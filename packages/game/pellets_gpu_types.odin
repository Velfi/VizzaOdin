package game

import engine "../engine"
import vk "vendor:vulkan"

PELLETS_GRID_CLEAR_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/grid_clear.slang"
PELLETS_GRID_POPULATE_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/grid_populate.slang"
PELLETS_PHYSICS_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/physics_compute.slang"
PELLETS_DENSITY_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/density_compute.slang"
PELLETS_BACKGROUND_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/background_render.slang"
PELLETS_RENDER_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/particle_render.slang"
PELLETS_TRAIL_FADE_VERTEX_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/trail_fade_vertex.slang"
PELLETS_TRAIL_FADE_FRAGMENT_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/trail_fade_fragment.slang"
PELLETS_TRAIL_BLIT_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/trail_blit.slang"
PELLETS_GRID_CLEAR_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/grid_clear"
PELLETS_GRID_POPULATE_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/grid_populate"
PELLETS_PHYSICS_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/physics_compute"
PELLETS_DENSITY_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/density_compute"
PELLETS_BACKGROUND_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/background_render_vertex"
PELLETS_BACKGROUND_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/background_render_fragment"
PELLETS_RENDER_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/particle_render_vertex"
PELLETS_RENDER_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/particle_render_fragment"
PELLETS_TRAIL_FADE_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/trail_fade_vertex"
PELLETS_TRAIL_FADE_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/trail_fade_fragment"
PELLETS_TRAIL_BLIT_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/trail_blit_vertex"
PELLETS_TRAIL_BLIT_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/trail_blit_fragment"
PELLETS_SOURCE_ENTRY :: "main"
PELLETS_VERTEX_SOURCE_ENTRY :: "vs_main"
PELLETS_FRAGMENT_SOURCE_ENTRY :: "fs_main"
PELLETS_ENTRY :: cstring("main")
PELLETS_VERTEX_ENTRY :: cstring("main")
PELLETS_FRAGMENT_ENTRY :: cstring("main")
PELLETS_WORKGROUP_SIZE :: u32(64)
PELLETS_GRID_CELL_CAPACITY :: 64
PELLETS_RETIRED_TRAIL_TARGET_CAP :: 4

Pellets_Particle :: struct #align(8) {
	position: [2]f32,
	velocity: [2]f32,
	mass: f32,
	radius: f32,
	clump_id: u32,
	density: f32,
	grabbed: u32,
	_pad0: u32,
	previous_position: [2]f32,
}

Pellets_Physics_Params :: struct #align(16) {
	mouse_position: [2]f32,
	mouse_velocity: [2]f32,
	particle_count: u32,
	gravitational_constant: f32,
	energy_damping: f32,
	collision_damping: f32,
	dt: f32,
	gravity_softening: f32,
	interaction_radius: f32,
	mouse_pressed: u32,
	mouse_mode: u32,
	cursor_size: f32,
	cursor_strength: f32,
	particle_size: f32,
	aspect_ratio: f32,
	density_damping_enabled: u32,
	overlap_resolution_strength: f32,
	frame_index: u32,
}

Pellets_Density_Params :: struct #align(16) {
	particle_count: u32,
	density_radius: f32,
	coloring_mode: u32,
	_padding: u32,
}

Pellets_Render_Params :: struct #align(16) {
	particle_size: f32,
	screen_width: f32,
	screen_height: f32,
	foreground_color_mode: u32,
}

Pellets_Background_Params :: struct #align(16) {
	background_color_mode: u32,
	_pad0: [3]u32,
}

Pellets_Grid_Params :: struct #align(16) {
	particle_count: u32,
	grid_width: u32,
	grid_height: u32,
	cell_size: f32,
	world_width: f32,
	world_height: f32,
	_pad1: u32,
	_pad2: u32,
}

Pellets_Grid_Cell :: struct #align(4) {
	particle_count: u32,
	particle_indices: [PELLETS_GRID_CELL_CAPACITY]u32,
}

Pellets_Fade_Params :: struct #align(16) {
	fade_amount: f32,
	_pad0: [3]f32,
}

Pellets_Trail_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	framebuffer: vk.Framebuffer,
	layout: vk.ImageLayout,
}

Pellets_Retired_Trail_Targets :: struct {
	images: [2]Pellets_Trail_Image,
	pending_frame_slots: u32,
}

Pellets_Gpu_State :: struct {
	grid_clear_shader: engine.Vk_Shader_Module,
	grid_populate_shader: engine.Vk_Shader_Module,
	physics_shader: engine.Vk_Shader_Module,
	density_shader: engine.Vk_Shader_Module,
	background_vertex_shader: engine.Vk_Shader_Module,
	background_fragment_shader: engine.Vk_Shader_Module,
	render_vertex_shader: engine.Vk_Shader_Module,
	render_fragment_shader: engine.Vk_Shader_Module,
	trail_fade_vertex_shader: engine.Vk_Shader_Module,
	trail_fade_fragment_shader: engine.Vk_Shader_Module,
	trail_blit_vertex_shader: engine.Vk_Shader_Module,
	trail_blit_fragment_shader: engine.Vk_Shader_Module,
	grid_clear_pipeline: engine.Vk_Compute_Pipeline,
	grid_populate_pipeline: engine.Vk_Compute_Pipeline,
	physics_pipeline: engine.Vk_Compute_Pipeline,
	density_pipeline: engine.Vk_Compute_Pipeline,
	background_pipeline: engine.Vk_Graphics_Pipeline,
	render_pipeline: engine.Vk_Graphics_Pipeline,
	trail_background_pipeline: engine.Vk_Graphics_Pipeline,
	trail_particle_pipeline: engine.Vk_Graphics_Pipeline,
	trail_fade_pipeline: engine.Vk_Graphics_Pipeline,
	trail_blit_pipeline: engine.Vk_Graphics_Pipeline,
	grid_clear_set_layout: vk.DescriptorSetLayout,
	grid_populate_set_layout: vk.DescriptorSetLayout,
	physics_set_layout: vk.DescriptorSetLayout,
	density_set_layout: vk.DescriptorSetLayout,
	background_set_layout: vk.DescriptorSetLayout,
	render_set_layout: vk.DescriptorSetLayout,
	trail_fade_set_layout: vk.DescriptorSetLayout,
	trail_blit_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	grid_clear_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	grid_populate_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	physics_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	density_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	background_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	render_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	trail_fade_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	trail_blit_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	particle_buffer: engine.Vk_Buffer,
	physics_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	density_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	background_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	background_color_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	render_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	trail_fade_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	grid_buffer: engine.Vk_Buffer,
	grid_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	grid_counts_buffer: engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	trail_render_pass: vk.RenderPass,
	trail_images: [2]Pellets_Trail_Image,
	retired_trail_targets: [PELLETS_RETIRED_TRAIL_TARGET_CAP]Pellets_Retired_Trail_Targets,
	trail_sampler: vk.Sampler,
	trail_width: u32,
	trail_height: u32,
	trail_initialized: bool,
	trail_write_index: u32,
	particle_count: u32,
	grid_width: u32,
	grid_height: u32,
	cell_size: f32,
	frame_index: u32,
	ready: bool,
}


