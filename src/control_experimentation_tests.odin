package main

import game "../packages/game"
import host "../packages/app"
import uifw "../packages/ui"

import "core:testing"

control_experimentation_draw_slider :: proc(ctx: ^uifw.Gui_Context, value: ^f32, help: string = "") {
	uifw.gui_layout_begin(ctx, {12, 12, 280, 100}, .Column, 0, 70)
	_ = uifw.gui_slider_f32(ctx, "Beta", "beta", value, 0, 100)
	if len(help) > 0 {
		uifw.gui_tooltip_for_id(ctx, uifw.gui_make_id(ctx, "beta"), help)
	}
	uifw.gui_layout_end(ctx)
}

@(test)
test_contextual_control_help_follows_focus_and_wraps_plain_language :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	value := f32(50)
	help := "Beta sets where close-range repulsion gives way to the longer-range force, so moving it changes how particles gather."
	ctx.focused = uifw.gui_make_id(&ctx, "beta")

	uifw.gui_begin_frame(&ctx, {window_width = 320, window_height = 220, mouse_pos = {-100, -100}})
	control_experimentation_draw_slider(&ctx, &value, help)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ctx.tooltip_visible)
	testing.expect(t, !ctx.tooltip_from_hover)
	testing.expect_value(t, ctx.tooltip_text, help)
	testing.expect(t, ctx.tooltip_rect.w <= 240.01)
	testing.expect(t, ctx.tooltip_rect.h > ctx.style.body_line_height + 16)
}

@(test)
test_contextual_control_help_uses_pointer_hover_too :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	value := f32(50)

	uifw.gui_begin_frame(&ctx, {window_width = 640, window_height = 360, mouse_pos = {100, 40}})
	control_experimentation_draw_slider(&ctx, &value, "A short explanation.")
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ctx.tooltip_visible)
	testing.expect(t, ctx.tooltip_from_hover)
}

@(test)
test_slider_shift_and_light_stick_use_fine_steps :: proc(t: ^testing.T) {
	keyboard_ctx: uifw.Gui_Context
	uifw.gui_init(&keyboard_ctx)
	defer uifw.gui_destroy(&keyboard_ctx)
	keyboard_value := f32(50)
	keyboard_id := uifw.gui_make_id(&keyboard_ctx, "beta")
	keyboard_ctx.focused = keyboard_id
	keyboard_ctx.focus_edit_id = keyboard_id

	uifw.gui_begin_frame(&keyboard_ctx, {key_right = true, key_shift = true})
	control_experimentation_draw_slider(&keyboard_ctx, &keyboard_value)
	uifw.gui_end_frame(&keyboard_ctx)
	testing.expect_value(t, keyboard_value, f32(51))

	controller_ctx: uifw.Gui_Context
	uifw.gui_init(&controller_ctx)
	defer uifw.gui_destroy(&controller_ctx)
	controller_value := f32(50)
	controller_id := uifw.gui_make_id(&controller_ctx, "beta")
	controller_ctx.focused = controller_id
	controller_ctx.focus_edit_id = controller_id

	uifw.gui_begin_frame(&controller_ctx, {
		active_device = .Controller,
		nav_x = 0.5,
		nav_pressed_x = 1,
	})
	control_experimentation_draw_slider(&controller_ctx, &controller_value)
	uifw.gui_end_frame(&controller_ctx)
	testing.expect_value(t, controller_value, f32(51))
}

@(test)
test_randomize_operations_can_restore_previous_settings :: proc(t: ^testing.T) {
	gray: game.Gray_Scott_Simulation
	game.gray_scott_init(&gray, 320, 240)
	gray_feed := gray.settings.feed
	game.gray_scott_randomize_settings(&gray)
	testing.expect(t, gray.runtime.randomize_undo_available)
	testing.expect(t, gray.settings.feed != gray_feed)
	gray.settings.stability_factor = 0.37
	testing.expect(t, game.gray_scott_undo_randomize_settings(&gray))
	testing.expect_value(t, gray.settings.feed, gray_feed)
	testing.expect_value(t, gray.settings.stability_factor, f32(0.37))

	particle: game.Particle_Life_Simulation
	game.particle_life_init(&particle, 320, 240)
	particle_force := particle.runtime.force_matrix[0]
	game.particle_life_randomize_forces(&particle)
	testing.expect(t, particle.runtime.force_randomize_undo_available)
	testing.expect(t, game.particle_life_undo_randomize_forces(&particle))
	testing.expect_value(t, particle.runtime.force_matrix[0], particle_force)

	slime: game.Remaining_Sim_State
	game.remaining_sim_init(&slime)
	turn_rate := slime.slime.agent_turn_rate
	game.slime_randomize_settings(&slime)
	testing.expect(t, slime.slime_randomize_undo_available)
	slime.slime.mask_strength = 0.83
	testing.expect(t, game.slime_undo_randomize_settings(&slime))
	testing.expect_value(t, slime.slime.agent_turn_rate, turn_rate)
	testing.expect_value(t, slime.slime.mask_strength, f32(0.83))

	slime.moire.curl = 1.73
	game.remaining_sim_reset_with_undo(&slime)
	testing.expect(t, slime.reset_undo.available)
	testing.expect(t, slime.moire.curl != 1.73)
	testing.expect(t, game.remaining_sim_undo_reset(&slime))
	testing.expect_value(t, slime.moire.curl, f32(1.73))
}

@(test)
test_action_notice_expires_after_feedback_window :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	uifw.gui_notice(&ctx, "Settings randomized.", 3)

	uifw.gui_begin_frame(&ctx, {delta_time = 1})
	testing.expect(t, ctx.notice_text_len > 0)
	testing.expect_value(t, ctx.notice_seconds, f32(2))

	uifw.gui_begin_frame(&ctx, {delta_time = 2})
	testing.expect_value(t, ctx.notice_text_len, 0)
	testing.expect_value(t, ctx.notice_seconds, f32(0))
}
