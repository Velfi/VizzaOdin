package game

import engine "../engine"
import uifw "../ui"

import "core:math"
import vk "vendor:vulkan"

PELLETS_GRID_CLEAR_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/grid_clear.slang"
PELLETS_GRID_POPULATE_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/grid_populate.slang"
PELLETS_PHYSICS_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/physics_compute.slang"
PELLETS_DENSITY_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/density_compute.slang"
PELLETS_BACKGROUND_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/background_render.slang"
PELLETS_RENDER_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/particle_render.slang"
PELLETS_TRAIL_FADE_VERTEX_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/trail_fade_vertex.slang"
PELLETS_TRAIL_FADE_FRAGMENT_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/trail_fade_fragment.slang"
PELLETS_TRAIL_BLIT_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/trail_blit.slang"
PELLETS_GRID_CLEAR_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/grid_clear"
PELLETS_GRID_POPULATE_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/grid_populate"
PELLETS_PHYSICS_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/physics_compute"
PELLETS_DENSITY_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/density_compute"
PELLETS_BACKGROUND_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/background_render_vertex"
PELLETS_BACKGROUND_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/background_render_fragment"
PELLETS_RENDER_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/particle_render_vertex"
PELLETS_RENDER_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/particle_render_fragment"
PELLETS_TRAIL_FADE_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/trail_fade_vertex"
PELLETS_TRAIL_FADE_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/trail_fade_fragment"
PELLETS_TRAIL_BLIT_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/trail_blit_vertex"
PELLETS_TRAIL_BLIT_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/trail_blit_fragment"
PELLETS_SOURCE_ENTRY :: "main"
PELLETS_VERTEX_SOURCE_ENTRY :: "vs_main"
PELLETS_FRAGMENT_SOURCE_ENTRY :: "fs_main"
PELLETS_ENTRY :: cstring("main")
PELLETS_VERTEX_ENTRY :: cstring("main")
PELLETS_FRAGMENT_ENTRY :: cstring("main")
PELLETS_WORKGROUP_SIZE :: u32(64)
PELLETS_GRID_CELL_CAPACITY :: 64

Pellets_Particle :: struct #align(8) {
	position: [2]f32,
	velocity: [2]f32,
	mass: f32,
	radius: f32,
	clump_id: u32,
	density: f32,
	grabbed: u32,
	_pad0: u32,
	previous_position: [2]f32,
}

Pellets_Physics_Params :: struct #align(16) {
	mouse_position: [2]f32,
	mouse_velocity: [2]f32,
	particle_count: u32,
	gravitational_constant: f32,
	energy_damping: f32,
	collision_damping: f32,
	dt: f32,
	gravity_softening: f32,
	interaction_radius: f32,
	mouse_pressed: u32,
	mouse_mode: u32,
	cursor_size: f32,
	cursor_strength: f32,
	particle_size: f32,
	aspect_ratio: f32,
	density_damping_enabled: u32,
	overlap_resolution_strength: f32,
	frame_index: u32,
}

Pellets_Density_Params :: struct #align(16) {
	particle_count: u32,
	density_radius: f32,
	coloring_mode: u32,
	_padding: u32,
}

Pellets_Render_Params :: struct #align(16) {
	particle_size: f32,
	screen_width: f32,
	screen_height: f32,
	foreground_color_mode: u32,
}

Pellets_Background_Params :: struct #align(16) {
	background_color_mode: u32,
	_pad0: [3]u32,
}

Pellets_Grid_Params :: struct #align(16) {
	particle_count: u32,
	grid_width: u32,
	grid_height: u32,
	cell_size: f32,
	world_width: f32,
	world_height: f32,
	_pad1: u32,
	_pad2: u32,
}

Pellets_Grid_Cell :: struct #align(4) {
	particle_count: u32,
	particle_indices: [PELLETS_GRID_CELL_CAPACITY]u32,
}

Pellets_Fade_Params :: struct #align(16) {
	fade_amount: f32,
	_pad0: [3]f32,
}

Pellets_Trail_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	framebuffer: vk.Framebuffer,
	layout: vk.ImageLayout,
}

Pellets_Gpu_State :: struct {
	grid_clear_shader: engine.Vk_Shader_Module,
	grid_populate_shader: engine.Vk_Shader_Module,
	physics_shader: engine.Vk_Shader_Module,
	density_shader: engine.Vk_Shader_Module,
	background_vertex_shader: engine.Vk_Shader_Module,
	background_fragment_shader: engine.Vk_Shader_Module,
	render_vertex_shader: engine.Vk_Shader_Module,
	render_fragment_shader: engine.Vk_Shader_Module,
	trail_fade_vertex_shader: engine.Vk_Shader_Module,
	trail_fade_fragment_shader: engine.Vk_Shader_Module,
	trail_blit_vertex_shader: engine.Vk_Shader_Module,
	trail_blit_fragment_shader: engine.Vk_Shader_Module,
	grid_clear_pipeline: engine.Vk_Compute_Pipeline,
	grid_populate_pipeline: engine.Vk_Compute_Pipeline,
	physics_pipeline: engine.Vk_Compute_Pipeline,
	density_pipeline: engine.Vk_Compute_Pipeline,
	background_pipeline: engine.Vk_Graphics_Pipeline,
	render_pipeline: engine.Vk_Graphics_Pipeline,
	trail_background_pipeline: engine.Vk_Graphics_Pipeline,
	trail_particle_pipeline: engine.Vk_Graphics_Pipeline,
	trail_fade_pipeline: engine.Vk_Graphics_Pipeline,
	trail_blit_pipeline: engine.Vk_Graphics_Pipeline,
	grid_clear_set_layout: vk.DescriptorSetLayout,
	grid_populate_set_layout: vk.DescriptorSetLayout,
	physics_set_layout: vk.DescriptorSetLayout,
	density_set_layout: vk.DescriptorSetLayout,
	background_set_layout: vk.DescriptorSetLayout,
	render_set_layout: vk.DescriptorSetLayout,
	trail_fade_set_layout: vk.DescriptorSetLayout,
	trail_blit_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	grid_clear_set: vk.DescriptorSet,
	grid_populate_set: vk.DescriptorSet,
	physics_set: vk.DescriptorSet,
	density_set: vk.DescriptorSet,
	background_set: vk.DescriptorSet,
	render_set: vk.DescriptorSet,
	trail_fade_sets: [2]vk.DescriptorSet,
	trail_blit_sets: [2]vk.DescriptorSet,
	particle_buffer: engine.Vk_Buffer,
	physics_params_buffer: engine.Vk_Buffer,
	density_params_buffer: engine.Vk_Buffer,
	background_params_buffer: engine.Vk_Buffer,
	background_color_buffer: engine.Vk_Buffer,
	render_params_buffer: engine.Vk_Buffer,
	trail_fade_params_buffer: engine.Vk_Buffer,
	grid_buffer: engine.Vk_Buffer,
	grid_params_buffer: engine.Vk_Buffer,
	grid_counts_buffer: engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	trail_render_pass: vk.RenderPass,
	trail_images: [2]Pellets_Trail_Image,
	trail_sampler: vk.Sampler,
	trail_width: u32,
	trail_height: u32,
	trail_initialized: bool,
	trail_write_index: u32,
	particle_count: u32,
	grid_width: u32,
	grid_height: u32,
	cell_size: f32,
	frame_index: u32,
	ready: bool,
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
	grid_size := vk.DeviceSize(size_of(Pellets_Grid_Cell) * int(total_cells))
	if !engine.vk_create_host_buffer(vk_ctx, grid_size, {.STORAGE_BUFFER}, &gpu.grid_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(total_cells)), {.STORAGE_BUFFER}, &gpu.grid_counts_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Pellets_Physics_Params)), {.UNIFORM_BUFFER}, &gpu.physics_params_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Pellets_Density_Params)), {.UNIFORM_BUFFER}, &gpu.density_params_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Pellets_Render_Params)), {.UNIFORM_BUFFER}, &gpu.render_params_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Pellets_Fade_Params)), {.UNIFORM_BUFFER}, &gpu.trail_fade_params_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Pellets_Background_Params)), {.UNIFORM_BUFFER}, &gpu.background_params_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of([4]f32)), {.UNIFORM_BUFFER}, &gpu.background_color_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Pellets_Grid_Params)), {.UNIFORM_BUFFER}, &gpu.grid_params_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT), {.STORAGE_BUFFER}, &gpu.lut_buffer) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	pellets_initialize_particles(gpu, settings)
	pellets_write_static_params(gpu, vk_ctx, settings)
	if !pellets_create_trail_render_pass(gpu, vk_ctx) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
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
	   !pellets_create_compute_pipeline(vk_ctx, gpu.physics_shader.handle, gpu.physics_set_layout, &gpu.physics_pipeline) ||
	   !pellets_create_compute_pipeline(vk_ctx, gpu.density_shader.handle, gpu.density_set_layout, &gpu.density_pipeline) {
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
	if !pellets_create_background_pipeline_for_pass(gpu, vk_ctx, gpu.trail_render_pass, &gpu.trail_background_pipeline) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !pellets_create_render_pipeline_for_pass(gpu, vk_ctx, gpu.trail_render_pass, &gpu.trail_particle_pipeline) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !pellets_create_fullscreen_pipeline(vk_ctx, gpu.trail_fade_vertex_shader, gpu.trail_fade_fragment_shader, gpu.trail_render_pass, gpu.trail_fade_set_layout, true, &gpu.trail_fade_pipeline) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	if !pellets_create_fullscreen_pipeline(vk_ctx, gpu.trail_blit_vertex_shader, gpu.trail_blit_fragment_shader, vk_ctx.render_pass, gpu.trail_blit_set_layout, true, &gpu.trail_blit_pipeline) {
		pellets_gpu_destroy(gpu, vk_ctx)
		return false
	}
	gpu.ready = true
	return true
}

pellets_load_shaders :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	return engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_GRID_CLEAR_SHADER_SOURCE, PELLETS_GRID_CLEAR_FALLBACK_SPV, .Compute, PELLETS_SOURCE_ENTRY, &gpu.grid_clear_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_GRID_POPULATE_SHADER_SOURCE, PELLETS_GRID_POPULATE_FALLBACK_SPV, .Compute, PELLETS_SOURCE_ENTRY, &gpu.grid_populate_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_PHYSICS_SHADER_SOURCE, PELLETS_PHYSICS_FALLBACK_SPV, .Compute, PELLETS_SOURCE_ENTRY, &gpu.physics_shader) &&
	       engine.vk_load_shader_module_with_fallback(vk_ctx, PELLETS_DENSITY_SHADER_SOURCE, PELLETS_DENSITY_FALLBACK_SPV, .Compute, PELLETS_SOURCE_ENTRY, &gpu.density_shader) &&
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

pellets_write_static_params :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^Pellets_Settings) {
	pellets_write_static_params_size(gpu, f32(vk_ctx.swapchain_extent.width * 2), f32(vk_ctx.swapchain_extent.height * 2), settings)
}

pellets_write_static_params_size :: proc(gpu: ^Pellets_Gpu_State, screen_width, screen_height: f32, settings: ^Pellets_Settings) {
	if gpu.render_params_buffer.mapped != nil {
		params := cast(^Pellets_Render_Params)gpu.render_params_buffer.mapped
		params^ = {
			particle_size = settings.particle_size,
			screen_width = screen_width,
			screen_height = screen_height,
			foreground_color_mode = u32(settings.foreground_index),
		}
	}
	if gpu.density_params_buffer.mapped != nil {
		params := cast(^Pellets_Density_Params)gpu.density_params_buffer.mapped
		params^ = {
			particle_count = gpu.particle_count,
			density_radius = settings.density_radius,
			coloring_mode = u32(settings.foreground_index),
		}
	}
	if gpu.background_params_buffer.mapped != nil {
		params := cast(^Pellets_Background_Params)gpu.background_params_buffer.mapped
		params^ = {
			background_color_mode = u32(settings.background_color_mode),
		}
	}
	if gpu.background_color_buffer.mapped != nil {
		scheme := color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
		color := cast(^[4]f32)gpu.background_color_buffer.mapped
		color^ = color_scheme_color_at(scheme, 0)
	}
	if gpu.grid_params_buffer.mapped != nil {
		params := cast(^Pellets_Grid_Params)gpu.grid_params_buffer.mapped
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

pellets_write_physics_params :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, sim: ^Remaining_Sim_State, dt: f32) {
	if gpu.physics_params_buffer.mapped == nil {
		return
	}
	settings := &sim.pellets
	aspect := f32(vk_ctx.swapchain_extent.width) / max(f32(vk_ctx.swapchain_extent.height), 1)
	params := cast(^Pellets_Physics_Params)gpu.physics_params_buffer.mapped
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
	}
}

pellets_create_descriptors :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	clear_bindings := [3]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	if !pellets_create_set_layout(vk_ctx, clear_bindings[:], &gpu.grid_clear_set_layout) {return false}
	populate_bindings := [4]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	if !pellets_create_set_layout(vk_ctx, populate_bindings[:], &gpu.grid_populate_set_layout) {return false}
	physics_bindings := [5]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	if !pellets_create_set_layout(vk_ctx, physics_bindings[:], &gpu.physics_set_layout) {return false}
	density_bindings := [2]vk.DescriptorSetLayoutBinding{
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	if !pellets_create_set_layout(vk_ctx, density_bindings[:], &gpu.density_set_layout) {return false}
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
		{type = .STORAGE_BUFFER, descriptorCount = 12},
		{type = .UNIFORM_BUFFER, descriptorCount = 11},
		{type = .SAMPLED_IMAGE, descriptorCount = 4},
		{type = .SAMPLER, descriptorCount = 4},
	}
	pool_info := vk.DescriptorPoolCreateInfo{sType = .DESCRIPTOR_POOL_CREATE_INFO, poolSizeCount = u32(len(pool_sizes)), pPoolSizes = raw_data(pool_sizes[:]), maxSets = 10}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &gpu.descriptor_pool) != .SUCCESS {return false}
	layouts := [10]vk.DescriptorSetLayout{
		gpu.grid_clear_set_layout,
		gpu.grid_populate_set_layout,
		gpu.physics_set_layout,
		gpu.density_set_layout,
		gpu.background_set_layout,
		gpu.render_set_layout,
		gpu.trail_fade_set_layout,
		gpu.trail_fade_set_layout,
		gpu.trail_blit_set_layout,
		gpu.trail_blit_set_layout,
	}
	sets: [10]vk.DescriptorSet
	alloc := vk.DescriptorSetAllocateInfo{sType = .DESCRIPTOR_SET_ALLOCATE_INFO, descriptorPool = gpu.descriptor_pool, descriptorSetCount = u32(len(layouts)), pSetLayouts = raw_data(layouts[:])}
	if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(sets[:])) != .SUCCESS {return false}
	gpu.grid_clear_set = sets[0]
	gpu.grid_populate_set = sets[1]
	gpu.physics_set = sets[2]
	gpu.density_set = sets[3]
	gpu.background_set = sets[4]
	gpu.render_set = sets[5]
	gpu.trail_fade_sets[0] = sets[6]
	gpu.trail_fade_sets[1] = sets[7]
	gpu.trail_blit_sets[0] = sets[8]
	gpu.trail_blit_sets[1] = sets[9]
	pellets_update_descriptors(gpu, vk_ctx)
	return true
}

pellets_create_set_layout :: proc(vk_ctx: ^engine.Vk_Context, bindings: []vk.DescriptorSetLayoutBinding, out: ^vk.DescriptorSetLayout) -> bool {
	info := vk.DescriptorSetLayoutCreateInfo{sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount = u32(len(bindings)), pBindings = raw_data(bindings)}
	return vk.CreateDescriptorSetLayout(vk_ctx.device, &info, nil, out) == .SUCCESS
}

pellets_update_descriptors :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	particle_info := vk.DescriptorBufferInfo{buffer = gpu.particle_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Pellets_Particle) * int(gpu.particle_count))}
	grid_info := vk.DescriptorBufferInfo{buffer = gpu.grid_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Pellets_Grid_Cell) * int(gpu.grid_width * gpu.grid_height))}
	counts_info := vk.DescriptorBufferInfo{buffer = gpu.grid_counts_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * int(gpu.grid_width * gpu.grid_height))}
	physics_info := vk.DescriptorBufferInfo{buffer = gpu.physics_params_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Pellets_Physics_Params))}
	density_info := vk.DescriptorBufferInfo{buffer = gpu.density_params_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Pellets_Density_Params))}
	render_info := vk.DescriptorBufferInfo{buffer = gpu.render_params_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Pellets_Render_Params))}
	background_params_info := vk.DescriptorBufferInfo{buffer = gpu.background_params_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Pellets_Background_Params))}
	background_color_info := vk.DescriptorBufferInfo{buffer = gpu.background_color_buffer.handle, offset = 0, range = vk.DeviceSize(size_of([4]f32))}
	grid_params_info := vk.DescriptorBufferInfo{buffer = gpu.grid_params_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Pellets_Grid_Params))}
	lut_info := vk.DescriptorBufferInfo{buffer = gpu.lut_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(u32) * COLOR_SCHEME_U32_COUNT)}
	writes := [?]vk.WriteDescriptorSet{
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.grid_clear_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.grid_clear_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &grid_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.grid_clear_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &counts_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.grid_populate_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.grid_populate_set, dstBinding = 1, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.grid_populate_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &grid_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.grid_populate_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &counts_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.physics_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.physics_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &physics_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.physics_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.physics_set, dstBinding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &grid_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.physics_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &counts_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.density_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.density_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &density_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.background_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &background_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.background_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &background_color_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.render_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.render_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &render_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.render_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &lut_info},
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
	return pellets_create_background_pipeline_for_pass(gpu, vk_ctx, vk_ctx.render_pass, &gpu.background_pipeline)
}

pellets_create_background_pipeline_for_pass :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, render_pass: vk.RenderPass, out: ^engine.Vk_Graphics_Pipeline) -> bool {
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
	info := vk.GraphicsPipelineCreateInfo{sType = .GRAPHICS_PIPELINE_CREATE_INFO, stageCount = 2, pStages = raw_data(stages[:]), pVertexInputState = &vertex_input, pInputAssemblyState = &input_assembly, pViewportState = &viewport_state, pRasterizationState = &raster, pMultisampleState = &multisample, pColorBlendState = &blend, pDynamicState = &dynamic_state, layout = out.layout, renderPass = render_pass, subpass = 0}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &out.pipeline) == .SUCCESS
}

pellets_create_render_pipeline :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	return pellets_create_render_pipeline_for_pass(gpu, vk_ctx, vk_ctx.render_pass, &gpu.render_pipeline)
}

pellets_create_render_pipeline_for_pass :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, render_pass: vk.RenderPass, out: ^engine.Vk_Graphics_Pipeline) -> bool {
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
	info := vk.GraphicsPipelineCreateInfo{sType = .GRAPHICS_PIPELINE_CREATE_INFO, stageCount = 2, pStages = raw_data(stages[:]), pVertexInputState = &vertex_input, pInputAssemblyState = &input_assembly, pViewportState = &viewport_state, pRasterizationState = &raster, pMultisampleState = &multisample, pColorBlendState = &blend, pDynamicState = &dynamic_state, layout = out.layout, renderPass = render_pass, subpass = 0}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &out.pipeline) == .SUCCESS
}

pellets_create_fullscreen_pipeline :: proc(vk_ctx: ^engine.Vk_Context, vertex_module, fragment_module: engine.Vk_Shader_Module, render_pass: vk.RenderPass, set_layout: vk.DescriptorSetLayout, blend_enabled: bool, out: ^engine.Vk_Graphics_Pipeline) -> bool {
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
	info := vk.GraphicsPipelineCreateInfo{sType = .GRAPHICS_PIPELINE_CREATE_INFO, stageCount = 2, pStages = raw_data(stages[:]), pVertexInputState = &vertex_input, pInputAssemblyState = &input_assembly, pViewportState = &viewport_state, pRasterizationState = &raster, pMultisampleState = &multisample, pColorBlendState = &blend, pDynamicState = &dynamic_state, layout = out.layout, renderPass = render_pass, subpass = 0}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &out.pipeline) == .SUCCESS
}

pellets_create_trail_render_pass :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	attachment := vk.AttachmentDescription{format = vk_ctx.swapchain_format, samples = {._1}, loadOp = .CLEAR, storeOp = .STORE, stencilLoadOp = .DONT_CARE, stencilStoreOp = .DONT_CARE, initialLayout = .COLOR_ATTACHMENT_OPTIMAL, finalLayout = .COLOR_ATTACHMENT_OPTIMAL}
	color_ref := vk.AttachmentReference{attachment = 0, layout = .COLOR_ATTACHMENT_OPTIMAL}
	subpass := vk.SubpassDescription{pipelineBindPoint = .GRAPHICS, colorAttachmentCount = 1, pColorAttachments = &color_ref}
	dependency := vk.SubpassDependency{srcSubpass = vk.SUBPASS_EXTERNAL, dstSubpass = 0, srcStageMask = {.COLOR_ATTACHMENT_OUTPUT}, dstStageMask = {.COLOR_ATTACHMENT_OUTPUT}, dstAccessMask = {.COLOR_ATTACHMENT_WRITE}, dependencyFlags = {.BY_REGION}}
	info := vk.RenderPassCreateInfo{sType = .RENDER_PASS_CREATE_INFO, attachmentCount = 1, pAttachments = &attachment, subpassCount = 1, pSubpasses = &subpass, dependencyCount = 1, pDependencies = &dependency}
	return vk.CreateRenderPass(vk_ctx.device, &info, nil, &gpu.trail_render_pass) == .SUCCESS
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
	if vk.AllocateMemory(vk_ctx.device, &alloc, nil, &image.memory) != .SUCCESS {
		return false
	}
	if vk.BindImageMemory(vk_ctx.device, image.handle, image.memory, 0) != .SUCCESS {
		return false
	}
	view_info := vk.ImageViewCreateInfo{sType = .IMAGE_VIEW_CREATE_INFO, image = image.handle, viewType = .D2, format = vk_ctx.swapchain_format, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	if vk.CreateImageView(vk_ctx.device, &view_info, nil, &image.view) != .SUCCESS {
		return false
	}
	attachment := image.view
	framebuffer_info := vk.FramebufferCreateInfo{sType = .FRAMEBUFFER_CREATE_INFO, renderPass = gpu.trail_render_pass, attachmentCount = 1, pAttachments = &attachment, width = width, height = height, layers = 1}
	if vk.CreateFramebuffer(vk_ctx.device, &framebuffer_info, nil, &image.framebuffer) != .SUCCESS {
		return false
	}
	image.layout = .UNDEFINED
	return true
}

pellets_destroy_trail_targets :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	for i in 0 ..< len(gpu.trail_images) {
		image := &gpu.trail_images[i]
		if image.framebuffer != vk.Framebuffer(0) {vk.DestroyFramebuffer(vk_ctx.device, image.framebuffer, nil)}
		if image.view != vk.ImageView(0) {vk.DestroyImageView(vk_ctx.device, image.view, nil)}
		if image.handle != vk.Image(0) {vk.DestroyImage(vk_ctx.device, image.handle, nil)}
		if image.memory != vk.DeviceMemory(0) {vk.FreeMemory(vk_ctx.device, image.memory, nil)}
		image^ = {}
	}
	gpu.trail_width = 0
	gpu.trail_height = 0
	gpu.trail_initialized = false
	gpu.trail_write_index = 0
}

pellets_update_trail_descriptors :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	fade_info := vk.DescriptorBufferInfo{buffer = gpu.trail_fade_params_buffer.handle, offset = 0, range = vk.DeviceSize(size_of(Pellets_Fade_Params))}
	sampler_info := vk.DescriptorImageInfo{sampler = gpu.trail_sampler}
	for i in 0 ..< len(gpu.trail_images) {
		image_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = gpu.trail_images[i].view}
		fade_writes := [3]vk.WriteDescriptorSet{
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.trail_fade_sets[i], dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &fade_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.trail_fade_sets[i], dstBinding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.trail_fade_sets[i], dstBinding = 2, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
		}
		blit_writes := [2]vk.WriteDescriptorSet{
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.trail_blit_sets[i], dstBinding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = gpu.trail_blit_sets[i], dstBinding = 1, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
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
	pellets_destroy_trail_targets(gpu, vk_ctx)
	for i in 0 ..< len(gpu.trail_images) {
		if !pellets_create_trail_image(gpu, vk_ctx, i, width, height) {
			pellets_destroy_trail_targets(gpu, vk_ctx)
			return false
		}
	}
	gpu.trail_width = width
	gpu.trail_height = height
	pellets_update_trail_descriptors(gpu, vk_ctx)
	return true
}

pellets_transition_trail_image :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, index: int, new_layout: vk.ImageLayout) {
	image := &gpu.trail_images[index]
	if image.handle == vk.Image(0) || image.layout == new_layout {
		return
	}
	old_layout := image.layout
	src_access: vk.AccessFlags
	dst_access: vk.AccessFlags
	src_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	dst_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	#partial switch old_layout {
	case .UNDEFINED:
		#partial switch new_layout {
		case .COLOR_ATTACHMENT_OPTIMAL:
			dst_access = {.COLOR_ATTACHMENT_WRITE}
			dst_stage = {.COLOR_ATTACHMENT_OUTPUT}
		}
	case .COLOR_ATTACHMENT_OPTIMAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.COLOR_ATTACHMENT_WRITE}
			dst_access = {.SHADER_READ}
			src_stage = {.COLOR_ATTACHMENT_OUTPUT}
			dst_stage = {.FRAGMENT_SHADER}
		}
	case .SHADER_READ_ONLY_OPTIMAL:
		#partial switch new_layout {
		case .COLOR_ATTACHMENT_OPTIMAL:
			src_access = {.SHADER_READ}
			dst_access = {.COLOR_ATTACHMENT_WRITE}
			src_stage = {.FRAGMENT_SHADER}
			dst_stage = {.COLOR_ATTACHMENT_OUTPUT}
		}
	}
	barrier := vk.ImageMemoryBarrier{sType = .IMAGE_MEMORY_BARRIER, srcAccessMask = src_access, dstAccessMask = dst_access, oldLayout = old_layout, newLayout = new_layout, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, image = image.handle, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	vk.CmdPipelineBarrier(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	image.layout = new_layout
}

pellets_dispatch_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dst: vk.PipelineStageFlags) {
	barrier := vk.MemoryBarrier{sType = .MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.SHADER_READ, .SHADER_WRITE}}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, dst, {}, 1, &barrier, 0, nil, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

pellets_gpu_step :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim: ^Remaining_Sim_State, dt: f32) {
	settings := &sim.pellets
	if !pellets_gpu_ensure(gpu, vk_ctx, settings) || sim.paused {
		return
	}
	gpu.frame_index += 1
	pellets_upload_lut(gpu, settings)
	pellets_write_static_params(gpu, vk_ctx, settings)
	pellets_write_physics_params(gpu, vk_ctx, sim, dt)
	total_cells := gpu.grid_width * gpu.grid_height
	cell_groups := max((total_cells + PELLETS_WORKGROUP_SIZE - 1) / PELLETS_WORKGROUP_SIZE, 1)
	particle_groups := max((gpu.particle_count + PELLETS_WORKGROUP_SIZE - 1) / PELLETS_WORKGROUP_SIZE, 1)
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.grid_clear_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.grid_clear_pipeline.layout, 0, 1, &gpu.grid_clear_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, cell_groups, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	pellets_dispatch_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.grid_populate_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.grid_populate_pipeline.layout, 0, 1, &gpu.grid_populate_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, particle_groups, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	pellets_dispatch_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.physics_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.physics_pipeline.layout, 0, 1, &gpu.physics_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, particle_groups, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	pellets_dispatch_barrier(vk_ctx, cmd, {.COMPUTE_SHADER})
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.density_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.density_pipeline.layout, 0, 1, &gpu.density_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, particle_groups, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	pellets_dispatch_barrier(vk_ctx, cmd, {.VERTEX_SHADER, .FRAGMENT_SHADER})
}

pellets_gpu_draw_scene :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, background_pipeline, particle_pipeline: ^engine.Vk_Graphics_Pipeline, width, height: u32) {
	viewport := vk.Viewport{x = 0, y = 0, width = f32(width), height = f32(height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = {width, height}}
	pellets_gpu_draw_scene_viewport(gpu, vk_ctx, cmd, background_pipeline, particle_pipeline, viewport, scissor)
}

pellets_gpu_draw_scene_viewport :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, background_pipeline, particle_pipeline: ^engine.Vk_Graphics_Pipeline, viewport: vk.Viewport, scissor: vk.Rect2D) {
	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(cmd, 0, 1, &local_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &local_scissor)
	pellets_gpu_draw_background(gpu, vk_ctx, cmd, background_pipeline)
	pellets_gpu_draw_particles(gpu, vk_ctx, cmd, particle_pipeline)
}

pellets_gpu_draw_background :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, background_pipeline: ^engine.Vk_Graphics_Pipeline) {
	if background_pipeline.pipeline != vk.Pipeline(0) {
		vk.CmdBindPipeline(cmd, .GRAPHICS, background_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, background_pipeline.layout, 0, 1, &gpu.background_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 6, 1, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
}

pellets_gpu_draw_particles :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, particle_pipeline: ^engine.Vk_Graphics_Pipeline) {
	vk.CmdBindPipeline(cmd, .GRAPHICS, particle_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, particle_pipeline.layout, 0, 1, &gpu.render_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDraw(cmd, 6, gpu.particle_count * 9, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
}

pellets_draw_ui_overlay :: proc(vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, ui: ^engine.Ui_Renderer) {
	if ui == nil {
		return
	}
	engine.vk_cmd_label_begin(vk_ctx, frame.command_buffer, "UI overlay")
	engine.ui_renderer_draw(ui, vk_ctx, frame.command_buffer, vk_ctx.swapchain_extent)
	engine.vk_cmd_label_end(vk_ctx, frame.command_buffer)
}

pellets_gpu_present_direct :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, settings: ^Pellets_Settings, ui: ^engine.Ui_Renderer = nil) {
	engine.vk_cmd_begin_swapchain_render_pass(vk_ctx, frame, pellets_clear_color(settings))
	pellets_gpu_draw_scene(gpu, vk_ctx, frame.command_buffer, &gpu.background_pipeline, &gpu.render_pipeline, vk_ctx.swapchain_extent.width, vk_ctx.swapchain_extent.height)
	pellets_draw_ui_overlay(vk_ctx, frame, ui)
	engine.vk_cmd_end_swapchain_render_pass(frame)
}

pellets_write_fade_params :: proc(gpu: ^Pellets_Gpu_State, settings: ^Pellets_Settings) {
	if gpu.trail_fade_params_buffer.mapped == nil {
		return
	}
	params := cast(^Pellets_Fade_Params)gpu.trail_fade_params_buffer.mapped
	params^ = {
		fade_amount = settings.trail_fade,
	}
}

pellets_gpu_present_trails :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, settings: ^Pellets_Settings, ui: ^engine.Ui_Renderer = nil) {
	if !pellets_ensure_trail_targets(gpu, vk_ctx) {
		pellets_gpu_present_direct(gpu, vk_ctx, frame, settings, ui)
		return
	}
	cmd := frame.command_buffer
	write_index := int(gpu.trail_write_index & 1)
	read_index := 1 - write_index
	pellets_transition_trail_image(gpu, vk_ctx, cmd, write_index, .COLOR_ATTACHMENT_OPTIMAL)
	if gpu.trail_initialized {
		pellets_transition_trail_image(gpu, vk_ctx, cmd, read_index, .SHADER_READ_ONLY_OPTIMAL)
		pellets_write_fade_params(gpu, settings)
	}

	clear_value := vk.ClearValue{color = {float32 = {0, 0, 0, 0}}}
	begin := vk.RenderPassBeginInfo{sType = .RENDER_PASS_BEGIN_INFO, renderPass = gpu.trail_render_pass, framebuffer = gpu.trail_images[write_index].framebuffer, renderArea = {offset = {0, 0}, extent = {gpu.trail_width, gpu.trail_height}}, clearValueCount = 1, pClearValues = &clear_value}
	vk.CmdBeginRenderPass(cmd, &begin, .INLINE)
	vk_ctx.command_shape.render_pass_count += 1
	viewport := vk.Viewport{x = 0, y = 0, width = f32(gpu.trail_width), height = f32(gpu.trail_height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = {gpu.trail_width, gpu.trail_height}}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	pellets_gpu_draw_background(gpu, vk_ctx, cmd, &gpu.trail_background_pipeline)
	if gpu.trail_initialized {
		vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.trail_fade_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.trail_fade_pipeline.layout, 0, 1, &gpu.trail_fade_sets[read_index], 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 3, 1, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
	pellets_gpu_draw_particles(gpu, vk_ctx, cmd, &gpu.trail_particle_pipeline)
	vk.CmdEndRenderPass(cmd)
	gpu.trail_images[write_index].layout = .COLOR_ATTACHMENT_OPTIMAL
	gpu.trail_initialized = true
	pellets_transition_trail_image(gpu, vk_ctx, cmd, write_index, .SHADER_READ_ONLY_OPTIMAL)

	engine.vk_cmd_begin_swapchain_render_pass(vk_ctx, frame, pellets_clear_color(settings))
	swapchain_viewport := vk.Viewport{x = 0, y = 0, width = f32(vk_ctx.swapchain_extent.width), height = f32(vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}
	swapchain_scissor := vk.Rect2D{offset = {0, 0}, extent = vk_ctx.swapchain_extent}
	vk.CmdSetViewport(cmd, 0, 1, &swapchain_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &swapchain_scissor)
	vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.trail_blit_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.trail_blit_pipeline.layout, 0, 1, &gpu.trail_blit_sets[write_index], 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDraw(cmd, 3, 1, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
	pellets_draw_ui_overlay(vk_ctx, frame, ui)
	engine.vk_cmd_end_swapchain_render_pass(frame)
	gpu.trail_write_index = u32(read_index)
}

pellets_gpu_present :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, sim: ^Remaining_Sim_State, ui: ^engine.Ui_Renderer = nil) {
	if !gpu.ready || gpu.render_pipeline.pipeline == vk.Pipeline(0) {
		return
	}
	settings := &sim.pellets
	pellets_upload_lut(gpu, settings)
	pellets_write_static_params(gpu, vk_ctx, settings)
	if settings.trails_enabled {
		pellets_gpu_present_trails(gpu, vk_ctx, frame, settings, ui)
		return
	}
	pellets_gpu_present_direct(gpu, vk_ctx, frame, settings, ui)
}

pellets_clear_color :: proc(settings: ^Pellets_Settings) -> uifw.Color {
	#partial switch settings.background_color_mode {
	case .White:
		return {0.92, 0.91, 0.88, 1}
	case .Gray18:
		return {0.18, 0.18, 0.18, 1}
	case .Color_Scheme:
		return {0.05, 0.045, 0.055, 1}
	case:
		return {0, 0, 0, 1}
	}
}

pellets_destroy_compute_pipeline :: proc(vk_ctx: ^engine.Vk_Context, pipeline: ^engine.Vk_Compute_Pipeline) {
	if pipeline.pipeline != vk.Pipeline(0) {vk.DestroyPipeline(vk_ctx.device, pipeline.pipeline, nil)}
	if pipeline.layout != vk.PipelineLayout(0) {vk.DestroyPipelineLayout(vk_ctx.device, pipeline.layout, nil)}
	pipeline^ = {}
}

pellets_gpu_destroy :: proc(gpu: ^Pellets_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	if vk_ctx == nil || vk_ctx.device == nil {
		gpu^ = {}
		return
	}
	pellets_destroy_compute_pipeline(vk_ctx, &gpu.grid_clear_pipeline)
	pellets_destroy_compute_pipeline(vk_ctx, &gpu.grid_populate_pipeline)
	pellets_destroy_compute_pipeline(vk_ctx, &gpu.physics_pipeline)
	pellets_destroy_compute_pipeline(vk_ctx, &gpu.density_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.background_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.render_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.trail_background_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.trail_particle_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.trail_fade_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.trail_blit_pipeline)
	pellets_destroy_trail_targets(gpu, vk_ctx)
	if gpu.trail_sampler != vk.Sampler(0) {vk.DestroySampler(vk_ctx.device, gpu.trail_sampler, nil)}
	if gpu.trail_render_pass != vk.RenderPass(0) {vk.DestroyRenderPass(vk_ctx.device, gpu.trail_render_pass, nil)}
	if gpu.descriptor_pool != vk.DescriptorPool(0) {vk.DestroyDescriptorPool(vk_ctx.device, gpu.descriptor_pool, nil)}
	if gpu.grid_clear_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.grid_clear_set_layout, nil)}
	if gpu.grid_populate_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.grid_populate_set_layout, nil)}
	if gpu.physics_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.physics_set_layout, nil)}
	if gpu.density_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.density_set_layout, nil)}
	if gpu.background_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.background_set_layout, nil)}
	if gpu.render_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.render_set_layout, nil)}
	if gpu.trail_fade_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.trail_fade_set_layout, nil)}
	if gpu.trail_blit_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.trail_blit_set_layout, nil)}
	engine.vk_destroy_buffer(vk_ctx, &gpu.particle_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.physics_params_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.density_params_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.background_params_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.background_color_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.render_params_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.trail_fade_params_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.grid_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.grid_params_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.grid_counts_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.lut_buffer)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.grid_clear_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.grid_populate_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.physics_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.density_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.background_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.background_fragment_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.render_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.render_fragment_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.trail_fade_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.trail_fade_fragment_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.trail_blit_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.trail_blit_fragment_shader)
	gpu^ = {}
}
