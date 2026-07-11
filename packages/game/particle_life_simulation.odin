package game

import uifw "../ui"

import "core:math"

particle_life_target_particle_count :: proc(settings: Particle_Life_Settings) -> u32 {
	return max(min(settings.particle_count, PARTICLE_LIFE_MAX_PARTICLE_COUNT), 1)
}

particle_life_target_species_count :: proc(settings: Particle_Life_Settings) -> u32 {
	return max(min(settings.species_count, PARTICLE_LIFE_MAX_SPECIES), 1)
}

particle_life_world_size_for_viewport :: proc(width, height: f32) -> [2]f32 {
	aspect := max(width, 1) / max(height, 1)
	return {max(aspect, 0.0001) * 2.0, 2.0}
}

particle_life_world_size :: proc(sim: ^Particle_Life_Simulation) -> [2]f32 {
	return particle_life_world_size_for_viewport(f32(max(sim.gpu.width, 1)), f32(max(sim.gpu.height, 1)))
}

particle_life_collision_distance :: proc(settings: Particle_Life_Settings) -> f32 {
	return max(settings.particle_size * 0.002, 0.0001)
}

particle_life_target_grid_cell_size :: proc(settings: Particle_Life_Settings) -> f32 {
	return max(settings.max_distance * PARTICLE_LIFE_FORCE_GRID_CELL_SCALE, 0.001)
}

particle_life_target_grid_axis :: proc(settings: Particle_Life_Settings) -> u32 {
	axis := u32(math.ceil(2.0 / particle_life_target_grid_cell_size(settings)))
	return max(min(axis, PARTICLE_LIFE_MAX_GRID_AXIS), 4)
}

particle_life_target_grid_dimensions :: proc(settings: Particle_Life_Settings, world_size: [2]f32) -> (u32, u32) {
	cell_size: f32
	grid_width, grid_height: u32
	scales := [4]f32{0.25, 1.0 / 3.0, 0.5, 1.0}
	for scale in scales {
		cell_size = max(settings.max_distance * scale, 0.001)
		grid_width = u32(math.ceil(max(world_size[0], 0.0001) / cell_size))
		grid_height = u32(math.ceil(max(world_size[1], 0.0001) / cell_size))
		if grid_width <= PARTICLE_LIFE_MAX_GRID_AXIS && grid_height <= PARTICLE_LIFE_MAX_GRID_AXIS {
			break
		}
	}
	return max(min(grid_width, PARTICLE_LIFE_MAX_GRID_AXIS), 4), max(min(grid_height, PARTICLE_LIFE_MAX_GRID_AXIS), 4)
}

particle_life_target_collision_grid_dimensions :: proc(settings: Particle_Life_Settings, world_size: [2]f32) -> (u32, u32) {
	cell_size := particle_life_collision_distance(settings)
	grid_width := u32(math.ceil(max(world_size[0], 0.0001) / cell_size))
	grid_height := u32(math.ceil(max(world_size[1], 0.0001) / cell_size))
	return max(min(grid_width, PARTICLE_LIFE_MAX_GRID_AXIS), 4), max(min(grid_height, PARTICLE_LIFE_MAX_GRID_AXIS), 4)
}

particle_life_target_neighbor_radius_cells :: proc(settings: Particle_Life_Settings, grid_width, grid_height: u32, world_size: [2]f32) -> u32 {
	cell_w := world_size[0] / f32(max(grid_width, 1))
	cell_h := world_size[1] / f32(max(grid_height, 1))
	cell_size := max(max(cell_w, cell_h), 0.0001)
	radius := u32(math.ceil(max(settings.max_distance, cell_size) / cell_size))
	return max(radius, 1)
}

particle_life_grid_satisfies_target :: proc(current_width, current_height, current_neighbor_radius, target_width, target_height, target_neighbor_radius: u32) -> bool {
	return current_width >= target_width &&
		current_height >= target_height &&
		current_neighbor_radius >= target_neighbor_radius
}

// CPU mirrors of the GPU contiguous-bin construction. These keep the exact
// membership/order-independent invariants testable without a Vulkan device.
particle_life_grid_exclusive_offsets :: proc(counts: []u32, offsets: []u32) -> u32 {
	running: u32
	for i in 0 ..< min(len(counts), len(offsets)) {
		offsets[i] = running
		running += counts[i]
	}
	return running
}

particle_life_grid_scatter_indices :: proc(cell_indices, offsets: []u32, cursors, out: []u32) -> bool {
	for i in 0 ..< len(cursors) {
		cursors[i] = 0
	}
	for cell_index, particle_index in cell_indices {
		if int(cell_index) >= len(offsets) || int(cell_index) >= len(cursors) {
			return false
		}
		destination := offsets[cell_index] + cursors[cell_index]
		if int(destination) >= len(out) {
			return false
		}
		out[destination] = u32(particle_index)
		cursors[cell_index] += 1
	}
	return true
}

particle_life_current_grid_satisfies_settings :: proc(sim: ^Particle_Life_Simulation) -> bool {
	world_size := particle_life_world_size(sim)
	target_grid_width, target_grid_height := particle_life_target_grid_dimensions(sim.settings, world_size)
	target_collision_width, target_collision_height := particle_life_target_collision_grid_dimensions(sim.settings, world_size)
	// A finer existing grid is reusable only if its stored search radius covers
	// the current distance at that finer cell size. Comparing against the target
	// grid's radius can incorrectly accept a stale grid after max_distance moves.
	current_neighbor_radius := particle_life_target_neighbor_radius_cells(
		sim.settings,
		sim.gpu.grid_width,
		sim.gpu.grid_height,
		world_size,
	)
	return particle_life_grid_satisfies_target(
		sim.gpu.grid_width,
		sim.gpu.grid_height,
		sim.gpu.neighbor_radius_cells,
		target_grid_width,
		target_grid_height,
		current_neighbor_radius,
	) && (!sim.settings.collision_enabled ||
		sim.gpu.collision_grid_width >= target_collision_width &&
		sim.gpu.collision_grid_height >= target_collision_height)
}

particle_life_target_analysis_grid_axis :: proc(settings: Particle_Life_Settings) -> u32 {
	return max(min(settings.analysis_grid_size, 1024), 64)
}

// Far-field forces change smoothly enough to reuse briefly. Nearby forces are
// still evaluated every step; this stride only rotates the expensive far-field
// refresh between complete GPU workgroups.
particle_life_force_refresh_stride :: proc(settings: Particle_Life_Settings) -> u32 {
	if !settings.force_temporal_coherence || settings.particle_count < 100_000 || settings.max_distance <= 0.05 {
		return 1
	}
	if settings.max_distance >= 0.18 {
		return 8
	}
	if settings.max_distance >= 0.12 {
		return 4
	}
	return 2
}

particle_life_force_sample_limit :: proc(settings: Particle_Life_Settings) -> u32 {
	if !settings.force_dense_sampling || settings.particle_count < 100_000 {
		return 0
	}
	return 64
}

particle_life_analysis_tile_count_for_axis :: proc(axis: u32) -> u32 {
	return (max(axis, 1) + PARTICLE_LIFE_ANALYSIS_TILE_SIZE - 1) / PARTICLE_LIFE_ANALYSIS_TILE_SIZE
}

particle_life_default_settings :: proc() -> Particle_Life_Settings {
	settings := Particle_Life_Settings {
		particle_count = 15000,
		species_count = 4,
		max_force = 0.5,
		max_distance = 0.05,
		friction = 0.5,
		beta = 0.5,
		brownian_motion = 0.5,
		particle_size = 4,
		cursor_size = 0.5,
		cursor_strength = 5.0,
		position_generator = 0,
		type_generator = 4,
		force_generator = 0,
		force_random_min = -1.0,
		force_random_max = 1.0,
		camera_zoom = 1,
		color_mode = .Color_Scheme,
		background_color_mode = .Color_Scheme,
		background_index = int(Vector_Background_Mode.Color_Scheme),
		background_color = {0.015, 0.018, 0.024, 1},
		post_processing = post_processing_default_settings(),
		brightness = 1,
		contrast = 1,
		saturation = 1,
		gamma = 1,
		trails_enabled = false,
		trail_fade_amount = 0.48,
		infinite_tiles_enabled = true,
		infinite_tile_radius = 4,
		analysis_enabled = false,
		analysis_interval_frames = 8,
		analysis_grid_size = 512,
		coherence_threshold = 0.55,
		min_blob_area_cells = 12,
		blob_overlay_enabled = false,
		collision_enabled = true,
		collision_distance = 0.008,
		collision_iterations = 3,
		collision_relaxation = 0.75,
		collision_damping = 0.9,
		force_temporal_coherence = true,
		force_dense_sampling = true,
		wrap_edges = true,
		paused = false,
		custom_force_matrix = true,
	}
	settings.force_matrix[0 * PARTICLE_LIFE_MAX_SPECIES + 0] = -0.1
	settings.force_matrix[0 * PARTICLE_LIFE_MAX_SPECIES + 1] = 0.2
	settings.force_matrix[0 * PARTICLE_LIFE_MAX_SPECIES + 2] = -0.1
	settings.force_matrix[0 * PARTICLE_LIFE_MAX_SPECIES + 3] = 0.1
	settings.force_matrix[1 * PARTICLE_LIFE_MAX_SPECIES + 0] = 0.2
	settings.force_matrix[1 * PARTICLE_LIFE_MAX_SPECIES + 1] = -0.1
	settings.force_matrix[1 * PARTICLE_LIFE_MAX_SPECIES + 2] = 0.3
	settings.force_matrix[1 * PARTICLE_LIFE_MAX_SPECIES + 3] = -0.1
	settings.force_matrix[2 * PARTICLE_LIFE_MAX_SPECIES + 0] = -0.1
	settings.force_matrix[2 * PARTICLE_LIFE_MAX_SPECIES + 1] = 0.3
	settings.force_matrix[2 * PARTICLE_LIFE_MAX_SPECIES + 2] = -0.1
	settings.force_matrix[2 * PARTICLE_LIFE_MAX_SPECIES + 3] = 0.2
	settings.force_matrix[3 * PARTICLE_LIFE_MAX_SPECIES + 0] = 0.1
	settings.force_matrix[3 * PARTICLE_LIFE_MAX_SPECIES + 1] = -0.1
	settings.force_matrix[3 * PARTICLE_LIFE_MAX_SPECIES + 2] = 0.2
	settings.force_matrix[3 * PARTICLE_LIFE_MAX_SPECIES + 3] = -0.1
	color_scheme_name_set(&settings.color_scheme, "ZELDA_Particles1")
	return settings
}

particle_life_apply_builtin_preset :: proc(sim: ^Particle_Life_Simulation, index: int) {
	if index < 0 || index >= len(PARTICLE_LIFE_BUILTIN_PRESET_NAMES) {
		return
	}
	sim.runtime.current_preset_index = index
	settings := particle_life_default_settings()
	particle_life_settings_preserve_color_scheme(&settings, sim.settings)
	particle_life_load_settings(sim, settings)
}

particle_life_init :: proc(sim: ^Particle_Life_Simulation, width, height: i32) {
	sim.settings = particle_life_default_settings()
	sim.runtime = {seed = 0x3c6ef372, needs_reset = true, force_curve_narrow_range = true, camera_zoom = 1, camera_target_zoom = 1, camera_smoothing_factor = CAMERA_DEFAULT_SMOOTHING}
	sim.gpu = {width = width, height = height}
	sim.blob_tracker = {next_id = 1}
}

particle_life_resize :: proc(sim: ^Particle_Life_Simulation, width, height: i32) {
	if sim.gpu.width == width && sim.gpu.height == height {
		return
	}
	sim.gpu.width = width
	sim.gpu.height = height
	sim.gpu.ready = false
}

particle_life_step :: proc(sim: ^Particle_Life_Simulation, dt: f32) {
	if sim.settings.paused {
		return
	}
	_ = dt
	sim.runtime.frame_index += 1
}

particle_life_apply_frame_input :: proc(sim: ^Particle_Life_Simulation, input: Ui_Frame_Input) {
	tool_set := canvas_tool_set_for_mode(.Particle_Life)
	canvas_tool_update_selection(&tool_set, &sim.canvas_tool, input)
	camera := particle_life_camera_control_state(sim)
	camera_controls_apply_input(&camera, input)
	particle_life_store_camera_control_state(sim, camera)

	sim.runtime.cursor_active = 0
	if !input.mouse_down || input.window_width <= 0 || input.window_height <= 0 {
		return
	}
	world := particle_life_screen_to_world(sim, input.mouse_pos, input.window_width, input.window_height)
	sim.runtime.cursor_x = world[0]
	sim.runtime.cursor_y = world[1]
	tool := canvas_tool_selected(&tool_set, &sim.canvas_tool)
	sim.runtime.cursor_active = canvas_tool_interaction_mode(tool, input.mouse_button == 3 || input.secondary_down)
}

particle_life_view_bounds :: proc(sim: ^Particle_Life_Simulation, width, height: f32) -> [4]f32 {
	world_size := particle_life_world_size_for_viewport(width, height)
	zoom := max(sim.runtime.camera_zoom, 0.25)
	half_x := world_size[0] * 0.5 / zoom
	half_y := world_size[1] * 0.5 / zoom
	return {
		sim.runtime.camera_x - half_x,
		sim.runtime.camera_y - half_y,
		sim.runtime.camera_x + half_x,
		sim.runtime.camera_y + half_y,
	}
}

particle_life_camera_control_state :: proc(sim: ^Particle_Life_Simulation) -> Camera_Control_State {
	return {
		position = {sim.runtime.camera_x, sim.runtime.camera_y},
		target_position = {sim.runtime.camera_target_x, sim.runtime.camera_target_y},
		zoom = sim.runtime.camera_zoom,
		target_zoom = sim.runtime.camera_target_zoom,
		smoothing_factor = sim.runtime.camera_smoothing_factor,
	}
}

particle_life_store_camera_control_state :: proc(sim: ^Particle_Life_Simulation, camera: Camera_Control_State) {
	sim.runtime.camera_x = camera.position[0]
	sim.runtime.camera_y = camera.position[1]
	sim.runtime.camera_zoom = max(camera.zoom, CAMERA_MIN_ZOOM)
	sim.runtime.camera_target_x = camera.target_position[0]
	sim.runtime.camera_target_y = camera.target_position[1]
	sim.runtime.camera_target_zoom = max(camera.target_zoom, CAMERA_MIN_ZOOM)
	sim.runtime.camera_smoothing_factor = camera.smoothing_factor
}

particle_life_screen_to_world :: proc(sim: ^Particle_Life_Simulation, mouse_pos: uifw.Vec2, width, height: i32) -> [2]f32 {
	camera := particle_life_camera_control_state(sim)
	camera_controls_sync(&camera)
	w := f32(max(width, 1))
	h := f32(max(height, 1))
	world_size := particle_life_world_size_for_viewport(w, h)
	zoom := max(camera.target_zoom, CAMERA_MIN_ZOOM)
	ndc_x := (mouse_pos.x / w) * 2.0 - 1.0
	ndc_y := -((mouse_pos.y / h) * 2.0 - 1.0)
	world := [2]f32 {
		camera.target_position[0] + ndc_x * world_size[0] * 0.5 / zoom,
		camera.target_position[1] + ndc_y * world_size[1] * 0.5 / zoom,
	}
	particle_life_store_camera_control_state(sim, camera)
	return world
}

particle_life_world_to_screen :: proc(sim: ^Particle_Life_Simulation, world: [2]f32, width, height: f32) -> uifw.Vec2 {
	bounds := particle_life_view_bounds(sim, width, height)
	normalized_x := (world[0] - bounds[0]) / max(bounds[2] - bounds[0], 0.00001)
	normalized_y := (world[1] - bounds[1]) / max(bounds[3] - bounds[1], 0.00001)
	return {normalized_x * width, (1.0 - normalized_y) * height}
}

particle_life_blob_overlay_radius_px :: proc(sim: ^Particle_Life_Simulation, blob: Particle_Life_Tracked_Blob, width, height: f32) -> f32 {
	bounds := particle_life_view_bounds(sim, width, height)
	world_w := max(bounds[2] - bounds[0], 0.00001)
	world_h := max(bounds[3] - bounds[1], 0.00001)
	blob_w := max(blob.bounds[2] - blob.bounds[0], 0.0)
	blob_h := max(blob.bounds[3] - blob.bounds[1], 0.0)
	if blob_w > 0 || blob_h > 0 {
		return max(max(blob_w * width / world_w, blob_h * height / world_h) * 0.5, 8.0)
	}
	axis := f32(max(particle_life_target_analysis_grid_axis(sim.settings), 1))
	radius_world := math.sqrt(f32(max(blob.area, 1)) / PARTICLE_LIFE_PI) * (2.0 / axis)
	screen_scale := min(width / world_w, height / world_h)
	return max(radius_world * screen_scale, 8.0)
}

particle_life_draw_blob_overlay :: proc(sim: ^Particle_Life_Simulation, ctx: ^uifw.Gui_Context, width, height: f32) {
	if !sim.settings.blob_overlay_enabled || sim.blob_tracker.count == 0 || width <= 0 || height <= 0 {
		return
	}
	uifw.gui_scissor_begin(ctx, {0, 0, width, height})
	for i: u32 = 0; i < sim.blob_tracker.count; i += 1 {
		blob := sim.blob_tracker.blobs[i]
		if blob.confidence <= 0.0 {
			continue
		}
		center := particle_life_world_to_screen(sim, blob.last_position, width, height)
		radius := min(particle_life_blob_overlay_radius_px(sim, blob, width, height), max(width, height))
		alpha := max(min(blob.confidence, 1.0), 0.18)
		color := uifw.Color{0.18, 0.86, 1.0, 0.35 * alpha}
		stroke := uifw.Color{0.68, 0.96, 1.0, 0.85 * alpha}
		rect := uifw.Rect{center.x - radius, center.y - radius, radius * 2.0, radius * 2.0}
		uifw.gui_ellipse(ctx, rect, color)
		uifw.gui_ellipse_stroke(ctx, rect, stroke, 2)
		uifw.gui_line(ctx, {center.x - 5, center.y}, {center.x + 5, center.y}, stroke, 1)
		uifw.gui_line(ctx, {center.x, center.y - 5}, {center.x, center.y + 5}, stroke, 1)
	}
	uifw.gui_scissor_end(ctx)
}

particle_life_random01 :: proc(seed: ^u32) -> f32 {
	x := seed^ + 0x9e3779b9
	x = (x ~ (x >> 16)) * 0x7feb352d
	x = (x ~ (x >> 15)) * 0x846ca68b
	x = x ~ (x >> 16)
	seed^ = x
	return f32(x) / f32(0xffffffff)
}

particle_life_random_range :: proc(seed: ^u32, min_value, max_value: f32) -> f32 {
	return min_value + (max_value - min_value) * particle_life_random01(seed)
}

particle_life_hash01 :: proc(seed: u32) -> f32 {
	x := seed
	x = ((x >> 16) ~ x) * 0x45d9f3b
	x = ((x >> 16) ~ x) * 0x45d9f3b
	x = (x >> 16) ~ x
	return f32(x) / f32(0xffffffff)
}

particle_life_frac :: proc(value: f32) -> f32 {
	return value - math.floor(value)
}

particle_life_generate_position :: proc(index, species_count, position_generator: u32, seed: u32) -> [2]f32 {
	type_id := index % max(species_count, 1)
	n_types := max(species_count, 1)
	rx := particle_life_hash01(seed * 2)
	ry := particle_life_hash01(seed * 3)
	switch position_generator {
	case 1: // Center
		return {(rx * 2.0 - 1.0) * 0.3, (ry * 2.0 - 1.0) * 0.3}
	case 2: // UniformCircle
		angle := rx * PARTICLE_LIFE_TAU
		radius := math.sqrt(ry) * 0.8
		return {math.cos(angle) * radius, math.sin(angle) * radius}
	case 3: // CenteredCircle
		angle := rx * PARTICLE_LIFE_TAU
		radius := ry * 0.8
		return {math.cos(angle) * radius, math.sin(angle) * radius}
	case 4: // Ring
		angle := rx * PARTICLE_LIFE_TAU
		radius := 0.35 + 0.01 * (ry - 0.5) * 2.0
		return {math.cos(angle) * radius, math.sin(angle) * radius}
	case 5: // RainbowRing
		angle := (0.3 * (rx - 0.5) * 2.0 + f32(type_id)) / f32(n_types) * PARTICLE_LIFE_TAU
		radius := 0.35 + 0.01 * (ry - 0.5) * 2.0
		return {math.cos(angle) * radius, math.sin(angle) * radius}
	case 6: // ColorBattle
		center_angle := f32(type_id) / f32(n_types) * PARTICLE_LIFE_TAU
		angle := rx * PARTICLE_LIFE_TAU
		radius := ry * 0.05
		return {
			0.25 * math.cos(center_angle) + math.cos(angle) * radius,
			0.25 * math.sin(center_angle) + math.sin(angle) * radius,
		}
	case 7: // ColorWheel
		center_angle := f32(type_id) / f32(n_types) * PARTICLE_LIFE_TAU
		return {
			0.15 * math.cos(center_angle) + (rx - 0.5) * 2.0 * 0.1,
			0.15 * math.sin(center_angle) + (ry - 0.5) * 2.0 * 0.1,
		}
	case 8: // Line
		return {rx * 2.0 - 1.0, (ry - 0.5) * 0.3}
	case 9: // Spiral
		f := rx
		angle := 2.0 * PARTICLE_LIFE_TAU * f
		spread := 0.25 * min(f, 0.2)
		radius := 0.45 * f + spread * (ry - 0.5) * 2.0
		return {radius * math.cos(angle), radius * math.sin(angle)}
	case 10: // RainbowSpiral
		type_spread := 0.3 / f32(n_types)
		f := f32(type_id + 1) / f32(n_types + 2) + type_spread * (rx - 0.5) * 2.0
		f = max(min(f, 1.0), 0.0)
		angle := 2.0 * PARTICLE_LIFE_TAU * f
		spread := 0.25 * min(f, 0.2)
		radius := 0.45 * f + spread * (ry - 0.5) * 2.0
		return {radius * math.cos(angle), radius * math.sin(angle)}
	case:
		return {rx * 2.0 - 1.0, ry * 2.0 - 1.0}
	}
}

particle_life_generate_position_for_world :: proc(index, species_count, position_generator: u32, seed: u32, world_size: [2]f32) -> (position, normalized_position: [2]f32) {
	normalized_position = particle_life_generate_position(index, species_count, position_generator, seed)
	half_size := [2]f32{max(world_size[0], 0.0001) * 0.5, max(world_size[1], 0.0001) * 0.5}
	position = {normalized_position[0] * half_size[0], normalized_position[1] * half_size[1]}
	return
}

particle_life_generate_species :: proc(position: [2]f32, n_types, type_generator: u32, seed: u32) -> u32 {
	n := max(n_types, 1)
	switch type_generator {
	case 0: // Radial
		distance := math.sqrt(position[0] * position[0] + position[1] * position[1])
		normalized := max(min(distance / 1.41421356, 1.0), 0.0)
		return u32(normalized * f32(n)) % n
	case 1: // Polar
		angle := math.atan2(position[1], position[0])
		normalized := (angle + PARTICLE_LIFE_PI) / PARTICLE_LIFE_TAU
		return u32(normalized * f32(n)) % n
	case 2: // StripesH
		normalized_y := (position[1] + 1.0) * 0.5
		return u32(normalized_y * f32(n)) % n
	case 3: // StripesV
		normalized_x := (position[0] + 1.0) * 0.5
		return u32(normalized_x * f32(n)) % n
	case 5: // LineH
		if math.abs(position[1]) < 0.1 {
			return 0
		}
		normalized_y := (position[1] + 1.0) * 0.5
		return (u32(normalized_y * f32(max(n - 1, 1))) + 1) % n
	case 6: // LineV
		if math.abs(position[0]) < 0.1 {
			return 0
		}
		normalized_x := (position[0] + 1.0) * 0.5
		return (u32(normalized_x * f32(max(n - 1, 1))) + 1) % n
	case 7: // Spiral
		distance := math.sqrt(position[0] * position[0] + position[1] * position[1])
		angle := math.atan2(position[1], position[0])
		spiral_value := distance + angle * 0.159
		return u32(particle_life_frac(spiral_value * 2.0) * f32(n)) % n
	case 8: // Dithered
		distance := math.sqrt(position[0] * position[0] + position[1] * position[1])
		band_value := distance * f32(n)
		base_band := u32(math.floor(band_value))
		noise_seed := u32((position[0] + 1.0) * 1000.0) + u32((position[1] + 1.0) * 1000.0) + seed
		noise := particle_life_hash01(noise_seed)
		band_fraction := particle_life_frac(band_value)
		if band_fraction > 0.8 && noise > 0.5 {
			return (base_band + 1) % n
		} else if band_fraction < 0.2 && noise < 0.5 {
			return (base_band + n - 1) % n
		}
		return base_band % n
	case 9: // WavyLineH
		normalized_y := (position[1] + 1.0) * 0.5
		line_spacing := 1.0 / f32(n)
		for i: u32 = 0; i < n; i += 1 {
			line_center := (f32(i) + 0.5) * line_spacing
			line_y := line_center + math.sin(position[0] * 2.5 * PARTICLE_LIFE_PI) * 0.25
			if math.abs(normalized_y - line_y) < 0.08 {
				return i
			}
		}
		return u32(normalized_y * f32(n)) % n
	case 10: // WavyLineV
		normalized_x := (position[0] + 1.0) * 0.5
		line_spacing := 1.0 / f32(n)
		for i: u32 = 0; i < n; i += 1 {
			line_center := (f32(i) + 0.5) * line_spacing
			line_x := line_center + math.sin(position[1] * 2.5 * PARTICLE_LIFE_PI) * 0.25
			if math.abs(normalized_x - line_x) < 0.08 {
				return i
			}
		}
		return u32(normalized_x * f32(n)) % n
	case:
		return u32(particle_life_hash01(seed * 4) * f32(n)) % n
	}
}
