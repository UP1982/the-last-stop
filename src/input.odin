package main

import rl "vendor:raylib"

Input :: struct {
    menu_move: int,
    confirm, pause, fullscreen: bool,
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
    input.pause = rl.IsKeyPressed(.ESCAPE)
    return input
}
