package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import vk "vendor:vulkan"

PARTICLE_LIFE_GRID_CLEAR_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/grid_clear.slang"
PARTICLE_LIFE_GRID_SCATTER_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/grid_scatter.slang"
PARTICLE_LIFE_GRID_SCATTER_PREDICTED_SHADER_SOURCE :: "assets/shaders/simulations/particle_life/shaders/grid_scatter_predicted.slang"
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
	_pad1: u32,
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
	custom_force_matrix: bool,
	force_matrix: [PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32,
	wrap_edges: bool,
	paused: bool,
}

Particle_Life_Runtime_State :: struct {
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

Particle_Life_Trail_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	framebuffer: vk.Framebuffer,
	layout: vk.ImageLayout,
}

Particle_Life_Retired_Trail_Targets :: struct {
	images: [2]Particle_Life_Trail_Image,
	pending_frame_slots: u32,
}

Particle_Life_Tile_Range :: struct {
	min_x: i32,
	max_x: i32,
	min_y: i32,
	max_y: i32,
}

Particle_Life_Gpu_State :: struct {
	ready: bool,
	grid_clear_shader_module: engine.Vk_Shader_Module,
	grid_scatter_shader_module: engine.Vk_Shader_Module,
	grid_scatter_predicted_shader_module: engine.Vk_Shader_Module,
	compute_binned_shader_module: engine.Vk_Shader_Module,
	collision_solve_shader_module: engine.Vk_Shader_Module,
	collision_apply_shader_module: engine.Vk_Shader_Module,
	copy_scratch_shader_module: engine.Vk_Shader_Module,
	init_shader_module: engine.Vk_Shader_Module,
	vertex_shader_module: engine.Vk_Shader_Module,
	fragment_shader_module: engine.Vk_Shader_Module,
	fade_vertex_shader_module: engine.Vk_Shader_Module,
	fade_fragment_shader_module: engine.Vk_Shader_Module,
	force_randomize_shader_module: engine.Vk_Shader_Module,
	force_update_shader_module: engine.Vk_Shader_Module,
	analysis_clear_shader_module: engine.Vk_Shader_Module,
	analysis_scatter_shader_module: engine.Vk_Shader_Module,
	analysis_coherence_shader_module: engine.Vk_Shader_Module,
	analysis_tile_label_shader_module: engine.Vk_Shader_Module,
	analysis_tile_merge_shader_module: engine.Vk_Shader_Module,
	analysis_summarize_shader_module: engine.Vk_Shader_Module,
	background_vertex_shader_module: engine.Vk_Shader_Module,
	background_fragment_shader_module: engine.Vk_Shader_Module,
	post_vertex_shader_module: engine.Vk_Shader_Module,
	post_fragment_shader_module: engine.Vk_Shader_Module,
	infinite_present_vertex_shader_module: engine.Vk_Shader_Module,
	infinite_present_fragment_shader_module: engine.Vk_Shader_Module,
	grid_clear_shader_spirv_path: string,
	grid_scatter_shader_spirv_path: string,
	grid_scatter_predicted_shader_spirv_path: string,
	compute_binned_shader_spirv_path: string,
	collision_solve_shader_spirv_path: string,
	collision_apply_shader_spirv_path: string,
	copy_scratch_shader_spirv_path: string,
	init_shader_spirv_path: string,
	vertex_shader_spirv_path: string,
	fragment_shader_spirv_path: string,
	fade_vertex_shader_spirv_path: string,
	fade_fragment_shader_spirv_path: string,
	force_randomize_shader_spirv_path: string,
	force_update_shader_spirv_path: string,
	analysis_clear_shader_spirv_path: string,
	analysis_scatter_shader_spirv_path: string,
	analysis_coherence_shader_spirv_path: string,
	analysis_tile_label_shader_spirv_path: string,
	analysis_tile_merge_shader_spirv_path: string,
	analysis_summarize_shader_spirv_path: string,
	background_vertex_shader_spirv_path: string,
	background_fragment_shader_spirv_path: string,
	post_vertex_shader_spirv_path: string,
	post_fragment_shader_spirv_path: string,
	infinite_present_vertex_shader_spirv_path: string,
	infinite_present_fragment_shader_spirv_path: string,
	grid_clear_pipeline: engine.Vk_Compute_Pipeline,
	grid_scatter_pipeline: engine.Vk_Compute_Pipeline,
	grid_scatter_predicted_pipeline: engine.Vk_Compute_Pipeline,
	compute_binned_pipeline: engine.Vk_Compute_Pipeline,
	collision_solve_pipeline: engine.Vk_Compute_Pipeline,
	collision_apply_pipeline: engine.Vk_Compute_Pipeline,
	copy_scratch_pipeline: engine.Vk_Compute_Pipeline,
	init_pipeline: engine.Vk_Compute_Pipeline,
	render_pipeline: engine.Vk_Graphics_Pipeline,
	trail_particle_pipeline: engine.Vk_Graphics_Pipeline,
	fade_pipeline: engine.Vk_Graphics_Pipeline,
	force_randomize_pipeline: engine.Vk_Compute_Pipeline,
	force_update_pipeline: engine.Vk_Compute_Pipeline,
	analysis_clear_pipeline: engine.Vk_Compute_Pipeline,
	analysis_scatter_pipeline: engine.Vk_Compute_Pipeline,
	analysis_coherence_pipeline: engine.Vk_Compute_Pipeline,
	analysis_tile_label_pipeline: engine.Vk_Compute_Pipeline,
	analysis_tile_merge_pipeline: engine.Vk_Compute_Pipeline,
	analysis_summarize_pipeline: engine.Vk_Compute_Pipeline,
	background_pipeline: engine.Vk_Graphics_Pipeline,
	post_pipeline: engine.Vk_Graphics_Pipeline,
	tiled_post_pipeline: engine.Vk_Graphics_Pipeline,
	trail_render_pass: vk.RenderPass,
	sim_set_layout: vk.DescriptorSetLayout,
	init_set_layout: vk.DescriptorSetLayout,
	color_set_layout: vk.DescriptorSetLayout,
	view_set_layout: vk.DescriptorSetLayout,
	fade_set_layout: vk.DescriptorSetLayout,
	force_op_set_layout: vk.DescriptorSetLayout,
	analysis_set_layout: vk.DescriptorSetLayout,
	background_set_layout: vk.DescriptorSetLayout,
	post_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	fade_descriptor_pool: vk.DescriptorPool,
	sim_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	init_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	color_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	view_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	force_randomize_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	force_update_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	analysis_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	background_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	post_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	fade_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	particle_buffer: engine.Vk_Buffer,
	particle_scratch_buffer: engine.Vk_Buffer,
	params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	init_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	fade_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	force_randomize_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	force_update_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	grid_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	collision_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	grid_heads_buffer: engine.Vk_Buffer,
	particle_next_buffer: engine.Vk_Buffer,
	collision_correction_buffer: engine.Vk_Buffer,
	analysis_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	analysis_cells_buffer: engine.Vk_Buffer,
	analysis_coherence_buffer: engine.Vk_Buffer,
	analysis_labels_buffer: engine.Vk_Buffer,
	analysis_tile_components_buffer: engine.Vk_Buffer,
	analysis_parent_buffer: engine.Vk_Buffer,
	analysis_blob_summaries_buffer: engine.Vk_Buffer,
	analysis_blob_count_buffer: engine.Vk_Buffer,
	selected_blob_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	background_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	post_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	force_matrix_buffer: engine.Vk_Buffer,
	color_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	color_mode_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	camera_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	viewport_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	trail_sampler: vk.Sampler,
	trail_images: [2]Particle_Life_Trail_Image,
	retired_trail_targets: [PARTICLE_LIFE_RETIRED_TRAIL_TARGET_CAP]Particle_Life_Retired_Trail_Targets,
	trail_width: u32,
	trail_height: u32,
	trail_write_index: u32,
	trail_initialized: bool,
	width: i32,
	height: i32,
	uploaded_particle_count: u32,
	uploaded_species_count: u32,
	grid_width: u32,
	grid_height: u32,
	neighbor_radius_cells: u32,
	analysis_grid_axis: u32,
	analysis_tile_count: u32,
	active_frame_slot: int,
}

Particle_Life_Simulation :: struct {
	settings: Particle_Life_Settings,
	runtime: Particle_Life_Runtime_State,
	gpu: Particle_Life_Gpu_State,
	blob_tracker: Particle_Life_Blob_Tracker,
}

particle_life_target_particle_count :: proc(settings: Particle_Life_Settings) -> u32 {
	return max(min(settings.particle_count, PARTICLE_LIFE_MAX_PARTICLE_COUNT), 1)
}

particle_life_target_species_count :: proc(settings: Particle_Life_Settings) -> u32 {
	return max(min(settings.species_count, PARTICLE_LIFE_MAX_SPECIES), 1)
}

particle_life_world_size_for_viewport :: proc(width, height: f32) -> [2]f32 {
	aspect := max(width, 1) / max(height, 1)
	return {max(aspect, 0.0001) * 2.0, 2.0}
}

particle_life_world_size :: proc(sim: ^Particle_Life_Simulation) -> [2]f32 {
	return particle_life_world_size_for_viewport(f32(max(sim.gpu.width, 1)), f32(max(sim.gpu.height, 1)))
}

particle_life_collision_distance :: proc(settings: Particle_Life_Settings) -> f32 {
	return max(settings.particle_size * 0.002, 0.0001)
}

particle_life_target_grid_cell_size :: proc(settings: Particle_Life_Settings) -> f32 {
	cell_size := max(settings.max_distance, 0.001)
	if settings.collision_enabled {
		cell_size = min(cell_size, particle_life_collision_distance(settings))
	}
	return cell_size
}

particle_life_target_grid_axis :: proc(settings: Particle_Life_Settings) -> u32 {
	axis := u32(math.ceil(2.0 / particle_life_target_grid_cell_size(settings)))
	return max(min(axis, PARTICLE_LIFE_MAX_GRID_AXIS), 4)
}

particle_life_target_grid_dimensions :: proc(settings: Particle_Life_Settings, world_size: [2]f32) -> (u32, u32) {
	cell_size := particle_life_target_grid_cell_size(settings)
	grid_width := u32(math.ceil(max(world_size[0], 0.0001) / cell_size))
	grid_height := u32(math.ceil(max(world_size[1], 0.0001) / cell_size))
	return max(min(grid_width, PARTICLE_LIFE_MAX_GRID_AXIS), 4), max(min(grid_height, PARTICLE_LIFE_MAX_GRID_AXIS), 4)
}

particle_life_target_neighbor_radius_cells :: proc(settings: Particle_Life_Settings, grid_width, grid_height: u32, world_size: [2]f32) -> u32 {
	cell_w := world_size[0] / f32(max(grid_width, 1))
	cell_h := world_size[1] / f32(max(grid_height, 1))
	cell_size := max(max(cell_w, cell_h), 0.0001)
	radius := u32(math.ceil(max(settings.max_distance, cell_size) / cell_size))
	return max(radius, 1)
}

particle_life_grid_satisfies_target :: proc(current_width, current_height, current_neighbor_radius, target_width, target_height, target_neighbor_radius: u32) -> bool {
	return current_width >= target_width &&
		current_height >= target_height &&
		current_neighbor_radius >= target_neighbor_radius
}

particle_life_current_grid_satisfies_settings :: proc(sim: ^Particle_Life_Simulation) -> bool {
	world_size := particle_life_world_size(sim)
	target_grid_width, target_grid_height := particle_life_target_grid_dimensions(sim.settings, world_size)
	target_neighbor_radius := particle_life_target_neighbor_radius_cells(sim.settings, target_grid_width, target_grid_height, world_size)
	return particle_life_grid_satisfies_target(
		sim.gpu.grid_width,
		sim.gpu.grid_height,
		sim.gpu.neighbor_radius_cells,
		target_grid_width,
		target_grid_height,
		target_neighbor_radius,
	)
}

particle_life_target_analysis_grid_axis :: proc(settings: Particle_Life_Settings) -> u32 {
	return max(min(settings.analysis_grid_size, 1024), 64)
}

particle_life_analysis_tile_count_for_axis :: proc(axis: u32) -> u32 {
	return (max(axis, 1) + PARTICLE_LIFE_ANALYSIS_TILE_SIZE - 1) / PARTICLE_LIFE_ANALYSIS_TILE_SIZE
}

particle_life_default_settings :: proc() -> Particle_Life_Settings {
	settings := Particle_Life_Settings {
		particle_count = 15000,
		species_count = 4,
		max_force = 0.5,
		max_distance = 0.05,
		friction = 0.5,
		beta = 0.5,
		brownian_motion = 0.5,
		particle_size = 4,
		cursor_size = 0.5,
		cursor_strength = 5.0,
		position_generator = 0,
		type_generator = 4,
		force_generator = 0,
		force_random_min = -1.0,
		force_random_max = 1.0,
		camera_zoom = 1,
		color_mode = .Color_Scheme,
		background_color_mode = .Color_Scheme,
		background_index = int(Vector_Background_Mode.Color_Scheme),
		background_color = {0.015, 0.018, 0.024, 1},
		post_processing = post_processing_default_settings(),
		brightness = 1,
		contrast = 1,
		saturation = 1,
		gamma = 1,
		trails_enabled = false,
		trail_fade_amount = 0.48,
		infinite_tiles_enabled = true,
		infinite_tile_radius = 4,
		analysis_enabled = false,
		analysis_interval_frames = 8,
		analysis_grid_size = 512,
		coherence_threshold = 0.55,
		min_blob_area_cells = 12,
		blob_overlay_enabled = false,
		collision_enabled = true,
		collision_distance = 0.008,
		collision_iterations = 3,
		collision_relaxation = 0.75,
		collision_damping = 0.9,
		wrap_edges = true,
		paused = false,
		custom_force_matrix = true,
	}
	settings.force_matrix[0 * PARTICLE_LIFE_MAX_SPECIES + 0] = -0.1
	settings.force_matrix[0 * PARTICLE_LIFE_MAX_SPECIES + 1] = 0.2
	settings.force_matrix[0 * PARTICLE_LIFE_MAX_SPECIES + 2] = -0.1
	settings.force_matrix[0 * PARTICLE_LIFE_MAX_SPECIES + 3] = 0.1
	settings.force_matrix[1 * PARTICLE_LIFE_MAX_SPECIES + 0] = 0.2
	settings.force_matrix[1 * PARTICLE_LIFE_MAX_SPECIES + 1] = -0.1
	settings.force_matrix[1 * PARTICLE_LIFE_MAX_SPECIES + 2] = 0.3
	settings.force_matrix[1 * PARTICLE_LIFE_MAX_SPECIES + 3] = -0.1
	settings.force_matrix[2 * PARTICLE_LIFE_MAX_SPECIES + 0] = -0.1
	settings.force_matrix[2 * PARTICLE_LIFE_MAX_SPECIES + 1] = 0.3
	settings.force_matrix[2 * PARTICLE_LIFE_MAX_SPECIES + 2] = -0.1
	settings.force_matrix[2 * PARTICLE_LIFE_MAX_SPECIES + 3] = 0.2
	settings.force_matrix[3 * PARTICLE_LIFE_MAX_SPECIES + 0] = 0.1
	settings.force_matrix[3 * PARTICLE_LIFE_MAX_SPECIES + 1] = -0.1
	settings.force_matrix[3 * PARTICLE_LIFE_MAX_SPECIES + 2] = 0.2
	settings.force_matrix[3 * PARTICLE_LIFE_MAX_SPECIES + 3] = -0.1
	color_scheme_name_set(&settings.color_scheme, "ZELDA_Particles1")
	return settings
}

particle_life_apply_builtin_preset :: proc(sim: ^Particle_Life_Simulation, index: int) {
	if index < 0 || index >= len(PARTICLE_LIFE_BUILTIN_PRESET_NAMES) {
		return
	}
	sim.runtime.current_preset_index = index
	settings := particle_life_default_settings()
	particle_life_settings_preserve_color_scheme(&settings, sim.settings)
	particle_life_load_settings(sim, settings)
}

particle_life_init :: proc(sim: ^Particle_Life_Simulation, width, height: i32) {
	sim.settings = particle_life_default_settings()
	sim.runtime = {seed = 0x3c6ef372, needs_reset = true, force_curve_narrow_range = true, camera_zoom = 1, camera_target_zoom = 1, camera_smoothing_factor = CAMERA_DEFAULT_SMOOTHING}
	sim.gpu = {width = width, height = height}
	sim.blob_tracker = {next_id = 1}
}

particle_life_resize :: proc(sim: ^Particle_Life_Simulation, width, height: i32) {
	if sim.gpu.width == width && sim.gpu.height == height {
		return
	}
	sim.gpu.width = width
	sim.gpu.height = height
	sim.gpu.ready = false
}

particle_life_step :: proc(sim: ^Particle_Life_Simulation, dt: f32) {
	if sim.settings.paused {
		return
	}
	_ = dt
	sim.runtime.frame_index += 1
}

particle_life_apply_frame_input :: proc(sim: ^Particle_Life_Simulation, input: Ui_Frame_Input) {
	camera := particle_life_camera_control_state(sim)
	camera_controls_apply_input(&camera, input)
	particle_life_store_camera_control_state(sim, camera)

	sim.runtime.cursor_active = 0
	if !input.mouse_down || input.window_width <= 0 || input.window_height <= 0 {
		return
	}
	world := particle_life_screen_to_world(sim, input.mouse_pos, input.window_width, input.window_height)
	sim.runtime.cursor_x = world[0]
	sim.runtime.cursor_y = world[1]
	sim.runtime.cursor_active = input.mouse_button == 3 ? 2 : 1
}

particle_life_view_bounds :: proc(sim: ^Particle_Life_Simulation, width, height: f32) -> [4]f32 {
	world_size := particle_life_world_size_for_viewport(width, height)
	zoom := max(sim.runtime.camera_zoom, 0.25)
	half_x := world_size[0] * 0.5 / zoom
	half_y := world_size[1] * 0.5 / zoom
	return {
		sim.runtime.camera_x - half_x,
		sim.runtime.camera_y - half_y,
		sim.runtime.camera_x + half_x,
		sim.runtime.camera_y + half_y,
	}
}

particle_life_camera_control_state :: proc(sim: ^Particle_Life_Simulation) -> Camera_Control_State {
	return {
		position = {sim.runtime.camera_x, sim.runtime.camera_y},
		target_position = {sim.runtime.camera_target_x, sim.runtime.camera_target_y},
		zoom = sim.runtime.camera_zoom,
		target_zoom = sim.runtime.camera_target_zoom,
		smoothing_factor = sim.runtime.camera_smoothing_factor,
	}
}

particle_life_store_camera_control_state :: proc(sim: ^Particle_Life_Simulation, camera: Camera_Control_State) {
	sim.runtime.camera_x = camera.position[0]
	sim.runtime.camera_y = camera.position[1]
	sim.runtime.camera_zoom = max(camera.zoom, CAMERA_MIN_ZOOM)
	sim.runtime.camera_target_x = camera.target_position[0]
	sim.runtime.camera_target_y = camera.target_position[1]
	sim.runtime.camera_target_zoom = max(camera.target_zoom, CAMERA_MIN_ZOOM)
	sim.runtime.camera_smoothing_factor = camera.smoothing_factor
}

particle_life_screen_to_world :: proc(sim: ^Particle_Life_Simulation, mouse_pos: uifw.Vec2, width, height: i32) -> [2]f32 {
	camera := particle_life_camera_control_state(sim)
	camera_controls_sync(&camera)
	w := f32(max(width, 1))
	h := f32(max(height, 1))
	world_size := particle_life_world_size_for_viewport(w, h)
	zoom := max(camera.target_zoom, CAMERA_MIN_ZOOM)
	ndc_x := (mouse_pos.x / w) * 2.0 - 1.0
	ndc_y := -((mouse_pos.y / h) * 2.0 - 1.0)
	world := [2]f32 {
		camera.target_position[0] + ndc_x * world_size[0] * 0.5 / zoom,
		camera.target_position[1] + ndc_y * world_size[1] * 0.5 / zoom,
	}
	particle_life_store_camera_control_state(sim, camera)
	return world
}

particle_life_world_to_screen :: proc(sim: ^Particle_Life_Simulation, world: [2]f32, width, height: f32) -> uifw.Vec2 {
	bounds := particle_life_view_bounds(sim, width, height)
	normalized_x := (world[0] - bounds[0]) / max(bounds[2] - bounds[0], 0.00001)
	normalized_y := (world[1] - bounds[1]) / max(bounds[3] - bounds[1], 0.00001)
	return {normalized_x * width, (1.0 - normalized_y) * height}
}

particle_life_blob_overlay_radius_px :: proc(sim: ^Particle_Life_Simulation, blob: Particle_Life_Tracked_Blob, width, height: f32) -> f32 {
	bounds := particle_life_view_bounds(sim, width, height)
	world_w := max(bounds[2] - bounds[0], 0.00001)
	world_h := max(bounds[3] - bounds[1], 0.00001)
	blob_w := max(blob.bounds[2] - blob.bounds[0], 0.0)
	blob_h := max(blob.bounds[3] - blob.bounds[1], 0.0)
	if blob_w > 0 || blob_h > 0 {
		return max(max(blob_w * width / world_w, blob_h * height / world_h) * 0.5, 8.0)
	}
	axis := f32(max(particle_life_target_analysis_grid_axis(sim.settings), 1))
	radius_world := math.sqrt(f32(max(blob.area, 1)) / PARTICLE_LIFE_PI) * (2.0 / axis)
	screen_scale := min(width / world_w, height / world_h)
	return max(radius_world * screen_scale, 8.0)
}

particle_life_draw_blob_overlay :: proc(sim: ^Particle_Life_Simulation, ctx: ^uifw.Gui_Context, width, height: f32) {
	if !sim.settings.blob_overlay_enabled || sim.blob_tracker.count == 0 || width <= 0 || height <= 0 {
		return
	}
	uifw.gui_scissor_begin(ctx, {0, 0, width, height})
	for i: u32 = 0; i < sim.blob_tracker.count; i += 1 {
		blob := sim.blob_tracker.blobs[i]
		if blob.confidence <= 0.0 {
			continue
		}
		center := particle_life_world_to_screen(sim, blob.last_position, width, height)
		radius := min(particle_life_blob_overlay_radius_px(sim, blob, width, height), max(width, height))
		alpha := max(min(blob.confidence, 1.0), 0.18)
		color := uifw.Color{0.18, 0.86, 1.0, 0.35 * alpha}
		stroke := uifw.Color{0.68, 0.96, 1.0, 0.85 * alpha}
		rect := uifw.Rect{center.x - radius, center.y - radius, radius * 2.0, radius * 2.0}
		uifw.gui_ellipse(ctx, rect, color)
		uifw.gui_ellipse_stroke(ctx, rect, stroke, 2)
		uifw.gui_line(ctx, {center.x - 5, center.y}, {center.x + 5, center.y}, stroke, 1)
		uifw.gui_line(ctx, {center.x, center.y - 5}, {center.x, center.y + 5}, stroke, 1)
	}
	uifw.gui_scissor_end(ctx)
}

particle_life_random01 :: proc(seed: ^u32) -> f32 {
	x := seed^ + 0x9e3779b9
	x = (x ~ (x >> 16)) * 0x7feb352d
	x = (x ~ (x >> 15)) * 0x846ca68b
	x = x ~ (x >> 16)
	seed^ = x
	return f32(x) / f32(0xffffffff)
}

particle_life_random_range :: proc(seed: ^u32, min_value, max_value: f32) -> f32 {
	return min_value + (max_value - min_value) * particle_life_random01(seed)
}

particle_life_hash01 :: proc(seed: u32) -> f32 {
	x := seed
	x = ((x >> 16) ~ x) * 0x45d9f3b
	x = ((x >> 16) ~ x) * 0x45d9f3b
	x = (x >> 16) ~ x
	return f32(x) / f32(0xffffffff)
}

particle_life_frac :: proc(value: f32) -> f32 {
	return value - math.floor(value)
}

particle_life_generate_position :: proc(index, species_count, position_generator: u32, seed: u32) -> [2]f32 {
	type_id := index % max(species_count, 1)
	n_types := max(species_count, 1)
	rx := particle_life_hash01(seed * 2)
	ry := particle_life_hash01(seed * 3)
	switch position_generator {
	case 1: // Center
		return {(rx * 2.0 - 1.0) * 0.3, (ry * 2.0 - 1.0) * 0.3}
	case 2: // UniformCircle
		angle := rx * PARTICLE_LIFE_TAU
		radius := math.sqrt(ry) * 0.8
		return {math.cos(angle) * radius, math.sin(angle) * radius}
	case 3: // CenteredCircle
		angle := rx * PARTICLE_LIFE_TAU
		radius := ry * 0.8
		return {math.cos(angle) * radius, math.sin(angle) * radius}
	case 4: // Ring
		angle := rx * PARTICLE_LIFE_TAU
		radius := 0.35 + 0.01 * (ry - 0.5) * 2.0
		return {math.cos(angle) * radius, math.sin(angle) * radius}
	case 5: // RainbowRing
		angle := (0.3 * (rx - 0.5) * 2.0 + f32(type_id)) / f32(n_types) * PARTICLE_LIFE_TAU
		radius := 0.35 + 0.01 * (ry - 0.5) * 2.0
		return {math.cos(angle) * radius, math.sin(angle) * radius}
	case 6: // ColorBattle
		center_angle := f32(type_id) / f32(n_types) * PARTICLE_LIFE_TAU
		angle := rx * PARTICLE_LIFE_TAU
		radius := ry * 0.05
		return {
			0.25 * math.cos(center_angle) + math.cos(angle) * radius,
			0.25 * math.sin(center_angle) + math.sin(angle) * radius,
		}
	case 7: // ColorWheel
		center_angle := f32(type_id) / f32(n_types) * PARTICLE_LIFE_TAU
		return {
			0.15 * math.cos(center_angle) + (rx - 0.5) * 2.0 * 0.1,
			0.15 * math.sin(center_angle) + (ry - 0.5) * 2.0 * 0.1,
		}
	case 8: // Line
		return {rx * 2.0 - 1.0, (ry - 0.5) * 0.3}
	case 9: // Spiral
		f := rx
		angle := 2.0 * PARTICLE_LIFE_TAU * f
		spread := 0.25 * min(f, 0.2)
		radius := 0.45 * f + spread * (ry - 0.5) * 2.0
		return {radius * math.cos(angle), radius * math.sin(angle)}
	case 10: // RainbowSpiral
		type_spread := 0.3 / f32(n_types)
		f := f32(type_id + 1) / f32(n_types + 2) + type_spread * (rx - 0.5) * 2.0
		f = max(min(f, 1.0), 0.0)
		angle := 2.0 * PARTICLE_LIFE_TAU * f
		spread := 0.25 * min(f, 0.2)
		radius := 0.45 * f + spread * (ry - 0.5) * 2.0
		return {radius * math.cos(angle), radius * math.sin(angle)}
	case:
		return {rx * 2.0 - 1.0, ry * 2.0 - 1.0}
	}
}

particle_life_generate_position_for_world :: proc(index, species_count, position_generator: u32, seed: u32, world_size: [2]f32) -> (position, normalized_position: [2]f32) {
	normalized_position = particle_life_generate_position(index, species_count, position_generator, seed)
	half_size := [2]f32{max(world_size[0], 0.0001) * 0.5, max(world_size[1], 0.0001) * 0.5}
	position = {normalized_position[0] * half_size[0], normalized_position[1] * half_size[1]}
	return
}

particle_life_generate_species :: proc(position: [2]f32, n_types, type_generator: u32, seed: u32) -> u32 {
	n := max(n_types, 1)
	switch type_generator {
	case 0: // Radial
		distance := math.sqrt(position[0] * position[0] + position[1] * position[1])
		normalized := max(min(distance / 1.41421356, 1.0), 0.0)
		return u32(normalized * f32(n)) % n
	case 1: // Polar
		angle := math.atan2(position[1], position[0])
		normalized := (angle + PARTICLE_LIFE_PI) / PARTICLE_LIFE_TAU
		return u32(normalized * f32(n)) % n
	case 2: // StripesH
		normalized_y := (position[1] + 1.0) * 0.5
		return u32(normalized_y * f32(n)) % n
	case 3: // StripesV
		normalized_x := (position[0] + 1.0) * 0.5
		return u32(normalized_x * f32(n)) % n
	case 5: // LineH
		if math.abs(position[1]) < 0.1 {
			return 0
		}
		normalized_y := (position[1] + 1.0) * 0.5
		return (u32(normalized_y * f32(max(n - 1, 1))) + 1) % n
	case 6: // LineV
		if math.abs(position[0]) < 0.1 {
			return 0
		}
		normalized_x := (position[0] + 1.0) * 0.5
		return (u32(normalized_x * f32(max(n - 1, 1))) + 1) % n
	case 7: // Spiral
		distance := math.sqrt(position[0] * position[0] + position[1] * position[1])
		angle := math.atan2(position[1], position[0])
		spiral_value := distance + angle * 0.159
		return u32(particle_life_frac(spiral_value * 2.0) * f32(n)) % n
	case 8: // Dithered
		distance := math.sqrt(position[0] * position[0] + position[1] * position[1])
		band_value := distance * f32(n)
		base_band := u32(math.floor(band_value))
		noise_seed := u32((position[0] + 1.0) * 1000.0) + u32((position[1] + 1.0) * 1000.0) + seed
		noise := particle_life_hash01(noise_seed)
		band_fraction := particle_life_frac(band_value)
		if band_fraction > 0.8 && noise > 0.5 {
			return (base_band + 1) % n
		} else if band_fraction < 0.2 && noise < 0.5 {
			return (base_band + n - 1) % n
		}
		return base_band % n
	case 9: // WavyLineH
		normalized_y := (position[1] + 1.0) * 0.5
		line_spacing := 1.0 / f32(n)
		for i: u32 = 0; i < n; i += 1 {
			line_center := (f32(i) + 0.5) * line_spacing
			line_y := line_center + math.sin(position[0] * 2.5 * PARTICLE_LIFE_PI) * 0.25
			if math.abs(normalized_y - line_y) < 0.08 {
				return i
			}
		}
		return u32(normalized_y * f32(n)) % n
	case 10: // WavyLineV
		normalized_x := (position[0] + 1.0) * 0.5
		line_spacing := 1.0 / f32(n)
		for i: u32 = 0; i < n; i += 1 {
			line_center := (f32(i) + 0.5) * line_spacing
			line_x := line_center + math.sin(position[1] * 2.5 * PARTICLE_LIFE_PI) * 0.25
			if math.abs(normalized_x - line_x) < 0.08 {
				return i
			}
		}
		return u32(normalized_x * f32(n)) % n
	case:
		return u32(particle_life_hash01(seed * 4) * f32(n)) % n
	}
}

particle_life_force_clamp :: proc(value: f32) -> f32 {
	return max(min(value, 1.0), -1.0)
}

particle_life_force_random_bool :: proc(seed: ^u32, probability: f32) -> bool {
	return particle_life_random01(seed) < probability
}

particle_life_force_random_int :: proc(seed: ^u32, min_value, max_value: int) -> int {
	if max_value <= min_value {
		return min_value
	}
	span := max_value - min_value + 1
	return min_value + int(particle_life_random01(seed) * f32(span)) % span
}

particle_life_force_species_distance :: proc(i, j: int) -> int {
	if i > j {
		return i - j
	}
	return j - i
}

particle_life_force_species_prime :: proc(n: int) -> bool {
	if n < 2 {
		return false
	}
	limit := int(math.sqrt(f32(n)))
	for i in 2 ..= limit {
		if n % i == 0 {
			return false
		}
	}
	return true
}

particle_life_force_matrix_set :: proc(force_values: ^[PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32, row, col, species_count: int, value: f32) {
	if row < 0 || col < 0 || row >= species_count || col >= species_count {
		return
	}
	force_values[row * PARTICLE_LIFE_MAX_SPECIES + col] = particle_life_force_clamp(value)
}

particle_life_generate_force_matrix :: proc(
	force_values: ^[PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32,
	species_count: u32,
	force_generator: u32,
	random_min, random_max: f32,
	base_seed: u32,
) {
	n := int(max(min(species_count, PARTICLE_LIFE_MAX_SPECIES), 1))
	seed := base_seed
	for i in 0 ..< len(force_values) {
		force_values[i] = 0
	}
	set :: proc(force_values: ^[PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32, n, i, j: int, value: f32) {
		particle_life_force_matrix_set(force_values, i, j, n, value)
	}
	rr :: proc(seed: ^u32, min_value, max_value: f32) -> f32 {
		return particle_life_random_range(seed, min_value, max_value)
	}

	switch force_generator {
	case 1: // Symmetry
		base_strength := rr(&seed, 0.3, 0.8)
		variation := rr(&seed, 0.1, 0.4)
		for i in 0 ..< n {
			for j in i ..< n {
				value: f32
				if i == j {
					value = rr(&seed, -0.3, -0.05)
				} else {
					sign: f32 = particle_life_force_random_bool(&seed, 0.5) ? 1.0 : -1.0
					value = sign * rr(&seed, 0.2, base_strength) + rr(&seed, -variation, variation)
				}
				set(force_values, n, i, j, value)
				if i != j do set(force_values, n, j, i, value)
			}
		}
	case 2: // Chains
		chain_strength := rr(&seed, 0.3, 0.7)
		self_repulsion := rr(&seed, -0.3, -0.05)
		background_strength := rr(&seed, -0.2, 0.1)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := background_strength + rr(&seed, -0.05, 0.05)
				if i == j {
					value = self_repulsion
				} else if particle_life_force_species_distance(i, j) == 1 {
					value = chain_strength + rr(&seed, -0.1, 0.1)
				}
				set(force_values, n, i, j, value)
			}
		}
	case 3: // Chains 2
		near_strength := rr(&seed, 0.2, 0.6)
		far_strength := rr(&seed, -0.3, 0.1)
		self_repulsion := rr(&seed, -0.4, -0.1)
		for i in 0 ..< n {
			for j in 0 ..< n {
				distance := particle_life_force_species_distance(i, j)
				value := rr(&seed, -0.1, 0.05)
				if i == j {
					value = self_repulsion
				} else if distance == 1 {
					value = near_strength + rr(&seed, -0.15, 0.15)
				} else if distance == 2 {
					value = far_strength + rr(&seed, -0.1, 0.1)
				}
				set(force_values, n, i, j, value)
			}
		}
	case 4: // Chains 3
		decay_rate := rr(&seed, 0.6, 0.9)
		base_strength := rr(&seed, 0.3, 0.6)
		self_repulsion := rr(&seed, -0.3, -0.05)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := self_repulsion
				if i != j {
					distance := f32(particle_life_force_species_distance(i, j))
					value = particle_life_force_clamp(base_strength * math.pow(decay_rate, distance) + rr(&seed, -0.1, 0.1))
				}
				set(force_values, n, i, j, value)
			}
		}
	case 5: // Snakes
		snake_strength := rr(&seed, 0.2, 0.5)
		end_connection_strength := rr(&seed, 0.1, 0.4)
		self_repulsion := rr(&seed, -0.3, -0.05)
		background_strength := rr(&seed, -0.1, 0.05)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := background_strength + rr(&seed, -0.05, 0.05)
				if i == j {
					value = self_repulsion
				} else if i == 0 && j == n - 1 {
					value = end_connection_strength + rr(&seed, -0.1, 0.1)
				} else if particle_life_force_species_distance(i, j) == 1 {
					value = snake_strength + rr(&seed, -0.1, 0.1)
				}
				set(force_values, n, i, j, value)
			}
		}
	case 6: // Zero
		for i in 0 ..< n {
			for j in 0 ..< n {
				set(force_values, n, i, j, rr(&seed, -0.01, 0.01))
			}
		}
	case 7: // Predator Prey
		for i in 0 ..< n {
			for j in 0 ..< n {
				value: f32 = 0
				if i == j {
					value = -0.1
				} else if j == (i + 1) % n {
					value = 0.4
				} else if i == (j + 1) % n {
					value = -0.3
				}
				set(force_values, n, i, j, value)
			}
		}
	case 8: // Symbiosis
		symbiosis_strength := rr(&seed, 0.4, 0.8)
		self_repulsion := rr(&seed, -0.3, -0.05)
		background_strength := rr(&seed, -0.1, 0.1)
		for i in 0 ..< n {
			for j in i ..< n {
				value := background_strength + rr(&seed, -0.05, 0.05)
				if i == j {
					value = self_repulsion
				} else if (i % 2 == 0 && j == i + 1) || (j % 2 == 0 && i == j + 1) {
					value = symbiosis_strength + rr(&seed, -0.1, 0.1)
				}
				set(force_values, n, i, j, value)
				if i != j do set(force_values, n, j, i, value)
			}
		}
	case 9: // Territorial
		self_repulsion := rr(&seed, -0.9, -0.5)
		other_repulsion_base := rr(&seed, -0.5, -0.1)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := i == j ? self_repulsion : other_repulsion_base + rr(&seed, -0.2, 0.2)
				set(force_values, n, i, j, value)
			}
		}
	case 10: // Magnetic
		attraction_strength := rr(&seed, 0.2, 0.6)
		repulsion_strength := rr(&seed, -0.6, -0.2)
		self_repulsion := rr(&seed, -0.3, -0.05)
		for i in 0 ..< n {
			for j in i ..< n {
				value := self_repulsion
				if i != j {
					same_charge := (i % 2 == 0) == (j % 2 == 0)
					value = (same_charge ? attraction_strength : repulsion_strength) + rr(&seed, -0.1, 0.1)
				}
				set(force_values, n, i, j, value)
				if i != j do set(force_values, n, j, i, value)
			}
		}
	case 11: // Crystal
		lattice_strength := rr(&seed, 0.4, 0.8)
		self_repulsion := rr(&seed, -0.4, -0.1)
		background_strength := rr(&seed, -0.2, 0.05)
		lattice_variation := rr(&seed, 0.05, 0.2)
		for i in 0 ..< n {
			for j in i ..< n {
				neighbors := particle_life_force_species_distance(i, j) == 1 || (i == 0 && j == n - 1) || (j == 0 && i == n - 1)
				value := background_strength + rr(&seed, -0.1, 0.1)
				if i == j {
					value = self_repulsion
				} else if neighbors {
					value = lattice_strength + rr(&seed, -lattice_variation, lattice_variation)
				}
				set(force_values, n, i, j, value)
				if i != j do set(force_values, n, j, i, value)
			}
		}
	case 12: // Wave
		amplitude := rr(&seed, 0.3, 0.7)
		frequency := rr(&seed, 0.5, 2.0)
		phase := rr(&seed, 0.0, PARTICLE_LIFE_TAU)
		self_repulsion := rr(&seed, -0.3, -0.05)
		for i in 0 ..< n {
			for j in i ..< n {
				value := self_repulsion
				if i != j {
					distance := f32(particle_life_force_species_distance(i, j))
					value = math.sin(distance * frequency + phase) * amplitude + rr(&seed, -0.1, 0.1)
				}
				set(force_values, n, i, j, value)
				if i != j do set(force_values, n, j, i, value)
			}
		}
	case 13: // Hierarchy
		hierarchy_strength := rr(&seed, 0.2, 0.5)
		self_repulsion := rr(&seed, -0.3, -0.05)
		background_strength := rr(&seed, -0.05, 0.05)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := background_strength + rr(&seed, -0.05, 0.05)
				if i == j {
					value = self_repulsion
				} else if i < j {
					value = hierarchy_strength + rr(&seed, -0.1, 0.1)
				}
				set(force_values, n, i, j, value)
			}
		}
	case 14, 15: // Clique / Anti-Clique
		group_size := particle_life_force_random_int(&seed, 2, max(n / 2, 2))
		self_repulsion := rr(&seed, -0.3, -0.05)
		inside := force_generator == 14 ? rr(&seed, 0.3, 0.7) : rr(&seed, -0.7, -0.3)
		outside := force_generator == 14 ? rr(&seed, -0.4, -0.1) : rr(&seed, 0.2, 0.5)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := self_repulsion
				if i != j {
					value = ((i / group_size) == (j / group_size) ? inside : outside) + rr(&seed, -0.1, 0.1)
				}
				set(force_values, n, i, j, value)
			}
		}
	case 16: // Fibonacci
		fib: [PARTICLE_LIFE_MAX_SPECIES]int
		fib[0] = 1
		fib[1] = 1
		for k in 2 ..< n {
			fib[k] = fib[k - 1] + fib[k - 2]
		}
		max_fib := f32(max(fib[max(n - 1, 0)], 1))
		scale_factor := rr(&seed, 0.5, 1.5)
		self_repulsion := rr(&seed, -0.3, -0.05)
		base_offset := rr(&seed, -0.2, 0.2)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := self_repulsion
				if i != j {
					distance := particle_life_force_species_distance(i, j)
					base_force := (f32(max(fib[distance], 1)) / max_fib) * scale_factor + base_offset
					value = base_force + rr(&seed, -0.1, 0.1)
				}
				set(force_values, n, i, j, value)
			}
		}
	case 17: // Prime
		prime_attraction := rr(&seed, 0.4, 0.8)
		mixed_attraction := rr(&seed, 0.1, 0.4)
		non_prime_repulsion := rr(&seed, -0.2, -0.05)
		self_repulsion := rr(&seed, -0.3, -0.05)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := self_repulsion
				if i != j {
					i_prime := particle_life_force_species_prime(i)
					j_prime := particle_life_force_species_prime(j)
					if i_prime && j_prime {
						value = prime_attraction + rr(&seed, -0.1, 0.1)
					} else if i_prime || j_prime {
						value = mixed_attraction + rr(&seed, -0.1, 0.1)
					} else {
						value = non_prime_repulsion + rr(&seed, -0.05, 0.05)
					}
				}
				set(force_values, n, i, j, value)
			}
		}
	case 18: // Fractal
		scale_factor := rr(&seed, 0.3, 0.7)
		frequency := rr(&seed, 2.0, 4.0)
		self_repulsion := rr(&seed, -0.3, -0.05)
		base_offset := rr(&seed, -0.1, 0.1)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := self_repulsion
				if i != j {
					distance := f32(particle_life_force_species_distance(i, j))
					normalized_distance := distance / max(f32(n - 1), 1.0)
					scale := math.log2(normalized_distance * frequency + 1.0)
					value = math.sin(scale * PARTICLE_LIFE_PI) * scale_factor + base_offset + rr(&seed, -0.1, 0.1)
				}
				set(force_values, n, i, j, value)
			}
		}
	case 19: // Rock Paper Scissors
		for i in 0 ..< n {
			for j in 0 ..< n {
				value: f32 = 0
				if i == j {
					value = -0.1
				} else if j == (i + 1) % n {
					value = 0.4
				} else if i == (j + 1) % n {
					value = -0.2
				}
				set(force_values, n, i, j, value)
			}
		}
	case 20, 21: // Cooperation / Competition
		mutual_strength := force_generator == 20 ? rr(&seed, 0.1, 0.4) : rr(&seed, -0.4, -0.1)
		self_repulsion := rr(&seed, -0.3, -0.05)
		for i in 0 ..< n {
			for j in i ..< n {
				value := i == j ? self_repulsion : mutual_strength + rr(&seed, -0.1, 0.1)
				set(force_values, n, i, j, value)
				if i != j do set(force_values, n, j, i, value)
			}
		}
	case:
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := rr(&seed, random_min, random_max)
				set(force_values, n, i, j, value)
			}
		}
	}
}

particle_life_force_hash :: proc(seed: u32) -> u32 {
	x := seed
	x = ((x >> 16) ~ x) * 0x45d9f3b
	x = ((x >> 16) ~ x) * 0x45d9f3b
	x = (x >> 16) ~ x
	return x
}

particle_life_force_random01 :: proc(seed: u32) -> f32 {
	return f32(particle_life_force_hash(seed)) / f32(0xffffffff)
}

particle_life_mirror_force_randomize :: proc(sim: ^Particle_Life_Simulation) {
	species_count := int(max(min(sim.settings.species_count, PARTICLE_LIFE_MAX_SPECIES), 1))
	generated_matrix: [PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32
	particle_life_generate_force_matrix(&generated_matrix, u32(species_count), sim.settings.force_generator, sim.settings.force_random_min, sim.settings.force_random_max, sim.runtime.seed)
	for a in 0 ..< species_count {
		for b in 0 ..< species_count {
			value := generated_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b]
			sim.runtime.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = value
			sim.settings.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = value
		}
	}
	sim.settings.custom_force_matrix = true
	sim.runtime.force_matrix_dirty = true
}

particle_life_force_value :: proc(sim: ^Particle_Life_Simulation, species_a, species_b: u32) -> f32 {
	a := min(species_a, PARTICLE_LIFE_MAX_SPECIES - 1)
	b := min(species_b, PARTICLE_LIFE_MAX_SPECIES - 1)
	return sim.runtime.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b]
}

particle_life_force_curve_value :: proc(max_force, max_distance, beta, distance: f32) -> f32 {
	min_dist := f32(0.001)
	beta_rmax := beta * max(max_distance, min_dist)
	if distance < beta_rmax {
		effective_distance := max(distance, min_dist)
		return (effective_distance / beta_rmax - 1.0) * max_force
	}
	if distance <= max_distance {
		return max_force * 0.5 * (1.0 - (1.0 + beta - (2.0 * distance) / max(max_distance, min_dist)) / max(1.0 - beta, 0.0001))
	}
	return 0
}

particle_life_force_matrix_color :: proc(value: f32) -> uifw.Color {
	amount := abs(value)
	if amount < 0.1 {
		return {0.54, 0.54, 0.54, 0.86}
	}
	if value < 0 {
		if amount < 0.3 do return {0.23, 0.51, 0.96, 0.88}
		if amount < 0.7 do return {0.15, 0.39, 0.92, 0.92}
		return {0.11, 0.31, 0.85, 0.96}
	}
	if amount < 0.3 do return {0.94, 0.27, 0.27, 0.88}
	if amount < 0.7 do return {0.86, 0.15, 0.15, 0.92}
	return {0.73, 0.11, 0.11, 0.96}
}

particle_life_force_matrix_upload_existing :: proc(sim: ^Particle_Life_Simulation, species_count: u32) {
	sim.settings.custom_force_matrix = true
	sim.runtime.force_matrix_dirty = true
	sim.runtime.pending_force_update = false
}

Particle_Life_Matrix_Transform :: enum {
	Scale_Down,
	Scale_Up,
	Rotate_CCW,
	Rotate_CW,
	Flip_H,
	Flip_V,
	Shift_Left,
	Shift_Right,
	Shift_Up,
	Shift_Down,
	Zero,
	Flip_Sign,
}

particle_life_apply_matrix_transform :: proc(sim: ^Particle_Life_Simulation, transform: Particle_Life_Matrix_Transform) {
	n := int(max(min(sim.settings.species_count, PARTICLE_LIFE_MAX_SPECIES), 1))
	old := sim.runtime.force_matrix
	new_matrix := old
	for i in 0 ..< n {
		for j in 0 ..< n {
			dst := i * PARTICLE_LIFE_MAX_SPECIES + j
			if i == j {
				new_matrix[dst] = old[dst]
				continue
			}
			switch transform {
			case .Scale_Down:
				new_matrix[dst] = max(min(old[dst] * 0.8, 1), -1)
			case .Scale_Up:
				new_matrix[dst] = max(min(old[dst] * 1.2, 1), -1)
			case .Rotate_CCW:
				new_matrix[dst] = old[j * PARTICLE_LIFE_MAX_SPECIES + (n - 1 - i)]
			case .Rotate_CW:
				new_matrix[dst] = old[(n - 1 - j) * PARTICLE_LIFE_MAX_SPECIES + i]
			case .Flip_H:
				new_matrix[dst] = old[i * PARTICLE_LIFE_MAX_SPECIES + (n - 1 - j)]
			case .Flip_V:
				new_matrix[dst] = old[(n - 1 - i) * PARTICLE_LIFE_MAX_SPECIES + j]
			case .Shift_Left:
				new_matrix[dst] = old[i * PARTICLE_LIFE_MAX_SPECIES + ((j - 1 + n) % n)]
			case .Shift_Right:
				new_matrix[dst] = old[i * PARTICLE_LIFE_MAX_SPECIES + ((j + 1) % n)]
			case .Shift_Up:
				new_matrix[dst] = old[((i - 1 + n) % n) * PARTICLE_LIFE_MAX_SPECIES + j]
			case .Shift_Down:
				new_matrix[dst] = old[((i + 1) % n) * PARTICLE_LIFE_MAX_SPECIES + j]
			case .Zero:
				new_matrix[dst] = 0
			case .Flip_Sign:
				new_matrix[dst] = -old[dst]
			}
		}
	}
	sim.runtime.force_matrix = new_matrix
	for i in 0 ..< len(sim.settings.force_matrix) {
		sim.settings.force_matrix[i] = sim.runtime.force_matrix[i]
	}
	particle_life_force_matrix_upload_existing(sim, u32(n))
}

particle_life_set_force_value :: proc(sim: ^Particle_Life_Simulation, species_a, species_b: u32, value: f32) {
	a := min(species_a, PARTICLE_LIFE_MAX_SPECIES - 1)
	b := min(species_b, PARTICLE_LIFE_MAX_SPECIES - 1)
	sim.runtime.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = value
	sim.settings.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = value
	sim.settings.custom_force_matrix = true
	sim.runtime.pending_force_update = true
	sim.runtime.pending_force_a = a
	sim.runtime.pending_force_b = b
	sim.runtime.pending_force_value = value
}

particle_life_note_trail_camera :: proc(sim: ^Particle_Life_Simulation) {
	zoom := max(sim.runtime.camera_zoom, 0.25)
	if !sim.runtime.trail_camera_valid {
		sim.runtime.trail_camera_x = sim.runtime.camera_x
		sim.runtime.trail_camera_y = sim.runtime.camera_y
		sim.runtime.trail_camera_zoom = zoom
		sim.runtime.trail_camera_valid = true
		return
	}
	epsilon := f32(0.00001)
	camera_changed :=
		math.abs(sim.runtime.camera_x - sim.runtime.trail_camera_x) > epsilon ||
		math.abs(sim.runtime.camera_y - sim.runtime.trail_camera_y) > epsilon ||
		math.abs(zoom - sim.runtime.trail_camera_zoom) > epsilon
	if camera_changed {
		sim.gpu.trail_initialized = false
		sim.runtime.trail_camera_x = sim.runtime.camera_x
		sim.runtime.trail_camera_y = sim.runtime.camera_y
		sim.runtime.trail_camera_zoom = zoom
	}
}

particle_life_tile_index_floor :: proc(value: f32) -> i32 {
	return i32(math.floor(value))
}

particle_life_tile_range_for_bounds :: proc(bounds: [4]f32, camera_x, camera_y: f32, radius_value: u32, tile_size: [2]f32) -> Particle_Life_Tile_Range {
	tile_w := max(tile_size[0], 0.0001)
	tile_h := max(tile_size[1], 0.0001)
	half_w := tile_w * 0.5
	half_h := tile_h * 0.5
	min_x := particle_life_tile_index_floor((bounds[0] - half_w) / tile_w)
	max_x := particle_life_tile_index_floor((bounds[2] + half_w) / tile_w)
	min_y := particle_life_tile_index_floor((bounds[1] - half_h) / tile_h)
	max_y := particle_life_tile_index_floor((bounds[3] + half_h) / tile_h)
	center_x := particle_life_tile_index_floor(camera_x / tile_w + 0.5)
	center_y := particle_life_tile_index_floor(camera_y / tile_h + 0.5)
	radius := i32(max(min(radius_value, 32), 0))
	return {
		min_x = max(min_x, center_x - radius),
		max_x = min(max_x, center_x + radius),
		min_y = max(min_y, center_y - radius),
		max_y = min(max_y, center_y + radius),
	}
}

particle_life_tile_bounds_for_offset :: proc(bounds: [4]f32, tile_x, tile_y: i32, tile_size: [2]f32) -> [4]f32 {
	offset_x := f32(tile_x) * tile_size[0]
	offset_y := f32(tile_y) * tile_size[1]
	return {
		bounds[0] - offset_x,
		bounds[1] - offset_y,
		bounds[2] - offset_x,
		bounds[3] - offset_y,
	}
}

particle_life_reset_runtime :: proc(sim: ^Particle_Life_Simulation) {
	particle_life_clear_preserved_particles(sim)
	sim.runtime.frame_index = 0
	sim.runtime.seed += 0x9e3779b9
	if sim.runtime.seed == 0 {
		sim.runtime.seed = 0x3c6ef372
	}
	sim.runtime.needs_reset = true
}

particle_life_clear_preserved_particles :: proc(sim: ^Particle_Life_Simulation) {
	if sim.runtime.preserved_particles != nil {
		delete(sim.runtime.preserved_particles)
	}
	sim.runtime.preserved_particles = nil
}

particle_life_request_resource_rebuild :: proc(sim: ^Particle_Life_Simulation) {
	if !sim.runtime.needs_reset && sim.gpu.particle_buffer.mapped != nil && sim.gpu.uploaded_particle_count > 0 && sim.gpu.uploaded_particle_count == particle_life_target_particle_count(sim.settings) && sim.gpu.uploaded_species_count == particle_life_target_species_count(sim.settings) {
		particle_life_clear_preserved_particles(sim)
		count := int(sim.gpu.uploaded_particle_count)
		sim.runtime.preserved_particles = make([]Particle_Life_Particle, count)
		particles := (cast([^]Particle_Life_Particle)sim.gpu.particle_buffer.mapped)[:count]
		copy(sim.runtime.preserved_particles, particles)
	}
	sim.gpu.ready = false
}

particle_life_reset_camera :: proc(sim: ^Particle_Life_Simulation) {
	camera := particle_life_camera_control_state(sim)
	camera_controls_reset(&camera)
	particle_life_store_camera_control_state(sim, camera)
}

particle_life_blob_tracker_reset :: proc(tracker: ^Particle_Life_Blob_Tracker) {
	tracker^ = {next_id = 1}
}

particle_life_analysis_workspace_destroy :: proc(workspace: ^Particle_Life_Analysis_Workspace) {
	if workspace.cells != nil {
		delete(workspace.cells)
	}
	if workspace.coherence != nil {
		delete(workspace.coherence)
	}
	if workspace.labels != nil {
		delete(workspace.labels)
	}
	if workspace.queue != nil {
		delete(workspace.queue)
	}
	workspace^ = {}
}

particle_life_analysis_workspace_ensure :: proc(workspace: ^Particle_Life_Analysis_Workspace, axis: u32) -> bool {
	cell_count := int(axis * axis)
	if axis == 0 || cell_count <= 0 {
		return false
	}
	if workspace.axis == axis && len(workspace.cells) == cell_count {
		return true
	}
	particle_life_analysis_workspace_destroy(workspace)
	workspace.axis = axis
	workspace.cells = make([]Particle_Life_Analysis_Cell, cell_count)
	workspace.coherence = make([]f32, cell_count)
	workspace.labels = make([]u32, cell_count)
	workspace.queue = make([]u32, cell_count)
	return workspace.cells != nil && workspace.coherence != nil && workspace.labels != nil && workspace.queue != nil
}

particle_life_smoothstep :: proc(edge0, edge1, x: f32) -> f32 {
	if edge0 == edge1 {
		return x >= edge1 ? 1 : 0
	}
	t := max(min((x - edge0) / (edge1 - edge0), 1.0), 0.0)
	return t * t * (3.0 - 2.0 * t)
}

particle_life_analysis_cell_index :: proc(x, y, axis: u32) -> u32 {
	return y * axis + x
}

particle_life_analysis_particle_coord :: proc(value, world_min, world_size: f32, axis: u32) -> u32 {
	normalized := max(min((value - world_min) / max(world_size, 0.0001), 0.999999), 0.0)
	return min(u32(normalized * f32(axis)), axis - 1)
}

particle_life_analysis_cell_center :: proc(x, y, axis: u32, world_size: [2]f32) -> [2]f32 {
	cell_w := world_size[0] / f32(axis)
	cell_h := world_size[1] / f32(axis)
	return {
		-world_size[0] * 0.5 + (f32(x) + 0.5) * cell_w,
		-world_size[1] * 0.5 + (f32(y) + 0.5) * cell_h,
	}
}

particle_life_analysis_compute_coherence :: proc(workspace: ^Particle_Life_Analysis_Workspace, axis: u32) {
	for y: u32 = 0; y < axis; y += 1 {
		for x: u32 = 0; x < axis; x += 1 {
			index := particle_life_analysis_cell_index(x, y, axis)
			cell := workspace.cells[index]
			if cell.density <= 0 {
				workspace.coherence[index] = 0
				continue
			}

			neighbor_density: f32
			neighbor_velocity := [2]f32{}
			neighbor_count: f32
			for oy := -1; oy <= 1; oy += 1 {
				for ox := -1; ox <= 1; ox += 1 {
					nx := i32(x) + i32(ox)
					ny := i32(y) + i32(oy)
					if nx < 0 || ny < 0 || nx >= i32(axis) || ny >= i32(axis) {
						continue
					}
					neighbor := workspace.cells[particle_life_analysis_cell_index(u32(nx), u32(ny), axis)]
					if neighbor.density <= 0 {
						continue
					}
					neighbor_density += neighbor.density
					neighbor_velocity[0] += neighbor.velocity_sum[0]
					neighbor_velocity[1] += neighbor.velocity_sum[1]
					neighbor_count += 1
				}
			}

			avg_velocity := [2]f32{cell.velocity_sum[0] / cell.density, cell.velocity_sum[1] / cell.density}
			avg_neighbor_velocity := [2]f32{}
			if neighbor_density > 0 {
				avg_neighbor_velocity = {neighbor_velocity[0] / neighbor_density, neighbor_velocity[1] / neighbor_density}
			}
			speed := math.sqrt(avg_velocity[0] * avg_velocity[0] + avg_velocity[1] * avg_velocity[1])
			neighbor_speed := math.sqrt(avg_neighbor_velocity[0] * avg_neighbor_velocity[0] + avg_neighbor_velocity[1] * avg_neighbor_velocity[1])
			alignment := f32(0.65)
			if speed > 0.00001 && neighbor_speed > 0.00001 {
				alignment = (avg_velocity[0] * avg_neighbor_velocity[0] + avg_velocity[1] * avg_neighbor_velocity[1]) / (speed * neighbor_speed)
				alignment = max(min(alignment * 0.5 + 0.5, 1.0), 0.0)
			}

			neighbor_average_density := neighbor_density / max(neighbor_count, 1.0)
			boundary_strength := math.abs(cell.density - neighbor_average_density) / max(cell.density, 1.0)
			boundary_score := max(min(boundary_strength * 1.5 + 0.50, 1.0), 0.50)
			density_score := particle_life_smoothstep(0.75, 4.0, cell.density)
			workspace.coherence[index] = density_score * alignment * boundary_score
		}
	}
}

particle_life_analysis_flush_component :: proc(
	workspace: ^Particle_Life_Analysis_Workspace,
	axis: u32,
	label: u32,
	start_index: u32,
	min_blob_area_cells: u32,
	world_size: [2]f32,
	out_summaries: ^[128]Particle_Life_Blob_Summary,
	out_count: ^u32,
) {
	read_index: u32
	write_index: u32 = 1
	workspace.queue[0] = start_index
	workspace.labels[start_index] = label

	summary: Particle_Life_Blob_Summary
	summary.id = label
	summary.bounds = {1, 1, -1, -1}
	weighted_position := [2]f32{}
	velocity_sum := [2]f32{}
	coherence_sum: f32

	for read_index < write_index {
		index := workspace.queue[read_index]
		read_index += 1
		cell := workspace.cells[index]
		x := index % axis
		y := index / axis
		center := particle_life_analysis_cell_center(x, y, axis, world_size)

		summary.area += 1
		summary.density += cell.density
		weighted_position[0] += center[0] * cell.density
		weighted_position[1] += center[1] * cell.density
		velocity_sum[0] += cell.velocity_sum[0]
		velocity_sum[1] += cell.velocity_sum[1]
		coherence_sum += workspace.coherence[index]
		summary.bounds[0] = min(summary.bounds[0], center[0])
		summary.bounds[1] = min(summary.bounds[1], center[1])
		summary.bounds[2] = max(summary.bounds[2], center[0])
		summary.bounds[3] = max(summary.bounds[3], center[1])
		for species in 0 ..< PARTICLE_LIFE_MAX_SPECIES {
			summary.species_histogram[species] += cell.species_histogram[species]
		}

		neighbors := [4]i32{-1, 1, -i32(axis), i32(axis)}
		for n in 0 ..< len(neighbors) {
			if neighbors[n] == -1 && x == 0 {
				continue
			}
			if neighbors[n] == 1 && x + 1 >= axis {
				continue
			}
			if neighbors[n] == -i32(axis) && y == 0 {
				continue
			}
			if neighbors[n] == i32(axis) && y + 1 >= axis {
				continue
			}
			next := u32(i32(index) + neighbors[n])
			if workspace.labels[next] != 0 || workspace.coherence[next] <= 0 {
				continue
			}
			workspace.labels[next] = label
			workspace.queue[write_index] = next
			write_index += 1
		}
	}

	if summary.area < min_blob_area_cells || out_count^ >= u32(len(out_summaries^)) {
		return
	}
	weight := max(summary.density, 0.00001)
	summary.centroid = {weighted_position[0] / weight, weighted_position[1] / weight}
	summary.velocity = {velocity_sum[0] / weight, velocity_sum[1] / weight}
	summary.coherence_score = coherence_sum / f32(max(summary.area, 1))
	out_summaries^[out_count^] = summary
	out_count^ += 1
}

particle_life_analyze_particles :: proc(
	workspace: ^Particle_Life_Analysis_Workspace,
	particles: []Particle_Life_Particle,
	species_count: u32,
	grid_axis: u32,
	min_blob_area_cells: u32,
	coherence_threshold: f32,
	world_size: [2]f32,
) -> []Particle_Life_Blob_Summary {
	axis := max(min(grid_axis, 1024), 4)
	if !particle_life_analysis_workspace_ensure(workspace, axis) {
		return nil
	}
	cell_count := int(axis * axis)
	for i in 0 ..< cell_count {
		workspace.cells[i] = {}
		workspace.coherence[i] = 0
		workspace.labels[i] = 0
	}
	workspace.summaries = {}
	world_min_x := -world_size[0] * 0.5
	world_min_y := -world_size[1] * 0.5

	for particle in particles {
		x := particle_life_analysis_particle_coord(particle.position[0], world_min_x, world_size[0], axis)
		y := particle_life_analysis_particle_coord(particle.position[1], world_min_y, world_size[1], axis)
		index := particle_life_analysis_cell_index(x, y, axis)
		cell := &workspace.cells[index]
		cell.density += 1
		cell.velocity_sum[0] += particle.velocity[0]
		cell.velocity_sum[1] += particle.velocity[1]
		speed := math.sqrt(particle.velocity[0] * particle.velocity[0] + particle.velocity[1] * particle.velocity[1])
		cell.speed_sum += speed
		species := min(particle.species, PARTICLE_LIFE_MAX_SPECIES - 1)
		if species < species_count {
			cell.species_histogram[species] += 1
		}
	}

	particle_life_analysis_compute_coherence(workspace, axis)
	threshold := max(min(coherence_threshold, 1.0), 0.0)
	for i in 0 ..< cell_count {
		if workspace.coherence[i] < threshold {
			workspace.coherence[i] = 0
		}
	}

	label: u32 = 1
	out_count: u32
	for i in 0 ..< cell_count {
		if workspace.labels[i] != 0 || workspace.coherence[i] <= 0 {
			continue
		}
		particle_life_analysis_flush_component(workspace, axis, label, u32(i), max(min_blob_area_cells, 1), world_size, &workspace.summaries, &out_count)
		label += 1
		if label == 0 {
			label = 1
		}
	}
	return workspace.summaries[:out_count]
}

particle_life_maybe_run_blob_analysis :: proc(sim: ^Particle_Life_Simulation) {
	if !sim.settings.analysis_enabled || sim.gpu.particle_buffer.mapped == nil || sim.gpu.uploaded_particle_count == 0 {
		return
	}
	interval := u64(max(sim.settings.analysis_interval_frames, 1))
	if sim.runtime.frame_index == sim.runtime.last_analysis_frame || (sim.runtime.frame_index % interval) != 0 {
		return
	}
	particles := (cast([^]Particle_Life_Particle)sim.gpu.particle_buffer.mapped)[:sim.gpu.uploaded_particle_count]
	summaries := particle_life_analyze_particles(
		&sim.runtime.analysis,
		particles,
		sim.gpu.uploaded_species_count,
		sim.settings.analysis_grid_size,
		sim.settings.min_blob_area_cells,
		sim.settings.coherence_threshold,
		particle_life_world_size(sim),
	)
	particle_life_blob_tracker_update(&sim.blob_tracker, summaries)
	sim.runtime.last_analysis_frame = sim.runtime.frame_index
}

particle_life_blob_distance_sq :: proc(a, b: [2]f32) -> f32 {
	dx := a[0] - b[0]
	dy := a[1] - b[1]
	return dx * dx + dy * dy
}

particle_life_blob_histogram_similarity :: proc(a, b: [PARTICLE_LIFE_MAX_SPECIES]u32) -> f32 {
	intersection: u32
	total: u32
	for i in 0 ..< PARTICLE_LIFE_MAX_SPECIES {
		intersection += min(a[i], b[i])
		total += max(a[i], b[i])
	}
	if total == 0 {
		return 1
	}
	return f32(intersection) / f32(total)
}

particle_life_blob_match_score :: proc(blob: Particle_Life_Tracked_Blob, summary: Particle_Life_Blob_Summary) -> f32 {
	position_distance := math.sqrt(particle_life_blob_distance_sq(blob.predicted_position, summary.centroid))
	position_score := max(1.0 - position_distance / 0.35, 0.0)
	velocity_distance := math.sqrt(particle_life_blob_distance_sq(blob.velocity, summary.velocity))
	velocity_score := max(1.0 - velocity_distance / 0.6, 0.0)
	area_a := f32(max(blob.area, 1))
	area_b := f32(max(summary.area, 1))
	area_score := min(area_a, area_b) / max(area_a, area_b)
	histogram_score := particle_life_blob_histogram_similarity(blob.species_histogram, summary.species_histogram)
	return position_score * 0.45 + velocity_score * 0.20 + area_score * 0.20 + histogram_score * 0.15
}

particle_life_blob_tracker_update_one :: proc(tracker: ^Particle_Life_Blob_Tracker, blob_index: int, summary: Particle_Life_Blob_Summary) {
	blob := &tracker.blobs[blob_index]
	blob.age += 1
	blob.missed_frames = 0
	blob.velocity = summary.velocity
	blob.bounds = summary.bounds
	blob.last_position = summary.centroid
	blob.predicted_position = {
		summary.centroid[0] + summary.velocity[0],
		summary.centroid[1] + summary.velocity[1],
	}
	blob.area = summary.area
	blob.confidence = min(blob.confidence + 0.15, 1.0)
	blob.species_histogram = summary.species_histogram
}

particle_life_blob_tracker_add :: proc(tracker: ^Particle_Life_Blob_Tracker, summary: Particle_Life_Blob_Summary) {
	if tracker.count >= u32(len(tracker.blobs)) {
		return
	}
	index := int(tracker.count)
	tracker.count += 1
	blob := &tracker.blobs[index]
	blob^ = {
		id = tracker.next_id,
		age = 1,
		last_position = summary.centroid,
		predicted_position = {
			summary.centroid[0] + summary.velocity[0],
			summary.centroid[1] + summary.velocity[1],
		},
		velocity = summary.velocity,
		bounds = summary.bounds,
		area = summary.area,
		confidence = 0.45,
		species_histogram = summary.species_histogram,
	}
	tracker.next_id += 1
	if tracker.next_id == 0 {
		tracker.next_id = 1
	}
}

particle_life_blob_tracker_update :: proc(tracker: ^Particle_Life_Blob_Tracker, summaries: []Particle_Life_Blob_Summary) {
	matched_blobs: [128]bool
	matched_summaries: [128]bool
	old_count := int(tracker.count)
	summary_count := min(len(summaries), len(matched_summaries))
	for s in 0 ..< summary_count {
		best_index := -1
		best_score: f32
		for b in 0 ..< old_count {
			if matched_blobs[b] {
				continue
			}
			score := particle_life_blob_match_score(tracker.blobs[b], summaries[s])
			if score > best_score {
				best_score = score
				best_index = b
			}
		}
		if best_index >= 0 && best_score >= 0.35 {
			particle_life_blob_tracker_update_one(tracker, best_index, summaries[s])
			matched_blobs[best_index] = true
			matched_summaries[s] = true
		}
	}
	write_index := 0
	for read_index in 0 ..< old_count {
		if !matched_blobs[read_index] && tracker.blobs[read_index].age > 0 {
			tracker.blobs[read_index].missed_frames += 1
			tracker.blobs[read_index].confidence = max(tracker.blobs[read_index].confidence - 0.2, 0.0)
		}
		if tracker.blobs[read_index].missed_frames <= 10 {
			if write_index != read_index {
				tracker.blobs[write_index] = tracker.blobs[read_index]
			}
			write_index += 1
		}
	}
	tracker.count = u32(write_index)
	for s in 0 ..< summary_count {
		if !matched_summaries[s] {
			particle_life_blob_tracker_add(tracker, summaries[s])
		}
	}
}

particle_life_randomize_forces :: proc(sim: ^Particle_Life_Simulation) {
	sim.runtime.force_randomize_undo_matrix = sim.runtime.force_matrix
	sim.runtime.force_randomize_undo_seed = sim.runtime.seed
	sim.runtime.force_randomize_undo_available = true
	sim.runtime.seed += 0x85ebca6b
	sim.settings.custom_force_matrix = false
	particle_life_mirror_force_randomize(sim)
	sim.runtime.pending_force_randomize = true
}

particle_life_undo_randomize_forces :: proc(sim: ^Particle_Life_Simulation) -> bool {
	if sim == nil || !sim.runtime.force_randomize_undo_available {
		return false
	}
	sim.runtime.seed = sim.runtime.force_randomize_undo_seed
	sim.runtime.force_matrix = sim.runtime.force_randomize_undo_matrix
	for i in 0 ..< len(sim.settings.force_matrix) {
		sim.settings.force_matrix[i] = sim.runtime.force_matrix[i]
	}
	sim.settings.custom_force_matrix = true
	sim.runtime.pending_force_randomize = false
	particle_life_force_matrix_upload_existing(sim, u32(max(min(sim.settings.species_count, PARTICLE_LIFE_MAX_SPECIES), 1)))
	sim.runtime.force_randomize_undo_available = false
	return true
}

particle_life_load_settings :: proc(sim: ^Particle_Life_Simulation, settings: Particle_Life_Settings) {
	particle_count_changed := sim.gpu.uploaded_particle_count != 0 && sim.gpu.uploaded_particle_count != particle_life_target_particle_count(settings)
	species_count_changed := sim.gpu.uploaded_species_count != 0 && sim.gpu.uploaded_species_count != particle_life_target_species_count(settings)
	sim.settings = settings
	sim.runtime.force_randomize_undo_available = false
	sim.settings.infinite_tiles_enabled = true
	sim.runtime.camera_x = settings.camera_x
	sim.runtime.camera_y = settings.camera_y
	sim.runtime.camera_zoom = max(settings.camera_zoom, 0.25)
	sim.runtime.camera_target_x = sim.runtime.camera_x
	sim.runtime.camera_target_y = sim.runtime.camera_y
	sim.runtime.camera_target_zoom = sim.runtime.camera_zoom
	if sim.runtime.camera_smoothing_factor <= 0 {
		sim.runtime.camera_smoothing_factor = CAMERA_DEFAULT_SMOOTHING
	}
	for i in 0 ..< len(sim.runtime.force_matrix) {
		sim.runtime.force_matrix[i] = settings.force_matrix[i]
	}
	sim.runtime.needs_reset = true
	if particle_count_changed || species_count_changed {
		sim.gpu.ready = false
	} else {
		sim.runtime.force_matrix_dirty = true
	}
}

particle_life_save_settings :: proc(sim: ^Particle_Life_Simulation) -> Particle_Life_Settings {
	settings := sim.settings
	settings.camera_x = sim.runtime.camera_x
	settings.camera_y = sim.runtime.camera_y
	settings.camera_zoom = max(sim.runtime.camera_zoom, 0.25)
	settings.custom_force_matrix = true
	settings.infinite_tiles_enabled = true
	for i in 0 ..< len(settings.force_matrix) {
		settings.force_matrix[i] = sim.runtime.force_matrix[i]
	}
	return settings
}

particle_life_clear_color :: proc(sim: ^Particle_Life_Simulation) -> uifw.Color {
	color := particle_life_background_color(&sim.settings)
	return {color[0], color[1], color[2], color[3]}
}

particle_life_background_color :: proc(settings: ^Particle_Life_Settings) -> [4]f32 {
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
		return settings.background_color
	}
}
