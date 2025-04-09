package game

import rl "vendor:raylib"

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"

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
	invuln_timer := f32(len(os.args) > 4 ? strconv.atof(os.args[4]) : 0.5)
	score := 0
	high_score := 0
	good := 0
	deaths := 0
	scores: [dynamic]int
	avg_score: f32
	dt: f32
	invuln: f32
	death: f32 = 1
	border_width := player.width * 3
	border_height := player.height * 3

	light := true
	hud := true

	sb := strings.builder_make_len(500)

	for i in 0 ..< square_count {
		append(&squares, Object{{0, 0, 20, 20}, {0, 0}})
	}

	for !rl.WindowShouldClose() {
		dt = rl.GetFrameTime()
		invuln -= dt
		death -= dt
		if rl.IsKeyDown(.W) do player.y -= 10 * speed * dt
		if rl.IsKeyDown(.S) do player.y += 10 * speed * dt
		if rl.IsKeyDown(.D) do player.x += 10 * speed * dt
		if rl.IsKeyDown(.A) do player.x -= 10 * speed * dt
		if rl.IsKeyPressed(.EIGHT) do rl.SetTargetFPS(120)
		if rl.IsKeyPressed(.NINE) do rl.SetTargetFPS(60)
		if rl.IsKeyPressed(.ZERO) do rl.SetTargetFPS(0)
		if rl.IsKeyPressed(.M) do light = !light
		if rl.IsKeyPressed(.H) do hud = !hud
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
			invuln <= 0 && death <= 0 ? rl.MAGENTA : rl.VIOLET,
		)

		for &s, idx in squares {
			rl.DrawRectangleV(
				{s.square.x, s.square.y},
				{s.square.width, s.square.height},
				// TODO: STOP JUST LIKE DON'T
				good == idx ? light ? rl.GREEN : rl.LIME : light ? rl.BLACK : rl.WHITE,
			)
			if death <= 0 {
				if rl.CheckCollisionRecs(s.square, player) {
					if good == idx {
						good = (good + 1) % len(squares)
						score += 1
						invuln = invuln_timer
						if score > high_score do high_score = score
					} else if (idx + 1) % len(squares) == good && invuln > 0 {
						// just ignore previous green square
					} else {
						append(&scores, score)
						avg_score = (avg_score + f32(score)) / 2
						player.x = 0
						player.y = 0
						score = 0
						deaths += 1
						death = invuln_timer
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
		rl.DrawText(strings.unsafe_to_cstring(&sb), 10, 10, 20, rl.BLACK)
		strings.builder_reset(&sb)

		if hud {
			fmt.sbprintln(&sb, "High score:", high_score)
			fmt.sbprintln(&sb, "Score:", score)
			fmt.sbprintln(&sb, "Square count:", len(squares))
			fmt.sbprintln(&sb, "Average score:", avg_score)
			fmt.sbprintln(&sb, "Movement speed:", speed)
			fmt.sbprintln(&sb, "Speed:", lerp_speed)
			fmt.sbprintln(&sb, "Deaths:", deaths)
			rl.DrawText(
				strings.unsafe_to_cstring(&sb),
				i32(border_width) + 10,
				i32(border_height) + 10,
				20,
				light ? rl.BLACK : rl.WHITE,
			)
			strings.builder_reset(&sb)
		}
	}
}
