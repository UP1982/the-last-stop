package main

import rl "vendor:raylib"

Input :: struct {
    menu_move: int,
    confirm, pause, fullscreen, return_train, hint, text_page: bool,
    skip, skip_down, pause_down, confirm_down: bool,
    move: f32,
    jump_pressed, jump_down, interact, interact_down: bool,
}

read_input :: proc() -> Input {
    input := Input{}
    input.fullscreen = rl.IsKeyPressed(.F11) ||
        (rl.IsKeyPressed(.ENTER) && (rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)))
    if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) { input.menu_move -= 1 }
    if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) { input.menu_move += 1 }
    // Alt+Enter must not also activate the selected menu item.
    input.confirm = !input.fullscreen &&
        (rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.Z))
    input.return_train = rl.IsKeyPressed(.R)
    input.hint = rl.IsKeyPressed(.H)
    input.text_page = rl.IsKeyPressed(.T)
    input.pause = rl.IsKeyPressed(.ESCAPE)
    input.pause_down = rl.IsKeyDown(.ESCAPE)
    input.skip = rl.IsKeyPressed(.X)
    input.skip_down = rl.IsKeyDown(.X)
    input.confirm_down = rl.IsKeyDown(.ENTER) || rl.IsKeyDown(.SPACE) || rl.IsKeyDown(.Z)
    if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) { input.move -= 1 }
    if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) { input.move += 1 }
    input.jump_pressed = rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.Z) ||
        rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP)
    input.jump_down = rl.IsKeyDown(.SPACE) || rl.IsKeyDown(.Z) ||
        rl.IsKeyDown(.W) || rl.IsKeyDown(.UP)
    input.interact = !input.fullscreen && (rl.IsKeyPressed(.E) || rl.IsKeyPressed(.ENTER))
    input.interact_down = rl.IsKeyDown(.E) || rl.IsKeyDown(.ENTER)
    return input
}
