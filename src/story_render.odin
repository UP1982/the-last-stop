package main

import c "../shared/content"
import rl "vendor:raylib"
import "core:fmt"

story_camera :: proc(g: Game_State, stage: c.Story_Stage_Def) -> Camera {
    camera:=Camera{}
    if stage.set!=.Forest_Obstacle { return camera }
    if stage.shot==.Winch_Branch {
        d:=g.scene.definition
        b:=branch_rect(g.scene,g.puzzle)
        w:=d.objects[d.puzzle.winch]
        centre:=(b.x+b.width/2+f32(w.position[0])+f32(w.size[0])/2)/2
        camera.x=clamp(centre-320,g.scene.camera_bounds.x,max(g.scene.camera_bounds.x,g.scene.camera_bounds.x+g.scene.camera_bounds.width-640))
    }
    return camera
}
story_heading :: proc(set:c.Story_Set,shot:c.Story_Shot) -> cstring {
    switch set {
    case .Willow_Platform: if shot==.Old_Platform { return "Willow Creek - The Last Stop platform" }; return "Willow Creek Station"
    case .Carriage: return "Aboard Brass"
    case .Forest_Travel: return "A little way through the valley"
    case .Forest_Obstacle: return "A branch across the line"
    case .Market_Platform: return "Clover Market Halt"
    case .Flower_Window: return "Oliver's paper flower"
    }
    return ""
}
story_cue_label :: proc(cue:c.Story_Cue) -> cstring {
    switch cue {
    case .None: return ""
    case .Whistle_Low: return "Brass: a low whistle"
    case .Door_Squeak: return "The door squeaks"
    case .Wheels: return "Wheels along the rails"
    case .Brake_Soft: return "Brass gently stops"
    case .Paper_Rustle: return "Paper rustles"
    case .Whistle_Depart: return "Brass whistles goodbye"
    }
    return ""
}
story_prop_bounds :: proc(prop:c.Prop_Def,camera:Camera) -> rl.Rectangle {
    w,h:=i32(30),i32(24)
    switch prop.kind {
    case .Train: w=210;h=86
    case .Door: w=32;h=66
    case .Bag: w=36;h=26
    case .Flowerpot: w=26;h=30
    case .Paper_Flower: w=24;h=20
    case .Slat: w=64;h=6
    case .Bench: w=100;h=20
    case .Timetable: w=38;h=48
    case .Sign: w=90;h=28
    case .Notice: w=52;h=36
    case .Market_Dressing: w=110;h=64
    }
    return {f32(prop.position[0]-pixel(camera.x)),f32(prop.position[1]-pixel(camera.y)),f32(w),f32(h)}
}
story_draw_prop :: proc(prop: c.Prop_Def, camera: Camera) {
    rect:=story_prop_bounds(prop,camera)
    x,y,w,h:=pixel(rect.x),pixel(rect.y),pixel(rect.width),pixel(rect.height)
    color:=MINT
    switch prop.kind {
    case .Train: color={78,101,109,255}
    case .Door: color={180,143,105,255}
    case .Bag: color={155,118,88,255}
    case .Flowerpot: color={181,126,99,255}
    case .Paper_Flower: color=CREAM
    case .Slat: color={193,157,119,255}
    case .Bench: color={153,126,100,255}
    case .Market_Dressing: color={141,120,95,255}
    case .Timetable,.Sign,.Notice: color=MINT
    }
    rl.DrawRectangle(x,y,w,h,color)
    rl.DrawRectangleLines(x,y,w,h,CREAM)
    if prop.kind==.Notice {
        // Rin's portrait on the fixed supper notice, using the same gray
        // placeholder and eye mask as her prologue actor. No collectible flag.
        rl.DrawRectangle(x+4,y+4,16,22,rl.Color{160,163,169,255})
        rl.DrawRectangle(x+4,y+10,16,5,NIGHT)
        rl.DrawRectangle(x+7,y+11,2,2,CREAM)
        rl.DrawRectangle(x+15,y+11,2,2,CREAM)
    }
    if prop.kind==.Train {
        for i in 0..<4 { rl.DrawRectangle(x+12+i32(i)*44,y+12,30,30,CREAM) }
    }
    if prop.kind==.Flowerpot && prop.state=="bloom" {
        rl.DrawLine(x+13,y,x+13,y-22,MINT)
        rl.DrawCircle(x+13,y-24,8,CREAM)
    }
    if prop.kind==.Paper_Flower {
        rl.DrawLine(x+12,y+h,x+12,y+2,MINT)
        rl.DrawRectangle(x+6,y-4,12,12,CREAM)
        rl.DrawRectangle(x+2,y,20,4,CREAM)
    }
}
story_draw_actor :: proc(g: Game_State,id:c.ID,a:c.Actor_Def,camera:Camera) {
    x,y:=a.feet[0]-pixel(camera.x),a.feet[1]-pixel(camera.y)
    color:=CREAM
    if id=="milo" { color={221,157,100,255} }
    if id=="rin" { color={160,163,169,255} }
    rl.DrawRectangle(x-12,y-36,24,36,color)
    if id=="oliver" { rl.DrawRectangle(x-10,y-52,6,18,color); rl.DrawRectangle(x+4,y-52,6,18,color) }
    if id=="milo" {
        rl.DrawRectangle(x-12,y-36,6,6,color); rl.DrawRectangle(x+6,y-36,6,6,color)
        rl.DrawRectangle(x-12,y-22,24,5,rl.Color{186,82,71,255})
        rl.DrawRectangle(x-20,y-21,8,17,rl.Color{124,109,82,255})
    }
    eye:=x+5; if a.facing=="left" { eye=x-8 }
    rl.DrawRectangle(eye,y-29,3,3,NIGHT)
    if a.pose==.Point || a.pose==.Reach || a.pose==.Wave || a.pose==.Tap {
        end:=x+28; if a.facing=="left" { end=x-28 }
        rl.DrawLineEx({f32(x),f32(y-19)},{f32(end),f32(y-25)},4,color)
    }
}
// Labels are UI pixels, outside the scene's 0.7x camera transform. Reserve
// silhouettes first, then names before prop captions. A crowded caption may
// be omitted rather than cover an actor, another caption, or the dialogue UI.
story_label_screen_rect :: proc(r:rl.Rectangle) -> rl.Rectangle {
    return {f32(pixel(96+r.x*0.7)),f32(pixel(4+r.y*0.7)),f32(pixel(r.width*0.7)),f32(pixel(r.height*0.7))}
}
story_actor_bounds :: proc(a:c.Actor_Def,camera:Camera) -> rl.Rectangle {
    return {f32(a.feet[0]-pixel(camera.x)-20),f32(a.feet[1]-pixel(camera.y)-54),48,54}
}
story_place_label :: proc(label:cstring,object:rl.Rectangle,occupied:^[dynamic]rl.Rectangle) {
    width:=rl.MeasureText(label,20)+8
    if width>624 { return }
    x:=clamp(pixel(object.x+object.width/2)-width/2,8,632-width)
    for attempt in 0..<7 {
        y:=pixel(object.y)-26-i32(attempt)*24
        if y<68 { break } // keep cue/header and notice bands clear
        if y+24>228 { continue }
        box:=rl.Rectangle{f32(x),f32(y),f32(width),24}
        clear:=true
        for other in occupied^ {
            if rl.CheckCollisionRecs(box,other) { clear=false; break }
        }
        if !clear { continue }
        rl.DrawRectangleRec(box,NIGHT)
        rl.DrawText(label,x+4,y+2,20,CREAM)
        append(occupied,box)
        return
    }
}
story_draw_labels :: proc(g:Game_State,stage:c.Story_Stage_Def,camera:Camera) {
    occupied:=make([dynamic]rl.Rectangle,context.temp_allocator)
    for _,prop in stage.props { append(&occupied,story_label_screen_rect(story_prop_bounds(prop,camera))) }
    for _,actor in stage.actors { append(&occupied,story_label_screen_rect(story_actor_bounds(actor,camera))) }
    if stage.set==.Carriage { append(&occupied,rl.Rectangle{8,68,624,42}) }
    if stage.shot==.Supper_Card { append(&occupied,rl.Rectangle{8,154,624,76}) }
    for id,actor in stage.actors {
        name:=fmt.ctprintf("%s",g.content.snapshot.chapter.speakers[id].name)
        story_place_label(name,story_label_screen_rect(story_actor_bounds(actor,camera)),&occupied)
    }
    for _,prop in stage.props {
        label:=fmt.ctprintf("%v: %s",prop.kind,prop.state)
        story_place_label(label,story_label_screen_rect(story_prop_bounds(prop,camera)),&occupied)
    }
}
story_draw :: proc(game: Game_State) {
    g:=game // Accessors borrow the immutable content; drawing changes no state.
    b:=story_beat(&g); if b==nil { return }
    stage:=b.stage
    center_text(story_heading(stage.set,stage.shot),12,24,CREAM)
    shot_labels:= [c.Story_Shot]cstring{.Wide="Wide view",.Passenger_Pair="Milo and Oliver",.Old_Platform="The old supper platform",.Winch_Branch="The branch, rope and winch",.Flower="The flowers",.Supper_Card="The supper notice"}
    center_text(shot_labels[stage.shot],36,12,MINT)
    camera:=story_camera(game,stage)
    rl.BeginScissorMode(0,46,640,184)
    rl.DrawRectangle(0,46,640,184,rl.Color{63,79,85,255})
    rl.BeginMode2D({offset={96,4},target={},rotation=0,zoom=0.7})
    moving:=stage.set==.Forest_Travel || stage.set==.Carriage
    if moving {
        offset:=i32(game.story.travel_elapsed*28)%120
        for i in 0..<8 {
            x:=i32(i)*120-offset-80
            rl.DrawRectangle(x,50,12,230,rl.Color{42,65,66,255})
            rl.DrawTriangle({f32(x-34),150},{f32(x+46),150},{f32(x+6),45},MINT)
        }
    }
    if stage.set==.Forest_Obstacle {
        world:=game; world.camera=camera; world.focus=-1
        draw_scene(world,false,false)
        d:=game.scene.definition
        branch:=branch_rect(game.scene,game.puzzle)
        winch:=d.objects[d.puzzle.winch]
        socket:=d.puzzle.winch_socket
        sx,sy:=winch.position[0]+socket[0]-pixel(camera.x),winch.position[1]+socket[1]-pixel(camera.y)
        rl.DrawCircleLines(sx,sy,6,CREAM)
    } else {
        rl.DrawRectangle(0,284,640,10,CREAM)
        if stage.set==.Forest_Travel || stage.set==.Flower_Window || stage.set==.Carriage {
            rl.DrawRectangle(72,100,480,150,rl.Color{94,109,117,255})
            rl.DrawRectangle(92,116,440,100,NIGHT)
        }
    }
    for _,prop in stage.props { story_draw_prop(prop,camera) }
    for id,actor in stage.actors { story_draw_actor(game,id,actor,camera) }
    rl.EndMode2D()
    story_draw_labels(game,stage,camera)
    rl.EndScissorMode()
    if game.story.cue_seconds>0 {
        rl.DrawRectangle(8,44,624,22,NIGHT)
        center_text(story_cue_label(game.story.cue),46,16,MINT)
    }
    // The notice is present from the first interior shot, independent of a
    // collectible. The card beat and notice shot expand it as legible UI below.
    if stage.set==.Carriage {
        rl.DrawRectangle(8,68,624,42,NIGHT)
        center_text("WILLOW CREEK PLATFORM SUPPER",70,16,CREAM)
        draw_story_glyphs("— ALL WELCOME",(640-story_text_width("— ALL WELCOME"))/2,90,MINT)
    }
    rl.DrawRectangle(8,232,624,124,NIGHT)
    rl.DrawRectangleLines(8,232,624,124,MINT)
    text:=story_text(&g)
    speaker:=""
    if b.kind==.Line {
        line:=story_dialogue(&g).lines[b.line]
        speaker=g.content.snapshot.chapter.speakers[line.speaker].name
        if line.delivery==.Offscreen { speaker=fmt.tprintf("%s (off screen)",speaker) }
    } else if b.kind==.Card {
        speaker="Rin's supper notice"; if b.string_key=="end_card" { speaker="Journey complete" }
    } else { speaker="[E / Enter] Continue when ready" }
    rl.DrawText(fmt.ctprintf("%s",speaker),32,240,18,MINT)
    draw_story_page(text,game.story.page_index,264,CREAM)
    pages:=story_page_count(text)
    action:=chapter_text(game,"advance")
    if game.story.role==.End_Card && game.story.beat_index==len(story_dialogue(&g).beat_order)-1 { action=chapter_text(game,"return_menu") }
    rl.DrawText(fmt.ctprintf("E/Enter: %s   X: %s   Esc: pause",action,chapter_text(game,"skip_scene")),24,336,16,MINT)
    if pages>1 { rl.DrawText(fmt.ctprintf("%d/%d",game.story.page_index+1,pages),566,240,16,MINT) }
    // Supper shot also accompanies arrival_04; its dialogue retains its own pages.
    if stage.shot==.Supper_Card && b.kind!=.Card {
        rl.DrawRectangle(8,154,624,76,NIGHT)
        draw_story_page(g.content.snapshot.chapter.strings["supper_card"],0,158,CREAM)
    }
    if game.checkpoint==.Complete {
        rl.DrawText("Keepsake: paper flower",24,208,16,CREAM)
    }
    if game.save.message!=nil {
        rl.DrawRectangle(0,46,640,22,NIGHT)
        center_text(game.save.message,48,16,CREAM)
    }
}
