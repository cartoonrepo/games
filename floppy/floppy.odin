package main

import debug "base:intrinsics"
import       "core:fmt"
import rl    "vendor:raylib"


TITLE         :: "Floppy"
SCREEN_WIDTH  :: 1024
SCREEN_HEIGHT :: 768

Entity_Id :: distinct int

Entity_Kind :: enum {
    Player,
    Pipe,
}

Entity :: struct {
    // all
    pos  : rl.Vector2,
    vel  : rl.Vector2,
    kind : Entity_Kind,

    // player
    radius : f32,
    score  : int,
    flags  : bit_set[Entity_Flags],

    // pipe
    size : rl.Vector2,
    gap  : f32,
    last_pipe_pos : f32,
}


Entity_Flags :: enum {
    Is_Dead,
}

entities: [dynamic]Entity

main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.SetTraceLogLevel(.NONE)

    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, TITLE); defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    floppy := create_entity(create_floppy())
    pipes  := setup_pipes()

    main_loop: for {
        if rl.WindowShouldClose() {
            break main_loop
        }

        update_pipes(pipes[:])

        rl.BeginDrawing(); defer rl.EndDrawing()
        rl.ClearBackground(rl.BLACK)

        draw_floppy(floppy)
        draw_pipes(pipes[:])
    }
}

create_floppy :: proc() -> Entity {
    r : f32 = 30
    return Entity {
        pos    = { 100, (f32(rl.GetScreenHeight()) + r) / 2 },
        radius = r,
        kind   = .Player,
    }
}


create_pipe :: proc(x, y, w, h, g: f32) -> Entity {
    return Entity {
        pos    = { x, y },
        size   = { w, h},
        vel    = { 2, 0 },
        gap    = g,
        kind   = .Pipe,
    }
}

setup_pipes :: proc() -> []Entity_Id {
    pipes: [dynamic]Entity_Id

    x: f32 = f32(SCREEN_WIDTH) / 2
    y: f32 = 0
    w: f32 = 60
    h: f32 = (f32(rl.GetScreenHeight()) / 2)
    g: f32 = w * 4

    number_of_pipes := int((SCREEN_WIDTH) / g)

    for i in 0..= number_of_pipes {
        x = f32(SCREEN_WIDTH) / 2 + f32(i) * g

        y = -w
        id := create_entity(create_pipe(x, y, w, h, g))
        append(&pipes, id)

        y = h + w
        id = create_entity(create_pipe(x, y, w, h, g))
        append(&pipes, id)
    }

    return pipes[:]
}

update_pipes :: proc(ids: []Entity_Id) {
    for i in ids {
        e := &entities[i]
        e.pos.x -= e.vel.x

        // debug.debug_trap()
        if e.pos.x + e.size.x < 0 {
            if i <= 2 { // offset 2 becasue 2 vertical pipes.
                e.pos.x = entities[len(ids)].pos.x + e.gap
            } else {
                e.pos.x = entities[i - 2].pos.x + e.gap // // offset 2 becasue 2 vertical pipes.
            }
        }
    }
}

create_entity :: proc(entity: Entity) -> (id: Entity_Id) {
    for &e, index in entities {
        if .Is_Dead in e.flags {
            e = entity
            e.flags -= { .Is_Dead }
            return Entity_Id(index)
        }
    }
    id = Entity_Id(len(entities))
    append(&entities, entity)
    return
}

draw_floppy :: proc(id: Entity_Id) {
    e := entities[id]
    rl.DrawCircleV(e.pos, e.radius, rl.BLUE)
}

draw_pipes :: proc(id: []Entity_Id) {
    for i in id {
        e := entities[i]
            rl.DrawRectangleV(e.pos, e.size, rl.MAROON)
    }
}
