package main

import "core:os"
import "core:fmt"
import rl "vendor:raylib"

main :: proc() {
    when #config(M0_SELF_TEST, false) || #config(M1_SELF_TEST, false) {
        run_self_tests()
        return
    }

    when #config(E0B_SELF_TEST, false) { run_e0b_self_tests(); return }

    when #config(M2_SELF_TEST, false) { run_m2_test_entry(); return }

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
    configure_save_profile(&game)
    defer destroy_save_profile(&game.save)
    when DEV_TOOLS { autoplay: Autoplay }
    for !rl.WindowShouldClose() && !game.quit_requested {
        input := read_input()
        if input.fullscreen {
            rl.ToggleFullscreen()
        }
        dt:=min(rl.GetFrameTime(), 0.1)
        when DEV_TOOLS {
            if game.content.options.autoplay!="" {
                input,_=autoplay_input(&autoplay,&game)
                // Capture rendezvous freezes simulation while retaining render.
                waiting:=false
                for name in ([6]string{"shelf","carried","installed","cranking","cleared","returned"}) {
                    if os.exists(fmt.tprintf("%s/%s.ready",autoplay.directory,name)) && !os.exists(fmt.tprintf("%s/%s.release",autoplay.directory,name)) { waiting=true }
                }
                if waiting { dt=0 }
            }
        }
        update_game(&game, input, dt)

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
    if game.save.active && !game.save.rejected { persist_game(&game) }
}
