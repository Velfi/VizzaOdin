package render_vk

import engine "../engine"

import vk "vendor:vulkan"

MAIN_MENU_BACKDROP_SHADER_SOURCE :: "assets/shaders/simulations/main_menu/shaders/combined.slang"
MAIN_MENU_BACKDROP_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/main_menu/shaders/combined_vertex"
MAIN_MENU_BACKDROP_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/main_menu/shaders/combined_fragment"
MAIN_MENU_BACKDROP_VERTEX_SOURCE_ENTRY :: "vs_main"
MAIN_MENU_BACKDROP_FRAGMENT_SOURCE_ENTRY :: "fs_main"
MAIN_MENU_BACKDROP_VERTEX_ENTRY :: cstring("main")
MAIN_MENU_BACKDROP_FRAGMENT_ENTRY :: cstring("main")
MAIN_MENU_BACKDROP_TIME_SCALE :: f32(0.03)

Main_Menu_Backdrop_Gpu_State :: struct {
	vertex_shader: engine.Vk_Shader_Module,
	fragment_shader: engine.Vk_Shader_Module,
	pipeline: engine.Vk_Graphics_Pipeline,
	time_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	time_set_layout: vk.DescriptorSetLayout,
	lut_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	time_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	lut_set: vk.DescriptorSet,
	time_seconds: f32,
	active_frame_slot: u32,
	palette_name: Color_Scheme_Name,
	palette_index: int,
	palette_seed: u32,
	palette_initialized: bool,
	lut_dirty: bool,
	ready: bool,
}

main_menu_backdrop_ensure :: proc(gpu: ^Main_Menu_Backdrop_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	if gpu.ready {
		return true
	}
	main_menu_backdrop_destroy(gpu, vk_ctx)

	if !engine.vk_load_shader_module_with_fallback(vk_ctx, MAIN_MENU_BACKDROP_SHADER_SOURCE, MAIN_MENU_BACKDROP_VERTEX_FALLBACK_SPV, .Vertex, MAIN_MENU_BACKDROP_VERTEX_SOURCE_ENTRY, &gpu.vertex_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, MAIN_MENU_BACKDROP_SHADER_SOURCE, MAIN_MENU_BACKDROP_FRAGMENT_FALLBACK_SPV, .Fragment, MAIN_MENU_BACKDROP_FRAGMENT_SOURCE_ENTRY, &gpu.fragment_shader) {
		engine.log_error("main_menu_backdrop_ensure: shader load failed")
		main_menu_backdrop_destroy(gpu, vk_ctx)
		return false
	}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(f32)), {.UNIFORM_BUFFER}, &gpu.time_buffers[i]) {
			engine.log_error("main_menu_backdrop_ensure: time buffer creation failed")
			main_menu_backdrop_destroy(gpu, vk_ctx)
			return false
		}
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT), {.STORAGE_BUFFER}, &gpu.lut_buffer) {
		engine.log_error("main_menu_backdrop_ensure: buffer creation failed")
		main_menu_backdrop_destroy(gpu, vk_ctx)
		return false
	}
	main_menu_backdrop_upload_lut(gpu)

	if !main_menu_backdrop_create_descriptors(gpu, vk_ctx) ||
	   !main_menu_backdrop_create_pipeline(gpu, vk_ctx) {
		engine.log_error("main_menu_backdrop_ensure: descriptor or pipeline creation failed")
		main_menu_backdrop_destroy(gpu, vk_ctx)
		return false
	}

	gpu.ready = true
	return true
}

main_menu_backdrop_upload_lut :: proc(gpu: ^Main_Menu_Backdrop_Gpu_State) {
	if gpu.lut_buffer.mapped == nil {
		return
	}
	scheme: Color_Scheme
	name := color_scheme_name_get(&gpu.palette_name)
	ok := false
	if len(name) > 0 {
		scheme, ok = color_scheme_load(name)
	}
	if ok {
		color_scheme_reverse(&scheme)
	} else {
		scheme = color_scheme_default()
	}
	data := (cast([^]u32)gpu.lut_buffer.mapped)[:COLOR_SCHEME_U32_COUNT]
	_ = color_scheme_write_u32_buffer(scheme, data)
	gpu.lut_dirty = false
}

main_menu_backdrop_select_next_palette :: proc(gpu: ^Main_Menu_Backdrop_Gpu_State) {
	names := color_scheme_available_names_cached()
	if len(names) == 0 {
		color_scheme_name_set(&gpu.palette_name, COLOR_SCHEME_DEFAULT_NAME)
		gpu.palette_index = 0
		gpu.palette_initialized = true
		gpu.lut_dirty = true
		return
	}

	next_index := int(main_menu_backdrop_random_u32(gpu) % u32(len(names)))
	current_name := color_scheme_name_get(&gpu.palette_name)
	for attempt in 0 ..< len(names) {
		if !gpu.palette_initialized || names[next_index] != current_name {
			break
		}
		next_index = (next_index + 1) % len(names)
	}
	gpu.palette_index = next_index
	gpu.palette_initialized = true
	color_scheme_name_set(&gpu.palette_name, names[next_index])
	gpu.lut_dirty = true
}

main_menu_backdrop_seed_palette :: proc(gpu: ^Main_Menu_Backdrop_Gpu_State, seed: u64) {
	mixed := seed + 0x9e3779b97f4a7c15
	mixed = (mixed ~ (mixed >> 30)) * 0xbf58476d1ce4e5b9
	mixed = (mixed ~ (mixed >> 27)) * 0x94d049bb133111eb
	mixed = mixed ~ (mixed >> 31)
	gpu.palette_seed = u32(mixed) ~ u32(mixed >> 32)
	if gpu.palette_seed == 0 {
		gpu.palette_seed = 0x6d2b79f5
	}
}

main_menu_backdrop_random_u32 :: proc(gpu: ^Main_Menu_Backdrop_Gpu_State) -> u32 {
	if gpu.palette_seed == 0 {
		gpu.palette_seed = 0x6d2b79f5
	}
	x := gpu.palette_seed + 0x9e3779b9
	x = (x ~ (x >> 16)) * 0x7feb352d
	x = (x ~ (x >> 15)) * 0x846ca68b
	x = x ~ (x >> 16)
	gpu.palette_seed = x
	return x
}

main_menu_backdrop_current_palette_name :: proc(gpu: ^Main_Menu_Backdrop_Gpu_State) -> string {
	return color_scheme_name_get(&gpu.palette_name)
}

main_menu_backdrop_create_descriptors :: proc(gpu: ^Main_Menu_Backdrop_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	time_binding := vk.DescriptorSetLayoutBinding{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}}
	time_layout_info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = 1, pBindings = &time_binding}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &time_layout_info, nil, &gpu.time_set_layout) != .SUCCESS {
		return false
	}

	lut_binding := vk.DescriptorSetLayoutBinding{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}}
	lut_layout_info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = 1, pBindings = &lut_binding}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &lut_layout_info, nil, &gpu.lut_set_layout) != .SUCCESS {
		return false
	}

	pool_sizes := [2]vk.DescriptorPoolSize{
		{type = .UNIFORM_BUFFER, descriptorCount = engine.MAX_FRAMES_IN_FLIGHT},
		{type = .STORAGE_BUFFER, descriptorCount = 1},
	}
	pool_info := vk.DescriptorPoolCreateInfo{sType = .DESCRIPTOR_POOL_CREATE_INFO, poolSizeCount = u32(len(pool_sizes)), pPoolSizes = raw_data(pool_sizes[:]), maxSets = engine.MAX_FRAMES_IN_FLIGHT + 1}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &gpu.descriptor_pool) != .SUCCESS {
		return false
	}

	layouts: [engine.MAX_FRAMES_IN_FLIGHT + 1]vk.DescriptorSetLayout
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		layouts[i] = gpu.time_set_layout
	}
	layouts[engine.MAX_FRAMES_IN_FLIGHT] = gpu.lut_set_layout
	sets: [engine.MAX_FRAMES_IN_FLIGHT + 1]vk.DescriptorSet
	alloc := vk.DescriptorSetAllocateInfo{sType = .DESCRIPTOR_SET_ALLOCATE_INFO, descriptorPool = gpu.descriptor_pool, descriptorSetCount = u32(len(layouts)), pSetLayouts = raw_data(layouts[:])}
	if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(sets[:])) != .SUCCESS {
		return false
	}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		gpu.time_sets[i] = sets[i]
		time_info := vk.DescriptorBufferInfo{buffer = gpu.time_buffers[i].handle, offset = 0, range = vk.DeviceSize(size_of(f32))}
		write := vk.WriteDescriptorSet{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.time_sets[i], dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &time_info}
		vk.UpdateDescriptorSets(vk_ctx.device, 1, &write, 0, nil)
	}
	gpu.lut_set = sets[engine.MAX_FRAMES_IN_FLIGHT]

	lut_info := vk.DescriptorBufferInfo{buffer = gpu.lut_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT)}
	lut_write := vk.WriteDescriptorSet{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.lut_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &lut_info}
	vk.UpdateDescriptorSets(vk_ctx.device, 1, &lut_write, 0, nil)
	return true
}

main_menu_backdrop_create_pipeline :: proc(gpu: ^Main_Menu_Backdrop_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	layouts := [2]vk.DescriptorSetLayout{gpu.time_set_layout, gpu.lut_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = u32(len(layouts)), pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gpu.pipeline.layout) != .SUCCESS {
		return false
	}

	stages := [2]vk.PipelineShaderStageCreateInfo{
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = gpu.vertex_shader.handle, pName = MAIN_MENU_BACKDROP_VERTEX_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = gpu.fragment_shader.handle, pName = MAIN_MENU_BACKDROP_FRAGMENT_ENTRY},
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
	rendering := engine.vk_pipeline_rendering_info(&vk_ctx.swapchain_format)
	info := vk.GraphicsPipelineCreateInfo{sType = .GRAPHICS_PIPELINE_CREATE_INFO, pNext = &rendering, stageCount = u32(len(stages)), pStages = raw_data(stages[:]), pVertexInputState = &vertex_input, pInputAssemblyState = &input_assembly, pViewportState = &viewport_state, pRasterizationState = &raster, pMultisampleState = &multisample, pColorBlendState = &blend, pDynamicState = &dynamic_state, layout = gpu.pipeline.layout}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &gpu.pipeline.pipeline) == .SUCCESS
}

main_menu_backdrop_draw :: proc(gpu: ^Main_Menu_Backdrop_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, dt: f32) {
	if !main_menu_backdrop_ensure(gpu, vk_ctx) {
		return
	}
	if gpu.lut_dirty {
		main_menu_backdrop_upload_lut(gpu)
	}
	gpu.time_seconds += max(dt, 0) * MAIN_MENU_BACKDROP_TIME_SCALE
	frame_slot := frame.frame_index % engine.MAX_FRAMES_IN_FLIGHT
	gpu.active_frame_slot = frame_slot
	time_buffer := &gpu.time_buffers[frame_slot]
	time_set := gpu.time_sets[frame_slot]
	if time_buffer.mapped != nil {
		(cast(^f32)time_buffer.mapped)^ = gpu.time_seconds
	}

	cmd := frame.command_buffer
	viewport := vk.Viewport{x = 0, y = 0, width = f32(vk_ctx.swapchain_extent.width), height = f32(vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = vk_ctx.swapchain_extent}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.pipeline.layout, 0, 1, &time_set, 0, nil)
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.pipeline.layout, 1, 1, &gpu.lut_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDraw(cmd, 6, 1, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
}

main_menu_backdrop_destroy :: proc(gpu: ^Main_Menu_Backdrop_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	palette_name := gpu.palette_name
	palette_index := gpu.palette_index
	palette_seed := gpu.palette_seed
	palette_initialized := gpu.palette_initialized
	lut_dirty := gpu.lut_dirty
	time_seconds := gpu.time_seconds

	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.pipeline)
	if gpu.descriptor_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, gpu.descriptor_pool, nil)
	}
	if gpu.time_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.time_set_layout, nil)
	}
	if gpu.lut_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.lut_set_layout, nil)
	}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		engine.vk_destroy_buffer(vk_ctx, &gpu.time_buffers[i])
	}
	engine.vk_destroy_buffer(vk_ctx, &gpu.lut_buffer)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.fragment_shader)
	gpu^ = {}
	gpu.palette_name = palette_name
	gpu.palette_index = palette_index
	gpu.palette_seed = palette_seed
	gpu.palette_initialized = palette_initialized
	gpu.lut_dirty = lut_dirty
	gpu.time_seconds = time_seconds
}
