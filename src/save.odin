#+feature dynamic-literals
package main

import c "../shared/content"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:sys/posix"
import "core:time"

Save_Record :: struct { checkpoint: Journey_Checkpoint, puzzle: Puzzle_State }
Save_Profile :: struct {
    directory, path: string,
    enabled, exists, rejected, dirty, active: bool,
    owner, anchored, busy: bool,
    directory_fd, lock_fd: posix.FD,
    directory_identity, lock_identity: posix.stat_t,
    message: cstring,
    loaded: Save_Record,
}
Save_Commit :: enum { Failed, Committed, Durability_Uncertain }
HANDLE_NAMES :=  [Handle_Location]string{.Shelf="shelf",.Held="held",.Dropped="dropped",.Installed="installed"}
PHASE_NAMES :=  [Puzzle_Phase]string{.Blocked="blocked",.Cranking="cranking",.Cleared="cleared"}
CHECKPOINT_NAMES :=  [Journey_Checkpoint]string{.Chapter_Start="chapter_start",.Boarded="boarded",.Puzzle="puzzle",.Returned="returned",.Arrival="arrival",.Complete="complete"}

resolve_save_directory :: proc(options: Launch_Options, preview_directory, home, environment: string, test_mode: bool) -> (string,bool) {
    // Preview always wins over CLI/environment. It never reads normal saves.
    if options.preview_scene!="" { return preview_directory, preview_directory!="" && filepath.is_abs(preview_directory) }
    directory:=options.save_directory
    if directory=="" { directory=environment }
    if directory!="" { return directory, filepath.is_abs(directory) }
    if test_mode { return "",false }
    if home=="" { return "",false }
    return fmt.aprintf("%s/Library/Application Support/The Last Stop/saves",home),true
}
json_keys :: proc(value: json.Value, names: []string) -> bool {
    o,ok:=value.(json.Object)
    if !ok || len(o)!=len(names) { return false }
    for name in names { if _,found:=o[name]; !found { return false } }
    return true
}
save_decode :: proc(bytes: []u8, scene: Runtime_Scene) -> (Save_Record,bool) {
    if scene.definition==nil { return {},false }
    owner:=c.new_owner(context.allocator); defer c.destroy_owner(owner)
    context.allocator=c.owner_allocator(owner)
    v,_,ok:=c.parse_strict(bytes,"save")
    if !ok { return {},false }
    if !json_keys(v,[]string{"save_version","chapter_id","scene_id","checkpoint","player_spawn","puzzle"}) { return {},false }
    o:=v.(json.Object)
    version,vi:=o["save_version"].(i64)
    chapter,ci:=o["chapter_id"].(string); scene_id,si:=o["scene_id"].(string)
    checkpoint,ki:=o["checkpoint"].(string); spawn,spi:=o["player_spawn"].(string)
    if !vi || (version!=1 && version!=2) || !ci || chapter!="oliver_flower_market" || !si || scene_id!="oliver_obstacle" || !ki || !spi { return {},false }
    r:Save_Record
    found:=false
    for name,k in CHECKPOINT_NAMES { if checkpoint==name { r.checkpoint=k; found=true; break } }
    if !found { return {},false }
    expected_spawn:="puzzle_entry"; if r.checkpoint>=.Returned { expected_spawn="train_return" }
    if spawn!=expected_spawn { return {},false }
    pv:=o["puzzle"]
    if !json_keys(pv,[]string{"handle_location","dropped_feet","phase","snail_seen"}) { return {},false }
    p:=pv.(json.Object)
    handle,hi:=p["handle_location"].(string); phase,pi:=p["phase"].(string); snail,sni:=p["snail_seen"].(bool)
    if !hi || !pi || !sni { return {},false }
    r.puzzle.snail_seen=snail
    found=false
    for name,k in HANDLE_NAMES { if handle==name { r.puzzle.handle=k; found=true; break } }
    if !found { return {},false }
    found=false
    for name,k in PHASE_NAMES { if phase==name { r.puzzle.phase=k; found=true; break } }
    if !found { return {},false }
    if r.puzzle.handle==.Dropped {
        feet,ai:=p["dropped_feet"].(json.Array)
        if !ai || len(feet)!=2 { return {},false }
        for n,i in feet {
            f:f64
             #partial switch val in n { case i64: f=f64(val); case f64: f=val; case: return {},false }
            if math.is_nan(f) || math.is_inf(f) { return {},false }
            // v1 stored half-scale world units. Convert in f64 before
            // narrowing, then let normal spatial validation recover unsafe data.
            if version==1 { f *= 2 }
            if abs(f)>f64(max(f32)) { r.puzzle.dropped_feet[i]=max(f32) }
            else { r.puzzle.dropped_feet[i]=f32(f) }
        }
    } else { if _,null:=p["dropped_feet"].(json.Null); !null { return {},false } }
    // Reject contradictions BEFORE normalization; recovery only repairs spatial
    // placement and held items, never phase/checkpoint contradictions.
    if r.puzzle.phase!=.Blocked && r.puzzle.handle!=.Installed { return {},false }
    if r.checkpoint<.Puzzle && (r.puzzle.handle!=.Shelf || r.puzzle.phase!=.Blocked || snail) { return {},false }
    if r.checkpoint>=.Returned && (r.puzzle.handle!=.Installed || r.puzzle.phase!=.Cleared) { return {},false }
    normalize_puzzle(&r.puzzle,scene)
    return r,puzzle_invariant(r.puzzle,r.checkpoint,scene)
}
save_encode :: proc(r: Save_Record) -> []u8 {
    allocator:=context.allocator
    owner:=c.new_owner(allocator); defer c.destroy_owner(owner)
    context.allocator=c.owner_allocator(owner)
    feet:json.Value=json.Null{}
    if r.puzzle.handle==.Dropped { feet=json.Array{f64(r.puzzle.dropped_feet[0]),f64(r.puzzle.dropped_feet[1])} }
    spawn:="puzzle_entry"; if r.checkpoint>=.Returned { spawn="train_return" }
    v:=json.Object{
        "save_version"=i64(2),"chapter_id"="oliver_flower_market","scene_id"="oliver_obstacle",
        "checkpoint"=CHECKPOINT_NAMES[r.checkpoint],"player_spawn"=spawn,
        "puzzle"=json.Object{"handle_location"=HANDLE_NAMES[r.puzzle.handle],"dropped_feet"=feet,
            "phase"=PHASE_NAMES[r.puzzle.phase],"snail_seen"=r.puzzle.snail_seen},
    }
    return transmute([]u8)strings.clone(string(c.serialize(v)),allocator)
}
save_hook :: proc(name:string) -> bool {
    when #config(M2_TEST_HOOKS,false) { return os.get_env("TLS_M2_FAULT",context.temp_allocator)==name }
    return false
}
save_rendezvous :: proc(name:string) {
    when #config(M2_TEST_HOOKS,false) {
        if os.get_env("TLS_M2_PAUSE",context.temp_allocator)==name {
            marker:=os.get_env("TLS_M2_MARKER",context.temp_allocator)
            _=os.write_entire_file(marker,name)
            for _ in 0..<3000 { if os.exists(fmt.tprintf("%s.release",marker)) { break }; time.sleep(10*time.Millisecond) }
        }
    }
}
// Keep both descriptors open for the entire profile lifetime. Static directory
// symlinks are supported; retargeting or replacing either identity invalidates it.
save_profile_identity :: proc(p:^Save_Profile) -> bool {
    if !p.anchored || !p.owner { return false }
    dir,lock,held:posix.stat_t
    return posix.fstat(p.directory_fd,&held)==nil && held.st_dev==p.directory_identity.st_dev && held.st_ino==p.directory_identity.st_ino &&
        posix.stat(strings.clone_to_cstring(p.directory,context.temp_allocator),&dir)==nil && dir.st_dev==held.st_dev && dir.st_ino==held.st_ino &&
        posix.fstat(p.lock_fd,&held)==nil && held.st_nlink==1 && posix.S_ISREG(held.st_mode) &&
        held.st_dev==p.lock_identity.st_dev && held.st_ino==p.lock_identity.st_ino &&
        posix.lstat(strings.clone_to_cstring(fmt.tprintf("%s/.write-owner.lock",p.directory),context.temp_allocator),&lock)==nil &&
        lock.st_dev==held.st_dev && lock.st_ino==held.st_ino
}
acquire_save_profile :: proc(p:^Save_Profile) {
    if e:=os.mkdir_all(p.directory,{.Read_User,.Write_User,.Execute_User}); e!=nil && e!=.Exist { return }
    p.directory_fd=posix.open(strings.clone_to_cstring(p.directory,context.temp_allocator),{.DIRECTORY},{})
    if p.directory_fd<0 { return }
    p.anchored=true
    if posix.fstat(p.directory_fd,&p.directory_identity)!=nil { return }
    p.lock_fd=posix.open(strings.clone_to_cstring(fmt.tprintf("%s/.write-owner.lock",p.directory),context.temp_allocator),{.RDWR,.CREAT,.NOFOLLOW},{.IRUSR,.IWUSR})
    if p.lock_fd<0 { return }
    if posix.fstat(p.lock_fd,&p.lock_identity)!=nil || !posix.S_ISREG(p.lock_identity.st_mode) || p.lock_identity.st_nlink!=1 { return }
    lock:=posix.flock{l_type=.WRLCK,l_whence=0}
    if posix.fcntl(p.lock_fd,.SETLK,&lock)<0 {
        error:=posix.errno()
        p.busy=error==.EACCES || error==.EAGAIN
        return
    }
    p.owner=true
    if !save_profile_identity(p) { p.owner=false }
}
save_atomic :: proc(profile: ^Save_Profile, r: Save_Record, scene: Runtime_Scene) -> Save_Commit {
    if !profile.enabled || profile.rejected || !save_profile_identity(profile) { return .Failed }
    if !puzzle_invariant(r.puzzle,r.checkpoint,scene) { return .Failed }
    bytes:=save_encode(r); defer delete(bytes)
    // Serialize -> strict decode/validate before touching destination.
    if _,ok:=save_decode(bytes,scene); !ok { return .Failed }
    m4_save_event(r,"before_temp")
    if !save_profile_identity(profile) { return .Failed }
    if save_hook("temp") { return .Failed }
    fd:posix.FD=-1
    temporary:cstring
    for attempt in 0..<100 {
        temporary=strings.clone_to_cstring(fmt.tprintf(".tls-save-%d-%d",posix.getpid(),attempt),context.temp_allocator)
        fd=posix.openat(profile.directory_fd,temporary,{.WRONLY,.CREAT,.EXCL,.NOFOLLOW},{.IRUSR,.IWUSR})
        if fd>=0 || posix.errno()!=.EEXIST { break }
    }
    if fd<0 { return .Failed }
    defer posix.unlinkat(profile.directory_fd,temporary,{})
    m4_save_event(r,"temp_created")
    m4_save_event(r,"before_write")
    if !save_profile_identity(profile) { _=posix.close(fd); return .Failed }
    offset:=0; wrote:=true
    for offset<len(bytes) {
        payload:=bytes[offset:]
        if save_hook("write") { payload=payload[:len(payload)/2] }
        n:=posix.write(fd,raw_data(payload),len(payload))
        if n<=0 || save_hook("write") { wrote=false; break }
        offset+=int(n)
    }
    m4_save_event(r,"after_write")
    m4_save_event(r,"before_sync")
    synced:=wrote && posix.fsync(fd)==nil && !save_hook("sync")
    m4_save_event(r,"after_sync")
    closed:=posix.close(fd)==nil && !save_hook("close")
    m4_save_event(r,"after_close")
    if !wrote || !synced || !closed { return .Failed }
    m4_save_event(r,"before_rename")
    save_rendezvous("before_rename")
    if !save_profile_identity(profile) { return .Failed }
    if save_hook("rename") || posix.renameat(profile.directory_fd,temporary,profile.directory_fd,"chapter_01.json")!=nil { return .Failed }
    m4_save_event(r,"after_rename")
    save_rendezvous("after_rename")
    if save_hook("directory_sync") || !save_profile_identity(profile) || posix.fsync(profile.directory_fd)!=nil || !save_profile_identity(profile) { return .Durability_Uncertain }
    return .Committed
}
Save_Load :: enum { Loaded, Missing, Rejected, Unavailable }
load_save_profile :: proc(profile: ^Save_Profile, scene: Runtime_Scene) -> Save_Load {
    profile.loaded={}; profile.exists=false; profile.rejected=false
    if !profile.enabled || !save_profile_identity(profile) { return .Unavailable }
    // Read through one descriptor and reject aliases of the permanent lock.
    // Closing any alias would release this process's POSIX record lock.
    named:posix.stat_t
    cpath:=strings.clone_to_cstring(profile.path,context.temp_allocator)
    if posix.stat(cpath,&named)!=nil {
        if posix.errno()==.ENOENT { profile.message="No saved journey found."; return .Missing }
        profile.rejected=true; profile.message="Save unavailable. Bytes kept. Retry Continue."
        return .Rejected
    }
    profile.exists=true
    if named.st_dev==profile.lock_identity.st_dev && named.st_ino==profile.lock_identity.st_ino {
        profile.rejected=true; profile.message="Save rejected. Bytes kept. New Game to reset."; return .Rejected
    }
    fd:=posix.open(cpath,{.NONBLOCK},{})
    if fd<0 { profile.rejected=true; profile.message="Save unavailable. Bytes kept. New Game to reset."; return .Rejected }
    opened:posix.stat_t
    stat_ok:=posix.fstat(fd,&opened)==nil
    alias:=stat_ok && opened.st_dev==profile.lock_identity.st_dev && opened.st_ino==profile.lock_identity.st_ino
    if alias { profile.owner=false } // closing an alias releases F_SETLK
    valid:=stat_ok && posix.S_ISREG(opened.st_mode) && opened.st_size>0 && opened.st_size<=256*1024 && !alias
    bytes:[]u8
    if valid {
        bytes=make([]u8,int(opened.st_size))
        offset:=0
        for offset<len(bytes) {
            remaining:int=len(bytes)-offset
            n:=posix.read(fd,raw_data(bytes[offset:]),uint(remaining))
            if n<=0 { valid=false; break }; offset+=int(n)
        }
        extra:[1]u8
        if posix.read(fd,&extra[0],1)!=0 { valid=false }
    }
    _=posix.close(fd)
    defer delete(bytes)
    r,ok:=save_decode(bytes,scene)
    if !valid || !ok || !save_profile_identity(profile) {
        profile.rejected=true
        profile.message="Save rejected. Bytes kept. New Game to reset."
        fmt.eprintln("SAVE: rejected; original bytes preserved; auto-overwrite disabled:",profile.path)
        return .Rejected
    }
    profile.loaded=r; profile.message=nil
    return .Loaded
}
configure_save_profile :: proc(g: ^Game_State, test_mode:=false) {
    if !g.content_ready { return }
    o:=g.content.options
    home,e:=os.user_home_dir(context.allocator); defer delete(home)
    if e!=nil { home="" }
    environment:=os.get_env("TLS_SAVE_DIR",context.allocator); defer delete(environment)
    directory,ok:=resolve_save_directory(o,g.content.preview_directory,home,environment,test_mode)
    g.save.directory=strings.clone(directory)
    if !ok { g.save.message="Save path invalid. Use an absolute --save-dir."; return }
    g.save.path=fmt.aprintf("%s/chapter_01.json",directory)
    g.save.enabled=true
    g.save.directory_fd=-1; g.save.lock_fd=-1
    acquire_save_profile(&g.save)
    if !g.save.owner {
        if g.save.busy { g.save.message="Another copy of The Last Stop is open." }
        else { g.save.message="Saving is unavailable on this drive." }
        return
    }
    if o.preview_scene!="" {
        // Deterministic fresh preview, no read of any previous session's run.
        g.checkpoint=.Puzzle; g.save.active=true; g.save.dirty=true; persist_game(g)
    } else { _=load_save_profile(&g.save,g.scene) }
}
destroy_save_profile :: proc(p: ^Save_Profile) {
    if p.anchored { _=posix.close(p.directory_fd) }
    if p.lock_fd>=0 && p.enabled { _=posix.close(p.lock_fd) }
    delete(p.directory); delete(p.path); p^={}
}
persist_game :: proc(g: ^Game_State) -> bool {
    when #config(M0_SELF_TEST,false) || #config(M1_SELF_TEST,false) { if !g.save.enabled { return true } }
    if !g.save.active { return true }
    g.save.dirty=true
    if !g.save.enabled || g.save.rejected || !g.save.owner { return false }
    g.save.dirty=true
    r:=Save_Record{g.checkpoint,g.puzzle}
    m4_event(g,"before_save")
    status:=save_atomic(&g.save,r,g.scene)
    m4_event(g,"after_save")
    if !save_profile_identity(&g.save) { g.save.message="Save location changed. Progress needs retry."; return false }
    if status==.Failed { g.save.message="Save failed. Progress needs retry."; fmt.eprintln("SAVE: write failed; dirty:",g.save.path) }
    else {
        g.save.exists=true; g.save.loaded=r
        if status==.Durability_Uncertain { g.save.message="Saved; disk sync uncertain. Retry pending."; fmt.eprintln("SAVE: committed; durability uncertain:",g.save.path) }
        else { g.save.dirty=false; g.save.message=nil }
    }
    return !g.save.dirty
}
new_run :: proc(g: ^Game_State) {
    if !save_run_allowed(g.save) { return }
    g.save.active=true
    g.save.rejected=false
    g.puzzle={}; g.checkpoint=.Chapter_Start; g.completion_cues=0; g.story_cues=0
    start_scene(g)
    persist_game(g)
    story_begin(g,.Intro)
    begin_transition(g,.Station_Intro)
}
continue_run :: proc(g: ^Game_State) {
    if !g.save.owner || g.save.active && g.save.dirty { return }
    // Re-read at the actual press, and require an explicit successful load.
    if load_save_profile(&g.save,g.scene)!=.Loaded { return }
    g.save.active=true
    g.checkpoint=g.save.loaded.checkpoint; g.puzzle=g.save.loaded.puzzle; g.completion_cues=0
    start_scene(g)
    resume_checkpoint(g)
    begin_transition(g,g.mode)
}

save_run_allowed :: proc(p:Save_Profile) -> bool {
    when #config(M0_SELF_TEST,false) || #config(M1_SELF_TEST,false) { return true }
    return p.owner
}
