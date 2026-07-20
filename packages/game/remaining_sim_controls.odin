package game

import uifw "zelda_engine:ui"
import engine "zelda_engine:engine"

import "core:fmt"
import "core:math"
import "core:c"
import sdl "vendor:sdl3"

remaining_sim_directory :: proc(kind: Remaining_Sim_Kind) -> string {
	#partial switch kind {
	case .Flow_Field:
		return "flow_field"
	case .Moire:
		return "moire"
	case .Vectors:
		return "vectors"
	case .Pellets:
		return "pellets"
	case .Primordial:
		return "primordial"
	case .Voronoi_CA:
		return "voronoi_ca"
	case .Slime_Mold:
		return "slime_mold"
	case:
		return "remaining"
	}
}

remaining_sim_scroll_row_height :: proc(gui: ^uifw.Gui_Context, rows: int) -> f32 {
	return f32(rows) * (gui.style.row_height + gui.style.spacing)
}

remaining_sim_scroll_heading_height :: proc(gui: ^uifw.Gui_Context) -> f32 {
	return gui.style.heading_line_height + gui.style.spacing
}

remaining_sim_scroll_spacer_height :: proc(gui: ^uifw.Gui_Context, height: f32) -> f32 {
	return height + gui.style.spacing
}

remaining_sim_controls_specific_content_height :: proc(sim: ^Remaining_Sim_State, kind: Remaining_Sim_Kind, gui: ^uifw.Gui_Context) -> f32 {
	rows := 0
	sections := 0

	#partial switch kind {
	case .Moire:
		rows = 3 + 1 + 6 + 3 + 3 + 4 + 1 + 1 + 3 + 3
		sections = 4
	case .Vectors:
		rows = 3 + 2 + 16 + 3 + 3 + 3
		sections = 1
	case .Primordial:
		rows = 3 + 3 + 3 + 14 + 2
		if sim.primordial.collision_enabled {rows += 2}
		if sim.primordial_randomize_undo_available {rows += 1}
		sections = 1
	case .Voronoi_CA:
		rows = 3 + 1 + 3 + 17
		if sim.voronoi_randomize_undo_available {rows += 1}
		sections = 1
	case .Pellets:
		rows = 3 + 2 + 3 + 9 + 6
		sections = 2
	case .Flow_Field:
		rows = 3 + 1 + 3 + 16 + 3 + 3 + 3 + 9 + 6
		sections = 4
	case .Slime_Mold:
		rows = 3 + 3 + 3 + 1 + 3 + 1 + 8 + 5 + 3 + 3 + 4
		sections = 4
	case:
		rows = 4
	}

	return remaining_sim_scroll_row_height(gui, rows) + remaining_sim_scroll_heading_height(gui) * f32(sections)
}

remaining_sim_controls_content_height :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind, content_width: f32) -> f32 {
	wrap_width := max(content_width - gui.style.panel_padding * 2 - gui.style.spacing_1, gui.style.body_char_width)
	description_lines := uifw.gui_wrap_line_count(gui, remaining_sim_description(kind), wrap_width)

	height := f32(0)
	height += remaining_sim_scroll_heading_height(gui) // About this simulation
	height += f32(description_lines) * gui.style.body_line_height + gui.style.spacing
	height += remaining_sim_scroll_spacer_height(gui, 8)
	height += remaining_sim_scroll_heading_height(gui) // Presets
	height += remaining_sim_scroll_row_height(gui, preset_fieldset_content_rows(&sim.preset_ui))
	height += remaining_sim_scroll_spacer_height(gui, 8)
	height += remaining_sim_controls_specific_content_height(sim, kind, gui)
	height += remaining_sim_scroll_heading_height(gui) * 7
	height += remaining_sim_scroll_row_height(gui, 22)
	height += remaining_sim_scroll_spacer_height(gui, 8)
	if sim.reset_undo.available {
		height += gui.style.row_height + gui.style.spacing
	}
	return height
}

remaining_sim_controller_section_content_height :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind, section: int, content_width: f32) -> f32 {
	row := gui.style.row_height + gui.style.spacing
	heading := remaining_sim_scroll_heading_height(gui)
	spacer := remaining_sim_scroll_spacer_height(gui, 8)
	if section == CONTROLLER_SECTION_PRESETS || section == 1 {
		wrap_width := max(content_width - gui.style.panel_padding * 2 - gui.style.spacing_1, gui.style.body_char_width)
		lines := uifw.gui_wrap_line_count(gui, remaining_sim_description(kind), wrap_width)
		action_rows := section == CONTROLLER_SECTION_PRESETS ? 1 + (sim.reset_undo.available ? 1 : 0) : 0
		return heading * f32(2 + (section == CONTROLLER_SECTION_PRESETS ? 1 : 0)) +
			row * f32(preset_fieldset_content_rows(&sim.preset_ui) + action_rows) +
			f32(lines) * gui.style.body_line_height + spacer * 2
	}
	if section == CONTROLLER_SECTION_LOOK || section == 2 {
		rows := 8
		#partial switch kind {
		case .Moire:
			rows = sim.moire.image_mode_enabled ? 13 : 3
		case .Vectors:
			rows = 3
		case .Flow_Field:
			rows = 8
		case .Pellets:
			rows = 10
			if sim.pellets.trails_enabled {rows += 1}
		case .Voronoi_CA:
			rows = 9
			if sim.voronoi.borders_enabled {rows += 1}
		case .Primordial:
			rows = 12
			if sim.primordial.traces_enabled {rows += 1}
		case:
		}
		return heading * 2 + row * f32(rows) + spacer
	}

	#partial switch kind {
	case .Flow_Field:
		switch section {
		case 3: return heading * 2 + row * 6 + uifw.gui_slider_height(gui)
		case 5:
			height := spacer + heading + row * (sim.flow.field_animation_enabled ? 4 : 3)
			if sim.flow.vector_field_type == .Noise {height += noise_settings_controls_content_height(gui, &sim.flow.noise)}
			if sim.flow.vector_field_type == .Image {height += row * 9}
			return height
		case 6: return heading + row * (sim.flow.emitter_mode == .Ring ? 13 : 12)
		case 7: return 8 + heading + row * 7
		case:
		}
	case .Pellets:
		switch section {
		case 3: return heading * 2 + shared_two_axis_pad_height(gui) + row * 6
		case 5: return heading + row * 6
		case 6: return 8 + heading + row * 5
		case:
		}
	case .Voronoi_CA:
		if section == 5 {
			rows := 9
			if sim.voronoi_randomize_undo_available {rows += 1}
			return heading * 2 + row * f32(rows) + shared_two_axis_pad_height(gui)
		}
	case .Moire:
		switch section {
		case MOIRE_SECTION_PATTERN:
			rows := 6
			if sim.moire.generator_type == .Radial {rows += 4}
			return heading * f32(sim.moire.generator_type == .Radial ? 3 : 2) + row * f32(rows) + shared_two_axis_pad_height(gui) * 2 + spacer * 2
		case 7: return heading + row * 4
		case:
		}
	case .Vectors:
		if section == 3 {
			height := heading + row * 6
			if sim.vectors.vector_field_type == .Noise {height += noise_settings_controls_content_height(gui, &sim.vectors.noise)}
			if sim.vectors.vector_field_type == .Image {height += row * 9}
			return height
		}
		if section == 8 {return heading * 2 + row * 6 + shared_two_axis_pad_height(gui)}
	case .Primordial:
		switch section {
		case 3: return heading * 2 + shared_two_axis_pad_height(gui) + row * 5
		case 5: return 8 + heading + row * 5
		case 6:
			rows := 6
			if sim.primordial.collision_enabled {rows += 2}
			if sim.primordial_randomize_undo_available {rows += 1}
			return spacer + heading + row * f32(rows) + shared_two_axis_pad_height(gui)
		case:
		}
	case:
	}
	return remaining_sim_controls_specific_content_height(sim, kind, gui)
}

remaining_sim_draw_controls :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind, panel: uifw.Rect, color_editor: ^Color_Scheme_Editor_State, worker: ^Product_Context = nil, section := -1, panel_scroll: ^f32 = nil) {
	uifw.gui_panel_begin(gui, panel)
	viewport := uifw.gui_next_rect(gui, height = max(panel.h - gui.style.panel_padding * 2, 0))
	content_height := remaining_sim_controls_content_height(sim, gui, kind, viewport.w)
	if section >= 0 {
		content_height = remaining_sim_controller_section_content_height(sim, gui, kind, section, viewport.w)
	}
	active_scroll := panel_scroll
	if active_scroll == nil {
		active_scroll = &sim.scroll
	}
	uifw.gui_scroll_begin(gui, viewport, content_height, active_scroll)
	if section >= 0 {
		remaining_sim_draw_controller_section(sim, gui, kind, color_editor, worker, section)
		uifw.gui_scroll_end(gui)
		uifw.gui_panel_end(gui)
		return
	}

	uifw.gui_heading(gui, "About this simulation")
	uifw.gui_text_block(gui, remaining_sim_description(kind), max(viewport.w - gui.style.panel_padding * 2, 1), gui.style.text_muted)
	uifw.gui_spacer(gui, 8)

	remaining_sim_draw_presets_section(sim, gui, kind, worker)
	uifw.gui_spacer(gui, 8)

	#partial switch kind {
	case .Moire:
		remaining_sim_draw_moire_menu(sim, gui, color_editor, worker)
	case .Vectors:
		remaining_sim_draw_vectors_menu(sim, gui, color_editor, worker)
	case .Primordial:
		remaining_sim_draw_common_sim_menu(sim, gui, kind, color_editor, worker)
	case .Voronoi_CA:
		remaining_sim_draw_common_sim_menu(sim, gui, kind, color_editor, worker)
	case .Pellets:
		remaining_sim_draw_common_sim_menu(sim, gui, kind, color_editor, worker)
	case .Flow_Field:
		remaining_sim_draw_common_sim_menu(sim, gui, kind, color_editor, worker)
	case .Slime_Mold:
		remaining_sim_draw_common_sim_menu(sim, gui, kind, color_editor, worker)
	case:
		uifw.gui_heading(gui, "Settings")
		remaining_sim_draw_settings_actions(sim, gui, "Reset")
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Speed: %.2f", sim.speed), "speed", &sim.speed, 0.02, 0, 5)
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Scale: %.2f", sim.scale), "scale", &sim.scale, 0.02, 0.25, 3)
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Density: %.2f", sim.density), "density", &sim.density, 0.02, 0.05, 1)
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Intensity: %.2f", sim.intensity), "intensity", &sim.intensity, 0.02, 0.05, 1)
	}
	uifw.gui_scroll_end(gui)
	uifw.gui_panel_end(gui)
	directory := remaining_sim_directory(kind)
	preset_save_dialog_draw(gui, &sim.preset_ui, worker, directory)
}

remaining_sim_draw_controller_section :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind, color_editor: ^Color_Scheme_Editor_State, worker: ^Product_Context, section: int) {
	if section == 0 {
		uifw.gui_heading(gui, "About this simulation")
		uifw.gui_text_block(gui, remaining_sim_description(kind), gui.content_width, gui.style.text_muted)
		return
	}
	if section == 1 {
		remaining_sim_draw_presets_section(sim, gui, kind, worker)
		uifw.gui_spacer(gui, 8)
		uifw.gui_heading(gui, "About this simulation")
		uifw.gui_text_block(gui, remaining_sim_description(kind), gui.content_width, gui.style.text_muted)
		return
	}
	if section == CONTROLLER_SECTION_PRESETS {
		remaining_sim_draw_presets_section(sim, gui, kind, worker)
		uifw.gui_spacer(gui, 8)
		uifw.gui_heading(gui, "Start Over")
		remaining_sim_draw_reset_action(sim, gui, remaining_sim_reset_label(kind))
		uifw.gui_spacer(gui, 8)
		uifw.gui_heading(gui, "About this simulation")
		uifw.gui_text_block(gui, remaining_sim_description(kind), gui.content_width, gui.style.text_muted)
		return
	}
	if section == CONTROLLER_SECTION_LOOK {
		#partial switch kind {
		case .Moire:
			remaining_sim_draw_moire_display_settings(sim, gui, color_editor, worker)
		case .Vectors:
			remaining_sim_draw_vectors_color(sim, gui, color_editor)
		case .Flow_Field, .Pellets, .Voronoi_CA, .Primordial:
			remaining_sim_draw_display_settings(sim, gui, kind, color_editor)
			uifw.gui_spacer(gui, 8)
			remaining_sim_draw_post_processing(sim, gui, kind)
		case:
		}
		return
	}
	#partial switch kind {
	case .Flow_Field:
		switch section {
		case 2: remaining_sim_draw_display_settings(sim, gui, kind, color_editor); remaining_sim_draw_post_processing(sim, gui, kind)
		case 3: remaining_sim_draw_interaction_controls(sim, gui, kind, "Brush")
		case 4: uifw.gui_heading(gui, "Settings"); remaining_sim_draw_settings_actions(sim, gui, "Reset Simulation")
		case 5: remaining_sim_draw_flow_settings(sim, gui, worker, 0)
		case 6: remaining_sim_draw_flow_settings(sim, gui, worker, 1)
		case 7: remaining_sim_draw_flow_settings(sim, gui, worker, 2)
		case:
		}
	case .Pellets:
		switch section {
		case 2: remaining_sim_draw_display_settings(sim, gui, kind, color_editor); remaining_sim_draw_post_processing(sim, gui, kind)
		case 3: remaining_sim_draw_interaction_controls(sim, gui, kind, "Brush")
		case 4: uifw.gui_heading(gui, "Settings"); remaining_sim_draw_settings_actions(sim, gui, "Reset Simulation")
		case 5: remaining_sim_draw_pellets_settings(sim, gui, 0)
		case 6: remaining_sim_draw_pellets_settings(sim, gui, 1)
		case:
		}
	case .Voronoi_CA:
		switch section {
		case 2: remaining_sim_draw_display_settings(sim, gui, kind, color_editor); remaining_sim_draw_post_processing(sim, gui, kind)
		case 3: remaining_sim_draw_interaction_controls(sim, gui, kind, "Brush")
		case 4: uifw.gui_heading(gui, "Settings"); remaining_sim_draw_settings_actions(sim, gui, "Reset Simulation")
		case 5: remaining_sim_draw_voronoi_settings(sim, gui, "Sites")
		case:
		}
	case .Primordial:
		switch section {
		case 2: remaining_sim_draw_display_settings(sim, gui, kind, color_editor); remaining_sim_draw_post_processing(sim, gui, kind)
		case 3: remaining_sim_draw_interaction_controls(sim, gui, kind, "Brush")
		case 4: uifw.gui_heading(gui, "Settings"); remaining_sim_draw_settings_actions(sim, gui, "Reset Simulation")
		case 5: remaining_sim_draw_primordial_settings(sim, gui, 0)
		case 6: remaining_sim_draw_primordial_settings(sim, gui, 1)
		case:
		}
	case .Moire:
		switch section {
		case 2: remaining_sim_draw_moire_display_settings(sim, gui, color_editor, worker)
		case 3: uifw.gui_heading(gui, "Controls"); uifw.gui_label(gui, "Mouse wheel: Zoom | Drag: Pan camera")
		case 4: uifw.gui_heading(gui, "Actions"); remaining_sim_draw_settings_actions(sim, gui, "Reset Moire Settings")
		case 5: remaining_sim_draw_moire_animation(sim, gui)
		case 6: remaining_sim_draw_moire_patterns(sim, gui); if sim.moire.generator_type == .Radial {remaining_sim_draw_moire_radial(sim, gui)}
		case 7: remaining_sim_draw_moire_advection(sim, gui)
		case MOIRE_SECTION_PATTERN:
			remaining_sim_draw_moire_patterns(sim, gui)
			if sim.moire.generator_type == .Radial {
				uifw.gui_spacer(gui, 8)
				remaining_sim_draw_moire_radial(sim, gui)
			}
			uifw.gui_spacer(gui, 8)
			remaining_sim_draw_moire_animation(sim, gui)
		case:
		}
	case .Vectors:
		switch section {
		case 2: remaining_sim_draw_vectors_color(sim, gui, color_editor)
		case 3: remaining_sim_draw_vectors_field(sim, gui, worker)
		case 8: remaining_sim_draw_interaction_controls(sim, gui, kind, "Probe")
		case:
		}
	case:
	}
}

remaining_sim_draw_presets_section :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind, worker: ^Product_Context = nil) {
	uifw.gui_heading(gui, "Presets")
	builtin_names := remaining_sim_builtin_preset_names(kind)
	directory := remaining_sim_directory(kind)
	preset_fieldset_draw(
		gui,
		&sim.preset_ui,
		worker,
		directory,
		builtin_names,
		sim.builtin_preset_index,
		Preset_Fieldset_Builtin_Context {kind = .Remaining, remaining = sim, remaining_kind = kind},
	)
}

remaining_sim_reset_label :: proc(kind: Remaining_Sim_Kind) -> string {
	#partial switch kind {
	case .Moire:
		return "Reset Moire Settings"
	case .Vectors:
		return "Reset Vector Field"
	case:
		return "Reset Simulation"
	}
}

remaining_sim_draw_reset_action :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, label: string) {
	if uifw.gui_button(gui, label, "reset") {
		remaining_sim_reset_with_undo(sim)
		uifw.gui_notice(gui, "Simulation returned to defaults. Restore Settings Before Reset is available here.")
	}
	if sim.reset_undo.available && uifw.gui_button(gui, "Restore Settings Before Reset", "undo_reset") {
		if remaining_sim_undo_reset(sim) {
			uifw.gui_notice(gui, "Settings from before reset restored.")
		}
	}
}

remaining_sim_draw_common_sim_menu :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind, color_editor: ^Color_Scheme_Editor_State, worker: ^Product_Context = nil) {
	remaining_sim_draw_display_settings(sim, gui, kind, color_editor)
	uifw.gui_spacer(gui, 8)
	remaining_sim_draw_post_processing(sim, gui, kind)
	uifw.gui_spacer(gui, 8)
	remaining_sim_draw_interaction_controls(sim, gui, kind)
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Settings")
	remaining_sim_draw_settings_actions(sim, gui, "Reset Simulation")
	#partial switch kind {
	case .Primordial:
		remaining_sim_draw_primordial_settings(sim, gui)
	case .Voronoi_CA:
		remaining_sim_draw_voronoi_settings(sim, gui)
	case .Pellets:
		remaining_sim_draw_pellets_settings(sim, gui)
	case .Flow_Field:
		remaining_sim_draw_flow_settings(sim, gui, worker)
	case .Slime_Mold:
		remaining_sim_draw_slime_settings(sim, gui, worker)
	case:
	}
}

remaining_sim_draw_post_processing :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind) {
	options := shared_default_post_processing_menu_options()
	#partial switch kind {
	case .Slime_Mold:
		settings := &sim.slime.post_processing
		_ = shared_post_processing_menu(gui, &settings.blur_enabled, &settings.blur_radius, &settings.blur_sigma, options)
	case .Flow_Field:
		settings := &sim.flow.post_processing
		_ = shared_post_processing_menu(gui, &settings.blur_enabled, &settings.blur_radius, &settings.blur_sigma, options)
	case .Pellets:
		settings := &sim.pellets.post_processing
		_ = shared_post_processing_menu(gui, &settings.blur_enabled, &settings.blur_radius, &settings.blur_sigma, options)
	case .Voronoi_CA:
		settings := &sim.voronoi.post_processing
		_ = shared_post_processing_menu(gui, &settings.blur_enabled, &settings.blur_radius, &settings.blur_sigma, options)
	case .Primordial:
		settings := &sim.primordial.post_processing
		_ = shared_post_processing_menu(gui, &settings.blur_enabled, &settings.blur_radius, &settings.blur_sigma, options)
	case:
	}
}

remaining_sim_draw_settings_actions :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, reset_label: string) {
	_ = uifw.gui_toggle(gui, fmt.tprintf("Paused: %v", sim.paused), "paused", &sim.paused)
	remaining_sim_draw_reset_action(sim, gui, reset_label)
}

remaining_sim_draw_display_settings :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind, color_editor: ^Color_Scheme_Editor_State) {
	uifw.gui_heading(gui, "Display Settings")
	#partial switch kind {
	case .Slime_Mold:
		settings := sim.slime
		_ = color_scheme_editor_draw_selector(gui, color_editor, "slime_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
		if uifw.gui_selector(gui, fmt.tprintf("Background: %s", SLIME_BACKGROUND_MODE_NAMES[settings.background_index]), "slime_background", &settings.background_index, SLIME_BACKGROUND_MODE_NAMES[:]) {
			settings.background_mode = Slime_Background_Mode(settings.background_index)
		}
	case .Flow_Field:
		settings := sim.flow
		_ = color_scheme_editor_draw_selector(gui, color_editor, "flow_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
		if uifw.gui_selector(gui, fmt.tprintf("Particle Color Mode: %s", FLOW_FOREGROUND_MODE_NAMES[settings.foreground_index]), "flow_foreground", &settings.foreground_index, FLOW_FOREGROUND_MODE_NAMES[:]) {
			settings.foreground_color_mode = Flow_Foreground_Mode(settings.foreground_index)
		}
		if uifw.gui_selector(gui, fmt.tprintf("Background Color Mode: %s", VECTOR_BACKGROUND_MODE_NAMES[settings.background_index]), "flow_background", &settings.background_index, VECTOR_BACKGROUND_MODE_NAMES[:]) {
			settings.background_color_mode = Vector_Background_Mode(settings.background_index)
		}
	case .Pellets:
		settings := sim.pellets
		_ = color_scheme_editor_draw_selector(gui, color_editor, "pellets_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
		if uifw.gui_selector(gui, fmt.tprintf("Background Color Mode: %s", VECTOR_BACKGROUND_MODE_NAMES[settings.background_index]), "pellets_background", &settings.background_index, VECTOR_BACKGROUND_MODE_NAMES[:]) {
			settings.background_color_mode = Vector_Background_Mode(settings.background_index)
		}
		if uifw.gui_selector(gui, fmt.tprintf("Particle Color Mode: %s", PELLETS_FOREGROUND_MODE_NAMES[settings.foreground_index]), "pellets_foreground", &settings.foreground_index, PELLETS_FOREGROUND_MODE_NAMES[:]) {
			settings.foreground_color_mode = Pellets_Foreground_Mode(settings.foreground_index)
		}
		if settings.foreground_color_mode == .Density {
			_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Density Radius: %.3f", settings.density_radius), "pellets_density_display", &settings.density_radius, 0.001, 0.001, 0.25)
		}
		_ = uifw.gui_toggle(gui, fmt.tprintf("Enable Trails: %v", settings.trails_enabled), "pellets_trails", &settings.trails_enabled)
		if settings.trails_enabled {
			_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Trail Fade: %.2f", settings.trail_fade), "pellets_trail_fade", &settings.trail_fade, 0.01, 0, 1)
		}
	case .Voronoi_CA:
		settings := sim.voronoi
		_ = color_scheme_editor_draw_selector(gui, color_editor, "voronoi_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
		settings.color_mode_index = max(min(settings.color_mode_index, len(VORONOI_COLOR_MODE_NAMES) - 1), 0)
		if uifw.gui_selector(gui, fmt.tprintf("Coloring Mode: %s", VORONOI_COLOR_MODE_NAMES[settings.color_mode_index]), "voronoi_color_mode", &settings.color_mode_index, VORONOI_COLOR_MODE_NAMES[:]) {
			settings.color_mode = u32(settings.color_mode_index)
		}
		_ = uifw.gui_toggle(gui, fmt.tprintf("Borders: %v", settings.borders_enabled), "voronoi_borders", &settings.borders_enabled)
		if settings.borders_enabled {
			_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Border Width: %.1f", settings.border_width), "voronoi_border_width", &settings.border_width, 0.5, 0, 64)
		}
	case .Primordial:
		settings := sim.primordial
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Particle Size: %.3f", settings.particle_size), "primordial_particle_size", &settings.particle_size, 0.001, 0.001, 0.1)
		_ = color_scheme_editor_draw_selector(gui, color_editor, "primordial_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
		if uifw.gui_selector(gui, fmt.tprintf("Background Color Mode: %s", VECTOR_BACKGROUND_MODE_NAMES[settings.background_index]), "primordial_background", &settings.background_index, VECTOR_BACKGROUND_MODE_NAMES[:]) {
			settings.background_color_mode = Vector_Background_Mode(settings.background_index)
		}
		if uifw.gui_selector(gui, fmt.tprintf("Particle Color Mode: %s", PRIMORDIAL_FOREGROUND_MODE_NAMES[settings.foreground_index]), "primordial_foreground", &settings.foreground_index, PRIMORDIAL_FOREGROUND_MODE_NAMES[:]) {
			settings.foreground_color_mode = Primordial_Foreground_Mode(settings.foreground_index)
		}
		if settings.foreground_color_mode == .Density {
			_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Density Radius: %.3f", settings.density_radius), "primordial_density_radius_display", &settings.density_radius, 0.001, 0.001, 0.25)
		}
		_ = uifw.gui_toggle(gui, fmt.tprintf("Particle Traces: %v", settings.traces_enabled), "primordial_traces", &settings.traces_enabled)
		if settings.traces_enabled {
			_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Trace Fade: %.2f", settings.trace_fade), "primordial_trace_fade", &settings.trace_fade, 0.01, 0, 1)
		}
	case:
	}
}

remaining_sim_draw_interaction_controls :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind, heading: string = "") {
	tool_set := canvas_tool_set_for_kind(kind)
	options := Controls_Panel_Options {
		heading = heading,
		mouse_interaction_text = "",
		cursor_settings_title = "",
		cursor = shared_default_cursor_config_options(),
	}
	#partial switch kind {
	case .Slime_Mold:
		options.cursor.size_min = 0.01
		options.cursor.size_max = 1.0
		options.cursor.strength_max = 50.0
	case .Flow_Field:
		options.cursor.show_strength = false
	case .Voronoi_CA:
		options.cursor_settings_title = "Cursor Settings"
		options.cursor.strength_step = 0.01
	case:
	}
	selector_title := kind == .Voronoi_CA ? "Canvas Tools" : (kind == .Vectors ? "Probe Tools" : "Brush Modes")
	shared_canvas_tool_selector(gui, &tool_set, &sim.canvas_tool, selector_title)
	if kind == .Vectors {
		pin := sim.vectors.probe_pinned ? " · pinned" : ""
		if !sim.vectors.probe_initialized {
			uifw.gui_label(gui, "Move the probe over the field to inspect it")
		} else if sim.vectors.probe_has_sample {
			uifw.gui_label(gui, fmt.tprintf("Probe %.3f at (%.2f, %.2f)%s", sim.vectors.probe_value, sim.vectors.probe_position[0], sim.vectors.probe_position[1], pin))
		} else {
			uifw.gui_label(gui, fmt.tprintf("Move the probe over the image field%s", pin))
		}
	}
	if kind == .Vectors && sim.canvas_tool.selected_slot == 0 {
		// Probe has no adjustable footprint; its panel is intentionally read-only.
		return
	}
	if kind == .Flow_Field && sim.canvas_tool.selected_slot > 0 {
		options.cursor_settings_title = "Force follows Vector Magnitude in the Field panel."
	}
	uifw.gui_heading(gui, "Brush Shape")
	_ = shared_cursor_config(gui, &sim.cursor_size, &sim.cursor_strength, options.cursor)
}

remaining_sim_draw_color_scheme_modal :: proc(gui: ^uifw.Gui_Context, color_editor: ^Color_Scheme_Editor_State, kind: Remaining_Sim_Kind, sim: ^Remaining_Sim_State) {
	#partial switch kind {
	case .Moire:
		_ = color_scheme_editor_draw_modal(gui, color_editor, &sim.moire.color_scheme)
	case .Vectors:
		_ = color_scheme_editor_draw_modal(gui, color_editor, &sim.vectors.color_scheme)
	case .Primordial:
		_ = color_scheme_editor_draw_modal(gui, color_editor, &sim.primordial.color_scheme)
	case .Voronoi_CA:
		_ = color_scheme_editor_draw_modal(gui, color_editor, &sim.voronoi.color_scheme)
	case .Pellets:
		_ = color_scheme_editor_draw_modal(gui, color_editor, &sim.pellets.color_scheme)
	case .Flow_Field:
		_ = color_scheme_editor_draw_modal(gui, color_editor, &sim.flow.color_scheme)
	case .Slime_Mold:
		_ = color_scheme_editor_draw_modal(gui, color_editor, &sim.slime.color_scheme)
	case:
	}
}

remaining_sim_enqueue_image_command :: proc(worker: ^Product_Context, target: Feature_Image_Target, path: string = "", clear := false) {
	if worker == nil {
		return
	}
	command_id := clear ? FEATURE_COMMAND_CLEAR_IMAGE : FEATURE_COMMAND_LOAD_IMAGE
	feature_id, slot, found := feature_image_target_location(target)
	if found {
		payload: Feature_Image_Command
		payload.slot = slot
		write_fixed_string(payload.path[:], path)
		if feature, ok := feature_command_make(feature_id, command_id, &payload); ok {
			_ = engine.queue_try_push(worker.ui_to_render, Ui_To_Render_Command{kind = .Feature, feature = feature})
		}
		return
	}
}

// Polls SDL once per render frame. AcquireCameraFrame returns nil until the
// camera has a new frame, so this naturally follows the device cadence (30/60
// fps, etc.) instead of throttling it to a timer.
remaining_sim_webcam_capture_control :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, worker: ^Product_Context, target: Feature_Image_Target, key: string) {
	count: c.int
	ids := sdl.GetCameras(&count)
	defer if ids != nil {sdl.free(ids)}
	available := ids != nil && count > 0
	start_requested := false
	if sim.webcam_capture == nil {
		if available {start_requested = uifw.gui_button(gui, "Start Webcam", key)} else {uifw.gui_disabled_button(gui, "Start Webcam")}
	} else if uifw.gui_button(gui, "Stop Webcam", fmt.tprintf("%s_stop", key)) {
		sdl.CloseCamera(sim.webcam_capture)
		sim.webcam_capture = nil
		write_fixed_string(sim.webcam_capture_status[:], fmt.tprintf("Webcam stopped after %d frames", sim.webcam_capture_frames))
	}
	if start_requested {
		selected := 0
		if worker != nil && len(worker.settings.preferred_camera) > 0 {
			for i in 0..<int(count) {
				name := sdl.GetCameraName(ids[i])
				if name != nil && string(name) == worker.settings.preferred_camera {selected = i; break}
			}
		}
		sim.webcam_capture = sdl.OpenCamera(ids[selected], nil)
		sim.webcam_capture_target = target
		sim.webcam_capture_frames = 0
		write_fixed_string(sim.webcam_capture_status[:], sim.webcam_capture == nil ? "Could not open preferred camera" : "Waiting for camera permission…")
	}
	if !available && sim.webcam_capture == nil {uifw.gui_label(gui, "No webcam devices")}
	status := fixed_string(sim.webcam_capture_status[:])
	if len(status) > 0 {uifw.gui_label(gui, status)}
}
