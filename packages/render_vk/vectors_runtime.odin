package render_vk

import engine "../engine"
import uifw "../ui"

import "core:math"
import vk "vendor:vulkan"

vectors_gpu_update_geometry :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Vectors_Settings, time: f32) {
	{
	frame_slot := vectors_gpu_active_frame_slot(vk_ctx)
	vertex_buffer := &gpu.vertex_buffers[frame_slot]
	if vertex_buffer.mapped == nil {
		gpu.index_count = 0
		gpu.instance_count = 0
		return
	}
	gpu.active_frame_slot = frame_slot
	instances := (cast([^]Vectors_Instance)vertex_buffer.mapped)[:VECTORS_MAX_SEGMENTS]
	spacing := max(settings.density, VECTORS_MIN_DENSITY)
	cols := min(max(int(2.4 / spacing), 8), 480)
	rows := min(max(int(1.8 / spacing), 6), 360)
	if settings.probe_initialized {
		if settings.vector_field_type == .Noise {
			settings.probe_value = noise_sample01_2d(&settings.noise, settings.probe_position[0], settings.probe_position[1], time)
			settings.probe_has_sample = true
		} else if gpu.image_loaded && len(gpu.image_data) == VECTORS_IMAGE_RESOLUTION * VECTORS_IMAGE_RESOLUTION {
			tex_u := math.clamp((settings.probe_position[0] + 1.0) * 0.5, 0, 1)
			tex_v := math.clamp(1.0 - (settings.probe_position[1] + 1.0) * 0.5, 0, 1)
			px := min(int(tex_u * f32(VECTORS_IMAGE_RESOLUTION - 1)), VECTORS_IMAGE_RESOLUTION - 1)
			py := min(int(tex_v * f32(VECTORS_IMAGE_RESOLUTION - 1)), VECTORS_IMAGE_RESOLUTION - 1)
			settings.probe_value = f32(gpu.image_data[py * VECTORS_IMAGE_RESOLUTION + px]) / 255.0
			settings.probe_has_sample = true
		} else {
			settings.probe_has_sample = false
		}
	}
	gpu.field_compute_active = gpu.field_pipeline.pipeline != vk.Pipeline(0)
	if gpu.field_compute_active {
		vectors_write_field_params(gpu, frame_slot, settings, time, u32(cols), u32(rows))
		gpu.instance_count = u32(cols * rows)
		#partial switch settings.display_mode {
		case .Arrows: gpu.index_count = 9
		case .Chevrons: gpu.index_count = 12
		case .Rings: gpu.index_count = 36
		case: gpu.index_count = 6
		}
		return
	}
	count := 0
	noise_cos := math.cos(settings.noise.rotation)
	noise_sin := math.sin(settings.noise.rotation)
	noise_frequency := max(settings.noise.frequency, 0.000001)
	for y in 0 ..< rows {
		for x in 0 ..< cols {
			wx := -1.2 + (f32(x) + 0.5) / f32(cols) * 2.4
			wy := -0.9 + (f32(y) + 0.5) / f32(rows) * 1.8
			value := f32(0.5)
			if settings.vector_field_type == .Noise {
				px := (wx - settings.noise.anchor_x) * noise_frequency
				py := (wy - settings.noise.anchor_y) * noise_frequency
				transformed := [2]f32{
					px * noise_cos - py * noise_sin + settings.noise.anchor_x + settings.noise.offset_x,
					px * noise_sin + py * noise_cos + settings.noise.anchor_y + settings.noise.offset_y,
				}
				value = noise_sample01_transformed_2d(&settings.noise, transformed, time)
			} else if gpu.image_loaded && len(gpu.image_data) == VECTORS_IMAGE_RESOLUTION * VECTORS_IMAGE_RESOLUTION {
				tex_u := math.clamp((wx + 1.0) * 0.5, 0, 1)
				tex_v := math.clamp(1.0 - (wy + 1.0) * 0.5, 0, 1)
				px := min(int(tex_u * f32(VECTORS_IMAGE_RESOLUTION - 1)), VECTORS_IMAGE_RESOLUTION - 1)
				py := min(int(tex_v * f32(VECTORS_IMAGE_RESOLUTION - 1)), VECTORS_IMAGE_RESOLUTION - 1)
				value = f32(gpu.image_data[py * VECTORS_IMAGE_RESOLUTION + px]) / 255.0
			}
			angle := value * 2 * math.PI
			stamp_count := min(settings.deflection_stamp_count, len(settings.deflection_stamps))
			for i in 0 ..< stamp_count {
				stamp := settings.deflection_stamps[i]
				dx := wx - stamp.position[0]
				dy := wy - stamp.position[1]
				distance_sq := dx * dx + dy * dy
				if distance_sq < stamp.radius * stamp.radius {
					distance := math.sqrt(distance_sq)
					angle += stamp.angle * (1 - distance / max(stamp.radius, 0.0001))
				}
			}
			instances[count] = {value = math.clamp(value, 0, 1), angle = angle}
			count += 1
		}
	}
	gpu.instance_count = u32(count)
	#partial switch settings.display_mode {
	case .Arrows: gpu.index_count = 9
	case .Chevrons: gpu.index_count = 12
	case .Rings: gpu.index_count = 36
	case: gpu.index_count = 6
	}
		return
		}
}

vectors_gpu_draw :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, settings: ^Vectors_Settings, time: f32) {
	viewport := vk.Viewport{x = 0, y = 0, width = f32(vk_ctx.swapchain_extent.width), height = f32(vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = vk_ctx.swapchain_extent}
	vectors_gpu_draw_viewport(gpu, vk_ctx, frame, settings, time, viewport, scissor)
}

vectors_gpu_dispatch_field :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	if !gpu.field_compute_active || gpu.instance_count == 0 {return}
	frame_slot := min(gpu.active_frame_slot, u32(engine.MAX_FRAMES_IN_FLIGHT - 1))
	vectors_record_webcam_upload(gpu, vk_ctx, cmd, int(frame_slot))
	if !gpu.webcam_live && gpu.webcam_descriptor_bound[frame_slot] {
		vectors_update_field_image_descriptor(gpu, vk_ctx, int(frame_slot), &gpu.field_image)
		gpu.webcam_descriptor_bound[frame_slot] = false
	}
	set := gpu.field_descriptor_sets[frame_slot]
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.field_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.field_pipeline.layout, 0, 1, &set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, (gpu.instance_count + 63) / 64, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	barrier := vk.MemoryBarrier2{sType = .MEMORY_BARRIER_2, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.VERTEX_ATTRIBUTE_READ}}
	engine.vk_cmd_pipeline_barrier2(cmd, {.COMPUTE_SHADER}, {.VERTEX_INPUT}, {}, 1, &barrier, 0, nil, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

vectors_gpu_prepare_viewport :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Vectors_Settings, time: f32, width, height: f32) -> bool {
	if !vectors_gpu_ensure(gpu, vk_ctx) {
		return false
	}
	frame_slot := vectors_gpu_active_frame_slot(vk_ctx)
	gpu.active_frame_slot = frame_slot
	vectors_upload_lut(gpu, settings)
	vectors_upload_camera(gpu, frame_slot, max(width, 1), max(height, 1), settings)
	vectors_gpu_refresh_image_if_needed(gpu, vk_ctx, settings)
	vectors_gpu_update_geometry(gpu, vk_ctx, settings, time)
	return gpu.index_count > 0
}

vectors_gpu_draw_viewport :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, settings: ^Vectors_Settings, time: f32, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !vectors_gpu_prepare_viewport(gpu, vk_ctx, settings, time, viewport.width, viewport.height) {
		return
	}
	vectors_gpu_draw_prepared_viewport(gpu, vk_ctx, frame, viewport, scissor)
}

vectors_gpu_draw_prepared_viewport :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if gpu.index_count == 0 {
		return
	}
	cmd := frame.command_buffer
	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(cmd, 0, 1, &local_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &local_scissor)
	vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.pipeline.pipeline)
	offset := vk.DeviceSize(0)
	frame_slot := min(gpu.active_frame_slot, u32(engine.MAX_FRAMES_IN_FLIGHT - 1))
	descriptor_set := gpu.descriptor_sets[frame_slot]
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.pipeline.layout, 0, 1, &descriptor_set, 0, nil)
	vertex_buffer := &gpu.vertex_buffers[frame_slot]
	if vertex_buffer.handle == vk.Buffer(0) {
		return
	}
	vk.CmdBindVertexBuffers(cmd, 0, 1, &vertex_buffer.handle, &offset)
	vk.CmdDraw(cmd, gpu.index_count, gpu.instance_count, 0, 0)
}

vectors_gpu_destroy :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.pipeline)
	if gpu.field_pipeline.pipeline != vk.Pipeline(0) {vk.DestroyPipeline(vk_ctx.device, gpu.field_pipeline.pipeline, nil)}
	if gpu.field_pipeline.layout != vk.PipelineLayout(0) {vk.DestroyPipelineLayout(vk_ctx.device, gpu.field_pipeline.layout, nil)}
	if gpu.field_descriptor_pool != vk.DescriptorPool(0) {vk.DestroyDescriptorPool(vk_ctx.device, gpu.field_descriptor_pool, nil)}
	if gpu.field_descriptor_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.field_descriptor_set_layout, nil)}
	if gpu.descriptor_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, gpu.descriptor_pool, nil)
	}
	if gpu.descriptor_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.descriptor_set_layout, nil)
	}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		engine.vk_destroy_buffer(vk_ctx, &gpu.vertex_buffers[i])
		engine.vk_destroy_buffer(vk_ctx, &gpu.index_buffers[i])
		engine.vk_destroy_buffer(vk_ctx, &gpu.camera_buffers[i])
		engine.vk_destroy_buffer(vk_ctx, &gpu.field_params_buffers[i])
		engine.vk_destroy_buffer(vk_ctx, &gpu.field_stamp_buffers[i])
		engine.vk_destroy_buffer(vk_ctx, &gpu.webcam_staging_buffers[i])
		flow_destroy_image(vk_ctx, &gpu.webcam_images[i])
	}
	if gpu.field_sampler != vk.Sampler(0) {vk.DestroySampler(vk_ctx.device, gpu.field_sampler, nil)}
	flow_destroy_image(vk_ctx, &gpu.field_image)
	engine.vk_destroy_buffer(vk_ctx, &gpu.lut_buffer)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.fragment_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.field_shader)
	delete(gpu.image_data)
	gpu^ = {}
}

vectors_gpu_active_frame_slot :: proc(vk_ctx: ^engine.Vk_Context) -> u32 {
	if vk_ctx == nil {
		return 0
	}
	return vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT
}
