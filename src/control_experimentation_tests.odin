package main

import game "../packages/game"
import host "../packages/app"
import uifw "zelda_engine:ui"

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
test_numeric_precision_mode_cycles_without_requiring_a_button_chord :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.controller_explicit_activation = true
	value := f32(50)
	id := uifw.gui_make_id(&ctx, "precision_number")
	ctx.focused = id
	ctx.focus_edit_id = id

	// The secondary action selects the next, broader step and is released
	// before adjustment, keeping the control operable with single presses.
	uifw.gui_begin_frame(&ctx, {active_device = .Controller, secondary_pressed = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 280, 60}, .Column, 0, 44)
	_ = uifw.gui_numeric_f32(&ctx, "Value: 50", "precision_number", &value, 1, 0, 100)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.numeric_precision_index, 3)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_pressed_x = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 280, 60}, .Column, 0, 44)
	_ = uifw.gui_numeric_f32(&ctx, "Value: 50", "precision_number", &value, 1, 0, 100)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, value, f32(60))
}

@(test)
test_numeric_context_hint_explains_device_specific_magnitude_controls :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.controller_explicit_activation = true
	value := f32(50)
	id := uifw.gui_make_id(&ctx, "hint_number")
	ctx.focused = id
	ctx.focus_edit_id = id

	uifw.gui_begin_frame(&ctx, {
		active_device = .Controller,
		window_width = 640,
		window_height = 360,
		mouse_pos = {-100, -100},
	})
	uifw.gui_layout_begin(&ctx, {12, 12, 280, 60}, .Column, 0, 44)
	_ = uifw.gui_numeric_f32(&ctx, "Value: 50", "hint_number", &value, 1, 0, 100)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ctx.tooltip_visible)
	testing.expect(t, !ctx.tooltip_from_hover)
	testing.expect(t, ctx.tooltip_numeric_controls)
	testing.expect_value(t, ctx.tooltip_text, "D-pad adjusts. Press Secondary to cycle the step: 0.01x, 0.1x, 1x, 10x, or 100x. Accept commits; Back cancels.")
	// There is no room above this top-row control, so its legend sits below it.
	testing.expect(t, ctx.tooltip_rect.y >= 72)
}

@(test)
test_numeric_context_hint_anchors_above_field_instead_of_at_pointer :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	value := f32(50)
	id := uifw.gui_make_id(&ctx, "positioned_hint")
	ctx.focused = id
	ctx.focus_edit_id = id

	uifw.gui_begin_frame(&ctx, {
		window_width = 1280,
		window_height = 720,
		mouse_pos = {900, 330},
	})
	uifw.gui_layout_begin(&ctx, {640, 360, 560, 60}, .Column, 0, 44)
	_ = uifw.gui_numeric_f32(&ctx, "Value: 50", "positioned_hint", &value, 1, 0, 100)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ctx.tooltip_visible)
	testing.expect(t, ctx.tooltip_rect.x <= 640)
	testing.expect(t, ctx.tooltip_rect.y + ctx.tooltip_rect.h <= 360)
}

@(test)
test_numeric_tracks_support_order_of_magnitude_and_signed_detail_mappings :: proc(t: ^testing.T) {
	linear_mid := uifw.gui_numeric_normalized(500, 0, 1000, .Linear)
	log_mid := uifw.gui_numeric_normalized(1, 0.001, 1000, .Logarithmic)
	negative := uifw.gui_numeric_normalized(-1, -1000, 1000, .Symmetric_Log)
	zero := uifw.gui_numeric_normalized(0, -1000, 1000, .Symmetric_Log)
	positive := uifw.gui_numeric_normalized(1, -1000, 1000, .Symmetric_Log)
	testing.expect_value(t, linear_mid, f32(0.5))
	testing.expect(t, abs(log_mid - 0.5) < 0.0001)
	testing.expect(t, negative < zero && zero == 0.5 && positive > zero)
	testing.expect(t, abs((negative + positive) - 1) < 0.0001)
}

@(test)
test_numeric_touch_edge_targets_step_without_turning_a_drag_into_a_tap :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	value := f32(5)

	uifw.gui_begin_frame(&ctx, {pointer_enabled = true, mouse_pos = {270, 22}, mouse_down = true, mouse_pressed = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 280, 60}, .Column, 0, 44)
	_ = uifw.gui_numeric_f32(&ctx, "Value: 5", "touch_number", &value, 1, 0, 10)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {pointer_enabled = true, mouse_pos = {270, 22}, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 280, 60}, .Column, 0, 44)
	_ = uifw.gui_numeric_f32(&ctx, "Value: 5", "touch_number", &value, 1, 0, 10)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, value, f32(6))
}

@(test)
test_numeric_center_tap_enters_exact_text_editing :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	value := f32(12.5)
	id := uifw.gui_make_id(&ctx, "tap_exact")
	uifw.gui_begin_frame(&ctx, {pointer_enabled = true, mouse_pos = {140, 22}, mouse_pressed = true, mouse_down = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 280, 60}, .Column, 0, 44)
	_ = uifw.gui_numeric_f32(&ctx, "Value: 12.5", "tap_exact", &value, 0.1, 0, 100)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	uifw.gui_begin_frame(&ctx, {pointer_enabled = true, mouse_pos = {140, 22}, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 280, 60}, .Column, 0, 44)
	_ = uifw.gui_numeric_f32(&ctx, "Value: 12.5", "tap_exact", &value, 0.1, 0, 100)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focused, id)
	testing.expect_value(t, ctx.text_edit_id, id)
}

@(test)
test_numeric_u32_preserves_values_above_f32_exact_integer_range :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.controller_explicit_activation = true
	value := u32(4_294_967_294)
	id := uifw.gui_make_id(&ctx, "exact_u32")
	ctx.focused = id
	ctx.focus_edit_id = id
	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_pressed_x = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 320, 60}, .Column, 0, 44)
	testing.expect(t, uifw.gui_numeric_u32(&ctx, "Seed", "exact_u32", &value, 0, ~u32(0)))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, value, ~u32(0))

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_pressed_x = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 320, 60}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_numeric_u32(&ctx, "Seed", "exact_u32", &value, 0, ~u32(0)))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
}

@(test)
test_randomize_operations_can_restore_previous_settings :: proc(t: ^testing.T) {
	gray: game.Gray_Scott_Simulation
	gray_storage: Test_Gray_Scott_Product_Storage
	test_gray_scott_init(&gray, &gray_storage, 320, 240)
	gray_feed := gray.settings.feed
	game.gray_scott_randomize_settings(&gray)
	testing.expect(t, gray.runtime.randomize_undo_available)
	testing.expect(t, gray.settings.feed != gray_feed)
	gray.settings.stability_factor = 0.37
	testing.expect(t, game.gray_scott_undo_randomize_settings(&gray))
	testing.expect_value(t, gray.settings.feed, gray_feed)
	testing.expect_value(t, gray.settings.stability_factor, f32(0.37))

	particle: game.Particle_Life_Simulation
	particle_storage: Test_Particle_Life_Product_Storage
	test_particle_life_init(&particle, &particle_storage, 320, 240)
	particle_force := particle.runtime.force_matrix[0]
	game.particle_life_randomize_forces(&particle)
	testing.expect(t, particle.runtime.force_randomize_undo_available)
	testing.expect(t, game.particle_life_undo_randomize_forces(&particle))
	testing.expect_value(t, particle.runtime.force_matrix[0], particle_force)

	slime: game.Remaining_Sim_State
	slime_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&slime, &slime_storage)
	turn_rate := slime.slime.agent_turn_rate
	game.slime_randomize_settings(&slime)
	testing.expect(t, slime.slime_randomize_undo_available)
	slime.slime.mask_strength = 0.83
	testing.expect(t, game.slime_undo_randomize_settings(&slime))
	testing.expect_value(t, slime.slime.agent_turn_rate, turn_rate)
	testing.expect_value(t, slime.slime.mask_strength, f32(0.83))

	primordial: game.Remaining_Sim_State
	primordial_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&primordial, &primordial_storage)
	primordial_before := primordial.primordial^
	game.primordial_randomize_settings(&primordial)
	testing.expect(t, primordial.primordial_randomize_undo_available)
	testing.expect(t, primordial.primordial.alpha != primordial_before.alpha || primordial.primordial.beta != primordial_before.beta)
	testing.expect(t, game.primordial_undo_randomize_settings(&primordial))
	testing.expect_value(t, primordial.primordial.alpha, primordial_before.alpha)
	testing.expect_value(t, primordial.primordial.beta, primordial_before.beta)
	testing.expect_value(t, primordial.primordial.velocity, primordial_before.velocity)
	testing.expect_value(t, primordial.primordial.radius, primordial_before.radius)
	testing.expect_value(t, primordial.primordial.random_seed, primordial_before.random_seed)

	voronoi: game.Remaining_Sim_State
	voronoi_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&voronoi, &voronoi_storage)
	voronoi_before := voronoi.voronoi^
	game.voronoi_randomize_settings(&voronoi)
	testing.expect(t, voronoi.voronoi_randomize_undo_available)
	testing.expect(t, voronoi.voronoi.point_count != voronoi_before.point_count || voronoi.voronoi.drift != voronoi_before.drift)
	testing.expect(t, game.voronoi_undo_randomize_settings(&voronoi))
	testing.expect_value(t, voronoi.voronoi.point_count, voronoi_before.point_count)
	testing.expect_value(t, voronoi.voronoi.time_scale, voronoi_before.time_scale)
	testing.expect_value(t, voronoi.voronoi.drift, voronoi_before.drift)
	testing.expect_value(t, voronoi.voronoi.brownian_speed, voronoi_before.brownian_speed)
	testing.expect_value(t, voronoi.voronoi.random_seed, voronoi_before.random_seed)

	slime.slime.agent_turn_rate = 1.73
	game.remaining_sim_reset_with_undo(&slime)
	testing.expect(t, slime.reset_undo.available)
	testing.expect(t, slime.slime.agent_turn_rate != 1.73)
	testing.expect(t, game.remaining_sim_undo_reset(&slime))
	testing.expect_value(t, slime.slime.agent_turn_rate, f32(1.73))
}

@(test)
test_primordial_regenerate_changes_only_generation_seed :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	sim_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&sim, &sim_storage)
	before := sim.primordial^
	game.primordial_regenerate(&sim)
	testing.expect(t, sim.primordial.random_seed != before.random_seed)
	testing.expect_value(t, sim.primordial.position_generator, before.position_generator)
	testing.expect_value(t, sim.primordial.alpha, before.alpha)
	testing.expect_value(t, sim.primordial.beta, before.beta)
}

@(test)
test_voronoi_regenerate_changes_only_site_seed :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	sim_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&sim, &sim_storage)
	before := sim.voronoi^
	game.voronoi_regenerate(&sim)
	testing.expect(t, sim.voronoi.random_seed != before.random_seed)
	testing.expect_value(t, sim.voronoi.point_count, before.point_count)
	testing.expect_value(t, sim.voronoi.drift, before.drift)
	testing.expect_value(t, sim.voronoi.brownian_speed, before.brownian_speed)
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

@(test)
test_action_notice_cannot_stick_during_zero_delta_redraws :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	uifw.gui_notice(&ctx, "Deflect selected", 0.05)

	for _ in 0 ..< 3 {
		uifw.gui_begin_frame(&ctx, {})
	}

	testing.expect_value(t, ctx.notice_text_len, 0)
	testing.expect_value(t, ctx.notice_seconds, f32(0))
}
