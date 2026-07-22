package main

import game "../packages/game"
import render_vk "../packages/render_vk"
import "core:math"
import "core:testing"

@(test)
test_st_flip_gpu_storage_is_device_local_and_cpu_buffers_are_host_visible :: proc(t: ^testing.T) {
	gpu_only := render_vk.st_flip_buffer_memory_properties(.GPU_Only)
	cpu_written := render_vk.st_flip_buffer_memory_properties(.CPU_Written)
	testing.expect(t, .DEVICE_LOCAL in gpu_only)
	testing.expect(t, !(.HOST_VISIBLE in gpu_only))
	testing.expect(t, .HOST_VISIBLE in cpu_written)
	testing.expect(t, .HOST_COHERENT in cpu_written)
}

test_st_flip_temporal_kernel_is_one_sided_and_forward_weighted :: proc(t: ^testing.T) {
	testing.expect_value(t, game.st_flip_temporal_weight(-0.51), f32(0))
	testing.expect_value(t, game.st_flip_temporal_weight(0.51), f32(0))
	testing.expect(t, game.st_flip_temporal_weight(0.4) > game.st_flip_temporal_weight(-0.4))
	testing.expect(t, game.st_flip_temporal_weight(0.5) > game.st_flip_temporal_weight(0))
}

test_st_flip_residual_carryover_prevents_time_drift :: proc(t: ^testing.T) {
	residual: f32
	global_time: f32
	particle_time: f32
	deviates := [?]f32{-0.5, 0.25, 0.5, -0.125, 0.375, -0.4, 0.1, 0.45}
	for i in 0 ..< 256 {
		dt := f32(1.0 / 60.0) * (i % 5 == 0 ? f32(0.75) : f32(1))
		actual, next := game.st_flip_advance_time_sample(dt, residual, deviates[i % len(deviates)], 1)
		global_time += dt
		particle_time += actual
		residual = next
		testing.expect(t, math.abs((global_time - particle_time) - residual) < 0.0001)
		testing.expect(t, math.abs(residual) <= f32(1.0 / 60.0) + 0.0001)
	}
}

test_st_flip_settings_are_bounded_without_runtime_state :: proc(t: ^testing.T) {
	settings := game.st_flip_default_settings()
	settings.particle_count = 1
	settings.grid_height = 4_096
	settings.target_cfl = 100
	settings.flip_ratio = -1
	settings.jitter_strength = 2
	game.st_flip_validate_settings(&settings)
	testing.expect_value(t, settings.particle_count, game.ST_FLIP_MIN_PARTICLE_COUNT)
	testing.expect_value(t, settings.grid_height, game.ST_FLIP_MAX_GRID_HEIGHT)
	testing.expect_value(t, settings.target_cfl, f32(30))
	testing.expect_value(t, settings.flip_ratio, f32(0))
	testing.expect_value(t, settings.jitter_strength, f32(1))
	testing.expect(t, size_of(game.ST_Flip_Runtime_State) > 0)
}

test_st_flip_defaults_match_paper :: proc(t: ^testing.T) {
	settings := game.st_flip_default_settings()
	testing.expect_value(t, settings.flip_ratio, f32(0.98))
	testing.expect_value(t, settings.jitter_strength, f32(1))
	testing.expect_value(t, settings.phase_steepness, f32(0.5))
	testing.expect_value(t, settings.gravity, f32(0))
	testing.expect_value(t, settings.ink_dissipation, f32(0.12))
	runtime := game.st_flip_runtime_defaults()
	testing.expect_value(t, runtime.brush_size, f32(0.1))
	testing.expect_value(t, runtime.brush_strength, f32(7))
}

test_st_flip_resolution_presets_scale_grid_and_particles_together :: proc(t: ^testing.T) {
	settings := game.st_flip_default_settings()
	for i in 0 ..< len(game.ST_FLIP_RESOLUTION_NAMES) {
		game.st_flip_apply_resolution(&settings, i)
		testing.expect_value(t, settings.grid_height, game.ST_FLIP_RESOLUTION_GRID_HEIGHTS[i])
		testing.expect_value(t, settings.particle_count, game.ST_FLIP_RESOLUTION_PARTICLE_COUNTS[i])
		testing.expect_value(t, game.st_flip_resolution_index(settings.grid_height), i)
	}
}

test_st_flip_high_resolution_pressure_work_is_bounded :: proc(t: ^testing.T) {
	// 3416x2064 at 8x produces a 1906x1152 grid. The requested 80 passes must
	// be reduced enough to remain beneath one command-buffer work budget.
	effective := render_vk.st_flip_effective_pressure_iterations(80, 1906, 1152)
	cell_visits := u64(effective) * u64(1906) * u64(1152)
	testing.expect(t, effective >= 16)
	testing.expect(t, effective < 80)
	testing.expect(t, cell_visits <= render_vk.ST_FLIP_PRESSURE_CELL_VISIT_BUDGET)
	// Ordinary resolutions retain the authored iteration count.
	testing.expect_value(t, render_vk.st_flip_effective_pressure_iterations(80, 256, 144), u32(80))
}

test_st_flip_phase_field_uses_sqrt_saturation :: proc(t: ^testing.T) {
	testing.expect_value(t, game.st_flip_phase_from_mass(0, 1, 0.5), f32(0))
	testing.expect(t, math.abs(game.st_flip_phase_from_mass(0.125, 1, 0.5) - f32(0.5)) < 0.0001)
	testing.expect_value(t, game.st_flip_phase_from_mass(2, 1, 0.5), f32(1))
}
