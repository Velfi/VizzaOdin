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
