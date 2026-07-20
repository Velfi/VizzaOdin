package render_vk

import engine "zelda_engine:engine"
import vk "vendor:vulkan"

PELLETS_RETIRED_TRAIL_TARGET_CAP :: 4

Pellets_Trail_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	layout: vk.ImageLayout,
}

Pellets_Retired_Trail_Targets :: struct {
	images: [2]Pellets_Trail_Image,
	pending_frame_slots: u32,
}

Pellets_Gpu_State :: struct {
	grid_clear_shader, grid_populate_shader, grid_prefix_shader, grid_prefix_blocks_shader, grid_prefix_add_shader, grid_scatter_shader, physics_shader: engine.Vk_Shader_Module,
	background_vertex_shader, background_fragment_shader: engine.Vk_Shader_Module,
	render_vertex_shader, render_fragment_shader: engine.Vk_Shader_Module,
	trail_fade_vertex_shader, trail_fade_fragment_shader: engine.Vk_Shader_Module,
	trail_blit_vertex_shader, trail_blit_fragment_shader: engine.Vk_Shader_Module,
	grid_clear_pipeline, grid_populate_pipeline, grid_prefix_pipeline, grid_prefix_blocks_pipeline, grid_prefix_add_pipeline, grid_scatter_pipeline, physics_pipeline: engine.Vk_Compute_Pipeline,
	background_pipeline, render_pipeline, trail_background_pipeline, trail_particle_pipeline: engine.Vk_Graphics_Pipeline,
	trail_fade_pipeline, trail_blit_pipeline: engine.Vk_Graphics_Pipeline,
	grid_clear_set_layout, grid_populate_set_layout, grid_prefix_set_layout, grid_scatter_set_layout, physics_set_layout: vk.DescriptorSetLayout,
	background_set_layout, render_set_layout, trail_fade_set_layout, trail_blit_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	grid_clear_sets, grid_populate_sets, grid_prefix_sets, grid_scatter_sets, physics_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	background_sets, render_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	trail_fade_sets, trail_blit_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	particle_buffer: engine.Vk_Buffer,
	physics_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	background_params_buffers, background_color_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	render_params_buffers, trail_fade_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	grid_buffer, grid_offsets_buffer, grid_cursors_buffer, grid_block_sums_buffer: engine.Vk_Buffer,
	grid_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	grid_counts_buffer, lut_buffer: engine.Vk_Buffer,
	trail_images: [2]Pellets_Trail_Image,
	retired_trail_targets: [PELLETS_RETIRED_TRAIL_TARGET_CAP]Pellets_Retired_Trail_Targets,
	trail_sampler: vk.Sampler,
	trail_width, trail_height: u32,
	trail_initialized: bool,
	trail_write_index, particle_count, grid_width, grid_height: u32,
	cell_size: f32,
	frame_index: u32,
	ready: bool,
	present_tile_count: u32,
	present_camera_position: [2]f32,
	present_camera_zoom: f32,
	present_camera_valid: bool,
}
