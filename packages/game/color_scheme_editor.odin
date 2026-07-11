package game

import uifw "../ui"

import "core:fmt"
import "core:math"
import "core:strings"

COLOR_SCHEME_EDITOR_MAX_STOPS :: 16
// Keep the mini/modal editor compiled but unavailable until it is ready to ship.
COLOR_SCHEME_MINI_EDITOR_ENABLED :: false

Color_Scheme_Editor_Stop :: struct {
	position: f32,
	color: uifw.Color,
}

Color_Scheme_Editor_State :: struct {
	open: bool,
	modal_open: bool,
	modal_invoker_focus: uifw.Gui_Id,
	initialized: bool,
	name: [COLOR_SCHEME_NAME_MAX]u8,
	name_len: int,
	modal_original_name: Color_Scheme_Name,
	stops: [COLOR_SCHEME_EDITOR_MAX_STOPS]Color_Scheme_Editor_Stop,
	stop_count: int,
	selected_stop: int,
	preset_index: int,
	color_space_index: int,
	interpolation_index: int,
	random_scheme_index: int,
	random_placement_index: int,
	random_stop_count: f32,
	display_mode_index: int,
	modal_scroll: f32,
	seed: u32,
	selected_hsv: uifw.Hsv_Color,
	status: [128]u8,
	selector_query: [128]u8,
}

COLOR_SCHEME_EDITOR_PRESETS := [?]string {
	"Custom",
	"Rainbow",
	"Heat",
	"Cool",
	"Viridis",
	"Plasma",
	"Inferno",
}

COLOR_SCHEME_EDITOR_COLOR_SPACES := [?]string {
	"RGB",
	"Lab",
	"OkLab",
	"Jzazbz",
	"HSLuv",
}

COLOR_SCHEME_EDITOR_INTERPOLATION := [?]string {
	"Smooth",
	"Stepped",
}

COLOR_SCHEME_EDITOR_DISPLAY_MODES := [?]string {
	"Smooth",
	"Dithered",
}

COLOR_SCHEME_EDITOR_RANDOM_SCHEMES := [?]string {
	"Basic",
	"Warm",
	"Cool",
	"Pastel",
	"Neon",
	"Earth",
	"Monochrome",
	"Complementary",
	"Truly Random",
}

COLOR_SCHEME_EDITOR_RANDOM_PLACEMENT := [?]string {
	"Random",
	"Even",
}

color_scheme_editor_init :: proc(editor: ^Color_Scheme_Editor_State) {
	editor^ = {}
	write_fixed_string(editor.name[:], "CUSTOM_New_Color_Scheme")
	editor.name_len = len("CUSTOM_New_Color_Scheme")
	editor.stop_count = 2
	editor.stops[0] = {position = 0, color = {0, 0, 1, 1}}
	editor.stops[1] = {position = 1, color = {1, 1, 0, 1}}
	editor.selected_stop = 0
	editor.color_space_index = 2
	editor.random_stop_count = 3
	editor.seed = 0x9e3779b9
	editor.selected_hsv = uifw.gui_rgb_to_hsv(editor.stops[0].color)
	editor.initialized = true
}

color_scheme_editor_draw_selector :: proc(ctx: ^uifw.Gui_Context, editor: ^Color_Scheme_Editor_State, key_prefix: string, color_name: ^Color_Scheme_Name, reversed: ^bool) -> bool {
	if !editor.initialized {
		color_scheme_editor_init(editor)
	}

	changed := false
	uifw.gui_push_id(ctx, key_prefix)
	color_names := color_scheme_available_names_cached()
	if len(color_names) > 0 {
		changed = color_scheme_editor_draw_scheme_picker(ctx, color_name, color_names, editor.selector_query[:]) || changed
	}
	if uifw.gui_toggle(ctx, fmt.tprintf("Reverse Colors: %v", reversed^), "reverse_colors", reversed) {
		changed = true
	}
	if COLOR_SCHEME_MINI_EDITOR_ENABLED {
		if uifw.gui_button(ctx, "Edit Color Scheme", "edit_color_scheme") {
			editor.modal_open = true
			editor.modal_invoker_focus = ctx.focused
			editor.modal_scroll = 0
			if color_name != nil {
				color_scheme_name_set(&editor.modal_original_name, color_scheme_name_get(color_name))
			}
		}
	}
	uifw.gui_pop_id(ctx)
	return changed
}

color_scheme_editor_draw_scheme_picker :: proc(ctx: ^uifw.Gui_Context, color_name: ^Color_Scheme_Name, color_names: []string, query_buffer: []u8) -> bool {
	color_index := color_scheme_index_of(color_names, color_scheme_name_get(color_name))
	if uifw.gui_stepper_combobox(
		ctx,
		color_scheme_name_get(color_name),
		"color_scheme",
		&color_index,
		color_names,
		query_buffer,
		"Previous color scheme",
		"Next color scheme",
	) {
		color_index = max(min(color_index, len(color_names) - 1), 0)
		color_scheme_name_set(color_name, color_names[color_index])
		return true
	}
	return false
}

color_scheme_editor_draw :: proc(ctx: ^uifw.Gui_Context, editor: ^Color_Scheme_Editor_State, color_name: ^Color_Scheme_Name) -> bool {
	changed := false
	uifw.gui_spacer(ctx, 6)
	uifw.gui_heading(ctx, "Color Scheme Editor")
	_ = uifw.gui_text_input(ctx, "Custom LUT name", "custom_lut_name", editor.name[:], &editor.name_len)

	if uifw.gui_selector(ctx, fmt.tprintf("Preset: %s", COLOR_SCHEME_EDITOR_PRESETS[editor.preset_index]), "preset", &editor.preset_index, COLOR_SCHEME_EDITOR_PRESETS[:]) {
		color_scheme_editor_apply_preset(editor, editor.preset_index)
	}
	_ = uifw.gui_selector(ctx, fmt.tprintf("Space: %s", COLOR_SCHEME_EDITOR_COLOR_SPACES[editor.color_space_index]), "color_space", &editor.color_space_index, COLOR_SCHEME_EDITOR_COLOR_SPACES[:])
	_ = uifw.gui_selector(ctx, fmt.tprintf("Display: %s", COLOR_SCHEME_EDITOR_DISPLAY_MODES[editor.display_mode_index]), "display_mode", &editor.display_mode_index, COLOR_SCHEME_EDITOR_DISPLAY_MODES[:])
	_ = uifw.gui_selector(ctx, fmt.tprintf("Interpolation: %s", COLOR_SCHEME_EDITOR_INTERPOLATION[editor.interpolation_index]), "interpolation", &editor.interpolation_index, COLOR_SCHEME_EDITOR_INTERPOLATION[:])

	color_scheme_editor_gradient_control(ctx, editor)

	if editor.selected_stop >= 0 && editor.selected_stop < editor.stop_count {
		stop := &editor.stops[editor.selected_stop]
		if uifw.gui_slider_f32(ctx, fmt.tprintf("Stop Position: %.2f", stop.position), "stop_position", &stop.position, 0, 1) {
			color_scheme_editor_sort_stops(editor)
		}
		if uifw.gui_color_picker_hsv(ctx, fmt.tprintf("Stop Color %d", editor.selected_stop + 1), "stop_color", &editor.selected_hsv) {
			stop = &editor.stops[editor.selected_stop]
			stop.color = uifw.gui_hsv_to_rgb(editor.selected_hsv)
			stop.color.a = 1
		}
		if uifw.gui_button(ctx, "Copy Selected Stop", "copy_stop") {
			color_scheme_editor_duplicate_selected(editor)
		}
		if editor.stop_count > 2 && uifw.gui_button(ctx, "Delete Selected Stop", "delete_stop") {
			color_scheme_editor_delete_selected(editor)
		}
	}

	uifw.gui_spacer(ctx, 4)
	_ = uifw.gui_selector(ctx, fmt.tprintf("Random Scheme: %s", COLOR_SCHEME_EDITOR_RANDOM_SCHEMES[editor.random_scheme_index]), "random_scheme", &editor.random_scheme_index, COLOR_SCHEME_EDITOR_RANDOM_SCHEMES[:])
	_ = uifw.gui_selector(ctx, fmt.tprintf("Stop Placement: %s", COLOR_SCHEME_EDITOR_RANDOM_PLACEMENT[editor.random_placement_index]), "random_placement", &editor.random_placement_index, COLOR_SCHEME_EDITOR_RANDOM_PLACEMENT[:])
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Stops: %d", int(editor.random_stop_count + 0.5)), "random_stop_count", &editor.random_stop_count, 2, COLOR_SCHEME_EDITOR_MAX_STOPS)
	if uifw.gui_button(ctx, "Generate Random Scheme", "generate_random") {
		color_scheme_editor_randomize(editor)
	}
	if uifw.gui_button(ctx, "Reverse Gradient Stops", "reverse_gradient") {
		color_scheme_editor_reverse(editor)
	}
	if uifw.gui_button(ctx, "Save Color Scheme", "save_color_scheme") {
		name := color_scheme_editor_sanitized_name(editor)
		if len(name) > 0 {
			scheme := color_scheme_editor_build_scheme(editor, name)
			if color_scheme_save_custom(name, scheme) {
				if color_name != nil {
					color_scheme_name_set(color_name, name)
				}
				write_fixed_string(editor.status[:], fmt.tprintf("Saved %s", name))
				changed = true
			} else {
				write_fixed_string(editor.status[:], "Failed to save color scheme")
			}
		} else {
			write_fixed_string(editor.status[:], "Enter a name before saving")
		}
	}
	status := fixed_string(editor.status[:])
	if len(status) > 0 {
		uifw.gui_label(ctx, status)
	}

	return changed
}

color_scheme_editor_draw_modal :: proc(ctx: ^uifw.Gui_Context, editor: ^Color_Scheme_Editor_State, color_name: ^Color_Scheme_Name) -> bool {
	if !COLOR_SCHEME_MINI_EDITOR_ENABLED {
		editor.modal_open = false
		editor.modal_scroll = 0
		return false
	}
	if !editor.initialized {
		color_scheme_editor_init(editor)
	}
	if !editor.modal_open {
		return false
	}

	window_w := f32(ctx.input.window_width)
	window_h := f32(ctx.input.window_height)
	dialog_w := min(max(window_w - ctx.style.spacing_2 * 2, 320), 760)
	dialog_h := min(max(window_h - ctx.style.spacing_2 * 2, 360), 720)
	dialog := uifw.Rect{
		x = max((window_w - dialog_w) * 0.5, ctx.style.spacing_2),
		y = max(window_h * 0.10, ctx.style.spacing_2),
		w = dialog_w,
		h = dialog_h,
	}
	if dialog.y + dialog.h > window_h - ctx.style.spacing_2 {
		dialog.y = max(window_h - dialog.h - ctx.style.spacing_2, ctx.style.spacing_2)
	}

	changed := false
	uifw.gui_push_id(ctx, "color_scheme_modal")
	uifw.gui_overlay_input_begin(ctx, {0, 0, window_w, window_h})
	if ctx.input.back {
		color_scheme_editor_cancel_modal(editor, color_name)
		color_scheme_editor_restore_focus(ctx, editor)
		uifw.gui_overlay_input_cancel(ctx)
		uifw.gui_pop_id(ctx)
		return false
	}
	uifw.gui_spatial_group_begin(ctx, "color_modal_focus_scope")
	defer uifw.gui_spatial_group_end(ctx)
	uifw.gui_focus_scope_trap_current(ctx)
	previous_explicit_activation := ctx.controller_explicit_activation
	ctx.controller_explicit_activation = previous_explicit_activation || ctx.input.active_device == .Controller
	defer ctx.controller_explicit_activation = previous_explicit_activation
	uifw.gui_panel_begin(ctx, dialog)
	header := uifw.gui_next_rect(ctx, height = ctx.style.row_height)
	close_w := min(ctx.style.row_height * 2.3, header.w * 0.24)
	title_rect := uifw.Rect{header.x, header.y, max(header.w - close_w - ctx.style.spacing, 0), header.h}
	close_rect := uifw.Rect{header.x + header.w - close_w, header.y, close_w, header.h}
	uifw.gui_text_clipped(ctx, title_rect, {title_rect.x + 2, title_rect.y + 5}, "Color Scheme Editor", ctx.style.text)
	if uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, "close"), close_rect, "Cancel", true) {
		color_scheme_editor_cancel_modal(editor, color_name)
		color_scheme_editor_restore_focus(ctx, editor)
		uifw.gui_focus_scope_release(ctx)
		uifw.gui_panel_end(ctx)
		uifw.gui_overlay_input_cancel(ctx)
		uifw.gui_pop_id(ctx)
		return false
	}

	viewport := uifw.gui_next_rect(ctx, height = max(dialog.h - ctx.style.panel_padding * 2 - ctx.style.row_height - ctx.style.spacing, 0))
	content_height := color_scheme_editor_mini_content_height(ctx)
	uifw.gui_scroll_begin(ctx, viewport, content_height, &editor.modal_scroll)
	changed = color_scheme_editor_draw_mini(ctx, editor, color_name) || changed
	uifw.gui_scroll_end(ctx)
	if !editor.modal_open {
		color_scheme_editor_restore_focus(ctx, editor)
		uifw.gui_focus_scope_release(ctx)
	}
	uifw.gui_panel_end(ctx)
	if editor.modal_open {
		uifw.gui_overlay_input_end(ctx)
	} else {
		uifw.gui_overlay_input_cancel(ctx)
	}
	uifw.gui_pop_id(ctx)

	return changed
}

color_scheme_editor_cancel_modal :: proc(editor: ^Color_Scheme_Editor_State, color_name: ^Color_Scheme_Name) {
	if color_name != nil {
		original := color_scheme_name_get(&editor.modal_original_name)
		if len(original) > 0 {
			color_scheme_name_set(color_name, original)
		}
	}
	editor.modal_open = false
	editor.modal_scroll = 0
}

color_scheme_editor_restore_focus :: proc(ctx: ^uifw.Gui_Context, editor: ^Color_Scheme_Editor_State) {
	if ctx != nil && editor.modal_invoker_focus != uifw.GUI_ID_NONE {
		ctx.focused = editor.modal_invoker_focus
	}
	editor.modal_invoker_focus = uifw.GUI_ID_NONE
}

color_scheme_editor_mini_content_height :: proc(ctx: ^uifw.Gui_Context) -> f32 {
	return ctx.style.row_height * 18 + ctx.style.spacing * 20 + 92
}

color_scheme_editor_draw_mini :: proc(ctx: ^uifw.Gui_Context, editor: ^Color_Scheme_Editor_State, color_name: ^Color_Scheme_Name) -> bool {
	changed := false
	_ = uifw.gui_text_input(ctx, "Name", "mini_lut_name", editor.name[:], &editor.name_len)

	row := uifw.gui_next_rect(ctx, height = ctx.style.row_height)
	cells: [2]uifw.Rect
	uifw.gui_distribute_equal(cells[:], row, .Row, ctx.style.spacing, .Start)
	uifw.gui_layout_begin(ctx, cells[0], .Column, 0, ctx.style.row_height)
	if uifw.gui_selector(ctx, fmt.tprintf("Preset: %s", COLOR_SCHEME_EDITOR_PRESETS[editor.preset_index]), "mini_preset", &editor.preset_index, COLOR_SCHEME_EDITOR_PRESETS[:]) {
		color_scheme_editor_apply_preset(editor, editor.preset_index)
	}
	uifw.gui_layout_end(ctx)
	uifw.gui_layout_begin(ctx, cells[1], .Column, 0, ctx.style.row_height)
	_ = uifw.gui_selector(ctx, fmt.tprintf("Space: %s", COLOR_SCHEME_EDITOR_COLOR_SPACES[editor.color_space_index]), "mini_color_space", &editor.color_space_index, COLOR_SCHEME_EDITOR_COLOR_SPACES[:])
	uifw.gui_layout_end(ctx)

	row = uifw.gui_next_rect(ctx, height = ctx.style.row_height)
	uifw.gui_distribute_equal(cells[:], row, .Row, ctx.style.spacing, .Start)
	uifw.gui_layout_begin(ctx, cells[0], .Column, 0, ctx.style.row_height)
	_ = uifw.gui_selector(ctx, fmt.tprintf("Interpolation: %s", COLOR_SCHEME_EDITOR_INTERPOLATION[editor.interpolation_index]), "mini_interpolation", &editor.interpolation_index, COLOR_SCHEME_EDITOR_INTERPOLATION[:])
	uifw.gui_layout_end(ctx)
	uifw.gui_layout_begin(ctx, cells[1], .Column, 0, ctx.style.row_height)
	_ = uifw.gui_selector(ctx, fmt.tprintf("Display: %s", COLOR_SCHEME_EDITOR_DISPLAY_MODES[editor.display_mode_index]), "mini_display", &editor.display_mode_index, COLOR_SCHEME_EDITOR_DISPLAY_MODES[:])
	uifw.gui_layout_end(ctx)

	color_scheme_editor_gradient_control(ctx, editor)

	if editor.selected_stop >= 0 && editor.selected_stop < editor.stop_count {
		uifw.gui_label(ctx, fmt.tprintf("Color Stop %d", editor.selected_stop + 1))
		stop := &editor.stops[editor.selected_stop]
		if uifw.gui_slider_f32(ctx, fmt.tprintf("Position: %.2f", stop.position), "mini_stop_position", &stop.position, 0, 1) {
			color_scheme_editor_sort_stops(editor)
		}
		if uifw.gui_color_picker_hsv(ctx, fmt.tprintf("Color %d", editor.selected_stop + 1), "mini_stop_color", &editor.selected_hsv) {
			stop = &editor.stops[editor.selected_stop]
			stop.color = uifw.gui_hsv_to_rgb(editor.selected_hsv)
			stop.color.a = 1
		}
		row = uifw.gui_next_rect(ctx, height = ctx.style.row_height)
		uifw.gui_distribute_equal(cells[:], row, .Row, ctx.style.spacing, .Start)
		if uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, "mini_copy"), cells[0], "Copy", true) {
			color_scheme_editor_duplicate_selected(editor)
		}
		delete_enabled := editor.stop_count > 2
		if uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, "mini_delete"), cells[1], "Delete", delete_enabled) {
			color_scheme_editor_delete_selected(editor)
		}
	}

	uifw.gui_spacer(ctx, 4)
	uifw.gui_label(ctx, "Random Generator")
	_ = uifw.gui_selector(ctx, fmt.tprintf("Random Scheme: %s", COLOR_SCHEME_EDITOR_RANDOM_SCHEMES[editor.random_scheme_index]), "mini_random_scheme", &editor.random_scheme_index, COLOR_SCHEME_EDITOR_RANDOM_SCHEMES[:])
	_ = uifw.gui_selector(ctx, fmt.tprintf("Stop Placement: %s", COLOR_SCHEME_EDITOR_RANDOM_PLACEMENT[editor.random_placement_index]), "mini_random_placement", &editor.random_placement_index, COLOR_SCHEME_EDITOR_RANDOM_PLACEMENT[:])
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Stops: %d", int(editor.random_stop_count + 0.5)), "mini_random_stop_count", &editor.random_stop_count, 2, COLOR_SCHEME_EDITOR_MAX_STOPS)
	if uifw.gui_button(ctx, "Generate", "mini_generate") {
		color_scheme_editor_randomize(editor)
	}
	if uifw.gui_button(ctx, "Reverse Gradient", "mini_reverse") {
		color_scheme_editor_reverse(editor)
	}

	row = uifw.gui_next_rect(ctx, height = ctx.style.row_height)
	uifw.gui_distribute_equal(cells[:], row, .Row, ctx.style.spacing, .Start)
	if uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, "mini_save"), cells[0], "Save Color Scheme", true) {
		name := color_scheme_editor_sanitized_name(editor)
		if len(name) > 0 {
			scheme := color_scheme_editor_build_scheme(editor, name)
			if color_scheme_save_custom(name, scheme) {
				if color_name != nil {
					color_scheme_name_set(color_name, name)
				}
				write_fixed_string(editor.status[:], fmt.tprintf("Saved %s", name))
				editor.modal_open = false
				editor.modal_scroll = 0
				changed = true
			} else {
				write_fixed_string(editor.status[:], "Failed to save color scheme")
			}
		} else {
			write_fixed_string(editor.status[:], "Enter a name before saving")
		}
	}
	if uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, "mini_cancel"), cells[1], "Cancel", true) {
		color_scheme_editor_cancel_modal(editor, color_name)
	}

	status := fixed_string(editor.status[:])
	if len(status) > 0 {
		uifw.gui_label(ctx, status)
	}
	return changed
}

color_scheme_editor_draw_standalone :: proc(ctx: ^uifw.Gui_Context, editor: ^Color_Scheme_Editor_State, panel: uifw.Rect, scroll: ^f32) {
	if !editor.initialized {
		color_scheme_editor_init(editor)
	}
	uifw.gui_panel_begin(ctx, panel)
	viewport := uifw.gui_next_rect(ctx, height = max(panel.h - ctx.style.panel_padding * 2, 0))
	content_height := color_scheme_editor_content_height(ctx)
	uifw.gui_scroll_begin(ctx, viewport, content_height, scroll)
	_ = color_scheme_editor_draw(ctx, editor, nil)
	uifw.gui_scroll_end(ctx)
	uifw.gui_panel_end(ctx)
}

color_scheme_editor_content_height :: proc(ctx: ^uifw.Gui_Context) -> f32 {
	return ctx.style.row_height * 25 + ctx.style.spacing * 26 + ctx.style.text_height * 4
}

color_scheme_editor_draw_full_preview :: proc(ctx: ^uifw.Gui_Context, editor: ^Color_Scheme_Editor_State, bounds: uifw.Rect) {
	if !editor.initialized {
		color_scheme_editor_init(editor)
	}
	segments := 256
	for i in 0 ..< segments {
		x0 := bounds.x + bounds.w * f32(i) / f32(segments)
		x1 := bounds.x + bounds.w * f32(i + 1) / f32(segments)
		t := (f32(i) + 0.5) / f32(segments)
		color := color_scheme_editor_preview_color_at(editor, t, i)
		uifw.gui_rect(ctx, {x0, bounds.y, max(x1 - x0 + 1, 1), bounds.h}, color)
	}
}

color_scheme_editor_gradient_control :: proc(ctx: ^uifw.Gui_Context, editor: ^Color_Scheme_Editor_State) {
	bounds := uifw.gui_next_rect(ctx, height = 68)
	track := uifw.Rect{bounds.x, bounds.y + 8, bounds.w, 34}
	segments := 64
	for i in 0 ..< segments {
		x0 := track.x + track.w * f32(i) / f32(segments)
		x1 := track.x + track.w * f32(i + 1) / f32(segments)
		t := (f32(i) + 0.5) / f32(segments)
		color := color_scheme_editor_preview_color_at(editor, t, i)
		uifw.gui_rect(ctx, {x0, track.y, max(x1 - x0 + 1, 1), track.h}, color)
	}
	uifw.gui_round_stroke(ctx, track, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)

	preview_id := uifw.gui_make_id(ctx, "gradient_preview")
	over_stop := false
	for i in 0 ..< editor.stop_count {
		x := track.x + track.w * uifw.gui_clamp01(editor.stops[i].position)
		handle_rect := uifw.Rect{x - 6, track.y - 5, 12, track.h + 10}
		if uifw.gui_mouse_contains(ctx, handle_rect) {
			over_stop = true
			break
		}
	}
	preview_control := uifw.gui_control(ctx, preview_id, track, true, false)
	if !over_stop && preview_control.hovered && ctx.active == preview_id && ctx.input.mouse_released && editor.stop_count < COLOR_SCHEME_EDITOR_MAX_STOPS {
		t := uifw.gui_clamp01((ctx.input.mouse_pos.x - track.x) / max(track.w, 1))
		color_scheme_editor_add_stop(editor, t)
	}

	for i in 0 ..< editor.stop_count {
		uifw.gui_push_id_int(ctx, i)
		stop := &editor.stops[i]
		x := track.x + track.w * uifw.gui_clamp01(stop.position)
		handle_rect := uifw.Rect{x - 6, track.y - 5, 12, track.h + 10}
		handle_id := uifw.gui_make_id(ctx, "stop")
		dragging := uifw.gui_drag_handle_region(ctx, handle_id, handle_rect, {x, track.y + track.h * 0.5}, 10)
		if dragging {
			fine := uifw.gui_pointer_fine_adjust_scale(ctx, handle_id)
			if fine < 1 {
				stop.position = uifw.gui_clamp01(stop.position + ctx.mouse_delta.x / max(track.w, 1) * fine)
			} else {
				stop.position = uifw.gui_clamp01((ctx.input.mouse_pos.x - track.x) / max(track.w, 1))
			}
			editor.selected_stop = i
			color_scheme_editor_sort_stops(editor)
		}
		_ = uifw.gui_update_focus_edit(ctx, handle_id, ctx.focused == handle_id)
		uifw.gui_controller_edit_f32(ctx, handle_id, &stop.position)
		nav_x, nav_y := uifw.gui_focused_nav_pressed(ctx, handle_id)
		if nav_x != 0 || nav_y != 0 {
			lower := i > 0 ? editor.stops[i - 1].position : f32(0)
			upper := i + 1 < editor.stop_count ? editor.stops[i + 1].position : f32(1)
			stop.position = min(max(stop.position + (nav_x - nav_y) * 0.02 * uifw.gui_fine_adjust_scale(ctx), lower), upper)
		}
		if ctx.focused == handle_id || (uifw.gui_mouse_contains(ctx, handle_rect) && ctx.input.mouse_pressed) {
			editor.selected_stop = i
			editor.selected_hsv = uifw.gui_rgb_to_hsv(editor.stops[i].color)
		}
		border := editor.selected_stop == i ? ctx.style.accent : ctx.style.text
		uifw.gui_round_rect(ctx, handle_rect, 4, stop.color)
		uifw.gui_round_stroke(ctx, handle_rect, 4, border, 2)
		uifw.gui_focus_or_edit_ring(ctx, handle_id, handle_rect)
		uifw.gui_pop_id(ctx)
	}
}

color_scheme_editor_preview_color_at :: proc(editor: ^Color_Scheme_Editor_State, position: f32, index: int) -> uifw.Color {
	color := color_scheme_editor_color_at(editor, position)
	if editor.display_mode_index != 1 {
		return color
	}
	threshold := f32(((index * 73) ~ (index >> 1) ~ 0x5a) & 15) / 15.0
	amount := (threshold - 0.5) * 0.08
	return {
		r = uifw.gui_clamp01(color.r + amount),
		g = uifw.gui_clamp01(color.g + amount),
		b = uifw.gui_clamp01(color.b + amount),
		a = color.a,
	}
}

color_scheme_editor_apply_preset :: proc(editor: ^Color_Scheme_Editor_State, preset: int) {
	editor.preset_index = max(min(preset, len(COLOR_SCHEME_EDITOR_PRESETS) - 1), 0)
	switch editor.preset_index {
	case 1:
		color_scheme_editor_set_hex_stops(editor, []string{"#ff0000", "#ff8000", "#ffff00", "#00ff00", "#0080ff", "#8000ff", "#ff0080"})
	case 2:
		color_scheme_editor_set_hex_stops(editor, []string{"#000000", "#ff0000", "#ffff00"})
	case 3:
		color_scheme_editor_set_hex_stops(editor, []string{"#0000ff", "#00ffff", "#ffffff"})
	case 4:
		color_scheme_editor_set_hex_stops(editor, []string{"#440154", "#31688e", "#35b779", "#fde725"})
	case 5:
		color_scheme_editor_set_hex_stops(editor, []string{"#0d0887", "#7e03a8", "#cc4778", "#f89441", "#f0f921"})
	case 6:
		color_scheme_editor_set_hex_stops(editor, []string{"#000004", "#1b0c41", "#4a0c6b", "#781c6d", "#ed6925"})
	}
}

color_scheme_editor_set_hex_stops :: proc(editor: ^Color_Scheme_Editor_State, colors: []string) {
	count := min(len(colors), COLOR_SCHEME_EDITOR_MAX_STOPS)
	editor.stop_count = count
	for color, i in colors[:count] {
		position := count == 1 ? f32(0) : f32(i) / f32(count - 1)
		editor.stops[i] = {position = position, color = color_scheme_editor_hex_to_color(color)}
	}
	editor.selected_stop = 0
	editor.selected_hsv = uifw.gui_rgb_to_hsv(editor.stops[0].color)
}

color_scheme_editor_duplicate_selected :: proc(editor: ^Color_Scheme_Editor_State) {
	if editor.stop_count >= COLOR_SCHEME_EDITOR_MAX_STOPS || editor.selected_stop < 0 || editor.selected_stop >= editor.stop_count {
		return
	}
	stop := editor.stops[editor.selected_stop]
	stop.position = uifw.gui_clamp01(stop.position + 0.05)
	editor.stops[editor.stop_count] = stop
	editor.stop_count += 1
	editor.selected_stop = editor.stop_count - 1
	color_scheme_editor_sort_stops(editor)
	editor.selected_hsv = uifw.gui_rgb_to_hsv(editor.stops[editor.selected_stop].color)
}

color_scheme_editor_add_stop :: proc(editor: ^Color_Scheme_Editor_State, position: f32) {
	if editor.stop_count >= COLOR_SCHEME_EDITOR_MAX_STOPS {
		return
	}
	editor.stops[editor.stop_count] = {position = uifw.gui_clamp01(position), color = color_scheme_editor_color_at(editor, position)}
	editor.stop_count += 1
	editor.selected_stop = editor.stop_count - 1
	color_scheme_editor_sort_stops(editor)
	editor.selected_hsv = uifw.gui_rgb_to_hsv(editor.stops[editor.selected_stop].color)
}

color_scheme_editor_delete_selected :: proc(editor: ^Color_Scheme_Editor_State) {
	if editor.stop_count <= 2 || editor.selected_stop < 0 || editor.selected_stop >= editor.stop_count {
		return
	}
	for i in editor.selected_stop ..< editor.stop_count - 1 {
		editor.stops[i] = editor.stops[i + 1]
	}
	editor.stop_count -= 1
	editor.selected_stop = min(editor.selected_stop, editor.stop_count - 1)
	editor.selected_hsv = uifw.gui_rgb_to_hsv(editor.stops[editor.selected_stop].color)
}

color_scheme_editor_sort_stops :: proc(editor: ^Color_Scheme_Editor_State) {
	if editor.stop_count <= 1 {
		return
	}
	selected_position := editor.selected_stop >= 0 && editor.selected_stop < editor.stop_count ? editor.stops[editor.selected_stop].position : -1
	for i in 1 ..< editor.stop_count {
		j := i
		for j > 0 && editor.stops[j - 1].position > editor.stops[j].position {
			editor.stops[j - 1], editor.stops[j] = editor.stops[j], editor.stops[j - 1]
			j -= 1
		}
	}
	if selected_position >= 0 {
		for i in 0 ..< editor.stop_count {
			if math.abs(editor.stops[i].position - selected_position) < 0.002 {
				editor.selected_stop = i
				break
			}
		}
	}
}

color_scheme_editor_reverse :: proc(editor: ^Color_Scheme_Editor_State) {
	for i in 0 ..< editor.stop_count {
		editor.stops[i].position = 1 - editor.stops[i].position
	}
	color_scheme_editor_sort_stops(editor)
}

color_scheme_editor_color_at :: proc(editor: ^Color_Scheme_Editor_State, position: f32) -> uifw.Color {
	if editor.stop_count <= 0 {
		return {0, 0, 0, 1}
	}
	t := uifw.gui_clamp01(position)
	left := editor.stops[0]
	right := editor.stops[editor.stop_count - 1]
	for i in 0 ..< editor.stop_count - 1 {
		if editor.stops[i].position <= t && editor.stops[i + 1].position >= t {
			left = editor.stops[i]
			right = editor.stops[i + 1]
			break
		}
	}
	if editor.interpolation_index == 1 || right.position <= left.position {
		return left.color
	}
	local_t := uifw.gui_clamp01((t - left.position) / max(right.position - left.position, 0.000001))
	return color_scheme_editor_interpolate(left.color, right.color, local_t, editor.color_space_index)
}
