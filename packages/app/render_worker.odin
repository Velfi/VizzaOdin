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

render_worker_handle_command :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, cmd: Ui_To_Render_Command) {
	#partial switch cmd.kind {
	case .Close:
		video_recorder_stop(&runtime.video_recorder)
		state.running = false
	case .Resize:
		if video_recorder_is_recording(&runtime.video_recorder) {
			video_recorder_stop(&runtime.video_recorder)
			app_ui_video_recording_apply_command_state(&runtime.app_ui, .Idle)
			render_worker_publish_preset_result(state, true, "Stopped video recording because the window was resized")
		}
		gray_scott_resize(&runtime.sim, cmd.width, cmd.height)
		particle_life_resize(&runtime.particle_life, cmd.width, cmd.height)
		vectors_gpu_destroy(&runtime.vectors_gpu, &runtime.vk_ctx)
		vectors_gpu_destroy(&runtime.preview_vectors_gpu, &runtime.vk_ctx)
		moire_gpu_destroy(&runtime.moire_gpu, &runtime.vk_ctx)
		moire_gpu_destroy(&runtime.preview_moire_gpu, &runtime.vk_ctx)
		primordial_gpu_destroy(&runtime.primordial_gpu, &runtime.vk_ctx)
		primordial_gpu_destroy(&runtime.preview_primordial_gpu, &runtime.vk_ctx)
		pellets_gpu_destroy(&runtime.pellets_gpu, &runtime.vk_ctx)
		pellets_gpu_destroy(&runtime.preview_pellets_gpu, &runtime.vk_ctx)
		flow_gpu_destroy(&runtime.flow_gpu, &runtime.vk_ctx)
		flow_gpu_destroy(&runtime.preview_flow_gpu, &runtime.vk_ctx)
		slime_gpu_destroy(&runtime.slime_gpu, &runtime.vk_ctx)
		voronoi_gpu_destroy(&runtime.voronoi_gpu, &runtime.vk_ctx)
		slime_gpu_destroy(&runtime.preview_slime_gpu, &runtime.vk_ctx)
		voronoi_gpu_destroy(&runtime.preview_voronoi_gpu, &runtime.vk_ctx)
		gray_scott_resize(&runtime.preview_gray_scott, runtime.preview_gray_scott.gpu.width, runtime.preview_gray_scott.gpu.height)
		runtime.preview_particle_life.gpu.ready = false
		if runtime.vk_ok {
			if !engine.vk_recreate_swapchain(&runtime.vk_ctx, cmd.width, cmd.height) {
				render_worker_publish_error(state, "Failed to recreate Vulkan swapchain after resize")
			} else {
				render_backend_destroy(&runtime.render_backend, &runtime.vk_ctx)
				vectors_gpu_destroy(&runtime.vectors_gpu, &runtime.vk_ctx)
				vectors_gpu_destroy(&runtime.preview_vectors_gpu, &runtime.vk_ctx)
				moire_gpu_destroy(&runtime.moire_gpu, &runtime.vk_ctx)
				moire_gpu_destroy(&runtime.preview_moire_gpu, &runtime.vk_ctx)
				primordial_gpu_destroy(&runtime.primordial_gpu, &runtime.vk_ctx)
				primordial_gpu_destroy(&runtime.preview_primordial_gpu, &runtime.vk_ctx)
				pellets_gpu_destroy(&runtime.pellets_gpu, &runtime.vk_ctx)
				pellets_gpu_destroy(&runtime.preview_pellets_gpu, &runtime.vk_ctx)
				flow_gpu_destroy(&runtime.flow_gpu, &runtime.vk_ctx)
				flow_gpu_destroy(&runtime.preview_flow_gpu, &runtime.vk_ctx)
				slime_gpu_destroy(&runtime.slime_gpu, &runtime.vk_ctx)
				voronoi_gpu_destroy(&runtime.voronoi_gpu, &runtime.vk_ctx)
				slime_gpu_destroy(&runtime.preview_slime_gpu, &runtime.vk_ctx)
				voronoi_gpu_destroy(&runtime.preview_voronoi_gpu, &runtime.vk_ctx)
				gray_scott_resize(&runtime.preview_gray_scott, runtime.preview_gray_scott.gpu.width, runtime.preview_gray_scott.gpu.height)
				runtime.preview_particle_life.gpu.ready = false
				if !render_backend_init(&runtime.render_backend, &runtime.vk_ctx) {
					runtime.vk_ok = false
					render_worker_publish_error(state, "Failed to recreate render backend after resize")
				}
			}
		}
	case .Frame_Input:
		if runtime.vk_ok && runtime.vk_ctx.needs_swapchain_recreate {
			if !engine.vk_recreate_swapchain(&runtime.vk_ctx, cmd.frame_input.window_width, cmd.frame_input.window_height) {
				render_worker_publish_error(state, "Failed to recreate Vulkan swapchain")
			} else {
				render_backend_destroy(&runtime.render_backend, &runtime.vk_ctx)
				vectors_gpu_destroy(&runtime.vectors_gpu, &runtime.vk_ctx)
				vectors_gpu_destroy(&runtime.preview_vectors_gpu, &runtime.vk_ctx)
				moire_gpu_destroy(&runtime.moire_gpu, &runtime.vk_ctx)
				moire_gpu_destroy(&runtime.preview_moire_gpu, &runtime.vk_ctx)
				primordial_gpu_destroy(&runtime.primordial_gpu, &runtime.vk_ctx)
				primordial_gpu_destroy(&runtime.preview_primordial_gpu, &runtime.vk_ctx)
				pellets_gpu_destroy(&runtime.pellets_gpu, &runtime.vk_ctx)
				pellets_gpu_destroy(&runtime.preview_pellets_gpu, &runtime.vk_ctx)
				flow_gpu_destroy(&runtime.flow_gpu, &runtime.vk_ctx)
				flow_gpu_destroy(&runtime.preview_flow_gpu, &runtime.vk_ctx)
				slime_gpu_destroy(&runtime.slime_gpu, &runtime.vk_ctx)
				voronoi_gpu_destroy(&runtime.voronoi_gpu, &runtime.vk_ctx)
				slime_gpu_destroy(&runtime.preview_slime_gpu, &runtime.vk_ctx)
				voronoi_gpu_destroy(&runtime.preview_voronoi_gpu, &runtime.vk_ctx)
				gray_scott_resize(&runtime.preview_gray_scott, runtime.preview_gray_scott.gpu.width, runtime.preview_gray_scott.gpu.height)
				runtime.preview_particle_life.gpu.ready = false
				if !render_backend_init(&runtime.render_backend, &runtime.vk_ctx) {
					runtime.vk_ok = false
					render_worker_publish_error(state, "Failed to recreate render backend")
				}
			}
		}
		now := time.tick_now()
		frame_dt := f32(time.duration_seconds(time.tick_diff(runtime.last_tick, now)))
		runtime.last_tick = now
		dt := frame_dt
		if cmd.frame_input.delta_time > 0 {
			dt = cmd.frame_input.delta_time
		}
		runtime.app_ui.last_stats.kind = .Frame_Stats
		runtime.app_ui.last_stats.frame_index = cmd.frame_input.frame_index
		runtime.app_ui.last_stats.frame_ms = frame_dt * 1000
		if frame_dt > 0 {
			runtime.app_ui.last_stats.fps = 1 / frame_dt
		}
		profile_sim_start := time.tick_now()
		if runtime.app_ui.mode == .Particle_Life {
			particle_life_step(&runtime.particle_life, dt)
		} else if runtime.app_ui.mode == .Slime_Mold {
			remaining_sim_step(&runtime.app_ui.slime_mold, dt)
		} else if runtime.app_ui.mode == .Flow_Field {
			remaining_sim_step(&runtime.app_ui.flow_field, dt)
		} else if runtime.app_ui.mode == .Pellets {
			remaining_sim_step(&runtime.app_ui.pellets, dt)
		} else if runtime.app_ui.mode == .Voronoi_CA {
			remaining_sim_step(&runtime.app_ui.voronoi_ca, dt)
		} else if runtime.app_ui.mode == .Moire {
			remaining_sim_step(&runtime.app_ui.moire, dt)
		} else if runtime.app_ui.mode == .Vectors {
			remaining_sim_step(&runtime.app_ui.vectors, dt)
		} else if runtime.app_ui.mode == .Primordial {
			remaining_sim_step(&runtime.app_ui.primordial, dt)
		} else {
			gray_scott_step(&runtime.sim, dt)
		}
		profile_sim_seconds := time.duration_seconds(time.tick_diff(profile_sim_start, time.tick_now()))

		profile_ui_start := time.tick_now()
		runtime.gui.style = uifw.gui_style_for_viewport(
			uifw.gui_default_style(),
			f32(cmd.frame_input.window_width),
			f32(cmd.frame_input.window_height),
			runtime.app_ui.settings.ui_scale,
		)
		uifw.gui_begin_frame(&runtime.gui, {
			window_width = cmd.frame_input.window_width,
			window_height = cmd.frame_input.window_height,
			mouse_pos = cmd.frame_input.mouse_pos,
			mouse_down = cmd.frame_input.mouse_down,
			mouse_pressed = cmd.frame_input.mouse_pressed,
			mouse_released = cmd.frame_input.mouse_released,
			mouse_moved = cmd.frame_input.mouse_moved,
			mouse_delta = cmd.frame_input.mouse_delta,
			mouse_button = cmd.frame_input.mouse_button,
			wheel_delta_x = cmd.frame_input.wheel_delta_x,
			wheel_delta = cmd.frame_input.wheel_delta,
			delta_time = cmd.frame_input.delta_time,
			active_device = cmd.frame_input.active_device,
			controller_prompt_style = cmd.frame_input.controller_prompt_style,
			pointer_enabled = cmd.frame_input.pointer_enabled,
			virtual_cursor_pos = cmd.frame_input.virtual_cursor_pos,
			nav_x = cmd.frame_input.nav_x,
			nav_y = cmd.frame_input.nav_y,
			nav_pressed_x = cmd.frame_input.nav_pressed_x,
			nav_pressed_y = cmd.frame_input.nav_pressed_y,
			accept = cmd.frame_input.accept,
			accept_pressed = cmd.frame_input.actions.accept.pressed,
			back = cmd.frame_input.back,
			pause = cmd.frame_input.pause,
			toggle_ui = cmd.frame_input.toggle_ui,
			focus_next = cmd.frame_input.focus_next,
			focus_prev = cmd.frame_input.focus_prev,
			primary_down = cmd.frame_input.primary_down,
			primary_pressed = cmd.frame_input.primary_pressed,
			primary_released = cmd.frame_input.primary_released,
			secondary_down = cmd.frame_input.secondary_down,
			secondary_pressed = cmd.frame_input.secondary_pressed,
			secondary_released = cmd.frame_input.secondary_released,
			controller_connected = cmd.frame_input.controller_connected,
			controller_disconnected = cmd.frame_input.controller_disconnected,
			text_input = cmd.frame_input.text_input,
			text_input_len = cmd.frame_input.text_input_len,
			clipboard_paste = cmd.frame_input.clipboard_paste,
			clipboard_paste_len = cmd.frame_input.clipboard_paste_len,
			key_tab = cmd.frame_input.key_tab,
			key_shift = cmd.frame_input.key_shift,
			key_ctrl = cmd.frame_input.key_ctrl,
			key_super = cmd.frame_input.key_super,
			key_enter = cmd.frame_input.key_enter,
			key_escape = cmd.frame_input.key_escape,
			key_backspace = cmd.frame_input.key_backspace,
			key_delete = cmd.frame_input.key_delete,
			key_home = cmd.frame_input.key_home,
			key_end = cmd.frame_input.key_end,
			key_left = cmd.frame_input.key_left,
			key_right = cmd.frame_input.key_right,
			key_up = cmd.frame_input.key_up,
			key_down = cmd.frame_input.key_down,
			key_w = cmd.frame_input.key_w,
			key_a = cmd.frame_input.key_a,
			key_s = cmd.frame_input.key_s,
			key_d = cmd.frame_input.key_d,
			key_q = cmd.frame_input.key_q,
			key_e = cmd.frame_input.key_e,
			key_x = cmd.frame_input.key_x,
			key_v = cmd.frame_input.key_v,
			key_c = cmd.frame_input.key_c,
			key_f1 = cmd.frame_input.key_f1,
			key_slash = cmd.frame_input.key_slash,
			key_space = cmd.frame_input.key_space,
			key_space_down = cmd.frame_input.key_space_down,
			key_space_pressed = cmd.frame_input.key_space_pressed,
			key_space_released = cmd.frame_input.key_space_released,
			controller_left = cmd.frame_input.controller_left,
			controller_right = cmd.frame_input.controller_right,
			controller_zoom = cmd.frame_input.controller_zoom,
		})
		simulation_input := app_ui_simulation_filter_input(&runtime.app_ui, &runtime.gui, cmd.frame_input)
		simulation_input.camera_sensitivity = runtime.app_ui.settings.default_camera_sensitivity
		simulation_input.controller_camera_sensitivity = runtime.app_ui.settings.controller_camera_sensitivity
		simulation_input.controller_camera_invert_y = runtime.app_ui.settings.controller_camera_invert_y
		if runtime.app_ui.mode == .Particle_Life {
			particle_life_apply_frame_input(&runtime.particle_life, simulation_input)
		} else if runtime.app_ui.mode == .Gray_Scott {
			gray_scott_apply_frame_input(&runtime.sim, simulation_input)
		} else if runtime.app_ui.mode == .Slime_Mold {
			remaining_sim_apply_frame_input_for_kind(&runtime.app_ui.slime_mold, .Slime_Mold, simulation_input)
		} else if runtime.app_ui.mode == .Flow_Field {
			remaining_sim_apply_frame_input_for_kind(&runtime.app_ui.flow_field, .Flow_Field, simulation_input)
		} else if runtime.app_ui.mode == .Pellets {
			remaining_sim_apply_frame_input_for_kind(&runtime.app_ui.pellets, .Pellets, simulation_input)
		} else if runtime.app_ui.mode == .Primordial {
			remaining_sim_apply_frame_input_for_kind(&runtime.app_ui.primordial, .Primordial, simulation_input)
		}
		mode_before_ui := runtime.app_ui.mode
		app_ui_draw(&runtime.app_ui, &runtime.gui, &runtime.sim, &runtime.particle_life, &runtime.vk_ctx, &state.product)
		render_worker_apply_main_menu_palette_after_navigation(runtime, mode_before_ui)
		uifw.gui_end_frame(&runtime.gui)
		slime_controller_ui_end_frame(&runtime.app_ui, &runtime.gui)
		simulation_controller_ui_end_frame(&runtime.app_ui, &runtime.gui)
		sync.atomic_store(&state.text_input_requested, runtime.gui.wants_text_input)
		if runtime.gui.clipboard_set_pending {
			msg: Render_To_Ui_Message
			msg.kind = .Clipboard_Set
			write_fixed_string(msg.text[:], string(runtime.gui.clipboard_set_text[:runtime.gui.clipboard_set_len]))
			_ = engine.queue_try_push(state.render_to_ui, msg)
			runtime.gui.clipboard_set_pending = false
			runtime.gui.clipboard_set_len = 0
		}
		profile_ui_seconds := time.duration_seconds(time.tick_diff(profile_ui_start, time.tick_now()))

		gray_scott_render(&runtime.sim, &runtime.vk_ctx)
		if runtime.debug_frame_log_count < engine.VK_DEBUG_FRAME_LOG_LIMIT {
			engine.log_debug(
				"render_worker: frame=",
				cmd.frame_input.frame_index,
				" mode=",
				runtime.app_ui.mode,
				" window_input=",
				cmd.frame_input.window_width,
				"x",
				cmd.frame_input.window_height,
				" swapchain=",
				runtime.vk_ctx.swapchain_extent.width,
				"x",
				runtime.vk_ctx.swapchain_extent.height,
				" gui_commands=",
				len(runtime.gui.commands),
				" mpos=",
				cmd.frame_input.mouse_pos.x,
				",",
				cmd.frame_input.mouse_pos.y,
			)
			runtime.debug_frame_log_count += 1
		}
		profile_render_seconds := f64(0)
		if runtime.vk_ok {
			profile_render_start := time.tick_now()
			video_capture := video_recorder_capture_sink(&runtime.video_recorder)
			frame_rendered := render_backend_draw_frame(&runtime.render_backend, &runtime.vk_ctx, &runtime.sim, &runtime.preview_gray_scott, &runtime.particle_life, &runtime.preview_particle_life, &runtime.vectors_gpu, &runtime.preview_vectors_gpu, &runtime.moire_gpu, &runtime.preview_moire_gpu, &runtime.primordial_gpu, &runtime.preview_primordial_gpu, &runtime.pellets_gpu, &runtime.preview_pellets_gpu, &runtime.flow_gpu, &runtime.preview_flow_gpu, &runtime.slime_gpu, &runtime.voronoi_gpu, &runtime.preview_slime_gpu, &runtime.preview_voronoi_gpu, &runtime.app_ui, &runtime.gui, dt, runtime.app_ui.mode, cmd.frame_input.frame_index, state.screenshot, &video_capture)
			if !frame_rendered {
				engine.log_error("render_worker: render_backend_draw_frame failed frame=", cmd.frame_input.frame_index)
				render_worker_publish_error(state, "Failed to execute Vulkan render graph")
			} else {
				// Menu previews and simulation GPU resources are initialized during
				// their first successful render. Keep the transition black through
				// that frame, then allow the next frame to begin fading in.
				app_ui_mode_transition_notify_loaded(&runtime.app_ui)
			}
				if runtime.video_recorder.status == .Failed {
					err := fixed_string(runtime.video_recorder.last_error[:])
					_ = video_recorder_stop(&runtime.video_recorder)
					app_ui_video_recording_apply_command_state(&runtime.app_ui, .Failed, err)
					render_worker_publish_error(state, err)
					runtime.video_recorder.status = .Idle
			}
			profile_render_seconds = time.duration_seconds(time.tick_diff(profile_render_start, time.tick_now()))
		}
			render_worker_profile_record(runtime, cmd.frame_input.frame_index, profile_sim_seconds, profile_ui_seconds, profile_render_seconds)
			render_worker_publish_stats(state, cmd.frame_input.frame_index, frame_dt, runtime.app_ui.mode, &runtime.sim, &runtime.particle_life, &runtime.app_ui, &runtime.render_backend, &runtime.gui, profile_sim_seconds, profile_ui_seconds, profile_render_seconds)
	case .Apply_Gray_Scott_Settings:
		gray_scott_load_settings(&runtime.sim, cmd.gray_scott_settings)
	case .Set_App_Mode:
		if video_recorder_is_recording(&runtime.video_recorder) && app_ui_mode_is_simulation(runtime.app_ui.mode) && !app_ui_mode_is_simulation(cmd.app_mode) {
			video_recorder_stop(&runtime.video_recorder)
			app_ui_video_recording_apply_command_state(&runtime.app_ui, .Idle)
		}
		mode_before_navigation := runtime.app_ui.mode
		app_ui_navigate(&runtime.app_ui, cmd.app_mode)
		render_worker_apply_main_menu_palette_after_navigation(runtime, mode_before_navigation)
	case .Apply_Builtin_Preset:
		if render_worker_apply_builtin_preset(runtime, cmd.app_mode, cmd.builtin_preset_index) {
			render_worker_publish_preset_result(state, true, fmt.tprintf("Applied built-in preset %d for %v", cmd.builtin_preset_index, cmd.app_mode))
		} else {
			render_worker_publish_preset_result(state, false, fmt.tprintf("Failed to apply built-in preset %d for %v", cmd.builtin_preset_index, cmd.app_mode))
		}
	case .Apply_Particle_Life_Settings:
		particle_life_load_settings(&runtime.particle_life, cmd.particle_life_settings)
		if cmd.particle_life_randomize_forces {
			particle_life_randomize_forces(&runtime.particle_life)
		}
		if cmd.particle_life_reset {
			particle_life_reset_runtime(&runtime.particle_life)
		}
		render_worker_publish_preset_result(state, true, "Configured Particle Life")
	case .Apply_Flow_Settings:
		runtime.app_ui.flow_field.flow = cmd.flow_settings
		image_path := fixed_string(runtime.app_ui.flow_field.flow.image_path[:])
		if len(image_path) > 0 && runtime.app_ui.flow_field.flow.vector_field_type == .Image {
			_ = flow_gpu_load_vector_field_image_path(&runtime.flow_gpu, &runtime.vk_ctx, image_path, &runtime.app_ui.flow_field.flow)
		}
		if cmd.flow_reset {
			flow_gpu_destroy(&runtime.flow_gpu, &runtime.vk_ctx)
		}
		render_worker_publish_preset_result(state, true, "Configured Flow Field")
	case .Apply_Remaining_Settings:
		switch cmd.remaining_kind {
		case .Flow_Field:
			runtime.app_ui.flow_field.flow = cmd.flow_settings
			image_path := fixed_string(runtime.app_ui.flow_field.flow.image_path[:])
			if len(image_path) > 0 && runtime.app_ui.flow_field.flow.vector_field_type == .Image {
				_ = flow_gpu_load_vector_field_image_path(&runtime.flow_gpu, &runtime.vk_ctx, image_path, &runtime.app_ui.flow_field.flow)
			}
			if cmd.remaining_reset {
				flow_gpu_destroy(&runtime.flow_gpu, &runtime.vk_ctx)
			}
		case .Pellets:
			runtime.app_ui.pellets.pellets = cmd.pellets_settings
			if cmd.remaining_reset {
				runtime.pellets_gpu.ready = false
			}
		case .Voronoi_CA:
			runtime.app_ui.voronoi_ca.voronoi = cmd.voronoi_settings
			if cmd.remaining_reset {
				runtime.voronoi_gpu.needs_rebuild = true
			}
		case .Moire:
			runtime.app_ui.moire.moire = cmd.moire_settings
			image_path := fixed_string(runtime.app_ui.moire.moire.image_path[:])
			if len(image_path) > 0 && runtime.app_ui.moire.moire.image_mode_enabled {
				_ = moire_gpu_load_image_path(&runtime.moire_gpu, &runtime.vk_ctx, image_path, &runtime.app_ui.moire.moire)
			}
			if cmd.remaining_reset {
				moire_gpu_destroy(&runtime.moire_gpu, &runtime.vk_ctx)
			}
		case .Vectors:
			runtime.app_ui.vectors.vectors = cmd.vectors_settings
			image_path := fixed_string(runtime.app_ui.vectors.vectors.image_path[:])
			if len(image_path) > 0 && runtime.app_ui.vectors.vectors.vector_field_type == .Image {
				_ = vectors_gpu_load_image_path(&runtime.vectors_gpu, image_path, &runtime.app_ui.vectors.vectors)
			}
			if cmd.remaining_reset {
				vectors_gpu_destroy(&runtime.vectors_gpu, &runtime.vk_ctx)
			}
		case .Primordial:
			runtime.app_ui.primordial.primordial = cmd.primordial_settings
			if cmd.remaining_reset {
				runtime.primordial_gpu.ready = false
			}
		case .Slime_Mold:
			runtime.app_ui.slime_mold.slime = cmd.slime_settings
			if slime_gpu_ensure(&runtime.slime_gpu, &runtime.vk_ctx, &runtime.app_ui.slime_mold.slime) {
				mask_path := fixed_string(runtime.app_ui.slime_mold.slime.mask_image_path[:])
				if len(mask_path) > 0 && runtime.app_ui.slime_mold.slime.mask_pattern == .Image {
					_ = slime_gpu_load_mask_image_path(&runtime.slime_gpu, mask_path, &runtime.app_ui.slime_mold.slime)
				}
				position_path := fixed_string(runtime.app_ui.slime_mold.slime.position_image_path[:])
				if len(position_path) > 0 && runtime.app_ui.slime_mold.slime.position_generator == 7 {
					_ = slime_gpu_load_position_image_path(&runtime.slime_gpu, position_path, &runtime.app_ui.slime_mold.slime)
				}
			}
			if cmd.remaining_reset {
				runtime.slime_gpu.needs_reset = true
			}
		}
		render_worker_publish_preset_result(state, true, fmt.tprintf("Configured %v", cmd.remaining_kind))
	case .Set_Color_Scheme:
		color_scheme_name := cmd.color_scheme_name
		name := fixed_string(color_scheme_name[:])
		if render_worker_set_color_scheme(runtime, cmd.app_mode, name, cmd.color_scheme_reversed, cmd.color_scheme_reversed_set) {
			render_worker_publish_preset_result(state, true, fmt.tprintf("Set color scheme %s for %v", name, cmd.app_mode))
		} else {
			render_worker_publish_preset_result(state, false, fmt.tprintf("Failed to set color scheme %s for %v", name, cmd.app_mode))
		}
	case .Hide_Ui:
		render_worker_hide_ui(runtime)
	case .Start_Video_Recording:
		file_path := cmd.file_path
		path := fixed_string(file_path[:])
		if video_recorder_start(&runtime.video_recorder, runtime.vk_ctx.swapchain_extent.width, runtime.vk_ctx.swapchain_extent.height, runtime.vk_ctx.swapchain_format, {output_path = path, fps = video_recorder_fps_from_settings(runtime.app_ui.settings)}) {
			app_ui_video_recording_apply_command_state(&runtime.app_ui, .Recording, path)
			render_worker_publish_preset_result(state, true, fmt.tprintf("Recording video to %s", path))
		} else {
			err := fixed_string(runtime.video_recorder.last_error[:])
			app_ui_video_recording_apply_command_state(&runtime.app_ui, .Failed, err)
			render_worker_publish_error(state, err)
			runtime.video_recorder.status = .Idle
		}
	case .Stop_Video_Recording:
		if video_recorder_is_recording(&runtime.video_recorder) {
			path := fixed_string(runtime.video_recorder.output_path[:])
			if video_recorder_stop(&runtime.video_recorder) {
				app_ui_video_recording_apply_command_state(&runtime.app_ui, .Idle, path)
				render_worker_publish_preset_result(state, true, fmt.tprintf("Saved video recording to %s", path))
			} else {
				err := fixed_string(runtime.video_recorder.last_error[:])
				app_ui_video_recording_apply_command_state(&runtime.app_ui, .Failed, err)
				render_worker_publish_error(state, err)
				runtime.video_recorder.status = .Idle
			}
		} else {
			app_ui_video_recording_apply_command_state(&runtime.app_ui, .Idle)
		}
	case .Cancel_Video_Recording:
		app_ui_video_recording_apply_command_state(&runtime.app_ui, .Idle)
	case .Video_Recording_Restoring_Fullscreen:
		app_ui_video_recording_apply_command_state(&runtime.app_ui, .Restoring_Fullscreen, "Restoring fullscreen before recording")
	case .Video_Recording_Error:
		file_path := cmd.file_path
		err := fixed_string(file_path[:])
		app_ui_video_recording_apply_command_state(&runtime.app_ui, .Failed, err)
		render_worker_publish_error(state, err)
	case .Reset_Gray_Scott:
		gray_scott_reset_runtime(&runtime.sim)
	case .Randomize_Gray_Scott:
		gray_scott_randomize_settings(&runtime.sim)
	case .Seed_Noise_Gray_Scott:
		gray_scott_seed_noise(&runtime.sim)
	case .Load_Gray_Scott_Nutrient_Image:
		file_path := cmd.file_path
		path := fixed_string(file_path[:])
		if len(path) > 0 {
			write_fixed_string(runtime.sim.settings.nutrient_image_path[:], path)
			runtime.sim.settings.mask_pattern = .Nutrient_Map
			gray_scott_upload_nutrient_map(&runtime.sim)
			if runtime.sim.runtime.nutrient_image_loaded {
				render_worker_publish_preset_result(state, true, "Loaded Gray-Scott nutrient image")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Gray-Scott nutrient image")
			}
		}
	case .Load_Vectors_Image:
		file_path := cmd.file_path
		path := fixed_string(file_path[:])
		if len(path) > 0 {
			runtime.app_ui.vectors.vectors.vector_field_type = .Image
			runtime.app_ui.vectors.vectors.vector_field_index = int(Vector_Field_Type.Image)
			write_fixed_string(runtime.app_ui.vectors.vectors.image_path[:], path)
			if vectors_gpu_load_image_path(&runtime.vectors_gpu, path, &runtime.app_ui.vectors.vectors) {
				render_worker_publish_preset_result(state, true, "Loaded Vectors image")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Vectors image")
			}
		}
	case .Load_Moire_Image:
		file_path := cmd.file_path
		path := fixed_string(file_path[:])
		if len(path) > 0 {
			runtime.app_ui.moire.moire.image_mode_enabled = true
			write_fixed_string(runtime.app_ui.moire.moire.image_path[:], path)
			if moire_gpu_load_image_path(&runtime.moire_gpu, &runtime.vk_ctx, path, &runtime.app_ui.moire.moire) {
				render_worker_publish_preset_result(state, true, "Loaded Moire image")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Moire image")
			}
		}
	case .Load_Flow_Image:
		file_path := cmd.file_path
		path := fixed_string(file_path[:])
		if len(path) > 0 {
			runtime.app_ui.flow_field.flow.vector_field_type = .Image
			runtime.app_ui.flow_field.flow.vector_field_index = int(Vector_Field_Type.Image)
			write_fixed_string(runtime.app_ui.flow_field.flow.image_path[:], path)
			if flow_gpu_load_vector_field_image_path(&runtime.flow_gpu, &runtime.vk_ctx, path, &runtime.app_ui.flow_field.flow) {
				render_worker_publish_preset_result(state, true, "Loaded Flow image")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Flow image")
			}
		}
	case .Load_Slime_Mask_Image:
		file_path := cmd.file_path
		path := fixed_string(file_path[:])
		if len(path) > 0 {
			if !slime_gpu_ensure(&runtime.slime_gpu, &runtime.vk_ctx, &runtime.app_ui.slime_mold.slime) {
				render_worker_publish_preset_result(state, false, fmt.tprintf("Failed to load Slime mask image: path=\"%s\"; reason=Slime GPU initialization failed; target=%dx%d", path, runtime.slime_gpu.width, runtime.slime_gpu.height))
			} else {
				ok, reason := slime_gpu_load_mask_image_path_diagnostic(&runtime.slime_gpu, path, &runtime.app_ui.slime_mold.slime)
				if ok {
					render_worker_publish_preset_result(state, true, "Loaded Slime mask image")
				} else {
					render_worker_publish_preset_result(state, false, fmt.tprintf("Failed to load Slime mask image: path=\"%s\"; target=%dx%d; fit=%v; reason=%s", path, runtime.slime_gpu.width, runtime.slime_gpu.height, runtime.app_ui.slime_mold.slime.mask_image_fit_mode, reason))
				}
			}
		}
	case .Load_Slime_Position_Image:
		file_path := cmd.file_path
		path := fixed_string(file_path[:])
		if len(path) > 0 {
			if slime_gpu_ensure(&runtime.slime_gpu, &runtime.vk_ctx, &runtime.app_ui.slime_mold.slime) &&
			   slime_gpu_load_position_image_path(&runtime.slime_gpu, path, &runtime.app_ui.slime_mold.slime) {
				render_worker_publish_preset_result(state, true, "Loaded Slime position image")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Slime position image")
			}
		}
	case .Clear_Gray_Scott_Nutrient_Image:
		write_fixed_string(runtime.sim.settings.nutrient_image_path[:], "")
		runtime.sim.runtime.nutrient_image_loaded = false
		gray_scott_upload_nutrient_map(&runtime.sim)
		render_worker_publish_preset_result(state, true, "Cleared Gray-Scott nutrient image")
	case .Clear_Vectors_Image:
		write_fixed_string(runtime.app_ui.vectors.vectors.image_path[:], "")
		write_fixed_string(runtime.vectors_gpu.image_path[:], "")
		runtime.vectors_gpu.image_loaded = false
		runtime.app_ui.vectors.vectors.vector_field_type = .Noise
		runtime.app_ui.vectors.vectors.vector_field_index = int(Vector_Field_Type.Noise)
		render_worker_publish_preset_result(state, true, "Cleared Vectors image")
	case .Clear_Moire_Image:
		write_fixed_string(runtime.app_ui.moire.moire.image_path[:], "")
		write_fixed_string(runtime.moire_gpu.image_path[:], "")
		runtime.moire_gpu.image_loaded = false
		runtime.app_ui.moire.moire.image_mode_enabled = false
		render_worker_publish_preset_result(state, true, "Cleared Moire image")
	case .Clear_Flow_Image:
		write_fixed_string(runtime.app_ui.flow_field.flow.image_path[:], "")
		write_fixed_string(runtime.flow_gpu.vector_field_image_path[:], "")
		runtime.flow_gpu.vector_field_image_loaded = false
		runtime.app_ui.flow_field.flow.vector_field_type = .Noise
		runtime.app_ui.flow_field.flow.vector_field_index = int(Vector_Field_Type.Noise)
		render_worker_publish_preset_result(state, true, "Cleared Flow image")
	case .Clear_Slime_Mask_Image:
		write_fixed_string(runtime.app_ui.slime_mold.slime.mask_image_path[:], "")
		runtime.app_ui.slime_mold.slime.mask_pattern = .Disabled
		runtime.app_ui.slime_mold.slime.mask_pattern_index = int(Slime_Mask_Pattern.Disabled)
		if runtime.slime_gpu.mask_buffer.mapped != nil {
			data := (cast([^]f32)runtime.slime_gpu.mask_buffer.mapped)[:int(runtime.slime_gpu.width * runtime.slime_gpu.height)]
			for i in 0 ..< len(data) {
				data[i] = 0
			}
		}
		render_worker_publish_preset_result(state, true, "Cleared Slime mask image")
	case .Clear_Slime_Position_Image:
		write_fixed_string(runtime.app_ui.slime_mold.slime.position_image_path[:], "")
		runtime.app_ui.slime_mold.slime.position_generator = 0
		runtime.app_ui.slime_mold.slime.position_generator_index = 0
		runtime.slime_gpu.needs_reset = true
		render_worker_publish_preset_result(state, true, "Cleared Slime position image")
	case .Load_Preset:
		preset_name := cmd.preset_name
		path := render_worker_preset_path(state, preset_name[:], false)
		if runtime.app_ui.mode == .Particle_Life {
			if settings, ok := settings_load_particle_life_preset(path, runtime.particle_life.settings); ok {
				particle_life_load_settings(&runtime.particle_life, settings)
				render_worker_publish_preset_result(state, true, "Loaded Particle Life TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Particle Life TOML preset")
			}
		} else if runtime.app_ui.mode == .Flow_Field {
			if settings, ok := settings_load_flow_preset(path, runtime.app_ui.flow_field.flow); ok {
				runtime.app_ui.flow_field.flow = settings
				image_path := fixed_string(settings.image_path[:])
				if len(image_path) > 0 {
					_ = flow_gpu_load_vector_field_image_path(&runtime.flow_gpu, &runtime.vk_ctx, image_path, &runtime.app_ui.flow_field.flow)
				}
				render_worker_publish_preset_result(state, true, "Loaded Flow TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Flow TOML preset")
			}
		} else if runtime.app_ui.mode == .Moire {
			if settings, ok := settings_load_moire_preset(path, runtime.app_ui.moire.moire); ok {
				runtime.app_ui.moire.moire = settings
				image_path := fixed_string(settings.image_path[:])
				if len(image_path) > 0 {
					_ = moire_gpu_load_image_path(&runtime.moire_gpu, &runtime.vk_ctx, image_path, &runtime.app_ui.moire.moire)
				}
				render_worker_publish_preset_result(state, true, "Loaded Moire TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Moire TOML preset")
			}
		} else if runtime.app_ui.mode == .Vectors {
			if settings, ok := settings_load_vectors_preset(path, runtime.app_ui.vectors.vectors); ok {
				runtime.app_ui.vectors.vectors = settings
				image_path := fixed_string(settings.image_path[:])
				if len(image_path) > 0 {
					_ = vectors_gpu_load_image_path(&runtime.vectors_gpu, image_path, &runtime.app_ui.vectors.vectors)
				}
				render_worker_publish_preset_result(state, true, "Loaded Vectors TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Vectors TOML preset")
			}
		} else if runtime.app_ui.mode == .Primordial {
			if settings, ok := settings_load_primordial_preset(path, runtime.app_ui.primordial.primordial); ok {
				runtime.app_ui.primordial.primordial = settings
				runtime.primordial_gpu.ready = false
				render_worker_publish_preset_result(state, true, "Loaded Primordial TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Primordial TOML preset")
			}
		} else if runtime.app_ui.mode == .Pellets {
			if settings, ok := settings_load_pellets_preset(path, runtime.app_ui.pellets.pellets); ok {
				runtime.app_ui.pellets.pellets = settings
				runtime.pellets_gpu.ready = false
				render_worker_publish_preset_result(state, true, "Loaded Pellets TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Pellets TOML preset")
			}
		} else if runtime.app_ui.mode == .Voronoi_CA {
			if settings, ok := settings_load_voronoi_preset(path, runtime.app_ui.voronoi_ca.voronoi); ok {
				runtime.app_ui.voronoi_ca.voronoi = settings
				runtime.voronoi_gpu.needs_rebuild = true
				render_worker_publish_preset_result(state, true, "Loaded Voronoi TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Voronoi TOML preset")
			}
		} else if runtime.app_ui.mode == .Slime_Mold {
			if settings, ok := settings_load_slime_preset(path, runtime.app_ui.slime_mold.slime); ok {
				runtime.app_ui.slime_mold.slime = settings
				if slime_gpu_ensure(&runtime.slime_gpu, &runtime.vk_ctx, &runtime.app_ui.slime_mold.slime) {
					mask_path := fixed_string(settings.mask_image_path[:])
					if len(mask_path) > 0 && settings.mask_pattern == .Image {
						_ = slime_gpu_load_mask_image_path(&runtime.slime_gpu, mask_path, &runtime.app_ui.slime_mold.slime)
					}
					position_path := fixed_string(settings.position_image_path[:])
					if len(position_path) > 0 && settings.position_generator == 7 {
						_ = slime_gpu_load_position_image_path(&runtime.slime_gpu, position_path, &runtime.app_ui.slime_mold.slime)
					}
				}
				runtime.slime_gpu.needs_reset = true
				render_worker_publish_preset_result(state, true, "Loaded Slime TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Slime TOML preset")
			}
		} else {
			if settings, ok := settings_load_gray_scott_preset(path, runtime.sim.settings); ok {
				gray_scott_load_settings(&runtime.sim, settings)
				render_worker_publish_preset_result(state, true, "Loaded Gray-Scott TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Gray-Scott TOML preset")
			}
		}
	case .Save_Preset:
		preset_name := cmd.preset_name
		path := render_worker_preset_path(state, preset_name[:], true)
		if runtime.app_ui.mode == .Particle_Life {
			if settings_save_particle_life(path, particle_life_save_settings(&runtime.particle_life)) {
				render_worker_publish_preset_result(state, true, "Saved Particle Life TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Particle Life TOML preset")
			}
		} else if runtime.app_ui.mode == .Flow_Field {
			if settings_save_flow(path, runtime.app_ui.flow_field.flow) {
				render_worker_publish_preset_result(state, true, "Saved Flow TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Flow TOML preset")
			}
		} else if runtime.app_ui.mode == .Moire {
			if settings_save_moire(path, runtime.app_ui.moire.moire) {
				render_worker_publish_preset_result(state, true, "Saved Moire TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Moire TOML preset")
			}
		} else if runtime.app_ui.mode == .Vectors {
			if settings_save_vectors(path, runtime.app_ui.vectors.vectors) {
				render_worker_publish_preset_result(state, true, "Saved Vectors TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Vectors TOML preset")
			}
		} else if runtime.app_ui.mode == .Primordial {
			if settings_save_primordial(path, runtime.app_ui.primordial.primordial) {
				render_worker_publish_preset_result(state, true, "Saved Primordial TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Primordial TOML preset")
			}
		} else if runtime.app_ui.mode == .Pellets {
			if settings_save_pellets(path, runtime.app_ui.pellets.pellets) {
				render_worker_publish_preset_result(state, true, "Saved Pellets TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Pellets TOML preset")
			}
		} else if runtime.app_ui.mode == .Voronoi_CA {
			if settings_save_voronoi(path, runtime.app_ui.voronoi_ca.voronoi) {
				render_worker_publish_preset_result(state, true, "Saved Voronoi TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Voronoi TOML preset")
			}
		} else if runtime.app_ui.mode == .Slime_Mold {
			if settings_save_slime(path, runtime.app_ui.slime_mold.slime) {
				render_worker_publish_preset_result(state, true, "Saved Slime TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Slime TOML preset")
			}
		} else {
			if settings_save_gray_scott(path, runtime.sim.settings) {
				render_worker_publish_preset_result(state, true, "Saved Gray-Scott TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Gray-Scott TOML preset")
			}
		}
	case .Delete_Preset:
		preset_name := cmd.preset_name
		path := render_worker_preset_path(state, preset_name[:], false)
		if err := os.remove(path); err == nil {
			if runtime.app_ui.mode == .Particle_Life {
				render_worker_publish_preset_result(state, true, "Deleted Particle Life TOML preset")
			} else {
				render_worker_publish_preset_result(state, true, "Deleted Gray-Scott TOML preset")
			}
		} else {
			if runtime.app_ui.mode == .Particle_Life {
				render_worker_publish_preset_result(state, false, "Failed to delete Particle Life TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to delete Gray-Scott TOML preset")
			}
		}
	}
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
