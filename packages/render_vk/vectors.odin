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
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, VECTORS_FIELD_SHADER_SOURCE, VECTORS_FIELD_FALLBACK_SPV, .Compute, VECTORS_SOURCE_ENTRY, &gpu.field_shader) {
		vectors_gpu_destroy(gpu, vk_ctx)
		return false
	}
	vertex_buffer_size := vk.DeviceSize(size_of(Vectors_Instance) * VECTORS_MAX_SEGMENTS)
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vertex_buffer_size, {.VERTEX_BUFFER, .STORAGE_BUFFER}, &gpu.vertex_buffers[i]) {
			vectors_gpu_destroy(gpu, vk_ctx)
			return false
		}
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Vectors_Camera_Uniform)), {.UNIFORM_BUFFER}, &gpu.camera_buffers[i]) {
			vectors_gpu_destroy(gpu, vk_ctx)
			return false
		}
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Flow_Vector_Params)), {.UNIFORM_BUFFER}, &gpu.field_params_buffers[i]) {
			vectors_gpu_destroy(gpu, vk_ctx)
			return false
		}
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Vectors_Field_Stamp) * 32), {.STORAGE_BUFFER}, &gpu.field_stamp_buffers[i]) {
			vectors_gpu_destroy(gpu, vk_ctx)
			return false
		}
	}
	if !flow_create_image(nil, vk_ctx, &gpu.field_image, VECTORS_IMAGE_RESOLUTION, VECTORS_IMAGE_RESOLUTION, {.SAMPLED, .TRANSFER_DST}) ||
	   !vectors_create_field_sampler(gpu, vk_ctx) {
		vectors_gpu_destroy(gpu, vk_ctx)
		return false
	}
	default_pixels := make([]u8, VECTORS_IMAGE_RESOLUTION * VECTORS_IMAGE_RESOLUTION * 4, context.temp_allocator)
	for i in 0 ..< VECTORS_IMAGE_RESOLUTION * VECTORS_IMAGE_RESOLUTION {
		default_pixels[i * 4 + 0], default_pixels[i * 4 + 1], default_pixels[i * 4 + 2], default_pixels[i * 4 + 3] = 128, 128, 128, 255
	}
	if !flow_upload_sampled_image(vk_ctx, &gpu.field_image, VECTORS_IMAGE_RESOLUTION, VECTORS_IMAGE_RESOLUTION, default_pixels) {
		vectors_gpu_destroy(gpu, vk_ctx)
		return false
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
	if !vectors_create_field_state(gpu, vk_ctx) {
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

vectors_upload_camera :: proc(gpu: ^Vectors_Gpu_State, frame_slot: u32, width, height: f32, settings: ^Vectors_Settings = nil) {
	slot := min(frame_slot, u32(engine.MAX_FRAMES_IN_FLIGHT - 1))
	camera_buffer := &gpu.camera_buffers[slot]
	if camera_buffer.mapped == nil {
		return
	}
	aspect := width / max(height, 1)
	camera := cast(^Vectors_Camera_Uniform)camera_buffer.mapped
	cols, rows: u32 = 8, 6
	line_length, line_width: f32 = 0.08, 0.004
	display_mode: u32
	if settings != nil {
		spacing := max(settings.density, VECTORS_MIN_DENSITY)
		cols = u32(min(max(int(2.4 / spacing), 8), 480))
		rows = u32(min(max(int(1.8 / spacing), 6), 360))
		line_length = settings.line_length
		line_width = settings.line_width
		display_mode = u32(settings.display_mode)
	}
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
		cols = cols,
		rows = rows,
		line_length = line_length,
		line_width = line_width,
		display_mode = display_mode,
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

vectors_create_field_sampler :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	info := vk.SamplerCreateInfo{sType = .SAMPLER_CREATE_INFO, magFilter = .LINEAR, minFilter = .LINEAR, mipmapMode = .LINEAR, addressModeU = .CLAMP_TO_EDGE, addressModeV = .CLAMP_TO_EDGE, addressModeW = .CLAMP_TO_EDGE}
	return vk.CreateSampler(vk_ctx.device, &info, nil, &gpu.field_sampler) == .SUCCESS
}

vectors_create_field_state :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	bindings := [5]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	layout_info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = 5, pBindings = raw_data(bindings[:])}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &layout_info, nil, &gpu.field_descriptor_set_layout) != .SUCCESS {return false}
	pool_sizes := [4]vk.DescriptorPoolSize {
		{type = .STORAGE_BUFFER, descriptorCount = engine.MAX_FRAMES_IN_FLIGHT * 2},
		{type = .UNIFORM_BUFFER, descriptorCount = engine.MAX_FRAMES_IN_FLIGHT},
		{type = .SAMPLED_IMAGE, descriptorCount = engine.MAX_FRAMES_IN_FLIGHT},
		{type = .SAMPLER, descriptorCount = engine.MAX_FRAMES_IN_FLIGHT},
	}
	pool_info := vk.DescriptorPoolCreateInfo{sType = .DESCRIPTOR_POOL_CREATE_INFO, poolSizeCount = 4, pPoolSizes = raw_data(pool_sizes[:]), maxSets = engine.MAX_FRAMES_IN_FLIGHT}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &gpu.field_descriptor_pool) != .SUCCESS {return false}
	layouts: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSetLayout
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {layouts[i] = gpu.field_descriptor_set_layout}
	alloc := vk.DescriptorSetAllocateInfo{sType = .DESCRIPTOR_SET_ALLOCATE_INFO, descriptorPool = gpu.field_descriptor_pool, descriptorSetCount = engine.MAX_FRAMES_IN_FLIGHT, pSetLayouts = raw_data(layouts[:])}
	if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(gpu.field_descriptor_sets[:])) != .SUCCESS {return false}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		instance_info := vk.DescriptorBufferInfo{buffer = gpu.vertex_buffers[i].handle, offset = 0, range = vk.DeviceSize(size_of(Vectors_Instance) * VECTORS_MAX_SEGMENTS)}
		params_info := vk.DescriptorBufferInfo{buffer = gpu.field_params_buffers[i].handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Vector_Params))}
		stamp_info := vk.DescriptorBufferInfo{buffer = gpu.field_stamp_buffers[i].handle, offset = 0, range = vk.DeviceSize(size_of(Vectors_Field_Stamp) * 32)}
		image_info := vk.DescriptorImageInfo{sampler = gpu.field_sampler, imageView = gpu.field_image.view, imageLayout = .SHADER_READ_ONLY_OPTIMAL}
		writes := [5]vk.WriteDescriptorSet {
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.field_descriptor_sets[i], dstBinding = 0, descriptorCount = 1, descriptorType = .STORAGE_BUFFER, pBufferInfo = &instance_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.field_descriptor_sets[i], dstBinding = 1, descriptorCount = 1, descriptorType = .UNIFORM_BUFFER, pBufferInfo = &params_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.field_descriptor_sets[i], dstBinding = 2, descriptorCount = 1, descriptorType = .SAMPLED_IMAGE, pImageInfo = &image_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.field_descriptor_sets[i], dstBinding = 3, descriptorCount = 1, descriptorType = .SAMPLER, pImageInfo = &image_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.field_descriptor_sets[i], dstBinding = 4, descriptorCount = 1, descriptorType = .STORAGE_BUFFER, pBufferInfo = &stamp_info},
		}
		vk.UpdateDescriptorSets(vk_ctx.device, 5, raw_data(writes[:]), 0, nil)
	}
	layout := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = &gpu.field_descriptor_set_layout}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout, nil, &gpu.field_pipeline.layout) != .SUCCESS {return false}
	stage := vk.PipelineShaderStageCreateInfo{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.COMPUTE}, module = gpu.field_shader.handle, pName = VECTORS_ENTRY}
	info := vk.ComputePipelineCreateInfo{sType = .COMPUTE_PIPELINE_CREATE_INFO, stage = stage, layout = gpu.field_pipeline.layout}
	return vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &gpu.field_pipeline.pipeline) == .SUCCESS
}

vectors_create_pipeline :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	stages := [2]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = gpu.vertex_shader.handle, pName = VECTORS_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = gpu.fragment_shader.handle, pName = VECTORS_ENTRY},
	}
	binding := vk.VertexInputBindingDescription {binding = 0, stride = u32(size_of(Vectors_Instance)), inputRate = .INSTANCE}
	attributes := [2]vk.VertexInputAttributeDescription {
		{location = 0, binding = 0, format = .R32_SFLOAT, offset = u32(offset_of(Vectors_Instance, value))},
		{location = 1, binding = 0, format = .R32_SFLOAT, offset = u32(offset_of(Vectors_Instance, angle))},
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
	gpu.field_image_dirty = true
	return true
}

vectors_gpu_upload_field_image_if_needed :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	if !gpu.field_image_dirty || !gpu.image_loaded || len(gpu.image_data) != VECTORS_IMAGE_RESOLUTION * VECTORS_IMAGE_RESOLUTION {return true}
	pixels := make([]u8, VECTORS_IMAGE_RESOLUTION * VECTORS_IMAGE_RESOLUTION * 4, context.temp_allocator)
	for i in 0 ..< VECTORS_IMAGE_RESOLUTION * VECTORS_IMAGE_RESOLUTION {
		v := gpu.image_data[i]
		pixels[i * 4 + 0], pixels[i * 4 + 1], pixels[i * 4 + 2], pixels[i * 4 + 3] = v, v, v, 255
	}
	if !flow_upload_sampled_image(vk_ctx, &gpu.field_image, VECTORS_IMAGE_RESOLUTION, VECTORS_IMAGE_RESOLUTION, pixels) {return false}
	gpu.field_image_dirty = false
	return true
}

vectors_ensure_webcam_slot :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int, width, height: u32) -> bool {
	image := &gpu.webcam_images[frame_slot]
	staging := &gpu.webcam_staging_buffers[frame_slot]
	size := vk.DeviceSize(width * height * 4)
	if image.handle != vk.Image(0) && image.width == width && image.height == height && staging.size >= size {return true}
	flow_destroy_image(vk_ctx, image)
	engine.vk_destroy_buffer(vk_ctx, staging)
	gpu.webcam_image_ready[frame_slot] = false
	if !flow_create_image(nil, vk_ctx, image, width, height, {.SAMPLED, .TRANSFER_DST}) ||
	   !engine.vk_create_host_buffer(vk_ctx, size, {.TRANSFER_SRC}, staging) {
		flow_destroy_image(vk_ctx, image)
		engine.vk_destroy_buffer(vk_ctx, staging)
		return false
	}
	return true
}

vectors_update_field_image_descriptor :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int, image: ^Flow_Image) {
	selected := image
	if selected == nil || selected.view == vk.ImageView(0) {selected = &gpu.field_image}
	info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = selected.view}
	write := vk.WriteDescriptorSet{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.field_descriptor_sets[frame_slot], dstBinding = 2, descriptorCount = 1, descriptorType = .SAMPLED_IMAGE, pImageInfo = &info}
	vk.UpdateDescriptorSets(vk_ctx.device, 1, &write, 0, nil)
}

vectors_record_webcam_upload :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, frame_slot: int) {
	if !gpu.webcam_upload_pending[frame_slot] {return}
	image := &gpu.webcam_images[frame_slot]
	staging := &gpu.webcam_staging_buffers[frame_slot]
	flow_transition_image(vk_ctx, cmd, image, .TRANSFER_DST_OPTIMAL)
	region := vk.BufferImageCopy{imageSubresource = {aspectMask = {.COLOR}, mipLevel = 0, baseArrayLayer = 0, layerCount = 1}, imageExtent = {image.width, image.height, 1}}
	vk.CmdCopyBufferToImage(cmd, staging.handle, image.handle, .TRANSFER_DST_OPTIMAL, 1, &region)
	engine.vk_cmd_count_transfer_copy(vk_ctx)
	flow_transition_image(vk_ctx, cmd, image, .SHADER_READ_ONLY_OPTIMAL)
	gpu.webcam_upload_pending[frame_slot] = false
	gpu.webcam_image_ready[frame_slot] = true
	vectors_update_field_image_descriptor(gpu, vk_ctx, frame_slot, image)
	gpu.webcam_descriptor_bound[frame_slot] = true
}

vectors_gpu_refresh_image_if_needed :: proc(gpu: ^Vectors_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Vectors_Settings) {
	path := fixed_string(settings.image_path[:])
	if len(path) == 0 {
		// An empty still-image path is also the normal state while the webcam
		// owns image_data.  The explicit Clear_Vectors_Image command clears the
		// GPU state, so do not discard a live camera frame here every draw.
		_ = vectors_gpu_upload_field_image_if_needed(gpu, vk_ctx)
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
	_ = vectors_gpu_upload_field_image_if_needed(gpu, vk_ctx)
}

vectors_write_field_params :: proc(gpu: ^Vectors_Gpu_State, frame_slot: u32, settings: ^Vectors_Settings, time: f32, cols, rows: u32) {
	if gpu.field_params_buffers[frame_slot].mapped == nil {return}
	noise := &settings.noise
	noise_sync_indices(noise)
	params := cast(^Flow_Vector_Params)gpu.field_params_buffers[frame_slot].mapped
	stamp_count := min(settings.deflection_stamp_count, len(settings.deflection_stamps))
	params^ = {
		vector_field_type = u32(settings.vector_field_type),
		noise_kind = u32(noise.kind_index), fractal_mode = u32(noise.fractal_mode_index), noise_seed = noise.seed,
		offset_x = noise.offset_x, offset_y = noise.offset_y, rotation = noise.rotation,
		anchor_x = noise.anchor_x, anchor_y = noise.anchor_y, noise_strength = noise.noise_strength,
		amplitude = noise.amplitude, frequency = noise.frequency, octaves = noise.octaves,
		lacunarity = noise.lacunarity, gain = noise.gain, warp_mode = u32(noise.warp_mode_index),
		warp_octaves = noise.warp_octaves, warp_amplitude = noise.warp_amplitude, warp_frequency = noise.warp_frequency,
		gabor_iterations = noise.gabor.iterations, gabor_velocity = noise.gabor.velocity,
		gabor_band_width = noise.gabor.band_width, gabor_band_softness = noise.gabor.band_softness,
		phasor_iterations = noise.phasor.iterations, phasor_velocity = noise.phasor.velocity, phasor_band_width = noise.phasor.band_width,
		voronoi_output = u32(noise.voronoi.output_index), voronoi_distance_mode = u32(noise.voronoi.distance_mode_index),
		wave_velocity = noise.wave.velocity, wave_band_width = noise.wave.band_width, wave_band_softness = noise.wave.band_softness,
		time = time, _pad0 = u32(stamp_count), target_width = cols, target_height = rows,
		image_fit_mode = u32(settings.image_fit_mode),
		image_mirror_horizontal = settings.image_mirror_horizontal ? 1 : 0,
		image_mirror_vertical = settings.image_mirror_vertical ? 1 : 0,
		image_invert_tone = settings.image_invert_tone ? 1 : 0,
		webcam_live = gpu.webcam_live ? 1 : 0,
	}
	if gpu.field_stamp_buffers[frame_slot].mapped != nil {
		stamps := (cast([^]Vectors_Field_Stamp)gpu.field_stamp_buffers[frame_slot].mapped)[:32]
		for i in 0 ..< stamp_count {
			stamp := settings.deflection_stamps[i]
			stamps[i] = {position = stamp.position, radius = stamp.radius, angle = stamp.angle}
		}
	}
}

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
	expected_glyph_count := u32(cols * rows)
	write_indices := !gpu.index_cache_valid[frame_slot] ||
		gpu.index_cache_counts[frame_slot] != expected_glyph_count ||
		gpu.index_cache_modes[frame_slot] != settings.display_mode
	if settings.probe_initialized {
		if settings.vector_field_type == .Noise {
			settings.probe_value = noise_sample01_2d(&settings.noise, settings.probe_position[0], settings.probe_position[1], time)
			settings.probe_has_sample = true
		} else if gpu.image_loaded && len(gpu.image_data) == VECTORS_IMAGE_RESOLUTION * VECTORS_IMAGE_RESOLUTION {
			tex_u := math.clamp((settings.probe_position[0] + 1.0) * 0.5, 0, 1)
			tex_v := math.clamp(1.0 - (settings.probe_position[1] + 1.0) * 0.5, 0, 1)
			px_probe := min(int(tex_u * f32(VECTORS_IMAGE_RESOLUTION - 1)), VECTORS_IMAGE_RESOLUTION - 1)
			py_probe := min(int(tex_v * f32(VECTORS_IMAGE_RESOLUTION - 1)), VECTORS_IMAGE_RESOLUTION - 1)
			settings.probe_value = f32(gpu.image_data[py_probe * VECTORS_IMAGE_RESOLUTION + px_probe]) / 255.0
			settings.probe_has_sample = true
		} else {
			settings.probe_has_sample = false
		}
	}
	for y in 0 ..< rows {
		for x in 0 ..< cols {
			if index_count + 36 > VECTORS_MAX_INDICES || vertex_count + 12 > VECTORS_MAX_VERTICES {
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
			stamp_count := min(settings.deflection_stamp_count, len(settings.deflection_stamps))
			for i in 0 ..< stamp_count {
				stamp := settings.deflection_stamps[i]
				dx_stamp := wx - stamp.position[0]
				dy_stamp := wy - stamp.position[1]
				distance := math.sqrt(dx_stamp * dx_stamp + dy_stamp * dy_stamp)
				if distance < stamp.radius {
					angle += stamp.angle * (1 - distance / max(stamp.radius, 0.0001))
				}
			}
			// The configured length is the full segment length, as in Vizza's
			// original vector renderer. Centering it on the sample doubles it.
			length := max(settings.line_length, 0.001) * (0.5 + math.clamp(value, 0, 1) * 0.5)
			half_width := max(settings.line_width, 0.001) * 0.5
			if settings.display_mode == .Rings {
				// Rings intentionally emphasize magnitude rather than direction:
				// their radius follows the sampled value while color retains the
				// same palette encoding as the directional glyphs.
				radius := max(length * 0.5, half_width * 2)
				inner_radius := max(radius - max(half_width * 2, radius * 0.18), radius * 0.35)
				base := u32(vertex_count)
				for segment in 0 ..< 6 {
					a := f32(segment) / 6.0 * 2 * math.PI
					ca := math.cos(a)
					sa := math.sin(a)
					vertices[vertex_count + segment] = {{wx + ca * radius, wy + sa * radius}, intensity}
					vertices[vertex_count + 6 + segment] = {{wx + ca * inner_radius, wy + sa * inner_radius}, intensity}
				}
				if write_indices {
					for segment in 0 ..< 6 {
						next := (segment + 1) % 6
						i := index_count + segment * 6
						indices[i + 0] = base + u32(segment)
						indices[i + 1] = base + u32(next)
						indices[i + 2] = base + 6 + u32(next)
						indices[i + 3] = base + u32(segment)
						indices[i + 4] = base + 6 + u32(next)
						indices[i + 5] = base + 6 + u32(segment)
					}
				}
				vertex_count += 12
				index_count += 36
				continue
			}
			// dx/dy are constructed from a unit direction, so normalizing them
			// again adds a square root and two divisions for every glyph.
			ux := math.cos(angle)
			uy := math.sin(angle)
			dx := ux * length
			dy := uy * length
			px := -uy * half_width
			py := ux * half_width
			x0 := wx
			y0 := wy
			x1 := wx + dx
			y1 := wy + dy
			if settings.display_mode == .Needles {
				x0 = wx - dx * 0.5
				y0 = wy - dy * 0.5
				x1 = wx + dx * 0.5
				y1 = wy + dy * 0.5
			}
			base := u32(vertex_count)
			vertices[vertex_count + 0] = {{x0 - px, y0 - py}, intensity}
			vertices[vertex_count + 1] = {{x0 + px, y0 + py}, intensity}
			vertices[vertex_count + 2] = {{x1 + px, y1 + py}, intensity}
			vertices[vertex_count + 3] = {{x1 - px, y1 - py}, intensity}
			if write_indices {
				indices[index_count + 0] = base
				indices[index_count + 1] = base + 1
				indices[index_count + 2] = base + 2
				indices[index_count + 3] = base
				indices[index_count + 4] = base + 2
				indices[index_count + 5] = base + 3
			}
			vertex_count += 4
			index_count += 6
			if settings.display_mode == .Arrows {
				// A filled head makes direction explicit while retaining the
				// magnitude-colored shaft used by the original display.
				head_length := min(length * 0.42, max(half_width * 8, length * 0.22))
				head_width := max(half_width * 3.5, head_length * 0.45)
				hx := x1 - ux * head_length
				hy := y1 - uy * head_length
				base = u32(vertex_count)
				vertices[vertex_count + 0] = {{x1, y1}, intensity}
				vertices[vertex_count + 1] = {{hx - uy * head_width, hy + ux * head_width}, intensity}
				vertices[vertex_count + 2] = {{hx + uy * head_width, hy - ux * head_width}, intensity}
				if write_indices {
					indices[index_count + 0] = base
					indices[index_count + 1] = base + 1
					indices[index_count + 2] = base + 2
				}
				vertex_count += 3
				index_count += 3
			} else if settings.display_mode == .Chevrons {
				// Add a second angled stroke to the shaft, producing a compact
				// directional V without implying motion or leaving a trail.
				wing_length := length * 0.42
				wing_x := x1 - ux * wing_length - uy * wing_length * 0.55
				wing_y := y1 - uy * wing_length + ux * wing_length * 0.55
				// The wing direction has fixed proportions. Normalize its
				// dimensionless direction instead of its world-space segment.
				wing_dir_x := ux + uy * 0.55
				wing_dir_y := uy - ux * 0.55
				wing_inv_len := f32(1.0) / math.sqrt(f32(1.0 + 0.55 * 0.55))
				wpx := -wing_dir_y * wing_inv_len * half_width
				wpy := wing_dir_x * wing_inv_len * half_width
				base = u32(vertex_count)
				vertices[vertex_count + 0] = {{wing_x - wpx, wing_y - wpy}, intensity}
				vertices[vertex_count + 1] = {{wing_x + wpx, wing_y + wpy}, intensity}
				vertices[vertex_count + 2] = {{x1 + wpx, y1 + wpy}, intensity}
				vertices[vertex_count + 3] = {{x1 - wpx, y1 - wpy}, intensity}
				if write_indices {
					indices[index_count + 0] = base
					indices[index_count + 1] = base + 1
					indices[index_count + 2] = base + 2
					indices[index_count + 3] = base
					indices[index_count + 4] = base + 2
					indices[index_count + 5] = base + 3
				}
				vertex_count += 4
				index_count += 6
			}
		}
	}
	gpu.index_count = u32(index_count)
	if write_indices {
		gpu.index_cache_counts[frame_slot] = expected_glyph_count
		gpu.index_cache_modes[frame_slot] = settings.display_mode
		gpu.index_cache_valid[frame_slot] = true
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
	barrier := vk.MemoryBarrier{sType = .MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.VERTEX_ATTRIBUTE_READ}}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.VERTEX_INPUT}, {}, 1, &barrier, 0, nil, 0, nil)
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
