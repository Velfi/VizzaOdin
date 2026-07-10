package game

import uifw "../ui"
import engine "../engine"

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:sync"
import "core:time"
import sdl "vendor:sdl3"

App_State :: struct {
	window: ^sdl.Window,
	settings: App_Settings,
	ui_to_render: Ui_To_Render_Queue,
	render_to_ui: Render_To_Ui_Queue,
	render_thread: ^sdl.Thread,
	render_worker: Render_Worker_State,
	render_runtime: Render_Worker_Runtime,
	frame_processor_mode: Frame_Processor_Mode,
	mcp_bridge: Mcp_Bridge,
	screenshot: engine.Screenshot_State,
	steam: Steam_Client,
	mcp_enabled: bool,
	running: bool,
	frame_index: u64,
	last_frame_tick: time.Tick,
	input: uifw.Input_State,
	held_mouse_button: u32,
	input_sequence: u64,
	last_mouse_keyboard_input_sequence: u64,
	last_controller_input_sequence: u64,
	active_device: uifw.Input_Device_Kind,
	action_resolver: Input_Action_Resolver,
	keyboard_action_released: Input_Action_Release_Pulses,
	controller_action_released: Input_Action_Release_Pulses,
	keyboard_accept_down: bool,
	keyboard_back_down: bool,
	keyboard_pause_down: bool,
	keyboard_pause_pressed: bool,
	keyboard_help_down: bool,
	keyboard_help_pressed: bool,
	keyboard_toggle_ui_down: bool,
	keyboard_toggle_ui_pressed: bool,
	keyboard_tab_down: bool,
	keyboard_tab_shifted: bool,
	keyboard_tab_repeated: bool,
	keyboard_nav_pressed_x: f32,
	keyboard_nav_pressed_y: f32,
	keyboard_camera_reset_pressed: bool,
	virtual_cursor_pos: uifw.Vec2,
	virtual_cursor_initialized: bool,
	ui_system_cursor_hidden: bool,
	system_cursor_transparent: bool,
	text_input_active: bool,
	transparent_cursor: ^sdl.Cursor,
	controller_connected_this_frame: bool,
	controller_disconnected_this_frame: bool,
	controller_dpad_x: f32,
	controller_dpad_y: f32,
	controller_nav_pressed_x: f32,
	controller_nav_pressed_y: f32,
	controller_accept_down: bool,
	controller_back_down: bool,
	controller_pause_down: bool,
	controller_pause_pressed: bool,
	controller_help_down: bool,
	controller_help_pressed: bool,
	controller_north_down: bool,
	controller_start_down: bool,
	controller_view_down: bool,
	controller_toggle_ui_down: bool,
	controller_toggle_ui_pressed: bool,
	controller_focus_next_down: bool,
	controller_focus_prev_down: bool,
	controller_left_shoulder_down: bool,
	controller_right_shoulder_down: bool,
	controller_secondary_button_down: bool,
	controller_camera_reset_pressed: bool,
	controller_camera_reset_down: bool,
	controller_left: uifw.Vec2,
	controller_right: uifw.Vec2,
	controller_left_trigger: f32,
	controller_right_trigger: f32,
	controller_left_trigger_down: bool,
	controller_right_trigger_down: bool,
	controller_left_trigger_prev_down: bool,
	controller_right_trigger_prev_down: bool,
	controller_left_trigger_event_down: bool,
	controller_right_trigger_event_down: bool,
	gamepad: ^sdl.Gamepad,
	gamepad_id: sdl.JoystickID,
	theme_preview: bool,
	video_recording_pending_start: bool,
	video_recording_restore_fullscreen: bool,
	video_recording_restore_attempts: u32,
	video_recording_preserve_fullscreen: bool,
	video_recording_preserve_fullscreen_attempts: u32,
	video_recording_pending_path: [MAX_FILE_PATH]u8,
}

App_Run_Config :: struct {
	mcp_enabled: bool,
	theme_preview: bool,
	steam_override: Steam_Enabled_Override,
	steam_app_id_override: u32,
	steam_library_path_override: string,
}

INPUT_MOUSE_MOVE_THRESHOLD :: f32(2.0)
INPUT_CONTROLLER_DEADZONE :: f32(0.25)
INPUT_CONTROLLER_TRIGGER_THRESHOLD :: f32(0.30)
INPUT_CONTROLLER_CURSOR_SPEED :: f32(0.72)

app_controller_deadzone :: proc(app: ^App_State) -> f32 {
	if app != nil && app.settings.controller_deadzone > 0 {
		return min(max(app.settings.controller_deadzone, 0.05), 0.60)
	}
	return INPUT_CONTROLLER_DEADZONE
}

app_controller_cursor_speed :: proc(app: ^App_State) -> f32 {
	if app != nil && app.settings.controller_cursor_speed > 0 {
		return min(max(app.settings.controller_cursor_speed, 0.20), 2.0)
	}
	return INPUT_CONTROLLER_CURSOR_SPEED
}

app_navigation_repeat_delay :: proc(app: ^App_State) -> f32 {
	if app != nil && app.settings.navigation_repeat_delay_ms > 0 {
		return f32(min(max(app.settings.navigation_repeat_delay_ms, 150), 1000)) / 1000.0
	}
	return INPUT_ACTION_REPEAT_DELAY
}

app_navigation_repeat_interval :: proc(app: ^App_State) -> f32 {
	if app != nil && app.settings.navigation_repeat_interval_ms > 0 {
		return f32(min(max(app.settings.navigation_repeat_interval_ms, 30), 300)) / 1000.0
	}
	return INPUT_ACTION_REPEAT_INTERVAL
}

NUTRIENT_IMAGE_FILTER_NAME :: cstring("Images")
NUTRIENT_IMAGE_FILTER_PATTERN :: cstring(IMAGE_FILE_FILTER_PATTERN)
NUTRIENT_IMAGE_DIALOG_FILTERS := [?]sdl.DialogFileFilter {
	{name = NUTRIENT_IMAGE_FILTER_NAME, pattern = NUTRIENT_IMAGE_FILTER_PATTERN},
}
VIDEO_FILE_FILTER_NAME :: cstring("MP4 Video")
VIDEO_FILE_FILTER_PATTERN :: cstring("mp4")
VIDEO_FILE_DIALOG_FILTERS := [?]sdl.DialogFileFilter {
	{name = VIDEO_FILE_FILTER_NAME, pattern = VIDEO_FILE_FILTER_PATTERN},
}
VIDEO_RECORDING_FULLSCREEN_RESTORE_MAX_FRAMES :: u32(180)

app_run :: proc(config: App_Run_Config = {}) -> int {
	app := new(App_State)
	defer free(app)
	defer engine.screenshot_state_destroy(&app.screenshot)
	app.mcp_enabled = config.mcp_enabled
	app.theme_preview = config.theme_preview

	settings_path := settings_app_config_path()
	settings_loaded: bool
	app.settings, settings_loaded = settings_load_app(settings_path)
	if !settings_loaded && settings_path != "config/app.toml" {
		app.settings, _ = settings_load_app("config/app.toml")
	}
	steam_config := steam_config_resolve(app.settings, config)
	steam_state := steam_client_init(&app.steam, steam_config)
	defer steam_client_shutdown(&app.steam)
	if steam_state == .Restart_Requested {
		return 0
	}

	if !sdl.Init({.VIDEO, .EVENTS, .GAMEPAD, .CAMERA}) {
		engine.log_error("SDL init failed: ", sdl.GetError())
		return 1
	}
	defer sdl.Quit()
	sdl.SetGamepadEventsEnabled(true)

	flags := sdl.WINDOW_VULKAN | sdl.WINDOW_RESIZABLE | sdl.WINDOW_HIGH_PIXEL_DENSITY
	app.window = sdl.CreateWindow("Vizza", c.int(app.settings.window_width), c.int(app.settings.window_height), flags)
	if app.window == nil {
		engine.log_error("SDL window creation failed: ", sdl.GetError())
		return 1
	}
	if app.settings.window_maximized {
		sdl.MaximizeWindow(app.window)
	}
	defer sdl.DestroyWindow(app.window)
	app.transparent_cursor = app_create_transparent_cursor()
	defer app_destroy_transparent_cursor(app)
	defer {
		app_set_system_cursor_transparent(app, false)
		if app.text_input_active {
			_ = sdl.StopTextInput(app.window)
		}
	}
	initial_w, initial_h: c.int
	initial_px_w, initial_px_h: c.int
	_ = sdl.GetWindowSize(app.window, &initial_w, &initial_h)
	_ = sdl.GetWindowSizeInPixels(app.window, &initial_px_w, &initial_px_h)
	engine.log_info("app_run: window logical=", initial_w, "x", initial_h, " pixels=", initial_px_w, "x", initial_px_h, " mcp=", app.mcp_enabled)
	app_open_first_gamepad(app)
	defer app_close_gamepad(app)

	if app.mcp_enabled && !mcp_bridge_start(&app.mcp_bridge) {
		engine.log_error("MCP bridge creation failed: ", sdl.GetError())
	} else if app.mcp_enabled {
		app.mcp_bridge.screenshot = &app.screenshot
		defer mcp_bridge_stop(&app.mcp_bridge)
	}

	app.render_worker = {
		ui_to_render = &app.ui_to_render,
		render_to_ui = &app.render_to_ui,
		settings = app.settings,
		vulkan_window = app.window,
		initial_pixel_width = i32(initial_px_w),
		initial_pixel_height = i32(initial_px_h),
		screenshot = nil,
		theme_preview = app.theme_preview,
	}
	if app.mcp_enabled {
		app.render_worker.screenshot = &app.screenshot
	}

	if !frame_processor_bootstrap(app) {
		return 1
	}
	defer frame_processor_shutdown(app)

	app.running = true
	app.last_frame_tick = time.tick_now()
	for app.running {
		app_loop_tick(app)
	}

	return 0
}

app_loop_tick :: proc(app: ^App_State) {
	frame_start := time.tick_now()
	app_poll_events(app)
	steam_client_tick(&app.steam)
	if app.mcp_enabled {
		mcp_bridge_poll_stdio(&app.mcp_bridge)
		mcp_bridge_drain_commands(&app.mcp_bridge, app)
	}
	if !app.running {
		return
	}
	app_video_recording_process_fullscreen_preservation(app)
	app_video_recording_process_pending_start(app)
	app_send_frame(app)
	frame_processor_pump(app)
	app_sync_text_input_active(app)
	app_drain_render_messages(app)
	app_apply_frame_pacing(app, frame_start)
}

app_set_text_input_active :: proc(app: ^App_State, active: bool) {
	if app == nil || app.window == nil || app.text_input_active == active {
		return
	}
	if active {
		if !sdl.StartTextInput(app.window) {
			engine.log_error("SDL text input start failed: ", sdl.GetError())
			return
		}
	} else if !sdl.StopTextInput(app.window) {
		engine.log_error("SDL text input stop failed: ", sdl.GetError())
		return
	}
	app.text_input_active = active
}

app_sync_text_input_active :: proc(app: ^App_State) {
	if app == nil {
		return
	}
	// This is a latest-state handoff rather than a queued event: UI correctness
	// must not depend on the lossy render-statistics queue having spare capacity.
	app_set_text_input_active(app, sync.atomic_load(&app.render_worker.text_input_requested))
}

app_poll_events :: proc(app: ^App_State) {
	app.input.mouse_pressed = false
	app.input.mouse_released = false
	app.input.mouse_moved = false
	app.input.mouse_delta = {}
	app.input.mouse_button = app.held_mouse_button
	app.input.wheel_delta = 0
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
			app_apply_mouse_button_event(app, u32(event.button.button), event.button.x, event.button.y, true)
		case .MOUSE_BUTTON_UP:
			app_apply_mouse_button_event(app, u32(event.button.button), event.button.x, event.button.y, false)
		case .MOUSE_WHEEL:
			app.input.wheel_delta += event.wheel.y
			if event.wheel.y != 0 {
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
	if app_key_matches_pause_shortcut(app.settings, key, scancode) {
		if down && is_repeat {return}
		if !down && app.keyboard_pause_down {app.keyboard_action_released.pause = true}
		app.keyboard_pause_down = down
		if down {
			app.keyboard_pause_pressed = true
			app.input.pause = true
		}
		if !app_key_matches(key, scancode, sdl.K_SPACE, .SPACE) {return}
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
			app.input.key_space = true
			app.input.key_space_pressed = true
		} else if !down && app.input.key_space_down {
			app.input.key_space_released = true
			app.keyboard_action_released.pause = true
			app.keyboard_action_released.control_deck = true
		}
		app.input.key_space_down = down
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
	app.controller_connected_this_frame = true
	engine.log_info("Gamepad connected: ", sdl.GetGamepadName(gamepad))
	return true
}

app_close_gamepad :: proc(app: ^App_State) {
	if app.gamepad == nil {
		return
	}
	sdl.CloseGamepad(app.gamepad)
	app.gamepad = nil
	app.gamepad_id = 0
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

app_controller_south_is_accept :: proc(settings: App_Settings) -> bool {
	return settings.controller_face_layout != "East Accept"
}

app_controller_start_is_pause :: proc(settings: App_Settings) -> bool {
	return settings.controller_menu_layout != "View Pauses"
}

app_controller_right_shoulder_is_next :: proc(settings: App_Settings) -> bool {
	return settings.controller_shoulder_layout != "Left Next"
}

app_controller_right_trigger_is_primary :: proc(settings: App_Settings) -> bool {
	return settings.controller_trigger_layout != "Left Primary"
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

app_input_axis :: proc(positive, negative: bool) -> f32 {
	value := f32(0)
	if positive {value += 1}
	if negative {value -= 1}
	return value
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
		mouse_keyboard_down = app.input.key_space_down,
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
// positions must reach the render/UI owner in their original order. Apply
// backpressure only after the generous command queue fills instead of
// collapsing distinct interactions into one synthetic frame.
app_push_frame_command :: proc(app: ^App_State, cmd: Ui_To_Render_Command) -> bool {
	if app.frame_processor_mode == .Main_Thread {
		if engine.queue_try_push(&app.ui_to_render, cmd) {
			return true
		}
		// On Darwin the renderer is owned by this thread, so a blocking push
		// would deadlock. Drain queued work and retry the exact frame.
		frame_processor_pump(app)
		return engine.queue_try_push(&app.ui_to_render, cmd)
	}
	return engine.queue_push_blocking(&app.ui_to_render, cmd)
}

app_send_frame :: proc(app: ^App_State) {
	now := time.tick_now()
	delta_time := f32(time.duration_seconds(time.tick_diff(app.last_frame_tick, now)))
	if delta_time <= 0 {
		delta_time = 1.0 / 60.0
	}
	app.last_frame_tick = now

	w, h: c.int
	lw, lh: c.int
	_ = sdl.GetWindowSizeInPixels(app.window, &w, &h)
	_ = sdl.GetWindowSize(app.window, &lw, &lh)
	scale_x := f32(w) / f32(max(lw, 1))
	scale_y := f32(h) / f32(max(lh, 1))
	app_update_controller_state(app, delta_time, i32(lw), i32(lh))
	actions := app_resolve_input_actions(app, delta_time)
	controller_active := app.active_device == .Controller
	pointer_device := app_pointer_device_for_actions(actions, app.active_device)
	controller_pointer_active := pointer_device == .Controller
	if app.ui_system_cursor_hidden && app_input_reveals_hidden_system_cursor(app.input, app.active_device) {
		app.ui_system_cursor_hidden = false
	}
	app_apply_system_cursor_visibility(app)
	if !controller_active && !controller_pointer_active {
		app.virtual_cursor_pos = app.input.mouse_pos
		app.virtual_cursor_initialized = true
	}

	mouse_logical := app.input.mouse_pos
	if controller_pointer_active {
		mouse_logical = app.virtual_cursor_pos
	}
	mouse_pos := uifw.Vec2{mouse_logical.x * scale_x, mouse_logical.y * scale_y}
	mouse_delta := uifw.Vec2{app.input.mouse_delta.x * scale_x, app.input.mouse_delta.y * scale_y}
	virtual_cursor_pos := uifw.Vec2{app.virtual_cursor_pos.x * scale_x, app.virtual_cursor_pos.y * scale_y}
	pointer_enabled := true
	nav_x := actions.navigate.value.x
	nav_y := actions.navigate.value.y
	nav_pressed_x := actions.navigate.pressed.x + actions.navigate.repeated.x
	nav_pressed_y := actions.navigate.pressed.y + actions.navigate.repeated.y

	primary_down := actions.primary.down
	primary_pressed := actions.primary.pressed
	primary_released := actions.primary.released
	secondary_down := actions.secondary.down
	secondary_pressed := actions.secondary.pressed
	secondary_released := actions.secondary.released
	// Keep the native mouse stream authoritative for mouse/keyboard pointer
	// input.  The semantic resolver owns cross-device arbitration, but using its
	// latched state to drive the GUI can turn the first physical click after
	// startup/device handoff into a focus-only click.  This also matches the
	// pre-action-layer behavior: mouse buttons reach the GUI exactly as SDL
	// reported them, while controller pointer buttons use resolved actions.
	if pointer_device == .Mouse_Keyboard {
		primary_down = app.input.mouse_down && app.input.mouse_button != 3
		primary_pressed = app.input.mouse_pressed && app.input.mouse_button != 3
		primary_released = app.input.mouse_released && app.input.mouse_button != 3
		secondary_down = app.input.mouse_down && app.input.mouse_button == 3
		secondary_pressed = app.input.mouse_pressed && app.input.mouse_button == 3
		secondary_released = app.input.mouse_released && app.input.mouse_button == 3
	}
	frame_mouse_down := primary_down || secondary_down
	frame_mouse_pressed := primary_pressed || secondary_pressed
	frame_mouse_released := primary_released || secondary_released
	frame_mouse_button := secondary_down || secondary_pressed || secondary_released ? u32(3) : u32(1)
	if pointer_device == .Mouse_Keyboard && app.input.mouse_button != 0 {
		frame_mouse_button = app.input.mouse_button
	}
	if app.mcp_enabled {
		mcp_bridge_publish_frame(&app.mcp_bridge, app, i32(w), i32(h), i32(lw), i32(lh))
	}

	cmd: Ui_To_Render_Command
	cmd.kind = .Frame_Input
	cmd.frame_input = {
		actions = actions,
		frame_index = app.frame_index,
		window_width = i32(w),
		window_height = i32(h),
		mouse_pos = mouse_pos,
		mouse_down = frame_mouse_down,
		mouse_pressed = frame_mouse_pressed,
		mouse_released = frame_mouse_released,
		mouse_moved = app.input.mouse_moved,
		mouse_delta = mouse_delta,
		mouse_button = frame_mouse_button,
		wheel_delta = app.input.wheel_delta,
		delta_time = delta_time,
		camera_sensitivity = app.settings.default_camera_sensitivity,
		camera_reset = actions.camera_reset.pressed,
		active_device = app.active_device,
		pointer_enabled = pointer_enabled,
		virtual_cursor_pos = virtual_cursor_pos,
		nav_x = nav_x,
		nav_y = nav_y,
		nav_pressed_x = nav_pressed_x,
		nav_pressed_y = nav_pressed_y,
		accept = actions.accept.pressed,
		back = actions.back.pressed,
		pause = actions.pause.pressed,
		help = actions.help.pressed,
		toggle_ui = actions.toggle_ui.pressed,
		focus_next = actions.focus_next.pressed || actions.focus_next.repeated,
		focus_prev = actions.focus_prev.pressed || actions.focus_prev.repeated,
		primary_down = primary_down,
		primary_pressed = primary_pressed,
		primary_released = primary_released,
		secondary_down = secondary_down,
		secondary_pressed = secondary_pressed,
		secondary_released = secondary_released,
		controller_connected = app.controller_connected_this_frame,
		controller_disconnected = app.controller_disconnected_this_frame,
		controller_left = app.controller_left,
		controller_right = app.controller_right,
		controller_zoom = app_controller_camera_zoom(app),
		text_input = app.input.text_input,
		text_input_len = app.input.text_input_len,
		clipboard_paste = app.input.clipboard_paste,
		clipboard_paste_len = app.input.clipboard_paste_len,
		key_tab = app.input.key_tab,
		key_shift = app.input.key_shift,
		key_ctrl = app.input.key_ctrl,
		key_super = app.input.key_super,
		key_enter = app.input.key_enter || (actions.accept.pressed && actions.accept.owner == .Mouse_Keyboard),
		key_escape = app.input.key_escape,
		key_backspace = app.input.key_backspace,
		key_delete = app.input.key_delete,
		key_home = app.input.key_home,
		key_end = app.input.key_end,
		key_left = app.input.key_left,
		key_right = app.input.key_right,
		key_up = app.input.key_up,
		key_down = app.input.key_down,
		key_w = app.input.key_w,
		key_a = app.input.key_a,
		key_s = app.input.key_s,
		key_d = app.input.key_d,
		key_q = app.input.key_q,
		key_e = app.input.key_e,
		key_x = app.input.key_x,
		key_v = app.input.key_v,
		key_c = app.input.key_c,
		key_f1 = app.input.key_f1,
		key_slash = app.input.key_slash,
		key_space = app.input.key_space,
		key_space_down = app.input.key_space_down,
		key_space_pressed = app.input.key_space_pressed,
		key_space_released = app.input.key_space_released,
	}
	_ = app_push_frame_command(app, cmd)
	if app.controller_disconnected_this_frame && app.active_device == .Controller {
		app.active_device = .Mouse_Keyboard
		app_apply_system_cursor_visibility(app)
	}
	app.frame_index += 1
}

app_reveal_hidden_system_cursor_from_mouse_input :: proc(app: ^App_State) {
	if app == nil || !app.ui_system_cursor_hidden || app.active_device != .Mouse_Keyboard {
		return
	}
	app.ui_system_cursor_hidden = false
	app_apply_system_cursor_visibility(app)
}

app_input_reveals_hidden_system_cursor :: proc(input: uifw.Input_State, active_device: uifw.Input_Device_Kind) -> bool {
	return active_device == .Mouse_Keyboard &&
		(input.mouse_pressed ||
		 input.mouse_released ||
		 input.mouse_down ||
		 input.mouse_moved ||
		 input.wheel_delta != 0)
}

app_apply_system_cursor_visibility :: proc(app: ^App_State) {
	if app == nil {
		return
	}
	hidden := app.active_device == .Controller || app.ui_system_cursor_hidden
	app_set_system_cursor_transparent(app, hidden)
}

app_set_system_cursor_transparent :: proc(app: ^App_State, transparent: bool) {
	if app == nil || transparent == app.system_cursor_transparent {
		return
	}
	if transparent {
		if app.transparent_cursor != nil {
			_ = sdl.SetCursor(app.transparent_cursor)
			app.system_cursor_transparent = true
		}
	} else {
		default_cursor := sdl.GetDefaultCursor()
		_ = sdl.SetCursor(default_cursor)
		app.system_cursor_transparent = false
	}
}

app_create_transparent_cursor :: proc() -> ^sdl.Cursor {
	data := [?]sdl.Uint8{0, 0, 0, 0, 0, 0, 0, 0}
	mask := [?]sdl.Uint8{0, 0, 0, 0, 0, 0, 0, 0}
	cursor := sdl.CreateCursor(raw_data(data[:]), raw_data(mask[:]), 8, 8, 0, 0)
	if cursor == nil {
		engine.log_error("Could not create transparent cursor: ", sdl.GetError())
	}
	return cursor
}

app_destroy_transparent_cursor :: proc(app: ^App_State) {
	if app == nil || app.transparent_cursor == nil {
		return
	}
	if app.system_cursor_transparent {
		app_set_system_cursor_transparent(app, false)
	}
	sdl.DestroyCursor(app.transparent_cursor)
	app.transparent_cursor = nil
}

app_apply_frame_pacing :: proc(app: ^App_State, frame_start: time.Tick) {
	if !app.settings.default_fps_limit_enabled || app.settings.default_fps_limit <= 0 {
		return
	}

	target_seconds := 1.0 / f64(app.settings.default_fps_limit)
	elapsed_seconds := time.duration_seconds(time.tick_diff(frame_start, time.tick_now()))
	remaining_seconds := target_seconds - elapsed_seconds
	if remaining_seconds <= 0 {
		return
	}

	delay_ms_f64 := max(remaining_seconds * 1000.0, 1.0)
	delay_ms := u32(delay_ms_f64)
	if f64(delay_ms) < delay_ms_f64 {
		delay_ms += 1
	}
	sdl.Delay(delay_ms)
}

app_drain_render_messages :: proc(app: ^App_State) {
	msg: Render_To_Ui_Message
	for engine.queue_try_pop(&app.render_to_ui, &msg) {
		#partial switch msg.kind {
		case .Ready, .Device_Info, .Preset_Result, .Error, .Shutdown_Complete:
			if app.mcp_enabled {
				mcp_bridge_publish_render_message(&app.mcp_bridge, msg)
			}
			text := fixed_string(msg.text[:])
			if len(text) > 0 {
				if app.mcp_enabled {
					if msg.kind == .Error {
						engine.log_error(text)
					} else {
						engine.log_info(text)
					}
				} else {
					fmt.println(text)
				}
			}
		case .Request_Nutrient_Image_Dialog:
			app_show_nutrient_image_dialog(app)
		case .Request_Vectors_Image_Dialog:
			app_show_vectors_image_dialog(app)
		case .Request_Moire_Image_Dialog:
			app_show_moire_image_dialog(app)
		case .Request_Flow_Image_Dialog:
			app_show_flow_image_dialog(app)
		case .Request_Slime_Mask_Image_Dialog:
			app_show_slime_mask_image_dialog(app)
		case .Request_Slime_Position_Image_Dialog:
			app_show_slime_position_image_dialog(app)
		case .Request_Video_Save_Dialog:
			engine.log_info("video_recording: received save dialog request on app thread")
			app_show_video_save_dialog(app)
		case .Clipboard_Set:
			text := fixed_string(msg.text[:])
			if len(text) > 0 {
				_ = sdl.SetClipboardText(cstring(raw_data(msg.text[:])))
			}
		case .Request_Close:
			app.running = false
		case .App_Settings_Changed:
			app_apply_settings(app, msg.app_settings)
		case .Frame_Stats:
			app.ui_system_cursor_hidden = msg.system_cursor_hidden &&
				!app_input_reveals_hidden_system_cursor(app.input, app.active_device)
			app_apply_system_cursor_visibility(app)
			if app.mcp_enabled {
				mcp_bridge_publish_render_message(&app.mcp_bridge, msg)
			}
		}
	}
}

app_write_fixed_string_cstring :: proc(dst: []u8, src: cstring) {
	if src == nil || len(dst) == 0 {
		return
	}
	i := 0
	bytes := cast([^]u8)src
	for i < len(dst) - 1 && bytes[i] != 0 {
		dst[i] = bytes[i]
		i += 1
	}
	dst[i] = 0
}

app_nutrient_image_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	_ = filter
	if userdata == nil || filelist == nil || filelist[0] == nil {
		return
	}
	app := cast(^App_State)userdata
	cmd: Ui_To_Render_Command
	cmd.kind = .Load_Gray_Scott_Nutrient_Image
	app_write_fixed_string_cstring(cmd.file_path[:], filelist[0])
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
}

app_show_nutrient_image_dialog :: proc(app: ^App_State) {
	sdl.ShowOpenFileDialog(
		app_nutrient_image_dialog_callback,
		app,
		app.window,
		raw_data(NUTRIENT_IMAGE_DIALOG_FILTERS[:]),
		c.int(len(NUTRIENT_IMAGE_DIALOG_FILTERS)),
		nil,
		false,
	)
}

app_vectors_image_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	_ = filter
	if userdata == nil || filelist == nil || filelist[0] == nil {
		return
	}
	app := cast(^App_State)userdata
	cmd: Ui_To_Render_Command
	cmd.kind = .Load_Vectors_Image
	app_write_fixed_string_cstring(cmd.file_path[:], filelist[0])
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
}

app_show_vectors_image_dialog :: proc(app: ^App_State) {
	sdl.ShowOpenFileDialog(
		app_vectors_image_dialog_callback,
		app,
		app.window,
		raw_data(NUTRIENT_IMAGE_DIALOG_FILTERS[:]),
		c.int(len(NUTRIENT_IMAGE_DIALOG_FILTERS)),
		nil,
		false,
	)
}

app_moire_image_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	_ = filter
	if userdata == nil || filelist == nil || filelist[0] == nil {
		return
	}
	app := cast(^App_State)userdata
	cmd: Ui_To_Render_Command
	cmd.kind = .Load_Moire_Image
	app_write_fixed_string_cstring(cmd.file_path[:], filelist[0])
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
}

app_show_moire_image_dialog :: proc(app: ^App_State) {
	sdl.ShowOpenFileDialog(
		app_moire_image_dialog_callback,
		app,
		app.window,
		raw_data(NUTRIENT_IMAGE_DIALOG_FILTERS[:]),
		c.int(len(NUTRIENT_IMAGE_DIALOG_FILTERS)),
		nil,
		false,
	)
}

app_flow_image_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	_ = filter
	if userdata == nil || filelist == nil || filelist[0] == nil {
		return
	}
	app := cast(^App_State)userdata
	cmd: Ui_To_Render_Command
	cmd.kind = .Load_Flow_Image
	app_write_fixed_string_cstring(cmd.file_path[:], filelist[0])
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
}

app_show_flow_image_dialog :: proc(app: ^App_State) {
	sdl.ShowOpenFileDialog(
		app_flow_image_dialog_callback,
		app,
		app.window,
		raw_data(NUTRIENT_IMAGE_DIALOG_FILTERS[:]),
		c.int(len(NUTRIENT_IMAGE_DIALOG_FILTERS)),
		nil,
		false,
	)
}

app_slime_mask_image_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	_ = filter
	if userdata == nil || filelist == nil || filelist[0] == nil {
		return
	}
	app := cast(^App_State)userdata
	cmd: Ui_To_Render_Command
	cmd.kind = .Load_Slime_Mask_Image
	app_write_fixed_string_cstring(cmd.file_path[:], filelist[0])
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
}

app_show_slime_mask_image_dialog :: proc(app: ^App_State) {
	sdl.ShowOpenFileDialog(
		app_slime_mask_image_dialog_callback,
		app,
		app.window,
		raw_data(NUTRIENT_IMAGE_DIALOG_FILTERS[:]),
		c.int(len(NUTRIENT_IMAGE_DIALOG_FILTERS)),
		nil,
		false,
	)
}

app_slime_position_image_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	_ = filter
	if userdata == nil || filelist == nil || filelist[0] == nil {
		return
	}
	app := cast(^App_State)userdata
	cmd: Ui_To_Render_Command
	cmd.kind = .Load_Slime_Position_Image
	app_write_fixed_string_cstring(cmd.file_path[:], filelist[0])
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
}

app_show_slime_position_image_dialog :: proc(app: ^App_State) {
	sdl.ShowOpenFileDialog(
		app_slime_position_image_dialog_callback,
		app,
		app.window,
		raw_data(NUTRIENT_IMAGE_DIALOG_FILTERS[:]),
		c.int(len(NUTRIENT_IMAGE_DIALOG_FILTERS)),
		nil,
		false,
	)
}

app_video_recording_is_fullscreen :: proc(app: ^App_State) -> bool {
	if app == nil || app.window == nil {
		return false
	}
	flags := sdl.GetWindowFlags(app.window)
	return .FULLSCREEN in flags
}

app_video_recording_send_start :: proc(app: ^App_State, path: string) {
	if len(path) == 0 {
		return
	}
	cmd: Ui_To_Render_Command
	cmd.kind = .Start_Video_Recording
	write_fixed_string(cmd.file_path[:], path)
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
	app.video_recording_pending_start = false
	app.video_recording_restore_fullscreen = false
	app.video_recording_restore_attempts = 0
	write_fixed_string(app.video_recording_pending_path[:], "")
}

app_video_recording_send_cancel :: proc(app: ^App_State) {
	cmd: Ui_To_Render_Command
	cmd.kind = .Cancel_Video_Recording
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
}

app_video_recording_send_error :: proc(app: ^App_State, text: string) {
	cmd: Ui_To_Render_Command
	cmd.kind = .Video_Recording_Error
	write_fixed_string(cmd.file_path[:], text)
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
}

app_video_recording_send_restoring :: proc(app: ^App_State) {
	cmd: Ui_To_Render_Command
	cmd.kind = .Video_Recording_Restoring_Fullscreen
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
}

app_video_recording_clear_pending_start :: proc(app: ^App_State) {
	app.video_recording_pending_start = false
	app.video_recording_restore_fullscreen = false
	app.video_recording_restore_attempts = 0
	write_fixed_string(app.video_recording_pending_path[:], "")
}

app_video_recording_begin_fullscreen_preservation :: proc(app: ^App_State) {
	if app == nil || app.window == nil || app_video_recording_is_fullscreen(app) {
		app.video_recording_preserve_fullscreen = false
		app.video_recording_preserve_fullscreen_attempts = 0
		return
	}
	app.video_recording_preserve_fullscreen = true
	app.video_recording_preserve_fullscreen_attempts = 0
	_ = sdl.SetWindowFullscreen(app.window, true)
}

app_video_recording_process_fullscreen_preservation :: proc(app: ^App_State) {
	if !app.video_recording_preserve_fullscreen {
		return
	}
	if app_video_recording_is_fullscreen(app) {
		app.video_recording_preserve_fullscreen = false
		app.video_recording_preserve_fullscreen_attempts = 0
		return
	}
	app.video_recording_preserve_fullscreen_attempts += 1
	if app.video_recording_preserve_fullscreen_attempts == 1 || (app.video_recording_preserve_fullscreen_attempts % 30) == 0 {
		_ = sdl.SetWindowFullscreen(app.window, true)
	}
	if app.video_recording_preserve_fullscreen_attempts >= VIDEO_RECORDING_FULLSCREEN_RESTORE_MAX_FRAMES {
		app.video_recording_preserve_fullscreen = false
		app.video_recording_preserve_fullscreen_attempts = 0
		engine.log_error("Could not restore fullscreen after video recording dialog")
	}
}

app_video_recording_process_pending_start :: proc(app: ^App_State) {
	if !app.video_recording_pending_start {
		return
	}
	path := fixed_string(app.video_recording_pending_path[:])
	if len(path) == 0 {
		app_video_recording_clear_pending_start(app)
		app_video_recording_send_cancel(app)
		return
	}
	if app.video_recording_restore_fullscreen {
		if app_video_recording_is_fullscreen(app) {
			app_video_recording_send_start(app, path)
			return
		}
		app.video_recording_restore_attempts += 1
		if app.video_recording_restore_attempts == 1 || (app.video_recording_restore_attempts % 30) == 0 {
			_ = sdl.SetWindowFullscreen(app.window, true)
		}
		if app.video_recording_restore_attempts >= VIDEO_RECORDING_FULLSCREEN_RESTORE_MAX_FRAMES {
			app_video_recording_clear_pending_start(app)
			app_video_recording_send_error(app, "Could not restore fullscreen; recording was not started")
		}
		return
	}
	app_video_recording_send_start(app, path)
}

app_video_recording_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	_ = filter
	if userdata == nil {
		return
	}
	app := cast(^App_State)userdata
	was_fullscreen := app.video_recording_restore_fullscreen
	if filelist == nil || filelist[0] == nil {
		err := sdl.GetError()
		if err != nil && len(string(err)) > 0 {
			engine.log_error("video_recording: save dialog failed or was canceled: ", err)
		} else {
			engine.log_info("video_recording: save dialog canceled")
		}
		app_video_recording_clear_pending_start(app)
		if was_fullscreen {
			app_video_recording_begin_fullscreen_preservation(app)
		}
		app_video_recording_send_cancel(app)
		return
	}
	app_write_fixed_string_cstring(app.video_recording_pending_path[:], filelist[0])
	path := fixed_string(app.video_recording_pending_path[:])
	engine.log_info("video_recording: save path selected: ", path)
	if was_fullscreen {
		if app_video_recording_is_fullscreen(app) {
			app_video_recording_send_start(app, path)
		} else if sdl.SetWindowFullscreen(app.window, true) {
			app.video_recording_pending_start = true
			app.video_recording_restore_fullscreen = true
			app.video_recording_restore_attempts = 0
			app_video_recording_send_restoring(app)
		} else {
			app_video_recording_clear_pending_start(app)
			app_video_recording_begin_fullscreen_preservation(app)
			app_video_recording_send_error(app, "Could not restore fullscreen; recording was not started")
		}
	} else {
		app_video_recording_send_start(app, path)
	}
}

app_show_video_save_dialog :: proc(app: ^App_State) {
	app.video_recording_pending_start = false
	app.video_recording_restore_fullscreen = app_video_recording_is_fullscreen(app)
	app.video_recording_restore_attempts = 0
	app.video_recording_preserve_fullscreen = false
	app.video_recording_preserve_fullscreen_attempts = 0
	write_fixed_string(app.video_recording_pending_path[:], "")
	engine.log_info("video_recording: opening save dialog fullscreen=", app.video_recording_restore_fullscreen)
	sdl.ShowSaveFileDialog(
		app_video_recording_dialog_callback,
		app,
		app.window,
		raw_data(VIDEO_FILE_DIALOG_FILTERS[:]),
		c.int(len(VIDEO_FILE_DIALOG_FILTERS)),
		nil,
	)
}
