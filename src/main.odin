package main

import rl "vendor:raylib"

MAIN_WIDTH  :: 1280
MAIN_HEIGHT :: 720

main :: proc() {
    rl.InitWindow(MAIN_WIDTH, MAIN_HEIGHT, "The Last Stop | Odin + raylib starter")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{28, 36, 59, 255})
        rl.DrawRectangle(0, 540, MAIN_WIDTH, 180, rl.Color{52, 71, 106, 255})
        rl.DrawRectangle(160, 475, 350, 90, rl.Color{118, 103, 147, 255})
        rl.DrawRectangle(180, 448, 310, 40, rl.Color{232, 185, 110, 255})
        rl.DrawRectangle(820, 508, 58, 55, rl.Color{242, 220, 202, 255})
        rl.DrawText("THE LAST STOP", 80, 80, 48, rl.Color{242, 220, 202, 255})
        rl.DrawText("Odin + raylib starter shell | press ESC to exit", 80, 142, 24, rl.Color{169, 209, 187, 255})
        rl.DrawText("Next: virtual canvas, input, Milo controller, Oliver puzzle", 80, 190, 22, rl.Color{242, 220, 202, 255})
        rl.EndDrawing()
    }
}
