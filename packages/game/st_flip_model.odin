package game

import "core:math"

ST_FLIP_MIN_PARTICLE_COUNT :: u32(8_192)
ST_FLIP_MAX_PARTICLE_COUNT :: u32(8_388_608)
ST_FLIP_DEFAULT_PARTICLE_COUNT :: u32(131_072)
ST_FLIP_MIN_GRID_HEIGHT :: u32(36)
ST_FLIP_MAX_GRID_HEIGHT :: u32(1_152)

ST_FLIP_RESOLUTION_NAMES := [?]string{"1/4x", "1/2x", "1x", "2x", "4x", "8x"}
ST_FLIP_RESOLUTION_GRID_HEIGHTS := [?]u32{36, 72, 144, 288, 576, 1_152}
ST_FLIP_RESOLUTION_PARTICLE_COUNTS := [?]u32{8_192, 32_768, 131_072, 524_288, 2_097_152, 8_388_608}

ST_Flip_Initial_Condition :: enum u32 {
	Dam_Break,
	Pool,
	Twin_Drops,
	Empty,
}

ST_Flip_Interaction_Mode :: enum u32 {
	Stir,
	Inject,
	Erase,
	Vortex,
}

ST_FLIP_INITIAL_CONDITION_NAMES := [?]string{"Dam Break", "Ink Bath", "Twin Drops", "Empty"}
ST_FLIP_INTERACTION_MODE_NAMES := [?]string{"Stir", "Inject", "Vortex"}
ST_FLIP_INTERACTION_MODES := [?]ST_Flip_Interaction_Mode{.Stir, .Inject, .Vortex}
ST_FLIP_BUILTIN_PRESET_NAMES := [?]string{"Ink Bath", "Slow Fade", "Turbulent Ink", "Persistent Ink"}

// Only authored, serializable values belong here. Particle positions, temporal
// residuals, grid fields, pressure scratch, and interaction impulses are owned
// by ST_Flip_Runtime_State or the renderer's GPU state.
ST_Flip_Settings :: struct {
	color_scheme: Color_Scheme_Name,
	color_scheme_reversed: bool,
	post_processing: Post_Processing_Settings,
	particle_count: u32,
	grid_height: u32,
	target_cfl: f32,
	simulation_speed: f32,
	gravity: f32,
	flip_ratio: f32,
	jitter_strength: f32,
	phase_steepness: f32,
	ink_dissipation: f32,
	pressure_iterations: u32,
	render_smoothing: f32,
	random_seed: u32,
	initial_condition: ST_Flip_Initial_Condition,
	initial_condition_index: int,
	paused: bool,
}

ST_Flip_Runtime_State :: struct {
	time: f32,
	previous_dt: f32,
	reset_requested: bool,
	noise_seed_requested: bool,
	initialized: bool,
	cursor_world: [2]f32,
	cursor_world_previous: [2]f32,
	cursor_velocity: [2]f32,
	cursor_active: bool,
	cursor_mode: ST_Flip_Interaction_Mode,
	brush_size: f32,
	brush_strength: f32,
	interaction_mode: ST_Flip_Interaction_Mode,
	interaction_mode_index: int,
	camera: Camera_Control_State,
	canvas_tool: Canvas_Tool_State,
	preset_ui: Preset_Fieldset_State,
	brush_mode_query: [64]u8,
	builtin_preset_index: int,
}

ST_Flip_Simulation :: struct {
	settings: ^ST_Flip_Settings,
	runtime: ^ST_Flip_Runtime_State,
}

ST_Flip_Particle :: struct #align(16) {
	position: [2]f32,
	velocity: [2]f32,
	time_residual: f32,
	random_state: u32,
	_padding: [2]u32,
}

ST_Flip_Sim_Params :: struct #align(16) {
	grid_width: u32,
	grid_height: u32,
	particle_count: u32,
	pass_index: u32,
	dt: f32,
	previous_dt: f32,
	cell_size: f32,
	target_cfl: f32,
	gravity: f32,
	flip_ratio: f32,
	jitter_strength: f32,
	phase_steepness: f32,
	reference_mass: f32,
	ink_dissipation: f32,
	brush_size: f32,
	brush_strength: f32,
	time: f32,
	_padding_time: f32,
	cursor: [2]f32,
	cursor_velocity: [2]f32,
	cursor_active: u32,
	cursor_mode: u32,
	random_seed: u32,
	step_index: u32,
}

ST_Flip_Present_Params :: struct #align(16) {
	color_scheme_reversed: u32,
	render_smoothing: f32,
	exposure: f32,
	_padding: f32,
}

st_flip_default_settings :: proc() -> ST_Flip_Settings {
	settings := ST_Flip_Settings {
		post_processing = post_processing_default_settings(),
		particle_count = ST_FLIP_DEFAULT_PARTICLE_COUNT,
		grid_height = 144,
		target_cfl = 8,
		simulation_speed = 1,
		gravity = 0,
		flip_ratio = 0.98,
		jitter_strength = 1,
		phase_steepness = 0.5,
		ink_dissipation = 0.12,
		pressure_iterations = 80,
		render_smoothing = 0.35,
		random_seed = 42,
		initial_condition = .Pool,
		initial_condition_index = int(ST_Flip_Initial_Condition.Pool),
	}
	color_scheme_name_set(&settings.color_scheme, "MATPLOTLIB_bone")
	return settings
}

st_flip_validate_settings :: proc(settings: ^ST_Flip_Settings) {
	if settings == nil do return
	settings.particle_count = max(min(settings.particle_count, ST_FLIP_MAX_PARTICLE_COUNT), ST_FLIP_MIN_PARTICLE_COUNT)
	settings.grid_height = max(min(settings.grid_height, ST_FLIP_MAX_GRID_HEIGHT), ST_FLIP_MIN_GRID_HEIGHT)
	settings.target_cfl = max(min(settings.target_cfl, 30), 0.25)
	settings.simulation_speed = max(min(settings.simulation_speed, 4), 0.05)
	settings.gravity = max(min(settings.gravity, 20), -20)
	settings.flip_ratio = max(min(settings.flip_ratio, 1), 0)
	settings.jitter_strength = max(min(settings.jitter_strength, 1), 0)
	settings.phase_steepness = max(min(settings.phase_steepness, 1.5), 0.1)
	settings.ink_dissipation = max(min(settings.ink_dissipation, 5), 0)
	settings.pressure_iterations = max(min(settings.pressure_iterations, 256), 16)
	settings.render_smoothing = max(min(settings.render_smoothing, 1), 0)
	settings.initial_condition_index = max(min(settings.initial_condition_index, len(ST_FLIP_INITIAL_CONDITION_NAMES) - 1), 0)
	settings.initial_condition = ST_Flip_Initial_Condition(settings.initial_condition_index)
}

st_flip_runtime_defaults :: proc() -> ST_Flip_Runtime_State {
	return {brush_size = 0.1, brush_strength = 7, interaction_mode = .Inject, interaction_mode_index = 1}
}

st_flip_resolution_index :: proc(grid_height: u32) -> int {
	best := 0
	best_distance := abs(int(grid_height) - int(ST_FLIP_RESOLUTION_GRID_HEIGHTS[0]))
	for height, i in ST_FLIP_RESOLUTION_GRID_HEIGHTS[1:] {
		distance := abs(int(grid_height) - int(height))
		if distance < best_distance {
			best = i + 1
			best_distance = distance
		}
	}
	return best
}

st_flip_apply_resolution :: proc(settings: ^ST_Flip_Settings, index: int) {
	if settings == nil do return
	i := max(min(index, len(ST_FLIP_RESOLUTION_NAMES) - 1), 0)
	settings.grid_height = ST_FLIP_RESOLUTION_GRID_HEIGHTS[i]
	settings.particle_count = ST_FLIP_RESOLUTION_PARTICLE_COUNTS[i]
}

st_flip_bind_product_instance :: proc(sim: ^ST_Flip_Simulation, instance: ^Feature_Instance) -> bool {
	if sim == nil || instance == nil do return false
	settings, settings_ok := feature_instance_settings(instance, ST_Flip_Settings)
	runtime, runtime_ok := feature_instance_runtime(instance, ST_Flip_Runtime_State)
	if !settings_ok || !runtime_ok do return false
	sim.settings = settings
	sim.runtime = runtime
	return true
}

st_flip_poly6 :: proc(r: f32) -> f32 {
	x := max(0, 1 - r * r)
	return x * x * x
}

// Equation 19. The support guard is explicit so out-of-slab samples cannot
// acquire weight from the even poly6 polynomial.
st_flip_temporal_weight :: proc(tau: f32) -> f32 {
	if tau > 0.5 || tau < -0.5 do return 0
	return f32(35.0 / 16.0) * st_flip_poly6(tau - 0.5)
}

st_flip_smoothstep :: proc(edge0, edge1, value: f32) -> f32 {
	if edge0 == edge1 do return value < edge0 ? 0 : 1
	t := max(min((value - edge0) / (edge1 - edge0), 1), 0)
	return t * t * (3 - 2 * t)
}

st_flip_adaptive_jitter_strength :: proc(speed, dt, cell_size, base_strength: f32) -> f32 {
	if cell_size <= 0 do return 0
	return max(min(base_strength, 1), 0) * st_flip_smoothstep(0, 1, math.abs(speed) * dt / cell_size)
}

st_flip_advance_time_sample :: proc(dt, residual, xi, gamma: f32) -> (actual_dt, next_residual: f32) {
	if dt <= 0 do return 0, residual
	jitter := max(min(gamma, 1), 0) * max(min(xi, 0.5), -0.5) * dt
	actual_dt = max(min(dt + residual + jitter, 2 * dt), 0)
	next_residual = dt + residual - actual_dt
	return
}

st_flip_phase_from_mass :: proc(mass, reference_mass, steepness: f32) -> f32 {
	denominator := max(reference_mass * max(steepness, 0.0001), 0.000001)
	return min(f32(math.sqrt(max(mass / denominator, 0))), 1)
}

st_flip_grid_width :: proc(grid_height: u32, viewport_width, viewport_height: f32) -> u32 {
	if viewport_height <= 0 do return grid_height
	aspect := max(viewport_width / viewport_height, 0.25)
	return max(u32(f32(grid_height) * aspect + 0.5), 1)
}
