package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"
import "core:math"

app_ui_draw_particle_life :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, worker: ^Product_Context) {
	width := f32(vk_ctx.swapchain_extent.width)
	height := f32(vk_ctx.swapchain_extent.height)
	pause_consumed := simulation_controller_ui_update_input(ui, gui)
	if gui.input.pause && !pause_consumed {
		sim.settings.paused = !sim.settings.paused
	}
	if sim.canvas_tool.changed {
		set := canvas_tool_set_for_mode(.Particle_Life)
		tool := canvas_tool_selected(&set, &sim.canvas_tool)
		uifw.gui_notice(gui, fmt.tprintf("%s selected — Primary: %s · Secondary: %s", tool.name, tool.primary_label, tool.secondary_label), 1.6)
	}
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
