package render_vk

import engine "../engine"
import uifw "../ui"

import "core:fmt"
import "core:math"
import vk "vendor:vulkan"

slime_gpu_ensure :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Slime_Settings) -> bool {
	width := max(vk_ctx.swapchain_extent.width, 1)
	height := max(vk_ctx.swapchain_extent.height, 1)
	return slime_gpu_ensure_size(gpu, vk_ctx, settings, width, height)
}

slime_gpu_ensure_size :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Slime_Settings, width, height: u32) -> bool {
	return slime_gpu_ensure_size_count(gpu, vk_ctx, settings, width, height, SLIME_AGENT_COUNT)
}

slime_gpu_ensure_size_count :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Slime_Settings, width, height, agent_count: u32) -> bool {
	target_width := max(width, 1)
	target_height := max(height, 1)
	target_agent_count := max(agent_count, 1)
	if gpu.ready && gpu.width == target_width && gpu.height == target_height && gpu.agent_count == target_agent_count {
		return true
	}
	slime_gpu_destroy(gpu, vk_ctx)
	gpu.width = target_width
	gpu.height = target_height
	gpu.agent_count = target_agent_count
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, SLIME_COMPUTE_SHADER_SOURCE, SLIME_UPDATE_FALLBACK_SPV, .Compute, SLIME_SOURCE_ENTRY_UPDATE, &gpu.update_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, SLIME_COMPUTE_SHADER_SOURCE, SLIME_DECAY_FALLBACK_SPV, .Compute, SLIME_SOURCE_ENTRY_DECAY, &gpu.decay_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, SLIME_COMPUTE_SHADER_SOURCE, SLIME_DIFFUSE_FALLBACK_SPV, .Compute, SLIME_SOURCE_ENTRY_DIFFUSE, &gpu.diffuse_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, SLIME_COMPUTE_SHADER_SOURCE, SLIME_UPDATE_SPEEDS_FALLBACK_SPV, .Compute, SLIME_SOURCE_ENTRY_UPDATE_SPEEDS, &gpu.update_speeds_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, SLIME_COMPUTE_SHADER_SOURCE, SLIME_RESET_FALLBACK_SPV, .Compute, SLIME_SOURCE_ENTRY_RESET, &gpu.reset_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, SLIME_GRADIENT_SHADER_SOURCE, SLIME_GRADIENT_FALLBACK_SPV, .Compute, SLIME_SOURCE_ENTRY_GRADIENT, &gpu.gradient_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, SLIME_DISPLAY_SHADER_SOURCE, SLIME_DISPLAY_FALLBACK_SPV, .Compute, SLIME_SOURCE_ENTRY_DISPLAY, &gpu.display_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, SLIME_PRESENT_SHADER_SOURCE, SLIME_PRESENT_VERTEX_FALLBACK_SPV, .Vertex, SLIME_PRESENT_VERTEX_SOURCE_ENTRY, &gpu.present_vertex_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, SLIME_PRESENT_SHADER_SOURCE, SLIME_PRESENT_FRAGMENT_FALLBACK_SPV, .Fragment, SLIME_PRESENT_FRAGMENT_SOURCE_ENTRY, &gpu.present_fragment_shader) {
		slime_gpu_destroy(gpu, vk_ctx)
		return false
	}
	pixel_count := int(target_width * target_height)
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of([4]f32) * int(gpu.agent_count)), {.STORAGE_BUFFER}, &gpu.agent_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(f32) * pixel_count), {.STORAGE_BUFFER}, &gpu.trail_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(f32) * pixel_count), {.STORAGE_BUFFER}, &gpu.mask_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(f32) * pixel_count), {.STORAGE_BUFFER}, &gpu.gradient_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT), {.STORAGE_BUFFER}, &gpu.lut_buffer) {
		slime_gpu_destroy(gpu, vk_ctx)
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Slime_Sim_Uniform)), {.UNIFORM_BUFFER}, &gpu.sim_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Slime_Cursor_Params)), {.UNIFORM_BUFFER}, &gpu.cursor_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Slime_Render_Params)), {.UNIFORM_BUFFER}, &gpu.render_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Slime_Camera)), {.UNIFORM_BUFFER}, &gpu.camera_buffers[frame_slot]) {
			slime_gpu_destroy(gpu, vk_ctx)
			return false
		}
	}
	slime_clear_host_buffers(gpu)
	if !slime_create_image(gpu, vk_ctx, &gpu.display_image, target_width, target_height, {.STORAGE, .SAMPLED, .TRANSFER_DST}) ||
	   !slime_create_sampler(gpu, vk_ctx) {
		slime_gpu_destroy(gpu, vk_ctx)
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		slime_upload_render_params(gpu, frame_slot, settings)
		slime_upload_camera(gpu, frame_slot)
		slime_write_uniforms(gpu, frame_slot, settings, 0, {0, 0}, 0.20, 1.0, 1.0 / 60.0)
	}
	if !slime_create_descriptors(gpu, vk_ctx) {
		slime_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !slime_create_compute_pipeline(vk_ctx, gpu.update_shader.handle, SLIME_ENTRY_UPDATE, gpu.sim_set_layout, &gpu.update_pipeline) ||
	   !slime_create_compute_pipeline(vk_ctx, gpu.decay_shader.handle, SLIME_ENTRY_DECAY, gpu.sim_set_layout, &gpu.decay_pipeline) ||
	   !slime_create_compute_pipeline(vk_ctx, gpu.diffuse_shader.handle, SLIME_ENTRY_DIFFUSE, gpu.sim_set_layout, &gpu.diffuse_pipeline) ||
	   !slime_create_compute_pipeline(vk_ctx, gpu.update_speeds_shader.handle, SLIME_ENTRY_UPDATE_SPEEDS, gpu.sim_set_layout, &gpu.update_speeds_pipeline) ||
	   !slime_create_compute_pipeline(vk_ctx, gpu.reset_shader.handle, SLIME_ENTRY_RESET, gpu.sim_set_layout, &gpu.reset_pipeline) ||
	   !slime_create_compute_pipeline(vk_ctx, gpu.gradient_shader.handle, SLIME_ENTRY_GRADIENT, gpu.sim_set_layout, &gpu.gradient_pipeline) ||
	   !slime_create_compute_pipeline(vk_ctx, gpu.display_shader.handle, SLIME_ENTRY_DISPLAY, gpu.display_set_layout, &gpu.display_pipeline) ||
	   !slime_create_present_pipeline(gpu, vk_ctx) {
		slime_gpu_destroy(gpu, vk_ctx)
		return false
	}
	gpu.needs_reset = true
	gpu.ready = true
	return true
}

slime_clear_host_buffers :: proc(gpu: ^Slime_Gpu_State) {
	if gpu.trail_buffer.mapped != nil {
		data := (cast([^]f32)gpu.trail_buffer.mapped)[:int(gpu.width * gpu.height)]
		for i in 0 ..< len(data) {
			data[i] = 0
		}
	}
	if gpu.mask_buffer.mapped != nil {
		data := (cast([^]f32)gpu.mask_buffer.mapped)[:int(gpu.width * gpu.height)]
		for i in 0 ..< len(data) {
			data[i] = 0
		}
	}
	if gpu.gradient_buffer.mapped != nil {
		data := (cast([^]f32)gpu.gradient_buffer.mapped)[:int(gpu.width * gpu.height)]
		for i in 0 ..< len(data) {
			data[i] = 0
		}
	}
}

slime_clear_trail_buffer :: proc(gpu: ^Slime_Gpu_State) {
	if gpu.trail_buffer.mapped == nil {
		return
	}
	data := (cast([^]f32)gpu.trail_buffer.mapped)[:int(gpu.width * gpu.height)]
	for i in 0 ..< len(data) {
		data[i] = 0
	}
}

slime_load_image_to_mask_buffer :: proc(gpu: ^Slime_Gpu_State, path: string, fit_mode: Vector_Image_Fit_Mode) -> bool {
	ok, reason := slime_load_image_to_mask_buffer_diagnostic(gpu, path, fit_mode)
	_ = reason
	return ok
}

slime_load_image_to_mask_buffer_diagnostic :: proc(gpu: ^Slime_Gpu_State, path: string, fit_mode: Vector_Image_Fit_Mode) -> (ok: bool, reason: string) {
	if len(path) == 0 || gpu.mask_buffer.mapped == nil || gpu.width == 0 || gpu.height == 0 {
		if len(path) == 0 {
			return false, "empty path"
		}
		if gpu.mask_buffer.mapped == nil {
			return false, "Slime mask buffer is not mapped; GPU resources are not ready"
		}
		return false, fmt.tprintf("Slime GPU target size is invalid: width=%d height=%d", gpu.width, gpu.height)
	}
	img, image_reason := shared_image_load_rgba8_diagnostic(path)
	if img == nil {
		return false, image_reason
	}
	defer shared_image_destroy(img)
	target_width := int(max(gpu.width, 1))
	target_height := int(max(gpu.height, 1))
	values := (cast([^]f32)gpu.mask_buffer.mapped)[:target_width * target_height]
	source := raw_data(img.pixels.buf[:])
	for y := 0; y < target_height; y += 1 {
		for x := 0; x < target_width; x += 1 {
			src_x, src_y: int
			value := u8(0)
			if vectors_image_source_coord(int(img.width), int(img.height), target_width, target_height, x, y, fit_mode, &src_x, &src_y) {
				value = vectors_sample_image_source(source, int(img.width), int(img.height), int(img.width) * 4, src_x, src_y)
			}
			values[y * target_width + x] = f32(value) / 255.0
		}
	}
	return true, ""
}

slime_gpu_load_mask_image_path :: proc(gpu: ^Slime_Gpu_State, path: string, settings: ^Slime_Settings) -> bool {
	ok, reason := slime_gpu_load_mask_image_path_diagnostic(gpu, path, settings)
	_ = reason
	return ok
}

slime_gpu_load_mask_image_path_diagnostic :: proc(gpu: ^Slime_Gpu_State, path: string, settings: ^Slime_Settings) -> (ok: bool, reason: string) {
	buffer_ok, buffer_reason := slime_load_image_to_mask_buffer_diagnostic(gpu, path, settings.mask_image_fit_mode)
	if buffer_ok {
		write_fixed_string(settings.mask_image_path[:], path)
		settings.mask_pattern = .Image
		settings.mask_pattern_index = int(Slime_Mask_Pattern.Image)
		return true, ""
	}
	return false, buffer_reason
}

slime_gpu_load_position_image_path :: proc(gpu: ^Slime_Gpu_State, path: string, settings: ^Slime_Settings) -> bool {
	if slime_load_image_to_mask_buffer(gpu, path, settings.position_image_fit_mode) {
		write_fixed_string(settings.position_image_path[:], path)
		settings.position_generator = 7
		settings.position_generator_index = 7
		gpu.needs_reset = true
		return true
	}
	return false
}

slime_create_image :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, image: ^Slime_Image, width, height: u32, usage: vk.ImageUsageFlags) -> bool {
	_ = gpu
	image^ = {width = width, height = height, layout = .UNDEFINED}
	info := vk.ImageCreateInfo{sType = .IMAGE_CREATE_INFO, imageType = .D2, format = SLIME_IMAGE_FORMAT, extent = {width, height, 1}, mipLevels = 1, arrayLayers = 1, samples = {._1}, tiling = .OPTIMAL, usage = usage, sharingMode = .EXCLUSIVE, initialLayout = .UNDEFINED}
	if vk.CreateImage(vk_ctx.device, &info, nil, &image.handle) != .SUCCESS {return false}
	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device, image.handle, &req)
	memory_type, ok := engine.vk_find_memory_type(vk_ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {return false}
	alloc := vk.MemoryAllocateInfo{sType = .MEMORY_ALLOCATE_INFO, allocationSize = req.size, memoryTypeIndex = memory_type}
	if vk.AllocateMemory(vk_ctx.device, &alloc, nil, &image.memory) != .SUCCESS {return false}
	if vk.BindImageMemory(vk_ctx.device, image.handle, image.memory, 0) != .SUCCESS {return false}
	view_info := vk.ImageViewCreateInfo{sType = .IMAGE_VIEW_CREATE_INFO, image = image.handle, viewType = .D2, format = SLIME_IMAGE_FORMAT, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	return vk.CreateImageView(vk_ctx.device, &view_info, nil, &image.view) == .SUCCESS
}

slime_create_sampler :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	info := vk.SamplerCreateInfo{sType = .SAMPLER_CREATE_INFO, magFilter = .LINEAR, minFilter = .LINEAR, mipmapMode = .LINEAR, addressModeU = .REPEAT, addressModeV = .REPEAT, addressModeW = .REPEAT}
	return vk.CreateSampler(vk_ctx.device, &info, nil, &gpu.sampler) == .SUCCESS
}

slime_ensure_webcam_slot :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int, width, height: u32) -> bool {
	image := &gpu.webcam_images[frame_slot]
	staging := &gpu.webcam_staging_buffers[frame_slot]
	size := vk.DeviceSize(width * height * 4)
	if image.handle != vk.Image(0) && image.width == width && image.height == height && staging.size >= size {return true}
	slime_destroy_image(vk_ctx, image)
	engine.vk_destroy_buffer(vk_ctx, staging)
	gpu.webcam_image_ready[frame_slot] = false
	if !slime_create_image(gpu, vk_ctx, image, width, height, {.SAMPLED, .TRANSFER_DST}) ||
	   !engine.vk_create_host_buffer(vk_ctx, size, {.TRANSFER_SRC}, staging) {
		slime_destroy_image(vk_ctx, image)
		engine.vk_destroy_buffer(vk_ctx, staging)
		return false
	}
	return true
}

slime_record_webcam_upload :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, frame_slot: int) {
	if !gpu.webcam_upload_pending[frame_slot] {return}
	image := &gpu.webcam_images[frame_slot]
	slime_transition_image(vk_ctx, cmd, image, .TRANSFER_DST_OPTIMAL)
	region := vk.BufferImageCopy{imageSubresource = {aspectMask = {.COLOR}, mipLevel = 0, baseArrayLayer = 0, layerCount = 1}, imageExtent = {image.width, image.height, 1}}
	vk.CmdCopyBufferToImage(cmd, gpu.webcam_staging_buffers[frame_slot].handle, image.handle, .TRANSFER_DST_OPTIMAL, 1, &region)
	engine.vk_cmd_count_transfer_copy(vk_ctx)
	slime_transition_image(vk_ctx, cmd, image, .SHADER_READ_ONLY_OPTIMAL)
	gpu.webcam_upload_pending[frame_slot] = false
	gpu.webcam_image_ready[frame_slot] = true
}

slime_upload_lut :: proc(gpu: ^Slime_Gpu_State, settings: ^Slime_Settings) {
	if gpu.lut_buffer.mapped == nil {return}
	scheme := color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
	data := (cast([^]u32)gpu.lut_buffer.mapped)[:COLOR_SCHEME_U32_COUNT]
	_ = color_scheme_write_u32_buffer(scheme, data)
}

slime_upload_render_params :: proc(gpu: ^Slime_Gpu_State, frame_slot: int, settings: ^Slime_Settings) {
	if gpu.render_params_buffers[frame_slot].mapped == nil {return}
	params := cast(^Slime_Render_Params)gpu.render_params_buffers[frame_slot].mapped
	params^ = {filtering_mode = settings.trail_map_filtering == .Nearest ? u32(0) : u32(1)}
}

slime_upload_camera :: proc(gpu: ^Slime_Gpu_State, frame_slot: int, control: ^Camera_Control_State = nil) {
	uniform := slime_camera_uniform_for_state(gpu.width, gpu.height, control)
	gpu.present_camera_zoom = uniform.zoom
	if gpu.camera_buffers[frame_slot].mapped == nil {return}
	camera := cast(^Slime_Camera)gpu.camera_buffers[frame_slot].mapped
	camera^ = uniform
}

slime_write_uniforms :: proc(gpu: ^Slime_Gpu_State, frame_slot: int, settings: ^Slime_Settings, cursor_active: u32, cursor_pixel: [2]f32, cursor_size, cursor_strength, dt: f32) {
	if gpu.sim_buffers[frame_slot].mapped != nil {
		sim := cast(^Slime_Sim_Uniform)gpu.sim_buffers[frame_slot].mapped
		sim^ = {
			width = gpu.width,
			height = gpu.height,
			decay_rate = settings.pheromone_decay_rate,
			agent_jitter = settings.agent_jitter,
			agent_speed_min = settings.agent_speed_min,
			agent_speed_max = settings.agent_speed_max,
			agent_turn_rate = settings.agent_turn_rate,
			agent_sensor_angle = settings.agent_sensor_angle,
			agent_sensor_distance = settings.agent_sensor_distance,
			diffusion_rate = settings.pheromone_diffusion_rate,
			pheromone_deposition_rate = settings.pheromone_deposition_rate,
			mask_pattern = u32(settings.mask_pattern),
			mask_target = u32(settings.mask_target),
			mask_strength = settings.mask_strength,
			mask_curve = settings.mask_curve,
			mask_mirror_horizontal = settings.mask_mirror_horizontal ? 1 : 0,
			mask_mirror_vertical = settings.mask_mirror_vertical ? 1 : 0,
			mask_invert_tone = settings.mask_invert_tone ? 1 : 0,
			random_seed = settings.random_seed,
			position_generator = settings.position_generator,
			delta_time = max(dt, 0),
			webcam_live = gpu.webcam_live ? 1 : 0,
			webcam_fit_mode = u32(gpu.webcam_fit_mode),
			webcam_width = gpu.webcam_images[frame_slot].width,
			webcam_height = gpu.webcam_images[frame_slot].height,
		}
	}
	if gpu.cursor_buffers[frame_slot].mapped != nil {
		cursor := cast(^Slime_Cursor_Params)gpu.cursor_buffers[frame_slot].mapped
		cursor^ = {
			is_active = cursor_active,
			x = cursor_pixel[0],
			y = cursor_pixel[1],
			strength = cursor_strength,
			size = cursor_size * max(f32(gpu.width), f32(gpu.height)),
		}
	}
}

slime_create_descriptors :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	sim_bindings := [7]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 4, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 5, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 6, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	display_bindings := [5]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	texture_bindings := [3]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	camera_bindings := [1]vk.DescriptorSetLayoutBinding{{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}}}
	if !slime_create_set_layout(vk_ctx, sim_bindings[:], &gpu.sim_set_layout) ||
	   !slime_create_set_layout(vk_ctx, display_bindings[:], &gpu.display_set_layout) ||
	   !slime_create_set_layout(vk_ctx, texture_bindings[:], &gpu.texture_set_layout) ||
	   !slime_create_set_layout(vk_ctx, camera_bindings[:], &gpu.camera_set_layout) {return false}
	pool_sizes := [5]vk.DescriptorPoolSize{{type = .STORAGE_BUFFER, descriptorCount = 8 * engine.MAX_FRAMES_IN_FLIGHT}, {type = .UNIFORM_BUFFER, descriptorCount = 5 * engine.MAX_FRAMES_IN_FLIGHT}, {type = .STORAGE_IMAGE, descriptorCount = engine.MAX_FRAMES_IN_FLIGHT}, {type = .SAMPLED_IMAGE, descriptorCount = 2 * engine.MAX_FRAMES_IN_FLIGHT}, {type = .SAMPLER, descriptorCount = 2 * engine.MAX_FRAMES_IN_FLIGHT}}
	pool_info := vk.DescriptorPoolCreateInfo{sType = .DESCRIPTOR_POOL_CREATE_INFO, poolSizeCount = u32(len(pool_sizes)), pPoolSizes = raw_data(pool_sizes[:]), maxSets = 4 * engine.MAX_FRAMES_IN_FLIGHT}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &gpu.descriptor_pool) != .SUCCESS {return false}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		layouts := [4]vk.DescriptorSetLayout{gpu.sim_set_layout, gpu.display_set_layout, gpu.texture_set_layout, gpu.camera_set_layout}
		sets: [4]vk.DescriptorSet
		alloc := vk.DescriptorSetAllocateInfo{sType = .DESCRIPTOR_SET_ALLOCATE_INFO, descriptorPool = gpu.descriptor_pool, descriptorSetCount = 4, pSetLayouts = raw_data(layouts[:])}
		if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(sets[:])) != .SUCCESS {return false}
		gpu.sim_sets[frame_slot] = sets[0]
		gpu.display_sets[frame_slot] = sets[1]
		gpu.texture_sets[frame_slot] = sets[2]
		gpu.camera_sets[frame_slot] = sets[3]
	}
	slime_update_descriptors(gpu, vk_ctx)
	return true
}

slime_create_set_layout :: proc(vk_ctx: ^engine.Vk_Context, bindings: []vk.DescriptorSetLayoutBinding, out: ^vk.DescriptorSetLayout) -> bool {
	info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(bindings)), pBindings = raw_data(bindings)}
	return vk.CreateDescriptorSetLayout(vk_ctx.device, &info, nil, out) == .SUCCESS
}

slime_update_descriptors :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		slime_update_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	}
}

slime_update_descriptors_for_slot :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	agent_info := vk.DescriptorBufferInfo{buffer = gpu.agent_buffer.handle, offset = 0, range = gpu.agent_buffer.size}
	trail_info := vk.DescriptorBufferInfo{buffer = gpu.trail_buffer.handle, offset = 0, range = gpu.trail_buffer.size}
	mask_info := vk.DescriptorBufferInfo{buffer = gpu.mask_buffer.handle, offset = 0, range = gpu.mask_buffer.size}
	gradient_info := vk.DescriptorBufferInfo{buffer = gpu.gradient_buffer.handle, offset = 0, range = gpu.gradient_buffer.size}
	sim_info := vk.DescriptorBufferInfo{buffer = gpu.sim_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Slime_Sim_Uniform))}
	cursor_info := vk.DescriptorBufferInfo{buffer = gpu.cursor_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Slime_Cursor_Params))}
	lut_info := vk.DescriptorBufferInfo{buffer = gpu.lut_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT)}
	display_storage := vk.DescriptorImageInfo{imageLayout = .GENERAL, imageView = gpu.display_image.view}
	display_sampled := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.display_image.view}
	sampler_info := vk.DescriptorImageInfo{sampler = gpu.sampler}
	webcam_sampled := vk.DescriptorImageInfo{imageLayout = .GENERAL, imageView = gpu.display_image.view}
	if gpu.webcam_image_ready[frame_slot] {webcam_sampled = {imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.webcam_images[frame_slot].view}}
	render_info := vk.DescriptorBufferInfo{buffer = gpu.render_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Slime_Render_Params))}
	camera_info := vk.DescriptorBufferInfo{buffer = gpu.camera_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Slime_Camera))}
	sim_set := gpu.sim_sets[frame_slot]
	display_set := gpu.display_sets[frame_slot]
	texture_set := gpu.texture_sets[frame_slot]
	camera_set := gpu.camera_sets[frame_slot]
	writes := [?]vk.WriteDescriptorSet{
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &agent_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &trail_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &sim_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &mask_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 4, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &cursor_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 5, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &webcam_sampled},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 6, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = display_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &trail_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = display_set, dstBinding = 1, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, pImageInfo = &display_storage},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = display_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &sim_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = display_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &lut_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = display_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &gradient_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = texture_set, dstBinding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &display_sampled},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = texture_set, dstBinding = 1, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = texture_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &render_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = camera_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &camera_info},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
}

slime_create_compute_pipeline :: proc(vk_ctx: ^engine.Vk_Context, shader: vk.ShaderModule, entry: cstring, set_layout: vk.DescriptorSetLayout, out: ^engine.Vk_Compute_Pipeline) -> bool {
	layouts := [1]vk.DescriptorSetLayout{set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &out.layout) != .SUCCESS {return false}
	stage := vk.PipelineShaderStageCreateInfo{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.COMPUTE}, module = shader, pName = entry}
	info := vk.ComputePipelineCreateInfo{sType = .COMPUTE_PIPELINE_CREATE_INFO, stage = stage, layout = out.layout}
	return vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &out.pipeline) == .SUCCESS
}

slime_create_present_pipeline :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	layouts := [2]vk.DescriptorSetLayout{gpu.texture_set_layout, gpu.camera_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 2, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gpu.present_pipeline.layout) != .SUCCESS {return false}
	stages := [2]vk.PipelineShaderStageCreateInfo{
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = gpu.present_vertex_shader.handle, pName = SLIME_PRESENT_VERTEX_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = gpu.present_fragment_shader.handle, pName = SLIME_PRESENT_FRAGMENT_ENTRY},
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
	info := vk.GraphicsPipelineCreateInfo{sType = .GRAPHICS_PIPELINE_CREATE_INFO, stageCount = 2, pStages = raw_data(stages[:]), pVertexInputState = &vertex_input, pInputAssemblyState = &input_assembly, pViewportState = &viewport_state, pRasterizationState = &raster, pMultisampleState = &multisample, pColorBlendState = &blend, pDynamicState = &dynamic_state, layout = gpu.present_pipeline.layout, renderPass = vk_ctx.render_pass, subpass = 0}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &gpu.present_pipeline.pipeline) == .SUCCESS
}

slime_transition_image :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, image: ^Slime_Image, new_layout: vk.ImageLayout) {
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
	} else if image.layout == .TRANSFER_DST_OPTIMAL {
		src_access = {.TRANSFER_WRITE}
		src_stage = {.TRANSFER}
	}
	if new_layout == .GENERAL {
		dst_access = {.SHADER_WRITE, .SHADER_READ}
		dst_stage = {.COMPUTE_SHADER}
	} else if new_layout == .SHADER_READ_ONLY_OPTIMAL {
		dst_access = {.SHADER_READ}
		dst_stage = {.COMPUTE_SHADER, .FRAGMENT_SHADER}
	} else if new_layout == .TRANSFER_DST_OPTIMAL {
		dst_access = {.TRANSFER_WRITE}
		dst_stage = {.TRANSFER}
	}
	barrier := vk.ImageMemoryBarrier{sType = .IMAGE_MEMORY_BARRIER, srcAccessMask = src_access, dstAccessMask = dst_access, oldLayout = image.layout, newLayout = new_layout, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, image = image.handle, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	vk.CmdPipelineBarrier(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	image.layout = new_layout
}

slime_compute_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dst: vk.PipelineStageFlags) {
	barrier := vk.MemoryBarrier{sType = .MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.SHADER_READ, .SHADER_WRITE}}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, dst, {}, 1, &barrier, 0, nil, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

slime_dispatch_agent_pipeline :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, frame_slot: int, pipeline: ^engine.Vk_Compute_Pipeline, workgroup_size: u32) {
	vk.CmdBindPipeline(cmd, .COMPUTE, pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := gpu.sim_sets[frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	total_groups := max((gpu.agent_count + workgroup_size - 1) / workgroup_size, 1)
	max_groups_x := u32(65535)
	groups_x := min(total_groups, max_groups_x)
	groups_y := max((total_groups + max_groups_x - 1) / max_groups_x, 1)
	vk.CmdDispatch(cmd, groups_x, groups_y, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
}

slime_gpu_step :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim_state: ^Remaining_Sim_State, dt: f32) {
	settings := &sim_state.slime
	if !slime_gpu_ensure(gpu, vk_ctx, settings) {return}
	slime_gpu_step_ready(gpu, vk_ctx, cmd, sim_state, dt)
}

slime_gpu_step_size :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim_state: ^Remaining_Sim_State, dt: f32, width, height: u32) {
	settings := &sim_state.slime
	if !slime_gpu_ensure_size(gpu, vk_ctx, settings, width, height) {return}
	slime_gpu_step_ready(gpu, vk_ctx, cmd, sim_state, dt)
}

slime_gpu_step_preview :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim_state: ^Remaining_Sim_State, dt: f32, width, height: u32) {
	settings := &sim_state.slime
	if !slime_gpu_ensure_size_count(gpu, vk_ctx, settings, width, height, SLIME_PREVIEW_AGENT_COUNT) {return}
	slime_gpu_step_ready(gpu, vk_ctx, cmd, sim_state, dt)
}

slime_gpu_step_ready :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim_state: ^Remaining_Sim_State, dt: f32) {
	settings := &sim_state.slime
	frame_slot := int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	slime_record_webcam_upload(gpu, vk_ctx, cmd, frame_slot)
	slime_update_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	if sim_state.slime_clear_trails_requested {
		slime_clear_trail_buffer(gpu)
		sim_state.slime_clear_trails_requested = false
	}
	if sim_state.slime_reset_requested {
		gpu.needs_reset = true
		sim_state.slime_reset_requested = false
	}
	slime_upload_lut(gpu, settings)
	slime_upload_render_params(gpu, frame_slot, settings)
	slime_write_uniforms(gpu, frame_slot, settings, sim_state.cursor_active, sim_state.cursor_pixel, sim_state.cursor_size, sim_state.cursor_strength, dt)
	speed_range_changed := slime_speed_range_changed(gpu, settings)
	sim_set := gpu.sim_sets[frame_slot]
	display_set := gpu.display_sets[frame_slot]
	if settings.mask_pattern != .Disabled && settings.mask_pattern != .Image {
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.gradient_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.gradient_pipeline.layout, 0, 1, &sim_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		total := gpu.width * gpu.height
		vk.CmdDispatch(cmd, (total + 255) / 256, 1, 1)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		slime_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	}
	if gpu.needs_reset {
		slime_dispatch_agent_pipeline(gpu, vk_ctx, cmd, frame_slot, &gpu.reset_pipeline, 64)
		slime_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
		gpu.agent_speed_min_uploaded = settings.agent_speed_min
		gpu.agent_speed_max_uploaded = settings.agent_speed_max
		gpu.needs_reset = false
	} else if speed_range_changed {
		slime_dispatch_agent_pipeline(gpu, vk_ctx, cmd, frame_slot, &gpu.update_speeds_pipeline, 256)
		slime_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
		gpu.agent_speed_min_uploaded = settings.agent_speed_min
		gpu.agent_speed_max_uploaded = settings.agent_speed_max
	}
	if !sim_state.paused {
		slime_dispatch_agent_pipeline(gpu, vk_ctx, cmd, frame_slot, &gpu.update_pipeline, 256)
		slime_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.decay_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.decay_pipeline.layout, 0, 1, &sim_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDispatch(cmd, (gpu.width + 15) / 16, (gpu.height + 15) / 16, 1)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		slime_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
		if settings.diffusion_frequency > 0 {
			vk.CmdBindPipeline(cmd, .COMPUTE, gpu.diffuse_pipeline.pipeline)
			engine.vk_cmd_count_pipeline_bind(vk_ctx)
			vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.diffuse_pipeline.layout, 0, 1, &sim_set, 0, nil)
			engine.vk_cmd_count_descriptor_bind(vk_ctx)
			vk.CmdDispatch(cmd, (gpu.width + 15) / 16, (gpu.height + 15) / 16, 1)
			engine.vk_cmd_count_compute_dispatch(vk_ctx)
			slime_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
		}
	}
	slime_transition_image(vk_ctx, cmd, &gpu.display_image, .GENERAL)
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.display_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.display_pipeline.layout, 0, 1, &display_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, (gpu.width + 15) / 16, (gpu.height + 15) / 16, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	slime_compute_barrier(vk_ctx, cmd, {.FRAGMENT_SHADER})
}

slime_gpu_present :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, camera: ^Camera_Control_State = nil) {
	viewport := vk.Viewport{x = 0, y = 0, width = f32(vk_ctx.swapchain_extent.width), height = f32(vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = vk_ctx.swapchain_extent}
	slime_gpu_present_viewport(gpu, vk_ctx, frame, viewport, scissor, camera)
}

slime_gpu_present_viewport :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D, camera: ^Camera_Control_State = nil) {
	if !gpu.ready || gpu.present_pipeline.pipeline == vk.Pipeline(0) {return}
	slime_transition_image(vk_ctx, frame.command_buffer, &gpu.display_image, .SHADER_READ_ONLY_OPTIMAL)
	slime_upload_camera(gpu, int(frame.frame_index), camera)
	slime_gpu_draw_prepared_viewport(gpu, vk_ctx, frame, viewport, scissor)
}

slime_gpu_draw_prepared_viewport :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gpu.ready || gpu.present_pipeline.pipeline == vk.Pipeline(0) {return}
	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(frame.command_buffer, 0, 1, &local_viewport)
	vk.CmdSetScissor(frame.command_buffer, 0, 1, &local_scissor)
	vk.CmdBindPipeline(frame.command_buffer, .GRAPHICS, gpu.present_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	frame_slot := int(frame.frame_index)
	texture_set := gpu.texture_sets[frame_slot]
	camera_set := gpu.camera_sets[frame_slot]
	vk.CmdBindDescriptorSets(frame.command_buffer, .GRAPHICS, gpu.present_pipeline.layout, 0, 1, &texture_set, 0, nil)
	vk.CmdBindDescriptorSets(frame.command_buffer, .GRAPHICS, gpu.present_pipeline.layout, 1, 1, &camera_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	zoom := gpu.present_camera_zoom
	if zoom <= 0 {
		zoom = 1
	}
	tile_count := infinite_render_tile_count(zoom)
	vk.CmdDraw(frame.command_buffer, 6, tile_count * tile_count, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
}

slime_clear_color :: proc(settings: ^Slime_Settings) -> uifw.Color {
	if settings.background_mode == .White {
		return {1, 1, 1, 1}
	}
	return {0, 0, 0, 1}
}

slime_destroy_compute_pipeline :: proc(vk_ctx: ^engine.Vk_Context, pipeline: ^engine.Vk_Compute_Pipeline) {
	if pipeline.pipeline != vk.Pipeline(0) {vk.DestroyPipeline(vk_ctx.device, pipeline.pipeline, nil)}
	if pipeline.layout != vk.PipelineLayout(0) {vk.DestroyPipelineLayout(vk_ctx.device, pipeline.layout, nil)}
	pipeline^ = {}
}

slime_destroy_image :: proc(vk_ctx: ^engine.Vk_Context, image: ^Slime_Image) {
	if image.view != vk.ImageView(0) {vk.DestroyImageView(vk_ctx.device, image.view, nil)}
	if image.handle != vk.Image(0) {vk.DestroyImage(vk_ctx.device, image.handle, nil)}
	if image.memory != vk.DeviceMemory(0) {vk.FreeMemory(vk_ctx.device, image.memory, nil)}
	image^ = {}
}

slime_gpu_destroy :: proc(gpu: ^Slime_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	if vk_ctx == nil || vk_ctx.device == nil {gpu^ = {}; return}
	slime_destroy_compute_pipeline(vk_ctx, &gpu.update_pipeline)
	slime_destroy_compute_pipeline(vk_ctx, &gpu.decay_pipeline)
	slime_destroy_compute_pipeline(vk_ctx, &gpu.diffuse_pipeline)
	slime_destroy_compute_pipeline(vk_ctx, &gpu.update_speeds_pipeline)
	slime_destroy_compute_pipeline(vk_ctx, &gpu.reset_pipeline)
	slime_destroy_compute_pipeline(vk_ctx, &gpu.gradient_pipeline)
	slime_destroy_compute_pipeline(vk_ctx, &gpu.display_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.present_pipeline)
	if gpu.descriptor_pool != vk.DescriptorPool(0) {vk.DestroyDescriptorPool(vk_ctx.device, gpu.descriptor_pool, nil)}
	if gpu.sim_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.sim_set_layout, nil)}
	if gpu.display_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.display_set_layout, nil)}
	if gpu.texture_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.texture_set_layout, nil)}
	if gpu.camera_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.camera_set_layout, nil)}
	if gpu.sampler != vk.Sampler(0) {vk.DestroySampler(vk_ctx.device, gpu.sampler, nil)}
	engine.vk_destroy_buffer(vk_ctx, &gpu.agent_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.trail_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.mask_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.gradient_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.lut_buffer)
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		engine.vk_destroy_buffer(vk_ctx, &gpu.sim_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.cursor_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.render_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.camera_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.webcam_staging_buffers[frame_slot])
		slime_destroy_image(vk_ctx, &gpu.webcam_images[frame_slot])
	}
	slime_destroy_image(vk_ctx, &gpu.display_image)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.update_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.decay_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.diffuse_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.update_speeds_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.reset_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.gradient_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.display_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.present_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.present_fragment_shader)
	gpu^ = {}
}
