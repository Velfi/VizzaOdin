package game

import uifw "zelda_engine:ui"
import engine "zelda_engine:engine"

import "core:fmt"

app_ui_handle_controller_disconnect :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	if !gui.input.controller_disconnected || gui.input.active_device != .Controller || !app_ui_mode_is_simulation(ui.mode) {
		return
	}
	ui.simulation_shell.show_ui = true
	app_ui_set_simulation_chrome_visible(ui, true)
	ui.simulation_shell.idle_seconds = 0
	_ = feature_instance_set_set_paused(&ui.feature_instances, ui.mode, true)
}

APP_UI_DEVICE_NOTICE_SECONDS :: f32(2.75)
APP_UI_DEVICE_NOTICE_FADE_SECONDS :: f32(0.35)

app_ui_update_device_notice :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	if gui.input.controller_connected {
		write_fixed_string(ui.device_notice[:], "Controller connected")
		ui.device_notice_seconds = APP_UI_DEVICE_NOTICE_SECONDS
		ui.device_notice_disconnected = false
	}
	if gui.input.controller_disconnected {
		paused_for_disconnect := gui.input.active_device == .Controller && app_ui_mode_is_simulation(ui.mode)
		message := paused_for_disconnect ? "Controller disconnected - simulation paused" : "Controller disconnected"
		write_fixed_string(ui.device_notice[:], message)
		ui.device_notice_seconds = APP_UI_DEVICE_NOTICE_SECONDS
		ui.device_notice_disconnected = true
	}
	if gui.input.controller_connected || gui.input.controller_disconnected {
		return
	}
	ui.device_notice_seconds = max(ui.device_notice_seconds - max(gui.input.delta_time, 0), 0)
	if ui.device_notice_seconds <= 0 {
		write_fixed_string(ui.device_notice[:], "")
		ui.device_notice_disconnected = false
	}
}

app_ui_draw_device_notice :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	message := fixed_string(ui.device_notice[:])
	if len(message) == 0 || ui.device_notice_seconds <= 0 || gui.input.window_width <= 0 || gui.input.window_height <= 0 {
		return
	}
	alpha := f32(1)
	if ui.device_notice_seconds < APP_UI_DEVICE_NOTICE_FADE_SECONDS {
		alpha = max(ui.device_notice_seconds / APP_UI_DEVICE_NOTICE_FADE_SECONDS, 0)
	}
	width := f32(gui.input.window_width)
	margin := max(gui.style.spacing_3, f32(18))
	padding := max(gui.style.spacing_2, f32(10))
	notice_w := min(max(uifw.gui_text_width(gui, message) + padding * 2.5, f32(220)), max(width - margin * 2, 1))
	notice_h := max(gui.style.row_height, gui.style.body_line_height + padding)
	notice_y := margin
	rect := uifw.Rect{max((width - notice_w) * 0.5, margin), notice_y, notice_w, notice_h}
	accent := gui.style.accent
	if ui.device_notice_disconnected {
		accent = {0.96, 0.56, 0.24, 1}
	}
	fill := uifw.Color{0.055, 0.065, 0.085, 0.94 * alpha}
	border := uifw.Color{accent.r, accent.g, accent.b, 0.82 * alpha}
	text_color := uifw.Color{gui.style.text.r, gui.style.text.g, gui.style.text.b, alpha}
	uifw.gui_shadow(gui, rect, gui.style.radius_control, {0, 5}, 16, {0, 0, 0, 0.42 * alpha})
	uifw.gui_round_rect(gui, rect, gui.style.radius_control, fill)
	uifw.gui_round_stroke(gui, rect, gui.style.radius_control, border, max(gui.style.border_width * 1.5, 1.5))
	text_rect := uifw.gui_inset(rect, padding)
	text_width := uifw.gui_text_width(gui, message)
	text_scale := f32(1)
	if text_width > 0 {
		text_scale = min(text_rect.w / text_width, 1)
	}
	uifw.gui_text_aligned_scaled(gui, text_rect, message, text_color, .Center, text_scale)
}

app_ui_draw_virtual_cursor :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	if app_ui_system_cursor_hidden(ui) {
		return
	}
	controller_gesture := ui != nil &&
		((ui.frame_actions.primary.owner == .Controller && ui.frame_actions.primary.down) ||
		 (ui.frame_actions.secondary.owner == .Controller && ui.frame_actions.secondary.down))
	if gui.input.active_device != .Controller && !controller_gesture {
		return
	}
	p := gui.input.mouse_pos
	size := max(gui.style.row_height * 0.26, 10)
	shadow := uifw.Color{0, 0, 0, 0.60}
	fill := gui.style.text
	accent := gui.style.accent
	uifw.gui_line(gui, {p.x - size + 2, p.y + 2}, {p.x + size + 2, p.y + 2}, shadow, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, {p.x + 2, p.y - size + 2}, {p.x + 2, p.y + size + 2}, shadow, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, {p.x - size, p.y}, {p.x + size, p.y}, fill, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, {p.x, p.y - size}, {p.x, p.y + size}, fill, max(gui.style.border_width * 2, 2))
	uifw.gui_ellipse(gui, {p.x - size * 0.26, p.y - size * 0.26, size * 0.52, size * 0.52}, accent)
}

app_ui_draw_gradient_editor :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2) {
	width := viewport.x
	height := viewport.y
	color_scheme_editor_draw_full_preview(gui, &ui.color_scheme_editor, {0, 0, width, height})

	if ui.simulation_shell.controls_visible {
		app_ui_draw_simulation_bar(ui, gui, .Gradient_Editor, nil, nil, nil, true, false, "Gradient Editor", viewport, width, nil)
	}
	if ui.simulation_shell.show_ui {
		panel := app_ui_simulation_menu_panel(ui, gui, width, height)
		color_scheme_editor_draw_standalone(gui, &ui.color_scheme_editor, panel, &ui.gradient_editor_scroll)
	}
}

app_ui_draw_remaining_sim :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind, sim: ^Remaining_Sim_State, viewport: uifw.Vec2, worker: ^Product_Context) {
	width := viewport.x
	height := viewport.y
	controller_ui_active := kind == .Slime_Mold || simulation_controller_ui_enabled(ui)
	pause_consumed := false
	controller_pause_pressed := app_ui_take_controller_action(&ui.frame_actions.pause)
	if controller_ui_active && controller_pause_pressed {
		app_ui_release_controller_focus(ui)
		app_ui_focus_simulation_bar_pause(gui)
		app_ui_set_simulation_chrome_visible(ui, true)
		pause_consumed = true
	}
	if kind == .Slime_Mold {
		pause_consumed = slime_controller_ui_update_input(ui, gui, sim, width, height) || pause_consumed
	} else {
		pause_consumed = simulation_controller_ui_update_input(ui, gui) || pause_consumed
	}
	if gui.input.pause && !pause_consumed {
		sim.paused = !sim.paused
	}
	if sim.canvas_tool.changed {
		set := canvas_tool_set_for_kind(kind)
		tool := canvas_tool_selected(&set, &sim.canvas_tool)
		if tool.valid {uifw.gui_notice(gui, fmt.tprintf("%s selected — Primary: %s · Secondary: %s", tool.name, tool.primary_label, tool.secondary_label), 1.6)}
	}
	if kind != .Vectors && kind != .Moire && kind != .Primordial && kind != .Pellets && kind != .Flow_Field && kind != .Slime_Mold && kind != .Voronoi_CA {
		remaining_sim_draw(sim, gui, kind, width, height)
	}
	if ui.simulation_shell.controls_visible {
		tool_set := canvas_tool_set_for_kind(kind)
		tool := canvas_tool_selected(&tool_set, &sim.canvas_tool)
		display_name := remaining_sim_name(kind)
		if tool.valid {
			display_name = fmt.tprintf("%s · %s — Primary: %s · Secondary: %s", display_name, tool.name, tool.primary_label, tool.secondary_label)
		}
		app_ui_draw_simulation_bar(ui, gui, app_mode_from_remaining_sim_kind(kind), nil, nil, sim, sim.paused, false, display_name, viewport, width, worker)
	}
	if kind == .Slime_Mold {
		slime_controller_ui_draw(ui, gui, sim, width, height, worker)
	} else {
		simulation_controller_ui_draw(ui, gui, remaining = sim, width = width, height = height, worker = worker)
	}
	if kind == .Vectors && sim.vectors_image_dialog_requested {
		sim.vectors_image_dialog_requested = false
		app_ui_request_image_dialog(ui, worker, .Vectors)
	}
	if kind == .Moire && sim.moire_image_dialog_requested {
		sim.moire_image_dialog_requested = false
		app_ui_request_image_dialog(ui, worker, .Moire)
	}
	if kind == .Flow_Field && sim.flow_image_dialog_requested {
		sim.flow_image_dialog_requested = false
		app_ui_request_image_dialog(ui, worker, .Flow)
	}
	if kind == .Slime_Mold && sim.slime_mask_image_dialog_requested {
		sim.slime_mask_image_dialog_requested = false
		app_ui_request_image_dialog(ui, worker, .Slime_Mask)
	}
	if kind == .Slime_Mold && sim.slime_position_image_dialog_requested {
		sim.slime_position_image_dialog_requested = false
		app_ui_request_image_dialog(ui, worker, .Slime_Position)
	}
}

app_ui_draw_options :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2, worker: ^Product_Context) {
	window_w := viewport.x
	window_h := viewport.y
	panel_w := min(max(window_w * 0.72, gui.style.body_char_width * 54), max(window_w - gui.style.margin * 2, 1))
	panel_h := min(max(window_h * 0.86, gui.style.row_height * 12), max(window_h - gui.style.margin * 2, 1))
	panel := centered_panel_styled(panel_w, panel_h, i32(viewport.x), i32(viewport.y), &gui.style)
	uifw.gui_panel_begin(gui, panel)
	inner_h := max(panel.h - gui.style.panel_padding * 2, 0)
	content_w := max(panel.w - gui.style.panel_padding * 2, 1)
	footer_h := app_ui_options_footer_height(gui, content_w)
	section_rail_h := app_ui_options_section_rail_height(gui, content_w)
	viewport_h := max(inner_h - gui.style.heading_line_height - section_rail_h - footer_h - gui.style.spacing * 3, gui.style.row_height)
	ui.options_section_index = max(min(ui.options_section_index, len(OPTIONS_SECTION_LABELS) - 1), 0)
	uifw.gui_heading(gui, "Options")
	if app_ui_draw_options_section_rail(gui, content_w, &ui.options_section_index) {
		ui.options_scroll = 0
	}
	viewport := uifw.gui_next_rect(gui, height = viewport_h)
	content_height := app_ui_options_content_height(gui, ui.options_section_index)
	uifw.gui_push_id(gui, "settings")
	uifw.gui_scroll_begin(gui, viewport, content_height, &ui.options_scroll)
	app_ui_draw_options_active_section(ui, gui, worker)
	uifw.gui_scroll_end(gui)
	footer := uifw.gui_next_rect(gui, height = footer_h)
	app_ui_draw_options_footer(ui, gui, footer, worker)
	uifw.gui_pop_id(gui)
	uifw.gui_panel_end(gui)
}

App_Ui_Options_Document_Context :: struct {
	ui: ^App_Ui_State,
	worker: ^Product_Context,
}

app_ui_draw_options_document_slot :: proc(data: rawptr, gui: ^uifw.Gui_Context, bounds: uifw.Rect) {
	document_context := cast(^App_Ui_Options_Document_Context)data
	if document_context == nil || document_context.ui == nil || gui == nil do return
	ui := document_context.ui
	content_w := max(bounds.w, 1)
	footer_h := app_ui_options_footer_height(gui, content_w)
	section_rail_h := app_ui_options_section_rail_height(gui, content_w)
	viewport_h := max(bounds.h - section_rail_h - footer_h - gui.style.spacing * 2, gui.style.row_height)
	ui.options_section_index = max(min(ui.options_section_index, len(OPTIONS_SECTION_LABELS) - 1), 0)
	if app_ui_draw_options_section_rail(gui, content_w, &ui.options_section_index) {
		ui.options_scroll = 0
	}
	viewport := uifw.gui_next_rect(gui, height = viewport_h)
	content_height := app_ui_options_content_height(gui, ui.options_section_index)
	uifw.gui_push_id(gui, "settings")
	uifw.gui_scroll_begin(gui, viewport, content_height, &ui.options_scroll)
	app_ui_draw_options_active_section(ui, gui, document_context.worker)
	uifw.gui_scroll_end(gui)
	footer := uifw.gui_next_rect(gui, height = footer_h)
	app_ui_draw_options_footer(ui, gui, footer, document_context.worker)
	uifw.gui_pop_id(gui)
}

app_ui_draw_options_document :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, documents: ^uifw.Ui_Document_Assets, viewport: uifw.Vec2, worker: ^Product_Context) {
	if ui == nil || gui == nil || documents == nil {
		app_ui_draw_options(ui, gui, viewport, worker)
		return
	}
	document, found := uifw.ui_document_assets_find(documents, "options")
	if !found {
		app_ui_draw_options(ui, gui, viewport, worker)
		return
	}
	root_height := max(viewport.y - 48, gui.style.row_height * 4)
	slot_height := max(root_height - gui.style.panel_padding * 2 - gui.style.heading_line_height - gui.style.spacing, gui.style.row_height)
	document_context := App_Ui_Options_Document_Context {ui, worker}
	bindings := [?]uifw.Ui_Document_Runtime_Binding {
		{id = "options_slot", kind = .Slot, userdata = &document_context, draw_slot = app_ui_draw_options_document_slot, slot_content_height = slot_height},
	}
	actions: uifw.Ui_Document_Action_State
	result := uifw.ui_document_draw(document, gui, {0, 0, viewport.x, viewport.y}, bindings[:], &actions)
	if result.error != .None {
		app_ui_draw_options(ui, gui, viewport, worker)
	}
}

app_ui_how_to_play_content_height :: proc(gui: ^uifw.Gui_Context, width: f32) -> f32 {
	wrap_width := max(width - gui.style.spacing_1, gui.style.body_char_width)
	height := f32(uifw.gui_wrap_line_count(gui, HOW_TO_PLAY_INTRO, wrap_width)) * gui.style.body_line_height
	height += gui.style.heading_line_height
	height += f32(uifw.gui_wrap_line_count(gui, HOW_TO_PLAY_DEMO_INTRO, wrap_width)) * gui.style.body_line_height
	demo_numeric_id := uifw.gui_make_id(gui, "how_to_play_demo_number")
	height += gui.style.row_height * 3 + uifw.gui_slider_height(gui) + uifw.gui_numeric_height(gui, demo_numeric_id)
	for section in HOW_TO_PLAY_SECTIONS {
		height += gui.style.heading_line_height
		height += f32(uifw.gui_wrap_line_count(gui, section.body, wrap_width)) * gui.style.body_line_height
		height += gui.style.spacing_2
	}
	// Each layout item also advances by the scroll column's normal gap.
	height += gui.style.spacing * f32(8 + len(HOW_TO_PLAY_SECTIONS) * 3)
	return height
}

app_ui_draw_how_to_play_demo :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, width: f32) {
	uifw.gui_heading(gui, "Try the controls")
	uifw.gui_text_block(gui, HOW_TO_PLAY_DEMO_INTRO, width, gui.style.text_muted)
	if uifw.gui_button(gui, fmt.tprintf("Button — pressed %d times", ui.how_to_play_demo_button_count), "how_to_play_demo_button") {
		ui.how_to_play_demo_button_count += 1
	}
	_ = uifw.gui_toggle(gui, fmt.tprintf("Toggle — %s", ui.how_to_play_demo_toggle ? "on" : "off"), "how_to_play_demo_toggle", &ui.how_to_play_demo_toggle)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Universal Number — %.3f", ui.how_to_play_demo_number), "how_to_play_demo_number", &ui.how_to_play_demo_number, 0.01, 0.001, 1000, mapping = .Logarithmic)
	_ = uifw.gui_slider_f32(gui, fmt.tprintf("Slider — %.0f%%", ui.how_to_play_demo_slider * 100), "how_to_play_demo_slider", &ui.how_to_play_demo_slider, 0, 1)
	_ = uifw.gui_selector(gui, fmt.tprintf("Selector — %s", HOW_TO_PLAY_DEMO_SELECTOR_OPTIONS[ui.how_to_play_demo_selector]), "how_to_play_demo_selector", &ui.how_to_play_demo_selector, HOW_TO_PLAY_DEMO_SELECTOR_OPTIONS[:])
	uifw.gui_spacer(gui, gui.style.spacing_2)
}

app_ui_controls_help_modal_content_height :: proc(gui: ^uifw.Gui_Context, width: f32, settings: App_Settings, mode := App_Mode.Main_Menu) -> f32 {
	quick_reference := app_ui_controls_help_quick_reference_for_settings(gui.input.active_device, settings)
	wrap_width := max(width - gui.style.spacing_1, gui.style.body_char_width)
	height := app_ui_how_to_play_content_height(gui, width) +
		gui.style.heading_line_height +
		f32(uifw.gui_wrap_line_count(gui, quick_reference, wrap_width)) * gui.style.body_line_height +
		gui.style.spacing * 3 + gui.style.spacing_2
	return height
}

app_ui_draw_how_to_play :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	window_w := f32(max(gui.input.window_width, 1))
	window_h := f32(max(gui.input.window_height, 1))
	margin := max(gui.style.margin, f32(18))
	panel_w := min(max(window_w * 0.74, gui.style.body_char_width * 44), max(window_w - margin * 2, 1))
	panel_h := min(max(window_h * 0.86, gui.style.row_height * 9), max(window_h - margin * 2, 1))
	panel := uifw.Rect{max((window_w - panel_w) * 0.5, margin), max((window_h - panel_h) * 0.5, margin), panel_w, panel_h}
	back_id := uifw.gui_make_id(gui, "back")
	if gui.input.active_device == .Controller {
		gui.focused = back_id
	}

	if gui.input.back {
		app_ui_navigate(ui, .Main_Menu)
	}

	uifw.gui_panel_begin(gui, panel)
	inner_h := max(panel.h - gui.style.panel_padding * 2, 1)
	footer_h := gui.style.row_height
	viewport_h := max(inner_h - gui.style.heading_line_height - footer_h - gui.style.spacing * 2, gui.style.row_height)
	uifw.gui_heading(gui, "Controls")
	viewport := uifw.gui_next_rect(gui, height = viewport_h)
	content_width := max(viewport.w - gui.style.spacing_2, 1)
	content_height := app_ui_how_to_play_content_height(gui, content_width)
	uifw.gui_scroll_begin_native(gui, viewport, content_height, &ui.how_to_play_scroll)
	uifw.gui_text_block(gui, HOW_TO_PLAY_INTRO, content_width, gui.style.text)
	uifw.gui_spacer(gui, gui.style.spacing_1)
	app_ui_draw_how_to_play_demo(ui, gui, content_width)
	for section in HOW_TO_PLAY_SECTIONS {
		uifw.gui_heading(gui, section.title)
		uifw.gui_text_block(gui, section.body, content_width, gui.style.text_muted)
		uifw.gui_spacer(gui, gui.style.spacing_2)
	}
	uifw.gui_scroll_end(gui)
	footer := uifw.gui_next_rect(gui, height = footer_h)
	back_w := uifw.gui_button_content_width(gui, "Back to Menu")
	if uifw.gui_button_at(gui, back_id, {footer.x, footer.y, back_w, footer.h}, "Back to Menu", true) {
		app_ui_navigate(ui, .Main_Menu)
	}
	uifw.gui_panel_end(gui)
}

app_ui_draw_how_to_play_document_slot :: proc(data: rawptr, gui: ^uifw.Gui_Context, bounds: uifw.Rect) {
	ui := cast(^App_Ui_State)data
	if ui == nil || gui == nil do return
	content_width := max(bounds.w - gui.style.spacing_2, 1)
	uifw.gui_text_block(gui, HOW_TO_PLAY_INTRO, content_width, gui.style.text)
	uifw.gui_spacer(gui, gui.style.spacing_1)
	app_ui_draw_how_to_play_demo(ui, gui, content_width)
	for section in HOW_TO_PLAY_SECTIONS {
		uifw.gui_heading(gui, section.title)
		uifw.gui_text_block(gui, section.body, content_width, gui.style.text_muted)
		uifw.gui_spacer(gui, gui.style.spacing_2)
	}
}

app_ui_draw_how_to_play_document :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, documents: ^uifw.Ui_Document_Assets, viewport: uifw.Vec2) {
	if ui == nil || gui == nil || documents == nil {
		app_ui_draw_how_to_play(ui, gui)
		return
	}
	document, found := uifw.ui_document_assets_find(documents, "controls_help")
	if !found {
		app_ui_draw_how_to_play(ui, gui)
		return
	}
	content_width := max(viewport.x - gui.style.panel_padding * 2 - gui.style.spacing_2 - 48, 1)
	content_height := app_ui_how_to_play_content_height(gui, content_width)
	bindings := [?]uifw.Ui_Document_Runtime_Binding {
		{id = "content_slot", kind = .Slot, userdata = ui, draw_slot = app_ui_draw_how_to_play_document_slot, slot_content_height = content_height},
		{id = "close", kind = .Action},
	}
	actions: uifw.Ui_Document_Action_State
	result := uifw.ui_document_draw(document, gui, {0, 0, viewport.x, viewport.y}, bindings[:], &actions)
	if result.error != .None {
		app_ui_draw_how_to_play(ui, gui)
		return
	}
	if gui.input.back {
		app_ui_navigate(ui, .Main_Menu)
		return
	}
	for action in actions.ids[:actions.count] {
		if action == "close" {
			app_ui_navigate(ui, .Main_Menu)
			return
		}
	}
}

app_ui_open_controls_help :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	if ui == nil || gui == nil || ui.controls_help_open {
		return
	}
	ui.controls_help_open = true
	ui.controls_help_open_frame = gui.frame_index
	ui.controls_help_invoker_focus = gui.focused
	ui.controls_help_modal_scroll = 0
}

app_ui_close_controls_help :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	if ui == nil {
		return
	}
	ui.controls_help_open = false
	ui.controls_help_modal_scroll = 0
	if gui != nil {
		gui.focused = ui.controls_help_invoker_focus
		uifw.gui_focus_scope_release(gui)
	}
	ui.controls_help_invoker_focus = uifw.GUI_ID_NONE
}

app_ui_draw_controls_help_modal :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	if ui == nil || gui == nil || !ui.controls_help_open {
		return
	}
	window_w := f32(max(gui.input.window_width, 1))
	window_h := f32(max(gui.input.window_height, 1))
	margin := max(gui.style.spacing_2, f32(12))
	panel_w := min(max(window_w * 0.76, gui.style.body_char_width * 40), max(window_w - margin * 2, 1))
	panel_h := min(max(window_h * 0.86, gui.style.row_height * 8), max(window_h - margin * 2, 1))
	panel := uifw.Rect{max((window_w - panel_w) * 0.5, margin), max((window_h - panel_h) * 0.5, margin), panel_w, panel_h}

	uifw.gui_push_id(gui, "controls_help_modal")
	uifw.gui_rect(gui, {0, 0, window_w, window_h}, {0, 0, 0, 0.72})
	uifw.gui_overlay_input_begin(gui, {0, 0, window_w, window_h})
	if gui.frame_index > ui.controls_help_open_frame && (gui.input.back || ui.frame_actions.help.pressed) {
		app_ui_close_controls_help(ui, gui)
		uifw.gui_overlay_input_cancel(gui)
		uifw.gui_pop_id(gui)
		return
	}
	uifw.gui_spatial_group_begin(gui, "controls_help_focus_scope")
	defer uifw.gui_spatial_group_end(gui)
	uifw.gui_focus_scope_trap_current(gui)
	previous_explicit_activation := gui.controller_explicit_activation
	gui.controller_explicit_activation = previous_explicit_activation || gui.input.active_device == .Controller
	defer gui.controller_explicit_activation = previous_explicit_activation

	uifw.gui_panel_begin(gui, panel)
	header := uifw.gui_next_rect(gui, height = gui.style.row_height)
	close_w := min(uifw.gui_button_content_width(gui, "Close"), header.w * 0.30)
	title_rect := uifw.Rect{header.x, header.y, max(header.w - close_w - gui.style.spacing, 0), header.h}
	close_rect := uifw.Rect{header.x + header.w - close_w, header.y, close_w, header.h}
	uifw.gui_text_clipped(gui, title_rect, {title_rect.x, title_rect.y + max((title_rect.h - gui.style.heading_text_height) * 0.5, 0)}, "Controls", gui.style.text)
	if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "close"), close_rect, "Close", true) {
		app_ui_close_controls_help(ui, gui)
		uifw.gui_panel_end(gui)
		uifw.gui_overlay_input_cancel(gui)
		uifw.gui_pop_id(gui)
		return
	}
	viewport := uifw.gui_next_rect(gui, height = max(panel.h - gui.style.panel_padding * 2 - gui.style.row_height - gui.style.spacing, gui.style.row_height))
	content_width := max(viewport.w - gui.style.spacing_2, 1)
	content_height := app_ui_controls_help_modal_content_height(gui, content_width, ui.settings, ui.mode)
	uifw.gui_scroll_begin_native(gui, viewport, content_height, &ui.controls_help_modal_scroll)
	quick_reference := app_ui_controls_help_quick_reference_for_settings(gui.input.active_device, ui.settings)
	uifw.gui_heading(gui, "Quick reference")
	uifw.gui_text_block(gui, quick_reference, content_width, gui.style.accent)
	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_text_block(gui, HOW_TO_PLAY_INTRO, content_width, gui.style.text)
	uifw.gui_spacer(gui, gui.style.spacing_1)
	app_ui_draw_how_to_play_demo(ui, gui, content_width)
	for section in HOW_TO_PLAY_SECTIONS {
		uifw.gui_heading(gui, section.title)
		uifw.gui_text_block(gui, section.body, content_width, gui.style.text_muted)
		uifw.gui_spacer(gui, gui.style.spacing_2)
	}
	uifw.gui_scroll_end(gui)
	uifw.gui_panel_end(gui)
	uifw.gui_overlay_input_end(gui)
	uifw.gui_pop_id(gui)
}
