package render_vk

import engine "../engine"
import uifw "../ui"

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import vk "vendor:vulkan"

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
	vk.CmdBindPipeline(cmd, .GRAPHICS, particle_life_gpu(sim).post_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	pipeline_layout := particle_life_gpu(sim).post_pipeline.layout
	post_set := particle_life_gpu(sim).post_sets[frame_slot][source_index]
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
	particle_life_gpu(sim).active_frame_slot = int(frame.frame_index)
	particle_life_update_background_descriptor(sim, vk_ctx, particle_life_gpu(sim).active_frame_slot)
	particle_life_update_post_descriptors(sim, vk_ctx, particle_life_gpu(sim).active_frame_slot)
	particle_life_collect_retired_trail_targets(sim, vk_ctx, particle_life_gpu(sim).active_frame_slot)
	particle_life_note_trail_camera(sim)
	cmd := frame.command_buffer
	write_index := int(particle_life_gpu(sim).trail_write_index & 1)
	read_index := 1 - write_index
	particle_life_transition_trail_image(sim, vk_ctx, cmd, write_index, .COLOR_ATTACHMENT_OPTIMAL)
	if sim.settings.trails_enabled && particle_life_gpu(sim).trail_initialized {
		particle_life_transition_trail_image(sim, vk_ctx, cmd, read_index, .SHADER_READ_ONLY_OPTIMAL)
		particle_life_write_fade_uniforms(sim)
		particle_life_update_fade_descriptor(sim, vk_ctx, particle_life_gpu(sim).active_frame_slot, write_index, read_index)
	}

	clear_value := vk.ClearValue{color = {float32 = {0, 0, 0, 0}}}
	engine.vk_cmd_begin_rendering(vk_ctx, cmd, particle_life_gpu(sim).trail_images[write_index].view, {particle_life_gpu(sim).trail_width, particle_life_gpu(sim).trail_height}, .COLOR_ATTACHMENT_OPTIMAL, .CLEAR, .STORE, clear_value)
	viewport := vk.Viewport{x = 0, y = 0, width = f32(particle_life_gpu(sim).trail_width), height = f32(particle_life_gpu(sim).trail_height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = {particle_life_gpu(sim).trail_width, particle_life_gpu(sim).trail_height}}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	particle_life_write_background_uniforms(sim)
	particle_life_update_background_descriptor(sim, vk_ctx, particle_life_gpu(sim).active_frame_slot)
	vk.CmdBindPipeline(cmd, .GRAPHICS, particle_life_gpu(sim).background_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	background_set := particle_life_gpu(sim).background_sets[particle_life_gpu(sim).active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, particle_life_gpu(sim).background_pipeline.layout, 0, 1, &background_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDraw(cmd, 6, 1, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
	if sim.settings.trails_enabled && particle_life_gpu(sim).trail_initialized {
		vk.CmdBindPipeline(cmd, .GRAPHICS, particle_life_gpu(sim).fade_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		fade_set := particle_life_gpu(sim).fade_sets[particle_life_gpu(sim).active_frame_slot][write_index]
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, particle_life_gpu(sim).fade_pipeline.layout, 0, 1, &fade_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 3, 1, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
	if sim.settings.infinite_tiles_enabled {
		particle_life_draw_infinite_tiles(sim, vk_ctx, cmd, &particle_life_gpu(sim).trail_particle_pipeline, f32(particle_life_gpu(sim).trail_width), f32(particle_life_gpu(sim).trail_height))
	} else {
		particle_life_draw_particles(sim, vk_ctx, cmd, &particle_life_gpu(sim).trail_particle_pipeline)
	}
	engine.vk_cmd_end_rendering(cmd)
	particle_life_gpu(sim).trail_images[write_index].layout = .COLOR_ATTACHMENT_OPTIMAL
	particle_life_gpu(sim).trail_initialized = true
	particle_life_post_trail_to_swapchain(sim, vk_ctx, frame, write_index, ui)
	particle_life_gpu(sim).trail_write_index = u32(read_index)
}

particle_life_gpu_present :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, ui: ^Ui_Render_Sink = nil) {
	if !particle_life_ensure_gpu_runtime(sim, vk_ctx) {
		return
	}
	particle_life_gpu(sim).active_frame_slot = int(frame.frame_index)
	if sim.settings.paused {
		particle_life_write_frame_uniforms(sim, 0)
	}
	particle_life_update_descriptors_for_slot(sim, vk_ctx, particle_life_gpu(sim).active_frame_slot)
	extent := vk_ctx.swapchain_extent
	if extent.width == 0 || extent.height == 0 {
		return
	}
	cmd := frame.command_buffer
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: present")
	defer engine.vk_cmd_label_end(vk_ctx, cmd)
	post_is_neutral := sim.settings.brightness == 1 && sim.settings.contrast == 1 && sim.settings.saturation == 1 && sim.settings.gamma == 1
	if sim.settings.trails_enabled || !post_is_neutral {
		if particle_life_ensure_trail_targets(sim, vk_ctx) {
			particle_life_gpu_present_trails(sim, vk_ctx, frame, ui)
			return
		}
	}
	engine.vk_cmd_begin_swapchain_render_pass(vk_ctx, frame, particle_life_clear_color(sim))
	viewport := vk.Viewport{x = 0, y = 0, width = f32(extent.width), height = f32(extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = extent}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	if sim.settings.infinite_tiles_enabled {
		particle_life_draw_infinite_tiles(sim, vk_ctx, cmd, &particle_life_gpu(sim).render_pipeline, f32(extent.width), f32(extent.height))
	} else {
		particle_life_draw_particles(sim, vk_ctx, cmd, &particle_life_gpu(sim).render_pipeline)
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
	particle_life_gpu(sim).active_frame_slot = int(frame.frame_index)
	if sim.settings.paused {
		particle_life_write_frame_uniforms(sim, 0)
	}
	particle_life_update_descriptors_for_slot(sim, vk_ctx, particle_life_gpu(sim).active_frame_slot)
	particle_life_gpu_draw_prepared_viewport(sim, vk_ctx, frame, viewport, scissor)
}

particle_life_gpu_draw_prepared_viewport :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if particle_life_gpu(sim).render_pipeline.pipeline == vk.Pipeline(0) {
		return
	}
	cmd := frame.command_buffer
	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(cmd, 0, 1, &local_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &local_scissor)
	if sim.settings.infinite_tiles_enabled {
		particle_life_draw_infinite_tiles(sim, vk_ctx, cmd, &particle_life_gpu(sim).render_pipeline, viewport.width, viewport.height)
	} else {
		particle_life_draw_particles(sim, vk_ctx, cmd, &particle_life_gpu(sim).render_pipeline)
	}
}




particle_life_destroy :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	particle_life_analysis_workspace_destroy(&sim.runtime.analysis)
	sim.runtime.render_ready = false
	sim.runtime.rendered_particle_count = 0
	sim.runtime.rendered_species_count = 0
	if vk_ctx == nil || vk_ctx.device == nil {
		particle_life_gpu(sim)^ = {}
		return
	}
	width := particle_life_gpu(sim).width
	height := particle_life_gpu(sim).height
	particle_life_destroy_compute_pipelines(sim, vk_ctx)
	particle_life_destroy_graphics_and_trails(sim, vk_ctx)
	particle_life_destroy_descriptor_state(sim, vk_ctx)
	particle_life_destroy_buffers(sim, vk_ctx)
	particle_life_destroy_shader_modules(sim, vk_ctx)
	particle_life_gpu(sim)^ = {width = width, height = height}
}

particle_life_destroy_compute_pipelines :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	if particle_life_gpu(sim).grid_clear_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).grid_clear_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).grid_clear_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).grid_clear_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).grid_scatter_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).grid_scatter_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).grid_scatter_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).grid_scatter_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).grid_scatter_predicted_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).grid_scatter_predicted_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).grid_scatter_predicted_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).grid_scatter_predicted_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).grid_prefix_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).grid_prefix_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).grid_prefix_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).grid_prefix_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).grid_prefix_blocks_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).grid_prefix_blocks_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).grid_prefix_blocks_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).grid_prefix_blocks_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).grid_prefix_add_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).grid_prefix_add_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).grid_prefix_add_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).grid_prefix_add_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).grid_index_scatter_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).grid_index_scatter_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).grid_index_scatter_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).grid_index_scatter_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).compute_binned_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).compute_binned_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).compute_binned_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).compute_binned_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).collision_solve_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).collision_solve_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).collision_solve_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).collision_solve_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).collision_apply_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).collision_apply_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).collision_apply_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).collision_apply_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).copy_scratch_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).copy_scratch_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).copy_scratch_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).copy_scratch_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).analysis_clear_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).analysis_clear_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).analysis_clear_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).analysis_clear_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).analysis_scatter_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).analysis_scatter_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).analysis_scatter_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).analysis_scatter_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).analysis_coherence_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).analysis_coherence_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).analysis_coherence_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).analysis_coherence_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).analysis_tile_label_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).analysis_tile_label_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).analysis_tile_label_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).analysis_tile_label_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).analysis_tile_merge_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).analysis_tile_merge_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).analysis_tile_merge_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).analysis_tile_merge_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).analysis_summarize_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).analysis_summarize_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).analysis_summarize_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).analysis_summarize_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).init_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).init_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).init_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).init_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).force_randomize_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).force_randomize_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).force_randomize_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).force_randomize_pipeline.layout, nil)
	}
	if particle_life_gpu(sim).force_update_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, particle_life_gpu(sim).force_update_pipeline.pipeline, nil)
	}
	if particle_life_gpu(sim).force_update_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, particle_life_gpu(sim).force_update_pipeline.layout, nil)
	}
}

particle_life_destroy_graphics_and_trails :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	if particle_life_gpu(sim).render_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &particle_life_gpu(sim).render_pipeline)
	}
	if particle_life_gpu(sim).trail_particle_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &particle_life_gpu(sim).trail_particle_pipeline)
	}
	if particle_life_gpu(sim).fade_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &particle_life_gpu(sim).fade_pipeline)
	}
	if particle_life_gpu(sim).background_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &particle_life_gpu(sim).background_pipeline)
	}
	if particle_life_gpu(sim).post_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &particle_life_gpu(sim).post_pipeline)
	}
	if particle_life_gpu(sim).tiled_post_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &particle_life_gpu(sim).tiled_post_pipeline)
	}
	particle_life_destroy_trail_targets(sim, vk_ctx)
	for i in 0 ..< PARTICLE_LIFE_RETIRED_TRAIL_TARGET_CAP {
		for image_index in 0 ..< len(particle_life_gpu(sim).retired_trail_targets[i].images) {
			particle_life_destroy_trail_image(vk_ctx, &particle_life_gpu(sim).retired_trail_targets[i].images[image_index])
		}
	}
	if particle_life_gpu(sim).trail_sampler != vk.Sampler(0) {
		vk.DestroySampler(vk_ctx.device, particle_life_gpu(sim).trail_sampler, nil)
	}
}

particle_life_destroy_descriptor_state :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	if particle_life_gpu(sim).descriptor_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, particle_life_gpu(sim).descriptor_pool, nil)
	}
	if particle_life_gpu(sim).fade_descriptor_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, particle_life_gpu(sim).fade_descriptor_pool, nil)
	}
	if particle_life_gpu(sim).sim_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, particle_life_gpu(sim).sim_set_layout, nil)
	}
	if particle_life_gpu(sim).init_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, particle_life_gpu(sim).init_set_layout, nil)
	}
	if particle_life_gpu(sim).color_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, particle_life_gpu(sim).color_set_layout, nil)
	}
	if particle_life_gpu(sim).view_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, particle_life_gpu(sim).view_set_layout, nil)
	}
	if particle_life_gpu(sim).fade_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, particle_life_gpu(sim).fade_set_layout, nil)
	}
	if particle_life_gpu(sim).background_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, particle_life_gpu(sim).background_set_layout, nil)
	}
	if particle_life_gpu(sim).post_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, particle_life_gpu(sim).post_set_layout, nil)
	}
	if particle_life_gpu(sim).force_op_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, particle_life_gpu(sim).force_op_set_layout, nil)
	}
	if particle_life_gpu(sim).analysis_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, particle_life_gpu(sim).analysis_set_layout, nil)
	}
}

particle_life_destroy_buffers :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	if particle_life_gpu(sim).particle_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).particle_buffer)
	}
	if particle_life_gpu(sim).particle_scratch_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).particle_scratch_buffer)
	}
	if particle_life_gpu(sim).force_cache_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).force_cache_buffer)
	}
	if particle_life_gpu(sim).grid_heads_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).grid_heads_buffer)
	}
	if particle_life_gpu(sim).particle_next_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).particle_next_buffer)
	}
	if particle_life_gpu(sim).grid_offsets_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).grid_offsets_buffer)
	}
	if particle_life_gpu(sim).grid_cursors_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).grid_cursors_buffer)
	}
	if particle_life_gpu(sim).grid_block_sums_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).grid_block_sums_buffer)
	}
	if particle_life_gpu(sim).collision_correction_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).collision_correction_buffer)
	}
	if particle_life_gpu(sim).analysis_cells_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).analysis_cells_buffer)
	}
	if particle_life_gpu(sim).analysis_coherence_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).analysis_coherence_buffer)
	}
	if particle_life_gpu(sim).analysis_labels_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).analysis_labels_buffer)
	}
	if particle_life_gpu(sim).analysis_tile_components_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).analysis_tile_components_buffer)
	}
	if particle_life_gpu(sim).analysis_parent_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).analysis_parent_buffer)
	}
	if particle_life_gpu(sim).analysis_blob_summaries_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).analysis_blob_summaries_buffer)
	}
	if particle_life_gpu(sim).analysis_blob_count_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).analysis_blob_count_buffer)
	}
	if particle_life_gpu(sim).force_matrix_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).force_matrix_buffer)
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).init_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).fade_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).force_randomize_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).force_update_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).grid_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).collision_grid_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).collision_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).analysis_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).selected_blob_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).background_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).post_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).color_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).color_mode_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).camera_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &particle_life_gpu(sim).viewport_buffers[frame_slot])
	}
}

particle_life_destroy_shader_modules :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	if particle_life_gpu(sim).grid_clear_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).grid_clear_shader_module)
	}
	if particle_life_gpu(sim).grid_scatter_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).grid_scatter_shader_module)
	}
	if particle_life_gpu(sim).grid_scatter_predicted_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).grid_scatter_predicted_shader_module)
	}
	if particle_life_gpu(sim).grid_prefix_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).grid_prefix_shader_module)
	}
	if particle_life_gpu(sim).grid_prefix_blocks_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).grid_prefix_blocks_shader_module)
	}
	if particle_life_gpu(sim).grid_prefix_add_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).grid_prefix_add_shader_module)
	}
	if particle_life_gpu(sim).grid_index_scatter_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).grid_index_scatter_shader_module)
	}
	if particle_life_gpu(sim).compute_binned_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).compute_binned_shader_module)
	}
	if particle_life_gpu(sim).collision_solve_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).collision_solve_shader_module)
	}
	if particle_life_gpu(sim).collision_apply_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).collision_apply_shader_module)
	}
	if particle_life_gpu(sim).copy_scratch_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).copy_scratch_shader_module)
	}
	if particle_life_gpu(sim).init_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).init_shader_module)
	}
	if particle_life_gpu(sim).vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).vertex_shader_module)
	}
	if particle_life_gpu(sim).fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).fragment_shader_module)
	}
	if particle_life_gpu(sim).fade_vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).fade_vertex_shader_module)
	}
	if particle_life_gpu(sim).fade_fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).fade_fragment_shader_module)
	}
	if particle_life_gpu(sim).force_randomize_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).force_randomize_shader_module)
	}
	if particle_life_gpu(sim).force_update_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).force_update_shader_module)
	}
	if particle_life_gpu(sim).analysis_clear_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).analysis_clear_shader_module)
	}
	if particle_life_gpu(sim).analysis_scatter_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).analysis_scatter_shader_module)
	}
	if particle_life_gpu(sim).analysis_coherence_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).analysis_coherence_shader_module)
	}
	if particle_life_gpu(sim).analysis_tile_label_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).analysis_tile_label_shader_module)
	}
	if particle_life_gpu(sim).analysis_tile_merge_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).analysis_tile_merge_shader_module)
	}
	if particle_life_gpu(sim).analysis_summarize_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).analysis_summarize_shader_module)
	}
	if particle_life_gpu(sim).background_vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).background_vertex_shader_module)
	}
	if particle_life_gpu(sim).background_fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).background_fragment_shader_module)
	}
	if particle_life_gpu(sim).post_vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).post_vertex_shader_module)
	}
	if particle_life_gpu(sim).post_fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).post_fragment_shader_module)
	}
	if particle_life_gpu(sim).infinite_present_vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).infinite_present_vertex_shader_module)
	}
	if particle_life_gpu(sim).infinite_present_fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &particle_life_gpu(sim).infinite_present_fragment_shader_module)
	}
}
