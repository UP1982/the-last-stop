package main

import "core:fmt"
import c "../shared/content"
import rl "vendor:raylib"

// Run without opening a window: odin run src -define:M0_SELF_TEST=true
when #config(M0_SELF_TEST, false) || #config(M1_SELF_TEST, false) {

run_self_tests :: proc() {
    owner := c.new_owner(context.allocator)
    defer c.destroy_owner(owner)
    context.allocator = c.owner_allocator(owner)
    v := make_viewport(1000, 700)
    assert(v.scale == 1 && v.destination.x == 180 && v.destination.y == 170)
    assert(v.destination.width == 640 && v.destination.height == 360)
    p, inside := mouse_to_virtual({500, 350}, v)
    assert(inside && p.x == 320 && p.y == 180)
    _, outside := mouse_to_virtual({179, 170}, v)
    assert(!outside)
    _, right_edge := mouse_to_virtual({820, 170}, v)
    assert(!right_edge)
    _, bottom_edge := mouse_to_virtual({180, 530}, v)
    assert(!bottom_edge)
    assert(make_viewport(640, 360).scale == 1)
    assert(make_viewport(1280, 720).scale == 2)
    assert(make_viewport(200, 100).scale == 1)
    letterbox := make_viewport(1400, 900)
    assert(letterbox.scale == 2 && letterbox.destination == rl.Rectangle{60,90,1280,720})
    mp, mi := mouse_to_virtual({700,450},letterbox)
    assert(mi && mp == rl.Vector2{320,180})

    g := Game_State{scene=make_graybox_scene(), content_ready=true}
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
    g := Game_State{scene=make_graybox_scene(), content_ready=true}
    start_scene(&g)
    enter_mode(&g, .Playing)
    update_game(&g, {}, FIXED_DT) // release menu aliases
    return g
}

run_m1_self_tests :: proc() {
    world := make_graybox_scene().world
    floor := [1]rl.Rectangle{{0, 288, 1280, 72}}
    ledge := [1]rl.Rectangle{{0, 288, 160, 72}}
    // Actually walk off a ledge, then press inside the coyote window.
    p := Player{position = {171.6, 288}, velocity = {WALK_SPEED, 0}, grounded = true}
    step_player(&p, {move = 1}, ledge[:], world)
    assert(!p.grounded && p.position.y > 288)
    for _ in 0..<6 { step_player(&p, {move = 1}, ledge[:], world) }
    step_player(&p, {jump_pressed = true, jump_down = true}, ledge[:], world)
    assert(p.velocity.y < 0 && p.coyote == 0 && p.jump_buffer == 0)
    p = {position = {171.6, 288}, velocity = {WALK_SPEED, 0}, grounded = true}
    for _ in 0..<16 { step_player(&p, {move = 1}, ledge[:], world) }
    step_player(&p, {jump_pressed = true, jump_down = true}, ledge[:], world)
    assert(p.velocity.y > 0) // late press cannot air-jump

    // Press before landing; jump must fire on contact without another edge.
    p = {position = {300, 280}, velocity = {0, 130}}
    step_player(&p, {jump_pressed = true, jump_down = true}, floor[:], world)
    assert(p.velocity.y > 0 && p.jump_buffer > 0)
    bounced := false
    for _ in 0..<12 {
        step_player(&p, {jump_down = true}, floor[:], world)
        if p.velocity.y < 0 { bounced = true; break }
    }
    assert(bounced && !p.grounded && p.jump_buffer == 0)
    p = {position = {300, 200}}
    step_player(&p, {jump_pressed = true, jump_down = true}, floor[:], world)
    for _ in 0..<120 { step_player(&p, {jump_down = true}, floor[:], world) }
    assert(p.grounded && p.position.y == 288) // expired buffer never jumps

    held := Player{position = {300, 288}, grounded = true}
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
    assert(held_apex < short_apex - 20 && held.grounded && short.grounded)

    // A tall step blocks both directions. The tiny M1 step auto-climbs, never
    // intersects the body, and lets the entire route be walked without jumps.
    walls := [2]rl.Rectangle{floor[0], {400, 240, 40, 48}}
    p = {position = {340, 288}, grounded = true}
    for _ in 0..<120 { step_player(&p, {move = 1}, walls[:], world) }
    assert(p.position.x == 388 && !overlaps(player_rect(p), walls[1]))
    p = {position = {480, 288}, grounded = true}
    for _ in 0..<120 { step_player(&p, {move = -1}, walls[:], world) }
    assert(p.position.x == 452 && !overlaps(player_rect(p), walls[1]))
    ceiling := [2]rl.Rectangle{floor[0], {240, 224, 120, 8}}
    p = {position = {300, 288}, grounded = true}
    step_player(&p, {jump_pressed = true, jump_down = true}, ceiling[:], world)
    for _ in 0..<60 {
        step_player(&p, {jump_down = true}, ceiling[:], world)
        assert(!overlaps(player_rect(p), ceiling[1]))
    }
    scene := make_graybox_scene()
    p = {position = {660, 288}, grounded = true}
    climbed := false
    for _ in 0..<120 {
        step_player(&p, {move = 1}, scene.solids[:], world)
        assert(!overlaps(player_rect(p), scene.solids[1]))
        if p.position.y == 280 { climbed = true }
    }
    assert(climbed && p.position.x > 780 && p.grounded)
    for _ in 0..<1200 { step_player(&p, {move = 1}, floor[:], world) }
    assert(p.position.x == 1268 && p.velocity.x == 0)
    for _ in 0..<1200 { step_player(&p, {move = -1}, floor[:], world) }
    assert(p.position.x == 12 && p.velocity.x == 0)
    p = {position = {300, 288}, grounded = true}
    step_player(&p, {move = 1}, floor[:], world)
    assert(p.velocity.x > 0 && p.velocity.x < WALK_SPEED)
    for _ in 0..<30 { step_player(&p, {move = 1}, floor[:], world) }
    assert(p.velocity.x == WALK_SPEED)
    for _ in 0..<30 { step_player(&p, {}, floor[:], world) }
    assert(p.velocity.x == 0)

    camera := Camera{}
    follow_camera(&camera, 1268, world)
    assert(camera.x == 640)
    follow_camera(&camera, 12, world)
    assert(camera.x == 0)
    follow_camera(&camera, 340, world)
    assert(camera.x == 0) // inside the deadzone
    follow_camera(&camera, 400, world)
    assert(camera.x == 44)
    follow_camera(&camera, -200, {80, 0, 1280, 360})
    assert(camera.x == 80)
    follow_camera(&camera, 2000, {80, 0, 1280, 360})
    assert(camera.x == 720)
    assert(pixel(12.6) == 13 && pixel(-12.6) == -13)

    objects := [2]Interactable{
        {{180, 240, 40, 48}, {}, "left", "left response", true},
        {{240, 240, 40, 48}, {}, "right", "right response", true},
    }
    p = {position = {236, 288}}
    assert(focus_nearest(p, objects[:]) == 1)
    p.position.x = 218
    assert(focus_nearest(p, objects[:]) == 0)
    objects[0].enabled = false
    assert(focus_nearest(p, objects[:]) == 1)
    p.position = {1000, 100}
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
    a.player.position.x = 1000
    enter_mode(&a, .Title)
    update_game(&a, {confirm = true, jump_pressed = true, interact = true}, 0)
    update_game(&a, {}, FADE_HALF_SECONDS)
    update_game(&a, {}, FADE_HALF_SECONDS)
    update_game(&a, {jump_down = true, interact_down = true}, FIXED_DT)
    assert(a.player.position == a.scene.spawn && a.player.grounded && a.response == nil)
    fmt.println("M1 self-tests passed: coyote/expiry, buffer/expiry, variable jump, AABB walls/ceiling/step, world clamp, acceleration, camera/deadzone, nearest focus, interaction, pause/controls isolation, fixed-step/dt clamp, restart")
}

// Synthetic M1 regression fixture only. Runtime has no fallback authoring site.
make_graybox_scene :: proc() -> Runtime_Scene {
    scene := Runtime_Scene{
        world={0,0,1280,360}, camera_bounds={0,0,1280,360}, spawn={280,288},
        solids=make([]rl.Rectangle,2), objects=make([]Interactable,4),
    }
    scene.solids[0]={0,288,1280,72}; scene.solids[1]={688,280,64,8}
    scene.objects[0]={{208,208,96,80},{32,224,192,64},"Brass","Brass waits patiently. (Placeholder)",true}
    scene.objects[1]={{416,224,112,80},{448,240,48,48},"Winch","An empty axle. (Placeholder)",true}
    scene.objects[2]={{776,240,72,64},{800,272,24,16},"Snail","A tiny neighbour waves. (Placeholder)",true}
    scene.objects[3]={{1144,240,80,64},{1176,256,16,16},"Handle","A handle on a shelf. (Placeholder)",true}
    return scene
}
}
