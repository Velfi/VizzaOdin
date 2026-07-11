package game

import engine "../engine"
import vk "vendor:vulkan"

PRIMORDIAL_UPDATE_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/particle_update.slang"
PRIMORDIAL_DENSITY_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/density_compute.slang"
PRIMORDIAL_GRID_CLEAR_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/grid_clear.slang"
PRIMORDIAL_GRID_POPULATE_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/grid_populate.slang"
PRIMORDIAL_BACKGROUND_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/background_render.slang"
PRIMORDIAL_RENDER_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/particle_render.slang"
PRIMORDIAL_FADE_VERTEX_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/fade_vertex.slang"
PRIMORDIAL_FADE_FRAGMENT_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/fade_fragment.slang"
PRIMORDIAL_UPDATE_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/particle_update"
PRIMORDIAL_DENSITY_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/density_compute"
PRIMORDIAL_GRID_CLEAR_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/grid_clear"
PRIMORDIAL_GRID_POPULATE_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/grid_populate"
PRIMORDIAL_BACKGROUND_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/background_render_vertex"
PRIMORDIAL_BACKGROUND_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/background_render_fragment"
PRIMORDIAL_RENDER_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/particle_render_vertex"
PRIMORDIAL_RENDER_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/particle_render_fragment"
PRIMORDIAL_FADE_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/fade_vertex"
PRIMORDIAL_FADE_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/fade_fragment"
PRIMORDIAL_SOURCE_ENTRY :: "main"
PRIMORDIAL_VERTEX_SOURCE_ENTRY :: "vs_main"
PRIMORDIAL_FRAGMENT_SOURCE_ENTRY :: "fs_main"
PRIMORDIAL_ENTRY :: cstring("main")
PRIMORDIAL_VERTEX_ENTRY :: cstring("main")
PRIMORDIAL_FRAGMENT_ENTRY :: cstring("main")
PRIMORDIAL_WORKGROUP_SIZE :: u32(64)
PRIMORDIAL_GRID_AXIS :: u32(128)
PRIMORDIAL_GRID_CELL_COUNT :: PRIMORDIAL_GRID_AXIS * PRIMORDIAL_GRID_AXIS
PRIMORDIAL_RETIRED_TRACE_TARGET_CAP :: 4

Primordial_Particle :: struct #align(8) {
	position: [2]f32,
	previous_position: [2]f32,
	heading: f32,
	velocity: f32,
	density: f32,
	grabbed: u32,
}

Primordial_Sim_Params :: struct #align(16) {
	mouse_position: [2]f32,
	mouse_velocity: [2]f32,
	alpha: f32,
	beta: f32,
	velocity: f32,
	radius: f32,
	dt: f32,
	width: f32,
	height: f32,
	wrap_edges: u32,
	particle_count: u32,
	mouse_pressed: u32,
	mouse_mode: u32,
	cursor_size: f32,
	cursor_strength: f32,
	aspect_ratio: f32,
	grid_axis: u32,
	grid_cell_size: f32,
	collision_enabled: u32,
	collision_distance: f32,
	collision_relaxation: f32,
	collision_damping: f32,
}

Primordial_Density_Params :: struct #align(16) {
	particle_count: u32,
	density_radius: f32,
	coloring_mode: u32,
	grid_axis: u32,
	grid_cell_size: f32,
	_padding: [3]u32,
}

Primordial_Render_Params :: struct #align(16) {
	particle_size: f32,
	screen_width: f32,
	screen_height: f32,
	foreground_color_mode: u32,
	camera_position: [2]f32,
	camera_zoom: f32,
	tile_count: u32,
}

Primordial_Background_Params :: struct #align(16) {
	background_color: [4]f32,
}

Primordial_Camera :: Vectors_Camera_Uniform

Primordial_Fade_Params :: struct #align(16) {
	fade_amount: f32,
	_pad0: [3]f32,
}

Primordial_Trace_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	framebuffer: vk.Framebuffer,
	layout: vk.ImageLayout,
}

Primordial_Retired_Trace_Targets :: struct {
	images: [2]Primordial_Trace_Image,
	pending_frame_slots: u32,
}

Primordial_Gpu_State :: struct {
	update_shader: engine.Vk_Shader_Module,
	density_shader: engine.Vk_Shader_Module,
	grid_clear_shader: engine.Vk_Shader_Module,
	grid_populate_shader: engine.Vk_Shader_Module,
	background_vertex_shader: engine.Vk_Shader_Module,
	background_fragment_shader: engine.Vk_Shader_Module,
	render_vertex_shader: engine.Vk_Shader_Module,
	render_fragment_shader: engine.Vk_Shader_Module,
	fade_vertex_shader: engine.Vk_Shader_Module,
	fade_fragment_shader: engine.Vk_Shader_Module,
	update_pipeline: engine.Vk_Compute_Pipeline,
	density_pipeline: engine.Vk_Compute_Pipeline,
	grid_clear_pipeline: engine.Vk_Compute_Pipeline,
	grid_populate_pipeline: engine.Vk_Compute_Pipeline,
	background_pipeline: engine.Vk_Graphics_Pipeline,
	render_pipeline: engine.Vk_Graphics_Pipeline,
	trace_particle_pipeline: engine.Vk_Graphics_Pipeline,
	fade_pipeline: engine.Vk_Graphics_Pipeline,
	blit_pipeline: engine.Vk_Graphics_Pipeline,
	update_set_layout: vk.DescriptorSetLayout,
	density_set_layout: vk.DescriptorSetLayout,
	grid_clear_set_layout: vk.DescriptorSetLayout,
	grid_populate_set_layout: vk.DescriptorSetLayout,
	background_set_layout: vk.DescriptorSetLayout,
	render_set_layout: vk.DescriptorSetLayout,
	fade_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	update_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	density_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	grid_clear_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	grid_populate_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	background_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	render_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	fade_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	blit_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	particle_buffers: [2]engine.Vk_Buffer,
	grid_heads_buffer: engine.Vk_Buffer,
	grid_next_buffer: engine.Vk_Buffer,
	sim_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	density_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	background_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	render_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	fade_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	blit_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	camera_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	trace_render_pass: vk.RenderPass,
	trace_images: [2]Primordial_Trace_Image,
	retired_trace_targets: [PRIMORDIAL_RETIRED_TRACE_TARGET_CAP]Primordial_Retired_Trace_Targets,
	trace_sampler: vk.Sampler,
	trace_width: u32,
	trace_height: u32,
	trace_initialized: bool,
	trace_write_index: u32,
	state_index: u32,
	grid_state_index: u32,
	grid_state_valid: bool,
	particle_count: u32,
	initialized_seed: u32,
	initialized_position_generator: u32,
	ready: bool,
	present_tile_count: u32,
	present_camera_position: [2]f32,
	present_camera_zoom: f32,
	present_camera_valid: bool,
}
