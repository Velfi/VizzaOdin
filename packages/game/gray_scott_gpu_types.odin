package game

import uifw "zelda_engine:ui"
GRAY_SCOTT_STEP_SHADER_SOURCE :: "assets/shaders/gray_scott_step.slang"
GRAY_SCOTT_PRESENT_SHADER_SOURCE :: "assets/shaders/gray_scott_present.slang"
GRAY_SCOTT_VERTEX_SHADER_SOURCE :: GRAY_SCOTT_PRESENT_SHADER_SOURCE
GRAY_SCOTT_STEP_FALLBACK_SPV :: "build/shaders/gray_scott_step"
GRAY_SCOTT_VERTEX_FALLBACK_SPV :: "build/shaders/gray_scott_present_vertex"
GRAY_SCOTT_PRESENT_FALLBACK_SPV :: "build/shaders/gray_scott_present_fragment"
GRAY_SCOTT_STEP_ENTRY :: "main"
GRAY_SCOTT_VERTEX_ENTRY :: "vertex_main"
GRAY_SCOTT_PRESENT_ENTRY :: "fragment_main"
GRAY_SCOTT_STEP_SPIRV_ENTRY :: "main"
GRAY_SCOTT_VERTEX_SPIRV_ENTRY :: "main"
GRAY_SCOTT_PRESENT_SPIRV_ENTRY :: "main"
GRAY_SCOTT_WORKGROUP_SIZE :: 8
GRAY_SCOTT_DEFAULT_ITERATIONS :: u32(1)
GRAY_SCOTT_MAX_STABLE_SUBSTEPS :: 128
GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS :: 132
GRAY_SCOTT_MODE_CLEAR :: u32(0)
GRAY_SCOTT_MODE_STEP :: u32(1)
GRAY_SCOTT_MODE_INITIAL_SEED :: u32(2)
GRAY_SCOTT_MODE_NOISE_SEED :: u32(3)
GRAY_SCOTT_MODE_PAINT :: u32(4)
GRAY_SCOTT_LUT_SIZE :: COLOR_SCHEME_U32_COUNT
GRAY_SCOTT_NUTRIENT_IMAGE_PATH_MAX :: 256

Gray_Scott_Params :: struct #align(16) {
	feed: f32,
	kill: f32,
	diffusion_a: f32,
	diffusion_b: f32,
	timestep: f32,
	width: u32,
	height: u32,
	mode: u32,
	seed: u32,
	frame_index: u32,
	mask_pattern: u32,
	mask_target: u32,
	mask_strength: f32,
	mask_mirror_horizontal: u32,
	mask_mirror_vertical: u32,
	mask_invert_tone: u32,
	max_timestep: f32,
	stability_factor: f32,
	enable_adaptive_timestep: u32,
	cursor_x: f32,
	cursor_y: f32,
	cursor_size: f32,
	cursor_strength: f32,
	mouse_button: u32,
	_pad0: u32,
	_pad1: u32,
	_pad2: u32,
	noise_kind: u32,
	noise_fractal_mode: u32,
	noise_seed: u32,
	noise_warp_mode: u32,
	noise_offset_x: f32,
	noise_offset_y: f32,
	noise_rotation: f32,
	noise_anchor_x: f32,
	noise_anchor_y: f32,
	noise_strength: f32,
	noise_amplitude: f32,
	noise_frequency: f32,
	noise_octaves: u32,
	noise_lacunarity: f32,
	noise_gain: f32,
	noise_warp_octaves: u32,
	noise_warp_amplitude: f32,
	noise_warp_frequency: f32,
	noise_gabor_iterations: u32,
	noise_gabor_velocity: f32,
	noise_gabor_band_width: f32,
	noise_gabor_band_softness: f32,
	noise_phasor_iterations: u32,
	noise_phasor_velocity: f32,
	noise_phasor_band_width: f32,
	noise_voronoi_output: u32,
	noise_voronoi_distance_mode: u32,
	noise_wave_velocity: f32,
	noise_wave_band_width: f32,
	noise_wave_band_softness: f32,
	seed_density: f32,
	seed_amplitude: f32,
}

Gray_Scott_Present_Params :: struct #align(16) {
	lut_reversed: u32,
	blur_enabled: u32,
	blur_radius: f32,
	blur_sigma: f32,
	width: u32,
	height: u32,
	viewport_width: u32,
	viewport_height: u32,
	camera_x: f32,
	camera_y: f32,
	camera_zoom: f32,
	view_mode: u32,
}

Gray_Scott_Camera :: struct #align(16) {
	transform_matrix: [16]f32,
	position: [2]f32,
	zoom: f32,
	aspect_ratio: f32,
}

Gray_Scott_Fullscreen_Vertex :: struct {
	pos: uifw.Vec2,
	color: uifw.Color,
	uv: uifw.Vec2,
	glyph: f32,
	effect: uifw.Color,
	material: uifw.Color,
}
