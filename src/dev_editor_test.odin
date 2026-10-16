#+feature dynamic-literals
package main

import c "../shared/content"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

// Optional file rendezvous drives the SAME native action dispatcher; it is not
// present in ordinary DEV builds, nor any release. No simulated CLI responses.
when DEV_TOOLS { dev_test_bool :: proc(v:json.Value)->bool { b,_:=v.(bool); return b } }
when DEV_TOOLS && #config(DEV_EDITOR_TEST_HOOKS,false) {
dev_native_commands :: proc(e:^Dev_Editor,g:^Game_State,r:^Runtime_Content) {
    path:=os.get_env("TLS_E2_CONTROL",context.temp_allocator)
    if path=="" { return }
    bytes,err:=os.read_entire_file(path,context.temp_allocator); if err!=nil { return }
    _=os.remove(path)
    context.allocator=context.temp_allocator
    v,_,ok:=c.parse_strict(bytes,"native command")
    if ok {
        // Dispatch allocations belong to the persistent allocator, not scratch.
        context.allocator=r.owner.backing
        name:=c.text(c.get(v,"action"))
        if name=="quit" { request_save_exit(g,true) }
        else if name=="upload-failure" { _=os.set_env("TLS_M4_UPLOAD_FAIL","1") }
        else if name=="upload-recovery" { _=os.unset_env("TLS_M4_UPLOAD_FAIL") }
        else if name=="game-input" {
            if !e.active || !e.paused {
                input:=Input{move=f32(c.integer(c.get(v,"move"))),interact=dev_test_bool(c.get(v,"interact")),interact_down=dev_test_bool(c.get(v,"interact")),skip=dev_test_bool(c.get(v,"skip"))}
                dev_tick(e,g,input,f32(c.integer(c.get(v,"ticks")))*FIXED_DT)
            }
        } else { _=dev_action(e,g,r,name,c.get(v,"args"),true) }
        e.generation+=1
    }
}
dev_native_status :: proc(e:^Dev_Editor,g:^Game_State,r:^Runtime_Content) {
    context.allocator=context.temp_allocator
    path:=os.get_env("TLS_E2_STATUS",context.temp_allocator); if path=="" { return }
    value:=json.Object{"generation"=i64(e.generation),"active"=e.active,"paused"=e.paused,"dirty"=e.dirty,"pending"=e.pending,"uncertain"=e.uncertain,"ticks"=i64(e.ticks),"live_textures"=i64(m4_live_textures),"mode"=fmt.tprintf("%v",g.mode),"checkpoint"=fmt.tprintf("%v",g.checkpoint),"handle"=fmt.tprintf("%v",g.puzzle.handle),"status"=string(e.status[:e.status_len]),"revision"=c.revision_string(r.snapshot.revision),"authored"=dev_document(r.snapshot).value}
    temporary:=fmt.tprintf("%s.next",path); _=os.write_entire_file(temporary,c.serialize(value)); _=os.rename(temporary,path)
}
}
when DEV_TOOLS && #config(DEV_EDITOR_SELF_TEST,false) {
dev_test_set :: proc(e:^Dev_Editor,g:^Game_State,r:^Runtime_Content,property:string,value:json.Value,collection:="objects",id:="crank_handle") -> bool {
    return dev_action(e,g,r,"set-property",json.Object{"collection"=collection,"id"=id,"property"=property,"value"=value},false)
}
dev_test_poll :: proc(e:^Dev_Editor,g:^Game_State,r:^Runtime_Content) {
    for _ in 0..<2000 {
        dev_poll_apply(e,g,r,false)
        if !e.pending { return }
        time.sleep(10*time.Millisecond)
    }
    assert(false,"Apply poll exceeded bounded timeout")
}
dev_allocation_checks :: proc(g:^Game_State,r:^Runtime_Content) {
    tracker:mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracker,context.allocator)
    defer mem.tracking_allocator_destroy(&tracker)
    context.allocator=mem.tracking_allocator(&tracker)
    {
        e:=Dev_Editor{}; defer dev_editor_destroy(&e)
        defer unload_runtime_content(r)
        assert(dev_action(&e,g,r,"enter-edit-mode",nil,false))
        value:=json.Array{i64(1192),i64(256)}; defer delete(value)
        bad:=json.Array{i64(-2000),i64(256)}; defer delete(bad)
        for _ in 0..<25 {
            assert(dev_set_property(&e,g,r,"objects","crank_handle","position",value,false))
            assert(!dev_set_property(&e,g,r,"objects","crank_handle","position",bad,false))
            assert(dev_action(&e,g,r,"discard-draft",nil,false))
        }
    }
    for _,entry in tracker.allocation_map { fmt.eprintln("E2 leaked",entry.size,entry.location) }
    assert(len(tracker.allocation_map)==0 && len(tracker.bad_free_array)==0,"editor allocation lifecycle")
    fmt.println("PASS E2 zero live allocations/bad frees after 25 candidate/rejection/discard cycles")
}
run_dev_editor_tests :: proc() {
    assert(len(os.args)>2)
    scenario:=os.args[1]
    if scenario=="flags" {
        for entry in ([]string{"scene","chapter"}) { assert(parse_launch_options([]string{"--preview-scene","oliver_obstacle","--preview-session","e2","--preview-entry",entry}).error=="") }
        for args in ([][]string{ {"--preview-entry","chapter"},{"--preview-scene","oliver_obstacle","--preview-session","e2","--preview-entry","wrong"},{"--preview-scene","oliver_obstacle","--preview-session","../e2"} }) { assert(parse_launch_options(args).error!="") }
        fmt.println("PASS E2 launch option contract"); return
    }
    r:=load_runtime_content(os.args[2:],context.allocator)
    defer unload_runtime_content(&r)
    assert(r.snapshot!=nil)
    g:=Game_State{}; configure_content(&g,&r,true)
    if scenario=="path-block" { assert(!dev_preview_path_safe(&r)); fmt.println("PASS E2 symlinked preview destination rejected before save setup"); return }
    if r.options.preview_scene!="" { assert(dev_preview_path_safe(&r)) }; configure_save_profile(&g,true); defer destroy_save_profile(&g.save)
    if scenario=="allocation" { dev_allocation_checks(&g,&r); return }
    e:=Dev_Editor{}; defer dev_editor_destroy(&e)
    assert(g.save.owner)
    if r.options.preview_entry=="chapter" { new_run(&g) }
    if scenario=="chapter" {
        assert(g.mode==.Station_Intro && g.checkpoint==.Chapter_Start)
        for _ in 0..<5 { update_game(&g,{},0.1) }
        assert(dev_action(&e,&g,&r,"enter-edit-mode",nil,false))
        story,fade,art:=g.story,g.fade_elapsed,g.art
        dev_tick(&e,&g,{skip=true,interact=true,move=1},0.1)
        assert(g.story==story && g.fade_elapsed==fade && g.art==art)
        assert(dev_action(&e,&g,&r,"step-preview",nil,false))
        assert(abs(g.story.elapsed-story.elapsed-FIXED_DT)<0.000001)
        fmt.println("PASS E2 chapter entry; frozen story/fades/animation; one story tick"); return
    }
    if scenario=="normal" {
        assert(!dev_action(&e,&g,&r,"enter-edit-mode",nil,false)); assert(e.baseline==nil)
        assert(dev_action(&e,&g,&r,"toggle-overlays",nil,false) && g.art.debug_boxes && !e.active)
        fmt.println("PASS E2 normal profile cannot author"); return
    }
    assert(dev_action(&e,&g,&r,"enter-edit-mode",nil,false))
    if scenario=="isolation" {
        assert(dev_action(&e,&g,&r,"resume-preview",nil,false)); dev_tick(&e,&g,{},0)
        visit(&g,.Handle); assert(g.puzzle.handle==.Held)
        walk_to(&g,950); press_interact(&g); assert(g.puzzle.handle==.Dropped)
        visit(&g,.Handle); assert(g.puzzle.handle==.Held)
        complete_puzzle(&g)
        for _ in 0..<5 {
            update_game(&g,{},0); update_game(&g,{skip=true,skip_down=true},0); settle_transition(&g)
            if g.checkpoint==.Complete { break }
        }
        assert(g.checkpoint==.Complete && owns_paper_flower(g))
        assert(dev_action(&e,&g,&r,"pause-preview",nil,false))
        assert(dev_action(&e,&g,&r,"step-preview",nil,false))
        assert(dev_action(&e,&g,&r,"reset-sandbox",nil,false))
        assert(persist_game(&g)); request_save_exit(&g,true); assert(g.quit_requested)
        fmt.println("PASS E2 pickup/drop/install/crank/clear/finish/step/reset/quit isolated without Apply"); return
    }
    if scenario=="geometry" {
        assert(dev_test_set(&e,&g,&r,"size",json.Array{i64(18),i64(16)}))
        assert(dev_test_set(&e,&g,&r,"position",json.Array{i64(300),i64(288)},"spawns","puzzle_entry"))
        assert(dev_test_set(&e,&g,&r,"collision",json.Array{i64(0),i64(0),i64(92),i64(8)},"objects","fallen_branch"))
        assert(dev_action(&e,&g,&r,"discard-draft",nil,false))
        fmt.println("PASS E2 size, spawn, existing collision candidate edits and discard"); return
    }
    if scenario=="state" {
        assert(e.active && e.paused)
        before:=g.player; g.response_seconds=2; g.puzzle={handle=.Installed,phase=.Cranking,crank_progress=0.3}; g.fade_elapsed=0.07; g.transitioning=true
        for _ in 0..<100 { dev_tick(&e,&g,{move=1,interact=true,skip=true,jump_pressed=true},0.1) }
        assert(g.player==before && g.response_seconds==2 && g.puzzle.crank_progress==0.3 && g.fade_elapsed==0.07 && g.transitioning)
        assert(dev_action(&e,&g,&r,"step-preview",nil,false))
        assert(abs(g.fade_elapsed-(0.07+FIXED_DT))<0.000001 && e.paused)
        g.transitioning=false; e.ticks=0
        g.accumulator=0.099; g.pending_interact=true; g.pending_return=true
        assert(dev_action(&e,&g,&r,"step-preview",nil,false))
        assert(abs(g.puzzle.crank_progress-(0.3+FIXED_DT/CRANK_SECONDS))<0.000001)
        assert(abs(g.response_seconds-(2-FIXED_DT))<0.000001 && g.accumulator==0 && !g.pending_return && !g.pending_interact && e.ticks==1)
        assert(dev_action(&e,&g,&r,"reset-sandbox",nil,false))
        player,puzzle,story,camera:=g.player,g.puzzle,g.story,g.camera
        for _ in 0..<8 {
            g.puzzle={handle=.Installed,phase=.Cleared,crank_progress=1}; g.story.elapsed=7; g.transitioning=true
            assert(dev_action(&e,&g,&r,"reset-sandbox",nil,false))
            assert(g.player==player && g.puzzle==puzzle && g.story==story && g.camera==camera && !g.transitioning)
        }
        assert(dev_action(&e,&g,&r,"resume-preview",nil,false))
        for _ in 0..<10 { dev_tick(&e,&g,{move=1,interact=true,interact_down=true,skip_down=true},0.1) }
        assert(g.player==player && g.puzzle.handle==.Shelf)
        dev_tick(&e,&g,{},0.1); assert(!e.fresh_input)
        dev_tick(&e,&g,{move=1},FIXED_DT); assert(g.player.position!=player.position)
        g.camera={640,0}
        viewport:=make_viewport(1400,800)
        assert(dev_hit_test(&e,&g,{1,1},viewport)==-1)
        p:=rl.Vector2{(1180-640)*2+viewport.destination.x,260*2+viewport.destination.y}
        selected:=dev_hit_test(&e,&g,p,viewport); assert(selected>=0 && e.records[selected].id=="crank_handle")
        g.puzzle.handle=.Installed
        assert(dev_hit_test(&e,&g,p,viewport)==selected,"installed handle must expose authored shelf marker")
        assert(dev_action(&e,&g,&r,"select-record",json.Object{"collection"="spawns","id"="handle_recovery"},false))
        assert(dev_test_set(&e,&g,&r,"position",json.Array{i64(1160),i64(288)},"spawns","handle_recovery"))
        assert(g.puzzle==Puzzle_State{} && e.paused && e.dirty)
        assert(dev_action(&e,&g,&r,"discard-draft",nil,false))
        assert(!e.dirty)
        fmt.println("PASS E2 frozen timers, exact step/backlog, deterministic reset, fresh input, authored hit-testing, recovery edit, discard"); return
    }
    original:=r.snapshot.revision
    assert(!dev_test_set(&e,&g,&r,"position",json.Array{i64(-999),i64(256)}))
    assert(r.snapshot.revision==original && !e.dirty)
    assert(!dev_test_set(&e,&g,&r,"layer",json.Value("foreground")))
    assert(!dev_test_set(&e,&g,&r,"position",json.Array{i64(1),i64(2)},"spawns","handle_recovery"))
    // The handle footprint fits at x8, but Milo cannot stand there: M2 rejects.
    assert(!dev_test_set(&e,&g,&r,"position",json.Array{i64(8),i64(288)},"spawns","handle_recovery"))
    assert(r.snapshot.revision==original)
    assert(dev_test_set(&e,&g,&r,"position",json.Array{i64(1192),i64(256)}))
    assert(dev_test_set(&e,&g,&r,"interaction",json.Array{i64(-40),i64(-20),i64(96),i64(68)}))
    assert(e.dirty && e.paused && g.puzzle==Puzzle_State{} && g.checkpoint==.Puzzle)
    if scenario=="invalid-disk" {
        revision:=r.snapshot.revision
        path:=fmt.aprintf("%s/data/scenes/oliver_obstacle.json",r.root)
        invalid:=os.get_env("TLS_E4_INVALID",context.temp_allocator)
        if invalid=="version" {
            doc:=json.clone_value(dev_document(r.snapshot).value)
            object:=c.object(doc); object["schema_version"]=i64(999)
            assert(os.write_entire_file(path,c.serialize(doc))==nil)
        } else if invalid=="asset" {
            doc:=json.clone_value(dev_document(r.snapshot).value)
            objects:=c.object(c.get(doc,"objects")); handle:=c.object(objects["crank_handle"])
            handle["asset"]="missing_e4_asset"
            assert(os.write_entire_file(path,c.serialize(doc))==nil)
        } else if invalid=="file" {
            assert(os.remove(fmt.aprintf("%s/assets/backgrounds/forest_track.png",r.root))==nil)
        } else { assert(os.write_entire_file(path,"{broken external content")==nil) }
        assert(!dev_action(&e,&g,&r,"discard-draft",nil,false))
        assert(e.dirty && r.snapshot.revision==revision && e.baseline.revision==original)
        assert(dev_start_apply(&e,&g,&r,false)); dev_test_poll(&e,&g,&r)
        assert(e.dirty && r.snapshot.revision==revision && e.baseline.revision==original)
        fmt.println("PASS E2 invalid external content retains draft on explicit reload"); return
    }
    if scenario=="draft" { fmt.println("PASS E2 candidate rollback, M2 rejection, validated draft; no Apply"); return }
    if scenario=="stale" {
        path:=fmt.aprintf("%s/data/chapters/chapter_01.json",r.root)
        bytes,er:=os.read_entire_file(path,context.allocator); assert(er==nil); defer delete(bytes)
        assert(os.write_entire_file(path,fmt.aprintf("%s\n",string(bytes)))==nil)
    }
    if scenario=="missing-cli" { assert(!dev_start_apply(&e,&g,&r,false)); assert(e.dirty && !e.pending); fmt.println("PASS E2 executable confinement/missing CLI"); return }
    assert(dev_start_apply(&e,&g,&r,false)); assert(e.pending)
    assert(!dev_test_set(&e,&g,&r,"position",json.Array{i64(1200),i64(256)}))
    if scenario=="lost" || scenario=="crash-before" || scenario=="crash-after" {
        if scenario!="lost" {
            marker:=os.get_env("TLS_E0_MARKER",context.temp_allocator)
            for _ in 0..<1000 { if os.exists(marker) { break }; time.sleep(10*time.Millisecond) }
            assert(os.exists(marker))
        }
        _=os.process_kill(e.process)
    }
    dev_test_poll(&e,&g,&r)
    if scenario=="stale" { assert(e.dirty && e.baseline.revision==original && strings.contains(string(e.status[:e.status_len]),"stale_revision")); fmt.println("PASS E2 stale Apply retains draft and expected revision"); return }
    if scenario=="lost" || scenario=="timeout" || scenario=="crash-before" || scenario=="crash-after" { assert(e.uncertain && e.dirty); assert(dev_action(&e,&g,&r,"discard-draft",nil,false)); assert(!e.uncertain && !e.dirty); fmt.println("PASS E2 lost/timeout result blocks mutations and retains draft"); return }
    if scenario=="busy" { assert(e.dirty && !e.uncertain && strings.contains(string(e.status[:e.status_len]),"busy")); fmt.println("PASS E2 busy conflict retains draft"); return }
    fault:=os.get_env("TLS_E0_FAULT",context.temp_allocator)
    if fault!="" {
        assert(e.dirty)
        if fault=="directory_sync" || fault=="finalize_history" {
            assert(e.uncertain && e.uncertain_token!="" && dev_inspect_history(r.root,e.uncertain_token))
            assert(dev_action(&e,&g,&r,"discard-draft",nil,false)); assert(!e.uncertain && !e.dirty)
        } else { assert(!e.uncertain && strings.contains(string(e.status[:e.status_len]),"CLI exit 4")) }
        fmt.println("PASS E2 real CLI failure/uncertainty:",fault); return
    }
    assert(!e.dirty && !e.uncertain && e.baseline.revision!=original && len(e.undo_before)>0)
    assert(r.scene.definition.objects[c.ID("crank_handle")].position==c.Vec2i{1192,256})
    assert(dev_inspect_history(r.root,e.undo_token))
    applied:=e.baseline.revision
    if scenario=="stale-undo" {
        path:=fmt.aprintf("%s/data/chapters/chapter_01.json",r.root)
        bytes,er:=os.read_entire_file(path,context.allocator); assert(er==nil); defer delete(bytes)
        assert(os.write_entire_file(path,fmt.aprintf("%s\n",string(bytes)))==nil)
    }
    assert(dev_start_apply(&e,&g,&r,true)); dev_test_poll(&e,&g,&r)
    if scenario=="stale-undo" { assert(e.baseline.revision==applied && strings.contains(string(e.status[:e.status_len]),"stale_revision")); fmt.println("PASS E2 stale Undo conflicts"); return }
    assert(!e.dirty && e.baseline.revision!=applied && len(e.undo_before)==0)
    assert(r.scene.definition.objects[c.ID("crank_handle")].position==c.Vec2i{1176,256})
    // Repeated candidate replacement/reset/discard exercises ownership teardown.
    for _ in 0..<15 {
        assert(dev_test_set(&e,&g,&r,"position",json.Array{i64(1192),i64(256)}))
        assert(dev_action(&e,&g,&r,"discard-draft",nil,false))
    }
    fmt.println("PASS E2 real CLI Apply/restore Undo, history, repeated draft teardown")
}
}
