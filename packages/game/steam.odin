package game

import engine "../engine"

import "core:dynlib"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"

STEAM_DEFAULT_ENABLED :: #config(VIZZA_STEAM_DEFAULT_ENABLED, false)
STEAM_DEFAULT_APP_ID :: u32(#config(VIZZA_STEAM_APP_ID, 0))
STEAM_DEFAULT_RESTART_IF_NECESSARY :: #config(VIZZA_STEAM_RESTART_IF_NECESSARY, false)
STEAM_ERR_MSG_CAP :: 1024

Steam_Enabled_Override :: enum {
	Config,
	Enabled,
	Disabled,
}

Steam_Client_State :: enum {
	Disabled,
	Available,
	Restart_Requested,
	Missing_Library,
	Missing_Symbols,
	Init_Failed,
}

Steam_API_Init_Result :: enum i32 {
	OK = 0,
	Failed_Generic = 1,
	No_Steam_Client = 2,
	Version_Mismatch = 3,
}

Steam_API_Symbols :: struct {
	InitFlat: proc "c" (err_msg: rawptr) -> Steam_API_Init_Result `dynlib:"SteamAPI_InitFlat"`,
	Shutdown: proc "c" () `dynlib:"SteamAPI_Shutdown"`,
	RunCallbacks: proc "c" () `dynlib:"SteamAPI_RunCallbacks"`,
	RestartAppIfNecessary: proc "c" (app_id: u32) -> bool `dynlib:"SteamAPI_RestartAppIfNecessary"`,
	SteamUser: proc "c" () -> rawptr `dynlib:"SteamAPI_SteamUser_v023"`,
	ISteamUser_BLoggedOn: proc "c" (user: rawptr) -> bool `dynlib:"SteamAPI_ISteamUser_BLoggedOn"`,
	ISteamUser_GetSteamID: proc "c" (user: rawptr) -> u64 `dynlib:"SteamAPI_ISteamUser_GetSteamID"`,
	SteamFriends: proc "c" () -> rawptr `dynlib:"SteamAPI_SteamFriends_v018"`,
	ISteamFriends_GetPersonaName: proc "c" (friends: rawptr) -> cstring `dynlib:"SteamAPI_ISteamFriends_GetPersonaName"`,
	__handle: dynlib.Library,
}

Steam_Config :: struct {
	enabled: bool,
	app_id: u32,
	restart_if_necessary: bool,
	library_path: string,
}

Steam_Client :: struct {
	state: Steam_Client_State,
	api: Steam_API_Symbols,
	initialized: bool,
}

steam_config_resolve :: proc(settings: App_Settings, run_config: App_Run_Config) -> Steam_Config {
	config := Steam_Config {
		enabled = settings.steam_enabled,
		app_id = settings.steam_app_id,
		restart_if_necessary = settings.steam_restart_if_necessary,
		library_path = settings.steam_library_path,
	}

	env_buf: [512]u8
	if value := os.get_env_buf(env_buf[:], "VIZZA_STEAM_ENABLED"); len(value) > 0 {
		if enabled, ok := steam_parse_bool(value); ok {
			config.enabled = enabled
		}
	}
	if value := os.get_env_buf(env_buf[:], "VIZZA_STEAM_APP_ID"); len(value) > 0 {
		if app_id, ok := steam_parse_u32(value); ok {
			config.app_id = app_id
		}
	}
	if value := os.get_env_buf(env_buf[:], "VIZZA_STEAM_RESTART_IF_NECESSARY"); len(value) > 0 {
		if restart, ok := steam_parse_bool(value); ok {
			config.restart_if_necessary = restart
		}
	}
	if value := os.get_env_buf(env_buf[:], "VIZZA_STEAM_LIBRARY"); len(value) > 0 {
		config.library_path = value
	}

	switch run_config.steam_override {
	case .Enabled:
		config.enabled = true
	case .Disabled:
		config.enabled = false
	case .Config:
	}
	if run_config.steam_app_id_override != 0 {
		config.app_id = run_config.steam_app_id_override
	}
	if len(run_config.steam_library_path_override) > 0 {
		config.library_path = run_config.steam_library_path_override
	}
	return config
}

steam_client_init :: proc(client: ^Steam_Client, config: Steam_Config) -> Steam_Client_State {
	client^ = {}
	if !config.enabled {
		client.state = .Disabled
		return client.state
	}

	loaded_path := ""
	if !steam_load_api(&client.api, config.library_path, &loaded_path) {
		client.state = .Missing_Library
		engine.log_warn("Steam enabled but ", steam_library_filename(), " could not be loaded; SteamAPI disabled")
		return client.state
	}

	if !steam_required_symbols_loaded(&client.api) {
		steam_unload_api(&client.api)
		client.state = .Missing_Symbols
		engine.log_warn("Steam enabled but required SteamAPI flat symbols are missing in ", loaded_path)
		return client.state
	}

	if config.restart_if_necessary && config.app_id != 0 && client.api.RestartAppIfNecessary(config.app_id) {
		steam_unload_api(&client.api)
		client.state = .Restart_Requested
		engine.log_info("Steam requested relaunch through the Steam client; exiting this process")
		return client.state
	}

	err_msg: [STEAM_ERR_MSG_CAP]u8
	result := client.api.InitFlat(rawptr(&err_msg[0]))
	if result != .OK {
		client.state = .Init_Failed
		reason := strings.string_from_null_terminated_ptr(raw_data(err_msg[:]), len(err_msg))
		if len(reason) > 0 {
			engine.log_warn("Steam init failed (", result, "): ", reason)
		} else {
			engine.log_warn("Steam init failed: ", result)
		}
		steam_unload_api(&client.api)
		return client.state
	}

	client.initialized = true
	client.state = .Available
	steam_log_connected(client, config.app_id, loaded_path)
	return client.state
}

steam_client_tick :: proc(client: ^Steam_Client) {
	if client == nil || !client.initialized || client.api.RunCallbacks == nil {
		return
	}
	client.api.RunCallbacks()
}

steam_client_shutdown :: proc(client: ^Steam_Client) {
	if client == nil {
		return
	}
	if client.initialized && client.api.Shutdown != nil {
		client.api.Shutdown()
	}
	steam_unload_api(&client.api)
	client^ = {}
}

steam_log_connected :: proc(client: ^Steam_Client, app_id: u32, loaded_path: string) {
	user := client.api.SteamUser()
	steam_id: u64
	logged_on := false
	if user != nil {
		logged_on = client.api.ISteamUser_BLoggedOn(user)
		if logged_on {
			steam_id = client.api.ISteamUser_GetSteamID(user)
		}
	}

	persona := ""
	friends := client.api.SteamFriends()
	if friends != nil {
		if name := client.api.ISteamFriends_GetPersonaName(friends); name != nil {
			persona = string(name)
		}
	}

	if app_id != 0 {
		engine.log_info("Steam connected: user='", persona, "' steam_id=", steam_id, " logged_on=", logged_on, " app_id=", app_id, " lib=", loaded_path)
	} else {
		engine.log_info("Steam connected: user='", persona, "' steam_id=", steam_id, " logged_on=", logged_on, " lib=", loaded_path)
	}
}

steam_load_api :: proc(api: ^Steam_API_Symbols, override_path: string, loaded_path: ^string) -> bool {
	if len(override_path) > 0 {
		return steam_try_load_api_path(api, override_path, loaded_path)
	}

	name := steam_library_filename()
	if len(name) == 0 {
		return false
	}
	if steam_try_load_api_path(api, name, loaded_path) {
		return true
	}

	relative, rel_err := filepath.join({".", name}, context.temp_allocator)
	if rel_err == nil && steam_try_load_api_path(api, relative, loaded_path) {
		return true
	}

	if exe_dir, exe_err := os.get_executable_directory(context.temp_allocator); exe_err == nil {
		if exe_path, join_err := filepath.join({exe_dir, name}, context.temp_allocator); join_err == nil && steam_try_load_api_path(api, exe_path, loaded_path) {
			return true
		}
		when ODIN_OS == .Darwin {
			if frameworks_path, join_err := filepath.join({exe_dir, "..", "Frameworks", name}, context.temp_allocator); join_err == nil && steam_try_load_api_path(api, frameworks_path, loaded_path) {
				return true
			}
		}
	}

	return false
}

steam_try_load_api_path :: proc(api: ^Steam_API_Symbols, path: string, loaded_path: ^string) -> bool {
	api^ = {}
	count, ok := dynlib.initialize_symbols(api, path, "", "__handle")
	if !ok || count <= 0 {
		steam_unload_api(api)
		return false
	}
	if loaded_path != nil {
		loaded_path^ = path
	}
	return true
}

steam_unload_api :: proc(api: ^Steam_API_Symbols) {
	if api != nil && api.__handle != nil {
		_ = dynlib.unload_library(api.__handle)
	}
	if api != nil {
		api^ = {}
	}
}

steam_required_symbols_loaded :: proc(api: ^Steam_API_Symbols) -> bool {
	return api.InitFlat != nil &&
		api.Shutdown != nil &&
		api.RunCallbacks != nil &&
		api.RestartAppIfNecessary != nil &&
		api.SteamUser != nil &&
		api.ISteamUser_BLoggedOn != nil &&
		api.ISteamUser_GetSteamID != nil &&
		api.SteamFriends != nil &&
		api.ISteamFriends_GetPersonaName != nil
}

steam_library_filename :: proc() -> string {
	when ODIN_OS == .Darwin {
		return "libsteam_api.dylib"
	} else when ODIN_OS == .Linux {
		return "libsteam_api.so"
	} else when ODIN_OS == .Windows {
		when ODIN_ARCH == .i386 {
			return "steam_api.dll"
		} else {
			return "steam_api64.dll"
		}
	} else {
		return ""
	}
}

steam_parse_bool :: proc(value: string) -> (bool, bool) {
	switch value {
	case "1", "true", "TRUE", "True", "yes", "YES", "Yes", "on", "ON", "On", "enabled", "ENABLED", "Enabled":
		return true, true
	case "0", "false", "FALSE", "False", "no", "NO", "No", "off", "OFF", "Off", "disabled", "DISABLED", "Disabled":
		return false, true
	}
	return false, false
}

steam_parse_u32 :: proc(value: string) -> (u32, bool) {
	parsed, ok := strconv.parse_uint(value)
	if !ok || parsed > uint(0xffffffff) {
		return 0, false
	}
	return u32(parsed), true
}
