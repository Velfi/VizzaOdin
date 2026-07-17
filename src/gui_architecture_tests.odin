package main

import game "../packages/game"
import host "../packages/app"
import engine "../packages/engine"
import rendervk "../packages/render_vk"
import uifw "../packages/ui"

import "core:math"
import "core:os"
import "core:testing"
import sdl "vendor:sdl3"
import vk "vendor:vulkan"

@(test)
test_gui_scroll_area_draws_top_edge_fade_at_bottom :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	viewport := uifw.Rect{0, 0, 120, 100}
	scroll := f32(90)
	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_scroll_begin(&ctx, viewport, 190, &scroll)
	uifw.gui_scroll_end(&ctx)

	top, bottom := test_count_scroll_fades(ctx.commands[:], viewport)
	testing.expect_value(t, top, 1)
	testing.expect_value(t, bottom, 0)
}

@(test)
test_gui_scroll_area_draws_both_edge_fades_mid_scroll :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	viewport := uifw.Rect{0, 0, 120, 100}
	scroll := f32(45)
	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_scroll_begin(&ctx, viewport, 190, &scroll)
	uifw.gui_scroll_end(&ctx)

	top, bottom := test_count_scroll_fades(ctx.commands[:], viewport)
	testing.expect_value(t, top, 1)
	testing.expect_value(t, bottom, 1)
}

@(test)
test_gui_scroll_area_omits_edge_fades_when_content_fits :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	viewport := uifw.Rect{0, 0, 120, 100}
	scroll := f32(0)
	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_scroll_begin(&ctx, viewport, 100, &scroll)
	uifw.gui_scroll_end(&ctx)

	top, bottom := test_count_scroll_fades(ctx.commands[:], viewport)
	testing.expect_value(t, top, 0)
	testing.expect_value(t, bottom, 0)
}

@(test)
test_gui_scroll_area_smooths_visible_offset :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	scroll := f32(0)
	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, delta_time = 1.0 / 60.0})
	uifw.gui_scroll_begin(&ctx, {0, 0, 120, 100}, 190, &scroll)
	_ = uifw.gui_next_rect(&ctx, height = 40)
	uifw.gui_scroll_end(&ctx)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, wheel_delta = -4, delta_time = 1.0 / 60.0})
	uifw.gui_scroll_begin(&ctx, {0, 0, 120, 100}, 190, &scroll)
	first := uifw.gui_next_rect(&ctx, height = 40)
	uifw.gui_scroll_end(&ctx)

	testing.expect_value(t, scroll, f32(90))
	testing.expect(t, first.y < 0)
	testing.expect(t, first.y > -90)
}

@(test)
test_gui_draggable_scroll_stops_at_content_bottom :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	viewport := uifw.Rect{0, 0, 120, 100}
	scroll := f32(0)
	uifw.gui_begin_frame(&ctx, {mouse_pos = {40, 80}, mouse_pressed = true, mouse_down = true})
	uifw.gui_scroll_begin_draggable(&ctx, viewport, 190, &scroll)
	uifw.gui_scroll_end(&ctx)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {40, -1000}, mouse_down = true})
	uifw.gui_scroll_begin_draggable(&ctx, viewport, 190, &scroll)
	uifw.gui_scroll_end(&ctx)
	uifw.gui_end_frame(&ctx)

	// The last content pixel aligns with the viewport bottom; no blank space
	// below the content can be dragged into view.
	testing.expect_value(t, scroll, f32(90))
}

@(test)
test_gui_scroll_area_clips_child_interaction :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	scroll := f32(0)
	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 90}, mouse_pressed = true, mouse_released = true})
	uifw.gui_scroll_begin(&ctx, {0, 0, 160, 50}, 150, &scroll)
	_ = uifw.gui_button(&ctx, "Visible", "visible")
	clicked := uifw.gui_button(&ctx, "Clipped", "clipped")
	uifw.gui_scroll_end(&ctx)

	testing.expect(t, !clicked)
	testing.expect_value(t, ctx.hot, uifw.GUI_ID_NONE)
	testing.expect_value(t, ctx.active, uifw.GUI_ID_NONE)
}

@(test)
test_gui_nested_scroll_child_consumes_before_parent :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	parent_scroll := f32(0)
	child_scroll := f32(0)
	uifw.gui_begin_frame(&ctx, {mouse_pos = {20, 20}, wheel_delta = -4})
	uifw.gui_scroll_begin(&ctx, {0, 0, 160, 100}, 300, &parent_scroll)
	uifw.gui_scroll_begin(&ctx, {10, 10, 100, 80}, 180, &child_scroll)
	uifw.gui_scroll_end(&ctx)
	uifw.gui_scroll_end(&ctx)

	testing.expect_value(t, parent_scroll, f32(0))
	testing.expect_value(t, child_scroll, f32(100))
}

@(test)
test_gui_nested_scroll_parent_consumes_at_child_limit :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	parent_scroll := f32(40)
	child_scroll := f32(0)
	uifw.gui_begin_frame(&ctx, {mouse_pos = {20, 20}, wheel_delta = 4})
	uifw.gui_scroll_begin(&ctx, {0, 0, 160, 100}, 300, &parent_scroll)
	uifw.gui_scroll_begin(&ctx, {10, 10, 100, 80}, 180, &child_scroll)
	uifw.gui_scroll_end(&ctx)
	uifw.gui_scroll_end(&ctx)

	testing.expect_value(t, parent_scroll, f32(0))
	testing.expect_value(t, child_scroll, f32(0))

	parent_scroll = 40
	child_scroll = 100
	uifw.gui_begin_frame(&ctx, {mouse_pos = {20, 20}, wheel_delta = -4})
	uifw.gui_scroll_begin(&ctx, {0, 0, 160, 100}, 300, &parent_scroll)
	uifw.gui_scroll_begin(&ctx, {10, 10, 100, 80}, 180, &child_scroll)
	uifw.gui_scroll_end(&ctx)
	uifw.gui_scroll_end(&ctx)

	testing.expect_value(t, parent_scroll, f32(168))
	testing.expect_value(t, child_scroll, f32(100))
}

@(test)
test_gui_distribution_allocates_equal_rows :: proc(t: ^testing.T) {
	rects: [3]uifw.Rect
	uifw.gui_distribute_equal(rects[:], {0, 0, 330, 40}, .Row, 15, .Start)

	testing.expect_value(t, rects[0], uifw.Rect{0, 0, 100, 40})
	testing.expect_value(t, rects[1], uifw.Rect{115, 0, 100, 40})
	testing.expect_value(t, rects[2], uifw.Rect{230, 0, 100, 40})
}

@(test)
test_gui_primitive_commands_are_renderer_neutral :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_line(&ctx, {0, 0}, {10, 10}, ctx.style.accent, 2)
	uifw.gui_rotated_rect(&ctx, {0, 0, 24, 16}, 0.4, ctx.style.text)
	uifw.gui_ellipse(&ctx, {0, 0, 24, 16}, ctx.style.accent)
	uifw.gui_ellipse_stroke(&ctx, {0, 0, 24, 16}, ctx.style.text, 2)
	uifw.gui_image_filtered(&ctx, {0, 0, 40, 30}, 7, ctx.style.control, {brightness = 1.2, contrast = 0.8, grayscale = 0.4, blur = 0.003})
	uifw.gui_rect_blend(&ctx, {0, 0, 10, 10}, ctx.style.accent, .Screen)
	uifw.gui_shader_rect(&ctx, {0, 0, 32, 32}, .SV_Grid, {0.5, 0, 0, 1}, {1, 1, 1, 1})
	uifw.gui_refractive_glass_rect(&ctx, {0, 0, 48, 36}, uifw.gui_default_glass_style(&ctx, 6))

	testing.expect_value(t, ctx.commands[0].kind, uifw.Draw_Command_Kind.Line)
	testing.expect_value(t, ctx.commands[1].kind, uifw.Draw_Command_Kind.Filled_Quad)
	testing.expect_value(t, ctx.commands[2].kind, uifw.Draw_Command_Kind.Filled_Ellipse)
	testing.expect_value(t, ctx.commands[3].kind, uifw.Draw_Command_Kind.Stroked_Ellipse)
	testing.expect_value(t, ctx.commands[4].kind, uifw.Draw_Command_Kind.Image)
	testing.expect_value(t, ctx.commands[4].image_filter.grayscale, f32(0.4))
	testing.expect_value(t, ctx.commands[5].blend, uifw.Gui_Blend_Mode.Screen)
	testing.expect_value(t, ctx.commands[6].kind, uifw.Draw_Command_Kind.Shader_Rect)
	testing.expect_value(t, ctx.commands[6].shader_kind, uifw.Gui_Shader_Kind.SV_Grid)
	testing.expect_value(t, ctx.commands[6].color.a, f32(1))
	testing.expect_value(t, ctx.commands[7].kind, uifw.Draw_Command_Kind.Refractive_Glass_Rect)
	testing.expect(t, ctx.commands[7].glass_style.ior > 1)
	testing.expect(t, ctx.commands[7].glass_style.roughness > 0)
}

@(test)
test_gui_button_supports_keyboard_focus_activation :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	uifw.gui_begin_frame(&ctx, {})
	id := uifw.gui_make_id(&ctx, "go")
	ctx.focused = id
	uifw.gui_begin_frame(&ctx, {key_enter = true})
	clicked := uifw.gui_button_at(&ctx, id, {0, 0, 80, 40}, "Go", true)

	testing.expect(t, clicked)
}

@(test)
test_gui_tab_focus_moves_between_controls :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	first := uifw.gui_make_id(&ctx, "first")
	second := uifw.gui_make_id(&ctx, "second")

	uifw.gui_begin_frame(&ctx, {key_tab = true})
	uifw.gui_begin_panel(&ctx, {0, 0, 160, 120})
	_ = uifw.gui_button(&ctx, "First", "first")
	_ = uifw.gui_button(&ctx, "Second", "second")
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focused, first)

	uifw.gui_begin_frame(&ctx, {key_tab = true})
	uifw.gui_begin_panel(&ctx, {0, 0, 160, 120})
	_ = uifw.gui_button(&ctx, "First", "first")
	_ = uifw.gui_button(&ctx, "Second", "second")
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focused, second)
}

@(test)
test_gui_spatial_focus_moves_across_grid :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	top_left := uifw.gui_make_id(&ctx, "top_left")
	top_right := uifw.gui_make_id(&ctx, "top_right")
	bottom_right := uifw.gui_make_id(&ctx, "bottom_right")
	ctx.focused = top_left

	uifw.gui_begin_frame(&ctx, {key_right = true})
	_ = uifw.gui_button_at(&ctx, top_left, {0, 0, 80, 40}, "A", true)
	_ = uifw.gui_button_at(&ctx, top_right, {100, 0, 80, 40}, "B", true)
	_ = uifw.gui_button_at(&ctx, uifw.gui_make_id(&ctx, "bottom_left"), {0, 60, 80, 40}, "C", true)
	_ = uifw.gui_button_at(&ctx, bottom_right, {100, 60, 80, 40}, "D", true)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focused, top_right)

	uifw.gui_begin_frame(&ctx, {})
	_ = uifw.gui_button_at(&ctx, top_left, {0, 0, 80, 40}, "A", true)
	_ = uifw.gui_button_at(&ctx, top_right, {100, 0, 80, 40}, "B", true)
	_ = uifw.gui_button_at(&ctx, uifw.gui_make_id(&ctx, "bottom_left"), {0, 60, 80, 40}, "C", true)
	_ = uifw.gui_button_at(&ctx, bottom_right, {100, 60, 80, 40}, "D", true)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {key_down = true})
	_ = uifw.gui_button_at(&ctx, top_left, {0, 0, 80, 40}, "A", true)
	_ = uifw.gui_button_at(&ctx, top_right, {100, 0, 80, 40}, "B", true)
	_ = uifw.gui_button_at(&ctx, uifw.gui_make_id(&ctx, "bottom_left"), {0, 60, 80, 40}, "C", true)
	_ = uifw.gui_button_at(&ctx, bottom_right, {100, 60, 80, 40}, "D", true)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focused, bottom_right)
}

@(test)
test_gui_spatial_focus_stays_at_edges_and_moves_once_per_press :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	left := uifw.gui_make_id(&ctx, "left")
	right := uifw.gui_make_id(&ctx, "right")
	ctx.focused = left

	uifw.gui_begin_frame(&ctx, {key_right = true})
	_ = uifw.gui_button_at(&ctx, left, {0, 0, 80, 40}, "Left", true)
	_ = uifw.gui_button_at(&ctx, right, {100, 0, 80, 40}, "Right", true)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focused, right)

	uifw.gui_begin_frame(&ctx, {key_right = true})
	_ = uifw.gui_button_at(&ctx, left, {0, 0, 80, 40}, "Left", true)
	_ = uifw.gui_button_at(&ctx, right, {100, 0, 80, 40}, "Right", true)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focused, right)
}

@(test)
test_gui_spatial_focus_skips_disabled_and_clipped_controls :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	start := uifw.gui_make_id(&ctx, "start")
	disabled := uifw.gui_make_id(&ctx, "disabled")
	clipped := uifw.gui_make_id(&ctx, "clipped")
	target := uifw.gui_make_id(&ctx, "target")
	ctx.focused = start

	uifw.gui_begin_frame(&ctx, {key_right = true})
	_ = uifw.gui_button_at(&ctx, start, {0, 0, 40, 40}, "A", true)
	_ = uifw.gui_button_at(&ctx, disabled, {60, 0, 40, 40}, "B", false)
	uifw.gui_input_clip_begin(&ctx, {0, 0, 120, 50})
	_ = uifw.gui_button_at(&ctx, clipped, {140, 0, 40, 40}, "C", true)
	uifw.gui_input_clip_end(&ctx)
	_ = uifw.gui_button_at(&ctx, target, {200, 0, 40, 40}, "D", true)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focused, target)
}

@(test)
test_gui_spatial_focus_recovers_when_edit_target_disappears :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	missing := uifw.gui_make_id(&ctx, "missing_slider")
	left := uifw.gui_make_id(&ctx, "left")
	right := uifw.gui_make_id(&ctx, "right")
	ctx.focused = missing
	uifw.gui_focus_edit_begin(&ctx, missing)

	uifw.gui_begin_frame(&ctx, {})
	_ = uifw.gui_button_at(&ctx, left, {0, 0, 80, 40}, "Left", true)
	_ = uifw.gui_button_at(&ctx, right, {100, 0, 80, 40}, "Right", true)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focus_edit_id, uifw.GUI_ID_NONE)

	ctx.focused = left
	uifw.gui_begin_frame(&ctx, {key_right = true})
	_ = uifw.gui_button_at(&ctx, left, {0, 0, 80, 40}, "Left", true)
	_ = uifw.gui_button_at(&ctx, right, {100, 0, 80, 40}, "Right", true)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focused, right)
}

@(test)
test_gui_spatial_focus_does_not_interfere_with_text_entry :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	buffer: [32]u8
	length := 0
	architecture_test_set_text(buffer[:], &length, "abcd")
	text_id := uifw.gui_make_id(&ctx, "name")
	button_id := uifw.gui_make_id(&ctx, "next")
	ctx.focused = text_id
	ctx.text_edit_id = text_id
	ctx.text_edit_caret = 0
	ctx.text_edit_anchor = 0

	uifw.gui_begin_frame(&ctx, {key_right = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 100}, .Column, 0, 44)
	_ = uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length)
	_ = uifw.gui_button(&ctx, "Next", "next")
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ctx.focused, text_id)
	testing.expect_value(t, ctx.text_edit_caret, 1)
	testing.expect(t, ctx.focused != button_id)
}

@(test)
test_gui_slider_and_area_support_directional_input :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	slider_id := uifw.gui_make_id(&ctx, "amount")
	value := f32(0.5)
	ctx.focused = slider_id
	uifw.gui_focus_edit_begin(&ctx, slider_id)
	uifw.gui_begin_frame(&ctx, {key_right = true})
	uifw.gui_begin_panel(&ctx, {0, 0, 180, 80})
	testing.expect(t, uifw.gui_slider_f32(&ctx, "Amount", "amount", &value, 0, 1))
	testing.expect(t, value > 0.5)

	area_id := uifw.gui_make_id(&ctx, "area")
	area_value := uifw.Vec2{0.5, 0.5}
	ctx.focused = area_id
	uifw.gui_focus_edit_begin(&ctx, area_id)
	uifw.gui_begin_frame(&ctx, {key_right = true, key_down = true, nav_pressed_x = 1, nav_pressed_y = 1})
	testing.expect(t, uifw.gui_area_slider_f32_at(&ctx, area_id, {0, 0, 100, 100}, &area_value, {0, 0}, {1, 1}))
	testing.expect(t, area_value.x > 0.5)
	testing.expect(t, area_value.y > 0.5)
}

@(test)
test_gui_stable_id_label_preserves_focus_across_value_change :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	value := f32(1)
	uifw.gui_push_id(&ctx, "settings")
	id := uifw.gui_make_id(&ctx, "value")
	uifw.gui_pop_id(&ctx)
	ctx.focused = id
	uifw.gui_focus_edit_begin(&ctx, id)
	uifw.gui_begin_frame(&ctx, {key_right = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	uifw.gui_push_id(&ctx, "settings")
	testing.expect(t, uifw.gui_numeric_f32(&ctx, "Value: 1", "value", &value, 1, 0, 10))
	uifw.gui_pop_id(&ctx)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, value, f32(2))
	testing.expect_value(t, ctx.focused, id)

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	uifw.gui_push_id(&ctx, "settings")
	_ = uifw.gui_numeric_f32(&ctx, "Value: 2", "value", &value, 1, 0, 10)
	uifw.gui_pop_id(&ctx)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ctx.focused, id)
}

@(test)
test_gui_number_input_disabled_draws_muted_and_ignores_input :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	id := uifw.gui_make_id(&ctx, "value")
	ctx.focused = id
	ctx.active = id
	value := f32(10)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {12, 12}, mouse_down = true, mouse_pressed = true, wheel_delta = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 44}, .Column, 0, 44)
	changed := uifw.gui_numeric_f32(&ctx, "Value: 10", "value", &value, 1, 0, 100, false)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, !changed)
	testing.expect_value(t, value, f32(10))
	testing.expect_value(t, ctx.focused, uifw.GUI_ID_NONE)
	testing.expect_value(t, ctx.active, uifw.GUI_ID_NONE)

	saw_muted_label := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "Value: 10" && command.color.a == ctx.style.text_muted.a {
			saw_muted_label = true
		}
	}
	testing.expect(t, saw_muted_label)
}

@(test)
test_gui_scoped_ids_disambiguate_same_local_key :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_push_id(&ctx, "left")
	left := uifw.gui_make_id(&ctx, "shared")
	uifw.gui_pop_id(&ctx)
	uifw.gui_push_id(&ctx, "right")
	right := uifw.gui_make_id(&ctx, "shared")
	uifw.gui_pop_id(&ctx)

	testing.expect(t, left != right)
	testing.expect(t, left != uifw.GUI_ID_NONE)
	testing.expect(t, right != uifw.GUI_ID_NONE)
}

@(test)
test_gui_duplicate_interactive_ids_are_reported :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 0, 44)
	_ = uifw.gui_button(&ctx, "One", "duplicate")
	_ = uifw.gui_button(&ctx, "Two", "duplicate")
	uifw.gui_layout_end(&ctx)

	testing.expect_value(t, ctx.debug_duplicate_id_count, 1)
}

@(test)
test_gui_number_input_supports_mouse_drag_and_typing :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	value := f32(10)
	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, mouse_down = true, mouse_pressed = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	_ = uifw.gui_numeric_f32(&ctx, "Number", "number", &value, 1, 0, 100)
	uifw.gui_layout_end(&ctx)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {30, 10}, mouse_down = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	testing.expect(t, uifw.gui_numeric_f32(&ctx, "Number", "number", &value, 1, 0, 100))
	uifw.gui_layout_end(&ctx)
	testing.expect(t, value > 10)

	text_input: [32]u8
	text_input[0] = '4'
	text_input[1] = '2'
	ctx.focused = uifw.gui_make_id(&ctx, "number")
	uifw.gui_begin_frame(&ctx, {text_input = text_input, text_input_len = 2})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	testing.expect(t, uifw.gui_numeric_f32(&ctx, "Number", "number", &value, 1, 0, 100))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, value, f32(42))
}

@(test)
test_gui_number_input_arrows_choose_value_or_text_mode :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	value := f32(10)
	id := uifw.gui_make_id(&ctx, "number")
	ctx.focused = id
	uifw.gui_focus_edit_begin(&ctx, id)

	uifw.gui_begin_frame(&ctx, {key_right = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	testing.expect(t, uifw.gui_numeric_f32(&ctx, "Number", "number", &value, 1, 0, 100))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, value, f32(11))
	testing.expect_value(t, ctx.text_edit_id, uifw.GUI_ID_NONE)

	ctx.text_edit_id = id
	uifw.gui_numeric_edit_set_value(&ctx, value)
	ctx.text_edit_caret = 0
	ctx.text_edit_anchor = 0

	uifw.gui_begin_frame(&ctx, {key_right = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_numeric_f32(&ctx, "Number", "number", &value, 1, 0, 100))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, value, f32(11))
	testing.expect_value(t, ctx.text_edit_caret, 1)
}

@(test)
test_gui_number_input_drag_does_not_scrub_while_editing :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	value := f32(10)
	id := uifw.gui_make_id(&ctx, "number")
	ctx.focused = id
	ctx.active = id
	ctx.text_edit_id = id
	uifw.gui_numeric_edit_set_value(&ctx, value)
	ctx.text_edit_caret = ctx.text_edit_len
	ctx.text_edit_anchor = ctx.text_edit_len

	uifw.gui_begin_frame(&ctx, {mouse_pos = {30, 10}, mouse_down = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_numeric_f32(&ctx, "Number", "number", &value, 1, 0, 100))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, value, f32(10))
}

@(test)
test_gui_text_wrapping_balances_whitespace_breaks :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_text_wrapped_at(&ctx, {0, 0}, "alpha beta gamma delta", 220, ctx.style.text)

	testing.expect_value(t, len(ctx.commands), 2)
	testing.expect_value(t, ctx.commands[0].kind, uifw.Draw_Command_Kind.Text)
	testing.expect_value(t, ctx.commands[0].text, "alpha beta")
	testing.expect_value(t, ctx.commands[1].text, "gamma delta")
}

@(test)
test_gui_animation_value_is_retained_by_id :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	id := uifw.gui_make_id(&ctx, "anim")
	uifw.gui_begin_frame(&ctx, {delta_time = 1.0 / 60.0})
	first := uifw.gui_animate_value(&ctx, id, 0, 10)
	uifw.gui_begin_frame(&ctx, {delta_time = 1.0 / 60.0})
	second := uifw.gui_animate_value(&ctx, id, 1, 10)

	testing.expect_value(t, first, f32(0))
	testing.expect(t, second > 0)
	testing.expect(t, second < 1)
}

@(test)
test_gui_panel_emits_panel_and_text_commands :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_panel_begin(&ctx, {0, 0, 220, 120})
	uifw.gui_heading(&ctx, "Panel")
	uifw.gui_label(&ctx, "Hello")
	uifw.gui_panel_end(&ctx)

	text_count := 0
	scissor_begin_count := 0
	scissor_end_count := 0
	for command in ctx.commands {
		#partial switch command.kind {
		case .Text:
			text_count += 1
		case .Scissor_Begin:
			scissor_begin_count += 1
		case .Scissor_End:
			scissor_end_count += 1
		}
	}

	testing.expect(t, len(ctx.commands) >= 9)
	testing.expect_value(t, ctx.commands[0].kind, uifw.Draw_Command_Kind.Filled_Rounded_Rect)
	testing.expect_value(t, ctx.commands[5].kind, uifw.Draw_Command_Kind.Filled_Rounded_Rect)
	testing.expect_value(t, ctx.commands[6].kind, uifw.Draw_Command_Kind.Refractive_Glass_Rect)
	testing.expect_value(t, ctx.commands[7].kind, uifw.Draw_Command_Kind.Stroked_Rounded_Rect)
	testing.expect_value(t, text_count, 2)
	testing.expect_value(t, scissor_begin_count, 2)
	testing.expect_value(t, scissor_end_count, 2)
}

@(test)
test_gui_hsv_rgb_round_trip_primary_color :: proc(t: ^testing.T) {
	hsv := uifw.Hsv_Color{h = 0, s = 1, v = 1, a = 0.5}
	rgb := uifw.gui_hsv_to_rgb(hsv)
	testing.expect_value(t, rgb.r, f32(1))
	testing.expect_value(t, rgb.g, f32(0))
	testing.expect_value(t, rgb.b, f32(0))
	testing.expect_value(t, rgb.a, f32(0.5))

	round_trip := uifw.gui_rgb_to_hsv(rgb)
	testing.expect(t, round_trip.h >= 0)
	testing.expect(t, round_trip.h < 1)
	testing.expect(t, round_trip.s > 0.99)
	testing.expect(t, round_trip.v > 0.99)
}

@(test)
test_gui_vec2_normalized_mapping_clamps_to_range :: proc(t: ^testing.T) {
	min_value := uifw.Vec2{-10, 20}
	max_value := uifw.Vec2{10, 60}
	mapped := uifw.gui_vec2_from_normalized({0.25, 0.75}, min_value, max_value)
	testing.expect_value(t, mapped.x, f32(-5))
	testing.expect_value(t, mapped.y, f32(50))

	normalized := uifw.gui_vec2_to_normalized({20, 0}, min_value, max_value)
	testing.expect_value(t, normalized.x, f32(1))
	testing.expect_value(t, normalized.y, f32(0))
}

@(test)
test_gui_area_slider_maps_mouse_position_to_value :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	value := uifw.Vec2{}
	uifw.gui_begin_frame(&ctx, {mouse_pos = {25, 75}, mouse_down = true, mouse_pressed = true})
	changed := uifw.gui_area_slider_f32_at(&ctx, uifw.gui_make_id(&ctx, "area"), {0, 0, 100, 100}, &value, {0, 0}, {1, 1})

	testing.expect(t, changed)
	testing.expect_value(t, value.x, f32(0.25))
	testing.expect_value(t, value.y, f32(0.75))
}

@(test)
test_gui_sv_grid_and_hue_wheel_map_mouse_to_hsv :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	hsv := uifw.Hsv_Color{h = 0.5, s = 0, v = 0, a = 1}
	uifw.gui_begin_frame(&ctx, {mouse_pos = {25, 75}, mouse_down = true, mouse_pressed = true})
	testing.expect(t, uifw.gui_sv_grid_at(&ctx, uifw.gui_make_id(&ctx, "sv"), {0, 0, 100, 100}, &hsv))
	testing.expect_value(t, hsv.s, f32(0.25))
	testing.expect_value(t, hsv.v, f32(0.25))

	uifw.gui_begin_frame(&ctx, {mouse_pos = {94, 50}, mouse_down = true, mouse_pressed = true})
	testing.expect(t, uifw.gui_hue_wheel_at(&ctx, uifw.gui_make_id(&ctx, "hue"), {0, 0, 100, 100}, &hsv))
	testing.expect(t, hsv.h < 0.01 || hsv.h > 0.99)
}

@(test)
test_gui_hue_wheel_registers_focusable_and_duplicate_id :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	hsv := uifw.Hsv_Color{h = 0.5, s = 1, v = 1, a = 1}
	id := uifw.gui_make_id(&ctx, "hue")

	uifw.gui_begin_frame(&ctx, {key_tab = true})
	_ = uifw.gui_hue_wheel_at(&ctx, id, {0, 0, 100, 100}, &hsv)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focused, id)

	uifw.gui_begin_frame(&ctx, {})
	_ = uifw.gui_hue_wheel_at(&ctx, id, {0, 0, 100, 100}, &hsv)
	_ = uifw.gui_hue_wheel_at(&ctx, id, {120, 0, 100, 100}, &hsv)
	testing.expect_value(t, ctx.debug_duplicate_id_count, 1)
}

@(test)
test_gui_checkbox_switch_and_radio_group_update_state :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	checked := false
	uifw.gui_begin_frame(&ctx, {mouse_pos = {12, 12}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 240}, .Column, 0, 44)
	testing.expect(t, uifw.gui_checkbox(&ctx, "Check", "check", &checked))
	uifw.gui_layout_end(&ctx)
	testing.expect(t, checked)

	switched := false
	uifw.gui_begin_frame(&ctx, {mouse_pos = {12, 12}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 240}, .Column, 0, 44)
	testing.expect(t, uifw.gui_switch(&ctx, "Switch", "switch", &switched))
	uifw.gui_layout_end(&ctx)
	testing.expect(t, switched)

	options := [?]string{"One", "Two", "Three"}
	current := 0
	uifw.gui_begin_frame(&ctx, {mouse_pos = {12, 92}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 240}, .Column, 0, 44)
	testing.expect(t, uifw.gui_radio_group(&ctx, "Group", "group", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, current, 1)
}

@(test)
test_gui_button_uses_centered_hig_style_label_and_focus_border :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	id := uifw.gui_make_id(&ctx, "go")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {})
	_ = uifw.gui_button_at(&ctx, id, {0, 0, 100, 44}, "Go", true)

	saw_centered_label := false
	saw_focus_border := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "Go" {
			saw_centered_label = command.text_align == .Center
		}
		if command.kind == uifw.Draw_Command_Kind.Stroked_Rounded_Rect && command.color.b == ctx.style.accent.b && command.stroke_width > ctx.style.border_width {
			saw_focus_border = true
		}
	}
	testing.expect(t, saw_centered_label)
	testing.expect(t, saw_focus_border)
}

@(test)
test_gui_checkbox_selected_state_uses_accent_fill_and_contrast_check :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	checked := true
	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 44}, .Column, 0, 44)
	_ = uifw.gui_checkbox(&ctx, "Check", "check", &checked)
	uifw.gui_layout_end(&ctx)

	saw_accent_box := false
	check_line_count := 0
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Filled_Rounded_Rect && command.rect.w <= 30 && command.color.b == ctx.style.accent.b {
			saw_accent_box = true
		}
		if command.kind == uifw.Draw_Command_Kind.Line && command.color.r == f32(1) && command.color.g == f32(1) && command.color.b == f32(1) {
			check_line_count += 1
		}
	}
	testing.expect(t, saw_accent_box)
	testing.expect(t, check_line_count >= 2)
}

@(test)
test_gui_toggle_renders_as_switch_control :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	enabled := true
	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 44}, .Column, 0, 44)
	_ = uifw.gui_toggle(&ctx, "Enabled: true", "enabled", &enabled)
	uifw.gui_layout_end(&ctx)

	saw_switch_track := false
	saw_switch_knob := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Filled_Rounded_Rect && command.rect.x == f32(8) && command.rect.w >= 54 && command.color.b == ctx.style.accent.b {
			saw_switch_track = true
		}
		if command.kind == uifw.Draw_Command_Kind.Filled_Ellipse && command.rect.x > 20 && command.rect.w > 12 {
			saw_switch_knob = true
		}
	}
	testing.expect(t, saw_switch_track)
	testing.expect(t, saw_switch_knob)
}

@(test)
test_gui_radio_group_selected_option_uses_accent_ring_and_dot :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three"}
	current := 1
	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 240}, .Column, 0, 44)
	_ = uifw.gui_radio_group(&ctx, "Group", "group", &current, options[:])
	uifw.gui_layout_end(&ctx)

	saw_accent_ring := false
	saw_accent_dot := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Stroked_Ellipse && command.color.b == ctx.style.accent.b && command.stroke_width > ctx.style.border_width {
			saw_accent_ring = true
		}
		if command.kind == uifw.Draw_Command_Kind.Filled_Ellipse && command.rect.w < 14 && command.color.b == ctx.style.accent.b {
			saw_accent_dot = true
		}
	}
	testing.expect(t, saw_accent_ring)
	testing.expect(t, saw_accent_dot)
}

@(test)
test_gui_radio_group_supports_controller_navigation :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three"}
	current := 0
	group_id := uifw.gui_make_id(&ctx, "group")
	ctx.focused = group_id

	// Focus alone does not let the group capture navigation.
	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_pressed_y = 1, nav_y = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 240}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_radio_group(&ctx, "Group", "group", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, current, 0)
	testing.expect_value(t, ctx.focused, group_id)

	// Accept activates the group without changing its value.
	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true, accept_pressed = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 240}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_radio_group(&ctx, "Group", "group", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focus_edit_id, group_id)
	testing.expect_value(t, current, 0)

	// Navigation changes the selection only while activated.
	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_pressed_y = 1, nav_y = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 240}, .Column, 0, 44)
	testing.expect(t, uifw.gui_radio_group(&ctx, "Group", "group", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, current, 1)
}

@(test)
test_gui_circular_progress_emits_shader_rect :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_circular_progress(&ctx, "Progress", 0.5)

	shader_count := 0
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Shader_Rect && command.shader_kind == uifw.Gui_Shader_Kind.Circular_Progress {
			shader_count += 1
			testing.expect_value(t, command.shader_params.r, f32(0.5))
		}
	}
	testing.expect_value(t, shader_count, 1)
}

@(test)
test_gui_combobox_filters_and_selects_with_enter :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"Linear", "Nearest", "Lanczos", "Cubic"}
	current := 0
	query: [32]u8

	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Filter", "filter", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, ctx.open_panel, uifw.gui_make_id(&ctx, "filter"))

	text_input: [32]u8
	text_input[0] = 'C'
	text_input[1] = 'u'
	uifw.gui_begin_frame(&ctx, {text_input = text_input, text_input_len = 2})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Filter: open", "filter", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, ctx.open_panel, uifw.gui_make_id(&ctx, "filter"))
	testing.expect_value(t, string(query[:2]), "Cu")

	uifw.gui_begin_frame(&ctx, {key_enter = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	testing.expect(t, uifw.gui_combobox(&ctx, "Filter", "filter", &current, options[:], query[:]))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, current, 3)
	testing.expect_value(t, ctx.open_panel, uifw.GUI_ID_NONE)
}

@(test)
test_gui_combobox_disappearing_with_its_tab_releases_open_panel :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"Ink", "Stir", "Vortex"}
	current := 0
	query: [32]u8

	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Tool", "tool", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect(t, ctx.open_panel != uifw.GUI_ID_NONE)

	// Simulate switching to another controller tab, where the combobox is no
	// longer drawn. End-of-frame cleanup must release its popup ownership so B
	// can close the containing tab on the following frame.
	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.open_panel, uifw.GUI_ID_NONE)
}

@(test)
test_gui_combobox_scrolls_hidden_options :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three", "Four", "Five", "Six", "Seven"}
	current := 0
	query: [32]u8

	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 320}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 80}, wheel_delta = -3})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 320}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	found_seven := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "Seven" {
			found_seven = true
		}
	}
	testing.expect(t, found_seven)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 234}, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 320}, .Column, 0, 44)
	testing.expect(t, uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:]))
	uifw.gui_layout_end(&ctx)

	testing.expect_value(t, current, 6)
	testing.expect_value(t, ctx.open_panel, uifw.GUI_ID_NONE)
}

@(test)
test_gui_combobox_popup_draws_after_later_controls :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"Linear", "Nearest", "Lanczos", "Cubic"}
	current := 0
	query: [32]u8

	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Filter", "filter", &current, options[:], query[:])
	_ = uifw.gui_button(&ctx, "Later Control", "later")
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	later_text_index := -1
	popup_text_index := -1
	for command, i in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "Later Control" {
			later_text_index = i
		}
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "Linear" {
			popup_text_index = i
		}
	}
	testing.expect(t, later_text_index >= 0)
	testing.expect(t, popup_text_index > later_text_index)
}

@(test)
test_gui_combobox_popup_consumes_overlapping_button_click :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"Linear", "Nearest", "Lanczos", "Cubic"}
	current := 0
	query: [32]u8

	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Filter", "filter", &current, options[:], query[:])
	_ = uifw.gui_button(&ctx, "Later Control", "later")
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	popup_y := ctx.combo_popup_rect.y + ctx.style.row_height * 0.5
	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, popup_y}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Filter", "filter", &current, options[:], query[:])
	clicked_later := uifw.gui_button(&ctx, "Later Control", "later")
	uifw.gui_layout_end(&ctx)

	testing.expect(t, !clicked_later)
	testing.expect_value(t, current, 0)
	testing.expect_value(t, ctx.open_panel, uifw.GUI_ID_NONE)
}

@(test)
test_gui_overlay_input_rect_consumes_underlying_clicks :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	overlay := uifw.Rect{40, 40, 180, 120}

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_overlay_input_begin(&ctx, overlay)
	uifw.gui_overlay_input_end(&ctx)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {80, 80}, mouse_pressed = true, mouse_released = true})
	underlying_clicked := uifw.gui_button_at(&ctx, uifw.gui_make_id(&ctx, "underlying"), {60, 60, 100, 44}, "Under", true)
	uifw.gui_overlay_input_begin(&ctx, overlay)
	modal_clicked := uifw.gui_button_at(&ctx, uifw.gui_make_id(&ctx, "modal"), {60, 60, 100, 44}, "Modal", true)
	uifw.gui_overlay_input_end(&ctx)

	testing.expect(t, !underlying_clicked)
	testing.expect(t, modal_clicked)
}

@(test)
test_gui_option_arrows_change_once_per_press :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three"}
	current := 0
	id := uifw.gui_make_id(&ctx, "selector")
	ctx.focused = id
	uifw.gui_focus_edit_begin(&ctx, id)

	uifw.gui_begin_frame(&ctx, {key_right = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 0, 44)
	testing.expect(t, uifw.gui_selector(&ctx, "One", "selector", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, current, 1)

	uifw.gui_begin_frame(&ctx, {key_right = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_selector(&ctx, "Two", "selector", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, current, 1)

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 0, 44)
	_ = uifw.gui_selector(&ctx, "Two", "selector", &current, options[:])
	uifw.gui_layout_end(&ctx)

	uifw.gui_begin_frame(&ctx, {key_right = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 0, 44)
	testing.expect(t, uifw.gui_selector(&ctx, "Two", "selector", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, current, 2)
}

@(test)
test_gui_selector_focused_arrows_enter_value_navigation :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three"}
	current := 0
	id := uifw.gui_make_id(&ctx, "selector")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {key_right = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 0, 44)
	testing.expect(t, uifw.gui_selector(&ctx, "One", "selector", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, current, 1)
	testing.expect_value(t, ctx.focused, id)
	testing.expect_value(t, ctx.focus_edit_id, id)

	uifw.gui_begin_frame(&ctx, {key_right = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_selector(&ctx, "Two", "selector", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, current, 1)
}

@(test)
test_gui_selector_controller_accept_then_dpad_changes_value :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three"}
	current := 0
	id := uifw.gui_make_id(&ctx, "selector")
	ctx.focused = id
	ctx.controller_explicit_activation = true

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_selector(&ctx, "One", "selector", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focus_edit_id, id)
	testing.expect_value(t, ctx.spatial_item_count, 1)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_pressed_y = 1, nav_y = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 0, 44)
	testing.expect(t, uifw.gui_selector(&ctx, "One", "selector", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, current, 1)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_y = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_selector(&ctx, "Two", "selector", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, current, 1)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_selector(&ctx, "Two", "selector", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focus_edit_id, uifw.GUI_ID_NONE)
}

@(test)
test_gui_selector_text_is_vertically_centered :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"Linear", "Nearest", "Lanczos"}
	current := 0
	row_h := f32(72)

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 120}, .Column, 0, row_h)
	_ = uifw.gui_selector(&ctx, "Texture Filtering: Linear", "selector", &current, options[:])
	uifw.gui_layout_end(&ctx)

	expected_y := max((row_h - ctx.style.body_text_height) * 0.5, 0)
	found := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "Texture Filtering: Linear" {
			found = true
			testing.expect(t, test_approx_f32(command.rect.y, expected_y))
		}
	}
	testing.expect(t, found)
}

@(test)
test_gui_combobox_popup_arrows_change_highlight_once_per_press :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three"}
	current := 0
	query: [32]u8

	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, ctx.combo_highlight, 0)

	uifw.gui_begin_frame(&ctx, {key_down = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, ctx.combo_highlight, 1)

	uifw.gui_begin_frame(&ctx, {key_down = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, ctx.combo_highlight, 1)
}

@(test)
test_gui_combobox_keyboard_opens_without_changing_selection :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three"}
	current := 1
	query: [32]u8
	id := uifw.gui_make_id(&ctx, "pick")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {key_space = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:]))
	uifw.gui_layout_end(&ctx)

	testing.expect_value(t, current, 1)
	testing.expect_value(t, ctx.open_panel, id)
	testing.expect_value(t, ctx.combo_highlight, 1)
}

@(test)
test_gui_combobox_enter_opens_without_changing_selection :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three"}
	current := 1
	query: [32]u8
	id := uifw.gui_make_id(&ctx, "pick")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {key_enter = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, current, 1)
	testing.expect_value(t, ctx.open_panel, id)
	testing.expect_value(t, ctx.combo_highlight, 1)
}

@(test)
test_gui_combobox_focused_arrows_cycle_then_confirm_opens_menu :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three"}
	current := 0
	query: [32]u8
	id := uifw.gui_make_id(&ctx, "pick")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {key_right = true})
	testing.expect(t, uifw.gui_combobox_cycle_focused(&ctx, id, &current, len(options)))
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, current, 1)
	testing.expect_value(t, ctx.open_panel, uifw.GUI_ID_NONE)

	uifw.gui_begin_frame(&ctx, {key_enter = true})
	testing.expect(t, !uifw.gui_combobox_cycle_focused(&ctx, id, &current, len(options)))
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, current, 1)
	testing.expect_value(t, ctx.open_panel, id)
}

@(test)
test_gui_combobox_controller_accept_opens_then_selects_after_navigation :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three"}
	current := 0
	query: [32]u8
	id := uifw.gui_make_id(&ctx, "pick")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, current, 0)
	testing.expect_value(t, ctx.open_panel, id)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, current, 0)
	testing.expect_value(t, ctx.open_panel, id)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_pressed_y = 1, nav_y = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.combo_highlight, 1)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 220}, .Column, 0, 44)
	testing.expect(t, uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, current, 1)
	testing.expect_value(t, ctx.open_panel, uifw.GUI_ID_NONE)
}

@(test)
test_gui_combobox_keyboard_highlight_scrolls_into_view :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three", "Four", "Five", "Six", "Seven"}
	current := 0
	query: [32]u8

	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 320}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)

	for i in 0 ..< 6 {
		uifw.gui_begin_frame(&ctx, {key_down = true})
		uifw.gui_layout_begin(&ctx, {0, 0, 220, 320}, .Column, 0, 44)
		_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
		uifw.gui_layout_end(&ctx)

		uifw.gui_begin_frame(&ctx, {})
		uifw.gui_layout_begin(&ctx, {0, 0, 220, 320}, .Column, 0, 44)
		_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
		uifw.gui_layout_end(&ctx)
	}

	testing.expect_value(t, ctx.combo_highlight, 6)
	testing.expect(t, ctx.combo_scroll > 0)
}

@(test)
test_gui_combobox_popup_opens_above_when_below_is_cramped :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three", "Four", "Five"}
	current := 0
	query: [32]u8

	uifw.gui_begin_frame(&ctx, {window_width = 300, window_height = 180, mouse_pos = {10, 134}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 132, 220, 44}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ctx.combo_popup_visible)
	testing.expect(t, ctx.combo_popup_rect.y < 132)
}

@(test)
test_gui_combobox_long_popup_uses_available_viewport_height :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve"}
	current := 5
	query: [32]u8

	uifw.gui_begin_frame(&ctx, {window_width = 300, window_height = 360, mouse_pos = {10, 162}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 140, 220, 44}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ctx.combo_popup_visible)
	testing.expect(t, ctx.combo_popup_rect.h > ctx.style.row_height * 5)
	testing.expect(t, ctx.combo_popup_rect.y >= ctx.style.spacing_1)
	testing.expect(t, ctx.combo_popup_rect.y + ctx.combo_popup_rect.h <= f32(360) - ctx.style.spacing_1)
}

@(test)
test_gui_combobox_long_popup_aligns_selected_row_to_control :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve"}
	current := 5
	query: [32]u8
	control_y := f32(140)
	row_h := f32(44)

	uifw.gui_begin_frame(&ctx, {window_width = 300, window_height = 360, mouse_pos = {10, control_y + row_h * 0.5}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, control_y, 220, row_h}, .Column, 0, row_h)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	expected_text_y := control_y + max((row_h - ctx.style.body_text_height) * 0.5, 0)
	selected_row_count := 0
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "Six" {
			if test_approx_f32(command.rect.y, expected_text_y) {
				selected_row_count += 1
			}
		}
	}
	testing.expect(t, selected_row_count >= 2)
	testing.expect(t, ctx.combo_scroll > 0)
}

@(test)
test_gui_combobox_long_popup_does_not_move_when_hover_changes :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve"}
	current := 5
	query: [32]u8
	control := uifw.Rect{0, 140, 220, 44}

	uifw.gui_begin_frame(&ctx, {window_width = 300, window_height = 360, mouse_pos = {10, 162}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, control, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	first_popup := ctx.combo_popup_rect

	hover := uifw.Vec2{first_popup.x + 10, first_popup.y + ctx.style.row_height * 0.5}
	uifw.gui_begin_frame(&ctx, {window_width = 300, window_height = 360, mouse_pos = hover, mouse_moved = true})
	uifw.gui_layout_begin(&ctx, control, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ctx.combo_highlight != current)
	testing.expect_value(t, ctx.combo_popup_rect, first_popup)
}

@(test)
test_gui_selector_tooltips_draw_after_selector :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two"}
	current := 0
	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 120}, .Column, 0, 44)
	_ = uifw.gui_selector(&ctx, "One", "selector", &current, options[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	selector_text_index := -1
	tooltip_text_index := -1
	for command, i in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "One" {
			selector_text_index = i
		}
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "Previous option" {
			tooltip_text_index = i
		}
	}
	testing.expect(t, selector_text_index >= 0)
	testing.expect(t, tooltip_text_index > selector_text_index)
}

@(test)
test_gui_tooltip_respects_input_clip :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}})
	uifw.gui_input_clip_begin(&ctx, {0, 40, 100, 40})
	uifw.gui_tooltip(&ctx, {0, 0, 40, 40}, "Clipped")
	uifw.gui_input_clip_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, !ctx.tooltip_visible)
}

@(test)
test_gui_combobox_popup_nudges_inside_viewport :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"Linear", "Nearest", "Lanczos", "Cubic"}
	current := 0
	query: [32]u8

	uifw.gui_begin_frame(&ctx, {window_width = 100, window_height = 100, mouse_pos = {82, 82}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {80, 80, 120, 120}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Filter", "filter", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ctx.combo_popup_visible)
	popup := ctx.combo_popup_rect
	testing.expect(t, popup.x >= 4)
	testing.expect(t, popup.y >= 4)
	testing.expect(t, popup.x + popup.w <= 96)
	testing.expect(t, popup.y + popup.h <= 96)
}

@(test)
test_gui_combobox_popup_ignores_stale_mouse_when_pointer_disabled :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two", "Three"}
	current := 0
	query: [32]u8

	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 44}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ctx.combo_popup_visible)
	testing.expect_value(t, ctx.combo_highlight, 0)

	row_y := ctx.combo_popup_rect.y + ctx.style.row_height + 1
	uifw.gui_begin_frame(&ctx, {active_device = .Controller, pointer_enabled = false, mouse_pos = {10, row_y}})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 44}, .Column, 0, 44)
	_ = uifw.gui_combobox(&ctx, "Pick", "pick", &current, options[:], query[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ctx.combo_highlight, 0)
}

@(test)
test_gui_tooltip_nudges_inside_viewport :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	options := [?]string{"One", "Two"}
	current := 0
	uifw.gui_begin_frame(&ctx, {window_width = 120, window_height = 70, mouse_pos = {95, 30}})
	uifw.gui_layout_begin(&ctx, {20, 20, 80, 44}, .Column, 0, 44)
	_ = uifw.gui_selector(&ctx, "One", "selector", &current, options[:])
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ctx.tooltip_visible)
	tooltip := ctx.tooltip_rect
	testing.expect(t, tooltip.x >= 4)
	testing.expect(t, tooltip.y >= 4)
	testing.expect(t, tooltip.x + tooltip.w <= 116)
	testing.expect(t, tooltip.y + tooltip.h <= 66)
}

@(test)
test_gui_tooltip_width_scales_with_large_text :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ctx.style.body_char_width = 30
	ctx.style.body_line_height = 60
	uifw.gui_begin_frame(&ctx, {window_width = 1680, window_height = 570, mouse_pos = {20, 20}})
	uifw.gui_tooltip(&ctx, {0, 0, 80, 80}, "Sensor Angle and Distance set how wide and how far ahead each agent can sense trails.")

	testing.expect(t, ctx.tooltip_visible)
	testing.expect(t, ctx.tooltip_rect.w > 420)
	testing.expect(t, ctx.tooltip_rect.h <= 570 - ctx.style.spacing_1 * 2)
}

@(test)
test_gui_text_input_accepts_text_and_backspace :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	buffer: [32]u8
	length := 0

	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	_ = uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length)
	uifw.gui_layout_end(&ctx)

	text_input: [32]u8
	text_input[0] = 'C'
	text_input[1] = 'u'
	uifw.gui_begin_frame(&ctx, {text_input = text_input, text_input_len = 2})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	testing.expect(t, uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, string(buffer[:length]), "Cu")

	uifw.gui_begin_frame(&ctx, {key_backspace = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	testing.expect(t, uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, string(buffer[:length]), "C")
}

architecture_test_set_text :: proc(buffer: []u8, length: ^int, text: string) {
	bytes := transmute([]u8)text
	length^ = min(len(buffer), len(bytes))
	for i in 0 ..< length^ {
		buffer[i] = bytes[i]
	}
	if length^ < len(buffer) {
		buffer[length^] = 0
	}
}

architecture_test_input_bytes :: proc(text: string) -> (input: [32]u8, length: int) {
	bytes := transmute([]u8)text
	length = min(len(input), len(bytes))
	for i in 0 ..< length {
		input[i] = bytes[i]
	}
	return
}

architecture_test_clipboard_bytes :: proc(text: string) -> (input: [256]u8, length: int) {
	bytes := transmute([]u8)text
	length = min(len(input), len(bytes))
	for i in 0 ..< length {
		input[i] = bytes[i]
	}
	return
}

@(test)
test_gui_text_input_inserts_at_caret :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	buffer: [32]u8
	length := 0
	architecture_test_set_text(buffer[:], &length, "abcd")
	id := uifw.gui_make_id(&ctx, "name")
	ctx.focused = id
	ctx.text_edit_id = id
	ctx.text_edit_caret = 2
	ctx.text_edit_anchor = 2
	text_input, text_len := architecture_test_input_bytes("X")

	uifw.gui_begin_frame(&ctx, {text_input = text_input, text_input_len = text_len})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	testing.expect(t, uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, string(buffer[:length]), "abXcd")
	testing.expect_value(t, ctx.text_edit_caret, 3)
}

@(test)
test_gui_text_input_moves_home_end_and_shift_selects :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	buffer: [32]u8
	length := 0
	architecture_test_set_text(buffer[:], &length, "abcd")
	id := uifw.gui_make_id(&ctx, "name")
	ctx.focused = id
	ctx.text_edit_id = id
	ctx.text_edit_caret = 4
	ctx.text_edit_anchor = 4

	uifw.gui_begin_frame(&ctx, {key_home = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	_ = uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length)
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, ctx.text_edit_caret, 0)
	testing.expect_value(t, ctx.text_edit_anchor, 0)

	uifw.gui_begin_frame(&ctx, {key_end = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	_ = uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length)
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, ctx.text_edit_caret, 4)

	ctx.text_edit_caret = 1
	ctx.text_edit_anchor = 1
	uifw.gui_begin_frame(&ctx, {key_right = true, key_shift = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	_ = uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length)
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, ctx.text_edit_anchor, 1)
	testing.expect_value(t, ctx.text_edit_caret, 2)
}

@(test)
test_gui_text_input_replaces_selection_and_deletes_selection :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	buffer: [32]u8
	length := 0
	architecture_test_set_text(buffer[:], &length, "abcd")
	id := uifw.gui_make_id(&ctx, "name")
	ctx.focused = id
	ctx.text_edit_id = id
	ctx.text_edit_caret = 1
	ctx.text_edit_anchor = 3
	text_input, text_len := architecture_test_input_bytes("Z")

	uifw.gui_begin_frame(&ctx, {text_input = text_input, text_input_len = text_len})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	testing.expect(t, uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, string(buffer[:length]), "aZd")

	architecture_test_set_text(buffer[:], &length, "abcd")
	ctx.focused = id
	ctx.text_edit_id = id
	ctx.text_edit_caret = 3
	ctx.text_edit_anchor = 1
	uifw.gui_begin_frame(&ctx, {key_backspace = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	testing.expect(t, uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, string(buffer[:length]), "ad")

	architecture_test_set_text(buffer[:], &length, "abcd")
	ctx.focused = id
	ctx.text_edit_id = id
	ctx.text_edit_caret = 1
	ctx.text_edit_anchor = 3
	uifw.gui_begin_frame(&ctx, {key_delete = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	testing.expect(t, uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, string(buffer[:length]), "ad")
}

@(test)
test_gui_text_input_select_all_cut_copy_and_paste :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	buffer: [32]u8
	length := 0
	architecture_test_set_text(buffer[:], &length, "abcd")
	id := uifw.gui_make_id(&ctx, "name")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {key_ctrl = true, key_a = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	_ = uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length)
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, ctx.text_edit_anchor, 0)
	testing.expect_value(t, ctx.text_edit_caret, 4)

	uifw.gui_begin_frame(&ctx, {key_ctrl = true, key_c = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	_ = uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length)
	uifw.gui_layout_end(&ctx)
	testing.expect(t, ctx.clipboard_set_pending)
	testing.expect_value(t, string(ctx.clipboard_set_text[:ctx.clipboard_set_len]), "abcd")

	uifw.gui_begin_frame(&ctx, {key_ctrl = true, key_x = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	testing.expect(t, uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, length, 0)

	clipboard, clipboard_len := architecture_test_clipboard_bytes("xy")
	uifw.gui_begin_frame(&ctx, {key_ctrl = true, key_v = true, clipboard_paste = clipboard, clipboard_paste_len = clipboard_len})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	testing.expect(t, uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, string(buffer[:length]), "xy")
}

@(test)
test_gui_text_input_click_places_caret :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	buffer: [32]u8
	length := 0
	architecture_test_set_text(buffer[:], &length, "abcd")
	click_x := f32(14) + uifw.gui_text_width(&ctx, "ab") + 1

	uifw.gui_begin_frame(&ctx, {mouse_pos = {click_x, 10}, mouse_pressed = true, mouse_down = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	_ = uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length)
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, ctx.text_edit_caret, 2)
}

@(test)
test_gui_text_input_word_and_platform_navigation :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	buffer: [32]u8
	length := 0
	architecture_test_set_text(buffer[:], &length, "alpha beta")
	id := uifw.gui_make_id(&ctx, "name")
	ctx.focused = id
	ctx.text_edit_id = id
	ctx.text_edit_caret = length
	ctx.text_edit_anchor = length

	uifw.gui_begin_frame(&ctx, {key_ctrl = true, key_left = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	_ = uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length)
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, ctx.text_edit_caret, 6)
	testing.expect_value(t, ctx.text_edit_anchor, 6)

	uifw.gui_begin_frame(&ctx, {key_super = true, key_left = true, key_shift = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	_ = uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length)
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, ctx.text_edit_caret, 0)
	testing.expect_value(t, ctx.text_edit_anchor, 6)
}

@(test)
test_gui_text_input_word_delete :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	buffer: [32]u8
	length := 0
	architecture_test_set_text(buffer[:], &length, "alpha beta")
	id := uifw.gui_make_id(&ctx, "name")
	ctx.focused = id
	ctx.text_edit_id = id
	ctx.text_edit_caret = length
	ctx.text_edit_anchor = length

	uifw.gui_begin_frame(&ctx, {key_ctrl = true, key_backspace = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	testing.expect(t, uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, string(buffer[:length]), "alpha ")
	testing.expect_value(t, ctx.text_edit_caret, 6)
}

@(test)
test_gui_text_input_focused_empty_field_draws_placeholder_and_accent_caret :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	buffer: [32]u8
	length := 0
	id := uifw.gui_make_id(&ctx, "name")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	_ = uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length)
	uifw.gui_layout_end(&ctx)

	saw_placeholder := false
	saw_focused_stroke := false
	saw_caret := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "Name" {
			saw_placeholder = true
			testing.expect(t, command.color.a < ctx.style.text.a)
		}
		if command.kind == uifw.Draw_Command_Kind.Stroked_Rounded_Rect && command.color.b == ctx.style.accent.b && command.stroke_width > ctx.style.border_width {
			saw_focused_stroke = true
		}
		if command.kind == uifw.Draw_Command_Kind.Filled_Rect && command.color.b == ctx.style.accent.b && command.rect.w >= 2 {
			saw_caret = true
		}
	}
	testing.expect(t, saw_placeholder)
	testing.expect(t, saw_focused_stroke)
	testing.expect(t, saw_caret)
}

@(test)
test_gui_text_input_clear_button_draws_for_focused_text_and_clears :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	buffer: [32]u8
	length := 0
	architecture_test_set_text(buffer[:], &length, "abcd")
	id := uifw.gui_make_id(&ctx, "name")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	_ = uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length)
	uifw.gui_layout_end(&ctx)

	saw_clear_circle := false
	clear_line_count := 0
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Filled_Ellipse && command.rect.x > 200 {
			saw_clear_circle = true
		}
		if command.kind == uifw.Draw_Command_Kind.Line && command.p0.x > 200 && command.p1.x > 200 {
			clear_line_count += 1
		}
	}
	testing.expect(t, saw_clear_circle)
	testing.expect(t, clear_line_count >= 2)

	clear := uifw.gui_text_input_clear_rect(&ctx, {0, 0, 240, 44})
	uifw.gui_begin_frame(&ctx, {mouse_pos = {clear.x + clear.w * 0.5, clear.y + clear.h * 0.5}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	testing.expect(t, uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, length, 0)
	testing.expect_value(t, string(buffer[:length]), "")
	testing.expect_value(t, ctx.text_edit_caret, 0)
	testing.expect_value(t, ctx.text_edit_anchor, 0)
}

@(test)
test_gui_text_input_value_clips_before_trailing_clear_button :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	buffer: [32]u8
	length := 0
	architecture_test_set_text(buffer[:], &length, "abcdef")
	id := uifw.gui_make_id(&ctx, "name")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 44}, .Column, 0, 44)
	_ = uifw.gui_text_input(&ctx, "Name", "name", buffer[:], &length)
	uifw.gui_layout_end(&ctx)

	clear_hit := uifw.gui_text_input_clear_hit_rect(&ctx, {0, 0, 240, 44})
	last_scissor: uifw.Rect
	saw_value := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Scissor_Begin {
			last_scissor = command.rect
		}
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "abcdef" {
			saw_value = true
			testing.expect(t, last_scissor.x + last_scissor.w <= clear_hit.x)
		}
	}
	testing.expect(t, saw_value)
}

@(test)
test_gui_number_input_paste_filters_to_numeric_text :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	value := f32(1)
	id := uifw.gui_make_id(&ctx, "number")
	ctx.focused = id
	clipboard, clipboard_len := architecture_test_clipboard_bytes("42x")

	uifw.gui_begin_frame(&ctx, {key_ctrl = true, key_v = true, clipboard_paste = clipboard, clipboard_paste_len = clipboard_len})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	testing.expect(t, uifw.gui_numeric_f32(&ctx, "Number", "number", &value, 1, 0, 100))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, value, f32(42))
	testing.expect_value(t, string(ctx.text_edit_buffer[:ctx.text_edit_len]), "42")
}

@(test)
test_color_scheme_editor_builds_lut_from_preset :: proc(t: ^testing.T) {
	editor: game.Color_Scheme_Editor_State
	game.color_scheme_editor_init(&editor)
	game.color_scheme_editor_apply_preset(&editor, 4)
	scheme := game.color_scheme_editor_build_scheme(&editor, "CUSTOM_Test")

	testing.expect_value(t, scheme.name, "CUSTOM_Test")
	testing.expect_value(t, scheme.red[0], u8(0x44))
	testing.expect_value(t, scheme.green[0], u8(0x01))
	testing.expect_value(t, scheme.blue[0], u8(0x54))
	testing.expect_value(t, scheme.red[255], u8(0xfd))
	testing.expect_value(t, scheme.green[255], u8(0xe7))
	testing.expect_value(t, scheme.blue[255], u8(0x25))
}

@(test)
test_color_scheme_editor_jzazbz_and_hsluv_interpolation_are_real :: proc(t: ^testing.T) {
	red := uifw.Color{1, 0, 0, 1}
	green := uifw.Color{0, 1, 0, 1}
	oklab := game.color_scheme_editor_interpolate(red, green, 0.5, 2)
	jzazbz := game.color_scheme_editor_interpolate(red, green, 0.5, 3)
	hsluv := game.color_scheme_editor_interpolate(red, green, 0.5, 4)

	test_expect_color_near_rgb8(t, jzazbz, 0xd3, 0xa7, 0x03, 2)
	test_expect_color_near_rgb8(t, hsluv, 0xc9, 0xab, 0x00, 2)
	testing.expect(t, !test_colors_match_rgb8(jzazbz, oklab))
	testing.expect(t, !test_colors_match_rgb8(hsluv, oklab))
}

@(test)
test_color_scheme_selector_filters_and_selects_scheme :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	editor: game.Color_Scheme_Editor_State
	game.color_scheme_editor_init(&editor)
	color_name: game.Color_Scheme_Name
	game.color_scheme_name_set(&color_name, "MATPLOTLIB_bone")
	reversed := false

	uifw.gui_begin_frame(&ctx, {mouse_pos = {80, 10}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 220}, .Column, 0, 44)
	_ = game.color_scheme_editor_draw_selector(&ctx, &editor, "test_color", &color_name, &reversed)
	uifw.gui_layout_end(&ctx)

	text_input: [32]u8
	copy(text_input[:], "viridis")
	uifw.gui_begin_frame(&ctx, {text_input = text_input, text_input_len = len("viridis")})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 220}, .Column, 0, 44)
	_ = game.color_scheme_editor_draw_selector(&ctx, &editor, "test_color", &color_name, &reversed)
	uifw.gui_layout_end(&ctx)

	uifw.gui_begin_frame(&ctx, {key_enter = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 220}, .Column, 0, 44)
	testing.expect(t, game.color_scheme_editor_draw_selector(&ctx, &editor, "test_color", &color_name, &reversed))
	uifw.gui_layout_end(&ctx)

	testing.expect_value(t, game.color_scheme_name_get(&color_name), "MATPLOTLIB_viridis")
	testing.expect_value(t, ctx.open_panel, uifw.GUI_ID_NONE)
}

@(test)
test_color_scheme_selector_side_arrows_cycle_schemes :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	editor: game.Color_Scheme_Editor_State
	game.color_scheme_editor_init(&editor)
	color_names := game.color_scheme_available_names_cached()
	if len(color_names) <= 1 {
		testing.expect(t, false)
		return
	}

	start_index := min(1, len(color_names) - 1)
	next_index := (start_index + 1) % len(color_names)
	color_name: game.Color_Scheme_Name
	game.color_scheme_name_set(&color_name, color_names[start_index])
	reversed := false

	uifw.gui_begin_frame(&ctx, {mouse_pos = {240, 22}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 220}, .Column, 0, 44)
	testing.expect(t, game.color_scheme_editor_draw_selector(&ctx, &editor, "test_color_arrows", &color_name, &reversed))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, game.color_scheme_name_get(&color_name), color_names[next_index])

	uifw.gui_begin_frame(&ctx, {mouse_pos = {20, 22}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 220}, .Column, 0, 44)
	testing.expect(t, game.color_scheme_editor_draw_selector(&ctx, &editor, "test_color_arrows", &color_name, &reversed))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, game.color_scheme_name_get(&color_name), color_names[start_index])
}

@(test)
test_color_scheme_selector_hides_modal_editor_entry_point :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	editor: game.Color_Scheme_Editor_State
	game.color_scheme_editor_init(&editor)
	color_name: game.Color_Scheme_Name
	game.color_scheme_name_set(&color_name, "MATPLOTLIB_bone")
	reversed := false

	uifw.gui_begin_frame(&ctx, {window_width = 900, window_height = 700, mouse_pos = {20, 108}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 220}, .Column, 0, 44)
	_ = game.color_scheme_editor_draw_selector(&ctx, &editor, "test_color_modal", &color_name, &reversed)
	uifw.gui_layout_end(&ctx)

	saw_edit_button := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "Edit Color Scheme" {
			saw_edit_button = true
		}
	}
	testing.expect(t, !saw_edit_button)
	testing.expect(t, !editor.modal_open)

	editor.modal_open = true
	uifw.gui_begin_frame(&ctx, {window_width = 900, window_height = 700})
	testing.expect(t, !game.color_scheme_editor_draw_modal(&ctx, &editor, &color_name))
	testing.expect(t, !editor.modal_open)
}

@(test)
test_color_scheme_modal_cancel_restores_original_scheme :: proc(t: ^testing.T) {
	editor: game.Color_Scheme_Editor_State
	game.color_scheme_editor_init(&editor)
	color_name: game.Color_Scheme_Name
	game.color_scheme_name_set(&color_name, "MATPLOTLIB_bone")
	game.color_scheme_name_set(&editor.modal_original_name, "MATPLOTLIB_bone")
	editor.modal_open = true
	game.color_scheme_name_set(&color_name, "MATPLOTLIB_viridis")

	game.color_scheme_editor_cancel_modal(&editor, &color_name)

	testing.expect(t, !editor.modal_open)
	testing.expect_value(t, game.color_scheme_name_get(&color_name), "MATPLOTLIB_bone")
}

@(test)
test_gui_controller_accept_activates_focused_button :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	id := uifw.gui_make_id(&ctx, "play")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, pointer_enabled = true, accept = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 200, 80}, .Column, 0, 44)
	testing.expect(t, uifw.gui_button(&ctx, "Play", "play"))
	uifw.gui_layout_end(&ctx)
}

@(test)
test_gui_controller_virtual_cursor_hovers_button :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	uifw.gui_begin_frame(&ctx, {
		active_device = .Controller,
		pointer_enabled = true,
		mouse_pos = {20, 20},
	})
	uifw.gui_layout_begin(&ctx, {0, 0, 200, 80}, .Column, 0, 44)
	id := uifw.gui_make_id(&ctx, "play")
	_ = uifw.gui_button(&ctx, "Play", "play")
	uifw.gui_layout_end(&ctx)

	testing.expect_value(t, ctx.hot, id)
}

@(test)
test_app_ui_controller_trigger_mouse_state_reaches_simulation_filter :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)
	ui.mode = .Flow_Field
	ui.simulation_shell.show_ui = false
	ui.simulation_shell.controls_visible = false

	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, {
		active_device = .Controller,
		pointer_enabled = true,
		window_width = 1920,
		window_height = 1080,
		mouse_pos = {960, 540},
		mouse_down = true,
		mouse_pressed = true,
		mouse_button = 3,
		actions = {secondary = {down = true, pressed = true, owner = .Controller}},
	})

	testing.expect(t, filtered.mouse_down)
	testing.expect(t, filtered.mouse_pressed)
	testing.expect_value(t, filtered.mouse_button, u32(3))
	testing.expect(t, filtered.actions.secondary.down)
}

@(test)
test_app_ui_active_controller_disconnect_pauses_simulation :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)
	ui.mode = .Flow_Field
	ui.flow_field.paused = false
	ui.simulation_shell.show_ui = false
	ui.simulation_shell.controls_visible = false

	uifw.gui_begin_frame(&ctx, {
		active_device = .Controller,
		controller_disconnected = true,
	})
	game.app_ui_handle_controller_disconnect(&ui, &ctx)

	testing.expect(t, ui.flow_field.paused)
	testing.expect(t, ui.simulation_shell.show_ui)
	testing.expect(t, ui.simulation_shell.controls_visible)
}

@(test)
test_gui_pointer_uses_previous_completed_geometry :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	id := uifw.gui_make_id(&ctx, "moving")
	uifw.gui_begin_frame(&ctx, {window_width = 400, window_height = 300})
	_ = uifw.gui_button_at(&ctx, id, {10, 10, 100, 40}, "Moving", true)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {window_width = 400, window_height = 300, mouse_pos = {12, 20}, mouse_moved = true})
	_ = uifw.gui_button_at(&ctx, id, {14, 10, 100, 40}, "Moving", true)
	testing.expect_value(t, ctx.hot, id)
	uifw.gui_end_frame(&ctx)
}

@(test)
test_gui_discontinuous_control_transition_suppresses_pointer_interaction :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	id := uifw.Gui_Id(91)
	uifw.gui_begin_frame(&ctx, {window_width = 400, window_height = 300})
	_ = uifw.gui_control(&ctx, id, {10, 10, 100, 40})
	uifw.gui_end_frame(&ctx)
	uifw.gui_begin_frame(&ctx, {window_width = 400, window_height = 300, mouse_pos = {20, 20}, mouse_moved = true})
	_ = uifw.gui_control(&ctx, id, {200, 10, 100, 40})
	testing.expect(t, ctx.hot != id)
	uifw.gui_end_frame(&ctx)
}

@(test)
test_gui_new_widget_waits_for_stable_geometry_after_bootstrap :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	uifw.gui_begin_frame(&ctx, {window_width = 400, window_height = 300})
	_ = uifw.gui_button_at(&ctx, uifw.gui_make_id(&ctx, "existing"), {10, 10, 100, 40}, "Existing", true)
	uifw.gui_end_frame(&ctx)

	new_id := uifw.gui_make_id(&ctx, "new")
	uifw.gui_begin_frame(&ctx, {window_width = 400, window_height = 300, mouse_pos = {220, 20}, mouse_moved = true})
	_ = uifw.gui_button_at(&ctx, new_id, {200, 10, 100, 40}, "New", true)
	testing.expect(t, ctx.hot != new_id)
	uifw.gui_end_frame(&ctx)
}

@(test)
test_gui_semantic_tree_tracks_layout_hierarchy_without_retaining_tree_pointers :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	uifw.gui_begin_frame(&ctx, {window_width = 400, window_height = 300})
	uifw.gui_layout_begin(&ctx, {0, 0, 300, 200}, .Column, 8, 40)
	id := uifw.gui_make_id(&ctx, "semantic_child")
	_ = uifw.gui_button_at(&ctx, id, {10, 10, 100, 40}, "Child", true)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	diagnostics := uifw.gui_semantic_diagnostics(&ctx)
	testing.expect_value(t, diagnostics.node_count, 2)
	testing.expect_value(t, diagnostics.layout_passes, 1)
	testing.expect_value(t, ctx.semantic_nodes[0].kind, uifw.Gui_Semantic_Node_Kind.Stack)
	testing.expect_value(t, ctx.semantic_nodes[1].parent, 0)
	testing.expect_value(t, ctx.semantic_nodes[1].id, id)
}

@(test)
test_gui_semantic_unstable_layout_suppresses_next_pointer_snapshot :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	id := uifw.Gui_Id(77)
	uifw.gui_begin_frame(&ctx, {window_width = 400, window_height = 300})
	_ = uifw.gui_control(&ctx, id, {10, 10, -1, 40})
	uifw.gui_end_frame(&ctx)
	diagnostics := uifw.gui_semantic_diagnostics(&ctx)
	testing.expect_value(t, diagnostics.layout_passes, 2)
	testing.expect_value(t, diagnostics.unstable_node_count, 1)
	testing.expect_value(t, ctx.interaction_rect_count, 1)
	testing.expect(t, !ctx.interaction_rects[0].enabled)
}

@(test)
test_gui_focus_ownership_restores_layers_and_deduplicates_modal_claims :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	canvas := uifw.Gui_Id(1)
	deck := uifw.Gui_Id(2)
	control := uifw.Gui_Id(3)
	modal := uifw.Gui_Id(4)
	uifw.gui_focus_owner_claim(&ctx, .Canvas, canvas)
	uifw.gui_focus_owner_claim(&ctx, .Control_Deck, deck)
	uifw.gui_focus_owner_claim(&ctx, .Active_Control, control)
	uifw.gui_focus_owner_release(&ctx, .Active_Control, control)
	testing.expect_value(t, ctx.focus_ownership.active_layer, uifw.Gui_Focus_Layer.Control_Deck)
	testing.expect_value(t, ctx.focus_ownership.active_owner, deck)
	uifw.gui_focus_owner_push_modal(&ctx, modal)
	uifw.gui_focus_owner_push_modal(&ctx, modal)
	testing.expect_value(t, ctx.focus_ownership.stack_count, 1)
	testing.expect_value(t, ctx.focus_ownership.active_layer, uifw.Gui_Focus_Layer.Modal)
	uifw.gui_focus_owner_pop_modal(&ctx)
	testing.expect_value(t, ctx.focus_ownership.active_layer, uifw.Gui_Focus_Layer.Control_Deck)
	testing.expect_value(t, ctx.focus_ownership.active_owner, deck)
}
