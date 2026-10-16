package main

import "core:os"
import rl "vendor:raylib"

main :: proc() {
    when #config(M0_SELF_TEST, false) || #config(M1_SELF_TEST, false) {
        run_self_tests()
        return
    }

    when DEV_TOOLS && #config(DEV_EDITOR_SELF_TEST,false) { run_dev_editor_tests(); return }

    when #config(M4_SELF_TEST,false) { run_m4_tests(); return }

    when #config(ART3_SELF_TEST, false) { run_art3_tests(); return }

    when #config(M3B_SELF_TEST, false) { run_m3b_test_entry(); return }

    when #config(M3A_SELF_TEST, false) { run_m3a_content_test(); return }

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
    when DEV_TOOLS {
        if content.options.preview_scene!="" && !dev_preview_path_safe(&content) {
            content_error(&content,"preview: unsafe isolated destination; startup blocked")
            game.content_ready=false; enter_mode(&game,.Content_Error)
        }
    }
    configure_save_profile(&game)
    when DEV_TOOLS {
        if content.options.preview_scene!="" {
            if !game.save.owner || !save_profile_identity(&game.save) {
                content_error(&content,"preview: isolated profile unavailable; startup blocked")
                game.content_ready=false; enter_mode(&game,.Content_Error)
            } else if content.options.preview_entry=="chapter" { new_run(&game) }
        }
    }
    defer destroy_save_profile(&game.save)
    when DEV_TOOLS { autoplay: Autoplay; editor:=Dev_Editor{}; defer dev_editor_destroy(&editor) }
    for !game.quit_requested {
        if rl.WindowShouldClose() { request_save_exit(&game,true); if game.quit_requested { break } }
        free_all(context.temp_allocator)
        when DEV_TOOLS {
            if rl.IsKeyPressed(.F3) { game.art.debug_boxes = !game.art.debug_boxes }
            if rl.IsKeyPressed(.F5) {
                if !editor.active && !editor.dirty && !editor.pending && !editor.uncertain { _=reload_runtime_content(&game,&content); dev_editor_forget_baseline(&editor) }
                else { dev_status(&editor,"F5 blocked while authoring. Use explicit Discard disk to reload; draft retained.") }
            }
        }
        input := read_input()
        if input.fullscreen {
            rl.ToggleFullscreen()
        }
        dt:=min(rl.GetFrameTime(), 0.1)
        when DEV_TOOLS {
            if game.content.options.autoplay!="" {
                input,_=autoplay_input(&autoplay,&game)
                // Capture rendezvous freezes simulation while retaining render.
                if autoplay_waiting(&autoplay) { dt=0 }
            }
        }
        m4_native_input(&game,&input,&dt)
        when DEV_TOOLS {
            dev_editor_frame(&editor,&game,&content,input,dt)
        } else { update_game(&game, input, dt) }

        // Recompute every frame, including immediately after fullscreen changes.
        viewport := make_viewport(rl.GetScreenWidth(), rl.GetScreenHeight())
        rl.BeginTextureMode(canvas)
        draw_game(game)
        when DEV_TOOLS { dev_editor_draw(&editor,&game) }
        rl.EndTextureMode()

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        // Render textures are vertically inverted in OpenGL.
        rl.DrawTexturePro(canvas.texture,
            {0, 0, VIRTUAL_WIDTH, -VIRTUAL_HEIGHT}, viewport.destination,
            {}, 0, rl.WHITE)
        rl.EndDrawing()
        m4_native_status(&game)
    }

}
