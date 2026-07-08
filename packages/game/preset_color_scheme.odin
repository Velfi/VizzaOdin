package game

gray_scott_settings_preserve_color_scheme :: proc(settings: ^Gray_Scott_Settings, current: Gray_Scott_Settings) {
	settings.color_scheme = current.color_scheme
	settings.color_scheme_reversed = current.color_scheme_reversed
}

particle_life_settings_preserve_color_scheme :: proc(settings: ^Particle_Life_Settings, current: Particle_Life_Settings) {
	settings.color_scheme = current.color_scheme
	settings.color_scheme_reversed = current.color_scheme_reversed
}

moire_settings_preserve_color_scheme :: proc(settings: ^Moire_Settings, current: Moire_Settings) {
	settings.color_scheme = current.color_scheme
	settings.color_scheme_reversed = current.color_scheme_reversed
}

vectors_settings_preserve_color_scheme :: proc(settings: ^Vectors_Settings, current: Vectors_Settings) {
	settings.color_scheme = current.color_scheme
	settings.color_scheme_reversed = current.color_scheme_reversed
}

primordial_settings_preserve_color_scheme :: proc(settings: ^Primordial_Settings, current: Primordial_Settings) {
	settings.color_scheme = current.color_scheme
	settings.color_scheme_reversed = current.color_scheme_reversed
}

voronoi_settings_preserve_color_scheme :: proc(settings: ^Voronoi_Settings, current: Voronoi_Settings) {
	settings.color_scheme = current.color_scheme
	settings.color_scheme_reversed = current.color_scheme_reversed
}

pellets_settings_preserve_color_scheme :: proc(settings: ^Pellets_Settings, current: Pellets_Settings) {
	settings.color_scheme = current.color_scheme
	settings.color_scheme_reversed = current.color_scheme_reversed
}

flow_settings_preserve_color_scheme :: proc(settings: ^Flow_Settings, current: Flow_Settings) {
	settings.color_scheme = current.color_scheme
	settings.color_scheme_reversed = current.color_scheme_reversed
}

slime_settings_preserve_color_scheme :: proc(settings: ^Slime_Settings, current: Slime_Settings) {
	settings.color_scheme = current.color_scheme
	settings.color_scheme_reversed = current.color_scheme_reversed
}

settings_load_gray_scott_preset :: proc(path: string, current: Gray_Scott_Settings) -> (Gray_Scott_Settings, bool) {
	settings, ok := settings_load_gray_scott(path, current)
	if ok {
		gray_scott_settings_preserve_color_scheme(&settings, current)
	}
	return settings, ok
}

settings_load_particle_life_preset :: proc(path: string, current: Particle_Life_Settings) -> (Particle_Life_Settings, bool) {
	settings, ok := settings_load_particle_life(path, current)
	if ok {
		particle_life_settings_preserve_color_scheme(&settings, current)
	}
	return settings, ok
}

settings_load_moire_preset :: proc(path: string, current: Moire_Settings) -> (Moire_Settings, bool) {
	settings, ok := settings_load_moire(path, current)
	if ok {
		moire_settings_preserve_color_scheme(&settings, current)
	}
	return settings, ok
}

settings_load_vectors_preset :: proc(path: string, current: Vectors_Settings) -> (Vectors_Settings, bool) {
	settings, ok := settings_load_vectors(path, current)
	if ok {
		vectors_settings_preserve_color_scheme(&settings, current)
	}
	return settings, ok
}

settings_load_primordial_preset :: proc(path: string, current: Primordial_Settings) -> (Primordial_Settings, bool) {
	settings, ok := settings_load_primordial(path, current)
	if ok {
		primordial_settings_preserve_color_scheme(&settings, current)
	}
	return settings, ok
}

settings_load_voronoi_preset :: proc(path: string, current: Voronoi_Settings) -> (Voronoi_Settings, bool) {
	settings, ok := settings_load_voronoi(path, current)
	if ok {
		voronoi_settings_preserve_color_scheme(&settings, current)
	}
	return settings, ok
}

settings_load_pellets_preset :: proc(path: string, current: Pellets_Settings) -> (Pellets_Settings, bool) {
	settings, ok := settings_load_pellets(path, current)
	if ok {
		pellets_settings_preserve_color_scheme(&settings, current)
	}
	return settings, ok
}

settings_load_flow_preset :: proc(path: string, current: Flow_Settings) -> (Flow_Settings, bool) {
	settings, ok := settings_load_flow(path, current)
	if ok {
		flow_settings_preserve_color_scheme(&settings, current)
	}
	return settings, ok
}

settings_load_slime_preset :: proc(path: string, current: Slime_Settings) -> (Slime_Settings, bool) {
	settings, ok := settings_load_slime(path, current)
	if ok {
		slime_settings_preserve_color_scheme(&settings, current)
	}
	return settings, ok
}
