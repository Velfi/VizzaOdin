package game

PRIMORDIAL_UPDATE_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/particle_update.slang"
PRIMORDIAL_DENSITY_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/density_compute.slang"
PRIMORDIAL_GRID_CLEAR_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/grid_clear.slang"
PRIMORDIAL_GRID_POPULATE_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/grid_populate.slang"
PRIMORDIAL_BACKGROUND_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/background_render.slang"
PRIMORDIAL_RENDER_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/particle_render.slang"
PRIMORDIAL_FADE_VERTEX_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/fade_vertex.slang"
PRIMORDIAL_FADE_FRAGMENT_SHADER_SOURCE :: "assets/shaders/simulations/primordial_particles/shaders/fade_fragment.slang"
PRIMORDIAL_UPDATE_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/particle_update"
PRIMORDIAL_DENSITY_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/density_compute"
PRIMORDIAL_GRID_CLEAR_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/grid_clear"
PRIMORDIAL_GRID_POPULATE_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/grid_populate"
PRIMORDIAL_BACKGROUND_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/background_render_vertex"
PRIMORDIAL_BACKGROUND_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/background_render_fragment"
PRIMORDIAL_RENDER_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/particle_render_vertex"
PRIMORDIAL_RENDER_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/particle_render_fragment"
PRIMORDIAL_FADE_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/fade_vertex"
PRIMORDIAL_FADE_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/primordial_particles/shaders/fade_fragment"
PRIMORDIAL_SOURCE_ENTRY :: "main"
PRIMORDIAL_VERTEX_SOURCE_ENTRY :: "vs_main"
PRIMORDIAL_FRAGMENT_SOURCE_ENTRY :: "fs_main"
PRIMORDIAL_ENTRY :: cstring("main")
PRIMORDIAL_VERTEX_ENTRY :: cstring("main")
PRIMORDIAL_FRAGMENT_ENTRY :: cstring("main")
PRIMORDIAL_WORKGROUP_SIZE :: u32(64)
PRIMORDIAL_GRID_AXIS :: u32(128)
PRIMORDIAL_GRID_CELL_COUNT :: PRIMORDIAL_GRID_AXIS * PRIMORDIAL_GRID_AXIS

Primordial_Particle :: struct #align(8) {
	position, previous_position: [2]f32,
	heading, velocity, density: f32,
	grabbed: u32,
}

Primordial_Sim_Params :: struct #align(16) {
	mouse_position, mouse_velocity: [2]f32,
	alpha, beta, velocity, radius, dt, width, height: f32,
	wrap_edges, particle_count, mouse_pressed, mouse_mode: u32,
	cursor_size, cursor_strength, aspect_ratio: f32,
	grid_axis: u32,
	grid_cell_size: f32,
	collision_enabled: u32,
	collision_distance, collision_relaxation, collision_damping: f32,
}

Primordial_Density_Params :: struct #align(16) {
	particle_count: u32,
	density_radius: f32,
	coloring_mode, grid_axis: u32,
	grid_cell_size: f32,
	_padding: [3]u32,
}

Primordial_Render_Params :: struct #align(16) {
	particle_size, screen_width, screen_height: f32,
	foreground_color_mode: u32,
	camera_position: [2]f32,
	camera_zoom: f32,
	tile_count: u32,
}

Primordial_Background_Params :: struct #align(16) {
	background_color: [4]f32,
}

Primordial_Camera :: Vectors_Camera_Uniform

Primordial_Fade_Params :: struct #align(16) {
	fade_amount: f32,
	_pad0: [3]f32,
}
