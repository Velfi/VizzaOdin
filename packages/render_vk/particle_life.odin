package render_vk

import engine "../engine"
import uifw "../ui"

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import vk "vendor:vulkan"

particle_life_ensure_gpu_paths :: proc(sim: ^Particle_Life_Simulation) -> bool {
	grid_clear_path := engine.shader_spirv_path(PARTICLE_LIFE_GRID_CLEAR_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_GRID_CLEAR_FALLBACK_SPV + ".spv")
	grid_scatter_path := engine.shader_spirv_path(PARTICLE_LIFE_GRID_SCATTER_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_GRID_SCATTER_FALLBACK_SPV + ".spv")
	grid_scatter_predicted_path := engine.shader_spirv_path(PARTICLE_LIFE_GRID_SCATTER_PREDICTED_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_GRID_SCATTER_PREDICTED_FALLBACK_SPV + ".spv")
	compute_binned_path := engine.shader_spirv_path(PARTICLE_LIFE_COMPUTE_BINNED_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_COMPUTE_BINNED_FALLBACK_SPV + ".spv")
	collision_solve_path := engine.shader_spirv_path(PARTICLE_LIFE_COLLISION_SOLVE_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_COLLISION_SOLVE_FALLBACK_SPV + ".spv")
	collision_apply_path := engine.shader_spirv_path(PARTICLE_LIFE_COLLISION_APPLY_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_COLLISION_APPLY_FALLBACK_SPV + ".spv")
	copy_scratch_path := engine.shader_spirv_path(PARTICLE_LIFE_COPY_SCRATCH_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_COPY_SCRATCH_FALLBACK_SPV + ".spv")
	init_path := engine.shader_spirv_path(PARTICLE_LIFE_INIT_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_INIT_FALLBACK_SPV + ".spv")
	vertex_path := engine.shader_spirv_path(PARTICLE_LIFE_VERTEX_SHADER_SOURCE, .Vertex, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_VERTEX_FALLBACK_SPV + ".spv")
	fragment_path := engine.shader_spirv_path(PARTICLE_LIFE_FRAGMENT_SHADER_SOURCE, .Fragment, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_FRAGMENT_FALLBACK_SPV + ".spv")
	fade_vertex_path := engine.shader_spirv_path(PARTICLE_LIFE_FADE_VERTEX_SHADER_SOURCE, .Vertex, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_FADE_VERTEX_FALLBACK_SPV + ".spv")
	fade_fragment_path := engine.shader_spirv_path(PARTICLE_LIFE_FADE_FRAGMENT_SHADER_SOURCE, .Fragment, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_FADE_FRAGMENT_FALLBACK_SPV + ".spv")
	force_randomize_path := engine.shader_spirv_path(PARTICLE_LIFE_FORCE_RANDOMIZE_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_FORCE_RANDOMIZE_FALLBACK_SPV + ".spv")
	force_update_path := engine.shader_spirv_path(PARTICLE_LIFE_FORCE_UPDATE_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_FORCE_UPDATE_FALLBACK_SPV + ".spv")
	analysis_clear_path := engine.shader_spirv_path(PARTICLE_LIFE_ANALYSIS_CLEAR_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_ANALYSIS_CLEAR_FALLBACK_SPV + ".spv")
	analysis_scatter_path := engine.shader_spirv_path(PARTICLE_LIFE_ANALYSIS_SCATTER_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_ANALYSIS_SCATTER_FALLBACK_SPV + ".spv")
	analysis_coherence_path := engine.shader_spirv_path(PARTICLE_LIFE_ANALYSIS_COHERENCE_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_ANALYSIS_COHERENCE_FALLBACK_SPV + ".spv")
	analysis_tile_label_path := engine.shader_spirv_path(PARTICLE_LIFE_ANALYSIS_TILE_LABEL_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_ANALYSIS_TILE_LABEL_FALLBACK_SPV + ".spv")
	analysis_tile_merge_path := engine.shader_spirv_path(PARTICLE_LIFE_ANALYSIS_TILE_MERGE_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_ANALYSIS_TILE_MERGE_FALLBACK_SPV + ".spv")
	analysis_summarize_path := engine.shader_spirv_path(PARTICLE_LIFE_ANALYSIS_SUMMARIZE_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_ANALYSIS_SUMMARIZE_FALLBACK_SPV + ".spv")
	background_vertex_path := engine.shader_spirv_path(PARTICLE_LIFE_BACKGROUND_SHADER_SOURCE, .Vertex, PARTICLE_LIFE_BACKGROUND_VERTEX_ENTRY, PARTICLE_LIFE_BACKGROUND_VERTEX_FALLBACK_SPV + ".spv")
	background_fragment_path := engine.shader_spirv_path(PARTICLE_LIFE_BACKGROUND_SHADER_SOURCE, .Fragment, PARTICLE_LIFE_BACKGROUND_FRAGMENT_ENTRY, PARTICLE_LIFE_BACKGROUND_FRAGMENT_FALLBACK_SPV + ".spv")
	post_vertex_path := engine.shader_spirv_path(PARTICLE_LIFE_POST_SHADER_SOURCE, .Vertex, PARTICLE_LIFE_POST_VERTEX_ENTRY, PARTICLE_LIFE_POST_VERTEX_FALLBACK_SPV + ".spv")
	post_fragment_path := engine.shader_spirv_path(PARTICLE_LIFE_POST_SHADER_SOURCE, .Fragment, PARTICLE_LIFE_POST_FRAGMENT_ENTRY, PARTICLE_LIFE_POST_FRAGMENT_FALLBACK_SPV + ".spv")
	infinite_present_vertex_path := engine.shader_spirv_path(PARTICLE_LIFE_INFINITE_PRESENT_VERTEX_SHADER_SOURCE, .Vertex, PARTICLE_LIFE_INFINITE_PRESENT_VERTEX_ENTRY, PARTICLE_LIFE_INFINITE_PRESENT_VERTEX_FALLBACK_SPV + ".spv")
	infinite_present_fragment_path := engine.shader_spirv_path(PARTICLE_LIFE_INFINITE_PRESENT_FRAGMENT_SHADER_SOURCE, .Fragment, PARTICLE_LIFE_INFINITE_PRESENT_FRAGMENT_ENTRY, PARTICLE_LIFE_INFINITE_PRESENT_FRAGMENT_FALLBACK_SPV + ".spv")
	if len(grid_clear_path) == 0 || len(grid_scatter_path) == 0 || len(grid_scatter_predicted_path) == 0 || len(compute_binned_path) == 0 || len(collision_solve_path) == 0 || len(collision_apply_path) == 0 || len(copy_scratch_path) == 0 || len(init_path) == 0 || len(vertex_path) == 0 || len(fragment_path) == 0 || len(fade_vertex_path) == 0 || len(fade_fragment_path) == 0 || len(force_randomize_path) == 0 || len(force_update_path) == 0 || len(analysis_clear_path) == 0 || len(analysis_scatter_path) == 0 || len(analysis_coherence_path) == 0 || len(analysis_tile_label_path) == 0 || len(analysis_tile_merge_path) == 0 || len(analysis_summarize_path) == 0 || len(background_vertex_path) == 0 || len(background_fragment_path) == 0 || len(post_vertex_path) == 0 || len(post_fragment_path) == 0 || len(infinite_present_vertex_path) == 0 || len(infinite_present_fragment_path) == 0 {
		return false
	}
	if !os.exists(grid_clear_path) || !os.exists(grid_scatter_path) || !os.exists(grid_scatter_predicted_path) || !os.exists(compute_binned_path) || !os.exists(collision_solve_path) || !os.exists(collision_apply_path) || !os.exists(copy_scratch_path) || !os.exists(init_path) || !os.exists(vertex_path) || !os.exists(fragment_path) || !os.exists(fade_vertex_path) || !os.exists(fade_fragment_path) || !os.exists(force_randomize_path) || !os.exists(force_update_path) || !os.exists(analysis_clear_path) || !os.exists(analysis_scatter_path) || !os.exists(analysis_coherence_path) || !os.exists(analysis_tile_label_path) || !os.exists(analysis_tile_merge_path) || !os.exists(analysis_summarize_path) || !os.exists(background_vertex_path) || !os.exists(background_fragment_path) || !os.exists(post_vertex_path) || !os.exists(post_fragment_path) || !os.exists(infinite_present_vertex_path) || !os.exists(infinite_present_fragment_path) {
		return false
	}
	sim.gpu.grid_clear_shader_spirv_path = grid_clear_path
	sim.gpu.grid_scatter_shader_spirv_path = grid_scatter_path
	sim.gpu.grid_scatter_predicted_shader_spirv_path = grid_scatter_predicted_path
	sim.gpu.compute_binned_shader_spirv_path = compute_binned_path
	sim.gpu.collision_solve_shader_spirv_path = collision_solve_path
	sim.gpu.collision_apply_shader_spirv_path = collision_apply_path
	sim.gpu.copy_scratch_shader_spirv_path = copy_scratch_path
	sim.gpu.init_shader_spirv_path = init_path
	sim.gpu.vertex_shader_spirv_path = vertex_path
	sim.gpu.fragment_shader_spirv_path = fragment_path
	sim.gpu.fade_vertex_shader_spirv_path = fade_vertex_path
	sim.gpu.fade_fragment_shader_spirv_path = fade_fragment_path
	sim.gpu.force_randomize_shader_spirv_path = force_randomize_path
	sim.gpu.force_update_shader_spirv_path = force_update_path
	sim.gpu.analysis_clear_shader_spirv_path = analysis_clear_path
	sim.gpu.analysis_scatter_shader_spirv_path = analysis_scatter_path
	sim.gpu.analysis_coherence_shader_spirv_path = analysis_coherence_path
	sim.gpu.analysis_tile_label_shader_spirv_path = analysis_tile_label_path
	sim.gpu.analysis_tile_merge_shader_spirv_path = analysis_tile_merge_path
	sim.gpu.analysis_summarize_shader_spirv_path = analysis_summarize_path
	sim.gpu.background_vertex_shader_spirv_path = background_vertex_path
	sim.gpu.background_fragment_shader_spirv_path = background_fragment_path
	sim.gpu.post_vertex_shader_spirv_path = post_vertex_path
	sim.gpu.post_fragment_shader_spirv_path = post_fragment_path
	sim.gpu.infinite_present_vertex_shader_spirv_path = infinite_present_vertex_path
	sim.gpu.infinite_present_fragment_shader_spirv_path = infinite_present_fragment_path
	return true
}

particle_life_ensure_gpu_runtime :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if sim.gpu.ready {
		return true
	}
	if sim.gpu.grid_clear_shader_module.handle != 0 || sim.gpu.grid_scatter_shader_module.handle != 0 || sim.gpu.grid_scatter_predicted_shader_module.handle != 0 || sim.gpu.compute_binned_shader_module.handle != 0 || sim.gpu.collision_solve_shader_module.handle != 0 || sim.gpu.collision_apply_shader_module.handle != 0 || sim.gpu.copy_scratch_shader_module.handle != 0 || sim.gpu.init_shader_module.handle != 0 || sim.gpu.vertex_shader_module.handle != 0 || sim.gpu.fragment_shader_module.handle != 0 || sim.gpu.fade_vertex_shader_module.handle != 0 || sim.gpu.fade_fragment_shader_module.handle != 0 || sim.gpu.force_randomize_shader_module.handle != 0 || sim.gpu.force_update_shader_module.handle != 0 || sim.gpu.analysis_clear_shader_module.handle != 0 || sim.gpu.analysis_scatter_shader_module.handle != 0 || sim.gpu.analysis_coherence_shader_module.handle != 0 || sim.gpu.analysis_tile_label_shader_module.handle != 0 || sim.gpu.analysis_tile_merge_shader_module.handle != 0 || sim.gpu.analysis_summarize_shader_module.handle != 0 || sim.gpu.background_vertex_shader_module.handle != 0 || sim.gpu.background_fragment_shader_module.handle != 0 || sim.gpu.post_vertex_shader_module.handle != 0 || sim.gpu.post_fragment_shader_module.handle != 0 || sim.gpu.infinite_present_vertex_shader_module.handle != 0 || sim.gpu.infinite_present_fragment_shader_module.handle != 0 {
		_ = vk.DeviceWaitIdle(vk_ctx.device)
		particle_life_destroy(sim, vk_ctx)
	}
	if !particle_life_ensure_gpu_paths(sim) {
		engine.log_error("particle_life_ensure_gpu_runtime: shader paths unavailable")
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.grid_clear_shader_spirv_path, &sim.gpu.grid_clear_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: grid clear shader load failed path=", sim.gpu.grid_clear_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.grid_scatter_shader_spirv_path, &sim.gpu.grid_scatter_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: grid scatter shader load failed path=", sim.gpu.grid_scatter_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.grid_scatter_predicted_shader_spirv_path, &sim.gpu.grid_scatter_predicted_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: predicted grid scatter shader load failed path=", sim.gpu.grid_scatter_predicted_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.compute_binned_shader_spirv_path, &sim.gpu.compute_binned_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: compute binned shader load failed path=", sim.gpu.compute_binned_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.collision_solve_shader_spirv_path, &sim.gpu.collision_solve_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: collision solve shader load failed path=", sim.gpu.collision_solve_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.collision_apply_shader_spirv_path, &sim.gpu.collision_apply_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: collision apply shader load failed path=", sim.gpu.collision_apply_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.copy_scratch_shader_spirv_path, &sim.gpu.copy_scratch_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: copy scratch shader load failed path=", sim.gpu.copy_scratch_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.init_shader_spirv_path, &sim.gpu.init_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: init shader load failed path=", sim.gpu.init_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.vertex_shader_spirv_path, &sim.gpu.vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: vertex shader load failed path=", sim.gpu.vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.fragment_shader_spirv_path, &sim.gpu.fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: fragment shader load failed path=", sim.gpu.fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.fade_vertex_shader_spirv_path, &sim.gpu.fade_vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: fade vertex shader load failed path=", sim.gpu.fade_vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.fade_fragment_shader_spirv_path, &sim.gpu.fade_fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: fade fragment shader load failed path=", sim.gpu.fade_fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.force_randomize_shader_spirv_path, &sim.gpu.force_randomize_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: force randomize shader load failed path=", sim.gpu.force_randomize_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.force_update_shader_spirv_path, &sim.gpu.force_update_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: force update shader load failed path=", sim.gpu.force_update_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.analysis_clear_shader_spirv_path, &sim.gpu.analysis_clear_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis clear shader load failed path=", sim.gpu.analysis_clear_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.analysis_scatter_shader_spirv_path, &sim.gpu.analysis_scatter_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis scatter shader load failed path=", sim.gpu.analysis_scatter_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.analysis_coherence_shader_spirv_path, &sim.gpu.analysis_coherence_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis coherence shader load failed path=", sim.gpu.analysis_coherence_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.analysis_tile_label_shader_spirv_path, &sim.gpu.analysis_tile_label_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis tile label shader load failed path=", sim.gpu.analysis_tile_label_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.analysis_tile_merge_shader_spirv_path, &sim.gpu.analysis_tile_merge_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis tile merge shader load failed path=", sim.gpu.analysis_tile_merge_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.analysis_summarize_shader_spirv_path, &sim.gpu.analysis_summarize_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis summarize shader load failed path=", sim.gpu.analysis_summarize_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.background_vertex_shader_spirv_path, &sim.gpu.background_vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: background vertex shader load failed path=", sim.gpu.background_vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.background_fragment_shader_spirv_path, &sim.gpu.background_fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: background fragment shader load failed path=", sim.gpu.background_fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.post_vertex_shader_spirv_path, &sim.gpu.post_vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: post vertex shader load failed path=", sim.gpu.post_vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.post_fragment_shader_spirv_path, &sim.gpu.post_fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: post fragment shader load failed path=", sim.gpu.post_fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.infinite_present_vertex_shader_spirv_path, &sim.gpu.infinite_present_vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: infinite present vertex shader load failed path=", sim.gpu.infinite_present_vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.infinite_present_fragment_shader_spirv_path, &sim.gpu.infinite_present_fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: infinite present fragment shader load failed path=", sim.gpu.infinite_present_fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !particle_life_create_resources(sim, vk_ctx) {
		engine.log_error("particle_life_ensure_gpu_runtime: resource creation failed")
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	sim.gpu.ready = true
	return true
}

particle_life_create_resources :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	particle_count := particle_life_target_particle_count(sim.settings)
	species_count := particle_life_target_species_count(sim.settings)
	restore_particles := !sim.runtime.needs_reset && len(sim.runtime.preserved_particles) == int(particle_count)
	world_size := particle_life_world_size(sim)
	grid_width, grid_height := particle_life_target_grid_dimensions(sim.settings, world_size)
	grid_cells := grid_width * grid_height
	neighbor_radius_cells := particle_life_target_neighbor_radius_cells(sim.settings, grid_width, grid_height, world_size)
	analysis_axis := particle_life_target_analysis_grid_axis(sim.settings)
	analysis_cells := analysis_axis * analysis_axis
	analysis_tile_count := particle_life_analysis_tile_count_for_axis(analysis_axis)
	analysis_tile_components := analysis_tile_count * analysis_tile_count * PARTICLE_LIFE_ANALYSIS_TILE_SIZE * PARTICLE_LIFE_ANALYSIS_TILE_SIZE
	particle_size := vk.DeviceSize(size_of(Particle_Life_Particle) * int(particle_count))
	if !engine.vk_create_host_buffer(vk_ctx, particle_size, {.STORAGE_BUFFER, .VERTEX_BUFFER, .TRANSFER_DST}, &sim.gpu.particle_buffer) {
		engine.log_error("particle_life_create_resources: particle buffer failed bytes=", particle_size)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, particle_size, {.STORAGE_BUFFER, .TRANSFER_SRC, .TRANSFER_DST}, &sim.gpu.particle_scratch_buffer) {
		engine.log_error("particle_life_create_resources: particle scratch buffer failed bytes=", particle_size)
		return false
	}
	params_size := vk.DeviceSize(size_of(Particle_Life_Params))
	init_params_size := vk.DeviceSize(size_of(Particle_Life_Init_Params))
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, params_size, {.UNIFORM_BUFFER}, &sim.gpu.params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, init_params_size, {.UNIFORM_BUFFER}, &sim.gpu.init_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Fade_Params)), {.UNIFORM_BUFFER}, &sim.gpu.fade_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Force_Randomize_Params)), {.UNIFORM_BUFFER}, &sim.gpu.force_randomize_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Force_Update_Params)), {.UNIFORM_BUFFER}, &sim.gpu.force_update_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Grid_Params)), {.UNIFORM_BUFFER}, &sim.gpu.grid_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Collision_Params)), {.UNIFORM_BUFFER}, &sim.gpu.collision_params_buffers[frame_slot]) {
			return false
		}
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(grid_cells)), {.STORAGE_BUFFER}, &sim.gpu.grid_heads_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(particle_count)), {.STORAGE_BUFFER}, &sim.gpu.particle_next_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of([2]f32) * int(particle_count)), {.STORAGE_BUFFER}, &sim.gpu.collision_correction_buffer) {
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Analysis_Params)), {.UNIFORM_BUFFER}, &sim.gpu.analysis_params_buffers[frame_slot]) {
			return false
		}
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Analysis_Gpu_Cell) * int(analysis_cells)), {.STORAGE_BUFFER}, &sim.gpu.analysis_cells_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(f32) * int(analysis_cells)), {.STORAGE_BUFFER}, &sim.gpu.analysis_coherence_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(analysis_cells)), {.STORAGE_BUFFER}, &sim.gpu.analysis_labels_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(analysis_tile_components)), {.STORAGE_BUFFER}, &sim.gpu.analysis_tile_components_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(analysis_cells)), {.STORAGE_BUFFER}, &sim.gpu.analysis_parent_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Blob_Accumulator) * PARTICLE_LIFE_ANALYSIS_MAX_BLOBS), {.STORAGE_BUFFER}, &sim.gpu.analysis_blob_summaries_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32)), {.STORAGE_BUFFER}, &sim.gpu.analysis_blob_count_buffer) {
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Selected_Blob_Params)), {.UNIFORM_BUFFER}, &sim.gpu.selected_blob_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Background_Params)), {.UNIFORM_BUFFER}, &sim.gpu.background_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Post_Params)), {.UNIFORM_BUFFER}, &sim.gpu.post_params_buffers[frame_slot]) {
			return false
		}
	}
	force_size := vk.DeviceSize(size_of(f32) * int(species_count * species_count))
	if !engine.vk_create_host_buffer(vk_ctx, force_size, {.STORAGE_BUFFER}, &sim.gpu.force_matrix_buffer) {
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Species_Colors)), {.UNIFORM_BUFFER}, &sim.gpu.color_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Color_Mode_Params)), {.UNIFORM_BUFFER}, &sim.gpu.color_mode_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Camera)), {.UNIFORM_BUFFER}, &sim.gpu.camera_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Viewport)), {.UNIFORM_BUFFER}, &sim.gpu.viewport_buffers[frame_slot]) {
			return false
		}
	}
	sim.gpu.uploaded_particle_count = particle_count
	sim.gpu.uploaded_species_count = species_count
	sim.gpu.grid_width = grid_width
	sim.gpu.grid_height = grid_height
	sim.gpu.neighbor_radius_cells = neighbor_radius_cells
	sim.gpu.analysis_grid_axis = analysis_axis
	sim.gpu.analysis_tile_count = analysis_tile_count
	particle_life_upload_force_matrix(sim)
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		sim.gpu.active_frame_slot = frame_slot
		particle_life_upload_static_uniforms(sim)
		particle_life_write_init_uniforms(sim)
		particle_life_write_frame_uniforms(sim, 0)
		particle_life_write_grid_uniforms(sim)
		particle_life_write_collision_uniforms(sim)
		particle_life_write_analysis_uniforms(sim)
		particle_life_write_fade_uniforms(sim)
		particle_life_write_background_uniforms(sim)
		particle_life_write_post_uniforms(sim)
	}
	if restore_particles && sim.gpu.particle_buffer.mapped != nil {
		particles := (cast([^]Particle_Life_Particle)sim.gpu.particle_buffer.mapped)[:particle_count]
		copy(particles, sim.runtime.preserved_particles)
		sim.runtime.needs_reset = false
	} else {
		sim.runtime.needs_reset = true
	}
	particle_life_clear_preserved_particles(sim)

	if !particle_life_create_descriptor_state(sim, vk_ctx) {
		engine.log_error("particle_life_create_resources: descriptor state failed")
		return false
	}
	if !particle_life_create_init_pipeline(sim, vk_ctx) {
		engine.log_error("particle_life_create_resources: init pipeline failed")
		return false
	}
	if !particle_life_create_compute_pipeline(sim, vk_ctx) {
		engine.log_error("particle_life_create_resources: compute pipeline failed")
		return false
	}
	if !particle_life_create_force_pipelines(sim, vk_ctx) {
		engine.log_error("particle_life_create_resources: force pipelines failed")
		return false
	}
	if !particle_life_create_render_pipeline(sim, vk_ctx) {
		engine.log_error("particle_life_create_resources: render pipeline failed")
		return false
	}
	if !particle_life_create_trail_resources(sim, vk_ctx) {
		engine.log_error("particle_life_create_resources: trail resources failed")
		return false
	}
	return true
}

particle_life_create_descriptor_state :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	sim_bindings := [9]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE, .VERTEX}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE, .VERTEX}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 5, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 6, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 7, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 8, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	sim_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(sim_bindings)),
		pBindings = raw_data(sim_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &sim_layout_info, nil, &sim.gpu.sim_set_layout) != .SUCCESS {
		return false
	}

	init_bindings := [2]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	init_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(init_bindings)),
		pBindings = raw_data(init_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &init_layout_info, nil, &sim.gpu.init_set_layout) != .SUCCESS {
		return false
	}

	color_bindings := [2]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	color_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(color_bindings)),
		pBindings = raw_data(color_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &color_layout_info, nil, &sim.gpu.color_set_layout) != .SUCCESS {
		return false
	}

	view_bindings := [2]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}},
	}
	view_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(view_bindings)),
		pBindings = raw_data(view_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &view_layout_info, nil, &sim.gpu.view_set_layout) != .SUCCESS {
		return false
	}

	force_op_bindings := [2]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	force_op_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(force_op_bindings)),
		pBindings = raw_data(force_op_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &force_op_layout_info, nil, &sim.gpu.force_op_set_layout) != .SUCCESS {
		return false
	}

	analysis_bindings := [10]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 5, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 6, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 7, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 8, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 9, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	analysis_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(analysis_bindings)),
		pBindings = raw_data(analysis_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &analysis_layout_info, nil, &sim.gpu.analysis_set_layout) != .SUCCESS {
		return false
	}

	pool_sizes := [2]vk.DescriptorPoolSize {
		{type = .STORAGE_BUFFER, descriptorCount = 20 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .UNIFORM_BUFFER, descriptorCount = 12 * engine.MAX_FRAMES_IN_FLIGHT},
	}
	pool_info := vk.DescriptorPoolCreateInfo {
		sType = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = u32(len(pool_sizes)),
		pPoolSizes = raw_data(pool_sizes[:]),
		maxSets = 7 * engine.MAX_FRAMES_IN_FLIGHT,
	}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &sim.gpu.descriptor_pool) != .SUCCESS {
		return false
	}

	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		layouts := [7]vk.DescriptorSetLayout{sim.gpu.sim_set_layout, sim.gpu.init_set_layout, sim.gpu.color_set_layout, sim.gpu.view_set_layout, sim.gpu.force_op_set_layout, sim.gpu.force_op_set_layout, sim.gpu.analysis_set_layout}
		sets := [7]vk.DescriptorSet{}
		alloc := vk.DescriptorSetAllocateInfo {
			sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
			descriptorPool = sim.gpu.descriptor_pool,
			descriptorSetCount = u32(len(layouts)),
			pSetLayouts = raw_data(layouts[:]),
		}
		if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(sets[:])) != .SUCCESS {
			return false
		}
		sim.gpu.sim_sets[frame_slot] = sets[0]
		sim.gpu.init_sets[frame_slot] = sets[1]
		sim.gpu.color_sets[frame_slot] = sets[2]
		sim.gpu.view_sets[frame_slot] = sets[3]
		sim.gpu.force_randomize_sets[frame_slot] = sets[4]
		sim.gpu.force_update_sets[frame_slot] = sets[5]
		sim.gpu.analysis_sets[frame_slot] = sets[6]
	}
	particle_life_update_descriptors(sim, vk_ctx)
	return true
}

particle_life_create_init_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = &sim.gpu.init_set_layout,
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &sim.gpu.init_pipeline.layout) != .SUCCESS {
		return false
	}
	stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.COMPUTE},
		module = sim.gpu.init_shader_module.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	info := vk.ComputePipelineCreateInfo {
		sType = .COMPUTE_PIPELINE_CREATE_INFO,
		stage = stage,
		layout = sim.gpu.init_pipeline.layout,
	}
	if vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &sim.gpu.init_pipeline.pipeline) != .SUCCESS {
		return false
	}
	return true
}

particle_life_create_compute_pipeline_for_module :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, shader: engine.Vk_Shader_Module, pipeline: ^engine.Vk_Compute_Pipeline) -> bool {
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = &sim.gpu.sim_set_layout,
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}
	stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.COMPUTE},
		module = shader.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	info := vk.ComputePipelineCreateInfo {
		sType = .COMPUTE_PIPELINE_CREATE_INFO,
		stage = stage,
		layout = pipeline.layout,
	}
	if vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline) != .SUCCESS {
		return false
	}
	return true
}

particle_life_create_compute_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, sim.gpu.grid_clear_shader_module, &sim.gpu.grid_clear_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, sim.gpu.grid_scatter_shader_module, &sim.gpu.grid_scatter_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, sim.gpu.grid_scatter_predicted_shader_module, &sim.gpu.grid_scatter_predicted_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, sim.gpu.compute_binned_shader_module, &sim.gpu.compute_binned_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, sim.gpu.collision_solve_shader_module, &sim.gpu.collision_solve_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, sim.gpu.collision_apply_shader_module, &sim.gpu.collision_apply_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, sim.gpu.copy_scratch_shader_module, &sim.gpu.copy_scratch_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, sim.gpu.analysis_clear_shader_module, sim.gpu.analysis_set_layout, &sim.gpu.analysis_clear_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, sim.gpu.analysis_scatter_shader_module, sim.gpu.analysis_set_layout, &sim.gpu.analysis_scatter_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, sim.gpu.analysis_coherence_shader_module, sim.gpu.analysis_set_layout, &sim.gpu.analysis_coherence_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, sim.gpu.analysis_tile_label_shader_module, sim.gpu.analysis_set_layout, &sim.gpu.analysis_tile_label_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, sim.gpu.analysis_tile_merge_shader_module, sim.gpu.analysis_set_layout, &sim.gpu.analysis_tile_merge_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, sim.gpu.analysis_summarize_shader_module, sim.gpu.analysis_set_layout, &sim.gpu.analysis_summarize_pipeline) {
		return false
	}
	return true
}

particle_life_create_analysis_pipeline :: proc(vk_ctx: ^engine.Vk_Context, shader: engine.Vk_Shader_Module, set_layout: vk.DescriptorSetLayout, pipeline: ^engine.Vk_Compute_Pipeline) -> bool {
	set_layouts := [1]vk.DescriptorSetLayout{set_layout}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = raw_data(set_layouts[:]),
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}
	stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.COMPUTE},
		module = shader.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	info := vk.ComputePipelineCreateInfo {
		sType = .COMPUTE_PIPELINE_CREATE_INFO,
		stage = stage,
		layout = pipeline.layout,
	}
	result := vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_analysis_pipeline: CreateComputePipelines failed result=", result)
		return false
	}
	return true
}

particle_life_create_force_pipeline :: proc(vk_ctx: ^engine.Vk_Context, shader: engine.Vk_Shader_Module, set_layout: vk.DescriptorSetLayout, pipeline: ^engine.Vk_Compute_Pipeline) -> bool {
	set_layouts := [1]vk.DescriptorSetLayout{set_layout}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = raw_data(set_layouts[:]),
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}
	stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.COMPUTE},
		module = shader.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	info := vk.ComputePipelineCreateInfo {
		sType = .COMPUTE_PIPELINE_CREATE_INFO,
		stage = stage,
		layout = pipeline.layout,
	}
	result := vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_force_pipeline: CreateComputePipelines failed result=", result)
		return false
	}
	return true
}

particle_life_create_force_pipelines :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if !particle_life_create_force_pipeline(vk_ctx, sim.gpu.force_randomize_shader_module, sim.gpu.force_op_set_layout, &sim.gpu.force_randomize_pipeline) {
		return false
	}
	if !particle_life_create_force_pipeline(vk_ctx, sim.gpu.force_update_shader_module, sim.gpu.force_op_set_layout, &sim.gpu.force_update_pipeline) {
		return false
	}
	return true
}

particle_life_create_particle_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, render_pass: vk.RenderPass, pipeline: ^engine.Vk_Graphics_Pipeline) -> bool {
	vertex_stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.VERTEX},
		module = sim.gpu.vertex_shader_module.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	fragment_stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.FRAGMENT},
		module = sim.gpu.fragment_shader_module.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	stages := [?]vk.PipelineShaderStageCreateInfo{vertex_stage, fragment_stage}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo {
		sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		topology = .TRIANGLE_LIST,
	}
	viewport_state := vk.PipelineViewportStateCreateInfo {
		sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		viewportCount = 1,
		scissorCount = 1,
	}
	raster := vk.PipelineRasterizationStateCreateInfo {
		sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		polygonMode = .FILL,
		cullMode = {},
		frontFace = .COUNTER_CLOCKWISE,
		lineWidth = 1,
	}
	multisample := vk.PipelineMultisampleStateCreateInfo {
		sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		rasterizationSamples = {._1},
	}
	blend_attachment := vk.PipelineColorBlendAttachmentState {
		blendEnable = true,
		srcColorBlendFactor = .SRC_ALPHA,
		dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
		colorBlendOp = .ADD,
		srcAlphaBlendFactor = .ONE,
		dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA,
		alphaBlendOp = .ADD,
		colorWriteMask = {.R, .G, .B, .A},
	}
	blend := vk.PipelineColorBlendStateCreateInfo {
		sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		attachmentCount = 1,
		pAttachments = &blend_attachment,
	}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo {
		sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = u32(len(dynamic_states)),
		pDynamicStates = raw_data(dynamic_states[:]),
	}
	set_layouts := [3]vk.DescriptorSetLayout{sim.gpu.sim_set_layout, sim.gpu.color_set_layout, sim.gpu.view_set_layout}
	push_range := vk.PushConstantRange {
		stageFlags = {.VERTEX},
		offset = 0,
		size = u32(size_of(Particle_Life_Viewport_Push)),
	}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = u32(len(set_layouts)),
		pSetLayouts = raw_data(set_layouts[:]),
		pushConstantRangeCount = 1,
		pPushConstantRanges = &push_range,
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}
	info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = u32(len(stages)),
		pStages = raw_data(stages[:]),
		pVertexInputState = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState = &multisample,
		pColorBlendState = &blend,
		pDynamicState = &dynamic_state,
		layout = pipeline.layout,
		renderPass = render_pass,
		subpass = 0,
	}
	result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_particle_pipeline: CreateGraphicsPipelines failed result=", result)
		return false
	}
	return true
}

particle_life_create_render_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	return particle_life_create_particle_pipeline(sim, vk_ctx, vk_ctx.render_pass, &sim.gpu.render_pipeline)
}

particle_life_create_trail_render_pass :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	attachment := vk.AttachmentDescription {
		format = vk_ctx.swapchain_format,
		samples = {._1},
		loadOp = .CLEAR,
		storeOp = .STORE,
		stencilLoadOp = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout = .COLOR_ATTACHMENT_OPTIMAL,
		finalLayout = .COLOR_ATTACHMENT_OPTIMAL,
	}
	color_ref := vk.AttachmentReference {
		attachment = 0,
		layout = .COLOR_ATTACHMENT_OPTIMAL,
	}
	subpass := vk.SubpassDescription {
		pipelineBindPoint = .GRAPHICS,
		colorAttachmentCount = 1,
		pColorAttachments = &color_ref,
	}
	dependency := vk.SubpassDependency {
		srcSubpass = vk.SUBPASS_EXTERNAL,
		dstSubpass = 0,
		srcStageMask = {.COLOR_ATTACHMENT_OUTPUT},
		dstStageMask = {.COLOR_ATTACHMENT_OUTPUT},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
		dependencyFlags = {.BY_REGION},
	}
	info := vk.RenderPassCreateInfo {
		sType = .RENDER_PASS_CREATE_INFO,
		attachmentCount = 1,
		pAttachments = &attachment,
		subpassCount = 1,
		pSubpasses = &subpass,
		dependencyCount = 1,
		pDependencies = &dependency,
	}
	result := vk.CreateRenderPass(vk_ctx.device, &info, nil, &sim.gpu.trail_render_pass)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_trail_render_pass: CreateRenderPass failed result=", result)
		return false
	}
	return true
}

particle_life_create_trail_image :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, index: int, width, height: u32) -> bool {
	image := &sim.gpu.trail_images[index]
	image_info := vk.ImageCreateInfo {
		sType = .IMAGE_CREATE_INFO,
		imageType = .D2,
		format = vk_ctx.swapchain_format,
		extent = {width, height, 1},
		mipLevels = 1,
		arrayLayers = 1,
		samples = {._1},
		tiling = .OPTIMAL,
		usage = {.COLOR_ATTACHMENT, .SAMPLED, .TRANSFER_SRC, .TRANSFER_DST},
		sharingMode = .EXCLUSIVE,
		initialLayout = .UNDEFINED,
	}
	if result := vk.CreateImage(vk_ctx.device, &image_info, nil, &image.handle); result != .SUCCESS {
		engine.log_error("particle_life_create_trail_image: CreateImage failed index=", index, " result=", result, " size=", width, "x", height, " format=", image_info.format)
		return false
	}
	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device, image.handle, &req)
	memory_type, ok := engine.vk_find_memory_type(vk_ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {
		return false
	}
	alloc := vk.MemoryAllocateInfo {
		sType = .MEMORY_ALLOCATE_INFO,
		allocationSize = req.size,
		memoryTypeIndex = memory_type,
	}
	if result := vk.AllocateMemory(vk_ctx.device, &alloc, nil, &image.memory); result != .SUCCESS {
		engine.log_error("particle_life_create_trail_image: AllocateMemory failed index=", index, " result=", result)
		return false
	}
	if result := vk.BindImageMemory(vk_ctx.device, image.handle, image.memory, 0); result != .SUCCESS {
		engine.log_error("particle_life_create_trail_image: BindImageMemory failed index=", index, " result=", result)
		return false
	}
	view_info := vk.ImageViewCreateInfo {
		sType = .IMAGE_VIEW_CREATE_INFO,
		image = image.handle,
		viewType = .D2,
		format = vk_ctx.swapchain_format,
		subresourceRange = {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
		},
	}
	if result := vk.CreateImageView(vk_ctx.device, &view_info, nil, &image.view); result != .SUCCESS {
		engine.log_error("particle_life_create_trail_image: CreateImageView failed index=", index, " result=", result)
		return false
	}
	attachment := image.view
	framebuffer_info := vk.FramebufferCreateInfo {
		sType = .FRAMEBUFFER_CREATE_INFO,
		renderPass = sim.gpu.trail_render_pass,
		attachmentCount = 1,
		pAttachments = &attachment,
		width = width,
		height = height,
		layers = 1,
	}
	if result := vk.CreateFramebuffer(vk_ctx.device, &framebuffer_info, nil, &image.framebuffer); result != .SUCCESS {
		engine.log_error("particle_life_create_trail_image: CreateFramebuffer failed index=", index, " result=", result)
		return false
	}
	image.layout = .UNDEFINED
	return true
}

particle_life_create_fade_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	set_layouts := [1]vk.DescriptorSetLayout{sim.gpu.fade_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = u32(len(set_layouts)),
		pSetLayouts = raw_data(set_layouts[:]),
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &sim.gpu.fade_pipeline.layout) != .SUCCESS {
		return false
	}
	stages := [2]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = sim.gpu.fade_vertex_shader_module.handle, pName = PARTICLE_LIFE_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = sim.gpu.fade_fragment_shader_module.handle, pName = PARTICLE_LIFE_ENTRY},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState {
		blendEnable = true,
		srcColorBlendFactor = .SRC_ALPHA,
		dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
		colorBlendOp = .ADD,
		srcAlphaBlendFactor = .ONE,
		dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA,
		alphaBlendOp = .ADD,
		colorWriteMask = {.R, .G, .B, .A},
	}
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = u32(len(dynamic_states)), pDynamicStates = raw_data(dynamic_states[:])}
	info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = u32(len(stages)),
		pStages = raw_data(stages[:]),
		pVertexInputState = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState = &multisample,
		pColorBlendState = &blend,
		pDynamicState = &dynamic_state,
		layout = sim.gpu.fade_pipeline.layout,
		renderPass = sim.gpu.trail_render_pass,
		subpass = 0,
	}
	result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &sim.gpu.fade_pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_fade_pipeline: CreateGraphicsPipelines failed result=", result)
		return false
	}
	return true
}

particle_life_create_fullscreen_pipeline :: proc(vk_ctx: ^engine.Vk_Context, vertex_module, fragment_module: engine.Vk_Shader_Module, vertex_entry, fragment_entry: string, render_pass: vk.RenderPass, set_layout: vk.DescriptorSetLayout, blend_enabled: bool, pipeline: ^engine.Vk_Graphics_Pipeline) -> bool {
	set_layouts := [1]vk.DescriptorSetLayout{set_layout}
	vertex_entry_c, vertex_err := strings.clone_to_cstring(vertex_entry, context.temp_allocator)
	if vertex_err != nil {
		return false
	}
	fragment_entry_c, fragment_err := strings.clone_to_cstring(fragment_entry, context.temp_allocator)
	if fragment_err != nil {
		return false
	}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = raw_data(set_layouts[:]),
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}
	stages := [2]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = vertex_module.handle, pName = vertex_entry_c},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = fragment_module.handle, pName = fragment_entry_c},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState {
		blendEnable = b32(blend_enabled),
		srcColorBlendFactor = .SRC_ALPHA,
		dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
		colorBlendOp = .ADD,
		srcAlphaBlendFactor = .ONE,
		dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA,
		alphaBlendOp = .ADD,
		colorWriteMask = {.R, .G, .B, .A},
	}
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = u32(len(dynamic_states)), pDynamicStates = raw_data(dynamic_states[:])}
	info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = u32(len(stages)),
		pStages = raw_data(stages[:]),
		pVertexInputState = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState = &multisample,
		pColorBlendState = &blend,
		pDynamicState = &dynamic_state,
		layout = pipeline.layout,
		renderPass = render_pass,
		subpass = 0,
	}
	result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_fullscreen_pipeline: CreateGraphicsPipelines failed result=", result, " vertex_entry=", vertex_entry, " fragment_entry=", fragment_entry, " render_pass=", render_pass)
		return false
	}
	return true
}

particle_life_create_trail_resources :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if !particle_life_create_trail_render_pass(sim, vk_ctx) {
		return false
	}
	if !particle_life_create_particle_pipeline(sim, vk_ctx, sim.gpu.trail_render_pass, &sim.gpu.trail_particle_pipeline) {
		return false
	}
	fade_bindings := [3]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	fade_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(fade_bindings)),
		pBindings = raw_data(fade_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &fade_layout_info, nil, &sim.gpu.fade_set_layout) != .SUCCESS {
		return false
	}
	background_binding := vk.DescriptorSetLayoutBinding{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}}
	background_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = 1,
		pBindings = &background_binding,
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &background_layout_info, nil, &sim.gpu.background_set_layout) != .SUCCESS {
		return false
	}
	post_bindings := [4]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}},
	}
	post_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(post_bindings)),
		pBindings = raw_data(post_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &post_layout_info, nil, &sim.gpu.post_set_layout) != .SUCCESS {
		return false
	}
	pool_sizes := [3]vk.DescriptorPoolSize {
		{type = .UNIFORM_BUFFER, descriptorCount = 7 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .SAMPLED_IMAGE, descriptorCount = 4 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .SAMPLER, descriptorCount = 4 * engine.MAX_FRAMES_IN_FLIGHT},
	}
	pool_info := vk.DescriptorPoolCreateInfo {
		sType = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = u32(len(pool_sizes)),
		pPoolSizes = raw_data(pool_sizes[:]),
		maxSets = 5 * engine.MAX_FRAMES_IN_FLIGHT,
	}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &sim.gpu.fade_descriptor_pool) != .SUCCESS {
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		fade_layouts := [2]vk.DescriptorSetLayout{sim.gpu.fade_set_layout, sim.gpu.fade_set_layout}
		fade_sets: [2]vk.DescriptorSet
		fade_alloc := vk.DescriptorSetAllocateInfo {
			sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
			descriptorPool = sim.gpu.fade_descriptor_pool,
			descriptorSetCount = u32(len(fade_layouts)),
			pSetLayouts = raw_data(fade_layouts[:]),
		}
		if vk.AllocateDescriptorSets(vk_ctx.device, &fade_alloc, raw_data(fade_sets[:])) != .SUCCESS {
			return false
		}
		sim.gpu.fade_sets[frame_slot][0] = fade_sets[0]
		sim.gpu.fade_sets[frame_slot][1] = fade_sets[1]
		background_alloc := vk.DescriptorSetAllocateInfo {
			sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
			descriptorPool = sim.gpu.fade_descriptor_pool,
			descriptorSetCount = 1,
			pSetLayouts = &sim.gpu.background_set_layout,
		}
		if vk.AllocateDescriptorSets(vk_ctx.device, &background_alloc, &sim.gpu.background_sets[frame_slot]) != .SUCCESS {
			return false
		}
		post_layouts := [2]vk.DescriptorSetLayout{sim.gpu.post_set_layout, sim.gpu.post_set_layout}
		post_sets: [2]vk.DescriptorSet
		post_alloc := vk.DescriptorSetAllocateInfo {
			sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
			descriptorPool = sim.gpu.fade_descriptor_pool,
			descriptorSetCount = u32(len(post_layouts)),
			pSetLayouts = raw_data(post_layouts[:]),
		}
		if vk.AllocateDescriptorSets(vk_ctx.device, &post_alloc, raw_data(post_sets[:])) != .SUCCESS {
			return false
		}
		sim.gpu.post_sets[frame_slot][0] = post_sets[0]
		sim.gpu.post_sets[frame_slot][1] = post_sets[1]
	}
	sampler_info := vk.SamplerCreateInfo {sType = .SAMPLER_CREATE_INFO}
	sampler_info.magFilter = .LINEAR
	sampler_info.minFilter = .LINEAR
	sampler_info.mipmapMode = .LINEAR
	sampler_info.addressModeU = .CLAMP_TO_EDGE
	sampler_info.addressModeV = .CLAMP_TO_EDGE
	sampler_info.addressModeW = .CLAMP_TO_EDGE
	sampler_info.minLod = 0
	sampler_info.maxLod = 1
	if vk.CreateSampler(vk_ctx.device, &sampler_info, nil, &sim.gpu.trail_sampler) != .SUCCESS {
		return false
	}
	if !particle_life_create_fade_pipeline(sim, vk_ctx) {
		return false
	}
	if !particle_life_create_fullscreen_pipeline(vk_ctx, sim.gpu.background_vertex_shader_module, sim.gpu.background_fragment_shader_module, PARTICLE_LIFE_BACKGROUND_VERTEX_ENTRY, PARTICLE_LIFE_BACKGROUND_FRAGMENT_ENTRY, sim.gpu.trail_render_pass, sim.gpu.background_set_layout, false, &sim.gpu.background_pipeline) {
		return false
	}
	if !particle_life_create_fullscreen_pipeline(vk_ctx, sim.gpu.post_vertex_shader_module, sim.gpu.post_fragment_shader_module, PARTICLE_LIFE_POST_VERTEX_ENTRY, PARTICLE_LIFE_POST_FRAGMENT_ENTRY, vk_ctx.render_pass, sim.gpu.post_set_layout, false, &sim.gpu.post_pipeline) {
		return false
	}
	if !particle_life_create_fullscreen_pipeline(vk_ctx, sim.gpu.infinite_present_vertex_shader_module, sim.gpu.infinite_present_fragment_shader_module, PARTICLE_LIFE_INFINITE_PRESENT_VERTEX_ENTRY, PARTICLE_LIFE_INFINITE_PRESENT_FRAGMENT_ENTRY, vk_ctx.render_pass, sim.gpu.post_set_layout, false, &sim.gpu.tiled_post_pipeline) {
		return false
	}
	return true
}

particle_life_update_descriptors :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		particle_life_update_descriptors_for_slot(sim, vk_ctx, frame_slot)
	}
}

particle_life_update_descriptors_for_slot :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	particle_info := vk.DescriptorBufferInfo{buffer = sim.gpu.particle_buffer.handle, offset = 0, range = sim.gpu.particle_buffer.size}
	particle_scratch_info := vk.DescriptorBufferInfo{buffer = sim.gpu.particle_scratch_buffer.handle, offset = 0, range = sim.gpu.particle_scratch_buffer.size}
	params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Params))}
	grid_heads_info := vk.DescriptorBufferInfo{buffer = sim.gpu.grid_heads_buffer.handle, offset = 0, range = sim.gpu.grid_heads_buffer.size}
	particle_next_info := vk.DescriptorBufferInfo{buffer = sim.gpu.particle_next_buffer.handle, offset = 0, range = sim.gpu.particle_next_buffer.size}
	grid_params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.grid_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Grid_Params))}
	collision_correction_info := vk.DescriptorBufferInfo{buffer = sim.gpu.collision_correction_buffer.handle, offset = 0, range = sim.gpu.collision_correction_buffer.size}
	collision_params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.collision_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Collision_Params))}
	init_params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.init_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Init_Params))}
	force_info := vk.DescriptorBufferInfo{buffer = sim.gpu.force_matrix_buffer.handle, offset = 0, range = sim.gpu.force_matrix_buffer.size}
	color_info := vk.DescriptorBufferInfo{buffer = sim.gpu.color_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Species_Colors))}
	mode_info := vk.DescriptorBufferInfo{buffer = sim.gpu.color_mode_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Color_Mode_Params))}
	camera_info := vk.DescriptorBufferInfo{buffer = sim.gpu.camera_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Camera))}
	viewport_info := vk.DescriptorBufferInfo{buffer = sim.gpu.viewport_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Viewport))}
	force_randomize_info := vk.DescriptorBufferInfo{buffer = sim.gpu.force_randomize_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Force_Randomize_Params))}
	force_update_info := vk.DescriptorBufferInfo{buffer = sim.gpu.force_update_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Force_Update_Params))}
	analysis_params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Analysis_Params))}
	analysis_cells_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_cells_buffer.handle, offset = 0, range = sim.gpu.analysis_cells_buffer.size}
	analysis_coherence_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_coherence_buffer.handle, offset = 0, range = sim.gpu.analysis_coherence_buffer.size}
	analysis_labels_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_labels_buffer.handle, offset = 0, range = sim.gpu.analysis_labels_buffer.size}
	analysis_tile_components_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_tile_components_buffer.handle, offset = 0, range = sim.gpu.analysis_tile_components_buffer.size}
	analysis_parent_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_parent_buffer.handle, offset = 0, range = sim.gpu.analysis_parent_buffer.size}
	analysis_blob_summaries_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_blob_summaries_buffer.handle, offset = 0, range = sim.gpu.analysis_blob_summaries_buffer.size}
	analysis_blob_count_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_blob_count_buffer.handle, offset = 0, range = sim.gpu.analysis_blob_count_buffer.size}
	sim_set := sim.gpu.sim_sets[frame_slot]
	init_set := sim.gpu.init_sets[frame_slot]
	color_set := sim.gpu.color_sets[frame_slot]
	view_set := sim.gpu.view_sets[frame_slot]
	force_randomize_set := sim.gpu.force_randomize_sets[frame_slot]
	force_update_set := sim.gpu.force_update_sets[frame_slot]
	analysis_set := sim.gpu.analysis_sets[frame_slot]
	writes := [29]vk.WriteDescriptorSet {
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &force_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_heads_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_next_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 5, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &grid_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 6, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_scratch_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 7, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &collision_correction_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 8, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &collision_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = init_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = init_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &init_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = color_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &color_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = color_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &mode_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = view_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &camera_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = view_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &viewport_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = force_randomize_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &force_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = force_randomize_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &force_randomize_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = force_update_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &force_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = force_update_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &force_update_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_cells_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_coherence_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 5, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_labels_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 6, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_tile_components_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 7, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_parent_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 8, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_blob_summaries_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 9, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_blob_count_info},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
}

particle_life_upload_force_matrix :: proc(sim: ^Particle_Life_Simulation) {
	if sim.gpu.force_matrix_buffer.mapped == nil {
		return
	}
	species_count := int(max(sim.gpu.uploaded_species_count, 1))
	forces := cast([^]f32)sim.gpu.force_matrix_buffer.mapped
	generated_matrix: [PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32
	if !sim.settings.custom_force_matrix {
		particle_life_generate_force_matrix(&generated_matrix, u32(species_count), sim.settings.force_generator, sim.settings.force_random_min, sim.settings.force_random_max, sim.runtime.seed)
	}
	for a in 0 ..< species_count {
		for b in 0 ..< species_count {
			v: f32
			if sim.settings.custom_force_matrix {
				v = sim.settings.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b]
			} else {
				v = generated_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b]
			}
			forces[a * species_count + b] = v
			sim.runtime.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = v
			sim.settings.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = v
		}
	}
	sim.settings.custom_force_matrix = true
	sim.runtime.force_matrix_dirty = false
}


particle_life_upload_static_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.color_buffers[frame_slot].mapped != nil {
		colors := cast(^Particle_Life_Species_Colors)sim.gpu.color_buffers[frame_slot].mapped
		colors^ = {}
		scheme_name := color_scheme_name_get(&sim.settings.color_scheme)
		scheme, ok := color_scheme_load(scheme_name)
		if !ok {
			scheme = color_scheme_default()
		}
		if sim.settings.color_scheme_reversed {
			color_scheme_reverse(&scheme)
		}
		species_count := int(particle_life_target_species_count(sim.settings))
		for i in 0 ..< PARTICLE_LIFE_MAX_SPECIES {
			t := 0
			if sim.settings.background_color_mode == .Color_Scheme && species_count > 0 {
				t = int(((i + 1) * (COLOR_SCHEME_SIZE - 1)) / species_count)
			} else if PARTICLE_LIFE_MAX_SPECIES > 1 {
				t = int((i * (COLOR_SCHEME_SIZE - 1)) / (PARTICLE_LIFE_MAX_SPECIES - 1))
			}
			t = max(min(t, COLOR_SCHEME_SIZE - 1), 0)
			colors.colors[i] = {
				f32(scheme.red[t]) / 255.0,
				f32(scheme.green[t]) / 255.0,
				f32(scheme.blue[t]) / 255.0,
				1,
			}
		}
		colors.colors[PARTICLE_LIFE_MAX_SPECIES] = particle_life_background_color(&sim.settings)
	}
	if sim.gpu.color_mode_buffers[frame_slot].mapped != nil {
		mode := cast(^Particle_Life_Color_Mode_Params)sim.gpu.color_mode_buffers[frame_slot].mapped
		mode^ = {
			mode = u32(sim.settings.color_mode),
			brightness = sim.settings.brightness,
			contrast = sim.settings.contrast,
			saturation = sim.settings.saturation,
			gamma = max(sim.settings.gamma, 0.01),
		}
	}
}

particle_life_write_init_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.init_params_buffers[frame_slot].mapped == nil {
		return
	}
	world_size := particle_life_world_size(sim)
	params := cast(^Particle_Life_Init_Params)sim.gpu.init_params_buffers[frame_slot].mapped
	params^ = {
		start_index = 0,
		spawn_count = sim.gpu.uploaded_particle_count,
		species_count = sim.gpu.uploaded_species_count,
		width = world_size[0],
		height = world_size[1],
		random_seed = sim.runtime.seed,
		position_generator = sim.settings.position_generator,
		type_generator = sim.settings.type_generator,
	}
}

particle_life_write_frame_uniforms :: proc(sim: ^Particle_Life_Simulation, dt: f32) {
	frame_slot := sim.gpu.active_frame_slot
	particle_life_upload_static_uniforms(sim)
	width := f32(max(sim.gpu.width, 1))
	height := f32(max(sim.gpu.height, 1))
	aspect := width / max(height, 1)
	world_size := particle_life_world_size_for_viewport(width, height)
	bounds := particle_life_view_bounds(sim, width, height)
	if sim.gpu.params_buffers[frame_slot].mapped != nil {
		params := cast(^Particle_Life_Params)sim.gpu.params_buffers[frame_slot].mapped
		params^ = {
			particle_count = sim.gpu.uploaded_particle_count,
			species_count = sim.gpu.uploaded_species_count,
			max_force = sim.settings.max_force,
			max_distance = sim.settings.max_distance,
			friction = sim.settings.friction,
			wrap_edges = sim.settings.wrap_edges ? 1 : 0,
			width = world_size[0],
			height = world_size[1],
			random_seed = sim.runtime.seed + u32(sim.runtime.frame_index & 0xffffffff),
			dt = min(max(dt, 0.0), 0.033),
			beta = sim.settings.beta,
			cursor_x = sim.runtime.cursor_x,
			cursor_y = sim.runtime.cursor_y,
			cursor_size = sim.settings.cursor_size,
			cursor_strength = sim.settings.cursor_strength,
			cursor_active = sim.runtime.cursor_active,
			brownian_motion = sim.settings.brownian_motion,
			particle_size = sim.settings.particle_size,
			aspect_ratio = aspect,
		}
	}
	if sim.gpu.camera_buffers[frame_slot].mapped != nil {
		zoom := max(sim.runtime.camera_zoom, CAMERA_MIN_ZOOM)
		camera := cast(^Particle_Life_Camera)sim.gpu.camera_buffers[frame_slot].mapped
		camera^ = {
			transform_matrix = {
				zoom, 0, 0, 0,
				0, zoom, 0, 0,
				0, 0, 1, 0,
				-sim.runtime.camera_x * zoom, -sim.runtime.camera_y * zoom, 0, 1,
			},
			position = {sim.runtime.camera_x, sim.runtime.camera_y},
			zoom = zoom,
			aspect_ratio = aspect,
		}
	}
	if sim.gpu.viewport_buffers[frame_slot].mapped != nil {
		particle_life_write_viewport_uniforms(sim, width, height, bounds)
	}
}

particle_life_write_viewport_uniforms :: proc(sim: ^Particle_Life_Simulation, width, height: f32, bounds: [4]f32) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.viewport_buffers[frame_slot].mapped == nil {
		return
	}
	viewport := cast(^Particle_Life_Viewport)sim.gpu.viewport_buffers[frame_slot].mapped
	viewport^ = {
		world_bounds = bounds,
		texture_size = {width, height},
	}
}

particle_life_push_viewport_uniform_mode :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Graphics_Pipeline) {
	_ = vk_ctx
	push := Particle_Life_Viewport_Push{}
	vk.CmdPushConstants(cmd, pipeline.layout, {.VERTEX}, 0, u32(size_of(Particle_Life_Viewport_Push)), &push)
}

particle_life_push_viewport_bounds :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Graphics_Pipeline, bounds: [4]f32) {
	_ = vk_ctx
	push := Particle_Life_Viewport_Push{world_bounds = bounds, enabled = 1}
	vk.CmdPushConstants(cmd, pipeline.layout, {.VERTEX}, 0, u32(size_of(Particle_Life_Viewport_Push)), &push)
}

particle_life_write_grid_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.grid_params_buffers[frame_slot].mapped == nil {
		return
	}
	world_size := particle_life_world_size(sim)
	cell_w := world_size[0] / f32(max(sim.gpu.grid_width, 1))
	cell_h := world_size[1] / f32(max(sim.gpu.grid_height, 1))
	params := cast(^Particle_Life_Grid_Params)sim.gpu.grid_params_buffers[frame_slot].mapped
	params^ = {
		particle_count = sim.gpu.uploaded_particle_count,
		grid_width = sim.gpu.grid_width,
		grid_height = sim.gpu.grid_height,
		neighbor_radius_cells = sim.gpu.neighbor_radius_cells,
		cell_size = max(cell_w, cell_h),
		world_min_x = -world_size[0] * 0.5,
		world_min_y = -world_size[1] * 0.5,
		world_width = world_size[0],
		world_height = world_size[1],
	}
}

particle_life_write_collision_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.collision_params_buffers[frame_slot].mapped == nil {
		return
	}
	min_distance := particle_life_collision_distance(sim.settings)
	params := cast(^Particle_Life_Collision_Params)sim.gpu.collision_params_buffers[frame_slot].mapped
	params^ = {
		enabled = sim.settings.collision_enabled ? 1 : 0,
		iterations = max(min(sim.settings.collision_iterations, 8), 1),
		min_distance = min_distance,
		relaxation = max(min(sim.settings.collision_relaxation, 1.0), 0.0),
		max_correction = min_distance * 0.25,
		velocity_damping = max(min(sim.settings.collision_damping, 1.0), 0.0),
	}
}

particle_life_write_analysis_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.analysis_params_buffers[frame_slot].mapped != nil {
		params := cast(^Particle_Life_Analysis_Params)sim.gpu.analysis_params_buffers[frame_slot].mapped
		params^ = {
			enabled = sim.settings.analysis_enabled ? 1 : 0,
			interval_frames = max(sim.settings.analysis_interval_frames, 1),
			grid_size = max(sim.gpu.analysis_grid_axis, 1),
			min_blob_area_cells = max(sim.settings.min_blob_area_cells, 1),
			coherence_threshold = sim.settings.coherence_threshold,
		}
	}
	if sim.gpu.selected_blob_params_buffers[frame_slot].mapped != nil {
		params := cast(^Particle_Life_Selected_Blob_Params)sim.gpu.selected_blob_params_buffers[frame_slot].mapped
		params^ = {
			selected_blob_id = sim.runtime.selected_blob_id,
			overlay_enabled = sim.settings.blob_overlay_enabled ? 1 : 0,
		}
	}
}

particle_life_write_fade_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.fade_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Particle_Life_Fade_Params)sim.gpu.fade_params_buffers[frame_slot].mapped
	params^ = {
		fade_amount = max(min(sim.settings.trail_fade_amount, 1.0), 0.0),
	}
}

particle_life_write_background_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.background_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Particle_Life_Background_Params)sim.gpu.background_params_buffers[frame_slot].mapped
	params^ = {background_color = particle_life_background_color(&sim.settings)}
}

particle_life_write_post_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.post_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Particle_Life_Post_Params)sim.gpu.post_params_buffers[frame_slot].mapped
	params^ = {
		brightness = sim.settings.brightness,
		contrast = sim.settings.contrast,
		saturation = sim.settings.saturation,
		gamma = max(sim.settings.gamma, 0.01),
	}
}

particle_life_dispatch_init :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	particle_life_write_init_uniforms(sim)
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.init_pipeline.pipeline)
	init_set := sim.gpu.init_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.init_pipeline.layout, 0, 1, &init_set, 0, nil)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	barrier := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = {.SHADER_READ, .SHADER_WRITE},
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = sim.gpu.particle_buffer.handle,
		offset = 0,
		size = sim.gpu.particle_buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.COMPUTE_SHADER, .VERTEX_SHADER}, {}, 0, nil, 1, &barrier, 0, nil)
	sim.runtime.needs_reset = false
}

particle_life_force_barrier :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	barrier := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = {.SHADER_READ, .SHADER_WRITE},
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = sim.gpu.force_matrix_buffer.handle,
		offset = 0,
		size = sim.gpu.force_matrix_buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.COMPUTE_SHADER}, {}, 0, nil, 1, &barrier, 0, nil)
}

particle_life_buffer_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, buffer: engine.Vk_Buffer, dst_stage: vk.PipelineStageFlags, dst_access: vk.AccessFlags) {
	barrier := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = dst_access,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = buffer.handle,
		offset = 0,
		size = buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, dst_stage, {}, 0, nil, 1, &barrier, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

particle_life_grid_barrier :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dst_stage: vk.PipelineStageFlags, dst_access: vk.AccessFlags) {
	barriers := [2]vk.BufferMemoryBarrier {
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.grid_heads_buffer.handle, offset = 0, size = sim.gpu.grid_heads_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.particle_next_buffer.handle, offset = 0, size = sim.gpu.particle_next_buffer.size},
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, dst_stage, {}, 0, nil, u32(len(barriers)), raw_data(barriers[:]), 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx, u32(len(barriers)))
}

particle_life_copy_scratch_to_particles_transfer :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	to_transfer := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = {.TRANSFER_READ},
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = sim.gpu.particle_scratch_buffer.handle,
		offset = 0,
		size = sim.gpu.particle_scratch_buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.TRANSFER}, {}, 0, nil, 1, &to_transfer, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	region := vk.BufferCopy {
		srcOffset = 0,
		dstOffset = 0,
		size = min(sim.gpu.particle_scratch_buffer.size, sim.gpu.particle_buffer.size),
	}
	vk.CmdCopyBuffer(cmd, sim.gpu.particle_scratch_buffer.handle, sim.gpu.particle_buffer.handle, 1, &region)
	engine.vk_cmd_count_transfer_copy(vk_ctx)
	to_vertex := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.TRANSFER_WRITE},
		dstAccessMask = {.SHADER_READ},
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = sim.gpu.particle_buffer.handle,
		offset = 0,
		size = sim.gpu.particle_buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.TRANSFER}, {.VERTEX_SHADER, .COMPUTE_SHADER}, {}, 0, nil, 1, &to_vertex, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

particle_life_copy_scratch_to_particles :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	if sim.gpu.copy_scratch_pipeline.pipeline == vk.Pipeline(0) {
		particle_life_copy_scratch_to_particles_transfer(sim, vk_ctx, cmd)
		return
	}
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.copy_scratch_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.copy_scratch_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_buffer_barrier(vk_ctx, cmd, sim.gpu.particle_buffer, {.VERTEX_SHADER, .COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_grid_clear :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	particle_life_write_grid_uniforms(sim)
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.grid_clear_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.grid_clear_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	cells := sim.gpu.grid_width * sim.gpu.grid_height
	group_x := u32((cells + PARTICLE_LIFE_GRID_CLEAR_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_GRID_CLEAR_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_grid_barrier(sim, vk_ctx, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_grid_scatter :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.grid_scatter_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.grid_scatter_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_grid_barrier(sim, vk_ctx, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_grid_scatter_predicted :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.grid_scatter_predicted_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.grid_scatter_predicted_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_grid_barrier(sim, vk_ctx, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_binned_compute :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.compute_binned_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.compute_binned_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_buffer_barrier(vk_ctx, cmd, sim.gpu.particle_scratch_buffer, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_collision_solve :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.collision_solve_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.collision_solve_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_buffer_barrier(vk_ctx, cmd, sim.gpu.collision_correction_buffer, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_collision_apply :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.collision_apply_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.collision_apply_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_buffer_barrier(vk_ctx, cmd, sim.gpu.particle_scratch_buffer, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_collision_solver :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	particle_life_write_collision_uniforms(sim)
	if !sim.settings.collision_enabled {
		return
	}
	particle_life_dispatch_grid_clear(sim, vk_ctx, cmd)
	particle_life_dispatch_grid_scatter_predicted(sim, vk_ctx, cmd)
	iterations := max(min(sim.settings.collision_iterations, 8), 1)
	for iteration: u32 = 0; iteration < iterations; iteration += 1 {
		particle_life_dispatch_collision_solve(sim, vk_ctx, cmd)
		particle_life_dispatch_collision_apply(sim, vk_ctx, cmd)
	}
}

particle_life_analysis_frame_due :: proc(sim: ^Particle_Life_Simulation) -> bool {
	if !sim.settings.analysis_enabled {
		return false
	}
	interval := u64(max(sim.settings.analysis_interval_frames, 1))
	return sim.runtime.frame_index != sim.runtime.last_analysis_frame && (sim.runtime.frame_index % interval) == 0
}

particle_life_analysis_gpu_ready :: proc(sim: ^Particle_Life_Simulation) -> bool {
	return sim.gpu.analysis_sets[sim.gpu.active_frame_slot] != vk.DescriptorSet(0) &&
		sim.gpu.analysis_clear_pipeline.pipeline != vk.Pipeline(0) &&
		sim.gpu.analysis_blob_count_buffer.mapped != nil &&
		sim.gpu.analysis_blob_summaries_buffer.mapped != nil
}

particle_life_analysis_barrier :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer, dst_stage: vk.PipelineStageFlags, dst_access: vk.AccessFlags) {
	barriers := [7]vk.BufferMemoryBarrier {
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_cells_buffer.handle, offset = 0, size = sim.gpu.analysis_cells_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_coherence_buffer.handle, offset = 0, size = sim.gpu.analysis_coherence_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_labels_buffer.handle, offset = 0, size = sim.gpu.analysis_labels_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_tile_components_buffer.handle, offset = 0, size = sim.gpu.analysis_tile_components_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_parent_buffer.handle, offset = 0, size = sim.gpu.analysis_parent_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_blob_summaries_buffer.handle, offset = 0, size = sim.gpu.analysis_blob_summaries_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_blob_count_buffer.handle, offset = 0, size = sim.gpu.analysis_blob_count_buffer.size},
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, dst_stage, {}, 0, nil, u32(len(barriers)), raw_data(barriers[:]), 0, nil)
}

particle_life_dispatch_analysis_pipeline :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Compute_Pipeline, groups_x, groups_y: u32) {
	vk.CmdBindPipeline(cmd, .COMPUTE, pipeline.pipeline)
	analysis_set := sim.gpu.analysis_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, pipeline.layout, 0, 1, &analysis_set, 0, nil)
	vk.CmdDispatch(cmd, max(groups_x, 1), max(groups_y, 1), 1)
	particle_life_analysis_barrier(sim, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_gpu_blob_analysis :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	if !particle_life_analysis_frame_due(sim) || !particle_life_analysis_gpu_ready(sim) {
		return
	}
	particle_life_write_analysis_uniforms(sim)
	axis := max(sim.gpu.analysis_grid_axis, 1)
	cells := axis * axis
	particle_groups := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	cell_groups := u32((cells + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	tile_count := max(sim.gpu.analysis_tile_count, 1)

	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_clear_pipeline, cell_groups, 1)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_scatter_pipeline, particle_groups, 1)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_coherence_pipeline, cell_groups, 1)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_tile_label_pipeline, tile_count, tile_count)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_tile_merge_pipeline, cell_groups, 1)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_summarize_pipeline, cell_groups, 1)
	particle_life_analysis_barrier(sim, cmd, {.HOST}, {.HOST_READ})
	sim.runtime.last_analysis_frame = sim.runtime.frame_index
}

particle_life_read_gpu_blob_analysis :: proc(sim: ^Particle_Life_Simulation) {
	if !particle_life_analysis_frame_due(sim) || sim.runtime.last_analysis_frame == 0 || sim.runtime.last_analysis_read_frame == sim.runtime.last_analysis_frame || !particle_life_analysis_gpu_ready(sim) {
		return
	}
	count_ptr := cast(^u32)sim.gpu.analysis_blob_count_buffer.mapped
	accumulators := cast([^]Particle_Life_Blob_Accumulator)sim.gpu.analysis_blob_summaries_buffer.mapped
	raw_count := min(count_ptr^, PARTICLE_LIFE_ANALYSIS_MAX_BLOBS)
	summaries: [PARTICLE_LIFE_ANALYSIS_MAX_BLOBS]Particle_Life_Blob_Summary
	out_count: u32
	axis := max(sim.gpu.analysis_grid_axis, 1)
	world_size := particle_life_world_size(sim)
	cell_w := world_size[0] / f32(axis)
	cell_h := world_size[1] / f32(axis)
	world_min_x := -world_size[0] * 0.5
	world_min_y := -world_size[1] * 0.5
	for i: u32 = 0; i < raw_count; i += 1 {
		acc := accumulators[i]
		if acc.area < max(sim.settings.min_blob_area_cells, 1) || acc.density == 0 {
			continue
		}
		summary: Particle_Life_Blob_Summary
		summary.id = acc.id
		summary.area = acc.area
		summary.density = f32(acc.density)
		inv_density := 1.0 / max(f32(acc.density), 1.0)
		summary.centroid = {
			(f32(acc.centroid_sum[0]) / PARTICLE_LIFE_ANALYSIS_COORD_SCALE) * inv_density,
			(f32(acc.centroid_sum[1]) / PARTICLE_LIFE_ANALYSIS_COORD_SCALE) * inv_density,
		}
		summary.velocity = {
			(f32(acc.velocity_sum[0]) / PARTICLE_LIFE_ANALYSIS_VELOCITY_SCALE) * inv_density,
			(f32(acc.velocity_sum[1]) / PARTICLE_LIFE_ANALYSIS_VELOCITY_SCALE) * inv_density,
		}
		summary.bounds = {
			world_min_x + f32(acc.bounds_min[0]) * cell_w,
			world_min_y + f32(acc.bounds_min[1]) * cell_h,
			world_min_x + f32(acc.bounds_max[0] + 1) * cell_w,
			world_min_y + f32(acc.bounds_max[1] + 1) * cell_h,
		}
		summary.coherence_score = (f32(acc.coherence_sum) / PARTICLE_LIFE_ANALYSIS_COHERENCE_SCALE) / f32(max(acc.area, 1))
		summary.species_histogram = acc.species_histogram
		summaries[out_count] = summary
		out_count += 1
	}
	particle_life_blob_tracker_update(&sim.blob_tracker, summaries[:out_count])
	sim.runtime.last_analysis_read_frame = sim.runtime.last_analysis_frame
}

particle_life_dispatch_force_randomize :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	_ = cmd
	particle_life_force_matrix_upload_existing(sim, sim.gpu.uploaded_species_count)
	sim.runtime.pending_force_randomize = false
}

particle_life_dispatch_force_update :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.force_update_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Particle_Life_Force_Update_Params)sim.gpu.force_update_params_buffers[frame_slot].mapped
	params^ = {
		species_a = sim.runtime.pending_force_a,
		species_b = sim.runtime.pending_force_b,
		new_force = sim.runtime.pending_force_value,
		species_count = sim.gpu.uploaded_species_count,
	}
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.force_update_pipeline.pipeline)
	force_update_set := sim.gpu.force_update_sets[frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.force_update_pipeline.layout, 0, 1, &force_update_set, 0, nil)
	vk.CmdDispatch(cmd, 1, 1, 1)
	particle_life_force_barrier(sim, cmd)
	sim.runtime.pending_force_update = false
}

particle_life_gpu_step :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dt: f32) {
	if sim.runtime.force_matrix_dirty {
		particle_life_upload_force_matrix(sim)
	}
	if !particle_life_ensure_gpu_runtime(sim, vk_ctx) {
		return
	}
	sim.gpu.active_frame_slot = int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	particle_life_update_descriptors_for_slot(sim, vk_ctx, sim.gpu.active_frame_slot)
	target_analysis_axis := particle_life_target_analysis_grid_axis(sim.settings)
	grid_satisfies_target := particle_life_current_grid_satisfies_settings(sim)
	if sim.gpu.uploaded_particle_count != particle_life_target_particle_count(sim.settings) || sim.gpu.uploaded_species_count != particle_life_target_species_count(sim.settings) || !grid_satisfies_target || sim.gpu.analysis_grid_axis != target_analysis_axis {
		if sim.gpu.uploaded_particle_count != particle_life_target_particle_count(sim.settings) || sim.gpu.uploaded_species_count != particle_life_target_species_count(sim.settings) {
			particle_life_clear_preserved_particles(sim)
			sim.gpu.ready = false
		} else {
			particle_life_request_resource_rebuild(sim)
		}
		return
	}
	if sim.runtime.needs_reset {
		particle_life_dispatch_init(sim, cmd)
	}
	if sim.runtime.pending_force_randomize {
		particle_life_dispatch_force_randomize(sim, cmd)
	}
	if sim.runtime.pending_force_update {
		particle_life_dispatch_force_update(sim, cmd)
	}
	if sim.settings.paused {
		return
	}
	particle_life_write_frame_uniforms(sim, dt)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: grid clear")
	particle_life_dispatch_grid_clear(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: grid scatter")
	particle_life_dispatch_grid_scatter(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: force compute")
	particle_life_dispatch_binned_compute(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: collision solve/apply")
	particle_life_dispatch_collision_solver(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: copy scratch")
	particle_life_copy_scratch_to_particles(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
}

particle_life_draw_particles :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Graphics_Pipeline) {
	vk.CmdBindPipeline(cmd, .GRAPHICS, pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	frame_slot := sim.gpu.active_frame_slot
	sets := [3]vk.DescriptorSet{sim.gpu.sim_sets[frame_slot], sim.gpu.color_sets[frame_slot], sim.gpu.view_sets[frame_slot]}
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline.layout, 0, u32(len(sets)), raw_data(sets[:]), 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	particle_life_push_viewport_uniform_mode(vk_ctx, cmd, pipeline)
	vk.CmdDraw(cmd, 6, sim.gpu.uploaded_particle_count, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
}


particle_life_draw_infinite_tiles :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Graphics_Pipeline, width, height: f32) {
	bounds := particle_life_view_bounds(sim, width, height)
	tile_size := particle_life_world_size_for_viewport(width, height)
	tile_count := infinite_render_tile_count(sim.runtime.camera_zoom)
	center_x := i32(math.round(sim.runtime.camera_x / tile_size[0]))
	center_y := i32(math.round(sim.runtime.camera_y / tile_size[1]))
	half_tiles := i32(tile_count / 2)
	tile_start_x := center_x - half_tiles
	tile_start_y := center_y - half_tiles
	vk.CmdBindPipeline(cmd, .GRAPHICS, pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	frame_slot := sim.gpu.active_frame_slot
	sets := [3]vk.DescriptorSet{sim.gpu.sim_sets[frame_slot], sim.gpu.color_sets[frame_slot], sim.gpu.view_sets[frame_slot]}
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline.layout, 0, u32(len(sets)), raw_data(sets[:]), 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	for y: u32 = 0; y < tile_count; y += 1 {
		tile_y := tile_start_y + i32(y)
		for x: u32 = 0; x < tile_count; x += 1 {
			tile_x := tile_start_x + i32(x)
			tile_bounds := particle_life_tile_bounds_for_offset(bounds, tile_x, tile_y, tile_size)
			particle_life_push_viewport_bounds(vk_ctx, cmd, pipeline, tile_bounds)
			vk.CmdDraw(cmd, 6, sim.gpu.uploaded_particle_count, 0, 0)
			engine.vk_cmd_count_draw(vk_ctx)
		}
	}
	particle_life_push_viewport_uniform_mode(vk_ctx, cmd, pipeline)
}

particle_life_transition_trail_image :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, index: int, new_layout: vk.ImageLayout) {
	image := &sim.gpu.trail_images[index]
	if image.handle == vk.Image(0) || image.layout == new_layout {
		return
	}
	old_layout := image.layout
	src_access: vk.AccessFlags
	dst_access: vk.AccessFlags
	src_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	dst_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	#partial switch old_layout {
	case .UNDEFINED:
		#partial switch new_layout {
		case .COLOR_ATTACHMENT_OPTIMAL:
			dst_access = {.COLOR_ATTACHMENT_WRITE}
			dst_stage = {.COLOR_ATTACHMENT_OUTPUT}
		case .TRANSFER_DST_OPTIMAL:
			dst_access = {.TRANSFER_WRITE}
			dst_stage = {.TRANSFER}
		}
	case .COLOR_ATTACHMENT_OPTIMAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.COLOR_ATTACHMENT_WRITE}
			dst_access = {.SHADER_READ}
			src_stage = {.COLOR_ATTACHMENT_OUTPUT}
			dst_stage = {.FRAGMENT_SHADER}
		case .TRANSFER_SRC_OPTIMAL:
			src_access = {.COLOR_ATTACHMENT_WRITE}
			dst_access = {.TRANSFER_READ}
			src_stage = {.COLOR_ATTACHMENT_OUTPUT}
			dst_stage = {.TRANSFER}
		}
	case .SHADER_READ_ONLY_OPTIMAL:
		#partial switch new_layout {
		case .COLOR_ATTACHMENT_OPTIMAL:
			src_access = {.SHADER_READ}
			dst_access = {.COLOR_ATTACHMENT_WRITE}
			src_stage = {.FRAGMENT_SHADER}
			dst_stage = {.COLOR_ATTACHMENT_OUTPUT}
		}
	case .TRANSFER_SRC_OPTIMAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.TRANSFER_READ}
			dst_access = {.SHADER_READ}
			src_stage = {.TRANSFER}
			dst_stage = {.FRAGMENT_SHADER}
		case .COLOR_ATTACHMENT_OPTIMAL:
			src_access = {.TRANSFER_READ}
			dst_access = {.COLOR_ATTACHMENT_WRITE}
			src_stage = {.TRANSFER}
			dst_stage = {.COLOR_ATTACHMENT_OUTPUT}
		}
	case .TRANSFER_DST_OPTIMAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.TRANSFER_WRITE}
			dst_access = {.SHADER_READ}
			src_stage = {.TRANSFER}
			dst_stage = {.FRAGMENT_SHADER}
		}
	}
	barrier := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = src_access,
		dstAccessMask = dst_access,
		oldLayout = old_layout,
		newLayout = new_layout,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = image.handle,
		subresourceRange = {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
		},
	}
	vk.CmdPipelineBarrier(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	image.layout = new_layout
}

particle_life_update_fade_descriptor :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot, set_index, read_index: int) {
	params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.fade_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Fade_Params))}
	image_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = sim.gpu.trail_images[read_index].view}
	sampler_info := vk.DescriptorImageInfo{sampler = sim.gpu.trail_sampler}
	set := sim.gpu.fade_sets[frame_slot][set_index]
	writes := [3]vk.WriteDescriptorSet {
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 2, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
}

particle_life_update_background_descriptor :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.background_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Background_Params))}
	write := vk.WriteDescriptorSet {
		sType = .WRITE_DESCRIPTOR_SET,
		dstSet = sim.gpu.background_sets[frame_slot],
		dstBinding = 0,
		descriptorType = .UNIFORM_BUFFER,
		descriptorCount = 1,
		pBufferInfo = &params_info,
	}
	vk.UpdateDescriptorSets(vk_ctx.device, 1, &write, 0, nil)
}

particle_life_update_post_descriptors :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.post_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Post_Params))}
	camera_info := vk.DescriptorBufferInfo{buffer = sim.gpu.camera_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Camera))}
	sampler_info := vk.DescriptorImageInfo{sampler = sim.gpu.trail_sampler}
	for i in 0 ..< len(sim.gpu.trail_images) {
		image_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = sim.gpu.trail_images[i].view}
		set := sim.gpu.post_sets[frame_slot][i]
		writes := [4]vk.WriteDescriptorSet {
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 1, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &camera_info},
		}
		vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
	}
}

particle_life_destroy_trail_image :: proc(vk_ctx: ^engine.Vk_Context, image: ^Particle_Life_Trail_Image) {
	if image.framebuffer != vk.Framebuffer(0) {
		vk.DestroyFramebuffer(vk_ctx.device, image.framebuffer, nil)
	}
	if image.view != vk.ImageView(0) {
		vk.DestroyImageView(vk_ctx.device, image.view, nil)
	}
	if image.handle != vk.Image(0) {
		vk.DestroyImage(vk_ctx.device, image.handle, nil)
	}
	if image.memory != vk.DeviceMemory(0) {
		vk.FreeMemory(vk_ctx.device, image.memory, nil)
	}
	image^ = {}
}

particle_life_destroy_trail_targets :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	for i in 0 ..< len(sim.gpu.trail_images) {
		particle_life_destroy_trail_image(vk_ctx, &sim.gpu.trail_images[i])
	}
	sim.gpu.trail_width = 0
	sim.gpu.trail_height = 0
	sim.gpu.trail_initialized = false
	sim.gpu.trail_write_index = 0
}

particle_life_frame_slot_mask :: proc() -> u32 {
	return (u32(1) << u32(engine.MAX_FRAMES_IN_FLIGHT)) - 1
}

particle_life_collect_retired_trail_targets :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	bit := u32(1) << u32(frame_slot)
	for i in 0 ..< PARTICLE_LIFE_RETIRED_TRAIL_TARGET_CAP {
		retired := &sim.gpu.retired_trail_targets[i]
		if retired.pending_frame_slots == 0 {
			continue
		}
		retired.pending_frame_slots = retired.pending_frame_slots & (~bit)
		if retired.pending_frame_slots == 0 {
			for image_index in 0 ..< len(retired.images) {
				particle_life_destroy_trail_image(vk_ctx, &retired.images[image_index])
			}
		}
	}
}

particle_life_retire_trail_targets :: proc(sim: ^Particle_Life_Simulation) -> bool {
	if sim.gpu.trail_images[0].handle == vk.Image(0) && sim.gpu.trail_images[1].handle == vk.Image(0) {
		sim.gpu.trail_images = {}
		sim.gpu.trail_width = 0
		sim.gpu.trail_height = 0
		sim.gpu.trail_initialized = false
		sim.gpu.trail_write_index = 0
		return true
	}
	for i in 0 ..< PARTICLE_LIFE_RETIRED_TRAIL_TARGET_CAP {
		retired := &sim.gpu.retired_trail_targets[i]
		if retired.pending_frame_slots == 0 {
			retired.images = sim.gpu.trail_images
			retired.pending_frame_slots = particle_life_frame_slot_mask()
			sim.gpu.trail_images = {}
			sim.gpu.trail_width = 0
			sim.gpu.trail_height = 0
			sim.gpu.trail_initialized = false
			sim.gpu.trail_write_index = 0
			return true
		}
	}
	engine.log_warn("particle life: trail target retire slots exhausted")
	return false
}

particle_life_ensure_trail_targets :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	width := max(vk_ctx.swapchain_extent.width, u32(1))
	height := max(vk_ctx.swapchain_extent.height, u32(1))
	if sim.gpu.trail_width == width && sim.gpu.trail_height == height && sim.gpu.trail_images[0].handle != vk.Image(0) && sim.gpu.trail_images[1].handle != vk.Image(0) {
		return true
	}
	if !particle_life_retire_trail_targets(sim) {
		return false
	}
	for i in 0 ..< len(sim.gpu.trail_images) {
		if !particle_life_create_trail_image(sim, vk_ctx, i, width, height) {
			particle_life_destroy_trail_targets(sim, vk_ctx)
			return false
		}
	}
	sim.gpu.trail_width = width
	sim.gpu.trail_height = height
	frame_slot := int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	particle_life_update_background_descriptor(sim, vk_ctx, frame_slot)
	particle_life_update_post_descriptors(sim, vk_ctx, frame_slot)
	particle_life_collect_retired_trail_targets(sim, vk_ctx, frame_slot)
	return true
}

particle_life_post_trail_to_swapchain :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, source_index: int, ui: ^Ui_Render_Sink = nil) {
	cmd := frame.command_buffer
	frame_slot := int(frame.frame_index)
	particle_life_write_post_uniforms(sim)
	particle_life_update_post_descriptors(sim, vk_ctx, frame_slot)
	particle_life_transition_trail_image(sim, vk_ctx, cmd, source_index, .SHADER_READ_ONLY_OPTIMAL)
	engine.vk_cmd_begin_swapchain_render_pass(vk_ctx, frame, particle_life_clear_color(sim))
	extent := vk_ctx.swapchain_extent
	viewport := vk.Viewport{x = 0, y = 0, width = f32(extent.width), height = f32(extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = extent}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	// The trail target is already rendered in camera space. Present it once as a
	// fullscreen image; applying the infinite-tile camera transform here would
	// transform (and tile) the camera-space result a second time.
	vk.CmdBindPipeline(cmd, .GRAPHICS, sim.gpu.post_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	pipeline_layout := sim.gpu.post_pipeline.layout
	post_set := sim.gpu.post_sets[frame_slot][source_index]
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline_layout, 0, 1, &post_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDraw(cmd, 6, 1, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
	if ui != nil {
		engine.vk_cmd_label_begin(vk_ctx, cmd, "UI overlay")
		ui_render_sink_draw(ui, vk_ctx, cmd, vk_ctx.swapchain_extent)
		engine.vk_cmd_label_end(vk_ctx, cmd)
	}
	engine.vk_cmd_end_swapchain_render_pass(frame)
}

particle_life_gpu_present_trails :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, ui: ^Ui_Render_Sink = nil) {
	sim.gpu.active_frame_slot = int(frame.frame_index)
	particle_life_update_background_descriptor(sim, vk_ctx, sim.gpu.active_frame_slot)
	particle_life_update_post_descriptors(sim, vk_ctx, sim.gpu.active_frame_slot)
	particle_life_collect_retired_trail_targets(sim, vk_ctx, sim.gpu.active_frame_slot)
	particle_life_note_trail_camera(sim)
	cmd := frame.command_buffer
	write_index := int(sim.gpu.trail_write_index & 1)
	read_index := 1 - write_index
	particle_life_transition_trail_image(sim, vk_ctx, cmd, write_index, .COLOR_ATTACHMENT_OPTIMAL)
	if sim.settings.trails_enabled && sim.gpu.trail_initialized {
		particle_life_transition_trail_image(sim, vk_ctx, cmd, read_index, .SHADER_READ_ONLY_OPTIMAL)
		particle_life_write_fade_uniforms(sim)
		particle_life_update_fade_descriptor(sim, vk_ctx, sim.gpu.active_frame_slot, write_index, read_index)
	}

	clear_value := vk.ClearValue{color = {float32 = {0, 0, 0, 0}}}
	begin := vk.RenderPassBeginInfo {
		sType = .RENDER_PASS_BEGIN_INFO,
		renderPass = sim.gpu.trail_render_pass,
		framebuffer = sim.gpu.trail_images[write_index].framebuffer,
		renderArea = {offset = {0, 0}, extent = {sim.gpu.trail_width, sim.gpu.trail_height}},
		clearValueCount = 1,
		pClearValues = &clear_value,
	}
	vk.CmdBeginRenderPass(cmd, &begin, .INLINE)
	vk_ctx.command_shape.render_pass_count += 1
	viewport := vk.Viewport{x = 0, y = 0, width = f32(sim.gpu.trail_width), height = f32(sim.gpu.trail_height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = {sim.gpu.trail_width, sim.gpu.trail_height}}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	particle_life_write_background_uniforms(sim)
	particle_life_update_background_descriptor(sim, vk_ctx, sim.gpu.active_frame_slot)
	vk.CmdBindPipeline(cmd, .GRAPHICS, sim.gpu.background_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	background_set := sim.gpu.background_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, sim.gpu.background_pipeline.layout, 0, 1, &background_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDraw(cmd, 6, 1, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
	if sim.settings.trails_enabled && sim.gpu.trail_initialized {
		vk.CmdBindPipeline(cmd, .GRAPHICS, sim.gpu.fade_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		fade_set := sim.gpu.fade_sets[sim.gpu.active_frame_slot][write_index]
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, sim.gpu.fade_pipeline.layout, 0, 1, &fade_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 3, 1, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
	if sim.settings.infinite_tiles_enabled {
		particle_life_draw_infinite_tiles(sim, vk_ctx, cmd, &sim.gpu.trail_particle_pipeline, f32(sim.gpu.trail_width), f32(sim.gpu.trail_height))
	} else {
		particle_life_draw_particles(sim, vk_ctx, cmd, &sim.gpu.trail_particle_pipeline)
	}
	vk.CmdEndRenderPass(cmd)
	sim.gpu.trail_images[write_index].layout = .COLOR_ATTACHMENT_OPTIMAL
	sim.gpu.trail_initialized = true
	particle_life_post_trail_to_swapchain(sim, vk_ctx, frame, write_index, ui)
	sim.gpu.trail_write_index = u32(read_index)
}

particle_life_gpu_present :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, ui: ^Ui_Render_Sink = nil) {
	if !particle_life_ensure_gpu_runtime(sim, vk_ctx) {
		return
	}
	sim.gpu.active_frame_slot = int(frame.frame_index)
	if sim.settings.paused {
		particle_life_write_frame_uniforms(sim, 0)
	}
	particle_life_update_descriptors_for_slot(sim, vk_ctx, sim.gpu.active_frame_slot)
	extent := vk_ctx.swapchain_extent
	if extent.width == 0 || extent.height == 0 {
		return
	}
	cmd := frame.command_buffer
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: present")
	defer engine.vk_cmd_label_end(vk_ctx, cmd)
	if particle_life_ensure_trail_targets(sim, vk_ctx) {
		particle_life_gpu_present_trails(sim, vk_ctx, frame, ui)
		return
	}
	engine.vk_cmd_begin_swapchain_render_pass(vk_ctx, frame, particle_life_clear_color(sim))
	viewport := vk.Viewport{x = 0, y = 0, width = f32(extent.width), height = f32(extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = extent}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	if sim.settings.infinite_tiles_enabled {
		particle_life_draw_infinite_tiles(sim, vk_ctx, cmd, &sim.gpu.render_pipeline, f32(extent.width), f32(extent.height))
	} else {
		particle_life_draw_particles(sim, vk_ctx, cmd, &sim.gpu.render_pipeline)
	}
	if ui != nil {
		engine.vk_cmd_label_begin(vk_ctx, cmd, "UI overlay")
		ui_render_sink_draw(ui, vk_ctx, cmd, vk_ctx.swapchain_extent)
		engine.vk_cmd_label_end(vk_ctx, cmd)
	}
	engine.vk_cmd_end_swapchain_render_pass(frame)
}

particle_life_gpu_present_viewport :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !particle_life_ensure_gpu_runtime(sim, vk_ctx) {
		return
	}
	sim.gpu.active_frame_slot = int(frame.frame_index)
	if sim.settings.paused {
		particle_life_write_frame_uniforms(sim, 0)
	}
	particle_life_update_descriptors_for_slot(sim, vk_ctx, sim.gpu.active_frame_slot)
	particle_life_gpu_draw_prepared_viewport(sim, vk_ctx, frame, viewport, scissor)
}

particle_life_gpu_draw_prepared_viewport :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if sim.gpu.render_pipeline.pipeline == vk.Pipeline(0) {
		return
	}
	cmd := frame.command_buffer
	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(cmd, 0, 1, &local_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &local_scissor)
	if sim.settings.infinite_tiles_enabled {
		particle_life_draw_infinite_tiles(sim, vk_ctx, cmd, &sim.gpu.render_pipeline, viewport.width, viewport.height)
	} else {
		particle_life_draw_particles(sim, vk_ctx, cmd, &sim.gpu.render_pipeline)
	}
}


particle_life_destroy :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	particle_life_analysis_workspace_destroy(&sim.runtime.analysis)
	if vk_ctx == nil || vk_ctx.device == nil {
		sim.gpu = {}
		return
	}
	if sim.gpu.grid_clear_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.grid_clear_pipeline.pipeline, nil)
	}
	if sim.gpu.grid_clear_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.grid_clear_pipeline.layout, nil)
	}
	if sim.gpu.grid_scatter_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.grid_scatter_pipeline.pipeline, nil)
	}
	if sim.gpu.grid_scatter_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.grid_scatter_pipeline.layout, nil)
	}
	if sim.gpu.grid_scatter_predicted_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.grid_scatter_predicted_pipeline.pipeline, nil)
	}
	if sim.gpu.grid_scatter_predicted_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.grid_scatter_predicted_pipeline.layout, nil)
	}
	if sim.gpu.compute_binned_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.compute_binned_pipeline.pipeline, nil)
	}
	if sim.gpu.compute_binned_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.compute_binned_pipeline.layout, nil)
	}
	if sim.gpu.collision_solve_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.collision_solve_pipeline.pipeline, nil)
	}
	if sim.gpu.collision_solve_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.collision_solve_pipeline.layout, nil)
	}
	if sim.gpu.collision_apply_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.collision_apply_pipeline.pipeline, nil)
	}
	if sim.gpu.collision_apply_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.collision_apply_pipeline.layout, nil)
	}
	if sim.gpu.copy_scratch_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.copy_scratch_pipeline.pipeline, nil)
	}
	if sim.gpu.copy_scratch_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.copy_scratch_pipeline.layout, nil)
	}
	if sim.gpu.analysis_clear_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.analysis_clear_pipeline.pipeline, nil)
	}
	if sim.gpu.analysis_clear_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.analysis_clear_pipeline.layout, nil)
	}
	if sim.gpu.analysis_scatter_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.analysis_scatter_pipeline.pipeline, nil)
	}
	if sim.gpu.analysis_scatter_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.analysis_scatter_pipeline.layout, nil)
	}
	if sim.gpu.analysis_coherence_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.analysis_coherence_pipeline.pipeline, nil)
	}
	if sim.gpu.analysis_coherence_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.analysis_coherence_pipeline.layout, nil)
	}
	if sim.gpu.analysis_tile_label_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.analysis_tile_label_pipeline.pipeline, nil)
	}
	if sim.gpu.analysis_tile_label_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.analysis_tile_label_pipeline.layout, nil)
	}
	if sim.gpu.analysis_tile_merge_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.analysis_tile_merge_pipeline.pipeline, nil)
	}
	if sim.gpu.analysis_tile_merge_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.analysis_tile_merge_pipeline.layout, nil)
	}
	if sim.gpu.analysis_summarize_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.analysis_summarize_pipeline.pipeline, nil)
	}
	if sim.gpu.analysis_summarize_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.analysis_summarize_pipeline.layout, nil)
	}
	if sim.gpu.init_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.init_pipeline.pipeline, nil)
	}
	if sim.gpu.init_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.init_pipeline.layout, nil)
	}
	if sim.gpu.force_randomize_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.force_randomize_pipeline.pipeline, nil)
	}
	if sim.gpu.force_randomize_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.force_randomize_pipeline.layout, nil)
	}
	if sim.gpu.force_update_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.force_update_pipeline.pipeline, nil)
	}
	if sim.gpu.force_update_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.force_update_pipeline.layout, nil)
	}
	if sim.gpu.render_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.render_pipeline)
	}
	if sim.gpu.trail_particle_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.trail_particle_pipeline)
	}
	if sim.gpu.fade_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.fade_pipeline)
	}
	if sim.gpu.background_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.background_pipeline)
	}
	if sim.gpu.post_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.post_pipeline)
	}
	if sim.gpu.tiled_post_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.tiled_post_pipeline)
	}
	particle_life_destroy_trail_targets(sim, vk_ctx)
	for i in 0 ..< PARTICLE_LIFE_RETIRED_TRAIL_TARGET_CAP {
		for image_index in 0 ..< len(sim.gpu.retired_trail_targets[i].images) {
			particle_life_destroy_trail_image(vk_ctx, &sim.gpu.retired_trail_targets[i].images[image_index])
		}
	}
	if sim.gpu.trail_sampler != vk.Sampler(0) {
		vk.DestroySampler(vk_ctx.device, sim.gpu.trail_sampler, nil)
	}
	if sim.gpu.trail_render_pass != vk.RenderPass(0) {
		vk.DestroyRenderPass(vk_ctx.device, sim.gpu.trail_render_pass, nil)
	}
	if sim.gpu.descriptor_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, sim.gpu.descriptor_pool, nil)
	}
	if sim.gpu.fade_descriptor_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, sim.gpu.fade_descriptor_pool, nil)
	}
	if sim.gpu.sim_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.sim_set_layout, nil)
	}
	if sim.gpu.init_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.init_set_layout, nil)
	}
	if sim.gpu.color_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.color_set_layout, nil)
	}
	if sim.gpu.view_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.view_set_layout, nil)
	}
	if sim.gpu.fade_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.fade_set_layout, nil)
	}
	if sim.gpu.background_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.background_set_layout, nil)
	}
	if sim.gpu.post_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.post_set_layout, nil)
	}
	if sim.gpu.force_op_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.force_op_set_layout, nil)
	}
	if sim.gpu.analysis_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.analysis_set_layout, nil)
	}
	if sim.gpu.particle_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.particle_buffer)
	}
	if sim.gpu.particle_scratch_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.particle_scratch_buffer)
	}
	if sim.gpu.grid_heads_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.grid_heads_buffer)
	}
	if sim.gpu.particle_next_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.particle_next_buffer)
	}
	if sim.gpu.collision_correction_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.collision_correction_buffer)
	}
	if sim.gpu.analysis_cells_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_cells_buffer)
	}
	if sim.gpu.analysis_coherence_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_coherence_buffer)
	}
	if sim.gpu.analysis_labels_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_labels_buffer)
	}
	if sim.gpu.analysis_tile_components_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_tile_components_buffer)
	}
	if sim.gpu.analysis_parent_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_parent_buffer)
	}
	if sim.gpu.analysis_blob_summaries_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_blob_summaries_buffer)
	}
	if sim.gpu.analysis_blob_count_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_blob_count_buffer)
	}
	if sim.gpu.force_matrix_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.force_matrix_buffer)
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.init_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.fade_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.force_randomize_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.force_update_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.grid_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.collision_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.selected_blob_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.background_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.post_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.color_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.color_mode_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.camera_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.viewport_buffers[frame_slot])
	}
	if sim.gpu.grid_clear_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.grid_clear_shader_module)
	}
	if sim.gpu.grid_scatter_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.grid_scatter_shader_module)
	}
	if sim.gpu.grid_scatter_predicted_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.grid_scatter_predicted_shader_module)
	}
	if sim.gpu.compute_binned_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.compute_binned_shader_module)
	}
	if sim.gpu.collision_solve_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.collision_solve_shader_module)
	}
	if sim.gpu.collision_apply_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.collision_apply_shader_module)
	}
	if sim.gpu.copy_scratch_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.copy_scratch_shader_module)
	}
	if sim.gpu.init_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.init_shader_module)
	}
	if sim.gpu.vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.vertex_shader_module)
	}
	if sim.gpu.fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.fragment_shader_module)
	}
	if sim.gpu.fade_vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.fade_vertex_shader_module)
	}
	if sim.gpu.fade_fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.fade_fragment_shader_module)
	}
	if sim.gpu.force_randomize_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.force_randomize_shader_module)
	}
	if sim.gpu.force_update_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.force_update_shader_module)
	}
	if sim.gpu.analysis_clear_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.analysis_clear_shader_module)
	}
	if sim.gpu.analysis_scatter_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.analysis_scatter_shader_module)
	}
	if sim.gpu.analysis_coherence_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.analysis_coherence_shader_module)
	}
	if sim.gpu.analysis_tile_label_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.analysis_tile_label_shader_module)
	}
	if sim.gpu.analysis_tile_merge_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.analysis_tile_merge_shader_module)
	}
	if sim.gpu.analysis_summarize_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.analysis_summarize_shader_module)
	}
	if sim.gpu.background_vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.background_vertex_shader_module)
	}
	if sim.gpu.background_fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.background_fragment_shader_module)
	}
	if sim.gpu.post_vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.post_vertex_shader_module)
	}
	if sim.gpu.post_fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.post_fragment_shader_module)
	}
	if sim.gpu.infinite_present_vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.infinite_present_vertex_shader_module)
	}
	if sim.gpu.infinite_present_fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.infinite_present_fragment_shader_module)
	}
	width := sim.gpu.width
	height := sim.gpu.height
	sim.gpu = {width = width, height = height}
}
