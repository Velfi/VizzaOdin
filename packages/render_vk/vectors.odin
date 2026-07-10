package render_vk

import engine "../engine"
import uifw "../ui"

import "core:math"
import vk "vendor:vulkan"

vectors_gpu_ensure :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	if gpu.ready {
		return true
	}
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, VECTORS_VERTEX_SHADER_SOURCE, VECTORS_VERTEX_FALLBACK_SPV, .Vertex, VECTORS_SOURCE_ENTRY, &gpu.vertex_shader) {
		engine.log_error("vectors_gpu_ensure: vertex shader load failed source=", VECTORS_VERTEX_SHADER_SOURCE)
		return false
	}
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, VECTORS_FRAGMENT_SHADER_SOURCE, VECTORS_FRAGMENT_FALLBACK_SPV, .Fragment, VECTORS_SOURCE_ENTRY, &gpu.fragment_shader) {
		engine.log_error("vectors_gpu_ensure: fragment shader load failed source=", VECTORS_FRAGMENT_SHADER_SOURCE)
		vectors_gpu_destroy(gpu, vk_ctx)
		return false
	}
	vertex_buffer_size := vk.DeviceSize(size_of(Vectors_Vertex) * VECTORS_MAX_VERTICES)
	index_buffer_size := vk.DeviceSize(size_of(u32) * VECTORS_MAX_INDICES)
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vertex_buffer_size, {.VERTEX_BUFFER}, &gpu.vertex_buffers[i]) {
			vectors_gpu_destroy(gpu, vk_ctx)
			return false
		}
		if !engine.vk_create_host_buffer(vk_ctx, index_buffer_size, {.INDEX_BUFFER}, &gpu.index_buffers[i]) {
			vectors_gpu_destroy(gpu, vk_ctx)
			return false
		}
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Vectors_Camera_Uniform)), {.UNIFORM_BUFFER}, &gpu.camera_buffers[i]) {
			vectors_gpu_destroy(gpu, vk_ctx)
			return false
		}
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT), {.STORAGE_BUFFER}, &gpu.lut_buffer) {
		vectors_gpu_destroy(gpu, vk_ctx)
		return false
	}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		vectors_upload_camera(gpu, u32(i), f32(vk_ctx.swapchain_extent.width), f32(vk_ctx.swapchain_extent.height))
	}
	if !vectors_create_descriptor_state(gpu, vk_ctx) {
		vectors_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !vectors_create_pipeline(gpu, vk_ctx) {
		vectors_gpu_destroy(gpu, vk_ctx)
		return false
	}
	gpu.ready = true
	return true
}

vectors_upload_lut :: proc(gpu: ^Vectors_Gpu_State, settings: ^Vectors_Settings) {
	if gpu.lut_buffer.mapped == nil {
		return
	}
	scheme := color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
	data := (cast([^]u32)gpu.lut_buffer.mapped)[:COLOR_SCHEME_U32_COUNT]
	_ = color_scheme_write_u32_buffer(scheme, data)
}

vectors_upload_camera :: proc(gpu: ^Vectors_Gpu_State, frame_slot: u32, width, height: f32) {
	slot := min(frame_slot, u32(engine.MAX_FRAMES_IN_FLIGHT - 1))
	camera_buffer := &gpu.camera_buffers[slot]
	if camera_buffer.mapped == nil {
		return
	}
	aspect := width / max(height, 1)
	camera := cast(^Vectors_Camera_Uniform)camera_buffer.mapped
	camera^ = {
		transform_matrix = {
			1, 0, 0, 0,
			0, 1, 0, 0,
			0, 0, 1, 0,
			0, 0, 0, 1,
		},
		position = {0, 0},
		zoom = 1,
		aspect_ratio = aspect,
	}
}

vectors_create_descriptor_state :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	bindings := [2]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}},
		{binding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(bindings)),
		pBindings = raw_data(bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &layout_info, nil, &gpu.descriptor_set_layout) != .SUCCESS {
		return false
	}
	pool_sizes := [2]vk.DescriptorPoolSize {
		{type = .UNIFORM_BUFFER, descriptorCount = engine.MAX_FRAMES_IN_FLIGHT},
		{type = .STORAGE_BUFFER, descriptorCount = engine.MAX_FRAMES_IN_FLIGHT},
	}
	pool_info := vk.DescriptorPoolCreateInfo {
		sType = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = u32(len(pool_sizes)),
		pPoolSizes = raw_data(pool_sizes[:]),
		maxSets = engine.MAX_FRAMES_IN_FLIGHT,
	}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &gpu.descriptor_pool) != .SUCCESS {
		return false
	}
	layouts: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSetLayout
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		layouts[i] = gpu.descriptor_set_layout
	}
	alloc := vk.DescriptorSetAllocateInfo {
		sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool = gpu.descriptor_pool,
		descriptorSetCount = u32(len(layouts)),
		pSetLayouts = raw_data(layouts[:]),
	}
	if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(gpu.descriptor_sets[:])) != .SUCCESS {
		return false
	}
	lut_info := vk.DescriptorBufferInfo {buffer = gpu.lut_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT)}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		camera_info := vk.DescriptorBufferInfo {buffer = gpu.camera_buffers[i].handle, offset = 0, range = vk.DeviceSize(size_of(Vectors_Camera_Uniform))}
		writes := [2]vk.WriteDescriptorSet {
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.descriptor_sets[i], dstBinding = 0, descriptorCount = 1, descriptorType = .UNIFORM_BUFFER, pBufferInfo = &camera_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.descriptor_sets[i], dstBinding = 1, descriptorCount = 1, descriptorType = .STORAGE_BUFFER, pBufferInfo = &lut_info},
		}
		vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
	}
	return true
}

vectors_create_pipeline :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	stages := [2]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = gpu.vertex_shader.handle, pName = VECTORS_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = gpu.fragment_shader.handle, pName = VECTORS_ENTRY},
	}
	binding := vk.VertexInputBindingDescription {binding = 0, stride = u32(size_of(Vectors_Vertex)), inputRate = .VERTEX}
	attributes := [2]vk.VertexInputAttributeDescription {
		{location = 0, binding = 0, format = .R32G32_SFLOAT, offset = u32(offset_of(Vectors_Vertex, position))},
		{location = 1, binding = 0, format = .R32_SFLOAT, offset = u32(offset_of(Vectors_Vertex, value))},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo {
		sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount = 1,
		pVertexBindingDescriptions = &binding,
		vertexAttributeDescriptionCount = u32(len(attributes)),
		pVertexAttributeDescriptions = raw_data(attributes[:]),
	}
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
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = &gpu.descriptor_set_layout,
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gpu.pipeline.layout) != .SUCCESS {
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
		layout = gpu.pipeline.layout,
		renderPass = vk_ctx.render_pass,
		subpass = 0,
	}
	result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &gpu.pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("vectors_create_pipeline: CreateGraphicsPipelines failed result=", result)
		return false
	}
	return true
}

vectors_gpu_load_image_path :: proc(gpu: ^Vectors_Gpu_State, path: string, settings: ^Vectors_Settings) -> bool {
	if len(path) == 0 {
		gpu.image_loaded = false
		return false
	}
	img, ok := shared_image_load_rgba8(path)
	if !ok {
		gpu.image_loaded = false
		return false
	}
	defer shared_image_destroy(img)

	source := raw_data(img.pixels.buf[:])
	if len(gpu.image_data) != VECTORS_IMAGE_RESOLUTION * VECTORS_IMAGE_RESOLUTION {
		delete(gpu.image_data)
		gpu.image_data = make([]u8, VECTORS_IMAGE_RESOLUTION * VECTORS_IMAGE_RESOLUTION)
	}
	for y := 0; y < VECTORS_IMAGE_RESOLUTION; y += 1 {
		for x := 0; x < VECTORS_IMAGE_RESOLUTION; x += 1 {
			dst_x := x
			dst_y := y
			if settings.image_mirror_horizontal {
				dst_x = VECTORS_IMAGE_RESOLUTION - 1 - dst_x
			}
			if settings.image_mirror_vertical {
				dst_y = VECTORS_IMAGE_RESOLUTION - 1 - dst_y
			}
			src_x, src_y: int
			value := u8(0)
			if vectors_image_source_coord(int(img.width), int(img.height), VECTORS_IMAGE_RESOLUTION, VECTORS_IMAGE_RESOLUTION, dst_x, dst_y, settings.image_fit_mode, &src_x, &src_y) {
				value = vectors_sample_image_source(source, int(img.width), int(img.height), int(img.width) * 4, src_x, src_y)
			}
			if settings.image_invert_tone {
				value = 255 - value
			}
			gpu.image_data[y * VECTORS_IMAGE_RESOLUTION + x] = value
		}
	}
	write_fixed_string(settings.image_path[:], path)
	write_fixed_string(gpu.image_path[:], path)
	gpu.image_fit_uploaded = settings.image_fit_mode
	gpu.image_mirror_horizontal_uploaded = settings.image_mirror_horizontal
	gpu.image_mirror_vertical_uploaded = settings.image_mirror_vertical
	gpu.image_invert_tone_uploaded = settings.image_invert_tone
	gpu.image_loaded = true
	return true
}

vectors_gpu_refresh_image_if_needed :: proc(gpu: ^Vectors_Gpu_State, settings: ^Vectors_Settings) {
	path := fixed_string(settings.image_path[:])
	if len(path) == 0 {
		// An empty still-image path is also the normal state while the webcam
		// owns image_data.  The explicit Clear_Vectors_Image command clears the
		// GPU state, so do not discard a live camera frame here every draw.
		return
	}
	if gpu.image_loaded &&
	   fixed_string(gpu.image_path[:]) == path &&
	   gpu.image_fit_uploaded == settings.image_fit_mode &&
	   gpu.image_mirror_horizontal_uploaded == settings.image_mirror_horizontal &&
	   gpu.image_mirror_vertical_uploaded == settings.image_mirror_vertical &&
	   gpu.image_invert_tone_uploaded == settings.image_invert_tone {
		return
	}
	_ = vectors_gpu_load_image_path(gpu, path, settings)
}

vectors_gpu_update_geometry :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Vectors_Settings, time: f32) {
	frame_slot := vectors_gpu_active_frame_slot(vk_ctx)
	vertex_buffer := &gpu.vertex_buffers[frame_slot]
	index_buffer := &gpu.index_buffers[frame_slot]
	if vertex_buffer.mapped == nil || index_buffer.mapped == nil {
		gpu.index_count = 0
		return
	}
	gpu.active_frame_slot = frame_slot
	vertices := (cast([^]Vectors_Vertex)vertex_buffer.mapped)[:VECTORS_MAX_VERTICES]
	indices := (cast([^]u32)index_buffer.mapped)[:VECTORS_MAX_INDICES]
	vertex_count := 0
	index_count := 0
	spacing := max(settings.density, VECTORS_MIN_DENSITY)
	cols := min(max(int(2.4 / spacing), 8), 480)
	rows := min(max(int(1.8 / spacing), 6), 360)
	for y in 0 ..< rows {
		for x in 0 ..< cols {
			if index_count + 6 > VECTORS_MAX_INDICES || vertex_count + 4 > VECTORS_MAX_VERTICES {
				break
			}
			wx := -1.2 + (f32(x) + 0.5) / f32(cols) * 2.4
			wy := -0.9 + (f32(y) + 0.5) / f32(rows) * 1.8
			value := f32(0.5)
			image_mode := settings.vector_field_type == .Image
			if settings.vector_field_type == .Noise {
				value = noise_sample01_2d(&settings.noise, wx, wy, time)
			} else if gpu.image_loaded && len(gpu.image_data) == VECTORS_IMAGE_RESOLUTION * VECTORS_IMAGE_RESOLUTION {
				tex_u := math.clamp((wx + 1.0) * 0.5, 0, 1)
				tex_v := math.clamp(1.0 - (wy + 1.0) * 0.5, 0, 1)
				px := min(int(tex_u * f32(VECTORS_IMAGE_RESOLUTION - 1)), VECTORS_IMAGE_RESOLUTION - 1)
				py := min(int(tex_v * f32(VECTORS_IMAGE_RESOLUTION - 1)), VECTORS_IMAGE_RESOLUTION - 1)
				value = f32(gpu.image_data[py * VECTORS_IMAGE_RESOLUTION + px]) / 255.0
			}
			intensity := math.clamp(value, 0, 1)
			angle := value * 2 * math.PI
			// The configured length is the full segment length, as in Vizza's
			// original vector renderer. Centering it on the sample doubles it.
			length := max(settings.line_length, 0.001) * (0.5 + math.clamp(value, 0, 1) * 0.5)
			half_width := max(settings.line_width, 0.001) * 0.5
			dx := math.cos(angle) * length
			dy := math.sin(angle) * length
			len := max(math.sqrt(dx * dx + dy * dy), 0.000001)
			px := -dy / len * half_width
			py := dx / len * half_width
			x0 := wx
			y0 := wy
			x1 := wx + dx
			y1 := wy + dy
			base := u32(vertex_count)
			vertices[vertex_count + 0] = {{x0 - px, y0 - py}, intensity}
			vertices[vertex_count + 1] = {{x0 + px, y0 + py}, intensity}
			vertices[vertex_count + 2] = {{x1 + px, y1 + py}, intensity}
			vertices[vertex_count + 3] = {{x1 - px, y1 - py}, intensity}
			indices[index_count + 0] = base
			indices[index_count + 1] = base + 1
			indices[index_count + 2] = base + 2
			indices[index_count + 3] = base
			indices[index_count + 4] = base + 2
			indices[index_count + 5] = base + 3
			vertex_count += 4
			index_count += 6
		}
	}
	gpu.index_count = u32(index_count)
}

vectors_gpu_draw :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, settings: ^Vectors_Settings, time: f32) {
	viewport := vk.Viewport{x = 0, y = 0, width = f32(vk_ctx.swapchain_extent.width), height = f32(vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = vk_ctx.swapchain_extent}
	vectors_gpu_draw_viewport(gpu, vk_ctx, frame, settings, time, viewport, scissor)
}

vectors_gpu_prepare_viewport :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Vectors_Settings, time: f32, width, height: f32) -> bool {
	if !vectors_gpu_ensure(gpu, vk_ctx) {
		return false
	}
	frame_slot := vectors_gpu_active_frame_slot(vk_ctx)
	gpu.active_frame_slot = frame_slot
	vectors_upload_lut(gpu, settings)
	vectors_upload_camera(gpu, frame_slot, max(width, 1), max(height, 1))
	vectors_gpu_refresh_image_if_needed(gpu, settings)
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
	index_buffer := &gpu.index_buffers[frame_slot]
	if vertex_buffer.handle == vk.Buffer(0) || index_buffer.handle == vk.Buffer(0) {
		return
	}
	vk.CmdBindVertexBuffers(cmd, 0, 1, &vertex_buffer.handle, &offset)
	vk.CmdBindIndexBuffer(cmd, index_buffer.handle, 0, .UINT32)
	vk.CmdDrawIndexed(cmd, gpu.index_count, 1, 0, 0, 0)
}

vectors_gpu_destroy :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.pipeline)
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
	}
	engine.vk_destroy_buffer(vk_ctx, &gpu.lut_buffer)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.fragment_shader)
	delete(gpu.image_data)
	gpu^ = {}
}

vectors_gpu_active_frame_slot :: proc(vk_ctx: ^engine.Vk_Context) -> u32 {
	if vk_ctx == nil {
		return 0
	}
	return vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT
}
