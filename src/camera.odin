package main

import rl "vendor:raylib"

Camera :: struct { x, y: f32 }

follow_camera :: proc(camera: ^Camera, player_x: f32, bounds: rl.Rectangle, player_y: f32 = 180) {
    DEADZONE :: f32(36)
    centre := camera.x + VIRTUAL_WIDTH / 2
    if player_x < centre - DEADZONE { camera.x = player_x + DEADZONE - VIRTUAL_WIDTH / 2 }
    if player_x > centre + DEADZONE { camera.x = player_x - DEADZONE - VIRTUAL_WIDTH / 2 }
    camera.y = clamp(player_y - VIRTUAL_HEIGHT / 2, bounds.y, max(bounds.y, bounds.y + bounds.height - VIRTUAL_HEIGHT))
    camera.x = clamp(camera.x, bounds.x, max(bounds.x, bounds.x + bounds.width - VIRTUAL_WIDTH))
}
