package main

import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

// Development-only input source. It feeds the SAME update_game/step_player/
// focus/interaction/save path as keyboard input. No teleports or state edits.
when DEV_TOOLS {
Autoplay :: struct {
    frame: int,
    captured: [6]bool,
    did_drop, wrong_order: bool,
    captured_title, captured_start: bool,
    directory, waiting_name: string,
    story_captured: map[string]bool,
    journey_started: bool,
    art_jump_requested: bool,
}
autoplay_input :: proc(a:^Autoplay,g:^Game_State) -> (Input,bool) {
    route:=g.content.options.autoplay
    if route=="" { return {},false }
    if a.directory=="" {
        a.directory=os.get_env("TLS_M2_EVIDENCE",context.allocator)
        if a.directory=="" { fmt.eprintln("autoplay needs TLS_M2_EVIDENCE"); g.quit_requested=true; return {},true }
    }
    a.frame+=1
    if a.frame>60*180 { fmt.eprintln("autoplay timeout"); g.quit_requested=true; return {},true }
    if g.transitioning { return {},true }
    if route=="art3" || route=="story-advance" || route=="story-skip" { return autoplay_journey(a,g,route=="story-skip"),true }
    // Extra render rendezvous for the resolution migration's window-size gate.
    // Only the explicit res640 route pauses at Title and initial puzzle control.
    if route=="res640" {
        if g.mode==.Title && !a.captured_title {
            if !autoplay_capture(a,g,"title") { return {},true }
            a.captured_title=true
        }
        if g.mode==.Playing && !a.captured_start {
            if !autoplay_capture(a,g,"start") { return {},true }
            a.captured_start=true
        }
    }
    if g.mode==.Title { return {confirm=true},true }
    if g.mode==.Station_Intro || g.mode==.Train_Travel || g.mode==.Obstacle_Arrival {
        if a.frame%30==0 { return {skip=true,skip_down=true},true }
        return {},true
    }
    stage:=-1
    names:=[6]string{"shelf","carried","installed","cranking","cleared","returned"}
    if g.mode==.Train_Travel_Resume { stage=5 }
    else if g.mode==.Playing {
        if g.puzzle.phase==.Cleared { stage=4 }
        else if g.puzzle.phase==.Cranking { if g.puzzle.crank_progress>=0.45 { stage=3 } }
        else if g.puzzle.handle==.Installed { stage=2 }
        else if g.puzzle.handle==.Held { stage=1 }
        else if g.puzzle.handle==.Shelf && abs(g.player.position.x-(kind_x(g,.Handle)-36))<8 { stage=0 }
    }
    if stage>=0 && !a.captured[stage] {
        if !autoplay_capture(a,g,names[stage]) { return {},true }
        a.captured[stage]=true
    }
    if g.mode==.Train_Travel_Resume { g.quit_requested=true; return {},true }
    if g.mode!=.Playing { return {},true }
    input:=Input{}
    target:=g.player.position.x
    interact:=false
    if g.puzzle.phase==.Cleared { input.return_train=true }
    else if g.puzzle.phase==.Cranking { return {},true }
    else if route=="drop" && !a.wrong_order && g.puzzle.handle==.Shelf {
        target=kind_x(g,.Winch)
        if abs(target-g.player.position.x)<6 { interact=true; if a.frame%30==0 { a.wrong_order=true } }
    }
    else if g.puzzle.handle==.Shelf || g.puzzle.handle==.Dropped { target=kind_x(g,.Handle)-36; interact=true }
    else if g.puzzle.handle==.Held {
        if route=="drop" && !a.did_drop {
            target=1000
            if abs(target-g.player.position.x)<6 { interact=true; if a.frame%30==0 { a.did_drop=true } }
        } else { target=kind_x(g,.Winch)-36; interact=true }
    } else { target=kind_x(g,.Winch)-36; interact=true }
    delta:=target-g.player.position.x
    if abs(delta)>6 { input.move=1; if delta<0 { input.move=-1 } }
    else if interact && a.frame%30==0 { input.interact=true; input.interact_down=true }
    return input,true
}
autoplay_capture :: proc(a:^Autoplay,g:^Game_State,name:string) -> bool {
    if a.waiting_name!=name { delete(a.waiting_name); a.waiting_name=strings.clone(name) }
    marker:=fmt.aprintf("%s/%s.ready",a.directory,name); defer delete(marker)
    release:=fmt.aprintf("%s/%s.release",a.directory,name); defer delete(release)
    if !os.exists(marker) {
        _=os.write_entire_file(marker,fmt.tprintf("mode=%v role=%v beat=%d page=%d elapsed=%f travel=%f story_cues=%d checkpoint=%v handle=%v phase=%v progress=%f cues=%d player=%v camera=%v art=%s frame=%d art_elapsed=%f facing=%d grounded=%t canvas=%dx%d window=%dx%d\n",g.mode,g.story.role,g.story.beat_index,g.story.page_index,g.story.elapsed,g.story.travel_elapsed,g.story_cues,g.checkpoint,g.puzzle.handle,g.puzzle.phase,g.puzzle.crank_progress,g.completion_cues,g.player.position,g.camera,g.art.asset,art_frame(g.art.asset,g.art.elapsed,6),g.art.elapsed,g.player.facing,g.player.grounded,VIRTUAL_WIDTH,VIRTUAL_HEIGHT,rl.GetScreenWidth(),rl.GetScreenHeight()))
        fmt.eprintln("M2_CAPTURE",name)
    }
    return os.exists(release)
}
autoplay_waiting :: proc(a:^Autoplay) -> bool {
    if a.waiting_name=="" { return false }
    return !os.exists(fmt.tprintf("%s/%s.release",a.directory,a.waiting_name))
}
autoplay_journey :: proc(a:^Autoplay,g:^Game_State,skip:bool) -> Input {
    if a.story_captured==nil { a.story_captured=make(map[string]bool) }
    name:=""
    if g.mode==.Title {
        name="title"; if a.journey_started { name="title_end" }
    } else if !a.journey_started { a.journey_started=true }
    reload:=os.get_env("TLS_M3B_RELOAD_LABEL",context.temp_allocator)
    if name=="" && reload!="" && !a.story_captured[fmt.tprintf("reload_%s",reload)] {
        name=fmt.tprintf("reload_%s",reload)
    }
    b:=story_beat(g)
    if name=="" && b!=nil && g.mode==STORY_MODES[g.story.role] {
        if skip {
            switch g.story.role {
            case .Intro: name="intro_skip"
            case .Travel: name="travel_skip"
            case .Obstacle: name="obstacle_skip"
            case .Return: name="return_skip"
            case .Arrival: name="arrival_skip"
            case .End_Card: name="end_skip"
            }
        } else {
            id:=story_dialogue(g).beat_order[g.story.beat_index]
            switch id {
            case "prologue_rin_01_beat": name="prologue"
            case "intro_board_sideways": name="boarding"
            case "travel_01_beat": name="travel"
            case "obstacle_01_beat": name="obstacle"
            case "return_forest_travel": name="return"
            case "arrival_03_beat": name="arrival"
            case "arrival_notice_card": name="supper"
            case "ending_text_card": name="end_card"
            }
        }
    }
    if name=="" && g.mode==.Playing {
        if g.puzzle.phase==.Cleared { name="cleared" }
        else if g.puzzle.phase==.Cranking { if g.puzzle.crank_progress>=0.45 { name="cranking" } }
        else if g.puzzle.handle==.Installed { name="installed" }
        else if g.puzzle.handle==.Held { name="carried" }
        else { name="puzzle" }
    }
    if name!="" && !a.story_captured[name] {
        if !autoplay_capture(a,g,name) { return {} }
        a.story_captured[strings.clone(name)]=true
    }
    if g.mode==.Title {
        if a.journey_started { g.quit_requested=true; return {} }
        if a.frame%30==0 { return {confirm=true,confirm_down=true} }
        return {}
    }
    if g.mode==STORY_MODES[g.story.role] {
        if a.frame%60==0 {
            if skip { return {skip=true,skip_down=true} }
            return {interact=true,interact_down=true}
        }
        return {}
    }
    if g.mode!=.Playing { return {} }
    // Art evidence uses the real input/controller path; no teleports/state edits.
    if g.content.options.autoplay=="art3" {
        if !a.story_captured["walking_right"] {
            if g.player.position.x>g.scene.spawn.x+48 && g.player.velocity.x>100 {
                if !autoplay_capture(a,g,"walking_right") { return {} }
                a.story_captured["walking_right"]=true
            }
            return {move=1}
        }
        if !a.story_captured["walking_left"] {
            if g.player.velocity.x < -100 {
                if !autoplay_capture(a,g,"walking_left") { return {} }
                a.story_captured["walking_left"]=true
            }
            return {move=-1}
        }
        if !a.story_captured["jumping"] {
            if !a.art_jump_requested { a.art_jump_requested=true; return {jump_pressed=true,jump_down=true} }
            if g.player.position.y<g.scene.spawn.y-24 {
                if !autoplay_capture(a,g,"jumping") { return {} }
                a.story_captured["jumping"]=true
            }
            return {jump_down=true}
        }
    }
    if g.puzzle.phase==.Cleared { return {return_train=true} }
    if g.puzzle.phase==.Cranking { return {} }
    target:=kind_x(g,.Winch)-36
    if g.puzzle.handle==.Shelf || g.puzzle.handle==.Dropped { target=kind_x(g,.Handle)-36 }
    delta:=target-g.player.position.x
    if abs(delta)>6 { move:f32=1; if delta<0 { move=-1 }; return {move=move} }
    if a.frame%30==0 { return {interact=true,interact_down=true} }
    return {}
}

}
