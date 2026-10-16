package main

import c "../shared/content"

Story_Role :: enum { Intro, Travel, Obstacle, Return, Arrival, End_Card }
Story_Finish_Reason :: enum { Normal, Skip }
Story_Player :: struct {
    role: Story_Role,
    beat_index, page_index: int,
    elapsed, travel_elapsed, cue_seconds: f32,
    finished, input_latched, silent: bool,
    cue: c.Story_Cue,
}
STORY_ROLE_NAMES := [Story_Role]string{.Intro="intro",.Travel="travel",.Obstacle="obstacle",.Return="return",.Arrival="arrival",.End_Card="end_card"}
STORY_MODES := [Story_Role]GameMode{.Intro=.Station_Intro,.Travel=.Train_Travel,.Obstacle=.Obstacle_Arrival,.Return=.Train_Travel_Resume,.Arrival=.Station_Outro,.End_Card=.Chapter_Complete}
STORY_CHECKPOINTS := [Story_Role]Journey_Checkpoint{.Intro=.Chapter_Start,.Travel=.Boarded,.Obstacle=.Puzzle,.Return=.Returned,.Arrival=.Arrival,.End_Card=.Complete}

story_dialogue :: proc(g: ^Game_State) -> ^c.Dialogue_Def {
    if g.content==nil || g.content.snapshot==nil { return nil }
    s:=g.content.snapshot
    ref,ok:=s.chapter.dialogues[STORY_ROLE_NAMES[g.story.role]]
    if !ok { return nil }
    return &s.dialogues[ref.id]
}
story_beat :: proc(g: ^Game_State) -> ^c.Story_Beat_Def {
    d:=story_dialogue(g)
    if d==nil || g.story.beat_index<0 || g.story.beat_index>=len(d.beat_order) { return nil }
    return &d.beats[d.beat_order[g.story.beat_index]]
}
story_text :: proc(g: ^Game_State) -> string {
    b:=story_beat(g); if b==nil { return "" }
    switch b.kind {
    case .Line: return story_dialogue(g).lines[b.line].text
    case .Card: return g.content.snapshot.chapter.strings[b.string_key]
    case .Stage: return ""
    }
    return ""
}
story_begin :: proc(g: ^Game_State, role: Story_Role, emit_cues:=true) {
    g.story={role=role,input_latched=true,silent=!emit_cues}
    enter_mode(g,STORY_MODES[role])
    b:=story_beat(g)
    if b==nil { enter_mode(g,.Content_Error); return }
    story_apply_stage(g,b)
}
story_apply_stage :: proc(g: ^Game_State, b: ^c.Story_Beat_Def) {
    // Presentation only: never interacts with the puzzle or changes checkpoints.
    g.story.cue=.None; g.story.cue_seconds=0
    if !g.story.silent && b.stage.cue!=.None {
        g.story.cue=b.stage.cue; g.story.cue_seconds=1.2; g.story_cues+=1
    }
}
story_update :: proc(g: ^Game_State, input: Input, dt: f32) {
    if g.story.finished { return }
    // update_game handles pause first and drains held aliases across modes.
    down:=input.interact || input.interact_down || input.skip || input.skip_down || input.pause_down || input.confirm_down
    g.story.input_latched=down
    if input.skip { story_finish(g,.Skip); return }
    if input.interact { story_advance(g); return }
    g.story.elapsed+=dt
    g.story.travel_elapsed+=dt
    g.story.cue_seconds=max(0,g.story.cue_seconds-dt)
    b:=story_beat(g)
    if b!=nil && b.kind==.Stage && b.duration_ms>0 && g.story.elapsed>=f32(b.duration_ms)/1000 {
        story_advance(g)
    }
}
story_advance :: proc(g: ^Game_State) {
    if g.story.finished || g.mode!=STORY_MODES[g.story.role] { return }
    b:=story_beat(g); if b==nil { return }
    if b.kind!=.Stage && g.story.page_index+1<story_page_count(story_text(g)) {
        g.story.page_index+=1; return
    }
    d:=story_dialogue(g)
    if g.story.beat_index+1==len(d.beat_order) { story_finish(g,.Normal); return }
    g.story.beat_index+=1; g.story.page_index=0; g.story.elapsed=0
    story_apply_stage(g,story_beat(g))
}
story_finish :: proc(g: ^Game_State, reason: Story_Finish_Reason) {
    if g.story.finished || g.mode!=STORY_MODES[g.story.role] ||
        g.checkpoint!=STORY_CHECKPOINTS[g.story.role] || !puzzle_invariant(g.puzzle,g.checkpoint,g.scene) { return }
    // Validation determines the only allowed handler; never execute content as
    // commands. Skip invokes exactly this handler, without visiting future beats.
    m4_event(g,"before_story_finish")
    g.story.finished=true
    switch g.story.role {
    case .Intro: board_oliver(g); begin_transition(g,.Train_Travel)
    case .Travel: enter_obstacle(g); begin_transition(g,.Obstacle_Arrival)
    case .Obstacle: begin_puzzle(g)
    case .Return: enter_arrival(g); begin_transition(g,.Station_Outro)
    case .Arrival: finish_oliver_journey(g); begin_transition(g,.Chapter_Complete)
    case .End_Card: show_title(g)
    }
    m4_event(g,"after_story_finish")
}
resume_checkpoint :: proc(g: ^Game_State) {
    // Deliberately restore the checkpoint, never a page, timer, cue or fade.
    start_scene(g)
    if g.checkpoint>=.Returned {
        g.player={position=marker_position(g.scene,true),grounded=true,facing=1}
        g.camera={}; follow_camera(&g.camera,g.player.position.x,g.scene.camera_bounds,g.player.position.y)
    }
    refresh_puzzle_objects(g)
    switch g.checkpoint {
    case .Chapter_Start: story_begin(g,.Intro,false)
    case .Boarded: story_begin(g,.Travel,false)
    case .Puzzle: g.story={}; enter_mode(g,.Playing)
    case .Returned: story_begin(g,.Return,false)
    case .Arrival: story_begin(g,.Arrival,false)
    case .Complete: story_begin(g,.End_Card,false)
    }
}
