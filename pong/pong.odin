package main

import    "core:math/rand"
import    "core:math"
import rl "vendor:raylib"

TITLE         :: "Pong"
SCREEN_WIDTH  :: 1024
SCREEN_HEIGHT :: 768

BALL_RADIUS    :: 14
BALL_SPEED     :: 8
BALL_MAX_SPEED :: 20

PADDLE_GAP       :: 40
PADDLE_WIDTH     :: 20
PADDLE_HEIGHT    :: 120
PADDLE_SPEED     :: 10
PADDLE_MAX_SPEED :: 20

Game_State :: struct {
    width  : i32,
    height : i32,
    title  : cstring,
    pause  : bool,
}

Entity_Type :: enum {
    Player,
    Cpu,
    Ball,
}

// group all entity in one struct
Entity :: struct {
    id        : Entity_Type,
    position  : rl.Vector2,
    velocity  : rl.Vector2,
    size      : rl.Vector2, // paddle
    color     : rl.Color,
    radius    : f32,        // ball
    speed     : f32,
    max_speed : f32,
    score     : i32,
}

main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.SetTraceLogLevel(.NONE)

    game_state := init_game_state(SCREEN_WIDTH, SCREEN_HEIGHT, TITLE)
   
    rl.InitWindow(game_state.width, game_state.height, game_state.title); defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    entities : [len(Entity_Type)]Entity

    init_entities(entities[:], game_state)

    main_loop: for {
        if rl.WindowShouldClose() {
            break main_loop
        }

        update_game(entities[:], game_state)

        // Draw
        rl.BeginDrawing(); defer rl.EndDrawing()
        rl.ClearBackground({ 0, 20, 30, 255 })

        for e in entities {
            switch e.id {
            case .Player : rl.DrawRectangleV(e.position, e.size,   e.color)
            case .Cpu    : rl.DrawRectangleV(e.position, e.size,   e.color)
            case .Ball   : rl.DrawCircleV(e.position,    e.radius, e.color)
            }
        }

        // middle line
        rl.DrawRectangle(game_state.width / 2, 0, 1, game_state.height, rl.SKYBLUE)
        w := game_state.width / 4
        rl.DrawText(rl.TextFormat("%v", entities[0].score), w,                    50, 80, rl.SKYBLUE)
        rl.DrawText(rl.TextFormat("%v", entities[1].score), game_state.width - w, 50, 80, rl.SKYBLUE)
    }
}

init_game_state :: proc(w, h: i32, t: cstring) -> Game_State {
    return Game_State {
        width  = w,
        height = h,
        title  = t,
    }
}

init_paddle :: proc(id: Entity_Type, e: ^Entity, g: Game_State) {
    ph : f32 = f32(g.height) / 2 
    px : f32 = PADDLE_GAP
    cx : f32 = f32(g.width) - PADDLE_GAP - PADDLE_WIDTH

    #partial switch id {
        case .Player : e.position = { px, ph }
        case .Cpu    : e.position = { cx, ph }  
    }

    e.id         = id
    e.velocity   = { 0, 1 }
    e.size       = { PADDLE_WIDTH, PADDLE_HEIGHT }
    e.color      = rl.BLUE
    e.speed      = PADDLE_SPEED
    e.max_speed  = PADDLE_MAX_SPEED
}

init_ball :: proc(id: Entity_Type, e: ^Entity, g: Game_State) {
    e.id         = id
    e.position   = get_ball_position(g)
    e.velocity   = { -1, rand.float32_range(-1, 1) }
    e.color      = rl.BLUE
    e.radius     = BALL_RADIUS
    e.speed      = BALL_SPEED
    e.max_speed  = BALL_MAX_SPEED
}

init_entities :: proc(e: []Entity, game_state: Game_State) {
    for id in Entity_Type {
        switch id {
        case .Player: init_paddle(id, &e[id], game_state)
        case .Cpu   : init_paddle(id, &e[id], game_state)
        case .Ball  : init_ball  (id, &e[id], game_state)
        }
    }
}

get_ball_position :: proc(game_state: Game_State) -> rl.Vector2 {
        p := f32(game_state.height) * 0.2 // 20% of height
        x := f32(game_state.width) / 2
        y := rand.float32_range(p, f32(game_state.height) - p)
        return rl.Vector2 { x, y },
}

update_player :: proc(e: []Entity, game_state: Game_State) {
    id: Entity_Type = .Player
    player := &e[id]

    if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {
        player.velocity.y = -1
    } else if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {
        player.velocity.y = 1
    } else {
        player.velocity.y = 0
    }

    player.position.y += player.velocity.y * player.speed

    paddle_movement_limit(player, f32(game_state.height))
}

update_cpu :: proc(e: []Entity, game_state: Game_State) {
    ball, cpu : ^Entity
    for id in Entity_Type {
        #partial switch id {
        case .Cpu    : cpu    = &e[id]
        case .Ball   : ball   = &e[id]
        }
    }

    // BUG: snaps to ball position when ball resets
    cpu.position.y = math.lerp(cpu.position.y, ball.position.y, f32(0.8))

    paddle_movement_limit(cpu, f32(game_state.height))
}

paddle_movement_limit :: proc(e: ^Entity, screen_height: f32) {
    if e.position.y <= 0 {
        e.position.y = 0
    } else if e.position.y >= screen_height - e.size.y {
        e.position.y = screen_height - e.size.y
    }
}

update_ball :: proc(e: []Entity, game_state: Game_State) {
        ball, player, cpu : ^Entity
        for id in Entity_Type {
            switch id {
            case .Player : player = &e[id]
            case .Cpu    : cpu    = &e[id]
            case .Ball   : ball   = &e[id]
            }
        }
           
        // wall collision check
        if ball.position.y <= ball.radius {
            ball.velocity.y *= -1
            ball.position.y  = ball.radius
        } else if ball.position.y >= f32(game_state.height) - ball.radius {
            ball.velocity.y *= -1
            ball.position.y  = f32(game_state.height) - ball.radius
        }

        if ball.position.x <= ball.radius {
            cpu.score += 1
            ball_reset(ball, game_state)
        } else if ball.position.x >= f32(game_state.width) - ball.radius {
            player.score += 1
            ball_reset(ball, game_state)
        }

        if rl.CheckCollisionCircleRec(ball.position, ball.radius, { player.position.x, player.position.y, player.size.x, player.size.y }) {
            offset := player.position.x + player.size.x
            if ball.position.x > offset - ball.radius / 2 {
                ball.velocity.x *= -1
                ball.velocity.y  = player.velocity.y
                ball.position.x  = offset + ball.radius
            }
                
        } else if rl.CheckCollisionCircleRec(ball.position, ball.radius, { cpu.position.x, cpu.position.y, cpu.size.x, cpu.size.y }) {
            if ball.position.x < cpu.position.x + ball.radius / 2 {
                ball.velocity.x *= -1
                ball.velocity.y *= cpu.velocity.y
                ball.position.x  = cpu.position.x - ball.radius
            }
        }

        // update ball
        ball.position += ball.velocity * ball.speed
}

ball_reset :: proc(ball: ^Entity, game_state: Game_State) {
        ball.position   = get_ball_position(game_state)
        ball.velocity   = { -1, rand.float32_range(-1, 1) }
}

update_game :: proc(e: []Entity, game_state: Game_State) {
    for id in Entity_Type {
        switch id {
        case .Player : update_player(e, game_state)
        case .Cpu    : update_cpu(e, game_state)
        case .Ball   : update_ball(e, game_state)
        }
    }
}
