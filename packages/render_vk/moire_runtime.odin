package render_vk

import engine "../engine"
import uifw "../ui"

import "core:math"
import vk "vendor:vulkan"

moire_transition_image :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, index: int, new_layout: vk.ImageLayout, cmd: vk.CommandBuffer) {
	old_layout := gpu.images[index].layout
	if old_layout == new_layout {
		return
	}
	src_access: vk.AccessFlags
	dst_access: vk.AccessFlags
	src_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	dst_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	#partial switch old_layout {
	case .UNDEFINED:
		#partial switch new_layout {
		case .GENERAL:
			dst_access = {.SHADER_READ, .SHADER_WRITE}
			dst_stage = {.COMPUTE_SHADER}
		case .SHADER_READ_ONLY_OPTIMAL:
			dst_access = {.SHADER_READ}
			dst_stage = {.FRAGMENT_SHADER}
		}
	case .GENERAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.SHADER_WRITE}
			dst_access = {.SHADER_READ}
			src_stage = {.COMPUTE_SHADER}
			dst_stage = {.FRAGMENT_SHADER}
		}
	case .SHADER_READ_ONLY_OPTIMAL:
		#partial switch new_layout {
		case .GENERAL:
			src_access = {.SHADER_READ}
			dst_access = {.SHADER_READ, .SHADER_WRITE}
			src_stage = {.FRAGMENT_SHADER}
			dst_stage = {.COMPUTE_SHADER}
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
		image = gpu.images[index].handle,
		subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1},
	}
	vk.CmdPipelineBarrier(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	gpu.images[index].layout = new_layout
}

moire_write_params :: proc(gpu: ^Moire_Gpu_State, frame_slot: int, settings: ^Moire_Settings, time: f32) {
	if gpu.params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Moire_Params)gpu.params_buffers[frame_slot].mapped
	params^ = {
		time = time,
		width = f32(gpu.width),
		height = f32(gpu.height),
		generator_type = f32(settings.generator_index),
		base_freq = settings.base_freq,
		moire_amount = settings.moire_amount,
		moire_rotation = settings.moire_rotation,
		moire_scale = settings.moire_scale,
		moire_interference = settings.moire_interference,
		moire_rotation3 = settings.moire_rotation3,
		moire_scale3 = settings.moire_scale3,
		moire_weight3 = settings.moire_weight3,
		radial_swirl_strength = settings.radial_swirl_strength,
		radial_starburst_count = settings.radial_starburst_count,
		radial_center_brightness = settings.radial_center_brightness,
		color_scheme_reversed = settings.color_scheme_reversed ? f32(1) : f32(0),
		advect_strength = settings.advect_strength,
		advect_speed = settings.advect_speed,
		curl = settings.curl,
		decay = settings.decay,
		image_loaded = gpu.image_loaded ? f32(1) : f32(0),
		image_mode_enabled = settings.image_mode_enabled ? f32(1) : f32(0),
		image_interference_mode = f32(settings.interference_index),
		image_mirror_horizontal = settings.image_mirror_horizontal ? f32(1) : f32(0),
		image_mirror_vertical = settings.image_mirror_vertical ? f32(1) : f32(0),
		image_invert_tone = settings.image_invert_tone ? f32(1) : f32(0),
	}
}

moire_gpu_step :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, settings: ^Moire_Settings, time: f32, width, height: i32, paused: bool) {
	if !moire_gpu_ensure(gpu, vk_ctx, width, height) {
		return
	}
	frame_slot := int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	lut_changed := moire_upload_lut(gpu, settings)
	moire_write_params(gpu, frame_slot, settings, time)
	read_index := int(gpu.state_index)
	write_index := 1 - read_index
	if paused && !lut_changed {
		moire_update_compute_descriptor(gpu, vk_ctx, frame_slot, read_index, write_index)
		moire_collect_retired_image_textures(gpu, vk_ctx, frame_slot)
		return
	}
	moire_transition_image(gpu, vk_ctx, read_index, .GENERAL, cmd)
	moire_transition_image(gpu, vk_ctx, write_index, .GENERAL, cmd)
	moire_update_compute_descriptor(gpu, vk_ctx, frame_slot, read_index, write_index)
	moire_collect_retired_image_textures(gpu, vk_ctx, frame_slot)
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.compute_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	compute_set := gpu.compute_sets[frame_slot][write_index]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.compute_pipeline.layout, 0, 1, &compute_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := (u32(gpu.width) + MOIRE_WORKGROUP_SIZE - 1) / MOIRE_WORKGROUP_SIZE
	group_y := (u32(gpu.height) + MOIRE_WORKGROUP_SIZE - 1) / MOIRE_WORKGROUP_SIZE
	vk.CmdDispatch(cmd, group_x, group_y, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	barrier := vk.MemoryBarrier{sType = .MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.SHADER_READ, .SHADER_WRITE}}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.COMPUTE_SHADER, .FRAGMENT_SHADER}, {}, 1, &barrier, 0, nil, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	gpu.state_index = u32(write_index)
}

moire_gpu_present :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame) {
	viewport := vk.Viewport{x = 0, y = 0, width = f32(vk_ctx.swapchain_extent.width), height = f32(vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = vk_ctx.swapchain_extent}
	moire_gpu_present_viewport(gpu, vk_ctx, frame, viewport, scissor)
}

moire_gpu_present_viewport :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gpu.ready || gpu.present_pipeline.pipeline == vk.Pipeline(0) {
		return
	}
	frame_slot := int(frame.frame_index)
	index := int(gpu.state_index)
	moire_transition_image(gpu, vk_ctx, index, .SHADER_READ_ONLY_OPTIMAL, frame.command_buffer)
	moire_update_texture_descriptor(gpu, vk_ctx, frame_slot, index)
	moire_upload_camera(gpu, frame_slot)
	moire_gpu_draw_prepared_viewport(gpu, vk_ctx, frame, viewport, scissor)
}

moire_gpu_draw_prepared_viewport :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gpu.ready || gpu.present_pipeline.pipeline == vk.Pipeline(0) {
		return
	}
	frame_slot := int(frame.frame_index)
	index := int(gpu.state_index)
	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(frame.command_buffer, 0, 1, &local_viewport)
	vk.CmdSetScissor(frame.command_buffer, 0, 1, &local_scissor)
	vk.CmdBindPipeline(frame.command_buffer, .GRAPHICS, gpu.present_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	texture_set := gpu.texture_sets[frame_slot][index]
	camera_set := gpu.camera_sets[frame_slot]
	vk.CmdBindDescriptorSets(frame.command_buffer, .GRAPHICS, gpu.present_pipeline.layout, 0, 1, &texture_set, 0, nil)
	vk.CmdBindDescriptorSets(frame.command_buffer, .GRAPHICS, gpu.present_pipeline.layout, 1, 1, &camera_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDraw(frame.command_buffer, 6, 25, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
}

moire_gpu_destroy :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	if vk_ctx == nil || vk_ctx.device == nil {
		gpu^ = {}
		return
	}
	if gpu.compute_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, gpu.compute_pipeline.pipeline, nil)
	}
	if gpu.compute_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, gpu.compute_pipeline.layout, nil)
	}
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.present_pipeline)
	if gpu.descriptor_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, gpu.descriptor_pool, nil)
	}
	if gpu.compute_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.compute_set_layout, nil)
	}
	if gpu.texture_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.texture_set_layout, nil)
	}
		if gpu.camera_set_layout != vk.DescriptorSetLayout(0) {
			vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.camera_set_layout, nil)
		}
		if gpu.sampler != vk.Sampler(0) {
			vk.DestroySampler(vk_ctx.device, gpu.sampler, nil)
		}
		moire_destroy_image(vk_ctx, &gpu.image_texture)
		for i in 0 ..< MOIRE_RETIRED_IMAGE_TEXTURE_CAP {
			moire_destroy_image(vk_ctx, &gpu.retired_image_textures[i].image)
		}
		for i in 0 ..< 2 {
			moire_destroy_image(vk_ctx, &gpu.images[i])
		}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		engine.vk_destroy_buffer(vk_ctx, &gpu.params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.render_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.camera_buffers[frame_slot])
	}
	engine.vk_destroy_buffer(vk_ctx, &gpu.lut_buffer)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.compute_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.present_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.present_fragment_shader)
	gpu^ = {}
}
