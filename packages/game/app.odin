package game

import uifw "../ui"
import engine "../engine"

import "base:runtime"
import "core:c"
import "core:fmt"
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
	virtual_cursor_pos: uifw.Vec2,
	virtual_cursor_initialized: bool,
	ui_system_cursor_hidden: bool,
	system_cursor_transparent: bool,
	transparent_cursor: ^sdl.Cursor,
	controller_connected_this_frame: bool,
	controller_disconnected_this_frame: bool,
	controller_dpad_x: f32,
	controller_dpad_y: f32,
	controller_accept_down: bool,
	controller_back_down: bool,
	controller_pause_down: bool,
	controller_toggle_ui_down: bool,
	controller_focus_next_down: bool,
	controller_focus_prev_down: bool,
	controller_secondary_button_down: bool,
	controller_left: uifw.Vec2,
	controller_right: uifw.Vec2,
	controller_left_trigger: f32,
	controller_right_trigger: f32,
	controller_left_trigger_down: bool,
	controller_right_trigger_down: bool,
	controller_left_trigger_prev_down: bool,
	controller_right_trigger_prev_down: bool,
	controller_nav_prev_x: f32,
	controller_nav_prev_y: f32,
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
	if !sdl.StartTextInput(app.window) {
		engine.log_error("SDL text input start failed: ", sdl.GetError())
	}
	defer sdl.DestroyWindow(app.window)
	app.transparent_cursor = app_create_transparent_cursor()
	defer app_destroy_transparent_cursor(app)
	defer {
		app_set_system_cursor_transparent(app, false)
		_ = sdl.StopTextInput(app.window)
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
	app_drain_render_messages(app)
	app_apply_frame_pacing(app, frame_start)
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
	app.input.key_slash = false
	app.input.key_space = false
	app.input.key_space_pressed = false
	app.input.key_space_released = false
	app.input.accept = false
	app.input.back = false
	app.input.pause = false
	app.input.toggle_ui = false
	app.input.focus_next = false
	app.input.focus_prev = false
	app.input.primary_pressed = false
	app.input.primary_released = false
	app.input.secondary_pressed = false
	app.input.secondary_released = false
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
			app_apply_key_event(app, event.key.key, event.key.scancode, true)
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
			app_mark_controller_input(app)
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

app_apply_key_event :: proc(app: ^App_State, key: sdl.Keycode, scancode: sdl.Scancode, down: bool) {
	if app_key_matches(key, scancode, sdl.K_TAB, .TAB) {
		app.input.key_tab = down
	} else if key == sdl.K_RETURN || key == sdl.K_KP_ENTER || scancode == .RETURN || scancode == .KP_ENTER {
		app.input.key_enter = down
	} else if app_key_matches(key, scancode, sdl.K_ESCAPE, .ESCAPE) {
		app.input.key_escape = down
	} else if app_key_matches(key, scancode, sdl.K_BACKSPACE, .BACKSPACE) {
		app.input.key_backspace = down
	} else if app_key_matches(key, scancode, sdl.K_DELETE, .DELETE) {
		app.input.key_delete = down
	} else if app_key_matches(key, scancode, sdl.K_HOME, .HOME) {
		app.input.key_home = down
	} else if app_key_matches(key, scancode, sdl.K_END, .END) {
		app.input.key_end = down
	} else if app_key_matches(key, scancode, sdl.K_LEFT, .LEFT) {
		app.input.key_left = down
	} else if app_key_matches(key, scancode, sdl.K_RIGHT, .RIGHT) {
		app.input.key_right = down
	} else if app_key_matches(key, scancode, sdl.K_UP, .UP) {
		app.input.key_up = down
	} else if app_key_matches(key, scancode, sdl.K_DOWN, .DOWN) {
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
		app.input.key_c = down
	} else if app_key_matches(key, scancode, sdl.K_SLASH, .SLASH) {
		app.input.key_slash = down
	} else if app_key_matches(key, scancode, sdl.K_SPACE, .SPACE) {
		if down && !app.input.key_space_down {
			app.input.key_space = true
			app.input.key_space_pressed = true
		} else if !down && app.input.key_space_down {
			app.input.key_space_released = true
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
	app.controller_left = {}
	app.controller_right = {}
	app.controller_left_trigger = 0
	app.controller_right_trigger = 0
	app.controller_left_trigger_down = false
	app.controller_right_trigger_down = false
	app.controller_dpad_x = 0
	app.controller_dpad_y = 0
	app.controller_accept_down = false
	app.controller_back_down = false
	app.controller_pause_down = false
	app.controller_toggle_ui_down = false
	app.controller_focus_next_down = false
	app.controller_focus_prev_down = false
	app.controller_secondary_button_down = false
}

app_apply_gamepad_button :: proc(app: ^App_State, button: sdl.GamepadButton, down: bool) {
	#partial switch button {
	case .SOUTH:
		app.controller_accept_down = down
		if down {app.input.accept = true}
	case .EAST:
		app.controller_back_down = down
		if down {app.input.back = true}
	case .WEST:
		app.controller_secondary_button_down = down
	case .NORTH, .BACK:
		app.controller_toggle_ui_down = down
		if down {app.input.toggle_ui = true}
	case .START:
		app.controller_pause_down = down
		if down {app.input.pause = true}
	case .DPAD_LEFT:
		app.controller_dpad_x = down ? f32(-1) : (app.controller_dpad_x < 0 ? f32(0) : app.controller_dpad_x)
	case .DPAD_RIGHT:
		app.controller_dpad_x = down ? f32(1) : (app.controller_dpad_x > 0 ? f32(0) : app.controller_dpad_x)
	case .DPAD_UP:
		app.controller_dpad_y = down ? f32(-1) : (app.controller_dpad_y < 0 ? f32(0) : app.controller_dpad_y)
	case .DPAD_DOWN:
		app.controller_dpad_y = down ? f32(1) : (app.controller_dpad_y > 0 ? f32(0) : app.controller_dpad_y)
	case .RIGHT_SHOULDER:
		app.controller_focus_next_down = down
		if down {app.input.focus_next = true}
	case .LEFT_SHOULDER:
		app.controller_focus_prev_down = down
		if down {app.input.focus_prev = true}
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
	return {
		app_apply_deadzone(app_gamepad_axis_value(app, x_axis), INPUT_CONTROLLER_DEADZONE),
		app_apply_deadzone(app_gamepad_axis_value(app, y_axis), INPUT_CONTROLLER_DEADZONE),
	}
}

app_controller_trigger_value :: proc(app: ^App_State, axis: sdl.GamepadAxis) -> f32 {
	raw := app_gamepad_axis_value(app, axis)
	if raw < 0 {
		return 0
	}
	return min(max(raw, 0), 1)
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
	app.controller_left_trigger_down = app.controller_left_trigger >= INPUT_CONTROLLER_TRIGGER_THRESHOLD || app.controller_secondary_button_down
	app.controller_right_trigger_down = app.controller_right_trigger >= INPUT_CONTROLLER_TRIGGER_THRESHOLD

	left_active := app.controller_left.x != 0 || app.controller_left.y != 0
	right_active := app.controller_right.x != 0 || app.controller_right.y != 0
	trigger_active := app.controller_left_trigger_down || app.controller_right_trigger_down
	if left_active || right_active || trigger_active {
		app_mark_controller_input(app)
	}

	if !app.virtual_cursor_initialized {
		app.virtual_cursor_pos = {f32(window_width) * 0.5, f32(window_height) * 0.5}
		app.virtual_cursor_initialized = true
	}
	if right_active {
		strength_x := app.controller_right.x * (app.controller_right.x < 0 ? -app.controller_right.x : app.controller_right.x)
		strength_y := app.controller_right.y * (app.controller_right.y < 0 ? -app.controller_right.y : app.controller_right.y)
		speed := max(f32(window_height), 480) * INPUT_CONTROLLER_CURSOR_SPEED
		dt := max(delta_time, 1.0 / 240.0)
		app.virtual_cursor_pos.x += strength_x * speed * dt
		app.virtual_cursor_pos.y += strength_y * speed * dt
	}
	app.virtual_cursor_pos.x = min(max(app.virtual_cursor_pos.x, 0), max(f32(window_width) - 1, 0))
	app.virtual_cursor_pos.y = min(max(app.virtual_cursor_pos.y, 0), max(f32(window_height) - 1, 0))
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
	controller_active := app.active_device == .Controller
	if app.ui_system_cursor_hidden && app_input_reveals_hidden_system_cursor(app.input, app.active_device) {
		app.ui_system_cursor_hidden = false
	}
	app_apply_system_cursor_visibility(app)
	if !controller_active {
		app.virtual_cursor_pos = app.input.mouse_pos
		app.virtual_cursor_initialized = true
	}

	mouse_logical := app.input.mouse_pos
	if controller_active {
		mouse_logical = app.virtual_cursor_pos
	}
	mouse_pos := uifw.Vec2{mouse_logical.x * scale_x, mouse_logical.y * scale_y}
	mouse_delta := uifw.Vec2{app.input.mouse_delta.x * scale_x, app.input.mouse_delta.y * scale_y}
	virtual_cursor_pos := uifw.Vec2{app.virtual_cursor_pos.x * scale_x, app.virtual_cursor_pos.y * scale_y}
	pointer_enabled := true
	nav_x := app.input.key_right ? f32(1) : f32(0)
	if app.input.key_left {
		nav_x -= 1
	}
	nav_y := app.input.key_down ? f32(1) : f32(0)
	if app.input.key_up {
		nav_y -= 1
	}
	controller_nav_x := app.controller_dpad_x
	controller_nav_y := app.controller_dpad_y
	if controller_nav_x == 0 && app.controller_left.x != 0 {
		controller_nav_x = app.controller_left.x
	}
	if controller_nav_y == 0 && app.controller_left.y != 0 {
		controller_nav_y = app.controller_left.y
	}
	if controller_active {
		nav_x += controller_nav_x
		nav_y += controller_nav_y
	}
	nav_pressed_x := f32(0)
	nav_pressed_y := f32(0)
	if controller_active {
		if controller_nav_x != 0 && app.controller_nav_prev_x == 0 {
			nav_pressed_x += controller_nav_x > 0 ? f32(1) : f32(-1)
		}
		if controller_nav_y != 0 && app.controller_nav_prev_y == 0 {
			nav_pressed_y += controller_nav_y > 0 ? f32(1) : f32(-1)
		}
	}
	app.controller_nav_prev_x = controller_nav_x
	app.controller_nav_prev_y = controller_nav_y

	primary_down := app.input.mouse_down && app.input.mouse_button != 3
	primary_pressed := app.input.mouse_pressed && app.input.mouse_button != 3
	primary_released := app.input.mouse_released && app.input.mouse_button != 3
	secondary_down := app.input.mouse_down && app.input.mouse_button == 3
	secondary_pressed := app.input.mouse_pressed && app.input.mouse_button == 3
	secondary_released := app.input.mouse_released && app.input.mouse_button == 3
	frame_mouse_down := app.input.mouse_down
	frame_mouse_pressed := app.input.mouse_pressed
	frame_mouse_released := app.input.mouse_released
	frame_mouse_button := app.input.mouse_button
	if controller_active {
		primary_down = app.controller_right_trigger_down
		primary_pressed = app.controller_right_trigger_down && !app.controller_right_trigger_prev_down
		primary_released = !app.controller_right_trigger_down && app.controller_right_trigger_prev_down
		secondary_down = app.controller_left_trigger_down
		secondary_pressed = app.controller_left_trigger_down && !app.controller_left_trigger_prev_down
		secondary_released = !app.controller_left_trigger_down && app.controller_left_trigger_prev_down
		frame_mouse_down = primary_down || secondary_down
		frame_mouse_pressed = primary_pressed || secondary_pressed
		frame_mouse_released = primary_released || secondary_released
		frame_mouse_button = secondary_down || secondary_pressed || secondary_released ? u32(3) : u32(1)
	}
	if app.mcp_enabled {
		mcp_bridge_publish_frame(&app.mcp_bridge, app, i32(w), i32(h), i32(lw), i32(lh))
	}

	cmd: Ui_To_Render_Command
	cmd.kind = .Frame_Input
	cmd.frame_input = {
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
		active_device = app.active_device,
		pointer_enabled = pointer_enabled,
		virtual_cursor_pos = virtual_cursor_pos,
		nav_x = nav_x,
		nav_y = nav_y,
		nav_pressed_x = nav_pressed_x,
		nav_pressed_y = nav_pressed_y,
		accept = app.input.key_enter || (controller_active && app.controller_accept_down),
		back = app.input.key_escape || (controller_active && app.controller_back_down),
		pause = app.input.key_space || (controller_active && app.input.pause),
		toggle_ui = app.input.key_slash || (controller_active && app.input.toggle_ui),
		focus_next = (app.input.key_tab && !app.input.key_shift) || (controller_active && (app.controller_focus_next_down || app.input.focus_next)),
		focus_prev = (app.input.key_tab && app.input.key_shift) || (controller_active && (app.controller_focus_prev_down || app.input.focus_prev)),
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
		controller_zoom = app.controller_right_trigger - app.controller_left_trigger,
		text_input = app.input.text_input,
		text_input_len = app.input.text_input_len,
		clipboard_paste = app.input.clipboard_paste,
		clipboard_paste_len = app.input.clipboard_paste_len,
		key_tab = app.input.key_tab,
		key_shift = app.input.key_shift,
		key_ctrl = app.input.key_ctrl,
		key_super = app.input.key_super,
		key_enter = app.input.key_enter,
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
		key_slash = app.input.key_slash,
		key_space = app.input.key_space,
		key_space_down = app.input.key_space_down,
		key_space_pressed = app.input.key_space_pressed,
		key_space_released = app.input.key_space_released,
	}
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
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
			app.settings = msg.app_settings
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
