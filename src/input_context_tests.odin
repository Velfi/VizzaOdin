package main

import game "../packages/game"
import uifw "../packages/ui"

import "core:testing"

@(test)
test_input_context_routes_channels_by_priority :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Slime_Mold

	input := game.Ui_Frame_Input{window_width = 1280, window_height = 720, mouse_pos = {640, 360}}
	route := game.app_ui_resolve_input_context(&ui, &ctx, input)
	testing.expect_value(t, route.active_context, game.App_Input_Context.Simulation_Canvas)
	testing.expect_value(t, route.pointer_owner, game.App_Input_Context.Simulation_Canvas)
	testing.expect_value(t, route.navigation_owner, game.App_Input_Context.Simulation_Canvas)
	testing.expect_value(t, route.keyboard_camera_owner, game.App_Input_Context.Simulation_Canvas)
	testing.expect_value(t, route.controller_camera_owner, game.App_Input_Context.Simulation_Canvas)
	testing.expect_value(t, route.global_shortcut_owner, game.App_Input_Context.Global_Fallback)

	ctx.focused = 42
	route = game.app_ui_resolve_input_context(&ui, &ctx, input)
	testing.expect_value(t, route.active_context, game.App_Input_Context.Focused_Ui)
	testing.expect_value(t, route.pointer_owner, game.App_Input_Context.Simulation_Canvas)
	testing.expect_value(t, route.navigation_owner, game.App_Input_Context.Focused_Ui)
	testing.expect_value(t, route.keyboard_camera_owner, game.App_Input_Context.Simulation_Canvas)
	testing.expect_value(t, route.controller_camera_owner, game.App_Input_Context.Focused_Ui)
	testing.expect_value(t, route.global_shortcut_owner, game.App_Input_Context.Global_Fallback)

	ctx.focus_edit_id = ctx.focused
	route = game.app_ui_resolve_input_context(&ui, &ctx, input)
	testing.expect_value(t, route.active_context, game.App_Input_Context.Value_Edit)
	testing.expect_value(t, route.pointer_owner, game.App_Input_Context.Value_Edit)
	testing.expect_value(t, route.navigation_owner, game.App_Input_Context.Value_Edit)
	testing.expect_value(t, route.keyboard_camera_owner, game.App_Input_Context.Value_Edit)
	testing.expect_value(t, route.controller_camera_owner, game.App_Input_Context.Value_Edit)
	testing.expect_value(t, route.global_shortcut_owner, game.App_Input_Context.Value_Edit)

	ui.slime_mold.preset_ui.save_open = true
	route = game.app_ui_resolve_input_context(&ui, &ctx, input)
	testing.expect_value(t, route.active_context, game.App_Input_Context.Modal)
	testing.expect_value(t, route.pointer_owner, game.App_Input_Context.Modal)
	testing.expect_value(t, route.navigation_owner, game.App_Input_Context.Modal)
	testing.expect_value(t, route.keyboard_camera_owner, game.App_Input_Context.Modal)
	testing.expect_value(t, route.controller_camera_owner, game.App_Input_Context.Modal)
	testing.expect_value(t, route.global_shortcut_owner, game.App_Input_Context.Modal)
}

@(test)
test_controller_ui_shortcut_is_owned_without_changing_prompt_device :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	show_ui_before := ui.simulation_shell.show_ui

	input := game.Ui_Frame_Input{
		window_width = 1280,
		window_height = 720,
		active_device = .Mouse_Keyboard,
		toggle_ui = true,
		actions = {
			toggle_ui = {pressed = true, owner = .Controller},
		},
	}
	route := game.app_ui_resolve_input_context(&ui, &ctx, input)
	testing.expect(t, route.controller_ui_claimed)
	testing.expect_value(t, route.active_context, game.App_Input_Context.Focused_Ui)
	testing.expect_value(t, route.global_shortcut_owner, game.App_Input_Context.Focused_Ui)

	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, input)
	testing.expect(t, !filtered.toggle_ui)
	testing.expect(t, !filtered.actions.toggle_ui.pressed)
	testing.expect(t, ui.frame_actions.toggle_ui.pressed)
	testing.expect_value(t, ui.frame_actions.toggle_ui.owner, game.Input_Action_Source.Controller)
	testing.expect_value(t, ui.simulation_shell.show_ui, show_ui_before)
}

@(test)
test_controller_deck_space_claim_reaches_ui_but_not_shell_or_simulation :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = false
	ui.slime_controller.panel_open = false
	show_ui_before := ui.simulation_shell.show_ui

	gui_input := uifw.Input_State{window_width = 1280, window_height = 720, key_space = true, pause = true}
	uifw.gui_begin_frame(&ctx, gui_input)
	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1280,
		window_height = 720,
		key_space = true,
		pause = true,
		actions = {pause = {pressed = true, owner = .Mouse_Keyboard}},
	})
	testing.expect(t, !filtered.key_space)
	testing.expect(t, !filtered.pause)
	testing.expect(t, ctx.input.key_space)
	testing.expect_value(t, ui.simulation_shell.show_ui, show_ui_before)

	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	testing.expect(t, ui.slime_controller.deck_visible)
	testing.expect(t, ui.slime_controller.focus.phase != .Unfocused)
}

@(test)
test_semantic_control_deck_action_opens_deck_without_legacy_space_fields :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = false

	input := game.Ui_Frame_Input{
		window_width = 1280,
		window_height = 720,
		actions = {
			control_deck = {pressed = true, owner = .Mouse_Keyboard},
		},
	}
	route := game.app_ui_resolve_input_context(&ui, &ctx, input)
	testing.expect(t, route.controller_ui_claimed)
	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, input)
	testing.expect(t, !filtered.actions.control_deck.pressed)
	testing.expect(t, ui.frame_actions.control_deck.pressed)

	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	testing.expect(t, ui.slime_controller.deck_visible)
	testing.expect(t, ui.slime_controller.focus.phase != .Unfocused)
}

@(test)
test_semantic_shoulder_focus_claim_routes_to_controller_deck :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold

	input := game.Ui_Frame_Input{
		window_width = 1280,
		window_height = 720,
		active_device = .Controller,
		focus_next = true,
		actions = {focus_next = {pressed = true, owner = .Controller}},
		controller_left = {0.8, 0.4},
	}
	route := game.app_ui_resolve_input_context(&ui, &ctx, input)
	testing.expect(t, route.controller_ui_claimed)
	testing.expect_value(t, route.active_context, game.App_Input_Context.Focused_Ui)
	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, input)
	testing.expect(t, !filtered.actions.focus_next.pressed)
	testing.expect_value(t, filtered.controller_left, uifw.Vec2{})
}

@(test)
test_engaged_edit_captures_outside_pointer_before_simulation :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Gray_Scott
	ctx.focused = 7
	ctx.focus_edit_id = 7

	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1280,
		window_height = 720,
		mouse_pos = {640, 360},
		mouse_down = true,
		mouse_pressed = true,
		primary_down = true,
		primary_pressed = true,
	})
	testing.expect_value(t, ui.input_route.pointer_owner, game.App_Input_Context.Value_Edit)
	testing.expect(t, !filtered.mouse_down)
	testing.expect(t, !filtered.mouse_pressed)
	testing.expect(t, !filtered.primary_down)
	testing.expect(t, !filtered.primary_pressed)
	testing.expect(t, !ui.simulation_shell.mouse_pressed)
}

@(test)
test_control_deck_hint_tracks_device_and_engagement_phase :: proc(t: ^testing.T) {
	state: game.Slime_Controller_Ui_State
	game.slime_controller_ui_init(&state)
	simulation_state: game.Simulation_Controller_Ui_State
	game.simulation_controller_ui_init(&simulation_state)

	state.focus.phase = .Region
	simulation_state.focus.phase = .Region
	testing.expect_value(
		t,
		game.slime_controller_ui_context_hint(&state, .Controller),
		"D-pad / shoulders: browse  |  Accept: open  |  Back: close",
	)
	testing.expect_value(
		t,
		game.slime_controller_ui_context_hint(&state, .Mouse_Keyboard),
		"Arrows / Tab: browse  |  Enter: open  |  Esc: close",
	)
	testing.expect_value(
		t,
		game.simulation_controller_ui_context_hint(&simulation_state, .Mouse_Keyboard),
		"Arrows / Tab: browse  |  Enter: open  |  Esc: close",
	)

	state.focus.phase = .Child_Region
	simulation_state.focus.phase = .Child_Region
	testing.expect_value(
		t,
		game.slime_controller_ui_context_hint(&state, .Controller),
		"D-pad: navigate  |  Accept: edit  |  Back: sections",
	)
	testing.expect_value(
		t,
		game.simulation_controller_ui_context_hint(&simulation_state, .Controller),
		"D-pad: navigate  |  Accept: edit  |  Back: sections",
	)
	state.focus.phase = .Active_Control
	simulation_state.focus.phase = .Active_Control
	testing.expect_value(
		t,
		game.slime_controller_ui_context_hint(&state, .Mouse_Keyboard),
		"Arrows: adjust  |  Shift: fine  |  Enter: commit  |  Esc: cancel",
	)
	testing.expect_value(
		t,
		game.simulation_controller_ui_context_hint(&simulation_state, .Controller),
		"D-pad: adjust  |  Light stick: fine  |  Accept: commit  |  Back: cancel",
	)
}

@(test)
test_control_deck_reserves_a_non_overlapping_command_strip :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	state: game.Slime_Controller_Ui_State
	game.slime_controller_ui_init(&state)
	state.deck_visible = true
	state.focus.phase = .Region

	uifw.gui_begin_frame(&ctx, {active_device = .Controller})
	game.slime_controller_ui_draw_deck(&state, &ctx, {0, 0, 1200, 180})

	hint := "D-pad / shoulders: browse  |  Accept: open  |  Back: close"
	hint_y := f32(-1)
	for command in ctx.commands {
		if command.kind == .Text && command.text == hint {
			hint_y = command.rect.y
			break
		}
	}
	testing.expect(t, hint_y > 0)
	for i in 0 ..< ctx.spatial_item_count {
		item := ctx.spatial_items[i]
		testing.expect(t, item.bounds.y + item.bounds.h <= hint_y)
	}
}

@(test)
test_control_panel_never_overlaps_deck_on_compact_viewports :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	state: game.Slime_Controller_Ui_State
	game.slime_controller_ui_init(&state)

	heights := [?]f32{320, 360, 480, 720}
	for height in heights {
		deck := game.slime_controller_ui_deck_rect(&ctx, 960, height, state.mode)
		panel := game.slime_controller_ui_panel_rect(&ctx, 960, height, deck)
		testing.expect(t, panel.y >= 0)
		testing.expect(t, panel.y + panel.h <= deck.y)
		testing.expect(t, deck.y + deck.h <= height)
	}
}

@(test)
test_mouse_canvas_click_releases_controller_ui_focus :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Particle_Life
	state := game.simulation_controller_ui_state(&ui)
	state.deck_visible = true
	state.panel_open = true
	state.focus.phase = .Child_Region
	ctx.focused = 77

	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, {
		active_device = .Mouse_Keyboard,
		window_width = 1280,
		window_height = 720,
		mouse_pos = {10, 300},
		mouse_pressed = true,
	})

	testing.expect(t, filtered.mouse_pressed)
	testing.expect_value(t, ctx.focused, uifw.GUI_ID_NONE)
	testing.expect_value(t, state.focus.phase, uifw.Controller_Focus_Phase.Unfocused)
	// The canvas click relinquishes UI focus and closes the panel. The same
	// pointer activity reveals the unified header/tab chrome for its grace
	// period, so visibility is intentionally independent from focus ownership.
	testing.expect(t, ui.simulation_shell.controls_visible)
	testing.expect(t, state.deck_visible)
	testing.expect(t, !state.panel_open)
	testing.expect_value(t, ui.input_route.pointer_owner, game.App_Input_Context.Simulation_Canvas)
}
