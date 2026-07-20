package app

import uifw "zelda_engine:ui"
import engine "zelda_engine:engine"

import "core:c"
import "core:time"
import sdl "vendor:sdl3"

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
	return engine.queue_push_blocking_below_count(&app.ui_to_render, cmd, FRAME_INPUT_MAX_PENDING)
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
		primary_down = app.input.mouse_down && app.input.mouse_button == 1
		primary_pressed = app.input.mouse_pressed && app.input.mouse_button == 1
		primary_released = app.input.mouse_released && app.input.mouse_button == 1
		secondary_down = app.input.mouse_down && app.input.mouse_button == 3
		secondary_pressed = app.input.mouse_pressed && app.input.mouse_button == 3
		secondary_released = app.input.mouse_released && app.input.mouse_button == 3
	}
	frame_mouse_down := primary_down || secondary_down
	frame_mouse_pressed := primary_pressed || secondary_pressed
	frame_mouse_released := primary_released || secondary_released
	frame_mouse_button := secondary_down || secondary_pressed || secondary_released ? u32(3) : u32(1)
	if pointer_device == .Mouse_Keyboard {
		// Preserve the complete native stream for gesture routing. Middle mouse is
		// not primary interaction, but it still needs press/hold/release phases for
		// exclusive camera panning.
		frame_mouse_down = app.input.mouse_down
		frame_mouse_pressed = app.input.mouse_pressed
		frame_mouse_released = app.input.mouse_released
		if app.input.mouse_button != 0 {
			frame_mouse_button = app.input.mouse_button
		}
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
		wheel_delta_x = app.input.wheel_delta_x,
		wheel_delta = app.input.wheel_delta,
		delta_time = delta_time,
		camera_sensitivity = app.settings.default_camera_sensitivity,
		active_device = app.active_device,
		controller_prompt_style = app.controller_prompt_style,
		pointer_enabled = pointer_enabled,
		virtual_cursor_pos = virtual_cursor_pos,
		controller_connected = app.controller_connected_this_frame,
		controller_disconnected = app.controller_disconnected_this_frame,
		canvas_tool_slot = app.input.canvas_tool_slot,
		controller_left = app.controller_left,
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
		key_escape_down = app.keyboard_back_down,
		controller_start_down = app.controller_start_down,
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
		key_space = app.input.key_space,
		key_space_down = false,
		camera_pan_modifier_down = app.input.key_space_down,
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
		 input.wheel_delta != 0 ||
		 input.wheel_delta_x != 0)
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
