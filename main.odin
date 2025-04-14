package game

import rl "vendor:raylib"

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:os"
import "core:strconv"
import "core:time"

// version: 1
Object :: struct {
	square: rl.Rectangle,
	target: rl.Vector2,
}

main :: proc() {
	if len(os.args) > 1 {
		switch os.args[1] {
		case "--help":
			fallthrough
		case "-h":
			fallthrough
		case "help":
			fallthrough
		case "h":
			fallthrough
		case "-?":
			fallthrough
		case "?":
			fmt.println("game [Square count] [Movement speed] [Square speed] [Invuln timer (s)]")
			fmt.println("defaults 10 50 1 0.5")
			return
		}
	}
	rl.InitWindow(800, 600, "idk")

	player := rl.Rectangle{200, 200, 20, 20}
	squares := make([dynamic]Object, 0, 100) // we like leaking memory 
	// defer delete(squares) // why the fuck should i care when the os takes care of that anyway
	square_count := len(os.args) > 1 ? strconv.atoi(os.args[1]) : 10
	speed := f32(len(os.args) > 2 ? strconv.atof(os.args[2]) : 50)
	lerp_speed := f32(len(os.args) > 3 ? strconv.atof(os.args[3]) : 1)
	invuln_time := f32(len(os.args) > 4 ? strconv.atof(os.args[4]) : 0.5)

	score := 0
	high_score := 0
	avg_score: f32
	scores: [dynamic]int
	// defer delete(scores)
	deaths := 0

	good := 0
	dt: f32
	invuln_timer: f32
	death_timer: f32 = 1

	border_width := player.width * 3
	border_height := player.height * 3

	light := true
	hud := true

	for i in 0 ..< square_count {
		append(&squares, Object{{0, 0, 20, 20}, {0, 0}})
	}

	for !rl.WindowShouldClose() {
		dt = rl.GetFrameTime()
		invuln_timer -= dt
		death_timer -= dt

		// https://mathproofs.blogspot.com/2005/07/mapping-square-to-circle.html
		{move := [2]f32{0, 0}
			r, l := rl.GetGamepadAxisMovement(0, .RIGHT_X), rl.GetGamepadAxisMovement(0, .LEFT_X)
			x := abs(r) - abs(l) > 0 ? r : l
			r, l = rl.GetGamepadAxisMovement(0, .RIGHT_Y), rl.GetGamepadAxisMovement(0, .LEFT_Y)
			y := abs(r) - abs(l) < 0 ? l : r
			move.x = x * math.sqrt(1 - 0.5 * y * y)
			move.y = y * math.sqrt(1 - 0.5 * x * x)

			if rl.IsKeyDown(.W) {move.y = -1}
			if rl.IsKeyDown(.S) {move.y = 1}
			if rl.IsKeyDown(.D) {move.x = 1}
			if rl.IsKeyDown(.A) {move.x = -1}
			if abs(move.x) < 0.1 {move.x = 0}
			if abs(move.y) < 0.1 {move.y = 0}
			player.x += move.x * 10 * speed * dt
			player.y += move.y * 10 * speed * dt
		}

		if rl.IsKeyPressed(.EIGHT) {rl.SetTargetFPS(120)}
		if rl.IsKeyPressed(.NINE) {rl.SetTargetFPS(60)}
		if rl.IsKeyPressed(.ZERO) {rl.SetTargetFPS(0)}
		if rl.IsKeyPressed(.M) {light = !light}
		if rl.IsKeyPressed(.H) || rl.IsGamepadButtonPressed(0, .MIDDLE_RIGHT) {hud = !hud}


		player.x = clamp(
			player.x,
			border_width,
			f32(rl.GetScreenWidth()) - border_width - player.width,
		)
		player.y = clamp(
			player.y,
			border_height,
			f32(rl.GetScreenHeight()) - border_height - player.height,
		)

		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(light ? rl.WHITE : rl.BLACK)
		rl.DrawRectangle(
			0,
			0,
			i32(border_width),
			rl.GetScreenHeight(),
			light ? {0, 0, 0, 100} : {255, 255, 255, 100},
		)
		rl.DrawRectangle(
			i32(border_width),
			0,
			rl.GetScreenWidth() - i32(border_width) * 2,
			i32(border_height),
			light ? {0, 0, 0, 100} : {255, 255, 255, 100},
		)
		rl.DrawRectangle(
			rl.GetScreenWidth() - i32(border_width),
			rl.GetScreenHeight(),
			-rl.GetScreenWidth() + i32(border_width) * 2,
			-i32(border_width),
			light ? {0, 0, 0, 100} : {255, 255, 255, 100},
		)
		rl.DrawRectangle(
			rl.GetScreenWidth(),
			rl.GetScreenHeight(),
			-i32(border_height),
			-rl.GetScreenWidth(),
			light ? {0, 0, 0, 100} : {255, 255, 255, 100},
		)

		rl.DrawRectangleV(
			{player.x, player.y},
			{player.width, player.height},
			invuln_timer <= 0 && death_timer <= 0 ? rl.MAGENTA : rl.VIOLET,
		)

		for &s, idx in squares {
			rl.DrawRectangleV(
				{s.square.x, s.square.y},
				{s.square.width, s.square.height},
				// TODO: STOP JUST LIKE DON'T
				good == idx ? light ? rl.GREEN : rl.DARKGREEN : light ? rl.BLACK : rl.WHITE,
			)
			if death_timer <= 0 {
				if rl.CheckCollisionRecs(s.square, player) {
					if good == idx {
						good = (good + 1) % len(squares)
						score += 1
						invuln_timer = invuln_time
						if score > high_score {high_score = score}
					} else if (idx + 1) % len(squares) == good && invuln_timer > 0 {
						// just ignore previous green square
					} else {
						append(&scores, score)
						avg_score = (avg_score + f32(score)) / 2
						player.x = 0
						player.y = 0
						score = 0
						deaths += 1
						death_timer = invuln_time
					}
				}
			}

			if rl.CheckCollisionRecs({s.target.x - 20, s.target.y - 20, 40, 40}, s.square) {
				s.target.x = rand.float32_range(0, f32(rl.GetScreenWidth()))
				s.target.y = rand.float32_range(0, f32(rl.GetScreenHeight()))
			}
			s.square.x = math.lerp(s.square.x, s.target.x, 1 - math.pow(0.5, lerp_speed * dt))
			s.square.y = math.lerp(s.square.y, s.target.y, 1 - math.pow(0.5, lerp_speed * dt))
		}
		rl.DrawFPS(rl.GetScreenWidth() - 100, 10)

		if hud {
			rl.DrawText(
				rl.TextFormat(
					"High score: %i\nScore: %i\nSquare count: %i\nAverage score: %.2f\nMovement speed: %.2f\nSpeed: %.2f\nDeaths: %i",
					high_score,
					score,
					len(squares),
					avg_score,
					speed,
					lerp_speed,
					deaths,
				),
				i32(border_width) + 10,
				i32(border_height) + 10,
				20,
				light ? rl.BLACK : rl.WHITE,
			)
		}
	}
	fmt.println("Scores:", scores)
	fmt.println("High score:", high_score)
	fmt.println("Score:", score)
	fmt.println("Square count:", len(squares))
	fmt.println("Average score:", avg_score)
	fmt.println("Movement speed:", speed)
	fmt.println("Speed:", lerp_speed)
	fmt.println("Deaths:", deaths)
}
