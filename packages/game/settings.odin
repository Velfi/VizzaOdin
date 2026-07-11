package game

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

STEAM_DEFAULT_ENABLED :: #config(VIZZA_STEAM_DEFAULT_ENABLED, false)
STEAM_DEFAULT_APP_ID :: u32(#config(VIZZA_STEAM_APP_ID, 0))
STEAM_DEFAULT_RESTART_IF_NECESSARY :: #config(VIZZA_STEAM_RESTART_IF_NECESSARY, false)

Toml_Type :: enum i32 {
	UNKNOWN  = 0,
	STRING   = 1,
	INT64    = 2,
	FP64     = 3,
	BOOLEAN  = 4,
	DATE     = 5,
	TIME     = 6,
	DATETIME = 7,
	DATETIMETZ = 8,
	ARRAY    = 9,
	TABLE    = 10,
}

Toml_String :: struct {
	ptr: cstring,
	len: i32,
}

Toml_Timestamp :: struct {
	year, month, day: i16,
	hour, minute, second: i16,
	usec: i32,
	tz: i16,
}

Toml_Array :: struct {
	size: i32,
	elem: ^Toml_Datum,
}

Toml_Table :: struct {
	size: i32,
	key: ^^u8,
	len: ^i32,
	value: ^Toml_Datum,
}

Toml_Value :: struct #raw_union {
	s: cstring,
	str: Toml_String,
	int64: i64,
	fp64: f64,
	boolean: bool,
	ts: Toml_Timestamp,
	arr: Toml_Array,
	tab: Toml_Table,
}

Toml_Datum :: struct {
	type: Toml_Type,
	flag: u32,
	lineno: i32,
	colno: i32,
	source: cstring,
	u: Toml_Value,
}

Toml_Result :: struct {
	ok: bool,
	toptab: Toml_Datum,
	errmsg: [200]u8,
	internal: rawptr,
}

when ODIN_OS == .Windows {
	foreign import tomlc17 "../../third_party/tomlc17/src/tomlc17.lib"
} else {
	foreign import tomlc17 "../../third_party/tomlc17/src/libtomlc17.a"
}

@(default_calling_convention = "c")
foreign tomlc17 {
	toml_parse_file_ex :: proc(fname: cstring) -> Toml_Result ---
	toml_free :: proc(result: Toml_Result) ---
	toml_seek :: proc(table: Toml_Datum, multipart_key: cstring) -> Toml_Datum ---
}

CONTROLLER_FACE_LAYOUT_OPTIONS := [?]string{"South Accept", "East Accept"}
CONTROLLER_MENU_LAYOUT_OPTIONS := [?]string{"Start Pauses", "View Pauses"}
CONTROLLER_SHOULDER_LAYOUT_OPTIONS := [?]string{"Right Next", "Left Next"}
CONTROLLER_TRIGGER_LAYOUT_OPTIONS := [?]string{"Right Primary", "Left Primary"}
KEYBOARD_SHORTCUT_PROFILE_OPTIONS := [?]string{"Standard", "Letter Shortcuts", "Custom"}
KEYBOARD_SHORTCUT_KEY_OPTIONS := [?]string{"Space", "Slash", "F1", "P", "U", "H"}

Keyboard_Shortcut_Key :: enum u8 {
	Space,
	Slash,
	F1,
	P,
	U,
	H,
}

Keyboard_Shortcut_Action :: enum u8 {
	Pause,
	Toggle_Ui,
	Help,
}

keyboard_shortcut_key_name :: proc(key: Keyboard_Shortcut_Key) -> string {
	index := int(key)
	if index < 0 || index >= len(KEYBOARD_SHORTCUT_KEY_OPTIONS) {return "Space"}
	return KEYBOARD_SHORTCUT_KEY_OPTIONS[index]
}

keyboard_shortcut_key_from_name :: proc(name: string) -> (Keyboard_Shortcut_Key, bool) {
	for option, index in KEYBOARD_SHORTCUT_KEY_OPTIONS {
		if name == option {return Keyboard_Shortcut_Key(index), true}
	}
	return .Space, false
}

App_Settings :: struct {
	ui_scale: f32,
	default_fps_limit: i32,
	default_fps_limit_enabled: bool,
	window_width: i32,
	window_height: i32,
	window_maximized: bool,
	auto_hide_delay: i32,
	menu_position: string,
	remember_controller_focus: bool,
	controller_deadzone: f32,
	controller_cursor_speed: f32,
	navigation_repeat_delay_ms: i32,
	navigation_repeat_interval_ms: i32,
	controller_face_layout: string,
	controller_menu_layout: string,
	controller_shoulder_layout: string,
	controller_trigger_layout: string,
	keyboard_shortcut_profile: string,
	keyboard_pause_binding: Keyboard_Shortcut_Key,
	keyboard_toggle_ui_binding: Keyboard_Shortcut_Key,
	keyboard_help_binding: Keyboard_Shortcut_Key,
	default_camera_sensitivity: f32,
	controller_camera_sensitivity: f32,
	controller_camera_invert_y: bool,
	preferred_camera: string,
	texture_filtering: string,
	gpu_memory_ceiling_fraction: f32,
	preset_directory: string,
	steam_enabled: bool,
	steam_app_id: u32,
	steam_restart_if_necessary: bool,
	steam_library_path: string,
}

settings_default :: proc() -> App_Settings {
	return {
		ui_scale = 1.0,
		default_fps_limit = 60,
		default_fps_limit_enabled = false,
		window_width = 1920,
		window_height = 1080,
		window_maximized = true,
		auto_hide_delay = 3000,
		menu_position = "middle",
		remember_controller_focus = true,
		controller_deadzone = 0.25,
		controller_cursor_speed = 0.72,
		navigation_repeat_delay_ms = 350,
		navigation_repeat_interval_ms = 90,
		controller_face_layout = "South Accept",
		controller_menu_layout = "Start Pauses",
		controller_shoulder_layout = "Right Next",
		controller_trigger_layout = "Right Primary",
		keyboard_shortcut_profile = "Standard",
		keyboard_pause_binding = .Space,
		keyboard_toggle_ui_binding = .Slash,
		keyboard_help_binding = .F1,
		default_camera_sensitivity = 1.0,
		controller_camera_sensitivity = 1.0,
		controller_camera_invert_y = false,
		preferred_camera = "",
		texture_filtering = "Linear",
		gpu_memory_ceiling_fraction = 0,
		preset_directory = "presets",
		steam_enabled = STEAM_DEFAULT_ENABLED,
		steam_app_id = STEAM_DEFAULT_APP_ID,
		steam_restart_if_necessary = STEAM_DEFAULT_RESTART_IF_NECESSARY,
		steam_library_path = "",
	}
}

settings_keyboard_binding :: proc(settings: App_Settings, action: Keyboard_Shortcut_Action) -> Keyboard_Shortcut_Key {
	switch action {
	case .Pause: return settings.keyboard_pause_binding
	case .Toggle_Ui: return settings.keyboard_toggle_ui_binding
	case .Help: return settings.keyboard_help_binding
	}
	return .Space
}

settings_set_keyboard_binding :: proc(settings: ^App_Settings, action: Keyboard_Shortcut_Action, key: Keyboard_Shortcut_Key) {
	switch action {
	case .Pause: settings.keyboard_pause_binding = key
	case .Toggle_Ui: settings.keyboard_toggle_ui_binding = key
	case .Help: settings.keyboard_help_binding = key
	}
}

settings_keyboard_binding_allowed :: proc(action: Keyboard_Shortcut_Action, key: Keyboard_Shortcut_Key) -> bool {
	// Space intentionally remains Pause + Slime Control Deck. Assigning Help or
	// Toggle UI to it would create two unrelated actions in the same context.
	return key != .Space || action == .Pause
}

settings_apply_keyboard_profile :: proc(settings: ^App_Settings, profile: string) {
	settings.keyboard_shortcut_profile = profile
	if profile == "Letter Shortcuts" {
		settings.keyboard_pause_binding = .P
		settings.keyboard_toggle_ui_binding = .U
		settings.keyboard_help_binding = .H
	} else if profile == "Standard" {
		settings.keyboard_pause_binding = .Space
		settings.keyboard_toggle_ui_binding = .Slash
		settings.keyboard_help_binding = .F1
	}
}

settings_keyboard_binding_in_use :: proc(settings: App_Settings, key: Keyboard_Shortcut_Key, except: Keyboard_Shortcut_Action) -> bool {
	for action in Keyboard_Shortcut_Action {
		if action != except && settings_keyboard_binding(settings, action) == key {return true}
	}
	return false
}

settings_keyboard_first_free_binding :: proc(settings: App_Settings, action: Keyboard_Shortcut_Action, reserved: Keyboard_Shortcut_Key) -> Keyboard_Shortcut_Key {
	for key in Keyboard_Shortcut_Key {
		if key != reserved && settings_keyboard_binding_allowed(action, key) && !settings_keyboard_binding_in_use(settings, key, action) {
			return key
		}
	}
	return action == .Pause ? .Space : .Slash
}

// Assigning a duplicate swaps the displaced action to the old key whenever
// that key is legal. If Space would be displaced into Help/Toggle UI, choose
// the first free legal key instead. Returns the displaced action, if any.
settings_assign_keyboard_binding :: proc(settings: ^App_Settings, action: Keyboard_Shortcut_Action, key: Keyboard_Shortcut_Key) -> (Keyboard_Shortcut_Action, bool) {
	if settings == nil || !settings_keyboard_binding_allowed(action, key) {return {}, false}
	old_key := settings_keyboard_binding(settings^, action)
	if old_key == key {return {}, false}
	displaced: Keyboard_Shortcut_Action
	had_conflict := false
	for other in Keyboard_Shortcut_Action {
		if other != action && settings_keyboard_binding(settings^, other) == key {
			displaced = other
			had_conflict = true
			break
		}
	}
	settings_set_keyboard_binding(settings, action, key)
	if had_conflict {
		replacement := old_key
		if !settings_keyboard_binding_allowed(displaced, replacement) || settings_keyboard_binding_in_use(settings^, replacement, displaced) {
			replacement = settings_keyboard_first_free_binding(settings^, displaced, key)
		}
		settings_set_keyboard_binding(settings, displaced, replacement)
	}
	settings.keyboard_shortcut_profile = "Custom"
	return displaced, had_conflict
}

settings_keyboard_bindings_valid :: proc(settings: App_Settings) -> bool {
	return settings_keyboard_binding_allowed(.Pause, settings.keyboard_pause_binding) &&
		settings_keyboard_binding_allowed(.Toggle_Ui, settings.keyboard_toggle_ui_binding) &&
		settings_keyboard_binding_allowed(.Help, settings.keyboard_help_binding) &&
		settings.keyboard_pause_binding != settings.keyboard_toggle_ui_binding &&
		settings.keyboard_pause_binding != settings.keyboard_help_binding &&
		settings.keyboard_toggle_ui_binding != settings.keyboard_help_binding
}

settings_effective_keyboard_binding :: proc(settings: App_Settings, action: Keyboard_Shortcut_Action) -> Keyboard_Shortcut_Key {
	if settings_keyboard_bindings_valid(settings) {return settings_keyboard_binding(settings, action)}
	if settings.keyboard_shortcut_profile == "Letter Shortcuts" {
		switch action {
		case .Pause: return .P
		case .Toggle_Ui: return .U
		case .Help: return .H
		}
	}
	switch action {
	case .Pause: return .Space
	case .Toggle_Ui: return .Slash
	case .Help: return .F1
	}
	return .Space
}

settings_toml_parser_name :: proc() -> string {
	return "tomlc17"
}

settings_app_config_path :: proc() -> string {
	when ODIN_OS == .Windows {
		buf: [1024]u8
		local_app_data := os.get_env_buf(buf[:], "LOCALAPPDATA")
		if len(local_app_data) > 0 {
			return fmt.tprintf("%s/VizzaOdin/config/app.toml", local_app_data)
		}
	}
	return "config/app.toml"
}

settings_load_app :: proc(path: string) -> (App_Settings, bool) {
	settings := settings_default()
	if !os.exists(path) {
		return settings, false
	}

	cpath, cerr := strings.clone_to_cstring(path, context.temp_allocator)
	if cerr != nil {
		return settings, false
	}
	result := toml_parse_file_ex(cpath)
	defer toml_free(result)
	if !result.ok {
		return settings, false
	}

	if v, ok := toml_i64(result.toptab, "window.width"); ok {
		settings.window_width = i32(v)
	}
	if v, ok := toml_i64(result.toptab, "window.height"); ok {
		settings.window_height = i32(v)
	}
	if v, ok := toml_bool(result.toptab, "window.maximized"); ok {
		settings.window_maximized = v
	}
	if v, ok := toml_bool(result.toptab, "display.fps_limit_enabled"); ok {
		settings.default_fps_limit_enabled = v
	}
	if v, ok := toml_i64(result.toptab, "display.fps_limit"); ok {
		settings.default_fps_limit = i32(v)
	}
	if v, ok := toml_f64(result.toptab, "display.ui_scale"); ok {
		settings.ui_scale = f32(v)
	}
	if v, ok := toml_string(result.toptab, "display.texture_filtering"); ok {
		cloned, aerr := strings.clone(v)
		if aerr == nil {
			settings.texture_filtering = cloned
		}
	}
	if v, ok := toml_i64(result.toptab, "ui.auto_hide_delay"); ok {
		settings.auto_hide_delay = i32(v)
	}
	if v, ok := toml_string(result.toptab, "ui.menu_position"); ok {
		cloned, aerr := strings.clone(v)
		if aerr == nil {
			settings.menu_position = cloned
		}
	}
	if v, ok := toml_bool(result.toptab, "ui.remember_controller_focus"); ok {
		settings.remember_controller_focus = v
	}
	if v, ok := toml_f64(result.toptab, "input.controller_deadzone"); ok {
		settings.controller_deadzone = min(max(f32(v), 0.05), 0.60)
	}
	if v, ok := toml_f64(result.toptab, "input.controller_cursor_speed"); ok {
		settings.controller_cursor_speed = min(max(f32(v), 0.20), 2.0)
	}
	if v, ok := toml_i64(result.toptab, "input.navigation_repeat_delay_ms"); ok {
		settings.navigation_repeat_delay_ms = i32(min(max(v, 150), 1000))
	}
	if v, ok := toml_i64(result.toptab, "input.navigation_repeat_interval_ms"); ok {
		settings.navigation_repeat_interval_ms = i32(min(max(v, 30), 300))
	}
	if v, ok := toml_string(result.toptab, "input.controller_face_layout"); ok {
		for option in CONTROLLER_FACE_LAYOUT_OPTIONS {
			if v == option {
				cloned, aerr := strings.clone(v)
				if aerr == nil {
					settings.controller_face_layout = cloned
				}
				break
			}
		}
	}
	if v, ok := toml_string(result.toptab, "input.controller_menu_layout"); ok {
		for option in CONTROLLER_MENU_LAYOUT_OPTIONS {
			if v == option {
				cloned, aerr := strings.clone(v)
				if aerr == nil {settings.controller_menu_layout = cloned}
				break
			}
		}
	}
	if v, ok := toml_string(result.toptab, "input.controller_shoulder_layout"); ok {
		for option in CONTROLLER_SHOULDER_LAYOUT_OPTIONS {
			if v == option {
				cloned, aerr := strings.clone(v)
				if aerr == nil {settings.controller_shoulder_layout = cloned}
				break
			}
		}
	}
	if v, ok := toml_string(result.toptab, "input.controller_trigger_layout"); ok {
		for option in CONTROLLER_TRIGGER_LAYOUT_OPTIONS {
			if v == option {
				cloned, aerr := strings.clone(v)
				if aerr == nil {settings.controller_trigger_layout = cloned}
				break
			}
		}
	}
	if v, ok := toml_string(result.toptab, "input.keyboard_shortcut_profile"); ok {
		for option in KEYBOARD_SHORTCUT_PROFILE_OPTIONS {
			if v == option {
				cloned, aerr := strings.clone(v)
				if aerr == nil {
					settings.keyboard_shortcut_profile = cloned
				}
				break
			}
		}
	}
	if v, ok := toml_string(result.toptab, "input.keyboard_pause_binding"); ok {
		if key, valid := keyboard_shortcut_key_from_name(v); valid {settings.keyboard_pause_binding = key}
	}
	if v, ok := toml_string(result.toptab, "input.keyboard_toggle_ui_binding"); ok {
		if key, valid := keyboard_shortcut_key_from_name(v); valid {settings.keyboard_toggle_ui_binding = key}
	}
	if v, ok := toml_string(result.toptab, "input.keyboard_help_binding"); ok {
		if key, valid := keyboard_shortcut_key_from_name(v); valid {settings.keyboard_help_binding = key}
	}
	if settings.keyboard_shortcut_profile == "Standard" {
		settings.keyboard_pause_binding = .Space
		settings.keyboard_toggle_ui_binding = .Slash
		settings.keyboard_help_binding = .F1
	} else if settings.keyboard_shortcut_profile == "Letter Shortcuts" {
		settings.keyboard_pause_binding = .P
		settings.keyboard_toggle_ui_binding = .U
		settings.keyboard_help_binding = .H
	} else if !settings_keyboard_bindings_valid(settings) {
		// Malformed custom layouts fail closed to a conflict-free set while
		// retaining the Custom label so no built-in profile is misrepresented.
		settings.keyboard_pause_binding = .Space
		settings.keyboard_toggle_ui_binding = .Slash
		settings.keyboard_help_binding = .F1
	}
	if v, ok := toml_f64(result.toptab, "camera.default_sensitivity"); ok {
		settings.default_camera_sensitivity = f32(v)
	}
	if v, ok := toml_f64(result.toptab, "camera.controller_sensitivity"); ok {
		settings.controller_camera_sensitivity = min(max(f32(v), 0.1), 5.0)
	}
	if v, ok := toml_bool(result.toptab, "camera.controller_invert_y"); ok {
		settings.controller_camera_invert_y = v
	}
	if v, ok := toml_string(result.toptab, "camera.preferred_device"); ok {
		if cloned, aerr := strings.clone(v); aerr == nil {settings.preferred_camera = cloned}
	}
	if v, ok := toml_f64(result.toptab, "gpu.memory_ceiling_fraction"); ok {
		settings.gpu_memory_ceiling_fraction = f32(v)
	}
	if v, ok := toml_string(result.toptab, "presets.directory"); ok {
		cloned, aerr := strings.clone(v)
		if aerr == nil {
			settings.preset_directory = cloned
		}
	}
	if v, ok := toml_bool(result.toptab, "steam.enabled"); ok {
		settings.steam_enabled = v
	}
	if v, ok := toml_i64(result.toptab, "steam.app_id"); ok {
		settings.steam_app_id = u32(max(min(v, 4294967295), 0))
	}
	if v, ok := toml_bool(result.toptab, "steam.restart_if_necessary"); ok {
		settings.steam_restart_if_necessary = v
	}
	if v, ok := toml_string(result.toptab, "steam.library_path"); ok {
		cloned, aerr := strings.clone(v)
		if aerr == nil {
			settings.steam_library_path = cloned
		}
	}
	return settings, true
}

settings_save_app :: proc(path: string, settings: App_Settings) -> bool {
	dir, _ := filepath.split(path)
	if len(dir) > 0 {
		_ = os.make_directory_all(dir)
	}
	buf: [1536]u8
	text := fmt.bprintf(
		buf[:],
		"[display]\nfps_limit_enabled = %v\nfps_limit = %d\nui_scale = %.2f\ntexture_filtering = \"%s\"\n\n[window]\nwidth = %d\nheight = %d\nmaximized = %v\n\n[ui]\nauto_hide_delay = %d\nmenu_position = \"%s\"\nremember_controller_focus = %v\n\n[input]\ncontroller_deadzone = %.2f\ncontroller_cursor_speed = %.2f\nnavigation_repeat_delay_ms = %d\nnavigation_repeat_interval_ms = %d\ncontroller_face_layout = \"%s\"\ncontroller_menu_layout = \"%s\"\ncontroller_shoulder_layout = \"%s\"\ncontroller_trigger_layout = \"%s\"\nkeyboard_shortcut_profile = \"%s\"\nkeyboard_pause_binding = \"%s\"\nkeyboard_toggle_ui_binding = \"%s\"\nkeyboard_help_binding = \"%s\"\n\n[camera]\ndefault_sensitivity = %.2f\ncontroller_sensitivity = %.2f\ncontroller_invert_y = %v\npreferred_device = \"%s\"\n\n[gpu]\nmemory_ceiling_fraction = %.3f\n\n[presets]\ndirectory = \"%s\"\n\n[steam]\nenabled = %v\napp_id = %d\nrestart_if_necessary = %v\nlibrary_path = \"%s\"\n",
		settings.default_fps_limit_enabled,
		settings.default_fps_limit,
		settings.ui_scale,
		settings.texture_filtering,
		settings.window_width,
		settings.window_height,
		settings.window_maximized,
		settings.auto_hide_delay,
		settings.menu_position,
		settings.remember_controller_focus,
		settings.controller_deadzone,
		settings.controller_cursor_speed,
		settings.navigation_repeat_delay_ms,
		settings.navigation_repeat_interval_ms,
		settings.controller_face_layout,
		settings.controller_menu_layout,
		settings.controller_shoulder_layout,
		settings.controller_trigger_layout,
		settings.keyboard_shortcut_profile,
		keyboard_shortcut_key_name(settings.keyboard_pause_binding),
		keyboard_shortcut_key_name(settings.keyboard_toggle_ui_binding),
		keyboard_shortcut_key_name(settings.keyboard_help_binding),
		settings.default_camera_sensitivity,
		settings.controller_camera_sensitivity,
		settings.controller_camera_invert_y,
		settings.preferred_camera,
		settings.gpu_memory_ceiling_fraction,
		settings.preset_directory,
		settings.steam_enabled,
		settings.steam_app_id,
		settings.steam_restart_if_necessary,
		settings.steam_library_path,
	)
	return os.write_entire_file(path, text) == nil
}
