package main

import    "core:math/rand"
import    "core:fmt"
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
PADDLE_SPEED     :: 12
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
    b         : bool
}


main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.SetTraceLogLevel(.NONE)

    game_state := init_game_state(SCREEN_WIDTH, SCREEN_HEIGHT, TITLE)
   
    rl.InitWindow(game_state.width, game_state.height, game_state.title); defer rl.CloseWindow()

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

init_entities :: proc(entity: []Entity, game_state: Game_State) {
    for e in Entity_Type {
        switch e {
        case .Player: init_paddle(e, &entity[e], game_state)
        case .Cpu   : init_paddle(e, &entity[e], game_state)
        case .Ball  : init_ball  (e, &entity[e], game_state)
        }
    }
}

get_ball_position :: proc(game_state: Game_State) -> rl.Vector2 {
        p := f32(game_state.height) * 0.2 // 20% of height
        x := f32(game_state.width) / 2
        y := rand.float32_range(p, f32(game_state.height) - p)
        return rl.Vector2 { x, y },
}

update_player :: proc(entity: []Entity, game_state: Game_State) {
    id: Entity_Type = .Player
    player := &entity[id]

    if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {
        player.velocity.y = -1
    } else if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {
        player.velocity.y = 1
    } else {
        player.velocity.y = 0
    }

    player.position.y += player.velocity.y * player.speed

    paddle_movement_limit(&player.position.y, &player.size.y, f32(game_state.height))
}

update_game :: proc(entity: []Entity, game_state: Game_State) {
    for e in Entity_Type {
        switch e {
        case .Player : update_player(entity, game_state)
        case .Cpu    : update_cpu(entity, game_state)
        case .Ball   : update_ball(entity, game_state)
        }
    }
}

update_cpu :: proc(entity: []Entity, game_state: Game_State) {
    ball, cpu : ^Entity
    for e in Entity_Type {
        #partial switch e {
        case .Cpu    : cpu    = &entity[e]
        case .Ball   : ball   = &entity[e]
        }
    }

    cpu.position.y = math.lerp(cpu.position.y - cpu.size.y / 2, ball.position.y, f32(0.8))
    paddle_movement_limit(&cpu.position.y, &cpu.size.y, f32(game_state.height))
}

paddle_movement_limit :: proc(pos_y, height: ^f32, screen_height: f32) {
    if pos_y^ <= 0 {
        pos_y^ = 0
    } else if pos_y^ >= screen_height - height^ {
        pos_y^ = screen_height - height^
    }
}

update_ball :: proc(entity: []Entity, game_state: Game_State) {
            // BUG: when ball collide with wall the time between frames to low so it will collide back again.
            // so it wiil jitter.
            ball, player, cpu : ^Entity
            for e in Entity_Type {
                switch e {
                case .Player : player = &entity[e]
                case .Cpu    : cpu    = &entity[e]
                case .Ball   : ball   = &entity[e]
                }
            }
           
            // wall collision check
            if ball.position.y <= ball.radius || ball.position.y >= f32(game_state.height) - ball.radius {
                ball.velocity.y *= -1
            }

            // TODO: update score, check win conditon. 
            if ball.position.x <= ball.radius || ball.position.x >= f32(game_state.width) - ball.radius {
                ball_reset(ball, game_state)
            }

            if rl.CheckCollisionCircleRec(ball.position, ball.radius, {player.position.x, player.position.y, player.size.x, player.size.y}) {
                ball.velocity *= { -1, player.velocity.y }
            } else if rl.CheckCollisionCircleRec(ball.position, ball.radius, {cpu.position.x, cpu.position.y, cpu.size.x, cpu.size.y}) {
                ball.velocity *= { -1, player.velocity.y }
            }
        // update ball
        ball.position += ball.velocity * ball.speed
}

ball_reset :: proc(ball: ^Entity, game_state: Game_State) {
        ball.position   = get_ball_position(game_state)
        ball.velocity   = { -1, rand.float32_range(-1, 1) }
}
