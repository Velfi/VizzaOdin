package game

import engine "../engine"
import uifw "../ui"

import "core:math"
import vk "vendor:vulkan"

VORONOI_JFA_INIT_SHADER_SOURCE :: "assets/shaders/simulations/voronoi_ca/shaders/jfa_init.slang"
VORONOI_ADJACENCY_BUILD_SHADER_SOURCE :: "assets/shaders/simulations/voronoi_ca/shaders/adjacency_build.slang"
VORONOI_ADJACENCY_COUNT_SHADER_SOURCE :: "assets/shaders/simulations/voronoi_ca/shaders/adjacency_count.slang"
VORONOI_UPDATE_SHADER_SOURCE :: "assets/shaders/simulations/voronoi_ca/shaders/compute_update.slang"
VORONOI_BROWNIAN_SHADER_SOURCE :: "assets/shaders/simulations/voronoi_ca/shaders/brownian.slang"
VORONOI_RENDER_SHADER_SOURCE :: "assets/shaders/simulations/voronoi_ca/shaders/voronoi_render_jfa.slang"
VORONOI_JFA_INIT_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/jfa_init"
VORONOI_ADJACENCY_BUILD_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/adjacency_build"
VORONOI_ADJACENCY_COUNT_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/adjacency_count"
VORONOI_UPDATE_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/compute_update"
VORONOI_BROWNIAN_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/brownian"
VORONOI_RENDER_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/voronoi_render_jfa_vertex"
VORONOI_RENDER_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/voronoi_render_jfa_fragment"
VORONOI_SOURCE_ENTRY :: "main"
VORONOI_VERTEX_SOURCE_ENTRY :: "vs_main"
VORONOI_FRAGMENT_SOURCE_ENTRY :: "fs_main"
VORONOI_ENTRY :: cstring("main")
VORONOI_VERTEX_ENTRY :: cstring("main")
VORONOI_FRAGMENT_ENTRY :: cstring("main")
VORONOI_MAX_NEIGHBORS :: u32(16)
VORONOI_IMAGE_FORMAT :: vk.Format(.R32G32B32A32_SFLOAT)

Voronoi_Vertex :: struct #align(8) {
	position: [2]f32,
	state: f32,
	pad0: f32,
	age: f32,
	alive_neighbors: u32,
	dead_neighbors: u32,
	pad1: u32,
}

Voronoi_Params :: struct #align(16) {
	count: f32,
	color_mode: f32,
	border_enabled: f32,
	border_width: f32,
	filter_mode: f32,
	resolution_x: f32,
	resolution_y: f32,
	jump_distance: f32,
}

Voronoi_Uniforms :: struct #align(16) {
	resolution: [2]f32,
	time: f32,
	drift: f32,
	rule_type: u32,
	_pad0: u32,
	_pad1: u32,
	_pad2: u32,
}

Voronoi_Brownian_Params :: struct #align(8) {
	speed: f32,
	delta_time: f32,
}

Voronoi_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	layout: vk.ImageLayout,
	width: u32,
	height: u32,
}

Voronoi_Gpu_State :: struct {
	width: u32,
	height: u32,
	jfa_init_shader: engine.Vk_Shader_Module,
	adjacency_build_shader: engine.Vk_Shader_Module,
	adjacency_count_shader: engine.Vk_Shader_Module,
	update_shader: engine.Vk_Shader_Module,
	brownian_shader: engine.Vk_Shader_Module,
	render_vertex_shader: engine.Vk_Shader_Module,
	render_fragment_shader: engine.Vk_Shader_Module,
	jfa_init_pipeline: engine.Vk_Compute_Pipeline,
	adjacency_build_pipeline: engine.Vk_Compute_Pipeline,
	adjacency_count_pipeline: engine.Vk_Compute_Pipeline,
	update_pipeline: engine.Vk_Compute_Pipeline,
	brownian_pipeline: engine.Vk_Compute_Pipeline,
	render_pipeline: engine.Vk_Graphics_Pipeline,
	jfa_set_layout: vk.DescriptorSetLayout,
	adjacency_build_set_layout: vk.DescriptorSetLayout,
	adjacency_count_set_layout: vk.DescriptorSetLayout,
	update_set_layout: vk.DescriptorSetLayout,
	brownian_set_layout: vk.DescriptorSetLayout,
	render_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	jfa_set: vk.DescriptorSet,
	adjacency_build_set: vk.DescriptorSet,
	adjacency_count_set: vk.DescriptorSet,
	update_set: vk.DescriptorSet,
	brownian_set: vk.DescriptorSet,
	render_set: vk.DescriptorSet,
	vertex_buffer: engine.Vk_Buffer,
	params_buffer: engine.Vk_Buffer,
	uniforms_buffer: engine.Vk_Buffer,
	brownian_params_buffer: engine.Vk_Buffer,
	neighbors_buffer: engine.Vk_Buffer,
	degrees_buffer: engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	jfa_image: Voronoi_Image,
	point_count: u32,
	time_accum: f32,
	needs_rebuild: bool,
	adjacency_valid: bool,
	ready: bool,
}

voronoi_gpu_ensure :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Voronoi_Settings) -> bool {
	width := max(vk_ctx.swapchain_extent.width, 1)
	height := max(vk_ctx.swapchain_extent.height, 1)
	return voronoi_gpu_ensure_size(gpu, vk_ctx, settings, width, height)
}

voronoi_gpu_ensure_size :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Voronoi_Settings, width, height: u32) -> bool {
	target_width := max(width, 1)
	target_height := max(height, 1)
	point_count := max(settings.point_count, 1)
	if gpu.ready && gpu.width == target_width && gpu.height == target_height && gpu.point_count == point_count {
		return true
	}
	voronoi_gpu_destroy(gpu, vk_ctx)
	gpu.width = target_width
	gpu.height = target_height
	gpu.point_count = point_count
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, VORONOI_JFA_INIT_SHADER_SOURCE, VORONOI_JFA_INIT_FALLBACK_SPV, .Compute, VORONOI_SOURCE_ENTRY, &gpu.jfa_init_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, VORONOI_ADJACENCY_BUILD_SHADER_SOURCE, VORONOI_ADJACENCY_BUILD_FALLBACK_SPV, .Compute, VORONOI_SOURCE_ENTRY, &gpu.adjacency_build_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, VORONOI_ADJACENCY_COUNT_SHADER_SOURCE, VORONOI_ADJACENCY_COUNT_FALLBACK_SPV, .Compute, VORONOI_SOURCE_ENTRY, &gpu.adjacency_count_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, VORONOI_UPDATE_SHADER_SOURCE, VORONOI_UPDATE_FALLBACK_SPV, .Compute, VORONOI_SOURCE_ENTRY, &gpu.update_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, VORONOI_BROWNIAN_SHADER_SOURCE, VORONOI_BROWNIAN_FALLBACK_SPV, .Compute, VORONOI_SOURCE_ENTRY, &gpu.brownian_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, VORONOI_RENDER_SHADER_SOURCE, VORONOI_RENDER_VERTEX_FALLBACK_SPV, .Vertex, VORONOI_VERTEX_SOURCE_ENTRY, &gpu.render_vertex_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, VORONOI_RENDER_SHADER_SOURCE, VORONOI_RENDER_FRAGMENT_FALLBACK_SPV, .Fragment, VORONOI_FRAGMENT_SOURCE_ENTRY, &gpu.render_fragment_shader) {
		voronoi_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Voronoi_Vertex) * int(gpu.point_count)), {.STORAGE_BUFFER}, &gpu.vertex_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Voronoi_Params)), {.UNIFORM_BUFFER}, &gpu.params_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Voronoi_Uniforms)), {.UNIFORM_BUFFER}, &gpu.uniforms_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Voronoi_Brownian_Params)), {.UNIFORM_BUFFER}, &gpu.brownian_params_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(gpu.point_count * VORONOI_MAX_NEIGHBORS)), {.STORAGE_BUFFER}, &gpu.neighbors_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(gpu.point_count)), {.STORAGE_BUFFER}, &gpu.degrees_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT), {.STORAGE_BUFFER}, &gpu.lut_buffer) {
		voronoi_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !voronoi_create_image(gpu, vk_ctx, &gpu.jfa_image, target_width, target_height) {
		voronoi_gpu_destroy(gpu, vk_ctx)
		return false
	}
	voronoi_initialize_points(gpu, settings)
	voronoi_write_params(gpu, settings)
	voronoi_write_uniforms(gpu, settings, 0)
	if !voronoi_create_descriptors(gpu, vk_ctx) ||
	   !voronoi_create_compute_pipeline(gpu, vk_ctx) ||
	   !voronoi_create_adjacency_pipelines(gpu, vk_ctx) ||
	   !voronoi_create_single_compute_pipeline(vk_ctx, gpu.brownian_shader.handle, gpu.brownian_set_layout, &gpu.brownian_pipeline) ||
	   !voronoi_create_render_pipeline(gpu, vk_ctx) {
		voronoi_gpu_destroy(gpu, vk_ctx)
		return false
	}
	gpu.needs_rebuild = true
	gpu.adjacency_valid = false
	gpu.ready = true
	return true
}

voronoi_create_image :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, image: ^Voronoi_Image, width, height: u32) -> bool {
	_ = gpu
	image^ = {width = width, height = height, layout = .UNDEFINED}
	info := vk.ImageCreateInfo{sType = .IMAGE_CREATE_INFO, imageType = .D2, format = VORONOI_IMAGE_FORMAT, extent = {width, height, 1}, mipLevels = 1, arrayLayers = 1, samples = {._1}, tiling = .OPTIMAL, usage = {.STORAGE, .SAMPLED}, sharingMode = .EXCLUSIVE, initialLayout = .UNDEFINED}
	if vk.CreateImage(vk_ctx.device, &info, nil, &image.handle) != .SUCCESS {return false}
	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device, image.handle, &req)
	memory_type, ok := engine.vk_find_memory_type(vk_ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {return false}
	alloc := vk.MemoryAllocateInfo{sType = .MEMORY_ALLOCATE_INFO, allocationSize = req.size, memoryTypeIndex = memory_type}
	if vk.AllocateMemory(vk_ctx.device, &alloc, nil, &image.memory) != .SUCCESS {return false}
	if vk.BindImageMemory(vk_ctx.device, image.handle, image.memory, 0) != .SUCCESS {return false}
	view_info := vk.ImageViewCreateInfo{sType = .IMAGE_VIEW_CREATE_INFO, image = image.handle, viewType = .D2, format = VORONOI_IMAGE_FORMAT, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	return vk.CreateImageView(vk_ctx.device, &view_info, nil, &image.view) == .SUCCESS
}

voronoi_initialize_points :: proc(gpu: ^Voronoi_Gpu_State, settings: ^Voronoi_Settings) {
	if gpu.vertex_buffer.mapped == nil {return}
	points := (cast([^]Voronoi_Vertex)gpu.vertex_buffer.mapped)[:gpu.point_count]
	rng := settings.random_seed
	if rng == 0 {rng = 42}
	for i in 0 ..< int(gpu.point_count) {
		x := voronoi_next_random01(&rng) * f32(gpu.width)
		y := voronoi_next_random01(&rng) * f32(gpu.height)
		state := voronoi_next_random01(&rng) > 0.5 ? f32(1) : f32(0)
		points[i] = {
			position = {x, y},
			state = state,
			pad0 = 0,
			age = voronoi_next_random01(&rng),
			alive_neighbors = u32(voronoi_next_random01(&rng) * 8),
			dead_neighbors = u32(voronoi_next_random01(&rng) * 8),
			pad1 = rng,
		}
	}
}

voronoi_next_random01 :: proc(rng: ^u32) -> f32 {
	rng^ = rng^ ~ (rng^ << 13)
	rng^ = rng^ ~ (rng^ >> 17)
	rng^ = rng^ ~ (rng^ << 5)
	return f32(rng^) / f32(0xffffffff)
}

voronoi_upload_lut :: proc(gpu: ^Voronoi_Gpu_State, settings: ^Voronoi_Settings) {
	if gpu.lut_buffer.mapped == nil {return}
	scheme := color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
	data := (cast([^]u32)gpu.lut_buffer.mapped)[:COLOR_SCHEME_U32_COUNT]
	_ = color_scheme_write_u32_buffer(scheme, data)
}

voronoi_write_params :: proc(gpu: ^Voronoi_Gpu_State, settings: ^Voronoi_Settings) {
	if gpu.params_buffer.mapped == nil {return}
	params := cast(^Voronoi_Params)gpu.params_buffer.mapped
	params^ = {
		count = f32(gpu.point_count),
		color_mode = f32(settings.color_mode),
		border_enabled = settings.borders_enabled ? f32(1) : f32(0),
		border_width = settings.border_width,
		filter_mode = 1,
		resolution_x = f32(gpu.width),
		resolution_y = f32(gpu.height),
		jump_distance = f32(max(gpu.width, gpu.height)),
	}
}

voronoi_write_uniforms :: proc(gpu: ^Voronoi_Gpu_State, settings: ^Voronoi_Settings, time: f32) {
	if gpu.uniforms_buffer.mapped == nil {return}
	uniforms := cast(^Voronoi_Uniforms)gpu.uniforms_buffer.mapped
	uniforms^ = {
		resolution = {f32(gpu.width), f32(gpu.height)},
		time = time,
		drift = settings.drift,
		rule_type = voronoi_rule_type(settings),
	}
}

voronoi_write_brownian_params :: proc(gpu: ^Voronoi_Gpu_State, settings: ^Voronoi_Settings, delta_time: f32) {
	if gpu.brownian_params_buffer.mapped == nil {return}
	params := cast(^Voronoi_Brownian_Params)gpu.brownian_params_buffer.mapped
	params^ = {
		speed = settings.brownian_speed,
		delta_time = delta_time,
	}
}

voronoi_rule_type :: proc(settings: ^Voronoi_Settings) -> u32 {
	rule := fixed_string(settings.rulestring[:])
	switch rule {
	case "B1357/S1357": return 0
	case "B2/S": return 1
	case "B25/S4": return 2
	case "B3/S012345678": return 3
	case "B3/S23": return 4
	case "B3/S1234": return 5
	case "B3/S12345": return 6
	case "B34/S34": return 7
	case "B35678/S5678": return 8
	case "B36/S125": return 9
	case "B36/S23": return 10
	case "B368/S245": return 11
	case "B4678/S35678": return 12
	case "B5678/S45678": return 13
	case "B6/S16": return 14
	case "B6/S1": return 15
	case "B6/S12": return 16
	case "B6/S123": return 17
	case "B6/S15": return 18
	case "B6/S2": return 19
	case "B7/S": return 20
	case "B8/S": return 21
	case "B9/S": return 22
	}
	return 4
}

voronoi_create_descriptors :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	jfa_bindings := [3]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	render_bindings := [4]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 3, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	adjacency_build_bindings := [5]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 4, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	adjacency_count_bindings := [4]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	update_bindings := [2]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	brownian_bindings := [3]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	if !voronoi_create_set_layout(vk_ctx, jfa_bindings[:], &gpu.jfa_set_layout) ||
	   !voronoi_create_set_layout(vk_ctx, adjacency_build_bindings[:], &gpu.adjacency_build_set_layout) ||
	   !voronoi_create_set_layout(vk_ctx, adjacency_count_bindings[:], &gpu.adjacency_count_set_layout) ||
	   !voronoi_create_set_layout(vk_ctx, update_bindings[:], &gpu.update_set_layout) ||
	   !voronoi_create_set_layout(vk_ctx, brownian_bindings[:], &gpu.brownian_set_layout) ||
	   !voronoi_create_set_layout(vk_ctx, render_bindings[:], &gpu.render_set_layout) {return false}
	pool_sizes := [4]vk.DescriptorPoolSize{{type = .STORAGE_BUFFER, descriptorCount = 13}, {type = .UNIFORM_BUFFER, descriptorCount = 8}, {type = .STORAGE_IMAGE, descriptorCount = 1}, {type = .SAMPLED_IMAGE, descriptorCount = 2}}
	pool_info := vk.DescriptorPoolCreateInfo{sType = .DESCRIPTOR_POOL_CREATE_INFO, poolSizeCount = u32(len(pool_sizes)), pPoolSizes = raw_data(pool_sizes[:]), maxSets = 6}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &gpu.descriptor_pool) != .SUCCESS {return false}
	layouts := [6]vk.DescriptorSetLayout{gpu.jfa_set_layout, gpu.adjacency_build_set_layout, gpu.adjacency_count_set_layout, gpu.update_set_layout, gpu.brownian_set_layout, gpu.render_set_layout}
	sets: [6]vk.DescriptorSet
	alloc := vk.DescriptorSetAllocateInfo{sType = .DESCRIPTOR_SET_ALLOCATE_INFO, descriptorPool = gpu.descriptor_pool, descriptorSetCount = 6, pSetLayouts = raw_data(layouts[:])}
	if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(sets[:])) != .SUCCESS {return false}
	gpu.jfa_set = sets[0]
	gpu.adjacency_build_set = sets[1]
	gpu.adjacency_count_set = sets[2]
	gpu.update_set = sets[3]
	gpu.brownian_set = sets[4]
	gpu.render_set = sets[5]
	voronoi_update_descriptors(gpu, vk_ctx)
	return true
}

voronoi_create_set_layout :: proc(vk_ctx: ^engine.Vk_Context, bindings: []vk.DescriptorSetLayoutBinding, out: ^vk.DescriptorSetLayout) -> bool {
	info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(bindings)), pBindings = raw_data(bindings)}
	return vk.CreateDescriptorSetLayout(vk_ctx.device, &info, nil, out) == .SUCCESS
}

voronoi_update_descriptors :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	vertex_info := vk.DescriptorBufferInfo{buffer = gpu.vertex_buffer.handle, offset = 0, range = gpu.vertex_buffer.size}
	params_info := vk.DescriptorBufferInfo{buffer = gpu.params_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Voronoi_Params))}
	uniforms_info := vk.DescriptorBufferInfo{buffer = gpu.uniforms_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Voronoi_Uniforms))}
	brownian_params_info := vk.DescriptorBufferInfo{buffer = gpu.brownian_params_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Voronoi_Brownian_Params))}
	neighbors_info := vk.DescriptorBufferInfo{buffer = gpu.neighbors_buffer.handle, offset = 0, range = gpu.neighbors_buffer.size}
	degrees_info := vk.DescriptorBufferInfo{buffer = gpu.degrees_buffer.handle, offset = 0, range = gpu.degrees_buffer.size}
	lut_info := vk.DescriptorBufferInfo{buffer = gpu.lut_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT)}
	jfa_storage := vk.DescriptorImageInfo{imageLayout = .GENERAL, imageView = gpu.jfa_image.view}
	jfa_sampled := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.jfa_image.view}
	writes := [?]vk.WriteDescriptorSet{
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.jfa_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vertex_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.jfa_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.jfa_set, dstBinding = 2, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, pImageInfo = &jfa_storage},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.adjacency_build_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vertex_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.adjacency_build_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &uniforms_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.adjacency_build_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &neighbors_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.adjacency_build_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &degrees_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.adjacency_build_set, dstBinding = 4, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &jfa_sampled},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.adjacency_count_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vertex_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.adjacency_count_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &uniforms_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.adjacency_count_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &neighbors_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.adjacency_count_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &degrees_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.update_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vertex_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.update_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &uniforms_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.brownian_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vertex_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.brownian_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &uniforms_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.brownian_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &brownian_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.render_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.render_set, dstBinding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vertex_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.render_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &lut_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.render_set, dstBinding = 3, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &jfa_sampled},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
}

voronoi_create_compute_pipeline :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	layouts := [1]vk.DescriptorSetLayout{gpu.jfa_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gpu.jfa_init_pipeline.layout) != .SUCCESS {return false}
	stage := vk.PipelineShaderStageCreateInfo{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.COMPUTE}, module = gpu.jfa_init_shader.handle, pName = VORONOI_ENTRY}
	info := vk.ComputePipelineCreateInfo{sType = .COMPUTE_PIPELINE_CREATE_INFO, stage = stage, layout = gpu.jfa_init_pipeline.layout}
	return vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &gpu.jfa_init_pipeline.pipeline) == .SUCCESS
}

voronoi_create_single_compute_pipeline :: proc(vk_ctx: ^engine.Vk_Context, shader: vk.ShaderModule, set_layout: vk.DescriptorSetLayout, out: ^engine.Vk_Compute_Pipeline) -> bool {
	layouts := [1]vk.DescriptorSetLayout{set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &out.layout) != .SUCCESS {return false}
	stage := vk.PipelineShaderStageCreateInfo{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.COMPUTE}, module = shader, pName = VORONOI_ENTRY}
	info := vk.ComputePipelineCreateInfo{sType = .COMPUTE_PIPELINE_CREATE_INFO, stage = stage, layout = out.layout}
	return vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &out.pipeline) == .SUCCESS
}

voronoi_create_adjacency_pipelines :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	return voronoi_create_single_compute_pipeline(vk_ctx, gpu.adjacency_build_shader.handle, gpu.adjacency_build_set_layout, &gpu.adjacency_build_pipeline) &&
	       voronoi_create_single_compute_pipeline(vk_ctx, gpu.adjacency_count_shader.handle, gpu.adjacency_count_set_layout, &gpu.adjacency_count_pipeline) &&
	       voronoi_create_single_compute_pipeline(vk_ctx, gpu.update_shader.handle, gpu.update_set_layout, &gpu.update_pipeline)
}

voronoi_create_render_pipeline :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	layouts := [1]vk.DescriptorSetLayout{gpu.render_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gpu.render_pipeline.layout) != .SUCCESS {return false}
	stages := [2]vk.PipelineShaderStageCreateInfo{
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = gpu.render_vertex_shader.handle, pName = VORONOI_VERTEX_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = gpu.render_fragment_shader.handle, pName = VORONOI_FRAGMENT_ENTRY},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState{blendEnable = false, colorWriteMask = {.R, .G, .B, .A}}
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = 2, pDynamicStates = raw_data(dynamic_states[:])}
	info := vk.GraphicsPipelineCreateInfo{sType = .GRAPHICS_PIPELINE_CREATE_INFO, stageCount = 2, pStages = raw_data(stages[:]), pVertexInputState = &vertex_input, pInputAssemblyState = &input_assembly, pViewportState = &viewport_state, pRasterizationState = &raster, pMultisampleState = &multisample, pColorBlendState = &blend, pDynamicState = &dynamic_state, layout = gpu.render_pipeline.layout, renderPass = vk_ctx.render_pass, subpass = 0}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &gpu.render_pipeline.pipeline) == .SUCCESS
}

voronoi_transition_image :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, image: ^Voronoi_Image, new_layout: vk.ImageLayout) {
	if image.layout == new_layout {return}
	src_access: vk.AccessFlags
	dst_access: vk.AccessFlags
	src_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	dst_stage := vk.PipelineStageFlags{.COMPUTE_SHADER}
	if image.layout == .GENERAL {
		src_access = {.SHADER_WRITE}
		src_stage = {.COMPUTE_SHADER}
	} else if image.layout == .SHADER_READ_ONLY_OPTIMAL {
		src_access = {.SHADER_READ}
		src_stage = {.COMPUTE_SHADER, .FRAGMENT_SHADER}
	}
	if new_layout == .GENERAL {
		dst_access = {.SHADER_WRITE}
		dst_stage = {.COMPUTE_SHADER}
	} else if new_layout == .SHADER_READ_ONLY_OPTIMAL {
		dst_access = {.SHADER_READ}
		dst_stage = {.COMPUTE_SHADER, .FRAGMENT_SHADER}
	}
	barrier := vk.ImageMemoryBarrier{sType = .IMAGE_MEMORY_BARRIER, srcAccessMask = src_access, dstAccessMask = dst_access, oldLayout = image.layout, newLayout = new_layout, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, image = image.handle, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	vk.CmdPipelineBarrier(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	image.layout = new_layout
}

voronoi_gpu_step :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, settings: ^Voronoi_Settings, delta_time: f32, paused: bool) {
	if !voronoi_gpu_ensure(gpu, vk_ctx, settings) {return}
	voronoi_gpu_step_ready(gpu, vk_ctx, cmd, settings, delta_time, paused)
}

voronoi_gpu_step_size :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, settings: ^Voronoi_Settings, delta_time: f32, paused: bool, width, height: u32) {
	if !voronoi_gpu_ensure_size(gpu, vk_ctx, settings, width, height) {return}
	voronoi_gpu_step_ready(gpu, vk_ctx, cmd, settings, delta_time, paused)
}

voronoi_gpu_step_ready :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, settings: ^Voronoi_Settings, delta_time: f32, paused: bool) {
	voronoi_upload_lut(gpu, settings)
	dt := delta_time * max(settings.time_scale, 0)
	if !paused {
		gpu.time_accum += dt
	}
	voronoi_write_uniforms(gpu, settings, gpu.time_accum)
	voronoi_write_params(gpu, settings)
	voronoi_write_brownian_params(gpu, settings, dt)
	point_groups := max((gpu.point_count + 127) / 128, 1)
	if !paused && settings.brownian_speed != 0 && settings.drift != 0 && dt != 0 {
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.brownian_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.brownian_pipeline.layout, 0, 1, &gpu.brownian_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDispatch(cmd, point_groups, 1, 1)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		voronoi_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER, .FRAGMENT_SHADER})
		gpu.needs_rebuild = true
		gpu.adjacency_valid = false
	}
	if gpu.needs_rebuild {
		voronoi_transition_image(vk_ctx, cmd, &gpu.jfa_image, .GENERAL)
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.jfa_init_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.jfa_init_pipeline.layout, 0, 1, &gpu.jfa_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDispatch(cmd, (gpu.width + 15) / 16, (gpu.height + 15) / 16, 1)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		voronoi_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER, .FRAGMENT_SHADER})
		gpu.needs_rebuild = false
		gpu.adjacency_valid = false
	}
	if !gpu.adjacency_valid {
		voronoi_transition_image(vk_ctx, cmd, &gpu.jfa_image, .SHADER_READ_ONLY_OPTIMAL)
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.adjacency_build_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.adjacency_build_pipeline.layout, 0, 1, &gpu.adjacency_build_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDispatch(cmd, point_groups, 1, 1)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		voronoi_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
		gpu.adjacency_valid = true
	}
	if !paused {
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.adjacency_count_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.adjacency_count_pipeline.layout, 0, 1, &gpu.adjacency_count_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDispatch(cmd, point_groups, 1, 1)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		voronoi_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER, .FRAGMENT_SHADER})
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.update_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.update_pipeline.layout, 0, 1, &gpu.update_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDispatch(cmd, point_groups, 1, 1)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		voronoi_compute_barrier(vk_ctx, cmd, {.FRAGMENT_SHADER})
	}
}

voronoi_compute_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dst: vk.PipelineStageFlags) {
	barrier := vk.MemoryBarrier{sType = .MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.SHADER_READ, .SHADER_WRITE}}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, dst, {}, 1, &barrier, 0, nil, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

voronoi_gpu_present :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame) {
	viewport := vk.Viewport{x = 0, y = 0, width = f32(vk_ctx.swapchain_extent.width), height = f32(vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = vk_ctx.swapchain_extent}
	voronoi_gpu_present_viewport(gpu, vk_ctx, frame, viewport, scissor)
}

voronoi_gpu_present_viewport :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gpu.ready || gpu.render_pipeline.pipeline == vk.Pipeline(0) {return}
	voronoi_transition_image(vk_ctx, frame.command_buffer, &gpu.jfa_image, .SHADER_READ_ONLY_OPTIMAL)
	voronoi_gpu_draw_prepared_viewport(gpu, vk_ctx, frame, viewport, scissor)
}

voronoi_gpu_draw_prepared_viewport :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gpu.ready || gpu.render_pipeline.pipeline == vk.Pipeline(0) {return}
	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(frame.command_buffer, 0, 1, &local_viewport)
	vk.CmdSetScissor(frame.command_buffer, 0, 1, &local_scissor)
	vk.CmdBindPipeline(frame.command_buffer, .GRAPHICS, gpu.render_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(frame.command_buffer, .GRAPHICS, gpu.render_pipeline.layout, 0, 1, &gpu.render_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDraw(frame.command_buffer, 3, 1, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
}

voronoi_clear_color :: proc() -> uifw.Color {
	return {0, 0, 0, 1}
}

voronoi_destroy_compute_pipeline :: proc(vk_ctx: ^engine.Vk_Context, pipeline: ^engine.Vk_Compute_Pipeline) {
	if pipeline.pipeline != vk.Pipeline(0) {vk.DestroyPipeline(vk_ctx.device, pipeline.pipeline, nil)}
	if pipeline.layout != vk.PipelineLayout(0) {vk.DestroyPipelineLayout(vk_ctx.device, pipeline.layout, nil)}
	pipeline^ = {}
}

voronoi_destroy_image :: proc(vk_ctx: ^engine.Vk_Context, image: ^Voronoi_Image) {
	if image.view != vk.ImageView(0) {vk.DestroyImageView(vk_ctx.device, image.view, nil)}
	if image.handle != vk.Image(0) {vk.DestroyImage(vk_ctx.device, image.handle, nil)}
	if image.memory != vk.DeviceMemory(0) {vk.FreeMemory(vk_ctx.device, image.memory, nil)}
	image^ = {}
}

voronoi_gpu_destroy :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	if vk_ctx == nil || vk_ctx.device == nil {gpu^ = {}; return}
	voronoi_destroy_compute_pipeline(vk_ctx, &gpu.jfa_init_pipeline)
	voronoi_destroy_compute_pipeline(vk_ctx, &gpu.adjacency_build_pipeline)
	voronoi_destroy_compute_pipeline(vk_ctx, &gpu.adjacency_count_pipeline)
	voronoi_destroy_compute_pipeline(vk_ctx, &gpu.update_pipeline)
	voronoi_destroy_compute_pipeline(vk_ctx, &gpu.brownian_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.render_pipeline)
	if gpu.descriptor_pool != vk.DescriptorPool(0) {vk.DestroyDescriptorPool(vk_ctx.device, gpu.descriptor_pool, nil)}
	if gpu.jfa_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.jfa_set_layout, nil)}
	if gpu.adjacency_build_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.adjacency_build_set_layout, nil)}
	if gpu.adjacency_count_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.adjacency_count_set_layout, nil)}
	if gpu.update_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.update_set_layout, nil)}
	if gpu.brownian_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.brownian_set_layout, nil)}
	if gpu.render_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.render_set_layout, nil)}
	engine.vk_destroy_buffer(vk_ctx, &gpu.vertex_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.params_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.uniforms_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.brownian_params_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.neighbors_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.degrees_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.lut_buffer)
	voronoi_destroy_image(vk_ctx, &gpu.jfa_image)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.jfa_init_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.adjacency_build_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.adjacency_count_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.update_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.brownian_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.render_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.render_fragment_shader)
	gpu^ = {}
}
