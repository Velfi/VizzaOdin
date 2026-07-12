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
	grid_prefix_path := engine.shader_spirv_path(PARTICLE_LIFE_GRID_PREFIX_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_GRID_PREFIX_FALLBACK_SPV + ".spv")
	grid_prefix_blocks_path := engine.shader_spirv_path(PARTICLE_LIFE_GRID_PREFIX_BLOCKS_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_GRID_PREFIX_BLOCKS_FALLBACK_SPV + ".spv")
	grid_prefix_add_path := engine.shader_spirv_path(PARTICLE_LIFE_GRID_PREFIX_ADD_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_GRID_PREFIX_ADD_FALLBACK_SPV + ".spv")
	grid_index_scatter_path := engine.shader_spirv_path(PARTICLE_LIFE_GRID_INDEX_SCATTER_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_GRID_INDEX_SCATTER_FALLBACK_SPV + ".spv")
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
	if len(grid_clear_path) == 0 || len(grid_scatter_path) == 0 || len(grid_scatter_predicted_path) == 0 || len(grid_prefix_path) == 0 || len(grid_prefix_blocks_path) == 0 || len(grid_prefix_add_path) == 0 || len(grid_index_scatter_path) == 0 || len(compute_binned_path) == 0 || len(collision_solve_path) == 0 || len(collision_apply_path) == 0 || len(copy_scratch_path) == 0 || len(init_path) == 0 || len(vertex_path) == 0 || len(fragment_path) == 0 || len(fade_vertex_path) == 0 || len(fade_fragment_path) == 0 || len(force_randomize_path) == 0 || len(force_update_path) == 0 || len(analysis_clear_path) == 0 || len(analysis_scatter_path) == 0 || len(analysis_coherence_path) == 0 || len(analysis_tile_label_path) == 0 || len(analysis_tile_merge_path) == 0 || len(analysis_summarize_path) == 0 || len(background_vertex_path) == 0 || len(background_fragment_path) == 0 || len(post_vertex_path) == 0 || len(post_fragment_path) == 0 || len(infinite_present_vertex_path) == 0 || len(infinite_present_fragment_path) == 0 {
		return false
	}
	if !os.exists(grid_clear_path) || !os.exists(grid_scatter_path) || !os.exists(grid_scatter_predicted_path) || !os.exists(grid_prefix_path) || !os.exists(grid_index_scatter_path) || !os.exists(compute_binned_path) || !os.exists(collision_solve_path) || !os.exists(collision_apply_path) || !os.exists(copy_scratch_path) || !os.exists(init_path) || !os.exists(vertex_path) || !os.exists(fragment_path) || !os.exists(fade_vertex_path) || !os.exists(fade_fragment_path) || !os.exists(force_randomize_path) || !os.exists(force_update_path) || !os.exists(analysis_clear_path) || !os.exists(analysis_scatter_path) || !os.exists(analysis_coherence_path) || !os.exists(analysis_tile_label_path) || !os.exists(analysis_tile_merge_path) || !os.exists(analysis_summarize_path) || !os.exists(background_vertex_path) || !os.exists(background_fragment_path) || !os.exists(post_vertex_path) || !os.exists(post_fragment_path) || !os.exists(infinite_present_vertex_path) || !os.exists(infinite_present_fragment_path) {
		return false
	}
	particle_life_gpu(sim).grid_clear_shader_spirv_path = grid_clear_path
	particle_life_gpu(sim).grid_scatter_shader_spirv_path = grid_scatter_path
	particle_life_gpu(sim).grid_scatter_predicted_shader_spirv_path = grid_scatter_predicted_path
	particle_life_gpu(sim).grid_prefix_shader_spirv_path = grid_prefix_path
	particle_life_gpu(sim).grid_prefix_blocks_shader_spirv_path = grid_prefix_blocks_path
	particle_life_gpu(sim).grid_prefix_add_shader_spirv_path = grid_prefix_add_path
	particle_life_gpu(sim).grid_index_scatter_shader_spirv_path = grid_index_scatter_path
	particle_life_gpu(sim).compute_binned_shader_spirv_path = compute_binned_path
	particle_life_gpu(sim).collision_solve_shader_spirv_path = collision_solve_path
	particle_life_gpu(sim).collision_apply_shader_spirv_path = collision_apply_path
	particle_life_gpu(sim).copy_scratch_shader_spirv_path = copy_scratch_path
	particle_life_gpu(sim).init_shader_spirv_path = init_path
	particle_life_gpu(sim).vertex_shader_spirv_path = vertex_path
	particle_life_gpu(sim).fragment_shader_spirv_path = fragment_path
	particle_life_gpu(sim).fade_vertex_shader_spirv_path = fade_vertex_path
	particle_life_gpu(sim).fade_fragment_shader_spirv_path = fade_fragment_path
	particle_life_gpu(sim).force_randomize_shader_spirv_path = force_randomize_path
	particle_life_gpu(sim).force_update_shader_spirv_path = force_update_path
	particle_life_gpu(sim).analysis_clear_shader_spirv_path = analysis_clear_path
	particle_life_gpu(sim).analysis_scatter_shader_spirv_path = analysis_scatter_path
	particle_life_gpu(sim).analysis_coherence_shader_spirv_path = analysis_coherence_path
	particle_life_gpu(sim).analysis_tile_label_shader_spirv_path = analysis_tile_label_path
	particle_life_gpu(sim).analysis_tile_merge_shader_spirv_path = analysis_tile_merge_path
	particle_life_gpu(sim).analysis_summarize_shader_spirv_path = analysis_summarize_path
	particle_life_gpu(sim).background_vertex_shader_spirv_path = background_vertex_path
	particle_life_gpu(sim).background_fragment_shader_spirv_path = background_fragment_path
	particle_life_gpu(sim).post_vertex_shader_spirv_path = post_vertex_path
	particle_life_gpu(sim).post_fragment_shader_spirv_path = post_fragment_path
	particle_life_gpu(sim).infinite_present_vertex_shader_spirv_path = infinite_present_vertex_path
	particle_life_gpu(sim).infinite_present_fragment_shader_spirv_path = infinite_present_fragment_path
	return true
}

particle_life_ensure_gpu_runtime :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if particle_life_gpu(sim).ready && (!sim.runtime.render_ready || particle_life_gpu(sim).width != sim.runtime.render_width || particle_life_gpu(sim).height != sim.runtime.render_height) {
		particle_life_destroy(sim, vk_ctx)
	}
	if particle_life_gpu(sim).ready {
		return true
	}
	particle_life_gpu(sim).width = sim.runtime.render_width
	particle_life_gpu(sim).height = sim.runtime.render_height
	if particle_life_gpu(sim).grid_clear_shader_module.handle != 0 || particle_life_gpu(sim).grid_scatter_shader_module.handle != 0 || particle_life_gpu(sim).grid_scatter_predicted_shader_module.handle != 0 || particle_life_gpu(sim).compute_binned_shader_module.handle != 0 || particle_life_gpu(sim).collision_solve_shader_module.handle != 0 || particle_life_gpu(sim).collision_apply_shader_module.handle != 0 || particle_life_gpu(sim).copy_scratch_shader_module.handle != 0 || particle_life_gpu(sim).init_shader_module.handle != 0 || particle_life_gpu(sim).vertex_shader_module.handle != 0 || particle_life_gpu(sim).fragment_shader_module.handle != 0 || particle_life_gpu(sim).fade_vertex_shader_module.handle != 0 || particle_life_gpu(sim).fade_fragment_shader_module.handle != 0 || particle_life_gpu(sim).force_randomize_shader_module.handle != 0 || particle_life_gpu(sim).force_update_shader_module.handle != 0 || particle_life_gpu(sim).analysis_clear_shader_module.handle != 0 || particle_life_gpu(sim).analysis_scatter_shader_module.handle != 0 || particle_life_gpu(sim).analysis_coherence_shader_module.handle != 0 || particle_life_gpu(sim).analysis_tile_label_shader_module.handle != 0 || particle_life_gpu(sim).analysis_tile_merge_shader_module.handle != 0 || particle_life_gpu(sim).analysis_summarize_shader_module.handle != 0 || particle_life_gpu(sim).background_vertex_shader_module.handle != 0 || particle_life_gpu(sim).background_fragment_shader_module.handle != 0 || particle_life_gpu(sim).post_vertex_shader_module.handle != 0 || particle_life_gpu(sim).post_fragment_shader_module.handle != 0 || particle_life_gpu(sim).infinite_present_vertex_shader_module.handle != 0 || particle_life_gpu(sim).infinite_present_fragment_shader_module.handle != 0 {
		_ = vk.DeviceWaitIdle(vk_ctx.device)
		particle_life_destroy(sim, vk_ctx)
	}
	if !particle_life_ensure_gpu_paths(sim) {
		engine.log_error("particle_life_ensure_gpu_runtime: shader paths unavailable")
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).grid_clear_shader_spirv_path, &particle_life_gpu(sim).grid_clear_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: grid clear shader load failed path=", particle_life_gpu(sim).grid_clear_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).grid_scatter_shader_spirv_path, &particle_life_gpu(sim).grid_scatter_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: grid scatter shader load failed path=", particle_life_gpu(sim).grid_scatter_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).grid_scatter_predicted_shader_spirv_path, &particle_life_gpu(sim).grid_scatter_predicted_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: predicted grid scatter shader load failed path=", particle_life_gpu(sim).grid_scatter_predicted_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).grid_prefix_shader_spirv_path, &particle_life_gpu(sim).grid_prefix_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: grid prefix shader load failed path=", particle_life_gpu(sim).grid_prefix_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).grid_prefix_blocks_shader_spirv_path, &particle_life_gpu(sim).grid_prefix_blocks_shader_module) {
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).grid_prefix_add_shader_spirv_path, &particle_life_gpu(sim).grid_prefix_add_shader_module) {
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).grid_index_scatter_shader_spirv_path, &particle_life_gpu(sim).grid_index_scatter_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: grid index scatter shader load failed path=", particle_life_gpu(sim).grid_index_scatter_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).compute_binned_shader_spirv_path, &particle_life_gpu(sim).compute_binned_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: compute binned shader load failed path=", particle_life_gpu(sim).compute_binned_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).collision_solve_shader_spirv_path, &particle_life_gpu(sim).collision_solve_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: collision solve shader load failed path=", particle_life_gpu(sim).collision_solve_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).collision_apply_shader_spirv_path, &particle_life_gpu(sim).collision_apply_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: collision apply shader load failed path=", particle_life_gpu(sim).collision_apply_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).copy_scratch_shader_spirv_path, &particle_life_gpu(sim).copy_scratch_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: copy scratch shader load failed path=", particle_life_gpu(sim).copy_scratch_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).init_shader_spirv_path, &particle_life_gpu(sim).init_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: init shader load failed path=", particle_life_gpu(sim).init_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).vertex_shader_spirv_path, &particle_life_gpu(sim).vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: vertex shader load failed path=", particle_life_gpu(sim).vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).fragment_shader_spirv_path, &particle_life_gpu(sim).fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: fragment shader load failed path=", particle_life_gpu(sim).fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).fade_vertex_shader_spirv_path, &particle_life_gpu(sim).fade_vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: fade vertex shader load failed path=", particle_life_gpu(sim).fade_vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).fade_fragment_shader_spirv_path, &particle_life_gpu(sim).fade_fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: fade fragment shader load failed path=", particle_life_gpu(sim).fade_fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).force_randomize_shader_spirv_path, &particle_life_gpu(sim).force_randomize_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: force randomize shader load failed path=", particle_life_gpu(sim).force_randomize_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).force_update_shader_spirv_path, &particle_life_gpu(sim).force_update_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: force update shader load failed path=", particle_life_gpu(sim).force_update_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).analysis_clear_shader_spirv_path, &particle_life_gpu(sim).analysis_clear_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis clear shader load failed path=", particle_life_gpu(sim).analysis_clear_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).analysis_scatter_shader_spirv_path, &particle_life_gpu(sim).analysis_scatter_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis scatter shader load failed path=", particle_life_gpu(sim).analysis_scatter_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).analysis_coherence_shader_spirv_path, &particle_life_gpu(sim).analysis_coherence_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis coherence shader load failed path=", particle_life_gpu(sim).analysis_coherence_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).analysis_tile_label_shader_spirv_path, &particle_life_gpu(sim).analysis_tile_label_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis tile label shader load failed path=", particle_life_gpu(sim).analysis_tile_label_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).analysis_tile_merge_shader_spirv_path, &particle_life_gpu(sim).analysis_tile_merge_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis tile merge shader load failed path=", particle_life_gpu(sim).analysis_tile_merge_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).analysis_summarize_shader_spirv_path, &particle_life_gpu(sim).analysis_summarize_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis summarize shader load failed path=", particle_life_gpu(sim).analysis_summarize_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).background_vertex_shader_spirv_path, &particle_life_gpu(sim).background_vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: background vertex shader load failed path=", particle_life_gpu(sim).background_vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).background_fragment_shader_spirv_path, &particle_life_gpu(sim).background_fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: background fragment shader load failed path=", particle_life_gpu(sim).background_fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).post_vertex_shader_spirv_path, &particle_life_gpu(sim).post_vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: post vertex shader load failed path=", particle_life_gpu(sim).post_vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).post_fragment_shader_spirv_path, &particle_life_gpu(sim).post_fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: post fragment shader load failed path=", particle_life_gpu(sim).post_fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).infinite_present_vertex_shader_spirv_path, &particle_life_gpu(sim).infinite_present_vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: infinite present vertex shader load failed path=", particle_life_gpu(sim).infinite_present_vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, particle_life_gpu(sim).infinite_present_fragment_shader_spirv_path, &particle_life_gpu(sim).infinite_present_fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: infinite present fragment shader load failed path=", particle_life_gpu(sim).infinite_present_fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !particle_life_create_resources(sim, vk_ctx) {
		engine.log_error("particle_life_ensure_gpu_runtime: resource creation failed")
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	particle_life_gpu(sim).ready = true
	sim.runtime.render_ready = true
	return true
}

particle_life_create_resources :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	particle_count := particle_life_target_particle_count(sim.settings^)
	species_count := particle_life_target_species_count(sim.settings^)
	restore_particles := !sim.runtime.needs_reset && len(sim.runtime.preserved_particles) == int(particle_count)
	world_size := particle_life_world_size(sim)
	grid_width, grid_height := particle_life_target_grid_dimensions(sim.settings^, world_size)
	collision_grid_width, collision_grid_height := particle_life_target_collision_grid_dimensions(sim.settings^, world_size)
	// Grid heads are tiny relative to particle storage. Reserve the maximum once
	// so influence-range and particle-size edits only change active dimensions.
	grid_cells := u32(PARTICLE_LIFE_MAX_GRID_AXIS * PARTICLE_LIFE_MAX_GRID_AXIS)
	neighbor_radius_cells := particle_life_target_neighbor_radius_cells(sim.settings^, grid_width, grid_height, world_size)
	analysis_axis := particle_life_target_analysis_grid_axis(sim.settings^)
	analysis_cells := analysis_axis * analysis_axis
	analysis_tile_count := particle_life_analysis_tile_count_for_axis(analysis_axis)
	analysis_tile_components := analysis_tile_count * analysis_tile_count * PARTICLE_LIFE_ANALYSIS_TILE_SIZE * PARTICLE_LIFE_ANALYSIS_TILE_SIZE
	particle_size := vk.DeviceSize(size_of(Particle_Life_Particle) * int(particle_count))
	if !engine.vk_create_host_buffer(vk_ctx, particle_size, {.STORAGE_BUFFER, .VERTEX_BUFFER, .TRANSFER_DST}, &particle_life_gpu(sim).particle_buffer) {
		engine.log_error("particle_life_create_resources: particle buffer failed bytes=", particle_size)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, particle_size, {.STORAGE_BUFFER, .TRANSFER_SRC, .TRANSFER_DST}, &particle_life_gpu(sim).particle_scratch_buffer) {
		engine.log_error("particle_life_create_resources: particle scratch buffer failed bytes=", particle_size)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of([2]f32) * int(particle_count)), {.STORAGE_BUFFER, .TRANSFER_DST}, &particle_life_gpu(sim).force_cache_buffer) {
		engine.log_error("particle_life_create_resources: force cache buffer failed")
		return false
	}
	params_size := vk.DeviceSize(size_of(Particle_Life_Params))
	init_params_size := vk.DeviceSize(size_of(Particle_Life_Init_Params))
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, params_size, {.UNIFORM_BUFFER}, &particle_life_gpu(sim).params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, init_params_size, {.UNIFORM_BUFFER}, &particle_life_gpu(sim).init_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Fade_Params)), {.UNIFORM_BUFFER}, &particle_life_gpu(sim).fade_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Force_Randomize_Params)), {.UNIFORM_BUFFER}, &particle_life_gpu(sim).force_randomize_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Force_Update_Params)), {.UNIFORM_BUFFER}, &particle_life_gpu(sim).force_update_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Grid_Params)), {.UNIFORM_BUFFER}, &particle_life_gpu(sim).grid_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Grid_Params)), {.UNIFORM_BUFFER}, &particle_life_gpu(sim).collision_grid_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Collision_Params)), {.UNIFORM_BUFFER}, &particle_life_gpu(sim).collision_params_buffers[frame_slot]) {
			return false
		}
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(grid_cells)), {.STORAGE_BUFFER}, &particle_life_gpu(sim).grid_heads_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(particle_count)), {.STORAGE_BUFFER}, &particle_life_gpu(sim).particle_next_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(grid_cells)), {.STORAGE_BUFFER}, &particle_life_gpu(sim).grid_offsets_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(grid_cells)), {.STORAGE_BUFFER}, &particle_life_gpu(sim).grid_cursors_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * 256), {.STORAGE_BUFFER}, &particle_life_gpu(sim).grid_block_sums_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of([2]f32) * int(particle_count)), {.STORAGE_BUFFER}, &particle_life_gpu(sim).collision_correction_buffer) {
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Analysis_Params)), {.UNIFORM_BUFFER}, &particle_life_gpu(sim).analysis_params_buffers[frame_slot]) {
			return false
		}
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Analysis_Gpu_Cell) * int(analysis_cells)), {.STORAGE_BUFFER}, &particle_life_gpu(sim).analysis_cells_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(f32) * int(analysis_cells)), {.STORAGE_BUFFER}, &particle_life_gpu(sim).analysis_coherence_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(analysis_cells)), {.STORAGE_BUFFER}, &particle_life_gpu(sim).analysis_labels_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(analysis_tile_components)), {.STORAGE_BUFFER}, &particle_life_gpu(sim).analysis_tile_components_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(analysis_cells)), {.STORAGE_BUFFER}, &particle_life_gpu(sim).analysis_parent_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Blob_Accumulator) * PARTICLE_LIFE_ANALYSIS_MAX_BLOBS), {.STORAGE_BUFFER}, &particle_life_gpu(sim).analysis_blob_summaries_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32)), {.STORAGE_BUFFER}, &particle_life_gpu(sim).analysis_blob_count_buffer) {
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Selected_Blob_Params)), {.UNIFORM_BUFFER}, &particle_life_gpu(sim).selected_blob_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Background_Params)), {.UNIFORM_BUFFER}, &particle_life_gpu(sim).background_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Post_Params)), {.UNIFORM_BUFFER}, &particle_life_gpu(sim).post_params_buffers[frame_slot]) {
			return false
		}
	}
	force_size := vk.DeviceSize(size_of(f32) * int(species_count * species_count))
	if !engine.vk_create_host_buffer(vk_ctx, force_size, {.STORAGE_BUFFER}, &particle_life_gpu(sim).force_matrix_buffer) {
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Species_Colors)), {.UNIFORM_BUFFER}, &particle_life_gpu(sim).color_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Color_Mode_Params)), {.UNIFORM_BUFFER}, &particle_life_gpu(sim).color_mode_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Camera)), {.UNIFORM_BUFFER}, &particle_life_gpu(sim).camera_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Viewport)), {.UNIFORM_BUFFER}, &particle_life_gpu(sim).viewport_buffers[frame_slot]) {
			return false
		}
	}
	particle_life_gpu(sim).uploaded_particle_count = particle_count
	particle_life_gpu(sim).uploaded_species_count = species_count
	sim.runtime.rendered_particle_count = particle_count
	sim.runtime.rendered_species_count = species_count
	particle_life_gpu(sim).grid_width = grid_width
	particle_life_gpu(sim).grid_height = grid_height
	particle_life_gpu(sim).neighbor_radius_cells = neighbor_radius_cells
	particle_life_gpu(sim).collision_grid_width = collision_grid_width
	particle_life_gpu(sim).collision_grid_height = collision_grid_height
	particle_life_gpu(sim).grid_cell_capacity = grid_cells
	particle_life_gpu(sim).analysis_grid_axis = analysis_axis
	particle_life_gpu(sim).analysis_tile_count = analysis_tile_count
	particle_life_upload_force_matrix(sim)
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		particle_life_gpu(sim).active_frame_slot = frame_slot
		particle_life_upload_static_uniforms(sim)
		particle_life_write_init_uniforms(sim)
		particle_life_write_frame_uniforms(sim, 0)
		particle_life_write_grid_uniforms(sim)
		particle_life_write_collision_grid_uniforms(sim)
		particle_life_write_collision_uniforms(sim)
		particle_life_write_analysis_uniforms(sim)
		particle_life_write_fade_uniforms(sim)
		particle_life_write_background_uniforms(sim)
		particle_life_write_post_uniforms(sim)
	}
	if restore_particles && particle_life_gpu(sim).particle_buffer.mapped != nil {
		particles := (cast([^]Particle_Life_Particle)particle_life_gpu(sim).particle_buffer.mapped)[:particle_count]
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
	sim_bindings := [13]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE, .VERTEX}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE, .VERTEX}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 5, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 6, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 7, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 8, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 9, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 10, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 11, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 12, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	sim_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(sim_bindings)),
		pBindings = raw_data(sim_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &sim_layout_info, nil, &particle_life_gpu(sim).sim_set_layout) != .SUCCESS {
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
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &init_layout_info, nil, &particle_life_gpu(sim).init_set_layout) != .SUCCESS {
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
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &color_layout_info, nil, &particle_life_gpu(sim).color_set_layout) != .SUCCESS {
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
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &view_layout_info, nil, &particle_life_gpu(sim).view_set_layout) != .SUCCESS {
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
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &force_op_layout_info, nil, &particle_life_gpu(sim).force_op_set_layout) != .SUCCESS {
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
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &analysis_layout_info, nil, &particle_life_gpu(sim).analysis_set_layout) != .SUCCESS {
		return false
	}

	pool_sizes := [2]vk.DescriptorPoolSize {
		{type = .STORAGE_BUFFER, descriptorCount = 32 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .UNIFORM_BUFFER, descriptorCount = 16 * engine.MAX_FRAMES_IN_FLIGHT},
	}
	pool_info := vk.DescriptorPoolCreateInfo {
		sType = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = u32(len(pool_sizes)),
		pPoolSizes = raw_data(pool_sizes[:]),
		maxSets = 8 * engine.MAX_FRAMES_IN_FLIGHT,
	}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &particle_life_gpu(sim).descriptor_pool) != .SUCCESS {
		return false
	}

	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		layouts := [8]vk.DescriptorSetLayout{particle_life_gpu(sim).sim_set_layout, particle_life_gpu(sim).sim_set_layout, particle_life_gpu(sim).init_set_layout, particle_life_gpu(sim).color_set_layout, particle_life_gpu(sim).view_set_layout, particle_life_gpu(sim).force_op_set_layout, particle_life_gpu(sim).force_op_set_layout, particle_life_gpu(sim).analysis_set_layout}
		sets := [8]vk.DescriptorSet{}
		alloc := vk.DescriptorSetAllocateInfo {
			sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
			descriptorPool = particle_life_gpu(sim).descriptor_pool,
			descriptorSetCount = u32(len(layouts)),
			pSetLayouts = raw_data(layouts[:]),
		}
		if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(sets[:])) != .SUCCESS {
			return false
		}
		particle_life_gpu(sim).sim_sets[frame_slot] = sets[0]
		particle_life_gpu(sim).collision_sets[frame_slot] = sets[1]
		particle_life_gpu(sim).init_sets[frame_slot] = sets[2]
		particle_life_gpu(sim).color_sets[frame_slot] = sets[3]
		particle_life_gpu(sim).view_sets[frame_slot] = sets[4]
		particle_life_gpu(sim).force_randomize_sets[frame_slot] = sets[5]
		particle_life_gpu(sim).force_update_sets[frame_slot] = sets[6]
		particle_life_gpu(sim).analysis_sets[frame_slot] = sets[7]
	}
	particle_life_update_descriptors(sim, vk_ctx)
	return true
}

particle_life_create_init_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = &particle_life_gpu(sim).init_set_layout,
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &particle_life_gpu(sim).init_pipeline.layout) != .SUCCESS {
		return false
	}
	stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.COMPUTE},
		module = particle_life_gpu(sim).init_shader_module.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	info := vk.ComputePipelineCreateInfo {
		sType = .COMPUTE_PIPELINE_CREATE_INFO,
		stage = stage,
		layout = particle_life_gpu(sim).init_pipeline.layout,
	}
	if vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &particle_life_gpu(sim).init_pipeline.pipeline) != .SUCCESS {
		return false
	}
	return true
}

particle_life_create_compute_pipeline_for_module :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, shader: engine.Vk_Shader_Module, pipeline: ^engine.Vk_Compute_Pipeline) -> bool {
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = &particle_life_gpu(sim).sim_set_layout,
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
