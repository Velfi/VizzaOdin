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
	width := sim.gpu.width
	height := sim.gpu.height
	particle_life_destroy_compute_pipelines(sim, vk_ctx)
	particle_life_destroy_graphics_and_trails(sim, vk_ctx)
	particle_life_destroy_descriptor_state(sim, vk_ctx)
	particle_life_destroy_buffers(sim, vk_ctx)
	particle_life_destroy_shader_modules(sim, vk_ctx)
	sim.gpu = {width = width, height = height}
}

particle_life_destroy_compute_pipelines :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
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
	if sim.gpu.grid_prefix_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.grid_prefix_pipeline.pipeline, nil)
	}
	if sim.gpu.grid_prefix_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.grid_prefix_pipeline.layout, nil)
	}
	if sim.gpu.grid_prefix_blocks_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.grid_prefix_blocks_pipeline.pipeline, nil)
	}
	if sim.gpu.grid_prefix_blocks_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.grid_prefix_blocks_pipeline.layout, nil)
	}
	if sim.gpu.grid_prefix_add_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.grid_prefix_add_pipeline.pipeline, nil)
	}
	if sim.gpu.grid_prefix_add_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.grid_prefix_add_pipeline.layout, nil)
	}
	if sim.gpu.grid_index_scatter_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.grid_index_scatter_pipeline.pipeline, nil)
	}
	if sim.gpu.grid_index_scatter_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.grid_index_scatter_pipeline.layout, nil)
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
}

particle_life_destroy_graphics_and_trails :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
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
}

particle_life_destroy_descriptor_state :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
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
}

particle_life_destroy_buffers :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	if sim.gpu.particle_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.particle_buffer)
	}
	if sim.gpu.particle_scratch_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.particle_scratch_buffer)
	}
	if sim.gpu.force_cache_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.force_cache_buffer)
	}
	if sim.gpu.grid_heads_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.grid_heads_buffer)
	}
	if sim.gpu.particle_next_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.particle_next_buffer)
	}
	if sim.gpu.grid_offsets_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.grid_offsets_buffer)
	}
	if sim.gpu.grid_cursors_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.grid_cursors_buffer)
	}
	if sim.gpu.grid_block_sums_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.grid_block_sums_buffer)
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
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.collision_grid_params_buffers[frame_slot])
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
}

particle_life_destroy_shader_modules :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	if sim.gpu.grid_clear_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.grid_clear_shader_module)
	}
	if sim.gpu.grid_scatter_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.grid_scatter_shader_module)
	}
	if sim.gpu.grid_scatter_predicted_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.grid_scatter_predicted_shader_module)
	}
	if sim.gpu.grid_prefix_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.grid_prefix_shader_module)
	}
	if sim.gpu.grid_prefix_blocks_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.grid_prefix_blocks_shader_module)
	}
	if sim.gpu.grid_prefix_add_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.grid_prefix_add_shader_module)
	}
	if sim.gpu.grid_index_scatter_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.grid_index_scatter_shader_module)
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
}
