package game

import "core:fmt"
import "core:os"
import "core:strings"

settings_write_gray_scott_toml :: proc(settings: Gray_Scott_Settings, out: []u8) -> string {
	color_scheme_name := settings.color_scheme
	nutrient_image_path := settings.nutrient_image_path
	base_buf: [2048]u8
	base := fmt.bprintf(
		base_buf[:],
		"[gray_scott]\nfeed = %.6f\nkill = %.6f\ndiffusion_a = %.6f\ndiffusion_b = %.6f\ntimestep = %.6f\nsimulation_speed = %.6f\nmax_timestep = %.6f\nstability_factor = %.6f\nenable_adaptive_timestep = %v\nmask_pattern = \"%s\"\nmask_target = %d\nmask_strength = %.6f\nmask_mirror_horizontal = %v\nmask_mirror_vertical = %v\nmask_invert_tone = %v\nnutrient_image_fit_mode = \"%s\"\nnutrient_image_path = \"%s\"\ncursor_size = %.6f\ncursor_strength = %.6f\ncolor_scheme = \"%s\"\ncolor_scheme_reversed = %v\nview_mode = %d\nblur_enabled = %v\nblur_radius = %.6f\nblur_sigma = %.6f\npaused = %v\nseed_density = %.6f\nseed_amplitude = %.6f\n",
		settings.feed,
		settings.kill,
		settings.diffusion_a,
		settings.diffusion_b,
		settings.timestep,
		settings.simulation_speed,
		settings.max_timestep,
		settings.stability_factor,
		settings.enable_adaptive_timestep,
		GRAY_SCOTT_MASK_PATTERN_NAMES[int(u32(settings.mask_pattern))],
		u32(settings.mask_target),
		settings.mask_strength,
		settings.mask_mirror_horizontal,
		settings.mask_mirror_vertical,
		settings.mask_invert_tone,
		GRAY_SCOTT_IMAGE_FIT_MODE_NAMES[int(u32(settings.nutrient_image_fit_mode))],
		fixed_string(nutrient_image_path[:]),
		settings.cursor_size,
		settings.cursor_strength,
		color_scheme_name_get(&color_scheme_name),
		settings.color_scheme_reversed,
		u32(settings.view_mode),
		settings.blur_enabled,
		settings.blur_radius,
		settings.blur_sigma,
		settings.paused,
		settings.seed_density,
		settings.seed_amplitude,
	)
	noise_buf: [2048]u8
	noise := settings_write_noise_toml("gray_scott.seed_noise", settings.seed_noise, noise_buf[:])
	return fmt.bprintf(out, "%s\n%s", base, noise)
}

settings_load_gray_scott :: proc(path: string, defaults: Gray_Scott_Settings) -> (Gray_Scott_Settings, bool) {
	settings := defaults
	if !os.exists(path) {
		return settings, false
	}

	cpath, cerr := strings.clone_to_cstring(path, context.temp_allocator)
	if cerr != nil {
		return settings, false
	}
	result := toml_parse_file_ex(cpath)
	defer toml_free(result)
	if !result.ok {
		return settings, false
	}

	if v, ok := toml_f64(result.toptab, "gray_scott.feed"); ok {
		settings.feed = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "gray_scott.kill"); ok {
		settings.kill = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "gray_scott.diffusion_a"); ok {
		settings.diffusion_a = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "gray_scott.diffusion_b"); ok {
		settings.diffusion_b = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "gray_scott.timestep"); ok {
		settings.timestep = f32(v)
	} else if v, ok := toml_f64(result.toptab, "gray_scott.time_scale"); ok {
		settings.timestep = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "gray_scott.simulation_speed"); ok {
		settings.simulation_speed = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "gray_scott.max_timestep"); ok {
		settings.max_timestep = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "gray_scott.stability_factor"); ok {
		settings.stability_factor = f32(v)
	}
	if v, ok := toml_bool(result.toptab, "gray_scott.enable_adaptive_timestep"); ok {
		settings.enable_adaptive_timestep = v
	}
	if v, ok := toml_string(result.toptab, "gray_scott.mask_pattern"); ok {
		pattern: Gray_Scott_Mask_Pattern
		if gray_scott_mask_pattern_from_name(v, &pattern) {
			settings.mask_pattern = pattern
		}
	} else if v, ok := toml_i64(result.toptab, "gray_scott.mask_pattern"); ok {
		settings.mask_pattern = Gray_Scott_Mask_Pattern(u32(max(min(v, i64(len(GRAY_SCOTT_MASK_PATTERN_NAMES) - 1)), 0)))
	}
	if v, ok := toml_i64(result.toptab, "gray_scott.mask_target"); ok {
		settings.mask_target = Gray_Scott_Mask_Target(u32(max(min(v, 5), 1)))
	}
	if v, ok := toml_f64(result.toptab, "gray_scott.mask_strength"); ok {
		settings.mask_strength = f32(v)
	}
	if v, ok := toml_bool(result.toptab, "gray_scott.mask_mirror_horizontal"); ok {
		settings.mask_mirror_horizontal = v
	}
	if v, ok := toml_bool(result.toptab, "gray_scott.mask_mirror_vertical"); ok {
		settings.mask_mirror_vertical = v
	}
	if v, ok := toml_bool(result.toptab, "gray_scott.mask_invert_tone"); ok {
		settings.mask_invert_tone = v
	}
	if v, ok := toml_string(result.toptab, "gray_scott.nutrient_image_fit_mode"); ok {
		fit_mode: Gray_Scott_Image_Fit_Mode
		if gray_scott_image_fit_mode_from_name(v, &fit_mode) {
			settings.nutrient_image_fit_mode = fit_mode
		}
	} else if v, ok := toml_i64(result.toptab, "gray_scott.nutrient_image_fit_mode"); ok {
		settings.nutrient_image_fit_mode = Gray_Scott_Image_Fit_Mode(u32(max(min(v, i64(len(GRAY_SCOTT_IMAGE_FIT_MODE_NAMES) - 1)), 0)))
	}
	if v, ok := toml_string(result.toptab, "gray_scott.nutrient_image_path"); ok {
		write_fixed_string(settings.nutrient_image_path[:], v)
	}
	if v, ok := toml_f64(result.toptab, "gray_scott.cursor_size"); ok {
		settings.cursor_size = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "gray_scott.cursor_strength"); ok {
		settings.cursor_strength = f32(v)
	}
	if v, ok := toml_string(result.toptab, "gray_scott.color_scheme"); ok {
		color_scheme_name_set(&settings.color_scheme, v)
	} else if v, ok := toml_i64(result.toptab, "gray_scott.color_scheme"); ok {
		color_scheme_name_set(&settings.color_scheme, color_scheme_legacy_name(int(v)))
	}
	if v, ok := toml_bool(result.toptab, "gray_scott.color_scheme_reversed"); ok {
		settings.color_scheme_reversed = v
	}
	if v, ok := toml_i64(result.toptab, "gray_scott.view_mode"); ok {
		settings.view_mode = Gray_Scott_View_Mode(u32(max(min(v, i64(len(GRAY_SCOTT_VIEW_MODE_NAMES) - 1)), 0)))
	}
	if v, ok := toml_bool(result.toptab, "gray_scott.blur_enabled"); ok {
		settings.blur_enabled = v
	}
	if v, ok := toml_f64(result.toptab, "gray_scott.blur_radius"); ok {
		settings.blur_radius = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "gray_scott.blur_sigma"); ok {
		settings.blur_sigma = f32(v)
	}
	if v, ok := toml_bool(result.toptab, "gray_scott.paused"); ok {
		settings.paused = v
	}
	if v, ok := toml_f64(result.toptab, "gray_scott.seed_density"); ok {settings.seed_density = f32(v)}
	if v, ok := toml_f64(result.toptab, "gray_scott.seed_amplitude"); ok {settings.seed_amplitude = f32(v)}
	settings_load_noise(result, "gray_scott.seed_noise", &settings.seed_noise)

	return settings, true
}

settings_save_gray_scott :: proc(path: string, settings: Gray_Scott_Settings) -> bool {
	buf: [4096]u8
	text := settings_write_gray_scott_toml(settings, buf[:])
	return os.write_entire_file(path, text) == nil
}

settings_write_particle_life_toml :: proc(settings: Particle_Life_Settings, out: []u8) -> string {
	position_index := int(max(min(settings.position_generator, u32(len(PARTICLE_LIFE_POSITION_GENERATOR_NAMES) - 1)), 0))
	type_index := int(max(min(settings.type_generator, u32(len(PARTICLE_LIFE_TYPE_GENERATOR_NAMES) - 1)), 0))
	force_index := int(max(min(settings.force_generator, u32(len(PARTICLE_LIFE_FORCE_GENERATOR_NAMES) - 1)), 0))
	cursor := 0
	appendf :: proc(out: []u8, cursor: ^int, fmt_string: string, args: ..any) {
		if cursor^ >= len(out) {
			return
		}
		text := fmt.bprintf(out[cursor^:], fmt_string, ..args)
		cursor^ += len(text)
	}
	color_mode_index := int(max(min(u32(settings.color_mode), u32(len(PARTICLE_LIFE_COLOR_MODE_NAMES) - 1)), 0))
	background_index := int(max(min(int(settings.background_color_mode), len(VECTOR_BACKGROUND_MODE_NAMES) - 1), 0))
	color_scheme_name := settings.color_scheme
	appendf(out, &cursor, "[particle_life]\nparticle_count = %d\nspecies_count = %d\nmax_force = %.6f\nmax_distance = %.6f\nfriction = %.6f\nbeta = %.6f\nbrownian_motion = %.6f\nparticle_size = %.6f\ncursor_size = %.6f\ncursor_strength = %.6f\nposition_generator = \"%s\"\ntype_generator = \"%s\"\nforce_generator = \"%s\"\nforce_random_min = %.6f\nforce_random_max = %.6f\ncamera_x = %.6f\ncamera_y = %.6f\ncamera_zoom = %.6f\ncolor_mode = \"%s\"\ncolor_scheme = \"%s\"\ncolor_scheme_reversed = %v\nbackground_color_mode = \"%s\"\nbackground_r = %.6f\nbackground_g = %.6f\nbackground_b = %.6f\nbackground_a = %.6f\nblur_enabled = %v\nblur_radius = %.6f\nblur_sigma = %.6f\nbrightness = %.6f\ncontrast = %.6f\nsaturation = %.6f\ngamma = %.6f\ntrails_enabled = %v\ntrail_fade_amount = %.6f\ninfinite_tiles_enabled = %v\ninfinite_tile_radius = %d\nanalysis_enabled = %v\nanalysis_interval_frames = %d\nanalysis_grid_size = %d\ncoherence_threshold = %.6f\nmin_blob_area_cells = %d\nblob_overlay_enabled = %v\nforce_dense_sampling = %v\nwrap_edges = %v\npaused = %v\ncustom_force_matrix = %v\n\n[particle_life.force_matrix]\n",
		settings.particle_count,
		settings.species_count,
		settings.max_force,
		settings.max_distance,
		settings.friction,
		settings.beta,
		settings.brownian_motion,
		settings.particle_size,
		settings.cursor_size,
		settings.cursor_strength,
		PARTICLE_LIFE_POSITION_GENERATOR_NAMES[position_index],
		PARTICLE_LIFE_TYPE_GENERATOR_NAMES[type_index],
		PARTICLE_LIFE_FORCE_GENERATOR_NAMES[force_index],
		settings.force_random_min,
		settings.force_random_max,
		settings.camera_x,
		settings.camera_y,
		max(settings.camera_zoom, 0.25),
		PARTICLE_LIFE_COLOR_MODE_NAMES[color_mode_index],
		color_scheme_name_get(&color_scheme_name),
		settings.color_scheme_reversed,
		VECTOR_BACKGROUND_MODE_NAMES[background_index],
		settings.background_color[0],
		settings.background_color[1],
		settings.background_color[2],
		settings.background_color[3],
		settings.post_processing.blur_enabled,
		settings.post_processing.blur_radius,
		settings.post_processing.blur_sigma,
		settings.brightness,
		settings.contrast,
		settings.saturation,
		settings.gamma,
		settings.trails_enabled,
		settings.trail_fade_amount,
		settings.infinite_tiles_enabled,
		settings.infinite_tile_radius,
		settings.analysis_enabled,
		settings.analysis_interval_frames,
		settings.analysis_grid_size,
		settings.coherence_threshold,
		settings.min_blob_area_cells,
		settings.blob_overlay_enabled,
		settings.force_dense_sampling,
		settings.wrap_edges,
		settings.paused,
		settings.custom_force_matrix,
	)
	species_count := int(max(min(settings.species_count, PARTICLE_LIFE_MAX_SPECIES), 1))
	for a in 0 ..< species_count {
		for b in 0 ..< species_count {
			appendf(out, &cursor, "f%d_%d = %.6f\n", a, b, settings.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b])
		}
	}
	return string(out[:min(cursor, len(out))])
}

particle_life_position_generator_from_name :: proc(name: string, out: ^u32) -> bool {
	for option, i in PARTICLE_LIFE_POSITION_GENERATOR_NAMES {
		if name == option {
			out^ = u32(i)
			return true
		}
	}
	return false
}

particle_life_type_generator_from_name :: proc(name: string, out: ^u32) -> bool {
	for option, i in PARTICLE_LIFE_TYPE_GENERATOR_NAMES {
		if name == option {
			out^ = u32(i)
			return true
		}
	}
	return false
}

particle_life_force_generator_from_name :: proc(name: string, out: ^u32) -> bool {
	for option, i in PARTICLE_LIFE_FORCE_GENERATOR_NAMES {
		if name == option {
			out^ = u32(i)
			return true
		}
	}
	return false
}

particle_life_color_mode_from_name :: proc(name: string, out: ^Particle_Life_Color_Mode) -> bool {
	for option, i in PARTICLE_LIFE_COLOR_MODE_NAMES {
		if name == option {
			out^ = Particle_Life_Color_Mode(u32(i))
			return true
		}
	}
	return false
}

settings_load_particle_life :: proc(path: string, defaults: Particle_Life_Settings) -> (Particle_Life_Settings, bool) {
	settings := defaults
	if !os.exists(path) {
		return settings, false
	}

	cpath, cerr := strings.clone_to_cstring(path, context.temp_allocator)
	if cerr != nil {
		return settings, false
	}
	result := toml_parse_file_ex(cpath)
	defer toml_free(result)
	if !result.ok {
		return settings, false
	}

	if v, ok := toml_i64(result.toptab, "particle_life.particle_count"); ok {
		settings.particle_count = u32(max(min(v, i64(PARTICLE_LIFE_MAX_PARTICLE_COUNT)), 1))
	}
	if v, ok := toml_i64(result.toptab, "particle_life.species_count"); ok {
		settings.species_count = u32(max(min(v, i64(PARTICLE_LIFE_MAX_SPECIES)), 1))
	}
	if v, ok := toml_f64(result.toptab, "particle_life.max_force"); ok {
		settings.max_force = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.max_distance"); ok {
		settings.max_distance = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.friction"); ok {
		settings.friction = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.beta"); ok {
		settings.beta = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.brownian_motion"); ok {
		settings.brownian_motion = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.particle_size"); ok {
		settings.particle_size = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.cursor_size"); ok {
		settings.cursor_size = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.cursor_strength"); ok {
		settings.cursor_strength = f32(v)
	}
	if v, ok := toml_string(result.toptab, "particle_life.position_generator"); ok {
		_ = particle_life_position_generator_from_name(v, &settings.position_generator)
	} else if v, ok := toml_i64(result.toptab, "particle_life.position_generator"); ok {
		settings.position_generator = u32(max(min(v, i64(len(PARTICLE_LIFE_POSITION_GENERATOR_NAMES) - 1)), 0))
	}
	if v, ok := toml_string(result.toptab, "particle_life.type_generator"); ok {
		_ = particle_life_type_generator_from_name(v, &settings.type_generator)
	} else if v, ok := toml_i64(result.toptab, "particle_life.type_generator"); ok {
		settings.type_generator = u32(max(min(v, i64(len(PARTICLE_LIFE_TYPE_GENERATOR_NAMES) - 1)), 0))
	}
	if v, ok := toml_string(result.toptab, "particle_life.force_generator"); ok {
		_ = particle_life_force_generator_from_name(v, &settings.force_generator)
	} else if v, ok := toml_i64(result.toptab, "particle_life.force_generator"); ok {
		settings.force_generator = u32(max(min(v, i64(len(PARTICLE_LIFE_FORCE_GENERATOR_NAMES) - 1)), 0))
	}
	if v, ok := toml_f64(result.toptab, "particle_life.force_random_min"); ok {
		settings.force_random_min = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.force_random_max"); ok {
		settings.force_random_max = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.camera_x"); ok {
		settings.camera_x = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.camera_y"); ok {
		settings.camera_y = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.camera_zoom"); ok {
		settings.camera_zoom = f32(max(v, 0.25))
	}
	if v, ok := toml_string(result.toptab, "particle_life.color_mode"); ok {
		_ = particle_life_color_mode_from_name(v, &settings.color_mode)
	} else if v, ok := toml_i64(result.toptab, "particle_life.color_mode"); ok {
		settings.color_mode = Particle_Life_Color_Mode(u32(max(min(v, i64(len(PARTICLE_LIFE_COLOR_MODE_NAMES) - 1)), 0)))
	}
	if v, ok := toml_string(result.toptab, "particle_life.color_scheme"); ok {
		color_scheme_name_set(&settings.color_scheme, v)
	}
	if v, ok := toml_bool(result.toptab, "particle_life.color_scheme_reversed"); ok {
		settings.color_scheme_reversed = v
	}
	if v, ok := toml_string(result.toptab, "particle_life.background_color_mode"); ok {
		value: Vector_Background_Mode
		if vector_background_mode_from_name(v, &value) {
			settings.background_color_mode = value
			settings.background_index = int(value)
		}
	} else if v, ok := toml_i64(result.toptab, "particle_life.background_color_mode"); ok {
		value := max(min(v, i64(len(VECTOR_BACKGROUND_MODE_NAMES) - 1)), 0)
		settings.background_color_mode = Vector_Background_Mode(value)
		settings.background_index = int(value)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.background_r"); ok {
		settings.background_color[0] = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.background_g"); ok {
		settings.background_color[1] = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.background_b"); ok {
		settings.background_color[2] = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.background_a"); ok {
		settings.background_color[3] = f32(v)
	}
	if v, ok := toml_bool(result.toptab, "particle_life.blur_enabled"); ok {
		settings.post_processing.blur_enabled = v
	}
	if v, ok := toml_f64(result.toptab, "particle_life.blur_radius"); ok {
		settings.post_processing.blur_radius = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.blur_sigma"); ok {
		settings.post_processing.blur_sigma = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.brightness"); ok {
		settings.brightness = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.contrast"); ok {
		settings.contrast = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.saturation"); ok {
		settings.saturation = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "particle_life.gamma"); ok {
		settings.gamma = f32(max(v, 0.01))
	}
	if v, ok := toml_bool(result.toptab, "particle_life.trails_enabled"); ok {
		settings.trails_enabled = v
	}
	if v, ok := toml_f64(result.toptab, "particle_life.trail_fade_amount"); ok {
		settings.trail_fade_amount = f32(max(min(v, 1.0), 0.0))
	}
	if v, ok := toml_bool(result.toptab, "particle_life.infinite_tiles_enabled"); ok {
		settings.infinite_tiles_enabled = v
	}
	if v, ok := toml_i64(result.toptab, "particle_life.infinite_tile_radius"); ok {
		settings.infinite_tile_radius = u32(max(min(v, 32), 0))
	}
	if v, ok := toml_bool(result.toptab, "particle_life.analysis_enabled"); ok {
		settings.analysis_enabled = v
	}
	if v, ok := toml_i64(result.toptab, "particle_life.analysis_interval_frames"); ok {
		settings.analysis_interval_frames = u32(max(min(v, 120), 1))
	}
	if v, ok := toml_i64(result.toptab, "particle_life.analysis_grid_size"); ok {
		settings.analysis_grid_size = u32(max(min(v, 1024), 16))
	}
	if v, ok := toml_f64(result.toptab, "particle_life.coherence_threshold"); ok {
		settings.coherence_threshold = f32(max(min(v, 1.0), 0.0))
	}
	if v, ok := toml_i64(result.toptab, "particle_life.min_blob_area_cells"); ok {
		settings.min_blob_area_cells = u32(max(min(v, 100000), 1))
	}
	if v, ok := toml_bool(result.toptab, "particle_life.blob_overlay_enabled"); ok {
		settings.blob_overlay_enabled = v
	}
	if v, ok := toml_bool(result.toptab, "particle_life.force_dense_sampling"); ok {
		settings.force_dense_sampling = v
	}
	if v, ok := toml_bool(result.toptab, "particle_life.wrap_edges"); ok {
		settings.wrap_edges = v
	}
	if v, ok := toml_bool(result.toptab, "particle_life.paused"); ok {
		settings.paused = v
	}
	if v, ok := toml_bool(result.toptab, "particle_life.custom_force_matrix"); ok {
		settings.custom_force_matrix = v
	}
	for a in 0 ..< PARTICLE_LIFE_MAX_SPECIES {
		for b in 0 ..< PARTICLE_LIFE_MAX_SPECIES {
			key := fmt.tprintf("particle_life.force_matrix.f%d_%d", a, b)
			if v, ok := toml_f64(result.toptab, key); ok {
				settings.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = f32(v)
				settings.custom_force_matrix = true
			}
		}
	}
	return settings, true
}

settings_save_particle_life :: proc(path: string, settings: Particle_Life_Settings) -> bool {
	buf: [8192]u8
	text := settings_write_particle_life_toml(settings, buf[:])
	return os.write_entire_file(path, text) == nil
}
