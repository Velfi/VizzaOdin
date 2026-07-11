package render_vk

import engine "../engine"
import uifw "../ui"

import "core:math"
import vk "vendor:vulkan"

flow_gpu_ensure :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Flow_Settings) -> bool {
	width := max(vk_ctx.swapchain_extent.width, 1)
	height := max(vk_ctx.swapchain_extent.height, 1)
	return flow_gpu_ensure_size(gpu, vk_ctx, settings, width, height)
}

flow_gpu_ensure_size :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Flow_Settings, trail_width, trail_height: u32) -> bool {
	target_pool := max(settings.total_pool_size, 1)
	target_width := max(trail_width, 1)
	target_height := max(trail_height, 1)
	if gpu.ready && gpu.total_pool_size == target_pool && gpu.trail_width == target_width && gpu.trail_height == target_height {
		return true
	}
	flow_gpu_destroy(gpu, vk_ctx)
	gpu.total_pool_size = target_pool
	gpu.trail_width = target_width
	gpu.trail_height = target_height
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, FLOW_VECTOR_SHADER_SOURCE, FLOW_VECTOR_FALLBACK_SPV, .Compute, FLOW_SOURCE_ENTRY, &gpu.vector_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, FLOW_PARTICLE_UPDATE_SHADER_SOURCE, FLOW_PARTICLE_UPDATE_FALLBACK_SPV, .Compute, FLOW_SOURCE_ENTRY, &gpu.particle_update_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, FLOW_TRAIL_DECAY_SHADER_SOURCE, FLOW_TRAIL_DECAY_FALLBACK_SPV, .Compute, FLOW_SOURCE_ENTRY, &gpu.trail_decay_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, FLOW_SHAPE_DRAWING_SHADER_SOURCE, FLOW_SHAPE_DRAWING_FALLBACK_SPV, .Compute, FLOW_SOURCE_ENTRY, &gpu.shape_drawing_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, FLOW_BACKGROUND_SHADER_SOURCE, FLOW_BACKGROUND_VERTEX_FALLBACK_SPV, .Vertex, FLOW_VERTEX_SOURCE_ENTRY, &gpu.background_vertex_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, FLOW_BACKGROUND_SHADER_SOURCE, FLOW_BACKGROUND_FRAGMENT_FALLBACK_SPV, .Fragment, FLOW_FRAGMENT_SOURCE_ENTRY, &gpu.background_fragment_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, FLOW_TRAIL_SHADER_SOURCE, FLOW_TRAIL_VERTEX_FALLBACK_SPV, .Vertex, FLOW_VERTEX_SOURCE_ENTRY, &gpu.trail_vertex_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, FLOW_TRAIL_SHADER_SOURCE, FLOW_TRAIL_FRAGMENT_FALLBACK_SPV, .Fragment, FLOW_FRAGMENT_SOURCE_ENTRY, &gpu.trail_fragment_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, FLOW_PARTICLE_SHADER_SOURCE, FLOW_PARTICLE_VERTEX_FALLBACK_SPV, .Vertex, FLOW_VERTEX_SOURCE_ENTRY, &gpu.particle_vertex_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, FLOW_PARTICLE_SHADER_SOURCE, FLOW_PARTICLE_FRAGMENT_FALLBACK_SPV, .Fragment, FLOW_FRAGMENT_SOURCE_ENTRY, &gpu.particle_fragment_shader) {
		flow_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Flow_Particle) * int(target_pool)), {.STORAGE_BUFFER}, &gpu.particle_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Flow_Vector) * int(FLOW_FIELD_RESOLUTION * FLOW_FIELD_RESOLUTION)), {.STORAGE_BUFFER}, &gpu.flow_vector_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT), {.STORAGE_BUFFER}, &gpu.lut_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Flow_Spawn_Control)), {.STORAGE_BUFFER}, &gpu.spawn_control_buffer) {
		flow_gpu_destroy(gpu, vk_ctx)
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Flow_Sim_Params)), {.UNIFORM_BUFFER}, &gpu.sim_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Flow_Vector_Params)), {.UNIFORM_BUFFER}, &gpu.vector_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of([4]f32)), {.UNIFORM_BUFFER}, &gpu.background_color_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Flow_Shape_Params)), {.UNIFORM_BUFFER}, &gpu.shape_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Flow_Camera)), {.UNIFORM_BUFFER}, &gpu.camera_buffers[frame_slot]) {
			flow_gpu_destroy(gpu, vk_ctx)
			return false
		}
	}
	if !flow_create_image(gpu, vk_ctx, &gpu.trail_image, gpu.trail_width, gpu.trail_height, {.STORAGE, .SAMPLED, .TRANSFER_DST}) ||
	   !flow_create_image(gpu, vk_ctx, &gpu.default_image, 1, 1, {.SAMPLED, .TRANSFER_DST}) ||
	   !flow_create_sampler(gpu, vk_ctx) {
		flow_gpu_destroy(gpu, vk_ctx)
		return false
	}
	flow_initialize_particles(gpu, settings)
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		flow_upload_camera(gpu, frame_slot, vk_ctx)
	}
	if !flow_create_descriptors(gpu, vk_ctx) {
		flow_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !flow_create_compute_pipeline(vk_ctx, gpu.vector_shader.handle, gpu.vector_set_layout, &gpu.vector_pipeline) ||
	   !flow_create_compute_pipeline(vk_ctx, gpu.particle_update_shader.handle, gpu.update_set_layout, &gpu.particle_update_pipeline) ||
	   !flow_create_compute_pipeline(vk_ctx, gpu.trail_decay_shader.handle, gpu.trail_set_layout, &gpu.trail_decay_pipeline) ||
	   !flow_create_compute_pipeline(vk_ctx, gpu.shape_drawing_shader.handle, gpu.shape_drawing_set_layout, &gpu.shape_drawing_pipeline) ||
	   !flow_create_background_pipeline(gpu, vk_ctx) ||
	   !flow_create_trail_pipeline(gpu, vk_ctx) ||
	   !flow_create_particle_pipeline(gpu, vk_ctx) {
		flow_gpu_destroy(gpu, vk_ctx)
		return false
	}
	gpu.ready = true
	flow_gpu_reload_vector_field_image_after_recreate(gpu, vk_ctx, settings)
	return true
}

flow_gpu_reload_vector_field_image_after_recreate :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Flow_Settings) {
	if settings.vector_field_type != .Image {
		return
	}
	image_path := fixed_string(settings.image_path[:])
	if len(image_path) == 0 {
		return
	}
	_ = flow_gpu_load_vector_field_image_path(gpu, vk_ctx, image_path, settings)
}

flow_create_image :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, image: ^Flow_Image, width, height: u32, usage: vk.ImageUsageFlags) -> bool {
	_ = gpu
	image^ = {width = width, height = height, layout = .UNDEFINED}
	info := vk.ImageCreateInfo{sType = .IMAGE_CREATE_INFO, imageType = .D2, format = FLOW_IMAGE_FORMAT, extent = {width, height, 1}, mipLevels = 1, arrayLayers = 1, samples = {._1}, tiling = .OPTIMAL, usage = usage, sharingMode = .EXCLUSIVE, initialLayout = .UNDEFINED}
	if vk.CreateImage(vk_ctx.device, &info, nil, &image.handle) != .SUCCESS {return false}
	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device, image.handle, &req)
	memory_type, ok := engine.vk_find_memory_type(vk_ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {return false}
	alloc := vk.MemoryAllocateInfo{sType = .MEMORY_ALLOCATE_INFO, allocationSize = req.size, memoryTypeIndex = memory_type}
	if vk.AllocateMemory(vk_ctx.device, &alloc, nil, &image.memory) != .SUCCESS {return false}
	if vk.BindImageMemory(vk_ctx.device, image.handle, image.memory, 0) != .SUCCESS {return false}
	view_info := vk.ImageViewCreateInfo{sType = .IMAGE_VIEW_CREATE_INFO, image = image.handle, viewType = .D2, format = FLOW_IMAGE_FORMAT, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	return vk.CreateImageView(vk_ctx.device, &view_info, nil, &image.view) == .SUCCESS
}

flow_create_sampler :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	info := vk.SamplerCreateInfo{sType = .SAMPLER_CREATE_INFO, magFilter = .LINEAR, minFilter = .LINEAR, mipmapMode = .LINEAR, addressModeU = .CLAMP_TO_EDGE, addressModeV = .CLAMP_TO_EDGE, addressModeW = .CLAMP_TO_EDGE}
	return vk.CreateSampler(vk_ctx.device, &info, nil, &gpu.sampler) == .SUCCESS
}

flow_upload_sampled_image :: proc(vk_ctx: ^engine.Vk_Context, image: ^Flow_Image, width, height: u32, pixels: []u8) -> bool {
	if !vk_ctx.frame_resources_ready || image.handle == vk.Image(0) || len(pixels) < int(width * height * 4) {
		return false
	}
	staging: engine.Vk_Buffer
	size := vk.DeviceSize(width * height * 4)
	if !engine.vk_create_host_buffer(vk_ctx, size, {.TRANSFER_SRC}, &staging) {
		return false
	}
	defer engine.vk_destroy_buffer(vk_ctx, &staging)
	dst := (cast([^]u8)staging.mapped)[:int(size)]
	copy(dst, pixels[:int(size)])

	command_buffer, begin_ok := engine.vk_begin_upload_commands(vk_ctx)
	if !begin_ok {
		return false
	}
	range := vk.ImageSubresourceRange{aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}
	to_transfer := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		dstAccessMask = {.TRANSFER_WRITE},
		oldLayout = .UNDEFINED,
		newLayout = .TRANSFER_DST_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = image.handle,
		subresourceRange = range,
	}
	vk.CmdPipelineBarrier(command_buffer, {.TOP_OF_PIPE}, {.TRANSFER}, {}, 0, nil, 0, nil, 1, &to_transfer)
	region := vk.BufferImageCopy {
		bufferOffset = 0,
		bufferRowLength = 0,
		bufferImageHeight = 0,
		imageSubresource = {aspectMask = {.COLOR}, mipLevel = 0, baseArrayLayer = 0, layerCount = 1},
		imageOffset = {0, 0, 0},
		imageExtent = {width, height, 1},
	}
	vk.CmdCopyBufferToImage(command_buffer, staging.handle, image.handle, .TRANSFER_DST_OPTIMAL, 1, &region)
	to_shader := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = {.TRANSFER_WRITE},
		dstAccessMask = {.SHADER_READ},
		oldLayout = .TRANSFER_DST_OPTIMAL,
		newLayout = .SHADER_READ_ONLY_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = image.handle,
		subresourceRange = range,
	}
	vk.CmdPipelineBarrier(command_buffer, {.TRANSFER}, {.COMPUTE_SHADER}, {}, 0, nil, 0, nil, 1, &to_shader)
	if !engine.vk_submit_upload_commands(vk_ctx) {
		return false
	}
	image.layout = .SHADER_READ_ONLY_OPTIMAL
	return true
}

flow_ensure_webcam_slot :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int, width, height: u32) -> bool {
	image := &gpu.webcam_images[frame_slot]
	staging := &gpu.webcam_staging_buffers[frame_slot]
	size := vk.DeviceSize(width * height * 4)
	if image.handle != vk.Image(0) && image.width == width && image.height == height && staging.size >= size {return true}
	flow_destroy_image(vk_ctx, image)
	engine.vk_destroy_buffer(vk_ctx, staging)
	gpu.webcam_image_ready[frame_slot] = false
	if !flow_create_image(gpu, vk_ctx, image, width, height, {.SAMPLED, .TRANSFER_DST}) ||
	   !engine.vk_create_host_buffer(vk_ctx, size, {.TRANSFER_SRC}, staging) {
		flow_destroy_image(vk_ctx, image)
		engine.vk_destroy_buffer(vk_ctx, staging)
		return false
	}
	return true
}

flow_record_webcam_upload :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, frame_slot: int) {
	if !gpu.webcam_upload_pending[frame_slot] {return}
	image := &gpu.webcam_images[frame_slot]
	staging := &gpu.webcam_staging_buffers[frame_slot]
	flow_transition_image(vk_ctx, cmd, image, .TRANSFER_DST_OPTIMAL)
	region := vk.BufferImageCopy {
		imageSubresource = {aspectMask = {.COLOR}, mipLevel = 0, baseArrayLayer = 0, layerCount = 1},
		imageExtent = {image.width, image.height, 1},
	}
	vk.CmdCopyBufferToImage(cmd, staging.handle, image.handle, .TRANSFER_DST_OPTIMAL, 1, &region)
	engine.vk_cmd_count_transfer_copy(vk_ctx)
	flow_transition_image(vk_ctx, cmd, image, .SHADER_READ_ONLY_OPTIMAL)
	gpu.webcam_upload_pending[frame_slot] = false
	gpu.webcam_image_ready[frame_slot] = true
}

flow_gpu_load_vector_field_image_path :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, path: string, settings: ^Flow_Settings) -> bool {
	if !gpu.ready || len(path) == 0 {
		gpu.vector_field_image_loaded = false
		return false
	}
	img, ok := shared_image_load_rgba8(path)
	if !ok {
		gpu.vector_field_image_loaded = false
		return false
	}
	defer shared_image_destroy(img)

	target_width := int(max(gpu.trail_width, 1))
	target_height := int(max(gpu.trail_height, 1))
	pixels := make([]u8, int(target_width * target_height * 4))
	defer delete(pixels)
	source := raw_data(img.pixels.buf[:])
	for y := 0; y < target_height; y += 1 {
		for x := 0; x < target_width; x += 1 {
			dst_x := x
			dst_y := y
			if settings.image_mirror_horizontal {
				dst_x = target_width - 1 - dst_x
			}
			if settings.image_mirror_vertical {
				dst_y = target_height - 1 - dst_y
			}
			src_x, src_y: int
			value := u8(0)
			if vectors_image_source_coord(int(img.width), int(img.height), target_width, target_height, dst_x, dst_y, settings.image_fit_mode, &src_x, &src_y) {
				value = vectors_sample_image_source(source, int(img.width), int(img.height), int(img.width) * 4, src_x, src_y)
			}
			if settings.image_invert_tone {
				value = 255 - value
			}
			i := (y * target_width + x) * 4
			pixels[i + 0] = value
			pixels[i + 1] = value
			pixels[i + 2] = value
			pixels[i + 3] = 255
		}
	}

	new_image: Flow_Image
	if !flow_create_image(gpu, vk_ctx, &new_image, u32(target_width), u32(target_height), {.SAMPLED, .TRANSFER_DST}) {
		return false
	}
	if !flow_upload_sampled_image(vk_ctx, &new_image, u32(target_width), u32(target_height), pixels) {
		flow_destroy_image(vk_ctx, &new_image)
		return false
	}
	if !flow_retire_vector_field_image(gpu) {
		flow_destroy_image(vk_ctx, &new_image)
		return false
	}
	gpu.vector_field_image = new_image
	write_fixed_string(gpu.vector_field_image_path[:], path)
	gpu.vector_field_image_fit_uploaded = settings.image_fit_mode
	gpu.vector_field_image_mirror_horizontal_uploaded = settings.image_mirror_horizontal
	gpu.vector_field_image_mirror_vertical_uploaded = settings.image_mirror_vertical
	gpu.vector_field_image_invert_tone_uploaded = settings.image_invert_tone
	gpu.vector_field_image_loaded = true
	return true
}

flow_initialize_particles :: proc(gpu: ^Flow_Gpu_State, settings: ^Flow_Settings) {
	if gpu.particle_buffer.mapped == nil {return}
	particles := (cast([^]Flow_Particle)gpu.particle_buffer.mapped)[:gpu.total_pool_size]
	autospawn := min(settings.total_pool_size, max(settings.total_pool_size / 2, 1))
	for i in 0 ..< int(gpu.total_pool_size) {
		spawn_type := i < int(autospawn) ? u32(0) : u32(1)
		particles[i] = {position = {0, 0}, age = 0, lut_index = 0, is_alive = 0, spawn_type = spawn_type}
	}
}

flow_upload_lut :: proc(gpu: ^Flow_Gpu_State, settings: ^Flow_Settings) {
	if gpu.lut_buffer.mapped == nil {return}
	scheme := color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
	data := (cast([^]u32)gpu.lut_buffer.mapped)[:COLOR_SCHEME_U32_COUNT]
	_ = color_scheme_write_u32_buffer(scheme, data)
}

flow_upload_camera :: proc(gpu: ^Flow_Gpu_State, frame_slot: int, vk_ctx: ^engine.Vk_Context) {
	flow_upload_camera_size(gpu, frame_slot, f32(vk_ctx.swapchain_extent.width), f32(vk_ctx.swapchain_extent.height))
}

flow_upload_camera_size :: proc(gpu: ^Flow_Gpu_State, frame_slot: int, width, height: f32) {
	if gpu.camera_buffers[frame_slot].mapped == nil {return}
	camera := cast(^Flow_Camera)gpu.camera_buffers[frame_slot].mapped
	camera^ = {
		transform_matrix = {
			1, 0, 0, 0,
			0, 1, 0, 0,
			0, 0, 1, 0,
			0, 0, 0, 1,
		},
		position = {0, 0},
		zoom = 1,
		aspect_ratio = max(width, 1) / max(height, 1),
	}
}

flow_upload_background_color :: proc(gpu: ^Flow_Gpu_State, frame_slot: int, settings: ^Flow_Settings) {
	if gpu.background_color_buffers[frame_slot].mapped == nil {
		return
	}
	color := cast(^[4]f32)gpu.background_color_buffers[frame_slot].mapped
	color^ = flow_background_color(settings)
}

flow_write_params :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int, sim: ^Remaining_Sim_State, dt: f32) {
	flow_write_params_size(gpu, vk_ctx, frame_slot, sim, dt, vk_ctx.swapchain_extent.width, vk_ctx.swapchain_extent.height)
}

flow_write_params_size :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int, sim: ^Remaining_Sim_State, dt: f32, screen_width, screen_height: u32) {
	settings := &sim.flow
	gpu.show_particles = settings.show_particles
	flow_upload_lut(gpu, settings)
	flow_upload_background_color(gpu, frame_slot, settings)
	width := max(screen_width, 1)
	height := max(screen_height, 1)
	if gpu.vector_params_buffers[frame_slot].mapped != nil {
		params := cast(^Flow_Vector_Params)gpu.vector_params_buffers[frame_slot].mapped
		noise := &settings.noise
		noise_sync_indices(noise)
		params^ = {
			grid_size = FLOW_FIELD_RESOLUTION,
			vector_field_type = u32(settings.vector_field_index),
			noise_kind = u32(noise.kind_index),
			fractal_mode = u32(noise.fractal_mode_index),
			noise_seed = noise.seed,
			offset_x = noise.offset_x + (settings.field_animation_enabled ? sim.time * settings.field_animation_speed : 0),
			offset_y = noise.offset_y + (settings.field_animation_enabled ? sim.time * settings.field_animation_speed * 0.6180339 : 0),
			rotation = noise.rotation,
			anchor_x = noise.anchor_x,
			anchor_y = noise.anchor_y,
			noise_strength = noise.noise_strength,
			amplitude = noise.amplitude,
			frequency = noise.frequency,
			octaves = noise.octaves,
			lacunarity = noise.lacunarity,
			gain = noise.gain,
			warp_mode = u32(noise.warp_mode_index),
			warp_octaves = noise.warp_octaves,
			warp_amplitude = noise.warp_amplitude,
			warp_frequency = noise.warp_frequency,
			gabor_iterations = noise.gabor.iterations,
			gabor_velocity = noise.gabor.velocity,
			gabor_band_width = noise.gabor.band_width,
			gabor_band_softness = noise.gabor.band_softness,
			phasor_iterations = noise.phasor.iterations,
			phasor_velocity = noise.phasor.velocity,
			phasor_band_width = noise.phasor.band_width,
			voronoi_output = u32(noise.voronoi.output_index),
			voronoi_distance_mode = u32(noise.voronoi.distance_mode_index),
			wave_velocity = noise.wave.velocity,
			wave_band_width = noise.wave.band_width,
			wave_band_softness = noise.wave.band_softness,
				time = sim.time,
			vector_magnitude = settings.vector_magnitude,
			image_fit_mode = u32(settings.image_fit_mode),
			image_mirror_horizontal = settings.image_mirror_horizontal ? 1 : 0,
			image_mirror_vertical = settings.image_mirror_vertical ? 1 : 0,
			image_invert_tone = settings.image_invert_tone ? 1 : 0,
			webcam_live = gpu.webcam_live ? 1 : 0,
			target_width = width,
			target_height = height,
		}
	}
	if gpu.sim_params_buffers[frame_slot].mapped != nil {
		params := cast(^Flow_Sim_Params)gpu.sim_params_buffers[frame_slot].mapped
		params^ = {
			autospawn_pool_size = min(settings.total_pool_size, max(settings.total_pool_size / 2, 1)),
			autospawn_rate = settings.autospawn_rate,
			brush_pool_size = settings.total_pool_size - min(settings.total_pool_size, max(settings.total_pool_size / 2, 1)),
			brush_spawn_rate = settings.brush_spawn_rate,
			cursor_size = sim.cursor_size,
			cursor_x = sim.cursor_world[0],
			cursor_y = sim.cursor_world[1],
			display_mode = u32(settings.foreground_index),
			flow_field_resolution = FLOW_FIELD_RESOLUTION,
			height = 2,
			mouse_button_down = flow_mouse_button_down_from_cursor(sim),
			noise_dt_multiplier = 1,
			noise_scale = settings.noise.frequency,
			noise_seed = settings.noise.seed,
			noise_x = settings.noise.offset_x,
			noise_y = settings.noise.offset_y,
			particle_autospawn = settings.particle_autospawn ? u32(1) : u32(0),
			particle_lifetime = settings.particle_lifetime,
			particle_shape = u32(settings.shape_index),
			particle_size = settings.particle_size,
			particle_speed = settings.particle_speed,
			screen_height = height,
			screen_width = width,
			time = sim.time,
			total_pool_size = gpu.total_pool_size,
			trail_decay_rate = settings.trail_decay_rate,
			trail_deposition_rate = settings.trail_deposition_rate,
			trail_diffusion_rate = settings.trail_diffusion_rate,
			trail_map_height = max(gpu.trail_height, 1),
			trail_map_width = max(gpu.trail_width, 1),
			trail_wash_out_rate = settings.trail_wash_out_rate,
			vector_magnitude = settings.vector_magnitude,
			width = 2,
			delta_time = dt,
			emitter_mode = u32(settings.emitter_index),
			emitter_radius = settings.emitter_radius,
			boundary_mode = u32(settings.boundary_index),
			trail_style = u32(settings.trail_style_index),
			field_animation_speed = settings.field_animation_speed,
			field_animation_enabled = settings.field_animation_enabled ? u32(1) : u32(0),
		}
	}
}

flow_write_shape_params :: proc(gpu: ^Flow_Gpu_State, frame_slot: int, sim: ^Remaining_Sim_State) {
	if gpu.shape_params_buffers[frame_slot].mapped == nil {
		return
	}
	settings := &sim.flow
	params := cast(^Flow_Shape_Params)gpu.shape_params_buffers[frame_slot].mapped
	params^ = {
		center_x = sim.cursor_world[0],
		center_y = sim.cursor_world[1],
		size = max(sim.cursor_size, 0.001),
		shape_type = u32(settings.shape_index),
		color = {1, 1, 1, 1},
		intensity = max(settings.trail_deposition_rate, 0),
		antialiasing_width = 2,
		rotation = 0,
		aspect_ratio = 1,
		trail_map_width = max(gpu.trail_width, 1),
		trail_map_height = max(gpu.trail_height, 1),
	}
}

flow_write_spawn_control :: proc(gpu: ^Flow_Gpu_State, sim: ^Remaining_Sim_State, dt: f32) {
	settings := &sim.flow
	if gpu.spawn_control_buffer.mapped == nil {return}
	gpu.autospawn_accumulator += f32(settings.autospawn_rate) * dt
	autospawn_allowed := u32(math.floor(gpu.autospawn_accumulator))
	gpu.autospawn_accumulator -= f32(autospawn_allowed)
	brush_allowed := u32(0)
	if sim.cursor_active != 0 {
		brush_allowed = u32(math.ceil(f32(settings.brush_spawn_rate) * dt))
	}
	control := cast(^Flow_Spawn_Control)gpu.spawn_control_buffer.mapped
	control^ = {autospawn_allowed = min(autospawn_allowed, 100000), brush_allowed = brush_allowed, autospawn_count = 0, brush_count = 0}
}

flow_create_descriptors :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	vector_bindings := [4]vk.DescriptorSetLayoutBinding{{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}}, {binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}}, {binding = 2, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}}, {binding = 3, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.COMPUTE}}}
	update_bindings := [6]vk.DescriptorSetLayoutBinding{{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}}, {binding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}}, {binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}}, {binding = 3, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}}, {binding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}}, {binding = 5, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}}}
	background_bindings := [4]vk.DescriptorSetLayoutBinding{{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX, .FRAGMENT}}, {binding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}}, {binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX, .FRAGMENT}}, {binding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}}}
	trail_bindings := [3]vk.DescriptorSetLayoutBinding{{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE, .FRAGMENT}}, {binding = 1, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE, .FRAGMENT}}, {binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}}}
	shape_bindings := [2]vk.DescriptorSetLayoutBinding{{binding = 0, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}}, {binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}}}
	particle_bindings := [3]vk.DescriptorSetLayoutBinding{{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX, .FRAGMENT}}, {binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX, .FRAGMENT}}, {binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX, .FRAGMENT}}}
	camera_bindings := [1]vk.DescriptorSetLayoutBinding{{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}}}
	if !flow_create_set_layout(vk_ctx, vector_bindings[:], &gpu.vector_set_layout) ||
	   !flow_create_set_layout(vk_ctx, update_bindings[:], &gpu.update_set_layout) ||
	   !flow_create_set_layout(vk_ctx, background_bindings[:], &gpu.background_set_layout) ||
	   !flow_create_set_layout(vk_ctx, trail_bindings[:], &gpu.trail_set_layout) ||
	   !flow_create_set_layout(vk_ctx, shape_bindings[:], &gpu.shape_drawing_set_layout) ||
	   !flow_create_set_layout(vk_ctx, particle_bindings[:], &gpu.particle_set_layout) ||
	   !flow_create_set_layout(vk_ctx, camera_bindings[:], &gpu.camera_set_layout) {return false}
	pool_sizes := [5]vk.DescriptorPoolSize{{type = .STORAGE_BUFFER, descriptorCount = 12 * engine.MAX_FRAMES_IN_FLIGHT}, {type = .UNIFORM_BUFFER, descriptorCount = 8 * engine.MAX_FRAMES_IN_FLIGHT}, {type = .STORAGE_IMAGE, descriptorCount = 3 * engine.MAX_FRAMES_IN_FLIGHT}, {type = .SAMPLED_IMAGE, descriptorCount = engine.MAX_FRAMES_IN_FLIGHT}, {type = .SAMPLER, descriptorCount = engine.MAX_FRAMES_IN_FLIGHT}}
	pool_info := vk.DescriptorPoolCreateInfo{sType = .DESCRIPTOR_POOL_CREATE_INFO, poolSizeCount = u32(len(pool_sizes)), pPoolSizes = raw_data(pool_sizes[:]), maxSets = 7 * engine.MAX_FRAMES_IN_FLIGHT}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &gpu.descriptor_pool) != .SUCCESS {return false}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		layouts := [7]vk.DescriptorSetLayout{gpu.vector_set_layout, gpu.update_set_layout, gpu.background_set_layout, gpu.trail_set_layout, gpu.shape_drawing_set_layout, gpu.particle_set_layout, gpu.camera_set_layout}
		sets: [7]vk.DescriptorSet
		alloc := vk.DescriptorSetAllocateInfo{sType = .DESCRIPTOR_SET_ALLOCATE_INFO, descriptorPool = gpu.descriptor_pool, descriptorSetCount = 7, pSetLayouts = raw_data(layouts[:])}
		if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(sets[:])) != .SUCCESS {return false}
		gpu.vector_sets[frame_slot] = sets[0]
		gpu.update_sets[frame_slot] = sets[1]
		gpu.background_sets[frame_slot] = sets[2]
		gpu.trail_sets[frame_slot] = sets[3]
		gpu.shape_drawing_sets[frame_slot] = sets[4]
		gpu.particle_sets[frame_slot] = sets[5]
		gpu.camera_sets[frame_slot] = sets[6]
	}
	flow_update_descriptors(gpu, vk_ctx)
	return true
}

flow_create_set_layout :: proc(vk_ctx: ^engine.Vk_Context, bindings: []vk.DescriptorSetLayoutBinding, out: ^vk.DescriptorSetLayout) -> bool {
	info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(bindings)), pBindings = raw_data(bindings)}
	return vk.CreateDescriptorSetLayout(vk_ctx.device, &info, nil, out) == .SUCCESS
}

flow_update_descriptors :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		flow_update_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	}
}

flow_update_descriptors_for_slot :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	particle_info := vk.DescriptorBufferInfo{buffer = gpu.particle_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Particle) * int(gpu.total_pool_size))}
	vector_info := vk.DescriptorBufferInfo{buffer = gpu.flow_vector_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Vector) * int(FLOW_FIELD_RESOLUTION * FLOW_FIELD_RESOLUTION))}
	sim_info := vk.DescriptorBufferInfo{buffer = gpu.sim_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Sim_Params))}
	vector_params_info := vk.DescriptorBufferInfo{buffer = gpu.vector_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Vector_Params))}
	lut_info := vk.DescriptorBufferInfo{buffer = gpu.lut_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT)}
	background_color_info := vk.DescriptorBufferInfo{buffer = gpu.background_color_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of([4]f32))}
	spawn_info := vk.DescriptorBufferInfo{buffer = gpu.spawn_control_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Spawn_Control))}
	shape_params_info := vk.DescriptorBufferInfo{buffer = gpu.shape_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Shape_Params))}
	camera_info := vk.DescriptorBufferInfo{buffer = gpu.camera_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Camera))}
	default_image_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.default_image.view}
	if gpu.webcam_live && gpu.webcam_image_ready[frame_slot] && gpu.webcam_images[frame_slot].view != vk.ImageView(0) {
		default_image_info = vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.webcam_images[frame_slot].view}
	} else if gpu.vector_field_image_loaded && gpu.vector_field_image.view != vk.ImageView(0) {
		default_image_info = vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.vector_field_image.view}
	}
	sampler_info := vk.DescriptorImageInfo{sampler = gpu.sampler}
	trail_info := vk.DescriptorImageInfo{imageLayout = .GENERAL, imageView = gpu.trail_image.view}
	vector_set := gpu.vector_sets[frame_slot]
	update_set := gpu.update_sets[frame_slot]
	background_set := gpu.background_sets[frame_slot]
	trail_set := gpu.trail_sets[frame_slot]
	shape_drawing_set := gpu.shape_drawing_sets[frame_slot]
	particle_set := gpu.particle_sets[frame_slot]
	camera_set := gpu.camera_sets[frame_slot]
	writes := [?]vk.WriteDescriptorSet{
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = vector_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vector_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = vector_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &vector_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = vector_set, dstBinding = 2, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &default_image_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = vector_set, dstBinding = 3, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = update_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = update_set, dstBinding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vector_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = update_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &sim_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = update_set, dstBinding = 3, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, pImageInfo = &trail_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = update_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &lut_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = update_set, dstBinding = 5, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &spawn_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = background_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vector_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = background_set, dstBinding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &lut_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = background_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &sim_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = background_set, dstBinding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &background_color_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = trail_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &sim_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = trail_set, dstBinding = 1, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, pImageInfo = &trail_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = trail_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vector_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = shape_drawing_set, dstBinding = 0, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, pImageInfo = &trail_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = shape_drawing_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &shape_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = particle_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = particle_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &sim_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = particle_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &lut_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = camera_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &camera_info},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
}

flow_create_compute_pipeline :: proc(vk_ctx: ^engine.Vk_Context, shader: vk.ShaderModule, set_layout: vk.DescriptorSetLayout, out: ^engine.Vk_Compute_Pipeline) -> bool {
	layouts := [1]vk.DescriptorSetLayout{set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &out.layout) != .SUCCESS {return false}
	stage := vk.PipelineShaderStageCreateInfo{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.COMPUTE}, module = shader, pName = FLOW_ENTRY}
	info := vk.ComputePipelineCreateInfo{sType = .COMPUTE_PIPELINE_CREATE_INFO, stage = stage, layout = out.layout}
	return vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &out.pipeline) == .SUCCESS
}

flow_create_background_pipeline :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	layouts := [2]vk.DescriptorSetLayout{gpu.background_set_layout, gpu.camera_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 2, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gpu.background_pipeline.layout) != .SUCCESS {return false}
	stages := [2]vk.PipelineShaderStageCreateInfo{{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = gpu.background_vertex_shader.handle, pName = FLOW_VERTEX_ENTRY}, {sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = gpu.background_fragment_shader.handle, pName = FLOW_FRAGMENT_ENTRY}}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState{blendEnable = true, srcColorBlendFactor = .SRC_ALPHA, dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA, colorBlendOp = .ADD, srcAlphaBlendFactor = .ONE, dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA, alphaBlendOp = .ADD, colorWriteMask = {.R, .G, .B, .A}}
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = 2, pDynamicStates = raw_data(dynamic_states[:])}
	info := vk.GraphicsPipelineCreateInfo{sType = .GRAPHICS_PIPELINE_CREATE_INFO, stageCount = 2, pStages = raw_data(stages[:]), pVertexInputState = &vertex_input, pInputAssemblyState = &input_assembly, pViewportState = &viewport_state, pRasterizationState = &raster, pMultisampleState = &multisample, pColorBlendState = &blend, pDynamicState = &dynamic_state, layout = gpu.background_pipeline.layout, renderPass = vk_ctx.render_pass, subpass = 0}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &gpu.background_pipeline.pipeline) == .SUCCESS
}

flow_create_trail_pipeline :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	layouts := [2]vk.DescriptorSetLayout{gpu.trail_set_layout, gpu.camera_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 2, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gpu.trail_pipeline.layout) != .SUCCESS {return false}
	stages := [2]vk.PipelineShaderStageCreateInfo{{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = gpu.trail_vertex_shader.handle, pName = FLOW_VERTEX_ENTRY}, {sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = gpu.trail_fragment_shader.handle, pName = FLOW_FRAGMENT_ENTRY}}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState{blendEnable = true, srcColorBlendFactor = .SRC_ALPHA, dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA, colorBlendOp = .ADD, srcAlphaBlendFactor = .ONE, dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA, alphaBlendOp = .ADD, colorWriteMask = {.R, .G, .B, .A}}
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = 2, pDynamicStates = raw_data(dynamic_states[:])}
	info := vk.GraphicsPipelineCreateInfo{sType = .GRAPHICS_PIPELINE_CREATE_INFO, stageCount = 2, pStages = raw_data(stages[:]), pVertexInputState = &vertex_input, pInputAssemblyState = &input_assembly, pViewportState = &viewport_state, pRasterizationState = &raster, pMultisampleState = &multisample, pColorBlendState = &blend, pDynamicState = &dynamic_state, layout = gpu.trail_pipeline.layout, renderPass = vk_ctx.render_pass, subpass = 0}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &gpu.trail_pipeline.pipeline) == .SUCCESS
}

flow_create_particle_pipeline :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	layouts := [2]vk.DescriptorSetLayout{gpu.particle_set_layout, gpu.camera_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 2, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gpu.particle_pipeline.layout) != .SUCCESS {return false}
	stages := [2]vk.PipelineShaderStageCreateInfo{{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = gpu.particle_vertex_shader.handle, pName = FLOW_VERTEX_ENTRY}, {sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = gpu.particle_fragment_shader.handle, pName = FLOW_FRAGMENT_ENTRY}}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState{blendEnable = true, srcColorBlendFactor = .SRC_ALPHA, dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA, colorBlendOp = .ADD, srcAlphaBlendFactor = .ONE, dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA, alphaBlendOp = .ADD, colorWriteMask = {.R, .G, .B, .A}}
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = 2, pDynamicStates = raw_data(dynamic_states[:])}
	info := vk.GraphicsPipelineCreateInfo{sType = .GRAPHICS_PIPELINE_CREATE_INFO, stageCount = 2, pStages = raw_data(stages[:]), pVertexInputState = &vertex_input, pInputAssemblyState = &input_assembly, pViewportState = &viewport_state, pRasterizationState = &raster, pMultisampleState = &multisample, pColorBlendState = &blend, pDynamicState = &dynamic_state, layout = gpu.particle_pipeline.layout, renderPass = vk_ctx.render_pass, subpass = 0}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &gpu.particle_pipeline.pipeline) == .SUCCESS
}
