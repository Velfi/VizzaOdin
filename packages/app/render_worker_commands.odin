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



render_worker_handle_command :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, cmd: Ui_To_Render_Command) {
	if render_worker_handle_lifecycle_command(state, runtime, cmd) {return}
	if cmd.kind == .Frame_Input {render_worker_handle_frame_command(state, runtime, cmd); return}
	if render_worker_handle_settings_command(state, runtime, cmd) {return}
	if render_worker_handle_recording_command(state, runtime, cmd) {return}
	if render_worker_handle_simulation_command(state, runtime, cmd) {return}
	_ = render_worker_handle_preset_command(state, runtime, cmd)
}

render_worker_handle_lifecycle_command :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, cmd: Ui_To_Render_Command) -> bool {
	#partial switch cmd.kind {
	case .Close:
		video_recorder_stop(&runtime.video_recorder)
		state.running = false
	case .Resize:
		render_worker_handle_resize(state, runtime, cmd)
	case:
		return false
	}
	return true
}



render_worker_ensure_swapchain_for_frame :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, cmd: Ui_To_Render_Command) {
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
}

render_worker_handle_frame_command :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, cmd: Ui_To_Render_Command) {
		dt, frame_dt := render_worker_begin_frame(runtime, cmd)
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
			controller_south_is_accept = app_controller_south_is_accept(runtime.app_ui.settings),
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
			canvas_tool_slot = cmd.frame_input.canvas_tool_slot,
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
		} else if runtime.app_ui.mode == .Voronoi_CA {
			remaining_sim_apply_frame_input_for_kind(&runtime.app_ui.voronoi_ca, .Voronoi_CA, simulation_input)
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
}

render_worker_begin_frame :: proc(runtime: ^Render_Worker_Runtime, cmd: Ui_To_Render_Command) -> (f32, f32) {
	now := time.tick_now()
	frame_dt := f32(time.duration_seconds(time.tick_diff(runtime.last_tick, now)))
	runtime.last_tick = now
	dt := cmd.frame_input.delta_time > 0 ? cmd.frame_input.delta_time : frame_dt
	runtime.app_ui.last_stats.kind = .Frame_Stats
	runtime.app_ui.last_stats.frame_index = cmd.frame_input.frame_index
	runtime.app_ui.last_stats.frame_ms = frame_dt * 1000
	if frame_dt > 0 do runtime.app_ui.last_stats.fps = 1 / frame_dt
	return dt, frame_dt
}

render_worker_handle_settings_command :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, cmd: Ui_To_Render_Command) -> bool {
	#partial switch cmd.kind {
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
	case .Set_Ui_Component_Fixture:
		runtime.app_ui.component_fixture = cmd.component_fixture
		runtime.app_ui.component_fixture_state = cmd.component_fixture_state
		runtime.app_ui.component_fixture_value = cmd.component_fixture_value
		app_ui_navigate_immediate(&runtime.app_ui, .Theme_Preview)
		app_ui_mode_transition_cancel(&runtime.app_ui)
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
	case:
		return false
	}
	return true
}

render_worker_handle_recording_command :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, cmd: Ui_To_Render_Command) -> bool {
	#partial switch cmd.kind {
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
	case:
		return false
	}
	return true
}

render_worker_handle_simulation_command :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, cmd: Ui_To_Render_Command) -> bool {
	#partial switch cmd.kind {
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
	case:
		return false
	}
	return true
}
