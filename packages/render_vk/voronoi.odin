package render_vk

import engine "../engine"
import uifw "../ui"

import "core:math"
import vk "vendor:vulkan"

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
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, VORONOI_JFA_ITERATION_SHADER_SOURCE, VORONOI_JFA_ITERATION_FALLBACK_SPV, .Compute, VORONOI_SOURCE_ENTRY, &gpu.jfa_iteration_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, VORONOI_BROWNIAN_SHADER_SOURCE, VORONOI_BROWNIAN_FALLBACK_SPV, .Compute, VORONOI_SOURCE_ENTRY, &gpu.brownian_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, VORONOI_RENDER_SHADER_SOURCE, VORONOI_RENDER_VERTEX_FALLBACK_SPV, .Vertex, VORONOI_VERTEX_SOURCE_ENTRY, &gpu.render_vertex_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, VORONOI_RENDER_SHADER_SOURCE, VORONOI_RENDER_FRAGMENT_FALLBACK_SPV, .Fragment, VORONOI_FRAGMENT_SOURCE_ENTRY, &gpu.render_fragment_shader) {
		voronoi_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Voronoi_Vertex) * int(gpu.point_count)), {.STORAGE_BUFFER}, &gpu.vertex_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT), {.STORAGE_BUFFER}, &gpu.lut_buffer) {
		voronoi_gpu_destroy(gpu, vk_ctx)
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Voronoi_Params)), {.UNIFORM_BUFFER}, &gpu.params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Voronoi_Uniforms)), {.UNIFORM_BUFFER}, &gpu.uniforms_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Voronoi_Brownian_Params)), {.UNIFORM_BUFFER}, &gpu.brownian_params_buffers[frame_slot]) {
			voronoi_gpu_destroy(gpu, vk_ctx)
			return false
		}
	}
	if !voronoi_create_image(gpu, vk_ctx, &gpu.jfa_image, target_width, target_height) ||
	   !voronoi_create_image(gpu, vk_ctx, &gpu.jfa_scratch_image, target_width, target_height) {
		voronoi_gpu_destroy(gpu, vk_ctx)
		return false
	}
	voronoi_initialize_points(gpu, settings)
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		voronoi_write_params(gpu, frame_slot, settings)
		voronoi_write_uniforms(gpu, frame_slot, settings, 0)
		voronoi_write_brownian_params(gpu, frame_slot, settings, 0)
	}
	if !voronoi_create_descriptors(gpu, vk_ctx) ||
	   !voronoi_create_compute_pipeline(gpu, vk_ctx) ||
	   !voronoi_create_jfa_iteration_pipeline(vk_ctx, gpu.jfa_iteration_shader.handle, gpu.jfa_iteration_set_layout, &gpu.jfa_iteration_pipeline) ||
	   !voronoi_create_single_compute_pipeline(vk_ctx, gpu.brownian_shader.handle, gpu.brownian_set_layout, &gpu.brownian_pipeline) ||
	   !voronoi_create_render_pipeline(gpu, vk_ctx) {
		voronoi_gpu_destroy(gpu, vk_ctx)
		return false
	}
	gpu.needs_rebuild = true
	gpu.ready = true
	return true
}

voronoi_create_image :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, image: ^Voronoi_Image, width, height: u32) -> bool {
	_ = gpu
	image^ = {width = width, height = height, layout = .UNDEFINED}
	info := vk.ImageCreateInfo{sType = .IMAGE_CREATE_INFO, imageType = .D2, format = VORONOI_IMAGE_FORMAT, extent = {width, height, 1}, mipLevels = 1, arrayLayers = 1, samples = {._1}, tiling = .OPTIMAL, usage = {.STORAGE, .SAMPLED, .TRANSFER_DST}, sharingMode = .EXCLUSIVE, initialLayout = .UNDEFINED}
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
		color := voronoi_next_random01(&rng)
		phase := voronoi_next_random01(&rng)
		seed := rng
		points[i] = {
			position = {x, y},
			color = color,
			pad0 = 0,
			phase = phase,
			seed = seed,
			pad1 = 0,
			random_state = rng,
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

voronoi_write_params :: proc(gpu: ^Voronoi_Gpu_State, frame_slot: int, settings: ^Voronoi_Settings, camera: ^Camera_Control_State = nil) {
	if gpu.params_buffers[frame_slot].mapped == nil {return}
	params := cast(^Voronoi_Params)gpu.params_buffers[frame_slot].mapped
	camera_data := camera_uniform_data(camera, f32(gpu.width), f32(gpu.height))
	tile_count := infinite_render_tile_count(camera_data.zoom)
	gpu.present_tile_count = tile_count
	params^ = {
		count = f32(gpu.point_count),
		color_mode = f32(settings.color_mode),
		border_enabled = settings.borders_enabled ? f32(1) : f32(0),
		border_width = settings.border_width,
		filter_mode = 1,
		resolution_x = f32(gpu.width),
		resolution_y = f32(gpu.height),
		jump_distance = f32(max(gpu.width, gpu.height)),
		camera_position = camera_data.position,
		camera_zoom = camera_data.zoom,
		tile_count = tile_count,
	}
}

voronoi_write_uniforms :: proc(gpu: ^Voronoi_Gpu_State, frame_slot: int, settings: ^Voronoi_Settings, time: f32) {
	if gpu.uniforms_buffers[frame_slot].mapped == nil {return}
	uniforms := cast(^Voronoi_Uniforms)gpu.uniforms_buffers[frame_slot].mapped
	uniforms^ = {
		resolution = {f32(gpu.width), f32(gpu.height)},
		time = time,
		drift = settings.drift,
	}
}

voronoi_write_brownian_params :: proc(gpu: ^Voronoi_Gpu_State, frame_slot: int, settings: ^Voronoi_Settings, delta_time: f32) {
	if gpu.brownian_params_buffers[frame_slot].mapped == nil {return}
	params := cast(^Voronoi_Brownian_Params)gpu.brownian_params_buffers[frame_slot].mapped
	params^ = {
		speed = settings.brownian_speed,
		delta_time = delta_time,
	}
}

voronoi_create_descriptors :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	jfa_bindings := [3]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	render_bindings := [3]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX, .FRAGMENT}},
		{binding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	brownian_bindings := [3]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	jfa_iteration_bindings := [3]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	if !voronoi_create_set_layout(vk_ctx, jfa_bindings[:], &gpu.jfa_set_layout) ||
	   !voronoi_create_set_layout(vk_ctx, jfa_iteration_bindings[:], &gpu.jfa_iteration_set_layout) ||
	   !voronoi_create_set_layout(vk_ctx, brownian_bindings[:], &gpu.brownian_set_layout) ||
	   !voronoi_create_set_layout(vk_ctx, render_bindings[:], &gpu.render_set_layout) {return false}
	pool_sizes := [4]vk.DescriptorPoolSize{{type = .STORAGE_BUFFER, descriptorCount = 4 * engine.MAX_FRAMES_IN_FLIGHT}, {type = .UNIFORM_BUFFER, descriptorCount = 6 * engine.MAX_FRAMES_IN_FLIGHT}, {type = .STORAGE_IMAGE, descriptorCount = 3 * engine.MAX_FRAMES_IN_FLIGHT}, {type = .SAMPLED_IMAGE, descriptorCount = 3 * engine.MAX_FRAMES_IN_FLIGHT}}
	pool_info := vk.DescriptorPoolCreateInfo{sType = .DESCRIPTOR_POOL_CREATE_INFO, poolSizeCount = u32(len(pool_sizes)), pPoolSizes = raw_data(pool_sizes[:]), maxSets = 5 * engine.MAX_FRAMES_IN_FLIGHT}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &gpu.descriptor_pool) != .SUCCESS {return false}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		layouts := [3]vk.DescriptorSetLayout{gpu.jfa_set_layout, gpu.brownian_set_layout, gpu.render_set_layout}
		sets: [3]vk.DescriptorSet
		alloc := vk.DescriptorSetAllocateInfo{sType = .DESCRIPTOR_SET_ALLOCATE_INFO, descriptorPool = gpu.descriptor_pool, descriptorSetCount = 3, pSetLayouts = raw_data(layouts[:])}
		if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(sets[:])) != .SUCCESS {return false}
		gpu.jfa_sets[frame_slot] = sets[0]
		gpu.brownian_sets[frame_slot] = sets[1]
		gpu.render_sets[frame_slot] = sets[2]
		iteration_layouts := [2]vk.DescriptorSetLayout{gpu.jfa_iteration_set_layout, gpu.jfa_iteration_set_layout}
		iteration_alloc := vk.DescriptorSetAllocateInfo{sType = .DESCRIPTOR_SET_ALLOCATE_INFO, descriptorPool = gpu.descriptor_pool, descriptorSetCount = 2, pSetLayouts = raw_data(iteration_layouts[:])}
		if vk.AllocateDescriptorSets(vk_ctx.device, &iteration_alloc, raw_data(gpu.jfa_iteration_sets[frame_slot][:])) != .SUCCESS {return false}
	}
	voronoi_update_descriptors(gpu, vk_ctx)
	return true
}

voronoi_create_set_layout :: proc(vk_ctx: ^engine.Vk_Context, bindings: []vk.DescriptorSetLayoutBinding, out: ^vk.DescriptorSetLayout) -> bool {
	info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(bindings)), pBindings = raw_data(bindings)}
	return vk.CreateDescriptorSetLayout(vk_ctx.device, &info, nil, out) == .SUCCESS
}

voronoi_update_descriptors :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		voronoi_update_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	}
}

voronoi_update_descriptors_for_slot :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	vertex_info := vk.DescriptorBufferInfo{buffer = gpu.vertex_buffer.handle, offset = 0, range = gpu.vertex_buffer.size}
	params_info := vk.DescriptorBufferInfo{buffer = gpu.params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Voronoi_Params))}
	uniforms_info := vk.DescriptorBufferInfo{buffer = gpu.uniforms_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Voronoi_Uniforms))}
	brownian_params_info := vk.DescriptorBufferInfo{buffer = gpu.brownian_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Voronoi_Brownian_Params))}
	lut_info := vk.DescriptorBufferInfo{buffer = gpu.lut_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT)}
	jfa_storage := vk.DescriptorImageInfo{imageLayout = .GENERAL, imageView = gpu.jfa_image.view}
	jfa_sampled := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.jfa_image.view}
	jfa_compute_read := vk.DescriptorImageInfo{imageLayout = .GENERAL, imageView = gpu.jfa_image.view}
	jfa_compute_write := vk.DescriptorImageInfo{imageLayout = .GENERAL, imageView = gpu.jfa_scratch_image.view}
	scratch_compute_read := vk.DescriptorImageInfo{imageLayout = .GENERAL, imageView = gpu.jfa_scratch_image.view}
	scratch_compute_write := vk.DescriptorImageInfo{imageLayout = .GENERAL, imageView = gpu.jfa_image.view}
	jfa_set := gpu.jfa_sets[frame_slot]
	brownian_set := gpu.brownian_sets[frame_slot]
	render_set := gpu.render_sets[frame_slot]
	writes := [?]vk.WriteDescriptorSet{
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = jfa_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vertex_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = jfa_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = jfa_set, dstBinding = 2, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, pImageInfo = &jfa_storage},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = brownian_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vertex_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = brownian_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &uniforms_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = brownian_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &brownian_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = render_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = render_set, dstBinding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &lut_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = render_set, dstBinding = 2, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &jfa_sampled},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.jfa_iteration_sets[frame_slot][0], dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.jfa_iteration_sets[frame_slot][0], dstBinding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &jfa_compute_read},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.jfa_iteration_sets[frame_slot][0], dstBinding = 2, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, pImageInfo = &jfa_compute_write},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.jfa_iteration_sets[frame_slot][1], dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.jfa_iteration_sets[frame_slot][1], dstBinding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &scratch_compute_read},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.jfa_iteration_sets[frame_slot][1], dstBinding = 2, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, pImageInfo = &scratch_compute_write},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
}

voronoi_update_render_image :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	image := gpu.jfa_result_is_scratch ? &gpu.jfa_scratch_image : &gpu.jfa_image
	info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = image.view}
	write := vk.WriteDescriptorSet{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.render_sets[frame_slot], dstBinding = 2, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &info}
	vk.UpdateDescriptorSets(vk_ctx.device, 1, &write, 0, nil)
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

voronoi_create_jfa_iteration_pipeline :: proc(vk_ctx: ^engine.Vk_Context, shader: vk.ShaderModule, set_layout: vk.DescriptorSetLayout, out: ^engine.Vk_Compute_Pipeline) -> bool {
	layouts := [1]vk.DescriptorSetLayout{set_layout}
	push_range := vk.PushConstantRange{stageFlags = {.COMPUTE}, offset = 0, size = size_of(u32)}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = raw_data(layouts[:]), pushConstantRangeCount = 1, pPushConstantRanges = &push_range}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &out.layout) != .SUCCESS {return false}
	stage := vk.PipelineShaderStageCreateInfo{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.COMPUTE}, module = shader, pName = VORONOI_ENTRY}
	info := vk.ComputePipelineCreateInfo{sType = .COMPUTE_PIPELINE_CREATE_INFO, stage = stage, layout = out.layout}
	return vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &out.pipeline) == .SUCCESS
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
		dst_access = {.SHADER_WRITE, .TRANSFER_WRITE}
		dst_stage = {.COMPUTE_SHADER, .TRANSFER}
	} else if new_layout == .SHADER_READ_ONLY_OPTIMAL {
		dst_access = {.SHADER_READ}
		dst_stage = {.COMPUTE_SHADER, .FRAGMENT_SHADER}
	}
	barrier := vk.ImageMemoryBarrier{sType = .IMAGE_MEMORY_BARRIER, srcAccessMask = src_access, dstAccessMask = dst_access, oldLayout = image.layout, newLayout = new_layout, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, image = image.handle, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	vk.CmdPipelineBarrier(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	image.layout = new_layout
}

voronoi_gpu_step :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim: ^Remaining_Sim_State, delta_time: f32) {
	if !voronoi_gpu_ensure(gpu, vk_ctx, &sim.voronoi) {return}
	voronoi_apply_interaction(gpu, sim, delta_time)
	voronoi_gpu_step_ready(gpu, vk_ctx, cmd, &sim.voronoi, delta_time, sim.paused)
}

voronoi_apply_interaction :: proc(gpu: ^Voronoi_Gpu_State, sim: ^Remaining_Sim_State, dt: f32) {
	if gpu.vertex_buffer.mapped == nil || gpu.point_count == 0 {return}
	points := (cast([^]Voronoi_Vertex)gpu.vertex_buffer.mapped)[:gpu.point_count]
	// The Voronoi image is presented with Vulkan's downward-positive viewport Y,
	// so its site coordinates use the same orientation as cursor_world.
	cursor := voronoi_cursor_texture_position(sim.cursor_world, gpu.width, gpu.height)
	cx, cy := cursor[0], cursor[1]
	radius := max(min(f32(gpu.width), f32(gpu.height)) * max(sim.cursor_size, 0.01) * 0.5, 8)
	strength := max(sim.cursor_strength, 0)
	changed := false
	if sim.voronoi_interaction_mode == 3 {
		if !sim.voronoi_grabbed {
			best := 0
			best_d2 := f32(3.4e38)
			for i in 0 ..< int(gpu.point_count) {
				dx := points[i].position[0] - cx; dy := points[i].position[1] - cy
				d2 := dx*dx + dy*dy
				if d2 < best_d2 {best_d2 = d2; best = i}
			}
			sim.voronoi_grabbed = true
			sim.voronoi_grabbed_index = u32(best)
		}
		points[sim.voronoi_grabbed_index].position = {cx, cy}
		changed = true
	} else if sim.voronoi_interaction_mode == 4 || sim.voronoi_interaction_mode == 5 {
		// Painting/erasing recycles nearby sites, preserving the fixed GPU buffer.
		stride := sim.voronoi_interaction_mode == 4 ? max(int(gpu.point_count / 12), 1) : 1
		for i := 0; i < int(gpu.point_count); i += stride {
			if sim.voronoi_interaction_mode == 4 {
				a := f32(i) * 2.399963
				points[i].position = {cx + math.cos(a)*12, cy + math.sin(a)*12}
			} else {
				dx := points[i].position[0]-cx; dy := points[i].position[1]-cy
				if dx*dx+dy*dy < radius*radius {points[i].position = {f32((i*977)%int(gpu.width)), f32((i*619)%int(gpu.height))}}
			}
			changed = true
		}
	} else if sim.voronoi_interaction_mode == 1 || sim.voronoi_interaction_mode == 2 {
		sign := sim.voronoi_interaction_mode == 1 ? f32(-1) : f32(1)
		for i in 0 ..< int(gpu.point_count) {
			dx := points[i].position[0]-cx; dy := points[i].position[1]-cy; d2 := dx*dx+dy*dy
			if d2 > 1 && d2 < radius*radius {s := sign*900*strength*dt*(1-math.sqrt(d2)/radius)/math.sqrt(d2); points[i].position[0] += dx*s; points[i].position[1] += dy*s; changed = true}
		}
	}
	if sim.voronoi_interaction_mode == 6 && sim.voronoi_pressed {
		for i in 0 ..< int(gpu.point_count) {
			dx := points[i].position[0]-cx; dy := points[i].position[1]-cy; d := max(math.sqrt(dx*dx+dy*dy), 1)
			if d < radius*1.5 {s := 36*strength*(1-d/(radius*1.5)); points[i].position[0] += dx/d*s; points[i].position[1] += dy/d*s; changed = true}
		}
	}
	if sim.voronoi_released && sim.voronoi_grabbed {
		i := sim.voronoi_grabbed_index
		// A short ballistic kick makes release read as a fling; Brownian drift
		// naturally takes over again after the impulse.
		points[i].position[0] += sim.cursor_world_velocity[0] * f32(gpu.width) * 0.06
		points[i].position[1] += sim.cursor_world_velocity[1] * f32(gpu.height) * 0.06
		sim.voronoi_grabbed = false
		changed = true
	}
	if changed {gpu.needs_rebuild = true}
}

voronoi_cursor_texture_position :: proc(cursor_world: [2]f32, width, height: u32) -> [2]f32 {
	return {
		(cursor_world[0] + 1) * 0.5 * f32(width),
		(cursor_world[1] + 1) * 0.5 * f32(height),
	}
}

voronoi_gpu_step_size :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, settings: ^Voronoi_Settings, delta_time: f32, paused: bool, width, height: u32) {
	if !voronoi_gpu_ensure_size(gpu, vk_ctx, settings, width, height) {return}
	voronoi_gpu_step_ready(gpu, vk_ctx, cmd, settings, delta_time, paused)
}

voronoi_gpu_step_ready :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, settings: ^Voronoi_Settings, delta_time: f32, paused: bool) {
	frame_slot := int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	voronoi_upload_lut(gpu, settings)
	dt := delta_time * max(settings.time_scale, 0)
	if !paused {
		gpu.time_accum += dt
	}
	voronoi_write_uniforms(gpu, frame_slot, settings, gpu.time_accum)
	voronoi_write_params(gpu, frame_slot, settings)
	voronoi_write_brownian_params(gpu, frame_slot, settings, dt)
	point_groups := max((gpu.point_count + 127) / 128, 1)
	if !paused && settings.brownian_speed != 0 && settings.drift != 0 && dt != 0 {
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.brownian_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		brownian_set := gpu.brownian_sets[frame_slot]
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.brownian_pipeline.layout, 0, 1, &brownian_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDispatch(cmd, point_groups, 1, 1)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		voronoi_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER, .FRAGMENT_SHADER})
		gpu.needs_rebuild = true
	}
	if gpu.needs_rebuild {
		voronoi_transition_image(vk_ctx, cmd, &gpu.jfa_image, .GENERAL)
		voronoi_transition_image(vk_ctx, cmd, &gpu.jfa_scratch_image, .GENERAL)
		// Give every pixel a valid fallback seed before scattering the remaining
		// sites. Sparse JFA seeds can otherwise leave unassigned islands on
		// non-power-of-two, toroidally wrapped targets.
		points := (cast([^]Voronoi_Vertex)gpu.vertex_buffer.mapped)[:gpu.point_count]
		fallback := points[0].position
		clear := vk.ClearColorValue{float32 = {fallback[0], fallback[1], 0, 1e28}}
		range := vk.ImageSubresourceRange{aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}
		vk.CmdClearColorImage(cmd, gpu.jfa_image.handle, .GENERAL, &clear, 1, &range)
		voronoi_transfer_to_compute_barrier(vk_ctx, cmd)
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.jfa_init_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		jfa_set := gpu.jfa_sets[frame_slot]
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.jfa_init_pipeline.layout, 0, 1, &jfa_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDispatch(cmd, point_groups, 1, 1)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		voronoi_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.jfa_iteration_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		jump := u32(1)
		for jump < max(gpu.width, gpu.height) {jump *= 2}
		ping := 0
		for jump >= 1 {
			set := gpu.jfa_iteration_sets[frame_slot][ping]
			vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.jfa_iteration_pipeline.layout, 0, 1, &set, 0, nil)
			engine.vk_cmd_count_descriptor_bind(vk_ctx)
			vk.CmdPushConstants(cmd, gpu.jfa_iteration_pipeline.layout, {.COMPUTE}, 0, size_of(u32), &jump)
			vk.CmdDispatch(cmd, (gpu.width + 7) / 8, (gpu.height + 7) / 8, 1)
			engine.vk_cmd_count_compute_dispatch(vk_ctx)
			voronoi_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
			ping = 1 - ping
			jump /= 2
		}
		gpu.jfa_result_is_scratch = ping == 1
		voronoi_update_render_image(gpu, vk_ctx, frame_slot)
		gpu.needs_rebuild = false
	}
}

voronoi_compute_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dst: vk.PipelineStageFlags) {
	barrier := vk.MemoryBarrier{sType = .MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.SHADER_READ, .SHADER_WRITE}}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, dst, {}, 1, &barrier, 0, nil, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

voronoi_transfer_to_compute_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	barrier := vk.MemoryBarrier{sType = .MEMORY_BARRIER, srcAccessMask = {.TRANSFER_WRITE}, dstAccessMask = {.SHADER_READ, .SHADER_WRITE}}
	vk.CmdPipelineBarrier(cmd, {.TRANSFER}, {.COMPUTE_SHADER}, {}, 1, &barrier, 0, nil, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

voronoi_gpu_present :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, camera: ^Camera_Control_State = nil) {
	viewport := vk.Viewport{x = 0, y = 0, width = f32(vk_ctx.swapchain_extent.width), height = f32(vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = vk_ctx.swapchain_extent}
	voronoi_gpu_present_viewport(gpu, vk_ctx, frame, viewport, scissor, camera)
}

voronoi_gpu_present_viewport :: proc(gpu: ^Voronoi_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D, camera: ^Camera_Control_State = nil) {
	if !gpu.ready || gpu.render_pipeline.pipeline == vk.Pipeline(0) {return}
	image := gpu.jfa_result_is_scratch ? &gpu.jfa_scratch_image : &gpu.jfa_image
	voronoi_transition_image(vk_ctx, frame.command_buffer, image, .SHADER_READ_ONLY_OPTIMAL)
	frame_slot := int(frame.frame_index)
	// Only camera fields differ from the step upload; settings fields remain in
	// the same mapped uniform and are refreshed by the simulation step.
	if gpu.params_buffers[frame_slot].mapped != nil {
		params := cast(^Voronoi_Params)gpu.params_buffers[frame_slot].mapped
		camera_data := camera_uniform_data(camera, viewport.width, viewport.height)
		params.camera_position = camera_data.position
		params.camera_zoom = camera_data.zoom
		params.tile_count = infinite_render_tile_count(camera_data.zoom)
		gpu.present_tile_count = params.tile_count
	}
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
	render_set := gpu.render_sets[int(frame.frame_index)]
	vk.CmdBindDescriptorSets(frame.command_buffer, .GRAPHICS, gpu.render_pipeline.layout, 0, 1, &render_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	tile_count := max(gpu.present_tile_count, 1)
	vk.CmdDraw(frame.command_buffer, 6, tile_count * tile_count, 0, 0)
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
	voronoi_destroy_compute_pipeline(vk_ctx, &gpu.jfa_iteration_pipeline)
	voronoi_destroy_compute_pipeline(vk_ctx, &gpu.brownian_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.render_pipeline)
	if gpu.descriptor_pool != vk.DescriptorPool(0) {vk.DestroyDescriptorPool(vk_ctx.device, gpu.descriptor_pool, nil)}
	if gpu.jfa_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.jfa_set_layout, nil)}
	if gpu.jfa_iteration_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.jfa_iteration_set_layout, nil)}
	if gpu.brownian_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.brownian_set_layout, nil)}
	if gpu.render_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.render_set_layout, nil)}
	engine.vk_destroy_buffer(vk_ctx, &gpu.vertex_buffer)
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		engine.vk_destroy_buffer(vk_ctx, &gpu.params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.uniforms_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.brownian_params_buffers[frame_slot])
	}
	engine.vk_destroy_buffer(vk_ctx, &gpu.lut_buffer)
	voronoi_destroy_image(vk_ctx, &gpu.jfa_image)
	voronoi_destroy_image(vk_ctx, &gpu.jfa_scratch_image)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.jfa_init_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.jfa_iteration_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.brownian_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.render_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.render_fragment_shader)
	gpu^ = {}
}
