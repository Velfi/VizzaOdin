package main

import game "../packages/game"
import host "../packages/app"
import uifw "zelda_engine:ui"

import "core:testing"

input_preferences_has_label :: proc(ctx: ^uifw.Gui_Context, expected: string) -> bool {
	separator := -1
	for ch, index in transmute([]u8)expected {
		if ch == ':' {separator = index; break}
	}
	label_found := false
	value_found := separator < 0
	for command in ctx.commands {
		if command.kind != .Text do continue
		if command.text == expected do return true
		if separator > 0 && command.text == expected[:separator] do label_found = true
		if separator > 0 {
			value := expected[separator + 1:]
			for len(value) > 0 && value[0] == ' ' do value = value[1:]
			if command.text == value do value_found = true
		}
	}
	return label_found && value_found
}
import sdl "vendor:sdl3"

@(test)
test_controller_prompt_style_detects_supported_families :: proc(t: ^testing.T) {
	testing.expect_value(t, host.app_controller_prompt_style_for(.XBOXONE, "Xbox Wireless Controller"), uifw.Controller_Prompt_Style.Xbox)
	testing.expect_value(t, host.app_controller_prompt_style_for(.PS4, "DUALSHOCK 4"), uifw.Controller_Prompt_Style.PlayStation)
	testing.expect_value(t, host.app_controller_prompt_style_for(.PS5, "DualSense Wireless Controller"), uifw.Controller_Prompt_Style.PlayStation)
	// Steam Deck can present an Xbox-shaped SDL mapping, so its name wins.
	testing.expect_value(t, host.app_controller_prompt_style_for(.XBOX360, "Steam Deck"), uifw.Controller_Prompt_Style.Steam_Deck)
	testing.expect_value(t, host.app_controller_prompt_style_for(sdl.GamepadType.STANDARD, "Unknown Pad"), uifw.Controller_Prompt_Style.Xbox)
}

@(test)
test_app_input_preferences_override_defaults_and_clamp :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	testing.expect_value(t, host.app_controller_deadzone(app), host.INPUT_CONTROLLER_DEADZONE)
	testing.expect_value(t, host.app_controller_cursor_speed(app), host.INPUT_CONTROLLER_CURSOR_SPEED)
	testing.expect_value(t, host.app_navigation_repeat_delay(app), game.INPUT_ACTION_REPEAT_DELAY)
	testing.expect_value(t, host.app_navigation_repeat_interval(app), game.INPUT_ACTION_REPEAT_INTERVAL)

	app.settings.controller_deadzone = 0.18
	app.settings.controller_cursor_speed = 1.25
	app.settings.navigation_repeat_delay_ms = 425
	app.settings.navigation_repeat_interval_ms = 120
	testing.expect_value(t, host.app_controller_deadzone(app), f32(0.18))
	testing.expect_value(t, host.app_controller_cursor_speed(app), f32(1.25))
	testing.expect_value(t, host.app_navigation_repeat_delay(app), f32(0.425))
	testing.expect_value(t, host.app_navigation_repeat_interval(app), f32(0.12))

	app.settings.controller_deadzone = 0.99
	app.settings.controller_cursor_speed = 99
	app.settings.navigation_repeat_delay_ms = 5000
	app.settings.navigation_repeat_interval_ms = 1
	testing.expect_value(t, host.app_controller_deadzone(app), f32(0.60))
	testing.expect_value(t, host.app_controller_cursor_speed(app), f32(2.0))
	testing.expect_value(t, host.app_navigation_repeat_delay(app), f32(1.0))
	testing.expect_value(t, host.app_navigation_repeat_interval(app), f32(0.03))
}

@(test)
test_app_navigation_repeat_uses_configured_timing :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	app.settings.navigation_repeat_delay_ms = 200
	app.settings.navigation_repeat_interval_ms = 75
	app.controller_dpad_x = 1

	initial := host.app_resolve_input_actions(app, 0)
	testing.expect_value(t, initial.navigate.pressed.x, f32(1))
	waiting := host.app_resolve_input_actions(app, 0.19)
	testing.expect_value(t, waiting.navigate.repeated.x, f32(0))
	repeated := host.app_resolve_input_actions(app, 0.02)
	testing.expect_value(t, repeated.navigate.repeated.x, f32(1))
}

@(test)
test_options_input_section_exposes_all_input_preferences :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)
	worker: host.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 520, 320}, .Column, 8, 44)
	game.app_ui_draw_options_input(&ui, &ctx, &worker)
	uifw.gui_layout_end(&ctx)

	expected := [?]string{
		"Keyboard Shortcuts: Standard",
		"Pause: Space",
		"Toggle UI: Slash",
		"Help: F1",
		"Stick Deadzone: 0.25",
		"Virtual Cursor Speed: 0.72",
		"Repeat Delay: 350 ms",
		"Repeat Interval: 90 ms",
		"Accept / Back Layout: South Accept",
		"Menu Buttons: Start Pauses",
		"Shoulders: Right Next",
	}
	for label in expected {
		testing.expect(t, input_preferences_has_label(&ctx, label))
	}
}

@(test)
test_options_camera_section_exposes_device_specific_tuning :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)
	worker: host.Render_Worker_State
	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 520, 240}, .Column, 8, 44)
	game.app_ui_draw_options_camera(&ui, &ctx, &worker)
	uifw.gui_layout_end(&ctx)
	expected := [?]string{"View Controls", "Keyboard / Wheel Sensitivity: 1.0", "Controller Sensitivity: 1.0", "Invert Controller Y"}
	for label in expected {
		testing.expect(t, input_preferences_has_label(&ctx, label))
	}
}
