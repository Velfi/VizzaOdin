package app

import "core:fmt"
import "core:strings"

mcp_bridge_configure_particle_life :: proc(id: string, bridge: ^Mcp_Bridge, line: string) -> string {
	settings := particle_life_default_settings()

	if value, ok := mcp_bridge_extract_number_field(line, "particle_count"); ok {
		settings.particle_count = u32(max(min(value, f32(PARTICLE_LIFE_MAX_PARTICLE_COUNT)), 1))
	}
	if value, ok := mcp_bridge_extract_number_field(line, "species_count"); ok {
		settings.species_count = u32(max(min(value, f32(PARTICLE_LIFE_MAX_SPECIES)), 1))
	}
	if value, ok := mcp_bridge_extract_number_field(line, "max_distance"); ok {
		settings.max_distance = max(value, 0.001)
	}
	if value, ok := mcp_bridge_extract_bool_field(line, "collision_enabled"); ok {
		settings.collision_enabled = value
	}
	if value, ok := mcp_bridge_extract_bool_field(line, "force_dense_sampling"); ok {
		settings.force_dense_sampling = value
	}
	if value, ok := mcp_bridge_extract_number_field(line, "position_generator"); ok {
		settings.position_generator = u32(max(min(value, f32(len(PARTICLE_LIFE_POSITION_GENERATOR_NAMES) - 1)), 0))
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "position_generator")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, PARTICLE_LIFE_POSITION_GENERATOR_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Particle Life position_generator")
			}
			settings.position_generator = index
		}
	}
	if value, ok := mcp_bridge_extract_number_field(line, "type_generator"); ok {
		settings.type_generator = u32(max(min(value, f32(len(PARTICLE_LIFE_TYPE_GENERATOR_NAMES) - 1)), 0))
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "type_generator")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, PARTICLE_LIFE_TYPE_GENERATOR_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Particle Life type_generator")
			}
			settings.type_generator = index
		}
	}
	if value, ok := mcp_bridge_extract_number_field(line, "force_generator"); ok {
		settings.force_generator = u32(max(min(value, f32(len(PARTICLE_LIFE_FORCE_GENERATOR_NAMES) - 1)), 0))
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "force_generator")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, PARTICLE_LIFE_FORCE_GENERATOR_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Particle Life force_generator")
			}
			settings.force_generator = index
		}
	}
	force_fields_set := false
	if value, ok := mcp_bridge_extract_number_field(line, "force_random_min"); ok {
		settings.force_random_min = max(min(value, 1.5), -1.5)
		force_fields_set = true
	}
	if value, ok := mcp_bridge_extract_number_field(line, "force_random_max"); ok {
		settings.force_random_max = max(min(value, 1.5), -1.5)
		force_fields_set = true
	}
	if settings.force_random_min > settings.force_random_max {
		settings.force_random_min, settings.force_random_max = settings.force_random_max, settings.force_random_min
	}

	randomize := force_fields_set
	if value, ok := mcp_bridge_extract_bool_field(line, "randomize_forces"); ok {
		randomize = value
	}
	reset := true
	if value, ok := mcp_bridge_extract_bool_field(line, "reset"); ok {
		reset = value
	}
	hide_ui := false
	if value, ok := mcp_bridge_extract_bool_field(line, "hide_ui"); ok {
		hide_ui = value
	}
	set_mode := true
	if value, ok := mcp_bridge_extract_bool_field(line, "set_mode"); ok {
		set_mode = value
	}

	cmd := Mcp_Command {
		kind = .Configure_Particle_Life,
		particle_life_settings = settings,
		particle_life_randomize_forces = randomize,
		particle_life_reset = reset,
		particle_life_hide_ui = hide_ui,
		particle_life_set_mode = set_mode,
	}
	if !mcp_bridge_enqueue_command(bridge, cmd) {
		return mcp_bridge_queue_error(id, bridge)
	}
	return mcp_bridge_tool_text(
		id,
		fmt.tprintf(
			"{{\"ok\":true,\"queued\":\"configure_particle_life\",\"settings\":{{\"particle_count\":%d,\"species_count\":%d,\"position_generator\":%d,\"type_generator\":%d,\"force_generator\":%d,\"force_random_min\":%.4f,\"force_random_max\":%.4f,\"randomize_forces\":%v,\"reset\":%v,\"hide_ui\":%v,\"set_mode\":%v}}}}",
			settings.particle_count,
			settings.species_count,
			settings.position_generator,
			settings.type_generator,
			settings.force_generator,
			settings.force_random_min,
			settings.force_random_max,
			randomize,
			reset,
			hide_ui,
			set_mode,
		),
	)
}

mcp_bridge_configure_flow_field :: proc(id: string, bridge: ^Mcp_Bridge, line: string) -> string {
	settings := flow_settings_default()

	if value, ok := mcp_bridge_extract_number_field(line, "vector_field_type"); ok {
		settings.vector_field_index = int(max(min(value, f32(len(VECTOR_FIELD_TYPE_NAMES) - 1)), 0))
		settings.vector_field_type = Vector_Field_Type(settings.vector_field_index)
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "vector_field_type")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, VECTOR_FIELD_TYPE_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Flow vector_field_type")
			}
			settings.vector_field_index = int(index)
			settings.vector_field_type = Vector_Field_Type(index)
		}
	}
	if value, ok := mcp_bridge_extract_number_field(line, "noise_kind"); ok {
		settings.noise.kind_index = int(max(min(value, f32(len(NOISE_KIND_NAMES) - 1)), 0))
		settings.noise.kind = Noise_Kind(settings.noise.kind_index)
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "noise_kind")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, NOISE_KIND_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Flow noise_kind")
			}
			settings.noise.kind_index = int(index)
			settings.noise.kind = Noise_Kind(index)
		}
	}
	if value, ok := mcp_bridge_extract_number_field(line, "fractal_mode"); ok {
		settings.noise.fractal_mode_index = int(max(min(value, f32(len(NOISE_FRACTAL_MODE_NAMES) - 1)), 0))
		settings.noise.fractal_mode = Noise_Fractal_Mode(settings.noise.fractal_mode_index)
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "fractal_mode")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, NOISE_FRACTAL_MODE_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Flow fractal_mode")
			}
			settings.noise.fractal_mode_index = int(index)
			settings.noise.fractal_mode = Noise_Fractal_Mode(index)
		}
	}
	if value, ok := mcp_bridge_extract_number_field(line, "warp_mode"); ok {
		settings.noise.warp_mode_index = int(max(min(value, f32(len(NOISE_WARP_MODE_NAMES) - 1)), 0))
		settings.noise.warp_mode = Noise_Warp_Mode(settings.noise.warp_mode_index)
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "warp_mode")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, NOISE_WARP_MODE_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Flow warp_mode")
			}
			settings.noise.warp_mode_index = int(index)
			settings.noise.warp_mode = Noise_Warp_Mode(index)
		}
	}
	if value, ok := mcp_bridge_extract_number_field(line, "seed"); ok {
		settings.noise.seed = u32(max(value, 0))
	}
	if value, ok := mcp_bridge_extract_number_field(line, "frequency"); ok {
		settings.noise.frequency = max(value, 0.000001)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "amplitude"); ok {
		settings.noise.amplitude = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "noise_strength"); ok {
		settings.noise.noise_strength = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "warp_amplitude"); ok {
		settings.noise.warp_amplitude = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "warp_frequency"); ok {
		settings.noise.warp_frequency = max(value, 0.000001)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "vector_magnitude"); ok {
		settings.vector_magnitude = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "particle_count"); ok {
		settings.total_pool_size = u32(max(min(value, 1000000), 1))
	}
	if value, ok := mcp_bridge_extract_number_field(line, "particle_lifetime"); ok {
		settings.particle_lifetime = max(value, 0.1)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "particle_speed"); ok {
		settings.particle_speed = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "particle_size"); ok {
		settings.particle_size = u32(max(min(value, 64), 1))
	}
	if value, ok := mcp_bridge_extract_number_field(line, "autospawn_rate"); ok {
		settings.autospawn_rate = u32(max(min(value, 100000), 0))
	}
	if value, ok := mcp_bridge_extract_bool_field(line, "show_particles"); ok {
		settings.show_particles = value
	}
	if value, ok := mcp_bridge_extract_number_field(line, "trail_decay_rate"); ok {
		settings.trail_decay_rate = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "trail_deposition_rate"); ok {
		settings.trail_deposition_rate = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "trail_diffusion_rate"); ok {
		settings.trail_diffusion_rate = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "trail_wash_out_rate"); ok {
		settings.trail_wash_out_rate = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "foreground_color_mode"); ok {
		settings.foreground_index = int(max(min(value, f32(len(FLOW_FOREGROUND_MODE_NAMES) - 1)), 0))
		settings.foreground_color_mode = Flow_Foreground_Mode(settings.foreground_index)
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "foreground_color_mode")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, FLOW_FOREGROUND_MODE_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Flow foreground_color_mode")
			}
			settings.foreground_index = int(index)
			settings.foreground_color_mode = Flow_Foreground_Mode(index)
		}
	}
	if value, ok := mcp_bridge_extract_number_field(line, "background_color_mode"); ok {
		settings.background_index = int(max(min(value, f32(len(VECTOR_BACKGROUND_MODE_NAMES) - 1)), 0))
		settings.background_color_mode = Vector_Background_Mode(settings.background_index)
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "background_color_mode")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, VECTOR_BACKGROUND_MODE_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Flow background_color_mode")
			}
			settings.background_index = int(index)
			settings.background_color_mode = Vector_Background_Mode(index)
		}
	}
	if name := mcp_bridge_extract_argument_string_field(line, "color_scheme"); len(name) > 0 {
		color_scheme_name_set(&settings.color_scheme, name)
	}
	if value, ok := mcp_bridge_extract_bool_field(line, "reversed"); ok {
		settings.color_scheme_reversed = value
	}
	noise_sync_indices(&settings.noise)

	reset := true
	if value, ok := mcp_bridge_extract_bool_field(line, "reset"); ok {
		reset = value
	}
	hide_ui := false
	if value, ok := mcp_bridge_extract_bool_field(line, "hide_ui"); ok {
		hide_ui = value
	}
	set_mode := true
	if value, ok := mcp_bridge_extract_bool_field(line, "set_mode"); ok {
		set_mode = value
	}

	cmd := Mcp_Command {
		kind = .Configure_Flow_Field,
		flow_settings = settings,
		flow_reset = reset,
		flow_hide_ui = hide_ui,
		flow_set_mode = set_mode,
	}
	if !mcp_bridge_enqueue_command(bridge, cmd) {
		return mcp_bridge_queue_error(id, bridge)
	}
	color_scheme := settings.color_scheme
	return mcp_bridge_tool_text(
		id,
		fmt.tprintf(
			"{{\"ok\":true,\"queued\":\"configure_flow_field\",\"settings\":{{\"noise_kind\":\"%s\",\"fractal_mode\":\"%s\",\"warp_mode\":\"%s\",\"seed\":%d,\"frequency\":%.4f,\"vector_magnitude\":%.4f,\"particle_count\":%d,\"particle_speed\":%.4f,\"particle_size\":%d,\"autospawn_rate\":%d,\"trail_decay_rate\":%.4f,\"trail_deposition_rate\":%.4f,\"trail_diffusion_rate\":%.4f,\"trail_wash_out_rate\":%.4f,\"color_scheme\":\"%s\",\"reversed\":%v,\"reset\":%v,\"hide_ui\":%v,\"set_mode\":%v}}}}",
			NOISE_KIND_NAMES[settings.noise.kind_index],
			NOISE_FRACTAL_MODE_NAMES[settings.noise.fractal_mode_index],
			NOISE_WARP_MODE_NAMES[settings.noise.warp_mode_index],
			settings.noise.seed,
			settings.noise.frequency,
			settings.vector_magnitude,
			settings.total_pool_size,
			settings.particle_speed,
			settings.particle_size,
			settings.autospawn_rate,
			settings.trail_decay_rate,
			settings.trail_deposition_rate,
			settings.trail_diffusion_rate,
			settings.trail_wash_out_rate,
			color_scheme_name_get(&color_scheme),
			settings.color_scheme_reversed,
			reset,
			hide_ui,
			set_mode,
		),
	)
}

mcp_bridge_configure_gray_scott :: proc(id: string, bridge: ^Mcp_Bridge, line: string) -> string {
	settings := gray_scott_default_settings()

	if value, ok := mcp_bridge_extract_number_field(line, "feed"); ok {settings.feed = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "kill"); ok {settings.kill = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "diffusion_a"); ok {settings.diffusion_a = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "diffusion_b"); ok {settings.diffusion_b = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "timestep"); ok {settings.timestep = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "simulation_speed"); ok {settings.simulation_speed = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "max_timestep"); ok {settings.max_timestep = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "stability_factor"); ok {settings.stability_factor = max(value, 0)}
	if value, ok := mcp_bridge_extract_bool_field(line, "enable_adaptive_timestep"); ok {settings.enable_adaptive_timestep = value}
	if value, ok := mcp_bridge_extract_number_field(line, "cursor_size"); ok {settings.cursor_size = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "cursor_strength"); ok {settings.cursor_strength = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "mask_strength"); ok {settings.mask_strength = max(value, 0)}
	if value, ok := mcp_bridge_extract_bool_field(line, "mask_mirror_horizontal"); ok {settings.mask_mirror_horizontal = value}
	if value, ok := mcp_bridge_extract_bool_field(line, "mask_mirror_vertical"); ok {settings.mask_mirror_vertical = value}
	if value, ok := mcp_bridge_extract_bool_field(line, "mask_invert_tone"); ok {settings.mask_invert_tone = value}
	if value, ok := mcp_bridge_extract_bool_field(line, "blur_enabled"); ok {settings.blur_enabled = value}
	if value, ok := mcp_bridge_extract_number_field(line, "blur_radius"); ok {settings.blur_radius = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "blur_sigma"); ok {settings.blur_sigma = max(value, 0)}
	if value, ok := mcp_bridge_extract_bool_field(line, "paused"); ok {settings.paused = value}
	if value, ok := mcp_bridge_extract_number_field(line, "mask_pattern"); ok {
		settings.mask_pattern = Gray_Scott_Mask_Pattern(u32(max(min(value, f32(len(GRAY_SCOTT_MASK_PATTERN_NAMES) - 1)), 0)))
	} else if name := mcp_bridge_extract_argument_string_field(line, "mask_pattern"); len(name) > 0 {
		pattern: Gray_Scott_Mask_Pattern
		if !gray_scott_mask_pattern_from_name(name, &pattern) {
			return mcp_bridge_error(id, -32602, "unknown Gray-Scott mask_pattern")
		}
		settings.mask_pattern = pattern
	}
	if value, ok := mcp_bridge_extract_number_field(line, "mask_target"); ok {
		settings.mask_target = gray_scott_mask_target_from_index(int(value))
	} else if name := mcp_bridge_extract_argument_string_field(line, "mask_target"); len(name) > 0 {
		index: u32
		if !mcp_bridge_named_index(name, GRAY_SCOTT_MASK_TARGET_NAMES[:], &index) {
			return mcp_bridge_error(id, -32602, "unknown Gray-Scott mask_target")
		}
		settings.mask_target = gray_scott_mask_target_from_index(int(index))
	}
	if value, ok := mcp_bridge_extract_number_field(line, "nutrient_image_fit_mode"); ok {
		settings.nutrient_image_fit_mode = Gray_Scott_Image_Fit_Mode(u32(max(min(value, f32(len(GRAY_SCOTT_IMAGE_FIT_MODE_NAMES) - 1)), 0)))
	} else if name := mcp_bridge_extract_argument_string_field(line, "nutrient_image_fit_mode"); len(name) > 0 {
		fit: Gray_Scott_Image_Fit_Mode
		if !gray_scott_image_fit_mode_from_name(name, &fit) {
			return mcp_bridge_error(id, -32602, "unknown Gray-Scott nutrient_image_fit_mode")
		}
		settings.nutrient_image_fit_mode = fit
	}
	if path := mcp_bridge_extract_argument_string_field(line, "nutrient_image_path"); len(path) > 0 {
		write_fixed_string(settings.nutrient_image_path[:], path)
		settings.mask_pattern = .Nutrient_Map
	}
	mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)

	reset, hide_ui, set_mode := mcp_bridge_capture_flags(line)
	seed_noise := false
	if value, ok := mcp_bridge_extract_bool_field(line, "seed_noise"); ok {seed_noise = value}
	cmd := Mcp_Command {
		kind = .Configure_Gray_Scott,
		gray_scott_settings = settings,
		gray_scott_reset = reset,
		gray_scott_seed_noise = seed_noise,
		gray_scott_hide_ui = hide_ui,
		gray_scott_set_mode = set_mode,
	}
	if !mcp_bridge_enqueue_command(bridge, cmd) {
		return mcp_bridge_queue_error(id, bridge)
	}
	return mcp_bridge_tool_text(id, fmt.tprintf("{{\"ok\":true,\"queued\":\"configure_gray_scott\",\"settings\":{{\"feed\":%.6f,\"kill\":%.6f,\"reset\":%v,\"seed_noise\":%v,\"hide_ui\":%v,\"set_mode\":%v}}}}", settings.feed, settings.kill, reset, seed_noise, hide_ui, set_mode))
}

mcp_bridge_configure_simulation :: proc(id: string, bridge: ^Mcp_Bridge, tool_name, line: string) -> string {
	mode_name := mcp_bridge_extract_string_field(line, "mode")
	if len(mode_name) == 0 {
		mode_name = mcp_bridge_mode_name_from_configure_tool(tool_name)
	}
	mode: App_Mode
	if !mcp_bridge_app_mode_from_name(mode_name, &mode) {
		return mcp_bridge_error(id, -32602, "configure_simulation requires a known non-gradient mode")
	}
	#partial switch mode {
	case .Gradient_Editor:
		return mcp_bridge_error(id, -32602, "Gradient_Editor does not support MCP config blobs")
	case .Gray_Scott:
		return mcp_bridge_configure_gray_scott(id, bridge, line)
	case .Particle_Life:
		return mcp_bridge_configure_particle_life(id, bridge, line)
	case .Flow_Field:
		return mcp_bridge_configure_flow_field(id, bridge, line)
	case .ST_FLIP:
		return mcp_bridge_configure_st_flip(id, bridge, line)
	case:
		kind: Remaining_Sim_Kind
		if !mcp_bridge_remaining_kind_from_mode(mode, &kind) {
			return mcp_bridge_error(id, -32602, "configure_simulation requires a simulation mode")
		}
		return mcp_bridge_configure_remaining_sim(id, bridge, kind, line)
	}
}

mcp_bridge_configure_st_flip :: proc(id: string, bridge: ^Mcp_Bridge, line: string) -> string {
	reset, hide_ui, set_mode := mcp_bridge_capture_flags(line)
	settings := st_flip_default_settings()
	mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)
	if value, ok := mcp_bridge_extract_number_field(line, "particle_count"); ok {settings.particle_count = u32(max(value, 1))}
	if value, ok := mcp_bridge_extract_number_field(line, "grid_height"); ok {settings.grid_height = u32(max(value, 1))}
	if value, ok := mcp_bridge_extract_number_field(line, "target_cfl"); ok {settings.target_cfl = value}
	if value, ok := mcp_bridge_extract_number_field(line, "simulation_speed"); ok {settings.simulation_speed = value}
	if value, ok := mcp_bridge_extract_number_field(line, "gravity"); ok {settings.gravity = value}
	if value, ok := mcp_bridge_extract_number_field(line, "flip_ratio"); ok {settings.flip_ratio = value}
	if value, ok := mcp_bridge_extract_number_field(line, "jitter_strength"); ok {settings.jitter_strength = value}
	if value, ok := mcp_bridge_extract_number_field(line, "phase_steepness"); ok {settings.phase_steepness = value}
	if value, ok := mcp_bridge_extract_number_field(line, "pressure_iterations"); ok {settings.pressure_iterations = u32(max(value, 1))}
	if value, ok := mcp_bridge_extract_number_field(line, "render_smoothing"); ok {settings.render_smoothing = value}
	if value, ok := mcp_bridge_extract_number_field(line, "random_seed"); ok {settings.random_seed = u32(max(value, 0))}
	if value, ok := mcp_bridge_extract_bool_field(line, "paused"); ok {settings.paused = value}
	if name := mcp_bridge_extract_string_field(line, "initial_condition"); len(name) > 0 {
		switch name {case "Pool", "pool": settings.initial_condition=.Pool; settings.initial_condition_index=1; case "Twin Drops", "twin_drops": settings.initial_condition=.Twin_Drops; settings.initial_condition_index=2; case "Empty", "empty": settings.initial_condition=.Empty; settings.initial_condition_index=3; case: settings.initial_condition=.Dam_Break; settings.initial_condition_index=0}
	}
	st_flip_validate_settings(&settings)
	cmd := Mcp_Command{kind=.Configure_ST_Flip, st_flip_settings=settings, st_flip_reset=reset, st_flip_hide_ui=hide_ui, st_flip_set_mode=set_mode}
	if !mcp_bridge_enqueue_command(bridge, cmd) do return mcp_bridge_queue_error(id, bridge)
	return mcp_bridge_tool_text(id, fmt.tprintf("{{\"ok\":true,\"queued\":\"configure_simulation\",\"mode\":\"ST_FLIP\",\"reset\":%v,\"hide_ui\":%v,\"set_mode\":%v}}", reset, hide_ui, set_mode))
}

mcp_bridge_configure_remaining_sim :: proc(id: string, bridge: ^Mcp_Bridge, kind: Remaining_Sim_Kind, line: string) -> string {
	reset, hide_ui, set_mode := mcp_bridge_capture_flags(line)
	cmd := Mcp_Command{kind = .Configure_Remaining_Sim, remaining_kind = kind, remaining_reset = reset, remaining_hide_ui = hide_ui, remaining_set_mode = set_mode}
	switch kind {
	case .Flow_Field:
		return mcp_bridge_configure_flow_field(id, bridge, line)
	case .Pellets:
		settings := pellets_settings_default()
		mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)
		if value, ok := mcp_bridge_extract_number_field(line, "particle_count"); ok {settings.particle_count = u32(max(min(value, 1000000), 1))}
		if value, ok := mcp_bridge_extract_number_field(line, "particle_size"); ok {settings.particle_size = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "collision_damping"); ok {settings.collision_damping = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "initial_velocity_max"); ok {settings.initial_velocity_max = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "initial_velocity_min"); ok {settings.initial_velocity_min = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "random_seed"); ok {settings.random_seed = u32(max(value, 0))}
		if value, ok := mcp_bridge_extract_number_field(line, "gravitational_constant"); ok {settings.gravitational_constant = value}
		if value, ok := mcp_bridge_extract_number_field(line, "energy_damping"); ok {settings.energy_damping = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "gravity_softening"); ok {settings.gravity_softening = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "density_radius"); ok {settings.density_radius = max(value, 0)}
		if value, ok := mcp_bridge_extract_bool_field(line, "trails_enabled"); ok {settings.trails_enabled = value}
		if value, ok := mcp_bridge_extract_number_field(line, "trail_fade"); ok {settings.trail_fade = max(value, 0)}
		if value, ok := mcp_bridge_extract_bool_field(line, "density_damping_enabled"); ok {settings.density_damping_enabled = value}
		if value, ok := mcp_bridge_extract_number_field(line, "overlap_resolution_strength"); ok {settings.overlap_resolution_strength = max(value, 0)}
		mcp_bridge_apply_named_index(line, "background_color_mode", VECTOR_BACKGROUND_MODE_NAMES[:], &settings.background_index)
		settings.background_color_mode = Vector_Background_Mode(settings.background_index)
		mcp_bridge_apply_named_index(line, "foreground_color_mode", PELLETS_FOREGROUND_MODE_NAMES[:], &settings.foreground_index)
		settings.foreground_color_mode = Pellets_Foreground_Mode(settings.foreground_index)
		cmd.pellets_settings = settings
	case .Voronoi_CA:
		settings := voronoi_settings_default()
		mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)
		if value, ok := mcp_bridge_extract_number_field(line, "point_count"); ok {settings.point_count = u32(max(min(value, 1000000), 1))}
		if value, ok := mcp_bridge_extract_number_field(line, "time_scale"); ok {settings.time_scale = value}
		if value, ok := mcp_bridge_extract_number_field(line, "drift"); ok {settings.drift = value}
		if value, ok := mcp_bridge_extract_number_field(line, "brownian_speed"); ok {settings.brownian_speed = value}
		if value, ok := mcp_bridge_extract_number_field(line, "random_seed"); ok {settings.random_seed = u32(max(value, 0))}
		if value, ok := mcp_bridge_extract_bool_field(line, "borders_enabled"); ok {settings.borders_enabled = value}
		if value, ok := mcp_bridge_extract_number_field(line, "border_width"); ok {settings.border_width = max(value, 0)}
		mcp_bridge_apply_named_index(line, "color_mode", VORONOI_COLOR_MODE_NAMES[:], &settings.color_mode_index)
		settings.color_mode = u32(settings.color_mode_index)
		cmd.voronoi_settings = settings
	case .Moire:
		settings := moire_settings_default()
		mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)
		if value, ok := mcp_bridge_extract_number_field(line, "speed"); ok {settings.speed = value}
		if value, ok := mcp_bridge_extract_number_field(line, "base_freq"); ok {settings.base_freq = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "moire_amount"); ok {settings.moire_amount = value}
		if value, ok := mcp_bridge_extract_number_field(line, "moire_rotation"); ok {settings.moire_rotation = value}
		if value, ok := mcp_bridge_extract_number_field(line, "moire_scale"); ok {settings.moire_scale = value}
		if value, ok := mcp_bridge_extract_number_field(line, "moire_interference"); ok {settings.moire_interference = value}
		if value, ok := mcp_bridge_extract_number_field(line, "moire_rotation3"); ok {settings.moire_rotation3 = value}
		if value, ok := mcp_bridge_extract_number_field(line, "moire_scale3"); ok {settings.moire_scale3 = value}
		if value, ok := mcp_bridge_extract_number_field(line, "moire_weight3"); ok {settings.moire_weight3 = value}
		if value, ok := mcp_bridge_extract_number_field(line, "radial_swirl_strength"); ok {settings.radial_swirl_strength = value}
		if value, ok := mcp_bridge_extract_number_field(line, "radial_starburst_count"); ok {settings.radial_starburst_count = value}
		if value, ok := mcp_bridge_extract_number_field(line, "radial_center_brightness"); ok {settings.radial_center_brightness = value}
		if value, ok := mcp_bridge_extract_number_field(line, "advect_strength"); ok {settings.advect_strength = value}
		if value, ok := mcp_bridge_extract_number_field(line, "advect_speed"); ok {settings.advect_speed = value}
		if value, ok := mcp_bridge_extract_number_field(line, "curl"); ok {settings.curl = value}
		if value, ok := mcp_bridge_extract_number_field(line, "decay"); ok {settings.decay = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "image_mode_enabled"); ok {settings.image_mode_enabled = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "image_mirror_horizontal"); ok {settings.image_mirror_horizontal = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "image_mirror_vertical"); ok {settings.image_mirror_vertical = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "image_invert_tone"); ok {settings.image_invert_tone = value}
		if path := mcp_bridge_extract_argument_string_field(line, "image_path"); len(path) > 0 {write_fixed_string(settings.image_path[:], path); settings.image_mode_enabled = true}
		mcp_bridge_apply_named_index(line, "generator_type", MOIRE_GENERATOR_TYPE_NAMES[:], &settings.generator_index)
		settings.generator_type = Moire_Generator_Type(settings.generator_index)
		mcp_bridge_apply_named_index(line, "image_fit_mode", VECTOR_IMAGE_FIT_MODE_NAMES[:], &settings.image_fit_index)
		settings.image_fit_mode = Vector_Image_Fit_Mode(settings.image_fit_index)
		mcp_bridge_apply_named_index(line, "image_interference_mode", MOIRE_INTERFERENCE_MODE_NAMES[:], &settings.interference_index)
		settings.image_interference_mode = Moire_Image_Interference_Mode(settings.interference_index)
		cmd.moire_settings = settings
	case .Vectors:
		settings := vectors_settings_default()
		mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)
		mcp_bridge_apply_noise_fields(line, &settings.noise)
		if value, ok := mcp_bridge_extract_number_field(line, "density"); ok {settings.density = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "line_length"); ok {settings.line_length = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "line_width"); ok {settings.line_width = max(value, 0)}
		if value, ok := mcp_bridge_extract_bool_field(line, "image_mirror_horizontal"); ok {settings.image_mirror_horizontal = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "image_mirror_vertical"); ok {settings.image_mirror_vertical = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "image_invert_tone"); ok {settings.image_invert_tone = value}
		if path := mcp_bridge_extract_argument_string_field(line, "image_path"); len(path) > 0 {write_fixed_string(settings.image_path[:], path); settings.vector_field_type = .Image; settings.vector_field_index = int(Vector_Field_Type.Image)}
		mcp_bridge_apply_named_index(line, "vector_field_type", VECTOR_FIELD_TYPE_NAMES[:], &settings.vector_field_index)
		settings.vector_field_type = Vector_Field_Type(settings.vector_field_index)
		mcp_bridge_apply_named_index(line, "background_color_mode", VECTOR_BACKGROUND_MODE_NAMES[:], &settings.background_index)
		settings.background_color_mode = Vector_Background_Mode(settings.background_index)
		mcp_bridge_apply_named_index(line, "image_fit_mode", VECTOR_IMAGE_FIT_MODE_NAMES[:], &settings.image_fit_index)
		settings.image_fit_mode = Vector_Image_Fit_Mode(settings.image_fit_index)
		cmd.vectors_settings = settings
	case .Primordial:
		settings := primordial_settings_default()
		mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)
		if value, ok := mcp_bridge_extract_number_field(line, "particle_count"); ok {settings.particle_count = u32(max(min(value, 1000000), 1))}
		if value, ok := mcp_bridge_extract_number_field(line, "random_seed"); ok {settings.random_seed = u32(max(value, 0))}
		if value, ok := mcp_bridge_extract_number_field(line, "alpha"); ok {settings.alpha = value}
		if value, ok := mcp_bridge_extract_number_field(line, "beta"); ok {settings.beta = value}
		if value, ok := mcp_bridge_extract_number_field(line, "velocity"); ok {settings.velocity = value}
		if value, ok := mcp_bridge_extract_number_field(line, "radius"); ok {settings.radius = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "dt"); ok {settings.dt = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "particle_size"); ok {settings.particle_size = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "density_radius"); ok {settings.density_radius = max(value, 0)}
		if value, ok := mcp_bridge_extract_bool_field(line, "traces_enabled"); ok {settings.traces_enabled = value}
		if value, ok := mcp_bridge_extract_number_field(line, "trace_fade"); ok {settings.trace_fade = max(value, 0)}
		if value, ok := mcp_bridge_extract_bool_field(line, "wrap_edges"); ok {settings.wrap_edges = value}
		mcp_bridge_apply_named_index(line, "position_generator", PRIMORDIAL_POSITION_GENERATOR_NAMES[:], &settings.position_generator_index)
		settings.position_generator = u32(settings.position_generator_index)
		mcp_bridge_apply_named_index(line, "background_color_mode", VECTOR_BACKGROUND_MODE_NAMES[:], &settings.background_index)
		settings.background_color_mode = Vector_Background_Mode(settings.background_index)
		mcp_bridge_apply_named_index(line, "foreground_color_mode", PRIMORDIAL_FOREGROUND_MODE_NAMES[:], &settings.foreground_index)
		settings.foreground_color_mode = Primordial_Foreground_Mode(settings.foreground_index)
		cmd.primordial_settings = settings
	case .Slime_Mold:
		settings := slime_settings_default()
		mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)
		if value, ok := mcp_bridge_extract_number_field(line, "agent_jitter"); ok {settings.agent_jitter = max(value, 0)}
		if value, ok := mcp_bridge_extract_bool_field(line, "isotropic_jitter"); ok {settings.isotropic_jitter = value}
		if value, ok := mcp_bridge_extract_number_field(line, "agent_heading_start"); ok {settings.agent_heading_start = value}
		if value, ok := mcp_bridge_extract_number_field(line, "agent_heading_end"); ok {settings.agent_heading_end = value}
		if value, ok := mcp_bridge_extract_number_field(line, "agent_sensor_angle"); ok {settings.agent_sensor_angle = value}
		if value, ok := mcp_bridge_extract_number_field(line, "agent_sensor_distance"); ok {settings.agent_sensor_distance = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "agent_speed_max"); ok {settings.agent_speed_max = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "agent_speed_min"); ok {settings.agent_speed_min = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "agent_turn_rate"); ok {settings.agent_turn_rate = value}
		if value, ok := mcp_bridge_extract_number_field(line, "pheromone_decay_rate"); ok {settings.pheromone_decay_rate = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "pheromone_deposition_rate"); ok {settings.pheromone_deposition_rate = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "pheromone_diffusion_rate"); ok {settings.pheromone_diffusion_rate = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "diffusion_frequency"); ok {settings.diffusion_frequency = u32(max(value, 1))}
		if value, ok := mcp_bridge_extract_number_field(line, "decay_frequency"); ok {settings.decay_frequency = u32(max(value, 1))}
		if value, ok := mcp_bridge_extract_number_field(line, "random_seed"); ok {settings.random_seed = u32(max(value, 0))}
		if value, ok := mcp_bridge_extract_number_field(line, "mask_strength"); ok {settings.mask_strength = value}
		if value, ok := mcp_bridge_extract_number_field(line, "mask_curve"); ok {settings.mask_curve = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "mask_mirror_horizontal"); ok {settings.mask_mirror_horizontal = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "mask_mirror_vertical"); ok {settings.mask_mirror_vertical = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "mask_invert_tone"); ok {settings.mask_invert_tone = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "mask_reversed"); ok {settings.mask_reversed = value}
		if path := mcp_bridge_extract_argument_string_field(line, "mask_image_path"); len(path) > 0 {write_fixed_string(settings.mask_image_path[:], path); settings.mask_pattern = .Image; settings.mask_pattern_index = int(Slime_Mask_Pattern.Image)}
		if path := mcp_bridge_extract_argument_string_field(line, "position_image_path"); len(path) > 0 {write_fixed_string(settings.position_image_path[:], path); settings.position_generator = 7; settings.position_generator_index = 7}
		mcp_bridge_apply_named_index(line, "position_generator", SLIME_POSITION_GENERATOR_NAMES[:], &settings.position_generator_index)
		settings.position_generator = u32(settings.position_generator_index)
		mcp_bridge_apply_named_index(line, "mask_pattern", SLIME_MASK_PATTERN_NAMES[:], &settings.mask_pattern_index)
		settings.mask_pattern = Slime_Mask_Pattern(settings.mask_pattern_index)
		mcp_bridge_apply_named_index(line, "mask_target", SLIME_MASK_TARGET_NAMES[:], &settings.mask_target_index)
		settings.mask_target = Slime_Mask_Target(settings.mask_target_index)
		mcp_bridge_apply_named_index(line, "mask_image_fit_mode", VECTOR_IMAGE_FIT_MODE_NAMES[:], &settings.mask_image_fit_index)
		settings.mask_image_fit_mode = Vector_Image_Fit_Mode(settings.mask_image_fit_index)
		mcp_bridge_apply_named_index(line, "position_image_fit_mode", VECTOR_IMAGE_FIT_MODE_NAMES[:], &settings.position_image_fit_index)
		settings.position_image_fit_mode = Vector_Image_Fit_Mode(settings.position_image_fit_index)
		mcp_bridge_apply_named_index(line, "background_mode", SLIME_BACKGROUND_MODE_NAMES[:], &settings.background_index)
		settings.background_mode = Slime_Background_Mode(settings.background_index)
		mcp_bridge_apply_named_index(line, "trail_map_filtering", FLOW_TRAIL_MAP_FILTERING_NAMES[:], &settings.trail_filtering_index)
		settings.trail_map_filtering = Flow_Trail_Map_Filtering(settings.trail_filtering_index)
		cmd.slime_settings = settings
	}
	if !mcp_bridge_enqueue_command(bridge, cmd) {
		return mcp_bridge_queue_error(id, bridge)
	}
	return mcp_bridge_tool_text(id, fmt.tprintf("{{\"ok\":true,\"queued\":\"configure_simulation\",\"mode\":\"%v\",\"reset\":%v,\"hide_ui\":%v,\"set_mode\":%v}}", kind, reset, hide_ui, set_mode))
}

mcp_bridge_capture_flags :: proc(line: string) -> (reset, hide_ui, set_mode: bool) {
	reset = true
	hide_ui = false
	set_mode = true
	if value, ok := mcp_bridge_extract_bool_field(line, "reset"); ok {reset = value}
	if value, ok := mcp_bridge_extract_bool_field(line, "hide_ui"); ok {hide_ui = value}
	if value, ok := mcp_bridge_extract_bool_field(line, "set_mode"); ok {set_mode = value}
	return
}

mcp_bridge_mode_name_from_configure_tool :: proc(tool_name: string) -> string {
	switch tool_name {
	case "configure_slime_mold":
		return "Slime_Mold"
	case "configure_pellets":
		return "Pellets"
	case "configure_voronoi", "configure_voronoi_ca":
		return "Voronoi_CA"
	case "configure_moire":
		return "Moire"
	case "configure_vectors":
		return "Vectors"
	case "configure_primordial":
		return "Primordial"
	case:
		return ""
	}
}

mcp_bridge_remaining_kind_from_mode :: proc(mode: App_Mode, out: ^Remaining_Sim_Kind) -> bool {
	#partial switch mode {
	case .Slime_Mold:
		out^ = .Slime_Mold
	case .Flow_Field:
		out^ = .Flow_Field
	case .Pellets:
		out^ = .Pellets
	case .Voronoi_CA:
		out^ = .Voronoi_CA
	case .Moire:
		out^ = .Moire
	case .Vectors:
		out^ = .Vectors
	case .Primordial:
		out^ = .Primordial
	case:
		return false
	}
	return true
}

mcp_bridge_apply_color_scheme_fields :: proc(line: string, color_scheme: ^Color_Scheme_Name, reversed: ^bool) {
	if name := mcp_bridge_extract_argument_string_field(line, "color_scheme"); len(name) > 0 {
		color_scheme_name_set(color_scheme, name)
	}
	if value, ok := mcp_bridge_extract_bool_field(line, "reversed"); ok {reversed^ = value}
	if value, ok := mcp_bridge_extract_bool_field(line, "color_scheme_reversed"); ok {reversed^ = value}
}

mcp_bridge_apply_named_index :: proc(line, field: string, names: []string, target: ^int) {
	if value, ok := mcp_bridge_extract_number_field(line, field); ok {
		target^ = int(max(min(value, f32(len(names) - 1)), 0))
		return
	}
	name := mcp_bridge_extract_argument_string_field(line, field)
	if len(name) == 0 {
		return
	}
	index: u32
	if mcp_bridge_named_index(name, names, &index) {
		target^ = int(index)
	}
}

mcp_bridge_apply_noise_fields :: proc(line: string, settings: ^Noise_Settings) {
	mcp_bridge_apply_named_index(line, "noise_kind", NOISE_KIND_NAMES[:], &settings.kind_index)
	settings.kind = Noise_Kind(settings.kind_index)
	mcp_bridge_apply_named_index(line, "fractal_mode", NOISE_FRACTAL_MODE_NAMES[:], &settings.fractal_mode_index)
	settings.fractal_mode = Noise_Fractal_Mode(settings.fractal_mode_index)
	mcp_bridge_apply_named_index(line, "warp_mode", NOISE_WARP_MODE_NAMES[:], &settings.warp_mode_index)
	settings.warp_mode = Noise_Warp_Mode(settings.warp_mode_index)
	if value, ok := mcp_bridge_extract_number_field(line, "seed"); ok {settings.seed = u32(max(value, 0))}
	if value, ok := mcp_bridge_extract_number_field(line, "frequency"); ok {settings.frequency = max(value, 0.000001)}
	if value, ok := mcp_bridge_extract_number_field(line, "amplitude"); ok {settings.amplitude = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "noise_strength"); ok {settings.noise_strength = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "offset_x"); ok {settings.offset_x = value}
	if value, ok := mcp_bridge_extract_number_field(line, "offset_y"); ok {settings.offset_y = value}
	if value, ok := mcp_bridge_extract_number_field(line, "rotation"); ok {settings.rotation = value}
	if value, ok := mcp_bridge_extract_number_field(line, "anchor_x"); ok {settings.anchor_x = value}
	if value, ok := mcp_bridge_extract_number_field(line, "anchor_y"); ok {settings.anchor_y = value}
	if value, ok := mcp_bridge_extract_number_field(line, "octaves"); ok {settings.octaves = u32(max(value, 1))}
	if value, ok := mcp_bridge_extract_number_field(line, "lacunarity"); ok {settings.lacunarity = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "gain"); ok {settings.gain = value}
	if value, ok := mcp_bridge_extract_number_field(line, "warp_octaves"); ok {settings.warp_octaves = u32(max(value, 1))}
	if value, ok := mcp_bridge_extract_number_field(line, "warp_amplitude"); ok {settings.warp_amplitude = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "warp_frequency"); ok {settings.warp_frequency = max(value, 0.000001)}
	noise_sync_indices(settings)
}

mcp_bridge_named_index :: proc(name: string, names: []string, out: ^u32) -> bool {
	needle := mcp_bridge_normalized_name(name)
	for candidate, index in names {
		if mcp_bridge_normalized_name(candidate) == needle {
			out^ = u32(index)
			return true
		}
	}
	return false
}

mcp_bridge_normalized_name :: proc(name: string) -> string {
	builder: strings.Builder
	strings.builder_init(&builder, context.temp_allocator)
	for ch in name {
		switch ch {
		case 'A'..='Z':
			strings.write_rune(&builder, ch + ('a' - 'A'))
		case 'a'..='z', '0'..='9':
			strings.write_rune(&builder, ch)
		case:
		}
	}
	return strings.to_string(builder)
}
