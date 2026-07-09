package game

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

Toml_Type :: enum i32 {
	UNKNOWN  = 0,
	STRING   = 1,
	INT64    = 2,
	FP64     = 3,
	BOOLEAN  = 4,
	DATE     = 5,
	TIME     = 6,
	DATETIME = 7,
	DATETIMETZ = 8,
	ARRAY    = 9,
	TABLE    = 10,
}

Toml_String :: struct {
	ptr: cstring,
	len: i32,
}

Toml_Timestamp :: struct {
	year, month, day: i16,
	hour, minute, second: i16,
	usec: i32,
	tz: i16,
}

Toml_Array :: struct {
	size: i32,
	elem: ^Toml_Datum,
}

Toml_Table :: struct {
	size: i32,
	key: ^^u8,
	len: ^i32,
	value: ^Toml_Datum,
}

Toml_Value :: struct #raw_union {
	s: cstring,
	str: Toml_String,
	int64: i64,
	fp64: f64,
	boolean: bool,
	ts: Toml_Timestamp,
	arr: Toml_Array,
	tab: Toml_Table,
}

Toml_Datum :: struct {
	type: Toml_Type,
	flag: u32,
	lineno: i32,
	colno: i32,
	source: cstring,
	u: Toml_Value,
}

Toml_Result :: struct {
	ok: bool,
	toptab: Toml_Datum,
	errmsg: [200]u8,
	internal: rawptr,
}

foreign import tomlc17 "../../third_party/tomlc17/src/libtomlc17.a"

@(default_calling_convention = "c")
foreign tomlc17 {
	toml_parse_file_ex :: proc(fname: cstring) -> Toml_Result ---
	toml_free :: proc(result: Toml_Result) ---
	toml_seek :: proc(table: Toml_Datum, multipart_key: cstring) -> Toml_Datum ---
}

App_Settings :: struct {
	ui_scale: f32,
	default_fps_limit: i32,
	default_fps_limit_enabled: bool,
	window_width: i32,
	window_height: i32,
	window_maximized: bool,
	auto_hide_ui: bool,
	auto_hide_delay: i32,
	menu_position: string,
	experimental_controller_ui: bool,
	default_camera_sensitivity: f32,
	texture_filtering: string,
	gpu_memory_ceiling_fraction: f32,
	preset_directory: string,
	steam_enabled: bool,
	steam_app_id: u32,
	steam_restart_if_necessary: bool,
	steam_library_path: string,
}

settings_default :: proc() -> App_Settings {
	return {
		ui_scale = 1.0,
		default_fps_limit = 60,
		default_fps_limit_enabled = false,
		window_width = 1920,
		window_height = 1080,
		window_maximized = true,
		auto_hide_ui = true,
		auto_hide_delay = 3000,
		menu_position = "middle",
		experimental_controller_ui = true,
		default_camera_sensitivity = 1.0,
		texture_filtering = "Linear",
		gpu_memory_ceiling_fraction = 0,
		preset_directory = "presets",
		steam_enabled = STEAM_DEFAULT_ENABLED,
		steam_app_id = STEAM_DEFAULT_APP_ID,
		steam_restart_if_necessary = STEAM_DEFAULT_RESTART_IF_NECESSARY,
		steam_library_path = "",
	}
}

settings_toml_parser_name :: proc() -> string {
	return "tomlc17"
}

settings_app_config_path :: proc() -> string {
	when ODIN_OS == .Windows {
		buf: [1024]u8
		local_app_data := os.get_env_buf(buf[:], "LOCALAPPDATA")
		if len(local_app_data) > 0 {
			return fmt.tprintf("%s/VizzaOdin/config/app.toml", local_app_data)
		}
	}
	return "config/app.toml"
}

settings_load_app :: proc(path: string) -> (App_Settings, bool) {
	settings := settings_default()
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

	if v, ok := toml_i64(result.toptab, "window.width"); ok {
		settings.window_width = i32(v)
	}
	if v, ok := toml_i64(result.toptab, "window.height"); ok {
		settings.window_height = i32(v)
	}
	if v, ok := toml_bool(result.toptab, "window.maximized"); ok {
		settings.window_maximized = v
	}
	if v, ok := toml_bool(result.toptab, "display.fps_limit_enabled"); ok {
		settings.default_fps_limit_enabled = v
	}
	if v, ok := toml_i64(result.toptab, "display.fps_limit"); ok {
		settings.default_fps_limit = i32(v)
	}
	if v, ok := toml_f64(result.toptab, "display.ui_scale"); ok {
		settings.ui_scale = f32(v)
	}
	if v, ok := toml_string(result.toptab, "display.texture_filtering"); ok {
		cloned, aerr := strings.clone(v)
		if aerr == nil {
			settings.texture_filtering = cloned
		}
	}
	if v, ok := toml_bool(result.toptab, "ui.auto_hide"); ok {
		settings.auto_hide_ui = v
	}
	if v, ok := toml_i64(result.toptab, "ui.auto_hide_delay"); ok {
		settings.auto_hide_delay = i32(v)
	}
	if v, ok := toml_string(result.toptab, "ui.menu_position"); ok {
		cloned, aerr := strings.clone(v)
		if aerr == nil {
			settings.menu_position = cloned
		}
	}
	if v, ok := toml_bool(result.toptab, "ui.experimental_controller_ui"); ok {
		settings.experimental_controller_ui = v
	}
	if v, ok := toml_f64(result.toptab, "camera.default_sensitivity"); ok {
		settings.default_camera_sensitivity = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "gpu.memory_ceiling_fraction"); ok {
		settings.gpu_memory_ceiling_fraction = f32(v)
	}
	if v, ok := toml_string(result.toptab, "presets.directory"); ok {
		cloned, aerr := strings.clone(v)
		if aerr == nil {
			settings.preset_directory = cloned
		}
	}
	if v, ok := toml_bool(result.toptab, "steam.enabled"); ok {
		settings.steam_enabled = v
	}
	if v, ok := toml_i64(result.toptab, "steam.app_id"); ok {
		settings.steam_app_id = u32(max(min(v, 4294967295), 0))
	}
	if v, ok := toml_bool(result.toptab, "steam.restart_if_necessary"); ok {
		settings.steam_restart_if_necessary = v
	}
	if v, ok := toml_string(result.toptab, "steam.library_path"); ok {
		cloned, aerr := strings.clone(v)
		if aerr == nil {
			settings.steam_library_path = cloned
		}
	}
	return settings, true
}

settings_save_app :: proc(path: string, settings: App_Settings) -> bool {
	dir, _ := filepath.split(path)
	if len(dir) > 0 {
		_ = os.make_directory_all(dir)
	}
	buf: [1024]u8
	text := fmt.bprintf(
		buf[:],
		"[display]\nfps_limit_enabled = %v\nfps_limit = %d\nui_scale = %.2f\ntexture_filtering = \"%s\"\n\n[window]\nwidth = %d\nheight = %d\nmaximized = %v\n\n[ui]\nauto_hide = %v\nauto_hide_delay = %d\nmenu_position = \"%s\"\nexperimental_controller_ui = %v\n\n[camera]\ndefault_sensitivity = %.2f\n\n[gpu]\nmemory_ceiling_fraction = %.3f\n\n[presets]\ndirectory = \"%s\"\n\n[steam]\nenabled = %v\napp_id = %d\nrestart_if_necessary = %v\nlibrary_path = \"%s\"\n",
		settings.default_fps_limit_enabled,
		settings.default_fps_limit,
		settings.ui_scale,
		settings.texture_filtering,
		settings.window_width,
		settings.window_height,
		settings.window_maximized,
		settings.auto_hide_ui,
		settings.auto_hide_delay,
		settings.menu_position,
		settings.experimental_controller_ui,
		settings.default_camera_sensitivity,
		settings.gpu_memory_ceiling_fraction,
		settings.preset_directory,
		settings.steam_enabled,
		settings.steam_app_id,
		settings.steam_restart_if_necessary,
		settings.steam_library_path,
	)
	return os.write_entire_file(path, text) == nil
}

settings_write_gray_scott_toml :: proc(settings: Gray_Scott_Settings, out: []u8) -> string {
	color_scheme_name := settings.color_scheme
	nutrient_image_path := settings.nutrient_image_path
	return fmt.bprintf(
		out,
		"[gray_scott]\nfeed = %.6f\nkill = %.6f\ndiffusion_a = %.6f\ndiffusion_b = %.6f\ntimestep = %.6f\nsimulation_speed = %.6f\nmax_timestep = %.6f\nstability_factor = %.6f\nenable_adaptive_timestep = %v\nmask_pattern = \"%s\"\nmask_target = %d\nmask_strength = %.6f\nmask_mirror_horizontal = %v\nmask_mirror_vertical = %v\nmask_invert_tone = %v\nnutrient_image_fit_mode = \"%s\"\nnutrient_image_path = \"%s\"\ncursor_size = %.6f\ncursor_strength = %.6f\ncolor_scheme = \"%s\"\ncolor_scheme_reversed = %v\nblur_enabled = %v\nblur_radius = %.6f\nblur_sigma = %.6f\npaused = %v\n",
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
		settings.blur_enabled,
		settings.blur_radius,
		settings.blur_sigma,
		settings.paused,
	)
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

	return settings, true
}

settings_save_gray_scott :: proc(path: string, settings: Gray_Scott_Settings) -> bool {
	buf: [1024]u8
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
	appendf(out, &cursor, "[particle_life]\nparticle_count = %d\nspecies_count = %d\nmax_force = %.6f\nmax_distance = %.6f\nfriction = %.6f\nbeta = %.6f\nbrownian_motion = %.6f\nparticle_size = %.6f\ncursor_size = %.6f\ncursor_strength = %.6f\nposition_generator = \"%s\"\ntype_generator = \"%s\"\nforce_generator = \"%s\"\nforce_random_min = %.6f\nforce_random_max = %.6f\ncamera_x = %.6f\ncamera_y = %.6f\ncamera_zoom = %.6f\ncolor_mode = \"%s\"\ncolor_scheme = \"%s\"\ncolor_scheme_reversed = %v\nbackground_color_mode = \"%s\"\nbackground_r = %.6f\nbackground_g = %.6f\nbackground_b = %.6f\nbackground_a = %.6f\nblur_enabled = %v\nblur_radius = %.6f\nblur_sigma = %.6f\nbrightness = %.6f\ncontrast = %.6f\nsaturation = %.6f\ngamma = %.6f\ntrails_enabled = %v\ntrail_fade_amount = %.6f\ninfinite_tiles_enabled = %v\ninfinite_tile_radius = %d\nanalysis_enabled = %v\nanalysis_interval_frames = %d\nanalysis_grid_size = %d\ncoherence_threshold = %.6f\nmin_blob_area_cells = %d\nblob_overlay_enabled = %v\nwrap_edges = %v\npaused = %v\ncustom_force_matrix = %v\n\n[particle_life.force_matrix]\n",
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

settings_write_primordial_toml :: proc(settings: Primordial_Settings, out: []u8) -> string {
	color_scheme := settings.color_scheme
	return fmt.bprintf(out, "[primordial]\ncolor_scheme = \"%s\"\ncolor_scheme_reversed = %v\nblur_enabled = %v\nblur_radius = %.6f\nblur_sigma = %.6f\nparticle_count = %d\nrandom_seed = %d\nposition_generator = \"%s\"\nalpha = %.6f\nbeta = %.6f\nvelocity = %.6f\nradius = %.6f\ndt = %.6f\nparticle_size = %.6f\ndensity_radius = %.6f\nbackground_color_mode = \"%s\"\nforeground_color_mode = \"%s\"\ntraces_enabled = %v\ntrace_fade = %.6f\nwrap_edges = %v\n",
		color_scheme_name_get(&color_scheme), settings.color_scheme_reversed, settings.post_processing.blur_enabled, settings.post_processing.blur_radius, settings.post_processing.blur_sigma, settings.particle_count, settings.random_seed, PRIMORDIAL_POSITION_GENERATOR_NAMES[settings.position_generator_index], settings.alpha, settings.beta, settings.velocity, settings.radius, settings.dt, settings.particle_size, settings.density_radius, VECTOR_BACKGROUND_MODE_NAMES[settings.background_index], PRIMORDIAL_FOREGROUND_MODE_NAMES[settings.foreground_index], settings.traces_enabled, settings.trace_fade, settings.wrap_edges)
}

settings_save_primordial :: proc(path: string, settings: Primordial_Settings) -> bool {
	buf: [4096]u8
	return os.write_entire_file(path, settings_write_primordial_toml(settings, buf[:])) == nil
}

settings_load_primordial :: proc(path: string, defaults: Primordial_Settings) -> (Primordial_Settings, bool) {
	settings := defaults
	if !os.exists(path) {return settings, false}
	cpath, cerr := strings.clone_to_cstring(path, context.temp_allocator)
	if cerr != nil {return settings, false}
	result := toml_parse_file_ex(cpath)
	defer toml_free(result)
	if !result.ok {return settings, false}
	if v, ok := toml_string(result.toptab, "primordial.color_scheme"); ok {color_scheme_name_set(&settings.color_scheme, v)}
	if v, ok := toml_bool(result.toptab, "primordial.color_scheme_reversed"); ok {settings.color_scheme_reversed = v}
	if v, ok := toml_bool(result.toptab, "primordial.blur_enabled"); ok {settings.post_processing.blur_enabled = v}
	if v, ok := toml_f64(result.toptab, "primordial.blur_radius"); ok {settings.post_processing.blur_radius = f32(v)}
	if v, ok := toml_f64(result.toptab, "primordial.blur_sigma"); ok {settings.post_processing.blur_sigma = f32(v)}
	if v, ok := toml_i64(result.toptab, "primordial.particle_count"); ok {settings.particle_count = u32(max(v, 1))}
	if v, ok := toml_i64(result.toptab, "primordial.random_seed"); ok {settings.random_seed = u32(max(v, 0))}
	if v, ok := toml_string(result.toptab, "primordial.position_generator"); ok {value: u32; if primordial_position_generator_from_name(v, &value) {settings.position_generator = value; settings.position_generator_index = int(value)}}
	if v, ok := toml_f64(result.toptab, "primordial.alpha"); ok {settings.alpha = f32(v)}
	if v, ok := toml_f64(result.toptab, "primordial.beta"); ok {settings.beta = f32(v)}
	if v, ok := toml_f64(result.toptab, "primordial.velocity"); ok {settings.velocity = f32(v)}
	if v, ok := toml_f64(result.toptab, "primordial.radius"); ok {settings.radius = f32(v)}
	if v, ok := toml_f64(result.toptab, "primordial.dt"); ok {settings.dt = f32(v)}
	if v, ok := toml_f64(result.toptab, "primordial.particle_size"); ok {settings.particle_size = f32(v)}
	if v, ok := toml_f64(result.toptab, "primordial.density_radius"); ok {settings.density_radius = f32(v)}
	if v, ok := toml_string(result.toptab, "primordial.background_color_mode"); ok {value: Vector_Background_Mode; if vector_background_mode_from_name(v, &value) {settings.background_color_mode = value; settings.background_index = int(value)}}
	if v, ok := toml_string(result.toptab, "primordial.foreground_color_mode"); ok {value: Primordial_Foreground_Mode; if primordial_foreground_mode_from_name(v, &value) {settings.foreground_color_mode = value; settings.foreground_index = int(value)}}
	if v, ok := toml_bool(result.toptab, "primordial.traces_enabled"); ok {settings.traces_enabled = v}
	if v, ok := toml_f64(result.toptab, "primordial.trace_fade"); ok {settings.trace_fade = f32(v)}
	if v, ok := toml_bool(result.toptab, "primordial.wrap_edges"); ok {settings.wrap_edges = v}
	return settings, true
}

settings_write_voronoi_toml :: proc(settings: Voronoi_Settings, out: []u8) -> string {
	color_scheme := settings.color_scheme
	color_mode_index := max(min(settings.color_mode_index, len(VORONOI_COLOR_MODE_NAMES) - 1), 0)
	return fmt.bprintf(out, "[voronoi]\ncolor_scheme = \"%s\"\ncolor_scheme_reversed = %v\nblur_enabled = %v\nblur_radius = %.6f\nblur_sigma = %.6f\npoint_count = %d\ntime_scale = %.6f\ndrift = %.6f\nbrownian_speed = %.6f\nrandom_seed = %d\nborders_enabled = %v\nborder_width = %.6f\ncolor_mode = \"%s\"\n",
		color_scheme_name_get(&color_scheme), settings.color_scheme_reversed, settings.post_processing.blur_enabled, settings.post_processing.blur_radius, settings.post_processing.blur_sigma, settings.point_count, settings.time_scale, settings.drift, settings.brownian_speed, settings.random_seed, settings.borders_enabled, settings.border_width, VORONOI_COLOR_MODE_NAMES[color_mode_index])
}

settings_save_voronoi :: proc(path: string, settings: Voronoi_Settings) -> bool {
	buf: [4096]u8
	return os.write_entire_file(path, settings_write_voronoi_toml(settings, buf[:])) == nil
}

settings_load_voronoi :: proc(path: string, defaults: Voronoi_Settings) -> (Voronoi_Settings, bool) {
	settings := defaults
	if !os.exists(path) {return settings, false}
	cpath, cerr := strings.clone_to_cstring(path, context.temp_allocator)
	if cerr != nil {return settings, false}
	result := toml_parse_file_ex(cpath)
	defer toml_free(result)
	if !result.ok {return settings, false}
	if v, ok := toml_string(result.toptab, "voronoi.color_scheme"); ok {color_scheme_name_set(&settings.color_scheme, v)}
	if v, ok := toml_bool(result.toptab, "voronoi.color_scheme_reversed"); ok {settings.color_scheme_reversed = v}
	if v, ok := toml_bool(result.toptab, "voronoi.blur_enabled"); ok {settings.post_processing.blur_enabled = v}
	if v, ok := toml_f64(result.toptab, "voronoi.blur_radius"); ok {settings.post_processing.blur_radius = f32(v)}
	if v, ok := toml_f64(result.toptab, "voronoi.blur_sigma"); ok {settings.post_processing.blur_sigma = f32(v)}
	if v, ok := toml_i64(result.toptab, "voronoi.point_count"); ok {settings.point_count = u32(max(v, 1))}
	if v, ok := toml_i64(result.toptab, "voronoi.num_points"); ok {settings.point_count = u32(max(v, 1))}
	if v, ok := toml_f64(result.toptab, "voronoi.time_scale"); ok {settings.time_scale = f32(v)}
	if v, ok := toml_f64(result.toptab, "voronoi.drift"); ok {settings.drift = f32(v)}
	if v, ok := toml_f64(result.toptab, "voronoi.brownian_speed"); ok {settings.brownian_speed = f32(v)}
	if v, ok := toml_i64(result.toptab, "voronoi.random_seed"); ok {settings.random_seed = u32(max(v, 0))}
	if v, ok := toml_bool(result.toptab, "voronoi.borders_enabled"); ok {settings.borders_enabled = v}
	if v, ok := toml_f64(result.toptab, "voronoi.border_width"); ok {settings.border_width = f32(v)}
	if v, ok := toml_string(result.toptab, "voronoi.color_mode"); ok {value: u32; if voronoi_color_mode_from_name(v, &value) {settings.color_mode = value; settings.color_mode_index = int(value)}} else if v, ok := toml_i64(result.toptab, "voronoi.color_mode"); ok {settings.color_mode = u32(max(min(v, i64(len(VORONOI_COLOR_MODE_NAMES) - 1)), 0)); settings.color_mode_index = int(settings.color_mode)}
	return settings, true
}

settings_write_pellets_toml :: proc(settings: Pellets_Settings, out: []u8) -> string {
	color_scheme := settings.color_scheme
	return fmt.bprintf(out, "[pellets]\ncolor_scheme = \"%s\"\ncolor_scheme_reversed = %v\nblur_enabled = %v\nblur_radius = %.6f\nblur_sigma = %.6f\nparticle_count = %d\nparticle_size = %.6f\ncollision_damping = %.6f\ninitial_velocity_max = %.6f\ninitial_velocity_min = %.6f\nrandom_seed = %d\nbackground_color_mode = \"%s\"\ngravity_constant = %.9f\nenergy_damping = %.6f\ngravity_softening = %.6f\ndensity_radius = %.6f\nforeground_color_mode = \"%s\"\ntrails_enabled = %v\ntrail_fade = %.6f\ndensity_damping_enabled = %v\noverlap_resolution_strength = %.6f\n",
		color_scheme_name_get(&color_scheme), settings.color_scheme_reversed, settings.post_processing.blur_enabled, settings.post_processing.blur_radius, settings.post_processing.blur_sigma, settings.particle_count, settings.particle_size, settings.collision_damping, settings.initial_velocity_max, settings.initial_velocity_min, settings.random_seed, VECTOR_BACKGROUND_MODE_NAMES[settings.background_index], settings.gravitational_constant, settings.energy_damping, settings.gravity_softening, settings.density_radius, PELLETS_FOREGROUND_MODE_NAMES[settings.foreground_index], settings.trails_enabled, settings.trail_fade, settings.density_damping_enabled, settings.overlap_resolution_strength)
}

settings_save_pellets :: proc(path: string, settings: Pellets_Settings) -> bool {
	buf: [4096]u8
	return os.write_entire_file(path, settings_write_pellets_toml(settings, buf[:])) == nil
}

settings_load_pellets :: proc(path: string, defaults: Pellets_Settings) -> (Pellets_Settings, bool) {
	settings := defaults
	if !os.exists(path) {return settings, false}
	cpath, cerr := strings.clone_to_cstring(path, context.temp_allocator)
	if cerr != nil {return settings, false}
	result := toml_parse_file_ex(cpath)
	defer toml_free(result)
	if !result.ok {return settings, false}
	if v, ok := toml_string(result.toptab, "pellets.color_scheme"); ok {color_scheme_name_set(&settings.color_scheme, v)}
	if v, ok := toml_bool(result.toptab, "pellets.color_scheme_reversed"); ok {settings.color_scheme_reversed = v}
	if v, ok := toml_bool(result.toptab, "pellets.blur_enabled"); ok {settings.post_processing.blur_enabled = v}
	if v, ok := toml_f64(result.toptab, "pellets.blur_radius"); ok {settings.post_processing.blur_radius = f32(v)}
	if v, ok := toml_f64(result.toptab, "pellets.blur_sigma"); ok {settings.post_processing.blur_sigma = f32(v)}
	if v, ok := toml_i64(result.toptab, "pellets.particle_count"); ok {settings.particle_count = u32(max(v, 1))}
	if v, ok := toml_f64(result.toptab, "pellets.particle_size"); ok {settings.particle_size = f32(v)}
	if v, ok := toml_f64(result.toptab, "pellets.collision_damping"); ok {settings.collision_damping = f32(v)}
	if v, ok := toml_f64(result.toptab, "pellets.initial_velocity_max"); ok {settings.initial_velocity_max = f32(v)}
	if v, ok := toml_f64(result.toptab, "pellets.initial_velocity_min"); ok {settings.initial_velocity_min = f32(v)}
	if v, ok := toml_i64(result.toptab, "pellets.random_seed"); ok {settings.random_seed = u32(max(v, 0))}
	if v, ok := toml_string(result.toptab, "pellets.background_color_mode"); ok {value: Vector_Background_Mode; if vector_background_mode_from_name(v, &value) {settings.background_color_mode = value; settings.background_index = int(value)}}
	if v, ok := toml_f64(result.toptab, "pellets.gravity_constant"); ok {settings.gravitational_constant = f32(v)}
	if v, ok := toml_f64(result.toptab, "pellets.energy_damping"); ok {settings.energy_damping = f32(v)}
	if v, ok := toml_f64(result.toptab, "pellets.gravity_softening"); ok {settings.gravity_softening = f32(v)}
	if v, ok := toml_f64(result.toptab, "pellets.density_radius"); ok {settings.density_radius = f32(v)}
	if v, ok := toml_string(result.toptab, "pellets.foreground_color_mode"); ok {value: Pellets_Foreground_Mode; if pellets_foreground_mode_from_name(v, &value) {settings.foreground_color_mode = value; settings.foreground_index = int(value)}}
	if v, ok := toml_bool(result.toptab, "pellets.trails_enabled"); ok {settings.trails_enabled = v}
	if v, ok := toml_f64(result.toptab, "pellets.trail_fade"); ok {settings.trail_fade = f32(v)}
	if v, ok := toml_bool(result.toptab, "pellets.density_damping_enabled"); ok {settings.density_damping_enabled = v}
	if v, ok := toml_f64(result.toptab, "pellets.overlap_resolution_strength"); ok {settings.overlap_resolution_strength = f32(v)}
	return settings, true
}

settings_write_slime_toml :: proc(settings: Slime_Settings, out: []u8) -> string {
	color_scheme := settings.color_scheme
	mask_image_path := settings.mask_image_path
	position_image_path := settings.position_image_path
	return fmt.bprintf(out, "[slime]\ncolor_scheme = \"%s\"\ncolor_scheme_reversed = %v\nblur_enabled = %v\nblur_radius = %.6f\nblur_sigma = %.6f\nagent_jitter = %.6f\nagent_heading_start = %.6f\nagent_heading_end = %.6f\nagent_sensor_angle = %.6f\nagent_sensor_distance = %.6f\nagent_speed_max = %.6f\nagent_speed_min = %.6f\nagent_turn_rate = %.6f\npheromone_decay_rate = %.6f\npheromone_deposition_rate = %.6f\npheromone_diffusion_rate = %.6f\ndiffusion_frequency = %d\ndecay_frequency = %d\nrandom_seed = %d\nposition_generator = \"%s\"\nposition_image_fit_mode = \"%s\"\nposition_image_path = \"%s\"\nmask_pattern = \"%s\"\nmask_target = \"%s\"\nmask_strength = %.6f\nmask_curve = %.6f\nmask_image_fit_mode = \"%s\"\nmask_image_path = \"%s\"\nmask_mirror_horizontal = %v\nmask_mirror_vertical = %v\nmask_invert_tone = %v\nmask_reversed = %v\ntrail_map_filtering = \"%s\"\nbackground_mode = \"%s\"\n",
		color_scheme_name_get(&color_scheme), settings.color_scheme_reversed, settings.post_processing.blur_enabled, settings.post_processing.blur_radius, settings.post_processing.blur_sigma, settings.agent_jitter, settings.agent_heading_start, settings.agent_heading_end, settings.agent_sensor_angle, settings.agent_sensor_distance, settings.agent_speed_max, settings.agent_speed_min, settings.agent_turn_rate, settings.pheromone_decay_rate, settings.pheromone_deposition_rate, settings.pheromone_diffusion_rate, settings.diffusion_frequency, settings.decay_frequency, settings.random_seed, SLIME_POSITION_GENERATOR_NAMES[settings.position_generator_index], VECTOR_IMAGE_FIT_MODE_NAMES[settings.position_image_fit_index], fixed_string(position_image_path[:]), SLIME_MASK_PATTERN_NAMES[settings.mask_pattern_index], SLIME_MASK_TARGET_NAMES[settings.mask_target_index], settings.mask_strength, settings.mask_curve, VECTOR_IMAGE_FIT_MODE_NAMES[settings.mask_image_fit_index], fixed_string(mask_image_path[:]), settings.mask_mirror_horizontal, settings.mask_mirror_vertical, settings.mask_invert_tone, settings.mask_reversed, FLOW_TRAIL_MAP_FILTERING_NAMES[settings.trail_filtering_index], SLIME_BACKGROUND_MODE_NAMES[settings.background_index])
}

settings_save_slime :: proc(path: string, settings: Slime_Settings) -> bool {
	buf: [4096]u8
	return os.write_entire_file(path, settings_write_slime_toml(settings, buf[:])) == nil
}

settings_load_slime :: proc(path: string, defaults: Slime_Settings) -> (Slime_Settings, bool) {
	settings := defaults
	if !os.exists(path) {return settings, false}
	cpath, cerr := strings.clone_to_cstring(path, context.temp_allocator)
	if cerr != nil {return settings, false}
	result := toml_parse_file_ex(cpath)
	defer toml_free(result)
	if !result.ok {return settings, false}
	if v, ok := toml_string(result.toptab, "slime.color_scheme"); ok {color_scheme_name_set(&settings.color_scheme, v)}
	if v, ok := toml_bool(result.toptab, "slime.color_scheme_reversed"); ok {settings.color_scheme_reversed = v}
	if v, ok := toml_bool(result.toptab, "slime.blur_enabled"); ok {settings.post_processing.blur_enabled = v}
	if v, ok := toml_f64(result.toptab, "slime.blur_radius"); ok {settings.post_processing.blur_radius = f32(v)}
	if v, ok := toml_f64(result.toptab, "slime.blur_sigma"); ok {settings.post_processing.blur_sigma = f32(v)}
	if v, ok := toml_f64(result.toptab, "slime.agent_jitter"); ok {settings.agent_jitter = f32(v)}
	if v, ok := toml_f64(result.toptab, "slime.agent_heading_start"); ok {settings.agent_heading_start = f32(v)}
	if v, ok := toml_f64(result.toptab, "slime.agent_heading_end"); ok {settings.agent_heading_end = f32(v)}
	if v, ok := toml_f64(result.toptab, "slime.agent_sensor_angle"); ok {settings.agent_sensor_angle = f32(v)}
	if v, ok := toml_f64(result.toptab, "slime.agent_sensor_distance"); ok {settings.agent_sensor_distance = f32(v)}
	if v, ok := toml_f64(result.toptab, "slime.agent_speed_max"); ok {settings.agent_speed_max = f32(v)}
	if v, ok := toml_f64(result.toptab, "slime.agent_speed_min"); ok {settings.agent_speed_min = f32(v)}
	if v, ok := toml_f64(result.toptab, "slime.agent_turn_rate"); ok {settings.agent_turn_rate = f32(v)}
	if v, ok := toml_f64(result.toptab, "slime.pheromone_decay_rate"); ok {settings.pheromone_decay_rate = f32(v)}
	if v, ok := toml_f64(result.toptab, "slime.pheromone_deposition_rate"); ok {settings.pheromone_deposition_rate = f32(v)}
	if v, ok := toml_f64(result.toptab, "slime.pheromone_diffusion_rate"); ok {settings.pheromone_diffusion_rate = f32(v)}
	if v, ok := toml_i64(result.toptab, "slime.diffusion_frequency"); ok {settings.diffusion_frequency = u32(max(v, 1))}
	if v, ok := toml_i64(result.toptab, "slime.decay_frequency"); ok {settings.decay_frequency = u32(max(v, 1))}
	if v, ok := toml_i64(result.toptab, "slime.random_seed"); ok {settings.random_seed = u32(max(v, 0))}
	if v, ok := toml_string(result.toptab, "slime.position_generator"); ok {value: u32; if slime_position_generator_from_name(v, &value) {settings.position_generator = value; settings.position_generator_index = int(value)}}
	if v, ok := toml_string(result.toptab, "slime.position_image_fit_mode"); ok {value: Vector_Image_Fit_Mode; if vector_image_fit_mode_from_name(v, &value) {settings.position_image_fit_mode = value; settings.position_image_fit_index = int(value)}}
	if v, ok := toml_string(result.toptab, "slime.position_image_path"); ok {write_fixed_string(settings.position_image_path[:], v)}
	if v, ok := toml_string(result.toptab, "slime.mask_pattern"); ok {value: Slime_Mask_Pattern; if slime_mask_pattern_from_name(v, &value) {settings.mask_pattern = value; settings.mask_pattern_index = int(value)}}
	if v, ok := toml_string(result.toptab, "slime.mask_target"); ok {value: Slime_Mask_Target; if slime_mask_target_from_name(v, &value) {settings.mask_target = value; settings.mask_target_index = int(value)}}
	if v, ok := toml_f64(result.toptab, "slime.mask_strength"); ok {settings.mask_strength = f32(v)}
	if v, ok := toml_f64(result.toptab, "slime.mask_curve"); ok {settings.mask_curve = f32(v)}
	if v, ok := toml_string(result.toptab, "slime.mask_image_fit_mode"); ok {value: Vector_Image_Fit_Mode; if vector_image_fit_mode_from_name(v, &value) {settings.mask_image_fit_mode = value; settings.mask_image_fit_index = int(value)}}
	if v, ok := toml_string(result.toptab, "slime.mask_image_path"); ok {write_fixed_string(settings.mask_image_path[:], v)}
	if v, ok := toml_bool(result.toptab, "slime.mask_mirror_horizontal"); ok {settings.mask_mirror_horizontal = v}
	if v, ok := toml_bool(result.toptab, "slime.mask_mirror_vertical"); ok {settings.mask_mirror_vertical = v}
	if v, ok := toml_bool(result.toptab, "slime.mask_invert_tone"); ok {settings.mask_invert_tone = v}
	if v, ok := toml_bool(result.toptab, "slime.mask_reversed"); ok {settings.mask_reversed = v}
	if v, ok := toml_string(result.toptab, "slime.trail_map_filtering"); ok {value: Flow_Trail_Map_Filtering; if flow_trail_map_filtering_from_name(v, &value) {settings.trail_map_filtering = value; settings.trail_filtering_index = int(value)}}
	if v, ok := toml_string(result.toptab, "slime.background_mode"); ok {value: Slime_Background_Mode; if slime_background_mode_from_name(v, &value) {settings.background_mode = value; settings.background_index = int(value)}}
	return settings, true
}

settings_write_noise_toml :: proc(table_name: string, settings: Noise_Settings, out: []u8) -> string {
	noise := settings
	noise_sync_indices(&noise)
	return fmt.bprintf(out,
		"[%s]\nkind = \"%s\"\nseed = %d\nnoise_strength = %.6f\namplitude = %.6f\nfrequency = %.6f\noffset_x = %.6f\noffset_y = %.6f\nrotation = %.6f\nanchor_x = %.6f\nanchor_y = %.6f\nfractal_mode = \"%s\"\noctaves = %d\nlacunarity = %.6f\ngain = %.6f\nwarp_mode = \"%s\"\nwarp_octaves = %d\nwarp_amplitude = %.6f\nwarp_frequency = %.6f\ngabor_iterations = %d\ngabor_velocity = %.6f\ngabor_band_width = %.6f\ngabor_band_softness = %.6f\nphasor_iterations = %d\nphasor_velocity = %.6f\nphasor_band_width = %.6f\ncellular_output = \"%s\"\ncellular_distance_mode = \"%s\"\nwave_velocity = %.6f\nwave_band_width = %.6f\nwave_band_softness = %.6f\n",
		table_name,
		NOISE_KIND_NAMES[noise.kind_index],
		noise.seed,
		noise.noise_strength,
		noise.amplitude,
		noise.frequency,
		noise.offset_x,
		noise.offset_y,
		noise.rotation,
		noise.anchor_x,
		noise.anchor_y,
		NOISE_FRACTAL_MODE_NAMES[noise.fractal_mode_index],
		noise.octaves,
		noise.lacunarity,
		noise.gain,
		NOISE_WARP_MODE_NAMES[noise.warp_mode_index],
		noise.warp_octaves,
		noise.warp_amplitude,
		noise.warp_frequency,
		noise.gabor.iterations,
		noise.gabor.velocity,
		noise.gabor.band_width,
		noise.gabor.band_softness,
		noise.phasor.iterations,
		noise.phasor.velocity,
		noise.phasor.band_width,
		NOISE_CELLULAR_OUTPUT_NAMES[noise.voronoi.output_index],
		NOISE_CELLULAR_DISTANCE_MODE_NAMES[noise.voronoi.distance_mode_index],
		noise.wave.velocity,
		noise.wave.band_width,
		noise.wave.band_softness,
	)
}

settings_load_noise :: proc(result: Toml_Result, prefix: string, settings: ^Noise_Settings) {
	if v, ok := toml_string(result.toptab, fmt.tprintf("%s.kind", prefix)); ok {kind: Noise_Kind; if noise_kind_from_name(v, &kind) {settings.kind = kind}}
	if v, ok := toml_i64(result.toptab, fmt.tprintf("%s.seed", prefix)); ok {settings.seed = u32(max(v, 0))}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.noise_strength", prefix)); ok {settings.noise_strength = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.amplitude", prefix)); ok {settings.amplitude = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.frequency", prefix)); ok {settings.frequency = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.offset_x", prefix)); ok {settings.offset_x = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.offset_y", prefix)); ok {settings.offset_y = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.rotation", prefix)); ok {settings.rotation = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.anchor_x", prefix)); ok {settings.anchor_x = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.anchor_y", prefix)); ok {settings.anchor_y = f32(v)}
	if v, ok := toml_string(result.toptab, fmt.tprintf("%s.fractal_mode", prefix)); ok {mode: Noise_Fractal_Mode; if noise_fractal_mode_from_name(v, &mode) {settings.fractal_mode = mode}}
	if v, ok := toml_i64(result.toptab, fmt.tprintf("%s.octaves", prefix)); ok {settings.octaves = u32(max(v, 1))}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.lacunarity", prefix)); ok {settings.lacunarity = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.gain", prefix)); ok {settings.gain = f32(v)}
	if v, ok := toml_string(result.toptab, fmt.tprintf("%s.warp_mode", prefix)); ok {mode: Noise_Warp_Mode; if noise_warp_mode_from_name(v, &mode) {settings.warp_mode = mode}}
	if v, ok := toml_i64(result.toptab, fmt.tprintf("%s.warp_octaves", prefix)); ok {settings.warp_octaves = u32(max(v, 1))}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.warp_amplitude", prefix)); ok {settings.warp_amplitude = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.warp_frequency", prefix)); ok {settings.warp_frequency = f32(v)}
	if v, ok := toml_i64(result.toptab, fmt.tprintf("%s.gabor_iterations", prefix)); ok {settings.gabor.iterations = u32(max(v, 1))}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.gabor_velocity", prefix)); ok {settings.gabor.velocity = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.gabor_band_width", prefix)); ok {settings.gabor.band_width = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.gabor_band_softness", prefix)); ok {settings.gabor.band_softness = f32(v)}
	if v, ok := toml_i64(result.toptab, fmt.tprintf("%s.phasor_iterations", prefix)); ok {settings.phasor.iterations = u32(max(v, 1))}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.phasor_velocity", prefix)); ok {settings.phasor.velocity = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.phasor_band_width", prefix)); ok {settings.phasor.band_width = f32(v)}
	if v, ok := toml_string(result.toptab, fmt.tprintf("%s.cellular_output", prefix)); ok {output: Noise_Cellular_Output; if noise_cellular_output_from_name(v, &output) {settings.voronoi.output = output}}
	if v, ok := toml_string(result.toptab, fmt.tprintf("%s.cellular_distance_mode", prefix)); ok {mode: Noise_Cellular_Distance_Mode; if noise_cellular_distance_mode_from_name(v, &mode) {settings.voronoi.distance_mode = mode}}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.wave_velocity", prefix)); ok {settings.wave.velocity = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.wave_band_width", prefix)); ok {settings.wave.band_width = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.wave_band_softness", prefix)); ok {settings.wave.band_softness = f32(v)}
	noise_sync_indices(settings)
}

settings_migrate_legacy_noise :: proc(result: Toml_Result, prefix: string, settings: ^Noise_Settings) {
	if v, ok := toml_string(result.toptab, fmt.tprintf("%s.noise_type", prefix)); ok {
		fractal := settings.fractal_mode
		kind: Noise_Kind
		if noise_kind_from_legacy_name(v, &kind, &fractal) {
			settings.kind = kind
			settings.fractal_mode = fractal
		}
	}
	if v, ok := toml_i64(result.toptab, fmt.tprintf("%s.noise_seed", prefix)); ok {settings.seed = u32(max(v, 0))}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.noise_scale", prefix)); ok {settings.frequency = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.noise_x", prefix)); ok {settings.offset_x = f32(v)}
	if v, ok := toml_f64(result.toptab, fmt.tprintf("%s.noise_y", prefix)); ok {settings.offset_y = f32(v)}
	noise_sync_indices(settings)
}

settings_write_flow_toml :: proc(settings: Flow_Settings, out: []u8) -> string {
	image_path := settings.image_path
	color_scheme := settings.color_scheme
	noise := settings.noise
	noise_sync_indices(&noise)
	noise_buf: [4096]u8
	noise_text := settings_write_noise_toml("flow.noise", noise, noise_buf[:])
	return fmt.bprintf(out, "[flow]\ncolor_scheme = \"%s\"\ncolor_scheme_reversed = %v\nblur_enabled = %v\nblur_radius = %.6f\nblur_sigma = %.6f\nvector_field_type = \"%s\"\nvector_magnitude = %.6f\nimage_fit_mode = \"%s\"\nimage_path = \"%s\"\nimage_mirror_horizontal = %v\nimage_mirror_vertical = %v\nimage_invert_tone = %v\ntotal_pool_size = %d\nparticle_lifetime = %.6f\nparticle_speed = %.6f\nparticle_size = %d\nparticle_shape = \"%s\"\nparticle_autospawn = %v\nshow_particles = %v\nautospawn_rate = %d\nbrush_spawn_rate = %d\nforeground_color_mode = \"%s\"\nbackground_color_mode = \"%s\"\ntrail_decay_rate = %.6f\ntrail_deposition_rate = %.6f\ntrail_diffusion_rate = %.6f\ntrail_wash_out_rate = %.6f\ntrail_map_filtering = \"%s\"\n\n%s",
		color_scheme_name_get(&color_scheme),
		settings.color_scheme_reversed,
		settings.post_processing.blur_enabled,
		settings.post_processing.blur_radius,
		settings.post_processing.blur_sigma,
		VECTOR_FIELD_TYPE_NAMES[settings.vector_field_index],
		settings.vector_magnitude,
		VECTOR_IMAGE_FIT_MODE_NAMES[settings.image_fit_index],
		fixed_string(image_path[:]),
		settings.image_mirror_horizontal,
		settings.image_mirror_vertical,
		settings.image_invert_tone,
		settings.total_pool_size,
		settings.particle_lifetime,
		settings.particle_speed,
		settings.particle_size,
		FLOW_PARTICLE_SHAPE_NAMES[settings.shape_index],
		settings.particle_autospawn,
		settings.show_particles,
		settings.autospawn_rate,
		settings.brush_spawn_rate,
		FLOW_FOREGROUND_MODE_NAMES[settings.foreground_index],
		VECTOR_BACKGROUND_MODE_NAMES[settings.background_index],
		settings.trail_decay_rate,
		settings.trail_deposition_rate,
		settings.trail_diffusion_rate,
		settings.trail_wash_out_rate,
		FLOW_TRAIL_MAP_FILTERING_NAMES[settings.trail_filtering_index],
		noise_text)
}

settings_save_flow :: proc(path: string, settings: Flow_Settings) -> bool {
	buf: [8192]u8
	return os.write_entire_file(path, settings_write_flow_toml(settings, buf[:])) == nil
}

settings_load_flow :: proc(path: string, defaults: Flow_Settings) -> (Flow_Settings, bool) {
	settings := defaults
	if !os.exists(path) {return settings, false}
	cpath, cerr := strings.clone_to_cstring(path, context.temp_allocator)
	if cerr != nil {return settings, false}
	result := toml_parse_file_ex(cpath)
	defer toml_free(result)
	if !result.ok {return settings, false}
	if v, ok := toml_string(result.toptab, "flow.color_scheme"); ok {color_scheme_name_set(&settings.color_scheme, v)}
	if v, ok := toml_bool(result.toptab, "flow.color_scheme_reversed"); ok {settings.color_scheme_reversed = v}
	if v, ok := toml_bool(result.toptab, "flow.blur_enabled"); ok {settings.post_processing.blur_enabled = v}
	if v, ok := toml_f64(result.toptab, "flow.blur_radius"); ok {settings.post_processing.blur_radius = f32(v)}
	if v, ok := toml_f64(result.toptab, "flow.blur_sigma"); ok {settings.post_processing.blur_sigma = f32(v)}
	if v, ok := toml_string(result.toptab, "flow.vector_field_type"); ok {value: Vector_Field_Type; if vector_field_type_from_name(v, &value) {settings.vector_field_type = value; settings.vector_field_index = int(value)}}
	if _, nested_noise_ok := toml_string(result.toptab, "flow.noise.kind"); nested_noise_ok {
		settings_load_noise(result, "flow.noise", &settings.noise)
	} else {
		settings_migrate_legacy_noise(result, "flow", &settings.noise)
	}
	if v, ok := toml_f64(result.toptab, "flow.vector_magnitude"); ok {settings.vector_magnitude = f32(v)}
	if v, ok := toml_string(result.toptab, "flow.image_fit_mode"); ok {value: Vector_Image_Fit_Mode; if vector_image_fit_mode_from_name(v, &value) {settings.image_fit_mode = value; settings.image_fit_index = int(value)}}
	if v, ok := toml_string(result.toptab, "flow.image_path"); ok {write_fixed_string(settings.image_path[:], v)}
	if v, ok := toml_bool(result.toptab, "flow.image_mirror_horizontal"); ok {settings.image_mirror_horizontal = v}
	if v, ok := toml_bool(result.toptab, "flow.image_mirror_vertical"); ok {settings.image_mirror_vertical = v}
	if v, ok := toml_bool(result.toptab, "flow.image_invert_tone"); ok {settings.image_invert_tone = v}
	if v, ok := toml_i64(result.toptab, "flow.total_pool_size"); ok {settings.total_pool_size = u32(max(v, 1))}
	if v, ok := toml_f64(result.toptab, "flow.particle_lifetime"); ok {settings.particle_lifetime = f32(v)}
	if v, ok := toml_f64(result.toptab, "flow.particle_speed"); ok {settings.particle_speed = f32(v)}
	if v, ok := toml_i64(result.toptab, "flow.particle_size"); ok {settings.particle_size = u32(max(v, 1))}
	if v, ok := toml_string(result.toptab, "flow.particle_shape"); ok {value: Flow_Particle_Shape; if flow_particle_shape_from_name(v, &value) {settings.particle_shape = value; settings.shape_index = int(value)}}
	if v, ok := toml_bool(result.toptab, "flow.particle_autospawn"); ok {settings.particle_autospawn = v}
	if v, ok := toml_bool(result.toptab, "flow.show_particles"); ok {settings.show_particles = v}
	if v, ok := toml_i64(result.toptab, "flow.autospawn_rate"); ok {settings.autospawn_rate = u32(max(v, 0))}
	if v, ok := toml_i64(result.toptab, "flow.brush_spawn_rate"); ok {settings.brush_spawn_rate = u32(max(v, 0))}
	if v, ok := toml_string(result.toptab, "flow.foreground_color_mode"); ok {value: Flow_Foreground_Mode; if flow_foreground_mode_from_name(v, &value) {settings.foreground_color_mode = value; settings.foreground_index = int(value)}}
	if v, ok := toml_string(result.toptab, "flow.background_color_mode"); ok {value: Vector_Background_Mode; if vector_background_mode_from_name(v, &value) {settings.background_color_mode = value; settings.background_index = int(value)}}
	if v, ok := toml_f64(result.toptab, "flow.trail_decay_rate"); ok {settings.trail_decay_rate = f32(v)}
	if v, ok := toml_f64(result.toptab, "flow.trail_deposition_rate"); ok {settings.trail_deposition_rate = f32(v)}
	if v, ok := toml_f64(result.toptab, "flow.trail_diffusion_rate"); ok {settings.trail_diffusion_rate = f32(v)}
	if v, ok := toml_f64(result.toptab, "flow.trail_wash_out_rate"); ok {settings.trail_wash_out_rate = f32(v)}
	if v, ok := toml_string(result.toptab, "flow.trail_map_filtering"); ok {value: Flow_Trail_Map_Filtering; if flow_trail_map_filtering_from_name(v, &value) {settings.trail_map_filtering = value; settings.trail_filtering_index = int(value)}}
	return settings, true
}

settings_write_vectors_toml :: proc(settings: Vectors_Settings, out: []u8) -> string {
	color_scheme := settings.color_scheme
	image_path := settings.image_path
	noise := settings.noise
	noise_sync_indices(&noise)
	noise_buf: [4096]u8
	noise_text := settings_write_noise_toml("vectors.noise", noise, noise_buf[:])
	return fmt.bprintf(out, "[vectors]\nvector_field_type = \"%s\"\ndensity = %.6f\nline_length = %.6f\nline_width = %.6f\nbackground_color_mode = \"%s\"\nimage_fit_mode = \"%s\"\nimage_path = \"%s\"\nimage_mirror_horizontal = %v\nimage_mirror_vertical = %v\nimage_invert_tone = %v\ncolor_scheme = \"%s\"\ncolor_scheme_reversed = %v\n\n%s",
		VECTOR_FIELD_TYPE_NAMES[settings.vector_field_index], settings.density, settings.line_length, settings.line_width, VECTOR_BACKGROUND_MODE_NAMES[settings.background_index], VECTOR_IMAGE_FIT_MODE_NAMES[settings.image_fit_index], fixed_string(image_path[:]), settings.image_mirror_horizontal, settings.image_mirror_vertical, settings.image_invert_tone, color_scheme_name_get(&color_scheme), settings.color_scheme_reversed, noise_text)
}

settings_save_vectors :: proc(path: string, settings: Vectors_Settings) -> bool {
	buf: [8192]u8
	return os.write_entire_file(path, settings_write_vectors_toml(settings, buf[:])) == nil
}

settings_load_vectors :: proc(path: string, defaults: Vectors_Settings) -> (Vectors_Settings, bool) {
	settings := defaults
	if !os.exists(path) {return settings, false}
	cpath, cerr := strings.clone_to_cstring(path, context.temp_allocator)
	if cerr != nil {return settings, false}
	result := toml_parse_file_ex(cpath)
	defer toml_free(result)
	if !result.ok {return settings, false}
	if v, ok := toml_string(result.toptab, "vectors.vector_field_type"); ok {value: Vector_Field_Type; if vector_field_type_from_name(v, &value) {settings.vector_field_type = value; settings.vector_field_index = int(value)}}
	if v, ok := toml_string(result.toptab, "vectors.image_fit_mode"); ok {value: Vector_Image_Fit_Mode; if vector_image_fit_mode_from_name(v, &value) {settings.image_fit_mode = value; settings.image_fit_index = int(value)}}
	if v, ok := toml_string(result.toptab, "vectors.image_path"); ok {write_fixed_string(settings.image_path[:], v)}
	if v, ok := toml_bool(result.toptab, "vectors.image_mirror_horizontal"); ok {settings.image_mirror_horizontal = v}
	if v, ok := toml_bool(result.toptab, "vectors.image_mirror_vertical"); ok {settings.image_mirror_vertical = v}
	if v, ok := toml_bool(result.toptab, "vectors.image_invert_tone"); ok {settings.image_invert_tone = v}
	if v, ok := toml_string(result.toptab, "vectors.color_scheme"); ok {color_scheme_name_set(&settings.color_scheme, v)}
	if v, ok := toml_bool(result.toptab, "vectors.color_scheme_reversed"); ok {settings.color_scheme_reversed = v}
	if _, nested_noise_ok := toml_string(result.toptab, "vectors.noise.kind"); nested_noise_ok {
		settings_load_noise(result, "vectors.noise", &settings.noise)
	} else {
		settings_migrate_legacy_noise(result, "vectors", &settings.noise)
	}
	if v, ok := toml_f64(result.toptab, "vectors.density"); ok {settings.density = f32(v)}
	if v, ok := toml_f64(result.toptab, "vectors.line_length"); ok {settings.line_length = f32(v)}
	if v, ok := toml_f64(result.toptab, "vectors.line_width"); ok {settings.line_width = f32(v)}
	if v, ok := toml_string(result.toptab, "vectors.background_color_mode"); ok {value: Vector_Background_Mode; if vector_background_mode_from_name(v, &value) {settings.background_color_mode = value; settings.background_index = int(value)}}
	return settings, true
}

settings_write_moire_toml :: proc(settings: Moire_Settings, out: []u8) -> string {
	image_path := settings.image_path
	color_scheme := settings.color_scheme
	return fmt.bprintf(out, "[moire]\nspeed = %.6f\ngenerator_type = \"%s\"\nbase_freq = %.6f\nmoire_amount = %.6f\nmoire_rotation = %.6f\nmoire_scale = %.6f\nmoire_interference = %.6f\nmoire_rotation3 = %.6f\nmoire_scale3 = %.6f\nmoire_weight3 = %.6f\nradial_swirl_strength = %.6f\nradial_starburst_count = %.6f\nradial_center_brightness = %.6f\nadvect_strength = %.6f\nadvect_speed = %.6f\ncurl = %.6f\ndecay = %.6f\nimage_mode_enabled = %v\nimage_fit_mode = \"%s\"\nimage_path = \"%s\"\nimage_mirror_horizontal = %v\nimage_mirror_vertical = %v\nimage_invert_tone = %v\nimage_interference_mode = \"%s\"\ncolor_scheme = \"%s\"\ncolor_scheme_reversed = %v\n",
		settings.speed, MOIRE_GENERATOR_TYPE_NAMES[settings.generator_index], settings.base_freq, settings.moire_amount, settings.moire_rotation, settings.moire_scale, settings.moire_interference, settings.moire_rotation3, settings.moire_scale3, settings.moire_weight3, settings.radial_swirl_strength, settings.radial_starburst_count, settings.radial_center_brightness, settings.advect_strength, settings.advect_speed, settings.curl, settings.decay, settings.image_mode_enabled, VECTOR_IMAGE_FIT_MODE_NAMES[settings.image_fit_index], fixed_string(image_path[:]), settings.image_mirror_horizontal, settings.image_mirror_vertical, settings.image_invert_tone, MOIRE_INTERFERENCE_MODE_NAMES[settings.interference_index], color_scheme_name_get(&color_scheme), settings.color_scheme_reversed)
}

settings_save_moire :: proc(path: string, settings: Moire_Settings) -> bool {
	buf: [4096]u8
	return os.write_entire_file(path, settings_write_moire_toml(settings, buf[:])) == nil
}

settings_load_moire :: proc(path: string, defaults: Moire_Settings) -> (Moire_Settings, bool) {
	settings := defaults
	if !os.exists(path) {return settings, false}
	cpath, cerr := strings.clone_to_cstring(path, context.temp_allocator)
	if cerr != nil {return settings, false}
	result := toml_parse_file_ex(cpath)
	defer toml_free(result)
	if !result.ok {return settings, false}
	if v, ok := toml_f64(result.toptab, "moire.speed"); ok {settings.speed = f32(v)}
	if v, ok := toml_string(result.toptab, "moire.generator_type"); ok {for i in 0 ..< len(MOIRE_GENERATOR_TYPE_NAMES) {if v == MOIRE_GENERATOR_TYPE_NAMES[i] {settings.generator_type = Moire_Generator_Type(i); settings.generator_index = i; break}}}
	if v, ok := toml_f64(result.toptab, "moire.base_freq"); ok {settings.base_freq = f32(v)}
	if v, ok := toml_f64(result.toptab, "moire.moire_amount"); ok {settings.moire_amount = f32(v)}
	if v, ok := toml_f64(result.toptab, "moire.moire_rotation"); ok {settings.moire_rotation = f32(v)}
	if v, ok := toml_f64(result.toptab, "moire.moire_scale"); ok {settings.moire_scale = f32(v)}
	if v, ok := toml_f64(result.toptab, "moire.moire_interference"); ok {settings.moire_interference = f32(v)}
	if v, ok := toml_f64(result.toptab, "moire.moire_rotation3"); ok {settings.moire_rotation3 = f32(v)}
	if v, ok := toml_f64(result.toptab, "moire.moire_scale3"); ok {settings.moire_scale3 = f32(v)}
	if v, ok := toml_f64(result.toptab, "moire.moire_weight3"); ok {settings.moire_weight3 = f32(v)}
	if v, ok := toml_f64(result.toptab, "moire.radial_swirl_strength"); ok {settings.radial_swirl_strength = f32(v)}
	if v, ok := toml_f64(result.toptab, "moire.radial_starburst_count"); ok {settings.radial_starburst_count = f32(v)}
	if v, ok := toml_f64(result.toptab, "moire.radial_center_brightness"); ok {settings.radial_center_brightness = f32(v)}
	if v, ok := toml_f64(result.toptab, "moire.advect_strength"); ok {settings.advect_strength = f32(v)}
	if v, ok := toml_f64(result.toptab, "moire.advect_speed"); ok {settings.advect_speed = f32(v)}
	if v, ok := toml_f64(result.toptab, "moire.curl"); ok {settings.curl = f32(v)}
	if v, ok := toml_f64(result.toptab, "moire.decay"); ok {settings.decay = f32(v)}
	if v, ok := toml_bool(result.toptab, "moire.image_mode_enabled"); ok {settings.image_mode_enabled = v}
	if v, ok := toml_string(result.toptab, "moire.image_fit_mode"); ok {value: Vector_Image_Fit_Mode; if vector_image_fit_mode_from_name(v, &value) {settings.image_fit_mode = value; settings.image_fit_index = int(value)}}
	if v, ok := toml_string(result.toptab, "moire.image_path"); ok {write_fixed_string(settings.image_path[:], v)}
	if v, ok := toml_bool(result.toptab, "moire.image_mirror_horizontal"); ok {settings.image_mirror_horizontal = v}
	if v, ok := toml_bool(result.toptab, "moire.image_mirror_vertical"); ok {settings.image_mirror_vertical = v}
	if v, ok := toml_bool(result.toptab, "moire.image_invert_tone"); ok {settings.image_invert_tone = v}
	if v, ok := toml_string(result.toptab, "moire.image_interference_mode"); ok {for i in 0 ..< len(MOIRE_INTERFERENCE_MODE_NAMES) {if v == MOIRE_INTERFERENCE_MODE_NAMES[i] {settings.image_interference_mode = Moire_Image_Interference_Mode(i); settings.interference_index = i; break}}}
	if v, ok := toml_string(result.toptab, "moire.color_scheme"); ok {color_scheme_name_set(&settings.color_scheme, v)}
	if v, ok := toml_bool(result.toptab, "moire.color_scheme_reversed"); ok {settings.color_scheme_reversed = v}
	return settings, true
}

toml_seek_key :: proc(table: Toml_Datum, key: string) -> Toml_Datum {
	ckey, cerr := strings.clone_to_cstring(key, context.temp_allocator)
	if cerr != nil {
		return {}
	}
	return toml_seek(table, ckey)
}

toml_i64 :: proc(table: Toml_Datum, key: string) -> (i64, bool) {
	datum := toml_seek_key(table, key)
	if datum.type == .INT64 {
		return datum.u.int64, true
	}
	return 0, false
}

toml_f64 :: proc(table: Toml_Datum, key: string) -> (f64, bool) {
	datum := toml_seek_key(table, key)
	#partial switch datum.type {
	case .FP64:
		return datum.u.fp64, true
	case .INT64:
		return f64(datum.u.int64), true
	}
	return 0, false
}

toml_bool :: proc(table: Toml_Datum, key: string) -> (bool, bool) {
	datum := toml_seek_key(table, key)
	if datum.type == .BOOLEAN {
		return datum.u.boolean, true
	}
	return false, false
}

toml_string :: proc(table: Toml_Datum, key: string) -> (string, bool) {
	datum := toml_seek_key(table, key)
	if datum.type != .STRING || datum.u.str.ptr == nil {
		return "", false
	}
	return strings.string_from_ptr(cast(^byte)datum.u.str.ptr, int(datum.u.str.len)), true
}
