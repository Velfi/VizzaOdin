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
	webcam_capture_command: Ui_To_Render_Command_Kind,
	webcam_capture_status: [128]u8,
	webcam_capture_frames: u64,
	slime_reset_requested: bool,
	slime_clear_trails_requested: bool,
	slime_randomize_undo: Slime_Randomize_Undo,
	slime_randomize_undo_available: bool,
	moire: Moire_Settings,
	vectors: Vectors_Settings,
	primordial: Primordial_Settings,
	voronoi: Voronoi_Settings,
	pellets: Pellets_Settings,
	flow: Flow_Settings,
	slime: Slime_Settings,
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
	background_color_mode: Vector_Background_Mode,
	image_fit_mode: Vector_Image_Fit_Mode,
	image_mirror_horizontal: bool,
	image_mirror_vertical: bool,
	image_invert_tone: bool,
	image_path: [MAX_FILE_PATH]u8,
	vector_field_index: int,
	background_index: int,
	image_fit_index: int,
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
	agent_jitter: f32,
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

moire_settings_default :: proc() -> Moire_Settings {
	settings: Moire_Settings
	color_scheme_name_set(&settings.color_scheme, "ZELDA_Fordite")
	settings = {
		speed = 0.1,
		generator_type = .Linear,
		base_freq = 20.0,
		moire_amount = 0.5,
		moire_rotation = 0.2,
		moire_scale = 1.05,
		moire_interference = 0.5,
		moire_rotation3 = -0.1,
		moire_scale3 = 1.1,
		moire_weight3 = 0.3,
		radial_swirl_strength = 0.5,
		radial_starburst_count = 16.0,
		radial_center_brightness = 1.0,
		advect_strength = 0.6,
		advect_speed = 1.5,
		curl = 0.8,
		decay = 0.98,
		image_mode_enabled = false,
		image_fit_mode = .Fit_V,
		image_mirror_horizontal = false,
		image_mirror_vertical = false,
		image_invert_tone = true,
		image_interference_mode = .Modulate,
		generator_index = int(Moire_Generator_Type.Linear),
		interference_index = int(Moire_Image_Interference_Mode.Modulate),
		image_fit_index = int(Vector_Image_Fit_Mode.Fit_V),
	}
	color_scheme_name_set(&settings.color_scheme, "ZELDA_Fordite")
	return settings
}

vectors_settings_default :: proc() -> Vectors_Settings {
	settings: Vectors_Settings
		settings = {
			vector_field_type = .Noise,
			noise = noise_settings_default(.Simplex),
			density = 0.02,
		line_length = 0.03,
		line_width = 0.001,
		background_color_mode = .Black,
		image_fit_mode = .Stretch,
		image_mirror_horizontal = false,
		image_mirror_vertical = false,
		image_invert_tone = false,
		vector_field_index = int(Vector_Field_Type.Noise),
		background_index = int(Vector_Background_Mode.Black),
		image_fit_index = int(Vector_Image_Fit_Mode.Stretch),
	}
	settings.noise.frequency = 5.0
	color_scheme_name_set(&settings.color_scheme, "MATPLOTLIB_viridis")
	return settings
}

primordial_settings_default :: proc() -> Primordial_Settings {
	settings: Primordial_Settings
	settings = {
		post_processing = post_processing_default_settings(),
		particle_count = 10000,
		random_seed = 42,
		position_generator = 0,
		alpha = 180.0,
		beta = 0.1,
		velocity = 0.2,
		radius = 0.1,
		dt = 0.016,
		particle_size = 0.01,
		density_radius = 0.04,
		background_color_mode = .Color_Scheme,
		foreground_color_mode = .Heading,
		traces_enabled = false,
		trace_fade = 0.48,
		wrap_edges = true,
		background_index = int(Vector_Background_Mode.Color_Scheme),
		foreground_index = int(Primordial_Foreground_Mode.Heading),
		position_generator_index = 0,
	}
	color_scheme_name_set(&settings.color_scheme, "MATPLOTLIB_turbo")
	return settings
}

voronoi_settings_default :: proc() -> Voronoi_Settings {
	settings: Voronoi_Settings
	color_scheme_name_set(&settings.color_scheme, "MATPLOTLIB_cubehelix")
	settings.color_scheme_reversed = true
	settings.post_processing = post_processing_default_settings()
	settings.point_count = 300
	settings.time_scale = 1.0
	settings.drift = 1.0
	settings.brownian_speed = 10.0
	settings.random_seed = 0
	settings.borders_enabled = false
	settings.border_width = 1.0
	settings.color_mode = 0
	settings.color_mode_index = 0
	return settings
}

pellets_settings_default :: proc() -> Pellets_Settings {
	settings: Pellets_Settings
	settings = {
		post_processing = post_processing_default_settings(),
		particle_count = 20000,
		particle_size = 0.0075,
		collision_damping = 1.0,
		initial_velocity_max = 0.1,
		initial_velocity_min = 0.1,
		random_seed = 0,
		background_color_mode = .Color_Scheme,
		gravitational_constant = 0.0000001,
		energy_damping = 1.0,
		gravity_softening = 0.003,
		density_radius = 0.019,
		foreground_color_mode = .Density,
		trails_enabled = false,
		trail_fade = 0.5,
		density_damping_enabled = false,
		overlap_resolution_strength = 0.02,
		background_index = int(Vector_Background_Mode.Color_Scheme),
		foreground_index = int(Pellets_Foreground_Mode.Density),
	}
	color_scheme_name_set(&settings.color_scheme, "MATPLOTLIB_bone")
	settings.color_scheme_reversed = true
	return settings
}

flow_settings_default :: proc() -> Flow_Settings {
	settings: Flow_Settings
		settings = {
			post_processing = post_processing_default_settings(),
			vector_field_type = .Noise,
			noise = noise_settings_default(.Simplex),
			vector_magnitude = 0.1,
		image_fit_mode = .Stretch,
		image_mirror_horizontal = false,
		image_mirror_vertical = false,
		image_invert_tone = false,
		total_pool_size = 100000,
		particle_lifetime = 5.0,
		particle_speed = 1.0,
		particle_size = 4,
		particle_shape = .Circle,
		particle_autospawn = true,
		show_particles = true,
		autospawn_rate = 500,
		brush_spawn_rate = 1000,
		foreground_color_mode = .Age,
		background_color_mode = .Color_Scheme,
		trail_decay_rate = 0.0,
		trail_deposition_rate = 1.0,
		trail_diffusion_rate = 0.0,
		trail_wash_out_rate = 0.1,
		trail_map_filtering = .Nearest,
		vector_field_index = int(Vector_Field_Type.Noise),
		image_fit_index = int(Vector_Image_Fit_Mode.Stretch),
		shape_index = int(Flow_Particle_Shape.Circle),
		foreground_index = int(Flow_Foreground_Mode.Age),
		background_index = int(Vector_Background_Mode.Color_Scheme),
		trail_filtering_index = int(Flow_Trail_Map_Filtering.Nearest),
	}
	settings.noise.offset_x = 1.0
	settings.noise.offset_y = 1.0
	color_scheme_name_set(&settings.color_scheme, "MATPLOTLIB_cubehelix")
	settings.color_scheme_reversed = true
	return settings
}

slime_settings_default :: proc() -> Slime_Settings {
	settings: Slime_Settings
	settings = {
		post_processing = post_processing_default_settings(),
		agent_jitter = 0.04,
		agent_heading_start = 0.0,
		agent_heading_end = 360.0,
		agent_sensor_angle = 0.3,
		agent_sensor_distance = 20.0,
		agent_speed_max = 60.0,
		agent_speed_min = 30.0,
		agent_turn_rate = 0.43,
		pheromone_decay_rate = 10.0,
		pheromone_deposition_rate = 100.0,
		pheromone_diffusion_rate = 100.0,
		diffusion_frequency = 1,
		decay_frequency = 1,
		random_seed = 0,
		position_generator = 0,
		mask_pattern = .Disabled,
		mask_target = .Pheromone_Deposition,
		mask_strength = 0.5,
		mask_curve = 1.0,
		mask_image_fit_mode = .Stretch,
		position_image_fit_mode = .Fit_V,
		mask_mirror_horizontal = false,
		mask_mirror_vertical = false,
		mask_invert_tone = false,
		mask_reversed = false,
		trail_map_filtering = .Nearest,
		background_mode = .Black,
		position_generator_index = 0,
		mask_pattern_index = int(Slime_Mask_Pattern.Disabled),
		mask_target_index = int(Slime_Mask_Target.Pheromone_Deposition),
		mask_image_fit_index = int(Vector_Image_Fit_Mode.Stretch),
		position_image_fit_index = int(Vector_Image_Fit_Mode.Fit_V),
		background_index = int(Slime_Background_Mode.Black),
		trail_filtering_index = int(Flow_Trail_Map_Filtering.Nearest),
	}
	color_scheme_name_set(&settings.color_scheme, "MATPLOTLIB_prism")
	settings.color_scheme_reversed = true
	return settings
}

remaining_sim_builtin_preset_names :: proc(kind: Remaining_Sim_Kind) -> []string {
	#partial switch kind {
	case .Moire:
		return MOIRE_BUILTIN_PRESET_NAMES[:]
	case .Slime_Mold:
		return SLIME_BUILTIN_PRESET_NAMES[:]
	case:
		return REMAINING_DEFAULT_BUILTIN_PRESET_NAMES[:]
	}
}

remaining_sim_apply_builtin_preset :: proc(sim: ^Remaining_Sim_State, kind: Remaining_Sim_Kind, index: int) {
	names := remaining_sim_builtin_preset_names(kind)
	if len(names) == 0 {
		return
	}
	preset_index := max(min(index, len(names) - 1), 0)
	sim.builtin_preset_index = preset_index

	#partial switch kind {
	case .Moire:
		settings := moire_settings_default()
		switch preset_index {
		case 1: // Classic Moire
			settings.base_freq = 30.0
			settings.moire_amount = 0.8
			settings.moire_rotation = 0.1
			settings.moire_scale = 1.02
			settings.moire_interference = 0.7
			settings.advect_strength = 0.1
		case 2: // Psychedelic
			settings.base_freq = 20.0
			settings.moire_amount = 0.5
			settings.moire_rotation = 0.3
			settings.moire_scale = 1.1
			settings.moire_interference = 0.5
			settings.advect_strength = 0.4
		case 3: // Subtle
			settings.base_freq = 40.0
			settings.moire_amount = 0.3
			settings.moire_rotation = 0.05
			settings.moire_scale = 1.01
			settings.moire_interference = 0.3
			settings.advect_strength = 0.2
		case:
		}
		moire_settings_preserve_color_scheme(&settings, sim.moire)
		sim.moire = settings
	case .Vectors:
		settings := vectors_settings_default()
		vectors_settings_preserve_color_scheme(&settings, sim.vectors)
		sim.vectors = settings
	case .Primordial:
		settings := primordial_settings_default()
		primordial_settings_preserve_color_scheme(&settings, sim.primordial)
		sim.primordial = settings
	case .Voronoi_CA:
		settings := voronoi_settings_default()
		voronoi_settings_preserve_color_scheme(&settings, sim.voronoi)
		sim.voronoi = settings
	case .Pellets:
		settings := pellets_settings_default()
		pellets_settings_preserve_color_scheme(&settings, sim.pellets)
		sim.pellets = settings
	case .Flow_Field:
		settings := flow_settings_default()
		flow_settings_preserve_color_scheme(&settings, sim.flow)
		sim.flow = settings
	case .Slime_Mold:
		settings := slime_settings_default()
		switch preset_index {
		case 1: // Gloop Loops
			settings.agent_jitter = 0.1
			settings.agent_turn_rate = 0.43
			settings.agent_speed_max = 300.0
			settings.agent_sensor_angle = 0.7
			settings.agent_sensor_distance = 5.0
			settings.pheromone_decay_rate = 100.0
		case 2: // Firecracker Trees
			settings.agent_jitter = 0.1
			settings.agent_turn_rate = 0.93
			settings.agent_speed_min = 200.0
			settings.agent_speed_max = 300.0
			settings.agent_sensor_angle = 0.3
		case 3: // Threads
			settings.agent_jitter = 0.0
			settings.agent_turn_rate = 0.02
			settings.agent_sensor_angle = 0.3
			settings.agent_speed_min = 50.0
			settings.agent_speed_max = 150.0
			settings.pheromone_decay_rate = 100.0
		case 4: // Snake
			settings.agent_turn_rate = 0.37
			settings.agent_sensor_angle = 1.34
			settings.agent_sensor_distance = 225.0
		case 5: // Cells
			settings.agent_jitter = 0.2
			settings.agent_turn_rate = 3.27
			settings.agent_speed_min = 200.0
			settings.agent_speed_max = 300.0
			settings.agent_sensor_angle = 1.95
			settings.agent_sensor_distance = 60.0
			settings.pheromone_decay_rate = 30.0
		case 6: // Net
			settings.agent_jitter = 3.0
			settings.agent_turn_rate = 6.0
			settings.agent_speed_min = 99.0
			settings.agent_speed_max = 100.0
			settings.agent_sensor_angle = 1.57
			settings.agent_sensor_distance = 225.0
			settings.pheromone_decay_rate = 400.0
		case 7: // Bars
			settings.agent_jitter = 3.9499364
			settings.agent_sensor_angle = 2.1932874
			settings.agent_sensor_distance = 443.47357
			settings.agent_speed_max = 482.0867
			settings.agent_speed_min = 426.72086
			settings.agent_turn_rate = 4.9691095
			settings.pheromone_decay_rate = 100.0
			settings.pheromone_deposition_rate = 43.590575
			settings.pheromone_diffusion_rate = 47.48144
		case 8: // Healthy Fungus
			settings.agent_jitter = 3.1646671
			settings.agent_sensor_angle = 1.2506089
			settings.agent_sensor_distance = 8.729994
			settings.agent_speed_max = 479.0331
			settings.agent_speed_min = 294.0581
			settings.agent_turn_rate = 0.88734615
			settings.pheromone_decay_rate = 100.0
			settings.pheromone_deposition_rate = 52.57219
			settings.pheromone_diffusion_rate = 24.33
		case 9: // Sand On A Speaker
			settings.agent_jitter = 2.991177
			settings.agent_sensor_angle = 0.6429619
			settings.agent_sensor_distance = 144.3722
			settings.agent_speed_max = 447.08768
			settings.agent_speed_min = 416.39087
			settings.agent_turn_rate = 2.1364458
			settings.pheromone_decay_rate = 100.0
			settings.pheromone_deposition_rate = 63.37401
			settings.pheromone_diffusion_rate = 7.905072
		case 10: // Spots
			settings.agent_jitter = 0.25468826
			settings.agent_sensor_angle = 1.5476805
			settings.agent_sensor_distance = 31.14605
			settings.agent_speed_max = 350.69513
			settings.agent_speed_min = 300.85114
			settings.agent_turn_rate = 4.5000796
			settings.pheromone_decay_rate = 100.0
			settings.pheromone_deposition_rate = 22.841704
			settings.pheromone_diffusion_rate = 6.278837
		case 11: // Cascades
			settings.agent_jitter = 4.6256456
			settings.agent_sensor_angle = 0.8972509
			settings.agent_sensor_distance = 239.66182
			settings.agent_speed_max = 381.27463
			settings.agent_speed_min = 276.8555
			settings.agent_turn_rate = 0.7331312
			settings.pheromone_decay_rate = 100.0
			settings.pheromone_deposition_rate = 27.726316
			settings.pheromone_diffusion_rate = 66.05927
		case 12: // Venom
			settings.agent_jitter = 2.0
			settings.agent_sensor_angle = 0.3
			settings.agent_sensor_distance = 20.0
			settings.agent_speed_max = 500.0
			settings.agent_speed_min = 0.0
			settings.agent_turn_rate = 0.20943952
		case:
		}
		slime_settings_preserve_color_scheme(&settings, sim.slime)
		sim.slime = settings
	case:
	}
}

remaining_sim_init :: proc(sim: ^Remaining_Sim_State) {
	sim^ = {
		intensity = 0.72,
		scale = 1.0,
		speed = 1.0,
		density = 0.55,
		cursor_size = 0.20,
		cursor_strength = 1.0,
		moire = moire_settings_default(),
		vectors = vectors_settings_default(),
		primordial = primordial_settings_default(),
		voronoi = voronoi_settings_default(),
		pellets = pellets_settings_default(),
		flow = flow_settings_default(),
		slime = slime_settings_default(),
	}
	camera_controls_init(&sim.camera)
}

remaining_sim_reset_with_undo :: proc(sim: ^Remaining_Sim_State) {
	if sim == nil {
		return
	}
	undo := Remaining_Sim_Reset_Undo {
		available = true,
		paused = sim.paused,
		time = sim.time,
		intensity = sim.intensity,
		scale = sim.scale,
		speed = sim.speed,
		density = sim.density,
		camera = sim.camera,
		cursor_size = sim.cursor_size,
		cursor_strength = sim.cursor_strength,
		builtin_preset_index = sim.builtin_preset_index,
		moire = sim.moire,
		vectors = sim.vectors,
		primordial = sim.primordial,
		voronoi = sim.voronoi,
		pellets = sim.pellets,
		flow = sim.flow,
		slime = sim.slime,
		slime_randomize_undo = sim.slime_randomize_undo,
		slime_randomize_undo_available = sim.slime_randomize_undo_available,
	}
	remaining_sim_init(sim)
	sim.reset_undo = undo
}

remaining_sim_undo_reset :: proc(sim: ^Remaining_Sim_State) -> bool {
	if sim == nil || !sim.reset_undo.available {
		return false
	}
	undo := sim.reset_undo
	sim.paused = undo.paused
	sim.time = undo.time
	sim.intensity = undo.intensity
	sim.scale = undo.scale
	sim.speed = undo.speed
	sim.density = undo.density
	sim.camera = undo.camera
	sim.cursor_size = undo.cursor_size
	sim.cursor_strength = undo.cursor_strength
	sim.builtin_preset_index = undo.builtin_preset_index
	sim.moire = undo.moire
	sim.vectors = undo.vectors
	sim.primordial = undo.primordial
	sim.voronoi = undo.voronoi
	sim.pellets = undo.pellets
	sim.flow = undo.flow
	sim.slime = undo.slime
	sim.slime_randomize_undo = undo.slime_randomize_undo
	sim.slime_randomize_undo_available = undo.slime_randomize_undo_available
	sim.reset_undo.available = false
	sim.slime_reset_requested = true
	return true
}

slime_request_reset :: proc(sim: ^Remaining_Sim_State) {
	if sim == nil {
		return
	}
	sim.slime_reset_requested = true
}

slime_request_clear_trails :: proc(sim: ^Remaining_Sim_State) {
	if sim == nil {
		return
	}
	sim.slime_clear_trails_requested = true
}

slime_random01 :: proc(seed: ^u32) -> f32 {
	seed^ = seed^ * 1664525 + 1013904223
	return f32(seed^ & 0x00ffffff) / f32(0x01000000)
}

slime_random_range :: proc(seed: ^u32, min_value, max_value: f32) -> f32 {
	return min_value + (max_value - min_value) * slime_random01(seed)
}

slime_randomize_seed :: proc(sim: ^Remaining_Sim_State) {
	if sim == nil {
		return
	}
	seed := sim.slime.random_seed
	if seed == 0 {
		seed = 0x6d2b79f5
	}
	seed = seed * 1664525 + 1013904223
	sim.slime.random_seed = seed
	slime_request_reset(sim)
}

slime_randomize_settings :: proc(sim: ^Remaining_Sim_State) {
	if sim == nil {
		return
	}
	sim.slime_randomize_undo = {
		agent_jitter = sim.slime.agent_jitter,
		agent_sensor_angle = sim.slime.agent_sensor_angle,
		agent_sensor_distance = sim.slime.agent_sensor_distance,
		agent_speed_min = sim.slime.agent_speed_min,
		agent_speed_max = sim.slime.agent_speed_max,
		agent_turn_rate = sim.slime.agent_turn_rate,
		pheromone_decay_rate = sim.slime.pheromone_decay_rate,
		pheromone_deposition_rate = sim.slime.pheromone_deposition_rate,
		pheromone_diffusion_rate = sim.slime.pheromone_diffusion_rate,
		random_seed = sim.slime.random_seed,
	}
	sim.slime_randomize_undo_available = true
	settings := &sim.slime
	seed := settings.random_seed
	if seed == 0 {
		seed = 0x9e3779b9
	}
	seed += 0x6d2b79f5
	settings.agent_jitter = slime_random_range(&seed, 0.0, 4.0)
	settings.agent_sensor_angle = slime_random_range(&seed, 0.15, 2.4)
	settings.agent_sensor_distance = slime_random_range(&seed, 4.0, 260.0)
	settings.agent_speed_min = slime_random_range(&seed, 0.0, 430.0)
	settings.agent_speed_max = slime_random_range(&seed, max(settings.agent_speed_min + 1.0, 20.0), 500.0)
	settings.agent_turn_rate = slime_random_range(&seed, 0.02, 5.5)
	settings.pheromone_decay_rate = slime_random_range(&seed, 4.0, 140.0)
	settings.pheromone_deposition_rate = slime_random_range(&seed, 15.0, 160.0)
	settings.pheromone_diffusion_rate = slime_random_range(&seed, 0.0, 130.0)
	settings.random_seed = seed
	slime_request_reset(sim)
}

slime_undo_randomize_settings :: proc(sim: ^Remaining_Sim_State) -> bool {
	if sim == nil || !sim.slime_randomize_undo_available {
		return false
	}
	undo := sim.slime_randomize_undo
	sim.slime.agent_jitter = undo.agent_jitter
	sim.slime.agent_sensor_angle = undo.agent_sensor_angle
	sim.slime.agent_sensor_distance = undo.agent_sensor_distance
	sim.slime.agent_speed_min = undo.agent_speed_min
	sim.slime.agent_speed_max = undo.agent_speed_max
	sim.slime.agent_turn_rate = undo.agent_turn_rate
	sim.slime.pheromone_decay_rate = undo.pheromone_decay_rate
	sim.slime.pheromone_deposition_rate = undo.pheromone_deposition_rate
	sim.slime.pheromone_diffusion_rate = undo.pheromone_diffusion_rate
	sim.slime.random_seed = undo.random_seed
	sim.slime_randomize_undo_available = false
	slime_request_reset(sim)
	return true
}

remaining_sim_apply_frame_input :: proc(sim: ^Remaining_Sim_State, input: Ui_Frame_Input) {
	remaining_sim_apply_frame_input_for_kind(sim, .Flow_Field, input)
}

remaining_sim_apply_frame_input_for_kind :: proc(sim: ^Remaining_Sim_State, kind: Remaining_Sim_Kind, input: Ui_Frame_Input) {
	if kind == .Slime_Mold {
		camera_controls_apply_input(&sim.camera, input)
	}
	was_cursor_active := sim.cursor_active
	previous_cursor_velocity := sim.cursor_world_velocity
	sim.cursor_active = 0
	sim.cursor_mode = 0
	if input.window_width <= 0 || input.window_height <= 0 {
		sim.cursor_world_velocity = {0, 0}
		return
	}
	world := remaining_sim_screen_to_world(input.mouse_pos, input.window_width, input.window_height)
	if kind == .Slime_Mold {
		world = camera_controls_screen_to_world(&sim.camera, input.mouse_pos, input.window_width, input.window_height)
	}
	// Flow Field and Pellets render their world coordinates with Vulkan's
	// downward-positive viewport Y, so keep pointer Y in the same space.
	if kind == .Flow_Field || kind == .Pellets {
		world[1] = -world[1]
	}
	dt := max(input.delta_time, 1.0 / 240.0)
	measured_velocity := [2]f32{
		(world[0] - sim.cursor_world_prev[0]) / dt,
		(world[1] - sim.cursor_world_prev[1]) / dt,
	}
	sim.cursor_world_velocity = remaining_sim_cursor_velocity_for_kind(kind, was_cursor_active, input.mouse_down, previous_cursor_velocity, measured_velocity)
	sim.cursor_world = world
	sim.cursor_world_prev = world
	sim.cursor_pixel = {input.mouse_pos.x, input.mouse_pos.y}
	if kind == .Slime_Mold {
		sim.cursor_pixel = {
			(world[0] + 1.0) * 0.5 * f32(input.window_width),
			(world[1] + 1.0) * 0.5 * f32(input.window_height),
		}
	}
	if input.mouse_down {
		sim.cursor_active = 1
		sim.cursor_mode = input.mouse_button == 3 ? u32(2) : u32(1)
	}
	tool_set := canvas_tool_set_for_kind(kind)
	canvas_tool_update_selection(&tool_set, &sim.canvas_tool, input)
	if kind == .Voronoi_CA {
		tool := canvas_tool_selected(&tool_set, &sim.canvas_tool)
		sim.voronoi_pressed = input.mouse_pressed || input.primary_pressed || input.secondary_pressed
		sim.voronoi_released = input.mouse_released || input.primary_released || input.secondary_released
		// 1 magnet, 2 repel, 3 pluck, 4 paint, 5 erase.
		sim.voronoi_interaction_mode = 0
		if input.mouse_down || input.primary_down || input.secondary_down {
			secondary := input.mouse_button == 3 || input.secondary_down
			action := canvas_tool_action_for_input(tool, secondary)
			#partial switch action {
			case .Attract: sim.voronoi_interaction_mode = 1
			case .Repel: sim.voronoi_interaction_mode = 2
			case .Pluck: sim.voronoi_interaction_mode = 3
			case .Paint_Sites: sim.voronoi_interaction_mode = 4
			case .Erase_Sites: sim.voronoi_interaction_mode = 5
			case .Shockwave: sim.voronoi_interaction_mode = 6
			case:
			}
		}
	}
}

remaining_sim_cursor_velocity_for_kind :: proc(kind: Remaining_Sim_Kind, was_cursor_active: u32, mouse_down: bool, previous_velocity, measured_velocity: [2]f32) -> [2]f32 {
	if kind != .Pellets {
		return measured_velocity
	}

	if mouse_down {
		if was_cursor_active == 0 {
			return measured_velocity
		}
		smoothing_factor := f32(0.7)
		return {
			previous_velocity[0] * (1.0 - smoothing_factor) + measured_velocity[0] * smoothing_factor,
			previous_velocity[1] * (1.0 - smoothing_factor) + measured_velocity[1] * smoothing_factor,
		}
	}

	decay_factor := f32(0.95)
	return {
		previous_velocity[0] * decay_factor,
		previous_velocity[1] * decay_factor,
	}
}

remaining_sim_screen_to_world :: proc(mouse_pos: uifw.Vec2, width, height: i32) -> [2]f32 {
	w := max(f32(width), 1)
	h := max(f32(height), 1)
	return {
		(mouse_pos.x / w) * 2.0 - 1.0,
		-((mouse_pos.y / h) * 2.0 - 1.0),
	}
}

remaining_sim_step :: proc(sim: ^Remaining_Sim_State, dt: f32) {
	if sim.paused {
		return
	}
	speed := sim.speed
	if sim.moire.speed > 0 {
		speed = sim.moire.speed
	}
	sim.time += dt * max(speed, 0)
}

remaining_sim_name :: proc(kind: Remaining_Sim_Kind) -> string {
	switch kind {
	case .Slime_Mold:
		return "Slime Mold"
	case .Flow_Field:
		return "Flow Field"
	case .Pellets:
		return "Pellets"
	case .Voronoi_CA:
		return "Voronoi"
	case .Moire:
		return "Moire"
	case .Vectors:
		return "Vectors"
	case .Primordial:
		return "Primordial"
	}
	return "Simulation"
}

remaining_sim_description :: proc(kind: Remaining_Sim_Kind) -> string {
	switch kind {
	case .Slime_Mold:
		return "Agent trails with decay and branching motion."
	case .Flow_Field:
		return "Particles advected through layered vector fields."
	case .Pellets:
		return "Particle physics with trails and density shading."
	case .Voronoi_CA:
		return "Drifting nearest-site regions with color-map controls."
	case .Moire:
		return "Interference patterns from rotating frequency grids."
	case .Vectors:
		return "A sampled field rendered as directional line glyphs."
	case .Primordial:
		return "Emergent particle motion with density feedback."
	}
	return ""
}

remaining_sim_draw :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind, width, height: f32) {
	bg0 := uifw.Color{0.018, 0.022, 0.028, 1}
	bg1 := uifw.Color{0.080, 0.076, 0.058, 1}
	switch kind {
	case .Slime_Mold:
		bg1 = {0.052, 0.092, 0.070, 1}
	case .Flow_Field:
		bg1 = {0.040, 0.074, 0.098, 1}
	case .Pellets:
		bg1 = {0.095, 0.058, 0.045, 1}
	case .Voronoi_CA:
		bg1 = {0.070, 0.065, 0.100, 1}
	case .Moire:
		bg1 = {0.090, 0.087, 0.045, 1}
	case .Vectors:
		bg1 = {0.030, 0.072, 0.075, 1}
	case .Primordial:
		bg1 = {0.082, 0.044, 0.082, 1}
	}
	uifw.gui_gradient_rect(gui, {0, 0, width, height}, bg0, bg1)

	switch kind {
	case .Slime_Mold:
		remaining_sim_draw_slime(sim, gui, width, height)
	case .Flow_Field:
		remaining_sim_draw_flow(sim, gui, width, height)
	case .Pellets:
		remaining_sim_draw_pellets(sim, gui, width, height)
	case .Voronoi_CA:
		remaining_sim_draw_voronoi(sim, gui, width, height)
	case .Moire:
		remaining_sim_draw_moire(sim, gui, width, height)
	case .Vectors:
		remaining_sim_draw_vectors(sim, gui, width, height)
	case .Primordial:
		remaining_sim_draw_primordial(sim, gui, width, height)
	}
}

remaining_sim_draw_slime :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, width, height: f32) {
	settings := &sim.slime
	if settings.background_mode == .White {
		uifw.gui_rect(gui, {0, 0, width, height}, {0.90, 0.92, 0.88, 0.70})
	}
	center := uifw.Vec2{width * 0.5, height * 0.54}
	count := 90
	for i in 0 ..< count {
		t := f32(i) / f32(count)
		heading := (settings.agent_heading_start + (settings.agent_heading_end - settings.agent_heading_start) * t) * 0.01745329252
		angle := heading + t * 18.8495559 + sim.time * settings.agent_turn_rate * (0.8 + t)
		speed_norm := (settings.agent_speed_min + (settings.agent_speed_max - settings.agent_speed_min) * t) / 500.0
		r := (0.08 + t * 0.42 + speed_norm * 0.18) * min(width, height) * sim.scale
		p := uifw.Vec2{center.x + math.cos(angle) * r, center.y + math.sin(angle * 0.86) * r * 0.62}
		sensor := settings.agent_sensor_distance
		q := uifw.Vec2{center.x + math.cos(angle + settings.agent_sensor_angle) * (r + sensor), center.y + math.sin(angle * 0.86 + settings.agent_sensor_angle) * (r + sensor * 0.42) * 0.62}
		alpha := (0.18 + t * 0.48) * sim.intensity * min(settings.pheromone_deposition_rate / 100.0, 2)
		uifw.gui_line(gui, p, q, {0.54, 0.95, 0.68, alpha}, 2)
	}
}

remaining_sim_draw_flow :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, width, height: f32) {
	settings := &sim.flow
	cols := 28
	rows := 16
	for y in 0 ..< rows {
		for x in 0 ..< cols {
			fx := (f32(x) + 0.5) / f32(cols)
			fy := (f32(y) + 0.5) / f32(rows)
				angle := noise_sample_2d(&settings.noise, fx, fy, sim.time) * 3.14159
			len := (14 + 340 * settings.vector_magnitude) * sim.scale
			c := uifw.Vec2{fx * width, fy * height}
			d := uifw.Vec2{math.cos(angle) * len, math.sin(angle) * len}
			uifw.gui_line(gui, {c.x - d.x, c.y - d.y}, {c.x + d.x, c.y + d.y}, {0.35, 0.82, 1.0, 0.42 * sim.intensity}, 2)
		}
	}
	particles := min(max(int(settings.total_pool_size / 2500), 20), 140)
	for i in 0 ..< particles {
		t := f32(i)
		life_phase := math.mod(sim.time * settings.particle_speed + t / max(f32(particles), 1), max(settings.particle_lifetime, 0.001))
		age := life_phase / max(settings.particle_lifetime, 0.001)
		x := width * (0.5 + 0.45 * math.sin(t * 1.37 + sim.time * settings.particle_speed))
		y := height * (0.5 + 0.40 * math.cos(t * 0.91 - sim.time * settings.particle_speed))
		size := f32(settings.particle_size)
		alpha := (1 - age) * (0.18 + settings.trail_deposition_rate * 0.28)
		color := uifw.Color{0.78, 0.94, 1.0, alpha}
		if settings.foreground_color_mode == .Random {
			color = {0.55 + 0.35 * math.sin(t), 0.48 + 0.42 * math.cos(t), 0.95, alpha}
		} else if settings.foreground_color_mode == .Direction {
			color = {0.95, 0.68, 0.30, alpha}
		}
		remaining_sim_draw_flow_particle(gui, settings.particle_shape, {x, y}, size, color)
	}
}

remaining_sim_draw_flow_particle :: proc(gui: ^uifw.Gui_Context, shape: Flow_Particle_Shape, center: uifw.Vec2, size: f32, color: uifw.Color) {
	rect := uifw.Rect{center.x - size, center.y - size, size * 2, size * 2}
	#partial switch shape {
	case .Square:
		uifw.gui_rect(gui, rect, color)
	case .Triangle:
		uifw.gui_quad(gui, {center.x, center.y - size}, {center.x + size, center.y + size}, {center.x - size, center.y + size}, {center.x, center.y - size}, color)
	case .Diamond:
		uifw.gui_quad(gui, {center.x, center.y - size}, {center.x + size, center.y}, {center.x, center.y + size}, {center.x - size, center.y}, color)
	case:
		uifw.gui_ellipse(gui, rect, color)
	}
}

remaining_sim_draw_pellets :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, width, height: f32) {
	settings := &sim.pellets
	#partial switch settings.background_color_mode {
	case .White:
		uifw.gui_rect(gui, {0, 0, width, height}, {0.92, 0.91, 0.88, 0.70})
	case .Gray18:
		uifw.gui_rect(gui, {0, 0, width, height}, {0.18, 0.18, 0.18, 0.78})
	case .Color_Scheme:
		uifw.gui_gradient_rect(gui, {0, 0, width, height}, {0.10, 0.05, 0.08, 0.72}, {0.08, 0.10, 0.05, 0.72})
	case:
	}
	count := min(max(int(settings.particle_count / 64), 40), 220)
	for i in 0 ..< count {
		t := f32(i)
		orbit := settings.initial_velocity_min + (settings.initial_velocity_max - settings.initial_velocity_min) * (0.5 + 0.5 * math.sin(t))
		x := width * (0.5 + 0.43 * math.sin(t * 1.71 + sim.time * (0.22 + orbit)))
		y := height * (0.5 + 0.38 * math.cos(t * 1.19 + sim.time * (0.31 + orbit)))
		r := max(settings.particle_size * min(width, height), 1.5)
		color := uifw.Color{1.0, 0.54, 0.30, 0.24 + 0.48 * sim.intensity}
		if settings.foreground_color_mode == .Velocity {
			color = {0.34, 0.84, 1.0, color.a}
		} else if settings.foreground_color_mode == .Random {
			color = {0.82 + 0.18 * math.sin(t), 0.38 + 0.28 * math.cos(t * 1.7), 0.72, color.a}
		}
		uifw.gui_ellipse(gui, {x - r, y - r, r * 2, r * 2}, color)
	}
}

remaining_sim_draw_voronoi :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, width, height: f32) {
	settings := &sim.voronoi
	target_cells := max(math.sqrt(f32(max(settings.point_count, 1))) * 0.7, 4)
	cell := max(min(width, height) / target_cells / max(sim.scale, 0.25), 12)
	cols := int(width / cell) + 2
	rows := int(height / cell) + 2
	for y in 0 ..< rows {
		for x in 0 ..< cols {
			phase := math.sin(f32(x) * 0.7 + f32(y) * 1.1 + sim.time * settings.time_scale)
			color := uifw.Color{0.30 + phase * 0.08, 0.24 + phase * 0.10, 0.58 + phase * 0.10, 0.36 * sim.intensity}
			rect := uifw.Rect{f32(x) * cell - cell, f32(y) * cell - cell, cell + 1, cell + 1}
			uifw.gui_rect(gui, rect, color)
			if settings.borders_enabled {
				uifw.gui_stroke(gui, rect, {1, 1, 1, 0.06})
			}
		}
	}
}

remaining_sim_draw_moire :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, width, height: f32) {
	settings := &sim.moire
	center := uifw.Vec2{width * 0.5, height * 0.5}
	count := 72
	for i in 0 ..< count {
		t := f32(i) / f32(count)
		base_r := min(width, height) * (0.05 + t * 0.70)
		r := base_r * max(settings.moire_scale, 0.1)
		a0 := settings.moire_rotation + sim.time * settings.advect_speed * 0.18 + t * 3.14159
		a1 := settings.moire_rotation3 - sim.time * settings.advect_speed * 0.11 + t * 6.28318
		if settings.generator_type == .Radial {
			swirl := settings.radial_swirl_strength * math.sin(t * settings.radial_starburst_count + sim.time)
			rect := uifw.Rect{center.x - r, center.y - r, r * 2, r * 2}
			alpha := (0.06 + t * 0.22) * settings.moire_amount
			uifw.gui_ellipse_stroke(gui, rect, {0.98, 0.78, 0.38, alpha}, 1 + settings.moire_interference * 3)
			uifw.gui_rotated_rect(gui, {center.x - r, center.y - 0.5, r * 2, 1.0}, a0 + swirl, {0.42, 0.96, 0.86, 0.08 * settings.moire_amount})
		} else {
			span := max(width, height) * 1.25
			row_y := center.y + (t - 0.5) * height * 1.25
			x := center.x - span * 0.5
			uifw.gui_rotated_rect(gui, {x, row_y, span, 1.0 + settings.moire_interference * 3}, a0, {0.96, 0.84, 0.38, 0.12 * settings.moire_amount})
			uifw.gui_rotated_rect(gui, {x, row_y, span, 1.0 + settings.moire_weight3 * 4}, a1, {0.45, 0.95, 0.88, 0.08 * settings.moire_amount})
		}
	}
	glow := min(width, height) * 0.28 * max(settings.radial_center_brightness, 0)
	if settings.generator_type == .Radial && glow > 1 {
		uifw.gui_ellipse(gui, {center.x - glow, center.y - glow, glow * 2, glow * 2}, {1.0, 0.92, 0.56, 0.035 * settings.moire_amount})
	}
}

remaining_sim_draw_vectors :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, width, height: f32) {
	settings := &sim.vectors
	#partial switch settings.background_color_mode {
	case .White:
		uifw.gui_rect(gui, {0, 0, width, height}, {0.92, 0.93, 0.90, 0.72})
	case .Gray18:
		uifw.gui_rect(gui, {0, 0, width, height}, {0.18, 0.18, 0.18, 0.84})
	case .Color_Scheme:
		uifw.gui_gradient_rect(gui, {0, 0, width, height}, {0.06, 0.12, 0.10, 0.82}, {0.11, 0.08, 0.18, 0.82})
	case:
	}
	spacing := max(settings.density, VECTORS_MIN_DENSITY)
	cols := int(2.0 / spacing)
	rows := int(1.12 / spacing)
	cols = min(max(cols, 8), 480)
	rows = min(max(rows, 5), 360)
	for y in 0 ..< rows {
		for x in 0 ..< cols {
			px := (f32(x) + 0.5) / f32(cols) * width
			py := (f32(y) + 0.5) / f32(rows) * height
				v := noise_sample_2d(&settings.noise, f32(x) / f32(cols), f32(y) / f32(rows), sim.time)
			angle := v * 3.14159
			len := max(settings.line_length, 0.001) * min(width, height) * (0.5 + math.clamp(v, 0, 1) * 0.5)
			d := uifw.Vec2{math.cos(angle) * len, math.sin(angle) * len}
			line_width := max(settings.line_width * min(width, height), 1)
			uifw.gui_line(gui, {px, py}, {px + d.x, py + d.y}, {0.42, 0.93, 0.84, 0.55 * sim.intensity}, line_width)
		}
	}
}

remaining_sim_draw_primordial :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, width, height: f32) {
	settings := &sim.primordial
	center := uifw.Vec2{width * 0.5, height * 0.5}
	count := 120
	for i in 0 ..< count {
		t := f32(i) / f32(count)
		alpha := settings.alpha * 0.01745329252
		angle := t * 6.2831853 * 7 + alpha + sim.time * settings.velocity * (1 + t)
		r := min(width, height) * (settings.radius + 0.43 * math.sin(t * 9.0 + sim.time * settings.beta) * 0.5 + t * 0.36) * sim.scale
		x := center.x + math.cos(angle) * r
		y := center.y + math.sin(angle * 1.17) * r
		size := 2.5 + 5.0 * sim.density
		uifw.gui_ellipse(gui, {x - size, y - size, size * 2, size * 2}, {0.93, 0.42, 0.94, 0.22 + 0.48 * sim.intensity})
	}
}
