package app

import uifw "../ui"
import engine "../engine"
import rendervk "../render_vk"

import "core:c"
import base64 "core:encoding/base64"
import "core:fmt"
import "core:os"
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
	Apply_Builtin_Preset,
	Set_Color_Scheme,
	Configure_Particle_Life,
	Configure_Flow_Field,
	Configure_Gray_Scott,
	Configure_Remaining_Sim,
	Hide_Ui,
	Seed_Noise_Gray_Scott,
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
	preset_index: int,
	color_scheme_name: Color_Scheme_Name,
	color_scheme_reversed: bool,
	color_scheme_reversed_set: bool,
	particle_life_settings: Particle_Life_Settings,
	particle_life_randomize_forces: bool,
	particle_life_reset: bool,
	particle_life_hide_ui: bool,
	particle_life_set_mode: bool,
	flow_settings: Flow_Settings,
	flow_reset: bool,
	flow_hide_ui: bool,
	flow_set_mode: bool,
	gray_scott_settings: Gray_Scott_Settings,
	gray_scott_reset: bool,
	gray_scott_seed_noise: bool,
	gray_scott_hide_ui: bool,
	gray_scott_set_mode: bool,
	remaining_kind: Remaining_Sim_Kind,
	remaining_reset: bool,
	remaining_hide_ui: bool,
	remaining_set_mode: bool,
	moire_settings: Moire_Settings,
	vectors_settings: Vectors_Settings,
	primordial_settings: Primordial_Settings,
	voronoi_settings: Voronoi_Settings,
	pellets_settings: Pellets_Settings,
	slime_settings: Slime_Settings,
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
		return fmt.tprintf("{{\"jsonrpc\":\"2.0\",\"id\":%s,\"result\":{{\"tools\":%s}}}}", id, mcp_bridge_compact_json_literal(MCP_TOOLS_JSON))
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
{"name":"list_modes","description":"List app modes known to the MCP bridge.","inputSchema":{"type":"object","properties":{}}},
{"name":"list_builtin_presets","description":"List built-in preset names for an app mode.","inputSchema":{"type":"object","required":["mode"],"properties":{"mode":{"type":"string"}}}},
{"name":"list_color_schemes","description":"List available LUT color scheme names.","inputSchema":{"type":"object","properties":{}}},
{"name":"click","description":"Inject a window-relative click through the app input path.","inputSchema":{"type":"object","required":["x","y"],"properties":{"x":{"type":"number"},"y":{"type":"number"}}}},
{"name":"mouse_down","description":"Press and hold a mouse button at a window-relative position.","inputSchema":{"type":"object","required":["x","y"],"properties":{"x":{"type":"number"},"y":{"type":"number"},"button":{"type":"number","description":"SDL-style button: 1 left, 2 middle, 3 right. Defaults to 1."}}}},
{"name":"mouse_up","description":"Release a mouse button at a window-relative position.","inputSchema":{"type":"object","required":["x","y"],"properties":{"x":{"type":"number"},"y":{"type":"number"},"button":{"type":"number","description":"SDL-style button: 1 left, 2 middle, 3 right. Defaults to 1."}}}},
{"name":"move","description":"Move the app's logical mouse position.","inputSchema":{"type":"object","required":["x","y"],"properties":{"x":{"type":"number"},"y":{"type":"number"}}}},
{"name":"wheel","description":"Inject mouse wheel delta.","inputSchema":{"type":"object","required":["delta"],"properties":{"delta":{"type":"number"}}}},
{"name":"set_mode","description":"Navigate directly to an app mode by status name, e.g. Slime_Mold, Flow_Field, Pellets, Voronoi, Moire, Vectors, Primordial, Main_Menu.","inputSchema":{"type":"object","required":["mode"],"properties":{"mode":{"type":"string"}}}},
{"name":"apply_builtin_preset","description":"Apply a built-in preset by app mode and zero-based preset index.","inputSchema":{"type":"object","required":["mode","index"],"properties":{"mode":{"type":"string"},"index":{"type":"number"}}}},
{"name":"set_color_scheme","description":"Set the color scheme for a simulation mode. The scheme name should match an available LUT without the .lut suffix.","inputSchema":{"type":"object","required":["mode","color_scheme"],"properties":{"mode":{"type":"string"},"color_scheme":{"type":"string"},"name":{"type":"string","description":"Alias for color_scheme."},"reversed":{"type":"boolean"}}}},
{"name":"configure_simulation","description":"Apply a flat capture/configuration blob to any simulation mode except Gradient_Editor. Requires mode. Starts from that simulation's defaults, applies supplied numeric/string/boolean fields, and supports reset, hide_ui, and set_mode.","inputSchema":{"type":"object","required":["mode"],"properties":{"mode":{"type":"string"},"reset":{"type":"boolean","description":"Defaults true."},"hide_ui":{"type":"boolean","description":"Defaults false."},"set_mode":{"type":"boolean","description":"Defaults true."}}}},
{"name":"configure_gray_scott","description":"Apply a Gray-Scott capture/configuration blob. Supports feed, kill, diffusion_a, diffusion_b, timestep, simulation_speed, mask settings, cursor settings, color_scheme, reversed, seed_noise, reset, hide_ui, and set_mode.","inputSchema":{"type":"object","properties":{}}},
{"name":"configure_particle_life","description":"Apply a Particle Life capture/configuration blob. Supports species_count, particle_count, position_generator, type_generator, force_generator, force_random_min, force_random_max, randomize_forces, reset, hide_ui, and set_mode. Generators may be numeric indexes or names such as Center and Random.","inputSchema":{"type":"object","properties":{"species_count":{"type":"number","description":"Clamped to 1-8."},"particle_count":{"type":"number"},"position_generator":{"oneOf":[{"type":"string"},{"type":"number"}]},"type_generator":{"oneOf":[{"type":"string"},{"type":"number"}]},"force_generator":{"oneOf":[{"type":"string"},{"type":"number"}]},"force_random_min":{"type":"number"},"force_random_max":{"type":"number"},"randomize_forces":{"type":"boolean","description":"Defaults true when force fields are provided."},"reset":{"type":"boolean","description":"Defaults true."},"hide_ui":{"type":"boolean","description":"Defaults false."},"set_mode":{"type":"boolean","description":"Defaults true."}}}},
{"name":"configure_flow_field","description":"Apply a Flow Field capture/configuration blob. Supports noise_kind, fractal_mode, warp_mode, seed, frequency, amplitude, noise_strength, vector_magnitude, particle_count, particle_lifetime, particle_speed, particle_size, autospawn_rate, show_particles, trail_decay_rate, trail_deposition_rate, trail_diffusion_rate, trail_wash_out_rate, foreground_color_mode, background_color_mode, color_scheme, reversed, reset, hide_ui, and set_mode.","inputSchema":{"type":"object","properties":{"noise_kind":{"oneOf":[{"type":"string"},{"type":"number"}]},"fractal_mode":{"oneOf":[{"type":"string"},{"type":"number"}]},"warp_mode":{"oneOf":[{"type":"string"},{"type":"number"}]},"seed":{"type":"number"},"frequency":{"type":"number"},"amplitude":{"type":"number"},"noise_strength":{"type":"number"},"warp_amplitude":{"type":"number"},"warp_frequency":{"type":"number"},"vector_magnitude":{"type":"number"},"particle_count":{"type":"number"},"particle_lifetime":{"type":"number"},"particle_speed":{"type":"number"},"particle_size":{"type":"number"},"autospawn_rate":{"type":"number"},"show_particles":{"type":"boolean"},"trail_decay_rate":{"type":"number"},"trail_deposition_rate":{"type":"number"},"trail_diffusion_rate":{"type":"number"},"trail_wash_out_rate":{"type":"number"},"foreground_color_mode":{"oneOf":[{"type":"string"},{"type":"number"}]},"background_color_mode":{"oneOf":[{"type":"string"},{"type":"number"}]},"color_scheme":{"type":"string"},"reversed":{"type":"boolean"},"reset":{"type":"boolean","description":"Defaults true."},"hide_ui":{"type":"boolean","description":"Defaults false."},"set_mode":{"type":"boolean","description":"Defaults true."}}}},
{"name":"configure_slime_mold","description":"Apply a Slime Mold capture/configuration blob. Supports all common capture flags plus key Slime fields such as agent speeds, sensing, pheromone rates, random_seed, position_generator, mask, background, trail filtering, image paths, color_scheme, and reversed.","inputSchema":{"type":"object","properties":{}}},
{"name":"configure_pellets","description":"Apply a Pellets capture/configuration blob.","inputSchema":{"type":"object","properties":{}}},
{"name":"configure_voronoi","description":"Apply a Voronoi CA capture/configuration blob.","inputSchema":{"type":"object","properties":{}}},
{"name":"configure_moire","description":"Apply a Moire capture/configuration blob.","inputSchema":{"type":"object","properties":{}}},
{"name":"configure_vectors","description":"Apply a Vectors capture/configuration blob.","inputSchema":{"type":"object","properties":{}}},
{"name":"configure_primordial","description":"Apply a Primordial Particles capture/configuration blob.","inputSchema":{"type":"object","properties":{}}},
{"name":"hide_ui","description":"Hide all simulation UI chrome before screenshot or video capture.","inputSchema":{"type":"object","properties":{}}},
{"name":"seed_noise_gray_scott","description":"Seed the Gray-Scott simulation field with noise before warmup/capture.","inputSchema":{"type":"object","properties":{}}},
{"name":"load_vectors_image","description":"Load an image path into the Vectors image-field mode.","inputSchema":{"type":"object","required":["path"],"properties":{"path":{"type":"string"}}}},
{"name":"load_moire_image","description":"Load an image path into Moire image mode.","inputSchema":{"type":"object","required":["path"],"properties":{"path":{"type":"string"}}}},
{"name":"load_flow_image","description":"Load an image path into Flow vector-field image mode.","inputSchema":{"type":"object","required":["path"],"properties":{"path":{"type":"string"}}}},
{"name":"load_slime_mask_image","description":"Load an image path into Slime Mold mask-image mode.","inputSchema":{"type":"object","required":["path"],"properties":{"path":{"type":"string"}}}},
{"name":"load_slime_position_image","description":"Load an image path into Slime Mold image-based position generation.","inputSchema":{"type":"object","required":["path"],"properties":{"path":{"type":"string"}}}},
{"name":"close_app","description":"Ask the running app to close.","inputSchema":{"type":"object","properties":{}}},
{"name":"screenshot","description":"Return the latest engine-rendered frame as QOI. With output_path, write the QOI file directly and return metadata only. Without output_path, return a base64 QOI data URL. Use scale, max_width, or max_height to reduce payload size, or output_width/output_height for exact output dimensions.","inputSchema":{"type":"object","properties":{"scale":{"type":"number","description":"Optional 0-1 downscale factor before encoding."},"max_width":{"type":"number","description":"Optional maximum output width."},"max_height":{"type":"number","description":"Optional maximum output height."},"output_width":{"type":"number","description":"Optional exact output width."},"output_height":{"type":"number","description":"Optional exact output height."},"output_path":{"type":"string","description":"Optional filesystem path for writing the QOI screenshot."},"path":{"type":"string","description":"Alias for output_path."}}}}
]`

mcp_bridge_compact_json_literal :: proc(text: string) -> string {
	builder: strings.Builder
	strings.builder_init(&builder, context.temp_allocator)
	for ch in text {
		switch ch {
		case '\n', '\r', '\t':
		case:
			strings.write_rune(&builder, ch)
		}
	}
	return strings.to_string(builder)
}

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
	case "list_modes":
		return mcp_bridge_tool_text(id, mcp_bridge_list_modes_json())
	case "list_builtin_presets":
		mode_name := mcp_bridge_extract_string_field(line, "mode")
		mode: App_Mode
		if !mcp_bridge_app_mode_from_name(mode_name, &mode) {
			return mcp_bridge_error(id, -32602, "list_builtin_presets requires a known app mode")
		}
		return mcp_bridge_tool_text(id, mcp_bridge_list_builtin_presets_json(mode))
	case "list_color_schemes":
		return mcp_bridge_tool_text(id, mcp_bridge_list_color_schemes_json())
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
	case "apply_builtin_preset":
		mode_name := mcp_bridge_extract_string_field(line, "mode")
		mode: App_Mode
		if !mcp_bridge_app_mode_from_name(mode_name, &mode) {
			return mcp_bridge_error(id, -32602, "apply_builtin_preset requires a known app mode")
		}
		index, index_ok := mcp_bridge_extract_number_field(line, "index")
		if !index_ok {
			return mcp_bridge_error(id, -32602, "apply_builtin_preset requires numeric index")
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Apply_Builtin_Preset, mode = mode, preset_index = int(index)}) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"apply_builtin_preset\"}")
	case "set_color_scheme":
		mode_name := mcp_bridge_extract_string_field(line, "mode")
		mode: App_Mode
		if !mcp_bridge_app_mode_from_name(mode_name, &mode) {
			return mcp_bridge_error(id, -32602, "set_color_scheme requires a known app mode")
		}
		name := mcp_bridge_extract_argument_string_field(line, "color_scheme")
		if len(name) == 0 {
			name = mcp_bridge_extract_argument_string_field(line, "name")
		}
		if len(name) == 0 {
			return mcp_bridge_error(id, -32602, "set_color_scheme requires color_scheme")
		}
		cmd := Mcp_Command{kind = .Set_Color_Scheme, mode = mode}
		write_fixed_string(cmd.color_scheme_name[:], name)
		if value, ok := mcp_bridge_extract_bool_field(line, "reversed"); ok {
			cmd.color_scheme_reversed = value
			cmd.color_scheme_reversed_set = true
		}
		if !mcp_bridge_enqueue_command(bridge, cmd) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"set_color_scheme\"}")
	case "configure_particle_life":
		return mcp_bridge_configure_particle_life(id, bridge, line)
	case "configure_flow_field":
		return mcp_bridge_configure_flow_field(id, bridge, line)
	case "configure_gray_scott":
		return mcp_bridge_configure_gray_scott(id, bridge, line)
	case "configure_simulation", "configure_slime_mold", "configure_pellets", "configure_voronoi", "configure_voronoi_ca", "configure_moire", "configure_vectors", "configure_primordial":
		return mcp_bridge_configure_simulation(id, bridge, name, line)
	case "hide_ui":
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Hide_Ui}) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"hide_ui\"}")
	case "seed_noise_gray_scott":
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Seed_Noise_Gray_Scott}) {
			return mcp_bridge_queue_error(id, bridge)
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"seed_noise_gray_scott\"}")
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

mcp_bridge_json_string_array :: proc(items: []string) -> string {
	builder: strings.Builder
	strings.builder_init(&builder, context.temp_allocator)
	strings.write_string(&builder, "[")
	for item, i in items {
		if i > 0 {
			strings.write_string(&builder, ",")
		}
		strings.write_string(&builder, "\"")
		strings.write_string(&builder, mcp_bridge_json_escape(item))
		strings.write_string(&builder, "\"")
	}
	strings.write_string(&builder, "]")
	return strings.to_string(builder)
}

mcp_bridge_list_modes_json :: proc() -> string {
	modes := [?]string {
		"Main_Menu",
		"Slime_Mold",
		"Gray_Scott",
		"Particle_Life",
		"Flow_Field",
		"Pellets",
		"Gradient_Editor",
		"Voronoi_CA",
		"Moire",
		"Vectors",
		"Primordial",
		"Options",
		"How_To_Play",
		"Theme_Preview",
	}
	simulations := [?]string {
		"Slime_Mold",
		"Gray_Scott",
		"Particle_Life",
		"Flow_Field",
		"Pellets",
		"Gradient_Editor",
		"Voronoi_CA",
		"Moire",
		"Vectors",
		"Primordial",
	}
	return fmt.tprintf(
		"{{\"ok\":true,\"modes\":%s,\"simulations\":%s}}",
		mcp_bridge_json_string_array(modes[:]),
		mcp_bridge_json_string_array(simulations[:]),
	)
}

mcp_bridge_list_builtin_presets_json :: proc(mode: App_Mode) -> string {
	names: []string
	#partial switch mode {
	case .Gray_Scott:
		names = GRAY_SCOTT_BUILTIN_PRESET_NAMES[:]
	case .Particle_Life:
		names = PARTICLE_LIFE_BUILTIN_PRESET_NAMES[:]
	case .Slime_Mold:
		names = SLIME_BUILTIN_PRESET_NAMES[:]
	case .Flow_Field, .Pellets, .Voronoi_CA, .Vectors, .Primordial:
		names = REMAINING_DEFAULT_BUILTIN_PRESET_NAMES[:]
	case .Moire:
		names = MOIRE_BUILTIN_PRESET_NAMES[:]
	case:
		return fmt.tprintf("{{\"ok\":true,\"mode\":\"%v\",\"count\":0,\"presets\":[]}}", mode)
	}
	return fmt.tprintf(
		"{{\"ok\":true,\"mode\":\"%v\",\"count\":%d,\"presets\":%s}}",
		mode,
		len(names),
		mcp_bridge_json_string_array(names),
	)
}

mcp_bridge_list_color_schemes_json :: proc() -> string {
	names := color_scheme_available_names_cached()
	return fmt.tprintf(
		"{{\"ok\":true,\"count\":%d,\"color_schemes\":%s}}",
		len(names),
		mcp_bridge_json_string_array(names),
	)
}

mcp_bridge_configure_particle_life :: proc(id: string, bridge: ^Mcp_Bridge, line: string) -> string {
	settings := particle_life_default_settings()

	if value, ok := mcp_bridge_extract_number_field(line, "particle_count"); ok {
		settings.particle_count = u32(max(min(value, f32(PARTICLE_LIFE_MAX_PARTICLE_COUNT)), 1))
	}
	if value, ok := mcp_bridge_extract_number_field(line, "species_count"); ok {
		settings.species_count = u32(max(min(value, f32(PARTICLE_LIFE_MAX_SPECIES)), 1))
	}
	if value, ok := mcp_bridge_extract_number_field(line, "position_generator"); ok {
		settings.position_generator = u32(max(min(value, f32(len(PARTICLE_LIFE_POSITION_GENERATOR_NAMES) - 1)), 0))
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "position_generator")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, PARTICLE_LIFE_POSITION_GENERATOR_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Particle Life position_generator")
			}
			settings.position_generator = index
		}
	}
	if value, ok := mcp_bridge_extract_number_field(line, "type_generator"); ok {
		settings.type_generator = u32(max(min(value, f32(len(PARTICLE_LIFE_TYPE_GENERATOR_NAMES) - 1)), 0))
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "type_generator")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, PARTICLE_LIFE_TYPE_GENERATOR_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Particle Life type_generator")
			}
			settings.type_generator = index
		}
	}
	if value, ok := mcp_bridge_extract_number_field(line, "force_generator"); ok {
		settings.force_generator = u32(max(min(value, f32(len(PARTICLE_LIFE_FORCE_GENERATOR_NAMES) - 1)), 0))
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "force_generator")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, PARTICLE_LIFE_FORCE_GENERATOR_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Particle Life force_generator")
			}
			settings.force_generator = index
		}
	}
	force_fields_set := false
	if value, ok := mcp_bridge_extract_number_field(line, "force_random_min"); ok {
		settings.force_random_min = max(min(value, 1.5), -1.5)
		force_fields_set = true
	}
	if value, ok := mcp_bridge_extract_number_field(line, "force_random_max"); ok {
		settings.force_random_max = max(min(value, 1.5), -1.5)
		force_fields_set = true
	}
	if settings.force_random_min > settings.force_random_max {
		settings.force_random_min, settings.force_random_max = settings.force_random_max, settings.force_random_min
	}

	randomize := force_fields_set
	if value, ok := mcp_bridge_extract_bool_field(line, "randomize_forces"); ok {
		randomize = value
	}
	reset := true
	if value, ok := mcp_bridge_extract_bool_field(line, "reset"); ok {
		reset = value
	}
	hide_ui := false
	if value, ok := mcp_bridge_extract_bool_field(line, "hide_ui"); ok {
		hide_ui = value
	}
	set_mode := true
	if value, ok := mcp_bridge_extract_bool_field(line, "set_mode"); ok {
		set_mode = value
	}

	cmd := Mcp_Command {
		kind = .Configure_Particle_Life,
		particle_life_settings = settings,
		particle_life_randomize_forces = randomize,
		particle_life_reset = reset,
		particle_life_hide_ui = hide_ui,
		particle_life_set_mode = set_mode,
	}
	if !mcp_bridge_enqueue_command(bridge, cmd) {
		return mcp_bridge_queue_error(id, bridge)
	}
	return mcp_bridge_tool_text(
		id,
		fmt.tprintf(
			"{{\"ok\":true,\"queued\":\"configure_particle_life\",\"settings\":{{\"particle_count\":%d,\"species_count\":%d,\"position_generator\":%d,\"type_generator\":%d,\"force_generator\":%d,\"force_random_min\":%.4f,\"force_random_max\":%.4f,\"randomize_forces\":%v,\"reset\":%v,\"hide_ui\":%v,\"set_mode\":%v}}}}",
			settings.particle_count,
			settings.species_count,
			settings.position_generator,
			settings.type_generator,
			settings.force_generator,
			settings.force_random_min,
			settings.force_random_max,
			randomize,
			reset,
			hide_ui,
			set_mode,
		),
	)
}

mcp_bridge_configure_flow_field :: proc(id: string, bridge: ^Mcp_Bridge, line: string) -> string {
	settings := flow_settings_default()

	if value, ok := mcp_bridge_extract_number_field(line, "vector_field_type"); ok {
		settings.vector_field_index = int(max(min(value, f32(len(VECTOR_FIELD_TYPE_NAMES) - 1)), 0))
		settings.vector_field_type = Vector_Field_Type(settings.vector_field_index)
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "vector_field_type")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, VECTOR_FIELD_TYPE_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Flow vector_field_type")
			}
			settings.vector_field_index = int(index)
			settings.vector_field_type = Vector_Field_Type(index)
		}
	}
	if value, ok := mcp_bridge_extract_number_field(line, "noise_kind"); ok {
		settings.noise.kind_index = int(max(min(value, f32(len(NOISE_KIND_NAMES) - 1)), 0))
		settings.noise.kind = Noise_Kind(settings.noise.kind_index)
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "noise_kind")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, NOISE_KIND_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Flow noise_kind")
			}
			settings.noise.kind_index = int(index)
			settings.noise.kind = Noise_Kind(index)
		}
	}
	if value, ok := mcp_bridge_extract_number_field(line, "fractal_mode"); ok {
		settings.noise.fractal_mode_index = int(max(min(value, f32(len(NOISE_FRACTAL_MODE_NAMES) - 1)), 0))
		settings.noise.fractal_mode = Noise_Fractal_Mode(settings.noise.fractal_mode_index)
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "fractal_mode")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, NOISE_FRACTAL_MODE_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Flow fractal_mode")
			}
			settings.noise.fractal_mode_index = int(index)
			settings.noise.fractal_mode = Noise_Fractal_Mode(index)
		}
	}
	if value, ok := mcp_bridge_extract_number_field(line, "warp_mode"); ok {
		settings.noise.warp_mode_index = int(max(min(value, f32(len(NOISE_WARP_MODE_NAMES) - 1)), 0))
		settings.noise.warp_mode = Noise_Warp_Mode(settings.noise.warp_mode_index)
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "warp_mode")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, NOISE_WARP_MODE_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Flow warp_mode")
			}
			settings.noise.warp_mode_index = int(index)
			settings.noise.warp_mode = Noise_Warp_Mode(index)
		}
	}
	if value, ok := mcp_bridge_extract_number_field(line, "seed"); ok {
		settings.noise.seed = u32(max(value, 0))
	}
	if value, ok := mcp_bridge_extract_number_field(line, "frequency"); ok {
		settings.noise.frequency = max(value, 0.000001)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "amplitude"); ok {
		settings.noise.amplitude = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "noise_strength"); ok {
		settings.noise.noise_strength = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "warp_amplitude"); ok {
		settings.noise.warp_amplitude = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "warp_frequency"); ok {
		settings.noise.warp_frequency = max(value, 0.000001)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "vector_magnitude"); ok {
		settings.vector_magnitude = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "particle_count"); ok {
		settings.total_pool_size = u32(max(min(value, 1000000), 1))
	}
	if value, ok := mcp_bridge_extract_number_field(line, "particle_lifetime"); ok {
		settings.particle_lifetime = max(value, 0.1)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "particle_speed"); ok {
		settings.particle_speed = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "particle_size"); ok {
		settings.particle_size = u32(max(min(value, 64), 1))
	}
	if value, ok := mcp_bridge_extract_number_field(line, "autospawn_rate"); ok {
		settings.autospawn_rate = u32(max(min(value, 100000), 0))
	}
	if value, ok := mcp_bridge_extract_bool_field(line, "show_particles"); ok {
		settings.show_particles = value
	}
	if value, ok := mcp_bridge_extract_number_field(line, "trail_decay_rate"); ok {
		settings.trail_decay_rate = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "trail_deposition_rate"); ok {
		settings.trail_deposition_rate = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "trail_diffusion_rate"); ok {
		settings.trail_diffusion_rate = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "trail_wash_out_rate"); ok {
		settings.trail_wash_out_rate = max(value, 0)
	}
	if value, ok := mcp_bridge_extract_number_field(line, "foreground_color_mode"); ok {
		settings.foreground_index = int(max(min(value, f32(len(FLOW_FOREGROUND_MODE_NAMES) - 1)), 0))
		settings.foreground_color_mode = Flow_Foreground_Mode(settings.foreground_index)
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "foreground_color_mode")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, FLOW_FOREGROUND_MODE_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Flow foreground_color_mode")
			}
			settings.foreground_index = int(index)
			settings.foreground_color_mode = Flow_Foreground_Mode(index)
		}
	}
	if value, ok := mcp_bridge_extract_number_field(line, "background_color_mode"); ok {
		settings.background_index = int(max(min(value, f32(len(VECTOR_BACKGROUND_MODE_NAMES) - 1)), 0))
		settings.background_color_mode = Vector_Background_Mode(settings.background_index)
	} else {
		name := mcp_bridge_extract_argument_string_field(line, "background_color_mode")
		if len(name) > 0 {
			index: u32
			if !mcp_bridge_named_index(name, VECTOR_BACKGROUND_MODE_NAMES[:], &index) {
				return mcp_bridge_error(id, -32602, "unknown Flow background_color_mode")
			}
			settings.background_index = int(index)
			settings.background_color_mode = Vector_Background_Mode(index)
		}
	}
	if name := mcp_bridge_extract_argument_string_field(line, "color_scheme"); len(name) > 0 {
		color_scheme_name_set(&settings.color_scheme, name)
	}
	if value, ok := mcp_bridge_extract_bool_field(line, "reversed"); ok {
		settings.color_scheme_reversed = value
	}
	noise_sync_indices(&settings.noise)

	reset := true
	if value, ok := mcp_bridge_extract_bool_field(line, "reset"); ok {
		reset = value
	}
	hide_ui := false
	if value, ok := mcp_bridge_extract_bool_field(line, "hide_ui"); ok {
		hide_ui = value
	}
	set_mode := true
	if value, ok := mcp_bridge_extract_bool_field(line, "set_mode"); ok {
		set_mode = value
	}

	cmd := Mcp_Command {
		kind = .Configure_Flow_Field,
		flow_settings = settings,
		flow_reset = reset,
		flow_hide_ui = hide_ui,
		flow_set_mode = set_mode,
	}
	if !mcp_bridge_enqueue_command(bridge, cmd) {
		return mcp_bridge_queue_error(id, bridge)
	}
	color_scheme := settings.color_scheme
	return mcp_bridge_tool_text(
		id,
		fmt.tprintf(
			"{{\"ok\":true,\"queued\":\"configure_flow_field\",\"settings\":{{\"noise_kind\":\"%s\",\"fractal_mode\":\"%s\",\"warp_mode\":\"%s\",\"seed\":%d,\"frequency\":%.4f,\"vector_magnitude\":%.4f,\"particle_count\":%d,\"particle_speed\":%.4f,\"particle_size\":%d,\"autospawn_rate\":%d,\"trail_decay_rate\":%.4f,\"trail_deposition_rate\":%.4f,\"trail_diffusion_rate\":%.4f,\"trail_wash_out_rate\":%.4f,\"color_scheme\":\"%s\",\"reversed\":%v,\"reset\":%v,\"hide_ui\":%v,\"set_mode\":%v}}}}",
			NOISE_KIND_NAMES[settings.noise.kind_index],
			NOISE_FRACTAL_MODE_NAMES[settings.noise.fractal_mode_index],
			NOISE_WARP_MODE_NAMES[settings.noise.warp_mode_index],
			settings.noise.seed,
			settings.noise.frequency,
			settings.vector_magnitude,
			settings.total_pool_size,
			settings.particle_speed,
			settings.particle_size,
			settings.autospawn_rate,
			settings.trail_decay_rate,
			settings.trail_deposition_rate,
			settings.trail_diffusion_rate,
			settings.trail_wash_out_rate,
			color_scheme_name_get(&color_scheme),
			settings.color_scheme_reversed,
			reset,
			hide_ui,
			set_mode,
		),
	)
}

mcp_bridge_configure_gray_scott :: proc(id: string, bridge: ^Mcp_Bridge, line: string) -> string {
	settings := gray_scott_default_settings()

	if value, ok := mcp_bridge_extract_number_field(line, "feed"); ok {settings.feed = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "kill"); ok {settings.kill = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "diffusion_a"); ok {settings.diffusion_a = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "diffusion_b"); ok {settings.diffusion_b = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "timestep"); ok {settings.timestep = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "simulation_speed"); ok {settings.simulation_speed = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "max_timestep"); ok {settings.max_timestep = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "stability_factor"); ok {settings.stability_factor = max(value, 0)}
	if value, ok := mcp_bridge_extract_bool_field(line, "enable_adaptive_timestep"); ok {settings.enable_adaptive_timestep = value}
	if value, ok := mcp_bridge_extract_number_field(line, "cursor_size"); ok {settings.cursor_size = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "cursor_strength"); ok {settings.cursor_strength = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "mask_strength"); ok {settings.mask_strength = max(value, 0)}
	if value, ok := mcp_bridge_extract_bool_field(line, "mask_mirror_horizontal"); ok {settings.mask_mirror_horizontal = value}
	if value, ok := mcp_bridge_extract_bool_field(line, "mask_mirror_vertical"); ok {settings.mask_mirror_vertical = value}
	if value, ok := mcp_bridge_extract_bool_field(line, "mask_invert_tone"); ok {settings.mask_invert_tone = value}
	if value, ok := mcp_bridge_extract_bool_field(line, "blur_enabled"); ok {settings.blur_enabled = value}
	if value, ok := mcp_bridge_extract_number_field(line, "blur_radius"); ok {settings.blur_radius = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "blur_sigma"); ok {settings.blur_sigma = max(value, 0)}
	if value, ok := mcp_bridge_extract_bool_field(line, "paused"); ok {settings.paused = value}
	if value, ok := mcp_bridge_extract_number_field(line, "mask_pattern"); ok {
		settings.mask_pattern = Gray_Scott_Mask_Pattern(u32(max(min(value, f32(len(GRAY_SCOTT_MASK_PATTERN_NAMES) - 1)), 0)))
	} else if name := mcp_bridge_extract_argument_string_field(line, "mask_pattern"); len(name) > 0 {
		pattern: Gray_Scott_Mask_Pattern
		if !gray_scott_mask_pattern_from_name(name, &pattern) {
			return mcp_bridge_error(id, -32602, "unknown Gray-Scott mask_pattern")
		}
		settings.mask_pattern = pattern
	}
	if value, ok := mcp_bridge_extract_number_field(line, "mask_target"); ok {
		settings.mask_target = gray_scott_mask_target_from_index(int(value))
	} else if name := mcp_bridge_extract_argument_string_field(line, "mask_target"); len(name) > 0 {
		index: u32
		if !mcp_bridge_named_index(name, GRAY_SCOTT_MASK_TARGET_NAMES[:], &index) {
			return mcp_bridge_error(id, -32602, "unknown Gray-Scott mask_target")
		}
		settings.mask_target = gray_scott_mask_target_from_index(int(index))
	}
	if value, ok := mcp_bridge_extract_number_field(line, "nutrient_image_fit_mode"); ok {
		settings.nutrient_image_fit_mode = Gray_Scott_Image_Fit_Mode(u32(max(min(value, f32(len(GRAY_SCOTT_IMAGE_FIT_MODE_NAMES) - 1)), 0)))
	} else if name := mcp_bridge_extract_argument_string_field(line, "nutrient_image_fit_mode"); len(name) > 0 {
		fit: Gray_Scott_Image_Fit_Mode
		if !gray_scott_image_fit_mode_from_name(name, &fit) {
			return mcp_bridge_error(id, -32602, "unknown Gray-Scott nutrient_image_fit_mode")
		}
		settings.nutrient_image_fit_mode = fit
	}
	if path := mcp_bridge_extract_argument_string_field(line, "nutrient_image_path"); len(path) > 0 {
		write_fixed_string(settings.nutrient_image_path[:], path)
		settings.mask_pattern = .Nutrient_Map
	}
	mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)

	reset, hide_ui, set_mode := mcp_bridge_capture_flags(line)
	seed_noise := false
	if value, ok := mcp_bridge_extract_bool_field(line, "seed_noise"); ok {seed_noise = value}
	cmd := Mcp_Command {
		kind = .Configure_Gray_Scott,
		gray_scott_settings = settings,
		gray_scott_reset = reset,
		gray_scott_seed_noise = seed_noise,
		gray_scott_hide_ui = hide_ui,
		gray_scott_set_mode = set_mode,
	}
	if !mcp_bridge_enqueue_command(bridge, cmd) {
		return mcp_bridge_queue_error(id, bridge)
	}
	return mcp_bridge_tool_text(id, fmt.tprintf("{{\"ok\":true,\"queued\":\"configure_gray_scott\",\"settings\":{{\"feed\":%.6f,\"kill\":%.6f,\"reset\":%v,\"seed_noise\":%v,\"hide_ui\":%v,\"set_mode\":%v}}}}", settings.feed, settings.kill, reset, seed_noise, hide_ui, set_mode))
}

mcp_bridge_configure_simulation :: proc(id: string, bridge: ^Mcp_Bridge, tool_name, line: string) -> string {
	mode_name := mcp_bridge_extract_string_field(line, "mode")
	if len(mode_name) == 0 {
		mode_name = mcp_bridge_mode_name_from_configure_tool(tool_name)
	}
	mode: App_Mode
	if !mcp_bridge_app_mode_from_name(mode_name, &mode) {
		return mcp_bridge_error(id, -32602, "configure_simulation requires a known non-gradient mode")
	}
	#partial switch mode {
	case .Gradient_Editor:
		return mcp_bridge_error(id, -32602, "Gradient_Editor does not support MCP config blobs")
	case .Gray_Scott:
		return mcp_bridge_configure_gray_scott(id, bridge, line)
	case .Particle_Life:
		return mcp_bridge_configure_particle_life(id, bridge, line)
	case .Flow_Field:
		return mcp_bridge_configure_flow_field(id, bridge, line)
	case:
		kind: Remaining_Sim_Kind
		if !mcp_bridge_remaining_kind_from_mode(mode, &kind) {
			return mcp_bridge_error(id, -32602, "configure_simulation requires a simulation mode")
		}
		return mcp_bridge_configure_remaining_sim(id, bridge, kind, line)
	}
}

mcp_bridge_configure_remaining_sim :: proc(id: string, bridge: ^Mcp_Bridge, kind: Remaining_Sim_Kind, line: string) -> string {
	reset, hide_ui, set_mode := mcp_bridge_capture_flags(line)
	cmd := Mcp_Command{kind = .Configure_Remaining_Sim, remaining_kind = kind, remaining_reset = reset, remaining_hide_ui = hide_ui, remaining_set_mode = set_mode}
	switch kind {
	case .Flow_Field:
		return mcp_bridge_configure_flow_field(id, bridge, line)
	case .Pellets:
		settings := pellets_settings_default()
		mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)
		if value, ok := mcp_bridge_extract_number_field(line, "particle_count"); ok {settings.particle_count = u32(max(min(value, 1000000), 1))}
		if value, ok := mcp_bridge_extract_number_field(line, "particle_size"); ok {settings.particle_size = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "collision_damping"); ok {settings.collision_damping = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "initial_velocity_max"); ok {settings.initial_velocity_max = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "initial_velocity_min"); ok {settings.initial_velocity_min = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "random_seed"); ok {settings.random_seed = u32(max(value, 0))}
		if value, ok := mcp_bridge_extract_number_field(line, "gravitational_constant"); ok {settings.gravitational_constant = value}
		if value, ok := mcp_bridge_extract_number_field(line, "energy_damping"); ok {settings.energy_damping = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "gravity_softening"); ok {settings.gravity_softening = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "density_radius"); ok {settings.density_radius = max(value, 0)}
		if value, ok := mcp_bridge_extract_bool_field(line, "trails_enabled"); ok {settings.trails_enabled = value}
		if value, ok := mcp_bridge_extract_number_field(line, "trail_fade"); ok {settings.trail_fade = max(value, 0)}
		if value, ok := mcp_bridge_extract_bool_field(line, "density_damping_enabled"); ok {settings.density_damping_enabled = value}
		if value, ok := mcp_bridge_extract_number_field(line, "overlap_resolution_strength"); ok {settings.overlap_resolution_strength = max(value, 0)}
		mcp_bridge_apply_named_index(line, "background_color_mode", VECTOR_BACKGROUND_MODE_NAMES[:], &settings.background_index)
		settings.background_color_mode = Vector_Background_Mode(settings.background_index)
		mcp_bridge_apply_named_index(line, "foreground_color_mode", PELLETS_FOREGROUND_MODE_NAMES[:], &settings.foreground_index)
		settings.foreground_color_mode = Pellets_Foreground_Mode(settings.foreground_index)
		cmd.pellets_settings = settings
	case .Voronoi_CA:
		settings := voronoi_settings_default()
		mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)
		if value, ok := mcp_bridge_extract_number_field(line, "point_count"); ok {settings.point_count = u32(max(min(value, 1000000), 1))}
		if value, ok := mcp_bridge_extract_number_field(line, "time_scale"); ok {settings.time_scale = value}
		if value, ok := mcp_bridge_extract_number_field(line, "drift"); ok {settings.drift = value}
		if value, ok := mcp_bridge_extract_number_field(line, "brownian_speed"); ok {settings.brownian_speed = value}
		if value, ok := mcp_bridge_extract_number_field(line, "random_seed"); ok {settings.random_seed = u32(max(value, 0))}
		if value, ok := mcp_bridge_extract_bool_field(line, "borders_enabled"); ok {settings.borders_enabled = value}
		if value, ok := mcp_bridge_extract_number_field(line, "border_width"); ok {settings.border_width = max(value, 0)}
		mcp_bridge_apply_named_index(line, "color_mode", VORONOI_COLOR_MODE_NAMES[:], &settings.color_mode_index)
		settings.color_mode = u32(settings.color_mode_index)
		cmd.voronoi_settings = settings
	case .Moire:
		settings := moire_settings_default()
		mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)
		if value, ok := mcp_bridge_extract_number_field(line, "speed"); ok {settings.speed = value}
		if value, ok := mcp_bridge_extract_number_field(line, "base_freq"); ok {settings.base_freq = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "moire_amount"); ok {settings.moire_amount = value}
		if value, ok := mcp_bridge_extract_number_field(line, "moire_rotation"); ok {settings.moire_rotation = value}
		if value, ok := mcp_bridge_extract_number_field(line, "moire_scale"); ok {settings.moire_scale = value}
		if value, ok := mcp_bridge_extract_number_field(line, "moire_interference"); ok {settings.moire_interference = value}
		if value, ok := mcp_bridge_extract_number_field(line, "moire_rotation3"); ok {settings.moire_rotation3 = value}
		if value, ok := mcp_bridge_extract_number_field(line, "moire_scale3"); ok {settings.moire_scale3 = value}
		if value, ok := mcp_bridge_extract_number_field(line, "moire_weight3"); ok {settings.moire_weight3 = value}
		if value, ok := mcp_bridge_extract_number_field(line, "radial_swirl_strength"); ok {settings.radial_swirl_strength = value}
		if value, ok := mcp_bridge_extract_number_field(line, "radial_starburst_count"); ok {settings.radial_starburst_count = value}
		if value, ok := mcp_bridge_extract_number_field(line, "radial_center_brightness"); ok {settings.radial_center_brightness = value}
		if value, ok := mcp_bridge_extract_number_field(line, "advect_strength"); ok {settings.advect_strength = value}
		if value, ok := mcp_bridge_extract_number_field(line, "advect_speed"); ok {settings.advect_speed = value}
		if value, ok := mcp_bridge_extract_number_field(line, "curl"); ok {settings.curl = value}
		if value, ok := mcp_bridge_extract_number_field(line, "decay"); ok {settings.decay = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "image_mode_enabled"); ok {settings.image_mode_enabled = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "image_mirror_horizontal"); ok {settings.image_mirror_horizontal = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "image_mirror_vertical"); ok {settings.image_mirror_vertical = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "image_invert_tone"); ok {settings.image_invert_tone = value}
		if path := mcp_bridge_extract_argument_string_field(line, "image_path"); len(path) > 0 {write_fixed_string(settings.image_path[:], path); settings.image_mode_enabled = true}
		mcp_bridge_apply_named_index(line, "generator_type", MOIRE_GENERATOR_TYPE_NAMES[:], &settings.generator_index)
		settings.generator_type = Moire_Generator_Type(settings.generator_index)
		mcp_bridge_apply_named_index(line, "image_fit_mode", VECTOR_IMAGE_FIT_MODE_NAMES[:], &settings.image_fit_index)
		settings.image_fit_mode = Vector_Image_Fit_Mode(settings.image_fit_index)
		mcp_bridge_apply_named_index(line, "image_interference_mode", MOIRE_INTERFERENCE_MODE_NAMES[:], &settings.interference_index)
		settings.image_interference_mode = Moire_Image_Interference_Mode(settings.interference_index)
		cmd.moire_settings = settings
	case .Vectors:
		settings := vectors_settings_default()
		mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)
		mcp_bridge_apply_noise_fields(line, &settings.noise)
		if value, ok := mcp_bridge_extract_number_field(line, "density"); ok {settings.density = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "line_length"); ok {settings.line_length = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "line_width"); ok {settings.line_width = max(value, 0)}
		if value, ok := mcp_bridge_extract_bool_field(line, "image_mirror_horizontal"); ok {settings.image_mirror_horizontal = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "image_mirror_vertical"); ok {settings.image_mirror_vertical = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "image_invert_tone"); ok {settings.image_invert_tone = value}
		if path := mcp_bridge_extract_argument_string_field(line, "image_path"); len(path) > 0 {write_fixed_string(settings.image_path[:], path); settings.vector_field_type = .Image; settings.vector_field_index = int(Vector_Field_Type.Image)}
		mcp_bridge_apply_named_index(line, "vector_field_type", VECTOR_FIELD_TYPE_NAMES[:], &settings.vector_field_index)
		settings.vector_field_type = Vector_Field_Type(settings.vector_field_index)
		mcp_bridge_apply_named_index(line, "background_color_mode", VECTOR_BACKGROUND_MODE_NAMES[:], &settings.background_index)
		settings.background_color_mode = Vector_Background_Mode(settings.background_index)
		mcp_bridge_apply_named_index(line, "image_fit_mode", VECTOR_IMAGE_FIT_MODE_NAMES[:], &settings.image_fit_index)
		settings.image_fit_mode = Vector_Image_Fit_Mode(settings.image_fit_index)
		cmd.vectors_settings = settings
	case .Primordial:
		settings := primordial_settings_default()
		mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)
		if value, ok := mcp_bridge_extract_number_field(line, "particle_count"); ok {settings.particle_count = u32(max(min(value, 1000000), 1))}
		if value, ok := mcp_bridge_extract_number_field(line, "random_seed"); ok {settings.random_seed = u32(max(value, 0))}
		if value, ok := mcp_bridge_extract_number_field(line, "alpha"); ok {settings.alpha = value}
		if value, ok := mcp_bridge_extract_number_field(line, "beta"); ok {settings.beta = value}
		if value, ok := mcp_bridge_extract_number_field(line, "velocity"); ok {settings.velocity = value}
		if value, ok := mcp_bridge_extract_number_field(line, "radius"); ok {settings.radius = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "dt"); ok {settings.dt = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "particle_size"); ok {settings.particle_size = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "density_radius"); ok {settings.density_radius = max(value, 0)}
		if value, ok := mcp_bridge_extract_bool_field(line, "traces_enabled"); ok {settings.traces_enabled = value}
		if value, ok := mcp_bridge_extract_number_field(line, "trace_fade"); ok {settings.trace_fade = max(value, 0)}
		if value, ok := mcp_bridge_extract_bool_field(line, "wrap_edges"); ok {settings.wrap_edges = value}
		mcp_bridge_apply_named_index(line, "position_generator", PRIMORDIAL_POSITION_GENERATOR_NAMES[:], &settings.position_generator_index)
		settings.position_generator = u32(settings.position_generator_index)
		mcp_bridge_apply_named_index(line, "background_color_mode", VECTOR_BACKGROUND_MODE_NAMES[:], &settings.background_index)
		settings.background_color_mode = Vector_Background_Mode(settings.background_index)
		mcp_bridge_apply_named_index(line, "foreground_color_mode", PRIMORDIAL_FOREGROUND_MODE_NAMES[:], &settings.foreground_index)
		settings.foreground_color_mode = Primordial_Foreground_Mode(settings.foreground_index)
		cmd.primordial_settings = settings
	case .Slime_Mold:
		settings := slime_settings_default()
		mcp_bridge_apply_color_scheme_fields(line, &settings.color_scheme, &settings.color_scheme_reversed)
		if value, ok := mcp_bridge_extract_number_field(line, "agent_jitter"); ok {settings.agent_jitter = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "agent_heading_start"); ok {settings.agent_heading_start = value}
		if value, ok := mcp_bridge_extract_number_field(line, "agent_heading_end"); ok {settings.agent_heading_end = value}
		if value, ok := mcp_bridge_extract_number_field(line, "agent_sensor_angle"); ok {settings.agent_sensor_angle = value}
		if value, ok := mcp_bridge_extract_number_field(line, "agent_sensor_distance"); ok {settings.agent_sensor_distance = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "agent_speed_max"); ok {settings.agent_speed_max = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "agent_speed_min"); ok {settings.agent_speed_min = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "agent_turn_rate"); ok {settings.agent_turn_rate = value}
		if value, ok := mcp_bridge_extract_number_field(line, "pheromone_decay_rate"); ok {settings.pheromone_decay_rate = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "pheromone_deposition_rate"); ok {settings.pheromone_deposition_rate = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "pheromone_diffusion_rate"); ok {settings.pheromone_diffusion_rate = max(value, 0)}
		if value, ok := mcp_bridge_extract_number_field(line, "diffusion_frequency"); ok {settings.diffusion_frequency = u32(max(value, 1))}
		if value, ok := mcp_bridge_extract_number_field(line, "decay_frequency"); ok {settings.decay_frequency = u32(max(value, 1))}
		if value, ok := mcp_bridge_extract_number_field(line, "random_seed"); ok {settings.random_seed = u32(max(value, 0))}
		if value, ok := mcp_bridge_extract_number_field(line, "mask_strength"); ok {settings.mask_strength = value}
		if value, ok := mcp_bridge_extract_number_field(line, "mask_curve"); ok {settings.mask_curve = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "mask_mirror_horizontal"); ok {settings.mask_mirror_horizontal = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "mask_mirror_vertical"); ok {settings.mask_mirror_vertical = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "mask_invert_tone"); ok {settings.mask_invert_tone = value}
		if value, ok := mcp_bridge_extract_bool_field(line, "mask_reversed"); ok {settings.mask_reversed = value}
		if path := mcp_bridge_extract_argument_string_field(line, "mask_image_path"); len(path) > 0 {write_fixed_string(settings.mask_image_path[:], path); settings.mask_pattern = .Image; settings.mask_pattern_index = int(Slime_Mask_Pattern.Image)}
		if path := mcp_bridge_extract_argument_string_field(line, "position_image_path"); len(path) > 0 {write_fixed_string(settings.position_image_path[:], path); settings.position_generator = 7; settings.position_generator_index = 7}
		mcp_bridge_apply_named_index(line, "position_generator", SLIME_POSITION_GENERATOR_NAMES[:], &settings.position_generator_index)
		settings.position_generator = u32(settings.position_generator_index)
		mcp_bridge_apply_named_index(line, "mask_pattern", SLIME_MASK_PATTERN_NAMES[:], &settings.mask_pattern_index)
		settings.mask_pattern = Slime_Mask_Pattern(settings.mask_pattern_index)
		mcp_bridge_apply_named_index(line, "mask_target", SLIME_MASK_TARGET_NAMES[:], &settings.mask_target_index)
		settings.mask_target = Slime_Mask_Target(settings.mask_target_index)
		mcp_bridge_apply_named_index(line, "mask_image_fit_mode", VECTOR_IMAGE_FIT_MODE_NAMES[:], &settings.mask_image_fit_index)
		settings.mask_image_fit_mode = Vector_Image_Fit_Mode(settings.mask_image_fit_index)
		mcp_bridge_apply_named_index(line, "position_image_fit_mode", VECTOR_IMAGE_FIT_MODE_NAMES[:], &settings.position_image_fit_index)
		settings.position_image_fit_mode = Vector_Image_Fit_Mode(settings.position_image_fit_index)
		mcp_bridge_apply_named_index(line, "background_mode", SLIME_BACKGROUND_MODE_NAMES[:], &settings.background_index)
		settings.background_mode = Slime_Background_Mode(settings.background_index)
		mcp_bridge_apply_named_index(line, "trail_map_filtering", FLOW_TRAIL_MAP_FILTERING_NAMES[:], &settings.trail_filtering_index)
		settings.trail_map_filtering = Flow_Trail_Map_Filtering(settings.trail_filtering_index)
		cmd.slime_settings = settings
	}
	if !mcp_bridge_enqueue_command(bridge, cmd) {
		return mcp_bridge_queue_error(id, bridge)
	}
	return mcp_bridge_tool_text(id, fmt.tprintf("{{\"ok\":true,\"queued\":\"configure_simulation\",\"mode\":\"%v\",\"reset\":%v,\"hide_ui\":%v,\"set_mode\":%v}}", kind, reset, hide_ui, set_mode))
}

mcp_bridge_capture_flags :: proc(line: string) -> (reset, hide_ui, set_mode: bool) {
	reset = true
	hide_ui = false
	set_mode = true
	if value, ok := mcp_bridge_extract_bool_field(line, "reset"); ok {reset = value}
	if value, ok := mcp_bridge_extract_bool_field(line, "hide_ui"); ok {hide_ui = value}
	if value, ok := mcp_bridge_extract_bool_field(line, "set_mode"); ok {set_mode = value}
	return
}

mcp_bridge_mode_name_from_configure_tool :: proc(tool_name: string) -> string {
	switch tool_name {
	case "configure_slime_mold":
		return "Slime_Mold"
	case "configure_pellets":
		return "Pellets"
	case "configure_voronoi", "configure_voronoi_ca":
		return "Voronoi_CA"
	case "configure_moire":
		return "Moire"
	case "configure_vectors":
		return "Vectors"
	case "configure_primordial":
		return "Primordial"
	case:
		return ""
	}
}

mcp_bridge_remaining_kind_from_mode :: proc(mode: App_Mode, out: ^Remaining_Sim_Kind) -> bool {
	#partial switch mode {
	case .Slime_Mold:
		out^ = .Slime_Mold
	case .Flow_Field:
		out^ = .Flow_Field
	case .Pellets:
		out^ = .Pellets
	case .Voronoi_CA:
		out^ = .Voronoi_CA
	case .Moire:
		out^ = .Moire
	case .Vectors:
		out^ = .Vectors
	case .Primordial:
		out^ = .Primordial
	case:
		return false
	}
	return true
}

mcp_bridge_apply_color_scheme_fields :: proc(line: string, color_scheme: ^Color_Scheme_Name, reversed: ^bool) {
	if name := mcp_bridge_extract_argument_string_field(line, "color_scheme"); len(name) > 0 {
		color_scheme_name_set(color_scheme, name)
	}
	if value, ok := mcp_bridge_extract_bool_field(line, "reversed"); ok {reversed^ = value}
	if value, ok := mcp_bridge_extract_bool_field(line, "color_scheme_reversed"); ok {reversed^ = value}
}

mcp_bridge_apply_named_index :: proc(line, field: string, names: []string, target: ^int) {
	if value, ok := mcp_bridge_extract_number_field(line, field); ok {
		target^ = int(max(min(value, f32(len(names) - 1)), 0))
		return
	}
	name := mcp_bridge_extract_argument_string_field(line, field)
	if len(name) == 0 {
		return
	}
	index: u32
	if mcp_bridge_named_index(name, names, &index) {
		target^ = int(index)
	}
}

mcp_bridge_apply_noise_fields :: proc(line: string, settings: ^Noise_Settings) {
	mcp_bridge_apply_named_index(line, "noise_kind", NOISE_KIND_NAMES[:], &settings.kind_index)
	settings.kind = Noise_Kind(settings.kind_index)
	mcp_bridge_apply_named_index(line, "fractal_mode", NOISE_FRACTAL_MODE_NAMES[:], &settings.fractal_mode_index)
	settings.fractal_mode = Noise_Fractal_Mode(settings.fractal_mode_index)
	mcp_bridge_apply_named_index(line, "warp_mode", NOISE_WARP_MODE_NAMES[:], &settings.warp_mode_index)
	settings.warp_mode = Noise_Warp_Mode(settings.warp_mode_index)
	if value, ok := mcp_bridge_extract_number_field(line, "seed"); ok {settings.seed = u32(max(value, 0))}
	if value, ok := mcp_bridge_extract_number_field(line, "frequency"); ok {settings.frequency = max(value, 0.000001)}
	if value, ok := mcp_bridge_extract_number_field(line, "amplitude"); ok {settings.amplitude = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "noise_strength"); ok {settings.noise_strength = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "offset_x"); ok {settings.offset_x = value}
	if value, ok := mcp_bridge_extract_number_field(line, "offset_y"); ok {settings.offset_y = value}
	if value, ok := mcp_bridge_extract_number_field(line, "rotation"); ok {settings.rotation = value}
	if value, ok := mcp_bridge_extract_number_field(line, "anchor_x"); ok {settings.anchor_x = value}
	if value, ok := mcp_bridge_extract_number_field(line, "anchor_y"); ok {settings.anchor_y = value}
	if value, ok := mcp_bridge_extract_number_field(line, "octaves"); ok {settings.octaves = u32(max(value, 1))}
	if value, ok := mcp_bridge_extract_number_field(line, "lacunarity"); ok {settings.lacunarity = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "gain"); ok {settings.gain = value}
	if value, ok := mcp_bridge_extract_number_field(line, "warp_octaves"); ok {settings.warp_octaves = u32(max(value, 1))}
	if value, ok := mcp_bridge_extract_number_field(line, "warp_amplitude"); ok {settings.warp_amplitude = max(value, 0)}
	if value, ok := mcp_bridge_extract_number_field(line, "warp_frequency"); ok {settings.warp_frequency = max(value, 0.000001)}
	noise_sync_indices(settings)
}

mcp_bridge_named_index :: proc(name: string, names: []string, out: ^u32) -> bool {
	needle := mcp_bridge_normalized_name(name)
	for candidate, index in names {
		if mcp_bridge_normalized_name(candidate) == needle {
			out^ = u32(index)
			return true
		}
	}
	return false
}

mcp_bridge_normalized_name :: proc(name: string) -> string {
	builder: strings.Builder
	strings.builder_init(&builder, context.temp_allocator)
	for ch in name {
		switch ch {
		case 'A'..='Z':
			strings.write_rune(&builder, ch + ('a' - 'A'))
		case 'a'..='z', '0'..='9':
			strings.write_rune(&builder, ch)
		case:
		}
	}
	return strings.to_string(builder)
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
	if mcp_bridge_profile_near_cap(msg.ui_vertex_count, rendervk.UI_MAX_VERTICES, profile.thresholds.cap_ratio) {
		profile.ui_vertex_pressure_count += 1
	}
	if mcp_bridge_profile_near_cap(msg.ui_batch_count, rendervk.UI_MAX_DRAW_BATCHES, profile.thresholds.cap_ratio) {
		profile.ui_batch_pressure_count += 1
	}
	if mcp_bridge_profile_near_cap(msg.ui_clear_rect_count, rendervk.UI_MAX_CLEAR_RECTS, profile.thresholds.cap_ratio) {
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
	mcp_bridge_profile_warning_append(&builder, &count, profile.ui_vertex_pressure_count > 0, fmt.tprintf("UI vertex count approached renderer cap %d time(s); max=%d cap=%d", profile.ui_vertex_pressure_count, profile.max_ui_vertex_count, rendervk.UI_MAX_VERTICES))
	mcp_bridge_profile_warning_append(&builder, &count, profile.ui_batch_pressure_count > 0, fmt.tprintf("UI batch count approached renderer cap %d time(s); max=%d cap=%d", profile.ui_batch_pressure_count, profile.max_ui_batch_count, rendervk.UI_MAX_DRAW_BATCHES))
	mcp_bridge_profile_warning_append(&builder, &count, profile.ui_clear_rect_pressure_count > 0, fmt.tprintf("UI clear rect count approached renderer cap %d time(s); max=%d cap=%d", profile.ui_clear_rect_pressure_count, profile.max_ui_clear_rect_count, rendervk.UI_MAX_CLEAR_RECTS))
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
	output_width: u32
	output_height: u32
	if value, has_value := mcp_bridge_extract_number_field(line, "scale"); has_value {
		scale = min(max(value, 0.01), 1)
	}
	if value, has_value := mcp_bridge_extract_number_field(line, "max_width"); has_value {
		max_width = u32(max(value, 1))
	}
	if value, has_value := mcp_bridge_extract_number_field(line, "max_height"); has_value {
		max_height = u32(max(value, 1))
	}
	if value, has_value := mcp_bridge_extract_number_field(line, "output_width"); has_value {
		output_width = u32(max(value, 1))
	}
	if value, has_value := mcp_bridge_extract_number_field(line, "output_height"); has_value {
		output_height = u32(max(value, 1))
	}
	qoi_bytes, width, height, sequence, ok := engine.screenshot_state_copy_qoi_resized(bridge.screenshot, max_width, max_height, scale, output_width, output_height, context.temp_allocator)
	if !ok {
		return mcp_bridge_error(id, -32000, "no rendered frame is available yet")
	}

	output_path := mcp_bridge_extract_string_field(line, "output_path")
	if len(output_path) == 0 {
		output_path = mcp_bridge_extract_string_field(line, "path")
	}
	if len(output_path) > 0 {
		if os.write_entire_file(output_path, qoi_bytes) != nil {
			return mcp_bridge_error(id, -32000, "failed to write screenshot output path")
		}
		return mcp_bridge_tool_text(id, fmt.tprintf(
			"{{\"ok\":true,\"format\":\"qoi\",\"mime\":\"image/qoi\",\"width\":%d,\"height\":%d,\"sequence\":%d,\"bytes\":%d,\"output_path\":\"%s\"}}",
			width,
			height,
			sequence,
			len(qoi_bytes),
			mcp_bridge_json_escape(output_path),
		))
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
	case "Voronoi", "voronoi", "Voronoi_CA", "voronoi_ca":
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
		case .Apply_Builtin_Preset:
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Apply_Builtin_Preset
			render_cmd.app_mode = cmd.mode
			render_cmd.builtin_preset_index = cmd.preset_index
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
		case .Set_Color_Scheme:
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Set_Color_Scheme
			render_cmd.app_mode = cmd.mode
			render_cmd.color_scheme_name = cmd.color_scheme_name
			render_cmd.color_scheme_reversed = cmd.color_scheme_reversed
			render_cmd.color_scheme_reversed_set = cmd.color_scheme_reversed_set
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
		case .Configure_Particle_Life:
			if cmd.particle_life_set_mode {
				mode_cmd: Ui_To_Render_Command
				mode_cmd.kind = .Set_App_Mode
				mode_cmd.app_mode = .Particle_Life
				_ = engine.queue_try_push(&app.ui_to_render, mode_cmd)
			}
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Apply_Particle_Life_Settings
			render_cmd.particle_life_settings = cmd.particle_life_settings
			render_cmd.particle_life_randomize_forces = cmd.particle_life_randomize_forces
			render_cmd.particle_life_reset = cmd.particle_life_reset
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
			if cmd.particle_life_hide_ui {
				hide_cmd: Ui_To_Render_Command
				hide_cmd.kind = .Hide_Ui
				_ = engine.queue_try_push(&app.ui_to_render, hide_cmd)
			}
		case .Configure_Flow_Field:
			if cmd.flow_set_mode {
				mode_cmd: Ui_To_Render_Command
				mode_cmd.kind = .Set_App_Mode
				mode_cmd.app_mode = .Flow_Field
				_ = engine.queue_try_push(&app.ui_to_render, mode_cmd)
			}
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Apply_Flow_Settings
			render_cmd.flow_settings = cmd.flow_settings
			render_cmd.flow_reset = cmd.flow_reset
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
			if cmd.flow_hide_ui {
				hide_cmd: Ui_To_Render_Command
				hide_cmd.kind = .Hide_Ui
				_ = engine.queue_try_push(&app.ui_to_render, hide_cmd)
			}
		case .Configure_Gray_Scott:
			if cmd.gray_scott_set_mode {
				mode_cmd: Ui_To_Render_Command
				mode_cmd.kind = .Set_App_Mode
				mode_cmd.app_mode = .Gray_Scott
				_ = engine.queue_try_push(&app.ui_to_render, mode_cmd)
			}
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Apply_Gray_Scott_Settings
			render_cmd.gray_scott_settings = cmd.gray_scott_settings
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
			if cmd.gray_scott_reset {
				reset_cmd: Ui_To_Render_Command
				reset_cmd.kind = .Reset_Gray_Scott
				_ = engine.queue_try_push(&app.ui_to_render, reset_cmd)
			}
			if cmd.gray_scott_seed_noise {
				seed_cmd: Ui_To_Render_Command
				seed_cmd.kind = .Seed_Noise_Gray_Scott
				_ = engine.queue_try_push(&app.ui_to_render, seed_cmd)
			}
			if cmd.gray_scott_hide_ui {
				hide_cmd: Ui_To_Render_Command
				hide_cmd.kind = .Hide_Ui
				_ = engine.queue_try_push(&app.ui_to_render, hide_cmd)
			}
		case .Configure_Remaining_Sim:
			if cmd.remaining_set_mode {
				mode_cmd: Ui_To_Render_Command
				mode_cmd.kind = .Set_App_Mode
				switch cmd.remaining_kind {
				case .Slime_Mold:
					mode_cmd.app_mode = .Slime_Mold
				case .Flow_Field:
					mode_cmd.app_mode = .Flow_Field
				case .Pellets:
					mode_cmd.app_mode = .Pellets
				case .Voronoi_CA:
					mode_cmd.app_mode = .Voronoi_CA
				case .Moire:
					mode_cmd.app_mode = .Moire
				case .Vectors:
					mode_cmd.app_mode = .Vectors
				case .Primordial:
					mode_cmd.app_mode = .Primordial
				}
				_ = engine.queue_try_push(&app.ui_to_render, mode_cmd)
			}
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Apply_Remaining_Settings
			render_cmd.remaining_kind = cmd.remaining_kind
			render_cmd.remaining_reset = cmd.remaining_reset
			render_cmd.flow_settings = cmd.flow_settings
			render_cmd.moire_settings = cmd.moire_settings
			render_cmd.vectors_settings = cmd.vectors_settings
			render_cmd.primordial_settings = cmd.primordial_settings
			render_cmd.voronoi_settings = cmd.voronoi_settings
			render_cmd.pellets_settings = cmd.pellets_settings
			render_cmd.slime_settings = cmd.slime_settings
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
			if cmd.remaining_hide_ui {
				hide_cmd: Ui_To_Render_Command
				hide_cmd.kind = .Hide_Ui
				_ = engine.queue_try_push(&app.ui_to_render, hide_cmd)
			}
		case .Hide_Ui:
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Hide_Ui
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
		case .Seed_Noise_Gray_Scott:
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Seed_Noise_Gray_Scott
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

	builder: strings.Builder
	strings.builder_init(&builder, context.temp_allocator)
	strings.write_string(&builder, fmt.tprintf(
		"{{\"ok\":true,\"running\":%v,\"frame_index\":%d,\"window_width\":%d,\"window_height\":%d,\"logical_window_width\":%d,\"logical_window_height\":%d,\"mouse_x\":%.2f,\"mouse_y\":%.2f,\"mouse_down\":%v,\"fps\":%.2f,\"frame_ms\":%.2f,\"app_mode\":\"%v\"",
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
	))
	strings.write_string(&builder, fmt.tprintf(
		",\"gray_scott_camera_x\":%.4f,\"gray_scott_camera_y\":%.4f,\"gray_scott_camera_zoom\":%.4f,\"gray_scott_controls_visible\":%v,\"gray_scott_paused\":%v",
		status.gray_scott_camera_x,
		status.gray_scott_camera_y,
		status.gray_scott_camera_zoom,
		status.gray_scott_controls_visible,
		status.gray_scott_paused,
	))
	strings.write_string(&builder, fmt.tprintf(
		",\"particle_life_camera_x\":%.4f,\"particle_life_camera_y\":%.4f,\"particle_life_camera_zoom\":%.4f,\"particle_life_ready\":%v,\"particle_life_paused\":%v,\"particle_life_controls_visible\":%v,\"particle_life_frame_index\":%d,\"particle_life_particle_count\":%d,\"particle_life_species_count\":%d,\"particle_life_requested_particle_count\":%d,\"particle_life_requested_species_count\":%d,\"particle_life_trails_enabled\":%v,\"particle_life_infinite_tiles_enabled\":%v",
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
	))
	strings.write_string(&builder, fmt.tprintf(
		",\"gpu_profiling_supported\":%v,\"gpu_profiling_enabled\":%v,\"gpu_simulation_step_ms\":%.4f,\"gpu_simulation_present_ms\":%.4f,\"gpu_ui_overlay_ms\":%.4f,\"gpu_frame_total_ms\":%.4f,\"sim_ms\":%.4f,\"ui_ms\":%.4f,\"render_ms\":%.4f,\"submit_ms\":%.4f,\"screenshot_ms\":%.4f,\"screenshot_captured\":%v,\"ui_build_ms\":%.4f,\"ui_overlay_ms\":%.4f",
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
	))
	strings.write_string(&builder, fmt.tprintf(
		",\"gui_command_count\":%d,\"ui_vertex_count\":%d,\"ui_batch_count\":%d,\"ui_clear_rect_count\":%d,\"main_menu_preview_visible_slot_count\":%d,\"main_menu_preview_warmed_mode_count\":%d,\"main_menu_preview_fallback_fill_count\":%d,\"main_menu_preview_skipped_present_count\":%d",
		status.gui_command_count,
		status.ui_vertex_count,
		status.ui_batch_count,
		status.ui_clear_rect_count,
		status.main_menu_preview_visible_slot_count,
		status.main_menu_preview_warmed_mode_count,
		status.main_menu_preview_fallback_fill_count,
		status.main_menu_preview_skipped_present_count,
	))
	strings.write_string(&builder, fmt.tprintf(
		",\"text_width_calls\":%d,\"text_width_cache_hits\":%d,\"text_width_ms\":%.4f,\"text_shape_calls\":%d,\"text_shape_glyphs\":%d,\"text_shape_ms\":%.4f,\"text_wrap_calls\":%d,\"text_wrap_ms\":%.4f,\"cpu_wait_fence_ms\":%.4f,\"cpu_acquire_ms\":%.4f,\"cpu_command_begin_ms\":%.4f,\"cpu_end_command_ms\":%.4f,\"cpu_queue_submit_ms\":%.4f,\"cpu_queue_present_ms\":%.4f,\"present_mode\":\"%s\"",
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
	))
	strings.write_string(&builder, fmt.tprintf(
		",\"command_render_pass_count\":%d,\"command_compute_dispatch_count\":%d,\"command_draw_count\":%d,\"command_pipeline_bind_count\":%d,\"command_descriptor_bind_count\":%d,\"command_pipeline_barrier_count\":%d,\"command_transfer_copy_count\":%d,\"command_ui_batch_count\":%d,\"command_backdrop_blur_pass_count\":%d,\"command_queue_count\":%d,\"command_queue_closed\":%v,\"last_message\":\"%s\"}}",
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
	))
	return strings.to_string(builder)
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

mcp_bridge_extract_argument_string_field :: proc(line, field: string) -> string {
	arguments_key := "\"arguments\""
	i := strings.index(line, arguments_key)
	if i < 0 {
		return ""
	}
	rest := line[i + len(arguments_key):]
	colon := strings.index(rest, ":")
	if colon < 0 {
		return ""
	}
	return mcp_bridge_extract_string_field(rest[colon + 1:], field)
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

mcp_bridge_extract_bool_field :: proc(line, field: string) -> (bool, bool) {
	key := fmt.tprintf("\"%s\"", field)
	i := strings.index(line, key)
	if i < 0 {
		return false, false
	}
	rest := line[i + len(key):]
	colon := strings.index(rest, ":")
	if colon < 0 {
		return false, false
	}
	rest = strings.trim_space(rest[colon + 1:])
	if strings.has_prefix(rest, "true") {
		return true, true
	}
	if strings.has_prefix(rest, "false") {
		return false, true
	}
	return false, false
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
