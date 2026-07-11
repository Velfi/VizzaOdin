package app

import uifw "../ui"
import engine "../engine"

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sync"
import "core:time"
import sdl "vendor:sdl3"

Render_Worker_State :: struct {
	using product: Product_Context,
	vulkan_window: ^sdl.Window,
	initial_pixel_width: i32,
	initial_pixel_height: i32,
	screenshot: ^engine.Screenshot_State,
	theme_preview: bool,
	text_input_requested: bool,
	running: bool,
}

Render_Worker_Runtime :: struct {
	vk_ctx: engine.Vk_Context,
	vk_ok: bool,
	render_backend: Render_Backend,
	video_recorder: Video_Recorder_State,
	sim: Gray_Scott_Simulation,
	preview_gray_scott: Gray_Scott_Simulation,
	particle_life: Particle_Life_Simulation,
	preview_particle_life: Particle_Life_Simulation,
	vectors_gpu: Vectors_Gpu_State,
	preview_vectors_gpu: Vectors_Gpu_State,
	moire_gpu: Moire_Gpu_State,
	preview_moire_gpu: Moire_Gpu_State,
	primordial_gpu: Primordial_Gpu_State,
	preview_primordial_gpu: Primordial_Gpu_State,
	pellets_gpu: Pellets_Gpu_State,
	preview_pellets_gpu: Pellets_Gpu_State,
	flow_gpu: Flow_Gpu_State,
	preview_flow_gpu: Flow_Gpu_State,
	slime_gpu: Slime_Gpu_State,
	voronoi_gpu: Voronoi_Gpu_State,
	preview_slime_gpu: Slime_Gpu_State,
	preview_voronoi_gpu: Voronoi_Gpu_State,
	gui: uifw.Gui_Context,
	app_ui: App_Ui_State,
	last_tick: time.Tick,
	profiler: Frame_Profiler,
	debug_frame_log_count: u32,
	initialized: bool,
}

PROFILE_REPORT_INTERVAL :: u64(120)

Frame_Profiler :: struct {
	frames: u64,
	sim_sum: f64,
	sim_max: f64,
	ui_sum: f64,
	ui_max: f64,
	render_sum: f64,
	render_max: f64,
	submit_sum: f64,
	submit_max: f64,
	screenshot_sum: f64,
	screenshot_max: f64,
	screenshot_captures: u64,
	ui_build_sum: f64,
	ui_build_max: f64,
	ui_overlay_sum: f64,
	ui_overlay_max: f64,
	text_width_calls: u64,
	text_width_cache_hits: u64,
	text_width_seconds: f64,
	text_shape_calls: u64,
	text_shape_glyphs: u64,
	text_shape_seconds: f64,
	text_wrap_calls: u64,
	text_wrap_seconds: f64,
}

render_worker_entry :: proc "c" (data: rawptr) -> c.int {
	context = runtime.default_context()
	state := cast(^Render_Worker_State)data
	render_worker_run(state)
	return 0
}

render_worker_run :: proc(state: ^Render_Worker_State) {
	runtime := new(Render_Worker_Runtime)
	defer free(runtime)
	if !render_worker_runtime_init(state, runtime) {
		return
	}
	defer render_worker_runtime_shutdown(state, runtime)

	state.running = true
	for state.running {
		cmd: Ui_To_Render_Command
		if !engine.queue_pop_blocking(state.ui_to_render, &cmd) {
			break
		}
		render_worker_handle_command(state, runtime, cmd)
		// This worker has its own thread-local context and temporary arena. Each
		// command is fully consumed here, so no temporary data may cross this
		// boundary into the next command/frame.
		free_all(context.temp_allocator)
	}
}

render_worker_pump :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime) {
	if !runtime.initialized {
		if !render_worker_runtime_init(state, runtime) {
			return
		}
		state.running = true
	}

	for {
		cmd: Ui_To_Render_Command
		if !engine.queue_try_pop(state.ui_to_render, &cmd) {
			break
		}
		render_worker_handle_command(state, runtime, cmd)
	}
}

render_worker_runtime_init :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime) -> bool {
	runtime^ = {}
	width := state.initial_pixel_width
	height := state.initial_pixel_height
	if width <= 0 || height <= 0 {
		width = state.settings.window_width
		height = state.settings.window_height
	}

	vk_ok := engine.vk_context_init(&runtime.vk_ctx, state.vulkan_window, width, height, state.settings.gpu_memory_ceiling_fraction, state.screenshot != nil)
	runtime.vk_ok = vk_ok
	engine.log_info("render_worker: vk_ok=", vk_ok, " pixel_size=", width, "x", height, " capture=", state.screenshot != nil)

	if vk_ok {
		if !render_backend_init(&runtime.render_backend, &runtime.vk_ctx) {
			runtime.vk_ok = false
		}
	}

	gray_scott_init(&runtime.sim, width, height)
	gray_scott_init(&runtime.preview_gray_scott, 256, 144)
	particle_life_init(&runtime.particle_life, width, height)
	particle_life_init(&runtime.preview_particle_life, 192, 144)
	uifw.gui_init(&runtime.gui)
	app_ui_init(&runtime.app_ui, state.settings, state.theme_preview)

	ready: Render_To_Ui_Message
	ready.kind = .Ready
	ready.device_info = runtime.vk_ctx.caps
	if runtime.vk_ok {
		write_fixed_string(ready.text[:], "Render worker initialized Vulkan device and swapchain")
	} else {
		write_fixed_string(ready.text[:], "Render worker started without a complete Vulkan render backend")
	}
	_ = engine.queue_try_push(state.render_to_ui, ready)

	runtime.last_tick = time.tick_now()
	runtime.initialized = true
	return true
}

render_worker_runtime_shutdown :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime) {
	if !runtime.initialized {
		engine.log_info("shutdown: render worker runtime skipped uninitialized")
		return
	}
	total_start := time.tick_now()
	engine.log_info("shutdown: render worker runtime begin")
	step_start := time.tick_now()
	_ = engine.vk_wait_for_frame_fences(&runtime.vk_ctx)
	engine.log_info("shutdown: vk frame fences wait ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	video_recorder_stop(&runtime.video_recorder)
	engine.log_info("shutdown: video recorder stop ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	render_backend_destroy(&runtime.render_backend, &runtime.vk_ctx)
	engine.log_info("shutdown: render backend destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	vectors_gpu_destroy(&runtime.vectors_gpu, &runtime.vk_ctx)
	engine.log_info("shutdown: vectors destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	vectors_gpu_destroy(&runtime.preview_vectors_gpu, &runtime.vk_ctx)
	engine.log_info("shutdown: preview vectors destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	moire_gpu_destroy(&runtime.moire_gpu, &runtime.vk_ctx)
	engine.log_info("shutdown: moire destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	moire_gpu_destroy(&runtime.preview_moire_gpu, &runtime.vk_ctx)
	engine.log_info("shutdown: preview moire destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	primordial_gpu_destroy(&runtime.primordial_gpu, &runtime.vk_ctx)
	engine.log_info("shutdown: primordial destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	primordial_gpu_destroy(&runtime.preview_primordial_gpu, &runtime.vk_ctx)
	engine.log_info("shutdown: preview primordial destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	pellets_gpu_destroy(&runtime.pellets_gpu, &runtime.vk_ctx)
	engine.log_info("shutdown: pellets destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	pellets_gpu_destroy(&runtime.preview_pellets_gpu, &runtime.vk_ctx)
	engine.log_info("shutdown: preview pellets destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	flow_gpu_destroy(&runtime.flow_gpu, &runtime.vk_ctx)
	engine.log_info("shutdown: flow destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	flow_gpu_destroy(&runtime.preview_flow_gpu, &runtime.vk_ctx)
	engine.log_info("shutdown: preview flow destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	slime_gpu_destroy(&runtime.slime_gpu, &runtime.vk_ctx)
	engine.log_info("shutdown: slime destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	voronoi_gpu_destroy(&runtime.voronoi_gpu, &runtime.vk_ctx)
	engine.log_info("shutdown: voronoi destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	slime_gpu_destroy(&runtime.preview_slime_gpu, &runtime.vk_ctx)
	engine.log_info("shutdown: preview slime destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	voronoi_gpu_destroy(&runtime.preview_voronoi_gpu, &runtime.vk_ctx)
	engine.log_info("shutdown: preview voronoi destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	gray_scott_destroy(&runtime.sim, &runtime.vk_ctx)
	engine.log_info("shutdown: gray scott destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	gray_scott_destroy(&runtime.preview_gray_scott, &runtime.vk_ctx)
	engine.log_info("shutdown: preview gray scott destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	particle_life_destroy(&runtime.particle_life, &runtime.vk_ctx)
	engine.log_info("shutdown: particle life destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	particle_life_destroy(&runtime.preview_particle_life, &runtime.vk_ctx)
	engine.log_info("shutdown: preview particle life destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	uifw.gui_destroy(&runtime.gui)
	engine.log_info("shutdown: gui destroy ms=", shutdown_elapsed_ms(step_start))
	step_start = time.tick_now()
	engine.vk_context_destroy(&runtime.vk_ctx)
	engine.log_info("shutdown: vk context destroy ms=", shutdown_elapsed_ms(step_start))
	runtime^ = {}
	engine.log_info("shutdown: render worker runtime total ms=", shutdown_elapsed_ms(total_start))

	done: Render_To_Ui_Message
	done.kind = .Shutdown_Complete
	write_fixed_string(done.text[:], "Render worker stopped")
	_ = engine.queue_try_push(state.render_to_ui, done)
	_ = state
}

render_worker_apply_main_menu_palette_after_navigation :: proc(runtime: ^Render_Worker_Runtime, previous_mode: App_Mode) {
	if runtime == nil || previous_mode != .Main_Menu || !app_ui_live_preview_supported(runtime.app_ui.mode) {
		return
	}
	palette_name := main_menu_backdrop_current_palette_name(&runtime.render_backend.main_menu_backdrop)
	_ = render_main_menu_apply_palette_to_mode(&runtime.app_ui, &runtime.sim.settings, &runtime.particle_life.settings, runtime.app_ui.mode, palette_name)
}

render_worker_remaining_kind_from_app_mode :: proc(mode: App_Mode, out: ^Remaining_Sim_Kind) -> bool {
	#partial switch mode {
	case .Slime_Mold:
		out^ = .Slime_Mold
	case .Flow_Field:
		out^ = .Flow_Field
	case .Pellets:
		out^ = .Pellets
	case .Voronoi_CA:
		out^ = .Voronoi_CA
	case .Moire:
		out^ = .Moire
	case .Vectors:
		out^ = .Vectors
	case .Primordial:
		out^ = .Primordial
	case:
		return false
	}
	return true
}

render_worker_remaining_state_from_app_mode :: proc(runtime: ^Render_Worker_Runtime, mode: App_Mode) -> ^Remaining_Sim_State {
	if runtime == nil {
		return nil
	}
	#partial switch mode {
	case .Slime_Mold:
		return &runtime.app_ui.slime_mold
	case .Flow_Field:
		return &runtime.app_ui.flow_field
	case .Pellets:
		return &runtime.app_ui.pellets
	case .Voronoi_CA:
		return &runtime.app_ui.voronoi_ca
	case .Moire:
		return &runtime.app_ui.moire
	case .Vectors:
		return &runtime.app_ui.vectors
	case .Primordial:
		return &runtime.app_ui.primordial
	case:
		return nil
	}
	return nil
}

render_worker_mark_mode_dirty :: proc(runtime: ^Render_Worker_Runtime, mode: App_Mode) {
	#partial switch mode {
	case .Primordial:
		runtime.primordial_gpu.ready = false
	case .Pellets:
		runtime.pellets_gpu.ready = false
	case .Voronoi_CA:
		runtime.voronoi_gpu.needs_rebuild = true
	case .Slime_Mold:
		runtime.slime_gpu.needs_reset = true
	case:
	}
}

render_worker_hide_ui :: proc(runtime: ^Render_Worker_Runtime) {
	if runtime == nil {
		return
	}
	app_ui_hide_unfocused_simulation_ui(&runtime.app_ui)
	runtime.app_ui.simulation_shell.force_hidden = true
	runtime.app_ui.simulation_shell.idle_seconds = f32(max(runtime.app_ui.settings.auto_hide_delay, 0)) / 1000.0
}

render_worker_apply_builtin_preset :: proc(runtime: ^Render_Worker_Runtime, mode: App_Mode, index: int) -> bool {
	if runtime == nil {
		return false
	}
	#partial switch mode {
	case .Gray_Scott:
		gray_scott_apply_builtin_preset(&runtime.sim, index)
	case .Particle_Life:
		particle_life_apply_builtin_preset(&runtime.particle_life, index)
	case:
		kind: Remaining_Sim_Kind
		if !render_worker_remaining_kind_from_app_mode(mode, &kind) {
			return false
		}
		remaining := render_worker_remaining_state_from_app_mode(runtime, mode)
		if remaining == nil {
			return false
		}
		remaining_sim_apply_builtin_preset(remaining, kind, index)
		render_worker_mark_mode_dirty(runtime, mode)
	}
	return true
}

render_worker_get_color_scheme_reversed :: proc(runtime: ^Render_Worker_Runtime, mode: App_Mode, out: ^bool) -> bool {
	if runtime == nil || out == nil {
		return false
	}
	#partial switch mode {
	case .Slime_Mold:
		out^ = runtime.app_ui.slime_mold.slime.color_scheme_reversed
	case .Gray_Scott:
		out^ = runtime.sim.settings.color_scheme_reversed
	case .Particle_Life:
		out^ = runtime.particle_life.settings.color_scheme_reversed
	case .Flow_Field:
		out^ = runtime.app_ui.flow_field.flow.color_scheme_reversed
	case .Pellets:
		out^ = runtime.app_ui.pellets.pellets.color_scheme_reversed
	case .Voronoi_CA:
		out^ = runtime.app_ui.voronoi_ca.voronoi.color_scheme_reversed
	case .Moire:
		out^ = runtime.app_ui.moire.moire.color_scheme_reversed
	case .Vectors:
		out^ = runtime.app_ui.vectors.vectors.color_scheme_reversed
	case .Primordial:
		out^ = runtime.app_ui.primordial.primordial.color_scheme_reversed
	case:
		return false
	}
	return true
}

render_worker_set_color_scheme_reversed :: proc(runtime: ^Render_Worker_Runtime, mode: App_Mode, reversed: bool) -> bool {
	#partial switch mode {
	case .Slime_Mold:
		runtime.app_ui.slime_mold.slime.color_scheme_reversed = reversed
	case .Gray_Scott:
		runtime.sim.settings.color_scheme_reversed = reversed
	case .Particle_Life:
		runtime.particle_life.settings.color_scheme_reversed = reversed
	case .Flow_Field:
		runtime.app_ui.flow_field.flow.color_scheme_reversed = reversed
	case .Pellets:
		runtime.app_ui.pellets.pellets.color_scheme_reversed = reversed
	case .Voronoi_CA:
		runtime.app_ui.voronoi_ca.voronoi.color_scheme_reversed = reversed
	case .Moire:
		runtime.app_ui.moire.moire.color_scheme_reversed = reversed
	case .Vectors:
		runtime.app_ui.vectors.vectors.color_scheme_reversed = reversed
	case .Primordial:
		runtime.app_ui.primordial.primordial.color_scheme_reversed = reversed
	case:
		return false
	}
	return true
}

render_worker_set_color_scheme :: proc(runtime: ^Render_Worker_Runtime, mode: App_Mode, name: string, reversed: bool, reversed_set: bool) -> bool {
	if runtime == nil || len(name) == 0 {
		return false
	}
	if _, ok := color_scheme_load(name); !ok {
		return false
	}
	previous_reversed := false
	if !reversed_set {
		if !render_worker_get_color_scheme_reversed(runtime, mode, &previous_reversed) {
			return false
		}
	}
	if !render_main_menu_apply_palette_to_mode(&runtime.app_ui, &runtime.sim.settings, &runtime.particle_life.settings, mode, name) {
		return false
	}
	if reversed_set {
		if !render_worker_set_color_scheme_reversed(runtime, mode, reversed) {
			return false
		}
	} else {
		if !render_worker_set_color_scheme_reversed(runtime, mode, previous_reversed) {
			return false
		}
	}
	render_worker_mark_mode_dirty(runtime, mode)
	return true
}

render_worker_profile_record :: proc(runtime: ^Render_Worker_Runtime, frame_index: u64, sim_seconds, ui_seconds, render_seconds: f64) {
	profile := &runtime.profiler
	profile.frames += 1
	render_worker_profile_accum(&profile.sim_sum, &profile.sim_max, sim_seconds)
	render_worker_profile_accum(&profile.ui_sum, &profile.ui_max, ui_seconds)
	render_worker_profile_accum(&profile.render_sum, &profile.render_max, render_seconds)
	render_worker_profile_accum(&profile.submit_sum, &profile.submit_max, runtime.render_backend.last_submit_seconds)
	render_worker_profile_accum(&profile.screenshot_sum, &profile.screenshot_max, runtime.render_backend.last_screenshot_seconds)
	if runtime.render_backend.last_screenshot_captured {
		profile.screenshot_captures += 1
	}
	render_worker_profile_accum(&profile.ui_build_sum, &profile.ui_build_max, runtime.render_backend.last_ui_build_seconds)
	render_worker_profile_accum(&profile.ui_overlay_sum, &profile.ui_overlay_max, runtime.render_backend.last_ui_overlay_seconds)

	text := uifw.gui_profile_snapshot()
	profile.text_width_calls += text.width_calls
	profile.text_width_cache_hits += text.width_cache_hits
	profile.text_width_seconds += text.width_seconds
	profile.text_shape_calls += text.shape_calls
	profile.text_shape_glyphs += text.shape_glyphs
	profile.text_shape_seconds += text.shape_seconds
	profile.text_wrap_calls += text.wrap_calls
	profile.text_wrap_seconds += text.wrap_seconds

	if profile.frames >= PROFILE_REPORT_INTERVAL {
		frames := f64(profile.frames)
		engine.log_debug(
			"profile: frame=", frame_index,
			" avg_ms sim=", render_worker_profile_ms(profile.sim_sum / frames),
			" ui=", render_worker_profile_ms(profile.ui_sum / frames),
			" render=", render_worker_profile_ms(profile.render_sum / frames),
			" submit=", render_worker_profile_ms(profile.submit_sum / frames),
			" screenshot=", render_worker_profile_ms(profile.screenshot_sum / frames),
			" ui_build=", render_worker_profile_ms(profile.ui_build_sum / frames),
			" ui_overlay=", render_worker_profile_ms(profile.ui_overlay_sum / frames),
			" max_ms sim=", render_worker_profile_ms(profile.sim_max),
			" ui=", render_worker_profile_ms(profile.ui_max),
			" render=", render_worker_profile_ms(profile.render_max),
			" submit=", render_worker_profile_ms(profile.submit_max),
			" screenshot=", render_worker_profile_ms(profile.screenshot_max),
			" screenshot_captures=", profile.screenshot_captures,
			" text width_calls=", profile.text_width_calls,
			" width_cache_hits=", profile.text_width_cache_hits,
			" width_ms=", render_worker_profile_ms(profile.text_width_seconds),
			" shape_calls=", profile.text_shape_calls,
			" shape_glyphs=", profile.text_shape_glyphs,
			" shape_ms=", render_worker_profile_ms(profile.text_shape_seconds),
			" wrap_calls=", profile.text_wrap_calls,
			" wrap_ms=", render_worker_profile_ms(profile.text_wrap_seconds),
		)
		profile^ = {}
	}
}

render_worker_profile_accum :: proc(sum, max_value: ^f64, value: f64) {
	sum^ += value
	if value > max_value^ {
		max_value^ = value
	}
}

render_worker_profile_ms :: proc(seconds: f64) -> f64 {
	return seconds * 1000.0
}

render_worker_publish_stats :: proc(state: ^Render_Worker_State, frame_index: u64, dt: f32, app_mode: App_Mode, sim: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation, ui: ^App_Ui_State, backend: ^Render_Backend, gui: ^uifw.Gui_Context, sim_seconds, ui_seconds, render_seconds: f64) {
	msg: Render_To_Ui_Message
	msg.kind = .Frame_Stats
	msg.frame_index = frame_index
	msg.frame_ms = dt * 1000
	msg.app_mode = app_mode
	msg.sim_ms = f32(render_worker_profile_ms(sim_seconds))
	msg.ui_ms = f32(render_worker_profile_ms(ui_seconds))
	msg.render_ms = f32(render_worker_profile_ms(render_seconds))
	text := uifw.gui_profile_snapshot()
	msg.text_width_calls = text.width_calls
	msg.text_width_cache_hits = text.width_cache_hits
	msg.text_width_ms = f32(render_worker_profile_ms(text.width_seconds))
	msg.text_shape_calls = text.shape_calls
	msg.text_shape_glyphs = text.shape_glyphs
	msg.text_shape_ms = f32(render_worker_profile_ms(text.shape_seconds))
	msg.text_wrap_calls = text.wrap_calls
	msg.text_wrap_ms = f32(render_worker_profile_ms(text.wrap_seconds))
	if gui != nil {
		msg.gui_command_count = u32(len(gui.commands))
	}
	if sim != nil {
		msg.gray_scott_camera_x = sim.runtime.camera_x
		msg.gray_scott_camera_y = sim.runtime.camera_y
		msg.gray_scott_camera_zoom = sim.runtime.camera_zoom
		msg.gray_scott_paused = sim.settings.paused
	}
	if particle_life != nil {
		msg.particle_life_camera_x = particle_life.runtime.camera_x
		msg.particle_life_camera_y = particle_life.runtime.camera_y
		msg.particle_life_camera_zoom = particle_life.runtime.camera_zoom
		msg.particle_life_ready = particle_life.gpu.ready
		msg.particle_life_paused = particle_life.settings.paused
		msg.particle_life_frame_index = particle_life.runtime.frame_index
		msg.particle_life_particle_count = particle_life.gpu.uploaded_particle_count
		msg.particle_life_requested_particle_count = particle_life_target_particle_count(particle_life.settings)
		if msg.particle_life_particle_count == 0 {
			msg.particle_life_particle_count = msg.particle_life_requested_particle_count
		}
		msg.particle_life_species_count = particle_life.gpu.uploaded_species_count
		msg.particle_life_requested_species_count = particle_life_target_species_count(particle_life.settings)
		if msg.particle_life_species_count == 0 {
			msg.particle_life_species_count = msg.particle_life_requested_species_count
		}
		msg.particle_life_trails_enabled = particle_life.settings.trails_enabled
		msg.particle_life_infinite_tiles_enabled = particle_life.settings.infinite_tiles_enabled
	}
	if ui != nil {
		msg.gray_scott_controls_visible = ui.simulation_shell.controls_visible
		msg.particle_life_controls_visible = ui.simulation_shell.controls_visible
		msg.system_cursor_hidden = app_ui_system_cursor_hidden(ui)
	}
	if backend != nil {
		msg.gpu_profiling_supported = backend.gpu_profiling_supported
		msg.gpu_profiling_enabled = backend.gpu_profiling_enabled
		msg.gpu_simulation_step_ms = f32(backend.last_gpu_simulation_step_ms)
		msg.gpu_simulation_present_ms = f32(backend.last_gpu_simulation_present_ms)
		msg.gpu_ui_overlay_ms = f32(backend.last_gpu_ui_overlay_ms)
		msg.gpu_frame_total_ms = f32(backend.last_gpu_frame_total_ms)
		msg.submit_ms = f32(render_worker_profile_ms(backend.last_submit_seconds))
		msg.screenshot_ms = f32(render_worker_profile_ms(backend.last_screenshot_seconds))
		msg.screenshot_captured = backend.last_screenshot_captured
		msg.ui_build_ms = f32(render_worker_profile_ms(backend.last_ui_build_seconds))
		msg.ui_overlay_ms = f32(render_worker_profile_ms(backend.last_ui_overlay_seconds))
		msg.ui_vertex_count = backend.ui.vertex_count
		msg.ui_batch_count = backend.ui.batch_count
		msg.ui_clear_rect_count = backend.ui.clear_rect_count
		msg.main_menu_preview_visible_slot_count = backend.last_main_menu_preview_visible_slot_count
		msg.main_menu_preview_warmed_mode_count = backend.last_main_menu_preview_warmed_mode_count
		msg.main_menu_preview_fallback_fill_count = backend.last_main_menu_preview_fallback_fill_count
		msg.main_menu_preview_skipped_present_count = backend.last_main_menu_preview_skipped_present_count
		msg.cpu_wait_fence_ms = f32(backend.last_cpu_wait_fence_ms)
		msg.cpu_acquire_ms = f32(backend.last_cpu_acquire_ms)
		msg.cpu_command_begin_ms = f32(backend.last_cpu_command_begin_ms)
		msg.cpu_end_command_ms = f32(backend.last_cpu_end_command_ms)
		msg.cpu_queue_submit_ms = f32(backend.last_cpu_queue_submit_ms)
		msg.cpu_queue_present_ms = f32(backend.last_cpu_queue_present_ms)
		write_fixed_string(msg.present_mode[:], backend.present_mode)
		msg.command_render_pass_count = backend.last_command_render_pass_count
		msg.command_compute_dispatch_count = backend.last_command_compute_dispatch_count
		msg.command_draw_count = backend.last_command_draw_count
		msg.command_pipeline_bind_count = backend.last_command_pipeline_bind_count
		msg.command_descriptor_bind_count = backend.last_command_descriptor_bind_count
		msg.command_pipeline_barrier_count = backend.last_command_pipeline_barrier_count
		msg.command_transfer_copy_count = backend.last_command_transfer_copy_count
		msg.command_ui_batch_count = backend.last_command_ui_batch_count
		msg.command_backdrop_blur_pass_count = backend.last_command_backdrop_blur_pass_count
	}
	if dt > 0 {
		msg.fps = 1 / dt
	}
	_ = engine.queue_try_push(state.render_to_ui, msg)
}

render_worker_publish_error :: proc(state: ^Render_Worker_State, text: string) {
	msg: Render_To_Ui_Message
	msg.kind = .Error
	write_fixed_string(msg.text[:], text)
	_ = engine.queue_try_push(state.render_to_ui, msg)
}

render_worker_publish_preset_result :: proc(state: ^Render_Worker_State, ok: bool, text: string) {
	msg: Render_To_Ui_Message
	msg.kind = .Preset_Result
	msg.preset_ok = ok
	write_fixed_string(msg.text[:], text)
	_ = engine.queue_try_push(state.render_to_ui, msg)
}

render_worker_preset_path :: proc(state: ^Render_Worker_State, preset_name_buf: []u8, ensure_directory := true) -> string {
	name := fixed_string(preset_name_buf)
	if len(name) == 0 {
		name = "preset.toml"
	}
	if slash := strings.index(name, "/"); ensure_directory && slash >= 0 {
		_ = os.make_directory_all(fmt.tprintf("%s/%s", state.settings.preset_directory, name[:slash]))
	}
	return fmt.tprintf("%s/%s", state.settings.preset_directory, name)
}
