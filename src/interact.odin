package main

import rl "vendor:raylib"

Interactable :: struct {
    bounds, visual: rl.Rectangle,
    label, response: cstring,
    enabled: bool,
}

Graybox_Scene :: struct {
    world, camera_bounds: rl.Rectangle,
    spawn: rl.Vector2,
    solids: [8]rl.Rectangle,
    solid_count: int,
    objects: [8]Interactable,
    object_count: int,
    train, branch, shed: rl.Rectangle,
}

// M1 HARDCODED SCENE: sole geometry/default authoring site. E0b replaces this
// constructor with a loaded-scene adapter. Never write these values to data/.
make_graybox_scene :: proc() -> Graybox_Scene {
    return {
        world = {0, 0, 640, 180}, camera_bounds = {0, 0, 640, 180}, spawn = {140, 144},
        solids = {{0, 144, 640, 36}, {344, 140, 32, 4}, {}, {}, {}, {}, {}, {}}, solid_count = 2,
        train = {16, 112, 96, 32}, branch = {96, 120, 48, 24}, shed = {552, 96, 72, 48},
        objects = {
            {{104, 104, 48, 40}, {16, 112, 96, 32}, "Brass", "Brass waits patiently. (Placeholder)", true},
            {{208, 112, 56, 40}, {224, 120, 24, 24}, "Winch", "An empty axle. (Placeholder)", true},
            {{388, 120, 36, 32}, {400, 136, 12, 8}, "Snail", "A tiny neighbour waves. (Placeholder)", true},
            {{572, 120, 40, 32}, {588, 128, 8, 8}, "Handle", "A handle on a shelf. (Placeholder)", true},
            {}, {}, {}, {},
        }, object_count = 4,
    }
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
