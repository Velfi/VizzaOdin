package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"
import "core:math"
import "core:c"
import sdl "vendor:sdl3"

app_ui_draw_theme_preview :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, vk_ctx: ^engine.Vk_Context) {
	if ui.component_fixture != .None {
		app_ui_draw_component_fixture(ui, gui)
		return
	}
	width := f32(vk_ctx.swapchain_extent.width)
	height := f32(vk_ctx.swapchain_extent.height)
	margin := f32(28)
	panel := uifw.Rect{margin, margin, max(width - margin * 2, 0), max(height - margin * 2, 0)}
	uifw.gui_panel_begin(gui, panel)
	uifw.gui_heading(gui, "UI Theme Preview")
	uifw.gui_label(gui, "Design sheet for the immediate-mode UI package")
	uifw.gui_spacer(gui, 10)

	sheet := uifw.gui_next_rect(gui, height = max(panel.h - 154, 0))
	column_gap := gui.style.spacing
	column_width := max((sheet.w - column_gap * 4) / 5, 0)
	controls := uifw.Rect{sheet.x, sheet.y, column_width, sheet.h}
	inputs := uifw.Rect{sheet.x + (column_width + column_gap), sheet.y, column_width, sheet.h}
	text_palette := uifw.Rect{sheet.x + (column_width + column_gap) * 2, sheet.y, column_width, sheet.h}
	media_layout := uifw.Rect{sheet.x + (column_width + column_gap) * 3, sheet.y, column_width, sheet.h}
	advanced := uifw.Rect{sheet.x + (column_width + column_gap) * 4, sheet.y, column_width, sheet.h}

	app_ui_theme_preview_controls(gui, controls)
	app_ui_theme_preview_inputs(gui, inputs)
	app_ui_theme_preview_text_palette(gui, text_palette)
	app_ui_theme_preview_media_layout(gui, media_layout)
	app_ui_theme_preview_advanced(ui, gui, advanced)
	uifw.gui_panel_end(gui)
}

app_ui_component_fixture_name :: proc(fixture: Ui_Component_Fixture) -> string {
	switch fixture {
	case .Button: return "Button"
	case .Toggle: return "Toggle"
	case .Slider: return "Slider"
	case .Number: return "Universal Number"
	case .Integer: return "Universal Integer"
	case .Selector: return "Selector"
	case .Text_Input: return "Text Input"
	case .None: return "Component"
	}
	return "Component"
}

app_ui_component_fixture_apply_state :: proc(gui: ^uifw.Gui_Context, id: uifw.Gui_Id, state: Ui_Component_Fixture_State) {
	switch state {
	case .Hover: gui.hot = id
	case .Active: gui.active = id
	case .Focused: gui.focused = id
	case .Editing:
		gui.focused = id
		gui.focus_edit_id = id
		gui.controller_explicit_activation = true
	case .Rest, .Disabled:
	}
}

app_ui_draw_component_fixture :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	window_w := f32(max(gui.input.window_width, 1))
	window_h := f32(max(gui.input.window_height, 1))
	card_w := min(max(window_w * 0.56, f32(320)), max(window_w - 48, 1))
	component_h := gui.style.row_height
	if ui.component_fixture == .Slider do component_h = uifw.gui_slider_height(gui)
	if ui.component_fixture == .Number || ui.component_fixture == .Integer {
		expanded := ui.component_fixture_state == .Active || ui.component_fixture_state == .Editing
		component_h = expanded ? max(gui.style.row_height + gui.style.small_line_height, f32(60)) : gui.style.row_height
	}
	content_h := gui.style.heading_line_height + gui.style.body_line_height + component_h + gui.style.spacing * 3 + gui.style.spacing_2
	card_h := min(max(content_h + gui.style.panel_padding * 2, f32(150)), max(window_h - 48, 1))
	card := uifw.Rect{(window_w - card_w) * 0.5, (window_h - card_h) * 0.5, card_w, card_h}
	uifw.gui_panel_begin(gui, card)
	uifw.gui_heading(gui, app_ui_component_fixture_name(ui.component_fixture))
	uifw.gui_label(gui, fmt.tprintf("Fixture state: %v", ui.component_fixture_state))
	uifw.gui_spacer(gui, gui.style.spacing_2)
	key := "component_fixture_target"
	id := uifw.gui_make_id(gui, key)
	app_ui_component_fixture_apply_state(gui, id, ui.component_fixture_state)
	enabled := ui.component_fixture_state != .Disabled

	switch ui.component_fixture {
	case .Button:
		_ = uifw.gui_button_at(gui, id, uifw.gui_next_rect(gui), "Run Simulation", enabled)
	case .Toggle:
		value := ui.component_fixture_value >= 0.5
		_ = uifw.gui_toggle(gui, "Enable trails", key, &value)
	case .Slider:
		value := ui.component_fixture_value
		_ = uifw.gui_slider_f32(gui, fmt.tprintf("Strength: %.2f", value), key, &value, 0, 1)
	case .Number:
		value := ui.component_fixture_value
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Interaction Radius: %.3f px", value), key, &value, 0.01, 0.001, 1000, enabled, .Logarithmic)
	case .Integer:
		value := u32(max(ui.component_fixture_value, 0))
		_ = uifw.gui_numeric_u32(gui, "Agent Count", key, &value, 1, 100_000_000, 100, enabled, unit = "agents")
	case .Selector:
		options := [?]string{"Linear", "Logarithmic", "Symmetric log"}
		index := min(max(int(ui.component_fixture_value), 0), len(options) - 1)
		_ = uifw.gui_selector(gui, fmt.tprintf("Mapping: %s", options[index]), key, &index, options[:])
	case .Text_Input:
		buffer: [64]u8
		copy(buffer[:], "Exact numeric value")
		length := len("Exact numeric value")
		_ = uifw.gui_text_input(gui, "Enter a value", key, buffer[:], &length)
	case .None:
	}

	uifw.gui_panel_end(gui)
}

app_ui_theme_preview_controls :: proc(gui: ^uifw.Gui_Context, bounds: uifw.Rect) {
	uifw.gui_layout_begin(gui, bounds, .Column, gui.style.spacing, gui.style.row_height)
	uifw.gui_heading(gui, "Buttons")
	_ = uifw.gui_button(gui, "Primary Button", "primary")
	app_ui_preview_button_state(gui, "Hover Button", "hover", .Hot)
	app_ui_preview_button_state(gui, "Active Button", "active", .Active)
	app_ui_preview_button_state(gui, "Focused Button", "focused", .Focused)
	uifw.gui_disabled_button(gui, "Disabled Button")

	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "Cards")
	card_height := max(gui.style.text_height * 2 + 28, f32(100))
	card := uifw.gui_next_rect(gui, height = card_height)
	_ = uifw.gui_card_button(gui, card, "Enabled Card", "enabled_card", "Subtitle and detail text", true)
	app_ui_preview_card_state(gui, "Hover Card", "hover_card", "Hot state", .Hot)
	app_ui_preview_card_state(gui, "Active Card", "active_card", "Pressed state", .Active)
	card = uifw.gui_next_rect(gui, height = card_height)
	_ = uifw.gui_card_button(gui, card, "Disabled Card", "disabled_card", "Unavailable", false)
	uifw.gui_layout_end(gui)
}

app_ui_theme_preview_inputs :: proc(gui: ^uifw.Gui_Context, bounds: uifw.Rect) {
	uifw.gui_layout_begin(gui, bounds, .Column, gui.style.spacing, gui.style.row_height)
	uifw.gui_heading(gui, "Inputs")
	toggle_on := true
	toggle_off := false
	_ = uifw.gui_toggle(gui, "Toggle: true", "toggle_on", &toggle_on)
	_ = uifw.gui_toggle(gui, "Toggle: false", "toggle_off", &toggle_off)
	app_ui_preview_button_state(gui, "Toggle: hover", "toggle_hover", .Hot)

	uifw.gui_spacer(gui, gui.style.spacing_2)
	value_low := f32(0.22)
	value_mid := f32(0.58)
	value_high := f32(0.86)
	_ = uifw.gui_slider_f32(gui, "Slider: 22%", "slider", &value_low, 0, 1)
	app_ui_preview_slider_state(gui, "Slider: hover", "slider_hover", &value_mid, .Hot)
	app_ui_preview_slider_state(gui, "Slider: active", "slider_active", &value_high, .Active)

	uifw.gui_spacer(gui, gui.style.spacing_2)
	number_value := f32(42)
	_ = uifw.gui_numeric_f32(gui, "Numeric Input: 42", "number", &number_value, 1, 0, 100)
	app_ui_preview_numeric_state(gui, "Numeric Input: hover", "number_hover", .Hot)
	app_ui_preview_numeric_state(gui, "Numeric Input: active", "number_active", .Active)

	uifw.gui_spacer(gui, gui.style.spacing_2)
	selector_options := [?]string{"Linear", "Nearest", "Lanczos"}
	selector_index := 1
	_ = uifw.gui_selector(gui, "Selector: Nearest", "selector", &selector_index, selector_options[:])
	open := true
	closed := false
	_ = uifw.gui_collapsible_begin(gui, "Collapsible: open", "collapsible_open", &open)
	_ = uifw.gui_collapsible_begin(gui, "Collapsible: closed", "collapsible_closed", &closed)
	uifw.gui_layout_end(gui)
}

app_ui_theme_preview_text_palette :: proc(gui: ^uifw.Gui_Context, bounds: uifw.Rect) {
	uifw.gui_layout_begin(gui, bounds, .Column, gui.style.spacing, gui.style.row_height)
	uifw.gui_heading(gui, "Text")
	uifw.gui_label(gui, "Label row")
	right_text := uifw.gui_next_rect(gui)
	uifw.gui_text_aligned(gui, right_text, "Left", gui.style.text_muted, .Left)
	uifw.gui_text_centered(gui, right_text, "Center", gui.style.text)
	uifw.gui_text_right(gui, right_text, "Right", gui.style.accent)
	uifw.gui_text_block(gui, "Wrapped text block shows the baseline rhythm, padding, and legibility when copy runs longer than a single row.", bounds.w - 4, gui.style.text)
	clip_rect := uifw.gui_next_rect(gui)
	uifw.gui_box(gui, clip_rect, {
		fill = gui.style.control,
		border = gui.style.panel_border,
		radius = gui.style.radius_control,
		border_width = gui.style.border_width,
	})
	uifw.gui_text_clipped(gui, uifw.gui_inset(clip_rect, 8), {clip_rect.x + 14, clip_rect.y + 6}, "Clipped text with a very long label that should stay inside its control", gui.style.text)

	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "Palette")
	app_ui_preview_swatch(gui, "Panel", gui.style.panel)
	app_ui_preview_swatch(gui, "Border", gui.style.panel_border)
	app_ui_preview_swatch(gui, "Control", gui.style.control)
	app_ui_preview_swatch(gui, "Hot", gui.style.control_hot)
	app_ui_preview_swatch(gui, "Active", gui.style.control_active)
	app_ui_preview_swatch(gui, "Accent", gui.style.accent)
	app_ui_preview_swatch(gui, "Text", gui.style.text)
	uifw.gui_layout_end(gui)
}

app_ui_theme_preview_media_layout :: proc(gui: ^uifw.Gui_Context, bounds: uifw.Rect) {
	uifw.gui_layout_begin(gui, bounds, .Column, gui.style.spacing, gui.style.row_height)
	uifw.gui_heading(gui, "Effects")
	effects := uifw.gui_next_rect(gui, height = 74)
	gradient := uifw.gui_inset_edges(effects, {left = 0, top = 2, right = effects.w * 0.52, bottom = 2})
	uifw.gui_box(gui, gradient, {
		fill = gui.style.accent,
		fill_to = uifw.gui_darken(gui.style.accent, 0.45),
		border = gui.style.panel_border,
		radius = gui.style.radius_control,
		border_width = gui.style.border_width,
		shadow_color = gui.style.shadow_color,
		shadow_offset = {0, 5},
		shadow_blur = 10,
		gradient = true,
	})
	uifw.gui_text_centered(gui, gradient, "Gradient", gui.style.text)
	ghost := uifw.gui_translate(uifw.gui_scale_from_center(gradient, 0.78), {effects.w * 0.56, 0})
	uifw.gui_box(gui, ghost, {
		fill = gui.style.danger,
		border = gui.style.panel_border,
		radius = gui.style.radius_control,
		border_width = gui.style.border_width,
		opacity = 0.62,
	})
	uifw.gui_text_centered(gui, ghost, "Opacity", gui.style.text)
	blend_row := uifw.gui_next_rect(gui, height = 42)
	blend_cells: [3]uifw.Rect
	uifw.gui_distribute_equal(blend_cells[:], blend_row, .Row, 8, .Start)
	blend_modes := [?]uifw.Gui_Blend_Mode{.Add, .Multiply, .Screen}
	blend_labels := [?]string{"Add", "Multiply", "Screen"}
	for cell, i in blend_cells {
		uifw.gui_box(gui, cell, {
			fill = i == 0 ? gui.style.accent : (i == 1 ? gui.style.danger : gui.style.text_muted),
			border = gui.style.panel_border,
			radius = gui.style.radius_control,
			border_width = gui.style.border_width,
			opacity = 0.72,
			blend = blend_modes[i],
		})
		uifw.gui_text_centered(gui, cell, blend_labels[i], gui.style.text)
	}

	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "Images")
	image_grid_bounds := uifw.gui_next_rect(gui, height = 188)
	image_grid := uifw.gui_grid_begin(gui, image_grid_bounds, 3, 8)
	app_ui_preview_image_sample(gui, uifw.gui_grid_next(&image_grid, 90), "Normal", {1, 1, 1, 1}, {0, 0, 1, 1}, {brightness = 1, contrast = 1}, .Alpha)
	app_ui_preview_image_sample(gui, uifw.gui_grid_next(&image_grid, 90), "Tint", gui.style.accent, {0, 0, 1, 1}, {brightness = 1.15, contrast = 1}, .Alpha)
	app_ui_preview_image_sample(gui, uifw.gui_grid_next(&image_grid, 90), "Crop", {1, 1, 1, 1}, {0, 0, 0.55, 0.55}, {brightness = 1, contrast = 1}, .Alpha)
	app_ui_preview_image_sample(gui, uifw.gui_grid_next(&image_grid, 90), "Bright", {1, 1, 1, 1}, {0, 0, 1, 1}, {brightness = 1.45, contrast = 1.05}, .Alpha)
	app_ui_preview_image_sample(gui, uifw.gui_grid_next(&image_grid, 90), "Gray", {1, 1, 1, 1}, {0, 0, 1, 1}, {brightness = 1, contrast = 1.1, grayscale = 1}, .Alpha)
	app_ui_preview_image_sample(gui, uifw.gui_grid_next(&image_grid, 90), "Blur", {1, 1, 1, 1}, {0, 0, 1, 1}, {brightness = 1, contrast = 1, blur = 0.014}, .Alpha)
	uifw.gui_spacer(gui, gui.style.spacing_2)
	filter_row := uifw.gui_next_rect(gui, height = 62)
	filter_cells: [3]uifw.Rect
	uifw.gui_distribute_equal(filter_cells[:], filter_row, .Row, 8, .Start)
	app_ui_preview_image_sample(gui, filter_cells[0], "Contrast", {1, 1, 1, 1}, {0, 0, 1, 1}, {brightness = 0.95, contrast = 1.8}, .Alpha)
	app_ui_preview_image_sample(gui, filter_cells[1], "Multiply", gui.style.accent, {0, 0, 1, 1}, {brightness = 1.2, contrast = 1.2}, .Multiply)
	app_ui_preview_image_sample(gui, filter_cells[2], "Screen", gui.style.danger, {0, 0, 1, 1}, {brightness = 1.05, contrast = 1}, .Screen)

	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "Geometry")
	geometry := uifw.gui_next_rect(gui, height = 70)
	media := uifw.gui_inset_edges(geometry, {left = 0, top = 2, right = geometry.w * 0.66, bottom = 2})
	uifw.gui_image_filtered(gui, media, uifw.Gui_Image_Id(uifw.UI_EXAMPLE_SCREENSHOT_TEXTURE_ID), {1, 1, 1, 1}, {brightness = 1.08, contrast = 1.2, grayscale = 0.25, blur = 0.0025})
	uifw.gui_text_centered(gui, media, "Image", gui.style.text)
	ellipse := uifw.Rect{geometry.x + geometry.w * 0.40, geometry.y + 8, geometry.w * 0.20, 46}
	uifw.gui_ellipse(gui, ellipse, uifw.gui_apply_opacity(gui.style.accent, 0.35))
	uifw.gui_ellipse_stroke(gui, ellipse, gui.style.accent, 2)
	line_start := uifw.Vec2{geometry.x + geometry.w * 0.68, geometry.y + 12}
	line_end := uifw.Vec2{geometry.x + geometry.w - 8, geometry.y + 58}
	uifw.gui_line(gui, line_start, line_end, gui.style.danger, 4)
	uifw.gui_line(gui, {line_start.x, line_end.y}, {line_end.x, line_start.y}, gui.style.text_muted, 2)
	rotated := uifw.Rect{geometry.x + geometry.w * 0.58, geometry.y + 28, 34, 22}
	uifw.gui_rotated_rect(gui, rotated, 0.45, uifw.gui_apply_opacity(gui.style.text, 0.42))

	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "Layout")
	breakpoint := uifw.gui_breakpoint(bounds.w)
	columns := uifw.gui_responsive_columns(bounds.w, 96, 4, 8)
	uifw.gui_label(gui, fmt.tprintf("Breakpoint: %v / columns: %d", breakpoint, columns))
	grid_bounds := uifw.gui_next_rect(gui, height = 124)
	grid := uifw.gui_grid_begin(gui, grid_bounds, columns, 8)
	for i in 0 ..< 6 {
		cell := uifw.gui_grid_next(&grid, 58)
		uifw.gui_box(gui, cell, {
			fill = gui.style.control,
			border = gui.style.panel_border,
			radius = gui.style.radius_control,
			border_width = gui.style.border_width,
		})
		uifw.gui_text_centered(gui, cell, fmt.tprintf("%d", i + 1), gui.style.text)
	}
	distributed_bounds := uifw.gui_next_rect(gui, height = 38)
	distributed: [3]uifw.Rect
	uifw.gui_distribute_equal(distributed[:], distributed_bounds, .Row, 8, .Space_Between)
	for rect, i in distributed {
		uifw.gui_box(gui, rect, {
			fill = uifw.gui_apply_opacity(gui.style.accent, 0.18 + f32(i) * 0.10),
			border = gui.style.accent,
			radius = gui.style.radius_control,
			border_width = gui.style.border_width,
		})
	}
	anchor_demo := uifw.gui_next_rect(gui, height = 70)
	uifw.gui_round_stroke(gui, anchor_demo, gui.style.radius_control, gui.style.panel_border, gui.style.border_width)
	anchored := uifw.gui_anchor_rect(anchor_demo, {left = 1, top = 0.5, right = 1, bottom = 0.5}, {left = 0, top = 0, right = 10, bottom = 0}, {96, 40})
	anchored.x -= anchored.w
	anchored.y -= anchored.h * 0.5
	uifw.gui_box(gui, anchored, {
		fill = gui.style.control_active,
		border = gui.style.accent,
		radius = gui.style.radius_control,
		border_width = gui.style.border_width,
	})
	uifw.gui_text_centered(gui, anchored, "Anchor", gui.style.text)
	uifw.gui_layout_end(gui)
}

app_ui_preview_image_sample :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, label: string, tint: uifw.Color, uv: uifw.Rect, filter: uifw.Gui_Image_Filter, blend: uifw.Gui_Blend_Mode) {
	uifw.gui_box(gui, rect, {
		fill = gui.style.control,
		border = gui.style.panel_border,
		radius = gui.style.radius_control,
		border_width = gui.style.border_width,
	})
	label_height := f32(28)
	image := uifw.gui_inset_edges(rect, {left = 5, top = 5, right = 5, bottom = label_height + 5})
	uifw.gui_image_uv_filtered_blend(gui, image, uifw.Gui_Image_Id(uifw.UI_EXAMPLE_SCREENSHOT_TEXTURE_ID), tint, uv, filter, blend)
	uifw.gui_text_centered(gui, {rect.x, rect.y + rect.h - label_height - 2, rect.w, label_height}, label, gui.style.text)
}

app_ui_theme_preview_advanced :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, bounds: uifw.Rect) {
	uifw.gui_layout_begin(gui, bounds, .Column, gui.style.spacing, gui.style.row_height)
	uifw.gui_heading(gui, "Advanced")

	_ = uifw.gui_color_picker_hsv(gui, "HSV Picker", "hsv_picker", &ui.preview_hsv)
	uifw.gui_spacer(gui, 4)
	_ = uifw.gui_area_slider_f32(gui, "2D Area", "area", &ui.preview_area, {0, 0}, {1, 1})

	uifw.gui_spacer(gui, 4)
	_ = uifw.gui_checkbox(gui, "Checkbox", "checkbox", &ui.preview_checkbox)
	_ = uifw.gui_switch(gui, "Switch", "switch", &ui.preview_switch)

	radio_options := [?]string{"Alpha", "Beta", "Gamma"}
	_ = uifw.gui_radio_group(gui, "Radio", "radio", &ui.preview_radio_index, radio_options[:])

	combo_options := [?]string{"Linear", "Nearest", "Lanczos", "Cubic", "Mitchell", "Catmull-Rom"}
	_ = uifw.gui_combobox(gui, "Searchable Combo", "combo", &ui.preview_combo_index, combo_options[:], ui.preview_combo_query[:])

	ui.preview_progress += gui.input.delta_time * 0.12
	if ui.preview_progress > 1 {
		ui.preview_progress -= 1
	}
	uifw.gui_circular_progress(gui, "Circular progress", ui.preview_progress)
	uifw.gui_layout_end(gui)
}

Preview_State :: enum {
	Normal,
	Hot,
	Active,
	Focused,
}

app_ui_preview_button_state :: proc(gui: ^uifw.Gui_Context, label, key: string, state: Preview_State) {
	id := uifw.gui_make_id(gui, key)
	app_ui_preview_apply_state(gui, id, state)
	rect := uifw.gui_next_rect(gui)
	_ = uifw.gui_button_at(gui, id, rect, label, true)
}

app_ui_preview_card_state :: proc(gui: ^uifw.Gui_Context, title, key, subtitle: string, state: Preview_State) {
	id := uifw.gui_make_id(gui, key)
	app_ui_preview_apply_state(gui, id, state)
	rect := uifw.gui_next_rect(gui, height = 96)
	_ = uifw.gui_card_button(gui, rect, title, key, subtitle, true)
}

app_ui_preview_slider_state :: proc(gui: ^uifw.Gui_Context, label, key: string, value: ^f32, state: Preview_State) {
	id := uifw.gui_make_id(gui, key)
	app_ui_preview_apply_state(gui, id, state)
	_ = uifw.gui_slider_f32(gui, label, key, value, 0, 1)
}

app_ui_preview_numeric_state :: proc(gui: ^uifw.Gui_Context, label, key: string, state: Preview_State) {
	id := uifw.gui_make_id(gui, key)
	app_ui_preview_apply_state(gui, id, state)
	value := f32(64)
	_ = uifw.gui_numeric_f32(gui, label, key, &value, 1, 0, 100)
}

app_ui_preview_apply_state :: proc(gui: ^uifw.Gui_Context, id: uifw.Gui_Id, state: Preview_State) {
	#partial switch state {
	case .Hot:
		gui.hot = id
	case .Active:
		gui.active = id
	case .Focused:
		gui.focused = id
	}
}

app_ui_preview_swatch :: proc(gui: ^uifw.Gui_Context, label: string, color: uifw.Color) {
	row := uifw.gui_next_rect(gui)
	size := min(row.h, 34)
	swatch := uifw.Rect{row.x, row.y + (row.h - size) * 0.5, size, size}
	uifw.gui_rect(gui, swatch, color)
	uifw.gui_stroke(gui, swatch, gui.style.panel_border)
	uifw.gui_text(gui, {row.x + size + 12, row.y + 6}, label, gui.style.text)
}

app_ui_options_section_rail_columns :: proc(gui: ^uifw.Gui_Context, width: f32) -> int {
	min_tab_w := max(gui.style.body_char_width * 11, gui.style.row_height * 2.2)
	return uifw.gui_responsive_columns(width, min_tab_w, len(OPTIONS_SECTION_LABELS), gui.style.spacing)
}

app_ui_options_section_rail_height :: proc(gui: ^uifw.Gui_Context, width: f32) -> f32 {
	columns := app_ui_options_section_rail_columns(gui, width)
	rows := (len(OPTIONS_SECTION_LABELS) + columns - 1) / columns
	return f32(rows) * gui.style.row_height + f32(max(rows - 1, 0)) * gui.style.spacing
}

app_ui_draw_options_section_rail :: proc(gui: ^uifw.Gui_Context, width: f32, current: ^int) -> bool {
	rail_h := app_ui_options_section_rail_height(gui, width)
	rail := uifw.gui_next_rect(gui, height = rail_h)
	columns := app_ui_options_section_rail_columns(gui, width)
	rows := (len(OPTIONS_SECTION_LABELS) + columns - 1) / columns
	changed := false
	uifw.gui_push_id(gui, "options_sections")
	for row in 0 ..< rows {
		row_start := row * columns
		row_count := min(columns, len(OPTIONS_SECTION_LABELS) - row_start)
		item_w := max((rail.w - gui.style.spacing * f32(max(row_count - 1, 0))) / f32(row_count), 1)
		y := rail.y + f32(row) * (gui.style.row_height + gui.style.spacing)
		for col in 0 ..< row_count {
			index := row_start + col
			rect := uifw.Rect{rail.x + f32(col) * (item_w + gui.style.spacing), y, item_w, gui.style.row_height}
			if app_ui_options_section_button(gui, rect, OPTIONS_SECTION_LABELS[index], OPTIONS_SECTION_KEYS[index], current^ == index) {
				current^ = index
				changed = true
			}
		}
	}
	uifw.gui_pop_id(gui)
	return changed
}

app_ui_options_section_button :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, label, key: string, selected: bool) -> bool {
	id := uifw.gui_make_id(gui, key)
	control := uifw.gui_control(gui, id, rect, true)

	fill := selected ? uifw.gui_lerp_color(gui.style.control, gui.style.accent, 0.32) : gui.style.control
	border := selected ? uifw.gui_apply_opacity(gui.style.accent, 0.84) : gui.style.panel_border
	stroke_w := selected ? max(gui.style.border_width * 2, 2) : gui.style.border_width
	if gui.active == id {
		fill = uifw.gui_lerp_color(gui.style.control_hot, gui.style.accent, 0.24)
		border = uifw.gui_apply_opacity(gui.style.accent, 0.82)
		stroke_w = max(gui.style.border_width * 2, 2)
	} else if control.hovered || control.focused {
		fill = selected ? uifw.gui_lerp_color(gui.style.control_hot, gui.style.accent, 0.22) : gui.style.control_hot
		border = control.focused || selected ? uifw.gui_apply_opacity(gui.style.accent, 0.78) : uifw.gui_apply_opacity(gui.style.text, 0.46)
		stroke_w = max(gui.style.border_width * 2, 2)
	}

	uifw.gui_round_rect(gui, rect, gui.style.radius_control, fill)
	uifw.gui_round_stroke(gui, rect, gui.style.radius_control, border, stroke_w)
	if control.focused {
		uifw.gui_focus_ring(gui, rect)
	}
	uifw.gui_text_centered(gui, uifw.gui_inset(rect, gui.style.spacing_1), label, selected ? gui.style.text : gui.style.text_muted)

	return control.activated || (control.hovered && gui.active == id && gui.input.mouse_released)
}

app_ui_draw_options_active_section :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, worker: ^Product_Context) {
	switch ui.options_section_index {
	case 0:
		app_ui_draw_options_display(ui, gui, worker)
	case 1:
		app_ui_draw_options_window(ui, gui, worker)
	case 2:
		app_ui_draw_options_interface(ui, gui, worker)
	case 3:
		app_ui_draw_options_input(ui, gui, worker)
	case 4:
		app_ui_draw_options_camera(ui, gui, worker)
	case:
		app_ui_draw_options_display(ui, gui, worker)
	}
}

app_ui_draw_options_display :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, worker: ^Product_Context) {
	uifw.gui_heading(gui, "Display")
	uifw.gui_push_id(gui, "display")
	if uifw.gui_toggle(gui, "FPS Limiter", "fps_limiter", &ui.settings.default_fps_limit_enabled) {
		app_ui_mark_settings_changed(ui, worker)
	}
	fps_limit := u32(max(ui.settings.default_fps_limit, 1))
	if uifw.gui_numeric_u32(gui, "FPS Limit", "fps_limit", &fps_limit, 1, 1200, 1, ui.settings.default_fps_limit_enabled) {
		ui.settings.default_fps_limit = i32(fps_limit)
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_numeric_f32(gui, fmt.tprintf("UI Scale: %.1f", ui.settings.ui_scale), "ui_scale", &ui.settings.ui_scale, 0.1, 0.5, 3.0) {
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_selector(gui, fmt.tprintf("Texture Filtering: %s", TEXTURE_FILTERING_OPTIONS[ui.texture_filtering_index]), "texture_filtering", &ui.texture_filtering_index, TEXTURE_FILTERING_OPTIONS[:]) {
		ui.settings.texture_filtering = TEXTURE_FILTERING_OPTIONS[ui.texture_filtering_index]
		app_ui_mark_settings_changed(ui, worker)
	}
	uifw.gui_pop_id(gui)
}

app_ui_draw_options_window :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, worker: ^Product_Context) {
	uifw.gui_heading(gui, "Window Defaults")
	uifw.gui_push_id(gui, "window")
	width := u32(max(ui.settings.window_width, 800))
	if uifw.gui_numeric_u32(gui, "Default Width", "width", &width, 800, 3840, 50) {
		ui.settings.window_width = i32(width)
		app_ui_mark_settings_changed(ui, worker)
	}
	height := u32(max(ui.settings.window_height, 600))
	if uifw.gui_numeric_u32(gui, "Default Height", "height", &height, 600, 2160, 50) {
		ui.settings.window_height = i32(height)
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_toggle(gui, "Start Maximized", "maximized", &ui.settings.window_maximized) {
		app_ui_mark_settings_changed(ui, worker)
	}
	uifw.gui_pop_id(gui)
}

app_ui_draw_options_interface :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, worker: ^Product_Context) {
	uifw.gui_heading(gui, "Interface")
	uifw.gui_push_id(gui, "ui_behavior")
	delay := u32(max(ui.settings.auto_hide_delay, 1000))
	if uifw.gui_numeric_u32(gui, "UI Hide Delay", "auto_hide_delay", &delay, 1000, 10000, 500, unit = "ms", grouped = false) {
		ui.settings.auto_hide_delay = i32(delay)
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_selector(gui, fmt.tprintf("Menu Position: %s", MENU_POSITION_OPTIONS[ui.menu_position_index]), "menu_position", &ui.menu_position_index, MENU_POSITION_OPTIONS[:]) {
		ui.settings.menu_position = MENU_POSITION_OPTIONS[ui.menu_position_index]
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_toggle(gui, "Remember Controller Focus", "remember_controller_focus", &ui.settings.remember_controller_focus) {
		app_ui_mark_settings_changed(ui, worker)
	}
	uifw.gui_pop_id(gui)
}

app_ui_draw_options_camera :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, worker: ^Product_Context) {
	uifw.gui_heading(gui, "Camera")
	uifw.gui_push_id(gui, "camera")
	count: c.int
	ids := sdl.GetCameras(&count)
	defer if ids != nil {sdl.free(ids)}
	device_names: [16]string
	device_count := min(max(int(count), 0), len(device_names))
	for i in 0..<device_count {
		name := sdl.GetCameraName(ids[i])
		device_names[i] = name == nil ? "Unnamed camera" : string(name)
	}
	if device_count > 0 {
		if ui.camera_device_index >= device_count || (ui.camera_device_index == 0 && len(ui.settings.preferred_camera) > 0) {
			ui.camera_device_index = 0
			for name, i in device_names[:device_count] {if name == ui.settings.preferred_camera {ui.camera_device_index = i; break}}
		}
		if uifw.gui_selector(gui, fmt.tprintf("Preferred Camera: %s", device_names[ui.camera_device_index]), "preferred_device", &ui.camera_device_index, device_names[:device_count]) {
			ui.settings.preferred_camera = device_names[ui.camera_device_index]
			if ui.camera_test != nil {sdl.CloseCamera(ui.camera_test); ui.camera_test = nil}
			app_ui_mark_settings_changed(ui, worker)
		}
		if ui.camera_test == nil {
			if uifw.gui_button(gui, "Test Camera", "test_camera") {
				ui.camera_test = sdl.OpenCamera(ids[ui.camera_device_index], nil)
				ui.camera_test_frames = 0
				write_fixed_string(ui.camera_test_status[:], ui.camera_test == nil ? "Could not open camera" : "Waiting for camera permission and first frame…")
			}
		} else {
			timestamp: u64
			frame := sdl.AcquireCameraFrame(ui.camera_test, &timestamp)
			if frame != nil {
				ui.camera_test_frames += 1
				sdl.ReleaseCameraFrame(ui.camera_test, frame)
				write_fixed_string(ui.camera_test_status[:], fmt.tprintf("Camera working — %d frames received", ui.camera_test_frames))
			}
			if uifw.gui_button(gui, "Stop Test", "stop_camera_test") {sdl.CloseCamera(ui.camera_test); ui.camera_test = nil}
		}
		uifw.gui_label(gui, fixed_string(ui.camera_test_status[:]))
	} else {
		uifw.gui_label(gui, "No cameras detected. Connect a camera and reopen Options.")
	}
	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "View Controls")
	if uifw.gui_numeric_f32(gui, fmt.tprintf("Keyboard / Wheel Sensitivity: %.1f", ui.settings.default_camera_sensitivity), "sensitivity", &ui.settings.default_camera_sensitivity, 0.1, 0.1, 5.0) {
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_numeric_f32(gui, fmt.tprintf("Controller Sensitivity: %.1f", ui.settings.controller_camera_sensitivity), "controller_sensitivity", &ui.settings.controller_camera_sensitivity, 0.1, 0.1, 5.0) {
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_toggle(gui, "Invert Controller Y", "controller_invert_y", &ui.settings.controller_camera_invert_y) {
		app_ui_mark_settings_changed(ui, worker)
	}
	uifw.gui_pop_id(gui)
}

app_ui_keyboard_action_label :: proc(action: Keyboard_Shortcut_Action) -> string {
	switch action {
	case .Pause: return "Pause"
	case .Toggle_Ui: return "Toggle UI"
	case .Help: return "Help"
	}
	return "Shortcut"
}

app_ui_assign_keyboard_binding :: proc(ui: ^App_Ui_State, action: Keyboard_Shortcut_Action, key: Keyboard_Shortcut_Key, worker: ^Product_Context) {
	if !settings_keyboard_binding_allowed(action, key) {
		write_fixed_string(ui.keyboard_binding_notice[:], "Space is reserved for Pause + Control Deck")
		return
	}
	displaced, swapped := settings_assign_keyboard_binding(&ui.settings, action, key)
	if swapped {
		write_fixed_string(ui.keyboard_binding_notice[:], fmt.tprintf("Reassigned %s to avoid a duplicate key", app_ui_keyboard_action_label(displaced)))
	} else {
		write_fixed_string(ui.keyboard_binding_notice[:], fmt.tprintf("%s now uses %s", app_ui_keyboard_action_label(action), keyboard_shortcut_key_name(key)))
	}
	ui.keyboard_shortcut_profile_index = option_index(ui.settings.keyboard_shortcut_profile, KEYBOARD_SHORTCUT_PROFILE_OPTIONS[:], 2)
	app_ui_mark_settings_changed(ui, worker)
}

app_ui_draw_options_input :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, worker: ^Product_Context) {
	uifw.gui_heading(gui, "Input Bindings and Navigation")
	uifw.gui_push_id(gui, "input")
	if uifw.gui_selector(gui, fmt.tprintf("Keyboard Shortcuts: %s", KEYBOARD_SHORTCUT_PROFILE_OPTIONS[ui.keyboard_shortcut_profile_index]), "keyboard_shortcut_profile", &ui.keyboard_shortcut_profile_index, KEYBOARD_SHORTCUT_PROFILE_OPTIONS[:]) {
		settings_apply_keyboard_profile(&ui.settings, KEYBOARD_SHORTCUT_PROFILE_OPTIONS[ui.keyboard_shortcut_profile_index])
		write_fixed_string(ui.keyboard_binding_notice[:], "Profile applied")
		app_ui_mark_settings_changed(ui, worker)
	}
	pause_binding_index := int(ui.settings.keyboard_pause_binding)
	if uifw.gui_selector(gui, fmt.tprintf("Pause: %s", keyboard_shortcut_key_name(ui.settings.keyboard_pause_binding)), "keyboard_pause_binding", &pause_binding_index, KEYBOARD_SHORTCUT_KEY_OPTIONS[:]) {
		app_ui_assign_keyboard_binding(ui, .Pause, Keyboard_Shortcut_Key(pause_binding_index), worker)
	}
	toggle_binding_index := int(ui.settings.keyboard_toggle_ui_binding)
	if uifw.gui_selector(gui, fmt.tprintf("Toggle UI: %s", keyboard_shortcut_key_name(ui.settings.keyboard_toggle_ui_binding)), "keyboard_toggle_ui_binding", &toggle_binding_index, KEYBOARD_SHORTCUT_KEY_OPTIONS[:]) {
		app_ui_assign_keyboard_binding(ui, .Toggle_Ui, Keyboard_Shortcut_Key(toggle_binding_index), worker)
	}
	help_binding_index := int(ui.settings.keyboard_help_binding)
	if uifw.gui_selector(gui, fmt.tprintf("Help: %s", keyboard_shortcut_key_name(ui.settings.keyboard_help_binding)), "keyboard_help_binding", &help_binding_index, KEYBOARD_SHORTCUT_KEY_OPTIONS[:]) {
		app_ui_assign_keyboard_binding(ui, .Help, Keyboard_Shortcut_Key(help_binding_index), worker)
	}
	binding_notice := fixed_string(ui.keyboard_binding_notice[:])
	if len(binding_notice) == 0 {binding_notice = "Duplicate keys swap automatically. Space is reserved for Pause + Control Deck."}
	uifw.gui_label(gui, binding_notice)
	if uifw.gui_numeric_f32(gui, fmt.tprintf("Stick Deadzone: %.2f", ui.settings.controller_deadzone), "controller_deadzone", &ui.settings.controller_deadzone, 0.01, 0.05, 0.60) {
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_numeric_f32(gui, fmt.tprintf("Virtual Cursor Speed: %.2f", ui.settings.controller_cursor_speed), "controller_cursor_speed", &ui.settings.controller_cursor_speed, 0.05, 0.20, 2.0) {
		app_ui_mark_settings_changed(ui, worker)
	}
	repeat_delay := u32(max(ui.settings.navigation_repeat_delay_ms, 150))
	if uifw.gui_numeric_u32(gui, "Repeat Delay", "navigation_repeat_delay", &repeat_delay, 150, 1000, 25, unit = "ms", grouped = false) {
		ui.settings.navigation_repeat_delay_ms = i32(repeat_delay)
		app_ui_mark_settings_changed(ui, worker)
	}
	repeat_interval := u32(max(ui.settings.navigation_repeat_interval_ms, 30))
	if uifw.gui_numeric_u32(gui, "Repeat Interval", "navigation_repeat_interval", &repeat_interval, 30, 300, 10, unit = "ms", grouped = false) {
		ui.settings.navigation_repeat_interval_ms = i32(repeat_interval)
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_selector(gui, fmt.tprintf("Accept / Back Layout: %s", CONTROLLER_FACE_LAYOUT_OPTIONS[ui.controller_face_layout_index]), "controller_face_layout", &ui.controller_face_layout_index, CONTROLLER_FACE_LAYOUT_OPTIONS[:]) {
		ui.settings.controller_face_layout = CONTROLLER_FACE_LAYOUT_OPTIONS[ui.controller_face_layout_index]
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_selector(gui, fmt.tprintf("Menu Buttons: %s", CONTROLLER_MENU_LAYOUT_OPTIONS[ui.controller_menu_layout_index]), "controller_menu_layout", &ui.controller_menu_layout_index, CONTROLLER_MENU_LAYOUT_OPTIONS[:]) {
		ui.settings.controller_menu_layout = CONTROLLER_MENU_LAYOUT_OPTIONS[ui.controller_menu_layout_index]
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_selector(gui, fmt.tprintf("Shoulders: %s", CONTROLLER_SHOULDER_LAYOUT_OPTIONS[ui.controller_shoulder_layout_index]), "controller_shoulder_layout", &ui.controller_shoulder_layout_index, CONTROLLER_SHOULDER_LAYOUT_OPTIONS[:]) {
		ui.settings.controller_shoulder_layout = CONTROLLER_SHOULDER_LAYOUT_OPTIONS[ui.controller_shoulder_layout_index]
		app_ui_mark_settings_changed(ui, worker)
	}
	uifw.gui_pop_id(gui)
}

app_ui_options_content_height :: proc(gui: ^uifw.Gui_Context, section_index: int) -> f32 {
	height := f32(0)
	item_count := 0
	control_count := 4
	switch section_index {
	case 0:
		control_count = 4
	case 1:
		control_count = 3
	case 2:
		control_count = 5
	case 3:
		control_count = 12
	case 4:
		control_count = 3
	case:
		control_count = 4
	}
	app_ui_options_measure_section(&height, &item_count, gui, control_count)

	return height + f32(max(item_count - 1, 0)) * gui.style.spacing
}

app_ui_options_measure_section :: proc(height: ^f32, item_count: ^int, gui: ^uifw.Gui_Context, control_count: int) {
	app_ui_options_measure_row(height, item_count, gui.style.heading_line_height)
	for _ in 0 ..< control_count {
		app_ui_options_measure_row(height, item_count, gui.style.row_height)
	}
}

app_ui_options_measure_row :: proc(height: ^f32, item_count: ^int, row_height: f32) {
	height^ += row_height
	item_count^ += 1
}

app_ui_options_footer_height :: proc(gui: ^uifw.Gui_Context, width: f32) -> f32 {
	action_rows := app_ui_options_footer_action_rows(gui, width)
	return gui.style.spacing_1 +
	       gui.style.body_line_height +
	       gui.style.spacing +
	       f32(action_rows) * gui.style.row_height +
	       f32(max(action_rows - 1, 0)) * gui.style.spacing
}

app_ui_options_footer_action_rows :: proc(gui: ^uifw.Gui_Context, width: f32) -> int {
	labels := [?]string{"Back to Menu", "Reset to Defaults", "Save"}
	row_count := 1
	row_w := f32(0)
	available := max(width, gui.style.row_height)
	for label in labels {
		w := min(uifw.gui_button_content_width(gui, label), available)
		if row_w > 0 && row_w + gui.style.spacing + w > available {
			row_count += 1
			row_w = w
		} else if row_w > 0 {
			row_w += gui.style.spacing + w
		} else {
			row_w = w
		}
	}
	return row_count
}

app_ui_draw_options_footer :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, bounds: uifw.Rect, worker: ^Product_Context) {
	uifw.gui_rect(gui, {bounds.x, bounds.y, bounds.w, gui.style.border_width}, {1, 1, 1, 0.16})

	status := ui.settings_dirty ? "Unsaved changes. Save to keep after restart." : "No unsaved changes."
	status_color := ui.settings_dirty ? gui.style.text : gui.style.text_muted
	status_rect := uifw.Rect{bounds.x, bounds.y + gui.style.spacing_1, bounds.w, gui.style.body_line_height}
	uifw.gui_text_clipped(gui, status_rect, {status_rect.x + gui.style.spacing_1, status_rect.y + max((status_rect.h - gui.style.body_text_height) * 0.5, 0)}, status, status_color)

	cursor := uifw.Vec2{bounds.x, status_rect.y + status_rect.h + gui.style.spacing}
	row_right := bounds.x + bounds.w
	if app_ui_options_footer_button(gui, "Back to Menu", "back", &cursor, bounds.x, row_right, gui.style.row_height, gui.style.spacing, true) {
		app_ui_navigate(ui, .Main_Menu)
	}
	if app_ui_options_footer_button(gui, "Reset to Defaults", "reset_defaults", &cursor, bounds.x, row_right, gui.style.row_height, gui.style.spacing, true) {
		app_ui_reset_settings_to_defaults(ui, worker)
	}
	if app_ui_options_footer_button(gui, "Save", "save", &cursor, bounds.x, row_right, gui.style.row_height, gui.style.spacing, ui.settings_dirty) {
		app_ui_save_settings(ui, worker)
	}
}

app_ui_options_footer_button :: proc(gui: ^uifw.Gui_Context, label, key: string, cursor: ^uifw.Vec2, row_left, row_right, row_height, gap: f32, enabled: bool) -> bool {
	available := max(row_right - row_left, 1)
	w := min(uifw.gui_button_content_width(gui, label), available)
	if cursor.x > row_left && cursor.x + w > row_right {
		cursor.x = row_left
		cursor.y += row_height + gap
	}
	rect := uifw.Rect{cursor.x, cursor.y, w, row_height}
	cursor.x += w + gap
	return uifw.gui_button_at(gui, uifw.gui_make_id(gui, key), rect, label, enabled)
}

centered_panel_styled :: proc(width, height: f32, window_width, window_height: i32, style: ^uifw.Gui_Style) -> uifw.Rect {
	margin := max(style.margin, f32(16))
	w := min(width, max(f32(window_width) - margin * 2, margin))
	h := min(height, max(f32(window_height) - margin * 2, margin))
	x := (f32(window_width) - w) * 0.5
	y := (f32(window_height) - h) * 0.5
	if x < margin do x = margin
	if y < margin do y = margin
	return {x, y, w, h}
}

centered_panel :: proc(width, height: f32, window_width, window_height: i32) -> uifw.Rect {
	margin := f32(16)
	w := min(width, max(f32(window_width) - margin * 2, margin))
	h := min(height, max(f32(window_height) - margin * 2, margin))
	x := (f32(window_width) - w) * 0.5
	y := (f32(window_height) - h) * 0.5
	if x < 16 do x = 16
	if y < 16 do y = 16
	return {x, y, w, h}
}

option_index :: proc(value: string, options: []string, fallback: int) -> int {
	for option, i in options {
		if option == value {
			return i
		}
	}
	return fallback
}
