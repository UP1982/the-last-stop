package main
import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

when #config(M4_SELF_TEST,false) {
m4_press :: proc(g:^Game_State,selection:int) {
    update_game(g,{},0); g.selection=selection; update_game(g,{confirm=true},0)
}
m4_assert :: proc(g:^Game_State) { assert(puzzle_invariant(g.puzzle,g.checkpoint,g.scene)) }
run_m4_tests :: proc() {
    command:=os.args[1]
    native:=command=="reload" || command=="assets" || command=="asset-reject" || command=="snapshot"
    if native { rl.InitWindow(640,360,"The Last Stop"); rl.SetExitKey(.KEY_NULL) }
    defer { if native { rl.CloseWindow() } }
    r:=load_runtime_content(os.args[2:],context.allocator); defer unload_runtime_content(&r)
    if command=="asset-reject" {
        assert(r.snapshot==nil || !stage_content_resources(&r))
        assert(m4_live_textures==0); fmt.println("PASS asset startup rollback"); return
    }
    assert(r.snapshot!=nil)
    if command=="snapshot" {
        path:=os.get_env("TLS_M4_DELETE",context.temp_allocator)
        assert(strings.has_prefix(path,"/tmp/")); _=os.remove(path)
    }
    upload_requested:=os.get_env("TLS_M4_UPLOAD_FAIL",context.temp_allocator)=="1"
    if command=="assets" { _=os.unset_env("TLS_M4_UPLOAD_FAIL") }
    if native { assert(stage_content_resources(&r)) }
    g:=Game_State{}; configure_content(&g,&r,true); configure_save_profile(&g,true); defer destroy_save_profile(&g.save)
    assert(strings.has_prefix(g.save.directory,"/tmp/"),"M4 refuses non-/tmp profiles")
    switch command {
    case "whole", "whole-skip":
        new_run(&g); settle_transition(&g)
        if command=="whole" { for g.mode!=.Playing { story_test_complete_role(&g) } }
        else { reach_puzzle(&g) }
        // Extend the audit route with actual focused movement, drop, snail,
        // pause, quit-to-title and fresh Continue before completing the story.
        visit(&g,.Handle); walk_to(&g,1000); press_interact(&g)
        assert(g.puzzle.handle==.Dropped)
        visit(&g,.Snail)
        pause_game(&g); m4_press(&g,2); settle_transition(&g)
        assert(g.mode==.Title); m4_press(&g,0); settle_transition(&g)
        complete_puzzle(&g)
        if command=="whole-skip" {
            for _ in 0..<8 {
                if g.mode==.Title { break }
                story_test_press(&g,true); settle_transition(&g)
            }
        } else { story_test_whole(&g) }
        assert(g.checkpoint==.Complete && g.mode==.Title && !g.save.dirty)
    case "one-save", "hold":
        continue_run(&g); settle_transition(&g)
        m4_event(&g,"loaded")
        if command=="one-save" { _=persist_game(&g) }
    case "unavailable":
        assert(!g.save.owner); new_run(&g); assert(!g.save.active && g.mode==.Title)
    case "lock-unavailable":
        assert(!g.save.owner && !g.save.busy)
        assert(g.save.message=="Saving is unavailable on this drive.")
        new_run(&g); continue_run(&g)
        assert(!g.save.active && g.mode==.Title)
        assert(save_atomic(&g.save,{.Arrival,{handle=.Installed,phase=.Cleared,crank_progress=1}},g.scene)==.Failed)
    case "busy":
        assert(g.save.busy && !g.save.owner)
        m4_press(&g,0); new_run(&g); continue_run(&g)
        assert(g.mode==.Title && !g.save.active && !g.save.dirty)
        assert(save_atomic(&g.save,{.Arrival,{handle=.Installed,phase=.Cleared,crank_progress=1}},g.scene)==.Failed)
    case "delete-continue", "reread":
        if command=="delete-continue" { _=os.remove(g.save.path) }
        else { m4_event(&g,"before_continue") }
        m4_press(&g,0); settle_transition(&g)
        if !g.save.exists || g.save.rejected { assert(g.mode==.Title && !g.save.active && g.save.loaded==Save_Record{}) }
        else { assert(g.checkpoint==g.save.loaded.checkpoint) }
    case "failed-navigation":
        continue_run(&g); settle_transition(&g)
        fault:=os.get_env("TLS_M4_FAULT",context.temp_allocator)
        target:=os.get_env("TLS_M4_TARGET",context.temp_allocator)
        if target=="Installed" { visit(&g,.Handle) }
        _=os.set_env("TLS_M2_FAULT",fault)
        if target=="Installed" { visit(&g,.Winch) }
        else if g.checkpoint==.Arrival { story_test_press(&g,true); settle_transition(&g) }
        else if g.puzzle.handle==.Dropped || g.puzzle.handle==.Shelf { visit(&g,.Handle) }
        else if g.puzzle.handle==.Installed && g.puzzle.phase==.Blocked { visit(&g,.Winch) }
        else if g.puzzle.phase==.Cranking { for _ in 0..<600 { update_game(&g,{},FIXED_DT) } }
        snapshot:=Save_Record{g.checkpoint,g.puzzle}; cues:=g.completion_cues; story_cues:=g.story_cues
        assert(g.save.dirty)
        pause_game(&g); m4_press(&g,2)
        assert(g.mode==.Save_Failed && g.save.active && g.save.dirty)
        m4_press(&g,0); assert(g.mode==.Save_Failed && g.save.dirty)
        // Return to game retains the exact live state; no cached Continue.
        m4_press(&g,1); assert(Save_Record{g.checkpoint,g.puzzle}==snapshot)
        pause_game(&g); m4_press(&g,2); assert(g.mode==.Save_Failed)
        _=os.unset_env("TLS_M2_FAULT")
        m4_press(&g,0); settle_transition(&g)
        assert(g.mode==.Title && !g.save.dirty && !g.save.active)
        assert(g.completion_cues==cues && g.story_cues==story_cues)
        m4_press(&g,0); settle_transition(&g)
        assert(g.checkpoint==snapshot.checkpoint)
        if snapshot.puzzle.handle==.Held { assert(g.puzzle.handle==.Dropped) }
        else { assert(g.puzzle.handle==snapshot.puzzle.handle && g.puzzle.phase==snapshot.puzzle.phase) }
        assert(g.completion_cues==0)
    case "reload":
        continue_run(&g); settle_transition(&g)
        // Test true live Held and mid-crank state (cold load normalizes both).
        variant:=os.get_env("TLS_M4_LIVE",context.temp_allocator)
        if variant=="Held" { visit(&g,.Handle) }
        if g.puzzle.phase==.Cranking { g.puzzle.crank_progress=0.42 }
        if os.get_env("TLS_M4_PAUSED",context.temp_allocator)=="1" { pause_game(&g) }
        previous:=g.puzzle; mode:=g.mode; story:=g.story
        changed:=os.get_env("TLS_M4_CONTENT",context.temp_allocator)
        assert(reload_runtime_content(&g,&r,[]string{"--project-root",changed}))
        m4_assert(&g)
        assert(g.mode==mode && g.story==story)
        assert(g.puzzle.handle==previous.handle && g.puzzle.phase==previous.phase && g.puzzle.crank_progress==previous.crank_progress && g.puzzle.snail_seen==previous.snail_seen)
        if previous.handle==.Dropped { assert(safe_handle_feet(g.scene,g.puzzle.dropped_feet)) }
        if g.mode==.Paused { update_game(&g,{},0); update_game(&g,{pause=true},0) }
        if g.checkpoint==.Puzzle { _=puzzle_action(&g,.Snail); complete_puzzle(&g) }
        story_test_whole(&g)
        assert(g.checkpoint==.Complete)
    case "snapshot":
        assert(len(r.textures)==10 && m4_live_textures==10)
        rl.BeginDrawing(); draw_game(g); rl.EndDrawing()
    case "assets":
        if upload_requested { _=os.set_env("TLS_M4_UPLOAD_FAIL","1") }
        for _ in 0..<8 {
            before:=r.snapshot; textures:=m4_live_textures; state:=g.puzzle
            bad:=os.get_env("TLS_M4_CONTENT",context.temp_allocator)
            assert(!reload_runtime_content(&g,&r,[]string{"--project-root",bad}))
            assert(r.snapshot==before && m4_live_textures==textures && g.puzzle==state)
            rl.BeginDrawing(); draw_game(g); rl.EndDrawing()
        }
    case "virtual-time":
        continue_run(&g); settle_transition(&g)
        before:=g.puzzle
        pause_game(&g)
        for dt in ([4]f32{-100,0,3600,86400}) { update_game(&g,{},dt); assert(g.puzzle==before) }
        update_game(&g,{pause=true},0)
        // Main loop bounds resume dt; test that same boundary after a long gap.
        update_game(&g,{},min(f32(86400),0.1)); m4_assert(&g)
        story_test_whole(&g)
    case: assert(false,"unknown M4 command")
    }
    m4_assert(&g)
    fmt.eprintln("M4_DONE",command,g.checkpoint,g.mode,"flower",owns_paper_flower(g),"dirty",g.save.dirty,"owner",g.save.owner,"cues",g.completion_cues,g.story_cues)
}
}
