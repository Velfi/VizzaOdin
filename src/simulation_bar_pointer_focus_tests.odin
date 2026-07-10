package main

import uifw "../packages/ui"

import "core:testing"

@(test)
test_pointer_focus_disabled_button_click_does_not_claim_navigation_focus :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	id := uifw.gui_make_id(&ctx, "simulation-bar-action")
	bounds := uifw.Rect{10, 10, 120, 40}

	uifw.gui_begin_frame(&ctx, {mouse_pos = {20, 20}, mouse_down = true, mouse_pressed = true})
	_ = uifw.gui_button_at(&ctx, id, bounds, "Pause", true, false)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ctx.focused, uifw.GUI_ID_NONE)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {20, 20}, mouse_released = true})
	activated := uifw.gui_button_at(&ctx, id, bounds, "Pause", true, false)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, activated)
	testing.expect_value(t, ctx.focused, uifw.GUI_ID_NONE)
}

@(test)
test_pointer_focus_disabled_button_keeps_keyboard_activation :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	id := uifw.gui_make_id(&ctx, "simulation-bar-action")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {key_enter = true, mouse_pos = {-1000, -1000}})
	activated := uifw.gui_button_at(&ctx, id, {10, 10, 120, 40}, "Pause", true, false)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, activated)
	testing.expect_value(t, ctx.focused, id)
}
