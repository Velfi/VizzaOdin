package game

import uifw "../ui"
import engine "../engine"

import "core:c"
import base64 "core:encoding/base64"
import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:sync"
import posix "core:sys/posix"

Mcp_Command_Kind :: enum {
	Click,
	Mouse_Down,
	Mouse_Up,
	Move,
	Wheel,
	Set_Mode,
	Close,
	Load_Vectors_Image,
	Load_Moire_Image,
	Load_Flow_Image,
	Load_Slime_Mask_Image,
	Load_Slime_Position_Image,
}

Mcp_Command :: struct {
	kind: Mcp_Command_Kind,
	x, y: f32,
	wheel_delta: f32,
	button: u32,
	mode: App_Mode,
	file_path: [MAX_FILE_PATH]u8,
}

Mcp_Bridge_Status :: struct {
	running: bool,
	frame_index: u64,
	window_width: i32,
	window_height: i32,
	logical_window_width: i32,
	logical_window_height: i32,
	mouse_pos: uifw.Vec2,
	mouse_down: bool,
	last_fps: f32,
	last_frame_ms: f32,
	app_mode: App_Mode,
	gray_scott_camera_x: f32,
	gray_scott_camera_y: f32,
	gray_scott_camera_zoom: f32,
	gray_scott_controls_visible: bool,
	gray_scott_paused: bool,
	particle_life_camera_x: f32,
	particle_life_camera_y: f32,
	particle_life_camera_zoom: f32,
	particle_life_ready: bool,
	particle_life_paused: bool,
	particle_life_controls_visible: bool,
	particle_life_frame_index: u64,
	particle_life_particle_count: u32,
	particle_life_species_count: u32,
	particle_life_requested_particle_count: u32,
	particle_life_requested_species_count: u32,
	particle_life_trails_enabled: bool,
	particle_life_infinite_tiles_enabled: bool,
	gpu_profiling_supported: bool,
	gpu_profiling_enabled: bool,
	gpu_simulation_step_ms: f32,
	gpu_simulation_present_ms: f32,
	gpu_ui_overlay_ms: f32,
	gpu_frame_total_ms: f32,
	sim_ms: f32,
	ui_ms: f32,
	render_ms: f32,
	submit_ms: f32,
	screenshot_ms: f32,
	screenshot_captured: bool,
	ui_build_ms: f32,
	ui_overlay_ms: f32,
	gui_command_count: u32,
	ui_vertex_count: u32,
	ui_batch_count: u32,
	ui_clear_rect_count: u32,
	main_menu_preview_visible_slot_count: u32,
	main_menu_preview_warmed_mode_count: u32,
	main_menu_preview_fallback_fill_count: u32,
	main_menu_preview_skipped_present_count: u32,
	text_width_calls: u64,
	text_width_cache_hits: u64,
	text_width_ms: f32,
	text_shape_calls: u64,
	text_shape_glyphs: u64,
	text_shape_ms: f32,
	text_wrap_calls: u64,
	text_wrap_ms: f32,
	cpu_wait_fence_ms: f32,
	cpu_acquire_ms: f32,
	cpu_command_begin_ms: f32,
	cpu_end_command_ms: f32,
	cpu_queue_submit_ms: f32,
	cpu_queue_present_ms: f32,
	present_mode: [32]u8,
	command_render_pass_count: u32,
	command_compute_dispatch_count: u32,
	command_draw_count: u32,
	command_pipeline_bind_count: u32,
	command_descriptor_bind_count: u32,
	command_pipeline_barrier_count: u32,
	command_transfer_copy_count: u32,
	command_ui_batch_count: u32,
	command_backdrop_blur_pass_count: u32,
	last_message: [MAX_ERROR_TEXT]u8,
}

Mcp_Command_Queue_Status :: struct {
	count: int,
	closed: bool,
}

MCP_PROFILE_DEFAULT_FRAMES :: u32(240)
MCP_PROFILE_MAX_WARNINGS :: 16
MCP_PROFILE_WARNING_TEXT :: 160
MCP_PROFILE_QUEUE_WARN_COUNT :: u32(120)
MCP_PROFILE_GUI_COMMAND_WARN_COUNT :: u32(2048)

Mcp_Profile_Thresholds :: struct {
	ui_spike_ms: f32,
	render_spike_ms: f32,
	gpu_ui_spike_ms: f32,
	screenshot_spike_ms: f32,
	cap_ratio: f32,
	text_calls_per_frame: u32,
	min_width_cache_hit_rate: f32,
}

Mcp_Profile_Session :: struct {
	requested: bool,
	active: bool,
	complete: bool,
	target_mode: App_Mode,
	target_frames: u32,
	collected_frames: u32,
	start_frame_index: u64,
	last_frame_index: u64,
	thresholds: Mcp_Profile_Thresholds,
	sim_sum, sim_max: f64,
	ui_sum, ui_max: f64,
	render_sum, render_max: f64,
	submit_sum, submit_max: f64,
	screenshot_sum, screenshot_max: f64,
	ui_build_sum, ui_build_max: f64,
	ui_overlay_sum, ui_overlay_max: f64,
	gpu_ui_overlay_sum, gpu_ui_overlay_max: f64,
	frame_ms_sum, frame_ms_max: f64,
	text_width_calls: u64,
	text_width_cache_hits: u64,
	text_width_ms_sum, text_width_ms_max: f64,
	text_shape_calls: u64,
	text_shape_glyphs: u64,
	text_shape_ms_sum, text_shape_ms_max: f64,
	text_wrap_calls: u64,
	text_wrap_ms_sum, text_wrap_ms_max: f64,
	screenshot_captures: u32,
	max_gui_command_count: u32,
	max_ui_vertex_count: u32,
	max_ui_batch_count: u32,
	max_ui_clear_rect_count: u32,
	max_command_queue_count: u32,
	ui_spike_count: u32,
	render_spike_count: u32,
	gpu_ui_spike_count: u32,
	screenshot_spike_count: u32,
	frame_stall_count: u32,
	command_queue_pressure_count: u32,
	gui_command_pressure_count: u32,
	ui_vertex_pressure_count: u32,
	ui_batch_pressure_count: u32,
	ui_clear_rect_pressure_count: u32,
}

Mcp_Bridge :: struct {
	pending_commands: [128]Mcp_Command,
	pending_command_count: int,
	status_mutex: sync.Mutex,
	stdout_mutex: sync.Mutex,
	status: Mcp_Bridge_Status,
	profile: Mcp_Profile_Session,
	screenshot: ^engine.Screenshot_State,
	input: [65536]u8,
	input_len: int,
	running: bool,
	stdin_open: bool,
	close_requested: bool,
}

mcp_bridge_start :: proc(bridge: ^Mcp_Bridge) -> bool {
	bridge^ = {}
	flags := posix.fcntl(posix.FD(0), .GETFL)
	if flags < 0 {
		return false
	}
	if posix.fcntl(posix.FD(0), .SETFL, flags | posix.O_NONBLOCK) < 0 {
		return false
	}
	bridge.running = true
	bridge.stdin_open = true
	bridge.status.running = true
	return true
}

mcp_bridge_stop :: proc(bridge: ^Mcp_Bridge) {
	bridge.running = false
	bridge.status.running = false
}

mcp_bridge_write_response :: proc(bridge: ^Mcp_Bridge, response: string) {
	sync.mutex_lock(&bridge.stdout_mutex)
	defer sync.mutex_unlock(&bridge.stdout_mutex)
	bytes := transmute([]u8)response
	total := int(len(bytes))
	written := 0
	for written < total {
		n := posix.write(posix.FD(1), raw_data(bytes[written:]), c.size_t(total - written))
		if n <= 0 {
			break
		}
		written += int(n)
	}
	newline := [?]u8{'\n'}
	_ = posix.write(posix.FD(1), raw_data(newline[:]), 1)
}

mcp_bridge_poll_stdio :: proc(bridge: ^Mcp_Bridge) {
	if !bridge.stdin_open {
		return
	}

	pfd := posix.pollfd {
		fd = posix.FD(0),
		events = {.IN, .HUP},
	}
	ready := posix.poll(&pfd, 1, 0)
	if ready <= 0 {
		return
	}
	if !(.IN in pfd.revents) {
		if .HUP in pfd.revents {
			bridge.stdin_open = false
			bridge.close_requested = true
			_ = mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Close})
		}
		return
	}

	if bridge.input_len >= len(bridge.input) {
		bridge.input_len = 0
	}
	n := posix.read(
		posix.FD(0),
		raw_data(bridge.input[bridge.input_len:]),
		c.size_t(len(bridge.input) - bridge.input_len),
	)
	if n < 0 {
		return
	}
	if n == 0 {
		bridge.stdin_open = false
		bridge.close_requested = true
		_ = mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Close})
		return
	}

	bridge.input_len += int(n)
	mcp_bridge_process_input(bridge)

	if .HUP in pfd.revents {
		bridge.stdin_open = false
		bridge.close_requested = true
		_ = mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Close})
	}
}

mcp_bridge_process_input :: proc(bridge: ^Mcp_Bridge) {
	start := 0
	for i := 0; i < bridge.input_len; i += 1 {
		if bridge.input[i] == '\n' {
			line := strings.trim_space(string(bridge.input[start:i]))
			if len(line) > 0 {
				response := mcp_bridge_handle_jsonrpc(bridge, line)
				if len(response) > 0 {
					mcp_bridge_write_response(bridge, response)
				}
			}
			start = i + 1
		}
	}
	if start > 0 {
		remaining := bridge.input_len - start
		if remaining > 0 {
			copy(bridge.input[:], bridge.input[start:bridge.input_len])
		}
		bridge.input_len = remaining
	}
}

mcp_bridge_handle_jsonrpc :: proc(bridge: ^Mcp_Bridge, line: string) -> string {
	id := mcp_bridge_extract_id(line)
	if strings.contains(line, "\"method\":\"initialize\"") || strings.contains(line, "\"method\": \"initialize\"") {
		return fmt.tprintf(
			"{{\"jsonrpc\":\"2.0\",\"id\":%s,\"result\":{{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{{\"tools\":{{}}}},\"serverInfo\":{{\"name\":\"vizzaodin\",\"version\":\"%s\"}}}}}}",
			id,
			engine.APP_VERSION,
		)
	}
	if strings.contains(line, "\"method\":\"notifications/initialized\"") || strings.contains(line, "\"method\": \"notifications/initialized\"") {
		return ""
	}
	if strings.contains(line, "\"method\":\"tools/list\"") || strings.contains(line, "\"method\": \"tools/list\"") {
		return fmt.tprintf("{{\"jsonrpc\":\"2.0\",\"id\":%s,\"result\":{{\"tools\":%s}}}}", id, MCP_TOOLS_JSON)
	}
	if strings.contains(line, "\"method\":\"tools/call\"") || strings.contains(line, "\"method\": \"tools/call\"") {
		name := mcp_bridge_extract_string_field(line, "name")
		return mcp_bridge_call_tool(bridge, id, name, line)
	}
	return mcp_bridge_error(id, -32601, "unsupported MCP method")
}

MCP_TOOLS_JSON :: `[
{"name":"app_status","description":"Read status from the running Vizza app.","inputSchema":{"type":"object","properties":{}}},
{"name":"profile_start","description":"Start a nonblocking UI/render profile for an app mode over a fixed number of frames.","inputSchema":{"type":"object","required":["mode"],"properties":{"mode":{"type":"string"},"frames":{"type":"number","description":"Frames to collect. Defaults to 240."},"ui_spike_ms":{"type":"number"},"render_spike_ms":{"type":"number"},"gpu_ui_spike_ms":{"type":"number"},"screenshot_spike_ms":{"type":"number"},"cap_ratio":{"type":"number"},"text_calls_per_frame":{"type":"number"},"min_width_cache_hit_rate":{"type":"number"}}}},
{"name":"profile_status","description":"Read the current UI/render profile collection state.","inputSchema":{"type":"object","properties":{}}},
{"name":"profile_report","description":"Return the latest UI/render profile report with sanitizer findings.","inputSchema":{"type":"object","properties":{}}},
{"name":"profile_reset","description":"Clear the current UI/render profile session.","inputSchema":{"type":"object","properties":{}}},
{"name":"click","description":"Inject a window-relative click through the app input path.","inputSchema":{"type":"object","required":["x","y"],"properties":{"x":{"type":"number"},"y":{"type":"number"}}}},
{"name":"mouse_down","description":"Press and hold a mouse button at a window-relative position.","inputSchema":{"type":"object","required":["x","y"],"properties":{"x":{"type":"number"},"y":{"type":"number"},"button":{"type":"number","description":"SDL-style button: 1 left, 2 middle, 3 right. Defaults to 1."}}}},
{"name":"mouse_up","description":"Release a mouse button at a window-relative position.","inputSchema":{"type":"object","required":["x","y"],"properties":{"x":{"type":"number"},"y":{"type":"number"},"button":{"type":"number","description":"SDL-style button: 1 left, 2 middle, 3 right. Defaults to 1."}}}},
{"name":"move","description":"Move the app's logical mouse position.","inputSchema":{"type":"object","required":["x","y"],"properties":{"x":{"type":"number"},"y":{"type":"number"}}}},
{"name":"wheel","description":"Inject mouse wheel delta.","inputSchema":{"type":"object","required":["delta"],"properties":{"delta":{"type":"number"}}}},
{"name":"set_mode","description":"Navigate directly to an app mode by status name, e.g. Slime_Mold, Flow_Field, Pellets, Voronoi_CA, Moire, Vectors, Primordial, Main_Menu.","inputSchema":{"type":"object","required":["mode"],"properties":{"mode":{"type":"string"}}}},
{"name":"load_vectors_image","description":"Load an image path into the Vectors image-field mode.","inputSchema":{"type":"object","required":["path"],"properties":{"path":{"type":"string"}}}},
{"name":"load_moire_image","description":"Load an image path into Moire image mode.","inputSchema":{"type":"object","required":["path"],"properties":{"path":{"type":"string"}}}},
{"name":"load_flow_image","description":"Load an image path into Flow vector-field image mode.","inputSchema":{"type":"object","required":["path"],"properties":{"path":{"type":"string"}}}},
{"name":"load_slime_mask_image","description":"Load an image path into Slime Mold mask-image mode.","inputSchema":{"type":"object","required":["path"],"properties":{"path":{"type":"string"}}}},
{"name":"load_slime_position_image","description":"Load an image path into Slime Mold image-based position generation.","inputSchema":{"type":"object","required":["path"],"properties":{"path":{"type":"string"}}}},
{"name":"close_app","description":"Ask the running app to close.","inputSchema":{"type":"object","properties":{}}},
{"name":"screenshot","description":"Return the latest engine-rendered frame as a base64 QOI data URL. Use scale, max_width, or max_height to reduce payload size.","inputSchema":{"type":"object","properties":{"scale":{"type":"number","description":"Optional 0-1 downscale factor before encoding."},"max_width":{"type":"number","description":"Optional maximum output width."},"max_height":{"type":"number","description":"Optional maximum output height."}}}}
]`

mcp_bridge_call_tool :: proc(bridge: ^Mcp_Bridge, id, name, line: string) -> string {
	switch name {
	case "app_status":
		return mcp_bridge_tool_text(id, mcp_bridge_status_json(bridge))
	case "profile_start":
		return mcp_bridge_profile_start(id, bridge, line)
	case "profile_status":
		return mcp_bridge_tool_text(id, mcp_bridge_profile_status_json(bridge))
	case "profile_report":
		return mcp_bridge_tool_text(id, mcp_bridge_profile_report_json(bridge))
	case "profile_reset":
		sync.mutex_lock(&bridge.status_mutex)
		bridge.profile = {}
		sync.mutex_unlock(&bridge.status_mutex)
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"profile\":\"reset\"}")
	case "click":
		x, x_ok := mcp_bridge_extract_number_field(line, "x")
		y, y_ok := mcp_bridge_extract_number_field(line, "y")
		if !x_ok || !y_ok {
			return mcp_bridge_error(id, -32602, "click requires numeric x and y")
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Click, x = x, y = y, button = 1}) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"click\"}")
	case "mouse_down":
		x, x_ok := mcp_bridge_extract_number_field(line, "x")
		y, y_ok := mcp_bridge_extract_number_field(line, "y")
		if !x_ok || !y_ok {
			return mcp_bridge_error(id, -32602, "mouse_down requires numeric x and y")
		}
		button := u32(1)
		if value, ok := mcp_bridge_extract_number_field(line, "button"); ok {
			button = u32(max(min(value, 3), 1))
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Mouse_Down, x = x, y = y, button = button}) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"mouse_down\"}")
	case "mouse_up":
		x, x_ok := mcp_bridge_extract_number_field(line, "x")
		y, y_ok := mcp_bridge_extract_number_field(line, "y")
		if !x_ok || !y_ok {
			return mcp_bridge_error(id, -32602, "mouse_up requires numeric x and y")
		}
		button := u32(1)
		if value, ok := mcp_bridge_extract_number_field(line, "button"); ok {
			button = u32(max(min(value, 3), 1))
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Mouse_Up, x = x, y = y, button = button}) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"mouse_up\"}")
	case "move":
		x, x_ok := mcp_bridge_extract_number_field(line, "x")
		y, y_ok := mcp_bridge_extract_number_field(line, "y")
		if !x_ok || !y_ok {
			return mcp_bridge_error(id, -32602, "move requires numeric x and y")
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Move, x = x, y = y}) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"move\"}")
	case "wheel":
		delta, ok := mcp_bridge_extract_number_field(line, "delta")
		if !ok {
			return mcp_bridge_error(id, -32602, "wheel requires numeric delta")
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Wheel, wheel_delta = delta}) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"wheel\"}")
	case "set_mode":
		mode_name := mcp_bridge_extract_string_field(line, "mode")
		mode: App_Mode
		if !mcp_bridge_app_mode_from_name(mode_name, &mode) {
			return mcp_bridge_error(id, -32602, "set_mode requires a known app mode")
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Set_Mode, mode = mode}) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"set_mode\"}")
	case "load_vectors_image":
		path := mcp_bridge_extract_string_field(line, "path")
		if len(path) == 0 {
			return mcp_bridge_error(id, -32602, "load_vectors_image requires path")
		}
		cmd := Mcp_Command{kind = .Load_Vectors_Image}
		write_fixed_string(cmd.file_path[:], path)
		if !mcp_bridge_enqueue_command(bridge, cmd) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"load_vectors_image\"}")
	case "load_moire_image":
		path := mcp_bridge_extract_string_field(line, "path")
		if len(path) == 0 {
			return mcp_bridge_error(id, -32602, "load_moire_image requires path")
		}
		cmd := Mcp_Command{kind = .Load_Moire_Image}
		write_fixed_string(cmd.file_path[:], path)
		if !mcp_bridge_enqueue_command(bridge, cmd) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"load_moire_image\"}")
	case "load_flow_image":
		path := mcp_bridge_extract_string_field(line, "path")
		if len(path) == 0 {
			return mcp_bridge_error(id, -32602, "load_flow_image requires path")
		}
		cmd := Mcp_Command{kind = .Load_Flow_Image}
		write_fixed_string(cmd.file_path[:], path)
		if !mcp_bridge_enqueue_command(bridge, cmd) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"load_flow_image\"}")
	case "load_slime_mask_image":
		path := mcp_bridge_extract_string_field(line, "path")
		if len(path) == 0 {
			return mcp_bridge_error(id, -32602, "load_slime_mask_image requires path")
		}
		cmd := Mcp_Command{kind = .Load_Slime_Mask_Image}
		write_fixed_string(cmd.file_path[:], path)
		if !mcp_bridge_enqueue_command(bridge, cmd) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"load_slime_mask_image\"}")
	case "load_slime_position_image":
		path := mcp_bridge_extract_string_field(line, "path")
		if len(path) == 0 {
			return mcp_bridge_error(id, -32602, "load_slime_position_image requires path")
		}
		cmd := Mcp_Command{kind = .Load_Slime_Position_Image}
		write_fixed_string(cmd.file_path[:], path)
		if !mcp_bridge_enqueue_command(bridge, cmd) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"load_slime_position_image\"}")
	case "close_app":
		bridge.close_requested = true
		_ = mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Close})
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"close\"}")
	case "screenshot":
		return mcp_bridge_screenshot(id, bridge, line)
	}
	return mcp_bridge_error(id, -32602, "unknown tool")
}

mcp_bridge_profile_default_thresholds :: proc() -> Mcp_Profile_Thresholds {
	return {
		ui_spike_ms = 12,
		render_spike_ms = 20,
		gpu_ui_spike_ms = 8,
		screenshot_spike_ms = 8,
		cap_ratio = 0.85,
		text_calls_per_frame = 512,
		min_width_cache_hit_rate = 0.70,
	}
}

mcp_bridge_profile_start :: proc(id: string, bridge: ^Mcp_Bridge, line: string) -> string {
	mode_name := mcp_bridge_extract_string_field(line, "mode")
	mode: App_Mode
	if !mcp_bridge_app_mode_from_name(mode_name, &mode) {
		return mcp_bridge_error(id, -32602, "profile_start requires a known mode")
	}

	frames := MCP_PROFILE_DEFAULT_FRAMES
	if value, ok := mcp_bridge_extract_number_field(line, "frames"); ok {
		frames = u32(max(value, 1))
	}

	thresholds := mcp_bridge_profile_default_thresholds()
	if value, ok := mcp_bridge_extract_number_field(line, "ui_spike_ms"); ok {
		thresholds.ui_spike_ms = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "render_spike_ms"); ok {
		thresholds.render_spike_ms = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "gpu_ui_spike_ms"); ok {
		thresholds.gpu_ui_spike_ms = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "screenshot_spike_ms"); ok {
		thresholds.screenshot_spike_ms = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "cap_ratio"); ok {
		thresholds.cap_ratio = min(max(value, 0.1), 1)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "text_calls_per_frame"); ok {
		thresholds.text_calls_per_frame = u32(max(value, 1))
	}
	if value, ok := mcp_bridge_extract_number_field(line, "min_width_cache_hit_rate"); ok {
		thresholds.min_width_cache_hit_rate = min(max(value, 0), 1)
	}

	if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Set_Mode, mode = mode}) {
		return mcp_bridge_queue_error(id, bridge)
	}

	sync.mutex_lock(&bridge.status_mutex)
	bridge.profile = {
		requested = true,
		target_mode = mode,
		target_frames = frames,
		thresholds = thresholds,
	}
	sync.mutex_unlock(&bridge.status_mutex)

	return mcp_bridge_tool_text(id, fmt.tprintf("{{\"ok\":true,\"queued\":\"profile_start\",\"mode\":\"%v\",\"frames\":%d}}", mode, frames))
}

mcp_bridge_profile_record_locked :: proc(bridge: ^Mcp_Bridge, msg: Render_To_Ui_Message) {
	profile := &bridge.profile
	if !profile.requested || profile.complete {
		return
	}
	if !profile.active {
		if msg.app_mode != profile.target_mode {
			return
		}
		profile.active = true
		profile.start_frame_index = msg.frame_index
		profile.last_frame_index = msg.frame_index
	}
	if msg.app_mode != profile.target_mode {
		return
	}

	if profile.collected_frames > 0 && msg.frame_index <= profile.last_frame_index {
		profile.frame_stall_count += 1
	}
	profile.last_frame_index = msg.frame_index
	profile.collected_frames += 1

	mcp_bridge_profile_accum(&profile.frame_ms_sum, &profile.frame_ms_max, msg.frame_ms)
	mcp_bridge_profile_accum(&profile.sim_sum, &profile.sim_max, msg.sim_ms)
	mcp_bridge_profile_accum(&profile.ui_sum, &profile.ui_max, msg.ui_ms)
	mcp_bridge_profile_accum(&profile.render_sum, &profile.render_max, msg.render_ms)
	mcp_bridge_profile_accum(&profile.submit_sum, &profile.submit_max, msg.submit_ms)
	mcp_bridge_profile_accum(&profile.screenshot_sum, &profile.screenshot_max, msg.screenshot_ms)
	mcp_bridge_profile_accum(&profile.ui_build_sum, &profile.ui_build_max, msg.ui_build_ms)
	mcp_bridge_profile_accum(&profile.ui_overlay_sum, &profile.ui_overlay_max, msg.ui_overlay_ms)
	mcp_bridge_profile_accum(&profile.gpu_ui_overlay_sum, &profile.gpu_ui_overlay_max, msg.gpu_ui_overlay_ms)
	mcp_bridge_profile_accum(&profile.text_width_ms_sum, &profile.text_width_ms_max, msg.text_width_ms)
	mcp_bridge_profile_accum(&profile.text_shape_ms_sum, &profile.text_shape_ms_max, msg.text_shape_ms)
	mcp_bridge_profile_accum(&profile.text_wrap_ms_sum, &profile.text_wrap_ms_max, msg.text_wrap_ms)

	profile.text_width_calls += msg.text_width_calls
	profile.text_width_cache_hits += msg.text_width_cache_hits
	profile.text_shape_calls += msg.text_shape_calls
	profile.text_shape_glyphs += msg.text_shape_glyphs
	profile.text_wrap_calls += msg.text_wrap_calls
	if msg.screenshot_captured {
		profile.screenshot_captures += 1
	}

	if msg.gui_command_count > profile.max_gui_command_count {
		profile.max_gui_command_count = msg.gui_command_count
	}
	if msg.ui_vertex_count > profile.max_ui_vertex_count {
		profile.max_ui_vertex_count = msg.ui_vertex_count
	}
	if msg.ui_batch_count > profile.max_ui_batch_count {
		profile.max_ui_batch_count = msg.ui_batch_count
	}
	if msg.ui_clear_rect_count > profile.max_ui_clear_rect_count {
		profile.max_ui_clear_rect_count = msg.ui_clear_rect_count
	}
	queue_count := u32(max(bridge.pending_command_count, 0))
	if queue_count > profile.max_command_queue_count {
		profile.max_command_queue_count = queue_count
	}

	if msg.ui_ms >= profile.thresholds.ui_spike_ms {
		profile.ui_spike_count += 1
	}
	if msg.render_ms >= profile.thresholds.render_spike_ms {
		profile.render_spike_count += 1
	}
	if msg.gpu_profiling_enabled && msg.gpu_ui_overlay_ms >= profile.thresholds.gpu_ui_spike_ms {
		profile.gpu_ui_spike_count += 1
	}
	if msg.screenshot_captured && msg.screenshot_ms >= profile.thresholds.screenshot_spike_ms {
		profile.screenshot_spike_count += 1
	}
	if queue_count >= MCP_PROFILE_QUEUE_WARN_COUNT {
		profile.command_queue_pressure_count += 1
	}
	if msg.gui_command_count >= MCP_PROFILE_GUI_COMMAND_WARN_COUNT {
		profile.gui_command_pressure_count += 1
	}
	if mcp_bridge_profile_near_cap(msg.ui_vertex_count, engine.UI_MAX_VERTICES, profile.thresholds.cap_ratio) {
		profile.ui_vertex_pressure_count += 1
	}
	if mcp_bridge_profile_near_cap(msg.ui_batch_count, engine.UI_MAX_DRAW_BATCHES, profile.thresholds.cap_ratio) {
		profile.ui_batch_pressure_count += 1
	}
	if mcp_bridge_profile_near_cap(msg.ui_clear_rect_count, engine.UI_MAX_CLEAR_RECTS, profile.thresholds.cap_ratio) {
		profile.ui_clear_rect_pressure_count += 1
	}

	if profile.collected_frames >= profile.target_frames {
		profile.complete = true
		profile.active = false
	}
}

mcp_bridge_profile_accum :: proc(sum, max_value: ^f64, value: f32) {
	v := f64(value)
	sum^ += v
	if v > max_value^ {
		max_value^ = v
	}
}

mcp_bridge_profile_near_cap :: proc(value, cap: u32, ratio: f32) -> bool {
	if cap == 0 {
		return false
	}
	return f32(value) >= f32(cap) * ratio
}

mcp_bridge_profile_avg :: proc(sum: f64, frames: u32) -> f64 {
	if frames == 0 {
		return 0
	}
	return sum / f64(frames)
}

mcp_bridge_profile_status_json :: proc(bridge: ^Mcp_Bridge) -> string {
	sync.mutex_lock(&bridge.status_mutex)
	profile := bridge.profile
	current_mode := bridge.status.app_mode
	frame_index := bridge.status.frame_index
	sync.mutex_unlock(&bridge.status_mutex)

	return fmt.tprintf(
		"{{\"ok\":true,\"requested\":%v,\"active\":%v,\"complete\":%v,\"target_mode\":\"%v\",\"current_mode\":\"%v\",\"target_frames\":%d,\"collected_frames\":%d,\"latest_frame_index\":%d}}",
		profile.requested,
		profile.active,
		profile.complete,
		profile.target_mode,
		current_mode,
		profile.target_frames,
		profile.collected_frames,
		frame_index,
	)
}

mcp_bridge_profile_report_json :: proc(bridge: ^Mcp_Bridge) -> string {
	sync.mutex_lock(&bridge.status_mutex)
	profile := bridge.profile
	sync.mutex_unlock(&bridge.status_mutex)

	warnings := mcp_bridge_profile_warnings_json(profile)
	frames := profile.collected_frames
	width_cache_hit_rate := f64(1)
	if profile.text_width_calls > 0 {
		width_cache_hit_rate = f64(profile.text_width_cache_hits) / f64(profile.text_width_calls)
	}

	return fmt.tprintf(
		"{{\"ok\":true,\"requested\":%v,\"active\":%v,\"complete\":%v,\"target_mode\":\"%v\",\"target_frames\":%d,\"collected_frames\":%d,\"start_frame_index\":%d,\"last_frame_index\":%d,\"averages_ms\":{{\"frame\":%.4f,\"sim\":%.4f,\"ui\":%.4f,\"render\":%.4f,\"submit\":%.4f,\"screenshot\":%.4f,\"ui_build\":%.4f,\"ui_overlay\":%.4f,\"gpu_ui_overlay\":%.4f,\"text_width\":%.4f,\"text_shape\":%.4f,\"text_wrap\":%.4f}},\"max_ms\":{{\"frame\":%.4f,\"sim\":%.4f,\"ui\":%.4f,\"render\":%.4f,\"submit\":%.4f,\"screenshot\":%.4f,\"ui_build\":%.4f,\"ui_overlay\":%.4f,\"gpu_ui_overlay\":%.4f,\"text_width\":%.4f,\"text_shape\":%.4f,\"text_wrap\":%.4f}},\"counts\":{{\"screenshot_captures\":%d,\"text_width_calls\":%d,\"text_width_cache_hits\":%d,\"text_width_cache_hit_rate\":%.4f,\"text_shape_calls\":%d,\"text_shape_glyphs\":%d,\"text_wrap_calls\":%d,\"max_gui_command_count\":%d,\"max_ui_vertex_count\":%d,\"max_ui_batch_count\":%d,\"max_ui_clear_rect_count\":%d,\"max_command_queue_count\":%d}},\"sanitizer\":{{\"ui_spike_count\":%d,\"render_spike_count\":%d,\"gpu_ui_spike_count\":%d,\"screenshot_spike_count\":%d,\"frame_stall_count\":%d,\"command_queue_pressure_count\":%d,\"gui_command_pressure_count\":%d,\"ui_vertex_pressure_count\":%d,\"ui_batch_pressure_count\":%d,\"ui_clear_rect_pressure_count\":%d,\"warnings\":%s}}}}",
		profile.requested,
		profile.active,
		profile.complete,
		profile.target_mode,
		profile.target_frames,
		frames,
		profile.start_frame_index,
		profile.last_frame_index,
		mcp_bridge_profile_avg(profile.frame_ms_sum, frames),
		mcp_bridge_profile_avg(profile.sim_sum, frames),
		mcp_bridge_profile_avg(profile.ui_sum, frames),
		mcp_bridge_profile_avg(profile.render_sum, frames),
		mcp_bridge_profile_avg(profile.submit_sum, frames),
		mcp_bridge_profile_avg(profile.screenshot_sum, frames),
		mcp_bridge_profile_avg(profile.ui_build_sum, frames),
		mcp_bridge_profile_avg(profile.ui_overlay_sum, frames),
		mcp_bridge_profile_avg(profile.gpu_ui_overlay_sum, frames),
		mcp_bridge_profile_avg(profile.text_width_ms_sum, frames),
		mcp_bridge_profile_avg(profile.text_shape_ms_sum, frames),
		mcp_bridge_profile_avg(profile.text_wrap_ms_sum, frames),
		profile.frame_ms_max,
		profile.sim_max,
		profile.ui_max,
		profile.render_max,
		profile.submit_max,
		profile.screenshot_max,
		profile.ui_build_max,
		profile.ui_overlay_max,
		profile.gpu_ui_overlay_max,
		profile.text_width_ms_max,
		profile.text_shape_ms_max,
		profile.text_wrap_ms_max,
		profile.screenshot_captures,
		profile.text_width_calls,
		profile.text_width_cache_hits,
		width_cache_hit_rate,
		profile.text_shape_calls,
		profile.text_shape_glyphs,
		profile.text_wrap_calls,
		profile.max_gui_command_count,
		profile.max_ui_vertex_count,
		profile.max_ui_batch_count,
		profile.max_ui_clear_rect_count,
		profile.max_command_queue_count,
		profile.ui_spike_count,
		profile.render_spike_count,
		profile.gpu_ui_spike_count,
		profile.screenshot_spike_count,
		profile.frame_stall_count,
		profile.command_queue_pressure_count,
		profile.gui_command_pressure_count,
		profile.ui_vertex_pressure_count,
		profile.ui_batch_pressure_count,
		profile.ui_clear_rect_pressure_count,
		warnings,
	)
}

mcp_bridge_profile_warnings_json :: proc(profile: Mcp_Profile_Session) -> string {
	builder: strings.Builder
	strings.builder_init(&builder, context.temp_allocator)
	strings.write_string(&builder, "[")
	count := 0
	mcp_bridge_profile_warning_append(&builder, &count, !profile.requested, "profile has not been started")
	mcp_bridge_profile_warning_append(&builder, &count, profile.requested && profile.collected_frames == 0, "profile has not collected frames yet")
	mcp_bridge_profile_warning_append(&builder, &count, profile.frame_stall_count > 0, fmt.tprintf("frame index did not advance monotonically %d time(s)", profile.frame_stall_count))
	mcp_bridge_profile_warning_append(&builder, &count, profile.command_queue_pressure_count > 0, fmt.tprintf("MCP input command queue reached pressure threshold %d time(s); max=%d", profile.command_queue_pressure_count, profile.max_command_queue_count))
	mcp_bridge_profile_warning_append(&builder, &count, profile.gui_command_pressure_count > 0, fmt.tprintf("GUI command count exceeded growth threshold %d time(s); max=%d", profile.gui_command_pressure_count, profile.max_gui_command_count))
	mcp_bridge_profile_warning_append(&builder, &count, profile.ui_vertex_pressure_count > 0, fmt.tprintf("UI vertex count approached renderer cap %d time(s); max=%d cap=%d", profile.ui_vertex_pressure_count, profile.max_ui_vertex_count, engine.UI_MAX_VERTICES))
	mcp_bridge_profile_warning_append(&builder, &count, profile.ui_batch_pressure_count > 0, fmt.tprintf("UI batch count approached renderer cap %d time(s); max=%d cap=%d", profile.ui_batch_pressure_count, profile.max_ui_batch_count, engine.UI_MAX_DRAW_BATCHES))
	mcp_bridge_profile_warning_append(&builder, &count, profile.ui_clear_rect_pressure_count > 0, fmt.tprintf("UI clear rect count approached renderer cap %d time(s); max=%d cap=%d", profile.ui_clear_rect_pressure_count, profile.max_ui_clear_rect_count, engine.UI_MAX_CLEAR_RECTS))
	mcp_bridge_profile_warning_append(&builder, &count, profile.ui_spike_count > 0, fmt.tprintf("UI frame build exceeded %.2f ms %d time(s); max=%.4f ms", profile.thresholds.ui_spike_ms, profile.ui_spike_count, profile.ui_max))
	mcp_bridge_profile_warning_append(&builder, &count, profile.render_spike_count > 0, fmt.tprintf("render frame exceeded %.2f ms %d time(s); max=%.4f ms", profile.thresholds.render_spike_ms, profile.render_spike_count, profile.render_max))
	mcp_bridge_profile_warning_append(&builder, &count, profile.gpu_ui_spike_count > 0, fmt.tprintf("GPU UI overlay exceeded %.2f ms %d time(s); max=%.4f ms", profile.thresholds.gpu_ui_spike_ms, profile.gpu_ui_spike_count, profile.gpu_ui_overlay_max))
	mcp_bridge_profile_warning_append(&builder, &count, profile.screenshot_spike_count > 0, fmt.tprintf("screenshot readback exceeded %.2f ms %d time(s); max=%.4f ms", profile.thresholds.screenshot_spike_ms, profile.screenshot_spike_count, profile.screenshot_max))
	if profile.collected_frames > 0 {
		text_calls_per_frame := (profile.text_width_calls + profile.text_shape_calls + profile.text_wrap_calls) / u64(profile.collected_frames)
		mcp_bridge_profile_warning_append(&builder, &count, text_calls_per_frame > u64(profile.thresholds.text_calls_per_frame), fmt.tprintf("text measurement calls averaged %d per frame; threshold=%d", text_calls_per_frame, profile.thresholds.text_calls_per_frame))
		if profile.text_width_calls > 0 {
			hit_rate := f64(profile.text_width_cache_hits) / f64(profile.text_width_calls)
			mcp_bridge_profile_warning_append(&builder, &count, hit_rate < f64(profile.thresholds.min_width_cache_hit_rate), fmt.tprintf("text width cache hit rate %.4f below threshold %.4f", hit_rate, profile.thresholds.min_width_cache_hit_rate))
		}
	}
	strings.write_string(&builder, "]")
	return strings.to_string(builder)
}

mcp_bridge_profile_warning_append :: proc(builder: ^strings.Builder, count: ^int, condition: bool, text: string) {
	if !condition || count^ >= MCP_PROFILE_MAX_WARNINGS {
		return
	}
	if count^ > 0 {
		strings.write_string(builder, ",")
	}
	strings.write_string(builder, "\"")
	strings.write_string(builder, mcp_bridge_json_escape(text))
	strings.write_string(builder, "\"")
	count^ += 1
}

mcp_bridge_screenshot :: proc(id: string, bridge: ^Mcp_Bridge, line: string) -> string {
	if bridge.screenshot == nil {
		return mcp_bridge_error(id, -32000, "screenshot buffer is not attached")
	}
	engine.screenshot_state_request_capture(bridge.screenshot)
	scale := f32(1)
	max_width: u32
	max_height: u32
	if value, has_value := mcp_bridge_extract_number_field(line, "scale"); has_value {
		scale = min(max(value, 0.01), 1)
	}
	if value, has_value := mcp_bridge_extract_number_field(line, "max_width"); has_value {
		max_width = u32(max(value, 1))
	}
	if value, has_value := mcp_bridge_extract_number_field(line, "max_height"); has_value {
		max_height = u32(max(value, 1))
	}
	qoi_bytes, width, height, sequence, ok := engine.screenshot_state_copy_qoi_sized(bridge.screenshot, max_width, max_height, scale, context.temp_allocator)
	if !ok {
		return mcp_bridge_error(id, -32000, "no rendered frame is available yet")
	}
	encoded, err := base64.encode(qoi_bytes, allocator = context.temp_allocator)
	if err != nil {
		return mcp_bridge_error(id, -32000, "failed to encode screenshot")
	}
	return mcp_bridge_tool_text(id, fmt.tprintf(
		"{{\"ok\":true,\"format\":\"qoi\",\"mime\":\"image/qoi\",\"width\":%d,\"height\":%d,\"sequence\":%d,\"bytes\":%d,\"data_url\":\"data:image/qoi;base64,%s\"}}",
		width,
		height,
		sequence,
		len(qoi_bytes),
		encoded,
	))
}

mcp_bridge_tool_text :: proc(id, text: string) -> string {
	return fmt.tprintf(
		"{{\"jsonrpc\":\"2.0\",\"id\":%s,\"result\":{{\"content\":[{{\"type\":\"text\",\"text\":\"%s\"}}]}}}}",
		id,
		mcp_bridge_json_escape(text),
	)
}

mcp_bridge_error :: proc(id: string, code: int, message: string) -> string {
	return fmt.tprintf(
		"{{\"jsonrpc\":\"2.0\",\"id\":%s,\"error\":{{\"code\":%d,\"message\":\"%s\"}}}}",
		id,
		code,
		mcp_bridge_json_escape(message),
	)
}

mcp_bridge_enqueue_command :: proc(bridge: ^Mcp_Bridge, cmd: Mcp_Command) -> bool {
	if bridge.pending_command_count >= len(bridge.pending_commands) {
		return false
	}
	bridge.pending_commands[bridge.pending_command_count] = cmd
	bridge.pending_command_count += 1
	return true
}

mcp_bridge_command_queue_status :: proc(bridge: ^Mcp_Bridge) -> Mcp_Command_Queue_Status {
	return {count = bridge.pending_command_count, closed = false}
}

mcp_bridge_queue_error :: proc(id: string, bridge: ^Mcp_Bridge) -> string {
	queue_status := mcp_bridge_command_queue_status(bridge)
	reason := "full"
	if queue_status.closed {
		reason = "closed"
	}
	return mcp_bridge_error(id, -32000, fmt.tprintf("input command queue is %s (count=%d)", reason, queue_status.count))
}

mcp_bridge_app_mode_from_name :: proc(name: string, out: ^App_Mode) -> bool {
	switch name {
	case "Main_Menu", "main_menu":
		out^ = .Main_Menu
	case "Slime_Mold", "slime_mold":
		out^ = .Slime_Mold
	case "Gray_Scott", "gray_scott":
		out^ = .Gray_Scott
	case "Particle_Life", "particle_life":
		out^ = .Particle_Life
	case "Flow_Field", "flow_field":
		out^ = .Flow_Field
	case "Pellets", "pellets":
		out^ = .Pellets
	case "Gradient_Editor", "gradient_editor":
		out^ = .Gradient_Editor
	case "Voronoi_CA", "voronoi_ca":
		out^ = .Voronoi_CA
	case "Moire", "moire":
		out^ = .Moire
	case "Vectors", "vectors":
		out^ = .Vectors
	case "Primordial", "primordial":
		out^ = .Primordial
	case "Options", "options":
		out^ = .Options
	case "How_To_Play", "how_to_play":
		out^ = .How_To_Play
	case "Theme_Preview", "theme_preview":
		out^ = .Theme_Preview
	case:
		return false
	}
	return true
}

mcp_bridge_drain_commands :: proc(bridge: ^Mcp_Bridge, app: ^App_State) {
	if bridge.close_requested {
		app.running = false
	}
	for idx := 0; idx < bridge.pending_command_count; idx += 1 {
		cmd := bridge.pending_commands[idx]
		switch cmd.kind {
		case .Click:
			app.input.mouse_pos = {cmd.x, cmd.y}
			app.input.mouse_down = false
			app.input.mouse_pressed = true
			app.input.mouse_released = true
			app.input.mouse_button = cmd.button
		case .Mouse_Down:
			app.input.mouse_pos = {cmd.x, cmd.y}
			app.input.mouse_down = true
			app.input.mouse_pressed = true
			app.input.mouse_released = false
			app.held_mouse_button = cmd.button
			app.input.mouse_button = cmd.button
		case .Mouse_Up:
			app.input.mouse_pos = {cmd.x, cmd.y}
			app.input.mouse_down = false
			app.input.mouse_pressed = false
			app.input.mouse_released = true
			app.input.mouse_button = cmd.button
			if app.held_mouse_button == cmd.button {
				app.held_mouse_button = 0
			}
		case .Move:
			app.input.mouse_pos = {cmd.x, cmd.y}
		case .Wheel:
			app.input.wheel_delta += cmd.wheel_delta
		case .Set_Mode:
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Set_App_Mode
			render_cmd.app_mode = cmd.mode
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
		case .Close:
			app.running = false
		case .Load_Vectors_Image:
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Load_Vectors_Image
			render_cmd.file_path = cmd.file_path
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
		case .Load_Moire_Image:
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Load_Moire_Image
			render_cmd.file_path = cmd.file_path
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
		case .Load_Flow_Image:
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Load_Flow_Image
			render_cmd.file_path = cmd.file_path
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
		case .Load_Slime_Mask_Image:
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Load_Slime_Mask_Image
			render_cmd.file_path = cmd.file_path
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
		case .Load_Slime_Position_Image:
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Load_Slime_Position_Image
			render_cmd.file_path = cmd.file_path
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
		}
	}
	bridge.pending_command_count = 0
}

mcp_bridge_publish_frame :: proc(bridge: ^Mcp_Bridge, app: ^App_State, width, height, logical_width, logical_height: i32) {
	sync.mutex_lock(&bridge.status_mutex)
	bridge.status.running = app.running
	bridge.status.frame_index = app.frame_index
	bridge.status.window_width = width
	bridge.status.window_height = height
	bridge.status.logical_window_width = logical_width
	bridge.status.logical_window_height = logical_height
	bridge.status.mouse_pos = app.input.mouse_pos
	bridge.status.mouse_down = app.input.mouse_down
	sync.mutex_unlock(&bridge.status_mutex)
}

mcp_bridge_publish_render_message :: proc(bridge: ^Mcp_Bridge, msg: Render_To_Ui_Message) {
	sync.mutex_lock(&bridge.status_mutex)
	if msg.kind == .Frame_Stats {
		bridge.status.last_fps = msg.fps
		bridge.status.last_frame_ms = msg.frame_ms
		bridge.status.app_mode = msg.app_mode
		bridge.status.gray_scott_camera_x = msg.gray_scott_camera_x
		bridge.status.gray_scott_camera_y = msg.gray_scott_camera_y
		bridge.status.gray_scott_camera_zoom = msg.gray_scott_camera_zoom
		bridge.status.gray_scott_controls_visible = msg.gray_scott_controls_visible
		bridge.status.gray_scott_paused = msg.gray_scott_paused
		bridge.status.particle_life_camera_x = msg.particle_life_camera_x
		bridge.status.particle_life_camera_y = msg.particle_life_camera_y
		bridge.status.particle_life_camera_zoom = msg.particle_life_camera_zoom
		bridge.status.particle_life_ready = msg.particle_life_ready
		bridge.status.particle_life_paused = msg.particle_life_paused
		bridge.status.particle_life_controls_visible = msg.particle_life_controls_visible
		bridge.status.particle_life_frame_index = msg.particle_life_frame_index
		bridge.status.particle_life_particle_count = msg.particle_life_particle_count
		bridge.status.particle_life_species_count = msg.particle_life_species_count
		bridge.status.particle_life_requested_particle_count = msg.particle_life_requested_particle_count
		bridge.status.particle_life_requested_species_count = msg.particle_life_requested_species_count
		bridge.status.particle_life_trails_enabled = msg.particle_life_trails_enabled
		bridge.status.particle_life_infinite_tiles_enabled = msg.particle_life_infinite_tiles_enabled
		bridge.status.gpu_profiling_supported = msg.gpu_profiling_supported
		bridge.status.gpu_profiling_enabled = msg.gpu_profiling_enabled
		bridge.status.gpu_simulation_step_ms = msg.gpu_simulation_step_ms
		bridge.status.gpu_simulation_present_ms = msg.gpu_simulation_present_ms
		bridge.status.gpu_ui_overlay_ms = msg.gpu_ui_overlay_ms
		bridge.status.gpu_frame_total_ms = msg.gpu_frame_total_ms
		bridge.status.sim_ms = msg.sim_ms
		bridge.status.ui_ms = msg.ui_ms
		bridge.status.render_ms = msg.render_ms
		bridge.status.submit_ms = msg.submit_ms
		bridge.status.screenshot_ms = msg.screenshot_ms
		bridge.status.screenshot_captured = msg.screenshot_captured
		bridge.status.ui_build_ms = msg.ui_build_ms
		bridge.status.ui_overlay_ms = msg.ui_overlay_ms
		bridge.status.gui_command_count = msg.gui_command_count
		bridge.status.ui_vertex_count = msg.ui_vertex_count
		bridge.status.ui_batch_count = msg.ui_batch_count
		bridge.status.ui_clear_rect_count = msg.ui_clear_rect_count
		bridge.status.main_menu_preview_visible_slot_count = msg.main_menu_preview_visible_slot_count
		bridge.status.main_menu_preview_warmed_mode_count = msg.main_menu_preview_warmed_mode_count
		bridge.status.main_menu_preview_fallback_fill_count = msg.main_menu_preview_fallback_fill_count
		bridge.status.main_menu_preview_skipped_present_count = msg.main_menu_preview_skipped_present_count
		bridge.status.text_width_calls = msg.text_width_calls
		bridge.status.text_width_cache_hits = msg.text_width_cache_hits
		bridge.status.text_width_ms = msg.text_width_ms
		bridge.status.text_shape_calls = msg.text_shape_calls
		bridge.status.text_shape_glyphs = msg.text_shape_glyphs
		bridge.status.text_shape_ms = msg.text_shape_ms
		bridge.status.text_wrap_calls = msg.text_wrap_calls
		bridge.status.text_wrap_ms = msg.text_wrap_ms
		bridge.status.cpu_wait_fence_ms = msg.cpu_wait_fence_ms
		bridge.status.cpu_acquire_ms = msg.cpu_acquire_ms
		bridge.status.cpu_command_begin_ms = msg.cpu_command_begin_ms
		bridge.status.cpu_end_command_ms = msg.cpu_end_command_ms
		bridge.status.cpu_queue_submit_ms = msg.cpu_queue_submit_ms
		bridge.status.cpu_queue_present_ms = msg.cpu_queue_present_ms
		bridge.status.present_mode = msg.present_mode
		bridge.status.command_render_pass_count = msg.command_render_pass_count
		bridge.status.command_compute_dispatch_count = msg.command_compute_dispatch_count
		bridge.status.command_draw_count = msg.command_draw_count
		bridge.status.command_pipeline_bind_count = msg.command_pipeline_bind_count
		bridge.status.command_descriptor_bind_count = msg.command_descriptor_bind_count
		bridge.status.command_pipeline_barrier_count = msg.command_pipeline_barrier_count
		bridge.status.command_transfer_copy_count = msg.command_transfer_copy_count
		bridge.status.command_ui_batch_count = msg.command_ui_batch_count
		bridge.status.command_backdrop_blur_pass_count = msg.command_backdrop_blur_pass_count
		mcp_bridge_profile_record_locked(bridge, msg)
	} else {
		bridge.status.last_message = msg.text
	}
	sync.mutex_unlock(&bridge.status_mutex)
}

mcp_bridge_status_json :: proc(bridge: ^Mcp_Bridge) -> string {
	sync.mutex_lock(&bridge.status_mutex)
	status := bridge.status
	sync.mutex_unlock(&bridge.status_mutex)
	queue_status := mcp_bridge_command_queue_status(bridge)

	return fmt.tprintf(
		"{{\"ok\":true,\"running\":%v,\"frame_index\":%d,\"window_width\":%d,\"window_height\":%d,\"logical_window_width\":%d,\"logical_window_height\":%d,\"mouse_x\":%.2f,\"mouse_y\":%.2f,\"mouse_down\":%v,\"fps\":%.2f,\"frame_ms\":%.2f,\"app_mode\":\"%v\",\"gray_scott_camera_x\":%.4f,\"gray_scott_camera_y\":%.4f,\"gray_scott_camera_zoom\":%.4f,\"gray_scott_controls_visible\":%v,\"gray_scott_paused\":%v,\"particle_life_camera_x\":%.4f,\"particle_life_camera_y\":%.4f,\"particle_life_camera_zoom\":%.4f,\"particle_life_ready\":%v,\"particle_life_paused\":%v,\"particle_life_controls_visible\":%v,\"particle_life_frame_index\":%d,\"particle_life_particle_count\":%d,\"particle_life_species_count\":%d,\"particle_life_requested_particle_count\":%d,\"particle_life_requested_species_count\":%d,\"particle_life_trails_enabled\":%v,\"particle_life_infinite_tiles_enabled\":%v,\"gpu_profiling_supported\":%v,\"gpu_profiling_enabled\":%v,\"gpu_simulation_step_ms\":%.4f,\"gpu_simulation_present_ms\":%.4f,\"gpu_ui_overlay_ms\":%.4f,\"gpu_frame_total_ms\":%.4f,\"sim_ms\":%.4f,\"ui_ms\":%.4f,\"render_ms\":%.4f,\"submit_ms\":%.4f,\"screenshot_ms\":%.4f,\"screenshot_captured\":%v,\"ui_build_ms\":%.4f,\"ui_overlay_ms\":%.4f,\"gui_command_count\":%d,\"ui_vertex_count\":%d,\"ui_batch_count\":%d,\"ui_clear_rect_count\":%d,\"main_menu_preview_visible_slot_count\":%d,\"main_menu_preview_warmed_mode_count\":%d,\"main_menu_preview_fallback_fill_count\":%d,\"main_menu_preview_skipped_present_count\":%d,\"text_width_calls\":%d,\"text_width_cache_hits\":%d,\"text_width_ms\":%.4f,\"text_shape_calls\":%d,\"text_shape_glyphs\":%d,\"text_shape_ms\":%.4f,\"text_wrap_calls\":%d,\"text_wrap_ms\":%.4f,\"cpu_wait_fence_ms\":%.4f,\"cpu_acquire_ms\":%.4f,\"cpu_command_begin_ms\":%.4f,\"cpu_end_command_ms\":%.4f,\"cpu_queue_submit_ms\":%.4f,\"cpu_queue_present_ms\":%.4f,\"present_mode\":\"%s\",\"command_render_pass_count\":%d,\"command_compute_dispatch_count\":%d,\"command_draw_count\":%d,\"command_pipeline_bind_count\":%d,\"command_descriptor_bind_count\":%d,\"command_pipeline_barrier_count\":%d,\"command_transfer_copy_count\":%d,\"command_ui_batch_count\":%d,\"command_backdrop_blur_pass_count\":%d,\"command_queue_count\":%d,\"command_queue_closed\":%v,\"last_message\":\"%s\"}}",
		status.running,
		status.frame_index,
		status.window_width,
		status.window_height,
		status.logical_window_width,
		status.logical_window_height,
		status.mouse_pos.x,
		status.mouse_pos.y,
		status.mouse_down,
		status.last_fps,
		status.last_frame_ms,
		status.app_mode,
		status.gray_scott_camera_x,
		status.gray_scott_camera_y,
		status.gray_scott_camera_zoom,
		status.gray_scott_controls_visible,
		status.gray_scott_paused,
		status.particle_life_camera_x,
		status.particle_life_camera_y,
		status.particle_life_camera_zoom,
		status.particle_life_ready,
		status.particle_life_paused,
		status.particle_life_controls_visible,
		status.particle_life_frame_index,
		status.particle_life_particle_count,
		status.particle_life_species_count,
		status.particle_life_requested_particle_count,
		status.particle_life_requested_species_count,
		status.particle_life_trails_enabled,
		status.particle_life_infinite_tiles_enabled,
		status.gpu_profiling_supported,
		status.gpu_profiling_enabled,
		status.gpu_simulation_step_ms,
		status.gpu_simulation_present_ms,
		status.gpu_ui_overlay_ms,
		status.gpu_frame_total_ms,
		status.sim_ms,
		status.ui_ms,
		status.render_ms,
		status.submit_ms,
		status.screenshot_ms,
		status.screenshot_captured,
		status.ui_build_ms,
		status.ui_overlay_ms,
		status.gui_command_count,
		status.ui_vertex_count,
		status.ui_batch_count,
		status.ui_clear_rect_count,
		status.main_menu_preview_visible_slot_count,
		status.main_menu_preview_warmed_mode_count,
		status.main_menu_preview_fallback_fill_count,
		status.main_menu_preview_skipped_present_count,
		status.text_width_calls,
		status.text_width_cache_hits,
		status.text_width_ms,
		status.text_shape_calls,
		status.text_shape_glyphs,
		status.text_shape_ms,
		status.text_wrap_calls,
		status.text_wrap_ms,
		status.cpu_wait_fence_ms,
		status.cpu_acquire_ms,
		status.cpu_command_begin_ms,
		status.cpu_end_command_ms,
		status.cpu_queue_submit_ms,
		status.cpu_queue_present_ms,
		mcp_bridge_json_escape(fixed_string(status.present_mode[:])),
		status.command_render_pass_count,
		status.command_compute_dispatch_count,
		status.command_draw_count,
		status.command_pipeline_bind_count,
		status.command_descriptor_bind_count,
		status.command_pipeline_barrier_count,
		status.command_transfer_copy_count,
		status.command_ui_batch_count,
		status.command_backdrop_blur_pass_count,
		queue_status.count,
		queue_status.closed,
		mcp_bridge_json_escape(fixed_string(status.last_message[:])),
	)
}

mcp_bridge_extract_id :: proc(line: string) -> string {
	key := "\"id\""
	i := strings.index(line, key)
	if i < 0 {
		return "null"
	}
	rest := line[i + len(key):]
	colon := strings.index(rest, ":")
	if colon < 0 {
		return "null"
	}
	rest = strings.trim_space(rest[colon + 1:])
	end := 0
	in_string := false
	for ch, idx in rest {
		if idx == 0 && ch == '"' {
			in_string = true
		} else if in_string && ch == '"' {
			end = idx + 1
			break
		} else if !in_string && (ch == ',' || ch == '}') {
			end = idx
			break
		}
	}
	if end <= 0 {
		end = len(rest)
	}
	return strings.trim_space(rest[:end])
}

mcp_bridge_extract_string_field :: proc(line, field: string) -> string {
	key := fmt.tprintf("\"%s\"", field)
	i := strings.index(line, key)
	if i < 0 {
		return ""
	}
	rest := line[i + len(key):]
	colon := strings.index(rest, ":")
	if colon < 0 {
		return ""
	}
	rest = strings.trim_space(rest[colon + 1:])
	if len(rest) == 0 || rest[0] != '"' {
		return ""
	}
	start := 1
	for idx := start; idx < len(rest); idx += 1 {
		if rest[idx] == '"' && rest[idx - 1] != '\\' {
			return rest[start:idx]
		}
	}
	return ""
}

mcp_bridge_extract_number_field :: proc(line, field: string) -> (f32, bool) {
	key := fmt.tprintf("\"%s\"", field)
	i := strings.index(line, key)
	if i < 0 {
		return 0, false
	}
	rest := line[i + len(key):]
	colon := strings.index(rest, ":")
	if colon < 0 {
		return 0, false
	}
	rest = strings.trim_space(rest[colon + 1:])
	end := 0
	for idx := 0; idx < len(rest); idx += 1 {
		ch := rest[idx]
		switch ch {
		case '0'..='9', '-', '+', '.', 'e', 'E':
			end = idx + 1
		case:
			if end > 0 {
				return strconv.parse_f32(rest[:end])
			}
			return 0, false
		}
	}
	if end <= 0 {
		return 0, false
	}
	return strconv.parse_f32(rest[:end])
}

mcp_bridge_json_escape :: proc(text: string) -> string {
	builder: strings.Builder
	strings.builder_init(&builder, context.temp_allocator)
	for ch in text {
		switch ch {
		case '"':
			strings.write_string(&builder, "\\\"")
		case '\\':
			strings.write_string(&builder, "\\\\")
		case '\n':
			strings.write_string(&builder, "\\n")
		case '\r':
			strings.write_string(&builder, "\\r")
		case '\t':
			strings.write_string(&builder, "\\t")
		case:
			strings.write_rune(&builder, ch)
		}
	}
	return strings.to_string(builder)
}
