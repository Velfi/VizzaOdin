package game


FLOW_VECTOR_SHADER_SOURCE :: "assets/shaders/simulations/flow/shaders/flow_vector_compute.slang"
FLOW_PARTICLE_UPDATE_SHADER_SOURCE :: "assets/shaders/simulations/flow/shaders/particle_update.slang"
FLOW_TRAIL_DECAY_SHADER_SOURCE :: "assets/shaders/simulations/flow/shaders/trail_decay_diffusion.slang"
FLOW_SHAPE_DRAWING_SHADER_SOURCE :: "assets/shaders/simulations/flow/shaders/shape_drawing.slang"
FLOW_BACKGROUND_SHADER_SOURCE :: "assets/shaders/simulations/flow/shaders/background_render.slang"
FLOW_TRAIL_SHADER_SOURCE :: "assets/shaders/simulations/flow/shaders/trail_render.slang"
FLOW_PARTICLE_SHADER_SOURCE :: "assets/shaders/simulations/flow/shaders/particle_render.slang"
FLOW_VECTOR_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/flow_vector_compute"
FLOW_PARTICLE_UPDATE_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/particle_update"
FLOW_TRAIL_DECAY_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/trail_decay_diffusion"
FLOW_SHAPE_DRAWING_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/shape_drawing"
FLOW_BACKGROUND_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/background_render_vertex"
FLOW_BACKGROUND_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/background_render_fragment"
FLOW_TRAIL_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/trail_render_vertex"
FLOW_TRAIL_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/trail_render_fragment"
FLOW_PARTICLE_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/particle_render_vertex"
FLOW_PARTICLE_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/particle_render_fragment"
FLOW_SOURCE_ENTRY :: "main"
FLOW_VERTEX_SOURCE_ENTRY :: "vs_main"
FLOW_FRAGMENT_SOURCE_ENTRY :: "fs_main"
FLOW_ENTRY :: cstring("main")
FLOW_VERTEX_ENTRY :: cstring("main")
FLOW_FRAGMENT_ENTRY :: cstring("main")
FLOW_FIELD_RESOLUTION :: u32(128)

Flow_Particle :: struct #align(8) {
	position: [2]f32,
	age: f32,
	lut_index: u32,
	is_alive: u32,
	spawn_type: u32,
	_pad0: u32,
	_pad1: u32,
}

Flow_Vector :: struct #align(8) {
	position: [2]f32,
	direction: [2]f32,
}

Flow_Vector_Params :: struct #align(16) {
	grid_size: u32,
	vector_field_type: u32,
	noise_kind: u32,
	fractal_mode: u32,
	noise_seed: u32,
	offset_x: f32,
	offset_y: f32,
	rotation: f32,
	anchor_x: f32,
	anchor_y: f32,
	noise_strength: f32,
	amplitude: f32,
	frequency: f32,
	octaves: u32,
	lacunarity: f32,
	gain: f32,
	warp_mode: u32,
	warp_octaves: u32,
	warp_amplitude: f32,
	warp_frequency: f32,
	gabor_iterations: u32,
	gabor_velocity: f32,
	gabor_band_width: f32,
	gabor_band_softness: f32,
	phasor_iterations: u32,
	phasor_velocity: f32,
	phasor_band_width: f32,
	voronoi_output: u32,
	voronoi_distance_mode: u32,
	wave_velocity: f32,
	wave_band_width: f32,
	wave_band_softness: f32,
	time: f32,
	vector_magnitude: f32,
	_pad0: u32,
	image_fit_mode: u32,
	image_mirror_horizontal: u32,
	image_mirror_vertical: u32,
	image_invert_tone: u32,
	webcam_live: u32,
	target_width: u32,
	target_height: u32,
	_pad1: u32,
}

Flow_Spawn_Control :: struct #align(16) {
	autospawn_allowed: u32,
	brush_allowed: u32,
	autospawn_count: u32,
	brush_count: u32,
}

Flow_Sim_Params :: struct #align(16) {
	autospawn_pool_size: u32,
	autospawn_rate: u32,
	brush_pool_size: u32,
	brush_spawn_rate: u32,
	cursor_size: f32,
	cursor_x: f32,
	cursor_y: f32,
	display_mode: u32,
	flow_field_resolution: u32,
	height: f32,
	mouse_button_down: u32,
	noise_dt_multiplier: f32,
	noise_scale: f32,
	noise_seed: u32,
	noise_x: f32,
	noise_y: f32,
	particle_autospawn: u32,
	particle_lifetime: f32,
	particle_shape: u32,
	particle_size: u32,
	particle_speed: f32,
	screen_height: u32,
	screen_width: u32,
	time: f32,
	total_pool_size: u32,
	trail_decay_rate: f32,
	trail_deposition_rate: f32,
	trail_diffusion_rate: f32,
	trail_map_height: u32,
	trail_map_width: u32,
	trail_wash_out_rate: f32,
	vector_magnitude: f32,
	width: f32,
	delta_time: f32,
	emitter_mode: u32,
	emitter_radius: f32,
	boundary_mode: u32,
	trail_style: u32,
	field_animation_speed: f32,
	field_animation_enabled: u32,
	_padding_1: u32,
}

Flow_Camera :: Vectors_Camera_Uniform

Flow_Shape_Params :: struct #align(16) {
	center_x: f32,
	center_y: f32,
	size: f32,
	shape_type: u32,
	color: [4]f32,
	intensity: f32,
	antialiasing_width: f32,
	rotation: f32,
	aspect_ratio: f32,
	trail_map_width: u32,
	trail_map_height: u32,
	_padding_0: u32,
	_padding_1: u32,
}

flow_background_color :: proc(settings: ^Flow_Settings) -> [4]f32 {
	#partial switch settings.background_color_mode {
	case .Black:
		return {0, 0, 0, 1}
	case .White:
		return {1, 1, 1, 1}
	case .Gray18:
		return {0.18, 0.18, 0.18, 1}
	case .Color_Scheme:
		scheme := color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
		return color_scheme_color_at(scheme, COLOR_SCHEME_SIZE - 1)
	case:
		return {0, 0, 0, 1}
	}
}

flow_mouse_button_down_from_cursor :: proc(sim: ^Remaining_Sim_State) -> u32 {
	if sim.cursor_active == 0 {
		return 0
	}
	return sim.cursor_mode
}
