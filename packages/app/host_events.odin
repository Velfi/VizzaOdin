package app

import uifw "../ui"
import engine "../engine"

import "core:c"
import "core:strings"
import sdl "vendor:sdl3"

app_poll_events :: proc(app: ^App_State) {
	app.input.mouse_pressed = false
	app.input.mouse_released = false
	app.input.mouse_moved = false
	app.input.mouse_delta = {}
	app.input.mouse_button = app.held_mouse_button
	app.input.wheel_delta = 0
	app.input.wheel_delta_x = 0
	app.input.text_input = {}
	app.input.text_input_len = 0
	app.input.clipboard_paste = {}
	app.input.clipboard_paste_len = 0
	app.input.key_tab = false
	app.input.key_enter = false
	app.input.key_escape = false
	app.input.key_backspace = false
	app.input.key_delete = false
	app.input.key_home = false
	app.input.key_end = false
	app.input.key_f1 = false
	app.input.key_slash = false
	app.input.key_space = false
	app.input.key_space_pressed = false
	app.input.key_space_released = false
	app.input.accept = false
	app.input.back = false
	app.input.pause = false
	app.input.toggle_ui = false
	app.keyboard_pause_pressed = false
	app.keyboard_help_pressed = false
	app.keyboard_toggle_ui_pressed = false
	app.controller_pause_pressed = false
	app.controller_help_pressed = false
	app.controller_toggle_ui_pressed = false
	app.input.focus_next = false
	app.input.focus_prev = false
	app.input.primary_pressed = false
	app.input.primary_released = false
	app.input.secondary_pressed = false
	app.input.secondary_released = false
	app.keyboard_tab_repeated = false
	app.keyboard_action_released = {}
	app.controller_action_released = {}
	app.keyboard_nav_pressed_x = 0
	app.keyboard_nav_pressed_y = 0
	app.keyboard_camera_reset_pressed = false
	app.controller_nav_pressed_x = 0
	app.controller_nav_pressed_y = 0
	app.controller_camera_reset_pressed = false
	app.controller_left_trigger_event_down = app.controller_left_trigger_down
	app.controller_right_trigger_event_down = app.controller_right_trigger_down
	app.input.controller_connected = false
	app.input.controller_disconnected = false
	app.input.canvas_tool_slot = 0
	app.controller_connected_this_frame = false
	app.controller_disconnected_this_frame = false

	event: sdl.Event
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			app.running = false
		case .WINDOW_CLOSE_REQUESTED:
			app.running = false
		case .WINDOW_RESIZED, .WINDOW_PIXEL_SIZE_CHANGED:
			pw, ph: c.int
			_ = sdl.GetWindowSizeInPixels(app.window, &pw, &ph)
			cmd: Ui_To_Render_Command
			cmd.kind = .Resize
			cmd.width = i32(pw)
			cmd.height = i32(ph)
			_ = engine.queue_try_push(&app.ui_to_render, cmd)
			case .WINDOW_ENTER_FULLSCREEN:
				app_video_recording_process_fullscreen_preservation(app)
				app_video_recording_process_pending_start(app)
		case .MOUSE_MOTION:
			if event.motion.which == sdl.TOUCH_MOUSEID {
				continue
			}
			dx := event.motion.x - app.input.mouse_pos.x
			dy := event.motion.y - app.input.mouse_pos.y
			app.input.mouse_pos = {event.motion.x, event.motion.y}
			app.input.mouse_delta.x += dx
			app.input.mouse_delta.y += dy
			app.input.mouse_moved = true
			if dx * dx + dy * dy >= INPUT_MOUSE_MOVE_THRESHOLD * INPUT_MOUSE_MOVE_THRESHOLD {
				app_mark_mouse_keyboard_input(app)
			}
			app_reveal_hidden_system_cursor_from_mouse_input(app)
		case .MOUSE_BUTTON_DOWN:
			if event.button.which == sdl.TOUCH_MOUSEID {
				continue
			}
			app_apply_mouse_button_event(app, u32(event.button.button), event.button.x, event.button.y, true)
		case .MOUSE_BUTTON_UP:
			if event.button.which == sdl.TOUCH_MOUSEID {
				continue
			}
			app_apply_mouse_button_event(app, u32(event.button.button), event.button.x, event.button.y, false)
		case .FINGER_DOWN, .FINGER_MOTION, .FINGER_UP, .FINGER_CANCELED:
			app_apply_touch_finger_event(app, event.tfinger)
		case .MOUSE_WHEEL:
			app.input.wheel_delta_x += event.wheel.x
			app.input.wheel_delta += event.wheel.y
			if event.wheel.x != 0 || event.wheel.y != 0 {
				app_mark_mouse_keyboard_input(app)
				app_reveal_hidden_system_cursor_from_mouse_input(app)
			}
		case .KEY_DOWN:
			app_apply_key_event(app, event.key.key, event.key.scancode, true, event.key.repeat)
			app_mark_mouse_keyboard_input(app)
		case .KEY_UP:
			app_apply_key_event(app, event.key.key, event.key.scancode, false)
		case .TEXT_INPUT:
			app_append_text_input(app, event.text.text)
			app_mark_mouse_keyboard_input(app)
		case .GAMEPAD_ADDED:
			if app.gamepad == nil {
				app_open_gamepad(app, event.gdevice.which)
			}
		case .GAMEPAD_REMOVED:
			if app.gamepad != nil && event.gdevice.which == app.gamepad_id {
				app_close_gamepad(app)
			}
		case .GAMEPAD_AXIS_MOTION:
			axis := cast(sdl.GamepadAxis)event.gaxis.axis
			app_note_gamepad_axis_event(app, axis, event.gaxis.value)
			if app_gamepad_axis_event_is_meaningful(app, axis) {
				app_mark_controller_input(app)
			}
		case .GAMEPAD_BUTTON_DOWN:
			app_apply_gamepad_button(app, cast(sdl.GamepadButton)event.gbutton.button, true)
			app_mark_controller_input(app)
		case .GAMEPAD_BUTTON_UP:
			app_apply_gamepad_button(app, cast(sdl.GamepadButton)event.gbutton.button, false)
			app_mark_controller_input(app)
		}
	}
}

app_apply_mouse_button_event :: proc(app: ^App_State, button: u32, x, y: f32, down: bool) {
	app.input.mouse_pos = {x, y}
	if down && button == 1 && app.input.key_space_down {
		app.space_pan_consumed = true
	}
	if down {
		app.input.mouse_down = true
		app.input.mouse_pressed = true
		app.held_mouse_button = button
		app.input.mouse_button = app.held_mouse_button
	} else {
		app.input.mouse_down = false
		app.input.mouse_released = true
		app.input.mouse_button = button
		if app.held_mouse_button == button {
			app.held_mouse_button = 0
		}
	}
	app_mark_mouse_keyboard_input(app)
	app_reveal_hidden_system_cursor_from_mouse_input(app)
}

app_touch_logical_position :: proc(x, y: f32, width, height: i32) -> uifw.Vec2 {
	return {
		min(max(x, 0), 1) * f32(max(width - 1, 0)),
		min(max(y, 0), 1) * f32(max(height - 1, 0)),
	}
}

app_apply_touch_finger_event :: proc(app: ^App_State, event: sdl.TouchFingerEvent) {
	if app == nil || app.window == nil {
		return
	}
	width, height: c.int
	_ = sdl.GetWindowSize(app.window, &width, &height)
	position := app_touch_logical_position(event.x, event.y, i32(width), i32(height))

	#partial switch event.type {
	case .FINGER_DOWN:
		if app.touch_active {
			if !app.touch_secondary_active {
				// A second finger temporarily promotes the canvas gesture to the
				// paired secondary action. The first finger remains the brush cursor.
				app_apply_mouse_button_event(app, 1, app.input.mouse_pos.x, app.input.mouse_pos.y, false)
				app.touch_secondary_active = true
				app.touch_secondary_finger_id = event.fingerID
				app_apply_mouse_button_event(app, 3, app.input.mouse_pos.x, app.input.mouse_pos.y, true)
			}
			return
		}
		app.touch_active = true
		app.touch_finger_id = event.fingerID
		app_apply_mouse_button_event(app, 1, position.x, position.y, true)
	case .FINGER_MOTION:
		if !app.touch_active || event.fingerID != app.touch_finger_id {
			return
		}
		delta := uifw.Vec2{position.x - app.input.mouse_pos.x, position.y - app.input.mouse_pos.y}
		app.input.mouse_pos = position
		app.input.mouse_delta.x += delta.x
		app.input.mouse_delta.y += delta.y
		app.input.mouse_moved = true
		app_mark_mouse_keyboard_input(app)
	case .FINGER_UP, .FINGER_CANCELED:
		if app.touch_secondary_active && event.fingerID == app.touch_secondary_finger_id {
			app_apply_mouse_button_event(app, 3, app.input.mouse_pos.x, app.input.mouse_pos.y, false)
			app.touch_secondary_active = false
			if app.touch_active {
				app_apply_mouse_button_event(app, 1, app.input.mouse_pos.x, app.input.mouse_pos.y, true)
			}
			return
		}
		if app.touch_secondary_active && event.fingerID == app.touch_finger_id {
			app_apply_mouse_button_event(app, 3, position.x, position.y, false)
			app.touch_active = false
			app.touch_secondary_active = false
			return
		}
		if !app.touch_active || event.fingerID != app.touch_finger_id {
			return
		}
		app_apply_mouse_button_event(app, 1, position.x, position.y, false)
		app.touch_active = false
		app.touch_secondary_active = false
	}
}

app_mark_mouse_keyboard_input :: proc(app: ^App_State) {
	app.input_sequence += 1
	app.last_mouse_keyboard_input_sequence = app.input_sequence
	app.active_device = .Mouse_Keyboard
}

app_mark_controller_input :: proc(app: ^App_State) {
	app.input_sequence += 1
	app.last_controller_input_sequence = app.input_sequence
	app.active_device = .Controller
}

app_key_matches :: proc(key: sdl.Keycode, scancode: sdl.Scancode, expected_key: sdl.Keycode, expected_scancode: sdl.Scancode) -> bool {
	return key == expected_key || scancode == expected_scancode
}

app_key_is_confirm :: proc(key: sdl.Keycode, scancode: sdl.Scancode) -> bool {
	return key == sdl.K_RETURN || key == sdl.K_KP_ENTER || scancode == .RETURN || scancode == .KP_ENTER
}

app_key_is_non_repeating_action :: proc(key: sdl.Keycode, scancode: sdl.Scancode) -> bool {
	return app_key_is_confirm(key, scancode) ||
		app_key_matches(key, scancode, sdl.K_ESCAPE, .ESCAPE) ||
		app_key_matches(key, scancode, sdl.K_SLASH, .SLASH)
}

app_keyboard_uses_letter_shortcuts :: proc(settings: App_Settings) -> bool {
	return settings.keyboard_shortcut_profile == "Letter Shortcuts"
}

app_key_matches_shortcut :: proc(binding: Keyboard_Shortcut_Key, key: sdl.Keycode, scancode: sdl.Scancode) -> bool {
	switch binding {
	case .Space: return app_key_matches(key, scancode, sdl.K_SPACE, .SPACE)
	case .Slash: return app_key_matches(key, scancode, sdl.K_SLASH, .SLASH)
	case .F1: return app_key_matches(key, scancode, sdl.K_F1, .F1)
	case .P: return app_key_matches(key, scancode, sdl.K_P, .P)
	case .U: return app_key_matches(key, scancode, sdl.K_U, .U)
	case .H: return app_key_matches(key, scancode, sdl.K_H, .H)
	}
	return false
}

app_key_matches_pause_shortcut :: proc(settings: App_Settings, key: sdl.Keycode, scancode: sdl.Scancode) -> bool {
	return app_key_matches_shortcut(settings_effective_keyboard_binding(settings, .Pause), key, scancode)
}

app_key_matches_toggle_ui_shortcut :: proc(settings: App_Settings, key: sdl.Keycode, scancode: sdl.Scancode) -> bool {
	return app_key_matches_shortcut(settings_effective_keyboard_binding(settings, .Toggle_Ui), key, scancode)
}

app_key_matches_help_shortcut :: proc(settings: App_Settings, key: sdl.Keycode, scancode: sdl.Scancode) -> bool {
	return app_key_matches_shortcut(settings_effective_keyboard_binding(settings, .Help), key, scancode)
}

app_apply_key_event :: proc(app: ^App_State, key: sdl.Keycode, scancode: sdl.Scancode, down: bool, is_repeat := false) {
	// Confirm, Back, and UI toggle are single actions. SDL key repeats must not
	// re-open a screen or pop another focus scope while the key is still held.
	if down && is_repeat && app_key_is_non_repeating_action(key, scancode) {
		return
	}
	space_key := app_key_matches(key, scancode, sdl.K_SPACE, .SPACE)
	space_tap_release := space_key && !down && app.input.key_space_down && !app.space_pan_consumed
	if app_key_matches_pause_shortcut(app.settings, key, scancode) {
		if down && is_repeat {return}
		if space_key {
			// Space is both a standalone shortcut and the laptop pan modifier.
			// Resolve it on release so holding Space before clicking cannot pause
			// before the camera chord is known.
			app.keyboard_pause_down = false
			if space_tap_release {
				app.keyboard_pause_pressed = true
				app.keyboard_action_released.pause = true
				app.input.pause = true
			}
		} else {
			if !down && app.keyboard_pause_down {app.keyboard_action_released.pause = true}
			app.keyboard_pause_down = down
		}
		if down && !space_key {
			app.keyboard_pause_pressed = true
			app.input.pause = true
		}
		if !space_key {return}
	}
	if app_key_matches_toggle_ui_shortcut(app.settings, key, scancode) {
		if down && is_repeat {return}
		if !down && app.keyboard_toggle_ui_down {app.keyboard_action_released.toggle_ui = true}
		app.keyboard_toggle_ui_down = down
		if down {
			app.keyboard_toggle_ui_pressed = true
			app.input.toggle_ui = true
		}
		if !app_key_matches(key, scancode, sdl.K_SLASH, .SLASH) {return}
	}
	if app_key_matches_help_shortcut(app.settings, key, scancode) {
		if down && is_repeat {return}
		if !down && app.keyboard_help_down {app.keyboard_action_released.help = true}
		app.keyboard_help_down = down
		if down {
			app.keyboard_help_pressed = true
			app.input.key_f1 = true
		}
		return
	}
	if app_key_matches(key, scancode, sdl.K_TAB, .TAB) {
		if down && !app.keyboard_tab_down {
			app.input.key_tab = true
			app.keyboard_tab_shifted = app.input.key_shift
		} else if down && is_repeat {
			app.input.key_tab = true
			app.keyboard_tab_repeated = true
		}
		if !down && app.keyboard_tab_down {
			if app.keyboard_tab_shifted {
				app.keyboard_action_released.focus_prev = true
			} else {
				app.keyboard_action_released.focus_next = true
			}
		}
		app.keyboard_tab_down = down
	} else if app_key_is_confirm(key, scancode) {
		if !down && app.keyboard_accept_down {app.keyboard_action_released.accept = true}
		app.keyboard_accept_down = down
		if down {app.input.key_enter = true}
	} else if app_key_matches(key, scancode, sdl.K_ESCAPE, .ESCAPE) {
		if !down && app.keyboard_back_down {app.keyboard_action_released.back = true}
		app.keyboard_back_down = down
		if down {app.input.key_escape = true}
	} else if app_key_matches(key, scancode, sdl.K_BACKSPACE, .BACKSPACE) {
		app.input.key_backspace = down
	} else if app_key_matches(key, scancode, sdl.K_DELETE, .DELETE) {
		app.input.key_delete = down
	} else if app_key_matches(key, scancode, sdl.K_HOME, .HOME) {
		app.input.key_home = down
	} else if app_key_matches(key, scancode, sdl.K_END, .END) {
		app.input.key_end = down
	} else if app_key_matches(key, scancode, sdl.K_LEFT, .LEFT) {
		if down && !is_repeat {app.keyboard_nav_pressed_x = -1}
		app.input.key_left = down
	} else if app_key_matches(key, scancode, sdl.K_RIGHT, .RIGHT) {
		if down && !is_repeat {app.keyboard_nav_pressed_x = 1}
		app.input.key_right = down
	} else if down && !is_repeat && key >= sdl.K_1 && key <= sdl.K_4 {
		app.input.canvas_tool_slot = u32(key - sdl.K_1) + 1
	} else if app_key_matches(key, scancode, sdl.K_UP, .UP) {
		if down && !is_repeat {app.keyboard_nav_pressed_y = -1}
		app.input.key_up = down
	} else if app_key_matches(key, scancode, sdl.K_DOWN, .DOWN) {
		if down && !is_repeat {app.keyboard_nav_pressed_y = 1}
		app.input.key_down = down
	} else if app_key_matches(key, scancode, sdl.K_W, .W) {
		app.input.key_w = down
	} else if app_key_matches(key, scancode, sdl.K_A, .A) {
		app.input.key_a = down
	} else if app_key_matches(key, scancode, sdl.K_S, .S) {
		app.input.key_s = down
	} else if app_key_matches(key, scancode, sdl.K_D, .D) {
		app.input.key_d = down
	} else if app_key_matches(key, scancode, sdl.K_Q, .Q) {
		app.input.key_q = down
	} else if app_key_matches(key, scancode, sdl.K_E, .E) {
		app.input.key_e = down
	} else if app_key_matches(key, scancode, sdl.K_X, .X) {
		app.input.key_x = down
	} else if app_key_matches(key, scancode, sdl.K_V, .V) {
		app.input.key_v = down
		if down && (app.input.key_ctrl || app.input.key_super) {
			app_read_clipboard_paste(app)
		}
	} else if app_key_matches(key, scancode, sdl.K_C, .C) {
		if down && !is_repeat {app.keyboard_camera_reset_pressed = true}
		if !down && app.input.key_c {app.keyboard_action_released.camera_reset = true}
		app.input.key_c = down
	} else if app_key_matches(key, scancode, sdl.K_SLASH, .SLASH) {
		if down {app.input.key_slash = true}
	} else if app_key_matches(key, scancode, sdl.K_SPACE, .SPACE) {
		if down && !app.input.key_space_down {
			app.space_pan_consumed = false
		} else if !down && app.input.key_space_down {
			app.input.key_space_released = true
			app.keyboard_action_released.control_deck = true
			if space_tap_release {
				app.input.key_space = true
				app.input.key_space_pressed = true
			}
		}
		app.input.key_space_down = down
		if !down {app.space_pan_consumed = false}
	} else if key == sdl.K_LSHIFT || key == sdl.K_RSHIFT || scancode == .LSHIFT || scancode == .RSHIFT {
		app.input.key_shift = down
	} else if key == sdl.K_LCTRL || key == sdl.K_RCTRL || scancode == .LCTRL || scancode == .RCTRL {
		app.input.key_ctrl = down
	} else if key == sdl.K_LGUI || key == sdl.K_RGUI || scancode == .LGUI || scancode == .RGUI {
		app.input.key_super = down
	}
}

app_open_first_gamepad :: proc(app: ^App_State) {
	count: c.int
	ids := sdl.GetGamepads(&count)
	defer sdl.free(ids)
	for i in 0 ..< count {
		if app_open_gamepad(app, ids[i]) {
			return
		}
	}
}

app_open_gamepad :: proc(app: ^App_State, id: sdl.JoystickID) -> bool {
	if app.gamepad != nil {
		return true
	}
	gamepad := sdl.OpenGamepad(id)
	if gamepad == nil {
		engine.log_error("Gamepad open failed: ", sdl.GetError())
		return false
	}
	app.gamepad = gamepad
	app.gamepad_id = id
	name := sdl.GetGamepadName(gamepad)
	name_text := ""
	if name != nil {
		name_text = string(name)
	}
	app.controller_prompt_style = app_controller_prompt_style_for(sdl.GetGamepadType(gamepad), name_text)
	app.controller_connected_this_frame = true
	engine.log_info("Gamepad connected: ", name, " prompts=", app.controller_prompt_style)
	return true
}

app_controller_prompt_style_for :: proc(gamepad_type: sdl.GamepadType, name: string) -> uifw.Controller_Prompt_Style {
	// SDL does not expose Steam Deck as a distinct GamepadType. Its internal
	// controller is identified by name and can otherwise report a standard or
	// Xbox-shaped mapping, so check the name before the broad type fallback.
	if strings.contains(name, "Steam Deck") || strings.contains(name, "STEAM DECK") || strings.contains(name, "steam deck") {
		return .Steam_Deck
	}
	#partial switch gamepad_type {
	case .PS3, .PS4, .PS5:
		return .PlayStation
	case .XBOX360, .XBOXONE:
		return .Xbox
	case:
		return .Xbox
	}
}

app_close_gamepad :: proc(app: ^App_State) {
	if app.gamepad == nil {
		return
	}
	sdl.CloseGamepad(app.gamepad)
	app.gamepad = nil
	app.gamepad_id = 0
	app.controller_prompt_style = .Xbox
	app.controller_disconnected_this_frame = true
	app.controller_action_released.primary = app.controller_action_released.primary || app_controller_primary_trigger_down(app)
	app.controller_action_released.secondary = app.controller_action_released.secondary || app_controller_secondary_down(app)
	app.controller_left = {}
	app.controller_right = {}
	app.controller_left_trigger = 0
	app.controller_right_trigger = 0
	app.controller_left_trigger_down = false
	app.controller_right_trigger_down = false
	app.controller_left_trigger_event_down = false
	app.controller_right_trigger_event_down = false
	app.controller_action_released.accept = app.controller_action_released.accept || app.controller_accept_down
	app.controller_action_released.back = app.controller_action_released.back || app.controller_back_down
	app.controller_action_released.pause = app.controller_action_released.pause || app.controller_pause_down
	app.controller_action_released.help = app.controller_action_released.help || app.controller_help_down
	app.controller_action_released.toggle_ui = app.controller_action_released.toggle_ui || app.controller_toggle_ui_down
	app.controller_action_released.focus_next = app.controller_action_released.focus_next || app.controller_focus_next_down
	app.controller_action_released.focus_prev = app.controller_action_released.focus_prev || app.controller_focus_prev_down
	app.controller_action_released.camera_reset = app.controller_action_released.camera_reset || app.controller_camera_reset_down
	app.controller_dpad_x = 0
	app.controller_dpad_y = 0
	app.controller_nav_pressed_x = 0
	app.controller_nav_pressed_y = 0
	app.controller_accept_down = false
	app.controller_back_down = false
	app.controller_pause_down = false
	app.controller_help_down = false
	app.controller_north_down = false
	app.controller_start_down = false
	app.controller_view_down = false
	app.controller_toggle_ui_down = false
	app.controller_focus_next_down = false
	app.controller_focus_prev_down = false
	app.controller_left_shoulder_down = false
	app.controller_right_shoulder_down = false
	app.controller_secondary_button_down = false
	app.controller_camera_reset_pressed = false
	app.controller_camera_reset_down = false
}

app_controller_primary_trigger_down :: proc(app: ^App_State) -> bool {
	return app_controller_right_trigger_is_primary(app.settings) ? app.controller_right_trigger_down : app.controller_left_trigger_down
}

app_controller_secondary_down :: proc(app: ^App_State) -> bool {
	trigger_down := app_controller_right_trigger_is_primary(app.settings) ? app.controller_left_trigger_down : app.controller_right_trigger_down
	return trigger_down || app.controller_secondary_button_down
}

app_controller_primary_trigger_prev_down :: proc(app: ^App_State) -> bool {
	return app_controller_right_trigger_is_primary(app.settings) ? app.controller_right_trigger_prev_down : app.controller_left_trigger_prev_down
}

app_controller_secondary_trigger_prev_down :: proc(app: ^App_State) -> bool {
	return app_controller_right_trigger_is_primary(app.settings) ? app.controller_left_trigger_prev_down : app.controller_right_trigger_prev_down
}

app_apply_controller_shoulder_button :: proc(app: ^App_State, button: sdl.GamepadButton, down: bool) {
	old_next := app.controller_focus_next_down
	old_prev := app.controller_focus_prev_down
	if button == .RIGHT_SHOULDER {app.controller_right_shoulder_down = down}
	if button == .LEFT_SHOULDER {app.controller_left_shoulder_down = down}
	right_next := app_controller_right_shoulder_is_next(app.settings)
	app.controller_focus_next_down = right_next ? app.controller_right_shoulder_down : app.controller_left_shoulder_down
	app.controller_focus_prev_down = right_next ? app.controller_left_shoulder_down : app.controller_right_shoulder_down
	if old_next && !app.controller_focus_next_down {app.controller_action_released.focus_next = true}
	if old_prev && !app.controller_focus_prev_down {app.controller_action_released.focus_prev = true}
	if !old_next && app.controller_focus_next_down {app.input.focus_next = true}
	if !old_prev && app.controller_focus_prev_down {app.input.focus_prev = true}
}

app_apply_controller_menu_button :: proc(app: ^App_State, button: sdl.GamepadButton, down: bool) {
	old_pause := app.controller_pause_down
	old_toggle := app.controller_toggle_ui_down
	#partial switch button {
	case .NORTH: app.controller_north_down = down
	case .START: app.controller_start_down = down
	case .BACK: app.controller_view_down = down
	}
	start_pauses := app_controller_start_is_pause(app.settings)
	app.controller_pause_down = start_pauses ? app.controller_start_down : app.controller_view_down
	app.controller_toggle_ui_down = app.controller_north_down || (start_pauses ? app.controller_view_down : app.controller_start_down)
	if old_pause && !app.controller_pause_down {app.controller_action_released.pause = true}
	if old_toggle && !app.controller_toggle_ui_down {app.controller_action_released.toggle_ui = true}
	if !old_pause && app.controller_pause_down {
		app.controller_pause_pressed = true
		app.input.pause = true
	}
	if !old_toggle && app.controller_toggle_ui_down {
		app.controller_toggle_ui_pressed = true
		app.input.toggle_ui = true
	}
}

app_release_controller_face_actions :: proc(app: ^App_State) {
	if app == nil {
		return
	}
	app.controller_action_released.accept = app.controller_action_released.accept || app.controller_accept_down
	app.controller_action_released.back = app.controller_action_released.back || app.controller_back_down
	app.controller_accept_down = false
	app.controller_back_down = false
	app.input.accept = false
	app.input.back = false
}
