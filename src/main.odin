package main

import rl "vendor:raylib"

main :: proc() {
    when #config(M0_SELF_TEST, false) {
        run_self_tests()
        return
    }

    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(1280, 720, "The Last Stop")
    defer rl.CloseWindow()
    rl.SetWindowMinSize(640, 360)
    rl.SetExitKey(.KEY_NULL)
    rl.SetTargetFPS(60)

    canvas := rl.LoadRenderTexture(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    defer rl.UnloadRenderTexture(canvas)
    rl.SetTextureFilter(canvas.texture, .POINT)

    game := Game_State{}
    for !rl.WindowShouldClose() && !game.quit_requested {
        input := read_input()
        if input.fullscreen {
            rl.ToggleFullscreen()
        }
        update_game(&game, input, min(rl.GetFrameTime(), 0.1))

        // Recompute every frame, including immediately after fullscreen changes.
        viewport := make_viewport(rl.GetScreenWidth(), rl.GetScreenHeight())
        rl.BeginTextureMode(canvas)
        draw_game(game)
        rl.EndTextureMode()

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        // Render textures are vertically inverted in OpenGL.
        rl.DrawTexturePro(canvas.texture,
            {0, 0, VIRTUAL_WIDTH, -VIRTUAL_HEIGHT}, viewport.destination,
            {}, 0, rl.WHITE)
        rl.EndDrawing()
    }
}
