package game

import uifw "../ui"

import "core:fmt"
import "core:math"

slime_controller_ui_float_slider :: proc(gui: ^uifw.Gui_Context, desc: Control_Descriptor, value: ^f32) -> bool {
	label := fmt.tprintf("%s: %.2f", desc.label, value^)
	changed := uifw.gui_slider_f32(gui, label, desc.stable_id, value, desc.range.min, desc.range.max)
	shared_control_explanation(gui, desc.stable_id, desc.description)
	return changed
}

slime_controller_ui_button :: proc(gui: ^uifw.Gui_Context, desc: Control_Descriptor, label_override: string = "") -> bool {
	label := desc.label
	if len(label_override) > 0 {
		label = label_override
	}
	clicked := uifw.gui_button(gui, label, desc.stable_id)
	shared_control_explanation(gui, desc.stable_id, desc.description)
	return clicked
}

slime_controller_ui_draw_presets :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State, worker: ^Product_Context) {
	builtin_names := remaining_sim_builtin_preset_names(.Slime_Mold)
	directory := remaining_sim_directory(.Slime_Mold)
	preset_fieldset_draw(
		gui,
		&sim.preset_ui,
		worker,
		directory,
		builtin_names,
		sim.builtin_preset_index,
		Preset_Fieldset_Builtin_Context {kind = .Remaining, remaining = sim, remaining_kind = .Slime_Mold},
	)
}

slime_controller_ui_draw_start_over :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	if desc, ok := slime_control_descriptor_by_id(.Playback_Reset); ok {
		if slime_controller_ui_button(gui, desc, "Respawn Agents") {
			slime_request_reset(sim)
			uifw.gui_notice(gui, "Agents respawned. Your behavior settings stayed unchanged.")
		}
	}
	if desc, ok := slime_control_descriptor_by_id(.Playback_Randomize); ok {
		if slime_controller_ui_button(gui, desc, "Randomize Behavior") {
			slime_randomize_settings(sim)
			uifw.gui_notice(gui, "Behavior randomized. Restore Previous Behavior is available here.")
		}
	}
	if sim.slime_randomize_undo_available && uifw.gui_button(gui, "Restore Previous Behavior", "slime_undo_randomize") {
		if slime_undo_randomize_settings(sim) {
			uifw.gui_notice(gui, "Previous Slime behavior restored.")
		}
	}
}

slime_controller_ui_draw_play :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	_ = ui
	if desc, ok := slime_control_descriptor_by_id(.Playback_Paused); ok {
		if uifw.gui_button(gui, sim.paused ? "Resume" : "Pause", desc.stable_id) {
			sim.paused = !sim.paused
		}
	}
	if desc, ok := slime_control_descriptor_by_id(.Playback_Reset); ok {
		if slime_controller_ui_button(gui, desc) {
			slime_request_reset(sim)
			uifw.gui_notice(gui, "Agents respawned. Your behavior settings stayed unchanged.")
		}
	}
	if desc, ok := slime_control_descriptor_by_id(.Playback_Clear_Accumulation); ok {
		if slime_controller_ui_button(gui, desc) {
			slime_request_clear_trails(sim)
		}
	}
	if desc, ok := slime_control_descriptor_by_id(.Playback_Randomize); ok {
		if slime_controller_ui_button(gui, desc) {
			slime_randomize_settings(sim)
			uifw.gui_notice(gui, "Behavior randomized. Restore Previous Behavior is available here.")
		}
	}
	if sim.slime_randomize_undo_available && uifw.gui_button(gui, "Restore Previous Behavior", "slime_play_undo_randomize") {
		if slime_undo_randomize_settings(sim) {
			uifw.gui_notice(gui, "Previous Slime behavior restored.")
		}
	}
}

slime_controller_ui_draw_look :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	settings := sim.slime
	_ = color_scheme_editor_draw_selector(gui, &ui.color_scheme_editor, "slime_controller_palette", &settings.color_scheme, &settings.color_scheme_reversed)
	if desc, ok := slime_control_descriptor_by_id(.Render_Background_Mode); ok {
		if uifw.gui_selector(gui, fmt.tprintf("%s: %s", desc.label, SLIME_BACKGROUND_MODE_NAMES[settings.background_index]), desc.stable_id, &settings.background_index, SLIME_BACKGROUND_MODE_NAMES[:]) {
			settings.background_mode = Slime_Background_Mode(settings.background_index)
		}
		shared_control_explanation(gui, desc.stable_id, desc.description)
	}
	uifw.gui_spacer(gui, 8)
	uifw.gui_label(gui, "Effects")
	if desc, ok := slime_control_descriptor_by_id(.Post_Blur_Enabled); ok {
		_ = uifw.gui_toggle(gui, settings.post_processing.blur_enabled ? "Blur: On" : "Blur: Off", desc.stable_id, &settings.post_processing.blur_enabled)
		shared_control_explanation(gui, desc.stable_id, desc.description)
	}
	if ui.slime_controller.mode != .Couch && settings.post_processing.blur_enabled {
		if desc, ok := slime_control_descriptor_by_id(.Post_Blur_Radius); ok {
			_ = slime_controller_ui_float_slider(gui, desc, &settings.post_processing.blur_radius)
		}
		if desc, ok := slime_control_descriptor_by_id(.Post_Blur_Sigma); ok {
			_ = slime_controller_ui_float_slider(gui, desc, &settings.post_processing.blur_sigma)
		}
	}
}

slime_controller_ui_draw_brush :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	uifw.gui_label(gui, "Interaction")
	tool_set := canvas_tool_set_for_kind(.Slime_Mold)
	shared_canvas_tool_selector(gui, &tool_set, &sim.canvas_tool)
	uifw.gui_spacer(gui, 8)
	uifw.gui_label(gui, "Shape")
	_ = shared_two_axis_pad_f32(gui, "Brush Shape", "slime_brush_shape", "Radius", "Strength", &sim.cursor_size, &sim.cursor_strength, 0.01, 1, 0, 50)
}

slime_controller_ui_draw_motion :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	settings := sim.slime
	uifw.gui_label(gui, "Population")
	if desc, ok := slime_control_descriptor_by_id(.Agents_Count); ok {
		if uifw.gui_numeric_u32(gui, desc.label, desc.stable_id, &settings.agent_count, SLIME_MIN_AGENT_COUNT, SLIME_MAX_AGENT_COUNT) {
			slime_request_reset(sim)
		}
		shared_control_explanation(gui, desc.stable_id, desc.description)
	}
	uifw.gui_spacer(gui, 8)
	uifw.gui_label(gui, "Movement")
	_ = shared_range_slider_f32(gui, "Speed Range", "slime_speed_range", &settings.agent_speed_min, &settings.agent_speed_max, 0, 500)
	shared_range_explanation(gui, "slime_speed_range", "Speed Range gives agents different movement speeds, from the slowest to the fastest.")
	turn_degrees := settings.agent_turn_rate * 180 / math.PI
	if slime_controller_ui_draw_behavior_diagram(gui, &turn_degrees, &settings.agent_jitter, &settings.agent_sensor_angle, &settings.agent_sensor_distance) {
		settings.agent_turn_rate = turn_degrees * math.PI / 180
	}
	_ = uifw.gui_toggle(gui, settings.isotropic_jitter ? "Isotropic Jitter: On" : "Isotropic Jitter: Off", "slime_isotropic_jitter", &settings.isotropic_jitter)
}

slime_controller_ui_draw_behavior_diagram :: proc(gui: ^uifw.Gui_Context, turn_degrees, jitter, angle, distance: ^f32) -> bool {
	bounds := uifw.gui_next_rect(gui, height = SLIME_CONTROLLER_UI_BEHAVIOR_HEIGHT)
	pad := min(max(gui.style.spacing_2, f32(10)), f32(16))
	gap := min(max(gui.style.spacing_2, f32(8)), f32(14))
	header_h := f32(24)
	content := uifw.Rect{bounds.x + pad, bounds.y + pad + header_h, max(bounds.w - pad * 2, 1), max(bounds.h - pad * 2 - header_h, 1)}
	sensor_area := uifw.Rect{content.x, content.y, max(content.w * 0.62 - gap, 1), content.h}
	motion_area := uifw.Rect{content.x + content.w * 0.62, content.y, max(content.w * 0.38, 1), content.h}
	changed := false

	uifw.gui_round_rect(gui, bounds, 10, {1, 1, 1, 0.07})
	uifw.gui_round_stroke(gui, bounds, 10, {1, 1, 1, 0.13}, max(gui.style.border_width, 1))
	title := "AGENT BEHAVIOR"
	title_scale := slime_controller_ui_fit_text_scale(gui, title, 0.56, content.w * 0.3)
	uifw.gui_text_aligned_scaled(gui, {content.x, bounds.y + pad, content.w * 0.3, header_h}, title, gui.style.text_muted, .Left, title_scale)

	center := uifw.Vec2{sensor_area.x + sensor_area.w * 0.52, sensor_area.y + sensor_area.h * 0.90}
	r := min(sensor_area.h * 0.80, sensor_area.w * 0.30)
	dist_t := min(max(distance^ / 500, 0), 1)
	cone_r := r * (0.55 + dist_t * 0.45)
	left := -math.PI * 0.5 - angle^
	right := -math.PI * 0.5 + angle^
	p0 := uifw.Vec2{center.x + math.cos(left) * cone_r, center.y + math.sin(left) * cone_r}
	p1 := uifw.Vec2{center.x + math.cos(right) * cone_r, center.y + math.sin(right) * cone_r}
	forward := uifw.Vec2{center.x, center.y - cone_r}
	sensor_id := uifw.gui_make_id(gui, "slime_behavior_sensor")
	if uifw.gui_drag_handle_region(gui, sensor_id, sensor_area, p1, 14) {
		dx := gui.input.mouse_pos.x - center.x
		dy := gui.input.mouse_pos.y - center.y
		pointer_r := math.sqrt(dx * dx + dy * dy)
		angle^ = min(max(math.abs(math.atan2(dx, -dy)), 0), math.PI)
		distance^ = min(max(((pointer_r / max(r, 1)) - 0.55) / 0.45 * 500, 0), 500)
		changed = true
	}
	_ = uifw.gui_update_focus_edit(gui, sensor_id, gui.focused == sensor_id)
	sensor_edit := uifw.Vec2{angle^, distance^}
	uifw.gui_controller_edit_vec2(gui, sensor_id, &sensor_edit)
	if sensor_edit.x != angle^ || sensor_edit.y != distance^ {
		angle^ = min(max(sensor_edit.x, 0), math.PI)
		distance^ = min(max(sensor_edit.y, 0), 500)
		changed = true
	}
	nav_x, nav_y := uifw.gui_focused_nav_pressed(gui, sensor_id)
	if nav_x != 0 || nav_y != 0 {
		scale := uifw.gui_fine_adjust_scale(gui)
		angle^ = min(max(angle^ + nav_x * math.PI * 0.025 * scale, 0), math.PI)
		distance^ = min(max(distance^ - nav_y * 12.5 * scale, 0), 500)
		changed = true
	}
	uifw.gui_quad(gui, center, p0, forward, p1, {0.392, 0.424, 1, 0.25})
	uifw.gui_line(gui, center, p0, gui.style.accent, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, center, p1, gui.style.accent, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, center, forward, {1, 1, 1, 0.62}, max(gui.style.border_width, 1))
	uifw.gui_ellipse(gui, {center.x - 6, center.y - 6, 12, 12}, gui.style.text)
	uifw.gui_ellipse(gui, {p1.x - 9, p1.y - 9, 18, 18}, gui.style.accent)
	uifw.gui_focus_or_edit_ring(gui, sensor_id, sensor_area)
	sensor_text := fmt.tprintf("SENSE  %.0f°  ·  %.0f", angle^ * 180 / math.PI, distance^)
	sensor_scale := slime_controller_ui_fit_text_scale(gui, sensor_text, 0.52, sensor_area.w)
	uifw.gui_text_aligned_scaled(gui, {sensor_area.x, sensor_area.y, sensor_area.w, header_h}, sensor_text, gui.style.text_muted, .Left, sensor_scale)

	divider_x := motion_area.x - gap * 0.5
	uifw.gui_line(gui, {divider_x, content.y}, {divider_x, content.y + content.h}, {1, 1, 1, 0.12}, max(gui.style.border_width, 1))
	motion_canvas := uifw.Rect{motion_area.x + pad, motion_area.y + header_h, max(motion_area.w - pad * 2, 1), max(motion_area.h - header_h - pad, 1)}
	turn_t := min(max(turn_degrees^ / 360, 0), 1)
	jitter_t := min(max(jitter^ / 5, 0), 1)
	motion_center := uifw.Vec2{motion_canvas.x + motion_canvas.w * 0.5, motion_canvas.y + motion_canvas.h * 0.92}
	motion_r := min(motion_canvas.h * 0.78, motion_canvas.w * 0.44)
	turn_visual := turn_t * math.PI * 0.48
	jitter_visual := jitter_t * math.PI * 0.22
	outer_visual := min(turn_visual + jitter_visual, math.PI * 0.72)
	turn_left := uifw.Vec2{motion_center.x + math.cos(-math.PI * 0.5 - turn_visual) * motion_r, motion_center.y + math.sin(-math.PI * 0.5 - turn_visual) * motion_r}
	turn_right := uifw.Vec2{motion_center.x + math.cos(-math.PI * 0.5 + turn_visual) * motion_r, motion_center.y + math.sin(-math.PI * 0.5 + turn_visual) * motion_r}
	outer_left := uifw.Vec2{motion_center.x + math.cos(-math.PI * 0.5 - outer_visual) * motion_r, motion_center.y + math.sin(-math.PI * 0.5 - outer_visual) * motion_r}
	outer_right := uifw.Vec2{motion_center.x + math.cos(-math.PI * 0.5 + outer_visual) * motion_r, motion_center.y + math.sin(-math.PI * 0.5 + outer_visual) * motion_r}
	motion_forward := uifw.Vec2{motion_center.x, motion_center.y - motion_r}
	turn_id := uifw.gui_make_id(gui, "slime_behavior_turn")
	turn_region := uifw.Rect{motion_area.x + motion_area.w * 0.5, motion_area.y, motion_area.w * 0.5, motion_area.h}
	if uifw.gui_drag_handle_region(gui, turn_id, turn_region, turn_right, 14) {
		dx := gui.input.mouse_pos.x - motion_center.x
		dy := gui.input.mouse_pos.y - motion_center.y
		pointer_angle := math.abs(math.atan2(dx, -dy))
		turn_degrees^ = min(max(pointer_angle / (math.PI * 0.48) * 360, 0), 360)
		changed = true
	}
	_ = uifw.gui_update_focus_edit(gui, turn_id, gui.focused == turn_id)
	uifw.gui_controller_edit_f32(gui, turn_id, turn_degrees)
	nav_x, nav_y = uifw.gui_focused_nav_pressed(gui, turn_id)
	if nav_x != 0 || nav_y != 0 {
		scale := uifw.gui_fine_adjust_scale(gui)
		turn_degrees^ = min(max(turn_degrees^ + (nav_x - nav_y) * 9 * scale, 0), 360)
		changed = true
	}
	jitter_id := uifw.gui_make_id(gui, "slime_behavior_jitter")
	jitter_region := uifw.Rect{motion_area.x, motion_area.y, motion_area.w * 0.5, motion_area.h}
	if uifw.gui_drag_handle_region(gui, jitter_id, jitter_region, outer_left, 14) {
		dx := gui.input.mouse_pos.x - motion_center.x
		dy := gui.input.mouse_pos.y - motion_center.y
		pointer_angle := math.abs(math.atan2(dx, -dy))
		jitter^ = min(max((pointer_angle - turn_visual) / (math.PI * 0.22) * 5, 0), 5)
		changed = true
	}
	_ = uifw.gui_update_focus_edit(gui, jitter_id, gui.focused == jitter_id)
	uifw.gui_controller_edit_f32(gui, jitter_id, jitter)
	nav_x, nav_y = uifw.gui_focused_nav_pressed(gui, jitter_id)
	if nav_x != 0 || nav_y != 0 {
		scale := uifw.gui_fine_adjust_scale(gui)
		jitter^ = min(max(jitter^ + (nav_x - nav_y) * 0.125 * scale, 0), 5)
		changed = true
	}

	// Solid fan: headings reachable through deliberate turning. Soft outer fan:
	// extra heading uncertainty introduced by jitter.
	uifw.gui_quad(gui, motion_center, outer_left, motion_forward, outer_right, {1, 1, 1, 0.08})
	uifw.gui_quad(gui, motion_center, turn_left, motion_forward, turn_right, {0.392, 0.424, 1, 0.24})
	uifw.gui_line(gui, motion_center, outer_left, {1, 1, 1, 0.30}, max(gui.style.border_width, 1))
	uifw.gui_line(gui, motion_center, outer_right, {1, 1, 1, 0.30}, max(gui.style.border_width, 1))
	uifw.gui_line(gui, motion_center, turn_left, gui.style.accent, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, motion_center, turn_right, gui.style.accent, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, motion_center, motion_forward, {1, 1, 1, 0.68}, max(gui.style.border_width, 1))
	uifw.gui_ellipse(gui, {motion_center.x - 7, motion_center.y - 7, 14, 14}, gui.style.text)
	uifw.gui_ellipse(gui, {turn_right.x - 10, turn_right.y - 10, 20, 20}, gui.style.accent)
	uifw.gui_ellipse(gui, {outer_left.x - 8, outer_left.y - 8, 16, 16}, gui.style.text)
	uifw.gui_focus_or_edit_ring(gui, turn_id, turn_region)
	uifw.gui_focus_or_edit_ring(gui, jitter_id, jitter_region)
	motion_text := fmt.tprintf("TURN %.0f°/s  ·  JITTER %.1f", turn_degrees^, jitter^)
	motion_scale := slime_controller_ui_fit_text_scale(gui, motion_text, 0.52, motion_area.w)
	uifw.gui_text_aligned_scaled(gui, {motion_area.x, motion_area.y, motion_area.w, header_h}, motion_text, gui.style.text_muted, .Left, motion_scale)
	return changed
}

slime_controller_ui_draw_awareness :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	settings := sim.slime
	_ = slime_controller_ui_draw_sensor_cone(gui, &settings.agent_sensor_angle, &settings.agent_sensor_distance)
}

slime_controller_ui_draw_sensor_cone :: proc(gui: ^uifw.Gui_Context, angle, distance: ^f32) -> bool {
	// This input has a deliberately fixed vertical footprint. Keeping the draw
	// height identical to the content-height estimate prevents layout drift.
	bounds := uifw.gui_next_rect(gui, height = SLIME_CONTROLLER_UI_AWARENESS_HEIGHT)
	id := uifw.gui_make_id(gui, "slime_sensor_cone")
	pad := min(max(gui.style.spacing_2, f32(12)), f32(20))
	info_w := min(max(bounds.w * 0.28, f32(210)), max(bounds.w - bounds.h * 1.6, bounds.w * 0.24))
	info := uifw.Rect{bounds.x + pad, bounds.y + pad, max(info_w - pad * 2, 1), max(bounds.h - pad * 2, 1)}
	visual := uifw.Rect{bounds.x + info_w, bounds.y + pad, max(bounds.w - info_w - pad, 1), max(bounds.h - pad * 2, 1)}
	center := uifw.Vec2{visual.x + visual.w * 0.5, visual.y + visual.h * 0.92}
	r := min(visual.h * 0.84, max(visual.w * 0.32, 1))
	current := uifw.Vec2{angle^, distance^}
	dist_t := min(max(current.y / 500.0, 0), 1)
	cone_r := r * (0.55 + dist_t * 0.45)
	left := -math.PI * 0.5 - current.x
	right := -math.PI * 0.5 + current.x
	p0 := uifw.Vec2{center.x + math.cos(left) * cone_r, center.y + math.sin(left) * cone_r}
	p1 := uifw.Vec2{center.x + math.cos(right) * cone_r, center.y + math.sin(right) * cone_r}
	forward := uifw.Vec2{center.x, center.y - cone_r}
	changed := false
	if uifw.gui_drag_handle_region(gui, id, bounds, p1, 14) {
		fine := uifw.gui_pointer_fine_adjust_scale(gui, id)
		if fine < 1 {
			current.x = min(max(current.x + gui.mouse_delta.x / max(r, 1) * math.PI * fine, 0), math.PI)
			current.y = min(max(current.y - gui.mouse_delta.y / max(r, 1) * 500 * fine, 0), 500)
		} else {
			dx := gui.input.mouse_pos.x - center.x
			dy := gui.input.mouse_pos.y - center.y
			distance_from_center := math.sqrt(dx * dx + dy * dy)
			current.x = min(max(math.abs(math.atan2(dx, -dy)), 0), math.PI)
			current.y = min(max(((distance_from_center / max(r, 1)) - 0.55) / 0.45 * 500, 0), 500)
		}
		changed = true
	}
	_ = uifw.gui_update_focus_edit(gui, id, gui.focused == id)
	uifw.gui_controller_edit_vec2(gui, id, &current)
	nav_x, nav_y := uifw.gui_focused_nav_pressed(gui, id)
	if nav_x != 0 || nav_y != 0 {
		adjust_scale := uifw.gui_fine_adjust_scale(gui)
		current.x = min(max(current.x + nav_x * math.PI * 0.025 * adjust_scale, 0), math.PI)
		current.y = min(max(current.y - nav_y * 12.5 * adjust_scale, 0), 500)
		changed = true
	}
	if current.x != angle^ || current.y != distance^ {
		angle^ = current.x
		distance^ = current.y
		changed = true
	}
	dist_t = min(max(distance^ / 500.0, 0), 1)
	cone_r = r * (0.55 + dist_t * 0.45)
	left = -math.PI * 0.5 - angle^
	right = -math.PI * 0.5 + angle^
	p0 = {center.x + math.cos(left) * cone_r, center.y + math.sin(left) * cone_r}
	p1 = {center.x + math.cos(right) * cone_r, center.y + math.sin(right) * cone_r}
	forward = {center.x, center.y - cone_r}
	uifw.gui_round_rect(gui, bounds, 10, {1, 1, 1, 0.07})
	uifw.gui_round_stroke(gui, bounds, 10, {1, 1, 1, 0.13}, max(gui.style.border_width, 1))
	uifw.gui_line(gui, {visual.x, bounds.y + pad}, {visual.x, bounds.y + bounds.h - pad}, {1, 1, 1, 0.12}, max(gui.style.border_width, 1))
	uifw.gui_quad(gui, center, p0, forward, p1, {0.392, 0.424, 1.0, 0.26})
	uifw.gui_line(gui, center, p0, gui.style.accent, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, center, p1, gui.style.accent, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, center, forward, {1, 1, 1, 0.72}, max(gui.style.border_width, 1))
	center_radius := max(gui.style.row_height * 0.07, f32(5))
	handle_radius := max(gui.style.row_height * 0.14, f32(9))
	uifw.gui_ellipse(gui, {center.x - center_radius, center.y - center_radius, center_radius * 2, center_radius * 2}, gui.style.text)
	uifw.gui_ellipse(gui, {p1.x - handle_radius, p1.y - handle_radius, handle_radius * 2, handle_radius * 2}, gui.style.accent)
	uifw.gui_focus_or_edit_ring(gui, id, bounds)
	angle_degrees := angle^ * 180 / math.PI
	row_gap := min(max(gui.style.spacing_1, f32(4)), f32(8))
	row_h := max((info.h - row_gap) * 0.5, 1)
	angle_text := fmt.tprintf("ANGLE     %.0f°", angle_degrees)
	distance_text := fmt.tprintf("REACH     %.0f", distance^)
	value_scale := min(slime_controller_ui_fit_text_scale(gui, angle_text, 0.72, info.w), slime_controller_ui_fit_text_scale(gui, distance_text, 0.72, info.w))
	uifw.gui_text_aligned_scaled(gui, {info.x, info.y, info.w, row_h}, angle_text, gui.style.text, .Left, value_scale)
	uifw.gui_text_aligned_scaled(gui, {info.x, info.y + row_h + row_gap, info.w, row_h}, distance_text, gui.style.text, .Left, value_scale)
	shared_control_explanation(gui, "slime_sensor_cone", "Sensor Angle and Distance set how wide and how far ahead each agent can sense trails.")
	return changed
}

slime_controller_ui_draw_field :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	settings := sim.slime
	uifw.gui_label(gui, "Ink")
	if desc, ok := slime_control_descriptor_by_id(.Field_Deposit); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &settings.pheromone_deposition_rate)
	}
	uifw.gui_spacer(gui, 8)
	uifw.gui_label(gui, "Memory")
	_ = shared_two_axis_pad_f32(gui, "Trail Character", "slime_trail_character", "Fade", "Spread", &settings.pheromone_decay_rate, &settings.pheromone_diffusion_rate, 0, 200, 0, 200)
	shared_control_explanation(gui, "slime_trail_character", "Pheromone Fade controls how quickly trails vanish; Spread controls how far they diffuse.")
	if desc, ok := slime_control_descriptor_by_id(.Playback_Clear_Accumulation); ok {
		if slime_controller_ui_button(gui, desc) {
			slime_request_clear_trails(sim)
		}
	}
}

slime_controller_ui_draw_birth :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State, worker: ^Product_Context) {
	settings := sim.slime
	if desc, ok := slime_control_descriptor_by_id(.Initialization_Position_Distribution); ok {
		if uifw.gui_selector(gui, fmt.tprintf("%s: %s", desc.label, SLIME_POSITION_GENERATOR_NAMES[settings.position_generator_index]), desc.stable_id, &settings.position_generator_index, SLIME_POSITION_GENERATOR_NAMES[:]) {
			settings.position_generator = u32(settings.position_generator_index)
			slime_request_reset(sim)
		}
		shared_control_explanation(gui, desc.stable_id, desc.description)
	}
	if desc, ok := slime_control_descriptor_by_id(.Initialization_Seed); ok {
		if uifw.gui_numeric_u32(gui, desc.label, desc.stable_id, &settings.random_seed, 0, ~u32(0)) {
			slime_request_reset(sim)
		}
	}
	if desc, ok := slime_control_descriptor_by_id(.Playback_Randomize); ok {
		if slime_controller_ui_button(gui, desc, "Randomize Seed") {
			slime_randomize_seed(sim)
		}
	}
	if settings.position_generator == 7 {
		position_options := shared_default_image_selector_options()
		position_options.fit_label = "Position Image Fit"
		position_options.fit_key = "slime_controller_position_image_fit"
		position_options.load_label = "Reload Selected"
		position_options.load_key = "slime_controller_position_load_png"
		position_options.browse_label = "Choose Image..."
		position_options.browse_key = "slime_controller_position_browse_png"
		position_options.clear_label = "Clear Position Image"
		position_options.clear_key = "slime_controller_position_clear_image"
		position_options.selected_label = "Selected Position Image"
		position_options.empty_label = fmt.tprintf("No position image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
		position_options.selected_path = fixed_string(settings.position_image_path[:])
		position_result := shared_image_selector(gui, &settings.position_image_fit_index, VECTOR_IMAGE_FIT_MODE_NAMES[:], position_options)
		reload_position_image := false
		if position_result.fit_changed {
			settings.position_image_fit_mode = Vector_Image_Fit_Mode(settings.position_image_fit_index)
			reload_position_image = true
		}
		if position_result.browse_requested {
			sim.slime_position_image_dialog_requested = true
		}
		if position_result.load_requested || reload_position_image {
			remaining_sim_enqueue_image_command(worker, .Slime_Position, fixed_string(settings.position_image_path[:]))
			slime_request_reset(sim)
		}
		if position_result.clear_requested {
			remaining_sim_enqueue_image_command(worker, .Slime_Position, clear = true)
			slime_request_reset(sim)
		}
	}
}

slime_controller_ui_draw_world :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State, worker: ^Product_Context) {
	settings := sim.slime
	if desc, ok := slime_control_descriptor_by_id(.Mask_Source); ok {
		if uifw.gui_selector(gui, fmt.tprintf("%s: %s", desc.label, SLIME_MASK_PATTERN_NAMES[settings.mask_pattern_index]), desc.stable_id, &settings.mask_pattern_index, SLIME_MASK_PATTERN_NAMES[:]) {
			settings.mask_pattern = Slime_Mask_Pattern(settings.mask_pattern_index)
		}
		shared_control_explanation(gui, desc.stable_id, desc.description)
	}
	if desc, ok := slime_control_descriptor_by_id(.Mask_Target); ok {
		if uifw.gui_selector(gui, fmt.tprintf("%s: %s", desc.label, SLIME_MASK_TARGET_NAMES[settings.mask_target_index]), desc.stable_id, &settings.mask_target_index, SLIME_MASK_TARGET_NAMES[:]) {
			settings.mask_target = Slime_Mask_Target(settings.mask_target_index)
		}
		shared_control_explanation(gui, desc.stable_id, desc.description)
	}
	_ = shared_two_axis_pad_f32(gui, "Mask Response", "slime_mask_response", "Strength", "Curve", &settings.mask_strength, &settings.mask_curve, 0, 1, 0.1, 4)
	if settings.mask_pattern == .Image {
		mask_options := shared_default_image_selector_options()
		mask_options.fit_label = "Mask Image Fit"
		mask_options.fit_key = "slime_controller_mask_image_fit"
		mask_options.load_label = "Reload Selected"
		mask_options.load_key = "slime_controller_mask_load_png"
		mask_options.browse_label = "Choose Image..."
		mask_options.browse_key = "slime_controller_mask_browse_png"
		mask_options.clear_label = "Clear Mask Image"
		mask_options.clear_key = "slime_controller_mask_clear_image"
		mask_options.selected_label = "Selected Mask Image"
		mask_options.empty_label = fmt.tprintf("No mask image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
		mask_options.selected_path = fixed_string(settings.mask_image_path[:])
		mask_result := shared_image_selector(gui, &settings.mask_image_fit_index, VECTOR_IMAGE_FIT_MODE_NAMES[:], mask_options)
		reload_mask_image := false
		if mask_result.fit_changed {
			settings.mask_image_fit_mode = Vector_Image_Fit_Mode(settings.mask_image_fit_index)
			reload_mask_image = true
		}
		if mask_result.browse_requested {
			sim.slime_mask_image_dialog_requested = true
		}
		if mask_result.load_requested || reload_mask_image {
			remaining_sim_enqueue_image_command(worker, .Slime_Mask, fixed_string(settings.mask_image_path[:]))
		}
		if mask_result.clear_requested {
			remaining_sim_enqueue_image_command(worker, .Slime_Mask, clear = true)
		}
	}
	if desc, ok := slime_control_descriptor_by_id(.Mask_Mirror_X); ok {
		_ = uifw.gui_toggle(gui, settings.mask_mirror_horizontal ? "Mirror X: On" : "Mirror X: Off", desc.stable_id, &settings.mask_mirror_horizontal)
	}
	if desc, ok := slime_control_descriptor_by_id(.Mask_Mirror_Y); ok {
		_ = uifw.gui_toggle(gui, settings.mask_mirror_vertical ? "Mirror Y: On" : "Mirror Y: Off", desc.stable_id, &settings.mask_mirror_vertical)
	}
	if desc, ok := slime_control_descriptor_by_id(.Mask_Invert); ok {
		_ = uifw.gui_toggle(gui, settings.mask_invert_tone ? "Invert: On" : "Invert: Off", desc.stable_id, &settings.mask_invert_tone)
	}
}

slime_controller_ui_draw_capture :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, worker: ^Product_Context) {
	if desc, ok := slime_control_descriptor_by_id(.Capture_Record); ok {
		if slime_controller_ui_button(gui, desc, app_ui_video_recording_button_label(ui)) {
			app_ui_video_recording_toggle(ui, worker)
		}
	}
}
