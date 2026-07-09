package main

import game "../packages/game"
import engine "../packages/engine"
import uifw "../packages/ui"

import "core:math"
import "core:os"
import "core:testing"
import sdl "vendor:sdl3"
import vk "vendor:vulkan"

test_approx_f32 :: proc(a, b: f32) -> bool {
	return math.abs(a - b) <= 0.01
}

test_is_scroll_top_fade :: proc(command: uifw.Draw_Command, viewport: uifw.Rect) -> bool {
	if command.kind != uifw.Draw_Command_Kind.Gradient_Rect {
		return false
	}
	return test_approx_f32(command.rect.x, viewport.x) &&
	       test_approx_f32(command.rect.y, viewport.y) &&
	       test_approx_f32(command.rect.w, viewport.w) &&
	       command.rect.h > 0 &&
	       command.rect.h <= 18.01 &&
	       command.color.r == 0 &&
	       command.color.g == 0 &&
	       command.color.b == 0 &&
	       command.color.a > 0 &&
	       command.color_2.r == 0 &&
	       command.color_2.g == 0 &&
	       command.color_2.b == 0 &&
	       command.color_2.a == 0
}

test_is_scroll_bottom_fade :: proc(command: uifw.Draw_Command, viewport: uifw.Rect) -> bool {
	if command.kind != uifw.Draw_Command_Kind.Gradient_Rect {
		return false
	}
	return test_approx_f32(command.rect.x, viewport.x) &&
	       test_approx_f32(command.rect.y + command.rect.h, viewport.y + viewport.h) &&
	       test_approx_f32(command.rect.w, viewport.w) &&
	       command.rect.h > 0 &&
	       command.rect.h <= 18.01 &&
	       command.color.r == 0 &&
	       command.color.g == 0 &&
	       command.color.b == 0 &&
	       command.color.a == 0 &&
	       command.color_2.r == 0 &&
	       command.color_2.g == 0 &&
	       command.color_2.b == 0 &&
	       command.color_2.a > 0
}

test_count_scroll_fades :: proc(commands: []uifw.Draw_Command, viewport: uifw.Rect) -> (top, bottom: int) {
	for command in commands {
		if test_is_scroll_top_fade(command, viewport) {
			top += 1
		}
		if test_is_scroll_bottom_fade(command, viewport) {
			bottom += 1
		}
	}
	return
}

test_expect_color_scheme :: proc(t: ^testing.T, color_scheme: ^game.Color_Scheme_Name, reversed: bool, expected_name: string, expected_reversed: bool) {
	testing.expect_value(t, game.color_scheme_name_get(color_scheme), expected_name)
	testing.expect_value(t, reversed, expected_reversed)
}

test_color_byte :: proc(value: f32) -> u8 {
	return u8(uifw.gui_clamp01(value) * 255 + 0.5)
}

test_expect_color_near_rgb8 :: proc(t: ^testing.T, color: uifw.Color, r, g, b: u8, tolerance: int) {
	red_delta := int(test_color_byte(color.r)) - int(r)
	green_delta := int(test_color_byte(color.g)) - int(g)
	blue_delta := int(test_color_byte(color.b)) - int(b)
	if red_delta < 0 {
		red_delta = -red_delta
	}
	if green_delta < 0 {
		green_delta = -green_delta
	}
	if blue_delta < 0 {
		blue_delta = -blue_delta
	}
	testing.expect(t, red_delta <= tolerance)
	testing.expect(t, green_delta <= tolerance)
	testing.expect(t, blue_delta <= tolerance)
}

test_colors_match_rgb8 :: proc(a, b: uifw.Color) -> bool {
	return test_color_byte(a.r) == test_color_byte(b.r) &&
	       test_color_byte(a.g) == test_color_byte(b.g) &&
	       test_color_byte(a.b) == test_color_byte(b.b)
}

test_is_black_horizontal_fade :: proc(command: uifw.Draw_Command, left_alpha, right_alpha: f32) -> bool {
	if command.kind != uifw.Draw_Command_Kind.Horizontal_Gradient_Rect {
		return false
	}
	return command.color.r == 0 &&
	       command.color.g == 0 &&
	       command.color.b == 0 &&
	       test_approx_f32(command.color.a, left_alpha) &&
	       command.color_2.r == 0 &&
	       command.color_2.g == 0 &&
	       command.color_2.b == 0 &&
	       test_approx_f32(command.color_2.a, right_alpha)
}

@(test)
test_memory_budget_prefers_reported_budget :: proc(t: ^testing.T) {
	budget := engine.gpu_memory_budget_from_heaps(
		sizes = []u64{1000},
		usages = []u64{100},
		budgets = []u64{800},
		has_budget = true,
		override_fraction = 0,
	)
	testing.expect_value(t, budget.heaps[0].ceiling, u64(560))
}

@(test)
test_memory_budget_falls_back_to_heap_size :: proc(t: ^testing.T) {
	budget := engine.gpu_memory_budget_from_heaps(
		sizes = []u64{1000},
		usages = []u64{0},
		budgets = nil,
		has_budget = false,
		override_fraction = 0,
	)
	testing.expect_value(t, budget.heaps[0].ceiling, u64(600))
}

@(test)
test_queue_is_bounded :: proc(t: ^testing.T) {
	q: engine.Bounded_Queue(int, 2)
	testing.expect(t, engine.queue_try_push(&q, 1))
	testing.expect(t, engine.queue_try_push(&q, 2))
	testing.expect(t, !engine.queue_try_push(&q, 3))

	value: int
	testing.expect(t, engine.queue_try_pop(&q, &value))
	testing.expect_value(t, value, 1)
	testing.expect(t, engine.queue_try_push(&q, 3))
	testing.expect_value(t, engine.queue_len(&q), 2)
}

@(test)
test_screenshot_state_converts_bgra_to_qoi_on_request :: proc(t: ^testing.T) {
	state: engine.Screenshot_State
	defer engine.screenshot_state_destroy(&state)

	pixels := []u8{10, 20, 30, 255}
	testing.expect(t, engine.screenshot_state_publish_from_gpu_rgba(&state, pixels, 1, 1, vk.Format.B8G8R8A8_SRGB, 7))

	qoi_bytes, width, height, sequence, ok := engine.screenshot_state_copy_qoi(&state)
	defer delete(qoi_bytes)

	testing.expect(t, ok)
	testing.expect_value(t, width, u32(1))
	testing.expect_value(t, height, u32(1))
	testing.expect_value(t, sequence, u64(1))
	testing.expect(t, len(qoi_bytes) >= 26)
	testing.expect_value(t, string(qoi_bytes[:4]), "qoif")
	testing.expect_value(t, qoi_bytes[4], u8(0))
	testing.expect_value(t, qoi_bytes[5], u8(0))
	testing.expect_value(t, qoi_bytes[6], u8(0))
	testing.expect_value(t, qoi_bytes[7], u8(1))
	testing.expect_value(t, qoi_bytes[8], u8(0))
	testing.expect_value(t, qoi_bytes[9], u8(0))
	testing.expect_value(t, qoi_bytes[10], u8(0))
	testing.expect_value(t, qoi_bytes[11], u8(1))
	testing.expect_value(t, qoi_bytes[12], u8(3))
	testing.expect_value(t, qoi_bytes[14], u8(0xfe))
	testing.expect_value(t, qoi_bytes[15], u8(30))
	testing.expect_value(t, qoi_bytes[16], u8(20))
	testing.expect_value(t, qoi_bytes[17], u8(10))
}

@(test)
test_video_recorder_uses_swapchain_pixel_format_names :: proc(t: ^testing.T) {
	testing.expect_value(t, game.video_recorder_pixel_format_name(vk.Format.B8G8R8A8_UNORM), "bgra")
	testing.expect_value(t, game.video_recorder_pixel_format_name(vk.Format.B8G8R8A8_SRGB), "bgra")
	testing.expect_value(t, game.video_recorder_pixel_format_name(vk.Format.R8G8B8A8_UNORM), "rgba")
}

@(test)
test_video_recorder_fps_defaults_and_clamps_to_sixty :: proc(t: ^testing.T) {
	settings := game.settings_default()
	settings.default_fps_limit_enabled = false
	settings.default_fps_limit = 240
	testing.expect_value(t, game.video_recorder_fps_from_settings(settings), u32(60))

	settings.default_fps_limit_enabled = true
	settings.default_fps_limit = 30
	testing.expect_value(t, game.video_recorder_fps_from_settings(settings), u32(30))

	settings.default_fps_limit = 240
	testing.expect_value(t, game.video_recorder_fps_from_settings(settings), u32(60))
}

@(test)
test_app_ui_video_recording_command_state_transitions :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	testing.expect_value(t, ui.video_recording_state, game.Video_Recording_Ui_State.Idle)

	game.app_ui_video_recording_apply_command_state(&ui, .Restoring_Fullscreen, "Restoring fullscreen before recording")
	testing.expect_value(t, ui.video_recording_state, game.Video_Recording_Ui_State.Restoring_Fullscreen)
	testing.expect_value(t, game.fixed_string(ui.video_recording_status[:]), "Restoring fullscreen before recording")

	game.app_ui_video_recording_apply_command_state(&ui, .Recording, "/tmp/test.mp4")
	testing.expect_value(t, ui.video_recording_state, game.Video_Recording_Ui_State.Recording)
	testing.expect_value(t, game.app_ui_video_recording_button_label(&ui), "Stop Recording")

	game.app_ui_video_recording_apply_command_state(&ui, .Failed, "ffmpeg was not found on PATH")
	testing.expect_value(t, ui.video_recording_state, game.Video_Recording_Ui_State.Failed)
	testing.expect_value(t, game.app_ui_video_recording_button_label(&ui), "Record")
}

@(test)
test_screenshot_state_can_return_smaller_qoi :: proc(t: ^testing.T) {
	state: engine.Screenshot_State
	defer engine.screenshot_state_destroy(&state)

	pixels := []u8{
		255, 0, 0, 255, 0, 255, 0, 255,
		0, 0, 255, 255, 255, 255, 255, 255,
	}
	testing.expect(t, engine.screenshot_state_publish_from_gpu_rgba(&state, pixels, 2, 2, vk.Format.R8G8B8A8_UNORM, 7))

	qoi_bytes, width, height, sequence, ok := engine.screenshot_state_copy_qoi_sized(&state, 1, 1, 1)
	defer delete(qoi_bytes)

	testing.expect(t, ok)
	testing.expect_value(t, width, u32(1))
	testing.expect_value(t, height, u32(1))
	testing.expect_value(t, sequence, u64(1))
	testing.expect_value(t, string(qoi_bytes[:4]), "qoif")
	testing.expect_value(t, qoi_bytes[7], u8(1))
	testing.expect_value(t, qoi_bytes[11], u8(1))
	testing.expect_value(t, qoi_bytes[12], u8(3))
}

@(test)
test_screenshot_state_throttles_background_capture_but_honors_requests :: proc(t: ^testing.T) {
	state: engine.Screenshot_State
	defer engine.screenshot_state_destroy(&state)

	pixels := []u8{1, 2, 3, 255}
	testing.expect(t, engine.screenshot_state_should_capture(&state, 1, 15))
	testing.expect(t, engine.screenshot_state_publish_from_gpu_rgba(&state, pixels, 1, 1, vk.Format.R8G8B8A8_UNORM, 1))
	testing.expect(t, !engine.screenshot_state_should_capture(&state, 2, 15))

	engine.screenshot_state_request_capture(&state)
	testing.expect(t, engine.screenshot_state_should_capture(&state, 3, 15))
	testing.expect(t, engine.screenshot_state_publish_from_gpu_rgba(&state, pixels, 1, 1, vk.Format.R8G8B8A8_UNORM, 3))
	testing.expect(t, !engine.screenshot_state_should_capture(&state, 4, 15))
	testing.expect(t, engine.screenshot_state_should_capture(&state, 18, 15))
}

@(test)
test_gray_scott_settings_round_trip :: proc(t: ^testing.T) {
	sim: game.Gray_Scott_Simulation
	game.gray_scott_init(&sim, 640, 480)
	sim.settings.feed = 0.04
	saved := game.gray_scott_save_settings(&sim)

	other: game.Gray_Scott_Simulation
	game.gray_scott_init(&other, 320, 240)
	game.gray_scott_load_settings(&other, saved)
	testing.expect_value(t, other.settings.feed, f32(0.04))
}

@(test)
test_gray_scott_toml_round_trip_through_tomlc17 :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_gray_scott_roundtrip.toml"
	settings := game.gray_scott_default_settings()
	settings.feed = 0.031
	settings.kill = 0.067
	settings.diffusion_b = 0.42
	settings.simulation_speed = 4.0
	settings.paused = true
	settings.mask_pattern = .Nutrient_Map
	settings.nutrient_image_fit_mode = .Fit_V
	game.write_fixed_string(settings.nutrient_image_path[:], "config/custom_nutrient.png")

	testing.expect(t, game.settings_save_gray_scott(path, settings))
	loaded, ok := game.settings_load_gray_scott(path, game.gray_scott_default_settings())
	testing.expect(t, ok)
	testing.expect_value(t, loaded.feed, settings.feed)
	testing.expect_value(t, loaded.kill, settings.kill)
	testing.expect_value(t, loaded.diffusion_b, settings.diffusion_b)
	testing.expect_value(t, loaded.simulation_speed, settings.simulation_speed)
	testing.expect_value(t, loaded.paused, settings.paused)
	testing.expect_value(t, loaded.mask_pattern, settings.mask_pattern)
	testing.expect_value(t, loaded.nutrient_image_fit_mode, settings.nutrient_image_fit_mode)
	testing.expect_value(t, game.fixed_string(loaded.nutrient_image_path[:]), "config/custom_nutrient.png")
}

@(test)
test_particle_life_toml_round_trip_through_tomlc17 :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_particle_life_roundtrip.toml"
	settings := game.particle_life_default_settings()
	settings.particle_count = 2222
	settings.species_count = 4
	settings.position_generator = 10
	settings.type_generator = 8
	settings.force_generator = 18
	settings.camera_x = 1.25
	settings.camera_y = -0.5
	settings.camera_zoom = 3.5
	settings.color_mode = .White
	settings.background_color_mode = .White
	settings.background_index = int(game.Vector_Background_Mode.White)
	game.color_scheme_name_set(&settings.color_scheme, "MATPLOTLIB_viridis")
	settings.color_scheme_reversed = true
	settings.background_color = {0.12, 0.23, 0.34, 1}
	settings.brightness = 1.4
	settings.contrast = 0.7
	settings.saturation = 1.6
	settings.gamma = 1.8
	settings.trails_enabled = false
	settings.trail_fade_amount = 0.042
	settings.infinite_tiles_enabled = false
	settings.infinite_tile_radius = 7
	settings.analysis_enabled = true
	settings.analysis_interval_frames = 6
	settings.analysis_grid_size = 512
	settings.coherence_threshold = 0.66
	settings.min_blob_area_cells = 20
	settings.blob_overlay_enabled = true
	settings.custom_force_matrix = true
	settings.force_matrix[2 * game.PARTICLE_LIFE_MAX_SPECIES + 3] = -0.625

	testing.expect(t, game.settings_save_particle_life(path, settings))
	loaded, ok := game.settings_load_particle_life(path, game.particle_life_default_settings())
	testing.expect(t, ok)
	testing.expect_value(t, loaded.particle_count, settings.particle_count)
	testing.expect_value(t, loaded.species_count, settings.species_count)
	testing.expect_value(t, loaded.position_generator, settings.position_generator)
	testing.expect_value(t, loaded.type_generator, settings.type_generator)
	testing.expect_value(t, loaded.force_generator, settings.force_generator)
	testing.expect_value(t, loaded.camera_x, settings.camera_x)
	testing.expect_value(t, loaded.camera_y, settings.camera_y)
	testing.expect_value(t, loaded.camera_zoom, settings.camera_zoom)
	testing.expect_value(t, loaded.color_mode, settings.color_mode)
	testing.expect_value(t, loaded.background_color_mode, settings.background_color_mode)
	testing.expect_value(t, loaded.background_index, int(game.Vector_Background_Mode.White))
	testing.expect_value(t, game.color_scheme_name_get(&loaded.color_scheme), "MATPLOTLIB_viridis")
	testing.expect_value(t, loaded.color_scheme_reversed, settings.color_scheme_reversed)
	testing.expect_value(t, loaded.background_color[0], settings.background_color[0])
	testing.expect_value(t, loaded.background_color[1], settings.background_color[1])
	testing.expect_value(t, loaded.background_color[2], settings.background_color[2])
	testing.expect_value(t, loaded.brightness, settings.brightness)
	testing.expect_value(t, loaded.contrast, settings.contrast)
	testing.expect_value(t, loaded.saturation, settings.saturation)
	testing.expect_value(t, loaded.gamma, settings.gamma)
	testing.expect_value(t, loaded.trails_enabled, settings.trails_enabled)
	testing.expect_value(t, loaded.trail_fade_amount, settings.trail_fade_amount)
	testing.expect_value(t, loaded.infinite_tiles_enabled, settings.infinite_tiles_enabled)
	testing.expect_value(t, loaded.infinite_tile_radius, settings.infinite_tile_radius)
	testing.expect_value(t, loaded.analysis_enabled, settings.analysis_enabled)
	testing.expect_value(t, loaded.analysis_interval_frames, settings.analysis_interval_frames)
	testing.expect_value(t, loaded.analysis_grid_size, settings.analysis_grid_size)
	testing.expect_value(t, loaded.coherence_threshold, settings.coherence_threshold)
	testing.expect_value(t, loaded.min_blob_area_cells, settings.min_blob_area_cells)
	testing.expect_value(t, loaded.blob_overlay_enabled, settings.blob_overlay_enabled)
	testing.expect_value(t, loaded.custom_force_matrix, true)
	testing.expect_value(t, loaded.force_matrix[2 * game.PARTICLE_LIFE_MAX_SPECIES + 3], f32(-0.625))
}

@(test)
test_particle_life_saved_preset_keeps_current_color_scheme :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_particle_life_preserve_color_preset.toml"
	preset := game.particle_life_default_settings()
	preset.particle_count = 3333
	game.color_scheme_name_set(&preset.color_scheme, "MATPLOTLIB_viridis")
	preset.color_scheme_reversed = true
	testing.expect(t, game.settings_save_particle_life(path, preset))

	current := game.particle_life_default_settings()
	game.color_scheme_name_set(&current.color_scheme, "ZELDA_Aqua")
	current.color_scheme_reversed = false
	loaded, ok := game.settings_load_particle_life_preset(path, current)

	testing.expect(t, ok)
	testing.expect_value(t, loaded.particle_count, u32(3333))
	test_expect_color_scheme(t, &loaded.color_scheme, loaded.color_scheme_reversed, "ZELDA_Aqua", false)
}

@(test)
test_particle_life_default_preset_matches_original_builtin :: proc(t: ^testing.T) {
	settings := game.particle_life_default_settings()
	testing.expect_value(t, settings.particle_count, u32(15000))
	testing.expect_value(t, settings.species_count, u32(4))
	testing.expect_value(t, settings.max_force, f32(0.5))
	testing.expect_value(t, settings.max_distance, f32(0.05))
	testing.expect_value(t, settings.friction, f32(0.5))
	testing.expect_value(t, settings.beta, f32(0.5))
	testing.expect_value(t, settings.brownian_motion, f32(0.5))
	testing.expect_value(t, settings.wrap_edges, true)
	testing.expect_value(t, settings.background_color_mode, game.Vector_Background_Mode.Color_Scheme)
	testing.expect_value(t, settings.background_index, int(game.Vector_Background_Mode.Color_Scheme))
	testing.expect_value(t, settings.force_matrix[0 * game.PARTICLE_LIFE_MAX_SPECIES + 0], f32(-0.1))
	testing.expect_value(t, settings.force_matrix[0 * game.PARTICLE_LIFE_MAX_SPECIES + 1], f32(0.2))
	testing.expect_value(t, settings.force_matrix[1 * game.PARTICLE_LIFE_MAX_SPECIES + 2], f32(0.3))
	testing.expect_value(t, settings.force_matrix[3 * game.PARTICLE_LIFE_MAX_SPECIES + 3], f32(-0.1))
}

@(test)
test_particle_life_background_color_mode_matches_old_lut_endpoint :: proc(t: ^testing.T) {
	settings := game.particle_life_default_settings()
	game.color_scheme_name_set(&settings.color_scheme, "MATPLOTLIB_viridis")
	settings.color_scheme_reversed = false
	settings.background_color_mode = .Color_Scheme
	settings.background_index = int(game.Vector_Background_Mode.Color_Scheme)

	scheme := game.color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
	expected := game.color_scheme_color_at(scheme, 0)
	actual := game.particle_life_background_color(&settings)
	testing.expect_value(t, actual[0], expected[0])
	testing.expect_value(t, actual[1], expected[1])
	testing.expect_value(t, actual[2], expected[2])
	testing.expect_value(t, actual[3], expected[3])

	settings.color_scheme_reversed = true
	scheme = game.color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
	expected = game.color_scheme_color_at(scheme, 0)
	actual = game.particle_life_background_color(&settings)
	testing.expect_value(t, actual[0], expected[0])
	testing.expect_value(t, actual[1], expected[1])
	testing.expect_value(t, actual[2], expected[2])
	testing.expect_value(t, actual[3], expected[3])

	settings.background_color_mode = .Gray18
	actual = game.particle_life_background_color(&settings)
	testing.expect_value(t, actual[0], f32(0.18))
	testing.expect_value(t, actual[1], f32(0.18))
	testing.expect_value(t, actual[2], f32(0.18))
	testing.expect_value(t, actual[3], f32(1))
}

@(test)
test_particle_life_builtin_preset_keeps_current_color_scheme :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	game.particle_life_init(&sim, 320, 240)
	game.color_scheme_name_set(&sim.settings.color_scheme, "ZELDA_Aqua")
	sim.settings.color_scheme_reversed = true

	game.particle_life_apply_builtin_preset(&sim, 0)

	test_expect_color_scheme(t, &sim.settings.color_scheme, sim.settings.color_scheme_reversed, "ZELDA_Aqua", true)
}

@(test)
test_particle_life_force_randomize_does_not_regenerate_particles :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	game.particle_life_init(&sim, 320, 240)
	sim.runtime.needs_reset = false

	game.particle_life_randomize_forces(&sim)

	testing.expect(t, !sim.runtime.needs_reset)
	testing.expect(t, sim.runtime.pending_force_randomize)
}

@(test)
test_particle_life_particle_regenerate_preserves_forces :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	game.particle_life_init(&sim, 320, 240)
	game.particle_life_randomize_forces(&sim)
	force_before := sim.runtime.force_matrix

	game.particle_life_reset_runtime(&sim)

	testing.expect(t, sim.runtime.needs_reset)
	testing.expect_value(t, sim.runtime.force_matrix[0], force_before[0])
	testing.expect_value(t, sim.runtime.force_matrix[1], force_before[1])
	testing.expect_value(t, sim.runtime.force_matrix[2 * game.PARTICLE_LIFE_MAX_SPECIES + 3], force_before[2 * game.PARTICLE_LIFE_MAX_SPECIES + 3])
}

@(test)
test_particle_life_resource_rebuild_does_not_regenerate_particles :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	game.particle_life_init(&sim, 320, 240)
	sim.runtime.needs_reset = false
	sim.gpu.ready = true

	game.particle_life_request_resource_rebuild(&sim)

	testing.expect(t, !sim.runtime.needs_reset)
	testing.expect(t, !sim.gpu.ready)
}

particle_life_test_blob_summary :: proc(x, y, vx, vy: f32, area: u32, species: u32) -> game.Particle_Life_Blob_Summary {
	summary: game.Particle_Life_Blob_Summary
	summary.area = area
	summary.centroid = {x, y}
	summary.velocity = {vx, vy}
	summary.density = 1
	summary.coherence_score = 1
	if species < game.PARTICLE_LIFE_MAX_SPECIES {
		summary.species_histogram[species] = area
	}
	return summary
}

@(test)
test_particle_life_blob_tracker_keeps_id_across_motion :: proc(t: ^testing.T) {
	tracker: game.Particle_Life_Blob_Tracker
	game.particle_life_blob_tracker_reset(&tracker)
	first := [?]game.Particle_Life_Blob_Summary{particle_life_test_blob_summary(0, 0, 0.02, 0, 24, 1)}
	game.particle_life_blob_tracker_update(&tracker, first[:])
	id := tracker.blobs[0].id

	next := [?]game.Particle_Life_Blob_Summary{particle_life_test_blob_summary(0.025, 0, 0.02, 0, 25, 1)}
	game.particle_life_blob_tracker_update(&tracker, next[:])

	testing.expect_value(t, tracker.count, u32(1))
	testing.expect_value(t, tracker.blobs[0].id, id)
	testing.expect(t, tracker.blobs[0].confidence > 0.45)
}

@(test)
test_particle_life_blob_tracker_ages_lost_blobs :: proc(t: ^testing.T) {
	tracker: game.Particle_Life_Blob_Tracker
	game.particle_life_blob_tracker_reset(&tracker)
	first := [?]game.Particle_Life_Blob_Summary{particle_life_test_blob_summary(0, 0, 0, 0, 24, 1)}
	game.particle_life_blob_tracker_update(&tracker, first[:])
	empty: [0]game.Particle_Life_Blob_Summary

	for _ in 0 ..< 10 {
		game.particle_life_blob_tracker_update(&tracker, empty[:])
	}
	testing.expect_value(t, tracker.count, u32(1))
	game.particle_life_blob_tracker_update(&tracker, empty[:])
	testing.expect_value(t, tracker.count, u32(0))
}

@(test)
test_particle_life_blob_tracker_distinguishes_distant_split :: proc(t: ^testing.T) {
	tracker: game.Particle_Life_Blob_Tracker
	game.particle_life_blob_tracker_reset(&tracker)
	first := [?]game.Particle_Life_Blob_Summary{particle_life_test_blob_summary(0, 0, 0, 0, 40, 2)}
	game.particle_life_blob_tracker_update(&tracker, first[:])

	split := [?]game.Particle_Life_Blob_Summary{
		particle_life_test_blob_summary(0.01, 0, 0, 0, 22, 2),
		particle_life_test_blob_summary(0.8, 0, 0, 0, 20, 2),
	}
	game.particle_life_blob_tracker_update(&tracker, split[:])

	testing.expect_value(t, tracker.count, u32(2))
}

@(test)
test_particle_life_blob_tracker_uses_species_histogram_tie_break :: proc(t: ^testing.T) {
	tracker: game.Particle_Life_Blob_Tracker
	game.particle_life_blob_tracker_reset(&tracker)
	first := [?]game.Particle_Life_Blob_Summary{
		particle_life_test_blob_summary(-0.1, 0, 0, 0, 20, 0),
		particle_life_test_blob_summary(0.1, 0, 0, 0, 20, 1),
	}
	game.particle_life_blob_tracker_update(&tracker, first[:])
	id_species_one := tracker.blobs[1].id

	next := [?]game.Particle_Life_Blob_Summary{particle_life_test_blob_summary(0.12, 0, 0, 0, 20, 1)}
	game.particle_life_blob_tracker_update(&tracker, next[:])

	found := false
	for i in 0 ..< int(tracker.count) {
		if tracker.blobs[i].id == id_species_one && tracker.blobs[i].missed_frames == 0 {
			found = true
		}
	}
	testing.expect(t, found)
}

@(test)
test_particle_life_analysis_segments_grid_blobs :: proc(t: ^testing.T) {
	workspace: game.Particle_Life_Analysis_Workspace
	defer game.particle_life_analysis_workspace_destroy(&workspace)

	particles := [?]game.Particle_Life_Particle{
		{position = {-0.08, -0.08}, velocity = {0.03, 0.01}, species = 1},
		{position = {-0.07, -0.08}, velocity = {0.03, 0.01}, species = 1},
		{position = {-0.08, -0.07}, velocity = {0.03, 0.01}, species = 1},
		{position = {-0.07, -0.07}, velocity = {0.03, 0.01}, species = 1},
		{position = {-0.06, -0.07}, velocity = {0.03, 0.01}, species = 1},
		{position = {0.58, 0.58}, velocity = {-0.02, 0.00}, species = 2},
		{position = {0.59, 0.58}, velocity = {-0.02, 0.00}, species = 2},
		{position = {0.58, 0.59}, velocity = {-0.02, 0.00}, species = 2},
		{position = {0.59, 0.59}, velocity = {-0.02, 0.00}, species = 2},
	}

	summaries := game.particle_life_analyze_particles(&workspace, particles[:], 4, 16, 1, 0.35, {2, 2})

	testing.expect_value(t, len(summaries), 2)
	if len(summaries) < 2 {
		return
	}
	testing.expect(t, summaries[0].area >= 1)
	testing.expect(t, summaries[0].density >= 4)
	testing.expect(t, summaries[0].coherence_score > 0.35)
	testing.expect(t, summaries[0].species_histogram[1] >= 4 || summaries[1].species_histogram[1] >= 4)
	testing.expect(t, summaries[0].species_histogram[2] >= 4 || summaries[1].species_histogram[2] >= 4)
}

@(test)
test_particle_life_analysis_gpu_struct_layouts_are_stable :: proc(t: ^testing.T) {
	testing.expect_value(t, size_of(game.Particle_Life_Analysis_Gpu_Cell), 48)
	testing.expect_value(t, align_of(game.Particle_Life_Analysis_Gpu_Cell), 16)
	testing.expect_value(t, size_of(game.Particle_Life_Blob_Accumulator), 80)
	testing.expect_value(t, align_of(game.Particle_Life_Blob_Accumulator), 16)
}

@(test)
test_particle_life_analysis_grid_helpers_clamp_and_tile :: proc(t: ^testing.T) {
	settings := game.particle_life_default_settings()
	settings.analysis_grid_size = 8
	testing.expect_value(t, game.particle_life_target_analysis_grid_axis(settings), u32(64))
	settings.analysis_grid_size = 2048
	testing.expect_value(t, game.particle_life_target_analysis_grid_axis(settings), u32(1024))
	settings.analysis_grid_size = 512
	testing.expect_value(t, game.particle_life_target_analysis_grid_axis(settings), u32(512))
	testing.expect_value(t, game.particle_life_analysis_tile_count_for_axis(512), u32(32))
	testing.expect_value(t, game.particle_life_analysis_tile_count_for_axis(513), u32(33))
}

@(test)
test_particle_life_collision_distance_follows_particle_size :: proc(t: ^testing.T) {
	settings := game.particle_life_default_settings()
	settings.collision_enabled = true
	settings.max_distance = 1.0
	settings.particle_size = 4
	settings.collision_distance = 0.04
	testing.expect_value(t, game.particle_life_collision_distance(settings), f32(0.008))
	testing.expect_value(t, game.particle_life_target_grid_cell_size(settings), f32(0.008))

	settings.particle_size = 12
	testing.expect_value(t, game.particle_life_collision_distance(settings), f32(0.024))
	testing.expect_value(t, game.particle_life_target_grid_cell_size(settings), f32(0.024))
}

@(test)
test_particle_life_collision_toggle_reuses_fine_grid :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	game.particle_life_init(&sim, 320, 240)
	world_size := game.particle_life_world_size(&sim)

	sim.settings.collision_enabled = true
	fine_width, fine_height := game.particle_life_target_grid_dimensions(sim.settings, world_size)
	fine_radius := game.particle_life_target_neighbor_radius_cells(sim.settings, fine_width, fine_height, world_size)
	sim.gpu.grid_width = fine_width
	sim.gpu.grid_height = fine_height
	sim.gpu.neighbor_radius_cells = fine_radius
	testing.expect(t, game.particle_life_current_grid_satisfies_settings(&sim))

	sim.settings.collision_enabled = false
	testing.expect(t, game.particle_life_current_grid_satisfies_settings(&sim))

	coarse_width, coarse_height := game.particle_life_target_grid_dimensions(sim.settings, world_size)
	coarse_radius := game.particle_life_target_neighbor_radius_cells(sim.settings, coarse_width, coarse_height, world_size)
	sim.gpu.grid_width = coarse_width
	sim.gpu.grid_height = coarse_height
	sim.gpu.neighbor_radius_cells = coarse_radius
	sim.settings.collision_enabled = true
	testing.expect(t, !game.particle_life_current_grid_satisfies_settings(&sim))
}

@(test)
test_particle_life_screen_to_world_keeps_mouse_y_upright :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	game.particle_life_init(&sim, 200, 100)

	top := game.particle_life_screen_to_world(&sim, {100, 0}, 200, 100)
	bottom := game.particle_life_screen_to_world(&sim, {100, 100}, 200, 100)
	left := game.particle_life_screen_to_world(&sim, {0, 50}, 200, 100)
	right := game.particle_life_screen_to_world(&sim, {200, 50}, 200, 100)

	testing.expect_value(t, top[0], f32(0))
	testing.expect_value(t, top[1], f32(1))
	testing.expect_value(t, bottom[0], f32(0))
	testing.expect_value(t, bottom[1], f32(-1))
	testing.expect_value(t, left[0], f32(-2))
	testing.expect_value(t, left[1], f32(0))
	testing.expect_value(t, right[0], f32(2))
	testing.expect_value(t, right[1], f32(0))
}

@(test)
test_particle_life_random_spawn_scales_to_viewport_world :: proc(t: ^testing.T) {
	wide_world := game.particle_life_world_size_for_viewport(200, 100)
	wide_position, wide_normalized := game.particle_life_generate_position_for_world(0, 4, 0, 42, wide_world)
	testing.expect_value(t, wide_world[0], f32(4))
	testing.expect_value(t, wide_world[1], f32(2))
	testing.expect_value(t, wide_position[0], wide_normalized[0] * 2.0)
	testing.expect_value(t, wide_position[1], wide_normalized[1])

	tall_world := game.particle_life_world_size_for_viewport(100, 200)
	tall_position, tall_normalized := game.particle_life_generate_position_for_world(0, 4, 0, 42, tall_world)
	testing.expect_value(t, tall_world[0], f32(1))
	testing.expect_value(t, tall_world[1], f32(2))
	testing.expect_value(t, tall_position[0], tall_normalized[0] * 0.5)
	testing.expect_value(t, tall_position[1], tall_normalized[1])
}

@(test)
test_gray_scott_screen_to_texture_matches_rendered_y :: proc(t: ^testing.T) {
	sim: game.Gray_Scott_Simulation
	game.gray_scott_init(&sim, 200, 100)

	top_x, top_y := game.gray_scott_screen_to_texture(&sim, {100, 0}, 200, 100)
	bottom_x, bottom_y := game.gray_scott_screen_to_texture(&sim, {100, 100}, 200, 100)

	testing.expect_value(t, top_x, f32(0.5))
	testing.expect_value(t, top_y, f32(1))
	testing.expect_value(t, bottom_x, f32(0.5))
	testing.expect_value(t, bottom_y, f32(0))
}

@(test)
test_particle_life_infinite_tile_range_clamps_to_camera_radius :: proc(t: ^testing.T) {
	bounds := [4]f32{-2.5, -1.0, 2.5, 1.0}
	tile_range := game.particle_life_tile_range_for_bounds(bounds, 0, 0, 1, {2, 2})
	testing.expect_value(t, tile_range.min_x, i32(-1))
	testing.expect_value(t, tile_range.max_x, i32(1))
	testing.expect_value(t, tile_range.min_y, i32(-1))
	testing.expect_value(t, tile_range.max_y, i32(1))
}

@(test)
test_particle_life_tile_bounds_shift_view_instead_of_particle_positions :: proc(t: ^testing.T) {
	bounds := [4]f32{-2.5, -1.0, 2.5, 1.0}
	shifted := game.particle_life_tile_bounds_for_offset(bounds, 2, -1, {2, 2})
	testing.expect_value(t, shifted[0], f32(-6.5))
	testing.expect_value(t, shifted[1], f32(1.0))
	testing.expect_value(t, shifted[2], f32(-1.5))
	testing.expect_value(t, shifted[3], f32(3.0))
}

@(test)
test_particle_life_trails_reset_when_camera_changes :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	game.particle_life_init(&sim, 1280, 720)

	sim.gpu.trail_initialized = true
	game.particle_life_note_trail_camera(&sim)
	testing.expect(t, sim.gpu.trail_initialized)

	sim.runtime.camera_zoom = 2
	game.particle_life_note_trail_camera(&sim)
	testing.expect(t, !sim.gpu.trail_initialized)
	testing.expect_value(t, sim.runtime.trail_camera_zoom, f32(2))

	sim.gpu.trail_initialized = true
	game.particle_life_note_trail_camera(&sim)
	testing.expect(t, sim.gpu.trail_initialized)
}

@(test)
test_camera_controls_zoom_to_cursor_keeps_world_point_stationary :: proc(t: ^testing.T) {
	camera: game.Camera_Control_State
	game.camera_controls_init(&camera)
	mouse := uifw.Vec2{960, 540}
	before := game.camera_controls_screen_to_world(&camera, mouse, 1920, 1080)

	game.camera_controls_zoom_to_cursor(&camera, game.CAMERA_WHEEL_DELTA_SCALE, 1, mouse, 1920, 1080)
	after := game.camera_controls_screen_to_world(&camera, mouse, 1920, 1080)

	testing.expect(t, math.abs(before[0] - after[0]) < 0.00001)
	testing.expect(t, math.abs(before[1] - after[1]) < 0.00001)
	testing.expect(t, camera.target_zoom > 1)
}

@(test)
test_camera_controls_middle_mouse_drag_pans_screen_space :: proc(t: ^testing.T) {
	camera: game.Camera_Control_State
	game.camera_controls_init(&camera)

	game.camera_controls_apply_input(&camera, {
		window_width = 100,
		window_height = 100,
		mouse_down = true,
		mouse_button = 2,
		mouse_delta = {10, 20},
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 1,
	})

	testing.expect(t, camera.target_position[0] < 0)
	testing.expect(t, camera.target_position[1] > 0)
	testing.expect(t, camera.position[0] < 0)
	testing.expect(t, camera.position[1] > 0)
}

@(test)
test_particle_life_camera_uses_shared_wasd_qe_reset_controls :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	game.particle_life_init(&sim, 1280, 720)

	game.particle_life_apply_frame_input(&sim, {key_w = true, key_d = true, key_e = true, delta_time = 1.0 / 60.0, camera_sensitivity = 2})
	testing.expect(t, sim.runtime.camera_target_x > 0)
	testing.expect(t, sim.runtime.camera_target_y > 0)
	testing.expect(t, sim.runtime.camera_target_zoom > 1)
	testing.expect(t, sim.runtime.camera_x > 0)
	testing.expect(t, sim.runtime.camera_y > 0)

	game.particle_life_apply_frame_input(&sim, {key_c = true, delta_time = 1.0 / 60.0, camera_sensitivity = 1})
	testing.expect_value(t, sim.runtime.camera_target_x, f32(0))
	testing.expect_value(t, sim.runtime.camera_target_y, f32(0))
	testing.expect_value(t, sim.runtime.camera_target_zoom, f32(1))
}

@(test)
test_camera_input_accepts_original_physical_hotkeys :: proc(t: ^testing.T) {
	app := new(game.App_State)
	defer free(app)

	game.app_apply_key_event(app, cast(sdl.Keycode)'W', .W, true)
	game.app_apply_key_event(app, cast(sdl.Keycode)'D', .D, true)
	game.app_apply_key_event(app, cast(sdl.Keycode)'E', .E, true)
	game.app_apply_key_event(app, cast(sdl.Keycode)'C', .C, true)

	testing.expect(t, app.input.key_w)
	testing.expect(t, app.input.key_d)
	testing.expect(t, app.input.key_e)
	testing.expect(t, app.input.key_c)

	game.app_apply_key_event(app, cast(sdl.Keycode)'W', .W, false)
	game.app_apply_key_event(app, cast(sdl.Keycode)'D', .D, false)
	game.app_apply_key_event(app, cast(sdl.Keycode)'E', .E, false)
	game.app_apply_key_event(app, cast(sdl.Keycode)'C', .C, false)

	testing.expect(t, !app.input.key_w)
	testing.expect(t, !app.input.key_d)
	testing.expect(t, !app.input.key_e)
	testing.expect(t, !app.input.key_c)
}

@(test)
test_camera_shift_does_not_change_original_pan_amount :: proc(t: ^testing.T) {
	base: game.Camera_Control_State
	shifted: game.Camera_Control_State
	game.camera_controls_init(&base)
	game.camera_controls_init(&shifted)

	game.camera_controls_apply_input(&base, {key_w = true, delta_time = 1.0 / 60.0, camera_sensitivity = 1})
	game.camera_controls_apply_input(&shifted, {key_w = true, key_shift = true, delta_time = 1.0 / 60.0, camera_sensitivity = 1})

	testing.expect_value(t, shifted.target_position[1], base.target_position[1])
	testing.expect_value(t, shifted.position[1], base.position[1])
}

@(test)
test_particle_life_accepts_left_side_simulation_clicks :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	game.particle_life_init(&sim, 1920, 1080)

	game.particle_life_apply_frame_input(&sim, {
		window_width = 1920,
		window_height = 1080,
		mouse_pos = {100, 100},
		mouse_down = true,
		mouse_button = 1,
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 1,
	})

	testing.expect_value(t, sim.runtime.cursor_active, u32(1))
}

@(test)
test_remaining_sim_screen_to_world_uses_ndc_coordinates :: proc(t: ^testing.T) {
	center := game.remaining_sim_screen_to_world({960, 540}, 1920, 1080)
	testing.expect_value(t, center[0], f32(0))
	testing.expect_value(t, center[1], f32(0))

	top_left := game.remaining_sim_screen_to_world({0, 0}, 1920, 1080)
	testing.expect_value(t, top_left[0], f32(-1))
	testing.expect_value(t, top_left[1], f32(1))
}

@(test)
test_remaining_sim_input_tracks_cursor_mode_and_velocity :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	game.remaining_sim_init(&sim)

	game.remaining_sim_apply_frame_input(&sim, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {50, 50},
		delta_time = 1.0 / 60.0,
	})
	game.remaining_sim_apply_frame_input(&sim, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {75, 25},
		mouse_down = true,
		mouse_button = 3,
		delta_time = 1.0 / 60.0,
	})

	testing.expect_value(t, sim.cursor_active, u32(1))
	testing.expect_value(t, sim.cursor_mode, u32(2))
	testing.expect_value(t, sim.cursor_world[0], f32(0.5))
	testing.expect_value(t, sim.cursor_world[1], f32(0.5))
	testing.expect(t, sim.cursor_world_velocity[0] > 0)
	testing.expect(t, sim.cursor_world_velocity[1] > 0)
}

@(test)
test_pellets_input_preserves_old_mouse_y_flip :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	game.remaining_sim_init(&sim)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Pellets, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {75, 25},
		mouse_down = true,
		mouse_button = 1,
		delta_time = 1.0 / 60.0,
	})

	testing.expect_value(t, sim.cursor_world[0], f32(0.5))
	testing.expect_value(t, sim.cursor_world[1], f32(-0.5))
}

@(test)
test_pellets_throw_velocity_survives_release_frame :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	game.remaining_sim_init(&sim)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Pellets, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {50, 50},
		mouse_down = true,
		mouse_button = 1,
		delta_time = 1.0 / 60.0,
	})
	game.remaining_sim_apply_frame_input_for_kind(&sim, .Pellets, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {75, 50},
		mouse_down = true,
		mouse_button = 1,
		delta_time = 1.0 / 60.0,
	})

	drag_velocity := sim.cursor_world_velocity
	testing.expect(t, drag_velocity[0] > 20)
	testing.expect(t, drag_velocity[0] < 30)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Pellets, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {75, 50},
		mouse_down = false,
		mouse_button = 1,
		delta_time = 1.0 / 60.0,
	})

	testing.expect_value(t, sim.cursor_active, u32(0))
	testing.expect_value(t, sim.cursor_mode, u32(0))
	testing.expect(t, sim.cursor_world_velocity[0] > 0)
	testing.expect(t, test_approx_f32(sim.cursor_world_velocity[0], drag_velocity[0] * 0.95))
}

@(test)
test_slime_mold_cursor_pixel_y_matches_shader_coordinates :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	game.remaining_sim_init(&sim)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Slime_Mold, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {25, 20},
		mouse_down = true,
		mouse_button = 1,
		delta_time = 1.0 / 60.0,
	})

	testing.expect_value(t, sim.cursor_pixel[0], f32(25))
	testing.expect_value(t, sim.cursor_pixel[1], f32(80))
	testing.expect_value(t, sim.cursor_world[1], f32(0.6))
}

@(test)
test_shader_manifest_parse_supports_multi_entry_sources :: proc(t: ^testing.T) {
	parsed, ok := engine.shader_manifest_parse_line("assets/shaders/simulations/slime_mold/shaders/compute.slang|compute|update_agent_speeds|build/shaders/simulations/slime_mold/shaders/compute_compute_update_agent_speeds.spv")

	testing.expect(t, ok)
	testing.expect_value(t, parsed.source_path, "assets/shaders/simulations/slime_mold/shaders/compute.slang")
	testing.expect_value(t, parsed.stage, engine.Shader_Stage.Compute)
	testing.expect_value(t, parsed.entry_point, "update_agent_speeds")
	testing.expect_value(t, parsed.spirv_path, "build/shaders/simulations/slime_mold/shaders/compute_compute_update_agent_speeds.spv")
}

@(test)
test_shader_source_fallback_constants_match_manifest_keys :: proc(t: ^testing.T) {
	testing.expect_value(t, game.FLOW_VECTOR_SHADER_SOURCE, "assets/shaders/simulations/flow/shaders/flow_vector_compute.slang")
	testing.expect_value(t, game.FLOW_VECTOR_FALLBACK_SPV, "build/shaders/simulations/flow/shaders/flow_vector_compute")
	testing.expect_value(t, game.SLIME_COMPUTE_SHADER_SOURCE, "assets/shaders/simulations/slime_mold/shaders/compute.slang")
	testing.expect_value(t, game.SLIME_SOURCE_ENTRY_UPDATE_SPEEDS, "update_agent_speeds")
	testing.expect_value(t, game.SLIME_UPDATE_SPEEDS_FALLBACK_SPV, "build/shaders/simulations/slime_mold/shaders/compute_compute_update_agent_speeds")
	testing.expect_value(t, game.MOIRE_PRESENT_FRAGMENT_SOURCE_ENTRY, "fs_main_texture")
	testing.expect_value(t, game.GRAY_SCOTT_PRESENT_FALLBACK_SPV, "build/shaders/gray_scott_present_fragment")
}

@(test)
test_slime_speed_range_change_tracking_matches_settings :: proc(t: ^testing.T) {
	gpu: game.Slime_Gpu_State
	settings := game.slime_settings_default()

	testing.expect(t, game.slime_speed_range_changed(&gpu, &settings))

	gpu.agent_speed_min_uploaded = settings.agent_speed_min
	gpu.agent_speed_max_uploaded = settings.agent_speed_max
	testing.expect(t, !game.slime_speed_range_changed(&gpu, &settings))

	settings.agent_speed_max += 0.25
	testing.expect(t, game.slime_speed_range_changed(&gpu, &settings))
}

@(test)
test_flow_defaults_keep_particles_visible_with_color_scheme_background :: proc(t: ^testing.T) {
	settings := game.flow_settings_default()

	testing.expect_value(t, settings.show_particles, true)
	testing.expect_value(t, settings.background_color_mode, game.Vector_Background_Mode.Color_Scheme)
	testing.expect_value(t, settings.background_index, int(game.Vector_Background_Mode.Color_Scheme))
	testing.expect_value(t, settings.image_fit_mode, game.Vector_Image_Fit_Mode.Stretch)
	testing.expect_value(t, settings.image_fit_index, int(game.Vector_Image_Fit_Mode.Stretch))
	testing.expect_value(t, settings.image_mirror_horizontal, false)
	testing.expect_value(t, settings.image_mirror_vertical, false)
	testing.expect_value(t, settings.image_invert_tone, false)
}

@(test)
test_flow_color_scheme_background_uses_old_lut_tail :: proc(t: ^testing.T) {
	settings := game.flow_settings_default()
	settings.background_color_mode = .Color_Scheme
	settings.background_index = int(game.Vector_Background_Mode.Color_Scheme)
	game.color_scheme_name_set(&settings.color_scheme, "MATPLOTLIB_viridis")
	settings.color_scheme_reversed = false

	scheme := game.color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
	expected := game.color_scheme_color_at(scheme, game.COLOR_SCHEME_SIZE - 1)
	actual := game.flow_background_color(&settings)
	testing.expect_value(t, actual[0], expected[0])
	testing.expect_value(t, actual[1], expected[1])
	testing.expect_value(t, actual[2], expected[2])
	testing.expect_value(t, actual[3], expected[3])
}

@(test)
test_vectors_color_scheme_background_uses_active_lut :: proc(t: ^testing.T) {
	settings := game.vectors_settings_default()
	settings.background_color_mode = .Color_Scheme
	settings.background_index = int(game.Vector_Background_Mode.Color_Scheme)
	game.color_scheme_name_set(&settings.color_scheme, "MATPLOTLIB_viridis")
	settings.color_scheme_reversed = false

	clear := game.vectors_clear_color(&settings)
	scheme := game.color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
	expected := game.color_scheme_color_at(scheme, 0)
	testing.expect_value(t, clear.r, expected[0])
	testing.expect_value(t, clear.g, expected[1])
	testing.expect_value(t, clear.b, expected[2])
	testing.expect_value(t, clear.a, expected[3])

	settings.color_scheme_reversed = true
	clear = game.vectors_clear_color(&settings)
	scheme = game.color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
	expected = game.color_scheme_color_at(scheme, 0)
	testing.expect_value(t, clear.r, expected[0])
	testing.expect_value(t, clear.g, expected[1])
	testing.expect_value(t, clear.b, expected[2])
	testing.expect_value(t, clear.a, expected[3])
}

@(test)
test_pellets_and_primordial_color_scheme_backgrounds_use_old_lut_head :: proc(t: ^testing.T) {
	pellets := game.pellets_settings_default()
	pellets.background_color_mode = .Color_Scheme
	pellets.background_index = int(game.Vector_Background_Mode.Color_Scheme)
	game.color_scheme_name_set(&pellets.color_scheme, "MATPLOTLIB_viridis")
	pellets.color_scheme_reversed = false
	scheme := game.color_scheme_effective(&pellets.color_scheme, pellets.color_scheme_reversed)
	expected := game.color_scheme_color_at(scheme, 0)
	actual := game.pellets_background_color(&pellets)
	testing.expect_value(t, actual[0], expected[0])
	testing.expect_value(t, actual[1], expected[1])
	testing.expect_value(t, actual[2], expected[2])
	testing.expect_value(t, actual[3], expected[3])

	primordial := game.primordial_settings_default()
	primordial.background_color_mode = .Color_Scheme
	primordial.background_index = int(game.Vector_Background_Mode.Color_Scheme)
	game.color_scheme_name_set(&primordial.color_scheme, "MATPLOTLIB_viridis")
	primordial.color_scheme_reversed = true
	scheme = game.color_scheme_effective(&primordial.color_scheme, primordial.color_scheme_reversed)
	expected = game.color_scheme_color_at(scheme, 0)
	actual = game.primordial_background_color(&primordial)
	testing.expect_value(t, actual[0], expected[0])
	testing.expect_value(t, actual[1], expected[1])
	testing.expect_value(t, actual[2], expected[2])
	testing.expect_value(t, actual[3], expected[3])

	clear := game.primordial_clear_color(&primordial)
	testing.expect_value(t, clear.r, expected[0])
	testing.expect_value(t, clear.g, expected[1])
	testing.expect_value(t, clear.b, expected[2])
	testing.expect_value(t, clear.a, expected[3])
}

@(test)
test_flow_shader_mouse_button_preserves_right_click_delete_mode :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	game.remaining_sim_init(&sim)

	testing.expect_value(t, game.flow_mouse_button_down_from_cursor(&sim), u32(0))

	sim.cursor_active = 1
	sim.cursor_mode = 1
	testing.expect_value(t, game.flow_mouse_button_down_from_cursor(&sim), u32(1))

	sim.cursor_mode = 2
	testing.expect_value(t, game.flow_mouse_button_down_from_cursor(&sim), u32(2))
}

@(test)
test_vectors_image_defaults_match_old_runtime_state :: proc(t: ^testing.T) {
	settings := game.vectors_settings_default()

	testing.expect_value(t, settings.vector_field_type, game.Vector_Field_Type.Noise)
	testing.expect_value(t, settings.noise.kind, game.Noise_Kind.Simplex)
	testing.expect_value(t, settings.noise.frequency, f32(5.0))
	testing.expect_value(t, settings.image_fit_mode, game.Vector_Image_Fit_Mode.Stretch)
	testing.expect_value(t, settings.image_fit_index, int(game.Vector_Image_Fit_Mode.Stretch))
	testing.expect_value(t, settings.image_mirror_horizontal, false)
	testing.expect_value(t, settings.image_mirror_vertical, false)
	testing.expect_value(t, settings.image_invert_tone, false)
}

@(test)
test_vector_image_source_rows_match_vulkan_visual_y :: proc(t: ^testing.T) {
	src_x, src_y: int

	ok := game.vectors_image_source_coord(1, 2, 1, 2, 0, 0, .Stretch, &src_x, &src_y)
	testing.expect(t, ok)
	testing.expect_value(t, src_x, 0)
	testing.expect_value(t, src_y, 1)

	ok = game.vectors_image_source_coord(1, 2, 1, 2, 0, 1, .Stretch, &src_x, &src_y)
	testing.expect(t, ok)
	testing.expect_value(t, src_x, 0)
	testing.expect_value(t, src_y, 0)
}

@(test)
test_gray_scott_nutrient_image_rows_match_vulkan_visual_y :: proc(t: ^testing.T) {
	source := [8]u8{
		255, 0, 0, 255,
		0, 0, 255, 255,
	}

	bottom_target_value := game.gray_scott_nutrient_image_value(raw_data(source[:]), 1, 2, 4, 1, 2, 0, 0, .Stretch)
	top_target_value := game.gray_scott_nutrient_image_value(raw_data(source[:]), 1, 2, 4, 1, 2, 0, 1, .Stretch)

	testing.expect(t, bottom_target_value < top_target_value)
	testing.expect_value(t, top_target_value, f32(0.2126))
}

@(test)
test_noise_defaults_match_world_creator_style_controls :: proc(t: ^testing.T) {
	settings := game.noise_settings_default(.Gabor)

	testing.expect_value(t, settings.kind, game.Noise_Kind.Gabor)
	testing.expect_value(t, settings.kind_index, int(game.Noise_Kind.Gabor))
	testing.expect_value(t, settings.noise_strength, f32(1))
	testing.expect_value(t, settings.amplitude, f32(1))
	testing.expect_value(t, settings.frequency, f32(1))
	testing.expect_value(t, settings.fractal_mode, game.Noise_Fractal_Mode.Single)
	testing.expect_value(t, settings.octaves, u32(6))
	testing.expect_value(t, settings.lacunarity, f32(2))
	testing.expect_value(t, settings.gain, f32(0.5))
	testing.expect_value(t, settings.warp_mode, game.Noise_Warp_Mode.None)
	testing.expect_value(t, settings.gabor.iterations, u32(50))
	testing.expect_value(t, settings.gabor.velocity, f32(1))
	testing.expect_value(t, settings.gabor.band_width, f32(0.01))
	testing.expect_value(t, settings.gabor.band_softness, f32(1))
}

@(test)
test_noise_all_kinds_produce_finite_bounded_samples :: proc(t: ^testing.T) {
	for i in 0 ..< len(game.NOISE_KIND_NAMES) {
		settings := game.noise_settings_default(game.Noise_Kind(i))
		settings.seed = 17
		settings.frequency = 2.25
		settings.fractal_mode = .FBM
		settings.octaves = 3
		value := game.noise_sample_2d(&settings, 0.37, -0.81, 0.125)

		testing.expect(t, value >= -1)
		testing.expect(t, value <= 1)
	}
}

@(test)
test_noise_type_specific_settings_affect_output :: proc(t: ^testing.T) {
	gabor := game.noise_settings_default(.Gabor)
	gabor.seed = 4
	gabor.gabor.band_width = 0.01
	gabor_a := game.noise_sample_2d(&gabor, 0.4, 0.8, 0.2)
	gabor.gabor.band_width = 0.25
	gabor_b := game.noise_sample_2d(&gabor, 0.4, 0.8, 0.2)
	testing.expect(t, math.abs(gabor_a - gabor_b) > 0.0001)

	phasor := game.noise_settings_default(.Phasor)
	phasor.seed = 5
	phasor.phasor.velocity = 0
	phasor_a := game.noise_sample_2d(&phasor, -0.2, 0.55, 0.25)
	phasor.phasor.velocity = 8
	phasor_b := game.noise_sample_2d(&phasor, -0.2, 0.55, 0.25)
	testing.expect(t, math.abs(phasor_a - phasor_b) > 0.0001)

	voronoi := game.noise_settings_default(.Voronoi)
	voronoi.seed = 6
	voronoi.voronoi.output = .Distance_F1
	voronoi_a := game.noise_sample_2d(&voronoi, 0.13, -0.47, 0)
	voronoi.voronoi.output = .Cell_Value
	voronoi_b := game.noise_sample_2d(&voronoi, 0.13, -0.47, 0)
	testing.expect(t, math.abs(voronoi_a - voronoi_b) > 0.0001)
}

@(test)
test_vectors_legacy_noise_preset_migrates_to_canonical_settings :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_vectors_legacy_noise.toml"
	legacy := "[vectors]\nvector_field_type = \"Noise\"\nnoise_type = \"FBM Ridged\"\nnoise_seed = 42\nnoise_scale = 3.500000\nnoise_x = -0.250000\nnoise_y = 0.750000\n"
	testing.expect(t, os.write_entire_file(path, legacy) == nil)

	loaded, ok := game.settings_load_vectors(path, game.vectors_settings_default())

	testing.expect(t, ok)
	testing.expect_value(t, loaded.noise.kind, game.Noise_Kind.Simplex)
	testing.expect_value(t, loaded.noise.fractal_mode, game.Noise_Fractal_Mode.Ridged)
	testing.expect_value(t, loaded.noise.seed, u32(42))
	testing.expect_value(t, loaded.noise.frequency, f32(3.5))
	testing.expect_value(t, loaded.noise.offset_x, f32(-0.25))
	testing.expect_value(t, loaded.noise.offset_y, f32(0.75))
}

@(test)
test_moire_image_defaults_match_old_runtime_state :: proc(t: ^testing.T) {
	settings := game.moire_settings_default()

	testing.expect_value(t, settings.image_mode_enabled, false)
	testing.expect_value(t, settings.image_fit_mode, game.Vector_Image_Fit_Mode.Fit_V)
	testing.expect_value(t, settings.image_fit_index, int(game.Vector_Image_Fit_Mode.Fit_V))
	testing.expect_value(t, settings.image_mirror_horizontal, false)
	testing.expect_value(t, settings.image_mirror_vertical, false)
	testing.expect_value(t, settings.image_invert_tone, true)
	testing.expect_value(t, settings.image_interference_mode, game.Moire_Image_Interference_Mode.Modulate)
}

@(test)
test_remaining_image_settings_round_trip_through_tomlc17 :: proc(t: ^testing.T) {
	flow_path := "/tmp/vizzaodin_flow_remaining_roundtrip.toml"
	flow := game.flow_settings_default()
	flow.vector_field_type = .Image
	flow.vector_field_index = int(game.Vector_Field_Type.Image)
	flow.image_fit_mode = .Fit_H
	flow.image_fit_index = int(game.Vector_Image_Fit_Mode.Fit_H)
	flow.image_mirror_horizontal = true
	flow.image_invert_tone = true
	flow.noise.kind = .Checkerboard
	flow.noise.seed = 77
	flow.noise.frequency = 2.5
	flow.noise.offset_x = -0.75
	flow.noise.offset_y = 1.25
	flow.noise.fractal_mode = .FBM
	flow.noise.octaves = 4
	flow.vector_magnitude = 0.45
	flow.total_pool_size = 12345
	flow.particle_lifetime = 6.5
	flow.particle_speed = 1.75
	flow.particle_size = 9
	flow.particle_shape = .Diamond
	flow.shape_index = int(game.Flow_Particle_Shape.Diamond)
	flow.particle_autospawn = false
	flow.show_particles = false
	flow.autospawn_rate = 12
	flow.brush_spawn_rate = 34
	flow.foreground_color_mode = .Direction
	flow.foreground_index = int(game.Flow_Foreground_Mode.Direction)
	flow.background_color_mode = .White
	flow.background_index = int(game.Vector_Background_Mode.White)
	flow.trail_decay_rate = 0.25
	flow.trail_deposition_rate = 0.75
	flow.trail_diffusion_rate = 0.125
	flow.trail_wash_out_rate = 0.0625
	flow.trail_map_filtering = .Linear
	flow.trail_filtering_index = int(game.Flow_Trail_Map_Filtering.Linear)
	game.write_fixed_string(flow.image_path[:], "config/flow.png")
	testing.expect(t, game.settings_save_flow(flow_path, flow))
	loaded_flow, flow_ok := game.settings_load_flow(flow_path, game.flow_settings_default())
	testing.expect(t, flow_ok)
	testing.expect_value(t, loaded_flow.vector_field_type, game.Vector_Field_Type.Image)
	testing.expect_value(t, loaded_flow.image_fit_mode, game.Vector_Image_Fit_Mode.Fit_H)
	testing.expect_value(t, loaded_flow.image_mirror_horizontal, true)
	testing.expect_value(t, loaded_flow.image_invert_tone, true)
	testing.expect_value(t, game.fixed_string(loaded_flow.image_path[:]), "config/flow.png")
	testing.expect_value(t, loaded_flow.noise.kind, game.Noise_Kind.Checkerboard)
	testing.expect_value(t, loaded_flow.noise.seed, u32(77))
	testing.expect_value(t, loaded_flow.noise.frequency, f32(2.5))
	testing.expect_value(t, loaded_flow.noise.offset_x, f32(-0.75))
	testing.expect_value(t, loaded_flow.noise.offset_y, f32(1.25))
	testing.expect_value(t, loaded_flow.noise.fractal_mode, game.Noise_Fractal_Mode.FBM)
	testing.expect_value(t, loaded_flow.noise.octaves, u32(4))
	testing.expect_value(t, loaded_flow.vector_magnitude, f32(0.45))
	testing.expect_value(t, loaded_flow.total_pool_size, u32(12345))
	testing.expect_value(t, loaded_flow.particle_lifetime, f32(6.5))
	testing.expect_value(t, loaded_flow.particle_speed, f32(1.75))
	testing.expect_value(t, loaded_flow.particle_size, u32(9))
	testing.expect_value(t, loaded_flow.particle_shape, game.Flow_Particle_Shape.Diamond)
	testing.expect_value(t, loaded_flow.particle_autospawn, false)
	testing.expect_value(t, loaded_flow.show_particles, false)
	testing.expect_value(t, loaded_flow.autospawn_rate, u32(12))
	testing.expect_value(t, loaded_flow.brush_spawn_rate, u32(34))
	testing.expect_value(t, loaded_flow.foreground_color_mode, game.Flow_Foreground_Mode.Direction)
	testing.expect_value(t, loaded_flow.background_color_mode, game.Vector_Background_Mode.White)
	testing.expect_value(t, loaded_flow.trail_decay_rate, f32(0.25))
	testing.expect_value(t, loaded_flow.trail_deposition_rate, f32(0.75))
	testing.expect_value(t, loaded_flow.trail_diffusion_rate, f32(0.125))
	testing.expect_value(t, loaded_flow.trail_wash_out_rate, f32(0.0625))
	testing.expect_value(t, loaded_flow.trail_map_filtering, game.Flow_Trail_Map_Filtering.Linear)

	moire_path := "/tmp/vizzaodin_moire_remaining_roundtrip.toml"
	moire := game.moire_settings_default()
	moire.speed = 0.33
	moire.generator_type = .Radial
	moire.generator_index = int(game.Moire_Generator_Type.Radial)
	moire.base_freq = 12.5
	moire.moire_amount = 1.25
	moire.moire_rotation = -0.75
	moire.moire_scale = 1.75
	moire.moire_interference = 0.875
	moire.moire_rotation3 = 0.45
	moire.moire_scale3 = 2.25
	moire.moire_weight3 = 0.625
	moire.radial_swirl_strength = 0.375
	moire.radial_starburst_count = 24
	moire.radial_center_brightness = 2.5
	moire.advect_strength = 1.25
	moire.advect_speed = 3.5
	moire.curl = 1.5
	moire.decay = 0.925
	moire.image_mode_enabled = true
	moire.image_fit_mode = .Center
	moire.image_fit_index = int(game.Vector_Image_Fit_Mode.Center)
	moire.image_mirror_horizontal = true
	moire.image_mirror_vertical = true
	moire.image_invert_tone = false
	moire.image_interference_mode = .Overlay
	moire.interference_index = int(game.Moire_Image_Interference_Mode.Overlay)
	game.write_fixed_string(moire.image_path[:], "config/moire.png")
	testing.expect(t, game.settings_save_moire(moire_path, moire))
	loaded_moire, moire_ok := game.settings_load_moire(moire_path, game.moire_settings_default())
	testing.expect(t, moire_ok)
	testing.expect_value(t, loaded_moire.speed, f32(0.33))
	testing.expect_value(t, loaded_moire.generator_type, game.Moire_Generator_Type.Radial)
	testing.expect_value(t, loaded_moire.base_freq, f32(12.5))
	testing.expect_value(t, loaded_moire.moire_amount, f32(1.25))
	testing.expect_value(t, loaded_moire.moire_rotation, f32(-0.75))
	testing.expect_value(t, loaded_moire.moire_scale, f32(1.75))
	testing.expect_value(t, loaded_moire.moire_interference, f32(0.875))
	testing.expect_value(t, loaded_moire.moire_rotation3, f32(0.45))
	testing.expect_value(t, loaded_moire.moire_scale3, f32(2.25))
	testing.expect_value(t, loaded_moire.moire_weight3, f32(0.625))
	testing.expect_value(t, loaded_moire.radial_swirl_strength, f32(0.375))
	testing.expect_value(t, loaded_moire.radial_starburst_count, f32(24))
	testing.expect_value(t, loaded_moire.radial_center_brightness, f32(2.5))
	testing.expect_value(t, loaded_moire.advect_strength, f32(1.25))
	testing.expect_value(t, loaded_moire.advect_speed, f32(3.5))
	testing.expect_value(t, loaded_moire.curl, f32(1.5))
	testing.expect_value(t, loaded_moire.decay, f32(0.925))
	testing.expect_value(t, loaded_moire.image_mode_enabled, true)
	testing.expect_value(t, loaded_moire.image_fit_mode, game.Vector_Image_Fit_Mode.Center)
	testing.expect_value(t, loaded_moire.image_mirror_horizontal, true)
	testing.expect_value(t, loaded_moire.image_mirror_vertical, true)
	testing.expect_value(t, loaded_moire.image_invert_tone, false)
	testing.expect_value(t, loaded_moire.image_interference_mode, game.Moire_Image_Interference_Mode.Overlay)
	testing.expect_value(t, game.fixed_string(loaded_moire.image_path[:]), "config/moire.png")

	vectors_path := "/tmp/vizzaodin_vectors_remaining_roundtrip.toml"
	vectors := game.vectors_settings_default()
	vectors.vector_field_type = .Image
	vectors.vector_field_index = int(game.Vector_Field_Type.Image)
	vectors.image_fit_mode = .Fit_V
	vectors.image_fit_index = int(game.Vector_Image_Fit_Mode.Fit_V)
	vectors.image_mirror_horizontal = true
	vectors.noise.kind = .Cylinders
	vectors.noise.seed = 123
	vectors.noise.frequency = 6.25
	vectors.density = 0.04
	vectors.line_length = 0.08
	vectors.line_width = 0.004
	vectors.background_color_mode = .Color_Scheme
	vectors.background_index = int(game.Vector_Background_Mode.Color_Scheme)
	testing.expect(t, game.settings_save_vectors(vectors_path, vectors))
	loaded_vectors, vectors_ok := game.settings_load_vectors(vectors_path, game.vectors_settings_default())
	testing.expect(t, vectors_ok)
	testing.expect_value(t, loaded_vectors.vector_field_type, game.Vector_Field_Type.Image)
	testing.expect_value(t, loaded_vectors.image_fit_mode, game.Vector_Image_Fit_Mode.Fit_V)
	testing.expect_value(t, loaded_vectors.image_mirror_horizontal, true)
	testing.expect_value(t, loaded_vectors.noise.kind, game.Noise_Kind.Cylinders)
	testing.expect_value(t, loaded_vectors.noise.seed, u32(123))
	testing.expect_value(t, loaded_vectors.noise.frequency, f32(6.25))
	testing.expect_value(t, loaded_vectors.density, f32(0.04))
	testing.expect_value(t, loaded_vectors.line_length, f32(0.08))
	testing.expect_value(t, loaded_vectors.line_width, f32(0.004))
	testing.expect_value(t, loaded_vectors.background_color_mode, game.Vector_Background_Mode.Color_Scheme)
}

@(test)
test_remaining_core_settings_round_trip_through_tomlc17 :: proc(t: ^testing.T) {
	primordial_path := "/tmp/vizzaodin_primordial_remaining_roundtrip.toml"
	primordial := game.primordial_settings_default()
	primordial.particle_count = 2345
	primordial.random_seed = 99
	primordial.position_generator = 6
	primordial.position_generator_index = 6
	primordial.alpha = 22.5
	primordial.beta = -1.25
	primordial.velocity = 0.75
	primordial.radius = 0.2
	primordial.dt = 0.033
	primordial.particle_size = 0.03
	primordial.density_radius = 0.09
	primordial.background_color_mode = .White
	primordial.background_index = int(game.Vector_Background_Mode.White)
	primordial.foreground_color_mode = .Velocity
	primordial.foreground_index = int(game.Primordial_Foreground_Mode.Velocity)
	primordial.traces_enabled = true
	primordial.trace_fade = 0.35
	primordial.wrap_edges = false
	testing.expect(t, game.settings_save_primordial(primordial_path, primordial))
	loaded_primordial, primordial_ok := game.settings_load_primordial(primordial_path, game.primordial_settings_default())
	testing.expect(t, primordial_ok)
	testing.expect_value(t, loaded_primordial.particle_count, u32(2345))
	testing.expect_value(t, loaded_primordial.random_seed, u32(99))
	testing.expect_value(t, loaded_primordial.position_generator, u32(6))
	testing.expect_value(t, loaded_primordial.alpha, f32(22.5))
	testing.expect_value(t, loaded_primordial.beta, f32(-1.25))
	testing.expect_value(t, loaded_primordial.velocity, f32(0.75))
	testing.expect_value(t, loaded_primordial.radius, f32(0.2))
	testing.expect_value(t, loaded_primordial.dt, f32(0.033))
	testing.expect_value(t, loaded_primordial.particle_size, f32(0.03))
	testing.expect_value(t, loaded_primordial.density_radius, f32(0.09))
	testing.expect_value(t, loaded_primordial.background_color_mode, game.Vector_Background_Mode.White)
	testing.expect_value(t, loaded_primordial.foreground_color_mode, game.Primordial_Foreground_Mode.Velocity)
	testing.expect_value(t, loaded_primordial.traces_enabled, true)
	testing.expect_value(t, loaded_primordial.trace_fade, f32(0.35))
	testing.expect_value(t, loaded_primordial.wrap_edges, false)

	pellets_path := "/tmp/vizzaodin_pellets_remaining_roundtrip.toml"
	pellets := game.pellets_settings_default()
	pellets.particle_count = 3456
	pellets.particle_size = 0.025
	pellets.collision_damping = 0.6
	pellets.initial_velocity_max = 0.5
	pellets.initial_velocity_min = 0.25
	pellets.random_seed = 123
	pellets.background_color_mode = .Gray18
	pellets.background_index = int(game.Vector_Background_Mode.Gray18)
	pellets.gravitational_constant = 0.000002
	pellets.energy_damping = 0.7
	pellets.gravity_softening = 0.01
	pellets.density_radius = 0.12
	pellets.foreground_color_mode = .Velocity
	pellets.foreground_index = int(game.Pellets_Foreground_Mode.Velocity)
	pellets.trails_enabled = true
	pellets.trail_fade = 0.42
	pellets.density_damping_enabled = true
	pellets.overlap_resolution_strength = 0.14
	testing.expect(t, game.settings_save_pellets(pellets_path, pellets))
	loaded_pellets, pellets_ok := game.settings_load_pellets(pellets_path, game.pellets_settings_default())
	testing.expect(t, pellets_ok)
	testing.expect_value(t, loaded_pellets.particle_count, u32(3456))
	testing.expect_value(t, loaded_pellets.particle_size, f32(0.025))
	testing.expect_value(t, loaded_pellets.collision_damping, f32(0.6))
	testing.expect_value(t, loaded_pellets.initial_velocity_max, f32(0.5))
	testing.expect_value(t, loaded_pellets.initial_velocity_min, f32(0.25))
	testing.expect_value(t, loaded_pellets.random_seed, u32(123))
	testing.expect_value(t, loaded_pellets.background_color_mode, game.Vector_Background_Mode.Gray18)
	testing.expect_value(t, loaded_pellets.gravitational_constant, f32(0.000002))
	testing.expect_value(t, loaded_pellets.energy_damping, f32(0.7))
	testing.expect_value(t, loaded_pellets.gravity_softening, f32(0.01))
	testing.expect_value(t, loaded_pellets.density_radius, f32(0.12))
	testing.expect_value(t, loaded_pellets.foreground_color_mode, game.Pellets_Foreground_Mode.Velocity)
	testing.expect_value(t, loaded_pellets.trails_enabled, true)
	testing.expect_value(t, loaded_pellets.trail_fade, f32(0.42))
	testing.expect_value(t, loaded_pellets.density_damping_enabled, true)
	testing.expect_value(t, loaded_pellets.overlap_resolution_strength, f32(0.14))

	voronoi_path := "/tmp/vizzaodin_voronoi_remaining_roundtrip.toml"
	voronoi := game.voronoi_settings_default()
	voronoi.point_count = 1234
	voronoi.time_scale = 2.5
	voronoi.drift = 0.75
	voronoi.brownian_speed = 42.5
	voronoi.random_seed = 44
	voronoi.borders_enabled = true
	voronoi.border_width = 6.5
	voronoi.color_mode = 2
	voronoi.color_mode_index = 2
	testing.expect(t, game.settings_save_voronoi(voronoi_path, voronoi))
	loaded_voronoi, voronoi_ok := game.settings_load_voronoi(voronoi_path, game.voronoi_settings_default())
	testing.expect(t, voronoi_ok)
	testing.expect_value(t, loaded_voronoi.point_count, u32(1234))
	testing.expect_value(t, loaded_voronoi.time_scale, f32(2.5))
	testing.expect_value(t, loaded_voronoi.drift, f32(0.75))
	testing.expect_value(t, loaded_voronoi.brownian_speed, f32(42.5))
	testing.expect_value(t, loaded_voronoi.random_seed, u32(44))
	testing.expect_value(t, loaded_voronoi.borders_enabled, true)
	testing.expect_value(t, loaded_voronoi.border_width, f32(6.5))
	testing.expect_value(t, loaded_voronoi.color_mode, u32(2))
	testing.expect_value(t, loaded_voronoi.color_mode_index, 2)

	slime_path := "/tmp/vizzaodin_slime_remaining_roundtrip.toml"
	slime := game.slime_settings_default()
	slime.agent_jitter = 0.12
	slime.agent_heading_start = 15
	slime.agent_heading_end = 300
	slime.agent_sensor_angle = 0.9
	slime.agent_sensor_distance = 45
	slime.agent_speed_max = 90
	slime.agent_speed_min = 12
	slime.agent_turn_rate = 0.7
	slime.pheromone_decay_rate = 12
	slime.pheromone_deposition_rate = 34
	slime.pheromone_diffusion_rate = 56
	slime.diffusion_frequency = 3
	slime.decay_frequency = 5
	slime.random_seed = 321
	slime.position_generator = 6
	slime.position_generator_index = 6
	slime.mask_pattern = .Wave_Function
	slime.mask_pattern_index = int(game.Slime_Mask_Pattern.Wave_Function)
	slime.mask_target = .Agent_Speed
	slime.mask_target_index = int(game.Slime_Mask_Target.Agent_Speed)
	slime.mask_strength = 0.65
	slime.mask_curve = 1.75
	slime.mask_image_fit_mode = .Fit_H
	slime.mask_image_fit_index = int(game.Vector_Image_Fit_Mode.Fit_H)
	game.write_fixed_string(slime.mask_image_path[:], "config/slime_mask.png")
	slime.position_image_fit_mode = .Center
	slime.position_image_fit_index = int(game.Vector_Image_Fit_Mode.Center)
	game.write_fixed_string(slime.position_image_path[:], "config/slime_position.png")
	slime.mask_mirror_horizontal = true
	slime.mask_mirror_vertical = true
	slime.mask_invert_tone = true
	slime.mask_reversed = true
	slime.trail_map_filtering = .Linear
	slime.trail_filtering_index = int(game.Flow_Trail_Map_Filtering.Linear)
	slime.background_mode = .White
	slime.background_index = int(game.Slime_Background_Mode.White)
	testing.expect(t, game.settings_save_slime(slime_path, slime))
	loaded_slime, slime_ok := game.settings_load_slime(slime_path, game.slime_settings_default())
	testing.expect(t, slime_ok)
	testing.expect_value(t, loaded_slime.agent_jitter, f32(0.12))
	testing.expect_value(t, loaded_slime.agent_heading_start, f32(15))
	testing.expect_value(t, loaded_slime.agent_heading_end, f32(300))
	testing.expect_value(t, loaded_slime.agent_sensor_angle, f32(0.9))
	testing.expect_value(t, loaded_slime.agent_sensor_distance, f32(45))
	testing.expect_value(t, loaded_slime.agent_speed_max, f32(90))
	testing.expect_value(t, loaded_slime.agent_speed_min, f32(12))
	testing.expect_value(t, loaded_slime.agent_turn_rate, f32(0.7))
	testing.expect_value(t, loaded_slime.pheromone_decay_rate, f32(12))
	testing.expect_value(t, loaded_slime.pheromone_deposition_rate, f32(34))
	testing.expect_value(t, loaded_slime.pheromone_diffusion_rate, f32(56))
	testing.expect_value(t, loaded_slime.diffusion_frequency, u32(3))
	testing.expect_value(t, loaded_slime.decay_frequency, u32(5))
	testing.expect_value(t, loaded_slime.random_seed, u32(321))
	testing.expect_value(t, loaded_slime.position_generator, u32(6))
	testing.expect_value(t, loaded_slime.mask_pattern, game.Slime_Mask_Pattern.Wave_Function)
	testing.expect_value(t, loaded_slime.mask_target, game.Slime_Mask_Target.Agent_Speed)
	testing.expect_value(t, loaded_slime.mask_strength, f32(0.65))
	testing.expect_value(t, loaded_slime.mask_curve, f32(1.75))
	testing.expect_value(t, loaded_slime.mask_image_fit_mode, game.Vector_Image_Fit_Mode.Fit_H)
	testing.expect_value(t, game.fixed_string(loaded_slime.mask_image_path[:]), "config/slime_mask.png")
	testing.expect_value(t, loaded_slime.position_image_fit_mode, game.Vector_Image_Fit_Mode.Center)
	testing.expect_value(t, game.fixed_string(loaded_slime.position_image_path[:]), "config/slime_position.png")
	testing.expect_value(t, loaded_slime.mask_mirror_horizontal, true)
	testing.expect_value(t, loaded_slime.mask_mirror_vertical, true)
	testing.expect_value(t, loaded_slime.mask_invert_tone, true)
	testing.expect_value(t, loaded_slime.mask_reversed, true)
	testing.expect_value(t, loaded_slime.trail_map_filtering, game.Flow_Trail_Map_Filtering.Linear)
	testing.expect_value(t, loaded_slime.background_mode, game.Slime_Background_Mode.White)
}

@(test)
test_flow_saved_preset_keeps_current_color_scheme :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_flow_preserve_color_preset.toml"
	preset := game.flow_settings_default()
	preset.vector_magnitude = 0.37
	game.color_scheme_name_set(&preset.color_scheme, "MATPLOTLIB_viridis")
	preset.color_scheme_reversed = true
	testing.expect(t, game.settings_save_flow(path, preset))

	current := game.flow_settings_default()
	game.color_scheme_name_set(&current.color_scheme, "ZELDA_Aqua")
	current.color_scheme_reversed = false
	loaded, ok := game.settings_load_flow_preset(path, current)

	testing.expect(t, ok)
	testing.expect_value(t, loaded.vector_magnitude, f32(0.37))
	test_expect_color_scheme(t, &loaded.color_scheme, loaded.color_scheme_reversed, "ZELDA_Aqua", false)
}

@(test)
test_remaining_builtin_presets_keep_current_color_scheme :: proc(t: ^testing.T) {
	expected_name := "ZELDA_Aqua"
	expected_reversed := false
	sim: game.Remaining_Sim_State
	game.remaining_sim_init(&sim)

	game.color_scheme_name_set(&sim.moire.color_scheme, expected_name)
	sim.moire.color_scheme_reversed = expected_reversed
	game.remaining_sim_apply_builtin_preset(&sim, game.Remaining_Sim_Kind.Moire, 2)
	test_expect_color_scheme(t, &sim.moire.color_scheme, sim.moire.color_scheme_reversed, expected_name, expected_reversed)

	game.color_scheme_name_set(&sim.vectors.color_scheme, expected_name)
	sim.vectors.color_scheme_reversed = expected_reversed
	game.remaining_sim_apply_builtin_preset(&sim, game.Remaining_Sim_Kind.Vectors, 0)
	test_expect_color_scheme(t, &sim.vectors.color_scheme, sim.vectors.color_scheme_reversed, expected_name, expected_reversed)

	game.color_scheme_name_set(&sim.primordial.color_scheme, expected_name)
	sim.primordial.color_scheme_reversed = expected_reversed
	game.remaining_sim_apply_builtin_preset(&sim, game.Remaining_Sim_Kind.Primordial, 0)
	test_expect_color_scheme(t, &sim.primordial.color_scheme, sim.primordial.color_scheme_reversed, expected_name, expected_reversed)

	game.color_scheme_name_set(&sim.voronoi.color_scheme, expected_name)
	sim.voronoi.color_scheme_reversed = expected_reversed
	game.remaining_sim_apply_builtin_preset(&sim, game.Remaining_Sim_Kind.Voronoi_CA, 0)
	test_expect_color_scheme(t, &sim.voronoi.color_scheme, sim.voronoi.color_scheme_reversed, expected_name, expected_reversed)

	game.color_scheme_name_set(&sim.pellets.color_scheme, expected_name)
	sim.pellets.color_scheme_reversed = expected_reversed
	game.remaining_sim_apply_builtin_preset(&sim, game.Remaining_Sim_Kind.Pellets, 0)
	test_expect_color_scheme(t, &sim.pellets.color_scheme, sim.pellets.color_scheme_reversed, expected_name, expected_reversed)

	game.color_scheme_name_set(&sim.flow.color_scheme, expected_name)
	sim.flow.color_scheme_reversed = expected_reversed
	game.remaining_sim_apply_builtin_preset(&sim, game.Remaining_Sim_Kind.Flow_Field, 0)
	test_expect_color_scheme(t, &sim.flow.color_scheme, sim.flow.color_scheme_reversed, expected_name, expected_reversed)

	game.color_scheme_name_set(&sim.slime.color_scheme, expected_name)
	sim.slime.color_scheme_reversed = expected_reversed
	game.remaining_sim_apply_builtin_preset(&sim, game.Remaining_Sim_Kind.Slime_Mold, 2)
	test_expect_color_scheme(t, &sim.slime.color_scheme, sim.slime.color_scheme_reversed, expected_name, expected_reversed)
}

@(test)
test_pellets_trail_defaults_match_old_runtime_state :: proc(t: ^testing.T) {
	settings := game.pellets_settings_default()

	testing.expect_value(t, settings.trails_enabled, false)
	testing.expect_value(t, settings.trail_fade, f32(0.5))
}

@(test)
test_primordial_visual_defaults_match_old_runtime_state :: proc(t: ^testing.T) {
	settings := game.primordial_settings_default()

	testing.expect_value(t, settings.particle_count, u32(10000))
	testing.expect_value(t, settings.random_seed, u32(42))
	testing.expect_value(t, settings.position_generator, u32(0))
	testing.expect_value(t, settings.particle_size, f32(0.01))
	testing.expect_value(t, settings.density_radius, f32(0.04))
	testing.expect_value(t, settings.background_color_mode, game.Vector_Background_Mode.Color_Scheme)
	testing.expect_value(t, settings.foreground_color_mode, game.Primordial_Foreground_Mode.Heading)
	testing.expect_value(t, settings.traces_enabled, false)
	testing.expect_value(t, settings.trace_fade, f32(0.48))
	testing.expect_value(t, settings.background_index, int(game.Vector_Background_Mode.Color_Scheme))
	testing.expect_value(t, settings.foreground_index, int(game.Primordial_Foreground_Mode.Heading))
	testing.expect_value(t, settings.position_generator_index, 0)
}

@(test)
test_primordial_position_generators_match_old_bounds :: proc(t: ^testing.T) {
	rng := u32(42)
	center := game.primordial_generate_position(0, 1, &rng)
	testing.expect(t, math.abs(center[0]) <= 0.3)
	testing.expect(t, math.abs(center[1]) <= 0.3)

	rng = 42
	ring := game.primordial_generate_position(0, 4, &rng)
	ring_radius := math.sqrt(ring[0] * ring[0] + ring[1] * ring[1])
	testing.expect(t, ring_radius >= 0.34)
	testing.expect(t, ring_radius <= 0.36)

	rng = 42
	line := game.primordial_generate_position(0, 5, &rng)
	testing.expect(t, math.abs(line[1]) <= 0.15)

	rng = 42
	spiral := game.primordial_generate_position(0, 6, &rng)
	spiral_radius := math.sqrt(spiral[0] * spiral[0] + spiral[1] * spiral[1])
	testing.expect(t, spiral_radius <= 0.7)
}

@(test)
test_app_ui_navigation_tracks_previous_mode :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	testing.expect_value(t, ui.mode, game.App_Mode.Main_Menu)
	game.app_ui_navigate(&ui, .Options)
	testing.expect_value(t, ui.mode, game.App_Mode.Options)
	testing.expect_value(t, ui.previous_mode, game.App_Mode.Main_Menu)
}

@(test)
test_main_menu_backdrop_selects_different_palette_on_reentry :: proc(t: ^testing.T) {
	names := game.color_scheme_available_names_cached()
	if len(names) < 2 {
		testing.expect(t, true)
		return
	}

	backdrop: game.Main_Menu_Backdrop_Gpu_State
	game.main_menu_backdrop_select_next_palette(&backdrop)
	first: game.Color_Scheme_Name
	game.color_scheme_name_set(&first, game.main_menu_backdrop_current_palette_name(&backdrop))
	game.main_menu_backdrop_select_next_palette(&backdrop)
	second := game.main_menu_backdrop_current_palette_name(&backdrop)

	testing.expect(t, game.color_scheme_name_get(&first) != second)
	testing.expect(t, len(game.color_scheme_name_get(&first)) > 0)
	testing.expect(t, len(second) > 0)
}

@(test)
test_main_menu_backdrop_seed_changes_initial_palette_sequence :: proc(t: ^testing.T) {
	names := game.color_scheme_available_names_cached()
	if len(names) < 2 {
		testing.expect(t, true)
		return
	}

	first: game.Main_Menu_Backdrop_Gpu_State
	second: game.Main_Menu_Backdrop_Gpu_State
	game.main_menu_backdrop_seed_palette(&first, 1)
	game.main_menu_backdrop_seed_palette(&second, 2)

	game.main_menu_backdrop_select_next_palette(&first)
	game.main_menu_backdrop_select_next_palette(&second)

	testing.expect(t, game.main_menu_backdrop_current_palette_name(&first) != game.main_menu_backdrop_current_palette_name(&second))
}

@(test)
test_app_ui_main_menu_logo_click_requests_palette_randomize :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {128, 112}, mouse_pressed = true, mouse_released = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ui.main_menu_palette_randomize_requested)
}

@(test)
test_render_backend_consumes_main_menu_palette_randomize_request :: proc(t: ^testing.T) {
	names := game.color_scheme_available_names_cached()
	if len(names) < 2 {
		testing.expect(t, true)
		return
	}

	backend: game.Render_Backend
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	game.render_backend_handle_main_menu_palette_requests(&backend, &ui, .Main_Menu)
	first: game.Color_Scheme_Name
	game.color_scheme_name_set(&first, game.main_menu_backdrop_current_palette_name(&backend.main_menu_backdrop))

	ui.main_menu_palette_randomize_requested = true
	game.render_backend_handle_main_menu_palette_requests(&backend, &ui, .Main_Menu)
	second := game.main_menu_backdrop_current_palette_name(&backend.main_menu_backdrop)

	testing.expect(t, !ui.main_menu_palette_randomize_requested)
	testing.expect(t, game.color_scheme_name_get(&first) != second)
}

@(test)
test_main_menu_preview_palette_helper_sets_reversed_scheme :: proc(t: ^testing.T) {
	palette := "MATPLOTLIB_viridis"

	gray_scott := game.gray_scott_default_settings()
	game.render_main_menu_apply_gray_scott_palette(&gray_scott, palette)
	testing.expect_value(t, game.color_scheme_name_get(&gray_scott.color_scheme), palette)
	testing.expect(t, gray_scott.color_scheme_reversed)

	particle_life := game.particle_life_default_settings()
	game.render_main_menu_apply_particle_life_palette(&particle_life, palette)
	testing.expect_value(t, game.color_scheme_name_get(&particle_life.color_scheme), palette)
	testing.expect(t, particle_life.color_scheme_reversed)

	flow := game.flow_settings_default()
	game.render_main_menu_apply_flow_palette(&flow, palette)
	testing.expect_value(t, game.color_scheme_name_get(&flow.color_scheme), palette)
	testing.expect(t, flow.color_scheme_reversed)
}

@(test)
test_main_menu_launch_palette_helper_sets_live_sim_schemes :: proc(t: ^testing.T) {
	palette := "ZELDA_Aqua"
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	gray_scott := game.gray_scott_default_settings()
	particle_life := game.particle_life_default_settings()

	testing.expect(t, game.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Slime_Mold, palette))
	test_expect_color_scheme(t, &ui.slime_mold.slime.color_scheme, ui.slime_mold.slime.color_scheme_reversed, palette, true)
	testing.expect(t, game.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Gray_Scott, palette))
	test_expect_color_scheme(t, &gray_scott.color_scheme, gray_scott.color_scheme_reversed, palette, true)
	testing.expect(t, game.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Particle_Life, palette))
	test_expect_color_scheme(t, &particle_life.color_scheme, particle_life.color_scheme_reversed, palette, true)
	testing.expect(t, game.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Flow_Field, palette))
	test_expect_color_scheme(t, &ui.flow_field.flow.color_scheme, ui.flow_field.flow.color_scheme_reversed, palette, true)
	testing.expect(t, game.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Pellets, palette))
	test_expect_color_scheme(t, &ui.pellets.pellets.color_scheme, ui.pellets.pellets.color_scheme_reversed, palette, true)
	testing.expect(t, game.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Voronoi_CA, palette))
	test_expect_color_scheme(t, &ui.voronoi_ca.voronoi.color_scheme, ui.voronoi_ca.voronoi.color_scheme_reversed, palette, true)
	testing.expect(t, game.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Moire, palette))
	test_expect_color_scheme(t, &ui.moire.moire.color_scheme, ui.moire.moire.color_scheme_reversed, palette, true)
	testing.expect(t, game.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Vectors, palette))
	test_expect_color_scheme(t, &ui.vectors.vectors.color_scheme, ui.vectors.vectors.color_scheme_reversed, palette, true)
	testing.expect(t, game.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Primordial, palette))
	test_expect_color_scheme(t, &ui.primordial.primordial.color_scheme, ui.primordial.primordial.color_scheme_reversed, palette, true)
	testing.expect(t, !game.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Gradient_Editor, palette))
}

@(test)
test_render_worker_main_menu_launch_applies_current_menu_palette_once :: proc(t: ^testing.T) {
	palette := "MATPLOTLIB_viridis"
	runtime := new(game.Render_Worker_Runtime)
	defer free(runtime)
	game.app_ui_init(&runtime.app_ui, game.settings_default())
	game.color_scheme_name_set(&runtime.render_backend.main_menu_backdrop.palette_name, palette)

	runtime.app_ui.mode = .Flow_Field
	game.render_worker_apply_main_menu_palette_after_navigation(runtime, .Options)
	test_expect_color_scheme(t, &runtime.app_ui.flow_field.flow.color_scheme, runtime.app_ui.flow_field.flow.color_scheme_reversed, "MATPLOTLIB_cubehelix", true)

	game.render_worker_apply_main_menu_palette_after_navigation(runtime, .Main_Menu)
	test_expect_color_scheme(t, &runtime.app_ui.flow_field.flow.color_scheme, runtime.app_ui.flow_field.flow.color_scheme_reversed, palette, true)
}

@(test)
test_render_worker_set_color_scheme_preserves_reversed_when_omitted :: proc(t: ^testing.T) {
	runtime := new(game.Render_Worker_Runtime)
	defer free(runtime)
	game.app_ui_init(&runtime.app_ui, game.settings_default())

	runtime.app_ui.slime_mold.slime.color_scheme_reversed = false
	testing.expect(t, game.render_worker_set_color_scheme(runtime, .Slime_Mold, "MATPLOTLIB_viridis", false, false))
	test_expect_color_scheme(t, &runtime.app_ui.slime_mold.slime.color_scheme, runtime.app_ui.slime_mold.slime.color_scheme_reversed, "MATPLOTLIB_viridis", false)

	runtime.app_ui.slime_mold.slime.color_scheme_reversed = true
	testing.expect(t, game.render_worker_set_color_scheme(runtime, .Slime_Mold, "ZELDA_Aqua", false, true))
	test_expect_color_scheme(t, &runtime.app_ui.slime_mold.slime.color_scheme, runtime.app_ui.slime_mold.slime.color_scheme_reversed, "ZELDA_Aqua", false)
}

@(test)
test_app_settings_round_trip_options_fields :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_app_settings_roundtrip.toml"
	settings := game.settings_default()
	settings.ui_scale = 1.4
	settings.default_fps_limit = 144
	settings.default_fps_limit_enabled = true
	settings.window_maximized = true
	settings.auto_hide_ui = false
	settings.auto_hide_delay = 4500
	settings.menu_position = "right"
	settings.experimental_controller_ui = false
	settings.default_camera_sensitivity = 2.2
	settings.texture_filtering = "Nearest"

	testing.expect(t, game.settings_save_app(path, settings))
	loaded, ok := game.settings_load_app(path)
	testing.expect(t, ok)
	defer delete(loaded.menu_position)
	defer delete(loaded.texture_filtering)
	defer delete(loaded.preset_directory)
	testing.expect_value(t, loaded.ui_scale, settings.ui_scale)
	testing.expect_value(t, loaded.default_fps_limit, settings.default_fps_limit)
	testing.expect_value(t, loaded.default_fps_limit_enabled, settings.default_fps_limit_enabled)
	testing.expect_value(t, loaded.window_maximized, settings.window_maximized)
	testing.expect_value(t, loaded.auto_hide_ui, settings.auto_hide_ui)
	testing.expect_value(t, loaded.auto_hide_delay, settings.auto_hide_delay)
	testing.expect_value(t, loaded.menu_position, settings.menu_position)
	testing.expect_value(t, loaded.experimental_controller_ui, settings.experimental_controller_ui)
	testing.expect_value(t, loaded.default_camera_sensitivity, settings.default_camera_sensitivity)
	testing.expect_value(t, loaded.texture_filtering, settings.texture_filtering)
}

@(test)
test_slime_control_descriptors_validate_couch_ui :: proc(t: ^testing.T) {
	testing.expect(t, game.slime_control_couch_validation_passes())
	testing.expect(t, game.slime_control_visible_descriptor_count(.Couch) > 0)

	required := [?]game.Control_Instrument{.Play, .Look, .Brush, .Motion, .Awareness, .Field, .Birth, .World}
	for instrument in required {
		testing.expect(t, game.slime_control_instrument_has_visible_controls(instrument, .Couch))
	}
}

@(test)
test_slime_descriptor_hides_known_ineffective_controls_from_couch :: proc(t: ^testing.T) {
	ids := [?]game.Control_Id{
		.Field_Decay_Frequency,
		.Field_Diffusion_Frequency,
		.Mask_Reversed,
		.Initialization_Heading_Range,
	}
	for id in ids {
		desc, ok := game.slime_control_descriptor_by_id(id)
		testing.expect(t, ok)
		testing.expect(t, game.control_is_broken_or_deprecated(desc))
		testing.expect(t, !game.control_is_visible_in_couch_ui(desc))
	}
}

@(test)
test_slime_visible_descriptor_validation_rejects_missing_metadata :: proc(t: ^testing.T) {
	desc, ok := game.slime_control_descriptor_by_id(.Brush_Radius)
	testing.expect(t, ok)
	testing.expect(t, game.control_descriptor_is_valid_for_visible_ui(desc))

	bad := desc
	bad.label = ""
	testing.expect(t, !game.control_descriptor_is_valid_for_visible_ui(bad))

	bad = desc
	bad.semantic_group = game.Semantic_Group(999)
	testing.expect(t, !game.control_descriptor_is_valid_for_visible_ui(bad))

	bad = desc
	bad.range.max = bad.range.min
	testing.expect(t, !game.control_descriptor_is_valid_for_visible_ui(bad))

	bad = desc
	bad.wiring_status = .ExposedIneffective
	testing.expect(t, !game.control_descriptor_is_valid_for_visible_ui(bad))
}

@(test)
test_slime_controller_deck_draw_does_not_steal_panel_focus :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = true
	ui.slime_controller.focused_index = 2
	ui.slime_controller.active_index = 2
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720})
	panel_focus := uifw.gui_make_id(&ctx, "panel_control")
	ctx.focused = panel_focus
	worker: game.Render_Worker_State
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)

	testing.expect_value(t, ctx.focused, panel_focus)
}

@(test)
test_slime_controller_deck_accept_ignores_non_deck_panel_focus :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = true
	ui.slime_controller.focused_index = 1
	ui.slime_controller.active_index = 2

	uifw.gui_begin_frame(&ctx, {accept = true})
	ctx.focused = uifw.gui_make_id(&ctx, "panel_control")
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)

	testing.expect_value(t, ui.slime_controller.active_index, 2)
}

@(test)
test_slime_controller_long_world_panel_scrolls :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Slime_Mold
	ui.slime_mold.slime.mask_pattern = .Image
	ui.slime_mold.slime.mask_pattern_index = int(game.Slime_Mask_Pattern.Image)
	ui.slime_controller.panel_open = true
	ui.slime_controller.deck_visible = true
	ui.slime_controller.focused_index = 6
	ui.slime_controller.active_index = 6
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 800, 360, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 800, window_height = 360, mouse_pos = {40, 110}, wheel_delta = -5})
	worker: game.Render_Worker_State
	game.slime_controller_ui_draw_panel(&ui, &ctx, &ui.slime_mold, {0, 0, 620, 180}, &worker)

	testing.expect(t, ui.slime_controller.panel_scroll > 0)
}

@(test)
test_slime_controller_ui_replaces_old_slime_panel_when_enabled :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.experimental_controller_ui = true
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.simulation_shell.show_ui = true
	ui.slime_controller.deck_visible = true
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1200, height = 800}
	worker: game.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1200, 800, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1200, window_height = 800})
	game.app_ui_draw_remaining_sim(&ui, &ctx, .Slime_Mold, &ui.slime_mold, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, test_first_text_command_index(ctx.commands[:], "About this simulation") < 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Play") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Look") >= 0)
}

@(test)
test_slime_controller_ui_disables_hidden_old_panel_hit_test :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.experimental_controller_ui = true
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.simulation_shell.show_ui = true
	ui.simulation_shell.controls_visible = true
	ui.slime_controller.deck_visible = false
	ui.slime_controller.panel_open = false
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1600, 900, ui.settings.ui_scale)

	old_panel := game.app_ui_simulation_menu_panel(&ui, &ctx, 1600, 900)
	input := game.Ui_Frame_Input {
		window_width = 1600,
		window_height = 900,
		mouse_pos = {old_panel.x + old_panel.w * 0.5, old_panel.y + old_panel.h * 0.5},
		mouse_pressed = true,
		mouse_down = true,
	}
	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, input)

	testing.expect(t, filtered.mouse_pressed)
	testing.expect(t, filtered.mouse_down)
	testing.expect(t, ui.simulation_shell.mouse_pressed)
}

@(test)
test_slime_controller_deck_tabs_bound_key_and_label_text :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.experimental_controller_ui = true
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = false
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 2048, 1152, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 2048, window_height = 1152})
	worker: game.Render_Worker_State
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 2048, 1152, &worker)
	uifw.gui_end_frame(&ctx)

	labels := [?]string{"Play", "Look", "Brush", "Motion", "Awareness", "Field", "World", "Birth", "Capture"}
	found := 0
	active_clip: uifw.Rect
	clip_active := false
	for command in ctx.commands {
		#partial switch command.kind {
		case .Scissor_Begin:
			active_clip = command.rect
			clip_active = true
		case .Scissor_End:
			clip_active = false
		case .Text:
			for label in labels {
				if command.text == label {
					testing.expect(t, clip_active)
					testing.expect(t, command.rect.x >= active_clip.x)
					testing.expect(t, command.rect.y >= active_clip.y)
					testing.expect(t, command.rect.x + command.rect.w <= active_clip.x + active_clip.w + 0.5)
					testing.expect(t, command.rect.y + command.rect.h <= active_clip.y + active_clip.h + 0.5)
					found += 1
				}
			}
		case:
		}
	}
	testing.expect_value(t, found, len(labels))
}

@(test)
test_slime_controller_deck_tab_focus_moves_between_tabs :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.experimental_controller_ui = true
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = false
	ui.slime_controller.focused_index = 0
	ui.slime_controller.active_index = 0
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, key_tab = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	worker: game.Render_Worker_State
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ui.slime_controller.deck_visible)
	testing.expect(t, !ui.slime_controller.panel_open)
	testing.expect_value(t, ui.slime_controller.focused_index, 1)
	testing.expect_value(t, ui.slime_controller.active_index, 0)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_1"))

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, key_tab = true, key_shift = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ui.slime_controller.focused_index, 0)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_0"))
}

@(test)
test_slime_controller_deck_arrow_focus_moves_once :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.experimental_controller_ui = true
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = false
	ui.slime_controller.focused_index = 0
	ui.slime_controller.active_index = 0
	ctx.focused = uifw.gui_make_id(&ctx, "slime_deck_0")
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, key_right = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	worker: game.Render_Worker_State
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ui.slime_controller.focused_index, 1)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_1"))

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, key_left = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ui.slime_controller.focused_index, 0)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_0"))
}

@(test)
test_slime_controller_deck_tab_opens_hidden_deck_without_skipping_tab :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.experimental_controller_ui = true
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = false
	ui.slime_controller.panel_open = false
	ui.slime_controller.active_index = 2
	ui.slime_controller.focused_index = 2
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, key_tab = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	worker: game.Render_Worker_State
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ui.slime_controller.deck_visible)
	testing.expect(t, !ui.slime_controller.panel_open)
	testing.expect_value(t, ui.slime_controller.focused_index, 2)
	testing.expect_value(t, ui.slime_controller.active_index, 2)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_2"))
}

@(test)
test_slime_controller_deck_click_selects_tab_with_panel_focus :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.experimental_controller_ui = true
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = true
	ui.slime_controller.active_index = 0
	ui.slime_controller.focused_index = 0
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, ui.settings.ui_scale)

	deck := game.slime_controller_ui_deck_rect(&ctx, 1280, 720, ui.slime_controller.mode)
	count := game.slime_controller_ui_visible_instrument_count(ui.slime_controller.mode)
	gap := ctx.style.spacing
	tab_w := max((deck.w - gap * f32(count + 1)) / f32(count), f32(1))
	tab_h := max(deck.h - gap * 2, f32(1))
	target_index := 1
	tab := uifw.Rect{deck.x + gap + f32(target_index) * (tab_w + gap), deck.y + gap, tab_w, tab_h}
	click := uifw.Vec2{tab.x + tab.w * 0.5, tab.y + tab.h * 0.5}
	panel_focus := uifw.gui_make_id(&ctx, "panel_control")
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, mouse_pos = click, mouse_down = true, mouse_pressed = true})
	ctx.focused = panel_focus
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, mouse_pos = click, mouse_released = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ui.slime_controller.panel_open)
	testing.expect_value(t, ui.slime_controller.focused_index, target_index)
	testing.expect_value(t, ui.slime_controller.active_index, target_index)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_1"))
}

@(test)
test_slime_controller_space_focuses_bottom_bar :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.experimental_controller_ui = true
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = false
	ui.slime_controller.panel_open = false
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1024, 768, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1024, window_height = 768, key_space = true})
	consumed := game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1024, 768)

	testing.expect(t, consumed)
	testing.expect(t, ui.slime_controller.deck_visible)
	testing.expect_value(t, ui.slime_controller.focused_index, ui.slime_controller.active_index)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_0"))
}

@(test)
test_slime_controller_select_focuses_bottom_bar_without_toggling_shell :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.experimental_controller_ui = true
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.simulation_shell.show_ui = true
	ui.slime_controller.deck_visible = false
	ui.slime_controller.panel_open = false
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1024, 768, ui.settings.ui_scale)

	game_input := game.Ui_Frame_Input{window_width = 1024, window_height = 768, active_device = .Controller, toggle_ui = true}
	game.app_ui_simulation_shell_update(&ui, game_input)

	uifw.gui_begin_frame(&ctx, {window_width = 1024, window_height = 768, active_device = .Controller, toggle_ui = true})
	consumed := game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1024, 768)

	testing.expect(t, consumed)
	testing.expect(t, ui.simulation_shell.show_ui)
	testing.expect(t, ui.slime_controller.deck_visible)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_0"))
}

@(test)
test_slime_controller_pause_focuses_header_bar :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.experimental_controller_ui = true
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_mold.paused = false
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1024, height = 768}
	worker: game.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1024, 768, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1024, window_height = 768, active_device = .Controller, pause = true})
	game.app_ui_draw_remaining_sim(&ui, &ctx, .Slime_Mold, &ui.slime_mold, &vk_ctx, &worker)

	uifw.gui_push_id(&ctx, "simulation_bar")
	pause_id := uifw.gui_make_id(&ctx, "pause")
	uifw.gui_pop_id(&ctx)

	testing.expect_value(t, ctx.focused, pause_id)
	testing.expect(t, !ui.slime_mold.paused)
}

@(test)
test_app_options_screen_uses_plain_toggle_labels_and_sticky_footer :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1200, height = 800}
	worker: game.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1200, 800, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1200, window_height = 800, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_options(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Options") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "FPS Limiter") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "FPS Limiter: false") < 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Start Maximized") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Start Maximized: true") < 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Auto-hide UI") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Auto-hide UI: true") < 0)

	scroll_clip: uifw.Rect
	found_scroll_clip := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Scissor_Begin {
			scroll_clip = command.rect
			found_scroll_clip = true
			break
		}
	}
	save_index := test_first_text_command_index(ctx.commands[:], "Save")
	testing.expect(t, found_scroll_clip)
	testing.expect(t, save_index >= 0)
	testing.expect(t, ctx.commands[save_index].rect.y > scroll_clip.y + scroll_clip.h)
}

@(test)
test_app_options_controller_ui_toggle_is_configurable :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.settings.experimental_controller_ui = true
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1600, height = 1200}
	worker: game.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1600, 1200, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1600, window_height = 1200, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_options(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	label_index := test_first_text_command_index(ctx.commands[:], "Controller UI")
	testing.expect(t, label_index >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Controller UI: true") < 0)
}

@(test)
test_app_options_screen_mutes_disabled_dependent_fields :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	settings := game.settings_default()
	settings.default_fps_limit_enabled = false
	settings.auto_hide_ui = false
	ui: game.App_Ui_State
	game.app_ui_init(&ui, settings)
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1200, height = 800}
	worker: game.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1200, 800, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1200, window_height = 800, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_options(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	saw_muted_fps_limit := false
	saw_muted_auto_hide_delay := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "FPS Limit: 60" && command.color.a == ctx.style.text_muted.a {
			saw_muted_fps_limit = true
		}
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "Auto-hide Delay: 3000 ms" && command.color.a == ctx.style.text_muted.a {
			saw_muted_auto_hide_delay = true
		}
	}
	testing.expect(t, saw_muted_fps_limit)
	testing.expect(t, saw_muted_auto_hide_delay)
}

@(test)
test_app_options_reset_defaults_stays_unsaved_and_publishes_change :: proc(t: ^testing.T) {
	render_to_ui := new(game.Render_To_Ui_Queue)
	defer free(render_to_ui)
	worker: game.Render_Worker_State
	worker.render_to_ui = render_to_ui
	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.ui_scale = 1.8
	settings.default_fps_limit_enabled = true
	settings.menu_position = "right"
	settings.texture_filtering = "Nearest"
	game.app_ui_init(&ui, settings)
	ui.settings_dirty = false

	game.app_ui_reset_settings_to_defaults(&ui, &worker)

	testing.expect(t, ui.settings_dirty)
	testing.expect_value(t, ui.settings.ui_scale, f32(1.0))
	testing.expect_value(t, ui.settings.default_fps_limit_enabled, false)
	testing.expect_value(t, ui.menu_position_index, game.option_index(ui.settings.menu_position, game.MENU_POSITION_OPTIONS[:], 1))
	testing.expect_value(t, ui.texture_filtering_index, game.option_index(ui.settings.texture_filtering, game.TEXTURE_FILTERING_OPTIONS[:], 0))

	msg: game.Render_To_Ui_Message
	testing.expect(t, engine.queue_try_pop(render_to_ui, &msg))
	testing.expect_value(t, msg.kind, game.Render_To_Ui_Message_Kind.App_Settings_Changed)
	testing.expect(t, !engine.queue_try_pop(render_to_ui, &msg))
}

@(test)
test_app_settings_defaults_are_tv_readable :: proc(t: ^testing.T) {
	settings := game.settings_default()

	testing.expect_value(t, settings.ui_scale, f32(1.0))
	testing.expect_value(t, settings.window_width, i32(1920))
	testing.expect_value(t, settings.window_height, i32(1080))
	testing.expect(t, settings.window_maximized)
}

@(test)
test_gui_style_for_viewport_computes_h_fraction_typography :: proc(t: ^testing.T) {
	style := uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1)

	testing.expect_value(t, style.display_text_height, f32(90))
	testing.expect_value(t, style.heading_text_height, f32(45))
	testing.expect_value(t, style.body_text_height, f32(30))
	testing.expect_value(t, style.small_text_height, f32(23))
	testing.expect_value(t, style.display_text_scale, f32(5.625))
}

@(test)
test_ui_font_atlas_cell_covers_wide_glyph_advances :: proc(t: ^testing.T) {
	display_scale := uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1).display_text_scale
	atlas_cell_w := f32(engine.UI_FONT_ATLAS_LOGICAL_WIDTH) * display_scale
	widest_advance := f32(0)
	for advance in uifw.GUI_FONT_ADVANCES {
		widest_advance = max(widest_advance, advance * display_scale)
	}

	testing.expect(t, atlas_cell_w >= widest_advance + display_scale)
}

@(test)
test_ui_shaped_glyph_ids_resolve_to_ascii_atlas_slots :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	shaped: [16]uifw.Gui_Shaped_Glyph
	label := "Slime Mold"
	bytes := transmute([]u8)label
	count := uifw.gui_font_shape_text(.Body, bytes, 1, shaped[:])

	testing.expect(t, count > 0)
	testing.expect_value(t, uifw.gui_font_glyph_slot(shaped[0].glyph_id), i32('S' - uifw.GUI_FONT_GLYPH_FIRST))
}

@(test)
test_gui_style_for_viewport_applies_ui_scale_multiplier :: proc(t: ^testing.T) {
	normal := uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1)
	scaled := uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1.5)

	testing.expect_value(t, scaled.display_text_height, f32(135))
	testing.expect_value(t, scaled.body_text_height, f32(45))
	testing.expect(t, scaled.rhythm > normal.rhythm)
	testing.expect(t, scaled.row_height > normal.row_height)
}

@(test)
test_gui_style_for_viewport_derives_rhythm_spacing_and_box_metrics :: proc(t: ^testing.T) {
	style := uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1)

	testing.expect_value(t, style.rhythm, f32(38))
	testing.expect_value(t, style.body_line_height, style.rhythm)
	testing.expect_value(t, style.spacing_1, f32(10))
	testing.expect_value(t, style.spacing_2, f32(19))
	testing.expect_value(t, style.spacing_3, style.rhythm)
	testing.expect_value(t, style.spacing_4, f32(57))
	testing.expect_value(t, style.panel_padding, style.spacing_2)
	testing.expect_value(t, style.margin, style.spacing_2)
	testing.expect_value(t, style.section_gap, style.spacing_3)
	testing.expect_value(t, style.border_width, f32(1))
}

@(test)
test_app_ui_simulation_bar_scales_with_viewport_style :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1)
	height := game.app_ui_simulation_bar_height(&ctx)

	testing.expect(t, height > game.SIMULATION_BAR_HEIGHT)
	testing.expect_value(t, height, ctx.style.row_height + ctx.style.spacing_2 * 2)
}

@(test)
test_app_ui_auto_hide_waits_until_ui_is_hidden :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.auto_hide_ui = true
	settings.auto_hide_delay = 1000
	game.app_ui_init(&ui, settings)
	ui.mode = .Gray_Scott

	game.app_ui_simulation_shell_update(&ui, {delta_time = 1.25})
	testing.expect(t, ui.simulation_shell.show_ui)
	testing.expect(t, ui.simulation_shell.controls_visible)

	game.app_ui_simulation_shell_update(&ui, {key_slash = true})
	testing.expect(t, !ui.simulation_shell.show_ui)
	testing.expect(t, ui.simulation_shell.controls_visible)

	game.app_ui_simulation_shell_update(&ui, {delta_time = 1.25})
	testing.expect(t, !ui.simulation_shell.controls_visible)
}

@(test)
test_app_ui_auto_hide_mouse_motion_reveals_hidden_controls :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.auto_hide_ui = true
	settings.auto_hide_delay = 1000
	game.app_ui_init(&ui, settings)
	ui.mode = .Gray_Scott
	ui.simulation_shell.show_ui = false
	ui.simulation_shell.controls_visible = false
	ui.simulation_shell.idle_seconds = 2

	game.app_ui_simulation_shell_update(&ui, {mouse_moved = true})
	testing.expect(t, ui.simulation_shell.controls_visible)
	testing.expect_value(t, ui.simulation_shell.idle_seconds, f32(0))
}

@(test)
test_app_ui_system_cursor_hides_with_hidden_simulation_controls :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.auto_hide_ui = true
	settings.auto_hide_delay = 1000
	game.app_ui_init(&ui, settings)
	ui.mode = .Gray_Scott

	testing.expect(t, !game.app_ui_system_cursor_hidden(&ui))

	game.app_ui_simulation_shell_update(&ui, {key_slash = true})
	testing.expect(t, !ui.simulation_shell.show_ui)
	testing.expect(t, ui.simulation_shell.controls_visible)
	testing.expect(t, !game.app_ui_system_cursor_hidden(&ui))

	game.app_ui_simulation_shell_update(&ui, {delta_time = 1.25})
	testing.expect(t, !ui.simulation_shell.controls_visible)
	testing.expect(t, game.app_ui_system_cursor_hidden(&ui))

	game.app_ui_simulation_shell_update(&ui, {mouse_moved = true})
	testing.expect(t, ui.simulation_shell.controls_visible)
	testing.expect(t, !game.app_ui_system_cursor_hidden(&ui))

	ui.mode = .Main_Menu
	ui.simulation_shell.show_ui = false
	ui.simulation_shell.controls_visible = false
	testing.expect(t, !game.app_ui_system_cursor_hidden(&ui))
}

@(test)
test_app_mouse_input_restores_hidden_system_cursor_immediately :: proc(t: ^testing.T) {
	testing.expect(t, game.app_input_reveals_hidden_system_cursor({
		mouse_pressed = true,
	}, .Mouse_Keyboard))
	testing.expect(t, game.app_input_reveals_hidden_system_cursor({
		mouse_moved = true,
	}, .Mouse_Keyboard))
	testing.expect(t, game.app_input_reveals_hidden_system_cursor({
		wheel_delta = 1,
	}, .Mouse_Keyboard))
	testing.expect(t, !game.app_input_reveals_hidden_system_cursor({
		mouse_pressed = true,
	}, .Controller))
	testing.expect(t, !game.app_input_reveals_hidden_system_cursor({}, .Mouse_Keyboard))
}

@(test)
test_app_mouse_button_events_update_position_for_same_frame_clicks :: proc(t: ^testing.T) {
	app := new(game.App_State)
	defer free(app)
	app.input.mouse_pos = {12, 18}

	game.app_apply_mouse_button_event(app, 1, 320, 240, true)
	game.app_apply_mouse_button_event(app, 1, 320, 240, false)

	testing.expect_value(t, app.input.mouse_pos.x, f32(320))
	testing.expect_value(t, app.input.mouse_pos.y, f32(240))
	testing.expect_value(t, app.input.mouse_delta.x, f32(0))
	testing.expect_value(t, app.input.mouse_delta.y, f32(0))
	testing.expect(t, app.input.mouse_pressed)
	testing.expect(t, app.input.mouse_released)
	testing.expect(t, !app.input.mouse_down)
	testing.expect_value(t, app.held_mouse_button, u32(0))

	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	uifw.gui_begin_frame(&ctx, {
		mouse_pos = app.input.mouse_pos,
		mouse_pressed = app.input.mouse_pressed,
		mouse_released = app.input.mouse_released,
	})
	clicked := uifw.gui_button_at(&ctx, uifw.gui_make_id(&ctx, "click_target"), {280, 220, 100, 50}, "Click", true)
	testing.expect(t, clicked)
}

@(test)
test_app_ui_simulation_filter_blocks_right_menu_clicks :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	settings := game.settings_default()
	settings.menu_position = "right"
	ui: game.App_Ui_State
	game.app_ui_init(&ui, settings)
	ui.mode = .Particle_Life

	menu := game.app_ui_simulation_menu_panel(&ui, &ctx, 1920, 1080)
	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1920,
		window_height = 1080,
		mouse_pos = {menu.x + menu.w * 0.5, menu.y + 40},
		mouse_down = true,
		mouse_pressed = true,
		mouse_button = 1,
	})

	testing.expect(t, !filtered.mouse_down)
	testing.expect(t, !filtered.mouse_pressed)
	testing.expect(t, !ui.simulation_shell.mouse_pressed)
}

@(test)
test_app_ui_simulation_filter_preserves_camera_arrows_without_ui_focus :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Gray_Scott

	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1920,
		window_height = 1080,
		key_right = true,
		nav_x = 1,
		nav_pressed_x = 1,
	})

	testing.expect(t, filtered.key_right)
	testing.expect_value(t, filtered.nav_x, f32(1))
	testing.expect_value(t, filtered.nav_pressed_x, f32(1))

	ctx.focused = uifw.gui_make_id(&ctx, "focused_control")
	filtered = game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1920,
		window_height = 1080,
		key_right = true,
		nav_x = 1,
		nav_pressed_x = 1,
	})

	testing.expect(t, !filtered.key_right)
	testing.expect_value(t, filtered.nav_x, f32(0))
	testing.expect_value(t, filtered.nav_pressed_x, f32(0))
}

@(test)
test_app_ui_simulation_filter_cancels_drag_on_top_bar :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	settings := game.settings_default()
	settings.menu_position = "right"
	ui: game.App_Ui_State
	game.app_ui_init(&ui, settings)
	ui.mode = .Particle_Life

	first := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1920,
		window_height = 1080,
		mouse_pos = {100, 100},
		mouse_down = true,
		mouse_pressed = true,
		mouse_button = 1,
	})
	testing.expect(t, first.mouse_down)
	testing.expect(t, ui.simulation_shell.mouse_pressed)

	second := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1920,
		window_height = 1080,
		mouse_pos = {100, 10},
		mouse_down = true,
		mouse_button = 1,
	})

	testing.expect(t, !second.mouse_down)
	testing.expect(t, second.mouse_released)
	testing.expect(t, !ui.simulation_shell.mouse_pressed)
}

@(test)
test_gui_style_scaled_expands_readability_metrics :: proc(t: ^testing.T) {
	base := uifw.gui_default_style()
	scaled := uifw.gui_style_scaled(base, 1.5)

	testing.expect_value(t, scaled.row_height, base.row_height * 1.5)
	testing.expect_value(t, scaled.text_height, base.text_height * 1.5)
	testing.expect_value(t, scaled.text_scale, base.text_scale * 1.5)
	testing.expect_value(t, scaled.panel_padding, base.panel_padding * 1.5)
}

@(test)
test_gui_collapsible_toggles_with_keyboard_space :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	open := false
	id := uifw.gui_make_id(&ctx, "section")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {key_space = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 80}, .Column, 0, 44)
	testing.expect(t, uifw.gui_collapsible_begin(&ctx, "Section", "section", &open))
	uifw.gui_layout_end(&ctx)
	testing.expect(t, open)
}

@(test)
test_gui_collapsible_draws_line_chevron_not_text_arrow :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	open := false
	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 80}, .Column, 0, 44)
	_ = uifw.gui_collapsible_begin(&ctx, "Section", "section", &open)
	uifw.gui_layout_end(&ctx)

	line_count := 0
	text_arrow_count := 0
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Line {
			line_count += 1
		}
		if command.kind == uifw.Draw_Command_Kind.Text && (command.text == ">" || command.text == "v") {
			text_arrow_count += 1
		}
	}
	testing.expect(t, line_count >= 2)
	testing.expect_value(t, text_arrow_count, 0)
}

@(test)
test_app_ui_main_menu_simulation_indices_route_to_modes :: proc(t: ^testing.T) {
	testing.expect_value(t, game.app_ui_mode_for_simulation_index(0), game.App_Mode.Slime_Mold)
	testing.expect_value(t, game.app_ui_mode_for_simulation_index(1), game.App_Mode.Gray_Scott)
	testing.expect_value(t, game.app_ui_mode_for_simulation_index(2), game.App_Mode.Particle_Life)
	testing.expect_value(t, game.app_ui_mode_for_simulation_index(3), game.App_Mode.Flow_Field)
	testing.expect_value(t, game.app_ui_mode_for_simulation_index(9), game.App_Mode.Primordial)
	testing.expect_value(t, game.app_ui_mode_for_simulation_index(10), game.App_Mode.Main_Menu)
}

@(test)
test_app_ui_main_menu_arrows_move_once_per_press :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_selected = 0

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1200, height = 800}
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}, key_down = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 1)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}, key_down = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 1)

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}, key_down = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 2)
}

@(test)
test_app_ui_main_menu_keyboard_scrolls_all_sims_into_view :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_selected = 0
	ui.main_menu_focus_slot = game.app_ui_main_menu_slot_for_simulation_index(0)

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), f32(vk_ctx.swapchain_extent.width), f32(vk_ctx.swapchain_extent.height), 1)

	for _ in 0 ..< 9 {
		uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, key_down = true})
		game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
		uifw.gui_end_frame(&ctx)

		uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}})
		game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
		uifw.gui_end_frame(&ctx)
	}

	testing.expect_value(t, ui.main_menu_selected, 9)
	testing.expect(t, ui.main_menu_scroll > 0)

	width := f32(vk_ctx.swapchain_extent.width)
	height := f32(vk_ctx.swapchain_extent.height)
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), width, height, 1)
	theme := game.app_ui_menu_theme(&ctx, width, height)
	margin_x := max(width * 0.055, ctx.style.spacing_4)
	title_y := max(height * 0.070, ctx.style.spacing_4)
	title_scale := max((height * 0.31) / f32(16), ctx.style.display_text_scale * 1.2)
	title_text_h := uifw.GUI_FONT_LOGICAL_HEIGHT * title_scale
	title_h := min(max(max(height * 0.20, ctx.style.display_line_height), title_text_h), height - title_y)
	side_w := min(max(width * 0.23, f32(330)), f32(560))
	right_margin := max(width * 0.050, ctx.style.spacing_4)
	options_size := game.app_ui_main_menu_text_button_size(&ctx, "OPTIONS", theme)
	quit_size := game.app_ui_main_menu_text_button_size(&ctx, "QUIT", theme)
	button_w := max(side_w, max(options_size.x, quit_size.x))
	actions_x := max(width - right_margin - button_w, margin_x)
	list_w := min(max(width * 0.60, f32(680)), max(actions_x - theme.detail_gap - margin_x, 1))
	list_y := max(title_y + title_h + theme.inner_gap, height * 0.39)
	list_bottom := height - max(height * 0.050, ctx.style.spacing_4)
	list_h := max(list_bottom - list_y, theme.row_height * 2.25)
	viewport := uifw.Rect{margin_x, list_y, list_w, list_h}
	selected_top := f32(ui.main_menu_selected) * (theme.row_height + ctx.style.spacing)
	selected_bottom := selected_top + theme.row_height

	testing.expect(t, selected_bottom <= ui.main_menu_scroll + viewport.h + theme.item_gap)
	testing.expect(t, selected_top >= ui.main_menu_scroll - theme.item_gap)
}

@(test)
test_app_ui_main_menu_keyboard_reaches_title_options_and_quit :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_selected = 0
	ui.main_menu_focus_slot = game.app_ui_main_menu_slot_for_simulation_index(0)

	render_to_ui := new(game.Render_To_Ui_Queue)
	defer free(render_to_ui)
	worker: game.Render_Worker_State
	worker.render_to_ui = render_to_ui
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, key_up = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_focus_slot, game.MAIN_MENU_TITLE_SLOT)

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, key_enter = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect(t, ui.main_menu_palette_randomize_requested)

	ui.main_menu_palette_randomize_requested = false
	ui.main_menu_selected = 9
	ui.main_menu_focus_slot = game.app_ui_main_menu_slot_for_simulation_index(9)
	ui.main_menu_focus_navigation_active = true
	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, nav_pressed_y = 1, active_device = .Controller})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_focus_slot, game.app_ui_main_menu_options_slot())

	ctx.focused = uifw.gui_make_id(&ctx, "options")
	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, accept = true, active_device = .Controller})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.mode, game.App_Mode.Options)

	game.app_ui_navigate(&ui, .Main_Menu)
	ui.main_menu_focus_slot = game.app_ui_main_menu_options_slot()
	ui.main_menu_focus_navigation_active = true
	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, nav_pressed_y = 1, active_device = .Controller})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_focus_slot, game.app_ui_main_menu_quit_slot())

	ctx.focused = uifw.gui_make_id(&ctx, "quit")
	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, accept = true, active_device = .Controller})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	msg: game.Render_To_Ui_Message
	testing.expect(t, engine.queue_try_pop(render_to_ui, &msg))
	testing.expect_value(t, msg.kind, game.Render_To_Ui_Message_Kind.Request_Close)
}

@(test)
test_app_ui_main_menu_keyboard_selection_ignores_stationary_hover :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_selected = 0

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State
	mouse := uifw.Vec2{200, 760}

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = mouse})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 1)

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = mouse, key_down = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 2)

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = mouse})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 2)

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = mouse, mouse_moved = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 1)
}

@(test)
test_app_ui_main_menu_hover_selection_draws_same_frame :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_selected = 0

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State
	mouse := uifw.Vec2{200, 980}

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = mouse})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ui.main_menu_selected, 2)
	found_selected_hover_row := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Stroked_Rounded_Rect &&
		   command.color.r > 0.9 &&
		   command.color.g > 0.9 &&
		   command.color.b > 0.9 &&
		   command.color.a >= 0.39 &&
		   command.stroke_width >= 2 &&
		   uifw.gui_contains(command.rect, mouse) {
			found_selected_hover_row = true
		}
	}
	testing.expect(t, found_selected_hover_row)
}

@(test)
test_app_ui_main_menu_hover_selection_respects_scroll_clip :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_selected = 0

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {200, 1070}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ui.main_menu_selected, 0)
}

@(test)
test_app_ui_main_menu_removes_how_to_play_and_stacks_options_quit :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	found_how_to_play := false
	title_scale := f32(0)
	title_h := f32(0)
	options_x := f32(-1)
	options_y := f32(-1)
	options_w := f32(-1)
	options_h := f32(-1)
	options_scale := f32(0)
	options_label := ""
	options_font := uifw.Gui_Font_Kind.Body
	options_align := uifw.Text_Align.Center
	byline_y := f32(-1)
	byline_scale := f32(0)
	byline_font := uifw.Gui_Font_Kind.Body
	quit_x := f32(-1)
	quit_y := f32(-1)
	quit_w := f32(-1)
	quit_h := f32(-1)
	quit_align := uifw.Text_Align.Center
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text {
			if command.text == "VIZZA" {
				title_scale = command.text_scale
				title_h = command.rect.h
			}
			if command.text == "By Zelda" {
				byline_y = command.rect.y
				byline_scale = command.text_scale
				byline_font = command.font_kind
			}
			if command.text == "How To Play" {
				found_how_to_play = true
			}
			if command.text == "OPTIONS" {
				options_x = command.rect.x
				options_y = command.rect.y
				options_w = command.rect.w
				options_h = command.rect.h
				options_scale = command.text_scale
				options_label = command.text
				options_font = command.font_kind
				options_align = command.text_align
			}
			if command.text == "QUIT" {
				quit_x = command.rect.x
				quit_y = command.rect.y
				quit_w = command.rect.w
				quit_h = command.rect.h
				quit_align = command.text_align
			}
		}
	}
	testing.expect(t, !found_how_to_play)
	testing.expect(t, title_scale >= f32(vk_ctx.swapchain_extent.height) * 0.24 / 16)
	testing.expect(t, title_h >= uifw.GUI_FONT_LOGICAL_HEIGHT * title_scale)
	testing.expect_value(t, byline_font, uifw.Gui_Font_Kind.Display)
	title_baseline_y := max(f32(vk_ctx.swapchain_extent.height) * 0.070, ctx.style.spacing_4) + uifw.GUI_FONT_LOGICAL_HEIGHT * title_scale * game.MAIN_MENU_DISPLAY_FONT_BASELINE_RATIO
	byline_baseline_y := byline_y + uifw.GUI_FONT_LOGICAL_HEIGHT * byline_scale * game.MAIN_MENU_DISPLAY_FONT_BASELINE_RATIO
	testing.expect(t, math.abs(byline_baseline_y - title_baseline_y) <= 0.01)
	testing.expect(t, options_x + options_w * 0.5 > f32(vk_ctx.swapchain_extent.width) * 0.68)
	testing.expect_value(t, options_font, uifw.Gui_Font_Kind.SimStart)
	testing.expect_value(t, options_align, uifw.Text_Align.Left)
	testing.expect_value(t, quit_align, uifw.Text_Align.Left)
	expected_scale := ctx.style.heading_text_scale * game.MAIN_MENU_TEXT_BUTTON_SCALE_MULTIPLIER
	testing.expect(t, options_scale >= expected_scale * 0.99)
	options_text_w := uifw.gui_font_text_width(.SimStart, transmute([]u8)options_label, options_scale, ctx.style.char_width * options_scale / ctx.style.text_scale)
	testing.expect(t, options_w >= options_text_w * 0.99)
	testing.expect(t, math.abs(options_x - quit_x) <= 0.01)
	testing.expect(t, math.abs(options_w - quit_w) <= 0.01)
	testing.expect(t, math.abs(options_h - quit_h) <= 0.01)
	testing.expect(t, options_y >= 0)
	testing.expect(t, quit_y > options_y)
	theme := game.app_ui_menu_theme(&ctx, f32(vk_ctx.swapchain_extent.width), f32(vk_ctx.swapchain_extent.height))
	bottom_margin := max(f32(vk_ctx.swapchain_extent.height) * 0.050, ctx.style.spacing_4)
	right_margin := max(f32(vk_ctx.swapchain_extent.width) * 0.050, ctx.style.spacing_4)
	text_h := uifw.GUI_FONT_LOGICAL_HEIGHT * options_scale
	padding_x := max(theme.small_gap * 2.0, text_h * 0.20)
	padding_y := max(theme.small_gap * 1.4, text_h * 0.14)
	testing.expect(t, math.abs(options_x + options_w + padding_x - (f32(vk_ctx.swapchain_extent.width) - right_margin)) <= 1.0)
	testing.expect(t, math.abs(quit_x + quit_w + padding_x - (f32(vk_ctx.swapchain_extent.width) - right_margin)) <= 1.0)
	testing.expect(t, math.abs(quit_y + quit_h + padding_y - (f32(vk_ctx.swapchain_extent.height) - bottom_margin)) <= 1.0)
	preview_right := f32(0)
	for i in 0 ..< ui.main_menu_preview_slot_count {
		preview_right = max(preview_right, ui.main_menu_preview_slots[i].rect.x + ui.main_menu_preview_slots[i].rect.w)
	}
	testing.expect(t, ui.main_menu_preview_slot_count > 0)
	testing.expect(t, preview_right + theme.detail_gap <= options_x - padding_x + 1.0)
}

@(test)
test_app_ui_main_menu_text_buttons_draw_5px_white_outline_when_focused :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-100, -100}})
	ctx.focused = uifw.gui_make_id(&ctx, "options")
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	found_focus_outline := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Stroked_Rounded_Rect &&
		   command.color.r > 0.9 &&
		   command.color.g > 0.9 &&
		   command.color.b > 0.9 &&
		   command.stroke_width == game.MAIN_MENU_TEXT_BUTTON_FOCUS_BORDER_WIDTH {
			found_focus_outline = true
		}
	}
	testing.expect(t, found_focus_outline)
}

@(test)
test_app_ui_main_menu_no_longer_emits_red_backdrop_gradients :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	found_old_fullscreen_backdrop := false
	found_old_upper_wash := false
	for command in ctx.commands {
		if command.kind != uifw.Draw_Command_Kind.Gradient_Rect {
			continue
		}
		if command.rect.x == 0 && command.rect.y == 0 &&
		   command.rect.w == f32(vk_ctx.swapchain_extent.width) &&
		   command.rect.h == f32(vk_ctx.swapchain_extent.height) &&
		   command.color.r == 1 && command.color.g == 0 && command.color.b == 0 {
			found_old_fullscreen_backdrop = true
		}
		if command.rect.x == 0 && command.rect.y == 0 &&
		   command.rect.w == f32(vk_ctx.swapchain_extent.width) &&
		   command.rect.h == f32(vk_ctx.swapchain_extent.height) * 0.42 &&
		   command.color.r == 1 && command.color.g == 0 && command.color.b == 0 {
			found_old_upper_wash = true
		}
	}
	testing.expect(t, !found_old_fullscreen_backdrop)
	testing.expect(t, !found_old_upper_wash)
}

@(test)
test_app_ui_main_menu_uses_refractive_glass_surfaces :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	glass_count := 0
	found_fixed_red_surface := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Refractive_Glass_Rect {
			glass_count += 1
			testing.expect(t, command.glass_style.ior > 1)
			testing.expect(t, command.glass_style.dispersion > 0)
		}
		if command.kind == uifw.Draw_Command_Kind.Filled_Rounded_Rect &&
		   command.color.r > 0.50 && command.color.g < 0.08 && command.color.b < 0.08 &&
		   command.rect.w > 200 && command.rect.h > 80 {
			found_fixed_red_surface = true
		}
	}
	testing.expect(t, glass_count > 0)
	testing.expect(t, !found_fixed_red_surface)
}

@(test)
test_app_ui_main_menu_preview_slots_skip_gradient_editor :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_scroll = 900

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	saw_gradient_label := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "Gradient Editor" {
			saw_gradient_label = true
			bytes := transmute([]u8)command.text
			fallback_advance := ctx.style.char_width * command.text_scale / max(ctx.style.text_scale, 0.001)
			text_w := uifw.gui_font_text_width(command.font_kind, bytes, command.text_scale, fallback_advance)
			testing.expect(t, text_w <= command.rect.w + 0.01)
		}
	}
	testing.expect(t, saw_gradient_label)
	for i in 0 ..< ui.main_menu_preview_slot_count {
		testing.expect(t, ui.main_menu_preview_slots[i].mode != game.App_Mode.Gradient_Editor)
	}
}

@(test)
test_app_ui_main_menu_preview_slots_keep_unclipped_rect_when_scrolled :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_scroll = 42

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	found_partially_clipped := false
	found_clipped_overlay := false
	for i in 0 ..< ui.main_menu_preview_slot_count {
		slot := ui.main_menu_preview_slots[i]
		if slot.clip_rect.h > 1 && slot.rect.h > slot.clip_rect.h + 1 {
			found_partially_clipped = true
			expected_left_w := slot.rect.w * game.MAIN_MENU_SIM_BUTTON_GRADIENT_MIDPOINT
			for command in ctx.commands {
				if test_is_black_horizontal_fade(command, 1, 0.5) &&
				   math.abs(command.rect.x - slot.clip_rect.x) <= 0.01 &&
				   math.abs(command.rect.y - slot.clip_rect.y) <= 0.01 &&
				   math.abs(command.rect.w - expected_left_w) <= 0.01 &&
				   math.abs(command.rect.h - slot.clip_rect.h) <= 0.01 {
					found_clipped_overlay = true
				}
			}
		}
	}
	testing.expect(t, found_partially_clipped)
	testing.expect(t, found_clipped_overlay)
}

@(test)
test_app_ui_main_menu_preview_slots_record_fallback_color :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	theme := game.app_ui_menu_theme(&ctx, 1920, 1080)
	testing.expect(t, ui.main_menu_preview_slot_count > 0)
	for i in 0 ..< ui.main_menu_preview_slot_count {
		slot := ui.main_menu_preview_slots[i]
		testing.expect(t, test_approx_f32(slot.fallback_color.r, theme.preview_surface.r))
		testing.expect(t, test_approx_f32(slot.fallback_color.g, theme.preview_surface.g))
		testing.expect(t, test_approx_f32(slot.fallback_color.b, theme.preview_surface.b))
		testing.expect(t, test_approx_f32(slot.fallback_color.a, theme.preview_surface.a))
	}
}

@(test)
test_app_ui_main_menu_preview_overlay_starts_fully_dark :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	found := false
	for command in ctx.commands {
		if !test_is_black_horizontal_fade(command, 1, 0.5) {
			continue
		}
		for next in ctx.commands {
			if test_is_black_horizontal_fade(next, 0.5, 0) &&
			   math.abs(next.rect.x - (command.rect.x + command.rect.w)) <= 0.01 &&
			   math.abs(next.rect.y - command.rect.y) <= 0.01 &&
			   math.abs(next.rect.h - command.rect.h) <= 0.01 {
				full_w := command.rect.w + next.rect.w
				midpoint := command.rect.w / full_w
				if math.abs(midpoint - game.MAIN_MENU_SIM_BUTTON_GRADIENT_MIDPOINT) <= 0.01 {
					found = true
				}
			}
		}
	}
	testing.expect(t, found)
}

@(test)
test_app_ui_main_menu_sim_buttons_do_not_draw_dark_inlay :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	theme := game.app_ui_menu_theme(&ctx, 1920, 1080)
	found_gradient := false
	found_dark_inlay := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Horizontal_Gradient_Rect {
			found_gradient = true
		}
		if command.kind == uifw.Draw_Command_Kind.Filled_Rounded_Rect &&
		   command.color.r == theme.shadow.r &&
		   command.color.g == theme.shadow.g &&
		   command.color.b == theme.shadow.b &&
		   command.color.a == theme.shadow.a {
			found_dark_inlay = true
		}
	}
	testing.expect(t, found_gradient)
	testing.expect(t, !found_dark_inlay)
}

@(test)
test_app_ui_main_menu_simulation_list_draws_scroll_edge_fades :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	width := f32(1920)
	height := f32(1080)
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), width, height, 1)
	theme := game.app_ui_menu_theme(&ctx, width, height)
	margin_x := max(width * 0.055, ctx.style.spacing_4)
	title_y := max(height * 0.070, ctx.style.spacing_4)
	title_scale := max((height * 0.31) / f32(16), ctx.style.display_text_scale * 1.2)
	title_text_h := uifw.GUI_FONT_LOGICAL_HEIGHT * title_scale
	title_h := min(max(max(height * 0.20, ctx.style.display_line_height), title_text_h), height - title_y)
	side_w := min(max(width * 0.23, f32(330)), f32(560))
	right_margin := max(width * 0.050, ctx.style.spacing_4)
	options_size := game.app_ui_main_menu_text_button_size(&ctx, "OPTIONS", theme)
	quit_size := game.app_ui_main_menu_text_button_size(&ctx, "QUIT", theme)
	button_w := max(side_w, max(options_size.x, quit_size.x))
	actions_x := max(width - right_margin - button_w, margin_x)
	list_w := min(max(width * 0.60, f32(680)), max(actions_x - theme.detail_gap - margin_x, 1))
	list_y := max(title_y + title_h + theme.inner_gap, height * 0.39)
	list_bottom := height - max(height * 0.050, ctx.style.spacing_4)
	list_h := max(list_bottom - list_y, theme.row_height * 2.25)
	viewport := uifw.Rect{margin_x, list_y, list_w, list_h}

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	top, bottom := test_count_scroll_fades(ctx.commands[:], viewport)
	testing.expect_value(t, top, 0)
	testing.expect_value(t, bottom, 1)

	ui.main_menu_scroll = 42
	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	top, bottom = test_count_scroll_fades(ctx.commands[:], viewport)
	testing.expect_value(t, top, 1)
	testing.expect(t, bottom >= 1)
}

@(test)
test_app_ui_main_menu_bottom_scroll_registers_primordial_live_preview :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_scroll = 1900

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: game.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	saw_primordial := false
	for i in 0 ..< ui.main_menu_preview_slot_count {
		if ui.main_menu_preview_slots[i].mode == game.App_Mode.Primordial {
			saw_primordial = true
		}
	}
	testing.expect(t, saw_primordial)
}

@(test)
test_render_main_menu_preview_viewport_matches_sim_button_clip :: proc(t: ^testing.T) {
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	render_ctx: game.Render_Context
	render_ctx.vk_ctx = &vk_ctx

	rect := uifw.Rect{118, 119, 1796, 438}
	clip := uifw.Rect{118, 160, 1796, 397}
	viewport: vk.Viewport
	scissor: vk.Rect2D
	ok := game.render_main_menu_preview_viewport_for_rect(&render_ctx, rect, clip, &viewport, &scissor)

	testing.expect(t, ok)
	testing.expect(t, test_approx_f32(viewport.x, rect.x))
	testing.expect(t, test_approx_f32(viewport.y, rect.y))
	testing.expect(t, test_approx_f32(viewport.width, rect.w))
	testing.expect(t, test_approx_f32(viewport.height, rect.h))
	testing.expect_value(t, scissor.offset.x, i32(clip.x))
	testing.expect_value(t, scissor.offset.y, i32(clip.y))
	testing.expect_value(t, scissor.extent.width, u32(clip.w))
	testing.expect_value(t, scissor.extent.height, u32(clip.h))
}

@(test)
test_render_main_menu_preview_scissor_clamps_to_swapchain :: proc(t: ^testing.T) {
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	render_ctx: game.Render_Context
	render_ctx.vk_ctx = &vk_ctx

	rect := uifw.Rect{-20, -30, 240, 160}
	clip := uifw.Rect{-10, -15, 120, 90}
	viewport: vk.Viewport
	scissor: vk.Rect2D
	ok := game.render_main_menu_preview_viewport_for_rect(&render_ctx, rect, clip, &viewport, &scissor)

	testing.expect(t, ok)
	testing.expect_value(t, i32(viewport.x), i32(rect.x))
	testing.expect_value(t, i32(viewport.y), i32(rect.y))
	testing.expect_value(t, u32(viewport.width), u32(rect.w))
	testing.expect_value(t, u32(viewport.height), u32(rect.h))
	testing.expect_value(t, scissor.offset.x, i32(0))
	testing.expect_value(t, scissor.offset.y, i32(0))
	testing.expect_value(t, scissor.extent.width, u32(110))
	testing.expect_value(t, scissor.extent.height, u32(75))
}

@(test)
test_render_main_menu_preview_viewport_clamps_partially_scrolled_row :: proc(t: ^testing.T) {
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	render_ctx: game.Render_Context
	render_ctx.vk_ctx = &vk_ctx

	rect := uifw.Rect{118, 980, 700, 220}
	clip := uifw.Rect{118, 980, 700, 100}
	viewport: vk.Viewport
	scissor: vk.Rect2D
	ok := game.render_main_menu_preview_viewport_for_rect(&render_ctx, rect, clip, &viewport, &scissor)

	testing.expect(t, ok)
	testing.expect_value(t, i32(viewport.x), i32(118))
	testing.expect_value(t, i32(viewport.y), i32(f32(vk_ctx.swapchain_extent.height) - rect.h))
	testing.expect_value(t, u32(viewport.width), u32(700))
	testing.expect_value(t, u32(viewport.height), u32(220))
	testing.expect(t, viewport.y + viewport.height <= f32(vk_ctx.swapchain_extent.height))
	testing.expect_value(t, scissor.offset.x, i32(118))
	testing.expect_value(t, scissor.offset.y, i32(980))
	testing.expect_value(t, scissor.extent.width, u32(700))
	testing.expect_value(t, scissor.extent.height, u32(100))
}

@(test)
test_render_main_menu_preview_size_uses_stable_slot_dimensions :: proc(t: ^testing.T) {
	slot := game.Main_Menu_Preview_Slot {
		mode = .Flow_Field,
		rect = {10, 20, 430, 260},
		clip_rect = {10, 20, 420, 220},
	}
	width, height := game.render_main_menu_preview_size_for_slot(slot)

	testing.expect_value(t, width, u32(430))
	testing.expect_value(t, height, u32(260))
}

@(test)
test_render_main_menu_preview_size_enforces_minimum :: proc(t: ^testing.T) {
	slot := game.Main_Menu_Preview_Slot {
		mode = .Slime_Mold,
		rect = {0, 0, 80, 60},
		clip_rect = {0, 0, 80, 60},
	}
	width, height := game.render_main_menu_preview_size_for_slot(slot)

	testing.expect_value(t, width, game.MAIN_MENU_SIM_PREVIEW_WIDTH)
	testing.expect_value(t, height, game.MAIN_MENU_SIM_PREVIEW_HEIGHT)
}

@(test)
test_render_main_menu_preview_size_enforces_cap_with_aspect :: proc(t: ^testing.T) {
	slot := game.Main_Menu_Preview_Slot {
		mode = .Flow_Field,
		rect = {0, 0, 1280, 720},
		clip_rect = {0, 0, 1280, 720},
	}
	width, height := game.render_main_menu_preview_size_for_slot(slot)

	testing.expect_value(t, width, game.MAIN_MENU_SIM_PREVIEW_MAX_WIDTH)
	testing.expect_value(t, height, game.MAIN_MENU_SIM_PREVIEW_MAX_HEIGHT)
}

@(test)
test_render_main_menu_preview_size_cap_preserves_non_16_9_aspect :: proc(t: ^testing.T) {
	slot := game.Main_Menu_Preview_Slot {
		mode = .Flow_Field,
		rect = {0, 0, 1280, 500},
		clip_rect = {0, 0, 1280, 500},
	}
	width, height := game.render_main_menu_preview_size_for_slot(slot)

	testing.expect_value(t, width, game.MAIN_MENU_SIM_PREVIEW_MAX_WIDTH)
	testing.expect_value(t, height, u32(250))
}

@(test)
test_render_main_menu_preview_size_for_mode_is_scroll_stable :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	ui.main_menu_preview_slot_count = 2
	ui.main_menu_preview_slots[0] = {mode = .Slime_Mold, rect = {0, 0, 384, 216}, clip_rect = {0, 0, 300, 160}}
	ui.main_menu_preview_slots[1] = {mode = .Flow_Field, rect = {0, 0, 512, 256}, clip_rect = {0, 0, 320, 180}}

	render_ctx: game.Render_Context
	render_ctx.app_ui = &ui

	flow_width, flow_height := game.render_main_menu_preview_size_for_mode(&render_ctx, .Flow_Field)
	missing_width, missing_height := game.render_main_menu_preview_size_for_mode(&render_ctx, .Gray_Scott)

	testing.expect_value(t, flow_width, game.MAIN_MENU_SIM_PREVIEW_WIDTH)
	testing.expect_value(t, flow_height, game.MAIN_MENU_SIM_PREVIEW_HEIGHT)
	testing.expect_value(t, missing_width, game.MAIN_MENU_SIM_PREVIEW_WIDTH)
	testing.expect_value(t, missing_height, game.MAIN_MENU_SIM_PREVIEW_HEIGHT)
}

@(test)
test_render_main_menu_preview_size_for_mode_ignores_swapchain_clip :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	ui.main_menu_preview_slot_count = 1
	ui.main_menu_preview_slots[0] = {mode = .Slime_Mold, rect = {-20, -10, 300, 200}, clip_rect = {0, 0, 220, 140}}

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 220, height = 140}
	render_ctx: game.Render_Context
	render_ctx.app_ui = &ui
	render_ctx.vk_ctx = &vk_ctx

	width, height := game.render_main_menu_preview_size_for_mode(&render_ctx, .Slime_Mold)

	testing.expect_value(t, width, game.MAIN_MENU_SIM_PREVIEW_WIDTH)
	testing.expect_value(t, height, game.MAIN_MENU_SIM_PREVIEW_HEIGHT)
}

@(test)
test_render_main_menu_preview_warm_policy_covers_all_supported_live_modes :: proc(t: ^testing.T) {
	testing.expect_value(t, game.render_main_menu_preview_supported_mode_count(), u32(9))
	testing.expect(t, game.app_ui_live_preview_supported(.Slime_Mold))
	testing.expect(t, game.app_ui_live_preview_supported(.Gray_Scott))
	testing.expect(t, game.app_ui_live_preview_supported(.Particle_Life))
	testing.expect(t, game.app_ui_live_preview_supported(.Flow_Field))
	testing.expect(t, game.app_ui_live_preview_supported(.Pellets))
	testing.expect(t, game.app_ui_live_preview_supported(.Voronoi_CA))
	testing.expect(t, game.app_ui_live_preview_supported(.Moire))
	testing.expect(t, game.app_ui_live_preview_supported(.Vectors))
	testing.expect(t, game.app_ui_live_preview_supported(.Primordial))
	testing.expect(t, !game.app_ui_live_preview_supported(.Gradient_Editor))
}

@(test)
test_app_ui_simulation_menu_panel_stays_inside_viewport_at_common_sizes :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	settings := game.settings_default()
	settings.menu_position = "right"
	ui: game.App_Ui_State
	game.app_ui_init(&ui, settings)
	ui.mode = .Gray_Scott

	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, 1)
	panel_720 := game.app_ui_simulation_menu_panel(&ui, &ctx, 1280, 720)
	testing.expect(t, panel_720.x >= ctx.style.margin)
	testing.expect(t, panel_720.x + panel_720.w <= 1280 - ctx.style.margin + 0.01)
	testing.expect(t, panel_720.y + panel_720.h <= 720 + 0.01)

	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1)
	panel_1080 := game.app_ui_simulation_menu_panel(&ui, &ctx, 1920, 1080)
	testing.expect(t, panel_1080.x >= ctx.style.margin)
	testing.expect(t, panel_1080.x + panel_1080.w <= 1920 - ctx.style.margin + 0.01)
	testing.expect(t, panel_1080.y + panel_1080.h <= 1080 + 0.01)

	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 3840, 2160, 1)
	panel_4k := game.app_ui_simulation_menu_panel(&ui, &ctx, 3840, 2160)
	testing.expect(t, panel_4k.x >= ctx.style.margin)
	testing.expect(t, panel_4k.x + panel_4k.w <= 3840 - ctx.style.margin + 0.01)
	testing.expect(t, panel_4k.y + panel_4k.h <= 2160 + 0.01)
}

@(test)
test_remaining_sim_pellets_sidebar_scroll_extent_tracks_ui_scale :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	sim: game.Remaining_Sim_State
	game.remaining_sim_init(&sim)

	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1)
	base_height := game.remaining_sim_controls_content_height(&sim, &ctx, .Pellets, 640)
	testing.expect(t, base_height > 1040)

	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1.5)
	scaled_height := game.remaining_sim_controls_content_height(&sim, &ctx, .Pellets, 640)
	testing.expect(t, scaled_height > base_height * 1.35)
}

test_first_text_command_index :: proc(commands: []uifw.Draw_Command, text: string) -> int {
	for command, i in commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == text {
			return i
		}
	}
	return -1
}

test_expect_text_order :: proc(t: ^testing.T, commands: []uifw.Draw_Command, expected: []string) {
	previous := -1
	for label in expected {
		index := test_first_text_command_index(commands, label)
		testing.expect(t, index >= 0)
		testing.expect(t, index > previous)
		previous = index
	}
}

test_draw_remaining_sim_menu_for_order :: proc(kind: game.Remaining_Sim_Kind) -> (ctx: uifw.Gui_Context) {
	uifw.gui_init(&ctx)
	uifw.gui_begin_frame(&ctx, {})
	sim: game.Remaining_Sim_State
	game.remaining_sim_init(&sim)
	editor: game.Color_Scheme_Editor_State
	game.color_scheme_editor_init(&editor)
	game.remaining_sim_draw_controls(&sim, &ctx, kind, {0, 0, 760, 6000}, &editor, nil)
	return
}

@(test)
test_remaining_sim_menus_follow_old_section_order :: proc(t: ^testing.T) {
	slime := test_draw_remaining_sim_menu_for_order(.Slime_Mold)
	defer uifw.gui_destroy(&slime)
	test_expect_text_order(t, slime.commands[:], []string{"About this simulation", "Presets", "Display Settings", "Controls", "Settings", "Pheromone", "Agent", "Mask"})

	flow := test_draw_remaining_sim_menu_for_order(.Flow_Field)
	defer uifw.gui_destroy(&flow)
	test_expect_text_order(t, flow.commands[:], []string{"About this simulation", "Presets", "Display Settings", "Controls", "Settings", "Flow Field", "Particles", "Trails"})

	pellets := test_draw_remaining_sim_menu_for_order(.Pellets)
	defer uifw.gui_destroy(&pellets)
	test_expect_text_order(t, pellets.commands[:], []string{"About this simulation", "Presets", "Display Settings", "Controls", "Settings", "Particle", "Physics"})

	voronoi := test_draw_remaining_sim_menu_for_order(.Voronoi_CA)
	defer uifw.gui_destroy(&voronoi)
	test_expect_text_order(t, voronoi.commands[:], []string{"About this simulation", "Presets", "Display Settings", "Controls", "Settings", "Voronoi Parameters"})

	primordial := test_draw_remaining_sim_menu_for_order(.Primordial)
	defer uifw.gui_destroy(&primordial)
	test_expect_text_order(t, primordial.commands[:], []string{"About this simulation", "Presets", "Display Settings", "Controls", "Settings", "Particle Configuration", "Physics Parameters"})

	moire := test_draw_remaining_sim_menu_for_order(.Moire)
	defer uifw.gui_destroy(&moire)
	test_expect_text_order(t, moire.commands[:], []string{"About this simulation", "Presets", "Display Settings", "Controls", "Actions", "Animation", "Moire Patterns", "Advection Flow"})

	vectors := test_draw_remaining_sim_menu_for_order(.Vectors)
	defer uifw.gui_destroy(&vectors)
	test_expect_text_order(t, vectors.commands[:], []string{"About this simulation", "Presets", "Color", "Vector Field"})
}

@(test)
test_gray_scott_and_particle_life_menus_follow_old_section_order :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	uifw.gui_begin_frame(&ctx, {})
	gray: game.Gray_Scott_Simulation
	game.gray_scott_init(&gray, 320, 240)
	editor: game.Color_Scheme_Editor_State
	game.color_scheme_editor_init(&editor)
	scroll := f32(0)
	_ = game.gray_scott_draw_controls(&gray, &ctx, {0, 0, 760, 6000}, &scroll, nil, &editor)
	test_expect_text_order(t, ctx.commands[:], []string{"About this simulation", "Presets", "Display Settings", "Post Processing", "Controls", "Settings", "Reaction-Diffusion", "Camera"})

	particle_ctx: uifw.Gui_Context
	uifw.gui_init(&particle_ctx)
	defer uifw.gui_destroy(&particle_ctx)
	uifw.gui_begin_frame(&particle_ctx, {})
	particle: game.Particle_Life_Simulation
	game.particle_life_init(&particle, 320, 240)
	particle_scroll := f32(0)
	game.particle_life_draw_controls(&particle, &particle_ctx, {0, 0, 760, 8000}, &particle_scroll, nil, &editor)
	test_expect_text_order(t, particle_ctx.commands[:], []string{"About this simulation", "Presets", "Display Settings", "Post Processing", "Controls", "Settings", "Physics", "Local Constraints", "Blob Analysis", "Camera"})
}

@(test)
test_preset_selector_side_arrows_cycle_and_apply_builtin_presets :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	gray: game.Gray_Scott_Simulation
	game.gray_scott_init(&gray, 320, 240)
	state: game.Preset_Fieldset_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {240, 22}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 120}, .Column, 0, 44)
	game.preset_fieldset_draw(&ctx, &state, nil, "gray_scott", game.GRAY_SCOTT_BUILTIN_PRESET_NAMES[:], 1, {
		kind = .Gray_Scott,
		gray_scott = &gray,
	})
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, state.selected_index, 2)
	testing.expect_value(t, gray.runtime.current_preset_index, 2)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {20, 22}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 120}, .Column, 0, 44)
	game.preset_fieldset_draw(&ctx, &state, nil, "gray_scott", game.GRAY_SCOTT_BUILTIN_PRESET_NAMES[:], gray.runtime.current_preset_index, {
		kind = .Gray_Scott,
		gray_scott = &gray,
	})
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, state.selected_index, 1)
	testing.expect_value(t, gray.runtime.current_preset_index, 1)
}

@(test)
test_gui_column_layout_allocates_rows :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {10, 20, 200, 120}, .Column, 5, 30)
	first := uifw.gui_next_rect(&ctx)
	second := uifw.gui_next_rect(&ctx, height = 40)
	uifw.gui_layout_end(&ctx)

	testing.expect_value(t, first.x, f32(10))
	testing.expect_value(t, first.y, f32(20))
	testing.expect_value(t, first.w, f32(200))
	testing.expect_value(t, first.h, f32(30))
	testing.expect_value(t, second.y, f32(55))
	testing.expect_value(t, second.h, f32(40))
}

@(test)
test_gui_grid_layout_allocates_cards :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	grid := uifw.gui_grid_begin(&ctx, {0, 0, 210, 200}, 2, 10)
	first := uifw.gui_grid_next(&grid, 50)
	second := uifw.gui_grid_next(&grid, 50)
	third := uifw.gui_grid_next(&grid, 50)

	testing.expect_value(t, first, uifw.Rect{0, 0, 100, 50})
	testing.expect_value(t, second, uifw.Rect{110, 0, 100, 50})
	testing.expect_value(t, third, uifw.Rect{0, 60, 100, 50})
}

@(test)
test_gui_scroll_area_clamps_and_offsets_content :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	scroll := f32(0)
	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, wheel_delta = -4})
	uifw.gui_scroll_begin(&ctx, {0, 0, 120, 100}, 190, &scroll)
	first := uifw.gui_next_rect(&ctx, height = 40)
	uifw.gui_scroll_end(&ctx)

	testing.expect_value(t, scroll, f32(90))
	testing.expect_value(t, first.y, f32(-90))
	saw_scissor_begin := false
	saw_scissor_end := false
	scrollbar_rects := 0
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Scissor_Begin {
			saw_scissor_begin = true
		}
		if command.kind == uifw.Draw_Command_Kind.Scissor_End {
			saw_scissor_end = true
		}
		if command.kind == uifw.Draw_Command_Kind.Filled_Rounded_Rect {
			scrollbar_rects += 1
		}
	}
	testing.expect(t, saw_scissor_begin)
	testing.expect(t, saw_scissor_end)
	testing.expect(t, scrollbar_rects >= 2)
}

@(test)
test_gui_scroll_area_draws_bottom_edge_fade_at_top :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	viewport := uifw.Rect{0, 0, 120, 100}
	scroll := f32(0)
	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_scroll_begin(&ctx, viewport, 190, &scroll)
	uifw.gui_scroll_end(&ctx)

	top, bottom := test_count_scroll_fades(ctx.commands[:], viewport)
	testing.expect_value(t, top, 0)
	testing.expect_value(t, bottom, 1)
}

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
	uifw.gui_begin_frame(&ctx, {key_right = true, key_down = true})
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
	testing.expect(t, uifw.gui_number_drag_f32(&ctx, "Value: 1", "value", &value, 1, 0, 10))
	uifw.gui_pop_id(&ctx)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, value, f32(2))
	testing.expect_value(t, ctx.focused, id)

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	uifw.gui_push_id(&ctx, "settings")
	_ = uifw.gui_number_drag_f32(&ctx, "Value: 2", "value", &value, 1, 0, 10)
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
	changed := uifw.gui_number_drag_f32(&ctx, "Value: 10", "value", &value, 1, 0, 100, false)
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
	_ = uifw.gui_number_drag_f32(&ctx, "Number", "number", &value, 1, 0, 100)
	uifw.gui_layout_end(&ctx)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {30, 10}, mouse_down = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	testing.expect(t, uifw.gui_number_drag_f32(&ctx, "Number", "number", &value, 1, 0, 100))
	uifw.gui_layout_end(&ctx)
	testing.expect(t, value > 10)

	text_input: [32]u8
	text_input[0] = '4'
	text_input[1] = '2'
	ctx.focused = uifw.gui_make_id(&ctx, "number")
	uifw.gui_begin_frame(&ctx, {text_input = text_input, text_input_len = 2})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	testing.expect(t, uifw.gui_number_drag_f32(&ctx, "Number", "number", &value, 1, 0, 100))
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
	testing.expect(t, uifw.gui_number_drag_f32(&ctx, "Number", "number", &value, 1, 0, 100))
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, value, f32(11))
	testing.expect_value(t, ctx.text_edit_id, uifw.GUI_ID_NONE)

	ctx.text_edit_id = id
	uifw.gui_number_edit_set_value(&ctx, value)
	ctx.text_edit_caret = 0
	ctx.text_edit_anchor = 0

	uifw.gui_begin_frame(&ctx, {key_right = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_number_drag_f32(&ctx, "Number", "number", &value, 1, 0, 100))
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
	uifw.gui_number_edit_set_value(&ctx, value)
	ctx.text_edit_caret = ctx.text_edit_len
	ctx.text_edit_anchor = ctx.text_edit_len

	uifw.gui_begin_frame(&ctx, {mouse_pos = {30, 10}, mouse_down = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 80}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_number_drag_f32(&ctx, "Number", "number", &value, 1, 0, 100))
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

	testing.expect(t, len(ctx.commands) >= 8)
	testing.expect_value(t, ctx.commands[0].kind, uifw.Draw_Command_Kind.Filled_Rounded_Rect)
	testing.expect_value(t, ctx.commands[5].kind, uifw.Draw_Command_Kind.Refractive_Glass_Rect)
	testing.expect_value(t, ctx.commands[6].kind, uifw.Draw_Command_Kind.Stroked_Rounded_Rect)
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

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_pressed_y = 1, nav_y = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 240}, .Column, 0, 44)
	testing.expect(t, uifw.gui_radio_group(&ctx, "Group", "group", &current, options[:]))
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, current, 1)
	testing.expect_value(t, ctx.focused, group_id)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_y = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 220, 240}, .Column, 0, 44)
	testing.expect(t, !uifw.gui_radio_group(&ctx, "Group", "group", &current, options[:]))
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
	testing.expect(t, uifw.gui_number_drag_f32(&ctx, "Number", "number", &value, 1, 0, 100))
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
		secondary_down = true,
		secondary_pressed = true,
	})

	testing.expect(t, filtered.mouse_down)
	testing.expect(t, filtered.mouse_pressed)
	testing.expect_value(t, filtered.mouse_button, u32(3))
	testing.expect(t, filtered.secondary_down)
}

@(test)
test_app_ui_active_controller_disconnect_pauses_simulation :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Flow_Field
	ui.flow_field.paused = false
	ui.simulation_shell.show_ui = false
	ui.simulation_shell.controls_visible = false

	uifw.gui_begin_frame(&ctx, {
		active_device = .Controller,
		controller_disconnected = true,
	})
	game.app_ui_handle_controller_disconnect(&ui, &ctx, nil, nil)

	testing.expect(t, ui.flow_field.paused)
	testing.expect(t, ui.simulation_shell.show_ui)
	testing.expect(t, ui.simulation_shell.controls_visible)
}
