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

draw_scene :: proc(game: Game_State, interface:=true, draw_player:=true) {
    scene, camera := game.scene, game.camera
    _=art_backdrop(game.content,"bg_forest_track",FOREST_RAIL_OFFSET-camera.y)
    // Background/world are already sorted by layer then stable ID by adapter.
    for object in scene.visuals {
        if object.layer==.Background { draw_scene_visual(game,object) }
    }
    draw_world_rect(scene.solids[0],camera,rl.Color{63,79,70,255})
    for object in scene.visuals {
        if object.layer==.World { draw_scene_visual(game,object) }
    }
    if scene.definition!=nil {
        d:=scene.definition
        b:=branch_rect(scene,game.puzzle)
        winch:=d.objects[d.puzzle.winch]
        a:=d.puzzle.winch_rope_anchor; z:=d.puzzle.branch_rope_anchor
        rl.DrawLineEx({f32(pixel(f32(winch.position[0]+a[0]))-pixel(camera.x)),f32(pixel(f32(winch.position[1]+a[1]))-pixel(camera.y))},{f32(pixel(b.x+f32(z[0]))-pixel(camera.x)),f32(pixel(b.y+f32(z[1]))-pixel(camera.y))},2,CREAM)
        if game.puzzle.handle!=.Held { draw_world_rect(handle_rect(scene,game.puzzle,game.player),camera,MINT) }
        if game.puzzle.handle==.Shelf {
            h:=handle_rect(scene,game.puzzle,game.player)
            draw_world_rect({h.x-12,h.y+h.height,40,4},camera,CREAM)
        }
    }
    if draw_player {
        id:=art_player_asset(PUZZLE_PLAYER_ASSET,game.player)
        if !art_draw(game.content,id,game.player.position,camera,game.art.elapsed,game.player.facing<0) {
            draw_world_rect(player_rect(game.player),camera,CREAM)
        }
        // Held prop is a separate placeholder, in front of Milo, exactly once.
        if scene.definition!=nil && game.puzzle.handle==.Held {
            draw_world_rect(handle_rect(scene,game.puzzle,game.player),camera,MINT)
        }
    }
    for object in scene.visuals {
        if object.layer==.Foreground { draw_scene_visual(game,object) }
    }
    // Focus affordance/UI are drawn after foreground, never hidden by sprites.
    for object, i in scene.objects {
        if !object.enabled { continue }
        if i==game.focus { r:=object.visual; r.x-=4; r.y-=4; r.width+=8; r.height+=8; art_outline(r,camera,CREAM) }
    }
    when DEV_TOOLS {
        if game.art.debug_boxes {
            for solid in scene.solids { art_outline(solid,camera,CREAM) }
            for object in scene.visuals { art_outline(object.rect,camera,rl.Color{232,185,110,255}) }
            for object in scene.objects { if object.enabled { art_outline(object.bounds,camera,MINT) } }
            if draw_player { art_outline(player_rect(game.player),camera,MINT) }
        }
    }
    if !interface { return }
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

draw_scene_visual :: proc(game:Game_State,authored:Scene_Visual) {
    object:=authored
    if game.scene.definition!=nil {
        if object.kind==.Handle { return }
        if object.kind==.Branch { object.rect=branch_rect(game.scene,game.puzzle) }
    }
    if object.asset!="" {
        anchor:=rl.Vector2{object.rect.x,object.rect.y}
        drawn:=false
        if object.kind==.Train {
            anchor={object.rect.x+object.rect.width/2,object.rect.y+object.rect.height}
            drawn=art_train(game.content,object.asset,anchor,game.camera)
        } else { drawn=art_draw(game.content,object.asset,anchor,game.camera) }
        if drawn { return }
    }
    color:=rl.Color{118,131,140,255}
    if object.kind==.Shed { color={68,77,89,255} }
    if object.kind==.Branch { color={118,103,147,255} }
    draw_world_rect(object.rect,game.camera,color)
}

draw_controls :: proc() {
    center_text("Controls", 60, 40, CREAM)
    center_text("Walk: A / D or Left / Right", 124, 20, CREAM)
    center_text("Jump: Space / Z / W / Up", 156, 20, CREAM)
    center_text("Hold jump for a higher hop", 182, 20, MINT)
    center_text("Interact / story advance: E / Enter", 210, 20, CREAM)
    center_text("Story: X skips the scene", 234, 20, MINT)
    center_text("Pause: Esc   Fullscreen: F11", 260, 20, CREAM)
    center_text("Alt + Enter: fullscreen", 284, 20, MINT)
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
    case .Station_Intro, .Train_Travel, .Obstacle_Arrival, .Train_Travel_Resume, .Station_Outro, .Chapter_Complete:
        story_draw(game)
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
        if game.mode==.Paused && game.pause_return_mode!=.Playing { story_draw(game) }
        else { draw_scene(game) }
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
