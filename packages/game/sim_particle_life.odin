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
	preset_ui: Preset_Fieldset_State,
	preserved_particles: []Particle_Life_Particle,
	pending_force_randomize: bool,
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

particle_life_ensure_gpu_paths :: proc(sim: ^Particle_Life_Simulation) -> bool {
	grid_clear_path := engine.shader_spirv_path(PARTICLE_LIFE_GRID_CLEAR_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_GRID_CLEAR_FALLBACK_SPV + ".spv")
	grid_scatter_path := engine.shader_spirv_path(PARTICLE_LIFE_GRID_SCATTER_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_GRID_SCATTER_FALLBACK_SPV + ".spv")
	grid_scatter_predicted_path := engine.shader_spirv_path(PARTICLE_LIFE_GRID_SCATTER_PREDICTED_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_GRID_SCATTER_PREDICTED_FALLBACK_SPV + ".spv")
	compute_binned_path := engine.shader_spirv_path(PARTICLE_LIFE_COMPUTE_BINNED_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_COMPUTE_BINNED_FALLBACK_SPV + ".spv")
	collision_solve_path := engine.shader_spirv_path(PARTICLE_LIFE_COLLISION_SOLVE_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_COLLISION_SOLVE_FALLBACK_SPV + ".spv")
	collision_apply_path := engine.shader_spirv_path(PARTICLE_LIFE_COLLISION_APPLY_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_COLLISION_APPLY_FALLBACK_SPV + ".spv")
	copy_scratch_path := engine.shader_spirv_path(PARTICLE_LIFE_COPY_SCRATCH_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_COPY_SCRATCH_FALLBACK_SPV + ".spv")
	init_path := engine.shader_spirv_path(PARTICLE_LIFE_INIT_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_INIT_FALLBACK_SPV + ".spv")
	vertex_path := engine.shader_spirv_path(PARTICLE_LIFE_VERTEX_SHADER_SOURCE, .Vertex, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_VERTEX_FALLBACK_SPV + ".spv")
	fragment_path := engine.shader_spirv_path(PARTICLE_LIFE_FRAGMENT_SHADER_SOURCE, .Fragment, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_FRAGMENT_FALLBACK_SPV + ".spv")
	fade_vertex_path := engine.shader_spirv_path(PARTICLE_LIFE_FADE_VERTEX_SHADER_SOURCE, .Vertex, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_FADE_VERTEX_FALLBACK_SPV + ".spv")
	fade_fragment_path := engine.shader_spirv_path(PARTICLE_LIFE_FADE_FRAGMENT_SHADER_SOURCE, .Fragment, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_FADE_FRAGMENT_FALLBACK_SPV + ".spv")
	force_randomize_path := engine.shader_spirv_path(PARTICLE_LIFE_FORCE_RANDOMIZE_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_FORCE_RANDOMIZE_FALLBACK_SPV + ".spv")
	force_update_path := engine.shader_spirv_path(PARTICLE_LIFE_FORCE_UPDATE_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_FORCE_UPDATE_FALLBACK_SPV + ".spv")
	analysis_clear_path := engine.shader_spirv_path(PARTICLE_LIFE_ANALYSIS_CLEAR_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_ANALYSIS_CLEAR_FALLBACK_SPV + ".spv")
	analysis_scatter_path := engine.shader_spirv_path(PARTICLE_LIFE_ANALYSIS_SCATTER_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_ANALYSIS_SCATTER_FALLBACK_SPV + ".spv")
	analysis_coherence_path := engine.shader_spirv_path(PARTICLE_LIFE_ANALYSIS_COHERENCE_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_ANALYSIS_COHERENCE_FALLBACK_SPV + ".spv")
	analysis_tile_label_path := engine.shader_spirv_path(PARTICLE_LIFE_ANALYSIS_TILE_LABEL_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_ANALYSIS_TILE_LABEL_FALLBACK_SPV + ".spv")
	analysis_tile_merge_path := engine.shader_spirv_path(PARTICLE_LIFE_ANALYSIS_TILE_MERGE_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_ANALYSIS_TILE_MERGE_FALLBACK_SPV + ".spv")
	analysis_summarize_path := engine.shader_spirv_path(PARTICLE_LIFE_ANALYSIS_SUMMARIZE_SHADER_SOURCE, .Compute, PARTICLE_LIFE_ENTRY, PARTICLE_LIFE_ANALYSIS_SUMMARIZE_FALLBACK_SPV + ".spv")
	background_vertex_path := engine.shader_spirv_path(PARTICLE_LIFE_BACKGROUND_SHADER_SOURCE, .Vertex, PARTICLE_LIFE_BACKGROUND_VERTEX_ENTRY, PARTICLE_LIFE_BACKGROUND_VERTEX_FALLBACK_SPV + ".spv")
	background_fragment_path := engine.shader_spirv_path(PARTICLE_LIFE_BACKGROUND_SHADER_SOURCE, .Fragment, PARTICLE_LIFE_BACKGROUND_FRAGMENT_ENTRY, PARTICLE_LIFE_BACKGROUND_FRAGMENT_FALLBACK_SPV + ".spv")
	post_vertex_path := engine.shader_spirv_path(PARTICLE_LIFE_POST_SHADER_SOURCE, .Vertex, PARTICLE_LIFE_POST_VERTEX_ENTRY, PARTICLE_LIFE_POST_VERTEX_FALLBACK_SPV + ".spv")
	post_fragment_path := engine.shader_spirv_path(PARTICLE_LIFE_POST_SHADER_SOURCE, .Fragment, PARTICLE_LIFE_POST_FRAGMENT_ENTRY, PARTICLE_LIFE_POST_FRAGMENT_FALLBACK_SPV + ".spv")
	infinite_present_vertex_path := engine.shader_spirv_path(PARTICLE_LIFE_INFINITE_PRESENT_VERTEX_SHADER_SOURCE, .Vertex, PARTICLE_LIFE_INFINITE_PRESENT_VERTEX_ENTRY, PARTICLE_LIFE_INFINITE_PRESENT_VERTEX_FALLBACK_SPV + ".spv")
	infinite_present_fragment_path := engine.shader_spirv_path(PARTICLE_LIFE_INFINITE_PRESENT_FRAGMENT_SHADER_SOURCE, .Fragment, PARTICLE_LIFE_INFINITE_PRESENT_FRAGMENT_ENTRY, PARTICLE_LIFE_INFINITE_PRESENT_FRAGMENT_FALLBACK_SPV + ".spv")
	if len(grid_clear_path) == 0 || len(grid_scatter_path) == 0 || len(grid_scatter_predicted_path) == 0 || len(compute_binned_path) == 0 || len(collision_solve_path) == 0 || len(collision_apply_path) == 0 || len(copy_scratch_path) == 0 || len(init_path) == 0 || len(vertex_path) == 0 || len(fragment_path) == 0 || len(fade_vertex_path) == 0 || len(fade_fragment_path) == 0 || len(force_randomize_path) == 0 || len(force_update_path) == 0 || len(analysis_clear_path) == 0 || len(analysis_scatter_path) == 0 || len(analysis_coherence_path) == 0 || len(analysis_tile_label_path) == 0 || len(analysis_tile_merge_path) == 0 || len(analysis_summarize_path) == 0 || len(background_vertex_path) == 0 || len(background_fragment_path) == 0 || len(post_vertex_path) == 0 || len(post_fragment_path) == 0 || len(infinite_present_vertex_path) == 0 || len(infinite_present_fragment_path) == 0 {
		return false
	}
	if !os.exists(grid_clear_path) || !os.exists(grid_scatter_path) || !os.exists(grid_scatter_predicted_path) || !os.exists(compute_binned_path) || !os.exists(collision_solve_path) || !os.exists(collision_apply_path) || !os.exists(copy_scratch_path) || !os.exists(init_path) || !os.exists(vertex_path) || !os.exists(fragment_path) || !os.exists(fade_vertex_path) || !os.exists(fade_fragment_path) || !os.exists(force_randomize_path) || !os.exists(force_update_path) || !os.exists(analysis_clear_path) || !os.exists(analysis_scatter_path) || !os.exists(analysis_coherence_path) || !os.exists(analysis_tile_label_path) || !os.exists(analysis_tile_merge_path) || !os.exists(analysis_summarize_path) || !os.exists(background_vertex_path) || !os.exists(background_fragment_path) || !os.exists(post_vertex_path) || !os.exists(post_fragment_path) || !os.exists(infinite_present_vertex_path) || !os.exists(infinite_present_fragment_path) {
		return false
	}
	sim.gpu.grid_clear_shader_spirv_path = grid_clear_path
	sim.gpu.grid_scatter_shader_spirv_path = grid_scatter_path
	sim.gpu.grid_scatter_predicted_shader_spirv_path = grid_scatter_predicted_path
	sim.gpu.compute_binned_shader_spirv_path = compute_binned_path
	sim.gpu.collision_solve_shader_spirv_path = collision_solve_path
	sim.gpu.collision_apply_shader_spirv_path = collision_apply_path
	sim.gpu.copy_scratch_shader_spirv_path = copy_scratch_path
	sim.gpu.init_shader_spirv_path = init_path
	sim.gpu.vertex_shader_spirv_path = vertex_path
	sim.gpu.fragment_shader_spirv_path = fragment_path
	sim.gpu.fade_vertex_shader_spirv_path = fade_vertex_path
	sim.gpu.fade_fragment_shader_spirv_path = fade_fragment_path
	sim.gpu.force_randomize_shader_spirv_path = force_randomize_path
	sim.gpu.force_update_shader_spirv_path = force_update_path
	sim.gpu.analysis_clear_shader_spirv_path = analysis_clear_path
	sim.gpu.analysis_scatter_shader_spirv_path = analysis_scatter_path
	sim.gpu.analysis_coherence_shader_spirv_path = analysis_coherence_path
	sim.gpu.analysis_tile_label_shader_spirv_path = analysis_tile_label_path
	sim.gpu.analysis_tile_merge_shader_spirv_path = analysis_tile_merge_path
	sim.gpu.analysis_summarize_shader_spirv_path = analysis_summarize_path
	sim.gpu.background_vertex_shader_spirv_path = background_vertex_path
	sim.gpu.background_fragment_shader_spirv_path = background_fragment_path
	sim.gpu.post_vertex_shader_spirv_path = post_vertex_path
	sim.gpu.post_fragment_shader_spirv_path = post_fragment_path
	sim.gpu.infinite_present_vertex_shader_spirv_path = infinite_present_vertex_path
	sim.gpu.infinite_present_fragment_shader_spirv_path = infinite_present_fragment_path
	return true
}

particle_life_ensure_gpu_runtime :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if sim.gpu.ready {
		return true
	}
	if sim.gpu.grid_clear_shader_module.handle != 0 || sim.gpu.grid_scatter_shader_module.handle != 0 || sim.gpu.grid_scatter_predicted_shader_module.handle != 0 || sim.gpu.compute_binned_shader_module.handle != 0 || sim.gpu.collision_solve_shader_module.handle != 0 || sim.gpu.collision_apply_shader_module.handle != 0 || sim.gpu.copy_scratch_shader_module.handle != 0 || sim.gpu.init_shader_module.handle != 0 || sim.gpu.vertex_shader_module.handle != 0 || sim.gpu.fragment_shader_module.handle != 0 || sim.gpu.fade_vertex_shader_module.handle != 0 || sim.gpu.fade_fragment_shader_module.handle != 0 || sim.gpu.force_randomize_shader_module.handle != 0 || sim.gpu.force_update_shader_module.handle != 0 || sim.gpu.analysis_clear_shader_module.handle != 0 || sim.gpu.analysis_scatter_shader_module.handle != 0 || sim.gpu.analysis_coherence_shader_module.handle != 0 || sim.gpu.analysis_tile_label_shader_module.handle != 0 || sim.gpu.analysis_tile_merge_shader_module.handle != 0 || sim.gpu.analysis_summarize_shader_module.handle != 0 || sim.gpu.background_vertex_shader_module.handle != 0 || sim.gpu.background_fragment_shader_module.handle != 0 || sim.gpu.post_vertex_shader_module.handle != 0 || sim.gpu.post_fragment_shader_module.handle != 0 || sim.gpu.infinite_present_vertex_shader_module.handle != 0 || sim.gpu.infinite_present_fragment_shader_module.handle != 0 {
		_ = vk.DeviceWaitIdle(vk_ctx.device)
		particle_life_destroy(sim, vk_ctx)
	}
	if !particle_life_ensure_gpu_paths(sim) {
		engine.log_error("particle_life_ensure_gpu_runtime: shader paths unavailable")
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.grid_clear_shader_spirv_path, &sim.gpu.grid_clear_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: grid clear shader load failed path=", sim.gpu.grid_clear_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.grid_scatter_shader_spirv_path, &sim.gpu.grid_scatter_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: grid scatter shader load failed path=", sim.gpu.grid_scatter_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.grid_scatter_predicted_shader_spirv_path, &sim.gpu.grid_scatter_predicted_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: predicted grid scatter shader load failed path=", sim.gpu.grid_scatter_predicted_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.compute_binned_shader_spirv_path, &sim.gpu.compute_binned_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: compute binned shader load failed path=", sim.gpu.compute_binned_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.collision_solve_shader_spirv_path, &sim.gpu.collision_solve_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: collision solve shader load failed path=", sim.gpu.collision_solve_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.collision_apply_shader_spirv_path, &sim.gpu.collision_apply_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: collision apply shader load failed path=", sim.gpu.collision_apply_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.copy_scratch_shader_spirv_path, &sim.gpu.copy_scratch_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: copy scratch shader load failed path=", sim.gpu.copy_scratch_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.init_shader_spirv_path, &sim.gpu.init_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: init shader load failed path=", sim.gpu.init_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.vertex_shader_spirv_path, &sim.gpu.vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: vertex shader load failed path=", sim.gpu.vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.fragment_shader_spirv_path, &sim.gpu.fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: fragment shader load failed path=", sim.gpu.fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.fade_vertex_shader_spirv_path, &sim.gpu.fade_vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: fade vertex shader load failed path=", sim.gpu.fade_vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.fade_fragment_shader_spirv_path, &sim.gpu.fade_fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: fade fragment shader load failed path=", sim.gpu.fade_fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.force_randomize_shader_spirv_path, &sim.gpu.force_randomize_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: force randomize shader load failed path=", sim.gpu.force_randomize_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.force_update_shader_spirv_path, &sim.gpu.force_update_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: force update shader load failed path=", sim.gpu.force_update_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.analysis_clear_shader_spirv_path, &sim.gpu.analysis_clear_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis clear shader load failed path=", sim.gpu.analysis_clear_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.analysis_scatter_shader_spirv_path, &sim.gpu.analysis_scatter_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis scatter shader load failed path=", sim.gpu.analysis_scatter_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.analysis_coherence_shader_spirv_path, &sim.gpu.analysis_coherence_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis coherence shader load failed path=", sim.gpu.analysis_coherence_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.analysis_tile_label_shader_spirv_path, &sim.gpu.analysis_tile_label_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis tile label shader load failed path=", sim.gpu.analysis_tile_label_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.analysis_tile_merge_shader_spirv_path, &sim.gpu.analysis_tile_merge_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis tile merge shader load failed path=", sim.gpu.analysis_tile_merge_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.analysis_summarize_shader_spirv_path, &sim.gpu.analysis_summarize_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: analysis summarize shader load failed path=", sim.gpu.analysis_summarize_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.background_vertex_shader_spirv_path, &sim.gpu.background_vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: background vertex shader load failed path=", sim.gpu.background_vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.background_fragment_shader_spirv_path, &sim.gpu.background_fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: background fragment shader load failed path=", sim.gpu.background_fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.post_vertex_shader_spirv_path, &sim.gpu.post_vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: post vertex shader load failed path=", sim.gpu.post_vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.post_fragment_shader_spirv_path, &sim.gpu.post_fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: post fragment shader load failed path=", sim.gpu.post_fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.infinite_present_vertex_shader_spirv_path, &sim.gpu.infinite_present_vertex_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: infinite present vertex shader load failed path=", sim.gpu.infinite_present_vertex_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.infinite_present_fragment_shader_spirv_path, &sim.gpu.infinite_present_fragment_shader_module) {
		engine.log_error("particle_life_ensure_gpu_runtime: infinite present fragment shader load failed path=", sim.gpu.infinite_present_fragment_shader_spirv_path)
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	if !particle_life_create_resources(sim, vk_ctx) {
		engine.log_error("particle_life_ensure_gpu_runtime: resource creation failed")
		particle_life_destroy(sim, vk_ctx)
		return false
	}
	sim.gpu.ready = true
	return true
}

particle_life_create_resources :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	particle_count := particle_life_target_particle_count(sim.settings)
	species_count := particle_life_target_species_count(sim.settings)
	restore_particles := !sim.runtime.needs_reset && len(sim.runtime.preserved_particles) == int(particle_count)
	world_size := particle_life_world_size(sim)
	grid_width, grid_height := particle_life_target_grid_dimensions(sim.settings, world_size)
	grid_cells := grid_width * grid_height
	neighbor_radius_cells := particle_life_target_neighbor_radius_cells(sim.settings, grid_width, grid_height, world_size)
	analysis_axis := particle_life_target_analysis_grid_axis(sim.settings)
	analysis_cells := analysis_axis * analysis_axis
	analysis_tile_count := particle_life_analysis_tile_count_for_axis(analysis_axis)
	analysis_tile_components := analysis_tile_count * analysis_tile_count * PARTICLE_LIFE_ANALYSIS_TILE_SIZE * PARTICLE_LIFE_ANALYSIS_TILE_SIZE
	particle_size := vk.DeviceSize(size_of(Particle_Life_Particle) * int(particle_count))
	if !engine.vk_create_host_buffer(vk_ctx, particle_size, {.STORAGE_BUFFER, .VERTEX_BUFFER, .TRANSFER_DST}, &sim.gpu.particle_buffer) {
		engine.log_error("particle_life_create_resources: particle buffer failed bytes=", particle_size)
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, particle_size, {.STORAGE_BUFFER, .TRANSFER_SRC, .TRANSFER_DST}, &sim.gpu.particle_scratch_buffer) {
		engine.log_error("particle_life_create_resources: particle scratch buffer failed bytes=", particle_size)
		return false
	}
	params_size := vk.DeviceSize(size_of(Particle_Life_Params))
	init_params_size := vk.DeviceSize(size_of(Particle_Life_Init_Params))
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, params_size, {.UNIFORM_BUFFER}, &sim.gpu.params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, init_params_size, {.UNIFORM_BUFFER}, &sim.gpu.init_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Fade_Params)), {.UNIFORM_BUFFER}, &sim.gpu.fade_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Force_Randomize_Params)), {.UNIFORM_BUFFER}, &sim.gpu.force_randomize_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Force_Update_Params)), {.UNIFORM_BUFFER}, &sim.gpu.force_update_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Grid_Params)), {.UNIFORM_BUFFER}, &sim.gpu.grid_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Collision_Params)), {.UNIFORM_BUFFER}, &sim.gpu.collision_params_buffers[frame_slot]) {
			return false
		}
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(grid_cells)), {.STORAGE_BUFFER}, &sim.gpu.grid_heads_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(particle_count)), {.STORAGE_BUFFER}, &sim.gpu.particle_next_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of([2]f32) * int(particle_count)), {.STORAGE_BUFFER}, &sim.gpu.collision_correction_buffer) {
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Analysis_Params)), {.UNIFORM_BUFFER}, &sim.gpu.analysis_params_buffers[frame_slot]) {
			return false
		}
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Analysis_Gpu_Cell) * int(analysis_cells)), {.STORAGE_BUFFER}, &sim.gpu.analysis_cells_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(f32) * int(analysis_cells)), {.STORAGE_BUFFER}, &sim.gpu.analysis_coherence_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(analysis_cells)), {.STORAGE_BUFFER}, &sim.gpu.analysis_labels_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(analysis_tile_components)), {.STORAGE_BUFFER}, &sim.gpu.analysis_tile_components_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32) * int(analysis_cells)), {.STORAGE_BUFFER}, &sim.gpu.analysis_parent_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Blob_Accumulator) * PARTICLE_LIFE_ANALYSIS_MAX_BLOBS), {.STORAGE_BUFFER}, &sim.gpu.analysis_blob_summaries_buffer) {
		return false
	}
	if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(u32)), {.STORAGE_BUFFER}, &sim.gpu.analysis_blob_count_buffer) {
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Selected_Blob_Params)), {.UNIFORM_BUFFER}, &sim.gpu.selected_blob_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Background_Params)), {.UNIFORM_BUFFER}, &sim.gpu.background_params_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Post_Params)), {.UNIFORM_BUFFER}, &sim.gpu.post_params_buffers[frame_slot]) {
			return false
		}
	}
	force_size := vk.DeviceSize(size_of(f32) * int(species_count * species_count))
	if !engine.vk_create_host_buffer(vk_ctx, force_size, {.STORAGE_BUFFER}, &sim.gpu.force_matrix_buffer) {
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Species_Colors)), {.UNIFORM_BUFFER}, &sim.gpu.color_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Color_Mode_Params)), {.UNIFORM_BUFFER}, &sim.gpu.color_mode_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Camera)), {.UNIFORM_BUFFER}, &sim.gpu.camera_buffers[frame_slot]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(Particle_Life_Viewport)), {.UNIFORM_BUFFER}, &sim.gpu.viewport_buffers[frame_slot]) {
			return false
		}
	}
	sim.gpu.uploaded_particle_count = particle_count
	sim.gpu.uploaded_species_count = species_count
	sim.gpu.grid_width = grid_width
	sim.gpu.grid_height = grid_height
	sim.gpu.neighbor_radius_cells = neighbor_radius_cells
	sim.gpu.analysis_grid_axis = analysis_axis
	sim.gpu.analysis_tile_count = analysis_tile_count
	particle_life_upload_force_matrix(sim)
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		sim.gpu.active_frame_slot = frame_slot
		particle_life_upload_static_uniforms(sim)
		particle_life_write_init_uniforms(sim)
		particle_life_write_frame_uniforms(sim, 0)
		particle_life_write_grid_uniforms(sim)
		particle_life_write_collision_uniforms(sim)
		particle_life_write_analysis_uniforms(sim)
		particle_life_write_fade_uniforms(sim)
		particle_life_write_background_uniforms(sim)
		particle_life_write_post_uniforms(sim)
	}
	if restore_particles && sim.gpu.particle_buffer.mapped != nil {
		particles := (cast([^]Particle_Life_Particle)sim.gpu.particle_buffer.mapped)[:particle_count]
		copy(particles, sim.runtime.preserved_particles)
		sim.runtime.needs_reset = false
	} else {
		sim.runtime.needs_reset = true
	}
	particle_life_clear_preserved_particles(sim)

	if !particle_life_create_descriptor_state(sim, vk_ctx) {
		engine.log_error("particle_life_create_resources: descriptor state failed")
		return false
	}
	if !particle_life_create_init_pipeline(sim, vk_ctx) {
		engine.log_error("particle_life_create_resources: init pipeline failed")
		return false
	}
	if !particle_life_create_compute_pipeline(sim, vk_ctx) {
		engine.log_error("particle_life_create_resources: compute pipeline failed")
		return false
	}
	if !particle_life_create_force_pipelines(sim, vk_ctx) {
		engine.log_error("particle_life_create_resources: force pipelines failed")
		return false
	}
	if !particle_life_create_render_pipeline(sim, vk_ctx) {
		engine.log_error("particle_life_create_resources: render pipeline failed")
		return false
	}
	if !particle_life_create_trail_resources(sim, vk_ctx) {
		engine.log_error("particle_life_create_resources: trail resources failed")
		return false
	}
	return true
}

particle_life_create_descriptor_state :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	sim_bindings := [9]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE, .VERTEX}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE, .VERTEX}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 5, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 6, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 7, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 8, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	sim_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(sim_bindings)),
		pBindings = raw_data(sim_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &sim_layout_info, nil, &sim.gpu.sim_set_layout) != .SUCCESS {
		return false
	}

	init_bindings := [2]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	init_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(init_bindings)),
		pBindings = raw_data(init_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &init_layout_info, nil, &sim.gpu.init_set_layout) != .SUCCESS {
		return false
	}

	color_bindings := [2]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	color_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(color_bindings)),
		pBindings = raw_data(color_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &color_layout_info, nil, &sim.gpu.color_set_layout) != .SUCCESS {
		return false
	}

	view_bindings := [2]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}},
	}
	view_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(view_bindings)),
		pBindings = raw_data(view_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &view_layout_info, nil, &sim.gpu.view_set_layout) != .SUCCESS {
		return false
	}

	force_op_bindings := [2]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	force_op_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(force_op_bindings)),
		pBindings = raw_data(force_op_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &force_op_layout_info, nil, &sim.gpu.force_op_set_layout) != .SUCCESS {
		return false
	}

	analysis_bindings := [10]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 5, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 6, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 7, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 8, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 9, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	analysis_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(analysis_bindings)),
		pBindings = raw_data(analysis_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &analysis_layout_info, nil, &sim.gpu.analysis_set_layout) != .SUCCESS {
		return false
	}

	pool_sizes := [2]vk.DescriptorPoolSize {
		{type = .STORAGE_BUFFER, descriptorCount = 20 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .UNIFORM_BUFFER, descriptorCount = 12 * engine.MAX_FRAMES_IN_FLIGHT},
	}
	pool_info := vk.DescriptorPoolCreateInfo {
		sType = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = u32(len(pool_sizes)),
		pPoolSizes = raw_data(pool_sizes[:]),
		maxSets = 7 * engine.MAX_FRAMES_IN_FLIGHT,
	}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &sim.gpu.descriptor_pool) != .SUCCESS {
		return false
	}

	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		layouts := [7]vk.DescriptorSetLayout{sim.gpu.sim_set_layout, sim.gpu.init_set_layout, sim.gpu.color_set_layout, sim.gpu.view_set_layout, sim.gpu.force_op_set_layout, sim.gpu.force_op_set_layout, sim.gpu.analysis_set_layout}
		sets := [7]vk.DescriptorSet{}
		alloc := vk.DescriptorSetAllocateInfo {
			sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
			descriptorPool = sim.gpu.descriptor_pool,
			descriptorSetCount = u32(len(layouts)),
			pSetLayouts = raw_data(layouts[:]),
		}
		if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(sets[:])) != .SUCCESS {
			return false
		}
		sim.gpu.sim_sets[frame_slot] = sets[0]
		sim.gpu.init_sets[frame_slot] = sets[1]
		sim.gpu.color_sets[frame_slot] = sets[2]
		sim.gpu.view_sets[frame_slot] = sets[3]
		sim.gpu.force_randomize_sets[frame_slot] = sets[4]
		sim.gpu.force_update_sets[frame_slot] = sets[5]
		sim.gpu.analysis_sets[frame_slot] = sets[6]
	}
	particle_life_update_descriptors(sim, vk_ctx)
	return true
}

particle_life_create_init_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = &sim.gpu.init_set_layout,
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &sim.gpu.init_pipeline.layout) != .SUCCESS {
		return false
	}
	stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.COMPUTE},
		module = sim.gpu.init_shader_module.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	info := vk.ComputePipelineCreateInfo {
		sType = .COMPUTE_PIPELINE_CREATE_INFO,
		stage = stage,
		layout = sim.gpu.init_pipeline.layout,
	}
	if vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &sim.gpu.init_pipeline.pipeline) != .SUCCESS {
		return false
	}
	return true
}

particle_life_create_compute_pipeline_for_module :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, shader: engine.Vk_Shader_Module, pipeline: ^engine.Vk_Compute_Pipeline) -> bool {
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = &sim.gpu.sim_set_layout,
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}
	stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.COMPUTE},
		module = shader.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	info := vk.ComputePipelineCreateInfo {
		sType = .COMPUTE_PIPELINE_CREATE_INFO,
		stage = stage,
		layout = pipeline.layout,
	}
	if vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline) != .SUCCESS {
		return false
	}
	return true
}

particle_life_create_compute_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, sim.gpu.grid_clear_shader_module, &sim.gpu.grid_clear_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, sim.gpu.grid_scatter_shader_module, &sim.gpu.grid_scatter_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, sim.gpu.grid_scatter_predicted_shader_module, &sim.gpu.grid_scatter_predicted_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, sim.gpu.compute_binned_shader_module, &sim.gpu.compute_binned_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, sim.gpu.collision_solve_shader_module, &sim.gpu.collision_solve_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, sim.gpu.collision_apply_shader_module, &sim.gpu.collision_apply_pipeline) {
		return false
	}
	if !particle_life_create_compute_pipeline_for_module(sim, vk_ctx, sim.gpu.copy_scratch_shader_module, &sim.gpu.copy_scratch_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, sim.gpu.analysis_clear_shader_module, sim.gpu.analysis_set_layout, &sim.gpu.analysis_clear_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, sim.gpu.analysis_scatter_shader_module, sim.gpu.analysis_set_layout, &sim.gpu.analysis_scatter_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, sim.gpu.analysis_coherence_shader_module, sim.gpu.analysis_set_layout, &sim.gpu.analysis_coherence_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, sim.gpu.analysis_tile_label_shader_module, sim.gpu.analysis_set_layout, &sim.gpu.analysis_tile_label_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, sim.gpu.analysis_tile_merge_shader_module, sim.gpu.analysis_set_layout, &sim.gpu.analysis_tile_merge_pipeline) {
		return false
	}
	if !particle_life_create_analysis_pipeline(vk_ctx, sim.gpu.analysis_summarize_shader_module, sim.gpu.analysis_set_layout, &sim.gpu.analysis_summarize_pipeline) {
		return false
	}
	return true
}

particle_life_create_analysis_pipeline :: proc(vk_ctx: ^engine.Vk_Context, shader: engine.Vk_Shader_Module, set_layout: vk.DescriptorSetLayout, pipeline: ^engine.Vk_Compute_Pipeline) -> bool {
	set_layouts := [1]vk.DescriptorSetLayout{set_layout}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = raw_data(set_layouts[:]),
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}
	stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.COMPUTE},
		module = shader.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	info := vk.ComputePipelineCreateInfo {
		sType = .COMPUTE_PIPELINE_CREATE_INFO,
		stage = stage,
		layout = pipeline.layout,
	}
	result := vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_analysis_pipeline: CreateComputePipelines failed result=", result)
		return false
	}
	return true
}

particle_life_create_force_pipeline :: proc(vk_ctx: ^engine.Vk_Context, shader: engine.Vk_Shader_Module, set_layout: vk.DescriptorSetLayout, pipeline: ^engine.Vk_Compute_Pipeline) -> bool {
	set_layouts := [1]vk.DescriptorSetLayout{set_layout}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = raw_data(set_layouts[:]),
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}
	stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.COMPUTE},
		module = shader.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	info := vk.ComputePipelineCreateInfo {
		sType = .COMPUTE_PIPELINE_CREATE_INFO,
		stage = stage,
		layout = pipeline.layout,
	}
	result := vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_force_pipeline: CreateComputePipelines failed result=", result)
		return false
	}
	return true
}

particle_life_create_force_pipelines :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if !particle_life_create_force_pipeline(vk_ctx, sim.gpu.force_randomize_shader_module, sim.gpu.force_op_set_layout, &sim.gpu.force_randomize_pipeline) {
		return false
	}
	if !particle_life_create_force_pipeline(vk_ctx, sim.gpu.force_update_shader_module, sim.gpu.force_op_set_layout, &sim.gpu.force_update_pipeline) {
		return false
	}
	return true
}

particle_life_create_particle_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, render_pass: vk.RenderPass, pipeline: ^engine.Vk_Graphics_Pipeline) -> bool {
	vertex_stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.VERTEX},
		module = sim.gpu.vertex_shader_module.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	fragment_stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.FRAGMENT},
		module = sim.gpu.fragment_shader_module.handle,
		pName = PARTICLE_LIFE_ENTRY,
	}
	stages := [?]vk.PipelineShaderStageCreateInfo{vertex_stage, fragment_stage}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
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
		blendEnable = true,
		srcColorBlendFactor = .SRC_ALPHA,
		dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
		colorBlendOp = .ADD,
		srcAlphaBlendFactor = .ONE,
		dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA,
		alphaBlendOp = .ADD,
		colorWriteMask = {.R, .G, .B, .A},
	}
	blend := vk.PipelineColorBlendStateCreateInfo {
		sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		attachmentCount = 1,
		pAttachments = &blend_attachment,
	}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo {
		sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = u32(len(dynamic_states)),
		pDynamicStates = raw_data(dynamic_states[:]),
	}
	set_layouts := [3]vk.DescriptorSetLayout{sim.gpu.sim_set_layout, sim.gpu.color_set_layout, sim.gpu.view_set_layout}
	push_range := vk.PushConstantRange {
		stageFlags = {.VERTEX},
		offset = 0,
		size = u32(size_of(Particle_Life_Viewport_Push)),
	}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = u32(len(set_layouts)),
		pSetLayouts = raw_data(set_layouts[:]),
		pushConstantRangeCount = 1,
		pPushConstantRanges = &push_range,
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}
	info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = u32(len(stages)),
		pStages = raw_data(stages[:]),
		pVertexInputState = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState = &multisample,
		pColorBlendState = &blend,
		pDynamicState = &dynamic_state,
		layout = pipeline.layout,
		renderPass = render_pass,
		subpass = 0,
	}
	result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_particle_pipeline: CreateGraphicsPipelines failed result=", result)
		return false
	}
	return true
}

particle_life_create_render_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	return particle_life_create_particle_pipeline(sim, vk_ctx, vk_ctx.render_pass, &sim.gpu.render_pipeline)
}

particle_life_create_trail_render_pass :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	attachment := vk.AttachmentDescription {
		format = vk_ctx.swapchain_format,
		samples = {._1},
		loadOp = .CLEAR,
		storeOp = .STORE,
		stencilLoadOp = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout = .COLOR_ATTACHMENT_OPTIMAL,
		finalLayout = .COLOR_ATTACHMENT_OPTIMAL,
	}
	color_ref := vk.AttachmentReference {
		attachment = 0,
		layout = .COLOR_ATTACHMENT_OPTIMAL,
	}
	subpass := vk.SubpassDescription {
		pipelineBindPoint = .GRAPHICS,
		colorAttachmentCount = 1,
		pColorAttachments = &color_ref,
	}
	dependency := vk.SubpassDependency {
		srcSubpass = vk.SUBPASS_EXTERNAL,
		dstSubpass = 0,
		srcStageMask = {.COLOR_ATTACHMENT_OUTPUT},
		dstStageMask = {.COLOR_ATTACHMENT_OUTPUT},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
		dependencyFlags = {.BY_REGION},
	}
	info := vk.RenderPassCreateInfo {
		sType = .RENDER_PASS_CREATE_INFO,
		attachmentCount = 1,
		pAttachments = &attachment,
		subpassCount = 1,
		pSubpasses = &subpass,
		dependencyCount = 1,
		pDependencies = &dependency,
	}
	result := vk.CreateRenderPass(vk_ctx.device, &info, nil, &sim.gpu.trail_render_pass)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_trail_render_pass: CreateRenderPass failed result=", result)
		return false
	}
	return true
}

particle_life_create_trail_image :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, index: int, width, height: u32) -> bool {
	image := &sim.gpu.trail_images[index]
	image_info := vk.ImageCreateInfo {
		sType = .IMAGE_CREATE_INFO,
		imageType = .D2,
		format = vk_ctx.swapchain_format,
		extent = {width, height, 1},
		mipLevels = 1,
		arrayLayers = 1,
		samples = {._1},
		tiling = .OPTIMAL,
		usage = {.COLOR_ATTACHMENT, .SAMPLED, .TRANSFER_SRC, .TRANSFER_DST},
		sharingMode = .EXCLUSIVE,
		initialLayout = .UNDEFINED,
	}
	if result := vk.CreateImage(vk_ctx.device, &image_info, nil, &image.handle); result != .SUCCESS {
		engine.log_error("particle_life_create_trail_image: CreateImage failed index=", index, " result=", result, " size=", width, "x", height, " format=", image_info.format)
		return false
	}
	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device, image.handle, &req)
	memory_type, ok := engine.vk_find_memory_type(vk_ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {
		return false
	}
	alloc := vk.MemoryAllocateInfo {
		sType = .MEMORY_ALLOCATE_INFO,
		allocationSize = req.size,
		memoryTypeIndex = memory_type,
	}
	if result := vk.AllocateMemory(vk_ctx.device, &alloc, nil, &image.memory); result != .SUCCESS {
		engine.log_error("particle_life_create_trail_image: AllocateMemory failed index=", index, " result=", result)
		return false
	}
	if result := vk.BindImageMemory(vk_ctx.device, image.handle, image.memory, 0); result != .SUCCESS {
		engine.log_error("particle_life_create_trail_image: BindImageMemory failed index=", index, " result=", result)
		return false
	}
	view_info := vk.ImageViewCreateInfo {
		sType = .IMAGE_VIEW_CREATE_INFO,
		image = image.handle,
		viewType = .D2,
		format = vk_ctx.swapchain_format,
		subresourceRange = {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
		},
	}
	if result := vk.CreateImageView(vk_ctx.device, &view_info, nil, &image.view); result != .SUCCESS {
		engine.log_error("particle_life_create_trail_image: CreateImageView failed index=", index, " result=", result)
		return false
	}
	attachment := image.view
	framebuffer_info := vk.FramebufferCreateInfo {
		sType = .FRAMEBUFFER_CREATE_INFO,
		renderPass = sim.gpu.trail_render_pass,
		attachmentCount = 1,
		pAttachments = &attachment,
		width = width,
		height = height,
		layers = 1,
	}
	if result := vk.CreateFramebuffer(vk_ctx.device, &framebuffer_info, nil, &image.framebuffer); result != .SUCCESS {
		engine.log_error("particle_life_create_trail_image: CreateFramebuffer failed index=", index, " result=", result)
		return false
	}
	image.layout = .UNDEFINED
	return true
}

particle_life_create_fade_pipeline :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	set_layouts := [1]vk.DescriptorSetLayout{sim.gpu.fade_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = u32(len(set_layouts)),
		pSetLayouts = raw_data(set_layouts[:]),
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &sim.gpu.fade_pipeline.layout) != .SUCCESS {
		return false
	}
	stages := [2]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = sim.gpu.fade_vertex_shader_module.handle, pName = PARTICLE_LIFE_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = sim.gpu.fade_fragment_shader_module.handle, pName = PARTICLE_LIFE_ENTRY},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState {
		blendEnable = true,
		srcColorBlendFactor = .SRC_ALPHA,
		dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
		colorBlendOp = .ADD,
		srcAlphaBlendFactor = .ONE,
		dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA,
		alphaBlendOp = .ADD,
		colorWriteMask = {.R, .G, .B, .A},
	}
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = u32(len(dynamic_states)), pDynamicStates = raw_data(dynamic_states[:])}
	info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = u32(len(stages)),
		pStages = raw_data(stages[:]),
		pVertexInputState = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState = &multisample,
		pColorBlendState = &blend,
		pDynamicState = &dynamic_state,
		layout = sim.gpu.fade_pipeline.layout,
		renderPass = sim.gpu.trail_render_pass,
		subpass = 0,
	}
	result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &sim.gpu.fade_pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_fade_pipeline: CreateGraphicsPipelines failed result=", result)
		return false
	}
	return true
}

particle_life_create_fullscreen_pipeline :: proc(vk_ctx: ^engine.Vk_Context, vertex_module, fragment_module: engine.Vk_Shader_Module, vertex_entry, fragment_entry: string, render_pass: vk.RenderPass, set_layout: vk.DescriptorSetLayout, blend_enabled: bool, pipeline: ^engine.Vk_Graphics_Pipeline) -> bool {
	set_layouts := [1]vk.DescriptorSetLayout{set_layout}
	vertex_entry_c, vertex_err := strings.clone_to_cstring(vertex_entry, context.temp_allocator)
	if vertex_err != nil {
		return false
	}
	fragment_entry_c, fragment_err := strings.clone_to_cstring(fragment_entry, context.temp_allocator)
	if fragment_err != nil {
		return false
	}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = raw_data(set_layouts[:]),
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}
	stages := [2]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = vertex_module.handle, pName = vertex_entry_c},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = fragment_module.handle, pName = fragment_entry_c},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState {
		blendEnable = b32(blend_enabled),
		srcColorBlendFactor = .SRC_ALPHA,
		dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
		colorBlendOp = .ADD,
		srcAlphaBlendFactor = .ONE,
		dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA,
		alphaBlendOp = .ADD,
		colorWriteMask = {.R, .G, .B, .A},
	}
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = u32(len(dynamic_states)), pDynamicStates = raw_data(dynamic_states[:])}
	info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = u32(len(stages)),
		pStages = raw_data(stages[:]),
		pVertexInputState = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState = &multisample,
		pColorBlendState = &blend,
		pDynamicState = &dynamic_state,
		layout = pipeline.layout,
		renderPass = render_pass,
		subpass = 0,
	}
	result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline)
	if result != .SUCCESS {
		engine.log_error("particle_life_create_fullscreen_pipeline: CreateGraphicsPipelines failed result=", result, " vertex_entry=", vertex_entry, " fragment_entry=", fragment_entry, " render_pass=", render_pass)
		return false
	}
	return true
}

particle_life_create_trail_resources :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if !particle_life_create_trail_render_pass(sim, vk_ctx) {
		return false
	}
	if !particle_life_create_particle_pipeline(sim, vk_ctx, sim.gpu.trail_render_pass, &sim.gpu.trail_particle_pipeline) {
		return false
	}
	fade_bindings := [3]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	fade_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(fade_bindings)),
		pBindings = raw_data(fade_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &fade_layout_info, nil, &sim.gpu.fade_set_layout) != .SUCCESS {
		return false
	}
	background_binding := vk.DescriptorSetLayoutBinding{binding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}}
	background_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = 1,
		pBindings = &background_binding,
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &background_layout_info, nil, &sim.gpu.background_set_layout) != .SUCCESS {
		return false
	}
	post_bindings := [4]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}},
	}
	post_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(post_bindings)),
		pBindings = raw_data(post_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &post_layout_info, nil, &sim.gpu.post_set_layout) != .SUCCESS {
		return false
	}
	pool_sizes := [3]vk.DescriptorPoolSize {
		{type = .UNIFORM_BUFFER, descriptorCount = 7 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .SAMPLED_IMAGE, descriptorCount = 4 * engine.MAX_FRAMES_IN_FLIGHT},
		{type = .SAMPLER, descriptorCount = 4 * engine.MAX_FRAMES_IN_FLIGHT},
	}
	pool_info := vk.DescriptorPoolCreateInfo {
		sType = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = u32(len(pool_sizes)),
		pPoolSizes = raw_data(pool_sizes[:]),
		maxSets = 5 * engine.MAX_FRAMES_IN_FLIGHT,
	}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &sim.gpu.fade_descriptor_pool) != .SUCCESS {
		return false
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		fade_layouts := [2]vk.DescriptorSetLayout{sim.gpu.fade_set_layout, sim.gpu.fade_set_layout}
		fade_sets: [2]vk.DescriptorSet
		fade_alloc := vk.DescriptorSetAllocateInfo {
			sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
			descriptorPool = sim.gpu.fade_descriptor_pool,
			descriptorSetCount = u32(len(fade_layouts)),
			pSetLayouts = raw_data(fade_layouts[:]),
		}
		if vk.AllocateDescriptorSets(vk_ctx.device, &fade_alloc, raw_data(fade_sets[:])) != .SUCCESS {
			return false
		}
		sim.gpu.fade_sets[frame_slot][0] = fade_sets[0]
		sim.gpu.fade_sets[frame_slot][1] = fade_sets[1]
		background_alloc := vk.DescriptorSetAllocateInfo {
			sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
			descriptorPool = sim.gpu.fade_descriptor_pool,
			descriptorSetCount = 1,
			pSetLayouts = &sim.gpu.background_set_layout,
		}
		if vk.AllocateDescriptorSets(vk_ctx.device, &background_alloc, &sim.gpu.background_sets[frame_slot]) != .SUCCESS {
			return false
		}
		post_layouts := [2]vk.DescriptorSetLayout{sim.gpu.post_set_layout, sim.gpu.post_set_layout}
		post_sets: [2]vk.DescriptorSet
		post_alloc := vk.DescriptorSetAllocateInfo {
			sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
			descriptorPool = sim.gpu.fade_descriptor_pool,
			descriptorSetCount = u32(len(post_layouts)),
			pSetLayouts = raw_data(post_layouts[:]),
		}
		if vk.AllocateDescriptorSets(vk_ctx.device, &post_alloc, raw_data(post_sets[:])) != .SUCCESS {
			return false
		}
		sim.gpu.post_sets[frame_slot][0] = post_sets[0]
		sim.gpu.post_sets[frame_slot][1] = post_sets[1]
	}
	sampler_info := vk.SamplerCreateInfo {sType = .SAMPLER_CREATE_INFO}
	sampler_info.magFilter = .LINEAR
	sampler_info.minFilter = .LINEAR
	sampler_info.mipmapMode = .LINEAR
	sampler_info.addressModeU = .CLAMP_TO_EDGE
	sampler_info.addressModeV = .CLAMP_TO_EDGE
	sampler_info.addressModeW = .CLAMP_TO_EDGE
	sampler_info.minLod = 0
	sampler_info.maxLod = 1
	if vk.CreateSampler(vk_ctx.device, &sampler_info, nil, &sim.gpu.trail_sampler) != .SUCCESS {
		return false
	}
	if !particle_life_create_fade_pipeline(sim, vk_ctx) {
		return false
	}
	if !particle_life_create_fullscreen_pipeline(vk_ctx, sim.gpu.background_vertex_shader_module, sim.gpu.background_fragment_shader_module, PARTICLE_LIFE_BACKGROUND_VERTEX_ENTRY, PARTICLE_LIFE_BACKGROUND_FRAGMENT_ENTRY, sim.gpu.trail_render_pass, sim.gpu.background_set_layout, false, &sim.gpu.background_pipeline) {
		return false
	}
	if !particle_life_create_fullscreen_pipeline(vk_ctx, sim.gpu.post_vertex_shader_module, sim.gpu.post_fragment_shader_module, PARTICLE_LIFE_POST_VERTEX_ENTRY, PARTICLE_LIFE_POST_FRAGMENT_ENTRY, vk_ctx.render_pass, sim.gpu.post_set_layout, false, &sim.gpu.post_pipeline) {
		return false
	}
	if !particle_life_create_fullscreen_pipeline(vk_ctx, sim.gpu.infinite_present_vertex_shader_module, sim.gpu.infinite_present_fragment_shader_module, PARTICLE_LIFE_INFINITE_PRESENT_VERTEX_ENTRY, PARTICLE_LIFE_INFINITE_PRESENT_FRAGMENT_ENTRY, vk_ctx.render_pass, sim.gpu.post_set_layout, false, &sim.gpu.tiled_post_pipeline) {
		return false
	}
	return true
}

particle_life_update_descriptors :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		particle_life_update_descriptors_for_slot(sim, vk_ctx, frame_slot)
	}
}

particle_life_update_descriptors_for_slot :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	particle_info := vk.DescriptorBufferInfo{buffer = sim.gpu.particle_buffer.handle, offset = 0, range = sim.gpu.particle_buffer.size}
	particle_scratch_info := vk.DescriptorBufferInfo{buffer = sim.gpu.particle_scratch_buffer.handle, offset = 0, range = sim.gpu.particle_scratch_buffer.size}
	params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Params))}
	grid_heads_info := vk.DescriptorBufferInfo{buffer = sim.gpu.grid_heads_buffer.handle, offset = 0, range = sim.gpu.grid_heads_buffer.size}
	particle_next_info := vk.DescriptorBufferInfo{buffer = sim.gpu.particle_next_buffer.handle, offset = 0, range = sim.gpu.particle_next_buffer.size}
	grid_params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.grid_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Grid_Params))}
	collision_correction_info := vk.DescriptorBufferInfo{buffer = sim.gpu.collision_correction_buffer.handle, offset = 0, range = sim.gpu.collision_correction_buffer.size}
	collision_params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.collision_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Collision_Params))}
	init_params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.init_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Init_Params))}
	force_info := vk.DescriptorBufferInfo{buffer = sim.gpu.force_matrix_buffer.handle, offset = 0, range = sim.gpu.force_matrix_buffer.size}
	color_info := vk.DescriptorBufferInfo{buffer = sim.gpu.color_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Species_Colors))}
	mode_info := vk.DescriptorBufferInfo{buffer = sim.gpu.color_mode_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Color_Mode_Params))}
	camera_info := vk.DescriptorBufferInfo{buffer = sim.gpu.camera_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Camera))}
	viewport_info := vk.DescriptorBufferInfo{buffer = sim.gpu.viewport_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Viewport))}
	force_randomize_info := vk.DescriptorBufferInfo{buffer = sim.gpu.force_randomize_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Force_Randomize_Params))}
	force_update_info := vk.DescriptorBufferInfo{buffer = sim.gpu.force_update_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Force_Update_Params))}
	analysis_params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Analysis_Params))}
	analysis_cells_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_cells_buffer.handle, offset = 0, range = sim.gpu.analysis_cells_buffer.size}
	analysis_coherence_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_coherence_buffer.handle, offset = 0, range = sim.gpu.analysis_coherence_buffer.size}
	analysis_labels_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_labels_buffer.handle, offset = 0, range = sim.gpu.analysis_labels_buffer.size}
	analysis_tile_components_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_tile_components_buffer.handle, offset = 0, range = sim.gpu.analysis_tile_components_buffer.size}
	analysis_parent_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_parent_buffer.handle, offset = 0, range = sim.gpu.analysis_parent_buffer.size}
	analysis_blob_summaries_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_blob_summaries_buffer.handle, offset = 0, range = sim.gpu.analysis_blob_summaries_buffer.size}
	analysis_blob_count_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_blob_count_buffer.handle, offset = 0, range = sim.gpu.analysis_blob_count_buffer.size}
	sim_set := sim.gpu.sim_sets[frame_slot]
	init_set := sim.gpu.init_sets[frame_slot]
	color_set := sim.gpu.color_sets[frame_slot]
	view_set := sim.gpu.view_sets[frame_slot]
	force_randomize_set := sim.gpu.force_randomize_sets[frame_slot]
	force_update_set := sim.gpu.force_update_sets[frame_slot]
	analysis_set := sim.gpu.analysis_sets[frame_slot]
	writes := [29]vk.WriteDescriptorSet {
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &force_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_heads_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_next_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 5, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &grid_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 6, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_scratch_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 7, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &collision_correction_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 8, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &collision_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = init_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = init_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &init_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = color_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &color_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = color_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &mode_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = view_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &camera_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = view_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &viewport_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = force_randomize_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &force_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = force_randomize_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &force_randomize_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = force_update_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &force_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = force_update_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &force_update_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_cells_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_coherence_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 5, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_labels_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 6, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_tile_components_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 7, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_parent_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 8, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_blob_summaries_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 9, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_blob_count_info},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
}

particle_life_upload_force_matrix :: proc(sim: ^Particle_Life_Simulation) {
	if sim.gpu.force_matrix_buffer.mapped == nil {
		return
	}
	species_count := int(max(sim.gpu.uploaded_species_count, 1))
	forces := cast([^]f32)sim.gpu.force_matrix_buffer.mapped
	generated_matrix: [PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32
	if !sim.settings.custom_force_matrix {
		particle_life_generate_force_matrix(&generated_matrix, u32(species_count), sim.settings.force_generator, sim.settings.force_random_min, sim.settings.force_random_max, sim.runtime.seed)
	}
	for a in 0 ..< species_count {
		for b in 0 ..< species_count {
			v: f32
			if sim.settings.custom_force_matrix {
				v = sim.settings.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b]
			} else {
				v = generated_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b]
			}
			forces[a * species_count + b] = v
			sim.runtime.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = v
			sim.settings.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = v
		}
	}
	sim.settings.custom_force_matrix = true
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
			index := a * species_count + b
			value := generated_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b]
			sim.runtime.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = value
			sim.settings.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = value
			if sim.gpu.force_matrix_buffer.mapped != nil && sim.gpu.uploaded_species_count == u32(species_count) {
				forces := cast([^]f32)sim.gpu.force_matrix_buffer.mapped
				forces[index] = value
			}
		}
	}
	sim.settings.custom_force_matrix = true
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
	if sim.gpu.force_matrix_buffer.mapped != nil && sim.gpu.uploaded_species_count == species_count {
		forces := cast([^]f32)sim.gpu.force_matrix_buffer.mapped
		for a: u32 = 0; a < species_count; a += 1 {
			for b: u32 = 0; b < species_count; b += 1 {
				forces[a * species_count + b] = sim.runtime.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b]
			}
		}
	}
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
	if sim.gpu.force_matrix_buffer.mapped == nil || sim.gpu.uploaded_species_count == 0 {
		return
	}
	if a >= sim.gpu.uploaded_species_count || b >= sim.gpu.uploaded_species_count {
		return
	}
	forces := cast([^]f32)sim.gpu.force_matrix_buffer.mapped
	forces[a * sim.gpu.uploaded_species_count + b] = value
	sim.runtime.pending_force_update = true
	sim.runtime.pending_force_a = a
	sim.runtime.pending_force_b = b
	sim.runtime.pending_force_value = value
}

particle_life_upload_static_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.color_buffers[frame_slot].mapped != nil {
		colors := cast(^Particle_Life_Species_Colors)sim.gpu.color_buffers[frame_slot].mapped
		colors^ = {}
		scheme_name := color_scheme_name_get(&sim.settings.color_scheme)
		scheme, ok := color_scheme_load(scheme_name)
		if !ok {
			scheme = color_scheme_default()
		}
		if sim.settings.color_scheme_reversed {
			color_scheme_reverse(&scheme)
		}
		species_count := int(particle_life_target_species_count(sim.settings))
		for i in 0 ..< PARTICLE_LIFE_MAX_SPECIES {
			t := 0
			if sim.settings.background_color_mode == .Color_Scheme && species_count > 0 {
				t = int(((i + 1) * (COLOR_SCHEME_SIZE - 1)) / species_count)
			} else if PARTICLE_LIFE_MAX_SPECIES > 1 {
				t = int((i * (COLOR_SCHEME_SIZE - 1)) / (PARTICLE_LIFE_MAX_SPECIES - 1))
			}
			t = max(min(t, COLOR_SCHEME_SIZE - 1), 0)
			colors.colors[i] = {
				f32(scheme.red[t]) / 255.0,
				f32(scheme.green[t]) / 255.0,
				f32(scheme.blue[t]) / 255.0,
				1,
			}
		}
		colors.colors[PARTICLE_LIFE_MAX_SPECIES] = particle_life_background_color(&sim.settings)
	}
	if sim.gpu.color_mode_buffers[frame_slot].mapped != nil {
		mode := cast(^Particle_Life_Color_Mode_Params)sim.gpu.color_mode_buffers[frame_slot].mapped
		mode^ = {
			mode = u32(sim.settings.color_mode),
			brightness = sim.settings.brightness,
			contrast = sim.settings.contrast,
			saturation = sim.settings.saturation,
			gamma = max(sim.settings.gamma, 0.01),
		}
	}
}

particle_life_write_init_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.init_params_buffers[frame_slot].mapped == nil {
		return
	}
	world_size := particle_life_world_size(sim)
	params := cast(^Particle_Life_Init_Params)sim.gpu.init_params_buffers[frame_slot].mapped
	params^ = {
		start_index = 0,
		spawn_count = sim.gpu.uploaded_particle_count,
		species_count = sim.gpu.uploaded_species_count,
		width = world_size[0],
		height = world_size[1],
		random_seed = sim.runtime.seed,
		position_generator = sim.settings.position_generator,
		type_generator = sim.settings.type_generator,
	}
}

particle_life_write_frame_uniforms :: proc(sim: ^Particle_Life_Simulation, dt: f32) {
	frame_slot := sim.gpu.active_frame_slot
	particle_life_upload_static_uniforms(sim)
	width := f32(max(sim.gpu.width, 1))
	height := f32(max(sim.gpu.height, 1))
	aspect := width / max(height, 1)
	world_size := particle_life_world_size_for_viewport(width, height)
	bounds := particle_life_view_bounds(sim, width, height)
	if sim.gpu.params_buffers[frame_slot].mapped != nil {
		params := cast(^Particle_Life_Params)sim.gpu.params_buffers[frame_slot].mapped
		params^ = {
			particle_count = sim.gpu.uploaded_particle_count,
			species_count = sim.gpu.uploaded_species_count,
			max_force = sim.settings.max_force,
			max_distance = sim.settings.max_distance,
			friction = sim.settings.friction,
			wrap_edges = sim.settings.wrap_edges ? 1 : 0,
			width = world_size[0],
			height = world_size[1],
			random_seed = sim.runtime.seed + u32(sim.runtime.frame_index & 0xffffffff),
			dt = min(max(dt, 0.0), 0.033),
			beta = sim.settings.beta,
			cursor_x = sim.runtime.cursor_x,
			cursor_y = sim.runtime.cursor_y,
			cursor_size = sim.settings.cursor_size,
			cursor_strength = sim.settings.cursor_strength,
			cursor_active = sim.runtime.cursor_active,
			brownian_motion = sim.settings.brownian_motion,
			particle_size = sim.settings.particle_size,
			aspect_ratio = aspect,
		}
	}
	if sim.gpu.camera_buffers[frame_slot].mapped != nil {
		zoom := max(sim.runtime.camera_zoom, CAMERA_MIN_ZOOM)
		camera := cast(^Particle_Life_Camera)sim.gpu.camera_buffers[frame_slot].mapped
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
	if sim.gpu.viewport_buffers[frame_slot].mapped != nil {
		particle_life_write_viewport_uniforms(sim, width, height, bounds)
	}
}

particle_life_write_viewport_uniforms :: proc(sim: ^Particle_Life_Simulation, width, height: f32, bounds: [4]f32) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.viewport_buffers[frame_slot].mapped == nil {
		return
	}
	viewport := cast(^Particle_Life_Viewport)sim.gpu.viewport_buffers[frame_slot].mapped
	viewport^ = {
		world_bounds = bounds,
		texture_size = {width, height},
	}
}

particle_life_push_viewport_uniform_mode :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Graphics_Pipeline) {
	_ = vk_ctx
	push := Particle_Life_Viewport_Push{}
	vk.CmdPushConstants(cmd, pipeline.layout, {.VERTEX}, 0, u32(size_of(Particle_Life_Viewport_Push)), &push)
}

particle_life_push_viewport_bounds :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Graphics_Pipeline, bounds: [4]f32) {
	_ = vk_ctx
	push := Particle_Life_Viewport_Push{world_bounds = bounds, enabled = 1}
	vk.CmdPushConstants(cmd, pipeline.layout, {.VERTEX}, 0, u32(size_of(Particle_Life_Viewport_Push)), &push)
}

particle_life_write_grid_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.grid_params_buffers[frame_slot].mapped == nil {
		return
	}
	world_size := particle_life_world_size(sim)
	cell_w := world_size[0] / f32(max(sim.gpu.grid_width, 1))
	cell_h := world_size[1] / f32(max(sim.gpu.grid_height, 1))
	params := cast(^Particle_Life_Grid_Params)sim.gpu.grid_params_buffers[frame_slot].mapped
	params^ = {
		particle_count = sim.gpu.uploaded_particle_count,
		grid_width = sim.gpu.grid_width,
		grid_height = sim.gpu.grid_height,
		neighbor_radius_cells = sim.gpu.neighbor_radius_cells,
		cell_size = max(cell_w, cell_h),
		world_min_x = -world_size[0] * 0.5,
		world_min_y = -world_size[1] * 0.5,
		world_width = world_size[0],
		world_height = world_size[1],
	}
}

particle_life_write_collision_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.collision_params_buffers[frame_slot].mapped == nil {
		return
	}
	min_distance := particle_life_collision_distance(sim.settings)
	params := cast(^Particle_Life_Collision_Params)sim.gpu.collision_params_buffers[frame_slot].mapped
	params^ = {
		enabled = sim.settings.collision_enabled ? 1 : 0,
		iterations = max(min(sim.settings.collision_iterations, 8), 1),
		min_distance = min_distance,
		relaxation = max(min(sim.settings.collision_relaxation, 1.0), 0.0),
		max_correction = min_distance * 0.25,
		velocity_damping = max(min(sim.settings.collision_damping, 1.0), 0.0),
	}
}

particle_life_write_analysis_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.analysis_params_buffers[frame_slot].mapped != nil {
		params := cast(^Particle_Life_Analysis_Params)sim.gpu.analysis_params_buffers[frame_slot].mapped
		params^ = {
			enabled = sim.settings.analysis_enabled ? 1 : 0,
			interval_frames = max(sim.settings.analysis_interval_frames, 1),
			grid_size = max(sim.gpu.analysis_grid_axis, 1),
			min_blob_area_cells = max(sim.settings.min_blob_area_cells, 1),
			coherence_threshold = sim.settings.coherence_threshold,
		}
	}
	if sim.gpu.selected_blob_params_buffers[frame_slot].mapped != nil {
		params := cast(^Particle_Life_Selected_Blob_Params)sim.gpu.selected_blob_params_buffers[frame_slot].mapped
		params^ = {
			selected_blob_id = sim.runtime.selected_blob_id,
			overlay_enabled = sim.settings.blob_overlay_enabled ? 1 : 0,
		}
	}
}

particle_life_write_fade_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.fade_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Particle_Life_Fade_Params)sim.gpu.fade_params_buffers[frame_slot].mapped
	params^ = {
		fade_amount = max(min(sim.settings.trail_fade_amount, 1.0), 0.0),
	}
}

particle_life_write_background_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.background_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Particle_Life_Background_Params)sim.gpu.background_params_buffers[frame_slot].mapped
	params^ = {background_color = particle_life_background_color(&sim.settings)}
}

particle_life_write_post_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.post_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Particle_Life_Post_Params)sim.gpu.post_params_buffers[frame_slot].mapped
	params^ = {
		brightness = sim.settings.brightness,
		contrast = sim.settings.contrast,
		saturation = sim.settings.saturation,
		gamma = max(sim.settings.gamma, 0.01),
	}
}

particle_life_dispatch_init :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	particle_life_write_init_uniforms(sim)
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.init_pipeline.pipeline)
	init_set := sim.gpu.init_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.init_pipeline.layout, 0, 1, &init_set, 0, nil)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	barrier := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = {.SHADER_READ, .SHADER_WRITE},
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = sim.gpu.particle_buffer.handle,
		offset = 0,
		size = sim.gpu.particle_buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.COMPUTE_SHADER, .VERTEX_SHADER}, {}, 0, nil, 1, &barrier, 0, nil)
	sim.runtime.needs_reset = false
}

particle_life_force_barrier :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	barrier := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = {.SHADER_READ, .SHADER_WRITE},
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = sim.gpu.force_matrix_buffer.handle,
		offset = 0,
		size = sim.gpu.force_matrix_buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.COMPUTE_SHADER}, {}, 0, nil, 1, &barrier, 0, nil)
}

particle_life_buffer_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, buffer: engine.Vk_Buffer, dst_stage: vk.PipelineStageFlags, dst_access: vk.AccessFlags) {
	barrier := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = dst_access,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = buffer.handle,
		offset = 0,
		size = buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, dst_stage, {}, 0, nil, 1, &barrier, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

particle_life_grid_barrier :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dst_stage: vk.PipelineStageFlags, dst_access: vk.AccessFlags) {
	barriers := [2]vk.BufferMemoryBarrier {
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.grid_heads_buffer.handle, offset = 0, size = sim.gpu.grid_heads_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.particle_next_buffer.handle, offset = 0, size = sim.gpu.particle_next_buffer.size},
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, dst_stage, {}, 0, nil, u32(len(barriers)), raw_data(barriers[:]), 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx, u32(len(barriers)))
}

particle_life_copy_scratch_to_particles_transfer :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	to_transfer := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = {.TRANSFER_READ},
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = sim.gpu.particle_scratch_buffer.handle,
		offset = 0,
		size = sim.gpu.particle_scratch_buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.TRANSFER}, {}, 0, nil, 1, &to_transfer, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	region := vk.BufferCopy {
		srcOffset = 0,
		dstOffset = 0,
		size = min(sim.gpu.particle_scratch_buffer.size, sim.gpu.particle_buffer.size),
	}
	vk.CmdCopyBuffer(cmd, sim.gpu.particle_scratch_buffer.handle, sim.gpu.particle_buffer.handle, 1, &region)
	engine.vk_cmd_count_transfer_copy(vk_ctx)
	to_vertex := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.TRANSFER_WRITE},
		dstAccessMask = {.SHADER_READ},
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = sim.gpu.particle_buffer.handle,
		offset = 0,
		size = sim.gpu.particle_buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.TRANSFER}, {.VERTEX_SHADER, .COMPUTE_SHADER}, {}, 0, nil, 1, &to_vertex, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

particle_life_copy_scratch_to_particles :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	if sim.gpu.copy_scratch_pipeline.pipeline == vk.Pipeline(0) {
		particle_life_copy_scratch_to_particles_transfer(sim, vk_ctx, cmd)
		return
	}
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.copy_scratch_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.copy_scratch_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_buffer_barrier(vk_ctx, cmd, sim.gpu.particle_buffer, {.VERTEX_SHADER, .COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_grid_clear :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	particle_life_write_grid_uniforms(sim)
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.grid_clear_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.grid_clear_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	cells := sim.gpu.grid_width * sim.gpu.grid_height
	group_x := u32((cells + PARTICLE_LIFE_GRID_CLEAR_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_GRID_CLEAR_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_grid_barrier(sim, vk_ctx, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_grid_scatter :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.grid_scatter_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.grid_scatter_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_grid_barrier(sim, vk_ctx, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_grid_scatter_predicted :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.grid_scatter_predicted_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.grid_scatter_predicted_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_grid_barrier(sim, vk_ctx, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_binned_compute :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.compute_binned_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.compute_binned_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_buffer_barrier(vk_ctx, cmd, sim.gpu.particle_scratch_buffer, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_collision_solve :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.collision_solve_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.collision_solve_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_buffer_barrier(vk_ctx, cmd, sim.gpu.collision_correction_buffer, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_collision_apply :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.collision_apply_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.collision_apply_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_buffer_barrier(vk_ctx, cmd, sim.gpu.particle_scratch_buffer, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_collision_solver :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	particle_life_write_collision_uniforms(sim)
	if !sim.settings.collision_enabled {
		return
	}
	particle_life_dispatch_grid_clear(sim, vk_ctx, cmd)
	particle_life_dispatch_grid_scatter_predicted(sim, vk_ctx, cmd)
	iterations := max(min(sim.settings.collision_iterations, 8), 1)
	for iteration: u32 = 0; iteration < iterations; iteration += 1 {
		particle_life_dispatch_collision_solve(sim, vk_ctx, cmd)
		particle_life_dispatch_collision_apply(sim, vk_ctx, cmd)
	}
}

particle_life_analysis_frame_due :: proc(sim: ^Particle_Life_Simulation) -> bool {
	if !sim.settings.analysis_enabled {
		return false
	}
	interval := u64(max(sim.settings.analysis_interval_frames, 1))
	return sim.runtime.frame_index != sim.runtime.last_analysis_frame && (sim.runtime.frame_index % interval) == 0
}

particle_life_analysis_gpu_ready :: proc(sim: ^Particle_Life_Simulation) -> bool {
	return sim.gpu.analysis_sets[sim.gpu.active_frame_slot] != vk.DescriptorSet(0) &&
		sim.gpu.analysis_clear_pipeline.pipeline != vk.Pipeline(0) &&
		sim.gpu.analysis_blob_count_buffer.mapped != nil &&
		sim.gpu.analysis_blob_summaries_buffer.mapped != nil
}

particle_life_analysis_barrier :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer, dst_stage: vk.PipelineStageFlags, dst_access: vk.AccessFlags) {
	barriers := [7]vk.BufferMemoryBarrier {
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_cells_buffer.handle, offset = 0, size = sim.gpu.analysis_cells_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_coherence_buffer.handle, offset = 0, size = sim.gpu.analysis_coherence_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_labels_buffer.handle, offset = 0, size = sim.gpu.analysis_labels_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_tile_components_buffer.handle, offset = 0, size = sim.gpu.analysis_tile_components_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_parent_buffer.handle, offset = 0, size = sim.gpu.analysis_parent_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_blob_summaries_buffer.handle, offset = 0, size = sim.gpu.analysis_blob_summaries_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_blob_count_buffer.handle, offset = 0, size = sim.gpu.analysis_blob_count_buffer.size},
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, dst_stage, {}, 0, nil, u32(len(barriers)), raw_data(barriers[:]), 0, nil)
}

particle_life_dispatch_analysis_pipeline :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Compute_Pipeline, groups_x, groups_y: u32) {
	vk.CmdBindPipeline(cmd, .COMPUTE, pipeline.pipeline)
	analysis_set := sim.gpu.analysis_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, pipeline.layout, 0, 1, &analysis_set, 0, nil)
	vk.CmdDispatch(cmd, max(groups_x, 1), max(groups_y, 1), 1)
	particle_life_analysis_barrier(sim, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_gpu_blob_analysis :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	if !particle_life_analysis_frame_due(sim) || !particle_life_analysis_gpu_ready(sim) {
		return
	}
	particle_life_write_analysis_uniforms(sim)
	axis := max(sim.gpu.analysis_grid_axis, 1)
	cells := axis * axis
	particle_groups := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	cell_groups := u32((cells + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	tile_count := max(sim.gpu.analysis_tile_count, 1)

	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_clear_pipeline, cell_groups, 1)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_scatter_pipeline, particle_groups, 1)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_coherence_pipeline, cell_groups, 1)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_tile_label_pipeline, tile_count, tile_count)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_tile_merge_pipeline, cell_groups, 1)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_summarize_pipeline, cell_groups, 1)
	particle_life_analysis_barrier(sim, cmd, {.HOST}, {.HOST_READ})
	sim.runtime.last_analysis_frame = sim.runtime.frame_index
}

particle_life_read_gpu_blob_analysis :: proc(sim: ^Particle_Life_Simulation) {
	if !particle_life_analysis_frame_due(sim) || sim.runtime.last_analysis_frame == 0 || sim.runtime.last_analysis_read_frame == sim.runtime.last_analysis_frame || !particle_life_analysis_gpu_ready(sim) {
		return
	}
	count_ptr := cast(^u32)sim.gpu.analysis_blob_count_buffer.mapped
	accumulators := cast([^]Particle_Life_Blob_Accumulator)sim.gpu.analysis_blob_summaries_buffer.mapped
	raw_count := min(count_ptr^, PARTICLE_LIFE_ANALYSIS_MAX_BLOBS)
	summaries: [PARTICLE_LIFE_ANALYSIS_MAX_BLOBS]Particle_Life_Blob_Summary
	out_count: u32
	axis := max(sim.gpu.analysis_grid_axis, 1)
	world_size := particle_life_world_size(sim)
	cell_w := world_size[0] / f32(axis)
	cell_h := world_size[1] / f32(axis)
	world_min_x := -world_size[0] * 0.5
	world_min_y := -world_size[1] * 0.5
	for i: u32 = 0; i < raw_count; i += 1 {
		acc := accumulators[i]
		if acc.area < max(sim.settings.min_blob_area_cells, 1) || acc.density == 0 {
			continue
		}
		summary: Particle_Life_Blob_Summary
		summary.id = acc.id
		summary.area = acc.area
		summary.density = f32(acc.density)
		inv_density := 1.0 / max(f32(acc.density), 1.0)
		summary.centroid = {
			(f32(acc.centroid_sum[0]) / PARTICLE_LIFE_ANALYSIS_COORD_SCALE) * inv_density,
			(f32(acc.centroid_sum[1]) / PARTICLE_LIFE_ANALYSIS_COORD_SCALE) * inv_density,
		}
		summary.velocity = {
			(f32(acc.velocity_sum[0]) / PARTICLE_LIFE_ANALYSIS_VELOCITY_SCALE) * inv_density,
			(f32(acc.velocity_sum[1]) / PARTICLE_LIFE_ANALYSIS_VELOCITY_SCALE) * inv_density,
		}
		summary.bounds = {
			world_min_x + f32(acc.bounds_min[0]) * cell_w,
			world_min_y + f32(acc.bounds_min[1]) * cell_h,
			world_min_x + f32(acc.bounds_max[0] + 1) * cell_w,
			world_min_y + f32(acc.bounds_max[1] + 1) * cell_h,
		}
		summary.coherence_score = (f32(acc.coherence_sum) / PARTICLE_LIFE_ANALYSIS_COHERENCE_SCALE) / f32(max(acc.area, 1))
		summary.species_histogram = acc.species_histogram
		summaries[out_count] = summary
		out_count += 1
	}
	particle_life_blob_tracker_update(&sim.blob_tracker, summaries[:out_count])
	sim.runtime.last_analysis_read_frame = sim.runtime.last_analysis_frame
}

particle_life_dispatch_force_randomize :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	_ = cmd
	particle_life_force_matrix_upload_existing(sim, sim.gpu.uploaded_species_count)
	sim.runtime.pending_force_randomize = false
}

particle_life_dispatch_force_update :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.force_update_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Particle_Life_Force_Update_Params)sim.gpu.force_update_params_buffers[frame_slot].mapped
	params^ = {
		species_a = sim.runtime.pending_force_a,
		species_b = sim.runtime.pending_force_b,
		new_force = sim.runtime.pending_force_value,
		species_count = sim.gpu.uploaded_species_count,
	}
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.force_update_pipeline.pipeline)
	force_update_set := sim.gpu.force_update_sets[frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.force_update_pipeline.layout, 0, 1, &force_update_set, 0, nil)
	vk.CmdDispatch(cmd, 1, 1, 1)
	particle_life_force_barrier(sim, cmd)
	sim.runtime.pending_force_update = false
}

particle_life_gpu_step :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dt: f32) {
	if !particle_life_ensure_gpu_runtime(sim, vk_ctx) {
		return
	}
	sim.gpu.active_frame_slot = int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	particle_life_update_descriptors_for_slot(sim, vk_ctx, sim.gpu.active_frame_slot)
	target_analysis_axis := particle_life_target_analysis_grid_axis(sim.settings)
	grid_satisfies_target := particle_life_current_grid_satisfies_settings(sim)
	if sim.gpu.uploaded_particle_count != particle_life_target_particle_count(sim.settings) || sim.gpu.uploaded_species_count != particle_life_target_species_count(sim.settings) || !grid_satisfies_target || sim.gpu.analysis_grid_axis != target_analysis_axis {
		if sim.gpu.uploaded_particle_count != particle_life_target_particle_count(sim.settings) || sim.gpu.uploaded_species_count != particle_life_target_species_count(sim.settings) {
			particle_life_clear_preserved_particles(sim)
			sim.gpu.ready = false
		} else {
			particle_life_request_resource_rebuild(sim)
		}
		return
	}
	if sim.runtime.needs_reset {
		particle_life_dispatch_init(sim, cmd)
	}
	if sim.runtime.pending_force_randomize {
		particle_life_dispatch_force_randomize(sim, cmd)
	}
	if sim.runtime.pending_force_update {
		particle_life_dispatch_force_update(sim, cmd)
	}
	if sim.settings.paused {
		return
	}
	particle_life_read_gpu_blob_analysis(sim)
	particle_life_write_frame_uniforms(sim, dt)
	particle_life_write_analysis_uniforms(sim)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: grid clear")
	particle_life_dispatch_grid_clear(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: grid scatter")
	particle_life_dispatch_grid_scatter(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: force compute")
	particle_life_dispatch_binned_compute(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: collision solve/apply")
	particle_life_dispatch_collision_solver(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: copy scratch")
	particle_life_copy_scratch_to_particles(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: blob analysis")
	particle_life_dispatch_gpu_blob_analysis(sim, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
}

particle_life_draw_particles :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Graphics_Pipeline) {
	vk.CmdBindPipeline(cmd, .GRAPHICS, pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	frame_slot := sim.gpu.active_frame_slot
	sets := [3]vk.DescriptorSet{sim.gpu.sim_sets[frame_slot], sim.gpu.color_sets[frame_slot], sim.gpu.view_sets[frame_slot]}
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline.layout, 0, u32(len(sets)), raw_data(sets[:]), 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	particle_life_push_viewport_uniform_mode(vk_ctx, cmd, pipeline)
	vk.CmdDraw(cmd, 6, sim.gpu.uploaded_particle_count, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
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

particle_life_draw_infinite_tiles :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Graphics_Pipeline, width, height: f32) {
	bounds := particle_life_view_bounds(sim, width, height)
	tile_size := particle_life_world_size_for_viewport(width, height)
	tile_count := infinite_render_tile_count(sim.runtime.camera_zoom)
	center_x := i32(math.round(sim.runtime.camera_x / tile_size[0]))
	center_y := i32(math.round(sim.runtime.camera_y / tile_size[1]))
	half_tiles := i32(tile_count / 2)
	tile_start_x := center_x - half_tiles
	tile_start_y := center_y - half_tiles
	vk.CmdBindPipeline(cmd, .GRAPHICS, pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	frame_slot := sim.gpu.active_frame_slot
	sets := [3]vk.DescriptorSet{sim.gpu.sim_sets[frame_slot], sim.gpu.color_sets[frame_slot], sim.gpu.view_sets[frame_slot]}
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline.layout, 0, u32(len(sets)), raw_data(sets[:]), 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	for y: u32 = 0; y < tile_count; y += 1 {
		tile_y := tile_start_y + i32(y)
		for x: u32 = 0; x < tile_count; x += 1 {
			tile_x := tile_start_x + i32(x)
			tile_bounds := particle_life_tile_bounds_for_offset(bounds, tile_x, tile_y, tile_size)
			particle_life_push_viewport_bounds(vk_ctx, cmd, pipeline, tile_bounds)
			vk.CmdDraw(cmd, 6, sim.gpu.uploaded_particle_count, 0, 0)
			engine.vk_cmd_count_draw(vk_ctx)
		}
	}
	particle_life_push_viewport_uniform_mode(vk_ctx, cmd, pipeline)
}

particle_life_transition_trail_image :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, index: int, new_layout: vk.ImageLayout) {
	image := &sim.gpu.trail_images[index]
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
		case .TRANSFER_DST_OPTIMAL:
			dst_access = {.TRANSFER_WRITE}
			dst_stage = {.TRANSFER}
		}
	case .COLOR_ATTACHMENT_OPTIMAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.COLOR_ATTACHMENT_WRITE}
			dst_access = {.SHADER_READ}
			src_stage = {.COLOR_ATTACHMENT_OUTPUT}
			dst_stage = {.FRAGMENT_SHADER}
		case .TRANSFER_SRC_OPTIMAL:
			src_access = {.COLOR_ATTACHMENT_WRITE}
			dst_access = {.TRANSFER_READ}
			src_stage = {.COLOR_ATTACHMENT_OUTPUT}
			dst_stage = {.TRANSFER}
		}
	case .SHADER_READ_ONLY_OPTIMAL:
		#partial switch new_layout {
		case .COLOR_ATTACHMENT_OPTIMAL:
			src_access = {.SHADER_READ}
			dst_access = {.COLOR_ATTACHMENT_WRITE}
			src_stage = {.FRAGMENT_SHADER}
			dst_stage = {.COLOR_ATTACHMENT_OUTPUT}
		}
	case .TRANSFER_SRC_OPTIMAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.TRANSFER_READ}
			dst_access = {.SHADER_READ}
			src_stage = {.TRANSFER}
			dst_stage = {.FRAGMENT_SHADER}
		case .COLOR_ATTACHMENT_OPTIMAL:
			src_access = {.TRANSFER_READ}
			dst_access = {.COLOR_ATTACHMENT_WRITE}
			src_stage = {.TRANSFER}
			dst_stage = {.COLOR_ATTACHMENT_OUTPUT}
		}
	case .TRANSFER_DST_OPTIMAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.TRANSFER_WRITE}
			dst_access = {.SHADER_READ}
			src_stage = {.TRANSFER}
			dst_stage = {.FRAGMENT_SHADER}
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
		image = image.handle,
		subresourceRange = {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
		},
	}
	vk.CmdPipelineBarrier(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	image.layout = new_layout
}

particle_life_update_fade_descriptor :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot, set_index, read_index: int) {
	params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.fade_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Fade_Params))}
	image_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = sim.gpu.trail_images[read_index].view}
	sampler_info := vk.DescriptorImageInfo{sampler = sim.gpu.trail_sampler}
	set := sim.gpu.fade_sets[frame_slot][set_index]
	writes := [3]vk.WriteDescriptorSet {
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 2, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
}

particle_life_update_background_descriptor :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.background_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Background_Params))}
	write := vk.WriteDescriptorSet {
		sType = .WRITE_DESCRIPTOR_SET,
		dstSet = sim.gpu.background_sets[frame_slot],
		dstBinding = 0,
		descriptorType = .UNIFORM_BUFFER,
		descriptorCount = 1,
		pBufferInfo = &params_info,
	}
	vk.UpdateDescriptorSets(vk_ctx.device, 1, &write, 0, nil)
}

particle_life_update_post_descriptors :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.post_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Post_Params))}
	camera_info := vk.DescriptorBufferInfo{buffer = sim.gpu.camera_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Camera))}
	sampler_info := vk.DescriptorImageInfo{sampler = sim.gpu.trail_sampler}
	for i in 0 ..< len(sim.gpu.trail_images) {
		image_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = sim.gpu.trail_images[i].view}
		set := sim.gpu.post_sets[frame_slot][i]
		writes := [4]vk.WriteDescriptorSet {
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 1, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &camera_info},
		}
		vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
	}
}

particle_life_destroy_trail_image :: proc(vk_ctx: ^engine.Vk_Context, image: ^Particle_Life_Trail_Image) {
	if image.framebuffer != vk.Framebuffer(0) {
		vk.DestroyFramebuffer(vk_ctx.device, image.framebuffer, nil)
	}
	if image.view != vk.ImageView(0) {
		vk.DestroyImageView(vk_ctx.device, image.view, nil)
	}
	if image.handle != vk.Image(0) {
		vk.DestroyImage(vk_ctx.device, image.handle, nil)
	}
	if image.memory != vk.DeviceMemory(0) {
		vk.FreeMemory(vk_ctx.device, image.memory, nil)
	}
	image^ = {}
}

particle_life_destroy_trail_targets :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	for i in 0 ..< len(sim.gpu.trail_images) {
		particle_life_destroy_trail_image(vk_ctx, &sim.gpu.trail_images[i])
	}
	sim.gpu.trail_width = 0
	sim.gpu.trail_height = 0
	sim.gpu.trail_initialized = false
	sim.gpu.trail_write_index = 0
}

particle_life_frame_slot_mask :: proc() -> u32 {
	return (u32(1) << u32(engine.MAX_FRAMES_IN_FLIGHT)) - 1
}

particle_life_collect_retired_trail_targets :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	bit := u32(1) << u32(frame_slot)
	for i in 0 ..< PARTICLE_LIFE_RETIRED_TRAIL_TARGET_CAP {
		retired := &sim.gpu.retired_trail_targets[i]
		if retired.pending_frame_slots == 0 {
			continue
		}
		retired.pending_frame_slots = retired.pending_frame_slots & (~bit)
		if retired.pending_frame_slots == 0 {
			for image_index in 0 ..< len(retired.images) {
				particle_life_destroy_trail_image(vk_ctx, &retired.images[image_index])
			}
		}
	}
}

particle_life_retire_trail_targets :: proc(sim: ^Particle_Life_Simulation) -> bool {
	if sim.gpu.trail_images[0].handle == vk.Image(0) && sim.gpu.trail_images[1].handle == vk.Image(0) {
		sim.gpu.trail_images = {}
		sim.gpu.trail_width = 0
		sim.gpu.trail_height = 0
		sim.gpu.trail_initialized = false
		sim.gpu.trail_write_index = 0
		return true
	}
	for i in 0 ..< PARTICLE_LIFE_RETIRED_TRAIL_TARGET_CAP {
		retired := &sim.gpu.retired_trail_targets[i]
		if retired.pending_frame_slots == 0 {
			retired.images = sim.gpu.trail_images
			retired.pending_frame_slots = particle_life_frame_slot_mask()
			sim.gpu.trail_images = {}
			sim.gpu.trail_width = 0
			sim.gpu.trail_height = 0
			sim.gpu.trail_initialized = false
			sim.gpu.trail_write_index = 0
			return true
		}
	}
	engine.log_warn("particle life: trail target retire slots exhausted")
	return false
}

particle_life_ensure_trail_targets :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	width := max(vk_ctx.swapchain_extent.width, u32(1))
	height := max(vk_ctx.swapchain_extent.height, u32(1))
	if sim.gpu.trail_width == width && sim.gpu.trail_height == height && sim.gpu.trail_images[0].handle != vk.Image(0) && sim.gpu.trail_images[1].handle != vk.Image(0) {
		return true
	}
	if !particle_life_retire_trail_targets(sim) {
		return false
	}
	for i in 0 ..< len(sim.gpu.trail_images) {
		if !particle_life_create_trail_image(sim, vk_ctx, i, width, height) {
			particle_life_destroy_trail_targets(sim, vk_ctx)
			return false
		}
	}
	sim.gpu.trail_width = width
	sim.gpu.trail_height = height
	frame_slot := int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	particle_life_update_background_descriptor(sim, vk_ctx, frame_slot)
	particle_life_update_post_descriptors(sim, vk_ctx, frame_slot)
	particle_life_collect_retired_trail_targets(sim, vk_ctx, frame_slot)
	return true
}

particle_life_post_trail_to_swapchain :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, source_index: int, ui: ^engine.Ui_Renderer = nil) {
	cmd := frame.command_buffer
	frame_slot := int(frame.frame_index)
	particle_life_write_post_uniforms(sim)
	particle_life_update_post_descriptors(sim, vk_ctx, frame_slot)
	particle_life_transition_trail_image(sim, vk_ctx, cmd, source_index, .SHADER_READ_ONLY_OPTIMAL)
	engine.vk_cmd_begin_swapchain_render_pass(vk_ctx, frame, particle_life_clear_color(sim))
	extent := vk_ctx.swapchain_extent
	viewport := vk.Viewport{x = 0, y = 0, width = f32(extent.width), height = f32(extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = extent}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	if sim.settings.infinite_tiles_enabled && sim.gpu.tiled_post_pipeline.pipeline != vk.Pipeline(0) {
		vk.CmdBindPipeline(cmd, .GRAPHICS, sim.gpu.tiled_post_pipeline.pipeline)
	} else {
		vk.CmdBindPipeline(cmd, .GRAPHICS, sim.gpu.post_pipeline.pipeline)
	}
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	pipeline_layout := sim.gpu.post_pipeline.layout
	if sim.settings.infinite_tiles_enabled && sim.gpu.tiled_post_pipeline.layout != vk.PipelineLayout(0) {
		pipeline_layout = sim.gpu.tiled_post_pipeline.layout
	}
	post_set := sim.gpu.post_sets[frame_slot][source_index]
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline_layout, 0, 1, &post_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	instance_count := u32(1)
	if sim.settings.infinite_tiles_enabled {
		tile_count := infinite_render_tile_count(sim.runtime.camera_zoom)
		instance_count = tile_count * tile_count
	}
	vk.CmdDraw(cmd, 6, instance_count, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
	if ui != nil {
		engine.vk_cmd_label_begin(vk_ctx, cmd, "UI overlay")
		engine.ui_renderer_draw(ui, vk_ctx, cmd, vk_ctx.swapchain_extent)
		engine.vk_cmd_label_end(vk_ctx, cmd)
	}
	engine.vk_cmd_end_swapchain_render_pass(frame)
}

particle_life_gpu_present_trails :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, ui: ^engine.Ui_Renderer = nil) {
	sim.gpu.active_frame_slot = int(frame.frame_index)
	particle_life_update_background_descriptor(sim, vk_ctx, sim.gpu.active_frame_slot)
	particle_life_update_post_descriptors(sim, vk_ctx, sim.gpu.active_frame_slot)
	particle_life_collect_retired_trail_targets(sim, vk_ctx, sim.gpu.active_frame_slot)
	particle_life_note_trail_camera(sim)
	cmd := frame.command_buffer
	write_index := int(sim.gpu.trail_write_index & 1)
	read_index := 1 - write_index
	particle_life_transition_trail_image(sim, vk_ctx, cmd, write_index, .COLOR_ATTACHMENT_OPTIMAL)
	if sim.settings.trails_enabled && sim.gpu.trail_initialized {
		particle_life_transition_trail_image(sim, vk_ctx, cmd, read_index, .SHADER_READ_ONLY_OPTIMAL)
		particle_life_write_fade_uniforms(sim)
		particle_life_update_fade_descriptor(sim, vk_ctx, sim.gpu.active_frame_slot, write_index, read_index)
	}

	clear_value := vk.ClearValue{color = {float32 = {0, 0, 0, 0}}}
	begin := vk.RenderPassBeginInfo {
		sType = .RENDER_PASS_BEGIN_INFO,
		renderPass = sim.gpu.trail_render_pass,
		framebuffer = sim.gpu.trail_images[write_index].framebuffer,
		renderArea = {offset = {0, 0}, extent = {sim.gpu.trail_width, sim.gpu.trail_height}},
		clearValueCount = 1,
		pClearValues = &clear_value,
	}
	vk.CmdBeginRenderPass(cmd, &begin, .INLINE)
	vk_ctx.command_shape.render_pass_count += 1
	viewport := vk.Viewport{x = 0, y = 0, width = f32(sim.gpu.trail_width), height = f32(sim.gpu.trail_height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = {sim.gpu.trail_width, sim.gpu.trail_height}}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	particle_life_write_background_uniforms(sim)
	particle_life_update_background_descriptor(sim, vk_ctx, sim.gpu.active_frame_slot)
	vk.CmdBindPipeline(cmd, .GRAPHICS, sim.gpu.background_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	background_set := sim.gpu.background_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, sim.gpu.background_pipeline.layout, 0, 1, &background_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDraw(cmd, 6, 1, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
	if sim.settings.trails_enabled && sim.gpu.trail_initialized {
		vk.CmdBindPipeline(cmd, .GRAPHICS, sim.gpu.fade_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		fade_set := sim.gpu.fade_sets[sim.gpu.active_frame_slot][write_index]
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, sim.gpu.fade_pipeline.layout, 0, 1, &fade_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 3, 1, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
	particle_life_draw_particles(sim, vk_ctx, cmd, &sim.gpu.trail_particle_pipeline)
	vk.CmdEndRenderPass(cmd)
	sim.gpu.trail_images[write_index].layout = .COLOR_ATTACHMENT_OPTIMAL
	sim.gpu.trail_initialized = true
	particle_life_post_trail_to_swapchain(sim, vk_ctx, frame, write_index, ui)
	sim.gpu.trail_write_index = u32(read_index)
}

particle_life_gpu_present :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, ui: ^engine.Ui_Renderer = nil) {
	if !particle_life_ensure_gpu_runtime(sim, vk_ctx) {
		return
	}
	sim.gpu.active_frame_slot = int(frame.frame_index)
	if sim.settings.paused {
		particle_life_write_frame_uniforms(sim, 0)
	}
	particle_life_update_descriptors_for_slot(sim, vk_ctx, sim.gpu.active_frame_slot)
	extent := vk_ctx.swapchain_extent
	if extent.width == 0 || extent.height == 0 {
		return
	}
	cmd := frame.command_buffer
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: present")
	defer engine.vk_cmd_label_end(vk_ctx, cmd)
	if particle_life_ensure_trail_targets(sim, vk_ctx) {
		particle_life_gpu_present_trails(sim, vk_ctx, frame, ui)
		return
	}
	engine.vk_cmd_begin_swapchain_render_pass(vk_ctx, frame, particle_life_clear_color(sim))
	viewport := vk.Viewport{x = 0, y = 0, width = f32(extent.width), height = f32(extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = extent}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	if sim.settings.infinite_tiles_enabled {
		particle_life_draw_infinite_tiles(sim, vk_ctx, cmd, &sim.gpu.render_pipeline, f32(extent.width), f32(extent.height))
	} else {
		particle_life_draw_particles(sim, vk_ctx, cmd, &sim.gpu.render_pipeline)
	}
	if ui != nil {
		engine.vk_cmd_label_begin(vk_ctx, cmd, "UI overlay")
		engine.ui_renderer_draw(ui, vk_ctx, cmd, vk_ctx.swapchain_extent)
		engine.vk_cmd_label_end(vk_ctx, cmd)
	}
	engine.vk_cmd_end_swapchain_render_pass(frame)
}

particle_life_gpu_present_viewport :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !particle_life_ensure_gpu_runtime(sim, vk_ctx) {
		return
	}
	sim.gpu.active_frame_slot = int(frame.frame_index)
	if sim.settings.paused {
		particle_life_write_frame_uniforms(sim, 0)
	}
	particle_life_update_descriptors_for_slot(sim, vk_ctx, sim.gpu.active_frame_slot)
	particle_life_gpu_draw_prepared_viewport(sim, vk_ctx, frame, viewport, scissor)
}

particle_life_gpu_draw_prepared_viewport :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if sim.gpu.render_pipeline.pipeline == vk.Pipeline(0) {
		return
	}
	cmd := frame.command_buffer
	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(cmd, 0, 1, &local_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &local_scissor)
	if sim.settings.infinite_tiles_enabled {
		particle_life_draw_infinite_tiles(sim, vk_ctx, cmd, &sim.gpu.render_pipeline, viewport.width, viewport.height)
	} else {
		particle_life_draw_particles(sim, vk_ctx, cmd, &sim.gpu.render_pipeline)
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
	sim.runtime.seed += 0x85ebca6b
	sim.settings.custom_force_matrix = false
	particle_life_mirror_force_randomize(sim)
	sim.runtime.pending_force_randomize = true
}

particle_life_load_settings :: proc(sim: ^Particle_Life_Simulation, settings: Particle_Life_Settings) {
	particle_count_changed := sim.gpu.uploaded_particle_count != 0 && sim.gpu.uploaded_particle_count != particle_life_target_particle_count(settings)
	species_count_changed := sim.gpu.uploaded_species_count != 0 && sim.gpu.uploaded_species_count != particle_life_target_species_count(settings)
	sim.settings = settings
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
		particle_life_upload_force_matrix(sim)
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

particle_life_destroy :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	particle_life_analysis_workspace_destroy(&sim.runtime.analysis)
	if vk_ctx == nil || vk_ctx.device == nil {
		sim.gpu = {}
		return
	}
	if sim.gpu.grid_clear_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.grid_clear_pipeline.pipeline, nil)
	}
	if sim.gpu.grid_clear_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.grid_clear_pipeline.layout, nil)
	}
	if sim.gpu.grid_scatter_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.grid_scatter_pipeline.pipeline, nil)
	}
	if sim.gpu.grid_scatter_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.grid_scatter_pipeline.layout, nil)
	}
	if sim.gpu.grid_scatter_predicted_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.grid_scatter_predicted_pipeline.pipeline, nil)
	}
	if sim.gpu.grid_scatter_predicted_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.grid_scatter_predicted_pipeline.layout, nil)
	}
	if sim.gpu.compute_binned_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.compute_binned_pipeline.pipeline, nil)
	}
	if sim.gpu.compute_binned_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.compute_binned_pipeline.layout, nil)
	}
	if sim.gpu.collision_solve_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.collision_solve_pipeline.pipeline, nil)
	}
	if sim.gpu.collision_solve_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.collision_solve_pipeline.layout, nil)
	}
	if sim.gpu.collision_apply_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.collision_apply_pipeline.pipeline, nil)
	}
	if sim.gpu.collision_apply_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.collision_apply_pipeline.layout, nil)
	}
	if sim.gpu.copy_scratch_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.copy_scratch_pipeline.pipeline, nil)
	}
	if sim.gpu.copy_scratch_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.copy_scratch_pipeline.layout, nil)
	}
	if sim.gpu.analysis_clear_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.analysis_clear_pipeline.pipeline, nil)
	}
	if sim.gpu.analysis_clear_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.analysis_clear_pipeline.layout, nil)
	}
	if sim.gpu.analysis_scatter_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.analysis_scatter_pipeline.pipeline, nil)
	}
	if sim.gpu.analysis_scatter_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.analysis_scatter_pipeline.layout, nil)
	}
	if sim.gpu.analysis_coherence_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.analysis_coherence_pipeline.pipeline, nil)
	}
	if sim.gpu.analysis_coherence_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.analysis_coherence_pipeline.layout, nil)
	}
	if sim.gpu.analysis_tile_label_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.analysis_tile_label_pipeline.pipeline, nil)
	}
	if sim.gpu.analysis_tile_label_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.analysis_tile_label_pipeline.layout, nil)
	}
	if sim.gpu.analysis_tile_merge_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.analysis_tile_merge_pipeline.pipeline, nil)
	}
	if sim.gpu.analysis_tile_merge_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.analysis_tile_merge_pipeline.layout, nil)
	}
	if sim.gpu.analysis_summarize_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.analysis_summarize_pipeline.pipeline, nil)
	}
	if sim.gpu.analysis_summarize_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.analysis_summarize_pipeline.layout, nil)
	}
	if sim.gpu.init_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.init_pipeline.pipeline, nil)
	}
	if sim.gpu.init_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.init_pipeline.layout, nil)
	}
	if sim.gpu.force_randomize_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.force_randomize_pipeline.pipeline, nil)
	}
	if sim.gpu.force_randomize_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.force_randomize_pipeline.layout, nil)
	}
	if sim.gpu.force_update_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.force_update_pipeline.pipeline, nil)
	}
	if sim.gpu.force_update_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.force_update_pipeline.layout, nil)
	}
	if sim.gpu.render_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.render_pipeline)
	}
	if sim.gpu.trail_particle_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.trail_particle_pipeline)
	}
	if sim.gpu.fade_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.fade_pipeline)
	}
	if sim.gpu.background_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.background_pipeline)
	}
	if sim.gpu.post_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.post_pipeline)
	}
	if sim.gpu.tiled_post_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.tiled_post_pipeline)
	}
	particle_life_destroy_trail_targets(sim, vk_ctx)
	for i in 0 ..< PARTICLE_LIFE_RETIRED_TRAIL_TARGET_CAP {
		for image_index in 0 ..< len(sim.gpu.retired_trail_targets[i].images) {
			particle_life_destroy_trail_image(vk_ctx, &sim.gpu.retired_trail_targets[i].images[image_index])
		}
	}
	if sim.gpu.trail_sampler != vk.Sampler(0) {
		vk.DestroySampler(vk_ctx.device, sim.gpu.trail_sampler, nil)
	}
	if sim.gpu.trail_render_pass != vk.RenderPass(0) {
		vk.DestroyRenderPass(vk_ctx.device, sim.gpu.trail_render_pass, nil)
	}
	if sim.gpu.descriptor_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, sim.gpu.descriptor_pool, nil)
	}
	if sim.gpu.fade_descriptor_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, sim.gpu.fade_descriptor_pool, nil)
	}
	if sim.gpu.sim_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.sim_set_layout, nil)
	}
	if sim.gpu.init_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.init_set_layout, nil)
	}
	if sim.gpu.color_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.color_set_layout, nil)
	}
	if sim.gpu.view_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.view_set_layout, nil)
	}
	if sim.gpu.fade_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.fade_set_layout, nil)
	}
	if sim.gpu.background_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.background_set_layout, nil)
	}
	if sim.gpu.post_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.post_set_layout, nil)
	}
	if sim.gpu.force_op_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.force_op_set_layout, nil)
	}
	if sim.gpu.analysis_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.analysis_set_layout, nil)
	}
	if sim.gpu.particle_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.particle_buffer)
	}
	if sim.gpu.particle_scratch_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.particle_scratch_buffer)
	}
	if sim.gpu.grid_heads_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.grid_heads_buffer)
	}
	if sim.gpu.particle_next_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.particle_next_buffer)
	}
	if sim.gpu.collision_correction_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.collision_correction_buffer)
	}
	if sim.gpu.analysis_cells_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_cells_buffer)
	}
	if sim.gpu.analysis_coherence_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_coherence_buffer)
	}
	if sim.gpu.analysis_labels_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_labels_buffer)
	}
	if sim.gpu.analysis_tile_components_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_tile_components_buffer)
	}
	if sim.gpu.analysis_parent_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_parent_buffer)
	}
	if sim.gpu.analysis_blob_summaries_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_blob_summaries_buffer)
	}
	if sim.gpu.analysis_blob_count_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_blob_count_buffer)
	}
	if sim.gpu.force_matrix_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.force_matrix_buffer)
	}
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.init_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.fade_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.force_randomize_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.force_update_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.grid_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.collision_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.analysis_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.selected_blob_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.background_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.post_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.color_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.color_mode_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.camera_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.viewport_buffers[frame_slot])
	}
	if sim.gpu.grid_clear_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.grid_clear_shader_module)
	}
	if sim.gpu.grid_scatter_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.grid_scatter_shader_module)
	}
	if sim.gpu.grid_scatter_predicted_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.grid_scatter_predicted_shader_module)
	}
	if sim.gpu.compute_binned_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.compute_binned_shader_module)
	}
	if sim.gpu.collision_solve_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.collision_solve_shader_module)
	}
	if sim.gpu.collision_apply_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.collision_apply_shader_module)
	}
	if sim.gpu.copy_scratch_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.copy_scratch_shader_module)
	}
	if sim.gpu.init_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.init_shader_module)
	}
	if sim.gpu.vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.vertex_shader_module)
	}
	if sim.gpu.fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.fragment_shader_module)
	}
	if sim.gpu.fade_vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.fade_vertex_shader_module)
	}
	if sim.gpu.fade_fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.fade_fragment_shader_module)
	}
	if sim.gpu.force_randomize_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.force_randomize_shader_module)
	}
	if sim.gpu.force_update_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.force_update_shader_module)
	}
	if sim.gpu.analysis_clear_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.analysis_clear_shader_module)
	}
	if sim.gpu.analysis_scatter_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.analysis_scatter_shader_module)
	}
	if sim.gpu.analysis_coherence_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.analysis_coherence_shader_module)
	}
	if sim.gpu.analysis_tile_label_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.analysis_tile_label_shader_module)
	}
	if sim.gpu.analysis_tile_merge_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.analysis_tile_merge_shader_module)
	}
	if sim.gpu.analysis_summarize_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.analysis_summarize_shader_module)
	}
	if sim.gpu.background_vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.background_vertex_shader_module)
	}
	if sim.gpu.background_fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.background_fragment_shader_module)
	}
	if sim.gpu.post_vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.post_vertex_shader_module)
	}
	if sim.gpu.post_fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.post_fragment_shader_module)
	}
	if sim.gpu.infinite_present_vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.infinite_present_vertex_shader_module)
	}
	if sim.gpu.infinite_present_fragment_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.infinite_present_fragment_shader_module)
	}
	width := sim.gpu.width
	height := sim.gpu.height
	sim.gpu = {width = width, height = height}
}

particle_life_controls_content_height :: proc(sim: ^Particle_Life_Simulation, ctx: ^uifw.Gui_Context) -> f32 {
	rows := 111
	sections := 12
	rows += preset_fieldset_content_rows(&sim.runtime.preset_ui) - 3
	matrix_rows := PARTICLE_LIFE_MAX_SPECIES + 2
	extra := 286 + f32(matrix_rows) * 42 + 7 * ctx.style.row_height
	slider_extra := max(uifw.gui_slider_height(ctx) - ctx.style.row_height, 0)
	slider_count := 22
	return f32(rows) * ctx.style.row_height + f32(max(rows - 1, 0) + sections + 18) * ctx.style.spacing + f32(sections) * 12 + extra + slider_extra * f32(slider_count)
}

particle_life_enqueue_preset_command :: proc(worker: ^Render_Worker_State, kind: Ui_To_Render_Command_Kind, name: string) {
	if worker == nil || worker.ui_to_render == nil {
		return
	}
	cmd: Ui_To_Render_Command
	cmd.kind = kind
	write_fixed_string(cmd.preset_name[:], name)
	_ = engine.queue_try_push(worker.ui_to_render, cmd)
}

particle_life_small_button :: proc(ctx: ^uifw.Gui_Context, rect: uifw.Rect, label, key: string) -> bool {
	return uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, key), rect, label, true)
}

particle_life_force_cell_label :: proc(value: f32) -> string {
	if value >= 0.995 {
		return "+1"
	}
	if value <= -0.995 {
		return "-1"
	}
	if math.abs(value) < 0.05 {
		return "0"
	}
	if value > 0 {
		return fmt.tprintf("+%.1f", value)
	}
	return fmt.tprintf("%.1f", value)
}

particle_life_draw_force_curve_editor :: proc(sim: ^Particle_Life_Simulation, ctx: ^uifw.Gui_Context) {
	row := uifw.gui_next_rect(ctx, height = ctx.style.row_height)
	button_w := min(132, row.w * 0.44)
	if particle_life_small_button(ctx, {row.x, row.y, button_w, row.h}, sim.runtime.force_curve_narrow_range ? "Narrow 0.01-0.1" : "Wide 0.01-1.0", "pl_curve_range") {
		sim.runtime.force_curve_narrow_range = !sim.runtime.force_curve_narrow_range
	}
	if particle_life_small_button(ctx, {row.x + row.w - button_w, row.y, button_w, row.h}, "Reset Physics", "pl_curve_reset") {
		sim.settings.max_force = 0.5
		sim.settings.max_distance = 0.01
		sim.settings.beta = 0.3
		sim.settings.friction = 0.5
		sim.settings.brownian_motion = 0.5
	}

	bounds := uifw.gui_next_rect(ctx, height = 236)
	uifw.gui_round_rect(ctx, bounds, 4, {0.10, 0.10, 0.10, 1})
	uifw.gui_round_stroke(ctx, bounds, 4, ctx.style.panel_border, ctx.style.border_width)
	margin := f32(34)
	plot := uifw.Rect{bounds.x + margin, bounds.y + 22, max(bounds.w - margin * 2, 1), max(bounds.h - 54, 1)}
	y_offset := plot.y + plot.h * 0.5
	max_scale_force := sim.runtime.force_curve_narrow_range ? f32(1.0) : f32(10.0)
	max_plot_distance := sim.runtime.force_curve_narrow_range ? f32(0.1) : f32(1.0)
	y_scale := plot.h / (2 * max_scale_force)
	to_y := proc(y: f32, y_offset, y_scale: f32) -> f32 {
		return y_offset - y * y_scale
	}
	to_x := proc(distance, max_plot_distance: f32, plot: uifw.Rect) -> f32 {
		return plot.x + (distance / max(max_plot_distance, 0.0001)) * plot.w
	}
	max_distance_x := to_x(sim.settings.max_distance, max_plot_distance, plot)
	beta_distance := sim.settings.beta * sim.settings.max_distance
	beta_x := to_x(min(beta_distance, sim.settings.max_distance), max_plot_distance, plot)
	max_force_y := to_y(sim.settings.max_force, y_offset, y_scale)

	inactive := uifw.Rect{max_distance_x, plot.y, max(plot.x + plot.w - max_distance_x, 0), plot.h}
	uifw.gui_rect(ctx, inactive, {0.06, 0.06, 0.06, 1})
	uifw.gui_rect(ctx, {plot.x, plot.y, max(beta_x - plot.x, 0), plot.h}, {0.94, 0.27, 0.27, 0.18})
	uifw.gui_rect(ctx, {beta_x, plot.y, max(max_distance_x - beta_x, 0), plot.h}, {0.23, 0.51, 0.96, 0.18})
	for i in 0 ..= 10 {
		x := plot.x + plot.w * f32(i) / 10
		uifw.gui_line(ctx, {x, plot.y}, {x, plot.y + plot.h}, {0.26, 0.26, 0.26, 0.65}, 1)
	}
	uifw.gui_line(ctx, {plot.x, y_offset}, {plot.x + plot.w, y_offset}, {0.42, 0.42, 0.42, 0.9}, 1)
	uifw.gui_line(ctx, {beta_x, plot.y}, {beta_x, plot.y + plot.h}, {0.90, 0.55, 0.10, 0.9}, 1)
	uifw.gui_line(ctx, {max_distance_x, plot.y}, {max_distance_x, plot.y + plot.h}, {0.23, 0.51, 0.96, 0.95}, 2)
	uifw.gui_line(ctx, {plot.x, plot.y}, {plot.x, plot.y + plot.h}, {0.32, 0.81, 0.40, 0.95}, 2)

	prev: uifw.Vec2
	for step in 0 ..= 160 {
		distance := sim.settings.max_distance * f32(step) / 160
		force := particle_life_force_curve_value(sim.settings.max_force, sim.settings.max_distance, sim.settings.beta, distance)
		p := uifw.Vec2{to_x(distance, max_plot_distance, plot), to_y(force, y_offset, y_scale)}
		if step > 0 {
			uifw.gui_line(ctx, prev, p, {0.94, 0.27, 0.27, 1}, 3)
		}
		prev = p
	}

	max_force_handle := uifw.Vec2{plot.x, max_force_y}
	max_distance_handle := uifw.Vec2{max_distance_x, y_offset}
	beta_handle := uifw.Vec2{beta_x, y_offset}
	force_id := uifw.gui_make_id(ctx, "pl_curve_force_handle")
	distance_id := uifw.gui_make_id(ctx, "pl_curve_distance_handle")
	beta_id := uifw.gui_make_id(ctx, "pl_curve_beta_handle")
	handle_hit_radius := f32(14)
	force_hit := uifw.Rect{max_force_handle.x - handle_hit_radius, max_force_handle.y - handle_hit_radius, handle_hit_radius * 2, handle_hit_radius * 2}
	distance_hit := uifw.Rect{max_distance_handle.x - handle_hit_radius, max_distance_handle.y - handle_hit_radius, handle_hit_radius * 2, handle_hit_radius * 2}
	beta_hit := uifw.Rect{beta_handle.x - handle_hit_radius, beta_handle.y - handle_hit_radius, handle_hit_radius * 2, handle_hit_radius * 2}
	if ctx.input.mouse_pressed && uifw.gui_mouse_contains(ctx, beta_hit) {
		sim.runtime.force_curve_beta_drag_start_x = ctx.input.mouse_pos.x
		sim.runtime.force_curve_beta_drag_start_value = sim.settings.beta
	}
	if uifw.gui_drag_handle_region(ctx, force_id, force_hit, max_force_handle, 12) {
		sim.settings.max_force = max((y_offset - ctx.input.mouse_pos.y) / y_scale, 0.1)
		sim.settings.max_force = min(sim.settings.max_force, max_scale_force)
	}
	if uifw.gui_drag_handle_region(ctx, distance_id, distance_hit, max_distance_handle, 12) {
		t := max(min((ctx.input.mouse_pos.x - plot.x) / max(plot.w, 1), 1), 0)
		sim.settings.max_distance = max(t * max_plot_distance, 0.001)
	}
	if uifw.gui_drag_handle_region(ctx, beta_id, beta_hit, beta_handle, 12) {
		delta_x := ctx.input.mouse_pos.x - sim.runtime.force_curve_beta_drag_start_x
		sim.settings.beta = max(min(sim.runtime.force_curve_beta_drag_start_value + delta_x * 0.002, 0.9), 0.1)
	}
	uifw.gui_ellipse(ctx, {max_force_handle.x - 7, max_force_handle.y - 7, 14, 14}, {0.32, 0.81, 0.40, 1})
	uifw.gui_ellipse(ctx, {max_distance_handle.x - 7, max_distance_handle.y - 7, 14, 14}, {0.23, 0.51, 0.96, 1})
	uifw.gui_ellipse(ctx, {beta_handle.x - 7, beta_handle.y - 7, 14, 14}, {0.98, 0.75, 0.14, 1})
	uifw.gui_text(ctx, {plot.x + 10, plot.y + 8}, "Close Range", ctx.style.text)
	uifw.gui_text(ctx, {beta_x + 10, plot.y + 8}, "Far Range", ctx.style.text)
	uifw.gui_text(ctx, {plot.x, bounds.y + bounds.h - 24}, "Distance (r)", ctx.style.text_muted)
	uifw.gui_text(ctx, {bounds.x + 8, plot.y + 4}, "Force", ctx.style.text_muted)

	uifw.gui_label(ctx, fmt.tprintf("F_max %.2f   r_max %.3f   beta %.2f   beta*r_max %.4f", sim.settings.max_force, sim.settings.max_distance, sim.settings.beta, sim.settings.beta * sim.settings.max_distance))
}

particle_life_draw_matrix_transform_row :: proc(sim: ^Particle_Life_Simulation, ctx: ^uifw.Gui_Context, labels: []string, keys: []string, transforms: []Particle_Life_Matrix_Transform) {
	row := uifw.gui_next_rect(ctx, height = ctx.style.row_height)
	gap := ctx.style.spacing
	w := (row.w - gap * f32(len(labels) - 1)) / f32(max(len(labels), 1))
	for i in 0 ..< len(labels) {
		rect := uifw.Rect{row.x + f32(i) * (w + gap), row.y, w, row.h}
		if particle_life_small_button(ctx, rect, labels[i], keys[i]) {
			particle_life_apply_matrix_transform(sim, transforms[i])
		}
	}
}

particle_life_draw_force_matrix_editor :: proc(sim: ^Particle_Life_Simulation, ctx: ^uifw.Gui_Context) {
	n := int(max(min(sim.settings.species_count, PARTICLE_LIFE_MAX_SPECIES), 1))
	available := max(ctx.content_width, 220)
	cell := min(max(ctx.style.row_height * 1.35, f32(58)), available / f32(n + 1))
	grid_w := cell * f32(n + 1)
	grid_bounds := uifw.gui_next_rect(ctx, height = cell * f32(n + 1))
	left := grid_bounds.x + max((available - grid_w) * 0.5, 0)
	header_y := grid_bounds.y
	text_scale := cell < 58 ? f32(0.56) : f32(0.66)
	for j in 0 ..< n {
		r := uifw.Rect{left + cell * f32(j + 1), header_y, cell, cell}
		uifw.gui_text_aligned_scaled(ctx, r, fmt.tprintf("S%d", j + 1), ctx.style.text, .Center, 0.72)
	}
	for i in 0 ..< n {
		row_y := grid_bounds.y + cell * f32(i + 1)
		uifw.gui_text_aligned_scaled(ctx, {left, row_y, cell, cell}, fmt.tprintf("S%d", i + 1), ctx.style.text, .Center, 0.72)
		for j in 0 ..< n {
			index := i * PARTICLE_LIFE_MAX_SPECIES + j
			value := sim.runtime.force_matrix[index]
			rect := uifw.Rect{left + cell * f32(j + 1), row_y, cell, cell}
			id := uifw.gui_make_id(ctx, fmt.tprintf("pl_matrix_%d_%d", i, j))
			control := uifw.gui_control(ctx, id, rect, true)
			if ctx.active == id && ctx.input.mouse_down {
				delta := ctx.input.wheel_delta * 0.1 + ctx.mouse_delta.x * 0.01
				if delta != 0 {
					value = max(min(value + delta, 1), -1)
					particle_life_set_force_value(sim, u32(i), u32(j), value)
				}
			}
			color := particle_life_force_matrix_color(value)
			if ctx.hot == id || ctx.active == id || control.focused {
				color.a = 1
			}
			uifw.gui_rect(ctx, rect, color)
			uifw.gui_stroke(ctx, rect, ctx.style.panel_border)
			uifw.gui_text_aligned_scaled(ctx, rect, particle_life_force_cell_label(value), ctx.style.text, .Center, text_scale)
		}
	}
	uifw.gui_text_block(ctx, "-1 repels   0 neutral   +1 attracts", ctx.content_width, ctx.style.text_muted)
	uifw.gui_text_block(ctx, "Transforms keep diagonal self-repulsion values.", ctx.content_width, ctx.style.text_muted)

	particle_life_draw_matrix_transform_row(sim, ctx, []string{"-20%", "+20%"}, []string{"pl_matrix_scale_down", "pl_matrix_scale_up"}, []Particle_Life_Matrix_Transform{.Scale_Down, .Scale_Up})
	particle_life_draw_matrix_transform_row(sim, ctx, []string{"Rot CCW", "Rot CW"}, []string{"pl_matrix_rot_ccw", "pl_matrix_rot_cw"}, []Particle_Life_Matrix_Transform{.Rotate_CCW, .Rotate_CW})
	particle_life_draw_matrix_transform_row(sim, ctx, []string{"Flip H", "Flip V"}, []string{"pl_matrix_flip_h", "pl_matrix_flip_v"}, []Particle_Life_Matrix_Transform{.Flip_H, .Flip_V})
	particle_life_draw_matrix_transform_row(sim, ctx, []string{"Shift L", "Shift R"}, []string{"pl_matrix_shift_l", "pl_matrix_shift_r"}, []Particle_Life_Matrix_Transform{.Shift_Left, .Shift_Right})
	particle_life_draw_matrix_transform_row(sim, ctx, []string{"Shift U", "Shift D"}, []string{"pl_matrix_shift_u", "pl_matrix_shift_d"}, []Particle_Life_Matrix_Transform{.Shift_Up, .Shift_Down})
	particle_life_draw_matrix_transform_row(sim, ctx, []string{"Zero", "Flip Sign"}, []string{"pl_matrix_zero", "pl_matrix_sign"}, []Particle_Life_Matrix_Transform{.Zero, .Flip_Sign})
}

particle_life_draw_controls :: proc(sim: ^Particle_Life_Simulation, ctx: ^uifw.Gui_Context, panel: uifw.Rect, scroll: ^f32, worker: ^Render_Worker_State, color_editor: ^Color_Scheme_Editor_State) {
	uifw.gui_panel_begin(ctx, panel)
	viewport := uifw.gui_next_rect(ctx, height = max(panel.h - ctx.style.panel_padding * 2, 0))
	uifw.gui_scroll_begin(ctx, viewport, particle_life_controls_content_height(sim, ctx), scroll)

	uifw.gui_heading(ctx, "About this simulation")
	uifw.gui_text_block(ctx, "Particle Life is a simulation where particles of different species interact with each other based on a force force_values.", panel.w - ctx.style.panel_padding * 2, ctx.style.text)
	uifw.gui_text_block(ctx, "Positive values attract, negative values repel, and values near zero stay neutral.", panel.w - ctx.style.panel_padding * 2, ctx.style.text_muted)
	uifw.gui_spacer(ctx, 8)

	uifw.gui_heading(ctx, "Presets")
	preset_fieldset_draw(
		ctx,
		&sim.runtime.preset_ui,
		worker,
		"particle_life",
		PARTICLE_LIFE_BUILTIN_PRESET_NAMES[:],
		sim.runtime.current_preset_index,
		Preset_Fieldset_Builtin_Context {kind = .Particle_Life, particle_life = sim},
	)
	uifw.gui_spacer(ctx, 8)

	uifw.gui_heading(ctx, "Display Settings")
	color_mode_index := int(u32(sim.settings.color_mode))
	if uifw.gui_selector(ctx, fmt.tprintf("Particle Color Mode: %s", PARTICLE_LIFE_COLOR_MODE_NAMES[color_mode_index]), "pl_color_mode", &color_mode_index, PARTICLE_LIFE_COLOR_MODE_NAMES[:]) {
		sim.settings.color_mode = Particle_Life_Color_Mode(u32(max(min(color_mode_index, len(PARTICLE_LIFE_COLOR_MODE_NAMES) - 1), 0)))
	}
	_ = color_scheme_editor_draw_selector(ctx, color_editor, "particle_life_color_scheme", &sim.settings.color_scheme, &sim.settings.color_scheme_reversed)
	if uifw.gui_selector(ctx, fmt.tprintf("Background Color Mode: %s", VECTOR_BACKGROUND_MODE_NAMES[sim.settings.background_index]), "pl_background", &sim.settings.background_index, VECTOR_BACKGROUND_MODE_NAMES[:]) {
		sim.settings.background_color_mode = Vector_Background_Mode(sim.settings.background_index)
	}
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Background R: %.2f", sim.settings.background_color[0]), "pl_bg_r", &sim.settings.background_color[0], 0, 1)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Background G: %.2f", sim.settings.background_color[1]), "pl_bg_g", &sim.settings.background_color[1], 0, 1)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Background B: %.2f", sim.settings.background_color[2]), "pl_bg_b", &sim.settings.background_color[2], 0, 1)
	if uifw.gui_toggle(ctx, fmt.tprintf("Enable Particle Traces: %v", sim.settings.trails_enabled), "pl_trails", &sim.settings.trails_enabled) {
		sim.gpu.trail_initialized = false
	}
	if sim.settings.trails_enabled {
		_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Trace Fade: %.2f", sim.settings.trail_fade_amount), "pl_trail_fade", &sim.settings.trail_fade_amount, 0.0, 1.0)
		if uifw.gui_button(ctx, "Clear Trails", "pl_clear_trails") {
			sim.gpu.trail_initialized = false
			sim.runtime.trail_camera_valid = false
		}
	}
	uifw.gui_spacer(ctx, 8)

	post_options := shared_default_post_processing_menu_options()
	_ = shared_post_processing_menu(ctx, &sim.settings.post_processing.blur_enabled, &sim.settings.post_processing.blur_radius, &sim.settings.post_processing.blur_sigma, post_options)
	uifw.gui_spacer(ctx, 8)

	uifw.gui_heading(ctx, "Display Adjustments")
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Brightness: %.2f", sim.settings.brightness), "pl_brightness", &sim.settings.brightness, 0, 2.5)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Contrast: %.2f", sim.settings.contrast), "pl_contrast", &sim.settings.contrast, 0, 2.5)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Saturation: %.2f", sim.settings.saturation), "pl_saturation", &sim.settings.saturation, 0, 2.5)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Gamma: %.2f", sim.settings.gamma), "pl_gamma", &sim.settings.gamma, 0.1, 4.0)
	uifw.gui_spacer(ctx, 8)

	cursor_options := shared_default_cursor_config_options()
	cursor_options.size_min = 0.05
	cursor_options.size_max = 1.0
	cursor_options.strength_min = 0.0
	cursor_options.strength_max = 20.0
	controls_options := Controls_Panel_Options {
		mouse_interaction_text = "Left click: Attract | Right click: Repel",
		cursor_settings_title = "",
		cursor = cursor_options,
	}
	_ = shared_controls_panel(ctx, controls_options, &sim.settings.cursor_size, &sim.settings.cursor_strength)
	uifw.gui_spacer(ctx, 8)

	uifw.gui_heading(ctx, "Settings")
	if uifw.gui_button(ctx, "Regenerate Particles", "pl_reset") {
		particle_life_reset_runtime(sim)
	}
	if uifw.gui_button(ctx, "Regenerate Matrix", "pl_randomize") {
		particle_life_randomize_forces(sim)
	}
	position_index := int(max(min(sim.settings.position_generator, u32(len(PARTICLE_LIFE_POSITION_GENERATOR_NAMES) - 1)), 0))
	if uifw.gui_selector(ctx, fmt.tprintf("Regenerate Positions: %s", PARTICLE_LIFE_POSITION_GENERATOR_NAMES[position_index]), "pl_position_generator", &position_index, PARTICLE_LIFE_POSITION_GENERATOR_NAMES[:]) {
		sim.settings.position_generator = u32(position_index)
		particle_life_reset_runtime(sim)
	}
	type_index := int(max(min(sim.settings.type_generator, u32(len(PARTICLE_LIFE_TYPE_GENERATOR_NAMES) - 1)), 0))
	if uifw.gui_selector(ctx, fmt.tprintf("Regenerate Types: %s", PARTICLE_LIFE_TYPE_GENERATOR_NAMES[type_index]), "pl_type_generator", &type_index, PARTICLE_LIFE_TYPE_GENERATOR_NAMES[:]) {
		sim.settings.type_generator = u32(type_index)
		particle_life_reset_runtime(sim)
	}
	particle_count := f32(sim.settings.particle_count)
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Particle Count: %d", sim.settings.particle_count), "pl_count", &particle_count, 1000, 1000, PARTICLE_LIFE_MAX_PARTICLE_COUNT) {
		particle_life_clear_preserved_particles(sim)
		sim.settings.particle_count = u32(particle_count)
		sim.runtime.needs_reset = true
		sim.gpu.ready = false
	}
	species_count := f32(sim.settings.species_count)
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Species Count: %d", sim.settings.species_count), "pl_species", &species_count, 1, 2, PARTICLE_LIFE_MAX_SPECIES) {
		particle_life_clear_preserved_particles(sim)
		sim.settings.species_count = u32(species_count)
		sim.runtime.needs_reset = true
		sim.gpu.ready = false
	}
	_ = uifw.gui_toggle(ctx, fmt.tprintf("Wrap Edges: %v", sim.settings.wrap_edges), "pl_wrap", &sim.settings.wrap_edges)
	_ = uifw.gui_toggle(ctx, fmt.tprintf("Paused: %v", sim.settings.paused), "pl_paused", &sim.settings.paused)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Particle Size: %.1f", sim.settings.particle_size), "pl_size", &sim.settings.particle_size, 2, 34)
	uifw.gui_text_block(ctx, "Click and drag to edit matrix values.", panel.w - ctx.style.panel_padding * 2, ctx.style.text_muted)
	force_index := int(max(min(sim.settings.force_generator, u32(len(PARTICLE_LIFE_FORCE_GENERATOR_NAMES) - 1)), 0))
	if uifw.gui_selector(ctx, fmt.tprintf("Force Generator: %s", PARTICLE_LIFE_FORCE_GENERATOR_NAMES[force_index]), "pl_force_generator", &force_index, PARTICLE_LIFE_FORCE_GENERATOR_NAMES[:]) {
		sim.settings.force_generator = u32(force_index)
	}
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Random Min: %.2f", sim.settings.force_random_min), "pl_force_min", &sim.settings.force_random_min, -1.5, 1.5)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Random Max: %.2f", sim.settings.force_random_max), "pl_force_max", &sim.settings.force_random_max, -1.5, 1.5)
	if sim.settings.force_random_min > sim.settings.force_random_max {
		sim.settings.force_random_min, sim.settings.force_random_max = sim.settings.force_random_max, sim.settings.force_random_min
	}
	particle_life_draw_force_matrix_editor(sim, ctx)

	uifw.gui_spacer(ctx, 8)
	uifw.gui_heading(ctx, "Physics")
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Max Force: %.2f", sim.settings.max_force), "pl_force", &sim.settings.max_force, 0.1, 10.0)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Range: %.2f", sim.settings.max_distance), "pl_range", &sim.settings.max_distance, 0.01, 1.0)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Friction: %.2f", sim.settings.friction), "pl_friction", &sim.settings.friction, 0.01, 1.0)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Beta: %.2f", sim.settings.beta), "pl_beta", &sim.settings.beta, 0.1, 0.9)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Brownian: %.3f", sim.settings.brownian_motion), "pl_brownian", &sim.settings.brownian_motion, 0.0, 1.0)
	particle_life_draw_force_curve_editor(sim, ctx)

	uifw.gui_spacer(ctx, 8)
	uifw.gui_heading(ctx, "Local Constraints")
	if uifw.gui_toggle(ctx, fmt.tprintf("Collisions: %v", sim.settings.collision_enabled), "pl_collision_enabled", &sim.settings.collision_enabled) {
		if !particle_life_current_grid_satisfies_settings(sim) {
			particle_life_request_resource_rebuild(sim)
		}
	}
	uifw.gui_text_block(ctx, fmt.tprintf("Distance follows particle size: %.4f", particle_life_collision_distance(sim.settings)), panel.w - ctx.style.panel_padding * 2, ctx.style.text_muted)
	collision_iterations := f32(sim.settings.collision_iterations)
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Iterations: %d", sim.settings.collision_iterations), "pl_collision_iterations", &collision_iterations, 1, 1, 8) {
		sim.settings.collision_iterations = u32(max(min(collision_iterations, 8), 1))
	}
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Relaxation: %.2f", sim.settings.collision_relaxation), "pl_collision_relaxation", &sim.settings.collision_relaxation, 0.0, 1.0)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Damping: %.2f", sim.settings.collision_damping), "pl_collision_damping", &sim.settings.collision_damping, 0.0, 1.0)

	uifw.gui_spacer(ctx, 8)
	uifw.gui_heading(ctx, "Blob Analysis")
	_ = uifw.gui_toggle(ctx, fmt.tprintf("Analysis: %v", sim.settings.analysis_enabled), "pl_analysis_enabled", &sim.settings.analysis_enabled)
	if uifw.gui_toggle(ctx, fmt.tprintf("Blob Overlay: %v", sim.settings.blob_overlay_enabled), "pl_blob_overlay", &sim.settings.blob_overlay_enabled) && sim.settings.blob_overlay_enabled {
		sim.settings.analysis_enabled = true
	}
	analysis_interval := f32(sim.settings.analysis_interval_frames)
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Analysis Cadence: %d", sim.settings.analysis_interval_frames), "pl_analysis_interval", &analysis_interval, 1, 1, 120) {
		sim.settings.analysis_interval_frames = u32(max(analysis_interval, 1))
	}
	analysis_grid := f32(sim.settings.analysis_grid_size)
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Analysis Grid: %d", sim.settings.analysis_grid_size), "pl_analysis_grid", &analysis_grid, 16, 64, 1024) {
		sim.settings.analysis_grid_size = u32(max(analysis_grid, 16))
		particle_life_request_resource_rebuild(sim)
	}
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Coherence: %.2f", sim.settings.coherence_threshold), "pl_coherence", &sim.settings.coherence_threshold, 0, 1)
	min_blob_area := f32(sim.settings.min_blob_area_cells)
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Min Blob Cells: %d", sim.settings.min_blob_area_cells), "pl_min_blob_area", &min_blob_area, 1, 1, 100000) {
		sim.settings.min_blob_area_cells = u32(max(min_blob_area, 1))
	}
	uifw.gui_text_block(ctx, fmt.tprintf("Tracked blobs: %d", sim.blob_tracker.count), panel.w - ctx.style.panel_padding * 2, ctx.style.text_muted)

	uifw.gui_spacer(ctx, 8)
	uifw.gui_heading(ctx, "Camera")
	if uifw.gui_button(ctx, "Reset View", "pl_reset_view") {
		particle_life_reset_camera(sim)
	}
	if uifw.gui_slider_f32(ctx, fmt.tprintf("Zoom: %.2f", sim.runtime.camera_zoom), "pl_camera_zoom", &sim.runtime.camera_zoom, 0.25, 24.0) {
		sim.runtime.camera_target_zoom = sim.runtime.camera_zoom
	}
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Pan X: %.2f", sim.runtime.camera_x), "pl_camera_x", &sim.runtime.camera_x, 0.05, -8.0, 8.0) {
		sim.runtime.camera_target_x = sim.runtime.camera_x
	}
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Pan Y: %.2f", sim.runtime.camera_y), "pl_camera_y", &sim.runtime.camera_y, 0.05, -8.0, 8.0) {
		sim.runtime.camera_target_y = sim.runtime.camera_y
	}
	uifw.gui_scroll_end(ctx)
	uifw.gui_panel_end(ctx)
	preset_save_dialog_draw(ctx, &sim.runtime.preset_ui, worker, "particle_life")
}
