package app

import engine "../engine"
import rendervk "../render_vk"

import base64 "core:encoding/base64"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sync"

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
	case "ST_FLIP", "st_flip", "ST-FLIP":
		out^ = .ST_FLIP
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

mcp_bridge_ui_component_fixture_from_name :: proc(name: string) -> (Ui_Component_Fixture, bool) {
	switch name {
	case "button": return .Button, true
	case "toggle": return .Toggle, true
	case "slider": return .Slider, true
	case "number", "numeric", "number_input": return .Number, true
	case "integer", "u32": return .Integer, true
	case "selector": return .Selector, true
	case "text_input", "text": return .Text_Input, true
	}
	return .None, false
}

mcp_bridge_ui_component_state_from_name :: proc(name: string) -> (Ui_Component_Fixture_State, bool) {
	switch name {
	case "rest": return .Rest, true
	case "hover", "hot": return .Hover, true
	case "active", "pressed": return .Active, true
	case "focused", "focus": return .Focused, true
	case "editing", "edit": return .Editing, true
	case "disabled": return .Disabled, true
	}
	return .Rest, false
}
