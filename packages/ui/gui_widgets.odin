package ui

import "core:math"
import "core:fmt"
import "core:strconv"

gui_label :: proc(ctx: ^Gui_Context, text: string) {
	bounds := gui_next_rect(ctx, height = ctx.style.body_line_height)
	gui_text_clipped(ctx, bounds, {bounds.x + ctx.style.spacing_1, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, text, ctx.style.text_muted)
}

gui_heading :: proc(ctx: ^Gui_Context, text: string) {
	bounds := gui_next_rect(ctx, height = ctx.style.heading_line_height)
	gui_scissor_begin(ctx, bounds)
	append(&ctx.commands, Draw_Command{
		kind = .Text,
		rect = {bounds.x + ctx.style.spacing_1, bounds.y + max((bounds.h - ctx.style.heading_text_height) * 0.5, 0), 0, 0},
		color = ctx.style.text,
		text = text,
		text_scale = ctx.style.heading_text_scale,
		text_align = .Left,
		font_kind = .Display,
	})
	gui_scissor_end(ctx)
	line_y := bounds.y + bounds.h - ctx.style.border_width
	gui_rect(ctx, {bounds.x, line_y, bounds.w, ctx.style.border_width}, {1, 1, 1, 0.20})
}

gui_text_block :: proc(ctx: ^Gui_Context, text: string, max_width: f32, color: Color) {
	wrap_width := max(max_width - ctx.style.spacing_1, ctx.style.body_char_width)
	lines := gui_wrap_line_count(ctx, text, wrap_width)
	bounds := gui_next_rect(ctx, height = f32(lines) * ctx.style.body_line_height)
	gui_scissor_begin(ctx, bounds)
	gui_text_wrapped_at(ctx, {bounds.x + ctx.style.spacing_1, bounds.y + max((ctx.style.body_line_height - ctx.style.body_text_height) * 0.5, 0)}, text, wrap_width, color)
	gui_scissor_end(ctx)
}

gui_spacer :: proc(ctx: ^Gui_Context, height: f32) {
	_ = gui_next_rect(ctx, height = height)
}

gui_disabled_button :: proc(ctx: ^Gui_Context, label: string) {
	bounds := gui_next_rect(ctx, width = gui_button_content_width(ctx, label), stretch_cross_axis = false)
	color := ctx.style.control_disabled
	text_color := Color{ctx.style.text.r * 0.55, ctx.style.text.g * 0.55, ctx.style.text.b * 0.55, 0.95}
	gui_round_rect(ctx, bounds, ctx.style.radius_control, color)
	gui_round_stroke(ctx, bounds, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)
	gui_text(ctx, {bounds.x + ctx.style.control_padding * 1.5, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, label, text_color)
}

gui_button :: gui_button_keyed

gui_button_keyed :: proc(ctx: ^Gui_Context, label, key: string) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx, width = gui_button_content_width(ctx, label), stretch_cross_axis = false)
	return gui_button_at(ctx, id, bounds, label, true)
}

gui_button_content_width :: proc(ctx: ^Gui_Context, label: string) -> f32 {
	text_w := gui_text_width(ctx, label)
	return max(text_w + ctx.style.control_padding * 3, ctx.style.row_height)
}

gui_button_at :: proc(ctx: ^Gui_Context, id: Gui_Id, bounds: Rect, label: string, enabled: bool, pointer_focus := true) -> bool {
	control := gui_control(ctx, id, bounds, enabled, true, pointer_focus)

	color := ctx.style.control
	border := ctx.style.panel_border
	stroke_width := ctx.style.border_width
	text_color := enabled ? ctx.style.text : ctx.style.text_muted
	if !enabled {
		color = ctx.style.control_disabled
	} else if ctx.active == id {
		color = gui_lerp_color(ctx.style.control_hot, ctx.style.accent, 0.18)
		border = gui_apply_opacity(ctx.style.accent, 0.62)
		stroke_width = max(ctx.style.border_width * 2, 2)
	} else if ctx.hot == id || control.focused {
		color = ctx.style.control_hot
		border = control.focused ? gui_apply_opacity(ctx.style.accent, 0.78) : gui_apply_opacity(ctx.style.text, 0.46)
		if control.focused {
			stroke_width = max(ctx.style.border_width * 2, 2)
		}
	}
	if enabled && ctx.input.delta_time > 0 {
		hot_t := gui_animate_value(ctx, id, (ctx.hot == id || ctx.active == id) ? f32(1) : f32(0), 10)
		target := ctx.active == id ? gui_lerp_color(ctx.style.control_hot, ctx.style.accent, 0.18) : ctx.style.control_hot
		color = gui_lerp_color(ctx.style.control, target, hot_t)
	}

	gui_shadow(ctx, bounds, ctx.style.radius_control, ctx.style.shadow_offset, ctx.style.shadow_blur * 0.42, {0, 0, 0, enabled ? f32(0.18) : f32(0.08)})
	gui_round_rect(ctx, bounds, ctx.style.radius_control, color)
	gui_round_stroke(ctx, bounds, ctx.style.radius_control, border, stroke_width)
	if ctx.focused == id {
		gui_focus_ring(ctx, bounds)
	}
	inset := ctx.style.control_padding
	if len(label) > 0 {
		text_rect := gui_inset(bounds, inset)
		gui_scissor_begin(ctx, text_rect)
		gui_text_centered(ctx, text_rect, label, text_color)
		gui_scissor_end(ctx)
	}

	return control.activated || (enabled && control.hovered && ctx.active == id && ctx.input.mouse_released)
}

gui_card_button :: gui_card_button_keyed

gui_card_button_keyed :: proc(ctx: ^Gui_Context, bounds: Rect, title, key, subtitle: string, enabled := true) -> bool {
	id := gui_make_id(ctx, key)
	clicked := gui_button_at(ctx, id, bounds, "", enabled)
	title_color := enabled ? ctx.style.text : Color{ctx.style.text.r * 0.55, ctx.style.text.g * 0.55, ctx.style.text.b * 0.55, 1}
	subtitle_color := enabled ? ctx.style.text_muted : Color{0.45, 0.48, 0.52, 1}
	text_rect := gui_inset(bounds, ctx.style.spacing_2)
	title_y := bounds.y + ctx.style.spacing_2
	gui_text_clipped(ctx, text_rect, {bounds.x + 16, title_y}, title, title_color)
	gui_text_clipped(ctx, text_rect, {bounds.x + 16, title_y + ctx.style.body_line_height}, subtitle, subtitle_color)
	return clicked
}

gui_toggle :: gui_toggle_keyed

gui_toggle_keyed :: proc(ctx: ^Gui_Context, label, key: string, value: ^bool) -> bool {
	return gui_switch_keyed(ctx, label, key, value)
}

gui_number_drag_f32 :: gui_number_drag_f32_keyed

gui_number_drag_f32_keyed :: proc(ctx: ^Gui_Context, label, key: string, value: ^f32, speed, min, max_value: f32, enabled := true) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	if !enabled {
		if ctx.focused == id {
			ctx.focused = GUI_ID_NONE
		}
		if ctx.active == id {
			ctx.active = GUI_ID_NONE
		}
		if ctx.text_edit_id == id {
			ctx.text_edit_id = GUI_ID_NONE
			ctx.text_edit_len = 0
			ctx.number_edit_snapshot_id = GUI_ID_NONE
		}
		gui_round_rect(ctx, bounds, ctx.style.radius_control, ctx.style.control_disabled)
		gui_round_stroke(ctx, bounds, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)
		gui_text_clipped(ctx, gui_inset(bounds, ctx.style.control_padding), {bounds.x + ctx.style.control_padding * 1.5, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, label, ctx.style.text_muted)
		return false
	}
	control := gui_control(ctx, id, bounds, true)
	changed := false
	editing := ctx.text_edit_id == id
	ctx.wants_text_input = ctx.wants_text_input ||
		(control.focused && (!ctx.controller_explicit_activation || ctx.focus_edit_id == id || editing))
	// Controllers engage numeric fields as value editors: the D-pad adjusts
	// the value, Accept commits, and Back restores the snapshot. Text editing
	// is reserved for keyboard input so Accept cannot strand a controller user
	// in a caret editor with no way to enter digits.
	start_edit := control.focused && !editing && !ctx.controller_explicit_activation && gui_number_edit_wants_text(ctx)
	if ctx.controller_explicit_activation {
		_ = gui_update_focus_edit(ctx, id, control.focused)
	} else {
		if control.focused && !editing && ctx.input.key_space {
			gui_focus_edit_begin(ctx, id)
		} else if !control.focused {
			gui_focus_edit_end(ctx, id)
		}
	}
	gui_controller_edit_f32(ctx, id, value)
	adjust_scale := gui_fine_adjust_scale(ctx)

	if ctx.active == id && ctx.input.mouse_down && !editing {
		delta := (ctx.input.wheel_delta * speed + ctx.mouse_delta.x * speed * 0.1) * adjust_scale
		value^ += delta
		if value^ < min do value^ = min
		if value^ > max_value do value^ = max_value
		changed = delta != 0
		if changed && ctx.text_edit_id == id {
			gui_number_edit_set_value(ctx, value^)
			ctx.text_edit_caret = ctx.text_edit_len
			ctx.text_edit_anchor = 0
		}
	}
	// Value edits advance on the navigation action's initial press and repeat,
	// not every frame an axis is held. This keeps an activated control's rate
	// stable across refresh rates and gives the user time to make fine edits.
	nav_x, nav_y := gui_focused_nav_pressed(ctx, id)
	if !editing && !start_edit && (nav_x != 0 || nav_y != 0) {
		value^ += (nav_x - nav_y) * speed * adjust_scale
		if value^ < min do value^ = min
		if value^ > max_value do value^ = max_value
		changed = true
		if ctx.text_edit_id == id {
			gui_number_edit_set_value(ctx, value^)
			ctx.text_edit_caret = ctx.text_edit_len
			ctx.text_edit_anchor = 0
		}
	}
	if control.focused && (editing || start_edit) {
		if start_edit && ctx.input.accept {
			if !ctx.controller_explicit_activation {
				gui_focus_edit_end(ctx, id)
			}
			gui_number_edit_begin(ctx, id, value^)
		} else {
			if editing {
				text_pos := Vec2{bounds.x + ctx.style.control_padding * 1.5, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}
				gui_text_edit_handle_mouse(ctx, id, ctx.text_edit_buffer[:], ctx.text_edit_len, bounds, text_pos)
			}
			edit_changed := gui_number_edit_f32(ctx, id, value, min, max_value)
			changed = changed || edit_changed
		}
	} else if ctx.text_edit_id == id {
		ctx.text_edit_id = GUI_ID_NONE
		ctx.text_edit_len = 0
		ctx.number_edit_snapshot_id = GUI_ID_NONE
	}

	gui_text_field_chrome(ctx, bounds, ctx.active == id || ctx.focus_edit_id == id, ctx.hot == id, control.focused)
	gui_focus_or_edit_ring(ctx, id, bounds)
	display_label := label
	if ctx.text_edit_id == id {
		display_label = string(ctx.text_edit_buffer[:ctx.text_edit_len])
	}
	if control.focused && ctx.text_edit_id == id {
		gui_text_edit_keep_caret_visible(ctx, ctx.text_edit_buffer[:], ctx.text_edit_len, gui_inset(bounds, ctx.style.control_padding * 2))
		gui_text_edit_draw(ctx, bounds, {bounds.x + ctx.style.control_padding * 1.5, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, ctx.text_edit_buffer[:], ctx.text_edit_len, label, true)
	} else {
		gui_text_clipped(ctx, gui_inset(bounds, ctx.style.control_padding), {bounds.x + ctx.style.control_padding * 1.5, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, display_label, ctx.style.text)
	}
	return changed
}

gui_slider_f32 :: gui_slider_f32_keyed

gui_slider_height :: proc(ctx: ^Gui_Context) -> f32 {
	return max(ctx.style.row_height, ctx.style.body_line_height + ctx.style.spacing_2 + ctx.style.control_padding * 2)
}

gui_slider_f32_keyed :: proc(ctx: ^Gui_Context, label, key: string, value: ^f32, min, max_value: f32) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx, height = gui_slider_height(ctx))
	changed := false
	t := gui_clamp01((value^ - min) / max(max_value - min, 0.000001))
	label_h := ctx.style.body_line_height
	handle_radius := max(ctx.style.control_padding, f32(8))
	track_inset := max(handle_radius, ctx.style.spacing_2)
	track_h := max(ctx.style.border_width * 3, f32(6))
	track := Rect{bounds.x + track_inset, bounds.y + label_h + ctx.style.spacing_2, max(bounds.w - track_inset * 2, 1), track_h}
	handle := Vec2{track.x + track.w * t, track.y + track.h * 0.5}

	if gui_drag_handle_region(ctx, id, bounds, handle, 12) {
		pointer_scale := gui_pointer_fine_adjust_scale(ctx, id)
		if pointer_scale < 1 {
			value^ += ctx.mouse_delta.x / max(track.w, 1) * (max_value - min) * pointer_scale
			if value^ < min do value^ = min
			if value^ > max_value do value^ = max_value
		} else {
			t = (ctx.input.mouse_pos.x - track.x) / max(track.w, 1)
			t = gui_clamp01(t)
			value^ = min + (max_value - min) * t
		}
		changed = true
	}
	_ = gui_update_focus_edit(ctx, id, ctx.focused == id)
	gui_controller_edit_f32(ctx, id, value)
	nav_x, nav_y := gui_focused_nav_pressed(ctx, id)
	if nav_x != 0 || nav_y != 0 {
		step := (max_value - min) * 0.05 * gui_fine_adjust_scale(ctx)
		value^ += (nav_x - nav_y) * step
		if value^ < min do value^ = min
		if value^ > max_value do value^ = max_value
		changed = true
	}

	t = gui_clamp01((value^ - min) / max(max_value - min, 0.000001))
	fill := track
	fill.w *= t
	handle = Vec2{track.x + track.w * t, track.y + track.h * 0.5}

	gui_text_clipped(ctx, {bounds.x, bounds.y, bounds.w, label_h}, {bounds.x + ctx.style.spacing_1, bounds.y + max((label_h - ctx.style.body_text_height) * 0.5, 0)}, label, ctx.style.text_muted)
	gui_round_rect(ctx, track, track.h * 0.5, ctx.style.control)
	gui_round_rect(ctx, fill, track.h * 0.5, ctx.style.accent)
	gui_round_stroke(ctx, track, track.h * 0.5, ctx.style.panel_border, ctx.style.border_width)
	gui_draw_handle(ctx, handle, handle_radius)
	gui_focus_or_edit_ring(ctx, id, bounds)

	return changed
}

gui_text_input :: gui_text_input_keyed

gui_text_edit_begin :: proc(ctx: ^Gui_Context, id: Gui_Id, length: int) {
	if ctx.text_edit_id != id {
		ctx.text_edit_id = id
		ctx.text_edit_caret = length
		ctx.text_edit_anchor = length
		ctx.text_edit_scroll_x = 0
		ctx.text_edit_blink = 0
		ctx.text_edit_selecting = false
	}
}

gui_text_edit_clamp :: proc(ctx: ^Gui_Context, length: int) {
	ctx.text_edit_caret = gui_utf8_clamp_index(ctx.text_edit_caret, length)
	ctx.text_edit_anchor = gui_utf8_clamp_index(ctx.text_edit_anchor, length)
}

gui_text_edit_has_selection :: proc(ctx: ^Gui_Context) -> bool {
	return ctx.text_edit_caret != ctx.text_edit_anchor
}

gui_text_edit_selection :: proc(ctx: ^Gui_Context) -> (start, end: int) {
	if ctx.text_edit_caret < ctx.text_edit_anchor {
		return ctx.text_edit_caret, ctx.text_edit_anchor
	}
	return ctx.text_edit_anchor, ctx.text_edit_caret
}

gui_text_edit_clear_selection :: proc(ctx: ^Gui_Context) {
	ctx.text_edit_anchor = ctx.text_edit_caret
}

gui_text_edit_delete_range :: proc(buffer: []u8, length: ^int, start, end: int) -> bool {
	range_start := max(min(start, length^), 0)
	range_end := max(min(end, length^), range_start)
	if range_start >= range_end {
		return false
	}
	count := length^ - range_end
	for i in 0 ..< count {
		buffer[range_start + i] = buffer[range_end + i]
	}
	length^ -= range_end - range_start
	if length^ < len(buffer) {
		buffer[length^] = 0
	}
	return true
}

gui_text_edit_delete_selection :: proc(ctx: ^Gui_Context, buffer: []u8, length: ^int) -> bool {
	if !gui_text_edit_has_selection(ctx) {
		return false
	}
	start, end := gui_text_edit_selection(ctx)
	if gui_text_edit_delete_range(buffer, length, start, end) {
		ctx.text_edit_caret = start
		ctx.text_edit_anchor = start
		return true
	}
	return false
}

gui_text_edit_insert_bytes :: proc(ctx: ^Gui_Context, buffer: []u8, length: ^int, bytes: []u8, numeric := false) -> bool {
	if len(buffer) == 0 || len(bytes) == 0 {
		return false
	}
	changed := gui_text_edit_delete_selection(ctx, buffer, length)
	for ch in bytes {
		if ch < 32 {
			continue
		}
		if numeric && !gui_number_edit_accepts_char(ch) {
			continue
		}
		if length^ >= len(buffer) {
			break
		}
		for i := length^; i > ctx.text_edit_caret; i -= 1 {
			buffer[i] = buffer[i - 1]
		}
		buffer[ctx.text_edit_caret] = ch
		length^ += 1
		ctx.text_edit_caret += 1
		ctx.text_edit_anchor = ctx.text_edit_caret
		changed = true
	}
	if length^ < len(buffer) {
		buffer[length^] = 0
	}
	return changed
}

gui_text_edit_set_clipboard :: proc(ctx: ^Gui_Context, bytes: []u8) {
	ctx.clipboard_set_len = min(len(bytes), len(ctx.clipboard_set_text) - 1)
	for i in 0 ..< ctx.clipboard_set_len {
		ctx.clipboard_set_text[i] = bytes[i]
	}
	if len(ctx.clipboard_set_text) > 0 {
		ctx.clipboard_set_text[ctx.clipboard_set_len] = 0
	}
	ctx.clipboard_set_pending = ctx.clipboard_set_len > 0
}

gui_text_edit_copy_selection :: proc(ctx: ^Gui_Context, buffer: []u8) {
	if !gui_text_edit_has_selection(ctx) {
		return
	}
	start, end := gui_text_edit_selection(ctx)
	gui_text_edit_set_clipboard(ctx, buffer[start:end])
}

gui_text_edit_move_caret :: proc(ctx: ^Gui_Context, length: int, caret: int, extend: bool) {
	ctx.text_edit_caret = gui_utf8_clamp_index(caret, length)
	if !extend {
		ctx.text_edit_anchor = ctx.text_edit_caret
	}
	ctx.text_edit_blink = 0
}

gui_text_edit_is_word_char :: proc(ch: u8) -> bool {
	switch ch {
	case 'a'..='z', 'A'..='Z', '0'..='9', '_':
		return true
	}
	return false
}

gui_text_edit_prev_word_index :: proc(bytes: []u8, index: int) -> int {
	i := gui_utf8_clamp_index(index, len(bytes))
	for i > 0 {
		prev := gui_utf8_prev_index(bytes, i)
		if gui_text_edit_is_word_char(bytes[prev]) {
			break
		}
		i = prev
	}
	for i > 0 {
		prev := gui_utf8_prev_index(bytes, i)
		if !gui_text_edit_is_word_char(bytes[prev]) {
			break
		}
		i = prev
	}
	return i
}

gui_text_edit_next_word_index :: proc(bytes: []u8, index: int) -> int {
	i := gui_utf8_clamp_index(index, len(bytes))
	for i < len(bytes) {
		if gui_text_edit_is_word_char(bytes[i]) {
			break
		}
		i = gui_utf8_next_index(bytes, i)
	}
	for i < len(bytes) {
		if !gui_text_edit_is_word_char(bytes[i]) {
			break
		}
		i = gui_utf8_next_index(bytes, i)
	}
	return i
}

gui_text_edit_process :: proc(ctx: ^Gui_Context, id: Gui_Id, buffer: []u8, length: ^int, numeric := false) -> bool {
	gui_text_edit_begin(ctx, id, length^)
	gui_text_edit_clamp(ctx, length^)
	changed := false
	modifier := ctx.input.key_ctrl || ctx.input.key_super

	if ctx.input.back || ctx.input.accept {
		ctx.focused = GUI_ID_NONE
		ctx.text_edit_selecting = false
		return false
	}

	if modifier && ctx.input.key_a {
		ctx.text_edit_caret = length^
		ctx.text_edit_anchor = 0
		ctx.text_edit_blink = 0
	}
	if modifier && ctx.input.key_c {
		gui_text_edit_copy_selection(ctx, buffer[:length^])
	}
	if modifier && ctx.input.key_x {
		gui_text_edit_copy_selection(ctx, buffer[:length^])
		if gui_text_edit_delete_selection(ctx, buffer, length) {
			changed = true
		}
	}
	if modifier && ctx.input.key_v && ctx.input.clipboard_paste_len > 0 {
		changed = gui_text_edit_insert_bytes(ctx, buffer, length, ctx.input.clipboard_paste[:ctx.input.clipboard_paste_len], numeric) || changed
	}

	if ctx.input.key_home {
		gui_text_edit_move_caret(ctx, length^, 0, ctx.input.key_shift)
	}
	if ctx.input.key_end {
		gui_text_edit_move_caret(ctx, length^, length^, ctx.input.key_shift)
	}
	if ctx.input.key_left {
		if ctx.input.key_super {
			gui_text_edit_move_caret(ctx, length^, 0, ctx.input.key_shift)
		} else if ctx.input.key_ctrl {
			gui_text_edit_move_caret(ctx, length^, gui_text_edit_prev_word_index(buffer[:length^], ctx.text_edit_caret), ctx.input.key_shift)
		} else if gui_text_edit_has_selection(ctx) && !ctx.input.key_shift {
			start, _ := gui_text_edit_selection(ctx)
			gui_text_edit_move_caret(ctx, length^, start, false)
		} else {
			gui_text_edit_move_caret(ctx, length^, gui_utf8_prev_index(buffer[:length^], ctx.text_edit_caret), ctx.input.key_shift)
		}
	}
	if ctx.input.key_right {
		if ctx.input.key_super {
			gui_text_edit_move_caret(ctx, length^, length^, ctx.input.key_shift)
		} else if ctx.input.key_ctrl {
			gui_text_edit_move_caret(ctx, length^, gui_text_edit_next_word_index(buffer[:length^], ctx.text_edit_caret), ctx.input.key_shift)
		} else if gui_text_edit_has_selection(ctx) && !ctx.input.key_shift {
			_, end := gui_text_edit_selection(ctx)
			gui_text_edit_move_caret(ctx, length^, end, false)
		} else {
			gui_text_edit_move_caret(ctx, length^, gui_utf8_next_index(buffer[:length^], ctx.text_edit_caret), ctx.input.key_shift)
		}
	}

	if ctx.input.key_backspace {
		if gui_text_edit_delete_selection(ctx, buffer, length) {
			changed = true
		} else if ctx.input.key_super && ctx.text_edit_caret > 0 {
			if gui_text_edit_delete_range(buffer, length, 0, ctx.text_edit_caret) {
				ctx.text_edit_caret = 0
				ctx.text_edit_anchor = 0
				changed = true
			}
		} else if ctx.input.key_ctrl && ctx.text_edit_caret > 0 {
			prev := gui_text_edit_prev_word_index(buffer[:length^], ctx.text_edit_caret)
			if gui_text_edit_delete_range(buffer, length, prev, ctx.text_edit_caret) {
				ctx.text_edit_caret = prev
				ctx.text_edit_anchor = prev
				changed = true
			}
		} else if ctx.text_edit_caret > 0 {
			prev := gui_utf8_prev_index(buffer[:length^], ctx.text_edit_caret)
			if gui_text_edit_delete_range(buffer, length, prev, ctx.text_edit_caret) {
				ctx.text_edit_caret = prev
				ctx.text_edit_anchor = prev
				changed = true
			}
		}
	}
	if ctx.input.key_delete {
		if gui_text_edit_delete_selection(ctx, buffer, length) {
			changed = true
		} else if ctx.input.key_super && ctx.text_edit_caret < length^ {
			if gui_text_edit_delete_range(buffer, length, ctx.text_edit_caret, length^) {
				ctx.text_edit_anchor = ctx.text_edit_caret
				changed = true
			}
		} else if ctx.input.key_ctrl && ctx.text_edit_caret < length^ {
			next := gui_text_edit_next_word_index(buffer[:length^], ctx.text_edit_caret)
			if gui_text_edit_delete_range(buffer, length, ctx.text_edit_caret, next) {
				ctx.text_edit_anchor = ctx.text_edit_caret
				changed = true
			}
		} else if ctx.text_edit_caret < length^ {
			next := gui_utf8_next_index(buffer[:length^], ctx.text_edit_caret)
			if gui_text_edit_delete_range(buffer, length, ctx.text_edit_caret, next) {
				ctx.text_edit_anchor = ctx.text_edit_caret
				changed = true
			}
		}
	}
	if ctx.input.text_input_len > 0 {
		changed = gui_text_edit_insert_bytes(ctx, buffer, length, ctx.input.text_input[:ctx.input.text_input_len], numeric) || changed
	}

	gui_text_edit_clamp(ctx, length^)
	return changed
}

gui_text_edit_hit_test :: proc(ctx: ^Gui_Context, buffer: []u8, x: f32) -> int {
	best := 0
	best_distance := abs(x)
	for i in 0 ..= len(buffer) {
		if i > 0 && gui_utf8_is_continuation(buffer[i - 1]) {
			continue
		}
		width := gui_text_width(ctx, string(buffer[:i]))
		distance := abs(width - x)
		if distance < best_distance {
			best = i
			best_distance = distance
		}
	}
	return best
}

gui_text_edit_handle_mouse :: proc(ctx: ^Gui_Context, id: Gui_Id, buffer: []u8, length: int, bounds: Rect, text_pos: Vec2) {
	if ctx.input.mouse_pressed && gui_mouse_contains(ctx, bounds) {
		local_x := ctx.input.mouse_pos.x - text_pos.x + ctx.text_edit_scroll_x
		ctx.text_edit_caret = gui_text_edit_hit_test(ctx, buffer[:length], local_x)
		if !ctx.input.key_shift {
			ctx.text_edit_anchor = ctx.text_edit_caret
		}
		ctx.text_edit_selecting = true
		ctx.text_edit_blink = 0
	} else if ctx.input.mouse_down && ctx.active == id && ctx.text_edit_selecting {
		local_x := ctx.input.mouse_pos.x - text_pos.x + ctx.text_edit_scroll_x
		ctx.text_edit_caret = gui_text_edit_hit_test(ctx, buffer[:length], local_x)
		ctx.text_edit_blink = 0
	}
	if ctx.input.mouse_released {
		ctx.text_edit_selecting = false
	}
}

gui_text_edit_keep_caret_visible :: proc(ctx: ^Gui_Context, buffer: []u8, length: int, rect: Rect) {
	caret_x := gui_text_width(ctx, string(buffer[:ctx.text_edit_caret]))
	padding := f32(8)
	if caret_x - ctx.text_edit_scroll_x > rect.w - padding {
		ctx.text_edit_scroll_x = caret_x - rect.w + padding
	}
	if caret_x - ctx.text_edit_scroll_x < 0 {
		ctx.text_edit_scroll_x = caret_x
	}
	ctx.text_edit_scroll_x = max(ctx.text_edit_scroll_x, 0)
}

gui_text_edit_draw :: proc(ctx: ^Gui_Context, rect: Rect, text_pos: Vec2, buffer: []u8, length: int, placeholder: string, focused: bool, trailing_inset := f32(0)) {
	display := string(buffer[:length])
	text_color := ctx.style.text
	if length == 0 {
		display = placeholder
		text_color = ctx.style.text_muted
	}
	clip := gui_inset_edges(rect, {left = ctx.style.control_padding, top = ctx.style.control_padding, right = ctx.style.control_padding + trailing_inset, bottom = ctx.style.control_padding})
	draw_pos := Vec2{text_pos.x - ctx.text_edit_scroll_x, text_pos.y}
	if focused && length > 0 && gui_text_edit_has_selection(ctx) {
		start, end := gui_text_edit_selection(ctx)
		x0 := draw_pos.x + gui_text_width(ctx, string(buffer[:start]))
		x1 := draw_pos.x + gui_text_width(ctx, string(buffer[:end]))
		gui_rect(ctx, {x0, rect.y + ctx.style.control_padding, max(x1 - x0, 1), max(rect.h - ctx.style.control_padding * 2, 1)}, {ctx.style.accent.r, ctx.style.accent.g, ctx.style.accent.b, 0.32})
	}
	gui_text_clipped(ctx, clip, draw_pos, display, text_color)
	if focused {
		ctx.text_edit_blink += ctx.input.delta_time
		if ctx.text_edit_blink > 1.0 {
			ctx.text_edit_blink -= 1.0
		}
		if ctx.text_edit_blink < 0.55 {
			caret_x := draw_pos.x + gui_text_width(ctx, string(buffer[:ctx.text_edit_caret]))
			caret_w := max(ctx.style.border_width * 2, 2)
			caret_h := max(ctx.style.body_text_height, rect.h - ctx.style.control_padding * 2)
			caret_y := rect.y + max((rect.h - caret_h) * 0.5, 0)
			gui_rect(ctx, {caret_x, caret_y, caret_w, caret_h}, ctx.style.accent)
		}
	}
}

gui_text_field_chrome :: proc(ctx: ^Gui_Context, bounds: Rect, active, hot, focused: bool) {
	color := ctx.style.control
	border := ctx.style.panel_border
	stroke_width := ctx.style.border_width
	if focused {
		color = gui_lerp_color(ctx.style.control, ctx.style.control_hot, active ? f32(0.45) : f32(0.22))
		border = gui_apply_opacity(ctx.style.accent, 0.78)
		stroke_width = max(ctx.style.border_width * 2, 2)
	} else if active {
		color = ctx.style.control_hot
	} else if hot {
		color = ctx.style.control_hot
	}
	gui_round_rect(ctx, bounds, ctx.style.radius_control, color)
	gui_round_stroke(ctx, bounds, ctx.style.radius_control, border, stroke_width)
}

gui_text_input_clear_rect :: proc(ctx: ^Gui_Context, bounds: Rect) -> Rect {
	size := min(max(bounds.h * 0.45, f32(18)), max(bounds.h - ctx.style.control_padding * 2, f32(12)))
	x := bounds.x + bounds.w - ctx.style.control_padding * 1.5 - size
	y := bounds.y + (bounds.h - size) * 0.5
	return {x, y, size, size}
}

gui_text_input_clear_hit_rect :: proc(ctx: ^Gui_Context, bounds: Rect) -> Rect {
	size := min(max(bounds.h * 0.72, f32(28)), bounds.h)
	x := bounds.x + bounds.w - ctx.style.control_padding - size
	y := bounds.y + (bounds.h - size) * 0.5
	return {x, y, size, size}
}

gui_text_input_body_rect :: proc(bounds, clear_hit: Rect, clear_visible: bool) -> Rect {
	if !clear_visible {
		return bounds
	}
	return {bounds.x, bounds.y, max(clear_hit.x - bounds.x, 0), bounds.h}
}

gui_text_input_draw_clear_button :: proc(ctx: ^Gui_Context, rect: Rect, hot, active: bool) {
	fill := Color{1, 1, 1, 0.24}
	if active {
		fill = Color{1, 1, 1, 0.36}
	} else if hot {
		fill = Color{1, 1, 1, 0.31}
	}
	gui_ellipse(ctx, rect, fill)
	center := Vec2{rect.x + rect.w * 0.5, rect.y + rect.h * 0.5}
	size := rect.w * 0.22
	line_color := Color{0.02, 0.025, 0.035, 0.82}
	gui_line(ctx, {center.x - size, center.y - size}, {center.x + size, center.y + size}, line_color, max(ctx.style.border_width * 1.6, 2))
	gui_line(ctx, {center.x + size, center.y - size}, {center.x - size, center.y + size}, line_color, max(ctx.style.border_width * 1.6, 2))
}

gui_text_input_keyed :: proc(ctx: ^Gui_Context, label, key: string, buffer: []u8, length: ^int) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	control := gui_control(ctx, id, bounds, true)
	editing := control.focused
	if ctx.controller_explicit_activation {
		editing = gui_update_focus_edit(ctx, id, control.focused)
	}
	gui_controller_edit_text(ctx, id, buffer, length)
	changed := false

	if length^ < 0 {
		length^ = 0
	}
	if length^ > len(buffer) {
		length^ = len(buffer)
	}

	clear_visual := gui_text_input_clear_rect(ctx, bounds)
	clear_hit := gui_text_input_clear_hit_rect(ctx, bounds)
	clear_visible := length^ > 0 && (control.focused || control.hovered)
	clear_hot := clear_visible && gui_mouse_contains(ctx, clear_hit)
	clear_active := clear_hot && ctx.active == id && ctx.input.mouse_down
	clear_clicked := clear_hot && ctx.active == id && ctx.input.mouse_released
	body := gui_text_input_body_rect(bounds, clear_hit, clear_visible)
	text_pos := Vec2{bounds.x + ctx.style.control_padding * 1.5, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}

	if editing {
		ctx.wants_text_input = true
		gui_text_edit_begin(ctx, id, length^)
		if clear_clicked {
			length^ = 0
			if len(buffer) > 0 {
				buffer[0] = 0
			}
			ctx.text_edit_caret = 0
			ctx.text_edit_anchor = 0
			ctx.text_edit_scroll_x = 0
			ctx.text_edit_blink = 0
			changed = true
			clear_visible = false
		} else if !(ctx.controller_explicit_activation && gui_accept_pressed(ctx)) {
			gui_text_edit_handle_mouse(ctx, id, buffer, length^, body, text_pos)
			changed = gui_text_edit_process(ctx, id, buffer, length) || changed
		}
		trailing_inset := clear_visible ? max(bounds.x + bounds.w - clear_hit.x, 0) : f32(0)
		edit_view := gui_inset_edges(bounds, {left = ctx.style.control_padding * 2, top = ctx.style.control_padding * 2, right = ctx.style.control_padding * 2 + trailing_inset, bottom = ctx.style.control_padding * 2})
		gui_text_edit_keep_caret_visible(ctx, buffer, length^, edit_view)
	} else if ctx.text_edit_id == id {
		ctx.text_edit_id = GUI_ID_NONE
		ctx.text_edit_selecting = false
	}

	gui_text_field_chrome(ctx, bounds, ctx.active == id || editing, ctx.hot == id, control.focused)
	gui_focus_or_edit_ring(ctx, id, bounds)
	trailing_inset := clear_visible ? max(bounds.x + bounds.w - clear_hit.x, 0) : f32(0)
	gui_text_edit_draw(ctx, bounds, text_pos, buffer, length^, label, editing, trailing_inset)
	if clear_visible {
		gui_text_input_draw_clear_button(ctx, clear_visual, clear_hot, clear_active)
	}
	return changed
}

gui_selector :: gui_selector_keyed

gui_selector_keyed :: proc(ctx: ^Gui_Context, label, key: string, current: ^int, options: []string) -> bool {
	if len(options) == 0 {
		return false
	}
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	current^ = max(min(current^, len(options) - 1), 0)
	arrow_w := min(max(bounds.h, f32(35)), bounds.w * 0.22)
	left := Rect{bounds.x, bounds.y, arrow_w, bounds.h}
	right := Rect{bounds.x + bounds.w - arrow_w, bounds.y, arrow_w, bounds.h}
	center := Rect{bounds.x + arrow_w, bounds.y, max(bounds.w - arrow_w * 2, 0), bounds.h}
	changed := false

	// The arrows are pointer affordances. Keeping them out of controller focus
	// makes the selector one coherent control: confirm to edit, D-pad to change.
	if gui_stepper_button_at(ctx, gui_id_child(id, "left"), left, -1, true, false) {
		ctx.focused = id
		current^ = (current^ - 1 + len(options)) % len(options)
		changed = true
	}
	gui_tooltip(ctx, left, "Previous option")
	center_control := gui_control(ctx, id, center, true)
	if center_control.hovered && ctx.active == id && ctx.input.mouse_released {
		current^ = (current^ + 1) % len(options)
		changed = true
	}
	if gui_stepper_button_at(ctx, gui_id_child(id, "right"), right, 1, true, false) {
		ctx.focused = id
		current^ = (current^ + 1) % len(options)
		changed = true
	}
	gui_tooltip(ctx, right, "Next option")
	editing := gui_update_focus_edit(ctx, id, ctx.focused == id)
	nav_x, nav_y: f32
	if editing {
		nav_x, nav_y = gui_focused_nav_pressed(ctx, id)
	} else if !ctx.controller_explicit_activation && center_control.focused && (ctx.input.nav_pressed_x != 0 || ctx.input.nav_pressed_y != 0) {
		gui_focus_edit_begin(ctx, id)
		ctx.focus_moved = true
		nav_x = ctx.input.nav_pressed_x
		nav_y = ctx.input.nav_pressed_y
	}
	// Capture before applying the first keyboard navigation step. Keyboard
	// arrows may engage a selector and change it in the same frame.
	gui_controller_edit_int(ctx, id, current)
	if nav_x != 0 || nav_y != 0 {
		delta := int(nav_x + nav_y)
		current^ = (current^ + delta + len(options)) % len(options)
		changed = true
	}
	center_fill := ctx.style.control
	if ctx.hot == id || ctx.focused == id {
		center_fill = {1, 1, 1, 0.15}
	}
	gui_rect(ctx, center, center_fill)
	gui_stroke(ctx, {center.x, center.y, center.w, center.h}, ctx.style.panel_border)
	text_y := center.y + max((center.h - ctx.style.body_text_height) * 0.5, 0)
	gui_text_clipped(ctx, gui_inset(center, 8), {center.x + 12, text_y}, label, ctx.style.text)
	gui_focus_or_edit_ring(ctx, id, center)
	return changed
}

gui_checkbox :: gui_checkbox_keyed

gui_checkbox_keyed :: proc(ctx: ^Gui_Context, label, key: string, value: ^bool) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	box_size := min(bounds.h - 10, f32(26))
	box := Rect{bounds.x + 8, bounds.y + (bounds.h - box_size) * 0.5, box_size, box_size}
	clicked := gui_button_behavior(ctx, id, bounds, true)
	if clicked {
		value^ = !value^
	}

	fill := ctx.style.control
	border := ctx.style.panel_border
	if ctx.hot == id {
		fill = ctx.style.control_hot
	}
	if ctx.active == id {
		fill = ctx.style.control_active
	}
	if value^ {
		fill = ctx.style.accent
		border = gui_apply_opacity(ctx.style.accent, 0.88)
		if ctx.hot == id || ctx.focused == id {
			fill = gui_lighten(ctx.style.accent, 0.08)
		}
		if ctx.active == id {
			fill = gui_lighten(ctx.style.accent, 0.14)
		}
	}
	gui_round_rect(ctx, box, 4, fill)
	gui_round_stroke(ctx, box, 4, border, ctx.style.border_width)
	if value^ {
		check_color := Color{1, 1, 1, 0.95}
		gui_line(ctx, {box.x + box.w * 0.23, box.y + box.h * 0.52}, {box.x + box.w * 0.43, box.y + box.h * 0.72}, check_color, max(ctx.style.border_width * 2, 2))
		gui_line(ctx, {box.x + box.w * 0.43, box.y + box.h * 0.72}, {box.x + box.w * 0.78, box.y + box.h * 0.28}, check_color, max(ctx.style.border_width * 2, 2))
	}
	if ctx.focused == id {
		gui_focus_ring(ctx, bounds)
	}
	gui_text_clipped(ctx, gui_inset_edges(bounds, {left = box_size + 20, top = 0, right = 8, bottom = 0}), {bounds.x + box_size + 24, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, label, ctx.style.text)
	return clicked
}

gui_switch :: gui_switch_keyed

gui_switch_keyed :: proc(ctx: ^Gui_Context, label, key: string, value: ^bool) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	track_h := min(max(bounds.h * 0.64, f32(28)), max(bounds.h - ctx.style.control_padding, f32(24)))
	track_w := max(track_h * 1.85, f32(54))
	track := Rect{bounds.x + 8, bounds.y + (bounds.h - track_h) * 0.5, track_w, track_h}
	clicked := gui_button_behavior(ctx, id, bounds, true)
	gui_controller_edit_bool(ctx, id, value)
	if clicked {
		value^ = !value^
	}

	t := value^ ? f32(1) : f32(0)
	if ctx.input.delta_time > 0 {
		t = gui_animate_value(ctx, gui_id_child(id, "switch-track"), t, 14)
	}
	track_color := gui_lerp_color(ctx.style.control, ctx.style.accent, t)
	track_border := ctx.style.panel_border
	if value^ {
		track_border = gui_apply_opacity(ctx.style.accent, 0.78)
	}
	if ctx.hot == id {
		track_color = value^ ? gui_lighten(ctx.style.accent, 0.08) : ctx.style.control_hot
	}
	if ctx.active == id {
		track_color = value^ ? gui_lighten(ctx.style.accent, 0.14) : ctx.style.control_active
	}
	gui_round_rect(ctx, track, track.h * 0.5, track_color)
	gui_round_stroke(ctx, track, track.h * 0.5, track_border, ctx.style.border_width)
	knob_padding := max(track.h * 0.14, f32(4))
	knob_size := max(track.h - knob_padding * 2, f32(12))
	knob_x := track.x + knob_padding + (track.w - knob_size - knob_padding * 2) * t
	knob := Rect{knob_x, track.y + knob_padding, knob_size, knob_size}
	gui_shadow(ctx, knob, knob_size * 0.5, {0, max(ctx.style.border_width, f32(1))}, ctx.style.shadow_blur * 0.35, {0, 0, 0, 0.26})
	gui_ellipse(ctx, knob, Color{1, 1, 1, 0.96})
	gui_ellipse_stroke(ctx, knob, gui_apply_opacity(ctx.style.panel_border, 0.68), ctx.style.border_width)
	if ctx.focused == id {
		gui_focus_ring(ctx, bounds)
	}
	label_left := track.x + track.w + ctx.style.spacing_2
	gui_text_clipped(ctx, gui_inset_edges(bounds, {left = label_left - bounds.x, top = 0, right = 8, bottom = 0}), {label_left, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, label, ctx.style.text)
	return clicked
}

gui_radio :: gui_radio_keyed

gui_radio_keyed :: proc(ctx: ^Gui_Context, label, key: string, selected: bool) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	size := min(bounds.h - 10, f32(26))
	circle := Rect{bounds.x + 8, bounds.y + (bounds.h - size) * 0.5, size, size}
	clicked := gui_button_behavior(ctx, id, bounds, true)
	fill := ctx.style.control
	border := ctx.style.panel_border
	if ctx.hot == id {
		fill = ctx.style.control_hot
	}
	if ctx.active == id {
		fill = ctx.style.control_active
	}
	if selected {
		border = gui_apply_opacity(ctx.style.accent, 0.88)
		if ctx.hot == id || ctx.focused == id {
			fill = gui_lerp_color(ctx.style.control, ctx.style.control_hot, 0.55)
		}
	}
	gui_ellipse(ctx, circle, fill)
	gui_ellipse_stroke(ctx, circle, border, selected ? max(ctx.style.border_width * 2, 2) : ctx.style.border_width)
	if selected {
		gui_ellipse(ctx, gui_inset(circle, max(size * 0.30, f32(6))), ctx.style.accent)
	}
	if ctx.focused == id {
		gui_focus_ring(ctx, bounds)
	}
	gui_text_clipped(ctx, gui_inset_edges(bounds, {left = size + 20, top = 0, right = 8, bottom = 0}), {bounds.x + size + 24, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, label, ctx.style.text)
	return clicked
}

gui_radio_group :: gui_radio_group_keyed

gui_radio_group_keyed :: proc(ctx: ^Gui_Context, label, key: string, current: ^int, options: []string) -> bool {
	if len(options) == 0 {
		return false
	}
	changed := false
	gui_label(ctx, label)
	group_id := gui_make_id(ctx, key)
	start_index := ctx.layout_depth > 0 ? ctx.layout_stack[ctx.layout_depth - 1].cursor : ctx.next_cursor
	group_bounds := Rect{start_index.x, start_index.y, 0, 0}
	row_bounds: [64]Rect
	option_count := min(len(options), len(row_bounds))
	for option, i in options {
		id := gui_id_child_int(group_id, i)
		bounds := gui_next_rect(ctx)
		if i < option_count {
			row_bounds[i] = bounds
		}
		if i == 0 {
			group_bounds = bounds
		} else {
			right := max(group_bounds.x + group_bounds.w, bounds.x + bounds.w)
			bottom := max(group_bounds.y + group_bounds.h, bounds.y + bounds.h)
			group_bounds.x = min(group_bounds.x, bounds.x)
			group_bounds.y = min(group_bounds.y, bounds.y)
			group_bounds.w = right - group_bounds.x
			group_bounds.h = bottom - group_bounds.y
		}
		size := min(bounds.h - 10, f32(24))
		circle := Rect{bounds.x + 8, bounds.y + (bounds.h - size) * 0.5, size, size}
		hovered := gui_mouse_contains(ctx, bounds)
		if hovered {
			ctx.hot = id
			if ctx.input.mouse_pressed {
				ctx.active = group_id
				ctx.focused = group_id
			}
		}
		clicked := hovered && ctx.active == group_id && ctx.input.mouse_released
		if clicked && current^ != i {
			current^ = i
			ctx.focused = group_id
			changed = true
		}
		fill := ctx.style.control
		border := ctx.style.panel_border
		if ctx.hot == id {
			fill = ctx.style.control_hot
		}
		if ctx.active == group_id {
			fill = ctx.style.control_active
		}
		if current^ == i {
			border = gui_apply_opacity(ctx.style.accent, 0.88)
			if ctx.hot == id || ctx.focused == group_id {
				fill = gui_lerp_color(ctx.style.control, ctx.style.control_hot, 0.55)
			}
		}
		gui_ellipse(ctx, circle, fill)
		gui_ellipse_stroke(ctx, circle, border, current^ == i ? max(ctx.style.border_width * 2, 2) : ctx.style.border_width)
		if current^ == i {
			gui_ellipse(ctx, gui_inset(circle, max(size * 0.30, f32(6))), ctx.style.accent)
		}
		gui_text_clipped(ctx, gui_inset_edges(bounds, {left = size + 20, top = 0, right = 8, bottom = 0}), {bounds.x + size + 24, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, option, ctx.style.text)
	}
	group_control := gui_control(ctx, group_id, group_bounds, true)
	editing := group_control.focused
	if ctx.controller_explicit_activation {
		editing = gui_update_focus_edit(ctx, group_id, group_control.focused)
		gui_controller_edit_int(ctx, group_id, current)
	}
	if group_control.activated && !ctx.controller_explicit_activation {
		current^ = (current^ + 1) % len(options)
		changed = true
	}
	if editing {
		nav_delta := int(ctx.input.nav_pressed_x + ctx.input.nav_pressed_y)
		if nav_delta != 0 {
			next := (current^ + nav_delta + len(options)) % len(options)
			if next != current^ {
				current^ = next
				changed = true
			}
		}
	}
	if group_control.focused {
		focus_bounds := group_bounds
		if current^ >= 0 && current^ < option_count {
			focus_bounds = row_bounds[current^]
		}
		gui_focus_or_edit_ring(ctx, group_id, focus_bounds)
	}
	return changed
}

gui_area_slider_f32 :: gui_area_slider_f32_keyed

gui_area_slider_f32_keyed :: proc(ctx: ^Gui_Context, label, key: string, value: ^Vec2, min_value, max_value: Vec2) -> bool {
	bounds := gui_next_rect(ctx, height = 160)
	gui_text_clipped(ctx, {bounds.x, bounds.y, bounds.w, ctx.style.row_height}, {bounds.x + 2, bounds.y + 4}, label, ctx.style.text)
	area := Rect{bounds.x, bounds.y + ctx.style.row_height, bounds.w, max(bounds.h - ctx.style.row_height, 1)}
	return gui_area_slider_f32_at(ctx, gui_make_id(ctx, key), area, value, min_value, max_value)
}

gui_area_slider_f32_at :: proc(ctx: ^Gui_Context, id: Gui_Id, area: Rect, value: ^Vec2, min_value, max_value: Vec2) -> bool {
	changed := false
	normalized := gui_vec2_to_normalized(value^, min_value, max_value)
	handle := gui_normalized_to_rect_point(area, normalized)
	if gui_drag_handle_region(ctx, id, area, handle, 10) {
		normalized := gui_rect_point_to_normalized(area, ctx.input.mouse_pos)
		value^ = gui_vec2_from_normalized(normalized, min_value, max_value)
		changed = true
	}
	_ = gui_update_focus_edit(ctx, id, ctx.focused == id)
	gui_controller_edit_vec2(ctx, id, value)
	nav_x, nav_y := gui_focused_nav_pressed(ctx, id)
	if nav_x != 0 || nav_y != 0 {
		step := Vec2{(max_value.x - min_value.x) * 0.05, (max_value.y - min_value.y) * 0.05}
		value^.x += nav_x * step.x
		value^.y += nav_y * step.y
		if value^.x < min_value.x do value^.x = min_value.x
		if value^.x > max_value.x do value^.x = max_value.x
		if value^.y < min_value.y do value^.y = min_value.y
		if value^.y > max_value.y do value^.y = max_value.y
		changed = true
	}
	gui_draw_checker_grid(ctx, area)
	gui_round_stroke(ctx, area, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)
	normalized = gui_vec2_to_normalized(value^, min_value, max_value)
	handle = gui_normalized_to_rect_point(area, normalized)
	gui_draw_handle(ctx, handle, 7)
	gui_focus_or_edit_ring(ctx, id, area)
	return changed
}

gui_hue_wheel :: proc(ctx: ^Gui_Context, label, key: string, hsv: ^Hsv_Color) -> bool {
	bounds := gui_next_rect(ctx, height = 176)
	gui_text_clipped(ctx, {bounds.x, bounds.y, bounds.w, ctx.style.row_height}, {bounds.x + 2, bounds.y + 4}, label, ctx.style.text)
	wheel := Rect{bounds.x, bounds.y + ctx.style.row_height, bounds.w, bounds.h - ctx.style.row_height}
	return gui_hue_wheel_at(ctx, gui_make_id(ctx, key), wheel, hsv)
}

gui_hue_wheel_at :: proc(ctx: ^Gui_Context, id: Gui_Id, bounds: Rect, hsv: ^Hsv_Color) -> bool {
	gui_register_focusable(ctx, id, bounds)
	center := Vec2{bounds.x + bounds.w * 0.5, bounds.y + bounds.h * 0.5}
	outer := max(min(bounds.w, bounds.h) * 0.5 - 6, 1)
	inner := max(outer - 18, 1)
	segments := 48
	_ = segments
	gui_shader_rect(ctx, {center.x - outer, center.y - outer, outer * 2, outer * 2}, .Hue_Wheel, {inner / outer, 1, 0, hsv.a}, {1, 1, 1, 1})
	gui_ellipse_stroke(ctx, {center.x - outer, center.y - outer, outer * 2, outer * 2}, ctx.style.panel_border, 1)
	gui_ellipse_stroke(ctx, {center.x - inner, center.y - inner, inner * 2, inner * 2}, ctx.style.panel_border, 1)

	changed := false
	h := gui_wrap01(hsv.h)
	angle := h * GUI_TAU
	handle := Vec2{center.x + math.cos(angle) * ((inner + outer) * 0.5), center.y + math.sin(angle) * ((inner + outer) * 0.5)}
	delta := Vec2{ctx.input.mouse_pos.x - center.x, ctx.input.mouse_pos.y - center.y}
	dist := math.sqrt(delta.x * delta.x + delta.y * delta.y)
	hovered := gui_mouse_in_input_clip(ctx) && ((dist >= inner && dist <= outer) || gui_contains_circle(handle, ctx.input.mouse_pos, 10))
	if hovered {
		ctx.hot = id
		if ctx.input.mouse_pressed {
			ctx.active = id
			ctx.focused = id
		}
	}
	if ctx.active == id && ctx.input.mouse_down {
		hsv.h = gui_hue_from_delta(delta)
		changed = true
	}
	_ = gui_update_focus_edit(ctx, id, ctx.focused == id)
	gui_controller_edit_hsv(ctx, id, hsv)
	nav_x, nav_y := gui_focused_nav_pressed(ctx, id)
	if nav_x != 0 || nav_y != 0 {
		hsv.h = gui_wrap01(hsv.h + (nav_x - nav_y) * 0.01)
		changed = true
	}
	h = gui_wrap01(hsv.h)
	angle = h * GUI_TAU
	handle = Vec2{center.x + math.cos(angle) * ((inner + outer) * 0.5), center.y + math.sin(angle) * ((inner + outer) * 0.5)}
	gui_draw_handle(ctx, handle, 7)
	gui_focus_or_edit_ring(ctx, id, bounds)
	return changed
}

gui_sv_grid :: proc(ctx: ^Gui_Context, label, key: string, hsv: ^Hsv_Color) -> bool {
	bounds := gui_next_rect(ctx, height = 158)
	gui_text_clipped(ctx, {bounds.x, bounds.y, bounds.w, ctx.style.row_height}, {bounds.x + 2, bounds.y + 4}, label, ctx.style.text)
	grid := Rect{bounds.x, bounds.y + ctx.style.row_height, bounds.w, bounds.h - ctx.style.row_height}
	return gui_sv_grid_at(ctx, gui_make_id(ctx, key), grid, hsv)
}

gui_sv_grid_at :: proc(ctx: ^Gui_Context, id: Gui_Id, grid: Rect, hsv: ^Hsv_Color) -> bool {
	hue_color := gui_hsv_to_rgb({h = hsv.h, s = 1, v = 1, a = 1})
	hue_color.a = gui_clamp01(hsv.a)
	gui_shader_rect(ctx, grid, .SV_Grid, {}, hue_color)
	changed := false
	handle := gui_normalized_to_rect_point(grid, {gui_clamp01(hsv.s), 1 - gui_clamp01(hsv.v)})
	if gui_drag_handle_region(ctx, id, grid, handle, 10) {
		n := gui_rect_point_to_normalized(grid, ctx.input.mouse_pos)
		hsv.s = n.x
		hsv.v = 1 - n.y
		changed = true
	}
	_ = gui_update_focus_edit(ctx, id, ctx.focused == id)
	gui_controller_edit_hsv(ctx, id, hsv)
	nav_x, nav_y := gui_focused_nav_pressed(ctx, id)
	if nav_x != 0 || nav_y != 0 {
		hsv.s = gui_clamp01(hsv.s + nav_x * 0.05)
		hsv.v = gui_clamp01(hsv.v - nav_y * 0.05)
		changed = true
	}
	gui_round_stroke(ctx, grid, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)
	handle = gui_normalized_to_rect_point(grid, {gui_clamp01(hsv.s), 1 - gui_clamp01(hsv.v)})
	gui_draw_handle(ctx, handle, 7)
	gui_focus_or_edit_ring(ctx, id, grid)
	return changed
}

gui_alpha_slider :: proc(ctx: ^Gui_Context, label, key: string, hsv: ^Hsv_Color) -> bool {
	bounds := gui_next_rect(ctx, height = ctx.style.row_height)
	id := gui_make_id(ctx, key)
	changed := false
	track := gui_inset_edges(bounds, {left = 0, top = 8, right = 0, bottom = 8})
	base := gui_hsv_to_rgb({h = hsv.h, s = hsv.s, v = hsv.v, a = 1})
	gui_shader_rect(ctx, track, .Alpha_Ramp, {0, 0, 0, 1}, base)
	x := track.x + track.w * gui_clamp01(hsv.a)
	handle := Vec2{x, track.y + track.h * 0.5}
	if gui_drag_handle_region(ctx, id, bounds, handle, 10) {
		hsv.a = gui_rect_point_to_normalized(bounds, ctx.input.mouse_pos).x
		changed = true
	}
	_ = gui_update_focus_edit(ctx, id, ctx.focused == id)
	gui_controller_edit_hsv(ctx, id, hsv)
	nav_x, nav_y := gui_focused_nav_pressed(ctx, id)
	if nav_x != 0 || nav_y != 0 {
		hsv.a = gui_clamp01(hsv.a + (nav_x - nav_y) * 0.05)
		changed = true
	}
	gui_round_stroke(ctx, track, track.h * 0.5, ctx.style.panel_border, ctx.style.border_width)
	x = track.x + track.w * gui_clamp01(hsv.a)
	gui_draw_handle(ctx, {x, track.y + track.h * 0.5}, 6)
	gui_text_clipped(ctx, gui_inset(bounds, 6), {bounds.x + 10, bounds.y + 6}, label, ctx.style.text)
	gui_focus_or_edit_ring(ctx, id, bounds)
	return changed
}

gui_color_picker_hsv :: gui_color_picker_hsv_keyed

gui_color_picker_hsv_keyed :: proc(ctx: ^Gui_Context, label, key: string, hsv: ^Hsv_Color) -> bool {
	changed := false
	gui_heading(ctx, label)
	gui_push_id(ctx, key)
	changed = gui_hue_wheel(ctx, "Hue", "hue", hsv) || changed
	changed = gui_sv_grid(ctx, "Saturation / Value", "sv", hsv) || changed
	changed = gui_alpha_slider(ctx, "Alpha", "alpha", hsv) || changed
	gui_pop_id(ctx)
	swatch := gui_next_rect(ctx, height = 42)
	gui_box(ctx, swatch, {
		fill = gui_hsv_to_rgb(hsv^),
		border = ctx.style.panel_border,
		radius = ctx.style.radius_control,
		border_width = ctx.style.border_width,
	})
	return changed
}

gui_circular_progress :: proc(ctx: ^Gui_Context, label: string, value: f32) {
	bounds := gui_next_rect(ctx, height = 92)
	size := min(bounds.h - 8, bounds.w * 0.38)
	rect := Rect{bounds.x + 6, bounds.y + (bounds.h - size) * 0.5, size, size}
	gui_shader_rect(ctx, rect, .Circular_Progress, {gui_clamp01(value), 0.72, 0, 1}, ctx.style.accent)
	gui_text_clipped(ctx, {bounds.x + size + 18, bounds.y, max(bounds.w - size - 18, 0), bounds.h}, {bounds.x + size + 24, bounds.y + 28}, label, ctx.style.text)
}

gui_combobox :: gui_combobox_keyed

// Cycles a closed combobox from either navigation axis. Composite controls can
// use this with pointer-only side arrows so they still behave as one input for
// keyboard and controller focus.
gui_combobox_cycle_focused :: proc(ctx: ^Gui_Context, id: Gui_Id, current: ^int, option_count: int) -> bool {
	if option_count <= 0 || ctx.focused != id || ctx.open_panel == id {
		return false
	}
	delta := 0
	if ctx.input.nav_pressed_x < 0 || ctx.input.nav_pressed_y < 0 {
		delta = -1
	} else if ctx.input.nav_pressed_x > 0 || ctx.input.nav_pressed_y > 0 {
		delta = 1
	}
	if delta == 0 {
		return false
	}
	current^ = (current^ + delta + option_count) % option_count
	return true
}

gui_stepper_button_at :: proc(ctx: ^Gui_Context, id: Gui_Id, bounds: Rect, direction: int, enabled: bool, focusable := true) -> bool {
	control := gui_control(ctx, id, bounds, enabled, focusable)
	fill := ctx.style.control
	border := ctx.style.panel_border
	if !enabled {
		fill = ctx.style.control_disabled
	} else if ctx.active == id {
		fill = ctx.style.control_active
		border = gui_apply_opacity(ctx.style.accent, 0.64)
	} else if ctx.hot == id || control.focused {
		fill = ctx.style.control_hot
		border = gui_apply_opacity(ctx.style.text, 0.46)
	}
	gui_round_rect(ctx, bounds, ctx.style.radius_control, fill)
	gui_round_stroke(ctx, bounds, ctx.style.radius_control, border, ctx.style.border_width)
	center := Vec2{bounds.x + bounds.w * 0.5, bounds.y + bounds.h * 0.5}
	size := max(min(bounds.w, bounds.h) * 0.16, 5)
	x := size * 0.42
	if direction < 0 {
		gui_line(ctx, {center.x + x, center.y - size}, {center.x - x, center.y}, ctx.style.text_muted, ctx.style.border_width * 2)
		gui_line(ctx, {center.x - x, center.y}, {center.x + x, center.y + size}, ctx.style.text_muted, ctx.style.border_width * 2)
	} else {
		gui_line(ctx, {center.x - x, center.y - size}, {center.x + x, center.y}, ctx.style.text_muted, ctx.style.border_width * 2)
		gui_line(ctx, {center.x + x, center.y}, {center.x - x, center.y + size}, ctx.style.text_muted, ctx.style.border_width * 2)
	}
	if control.focused {
		gui_focus_ring(ctx, bounds)
	}
	return control.activated || (enabled && control.hovered && ctx.active == id && ctx.input.mouse_released)
}

// A selector with pointer-friendly previous/next buttons and a searchable
// center dropdown. In explicit controller mode, focus only identifies the
// navigation destination; Accept engages the selector before D-pad input can
// change its value. The dropdown remains available through pointer input.
gui_stepper_combobox :: proc(
	ctx: ^Gui_Context,
	label, key: string,
	current: ^int,
	options: []string,
	query_buffer: []u8,
	previous_tooltip := "Previous option",
	next_tooltip := "Next option",
) -> bool {
	if len(options) == 0 {
		return false
	}
	id := gui_make_id(ctx, key)
	row := gui_next_rect(ctx)
	current^ = max(min(current^, len(options) - 1), 0)
	value_before := current^
	arrow_w := min(max(row.h, f32(35)), row.w * 0.22)
	left := Rect{row.x, row.y, arrow_w, row.h}
	right := Rect{row.x + row.w - arrow_w, row.y, arrow_w, row.h}
	center := Rect{row.x + arrow_w, row.y, max(row.w - arrow_w * 2, 0), row.h}
	changed := false

	if gui_stepper_button_at(ctx, gui_id_child(id, "previous"), left, -1, true, false) {
		ctx.focused = id
		current^ = (current^ - 1 + len(options)) % len(options)
		changed = true
	}
	gui_tooltip(ctx, left, previous_tooltip)

	if gui_stepper_button_at(ctx, gui_id_child(id, "next"), right, 1, true, false) {
		ctx.focused = id
		current^ = (current^ + 1) % len(options)
		changed = true
	}
	gui_tooltip(ctx, right, next_tooltip)

	if ctx.controller_explicit_activation {
		editing := gui_update_focus_edit(ctx, id, ctx.focused == id)
		gui_controller_edit_int(ctx, id, current)
		if editing {
			nav_x, nav_y := gui_focused_nav_pressed(ctx, id)
			if nav_x != 0 || nav_y != 0 {
				delta := int(nav_x + nav_y)
				current^ = (current^ + delta + len(options)) % len(options)
				changed = true
			}
		}
	} else {
		changed = gui_combobox_cycle_focused(ctx, id, current, len(options)) || changed
	}

	gui_layout_begin(ctx, center, .Column, 0, center.h)
	changed = gui_combobox_keyed(ctx, label, key, current, options, query_buffer, false) || changed
	gui_layout_end(ctx)
	gui_focus_or_edit_ring(ctx, id, center)
	// Cancellation restores the snapshot inside gui_controller_edit_int. Report
	// that restoration so callers can re-apply runtime-backed selections.
	return changed || current^ != value_before
}

gui_select_chrome :: proc(ctx: ^Gui_Context, bounds: Rect, display: string, id: Gui_Id, open, focused: bool) {
	fill := ctx.style.control
	border := ctx.style.panel_border
	stroke_width := ctx.style.border_width
	if open || ctx.active == id || ctx.focus_edit_id == id {
		fill = ctx.style.control_active
		border = gui_apply_opacity(ctx.style.accent, 0.64)
		stroke_width = max(ctx.style.border_width * 2, 2)
	} else if ctx.hot == id || focused {
		fill = ctx.style.control_hot
		border = gui_apply_opacity(ctx.style.text, 0.46)
	}

	gui_shadow(ctx, bounds, ctx.style.radius_control, ctx.style.shadow_offset, ctx.style.shadow_blur * 0.72, {0, 0, 0, 0.18})
	gui_round_rect(ctx, bounds, ctx.style.radius_control, fill)
	gui_round_stroke(ctx, bounds, ctx.style.radius_control, border, stroke_width)
	text_rect := gui_inset_edges(bounds, {left = ctx.style.control_padding * 1.5, top = 0, right = bounds.h, bottom = 0})
	gui_text_clipped(ctx, text_rect, {text_rect.x, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, display, ctx.style.text)
	icon_center := Vec2{bounds.x + bounds.w - bounds.h * 0.5, bounds.y + bounds.h * 0.5}
	gui_chevron(ctx, icon_center, max(bounds.h * 0.16, 5), open, ctx.style.text_muted)
}

gui_chevron :: proc(ctx: ^Gui_Context, center: Vec2, size: f32, up: bool, color: Color) {
	half := size
	y := size * 0.36
	if up {
		gui_line(ctx, {center.x - half, center.y + y}, {center.x, center.y - y}, color, ctx.style.border_width * 2)
		gui_line(ctx, {center.x, center.y - y}, {center.x + half, center.y + y}, color, ctx.style.border_width * 2)
	} else {
		gui_line(ctx, {center.x - half, center.y - y}, {center.x, center.y + y}, color, ctx.style.border_width * 2)
		gui_line(ctx, {center.x, center.y + y}, {center.x + half, center.y - y}, color, ctx.style.border_width * 2)
	}
}

gui_combo_popup_rect :: proc(ctx: ^Gui_Context, bounds: Rect, options: []string, query: string, match_count, selected_index: int) -> Rect {
	query_height := len(query) > 0 ? ctx.style.row_height : f32(0)
	visible_rows := min(max(match_count, 1), GUI_COMBO_SHORT_POPUP_ROWS)
	list_height := f32(visible_rows) * ctx.style.row_height
	width := max(bounds.w, gui_combo_popup_content_width(ctx, options))
	max_width := f32(ctx.input.window_width) > 0 ? max(f32(ctx.input.window_width) - ctx.style.spacing_1 * 2, bounds.w) : width
	width = min(width, max_width)
	popup_height := query_height + list_height

	below := Rect{bounds.x, bounds.y + bounds.h + ctx.style.spacing_1, width, popup_height}
	if ctx.input.window_height <= 0 {
		return below
	}
	margin := ctx.style.spacing_1
	viewport_h := max(f32(ctx.input.window_height) - margin * 2, 0)
	if match_count > GUI_COMBO_SHORT_POPUP_ROWS && viewport_h > 0 {
		content_height := f32(max(match_count, 1)) * ctx.style.row_height
		popup_height = min(query_height + content_height, viewport_h)
		popup_height = max(popup_height, min(query_height + ctx.style.row_height, viewport_h))
		selected_rank := gui_combo_match_rank(options, query, selected_index)
		selected_center_y := bounds.y + bounds.h * 0.5
		y := selected_center_y - query_height - (f32(selected_rank) + 0.5) * ctx.style.row_height
		return gui_overlay_nudge_into_view(ctx, {bounds.x, y, width, popup_height})
	}

	space_below := f32(ctx.input.window_height) - margin - (bounds.y + bounds.h + ctx.style.spacing_1)
	space_above := bounds.y - ctx.style.spacing_1 - margin
	if space_below < popup_height && space_above > space_below {
		above_h := min(popup_height, max(space_above, ctx.style.row_height))
		return gui_overlay_nudge_into_view(ctx, {bounds.x, bounds.y - ctx.style.spacing_1 - above_h, width, above_h})
	}
	return gui_overlay_nudge_into_view(ctx, below)
}

gui_combo_popup_content_width :: proc(ctx: ^Gui_Context, options: []string) -> f32 {
	width := f32(0)
	for option in options {
		width = max(width, gui_text_width(ctx, option))
	}
	return width + ctx.style.control_padding * 4 + gui_scrollbar_reserved_width(ctx)
}

gui_combo_match_count :: proc(options: []string, query: string) -> int {
	count := 0
	for option in options {
		if gui_string_contains_fold(option, query) {
			count += 1
		}
	}
	return count
}

gui_combo_match_rank :: proc(options: []string, query: string, selected_index: int) -> int {
	rank := 0
	for option, i in options {
		if !gui_string_contains_fold(option, query) {
			continue
		}
		if i == selected_index {
			return rank
		}
		rank += 1
	}
	return 0
}

gui_combo_scroll_highlight_into_view :: proc(ctx: ^Gui_Context, matches: []int, viewport_height: f32) {
	if ctx.combo_highlight < 0 || viewport_height <= 0 {
		return
	}
	highlight_index := -1
	for match, i in matches {
		if match == ctx.combo_highlight {
			highlight_index = i
			break
		}
	}
	if highlight_index < 0 {
		return
	}
	row_top := f32(highlight_index) * ctx.style.row_height
	row_bottom := row_top + ctx.style.row_height
	if row_top < ctx.combo_scroll {
		ctx.combo_scroll = row_top
	} else if row_bottom > ctx.combo_scroll + viewport_height {
		ctx.combo_scroll = row_bottom - viewport_height
	}
}

gui_combo_scroll_highlight_to_anchor :: proc(ctx: ^Gui_Context, matches: []int, list_viewport: Rect, bounds: Rect) {
	if ctx.combo_highlight < 0 || list_viewport.h <= 0 {
		return
	}
	highlight_index := -1
	for match, i in matches {
		if match == ctx.combo_highlight {
			highlight_index = i
			break
		}
	}
	if highlight_index < 0 {
		return
	}
	content_height := f32(len(matches)) * ctx.style.row_height
	max_scroll := max(content_height - list_viewport.h, 0)
	anchor_center_y := bounds.y + bounds.h * 0.5
	row_center := f32(highlight_index) * ctx.style.row_height + ctx.style.row_height * 0.5
	ctx.combo_scroll = min(max(row_center - (anchor_center_y - list_viewport.y), 0), max_scroll)
}

gui_combobox_keyed :: proc(ctx: ^Gui_Context, label, key: string, current: ^int, options: []string, query_buffer: []u8, focus_accept_opens := true) -> bool {
	if len(options) == 0 {
		return false
	}
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	current^ = max(min(current^, len(options) - 1), 0)
	changed := false
	open := ctx.open_panel == id
	opened_this_frame := false
	control := gui_control(ctx, id, bounds, true)
	accept_pressed := gui_accept_pressed(ctx)
	clicked := (focus_accept_opens && control.focused && accept_pressed) || (control.hovered && ctx.active == id && ctx.input.mouse_released)
	if open && accept_pressed {
		clicked = false
	}
	if open && clicked {
		query := gui_query_string(query_buffer)
		matches_count := gui_combo_match_count(options, query)
		popup := gui_combo_popup_rect(ctx, bounds, options, query, matches_count, current^)
		if gui_contains(popup, ctx.input.mouse_pos) {
			clicked = false
		}
	}
	if !open && control.focused && ctx.input.key_space {
		clicked = true
	}
	if clicked {
		if open {
			ctx.open_panel = GUI_ID_NONE
		} else {
			ctx.open_panel = id
			ctx.focused = id
			ctx.combo_highlight = max(min(current^, len(options) - 1), 0)
			ctx.combo_scroll = 0
			gui_clear_query(query_buffer)
			opened_this_frame = true
		}
		open = ctx.open_panel == id
	}
	if open && ctx.input.mouse_pressed && !gui_contains(bounds, ctx.input.mouse_pos) {
		query := gui_query_string(query_buffer)
		matches_count := gui_combo_match_count(options, query)
		popup := gui_combo_popup_rect(ctx, bounds, options, query, matches_count, current^)
		if !gui_contains(popup, ctx.input.mouse_pos) {
			ctx.open_panel = GUI_ID_NONE
			open = false
		}
	}

	display := label
	if current^ >= 0 && current^ < len(options) {
		display = options[current^]
	}
	gui_select_chrome(ctx, bounds, display, id, open, control.focused)

	if !open {
		return changed
	}
	ctx.wants_text_input = true

	query_changed := false
	if ctx.input.text_input_len > 0 {
		gui_append_query(query_buffer, ctx.input.text_input[:ctx.input.text_input_len])
		query_changed = true
	}
	if ctx.input.key_backspace {
		gui_pop_query(query_buffer)
		query_changed = true
	}
	if ctx.input.back {
		ctx.open_panel = GUI_ID_NONE
		return false
	}

	query := gui_query_string(query_buffer)
	if query_changed {
		ctx.combo_scroll = 0
	}
	matches := make([dynamic]int, 0, len(options))
	defer delete(matches)
	for option, i in options {
		if gui_string_contains_fold(option, query) {
			append(&matches, i)
		}
	}
	if len(matches) == 0 {
		ctx.combo_highlight = -1
	} else {
		if ctx.combo_highlight < 0 || !gui_match_contains(matches[:], ctx.combo_highlight) {
			ctx.combo_highlight = matches[0]
		}
		if !opened_this_frame && ctx.input.nav_pressed_y > 0 {
			ctx.combo_highlight = gui_next_match(matches[:], ctx.combo_highlight, 1)
		}
		if !opened_this_frame && ctx.input.nav_pressed_y < 0 {
			ctx.combo_highlight = gui_next_match(matches[:], ctx.combo_highlight, -1)
		}
		if !opened_this_frame && accept_pressed {
			current^ = ctx.combo_highlight
			ctx.open_panel = GUI_ID_NONE
			return true
		}
	}

	// Anchor long popups to the committed selection. Pointer hover and keyboard
	// navigation update combo_highlight; using that moving value for geometry
	// makes the entire popup jump beneath a stationary pointer every frame.
	popup := gui_combo_popup_rect(ctx, bounds, options, query, len(matches), current^)
	query_height := len(query) > 0 ? ctx.style.row_height : f32(0)
	list_viewport := Rect{popup.x, popup.y + query_height, popup.w, max(popup.h - query_height, 0)}
	content_height := f32(len(matches)) * ctx.style.row_height
	max_scroll := max(content_height - list_viewport.h, 0)
	if opened_this_frame && len(matches) > GUI_COMBO_SHORT_POPUP_ROWS {
		gui_combo_scroll_highlight_to_anchor(ctx, matches[:], list_viewport, bounds)
	} else {
		gui_combo_scroll_highlight_into_view(ctx, matches[:], list_viewport.h)
	}
	combo_scroll := ctx.combo_scroll
	_, _ = gui_apply_wheel_scroll(ctx, popup, &combo_scroll, max_scroll, ctx.style.row_height, ctx.scroll_depth)
	ctx.combo_scroll = combo_scroll
	ctx.combo_scroll = min(max(ctx.combo_scroll, 0), max_scroll)
	gui_record_scroll_hit(ctx, popup, ctx.combo_scroll, max_scroll, ctx.style.row_height, ctx.scroll_depth)
	gui_overlay_input_rect(ctx, popup)
	gui_set_combo_popup(ctx, id, popup, options, query)
	y := list_viewport.y - ctx.combo_scroll
	for match in matches {
		row := Rect{popup.x, y, popup.w, ctx.style.row_height}
		visible_row := y + ctx.style.row_height > list_viewport.y && y < list_viewport.y + list_viewport.h
		row_id := gui_id_child_int(id, match)
		if visible_row && !opened_this_frame && gui_pointer_enabled(ctx) && gui_contains(list_viewport, ctx.input.mouse_pos) && gui_contains(row, ctx.input.mouse_pos) {
			ctx.hot = row_id
			ctx.combo_highlight = match
			if ctx.input.mouse_released {
				current^ = match
				ctx.open_panel = GUI_ID_NONE
				changed = true
			}
		}
		y += ctx.style.row_height
		if y >= popup.y + popup.h {
			break
		}
	}
	return changed
}

gui_set_combo_popup :: proc(ctx: ^Gui_Context, id: Gui_Id, popup: Rect, options: []string, query: string) {
	ctx.combo_popup_visible = true
	ctx.combo_popup_id = id
	ctx.combo_popup_rect = popup
	ctx.combo_popup_options = options
	ctx.combo_popup_query_len = min(len(query), len(ctx.combo_popup_query))
	query_bytes := transmute([]u8)query
	for i in 0 ..< ctx.combo_popup_query_len {
		ctx.combo_popup_query[i] = query_bytes[i]
	}
	if ctx.combo_popup_query_len < len(ctx.combo_popup_query) {
		ctx.combo_popup_query[ctx.combo_popup_query_len] = 0
	}
}

gui_draw_combo_popup_overlay :: proc(ctx: ^Gui_Context) {
	if !ctx.combo_popup_visible || ctx.open_panel != ctx.combo_popup_id {
		return
	}
	popup := ctx.combo_popup_rect
	query := string(ctx.combo_popup_query[:ctx.combo_popup_query_len])
	gui_shadow(ctx, popup, ctx.style.radius_control, {0, 5}, 12, ctx.style.shadow_color)
	gui_round_rect(ctx, popup, ctx.style.radius_control, ctx.style.panel)
	gui_round_stroke(ctx, popup, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)
	gui_scissor_begin(ctx, popup)
	query_height := len(query) > 0 ? ctx.style.row_height : f32(0)
	if len(query) > 0 {
		query_row := Rect{popup.x, popup.y, popup.w, ctx.style.row_height}
		gui_round_rect(ctx, gui_inset(query_row, 3), ctx.style.radius_control, ctx.style.control)
		gui_text_clipped(ctx, gui_inset(query_row, 8), {query_row.x + 12, query_row.y + 6}, query, ctx.style.accent)
	}

	list_viewport := Rect{popup.x, popup.y + query_height, popup.w, max(popup.h - query_height, 0)}
	y := list_viewport.y - ctx.combo_scroll
	match_count := gui_combo_match_count(ctx.combo_popup_options, query)
	for option, match in ctx.combo_popup_options {
		if !gui_string_contains_fold(option, query) {
			continue
		}
		row := Rect{popup.x, y, popup.w, ctx.style.row_height}
		if y + ctx.style.row_height > list_viewport.y && y < list_viewport.y + list_viewport.h {
			if ctx.combo_highlight == match {
				gui_round_rect(ctx, gui_inset(row, 3), ctx.style.radius_control, ctx.style.control_hot)
			}
			text_left := row.x + ctx.style.control_padding * 1.5
			if match == ctx.combo_highlight {
				gui_rect(ctx, {row.x + 3, row.y + 7, max(ctx.style.border_width * 2, 2), max(row.h - 14, 1)}, ctx.style.accent)
			}
			gui_text_clipped(ctx, gui_inset_edges(row, {left = ctx.style.control_padding * 1.5, top = 0, right = gui_scrollbar_reserved_width(ctx) + ctx.style.control_padding, bottom = 0}), {text_left, row.y + max((row.h - ctx.style.body_text_height) * 0.5, 0)}, option, ctx.style.text)
		}
		y += ctx.style.row_height
		if y >= popup.y + popup.h {
			break
		}
	}
	if match_count == 0 {
		gui_text_clipped(ctx, gui_inset(popup, 8), {popup.x + 12, popup.y + 6}, "No matches", ctx.style.text_muted)
	}
	gui_scissor_end(ctx)
	gui_scrollbar(ctx, list_viewport, f32(match_count) * ctx.style.row_height, ctx.combo_scroll)
}

gui_collapsible_begin :: gui_collapsible_begin_keyed

gui_collapsible_begin_keyed :: proc(ctx: ^Gui_Context, label, key: string, open: ^bool) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	control := gui_control(ctx, id, bounds, true)
	if (control.focused && (gui_accept_pressed(ctx) || ctx.input.key_space)) || (control.hovered && ctx.active == id && ctx.input.mouse_released) {
		open^ = !open^
	}
	gui_expander_chrome(ctx, bounds, label, id, open^, control.focused)
	return open^
}

gui_expander_chrome :: proc(ctx: ^Gui_Context, bounds: Rect, label: string, id: Gui_Id, open, focused: bool) {
	fill := Color{0, 0, 0, 0}
	border := ctx.style.panel_border
	label_color := ctx.style.text
	if open {
		fill = gui_apply_opacity(ctx.style.control, 0.72)
		border = gui_apply_opacity(ctx.style.accent, 0.45)
		label_color = ctx.style.text
	}
	if ctx.hot == id || focused {
		fill = ctx.style.control_hot
		border = gui_apply_opacity(ctx.style.text, 0.46)
	}
	if ctx.active == id {
		fill = ctx.style.control_active
		border = gui_apply_opacity(ctx.style.accent, 0.64)
	}
	if fill.a > 0 {
		gui_round_rect(ctx, bounds, ctx.style.radius_control, fill)
	}
	gui_round_stroke(ctx, bounds, ctx.style.radius_control, border, ctx.style.border_width)
	if open {
		gui_rect(ctx, {bounds.x + 3, bounds.y + 7, max(ctx.style.border_width * 2, 2), max(bounds.h - 14, 1)}, ctx.style.accent)
	}
	t := open ? f32(1) : f32(0)
	if ctx.input.delta_time > 0 {
		t = gui_animate_value(ctx, gui_id_child(id, "expander-open"), t, 16)
	}
	icon_center := Vec2{bounds.x + ctx.style.control_padding * 2.1, bounds.y + bounds.h * 0.5}
	icon_color := (ctx.hot == id || focused || open) ? ctx.style.accent : ctx.style.text_muted
	gui_expander_chevron(ctx, icon_center, max(bounds.h * 0.16, 5), t, icon_color)
	text_x := bounds.x + ctx.style.control_padding * 4
	text_rect := gui_inset_edges(bounds, {left = ctx.style.control_padding * 4, top = 0, right = ctx.style.control_padding, bottom = 0})
	gui_text_clipped(ctx, text_rect, {text_x, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, label, label_color)
	if focused {
		gui_focus_ring(ctx, bounds)
	}
}

gui_expander_chevron :: proc(ctx: ^Gui_Context, center: Vec2, size, t: f32, color: Color) {
	x := gui_clamp01(t)
	closed_a := Vec2{center.x - size * 0.35, center.y - size}
	closed_b := Vec2{center.x + size * 0.45, center.y}
	closed_c := Vec2{center.x - size * 0.35, center.y + size}
	open_a := Vec2{center.x - size, center.y - size * 0.35}
	open_b := Vec2{center.x, center.y + size * 0.45}
	open_c := Vec2{center.x + size, center.y - size * 0.35}
	a := gui_lerp_vec2(closed_a, open_a, x)
	b := gui_lerp_vec2(closed_b, open_b, x)
	c := gui_lerp_vec2(closed_c, open_c, x)
	gui_line(ctx, a, b, color, ctx.style.border_width * 2)
	gui_line(ctx, b, c, color, ctx.style.border_width * 2)
}

gui_scissor_begin :: proc(ctx: ^Gui_Context, rect: Rect) {
	append(&ctx.commands, Draw_Command{kind = .Scissor_Begin, rect = rect})
}

gui_scissor_end :: proc(ctx: ^Gui_Context) {
	append(&ctx.commands, Draw_Command{kind = .Scissor_End})
}

gui_input_clip_begin :: proc(ctx: ^Gui_Context, rect: Rect) {
	if ctx.input_clip_depth >= MAX_GUI_CLIP_DEPTH {
		return
	}
	clip := rect
	if ctx.input_clip_depth > 0 {
		clip = gui_rect_intersection(ctx.input_clip_stack[ctx.input_clip_depth - 1], rect)
	}
	ctx.input_clip_stack[ctx.input_clip_depth] = clip
	ctx.input_clip_depth += 1
}

gui_input_clip_end :: proc(ctx: ^Gui_Context) {
	if ctx.input_clip_depth > 0 {
		ctx.input_clip_depth -= 1
	}
}

gui_overlay_input_rect :: proc(ctx: ^Gui_Context, rect: Rect) {
	if rect.w <= 0 || rect.h <= 0 || ctx.next_overlay_input_rect_count >= MAX_GUI_OVERLAY_INPUT_RECTS {
		return
	}
	ctx.next_overlay_input_rects[ctx.next_overlay_input_rect_count] = rect
	ctx.next_overlay_input_rect_count += 1
}

gui_overlay_input_begin :: proc(ctx: ^Gui_Context, rect: Rect) {
	gui_overlay_input_rect(ctx, rect)
	ctx.overlay_input_depth += 1
}

gui_overlay_input_end :: proc(ctx: ^Gui_Context) {
	if ctx.overlay_input_depth > 0 {
		ctx.overlay_input_depth -= 1
	}
}

gui_overlay_input_cancel :: proc(ctx: ^Gui_Context) {
	gui_overlay_input_end(ctx)
	if ctx.next_overlay_input_rect_count > 0 {
		ctx.next_overlay_input_rect_count -= 1
	}
}

gui_scrollbar :: proc(ctx: ^Gui_Context, viewport: Rect, content_height, scroll: f32) {
	if content_height <= viewport.h || viewport.h <= 0 {
		return
	}
	track_w := ctx.style.scrollbar_width
	track_margin := ctx.style.border_width * 2
	track := Rect{viewport.x + viewport.w - track_w - track_margin, viewport.y + track_margin, track_w, max(viewport.h - track_margin * 2, 0)}
	if track.h <= 0 {
		return
	}
	thumb_h := max(track.h * (viewport.h / max(content_height, 1)), ctx.style.rhythm * 0.5)
	thumb_h = min(thumb_h, track.h)
	max_scroll := max(content_height - viewport.h, 1)
	thumb_range := max(track.h - thumb_h, 0)
	thumb_y := track.y + thumb_range * gui_clamp01(scroll / max_scroll)
	thumb := Rect{track.x, thumb_y, track.w, thumb_h}
	gui_round_rect(ctx, track, track.w * 0.5, gui_apply_opacity(ctx.style.control, 0.55))
	gui_round_rect(ctx, thumb, thumb.w * 0.5, gui_apply_opacity(ctx.style.text_muted, 0.70))
}

gui_scrollbar_reserved_width :: proc(ctx: ^Gui_Context) -> f32 {
	return ctx.style.scrollbar_width + ctx.style.scrollbar_gutter + ctx.style.border_width * 2
}

gui_scrollbar_content_width :: proc(ctx: ^Gui_Context, viewport: Rect, content_height: f32) -> f32 {
	if content_height <= viewport.h || viewport.h <= 0 {
		return viewport.w
	}
	return max(viewport.w - gui_scrollbar_reserved_width(ctx), 0)
}

gui_next_row :: proc(ctx: ^Gui_Context, width := f32(-1), height := f32(-1)) -> Rect {
	w := width
	h := height
	if w <= 0 {
		w = ctx.content_width
	}
	if h <= 0 {
		h = ctx.style.row_height
	}
	bounds := Rect {
		x = ctx.next_cursor.x,
		y = ctx.next_cursor.y,
		w = w,
		h = h,
	}
	ctx.next_cursor.y += h + ctx.style.spacing
	return bounds
}
