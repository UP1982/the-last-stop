package main

import "core:fmt"
import "core:os"
import "core:strings"

when #config(M3B_SELF_TEST,false) {
// Test fixtures contain durable state only; all playback after restoration uses
// the actual update/input/handler/save path. No graphical initialization needed.
story_test_role :: proc(g:^Game_State, role:Story_Role) {
    g.save.active=false; g.transitioning=false; g.puzzle={}; g.completion_cues=0; g.story_cues=0
    g.checkpoint=STORY_CHECKPOINTS[role]
    if g.checkpoint>=.Returned { g.puzzle={handle=.Installed,phase=.Cleared,crank_progress=1} }
    start_scene(g); story_begin(g,role)
}
story_test_press :: proc(g:^Game_State, skip:=false) {
    update_game(g,{},0)
    update_game(g,{interact=!skip,interact_down=!skip,skip=skip,skip_down=skip},0)
}
story_test_complete_role :: proc(g:^Game_State) {
    role:=g.story.role
    for _ in 0..<10000 {
        if g.mode!=STORY_MODES[role] || g.story.finished { break }
        story_test_press(g)
    }
    assert(g.mode!=STORY_MODES[role] || g.story.finished)
    settle_transition(g)
}
story_test_whole :: proc(g:^Game_State) {
    for _ in 0..<10 {
        if g.mode==.Title { assert(owns_paper_flower(g^)); return }
        if g.mode==.Playing { complete_puzzle(g) }
        else { story_test_complete_role(g) }
    }
    assert(false,"journey did not reach title")
}
story_test_convergence :: proc(g:^Game_State) {
    cases:=0; pages_seen:=0
    for role in Story_Role {
        story_test_role(g,role)
        baseline:=g^
        story_test_complete_role(&baseline)
        expected:=Save_Record{baseline.checkpoint,baseline.puzzle}
        d:=story_dialogue(g)
        for _,index in d.beat_order {
            // Start at each real beat/page by advancing through every prior beat.
            story_test_role(g,role)
            for g.story.beat_index<index { story_test_press(g) }
            pages:=story_page_count(story_text(g))
            for page in 0..<pages {
                story_test_role(g,role)
                for g.story.beat_index<index || g.story.page_index<page { story_test_press(g) }
                normal,skipped:=g^,g^
                story_test_complete_role(&normal)
                cues:=skipped.story_cues
                story_test_press(&skipped,true)
                // Calls arriving again before the destination activates are no-ops.
                before:=skipped
                story_finish(&skipped,.Skip); story_finish(&skipped,.Normal)
                assert(skipped.checkpoint==before.checkpoint && skipped.mode==before.mode && skipped.story_cues==before.story_cues)
                settle_transition(&skipped)
                assert(Save_Record{normal.checkpoint,normal.puzzle}==expected)
                assert(Save_Record{skipped.checkpoint,skipped.puzzle}==expected)
                assert(normal.mode==baseline.mode && skipped.mode==baseline.mode)
                // Next-role first cue is allowed; skipped beats emit no cues.
                assert(skipped.story_cues<=cues+1)
                cases+=1
                if pages>1 { pages_seen+=1 }
            }
        }
    }
    assert(cases>=52)
    fmt.println("PASS convergence: all six roles, every beat/page:",cases,"cases; paginated positions:",pages_seen)
}
story_test_pause_inputs :: proc(g:^Game_State) {
    for role in Story_Role {
        story_test_role(g,role)
        // At every text page (and every stage) pause retains exact transient state.
        role_mode:=g.mode
        d:=story_dialogue(g)
        for _,index in d.beat_order {
            story_test_role(g,role)
            for g.story.beat_index<index { story_test_press(g) }
            pages:=story_page_count(story_text(g))
            for page in 0..<pages {
                story_test_role(g,role)
                for g.story.beat_index<index || g.story.page_index<page { story_test_press(g) }
                update_game(g,{},0.123)
                before:=g.story; p:=g.puzzle; cues:=g.story_cues
                update_game(g,{pause=true,pause_down=true,interact=true,interact_down=true,skip=true,skip_down=true},0)
                assert(g.mode==.Paused && g.pause_return_mode==role_mode && g.story==before)
                for _ in 0..<90 { update_game(g,{pause=true,pause_down=true,interact=true,skip=true},1) }
                assert(g.mode==.Paused && g.story==before && g.puzzle==p && g.story_cues==cues)
                update_game(g,{},0)
                update_game(g,{pause=true},0)
                assert(g.mode==role_mode && g.story==before)
                // Simultaneous held input across resume does not advance or skip.
                for _ in 0..<4 { update_game(g,{pause=true,interact=true,skip=true},0) }
                assert(g.mode==role_mode && g.story==before)
            }
        }
        // Skip wins over advance, then its held edge is drained during fade.
        story_test_role(g,role)
        update_game(g,{},0)
        update_game(g,{interact=true,interact_down=true,skip=true,skip_down=true},0)
        checkpoint:=g.checkpoint
        for _ in 0..<120 { update_game(g,{interact=true,interact_down=true,skip=true,skip_down=true},FIXED_DT) }
        assert(g.checkpoint==checkpoint)
        // A fresh X still works while E is held from an earlier advance.
        story_test_role(g,role)
        story_test_press(g)
        update_game(g,{interact_down=true,skip=true,skip_down=true},0)
        assert(g.story.finished || g.mode!=role_mode)
    }
    // A timed beat advances automatically, and consumes at most one beat even
    // with a large dt; a spoken line never expires.
    story_test_role(g,.Travel)
    update_game(g,{},8)
    assert(g.story.beat_index==1)
    for story_beat(g).kind!=.Line { story_test_press(g) }
    before:=g.story.beat_index
    update_game(g,{},800)
    assert(g.story.beat_index==before)
    fmt.println("PASS pause/input: every beat/page freezes; exact modes; held and simultaneous aliases; automatic stages; unexpired lines")
}
story_test_guards :: proc(g:^Game_State) {
    story_test_role(g,.Travel)
    story_test_press(g,true); settle_transition(g)
    assert(g.mode==.Obstacle_Arrival && g.checkpoint==.Puzzle && g.puzzle.handle==.Shelf && g.puzzle.phase==.Blocked)
    story_test_press(g,true)
    assert(g.mode==.Playing && g.checkpoint==.Puzzle)
    for _ in 0..<4 {
        enter_arrival(g); finish_oliver_journey(g); show_title(g); _=puzzle_action(g,.Return)
    }
    assert(g.mode==.Playing && g.checkpoint==.Puzzle && !owns_paper_flower(g^))
    for role in ([]Story_Role{.Return,.Arrival,.End_Card}) {
        story_test_role(g,role)
        g.puzzle={}
        before:=g.checkpoint
        story_finish(g,.Skip)
        enter_arrival(g); finish_oliver_journey(g); show_title(g)
        assert(g.checkpoint==before && !g.story.finished)
    }
    // Each compiled completion handler rejects contradictory puzzle records,
    // independently of story_finish and of save/content validation.
    for checkpoint in ([]Journey_Checkpoint{.Returned,.Arrival,.Complete}) {
        g.checkpoint=checkpoint; g.puzzle={handle=.Installed,phase=.Cleared,crank_progress=0}
        before:=g.checkpoint; mode:=g.mode
        enter_arrival(g); finish_oliver_journey(g); show_title(g)
        assert(g.checkpoint==before && g.mode==mode)
    }
    story_test_role(g,.Arrival)
    story_test_press(g,true)
    assert(owns_paper_flower(g^))
    cues:=g.story_cues
    for _ in 0..<100 { finish_oliver_journey(g); story_finish(g,.Skip) }
    assert(g.checkpoint==.Complete && g.story_cues==cues)
    fmt.println("PASS guards: travel/obstacle skip retain uncleared puzzle; repeated farewell grants one derived flower, no duplicate cues")
}
story_test_text :: proc() {
    for s in ([]string{"A little further down the line…","WILLOW CREEK PLATFORM SUPPER — ALL WELCOME",strings.repeat("word ",820),strings.repeat("猫",4096),"line one\nline two",strings.repeat("W",4096)}) {
        ends,count:=story_line_ends(s)
        start:=0
        for end,index in ends[:count] {
            assert(end>=start && end<=len(s))
            if end<len(s) { assert(s[end]&0xc0!=0x80) }
            assert(story_text_width(story_line(s,ends[:count],index))<=STORY_TEXT_WIDTH)
            assert(264+i32(index%STORY_ROWS)*STORY_LINE_HEIGHT+STORY_FONT_SIZE<=336)
            start=end
        }
        assert(start==len(s) && story_page_count(s)==(count+STORY_ROWS-1)/STORY_ROWS)
    }
    fmt.println("PASS text: bounded pixel widths, UTF-8 boundaries, newline/long words, all pages, em dash and ellipsis preserved")
}
run_m3b_test_entry :: proc() {
    assert(len(os.args)>=2)
    command:=os.args[1]
    runtime:=load_runtime_content(os.args[2:],context.allocator)
    defer unload_runtime_content(&runtime)
    if command=="startup-rejected" {
        assert(runtime.snapshot==nil && len(runtime.error_lines)>0)
        message:=""
        for line in runtime.error_lines { message=fmt.tprintf("%s%s",message,line) }
        assert(strings.contains(message,"story_migration_required"))
        assert(strings.contains(message,"schema v1; migrate to v2 to play"))
        g:=Game_State{}
        configure_content(&g,&runtime,false); configure_save_profile(&g,true)
        defer destroy_save_profile(&g.save)
        assert(g.mode==.Content_Error && !g.content_ready)
        assert(!g.save.enabled && !g.save.active && g.save.path=="")
        // The only way back to the menu must still refuse Start/Continue.
        for _ in 0..<3 {
            update_game(&g,{},0); update_game(&g,{confirm=true},0)
            assert(g.mode==.Title)
            update_game(&g,{},0); update_game(&g,{confirm=true},0)
            assert(g.mode==.Content_Error && !g.transitioning && !g.save.active)
        }
        fmt.println("PASS startup refused before menus/save profile:",message)
        return
    }
    assert(runtime.snapshot!=nil)
    g:=Game_State{}
    configure_content(&g,&runtime,true); configure_save_profile(&g,true)
    defer destroy_save_profile(&g.save)
    assert(g.save.enabled,"M3b tests require isolated --save-dir")
    switch command {
    case "selftest":
        story_test_convergence(&g); story_test_pause_inputs(&g); story_test_guards(&g); story_test_text()
    case "new":
        update_game(&g,{confirm=true},0)
        assert(g.checkpoint==.Chapter_Start && g.save.exists)
        settle_transition(&g)
        assert(g.mode==.Station_Intro)
    case "resume", "before-arrival", "after-arrival", "retry":
        assert(g.save.exists && !g.save.rejected)
        expected:=g.save.loaded.checkpoint
        update_game(&g,{confirm=true},0)
        // Continued presentation begins without replaying any semantic cue.
        assert(g.checkpoint==expected && g.completion_cues==0 && g.story_cues==0)
        expected_mode:=GameMode.Playing
        for cp,role in STORY_CHECKPOINTS { if cp==expected && expected!=.Puzzle { expected_mode=STORY_MODES[role] } }
        assert(g.mode==expected_mode)
        normalized:=g.puzzle; normalize_puzzle(&normalized,g.scene); assert(g.puzzle==normalized)
        fmt.println("RESTORED",g.checkpoint,g.mode,g.puzzle.handle,g.puzzle.phase,"cues",g.completion_cues,g.story_cues)
        settle_transition(&g)
        if command=="before-arrival" || command=="after-arrival" || command=="retry" {
            assert(g.checkpoint==.Arrival)
            // Retry covers effects that have actually run, rather than only a
            // silent reload. Re-enable presentation on this restored fixture.
            if command=="retry" { g.story.silent=false }
            // Stop on the final farewell beat, before the only reward commit.
            d:=story_dialogue(&g)
            for g.story.beat_index<len(d.beat_order)-1 { story_test_press(&g) }
            if command!="before-arrival" {
                if command=="retry" {
                    fault:=os.get_env("TLS_M3B_FAULT",context.temp_allocator)
                    if fault=="" { fault="rename" }
                    assert(os.set_env("TLS_M2_FAULT",fault)==nil)
                }
                story_test_press(&g,true)
                assert(owns_paper_flower(g))
                cues:=g.story_cues
                if command=="retry" { assert(cues>=2,"paper rustle and farewell whistle must have run before the failure") }
                for _ in 0..<10 { finish_oliver_journey(&g); story_finish(&g,.Skip) }
                assert(g.story_cues==cues)
                if command=="retry" {
                    assert(g.save.dirty && g.save.message!=nil)
                    bytes,e:=os.read_entire_file(g.save.path,context.temp_allocator); assert(e==nil)
                    saved,ok:=save_decode(bytes,g.scene); assert(ok)
                    if os.get_env("TLS_M3B_FAULT",context.temp_allocator)=="directory_sync" { assert(saved.checkpoint==.Complete) }
                    else { assert(saved.checkpoint==.Arrival) }
                    _=os.unset_env("TLS_M2_FAULT")
                    persist_game(&g)
                    assert(!g.save.dirty && g.save.message==nil && g.story_cues==cues)
                    fmt.println("PASS failed-save retry: checkpoint Complete, flower derived once, no effect replay")
                }
            }
            persist_game(&g)
        } else { story_test_whole(&g) }
    case: assert(false,"unknown M3b test command")
    }
    assert(puzzle_invariant(g.puzzle,g.checkpoint,g.scene))
    assert(!g.save.dirty)
    fmt.println("PASS M3b",command,"checkpoint",g.checkpoint,"mode",g.mode,"flower",owns_paper_flower(g),"clearance cues",g.completion_cues,"story cues",g.story_cues)
}
}
