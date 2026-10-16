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
story_draw_prop :: proc(prop: c.Prop_Def, camera: Camera) {
    x,y:=prop.position[0]-pixel(camera.x),prop.position[1]-pixel(camera.y)
    w,h:=i32(30),i32(24)
    color:=MINT
    switch prop.kind {
    case .Train: w=210;h=86;color={78,101,109,255}
    case .Door: w=32;h=66;color={180,143,105,255}
    case .Bag: w=36;h=26;color={155,118,88,255}
    case .Flowerpot: w=26;h=30;color={181,126,99,255}
    case .Paper_Flower: w=24;h=20;color=CREAM
    case .Slat: w=64;h=6;color={193,157,119,255}
    case .Bench: w=100;h=20;color={153,126,100,255}
    case .Timetable: w=38;h=48
    case .Sign: w=90;h=28
    case .Notice: w=52;h=36
    case .Market_Dressing: w=110;h=64;color={141,120,95,255}
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
    label:=fmt.ctprintf("%v: %s",prop.kind,prop.state)
    rl.DrawText(label,x,y+h+3,12,CREAM)
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
    rl.DrawText(fmt.ctprintf("%s",g.content.snapshot.chapter.speakers[id].name),x-20,y+4,16,CREAM)
    rl.DrawText(fmt.ctprintf("%v / %v",a.pose,a.emote),x-32,y+22,12,MINT)
    if a.pose==.Point || a.pose==.Reach || a.pose==.Wave || a.pose==.Tap {
        end:=x+28; if a.facing=="left" { end=x-28 }
        rl.DrawLineEx({f32(x),f32(y-19)},{f32(end),f32(y-25)},4,color)
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
        rl.DrawText("Branch",pixel(branch.x)-pixel(camera.x),pixel(branch.y)-pixel(camera.y)-18,16,CREAM)
        label:cstring="Handle fitted"; if game.puzzle.handle!=.Installed { label="Empty socket" }
        rl.DrawText(label,sx-34,sy-28,16,CREAM)
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
        draw_story_glyphs("— ALL WELCOME",216,90,MINT)
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
        rl.DrawRectangle(8,160,624,64,NIGHT)
        draw_story_page(g.content.snapshot.chapter.strings["supper_card"],0,166,CREAM)
    }
    if game.checkpoint==.Complete {
        rl.DrawText("Keepsake: paper flower",24,208,16,CREAM)
    }
    if game.save.message!=nil {
        rl.DrawRectangle(0,46,640,22,NIGHT)
        center_text(game.save.message,48,16,CREAM)
    }
}
