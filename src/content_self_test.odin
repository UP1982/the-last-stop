#+feature dynamic-literals
package main

import c "../shared/content"
import "core:fmt"
import "core:encoding/json"
import "core:strings"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

when #config(E0B_SELF_TEST, false) {
run_e0b_self_tests :: proc() {
    assert(len(os.args) >= 2)
    expect_invalid := os.args[1] == "invalid"
    tracker: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracker, context.allocator)
    defer mem.tracking_allocator_destroy(&tracker)
    allocator := mem.tracking_allocator(&tracker)
    for _ in 0..<100 {
        runtime := load_runtime_content(os.args[2:], allocator)
        g := Game_State{}
        configure_content(&g, &runtime, runtime.snapshot != nil)
        if expect_invalid {
            assert(runtime.snapshot == nil && !g.content_ready)
            assert(g.mode == .Content_Error && len(runtime.error_lines) > 0)
            update_game(&g, {}, 0)
            update_game(&g, {pause=true}, 0)
            assert(g.mode == .Title)
            update_game(&g, {}, 0)
            update_game(&g, {confirm=true}, 0)
            assert(g.mode == .Content_Error && !g.transitioning)
            update_game(&g, {}, 0)
            update_game(&g, {confirm=true}, 0)
            update_game(&g, {}, 0)
            update_game(&g, {menu_move=1, confirm=true}, 0)
            assert(g.quit_requested) // Quit remains reachable after failed start
        } else {
            assert(runtime.snapshot != nil && g.content_ready)
            def := runtime.scene.definition
            assert(def.id == "oliver_obstacle" && runtime.snapshot.chapter.id == "oliver_flower_market")
            assert(g.scene.world == rect_from_content(def.world_bounds))
            assert(g.scene.camera_bounds == rect_from_content(def.camera_bounds))
            assert(g.scene.solids[0] == rect_from_content(def.ground))
            spawn := def.spawns[def.puzzle.player_spawn].position
            assert(g.scene.spawn == rl.Vector2{f32(spawn[0]),f32(spawn[1])})
            assert(len(g.scene.visuals) == len(def.objects))
            collisions, interactions := 1, 0
            for visual, i in g.scene.visuals {
                object := def.objects[visual.id]
                assert(visual.rect == rl.Rectangle{f32(object.position[0]),f32(object.position[1]),f32(object.size[0]),f32(object.size[1])})
                assert(visual.kind == object.kind && visual.layer == object.layer)
                if i > 0 {
                    prev := g.scene.visuals[i-1]
                    assert(prev.layer < visual.layer || prev.layer == visual.layer && prev.id < visual.id)
                }
                if object.has_collision {
                    assert(g.scene.solids[collisions] == local_rect(object.collision, object.position))
                    collisions += 1
                }
                if object.has_interaction {
                    target := g.scene.objects[visual.interaction_index]
                    assert(target.bounds == local_rect(object.interaction, object.position))
                    assert(target.visual == visual.rect && string(target.label) == string(object.id))
                    interactions += 1
                    // Focus is computed from the loaded world-space zone.
                    p := Player{position={target.bounds.x+target.bounds.width/2, f32(def.ground.y)}}
                    assert(focus_nearest(p, []Interactable{target}) == 0)
                } else { assert(visual.interaction_index == -1) }
            }
            assert(len(g.scene.solids) == collisions && len(g.scene.objects) == interactions)
            if runtime.options.preview_scene != "" {
                assert(g.mode == .Playing && !g.transitioning)
                home, err := os.user_home_dir(context.allocator)
                assert(err == nil)
                expected := fmt.aprintf("%s/Library/Caches/The Last Stop/preview/%s", home, runtime.options.preview_session)
                assert(runtime.preview_directory == expected)
                delete(expected); delete(home)
            } else { assert(g.mode == .Title) }
            start_scene(&g)
            assert(g.player.position == g.scene.spawn && g.player.velocity == rl.Vector2{})
            start_scene(&g)
            assert(g.player.position == g.scene.spawn && g.response == nil)
            // Walk both world edges using exactly the loaded ground/colliders.
            for _ in 0..<1600 { step_player(&g.player, {move=1}, g.scene.solids, g.scene.world) }
            assert(g.player.position.x == g.scene.world.x+g.scene.world.width-PLAYER_WIDTH/2)
            for _ in 0..<1600 { step_player(&g.player, {move=-1}, g.scene.solids, g.scene.world) }
            assert(g.player.position.x == g.scene.world.x+PLAYER_WIDTH/2)
            follow_camera(&g.camera, g.scene.world.x+g.scene.world.width, g.scene.camera_bounds, f32(def.ground.y))
            assert(g.camera.x == g.scene.camera_bounds.x+g.scene.camera_bounds.width-VIRTUAL_WIDTH)
        }
        unload_runtime_content(&runtime)
        unload_runtime_content(&runtime) // clearing makes repeated destruction safe
        assert(len(tracker.allocation_map) == 0, "runtime load/unload leaked")
        assert(len(tracker.bad_free_array) == 0, "runtime attempted an invalid free")
    }
    for id in ([]string{"a", "e0b_test-123", "0123456789012345678901234567890123456789012345678901234567890123"}) { assert(valid_preview_session(id)) }
    for id in ([]string{"", "../save", "UPPER", "a/b", "a.b", "a b", "01234567890123456789012345678901234567890123456789012345678901234"}) { assert(!valid_preview_session(id)) }
    assert(parse_launch_options([]string{"--preview-scene","oliver_obstacle"}).error != "")
    assert(parse_launch_options([]string{"--project-root"}).error != "")
    assert(parse_launch_options([]string{"--preview-scene","unknown","--preview-session","test"}).error != "")
    if expect_invalid { fmt.println("PASS E0b invalid: startup blocked, diagnostics, title/quit, 100 allocation cycles") }
    else { fmt.println("PASS E0b valid: in-game adapter, all authored geometry/spawns/interactions, deterministic order/reset, loaded collision/camera/focus, 100 allocation cycles") }
}
}

// Window-free integration seam: real runtime loader, real response selection,
// loaded dialogue definitions. No save-profile setup or normal-save reads.
when #config(M3A_SELF_TEST, false) {
run_m3a_content_test :: proc() {
    runtime:=load_runtime_content(os.args[1:],context.allocator)
    defer unload_runtime_content(&runtime)
    assert(runtime.snapshot!=nil)
    g:=Game_State{}
    configure_content(&g,&runtime,true)
    g.checkpoint=.Puzzle
    _=puzzle_action(&g,.Install)
    assert(string(g.response)==runtime.snapshot.chapter.strings["needs_handle"])
    responses:=json.Array{string(g.response)}
    for _ in 0..<3 { request_hint(&g); append(&responses,string(g.response)) }
    assert(g.hint_tier==2)
    g.puzzle.handle=.Held
    request_hint(&g); assert(string(g.response)==runtime.snapshot.chapter.strings["held_hint"])
    g.puzzle={handle=.Installed,phase=.Cleared,crank_progress=1}
    request_hint(&g); assert(string(g.response)==runtime.snapshot.chapter.strings["return_hint"])
    // Compiled completion guards still prevent content from bypassing a puzzle.
    g.puzzle={}; g.checkpoint=.Boarded
    enter_arrival(&g); finish_oliver_journey(&g)
    assert(g.checkpoint==.Boarded && !owns_paper_flower(g))
    enter_obstacle(&g); assert(g.checkpoint==.Puzzle && g.puzzle.phase==.Blocked)
    _=puzzle_action(&g,.Return); assert(g.checkpoint==.Puzzle)
    g.puzzle={handle=.Installed,phase=.Cleared,crank_progress=1}
    _=puzzle_action(&g,.Return); enter_arrival(&g)
    finish_oliver_journey(&g); finish_oliver_journey(&g)
    assert(g.checkpoint==.Complete && owns_paper_flower(g))
    docs:=make(json.Object)
    for id,d in runtime.snapshot.dialogues {
        order:=make(json.Array,0,len(d.order)); beats:=make(json.Array,0,len(d.beat_order))
        for line in d.order { append(&order,json.Object{"id"=string(line),"speaker"=string(d.lines[line].speaker),"text"=d.lines[line].text,"delivery"="offscreen" if d.lines[line].delivery==.Offscreen else "onscreen"}) }
        for beat in d.beat_order { append(&beats,string(beat)) }
        docs[string(id)]=json.Object{"order"=order,"beat_order"=beats,"version"=i64(d.schema_version)}
    }
    for s in ([]string{"a — b… 猫",strings.repeat("word ",820),strings.repeat("猫",100),"line one\nline two"}) {
        ends,count:=content_line_ends(s)
        start:=0
        for end in ends[:count] {
            assert(end>=start && end<=len(s))
            if end<len(s) { assert(s[end]&0xc0!=0x80,"text wrapping split UTF-8") }
            columns:=0; for ch in s[start:end] { if ch!='\n' { columns+=1 } }
            assert(columns<=31)
            start=end
        }
        assert(start==len(s))
    }
    fmt.print(string(c.serialize(json.Object{"responses"=responses,"dialogues"=docs,"guarded_complete"=owns_paper_flower(g)})))
}
}
