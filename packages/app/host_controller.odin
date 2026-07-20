package app

import uifw "zelda_engine:ui"

import sdl "vendor:sdl3"

app_apply_settings :: proc(app: ^App_State, settings: App_Settings) {
	if app == nil {
		return
	}
	if app_controller_south_is_accept(app.settings) != app_controller_south_is_accept(settings) {
		// A layout swap can occur while a face button is held. Release the old
		// semantic owner now; require a fresh press under the new profile.
		app_release_controller_face_actions(app)
	}
	if app_controller_start_is_pause(app.settings) != app_controller_start_is_pause(settings) {
		app.controller_action_released.pause = app.controller_action_released.pause || app.controller_pause_down
		app.controller_action_released.toggle_ui = app.controller_action_released.toggle_ui || app.controller_toggle_ui_down
		app.controller_pause_down = false
		app.controller_toggle_ui_down = false
		app.controller_pause_pressed = false
		app.controller_toggle_ui_pressed = false
		app.controller_north_down = false
		app.controller_start_down = false
		app.controller_view_down = false
		app.input.pause = false
		app.input.toggle_ui = false
	}
	if app_controller_right_shoulder_is_next(app.settings) != app_controller_right_shoulder_is_next(settings) {
		app.controller_action_released.focus_next = app.controller_action_released.focus_next || app.controller_focus_next_down
		app.controller_action_released.focus_prev = app.controller_action_released.focus_prev || app.controller_focus_prev_down
		app.controller_focus_next_down = false
		app.controller_focus_prev_down = false
		app.controller_left_shoulder_down = false
		app.controller_right_shoulder_down = false
		app.input.focus_next = false
		app.input.focus_prev = false
	}
	if app_controller_right_trigger_is_primary(app.settings) != app_controller_right_trigger_is_primary(settings) {
		app.controller_action_released.primary = app.controller_action_released.primary || app_controller_primary_trigger_down(app)
		app.controller_action_released.secondary = app.controller_action_released.secondary || (app_controller_secondary_down(app) && !app.controller_secondary_button_down)
		app.controller_left_trigger = 0
		app.controller_right_trigger = 0
		app.controller_left_trigger_down = false
		app.controller_right_trigger_down = false
		app.controller_left_trigger_prev_down = false
		app.controller_right_trigger_prev_down = false
		app.controller_left_trigger_event_down = false
		app.controller_right_trigger_event_down = false
		app.input.primary_pressed = false
		app.input.primary_released = false
		if !app.controller_secondary_button_down {
			app.input.secondary_pressed = false
			app.input.secondary_released = false
		}
	}
	if settings_effective_keyboard_binding(app.settings, .Pause) != settings_effective_keyboard_binding(settings, .Pause) ||
	   settings_effective_keyboard_binding(app.settings, .Toggle_Ui) != settings_effective_keyboard_binding(settings, .Toggle_Ui) ||
	   settings_effective_keyboard_binding(app.settings, .Help) != settings_effective_keyboard_binding(settings, .Help) {
		app.keyboard_action_released.pause = app.keyboard_action_released.pause || app.keyboard_pause_down
		app.keyboard_action_released.help = app.keyboard_action_released.help || app.keyboard_help_down
		app.keyboard_action_released.toggle_ui = app.keyboard_action_released.toggle_ui || app.keyboard_toggle_ui_down
		app.keyboard_pause_down = false
		app.keyboard_help_down = false
		app.keyboard_toggle_ui_down = false
		app.keyboard_pause_pressed = false
		app.keyboard_help_pressed = false
		app.keyboard_toggle_ui_pressed = false
		app.input.pause = false
		app.input.key_f1 = false
		app.input.toggle_ui = false
	}
	app.settings = settings
}

app_apply_gamepad_button :: proc(app: ^App_State, button: sdl.GamepadButton, down: bool) {
	#partial switch button {
	case .SOUTH, .EAST:
		south := button == .SOUTH
		accept := south == app_controller_south_is_accept(app.settings)
		if accept {
			if !down && app.controller_accept_down {app.controller_action_released.accept = true}
			app.controller_accept_down = down
			if down {app.input.accept = true}
		} else {
			if !down && app.controller_back_down {app.controller_action_released.back = true}
			app.controller_back_down = down
			if down {app.input.back = true}
		}
	case .WEST:
		if !down && app.controller_secondary_button_down {app.controller_action_released.secondary = true}
		app.controller_secondary_button_down = down
		if down {app.input.secondary_pressed = true} else {app.input.secondary_released = true}
	case .NORTH, .BACK, .START:
		app_apply_controller_menu_button(app, button, down)
	case .GUIDE:
		if !down && app.controller_help_down {app.controller_action_released.help = true}
		app.controller_help_down = down
		if down {app.controller_help_pressed = true}
	case .DPAD_LEFT:
		if down {app.controller_nav_pressed_x = -1}
		app.controller_dpad_x = down ? f32(-1) : (app.controller_dpad_x < 0 ? f32(0) : app.controller_dpad_x)
	case .DPAD_RIGHT:
		if down {app.controller_nav_pressed_x = 1}
		app.controller_dpad_x = down ? f32(1) : (app.controller_dpad_x > 0 ? f32(0) : app.controller_dpad_x)
	case .DPAD_UP:
		if down {app.controller_nav_pressed_y = -1}
		app.controller_dpad_y = down ? f32(-1) : (app.controller_dpad_y < 0 ? f32(0) : app.controller_dpad_y)
	case .DPAD_DOWN:
		if down {app.controller_nav_pressed_y = 1}
		app.controller_dpad_y = down ? f32(1) : (app.controller_dpad_y > 0 ? f32(0) : app.controller_dpad_y)
	case .RIGHT_SHOULDER:
		app_apply_controller_shoulder_button(app, button, down)
	case .LEFT_SHOULDER:
		app_apply_controller_shoulder_button(app, button, down)
	case .LEFT_STICK:
		if !down && app.controller_camera_reset_down {app.controller_action_released.camera_reset = true}
		app.controller_camera_reset_down = down
		if down {app.controller_camera_reset_pressed = true}
	}
}

app_append_text_input :: proc(app: ^App_State, text: cstring) {
	if text == nil {
		return
	}
	src := cast([^]u8)text
	i := 0
	for src[i] != 0 && app.input.text_input_len < len(app.input.text_input) {
		app.input.text_input[app.input.text_input_len] = src[i]
		app.input.text_input_len += 1
		i += 1
	}
}

app_read_clipboard_paste :: proc(app: ^App_State) {
	if !sdl.HasClipboardText() {
		return
	}
	text := sdl.GetClipboardText()
	if text == nil {
		return
	}
	defer sdl.free(text)
	src := cast([^]u8)text
	i := 0
	for src[i] != 0 && app.input.clipboard_paste_len < len(app.input.clipboard_paste) {
		app.input.clipboard_paste[app.input.clipboard_paste_len] = src[i]
		app.input.clipboard_paste_len += 1
		i += 1
	}
}

app_gamepad_axis_value :: proc(app: ^App_State, axis: sdl.GamepadAxis) -> f32 {
	if app.gamepad == nil {
		return 0
	}
	raw := sdl.GetGamepadAxis(app.gamepad, axis)
	if raw < 0 {
		return max(f32(raw) / 32768.0, -1)
	}
	return min(f32(raw) / 32767.0, 1)
}

app_apply_deadzone :: proc(value, deadzone: f32) -> f32 {
	mag := value < 0 ? -value : value
	if mag <= deadzone {
		return 0
	}
	scaled := (mag - deadzone) / max(1 - deadzone, 0.0001)
	return value < 0 ? -scaled : scaled
}

app_controller_axis_pair :: proc(app: ^App_State, x_axis, y_axis: sdl.GamepadAxis) -> uifw.Vec2 {
	raw := uifw.Vec2{
		app_gamepad_axis_value(app, x_axis),
		app_gamepad_axis_value(app, y_axis),
	}
	return input_action_apply_radial_deadzone(raw, app_controller_deadzone(app))
}

app_controller_trigger_value :: proc(app: ^App_State, axis: sdl.GamepadAxis) -> f32 {
	raw := app_gamepad_axis_value(app, axis)
	if raw < 0 {
		return 0
	}
	return min(max(raw, 0), 1)
}

app_gamepad_event_axis_value :: proc(raw: i16) -> f32 {
	if raw < 0 {
		return max(f32(raw) / 32768.0, -1)
	}
	return min(f32(raw) / 32767.0, 1)
}

app_note_gamepad_axis_event :: proc(app: ^App_State, axis: sdl.GamepadAxis, raw: i16) {
	value := max(app_gamepad_event_axis_value(raw), 0)
	#partial switch axis {
	case .RIGHT_TRIGGER:
		down := value >= INPUT_CONTROLLER_TRIGGER_THRESHOLD
		primary := app_controller_right_trigger_is_primary(app.settings)
		if down && !app.controller_right_trigger_event_down {
			if primary {app.input.primary_pressed = true} else {app.input.secondary_pressed = true}
		}
		if !down && app.controller_right_trigger_event_down {
			if primary {app.input.primary_released = true} else {app.input.secondary_released = true}
		}
		app.controller_right_trigger_event_down = down
	case .LEFT_TRIGGER:
		down := value >= INPUT_CONTROLLER_TRIGGER_THRESHOLD
		primary := !app_controller_right_trigger_is_primary(app.settings)
		if down && !app.controller_left_trigger_event_down {
			if primary {app.input.primary_pressed = true} else {app.input.secondary_pressed = true}
		}
		if !down && app.controller_left_trigger_event_down {
			if primary {app.input.primary_released = true} else {app.input.secondary_released = true}
		}
		app.controller_left_trigger_event_down = down
	case:
	}
}

app_gamepad_axis_event_is_meaningful :: proc(app: ^App_State, axis: sdl.GamepadAxis) -> bool {
	#partial switch axis {
	case .LEFTX, .LEFTY:
		value := app_controller_axis_pair(app, .LEFTX, .LEFTY)
		return value.x != 0 || value.y != 0 || app.controller_left.x != 0 || app.controller_left.y != 0
	case .RIGHTX, .RIGHTY:
		value := app_controller_axis_pair(app, .RIGHTX, .RIGHTY)
		return value.x != 0 || value.y != 0 || app.controller_right.x != 0 || app.controller_right.y != 0
	case .LEFT_TRIGGER:
		return app_controller_trigger_value(app, .LEFT_TRIGGER) >= INPUT_CONTROLLER_TRIGGER_THRESHOLD || app.controller_left_trigger_down
	case .RIGHT_TRIGGER:
		return app_controller_trigger_value(app, .RIGHT_TRIGGER) >= INPUT_CONTROLLER_TRIGGER_THRESHOLD || app.controller_right_trigger_down
	case:
	}
	return false
}

app_update_controller_state :: proc(app: ^App_State, delta_time: f32, window_width, window_height: i32) {
	app.controller_left_trigger_prev_down = app.controller_left_trigger_down
	app.controller_right_trigger_prev_down = app.controller_right_trigger_down

	if app.gamepad == nil {
		app.controller_left = {}
		app.controller_right = {}
		app.controller_left_trigger = 0
		app.controller_right_trigger = 0
		app.controller_left_trigger_down = false
		app.controller_right_trigger_down = false
		return
	}

	app.controller_left = app_controller_axis_pair(app, .LEFTX, .LEFTY)
	app.controller_right = app_controller_axis_pair(app, .RIGHTX, .RIGHTY)
	app.controller_left_trigger = app_controller_trigger_value(app, .LEFT_TRIGGER)
	app.controller_right_trigger = app_controller_trigger_value(app, .RIGHT_TRIGGER)
	app.controller_left_trigger_down = app.controller_left_trigger >= INPUT_CONTROLLER_TRIGGER_THRESHOLD
	app.controller_right_trigger_down = app.controller_right_trigger >= INPUT_CONTROLLER_TRIGGER_THRESHOLD

	left_active := app.controller_left.x != 0 || app.controller_left.y != 0
	right_active := app.controller_right.x != 0 || app.controller_right.y != 0

	if !app.virtual_cursor_initialized {
		app.virtual_cursor_pos = {f32(window_width) * 0.5, f32(window_height) * 0.5}
		app.virtual_cursor_initialized = true
	}
	if right_active {
		strength_x := app.controller_right.x * (app.controller_right.x < 0 ? -app.controller_right.x : app.controller_right.x)
		strength_y := app.controller_right.y * (app.controller_right.y < 0 ? -app.controller_right.y : app.controller_right.y)
		speed := max(f32(window_height), 480) * app_controller_cursor_speed(app)
		dt := max(delta_time, 1.0 / 240.0)
		app.virtual_cursor_pos.x += strength_x * speed * dt
		app.virtual_cursor_pos.y += strength_y * speed * dt
	}
	app.virtual_cursor_pos.x = min(max(app.virtual_cursor_pos.x, 0), max(f32(window_width) - 1, 0))
	app.virtual_cursor_pos.y = min(max(app.virtual_cursor_pos.y, 0), max(f32(window_height) - 1, 0))
}

app_controller_camera_zoom :: proc(app: ^App_State) -> f32 {
	zoom := -app.controller_dpad_y
	if zoom == 0 {
		// Preserve a quick D-pad tap that begins and ends between frames.
		zoom = -app.controller_nav_pressed_y
	}
	return min(max(zoom, -1), 1)
}

app_resolve_input_actions :: proc(app: ^App_State, delta_time: f32) -> Input_Action_Frame {
	keyboard_nav := uifw.Vec2{
		app_input_axis(app.input.key_right, app.input.key_left),
		app_input_axis(app.input.key_down, app.input.key_up),
	}
	controller_nav := uifw.Vec2{app.controller_dpad_x, app.controller_dpad_y}
	if controller_nav.x == 0 {
		controller_nav.x = app.controller_left.x
	}
	if controller_nav.y == 0 {
		controller_nav.y = app.controller_left.y
	}
	navigate := uifw.Vec2{
		min(max(keyboard_nav.x + controller_nav.x, -1), 1),
		min(max(keyboard_nav.y + controller_nav.y, -1), 1),
	}

	actions: Input_Action_Frame
	actions.navigate = input_action_resolve_navigation(
		&app.action_resolver,
		navigate,
		delta_time,
		app_navigation_repeat_delay(app),
		app_navigation_repeat_interval(app),
	)
	actions.navigate.pressed.x = min(max(actions.navigate.pressed.x + app.keyboard_nav_pressed_x + app.controller_nav_pressed_x, -1), 1)
	actions.navigate.pressed.y = min(max(actions.navigate.pressed.y + app.keyboard_nav_pressed_y + app.controller_nav_pressed_y, -1), 1)
	actions.accept = input_action_resolve_button(&app.action_resolver.accept, {
		mouse_keyboard_down = app.keyboard_accept_down,
		controller_down = app.controller_accept_down,
		mouse_keyboard_pressed = app.input.key_enter,
		controller_pressed = app.input.accept,
		mouse_keyboard_released = app.keyboard_action_released.accept,
		controller_released = app.controller_action_released.accept,
	})
	actions.back = input_action_resolve_button(&app.action_resolver.back, {
		mouse_keyboard_down = app.keyboard_back_down,
		controller_down = app.controller_back_down,
		mouse_keyboard_pressed = app.input.key_escape,
		controller_pressed = app.input.back,
		mouse_keyboard_released = app.keyboard_action_released.back,
		controller_released = app.controller_action_released.back,
	})
	actions.pause = input_action_resolve_button(&app.action_resolver.pause, {
		mouse_keyboard_down = app.keyboard_pause_down,
		controller_down = app.controller_pause_down,
		mouse_keyboard_pressed = app.keyboard_pause_pressed,
		controller_pressed = app.controller_pause_pressed || (app.input.pause && !app.keyboard_pause_pressed),
		mouse_keyboard_released = app.keyboard_action_released.pause,
		controller_released = app.controller_action_released.pause,
	})
	actions.help = input_action_resolve_button(&app.action_resolver.help, {
		mouse_keyboard_down = app.keyboard_help_down,
		controller_down = app.controller_help_down,
		mouse_keyboard_pressed = app.keyboard_help_pressed,
		controller_pressed = app.controller_help_pressed,
		mouse_keyboard_released = app.keyboard_action_released.help,
		controller_released = app.controller_action_released.help,
	})
	actions.toggle_ui = input_action_resolve_button(&app.action_resolver.toggle_ui, {
		mouse_keyboard_down = app.keyboard_toggle_ui_down,
		controller_down = app.controller_toggle_ui_down,
		mouse_keyboard_pressed = app.keyboard_toggle_ui_pressed,
		controller_pressed = app.controller_toggle_ui_pressed || (app.input.toggle_ui && !app.keyboard_toggle_ui_pressed),
		mouse_keyboard_released = app.keyboard_action_released.toggle_ui,
		controller_released = app.controller_action_released.toggle_ui,
	})
	actions.control_deck = input_action_resolve_button(&app.action_resolver.control_deck, {
		mouse_keyboard_down = false,
		mouse_keyboard_pressed = app.input.key_space || app.input.key_space_pressed,
		mouse_keyboard_released = app.keyboard_action_released.control_deck,
	})
	actions.focus_next = input_action_resolve_button(&app.action_resolver.focus_next, {
		mouse_keyboard_down = app.keyboard_tab_down && !app.keyboard_tab_shifted,
		controller_down = app.controller_focus_next_down,
		mouse_keyboard_pressed = app.input.key_tab && !app.keyboard_tab_shifted && !app.keyboard_tab_repeated,
		controller_pressed = app.input.focus_next,
		mouse_keyboard_repeated = app.keyboard_tab_repeated && !app.keyboard_tab_shifted,
		mouse_keyboard_released = app.keyboard_action_released.focus_next,
		controller_released = app.controller_action_released.focus_next,
	})
	actions.focus_prev = input_action_resolve_button(&app.action_resolver.focus_prev, {
		mouse_keyboard_down = app.keyboard_tab_down && app.keyboard_tab_shifted,
		controller_down = app.controller_focus_prev_down,
		mouse_keyboard_pressed = app.input.key_tab && app.keyboard_tab_shifted && !app.keyboard_tab_repeated,
		controller_pressed = app.input.focus_prev,
		mouse_keyboard_repeated = app.keyboard_tab_repeated && app.keyboard_tab_shifted,
		mouse_keyboard_released = app.keyboard_action_released.focus_prev,
		controller_released = app.controller_action_released.focus_prev,
	})

	mouse_primary_down := app.input.mouse_down && app.input.mouse_button != 3
	mouse_secondary_down := app.input.mouse_down && app.input.mouse_button == 3
	actions.primary = input_action_resolve_button(&app.action_resolver.primary, {
		mouse_keyboard_down = mouse_primary_down,
		controller_down = app_controller_primary_trigger_down(app),
		mouse_keyboard_pressed = app.input.mouse_pressed && app.input.mouse_button != 3,
		controller_pressed = app.input.primary_pressed || (app_controller_primary_trigger_down(app) && !app_controller_primary_trigger_prev_down(app)),
		mouse_keyboard_released = app.input.mouse_released && app.input.mouse_button != 3,
		controller_released = app.input.primary_released || app.controller_action_released.primary,
	})
	actions.secondary = input_action_resolve_button(&app.action_resolver.secondary, {
		mouse_keyboard_down = mouse_secondary_down,
		controller_down = app_controller_secondary_down(app),
		mouse_keyboard_pressed = app.input.mouse_pressed && app.input.mouse_button == 3,
		controller_pressed = app.input.secondary_pressed || (app_controller_secondary_down(app) && !app_controller_secondary_trigger_prev_down(app)),
		mouse_keyboard_released = app.input.mouse_released && app.input.mouse_button == 3,
		controller_released = app.input.secondary_released || app.controller_action_released.secondary,
	})
	actions.camera_reset = input_action_resolve_button(&app.action_resolver.camera_reset, {
		mouse_keyboard_down = app.input.key_c,
		controller_down = app.controller_camera_reset_down,
		mouse_keyboard_pressed = app.keyboard_camera_reset_pressed,
		controller_pressed = app.controller_camera_reset_pressed,
		mouse_keyboard_released = app.keyboard_action_released.camera_reset,
		controller_released = app.controller_action_released.camera_reset,
	})
	actions.camera_pan = {
		min(max(app_input_axis(app.input.key_right || app.input.key_d, app.input.key_left || app.input.key_a) + app.controller_left.x, -1), 1),
		min(max(app_input_axis(app.input.key_down || app.input.key_s, app.input.key_up || app.input.key_w) + app.controller_left.y, -1), 1),
	}
	actions.camera_zoom = min(max(app_input_axis(app.input.key_e, app.input.key_q) + app_controller_camera_zoom(app), -1), 1)
	return actions
}

app_pointer_device_for_actions :: proc(actions: Input_Action_Frame, fallback: uifw.Input_Device_Kind) -> uifw.Input_Device_Kind {
	if actions.primary.down || actions.primary.pressed || actions.primary.released {
		if actions.primary.owner == .Controller {return .Controller}
		if actions.primary.owner == .Mouse_Keyboard {return .Mouse_Keyboard}
	}
	if actions.secondary.down || actions.secondary.pressed || actions.secondary.released {
		if actions.secondary.owner == .Controller {return .Controller}
		if actions.secondary.owner == .Mouse_Keyboard {return .Mouse_Keyboard}
	}
	return fallback
}

// Frame input is an ordered event stream, not a mergeable state snapshot:
// opposite navigation taps, repeated accepts, text edits, and pointer
// positions must reach the render/UI owner in their original order. Keep only
// a small number of frames in flight so a producer faster than presentation
// cannot turn the command queue into seconds of input latency. The queue keeps
// its larger physical capacity for control-command bursts.
FRAME_INPUT_MAX_PENDING :: 2
