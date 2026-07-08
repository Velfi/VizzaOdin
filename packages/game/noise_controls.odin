package game

import uifw "../ui"

import "core:fmt"

draw_noise_settings_controls :: proc(gui: ^uifw.Gui_Context, settings: ^Noise_Settings, key_prefix: string) -> bool {
	changed := false
	noise_sync_indices(settings)

	if uifw.gui_collapsible_begin(gui, "Base", fmt.tprintf("%s_base", key_prefix), &settings.base_open) {
		seed := f32(settings.seed)
		if uifw.gui_number_drag_f32(gui, fmt.tprintf("Seed: %d", settings.seed), fmt.tprintf("%s_seed", key_prefix), &seed, 1, 0, 4294967295) {
			settings.seed = u32(seed)
			changed = true
		}
	}

	if uifw.gui_collapsible_begin(gui, "Placement", fmt.tprintf("%s_placement", key_prefix), &settings.placement_open) {
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Offset X: %.2f", settings.offset_x), fmt.tprintf("%s_offset_x", key_prefix), &settings.offset_x, 0.01, -100, 100) || changed
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Offset Y: %.2f", settings.offset_y), fmt.tprintf("%s_offset_y", key_prefix), &settings.offset_y, 0.01, -100, 100) || changed
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Rotation: %.2f", settings.rotation), fmt.tprintf("%s_rotation", key_prefix), &settings.rotation, 0.01, -6.28318, 6.28318) || changed
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Anchor X: %.2f", settings.anchor_x), fmt.tprintf("%s_anchor_x", key_prefix), &settings.anchor_x, 0.01, -100, 100) || changed
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Anchor Y: %.2f", settings.anchor_y), fmt.tprintf("%s_anchor_y", key_prefix), &settings.anchor_y, 0.01, -100, 100) || changed
	}

	if uifw.gui_collapsible_begin(gui, "Noise", fmt.tprintf("%s_noise", key_prefix), &settings.noise_open) {
		settings.kind_index = max(min(settings.kind_index, len(NOISE_KIND_NAMES) - 1), 0)
		if uifw.gui_selector(gui, fmt.tprintf("Noise Type: %s", NOISE_KIND_NAMES[settings.kind_index]), fmt.tprintf("%s_kind", key_prefix), &settings.kind_index, NOISE_KIND_NAMES[:]) {
			settings.kind = Noise_Kind(settings.kind_index)
			changed = true
		}
		changed = uifw.gui_slider_f32(gui, fmt.tprintf("Noise Strength: %.2f", settings.noise_strength), fmt.tprintf("%s_strength", key_prefix), &settings.noise_strength, 0, 2) || changed
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Amplitude: %.2f", settings.amplitude), fmt.tprintf("%s_amplitude", key_prefix), &settings.amplitude, 0.01, 0, 10) || changed
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Frequency: %.2f", settings.frequency), fmt.tprintf("%s_frequency", key_prefix), &settings.frequency, 0.01, 0.001, 100) || changed
		changed = draw_noise_kind_specific_controls(gui, settings, key_prefix) || changed
	}

	if uifw.gui_collapsible_begin(gui, "Fractal", fmt.tprintf("%s_fractal", key_prefix), &settings.fractal_open) {
		settings.fractal_mode_index = max(min(settings.fractal_mode_index, len(NOISE_FRACTAL_MODE_NAMES) - 1), 0)
		if uifw.gui_selector(gui, fmt.tprintf("Fractal: %s", NOISE_FRACTAL_MODE_NAMES[settings.fractal_mode_index]), fmt.tprintf("%s_fractal_mode", key_prefix), &settings.fractal_mode_index, NOISE_FRACTAL_MODE_NAMES[:]) {
			settings.fractal_mode = Noise_Fractal_Mode(settings.fractal_mode_index)
			changed = true
		}
		if settings.fractal_mode != .Single {
			octaves := f32(settings.octaves)
			if uifw.gui_number_drag_f32(gui, fmt.tprintf("Octaves: %d", settings.octaves), fmt.tprintf("%s_octaves", key_prefix), &octaves, 1, 1, 12) {
				settings.octaves = u32(octaves)
				changed = true
			}
			changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Lacunarity: %.2f", settings.lacunarity), fmt.tprintf("%s_lacunarity", key_prefix), &settings.lacunarity, 0.01, 0.01, 8) || changed
			changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Gain: %.2f", settings.gain), fmt.tprintf("%s_gain", key_prefix), &settings.gain, 0.01, 0, 1) || changed
		}
	}

	if uifw.gui_collapsible_begin(gui, "Domain Warping", fmt.tprintf("%s_warp", key_prefix), &settings.warp_open) {
		settings.warp_mode_index = max(min(settings.warp_mode_index, len(NOISE_WARP_MODE_NAMES) - 1), 0)
		if uifw.gui_selector(gui, fmt.tprintf("Warp Mode: %s", NOISE_WARP_MODE_NAMES[settings.warp_mode_index]), fmt.tprintf("%s_warp_mode", key_prefix), &settings.warp_mode_index, NOISE_WARP_MODE_NAMES[:]) {
			settings.warp_mode = Noise_Warp_Mode(settings.warp_mode_index)
			changed = true
		}
		if settings.warp_mode != .None {
			warp_octaves := f32(settings.warp_octaves)
			if uifw.gui_number_drag_f32(gui, fmt.tprintf("Warp Octaves: %d", settings.warp_octaves), fmt.tprintf("%s_warp_octaves", key_prefix), &warp_octaves, 1, 1, 8) {
				settings.warp_octaves = u32(warp_octaves)
				changed = true
			}
			changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Warp Amplitude: %.2f", settings.warp_amplitude), fmt.tprintf("%s_warp_amplitude", key_prefix), &settings.warp_amplitude, 0.01, 0, 10) || changed
			changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Warp Frequency: %.2f", settings.warp_frequency), fmt.tprintf("%s_warp_frequency", key_prefix), &settings.warp_frequency, 0.01, 0.001, 32) || changed
		}
	}

	noise_sync_indices(settings)
	return changed
}

draw_noise_kind_specific_controls :: proc(gui: ^uifw.Gui_Context, settings: ^Noise_Settings, key_prefix: string) -> bool {
	changed := false
	#partial switch settings.kind {
	case .Gabor:
		iterations := f32(settings.gabor.iterations)
		if uifw.gui_number_drag_f32(gui, fmt.tprintf("Iterations: %d", settings.gabor.iterations), fmt.tprintf("%s_gabor_iterations", key_prefix), &iterations, 1, 1, 96) {
			settings.gabor.iterations = u32(iterations)
			changed = true
		}
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Velocity: %.2f", settings.gabor.velocity), fmt.tprintf("%s_gabor_velocity", key_prefix), &settings.gabor.velocity, 0.01, -10, 10) || changed
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Band Width: %.3f", settings.gabor.band_width), fmt.tprintf("%s_gabor_band_width", key_prefix), &settings.gabor.band_width, 0.001, 0.001, 10) || changed
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Band Softness: %.2f", settings.gabor.band_softness), fmt.tprintf("%s_gabor_band_softness", key_prefix), &settings.gabor.band_softness, 0.01, 0.01, 8) || changed
	case .Phasor:
		iterations := f32(settings.phasor.iterations)
		if uifw.gui_number_drag_f32(gui, fmt.tprintf("Iterations: %d", settings.phasor.iterations), fmt.tprintf("%s_phasor_iterations", key_prefix), &iterations, 1, 1, 96) {
			settings.phasor.iterations = u32(iterations)
			changed = true
		}
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Velocity: %.2f", settings.phasor.velocity), fmt.tprintf("%s_phasor_velocity", key_prefix), &settings.phasor.velocity, 0.01, -10, 10) || changed
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Band Width: %.3f", settings.phasor.band_width), fmt.tprintf("%s_phasor_band_width", key_prefix), &settings.phasor.band_width, 0.001, 0.001, 10) || changed
	case .Voronoi:
		settings.voronoi.output_index = max(min(settings.voronoi.output_index, len(NOISE_CELLULAR_OUTPUT_NAMES) - 1), 0)
		if uifw.gui_selector(gui, fmt.tprintf("Cellular Output: %s", NOISE_CELLULAR_OUTPUT_NAMES[settings.voronoi.output_index]), fmt.tprintf("%s_cellular_output", key_prefix), &settings.voronoi.output_index, NOISE_CELLULAR_OUTPUT_NAMES[:]) {
			settings.voronoi.output = Noise_Cellular_Output(settings.voronoi.output_index)
			changed = true
		}
		settings.voronoi.distance_mode_index = max(min(settings.voronoi.distance_mode_index, len(NOISE_CELLULAR_DISTANCE_MODE_NAMES) - 1), 0)
		if uifw.gui_selector(gui, fmt.tprintf("Cellular Distance Mode: %s", NOISE_CELLULAR_DISTANCE_MODE_NAMES[settings.voronoi.distance_mode_index]), fmt.tprintf("%s_cellular_distance", key_prefix), &settings.voronoi.distance_mode_index, NOISE_CELLULAR_DISTANCE_MODE_NAMES[:]) {
			settings.voronoi.distance_mode = Noise_Cellular_Distance_Mode(settings.voronoi.distance_mode_index)
			changed = true
		}
	case .Wave:
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Velocity: %.2f", settings.wave.velocity), fmt.tprintf("%s_wave_velocity", key_prefix), &settings.wave.velocity, 0.01, -10, 10) || changed
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Band Width: %.3f", settings.wave.band_width), fmt.tprintf("%s_wave_band_width", key_prefix), &settings.wave.band_width, 0.001, 0.001, 10) || changed
		changed = uifw.gui_number_drag_f32(gui, fmt.tprintf("Band Softness: %.2f", settings.wave.band_softness), fmt.tprintf("%s_wave_band_softness", key_prefix), &settings.wave.band_softness, 0.01, 0.01, 8) || changed
	case:
	}
	return changed
}
