package main

import rl "vendor:raylib"
import "core:math"

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

pixel :: proc(value: f32) -> i32 { return i32(math.round(value)) }

draw_world_rect :: proc(rect: rl.Rectangle, camera: Camera, color: rl.Color) {
    rl.DrawRectangle(pixel(rect.x) - pixel(camera.x), pixel(rect.y) - pixel(camera.y),
        pixel(rect.width), pixel(rect.height), color)
}

draw_scene :: proc(game: Game_State) {
    scene, camera := game.scene, game.camera
    draw_world_rect(scene.solids[0], camera, rl.Color{99, 108, 116, 255})
    for authored in scene.visuals {
        object:=authored
        if scene.definition!=nil {
            if object.kind==.Handle { continue }
            if object.kind==.Branch { object.rect=branch_rect(scene,game.puzzle) }
        }
        color := rl.Color{118, 131, 140, 255}
        if object.kind == .Shed { color = {68, 77, 89, 255} }
        if object.kind == .Branch { color = {118, 103, 147, 255} }
        draw_world_rect(object.rect, camera, color)
        if game.content != nil && object.asset != "" {
            if texture, ok := game.content.textures[object.asset]; ok {
                asset := game.content.snapshot.assets[object.asset]
                dest := object.rect; dest.x -= camera.x; dest.y -= camera.y
                dest.x = f32(pixel(dest.x)); dest.y = f32(pixel(dest.y))
                rl.DrawTexturePro(texture, {0, 0, f32(asset.frame_size[0]), f32(asset.frame_size[1])}, dest, {}, 0, rl.WHITE)
            }
        }
    }
    if scene.definition!=nil {
        d:=scene.definition
        b:=branch_rect(scene,game.puzzle)
        winch:=d.objects[d.puzzle.winch]
        a:=d.puzzle.winch_rope_anchor; z:=d.puzzle.branch_rope_anchor
        rl.DrawLine(pixel(f32(winch.position[0]+a[0])-camera.x),pixel(f32(winch.position[1]+a[1])-camera.y),pixel(b.x+f32(z[0])-camera.x),pixel(b.y+f32(z[1])-camera.y),CREAM)
        draw_world_rect(handle_rect(scene,game.puzzle,game.player),camera,MINT)
        if game.puzzle.handle==.Shelf {
            h:=handle_rect(scene,game.puzzle,game.player)
            draw_world_rect({h.x-6,h.y+h.height,20,2},camera,CREAM)
        }
    }
    for object, i in scene.objects {
        if !object.enabled { continue }
        r := object.visual
        x, y := pixel(r.x) - pixel(camera.x), pixel(r.y) - pixel(camera.y)
        if x >= VIRTUAL_WIDTH || x+pixel(r.width) <= 0 || y >= VIRTUAL_HEIGHT || y+pixel(r.height) <= 0 { continue }
        if i == game.focus {
            rl.DrawRectangleLines(x - 2, y - 2, pixel(r.width) + 4, pixel(r.height) + 4, CREAM)
        }
        when DEV_TOOLS {
            zone := object.bounds
            rl.DrawRectangleLines(pixel(zone.x)-pixel(camera.x), pixel(zone.y)-pixel(camera.y), pixel(zone.width), pixel(zone.height), MINT)
        }

    }
    // Placeholder cat: body stays exactly inside the agreed collision footprint.
    x, y := pixel(game.player.position.x) - pixel(camera.x), pixel(game.player.position.y) - pixel(camera.y)
    rl.DrawRectangle(x - 6, y - 16, 12, 16, CREAM)
    rl.DrawRectangle(x - 6, y - 16, 3, 3, MINT)
    rl.DrawRectangle(x + 3, y - 16, 3, 3, MINT)
    eye_x := x + 2
    if game.player.facing < 0 { eye_x = x - 4 }
    rl.DrawRectangle(eye_x, y - 10, 2, 2, NIGHT)
    rl.DrawText("Milo", x - 9, y - 29, 10, CREAM)
    rl.DrawRectangle(0, 0, 320, 28, NIGHT)
    center_text("A D / arrows: walk   Esc: pause", 6, 10, MINT)
    if scene.definition!=nil { center_text(puzzle_hint(game.puzzle),17,10,CREAM) }
    else { center_text("Space / Z / W / Up: jump", 17, 10, CREAM) }
    if game.focus >= 0 {
        rl.DrawRectangle(2, 151, 316, 27, NIGHT)
        center_text("[E / Enter] Interact", 153, 10, CREAM)
        center_text(scene.objects[game.focus].label, 166, 10, MINT)
    }
    if game.focus<0 && game.puzzle.handle==.Held { center_text("[E / Enter] Drop handle",166,10,CREAM) }
    if game.save.message!=nil {
        rl.DrawRectangle(0,137,320,12,NIGHT)
        center_text(game.save.message,138,8,CREAM)
    }
    if game.response_seconds > 0 {
        rl.DrawRectangle(2, 33, 316, 23, NIGHT)
        center_text(game.response, 39, 10, CREAM)
    }
}

draw_controls :: proc() {
    center_text("Controls", 30, 20, CREAM)
    center_text("Walk: A / D or Left / Right", 62, 10, CREAM)
    center_text("Jump: Space / Z / W / Up", 78, 10, CREAM)
    center_text("Hold jump for a higher hop", 91, 10, MINT)
    center_text("Interact: E / Enter", 107, 10, CREAM)
    center_text("Pause: Esc   Fullscreen: F11", 123, 10, CREAM)
    center_text("Alt + Enter: fullscreen", 136, 10, MINT)
    center_text("Esc / Enter / Space / Z: back", 158, 10, CREAM)
}

draw_game :: proc(game: Game_State) {
    rl.ClearBackground(NIGHT)
    switch game.mode {
    case .Title:
        center_text("THE LAST STOP", 35, 20, CREAM)
        center_text("A little further down the line", 63, 10, MINT)
        if game.save.exists && !game.save.rejected {
            menu_item("Continue",0,game.selection,90)
            menu_item("New Game",1,game.selection,109)
            menu_item("Quit",2,game.selection,128)
        } else {
            menu_item("New Game",0,game.selection,99)
            menu_item("Quit",1,game.selection,118)
        }
        if game.save.message!=nil { center_text(game.save.message,171,8,CREAM) }
        center_text("Arrows / W S  -  Enter / Space / Z", 151, 10, MINT)
    case .Confirm_New:
        center_text("Replace existing run?",40,20,CREAM)
        center_text("New Game replaces the saved progress.",70,10,MINT)
        menu_item("Keep run",0,game.selection,104)
        menu_item("Replace / reset",1,game.selection,123)
    case .Returned:
        center_text("Back aboard Brass",48,20,CREAM)
        center_text("The track is clear. Thank you, Milo.",84,10,MINT)
        center_text("M2 complete - story continues in M3",104,10,CREAM)
        center_text("Enter / Esc: title",148,10,MINT)
        if game.save.message!=nil { center_text(game.save.message,171,8,CREAM) }
    case .Content_Error:
        center_text("Content could not load", 10, 20, CREAM)
        center_text("Chapter blocked - diagnostics below", 36, 10, MINT)
        if game.content != nil {
            lines := game.content.error_lines
            for i := 0; i < 7 && game.selection+i < len(lines); i += 1 {
                rl.DrawText(lines[game.selection+i], 8, 54+i32(i)*12, 10, CREAM)
            }
        }
        center_text("Up/Down: scroll   Esc / Enter: title", 151, 10, MINT)
        center_text("Full diagnostics also on stderr", 166, 10, CREAM)
    case .Playing, .Paused:
        draw_scene(game)
        if game.mode == .Paused {
            rl.DrawRectangle(0, 0, 320, 180, rl.Color{0, 0, 0, 170})
            if game.controls_open { draw_controls() }
            else {
                center_text("Paused", 35, 20, CREAM)
                menu_item("Resume", 0, game.selection, 76)
                menu_item("Controls", 1, game.selection, 95)
                menu_item("Quit to Title", 2, game.selection, 114)
                center_text("Esc to resume", 151, 10, MINT)
            }
        }
    }
    if game.transitioning {
        rl.DrawRectangle(0, 0, 320, 180, rl.Color{0, 0, 0, u8(255 * fade_alpha(game))})
    }
}
