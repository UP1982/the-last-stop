package main
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:time"

// Entire instrumentation body is absent from release builds. Matching can use
// an event ordinal OR a checkpoint/handle/phase/name, so later checkpoints never
// accidentally rendezvous at the first New Game write.
m4_count:int
m4_event :: proc(g:^Game_State,name:string) {
    when #config(M4_TEST_HOOKS,false) {
        m4_count+=1
        label:=fmt.tprintf("%v/%v/%v/%s",g.checkpoint,g.puzzle.handle,g.puzzle.phase,name)
        fmt.eprintln("M4_EVENT",m4_count,label,"cues",g.completion_cues,g.story_cues)
        stop:=os.get_env("TLS_M4_STOP",context.temp_allocator)
        ordinal,_:=strconv.parse_int(stop)
        if stop==label || ordinal>0 && ordinal==m4_count {
            marker:=os.get_env("TLS_M4_MARKER",context.temp_allocator)
            _=os.write_entire_file(marker,label)
            for _ in 0..<3000 { if os.exists(fmt.tprintf("%s.release",marker)) { break }; time.sleep(10*time.Millisecond) }
        }
    }
}
m4_save_event :: proc(r:Save_Record,name:string) {
    when #config(M4_TEST_HOOKS,false) { g:=Game_State{checkpoint=r.checkpoint,puzzle=r.puzzle}; m4_event(&g,name) }
}

m4_native_generation:int
m4_live_textures:int
m4_resource_balance :: proc(delta:int) {
    when #config(M4_TEST_HOOKS,false) { m4_live_textures+=delta; assert(m4_live_textures>=0) }
}
// File commands drive Input, never the user's keyboard. dt=0 between commands
// gives native lifecycle tests deterministic states without changing the clock.
m4_native_input :: proc(g:^Game_State,input:^Input,dt:^f32) {
    when #config(M4_TEST_HOOKS,false) {
        control:=os.get_env("TLS_M4_CONTROL",context.temp_allocator)
        if control=="" { return }
        input^={}; dt^=0
        bytes,e:=os.read_entire_file(control,context.temp_allocator)
        if e!=nil { return }
        _=os.remove(control)
        m4_native_generation+=1
        cmd:=string(bytes)
        switch cmd {
        case "continue": input.confirm=true
        case "pause": input.pause=true
        case "title": g.selection=2; input.confirm=true
        case "retry": g.selection=0; input.confirm=true
        case "return": g.selection=1; input.confirm=true
        case "quit": g.selection=1; if g.save.exists && !g.save.rejected { g.selection=2 }; input.confirm=true
        case "skip": input.skip=true
        case "tick-before": dt^=FADE_HALF_SECONDS/2
        case "tick-after": dt^=FADE_HALF_SECONDS
        case "settle": settle_transition(g)
        case "pickup": visit(g,.Handle)
        case "fault": _=os.set_env("TLS_M2_FAULT","rename"); _=persist_game(g)
        case "recover": _=os.unset_env("TLS_M2_FAULT")
        case "crank-mid": dt^=0.1
        case "release":
        }
    }
}
m4_native_status :: proc(g:^Game_State) {
    when #config(M4_TEST_HOOKS,false) {
        path:=os.get_env("TLS_M4_STATUS",context.temp_allocator)
        if path!="" {
            temporary:=fmt.tprintf("%s.next",path)
            _=os.write_entire_file(temporary,fmt.tprintf("%v|%v|%v|%v|%t|%t|%t|%t|%d|%d|%f|%d",g.mode,g.checkpoint,g.puzzle.handle,g.puzzle.phase,g.save.dirty,g.save.owner,g.transitioning,g.quit_requested,g.completion_cues,g.story_cues,g.fade_elapsed,m4_native_generation))
            _=os.rename(temporary,path)
        }
    }
}
