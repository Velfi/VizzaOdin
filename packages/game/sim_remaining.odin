package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"
import "core:math"
import sdl "vendor:sdl3"

Remaining_Sim_Kind :: enum {
	Slime_Mold,
	Flow_Field,
	Pellets,
	Voronoi_CA,
	Moire,
	Vectors,
	Primordial,
}

Remaining_Sim_State :: struct {
	using runtime: ^Remaining_Sim_Runtime_State,
	moire: ^Moire_Settings,
	vectors: ^Vectors_Settings,
	primordial: ^Primordial_Settings,
	voronoi: ^Voronoi_Settings,
	pellets: ^Pellets_Settings,
	flow: ^Flow_Settings,
	slime: ^Slime_Settings,
}

remaining_sim_bind_product_instance :: proc(sim: ^Remaining_Sim_State, instance: ^Feature_Instance, kind: Remaining_Sim_Kind) -> bool {
	if sim == nil || instance == nil do return false
	runtime, ok := feature_instance_runtime(instance, Remaining_Sim_Runtime_State)
	if !ok do return false
	sim^ = {runtime = runtime}
	runtime.kind = kind
	#partial switch kind {
	case .Slime_Mold: sim.slime, ok = feature_instance_settings(instance, Slime_Settings)
	case .Flow_Field: sim.flow, ok = feature_instance_settings(instance, Flow_Settings)
	case .Pellets: sim.pellets, ok = feature_instance_settings(instance, Pellets_Settings)
	case .Voronoi_CA: sim.voronoi, ok = feature_instance_settings(instance, Voronoi_Settings)
	case .Moire: sim.moire, ok = feature_instance_settings(instance, Moire_Settings)
	case .Vectors: sim.vectors, ok = feature_instance_settings(instance, Vectors_Settings)
	case .Primordial: sim.primordial, ok = feature_instance_settings(instance, Primordial_Settings)
	}
	return ok
}

// Transient product state shared by the remaining simulation implementations.
// This structure is never serialized; only the typed settings fields above are
// eligible for preset persistence.
Remaining_Sim_Runtime_State :: struct {
	kind: Remaining_Sim_Kind,
	paused: bool,
	time: f32,
	intensity: f32,
	scale: f32,
	speed: f32,
	density: f32,
	scroll: f32,
	cursor_world: [2]f32,
	cursor_world_prev: [2]f32,
	cursor_world_velocity: [2]f32,
	cursor_pixel: [2]f32,
	cursor_active: u32,
	cursor_mode: u32,
	canvas_tool: Canvas_Tool_State,
	voronoi_interaction_mode: u32,
	voronoi_pressed: bool,
	voronoi_released: bool,
	voronoi_grabbed: bool,
	voronoi_grabbed_index: u32,
	camera: Camera_Control_State,
	cursor_size: f32,
	cursor_strength: f32,
	preset_ui: Preset_Fieldset_State,
	builtin_preset_index: int,
	vectors_image_dialog_requested: bool,
	moire_image_dialog_requested: bool,
	flow_image_dialog_requested: bool,
	slime_mask_image_dialog_requested: bool,
	slime_position_image_dialog_requested: bool,
	webcam_capture: ^sdl.Camera,
	webcam_capture_target: Feature_Image_Target,
	webcam_capture_status: [128]u8,
	webcam_capture_frames: u64,
	slime_reset_requested: bool,
	slime_clear_trails_requested: bool,
	flow_clear_trails_requested: bool,
	slime_randomize_undo: Slime_Randomize_Undo,
	slime_randomize_undo_available: bool,
	primordial_randomize_undo: Primordial_Randomize_Undo,
	primordial_randomize_undo_available: bool,
	voronoi_randomize_undo: Voronoi_Randomize_Undo,
	voronoi_randomize_undo_available: bool,
	reset_undo: Remaining_Sim_Reset_Undo,
}

Remaining_Sim_Reset_Undo :: struct {
	available: bool,
	paused: bool,
	time: f32,
	intensity: f32,
	scale: f32,
	speed: f32,
	density: f32,
	camera: Camera_Control_State,
	cursor_size: f32,
	cursor_strength: f32,
	builtin_preset_index: int,
	moire: Moire_Settings,
	vectors: Vectors_Settings,
	primordial: Primordial_Settings,
	voronoi: Voronoi_Settings,
	pellets: Pellets_Settings,
	flow: Flow_Settings,
	slime: Slime_Settings,
	slime_randomize_undo: Slime_Randomize_Undo,
	slime_randomize_undo_available: bool,
}

Moire_Generator_Type :: enum int {
	Linear,
	Radial,
}

Moire_Image_Interference_Mode :: enum int {
	Replace,
	Add,
	Multiply,
	Overlay,
	Mask,
	Modulate,
}

Moire_Settings :: struct {
	color_scheme: Color_Scheme_Name,
	color_scheme_reversed: bool,
	speed: f32,
	generator_type: Moire_Generator_Type,
	base_freq: f32,
	moire_amount: f32,
	moire_rotation: f32,
	moire_scale: f32,
	moire_interference: f32,
	moire_rotation3: f32,
	moire_scale3: f32,
	moire_weight3: f32,
	radial_swirl_strength: f32,
	radial_starburst_count: f32,
	radial_center_brightness: f32,
	advect_strength: f32,
	advect_speed: f32,
	curl: f32,
	decay: f32,
	image_mode_enabled: bool,
	image_fit_mode: Vector_Image_Fit_Mode,
	image_mirror_horizontal: bool,
	image_mirror_vertical: bool,
	image_invert_tone: bool,
	image_interference_mode: Moire_Image_Interference_Mode,
	image_path: [MAX_FILE_PATH]u8,
	generator_index: int,
	interference_index: int,
	image_fit_index: int,
}

MOIRE_GENERATOR_TYPE_NAMES := [?]string{"Linear", "Radial"}
MOIRE_INTERFERENCE_MODE_NAMES := [?]string{"Replace", "Add", "Multiply", "Overlay", "Mask", "Modulate"}
VECTOR_FIELD_TYPE_NAMES := [?]string{"Noise", "Image"}
VECTOR_BACKGROUND_MODE_NAMES := [?]string{"Black", "White", "Gray18", "Color Scheme"}
VECTOR_IMAGE_FIT_MODE_NAMES := [?]string{"Stretch", "Center", "Fit H", "Fit V"}
VECTOR_DISPLAY_MODE_NAMES := [?]string{"Lines", "Needles", "Arrows", "Chevrons", "Rings"}
PELLETS_FOREGROUND_MODE_NAMES := [?]string{"Density", "Velocity", "Random"}
PRIMORDIAL_FOREGROUND_MODE_NAMES := [?]string{"Random", "Density", "Heading", "Velocity"}
VORONOI_COLOR_MODE_NAMES := [?]string{"Random", "Distance", "Rings"}
PRIMORDIAL_POSITION_GENERATOR_NAMES := [?]string{"Random", "Center", "UniformCircle", "CenteredCircle", "Ring", "Line", "Spiral"}
SLIME_POSITION_GENERATOR_NAMES := [?]string{"Random", "Center", "Uniform Circle", "Centered Circle", "Ring", "Line", "Spiral", "Image"}
SLIME_MASK_PATTERN_NAMES := [?]string{"Disabled", "Checkerboard", "Diagonal Gradient", "Radial Gradient", "Vertical Stripes", "Horizontal Stripes", "Wave Function", "Cosine Grid", "Image"}
SLIME_MASK_TARGET_NAMES := [?]string{"Pheromone Deposition", "Pheromone Decay", "Pheromone Diffusion", "Agent Speed", "Agent Turn Rate", "Agent Sensor Distance", "Trail Map"}
FLOW_PARTICLE_SHAPE_NAMES := [?]string{"Circle", "Square", "Triangle", "Flower", "Diamond"}
FLOW_FOREGROUND_MODE_NAMES := [?]string{"Age", "Random", "Direction"}
FLOW_TRAIL_MAP_FILTERING_NAMES := [?]string{"Nearest", "Linear"}
FLOW_EMITTER_MODE_NAMES := [?]string{"Area", "Center", "Ring", "Edges", "Line"}
FLOW_BOUNDARY_MODE_NAMES := [?]string{"Wrap", "Bounce", "Absorb", "Respawn"}
FLOW_TRAIL_STYLE_NAMES := [?]string{"Ink", "Dotted", "Tapered", "Neon"}
REMAINING_DEFAULT_BUILTIN_PRESET_NAMES := [?]string{"Default"}
MOIRE_BUILTIN_PRESET_NAMES := [?]string{"Default", "Classic Moire", "Psychedelic", "Subtle"}
SLIME_BUILTIN_PRESET_NAMES := [?]string{"Default", "Gloop Loops", "Firecracker Trees", "Threads", "Snake", "Cells", "Net", "Bars", "Healthy Fungus", "Sand On A Speaker", "Spots", "Cascades", "Venom"}

Vector_Field_Type :: enum int {
	Noise,
	Image,
}

Vector_Background_Mode :: enum int {
	Black,
	White,
	Gray18,
	Color_Scheme,
}

Vector_Image_Fit_Mode :: enum int {
	Stretch,
	Center,
	Fit_H,
	Fit_V,
}

Vector_Display_Mode :: enum int {
	Lines,
	Needles,
	Arrows,
	Chevrons,
	Rings,
}

Flow_Emitter_Mode :: enum int {Area, Center, Ring, Edges, Line}
Flow_Boundary_Mode :: enum int {Wrap, Bounce, Absorb, Respawn}
Flow_Trail_Style :: enum int {Ink, Dotted, Tapered, Neon}

flow_emitter_mode_from_name :: proc(name: string, out: ^Flow_Emitter_Mode) -> bool {
	for value, i in FLOW_EMITTER_MODE_NAMES {if name == value {out^ = Flow_Emitter_Mode(i); return true}}
	return false
}
flow_boundary_mode_from_name :: proc(name: string, out: ^Flow_Boundary_Mode) -> bool {
	for value, i in FLOW_BOUNDARY_MODE_NAMES {if name == value {out^ = Flow_Boundary_Mode(i); return true}}
	return false
}
flow_trail_style_from_name :: proc(name: string, out: ^Flow_Trail_Style) -> bool {
	for value, i in FLOW_TRAIL_STYLE_NAMES {if name == value {out^ = Flow_Trail_Style(i); return true}}
	return false
}

vector_display_mode_from_name :: proc(name: string, out: ^Vector_Display_Mode) -> bool {
	for value, i in VECTOR_DISPLAY_MODE_NAMES {
		if name == value {
			out^ = Vector_Display_Mode(i)
			return true
		}
	}
	return false
}

vector_image_fit_mode_from_name :: proc(name: string, out: ^Vector_Image_Fit_Mode) -> bool {
	switch name {
	case "Stretch", "stretch":
		out^ = .Stretch
	case "Center", "center":
		out^ = .Center
	case "Fit H", "FitH", "Fit_H", "fit h", "fith", "fit_h":
		out^ = .Fit_H
	case "Fit V", "FitV", "Fit_V", "fit v", "fitv", "fit_v":
		out^ = .Fit_V
	case:
		return false
	}
	return true
}

vector_field_type_from_name :: proc(name: string, out: ^Vector_Field_Type) -> bool {
	switch name {
	case "Noise", "noise":
		out^ = .Noise
	case "Image", "image":
		out^ = .Image
	case:
		return false
	}
	return true
}

Vectors_Settings :: struct {
	color_scheme: Color_Scheme_Name,
	color_scheme_reversed: bool,
	vector_field_type: Vector_Field_Type,
	noise: Noise_Settings,
	density: f32,
	line_length: f32,
	line_width: f32,
	display_mode: Vector_Display_Mode,
	background_color_mode: Vector_Background_Mode,
	image_fit_mode: Vector_Image_Fit_Mode,
	image_mirror_horizontal: bool,
	image_mirror_vertical: bool,
	image_invert_tone: bool,
	image_path: [MAX_FILE_PATH]u8,
	vector_field_index: int,
	background_index: int,
	image_fit_index: int,
	display_index: int,
	// Canvas edits are runtime instruments and are intentionally omitted by settings serialization.
	deflection_stamps: [32]Vector_Deflection_Stamp,
	deflection_stamp_count: int,
	probe_position: [2]f32,
	probe_value: f32,
	probe_pinned: bool,
	probe_has_sample: bool,
	probe_initialized: bool,
}

Vector_Deflection_Stamp :: struct {
	position: [2]f32,
	radius: f32,
	angle: f32,
}

Primordial_Settings :: struct {
	color_scheme: Color_Scheme_Name,
	color_scheme_reversed: bool,
	post_processing: Post_Processing_Settings,
	particle_count: u32,
	random_seed: u32,
	position_generator: u32,
	alpha: f32,
	beta: f32,
	velocity: f32,
	radius: f32,
	dt: f32,
	particle_size: f32,
	collision_enabled: bool,
	collision_relaxation: f32,
	collision_damping: f32,
	density_radius: f32,
	background_color_mode: Vector_Background_Mode,
	foreground_color_mode: Primordial_Foreground_Mode,
	traces_enabled: bool,
	trace_fade: f32,
	wrap_edges: bool,
	background_index: int,
	foreground_index: int,
	position_generator_index: int,
}

// Transient experimentation history. This deliberately does not belong to
// Primordial_Settings, so it never leaks into presets.
Primordial_Randomize_Undo :: struct {
	alpha, beta, velocity, radius: f32,
	random_seed: u32,
}

Primordial_Foreground_Mode :: enum int {
	Random,
	Density,
	Heading,
	Velocity,
}

Voronoi_Settings :: struct {
	color_scheme: Color_Scheme_Name,
	color_scheme_reversed: bool,
	post_processing: Post_Processing_Settings,
	point_count: u32,
	time_scale: f32,
	drift: f32,
	brownian_speed: f32,
	random_seed: u32,
	borders_enabled: bool,
	border_width: f32,
	color_mode: u32,
	color_mode_index: int,
}

Voronoi_Randomize_Undo :: struct {
	point_count: u32,
	time_scale, drift, brownian_speed: f32,
	random_seed: u32,
}

Pellets_Foreground_Mode :: enum int {
	Density,
	Velocity,
	Random,
}

Pellets_Settings :: struct {
	color_scheme: Color_Scheme_Name,
	color_scheme_reversed: bool,
	post_processing: Post_Processing_Settings,
	particle_count: u32,
	particle_size: f32,
	collision_damping: f32,
	initial_velocity_max: f32,
	initial_velocity_min: f32,
	random_seed: u32,
	background_color_mode: Vector_Background_Mode,
	gravitational_constant: f32,
	energy_damping: f32,
	gravity_softening: f32,
	density_radius: f32,
	foreground_color_mode: Pellets_Foreground_Mode,
	trails_enabled: bool,
	trail_fade: f32,
	density_damping_enabled: bool,
	overlap_resolution_strength: f32,
	background_index: int,
	foreground_index: int,
}

Flow_Particle_Shape :: enum int {
	Circle,
	Square,
	Triangle,
	Star,
	Diamond,
}

Flow_Foreground_Mode :: enum int {
	Age,
	Random,
	Direction,
}

Flow_Trail_Map_Filtering :: enum int {
	Nearest,
	Linear,
}

flow_particle_shape_from_name :: proc(name: string, out: ^Flow_Particle_Shape) -> bool {
	for i in 0 ..< len(FLOW_PARTICLE_SHAPE_NAMES) {
		if name == FLOW_PARTICLE_SHAPE_NAMES[i] {
			out^ = Flow_Particle_Shape(i)
			return true
		}
	}
	return false
}

flow_foreground_mode_from_name :: proc(name: string, out: ^Flow_Foreground_Mode) -> bool {
	for i in 0 ..< len(FLOW_FOREGROUND_MODE_NAMES) {
		if name == FLOW_FOREGROUND_MODE_NAMES[i] {
			out^ = Flow_Foreground_Mode(i)
			return true
		}
	}
	return false
}

flow_trail_map_filtering_from_name :: proc(name: string, out: ^Flow_Trail_Map_Filtering) -> bool {
	for i in 0 ..< len(FLOW_TRAIL_MAP_FILTERING_NAMES) {
		if name == FLOW_TRAIL_MAP_FILTERING_NAMES[i] {
			out^ = Flow_Trail_Map_Filtering(i)
			return true
		}
	}
	return false
}

vector_background_mode_from_name :: proc(name: string, out: ^Vector_Background_Mode) -> bool {
	for i in 0 ..< len(VECTOR_BACKGROUND_MODE_NAMES) {
		if name == VECTOR_BACKGROUND_MODE_NAMES[i] {
			out^ = Vector_Background_Mode(i)
			return true
		}
	}
	return false
}

primordial_foreground_mode_from_name :: proc(name: string, out: ^Primordial_Foreground_Mode) -> bool {
	for i in 0 ..< len(PRIMORDIAL_FOREGROUND_MODE_NAMES) {
		if name == PRIMORDIAL_FOREGROUND_MODE_NAMES[i] {
			out^ = Primordial_Foreground_Mode(i)
			return true
		}
	}
	return false
}

voronoi_color_mode_from_name :: proc(name: string, out: ^u32) -> bool {
	for i in 0 ..< len(VORONOI_COLOR_MODE_NAMES) {
		if name == VORONOI_COLOR_MODE_NAMES[i] {
			out^ = u32(i)
			return true
		}
	}
	switch name {
	case "Density":
		out^ = 1
		return true
	case "Age":
		out^ = 2
		return true
	case "Binary":
		out^ = 0
		return true
	}
	return false
}

pellets_foreground_mode_from_name :: proc(name: string, out: ^Pellets_Foreground_Mode) -> bool {
	for i in 0 ..< len(PELLETS_FOREGROUND_MODE_NAMES) {
		if name == PELLETS_FOREGROUND_MODE_NAMES[i] {
			out^ = Pellets_Foreground_Mode(i)
			return true
		}
	}
	return false
}

slime_background_mode_from_name :: proc(name: string, out: ^Slime_Background_Mode) -> bool {
	for i in 0 ..< len(SLIME_BACKGROUND_MODE_NAMES) {
		if name == SLIME_BACKGROUND_MODE_NAMES[i] {
			out^ = Slime_Background_Mode(i)
			return true
		}
	}
	return false
}

slime_mask_pattern_from_name :: proc(name: string, out: ^Slime_Mask_Pattern) -> bool {
	for i in 0 ..< len(SLIME_MASK_PATTERN_NAMES) {
		if name == SLIME_MASK_PATTERN_NAMES[i] {
			out^ = Slime_Mask_Pattern(i)
			return true
		}
	}
	return false
}

slime_mask_target_from_name :: proc(name: string, out: ^Slime_Mask_Target) -> bool {
	for i in 0 ..< len(SLIME_MASK_TARGET_NAMES) {
		if name == SLIME_MASK_TARGET_NAMES[i] {
			out^ = Slime_Mask_Target(i)
			return true
		}
	}
	return false
}

slime_position_generator_from_name :: proc(name: string, out: ^u32) -> bool {
	for i in 0 ..< len(SLIME_POSITION_GENERATOR_NAMES) {
		if name == SLIME_POSITION_GENERATOR_NAMES[i] {
			out^ = u32(i)
			return true
		}
	}
	return false
}

primordial_position_generator_from_name :: proc(name: string, out: ^u32) -> bool {
	for i in 0 ..< len(PRIMORDIAL_POSITION_GENERATOR_NAMES) {
		if name == PRIMORDIAL_POSITION_GENERATOR_NAMES[i] {
			out^ = u32(i)
			return true
		}
	}
	return false
}

Flow_Settings :: struct {
	color_scheme: Color_Scheme_Name,
	color_scheme_reversed: bool,
	post_processing: Post_Processing_Settings,
	vector_field_type: Vector_Field_Type,
	noise: Noise_Settings,
	vector_magnitude: f32,
	image_fit_mode: Vector_Image_Fit_Mode,
	image_mirror_horizontal: bool,
	image_mirror_vertical: bool,
	image_invert_tone: bool,
	image_path: [MAX_FILE_PATH]u8,
	total_pool_size: u32,
	particle_lifetime: f32,
	particle_speed: f32,
	particle_size: u32,
	particle_shape: Flow_Particle_Shape,
	particle_autospawn: bool,
	show_particles: bool,
	autospawn_rate: u32,
	brush_spawn_rate: u32,
	emitter_mode: Flow_Emitter_Mode,
	emitter_radius: f32,
	boundary_mode: Flow_Boundary_Mode,
	trail_style: Flow_Trail_Style,
	field_animation_enabled: bool,
	field_animation_speed: f32,
	foreground_color_mode: Flow_Foreground_Mode,
	background_color_mode: Vector_Background_Mode,
	trail_decay_rate: f32,
	trail_deposition_rate: f32,
	trail_diffusion_rate: f32,
	trail_wash_out_rate: f32,
	trail_map_filtering: Flow_Trail_Map_Filtering,
	vector_field_index: int,
	image_fit_index: int,
	shape_index: int,
	foreground_index: int,
	background_index: int,
	trail_filtering_index: int,
	emitter_index: int,
	boundary_index: int,
	trail_style_index: int,
}

Slime_Background_Mode :: enum int {
	Black,
	White,
}

Slime_Mask_Pattern :: enum int {
	Disabled,
	Checkerboard,
	Diagonal_Gradient,
	Radial_Gradient,
	Vertical_Stripes,
	Horizontal_Stripes,
	Wave_Function,
	Cosine_Grid,
	Image,
}

Slime_Mask_Target :: enum int {
	Pheromone_Deposition,
	Pheromone_Decay,
	Pheromone_Diffusion,
	Agent_Speed,
	Agent_Turn_Rate,
	Agent_Sensor_Distance,
	Trail_Map,
}

SLIME_BACKGROUND_MODE_NAMES := [?]string{"Black", "White"}

Slime_Settings :: struct {
	color_scheme: Color_Scheme_Name,
	color_scheme_reversed: bool,
	post_processing: Post_Processing_Settings,
	agent_count: u32,
	agent_jitter: f32,
	isotropic_jitter: bool,
	agent_heading_start: f32,
	agent_heading_end: f32,
	agent_sensor_angle: f32,
	agent_sensor_distance: f32,
	agent_speed_max: f32,
	agent_speed_min: f32,
	agent_turn_rate: f32,
	pheromone_decay_rate: f32,
	pheromone_deposition_rate: f32,
	pheromone_diffusion_rate: f32,
	diffusion_frequency: u32,
	decay_frequency: u32,
	random_seed: u32,
	position_generator: u32,
	mask_pattern: Slime_Mask_Pattern,
	mask_target: Slime_Mask_Target,
	mask_strength: f32,
	mask_curve: f32,
	mask_image_fit_mode: Vector_Image_Fit_Mode,
	mask_image_path: [MAX_FILE_PATH]u8,
	position_image_fit_mode: Vector_Image_Fit_Mode,
	position_image_path: [MAX_FILE_PATH]u8,
	mask_mirror_horizontal: bool,
	mask_mirror_vertical: bool,
	mask_invert_tone: bool,
	mask_reversed: bool,
	trail_map_filtering: Flow_Trail_Map_Filtering,
	background_mode: Slime_Background_Mode,
	position_generator_index: int,
	mask_pattern_index: int,
	mask_target_index: int,
	mask_image_fit_index: int,
	position_image_fit_index: int,
	background_index: int,
	trail_filtering_index: int,
}

Slime_Randomize_Undo :: struct {
	agent_jitter: f32,
	agent_sensor_angle: f32,
	agent_sensor_distance: f32,
	agent_speed_min: f32,
	agent_speed_max: f32,
	agent_turn_rate: f32,
	pheromone_decay_rate: f32,
	pheromone_deposition_rate: f32,
	pheromone_diffusion_rate: f32,
	random_seed: u32,
}
