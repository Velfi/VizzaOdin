package main

import game "../packages/game"

import "core:os"
import "core:strconv"
import "core:strings"

main :: proc() {
	mcp_enabled := false
	theme_preview := false
	steam_override := game.Steam_Enabled_Override.Config
	steam_app_id_override: u32
	steam_library_path_override := ""

	i := 1
	for i < len(os.args) {
		arg := os.args[i]
		if arg == "--mcp" {
			mcp_enabled = true
		} else if arg == "--theme-preview" {
			theme_preview = true
		} else if arg == "--steam" {
			steam_override = .Enabled
		} else if arg == "--no-steam" || arg == "--no-platform-services" {
			steam_override = .Disabled
		} else if strings.has_prefix(arg, "--steam-app-id=") {
			if app_id, ok := parse_u32_cli(arg[len("--steam-app-id="):]); ok {
				steam_app_id_override = app_id
			}
		} else if arg == "--steam-app-id" && i + 1 < len(os.args) {
			i += 1
			if app_id, ok := parse_u32_cli(os.args[i]); ok {
				steam_app_id_override = app_id
			}
		} else if strings.has_prefix(arg, "--steam-library=") {
			steam_library_path_override = arg[len("--steam-library="):]
		} else if strings.has_prefix(arg, "--steam-lib=") {
			steam_library_path_override = arg[len("--steam-lib="):]
		} else if (arg == "--steam-library" || arg == "--steam-lib") && i + 1 < len(os.args) {
			i += 1
			steam_library_path_override = os.args[i]
		}
		i += 1
	}
	os.exit(
		game.app_run(
			game.App_Run_Config {
				mcp_enabled = mcp_enabled,
				theme_preview = theme_preview,
				steam_override = steam_override,
				steam_app_id_override = steam_app_id_override,
				steam_library_path_override = steam_library_path_override,
			},
		),
	)
}

parse_u32_cli :: proc(value: string) -> (u32, bool) {
	parsed, ok := strconv.parse_uint(value)
	if !ok || parsed > uint(0xffffffff) {
		return 0, false
	}
	return u32(parsed), true
}
