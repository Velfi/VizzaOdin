package game

CANVAS_TOOL_DIRECTIONS := [?]string{"Left", "Up", "Right", "Down"}

shared_canvas_tool_selector :: proc(ctx: ^uifw.Gui_Context, set: ^Canvas_Tool_Set, state: ^Canvas_Tool_State, title: string = "Brush Modes") {
	count := 0
	for tool in set.tools {if tool.valid {count += 1}}
	if count <= 1 {return}
	uifw.gui_heading(ctx, title)
	for tool, index in set.tools {
		if !tool.valid {continue}
		prefix := state.selected_slot == index ? "•" : " "
		label := fmt.tprintf("%s %s · %s", prefix, CANVAS_TOOL_DIRECTIONS[index], tool.name)
		if uifw.gui_button(ctx, label, fmt.tprintf("brush_mode_%d", index)) {
			state.previous_slot = state.selected_slot
			state.selected_slot = index
			state.changed = true
			uifw.gui_notice(ctx, fmt.tprintf("%s selected — Primary: %s · Secondary: %s", tool.name, tool.primary_label, tool.secondary_label), 1.6)
		}
	}
	selected := canvas_tool_selected(set, state)
	if selected.valid {uifw.gui_label(ctx, fmt.tprintf("Primary: %s   Secondary: %s", selected.primary_label, selected.secondary_label))}
}

import uifw "zelda_engine:ui"

import "core:fmt"

Cursor_Config_Options :: struct {
	size_label: string,
	strength_label: string,
	size_key: string,
	strength_key: string,
	size_min: f32,
	size_max: f32,
	size_step: f32,
	strength_min: f32,
	strength_max: f32,
	strength_step: f32,
	show_strength: bool,
	use_two_axis_pad: bool,
}

Controls_Panel_Options :: struct {
	heading: string,
	mouse_interaction_text: string,
	cursor_settings_title: string,
	cursor: Cursor_Config_Options,
}

Image_Selector_Result :: struct {
	fit_changed: bool,
	load_requested: bool,
	browse_requested: bool,
	clear_requested: bool,
}

Image_Selector_Options :: struct {
	fit_label: string,
	fit_key: string,
	load_label: string,
	load_key: string,
	browse_label: string,
	browse_key: string,
	clear_label: string,
	clear_key: string,
	selected_label: string,
	empty_label: string,
	selected_path: string,
	show_fit_mode: bool,
	show_load_button: bool,
	show_browse_button: bool,
	show_clear_button: bool,
	show_selected_path: bool,
}

Webcam_Control_Action :: enum {
	None,
	Start,
	Stop,
}

Webcam_Controls_Result :: struct {
	action: Webcam_Control_Action,
}

Webcam_Controls_Options :: struct {
	start_label: string,
	stop_label: string,
	start_key: string,
	stop_key: string,
	active: bool,
	device_count: int,
}

Post_Processing_Menu_Options :: struct {
	heading: string,
	enabled_label: string,
	enabled_key: string,
	radius_label: string,
	radius_key: string,
	sigma_label: string,
	sigma_key: string,
	radius_min: f32,
	radius_max: f32,
	radius_step: f32,
	sigma_min: f32,
	sigma_max: f32,
	sigma_step: f32,
}

shared_default_cursor_config_options :: proc() -> Cursor_Config_Options {
	return {
		size_label = "Cursor Size",
		strength_label = "Cursor Strength",
		size_key = "cursor_size",
		strength_key = "cursor_strength",
		size_min = 0.01,
		size_max = 1.0,
		size_step = 0.01,
		strength_min = 0.0,
		strength_max = 1.0,
		strength_step = 0.05,
		show_strength = true,
		use_two_axis_pad = true,
	}
}

shared_default_image_selector_options :: proc() -> Image_Selector_Options {
	return {
		fit_label = "Image Fit",
		fit_key = "image_fit",
		load_label = "Load Image",
		load_key = "load_image",
		browse_label = "Browse Image",
		browse_key = "browse_image",
		clear_label = "Clear Selection",
		clear_key = "clear_image",
		selected_label = "Selected Image",
		empty_label = "No image selected",
		show_fit_mode = true,
		show_load_button = true,
		show_browse_button = true,
		show_clear_button = true,
		show_selected_path = true,
	}
}

shared_default_webcam_controls_options :: proc() -> Webcam_Controls_Options {
	return {
		start_label = "Start Webcam",
		stop_label = "Stop Webcam",
		start_key = "start_webcam",
		stop_key = "stop_webcam",
		active = false,
		device_count = 0,
	}
}

shared_default_post_processing_menu_options :: proc() -> Post_Processing_Menu_Options {
	return {
		heading = "Post Processing",
		enabled_label = "Blur Filter",
		enabled_key = "blur_filter",
		radius_label = "Blur Radius",
		radius_key = "blur_radius",
		sigma_label = "Blur Sigma",
		sigma_key = "blur_sigma",
		radius_min = 0.0,
		radius_max = 50.0,
		radius_step = 0.5,
		sigma_min = 0.1,
		sigma_max = 10.0,
		sigma_step = 0.1,
	}
}

shared_cursor_config :: proc(ctx: ^uifw.Gui_Context, size: ^f32, strength: ^f32, options: Cursor_Config_Options) -> bool {
	changed := false
	if options.show_strength && strength != nil && options.use_two_axis_pad {
		return shared_two_axis_pad_f32(
			ctx,
			"Brush Shape",
			"cursor_shape",
			options.size_label,
			options.strength_label,
			size,
			strength,
			options.size_min,
			options.size_max,
			options.strength_min,
			options.strength_max,
		)
	}
	if uifw.gui_slider_f32(ctx, fmt.tprintf("%s: %.2f", options.size_label, size^), options.size_key, size, options.size_min, options.size_max) {
		changed = true
	}
	if options.show_strength && strength != nil {
		if uifw.gui_slider_f32(ctx, fmt.tprintf("%s: %.2f", options.strength_label, strength^), options.strength_key, strength, options.strength_min, options.strength_max) {
			changed = true
		}
	}
	return changed
}

shared_controls_panel :: proc(ctx: ^uifw.Gui_Context, options: Controls_Panel_Options, cursor_size: ^f32, cursor_strength: ^f32) -> bool {
	heading := len(options.heading) > 0 ? options.heading : "Controls"
	uifw.gui_heading(ctx, heading)
	if len(options.mouse_interaction_text) > 0 {
		uifw.gui_label(ctx, options.mouse_interaction_text)
	}
	if len(options.cursor_settings_title) > 0 {
		uifw.gui_label(ctx, options.cursor_settings_title)
	}
	slider_h := uifw.gui_slider_height(ctx)
	controls_h := slider_h * (options.cursor.show_strength ? f32(2) : f32(1)) + ctx.style.spacing * (options.cursor.show_strength ? f32(1) : f32(0))
	if options.cursor.show_strength && options.cursor.use_two_axis_pad {
		controls_h = shared_two_axis_pad_height(ctx)
	}
	card_h := controls_h + ctx.style.spacing_2 * 2
	card := uifw.gui_next_rect(ctx, height = card_h)
	uifw.gui_round_rect(ctx, card, 6, {1, 1, 1, 0.05})
	uifw.gui_round_stroke(ctx, card, 6, {1, 1, 1, 0.10}, ctx.style.border_width)
	uifw.gui_layout_begin(ctx, uifw.gui_inset(card, ctx.style.spacing_2), .Column, ctx.style.spacing, ctx.style.row_height)
	changed := shared_cursor_config(ctx, cursor_size, cursor_strength, options.cursor)
	uifw.gui_layout_end(ctx)
	return changed
}

shared_two_axis_pad_height :: proc(ctx: ^uifw.Gui_Context) -> f32 {
	return max(ctx.style.row_height * 3.8, f32(172))
}

// Explanations keep the real control name in the UI while translating its
// effect into one short, experiment-friendly sentence on hover or focus.
shared_control_explanation :: proc(ctx: ^uifw.Gui_Context, key, explanation: string) {
	uifw.gui_tooltip_for_id(ctx, uifw.gui_make_id(ctx, key), explanation)
}

shared_range_explanation :: proc(ctx: ^uifw.Gui_Context, key, explanation: string) {
	uifw.gui_tooltip_for_id(ctx, uifw.gui_make_id(ctx, fmt.tprintf("%s_lower", key)), explanation)
	uifw.gui_tooltip_for_id(ctx, uifw.gui_make_id(ctx, fmt.tprintf("%s_upper", key)), explanation)
}

shared_two_axis_pad_f32 :: proc(
	ctx: ^uifw.Gui_Context,
	title, key, x_label, y_label: string,
	x, y: ^f32,
	x_min, x_max, y_min, y_max: f32,
) -> bool {
	bounds := uifw.gui_next_rect(ctx, height = shared_two_axis_pad_height(ctx))
	id := uifw.gui_make_id(ctx, key)
	title_h := ctx.style.body_line_height
	value_h := ctx.style.small_line_height
	pad := uifw.Rect{
		bounds.x + ctx.style.spacing_2,
		bounds.y + title_h + ctx.style.spacing_1,
		max(bounds.w - ctx.style.spacing_2 * 2, 1),
		max(bounds.h - title_h - value_h - ctx.style.spacing_2 * 2, 1),
	}
	current := uifw.Vec2{x^, y^}
	x_range := max(x_max - x_min, f32(0.000001))
	y_range := max(y_max - y_min, f32(0.000001))
	tx := uifw.gui_clamp01((current.x - x_min) / x_range)
	ty := uifw.gui_clamp01((current.y - y_min) / y_range)
	handle := uifw.Vec2{pad.x + pad.w * tx, pad.y + pad.h * (1 - ty)}
	changed := false
	if uifw.gui_drag_handle_region(ctx, id, pad, handle, 14) {
		fine := uifw.gui_pointer_fine_adjust_scale(ctx, id)
		if fine < 1 {
			current.x += ctx.mouse_delta.x / max(pad.w, 1) * x_range * fine
			current.y -= ctx.mouse_delta.y / max(pad.h, 1) * y_range * fine
		} else {
			current.x = x_min + x_range * uifw.gui_clamp01((ctx.input.mouse_pos.x - pad.x) / max(pad.w, 1))
			current.y = y_min + y_range * (1 - uifw.gui_clamp01((ctx.input.mouse_pos.y - pad.y) / max(pad.h, 1)))
		}
		changed = true
	}
	_ = uifw.gui_update_focus_edit(ctx, id, ctx.focused == id)
	uifw.gui_controller_edit_vec2(ctx, id, &current)
	nav_x, nav_y := uifw.gui_focused_nav_pressed(ctx, id)
	if nav_x != 0 || nav_y != 0 {
		adjust_scale := uifw.gui_fine_adjust_scale(ctx)
		current.x += nav_x * x_range * 0.025 * adjust_scale
		current.y -= nav_y * y_range * 0.025 * adjust_scale
		changed = true
	}
	current.x = min(max(current.x, x_min), x_max)
	current.y = min(max(current.y, y_min), y_max)
	if current.x != x^ || current.y != y^ {
		x^ = current.x
		y^ = current.y
		changed = true
	}

	uifw.gui_text_clipped(ctx, {bounds.x, bounds.y, bounds.w, title_h}, {bounds.x + 2, bounds.y}, title, ctx.style.text)
	uifw.gui_round_rect(ctx, pad, ctx.style.radius_control, {1, 1, 1, 0.055})
	uifw.gui_round_stroke(ctx, pad, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)
	grid := uifw.gui_apply_opacity(ctx.style.text_muted, 0.20)
	for i in 1 ..< 4 {
		t := f32(i) / 4
		uifw.gui_line(ctx, {pad.x + pad.w * t, pad.y}, {pad.x + pad.w * t, pad.y + pad.h}, grid, 1)
		uifw.gui_line(ctx, {pad.x, pad.y + pad.h * t}, {pad.x + pad.w, pad.y + pad.h * t}, grid, 1)
	}
	tx = uifw.gui_clamp01((x^ - x_min) / x_range)
	ty = uifw.gui_clamp01((y^ - y_min) / y_range)
	handle = {pad.x + pad.w * tx, pad.y + pad.h * (1 - ty)}
	uifw.gui_line(ctx, {pad.x, handle.y}, {pad.x + pad.w, handle.y}, uifw.gui_apply_opacity(ctx.style.accent, 0.22), 1)
	uifw.gui_line(ctx, {handle.x, pad.y}, {handle.x, pad.y + pad.h}, uifw.gui_apply_opacity(ctx.style.accent, 0.22), 1)
	handle_radius := max(ctx.style.row_height * 0.17, f32(9))
	handle_bounds := uifw.Rect{handle.x - handle_radius, handle.y - handle_radius, handle_radius * 2, handle_radius * 2}
	uifw.gui_ellipse(ctx, handle_bounds, ctx.style.accent)
	uifw.gui_ellipse_stroke(ctx, handle_bounds, ctx.style.text, max(ctx.style.border_width * 1.5, f32(2)))
	uifw.gui_focus_or_edit_ring(ctx, id, pad)
	values := fmt.tprintf("%s %.2f    %s %.2f", x_label, x^, y_label, y^)
	uifw.gui_text_clipped(ctx, {bounds.x, pad.y + pad.h + ctx.style.spacing_1, bounds.w, value_h}, {bounds.x + 2, pad.y + pad.h + ctx.style.spacing_1}, values, ctx.style.text_muted)
	return changed
}

shared_range_slider_f32 :: proc(
	ctx: ^uifw.Gui_Context,
	title, key: string,
	lower, upper: ^f32,
	min_value, max_value: f32,
) -> bool {
	bounds := uifw.gui_next_rect(ctx, height = uifw.gui_slider_height(ctx))
	label_h := ctx.style.body_line_height
	handle_radius := max(ctx.style.control_padding, f32(8))
	track_inset := max(handle_radius, ctx.style.spacing_2)
	track_h := max(ctx.style.border_width * 3, f32(6))
	track := uifw.Rect{bounds.x + track_inset, bounds.y + label_h + ctx.style.spacing_2, max(bounds.w - track_inset * 2, 1), track_h}
	range := max(max_value - min_value, f32(0.000001))
	lower^ = min(max(lower^, min_value), max_value)
	upper^ = min(max(upper^, min_value), max_value)
	if lower^ > upper^ {lower^, upper^ = upper^, lower^}
	low_t := uifw.gui_clamp01((lower^ - min_value) / range)
	high_t := uifw.gui_clamp01((upper^ - min_value) / range)
	low_center := uifw.Vec2{track.x + track.w * low_t, track.y + track.h * 0.5}
	high_center := uifw.Vec2{track.x + track.w * high_t, track.y + track.h * 0.5}
	low_id := uifw.gui_make_id(ctx, fmt.tprintf("%s_lower", key))
	high_id := uifw.gui_make_id(ctx, fmt.tprintf("%s_upper", key))
	hit_size := max(ctx.style.row_height * 0.55, f32(26))
	low_hit := uifw.Rect{low_center.x - hit_size * 0.5, low_center.y - hit_size * 0.5, hit_size, hit_size}
	high_hit := uifw.Rect{high_center.x - hit_size * 0.5, high_center.y - hit_size * 0.5, hit_size, hit_size}
	_ = uifw.gui_control(ctx, low_id, low_hit, true)
	_ = uifw.gui_control(ctx, high_id, high_hit, true)
	changed := false
	track_hit := uifw.Rect{track.x, bounds.y + label_h, track.w, max(bounds.h - label_h, 1)}
	if ctx.input.mouse_pressed && uifw.gui_mouse_contains(ctx, track_hit) {
		low_delta := ctx.input.mouse_pos.x - low_center.x
		high_delta := ctx.input.mouse_pos.x - high_center.x
		selected_id := low_delta * low_delta <= high_delta * high_delta ? low_id : high_id
		ctx.active = selected_id
		ctx.focused = selected_id
	}
	if ctx.active == low_id && ctx.input.mouse_down {
		fine := uifw.gui_pointer_fine_adjust_scale(ctx, low_id)
		if fine < 1 {
			lower^ = min(upper^, max(lower^ + ctx.mouse_delta.x / max(track.w, 1) * range * fine, min_value))
		} else {
			lower^ = min(upper^, min_value + range * uifw.gui_clamp01((ctx.input.mouse_pos.x - track.x) / max(track.w, 1)))
		}
		changed = true
	}
	if ctx.active == high_id && ctx.input.mouse_down {
		fine := uifw.gui_pointer_fine_adjust_scale(ctx, high_id)
		if fine < 1 {
			upper^ = max(lower^, min(upper^ + ctx.mouse_delta.x / max(track.w, 1) * range * fine, max_value))
		} else {
			upper^ = max(lower^, min_value + range * uifw.gui_clamp01((ctx.input.mouse_pos.x - track.x) / max(track.w, 1)))
		}
		changed = true
	}
	_ = uifw.gui_update_focus_edit(ctx, low_id, ctx.focused == low_id)
	uifw.gui_controller_edit_f32(ctx, low_id, lower)
	_ = uifw.gui_update_focus_edit(ctx, high_id, ctx.focused == high_id)
	uifw.gui_controller_edit_f32(ctx, high_id, upper)
	low_x, low_y := uifw.gui_focused_nav_pressed(ctx, low_id)
	high_x, high_y := uifw.gui_focused_nav_pressed(ctx, high_id)
	step := range * 0.025 * uifw.gui_fine_adjust_scale(ctx)
	if low_x != 0 || low_y != 0 {
		lower^ = min(max(lower^ + (low_x - low_y) * step, min_value), upper^)
		changed = true
	}
	if high_x != 0 || high_y != 0 {
		upper^ = max(min(upper^ + (high_x - high_y) * step, max_value), lower^)
		changed = true
	}
	low_t = uifw.gui_clamp01((lower^ - min_value) / range)
	high_t = uifw.gui_clamp01((upper^ - min_value) / range)
	low_center.x = track.x + track.w * low_t
	high_center.x = track.x + track.w * high_t
	label := fmt.tprintf("%s: %.2f - %.2f", title, lower^, upper^)
	if ctx.focused == low_id {label = fmt.tprintf("%s · [Min %.2f]   Max %.2f", title, lower^, upper^)}
	if ctx.focused == high_id {label = fmt.tprintf("%s · Min %.2f   [Max %.2f]", title, lower^, upper^)}
	uifw.gui_text_clipped(ctx, {bounds.x, bounds.y, bounds.w, label_h}, {bounds.x + 2, bounds.y}, label, ctx.style.text)
	uifw.gui_round_rect(ctx, track, track_h * 0.5, ctx.style.control)
	uifw.gui_round_rect(ctx, {low_center.x, track.y, max(high_center.x - low_center.x, 1), track.h}, track_h * 0.5, ctx.style.accent)
	low_fill := ctx.focused == low_id ? ctx.style.accent : ctx.style.text
	high_fill := ctx.focused == high_id ? ctx.style.accent : ctx.style.text
	uifw.gui_ellipse(ctx, {low_center.x - handle_radius, low_center.y - handle_radius, handle_radius * 2, handle_radius * 2}, low_fill)
	uifw.gui_ellipse(ctx, {high_center.x - handle_radius, high_center.y - handle_radius, handle_radius * 2, handle_radius * 2}, high_fill)
	uifw.gui_focus_or_edit_ring(ctx, low_id, low_hit)
	uifw.gui_focus_or_edit_ring(ctx, high_id, high_hit)
	return changed
}

shared_image_selector :: proc(ctx: ^uifw.Gui_Context, fit_index: ^int, fit_names: []string, options: Image_Selector_Options) -> Image_Selector_Result {
	result: Image_Selector_Result
	has_selection := len(options.selected_path) > 0
	if options.show_selected_path {
		if has_selection {
			uifw.gui_label(ctx, fmt.tprintf("%s: %s", options.selected_label, options.selected_path))
		} else {
			uifw.gui_label(ctx, options.empty_label)
		}
	}
	if options.show_fit_mode && fit_index != nil && len(fit_names) > 0 {
		fit_index^ = max(min(fit_index^, len(fit_names) - 1), 0)
		if uifw.gui_selector(ctx, fmt.tprintf("%s: %s", options.fit_label, fit_names[fit_index^]), options.fit_key, fit_index, fit_names) {
			fit_index^ = max(min(fit_index^, len(fit_names) - 1), 0)
			result.fit_changed = true
		}
	}
	if options.show_load_button && has_selection && uifw.gui_button(ctx, options.load_label, options.load_key) {
		result.load_requested = true
	}
	if options.show_browse_button && uifw.gui_button(ctx, options.browse_label, options.browse_key) {
		result.browse_requested = true
	}
	if options.show_clear_button && has_selection && uifw.gui_button(ctx, options.clear_label, options.clear_key) {
		result.clear_requested = true
	}
	return result
}

shared_webcam_controls :: proc(ctx: ^uifw.Gui_Context, options: Webcam_Controls_Options) -> Webcam_Controls_Result {
	result: Webcam_Controls_Result
	if options.active {
		if uifw.gui_button(ctx, options.stop_label, options.stop_key) {
			result.action = .Stop
		}
	} else if uifw.gui_button(ctx, options.start_label, options.start_key) {
		result.action = .Start
	}
	if options.device_count > 0 {
		uifw.gui_label(ctx, fmt.tprintf("%d camera%s available", options.device_count, options.device_count == 1 ? "" : "s"))
	}
	return result
}

shared_post_processing_menu :: proc(ctx: ^uifw.Gui_Context, enabled: ^bool, radius: ^f32, sigma: ^f32, options: Post_Processing_Menu_Options) -> bool {
	changed := false
	if len(options.heading) > 0 {
		uifw.gui_heading(ctx, options.heading)
	}
	if uifw.gui_toggle(ctx, enabled^ ? "Enabled" : "Disabled", options.enabled_key, enabled) {
		changed = true
	}
	if enabled^ {
		if uifw.gui_numeric_f32(ctx, fmt.tprintf("%s: %.2f", options.radius_label, radius^), options.radius_key, radius, options.radius_step, options.radius_min, options.radius_max) {
			changed = true
		}
		if uifw.gui_numeric_f32(ctx, fmt.tprintf("%s: %.2f", options.sigma_label, sigma^), options.sigma_key, sigma, options.sigma_step, options.sigma_min, options.sigma_max) {
			changed = true
		}
	}
	return changed
}
