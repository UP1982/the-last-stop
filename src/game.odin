package main

GameMode :: enum { Title, Playing, Paused }
FADE_HALF_SECONDS :: 0.18

Game_State :: struct {
    mode: GameMode,
    selection: int,
    quit_requested: bool,
    transitioning: bool,
    next_mode: GameMode,
    fade_elapsed: f32,
}

enter_mode :: proc(game: ^Game_State, mode: GameMode) {
    game.mode = mode
    game.selection = 0
}

begin_transition :: proc(game: ^Game_State, next: GameMode) {
    game.transitioning = true
    game.next_mode = next
    game.fade_elapsed = 0
}

update_game :: proc(game: ^Game_State, input: Input, dt: f32) {
    if game.transitioning {
        before := game.fade_elapsed
        game.fade_elapsed += dt
        if before < FADE_HALF_SECONDS && game.fade_elapsed >= FADE_HALF_SECONDS {
            enter_mode(game, game.next_mode)
        }
        if game.fade_elapsed >= 2 * FADE_HALF_SECONDS {
            game.transitioning = false
        }
        return // Discard input during fades; never activate the destination menu.
    }

    switch game.mode {
    case .Title:
        game.selection = (game.selection + input.menu_move + 2) % 2
        if input.confirm {
            if game.selection == 0 { begin_transition(game, .Playing) }
            else { game.quit_requested = true }
        }
    case .Playing:
        if input.pause { enter_mode(game, .Paused) }
    case .Paused:
        if input.pause {
            enter_mode(game, .Playing)
            return
        }
        game.selection = (game.selection + input.menu_move + 2) % 2
        if input.confirm {
            if game.selection == 0 { enter_mode(game, .Playing) }
            else { begin_transition(game, .Title) }
        }
    }
}

fade_alpha :: proc(game: Game_State) -> f32 {
    if !game.transitioning { return 0 }
    t := game.fade_elapsed / FADE_HALF_SECONDS
    return clamp(1 - abs(t - 1), 0, 1)
}
