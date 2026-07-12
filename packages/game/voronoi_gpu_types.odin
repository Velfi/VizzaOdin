package game

Voronoi_Vertex :: struct #align(8) {
	position: [2]f32,
	color: f32,
	pad0: f32,
	phase: f32,
	seed: u32,
	pad1: u32,
	random_state: u32,
}

Voronoi_Params :: struct #align(16) {
	count: f32,
	color_mode: f32,
	border_enabled: f32,
	border_width: f32,
	filter_mode: f32,
	resolution_x: f32,
	resolution_y: f32,
	jump_distance: f32,
	camera_position: [2]f32,
	camera_zoom: f32,
	tile_count: u32,
}

Voronoi_Uniforms :: struct #align(16) {
	resolution: [2]f32,
	time: f32,
	drift: f32,
	_pad0: u32,
	_pad1: u32,
	_pad2: u32,
	_pad3: u32,
}

Voronoi_Brownian_Params :: struct #align(8) {
	speed: f32,
	delta_time: f32,
}
