package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"
import "core:math"
import sdl "vendor:sdl3"

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
		display_mode = .Lines,
		display_index = int(Vector_Display_Mode.Lines),
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
		collision_enabled = true,
		collision_relaxation = 0.8,
		collision_damping = 0.98,
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
		emitter_mode = .Area,
		emitter_radius = 0.5,
		boundary_mode = .Wrap,
		trail_style = .Ink,
		field_animation_enabled = false,
		field_animation_speed = 0.15,
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
		emitter_index = int(Flow_Emitter_Mode.Area),
		boundary_index = int(Flow_Boundary_Mode.Wrap),
		trail_style_index = int(Flow_Trail_Style.Ink),
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
		agent_count = SLIME_AGENT_COUNT,
		agent_jitter = 0.04,
		isotropic_jitter = true,
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
		slime_request_reset(sim)
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
