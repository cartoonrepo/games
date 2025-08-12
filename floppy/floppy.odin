package main

import    "core:math/rand"
import rl "vendor:raylib"

TITLE         :: "Floppy"
SCREEN_WIDTH  :: 1024
SCREEN_HEIGHT :: 768

GRAVITY :: 30
JUMP    :: 500

FLOPPY_RADIUS :: 26 
FLOPPY_X_POS  :: 200 

PIPE_WIDTH      :: 120
PIPE_HEIGHT     :: SCREEN_HEIGHT
PIPE_MOVE_SPEED :: 5
PIPE_HOR_GAP    :: 200
PIPE_VER_GAP    :: 100
PIPE_RAND_Y_POS :: 160

Game_State :: struct {
    height    : i32,
    width     : i32,
    game_over : bool,
    score     : int,
    hi_score  : int,
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

    // pipe
    size   : rl.Vector2,
    active : bool,
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
        } else {
            reset_game(floppy, pipes[:])
            if rl.IsKeyPressed(.ENTER) {
                game_state.game_over = false
                if game_state.score > game_state.hi_score {
                    game_state.hi_score = game_state.score
                }
                game_state.score = 0
            }
        }

        rl.BeginDrawing(); defer rl.EndDrawing()
        rl.ClearBackground({ 0, 20, 30, 255 })

        if !game_state.game_over {
            draw_pipes(pipes[:])
            draw_floppy(floppy)

            // score
            text := rl.TextFormat("SCORE: %v", game_state.score)
            draw_text_center(text, game_state.width - 120, 10, 40, rl.RED)
        } else {
            game_over_screen()
        }
    }

    delete(entities)
    delete(pipes)
}

create_floppy :: proc() -> Entity {
    return Entity {
        pos    = { FLOPPY_X_POS, (f32(rl.GetScreenHeight()) + FLOPPY_RADIUS) / 3 },
        radius = FLOPPY_RADIUS,
        kind   = .Player,
    }
}

create_pipe :: proc(x, y: f32) -> Entity {
    return Entity {
        pos    = { x, y },
        size   = { PIPE_WIDTH, PIPE_HEIGHT },
        vel    = { PIPE_MOVE_SPEED, 0 },
        kind   = .Pipe,
        active = true,
    }
}

reset_floppy :: proc(id: Entity_Id) {
    e := get_entity(id)
    e^ = create_floppy()
}

set_pipes_position :: proc(index: int, x: ^f32) -> (y0, y1: f32) {
    c := f32(rl.GetScreenHeight()) / 2

    rand_num := rand.float32_range(c - PIPE_RAND_Y_POS, c + PIPE_RAND_Y_POS)

    x^ += PIPE_WIDTH + PIPE_HOR_GAP

    y0 = rand_num - PIPE_HEIGHT - PIPE_VER_GAP  
    y1 = rand_num + PIPE_VER_GAP

    return
}

reset_pipes :: proc(ids: []Entity_Id) {
    x : f32 = f32(SCREEN_WIDTH) / 2 - PIPE_WIDTH - PIPE_HOR_GAP

    for i := 0; i < len(ids); i += 2 {
        p0 := get_entity(ids[i])
        p1 := get_entity(ids[i + 1])

         y0, y1 := set_pipes_position(i, &x)

        p0^ = create_pipe(x, y0)
        p1^ = create_pipe(x, y1)
    }
}

setup_pipes :: proc() -> []Entity_Id {
    pipes: [dynamic]Entity_Id

    number_of_pipes := 2 * (int((SCREEN_WIDTH) / (PIPE_WIDTH + PIPE_HOR_GAP)) + 1)

    x : f32 = f32(SCREEN_WIDTH) / 2 - PIPE_WIDTH - PIPE_HOR_GAP
    for i := 0; i < number_of_pipes; i += 2 {
        y0, y1 := set_pipes_position(i, &x)
    
        h_id := create_entity(create_pipe(x, y0))
        v_id := create_entity(create_pipe(x, y1))

        append(&pipes, h_id)
        append(&pipes, v_id)
    }

    return pipes[:]
}

update_floppy :: proc(id: Entity_Id) {
    dt := rl.GetFrameTime()
    e := get_entity(id)

    if rl.IsKeyPressed(.SPACE) || rl.IsMouseButtonPressed(.LEFT) {
        e.vel.y = -JUMP
    }

    e.vel.y += GRAVITY
    e.pos += e.vel * dt
}

update_game :: proc(floppy: Entity_Id, pipes: []Entity_Id) {
    update_floppy(floppy)

    for i := 0; i < len(pipes); i += 2 {
        update_pipes(i, pipes[:])

        check_collision(floppy, pipes[i])
        check_collision(floppy, pipes[i + 1])

        update_score(get_entity(floppy), get_entity(pipes[i]), i)
    }
}

reset_game :: proc(floppy: Entity_Id, pipes: []Entity_Id) {
    reset_floppy(floppy)
    reset_pipes(pipes[:])
}

check_collision :: proc(floppy, pipe: Entity_Id) {
    f := get_entity(floppy)
    p := get_entity(pipe)

    if rl.CheckCollisionCircleRec(f.pos, f.radius, { p.pos.x, p.pos.y, p.size.x, p.size.y }) {
        game_state.game_over = true
    }

    if f.pos.y < 0 || f.pos.y > f32(game_state.height) {
        game_state.game_over = true
    }
}

update_score :: proc(e, p: ^Entity, i: int) {
    if p.pos.x + p.size.x < e.pos.x && p.active && !game_state.game_over {
        game_state.score += 1
        if game_state.hi_score == 0 {
            game_state.hi_score = game_state.score
        }
        p.active = false
    }
}

update_pipes :: proc(i: int, pipes: []Entity_Id) {
    p1 := get_entity(pipes[i])
    p2 := get_entity(pipes[i + 1])

    p1.pos.x -= p1.vel.x
    p2.pos.x -= p2.vel.x

    if p1.pos.x + p1.size.x < 0 {
        w : f32 = f32(rl.GetScreenHeight()) / 2
        y : f32 = rand.float32_range(w - PIPE_RAND_Y_POS, w + PIPE_RAND_Y_POS)

                    // get last pipe position                    get previous pipe position
        x := (i < 2) ? get_entity(pipes[len(pipes) - 1]).pos.x : get_entity(pipes[i - 2]).pos.x

        p1.pos.x = x + PIPE_WIDTH + PIPE_HOR_GAP
        p2.pos.x = x + PIPE_WIDTH + PIPE_HOR_GAP

        p1.pos.y =  y - p1.size.y - 100
        p2.pos.y =  y + 100 
        
        p1.active = true
        p2.active = true
    }
}

get_entity :: proc(id: Entity_Id) -> ^Entity {
    if int(id) < len(entities) {
        return &entities[int(id)]
    }
    return nil
}

create_entity :: proc(entity: Entity) -> (id: Entity_Id) {
    id = Entity_Id(len(entities))
    append(&entities, entity)
    return
}

draw_floppy :: proc(id: Entity_Id) {
    e := get_entity(id)
    rl.DrawCircleV(e.pos, e.radius, rl.MAGENTA)
}

draw_pipes :: proc(ids: []Entity_Id) {
    for i in ids {
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
    // game_over
    text : cstring = "GAMOVER"
    font_size : i32 = 100

    x := game_state.width / 2
    y := ((game_state.height) - font_size) / 3
    draw_text_center(text, x, y, font_size, rl.RED)

    // score
    y -= 100
    text = rl.TextFormat("SCORE: %v", game_state.score)
    font_size = 60
    draw_text_center(text, x, y, font_size, rl.SKYBLUE)

    // hi-score
    y -= 60
    text = rl.TextFormat("HI-SCORE: %v", game_state.hi_score)
    font_size = 40
    draw_text_center(text, x, y, font_size, rl.BLUE)

    y += 350
    font_size = 40
    draw_text_center("Press ENTER to restart", x, y, font_size, rl.VIOLET)
}
