package main

import game "../packages/game"
import host "../packages/app"
import uifw "zelda_engine:ui"

import "core:testing"

@(test)
test_active_controller_disconnect_explains_pause_and_preserves_edit_focus :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)
	ui.mode = .Flow_Field
	ui.flow_field.paused = false
	ctx.focused = 41
	ctx.focus_edit_id = 41

	uifw.gui_begin_frame(&ctx, {
		active_device = .Controller,
		controller_disconnected = true,
	})
	game.app_ui_handle_controller_disconnect(&ui, &ctx)
	game.app_ui_update_device_notice(&ui, &ctx)

	testing.expect(t, ui.flow_field.paused)
	testing.expect_value(t, game.fixed_string(ui.device_notice[:]), "Controller disconnected - simulation paused")
	testing.expect(t, ui.device_notice_disconnected)
	testing.expect_value(t, ctx.focused, uifw.Gui_Id(41))
	testing.expect_value(t, ctx.focus_edit_id, uifw.Gui_Id(41))
}

@(test)
test_device_notice_reports_connection_and_expires :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)

	uifw.gui_begin_frame(&ctx, {controller_connected = true})
	game.app_ui_update_device_notice(&ui, &ctx)
	testing.expect_value(t, game.fixed_string(ui.device_notice[:]), "Controller connected")
	testing.expect(t, !ui.device_notice_disconnected)

	uifw.gui_begin_frame(&ctx, {delta_time = game.APP_UI_DEVICE_NOTICE_SECONDS})
	game.app_ui_update_device_notice(&ui, &ctx)
	testing.expect_value(t, game.fixed_string(ui.device_notice[:]), "")
	testing.expect_value(t, ui.device_notice_seconds, f32(0))
}

@(test)
test_device_notice_stays_at_top_with_bottom_simulation_bar :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)
	ui.mode = .Gray_Scott
	ui.simulation_shell.controls_visible = true
	game.write_fixed_string(ui.device_notice[:], "Controller connected")
	ui.device_notice_seconds = game.APP_UI_DEVICE_NOTICE_SECONDS

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720})
	game.app_ui_draw_device_notice(&ui, &ctx)
	found := false
	for command in ctx.commands {
		if command.kind == .Text && command.text == "Controller connected" {
			found = true
			testing.expect(t, command.rect.y >= max(ctx.style.spacing_3, f32(18)))
			testing.expect(t, command.rect.y < game.app_ui_simulation_bar_height(&ctx))
			testing.expect(t, command.rect.x >= 0)
			testing.expect(t, command.rect.x + command.rect.w <= 1280)
		}
	}
	testing.expect(t, found)
}

@(test)
test_device_notice_scales_long_text_to_narrow_window :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)
	game.write_fixed_string(ui.device_notice[:], "Controller disconnected - simulation paused")
	ui.device_notice_seconds = game.APP_UI_DEVICE_NOTICE_SECONDS

	uifw.gui_begin_frame(&ctx, {window_width = 320, window_height = 240})
	game.app_ui_draw_device_notice(&ui, &ctx)
	for command in ctx.commands {
		if command.kind == .Text && command.text == "Controller disconnected - simulation paused" {
			text_width := uifw.gui_font_text_width(command.font_kind, transmute([]u8)command.text, command.text_scale, ctx.style.char_width)
			testing.expect(t, text_width <= command.rect.w + 0.01)
			return
		}
	}
	testing.expect(t, false)
}
