package main

import engine "../../packages/engine"
import game "../../packages/game"
import render_vk "../../packages/render_vk"

import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"
import sdl "vendor:sdl3"

Bench_Config :: struct {
	particles: []u32,
	ranges: []f32,
	iterations: int,
	warmup: int,
	collisions: bool,
	species: u32,
	churn: bool,
}

parse_u32_list :: proc(value: string, allocator := context.allocator) -> []u32 {
	out := make([dynamic]u32, allocator)
	for token in strings.split(value, ",") {
		if parsed, ok := strconv.parse_uint(strings.trim_space(token)); ok && parsed > 0 && parsed <= uint(game.PARTICLE_LIFE_MAX_PARTICLE_COUNT) {
			append(&out, u32(parsed))
		}
	}
	return out[:]
}

parse_f32_list :: proc(value: string, allocator := context.allocator) -> []f32 {
	out := make([dynamic]f32, allocator)
	for token in strings.split(value, ",") {
		if parsed, ok := strconv.parse_f32(strings.trim_space(token)); ok && parsed > 0 {
			append(&out, parsed)
		}
	}
	return out[:]
}

parse_positive_int :: proc(value: string, fallback: int) -> int {
	if parsed, ok := strconv.parse_int(value); ok && parsed > 0 {
		return int(parsed)
	}
	return fallback
}

parse_config :: proc(args: []string) -> Bench_Config {
	config := Bench_Config {
		particles = []u32{10_000, 25_000, 50_000},
		ranges = []f32{0.02, 0.05, 0.1, 0.2, 0.4},
		iterations = 30,
		warmup = 5,
		collisions = true,
		species = 4,
	}
	for arg in args[1:] {
		if strings.has_prefix(arg, "--particles=") {
			if values := parse_u32_list(arg[len("--particles="):]); len(values) > 0 { config.particles = values }
		} else if strings.has_prefix(arg, "--ranges=") {
			if values := parse_f32_list(arg[len("--ranges="):]); len(values) > 0 { config.ranges = values }
		} else if strings.has_prefix(arg, "--iterations=") {
			config.iterations = parse_positive_int(arg[len("--iterations="):], config.iterations)
		} else if strings.has_prefix(arg, "--warmup=") {
			config.warmup = parse_positive_int(arg[len("--warmup="):], config.warmup)
		} else if arg == "--no-collisions" {
			config.collisions = false
		} else if strings.has_prefix(arg, "--species=") {
			if parsed, ok := strconv.parse_uint(arg[len("--species="):]); ok {
				config.species = max(min(u32(parsed), game.PARTICLE_LIFE_MAX_SPECIES), 1)
			}
		} else if arg == "--churn" {
			config.churn = true
		}
	}
	return config
}

run_churn :: proc(vk_ctx: ^engine.Vk_Context, config: Bench_Config) -> bool {
	sim: game.Particle_Life_Simulation
	game.particle_life_init(&sim, 1280, 720)
	defer render_vk.particle_life_destroy(&sim, vk_ctx)
	sim.settings.particle_count = config.particles[0]
	sim.settings.species_count = config.species
	sim.settings.force_generator = 0
	sim.settings.collision_enabled = config.collisions
	sim.settings.analysis_enabled = false
	sim.settings.trails_enabled = false
	sim.settings.max_distance = config.ranges[0]
	for _ in 0 ..< config.warmup + 2 {
		if !submit_step(&sim, vk_ctx) { return false }
	}
	initial_grid_buffer := sim.gpu.grid_heads_buffer.handle
	rebuilds := 0
	samples := make([]f64, config.iterations)
	for i in 0 ..< config.iterations {
		sim.settings.max_distance = config.ranges[i % len(config.ranges)]
		start := time.tick_now()
		if !submit_step(&sim, vk_ctx) { return false }
		samples[i] = time.duration_seconds(time.tick_since(start)) * 1000.0
		if sim.gpu.grid_heads_buffer.handle != initial_grid_buffer {
			rebuilds += 1
			initial_grid_buffer = sim.gpu.grid_heads_buffer.handle
		}
	}
	sort_f64(samples)
	total: f64
	for sample in samples { total += sample }
	fmt.println("churn_particles,species,collisions,ranges,iterations,resource_rebuilds,mean_ms,p50_ms,p95_ms,max_ms")
	fmt.printf("%d,%d,%t,%d,%d,%d,%.6f,%.6f,%.6f,%.6f\n", config.particles[0], config.species, config.collisions, len(config.ranges), config.iterations, rebuilds, total / f64(config.iterations), percentile(samples, 0.5), percentile(samples, 0.95), samples[len(samples) - 1])
	return true
}

submit_step :: proc(sim: ^game.Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	cmd, ok := engine.vk_begin_upload_commands(vk_ctx)
	if !ok { return false }
	render_vk.particle_life_gpu_step(sim, vk_ctx, cmd, 1.0 / 60.0)
	return engine.vk_submit_upload_commands(vk_ctx)
}

percentile :: proc(sorted: []f64, fraction: f64) -> f64 {
	if len(sorted) == 0 { return 0 }
	index := int(math.round(fraction * f64(len(sorted) - 1)))
	return sorted[max(min(index, len(sorted) - 1), 0)]
}

run_case :: proc(vk_ctx: ^engine.Vk_Context, particle_count, species: u32, influence_range: f32, collisions: bool, warmup, iterations: int) -> bool {
	sim: game.Particle_Life_Simulation
	game.particle_life_init(&sim, 1280, 720)
	defer render_vk.particle_life_destroy(&sim, vk_ctx)
	sim.settings.particle_count = particle_count
	sim.settings.species_count = species
	sim.settings.force_generator = 0 // Random
	sim.settings.max_distance = influence_range
	sim.settings.collision_enabled = collisions
	sim.settings.analysis_enabled = false
	sim.settings.trails_enabled = false

	// The first submissions compile/create resources and initialize particles;
	// keep them outside the steady-state sample.
	for _ in 0 ..< warmup + 2 {
		if !submit_step(&sim, vk_ctx) { return false }
	}

	samples := make([]f64, iterations)
	for i in 0 ..< iterations {
		start := time.tick_now()
		if !submit_step(&sim, vk_ctx) { return false }
		samples[i] = time.duration_seconds(time.tick_since(start)) * 1000.0
	}
	sort_f64(samples)
	total: f64
	for sample in samples { total += sample }
	grid_w, grid_h := game.particle_life_target_grid_dimensions(sim.settings, game.particle_life_world_size(&sim))
	radius := game.particle_life_target_neighbor_radius_cells(sim.settings, grid_w, grid_h, game.particle_life_world_size(&sim))
	fmt.printf("%d,%d,random,%.6f,%t,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f\n", particle_count, species, influence_range, collisions, grid_w, grid_h, radius, iterations, total / f64(iterations), percentile(samples, 0.5), percentile(samples, 0.95), samples[len(samples) - 1])
	return true
}

sort_f64 :: proc(values: []f64) {
	for i in 1 ..< len(values) {
		value := values[i]
		j := i
		for j > 0 && values[j - 1] > value {
			values[j] = values[j - 1]
			j -= 1
		}
		values[j] = value
	}
}

main :: proc() {
	config := parse_config(os.args)
	if !sdl.Init({.VIDEO}) {
		fmt.eprintf("particle-life-perf: SDL init failed: %s\n", sdl.GetError())
		os.exit(1)
	}
	defer sdl.Quit()
	window := sdl.CreateWindow("Particle Life perf", 1280, 720, sdl.WINDOW_VULKAN | sdl.WINDOW_HIDDEN)
	if window == nil {
		fmt.eprintf("particle-life-perf: window creation failed: %s\n", sdl.GetError())
		os.exit(1)
	}
	defer sdl.DestroyWindow(window)

	vk_ctx: engine.Vk_Context
	if !engine.vk_context_init(&vk_ctx, window, 1280, 720, 0.70) {
		fmt.eprintln("particle-life-perf: Vulkan initialization failed")
		os.exit(1)
	}
	defer engine.vk_context_destroy(&vk_ctx)
	if config.churn {
		if !run_churn(&vk_ctx, config) { os.exit(1) }
		return
	}
	fmt.println("particles,species,force_grid,influence_range,collisions,grid_width,grid_height,neighbor_radius,iterations,mean_ms,p50_ms,p95_ms,max_ms")
	for particle_count in config.particles {
		for influence_range in config.ranges {
			if !run_case(&vk_ctx, particle_count, config.species, influence_range, config.collisions, config.warmup, config.iterations) {
				fmt.eprintln("particle-life-perf: benchmark submission failed")
				os.exit(1)
			}
		}
	}
}
