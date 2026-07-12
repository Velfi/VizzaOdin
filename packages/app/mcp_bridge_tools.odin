package app

import "core:fmt"
import "core:strings"
import "core:sync"



mcp_bridge_call_tool :: proc(bridge: ^Mcp_Bridge, id, name, line: string) -> string {
	if response, handled := mcp_bridge_call_status_tool(bridge, id, name, line); handled {return response}
	if response, handled := mcp_bridge_call_pointer_tool(bridge, id, name, line); handled {return response}
	if response, handled := mcp_bridge_call_configure_tool(bridge, id, name, line); handled {return response}
	if response, handled := mcp_bridge_call_media_tool(bridge, id, name, line); handled {return response}
	if response, handled := mcp_bridge_call_application_tool(bridge, id, name, line); handled {return response}
	return mcp_bridge_error(id, -32602, "unknown tool")
}

mcp_bridge_call_status_tool :: proc(bridge: ^Mcp_Bridge, id, name, line: string) -> (string, bool) {
	switch name {
	case "app_status":
		return mcp_bridge_tool_text(id, mcp_bridge_status_json(bridge)), true
	case "gpu_status":
		return mcp_bridge_tool_text(id, mcp_bridge_gpu_status_json(bridge)), true
	case "profile_start":
		return mcp_bridge_profile_start(id, bridge, line), true
	case "profile_status":
		return mcp_bridge_tool_text(id, mcp_bridge_profile_status_json(bridge)), true
	case "profile_report":
		return mcp_bridge_tool_text(id, mcp_bridge_profile_report_json(bridge)), true
	case "profile_reset":
		sync.mutex_lock(&bridge.status_mutex)
		bridge.profile = {}
		sync.mutex_unlock(&bridge.status_mutex)
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"profile\":\"reset\"}"), true
	case "list_modes":
		return mcp_bridge_tool_text(id, mcp_bridge_list_modes_json()), true
	case "list_builtin_presets":
		mode_name := mcp_bridge_extract_string_field(line, "mode")
		mode: App_Mode
		if !mcp_bridge_app_mode_from_name(mode_name, &mode) {
			return mcp_bridge_error(id, -32602, "list_builtin_presets requires a known app mode"), true
		}
		return mcp_bridge_tool_text(id, mcp_bridge_list_builtin_presets_json(mode)), true
	case "list_color_schemes":
		return mcp_bridge_tool_text(id, mcp_bridge_list_color_schemes_json()), true
	case:
		return "", false
	}
	return "", false
}

mcp_bridge_call_pointer_tool :: proc(bridge: ^Mcp_Bridge, id, name, line: string) -> (string, bool) {
	switch name {
	case "click":
		x, x_ok := mcp_bridge_extract_number_field(line, "x")
		y, y_ok := mcp_bridge_extract_number_field(line, "y")
		if !x_ok || !y_ok {
			return mcp_bridge_error(id, -32602, "click requires numeric x and y"), true
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Click, x = x, y = y, button = 1}) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"click\"}"), true
	case "mouse_down":
		x, x_ok := mcp_bridge_extract_number_field(line, "x")
		y, y_ok := mcp_bridge_extract_number_field(line, "y")
		if !x_ok || !y_ok {
			return mcp_bridge_error(id, -32602, "mouse_down requires numeric x and y"), true
		}
		button := u32(1)
		if value, ok := mcp_bridge_extract_number_field(line, "button"); ok {
			button = u32(max(min(value, 3), 1))
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Mouse_Down, x = x, y = y, button = button}) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"mouse_down\"}"), true
	case "mouse_up":
		x, x_ok := mcp_bridge_extract_number_field(line, "x")
		y, y_ok := mcp_bridge_extract_number_field(line, "y")
		if !x_ok || !y_ok {
			return mcp_bridge_error(id, -32602, "mouse_up requires numeric x and y"), true
		}
		button := u32(1)
		if value, ok := mcp_bridge_extract_number_field(line, "button"); ok {
			button = u32(max(min(value, 3), 1))
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Mouse_Up, x = x, y = y, button = button}) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"mouse_up\"}"), true
	case "move":
		x, x_ok := mcp_bridge_extract_number_field(line, "x")
		y, y_ok := mcp_bridge_extract_number_field(line, "y")
		if !x_ok || !y_ok {
			return mcp_bridge_error(id, -32602, "move requires numeric x and y"), true
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Move, x = x, y = y}) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"move\"}"), true
	case "wheel":
		delta, ok := mcp_bridge_extract_number_field(line, "delta")
		if !ok {
			return mcp_bridge_error(id, -32602, "wheel requires numeric delta"), true
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Wheel, wheel_delta = delta}) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"wheel\"}"), true
	case "set_mode":
		mode_name := mcp_bridge_extract_string_field(line, "mode")
		mode: App_Mode
		if !mcp_bridge_app_mode_from_name(mode_name, &mode) {
			return mcp_bridge_error(id, -32602, "set_mode requires a known app mode"), true
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Set_Mode, mode = mode}) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"set_mode\"}"), true
	case:
		return "", false
	}
	return "", false
}

mcp_bridge_call_configure_tool :: proc(bridge: ^Mcp_Bridge, id, name, line: string) -> (string, bool) {
	switch name {
	case "list_ui_components":
		return mcp_bridge_tool_text(id, "{\"components\":[\"button\",\"toggle\",\"slider\",\"number\",\"integer\",\"selector\",\"text_input\"],\"states\":[\"rest\",\"hover\",\"active\",\"focused\",\"editing\",\"disabled\"]}"), true
	case "render_ui_component":
		component_name := mcp_bridge_extract_string_field(line, "component")
		fixture, fixture_ok := mcp_bridge_ui_component_fixture_from_name(component_name)
		if !fixture_ok {
			return mcp_bridge_error(id, -32602, "render_ui_component requires a known component"), true
		}
		state_name := mcp_bridge_extract_string_field(line, "state")
		fixture_state, state_ok := mcp_bridge_ui_component_state_from_name(state_name)
		if len(state_name) == 0 {
			fixture_state, state_ok = .Rest, true
		}
		if !state_ok {
			return mcp_bridge_error(id, -32602, "render_ui_component requires a known state"), true
		}
		value := f32(0.58)
		if requested, ok := mcp_bridge_extract_number_field(line, "value"); ok do value = requested
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Set_Ui_Component_Fixture, component_fixture = fixture, component_fixture_state = fixture_state, component_fixture_value = value}) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, fmt.tprintf("{\"ok\":true,\"queued\":\"render_ui_component\",\"component\":\"%s\",\"state\":\"%s\",\"value\":%.6f}", component_name, state_name, value)), true
	case "apply_builtin_preset":
		mode_name := mcp_bridge_extract_string_field(line, "mode")
		mode: App_Mode
		if !mcp_bridge_app_mode_from_name(mode_name, &mode) {
			return mcp_bridge_error(id, -32602, "apply_builtin_preset requires a known app mode"), true
		}
		index, index_ok := mcp_bridge_extract_number_field(line, "index")
		if !index_ok {
			return mcp_bridge_error(id, -32602, "apply_builtin_preset requires numeric index"), true
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Apply_Builtin_Preset, mode = mode, preset_index = int(index)}) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"apply_builtin_preset\"}"), true
	case "set_color_scheme":
		mode_name := mcp_bridge_extract_string_field(line, "mode")
		mode: App_Mode
		if !mcp_bridge_app_mode_from_name(mode_name, &mode) {
			return mcp_bridge_error(id, -32602, "set_color_scheme requires a known app mode"), true
		}
		name := mcp_bridge_extract_argument_string_field(line, "color_scheme")
		if len(name) == 0 {
			name = mcp_bridge_extract_argument_string_field(line, "name")
		}
		if len(name) == 0 {
			return mcp_bridge_error(id, -32602, "set_color_scheme requires color_scheme"), true
		}
		cmd := Mcp_Command{kind = .Set_Color_Scheme, mode = mode}
		write_fixed_string(cmd.color_scheme_name[:], name)
		if value, ok := mcp_bridge_extract_bool_field(line, "reversed"); ok {
			cmd.color_scheme_reversed = value
			cmd.color_scheme_reversed_set = true
		}
		if !mcp_bridge_enqueue_command(bridge, cmd) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"set_color_scheme\"}"), true
	case "configure_particle_life":
		return mcp_bridge_configure_particle_life(id, bridge, line), true
	case "configure_flow_field":
		return mcp_bridge_configure_flow_field(id, bridge, line), true
	case "configure_gray_scott":
		return mcp_bridge_configure_gray_scott(id, bridge, line), true
	case "configure_simulation", "configure_slime_mold", "configure_pellets", "configure_voronoi", "configure_voronoi_ca", "configure_moire", "configure_vectors", "configure_primordial":
		return mcp_bridge_configure_simulation(id, bridge, name, line), true
	case:
		return "", false
	}
	return "", false
}

mcp_bridge_call_media_tool :: proc(bridge: ^Mcp_Bridge, id, name, line: string) -> (string, bool) {
	switch name {
	case "hide_ui":
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Hide_Ui}) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"hide_ui\"}"), true
	case "seed_noise_gray_scott":
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Seed_Noise_Gray_Scott}) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"seed_noise_gray_scott\"}"), true
	case "load_vectors_image":
		path := mcp_bridge_extract_string_field(line, "path")
		if len(path) == 0 {
			return mcp_bridge_error(id, -32602, "load_vectors_image requires path"), true
		}
		cmd := Mcp_Command{kind = .Load_Vectors_Image}
		write_fixed_string(cmd.file_path[:], path)
		if !mcp_bridge_enqueue_command(bridge, cmd) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"load_vectors_image\"}"), true
	case "load_moire_image":
		path := mcp_bridge_extract_string_field(line, "path")
		if len(path) == 0 {
			return mcp_bridge_error(id, -32602, "load_moire_image requires path"), true
		}
		cmd := Mcp_Command{kind = .Load_Moire_Image}
		write_fixed_string(cmd.file_path[:], path)
		if !mcp_bridge_enqueue_command(bridge, cmd) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"load_moire_image\"}"), true
	case "load_flow_image":
		path := mcp_bridge_extract_string_field(line, "path")
		if len(path) == 0 {
			return mcp_bridge_error(id, -32602, "load_flow_image requires path"), true
		}
		cmd := Mcp_Command{kind = .Load_Flow_Image}
		write_fixed_string(cmd.file_path[:], path)
		if !mcp_bridge_enqueue_command(bridge, cmd) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"load_flow_image\"}"), true
	case "load_slime_mask_image":
		path := mcp_bridge_extract_string_field(line, "path")
		if len(path) == 0 {
			return mcp_bridge_error(id, -32602, "load_slime_mask_image requires path"), true
		}
		cmd := Mcp_Command{kind = .Load_Slime_Mask_Image}
		write_fixed_string(cmd.file_path[:], path)
		if !mcp_bridge_enqueue_command(bridge, cmd) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"load_slime_mask_image\"}"), true
	case "load_slime_position_image":
		path := mcp_bridge_extract_string_field(line, "path")
		if len(path) == 0 {
			return mcp_bridge_error(id, -32602, "load_slime_position_image requires path"), true
		}
		cmd := Mcp_Command{kind = .Load_Slime_Position_Image}
		write_fixed_string(cmd.file_path[:], path)
		if !mcp_bridge_enqueue_command(bridge, cmd) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"load_slime_position_image\"}"), true
	case:
		return "", false
	}
	return "", false
}

mcp_bridge_call_application_tool :: proc(bridge: ^Mcp_Bridge, id, name, line: string) -> (string, bool) {
	switch name {
	case "close_app":
		bridge.close_requested = true
		_ = mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Close})
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"close\"}"), true
	case "screenshot":
		return mcp_bridge_screenshot(id, bridge, line), true
	case "resize_window":
		width, width_ok := mcp_bridge_extract_number_field(line, "width")
		height, height_ok := mcp_bridge_extract_number_field(line, "height")
		if !width_ok || !height_ok || width < 320 || height < 240 {
			return mcp_bridge_error(id, -32602, "resize_window requires width >= 320 and height >= 240"), true
		}
		if !mcp_bridge_enqueue_command(bridge, Mcp_Command{kind = .Resize_Window, x = width, y = height}) {
			return mcp_bridge_queue_error(id, bridge), true
		}
		return mcp_bridge_tool_text(id, "{\"ok\":true,\"queued\":\"resize_window\"}"), true
	case:
		return "", false
	}
	return "", false
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
	modes: [16]string
	simulations: [16]string
	mode_count := 0
	simulation_count := 0
	modes[mode_count] = "Main_Menu"
	mode_count += 1
	for index in 0 ..< feature_count() {
		descriptor, ok := feature_descriptor_at(index)
		if !ok do continue
		name := fmt.tprintf("%v", descriptor.mode)
		modes[mode_count] = name
		mode_count += 1
		simulations[simulation_count] = name
		simulation_count += 1
	}
	shell_modes := [?]string{"Options", "How_To_Play", "Theme_Preview"}
	for name in shell_modes {
		modes[mode_count] = name
		mode_count += 1
	}
	return fmt.tprintf(
		"{{\"ok\":true,\"modes\":%s,\"simulations\":%s}}",
		mcp_bridge_json_string_array(modes[:mode_count]),
		mcp_bridge_json_string_array(simulations[:simulation_count]),
	)
}

mcp_bridge_list_builtin_presets_json :: proc(mode: App_Mode) -> string {
	descriptor, ok := feature_descriptor_by_mode(mode)
	if !ok || descriptor.builtin_preset_names == nil {
		return fmt.tprintf("{{\"ok\":true,\"mode\":\"%v\",\"count\":0,\"presets\":[]}}", mode)
	}
	names := descriptor.builtin_preset_names()
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
