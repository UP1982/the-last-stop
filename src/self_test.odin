package main

import "core:fmt"

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
    assert(g.selection == 1)
    update_game(&g, {confirm = true}, 0)
    update_game(&g, {}, FADE_HALF_SECONDS)
    update_game(&g, {}, FADE_HALF_SECONDS)
    assert(g.mode == .Title && g.selection == 0 && !g.transitioning)
    update_game(&g, {menu_move = 1, confirm = true}, 0)
    assert(g.quit_requested)
    fmt.println("M0 self-tests passed: viewport, mouse bounds, mode transitions, fade input isolation, quit")
}
