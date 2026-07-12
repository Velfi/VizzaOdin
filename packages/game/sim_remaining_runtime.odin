package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"
import "core:math"
import sdl "vendor:sdl3"

remaining_sim_apply_frame_input :: proc(sim: ^Remaining_Sim_State, input: Ui_Frame_Input) {
	remaining_sim_apply_frame_input_for_kind(sim, .Flow_Field, input)
}

remaining_sim_apply_frame_input_for_kind :: proc(sim: ^Remaining_Sim_State, kind: Remaining_Sim_Kind, input: Ui_Frame_Input) {
	if kind == .Slime_Mold || kind == .Pellets || kind == .Voronoi_CA || kind == .Primordial {
		camera_controls_apply_input(&sim.camera, input)
	}
	was_cursor_active := sim.cursor_active
	previous_cursor_velocity := sim.cursor_world_velocity
	sim.cursor_active = 0
	sim.cursor_mode = 0
	if input.window_width <= 0 || input.window_height <= 0 {
		sim.cursor_world_velocity = {0, 0}
		return
	}
	world := remaining_sim_screen_to_world(input.mouse_pos, input.window_width, input.window_height)
	if kind == .Slime_Mold || kind == .Pellets || kind == .Voronoi_CA || kind == .Primordial {
		world = camera_controls_screen_to_world(&sim.camera, input.mouse_pos, input.window_width, input.window_height)
	}
	if kind == .Pellets || kind == .Voronoi_CA || kind == .Primordial {
		world = toroidal_world_position(world)
	}
	// These simulations render their world coordinates with Vulkan's
	// downward-positive viewport Y, so keep pointer Y in the same space.
	if kind == .Flow_Field || kind == .Pellets || kind == .Primordial {
		world[1] = -world[1]
	}
	dt := max(input.delta_time, 1.0 / 240.0)
	measured_velocity := [2]f32{
		(world[0] - sim.cursor_world_prev[0]) / dt,
		(world[1] - sim.cursor_world_prev[1]) / dt,
	}
	sim.cursor_world_velocity = remaining_sim_cursor_velocity_for_kind(kind, was_cursor_active, input.mouse_down, previous_cursor_velocity, measured_velocity)
	sim.cursor_world = world
	sim.cursor_world_prev = world
	sim.cursor_pixel = {input.mouse_pos.x, input.mouse_pos.y}
	if kind == .Slime_Mold {
		sim.cursor_pixel = {
			(world[0] + 1.0) * 0.5 * f32(input.window_width),
			(world[1] + 1.0) * 0.5 * f32(input.window_height),
		}
	}
	if input.mouse_down {
		sim.cursor_active = 1
		sim.cursor_mode = input.mouse_button == 3 ? u32(2) : u32(1)
	}
	tool_set := canvas_tool_set_for_kind(kind)
	canvas_tool_update_selection(&tool_set, &sim.canvas_tool, input)
	if sim.cursor_active != 0 && kind != .Voronoi_CA {
		tool := canvas_tool_selected(&tool_set, &sim.canvas_tool)
		if tool.valid {
			sim.cursor_mode = canvas_tool_interaction_mode(tool, input.mouse_button == 3 || input.actions.secondary.down)
		}
	}
	if kind == .Vectors && sim.cursor_active != 0 {
		settings := sim.vectors
		if sim.cursor_mode == 3 || sim.cursor_mode == 4 {
			settings.probe_position = sim.cursor_world
			settings.probe_initialized = true
			settings.probe_value = noise_sample01_2d(&settings.noise, sim.cursor_world[0], sim.cursor_world[1], sim.time)
			settings.probe_has_sample = settings.vector_field_type == .Noise
			settings.probe_pinned = sim.cursor_mode == 4
		} else if sim.cursor_mode == 5 || sim.cursor_mode == 6 {
			index := settings.deflection_stamp_count % len(settings.deflection_stamps)
			settings.deflection_stamps[index] = {
				position = sim.cursor_world,
				radius = max(sim.cursor_size, 0.01),
				angle = (sim.cursor_mode == 5 ? f32(1) : f32(-1)) * sim.cursor_strength * 0.03,
			}
			settings.deflection_stamp_count += 1
		}
	}
	if kind == .Voronoi_CA {
		tool := canvas_tool_selected(&tool_set, &sim.canvas_tool)
		sim.voronoi_pressed = input.mouse_pressed || input.actions.primary.pressed || input.actions.secondary.pressed
		sim.voronoi_released = input.mouse_released || input.actions.primary.released || input.actions.secondary.released
		// 1 magnet, 2 repel, 3 pluck, 4 paint, 5 erase.
		sim.voronoi_interaction_mode = 0
		if input.mouse_down || input.actions.primary.down || input.actions.secondary.down {
			secondary := input.mouse_button == 3 || input.actions.secondary.down
			action := canvas_tool_action_for_input(tool, secondary)
			#partial switch action {
			case .Attract: sim.voronoi_interaction_mode = 1
			case .Repel: sim.voronoi_interaction_mode = 2
			case .Pluck: sim.voronoi_interaction_mode = 3
			case .Paint_Sites: sim.voronoi_interaction_mode = 4
			case .Erase_Sites: sim.voronoi_interaction_mode = 5
			case .Shockwave: sim.voronoi_interaction_mode = 6
			case:
			}
		}
	}
}

remaining_sim_cursor_velocity_for_kind :: proc(kind: Remaining_Sim_Kind, was_cursor_active: u32, mouse_down: bool, previous_velocity, measured_velocity: [2]f32) -> [2]f32 {
	if kind != .Pellets {
		return measured_velocity
	}

	if mouse_down {
		if was_cursor_active == 0 {
			return measured_velocity
		}
		smoothing_factor := f32(0.7)
		return {
			previous_velocity[0] * (1.0 - smoothing_factor) + measured_velocity[0] * smoothing_factor,
			previous_velocity[1] * (1.0 - smoothing_factor) + measured_velocity[1] * smoothing_factor,
		}
	}

	decay_factor := f32(0.95)
	return {
		previous_velocity[0] * decay_factor,
		previous_velocity[1] * decay_factor,
	}
}

remaining_sim_screen_to_world :: proc(mouse_pos: uifw.Vec2, width, height: i32) -> [2]f32 {
	w := max(f32(width), 1)
	h := max(f32(height), 1)
	return {
		(mouse_pos.x / w) * 2.0 - 1.0,
		-((mouse_pos.y / h) * 2.0 - 1.0),
	}
}

remaining_sim_step :: proc(sim: ^Remaining_Sim_State, dt: f32) {
	if sim.paused {
		return
	}
	speed := sim.speed
	if sim.moire != nil && sim.moire.speed > 0 {
		speed = sim.moire.speed
	}
	sim.time += dt * max(speed, 0)
}

remaining_sim_name :: proc(kind: Remaining_Sim_Kind) -> string {
	switch kind {
	case .Slime_Mold:
		return "Slime Mold"
	case .Flow_Field:
		return "Flow Field"
	case .Pellets:
		return "Pellets"
	case .Voronoi_CA:
		return "Voronoi"
	case .Moire:
		return "Moire"
	case .Vectors:
		return "Vectors"
	case .Primordial:
		return "Primordial"
	}
	return "Simulation"
}

remaining_sim_description :: proc(kind: Remaining_Sim_Kind) -> string {
	switch kind {
	case .Slime_Mold:
		return "Agent trails with decay and branching motion."
	case .Flow_Field:
		return "Particles advected through layered vector fields."
	case .Pellets:
		return "Particle physics with trails and density shading."
	case .Voronoi_CA:
		return "Drifting nearest-site regions with color-map controls."
	case .Moire:
		return "Interference patterns from rotating frequency grids."
	case .Vectors:
		return "A sampled field rendered as directional line glyphs."
	case .Primordial:
		return "Emergent particle motion with density feedback."
	}
	return ""
}

remaining_sim_draw :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind, width, height: f32) {
	bg0 := uifw.Color{0.018, 0.022, 0.028, 1}
	bg1 := uifw.Color{0.080, 0.076, 0.058, 1}
	switch kind {
	case .Slime_Mold:
		bg1 = {0.052, 0.092, 0.070, 1}
	case .Flow_Field:
		bg1 = {0.040, 0.074, 0.098, 1}
	case .Pellets:
		bg1 = {0.095, 0.058, 0.045, 1}
	case .Voronoi_CA:
		bg1 = {0.070, 0.065, 0.100, 1}
	case .Moire:
		bg1 = {0.090, 0.087, 0.045, 1}
	case .Vectors:
		bg1 = {0.030, 0.072, 0.075, 1}
	case .Primordial:
		bg1 = {0.082, 0.044, 0.082, 1}
	}
	uifw.gui_gradient_rect(gui, {0, 0, width, height}, bg0, bg1)

	switch kind {
	case .Slime_Mold:
		remaining_sim_draw_slime(sim, gui, width, height)
	case .Flow_Field:
		remaining_sim_draw_flow(sim, gui, width, height)
	case .Pellets:
		remaining_sim_draw_pellets(sim, gui, width, height)
	case .Voronoi_CA:
		remaining_sim_draw_voronoi(sim, gui, width, height)
	case .Moire:
		remaining_sim_draw_moire(sim, gui, width, height)
	case .Vectors:
		remaining_sim_draw_vectors(sim, gui, width, height)
	case .Primordial:
		remaining_sim_draw_primordial(sim, gui, width, height)
	}
}

remaining_sim_draw_slime :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, width, height: f32) {
	settings := sim.slime
	if settings.background_mode == .White {
		uifw.gui_rect(gui, {0, 0, width, height}, {0.90, 0.92, 0.88, 0.70})
	}
	center := uifw.Vec2{width * 0.5, height * 0.54}
	count := 90
	for i in 0 ..< count {
		t := f32(i) / f32(count)
		heading := (settings.agent_heading_start + (settings.agent_heading_end - settings.agent_heading_start) * t) * 0.01745329252
		angle := heading + t * 18.8495559 + sim.time * settings.agent_turn_rate * (0.8 + t)
		speed_norm := (settings.agent_speed_min + (settings.agent_speed_max - settings.agent_speed_min) * t) / 500.0
		r := (0.08 + t * 0.42 + speed_norm * 0.18) * min(width, height) * sim.scale
		p := uifw.Vec2{center.x + math.cos(angle) * r, center.y + math.sin(angle * 0.86) * r * 0.62}
		sensor := settings.agent_sensor_distance
		q := uifw.Vec2{center.x + math.cos(angle + settings.agent_sensor_angle) * (r + sensor), center.y + math.sin(angle * 0.86 + settings.agent_sensor_angle) * (r + sensor * 0.42) * 0.62}
		alpha := (0.18 + t * 0.48) * sim.intensity * min(settings.pheromone_deposition_rate / 100.0, 2)
		uifw.gui_line(gui, p, q, {0.54, 0.95, 0.68, alpha}, 2)
	}
}

remaining_sim_draw_flow :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, width, height: f32) {
	settings := sim.flow
	cols := 28
	rows := 16
	for y in 0 ..< rows {
		for x in 0 ..< cols {
			fx := (f32(x) + 0.5) / f32(cols)
			fy := (f32(y) + 0.5) / f32(rows)
				angle := noise_sample_2d(&settings.noise, fx, fy, sim.time) * 3.14159
			len := (14 + 340 * settings.vector_magnitude) * sim.scale
			c := uifw.Vec2{fx * width, fy * height}
			d := uifw.Vec2{math.cos(angle) * len, math.sin(angle) * len}
			uifw.gui_line(gui, {c.x - d.x, c.y - d.y}, {c.x + d.x, c.y + d.y}, {0.35, 0.82, 1.0, 0.42 * sim.intensity}, 2)
		}
	}
	particles := min(max(int(settings.total_pool_size / 2500), 20), 140)
	for i in 0 ..< particles {
		t := f32(i)
		life_phase := math.mod(sim.time * settings.particle_speed + t / max(f32(particles), 1), max(settings.particle_lifetime, 0.001))
		age := life_phase / max(settings.particle_lifetime, 0.001)
		x := width * (0.5 + 0.45 * math.sin(t * 1.37 + sim.time * settings.particle_speed))
		y := height * (0.5 + 0.40 * math.cos(t * 0.91 - sim.time * settings.particle_speed))
		size := f32(settings.particle_size)
		alpha := (1 - age) * (0.18 + settings.trail_deposition_rate * 0.28)
		color := uifw.Color{0.78, 0.94, 1.0, alpha}
		if settings.foreground_color_mode == .Random {
			color = {0.55 + 0.35 * math.sin(t), 0.48 + 0.42 * math.cos(t), 0.95, alpha}
		} else if settings.foreground_color_mode == .Direction {
			color = {0.95, 0.68, 0.30, alpha}
		}
		remaining_sim_draw_flow_particle(gui, settings.particle_shape, {x, y}, size, color)
	}
}

remaining_sim_draw_flow_particle :: proc(gui: ^uifw.Gui_Context, shape: Flow_Particle_Shape, center: uifw.Vec2, size: f32, color: uifw.Color) {
	rect := uifw.Rect{center.x - size, center.y - size, size * 2, size * 2}
	#partial switch shape {
	case .Square:
		uifw.gui_rect(gui, rect, color)
	case .Triangle:
		uifw.gui_quad(gui, {center.x, center.y - size}, {center.x + size, center.y + size}, {center.x - size, center.y + size}, {center.x, center.y - size}, color)
	case .Diamond:
		uifw.gui_quad(gui, {center.x, center.y - size}, {center.x + size, center.y}, {center.x, center.y + size}, {center.x - size, center.y}, color)
	case:
		uifw.gui_ellipse(gui, rect, color)
	}
}

remaining_sim_draw_pellets :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, width, height: f32) {
	settings := sim.pellets
	#partial switch settings.background_color_mode {
	case .White:
		uifw.gui_rect(gui, {0, 0, width, height}, {0.92, 0.91, 0.88, 0.70})
	case .Gray18:
		uifw.gui_rect(gui, {0, 0, width, height}, {0.18, 0.18, 0.18, 0.78})
	case .Color_Scheme:
		uifw.gui_gradient_rect(gui, {0, 0, width, height}, {0.10, 0.05, 0.08, 0.72}, {0.08, 0.10, 0.05, 0.72})
	case:
	}
	count := min(max(int(settings.particle_count / 64), 40), 220)
	for i in 0 ..< count {
		t := f32(i)
		orbit := settings.initial_velocity_min + (settings.initial_velocity_max - settings.initial_velocity_min) * (0.5 + 0.5 * math.sin(t))
		x := width * (0.5 + 0.43 * math.sin(t * 1.71 + sim.time * (0.22 + orbit)))
		y := height * (0.5 + 0.38 * math.cos(t * 1.19 + sim.time * (0.31 + orbit)))
		r := max(settings.particle_size * min(width, height), 1.5)
		color := uifw.Color{1.0, 0.54, 0.30, 0.24 + 0.48 * sim.intensity}
		if settings.foreground_color_mode == .Velocity {
			color = {0.34, 0.84, 1.0, color.a}
		} else if settings.foreground_color_mode == .Random {
			color = {0.82 + 0.18 * math.sin(t), 0.38 + 0.28 * math.cos(t * 1.7), 0.72, color.a}
		}
		uifw.gui_ellipse(gui, {x - r, y - r, r * 2, r * 2}, color)
	}
}

remaining_sim_draw_voronoi :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, width, height: f32) {
	settings := sim.voronoi
	target_cells := max(math.sqrt(f32(max(settings.point_count, 1))) * 0.7, 4)
	cell := max(min(width, height) / target_cells / max(sim.scale, 0.25), 12)
	cols := int(width / cell) + 2
	rows := int(height / cell) + 2
	for y in 0 ..< rows {
		for x in 0 ..< cols {
			phase := math.sin(f32(x) * 0.7 + f32(y) * 1.1 + sim.time * settings.time_scale)
			color := uifw.Color{0.30 + phase * 0.08, 0.24 + phase * 0.10, 0.58 + phase * 0.10, 0.36 * sim.intensity}
			rect := uifw.Rect{f32(x) * cell - cell, f32(y) * cell - cell, cell + 1, cell + 1}
			uifw.gui_rect(gui, rect, color)
			if settings.borders_enabled {
				uifw.gui_stroke(gui, rect, {1, 1, 1, 0.06})
			}
		}
	}
}

remaining_sim_draw_moire :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, width, height: f32) {
	settings := sim.moire
	center := uifw.Vec2{width * 0.5, height * 0.5}
	count := 72
	for i in 0 ..< count {
		t := f32(i) / f32(count)
		base_r := min(width, height) * (0.05 + t * 0.70)
		r := base_r * max(settings.moire_scale, 0.1)
		a0 := settings.moire_rotation + sim.time * settings.advect_speed * 0.18 + t * 3.14159
		a1 := settings.moire_rotation3 - sim.time * settings.advect_speed * 0.11 + t * 6.28318
		if settings.generator_type == .Radial {
			swirl := settings.radial_swirl_strength * math.sin(t * settings.radial_starburst_count + sim.time)
			rect := uifw.Rect{center.x - r, center.y - r, r * 2, r * 2}
			alpha := (0.06 + t * 0.22) * settings.moire_amount
			uifw.gui_ellipse_stroke(gui, rect, {0.98, 0.78, 0.38, alpha}, 1 + settings.moire_interference * 3)
			uifw.gui_rotated_rect(gui, {center.x - r, center.y - 0.5, r * 2, 1.0}, a0 + swirl, {0.42, 0.96, 0.86, 0.08 * settings.moire_amount})
		} else {
			span := max(width, height) * 1.25
			row_y := center.y + (t - 0.5) * height * 1.25
			x := center.x - span * 0.5
			uifw.gui_rotated_rect(gui, {x, row_y, span, 1.0 + settings.moire_interference * 3}, a0, {0.96, 0.84, 0.38, 0.12 * settings.moire_amount})
			uifw.gui_rotated_rect(gui, {x, row_y, span, 1.0 + settings.moire_weight3 * 4}, a1, {0.45, 0.95, 0.88, 0.08 * settings.moire_amount})
		}
	}
	glow := min(width, height) * 0.28 * max(settings.radial_center_brightness, 0)
	if settings.generator_type == .Radial && glow > 1 {
		uifw.gui_ellipse(gui, {center.x - glow, center.y - glow, glow * 2, glow * 2}, {1.0, 0.92, 0.56, 0.035 * settings.moire_amount})
	}
}

remaining_sim_draw_vectors :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, width, height: f32) {
	settings := sim.vectors
	#partial switch settings.background_color_mode {
	case .White:
		uifw.gui_rect(gui, {0, 0, width, height}, {0.92, 0.93, 0.90, 0.72})
	case .Gray18:
		uifw.gui_rect(gui, {0, 0, width, height}, {0.18, 0.18, 0.18, 0.84})
	case .Color_Scheme:
		uifw.gui_gradient_rect(gui, {0, 0, width, height}, {0.06, 0.12, 0.10, 0.82}, {0.11, 0.08, 0.18, 0.82})
	case:
	}
	spacing := max(settings.density, VECTORS_MIN_DENSITY)
	cols := int(2.0 / spacing)
	rows := int(1.12 / spacing)
	cols = min(max(cols, 8), 480)
	rows = min(max(rows, 5), 360)
	for y in 0 ..< rows {
		for x in 0 ..< cols {
			px := (f32(x) + 0.5) / f32(cols) * width
			py := (f32(y) + 0.5) / f32(rows) * height
				v := noise_sample_2d(&settings.noise, f32(x) / f32(cols), f32(y) / f32(rows), sim.time)
			angle := v * 3.14159
			len := max(settings.line_length, 0.001) * min(width, height) * (0.5 + math.clamp(v, 0, 1) * 0.5)
			d := uifw.Vec2{math.cos(angle) * len, math.sin(angle) * len}
			line_width := max(settings.line_width * min(width, height), 1)
			uifw.gui_line(gui, {px, py}, {px + d.x, py + d.y}, {0.42, 0.93, 0.84, 0.55 * sim.intensity}, line_width)
		}
	}
}

remaining_sim_draw_primordial :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, width, height: f32) {
	settings := sim.primordial
	center := uifw.Vec2{width * 0.5, height * 0.5}
	count := 120
	for i in 0 ..< count {
		t := f32(i) / f32(count)
		alpha := settings.alpha * 0.01745329252
		angle := t * 6.2831853 * 7 + alpha + sim.time * settings.velocity * (1 + t)
		r := min(width, height) * (settings.radius + 0.43 * math.sin(t * 9.0 + sim.time * settings.beta) * 0.5 + t * 0.36) * sim.scale
		x := center.x + math.cos(angle) * r
		y := center.y + math.sin(angle * 1.17) * r
		size := 2.5 + 5.0 * sim.density
		uifw.gui_ellipse(gui, {x - size, y - size, size * 2, size * 2}, {0.93, 0.42, 0.94, 0.22 + 0.48 * sim.intensity})
	}
}
