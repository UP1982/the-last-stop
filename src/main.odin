package main

import "core:os"
import rl "vendor:raylib"

main :: proc() {
    when #config(M0_SELF_TEST, false) || #config(M1_SELF_TEST, false) {
        run_self_tests()
        return
    }

    when #config(E0B_SELF_TEST, false) { run_e0b_self_tests(); return }

    content := load_runtime_content(os.args[1:], context.allocator)

    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(1280, 720, "The Last Stop")
    defer rl.CloseWindow()
    defer unload_runtime_content(&content)
    rl.SetWindowMinSize(640, 360)
    rl.SetExitKey(.KEY_NULL)
    rl.SetTargetFPS(60)

    canvas := rl.LoadRenderTexture(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    defer rl.UnloadRenderTexture(canvas)
    rl.SetTextureFilter(canvas.texture, .POINT)

    game := Game_State{}
    configure_content(&game, &content, stage_content_resources(&content))
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
