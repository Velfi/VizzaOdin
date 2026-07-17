package game

PELLETS_GRID_CLEAR_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/grid_clear.slang"
PELLETS_GRID_POPULATE_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/grid_populate.slang"
PELLETS_GRID_PREFIX_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/grid_prefix.slang"
PELLETS_GRID_PREFIX_BLOCKS_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/grid_prefix_blocks.slang"
PELLETS_GRID_PREFIX_ADD_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/grid_prefix_add.slang"
PELLETS_GRID_SCATTER_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/grid_scatter.slang"
PELLETS_PHYSICS_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/physics_compute.slang"
PELLETS_BACKGROUND_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/background_render.slang"
PELLETS_RENDER_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/particle_render.slang"
PELLETS_TRAIL_FADE_VERTEX_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/trail_fade_vertex.slang"
PELLETS_TRAIL_FADE_FRAGMENT_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/trail_fade_fragment.slang"
PELLETS_TRAIL_BLIT_SHADER_SOURCE :: "assets/shaders/simulations/pellets/shaders/trail_blit.slang"
PELLETS_GRID_CLEAR_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/grid_clear"
PELLETS_GRID_POPULATE_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/grid_populate"
PELLETS_GRID_PREFIX_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/grid_prefix"
PELLETS_GRID_PREFIX_BLOCKS_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/grid_prefix_blocks"
PELLETS_GRID_PREFIX_ADD_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/grid_prefix_add"
PELLETS_GRID_SCATTER_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/grid_scatter"
PELLETS_PHYSICS_FALLBACK_SPV :: "build/shaders/simulations/pellets/shaders/physics_compute"
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

Pellets_Particle :: struct #align(8) {
	position: [2]f32,
	velocity: [2]f32,
	mass, radius: f32,
	clump_id: u32,
	density: f32,
	grabbed, _pad0: u32,
	previous_position: [2]f32,
}

Pellets_Physics_Params :: struct #align(16) {
	mouse_position, mouse_velocity: [2]f32,
	particle_count: u32,
	gravitational_constant, energy_damping, collision_damping, dt, gravity_softening: f32,
	interaction_radius: f32,
	mouse_pressed, mouse_mode: u32,
	cursor_size, cursor_strength, particle_size, aspect_ratio: f32,
	density_damping_enabled: u32,
	overlap_resolution_strength: f32,
	frame_index, coloring_mode: u32,
	density_radius: f32,
}

Pellets_Render_Params :: struct #align(16) {
	particle_size, screen_width, screen_height: f32,
	foreground_color_mode: u32,
	camera_position: [2]f32,
	camera_zoom: f32,
	tile_count: u32,
}

Pellets_Background_Params :: struct #align(16) {
	background_color_mode: u32,
	_pad0: [3]u32,
}

Pellets_Grid_Params :: struct #align(16) {
	particle_count, grid_width, grid_height: u32,
	cell_size, world_width, world_height: f32,
	_pad1, _pad2: u32,
}

Pellets_Fade_Params :: struct #align(16) {
	fade_amount: f32,
	_pad0: [3]f32,
}
