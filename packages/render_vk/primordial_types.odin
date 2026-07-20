package render_vk

import engine "zelda_engine:engine"
import vk "vendor:vulkan"

PRIMORDIAL_RETIRED_TRACE_TARGET_CAP :: 4

Primordial_Trace_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	layout: vk.ImageLayout,
}

Primordial_Retired_Trace_Targets :: struct {
	images: [2]Primordial_Trace_Image,
	pending_frame_slots: u32,
}

Primordial_Gpu_State :: struct {
	update_shader, density_shader, grid_clear_shader, grid_populate_shader: engine.Vk_Shader_Module,
	background_vertex_shader, background_fragment_shader: engine.Vk_Shader_Module,
	render_vertex_shader, render_fragment_shader, fade_vertex_shader, fade_fragment_shader: engine.Vk_Shader_Module,
	update_pipeline, density_pipeline, grid_clear_pipeline, grid_populate_pipeline: engine.Vk_Compute_Pipeline,
	background_pipeline, render_pipeline, trace_particle_pipeline, fade_pipeline, blit_pipeline: engine.Vk_Graphics_Pipeline,
	update_set_layout, density_set_layout, grid_clear_set_layout, grid_populate_set_layout: vk.DescriptorSetLayout,
	background_set_layout, render_set_layout, fade_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	update_sets, density_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	grid_clear_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	grid_populate_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	background_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	render_sets, fade_sets, blit_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	particle_buffers: [2]engine.Vk_Buffer,
	grid_heads_buffer, grid_next_buffer: engine.Vk_Buffer,
	sim_params_buffers, density_params_buffers, background_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	render_params_buffers, fade_params_buffers, blit_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	camera_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	trace_images: [2]Primordial_Trace_Image,
	retired_trace_targets: [PRIMORDIAL_RETIRED_TRACE_TARGET_CAP]Primordial_Retired_Trace_Targets,
	trace_sampler: vk.Sampler,
	trace_width, trace_height: u32,
	trace_initialized: bool,
	trace_write_index, state_index, grid_state_index: u32,
	grid_state_valid: bool,
	particle_count, initialized_seed, initialized_position_generator: u32,
	ready: bool,
	present_tile_count: u32,
	present_camera_position: [2]f32,
	present_camera_zoom: f32,
	present_camera_valid: bool,
}
