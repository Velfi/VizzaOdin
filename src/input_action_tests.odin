package main

import game "../packages/game"
import host "../packages/app"
import uifw "../packages/ui"

import "core:math"
import "core:testing"
import sdl "vendor:sdl3"

input_action_test_approx :: proc(a, b: f32) -> bool {
	return math.abs(a - b) <= 0.001
}

@(test)
test_input_action_button_has_explicit_press_hold_release_phases :: proc(t: ^testing.T) {
	state: game.Input_Action_Button_Resolver

	pressed := game.input_action_resolve_button(&state, {
		mouse_keyboard_down = true,
		mouse_keyboard_pressed = true,
	})
	testing.expect(t, pressed.down)
	testing.expect(t, pressed.pressed)
	testing.expect(t, !pressed.repeated)
	testing.expect(t, !pressed.released)
	testing.expect_value(t, pressed.owner, game.Input_Action_Source.Mouse_Keyboard)

	held := game.input_action_resolve_button(&state, {mouse_keyboard_down = true})
	testing.expect(t, held.down)
	testing.expect(t, !held.pressed)
	testing.expect(t, !held.released)
	testing.expect_value(t, held.owner, game.Input_Action_Source.Mouse_Keyboard)

	released := game.input_action_resolve_button(&state, {})
	testing.expect(t, !released.down)
	testing.expect(t, !released.pressed)
	testing.expect(t, released.released)
	testing.expect_value(t, released.owner, game.Input_Action_Source.Mouse_Keyboard)
}

@(test)
test_input_action_fast_tap_preserves_press_and_release :: proc(t: ^testing.T) {
	state: game.Input_Action_Button_Resolver
	action := game.input_action_resolve_button(&state, {
		controller_pressed = true,
	})

	testing.expect(t, !action.down)
	testing.expect(t, action.pressed)
	testing.expect(t, action.released)
	testing.expect_value(t, action.owner, game.Input_Action_Source.Controller)
}

@(test)
test_input_action_owner_does_not_switch_mid_hold :: proc(t: ^testing.T) {
	state: game.Input_Action_Button_Resolver
	_ = game.input_action_resolve_button(&state, {
		mouse_keyboard_down = true,
		mouse_keyboard_pressed = true,
	})

	second_source := game.input_action_resolve_button(&state, {
		mouse_keyboard_down = true,
		controller_down = true,
		controller_pressed = true,
	})
	testing.expect(t, !second_source.pressed)
	testing.expect_value(t, second_source.owner, game.Input_Action_Source.Mouse_Keyboard)

	first_source_released := game.input_action_resolve_button(&state, {
		controller_down = true,
	})
	testing.expect(t, first_source_released.down)
	testing.expect(t, !first_source_released.released)
	testing.expect_value(t, first_source_released.owner, game.Input_Action_Source.Mouse_Keyboard)

	all_released := game.input_action_resolve_button(&state, {})
	testing.expect(t, all_released.released)
	testing.expect_value(t, all_released.owner, game.Input_Action_Source.Mouse_Keyboard)
}

@(test)
test_input_action_other_source_fast_tap_cannot_retrigger_held_action :: proc(t: ^testing.T) {
	state: game.Input_Action_Button_Resolver
	first := game.input_action_resolve_button(&state, {
		mouse_keyboard_down = true,
		mouse_keyboard_pressed = true,
	})
	testing.expect(t, first.pressed)
	testing.expect_value(t, first.owner, game.Input_Action_Source.Mouse_Keyboard)

	controller_tap := game.input_action_resolve_button(&state, {
		mouse_keyboard_down = true,
		controller_pressed = true,
		controller_released = true,
	})
	testing.expect(t, controller_tap.down)
	testing.expect(t, !controller_tap.pressed)
	testing.expect(t, !controller_tap.released)
	testing.expect_value(t, controller_tap.owner, game.Input_Action_Source.Mouse_Keyboard)

	keyboard_release := game.input_action_resolve_button(&state, {
		mouse_keyboard_released = true,
	})
	testing.expect(t, keyboard_release.released)
	testing.expect_value(t, keyboard_release.owner, game.Input_Action_Source.Mouse_Keyboard)
}

@(test)
test_input_action_held_back_only_presses_once :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	app.controller_back_down = true
	app.input.back = true

	first := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, first.back.pressed)
	testing.expect(t, first.back.down)

	app.input.back = false
	second := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, !second.back.pressed)
	testing.expect(t, second.back.down)

	app.controller_back_down = false
	third := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, third.back.released)
}

@(test)
test_space_resolves_distinct_pause_and_control_deck_actions :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	host.app_apply_key_event(app, sdl.K_SPACE, .SPACE, true)
	pressed := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, pressed.pause.pressed)
	testing.expect(t, pressed.control_deck.pressed)
	testing.expect_value(t, pressed.pause.owner, game.Input_Action_Source.Mouse_Keyboard)
	testing.expect_value(t, pressed.control_deck.owner, game.Input_Action_Source.Mouse_Keyboard)

	app.input.key_space = false
	app.input.key_space_pressed = false
	app.keyboard_action_released = {}
	host.app_apply_key_event(app, sdl.K_SPACE, .SPACE, false)
	released := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, released.pause.released)
	testing.expect(t, released.control_deck.released)
}

@(test)
test_letter_shortcut_profile_routes_pause_ui_and_help_semantically :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	app.settings = game.settings_default()
	game.settings_apply_keyboard_profile(&app.settings, "Letter Shortcuts")

	host.app_apply_key_event(app, sdl.K_P, .P, true)
	pause := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, pause.pause.pressed)
	testing.expect(t, !pause.control_deck.pressed)
	testing.expect_value(t, pause.pause.owner, game.Input_Action_Source.Mouse_Keyboard)
	host.app_apply_key_event(app, sdl.K_P, .P, false)

	app.input.pause = false
	app.keyboard_action_released = {}
	host.app_apply_key_event(app, sdl.K_SPACE, .SPACE, true)
	space := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, !space.pause.pressed)
	testing.expect(t, space.control_deck.pressed)
	host.app_apply_key_event(app, sdl.K_SPACE, .SPACE, false)

	app.input.toggle_ui = false
	app.keyboard_action_released = {}
	host.app_apply_key_event(app, sdl.K_U, .U, true)
	toggle := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, toggle.toggle_ui.pressed)
	testing.expect_value(t, toggle.toggle_ui.owner, game.Input_Action_Source.Mouse_Keyboard)
	host.app_apply_key_event(app, sdl.K_U, .U, false)

	app.input.key_f1 = false
	host.app_apply_key_event(app, sdl.K_H, .H, true)
	testing.expect(t, app.input.key_f1)
	app.input.key_f1 = false
	host.app_apply_key_event(app, sdl.K_F1, .F1, true)
	testing.expect(t, !app.input.key_f1)
}

@(test)
test_custom_keyboard_bindings_route_effective_actions :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	app.settings = game.settings_default()
	_, _ = game.settings_assign_keyboard_binding(&app.settings, .Pause, .H)
	_, _ = game.settings_assign_keyboard_binding(&app.settings, .Toggle_Ui, .P)
	_, _ = game.settings_assign_keyboard_binding(&app.settings, .Help, .U)

	host.app_apply_key_event(app, sdl.K_H, .H, true)
	actions := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, actions.pause.pressed)
	host.app_apply_key_event(app, sdl.K_H, .H, false)
	app.input.pause = false
	app.keyboard_action_released = {}
	host.app_apply_key_event(app, sdl.K_P, .P, true)
	actions = host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, actions.toggle_ui.pressed)
	host.app_apply_key_event(app, sdl.K_U, .U, true)
	testing.expect(t, app.input.key_f1)
	actions = host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, actions.help.pressed)
	testing.expect_value(t, actions.help.owner, game.Input_Action_Source.Mouse_Keyboard)
}

@(test)
test_controller_guide_resolves_semantic_help_and_preserves_fast_tap :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	host.app_apply_gamepad_button(app, .GUIDE, true)
	host.app_apply_gamepad_button(app, .GUIDE, false)
	actions := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, actions.help.pressed)
	testing.expect(t, actions.help.released)
	testing.expect(t, !actions.help.down)
	testing.expect_value(t, actions.help.owner, game.Input_Action_Source.Controller)
}

@(test)
test_controller_menu_layout_maps_start_view_and_preserves_multiple_contributors :: proc(t: ^testing.T) {
	standard := new(host.App_State)
	defer free(standard)
	standard.settings = game.settings_default()
	host.app_apply_gamepad_button(standard, .START, true)
	testing.expect(t, standard.controller_pause_down)
	testing.expect(t, !standard.controller_toggle_ui_down)
	host.app_apply_gamepad_button(standard, .BACK, true)
	testing.expect(t, standard.controller_pause_down)
	testing.expect(t, standard.controller_toggle_ui_down)
	host.app_apply_gamepad_button(standard, .NORTH, true)
	host.app_apply_gamepad_button(standard, .BACK, false)
	testing.expect(t, standard.controller_toggle_ui_down)
	testing.expect(t, !standard.controller_action_released.toggle_ui)

	alternate := new(host.App_State)
	defer free(alternate)
	alternate.settings = game.settings_default()
	alternate.settings.controller_menu_layout = "View Pauses"
	host.app_apply_gamepad_button(alternate, .BACK, true)
	host.app_apply_gamepad_button(alternate, .BACK, false)
	actions := host.app_resolve_input_actions(alternate, 1.0 / 60.0)
	testing.expect(t, actions.pause.pressed)
	testing.expect(t, actions.pause.released)
	testing.expect_value(t, actions.pause.owner, game.Input_Action_Source.Controller)
	host.app_apply_gamepad_button(alternate, .START, true)
	testing.expect(t, alternate.controller_toggle_ui_down)
	testing.expect(t, !alternate.controller_pause_down)
}

@(test)
test_controller_menu_layout_change_releases_held_semantic_actions :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	app.settings = game.settings_default()
	host.app_apply_gamepad_button(app, .START, true)
	_ = host.app_resolve_input_actions(app, 1.0 / 60.0)
	changed := app.settings
	changed.controller_menu_layout = "View Pauses"
	host.app_apply_settings(app, changed)
	testing.expect(t, !app.controller_pause_down)
	testing.expect(t, !app.controller_start_down)
	released := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, released.pause.released)
	testing.expect(t, !released.pause.down)
}

@(test)
test_controller_shoulder_layout_swaps_semantic_focus_direction :: proc(t: ^testing.T) {
	standard := new(host.App_State)
	defer free(standard)
	standard.settings = game.settings_default()
	host.app_apply_gamepad_button(standard, .RIGHT_SHOULDER, true)
	actions := host.app_resolve_input_actions(standard, 1.0 / 60.0)
	testing.expect(t, actions.focus_next.pressed)
	testing.expect(t, !actions.focus_prev.pressed)
	host.app_apply_gamepad_button(standard, .RIGHT_SHOULDER, false)

	alternate := new(host.App_State)
	defer free(alternate)
	alternate.settings = game.settings_default()
	alternate.settings.controller_shoulder_layout = "Left Next"
	host.app_apply_gamepad_button(alternate, .LEFT_SHOULDER, true)
	actions = host.app_resolve_input_actions(alternate, 1.0 / 60.0)
	testing.expect(t, actions.focus_next.pressed)
	testing.expect(t, !actions.focus_prev.pressed)
	host.app_apply_gamepad_button(alternate, .RIGHT_SHOULDER, true)
	actions = host.app_resolve_input_actions(alternate, 1.0 / 60.0)
	testing.expect(t, actions.focus_prev.pressed)
}

@(test)
test_controller_shoulder_layout_change_releases_held_focus :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	app.settings = game.settings_default()
	host.app_apply_gamepad_button(app, .RIGHT_SHOULDER, true)
	_ = host.app_resolve_input_actions(app, 1.0 / 60.0)
	changed := app.settings
	changed.controller_shoulder_layout = "Left Next"
	host.app_apply_settings(app, changed)
	testing.expect(t, !app.controller_focus_next_down)
	testing.expect(t, !app.controller_right_shoulder_down)
	released := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, released.focus_next.released)
	testing.expect(t, !released.focus_next.down)
}

@(test)
test_controller_guide_opens_and_closes_help_without_reopening :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Gray_Scott
	ui.simulation_shell.show_ui = false
	ui.simulation_shell.controls_visible = false
	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720})
	guide := game.Input_Action_Button_State{pressed = true, owner = .Controller}
	_ = game.app_ui_simulation_filter_input(&ui, &ctx, {window_width = 1280, window_height = 720, help = true, actions = {help = guide}})
	testing.expect(t, ui.controls_help_open)
	_ = game.app_ui_simulation_filter_input(&ui, &ctx, {window_width = 1280, window_height = 720})
	testing.expect_value(t, ui.input_route.active_context, game.App_Input_Context.Modal)
	_ = game.app_ui_simulation_filter_input(&ui, &ctx, {window_width = 1280, window_height = 720, help = true, actions = {help = guide}})
	testing.expect(t, !ui.controls_help_open)

	ctx.text_edit_id = 42
	_ = game.app_ui_simulation_filter_input(&ui, &ctx, {window_width = 1280, window_height = 720, help = true, actions = {help = guide}})
	testing.expect(t, !ui.controls_help_open)
}

@(test)
test_keyboard_binding_conflicts_swap_or_reassign_without_duplicates :: proc(t: ^testing.T) {
	settings := game.settings_default()
	displaced, conflicted := game.settings_assign_keyboard_binding(&settings, .Pause, .Slash)
	testing.expect(t, conflicted)
	testing.expect_value(t, displaced, game.Keyboard_Shortcut_Action.Toggle_Ui)
	testing.expect_value(t, settings.keyboard_pause_binding, game.Keyboard_Shortcut_Key.Slash)
	// Toggle UI cannot inherit Pause's old Space binding, so it receives the
	// first free legal key instead.
	testing.expect_value(t, settings.keyboard_toggle_ui_binding, game.Keyboard_Shortcut_Key.P)
	testing.expect(t, game.settings_keyboard_bindings_valid(settings))

	displaced, conflicted = game.settings_assign_keyboard_binding(&settings, .Help, .P)
	testing.expect(t, conflicted)
	testing.expect_value(t, displaced, game.Keyboard_Shortcut_Action.Toggle_Ui)
	testing.expect_value(t, settings.keyboard_help_binding, game.Keyboard_Shortcut_Key.P)
	testing.expect_value(t, settings.keyboard_toggle_ui_binding, game.Keyboard_Shortcut_Key.F1)
	testing.expect(t, game.settings_keyboard_bindings_valid(settings))

	before := settings.keyboard_help_binding
	_, changed := game.settings_assign_keyboard_binding(&settings, .Help, .Space)
	testing.expect(t, !changed)
	testing.expect_value(t, settings.keyboard_help_binding, before)
}

@(test)
test_keyboard_profile_change_releases_held_semantic_shortcuts :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	app.settings = game.settings_default()
	host.app_apply_key_event(app, sdl.K_SPACE, .SPACE, true)
	pressed := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, pressed.pause.down)

	changed := app.settings
	game.settings_apply_keyboard_profile(&changed, "Letter Shortcuts")
	host.app_apply_settings(app, changed)
	testing.expect(t, !app.keyboard_pause_down)
	released := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, released.pause.released)
	testing.expect(t, !released.pause.down)
}

@(test)
test_help_remap_releases_held_help_and_discards_old_press_pulse :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	app.settings = game.settings_default()
	host.app_apply_key_event(app, sdl.K_F1, .F1, true)
	pressed := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, pressed.help.down)

	changed := app.settings
	_, _ = game.settings_assign_keyboard_binding(&changed, .Help, .H)
	host.app_apply_settings(app, changed)
	testing.expect(t, !app.keyboard_help_down)
	testing.expect(t, !app.input.key_f1)
	released := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, released.help.released)
	testing.expect(t, !released.help.pressed)
	testing.expect(t, !released.help.down)
}

@(test)
test_input_action_sources_are_not_gated_by_prompt_device :: proc(t: ^testing.T) {
	controller_while_mouse_prompts := new(host.App_State)
	defer free(controller_while_mouse_prompts)
	controller_while_mouse_prompts.active_device = .Mouse_Keyboard
	controller_while_mouse_prompts.controller_accept_down = true
	controller_while_mouse_prompts.input.accept = true
	controller_actions := host.app_resolve_input_actions(controller_while_mouse_prompts, 1.0 / 60.0)
	testing.expect(t, controller_actions.accept.pressed)
	testing.expect_value(t, controller_actions.accept.owner, game.Input_Action_Source.Controller)

	keyboard_while_controller_prompts := new(host.App_State)
	defer free(keyboard_while_controller_prompts)
	keyboard_while_controller_prompts.active_device = .Controller
	keyboard_while_controller_prompts.keyboard_back_down = true
	keyboard_while_controller_prompts.input.key_escape = true
	keyboard_actions := host.app_resolve_input_actions(keyboard_while_controller_prompts, 1.0 / 60.0)
	testing.expect(t, keyboard_actions.back.pressed)
	testing.expect_value(t, keyboard_actions.back.owner, game.Input_Action_Source.Mouse_Keyboard)
}

@(test)
test_controller_face_layout_can_swap_accept_and_back :: proc(t: ^testing.T) {
	standard := new(host.App_State)
	defer free(standard)
	standard.settings = game.settings_default()
	host.app_apply_gamepad_button(standard, .SOUTH, true)
	testing.expect(t, standard.controller_accept_down)
	testing.expect(t, !standard.controller_back_down)

	east_accept := new(host.App_State)
	defer free(east_accept)
	east_accept.settings = game.settings_default()
	east_accept.settings.controller_face_layout = "East Accept"
	host.app_apply_gamepad_button(east_accept, .EAST, true)
	testing.expect(t, east_accept.controller_accept_down)
	testing.expect(t, !east_accept.controller_back_down)
	host.app_apply_gamepad_button(east_accept, .SOUTH, true)
	testing.expect(t, east_accept.controller_back_down)
}

@(test)
test_controller_face_layout_change_releases_held_semantic_action :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	app.settings = game.settings_default()
	host.app_apply_gamepad_button(app, .SOUTH, true)
	first := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, first.accept.down)

	changed := app.settings
	changed.controller_face_layout = "East Accept"
	host.app_apply_settings(app, changed)
	testing.expect(t, !app.controller_accept_down)
	second := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, second.accept.released)
	testing.expect(t, !second.back.pressed)
}

@(test)
test_input_action_navigation_repeats_after_delay :: proc(t: ^testing.T) {
	resolver: game.Input_Action_Resolver

	initial := game.input_action_resolve_navigation(&resolver, {1, 0}, 0)
	testing.expect_value(t, initial.pressed, uifw.Vec2{1, 0})
	testing.expect_value(t, initial.repeated, uifw.Vec2{})

	waiting := game.input_action_resolve_navigation(&resolver, {1, 0}, 0.34)
	testing.expect_value(t, waiting.pressed, uifw.Vec2{})
	testing.expect_value(t, waiting.repeated, uifw.Vec2{})

	repeated := game.input_action_resolve_navigation(&resolver, {1, 0}, 0.02)
	testing.expect_value(t, repeated.repeated, uifw.Vec2{1, 0})

	between_repeats := game.input_action_resolve_navigation(&resolver, {1, 0}, 0.07)
	testing.expect_value(t, between_repeats.repeated, uifw.Vec2{})

	repeated_again := game.input_action_resolve_navigation(&resolver, {1, 0}, 0.03)
	testing.expect_value(t, repeated_again.repeated, uifw.Vec2{1, 0})

	reversed := game.input_action_resolve_navigation(&resolver, {-1, 0}, 0)
	testing.expect_value(t, reversed.pressed, uifw.Vec2{-1, 0})
}

@(test)
test_input_action_radial_deadzone_is_circular_and_rescaled :: proc(t: ^testing.T) {
	inside := game.input_action_apply_radial_deadzone({0.15, 0.15}, 0.25)
	testing.expect_value(t, inside, uifw.Vec2{})

	cardinal := game.input_action_apply_radial_deadzone({0.5, 0}, 0.25)
	testing.expect(t, input_action_test_approx(cardinal.x, 1.0 / 3.0))
	testing.expect(t, input_action_test_approx(cardinal.y, 0))

	diagonal := game.input_action_apply_radial_deadzone({0.2, 0.2}, 0.25)
	testing.expect(t, diagonal.x > 0)
	testing.expect(t, input_action_test_approx(diagonal.x, diagonal.y))
}

@(test)
test_keyboard_back_ignores_auto_repeat :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)

	host.app_apply_key_event(app, sdl.K_ESCAPE, .ESCAPE, true)
	testing.expect(t, app.input.key_escape)
	testing.expect(t, app.keyboard_back_down)

	host.app_poll_events(app)
	host.app_apply_key_event(app, sdl.K_ESCAPE, .ESCAPE, true, true)
	testing.expect(t, !app.input.key_escape)
	testing.expect(t, app.keyboard_back_down)

	host.app_apply_key_event(app, sdl.K_ESCAPE, .ESCAPE, false)
	testing.expect(t, !app.keyboard_back_down)
}

input_action_test_draw_scroll_buttons :: proc(ctx: ^uifw.Gui_Context, scroll: ^f32) {
	uifw.gui_scroll_begin(ctx, {0, 0, 180, 100}, 160, scroll)
	_ = uifw.gui_button(ctx, "First", "first")
	_ = uifw.gui_button(ctx, "Second", "second")
	_ = uifw.gui_button(ctx, "Third", "third")
	uifw.gui_scroll_end(ctx)
}

@(test)
test_gui_spatial_navigation_reveals_offscreen_scroll_item :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	scroll := f32(0)
	second := uifw.gui_make_id(&ctx, "second")
	third := uifw.gui_make_id(&ctx, "third")
	ctx.focused = second

	uifw.gui_begin_frame(&ctx, {key_down = true})
	input_action_test_draw_scroll_buttons(&ctx, &scroll)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ctx.focused, third)
	testing.expect(t, scroll > 0)
}

@(test)
test_gui_tab_navigation_reveals_offscreen_scroll_item :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	scroll := f32(0)
	second := uifw.gui_make_id(&ctx, "second")
	third := uifw.gui_make_id(&ctx, "third")
	ctx.focused = second

	uifw.gui_begin_frame(&ctx, {key_tab = true})
	input_action_test_draw_scroll_buttons(&ctx, &scroll)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ctx.focused, third)
	testing.expect(t, scroll > 0)
}

@(test)
test_gui_reverse_navigation_reveals_item_above_scroll_viewport :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	scroll := f32(60)
	first := uifw.gui_make_id(&ctx, "first")
	second := uifw.gui_make_id(&ctx, "second")
	ctx.focused = second

	uifw.gui_begin_frame(&ctx, {key_up = true})
	input_action_test_draw_scroll_buttons(&ctx, &scroll)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ctx.focused, first)
	testing.expect(t, scroll < 60)
}

@(test)
test_gui_explicit_controller_button_activates_with_one_press :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	id := uifw.gui_make_id(&ctx, "apply")
	ctx.focused = id
	ctx.controller_explicit_activation = true
	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true})
	clicked := uifw.gui_button_at(&ctx, id, {0, 0, 140, 44}, "Apply", true)

	testing.expect(t, clicked)
	testing.expect_value(t, ctx.focus_edit_id, uifw.GUI_ID_NONE)
	testing.expect_value(t, ctx.controller_armed_id, uifw.GUI_ID_NONE)
}

@(test)
test_gui_explicit_controller_toggle_changes_with_one_press :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	value := false
	id := uifw.gui_make_id(&ctx, "enabled")
	ctx.focused = id
	ctx.controller_explicit_activation = true
	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	changed := uifw.gui_toggle(&ctx, "Enabled", "enabled", &value)
	uifw.gui_layout_end(&ctx)

	testing.expect(t, changed)
	testing.expect(t, value)
	testing.expect_value(t, ctx.focus_edit_id, uifw.GUI_ID_NONE)
}

@(test)
test_slime_modal_owns_back_before_underlying_focus_scope :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = true
	ui.slime_controller.focus.phase = .Child_Region
	ui.slime_mold.preset_ui.save_open = true

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, back = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)

	testing.expect(t, ui.slime_controller.panel_open)
	testing.expect_value(t, ui.slime_controller.focus.phase, uifw.Controller_Focus_Phase.Child_Region)
}

@(test)
test_preset_modal_accepts_semantic_controller_back :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	state: game.Preset_Fieldset_State
	state.save_open = true
	state.save_open_frame = 0
	worker := new(host.Render_Worker_State)
	defer free(worker)

	uifw.gui_begin_frame(&ctx, {
		window_width = 900,
		window_height = 700,
		active_device = .Controller,
		back = true,
	})
	game.preset_save_dialog_draw(&ctx, &state, worker, "slime")

	testing.expect(t, !state.save_open)
}

@(test)
test_focus_driven_controller_ui_keeps_toggle_action_out_of_shell :: proc(t: ^testing.T) {
	controller_owned: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&controller_owned, settings)
	controller_owned.mode = .Slime_Mold
	controller_owned.simulation_shell.show_ui = false
	game.app_ui_simulation_shell_update(&controller_owned, {
		active_device = .Mouse_Keyboard,
		toggle_ui = true,
		actions = {
			toggle_ui = {
				pressed = true,
				owner = .Controller,
			},
		},
	})
	testing.expect(t, !controller_owned.simulation_shell.show_ui)

	keyboard_owned: game.App_Ui_State
	game.app_ui_init(&keyboard_owned, settings)
	keyboard_owned.mode = .Slime_Mold
	keyboard_owned.simulation_shell.show_ui = false
	game.app_ui_simulation_shell_update(&keyboard_owned, {
		active_device = .Controller,
		toggle_ui = true,
		actions = {
			toggle_ui = {
				pressed = true,
				owner = .Mouse_Keyboard,
			},
		},
	})
	testing.expect(t, !keyboard_owned.simulation_shell.show_ui)
}

@(test)
test_focused_controller_ui_blocks_controller_camera_even_with_mouse_prompts :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.focus.phase = .Region

	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1280,
		window_height = 720,
		active_device = .Mouse_Keyboard,
		controller_left = {0.8, -0.5},
		controller_zoom = 0.7,
		camera_reset = true,
	})

	testing.expect_value(t, filtered.controller_left, uifw.Vec2{})
	testing.expect_value(t, filtered.controller_zoom, f32(0))
	testing.expect(t, !filtered.camera_reset)
}

@(test)
test_gui_tab_navigation_wraps_inside_current_focus_group :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	panel_first := uifw.gui_make_id(&ctx, "panel_first")
	panel_second := uifw.gui_make_id(&ctx, "panel_second")
	deck_item := uifw.gui_make_id(&ctx, "deck_item")
	ctx.focused = panel_second

	uifw.gui_begin_frame(&ctx, {key_tab = true})
	uifw.gui_spatial_group_begin(&ctx, "panel")
	_ = uifw.gui_button_at(&ctx, panel_first, {0, 0, 100, 40}, "First", true)
	_ = uifw.gui_button_at(&ctx, panel_second, {0, 50, 100, 40}, "Second", true)
	uifw.gui_spatial_group_end(&ctx)
	uifw.gui_spatial_group_begin(&ctx, "deck")
	_ = uifw.gui_button_at(&ctx, deck_item, {120, 0, 100, 40}, "Deck", true)
	uifw.gui_spatial_group_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ctx.focused, panel_first)
	testing.expect(t, ctx.focused != deck_item)
}

@(test)
test_preset_modal_traps_focus_and_restores_invoker :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	invoker := uifw.gui_make_id(&ctx, "save_invoker")
	state: game.Preset_Fieldset_State
	state.save_open = true
	state.save_open_frame = 0
	state.save_invoker_focus = invoker
	worker := new(host.Render_Worker_State)
	defer free(worker)
	ctx.focused = invoker

	uifw.gui_begin_frame(&ctx, {window_width = 900, window_height = 700})
	_ = uifw.gui_button_at(&ctx, invoker, {0, 0, 120, 44}, "Invoker", true)
	game.preset_save_dialog_draw(&ctx, &state, worker, "slime")
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ctx.focus_scope_active)
	testing.expect(t, ctx.focused != invoker)
	modal_focus := ctx.focused
	modal_scope := ctx.focus_scope
	found_in_scope := false
	for i in 0 ..< ctx.spatial_item_count {
		item := ctx.spatial_items[i]
		if item.id == modal_focus && item.group == modal_scope {
			found_in_scope = true
			break
		}
	}
	testing.expect(t, found_in_scope)

	uifw.gui_begin_frame(&ctx, {window_width = 900, window_height = 700, key_tab = true})
	_ = uifw.gui_button_at(&ctx, invoker, {0, 0, 120, 44}, "Invoker", true)
	game.preset_save_dialog_draw(&ctx, &state, worker, "slime")
	uifw.gui_end_frame(&ctx)
	testing.expect(t, ctx.focused != invoker)

	uifw.gui_begin_frame(&ctx, {window_width = 900, window_height = 700, back = true})
	_ = uifw.gui_button_at(&ctx, invoker, {0, 0, 120, 44}, "Invoker", true)
	game.preset_save_dialog_draw(&ctx, &state, worker, "slime")
	uifw.gui_end_frame(&ctx)

	testing.expect(t, !state.save_open)
	testing.expect_value(t, ctx.focused, invoker)
	testing.expect_value(t, ctx.overlay_input_rect_count, 0)
}

@(test)
test_gui_controller_number_edit_back_restores_snapshot :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.controller_explicit_activation = true

	value := f32(5)
	id := uifw.gui_make_id(&ctx, "amount")
	ctx.focused = id
	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 80}, .Column, 0, 44)
	_ = uifw.gui_number_drag_f32(&ctx, "Amount", "amount", &value, 1, 0, 10)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focus_edit_id, id)
	testing.expect_value(t, ctx.text_edit_id, uifw.GUI_ID_NONE)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 80}, .Column, 0, 44)
	_ = uifw.gui_number_drag_f32(&ctx, "Amount", "amount", &value, 1, 0, 10)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	value = 8

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, back = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 80}, .Column, 0, 44)
	_ = uifw.gui_number_drag_f32(&ctx, "Amount", "amount", &value, 1, 0, 10)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, value, f32(5))
	testing.expect_value(t, ctx.focus_edit_id, uifw.GUI_ID_NONE)
	testing.expect_value(t, ctx.text_edit_id, uifw.GUI_ID_NONE)
}

@(test)
test_gui_controller_number_edit_adjusts_with_navigation_and_commits :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.controller_explicit_activation = true

	value := f32(5)
	id := uifw.gui_make_id(&ctx, "amount")
	ctx.focused = id
	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 80}, .Column, 0, 44)
	_ = uifw.gui_number_drag_f32(&ctx, "Amount", "amount", &value, 1, 0, 10)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focus_edit_id, id)
	testing.expect_value(t, ctx.text_edit_id, uifw.GUI_ID_NONE)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_pressed_x = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 80}, .Column, 0, 44)
	testing.expect(t, uifw.gui_number_drag_f32(&ctx, "Amount", "amount", &value, 1, 0, 10))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, value, f32(6))

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 80}, .Column, 0, 44)
	_ = uifw.gui_number_drag_f32(&ctx, "Amount", "amount", &value, 1, 0, 10)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, value, f32(6))
	testing.expect_value(t, ctx.focus_edit_id, uifw.GUI_ID_NONE)
}

@(test)
test_gui_controller_slider_uses_navigation_repeat_not_frame_rate :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.controller_explicit_activation = true

	value := f32(0.5)
	id := uifw.gui_make_id(&ctx, "amount")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 80}, .Column, 0, 44)
	_ = uifw.gui_slider_f32(&ctx, "Amount", "amount", &value, 0, 1)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_x = 1, nav_pressed_x = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 80}, .Column, 0, 44)
	testing.expect(t, uifw.gui_slider_f32(&ctx, "Amount", "amount", &value, 0, 1))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, value, f32(0.55))

	// Holding an axis supplies nav_x every frame, but only the action resolver
	// emits nav_pressed_x when its repeat interval has elapsed.
	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_x = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 80}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_slider_f32(&ctx, "Amount", "amount", &value, 0, 1))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, value, f32(0.55))
}

@(test)
test_slime_focus_memory_commits_after_end_frame_navigation :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.remember_controller_focus = true
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.focus.phase = .Child_Region
	ui.slime_controller.focus.remember_focus = true

	instrument := game.Control_Instrument.Presets
	uifw.gui_begin_frame(&ctx, {key_down = true})
	uifw.gui_push_id(&ctx, "slime_controller_panel")
	uifw.gui_push_id_int(&ctx, int(instrument))
	first := uifw.gui_make_id(&ctx, "first")
	second := uifw.gui_make_id(&ctx, "second")
	ctx.focused = first
	uifw.gui_spatial_group_begin(&ctx, "slime_panel_region")
	_ = uifw.gui_button_at(&ctx, first, {0, 0, 120, 40}, "First", true)
	_ = uifw.gui_button_at(&ctx, second, {0, 50, 120, 40}, "Second", true)
	uifw.gui_spatial_group_end(&ctx)
	uifw.gui_pop_id(&ctx)
	uifw.gui_pop_id(&ctx)
	uifw.gui_end_frame(&ctx)
	game.slime_controller_ui_end_frame(&ui, &ctx)

	panel_region := game.slime_controller_ui_panel_region_id(&ctx, instrument)
	restored := uifw.gui_controller_focus_restore(&ui.slime_controller.focus, panel_region, first)
	testing.expect_value(t, ctx.focused, second)
	testing.expect_value(t, restored, second)
}

@(test)
test_simulation_tab_component_supports_keyboard_entry_and_controller_browse :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Gray_Scott
	state := game.simulation_controller_ui_state(&ui)
	count := len(game.simulation_controller_ui_tabs(ui.mode))
	testing.expect(t, count > 1)

	uifw.gui_begin_frame(&ctx, {active_device = .Mouse_Keyboard, focus_next = true})
	_ = game.simulation_controller_ui_update_input(&ui, &ctx)
	testing.expect_value(t, state.focus.phase, uifw.Controller_Focus_Phase.Region)
	testing.expect(t, state.deck_visible)
	initial := state.focused_index

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_pressed_x = 1, nav_x = 1})
	_ = game.simulation_controller_ui_update_input(&ui, &ctx)
	testing.expect_value(t, state.focused_index, (initial + 1) % count)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true, accept_pressed = true})
	_ = game.simulation_controller_ui_update_input(&ui, &ctx)
	testing.expect(t, state.panel_open)
	testing.expect(t, state.pending_panel_focus)
	testing.expect_value(t, state.focus.phase, uifw.Controller_Focus_Phase.Child_Region)
}

@(test)
test_fast_dpad_and_camera_reset_taps_survive_final_up_state :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)

	host.app_apply_gamepad_button(app, .DPAD_RIGHT, true)
	host.app_apply_gamepad_button(app, .DPAD_RIGHT, false)
	host.app_apply_key_event(app, cast(sdl.Keycode)'C', .C, true)
	host.app_apply_key_event(app, cast(sdl.Keycode)'C', .C, false)
	actions := host.app_resolve_input_actions(app, 1.0 / 60.0)

	testing.expect_value(t, app.controller_dpad_x, f32(0))
	testing.expect(t, !app.input.key_c)
	testing.expect_value(t, actions.navigate.pressed.x, f32(1))
	testing.expect(t, actions.camera_reset.pressed)
	testing.expect(t, actions.camera_reset.released)
}

@(test)
test_release_and_repress_between_frames_preserves_both_phases :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	host.app_apply_gamepad_button(app, .EAST, true)
	first := host.app_resolve_input_actions(app, 1.0 / 60.0)
	testing.expect(t, first.back.pressed)

	app.input.back = false
	app.controller_action_released = {}
	host.app_apply_gamepad_button(app, .EAST, false)
	host.app_apply_gamepad_button(app, .EAST, true)
	second := host.app_resolve_input_actions(app, 1.0 / 60.0)

	testing.expect(t, second.back.down)
	testing.expect(t, second.back.released)
	testing.expect(t, second.back.pressed)
}

@(test)
test_trigger_axis_events_accumulate_fast_press_and_release :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	host.app_note_gamepad_axis_event(app, .RIGHT_TRIGGER, 32767)
	host.app_note_gamepad_axis_event(app, .RIGHT_TRIGGER, 0)

	testing.expect(t, app.input.primary_pressed)
	testing.expect(t, app.input.primary_released)
}

@(test)
test_controller_triggers_interact_without_zooming_camera :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	app.controller_right_trigger = 0.85
	app.controller_right_trigger_down = true
	app.input.primary_pressed = true
	actions := host.app_resolve_input_actions(app, 1.0 / 60.0)

	testing.expect(t, actions.primary.down)
	testing.expect(t, actions.primary.pressed)
	testing.expect_value(t, actions.camera_zoom, f32(0))
}

@(test)
test_controller_dpad_zoom_preserves_held_and_fast_tap_input :: proc(t: ^testing.T) {
	held := new(host.App_State)
	defer free(held)
	held.controller_dpad_y = -1
	held_actions := host.app_resolve_input_actions(held, 1.0 / 60.0)
	testing.expect_value(t, held_actions.camera_zoom, f32(1))

	tapped := new(host.App_State)
	defer free(tapped)
	host.app_apply_gamepad_button(tapped, .DPAD_DOWN, true)
	host.app_apply_gamepad_button(tapped, .DPAD_DOWN, false)
	tapped_actions := host.app_resolve_input_actions(tapped, 1.0 / 60.0)
	testing.expect_value(t, tapped.controller_dpad_y, f32(0))
	testing.expect_value(t, tapped_actions.camera_zoom, f32(-1))
}

@(test)
test_gui_wheel_scroll_is_not_undone_by_retained_focus :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	scroll := f32(0)
	ctx.focused = uifw.gui_make_id(&ctx, "first")
	uifw.gui_begin_frame(&ctx, {mouse_pos = {20, 20}, wheel_delta = -4})
	input_action_test_draw_scroll_buttons(&ctx, &scroll)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, scroll, f32(60))
}

@(test)
test_gui_explicit_selector_dpad_does_not_edit_before_accept :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.controller_explicit_activation = true

	options := [?]string{"One", "Two", "Three"}
	current := 0
	selector := uifw.gui_make_id(&ctx, "selector")
	next := uifw.gui_make_id(&ctx, "next")
	ctx.focused = selector
	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_y = 1, nav_pressed_y = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 8, 44)
	changed := uifw.gui_selector(&ctx, "One", "selector", &current, options[:])
	_ = uifw.gui_button(&ctx, "Next", "next")
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, !changed)
	testing.expect_value(t, current, 0)
	testing.expect_value(t, ctx.focused, next)
}

@(test)
test_preset_stepper_combobox_distinguishes_focused_from_active :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.controller_explicit_activation = true

	presets := [?]string{"Default", "Calm", "Wild"}
	state: game.Preset_Fieldset_State
	id := uifw.gui_make_id(&ctx, "preset_select")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_x = 1, nav_pressed_x = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 70}, .Column, 0, 44)
	testing.expect(t, !game.preset_fieldset_draw_selector(&ctx, &state, presets[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, state.selected_index, 0)
	testing.expect_value(t, ctx.focus_edit_id, uifw.GUI_ID_NONE)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true, accept_pressed = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 70}, .Column, 0, 44)
	testing.expect(t, !game.preset_fieldset_draw_selector(&ctx, &state, presets[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, state.selected_index, 0)
	testing.expect_value(t, ctx.focus_edit_id, id)
	testing.expect_value(t, ctx.open_panel, uifw.GUI_ID_NONE)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_x = 1, nav_pressed_x = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 70}, .Column, 0, 44)
	testing.expect(t, game.preset_fieldset_draw_selector(&ctx, &state, presets[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, state.selected_index, 1)
	testing.expect_value(t, ctx.focus_edit_id, id)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, back = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 70}, .Column, 0, 44)
	testing.expect(t, game.preset_fieldset_draw_selector(&ctx, &state, presets[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, state.selected_index, 0)
	testing.expect_value(t, ctx.focus_edit_id, uifw.GUI_ID_NONE)
}

@(test)
test_gui_consecutive_semantic_accept_pulses_are_distinct :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.controller_explicit_activation = true
	value := false
	id := uifw.gui_make_id(&ctx, "toggle")
	ctx.focused = id

	expected_values := [?]bool{true, false}
	for expected in expected_values {
		uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true, accept_pressed = true})
		uifw.gui_layout_begin(&ctx, {0, 0, 220, 70}, .Column, 0, 44)
		testing.expect(t, uifw.gui_toggle(&ctx, "Toggle", "toggle", &value))
		uifw.gui_layout_end(&ctx)
		uifw.gui_end_frame(&ctx)
		testing.expect_value(t, value, expected)
	}
}

@(test)
test_gui_focus_loss_clears_controller_edit_snapshot :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.controller_explicit_activation = true
	value := f32(0.5)
	slider := uifw.gui_make_id(&ctx, "slider")
	other := uifw.gui_make_id(&ctx, "other")
	ctx.focused = slider

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 8, 44)
	_ = uifw.gui_slider_f32(&ctx, "Slider", "slider", &value, 0, 1)
	_ = uifw.gui_button(&ctx, "Other", "other")
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.controller_snapshot_id, slider)

	ctx.focused = other
	uifw.gui_begin_frame(&ctx, {active_device = .Controller})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 8, 44)
	_ = uifw.gui_slider_f32(&ctx, "Slider", "slider", &value, 0, 1)
	_ = uifw.gui_button(&ctx, "Other", "other")
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ctx.focus_edit_id, uifw.GUI_ID_NONE)
	testing.expect_value(t, ctx.controller_armed_id, uifw.GUI_ID_NONE)
	testing.expect_value(t, ctx.controller_snapshot_id, uifw.GUI_ID_NONE)
}

@(test)
test_editor_capture_blocks_global_shortcuts_but_button_focus_keeps_wasd_camera :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Slime_Mold
	ui.simulation_shell.show_ui = true

	ctx.focused = 123
	button_focused := game.app_ui_simulation_filter_input(&ui, &ctx, {
		key_w = true,
		controller_left = {0.8, 0.2},
	})
	testing.expect(t, button_focused.key_w)
	testing.expect_value(t, button_focused.controller_left, uifw.Vec2{})

	ctx.text_edit_id = ctx.focused
	ctx.input.pause = true
	ctx.input.toggle_ui = true
	ctx.input.key_space = true
	ctx.input.key_slash = true
	editor_filtered := game.app_ui_simulation_filter_input(&ui, &ctx, {
		pause = true,
		toggle_ui = true,
		key_space = true,
		key_slash = true,
		key_w = true,
	})
	testing.expect(t, ui.simulation_shell.show_ui)
	testing.expect(t, !editor_filtered.pause)
	testing.expect(t, !editor_filtered.toggle_ui)
	testing.expect(t, !editor_filtered.key_w)
	testing.expect(t, !ctx.input.pause)
	testing.expect(t, !ctx.input.toggle_ui)
}

@(test)
test_controller_action_can_only_be_taken_once :: proc(t: ^testing.T) {
	action := game.Input_Action_Button_State{
		pressed = true,
		owner = .Controller,
	}
	testing.expect(t, game.app_ui_take_controller_action(&action, true, .Controller))
	testing.expect(t, !game.app_ui_take_controller_action(&action, false, .Controller))
}

@(test)
test_pointer_gesture_owner_overrides_prompt_device :: proc(t: ^testing.T) {
	actions: game.Input_Action_Frame
	actions.primary = {
		down = true,
		pressed = true,
		owner = .Mouse_Keyboard,
	}
	device := host.app_pointer_device_for_actions(actions, .Controller)
	testing.expect_value(t, device, uifw.Input_Device_Kind.Mouse_Keyboard)
}

@(test)
test_keyboard_number_escape_restores_pre_edit_value :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	value := f32(5)
	id := uifw.gui_make_id(&ctx, "number")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {key_enter = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 70}, .Column, 0, 44)
	_ = uifw.gui_number_drag_f32(&ctx, "Number", "number", &value, 1, 0, 10)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	value = 9

	uifw.gui_begin_frame(&ctx, {key_escape = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 70}, .Column, 0, 44)
	_ = uifw.gui_number_drag_f32(&ctx, "Number", "number", &value, 1, 0, 10)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, value, f32(5))
	testing.expect_value(t, ctx.text_edit_id, uifw.GUI_ID_NONE)
}

@(test)
test_gui_text_input_request_covers_numeric_editor_activation :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	value := f32(5)
	id := uifw.gui_make_id(&ctx, "number")

	// Keyboard users can begin a numeric edit by typing, so SDL text input
	// must already be active while the numeric control is merely focused.
	ctx.focused = id
	uifw.gui_begin_frame(&ctx, {active_device = .Mouse_Keyboard})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 70}, .Column, 0, 44)
	_ = uifw.gui_number_drag_f32(&ctx, "Number", "number", &value, 1, 0, 10)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect(t, ctx.wants_text_input)
	testing.expect_value(t, ctx.text_edit_id, uifw.GUI_ID_NONE)

	// Controller browse focus alone must not invoke the platform text service.
	uifw.gui_begin_frame(&ctx, {active_device = .Controller})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 70}, .Column, 0, 44)
	_ = uifw.gui_number_drag_f32(&ctx, "Number", "number", &value, 1, 0, 10)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect(t, !ctx.wants_text_input)
}

@(test)
test_previous_frame_overlay_blocks_simulation_pointer_everywhere :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Gray_Scott
	ctx.overlay_input_rect_count = 1
	ctx.overlay_input_rects[0] = {300, 200, 200, 200}

	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1000,
		window_height = 700,
		mouse_pos = {10, 650},
		mouse_down = true,
		mouse_pressed = true,
		primary_down = true,
		primary_pressed = true,
	})

	testing.expect(t, !filtered.mouse_down)
	testing.expect(t, !filtered.mouse_pressed)
}

@(test)
test_gui_area_edit_back_restores_vector_snapshot :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.controller_explicit_activation = true
	value := uifw.Vec2{0.25, 0.75}
	id := uifw.gui_make_id(&ctx, "area")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 210}, .Column, 0, 44)
	_ = uifw.gui_area_slider_f32(&ctx, "Area", "area", &value, {}, {1, 1})
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	value = {0.9, 0.1}

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, back = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 210}, .Column, 0, 44)
	_ = uifw.gui_area_slider_f32(&ctx, "Area", "area", &value, {}, {1, 1})
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, value, uifw.Vec2{0.25, 0.75})
}

@(test)
test_gui_pointer_selector_arrow_keeps_coherent_selector_focus :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	options := [?]string{"One", "Two", "Three"}
	current := 0
	id := uifw.gui_make_id(&ctx, "selector")

	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 20}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 70}, .Column, 0, 44)
	testing.expect(t, uifw.gui_selector(&ctx, "One", "selector", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, current, 2)
	testing.expect_value(t, ctx.focused, id)
}

@(test)
test_gray_scott_plot_requires_controller_activation_and_back_restores_value :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	x, y := f32(0.04), f32(0.06)
	id := uifw.gui_make_id(&ctx, "plot")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_pressed_x = 1, nav_x = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 240}, .Column, 0, 44)
	testing.expect(t, !game.gray_scott_xy_plot(&ctx, "Plot", "plot", "X", "Y", "X", "Y", &x, &y, {}, {0.1, 0.1}, {1, 0, 0, 1}, {1, 1, 1, 1}))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect(t, input_action_test_approx(x, 0.04))

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true, accept_pressed = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 240}, .Column, 0, 44)
	_ = game.gray_scott_xy_plot(&ctx, "Plot", "plot", "X", "Y", "X", "Y", &x, &y, {}, {0.1, 0.1}, {1, 0, 0, 1}, {1, 1, 1, 1})
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focus_edit_id, id)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_pressed_x = 1, nav_x = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 240}, .Column, 0, 44)
	testing.expect(t, game.gray_scott_xy_plot(&ctx, "Plot", "plot", "X", "Y", "X", "Y", &x, &y, {}, {0.1, 0.1}, {1, 0, 0, 1}, {1, 1, 1, 1}))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect(t, x > 0.04)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, back = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 240}, .Column, 0, 44)
	_ = game.gray_scott_xy_plot(&ctx, "Plot", "plot", "X", "Y", "X", "Y", &x, &y, {}, {0.1, 0.1}, {1, 0, 0, 1}, {1, 1, 1, 1})
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect(t, input_action_test_approx(x, 0.04))
	testing.expect(t, input_action_test_approx(y, 0.06))
}

@(test)
test_particle_force_matrix_cell_supports_controller_editing :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	sim: game.Particle_Life_Simulation
	sim.settings.species_count = 1
	id := uifw.gui_make_id(&ctx, "pl_matrix_0_0")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true, accept_pressed = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 420}, .Column, 0, 44)
	game.particle_life_draw_force_matrix_editor(&sim, &ctx)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focus_edit_id, id)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_pressed_x = 1, nav_x = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 420}, .Column, 0, 44)
	game.particle_life_draw_force_matrix_editor(&sim, &ctx)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect(t, input_action_test_approx(sim.runtime.force_matrix[0], 0.1))

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, back = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 420}, .Column, 0, 44)
	game.particle_life_draw_force_matrix_editor(&sim, &ctx)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect(t, input_action_test_approx(sim.runtime.force_matrix[0], 0))
}

@(test)
test_slime_pointer_deck_selection_reconciles_controller_region :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = true
	ui.slime_controller.focus.phase = .Child_Region
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, ui.settings.ui_scale)
	deck := game.slime_controller_ui_deck_rect(&ctx, 1280, 720, ui.slime_controller.mode)
	point := uifw.Vec2{deck.x + ctx.style.spacing_1 + 5, deck.y + game.app_ui_simulation_bar_height(&ctx) + ctx.style.spacing_1 + 5}

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, mouse_pos = point, mouse_pressed = true, mouse_released = true})
	game.slime_controller_ui_draw_deck(&ui.slime_controller, &ctx, deck)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.slime_controller.focus.phase, uifw.Controller_Focus_Phase.Region)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_0"))

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, active_device = .Controller, accept = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	testing.expect_value(t, ui.slime_controller.focus.phase, uifw.Controller_Focus_Phase.Child_Region)
}
