package main

import rl "vendor:raylib"

Interactable :: struct {
    bounds, visual: rl.Rectangle,
    label, response: cstring,
    enabled: bool,
}

focus_nearest :: proc(player: Player, objects: []Interactable) -> int {
    best := -1
    distance := f32(1e20)
    body := player_rect(player)
    centre := rl.Vector2{player.position.x, player.position.y - PLAYER_HEIGHT / 2}
    for object, i in objects {
        if !object.enabled { continue }
        r := object.bounds
        dx := centre.x - clamp(centre.x, r.x, r.x + r.width)
        dy := centre.y - clamp(centre.y, r.y, r.y + r.height)
        if !overlaps(body, r) && dx * dx + dy * dy > 20 * 20 { continue }
        // Rank by interaction-zone centre; stable array order resolves ties.
        dx = centre.x - (r.x + r.width / 2)
        dy = centre.y - (r.y + r.height / 2)
        d := dx * dx + dy * dy
        if d < distance { best = i; distance = d }
    }
    return best
}
