package render_vk

import engine "../engine"
import uifw "../ui"

import "core:math"
import vk "vendor:vulkan"

primordial_effective_step_dt :: proc(configured_dt, frame_dt: f32) -> f32 {
	return configured_dt * max(frame_dt, 0) * 60.0
}

primordial_gpu_ensure :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Primordial_Settings) -> bool {
	target_count := max(settings.particle_count, 1)
	if gpu.ready &&
	   gpu.particle_count == target_count &&
	   gpu.initialized_seed == settings.random_seed &&
	   gpu.initialized_position_generator == settings.position_generator {
		return true
	}
	primordial_gpu_destroy(gpu, vk_ctx)
	gpu.particle_count = target_count
	gpu.initialized_seed = settings.random_seed
	gpu.initialized_position_generator = settings.position_generator
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, PRIMORDIAL_UPDATE_SHADER_SOURCE, PRIMORDIAL_UPDATE_FALLBACK_SPV, .Compute, PRIMORDIAL_SOURCE_ENTRY, &gpu.update_shader) {
		engine.log_error("primordial_gpu_ensure: update shader load failed source=", PRIMORDIAL_UPDATE_SHADER_SOURCE)
		return false
	}
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, PRIMORDIAL_DENSITY_SHADER_SOURCE, PRIMORDIAL_DENSITY_FALLBACK_SPV, .Compute, PRIMORDIAL_SOURCE_ENTRY, &gpu.density_shader) {
		engine.log_error("primordial_gpu_ensure: density shader load failed source=", PRIMORDIAL_DENSITY_SHADER_SOURCE)
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, PRIMORDIAL_GRID_CLEAR_SHADER_SOURCE, PRIMORDIAL_GRID_CLEAR_FALLBACK_SPV, .Compute, PRIMORDIAL_SOURCE_ENTRY, &gpu.grid_clear_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, PRIMORDIAL_GRID_POPULATE_SHADER_SOURCE, PRIMORDIAL_GRID_POPULATE_FALLBACK_SPV, .Compute, PRIMORDIAL_SOURCE_ENTRY, &gpu.grid_populate_shader) {
		engine.log_error("primordial_gpu_ensure: grid shader load failed")
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, PRIMORDIAL_BACKGROUND_SHADER_SOURCE, PRIMORDIAL_BACKGROUND_VERTEX_FALLBACK_SPV, .Vertex, PRIMORDIAL_VERTEX_SOURCE_ENTRY, &gpu.background_vertex_shader) {
		engine.log_error("primordial_gpu_ensure: background vertex shader load failed source=", PRIMORDIAL_BACKGROUND_SHADER_SOURCE)
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, PRIMORDIAL_BACKGROUND_SHADER_SOURCE, PRIMORDIAL_BACKGROUND_FRAGMENT_FALLBACK_SPV, .Fragment, PRIMORDIAL_FRAGMENT_SOURCE_ENTRY, &gpu.background_fragment_shader) {
		engine.log_error("primordial_gpu_ensure: background fragment shader load failed source=", PRIMORDIAL_BACKGROUND_SHADER_SOURCE)
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, PRIMORDIAL_RENDER_SHADER_SOURCE, PRIMORDIAL_RENDER_VERTEX_FALLBACK_SPV, .Vertex, PRIMORDIAL_VERTEX_SOURCE_ENTRY, &gpu.render_vertex_shader) {
		engine.log_error("primordial_gpu_ensure: render vertex shader load failed source=", PRIMORDIAL_RENDER_SHADER_SOURCE)
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, PRIMORDIAL_RENDER_SHADER_SOURCE, PRIMORDIAL_RENDER_FRAGMENT_FALLBACK_SPV, .Fragment, PRIMORDIAL_FRAGMENT_SOURCE_ENTRY, &gpu.render_fragment_shader) {
		engine.log_error("primordial_gpu_ensure: render fragment shader load failed source=", PRIMORDIAL_RENDER_SHADER_SOURCE)
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, PRIMORDIAL_FADE_VERTEX_SHADER_SOURCE, PRIMORDIAL_FADE_VERTEX_FALLBACK_SPV, .Vertex, PRIMORDIAL_SOURCE_ENTRY, &gpu.fade_vertex_shader) {
		engine.log_error("primordial_gpu_ensure: fade vertex shader load failed source=", PRIMORDIAL_FADE_VERTEX_SHADER_SOURCE)
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, PRIMORDIAL_FADE_FRAGMENT_SHADER_SOURCE, PRIMORDIAL_FADE_FRAGMENT_FALLBACK_SPV, .Fragment, PRIMORDIAL_SOURCE_ENTRY, &gpu.fade_fragment_shader) {
		engine.log_error("primordial_gpu_ensure: fade fragment shader load failed source=", PRIMORDIAL_FADE_FRAGMENT_SHADER_SOURCE)
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	particle_size := vk.DeviceSize(size_of(Primordial_Particle) * int(gpu.particle_count))
	for i in 0 ..< 2 {
		if !engine.vk_create_host_buffer(vk_ctx, particle_size, {.STORAGE_BUFFER, .VERTEX_BUFFER}, &gpu.particle_buffers[i]) {
			primordial_gpu_destroy(gpu, vk_ctx)
			return false
		}
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(PRIMORDIAL_GRID_CELL_COUNT)), {.STORAGE_BUFFER}, &gpu.grid_heads_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(gpu.particle_count)), {.STORAGE_BUFFER}, &gpu.grid_next_buffer) {
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Primordial_Sim_Params)), {.UNIFORM_BUFFER}, &gpu.sim_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Primordial_Density_Params)), {.UNIFORM_BUFFER}, &gpu.density_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Primordial_Render_Params)), {.UNIFORM_BUFFER}, &gpu.render_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Primordial_Fade_Params)), {.UNIFORM_BUFFER}, &gpu.fade_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Primordial_Fade_Params)), {.UNIFORM_BUFFER}, &gpu.blit_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Primordial_Background_Params)), {.UNIFORM_BUFFER}, &gpu.background_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Primordial_Camera)), {.UNIFORM_BUFFER}, &gpu.camera_buffers[frame_slot]) {
			primordial_gpu_destroy(gpu, vk_ctx)
			return false
		}
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT), {.STORAGE_BUFFER}, &gpu.lut_buffer) {
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	primordial_initialize_particles(gpu, settings)
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		primordial_upload_camera(gpu, frame_slot, f32(vk_ctx.swapchain_extent.width), f32(vk_ctx.swapchain_extent.height))
		primordial_upload_render_params(gpu, frame_slot, settings)
		primordial_upload_background_params(gpu, frame_slot, settings)
		primordial_upload_blit_params(gpu, frame_slot)
	}
	if !primordial_create_trace_render_pass(gpu, vk_ctx) {
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !primordial_create_sampler(gpu, vk_ctx) {
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !primordial_create_descriptors(gpu, vk_ctx) {
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !primordial_create_compute_pipeline(vk_ctx, gpu.update_shader.handle, gpu.update_set_layout, &gpu.update_pipeline) {
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !primordial_create_compute_pipeline(vk_ctx, gpu.density_shader.handle, gpu.density_set_layout, &gpu.density_pipeline) {
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !primordial_create_compute_pipeline(vk_ctx, gpu.grid_clear_shader.handle, gpu.grid_clear_set_layout, &gpu.grid_clear_pipeline) ||
	   !primordial_create_compute_pipeline(vk_ctx, gpu.grid_populate_shader.handle, gpu.grid_populate_set_layout, &gpu.grid_populate_pipeline) {
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !primordial_create_background_pipeline(gpu, vk_ctx) {
		engine.log_error("primordial_gpu_ensure: background pipeline creation failed")
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !primordial_create_render_pipeline(gpu, vk_ctx) {
		engine.log_error("primordial_gpu_ensure: render pipeline creation failed")
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !primordial_create_render_pipeline_for_pass(gpu, vk_ctx, gpu.trace_render_pass, &gpu.trace_particle_pipeline) {
		engine.log_error("primordial_gpu_ensure: trace particle pipeline creation failed")
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !primordial_create_fade_pipeline(gpu, vk_ctx, gpu.trace_render_pass, &gpu.fade_pipeline) {
		engine.log_error("primordial_gpu_ensure: fade pipeline creation failed")
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !primordial_create_fade_pipeline(gpu, vk_ctx, vk_ctx.render_pass, &gpu.blit_pipeline) {
		engine.log_error("primordial_gpu_ensure: blit pipeline creation failed")
		primordial_gpu_destroy(gpu, vk_ctx)
		return false
	}
	gpu.ready = true
	return true
}

primordial_initialize_particles :: proc(gpu: ^Primordial_Gpu_State, settings: ^Primordial_Settings) {
	// Xorshift32's all-zero state is absorbing. Keep zero valid as a user-facing
	// seed, but map it to a deterministic non-zero state so particles do not all
	// initialize in the same grid cell and trigger pathological neighbor scans.
	seed := primordial_rng_seed(settings.random_seed)
	for buffer_index in 0 ..< 2 {
		if gpu.particle_buffers[buffer_index].mapped == nil {
			continue
		}
		particles := (cast([^]Primordial_Particle)gpu.particle_buffers[buffer_index].mapped)[:gpu.particle_count]
		rng := seed
		for i in 0 ..< int(gpu.particle_count) {
			pos := primordial_generate_position(u32(i), settings.position_generator, &rng)
			rand_heading := primordial_next_random01(&rng)
			particles[i] = {
				position = pos,
				previous_position = pos,
				heading = rand_heading * 2 * math.PI,
				velocity = 0,
				density = 0,
				grabbed = 0,
			}
		}
	}
	gpu.state_index = 0
}

primordial_rng_seed :: proc(seed: u32) -> u32 {
	return seed != 0 ? seed : 0x6d2b79f5
}

primordial_generate_position :: proc(index, generator: u32, rng: ^u32) -> [2]f32 {
	_ = index
	rand_x := primordial_next_random01(rng)
	rand_y := primordial_next_random01(rng)
	switch generator {
	case 1: // Center
		return {(rand_x * 2 - 1) * 0.3, (rand_y * 2 - 1) * 0.3}
	case 2: // UniformCircle
		angle := rand_x * 2 * math.PI
		radius := math.sqrt(rand_y) * 0.8
		return {math.cos(angle) * radius, math.sin(angle) * radius}
	case 3: // CenteredCircle
		angle := rand_x * 2 * math.PI
		radius := rand_y * 0.8
		return {math.cos(angle) * radius, math.sin(angle) * radius}
	case 4: // Ring
		angle := rand_x * 2 * math.PI
		radius := f32(0.35) + f32(0.01) * ((rand_y - 0.5) * 2)
		return {math.cos(angle) * radius, math.sin(angle) * radius}
	case 5: // Line
		return {rand_x * 2 - 1, (rand_y - 0.5) * 0.3}
	case 6: // Spiral
		f := rand_x
		angle := 2.0 * 2 * math.PI * f
		spread := 0.25 * min(f, 0.2)
		radius := 0.45 * f + spread * ((rand_y - 0.5) * 2)
		return {math.cos(angle) * radius, math.sin(angle) * radius}
	case:
		return {rand_x * 2 - 1, rand_y * 2 - 1}
	}
}

primordial_next_random01 :: proc(rng: ^u32) -> f32 {
	rng^ = rng^ ~ (rng^ << 13)
	rng^ = rng^ ~ (rng^ >> 17)
	rng^ = rng^ ~ (rng^ << 5)
	return f32(rng^) / f32(0xffffffff)
}

primordial_upload_lut :: proc(gpu: ^Primordial_Gpu_State, settings: ^Primordial_Settings) {
	if gpu.lut_buffer.mapped == nil {
		return
	}
	scheme := color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
	data := (cast([^]u32)gpu.lut_buffer.mapped)[:COLOR_SCHEME_U32_COUNT]
	_ = color_scheme_write_u32_buffer(scheme, data)
}

primordial_upload_camera :: proc(gpu: ^Primordial_Gpu_State, frame_slot: int, width, height: f32) {
	if gpu.camera_buffers[frame_slot].mapped == nil {
		return
	}
	camera := cast(^Primordial_Camera)gpu.camera_buffers[frame_slot].mapped
	camera^ = {
		transform_matrix = {
			1, 0, 0, 0,
			0, 1, 0, 0,
			0, 0, 1, 0,
			0, 0, 0, 1,
		},
		position = {0, 0},
		zoom = 1,
		aspect_ratio = width / max(height, 1),
	}
}

primordial_upload_background_params :: proc(gpu: ^Primordial_Gpu_State, frame_slot: int, settings: ^Primordial_Settings) {
	if gpu.background_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Primordial_Background_Params)gpu.background_params_buffers[frame_slot].mapped
	color := primordial_background_color(settings)
	params^ = {background_color = color}
}

primordial_background_color :: proc(settings: ^Primordial_Settings) -> [4]f32 {
	#partial switch settings.background_color_mode {
	case .Black:
		return {0, 0, 0, 1}
	case .White:
		return {1, 1, 1, 1}
	case .Gray18:
		return {0.18, 0.18, 0.18, 1}
	case .Color_Scheme:
		scheme := color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
		return color_scheme_color_at(scheme, 0)
	case:
		return {0, 0, 0, 1}
	}
}

primordial_upload_render_params :: proc(gpu: ^Primordial_Gpu_State, frame_slot: int, settings: ^Primordial_Settings, camera: ^Camera_Control_State = nil) {
	if gpu.render_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Primordial_Render_Params)gpu.render_params_buffers[frame_slot].mapped
	camera_data := camera_uniform_data(camera, 1, 1)
	tile_count := infinite_render_tile_count(camera_data.zoom)
	gpu.present_tile_count = tile_count
	params^ = {
		particle_size = settings.particle_size,
		screen_width = 1,
		screen_height = 1,
		foreground_color_mode = u32(settings.foreground_color_mode),
		camera_position = camera_data.position,
		camera_zoom = camera_data.zoom,
		tile_count = tile_count,
	}
}

primordial_upload_render_params_for_extent :: proc(gpu: ^Primordial_Gpu_State, frame_slot: int, settings: ^Primordial_Settings, width, height: f32, camera: ^Camera_Control_State = nil) {
	if gpu.render_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Primordial_Render_Params)gpu.render_params_buffers[frame_slot].mapped
	camera_data := camera_uniform_data(camera, width, height)
	tile_count := infinite_render_tile_count(camera_data.zoom)
	if gpu.present_camera_valid &&
	   (gpu.present_camera_position != camera_data.position || gpu.present_camera_zoom != camera_data.zoom) {
		gpu.trace_initialized = false
	}
	gpu.present_camera_position = camera_data.position
	gpu.present_camera_zoom = camera_data.zoom
	gpu.present_camera_valid = true
	gpu.present_tile_count = tile_count
	params^ = {
		particle_size = settings.particle_size,
		screen_width = width,
		screen_height = height,
		foreground_color_mode = u32(settings.foreground_color_mode),
		camera_position = camera_data.position,
		camera_zoom = camera_data.zoom,
		tile_count = tile_count,
	}
}

primordial_upload_fade_params :: proc(gpu: ^Primordial_Gpu_State, frame_slot: int, settings: ^Primordial_Settings) {
	if gpu.fade_params_buffers[frame_slot].mapped == nil {
		return
	}
	fade_amount: f32
	if settings.trace_fade < 1.0 {
		fade_amount = (1.0 - settings.trace_fade) * 0.05
	}
	params := cast(^Primordial_Fade_Params)gpu.fade_params_buffers[frame_slot].mapped
	params^ = {fade_amount = fade_amount}
}

primordial_upload_blit_params :: proc(gpu: ^Primordial_Gpu_State, frame_slot: int) {
	if gpu.blit_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Primordial_Fade_Params)gpu.blit_params_buffers[frame_slot].mapped
	params^ = {fade_amount = 0}
}

primordial_write_step_params :: proc(gpu: ^Primordial_Gpu_State, frame_slot: int, sim: ^Remaining_Sim_State, dt: f32, width, height: f32) {
	settings := &sim.primordial
	if gpu.sim_params_buffers[frame_slot].mapped != nil {
		params := cast(^Primordial_Sim_Params)gpu.sim_params_buffers[frame_slot].mapped
		params^ = {
			mouse_position = sim.cursor_world,
			mouse_velocity = sim.cursor_world_velocity,
			alpha = settings.alpha * math.PI / 180,
			beta = settings.beta,
			velocity = settings.velocity,
			radius = settings.radius,
			// `settings.dt` is the legacy per-frame amount at 60 Hz. Scale it by
			// elapsed time so uncapped presentation does not accelerate particles.
			dt = primordial_effective_step_dt(settings.dt, dt),
			width = 2,
			height = 2,
			wrap_edges = settings.wrap_edges ? u32(1) : u32(0),
			particle_count = gpu.particle_count,
			mouse_pressed = sim.cursor_active != 0 ? u32(1) : u32(0),
			mouse_mode = sim.cursor_mode,
			cursor_size = sim.cursor_size,
			cursor_strength = sim.cursor_strength,
			aspect_ratio = width / max(height, 1),
			grid_axis = PRIMORDIAL_GRID_AXIS,
			grid_cell_size = 2.0 / f32(PRIMORDIAL_GRID_AXIS),
			collision_enabled = settings.collision_enabled ? u32(1) : u32(0),
			collision_distance = max(settings.particle_size * 2.0, 0.0001),
			collision_relaxation = clamp(settings.collision_relaxation, 0, 1),
			collision_damping = clamp(settings.collision_damping, 0, 1),
		}
	}
	if gpu.density_params_buffers[frame_slot].mapped != nil {
		params := cast(^Primordial_Density_Params)gpu.density_params_buffers[frame_slot].mapped
		params^ = {
			particle_count = gpu.particle_count,
			density_radius = settings.density_radius,
			coloring_mode = u32(settings.foreground_color_mode),
			grid_axis = PRIMORDIAL_GRID_AXIS,
			grid_cell_size = 2.0 / f32(PRIMORDIAL_GRID_AXIS),
		}
	}
}

primordial_create_descriptors :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	update_bindings := [5]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	update_layout_info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(update_bindings)), pBindings = raw_data(update_bindings[:])}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &update_layout_info, nil, &gpu.update_set_layout) != .SUCCESS {
		return false
	}
	density_bindings := [4]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	density_layout_info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(density_bindings)), pBindings = raw_data(density_bindings[:])}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &density_layout_info, nil, &gpu.density_set_layout) != .SUCCESS {
		return false
	}
	grid_clear_bindings := [1]vk.DescriptorSetLayoutBinding{{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}}}
	grid_clear_layout_info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = 1, pBindings = raw_data(grid_clear_bindings[:])}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &grid_clear_layout_info, nil, &gpu.grid_clear_set_layout) != .SUCCESS {return false}
	grid_populate_bindings := [4]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	grid_populate_layout_info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = 4, pBindings = raw_data(grid_populate_bindings[:])}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &grid_populate_layout_info, nil, &gpu.grid_populate_set_layout) != .SUCCESS {return false}
	background_bindings := [2]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	background_layout_info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(background_bindings)), pBindings = raw_data(background_bindings[:])}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &background_layout_info, nil, &gpu.background_set_layout) != .SUCCESS {
		return false
	}
	render_bindings := [3]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX, .FRAGMENT}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX, .FRAGMENT}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX, .FRAGMENT}},
	}
	render_layout_info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(render_bindings)), pBindings = raw_data(render_bindings[:])}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &render_layout_info, nil, &gpu.render_set_layout) != .SUCCESS {
		return false
	}
	fade_bindings := [3]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	fade_layout_info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(fade_bindings)), pBindings = raw_data(fade_bindings[:])}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &fade_layout_info, nil, &gpu.fade_set_layout) != .SUCCESS {
		return false
	}
	pool_sizes := [4]vk.DescriptorPoolSize {
		{type = .STORAGE_BUFFER, descriptorCount = 30 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .UNIFORM_BUFFER, descriptorCount = 16 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .SAMPLED_IMAGE, descriptorCount = 4 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .SAMPLER, descriptorCount = 4 * engine.MAX_FRAMES_IN_FLIGHT},
	}
	pool_info := vk.DescriptorPoolCreateInfo{sType = .DESCRIPTOR_POOL_CREATE_INFO, poolSizeCount = u32(len(pool_sizes)), pPoolSizes = raw_data(pool_sizes[:]), maxSets = 14 * engine.MAX_FRAMES_IN_FLIGHT}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &gpu.descriptor_pool) != .SUCCESS {
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		layouts := [14]vk.DescriptorSetLayout{gpu.update_set_layout, gpu.update_set_layout, gpu.density_set_layout, gpu.density_set_layout, gpu.background_set_layout, gpu.render_set_layout, gpu.render_set_layout, gpu.fade_set_layout, gpu.fade_set_layout, gpu.fade_set_layout, gpu.fade_set_layout, gpu.grid_clear_set_layout, gpu.grid_populate_set_layout, gpu.grid_populate_set_layout}
		sets: [14]vk.DescriptorSet
		alloc := vk.DescriptorSetAllocateInfo{sType = .DESCRIPTOR_SET_ALLOCATE_INFO, descriptorPool = gpu.descriptor_pool, descriptorSetCount = u32(len(layouts)), pSetLayouts = raw_data(layouts[:])}
		if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(sets[:])) != .SUCCESS {
			return false
		}
		gpu.update_sets[frame_slot][0] = sets[0]
		gpu.update_sets[frame_slot][1] = sets[1]
		gpu.density_sets[frame_slot][0] = sets[2]
		gpu.density_sets[frame_slot][1] = sets[3]
		gpu.background_sets[frame_slot] = sets[4]
		gpu.render_sets[frame_slot][0] = sets[5]
		gpu.render_sets[frame_slot][1] = sets[6]
		gpu.fade_sets[frame_slot][0] = sets[7]
		gpu.fade_sets[frame_slot][1] = sets[8]
		gpu.blit_sets[frame_slot][0] = sets[9]
		gpu.blit_sets[frame_slot][1] = sets[10]
		gpu.grid_clear_sets[frame_slot] = sets[11]
		gpu.grid_populate_sets[frame_slot][0] = sets[12]
		gpu.grid_populate_sets[frame_slot][1] = sets[13]
	}
	primordial_update_descriptors(gpu, vk_ctx)
	return true
}

primordial_update_descriptors :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		primordial_update_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	}
}

primordial_update_descriptors_for_slot :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	particle_range := vk.DeviceSize(size_of(Primordial_Particle) * int(gpu.particle_count))
	sim_info := vk.DescriptorBufferInfo{buffer = gpu.sim_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Primordial_Sim_Params))}
	density_params_info := vk.DescriptorBufferInfo{buffer = gpu.density_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Primordial_Density_Params))}
	render_params_info := vk.DescriptorBufferInfo{buffer = gpu.render_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Primordial_Render_Params))}
	background_params_info := vk.DescriptorBufferInfo{buffer = gpu.background_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Primordial_Background_Params))}
	camera_info := vk.DescriptorBufferInfo{buffer = gpu.camera_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Primordial_Camera))}
	lut_info := vk.DescriptorBufferInfo{buffer = gpu.lut_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT)}
	grid_heads_info := vk.DescriptorBufferInfo{buffer = gpu.grid_heads_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * int(PRIMORDIAL_GRID_CELL_COUNT))}
	grid_next_info := vk.DescriptorBufferInfo{buffer = gpu.grid_next_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * int(gpu.particle_count))}
	grid_clear_set := gpu.grid_clear_sets[frame_slot]
	grid_clear_write := vk.WriteDescriptorSet{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_clear_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_heads_info}
	vk.UpdateDescriptorSets(vk_ctx.device, 1, &grid_clear_write, 0, nil)
	background_set := gpu.background_sets[frame_slot]
	background_writes := [2]vk.WriteDescriptorSet {
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = background_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &camera_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = background_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &background_params_info},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(background_writes)), raw_data(background_writes[:]), 0, nil)
	for write_index in 0 ..< 2 {
		read_index := 1 - write_index
		read_info := vk.DescriptorBufferInfo{buffer = gpu.particle_buffers[read_index].handle, offset = 0, range = particle_range}
		write_info := vk.DescriptorBufferInfo{buffer = gpu.particle_buffers[write_index].handle, offset = 0, range = particle_range}
		update_set := gpu.update_sets[frame_slot][write_index]
		density_set := gpu.density_sets[frame_slot][write_index]
		render_set := gpu.render_sets[frame_slot][write_index]
		update_writes := [5]vk.WriteDescriptorSet {
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = update_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &read_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = update_set, dstBinding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &write_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = update_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &sim_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = update_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_heads_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = update_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_next_info},
		}
		vk.UpdateDescriptorSets(vk_ctx.device, u32(len(update_writes)), raw_data(update_writes[:]), 0, nil)
		grid_populate_set := gpu.grid_populate_sets[frame_slot][write_index]
		grid_populate_writes := [4]vk.WriteDescriptorSet {
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_populate_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &read_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_populate_set, dstBinding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_heads_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_populate_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_next_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_populate_set, dstBinding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &sim_info},
		}
		vk.UpdateDescriptorSets(vk_ctx.device, 4, raw_data(grid_populate_writes[:]), 0, nil)
		density_writes := [4]vk.WriteDescriptorSet {
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = density_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &write_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = density_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &density_params_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = density_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_heads_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = density_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_next_info},
		}
		vk.UpdateDescriptorSets(vk_ctx.device, u32(len(density_writes)), raw_data(density_writes[:]), 0, nil)
		render_writes := [3]vk.WriteDescriptorSet {
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = render_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &write_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = render_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &render_params_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = render_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &lut_info},
		}
		vk.UpdateDescriptorSets(vk_ctx.device, u32(len(render_writes)), raw_data(render_writes[:]), 0, nil)
	}
}

primordial_update_trace_descriptors :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		primordial_update_trace_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	}
}

primordial_update_trace_descriptors_for_slot :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	fade_info := vk.DescriptorBufferInfo{buffer = gpu.fade_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Primordial_Fade_Params))}
	blit_info := vk.DescriptorBufferInfo{buffer = gpu.blit_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Primordial_Fade_Params))}
	sampler_info := vk.DescriptorImageInfo{sampler = gpu.trace_sampler}
	for i in 0 ..< len(gpu.trace_images) {
		image_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.trace_images[i].view}
		fade_set := gpu.fade_sets[frame_slot][i]
		blit_set := gpu.blit_sets[frame_slot][i]
		fade_writes := [3]vk.WriteDescriptorSet {
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = fade_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &fade_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = fade_set, dstBinding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = fade_set, dstBinding = 2, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
		}
		blit_writes := [3]vk.WriteDescriptorSet {
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = blit_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &blit_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = blit_set, dstBinding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = blit_set, dstBinding = 2, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
		}
		vk.UpdateDescriptorSets(vk_ctx.device, u32(len(fade_writes)), raw_data(fade_writes[:]), 0, nil)
		vk.UpdateDescriptorSets(vk_ctx.device, u32(len(blit_writes)), raw_data(blit_writes[:]), 0, nil)
	}
}

primordial_create_compute_pipeline :: proc(vk_ctx: ^engine.Vk_Context, shader: vk.ShaderModule, set_layout: vk.DescriptorSetLayout, out: ^engine.Vk_Compute_Pipeline) -> bool {
	layouts := [1]vk.DescriptorSetLayout{set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &out.layout) != .SUCCESS {
		return false
	}
	stage := vk.PipelineShaderStageCreateInfo{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.COMPUTE}, module = shader, pName = PRIMORDIAL_ENTRY}
	info := vk.ComputePipelineCreateInfo{sType = .COMPUTE_PIPELINE_CREATE_INFO, stage = stage, layout = out.layout}
	return vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &out.pipeline) == .SUCCESS
}

primordial_create_background_pipeline :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	layouts := [1]vk.DescriptorSetLayout{gpu.background_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = raw_data(layouts[:])}
	if result := vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gpu.background_pipeline.layout); result != .SUCCESS {
		engine.log_error("primordial_create_background_pipeline: CreatePipelineLayout failed result=", result)
		return false
	}
	stages := [2]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = gpu.background_vertex_shader.handle, pName = PRIMORDIAL_VERTEX_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = gpu.background_fragment_shader.handle, pName = PRIMORDIAL_FRAGMENT_ENTRY},
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
		layout = gpu.background_pipeline.layout,
		renderPass = vk_ctx.render_pass,
		subpass = 0,
	}
	result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &gpu.background_pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("primordial_create_background_pipeline: CreateGraphicsPipelines failed result=", result)
		return false
	}
	return true
}
