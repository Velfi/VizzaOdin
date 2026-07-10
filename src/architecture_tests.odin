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

test_first_text_command_index :: proc(commands: []uifw.Draw_Command, text: string) -> int {
	for command, i in commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == text {
			return i
		}
	}
	return -1
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
	testing.expect_value(t, host.video_recorder_pixel_format_name(vk.Format.B8G8R8A8_UNORM), "bgra")
	testing.expect_value(t, host.video_recorder_pixel_format_name(vk.Format.B8G8R8A8_SRGB), "bgra")
	testing.expect_value(t, host.video_recorder_pixel_format_name(vk.Format.R8G8B8A8_UNORM), "rgba")
}

@(test)
test_video_recorder_fps_defaults_and_clamps_to_sixty :: proc(t: ^testing.T) {
	settings := game.settings_default()
	settings.default_fps_limit_enabled = false
	settings.default_fps_limit = 240
	testing.expect_value(t, host.video_recorder_fps_from_settings(settings), u32(60))

	settings.default_fps_limit_enabled = true
	settings.default_fps_limit = 30
	testing.expect_value(t, host.video_recorder_fps_from_settings(settings), u32(30))

	settings.default_fps_limit = 240
	testing.expect_value(t, host.video_recorder_fps_from_settings(settings), u32(60))
}

@(test)
test_video_recorder_resamples_wall_clock_to_fixed_rate_timeline :: proc(t: ^testing.T) {
	testing.expect_value(t, host.video_recorder_desired_frame_count(0, 60), u64(1))
	testing.expect_value(t, host.video_recorder_desired_frame_count(0.5, 60), u64(31))
	testing.expect_value(t, host.video_recorder_desired_frame_count(1.0, 60), u64(61))
	testing.expect_value(t, host.video_recorder_desired_frame_count(1.0, 0), u64(0))
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
test_gray_scott_noise_seed_preserves_live_gpu_runtime :: proc(t: ^testing.T) {
	sim: game.Gray_Scott_Simulation
	game.gray_scott_init(&sim, 640, 480)
	sim.gpu.ready = true
	seed_before := sim.runtime.seed

	game.gray_scott_seed_noise(&sim)

	testing.expect(t, sim.runtime.seed != seed_before)
	testing.expect_value(t, sim.runtime.pending_seed_mode, game.GRAY_SCOTT_MODE_NOISE_SEED)
	testing.expect(t, sim.gpu.ready)
}

@(test)
test_gray_scott_builtin_preset_preserves_live_field :: proc(t: ^testing.T) {
	sim: game.Gray_Scott_Simulation
	game.gray_scott_init(&sim, 640, 480)
	sim.runtime.pending_seed_mode = 0
	sim.gpu.ready = true
	seed_before := sim.runtime.seed

	game.gray_scott_apply_builtin_preset(&sim, 2)

	testing.expect_value(t, sim.runtime.seed, seed_before)
	testing.expect_value(t, sim.runtime.pending_seed_mode, u32(0))
	testing.expect(t, sim.gpu.ready)
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
		camera_pan_down = true,
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
test_camera_controls_trackpad_zoom_clamps_bursts_and_uses_visible_camera :: proc(t: ^testing.T) {
	camera: game.Camera_Control_State
	game.camera_controls_init(&camera)
	camera.position = {0.25, -0.1}
	camera.target_position = {2, 1}
	camera.zoom = 1.25
	camera.target_zoom = 3
	mouse := uifw.Vec2{150, 25}
	before := game.camera_controls_screen_to_world(&camera, mouse, 200, 100)

	game.camera_controls_apply_input(&camera, {
		window_width = 200,
		window_height = 100,
		mouse_pos = mouse,
		wheel_delta = 100,
		delta_time = 0,
		camera_sensitivity = 1,
	})
	after := game.camera_controls_screen_to_world(&camera, mouse, 200, 100)

	testing.expect(t, math.abs(before[0] - after[0]) < 0.00001)
	testing.expect(t, math.abs(before[1] - after[1]) < 0.00001)
	testing.expect(t, camera.zoom < f32(1.5))
}

@(test)
test_camera_controls_shift_trackpad_scroll_pans_without_zooming :: proc(t: ^testing.T) {
	camera: game.Camera_Control_State
	game.camera_controls_init(&camera)
	game.camera_controls_apply_input(&camera, {
		wheel_delta = 1.5,
		key_shift = true,
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 1,
	})
	testing.expect(t, camera.target_position[0] > 0)
	testing.expect_value(t, camera.target_zoom, f32(1))
}

@(test)
test_particle_life_camera_uses_shared_wasd_qe_reset_controls :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	game.particle_life_init(&sim, 1280, 720)

	game.particle_life_apply_frame_input(&sim, {key_w = true, key_d = true, key_e = true, delta_time = 1.0 / 60.0, camera_sensitivity = 2})
	testing.expect(t, sim.runtime.camera_target_x > 0)
	testing.expect(t, sim.runtime.camera_target_y < 0)
	testing.expect(t, sim.runtime.camera_target_zoom > 1)
	testing.expect(t, sim.runtime.camera_x > 0)
	testing.expect(t, sim.runtime.camera_y < 0)

	game.particle_life_apply_frame_input(&sim, {key_c = true, delta_time = 1.0 / 60.0, camera_sensitivity = 1})
	testing.expect_value(t, sim.runtime.camera_target_x, f32(0))
	testing.expect_value(t, sim.runtime.camera_target_y, f32(0))
	testing.expect_value(t, sim.runtime.camera_target_zoom, f32(1))
}

@(test)
test_slime_mold_camera_uses_shared_unfocused_controls :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	game.remaining_sim_init(&sim)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Slime_Mold, {
		key_w = true,
		key_d = true,
		key_e = true,
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 2,
	})
	testing.expect(t, sim.camera.target_position[0] > 0)
	testing.expect(t, sim.camera.target_position[1] < 0)
	testing.expect(t, sim.camera.target_zoom > 1)
	testing.expect(t, sim.camera.position[0] > 0)
	testing.expect(t, sim.camera.position[1] < 0)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Slime_Mold, {
		key_c = true,
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 1,
	})
	testing.expect_value(t, sim.camera.target_position[0], f32(0))
	testing.expect_value(t, sim.camera.target_position[1], f32(0))
	testing.expect_value(t, sim.camera.target_zoom, f32(1))
}

@(test)
test_slime_mold_camera_accepts_controller_pan_and_zoom :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	game.remaining_sim_init(&sim)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Slime_Mold, {
		controller_left = {1, -1},
		controller_zoom = 1,
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 1,
	})

	testing.expect(t, sim.camera.target_position[0] > 0)
	testing.expect(t, sim.camera.target_position[1] < 0)
	testing.expect(t, sim.camera.target_zoom > 1)
}

@(test)
test_controller_camera_y_inversion_preserves_default_direction_and_isolates_sensitivity :: proc(t: ^testing.T) {
	normal, inverted, slow, fast: game.Camera_Control_State
	game.camera_controls_init(&normal)
	game.camera_controls_init(&inverted)
	game.camera_controls_init(&slow)
	game.camera_controls_init(&fast)
	base_input := game.Ui_Frame_Input{
		controller_left = {0.5, -0.75},
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 4,
		controller_camera_sensitivity = 1,
	}
	game.camera_controls_apply_input(&normal, base_input)
	base_input.controller_camera_invert_y = true
	game.camera_controls_apply_input(&inverted, base_input)
	testing.expect(t, normal.target_position[1] < 0)
	testing.expect(t, inverted.target_position[1] > 0)
	testing.expect(t, math.abs(normal.target_position[1] + inverted.target_position[1]) < 0.00001)

	base_input.controller_camera_invert_y = false
	base_input.controller_camera_sensitivity = 0.5
	game.camera_controls_apply_input(&slow, base_input)
	base_input.controller_camera_sensitivity = 2
	game.camera_controls_apply_input(&fast, base_input)
	testing.expect(t, math.abs(fast.target_position[0]) > math.abs(slow.target_position[0]))
	zoom_slow, zoom_fast: game.Camera_Control_State
	game.camera_controls_init(&zoom_slow)
	game.camera_controls_init(&zoom_fast)
	game.camera_controls_apply_input(&zoom_slow, {controller_zoom = 1, camera_sensitivity = 4, controller_camera_sensitivity = 0.5, delta_time = 1.0 / 60.0})
	game.camera_controls_apply_input(&zoom_fast, {controller_zoom = 1, camera_sensitivity = 4, controller_camera_sensitivity = 2, delta_time = 1.0 / 60.0})
	testing.expect(t, zoom_fast.target_zoom > zoom_slow.target_zoom)

	keyboard_a, keyboard_b: game.Camera_Control_State
	game.camera_controls_init(&keyboard_a)
	game.camera_controls_init(&keyboard_b)
	game.camera_controls_apply_input(&keyboard_a, {key_w = true, camera_sensitivity = 1, controller_camera_sensitivity = 0.1, delta_time = 1.0 / 60.0})
	game.camera_controls_apply_input(&keyboard_b, {key_w = true, camera_sensitivity = 1, controller_camera_sensitivity = 5, delta_time = 1.0 / 60.0})
	testing.expect_value(t, keyboard_a.target_position, keyboard_b.target_position)
}

@(test)
test_slime_mold_camera_resets_from_controller_reset_action :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	game.remaining_sim_init(&sim)
	sim.camera.position = {1, -0.5}
	sim.camera.target_position = sim.camera.position
	sim.camera.zoom = 2
	sim.camera.target_zoom = 2

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Slime_Mold, {
		camera_reset = true,
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 1,
	})

	testing.expect_value(t, sim.camera.position[0], f32(0))
	testing.expect_value(t, sim.camera.position[1], f32(0))
	testing.expect_value(t, sim.camera.zoom, f32(1))
	testing.expect_value(t, sim.camera.target_zoom, f32(1))
}

@(test)
test_slime_camera_uniform_uses_runtime_camera_state :: proc(t: ^testing.T) {
	camera: game.Camera_Control_State
	game.camera_controls_init(&camera)
	camera.position = {1, -0.5}
	camera.target_position = camera.position
	camera.zoom = 2
	camera.target_zoom = 2

	uniform := game.slime_camera_uniform_for_state(320, 160, &camera)

	testing.expect_value(t, uniform.position[0], f32(1))
	testing.expect_value(t, uniform.position[1], f32(-0.5))
	testing.expect_value(t, uniform.zoom, f32(2))
	testing.expect_value(t, uniform.aspect_ratio, f32(2))
	testing.expect_value(t, uniform.transform_matrix[0], f32(2))
	testing.expect_value(t, uniform.transform_matrix[5], f32(2))
	testing.expect_value(t, uniform.transform_matrix[12], f32(-2))
	testing.expect_value(t, uniform.transform_matrix[13], f32(1))
}

@(test)
test_controller_left_stick_click_requests_camera_reset :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)

	host.app_apply_gamepad_button(app, .LEFT_STICK, true)
	testing.expect(t, app.controller_camera_reset_pressed)

	host.app_apply_gamepad_button(app, .LEFT_STICK, false)
	testing.expect(t, app.controller_camera_reset_pressed)

	host.app_poll_events(app)
	testing.expect(t, !app.controller_camera_reset_pressed)
}

@(test)
test_controller_confirm_is_a_single_press_pulse :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)

	host.app_apply_gamepad_button(app, .SOUTH, true)
	testing.expect(t, app.controller_accept_down)
	testing.expect(t, app.input.accept)

	// The physical button remains held, but the one-frame action pulse expires.
	host.app_poll_events(app)
	testing.expect(t, app.controller_accept_down)
	testing.expect(t, !app.input.accept)
}

@(test)
test_keyboard_confirm_ignores_auto_repeat :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)

	host.app_apply_key_event(app, sdl.K_RETURN, .RETURN, true)
	testing.expect(t, app.input.key_enter)

	host.app_poll_events(app)
	host.app_apply_key_event(app, sdl.K_RETURN, .RETURN, true, true)
	testing.expect(t, !app.input.key_enter)
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
test_flow_field_input_tracks_cursor_mode_and_vulkan_y :: proc(t: ^testing.T) {
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
	testing.expect_value(t, sim.cursor_world[1], f32(-0.5))
	testing.expect(t, sim.cursor_world_velocity[0] > 0)
	testing.expect(t, sim.cursor_world_velocity[1] < 0)
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
test_app_ui_navigation_tracks_previous_mode :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	testing.expect_value(t, ui.mode, game.App_Mode.Main_Menu)
	game.app_ui_navigate(&ui, .Options)
	testing.expect_value(t, ui.mode, game.App_Mode.Options)
	testing.expect_value(t, ui.previous_mode, game.App_Mode.Main_Menu)
}

@(test)
test_app_ui_scene_to_main_menu_waits_at_black_until_menu_rendered :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	game.app_ui_navigate(&ui, .Slime_Mold)
	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_OUT_SECONDS)
	game.app_ui_mode_transition_notify_loaded(&ui)
	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_IN_SECONDS)

	game.app_ui_navigate(&ui, .Main_Menu)
	testing.expect_value(t, ui.mode, game.App_Mode.Slime_Mold)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Fade_Out)
	testing.expect_value(t, ui.mode_transition_target, game.App_Mode.Main_Menu)
	testing.expect(t, test_approx_f32(game.app_ui_mode_transition_opacity(&ui), 0))

	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_OUT_SECONDS * 0.5)
	testing.expect_value(t, ui.mode, game.App_Mode.Slime_Mold)
	testing.expect(t, test_approx_f32(game.app_ui_mode_transition_opacity(&ui), 0.5))

	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_OUT_SECONDS * 0.5)
	testing.expect_value(t, ui.mode, game.App_Mode.Main_Menu)
	testing.expect_value(t, ui.previous_mode, game.App_Mode.Slime_Mold)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Waiting_For_Target)
	testing.expect(t, test_approx_f32(game.app_ui_mode_transition_opacity(&ui), 1))

	game.app_ui_mode_transition_update(&ui, 1)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Waiting_For_Target)
	testing.expect(t, test_approx_f32(game.app_ui_mode_transition_opacity(&ui), 1))

	game.app_ui_mode_transition_notify_loaded(&ui)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Fade_In)
	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_IN_SECONDS * 0.5)
	testing.expect(t, test_approx_f32(game.app_ui_mode_transition_opacity(&ui), 0.5))
	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_IN_SECONDS * 0.5)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Idle)
	testing.expect(t, test_approx_f32(game.app_ui_mode_transition_opacity(&ui), 0))
}

@(test)
test_app_ui_main_menu_to_scene_waits_at_black_until_scene_rendered :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	game.app_ui_navigate(&ui, .Particle_Life)
	testing.expect_value(t, ui.mode, game.App_Mode.Main_Menu)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Fade_Out)
	testing.expect_value(t, ui.mode_transition_target, game.App_Mode.Particle_Life)

	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_OUT_SECONDS)
	testing.expect_value(t, ui.mode, game.App_Mode.Particle_Life)
	testing.expect_value(t, ui.previous_mode, game.App_Mode.Main_Menu)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Waiting_For_Target)
	testing.expect(t, test_approx_f32(game.app_ui_mode_transition_opacity(&ui), 1))

	game.app_ui_mode_transition_notify_loaded(&ui)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Fade_In)
	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_IN_SECONDS)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Idle)
}

@(test)
test_app_ui_non_scene_returns_to_main_menu_without_fade :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	game.app_ui_navigate(&ui, .Options)
	game.app_ui_navigate(&ui, .Main_Menu)

	testing.expect_value(t, ui.mode, game.App_Mode.Main_Menu)
	testing.expect_value(t, ui.previous_mode, game.App_Mode.Options)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Idle)
}

@(test)
test_main_menu_backdrop_selects_different_palette_on_reentry :: proc(t: ^testing.T) {
	names := game.color_scheme_available_names_cached()
	if len(names) < 2 {
		testing.expect(t, true)
		return
	}

	backdrop: rendervk.Main_Menu_Backdrop_Gpu_State
	rendervk.main_menu_backdrop_select_next_palette(&backdrop)
	first: game.Color_Scheme_Name
	game.color_scheme_name_set(&first, rendervk.main_menu_backdrop_current_palette_name(&backdrop))
	rendervk.main_menu_backdrop_select_next_palette(&backdrop)
	second := rendervk.main_menu_backdrop_current_palette_name(&backdrop)

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

	first: rendervk.Main_Menu_Backdrop_Gpu_State
	second: rendervk.Main_Menu_Backdrop_Gpu_State
	rendervk.main_menu_backdrop_seed_palette(&first, 1)
	rendervk.main_menu_backdrop_seed_palette(&second, 2)

	rendervk.main_menu_backdrop_select_next_palette(&first)
	rendervk.main_menu_backdrop_select_next_palette(&second)

	testing.expect(t, rendervk.main_menu_backdrop_current_palette_name(&first) != rendervk.main_menu_backdrop_current_palette_name(&second))
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
	worker: host.Render_Worker_State

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

	backend: rendervk.Render_Backend
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	rendervk.render_backend_handle_main_menu_palette_requests(&backend, &ui, .Main_Menu)
	first: game.Color_Scheme_Name
	game.color_scheme_name_set(&first, rendervk.main_menu_backdrop_current_palette_name(&backend.main_menu_backdrop))

	ui.main_menu_palette_randomize_requested = true
	rendervk.render_backend_handle_main_menu_palette_requests(&backend, &ui, .Main_Menu)
	second := rendervk.main_menu_backdrop_current_palette_name(&backend.main_menu_backdrop)

	testing.expect(t, !ui.main_menu_palette_randomize_requested)
	testing.expect(t, game.color_scheme_name_get(&first) != second)
}

@(test)
test_main_menu_preview_palette_helper_sets_reversed_scheme :: proc(t: ^testing.T) {
	palette := "MATPLOTLIB_viridis"

	gray_scott := game.gray_scott_default_settings()
	rendervk.render_main_menu_apply_gray_scott_palette(&gray_scott, palette)
	testing.expect_value(t, game.color_scheme_name_get(&gray_scott.color_scheme), palette)
	testing.expect(t, gray_scott.color_scheme_reversed)

	particle_life := game.particle_life_default_settings()
	rendervk.render_main_menu_apply_particle_life_palette(&particle_life, palette)
	testing.expect_value(t, game.color_scheme_name_get(&particle_life.color_scheme), palette)
	testing.expect(t, particle_life.color_scheme_reversed)

	flow := game.flow_settings_default()
	rendervk.render_main_menu_apply_flow_palette(&flow, palette)
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

	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Slime_Mold, palette))
	test_expect_color_scheme(t, &ui.slime_mold.slime.color_scheme, ui.slime_mold.slime.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Gray_Scott, palette))
	test_expect_color_scheme(t, &gray_scott.color_scheme, gray_scott.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Particle_Life, palette))
	test_expect_color_scheme(t, &particle_life.color_scheme, particle_life.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Flow_Field, palette))
	test_expect_color_scheme(t, &ui.flow_field.flow.color_scheme, ui.flow_field.flow.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Pellets, palette))
	test_expect_color_scheme(t, &ui.pellets.pellets.color_scheme, ui.pellets.pellets.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Voronoi_CA, palette))
	test_expect_color_scheme(t, &ui.voronoi_ca.voronoi.color_scheme, ui.voronoi_ca.voronoi.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Moire, palette))
	test_expect_color_scheme(t, &ui.moire.moire.color_scheme, ui.moire.moire.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Vectors, palette))
	test_expect_color_scheme(t, &ui.vectors.vectors.color_scheme, ui.vectors.vectors.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Primordial, palette))
	test_expect_color_scheme(t, &ui.primordial.primordial.color_scheme, ui.primordial.primordial.color_scheme_reversed, palette, true)
	testing.expect(t, !rendervk.render_main_menu_apply_palette_to_mode(&ui, &gray_scott, &particle_life, .Gradient_Editor, palette))
}

@(test)
test_render_worker_main_menu_launch_applies_current_menu_palette_once :: proc(t: ^testing.T) {
	palette := "MATPLOTLIB_viridis"
	runtime := new(host.Render_Worker_Runtime)
	defer free(runtime)
	game.app_ui_init(&runtime.app_ui, game.settings_default())
	game.color_scheme_name_set(&runtime.render_backend.main_menu_backdrop.palette_name, palette)

	runtime.app_ui.mode = .Flow_Field
	host.render_worker_apply_main_menu_palette_after_navigation(runtime, .Options)
	test_expect_color_scheme(t, &runtime.app_ui.flow_field.flow.color_scheme, runtime.app_ui.flow_field.flow.color_scheme_reversed, "MATPLOTLIB_cubehelix", true)

	host.render_worker_apply_main_menu_palette_after_navigation(runtime, .Main_Menu)
	test_expect_color_scheme(t, &runtime.app_ui.flow_field.flow.color_scheme, runtime.app_ui.flow_field.flow.color_scheme_reversed, palette, true)
}

@(test)
test_render_worker_set_color_scheme_preserves_reversed_when_omitted :: proc(t: ^testing.T) {
	runtime := new(host.Render_Worker_Runtime)
	defer free(runtime)
	game.app_ui_init(&runtime.app_ui, game.settings_default())

	runtime.app_ui.slime_mold.slime.color_scheme_reversed = false
	testing.expect(t, host.render_worker_set_color_scheme(runtime, .Slime_Mold, "MATPLOTLIB_viridis", false, false))
	test_expect_color_scheme(t, &runtime.app_ui.slime_mold.slime.color_scheme, runtime.app_ui.slime_mold.slime.color_scheme_reversed, "MATPLOTLIB_viridis", false)

	runtime.app_ui.slime_mold.slime.color_scheme_reversed = true
	testing.expect(t, host.render_worker_set_color_scheme(runtime, .Slime_Mold, "ZELDA_Aqua", false, true))
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
	settings.auto_hide_delay = 4500
	settings.menu_position = "right"
	settings.remember_controller_focus = false
	settings.controller_deadzone = 0.18
	settings.controller_cursor_speed = 1.15
	settings.navigation_repeat_delay_ms = 475
	settings.navigation_repeat_interval_ms = 125
	settings.controller_face_layout = "East Accept"
	settings.controller_menu_layout = "View Pauses"
	settings.controller_shoulder_layout = "Left Next"
	settings.keyboard_shortcut_profile = "Custom"
	settings.keyboard_pause_binding = .P
	settings.keyboard_toggle_ui_binding = .H
	settings.keyboard_help_binding = .U
	settings.default_camera_sensitivity = 2.2
	settings.controller_camera_sensitivity = 1.7
	settings.controller_camera_invert_y = true
	settings.texture_filtering = "Nearest"

	testing.expect(t, game.settings_save_app(path, settings))
	loaded, ok := game.settings_load_app(path)
	testing.expect(t, ok)
	defer delete(loaded.menu_position)
	defer delete(loaded.texture_filtering)
	defer delete(loaded.controller_face_layout)
	defer delete(loaded.controller_menu_layout)
	defer delete(loaded.controller_shoulder_layout)
	defer delete(loaded.controller_trigger_layout)
	defer delete(loaded.keyboard_shortcut_profile)
	defer delete(loaded.preset_directory)
	testing.expect_value(t, loaded.ui_scale, settings.ui_scale)
	testing.expect_value(t, loaded.default_fps_limit, settings.default_fps_limit)
	testing.expect_value(t, loaded.default_fps_limit_enabled, settings.default_fps_limit_enabled)
	testing.expect_value(t, loaded.window_maximized, settings.window_maximized)
	testing.expect_value(t, loaded.auto_hide_delay, settings.auto_hide_delay)
	testing.expect_value(t, loaded.menu_position, settings.menu_position)
	testing.expect_value(t, loaded.remember_controller_focus, settings.remember_controller_focus)
	testing.expect_value(t, loaded.controller_deadzone, settings.controller_deadzone)
	testing.expect_value(t, loaded.controller_cursor_speed, settings.controller_cursor_speed)
	testing.expect_value(t, loaded.navigation_repeat_delay_ms, settings.navigation_repeat_delay_ms)
	testing.expect_value(t, loaded.navigation_repeat_interval_ms, settings.navigation_repeat_interval_ms)
	testing.expect_value(t, loaded.controller_face_layout, settings.controller_face_layout)
	testing.expect_value(t, loaded.controller_menu_layout, settings.controller_menu_layout)
	testing.expect_value(t, loaded.controller_shoulder_layout, settings.controller_shoulder_layout)
	testing.expect_value(t, loaded.keyboard_shortcut_profile, settings.keyboard_shortcut_profile)
	testing.expect_value(t, loaded.keyboard_pause_binding, settings.keyboard_pause_binding)
	testing.expect_value(t, loaded.keyboard_toggle_ui_binding, settings.keyboard_toggle_ui_binding)
	testing.expect_value(t, loaded.keyboard_help_binding, settings.keyboard_help_binding)
	testing.expect_value(t, loaded.default_camera_sensitivity, settings.default_camera_sensitivity)
	testing.expect_value(t, loaded.controller_camera_sensitivity, settings.controller_camera_sensitivity)
	testing.expect_value(t, loaded.controller_camera_invert_y, settings.controller_camera_invert_y)
	testing.expect_value(t, loaded.texture_filtering, settings.texture_filtering)
}

@(test)
test_custom_keyboard_binding_config_recovers_from_duplicates_and_reserved_space :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_invalid_keyboard_bindings.toml"
	text := "[input]\nkeyboard_shortcut_profile = \"Custom\"\nkeyboard_pause_binding = \"P\"\nkeyboard_toggle_ui_binding = \"Space\"\nkeyboard_help_binding = \"P\"\n"
	testing.expect(t, os.write_entire_file(path, transmute([]u8)text) == nil)
	loaded, ok := game.settings_load_app(path)
	testing.expect(t, ok)
	defer delete(loaded.keyboard_shortcut_profile)
	testing.expect_value(t, loaded.keyboard_shortcut_profile, "Custom")
	testing.expect(t, game.settings_keyboard_bindings_valid(loaded))
	testing.expect_value(t, loaded.keyboard_pause_binding, game.Keyboard_Shortcut_Key.Space)
	testing.expect_value(t, loaded.keyboard_toggle_ui_binding, game.Keyboard_Shortcut_Key.Slash)
	testing.expect_value(t, loaded.keyboard_help_binding, game.Keyboard_Shortcut_Key.F1)
}

@(test)
test_voronoi_canvas_tools_have_stable_cardinal_slots_and_pairs :: proc(t: ^testing.T) {
	set := game.canvas_tool_set_for_kind(.Voronoi_CA)
	testing.expect_value(t, set.tools[0].name, "Magnet")
	testing.expect_value(t, set.tools[0].primary_action, game.Canvas_Tool_Action.Attract)
	testing.expect_value(t, set.tools[0].secondary_action, game.Canvas_Tool_Action.Repel)
	testing.expect_value(t, set.tools[1].name, "Sites")
	testing.expect_value(t, set.tools[2].name, "Sculpt")
	testing.expect(t, !set.tools[3].valid)
}

@(test)
test_canvas_tool_dpad_selection_is_direct_and_ignores_empty_slots :: proc(t: ^testing.T) {
	set := game.canvas_tool_set_for_kind(.Voronoi_CA)
	state: game.Canvas_Tool_State
	game.canvas_tool_update_selection(&set, &state, {nav_pressed_y = -1})
	testing.expect_value(t, state.selected_slot, 1)
	testing.expect(t, state.changed)
	game.canvas_tool_update_selection(&set, &state, {nav_pressed_x = 1})
	testing.expect_value(t, state.selected_slot, 2)
	game.canvas_tool_update_selection(&set, &state, {nav_pressed_y = 1})
	testing.expect_value(t, state.selected_slot, 2)
	testing.expect(t, !state.changed)
}
