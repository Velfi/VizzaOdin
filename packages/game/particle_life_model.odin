package game

import uifw "zelda_engine:ui"

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"

PARTICLE_LIFE_GRID_CLEAR_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/grid_clear.slang"
PARTICLE_LIFE_GRID_SCATTER_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/grid_scatter.slang"
PARTICLE_LIFE_GRID_SCATTER_PREDICTED_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/grid_scatter_predicted.slang"
PARTICLE_LIFE_GRID_PREFIX_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/grid_prefix.slang"
PARTICLE_LIFE_GRID_PREFIX_BLOCKS_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/grid_prefix_blocks.slang"
PARTICLE_LIFE_GRID_PREFIX_ADD_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/grid_prefix_add.slang"
PARTICLE_LIFE_GRID_INDEX_SCATTER_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/grid_index_scatter.slang"
PARTICLE_LIFE_COMPUTE_BINNED_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/compute_binned.slang"
PARTICLE_LIFE_COLLISION_SOLVE_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/collision_solve.slang"
PARTICLE_LIFE_COLLISION_APPLY_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/collision_apply.slang"
PARTICLE_LIFE_COPY_SCRATCH_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/copy_scratch.slang"
PARTICLE_LIFE_INIT_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/init.slang"
PARTICLE_LIFE_VERTEX_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/vertex.slang"
PARTICLE_LIFE_FRAGMENT_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/fragment.slang"
PARTICLE_LIFE_FADE_VERTEX_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/fade_vertex.slang"
PARTICLE_LIFE_FADE_FRAGMENT_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/fade_fragment.slang"
PARTICLE_LIFE_FORCE_RANDOMIZE_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/force_randomize.slang"
PARTICLE_LIFE_FORCE_UPDATE_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/force_update.slang"
PARTICLE_LIFE_ANALYSIS_CLEAR_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/analysis_clear.slang"
PARTICLE_LIFE_ANALYSIS_SCATTER_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/analysis_scatter.slang"
PARTICLE_LIFE_ANALYSIS_COHERENCE_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/analysis_coherence.slang"
PARTICLE_LIFE_ANALYSIS_TILE_LABEL_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/analysis_tile_label.slang"
PARTICLE_LIFE_ANALYSIS_TILE_MERGE_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/analysis_tile_merge.slang"
PARTICLE_LIFE_ANALYSIS_SUMMARIZE_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/analysis_summarize.slang"
PARTICLE_LIFE_BACKGROUND_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/background_render.slang"
PARTICLE_LIFE_POST_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/post_effect.slang"
PARTICLE_LIFE_INFINITE_PRESENT_VERTEX_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/infinite_present_vertex.slang"
PARTICLE_LIFE_INFINITE_PRESENT_FRAGMENT_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/infinite_present_fragment.slang"
PARTICLE_LIFE_GRID_CLEAR_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/grid_clear"
PARTICLE_LIFE_GRID_SCATTER_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/grid_scatter"
PARTICLE_LIFE_GRID_SCATTER_PREDICTED_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/grid_scatter_predicted"
PARTICLE_LIFE_GRID_PREFIX_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/grid_prefix"
PARTICLE_LIFE_GRID_PREFIX_BLOCKS_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/grid_prefix_blocks"
PARTICLE_LIFE_GRID_PREFIX_ADD_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/grid_prefix_add"
PARTICLE_LIFE_GRID_INDEX_SCATTER_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/grid_index_scatter"
PARTICLE_LIFE_COMPUTE_BINNED_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/compute_binned"
PARTICLE_LIFE_COLLISION_SOLVE_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/collision_solve"
PARTICLE_LIFE_COLLISION_APPLY_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/collision_apply"
PARTICLE_LIFE_COPY_SCRATCH_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/copy_scratch"
PARTICLE_LIFE_INIT_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/init"
PARTICLE_LIFE_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/vertex"
PARTICLE_LIFE_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/fragment"
PARTICLE_LIFE_FADE_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/fade_vertex"
PARTICLE_LIFE_FADE_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/fade_fragment"
PARTICLE_LIFE_FORCE_RANDOMIZE_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/force_randomize"
PARTICLE_LIFE_FORCE_UPDATE_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/force_update"
PARTICLE_LIFE_ANALYSIS_CLEAR_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/analysis_clear"
PARTICLE_LIFE_ANALYSIS_SCATTER_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/analysis_scatter"
PARTICLE_LIFE_ANALYSIS_COHERENCE_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/analysis_coherence"
PARTICLE_LIFE_ANALYSIS_TILE_LABEL_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/analysis_tile_label"
PARTICLE_LIFE_ANALYSIS_TILE_MERGE_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/analysis_tile_merge"
PARTICLE_LIFE_ANALYSIS_SUMMARIZE_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/analysis_summarize"
PARTICLE_LIFE_BACKGROUND_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/background_render_vertex"
PARTICLE_LIFE_BACKGROUND_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/background_render_fragment"
PARTICLE_LIFE_POST_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/post_effect_vertex"
PARTICLE_LIFE_POST_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/post_effect_fragment"
PARTICLE_LIFE_INFINITE_PRESENT_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/infinite_present_vertex"
PARTICLE_LIFE_INFINITE_PRESENT_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/particle_life/shaders/infinite_present_fragment"
PARTICLE_LIFE_ENTRY :: "main"
PARTICLE_LIFE_BACKGROUND_VERTEX_ENTRY :: "main"
PARTICLE_LIFE_BACKGROUND_FRAGMENT_ENTRY :: "main"
PARTICLE_LIFE_POST_VERTEX_ENTRY :: "main"
PARTICLE_LIFE_POST_FRAGMENT_ENTRY :: "main"
PARTICLE_LIFE_INFINITE_PRESENT_VERTEX_ENTRY :: "main"
PARTICLE_LIFE_INFINITE_PRESENT_FRAGMENT_ENTRY :: "main"
PARTICLE_LIFE_MAX_PARTICLE_COUNT :: 500000
PARTICLE_LIFE_MAX_SPECIES :: 8
PARTICLE_LIFE_COLOR_COUNT :: 9
PARTICLE_LIFE_WORKGROUP_SIZE :: 64
PARTICLE_LIFE_GRID_CLEAR_WORKGROUP_SIZE :: 64
PARTICLE_LIFE_MAX_GRID_AXIS :: 256
PARTICLE_LIFE_FORCE_GRID_CELL_SCALE :: f32(0.25)
PARTICLE_LIFE_ANALYSIS_TILE_SIZE :: 16
PARTICLE_LIFE_ANALYSIS_MAX_BLOBS :: 128
PARTICLE_LIFE_ANALYSIS_COORD_SCALE :: f32(4096.0)
PARTICLE_LIFE_ANALYSIS_VELOCITY_SCALE :: f32(65536.0)
PARTICLE_LIFE_ANALYSIS_COHERENCE_SCALE :: f32(65536.0)
PARTICLE_LIFE_TAU :: f32(6.28318530718)
PARTICLE_LIFE_PI :: f32(3.14159265359)
PARTICLE_LIFE_RETIRED_TRAIL_TARGET_CAP :: 4

Particle_Life_Color_Mode :: enum u32 {
	Gray18 = 0,
	White = 1,
	Black = 2,
	Color_Scheme = 3,
}

PARTICLE_LIFE_COLOR_MODE_NAMES := [?]string {
	"Gray18",
	"White",
	"Black",
	"Color Scheme",
}

PARTICLE_LIFE_BUILTIN_PRESET_NAMES := [?]string {
	"Default",
}

PARTICLE_LIFE_POSITION_GENERATOR_NAMES := [?]string {
	"Random",
	"Center",
	"Uniform Circle",
	"Centered Circle",
	"Ring",
	"Rainbow Ring",
	"Color Battle",
	"Color Wheel",
	"Line",
	"Spiral",
	"Rainbow Spiral",
}

PARTICLE_LIFE_TYPE_GENERATOR_NAMES := [?]string {
	"Radial",
	"Polar",
	"Stripes H",
	"Stripes V",
	"Random",
	"Line H",
	"Line V",
	"Spiral",
	"Dithered",
	"Wavy Line H",
	"Wavy Line V",
}

PARTICLE_LIFE_FORCE_GENERATOR_NAMES := [?]string {
	"Random",
	"Symmetry",
	"Chains",
	"Chains 2",
	"Chains 3",
	"Snakes",
	"Zero",
	"Predator Prey",
	"Symbiosis",
	"Territorial",
	"Magnetic",
	"Crystal",
	"Wave",
	"Hierarchy",
	"Clique",
	"Anti-Clique",
	"Fibonacci",
	"Prime",
	"Fractal",
	"Rock Paper Scissors",
	"Cooperation",
	"Competition",
}

Particle_Life_Particle :: struct #align(8) {
	position: [2]f32,
	velocity: [2]f32,
	species: u32,
	_pad: u32,
}

Particle_Life_Params :: struct #align(16) {
	particle_count: u32,
	species_count: u32,
	max_force: f32,
	max_distance: f32,
	friction: f32,
	wrap_edges: u32,
	width: f32,
	height: f32,
	random_seed: u32,
	dt: f32,
	beta: f32,
	cursor_x: f32,
	cursor_y: f32,
	cursor_size: f32,
	cursor_strength: f32,
	cursor_active: u32,
	brownian_motion: f32,
	particle_size: f32,
	aspect_ratio: f32,
	force_refresh_stride: u32,
	force_sample_limit: u32,
	_pad1: u32,
	_pad2: u32,
	_pad3: u32,
}

Particle_Life_Init_Params :: struct #align(16) {
	start_index: u32,
	spawn_count: u32,
	species_count: u32,
	width: f32,
	height: f32,
	random_seed: u32,
	position_generator: u32,
	type_generator: u32,
	_pad1: u32,
	_pad2: u32,
}

Particle_Life_Camera :: struct #align(16) {
	transform_matrix: [16]f32,
	position: [2]f32,
	zoom: f32,
	aspect_ratio: f32,
}

Particle_Life_Viewport :: struct #align(16) {
	world_bounds: [4]f32,
	texture_size: [2]f32,
	_pad1: f32,
	_pad2: f32,
}

Particle_Life_Viewport_Push :: struct #align(16) {
	world_bounds: [4]f32,
	enabled: u32,
	_pad0: u32,
	_pad1: u32,
	_pad2: u32,
}

Particle_Life_Species_Colors :: struct #align(16) {
	colors: [PARTICLE_LIFE_COLOR_COUNT][4]f32,
}

Particle_Life_Color_Mode_Params :: struct #align(16) {
	mode: u32,
	_pad1: u32,
	_pad2: u32,
	_pad3: u32,
	brightness: f32,
	contrast: f32,
	saturation: f32,
	gamma: f32,
}

Particle_Life_Fade_Params :: struct #align(16) {
	fade_amount: f32,
	_pad1: f32,
	_pad2: f32,
	_pad3: f32,
}

Particle_Life_Force_Randomize_Params :: struct #align(16) {
	species_count: u32,
	random_seed: u32,
	min_force: f32,
	max_force: f32,
}

Particle_Life_Force_Update_Params :: struct #align(16) {
	species_a: u32,
	species_b: u32,
	new_force: f32,
	species_count: u32,
}

Particle_Life_Grid_Params :: struct #align(16) {
	particle_count: u32,
	grid_width: u32,
	grid_height: u32,
	neighbor_radius_cells: u32,
	cell_size: f32,
	world_min_x: f32,
	world_min_y: f32,
	world_width: f32,
	world_height: f32,
	_pad0: f32,
	_pad1: f32,
}

Particle_Life_Collision_Params :: struct #align(16) {
	enabled: u32,
	iterations: u32,
	_pad0: u32,
	_pad1: u32,
	min_distance: f32,
	relaxation: f32,
	max_correction: f32,
	velocity_damping: f32,
}

Particle_Life_Analysis_Params :: struct #align(16) {
	enabled: u32,
	interval_frames: u32,
	grid_size: u32,
	min_blob_area_cells: u32,
	coherence_threshold: f32,
	_pad1: f32,
	_pad2: f32,
	_pad3: f32,
}

Particle_Life_Analysis_Cell :: struct #align(16) {
	density: f32,
	velocity_sum: [2]f32,
	speed_sum: f32,
	species_histogram: [PARTICLE_LIFE_MAX_SPECIES]u32,
}

Particle_Life_Analysis_Gpu_Cell :: struct #align(16) {
	density: u32,
	velocity_sum: [2]i32,
	speed_sum: u32,
	species_histogram: [PARTICLE_LIFE_MAX_SPECIES]u32,
}

Particle_Life_Blob_Accumulator :: struct #align(16) {
	id: u32,
	area: u32,
	density: u32,
	coherence_sum: u32,
	centroid_sum: [2]i32,
	velocity_sum: [2]i32,
	bounds_min: [2]u32,
	bounds_max: [2]u32,
	species_histogram: [PARTICLE_LIFE_MAX_SPECIES]u32,
}

Particle_Life_Blob_Summary :: struct #align(16) {
	id: u32,
	area: u32,
	_pad0: u32,
	_pad1: u32,
	centroid: [2]f32,
	velocity: [2]f32,
	bounds: [4]f32,
	coherence_score: f32,
	density: f32,
	species_histogram: [PARTICLE_LIFE_MAX_SPECIES]u32,
}

Particle_Life_Selected_Blob_Params :: struct #align(16) {
	selected_blob_id: u32,
	overlay_enabled: u32,
	_pad0: u32,
	_pad1: u32,
}

Particle_Life_Analysis_Workspace :: struct {
	axis: u32,
	cells: []Particle_Life_Analysis_Cell,
	coherence: []f32,
	labels: []u32,
	queue: []u32,
	summaries: [128]Particle_Life_Blob_Summary,
}

Particle_Life_Background_Params :: struct #align(16) {
	background_color: [4]f32,
}

Particle_Life_Post_Params :: struct #align(16) {
	brightness: f32,
	contrast: f32,
	saturation: f32,
	gamma: f32,
}

Particle_Life_Settings :: struct {
	particle_count: u32,
	species_count: u32,
	max_force: f32,
	max_distance: f32,
	friction: f32,
	beta: f32,
	brownian_motion: f32,
	particle_size: f32,
	cursor_size: f32,
	cursor_strength: f32,
	position_generator: u32,
	type_generator: u32,
	force_generator: u32,
	force_random_min: f32,
	force_random_max: f32,
	camera_x: f32,
	camera_y: f32,
	camera_zoom: f32,
	color_mode: Particle_Life_Color_Mode,
	color_scheme: Color_Scheme_Name,
	color_scheme_reversed: bool,
	background_color_mode: Vector_Background_Mode,
	background_index: int,
	background_color: [4]f32,
	post_processing: Post_Processing_Settings,
	brightness: f32,
	contrast: f32,
	saturation: f32,
	gamma: f32,
	trails_enabled: bool,
	trail_fade_amount: f32,
	infinite_tiles_enabled: bool,
	infinite_tile_radius: u32,
	analysis_enabled: bool,
	analysis_interval_frames: u32,
	analysis_grid_size: u32,
	coherence_threshold: f32,
	min_blob_area_cells: u32,
	blob_overlay_enabled: bool,
	collision_enabled: bool,
	collision_distance: f32,
	collision_iterations: u32,
	collision_relaxation: f32,
	collision_damping: f32,
	force_temporal_coherence: bool,
	force_dense_sampling: bool,
	custom_force_matrix: bool,
	force_matrix: [PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32,
	wrap_edges: bool,
	paused: bool,
}

Particle_Life_Runtime_State :: struct {
	canvas_tool: Canvas_Tool_State,
	blob_tracker: Particle_Life_Blob_Tracker,
	render_ready: bool,
	render_width: i32,
	render_height: i32,
	rendered_particle_count: u32,
	rendered_species_count: u32,
	grid_width: u32,
	grid_height: u32,
	neighbor_radius_cells: u32,
	collision_grid_width: u32,
	collision_grid_height: u32,
	render_rebuild_requested: bool,
	preserve_particles_requested: bool,
	trail_reset_requested: bool,
	frame_index: u64,
	seed: u32,
	cursor_active: u32,
	cursor_x: f32,
	cursor_y: f32,
	needs_reset: bool,
	selected_species_a: u32,
	selected_species_b: u32,
	force_curve_narrow_range: bool,
	force_curve_beta_drag_start_x: f32,
	force_curve_beta_drag_start_value: f32,
	camera_x: f32,
	camera_y: f32,
	camera_zoom: f32,
	camera_target_x: f32,
	camera_target_y: f32,
	camera_target_zoom: f32,
	camera_smoothing_factor: f32,
	current_preset_index: int,
	trail_camera_valid: bool,
	trail_camera_x: f32,
	trail_camera_y: f32,
	trail_camera_zoom: f32,
	force_matrix: [PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32,
	force_randomize_undo_matrix: [PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32,
	force_randomize_undo_seed: u32,
	force_randomize_undo_available: bool,
	preset_ui: Preset_Fieldset_State,
	preserved_particles: []Particle_Life_Particle,
	pending_force_randomize: bool,
	force_matrix_dirty: bool,
	pending_force_update: bool,
	pending_force_a: u32,
	pending_force_b: u32,
	pending_force_value: f32,
	selected_blob_id: u32,
	last_analysis_frame: u64,
	last_analysis_read_frame: u64,
	analysis: Particle_Life_Analysis_Workspace,
}

Particle_Life_Tracked_Blob :: struct {
	id: u32,
	age: u32,
	missed_frames: u32,
	last_position: [2]f32,
	predicted_position: [2]f32,
	velocity: [2]f32,
	bounds: [4]f32,
	area: u32,
	confidence: f32,
	species_histogram: [PARTICLE_LIFE_MAX_SPECIES]u32,
}

Particle_Life_Blob_Tracker :: struct {
	next_id: u32,
	count: u32,
	blobs: [128]Particle_Life_Tracked_Blob,
}

Particle_Life_Tile_Range :: struct {
	min_x: i32,
	max_x: i32,
	min_y: i32,
	max_y: i32,
}

Particle_Life_Simulation :: struct {
	settings: ^Particle_Life_Settings,
	using runtime: ^Particle_Life_Runtime_State,
	render_runtime: rawptr,
}

particle_life_bind_product_instance :: proc(sim: ^Particle_Life_Simulation, instance: ^Feature_Instance) -> bool {
	if sim == nil do return false
	settings, settings_ok := feature_instance_settings(instance, Particle_Life_Settings)
	runtime, runtime_ok := feature_instance_runtime(instance, Particle_Life_Runtime_State)
	if !settings_ok || !runtime_ok do return false
	sim.settings = settings
	sim.runtime = runtime
	return true
}
