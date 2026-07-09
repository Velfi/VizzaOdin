package game

import engine "../engine"
import uifw "../ui"

import "core:math"
import vk "vendor:vulkan"

MOIRE_COMPUTE_SHADER_SOURCE :: "assets/shaders/simulations/moire/compute.slang"
MOIRE_PRESENT_SHADER_SOURCE :: "assets/shaders/simulations/voronoi_ca/shaders/infinite_render.slang"
MOIRE_COMPUTE_FALLBACK_SPV :: "build/shaders/simulations/moire/compute"
MOIRE_PRESENT_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/infinite_render_vertex"
MOIRE_PRESENT_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/infinite_render_fragment"
MOIRE_COMPUTE_SOURCE_ENTRY :: "main"
MOIRE_PRESENT_VERTEX_SOURCE_ENTRY :: "vs_main"
MOIRE_PRESENT_FRAGMENT_SOURCE_ENTRY :: "fs_main_texture"
MOIRE_COMPUTE_ENTRY :: cstring("main")
MOIRE_PRESENT_VERTEX_ENTRY :: cstring("main")
MOIRE_PRESENT_FRAGMENT_ENTRY :: cstring("main")
MOIRE_IMAGE_FORMAT :: vk.Format(.R8G8B8A8_UNORM)
MOIRE_WORKGROUP_SIZE :: u32(8)
MOIRE_RETIRED_IMAGE_TEXTURE_CAP :: 4

Moire_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	layout: vk.ImageLayout,
}

Moire_Retired_Image_Texture :: struct {
	image: Moire_Image,
	pending_frame_slots: u32,
}

Moire_Params :: struct #align(16) {
	time: f32,
	width: f32,
	height: f32,
	generator_type: f32,
	base_freq: f32,
	moire_amount: f32,
	moire_rotation: f32,
	moire_scale: f32,
	moire_interference: f32,
	moire_rotation3: f32,
	moire_scale3: f32,
	moire_weight3: f32,
	radial_swirl_strength: f32,
	radial_starburst_count: f32,
	radial_center_brightness: f32,
	color_scheme_reversed: f32,
	advect_strength: f32,
	advect_speed: f32,
	curl: f32,
	decay: f32,
	image_loaded: f32,
	image_mode_enabled: f32,
	image_interference_mode: f32,
	image_mirror_horizontal: f32,
	image_mirror_vertical: f32,
	image_invert_tone: f32,
	_pad0: f32,
	_pad1: f32,
}

Moire_Render_Params :: struct #align(16) {
	filtering_mode: u32,
	_pad0: u32,
	_pad1: u32,
	_pad2: u32,
}

Moire_Camera :: Vectors_Camera_Uniform

Moire_Gpu_State :: struct {
	width: i32,
	height: i32,
	images: [2]Moire_Image,
	state_index: u32,
	compute_shader: engine.Vk_Shader_Module,
	present_vertex_shader: engine.Vk_Shader_Module,
	present_fragment_shader: engine.Vk_Shader_Module,
	compute_pipeline: engine.Vk_Compute_Pipeline,
	present_pipeline: engine.Vk_Graphics_Pipeline,
	compute_set_layout: vk.DescriptorSetLayout,
	texture_set_layout: vk.DescriptorSetLayout,
	camera_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	compute_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	texture_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	camera_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	render_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	camera_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	sampler: vk.Sampler,
	lut_uploaded_scheme: Color_Scheme_Name,
	lut_uploaded_reversed: bool,
	image_texture: Moire_Image,
	retired_image_textures: [MOIRE_RETIRED_IMAGE_TEXTURE_CAP]Moire_Retired_Image_Texture,
	image_loaded: bool,
	image_path: [MAX_FILE_PATH]u8,
	image_fit_uploaded: Vector_Image_Fit_Mode,
	image_mirror_horizontal_uploaded: bool,
	image_mirror_vertical_uploaded: bool,
	image_invert_tone_uploaded: bool,
	image_width: i32,
	image_height: i32,
	ready: bool,
}

moire_gpu_ensure :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, width, height: i32) -> bool {
	if gpu.ready && gpu.width == width && gpu.height == height {
		return true
	}
	moire_gpu_destroy(gpu, vk_ctx)
	gpu.width = max(width, 1)
	gpu.height = max(height, 1)
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, MOIRE_COMPUTE_SHADER_SOURCE, MOIRE_COMPUTE_FALLBACK_SPV, .Compute, MOIRE_COMPUTE_SOURCE_ENTRY, &gpu.compute_shader) {
		engine.log_error("moire_gpu_ensure: compute shader load failed source=", MOIRE_COMPUTE_SHADER_SOURCE)
		return false
	}
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, MOIRE_PRESENT_SHADER_SOURCE, MOIRE_PRESENT_VERTEX_FALLBACK_SPV, .Vertex, MOIRE_PRESENT_VERTEX_SOURCE_ENTRY, &gpu.present_vertex_shader) {
		engine.log_error("moire_gpu_ensure: present vertex shader load failed source=", MOIRE_PRESENT_SHADER_SOURCE)
		moire_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, MOIRE_PRESENT_SHADER_SOURCE, MOIRE_PRESENT_FRAGMENT_FALLBACK_SPV, .Fragment, MOIRE_PRESENT_FRAGMENT_SOURCE_ENTRY, &gpu.present_fragment_shader) {
		engine.log_error("moire_gpu_ensure: present fragment shader load failed source=", MOIRE_PRESENT_SHADER_SOURCE)
		moire_gpu_destroy(gpu, vk_ctx)
		return false
	}
	for i in 0 ..< 2 {
		if !moire_create_image(gpu, vk_ctx, i) {
			moire_gpu_destroy(gpu, vk_ctx)
			return false
		}
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Moire_Params)), {.UNIFORM_BUFFER}, &gpu.params_buffers[frame_slot]) {
			moire_gpu_destroy(gpu, vk_ctx)
			return false
		}
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT), {.STORAGE_BUFFER}, &gpu.lut_buffer) {
		moire_gpu_destroy(gpu, vk_ctx)
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Moire_Render_Params)), {.UNIFORM_BUFFER}, &gpu.render_params_buffers[frame_slot]) {
			moire_gpu_destroy(gpu, vk_ctx)
			return false
		}
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Moire_Camera)), {.UNIFORM_BUFFER}, &gpu.camera_buffers[frame_slot]) {
			moire_gpu_destroy(gpu, vk_ctx)
			return false
		}
		moire_upload_render_params(gpu, frame_slot)
		moire_upload_camera(gpu, frame_slot)
	}
	if !moire_create_sampler(gpu, vk_ctx) {
		moire_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !moire_create_descriptors(gpu, vk_ctx) {
		moire_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !moire_create_compute_pipeline(gpu, vk_ctx) {
		moire_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !moire_create_present_pipeline(gpu, vk_ctx) {
		moire_gpu_destroy(gpu, vk_ctx)
		return false
	}
	gpu.ready = true
	return true
}

moire_create_image :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, index: int) -> bool {
	image := &gpu.images[index]
	info := vk.ImageCreateInfo {
		sType = .IMAGE_CREATE_INFO,
		imageType = .D2,
		format = MOIRE_IMAGE_FORMAT,
		extent = {u32(gpu.width), u32(gpu.height), 1},
		mipLevels = 1,
		arrayLayers = 1,
		samples = {._1},
		tiling = .OPTIMAL,
		usage = {.STORAGE, .SAMPLED, .TRANSFER_DST},
		sharingMode = .EXCLUSIVE,
		initialLayout = .UNDEFINED,
	}
	if vk.CreateImage(vk_ctx.device, &info, nil, &image.handle) != .SUCCESS {
		return false
	}
	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device, image.handle, &req)
	memory_type, ok := engine.vk_find_memory_type(vk_ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {
		return false
	}
	alloc := vk.MemoryAllocateInfo{sType = .MEMORY_ALLOCATE_INFO, allocationSize = req.size, memoryTypeIndex = memory_type}
	if vk.AllocateMemory(vk_ctx.device, &alloc, nil, &image.memory) != .SUCCESS {
		return false
	}
	if vk.BindImageMemory(vk_ctx.device, image.handle, image.memory, 0) != .SUCCESS {
		return false
	}
	view_info := vk.ImageViewCreateInfo {
		sType = .IMAGE_VIEW_CREATE_INFO,
		image = image.handle,
		viewType = .D2,
		format = MOIRE_IMAGE_FORMAT,
		subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1},
	}
	if vk.CreateImageView(vk_ctx.device, &view_info, nil, &image.view) != .SUCCESS {
		return false
	}
	image.layout = .UNDEFINED
	return true
}

moire_create_sampled_image :: proc(vk_ctx: ^engine.Vk_Context, image: ^Moire_Image, width, height: u32) -> bool {
	image^ = {layout = .UNDEFINED}
	info := vk.ImageCreateInfo {
		sType = .IMAGE_CREATE_INFO,
		imageType = .D2,
		format = MOIRE_IMAGE_FORMAT,
		extent = {width, height, 1},
		mipLevels = 1,
		arrayLayers = 1,
		samples = {._1},
		tiling = .OPTIMAL,
		usage = {.SAMPLED, .TRANSFER_DST},
		sharingMode = .EXCLUSIVE,
		initialLayout = .UNDEFINED,
	}
	if vk.CreateImage(vk_ctx.device, &info, nil, &image.handle) != .SUCCESS {
		return false
	}
	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device, image.handle, &req)
	memory_type, ok := engine.vk_find_memory_type(vk_ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {
		return false
	}
	alloc := vk.MemoryAllocateInfo{sType = .MEMORY_ALLOCATE_INFO, allocationSize = req.size, memoryTypeIndex = memory_type}
	if vk.AllocateMemory(vk_ctx.device, &alloc, nil, &image.memory) != .SUCCESS {
		return false
	}
	if vk.BindImageMemory(vk_ctx.device, image.handle, image.memory, 0) != .SUCCESS {
		return false
	}
	view_info := vk.ImageViewCreateInfo {
		sType = .IMAGE_VIEW_CREATE_INFO,
		image = image.handle,
		viewType = .D2,
		format = MOIRE_IMAGE_FORMAT,
		subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1},
	}
	return vk.CreateImageView(vk_ctx.device, &view_info, nil, &image.view) == .SUCCESS
}

moire_destroy_image :: proc(vk_ctx: ^engine.Vk_Context, image: ^Moire_Image) {
	if image.view != vk.ImageView(0) {
		vk.DestroyImageView(vk_ctx.device, image.view, nil)
	}
	if image.handle != vk.Image(0) {
		vk.DestroyImage(vk_ctx.device, image.handle, nil)
	}
	if image.memory != vk.DeviceMemory(0) {
		vk.FreeMemory(vk_ctx.device, image.memory, nil)
	}
	image^ = {}
}

moire_frame_slot_mask :: proc() -> u32 {
	return (u32(1) << u32(engine.MAX_FRAMES_IN_FLIGHT)) - 1
}

moire_collect_retired_image_textures :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	bit := u32(1) << u32(frame_slot)
	for i in 0 ..< MOIRE_RETIRED_IMAGE_TEXTURE_CAP {
		retired := &gpu.retired_image_textures[i]
		if retired.pending_frame_slots == 0 {
			continue
		}
		retired.pending_frame_slots = retired.pending_frame_slots & (~bit)
		if retired.pending_frame_slots == 0 {
			moire_destroy_image(vk_ctx, &retired.image)
		}
	}
}

moire_retire_image_texture :: proc(gpu: ^Moire_Gpu_State) -> bool {
	if gpu.image_texture.handle == vk.Image(0) {
		gpu.image_texture = {}
		return true
	}
	for i in 0 ..< MOIRE_RETIRED_IMAGE_TEXTURE_CAP {
		retired := &gpu.retired_image_textures[i]
		if retired.pending_frame_slots == 0 {
			retired.image = gpu.image_texture
			retired.pending_frame_slots = moire_frame_slot_mask()
			gpu.image_texture = {}
			return true
		}
	}
	engine.log_warn("moire: image texture retire slots exhausted")
	return false
}

moire_upload_sampled_image :: proc(vk_ctx: ^engine.Vk_Context, image: ^Moire_Image, width, height: u32, pixels: []u8) -> bool {
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

moire_gpu_load_image_path :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, path: string, settings: ^Moire_Settings) -> bool {
	if !gpu.ready || len(path) == 0 {
		gpu.image_loaded = false
		return false
	}
	img, ok := shared_image_load_rgba8(path)
	if !ok {
		gpu.image_loaded = false
		return false
	}
	defer shared_image_destroy(img)

	target_width := int(max(gpu.width, 1))
	target_height := int(max(gpu.height, 1))
	pixels := make([]u8, int(target_width * target_height * 4))
	defer delete(pixels)
	source := raw_data(img.pixels.buf[:])
	for y := 0; y < target_height; y += 1 {
		for x := 0; x < target_width; x += 1 {
			dst_x := x
			dst_y := y
			src_x, src_y: int
			value := u8(0)
			if vectors_image_source_coord(int(img.width), int(img.height), target_width, target_height, dst_x, dst_y, settings.image_fit_mode, &src_x, &src_y) {
				value = vectors_sample_image_source(source, int(img.width), int(img.height), int(img.width) * 4, src_x, src_y)
			}
			i := (y * target_width + x) * 4
			pixels[i + 0] = value
			pixels[i + 1] = value
			pixels[i + 2] = value
			pixels[i + 3] = 255
		}
	}

	new_texture: Moire_Image
	if !moire_create_sampled_image(vk_ctx, &new_texture, u32(target_width), u32(target_height)) {
		gpu.image_loaded = false
		return false
	}
	if !moire_upload_sampled_image(vk_ctx, &new_texture, u32(target_width), u32(target_height), pixels) {
		moire_destroy_image(vk_ctx, &new_texture)
		gpu.image_loaded = false
		return false
	}
	if !moire_retire_image_texture(gpu) {
		moire_destroy_image(vk_ctx, &new_texture)
		return false
	}
	gpu.image_texture = new_texture
	write_fixed_string(gpu.image_path[:], path)
	gpu.image_fit_uploaded = settings.image_fit_mode
	gpu.image_mirror_horizontal_uploaded = settings.image_mirror_horizontal
	gpu.image_mirror_vertical_uploaded = settings.image_mirror_vertical
	gpu.image_invert_tone_uploaded = settings.image_invert_tone
	gpu.image_width = i32(target_width)
	gpu.image_height = i32(target_height)
	gpu.image_loaded = true
	return true
}

moire_gpu_refresh_image_if_needed :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Moire_Settings) {
	path := fixed_string(settings.image_path[:])
	if len(path) == 0 {
		return
	}
	if gpu.image_loaded &&
	   gpu.image_width == gpu.width &&
	   gpu.image_height == gpu.height &&
	   gpu.image_fit_uploaded == settings.image_fit_mode &&
	   gpu.image_mirror_horizontal_uploaded == settings.image_mirror_horizontal &&
	   gpu.image_mirror_vertical_uploaded == settings.image_mirror_vertical &&
	   gpu.image_invert_tone_uploaded == settings.image_invert_tone &&
	   fixed_string(gpu.image_path[:]) == path {
		return
	}
	_ = moire_gpu_load_image_path(gpu, vk_ctx, path, settings)
}

moire_upload_lut :: proc(gpu: ^Moire_Gpu_State, settings: ^Moire_Settings) -> bool {
	if gpu.lut_buffer.mapped == nil {
		return false
	}
	changed := gpu.lut_uploaded_scheme != settings.color_scheme || gpu.lut_uploaded_reversed != settings.color_scheme_reversed
	if !changed {
		return false
	}
	scheme := color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
	data := (cast([^]u32)gpu.lut_buffer.mapped)[:COLOR_SCHEME_U32_COUNT]
	_ = color_scheme_write_u32_buffer(scheme, data)
	gpu.lut_uploaded_scheme = settings.color_scheme
	gpu.lut_uploaded_reversed = settings.color_scheme_reversed
	return true
}

moire_upload_render_params :: proc(gpu: ^Moire_Gpu_State, frame_slot: int) {
	if gpu.render_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Moire_Render_Params)gpu.render_params_buffers[frame_slot].mapped
	params^ = {filtering_mode = 1}
}

moire_upload_camera :: proc(gpu: ^Moire_Gpu_State, frame_slot: int) {
	if gpu.camera_buffers[frame_slot].mapped == nil {
		return
	}
	camera := cast(^Moire_Camera)gpu.camera_buffers[frame_slot].mapped
	camera^ = {
		transform_matrix = {
			1, 0, 0, 0,
			0, 1, 0, 0,
			0, 0, 1, 0,
			0, 0, 0, 1,
		},
		position = {0, 0},
		zoom = 1,
		aspect_ratio = f32(gpu.width) / f32(max(gpu.height, 1)),
	}
}

moire_create_sampler :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	info := vk.SamplerCreateInfo {
		sType = .SAMPLER_CREATE_INFO,
		magFilter = .LINEAR,
		minFilter = .LINEAR,
		mipmapMode = .LINEAR,
		addressModeU = .REPEAT,
		addressModeV = .REPEAT,
		addressModeW = .REPEAT,
	}
	return vk.CreateSampler(vk_ctx.device, &info, nil, &gpu.sampler) == .SUCCESS
}

moire_create_descriptors :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	compute_bindings := [6]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 4, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 5, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	compute_layout_info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(compute_bindings)), pBindings = raw_data(compute_bindings[:])}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &compute_layout_info, nil, &gpu.compute_set_layout) != .SUCCESS {
		return false
	}
	texture_bindings := [3]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	texture_layout_info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(texture_bindings)), pBindings = raw_data(texture_bindings[:])}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &texture_layout_info, nil, &gpu.texture_set_layout) != .SUCCESS {
		return false
	}
	camera_binding := [1]vk.DescriptorSetLayoutBinding{{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}}}
	camera_layout_info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = 1, pBindings = raw_data(camera_binding[:])}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &camera_layout_info, nil, &gpu.camera_set_layout) != .SUCCESS {
		return false
	}
	pool_sizes := [4]vk.DescriptorPoolSize {
		{type = .STORAGE_IMAGE, descriptorCount = 2 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .SAMPLED_IMAGE, descriptorCount = 8 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .SAMPLER, descriptorCount = 4 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .UNIFORM_BUFFER, descriptorCount = 5 * engine.MAX_FRAMES_IN_FLIGHT},
	}
	pool_info := vk.DescriptorPoolCreateInfo{sType = .DESCRIPTOR_POOL_CREATE_INFO, poolSizeCount = u32(len(pool_sizes)), pPoolSizes = raw_data(pool_sizes[:]), maxSets = 5 * engine.MAX_FRAMES_IN_FLIGHT}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &gpu.descriptor_pool) != .SUCCESS {
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		layouts := [5]vk.DescriptorSetLayout{gpu.compute_set_layout, gpu.compute_set_layout, gpu.texture_set_layout, gpu.texture_set_layout, gpu.camera_set_layout}
		sets: [5]vk.DescriptorSet
		alloc := vk.DescriptorSetAllocateInfo{sType = .DESCRIPTOR_SET_ALLOCATE_INFO, descriptorPool = gpu.descriptor_pool, descriptorSetCount = u32(len(layouts)), pSetLayouts = raw_data(layouts[:])}
		if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(sets[:])) != .SUCCESS {
			return false
		}
		gpu.compute_sets[frame_slot][0] = sets[0]
		gpu.compute_sets[frame_slot][1] = sets[1]
		gpu.texture_sets[frame_slot][0] = sets[2]
		gpu.texture_sets[frame_slot][1] = sets[3]
		gpu.camera_sets[frame_slot] = sets[4]
	}
	moire_update_all_descriptors(gpu, vk_ctx)
	return true
}

moire_update_all_descriptors :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		for write_index in 0 ..< 2 {
			read_index := 1 - write_index
			moire_update_compute_descriptor(gpu, vk_ctx, frame_slot, read_index, write_index)
			moire_update_texture_descriptor(gpu, vk_ctx, frame_slot, write_index)
		}
		moire_update_camera_descriptor(gpu, vk_ctx, frame_slot)
	}
}

moire_update_camera_descriptor :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	camera_info := vk.DescriptorBufferInfo{buffer = gpu.camera_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Moire_Camera))}
	write := vk.WriteDescriptorSet{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.camera_sets[frame_slot], dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &camera_info}
	vk.UpdateDescriptorSets(vk_ctx.device, 1, &write, 0, nil)
}

moire_update_compute_descriptor :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot, read_index, write_index: int) {
	output_info := vk.DescriptorImageInfo{imageLayout = .GENERAL, imageView = gpu.images[write_index].view}
	params_info := vk.DescriptorBufferInfo{buffer = gpu.params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Moire_Params))}
	lut_info := vk.DescriptorBufferInfo{buffer = gpu.lut_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT)}
	prev_info := vk.DescriptorImageInfo{imageLayout = .GENERAL, imageView = gpu.images[read_index].view}
	sampler_info := vk.DescriptorImageInfo{sampler = gpu.sampler}
	image_info := vk.DescriptorImageInfo{imageLayout = .GENERAL, imageView = gpu.images[read_index].view}
	if gpu.image_loaded && gpu.image_texture.view != vk.ImageView(0) {
		image_info = vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.image_texture.view}
	}
	set := gpu.compute_sets[frame_slot][write_index]
	writes := [6]vk.WriteDescriptorSet {
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 0, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, pImageInfo = &output_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &lut_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 3, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &prev_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 4, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 5, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
}

moire_update_texture_descriptor :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot, index: int) {
	image_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.images[index].view}
	sampler_info := vk.DescriptorImageInfo{sampler = gpu.sampler}
	params_info := vk.DescriptorBufferInfo{buffer = gpu.render_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Moire_Render_Params))}
	set := gpu.texture_sets[frame_slot][index]
	writes := [3]vk.WriteDescriptorSet {
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 1, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
}

moire_create_compute_pipeline :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = &gpu.compute_set_layout}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gpu.compute_pipeline.layout) != .SUCCESS {
		return false
	}
	stage := vk.PipelineShaderStageCreateInfo{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.COMPUTE}, module = gpu.compute_shader.handle, pName = MOIRE_COMPUTE_ENTRY}
	info := vk.ComputePipelineCreateInfo{sType = .COMPUTE_PIPELINE_CREATE_INFO, stage = stage, layout = gpu.compute_pipeline.layout}
	return vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &gpu.compute_pipeline.pipeline) == .SUCCESS
}

moire_create_present_pipeline :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	set_layouts := [2]vk.DescriptorSetLayout{gpu.texture_set_layout, gpu.camera_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 2, pSetLayouts = raw_data(set_layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gpu.present_pipeline.layout) != .SUCCESS {
		return false
	}
	stages := [2]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = gpu.present_vertex_shader.handle, pName = MOIRE_PRESENT_VERTEX_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = gpu.present_fragment_shader.handle, pName = MOIRE_PRESENT_FRAGMENT_ENTRY},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState{blendEnable = false, srcColorBlendFactor = .ONE, dstColorBlendFactor = .ZERO, colorBlendOp = .ADD, srcAlphaBlendFactor = .ONE, dstAlphaBlendFactor = .ZERO, alphaBlendOp = .ADD, colorWriteMask = {.R, .G, .B, .A}}
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = 2, pDynamicStates = raw_data(dynamic_states[:])}
	info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = 2,
		pStages = raw_data(stages[:]),
		pVertexInputState = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState = &multisample,
		pColorBlendState = &blend,
		pDynamicState = &dynamic_state,
		layout = gpu.present_pipeline.layout,
		renderPass = vk_ctx.render_pass,
		subpass = 0,
	}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &gpu.present_pipeline.pipeline) == .SUCCESS
}

moire_transition_image :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, index: int, new_layout: vk.ImageLayout, cmd: vk.CommandBuffer) {
	old_layout := gpu.images[index].layout
	if old_layout == new_layout {
		return
	}
	src_access: vk.AccessFlags
	dst_access: vk.AccessFlags
	src_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	dst_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	#partial switch old_layout {
	case .UNDEFINED:
		#partial switch new_layout {
		case .GENERAL:
			dst_access = {.SHADER_READ, .SHADER_WRITE}
			dst_stage = {.COMPUTE_SHADER}
		case .SHADER_READ_ONLY_OPTIMAL:
			dst_access = {.SHADER_READ}
			dst_stage = {.FRAGMENT_SHADER}
		}
	case .GENERAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.SHADER_WRITE}
			dst_access = {.SHADER_READ}
			src_stage = {.COMPUTE_SHADER}
			dst_stage = {.FRAGMENT_SHADER}
		}
	case .SHADER_READ_ONLY_OPTIMAL:
		#partial switch new_layout {
		case .GENERAL:
			src_access = {.SHADER_READ}
			dst_access = {.SHADER_READ, .SHADER_WRITE}
			src_stage = {.FRAGMENT_SHADER}
			dst_stage = {.COMPUTE_SHADER}
		}
	}
	barrier := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = src_access,
		dstAccessMask = dst_access,
		oldLayout = old_layout,
		newLayout = new_layout,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = gpu.images[index].handle,
		subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1},
	}
	vk.CmdPipelineBarrier(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	gpu.images[index].layout = new_layout
}

moire_write_params :: proc(gpu: ^Moire_Gpu_State, frame_slot: int, settings: ^Moire_Settings, time: f32) {
	if gpu.params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Moire_Params)gpu.params_buffers[frame_slot].mapped
	params^ = {
		time = time,
		width = f32(gpu.width),
		height = f32(gpu.height),
		generator_type = f32(settings.generator_index),
		base_freq = settings.base_freq,
		moire_amount = settings.moire_amount,
		moire_rotation = settings.moire_rotation,
		moire_scale = settings.moire_scale,
		moire_interference = settings.moire_interference,
		moire_rotation3 = settings.moire_rotation3,
		moire_scale3 = settings.moire_scale3,
		moire_weight3 = settings.moire_weight3,
		radial_swirl_strength = settings.radial_swirl_strength,
		radial_starburst_count = settings.radial_starburst_count,
		radial_center_brightness = settings.radial_center_brightness,
		color_scheme_reversed = settings.color_scheme_reversed ? f32(1) : f32(0),
		advect_strength = settings.advect_strength,
		advect_speed = settings.advect_speed,
		curl = settings.curl,
		decay = settings.decay,
		image_loaded = gpu.image_loaded ? f32(1) : f32(0),
		image_mode_enabled = settings.image_mode_enabled ? f32(1) : f32(0),
		image_interference_mode = f32(settings.interference_index),
		image_mirror_horizontal = settings.image_mirror_horizontal ? f32(1) : f32(0),
		image_mirror_vertical = settings.image_mirror_vertical ? f32(1) : f32(0),
		image_invert_tone = settings.image_invert_tone ? f32(1) : f32(0),
	}
}

moire_gpu_step :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, settings: ^Moire_Settings, time: f32, width, height: i32, paused: bool) {
	if !moire_gpu_ensure(gpu, vk_ctx, width, height) {
		return
	}
	frame_slot := int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	lut_changed := moire_upload_lut(gpu, settings)
	moire_write_params(gpu, frame_slot, settings, time)
	read_index := int(gpu.state_index)
	write_index := 1 - read_index
	if paused && !lut_changed {
		moire_update_compute_descriptor(gpu, vk_ctx, frame_slot, read_index, write_index)
		moire_collect_retired_image_textures(gpu, vk_ctx, frame_slot)
		return
	}
	moire_transition_image(gpu, vk_ctx, read_index, .GENERAL, cmd)
	moire_transition_image(gpu, vk_ctx, write_index, .GENERAL, cmd)
	moire_update_compute_descriptor(gpu, vk_ctx, frame_slot, read_index, write_index)
	moire_collect_retired_image_textures(gpu, vk_ctx, frame_slot)
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.compute_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	compute_set := gpu.compute_sets[frame_slot][write_index]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.compute_pipeline.layout, 0, 1, &compute_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := (u32(gpu.width) + MOIRE_WORKGROUP_SIZE - 1) / MOIRE_WORKGROUP_SIZE
	group_y := (u32(gpu.height) + MOIRE_WORKGROUP_SIZE - 1) / MOIRE_WORKGROUP_SIZE
	vk.CmdDispatch(cmd, group_x, group_y, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	barrier := vk.MemoryBarrier{sType = .MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.SHADER_READ, .SHADER_WRITE}}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.COMPUTE_SHADER, .FRAGMENT_SHADER}, {}, 1, &barrier, 0, nil, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	gpu.state_index = u32(write_index)
}

moire_gpu_present :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame) {
	viewport := vk.Viewport{x = 0, y = 0, width = f32(vk_ctx.swapchain_extent.width), height = f32(vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = vk_ctx.swapchain_extent}
	moire_gpu_present_viewport(gpu, vk_ctx, frame, viewport, scissor)
}

moire_gpu_present_viewport :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gpu.ready || gpu.present_pipeline.pipeline == vk.Pipeline(0) {
		return
	}
	frame_slot := int(frame.frame_index)
	index := int(gpu.state_index)
	moire_transition_image(gpu, vk_ctx, index, .SHADER_READ_ONLY_OPTIMAL, frame.command_buffer)
	moire_update_texture_descriptor(gpu, vk_ctx, frame_slot, index)
	moire_upload_camera(gpu, frame_slot)
	moire_gpu_draw_prepared_viewport(gpu, vk_ctx, frame, viewport, scissor)
}

moire_gpu_draw_prepared_viewport :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gpu.ready || gpu.present_pipeline.pipeline == vk.Pipeline(0) {
		return
	}
	frame_slot := int(frame.frame_index)
	index := int(gpu.state_index)
	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(frame.command_buffer, 0, 1, &local_viewport)
	vk.CmdSetScissor(frame.command_buffer, 0, 1, &local_scissor)
	vk.CmdBindPipeline(frame.command_buffer, .GRAPHICS, gpu.present_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	texture_set := gpu.texture_sets[frame_slot][index]
	camera_set := gpu.camera_sets[frame_slot]
	vk.CmdBindDescriptorSets(frame.command_buffer, .GRAPHICS, gpu.present_pipeline.layout, 0, 1, &texture_set, 0, nil)
	vk.CmdBindDescriptorSets(frame.command_buffer, .GRAPHICS, gpu.present_pipeline.layout, 1, 1, &camera_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDraw(frame.command_buffer, 6, 25, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
}

moire_gpu_destroy :: proc(gpu: ^Moire_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	if vk_ctx == nil || vk_ctx.device == nil {
		gpu^ = {}
		return
	}
	if gpu.compute_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, gpu.compute_pipeline.pipeline, nil)
	}
	if gpu.compute_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, gpu.compute_pipeline.layout, nil)
	}
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.present_pipeline)
	if gpu.descriptor_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, gpu.descriptor_pool, nil)
	}
	if gpu.compute_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.compute_set_layout, nil)
	}
	if gpu.texture_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.texture_set_layout, nil)
	}
		if gpu.camera_set_layout != vk.DescriptorSetLayout(0) {
			vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.camera_set_layout, nil)
		}
		if gpu.sampler != vk.Sampler(0) {
			vk.DestroySampler(vk_ctx.device, gpu.sampler, nil)
		}
		moire_destroy_image(vk_ctx, &gpu.image_texture)
		for i in 0 ..< MOIRE_RETIRED_IMAGE_TEXTURE_CAP {
			moire_destroy_image(vk_ctx, &gpu.retired_image_textures[i].image)
		}
		for i in 0 ..< 2 {
			moire_destroy_image(vk_ctx, &gpu.images[i])
		}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		engine.vk_destroy_buffer(vk_ctx, &gpu.params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.render_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.camera_buffers[frame_slot])
	}
	engine.vk_destroy_buffer(vk_ctx, &gpu.lut_buffer)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.compute_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.present_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.present_fragment_shader)
	gpu^ = {}
}
