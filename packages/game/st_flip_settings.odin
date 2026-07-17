package game

import "core:fmt"
import "core:os"
import "core:strings"

settings_write_st_flip_toml :: proc(settings: ST_Flip_Settings, out: []u8) -> string {
	color := settings.color_scheme
	return fmt.bprintf(out, "[st_flip]\ncolor_scheme = \"%s\"\ncolor_scheme_reversed = %v\nblur_enabled = %v\nblur_radius = %.6f\nblur_sigma = %.6f\nparticle_count = %d\ngrid_height = %d\ntarget_cfl = %.6f\nsimulation_speed = %.6f\ngravity = %.6f\nflip_ratio = %.6f\njitter_strength = %.6f\nphase_steepness = %.6f\nink_dissipation = %.6f\npressure_iterations = %d\nrender_smoothing = %.6f\nrandom_seed = %d\ninitial_condition = \"%s\"\npaused = %v\n",
		color_scheme_name_get(&color), settings.color_scheme_reversed,
		settings.post_processing.blur_enabled, settings.post_processing.blur_radius, settings.post_processing.blur_sigma,
		settings.particle_count, settings.grid_height, settings.target_cfl, settings.simulation_speed, settings.gravity,
		settings.flip_ratio, settings.jitter_strength, settings.phase_steepness, settings.ink_dissipation, settings.pressure_iterations,
		settings.render_smoothing, settings.random_seed,
		ST_FLIP_INITIAL_CONDITION_NAMES[settings.initial_condition_index], settings.paused)
}

settings_save_st_flip :: proc(path: string, settings: ST_Flip_Settings) -> bool {
	buf: [4096]u8
	return os.write_entire_file(path, settings_write_st_flip_toml(settings, buf[:])) == nil
}

settings_load_st_flip :: proc(path: string, defaults: ST_Flip_Settings) -> (ST_Flip_Settings, bool) {
	settings := defaults
	if !os.exists(path) do return settings, false
	cpath, err := strings.clone_to_cstring(path, context.temp_allocator)
	if err != nil do return settings, false
	result := toml_parse_file_ex(cpath)
	defer toml_free(result)
	if !result.ok do return settings, false
	if v, ok := toml_string(result.toptab, "st_flip.color_scheme"); ok do color_scheme_name_set(&settings.color_scheme, v)
	if v, ok := toml_bool(result.toptab, "st_flip.color_scheme_reversed"); ok do settings.color_scheme_reversed = v
	if v, ok := toml_bool(result.toptab, "st_flip.blur_enabled"); ok do settings.post_processing.blur_enabled = v
	if v, ok := toml_f64(result.toptab, "st_flip.blur_radius"); ok do settings.post_processing.blur_radius = f32(v)
	if v, ok := toml_f64(result.toptab, "st_flip.blur_sigma"); ok do settings.post_processing.blur_sigma = f32(v)
	if v, ok := toml_i64(result.toptab, "st_flip.particle_count"); ok do settings.particle_count = u32(max(v, 1))
	if v, ok := toml_i64(result.toptab, "st_flip.grid_height"); ok do settings.grid_height = u32(max(v, 1))
	if v, ok := toml_f64(result.toptab, "st_flip.target_cfl"); ok do settings.target_cfl = f32(v)
	if v, ok := toml_f64(result.toptab, "st_flip.simulation_speed"); ok do settings.simulation_speed = f32(v)
	if v, ok := toml_f64(result.toptab, "st_flip.gravity"); ok do settings.gravity = f32(v)
	if v, ok := toml_f64(result.toptab, "st_flip.flip_ratio"); ok do settings.flip_ratio = f32(v)
	if v, ok := toml_f64(result.toptab, "st_flip.jitter_strength"); ok do settings.jitter_strength = f32(v)
	if v, ok := toml_f64(result.toptab, "st_flip.phase_steepness"); ok do settings.phase_steepness = f32(v)
	if v, ok := toml_f64(result.toptab, "st_flip.ink_dissipation"); ok do settings.ink_dissipation = f32(v)
	if v, ok := toml_i64(result.toptab, "st_flip.pressure_iterations"); ok do settings.pressure_iterations = u32(max(v, 1))
	if v, ok := toml_f64(result.toptab, "st_flip.render_smoothing"); ok do settings.render_smoothing = f32(v)
	if v, ok := toml_i64(result.toptab, "st_flip.random_seed"); ok do settings.random_seed = u32(max(v, 0))
	if v, ok := toml_string(result.toptab, "st_flip.initial_condition"); ok {
		// "Pool" is the pre-ink-bath spelling retained for preset compatibility.
		if v == "Pool" do settings.initial_condition_index = int(ST_Flip_Initial_Condition.Pool)
		for name, i in ST_FLIP_INITIAL_CONDITION_NAMES {if v == name {settings.initial_condition_index = i; break}}
	}
	if v, ok := toml_bool(result.toptab, "st_flip.paused"); ok do settings.paused = v
	st_flip_validate_settings(&settings)
	return settings, true
}

settings_load_st_flip_preset :: proc(path: string, current: ST_Flip_Settings) -> (ST_Flip_Settings, bool) {
	settings, ok := settings_load_st_flip(path, current)
	if ok {
		settings.color_scheme = current.color_scheme
		settings.color_scheme_reversed = current.color_scheme_reversed
	}
	return settings, ok
}
