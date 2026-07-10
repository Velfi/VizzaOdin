package render_vk

import uifw "../ui"
import engine "../engine"

import vk "vendor:vulkan"
import "core:c"
import "core:fmt"
import "core:math"
import "core:os"
import sdl "vendor:sdl3"

gray_scott_render :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) {
	_ = sim
	_ = vk_ctx
}

gray_scott_get_step_shader_spv_path :: proc() -> string {
	return engine.shader_spirv_path(
		GRAY_SCOTT_STEP_SHADER_SOURCE,
		.Compute,
		GRAY_SCOTT_STEP_ENTRY,
		GRAY_SCOTT_STEP_FALLBACK_SPV + ".spv",
	)
}

gray_scott_get_present_shader_spv_path :: proc() -> string {
	return engine.shader_spirv_path(
		GRAY_SCOTT_PRESENT_SHADER_SOURCE,
		.Fragment,
		GRAY_SCOTT_PRESENT_ENTRY,
		GRAY_SCOTT_PRESENT_FALLBACK_SPV + ".spv",
	)
}

gray_scott_get_vertex_shader_spv_path :: proc() -> string {
	return engine.shader_spirv_path(
		GRAY_SCOTT_VERTEX_SHADER_SOURCE,
		.Vertex,
		GRAY_SCOTT_VERTEX_ENTRY,
		GRAY_SCOTT_VERTEX_FALLBACK_SPV + ".spv",
	)
}

gray_scott_ensure_gpu_paths :: proc(sim: ^Gray_Scott_Simulation) -> bool {
	step_path := gray_scott_get_step_shader_spv_path()
	vertex_path := gray_scott_get_vertex_shader_spv_path()
	present_path := gray_scott_get_present_shader_spv_path()
	if len(step_path) == 0 || len(vertex_path) == 0 || len(present_path) == 0 {
		return false
	}
	if !os.exists(step_path) || !os.exists(vertex_path) || !os.exists(present_path) {
		return false
	}
	sim.gpu.step_shader_spirv_path = step_path
	sim.gpu.vertex_shader_spirv_path = vertex_path
	sim.gpu.present_shader_spirv_path = present_path
	return true
}

gray_scott_ensure_gpu_runtime :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if sim.gpu.ready {
		return true
	}

	if sim.gpu.step_shader_module.handle != 0 || sim.gpu.present_shader_module.handle != 0 {
		gray_scott_destroy(sim, vk_ctx)
	}
	if !gray_scott_ensure_gpu_paths(sim) {
		return false
	}

	step_module := engine.Vk_Shader_Module{}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.step_shader_spirv_path, &step_module) {
		return false
	}
	present_module := engine.Vk_Shader_Module{}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.present_shader_spirv_path, &present_module) {
		engine.vk_destroy_shader_module(vk_ctx, &step_module)
		return false
	}
	vertex_module := engine.Vk_Shader_Module{}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.vertex_shader_spirv_path, &vertex_module) {
		engine.vk_destroy_shader_module(vk_ctx, &step_module)
		engine.vk_destroy_shader_module(vk_ctx, &present_module)
		return false
	}

	sim.gpu.step_shader_module = step_module
	sim.gpu.present_shader_module = present_module
	sim.gpu.vertex_shader_module = vertex_module

	if !gray_scott_create_render_state(sim, vk_ctx) {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	sim.gpu.ready = true
	return true
}

gray_scott_create_render_state :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if !gray_scott_create_compute_resources(sim, vk_ctx) {
		return false
	}
	if !gray_scott_create_present_resources(sim, vk_ctx) {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}
	return true
}

gray_scott_create_image_resource :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, index: int) -> bool {
	width := cast(int)max(sim.gpu.width, 1)
	height := cast(int)max(sim.gpu.height, 1)
	if width <= 0 || height <= 0 {
		return false
	}

	image_info := vk.ImageCreateInfo {
		sType = .IMAGE_CREATE_INFO,
		imageType = .D2,
		format = GRAY_SCOTT_IMAGE_FORMAT,
		extent = {width = u32(width), height = u32(height), depth = 1},
		mipLevels = 1,
		arrayLayers = 1,
		samples = {._1},
		tiling = .OPTIMAL,
		usage = {.STORAGE, .SAMPLED},
		sharingMode = .EXCLUSIVE,
		initialLayout = .UNDEFINED,
	}
	if vk.CreateImage(vk_ctx.device, &image_info, nil, &sim.gpu.storage[index].handle) != .SUCCESS {
		return false
	}

	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device, sim.gpu.storage[index].handle, &req)
	memory_type, ok := engine.vk_find_memory_type(vk_ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {
		vk.DestroyImage(vk_ctx.device, sim.gpu.storage[index].handle, nil)
		sim.gpu.storage[index].handle = vk.Image(0)
		return false
	}

	alloc_info := vk.MemoryAllocateInfo {
		sType = .MEMORY_ALLOCATE_INFO,
		allocationSize = req.size,
		memoryTypeIndex = memory_type,
	}
	if vk.AllocateMemory(vk_ctx.device, &alloc_info, nil, &sim.gpu.storage[index].memory) != .SUCCESS {
		vk.DestroyImage(vk_ctx.device, sim.gpu.storage[index].handle, nil)
		sim.gpu.storage[index].handle = vk.Image(0)
		return false
	}
	if vk.BindImageMemory(vk_ctx.device, sim.gpu.storage[index].handle, sim.gpu.storage[index].memory, 0) != .SUCCESS {
		vk.FreeMemory(vk_ctx.device, sim.gpu.storage[index].memory, nil)
		vk.DestroyImage(vk_ctx.device, sim.gpu.storage[index].handle, nil)
		sim.gpu.storage[index] = {}
		return false
	}

	view_info := vk.ImageViewCreateInfo {
		sType = .IMAGE_VIEW_CREATE_INFO,
		image = sim.gpu.storage[index].handle,
		viewType = .D2,
		format = GRAY_SCOTT_IMAGE_FORMAT,
		components = {r = .IDENTITY, g = .IDENTITY, b = .IDENTITY, a = .IDENTITY},
		subresourceRange = {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
		},
	}
	if vk.CreateImageView(vk_ctx.device, &view_info, nil, &sim.gpu.storage[index].view) != .SUCCESS {
		vk.FreeMemory(vk_ctx.device, sim.gpu.storage[index].memory, nil)
		vk.DestroyImage(vk_ctx.device, sim.gpu.storage[index].handle, nil)
		sim.gpu.storage[index] = {}
		return false
	}

	sim.gpu.storage[index].layout = .UNDEFINED
	return true
}

gray_scott_upload_lut :: proc(sim: ^Gray_Scott_Simulation) {
	if sim.gpu.lut_buffer.mapped == nil {
		return
	}
	name := color_scheme_name_get(&sim.settings.color_scheme)
	scheme, ok := color_scheme_load(name)
	if !ok {
		scheme = color_scheme_default()
	}
	if sim.settings.color_scheme_reversed {
		color_scheme_reverse(&scheme)
	}
	out := cast([^]u32)sim.gpu.lut_buffer.mapped
	_ = color_scheme_write_u32_buffer(scheme, out[:GRAY_SCOTT_LUT_SIZE])
	sim.gpu.lut_uploaded_scheme = sim.settings.color_scheme
	sim.gpu.lut_uploaded_reversed = sim.settings.color_scheme_reversed
}

gray_scott_upload_present_params :: proc(sim: ^Gray_Scott_Simulation, frame_slot: u32) {
	slot := min(frame_slot, u32(engine.MAX_FRAMES_IN_FLIGHT - 1))
	present_params_buffer := &sim.gpu.present_params_buffers[slot]
	if present_params_buffer.mapped == nil {
		return
	}
	params := cast(^Gray_Scott_Present_Params)present_params_buffer.mapped
	params^ = {
		lut_reversed = sim.settings.color_scheme_reversed ? 1 : 0,
		blur_enabled = sim.settings.blur_enabled ? 1 : 0,
		blur_radius = sim.settings.blur_radius,
		blur_sigma = sim.settings.blur_sigma,
		width = u32(max(sim.gpu.width, 1)),
		height = u32(max(sim.gpu.height, 1)),
		viewport_width = u32(max(sim.gpu.width, 1)),
		viewport_height = u32(max(sim.gpu.height, 1)),
		camera_x = sim.runtime.camera_x,
		camera_y = sim.runtime.camera_y,
		camera_zoom = max(sim.runtime.camera_zoom, 0.05),
		view_mode = u32(sim.settings.view_mode),
	}
}

gray_scott_upload_camera :: proc(sim: ^Gray_Scott_Simulation, frame_slot: u32) {
	slot := min(frame_slot, u32(engine.MAX_FRAMES_IN_FLIGHT - 1))
	camera_buffer := &sim.gpu.camera_buffers[slot]
	if camera_buffer.mapped == nil {
		return
	}
	zoom := max(sim.runtime.camera_zoom, CAMERA_MIN_ZOOM)
	aspect := f32(max(sim.gpu.width, 1)) / f32(max(sim.gpu.height, 1))
	camera := cast(^Gray_Scott_Camera)camera_buffer.mapped
	camera^ = {
		transform_matrix = {
			zoom, 0, 0, 0,
			0, zoom, 0, 0,
			0, 0, 1, 0,
			-sim.runtime.camera_x * zoom, -sim.runtime.camera_y * zoom, 0, 1,
		},
		position = {sim.runtime.camera_x, sim.runtime.camera_y},
		zoom = zoom,
		aspect_ratio = aspect,
	}
}

gray_scott_sync_present_resources :: proc(sim: ^Gray_Scott_Simulation) {
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		gray_scott_sync_present_resources_for_slot(sim, u32(i))
	}
}

gray_scott_sync_present_resources_for_slot :: proc(sim: ^Gray_Scott_Simulation, frame_slot: u32) {
	if sim.gpu.lut_uploaded_scheme != sim.settings.color_scheme || sim.gpu.lut_uploaded_reversed != sim.settings.color_scheme_reversed {
		gray_scott_upload_lut(sim)
	}
	gray_scott_upload_present_params(sim, frame_slot)
	gray_scott_upload_camera(sim, frame_slot)
}

gray_scott_load_nutrient_image :: proc(sim: ^Gray_Scott_Simulation) -> bool {
	if sim.gpu.nutrient_buffer.mapped == nil {
		sim.runtime.nutrient_image_loaded = false
		return false
	}
	path := fixed_string(sim.settings.nutrient_image_path[:])
	if len(path) == 0 || !os.exists(path) {
		sim.runtime.nutrient_image_loaded = false
		return false
	}
	img, ok := shared_image_load_rgba8(path)
	if !ok {
		sim.runtime.nutrient_image_loaded = false
		return false
	}
	defer shared_image_destroy(img)

	target_width := int(max(sim.gpu.width, 1))
	target_height := int(max(sim.gpu.height, 1))
	values := cast([^]f32)sim.gpu.nutrient_buffer.mapped
	source := raw_data(img.pixels.buf[:])
	for y := 0; y < target_height; y += 1 {
		for x := 0; x < target_width; x += 1 {
			values[y * target_width + x] = gray_scott_nutrient_image_value(source, int(img.width), int(img.height), int(img.width) * 4, target_width, target_height, x, y, sim.settings.nutrient_image_fit_mode)
		}
	}
	sim.runtime.nutrient_image_loaded = true
	return true
}

gray_scott_update_webcam_nutrient_map :: proc(sim: ^Gray_Scott_Simulation) -> bool {
	if !sim.runtime.webcam_active || sim.runtime.webcam == nil || sim.gpu.nutrient_buffer.mapped == nil {
		return false
	}
	permission := sdl.GetCameraPermissionState(sim.runtime.webcam)
	if permission == .DENIED {
		sim.runtime.webcam_permission_denied = true
		gray_scott_stop_webcam(sim)
		return false
	}
	if permission == .PENDING {
		return false
	}

	timestamp: sdl.Uint64
	frame := sdl.AcquireCameraFrame(sim.runtime.webcam, &timestamp)
	if frame == nil {
		return false
	}
	defer sdl.ReleaseCameraFrame(sim.runtime.webcam, frame)

	converted := sdl.ConvertSurface(frame, .RGBA32)
	if converted == nil || converted.pixels == nil || converted.w <= 0 || converted.h <= 0 {
		return false
	}
	defer sdl.DestroySurface(converted)

	locked := false
	if sdl.MUSTLOCK(converted) {
		if !sdl.LockSurface(converted) {
			return false
		}
		locked = true
	}
	defer if locked {
		sdl.UnlockSurface(converted)
	}

	target_width := int(max(sim.gpu.width, 1))
	target_height := int(max(sim.gpu.height, 1))
	values := cast([^]f32)sim.gpu.nutrient_buffer.mapped
	source := cast([^]u8)converted.pixels
	for y := 0; y < target_height; y += 1 {
		for x := 0; x < target_width; x += 1 {
			values[y * target_width + x] = gray_scott_nutrient_image_value(source, int(converted.w), int(converted.h), int(converted.pitch), target_width, target_height, x, y, sim.settings.nutrient_image_fit_mode)
		}
	}
	sim.runtime.nutrient_image_loaded = true
	sim.runtime.webcam_frames += 1
	return true
}

gray_scott_upload_nutrient_map :: proc(sim: ^Gray_Scott_Simulation) {
	sim.runtime.nutrient_upload_pending = false
	if sim.gpu.nutrient_buffer.mapped == nil {
		return
	}
	if gray_scott_load_nutrient_image(sim) {
		return
	}
	width := int(max(sim.gpu.width, 1))
	height := int(max(sim.gpu.height, 1))
	values := cast([^]f32)sim.gpu.nutrient_buffer.mapped
	seed := sim.runtime.seed
	for y := 0; y < height; y += 1 {
		ny := f32(y) / f32(max(height - 1, 1))
		for x := 0; x < width; x += 1 {
			nx := f32(x) / f32(max(width - 1, 1))
			dx := nx - 0.5
			dy := ny - 0.5
			radial := max(1.0 - (dx * dx + dy * dy) * 2.4, 0.0)
			diagonal := (nx + ny) * 0.5
			coarse := gray_scott_hash01(u32(x / 16), u32(y / 16), seed)
			fine := gray_scott_hash01(u32(x / 5), u32(y / 5), seed + 17)
			value := radial * 0.45 + diagonal * 0.35 + coarse * 0.15 + fine * 0.05
			values[y * width + x] = max(min(value, 1.0), 0.0)
		}
	}
}

gray_scott_create_compute_resources :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	for i := 0; i < 2; i += 1 {
		if !gray_scott_create_image_resource(sim, vk_ctx, i) {
			for j := 0; j < i; j += 1 {
				if sim.gpu.storage[j].view != vk.ImageView(0) {
					vk.DestroyImageView(vk_ctx.device, sim.gpu.storage[j].view, nil)
				}
				if sim.gpu.storage[j].handle != vk.Image(0) {
					vk.DestroyImage(vk_ctx.device, sim.gpu.storage[j].handle, nil)
				}
				if sim.gpu.storage[j].memory != vk.DeviceMemory(0) {
					vk.FreeMemory(vk_ctx.device, sim.gpu.storage[j].memory, nil)
				}
				sim.gpu.storage[j] = {}
			}
			return false
		}
	}

	buffer_size := vk.DeviceSize(size_of(Gray_Scott_Params))
	for i := 0; i < len(sim.gpu.params_buffers); i += 1 {
		if !engine.vk_create_host_buffer(vk_ctx, buffer_size, {.UNIFORM_BUFFER}, &sim.gpu.params_buffers[i]) {
			gray_scott_destroy(sim, vk_ctx)
			return false
		}
	}

	nutrient_size := vk.DeviceSize(size_of(f32) * max(sim.gpu.width, 1) * max(sim.gpu.height, 1))
	if !engine.vk_create_host_buffer(vk_ctx, nutrient_size, {.STORAGE_BUFFER}, &sim.gpu.nutrient_buffer) {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}
	gray_scott_upload_nutrient_map(sim)

	compute_set_bindings := [4]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	compute_set_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(compute_set_bindings)),
		pBindings = raw_data(compute_set_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &compute_set_layout_info, nil, &sim.gpu.compute_set_layout) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	pool_sizes := [3]vk.DescriptorPoolSize {
		{type = .STORAGE_IMAGE, descriptorCount = u32(GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS * 2)},
		{type = .UNIFORM_BUFFER, descriptorCount = u32(GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS)},
		{type = .STORAGE_BUFFER, descriptorCount = u32(GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS)},
	}
	compute_pool_info := vk.DescriptorPoolCreateInfo {
		sType = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = u32(len(pool_sizes)),
		pPoolSizes = raw_data(pool_sizes[:]),
		maxSets = u32(GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS),
	}
	if vk.CreateDescriptorPool(vk_ctx.device, &compute_pool_info, nil, &sim.gpu.compute_pool) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	compute_set_layouts: [GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS]vk.DescriptorSetLayout
	for i := 0; i < len(compute_set_layouts); i += 1 {
		compute_set_layouts[i] = sim.gpu.compute_set_layout
	}
	set_alloc := vk.DescriptorSetAllocateInfo {
		sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool = sim.gpu.compute_pool,
		descriptorSetCount = u32(len(sim.gpu.compute_sets)),
		pSetLayouts = raw_data(compute_set_layouts[:]),
	}
	if vk.AllocateDescriptorSets(vk_ctx.device, &set_alloc, raw_data(sim.gpu.compute_sets[:])) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	compute_layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = &sim.gpu.compute_set_layout,
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &compute_layout_info, nil, &sim.gpu.compute_pipeline.layout) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	compute_stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.COMPUTE},
		module = sim.gpu.step_shader_module.handle,
		pName = GRAY_SCOTT_STEP_SPIRV_ENTRY,
	}
	compute_pipeline_info := vk.ComputePipelineCreateInfo {
		sType = .COMPUTE_PIPELINE_CREATE_INFO,
		stage = compute_stage,
		layout = sim.gpu.compute_pipeline.layout,
	}
	if vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &compute_pipeline_info, nil, &sim.gpu.compute_pipeline.pipeline) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	return true
}

gray_scott_create_fullscreen_vertex_buffer :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	buffer_size := vk.DeviceSize(size_of(Gray_Scott_Fullscreen_Vertex) * 6)
	if !engine.vk_create_host_buffer(vk_ctx, buffer_size, {.VERTEX_BUFFER}, &sim.gpu.fullscreen_vertices) {
		return false
	}

	white := uifw.Color{1, 1, 1, 1}
	zero := uifw.Color{0, 0, 0, 0}
	verts := cast([^]Gray_Scott_Fullscreen_Vertex)sim.gpu.fullscreen_vertices.mapped
	verts[0] = {pos = {-1, -1}, color = white, uv = {0, 1}, glyph = 0, effect = zero}
	verts[1] = {pos = { 1, -1}, color = white, uv = {1, 1}, glyph = 0, effect = zero}
	verts[2] = {pos = {-1,  1}, color = white, uv = {0, 0}, glyph = 0, effect = zero}
	verts[3] = {pos = {-1,  1}, color = white, uv = {0, 0}, glyph = 0, effect = zero}
	verts[4] = {pos = { 1, -1}, color = white, uv = {1, 1}, glyph = 0, effect = zero}
	verts[5] = {pos = { 1,  1}, color = white, uv = {1, 0}, glyph = 0, effect = zero}
	return true
}

gray_scott_create_present_resources :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	lut_size := vk.DeviceSize(size_of(u32) * GRAY_SCOTT_LUT_SIZE)
	if !engine.vk_create_host_buffer(vk_ctx, lut_size, {.STORAGE_BUFFER}, &sim.gpu.lut_buffer) {
		return false
	}
	present_params_size := vk.DeviceSize(size_of(Gray_Scott_Present_Params))
	camera_size := vk.DeviceSize(size_of(Gray_Scott_Camera))
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, present_params_size, {.UNIFORM_BUFFER}, &sim.gpu.present_params_buffers[i]) {
			gray_scott_destroy(sim, vk_ctx)
			return false
		}
		if !engine.vk_create_host_buffer(vk_ctx, camera_size, {.UNIFORM_BUFFER}, &sim.gpu.camera_buffers[i]) {
			gray_scott_destroy(sim, vk_ctx)
			return false
		}
	}
	gray_scott_upload_lut(sim)
	gray_scott_sync_present_resources(sim)

	sampler_info := vk.SamplerCreateInfo {sType = .SAMPLER_CREATE_INFO}
	sampler_info.magFilter = .LINEAR
	sampler_info.minFilter = .LINEAR
	sampler_info.mipmapMode = .LINEAR
	sampler_info.addressModeU = .REPEAT
	sampler_info.addressModeV = .REPEAT
	sampler_info.addressModeW = .REPEAT
	sampler_info.minLod = 0
	sampler_info.maxLod = 1
	sampler_info.unnormalizedCoordinates = false
	sampler_info.anisotropyEnable = false
	sampler_info.maxAnisotropy = 1
	sampler_info.compareEnable = false
	sampler_info.compareOp = .ALWAYS
	if vk.CreateSampler(vk_ctx.device, &sampler_info, nil, &sim.gpu.sampler) != .SUCCESS {
		return false
	}

	present_set_bindings := [5]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 4, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}},
	}
	present_set_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(present_set_bindings)),
		pBindings = raw_data(present_set_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &present_set_layout_info, nil, &sim.gpu.present_set_layout) != .SUCCESS {
		vk.DestroySampler(vk_ctx.device, sim.gpu.sampler, nil)
		sim.gpu.sampler = vk.Sampler(0)
		return false
	}

	present_pool_sizes := [4]vk.DescriptorPoolSize {
		{
			type = .SAMPLER,
			descriptorCount = engine.MAX_FRAMES_IN_FLIGHT,
		},
		{
			type = .SAMPLED_IMAGE,
			descriptorCount = engine.MAX_FRAMES_IN_FLIGHT,
		},
		{
			type = .STORAGE_BUFFER,
			descriptorCount = engine.MAX_FRAMES_IN_FLIGHT,
		},
		{
			type = .UNIFORM_BUFFER,
			descriptorCount = engine.MAX_FRAMES_IN_FLIGHT * 2,
		},
	}
	present_pool_info := vk.DescriptorPoolCreateInfo {
		sType = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = u32(len(present_pool_sizes)),
		pPoolSizes = raw_data(present_pool_sizes[:]),
		maxSets = engine.MAX_FRAMES_IN_FLIGHT,
	}
	if vk.CreateDescriptorPool(vk_ctx.device, &present_pool_info, nil, &sim.gpu.present_pool) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	present_layouts: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSetLayout
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		present_layouts[i] = sim.gpu.present_set_layout
	}
	present_set_alloc := vk.DescriptorSetAllocateInfo {
		sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool = sim.gpu.present_pool,
		descriptorSetCount = u32(len(present_layouts)),
		pSetLayouts = raw_data(present_layouts[:]),
	}
	if vk.AllocateDescriptorSets(vk_ctx.device, &present_set_alloc, raw_data(sim.gpu.present_sets[:])) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !gray_scott_update_present_descriptor(sim, vk_ctx, 0, u32(i)) {
			gray_scott_destroy(sim, vk_ctx)
			return false
		}
	}

	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = &sim.gpu.present_set_layout,
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &sim.gpu.present_pipeline.layout) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	vertex_stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.VERTEX},
		module = sim.gpu.vertex_shader_module.handle,
		pName = GRAY_SCOTT_VERTEX_SPIRV_ENTRY,
	}
	fragment_stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.FRAGMENT},
		module = sim.gpu.present_shader_module.handle,
		pName = GRAY_SCOTT_PRESENT_SPIRV_ENTRY,
	}
	stages := [?]vk.PipelineShaderStageCreateInfo {vertex_stage, fragment_stage}

	vertex_input := vk.PipelineVertexInputStateCreateInfo {
		sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount = 0,
		pVertexBindingDescriptions = nil,
		vertexAttributeDescriptionCount = 0,
		pVertexAttributeDescriptions = nil,
	}
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
		blendEnable = false,
		srcColorBlendFactor = .ONE,
		dstColorBlendFactor = .ZERO,
		colorBlendOp = .ADD,
		srcAlphaBlendFactor = .ONE,
		dstAlphaBlendFactor = .ZERO,
		alphaBlendOp = .ADD,
		colorWriteMask = {.R, .G, .B, .A},
	}
	blend := vk.PipelineColorBlendStateCreateInfo {
		sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		attachmentCount = 1,
		pAttachments = &blend_attachment,
	}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state_info := vk.PipelineDynamicStateCreateInfo {
		sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = u32(len(dynamic_states)),
		pDynamicStates = raw_data(dynamic_states[:]),
	}
	present_info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = u32(len(stages)),
		pStages = raw_data(stages[:]),
		pVertexInputState = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState = &multisample,
		pColorBlendState = &blend,
		pDynamicState = &dynamic_state_info,
		layout = sim.gpu.present_pipeline.layout,
		renderPass = vk_ctx.render_pass,
		subpass = 0,
	}
	present_result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &present_info, nil, &sim.gpu.present_pipeline.pipeline)
	if present_result != .SUCCESS {
		engine.log_error("gray_scott_create_present_resources: CreateGraphicsPipelines failed result=", present_result)
		gray_scott_destroy(sim, vk_ctx)
		return false
	}
	return true
}

gray_scott_update_compute_descriptors :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, read_index: int, write_index: int, dispatch_slot: int) -> bool {
	if read_index < 0 || read_index >= 2 || write_index < 0 || write_index >= 2 || dispatch_slot < 0 || dispatch_slot >= len(sim.gpu.compute_sets) {
		return false
	}
	if sim.gpu.compute_sets[dispatch_slot] == vk.DescriptorSet(0) {
		return false
	}

	storage_info := vk.DescriptorImageInfo {
		imageLayout = .GENERAL,
		imageView = sim.gpu.storage[write_index].view,
	}
	sample_info := vk.DescriptorImageInfo {
		imageLayout = .GENERAL,
		imageView = sim.gpu.storage[read_index].view,
	}
	buffer_info := vk.DescriptorBufferInfo {
		buffer = sim.gpu.params_buffers[dispatch_slot].handle,
		offset = 0,
		range = vk.DeviceSize(size_of(Gray_Scott_Params)),
	}
	nutrient_info := vk.DescriptorBufferInfo {
		buffer = sim.gpu.nutrient_buffer.handle,
		offset = 0,
		range = vk.DeviceSize(size_of(f32) * max(sim.gpu.width, 1) * max(sim.gpu.height, 1)),
	}
	writes := [4]vk.WriteDescriptorSet {
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = sim.gpu.compute_sets[dispatch_slot],
			dstBinding = 0,
			descriptorType = .STORAGE_IMAGE,
			descriptorCount = 1,
			pImageInfo = &storage_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = sim.gpu.compute_sets[dispatch_slot],
			dstBinding = 1,
			descriptorType = .STORAGE_IMAGE,
			descriptorCount = 1,
			pImageInfo = &sample_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = sim.gpu.compute_sets[dispatch_slot],
			dstBinding = 2,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &buffer_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = sim.gpu.compute_sets[dispatch_slot],
			dstBinding = 3,
			descriptorType = .STORAGE_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &nutrient_info,
		},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
	return true
}

gray_scott_update_present_descriptor :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, read_index: int, frame_slot: u32) -> bool {
	slot := min(frame_slot, u32(engine.MAX_FRAMES_IN_FLIGHT - 1))
	present_set := sim.gpu.present_sets[slot]
	if present_set == vk.DescriptorSet(0) {
		return false
	}
	if read_index < 0 || read_index >= 2 {
		return false
	}
	image_info := vk.DescriptorImageInfo {
		imageLayout = .SHADER_READ_ONLY_OPTIMAL,
		imageView = sim.gpu.storage[read_index].view,
	}
	sampler_info := vk.DescriptorImageInfo {
		sampler = sim.gpu.sampler,
	}
	lut_info := vk.DescriptorBufferInfo {
		buffer = sim.gpu.lut_buffer.handle,
		offset = 0,
		range = vk.DeviceSize(size_of(u32) * GRAY_SCOTT_LUT_SIZE),
	}
	present_params_info := vk.DescriptorBufferInfo {
		buffer = sim.gpu.present_params_buffers[slot].handle,
		offset = 0,
		range = vk.DeviceSize(size_of(Gray_Scott_Present_Params)),
	}
	camera_info := vk.DescriptorBufferInfo {
		buffer = sim.gpu.camera_buffers[slot].handle,
		offset = 0,
		range = vk.DeviceSize(size_of(Gray_Scott_Camera)),
	}
	writes := [5]vk.WriteDescriptorSet {
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = present_set,
			dstBinding = 0,
			descriptorType = .SAMPLED_IMAGE,
			descriptorCount = 1,
			pImageInfo = &image_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = present_set,
			dstBinding = 1,
			descriptorType = .SAMPLER,
			descriptorCount = 1,
			pImageInfo = &sampler_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = present_set,
			dstBinding = 2,
			descriptorType = .STORAGE_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &lut_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = present_set,
			dstBinding = 3,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &present_params_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = present_set,
			dstBinding = 4,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &camera_info,
		},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
	return true
}

gray_scott_transition_image :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, index: int, old_layout: vk.ImageLayout, new_layout: vk.ImageLayout, cmd: vk.CommandBuffer) {
	if old_layout == new_layout {
		return
	}
	image := sim.gpu.storage[index].handle
	if image == vk.Image(0) {
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
				dst_stage = {.COMPUTE_SHADER, .FRAGMENT_SHADER}
			}
	case .GENERAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.SHADER_WRITE}
			dst_access = {.SHADER_READ}
			src_stage = {.COMPUTE_SHADER}
			dst_stage = {.COMPUTE_SHADER, .FRAGMENT_SHADER}
		}
	case .SHADER_READ_ONLY_OPTIMAL:
		#partial switch new_layout {
		case .GENERAL:
			src_access = {.SHADER_READ}
			dst_access = {.SHADER_READ, .SHADER_WRITE}
			src_stage = {.COMPUTE_SHADER, .FRAGMENT_SHADER}
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
		image = image,
		subresourceRange = {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
		},
	}
	vk.CmdPipelineBarrier(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	sim.gpu.storage[index].layout = new_layout
}

gray_scott_next_compute_slot :: proc(sim: ^Gray_Scott_Simulation) -> (int, bool) {
	slot := int(sim.gpu.compute_dispatch_slot)
	if slot < 0 || slot >= GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS {
		return 0, false
	}
	sim.gpu.compute_dispatch_slot += 1
	return slot, true
}

gray_scott_write_params :: proc(sim: ^Gray_Scott_Simulation, dispatch_slot: int, mode: u32, dt: f32) {
	if dispatch_slot < 0 || dispatch_slot >= len(sim.gpu.params_buffers) || sim.gpu.params_buffers[dispatch_slot].mapped == nil {
		return
	}
	params := cast(^Gray_Scott_Params)sim.gpu.params_buffers[dispatch_slot].mapped
	params^ = {
		feed = sim.settings.feed,
		kill = sim.settings.kill,
		diffusion_a = sim.settings.diffusion_a,
		diffusion_b = sim.settings.diffusion_b,
		timestep = dt,
		width = u32(max(sim.gpu.width, 1)),
		height = u32(max(sim.gpu.height, 1)),
		mode = mode,
		seed = sim.runtime.seed,
		frame_index = u32(sim.runtime.frame_index & 0xffffffff),
		mask_pattern = u32(sim.settings.mask_pattern),
		mask_target = u32(sim.settings.mask_target),
		mask_strength = sim.settings.mask_strength,
		mask_mirror_horizontal = sim.settings.mask_mirror_horizontal ? 1 : 0,
		mask_mirror_vertical = sim.settings.mask_mirror_vertical ? 1 : 0,
		mask_invert_tone = sim.settings.mask_invert_tone ? 1 : 0,
		max_timestep = sim.settings.max_timestep,
		stability_factor = sim.settings.stability_factor,
		enable_adaptive_timestep = sim.settings.enable_adaptive_timestep ? 1 : 0,
		cursor_x = sim.runtime.paint_x,
		cursor_y = sim.runtime.paint_y,
		cursor_size = sim.settings.cursor_size,
		cursor_strength = sim.settings.cursor_strength,
		mouse_button = sim.runtime.paint_button,
	}
}

gray_scott_compute_memory_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	barrier := vk.MemoryBarrier {
		sType = .MEMORY_BARRIER,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = {.SHADER_READ, .SHADER_WRITE},
	}
	vk.CmdPipelineBarrier(
		cmd,
		{.COMPUTE_SHADER},
		{.COMPUTE_SHADER},
		{},
		1,
		&barrier,
		0,
		nil,
		0,
		nil,
	)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

gray_scott_dispatch_compute :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dispatch_slot: int) -> bool {
	group_x := u32((max(sim.gpu.width, 1) + GRAY_SCOTT_WORKGROUP_SIZE - 1) / GRAY_SCOTT_WORKGROUP_SIZE)
	group_y := u32((max(sim.gpu.height, 1) + GRAY_SCOTT_WORKGROUP_SIZE - 1) / GRAY_SCOTT_WORKGROUP_SIZE)
	if group_x == 0 || group_y == 0 {
		return false
	}
	if dispatch_slot < 0 || dispatch_slot >= len(sim.gpu.compute_sets) || sim.gpu.compute_sets[dispatch_slot] == vk.DescriptorSet(0) {
		return false
	}
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.compute_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.compute_pipeline.layout, 0, 1, &sim.gpu.compute_sets[dispatch_slot], 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, group_x, group_y, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	gray_scott_compute_memory_barrier(vk_ctx, cmd)
	return true
}

gray_scott_estimate_stable_timestep :: proc(sim: ^Gray_Scott_Simulation) -> f32 {
	// Forward Euler with the five-point 2D Laplacian requires dt * D <= 1/4.
	// Mask modulation is a [0, 1] multiplier, so the configured diffusion is
	// the maximum diffusion present anywhere in the field.
	max_diffusion := max(max(sim.settings.diffusion_a, sim.settings.diffusion_b), 0.0001)
	diffusion_limit := 0.25 / max_diffusion
	reaction_limit := 1.0 / max(1.0 + sim.settings.feed + sim.settings.kill, 0.0001)
	stable := min(diffusion_limit, reaction_limit) * max(sim.settings.stability_factor, 0.01)
	return min(max(stable, 0.0001), max(sim.settings.max_timestep, 0.0001))
}

gray_scott_apply_compute_mode_to_image :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, write_index: int, mode: u32, dt: f32) -> bool {
	read_index := 1 - write_index
	if sim.gpu.storage[read_index].layout != .GENERAL {
		gray_scott_transition_image(sim, vk_ctx, read_index, sim.gpu.storage[read_index].layout, .GENERAL, cmd)
	}
	if sim.gpu.storage[write_index].layout != .GENERAL {
		gray_scott_transition_image(sim, vk_ctx, write_index, sim.gpu.storage[write_index].layout, .GENERAL, cmd)
	}
	dispatch_slot, ok := gray_scott_next_compute_slot(sim)
	if !ok {
		engine.log_error("gray_scott_apply_compute_mode_to_image: compute dispatch slots exhausted")
		return false
	}
	gray_scott_write_params(sim, dispatch_slot, mode, dt)
	if !gray_scott_update_compute_descriptors(sim, vk_ctx, read_index, write_index, dispatch_slot) {
		return false
	}
	if !gray_scott_dispatch_compute(sim, vk_ctx, cmd, dispatch_slot) {
		return false
	}
	return true
}

gray_scott_apply_compute_mode_to_state :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, mode: u32, dt: f32) -> bool {
	if !gray_scott_apply_compute_mode_to_image(sim, vk_ctx, cmd, 0, mode, dt) {
		return false
	}
	if !gray_scott_apply_compute_mode_to_image(sim, vk_ctx, cmd, 1, mode, dt) {
		return false
	}
	sim.gpu.state_index = 0
	sim.runtime.pending_seed_mode = 0
	return true
}

gray_scott_step_compute_resources :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dt: f32) -> bool {
	sim.gpu.compute_dispatch_slot = 0
	if sim.gpu.compute_pipeline.pipeline == vk.Pipeline(0) || sim.gpu.compute_sets[0] == vk.DescriptorSet(0) || sim.gpu.compute_sets[1] == vk.DescriptorSet(0) {
		return false
	}
	for i := 0; i < 2; i += 1 {
		if sim.gpu.storage[i].handle == vk.Image(0) {
			return false
		}
	}
	if sim.runtime.webcam_active {
		_ = gray_scott_update_webcam_nutrient_map(sim)
	}

	if sim.runtime.pending_seed_mode != 0 {
		if !gray_scott_apply_compute_mode_to_state(sim, vk_ctx, cmd, sim.runtime.pending_seed_mode, 1.0) {
			return false
		}
	}
	if sim.runtime.paint_active {
		read_index := int(sim.gpu.state_index)
		write_index := 1 - read_index
		if !gray_scott_apply_compute_mode_to_image(sim, vk_ctx, cmd, write_index, GRAY_SCOTT_MODE_PAINT, 1.0) {
			return false
		}
		sim.gpu.state_index = u32(write_index)
	}
	if sim.settings.paused {
		return true
	}

	base_timestep := sim.settings.timestep
	speed := max(sim.settings.simulation_speed, 0.0)
	// Preserve the legacy apparent rate at 60 Hz while making evolution depend
	// on elapsed time rather than the number of rendered frames.
	total_step_dt := base_timestep * speed * dt * 60.0
	if total_step_dt <= 0 || dt <= 0 {
		return true
	}
	stable_dt := gray_scott_estimate_stable_timestep(sim)
	// Bound catch-up work after a long stall rather than taking an unstable step.
	total_step_dt = min(total_step_dt, stable_dt * f32(GRAY_SCOTT_MAX_STABLE_SUBSTEPS))
	substeps := max(int(math.ceil(total_step_dt / stable_dt)), 1)
	per_iteration_dt := total_step_dt / f32(substeps)

	read_index := int(sim.gpu.state_index)
	write_index := 1 - read_index

	for _ in 0 ..< substeps {
		if sim.gpu.storage[read_index].layout != .GENERAL {
			gray_scott_transition_image(sim, vk_ctx, read_index, sim.gpu.storage[read_index].layout, .GENERAL, cmd)
		}
		if sim.gpu.storage[write_index].layout != .GENERAL {
			gray_scott_transition_image(sim, vk_ctx, write_index, sim.gpu.storage[write_index].layout, .GENERAL, cmd)
		}
		dispatch_slot, ok := gray_scott_next_compute_slot(sim)
		if !ok {
			engine.log_error("gray_scott_step_compute_resources: compute dispatch slots exhausted")
			return false
		}
		gray_scott_write_params(sim, dispatch_slot, GRAY_SCOTT_MODE_STEP, per_iteration_dt)
		if !gray_scott_update_compute_descriptors(sim, vk_ctx, read_index, write_index, dispatch_slot) {
			return false
		}
		if !gray_scott_dispatch_compute(sim, vk_ctx, cmd, dispatch_slot) {
			return false
		}
		read_index, write_index = write_index, read_index
	}
	sim.gpu.state_index = u32(read_index)
	return true
}

gray_scott_gpu_step :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dt: f32) {
	if !gray_scott_ensure_gpu_runtime(sim, vk_ctx) {
		return
	}
	if sim.runtime.nutrient_upload_pending {
		gray_scott_upload_nutrient_map(sim)
	}
	_ = vk_ctx
	_ = gray_scott_step_compute_resources(sim, vk_ctx, cmd, dt)
}

gray_scott_shader_path_report :: proc(sim: ^Gray_Scott_Simulation, kind: string) -> string {
	if kind == "compute" {
		return sim.gpu.step_shader_spirv_path
	}
	return sim.gpu.present_shader_spirv_path
}

gray_scott_gpu_present :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	extent := vk_ctx.swapchain_extent
	viewport := vk.Viewport{x = 0, y = 0, width = f32(extent.width), height = f32(extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = extent}
	gray_scott_gpu_present_viewport(sim, vk_ctx, cmd, viewport, scissor)
}

gray_scott_gpu_present_viewport :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gray_scott_gpu_prepare_present_viewport(sim, vk_ctx, cmd) {
		return
	}
	gray_scott_gpu_draw_prepared_viewport(sim, vk_ctx, cmd, viewport, scissor)
}

gray_scott_gpu_prepare_present_viewport :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) -> bool {
	if !gray_scott_ensure_gpu_runtime(sim, vk_ctx) {
		return false
	}

	if sim.gpu.present_pipeline.pipeline == vk.Pipeline(0) {
		return false
	}
	if sim.gpu.state_index >= 2 {
		return false
	}
	state_index := int(sim.gpu.state_index)
	extent := vk_ctx.swapchain_extent
	if extent.width == 0 || extent.height == 0 {
		return false
	}
	if state_index < 0 || state_index >= 2 {
		return false
	}
	if sim.gpu.storage[state_index].layout != .SHADER_READ_ONLY_OPTIMAL {
		gray_scott_transition_image(sim, vk_ctx, state_index, sim.gpu.storage[state_index].layout, .SHADER_READ_ONLY_OPTIMAL, cmd)
	}
	frame_slot := vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT
	sim.gpu.present_frame_slot = frame_slot
	gray_scott_sync_present_resources_for_slot(sim, frame_slot)
	if !gray_scott_update_present_descriptor(sim, vk_ctx, state_index, frame_slot) {
		return false
	}
	return true
}

gray_scott_gpu_draw_prepared_viewport :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if sim == nil || !sim.gpu.ready || sim.gpu.present_pipeline.pipeline == vk.Pipeline(0) {
		return
	}

	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(cmd, 0, 1, &local_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &local_scissor)
	vk.CmdBindPipeline(cmd, .GRAPHICS, sim.gpu.present_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	frame_slot := min(sim.gpu.present_frame_slot, u32(engine.MAX_FRAMES_IN_FLIGHT - 1))
	present_set := sim.gpu.present_sets[frame_slot]
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, sim.gpu.present_pipeline.layout, 0, 1, &present_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	tile_count := infinite_render_tile_count(sim.runtime.camera_zoom)
	vk.CmdDraw(cmd, 6, tile_count * tile_count, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
}

gray_scott_destroy :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) {
	gray_scott_stop_webcam(sim)
	if vk_ctx == nil || vk_ctx.device == nil {
		sim.gpu = {}
		return
	}

	if sim.gpu.compute_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.compute_pipeline.pipeline, nil)
		sim.gpu.compute_pipeline.pipeline = vk.Pipeline(0)
	}
	if sim.gpu.compute_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.compute_pipeline.layout, nil)
		sim.gpu.compute_pipeline.layout = vk.PipelineLayout(0)
	}

	if sim.gpu.present_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.present_pipeline)
	}

	if sim.gpu.compute_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.compute_set_layout, nil)
		sim.gpu.compute_set_layout = vk.DescriptorSetLayout(0)
	}
	if sim.gpu.present_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.present_set_layout, nil)
		sim.gpu.present_set_layout = vk.DescriptorSetLayout(0)
	}
	if sim.gpu.compute_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, sim.gpu.compute_pool, nil)
		sim.gpu.compute_pool = vk.DescriptorPool(0)
	}
	if sim.gpu.present_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, sim.gpu.present_pool, nil)
		sim.gpu.present_pool = vk.DescriptorPool(0)
	}
	if sim.gpu.sampler != vk.Sampler(0) {
		vk.DestroySampler(vk_ctx.device, sim.gpu.sampler, nil)
		sim.gpu.sampler = vk.Sampler(0)
	}
	for i := 0; i < 2; i += 1 {
		if sim.gpu.storage[i].view != vk.ImageView(0) {
			vk.DestroyImageView(vk_ctx.device, sim.gpu.storage[i].view, nil)
		}
		if sim.gpu.storage[i].handle != vk.Image(0) {
			vk.DestroyImage(vk_ctx.device, sim.gpu.storage[i].handle, nil)
		}
		if sim.gpu.storage[i].memory != vk.DeviceMemory(0) {
			vk.FreeMemory(vk_ctx.device, sim.gpu.storage[i].memory, nil)
		}
		sim.gpu.storage[i] = {}
	}
	for i := 0; i < len(sim.gpu.params_buffers); i += 1 {
		if sim.gpu.params_buffers[i].handle != vk.Buffer(0) {
			engine.vk_destroy_buffer(vk_ctx, &sim.gpu.params_buffers[i])
		}
	}
	if sim.gpu.nutrient_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.nutrient_buffer)
	}
	if sim.gpu.lut_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.lut_buffer)
	}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if sim.gpu.present_params_buffers[i].handle != vk.Buffer(0) {
			engine.vk_destroy_buffer(vk_ctx, &sim.gpu.present_params_buffers[i])
		}
		if sim.gpu.camera_buffers[i].handle != vk.Buffer(0) {
			engine.vk_destroy_buffer(vk_ctx, &sim.gpu.camera_buffers[i])
		}
	}
	if sim.gpu.fullscreen_vertices.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.fullscreen_vertices)
	}
	if sim.gpu.step_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.step_shader_module)
	}
	if sim.gpu.present_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.present_shader_module)
	}
	if sim.gpu.vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.vertex_shader_module)
	}

	sim.gpu.ready = false
	sim.gpu.compute_sets = {}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		sim.gpu.present_sets[i] = vk.DescriptorSet(0)
	}
	sim.gpu.state_index = 0
	sim.gpu.step_shader_spirv_path = ""
	sim.gpu.vertex_shader_spirv_path = ""
	sim.gpu.present_shader_spirv_path = ""
}
