package main

import "core:fmt"
import "core:os"
import rl "vendor:raylib"

// Development-only input source. It feeds the SAME update_game/step_player/
// focus/interaction/save path as keyboard input. No teleports or state edits.
when DEV_TOOLS {
Autoplay :: struct {
    frame: int,
    captured: [6]bool,
    did_drop, wrong_order: bool,
    captured_title, captured_start: bool,
    directory: string,
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
    stage:=-1
    names:=[6]string{"shelf","carried","installed","cranking","cleared","returned"}
    if g.mode==.Returned { stage=5 }
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
    if g.mode==.Returned { g.quit_requested=true; return {},true }
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
    marker:=fmt.aprintf("%s/%s.ready",a.directory,name); defer delete(marker)
    release:=fmt.aprintf("%s/%s.release",a.directory,name); defer delete(release)
    if !os.exists(marker) {
        _=os.write_entire_file(marker,fmt.tprintf("checkpoint=%v handle=%v phase=%v progress=%f cues=%d player=%v camera=%v canvas=%dx%d window=%dx%d\n",g.checkpoint,g.puzzle.handle,g.puzzle.phase,g.puzzle.crank_progress,g.completion_cues,g.player.position,g.camera,VIRTUAL_WIDTH,VIRTUAL_HEIGHT,rl.GetScreenWidth(),rl.GetScreenHeight()))
        fmt.eprintln("M2_CAPTURE",name)
    }
    return os.exists(release)
}
}
