package app

import uifw "zelda_engine:ui"
import engine "zelda_engine:engine"

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
	if cmd.kind == .Feature {
		feature := cmd.feature
		render_worker_handle_feature_command(state, runtime, &feature)
		return
	}
	if render_worker_handle_settings_command(state, runtime, cmd) {return}
	if render_worker_handle_recording_command(state, runtime, cmd) {return}
}

render_worker_publish_feature_result :: proc(state: ^Render_Worker_State, result: Feature_Result) {
	message: Render_To_Ui_Message
	message.kind = .Feature_Result
	message.feature_result = result
	write_fixed_string(message.text[:], fixed_string(message.feature_result.message[:]))
	_ = engine.queue_try_push(state.render_to_ui, message)
}

render_worker_handle_feature_command :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, command: ^Feature_Command) {
	result := Feature_Result {feature_id = command.feature_id, command_id = command.command_id}
	if state == nil || state.shutdown_started {
		result.error = .Shutting_Down
		write_fixed_string(result.message[:], "Feature command rejected during shutdown")
		if state != nil do render_worker_publish_feature_result(state, result)
		return
	}
	if validation := feature_command_validate(command); validation != .None {
		result.error = validation
		write_fixed_string(result.message[:], "Feature command schema validation failed")
		render_worker_publish_feature_result(state, result)
		return
	}
	descriptor, found := feature_descriptor_by_id(command.feature_id)
	if !found {
		result.error = .Unknown_Feature
		write_fixed_string(result.message[:], "Unknown feature")
		render_worker_publish_feature_result(state, result)
		return
	}
	mode_matches := runtime.app_ui.mode == descriptor.mode || (runtime.app_ui.mode_transition_phase != .Idle && runtime.app_ui.mode_transition_target == descriptor.mode)
	if !mode_matches {
		result.error = .Wrong_Mode
		write_fixed_string(result.message[:], "Feature command does not target the active mode")
		render_worker_publish_feature_result(state, result)
		return
	}

	dispatched := false
	if command.command_id == FEATURE_COMMAND_APPLY_PRESET {
		payload, ok := feature_command_payload(command, Feature_Preset_Command)
		if ok {
			dispatched = render_worker_apply_builtin_preset(runtime, descriptor.mode, int(payload.index))
		}
	} else if command.command_id == FEATURE_COMMAND_SET_COLOR {
		if payload, ok := feature_command_payload(command, Feature_Color_Command); ok {
			name := fixed_string(payload.name[:])
			dispatched = render_worker_set_color_scheme(runtime, descriptor.mode, name, payload.reversed, payload.reversed_set)
		}
	} else if command.command_id == FEATURE_COMMAND_RESET {
		if payload, ok := feature_command_payload(command, Feature_Reset_Command); ok {
			product_instance := feature_instance_set_get(&runtime.app_ui.feature_instances, descriptor.mode)
			dispatched = product_instance != nil && descriptor.reset != nil && descriptor.reset(product_instance.settings, product_instance.runtime, payload)
			if dispatched {
				render_descriptor, render_found := render_feature_descriptor_by_mode(descriptor.mode)
				render_instance := render_feature_instance_set_get(&runtime.feature_instances, descriptor.mode)
				if render_found && render_instance != nil && render_descriptor.reset_runtime != nil {
					render_descriptor.reset_runtime(render_instance.runtime, &runtime.vk_ctx)
				}
			}
		}
	} else if command.command_id == FEATURE_COMMAND_PRESET_FILE {
		if payload, ok := feature_command_payload(command, Feature_Preset_File_Command); ok {
			dispatched = render_worker_handle_preset_file_command(state, runtime, descriptor.mode, payload^)
		}
	} else if command.command_id == FEATURE_COMMAND_LOAD_IMAGE || command.command_id == FEATURE_COMMAND_CLEAR_IMAGE {
		if payload, ok := feature_command_payload(command, Feature_Image_Command); ok {
			if command.command_id == FEATURE_COMMAND_LOAD_IMAGE && payload.dialog_request_id != 0 && len(fixed_string(payload.path[:])) == 0 {
				if _, valid_target := feature_image_target(command.feature_id, payload.slot); !valid_target {
					result.error = .Dispatch_Failed
					write_fixed_string(result.message[:], "Unsupported image dialog target")
					render_worker_publish_feature_result(state, result)
					return
				}
				result.success = true
				result.dialog = {kind = .Open_Image, request_id = payload.dialog_request_id, feature_id = command.feature_id, slot = payload.slot}
				write_fixed_string(result.message[:], "Image selection requested")
				render_worker_publish_feature_result(state, result)
				return
			}
			if payload.dialog_request_id != 0 {
				target, valid_target := feature_image_target(command.feature_id, payload.slot)
				if !valid_target || !app_ui_consume_image_dialog_request(&runtime.app_ui, target, payload.dialog_request_id) {
					result.error = .Stale_Result
					write_fixed_string(result.message[:], "Image dialog result is stale")
					render_worker_publish_feature_result(state, result)
					return
				}
			}
			dispatched = render_worker_dispatch_feature_image(state, runtime, command.feature_id, payload, command.command_id == FEATURE_COMMAND_CLEAR_IMAGE)
		}
	} else if command.command_id == FEATURE_COMMAND_APPLY_SETTINGS {
		instance := feature_instance_set_get(&runtime.app_ui.feature_instances, descriptor.mode)
		if instance != nil && descriptor.apply_settings != nil {
			dispatched = descriptor.apply_settings(instance.settings, instance.runtime, rawptr(&command.payload.bytes[0]))
			if dispatched do render_worker_mark_mode_dirty(runtime, descriptor.mode)
		}
	}
	result.success = dispatched
	result.error = dispatched ? .None : .Dispatch_Failed
	write_fixed_string(result.message[:], dispatched ? "Feature command applied" : "Feature command dispatch failed")
	render_worker_publish_feature_result(state, result)
}

render_worker_handle_lifecycle_command :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, cmd: Ui_To_Render_Command) -> bool {
	#partial switch cmd.kind {
	case .Close:
		video_recorder_stop(&runtime.video_recorder)
		state.shutdown_started = true
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
				render_feature_instance_set_release_target_resources(&runtime.feature_instances, &runtime.vk_ctx)
				gray_scott_resize(&runtime.app_ui.preview_gray_scott, runtime.app_ui.preview_gray_scott.runtime.render_width, runtime.app_ui.preview_gray_scott.runtime.render_height)
				render_worker_particle_life_gpu(runtime, true).ready = false
				if !render_backend_init(&runtime.render_backend, &runtime.vk_ctx) {
					runtime.vk_ok = false
					render_worker_publish_error(state, "Failed to recreate render backend")
				}
			}
		}
}

render_worker_handle_frame_command :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, cmd: Ui_To_Render_Command) {
		render_worker_try_recover_device(state, runtime, cmd.frame_input.window_width, cmd.frame_input.window_height, cmd.frame_input.frame_index)
		dt, frame_dt := render_worker_begin_frame(runtime, cmd)
		profile_sim_start := time.tick_now()
		if descriptor, found := feature_descriptor_by_mode(runtime.app_ui.mode); found && descriptor.update != nil {
			instance := feature_instance_set_get(&runtime.app_ui.feature_instances, runtime.app_ui.mode)
			if instance != nil do _ = descriptor.update(instance.settings, instance.runtime, dt)
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
			nav_x = cmd.frame_input.actions.navigate.value.x,
			nav_y = cmd.frame_input.actions.navigate.value.y,
			nav_pressed_x = cmd.frame_input.actions.navigate.pressed.x,
			nav_pressed_y = cmd.frame_input.actions.navigate.pressed.y,
			accept = cmd.frame_input.actions.accept.pressed || cmd.frame_input.actions.accept.repeated,
			accept_pressed = cmd.frame_input.actions.accept.pressed,
			back = cmd.frame_input.actions.back.pressed || cmd.frame_input.actions.back.repeated,
			pause = cmd.frame_input.actions.pause.pressed || cmd.frame_input.actions.pause.repeated,
			focus_next = cmd.frame_input.actions.focus_next.pressed || cmd.frame_input.actions.focus_next.repeated,
			focus_prev = cmd.frame_input.actions.focus_prev.pressed || cmd.frame_input.actions.focus_prev.repeated,
			primary_down = cmd.frame_input.actions.primary.down,
			primary_pressed = cmd.frame_input.actions.primary.pressed,
			primary_released = cmd.frame_input.actions.primary.released,
			secondary_down = cmd.frame_input.actions.secondary.down,
			secondary_pressed = cmd.frame_input.actions.secondary.pressed,
			secondary_released = cmd.frame_input.actions.secondary.released,
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
			key_space = cmd.frame_input.key_space,
			key_space_down = cmd.frame_input.key_space_down,
			key_space_pressed = cmd.frame_input.key_space_pressed,
			key_space_released = cmd.frame_input.key_space_released,
			controller_left = cmd.frame_input.controller_left,
			controller_zoom = cmd.frame_input.controller_zoom,
		})
		simulation_input := app_ui_simulation_filter_input(&runtime.app_ui, &runtime.gui, cmd.frame_input)
		simulation_input.camera_sensitivity = runtime.app_ui.settings.default_camera_sensitivity
		simulation_input.controller_camera_sensitivity = runtime.app_ui.settings.controller_camera_sensitivity
		simulation_input.controller_camera_invert_y = runtime.app_ui.settings.controller_camera_invert_y
		if descriptor, found := feature_descriptor_by_mode(runtime.app_ui.mode); found && descriptor.apply_input != nil {
			instance := feature_instance_set_get(&runtime.app_ui.feature_instances, runtime.app_ui.mode)
			if instance != nil do _ = descriptor.apply_input(instance.settings, instance.runtime, simulation_input)
		}
		mode_before_ui := runtime.app_ui.mode
		app_ui_draw(
			&runtime.app_ui,
			&runtime.gui,
			&runtime.ui_documents,
			{f32(runtime.vk_ctx.swapchain_extent.width), f32(runtime.vk_ctx.swapchain_extent.height)},
			&state.product,
		)
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

		gray_scott_render(&runtime.app_ui.gray_scott, &runtime.vk_ctx)
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
				len(runtime.gui.paint_commands),
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
			frame_rendered := render_backend_draw_frame(&runtime.render_backend, &runtime.vk_ctx, &runtime.feature_instances, &runtime.app_ui, &runtime.gui, dt, runtime.app_ui.mode, cmd.frame_input.frame_index, state.screenshot, &video_capture)
			if !frame_rendered {
				if runtime.vk_ctx.device_lost {
					loss_stage := fixed_string(runtime.vk_ctx.device_loss_stage[:])
					loss_detail := fixed_string(runtime.vk_ctx.device_loss_detail[:])
					runtime.vk_ok = false
					runtime.device_recovery_pending = true
					runtime.last_device_recovery_frame = 0
					engine.log_error("render_worker: Vulkan device lost; scheduling adapter recovery")
					render_worker_publish_error(state, fmt.tprintf("Vulkan adapter lost while %s. Driver report: %s. Attempting recovery.", loss_stage, loss_detail))
				} else {
					engine.log_error("render_worker: render_backend_draw_frame failed frame=", cmd.frame_input.frame_index)
					render_worker_publish_error(state, "Failed to execute Vulkan render graph")
				}
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
			render_worker_publish_stats(state, cmd.frame_input.frame_index, frame_dt, runtime.app_ui.mode, &runtime.app_ui.gray_scott, &runtime.app_ui.particle_life, &runtime.app_ui, &runtime.render_backend, &runtime.gui, profile_sim_seconds, profile_ui_seconds, profile_render_seconds)
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
	case .Hide_Ui:
		render_worker_hide_ui(runtime)
	case .Debug_Reload_Ui_Document:
		document_id_value := cmd.document_id
		path_value := cmd.file_path
		document_id := fixed_string(document_id_value[:])
		path := fixed_string(path_value[:])
		result := uifw.ui_document_assets_reload(&runtime.ui_documents, document_id, path)
		if result.error == .None {
			render_worker_publish_preset_result(state, true, fmt.tprintf("Reloaded UI document %s", document_id))
		} else {
			render_worker_publish_preset_result(state, false, fmt.tprintf("UI document reload failed: id=%s error=%v index=%d message=%s", document_id, result.error, result.index, result.message))
		}
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
