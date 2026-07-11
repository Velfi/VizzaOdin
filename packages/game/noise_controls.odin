package game

import uifw "../ui"

import "core:fmt"

noise_settings_controls_content_height :: proc(gui: ^uifw.Gui_Context, settings: ^Noise_Settings) -> f32 {
	row := gui.style.row_height + gui.style.spacing
	height := row * 5 // Base, Placement, Noise, Fractal, and Domain Warping headers.
	if settings.base_open {height += row}
	if settings.placement_open {height += row * 5}
	if settings.noise_open {
		height += row * 3 + uifw.gui_slider_height(gui)
		#partial switch settings.kind {
		case .Gabor: height += row * 4
		case .Phasor: height += row * 3
		case .Voronoi: height += row * 2
		case .Wave: height += row * 3
		case:
		}
	}
	if settings.fractal_open {
		height += row
		if settings.fractal_mode != .Single {height += row * 3}
	}
	if settings.warp_open {
		height += row
		if settings.warp_mode != .None {height += row * 3}
	}
	return height
}

draw_noise_settings_controls :: proc(gui: ^uifw.Gui_Context, settings: ^Noise_Settings, key_prefix: string) -> bool {
	changed := false
	noise_sync_indices(settings)

	if uifw.gui_collapsible_begin(gui, "Base", fmt.tprintf("%s_base", key_prefix), &settings.base_open) {
		if uifw.gui_numeric_u32(gui, "Seed", fmt.tprintf("%s_seed", key_prefix), &settings.seed, 0, ~u32(0)) {
			changed = true
		}
	}

	if uifw.gui_collapsible_begin(gui, "Placement", fmt.tprintf("%s_placement", key_prefix), &settings.placement_open) {
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Offset X: %.2f", settings.offset_x), fmt.tprintf("%s_offset_x", key_prefix), &settings.offset_x, 0.01, -100, 100) || changed
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Offset Y: %.2f", settings.offset_y), fmt.tprintf("%s_offset_y", key_prefix), &settings.offset_y, 0.01, -100, 100) || changed
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Rotation: %.2f", settings.rotation), fmt.tprintf("%s_rotation", key_prefix), &settings.rotation, 0.01, -6.28318, 6.28318) || changed
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Anchor X: %.2f", settings.anchor_x), fmt.tprintf("%s_anchor_x", key_prefix), &settings.anchor_x, 0.01, -100, 100) || changed
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Anchor Y: %.2f", settings.anchor_y), fmt.tprintf("%s_anchor_y", key_prefix), &settings.anchor_y, 0.01, -100, 100) || changed
	}

	if uifw.gui_collapsible_begin(gui, "Noise", fmt.tprintf("%s_noise", key_prefix), &settings.noise_open) {
		settings.kind_index = max(min(settings.kind_index, len(NOISE_KIND_NAMES) - 1), 0)
		if uifw.gui_selector(gui, fmt.tprintf("Noise Type: %s", NOISE_KIND_NAMES[settings.kind_index]), fmt.tprintf("%s_kind", key_prefix), &settings.kind_index, NOISE_KIND_NAMES[:]) {
			settings.kind = Noise_Kind(settings.kind_index)
			changed = true
		}
		changed = uifw.gui_slider_f32(gui, fmt.tprintf("Noise Strength: %.2f", settings.noise_strength), fmt.tprintf("%s_strength", key_prefix), &settings.noise_strength, 0, 2) || changed
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Amplitude: %.2f", settings.amplitude), fmt.tprintf("%s_amplitude", key_prefix), &settings.amplitude, 0.01, 0, 10) || changed
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Frequency: %.2f", settings.frequency), fmt.tprintf("%s_frequency", key_prefix), &settings.frequency, 0.01, 0.001, 100, mapping = .Logarithmic) || changed
		changed = draw_noise_kind_specific_controls(gui, settings, key_prefix) || changed
	}

	if uifw.gui_collapsible_begin(gui, "Fractal", fmt.tprintf("%s_fractal", key_prefix), &settings.fractal_open) {
		settings.fractal_mode_index = max(min(settings.fractal_mode_index, len(NOISE_FRACTAL_MODE_NAMES) - 1), 0)
		if uifw.gui_selector(gui, fmt.tprintf("Fractal: %s", NOISE_FRACTAL_MODE_NAMES[settings.fractal_mode_index]), fmt.tprintf("%s_fractal_mode", key_prefix), &settings.fractal_mode_index, NOISE_FRACTAL_MODE_NAMES[:]) {
			settings.fractal_mode = Noise_Fractal_Mode(settings.fractal_mode_index)
			changed = true
		}
		if settings.fractal_mode != .Single {
			if uifw.gui_numeric_u32(gui, "Octaves", fmt.tprintf("%s_octaves", key_prefix), &settings.octaves, 1, 12) {
				changed = true
			}
			changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Lacunarity: %.2f", settings.lacunarity), fmt.tprintf("%s_lacunarity", key_prefix), &settings.lacunarity, 0.01, 0.01, 8) || changed
			changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Gain: %.2f", settings.gain), fmt.tprintf("%s_gain", key_prefix), &settings.gain, 0.01, 0, 1) || changed
		}
	}

	if uifw.gui_collapsible_begin(gui, "Domain Warping", fmt.tprintf("%s_warp", key_prefix), &settings.warp_open) {
		settings.warp_mode_index = max(min(settings.warp_mode_index, len(NOISE_WARP_MODE_NAMES) - 1), 0)
		if uifw.gui_selector(gui, fmt.tprintf("Warp Mode: %s", NOISE_WARP_MODE_NAMES[settings.warp_mode_index]), fmt.tprintf("%s_warp_mode", key_prefix), &settings.warp_mode_index, NOISE_WARP_MODE_NAMES[:]) {
			settings.warp_mode = Noise_Warp_Mode(settings.warp_mode_index)
			changed = true
		}
		if settings.warp_mode != .None {
			if uifw.gui_numeric_u32(gui, "Warp Octaves", fmt.tprintf("%s_warp_octaves", key_prefix), &settings.warp_octaves, 1, 8) {
				changed = true
			}
			changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Warp Amplitude: %.2f", settings.warp_amplitude), fmt.tprintf("%s_warp_amplitude", key_prefix), &settings.warp_amplitude, 0.01, 0, 10) || changed
			changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Warp Frequency: %.2f", settings.warp_frequency), fmt.tprintf("%s_warp_frequency", key_prefix), &settings.warp_frequency, 0.01, 0.001, 32, mapping = .Logarithmic) || changed
		}
	}

	noise_sync_indices(settings)
	return changed
}

draw_noise_kind_specific_controls :: proc(gui: ^uifw.Gui_Context, settings: ^Noise_Settings, key_prefix: string) -> bool {
	changed := false
	#partial switch settings.kind {
	case .Gabor:
		if uifw.gui_numeric_u32(gui, "Iterations", fmt.tprintf("%s_gabor_iterations", key_prefix), &settings.gabor.iterations, 1, 96) {
			changed = true
		}
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Velocity: %.2f", settings.gabor.velocity), fmt.tprintf("%s_gabor_velocity", key_prefix), &settings.gabor.velocity, 0.01, -10, 10) || changed
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Band Width: %.3f", settings.gabor.band_width), fmt.tprintf("%s_gabor_band_width", key_prefix), &settings.gabor.band_width, 0.001, 0.001, 10) || changed
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Band Softness: %.2f", settings.gabor.band_softness), fmt.tprintf("%s_gabor_band_softness", key_prefix), &settings.gabor.band_softness, 0.01, 0.01, 8) || changed
	case .Phasor:
		if uifw.gui_numeric_u32(gui, "Iterations", fmt.tprintf("%s_phasor_iterations", key_prefix), &settings.phasor.iterations, 1, 96) {
			changed = true
		}
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Velocity: %.2f", settings.phasor.velocity), fmt.tprintf("%s_phasor_velocity", key_prefix), &settings.phasor.velocity, 0.01, -10, 10) || changed
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Band Width: %.3f", settings.phasor.band_width), fmt.tprintf("%s_phasor_band_width", key_prefix), &settings.phasor.band_width, 0.001, 0.001, 10) || changed
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
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Velocity: %.2f", settings.wave.velocity), fmt.tprintf("%s_wave_velocity", key_prefix), &settings.wave.velocity, 0.01, -10, 10) || changed
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Band Width: %.3f", settings.wave.band_width), fmt.tprintf("%s_wave_band_width", key_prefix), &settings.wave.band_width, 0.001, 0.001, 10) || changed
		changed = uifw.gui_numeric_f32(gui, fmt.tprintf("Band Softness: %.2f", settings.wave.band_softness), fmt.tprintf("%s_wave_band_softness", key_prefix), &settings.wave.band_softness, 0.01, 0.01, 8) || changed
	case:
	}
	return changed
}
