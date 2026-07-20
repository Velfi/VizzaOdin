package app

import uifw "zelda_engine:ui"
import engine "zelda_engine:engine"
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
	Resize_Window,
	Set_Mode,
	Set_Ui_Component_Fixture,
	Apply_Builtin_Preset,
	Set_Color_Scheme,
	Configure_Particle_Life,
	Configure_Flow_Field,
	Configure_Gray_Scott,
	Configure_ST_Flip,
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
	component_fixture: Ui_Component_Fixture,
	component_fixture_state: Ui_Component_Fixture_State,
	component_fixture_value: f32,
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
	st_flip_settings: ST_Flip_Settings,
	st_flip_reset: bool,
	st_flip_hide_ui: bool,
	st_flip_set_mode: bool,
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
	gpu_pellets_grid_clear_ms: f32,
	gpu_pellets_grid_build_ms: f32,
	gpu_pellets_grid_scatter_ms: f32,
	gpu_pellets_physics_ms: f32,
	gpu_pellets_density_ms: f32,
	gpu_pellets_particle_draw_ms: f32,
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
	when ODIN_OS == .Windows {
		// The bridge currently relies on Unix nonblocking stdio. Keep the
		// regular Windows app available while reporting --mcp as unsupported.
		return false
	} else {
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
}

mcp_bridge_stop :: proc(bridge: ^Mcp_Bridge) {
	bridge.running = false
	bridge.status.running = false
}

mcp_bridge_write_response :: proc(bridge: ^Mcp_Bridge, response: string) {
	when ODIN_OS == .Windows {
		return
	} else {
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
}

mcp_bridge_poll_stdio :: proc(bridge: ^Mcp_Bridge) {
	when ODIN_OS == .Windows {
		return
	} else {
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
			APP_VERSION,
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
{"name":"gpu_status","description":"Read compact frame and GPU pass timings from the running Vizza app.","inputSchema":{"type":"object","properties":{}}},
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
{"name":"resize_window","description":"Resize the running window in logical points for resize-preservation testing.","inputSchema":{"type":"object","required":["width","height"],"properties":{"width":{"type":"number"},"height":{"type":"number"}}}},
{"name":"set_mode","description":"Navigate directly to an app mode by status name, e.g. Slime_Mold, Flow_Field, Pellets, Voronoi, Moire, Vectors, Primordial, Main_Menu.","inputSchema":{"type":"object","required":["mode"],"properties":{"mode":{"type":"string"}}}},
{"name":"list_ui_components","description":"List UI component fixtures and supported visual states available to the isolated renderer.","inputSchema":{"type":"object","properties":{}}},
{"name":"render_ui_component","description":"Render one UI component fixture in isolation through the production UI pipeline.","inputSchema":{"type":"object","required":["component"],"properties":{"component":{"type":"string","enum":["button","toggle","slider","number","integer","selector","text_input"]},"state":{"type":"string","enum":["rest","hover","active","focused","editing","disabled"]},"value":{"type":"number","description":"Fixture value; meaning depends on the component."}}}},
{"name":"apply_builtin_preset","description":"Apply a built-in preset by app mode and zero-based preset index.","inputSchema":{"type":"object","required":["mode","index"],"properties":{"mode":{"type":"string"},"index":{"type":"number"}}}},
{"name":"set_color_scheme","description":"Set the color scheme for a simulation mode. The scheme name should match an available LUT without the .lut suffix.","inputSchema":{"type":"object","required":["mode","color_scheme"],"properties":{"mode":{"type":"string"},"color_scheme":{"type":"string"},"name":{"type":"string","description":"Alias for color_scheme."},"reversed":{"type":"boolean"}}}},
{"name":"configure_simulation","description":"Apply a flat capture/configuration blob to any simulation mode except Gradient_Editor. Requires mode. Starts from that simulation's defaults, applies supplied numeric/string/boolean fields, and supports reset, hide_ui, and set_mode.","inputSchema":{"type":"object","required":["mode"],"properties":{"mode":{"type":"string"},"reset":{"type":"boolean","description":"Defaults true."},"hide_ui":{"type":"boolean","description":"Defaults false."},"set_mode":{"type":"boolean","description":"Defaults true."}}}},
{"name":"configure_gray_scott","description":"Apply a Gray-Scott capture/configuration blob. Supports feed, kill, diffusion_a, diffusion_b, timestep, simulation_speed, mask settings, cursor settings, color_scheme, reversed, seed_noise, reset, hide_ui, and set_mode.","inputSchema":{"type":"object","properties":{}}},
{"name":"configure_particle_life","description":"Apply a Particle Life capture/configuration blob. Supports species_count, particle_count, max_distance, collision_enabled, force_dense_sampling, generators, force ranges, reset, hide_ui, and set_mode. Generators may be numeric indexes or names such as Center and Random.","inputSchema":{"type":"object","properties":{"species_count":{"type":"number","description":"Clamped to 1-8."},"particle_count":{"type":"number"},"max_distance":{"type":"number"},"collision_enabled":{"type":"boolean"},"force_dense_sampling":{"type":"boolean"},"position_generator":{"oneOf":[{"type":"string"},{"type":"number"}]},"type_generator":{"oneOf":[{"type":"string"},{"type":"number"}]},"force_generator":{"oneOf":[{"type":"string"},{"type":"number"}]},"force_random_min":{"type":"number"},"force_random_max":{"type":"number"},"randomize_forces":{"type":"boolean","description":"Defaults true when force fields are provided."},"reset":{"type":"boolean","description":"Defaults true."},"hide_ui":{"type":"boolean","description":"Defaults false."},"set_mode":{"type":"boolean","description":"Defaults true."}}}},
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
