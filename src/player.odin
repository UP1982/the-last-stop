package main

import rl "vendor:raylib"

// E0 A1 confirmed: position is the bottom-centre of the 12x16 footprint.
PLAYER_WIDTH :: 12
PLAYER_HEIGHT :: 16
FIXED_DT :: f32(1.0 / 120.0)
COYOTE_SECONDS :: f32(0.1)
JUMP_BUFFER_SECONDS :: f32(0.1)
WALK_SPEED :: f32(72)
GRAVITY :: f32(300)
JUMP_SPEED :: f32(112)
MAX_STEP :: f32(4)

Player :: struct {
    position, velocity: rl.Vector2,
    grounded: bool,
    coyote, jump_buffer: f32,
    facing: int,
}

player_rect :: proc(p: Player) -> rl.Rectangle {
    return {p.position.x - PLAYER_WIDTH / 2, p.position.y - PLAYER_HEIGHT,
        PLAYER_WIDTH, PLAYER_HEIGHT}
}

overlaps :: proc(a, b: rl.Rectangle) -> bool {
    return a.x < b.x + b.width && a.x + a.width > b.x &&
        a.y < b.y + b.height && a.y + a.height > b.y
}

approach :: proc(value, target, amount: f32) -> f32 {
    if value < target { return min(value + amount, target) }
    return max(value - amount, target)
}

try_jump :: proc(p: ^Player) {
    if p.jump_buffer > 0 && (p.grounded || p.coyote > 0) {
        p.velocity.y = -JUMP_SPEED
        p.grounded = false
        p.coyote = 0
        p.jump_buffer = 0
    }
}

// Swept, axis-separated AABBs. The fixed step bounds displacement; crossing
// tests still prevent tunnelling through thin walls and platform tops.
step_player :: proc(p: ^Player, input: Input, solids: []rl.Rectangle, world: rl.Rectangle) {
    dt := FIXED_DT
    if p.grounded { p.coyote = COYOTE_SECONDS }
    else { p.coyote = max(0, p.coyote - dt) }
    p.jump_buffer = max(0, p.jump_buffer - dt)
    if input.jump_pressed { p.jump_buffer = JUMP_BUFFER_SECONDS }
    try_jump(p)
    // Early release cuts only upward speed, preserving a gentle short hop.
    if !input.jump_down && p.velocity.y < -JUMP_SPEED * 0.45 {
        p.velocity.y = -JUMP_SPEED * 0.45
    }
    acceleration: f32 = 480
    if input.move == 0 { acceleration = 600 }
    p.velocity.x = approach(p.velocity.x, clamp(input.move, -1, 1) * WALK_SPEED, acceleration * dt)
    if input.move != 0 { p.facing = 1; if input.move < 0 { p.facing = -1 } }

    old := player_rect(p^)
    next_x := p.position.x + p.velocity.x * dt
    // A tiny step is walkable without jumping. Check headroom against every
    // solid before raising the footprint; taller obstacles remain walls.
    for solid in solids {
        candidate := rl.Rectangle{next_x - PLAYER_WIDTH / 2, p.position.y - PLAYER_HEIGHT,
            PLAYER_WIDTH, PLAYER_HEIGHT}
        rise := p.position.y - solid.y
        if p.grounded && rise > 0 && rise <= MAX_STEP && overlaps(candidate, solid) {
            candidate.y -= rise
            clear := true
            for other in solids { if overlaps(candidate, other) { clear = false; break } }
            if clear { p.position.y = solid.y; old = player_rect(p^) }
        }
    }
    for solid in solids {
        if old.y >= solid.y + solid.height || old.y + old.height <= solid.y { continue }
        if p.velocity.x > 0 && old.x + old.width <= solid.x && next_x + PLAYER_WIDTH / 2 > solid.x {
            next_x = min(next_x, solid.x - PLAYER_WIDTH / 2)
            p.velocity.x = 0
        } else if p.velocity.x < 0 && old.x >= solid.x + solid.width && next_x - PLAYER_WIDTH / 2 < solid.x + solid.width {
            next_x = max(next_x, solid.x + solid.width + PLAYER_WIDTH / 2)
            p.velocity.x = 0
        }
    }
    p.position.x = clamp(next_x, world.x + PLAYER_WIDTH / 2, world.x + world.width - PLAYER_WIDTH / 2)
    if p.position.x != next_x { p.velocity.x = 0 }

    old = player_rect(p^)
    p.velocity.y = min(p.velocity.y + GRAVITY * dt, 180)
    next_y := p.position.y + p.velocity.y * dt
    p.grounded = false
    for solid in solids {
        if old.x >= solid.x + solid.width || old.x + old.width <= solid.x { continue }
        if p.velocity.y >= 0 && p.position.y <= solid.y && next_y >= solid.y {
            next_y = min(next_y, solid.y)
            p.velocity.y = 0
            p.grounded = true
        } else if p.velocity.y < 0 && old.y >= solid.y + solid.height && next_y - PLAYER_HEIGHT < solid.y + solid.height {
            next_y = max(next_y, solid.y + solid.height + PLAYER_HEIGHT)
            p.velocity.y = 0
        }
    }
    p.position.y = next_y
    // Consume a buffered press on this landing, rather than a render later.
    try_jump(p)
}
