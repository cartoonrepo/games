package main

import    "core:fmt"
import    "core:math/rand"
import rl "vendor:raylib"

TITLE         :: "Floppy"
SCREEN_WIDTH  :: 1024
SCREEN_HEIGHT :: 768

GRAVITY :: 30
JUMP    :: 500

PIPE_MOVE_SPEED :: 5
PIPE_HOR_GAP    :: 400
PIPE_VER_GAP    :: 120

Game_State :: struct {
    height   : i32,
    width    : i32,
    game_over: bool,
    score    : int,
}

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

    // floppy (player)
    radius : f32,
    flags  : bit_set[Entity_Flags],

    // pipe
    size   : rl.Vector2,
    active : bool,
}

Entity_Flags :: enum {
    Is_Dead,
}

game_state: Game_State
entities: [dynamic]Entity

main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.SetTraceLogLevel(.NONE)

    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, TITLE); defer rl.CloseWindow()

    game_state.height = rl.GetScreenHeight()
    game_state.width  = rl.GetScreenWidth()

    floppy := create_entity(create_floppy())
    pipes  := setup_pipes()

    main_loop: for {
        if rl.WindowShouldClose() {
            break main_loop
        }

        if !game_state.game_over {
            update_game(floppy, pipes[:])
        }

        rl.BeginDrawing(); defer rl.EndDrawing()
        rl.ClearBackground(rl.BLACK)

        if !game_state.game_over {
            draw_pipes(pipes[:])
            draw_floppy(floppy)
            draw_score(game_state.width - 120, 10, 40, rl.RED)
        } else {
            game_over_screen()
        }

    }

    delete(entities)
}

create_floppy :: proc() -> Entity {
    r : f32 = 26
    return Entity {
        pos    = { 100, (f32(rl.GetScreenHeight()) + r) / 2 },
        radius = r,
        kind   = .Player,
    }
}

create_pipe :: proc(x, y, w, h: f32) -> Entity {
    return Entity {
        pos    = { x, y },
        size   = { w, h },
        vel    = { PIPE_MOVE_SPEED, 0 },
        kind   = .Pipe,
        active = true,
    }
}

setup_pipes :: proc() -> []Entity_Id {
    pipes: [dynamic]Entity_Id

    x:  f32 = f32(SCREEN_WIDTH) / 2
    y:  f32 = 0
    w:  f32 = 120
    h:  f32 = f32(rl.GetScreenHeight())

    number_of_pipes := int((SCREEN_WIDTH) / PIPE_HOR_GAP) + 1  // add extra one pipe so it won't feel like poping pipe at the end.

    c := f32(rl.GetScreenHeight()) / 2
    for i in 0..= number_of_pipes {
        x = f32(SCREEN_WIDTH) / 2 + f32(i) * PIPE_HOR_GAP

        r := rand.float32_range(c - 200, c + 200)

        y = r - h - PIPE_VER_GAP  
        id := create_entity(create_pipe(x, y, w, h))
        append(&pipes, id)

        y = r + PIPE_VER_GAP
        id = create_entity(create_pipe(x, y, w, h))
        append(&pipes, id)
    }

    return pipes[:]
}

update_floppy :: proc(id: Entity_Id) {
    dt := rl.GetFrameTime()
    e := get_entity(id)

    if rl.IsKeyPressed(.SPACE) {
        e.vel.y = -JUMP
    }

    e.vel.y += GRAVITY

    e.pos += e.vel * dt
}

update_game :: proc(floppy: Entity_Id, pipes: []Entity_Id) {
    update_floppy(floppy)

    for i := 1; i <= len(pipes); i += 2 {
        update_pipes(i, pipes[:])

        check_collision(floppy, Entity_Id(i))
        check_collision(floppy, Entity_Id(i + 1))

        update_score(get_entity(floppy), get_entity(Entity_Id(i)), i)
    }
}

check_collision :: proc(floppy, pipe: Entity_Id) {
    f := get_entity(floppy)
    p := get_entity(pipe)

    if rl.CheckCollisionCircleRec(f.pos, f.radius, { p.pos.x, p.pos.y, p.size.x, p.size.y }) {
        f.flags = { .Is_Dead }
        game_state.game_over = true
    }

    if f.pos.y < 0 || f.pos.y > f32(game_state.height) {
        game_state.game_over = true
    }
}

update_score :: proc(e, p: ^Entity, i: int) {
    if p.pos.x + p.size.x < e.pos.x && p.active && !game_state.game_over {
        game_state.score += 1
        p.active = false
    }
}

update_pipes :: proc(i: int, pipes: []Entity_Id) {
    e1 := get_entity(Entity_Id(i))
    e2 := get_entity(Entity_Id(i + 1))

    e1.pos.x -= e1.vel.x
    e2.pos.x -= e2.vel.x

    w := f32(rl.GetScreenHeight()) / 2
    y : f32 = rand.float32_range(w - 200, w + 200)

    if e1.pos.x + e1.size.x < 0 {
        if i <= 2 { // offset 2 becasue 2 vertical pipes.
            x := get_entity(Entity_Id(len(pipes))).pos.x
            e1.pos.x = x + PIPE_HOR_GAP
            e2.pos.x = x + PIPE_HOR_GAP

        } else {
            x := get_entity(Entity_Id(i - 2)).pos.x
            e1.pos.x = x + PIPE_HOR_GAP
            e2.pos.x = x + PIPE_HOR_GAP
        }

        e1.pos.y =  y - e1.size.y - 100
        e2.pos.y =  y + 100 
        
        e1.active = true
        e2.active = true
    }
}

get_entity :: proc(id: Entity_Id) -> ^Entity {
    if int(id) < len(entities) {
        return &entities[int(id)]
    }

    return nil
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
    e := get_entity(id)
    rl.DrawCircleV(e.pos, e.radius, rl.MAGENTA)
}

draw_pipes :: proc(id: []Entity_Id) {
    for i in id {
        e := get_entity(i)
        c := rl.LIME
        if i % 2 == 0 { c = rl.BLUE }
        rl.DrawRectangleV(e.pos, e.size, c)
    }
}

draw_text_center :: proc(text: cstring, x, y, font_size: i32, color: rl.Color) {
    xx := x - rl.MeasureText(text, font_size) / 2
    rl.DrawText(text, xx, y, font_size, color)
}

draw_score :: proc(x, y, font_size: i32, color: rl.Color) {
    text : cstring = rl.TextFormat("SCORE: %v", game_state.score)
    draw_text_center(text, x, y, font_size, color)
}

game_over_screen :: proc() {
    text : cstring = "GAMOVER"
    font_size : i32 = 100

    x := game_state.width / 2
    y := ((game_state.height) - font_size) / 3

    draw_text_center(text, x, y, font_size, rl.RED)
    y -= 100
    draw_score(x, y, 60, rl.BLUE)

    y += 250
    font_size = 40
    draw_text_center("Press ENTER to restart", x, y, font_size, rl.SKYBLUE)
}
