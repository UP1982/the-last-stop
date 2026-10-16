package main

import rl "vendor:raylib"

VIRTUAL_WIDTH :: 320
VIRTUAL_HEIGHT :: 180

Viewport :: struct {
    scale: i32,
    destination: rl.Rectangle,
}

make_viewport :: proc(width, height: i32) -> Viewport {
    // Minimum window is 640x360. If an OS forces smaller dimensions, retain
    // scale 1 (cropped rather than fractional pixels) as the explicit fallback.
    scale := max(1, min(width / VIRTUAL_WIDTH, height / VIRTUAL_HEIGHT))
    w, h := VIRTUAL_WIDTH * scale, VIRTUAL_HEIGHT * scale
    return {scale, {f32((width - w) / 2), f32((height - h) / 2), f32(w), f32(h)}}
}

// Uses raylib screen/mouse coordinates. Do not clamp letterbox clicks into
// the canvas: callers must check inside before using the returned position.
mouse_to_virtual :: proc(mouse: rl.Vector2, viewport: Viewport) -> (position: rl.Vector2, inside: bool) {
    d := viewport.destination
    position = {(mouse.x - d.x) / f32(viewport.scale), (mouse.y - d.y) / f32(viewport.scale)}
    inside = position.x >= 0 && position.y >= 0 &&
        position.x < VIRTUAL_WIDTH && position.y < VIRTUAL_HEIGHT
    return
}

CREAM :: rl.Color{242, 220, 202, 255}
MINT :: rl.Color{169, 209, 187, 255}
NIGHT :: rl.Color{28, 36, 59, 255}

center_text :: proc(text: cstring, y, size: i32, color: rl.Color) {
    rl.DrawText(text, (VIRTUAL_WIDTH - rl.MeasureText(text, size)) / 2, y, size, color)
}

menu_item :: proc(text: cstring, row, selected: int, y: i32) {
    if row == selected {
        rl.DrawRectangle(100, y - 2, 120, 14, rl.Color{52, 71, 106, 255})
        rl.DrawText(">", 105, y, 10, MINT)
    }
    center_text(text, y, 10, CREAM)
}

draw_game :: proc(game: Game_State) {
    rl.ClearBackground(NIGHT)
    switch game.mode {
    case .Title:
        center_text("THE LAST STOP", 35, 20, CREAM)
        center_text("A little further down the line", 63, 10, MINT)
        menu_item("Start", 0, game.selection, 99)
        menu_item("Quit", 1, game.selection, 118)
        center_text("Arrows / W S  -  Enter / Space / Z", 151, 10, MINT)
    case .Playing, .Paused:
        rl.DrawRectangle(0, 130, 320, 50, rl.Color{52, 71, 106, 255})
        rl.DrawRectangle(45, 112, 85, 28, rl.Color{118, 103, 147, 255})
        rl.DrawRectangle(52, 117, 17, 10, rl.Color{232, 185, 110, 255})
        rl.DrawRectangle(76, 117, 17, 10, rl.Color{232, 185, 110, 255})
        if game.mode == .Playing {
            center_text("The journey begins here", 38, 10, CREAM)
            center_text("M0 placeholder - Esc to pause", 57, 10, MINT)
        } else {
            rl.DrawRectangle(0, 0, 320, 180, rl.Color{0, 0, 0, 170})
            center_text("Paused", 45, 20, CREAM)
            menu_item("Resume", 0, game.selection, 86)
            menu_item("Quit to Title", 1, game.selection, 107)
            center_text("Esc to resume", 147, 10, MINT)
        }
    }
    if game.transitioning {
        rl.DrawRectangle(0, 0, 320, 180, rl.Color{0, 0, 0, u8(255 * fade_alpha(game))})
    }
}
