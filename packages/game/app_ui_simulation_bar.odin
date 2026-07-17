package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"
import "core:math"

app_ui_draw_simulation_bar :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, mode: App_Mode, gray_scott: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation, remaining: ^Remaining_Sim_State, paused, loading: bool, simulation_name: string, viewport: uifw.Vec2, width: f32, worker: ^Product_Context) {
	height := f32(gui.input.window_height)
	if viewport.y > 0 {
		height = viewport.y
	}
	if height <= 0 {height = f32(720)}
	bar := app_ui_simulation_chrome_rect(ui, gui, mode, width, height)
	radius := max(gui.style.radius_control * 2, f32(8))
	uifw.gui_shadow(gui, bar, radius, {0, 6}, 18, {0, 0, 0, 0.36})
	uifw.gui_round_rect(gui, bar, radius, {0.025, 0.035, 0.05, 0.52})
	glass := uifw.gui_default_glass_style(gui, radius)
	glass.tint = {0.06, 0.08, 0.10, 0.68}
	glass.roughness = 0.58
	glass.thickness = max(gui.style.rhythm * 0.20, f32(8))
	glass.bevel = max(gui.style.border_width * 6, f32(6))
	glass.border = 0.32
	glass.highlight = 0.38
	uifw.gui_refractive_glass_rect(gui, bar, glass)
	uifw.gui_round_stroke(gui, bar, radius, {1, 1, 1, 0.16}, gui.style.border_width)

	header_h := app_ui_simulation_bar_height(gui)
	pad := gui.style.spacing_1
	gap := max(gui.style.spacing_1, gui.style.border_width * 2)
	content := uifw.Rect{bar.x + pad, bar.y + pad, max(bar.w - pad * 2, 1), max(header_h - pad * 2, 1)}
	button_h := content.h
	back_label := "Menu"
	help_label := "Help"
	pause_label := paused ? "Resume" : "Pause"
	record_visible := worker != nil && app_ui_mode_allows_video_recording(mode)
	record_label := app_ui_video_recording_button_label(ui)
	record_display_label := record_label
	if content.w < f32(760) {
		if ui.video_recording_state == .Recording {record_display_label = "Stop"} else {record_display_label = "Rec"}
		if paused {pause_label = "Play"}
	}
	back_w := uifw.gui_button_content_width(gui, back_label)
	help_w := uifw.gui_button_content_width(gui, help_label)
	pause_w := uifw.gui_button_content_width(gui, pause_label)
	record_w := record_visible ? uifw.gui_button_content_width(gui, record_display_label) : f32(0)
	button_count := record_visible ? 4 : 3
	natural_buttons_w := back_w + help_w + pause_w + record_w
	info_reserve := min(max(content.w * 0.26, gui.style.row_height * 1.65), content.w * 0.42)
	buttons_available := max(content.w - info_reserve - gap * f32(button_count), f32(button_count))
	shrink := min(buttons_available / max(natural_buttons_w, 1), f32(1))
	back_w *= shrink
	help_w *= shrink
	pause_w *= shrink
	record_w *= shrink
	x := content.x
	back_rect := uifw.Rect{x, content.y, back_w, button_h}
	x += back_w + gap
	help_rect := uifw.Rect{x, content.y, help_w, button_h}
	x += help_w + gap
	pause_rect := uifw.Rect{x, content.y, pause_w, button_h}
	x += pause_w
	record_rect: uifw.Rect
	if record_visible {
		x += gap
		record_rect = {x, content.y, record_w, button_h}
		x += record_w
	}

	uifw.gui_push_id(gui, "simulation_bar")
	if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "back"), back_rect, back_label, true, false) {
		app_ui_video_recording_stop(ui, worker)
		app_ui_navigate(ui, .Main_Menu)
	}
	if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "help"), help_rect, help_label, true, false) {
		app_ui_open_controls_help(ui, gui)
	}
	if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "pause"), pause_rect, pause_label, true, false) {
		app_ui_simulation_set_paused(ui, mode, !paused)
	}
	if paused {
		uifw.gui_round_stroke(gui, pause_rect, gui.style.radius_control, uifw.gui_apply_opacity(gui.style.accent, 0.62), max(gui.style.border_width * 1.5, 1.5))
	}
	if record_visible {
		if ui.video_recording_state == .Restoring_Fullscreen {
			uifw.gui_text_aligned(gui, app_ui_simulation_bar_text_rect(gui, record_rect), record_display_label, gui.style.text_muted, .Center)
		} else if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "record"), record_rect, record_display_label, true, false) {
			app_ui_video_recording_toggle(ui, worker)
		}
		if ui.video_recording_state == .Recording {
			uifw.gui_round_stroke(gui, record_rect, gui.style.radius_control, uifw.gui_apply_opacity(gui.style.danger, 0.82), max(gui.style.border_width * 1.5, 1.5))
		}
	}
	info_x := x + gap
	info_rect := uifw.Rect{info_x, content.y, max(content.x + content.w - info_x, 1), content.h}
	app_ui_draw_simulation_bar_info(gui, info_rect, simulation_name, paused, loading, ui.last_stats.fps)
	uifw.gui_pop_id(gui)

	if slime_controller_ui_enabled(ui) || simulation_controller_ui_enabled(ui) {
		line_y := bar.y + header_h - gui.style.border_width
		uifw.gui_rect(gui, {bar.x + pad * 2, line_y, max(bar.w - pad * 4, 1), gui.style.border_width}, {1, 1, 1, 0.12})
	}
}

app_ui_draw_simulation_bar_info :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, simulation_name: string, paused, loading: bool, fps: f32) {
	if rect.w <= 1 {return}
	status := loading ? "Loading" : (paused ? "Paused" : "Running")
	status_color := uifw.Color{0.32, 0.88, 0.58, 1}
	if paused {status_color = {0.98, 0.70, 0.28, 1}}
	if loading {status_color = gui.style.accent}
	fps_label := fmt.tprintf("%.0f FPS", fps)
	text_rect := app_ui_simulation_bar_text_rect(gui, rect)
	// Reserve the configured four-digit range so FPS fluctuations do not move
	// the status badge or simulation name as the displayed digit count changes.
	fps_w := min(max(uifw.gui_text_width(gui, "0000 FPS") + gui.style.spacing_1 * 2, gui.style.row_height), rect.w)
	fps_rect := uifw.Rect{rect.x + rect.w - fps_w, text_rect.y, fps_w, text_rect.h}
	uifw.gui_text_right(gui, fps_rect, fps_label, gui.style.text_muted)
	remaining_w := max(rect.w - fps_w - gui.style.spacing_1, 0)
	status_w := uifw.gui_text_width(gui, status) + gui.style.spacing_1 * 4 + max(gui.style.border_width * 6, f32(6))
	if remaining_w >= status_w {
		status_rect := uifw.Rect{rect.x + remaining_w - status_w, rect.y + max((rect.h - gui.style.body_line_height) * 0.5, 0), status_w, min(gui.style.body_line_height, rect.h)}
		uifw.gui_round_rect(gui, status_rect, status_rect.h * 0.5, uifw.gui_apply_opacity(status_color, 0.13))
		dot_size := max(gui.style.border_width * 6, f32(6))
		dot := uifw.Rect{status_rect.x + gui.style.spacing_1, status_rect.y + (status_rect.h - dot_size) * 0.5, dot_size, dot_size}
		uifw.gui_ellipse(gui, dot, status_color)
		status_text := uifw.Rect{dot.x + dot.w + gui.style.spacing_1, status_rect.y, max(status_rect.x + status_rect.w - dot.x - dot.w - gui.style.spacing_1 * 2, 1), status_rect.h}
		uifw.gui_text_aligned(gui, status_text, status, gui.style.text, .Left)
		remaining_w = max(remaining_w - status_w - gui.style.spacing_1, 0)
	}
	if remaining_w >= gui.style.body_char_width * 4 {
		name_rect := uifw.Rect{rect.x, text_rect.y, remaining_w, text_rect.h}
		uifw.gui_scissor_begin(gui, name_rect)
		uifw.gui_text_aligned(gui, name_rect, simulation_name, gui.style.text, .Left)
		uifw.gui_scissor_end(gui)
	}
}

app_ui_simulation_chrome_rect :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, mode: App_Mode, width, height: f32) -> uifw.Rect {
	if mode == .Slime_Mold && ui != nil {
		return slime_controller_ui_deck_rect(gui, width, height, ui.slime_controller.mode)
	}
	if _, ok := simulation_controller_ui_state_index(mode); ok {
		return simulation_controller_ui_deck_rect(gui, width, height, len(simulation_controller_ui_tabs(mode)))
	}
	margin := max(gui.style.spacing_3, f32(18))
	bar_h := app_ui_simulation_bar_height(gui)
	target_w := max(width * 0.62, gui.style.body_char_width * 30)
	bar_w := min(target_w, max(width - margin * 2, 1))
	return {max((width - bar_w) * 0.5, margin), max(height - bar_h - margin, margin), bar_w, bar_h}
}

app_ui_focus_simulation_bar_pause :: proc(gui: ^uifw.Gui_Context) {
	uifw.gui_push_id(gui, "simulation_bar")
	gui.focused = uifw.gui_make_id(gui, "pause")
	uifw.gui_pop_id(gui)
}

app_ui_focus_simulation_bar_back :: proc(gui: ^uifw.Gui_Context) {
	uifw.gui_push_id(gui, "simulation_bar")
	gui.focused = uifw.gui_make_id(gui, "back")
	uifw.gui_pop_id(gui)
}

app_ui_simulation_bar_text_rect :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect) -> uifw.Rect {
	return {rect.x, rect.y + max((rect.h - gui.style.body_text_height) * 0.5, 0), rect.w, gui.style.body_text_height}
}

app_ui_video_recording_button_label :: proc(ui: ^App_Ui_State) -> string {
	#partial switch ui.video_recording_state {
	case .Choosing_Path:
		return "Choosing..."
	case .Restoring_Fullscreen:
		return "Restoring..."
	case .Recording:
		return "Stop Recording"
	case:
		return "Record"
	}
}

app_ui_mode_allows_video_recording :: proc(mode: App_Mode) -> bool {
	#partial switch mode {
	case .Slime_Mold, .Gray_Scott, .Particle_Life, .Flow_Field, .Pellets, .ST_FLIP, .Voronoi_CA, .Moire, .Vectors, .Primordial:
		return true
	case:
		return false
	}
}

app_ui_video_recording_toggle :: proc(ui: ^App_Ui_State, worker: ^Product_Context) {
	if worker == nil {
		return
	}
	if ui.video_recording_state == .Recording {
		app_ui_video_recording_stop(ui, worker)
		return
	}
	if ui.video_recording_state != .Choosing_Path {
		ui.video_recording_state = .Choosing_Path
		write_fixed_string(ui.video_recording_status[:], "Choosing recording destination")
	}
	app_ui_video_recording_request_save_dialog(ui, worker)
}

app_ui_video_recording_request_save_dialog :: proc(ui: ^App_Ui_State, worker: ^Product_Context) {
	ui.video_recording_state = .Choosing_Path
	write_fixed_string(ui.video_recording_status[:], "Choosing recording destination")
	msg: Render_To_Ui_Message
	msg.kind = .Request_Video_Save_Dialog
	engine.log_info("video_recording: record clicked; requesting save dialog")
	if !engine.queue_try_push(worker.render_to_ui, msg) {
		engine.log_error("video_recording: failed to queue save dialog request")
		app_ui_video_recording_apply_command_state(ui, .Failed, "Could not open save dialog")
	}
}

app_ui_video_recording_stop :: proc(ui: ^App_Ui_State, worker: ^Product_Context) {
	if worker == nil {
		return
	}
	if ui.video_recording_state == .Recording || ui.video_recording_state == .Choosing_Path || ui.video_recording_state == .Restoring_Fullscreen {
		cmd: Ui_To_Render_Command
		cmd.kind = .Stop_Video_Recording
		_ = engine.queue_try_push(worker.ui_to_render, cmd)
		ui.video_recording_state = .Idle
		write_fixed_string(ui.video_recording_status[:], "")
	}
}

app_ui_video_recording_apply_command_state :: proc(ui: ^App_Ui_State, state: Video_Recording_Ui_State, text: string = "") {
	ui.video_recording_state = state
	write_fixed_string(ui.video_recording_status[:], text)
}

app_ui_simulation_set_paused :: proc(ui: ^App_Ui_State, mode: App_Mode, paused: bool) {
	if ui != nil do _ = feature_instance_set_set_paused(&ui.feature_instances, mode, paused)
}

app_ui_mode_is_simulation :: proc(mode: App_Mode) -> bool {
	descriptor, ok := feature_descriptor_by_mode(mode)
	return ok && feature_has_capability(descriptor, .Simulation)
}

app_mode_from_remaining_sim_kind :: proc(kind: Remaining_Sim_Kind) -> App_Mode {
	#partial switch kind {
	case .Slime_Mold:
		return .Slime_Mold
	case .Flow_Field:
		return .Flow_Field
	case .Pellets:
		return .Pellets
	case .Voronoi_CA:
		return .Voronoi_CA
	case .Moire:
		return .Moire
	case .Vectors:
		return .Vectors
	case .Primordial:
		return .Primordial
	}
	return .Main_Menu
}

remaining_sim_kind_from_app_mode :: proc(mode: App_Mode) -> Remaining_Sim_Kind {
	#partial switch mode {
	case .Slime_Mold: return .Slime_Mold
	case .Flow_Field: return .Flow_Field
	case .Pellets: return .Pellets
	case .Voronoi_CA: return .Voronoi_CA
	case .Moire: return .Moire
	case .Vectors: return .Vectors
	case .Primordial: return .Primordial
	case: return .Slime_Mold
	}
}

app_ui_simulation_reset :: proc(mode: App_Mode, gray_scott: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation) {
	#partial switch mode {
	case .Gray_Scott:
		if gray_scott != nil {
			gray_scott_reset_runtime(gray_scott)
		}
	case .Particle_Life:
		if particle_life != nil {
			particle_life_reset_runtime(particle_life)
		}
	case:
	}
}

app_ui_simulation_randomize :: proc(mode: App_Mode, gray_scott: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation) {
	#partial switch mode {
	case .Gray_Scott:
		if gray_scott != nil {
			gray_scott_randomize_settings(gray_scott)
		}
	case .Particle_Life:
		if particle_life != nil {
			particle_life_randomize_forces(particle_life)
		}
	case:
	}
}

app_ui_draw_loading_overlay :: proc(gui: ^uifw.Gui_Context, width, height: f32, loading: bool) {
	if !loading {
		return
	}
	overlay := uifw.Rect{0, 0, width, height}
	glass := uifw.gui_default_glass_style(gui, 0)
	glass.tint = {0.04, 0.05, 0.07, 0.56}
	glass.radius = 0
	glass.roughness = 0.88
	glass.thickness = max(gui.style.rhythm * 0.42, f32(16))
	glass.bevel = max(gui.style.border_width * 3, f32(3))
	glass.border = 0.12
	glass.highlight = 0.18
	uifw.gui_refractive_glass_rect(gui, overlay, glass)
	scale := app_ui_simulation_bar_scale(gui)
	spinner_size := max(gui.style.rhythm, f32(40) * scale)
	center_x := width * 0.5
	center_y := height * 0.5 - gui.style.rhythm
	spinner := uifw.Rect{center_x - spinner_size * 0.5, center_y - spinner_size * 0.5, spinner_size, spinner_size}
	uifw.gui_ellipse_stroke(gui, spinner, {1, 1, 1, 0.30}, max(gui.style.border_width * 2, 4 * scale))
	angle := f32(gui.frame_index % 60) / 60.0 * uifw.GUI_TAU
	dot_r := spinner_size * 0.12
	orbit_r := spinner_size * 0.5
	dot := uifw.Rect{
		center_x + math.cos(angle) * orbit_r - dot_r,
		center_y + math.sin(angle) * orbit_r - dot_r,
		dot_r * 2,
		dot_r * 2,
	}
	uifw.gui_ellipse(gui, dot, {1, 1, 1, 1})
	title_w := min(width - gui.style.margin * 2, max(gui.style.body_char_width * 26, 1))
	title := uifw.Rect{center_x - title_w * 0.5, center_y + spinner_size * 0.5 + gui.style.spacing_2, title_w, gui.style.body_line_height}
	uifw.gui_text_centered(gui, title, "Starting Simulation...", gui.style.text)
	subtitle := uifw.Rect{title.x, title.y + title.h, title.w, gui.style.small_line_height}
	uifw.gui_text_centered(gui, subtitle, "Initializing GPU resources", gui.style.text_muted)
}

app_ui_simulation_bar_scale :: proc(gui: ^uifw.Gui_Context) -> f32 {
	return max(gui.style.row_height / SIMULATION_BAR_BASE_ROW_HEIGHT, 1)
}

app_ui_simulation_bar_height :: proc(gui: ^uifw.Gui_Context) -> f32 {
	content_h := gui.style.spacing_1 * 2 + gui.style.row_height
	return max(SIMULATION_BAR_HEIGHT, content_h)
}

// Simulation controls deliberately remain a single, temporary playground
// surface. On large displays, cap its line length instead of turning the UI
// into a dense expert workspace; the recovered space belongs to the artwork.
app_ui_simulation_control_panel_width :: proc(gui: ^uifw.Gui_Context, width, minimum: f32) -> f32 {
	margin := max(gui.style.spacing_3, f32(18))
	available := max(width - margin * 2, 1)
	target := max(width * 0.52, minimum)
	readable_cap := max(gui.style.body_char_width * 48, minimum)
	return min(target, min(readable_cap, available))
}

app_ui_simulation_control_panel_height_fraction :: proc(width: f32, compact, wide: f32) -> f32 {
	return uifw.gui_breakpoint(width) == .Wide ? wide : compact
}

app_ui_simulation_menu_panel :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, width, height: f32) -> uifw.Rect {
	top := f32(0)
	bottom_margin := f32(0)
	if ui.simulation_shell.controls_visible && !slime_controller_ui_enabled(ui) && !simulation_controller_ui_enabled(ui) {
		bottom_margin = app_ui_simulation_bar_height(gui) + max(gui.style.spacing_3, f32(18)) * 2
	}
	breakpoint := uifw.gui_breakpoint(width)
	min_w := breakpoint == .Compact ? max(gui.style.body_char_width * 18, f32(320)) : max(gui.style.body_char_width * 24, f32(440))
	max_w := breakpoint == .Wide ? max(gui.style.body_char_width * 34, f32(760)) : max(gui.style.body_char_width * 30, f32(680))
	if ui.mode == .Particle_Life {
		force_cell := max(gui.style.row_height * 1.35, gui.style.rhythm * 1.45)
		force_grid_w := force_cell * f32(PARTICLE_LIFE_MAX_SPECIES + 1)
		min_w = max(min_w, force_grid_w + gui.style.panel_padding * 2 + gui.style.spacing_3)
		max_w = max(max_w, min_w)
	} else if ui.mode == .Gradient_Editor {
		min_w = breakpoint == .Compact ? max(gui.style.body_char_width * 19, f32(340)) : max(gui.style.body_char_width * 28, f32(520))
		max_w = breakpoint == .Wide ? max(gui.style.body_char_width * 34, f32(720)) : max(gui.style.body_char_width * 31, f32(660))
	}
	available_w := max(width - gui.style.margin * 2, 1)
	panel_w := min(max(width * 0.36, min_w), min(max_w, available_w))
	panel_h := max(height - top - bottom_margin, 120)
	x := max((width - panel_w) * 0.5, gui.style.margin)

	position := MENU_POSITION_OPTIONS[ui.menu_position_index]
	if position == "left" {
		x = gui.style.margin
	} else if position == "right" {
		x = max(width - panel_w - gui.style.margin, gui.style.margin)
	}
	return {x, top, panel_w, panel_h}
}

app_ui_navigate_immediate :: proc(ui: ^App_Ui_State, mode: App_Mode) {
	if ui.video_recording_state == .Recording && app_ui_mode_is_simulation(ui.mode) && !app_ui_mode_is_simulation(mode) {
		ui.video_recording_state = .Idle
		write_fixed_string(ui.video_recording_status[:], "")
	}
	ui.previous_mode = ui.mode
	ui.mode = mode
	if mode == .Options {
		ui.options_scroll = 0
	}
	if mode == .How_To_Play {
		ui.how_to_play_scroll = 0
	}
	if app_ui_mode_is_simulation(mode) {
		// A simulation starts with no controller surface claiming focus. Mouse
		// motion may reveal the transient bar; Tab/deck actions explicitly enter
		// and focus the controller UI.
		app_ui_hide_unfocused_simulation_ui(ui)
		ui.simulation_shell.idle_seconds = 0
	}
}

app_ui_navigate :: proc(ui: ^App_Ui_State, mode: App_Mode) {
	if ui == nil {
		return
	}
	if app_ui_mode_transition_active(ui) {
		return
	}
	transition_between_menu_and_scene :=
		(ui.mode == .Main_Menu && app_ui_mode_is_simulation(mode)) ||
		(app_ui_mode_is_simulation(ui.mode) && mode == .Main_Menu)
	if transition_between_menu_and_scene {
		app_ui_mode_transition_request(ui, mode)
		return
	}
	app_ui_mode_transition_cancel(ui)
	app_ui_navigate_immediate(ui, mode)
}

app_ui_save_settings :: proc(ui: ^App_Ui_State, worker: ^Product_Context) {
	if settings_save_app(settings_app_config_path(), ui.settings) {
		worker.settings = ui.settings
		ui.settings_dirty = false
		app_ui_publish_settings_changed(ui, worker)
		msg: Render_To_Ui_Message
		msg.kind = .Preset_Result
		msg.preset_ok = true
		write_fixed_string(msg.text[:], "Saved app settings")
		_ = engine.queue_try_push(worker.render_to_ui, msg)
	}
}

app_ui_mark_settings_changed :: proc(ui: ^App_Ui_State, worker: ^Product_Context) {
	ui.settings_dirty = true
	app_ui_publish_settings_changed(ui, worker)
}

app_ui_reset_settings_to_defaults :: proc(ui: ^App_Ui_State, worker: ^Product_Context) {
	ui.settings = settings_default()
	ui.menu_position_index = option_index(ui.settings.menu_position, MENU_POSITION_OPTIONS[:], 1)
	ui.texture_filtering_index = option_index(ui.settings.texture_filtering, TEXTURE_FILTERING_OPTIONS[:], 0)
	ui.controller_face_layout_index = option_index(ui.settings.controller_face_layout, CONTROLLER_FACE_LAYOUT_OPTIONS[:], 0)
	ui.controller_menu_layout_index = option_index(ui.settings.controller_menu_layout, CONTROLLER_MENU_LAYOUT_OPTIONS[:], 0)
	ui.controller_shoulder_layout_index = option_index(ui.settings.controller_shoulder_layout, CONTROLLER_SHOULDER_LAYOUT_OPTIONS[:], 0)
	ui.keyboard_shortcut_profile_index = option_index(ui.settings.keyboard_shortcut_profile, KEYBOARD_SHORTCUT_PROFILE_OPTIONS[:], 0)
	app_ui_mark_settings_changed(ui, worker)
}

app_ui_publish_settings_changed :: proc(ui: ^App_Ui_State, worker: ^Product_Context) {
	msg: Render_To_Ui_Message
	msg.kind = .App_Settings_Changed
	msg.app_settings = ui.settings
	_ = engine.queue_try_push(worker.render_to_ui, msg)
}
