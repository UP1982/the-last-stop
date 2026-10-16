package main

import c "../shared/content"
import rl "vendor:raylib"
import "core:math"

VIRTUAL_WIDTH :: c.VIEW_WIDTH
VIRTUAL_HEIGHT :: c.VIEW_HEIGHT

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
        rl.DrawRectangle(200, y - 4, 240, 28, rl.Color{52, 71, 106, 255})
        rl.DrawText(">", 210, y, 20, MINT)
    }
    center_text(text, y, 20, CREAM)
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
        rl.DrawLineEx({f32(pixel(f32(winch.position[0]+a[0])-camera.x)),f32(pixel(f32(winch.position[1]+a[1])-camera.y))},{f32(pixel(b.x+f32(z[0])-camera.x)),f32(pixel(b.y+f32(z[1])-camera.y))},2,CREAM)
        draw_world_rect(handle_rect(scene,game.puzzle,game.player),camera,MINT)
        if game.puzzle.handle==.Shelf {
            h:=handle_rect(scene,game.puzzle,game.player)
            draw_world_rect({h.x-12,h.y+h.height,40,4},camera,CREAM)
        }
    }
    for object, i in scene.objects {
        if !object.enabled { continue }
        r := object.visual
        x, y := pixel(r.x) - pixel(camera.x), pixel(r.y) - pixel(camera.y)
        if x >= VIRTUAL_WIDTH || x+pixel(r.width) <= 0 || y >= VIRTUAL_HEIGHT || y+pixel(r.height) <= 0 { continue }
        if i == game.focus {
            rl.DrawRectangleLinesEx({f32(x - 4), f32(y - 4), f32(pixel(r.width) + 8), f32(pixel(r.height) + 8)}, 2, CREAM)
        }
        when DEV_TOOLS {
            zone := object.bounds
            rl.DrawRectangleLinesEx({f32(pixel(zone.x)-pixel(camera.x)), f32(pixel(zone.y)-pixel(camera.y)), f32(pixel(zone.width)), f32(pixel(zone.height))}, 2, MINT)
        }

    }
    // Placeholder cat: body stays exactly inside the agreed collision footprint.
    x, y := pixel(game.player.position.x) - pixel(camera.x), pixel(game.player.position.y) - pixel(camera.y)
    rl.DrawRectangle(x - 12, y - 32, 24, 32, CREAM)
    rl.DrawRectangle(x - 12, y - 32, 6, 6, MINT)
    rl.DrawRectangle(x + 6, y - 32, 6, 6, MINT)
    eye_x := x + 4
    if game.player.facing < 0 { eye_x = x - 8 }
    rl.DrawRectangle(eye_x, y - 20, 4, 4, NIGHT)
    rl.DrawText("Milo", x - 18, y - 58, 20, CREAM)
    rl.DrawRectangle(0, 0, 640, 88, NIGHT)
    center_text("A D: walk   H: hint   T: text page   Esc: pause", 12, 20, MINT)
    if scene.definition!=nil { draw_content_text(puzzle_hint(game),34,16,CREAM,game.text_page) }
    else { center_text("Space / Z / W / Up: jump", 34, 20, CREAM) }
    if game.focus >= 0 {
        rl.DrawRectangle(4, 302, 632, 54, NIGHT)
        center_text("[E / Enter] Interact", 306, 20, CREAM)
        draw_content_text(scene.objects[game.focus].label, 330, 16, MINT,game.text_page,1)
    }
    if game.focus<0 && game.puzzle.handle==.Held {
        center_text("[E / Enter]",306,20,CREAM)
        draw_content_text(chapter_text(game,"drop"),330,16,CREAM,game.text_page,1)
    }
    if game.save.message!=nil {
        rl.DrawRectangle(0,274,640,24,NIGHT)
        center_text(game.save.message,276,20,CREAM)
    }
    if game.response_seconds > 0 {
        rl.DrawRectangle(4, 92, 632, 66, NIGHT)
        draw_content_text(game.response, 96, 16, CREAM,game.text_page)
    }
}

draw_controls :: proc() {
    center_text("Controls", 60, 40, CREAM)
    center_text("Walk: A / D or Left / Right", 124, 20, CREAM)
    center_text("Jump: Space / Z / W / Up", 156, 20, CREAM)
    center_text("Hold jump for a higher hop", 182, 20, MINT)
    center_text("Interact: E / Enter", 214, 20, CREAM)
    center_text("Pause: Esc   Fullscreen: F11", 246, 20, CREAM)
    center_text("Alt + Enter: fullscreen", 272, 20, MINT)
    center_text("Esc / Enter / Space / Z: back", 316, 20, CREAM)
}

draw_game :: proc(game: Game_State) {
    rl.ClearBackground(NIGHT)
    switch game.mode {
    case .Title:
        center_text("THE LAST STOP", 70, 40, CREAM)
        center_text("A little further down the line", 126, 20, MINT)
        if game.save.exists && !game.save.rejected {
            menu_item("Continue",0,game.selection,180)
            menu_item("New Game",1,game.selection,218)
            menu_item("Quit",2,game.selection,256)
        } else {
            menu_item("New Game",0,game.selection,198)
            menu_item("Quit",1,game.selection,236)
        }
        if game.save.message!=nil { center_text(game.save.message,342,20,CREAM) }
        center_text("Arrows / W S  -  Enter / Space / Z", 302, 20, MINT)
    case .Confirm_New:
        center_text("Replace existing run?",80,40,CREAM)
        center_text("New Game replaces the saved progress.",140,20,MINT)
        menu_item("Keep run",0,game.selection,208)
        menu_item("Replace / reset",1,game.selection,246)
    case .Returned:
        center_text("Back aboard Brass",96,40,CREAM)
        draw_content_text(chapter_text(game,"clear"),168,20,MINT)
        center_text("M2 complete - story continues in M3",208,20,CREAM)
        center_text("Enter / Esc: title",296,20,MINT)
        if game.save.message!=nil { center_text(game.save.message,342,20,CREAM) }
    case .Content_Error:
        center_text("Content could not load", 20, 40, CREAM)
        center_text("Chapter blocked - diagnostics below", 72, 20, MINT)
        if game.content != nil {
            lines := game.content.error_lines
            for i := 0; i < 7 && game.selection+i < len(lines); i += 1 {
                rl.DrawText(lines[game.selection+i], 16, 108+i32(i)*24, 20, CREAM)
            }
        }
        center_text("Up/Down: scroll   Esc / Enter: title", 302, 20, MINT)
        center_text("Full diagnostics also on stderr", 332, 20, CREAM)
    case .Playing, .Paused:
        draw_scene(game)
        if game.mode == .Paused {
            rl.DrawRectangle(0, 0, 640, 360, rl.Color{0, 0, 0, 170})
            if game.controls_open { draw_controls() }
            else {
                center_text("Paused", 70, 40, CREAM)
                menu_item("Resume", 0, game.selection, 152)
                menu_item("Controls", 1, game.selection, 190)
                menu_item("Quit to Title", 2, game.selection, 228)
                center_text("Esc to resume", 302, 20, MINT)
            }
        }
    }
    if game.transitioning {
        rl.DrawRectangle(0, 0, 640, 360, rl.Color{0, 0, 0, u8(255 * fade_alpha(game))})
    }
}
