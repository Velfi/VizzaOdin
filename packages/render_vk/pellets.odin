package render_vk

import engine "zelda_engine:engine"
import uifw "zelda_engine:ui"

import "core:math"
import vk "vendor:vulkan"

pellets_semi_implicit_euler :: proc(position, velocity, acceleration: [2]f32, dt, damping: f32) -> ([2]f32, [2]f32) {
	next_velocity := velocity + acceleration * dt
	next_velocity *= damping
	return position + next_velocity * dt, next_velocity
}

pellets_toroidal_delta :: proc(from, to: [2]f32) -> [2]f32 {
	delta := to - from
	if math.abs(delta.x) > 1 do delta.x -= math.sign(delta.x) * 2
	if math.abs(delta.y) > 1 do delta.y -= math.sign(delta.y) * 2
	return delta
}

pellets_density_contribution :: proc(distance_squared, radius: f32) -> f32 {
	if distance_squared < 0 || distance_squared >= radius * radius do return 0
	return 1 / (1 + distance_squared)
}

pellets_bounded_separation :: proc(direction: [2]f32, total_overlap: f32, overlap_count: u32, strength, particle_size: f32) -> [2]f32 {
	length_squared := direction.x * direction.x + direction.y * direction.y
	if overlap_count == 0 || total_overlap <= particle_size * 0.003 || length_squared <= 1e-12 do return {}
	unit := direction / f32(math.sqrt(length_squared))
	average_overlap := total_overlap / f32(overlap_count)
	correction := min(average_overlap * strength * 1.5, particle_size * 0.8)
	return unit * correction
}

pellets_gpu_ensure :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Pellets_Settings) -> bool {
	target_count := max(settings.particle_count, 1)
	cell_size := max(settings.particle_size * 3, 0.01)
	grid_width := max(u32(2.0 / cell_size), 1)
	grid_height := max(u32(2.0 / cell_size), 1)
	if gpu.ready && gpu.particle_count == target_count && gpu.grid_width == grid_width && gpu.grid_height == grid_height {
		return true
	}
	pellets_gpu_destroy(gpu, vk_ctx)
	gpu.particle_count = target_count
	gpu.cell_size = cell_size
	gpu.grid_width = grid_width
	gpu.grid_height = grid_height
	if !pellets_load_shaders(gpu, vk_ctx) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	particle_size := vk.DeviceSize(size_of(Pellets_Particle) * int(gpu.particle_count))
	if !engine.vk_create_host_buffer(vk_ctx, particle_size, {.STORAGE_BUFFER}, &gpu.particle_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	total_cells := gpu.grid_width * gpu.grid_height
	grid_size := vk.DeviceSize(size_of(u32) * int(gpu.particle_count))
	if !engine.vk_create_host_buffer(vk_ctx, grid_size, {.STORAGE_BUFFER}, &gpu.grid_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(total_cells)), {.STORAGE_BUFFER}, &gpu.grid_counts_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	block_count := max((total_cells + 255) / 256, 1)
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(total_cells)), {.STORAGE_BUFFER}, &gpu.grid_offsets_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(total_cells)), {.STORAGE_BUFFER}, &gpu.grid_cursors_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(block_count)), {.STORAGE_BUFFER}, &gpu.grid_block_sums_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Pellets_Physics_Params)), {.UNIFORM_BUFFER}, &gpu.physics_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Pellets_Render_Params)), {.UNIFORM_BUFFER}, &gpu.render_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Pellets_Fade_Params)), {.UNIFORM_BUFFER}, &gpu.trail_fade_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Pellets_Background_Params)), {.UNIFORM_BUFFER}, &gpu.background_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of([4]f32)), {.UNIFORM_BUFFER}, &gpu.background_color_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Pellets_Grid_Params)), {.UNIFORM_BUFFER}, &gpu.grid_params_buffers[frame_slot]) {
			pellets_gpu_destroy(gpu, vk_ctx)
			return false
		}
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT), {.STORAGE_BUFFER}, &gpu.lut_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	pellets_initialize_particles(gpu, settings)
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		pellets_write_static_params(gpu, vk_ctx, frame_slot, settings)
	}
	if !pellets_create_sampler(gpu, vk_ctx) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !pellets_create_descriptors(gpu, vk_ctx) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !pellets_create_compute_pipeline(vk_ctx, gpu.grid_clear_shader.handle, gpu.grid_clear_set_layout, &gpu.grid_clear_pipeline) ||
	   !pellets_create_compute_pipeline(vk_ctx, gpu.grid_populate_shader.handle, gpu.grid_populate_set_layout, &gpu.grid_populate_pipeline) ||
	   !pellets_create_compute_pipeline(vk_ctx, gpu.grid_prefix_shader.handle, gpu.grid_prefix_set_layout, &gpu.grid_prefix_pipeline) ||
	   !pellets_create_compute_pipeline(vk_ctx, gpu.grid_prefix_blocks_shader.handle, gpu.grid_prefix_set_layout, &gpu.grid_prefix_blocks_pipeline) ||
	   !pellets_create_compute_pipeline(vk_ctx, gpu.grid_prefix_add_shader.handle, gpu.grid_prefix_set_layout, &gpu.grid_prefix_add_pipeline) ||
	   !pellets_create_compute_pipeline(vk_ctx, gpu.grid_scatter_shader.handle, gpu.grid_scatter_set_layout, &gpu.grid_scatter_pipeline) ||
	   !pellets_create_compute_pipeline(vk_ctx, gpu.physics_shader.handle, gpu.physics_set_layout, &gpu.physics_pipeline) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !pellets_create_background_pipeline(gpu, vk_ctx) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !pellets_create_render_pipeline(gpu, vk_ctx) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !pellets_create_background_pipeline_for_pass(gpu, vk_ctx, &gpu.trail_background_pipeline) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !pellets_create_render_pipeline_for_pass(gpu, vk_ctx, &gpu.trail_particle_pipeline) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !pellets_create_fullscreen_pipeline(vk_ctx, gpu.trail_fade_vertex_shader, gpu.trail_fade_fragment_shader, gpu.trail_fade_set_layout, true, &gpu.trail_fade_pipeline) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !pellets_create_fullscreen_pipeline(vk_ctx, gpu.trail_blit_vertex_shader, gpu.trail_blit_fragment_shader, gpu.trail_blit_set_layout, true, &gpu.trail_blit_pipeline) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	gpu.ready = true
	return true
}

pellets_load_shaders :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	return engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_GRID_CLEAR_SHADER_SOURCE, PELLETS_GRID_CLEAR_FALLBACK_SPV, .Compute, PELLETS_SOURCE_ENTRY, &gpu.grid_clear_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_GRID_POPULATE_SHADER_SOURCE, PELLETS_GRID_POPULATE_FALLBACK_SPV, .Compute, PELLETS_SOURCE_ENTRY, &gpu.grid_populate_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_GRID_PREFIX_SHADER_SOURCE, PELLETS_GRID_PREFIX_FALLBACK_SPV, .Compute, PELLETS_SOURCE_ENTRY, &gpu.grid_prefix_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_GRID_PREFIX_BLOCKS_SHADER_SOURCE, PELLETS_GRID_PREFIX_BLOCKS_FALLBACK_SPV, .Compute, PELLETS_SOURCE_ENTRY, &gpu.grid_prefix_blocks_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_GRID_PREFIX_ADD_SHADER_SOURCE, PELLETS_GRID_PREFIX_ADD_FALLBACK_SPV, .Compute, PELLETS_SOURCE_ENTRY, &gpu.grid_prefix_add_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_GRID_SCATTER_SHADER_SOURCE, PELLETS_GRID_SCATTER_FALLBACK_SPV, .Compute, PELLETS_SOURCE_ENTRY, &gpu.grid_scatter_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_PHYSICS_SHADER_SOURCE, PELLETS_PHYSICS_FALLBACK_SPV, .Compute, PELLETS_SOURCE_ENTRY, &gpu.physics_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_BACKGROUND_SHADER_SOURCE, PELLETS_BACKGROUND_VERTEX_FALLBACK_SPV, .Vertex, PELLETS_VERTEX_SOURCE_ENTRY, &gpu.background_vertex_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_BACKGROUND_SHADER_SOURCE, PELLETS_BACKGROUND_FRAGMENT_FALLBACK_SPV, .Fragment, PELLETS_FRAGMENT_SOURCE_ENTRY, &gpu.background_fragment_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_RENDER_SHADER_SOURCE, PELLETS_RENDER_VERTEX_FALLBACK_SPV, .Vertex, PELLETS_VERTEX_SOURCE_ENTRY, &gpu.render_vertex_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_RENDER_SHADER_SOURCE, PELLETS_RENDER_FRAGMENT_FALLBACK_SPV, .Fragment, PELLETS_FRAGMENT_SOURCE_ENTRY, &gpu.render_fragment_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_TRAIL_FADE_VERTEX_SHADER_SOURCE, PELLETS_TRAIL_FADE_VERTEX_FALLBACK_SPV, .Vertex, PELLETS_VERTEX_SOURCE_ENTRY, &gpu.trail_fade_vertex_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_TRAIL_FADE_FRAGMENT_SHADER_SOURCE, PELLETS_TRAIL_FADE_FRAGMENT_FALLBACK_SPV, .Fragment, PELLETS_FRAGMENT_SOURCE_ENTRY, &gpu.trail_fade_fragment_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_TRAIL_BLIT_SHADER_SOURCE, PELLETS_TRAIL_BLIT_VERTEX_FALLBACK_SPV, .Vertex, PELLETS_VERTEX_SOURCE_ENTRY, &gpu.trail_blit_vertex_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_TRAIL_BLIT_SHADER_SOURCE, PELLETS_TRAIL_BLIT_FRAGMENT_FALLBACK_SPV, .Fragment, PELLETS_FRAGMENT_SOURCE_ENTRY, &gpu.trail_blit_fragment_shader)
}

pellets_initialize_particles :: proc(gpu: ^Pellets_Gpu_State, settings: ^Pellets_Settings) {
	if gpu.particle_buffer.mapped == nil {
		return
	}
	particles := (cast([^]Pellets_Particle)gpu.particle_buffer.mapped)[:gpu.particle_count]
	rng := settings.random_seed
	if rng == 0 {
		rng = 42
	}
	vmin := min(settings.initial_velocity_min, settings.initial_velocity_max)
	vmax := max(settings.initial_velocity_min, settings.initial_velocity_max)
	for i in 0 ..< int(gpu.particle_count) {
		x := pellets_next_random01(&rng) * 2 - 1
		y := pellets_next_random01(&rng) * 2 - 1
		angle := pellets_next_random01(&rng) * 2 * math.PI
		speed := vmin
		if vmax > vmin {
			speed = vmin + pellets_next_random01(&rng) * (vmax - vmin)
		}
		velocity := [2]f32{math.cos(angle) * speed, math.sin(angle) * speed}
		position := [2]f32{x, y}
		particles[i] = {
			position = position,
			velocity = velocity,
			mass = 1,
			radius = settings.particle_size,
			clump_id = 0,
			density = 0,
			grabbed = 0,
			_pad0 = 0,
			previous_position = {position.x - velocity.x * 0.016, position.y - velocity.y * 0.016},
		}
	}
	gpu.frame_index = 0
}

pellets_next_random01 :: proc(rng: ^u32) -> f32 {
	rng^ = rng^ ~ (rng^ << 13)
	rng^ = rng^ ~ (rng^ >> 17)
	rng^ = rng^ ~ (rng^ << 5)
	return f32(rng^) / f32(0xffffffff)
}

pellets_upload_lut :: proc(gpu: ^Pellets_Gpu_State, settings: ^Pellets_Settings) {
	if gpu.lut_buffer.mapped == nil {
		return
	}
	scheme := color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
	data := (cast([^]u32)gpu.lut_buffer.mapped)[:COLOR_SCHEME_U32_COUNT]
	_ = color_scheme_write_u32_buffer(scheme, data)
}

pellets_write_static_params :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int, settings: ^Pellets_Settings, camera: ^Camera_Control_State = nil) {
	pellets_write_static_params_size(gpu, frame_slot, f32(vk_ctx.swapchain_extent.width * 2), f32(vk_ctx.swapchain_extent.height * 2), settings, camera)
}

pellets_write_static_params_size :: proc(gpu: ^Pellets_Gpu_State, frame_slot: int, screen_width, screen_height: f32, settings: ^Pellets_Settings, camera: ^Camera_Control_State = nil) {
	camera_data := camera_uniform_data(camera, screen_width, screen_height)
	tile_count := infinite_render_tile_count(camera_data.zoom)
	if gpu.present_camera_valid &&
	   (gpu.present_camera_position != camera_data.position || gpu.present_camera_zoom != camera_data.zoom) {
		gpu.trail_initialized = false
	}
	gpu.present_camera_position = camera_data.position
	gpu.present_camera_zoom = camera_data.zoom
	gpu.present_camera_valid = true
	gpu.present_tile_count = tile_count
	if gpu.render_params_buffers[frame_slot].mapped != nil {
		params := cast(^Pellets_Render_Params)gpu.render_params_buffers[frame_slot].mapped
		params^ = {
			particle_size = settings.particle_size,
			screen_width = screen_width,
			screen_height = screen_height,
			foreground_color_mode = u32(settings.foreground_index),
			camera_position = camera_data.position,
			camera_zoom = camera_data.zoom,
			tile_count = tile_count,
		}
	}
	if gpu.background_params_buffers[frame_slot].mapped != nil {
		params := cast(^Pellets_Background_Params)gpu.background_params_buffers[frame_slot].mapped
		params^ = {
			background_color_mode = u32(settings.background_color_mode),
		}
	}
	if gpu.background_color_buffers[frame_slot].mapped != nil {
		color := cast(^[4]f32)gpu.background_color_buffers[frame_slot].mapped
		color^ = pellets_background_color(settings)
	}
	if gpu.grid_params_buffers[frame_slot].mapped != nil {
		params := cast(^Pellets_Grid_Params)gpu.grid_params_buffers[frame_slot].mapped
		params^ = {
			particle_count = gpu.particle_count,
			grid_width = gpu.grid_width,
			grid_height = gpu.grid_height,
			cell_size = gpu.cell_size,
			world_width = 2,
			world_height = 2,
		}
	}
}

pellets_write_physics_params :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int, sim: ^Remaining_Sim_State, dt: f32) {
	if gpu.physics_params_buffers[frame_slot].mapped == nil {
		return
	}
	settings := sim.pellets
	aspect := f32(vk_ctx.swapchain_extent.width) / max(f32(vk_ctx.swapchain_extent.height), 1)
	params := cast(^Pellets_Physics_Params)gpu.physics_params_buffers[frame_slot].mapped
	params^ = {
		mouse_position = sim.cursor_world,
		mouse_velocity = sim.cursor_world_velocity,
		particle_count = gpu.particle_count,
		gravitational_constant = settings.gravitational_constant,
		energy_damping = settings.energy_damping,
		collision_damping = settings.collision_damping,
		dt = dt,
		gravity_softening = settings.gravity_softening,
		interaction_radius = max(settings.particle_size * 3, settings.gravity_softening),
		mouse_pressed = sim.cursor_active != 0 ? u32(1) : u32(0),
		mouse_mode = sim.cursor_mode,
		cursor_size = sim.cursor_size,
		cursor_strength = sim.cursor_strength,
		particle_size = settings.particle_size,
		aspect_ratio = aspect,
		density_damping_enabled = settings.density_damping_enabled ? u32(1) : u32(0),
		overlap_resolution_strength = settings.overlap_resolution_strength,
		frame_index = gpu.frame_index,
		coloring_mode = u32(settings.foreground_color_mode),
		density_radius = settings.density_radius,
	}
}

pellets_create_descriptors :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	clear_bindings := [2]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	if !pellets_create_set_layout(vk_ctx, clear_bindings[:], &gpu.grid_clear_set_layout) {return false}
	populate_bindings := [3]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	if !pellets_create_set_layout(vk_ctx, populate_bindings[:], &gpu.grid_populate_set_layout) {return false}
	prefix_bindings := [5]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	if !pellets_create_set_layout(vk_ctx, prefix_bindings[:], &gpu.grid_prefix_set_layout) {return false}
	scatter_bindings := prefix_bindings
	if !pellets_create_set_layout(vk_ctx, scatter_bindings[:], &gpu.grid_scatter_set_layout) {return false}
	physics_bindings := [6]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 5, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	if !pellets_create_set_layout(vk_ctx, physics_bindings[:], &gpu.physics_set_layout) {return false}
	background_bindings := [2]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	if !pellets_create_set_layout(vk_ctx, background_bindings[:], &gpu.background_set_layout) {return false}
	render_bindings := [3]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX, .FRAGMENT}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX, .FRAGMENT}},
	}
	if !pellets_create_set_layout(vk_ctx, render_bindings[:], &gpu.render_set_layout) {return false}
	fade_bindings := [3]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	if !pellets_create_set_layout(vk_ctx, fade_bindings[:], &gpu.trail_fade_set_layout) {return false}
	blit_bindings := [2]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	if !pellets_create_set_layout(vk_ctx, blit_bindings[:], &gpu.trail_blit_set_layout) {return false}

	pool_sizes := [4]vk.DescriptorPoolSize{
		{type = .STORAGE_BUFFER, descriptorCount = 32 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .UNIFORM_BUFFER, descriptorCount = 11 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .SAMPLED_IMAGE, descriptorCount = 4 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .SAMPLER, descriptorCount = 4 * engine.MAX_FRAMES_IN_FLIGHT},
	}
	pool_info := vk.DescriptorPoolCreateInfo{sType = .DESCRIPTOR_POOL_CREATE_INFO, poolSizeCount = u32(len(pool_sizes)), pPoolSizes = raw_data(pool_sizes[:]), maxSets = 11 * engine.MAX_FRAMES_IN_FLIGHT}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &gpu.descriptor_pool) != .SUCCESS {return false}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		layouts := [11]vk.DescriptorSetLayout{
			gpu.grid_clear_set_layout,
			gpu.grid_populate_set_layout,
			gpu.grid_prefix_set_layout,
			gpu.grid_scatter_set_layout,
			gpu.physics_set_layout,
			gpu.background_set_layout,
			gpu.render_set_layout,
			gpu.trail_fade_set_layout,
			gpu.trail_fade_set_layout,
			gpu.trail_blit_set_layout,
			gpu.trail_blit_set_layout,
		}
		sets: [11]vk.DescriptorSet
		alloc := vk.DescriptorSetAllocateInfo{sType = .DESCRIPTOR_SET_ALLOCATE_INFO, descriptorPool = gpu.descriptor_pool, descriptorSetCount = u32(len(layouts)), pSetLayouts = raw_data(layouts[:])}
		if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(sets[:])) != .SUCCESS {return false}
		gpu.grid_clear_sets[frame_slot] = sets[0]
		gpu.grid_populate_sets[frame_slot] = sets[1]
		gpu.grid_prefix_sets[frame_slot] = sets[2]
		gpu.grid_scatter_sets[frame_slot] = sets[3]
		gpu.physics_sets[frame_slot] = sets[4]
		gpu.background_sets[frame_slot] = sets[5]
		gpu.render_sets[frame_slot] = sets[6]
		gpu.trail_fade_sets[frame_slot][0] = sets[7]
		gpu.trail_fade_sets[frame_slot][1] = sets[8]
		gpu.trail_blit_sets[frame_slot][0] = sets[9]
		gpu.trail_blit_sets[frame_slot][1] = sets[10]
	}
	pellets_update_descriptors(gpu, vk_ctx)
	return true
}

pellets_create_set_layout :: proc(vk_ctx: ^engine.Vk_Context, bindings: []vk.DescriptorSetLayoutBinding, out: ^vk.DescriptorSetLayout) -> bool {
	info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(bindings)), pBindings = raw_data(bindings)}
	return vk.CreateDescriptorSetLayout(vk_ctx.device, &info, nil, out) == .SUCCESS
}

pellets_update_descriptors :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		pellets_update_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	}
}

pellets_update_descriptors_for_slot :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	particle_info := vk.DescriptorBufferInfo{buffer = gpu.particle_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Pellets_Particle) * int(gpu.particle_count))}
	grid_info := vk.DescriptorBufferInfo{buffer = gpu.grid_buffer.handle, offset = 0, range = gpu.grid_buffer.size}
	counts_info := vk.DescriptorBufferInfo{buffer = gpu.grid_counts_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * int(gpu.grid_width * gpu.grid_height))}
	offsets_info := vk.DescriptorBufferInfo{buffer = gpu.grid_offsets_buffer.handle, offset = 0, range = gpu.grid_offsets_buffer.size}
	cursors_info := vk.DescriptorBufferInfo{buffer = gpu.grid_cursors_buffer.handle, offset = 0, range = gpu.grid_cursors_buffer.size}
	block_sums_info := vk.DescriptorBufferInfo{buffer = gpu.grid_block_sums_buffer.handle, offset = 0, range = gpu.grid_block_sums_buffer.size}
	physics_info := vk.DescriptorBufferInfo{buffer = gpu.physics_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Pellets_Physics_Params))}
	render_info := vk.DescriptorBufferInfo{buffer = gpu.render_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Pellets_Render_Params))}
	background_params_info := vk.DescriptorBufferInfo{buffer = gpu.background_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Pellets_Background_Params))}
	background_color_info := vk.DescriptorBufferInfo{buffer = gpu.background_color_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of([4]f32))}
	grid_params_info := vk.DescriptorBufferInfo{buffer = gpu.grid_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Pellets_Grid_Params))}
	lut_info := vk.DescriptorBufferInfo{buffer = gpu.lut_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT)}
	grid_clear_set := gpu.grid_clear_sets[frame_slot]
	grid_populate_set := gpu.grid_populate_sets[frame_slot]
	grid_prefix_set := gpu.grid_prefix_sets[frame_slot]
	grid_scatter_set := gpu.grid_scatter_sets[frame_slot]
	physics_set := gpu.physics_sets[frame_slot]
	background_set := gpu.background_sets[frame_slot]
	render_set := gpu.render_sets[frame_slot]
	writes := [?]vk.WriteDescriptorSet{
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_clear_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &counts_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_clear_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &grid_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_populate_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_populate_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &grid_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_populate_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &counts_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_prefix_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &counts_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_prefix_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &grid_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_prefix_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &offsets_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_prefix_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &cursors_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_prefix_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &block_sums_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_scatter_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_scatter_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &grid_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_scatter_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &offsets_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_scatter_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &cursors_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = grid_scatter_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = physics_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = physics_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &physics_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = physics_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = physics_set, dstBinding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &grid_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = physics_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &counts_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = physics_set, dstBinding = 5, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &offsets_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = background_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &background_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = background_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &background_color_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = render_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = render_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &render_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = render_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &lut_info},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
}

pellets_create_compute_pipeline :: proc(vk_ctx: ^engine.Vk_Context, shader: vk.ShaderModule, set_layout: vk.DescriptorSetLayout, out: ^engine.Vk_Compute_Pipeline) -> bool {
	layouts := [1]vk.DescriptorSetLayout{set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &out.layout) != .SUCCESS {return false}
	stage := vk.PipelineShaderStageCreateInfo{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.COMPUTE}, module = shader, pName = PELLETS_ENTRY}
	info := vk.ComputePipelineCreateInfo{sType = .COMPUTE_PIPELINE_CREATE_INFO, stage = stage, layout = out.layout}
	return vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &out.pipeline) == .SUCCESS
}

pellets_create_background_pipeline :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	return pellets_create_background_pipeline_for_pass(gpu, vk_ctx, &gpu.background_pipeline)
}

pellets_create_background_pipeline_for_pass :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, out: ^engine.Vk_Graphics_Pipeline) -> bool {
	layouts := [1]vk.DescriptorSetLayout{gpu.background_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &out.layout) != .SUCCESS {return false}
	stages := [2]vk.PipelineShaderStageCreateInfo{
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = gpu.background_vertex_shader.handle, pName = PELLETS_VERTEX_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = gpu.background_fragment_shader.handle, pName = PELLETS_FRAGMENT_ENTRY},
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
	rendering := engine.vk_pipeline_rendering_info(&vk_ctx.swapchain_format)
	info := vk.GraphicsPipelineCreateInfo{sType = .GRAPHICS_PIPELINE_CREATE_INFO, pNext = &rendering, stageCount = 2, pStages = raw_data(stages[:]), pVertexInputState = &vertex_input, pInputAssemblyState = &input_assembly, pViewportState = &viewport_state, pRasterizationState = &raster, pMultisampleState = &multisample, pColorBlendState = &blend, pDynamicState = &dynamic_state, layout = out.layout}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &out.pipeline) == .SUCCESS
}

pellets_create_render_pipeline :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	return pellets_create_render_pipeline_for_pass(gpu, vk_ctx, &gpu.render_pipeline)
}

pellets_create_render_pipeline_for_pass :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, out: ^engine.Vk_Graphics_Pipeline) -> bool {
	layouts := [1]vk.DescriptorSetLayout{gpu.render_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &out.layout) != .SUCCESS {return false}
	stages := [2]vk.PipelineShaderStageCreateInfo{
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = gpu.render_vertex_shader.handle, pName = PELLETS_VERTEX_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = gpu.render_fragment_shader.handle, pName = PELLETS_FRAGMENT_ENTRY},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState{blendEnable = true, srcColorBlendFactor = .SRC_ALPHA, dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA, colorBlendOp = .ADD, srcAlphaBlendFactor = .ONE, dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA, alphaBlendOp = .ADD, colorWriteMask = {.R, .G, .B, .A}}
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = 2, pDynamicStates = raw_data(dynamic_states[:])}
	rendering := engine.vk_pipeline_rendering_info(&vk_ctx.swapchain_format)
	info := vk.GraphicsPipelineCreateInfo{sType = .GRAPHICS_PIPELINE_CREATE_INFO, pNext = &rendering, stageCount = 2, pStages = raw_data(stages[:]), pVertexInputState = &vertex_input, pInputAssemblyState = &input_assembly, pViewportState = &viewport_state, pRasterizationState = &raster, pMultisampleState = &multisample, pColorBlendState = &blend, pDynamicState = &dynamic_state, layout = out.layout}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &out.pipeline) == .SUCCESS
}

pellets_create_fullscreen_pipeline :: proc(vk_ctx: ^engine.Vk_Context, vertex_module, fragment_module: engine.Vk_Shader_Module, set_layout: vk.DescriptorSetLayout, blend_enabled: bool, out: ^engine.Vk_Graphics_Pipeline) -> bool {
	layouts := [1]vk.DescriptorSetLayout{set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &out.layout) != .SUCCESS {return false}
	stages := [2]vk.PipelineShaderStageCreateInfo{
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = vertex_module.handle, pName = PELLETS_VERTEX_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = fragment_module.handle, pName = PELLETS_FRAGMENT_ENTRY},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState{blendEnable = b32(blend_enabled), srcColorBlendFactor = .SRC_ALPHA, dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA, colorBlendOp = .ADD, srcAlphaBlendFactor = .ONE, dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA, alphaBlendOp = .ADD, colorWriteMask = {.R, .G, .B, .A}}
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = 2, pDynamicStates = raw_data(dynamic_states[:])}
	rendering := engine.vk_pipeline_rendering_info(&vk_ctx.swapchain_format)
	info := vk.GraphicsPipelineCreateInfo{sType = .GRAPHICS_PIPELINE_CREATE_INFO, pNext = &rendering, stageCount = 2, pStages = raw_data(stages[:]), pVertexInputState = &vertex_input, pInputAssemblyState = &input_assembly, pViewportState = &viewport_state, pRasterizationState = &raster, pMultisampleState = &multisample, pColorBlendState = &blend, pDynamicState = &dynamic_state, layout = out.layout}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &out.pipeline) == .SUCCESS
}

pellets_create_sampler :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	info := vk.SamplerCreateInfo{sType = .SAMPLER_CREATE_INFO, magFilter = .LINEAR, minFilter = .LINEAR, mipmapMode = .LINEAR, addressModeU = .CLAMP_TO_EDGE, addressModeV = .CLAMP_TO_EDGE, addressModeW = .CLAMP_TO_EDGE, minLod = 0, maxLod = 1}
	return vk.CreateSampler(vk_ctx.device, &info, nil, &gpu.trail_sampler) == .SUCCESS
}

pellets_create_trail_image :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, index: int, width, height: u32) -> bool {
	image := &gpu.trail_images[index]
	image_info := vk.ImageCreateInfo{sType = .IMAGE_CREATE_INFO, imageType = .D2, format = vk_ctx.swapchain_format, extent = {width, height, 1}, mipLevels = 1, arrayLayers = 1, samples = {._1}, tiling = .OPTIMAL, usage = {.COLOR_ATTACHMENT, .SAMPLED, .TRANSFER_SRC, .TRANSFER_DST}, sharingMode = .EXCLUSIVE, initialLayout = .UNDEFINED}
	if vk.CreateImage(vk_ctx.device, &image_info, nil, &image.handle) != .SUCCESS {
		return false
	}
	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device, image.handle, &req)
	memory_type, ok := engine.vk_find_memory_type(vk_ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {
		return false
	}
	alloc := vk.MemoryAllocateInfo{sType = .MEMORY_ALLOCATE_INFO, allocationSize = req.size, memoryTypeIndex = memory_type}
	if !engine.vk_allocate_memory_checked(vk_ctx, &alloc, "pellets image", &image.memory) {
		return false
	}
	if vk.BindImageMemory(vk_ctx.device, image.handle, image.memory, 0) != .SUCCESS {
		return false
	}
	view_info := vk.ImageViewCreateInfo{sType = .IMAGE_VIEW_CREATE_INFO, image = image.handle, viewType = .D2, format = vk_ctx.swapchain_format, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	if vk.CreateImageView(vk_ctx.device, &view_info, nil, &image.view) != .SUCCESS {
		return false
	}
	image.layout = .UNDEFINED
	return true
}

pellets_destroy_trail_image :: proc(vk_ctx: ^engine.Vk_Context, image: ^Pellets_Trail_Image) {
	if image.view != vk.ImageView(0) {vk.DestroyImageView(vk_ctx.device, image.view, nil)}
	if image.handle != vk.Image(0) {vk.DestroyImage(vk_ctx.device, image.handle, nil)}
	if image.memory != vk.DeviceMemory(0) {vk.FreeMemory(vk_ctx.device, image.memory, nil)}
	image^ = {}
}

pellets_destroy_trail_targets :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	for i in 0 ..< len(gpu.trail_images) {
		pellets_destroy_trail_image(vk_ctx, &gpu.trail_images[i])
	}
	gpu.trail_width = 0
	gpu.trail_height = 0
	gpu.trail_initialized = false
	gpu.trail_write_index = 0
}

pellets_frame_slot_mask :: proc() -> u32 {
	return (u32(1) << u32(engine.MAX_FRAMES_IN_FLIGHT)) - 1
}

pellets_collect_retired_trail_targets :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	bit := u32(1) << u32(frame_slot)
	for i in 0 ..< PELLETS_RETIRED_TRAIL_TARGET_CAP {
		retired := &gpu.retired_trail_targets[i]
		if retired.pending_frame_slots == 0 {
			continue
		}
		retired.pending_frame_slots = retired.pending_frame_slots & (~bit)
		if retired.pending_frame_slots == 0 {
			for image_index in 0 ..< len(retired.images) {
				pellets_destroy_trail_image(vk_ctx, &retired.images[image_index])
			}
		}
	}
}

pellets_retire_trail_targets :: proc(gpu: ^Pellets_Gpu_State) -> bool {
	if gpu.trail_images[0].handle == vk.Image(0) && gpu.trail_images[1].handle == vk.Image(0) {
		gpu.trail_images = {}
		gpu.trail_width = 0
		gpu.trail_height = 0
		gpu.trail_initialized = false
		gpu.trail_write_index = 0
		return true
	}
	for i in 0 ..< PELLETS_RETIRED_TRAIL_TARGET_CAP {
		retired := &gpu.retired_trail_targets[i]
		if retired.pending_frame_slots == 0 {
			retired.images = gpu.trail_images
			retired.pending_frame_slots = pellets_frame_slot_mask()
			gpu.trail_images = {}
			gpu.trail_width = 0
			gpu.trail_height = 0
			gpu.trail_initialized = false
			gpu.trail_write_index = 0
			return true
		}
	}
	engine.log_warn("pellets: trail target retire slots exhausted")
	return false
}

pellets_update_trail_descriptors :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		pellets_update_trail_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	}
}

pellets_update_trail_descriptors_for_slot :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	fade_info := vk.DescriptorBufferInfo{buffer = gpu.trail_fade_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Pellets_Fade_Params))}
	sampler_info := vk.DescriptorImageInfo{sampler = gpu.trail_sampler}
	for i in 0 ..< len(gpu.trail_images) {
		image_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.trail_images[i].view}
		fade_set := gpu.trail_fade_sets[frame_slot][i]
		blit_set := gpu.trail_blit_sets[frame_slot][i]
		fade_writes := [3]vk.WriteDescriptorSet{
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = fade_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &fade_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = fade_set, dstBinding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = fade_set, dstBinding = 2, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
		}
		blit_writes := [2]vk.WriteDescriptorSet{
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = blit_set, dstBinding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = blit_set, dstBinding = 1, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
		}
		vk.UpdateDescriptorSets(vk_ctx.device, u32(len(fade_writes)), raw_data(fade_writes[:]), 0, nil)
		vk.UpdateDescriptorSets(vk_ctx.device, u32(len(blit_writes)), raw_data(blit_writes[:]), 0, nil)
	}
}

pellets_ensure_trail_targets :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	width := max(vk_ctx.swapchain_extent.width, u32(1))
	height := max(vk_ctx.swapchain_extent.height, u32(1))
	if gpu.trail_width == width && gpu.trail_height == height && gpu.trail_images[0].handle != vk.Image(0) && gpu.trail_images[1].handle != vk.Image(0) {
		return true
	}
	if !pellets_retire_trail_targets(gpu) {
		return false
	}
	for i in 0 ..< len(gpu.trail_images) {
		if !pellets_create_trail_image(gpu, vk_ctx, i, width, height) {
			pellets_destroy_trail_targets(gpu, vk_ctx)
			return false
		}
	}
	gpu.trail_width = width
	gpu.trail_height = height
	frame_slot := int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	pellets_update_trail_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	pellets_collect_retired_trail_targets(gpu, vk_ctx, frame_slot)
	return true
}
