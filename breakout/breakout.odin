package main

import    "core:fmt"
import    "base:runtime"
import    "core:mem"
// import    "core:math/rand"
import rl "vendor:raylib"

TITLE         :: "Breakout"
SCREEN_WIDTH  :: 1024
SCREEN_HEIGHT :: 768

MAX_ENTITIES  :: 2000

Breakout_Context :: struct {
    height : i32,
    width  : i32,

    game_state : ^Game_State,
}

Game_State :: struct {
    game_over : bool,
    score     : int,
    hi_score  : int,
    entities  : []Entity,
}

Entity_Id :: distinct int

Entity :: struct {
    pos  : rl.Vector2,
    vel  : rl.Vector2,
    size : rl.Vector2,
}

ctx := Breakout_Context {
    width  = SCREEN_WIDTH,
    height = SCREEN_HEIGHT,
}

setup_game_state :: proc(ctx: ^Breakout_Context, allocator := context.allocator) {
    ctx.game_state = new(Game_State, allocator)
    ctx.game_state.entities = make([]Entity, MAX_ENTITIES, allocator)
}

main :: proc() {
    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }

    // permanent arena memory
    permanent_arena : mem.Arena
    permanent_alloc := permanent_alloc(&permanent_arena)
    defer destroy_arena(&permanent_arena)

    setup_game_state(&ctx, permanent_alloc)

    rl.SetConfigFlags({.VSYNC_HINT})
    rl.SetTraceLogLevel(.NONE)
    rl.InitWindow(ctx.width, ctx.height, TITLE); defer rl.CloseWindow()
    
    main_loop: for {
        if rl.WindowShouldClose() {
            break main_loop
        }

        // @Draw
        rl.BeginDrawing(); defer rl.EndDrawing()
        rl.ClearBackground({ 0, 20, 30, 255 })
    }
}


// @Entity
entity_get :: proc(id: Entity_Id) -> (e: ^Entity) {
    return
}

entity_create :: proc(e: Entity) -> (id: Entity_Id) {
    return
}


// @Arena
permanent_alloc :: proc(arena: ^mem.Arena) -> runtime.Allocator {
    permanent_mem := make([]byte, 2 * mem.Megabyte)
    mem.arena_init(arena, permanent_mem)
    return mem.arena_allocator(arena)
}

destroy_arena :: proc(arena: ^mem.Arena) {
    delete(arena.data)
}

