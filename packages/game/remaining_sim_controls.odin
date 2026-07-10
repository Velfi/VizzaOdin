package game

import uifw "../ui"
import engine "../engine"

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

remaining_sim_controls_specific_content_height :: proc(kind: Remaining_Sim_Kind, gui: ^uifw.Gui_Context) -> f32 {
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
		rows = 3 + 3 + 3 + 9 + 2
		sections = 1
	case .Voronoi_CA:
		rows = 3 + 1 + 3 + 15
		sections = 1
	case .Pellets:
		rows = 3 + 2 + 3 + 9 + 6
		sections = 2
	case .Flow_Field:
		rows = 3 + 1 + 3 + 16 + 3 + 3 + 3 + 9 + 5
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
	height += remaining_sim_controls_specific_content_height(kind, gui)
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
		case 3: return heading + row * 2 + uifw.gui_slider_height(gui)
		case 5:
			height := heading + row * 2
			if sim.flow.vector_field_type == .Noise {height += noise_settings_controls_content_height(gui, &sim.flow.noise)}
			if sim.flow.vector_field_type == .Image {height += row * 9}
			return height
		case 6: return heading + row * 9
		case 7: return heading + row * 5
		case:
		}
	case .Pellets:
		switch section {
		case 3: return heading + shared_two_axis_pad_height(gui) + row * 2
		case 5: return heading + row * 6
		case 6: return heading + row * 5
		case:
		}
	case .Voronoi_CA:
		if section == 5 {return heading + row * 5}
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
			height := heading + row * 5
			if sim.vectors.vector_field_type == .Noise {height += noise_settings_controls_content_height(gui, &sim.vectors.noise)}
			if sim.vectors.vector_field_type == .Image {height += row * 9}
			return height
		}
	case .Primordial:
		switch section {
		case 3: return heading + shared_two_axis_pad_height(gui) + row * 2
		case 5: return heading + row * 3
		case 6: return heading + row * 4 + shared_two_axis_pad_height(gui)
		case:
		}
	case:
	}
	return remaining_sim_controls_specific_content_height(kind, gui)
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
		_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Speed: %.2f", sim.speed), "speed", &sim.speed, 0.02, 0, 5)
		_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Scale: %.2f", sim.scale), "scale", &sim.scale, 0.02, 0.25, 3)
		_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Density: %.2f", sim.density), "density", &sim.density, 0.02, 0.05, 1)
		_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Intensity: %.2f", sim.intensity), "intensity", &sim.intensity, 0.02, 0.05, 1)
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
		settings := &sim.slime
		_ = color_scheme_editor_draw_selector(gui, color_editor, "slime_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
		if uifw.gui_selector(gui, fmt.tprintf("Background: %s", SLIME_BACKGROUND_MODE_NAMES[settings.background_index]), "slime_background", &settings.background_index, SLIME_BACKGROUND_MODE_NAMES[:]) {
			settings.background_mode = Slime_Background_Mode(settings.background_index)
		}
	case .Flow_Field:
		settings := &sim.flow
		_ = color_scheme_editor_draw_selector(gui, color_editor, "flow_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
		if uifw.gui_selector(gui, fmt.tprintf("Particle Color Mode: %s", FLOW_FOREGROUND_MODE_NAMES[settings.foreground_index]), "flow_foreground", &settings.foreground_index, FLOW_FOREGROUND_MODE_NAMES[:]) {
			settings.foreground_color_mode = Flow_Foreground_Mode(settings.foreground_index)
		}
		if uifw.gui_selector(gui, fmt.tprintf("Background Color Mode: %s", VECTOR_BACKGROUND_MODE_NAMES[settings.background_index]), "flow_background", &settings.background_index, VECTOR_BACKGROUND_MODE_NAMES[:]) {
			settings.background_color_mode = Vector_Background_Mode(settings.background_index)
		}
	case .Pellets:
		settings := &sim.pellets
		_ = color_scheme_editor_draw_selector(gui, color_editor, "pellets_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
		if uifw.gui_selector(gui, fmt.tprintf("Background Color Mode: %s", VECTOR_BACKGROUND_MODE_NAMES[settings.background_index]), "pellets_background", &settings.background_index, VECTOR_BACKGROUND_MODE_NAMES[:]) {
			settings.background_color_mode = Vector_Background_Mode(settings.background_index)
		}
		if uifw.gui_selector(gui, fmt.tprintf("Particle Color Mode: %s", PELLETS_FOREGROUND_MODE_NAMES[settings.foreground_index]), "pellets_foreground", &settings.foreground_index, PELLETS_FOREGROUND_MODE_NAMES[:]) {
			settings.foreground_color_mode = Pellets_Foreground_Mode(settings.foreground_index)
		}
		if settings.foreground_color_mode == .Density {
			_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Density Radius: %.3f", settings.density_radius), "pellets_density_display", &settings.density_radius, 0.001, 0.001, 0.25)
		}
		_ = uifw.gui_toggle(gui, fmt.tprintf("Enable Trails: %v", settings.trails_enabled), "pellets_trails", &settings.trails_enabled)
		if settings.trails_enabled {
			_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Trail Fade: %.2f", settings.trail_fade), "pellets_trail_fade", &settings.trail_fade, 0.01, 0, 1)
		}
	case .Voronoi_CA:
		settings := &sim.voronoi
		_ = color_scheme_editor_draw_selector(gui, color_editor, "voronoi_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
		settings.color_mode_index = max(min(settings.color_mode_index, len(VORONOI_COLOR_MODE_NAMES) - 1), 0)
		if uifw.gui_selector(gui, fmt.tprintf("Coloring Mode: %s", VORONOI_COLOR_MODE_NAMES[settings.color_mode_index]), "voronoi_color_mode", &settings.color_mode_index, VORONOI_COLOR_MODE_NAMES[:]) {
			settings.color_mode = u32(settings.color_mode_index)
		}
		_ = uifw.gui_toggle(gui, fmt.tprintf("Borders: %v", settings.borders_enabled), "voronoi_borders", &settings.borders_enabled)
		if settings.borders_enabled {
			_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Border Width: %.1f", settings.border_width), "voronoi_border_width", &settings.border_width, 0.5, 0, 64)
		}
	case .Primordial:
		settings := &sim.primordial
		_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Particle Size: %.3f", settings.particle_size), "primordial_particle_size", &settings.particle_size, 0.001, 0.001, 0.1)
		_ = color_scheme_editor_draw_selector(gui, color_editor, "primordial_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
		if uifw.gui_selector(gui, fmt.tprintf("Background Color Mode: %s", VECTOR_BACKGROUND_MODE_NAMES[settings.background_index]), "primordial_background", &settings.background_index, VECTOR_BACKGROUND_MODE_NAMES[:]) {
			settings.background_color_mode = Vector_Background_Mode(settings.background_index)
		}
		if uifw.gui_selector(gui, fmt.tprintf("Particle Color Mode: %s", PRIMORDIAL_FOREGROUND_MODE_NAMES[settings.foreground_index]), "primordial_foreground", &settings.foreground_index, PRIMORDIAL_FOREGROUND_MODE_NAMES[:]) {
			settings.foreground_color_mode = Primordial_Foreground_Mode(settings.foreground_index)
		}
		if settings.foreground_color_mode == .Density {
			_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Density Radius: %.3f", settings.density_radius), "primordial_density_radius_display", &settings.density_radius, 0.001, 0.001, 0.25)
		}
		_ = uifw.gui_toggle(gui, fmt.tprintf("Particle Traces: %v", settings.traces_enabled), "primordial_traces", &settings.traces_enabled)
		if settings.traces_enabled {
			_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Trace Fade: %.2f", settings.trace_fade), "primordial_trace_fade", &settings.trace_fade, 0.01, 0, 1)
		}
	case:
	}
}

remaining_sim_draw_interaction_controls :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind, heading: string = "") {
	options := Controls_Panel_Options {
		heading = heading,
		mouse_interaction_text = "",
		cursor_settings_title = "",
		cursor = shared_default_cursor_config_options(),
	}
	#partial switch kind {
	case .Slime_Mold:
		options.mouse_interaction_text = gui.input.active_device == .Controller ? "Primary: attract agents | Secondary: repel agents" : "Left click: attract agents | Right click: repel agents"
		options.cursor.size_min = 0.01
		options.cursor.size_max = 1.0
		options.cursor.strength_max = 50.0
	case .Flow_Field:
		options.mouse_interaction_text = gui.input.active_device == .Controller ? "Primary: spawn particles | Secondary: remove particles" : "Left click: spawn particles | Right click: remove particles"
		options.cursor.show_strength = false
	case .Pellets:
		options.mouse_interaction_text = gui.input.active_device == .Controller ? "Primary: attract particles" : "Left click: attract particles"
	case .Voronoi_CA:
		options.cursor_settings_title = "Cursor Settings"
		options.cursor.strength_step = 0.01
	case .Primordial:
		options.mouse_interaction_text = gui.input.active_device == .Controller ? "Primary: fling particles | Triggers: zoom" : "Drag: fling particles | Scroll: zoom"
	case:
		options.mouse_interaction_text = "Mouse interaction"
	}
	_ = shared_controls_panel(gui, options, &sim.cursor_size, &sim.cursor_strength)
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

remaining_sim_enqueue_image_command :: proc(worker: ^Product_Context, kind: Ui_To_Render_Command_Kind, path: string = "") {
	if worker == nil {
		return
	}
	cmd: Ui_To_Render_Command
	cmd.kind = kind
	if len(path) > 0 {
		write_fixed_string(cmd.file_path[:], path)
	}
	_ = engine.queue_try_push(worker.ui_to_render, cmd)
}

// Polls SDL once per render frame. AcquireCameraFrame returns nil until the
// camera has a new frame, so this naturally follows the device cadence (30/60
// fps, etc.) instead of throttling it to a timer.
remaining_sim_webcam_capture_control :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, worker: ^Product_Context, command: Ui_To_Render_Command_Kind, key: string) {
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
		sim.webcam_capture_command = command
		sim.webcam_capture_frames = 0
		write_fixed_string(sim.webcam_capture_status[:], sim.webcam_capture == nil ? "Could not open preferred camera" : "Waiting for camera permission…")
	}
	if !available && sim.webcam_capture == nil {uifw.gui_label(gui, "No webcam devices")}
	status := fixed_string(sim.webcam_capture_status[:])
	if len(status) > 0 {uifw.gui_label(gui, status)}
}

remaining_sim_draw_moire_menu :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, color_editor: ^Color_Scheme_Editor_State, worker: ^Product_Context = nil) {
	remaining_sim_draw_moire_display_settings(sim, gui, color_editor, worker)
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Controls")
	uifw.gui_label(gui, "Mouse wheel: Zoom | Drag: Pan camera")
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Actions")
	remaining_sim_draw_settings_actions(sim, gui, "Reset Moire Settings")
	uifw.gui_spacer(gui, 8)
	remaining_sim_draw_moire_animation(sim, gui)
	uifw.gui_spacer(gui, 8)
	remaining_sim_draw_moire_patterns(sim, gui)
	if sim.moire.generator_type == .Radial {
		uifw.gui_spacer(gui, 8)
		remaining_sim_draw_moire_radial(sim, gui)
	}
	uifw.gui_spacer(gui, 8)
	remaining_sim_draw_moire_advection(sim, gui)
}

remaining_sim_draw_moire_display_settings :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, color_editor: ^Color_Scheme_Editor_State, worker: ^Product_Context = nil) {
	settings := &sim.moire
	uifw.gui_heading(gui, "Display Settings")
	_ = color_scheme_editor_draw_selector(gui, color_editor, "moire_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Image Mode: %v", settings.image_mode_enabled), "image_mode", &settings.image_mode_enabled)
	if !settings.image_mode_enabled {
		return
	}
	if uifw.gui_selector(gui, fmt.tprintf("Interference Mode: %s", MOIRE_INTERFERENCE_MODE_NAMES[settings.interference_index]), "image_interference", &settings.interference_index, MOIRE_INTERFERENCE_MODE_NAMES[:]) {
		settings.image_interference_mode = Moire_Image_Interference_Mode(settings.interference_index)
	}
	image_options := shared_default_image_selector_options()
	image_options.fit_label = "Image Fit"
	image_options.fit_key = "moire_image_fit"
	image_options.load_label = "Reload Selected"
	image_options.load_key = "moire_load_png"
	image_options.browse_label = "Choose Image..."
	image_options.browse_key = "moire_browse_png"
	image_options.clear_key = "moire_clear_image"
	image_options.selected_label = "Selected Image"
	image_options.empty_label = fmt.tprintf("No image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
	image_options.selected_path = fixed_string(settings.image_path[:])
	image_result := shared_image_selector(gui, &settings.image_fit_index, VECTOR_IMAGE_FIT_MODE_NAMES[:], image_options)
	remaining_sim_webcam_capture_control(sim, gui, worker, .Load_Moire_Image, "moire_capture_webcam")
	reload_image := false
	if image_result.fit_changed {
		settings.image_fit_mode = Vector_Image_Fit_Mode(settings.image_fit_index)
		reload_image = true
	}
	if image_result.browse_requested {
		sim.moire_image_dialog_requested = true
	}
	if image_result.load_requested || reload_image {
		remaining_sim_enqueue_image_command(worker, .Load_Moire_Image, fixed_string(settings.image_path[:]))
	}
	if image_result.clear_requested {
		remaining_sim_enqueue_image_command(worker, .Clear_Moire_Image)
	}
	_ = uifw.gui_toggle(gui, fmt.tprintf("Mirror Horizontal: %v", settings.image_mirror_horizontal), "mirror_h", &settings.image_mirror_horizontal)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Mirror Vertical: %v", settings.image_mirror_vertical), "mirror_v", &settings.image_mirror_vertical)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Invert Tone: %v", settings.image_invert_tone), "invert_tone", &settings.image_invert_tone)
}

remaining_sim_draw_moire_animation :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context) {
	settings := &sim.moire
	uifw.gui_heading(gui, "Animation")
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Speed: %.2f", settings.speed), "moire_speed", &settings.speed, 0.01, 0, 5)
}

remaining_sim_draw_moire_patterns :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context) {
	settings := &sim.moire
	uifw.gui_heading(gui, "Moire Patterns")
	if uifw.gui_selector(gui, fmt.tprintf("Generator Type: %s", MOIRE_GENERATOR_TYPE_NAMES[settings.generator_index]), "generator_type", &settings.generator_index, MOIRE_GENERATOR_TYPE_NAMES[:]) {
		settings.generator_type = Moire_Generator_Type(settings.generator_index)
	}
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Base Frequency: %.2f", settings.base_freq), "base_freq", &settings.base_freq, 0.1, 0.1, 80)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Moire Amount: %.2f", settings.moire_amount), "moire_amount", &settings.moire_amount, 0.01, 0, 2)
	rotation_two_degrees := settings.moire_rotation * 180 / math.PI
	if shared_two_axis_pad_f32(gui, "Second Layer Transform", "moire_layer_two", "Rotation °", "Scale", &rotation_two_degrees, &settings.moire_scale, -360, 360, 0.1, 4) {
		settings.moire_rotation = rotation_two_degrees * math.PI / 180
	}
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Interference: %.2f", settings.moire_interference), "moire_interference", &settings.moire_interference, 0.01, 0, 1)
	rotation_three_degrees := settings.moire_rotation3 * 180 / math.PI
	if shared_two_axis_pad_f32(gui, "Third Layer Transform", "moire_layer_three", "Rotation °", "Scale", &rotation_three_degrees, &settings.moire_scale3, -360, 360, 0.1, 4) {
		settings.moire_rotation3 = rotation_three_degrees * math.PI / 180
	}
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Weight 3: %.2f", settings.moire_weight3), "moire_weight3", &settings.moire_weight3, 0.01, 0, 1)
}

remaining_sim_draw_moire_radial :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context) {
	settings := &sim.moire
	uifw.gui_heading(gui, "Radial Pattern Settings")
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Swirl: %.2f", settings.radial_swirl_strength), "radial_swirl", &settings.radial_swirl_strength, 0.01, 0, 1)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Starburst: %.1f", settings.radial_starburst_count), "radial_starburst", &settings.radial_starburst_count, 0.5, 1, 64)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Center Brightness: %.2f", settings.radial_center_brightness), "radial_center", &settings.radial_center_brightness, 0.01, 0, 4)
}

remaining_sim_draw_moire_advection :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context) {
	settings := &sim.moire
	uifw.gui_heading(gui, "Advection Flow")
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Advect Strength: %.2f", settings.advect_strength), "advect_strength", &settings.advect_strength, 0.01, 0, 2)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Advect Speed: %.2f", settings.advect_speed), "advect_speed", &settings.advect_speed, 0.01, 0, 5)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Curl: %.2f", settings.curl), "curl", &settings.curl, 0.01, 0, 2)
	shared_control_explanation(gui, "curl", "Curl controls how strongly the flow bends into swirls and rolling eddies.")
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Decay: %.2f", settings.decay), "decay", &settings.decay, 0.001, 0.8, 1)
}

remaining_sim_draw_vectors_menu :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, color_editor: ^Color_Scheme_Editor_State, worker: ^Product_Context = nil) {
	remaining_sim_draw_vectors_color(sim, gui, color_editor)
	uifw.gui_spacer(gui, 8)
	remaining_sim_draw_vectors_field(sim, gui, worker)
}

remaining_sim_draw_vectors_color :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, color_editor: ^Color_Scheme_Editor_State) {
	settings := &sim.vectors
	uifw.gui_heading(gui, "Color")
	if uifw.gui_selector(gui, fmt.tprintf("Background: %s", VECTOR_BACKGROUND_MODE_NAMES[settings.background_index]), "vectors_background", &settings.background_index, VECTOR_BACKGROUND_MODE_NAMES[:]) {
		settings.background_color_mode = Vector_Background_Mode(settings.background_index)
	}
	_ = color_scheme_editor_draw_selector(gui, color_editor, "vectors_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
}

remaining_sim_draw_vectors_field :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, worker: ^Product_Context = nil) {
	settings := &sim.vectors
	uifw.gui_heading(gui, "Vector Field")
	if uifw.gui_selector(gui, fmt.tprintf("Vector Field: %s", VECTOR_FIELD_TYPE_NAMES[settings.vector_field_index]), "vector_field", &settings.vector_field_index, VECTOR_FIELD_TYPE_NAMES[:]) {
		settings.vector_field_type = Vector_Field_Type(settings.vector_field_index)
	}
	if settings.vector_field_type == .Image {
		image_options := shared_default_image_selector_options()
		image_options.fit_label = "Image Fit"
		image_options.fit_key = "vector_image_fit"
		image_options.load_label = "Reload Selected"
		image_options.load_key = "vector_load_png"
		image_options.browse_label = "Choose Image..."
		image_options.browse_key = "vector_browse_png"
		image_options.clear_key = "vector_clear_image"
		image_options.selected_label = "Selected Image"
		image_options.empty_label = fmt.tprintf("No image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
		image_options.selected_path = fixed_string(settings.image_path[:])
		image_result := shared_image_selector(gui, &settings.image_fit_index, VECTOR_IMAGE_FIT_MODE_NAMES[:], image_options)
		remaining_sim_webcam_capture_control(sim, gui, worker, .Load_Vectors_Image, "vectors_capture_webcam")
		if image_result.fit_changed {
			settings.image_fit_mode = Vector_Image_Fit_Mode(settings.image_fit_index)
		}
		if image_result.browse_requested {
			sim.vectors_image_dialog_requested = true
		}
		if image_result.load_requested {
			remaining_sim_enqueue_image_command(worker, .Load_Vectors_Image, fixed_string(settings.image_path[:]))
		}
		if image_result.clear_requested {
			remaining_sim_enqueue_image_command(worker, .Clear_Vectors_Image)
		}
		_ = uifw.gui_toggle(gui, fmt.tprintf("Mirror Horizontal: %v", settings.image_mirror_horizontal), "vector_mirror_h", &settings.image_mirror_horizontal)
		_ = uifw.gui_toggle(gui, fmt.tprintf("Mirror Vertical: %v", settings.image_mirror_vertical), "vector_mirror_v", &settings.image_mirror_vertical)
		_ = uifw.gui_toggle(gui, fmt.tprintf("Invert Tone: %v", settings.image_invert_tone), "vector_invert", &settings.image_invert_tone)
	} else if settings.vector_field_type == .Noise {
		_ = draw_noise_settings_controls(gui, &settings.noise, "vectors_noise")
	}
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Density: %.3f", settings.density), "vector_density", &settings.density, 0.001, VECTORS_MIN_DENSITY, 0.1)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Line Length: %.3f", settings.line_length), "line_length", &settings.line_length, 0.001, 0.005, 1)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Line Width: %.3f", settings.line_width), "line_width", &settings.line_width, 0.001, 0.001, 1)
	if uifw.gui_button(gui, "Reset", "vectors_reset") {
		remaining_sim_reset_with_undo(sim)
		uifw.gui_notice(gui, "Vector field returned to defaults. Restore Settings Before Reset is available here.")
	}
	if sim.reset_undo.available && uifw.gui_button(gui, "Restore Settings Before Reset", "vectors_undo_reset") {
		if remaining_sim_undo_reset(sim) {
			uifw.gui_notice(gui, "Vector settings from before reset restored.")
		}
	}
}

remaining_sim_draw_primordial_settings :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, subsection := -1) {
	settings := &sim.primordial
	if subsection < 0 || subsection == 0 {
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, subsection == 0 ? "Population" : "Particle Configuration")
	if uifw.gui_selector(gui, fmt.tprintf("Position Generator: %s", PRIMORDIAL_POSITION_GENERATOR_NAMES[settings.position_generator_index]), "primordial_position_generator", &settings.position_generator_index, PRIMORDIAL_POSITION_GENERATOR_NAMES[:]) {
		settings.position_generator = u32(settings.position_generator_index)
	}
	count := f32(settings.particle_count)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Particle Count: %d", settings.particle_count), "primordial_particle_count", &count, 100, 100, 500000) {
		settings.particle_count = u32(count)
	}
	seed := f32(settings.random_seed)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Random Seed: %d", settings.random_seed), "primordial_seed", &seed, 1, 0, 4294967295) {
		settings.random_seed = u32(seed)
	}
	}
	if subsection < 0 || subsection == 1 {
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, subsection == 1 ? "Motion" : "Physics Parameters")
	_ = shared_two_axis_pad_f32(gui, "Rotation Response", "primordial_rotation", "Alpha", "Beta", &settings.alpha, &settings.beta, -180, 180, -60, 60)
	shared_control_explanation(gui, "primordial_rotation", "Alpha and Beta are the two rotation-response angles. Together they decide how particles turn around neighbors.")
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Velocity: %.2f", settings.velocity), "velocity", &settings.velocity, 0.01, 0.01, 2)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Radius: %.3f", settings.radius), "radius", &settings.radius, 0.001, 0.001, 0.5)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Time Step: %.3f", settings.dt), "primordial_dt", &settings.dt, 0.001, 0, 0.25)
	shared_control_explanation(gui, "primordial_dt", "Time Step is how much simulated time moves forward per update. Higher is faster but less precise.")
	_ = uifw.gui_toggle(gui, fmt.tprintf("Wrap Edges: %v", settings.wrap_edges), "wrap_edges", &settings.wrap_edges)
	}
}

remaining_sim_draw_voronoi_settings :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, heading := "Voronoi Parameters") {
	settings := &sim.voronoi
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, heading)
	point_count := f32(settings.point_count)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Points: %d", settings.point_count), "voronoi_points", &point_count, 100, 32, 20000) {
		settings.point_count = u32(point_count)
	}
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Drift: %.2f", settings.drift), "voronoi_drift", &settings.drift, 0.01, 0, 4)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Brownian Speed: %.1f", settings.brownian_speed), "voronoi_brownian_speed", &settings.brownian_speed, 1, 0, 500)
	shared_control_explanation(gui, "voronoi_brownian_speed", "Brownian Speed adds random wandering to the sites that shape the Voronoi cells.")
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Time Scale: %.2f", settings.time_scale), "voronoi_time_scale", &settings.time_scale, 0.01, 0, 10)
	seed := f32(settings.random_seed)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Random Seed: %d", settings.random_seed), "random_seed", &seed, 1, 0, 4294967295) {
		settings.random_seed = u32(seed)
	}
}

remaining_sim_draw_pellets_settings :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, subsection := -1) {
	settings := &sim.pellets
	if subsection < 0 || subsection == 0 {
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Particle")
	count := f32(settings.particle_count)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Particle Count: %d", settings.particle_count), "particle_count", &count, 100, 100, 500000) {
		settings.particle_count = u32(count)
	}
	seed := f32(settings.random_seed)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Random Seed: %d", settings.random_seed), "pellets_seed", &seed, 1, 0, 4294967295) {
		settings.random_seed = u32(seed)
	}
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Particle Size: %.3f", settings.particle_size), "particle_size", &settings.particle_size, 0.001, 0.001, 0.1)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Collision Damping: %.2f", settings.collision_damping), "collision_damping", &settings.collision_damping, 0.01, 0, 1)
	_ = shared_range_slider_f32(gui, "Initial Velocity", "pellets_initial_velocity", &settings.initial_velocity_min, &settings.initial_velocity_max, 0, 2)
	}
	if subsection < 0 || subsection == 1 {
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Physics")
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Gravity Constant: %.7f", settings.gravitational_constant), "gravity_constant", &settings.gravitational_constant, 0.0000001, 0, 0.1)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Energy Damping: %.2f", settings.energy_damping), "energy_damping", &settings.energy_damping, 0.01, 0, 1)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Gravity Softening: %.3f", settings.gravity_softening), "gravity_softening", &settings.gravity_softening, 0.001, 0.0001, 0.1)
	shared_control_explanation(gui, "gravity_softening", "Gravity Softening prevents gravity from becoming extreme when pellets get very close.")
	_ = uifw.gui_toggle(gui, fmt.tprintf("Density Damping: %v", settings.density_damping_enabled), "density_damping", &settings.density_damping_enabled)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Overlap Resolution: %.2f", settings.overlap_resolution_strength), "overlap_resolution", &settings.overlap_resolution_strength, 0.01, 0, 1)
	}
}

remaining_sim_draw_flow_settings :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, worker: ^Product_Context = nil, subsection := -1) {
	settings := &sim.flow
	if subsection < 0 || subsection == 0 {
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Flow Field")
	if uifw.gui_selector(gui, fmt.tprintf("Vector Field: %s", VECTOR_FIELD_TYPE_NAMES[settings.vector_field_index]), "flow_vector_field", &settings.vector_field_index, VECTOR_FIELD_TYPE_NAMES[:]) {
		settings.vector_field_type = Vector_Field_Type(settings.vector_field_index)
	}
	if settings.vector_field_type == .Noise {
		_ = draw_noise_settings_controls(gui, &settings.noise, "flow_noise")
	}
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Vector Magnitude: %.2f", settings.vector_magnitude), "vector_magnitude", &settings.vector_magnitude, 0.01, 0, 2)
	if settings.vector_field_type == .Image {
		image_options := shared_default_image_selector_options()
		image_options.fit_label = "Image Fit"
		image_options.fit_key = "flow_image_fit"
		image_options.load_label = "Reload Selected"
		image_options.load_key = "flow_load_png"
		image_options.browse_label = "Choose Image..."
		image_options.browse_key = "flow_browse_png"
		image_options.clear_key = "flow_clear_image"
		image_options.selected_label = "Selected Image"
		image_options.empty_label = fmt.tprintf("No image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
		image_options.selected_path = fixed_string(settings.image_path[:])
		image_result := shared_image_selector(gui, &settings.image_fit_index, VECTOR_IMAGE_FIT_MODE_NAMES[:], image_options)
		remaining_sim_webcam_capture_control(sim, gui, worker, .Load_Flow_Image, "flow_capture_webcam")
		reload_image := false
		if image_result.fit_changed {
			settings.image_fit_mode = Vector_Image_Fit_Mode(settings.image_fit_index)
			reload_image = true
		}
		if image_result.browse_requested {
			sim.flow_image_dialog_requested = true
		}
		if image_result.load_requested {
			reload_image = true
		}
		if uifw.gui_toggle(gui, fmt.tprintf("Mirror Horizontal: %v", settings.image_mirror_horizontal), "flow_mirror_h", &settings.image_mirror_horizontal) {
			reload_image = true
		}
		if uifw.gui_toggle(gui, fmt.tprintf("Mirror Vertical: %v", settings.image_mirror_vertical), "flow_mirror_v", &settings.image_mirror_vertical) {
			reload_image = true
		}
		if uifw.gui_toggle(gui, fmt.tprintf("Invert Tone: %v", settings.image_invert_tone), "flow_invert", &settings.image_invert_tone) {
			reload_image = true
		}
		if reload_image {
			remaining_sim_enqueue_image_command(worker, .Load_Flow_Image, fixed_string(settings.image_path[:]))
		}
		if image_result.clear_requested {
			remaining_sim_enqueue_image_command(worker, .Clear_Flow_Image)
		}
	}
	}
	if subsection < 0 || subsection == 1 {
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Particles")
	if uifw.gui_selector(gui, fmt.tprintf("Shape: %s", FLOW_PARTICLE_SHAPE_NAMES[settings.shape_index]), "flow_shape", &settings.shape_index, FLOW_PARTICLE_SHAPE_NAMES[:]) {
		settings.particle_shape = Flow_Particle_Shape(settings.shape_index)
	}
	pool := f32(settings.total_pool_size)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Pool Size: %d", settings.total_pool_size), "flow_pool", &pool, 1000, 100, 1000000) {
		settings.total_pool_size = u32(pool)
	}
	lifetime := settings.particle_lifetime
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Lifetime: %.2f", lifetime), "flow_lifetime", &settings.particle_lifetime, 0.1, 0.1, 60)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Particle Speed: %.2f", settings.particle_speed), "flow_speed", &settings.particle_speed, 0.01, 0, 10)
	size := f32(settings.particle_size)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Particle Size: %d", settings.particle_size), "flow_size", &size, 1, 1, 64) {
		settings.particle_size = u32(size)
	}
	_ = uifw.gui_toggle(gui, fmt.tprintf("Autospawn: %v", settings.particle_autospawn), "flow_autospawn", &settings.particle_autospawn)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Show Particles: %v", settings.show_particles), "flow_show_particles", &settings.show_particles)
	auto_rate := f32(settings.autospawn_rate)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Autospawn Rate: %d", settings.autospawn_rate), "flow_autospawn_rate", &auto_rate, 10, 0, 100000) {
		settings.autospawn_rate = u32(auto_rate)
	}
	brush_rate := f32(settings.brush_spawn_rate)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Brush Spawn Rate: %d", settings.brush_spawn_rate), "flow_brush_rate", &brush_rate, 10, 0, 100000) {
		settings.brush_spawn_rate = u32(brush_rate)
	}
	}
	if subsection < 0 || subsection == 2 {
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Trails")
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Decay: %.2f", settings.trail_decay_rate), "trail_decay", &settings.trail_decay_rate, 0.01, 0, 10)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Deposition: %.2f", settings.trail_deposition_rate), "trail_deposition", &settings.trail_deposition_rate, 0.01, 0, 10)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Diffusion: %.2f", settings.trail_diffusion_rate), "trail_diffusion", &settings.trail_diffusion_rate, 0.01, 0, 10)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Wash Out: %.2f", settings.trail_wash_out_rate), "trail_wash_out", &settings.trail_wash_out_rate, 0.01, 0, 10)
	if uifw.gui_selector(gui, fmt.tprintf("Filtering: %s", FLOW_TRAIL_MAP_FILTERING_NAMES[settings.trail_filtering_index]), "flow_trail_filtering", &settings.trail_filtering_index, FLOW_TRAIL_MAP_FILTERING_NAMES[:]) {
		settings.trail_map_filtering = Flow_Trail_Map_Filtering(settings.trail_filtering_index)
	}
	}
}

remaining_sim_draw_slime_settings :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, worker: ^Product_Context = nil) {
	settings := &sim.slime
	if uifw.gui_selector(gui, fmt.tprintf("Trail Filtering: %s", FLOW_TRAIL_MAP_FILTERING_NAMES[settings.trail_filtering_index]), "slime_trail_filtering", &settings.trail_filtering_index, FLOW_TRAIL_MAP_FILTERING_NAMES[:]) {
		settings.trail_map_filtering = Flow_Trail_Map_Filtering(settings.trail_filtering_index)
	}
	seed := f32(settings.random_seed)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Random Seed: %d", settings.random_seed), "slime_seed", &seed, 1, 0, 4294967295) {
		settings.random_seed = u32(seed)
	}
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Pheromone")
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Decay Rate: %.1f", settings.pheromone_decay_rate), "pheromone_decay", &settings.pheromone_decay_rate, 1, 0, 200)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Deposition Rate: %.1f", settings.pheromone_deposition_rate), "pheromone_deposition", &settings.pheromone_deposition_rate, 1, 0, 200)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Diffusion Rate: %.1f", settings.pheromone_diffusion_rate), "pheromone_diffusion", &settings.pheromone_diffusion_rate, 1, 0, 200)
	diffusion := f32(settings.diffusion_frequency)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Diffusion Frequency: %d", settings.diffusion_frequency), "diffusion_frequency", &diffusion, 1, 1, 128) {
		settings.diffusion_frequency = u32(diffusion)
	}
	decay := f32(settings.decay_frequency)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Decay Frequency: %d", settings.decay_frequency), "decay_frequency", &decay, 1, 1, 128) {
		settings.decay_frequency = u32(decay)
	}
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Agent")
	if uifw.gui_selector(gui, fmt.tprintf("Position Generator: %s", SLIME_POSITION_GENERATOR_NAMES[settings.position_generator_index]), "slime_position_generator", &settings.position_generator_index, SLIME_POSITION_GENERATOR_NAMES[:]) {
		settings.position_generator = u32(settings.position_generator_index)
	}
	if settings.position_generator == 7 {
		position_options := shared_default_image_selector_options()
		position_options.fit_label = "Position Image Fit"
		position_options.fit_key = "slime_position_image_fit"
		position_options.load_label = "Reload Selected"
		position_options.load_key = "slime_position_load_png"
		position_options.browse_label = "Choose Image..."
		position_options.browse_key = "slime_position_browse_png"
		position_options.clear_key = "slime_position_clear_image"
		position_options.selected_label = "Selected Position Image"
		position_options.empty_label = fmt.tprintf("No position image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
		position_options.selected_path = fixed_string(settings.position_image_path[:])
		position_result := shared_image_selector(gui, &settings.position_image_fit_index, VECTOR_IMAGE_FIT_MODE_NAMES[:], position_options)
		remaining_sim_webcam_capture_control(sim, gui, worker, .Load_Slime_Position_Image, "slime_position_capture_webcam")
		reload_position_image := false
		if position_result.fit_changed {
			settings.position_image_fit_mode = Vector_Image_Fit_Mode(settings.position_image_fit_index)
			reload_position_image = true
		}
		if position_result.browse_requested {
			sim.slime_position_image_dialog_requested = true
		}
		if position_result.load_requested || reload_position_image {
			remaining_sim_enqueue_image_command(worker, .Load_Slime_Position_Image, fixed_string(settings.position_image_path[:]))
		}
		if position_result.clear_requested {
			remaining_sim_enqueue_image_command(worker, .Clear_Slime_Position_Image)
		}
	}
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Jitter: %.2f", settings.agent_jitter), "agent_jitter", &settings.agent_jitter, 0.01, 0, 1)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Heading Start: %.1f", settings.agent_heading_start), "heading_start", &settings.agent_heading_start, 1, 0, 360)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Heading End: %.1f", settings.agent_heading_end), "heading_end", &settings.agent_heading_end, 1, 0, 360)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Sensor Angle: %.2f", settings.agent_sensor_angle), "sensor_angle", &settings.agent_sensor_angle, 0.01, 0, 3.14159)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Sensor Distance: %.1f", settings.agent_sensor_distance), "sensor_distance", &settings.agent_sensor_distance, 1, 0, 500)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Speed Min: %.1f", settings.agent_speed_min), "speed_min", &settings.agent_speed_min, 1, 0, 500)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Speed Max: %.1f", settings.agent_speed_max), "speed_max", &settings.agent_speed_max, 1, 0, 500)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Turn Rate: %.2f", settings.agent_turn_rate), "turn_rate", &settings.agent_turn_rate, 0.01, 0, 6.28318)
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Mask")
	if uifw.gui_selector(gui, fmt.tprintf("Pattern: %s", SLIME_MASK_PATTERN_NAMES[settings.mask_pattern_index]), "slime_mask_pattern", &settings.mask_pattern_index, SLIME_MASK_PATTERN_NAMES[:]) {
		settings.mask_pattern = Slime_Mask_Pattern(settings.mask_pattern_index)
	}
	if uifw.gui_selector(gui, fmt.tprintf("Target: %s", SLIME_MASK_TARGET_NAMES[settings.mask_target_index]), "slime_mask_target", &settings.mask_target_index, SLIME_MASK_TARGET_NAMES[:]) {
		settings.mask_target = Slime_Mask_Target(settings.mask_target_index)
	}
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Strength: %.2f", settings.mask_strength), "slime_mask_strength", &settings.mask_strength, 0.01, 0, 1)
	_ = uifw.gui_number_drag_f32(gui, fmt.tprintf("Curve: %.2f", settings.mask_curve), "slime_mask_curve", &settings.mask_curve, 0.01, 0.1, 4)
	if settings.mask_pattern == .Image {
		mask_options := shared_default_image_selector_options()
		mask_options.fit_label = "Mask Image Fit"
		mask_options.fit_key = "slime_mask_image_fit"
		mask_options.load_label = "Reload Selected"
		mask_options.load_key = "slime_mask_load_png"
		mask_options.browse_label = "Choose Image..."
		mask_options.browse_key = "slime_mask_browse_png"
		mask_options.clear_key = "slime_mask_clear_image"
		mask_options.selected_label = "Selected Mask Image"
		mask_options.empty_label = fmt.tprintf("No mask image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
		mask_options.selected_path = fixed_string(settings.mask_image_path[:])
		mask_result := shared_image_selector(gui, &settings.mask_image_fit_index, VECTOR_IMAGE_FIT_MODE_NAMES[:], mask_options)
		remaining_sim_webcam_capture_control(sim, gui, worker, .Load_Slime_Mask_Image, "slime_mask_capture_webcam")
		reload_mask_image := false
		if mask_result.fit_changed {
			settings.mask_image_fit_mode = Vector_Image_Fit_Mode(settings.mask_image_fit_index)
			reload_mask_image = true
		}
		if mask_result.browse_requested {
			sim.slime_mask_image_dialog_requested = true
		}
		if mask_result.load_requested || reload_mask_image {
			remaining_sim_enqueue_image_command(worker, .Load_Slime_Mask_Image, fixed_string(settings.mask_image_path[:]))
		}
		if mask_result.clear_requested {
			remaining_sim_enqueue_image_command(worker, .Clear_Slime_Mask_Image)
		}
	}
	_ = uifw.gui_toggle(gui, fmt.tprintf("Mirror Horizontal: %v", settings.mask_mirror_horizontal), "slime_mask_mirror_h", &settings.mask_mirror_horizontal)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Mirror Vertical: %v", settings.mask_mirror_vertical), "slime_mask_mirror_v", &settings.mask_mirror_vertical)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Invert Tone: %v", settings.mask_invert_tone), "slime_mask_invert", &settings.mask_invert_tone)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Reverse Mask: %v", settings.mask_reversed), "slime_mask_reversed", &settings.mask_reversed)
}
