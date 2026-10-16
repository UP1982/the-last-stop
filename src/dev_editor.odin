#+feature dynamic-literals
package main

// Every authoring procedure and its launch strings are compiled out of release.
import c "../shared/content"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"
import "core:slice"
import "core:time"
import "core:sys/posix"
import "core:c/libc"
import rl "vendor:raylib"

when DEV_TOOLS {
dev_request_sequence: int
Dev_Record :: struct { collection, id: string }
Dev_Editor :: struct {
    active, paused, fresh_input, dirty, uncertain: bool,
    baseline: ^c.Snapshot, // independent immutable allocation domain
    undo_before: []u8,
    undo_revision: c.Revision,
    undo_token, uncertain_token, last_request_id: string,
    last_expected: c.Revision,
    records: [dynamic]Dev_Record,
    selected, field: int,
    typing, replace_text: bool,
    text: [128]u8,
    text_len: int,
    status: [2048]u8,
    status_len: int,
    pending: bool,
    process: os.Process,
    job_dir, request_path, output_path: string,
    started: time.Tick,
    job_undo: bool,
    job_before: []u8,
    job_revision: c.Revision,
    generation, ticks: int,
}
dev_status :: proc(e:^Dev_Editor,message:string) {
    e.status_len=min(len(message),len(e.status)-1)
    copy(e.status[:],transmute([]u8)message[:e.status_len]); e.status[e.status_len]=0
    fmt.eprintln("E2",message)
}
dev_realpath :: proc(path:string) -> string {
    p:=posix.realpath(strings.clone_to_cstring(path,context.temp_allocator))
    if p==nil { return "" }
    defer libc.free(rawptr(p))
    return strings.clone_from_cstring(p)
}
// M4 permits static symlinks for normal saves. Preview has the stricter authoring
// rule: no symlink in HOME or any existing component below it, no fallback.
dev_preview_path_safe :: proc(r:^Runtime_Content) -> bool {
    home,err:=os.user_home_dir(context.temp_allocator)
    if err!=nil || home=="" || r.preview_directory=="" { return false }
    current:=home
    for part,i in ([]string{"","Library","Caches","The Last Stop","preview",r.options.preview_session}) {
        if i>0 { current=fmt.tprintf("%s/%s",current,part) }
        info,ie:=os.lstat(current,context.temp_allocator)
        if ie!=nil {
            // Missing directories may be established by M4; all other errors
            // (e.g. an inaccessible/non-directory parent) fail profile setup.
            if os.exists(current) { return false }
            continue
        }
        if info.type!=.Directory { return false }
    }
    return true
}
dev_isolated :: proc(g:^Game_State) -> bool {
    return g.content_ready && g.content!=nil && g.content.options.error=="" &&
        g.content.options.preview_scene=="oliver_obstacle" && valid_preview_session(g.content.options.preview_session) &&
        dev_preview_path_safe(g.content) && g.save.owner && save_profile_identity(&g.save) &&
        g.save.directory==g.content.preview_directory
}
dev_document :: proc(s:^c.Snapshot) -> ^c.Document {
    if s!=nil { for &d in s.documents { if d.kind=="scene" && d.id=="oliver_obstacle" { return &d } } }
    return nil
}
dev_editor_forget_baseline :: proc(e:^Dev_Editor) {
    c.destroy_snapshot(e.baseline); e.baseline=nil
    for r in e.records { delete(r.collection); delete(r.id) }; delete(e.records); e.records=nil
}
dev_job_cleanup :: proc(e:^Dev_Editor) {
    _=os.remove(e.request_path); _=os.remove(e.output_path); _=os.remove(e.job_dir)
    delete(e.request_path); delete(e.output_path); delete(e.job_dir)
    e.request_path=""; e.output_path=""; e.job_dir=""
    delete(e.job_before); e.job_before=nil
}
dev_editor_destroy :: proc(e:^Dev_Editor) {
    if e.pending { _=os.process_kill(e.process); _,_=os.process_wait(e.process); e.pending=false }
    dev_job_cleanup(e); dev_editor_forget_baseline(e)
    delete(e.undo_before); delete(e.undo_token); delete(e.uncertain_token); delete(e.last_request_id); e^={}
}
dev_capture_baseline :: proc(e:^Dev_Editor,r:^Runtime_Content) -> bool {
    loaded:=c.validate_sources(r.snapshot.sources[:],c.CHAPTER_PATH,context.allocator)
    if loaded.snapshot==nil { c.destroy_load_result(&loaded); return false }
    dev_editor_forget_baseline(e)
    e.baseline=loaded.snapshot; loaded.snapshot=nil; c.destroy_load_result(&loaded)
    def:=r.scene.definition
    for id in def.objects { append(&e.records,Dev_Record{strings.clone("objects"),strings.clone(string(id))}) }
    for id in def.spawns { append(&e.records,Dev_Record{strings.clone("spawns"),strings.clone(string(id))}) }
    slice.sort_by(e.records[:],proc(a,b:Dev_Record)->bool { if a.collection!=b.collection { return a.collection<b.collection }; return a.id<b.id })
    e.dirty=false; e.selected=0
    return true
}
dev_focus_selection :: proc(e:^Dev_Editor,g:^Game_State) {
    if e.selected<0 || e.selected>=len(e.records) { return }
    r:=e.records[e.selected]; p: c.Vec2i
    if r.collection=="objects" { p=g.scene.definition.objects[c.ID(r.id)].position } else { p=g.scene.definition.spawns[c.ID(r.id)].position }
    g.camera.x=clamp(f32(p[0])-420,g.scene.camera_bounds.x,max(g.scene.camera_bounds.x,g.scene.camera_bounds.x+g.scene.camera_bounds.width-VIRTUAL_WIDTH))
}
dev_reset :: proc(e:^Dev_Editor,g:^Game_State) {
    // Save descriptors remain M4-owned; never copy/reconfigure their ownership.
    save:=g.save; content:=g.content; scene:=content.scene
    g^=Game_State{save=save,content=content,content_ready=true,scene=scene,checkpoint=.Puzzle}
    g.save.active=true; g.save.dirty=true
    start_scene(g); enter_mode(g,.Playing); refresh_puzzle_objects(g)
    e.paused=true; e.fresh_input=true; e.ticks=0
    dev_focus_selection(e,g)
}
// Stage a validated graph in a new domain. No candidate geometry/resources are
// visible until ALL shared-content and M2 checks (and native uploads) pass.
dev_runtime :: proc(snapshot:^c.Snapshot,old:^Runtime_Content,native:bool) -> (Runtime_Content,bool) {
    r:=Runtime_Content{owner=c.new_owner(context.allocator),snapshot=snapshot}
    context.allocator=c.owner_allocator(r.owner)
    r.root=strings.clone(old.root); r.preview_directory=strings.clone(old.preview_directory)
    r.options=old.options
    r.options.project_root=strings.clone(old.options.project_root)
    r.options.preview_scene=strings.clone(old.options.preview_scene)
    r.options.preview_session=strings.clone(old.options.preview_session)
    r.options.preview_entry=strings.clone(old.options.preview_entry)
    r.options.save_directory=strings.clone(old.options.save_directory)
    r.options.autoplay=strings.clone(old.options.autoplay)
    r.text=make(map[string]cstring)
    for key,value in snapshot.chapter.strings { r.text[key]=strings.clone_to_cstring(value) }
    def,_:=c.find_scene(snapshot,snapshot.chapter.puzzle_scene); r.scene=adapt_scene(def)
    if !validate_runtime_puzzle(r.scene) { unload_runtime_content(&r); return {},false }
    if native && !stage_content_resources(&r) { unload_runtime_content(&r); return {},false }
    return r,true
}
dev_publish :: proc(e:^Dev_Editor,g:^Game_State,r:^Runtime_Content,snapshot:^c.Snapshot,native:bool) -> bool {
    candidate,ok:=dev_runtime(snapshot,r,native)
    if !ok { dev_status(e,"Candidate rejected: M2 pickability or native resources. Draft retained."); return false }
    old:=r^; r^=candidate; g.content=r
    dev_reset(e,g) // clears borrowed render strings before releasing old owner
    unload_runtime_content(&old)
    return true
}
dev_permitted :: proc(r:^Runtime_Content,collection,id,property:string) -> bool {
    if collection=="spawns" { _,ok:=r.scene.definition.spawns[c.ID(id)]; return ok && property=="position" }
    if collection!="objects" { return false }
    o,ok:=r.scene.definition.objects[c.ID(id)]; if !ok { return false }
    return property=="position" || property=="size" || property=="interaction" && o.has_interaction || property=="collision" && o.has_collision
}
dev_set_property :: proc(e:^Dev_Editor,g:^Game_State,r:^Runtime_Content,collection,id,property:string,value:json.Value,native:bool) -> bool {
    if !e.active || e.pending || e.uncertain || !dev_permitted(r,collection,id,property) { dev_status(e,"Property unavailable or mutation blocked; draft retained."); return false }
    owner:=c.new_owner(context.allocator); defer c.destroy_owner(owner)
    context.allocator=c.owner_allocator(owner)
    doc:=dev_document(r.snapshot); root:=json.clone_value(doc.value)
    records:=c.object(c.get(root,collection)); record:=c.object(records[id]); record[property]=json.clone_value(value); records[id]=record
    bytes:=c.serialize(root)
    sources:=make([]c.Document_Source,len(r.snapshot.sources)); copy(sources,r.snapshot.sources[:])
    for &src in sources { if src.path==doc.source.path { src.bytes=bytes } }
    // Candidate snapshot must outlive this request's scratch domain.
    loaded:=c.validate_sources(sources,c.CHAPTER_PATH,owner.backing)
    defer c.destroy_load_result(&loaded)
    if loaded.snapshot==nil {
        d:=loaded.diagnostics[0]; dev_status(e,fmt.tprintf("%s %s: %s; draft retained",d.code,d.pointer,d.message)); return false
    }
    snapshot:=loaded.snapshot; loaded.snapshot=nil
    context.allocator=owner.backing
    if !dev_publish(e,g,r,snapshot,native) { return false }
    context.allocator=c.owner_allocator(owner)
    e.dirty=string(c.serialize(dev_document(e.baseline).value))!=string(c.serialize(dev_document(r.snapshot).value))
    dev_status(e,"Valid draft. Geometry edits reset the unsolved sandbox and pause. Apply explicitly to save.")
    return true
}
// Authored boxes use the immutable definition, including the handle's shelf
// marker when the live unique handle is installed/carried elsewhere.
dev_hit_test :: proc(e:^Dev_Editor,g:^Game_State,mouse:rl.Vector2,viewport:Viewport) -> int {
    p,inside:=mouse_to_virtual(mouse,viewport); if !inside { return -1 }
    p.x+=g.camera.x; p.y+=g.camera.y
    // Prefer the smallest authored marker when records overlap (shed/handle).
    best:=-1; area:=f32(1e20)
    for record,i in e.records {
        rect:rl.Rectangle
        if record.collection=="objects" { o:=g.scene.definition.objects[c.ID(record.id)]; rect={f32(o.position[0]),f32(o.position[1]),f32(o.size[0]),f32(o.size[1])} }
        else { s:=g.scene.definition.spawns[c.ID(record.id)]; rect={f32(s.position[0])-5,f32(s.position[1])-5,10,10} }
        if rl.CheckCollisionPointRec(p,rect) && rect.width*rect.height<area { best=i; area=rect.width*rect.height }
    }
    return best
}
dev_operations :: proc(e:^Dev_Editor,r:^Runtime_Content) -> json.Array {
    ops:=make(json.Array)
    before,after:=dev_document(e.baseline).value,dev_document(r.snapshot).value
    for record in e.records {
        a:=c.get(c.get(before,record.collection),record.id); b:=c.get(c.get(after,record.collection),record.id)
        for property in ([]string{"position","size","interaction","collision"}) {
            if !dev_permitted(r,record.collection,record.id,property) { continue }
            if string(c.serialize(c.get(a,property)))!=string(c.serialize(c.get(b,property))) {
                append(&ops,json.Object{"op"="set_property","collection"=record.collection,"id"=record.id,"property"=property,"value"=json.clone_value(c.get(b,property))})
            }
        }
    }
    return ops
}
dev_start_apply :: proc(e:^Dev_Editor,g:^Game_State,r:^Runtime_Content,undo:bool) -> bool {
    if !e.active || !dev_isolated(g) || e.pending || e.uncertain || undo && len(e.undo_before)==0 { return false }
    if undo && e.dirty { dev_status(e,"Undo saved requires a clean draft. Apply or Discard the draft first."); return false }
    owner:=c.new_owner(context.allocator); defer c.destroy_owner(owner); context.allocator=c.owner_allocator(owner)
    canonical:=dev_realpath(r.root); defer delete(canonical)
    executable:=fmt.aprintf("%s/build/tls-content",canonical)
    // Fixed root-relative executable, no symlink components or arbitrary argv.
    if canonical=="" || !c.confined(canonical,"build/tls-content","build/") { dev_status(e,"Apply unavailable: build/tls-content must be a confined regular executable."); return false }
    info,ie:=os.stat(executable,context.allocator)
    if ie!=nil || info.type!=.Regular || posix.access(strings.clone_to_cstring(executable),{.X_OK})!=.OK { dev_status(e,"Apply unavailable: content executable missing or not executable."); return false }
    ops:=dev_operations(e,r)
    expected:=e.baseline.revision
    if undo {
        value,_,ok:=c.parse_strict(e.undo_before,"undo before-image"); if !ok { return false }
        ops=json.Array{json.Object{"op"="restore_document","value"=value}}; expected=e.undo_revision
    }
    if len(ops)==0 { dev_status(e,"No authored changes to apply."); return true }
    template:=strings.clone_to_cstring("/tmp/tls-native-edit-XXXXXX")
    if posix.mkdtemp(cast([^]u8)template)==nil { dev_status(e,"Apply failed: private request directory unavailable."); return false }
    // Job fields use the caller's allocator, not this request scratch owner.
    context.allocator=owner.backing
    e.job_dir=strings.clone_from_cstring(template)
    e.request_path=fmt.aprintf("%s/request.json",e.job_dir); e.output_path=fmt.aprintf("%s/result.json",e.job_dir)
    e.job_before=slice.clone(dev_document(e.baseline).source.bytes)
    e.job_revision=expected; e.job_undo=undo
    context.allocator=c.owner_allocator(owner)
    dev_request_sequence+=1
    request_id:=fmt.aprintf("native_%d_%d",os.get_pid(),dev_request_sequence)
    context.allocator=owner.backing
    delete(e.last_request_id); e.last_request_id=strings.clone(request_id); e.last_expected=expected
    delete(e.uncertain_token); e.uncertain_token=""
    context.allocator=c.owner_allocator(owner)
    request:=json.Object{"protocol_version"=i64(1),"request_id"=request_id,"chapter"="oliver_flower_market","document"="oliver_obstacle","expected_revision"=c.revision_string(expected),"operations"=ops}
    request_bytes:=c.serialize(request)
    fmt.eprintln("E2 request",string(request_bytes))
    written:=os.write_entire_file(e.request_path,request_bytes,{.Read_User,.Write_User})
    output,oe:=os.create(e.output_path); if oe!=nil || written!=nil { if oe==nil { _=os.close(output) }; context.allocator=owner.backing; dev_job_cleanup(e); dev_status(e,"Apply I/O failure before launch. Draft retained."); return false }
    process,pe:=os.process_start({command=[]string{executable,"apply-edit","--project-root",canonical,"--request",e.request_path},working_dir=canonical,stdout=output})
    _=os.close(output)
    if pe!=nil { context.allocator=owner.backing; dev_job_cleanup(e); dev_status(e,"Apply failed to start; draft retained."); return false }
    e.process=process; e.pending=true; e.started=time.tick_now(); e.paused=true
    clear_gameplay_edges(g); dev_status(e,"Applying through content CLI; rendering stays active. Mutations disabled.")
    return true
}
dev_replace_baseline :: proc(e:^Dev_Editor,s:^c.Snapshot) {
    loaded:=c.validate_sources(s.sources[:],c.CHAPTER_PATH,context.allocator)
    assert(loaded.snapshot!=nil)
    c.destroy_snapshot(e.baseline); e.baseline=loaded.snapshot; loaded.snapshot=nil; c.destroy_load_result(&loaded)
}
dev_poll_apply :: proc(e:^Dev_Editor,g:^Game_State,r:^Runtime_Content,native:bool) {
    if !e.pending { return }
    state,err:=os.process_wait(e.process,timeout=0)
    oversized:=false
    info,ie:=os.stat(e.output_path,context.temp_allocator)
    if ie==nil { oversized=info.size>c.MAX_DOCUMENT_BYTES }
    if !state.exited && !oversized && time.tick_since(e.started)<15*time.Second { return }
    e.pending=false
    defer dev_job_cleanup(e)
    if !state.exited {
        _=os.process_kill(e.process); _,_=os.process_wait(e.process)
        e.uncertain=true; dev_status(e,"Apply outcome unknown (timeout/output bound). Draft retained. Inspect disk/history; Discard reloads observed disk."); return
    }
    bytes,read_ok:=c.read_bounded(e.output_path,c.MAX_DOCUMENT_BYTES)
    defer delete(bytes)
    result,_,valid:=c.parse_strict(bytes,"content CLI result")
    defer json.destroy_value(result)
    code:=state.exit_code; commit:=c.text(c.get(result,"commit_state"))
    fmt.eprintf("E2 CLI exit=%d result=%s\n",code,string(bytes))
    if !read_ok || !valid || c.integer(c.get(result,"protocol_version"))!=1 || !state.success && code==0 {
        e.uncertain=true; dev_status(e,"Apply outcome unknown: invalid/lost CLI response. Draft retained. Inspect disk/history before reloading."); return
    }
    if code==2 || code==3 || code==4 {
        diagnostics,ok:=c.get(result,"diagnostics").(json.Array)
        if ok && len(diagnostics)>0 {
            d:=diagnostics[0]
            dev_status(e,fmt.tprintf("CLI exit %d: %s: %s. Draft retained; expected revision unchanged.",code,c.text(c.get(d,"code")),c.text(c.get(d,"message"))))
        } else { dev_status(e,fmt.tprintf("CLI exit %d. Draft retained; expected revision unchanged.",code)) }
        return
    }
    if code!=0 && code!=5 || commit!="committed" && commit!="not_committed" && commit!="committed_durability_uncertain" {
        e.uncertain=true; dev_status(e,"Apply outcome unknown. Inspect disk and history. Draft retained."); return
    }
    loaded:=c.load_chapter(r.root,c.CHAPTER_PATH,context.allocator)
    defer c.destroy_load_result(&loaded)
    observed_revision:=c.revision_string(loaded.snapshot.revision) if loaded.snapshot!=nil else ""
    defer if observed_revision!="" { delete(observed_revision) }
    if loaded.snapshot==nil || observed_revision!=c.text(c.get(result,"new_revision")) {
        e.uncertain=true; dev_status(e,"Disk inspection differs from CLI result or failed. Outcome needs review; draft retained."); return
    }
    if code==5 || commit=="committed_durability_uncertain" {
        e.uncertain=true
        delete(e.uncertain_token); e.uncertain_token=strings.clone(c.text(c.get(result,"undo_token")))
        dev_status(e,"Replacement happened; durability/finalization uncertain. Disk inspected. Draft retained; inspect .studio/history before Discard reload."); return
    }
    if commit=="committed" {
        delete(e.undo_before); e.undo_before=slice.clone(e.job_before)
        e.undo_revision=loaded.snapshot.revision
        delete(e.undo_token); e.undo_token=strings.clone(c.text(c.get(result,"undo_token")))
        if e.job_undo { delete(e.undo_before); e.undo_before=nil }
    }
    dev_replace_baseline(e,loaded.snapshot)
    snapshot:=loaded.snapshot; loaded.snapshot=nil
    if !dev_publish(e,g,r,snapshot,native) {
        e.dirty=true
        dev_status(e,"Saved; preview still shows previous content. Discard reload retries native resources."); return
    }
    e.dirty=false
    if commit=="not_committed" { dev_status(e,"Confirmed no-op; disk re-inspected. No replacement/history created.") }
    else if e.job_undo { dev_status(e,"Undo applied through validated restore_document transaction; disk re-inspected.") }
    else { dev_status(e,"Saved through content CLI; disk re-inspected. Undo applied restores its before-image.") }
}
dev_inspect_history :: proc(root,token:string) -> bool {
    if !strings.has_prefix(token,"txn-") || strings.contains(token,"/") || strings.contains(token,"..") { return false }
    owner:=c.new_owner(context.allocator); defer c.destroy_owner(owner); context.allocator=c.owner_allocator(owner)
    base:=fmt.aprintf(".studio/history/%s",token)
    before,after: []u8
    record:json.Value
    for name in ([]string{"before.json","after.json","prepared.json"}) {
        path:=fmt.aprintf("%s/%s",base,name)
        if !c.confined(root,path,".studio/") { return false }
        bytes,ok:=c.read_bounded(fmt.aprintf("%s/%s",root,path),c.MAX_DOCUMENT_BYTES)
        if !ok { return false }
        value,_,valid:=c.parse_strict(bytes,path); if !valid { return false }
        if name=="before.json" { before=bytes } else if name=="after.json" { after=bytes } else { record=value }
    }
    return c.hex_digest(c.hash_bytes(before))==c.text(c.get(record,"before_sha256")) &&
        c.hex_digest(c.hash_bytes(after))==c.text(c.get(record,"after_sha256"))
}
dev_reconcile_unknown :: proc(e:^Dev_Editor,r:^Runtime_Content,disk:^c.Snapshot) -> bool {
    owner:=c.new_owner(context.allocator); defer c.destroy_owner(owner); context.allocator=c.owner_allocator(owner)
    if e.uncertain_token!="" { return dev_inspect_history(r.root,e.uncertain_token) }
    history:=fmt.aprintf("%s/.studio/history",r.root)
    if !os.exists(history) { return disk.revision==e.last_expected }
    if !c.confined(r.root,".studio/history",".studio/") { return false }
    entries,err:=os.read_directory_by_path(history,1025,context.allocator)
    if err!=nil || len(entries)>1024 { return false }
    for entry in entries {
        if entry.type!=.Directory { continue }
        path:=fmt.aprintf(".studio/history/%s/prepared.json",entry.name)
        if !c.confined(r.root,path,".studio/") { continue }
        bytes,ok:=c.read_bounded(fmt.aprintf("%s/%s",r.root,path),c.MAX_DOCUMENT_BYTES); if !ok { continue }
        record,_,valid:=c.parse_strict(bytes,path)
        if valid && c.text(c.get(record,"request_id"))==e.last_request_id {
            if !dev_inspect_history(r.root,entry.name) { return false }
            fmt.eprintln("E2 inspected uncertain transaction",entry.name,"disk revision",c.revision_string(disk.revision))
            return true
        }
    }
    return disk.revision==e.last_expected
}
dev_discard :: proc(e:^Dev_Editor,g:^Game_State,r:^Runtime_Content,native:bool) -> bool {
    if e.pending { return false }
    loaded:=c.load_chapter(r.root,c.CHAPTER_PATH,context.allocator)
    defer c.destroy_load_result(&loaded)
    if loaded.snapshot==nil { dev_status(e,"Disk reload rejected: invalid/external content. Draft retained."); return false }
    if e.uncertain && !dev_reconcile_unknown(e,r,loaded.snapshot) {
        dev_status(e,"Uncertain transaction history/disk inspection failed. Draft retained; authoring blocked."); return false
    }
    snapshot:=loaded.snapshot; loaded.snapshot=nil
    if !dev_publish(e,g,r,snapshot,native) { return false }
    if !dev_capture_baseline(e,r) { return false }
    e.uncertain=false; e.typing=false
    dev_status(e,"Draft discarded; validated disk loaded. Sandbox reset and paused.")
    return true
}
// Shared dispatch for inspector and repeatable tests. No network/shell endpoint.
dev_action :: proc(e:^Dev_Editor,g:^Game_State,r:^Runtime_Content,name:string,args:json.Value=nil,native:bool=true) -> bool {
    if name=="toggle-overlays" { g.art.debug_boxes=!g.art.debug_boxes; return true }
    if name=="enter-edit-mode" {
        if e.pending { return false }
        if !dev_isolated(g) { dev_status(e,"F4 requires a valid isolated Studio preview. Launch a Studio preview to author."); return false }
        if e.baseline==nil && !dev_capture_baseline(e,r) { return false }
        e.active=!e.active; e.paused=true; e.typing=false; e.fresh_input=true; clear_gameplay_edges(g)
        dev_status(e,"Edit mode: geometry edits reset the unsolved sandbox and pause. Explicit Apply saves content.")
        return true
    }
    if !e.active || e.pending { return false }
    if !dev_isolated(g) { e.paused=true; dev_status(e,"Preview profile is no longer isolated/owned. Authoring blocked."); return false }
    switch name {
    case "select-record":
        for record,i in e.records {
            if record.collection==c.text(c.get(args,"collection")) && record.id==c.text(c.get(args,"id")) { e.selected=i; e.typing=false; dev_focus_selection(e,g); return true }
        }
    case "set-property": return dev_set_property(e,g,r,c.text(c.get(args,"collection")),c.text(c.get(args,"id")),c.text(c.get(args,"property")),c.get(args,"value"),native)
    case "pause-preview": e.paused=true; e.fresh_input=true; clear_gameplay_edges(g); return true
    case "resume-preview": e.paused=false; e.fresh_input=true; clear_gameplay_edges(g); return true
    case "step-preview":
        e.paused=true; e.fresh_input=true; clear_gameplay_edges(g)
        update_game(g,{},FIXED_DT); clear_gameplay_edges(g); e.ticks+=1; return true
    case "reset-sandbox": dev_reset(e,g); dev_status(e,"Sandbox reset deterministically from current draft; paused."); return true
    case "discard-draft": return dev_discard(e,g,r,native)
    case "apply-to-content": return dev_start_apply(e,g,r,false)
    case "undo-applied": return dev_start_apply(e,g,r,true)
    }
    return false
}
dev_tick :: proc(e:^Dev_Editor,g:^Game_State,input:Input,dt:f32) {
    if e.pending || e.active && e.paused { clear_gameplay_edges(g); return }
    if e.fresh_input {
        clear_gameplay_edges(g)
        // All keys, including held movement and skip/menu aliases, must release.
        if input.move==0 && !input.jump_down && !input.interact_down && !input.skip_down && !input.confirm_down && !input.pause_down &&
            !input.jump_pressed && !input.interact && !input.skip && !input.confirm && !input.pause && !input.return_train { e.fresh_input=false }
        return
    }
    update_game(g,input,dt)
}
dev_properties :: proc(e:^Dev_Editor,r:^Runtime_Content) -> []string {
    if len(e.records)==0 { return nil }
    record:=e.records[e.selected]; props:=make([dynamic]string,0,4,context.temp_allocator)
    for p in ([]string{"position","size","interaction","collision"}) { if dev_permitted(r,record.collection,record.id,p) { append(&props,p) } }
    return props[:]
}
dev_value_text :: proc(value:json.Value) -> string {
    // Content serialization is pretty printed; inspector fields are single-line.
    text:=string(c.serialize(value))
    text,_=strings.replace_all(text,"\n","")
    text,_=strings.replace_all(text," ","")
    return text
}
dev_begin_typing :: proc(e:^Dev_Editor,r:^Runtime_Content,field:int) {
    context.allocator=context.temp_allocator
    props:=dev_properties(e,r); if field<0 || field>=len(props) { return }
    record:=e.records[e.selected]
    value:=c.get(c.get(c.get(dev_document(r.snapshot).value,record.collection),record.id),props[field])
    text:=dev_value_text(value)
    e.text_len=min(len(text),len(e.text)-1); copy(e.text[:],transmute([]u8)text[:e.text_len]); e.text[e.text_len]=0
    e.field=field; e.typing=true; e.replace_text=true; e.paused=true
}
dev_editor_frame :: proc(e:^Dev_Editor,g:^Game_State,r:^Runtime_Content,input:Input,dt:f32) {
    dev_poll_apply(e,g,r,true)
    when #config(DEV_EDITOR_TEST_HOOKS,false) { dev_native_commands(e,g,r) }
    consumed:=false
    if rl.IsKeyPressed(.F4) { _=dev_action(e,g,r,"enter-edit-mode"); consumed=true }
    if e.active && !e.pending {
        viewport:=make_viewport(rl.GetScreenWidth(),rl.GetScreenHeight())
        mouse,inside:=mouse_to_virtual(rl.GetMousePosition(),viewport)
        ctrl:=rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL) || rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER)
        if e.typing {
            consumed=true
            if ctrl && rl.IsKeyPressed(.A) { e.replace_text=true }
            for ch:=rl.GetCharPressed(); ch!=0; ch=rl.GetCharPressed() {
                if (ch>='0' && ch<='9' || ch=='-' || ch==',' || ch==' ' || ch=='[' || ch==']') && e.text_len<len(e.text)-1 { if e.replace_text { e.text_len=0; e.replace_text=false }; e.text[e.text_len]=u8(ch); e.text_len+=1; e.text[e.text_len]=0 }
            }
            if rl.IsKeyPressed(.BACKSPACE) && e.text_len>0 { if e.replace_text { e.text_len=0; e.replace_text=false } else { e.text_len-=1 }; e.text[e.text_len]=0 }
            if rl.IsKeyPressed(.ESCAPE) { e.typing=false }
            if rl.IsKeyPressed(.ENTER) {
                owner:=c.new_owner(context.allocator)
                context.allocator=c.owner_allocator(owner)
                value,_,ok:=c.parse_strict(e.text[:e.text_len],"native numeric field")
                if ok {
                    record:=e.records[e.selected]; props:=dev_properties(e,r)
                    context.allocator=owner.backing
                    _=dev_set_property(e,g,r,record.collection,record.id,props[e.field],value,true)
                } else { dev_status(e,"Enter a JSON integer array, e.g. [1176,256]. Draft retained.") }
                context.allocator=owner.backing; c.destroy_owner(owner); e.typing=false
            }
        } else {
            action:=""
            if rl.IsKeyPressed(.F6) { action="resume-preview" if e.paused else "pause-preview" }
            if rl.IsKeyPressed(.F7) { action="step-preview" }
            if rl.IsKeyPressed(.F8) { action="reset-sandbox" }
            if ctrl && rl.IsKeyPressed(.S) { action="apply-to-content" }
            if ctrl && rl.IsKeyPressed(.Z) { action="undo-applied" }
            if rl.IsKeyPressed(.TAB) { e.selected=(e.selected+1)%len(e.records); dev_focus_selection(e,g); consumed=true }
            if inside && rl.IsMouseButtonPressed(.LEFT) {
                consumed=true
                if mouse.y>=158 && mouse.y<180 {
                    actions:=[]string{"pause-preview","resume-preview","step-preview","reset-sandbox","apply-to-content","undo-applied","discard-draft"}
                    i:=int(mouse.x)/91; if i<len(actions) { action=actions[i] }
                } else if mouse.x<190 && mouse.y>=40 && mouse.y<40+f32(len(e.records)*12) {
                    e.selected=int(mouse.y-40)/12; dev_focus_selection(e,g)
                } else if mouse.x>=205 && mouse.y>=42 && mouse.y<154 { dev_begin_typing(e,r,int(mouse.y-42)/26) }
                else if mouse.y>=200 { index:=dev_hit_test(e,g,rl.GetMousePosition(),viewport); if index>=0 { e.selected=index } }
            }
            if action!="" { _=dev_action(e,g,r,action); consumed=true }
        }
    }
    if consumed { e.fresh_input=true; clear_gameplay_edges(g) } else { dev_tick(e,g,input,dt) }
    when #config(DEV_EDITOR_TEST_HOOKS,false) { dev_native_status(e,g,r) }
}
dev_editor_draw :: proc(e:^Dev_Editor,g:^Game_State) {
    context.allocator=context.temp_allocator
    if (g.art.debug_boxes || e.active) && g.scene.definition!=nil {
        def:=g.scene.definition
        art_outline(g.scene.world,g.camera,CREAM); art_outline(g.scene.camera_bounds,g.camera,MINT)
        for id,o in def.objects {
            rect:=rl.Rectangle{f32(o.position[0]),f32(o.position[1]),f32(o.size[0]),f32(o.size[1])}
            color:=rl.Color{232,185,110,255}
            art_outline(rect,g.camera,color)
            if o.has_collision { art_outline(local_rect(o.collision,o.position),g.camera,rl.RED) }
            if o.has_interaction { art_outline(local_rect(o.interaction,o.position),g.camera,MINT) }
            rl.DrawText(strings.clone_to_cstring(fmt.tprintf("%s [authored]",id),context.temp_allocator),pixel(rect.x-g.camera.x),pixel(rect.y-g.camera.y)-12,10,color)
        }
        if g.puzzle.handle!=.Shelf {
            live:=handle_rect(g.scene,g.puzzle,g.player); art_outline(live,g.camera,rl.SKYBLUE)
            rl.DrawText("live handle",pixel(live.x-g.camera.x),pixel(live.y-g.camera.y)-12,10,rl.SKYBLUE)
        }
        if g.puzzle.phase!=.Blocked { art_outline(branch_rect(g.scene,g.puzzle),g.camera,rl.SKYBLUE) }
        for id,s in def.spawns {
            p:=rl.Vector2{f32(s.position[0])-g.camera.x,f32(s.position[1])-g.camera.y}
            rl.DrawCircleLines(i32(p.x),i32(p.y),5,MINT)
            rl.DrawText(strings.clone_to_cstring(string(id),context.temp_allocator),i32(p.x)-24,i32(p.y)+8,10,MINT)
        }
    }
    if !e.active {
        if g.art.debug_boxes {
            rl.DrawRectangle(0,0,640,18,NIGHT)
            rl.DrawText(strings.clone_to_cstring(fmt.tprintf("READ ONLY | %v / %v / %v | F4: Studio preview only",g.checkpoint,g.puzzle.handle,g.puzzle.phase),context.temp_allocator),4,4,10,MINT)
        }
        if e.status_len>0 { rl.DrawRectangle(0,338,640,22,NIGHT); rl.DrawText(cstring(&e.status[0]),4,342,10,CREAM) }
        return
    }
    rl.DrawRectangle(0,0,640,198,NIGHT)
    rl.DrawText(strings.clone_to_cstring(fmt.tprintf("EDIT %s %s | %v / %v / %v", "APPLYING" if e.pending else "PAUSED" if e.paused else "RUNNING","DRAFT" if e.dirty else "saved",g.checkpoint,g.puzzle.handle,g.puzzle.phase),context.temp_allocator),6,5,12,MINT)
    rl.DrawText("Geometry edits reset to unsolved + pause. F4 close; Tab select.",6,21,10,CREAM)
    for record,i in e.records {
        if i==e.selected { rl.DrawRectangle(2,39+i32(i)*12,194,12,rl.Color{52,71,106,255}) }
        rl.DrawText(strings.clone_to_cstring(record.id,context.temp_allocator),6,40+i32(i)*12,10,CREAM)
    }
    props:=dev_properties(e,g.content)
    record:=e.records[e.selected]
    for property,i in props {
        value:=c.get(c.get(c.get(dev_document(g.content.snapshot).value,record.collection),record.id),property)
        text:=dev_value_text(value)
        if e.typing && e.field==i { text=string(e.text[:e.text_len]) }
        rl.DrawText(strings.clone_to_cstring(fmt.tprintf("%s: %s",property,text),context.temp_allocator),205,44+i32(i)*26,12,CREAM)
    }
    for label,i in ([]cstring{"Pause F6","Run F6","Step F7","Reset F8","Apply ^S","Undo saved","Discard disk"}) {
        rl.DrawRectangle(1+i32(i)*91,158,89,21,rl.Color{52,71,106,255}); rl.DrawText(label,4+i32(i)*91,164,10,MINT)
    }
    rl.DrawText("Click a property; type [integers] + Enter. Esc cancels.",6,184,10,CREAM)
    // Bounded, wrapped diagnostics remain legible at the minimum canvas size.
    rl.DrawRectangle(0,312,640,48,NIGHT)
    for row:=0; row<4; row+=1 {
        start:=row*100; if start>=e.status_len { break }
        text:=string(e.status[start:min(start+100,e.status_len)])
        rl.DrawText(strings.clone_to_cstring(text,context.temp_allocator),4,314+i32(row)*11,10,CREAM)
    }
}
} // DEV_TOOLS
