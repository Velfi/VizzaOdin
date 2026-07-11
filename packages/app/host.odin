package app

import uifw "../ui"
import engine "../engine"

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:strings"
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
	touch_active: bool,
	touch_finger_id: sdl.FingerID,
	touch_secondary_active: bool,
	touch_secondary_finger_id: sdl.FingerID,
	space_pan_consumed: bool,
	input_sequence: u64,
	last_mouse_keyboard_input_sequence: u64,
	last_controller_input_sequence: u64,
	active_device: uifw.Input_Device_Kind,
	controller_prompt_style: uifw.Controller_Prompt_Style,
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
	engine.log_info("app_run: begin mcp=", config.mcp_enabled, " theme_preview=", config.theme_preview, " steam_override=", config.steam_override)
	app := new(App_State)
	defer free(app)
	defer engine.screenshot_state_destroy(&app.screenshot)
	app.mcp_enabled = config.mcp_enabled
	app.theme_preview = config.theme_preview

	settings_path := settings_app_config_path()
	engine.log_info("app_run: loading settings path=", settings_path)
	settings_loaded: bool
	app.settings, settings_loaded = settings_load_app(settings_path)
	if !settings_loaded && settings_path != "config/app.toml" {
		app.settings, _ = settings_load_app("config/app.toml")
	}
	engine.log_info("app_run: settings_loaded=", settings_loaded)
	steam_config := steam_config_resolve(app.settings, config)
	steam_state := steam_client_init(&app.steam, steam_config)
	engine.log_info("app_run: steam_state=", steam_state)
	defer steam_client_shutdown(&app.steam)
	if steam_state == .Restart_Requested {
		engine.log_info("app_run: clean early exit for Steam relaunch")
		return 0
	}

	engine.log_info("app_run: SDL init begin")
	if !sdl.Init({.VIDEO, .EVENTS, .GAMEPAD, .CAMERA}) {
		engine.log_error("SDL init failed: ", sdl.GetError())
		return 1
	}
	engine.log_info("app_run: SDL init complete")
	defer sdl.Quit()
	sdl.SetGamepadEventsEnabled(true)
	// Deliver the click that gives the window mouse focus. Without this, a
	// mouse-first launch can consume the first press as window activation, so
	// controls appear to require a double click. This must be set before the
	// window is created.
	_ = sdl.SetHint(sdl.HINT_MOUSE_FOCUS_CLICKTHROUGH, "1")

	flags := sdl.WINDOW_VULKAN | sdl.WINDOW_RESIZABLE | sdl.WINDOW_HIGH_PIXEL_DENSITY
	app.window = sdl.CreateWindow("Vizza", c.int(app.settings.window_width), c.int(app.settings.window_height), flags)
	if app.window == nil {
		engine.log_error("SDL window creation failed: ", sdl.GetError())
		return 1
	}
	engine.log_info("app_run: SDL window created")
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
		engine.log_error("app_run: frame processor bootstrap failed")
		return 1
	}
	engine.log_info("app_run: frame processor ready; entering main loop")
	defer frame_processor_shutdown(app)

	app.running = true
	app.last_frame_tick = time.tick_now()
	for app.running {
		app_loop_tick(app)
	}

	engine.log_info("app_run: main loop ended")
	return 0
}

app_loop_tick :: proc(app: ^App_State) {
	// The default temporary allocator is a growing arena. Keep allocations made
	// while producing and, on Darwin, rendering this frame alive until every
	// frame consumer has finished, then release the arena before the next tick.
	defer free_all(context.temp_allocator)
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
