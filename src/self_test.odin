package main

import "core:fmt"
import rl "vendor:raylib"

// Run without opening a window: odin run src -define:M0_SELF_TEST=true
run_self_tests :: proc() {
    v := make_viewport(1000, 700)
    assert(v.scale == 3 && v.destination.x == 20 && v.destination.y == 80)
    assert(v.destination.width == 960 && v.destination.height == 540)
    p, inside := mouse_to_virtual({500, 350}, v)
    assert(inside && p.x == 160 && p.y == 90)
    _, outside := mouse_to_virtual({19, 80}, v)
    assert(!outside)
    _, right_edge := mouse_to_virtual({980, 80}, v)
    assert(!right_edge)
    assert(make_viewport(640, 360).scale == 2)
    assert(make_viewport(1280, 720).scale == 4)
    assert(make_viewport(200, 100).scale == 1)

    g := Game_State{}
    update_game(&g, {pause = true}, 0)
    assert(g.mode == .Title && !g.quit_requested)
    update_game(&g, {confirm = true}, 0)
    assert(g.transitioning && g.mode == .Title)
    update_game(&g, {}, FADE_HALF_SECONDS)
    assert(g.mode == .Playing && fade_alpha(g) == 1)
    update_game(&g, {pause = true, confirm = true}, FADE_HALF_SECONDS)
    assert(!g.transitioning && g.mode == .Playing)
    update_game(&g, {pause = true}, 0)
    assert(g.mode == .Paused && g.selection == 0)
    update_game(&g, {confirm = true}, 0)
    assert(g.mode == .Playing)
    update_game(&g, {pause = true}, 0)
    update_game(&g, {menu_move = -1}, 0)
    assert(g.selection == 2)
    update_game(&g, {confirm = true}, 0)
    update_game(&g, {}, FADE_HALF_SECONDS)
    update_game(&g, {}, FADE_HALF_SECONDS)
    assert(g.mode == .Title && g.selection == 0 && !g.transitioning)
    update_game(&g, {menu_move = 1, confirm = true}, 0)
    assert(g.quit_requested)
    fmt.println("M0 self-tests passed: viewport, mouse bounds, mode transitions, fade input isolation, quit")
    run_m1_self_tests()
}

test_playing_game :: proc() -> Game_State {
    g := Game_State{}
    start_graybox(&g)
    enter_mode(&g, .Playing)
    update_game(&g, {}, FIXED_DT) // release menu aliases
    return g
}

run_m1_self_tests :: proc() {
    world := make_graybox_scene().world
    floor := [1]rl.Rectangle{{0, 144, 640, 36}}
    ledge := [1]rl.Rectangle{{0, 144, 80, 36}}
    // Actually walk off a ledge, then press inside the coyote window.
    p := Player{position = {85.8, 144}, velocity = {WALK_SPEED, 0}, grounded = true}
    step_player(&p, {move = 1}, ledge[:], world)
    assert(!p.grounded && p.position.y > 144)
    for _ in 0..<6 { step_player(&p, {move = 1}, ledge[:], world) }
    step_player(&p, {jump_pressed = true, jump_down = true}, ledge[:], world)
    assert(p.velocity.y < 0 && p.coyote == 0 && p.jump_buffer == 0)
    p = {position = {85.8, 144}, velocity = {WALK_SPEED, 0}, grounded = true}
    for _ in 0..<16 { step_player(&p, {move = 1}, ledge[:], world) }
    step_player(&p, {jump_pressed = true, jump_down = true}, ledge[:], world)
    assert(p.velocity.y > 0) // late press cannot air-jump

    // Press before landing; jump must fire on contact without another edge.
    p = {position = {150, 140}, velocity = {0, 65}}
    step_player(&p, {jump_pressed = true, jump_down = true}, floor[:], world)
    assert(p.velocity.y > 0 && p.jump_buffer > 0)
    bounced := false
    for _ in 0..<12 {
        step_player(&p, {jump_down = true}, floor[:], world)
        if p.velocity.y < 0 { bounced = true; break }
    }
    assert(bounced && !p.grounded && p.jump_buffer == 0)
    p = {position = {150, 100}}
    step_player(&p, {jump_pressed = true, jump_down = true}, floor[:], world)
    for _ in 0..<120 { step_player(&p, {jump_down = true}, floor[:], world) }
    assert(p.grounded && p.position.y == 144) // expired buffer never jumps

    held := Player{position = {150, 144}, grounded = true}
    short := held
    step_player(&held, {jump_pressed = true, jump_down = true}, floor[:], world)
    short = held
    held_apex, short_apex := held.position.y, short.position.y
    for _ in 0..<100 {
        step_player(&held, {jump_down = true}, floor[:], world)
        step_player(&short, {}, floor[:], world)
        held_apex = min(held_apex, held.position.y)
        short_apex = min(short_apex, short.position.y)
    }
    assert(held_apex < short_apex - 10 && held.grounded && short.grounded)

    // A tall step blocks both directions. The tiny M1 step auto-climbs, never
    // intersects the body, and lets the entire route be walked without jumps.
    walls := [2]rl.Rectangle{floor[0], {200, 120, 20, 24}}
    p = {position = {170, 144}, grounded = true}
    for _ in 0..<120 { step_player(&p, {move = 1}, walls[:], world) }
    assert(p.position.x == 194 && !overlaps(player_rect(p), walls[1]))
    p = {position = {240, 144}, grounded = true}
    for _ in 0..<120 { step_player(&p, {move = -1}, walls[:], world) }
    assert(p.position.x == 226 && !overlaps(player_rect(p), walls[1]))
    ceiling := [2]rl.Rectangle{floor[0], {120, 112, 60, 4}}
    p = {position = {150, 144}, grounded = true}
    step_player(&p, {jump_pressed = true, jump_down = true}, ceiling[:], world)
    for _ in 0..<60 {
        step_player(&p, {jump_down = true}, ceiling[:], world)
        assert(!overlaps(player_rect(p), ceiling[1]))
    }
    scene := make_graybox_scene()
    p = {position = {330, 144}, grounded = true}
    climbed := false
    for _ in 0..<120 {
        step_player(&p, {move = 1}, scene.solids[:scene.solid_count], world)
        assert(!overlaps(player_rect(p), scene.solids[1]))
        if p.position.y == 140 { climbed = true }
    }
    assert(climbed && p.position.x > 390 && p.grounded)
    for _ in 0..<1200 { step_player(&p, {move = 1}, floor[:], world) }
    assert(p.position.x == 634 && p.velocity.x == 0)
    for _ in 0..<1200 { step_player(&p, {move = -1}, floor[:], world) }
    assert(p.position.x == 6 && p.velocity.x == 0)
    p = {position = {150, 144}, grounded = true}
    step_player(&p, {move = 1}, floor[:], world)
    assert(p.velocity.x > 0 && p.velocity.x < WALK_SPEED)
    for _ in 0..<30 { step_player(&p, {move = 1}, floor[:], world) }
    assert(p.velocity.x == WALK_SPEED)
    for _ in 0..<30 { step_player(&p, {}, floor[:], world) }
    assert(p.velocity.x == 0)

    camera := Camera{}
    follow_camera(&camera, 634, world)
    assert(camera.x == 320)
    follow_camera(&camera, 6, world)
    assert(camera.x == 0)
    follow_camera(&camera, 170, world)
    assert(camera.x == 0) // inside the deadzone
    follow_camera(&camera, 200, world)
    assert(camera.x == 22)
    follow_camera(&camera, -100, {40, 0, 640, 180})
    assert(camera.x == 40)
    follow_camera(&camera, 1000, {40, 0, 640, 180})
    assert(camera.x == 360)
    assert(pixel(12.6) == 13 && pixel(-12.6) == -13)

    objects := [2]Interactable{
        {{90, 120, 20, 24}, {}, "left", "left response", true},
        {{120, 120, 20, 24}, {}, "right", "right response", true},
    }
    p = {position = {118, 144}}
    assert(focus_nearest(p, objects[:]) == 1)
    p.position.x = 109
    assert(focus_nearest(p, objects[:]) == 0)
    objects[0].enabled = false
    assert(focus_nearest(p, objects[:]) == 1)
    p.position = {500, 50}
    assert(focus_nearest(p, objects[:]) == -1)

    g := test_playing_game()
    update_game(&g, {interact = true}, FIXED_DT)
    assert(g.focus == 0 && g.response == g.scene.objects[0].response && g.response_seconds > 0)
    update_game(&g, {pause = true, jump_pressed = true, interact = true}, FIXED_DT)
    frozen := g
    for _ in 0..<120 {
        update_game(&g, {move = 1, jump_pressed = true, jump_down = true, interact = true}, FIXED_DT)
    }
    assert(g.mode == .Paused && g.player == frozen.player && g.camera == frozen.camera)
    assert(g.response_seconds == frozen.response_seconds && !g.pending_jump && !g.pending_interact)
    update_game(&g, {menu_move = 1, confirm = true}, FIXED_DT)
    assert(g.controls_open && g.mode == .Paused)
    update_game(&g, {confirm = true, jump_pressed = true, interact = true}, FIXED_DT)
    assert(!g.controls_open && g.mode == .Paused && g.player == frozen.player)
    update_game(&g, {pause = true, jump_pressed = true, jump_down = true, interact = true, interact_down = true}, FIXED_DT)
    assert(g.mode == .Playing)
    update_game(&g, {jump_pressed = true, jump_down = true, interact = true, interact_down = true}, FIXED_DT)
    assert(g.player.grounded && g.response_seconds < frozen.response_seconds)
    update_game(&g, {}, FIXED_DT)
    update_game(&g, {jump_pressed = true, jump_down = true}, FIXED_DT)
    assert(g.player.velocity.y < 0)

    // Fixed-step frame grouping, pending edges on fast frames, and dt clamp.
    a, b := test_playing_game(), test_playing_game()
    for _ in 0..<60 { update_game(&a, {move = 1}, FIXED_DT * 2) }
    for _ in 0..<30 { update_game(&b, {move = 1}, FIXED_DT * 4) }
    assert(abs(a.player.position.x - b.player.position.x) < 0.001)
    update_game(&a, {jump_pressed = true, jump_down = true}, 0)
    assert(a.pending_jump)
    update_game(&a, {jump_down = true}, FIXED_DT)
    assert(a.player.velocity.y < 0 && !a.pending_jump)
    a = test_playing_game()
    b = a
    update_game(&a, {move = 1}, 10)
    update_game(&b, {move = 1}, 0.1)
    assert(a.player == b.player)
    // A new title/start resets the player; its confirm cannot jump/interact.
    a.player.position.x = 500
    enter_mode(&a, .Title)
    update_game(&a, {confirm = true, jump_pressed = true, interact = true}, 0)
    update_game(&a, {}, FADE_HALF_SECONDS)
    update_game(&a, {}, FADE_HALF_SECONDS)
    update_game(&a, {jump_down = true, interact_down = true}, FIXED_DT)
    assert(a.player.position == a.scene.spawn && a.player.grounded && a.response == nil)
    fmt.println("M1 self-tests passed: coyote/expiry, buffer/expiry, variable jump, AABB walls/ceiling/step, world clamp, acceleration, camera/deadzone, nearest focus, interaction, pause/controls isolation, fixed-step/dt clamp, restart")
}
