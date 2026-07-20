package game

import uifw "zelda_engine:ui"
import engine "zelda_engine:engine"

import "core:fmt"
import "core:math"

app_ui_draw_main_menu :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2, worker: ^Product_Context) {
	width := viewport.x
	height := viewport.y
	theme := app_ui_menu_theme(gui, width, height)
	ui.main_menu_live_preview_visible = false
	ui.main_menu_preview_slot_count = 0
	if app_ui_main_menu_pointer_interaction(gui) {
		ui.main_menu_focus_navigation_active = false
	}
	app_ui_main_menu_apply_navigation(ui, gui)

	app_ui_draw_main_menu_backdrop(gui, {0, 0, width, height}, theme)

	app_ui_main_menu_sync_slot_to_selection(ui, gui)
	if gui.input.accept && gui.focused == uifw.GUI_ID_NONE {
		app_ui_main_menu_activate_slot(ui, ui.main_menu_focus_slot, worker)
	}

	margin_x := max(width * 0.055, gui.style.spacing_4)
	title_y := max(height * 0.070, gui.style.spacing_4)
	title_w := max(width - margin_x * 2, 1)
	title_scale := max((height * 0.31) / f32(16), gui.style.display_text_scale * 1.2)
	title_text_h := uifw.GUI_FONT_LOGICAL_HEIGHT * title_scale
	title_h := min(max(max(height * 0.20, gui.style.display_line_height), title_text_h), height - title_y)
	title := uifw.Rect{margin_x, title_y, title_w, title_h}
	title_label := "VIZZA"
	title_bytes := transmute([]u8)title_label
	title_fallback_advance := gui.style.char_width * title_scale / max(gui.style.text_scale, 0.001)
	title_text_w := uifw.gui_font_text_width(.Display, title_bytes, title_scale, title_fallback_advance)
	title_click := uifw.Rect{title.x, title.y, min(title_text_w, title.w), title.h}
	title_id := uifw.gui_make_id(gui, "main_menu_logo")
	if ui.main_menu_focus_navigation_active {
		if ui.main_menu_focus_slot == MAIN_MENU_TITLE_SLOT {
			gui.focused = title_id
		} else if gui.focused == title_id {
			gui.focused = uifw.GUI_ID_NONE
		}
	}
	title_control := uifw.gui_control(gui, title_id, title_click, true)
	if title_control.activated || (title_control.hovered && gui.active == title_id && gui.input.mouse_released) {
		ui.main_menu_focus_slot = MAIN_MENU_TITLE_SLOT
		ui.main_menu_palette_randomize_requested = true
	}
	uifw.gui_text_aligned_font(gui, title, title_label, theme.text, .Left, .Display, title_scale)
	if title_control.focused {
		ui.main_menu_focus_slot = MAIN_MENU_TITLE_SLOT
		uifw.gui_round_stroke(gui, uifw.gui_inset(title_click, -theme.border_width * 2), theme.card_radius, uifw.gui_apply_opacity(theme.text, 0.88), MAIN_MENU_TEXT_BUTTON_FOCUS_BORDER_WIDTH)
	}
	byline_scale := gui.style.heading_text_scale * 1.45
	byline_text_h := uifw.GUI_FONT_LOGICAL_HEIGHT * byline_scale
	title_baseline_y := title.y + title_text_h * MAIN_MENU_DISPLAY_FONT_BASELINE_RATIO
	byline_baseline_offset := byline_text_h * MAIN_MENU_DISPLAY_FONT_BASELINE_RATIO
	byline := uifw.Rect{margin_x + title_w * 0.68, title_baseline_y - byline_baseline_offset, title_w * 0.30, byline_text_h}
	uifw.gui_text_aligned_font(gui, byline, "By Zelda", theme.text, .Left, .Display, byline_scale)

	side_w := min(max(width * 0.23, f32(330)), f32(560))
	bottom_margin := max(height * 0.050, gui.style.spacing_4)
	right_margin := max(width * 0.050, gui.style.spacing_4)
	actions_x := f32(0)
	action_gap := f32(0)
	button_w := f32(0)
	button_h := f32(0)
	actions_h := f32(0)
	actions_y := f32(0)
	available_list_w := max(width - margin_x * 2, 1)
	if width >= 920 {
		action_gap = max(theme.item_gap * 0.12, theme.footer_height * 0.07)
		options_size := app_ui_main_menu_text_button_size(gui, "OPTIONS", theme)
		quit_size := app_ui_main_menu_text_button_size(gui, "QUIT", theme)
		button_w = max(side_w, max(options_size.x, quit_size.x))
		button_h = max(theme.footer_height, max(options_size.y, quit_size.y))
		actions_h = button_h * 2 + action_gap
		actions_x = max(width - right_margin - button_w, margin_x)
		actions_y = max(height - bottom_margin - actions_h, 0)
		available_list_w = max(actions_x - theme.detail_gap - margin_x, 1)
	}
	list_w := min(max(width * 0.60, f32(680)), available_list_w)
	if width < 920 {
		list_w = max(width - margin_x * 2, 1)
	}
	list_y := max(title.y + title.h + theme.inner_gap, height * 0.39)
	list_bottom := height - bottom_margin
	list_h := max(list_bottom - list_y, theme.row_height * 2.25)
	list := uifw.Rect{margin_x, list_y, list_w, list_h}
	app_ui_draw_main_menu_catalog_eyebrow(gui, list, theme)
	app_ui_draw_main_menu_list(ui, gui, app_ui_main_menu_catalog_list_bounds(gui, list), theme)

	if width >= 920 {
		actions := uifw.Rect{actions_x, actions_y, button_w, actions_h}
		options_id := uifw.gui_make_id(gui, "options")
		if ui.main_menu_focus_navigation_active {
			if ui.main_menu_focus_slot == app_ui_main_menu_options_slot() {
				gui.focused = options_id
			} else if gui.focused == options_id {
				gui.focused = uifw.GUI_ID_NONE
			}
		}
		if app_ui_draw_main_menu_text_button(gui, {actions.x, actions.y, button_w, button_h}, "options", "OPTIONS", theme) {
			ui.main_menu_focus_slot = app_ui_main_menu_options_slot()
			app_ui_main_menu_activate_slot(ui, ui.main_menu_focus_slot, worker)
		}
		if gui.focused == options_id {
			ui.main_menu_focus_slot = app_ui_main_menu_options_slot()
		}
		quit_id := uifw.gui_make_id(gui, "quit")
		if ui.main_menu_focus_navigation_active {
			if ui.main_menu_focus_slot == app_ui_main_menu_quit_slot() {
				gui.focused = quit_id
			} else if gui.focused == quit_id {
				gui.focused = uifw.GUI_ID_NONE
			}
		}
		if app_ui_draw_main_menu_text_button(gui, {actions.x, actions.y + button_h + action_gap, button_w, button_h}, "quit", "QUIT", theme, true, ui.main_menu_quit_hold_highlight) {
			ui.main_menu_focus_slot = app_ui_main_menu_quit_slot()
			app_ui_main_menu_activate_slot(ui, ui.main_menu_focus_slot, worker)
		}
		if gui.focused == quit_id {
			ui.main_menu_focus_slot = app_ui_main_menu_quit_slot()
		}
	} else {
		action_gap := max(theme.item_gap * 1.4, theme.footer_height * 0.35)
		actions := uifw.Rect{list.x, max(list.y + list.h - theme.footer_height * 2 - action_gap, list.y), list.w, theme.footer_height * 2 + action_gap}
		button_w := min(actions.w, max(gui.style.body_char_width * 16, 220))
		button_x := actions.x + max((actions.w - button_w) * 0.5, 0)
		options_id := uifw.gui_make_id(gui, "options")
		if ui.main_menu_focus_navigation_active {
			if ui.main_menu_focus_slot == app_ui_main_menu_options_slot() {
				gui.focused = options_id
			} else if gui.focused == options_id {
				gui.focused = uifw.GUI_ID_NONE
			}
		}
		if app_ui_draw_main_menu_text_button(gui, {button_x, actions.y, button_w, theme.footer_height}, "options", "OPTIONS", theme) {
			ui.main_menu_focus_slot = app_ui_main_menu_options_slot()
			app_ui_main_menu_activate_slot(ui, ui.main_menu_focus_slot, worker)
		}
		if gui.focused == options_id {
			ui.main_menu_focus_slot = app_ui_main_menu_options_slot()
		}
		quit_id := uifw.gui_make_id(gui, "quit")
		if ui.main_menu_focus_navigation_active {
			if ui.main_menu_focus_slot == app_ui_main_menu_quit_slot() {
				gui.focused = quit_id
			} else if gui.focused == quit_id {
				gui.focused = uifw.GUI_ID_NONE
			}
		}
		if app_ui_draw_main_menu_text_button(gui, {button_x, actions.y + theme.footer_height + action_gap, button_w, theme.footer_height}, "quit", "QUIT", theme, true, ui.main_menu_quit_hold_highlight) {
			ui.main_menu_focus_slot = app_ui_main_menu_quit_slot()
			app_ui_main_menu_activate_slot(ui, ui.main_menu_focus_slot, worker)
		}
		if gui.focused == quit_id {
			ui.main_menu_focus_slot = app_ui_main_menu_quit_slot()
		}
	}
}

App_Ui_Main_Menu_Document_Context :: struct {
	ui: ^App_Ui_State,
	worker: ^Product_Context,
	viewport: uifw.Vec2,
}

app_ui_draw_main_menu_document_slot :: proc(data: rawptr, gui: ^uifw.Gui_Context, bounds: uifw.Rect) {
	_ = bounds
	document_context := cast(^App_Ui_Main_Menu_Document_Context)data
	if document_context == nil || document_context.ui == nil || gui == nil do return
	app_ui_draw_main_menu(document_context.ui, gui, document_context.viewport, document_context.worker)
}

app_ui_draw_main_menu_document :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, documents: ^uifw.Ui_Document_Assets, viewport: uifw.Vec2, worker: ^Product_Context) {
	if ui == nil || gui == nil || documents == nil {
		app_ui_draw_main_menu(ui, gui, viewport, worker)
		return
	}
	document, found := uifw.ui_document_assets_find(documents, "main_menu")
	if !found {
		app_ui_draw_main_menu(ui, gui, viewport, worker)
		return
	}
	document_context := App_Ui_Main_Menu_Document_Context {ui, worker, viewport}
	bindings := [?]uifw.Ui_Document_Runtime_Binding {
		{id = "wide_shell", kind = .Slot, userdata = &document_context, draw_slot = app_ui_draw_main_menu_document_slot, slot_content_height = viewport.y},
		{id = "compact_shell", kind = .Slot, userdata = &document_context, draw_slot = app_ui_draw_main_menu_document_slot, slot_content_height = viewport.y},
	}
	result := uifw.ui_document_draw(document, gui, {0, 0, viewport.x, viewport.y}, bindings[:], nil)
	if result.error != .None {
		app_ui_draw_main_menu(ui, gui, viewport, worker)
	}
}

app_ui_main_menu_pointer_interaction :: proc(gui: ^uifw.Gui_Context) -> bool {
	return uifw.gui_pointer_enabled(gui) &&
	       (gui.input.mouse_pressed ||
	        gui.input.mouse_released ||
	        gui.input.mouse_down ||
	        gui.input.wheel_delta != 0)
}

app_ui_main_menu_options_slot :: proc() -> int {
	return MAIN_MENU_SIMULATION_SLOT_OFFSET + len(APP_SIMULATION_NAMES)
}

app_ui_main_menu_quit_slot :: proc() -> int {
	return app_ui_main_menu_options_slot() + 1
}

app_ui_main_menu_slot_count :: proc() -> int {
	return app_ui_main_menu_quit_slot() + 1
}

app_ui_main_menu_clamp_slot :: proc(slot: int) -> int {
	return max(min(slot, app_ui_main_menu_slot_count() - 1), MAIN_MENU_TITLE_SLOT)
}

app_ui_main_menu_slot_for_simulation_index :: proc(index: int) -> int {
	return MAIN_MENU_SIMULATION_SLOT_OFFSET + max(min(index, len(APP_SIMULATION_NAMES) - 1), 0)
}

app_ui_main_menu_simulation_index_for_slot :: proc(slot: int) -> (index: int, ok: bool) {
	index = slot - MAIN_MENU_SIMULATION_SLOT_OFFSET
	ok = index >= 0 && index < len(APP_SIMULATION_NAMES)
	if !ok {
		index = 0
	}
	return
}

app_ui_main_menu_sync_slot_to_selection :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	ui.main_menu_selected = max(min(ui.main_menu_selected, len(APP_SIMULATION_NAMES) - 1), 0)
	ui.main_menu_focus_slot = app_ui_main_menu_clamp_slot(ui.main_menu_focus_slot)
	if gui.focused == uifw.GUI_ID_NONE && !ui.main_menu_focus_navigation_active {
		ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(ui.main_menu_selected)
	}
}

app_ui_main_menu_apply_navigation :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	app_ui_main_menu_sync_slot_to_selection(ui, gui)

	direction := 0
	if gui.input.focus_next {
		direction = 1
	} else if gui.input.focus_prev {
		direction = -1
	} else if gui.input.nav_pressed_y > 0 {
		direction = 1
	} else if gui.input.nav_pressed_y < 0 {
		direction = -1
	}

	if direction != 0 {
		if (gui.input.focus_next || gui.input.focus_prev) && gui.focused == uifw.GUI_ID_NONE && !ui.main_menu_focus_navigation_active {
			ui.main_menu_focus_slot = direction > 0 ? MAIN_MENU_TITLE_SLOT : app_ui_main_menu_quit_slot()
		} else {
			if !ui.main_menu_focus_navigation_active {
				ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(ui.main_menu_selected)
			}
			ui.main_menu_focus_slot = app_ui_main_menu_clamp_slot(ui.main_menu_focus_slot + direction)
		}
		ui.main_menu_focus_navigation_active = true
		gui.focus_moved = true
		if index, ok := app_ui_main_menu_simulation_index_for_slot(ui.main_menu_focus_slot); ok {
			ui.main_menu_selected = index
		}
		return
	}

	if gui.input.nav_pressed_x > 0 {
		if _, ok := app_ui_main_menu_simulation_index_for_slot(ui.main_menu_focus_slot); ok {
			ui.main_menu_focus_slot = app_ui_main_menu_options_slot()
			ui.main_menu_focus_navigation_active = true
			gui.focus_moved = true
		}
	} else if gui.input.nav_pressed_x < 0 {
		if ui.main_menu_focus_slot == app_ui_main_menu_options_slot() ||
		   ui.main_menu_focus_slot == app_ui_main_menu_quit_slot() {
			ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(ui.main_menu_selected)
			ui.main_menu_focus_navigation_active = true
			gui.focus_moved = true
		}
	}
}

app_ui_main_menu_request_close :: proc(worker: ^Product_Context) {
	if worker == nil || worker.render_to_ui == nil {
		return
	}
	msg: Render_To_Ui_Message
	msg.kind = .Request_Close
	_ = engine.queue_try_push(worker.render_to_ui, msg)
}

app_ui_main_menu_activate_slot :: proc(ui: ^App_Ui_State, slot: int, worker: ^Product_Context) {
	clamped_slot := app_ui_main_menu_clamp_slot(slot)
	if index, ok := app_ui_main_menu_simulation_index_for_slot(clamped_slot); ok {
		ui.main_menu_selected = index
		app_ui_navigate(ui, app_ui_mode_for_simulation_index(index))
		return
	}
	if clamped_slot == MAIN_MENU_TITLE_SLOT {
		ui.main_menu_palette_randomize_requested = true
	} else if clamped_slot == app_ui_main_menu_options_slot() {
		app_ui_navigate(ui, .Options)
	} else if clamped_slot == app_ui_main_menu_quit_slot() {
		app_ui_main_menu_request_close(worker)
	}
}

app_ui_main_menu_scroll_simulation_into_view :: proc(ui: ^App_Ui_State, viewport: uifw.Rect, content_h, row_gap: f32, theme: Menu_Theme) {
	index, ok := app_ui_main_menu_simulation_index_for_slot(ui.main_menu_focus_slot)
	if !ok {
		return
	}
	max_scroll := max(content_h - viewport.h, 0)
	row_step := theme.row_height + row_gap
	row_top := f32(index) * row_step
	row_bottom := row_top + theme.row_height
	padding := min(max(row_gap * 0.45, 8), max(viewport.h * 0.18, 0))
	if row_top < ui.main_menu_scroll + padding {
		ui.main_menu_scroll = row_top - padding
	} else if row_bottom > ui.main_menu_scroll + viewport.h - padding {
		ui.main_menu_scroll = row_bottom - viewport.h + padding
	}
	ui.main_menu_scroll = min(max(ui.main_menu_scroll, 0), max_scroll)
}

app_ui_main_menu_text_button_size :: proc(gui: ^uifw.Gui_Context, label: string, theme: Menu_Theme) -> uifw.Vec2 {
	text_scale := gui.style.heading_text_scale * MAIN_MENU_TEXT_BUTTON_SCALE_MULTIPLIER
	bytes := transmute([]u8)label
	fallback_advance := gui.style.char_width * text_scale / max(gui.style.text_scale, 0.001)
	text_w := uifw.gui_font_text_width(.SimStart, bytes, text_scale, fallback_advance)
	text_h := uifw.GUI_FONT_LOGICAL_HEIGHT * text_scale
	padding_x := max(theme.small_gap * 2.0, text_h * 0.20)
	padding_y := max(theme.small_gap * 1.4, text_h * 0.14)
	return {text_w + padding_x * 2, text_h + padding_y * 2}
}

app_ui_fit_sim_start_text_scale :: proc(gui: ^uifw.Gui_Context, label: string, desired_scale, max_width: f32) -> f32 {
	if max_width <= 1 || desired_scale <= 0 || len(label) == 0 {
		return desired_scale
	}
	bytes := transmute([]u8)label
	fallback_advance := gui.style.char_width * desired_scale / max(gui.style.text_scale, 0.001)
	text_w := uifw.gui_font_text_width(.SimStart, bytes, desired_scale, fallback_advance)
	if text_w <= max_width || text_w <= 0 {
		return desired_scale
	}
	return desired_scale * max_width / text_w
}

app_ui_menu_theme :: proc(gui: ^uifw.Gui_Context, width, height: f32) -> Menu_Theme {
	scale := min(max(min(width / 1920, height / 1080), 0.72), 1.35)
	return {
		panel = {0.09, 0.11, 0.13, 0.24},
		panel_top = {0.70, 0.78, 0.86, 0.22},
		surface = {0.08, 0.10, 0.12, 0.34},
		surface_hot = {0.18, 0.21, 0.24, 0.40},
		surface_selected = {0.24, 0.28, 0.32, 0.46},
		preview_surface = {0.018, 0.022, 0.028, 1.0},
		footer_surface = {0.09, 0.11, 0.13, 0.24},
		border = {1.00, 1.00, 1.00, 0.18},
		border_hot = {1.00, 1.00, 1.00, 0.58},
		accent = {1.00, 1.00, 1.00, 1.0},
		accent_soft = {1.00, 1.00, 1.00, 0.20},
		text = {1.00, 1.00, 1.00, 1.0},
		text_muted = {0.90, 0.90, 0.90, 0.88},
		text_dim = {1.00, 1.00, 1.00, 0.68},
		chip = {0.08, 0.10, 0.12, 0.28},
		chip_border = {1.0, 1.0, 1.0, 0.20},
		danger = {0.90, 0.18, 0.16, 1.0},
		shadow = {0, 0, 0, 0.42},
		panel_padding = gui.style.spacing_4 * scale,
		inner_gap = max(gui.style.spacing_4 * 1.1 * scale, 18),
		item_gap = max(height * 0.032, gui.style.spacing_3 * 1.35 * scale),
		small_gap = max(gui.style.spacing_2 * scale, 6),
		footer_height = max(gui.style.row_height * 2.20 * scale, 88),
		footer_gap = gui.style.spacing_2 * scale,
		row_height = min(max(height * 0.165, gui.style.row_height * 3.0 * scale), height * 0.20),
		thumbnail_width = 0,
		thumbnail_height = 0,
		chip_height = 0,
		chip_gap = 0,
		detail_min_width = 0,
		detail_gap = max(gui.style.spacing_4 * 2.6 * scale, 36),
		radius = max(gui.style.radius_panel, f32(5)),
		card_radius = max(gui.style.radius_control, f32(5)),
		border_width = 1,
		start_width = 0,
	}
}

app_ui_draw_main_menu_backdrop :: proc(gui: ^uifw.Gui_Context, bounds: uifw.Rect, theme: Menu_Theme) {
	_ = gui
	_ = bounds
	_ = theme
}

app_ui_menu_glass_style :: proc(gui: ^uifw.Gui_Context, theme: Menu_Theme, radius: f32, emphasis: f32 = 0) -> uifw.Gui_Glass_Style {
	glass := uifw.gui_default_glass_style(gui, radius)
	t := uifw.gui_clamp01(emphasis)
	glass.tint = uifw.gui_lerp_color(theme.surface, theme.surface_selected, t)
	glass.tint.a = 0.34 + t * 0.14
	glass.roughness = 0.42 + t * 0.18
	glass.thickness = max(gui.style.rhythm * (0.18 + t * 0.06), f32(7))
	glass.bevel = max(gui.style.border_width * (5.5 + t * 1.5), f32(5))
	glass.dispersion = 0.70 + t * 0.35
	glass.border = 0.28 + t * 0.34
	glass.highlight = 0.34 + t * 0.22
	return glass
}

app_ui_draw_menu_chip :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, label: string, theme: Menu_Theme, emphasis: f32) {
	fill := uifw.gui_lerp_color(theme.chip, theme.accent_soft, emphasis)
	border := uifw.gui_lerp_color(theme.chip_border, theme.accent, emphasis * 0.45)
	uifw.gui_box(gui, rect, {
		fill = fill,
		border = border,
		radius = rect.h * 0.5,
		border_width = theme.border_width,
	})
	app_ui_draw_menu_centered_text(gui, rect, label, uifw.gui_lerp_color(theme.text_dim, theme.text_muted, emphasis))
}

app_ui_draw_menu_centered_text :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, label: string, color: uifw.Color) {
	text_w := uifw.gui_text_width(gui, label)
	pos := uifw.Vec2{
		rect.x + max((rect.w - text_w) * 0.5, 0),
		rect.y + max((rect.h - gui.style.body_text_height) * 0.5, 0),
	}
	uifw.gui_text_clipped(gui, rect, pos, label, color)
}

app_ui_draw_main_menu_button :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, key, label: string, theme: Menu_Theme, primary, danger: bool) -> bool {
	id := uifw.gui_make_id(gui, key)
	control := uifw.gui_control(gui, id, rect, true)
	hot_t := uifw.gui_animate_value(gui, uifw.gui_id_child(id, "hot"), (control.hovered || control.focused || gui.active == id) ? f32(1) : f32(0), 14)
	base := primary ? theme.accent_soft : theme.surface
	target := primary ? uifw.gui_lerp_color(theme.accent_soft, theme.accent, 0.55) : theme.surface_hot
	if danger {
		target = uifw.gui_lerp_color(theme.surface_hot, theme.danger, 0.22)
	}
	fill := uifw.gui_lerp_color(base, target, hot_t)
	border := uifw.gui_lerp_color(theme.border, theme.border_hot, hot_t)
	glass := app_ui_menu_glass_style(gui, theme, theme.card_radius, hot_t)
	glass.tint = fill
	uifw.gui_shadow(gui, rect, theme.card_radius, {0, theme.small_gap * 0.65}, theme.inner_gap, theme.shadow)
	uifw.gui_refractive_glass_rect(gui, rect, glass)
	uifw.gui_round_stroke(gui, rect, theme.card_radius, border, theme.border_width)
	if control.focused {
		uifw.gui_focus_ring(gui, rect)
	}
	uifw.gui_text_aligned_font(gui, rect, label, theme.text, .Center, .Body, gui.style.heading_text_scale)
	return control.activated || (control.hovered && gui.active == id && gui.input.mouse_released)
}

app_ui_draw_main_menu_text_button :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, key, label: string, theme: Menu_Theme, muted_at_rest := false, force_highlight := false) -> bool {
	text_scale := gui.style.heading_text_scale * MAIN_MENU_TEXT_BUTTON_SCALE_MULTIPLIER
	bytes := transmute([]u8)label
	fallback_advance := gui.style.char_width * text_scale / max(gui.style.text_scale, 0.001)
	text_w := uifw.gui_font_text_width(.SimStart, bytes, text_scale, fallback_advance)
	text_h := uifw.GUI_FONT_LOGICAL_HEIGHT * text_scale
	padding_x := max(theme.small_gap * 2.0, text_h * 0.20)
	padding_y := max(theme.small_gap * 1.4, text_h * 0.14)
	button_w := max(rect.w, text_w + padding_x * 2)
	button_h := max(rect.h, text_h + padding_y * 2)
	button := uifw.Rect{
		rect.x + (rect.w - button_w) * 0.5,
		rect.y + (rect.h - button_h) * 0.5,
		button_w,
		button_h,
	}
	text_rect := uifw.Rect{
		button.x + padding_x,
		button.y + max((button.h - text_h) * 0.5, 0),
		max(button.w - padding_x * 2, 1),
		text_h,
	}

	id := uifw.gui_make_id(gui, key)
	control := uifw.gui_control(gui, id, button, true)
	hot_t := uifw.gui_animate_value(gui, uifw.gui_id_child(id, "text_hot"), (force_highlight || control.hovered || control.focused || gui.active == id) ? f32(1) : f32(0), 16)
	if hot_t > 0.01 || control.focused {
		glass := app_ui_menu_glass_style(gui, theme, theme.card_radius, hot_t)
		glass.tint.a = 0.12 + hot_t * 0.08
		uifw.gui_refractive_glass_rect(gui, button, glass)
	}
	if hot_t > 0.01 {
		stroke := uifw.gui_apply_opacity(theme.text, 0.95 * hot_t)
		uifw.gui_round_stroke(gui, button, theme.card_radius, stroke, MAIN_MENU_TEXT_BUTTON_FOCUS_BORDER_WIDTH)
	}
	text_color := muted_at_rest ? uifw.gui_lerp_color(theme.text_dim, theme.text, hot_t) : theme.text
	uifw.gui_text_aligned_font(gui, text_rect, label, text_color, .Left, .SimStart, text_scale)
	return control.activated || (control.hovered && gui.active == id && gui.input.mouse_released)
}

app_ui_draw_main_menu_footer_button :: proc(gui: ^uifw.Gui_Context, actions: uifw.Rect, index, count: int, key, label: string, theme: Menu_Theme, danger: bool) -> bool {
	gap_total := theme.item_gap * f32(max(count - 1, 0))
	cell_w := max((actions.w - gap_total - theme.small_gap * 2) / f32(max(count, 1)), 1)
	button_h := max(actions.h - theme.small_gap * 2, 1)
	rect := uifw.Rect{actions.x + theme.small_gap + f32(index) * (cell_w + theme.item_gap), actions.y + theme.small_gap, cell_w, button_h}
	return app_ui_draw_main_menu_button(gui, rect, key, label, theme, false, danger)
}
