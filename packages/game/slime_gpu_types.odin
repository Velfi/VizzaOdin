package game

import "core:math"

SLIME_COMPUTE_SHADER_SOURCE :: "assets/shaders/simulations/slime_mold/shaders/compute.slang"
SLIME_GRADIENT_SHADER_SOURCE :: "assets/shaders/simulations/slime_mold/shaders/gradient.slang"
SLIME_DISPLAY_SHADER_SOURCE :: "assets/shaders/simulations/slime_mold/shaders/display.slang"
SLIME_PRESENT_SHADER_SOURCE :: "assets/shaders/simulations/voronoi_ca/shaders/infinite_render.slang"
SLIME_UPDATE_FALLBACK_SPV :: "build/shaders/simulations/slime_mold/shaders/compute_compute_update_agents"
SLIME_DECAY_FALLBACK_SPV :: "build/shaders/simulations/slime_mold/shaders/compute_compute_decay_trail"
SLIME_DIFFUSE_FALLBACK_SPV :: "build/shaders/simulations/slime_mold/shaders/compute_compute_diffuse_trail"
SLIME_UPDATE_SPEEDS_FALLBACK_SPV :: "build/shaders/simulations/slime_mold/shaders/compute_compute_update_agent_speeds"
SLIME_RESET_FALLBACK_SPV :: "build/shaders/simulations/slime_mold/shaders/compute_compute_reset_agents"
SLIME_GRADIENT_FALLBACK_SPV :: "build/shaders/simulations/slime_mold/shaders/gradient"
SLIME_DISPLAY_FALLBACK_SPV :: "build/shaders/simulations/slime_mold/shaders/display"
SLIME_PRESENT_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/infinite_render_vertex"
SLIME_PRESENT_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/infinite_render_fragment"
SLIME_SOURCE_ENTRY_UPDATE :: "update_agents"
SLIME_SOURCE_ENTRY_DECAY :: "decay_trail"
SLIME_SOURCE_ENTRY_DIFFUSE :: "diffuse_trail"
SLIME_SOURCE_ENTRY_UPDATE_SPEEDS :: "update_agent_speeds"
SLIME_SOURCE_ENTRY_RESET :: "reset_agents"
SLIME_SOURCE_ENTRY_GRADIENT :: "generate_mask"
SLIME_SOURCE_ENTRY_DISPLAY :: "main"
SLIME_PRESENT_VERTEX_SOURCE_ENTRY :: "vs_main"
SLIME_PRESENT_FRAGMENT_SOURCE_ENTRY :: "fs_main_texture"
SLIME_ENTRY_UPDATE :: cstring("main")
SLIME_ENTRY_DECAY :: cstring("main")
SLIME_ENTRY_DIFFUSE :: cstring("main")
SLIME_ENTRY_UPDATE_SPEEDS :: cstring("main")
SLIME_ENTRY_RESET :: cstring("main")
SLIME_ENTRY_GRADIENT :: cstring("main")
SLIME_ENTRY_DISPLAY :: cstring("main")
SLIME_PRESENT_VERTEX_ENTRY :: cstring("main")
SLIME_PRESENT_FRAGMENT_ENTRY :: cstring("main")
SLIME_AGENT_COUNT :: u32(10_000_000)
SLIME_MIN_AGENT_COUNT :: u32(1)
SLIME_MAX_AGENT_COUNT :: u32(100_000_000)
SLIME_PREVIEW_AGENT_COUNT :: u32(80_000)

Slime_Sim_Uniform :: struct #align(16) {
	width: u32,
	height: u32,
	decay_rate: f32,
	agent_jitter: f32,
	agent_speed_min: f32,
	agent_speed_max: f32,
	agent_turn_rate: f32,
	agent_sensor_angle: f32,
	agent_sensor_distance: f32,
	diffusion_rate: f32,
	pheromone_deposition_rate: f32,
	mask_pattern: u32,
	mask_target: u32,
	mask_strength: f32,
	mask_curve: f32,
	mask_mirror_horizontal: u32,
	mask_mirror_vertical: u32,
	mask_invert_tone: u32,
	random_seed: u32,
	position_generator: u32,
	delta_time: f32,
	agent_count: u32,
	webcam_live: u32,
	webcam_fit_mode: u32,
	webcam_width: u32,
	webcam_height: u32,
	isotropic_jitter: u32,
}

Slime_Cursor_Params :: struct #align(16) {
	is_active: u32,
	x: f32,
	y: f32,
	strength: f32,
	size: f32,
	_pad1: u32,
	_pad2: u32,
	_pad3: u32,
}

Slime_Render_Params :: Moire_Render_Params
Slime_Camera :: Vectors_Camera_Uniform

slime_camera_uniform_for_state :: proc(width, height: u32, control: ^Camera_Control_State = nil) -> Slime_Camera {
	data := camera_uniform_data(control, f32(width), f32(height))
	return {
		transform_matrix = data.transform_matrix,
		position = data.position,
		zoom = data.zoom,
		aspect_ratio = data.aspect_ratio,
	}
}
