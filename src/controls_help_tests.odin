package main

import engine "../packages/engine"
import game "../packages/game"
import host "../packages/app"
import uifw "../packages/ui"

import "core:testing"

controls_help_find_item :: proc(ctx: ^uifw.Gui_Context, id: uifw.Gui_Id) -> (uifw.Gui_Spatial_Item, bool) {
	for i in 0 ..< ctx.spatial_item_count {
		if ctx.spatial_items[i].id == id {
			return ctx.spatial_items[i], true
		}
	}
	return {}, false
}

controls_help_has_text :: proc(ctx: ^uifw.Gui_Context, text: string) -> bool {
	for command in ctx.commands {
		if command.kind == .Text && command.text == text {
			return true
		}
	}
	return false
}

controls_help_has_text_prefix :: proc(ctx: ^uifw.Gui_Context, text: string) -> bool {
	for command in ctx.commands {
		if command.kind == .Text && len(command.text) >= len(text) && command.text[:len(text)] == text {
			return true
		}
	}
	return false
}

@(test)
test_controls_help_teaches_current_input_model_and_supports_back :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .How_To_Play

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720})
	game.app_ui_draw_how_to_play(&ui, &ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect(t, controls_help_has_text(&ctx, "Controls"))
	// The intro is normally wrapped into line commands; assert its opening is
	// present instead of depending on a particular font metric or UI scale.
	testing.expect(t, controls_help_has_text_prefix(&ctx, "You do not need to understand every setting"))
	testing.expect(t, controls_help_has_text(&ctx, "Try the controls"))
	_, demo_button_found := controls_help_find_item(&ctx, uifw.gui_make_id(&ctx, "how_to_play_demo_button"))
	_, demo_toggle_found := controls_help_find_item(&ctx, uifw.gui_make_id(&ctx, "how_to_play_demo_toggle"))
	_, demo_number_found := controls_help_find_item(&ctx, uifw.gui_make_id(&ctx, "how_to_play_demo_number"))
	_, demo_slider_found := controls_help_find_item(&ctx, uifw.gui_make_id(&ctx, "how_to_play_demo_slider"))
	_, demo_selector_found := controls_help_find_item(&ctx, uifw.gui_make_id(&ctx, "how_to_play_demo_selector"))
	testing.expect(t, demo_button_found && demo_toggle_found && demo_number_found && demo_slider_found && demo_selector_found)
	for section in game.HOW_TO_PLAY_SECTIONS {
		testing.expect(t, controls_help_has_text(&ctx, section.title))
	}
	back, found := controls_help_find_item(&ctx, uifw.gui_make_id(&ctx, "back"))
	testing.expect(t, found)
	testing.expect(t, back.bounds.x >= 0 && back.bounds.y >= 0)
	testing.expect(t, back.bounds.x + back.bounds.w <= 1280)
	testing.expect(t, back.bounds.y + back.bounds.h <= 720)

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, back = true})
	game.app_ui_draw_how_to_play(&ui, &ctx)
	testing.expect_value(t, ui.mode, game.App_Mode.Main_Menu)
}

@(test)
test_ui_component_fixture_renders_only_the_requested_target_state :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default(), true)
	ui.component_fixture = .Number
	ui.component_fixture_state = .Editing
	ui.component_fixture_value = 12.5

	uifw.gui_begin_frame(&ctx, {window_width = 800, window_height = 480, active_device = .Controller})
	game.app_ui_draw_component_fixture(&ui, &ctx)
	uifw.gui_end_frame(&ctx)
	target := uifw.gui_make_id(&ctx, "component_fixture_target")
	_, found := controls_help_find_item(&ctx, target)
	testing.expect(t, found)
	testing.expect_value(t, ctx.focused, target)
	testing.expect_value(t, ctx.focus_edit_id, target)
	testing.expect(t, ctx.spatial_item_count == 1)
}

@(test)
test_main_menu_actions_fit_wide_and_compact_layouts_without_controls :: proc(t: ^testing.T) {
	viewports := [?]uifw.Vec2{{1920, 1080}, {800, 700}, {480, 640}}
	for viewport in viewports {
		ctx: uifw.Gui_Context
		uifw.gui_init(&ctx)
		ui: game.App_Ui_State
		game.app_ui_init(&ui, game.settings_default())
		ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), viewport.x, viewport.y, 1)
		vk_ctx: engine.Vk_Context
		vk_ctx.swapchain_extent = {width = u32(viewport.x), height = u32(viewport.y)}
		worker: host.Render_Worker_State

		uifw.gui_begin_frame(&ctx, {window_width = i32(viewport.x), window_height = i32(viewport.y), mouse_pos = {-1000, -1000}})
		game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
		options, options_found := controls_help_find_item(&ctx, uifw.gui_make_id(&ctx, "options"))
		controls, controls_found := controls_help_find_item(&ctx, uifw.gui_make_id(&ctx, "controls"))
		quit, quit_found := controls_help_find_item(&ctx, uifw.gui_make_id(&ctx, "quit"))
		_ = controls
		testing.expect(t, options_found && !controls_found && quit_found)
		testing.expect(t, options.bounds.y + options.bounds.h <= quit.bounds.y)
		testing.expect(t, options.bounds.x >= 0 && quit.bounds.x + quit.bounds.w <= viewport.x)
		testing.expect(t, options.bounds.y >= 0 && quit.bounds.y + quit.bounds.h <= viewport.y)
		uifw.gui_destroy(&ctx)
	}
}

@(test)
test_simulation_f1_opens_modal_help_without_leaking_through_an_editor :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Gray_Scott

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720})
	_ = game.app_ui_simulation_filter_input(&ui, &ctx, {window_width = 1280, window_height = 720, key_f1 = true, frame_index = 7})
	testing.expect(t, ui.controls_help_open)
	testing.expect_value(t, ui.controls_help_open_frame, ctx.frame_index)

	_ = game.app_ui_simulation_filter_input(&ui, &ctx, {window_width = 1280, window_height = 720})
	testing.expect_value(t, ui.input_route.active_context, game.App_Input_Context.Modal)

	game.app_ui_close_controls_help(&ui, &ctx)
	ctx.text_edit_id = 42
	_ = game.app_ui_simulation_filter_input(&ui, &ctx, {window_width = 1280, window_height = 720, key_f1 = true})
	testing.expect(t, !ui.controls_help_open)
}

@(test)
test_simulation_help_modal_restores_invoker_focus_on_back :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Gray_Scott
	invoker := uifw.gui_make_id(&ctx, "help_invoker")
	ctx.focused = invoker

	uifw.gui_begin_frame(&ctx, {window_width = 960, window_height = 720})
	game.app_ui_open_controls_help(&ui, &ctx)
	game.app_ui_draw_controls_help_modal(&ui, &ctx)
	testing.expect(t, ui.controls_help_open)
	testing.expect(t, controls_help_has_text(&ctx, "Controls"))
	testing.expect(t, controls_help_has_text(&ctx, "Quick reference"))

	uifw.gui_end_frame(&ctx)
	uifw.gui_begin_frame(&ctx, {window_width = 960, window_height = 720, back = true})
	game.app_ui_draw_controls_help_modal(&ui, &ctx)
	testing.expect(t, !ui.controls_help_open)
	testing.expect_value(t, ctx.focused, invoker)
}

@(test)
test_simulation_help_quick_reference_tracks_prompt_device :: proc(t: ^testing.T) {
	keyboard := game.app_ui_controls_help_quick_reference(.Mouse_Keyboard)
	letters := game.app_ui_controls_help_quick_reference(.Mouse_Keyboard, "Letter Shortcuts")
	controller := game.app_ui_controls_help_quick_reference(.Controller)
	testing.expect(t, keyboard == game.CONTROLS_HELP_KEYBOARD_QUICK_REFERENCE)
	testing.expect(t, letters == game.CONTROLS_HELP_KEYBOARD_LETTER_QUICK_REFERENCE)
	testing.expect(t, controller == game.CONTROLS_HELP_CONTROLLER_QUICK_REFERENCE)
	testing.expect(t, keyboard != controller)
	testing.expect(t, keyboard != letters)
	custom_settings := game.settings_default()
	custom_settings.keyboard_shortcut_profile = "Custom"
	custom_settings.keyboard_pause_binding = .P
	custom_settings.keyboard_toggle_ui_binding = .U
	custom_settings.keyboard_help_binding = .H
	custom := game.app_ui_controls_help_quick_reference_for_settings(.Mouse_Keyboard, custom_settings)
	testing.expect(t, custom == "H closes help  •  Tab / Shift+Tab moves focus  •  Enter activates or edits  •  Escape goes back or cancels  •  U toggles UI  •  P pauses")
	view_pause := game.settings_default()
	view_pause.controller_menu_layout = "View Pauses"
	controller_alt := game.app_ui_controls_help_quick_reference_for_settings(.Controller, view_pause)
	testing.expect(t, controller_alt == game.CONTROLS_HELP_CONTROLLER_VIEW_PAUSE_QUICK_REFERENCE)
	view_pause.controller_shoulder_layout = "Left Next"
	controller_left_alt := game.app_ui_controls_help_quick_reference_for_settings(.Controller, view_pause)
	testing.expect(t, controller_left_alt == game.CONTROLS_HELP_CONTROLLER_LEFT_NEXT_VIEW_PAUSE_QUICK_REFERENCE)
}

@(test)
test_simulation_bar_help_affordance_fits_compact_and_wide_windows :: proc(t: ^testing.T) {
	viewports := [?]uifw.Vec2{{1920, 1080}, {800, 700}, {480, 640}}
	for viewport in viewports {
		ctx: uifw.Gui_Context
		uifw.gui_init(&ctx)
		ui: game.App_Ui_State
		game.app_ui_init(&ui, game.settings_default())
		ui.mode = .Gray_Scott
		ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), viewport.x, viewport.y, 1)
		vk_ctx: engine.Vk_Context
		vk_ctx.swapchain_extent = {width = u32(viewport.x), height = u32(viewport.y)}
		uifw.gui_begin_frame(&ctx, {window_width = i32(viewport.x), window_height = i32(viewport.y), mouse_pos = {-1000, -1000}})
		game.app_ui_draw_simulation_bar(&ui, &ctx, .Gray_Scott, nil, nil, nil, false, false, "Gray-Scott", &vk_ctx, viewport.x, nil)
		uifw.gui_push_id(&ctx, "simulation_bar")
		help, found := controls_help_find_item(&ctx, uifw.gui_make_id(&ctx, "help"))
		uifw.gui_pop_id(&ctx)
		testing.expect(t, found)
		testing.expect(t, help.bounds.x >= 0 && help.bounds.y >= 0)
		testing.expect(t, help.bounds.x + help.bounds.w <= viewport.x)
		testing.expect(t, help.bounds.y + help.bounds.h <= viewport.y)
		uifw.gui_destroy(&ctx)
	}
}
