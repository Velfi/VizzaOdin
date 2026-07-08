package game

import engine "../engine"

import vk "vendor:vulkan"

POST_BLUR_SHADER_SOURCE :: "assets/shaders/post_blur.slang"
POST_BLUR_VERTEX_FALLBACK_SPV :: "build/shaders/post_blur_vertex"
POST_BLUR_FRAGMENT_FALLBACK_SPV :: "build/shaders/post_blur_fragment"
POST_BLUR_VERTEX_ENTRY :: "vertex_main"
POST_BLUR_FRAGMENT_ENTRY :: "fragment_main"

Post_Processing_Settings :: struct {
	blur_enabled: bool,
	blur_radius: f32,
	blur_sigma: f32,
}

Post_Blur_Params :: struct #align(16) {
	radius: f32,
	sigma: f32,
	width: f32,
	height: f32,
}

Post_Processing_Image :: struct {
	image: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
}

Post_Processing_Gpu_State :: struct {
	ready: bool,
	width: u32,
	height: u32,
	format: vk.Format,
	render_pass: vk.RenderPass,
	source: Post_Processing_Image,
	source_layout: vk.ImageLayout,
	sampler: vk.Sampler,
	params_buffer: engine.Vk_Buffer,
	set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	descriptor_set: vk.DescriptorSet,
	pipeline: engine.Vk_Graphics_Pipeline,
}

post_processing_default_settings :: proc() -> Post_Processing_Settings {
	return {
		blur_enabled = false,
		blur_radius = 5.0,
		blur_sigma = 2.0,
	}
}

post_processing_gpu_destroy :: proc(gpu: ^Post_Processing_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.pipeline)
	if gpu.descriptor_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, gpu.descriptor_pool, nil)
	}
	if gpu.set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.set_layout, nil)
	}
	if gpu.params_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &gpu.params_buffer)
	}
	if gpu.sampler != vk.Sampler(0) {
		vk.DestroySampler(vk_ctx.device, gpu.sampler, nil)
	}
	post_processing_destroy_image(vk_ctx, &gpu.source)
	gpu^ = {}
}

post_processing_destroy_image :: proc(vk_ctx: ^engine.Vk_Context, image: ^Post_Processing_Image) {
	if image.view != vk.ImageView(0) {
		vk.DestroyImageView(vk_ctx.device, image.view, nil)
	}
	if image.image != vk.Image(0) {
		vk.DestroyImage(vk_ctx.device, image.image, nil)
	}
	if image.memory != vk.DeviceMemory(0) {
		vk.FreeMemory(vk_ctx.device, image.memory, nil)
	}
	image^ = {}
}

post_processing_gpu_ensure :: proc(gpu: ^Post_Processing_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	width := vk_ctx.swapchain_extent.width
	height := vk_ctx.swapchain_extent.height
	if width == 0 || height == 0 {
		return false
	}
	if gpu.ready &&
	   gpu.width == width &&
	   gpu.height == height &&
	   gpu.format == vk_ctx.swapchain_format &&
	   gpu.render_pass == vk_ctx.render_pass_load {
		return true
	}

	post_processing_gpu_destroy(gpu, vk_ctx)
	gpu.width = width
	gpu.height = height
	gpu.format = vk_ctx.swapchain_format
	gpu.render_pass = vk_ctx.render_pass_load
	gpu.source_layout = .UNDEFINED

	if !post_processing_create_source_image(gpu, vk_ctx) {
		post_processing_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !post_processing_create_sampler(gpu, vk_ctx) {
		post_processing_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Post_Blur_Params)), {.UNIFORM_BUFFER}, &gpu.params_buffer) {
		post_processing_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !post_processing_create_descriptors(gpu, vk_ctx) {
		post_processing_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !post_processing_create_pipeline(gpu, vk_ctx) {
		post_processing_gpu_destroy(gpu, vk_ctx)
		return false
	}

	gpu.ready = true
	return true
}

post_processing_create_source_image :: proc(gpu: ^Post_Processing_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	info := vk.ImageCreateInfo {
		sType = .IMAGE_CREATE_INFO,
		imageType = .D2,
		format = vk_ctx.swapchain_format,
		extent = {gpu.width, gpu.height, 1},
		mipLevels = 1,
		arrayLayers = 1,
		samples = {._1},
		tiling = .OPTIMAL,
		usage = {.TRANSFER_DST, .SAMPLED},
		sharingMode = .EXCLUSIVE,
		initialLayout = .UNDEFINED,
	}
	if vk.CreateImage(vk_ctx.device, &info, nil, &gpu.source.image) != .SUCCESS {
		return false
	}

	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device, gpu.source.image, &req)
	memory_type, ok := engine.vk_find_memory_type(vk_ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {
		return false
	}
	alloc := vk.MemoryAllocateInfo{sType = .MEMORY_ALLOCATE_INFO, allocationSize = req.size, memoryTypeIndex = memory_type}
	if vk.AllocateMemory(vk_ctx.device, &alloc, nil, &gpu.source.memory) != .SUCCESS {
		return false
	}
	if vk.BindImageMemory(vk_ctx.device, gpu.source.image, gpu.source.memory, 0) != .SUCCESS {
		return false
	}

	view_info := vk.ImageViewCreateInfo {
		sType = .IMAGE_VIEW_CREATE_INFO,
		image = gpu.source.image,
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
	return vk.CreateImageView(vk_ctx.device, &view_info, nil, &gpu.source.view) == .SUCCESS
}

post_processing_create_sampler :: proc(gpu: ^Post_Processing_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	info := vk.SamplerCreateInfo{sType = .SAMPLER_CREATE_INFO}
	info.magFilter = .LINEAR
	info.minFilter = .LINEAR
	info.mipmapMode = .LINEAR
	info.addressModeU = .CLAMP_TO_EDGE
	info.addressModeV = .CLAMP_TO_EDGE
	info.addressModeW = .CLAMP_TO_EDGE
	info.minLod = 0
	info.maxLod = 1
	return vk.CreateSampler(vk_ctx.device, &info, nil, &gpu.sampler) == .SUCCESS
}

post_processing_create_descriptors :: proc(gpu: ^Post_Processing_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	bindings := [3]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	layout_info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(bindings)), pBindings = raw_data(bindings[:])}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &layout_info, nil, &gpu.set_layout) != .SUCCESS {
		return false
	}

	pool_sizes := [3]vk.DescriptorPoolSize {
		{type = .SAMPLED_IMAGE, descriptorCount = 1},
		{type = .SAMPLER, descriptorCount = 1},
		{type = .UNIFORM_BUFFER, descriptorCount = 1},
	}
	pool_info := vk.DescriptorPoolCreateInfo{sType = .DESCRIPTOR_POOL_CREATE_INFO, maxSets = 1, poolSizeCount = u32(len(pool_sizes)), pPoolSizes = raw_data(pool_sizes[:])}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &gpu.descriptor_pool) != .SUCCESS {
		return false
	}

	alloc := vk.DescriptorSetAllocateInfo{sType = .DESCRIPTOR_SET_ALLOCATE_INFO, descriptorPool = gpu.descriptor_pool, descriptorSetCount = 1, pSetLayouts = &gpu.set_layout}
	if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, &gpu.descriptor_set) != .SUCCESS {
		return false
	}

	image_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.source.view}
	sampler_info := vk.DescriptorImageInfo{sampler = gpu.sampler}
	params_info := vk.DescriptorBufferInfo{buffer = gpu.params_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Post_Blur_Params))}
	writes := [3]vk.WriteDescriptorSet {
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.descriptor_set, dstBinding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.descriptor_set, dstBinding = 1, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.descriptor_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
	return true
}

post_processing_create_pipeline :: proc(gpu: ^Post_Processing_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	vertex: engine.Vk_Shader_Module
	fragment: engine.Vk_Shader_Module
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, POST_BLUR_SHADER_SOURCE, POST_BLUR_VERTEX_FALLBACK_SPV, .Vertex, POST_BLUR_VERTEX_ENTRY, &vertex) {
		return false
	}
	defer engine.vk_destroy_shader_module(vk_ctx, &vertex)
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, POST_BLUR_SHADER_SOURCE, POST_BLUR_FRAGMENT_FALLBACK_SPV, .Fragment, POST_BLUR_FRAGMENT_ENTRY, &fragment) {
		return false
	}
	defer engine.vk_destroy_shader_module(vk_ctx, &fragment)

	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = &gpu.set_layout}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gpu.pipeline.layout) != .SUCCESS {
		return false
	}

	stages := [2]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = vertex.handle, pName = POST_BLUR_VERTEX_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = fragment.handle, pName = POST_BLUR_FRAGMENT_ENTRY},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState{blendEnable = false, colorWriteMask = {.R, .G, .B, .A}}
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
		layout = gpu.pipeline.layout,
		renderPass = vk_ctx.render_pass_load,
		subpass = 0,
	}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &gpu.pipeline.pipeline) == .SUCCESS
}

post_processing_apply_blur :: proc(gpu: ^Post_Processing_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, settings: ^Post_Processing_Settings) -> bool {
	if settings == nil || !settings.blur_enabled || settings.blur_radius <= 0 {
		return false
	}
	if !post_processing_gpu_ensure(gpu, vk_ctx) {
		return false
	}

	params := cast(^Post_Blur_Params)gpu.params_buffer.mapped
	params^ = {
		radius = min(max(settings.blur_radius, 0), 50),
		sigma = min(max(settings.blur_sigma, 0.1), 10),
		width = f32(max(vk_ctx.swapchain_extent.width, 1)),
		height = f32(max(vk_ctx.swapchain_extent.height, 1)),
	}

	range := vk.ImageSubresourceRange {
		aspectMask = {.COLOR},
		baseMipLevel = 0,
		levelCount = 1,
		baseArrayLayer = 0,
		layerCount = 1,
	}
	swapchain_image := vk_ctx.swapchain_images[frame.image_index]

	to_src := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = {},
		dstAccessMask = {.TRANSFER_READ},
		oldLayout = .PRESENT_SRC_KHR,
		newLayout = .TRANSFER_SRC_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = swapchain_image,
		subresourceRange = range,
	}
	to_dst := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = gpu.source_layout == .SHADER_READ_ONLY_OPTIMAL ? vk.AccessFlags{.SHADER_READ} : vk.AccessFlags{},
		dstAccessMask = {.TRANSFER_WRITE},
		oldLayout = gpu.source_layout,
		newLayout = .TRANSFER_DST_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = gpu.source.image,
		subresourceRange = range,
	}
	pre_barriers := [2]vk.ImageMemoryBarrier{to_src, to_dst}
	vk.CmdPipelineBarrier(frame.command_buffer, {.COLOR_ATTACHMENT_OUTPUT, .FRAGMENT_SHADER}, {.TRANSFER}, {}, 0, nil, 0, nil, u32(len(pre_barriers)), raw_data(pre_barriers[:]))
	engine.vk_cmd_count_pipeline_barrier(vk_ctx, u32(len(pre_barriers)))

	src_min := vk.Offset3D{0, 0, 0}
	src_max := vk.Offset3D{i32(vk_ctx.swapchain_extent.width), i32(vk_ctx.swapchain_extent.height), 1}
	dst_min := vk.Offset3D{0, 0, 0}
	dst_max := vk.Offset3D{i32(gpu.width), i32(gpu.height), 1}
	blit := vk.ImageBlit {
		srcSubresource = {aspectMask = {.COLOR}, mipLevel = 0, baseArrayLayer = 0, layerCount = 1},
		srcOffsets = {src_min, src_max},
		dstSubresource = {aspectMask = {.COLOR}, mipLevel = 0, baseArrayLayer = 0, layerCount = 1},
		dstOffsets = {dst_min, dst_max},
	}
	vk.CmdBlitImage(frame.command_buffer, swapchain_image, .TRANSFER_SRC_OPTIMAL, gpu.source.image, .TRANSFER_DST_OPTIMAL, 1, &blit, .LINEAR)
	engine.vk_cmd_count_transfer_copy(vk_ctx)

	to_color := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = {.TRANSFER_READ},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
		oldLayout = .TRANSFER_SRC_OPTIMAL,
		newLayout = .COLOR_ATTACHMENT_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = swapchain_image,
		subresourceRange = range,
	}
	to_shader := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = {.TRANSFER_WRITE},
		dstAccessMask = {.SHADER_READ},
		oldLayout = .TRANSFER_DST_OPTIMAL,
		newLayout = .SHADER_READ_ONLY_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = gpu.source.image,
		subresourceRange = range,
	}
	post_barriers := [2]vk.ImageMemoryBarrier{to_color, to_shader}
	vk.CmdPipelineBarrier(frame.command_buffer, {.TRANSFER}, {.COLOR_ATTACHMENT_OUTPUT, .FRAGMENT_SHADER}, {}, 0, nil, 0, nil, u32(len(post_barriers)), raw_data(post_barriers[:]))
	engine.vk_cmd_count_pipeline_barrier(vk_ctx, u32(len(post_barriers)))
	gpu.source_layout = .SHADER_READ_ONLY_OPTIMAL

	engine.vk_cmd_begin_swapchain_render_pass_load(vk_ctx, frame)
	viewport := vk.Viewport{x = 0, y = 0, width = f32(vk_ctx.swapchain_extent.width), height = f32(vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = vk_ctx.swapchain_extent}
	vk.CmdSetViewport(frame.command_buffer, 0, 1, &viewport)
	vk.CmdSetScissor(frame.command_buffer, 0, 1, &scissor)
	vk.CmdBindPipeline(frame.command_buffer, .GRAPHICS, gpu.pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(frame.command_buffer, .GRAPHICS, gpu.pipeline.layout, 0, 1, &gpu.descriptor_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDraw(frame.command_buffer, 6, 1, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
	engine.vk_cmd_end_swapchain_render_pass(frame)
	return true
}
