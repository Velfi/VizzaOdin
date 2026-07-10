package main

import uifw "../packages/ui"

import "core:testing"

gui_keyboard_cancel_draw_slider :: proc(ctx: ^uifw.Gui_Context, value: ^f32) {
	uifw.gui_layout_begin(ctx, {0, 0, 240, 90}, .Column, 0, 70)
	_ = uifw.gui_slider_f32(ctx, "Option", "option-slider", value, 0, 100)
	uifw.gui_layout_end(ctx)
}

@(test)
test_keyboard_slider_escape_restores_engagement_snapshot :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	value := f32(25)
	id := uifw.gui_make_id(&ctx, "option-slider")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {key_enter = true})
	gui_keyboard_cancel_draw_slider(&ctx, &value)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focus_edit_id, id)

	uifw.gui_begin_frame(&ctx, {key_right = true})
	gui_keyboard_cancel_draw_slider(&ctx, &value)
	uifw.gui_end_frame(&ctx)
	testing.expect(t, value > 25)

	uifw.gui_begin_frame(&ctx, {key_escape = true})
	gui_keyboard_cancel_draw_slider(&ctx, &value)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, value, f32(25))
	testing.expect_value(t, ctx.focus_edit_id, uifw.GUI_ID_NONE)
	testing.expect_value(t, ctx.controller_snapshot_id, uifw.GUI_ID_NONE)
}

@(test)
test_keyboard_slider_accept_commits_engagement_snapshot :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	value := f32(25)
	id := uifw.gui_make_id(&ctx, "option-slider")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {key_enter = true})
	gui_keyboard_cancel_draw_slider(&ctx, &value)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {key_right = true})
	gui_keyboard_cancel_draw_slider(&ctx, &value)
	uifw.gui_end_frame(&ctx)
	edited := value
	testing.expect(t, edited > 25)

	uifw.gui_begin_frame(&ctx, {key_enter = true})
	gui_keyboard_cancel_draw_slider(&ctx, &value)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, value, edited)
	testing.expect_value(t, ctx.focus_edit_id, uifw.GUI_ID_NONE)
	testing.expect_value(t, ctx.controller_snapshot_id, uifw.GUI_ID_NONE)
}

@(test)
test_keyboard_selector_escape_restores_first_arrow_change :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	options := [?]string{"One", "Two", "Three"}
	current := 0
	id := uifw.gui_make_id(&ctx, "option-selector")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {key_right = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 70}, .Column, 0, 44)
	_ = uifw.gui_selector(&ctx, "Option", "option-selector", &current, options[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, current, 1)
	testing.expect_value(t, ctx.focus_edit_id, id)

	uifw.gui_begin_frame(&ctx, {key_escape = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 70}, .Column, 0, 44)
	_ = uifw.gui_selector(&ctx, "Option", "option-selector", &current, options[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, current, 0)
	testing.expect_value(t, ctx.focus_edit_id, uifw.GUI_ID_NONE)
}
