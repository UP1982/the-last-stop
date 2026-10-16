package main

import "core:fmt"
import "core:os"

// Development-only input source. It feeds the SAME update_game/step_player/
// focus/interaction/save path as keyboard input. No teleports or state edits.
when DEV_TOOLS {
Autoplay :: struct {
    frame: int,
    captured: [6]bool,
    did_drop, wrong_order: bool,
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
    if g.mode==.Title { return {confirm=true},true }
    stage:=-1
    names:=[6]string{"shelf","carried","installed","cranking","cleared","returned"}
    if g.mode==.Returned { stage=5 }
    else if g.mode==.Playing {
        if g.puzzle.phase==.Cleared { stage=4 }
        else if g.puzzle.phase==.Cranking { if g.puzzle.crank_progress>=0.45 { stage=3 } }
        else if g.puzzle.handle==.Installed { stage=2 }
        else if g.puzzle.handle==.Held { stage=1 }
        else if g.puzzle.handle==.Shelf && abs(g.player.position.x-(kind_x(g,.Handle)-18))<4 { stage=0 }
    }
    if stage>=0 && !a.captured[stage] {
        marker:=fmt.aprintf("%s/%s.ready",a.directory,names[stage]); defer delete(marker)
        release:=fmt.aprintf("%s/%s.release",a.directory,names[stage]); defer delete(release)
        if !os.exists(marker) {
            _=os.write_entire_file(marker,fmt.tprintf("checkpoint=%v handle=%v phase=%v progress=%f cues=%d\n",g.checkpoint,g.puzzle.handle,g.puzzle.phase,g.puzzle.crank_progress,g.completion_cues))
            fmt.eprintln("M2_CAPTURE",names[stage])
        }
        if !os.exists(release) { return {},true }
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
        if abs(target-g.player.position.x)<3 { interact=true; if a.frame%30==0 { a.wrong_order=true } }
    }
    else if g.puzzle.handle==.Shelf || g.puzzle.handle==.Dropped { target=kind_x(g,.Handle)-18; interact=true }
    else if g.puzzle.handle==.Held {
        if route=="drop" && !a.did_drop {
            target=500
            if abs(target-g.player.position.x)<3 { interact=true; if a.frame%30==0 { a.did_drop=true } }
        } else { target=kind_x(g,.Winch)-18; interact=true }
    } else { target=kind_x(g,.Winch)-18; interact=true }
    delta:=target-g.player.position.x
    if abs(delta)>3 { input.move=1; if delta<0 { input.move=-1 } }
    else if interact && a.frame%30==0 { input.interact=true; input.interact_down=true }
    return input,true
}
}
