package render_vk

import engine "../engine"
import uifw "../ui"

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import vk "vendor:vulkan"

particle_life_create_compute_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, particle_life_gpu(sim).grid_clear_shader_module, &particle_life_gpu(sim).grid_clear_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, particle_life_gpu(sim).grid_scatter_shader_module, &particle_life_gpu(sim).grid_scatter_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, particle_life_gpu(sim).grid_scatter_predicted_shader_module, &particle_life_gpu(sim).grid_scatter_predicted_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, particle_life_gpu(sim).grid_prefix_shader_module, &particle_life_gpu(sim).grid_prefix_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, particle_life_gpu(sim).grid_prefix_blocks_shader_module, &particle_life_gpu(sim).grid_prefix_blocks_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, particle_life_gpu(sim).grid_prefix_add_shader_module, &particle_life_gpu(sim).grid_prefix_add_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, particle_life_gpu(sim).grid_index_scatter_shader_module, &particle_life_gpu(sim).grid_index_scatter_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, particle_life_gpu(sim).compute_binned_shader_module, &particle_life_gpu(sim).compute_binned_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, particle_life_gpu(sim).collision_solve_shader_module, &particle_life_gpu(sim).collision_solve_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, particle_life_gpu(sim).collision_apply_shader_module, &particle_life_gpu(sim).collision_apply_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, particle_life_gpu(sim).copy_scratch_shader_module, &particle_life_gpu(sim).copy_scratch_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, particle_life_gpu(sim).analysis_clear_shader_module, particle_life_gpu(sim).analysis_set_layout, &particle_life_gpu(sim).analysis_clear_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, particle_life_gpu(sim).analysis_scatter_shader_module, particle_life_gpu(sim).analysis_set_layout, &particle_life_gpu(sim).analysis_scatter_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, particle_life_gpu(sim).analysis_coherence_shader_module, particle_life_gpu(sim).analysis_set_layout, &particle_life_gpu(sim).analysis_coherence_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, particle_life_gpu(sim).analysis_tile_label_shader_module, particle_life_gpu(sim).analysis_set_layout, &particle_life_gpu(sim).analysis_tile_label_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, particle_life_gpu(sim).analysis_tile_merge_shader_module, particle_life_gpu(sim).analysis_set_layout, &particle_life_gpu(sim).analysis_tile_merge_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, particle_life_gpu(sim).analysis_summarize_shader_module, particle_life_gpu(sim).analysis_set_layout, &particle_life_gpu(sim).analysis_summarize_pipeline) {
		return false
	}
	return true
}

particle_life_create_analysis_pipeline :: proc(vk_ctx: ^engine.Vk_Context, shader: engine.Vk_Shader_Module, set_layout: vk.DescriptorSetLayout, pipeline: ^engine.Vk_Compute_Pipeline) -> bool {
	set_layouts := [1]vk.DescriptorSetLayout{set_layout}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = raw_data(set_layouts[:]),
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
	result := vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_analysis_pipeline: CreateComputePipelines failed result=", result)
		return false
	}
	return true
}

particle_life_create_force_pipeline :: proc(vk_ctx: ^engine.Vk_Context, shader: engine.Vk_Shader_Module, set_layout: vk.DescriptorSetLayout, pipeline: ^engine.Vk_Compute_Pipeline) -> bool {
	set_layouts := [1]vk.DescriptorSetLayout{set_layout}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = raw_data(set_layouts[:]),
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
	result := vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_force_pipeline: CreateComputePipelines failed result=", result)
		return false
	}
	return true
}

particle_life_create_force_pipelines :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if !particle_life_create_force_pipeline(vk_ctx, particle_life_gpu(sim).force_randomize_shader_module, particle_life_gpu(sim).force_op_set_layout, &particle_life_gpu(sim).force_randomize_pipeline) {
		return false
	}
	if !particle_life_create_force_pipeline(vk_ctx, particle_life_gpu(sim).force_update_shader_module, particle_life_gpu(sim).force_op_set_layout, &particle_life_gpu(sim).force_update_pipeline) {
		return false
	}
	return true
}

particle_life_create_particle_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, pipeline: ^engine.Vk_Graphics_Pipeline) -> bool {
	vertex_stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.VERTEX},
		module = particle_life_gpu(sim).vertex_shader_module.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	fragment_stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.FRAGMENT},
		module = particle_life_gpu(sim).fragment_shader_module.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	stages := [?]vk.PipelineShaderStageCreateInfo{vertex_stage, fragment_stage}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo {
		sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		topology = .TRIANGLE_LIST,
	}
	viewport_state := vk.PipelineViewportStateCreateInfo {
		sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		viewportCount = 1,
		scissorCount = 1,
	}
	raster := vk.PipelineRasterizationStateCreateInfo {
		sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		polygonMode = .FILL,
		cullMode = {},
		frontFace = .COUNTER_CLOCKWISE,
		lineWidth = 1,
	}
	multisample := vk.PipelineMultisampleStateCreateInfo {
		sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		rasterizationSamples = {._1},
	}
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
	blend := vk.PipelineColorBlendStateCreateInfo {
		sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		attachmentCount = 1,
		pAttachments = &blend_attachment,
	}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo {
		sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = u32(len(dynamic_states)),
		pDynamicStates = raw_data(dynamic_states[:]),
	}
	set_layouts := [3]vk.DescriptorSetLayout{particle_life_gpu(sim).sim_set_layout, particle_life_gpu(sim).color_set_layout, particle_life_gpu(sim).view_set_layout}
	push_range := vk.PushConstantRange {
		stageFlags = {.VERTEX},
		offset = 0,
		size = u32(size_of(Particle_Life_Viewport_Push)),
	}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = u32(len(set_layouts)),
		pSetLayouts = raw_data(set_layouts[:]),
		pushConstantRangeCount = 1,
		pPushConstantRanges = &push_range,
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}
	rendering := engine.vk_pipeline_rendering_info(&vk_ctx.swapchain_format)
	info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		pNext = &rendering,
		stageCount = u32(len(stages)),
		pStages = raw_data(stages[:]),
		pVertexInputState = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState = &multisample,
		pColorBlendState = &blend,
		pDynamicState = &dynamic_state,
		layout = pipeline.layout,
	}
	result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_particle_pipeline: CreateGraphicsPipelines failed result=", result)
		return false
	}
	return true
}

particle_life_create_render_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	return particle_life_create_particle_pipeline(sim, vk_ctx, &particle_life_gpu(sim).render_pipeline)
}

particle_life_create_trail_image :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, index: int, width, height: u32) -> bool {
	image := &particle_life_gpu(sim).trail_images[index]
	image_info := vk.ImageCreateInfo {
		sType = .IMAGE_CREATE_INFO,
		imageType = .D2,
		format = vk_ctx.swapchain_format,
		extent = {width, height, 1},
		mipLevels = 1,
		arrayLayers = 1,
		samples = {._1},
		tiling = .OPTIMAL,
		usage = {.COLOR_ATTACHMENT, .SAMPLED, .TRANSFER_SRC, .TRANSFER_DST},
		sharingMode = .EXCLUSIVE,
		initialLayout = .UNDEFINED,
	}
	if result := vk.CreateImage(vk_ctx.device, &image_info, nil, &image.handle); result != .SUCCESS {
		engine.log_error("particle_life_create_trail_image: CreateImage failed index=", index, " result=", result, " size=", width, "x", height, " format=", image_info.format)
		return false
	}
	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device, image.handle, &req)
	memory_type, ok := engine.vk_find_memory_type(vk_ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {
		return false
	}
	alloc := vk.MemoryAllocateInfo {
		sType = .MEMORY_ALLOCATE_INFO,
		allocationSize = req.size,
		memoryTypeIndex = memory_type,
	}
	if result := vk.AllocateMemory(vk_ctx.device, &alloc, nil, &image.memory); result != .SUCCESS {
		engine.log_error("particle_life_create_trail_image: AllocateMemory failed index=", index, " result=", result)
		return false
	}
	if result := vk.BindImageMemory(vk_ctx.device, image.handle, image.memory, 0); result != .SUCCESS {
		engine.log_error("particle_life_create_trail_image: BindImageMemory failed index=", index, " result=", result)
		return false
	}
	view_info := vk.ImageViewCreateInfo {
		sType = .IMAGE_VIEW_CREATE_INFO,
		image = image.handle,
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
	if result := vk.CreateImageView(vk_ctx.device, &view_info, nil, &image.view); result != .SUCCESS {
		engine.log_error("particle_life_create_trail_image: CreateImageView failed index=", index, " result=", result)
		return false
	}
	image.layout = .UNDEFINED
	return true
}

particle_life_create_fade_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	set_layouts := [1]vk.DescriptorSetLayout{particle_life_gpu(sim).fade_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = u32(len(set_layouts)),
		pSetLayouts = raw_data(set_layouts[:]),
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &particle_life_gpu(sim).fade_pipeline.layout) != .SUCCESS {
		return false
	}
	stages := [2]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = particle_life_gpu(sim).fade_vertex_shader_module.handle, pName = PARTICLE_LIFE_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = particle_life_gpu(sim).fade_fragment_shader_module.handle, pName = PARTICLE_LIFE_ENTRY},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
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
	rendering := engine.vk_pipeline_rendering_info(&vk_ctx.swapchain_format)
	info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		pNext = &rendering,
		stageCount = u32(len(stages)),
		pStages = raw_data(stages[:]),
		pVertexInputState = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState = &multisample,
		pColorBlendState = &blend,
		pDynamicState = &dynamic_state,
		layout = particle_life_gpu(sim).fade_pipeline.layout,
	}
	result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &particle_life_gpu(sim).fade_pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_fade_pipeline: CreateGraphicsPipelines failed result=", result)
		return false
	}
	return true
}

particle_life_create_fullscreen_pipeline :: proc(vk_ctx: ^engine.Vk_Context, vertex_module, fragment_module: engine.Vk_Shader_Module, vertex_entry, fragment_entry: string, set_layout: vk.DescriptorSetLayout, blend_enabled: bool, pipeline: ^engine.Vk_Graphics_Pipeline) -> bool {
	set_layouts := [1]vk.DescriptorSetLayout{set_layout}
	vertex_entry_c, vertex_err := strings.clone_to_cstring(vertex_entry, context.temp_allocator)
	if vertex_err != nil {
		return false
	}
	fragment_entry_c, fragment_err := strings.clone_to_cstring(fragment_entry, context.temp_allocator)
	if fragment_err != nil {
		return false
	}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = raw_data(set_layouts[:]),
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}
	stages := [2]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = vertex_module.handle, pName = vertex_entry_c},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = fragment_module.handle, pName = fragment_entry_c},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState {
		blendEnable = b32(blend_enabled),
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
	rendering := engine.vk_pipeline_rendering_info(&vk_ctx.swapchain_format)
	info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		pNext = &rendering,
		stageCount = u32(len(stages)),
		pStages = raw_data(stages[:]),
		pVertexInputState = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState = &multisample,
		pColorBlendState = &blend,
		pDynamicState = &dynamic_state,
		layout = pipeline.layout,
	}
	result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_fullscreen_pipeline: CreateGraphicsPipelines failed result=", result, " vertex_entry=", vertex_entry, " fragment_entry=", fragment_entry)
		return false
	}
	return true
}

particle_life_create_trail_resources :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if !particle_life_create_particle_pipeline(sim, vk_ctx, &particle_life_gpu(sim).trail_particle_pipeline) {
		return false
	}
	fade_bindings := [3]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	fade_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(fade_bindings)),
		pBindings = raw_data(fade_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &fade_layout_info, nil, &particle_life_gpu(sim).fade_set_layout) != .SUCCESS {
		return false
	}
	background_binding := vk.DescriptorSetLayoutBinding{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}}
	background_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = 1,
		pBindings = &background_binding,
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &background_layout_info, nil, &particle_life_gpu(sim).background_set_layout) != .SUCCESS {
		return false
	}
	post_bindings := [4]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}},
	}
	post_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(post_bindings)),
		pBindings = raw_data(post_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &post_layout_info, nil, &particle_life_gpu(sim).post_set_layout) != .SUCCESS {
		return false
	}
	pool_sizes := [3]vk.DescriptorPoolSize {
		{type = .UNIFORM_BUFFER, descriptorCount = 7 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .SAMPLED_IMAGE, descriptorCount = 4 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .SAMPLER, descriptorCount = 4 * engine.MAX_FRAMES_IN_FLIGHT},
	}
	pool_info := vk.DescriptorPoolCreateInfo {
		sType = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = u32(len(pool_sizes)),
		pPoolSizes = raw_data(pool_sizes[:]),
		maxSets = 5 * engine.MAX_FRAMES_IN_FLIGHT,
	}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &particle_life_gpu(sim).fade_descriptor_pool) != .SUCCESS {
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		fade_layouts := [2]vk.DescriptorSetLayout{particle_life_gpu(sim).fade_set_layout, particle_life_gpu(sim).fade_set_layout}
		fade_sets: [2]vk.DescriptorSet
		fade_alloc := vk.DescriptorSetAllocateInfo {
			sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
			descriptorPool = particle_life_gpu(sim).fade_descriptor_pool,
			descriptorSetCount = u32(len(fade_layouts)),
			pSetLayouts = raw_data(fade_layouts[:]),
		}
		if vk.AllocateDescriptorSets(vk_ctx.device, &fade_alloc, raw_data(fade_sets[:])) != .SUCCESS {
			return false
		}
		particle_life_gpu(sim).fade_sets[frame_slot][0] = fade_sets[0]
		particle_life_gpu(sim).fade_sets[frame_slot][1] = fade_sets[1]
		background_alloc := vk.DescriptorSetAllocateInfo {
			sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
			descriptorPool = particle_life_gpu(sim).fade_descriptor_pool,
			descriptorSetCount = 1,
			pSetLayouts = &particle_life_gpu(sim).background_set_layout,
		}
		if vk.AllocateDescriptorSets(vk_ctx.device, &background_alloc, &particle_life_gpu(sim).background_sets[frame_slot]) != .SUCCESS {
			return false
		}
		post_layouts := [2]vk.DescriptorSetLayout{particle_life_gpu(sim).post_set_layout, particle_life_gpu(sim).post_set_layout}
		post_sets: [2]vk.DescriptorSet
		post_alloc := vk.DescriptorSetAllocateInfo {
			sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
			descriptorPool = particle_life_gpu(sim).fade_descriptor_pool,
			descriptorSetCount = u32(len(post_layouts)),
			pSetLayouts = raw_data(post_layouts[:]),
		}
		if vk.AllocateDescriptorSets(vk_ctx.device, &post_alloc, raw_data(post_sets[:])) != .SUCCESS {
			return false
		}
		particle_life_gpu(sim).post_sets[frame_slot][0] = post_sets[0]
		particle_life_gpu(sim).post_sets[frame_slot][1] = post_sets[1]
	}
	sampler_info := vk.SamplerCreateInfo {sType = .SAMPLER_CREATE_INFO}
	sampler_info.magFilter = .LINEAR
	sampler_info.minFilter = .LINEAR
	sampler_info.mipmapMode = .LINEAR
	sampler_info.addressModeU = .CLAMP_TO_EDGE
	sampler_info.addressModeV = .CLAMP_TO_EDGE
	sampler_info.addressModeW = .CLAMP_TO_EDGE
	sampler_info.minLod = 0
	sampler_info.maxLod = 1
	if vk.CreateSampler(vk_ctx.device, &sampler_info, nil, &particle_life_gpu(sim).trail_sampler) != .SUCCESS {
		return false
	}
	if !particle_life_create_fade_pipeline(sim, vk_ctx) {
		return false
	}
	if !particle_life_create_fullscreen_pipeline(vk_ctx, particle_life_gpu(sim).background_vertex_shader_module, particle_life_gpu(sim).background_fragment_shader_module, PARTICLE_LIFE_BACKGROUND_VERTEX_ENTRY, PARTICLE_LIFE_BACKGROUND_FRAGMENT_ENTRY, particle_life_gpu(sim).background_set_layout, false, &particle_life_gpu(sim).background_pipeline) {
		return false
	}
	if !particle_life_create_fullscreen_pipeline(vk_ctx, particle_life_gpu(sim).post_vertex_shader_module, particle_life_gpu(sim).post_fragment_shader_module, PARTICLE_LIFE_POST_VERTEX_ENTRY, PARTICLE_LIFE_POST_FRAGMENT_ENTRY, particle_life_gpu(sim).post_set_layout, false, &particle_life_gpu(sim).post_pipeline) {
		return false
	}
	if !particle_life_create_fullscreen_pipeline(vk_ctx, particle_life_gpu(sim).infinite_present_vertex_shader_module, particle_life_gpu(sim).infinite_present_fragment_shader_module, PARTICLE_LIFE_INFINITE_PRESENT_VERTEX_ENTRY, PARTICLE_LIFE_INFINITE_PRESENT_FRAGMENT_ENTRY, particle_life_gpu(sim).post_set_layout, false, &particle_life_gpu(sim).tiled_post_pipeline) {
		return false
	}
	return true
}
