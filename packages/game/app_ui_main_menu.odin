package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"
import "core:math"

app_ui_draw_main_menu :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, vk_ctx: ^engine.Vk_Context, worker: ^Product_Context) {
	width := f32(vk_ctx.swapchain_extent.width)
	height := f32(vk_ctx.swapchain_extent.height)
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
		row_height = min(max(height * 0.205, gui.style.row_height * 3.6 * scale), height * 0.245),
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

app_ui_draw_particle_life :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, worker: ^Product_Context) {
	width := f32(vk_ctx.swapchain_extent.width)
	height := f32(vk_ctx.swapchain_extent.height)
	pause_consumed := simulation_controller_ui_update_input(ui, gui)
	if gui.input.pause && !pause_consumed {
		sim.settings.paused = !sim.settings.paused
	}
	particle_life_draw_blob_overlay(sim, gui, width, height)
	if ui.simulation_shell.controls_visible {
		tool_set := canvas_tool_set_for_mode(.Particle_Life)
		tool := canvas_tool_selected(&tool_set, &sim.canvas_tool)
		name := fmt.tprintf("Particle Life · %s — Primary: %s · Secondary: %s", tool.name, tool.primary_label, tool.secondary_label)
		app_ui_draw_simulation_bar(ui, gui, .Particle_Life, nil, sim, nil, sim.settings.paused, !sim.gpu.ready, name, vk_ctx, width, worker)
	}
	simulation_controller_ui_draw(ui, gui, particle = sim, width = width, height = height, worker = worker)
	app_ui_draw_loading_overlay(gui, width, height, !sim.gpu.ready)
}

app_ui_mode_for_simulation_index :: proc(index: int) -> App_Mode {
	switch index {
	case 0:
		return .Slime_Mold
	case 1:
		return .Gray_Scott
	case 2:
		return .Particle_Life
	case 3:
		return .Flow_Field
	case 4:
		return .Pellets
	case 5:
		return .Gradient_Editor
	case 6:
		return .Voronoi_CA
	case 7:
		return .Moire
	case 8:
		return .Vectors
	case 9:
		return .Primordial
	case:
		return .Main_Menu
	}
}

app_ui_draw_main_menu_content :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, bounds: uifw.Rect, theme: Menu_Theme) {
	app_ui_draw_main_menu_list(ui, gui, bounds, theme)
}

app_ui_draw_main_menu_list :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, bounds: uifw.Rect, theme: Menu_Theme) {
	row_gap := gui.style.spacing
	content_h := f32(len(APP_SIMULATION_NAMES)) * theme.row_height + f32(max(len(APP_SIMULATION_NAMES) - 1, 0)) * row_gap
	viewport := app_ui_main_menu_list_viewport(gui, bounds)
	if ui.main_menu_focus_navigation_active {
		app_ui_main_menu_scroll_simulation_into_view(ui, viewport, content_h, row_gap, theme)
	}
	saved_scrollbar_width := gui.style.scrollbar_width
	saved_scrollbar_gutter := gui.style.scrollbar_gutter
	saved_control := gui.style.control
	saved_text_muted := gui.style.text_muted
	gui.style.scrollbar_width = max(saved_scrollbar_width * 1.65, f32(9))
	gui.style.scrollbar_gutter = max(saved_scrollbar_gutter, gui.style.spacing_1)
	gui.style.control = uifw.gui_apply_opacity(theme.text, 0.24)
	gui.style.text_muted = theme.text
	uifw.gui_scroll_begin_draggable(gui, viewport, content_h, &ui.main_menu_scroll)
	uifw.gui_push_id(gui, "main_menu_simulations")
	if ui.main_menu_focus_navigation_active {
		if index, ok := app_ui_main_menu_simulation_index_for_slot(ui.main_menu_focus_slot); ok {
			gui.focused = uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", index))
		} else {
			for i in 0 ..< len(APP_SIMULATION_NAMES) {
				if gui.focused == uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", i)) {
					gui.focused = uifw.GUI_ID_NONE
					break
				}
			}
		}
	}
	rows: [len(APP_SIMULATION_NAMES)]uifw.Rect
	hovered_index := -1
	for i in 0 ..< len(APP_SIMULATION_NAMES) {
		rows[i] = uifw.gui_next_rect(gui, height = theme.row_height)
		if uifw.gui_mouse_contains(gui, rows[i]) {
			hovered_index = i
		}
	}
	if hovered_index >= 0 && !ui.main_menu_focus_navigation_active {
		ui.main_menu_selected = hovered_index
		ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(hovered_index)
		gui.focused = uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", hovered_index))
	}
	for i in 0 ..< len(APP_SIMULATION_NAMES) {
		row := rows[i]
		if app_ui_draw_simulation_row(ui, gui, row, viewport, i, theme) {
			ui.main_menu_selected = i
			ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(i)
			app_ui_navigate(ui, app_ui_mode_for_simulation_index(i))
		}
		id := uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", i))
		if gui.focused == id {
			ui.main_menu_selected = i
			ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(i)
		}
	}
	for i in 0 ..< len(APP_SIMULATION_NAMES) {
		id := uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", i))
		if gui.focused == id {
			ui.main_menu_selected = i
			ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(i)
		}
	}
	uifw.gui_pop_id(gui)
	uifw.gui_scroll_end(gui)
	gui.style.scrollbar_width = saved_scrollbar_width
	gui.style.scrollbar_gutter = saved_scrollbar_gutter
	gui.style.control = saved_control
	gui.style.text_muted = saved_text_muted

	max_scroll := max(content_h - viewport.h, 0)
	if ui.main_menu_scroll < max_scroll - 0.5 {
		fade_h := min(max(gui.style.rhythm * 0.78, f32(14)), viewport.h * 0.18)
		uifw.gui_gradient_rect(gui, {viewport.x, viewport.y + viewport.h - fade_h, viewport.w, fade_h}, {0, 0, 0, 0}, {0, 0, 0, 0.58})
	}
	app_ui_draw_main_menu_instruction_strip(ui, gui, app_ui_main_menu_list_hint_rect(gui, bounds), theme)
}

app_ui_main_menu_list_hint_height :: proc(gui: ^uifw.Gui_Context) -> f32 {
	return max(gui.style.small_line_height * 1.65, f32(28))
}

app_ui_main_menu_list_viewport :: proc(gui: ^uifw.Gui_Context, bounds: uifw.Rect) -> uifw.Rect {
	hint_h := app_ui_main_menu_list_hint_height(gui)
	gap := max(gui.style.spacing_1, f32(5))
	if gui.input.window_width > 0 && gui.input.window_width < 920 {
		return {bounds.x, bounds.y + hint_h + gap, bounds.w, max(bounds.h - hint_h - gap, gui.style.row_height)}
	}
	return {bounds.x, bounds.y, bounds.w, max(bounds.h - hint_h - gap, gui.style.row_height)}
}

app_ui_main_menu_list_hint_rect :: proc(gui: ^uifw.Gui_Context, bounds: uifw.Rect) -> uifw.Rect {
	hint_h := app_ui_main_menu_list_hint_height(gui)
	if gui.input.window_width > 0 && gui.input.window_width < 920 {
		return {bounds.x, bounds.y, bounds.w, hint_h}
	}
	return {bounds.x, bounds.y + bounds.h - hint_h, bounds.w, hint_h}
}

app_ui_main_menu_catalog_eyebrow_label :: proc() -> string {
	return fmt.tprintf("%d SIMULATIONS", len(APP_SIMULATION_NAMES))
}

app_ui_main_menu_catalog_eyebrow_height :: proc(gui: ^uifw.Gui_Context) -> f32 {
	return max(gui.style.small_line_height, f32(18))
}

app_ui_main_menu_catalog_list_bounds :: proc(gui: ^uifw.Gui_Context, bounds: uifw.Rect) -> uifw.Rect {
	eyebrow_h := app_ui_main_menu_catalog_eyebrow_height(gui)
	gap := max(gui.style.spacing_1, f32(5))
	return {bounds.x, bounds.y + eyebrow_h + gap, bounds.w, max(bounds.h - eyebrow_h - gap, gui.style.row_height)}
}

app_ui_draw_main_menu_catalog_eyebrow :: proc(gui: ^uifw.Gui_Context, list: uifw.Rect, theme: Menu_Theme) {
	label := app_ui_main_menu_catalog_eyebrow_label()
	height := app_ui_main_menu_catalog_eyebrow_height(gui)
	rect := uifw.Rect{list.x + theme.border_width, list.y, max(list.w - theme.border_width * 2, 1), height}
	uifw.gui_text_aligned_font(gui, rect, label, theme.text_dim, .Left, .Body, gui.style.small_text_scale)
}

app_ui_draw_main_menu_instruction_strip :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, theme: Menu_Theme) {
	if rect.w <= 1 || rect.h <= 1 {
		return
	}
	uifw.gui_round_rect(gui, rect, theme.card_radius, {0, 0, 0, 0.32})
	content := uifw.gui_inset_edges(rect, {left = gui.style.spacing_1, top = 0, right = gui.style.spacing_1, bottom = 0})
	if gui.input.active_device == .Controller {
		accept, _ := controller_prompt_face_icons(&ui.settings)
		items := [?]Controller_Prompt_Hint {
			{icons = {.Dpad, .Dpad, .Dpad}, icon_count = 1, label = "Browse"},
			{icons = {accept, .Dpad, .Dpad}, icon_count = 1, label = "Start"},
		}
		controller_prompt_draw_items(gui, content, items[:])
		return
	}
	label := "Scroll / \u2191\u2193  Browse   \u2022   Enter / Click  Start"
	if rect.w < gui.style.body_char_width * 43 {
		label = "Scroll / \u2191\u2193 Browse  \u2022  Enter Start"
	}
	app_ui_draw_menu_centered_text(gui, content, label, theme.text_muted)
}

app_ui_draw_simulation_row :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, bounds, clip_bounds: uifw.Rect, index: int, theme: Menu_Theme) -> bool {
	id := uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", index))
	control := uifw.gui_control(gui, id, bounds, true)
	hover_t := uifw.gui_animate_value(gui, uifw.gui_id_child(id, "hover"), (control.hovered || control.focused) ? f32(1) : f32(0), 14)
	card := uifw.gui_inset(bounds, theme.border_width)
	clipped_card := uifw.gui_rect_intersection(card, clip_bounds)
	if clipped_card.w <= 1 || clipped_card.h <= 1 {
		return false
	}
	mode := app_ui_mode_for_simulation_index(index)
	live_preview := app_ui_live_preview_supported(mode)

	border := uifw.gui_lerp_color(theme.border, theme.border_hot, hover_t)
	emphasis := hover_t
	if !live_preview {
		uifw.gui_refractive_glass_rect(gui, card, app_ui_menu_glass_style(gui, theme, theme.card_radius, emphasis))
	}

	preview := uifw.gui_inset(card, theme.border_width)
	clipped_preview := uifw.gui_rect_intersection(preview, clip_bounds)
	if clipped_preview.w > 1 && clipped_preview.h > 1 {
		app_ui_draw_live_simulation_preview(ui, gui, preview, clipped_preview, mode, theme.preview_surface, f32(index))
	}
	if live_preview {
		uifw.gui_refractive_glass_rect(gui, card, app_ui_menu_glass_style(gui, theme, theme.card_radius, emphasis))
	}
	uifw.gui_round_stroke(gui, card, theme.card_radius, border, theme.border_width)

	uifw.gui_scissor_begin(gui, clipped_card)
	if clipped_preview.w > 1 && clipped_preview.h > 1 {
		mid_x := preview.x + preview.w * MAIN_MENU_SIM_BUTTON_GRADIENT_MIDPOINT
		left_fade := uifw.gui_rect_intersection(
			{preview.x, preview.y, max(mid_x - preview.x, 0), preview.h},
			clipped_preview,
		)
		right_fade := uifw.gui_rect_intersection(
			{mid_x, preview.y, max(preview.x + preview.w - mid_x, 0), preview.h},
			clipped_preview,
		)
		if left_fade.w > 1 && left_fade.h > 1 {
			uifw.gui_horizontal_gradient_rect(gui, left_fade, {0, 0, 0, 1.0}, {0, 0, 0, 0.62})
		}
		if right_fade.w > 1 && right_fade.h > 1 {
			uifw.gui_horizontal_gradient_rect(gui, right_fade, {0, 0, 0, 0.62}, {0, 0, 0, 0.0})
		}
	}
	if hover_t > 0.01 {
		uifw.gui_round_rect(gui, card, theme.card_radius, uifw.gui_lerp_color({1, 1, 1, 0.0}, {1, 1, 1, 0.13}, hover_t))
	}
	label_inset := max(theme.inner_gap, 22)
	utility_reserve := max(gui.style.scrollbar_width + gui.style.scrollbar_gutter + gui.style.spacing_2, f32(28))
	label_max_w := max(card.w - label_inset * 2 - utility_reserve, 1)
	label_scale := app_ui_fit_sim_start_text_scale(gui, APP_SIMULATION_NAMES[index], gui.style.heading_text_scale * (card.h >= 96 ? f32(1.95) : f32(1.35)), label_max_w)
	label_h := uifw.GUI_FONT_LOGICAL_HEIGHT * label_scale
	label := uifw.Rect{
		card.x + label_inset,
		card.y + max((card.h - label_h) * 0.5, 0),
		label_max_w,
		label_h,
	}
	uifw.gui_text_aligned_font(gui, label, APP_SIMULATION_NAMES[index], theme.text, .Left, .SimStart, label_scale)
	uifw.gui_scissor_end(gui)

	if control.focused {
		uifw.gui_focus_ring(gui, uifw.gui_inset(card, -theme.border_width))
	}
	return control.activated || (control.hovered && gui.active == id && gui.input.mouse_released)
}

app_ui_draw_main_menu_detail :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, bounds: uifw.Rect, theme: Menu_Theme) {
	_ = ui
	_ = gui
	_ = bounds
	_ = theme
}

app_ui_live_preview_supported :: proc(mode: App_Mode) -> bool {
	#partial switch mode {
	case .Slime_Mold, .Gray_Scott, .Particle_Life, .Flow_Field, .Pellets, .Voronoi_CA, .Moire, .Vectors, .Primordial:
		return true
	case:
		return false
	}
}

app_ui_draw_live_simulation_preview :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect, clip_rect: uifw.Rect, mode: App_Mode, fallback_color: uifw.Color, seed: f32) {
	if app_ui_live_preview_supported(mode) {
		ui.main_menu_live_preview_visible = true
		ui.main_menu_live_preview_mode = mode
		ui.main_menu_live_preview_rect = rect
		if ui.main_menu_preview_slot_count < MAIN_MENU_PREVIEW_SLOT_CAP {
			ui.main_menu_preview_slots[ui.main_menu_preview_slot_count] = {mode = mode, rect = rect, clip_rect = clip_rect, fallback_color = fallback_color}
			ui.main_menu_preview_slot_count += 1
		}
		uifw.gui_round_stroke(gui, clip_rect, gui.style.radius_control, gui.style.panel_border, gui.style.border_width)
		return
	}
	app_ui_draw_simulation_preview(ui, gui, clip_rect, mode, seed)
}

app_ui_draw_lut_gradient_preview :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect) {
	scheme := color_scheme_effective(&ui.main_menu_palette, true)
	segment_count :: COLOR_SCHEME_SIZE
	for i in 0 ..< segment_count {
		x0 := rect.x + rect.w * f32(i) / f32(segment_count)
		x1 := rect.x + rect.w * f32(i + 1) / f32(segment_count)
		left := color_scheme_color_at(scheme, i * (COLOR_SCHEME_SIZE - 1) / segment_count)
		right := color_scheme_color_at(scheme, (i + 1) * (COLOR_SCHEME_SIZE - 1) / segment_count)
		uifw.gui_horizontal_gradient_rect(
			gui,
			{x0, rect.y, x1 - x0, rect.h},
			{left[0], left[1], left[2], left[3]},
			{right[0], right[1], right[2], right[3]},
		)
	}
}

app_ui_draw_simulation_preview :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, mode: App_Mode, seed: f32) {
	if rect.w <= 0 || rect.h <= 0 {
		return
	}
	uifw.gui_round_rect(gui, rect, gui.style.radius_control, {0.015, 0.018, 0.026, 0.96})
	uifw.gui_round_stroke(gui, rect, gui.style.radius_control, gui.style.panel_border, gui.style.border_width)
	clip := uifw.gui_inset(rect, gui.style.border_width)
	uifw.gui_scissor_begin(gui, clip)
	t := f32(gui.frame_index % 240) / 240.0
	cx := rect.x + rect.w * 0.5
	cy := rect.y + rect.h * 0.5
	min_d := min(rect.w, rect.h)

	#partial switch mode {
	case .Slime_Mold:
		uifw.gui_gradient_rect(gui, rect, {0.02, 0.04, 0.025, 1}, {0.08, 0.16, 0.10, 1})
		for i in 0 ..< 8 {
			a := f32(i) * 0.785 + t * 2.0
			r := min_d * (0.12 + f32(i % 4) * 0.055)
			p := uifw.Vec2{cx + math.cos(a) * r, cy + math.sin(a * 1.7) * r}
			uifw.gui_line(gui, p, {p.x + math.cos(a + 1.4) * min_d * 0.22, p.y + math.sin(a + 1.4) * min_d * 0.22}, {0.52, 1.0, 0.58, 0.45}, max(gui.style.border_width, 1))
		}
	case .Gray_Scott:
		uifw.gui_gradient_rect(gui, rect, {0.03, 0.035, 0.08, 1}, {0.20, 0.10, 0.28, 1})
		for i in 0 ..< 6 {
			r := min_d * (0.10 + f32(i) * 0.055)
			uifw.gui_ellipse_stroke(gui, {cx - r, cy - r, r * 2, r * 2}, {0.65, 0.88, 1.0, 0.18 + f32(i) * 0.035}, max(gui.style.border_width, 1))
		}
	case .Particle_Life:
		uifw.gui_rect(gui, rect, {0.015, 0.018, 0.024, 1})
		for i in 0 ..< 18 {
			a := f32(i) * 2.399 + seed
			r := min_d * (0.10 + f32(i % 7) * 0.045)
			x := cx + math.cos(a + t) * r
			y := cy + math.sin(a * 1.3 - t) * r
			color := (i % 3 == 0) ? uifw.Color{0.95, 0.34, 0.42, 0.88} : ((i % 3 == 1) ? uifw.Color{0.28, 0.80, 1.0, 0.88} : uifw.Color{0.95, 0.82, 0.32, 0.88})
			s := max(min_d * 0.035, 2)
			uifw.gui_ellipse(gui, {x - s, y - s, s * 2, s * 2}, color)
		}
	case .Flow_Field:
		uifw.gui_gradient_rect(gui, rect, {0.02, 0.03, 0.06, 1}, {0.05, 0.16, 0.18, 1})
		for i in 0 ..< 7 {
			y := rect.y + rect.h * (f32(i) + 0.5) / 7.0
			uifw.gui_line(gui, {rect.x + rect.w * 0.12, y}, {rect.x + rect.w * 0.88, y + math.sin(f32(i) + t * 6.0) * rect.h * 0.10}, {0.35, 0.95, 0.95, 0.40}, max(gui.style.border_width, 1))
		}
	case .Pellets:
		uifw.gui_rect(gui, rect, {0.04, 0.03, 0.025, 1})
		for i in 0 ..< 10 {
			x := rect.x + rect.w * (0.14 + f32((i * 37) % 73) / 100.0)
			y := rect.y + rect.h * (0.18 + f32((i * 19) % 67) / 100.0)
			s := min_d * (0.035 + f32(i % 3) * 0.014)
			uifw.gui_ellipse(gui, {x - s, y - s, s * 2, s * 2}, {0.95, 0.63, 0.24, 0.85})
		}
	case .Gradient_Editor:
		app_ui_draw_lut_gradient_preview(ui, gui, rect)
	case .Voronoi_CA:
		uifw.gui_rect(gui, rect, {0.025, 0.025, 0.035, 1})
		cell := max(min_d * 0.18, 4)
		for y := rect.y; y < rect.y + rect.h; y += cell {
			for x := rect.x; x < rect.x + rect.w; x += cell {
				k := int((x + y + seed * 17) / cell) % 3
				color := k == 0 ? uifw.Color{0.16, 0.72, 0.68, 0.65} : (k == 1 ? uifw.Color{0.86, 0.34, 0.48, 0.58} : uifw.Color{0.88, 0.78, 0.30, 0.50})
				uifw.gui_rect(gui, {x, y, cell - gui.style.border_width, cell - gui.style.border_width}, color)
			}
		}
	case .Moire:
		uifw.gui_rect(gui, rect, {0.02, 0.02, 0.028, 1})
		for i in 0 ..< 9 {
			a := -0.7 + f32(i) * 0.17
			x := rect.x + rect.w * f32(i) / 8.0
			uifw.gui_rotated_rect(gui, {x, cy, rect.w * 0.9, max(gui.style.border_width, 1)}, a, {0.94, 0.84, 0.36, 0.20})
		}
	case .Vectors:
		uifw.gui_rect(gui, rect, {0.015, 0.025, 0.028, 1})
		for i in 0 ..< 6 {
			x := rect.x + rect.w * (0.15 + f32(i) * 0.14)
			y := rect.y + rect.h * (0.25 + f32(i % 3) * 0.22)
			a := f32(i) * 0.7 + t * 2
			d := min_d * 0.12
			uifw.gui_line(gui, {x - math.cos(a) * d, y - math.sin(a) * d}, {x + math.cos(a) * d, y + math.sin(a) * d}, {0.58, 0.93, 0.88, 0.75}, max(gui.style.border_width, 1))
		}
	case .Primordial:
		uifw.gui_gradient_rect(gui, rect, {0.025, 0.016, 0.04, 1}, {0.10, 0.04, 0.13, 1})
		for i in 0 ..< 12 {
			a := f32(i) * 0.86 + t * 4
			r := min_d * (0.08 + f32(i) * 0.018)
			s := max(min_d * 0.025, 2)
			uifw.gui_ellipse(gui, {cx + math.cos(a) * r - s, cy + math.sin(a * 1.2) * r - s, s * 2, s * 2}, {0.96, 0.42, 0.95, 0.55})
		}
	case:
		uifw.gui_rect(gui, rect, {0.08, 0.08, 0.10, 1})
	}
	uifw.gui_scissor_end(gui)
}
