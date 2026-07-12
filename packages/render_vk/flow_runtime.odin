package render_vk

import engine "../engine"
import uifw "../ui"

import "core:math"
import vk "vendor:vulkan"

flow_transition_image :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, image: ^Flow_Image, new_layout: vk.ImageLayout) {
	if image.layout == new_layout {return}
	src_access: vk.AccessFlags2
	dst_access: vk.AccessFlags2
	src_stage := vk.PipelineStageFlags2{.TOP_OF_PIPE}
	dst_stage := vk.PipelineStageFlags2{.COMPUTE_SHADER}
	if image.layout == .GENERAL {
		src_access = {.SHADER_WRITE}
		src_stage = {.COMPUTE_SHADER}
	} else if image.layout == .TRANSFER_DST_OPTIMAL {
		src_access = {.TRANSFER_WRITE}
		src_stage = {.TRANSFER}
	}
	if new_layout == .GENERAL {
		dst_access = {.SHADER_READ, .SHADER_WRITE}
	} else if new_layout == .SHADER_READ_ONLY_OPTIMAL {
		dst_access = {.SHADER_READ}
		dst_stage = {.COMPUTE_SHADER}
	} else if new_layout == .TRANSFER_DST_OPTIMAL {
		dst_access = {.TRANSFER_WRITE}
		dst_stage = {.TRANSFER}
	}
	barrier := vk.ImageMemoryBarrier2{sType = .IMAGE_MEMORY_BARRIER_2, srcAccessMask = src_access, dstAccessMask = dst_access, oldLayout = image.layout, newLayout = new_layout, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, image = image.handle, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	engine.vk_cmd_pipeline_barrier2(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	image.layout = new_layout
}

flow_compute_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dst: vk.PipelineStageFlags2) {
	barrier := vk.MemoryBarrier2{sType = .MEMORY_BARRIER_2, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.SHADER_READ, .SHADER_WRITE}}
	engine.vk_cmd_pipeline_barrier2(cmd, {.COMPUTE_SHADER}, dst, {}, 1, &barrier, 0, nil, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

flow_gpu_step :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim: ^Remaining_Sim_State, dt: f32) {
	width := max(vk_ctx.swapchain_extent.width, 1)
	height := max(vk_ctx.swapchain_extent.height, 1)
	flow_gpu_step_size(gpu, vk_ctx, cmd, sim, dt, width, height, width, height)
}

flow_gpu_step_size :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim: ^Remaining_Sim_State, dt: f32, trail_width, trail_height, screen_width, screen_height: u32) {
	settings := sim.flow
	if !flow_gpu_ensure_size(gpu, vk_ctx, settings, trail_width, trail_height) {return}
	frame_slot := int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	flow_record_webcam_upload(gpu, vk_ctx, cmd, frame_slot)
	flow_write_params_size(gpu, vk_ctx, frame_slot, sim, dt, screen_width, screen_height)
	flow_update_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	flow_collect_retired_vector_field_images(gpu, vk_ctx, frame_slot)
	flow_transition_image(vk_ctx, cmd, &gpu.trail_image, .GENERAL)
	if sim.flow_clear_trails_requested {
		background_color := flow_background_color(settings)
		clear := vk.ClearColorValue{float32 = {background_color[0], background_color[1], background_color[2], background_color[3]}}
		range := vk.ImageSubresourceRange{aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}
		vk.CmdClearColorImage(cmd, gpu.trail_image.handle, .GENERAL, &clear, 1, &range)
		gpu.trail_cleared = true
		sim.flow_clear_trails_requested = false
	}
	if sim.paused {return}
	if !gpu.default_image_initialized {
		flow_transition_image(vk_ctx, cmd, &gpu.default_image, .TRANSFER_DST_OPTIMAL)
		default_clear := vk.ClearColorValue{float32 = {1, 1, 1, 1}}
		default_range := vk.ImageSubresourceRange{aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}
		vk.CmdClearColorImage(cmd, gpu.default_image.handle, .TRANSFER_DST_OPTIMAL, &default_clear, 1, &default_range)
		gpu.default_image_initialized = true
	}
	flow_transition_image(vk_ctx, cmd, &gpu.default_image, .SHADER_READ_ONLY_OPTIMAL)
	if !gpu.trail_cleared {
		background_color := flow_background_color(settings)
		clear := vk.ClearColorValue{float32 = {background_color[0], background_color[1], background_color[2], background_color[3]}}
		range := vk.ImageSubresourceRange{aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}
		vk.CmdClearColorImage(cmd, gpu.trail_image.handle, .GENERAL, &clear, 1, &range)
		gpu.trail_cleared = true
	}
	flow_write_spawn_control(gpu, sim, dt)
	vector_set := gpu.vector_sets[frame_slot]
	trail_set := gpu.trail_sets[frame_slot]
	shape_drawing_set := gpu.shape_drawing_sets[frame_slot]
	update_set := gpu.update_sets[frame_slot]
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.vector_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.vector_pipeline.layout, 0, 1, &vector_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, (FLOW_FIELD_RESOLUTION + 15) / 16, (FLOW_FIELD_RESOLUTION + 15) / 16, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	flow_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.trail_decay_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.trail_decay_pipeline.layout, 0, 1, &trail_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, (max(gpu.trail_width, 1) + 15) / 16, (max(gpu.trail_height, 1) + 15) / 16, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	flow_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	if sim.cursor_active != 0 && sim.cursor_mode == 1 && gpu.shape_drawing_pipeline.pipeline != vk.Pipeline(0) {
		flow_write_shape_params(gpu, frame_slot, sim)
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.shape_drawing_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.shape_drawing_pipeline.layout, 0, 1, &shape_drawing_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDispatch(cmd, (max(gpu.trail_width, 1) + 7) / 8, (max(gpu.trail_height, 1) + 7) / 8, 1)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		flow_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	}
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.particle_update_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.particle_update_pipeline.layout, 0, 1, &update_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, (gpu.total_pool_size + 63) / 64, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	flow_compute_barrier(vk_ctx, cmd, {.VERTEX_SHADER, .FRAGMENT_SHADER})
}

flow_gpu_step_preview :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim: ^Remaining_Sim_State, dt: f32, preview_width, preview_height: u32) {
	flow_gpu_step_size(gpu, vk_ctx, cmd, sim, dt, preview_width, preview_height, preview_width, preview_height)
}

flow_gpu_present :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame) {
	viewport := vk.Viewport{x = 0, y = 0, width = f32(vk_ctx.swapchain_extent.width), height = f32(vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = vk_ctx.swapchain_extent}
	flow_gpu_present_viewport(gpu, vk_ctx, frame, viewport, scissor)
}

flow_gpu_present_viewport :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gpu.ready || gpu.particle_pipeline.pipeline == vk.Pipeline(0) {return}
	frame_slot := int(frame.frame_index)
	flow_upload_camera_size(gpu, frame_slot, viewport.width, viewport.height)
	flow_update_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	flow_collect_retired_vector_field_images(gpu, vk_ctx, frame_slot)
	if gpu.trail_pipeline.pipeline != vk.Pipeline(0) {
		flow_transition_image(vk_ctx, frame.command_buffer, &gpu.trail_image, .GENERAL)
	}
	flow_gpu_draw_prepared_viewport(gpu, vk_ctx, frame, viewport, scissor)
}

flow_gpu_draw_prepared_viewport :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gpu.ready || gpu.particle_pipeline.pipeline == vk.Pipeline(0) {return}
	cmd := frame.command_buffer
	local_viewport := viewport
	local_scissor := scissor
	frame_slot := int(frame.frame_index)
	background_set := gpu.background_sets[frame_slot]
	trail_set := gpu.trail_sets[frame_slot]
	particle_set := gpu.particle_sets[frame_slot]
	camera_set := gpu.camera_sets[frame_slot]
	vk.CmdSetViewport(cmd, 0, 1, &local_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &local_scissor)
	if gpu.background_pipeline.pipeline != vk.Pipeline(0) {
		vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.background_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.background_pipeline.layout, 0, 1, &background_set, 0, nil)
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.background_pipeline.layout, 1, 1, &camera_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 6, 1, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
	if gpu.trail_pipeline.pipeline != vk.Pipeline(0) {
		vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.trail_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.trail_pipeline.layout, 0, 1, &trail_set, 0, nil)
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.trail_pipeline.layout, 1, 1, &camera_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 6, 1, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
	if gpu.show_particles {
		vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.particle_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.particle_pipeline.layout, 0, 1, &particle_set, 0, nil)
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.particle_pipeline.layout, 1, 1, &camera_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 6, gpu.total_pool_size, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
}

flow_clear_color :: proc(settings: ^Flow_Settings) -> uifw.Color {
	_ = settings
	return {0, 0, 0, 1}
}

flow_destroy_compute_pipeline :: proc(vk_ctx: ^engine.Vk_Context, pipeline: ^engine.Vk_Compute_Pipeline) {
	if pipeline.pipeline != vk.Pipeline(0) {vk.DestroyPipeline(vk_ctx.device, pipeline.pipeline, nil)}
	if pipeline.layout != vk.PipelineLayout(0) {vk.DestroyPipelineLayout(vk_ctx.device, pipeline.layout, nil)}
	pipeline^ = {}
}

flow_destroy_image :: proc(vk_ctx: ^engine.Vk_Context, image: ^Flow_Image) {
	if image.view != vk.ImageView(0) {vk.DestroyImageView(vk_ctx.device, image.view, nil)}
	if image.handle != vk.Image(0) {vk.DestroyImage(vk_ctx.device, image.handle, nil)}
	if image.memory != vk.DeviceMemory(0) {vk.FreeMemory(vk_ctx.device, image.memory, nil)}
	image^ = {}
}

flow_frame_slot_mask :: proc() -> u32 {
	return (u32(1) << u32(engine.MAX_FRAMES_IN_FLIGHT)) - 1
}

flow_collect_retired_vector_field_images :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	bit := u32(1) << u32(frame_slot)
	for i in 0 ..< FLOW_RETIRED_VECTOR_FIELD_IMAGE_CAP {
		retired := &gpu.retired_vector_field_images[i]
		if retired.pending_frame_slots == 0 {
			continue
		}
		retired.pending_frame_slots = retired.pending_frame_slots & (~bit)
		if retired.pending_frame_slots == 0 {
			flow_destroy_image(vk_ctx, &retired.image)
		}
	}
}

flow_retire_vector_field_image :: proc(gpu: ^Flow_Gpu_State) -> bool {
	if gpu.vector_field_image.handle == vk.Image(0) {
		gpu.vector_field_image = {}
		return true
	}
	for i in 0 ..< FLOW_RETIRED_VECTOR_FIELD_IMAGE_CAP {
		retired := &gpu.retired_vector_field_images[i]
		if retired.pending_frame_slots == 0 {
			retired.image = gpu.vector_field_image
			retired.pending_frame_slots = flow_frame_slot_mask()
			gpu.vector_field_image = {}
			return true
		}
	}
	engine.log_warn("flow: vector field image retire slots exhausted")
	return false
}

flow_gpu_destroy :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	if vk_ctx == nil || vk_ctx.device == nil {gpu^ = {}; return}
	flow_destroy_compute_pipeline(vk_ctx, &gpu.vector_pipeline)
	flow_destroy_compute_pipeline(vk_ctx, &gpu.particle_update_pipeline)
	flow_destroy_compute_pipeline(vk_ctx, &gpu.trail_decay_pipeline)
	flow_destroy_compute_pipeline(vk_ctx, &gpu.shape_drawing_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.background_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.trail_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.particle_pipeline)
	if gpu.descriptor_pool != vk.DescriptorPool(0) {vk.DestroyDescriptorPool(vk_ctx.device, gpu.descriptor_pool, nil)}
	if gpu.vector_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.vector_set_layout, nil)}
	if gpu.update_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.update_set_layout, nil)}
	if gpu.background_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.background_set_layout, nil)}
	if gpu.trail_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.trail_set_layout, nil)}
	if gpu.shape_drawing_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.shape_drawing_set_layout, nil)}
	if gpu.particle_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.particle_set_layout, nil)}
	if gpu.camera_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.camera_set_layout, nil)}
	if gpu.sampler != vk.Sampler(0) {vk.DestroySampler(vk_ctx.device, gpu.sampler, nil)}
	engine.vk_destroy_buffer(vk_ctx, &gpu.particle_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.flow_vector_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.lut_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.spawn_control_buffer)
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		engine.vk_destroy_buffer(vk_ctx, &gpu.sim_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.vector_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.background_color_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.shape_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.camera_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.webcam_staging_buffers[frame_slot])
		flow_destroy_image(vk_ctx, &gpu.webcam_images[frame_slot])
	}
	for i in 0 ..< FLOW_RETIRED_VECTOR_FIELD_IMAGE_CAP {
		flow_destroy_image(vk_ctx, &gpu.retired_vector_field_images[i].image)
	}
	flow_destroy_image(vk_ctx, &gpu.trail_image)
	flow_destroy_image(vk_ctx, &gpu.default_image)
	flow_destroy_image(vk_ctx, &gpu.vector_field_image)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.vector_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.particle_update_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.trail_decay_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.shape_drawing_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.background_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.background_fragment_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.trail_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.trail_fragment_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.particle_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.particle_fragment_shader)
	gpu^ = {}
}
