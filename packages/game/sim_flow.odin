package game

import engine "../engine"
import uifw "../ui"

import "core:math"
import vk "vendor:vulkan"

FLOW_VECTOR_SHADER_SOURCE :: "assets/shaders/simulations/flow/shaders/flow_vector_compute.slang"
FLOW_PARTICLE_UPDATE_SHADER_SOURCE :: "assets/shaders/simulations/flow/shaders/particle_update.slang"
FLOW_TRAIL_DECAY_SHADER_SOURCE :: "assets/shaders/simulations/flow/shaders/trail_decay_diffusion.slang"
FLOW_SHAPE_DRAWING_SHADER_SOURCE :: "assets/shaders/simulations/flow/shaders/shape_drawing.slang"
FLOW_BACKGROUND_SHADER_SOURCE :: "assets/shaders/simulations/flow/shaders/background_render.slang"
FLOW_TRAIL_SHADER_SOURCE :: "assets/shaders/simulations/flow/shaders/trail_render.slang"
FLOW_PARTICLE_SHADER_SOURCE :: "assets/shaders/simulations/flow/shaders/particle_render.slang"
FLOW_VECTOR_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/flow_vector_compute"
FLOW_PARTICLE_UPDATE_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/particle_update"
FLOW_TRAIL_DECAY_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/trail_decay_diffusion"
FLOW_SHAPE_DRAWING_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/shape_drawing"
FLOW_BACKGROUND_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/background_render_vertex"
FLOW_BACKGROUND_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/background_render_fragment"
FLOW_TRAIL_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/trail_render_vertex"
FLOW_TRAIL_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/trail_render_fragment"
FLOW_PARTICLE_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/particle_render_vertex"
FLOW_PARTICLE_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/flow/shaders/particle_render_fragment"
FLOW_SOURCE_ENTRY :: "main"
FLOW_VERTEX_SOURCE_ENTRY :: "vs_main"
FLOW_FRAGMENT_SOURCE_ENTRY :: "fs_main"
FLOW_ENTRY :: cstring("main")
FLOW_VERTEX_ENTRY :: cstring("main")
FLOW_FRAGMENT_ENTRY :: cstring("main")
FLOW_FIELD_RESOLUTION :: u32(128)
FLOW_IMAGE_FORMAT :: vk.Format(.R8G8B8A8_UNORM)

Flow_Particle :: struct #align(8) {
	position: [2]f32,
	age: f32,
	lut_index: u32,
	is_alive: u32,
	spawn_type: u32,
	_pad0: u32,
	_pad1: u32,
}

Flow_Vector :: struct #align(8) {
	position: [2]f32,
	direction: [2]f32,
}

Flow_Vector_Params :: struct #align(16) {
	grid_size: u32,
	vector_field_type: u32,
	noise_kind: u32,
	fractal_mode: u32,
	noise_seed: u32,
	offset_x: f32,
	offset_y: f32,
	rotation: f32,
	anchor_x: f32,
	anchor_y: f32,
	noise_strength: f32,
	amplitude: f32,
	frequency: f32,
	octaves: u32,
	lacunarity: f32,
	gain: f32,
	warp_mode: u32,
	warp_octaves: u32,
	warp_amplitude: f32,
	warp_frequency: f32,
	gabor_iterations: u32,
	gabor_velocity: f32,
	gabor_band_width: f32,
	gabor_band_softness: f32,
	phasor_iterations: u32,
	phasor_velocity: f32,
	phasor_band_width: f32,
	voronoi_output: u32,
	voronoi_distance_mode: u32,
	wave_velocity: f32,
	wave_band_width: f32,
	wave_band_softness: f32,
	time: f32,
	vector_magnitude: f32,
	_pad0: u32,
	_pad1: u32,
}

Flow_Spawn_Control :: struct #align(16) {
	autospawn_allowed: u32,
	brush_allowed: u32,
	autospawn_count: u32,
	brush_count: u32,
}

Flow_Sim_Params :: struct #align(16) {
	autospawn_pool_size: u32,
	autospawn_rate: u32,
	brush_pool_size: u32,
	brush_spawn_rate: u32,
	cursor_size: f32,
	cursor_x: f32,
	cursor_y: f32,
	display_mode: u32,
	flow_field_resolution: u32,
	height: f32,
	mouse_button_down: u32,
	noise_dt_multiplier: f32,
	noise_scale: f32,
	noise_seed: u32,
	noise_x: f32,
	noise_y: f32,
	particle_autospawn: u32,
	particle_lifetime: f32,
	particle_shape: u32,
	particle_size: u32,
	particle_speed: f32,
	screen_height: u32,
	screen_width: u32,
	time: f32,
	total_pool_size: u32,
	trail_decay_rate: f32,
	trail_deposition_rate: f32,
	trail_diffusion_rate: f32,
	trail_map_height: u32,
	trail_map_width: u32,
	trail_wash_out_rate: f32,
	vector_magnitude: f32,
	width: f32,
	delta_time: f32,
	_padding_1: u32,
	_padding_2: u32,
}

Flow_Camera :: Vectors_Camera_Uniform

Flow_Shape_Params :: struct #align(16) {
	center_x: f32,
	center_y: f32,
	size: f32,
	shape_type: u32,
	color: [4]f32,
	intensity: f32,
	antialiasing_width: f32,
	rotation: f32,
	aspect_ratio: f32,
	trail_map_width: u32,
	trail_map_height: u32,
	_padding_0: u32,
	_padding_1: u32,
}

Flow_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	layout: vk.ImageLayout,
	width: u32,
	height: u32,
}

Flow_Gpu_State :: struct {
	vector_shader: engine.Vk_Shader_Module,
	particle_update_shader: engine.Vk_Shader_Module,
	trail_decay_shader: engine.Vk_Shader_Module,
	shape_drawing_shader: engine.Vk_Shader_Module,
	background_vertex_shader: engine.Vk_Shader_Module,
	background_fragment_shader: engine.Vk_Shader_Module,
	trail_vertex_shader: engine.Vk_Shader_Module,
	trail_fragment_shader: engine.Vk_Shader_Module,
	particle_vertex_shader: engine.Vk_Shader_Module,
	particle_fragment_shader: engine.Vk_Shader_Module,
	vector_pipeline: engine.Vk_Compute_Pipeline,
	particle_update_pipeline: engine.Vk_Compute_Pipeline,
	trail_decay_pipeline: engine.Vk_Compute_Pipeline,
	shape_drawing_pipeline: engine.Vk_Compute_Pipeline,
	background_pipeline: engine.Vk_Graphics_Pipeline,
	trail_pipeline: engine.Vk_Graphics_Pipeline,
	particle_pipeline: engine.Vk_Graphics_Pipeline,
	vector_set_layout: vk.DescriptorSetLayout,
	update_set_layout: vk.DescriptorSetLayout,
	background_set_layout: vk.DescriptorSetLayout,
	trail_set_layout: vk.DescriptorSetLayout,
	shape_drawing_set_layout: vk.DescriptorSetLayout,
	particle_set_layout: vk.DescriptorSetLayout,
	camera_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	vector_set: vk.DescriptorSet,
	update_set: vk.DescriptorSet,
	background_set: vk.DescriptorSet,
	trail_set: vk.DescriptorSet,
	shape_drawing_set: vk.DescriptorSet,
	particle_set: vk.DescriptorSet,
	camera_set: vk.DescriptorSet,
	particle_buffer: engine.Vk_Buffer,
	flow_vector_buffer: engine.Vk_Buffer,
	sim_params_buffer: engine.Vk_Buffer,
	vector_params_buffer: engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	background_color_buffer: engine.Vk_Buffer,
	spawn_control_buffer: engine.Vk_Buffer,
	shape_params_buffer: engine.Vk_Buffer,
	camera_buffer: engine.Vk_Buffer,
	trail_image: Flow_Image,
	default_image: Flow_Image,
	vector_field_image: Flow_Image,
	vector_field_image_loaded: bool,
	vector_field_image_path: [MAX_FILE_PATH]u8,
	vector_field_image_fit_uploaded: Vector_Image_Fit_Mode,
	vector_field_image_mirror_horizontal_uploaded: bool,
	vector_field_image_mirror_vertical_uploaded: bool,
	vector_field_image_invert_tone_uploaded: bool,
	sampler: vk.Sampler,
	total_pool_size: u32,
	trail_width: u32,
	trail_height: u32,
	autospawn_accumulator: f32,
	brush_spawn_accumulator: f32,
	trail_cleared: bool,
	default_image_initialized: bool,
	show_particles: bool,
	ready: bool,
}

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
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Flow_Sim_Params)), {.UNIFORM_BUFFER}, &gpu.sim_params_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Flow_Vector_Params)), {.UNIFORM_BUFFER}, &gpu.vector_params_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT), {.STORAGE_BUFFER}, &gpu.lut_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of([4]f32)), {.UNIFORM_BUFFER}, &gpu.background_color_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Flow_Spawn_Control)), {.STORAGE_BUFFER}, &gpu.spawn_control_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Flow_Shape_Params)), {.UNIFORM_BUFFER}, &gpu.shape_params_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Flow_Camera)), {.UNIFORM_BUFFER}, &gpu.camera_buffer) {
		flow_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !flow_create_image(gpu, vk_ctx, &gpu.trail_image, gpu.trail_width, gpu.trail_height, {.STORAGE, .SAMPLED, .TRANSFER_DST}) ||
	   !flow_create_image(gpu, vk_ctx, &gpu.default_image, 1, 1, {.SAMPLED, .TRANSFER_DST}) ||
	   !flow_create_sampler(gpu, vk_ctx) {
		flow_gpu_destroy(gpu, vk_ctx)
		return false
	}
	flow_initialize_particles(gpu, settings)
	flow_upload_camera(gpu, vk_ctx)
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

	flow_destroy_image(vk_ctx, &gpu.vector_field_image)
	if !flow_create_image(gpu, vk_ctx, &gpu.vector_field_image, u32(target_width), u32(target_height), {.SAMPLED, .TRANSFER_DST}) {
		gpu.vector_field_image_loaded = false
		return false
	}
	if !flow_upload_sampled_image(vk_ctx, &gpu.vector_field_image, u32(target_width), u32(target_height), pixels) {
		gpu.vector_field_image_loaded = false
		return false
	}
	write_fixed_string(gpu.vector_field_image_path[:], path)
	gpu.vector_field_image_fit_uploaded = settings.image_fit_mode
	gpu.vector_field_image_mirror_horizontal_uploaded = settings.image_mirror_horizontal
	gpu.vector_field_image_mirror_vertical_uploaded = settings.image_mirror_vertical
	gpu.vector_field_image_invert_tone_uploaded = settings.image_invert_tone
	gpu.vector_field_image_loaded = true
	flow_update_descriptors(gpu, vk_ctx)
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

flow_upload_camera :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	flow_upload_camera_size(gpu, f32(vk_ctx.swapchain_extent.width), f32(vk_ctx.swapchain_extent.height))
}

flow_upload_camera_size :: proc(gpu: ^Flow_Gpu_State, width, height: f32) {
	if gpu.camera_buffer.mapped == nil {return}
	camera := cast(^Flow_Camera)gpu.camera_buffer.mapped
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

flow_upload_background_color :: proc(gpu: ^Flow_Gpu_State, settings: ^Flow_Settings) {
	if gpu.background_color_buffer.mapped == nil {
		return
	}
	color := cast(^[4]f32)gpu.background_color_buffer.mapped
	#partial switch settings.background_color_mode {
	case .Black:
		color^ = {0, 0, 0, 1}
	case .White:
		color^ = {1, 1, 1, 1}
	case .Gray18:
		color^ = {0.18, 0.18, 0.18, 1}
	case .Color_Scheme:
		scheme := color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
		color^ = color_scheme_color_at(scheme, COLOR_SCHEME_SIZE - 1)
	case:
		color^ = {0, 0, 0, 1}
	}
}

flow_mouse_button_down_from_cursor :: proc(sim: ^Remaining_Sim_State) -> u32 {
	if sim.cursor_active == 0 {
		return 0
	}
	return sim.cursor_mode
}

flow_write_params :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, sim: ^Remaining_Sim_State, dt: f32) {
	flow_write_params_size(gpu, vk_ctx, sim, dt, vk_ctx.swapchain_extent.width, vk_ctx.swapchain_extent.height)
}

flow_write_params_size :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, sim: ^Remaining_Sim_State, dt: f32, screen_width, screen_height: u32) {
	settings := &sim.flow
	gpu.show_particles = settings.show_particles
	flow_upload_lut(gpu, settings)
	flow_upload_background_color(gpu, settings)
	width := max(screen_width, 1)
	height := max(screen_height, 1)
	if gpu.vector_params_buffer.mapped != nil {
		params := cast(^Flow_Vector_Params)gpu.vector_params_buffer.mapped
		noise := &settings.noise
		noise_sync_indices(noise)
		params^ = {
			grid_size = FLOW_FIELD_RESOLUTION,
			vector_field_type = u32(settings.vector_field_index),
			noise_kind = u32(noise.kind_index),
			fractal_mode = u32(noise.fractal_mode_index),
			noise_seed = noise.seed,
			offset_x = noise.offset_x,
			offset_y = noise.offset_y,
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
		}
	}
	if gpu.sim_params_buffer.mapped != nil {
		params := cast(^Flow_Sim_Params)gpu.sim_params_buffer.mapped
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
		}
	}
}

flow_write_shape_params :: proc(gpu: ^Flow_Gpu_State, sim: ^Remaining_Sim_State) {
	if gpu.shape_params_buffer.mapped == nil {
		return
	}
	settings := &sim.flow
	params := cast(^Flow_Shape_Params)gpu.shape_params_buffer.mapped
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
	pool_sizes := [5]vk.DescriptorPoolSize{{type = .STORAGE_BUFFER, descriptorCount = 12}, {type = .UNIFORM_BUFFER, descriptorCount = 8}, {type = .STORAGE_IMAGE, descriptorCount = 3}, {type = .SAMPLED_IMAGE, descriptorCount = 1}, {type = .SAMPLER, descriptorCount = 1}}
	pool_info := vk.DescriptorPoolCreateInfo{sType = .DESCRIPTOR_POOL_CREATE_INFO, poolSizeCount = u32(len(pool_sizes)), pPoolSizes = raw_data(pool_sizes[:]), maxSets = 7}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &gpu.descriptor_pool) != .SUCCESS {return false}
	layouts := [7]vk.DescriptorSetLayout{gpu.vector_set_layout, gpu.update_set_layout, gpu.background_set_layout, gpu.trail_set_layout, gpu.shape_drawing_set_layout, gpu.particle_set_layout, gpu.camera_set_layout}
	sets: [7]vk.DescriptorSet
	alloc := vk.DescriptorSetAllocateInfo{sType = .DESCRIPTOR_SET_ALLOCATE_INFO, descriptorPool = gpu.descriptor_pool, descriptorSetCount = 7, pSetLayouts = raw_data(layouts[:])}
	if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(sets[:])) != .SUCCESS {return false}
	gpu.vector_set = sets[0]; gpu.update_set = sets[1]; gpu.background_set = sets[2]; gpu.trail_set = sets[3]; gpu.shape_drawing_set = sets[4]; gpu.particle_set = sets[5]; gpu.camera_set = sets[6]
	flow_update_descriptors(gpu, vk_ctx)
	return true
}

flow_create_set_layout :: proc(vk_ctx: ^engine.Vk_Context, bindings: []vk.DescriptorSetLayoutBinding, out: ^vk.DescriptorSetLayout) -> bool {
	info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(bindings)), pBindings = raw_data(bindings)}
	return vk.CreateDescriptorSetLayout(vk_ctx.device, &info, nil, out) == .SUCCESS
}

flow_update_descriptors :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	particle_info := vk.DescriptorBufferInfo{buffer = gpu.particle_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Particle) * int(gpu.total_pool_size))}
	vector_info := vk.DescriptorBufferInfo{buffer = gpu.flow_vector_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Vector) * int(FLOW_FIELD_RESOLUTION * FLOW_FIELD_RESOLUTION))}
	sim_info := vk.DescriptorBufferInfo{buffer = gpu.sim_params_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Sim_Params))}
	vector_params_info := vk.DescriptorBufferInfo{buffer = gpu.vector_params_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Vector_Params))}
	lut_info := vk.DescriptorBufferInfo{buffer = gpu.lut_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT)}
	background_color_info := vk.DescriptorBufferInfo{buffer = gpu.background_color_buffer.handle, offset = 0, range = vk.DeviceSize(size_of([4]f32))}
	spawn_info := vk.DescriptorBufferInfo{buffer = gpu.spawn_control_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Spawn_Control))}
	shape_params_info := vk.DescriptorBufferInfo{buffer = gpu.shape_params_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Shape_Params))}
	camera_info := vk.DescriptorBufferInfo{buffer = gpu.camera_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Flow_Camera))}
	default_image_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.default_image.view}
	if gpu.vector_field_image_loaded && gpu.vector_field_image.view != vk.ImageView(0) {
		default_image_info = vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.vector_field_image.view}
	}
	sampler_info := vk.DescriptorImageInfo{sampler = gpu.sampler}
	trail_info := vk.DescriptorImageInfo{imageLayout = .GENERAL, imageView = gpu.trail_image.view}
	writes := [?]vk.WriteDescriptorSet{
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.vector_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vector_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.vector_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &vector_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.vector_set, dstBinding = 2, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &default_image_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.vector_set, dstBinding = 3, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.update_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.update_set, dstBinding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vector_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.update_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &sim_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.update_set, dstBinding = 3, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, pImageInfo = &trail_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.update_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &lut_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.update_set, dstBinding = 5, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &spawn_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.background_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vector_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.background_set, dstBinding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &lut_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.background_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &sim_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.background_set, dstBinding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &background_color_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.trail_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &sim_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.trail_set, dstBinding = 1, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, pImageInfo = &trail_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.trail_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &vector_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.shape_drawing_set, dstBinding = 0, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, pImageInfo = &trail_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.shape_drawing_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &shape_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.particle_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.particle_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &sim_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.particle_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &lut_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.camera_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &camera_info},
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

flow_transition_image :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, image: ^Flow_Image, new_layout: vk.ImageLayout) {
	if image.layout == new_layout {return}
	src_access: vk.AccessFlags
	dst_access: vk.AccessFlags
	src_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	dst_stage := vk.PipelineStageFlags{.COMPUTE_SHADER}
	if image.layout == .GENERAL {
		src_access = {.SHADER_WRITE}
		src_stage = {.COMPUTE_SHADER}
	} else if image.layout == .TRANSFER_DST_OPTIMAL {
		src_access = {.TRANSFER_WRITE}
		src_stage = {.TRANSFER}
	}
	if new_layout == .GENERAL {
		dst_access = {.SHADER_READ, .SHADER_WRITE}
	} else if new_layout == .SHADER_READ_ONLY_OPTIMAL {
		dst_access = {.SHADER_READ}
		dst_stage = {.COMPUTE_SHADER}
	} else if new_layout == .TRANSFER_DST_OPTIMAL {
		dst_access = {.TRANSFER_WRITE}
		dst_stage = {.TRANSFER}
	}
	barrier := vk.ImageMemoryBarrier{sType = .IMAGE_MEMORY_BARRIER, srcAccessMask = src_access, dstAccessMask = dst_access, oldLayout = image.layout, newLayout = new_layout, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, image = image.handle, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	vk.CmdPipelineBarrier(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	image.layout = new_layout
}

flow_compute_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dst: vk.PipelineStageFlags) {
	barrier := vk.MemoryBarrier{sType = .MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.SHADER_READ, .SHADER_WRITE}}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, dst, {}, 1, &barrier, 0, nil, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

flow_gpu_step :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim: ^Remaining_Sim_State, dt: f32) {
	width := max(vk_ctx.swapchain_extent.width, 1)
	height := max(vk_ctx.swapchain_extent.height, 1)
	flow_gpu_step_size(gpu, vk_ctx, cmd, sim, dt, width, height, width, height)
}

flow_gpu_step_size :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim: ^Remaining_Sim_State, dt: f32, trail_width, trail_height, screen_width, screen_height: u32) {
	settings := &sim.flow
	if !flow_gpu_ensure_size(gpu, vk_ctx, settings, trail_width, trail_height) {return}
	flow_write_params_size(gpu, vk_ctx, sim, dt, screen_width, screen_height)
	if sim.paused {return}
	flow_transition_image(vk_ctx, cmd, &gpu.trail_image, .GENERAL)
	if !gpu.default_image_initialized {
		flow_transition_image(vk_ctx, cmd, &gpu.default_image, .TRANSFER_DST_OPTIMAL)
		default_clear := vk.ClearColorValue{float32 = {1, 1, 1, 1}}
		default_range := vk.ImageSubresourceRange{aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}
		vk.CmdClearColorImage(cmd, gpu.default_image.handle, .TRANSFER_DST_OPTIMAL, &default_clear, 1, &default_range)
		gpu.default_image_initialized = true
	}
	flow_transition_image(vk_ctx, cmd, &gpu.default_image, .SHADER_READ_ONLY_OPTIMAL)
	if !gpu.trail_cleared {
		clear := vk.ClearColorValue{float32 = {0, 0, 0, 0}}
		range := vk.ImageSubresourceRange{aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}
		vk.CmdClearColorImage(cmd, gpu.trail_image.handle, .GENERAL, &clear, 1, &range)
		gpu.trail_cleared = true
	}
	flow_write_spawn_control(gpu, sim, dt)
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.vector_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.vector_pipeline.layout, 0, 1, &gpu.vector_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, (FLOW_FIELD_RESOLUTION + 15) / 16, (FLOW_FIELD_RESOLUTION + 15) / 16, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	flow_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.trail_decay_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.trail_decay_pipeline.layout, 0, 1, &gpu.trail_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, (max(gpu.trail_width, 1) + 15) / 16, (max(gpu.trail_height, 1) + 15) / 16, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	flow_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	if sim.cursor_active != 0 && sim.cursor_mode == 1 && gpu.shape_drawing_pipeline.pipeline != vk.Pipeline(0) {
		flow_write_shape_params(gpu, sim)
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.shape_drawing_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.shape_drawing_pipeline.layout, 0, 1, &gpu.shape_drawing_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDispatch(cmd, (max(gpu.trail_width, 1) + 7) / 8, (max(gpu.trail_height, 1) + 7) / 8, 1)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		flow_compute_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	}
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.particle_update_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.particle_update_pipeline.layout, 0, 1, &gpu.update_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, (gpu.total_pool_size + 63) / 64, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	flow_compute_barrier(vk_ctx, cmd, {.VERTEX_SHADER, .FRAGMENT_SHADER})
}

flow_gpu_step_preview :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim: ^Remaining_Sim_State, dt: f32, preview_width, preview_height: u32) {
	flow_gpu_step_size(gpu, vk_ctx, cmd, sim, dt, preview_width, preview_height, preview_width, preview_height)
}

flow_gpu_present :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame) {
	viewport := vk.Viewport{x = 0, y = 0, width = f32(vk_ctx.swapchain_extent.width), height = f32(vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = vk_ctx.swapchain_extent}
	flow_gpu_present_viewport(gpu, vk_ctx, frame, viewport, scissor)
}

flow_gpu_present_viewport :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gpu.ready || gpu.particle_pipeline.pipeline == vk.Pipeline(0) {return}
	flow_upload_camera_size(gpu, viewport.width, viewport.height)
	if gpu.trail_pipeline.pipeline != vk.Pipeline(0) {
		flow_transition_image(vk_ctx, frame.command_buffer, &gpu.trail_image, .GENERAL)
	}
	flow_gpu_draw_prepared_viewport(gpu, vk_ctx, frame, viewport, scissor)
}

flow_gpu_draw_prepared_viewport :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gpu.ready || gpu.particle_pipeline.pipeline == vk.Pipeline(0) {return}
	cmd := frame.command_buffer
	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(cmd, 0, 1, &local_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &local_scissor)
	if gpu.background_pipeline.pipeline != vk.Pipeline(0) {
		vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.background_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.background_pipeline.layout, 0, 1, &gpu.background_set, 0, nil)
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.background_pipeline.layout, 1, 1, &gpu.camera_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 6, 1, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
	if gpu.trail_pipeline.pipeline != vk.Pipeline(0) {
		vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.trail_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.trail_pipeline.layout, 0, 1, &gpu.trail_set, 0, nil)
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.trail_pipeline.layout, 1, 1, &gpu.camera_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 6, 1, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
	if gpu.show_particles {
		vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.particle_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.particle_pipeline.layout, 0, 1, &gpu.particle_set, 0, nil)
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.particle_pipeline.layout, 1, 1, &gpu.camera_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 6, gpu.total_pool_size, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
}

flow_clear_color :: proc(settings: ^Flow_Settings) -> uifw.Color {
	_ = settings
	return {0, 0, 0, 1}
}

flow_destroy_compute_pipeline :: proc(vk_ctx: ^engine.Vk_Context, pipeline: ^engine.Vk_Compute_Pipeline) {
	if pipeline.pipeline != vk.Pipeline(0) {vk.DestroyPipeline(vk_ctx.device, pipeline.pipeline, nil)}
	if pipeline.layout != vk.PipelineLayout(0) {vk.DestroyPipelineLayout(vk_ctx.device, pipeline.layout, nil)}
	pipeline^ = {}
}

flow_destroy_image :: proc(vk_ctx: ^engine.Vk_Context, image: ^Flow_Image) {
	if image.view != vk.ImageView(0) {vk.DestroyImageView(vk_ctx.device, image.view, nil)}
	if image.handle != vk.Image(0) {vk.DestroyImage(vk_ctx.device, image.handle, nil)}
	if image.memory != vk.DeviceMemory(0) {vk.FreeMemory(vk_ctx.device, image.memory, nil)}
	image^ = {}
}

flow_gpu_destroy :: proc(gpu: ^Flow_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	if vk_ctx == nil || vk_ctx.device == nil {gpu^ = {}; return}
	flow_destroy_compute_pipeline(vk_ctx, &gpu.vector_pipeline)
	flow_destroy_compute_pipeline(vk_ctx, &gpu.particle_update_pipeline)
	flow_destroy_compute_pipeline(vk_ctx, &gpu.trail_decay_pipeline)
	flow_destroy_compute_pipeline(vk_ctx, &gpu.shape_drawing_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.background_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.trail_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.particle_pipeline)
	if gpu.descriptor_pool != vk.DescriptorPool(0) {vk.DestroyDescriptorPool(vk_ctx.device, gpu.descriptor_pool, nil)}
	if gpu.vector_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.vector_set_layout, nil)}
	if gpu.update_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.update_set_layout, nil)}
	if gpu.background_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.background_set_layout, nil)}
	if gpu.trail_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.trail_set_layout, nil)}
	if gpu.shape_drawing_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.shape_drawing_set_layout, nil)}
	if gpu.particle_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.particle_set_layout, nil)}
	if gpu.camera_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.camera_set_layout, nil)}
	if gpu.sampler != vk.Sampler(0) {vk.DestroySampler(vk_ctx.device, gpu.sampler, nil)}
	engine.vk_destroy_buffer(vk_ctx, &gpu.particle_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.flow_vector_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.sim_params_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.vector_params_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.lut_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.background_color_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.spawn_control_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.shape_params_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.camera_buffer)
	flow_destroy_image(vk_ctx, &gpu.trail_image)
	flow_destroy_image(vk_ctx, &gpu.default_image)
	flow_destroy_image(vk_ctx, &gpu.vector_field_image)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.vector_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.particle_update_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.trail_decay_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.shape_drawing_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.background_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.background_fragment_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.trail_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.trail_fragment_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.particle_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.particle_fragment_shader)
	gpu^ = {}
}
