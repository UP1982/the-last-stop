package main

import c "../shared/content"
import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

when #config(M2_SELF_TEST,false) || DEV_TOOLS {
settle_transition :: proc(g:^Game_State) {
    for _ in 0..<50 { update_game(g,{},FIXED_DT) }
}
walk_to :: proc(g:^Game_State, x:f32) {
    for _ in 0..<4000 {
        delta:=x-g.player.position.x
        if abs(delta)<0.8 { break }
        move:f32=1; if delta<0 { move=-1 }
        update_game(g,{move=move},FIXED_DT)
    }
    for _ in 0..<25 { update_game(g,{},FIXED_DT) }
    assert(abs(g.player.position.x-x)<8)
}
kind_x :: proc(g:^Game_State, kind:c.Object_Kind) -> f32 {
    refresh_puzzle_objects(g)
    for v in g.scene.visuals {
        if v.kind==kind {
            o:=g.scene.objects[v.interaction_index]
            if kind==.Handle && g.puzzle.handle==.Dropped { return g.puzzle.dropped_feet[0] }
            return o.bounds.x+o.bounds.width/2
        }
    }
    return -1000
}
press_interact :: proc(g:^Game_State) {
    update_game(g,{},FIXED_DT)
    update_game(g,{interact=true,interact_down=true},FIXED_DT)
    update_game(g,{},FIXED_DT)
}
visit :: proc(g:^Game_State,kind:c.Object_Kind) { walk_to(g,kind_x(g,kind)); press_interact(g) }
complete_puzzle :: proc(g:^Game_State) {
    if g.checkpoint>=.Returned { return }
    if g.puzzle.handle==.Shelf || g.puzzle.handle==.Dropped { visit(g,.Handle) }
    if g.puzzle.handle==.Held { visit(g,.Winch) }
    if g.puzzle.phase==.Blocked { visit(g,.Winch) }
    for _ in 0..<600 { update_game(g,{},FIXED_DT) }
    if g.puzzle.phase!=.Cleared { fmt.eprintln("completion failed",g.puzzle,g.checkpoint,g.mode,g.player.position,g.focus) }
    assert(g.puzzle.phase==.Cleared)
    update_game(g,{return_train=true},FIXED_DT)
    assert(g.checkpoint==.Returned && g.mode==.Returned)
}
}

when #config(M2_SELF_TEST,false) {
run_m2_test_entry :: proc() {
    assert(len(os.args)>=2)
    command:=os.args[1]
    runtime:=load_runtime_content(os.args[2:],context.allocator)
    defer unload_runtime_content(&runtime)
    if runtime.snapshot==nil { os.exit(2) }
    if command=="default-path" {
        home,e:=os.user_home_dir(context.allocator); assert(e==nil); defer delete(home)
        directory,ok:=resolve_save_directory({},"",home,"",false); assert(ok)
        fmt.println(directory); return // resolve only: NEVER read/write normal saves
    }
    g:=Game_State{}
    configure_content(&g,&runtime,true)
    configure_save_profile(&g,true)
    defer destroy_save_profile(&g.save)
    if !g.save.enabled { fmt.eprintln("test refuses normal-save fallback"); os.exit(2) }
    switch command {
    case "path": fmt.println(g.save.path); return
    case "inspect":
        if g.save.rejected { os.exit(3) }
        if !g.save.exists { os.exit(1) }
        bytes:=save_encode(g.save.loaded); defer delete(bytes); fmt.print(string(bytes)); return
    case "title-quit":
        // Closing a newly opened title must preserve the existing run/rejection.
        persist_game(&g); fmt.println("PASS title has no active run"); return
    case "keep", "reset":
        assert(g.save.exists)
        original,e:=os.read_entire_file(g.save.path,context.allocator); assert(e==nil); defer delete(original)
        if !g.save.rejected { g.selection=1 }
        update_game(&g,{confirm=true},0); assert(g.mode==.Confirm_New)
        if command=="reset" { g.selection=1 }
        update_game(&g,{confirm=true},0)
        if command=="keep" {
            current,ce:=os.read_entire_file(g.save.path,context.allocator); assert(ce==nil); defer delete(current)
            assert(string(original)==string(current) && g.mode==.Title); return
        }
        settle_transition(&g); assert(!g.save.rejected && g.puzzle.handle==.Shelf)
    case "advance", "drop", "pause-save", "quit-save", "snail":
        if !g.save.exists || g.save.rejected { os.exit(3) }
        update_game(&g,{confirm=true},0); settle_transition(&g)
        if command=="snail" { visit(&g,.Snail); visit(&g,.Snail) }
        else if command=="drop" { walk_to(&g,500); press_interact(&g) }
        else if command=="pause-save" { update_game(&g,{pause=true},0); assert(g.mode==.Paused) }
        else if command=="quit-save" { persist_game(&g) }
        else if g.puzzle.handle==.Shelf || g.puzzle.handle==.Dropped { visit(&g,.Handle) }
        else if g.puzzle.handle==.Held { visit(&g,.Winch) }
        else if g.puzzle.phase==.Blocked { visit(&g,.Winch) }
        else if g.puzzle.phase==.Cranking { for _ in 0..<600 { update_game(&g,{},FIXED_DT) } }
        else { update_game(&g,{return_train=true},FIXED_DT) }
    case "resume":
        if !g.save.exists || g.save.rejected { os.exit(3) }
        // Exercise actual Continue menu and fresh-process normalization.
        update_game(&g,{confirm=true},0); settle_transition(&g)
        p:=g.save.loaded.puzzle; normalize_puzzle(&p,g.scene); assert(p==g.save.loaded.puzzle)
        complete_puzzle(&g)
    case "selftest": run_m2_behavior_tests(&g)
    case "return-edge": run_m2_return_edge_tests(&g)
    case "geometry-path": run_m2_geometry_path(&g)
    case "write-review-drop":
        // Astra's exact dropped-handle reproducer, through movement + E.
        new_run(&g); settle_transition(&g)
        visit(&g,.Handle); walk_to(&g,500)
        for _ in 0..<5 { update_game(&g,{move=1},FIXED_DT) }
        for _ in 0..<25 { update_game(&g,{},FIXED_DT) }
        press_interact(&g)
        assert(g.puzzle.handle==.Dropped && abs(g.puzzle.dropped_feet[0]-497.1536)<0.01)
    case:
        if !strings.has_prefix(command,"write-") { os.exit(2) }
        target:=strings.trim_prefix(command,"write-")
        new_run(&g); settle_transition(&g)
        if target=="chapter_start" { g.checkpoint=.Chapter_Start; persist_game(&g) }
        else if target=="boarded" { g.checkpoint=.Boarded; persist_game(&g) }
        else if target!="shelf" {
            visit(&g,.Handle); assert(g.puzzle.handle==.Held)
            if target=="dropped" { walk_to(&g,500); press_interact(&g); assert(g.puzzle.handle==.Dropped) }
            else if target!="held" {
                visit(&g,.Winch); assert(g.puzzle.handle==.Installed && g.puzzle.phase==.Blocked)
                if target!="installed" {
                    press_interact(&g); assert(g.puzzle.phase==.Cranking)
                    if target!="cranking" {
                        for _ in 0..<600 { update_game(&g,{},FIXED_DT) }
                        assert(g.puzzle.phase==.Cleared)
                        if target!="cleared" {
                            update_game(&g,{return_train=true},FIXED_DT)
                            if target=="arrival" || target=="complete" { g.checkpoint=.Arrival; persist_game(&g) }
                            if target=="complete" { finish_oliver_journey(&g); finish_oliver_journey(&g); assert(owns_paper_flower(g)) }
                        }
                    }
                }
            }
        }
    }
    assert(puzzle_invariant(g.puzzle,g.checkpoint,g.scene))
    if g.save.dirty { if g.save.message=="Saved; disk sync uncertain. Retry pending." { os.exit(5) }; os.exit(4) }
    fmt.println("PASS M2",command,"checkpoint",g.checkpoint,"handle",g.puzzle.handle,"phase",g.puzzle.phase,"cues",g.completion_cues)
}
run_m2_return_edge_tests :: proc(g:^Game_State) {
    // Use only existing public input/state fields so these exact tests can be
    // compiled against e2c6a3e, without backporting the fix.
    g.save.active=false
    g.checkpoint=.Puzzle; g.puzzle={handle=.Installed,phase=.Cleared,crank_progress=1}
    enter_mode(g,.Playing); start_scene(g)
    update_game(g,{return_train=true},FIXED_DT/2)
    assert(g.checkpoint==.Puzzle && g.mode==.Playing)
    update_game(g,{},FIXED_DT/2)
    assert(g.checkpoint==.Returned && g.mode==.Returned, "sub-step R edge must execute on next simulation step")
    returned_player:=g.player
    for _ in 0..<10 { update_game(g,{},FIXED_DT) }
    assert(g.checkpoint==.Returned && g.mode==.Returned && g.player==returned_player)

    // A consumed blocked-return edge cannot fire later when clearance arrives.
    g.checkpoint=.Puzzle; g.puzzle={handle=.Installed,phase=.Cranking,crank_progress=0.99}
    enter_mode(g,.Playing)
    update_game(g,{return_train=true},FIXED_DT/2)
    update_game(g,{},FIXED_DT/2)
    for _ in 0..<10 { update_game(g,{},FIXED_DT) }
    assert(g.puzzle.phase==.Cleared && g.checkpoint==.Puzzle)

    // Pause discards all queued action edges, including a simultaneous R.
    update_game(g,{return_train=true,jump_pressed=true,interact=true},FIXED_DT/2)
    update_game(g,{pause=true,return_train=true},0)
    update_game(g,{pause=true},0)
    update_game(g,{},FIXED_DT)
    assert(g.mode==.Playing && g.checkpoint==.Puzzle && g.player.grounded)
    // Starting a fade clears immediately, and the destination clears again.
    update_game(g,{return_train=true,interact=true},FIXED_DT/2)
    begin_transition(g,.Playing); settle_transition(g)
    assert(g.mode==.Playing && g.checkpoint==.Puzzle)
    update_game(g,{return_train=true,interact=true},FIXED_DT/2)
    enter_mode(g,.Playing); update_game(g,{},FIXED_DT)
    assert(g.checkpoint==.Puzzle)
    // A new press still works; queued R + E cannot activate two targets.
    update_game(g,{return_train=true,interact=true},FIXED_DT/2)
    update_game(g,{},FIXED_DT/2)
    assert(g.checkpoint==.Returned && g.mode==.Returned && !g.puzzle.snail_seen)
    fmt.println("PASS sub-step R: exactly one return; blocked consumption; pause/fade/mode queue clearing; simultaneous R/E")
}

run_m2_geometry_path :: proc(g:^Game_State) {
    // Each externally perturbed, validated fixture must complete using actual
    // fixed-step movement, displayed focus, and fresh input edges, not actions.
    new_run(g); settle_transition(g)
    // Check the displayed focus over the whole grounded pickup envelope,
    // including positions where a competing interaction centre is nearer.
    saved_player:=g.player
    handle_index:=-1
    for v in g.scene.visuals { if v.kind==.Handle { handle_index=v.interaction_index } }
    assert(handle_index>=0)
    target:=g.scene.objects[handle_index]
    for i in 0..<640 {
        x:=g.scene.world.x+PLAYER_WIDTH/2+f32(i)*(g.scene.world.width-PLAYER_WIDTH)/639
        g.player={position={x,g.scene.solids[0].y},grounded=true,facing=1}
        refresh_puzzle_objects(g)
        if focus_nearest(g.player,[]Interactable{target})==0 {
            assert(g.focus==handle_index, "loose pickup within reach must win the displayed focus")
        }
    }
    g.player=saved_player
    complete_puzzle(g)
    assert(g.completion_cues==1)
    new_run(g); settle_transition(g); visit(g,.Handle)
    assert(g.puzzle.handle==.Held)
    // Find an unfocused spot using actual movement, then E to drop and recover.
    dropped:=false
    for i in 0..<32 {
        x:=g.scene.world.x+12+(g.scene.world.width-24)*f32(i)/31
        walk_to(g,x)
        if g.focus>=0 { continue }
        press_interact(g)
        assert(g.puzzle.handle==.Dropped)
        dropped=true
        break
    }
    assert(dropped, "fixture needs at least one unfocused drop point")
    complete_puzzle(g)
    assert(g.checkpoint==.Returned && g.completion_cues==1)
    fmt.println("PASS perturbed geometry: shelf + real-input drop/pickup/install/crank/return completion paths")
}
run_m2_behavior_tests :: proc(g:^Game_State) {
    // Direct real-loop completion.
    new_run(g); settle_transition(g); complete_puzzle(g)
    assert(g.completion_cues==1 && !g.puzzle.snail_seen)
    // Wrong order, repeated drops, airborne drop and pause/held/simultaneous edges.
    new_run(g); settle_transition(g)
    visit(g,.Winch); assert(g.puzzle.handle==.Shelf && g.response==M2_TEXT.needs_handle)
    visit(g,.Train); assert(g.checkpoint==.Puzzle)
    visit(g,.Branch); assert(g.puzzle.phase==.Blocked)
    visit(g,.Handle)
    for _ in 0..<3 {
        walk_to(g,500)
        update_game(g,{jump_pressed=true,jump_down=true,interact=true,interact_down=true},FIXED_DT)
        assert(g.puzzle.handle==.Dropped && safe_handle_feet(g.scene,g.puzzle.dropped_feet))
        for _ in 0..<120 { update_game(g,{},FIXED_DT) }
        visit(g,.Handle); assert(g.puzzle.handle==.Held)
    }
    visit(g,.Snail); visit(g,.Snail); assert(g.puzzle.snail_seen)
    visit(g,.Winch); assert(g.puzzle.handle==.Installed && g.puzzle.phase==.Blocked)
    update_game(g,{interact=true,interact_down=true},FIXED_DT)
    assert(g.puzzle.phase==.Cranking)
    progress:=g.puzzle.crank_progress
    for _ in 0..<20 { update_game(g,{interact=true,interact_down=true},FIXED_DT) }
    assert(g.puzzle.crank_progress>progress)
    update_game(g,{pause=true,interact=true},FIXED_DT)
    frozen:=g.puzzle
    for _ in 0..<120 { update_game(g,{interact=true,return_train=true,move=1},FIXED_DT) }
    assert(g.puzzle==frozen && g.mode==.Paused)
    update_game(g,{pause=true},FIXED_DT); update_game(g,{},FIXED_DT)
    walk_to(g,500) // automatic cranking proceeds away from focus
    complete_puzzle(g); assert(g.completion_cues==1)
    before:=g.checkpoint; _=puzzle_action(g,.Return); assert(g.checkpoint==before && g.completion_cues==1)

    // Enumerate EVERY reachable abstract puzzle state (handle x phase x snail).
    // All actions are applied at every node, and every successor checked. Then
    // demonstrate a completion from each node, without requiring the snail.
    nodes:=0
    for phase in Puzzle_Phase { for handle in Handle_Location { for seen in ([2]bool{false,true}) {
        if phase!=.Blocked && handle!=.Installed { continue }
        initial:=Puzzle_State{handle=handle,phase=phase,snail_seen=seen}
        if handle==.Dropped { initial.dropped_feet=recovery_feet(g.scene) }
        if phase==.Cleared { initial.crank_progress=1 }
        for action in Puzzle_Action {
            g.save.active=false; g.puzzle=initial; g.checkpoint=.Puzzle; enter_mode(g,.Playing); start_scene(g)
            assert(puzzle_invariant(g.puzzle,g.checkpoint,g.scene))
            changed:=puzzle_action(g,action)
            // Invalid action's state must be exactly unchanged.
            valid:=action==.Pickup && (handle==.Shelf || handle==.Dropped) || action==.Drop && handle==.Held ||
                action==.Install && handle==.Held || action==.Activate && handle==.Installed && phase==.Blocked ||
                action==.Return && phase==.Cleared || action==.Snail && !seen
            assert(changed==valid)
            if !valid { assert(g.puzzle==initial && g.checkpoint==.Puzzle) }
            assert(puzzle_invariant(g.puzzle,g.checkpoint,g.scene))
        }
        g.puzzle=initial; g.checkpoint=.Puzzle; g.completion_cues=0; start_scene(g); enter_mode(g,.Playing)
        complete_puzzle(g); assert(g.checkpoint==.Returned)
        nodes+=1
    } } }
    assert(nodes==12)
    for checkpoint in Journey_Checkpoint {
        if checkpoint==.Puzzle { continue }
        g.checkpoint=checkpoint; g.puzzle={}
        if checkpoint>=.Returned { g.puzzle={handle=.Installed,phase=.Cleared,crank_progress=1} }
        before:=g.puzzle
        for action in Puzzle_Action {
            assert(!puzzle_action(g,action) && g.puzzle==before && g.checkpoint==checkpoint)
        }
    }
    // Safe projection at both world edges / invalid and non-finite positions.
    for x in ([4]f32{g.scene.world.x,g.scene.world.x+g.scene.world.width,-10000,10000}) {
        feet:=project_drop(g.scene,{position={x,40}})
        assert(safe_handle_feet(g.scene,feet))
    }
    // Unfocused and out-of-range presses don't act on stale focus.
    g.puzzle={}; g.checkpoint=.Puzzle; start_scene(g); enter_mode(g,.Playing)
    walk_to(g,500); press_interact(g); assert(g.puzzle.handle==.Shelf)
    // Repeat-return and guarded M3 helpers cannot bypass uncleared puzzle.
    board_oliver(g); finish_oliver_journey(g); _=puzzle_action(g,.Return)
    assert(g.checkpoint==.Puzzle && !owns_paper_flower(g^))
    // New Game existing run requires explicit Keep/Replace; default Keep.
    g.save.active=true; g.save.exists=true; g.save.rejected=false; enter_mode(g,.Title)
    update_game(g,{menu_move=1,confirm=true},0); assert(g.mode==.Confirm_New)
    update_game(g,{confirm=true},0); assert(g.mode==.Title)
    update_game(g,{menu_move=1,confirm=true},0); update_game(g,{menu_move=1,confirm=true},0)
    settle_transition(g); assert(g.puzzle.handle==.Shelf && g.checkpoint==.Puzzle)
    complete_puzzle(g)
    fmt.println("PASS M2 behavioral: 12 reachable abstract states x 9 actions; completion reachable from each; direct + drop/wrong-order completions; edge/air drops; held/simultaneous/pause; hints/focus; reset confirmation")
}
}
