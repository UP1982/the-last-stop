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
    if !vi || version!=1 || !ci || chapter!="oliver_flower_market" || !si || scene_id!="oliver_obstacle" || !ki || !spi { return {},false }
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
        "save_version"=i64(1),"chapter_id"="oliver_flower_market","scene_id"="oliver_obstacle",
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
save_sync_directory :: proc(dir:string) -> bool {
    path:=strings.clone_to_cstring(dir); defer delete(path)
    fd:=posix.open(path,{.DIRECTORY},{})
    if fd<0 { return false }
    synced:=posix.fsync(fd)==nil; closed:=posix.close(fd)==nil
    return synced && closed
}
save_atomic :: proc(profile: ^Save_Profile, r: Save_Record, scene: Runtime_Scene) -> Save_Commit {
    if !profile.enabled || profile.rejected { return .Failed }
    if !puzzle_invariant(r.puzzle,r.checkpoint,scene) { return .Failed }
    bytes:=save_encode(r); defer delete(bytes)
    // Serialize -> strict decode/validate before touching destination.
    if _,ok:=save_decode(bytes,scene); !ok { return .Failed }
    if e:=os.mkdir_all(profile.directory,{.Read_User,.Write_User,.Execute_User}); e!=nil && e!=.Exist { return .Failed }
    if save_hook("temp") { return .Failed }
    f,e:=os.create_temp_file(profile.directory,".tls-save-*")
    if e!=nil { return .Failed }
    temporary:=strings.clone(os.name(f)); defer delete(temporary); defer os.remove(temporary)
    offset:=0; wrote:=true
    for offset<len(bytes) {
        payload:=bytes[offset:]
        if save_hook("write") { payload=payload[:len(payload)/2] }
        n,we:=os.write(f,payload)
        if we!=nil || n<=0 || save_hook("write") { wrote=false; break }
        offset+=n
    }
    synced:=wrote && os.sync(f)==nil && !save_hook("sync")
    closed:=os.close(f)==nil && !save_hook("close")
    if !wrote || !synced || !closed { return .Failed }
    save_rendezvous("before_rename")
    if save_hook("rename") || os.rename(temporary,profile.path)!=nil { return .Failed }
    save_rendezvous("after_rename")
    if save_hook("directory_sync") || !save_sync_directory(profile.directory) { return .Durability_Uncertain }
    return .Committed
}
load_save_profile :: proc(profile: ^Save_Profile, scene: Runtime_Scene) {
    if !profile.enabled { return }
    profile.exists=os.exists(profile.path)
    if !profile.exists { return }
    bytes,e:=os.read_entire_file(profile.path,context.allocator)
    defer delete(bytes)
    r,ok:=save_decode(bytes,scene)
    if e!=nil || !ok {
        profile.rejected=true
        profile.message="Save rejected. Bytes kept. New Game to reset."
        fmt.eprintln("SAVE: rejected; original bytes preserved; auto-overwrite disabled:",profile.path)
        return
    }
    profile.loaded=r
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
    if o.preview_scene!="" {
        // Deterministic fresh preview, no read of any previous session's run.
        g.checkpoint=.Puzzle; g.save.active=true; g.save.dirty=true; persist_game(g)
    } else { load_save_profile(&g.save,g.scene) }
}
destroy_save_profile :: proc(p: ^Save_Profile) { delete(p.directory); delete(p.path); p^={} }
persist_game :: proc(g: ^Game_State) {
    if !g.save.enabled || g.save.rejected || !g.save.active { return }
    g.save.dirty=true
    r:=Save_Record{g.checkpoint,g.puzzle}
    status:=save_atomic(&g.save,r,g.scene)
    if status==.Failed { g.save.message="Save failed. Progress needs retry."; fmt.eprintln("SAVE: write failed; dirty:",g.save.path) }
    else {
        g.save.exists=true; g.save.loaded=r
        if status==.Durability_Uncertain { g.save.message="Saved; disk sync uncertain. Retry pending."; fmt.eprintln("SAVE: committed; durability uncertain:",g.save.path) }
        else { g.save.dirty=false; g.save.message=nil }
    }
}
new_run :: proc(g: ^Game_State) {
    g.save.active=true
    g.save.rejected=false
    g.puzzle={}; g.checkpoint=.Chapter_Start; g.completion_cues=0
    start_scene(g)
    persist_game(g)
    // M2 skips story presentation; M3 will call these at the actual boundaries.
    board_oliver(g); enter_obstacle(g)
    refresh_puzzle_objects(g)
    begin_transition(g,.Playing)
}
continue_run :: proc(g: ^Game_State) {
    if !g.save.exists || g.save.rejected { return }
    // Re-read disk (never continue the in-memory Held state).
    load_save_profile(&g.save,g.scene)
    if g.save.rejected { return }
    g.save.active=true
    g.checkpoint=g.save.loaded.checkpoint; g.puzzle=g.save.loaded.puzzle; g.completion_cues=0
    start_scene(g)
    if g.checkpoint<.Puzzle { board_oliver(g); enter_obstacle(g) }
    mode:=GameMode.Playing
    if g.checkpoint>=.Returned {
        g.player={position=marker_position(g.scene,true),grounded=true,facing=1}
        g.camera={}; follow_camera(&g.camera,g.player.position.x,g.scene.camera_bounds,g.player.position.y)
        mode=.Returned
    }
    refresh_puzzle_objects(g)
    begin_transition(g,mode)
}
