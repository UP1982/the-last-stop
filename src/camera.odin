package main

import rl "vendor:raylib"

Camera :: struct { x: f32 }

follow_camera :: proc(camera: ^Camera, player_x: f32, bounds: rl.Rectangle) {
    DEADZONE :: f32(18)
    centre := camera.x + VIRTUAL_WIDTH / 2
    if player_x < centre - DEADZONE { camera.x = player_x + DEADZONE - VIRTUAL_WIDTH / 2 }
    if player_x > centre + DEADZONE { camera.x = player_x - DEADZONE - VIRTUAL_WIDTH / 2 }
    camera.x = clamp(camera.x, bounds.x, max(bounds.x, bounds.x + bounds.width - VIRTUAL_WIDTH))
}
