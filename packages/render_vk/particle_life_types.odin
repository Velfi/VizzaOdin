package render_vk

import engine "zelda_engine:engine"
import vk "vendor:vulkan"

Particle_Life_Trail_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	layout: vk.ImageLayout,
}

Particle_Life_Retired_Trail_Targets :: struct {
	images: [2]Particle_Life_Trail_Image,
	pending_frame_slots: u32,
}

Particle_Life_Gpu_State :: struct {
	ready: bool,
	grid_clear_shader_module, grid_scatter_shader_module, grid_scatter_predicted_shader_module: engine.Vk_Shader_Module,
	grid_prefix_shader_module, grid_prefix_blocks_shader_module, grid_prefix_add_shader_module: engine.Vk_Shader_Module,
	grid_index_scatter_shader_module, compute_binned_shader_module: engine.Vk_Shader_Module,
	collision_solve_shader_module, collision_apply_shader_module, copy_scratch_shader_module: engine.Vk_Shader_Module,
	init_shader_module, vertex_shader_module, fragment_shader_module: engine.Vk_Shader_Module,
	fade_vertex_shader_module, fade_fragment_shader_module: engine.Vk_Shader_Module,
	force_randomize_shader_module, force_update_shader_module: engine.Vk_Shader_Module,
	analysis_clear_shader_module, analysis_scatter_shader_module, analysis_coherence_shader_module: engine.Vk_Shader_Module,
	analysis_tile_label_shader_module, analysis_tile_merge_shader_module, analysis_summarize_shader_module: engine.Vk_Shader_Module,
	background_vertex_shader_module, background_fragment_shader_module: engine.Vk_Shader_Module,
	post_vertex_shader_module, post_fragment_shader_module: engine.Vk_Shader_Module,
	infinite_present_vertex_shader_module, infinite_present_fragment_shader_module: engine.Vk_Shader_Module,
	grid_clear_shader_spirv_path, grid_scatter_shader_spirv_path, grid_scatter_predicted_shader_spirv_path: string,
	grid_prefix_shader_spirv_path, grid_prefix_blocks_shader_spirv_path, grid_prefix_add_shader_spirv_path: string,
	grid_index_scatter_shader_spirv_path, compute_binned_shader_spirv_path: string,
	collision_solve_shader_spirv_path, collision_apply_shader_spirv_path, copy_scratch_shader_spirv_path: string,
	init_shader_spirv_path, vertex_shader_spirv_path, fragment_shader_spirv_path: string,
	fade_vertex_shader_spirv_path, fade_fragment_shader_spirv_path: string,
	force_randomize_shader_spirv_path, force_update_shader_spirv_path: string,
	analysis_clear_shader_spirv_path, analysis_scatter_shader_spirv_path, analysis_coherence_shader_spirv_path: string,
	analysis_tile_label_shader_spirv_path, analysis_tile_merge_shader_spirv_path, analysis_summarize_shader_spirv_path: string,
	background_vertex_shader_spirv_path, background_fragment_shader_spirv_path: string,
	post_vertex_shader_spirv_path, post_fragment_shader_spirv_path: string,
	infinite_present_vertex_shader_spirv_path, infinite_present_fragment_shader_spirv_path: string,
	grid_clear_pipeline, grid_scatter_pipeline, grid_scatter_predicted_pipeline: engine.Vk_Compute_Pipeline,
	grid_prefix_pipeline, grid_prefix_blocks_pipeline, grid_prefix_add_pipeline: engine.Vk_Compute_Pipeline,
	grid_index_scatter_pipeline, compute_binned_pipeline: engine.Vk_Compute_Pipeline,
	collision_solve_pipeline, collision_apply_pipeline, copy_scratch_pipeline, init_pipeline: engine.Vk_Compute_Pipeline,
	render_pipeline, trail_particle_pipeline, fade_pipeline: engine.Vk_Graphics_Pipeline,
	force_randomize_pipeline, force_update_pipeline: engine.Vk_Compute_Pipeline,
	analysis_clear_pipeline, analysis_scatter_pipeline, analysis_coherence_pipeline: engine.Vk_Compute_Pipeline,
	analysis_tile_label_pipeline, analysis_tile_merge_pipeline, analysis_summarize_pipeline: engine.Vk_Compute_Pipeline,
	background_pipeline, post_pipeline, tiled_post_pipeline: engine.Vk_Graphics_Pipeline,
	sim_set_layout, init_set_layout, color_set_layout, view_set_layout, fade_set_layout: vk.DescriptorSetLayout,
	force_op_set_layout, analysis_set_layout, background_set_layout, post_set_layout: vk.DescriptorSetLayout,
	descriptor_pool, fade_descriptor_pool: vk.DescriptorPool,
	sim_sets, collision_sets, init_sets, color_sets, view_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	force_randomize_sets, force_update_sets, analysis_sets, background_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	post_sets, fade_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	particle_buffer, particle_scratch_buffer, force_cache_buffer: engine.Vk_Buffer,
	params_buffers, init_params_buffers, fade_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	force_randomize_params_buffers, force_update_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	grid_params_buffers, collision_grid_params_buffers, collision_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	grid_heads_buffer, particle_next_buffer, grid_offsets_buffer, grid_cursors_buffer: engine.Vk_Buffer,
	grid_block_sums_buffer, collision_correction_buffer: engine.Vk_Buffer,
	analysis_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	analysis_cells_buffer, analysis_coherence_buffer, analysis_labels_buffer: engine.Vk_Buffer,
	analysis_tile_components_buffer, analysis_parent_buffer: engine.Vk_Buffer,
	analysis_blob_summaries_buffer, analysis_blob_count_buffer: engine.Vk_Buffer,
	selected_blob_params_buffers, background_params_buffers, post_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	force_matrix_buffer: engine.Vk_Buffer,
	color_buffers, color_mode_buffers, camera_buffers, viewport_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	trail_sampler: vk.Sampler,
	trail_images: [2]Particle_Life_Trail_Image,
	retired_trail_targets: [PARTICLE_LIFE_RETIRED_TRAIL_TARGET_CAP]Particle_Life_Retired_Trail_Targets,
	trail_width, trail_height, trail_write_index: u32,
	trail_initialized: bool,
	width, height: i32,
	uploaded_particle_count, uploaded_species_count: u32,
	grid_width, grid_height, neighbor_radius_cells: u32,
	collision_grid_width, collision_grid_height, grid_cell_capacity: u32,
	analysis_grid_axis, analysis_tile_count: u32,
	active_frame_slot: int,
}

particle_life_gpu :: proc(sim: ^Particle_Life_Simulation) -> ^Particle_Life_Gpu_State {
	if sim == nil || sim.render_runtime == nil do return nil
	return cast(^Particle_Life_Gpu_State)sim.render_runtime
}
