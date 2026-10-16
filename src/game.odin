package main

GameMode :: enum { Title, Playing, Paused, Content_Error, Confirm_New,
    Station_Intro, Train_Travel, Obstacle_Arrival, Train_Travel_Resume, Station_Outro, Chapter_Complete }
Action_Key :: enum { Advance, Skip, Pause, Confirm }
Action_Keys :: bit_set[Action_Key]
FADE_HALF_SECONDS :: 0.18

Game_State :: struct {
    mode: GameMode,
    pause_return_mode: GameMode,
    story: Story_Player,
    art: Art_Playback,
    story_cues: int,
    action_latched: Action_Keys,
    puzzle: Puzzle_State,
    checkpoint: Journey_Checkpoint,
    save: Save_Profile,
    completion_cues: int,
    interact_latched: bool,
    selection: int,
    quit_requested: bool,
    transitioning: bool,
    next_mode: GameMode,
    fade_elapsed: f32,
    scene: Runtime_Scene,
    content: ^Runtime_Content,
    content_ready: bool,
    player: Player,
    camera: Camera,
    focus: int,
    response: cstring,
    response_seconds: f32,
    hint_tier, text_page: int,
    controls_open, gameplay_keys_blocked: bool,
    accumulator: f32,
    pending_jump, pending_interact, pending_return: bool,
}

clear_gameplay_edges :: proc(game: ^Game_State) {
    game.accumulator = 0
    game.pending_jump = false
    game.pending_interact = false
    game.pending_return = false
}

enter_mode :: proc(game: ^Game_State, mode: GameMode) {
    game.mode = mode
    game.action_latched = {.Advance,.Skip,.Pause,.Confirm}
    game.selection = 0
    game.controls_open = false
    clear_gameplay_edges(game)
    game.gameplay_keys_blocked = true
}

start_scene :: proc(game: ^Game_State) {
    game.player = {position = game.scene.spawn, grounded = true, facing = 1}
    game.art.asset=""; game.art.elapsed=0
    game.camera = {}
    follow_camera(&game.camera, game.player.position.x, game.scene.camera_bounds, game.player.position.y)
    game.focus = focus_puzzle(game.player, game.scene, game.puzzle)
    game.hint_tier = 0
    game.response = nil
    game.response_seconds = 0
}

update_playing :: proc(game: ^Game_State, frame_input: Input, dt: f32) {
    input := frame_input
    // Menu confirmation/navigation aliases must be released before gameplay.
    // Pausing also clears queued edges and accumulated simulation time.
    if game.gameplay_keys_blocked {
        game.gameplay_keys_blocked = input.jump_down || input.interact_down
        input.jump_pressed = false
        input.jump_down = false
        input.interact = false
    }
    if input.hint { request_hint(game) }
    if input.text_page { game.text_page+=1 }
    game.pending_jump = game.pending_jump || input.jump_pressed
    // Defensive edge latch also protects scripted/simultaneous/held aliases.
    edge := input.interact && !game.interact_latched
    game.interact_latched = input.interact_down || input.interact
    game.pending_interact = game.pending_interact || edge
    game.pending_return = game.pending_return || input.return_train
    game.accumulator += clamp(dt, 0, 0.1)
    for game.accumulator >= FIXED_DT {
        tick_input := input
        tick_input.jump_pressed = game.pending_jump
        step_player(&game.player, tick_input, game.scene.solids[:], game.scene.world)
        art_step_player(game,FIXED_DT)
        refresh_puzzle_objects(game)
        if game.scene.definition==nil { game.focus = focus_nearest(game.player, game.scene.objects[:]) }
        game.response_seconds = max(0, game.response_seconds - FIXED_DT)
        if game.pending_return { _=puzzle_action(game,.Return) }
        else if game.pending_interact { interact_puzzle(game) }
        if game.mode==.Playing { advance_crank(game,FIXED_DT) }
        refresh_puzzle_objects(game)
        game.pending_jump = false
        game.pending_interact = false
        game.pending_return = false
        follow_camera(&game.camera, game.player.position.x, game.scene.camera_bounds, game.player.position.y)
        game.accumulator -= FIXED_DT
        if game.mode!=.Playing { game.accumulator=0; break }
    }
}

begin_transition :: proc(game: ^Game_State, next: GameMode) {
    clear_gameplay_edges(game)
    game.transitioning = true
    game.action_latched = {.Advance,.Skip,.Pause,.Confirm}
    game.next_mode = next
    game.fade_elapsed = 0
}

update_game :: proc(game: ^Game_State, input: Input, dt: f32) {
    dt := max(dt, 0)
    input := input
    down: Action_Keys
    if input.interact || input.interact_down { down += {.Advance} }
    if input.skip || input.skip_down { down += {.Skip} }
    if input.pause || input.pause_down { down += {.Pause} }
    if input.confirm || input.confirm_down { down += {.Confirm} }
    edges:=down & ~game.action_latched
    game.action_latched=down
    input.interact=input.interact && .Advance in edges
    input.skip=input.skip && .Skip in edges
    input.pause=input.pause && .Pause in edges
    input.confirm=input.confirm && .Confirm in edges
    if game.transitioning {
        before := game.fade_elapsed
        game.fade_elapsed += dt
        if before < FADE_HALF_SECONDS && game.fade_elapsed >= FADE_HALF_SECONDS {
            enter_mode(game, game.next_mode)
            if game.story.finished {
                for mode,role in STORY_MODES {
                    if mode==game.next_mode { story_begin(game,role); break }
                }
            }
        }
        if game.fade_elapsed >= 2 * FADE_HALF_SECONDS {
            game.transitioning = false
        }
        return // Discard input during fades; never activate the destination menu.
    }

    switch game.mode {
    case .Title:
        count:=2
        if game.save.exists && !game.save.rejected { count=3 }
        game.selection = (game.selection + input.menu_move + count) % count
        if input.confirm {
            if game.selection==count-1 { game.quit_requested=true }
            else if !game.content_ready { enter_mode(game,.Content_Error) }
            else if count==3 && game.selection==0 { continue_run(game) }
            else if game.save.exists { enter_mode(game,.Confirm_New) }
            else { new_run(game) }
        }
    case .Confirm_New:
        game.selection=(game.selection+input.menu_move+2)%2
        if input.pause { enter_mode(game,.Title) }
        else if input.confirm {
            if game.selection==0 { enter_mode(game,.Title) }
            else { new_run(game) }
        }
    case .Station_Intro, .Train_Travel, .Obstacle_Arrival, .Train_Travel_Resume, .Station_Outro, .Chapter_Complete:
        if input.pause { pause_game(game); return }
        story_update(game,input,dt)
    case .Content_Error:
        count := 0
        if game.content != nil { count = len(game.content.error_lines) }
        game.selection = clamp(game.selection + input.menu_move, 0, max(0, count-7))
        if input.pause || input.confirm { enter_mode(game, .Title) }
    case .Playing:
        if input.pause { pause_game(game); return }
        update_playing(game, input, dt)
    case .Paused:
        if game.controls_open {
            if input.pause || input.confirm { game.controls_open = false }
            return
        }
        if input.pause {
            enter_mode(game, game.pause_return_mode)
            return
        }
        game.selection = (game.selection + input.menu_move + 3) % 3
        if input.confirm {
            if game.selection == 0 { enter_mode(game, game.pause_return_mode) }
            else if game.selection == 1 { game.controls_open = true }
            else { persist_game(game); begin_transition(game, .Title) }
        }
    }
}

fade_alpha :: proc(game: Game_State) -> f32 {
    if !game.transitioning { return 0 }
    t := game.fade_elapsed / FADE_HALF_SECONDS
    return clamp(1 - abs(t - 1), 0, 1)
}

pause_game :: proc(g: ^Game_State) {
    g.pause_return_mode=g.mode
    persist_game(g)
    enter_mode(g,.Paused)
}
