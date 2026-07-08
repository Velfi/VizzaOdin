package game

import uifw "../ui"

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
}

Controls_Panel_Options :: struct {
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
	uifw.gui_heading(ctx, "Controls")
	if len(options.mouse_interaction_text) > 0 {
		uifw.gui_label(ctx, options.mouse_interaction_text)
	}
	if len(options.cursor_settings_title) > 0 {
		uifw.gui_label(ctx, options.cursor_settings_title)
	}
	slider_h := uifw.gui_slider_height(ctx)
	card_h := slider_h * (options.cursor.show_strength ? f32(2) : f32(1)) + ctx.style.spacing * (options.cursor.show_strength ? f32(1) : f32(0)) + ctx.style.spacing_2 * 2
	card := uifw.gui_next_rect(ctx, height = card_h)
	uifw.gui_round_rect(ctx, card, 6, {1, 1, 1, 0.05})
	uifw.gui_round_stroke(ctx, card, 6, {1, 1, 1, 0.10}, ctx.style.border_width)
	uifw.gui_layout_begin(ctx, uifw.gui_inset(card, ctx.style.spacing_2), .Column, ctx.style.spacing, ctx.style.row_height)
	changed := shared_cursor_config(ctx, cursor_size, cursor_strength, options.cursor)
	uifw.gui_layout_end(ctx)
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
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("%s: %.2f", options.radius_label, radius^), options.radius_key, radius, options.radius_step, options.radius_min, options.radius_max) {
		changed = true
	}
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("%s: %.2f", options.sigma_label, sigma^), options.sigma_key, sigma, options.sigma_step, options.sigma_min, options.sigma_max) {
		changed = true
	}
	return changed
}
