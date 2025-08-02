package main

import    "core:math/rand"
import    "core:fmt"
import    "core:math"
import rl "vendor:raylib"

TITLE         :: "Floppy"
SCREEN_WIDTH  :: 1024
SCREEN_HEIGHT :: 768

main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.SetTraceLogLevel(.NONE)

    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, TITLE); defer rl.CloseWindow()

    rl.SetTargetFPS(60)


    main_loop: for {
        if rl.WindowShouldClose() {
            break main_loop
        }

        rl.BeginDrawing(); defer rl.EndDrawing()
        rl.ClearBackground(rl.BLACK)
    }
}
