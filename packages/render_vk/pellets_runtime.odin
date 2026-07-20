package render_vk

import engine "zelda_engine:engine"
import uifw "zelda_engine:ui"

import "core:math"
import vk "vendor:vulkan"

pellets_transition_trail_image :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, index: int, new_layout: vk.ImageLayout) {
	image := &gpu.trail_images[index]
	if image.handle == vk.Image(0) || image.layout == new_layout {
		return
	}
	old_layout := image.layout
	src_access: vk.AccessFlags2
	dst_access: vk.AccessFlags2
	src_stage := vk.PipelineStageFlags2{.TOP_OF_PIPE}
	dst_stage := vk.PipelineStageFlags2{.TOP_OF_PIPE}
	#partial switch old_layout {
	case .UNDEFINED:
		#partial switch new_layout {
		case .COLOR_ATTACHMENT_OPTIMAL:
			dst_access = {.COLOR_ATTACHMENT_WRITE}
			dst_stage = {.COLOR_ATTACHMENT_OUTPUT}
		}
	case .COLOR_ATTACHMENT_OPTIMAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.COLOR_ATTACHMENT_WRITE}
			dst_access = {.SHADER_READ}
			src_stage = {.COLOR_ATTACHMENT_OUTPUT}
			dst_stage = {.FRAGMENT_SHADER}
		}
	case .SHADER_READ_ONLY_OPTIMAL:
		#partial switch new_layout {
		case .COLOR_ATTACHMENT_OPTIMAL:
			src_access = {.SHADER_READ}
			dst_access = {.COLOR_ATTACHMENT_WRITE}
			src_stage = {.FRAGMENT_SHADER}
			dst_stage = {.COLOR_ATTACHMENT_OUTPUT}
		}
	}
	barrier := vk.ImageMemoryBarrier2{sType = .IMAGE_MEMORY_BARRIER_2, srcAccessMask = src_access, dstAccessMask = dst_access, oldLayout = old_layout, newLayout = new_layout, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, image = image.handle, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	engine.vk_cmd_pipeline_barrier2(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	image.layout = new_layout
}

pellets_dispatch_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dst: vk.PipelineStageFlags2) {
	barrier := vk.MemoryBarrier2{sType = .MEMORY_BARRIER_2, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.SHADER_READ, .SHADER_WRITE}}
	engine.vk_cmd_pipeline_barrier2(cmd, {.COMPUTE_SHADER}, dst, {}, 1, &barrier, 0, nil, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

pellets_gpu_step :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim: ^Remaining_Sim_State, dt: f32) {
	settings := sim.pellets
	if !pellets_gpu_ensure(gpu, vk_ctx, settings) || sim.paused {
		return
	}
	frame_slot := int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	gpu.frame_index += 1
	pellets_upload_lut(gpu, settings)
	pellets_write_static_params(gpu, vk_ctx, frame_slot, settings)
	pellets_write_physics_params(gpu, vk_ctx, frame_slot, sim, dt)
	pellets_update_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	total_cells := gpu.grid_width * gpu.grid_height
	cell_groups := max((total_cells + PELLETS_WORKGROUP_SIZE - 1) / PELLETS_WORKGROUP_SIZE, 1)
	particle_groups := max((gpu.particle_count + PELLETS_WORKGROUP_SIZE - 1) / PELLETS_WORKGROUP_SIZE, 1)
	grid_clear_set := gpu.grid_clear_sets[frame_slot]
	grid_populate_set := gpu.grid_populate_sets[frame_slot]
	physics_set := gpu.physics_sets[frame_slot]
	profile_frame := engine.Vk_Frame{frame_index = u32(frame_slot)}
	engine.gpu_profiler_begin_pass(vk_ctx, cmd, profile_frame, .Pellets_Grid_Clear)
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.grid_clear_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.grid_clear_pipeline.layout, 0, 1, &grid_clear_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, cell_groups, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	engine.gpu_profiler_end_pass(vk_ctx, cmd, profile_frame, .Pellets_Grid_Clear)
	pellets_dispatch_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	engine.gpu_profiler_begin_pass(vk_ctx, cmd, profile_frame, .Pellets_Grid_Build)
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.grid_populate_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.grid_populate_pipeline.layout, 0, 1, &grid_populate_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, particle_groups, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	engine.gpu_profiler_end_pass(vk_ctx, cmd, profile_frame, .Pellets_Grid_Build)
	pellets_dispatch_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	grid_prefix_set := gpu.grid_prefix_sets[frame_slot]
	block_count := max((total_cells + 255) / 256, 1)
	engine.gpu_profiler_begin_pass(vk_ctx, cmd, profile_frame, .Pellets_Grid_Scatter)
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.grid_prefix_pipeline.pipeline)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.grid_prefix_pipeline.layout, 0, 1, &grid_prefix_set, 0, nil)
	vk.CmdDispatch(cmd, block_count, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	pellets_dispatch_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.grid_prefix_blocks_pipeline.pipeline)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.grid_prefix_blocks_pipeline.layout, 0, 1, &grid_prefix_set, 0, nil)
	vk.CmdDispatch(cmd, 1, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	pellets_dispatch_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.grid_prefix_add_pipeline.pipeline)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.grid_prefix_add_pipeline.layout, 0, 1, &grid_prefix_set, 0, nil)
	vk.CmdDispatch(cmd, block_count, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	pellets_dispatch_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	grid_scatter_set := gpu.grid_scatter_sets[frame_slot]
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.grid_scatter_pipeline.pipeline)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.grid_scatter_pipeline.layout, 0, 1, &grid_scatter_set, 0, nil)
	vk.CmdDispatch(cmd, particle_groups, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	engine.gpu_profiler_end_pass(vk_ctx, cmd, profile_frame, .Pellets_Grid_Scatter)
	pellets_dispatch_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	engine.gpu_profiler_begin_pass(vk_ctx, cmd, profile_frame, .Pellets_Physics)
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.physics_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.physics_pipeline.layout, 0, 1, &physics_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, particle_groups, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	engine.gpu_profiler_end_pass(vk_ctx, cmd, profile_frame, .Pellets_Physics)
	pellets_dispatch_barrier(vk_ctx, cmd, {.VERTEX_SHADER, .FRAGMENT_SHADER})
}

pellets_gpu_draw_scene :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, frame_slot: int, background_pipeline, particle_pipeline: ^engine.Vk_Graphics_Pipeline, width, height: u32) {
	viewport := vk.Viewport{x = 0, y = 0, width = f32(width), height = f32(height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = {width, height}}
	pellets_gpu_draw_scene_viewport(gpu, vk_ctx, cmd, frame_slot, background_pipeline, particle_pipeline, viewport, scissor)
}

pellets_gpu_draw_scene_viewport :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, frame_slot: int, background_pipeline, particle_pipeline: ^engine.Vk_Graphics_Pipeline, viewport: vk.Viewport, scissor: vk.Rect2D) {
	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(cmd, 0, 1, &local_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &local_scissor)
	pellets_gpu_draw_background(gpu, vk_ctx, cmd, frame_slot, background_pipeline)
	pellets_gpu_draw_particles(gpu, vk_ctx, cmd, frame_slot, particle_pipeline)
}

pellets_gpu_draw_background :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, frame_slot: int, background_pipeline: ^engine.Vk_Graphics_Pipeline) {
	if background_pipeline.pipeline != vk.Pipeline(0) {
		vk.CmdBindPipeline(cmd, .GRAPHICS, background_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		background_set := gpu.background_sets[frame_slot]
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, background_pipeline.layout, 0, 1, &background_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 6, 1, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
}

pellets_gpu_draw_particles :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, frame_slot: int, particle_pipeline: ^engine.Vk_Graphics_Pipeline) {
	profile_frame := engine.Vk_Frame{frame_index = u32(frame_slot)}
	engine.gpu_profiler_begin_pass(vk_ctx, cmd, profile_frame, .Pellets_Particle_Draw)
	vk.CmdBindPipeline(cmd, .GRAPHICS, particle_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	render_set := gpu.render_sets[frame_slot]
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, particle_pipeline.layout, 0, 1, &render_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	tile_count := max(gpu.present_tile_count, 1)
	vk.CmdDraw(cmd, 6, gpu.particle_count * tile_count * tile_count, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
	engine.gpu_profiler_end_pass(vk_ctx, cmd, profile_frame, .Pellets_Particle_Draw)
}

pellets_draw_ui_overlay :: proc(vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, ui: ^Ui_Render_Sink) {
	if ui == nil {
		return
	}
	engine.vk_cmd_label_begin(vk_ctx, frame.command_buffer, "UI overlay")
	ui_render_sink_draw(ui, vk_ctx, frame.command_buffer, vk_ctx.swapchain_extent)
	engine.vk_cmd_label_end(vk_ctx, frame.command_buffer)
}

pellets_gpu_present_direct :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, settings: ^Pellets_Settings, ui: ^Ui_Render_Sink = nil) {
	engine.vk_cmd_begin_swapchain_render_pass(vk_ctx, frame, pellets_clear_color(settings))
	pellets_gpu_draw_scene(gpu, vk_ctx, frame.command_buffer, int(frame.frame_index), &gpu.background_pipeline, &gpu.render_pipeline, vk_ctx.swapchain_extent.width, vk_ctx.swapchain_extent.height)
	pellets_draw_ui_overlay(vk_ctx, frame, ui)
	engine.vk_cmd_end_swapchain_render_pass(frame)
}

pellets_write_fade_params :: proc(gpu: ^Pellets_Gpu_State, frame_slot: int, settings: ^Pellets_Settings) {
	if gpu.trail_fade_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Pellets_Fade_Params)gpu.trail_fade_params_buffers[frame_slot].mapped
	params^ = {
		fade_amount = settings.trail_fade,
	}
}

pellets_gpu_present_trails :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, settings: ^Pellets_Settings, ui: ^Ui_Render_Sink = nil) {
	if !pellets_ensure_trail_targets(gpu, vk_ctx) {
		pellets_gpu_present_direct(gpu, vk_ctx, frame, settings, ui)
		return
	}
	cmd := frame.command_buffer
	frame_slot := int(frame.frame_index)
	pellets_update_trail_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	pellets_collect_retired_trail_targets(gpu, vk_ctx, frame_slot)
	write_index := int(gpu.trail_write_index & 1)
	read_index := 1 - write_index
	pellets_transition_trail_image(gpu, vk_ctx, cmd, write_index, .COLOR_ATTACHMENT_OPTIMAL)
	if gpu.trail_initialized {
		pellets_transition_trail_image(gpu, vk_ctx, cmd, read_index, .SHADER_READ_ONLY_OPTIMAL)
		pellets_write_fade_params(gpu, frame_slot, settings)
	}

	clear_value := vk.ClearValue{color = {float32 = {0, 0, 0, 0}}}
	engine.vk_cmd_begin_rendering(vk_ctx, cmd, gpu.trail_images[write_index].view, {gpu.trail_width, gpu.trail_height}, .COLOR_ATTACHMENT_OPTIMAL, .CLEAR, .STORE, clear_value)
	viewport := vk.Viewport{x = 0, y = 0, width = f32(gpu.trail_width), height = f32(gpu.trail_height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = {gpu.trail_width, gpu.trail_height}}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	pellets_gpu_draw_background(gpu, vk_ctx, cmd, frame_slot, &gpu.trail_background_pipeline)
	if gpu.trail_initialized {
		vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.trail_fade_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		fade_set := gpu.trail_fade_sets[frame_slot][read_index]
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.trail_fade_pipeline.layout, 0, 1, &fade_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 3, 1, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
	pellets_gpu_draw_particles(gpu, vk_ctx, cmd, frame_slot, &gpu.trail_particle_pipeline)
	engine.vk_cmd_end_rendering(cmd)
	gpu.trail_images[write_index].layout = .COLOR_ATTACHMENT_OPTIMAL
	gpu.trail_initialized = true
	pellets_transition_trail_image(gpu, vk_ctx, cmd, write_index, .SHADER_READ_ONLY_OPTIMAL)

	engine.vk_cmd_begin_swapchain_render_pass(vk_ctx, frame, pellets_clear_color(settings))
	swapchain_viewport := vk.Viewport{x = 0, y = 0, width = f32(vk_ctx.swapchain_extent.width), height = f32(vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}
	swapchain_scissor := vk.Rect2D{offset = {0, 0}, extent = vk_ctx.swapchain_extent}
	vk.CmdSetViewport(cmd, 0, 1, &swapchain_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &swapchain_scissor)
	vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.trail_blit_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	blit_set := gpu.trail_blit_sets[frame_slot][write_index]
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.trail_blit_pipeline.layout, 0, 1, &blit_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDraw(cmd, 3, 1, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
	pellets_draw_ui_overlay(vk_ctx, frame, ui)
	engine.vk_cmd_end_swapchain_render_pass(frame)
	gpu.trail_write_index = u32(read_index)
}

pellets_gpu_present :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, sim: ^Remaining_Sim_State, ui: ^Ui_Render_Sink = nil) {
	if !gpu.ready || gpu.render_pipeline.pipeline == vk.Pipeline(0) {
		return
	}
	settings := sim.pellets
	frame_slot := int(frame.frame_index)
	if gpu.trail_images[0].handle != vk.Image(0) && gpu.trail_images[1].handle != vk.Image(0) {
		pellets_update_trail_descriptors_for_slot(gpu, vk_ctx, frame_slot)
		pellets_collect_retired_trail_targets(gpu, vk_ctx, frame_slot)
	}
	pellets_upload_lut(gpu, settings)
	pellets_write_static_params(gpu, vk_ctx, frame_slot, settings, &sim.camera)
	pellets_update_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	if settings.trails_enabled {
		pellets_gpu_present_trails(gpu, vk_ctx, frame, settings, ui)
		return
	}
	pellets_gpu_present_direct(gpu, vk_ctx, frame, settings, ui)
}

pellets_clear_color :: proc(settings: ^Pellets_Settings) -> uifw.Color {
	color := pellets_background_color(settings)
	return {color[0], color[1], color[2], color[3]}
}

pellets_background_color :: proc(settings: ^Pellets_Settings) -> [4]f32 {
	#partial switch settings.background_color_mode {
	case .White:
		return {1, 1, 1, 1}
	case .Gray18:
		return {0.18, 0.18, 0.18, 1}
	case .Color_Scheme:
		scheme := color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
		return color_scheme_color_at(scheme, 0)
	case:
		return {0, 0, 0, 1}
	}
}

pellets_destroy_compute_pipeline :: proc(vk_ctx: ^engine.Vk_Context, pipeline: ^engine.Vk_Compute_Pipeline) {
	if pipeline.pipeline != vk.Pipeline(0) {vk.DestroyPipeline(vk_ctx.device, pipeline.pipeline, nil)}
	if pipeline.layout != vk.PipelineLayout(0) {vk.DestroyPipelineLayout(vk_ctx.device, pipeline.layout, nil)}
	pipeline^ = {}
}

pellets_gpu_destroy :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	if vk_ctx == nil || vk_ctx.device == nil {
		gpu^ = {}
		return
	}
	pellets_destroy_compute_pipeline(vk_ctx, &gpu.grid_clear_pipeline)
	pellets_destroy_compute_pipeline(vk_ctx, &gpu.grid_populate_pipeline)
	pellets_destroy_compute_pipeline(vk_ctx, &gpu.grid_prefix_pipeline)
	pellets_destroy_compute_pipeline(vk_ctx, &gpu.grid_prefix_blocks_pipeline)
	pellets_destroy_compute_pipeline(vk_ctx, &gpu.grid_prefix_add_pipeline)
	pellets_destroy_compute_pipeline(vk_ctx, &gpu.grid_scatter_pipeline)
	pellets_destroy_compute_pipeline(vk_ctx, &gpu.physics_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.background_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.render_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.trail_background_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.trail_particle_pipeline)
		engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.trail_fade_pipeline)
		engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.trail_blit_pipeline)
		pellets_destroy_trail_targets(gpu, vk_ctx)
		for i in 0 ..< PELLETS_RETIRED_TRAIL_TARGET_CAP {
			for image_index in 0 ..< len(gpu.retired_trail_targets[i].images) {
				pellets_destroy_trail_image(vk_ctx, &gpu.retired_trail_targets[i].images[image_index])
			}
		}
		if gpu.trail_sampler != vk.Sampler(0) {vk.DestroySampler(vk_ctx.device, gpu.trail_sampler, nil)}
	if gpu.descriptor_pool != vk.DescriptorPool(0) {vk.DestroyDescriptorPool(vk_ctx.device, gpu.descriptor_pool, nil)}
	if gpu.grid_clear_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.grid_clear_set_layout, nil)}
	if gpu.grid_populate_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.grid_populate_set_layout, nil)}
	if gpu.grid_prefix_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.grid_prefix_set_layout, nil)}
	if gpu.grid_scatter_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.grid_scatter_set_layout, nil)}
	if gpu.physics_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.physics_set_layout, nil)}
	if gpu.background_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.background_set_layout, nil)}
	if gpu.render_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.render_set_layout, nil)}
	if gpu.trail_fade_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.trail_fade_set_layout, nil)}
	if gpu.trail_blit_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.trail_blit_set_layout, nil)}
	engine.vk_destroy_buffer(vk_ctx, &gpu.particle_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.grid_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.grid_counts_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.grid_offsets_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.grid_cursors_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.grid_block_sums_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.lut_buffer)
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		engine.vk_destroy_buffer(vk_ctx, &gpu.physics_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.background_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.background_color_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.render_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.trail_fade_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.grid_params_buffers[frame_slot])
	}
	engine.vk_destroy_shader_module(vk_ctx, &gpu.grid_clear_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.grid_populate_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.grid_prefix_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.grid_prefix_blocks_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.grid_prefix_add_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.grid_scatter_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.physics_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.background_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.background_fragment_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.render_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.render_fragment_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.trail_fade_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.trail_fade_fragment_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.trail_blit_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.trail_blit_fragment_shader)
	gpu^ = {}
}
