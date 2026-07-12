package app

import engine "../engine"

import "core:fmt"
import "core:strings"
import "core:sync"
import sdl "vendor:sdl3"

mcp_enqueue_feature_command :: proc(app: ^App_State, mode: App_Mode, command_id: Feature_Command_Id, value: ^$T) -> bool {
	descriptor, ok := feature_descriptor_by_mode(mode)
	if !ok do return false
	feature, made := feature_command_make(descriptor.id, command_id, value)
	if !made do return false
	command: Ui_To_Render_Command
	command.kind = .Feature
	command.feature = feature
	return engine.queue_try_push(&app.ui_to_render, command)
}

mcp_bridge_drain_commands :: proc(bridge: ^Mcp_Bridge, app: ^App_State) {
	if bridge.close_requested {
		app.running = false
	}
	for idx := 0; idx < bridge.pending_command_count; idx += 1 {
		cmd := bridge.pending_commands[idx]
		switch cmd.kind {
		case .Click:
			app.input.mouse_pos = {cmd.x, cmd.y}
			app.input.mouse_down = false
			app.input.mouse_pressed = true
			app.input.mouse_released = true
			app.input.mouse_button = cmd.button
		case .Mouse_Down:
			app.input.mouse_pos = {cmd.x, cmd.y}
			app.input.mouse_down = true
			app.input.mouse_pressed = true
			app.input.mouse_released = false
			app.held_mouse_button = cmd.button
			app.input.mouse_button = cmd.button
		case .Mouse_Up:
			app.input.mouse_pos = {cmd.x, cmd.y}
			app.input.mouse_down = false
			app.input.mouse_pressed = false
			app.input.mouse_released = true
			app.input.mouse_button = cmd.button
			if app.held_mouse_button == cmd.button {
				app.held_mouse_button = 0
			}
		case .Move:
			app.input.mouse_pos = {cmd.x, cmd.y}
		case .Wheel:
			app.input.wheel_delta += cmd.wheel_delta
		case .Resize_Window:
			if app.window != nil do _ = sdl.SetWindowSize(app.window, i32(cmd.x), i32(cmd.y))
		case .Set_Mode:
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Set_App_Mode
			render_cmd.app_mode = cmd.mode
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
		case .Set_Ui_Component_Fixture:
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Set_Ui_Component_Fixture
			render_cmd.component_fixture = cmd.component_fixture
			render_cmd.component_fixture_state = cmd.component_fixture_state
			render_cmd.component_fixture_value = cmd.component_fixture_value
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
		case .Apply_Builtin_Preset:
			payload := Feature_Preset_Command{index = i32(cmd.preset_index)}
			_ = mcp_enqueue_feature_command(app, cmd.mode, FEATURE_COMMAND_APPLY_PRESET, &payload)
		case .Set_Color_Scheme:
			payload := Feature_Color_Command{name = cmd.color_scheme_name, reversed = cmd.color_scheme_reversed, reversed_set = cmd.color_scheme_reversed_set}
			_ = mcp_enqueue_feature_command(app, cmd.mode, FEATURE_COMMAND_SET_COLOR, &payload)
		case .Configure_Particle_Life:
			if cmd.particle_life_set_mode {
				mode_cmd: Ui_To_Render_Command
				mode_cmd.kind = .Set_App_Mode
				mode_cmd.app_mode = .Particle_Life
				_ = engine.queue_try_push(&app.ui_to_render, mode_cmd)
			}
			_ = mcp_enqueue_feature_command(app, .Particle_Life, FEATURE_COMMAND_APPLY_SETTINGS, &cmd.particle_life_settings)
			if cmd.particle_life_randomize_forces || cmd.particle_life_reset {
				reset := Feature_Reset_Command{randomize = cmd.particle_life_randomize_forces}
				_ = mcp_enqueue_feature_command(app, .Particle_Life, FEATURE_COMMAND_RESET, &reset)
			}
			if cmd.particle_life_hide_ui {
				hide_cmd: Ui_To_Render_Command
				hide_cmd.kind = .Hide_Ui
				_ = engine.queue_try_push(&app.ui_to_render, hide_cmd)
			}
		case .Configure_Flow_Field:
			if cmd.flow_set_mode {
				mode_cmd: Ui_To_Render_Command
				mode_cmd.kind = .Set_App_Mode
				mode_cmd.app_mode = .Flow_Field
				_ = engine.queue_try_push(&app.ui_to_render, mode_cmd)
			}
			_ = mcp_enqueue_feature_command(app, .Flow_Field, FEATURE_COMMAND_APPLY_SETTINGS, &cmd.flow_settings)
			if cmd.flow_reset {
				reset: Feature_Reset_Command
				_ = mcp_enqueue_feature_command(app, .Flow_Field, FEATURE_COMMAND_RESET, &reset)
			}
			if cmd.flow_hide_ui {
				hide_cmd: Ui_To_Render_Command
				hide_cmd.kind = .Hide_Ui
				_ = engine.queue_try_push(&app.ui_to_render, hide_cmd)
			}
		case .Configure_Gray_Scott:
			if cmd.gray_scott_set_mode {
				mode_cmd: Ui_To_Render_Command
				mode_cmd.kind = .Set_App_Mode
				mode_cmd.app_mode = .Gray_Scott
				_ = engine.queue_try_push(&app.ui_to_render, mode_cmd)
			}
			_ = mcp_enqueue_feature_command(app, .Gray_Scott, FEATURE_COMMAND_APPLY_SETTINGS, &cmd.gray_scott_settings)
			if cmd.gray_scott_reset {
				reset: Feature_Reset_Command
				_ = mcp_enqueue_feature_command(app, .Gray_Scott, FEATURE_COMMAND_RESET, &reset)
			}
			if cmd.gray_scott_seed_noise {
				reset := Feature_Reset_Command{seed_noise = true}
				_ = mcp_enqueue_feature_command(app, .Gray_Scott, FEATURE_COMMAND_RESET, &reset)
			}
			if cmd.gray_scott_hide_ui {
				hide_cmd: Ui_To_Render_Command
				hide_cmd.kind = .Hide_Ui
				_ = engine.queue_try_push(&app.ui_to_render, hide_cmd)
			}
		case .Configure_Remaining_Sim:
			if cmd.remaining_set_mode {
				mode_cmd: Ui_To_Render_Command
				mode_cmd.kind = .Set_App_Mode
				switch cmd.remaining_kind {
				case .Slime_Mold:
					mode_cmd.app_mode = .Slime_Mold
				case .Flow_Field:
					mode_cmd.app_mode = .Flow_Field
				case .Pellets:
					mode_cmd.app_mode = .Pellets
				case .Voronoi_CA:
					mode_cmd.app_mode = .Voronoi_CA
				case .Moire:
					mode_cmd.app_mode = .Moire
				case .Vectors:
					mode_cmd.app_mode = .Vectors
				case .Primordial:
					mode_cmd.app_mode = .Primordial
				}
				_ = engine.queue_try_push(&app.ui_to_render, mode_cmd)
			}
			switch cmd.remaining_kind {
			case .Slime_Mold: _ = mcp_enqueue_feature_command(app, .Slime_Mold, FEATURE_COMMAND_APPLY_SETTINGS, &cmd.slime_settings)
			case .Flow_Field: _ = mcp_enqueue_feature_command(app, .Flow_Field, FEATURE_COMMAND_APPLY_SETTINGS, &cmd.flow_settings)
			case .Pellets: _ = mcp_enqueue_feature_command(app, .Pellets, FEATURE_COMMAND_APPLY_SETTINGS, &cmd.pellets_settings)
			case .Voronoi_CA: _ = mcp_enqueue_feature_command(app, .Voronoi_CA, FEATURE_COMMAND_APPLY_SETTINGS, &cmd.voronoi_settings)
			case .Moire: _ = mcp_enqueue_feature_command(app, .Moire, FEATURE_COMMAND_APPLY_SETTINGS, &cmd.moire_settings)
			case .Vectors: _ = mcp_enqueue_feature_command(app, .Vectors, FEATURE_COMMAND_APPLY_SETTINGS, &cmd.vectors_settings)
			case .Primordial: _ = mcp_enqueue_feature_command(app, .Primordial, FEATURE_COMMAND_APPLY_SETTINGS, &cmd.primordial_settings)
			}
			if cmd.remaining_reset {
				mode := app_mode_from_remaining_sim_kind(cmd.remaining_kind)
				reset: Feature_Reset_Command
				_ = mcp_enqueue_feature_command(app, mode, FEATURE_COMMAND_RESET, &reset)
			}
			if cmd.remaining_hide_ui {
				hide_cmd: Ui_To_Render_Command
				hide_cmd.kind = .Hide_Ui
				_ = engine.queue_try_push(&app.ui_to_render, hide_cmd)
			}
		case .Hide_Ui:
			render_cmd: Ui_To_Render_Command
			render_cmd.kind = .Hide_Ui
			_ = engine.queue_try_push(&app.ui_to_render, render_cmd)
		case .Seed_Noise_Gray_Scott:
			reset := Feature_Reset_Command{seed_noise = true}
			_ = mcp_enqueue_feature_command(app, .Gray_Scott, FEATURE_COMMAND_RESET, &reset)
		case .Close:
			app.running = false
		case .Load_Vectors_Image:
			image := Feature_Image_Command{path = cmd.file_path}
			_ = mcp_enqueue_feature_command(app, .Vectors, FEATURE_COMMAND_LOAD_IMAGE, &image)
		case .Load_Moire_Image:
			image := Feature_Image_Command{path = cmd.file_path}
			_ = mcp_enqueue_feature_command(app, .Moire, FEATURE_COMMAND_LOAD_IMAGE, &image)
		case .Load_Flow_Image:
			image := Feature_Image_Command{path = cmd.file_path}
			_ = mcp_enqueue_feature_command(app, .Flow_Field, FEATURE_COMMAND_LOAD_IMAGE, &image)
		case .Load_Slime_Mask_Image:
			image := Feature_Image_Command{path = cmd.file_path, slot = 0}
			_ = mcp_enqueue_feature_command(app, .Slime_Mold, FEATURE_COMMAND_LOAD_IMAGE, &image)
		case .Load_Slime_Position_Image:
			image := Feature_Image_Command{path = cmd.file_path, slot = 1}
			_ = mcp_enqueue_feature_command(app, .Slime_Mold, FEATURE_COMMAND_LOAD_IMAGE, &image)
		}
	}
	bridge.pending_command_count = 0
}

mcp_bridge_publish_frame :: proc(bridge: ^Mcp_Bridge, app: ^App_State, width, height, logical_width, logical_height: i32) {
	sync.mutex_lock(&bridge.status_mutex)
	bridge.status.running = app.running
	bridge.status.frame_index = app.frame_index
	bridge.status.window_width = width
	bridge.status.window_height = height
	bridge.status.logical_window_width = logical_width
	bridge.status.logical_window_height = logical_height
	bridge.status.mouse_pos = app.input.mouse_pos
	bridge.status.mouse_down = app.input.mouse_down
	sync.mutex_unlock(&bridge.status_mutex)
}

mcp_bridge_publish_render_message :: proc(bridge: ^Mcp_Bridge, msg: Render_To_Ui_Message) {
	sync.mutex_lock(&bridge.status_mutex)
	if msg.kind == .Frame_Stats {
		bridge.status.last_fps = msg.fps
		bridge.status.last_frame_ms = msg.frame_ms
		bridge.status.app_mode = msg.app_mode
		bridge.status.gray_scott_camera_x = msg.gray_scott_camera_x
		bridge.status.gray_scott_camera_y = msg.gray_scott_camera_y
		bridge.status.gray_scott_camera_zoom = msg.gray_scott_camera_zoom
		bridge.status.gray_scott_controls_visible = msg.gray_scott_controls_visible
		bridge.status.gray_scott_paused = msg.gray_scott_paused
		bridge.status.particle_life_camera_x = msg.particle_life_camera_x
		bridge.status.particle_life_camera_y = msg.particle_life_camera_y
		bridge.status.particle_life_camera_zoom = msg.particle_life_camera_zoom
		bridge.status.particle_life_ready = msg.particle_life_ready
		bridge.status.particle_life_paused = msg.particle_life_paused
		bridge.status.particle_life_controls_visible = msg.particle_life_controls_visible
		bridge.status.particle_life_frame_index = msg.particle_life_frame_index
		bridge.status.particle_life_particle_count = msg.particle_life_particle_count
		bridge.status.particle_life_species_count = msg.particle_life_species_count
		bridge.status.particle_life_requested_particle_count = msg.particle_life_requested_particle_count
		bridge.status.particle_life_requested_species_count = msg.particle_life_requested_species_count
		bridge.status.particle_life_trails_enabled = msg.particle_life_trails_enabled
		bridge.status.particle_life_infinite_tiles_enabled = msg.particle_life_infinite_tiles_enabled
		bridge.status.gpu_profiling_supported = msg.gpu_profiling_supported
		bridge.status.gpu_profiling_enabled = msg.gpu_profiling_enabled
		bridge.status.gpu_simulation_step_ms = msg.gpu_simulation_step_ms
		bridge.status.gpu_simulation_present_ms = msg.gpu_simulation_present_ms
		bridge.status.gpu_ui_overlay_ms = msg.gpu_ui_overlay_ms
		bridge.status.gpu_frame_total_ms = msg.gpu_frame_total_ms
		bridge.status.gpu_pellets_grid_clear_ms = msg.gpu_pellets_grid_clear_ms
		bridge.status.gpu_pellets_grid_build_ms = msg.gpu_pellets_grid_build_ms
		bridge.status.gpu_pellets_grid_scatter_ms = msg.gpu_pellets_grid_scatter_ms
		bridge.status.gpu_pellets_physics_ms = msg.gpu_pellets_physics_ms
		bridge.status.gpu_pellets_density_ms = msg.gpu_pellets_density_ms
		bridge.status.gpu_pellets_particle_draw_ms = msg.gpu_pellets_particle_draw_ms
		bridge.status.sim_ms = msg.sim_ms
		bridge.status.ui_ms = msg.ui_ms
		bridge.status.render_ms = msg.render_ms
		bridge.status.submit_ms = msg.submit_ms
		bridge.status.screenshot_ms = msg.screenshot_ms
		bridge.status.screenshot_captured = msg.screenshot_captured
		bridge.status.ui_build_ms = msg.ui_build_ms
		bridge.status.ui_overlay_ms = msg.ui_overlay_ms
		bridge.status.gui_command_count = msg.gui_command_count
		bridge.status.ui_vertex_count = msg.ui_vertex_count
		bridge.status.ui_batch_count = msg.ui_batch_count
		bridge.status.ui_clear_rect_count = msg.ui_clear_rect_count
		bridge.status.main_menu_preview_visible_slot_count = msg.main_menu_preview_visible_slot_count
		bridge.status.main_menu_preview_warmed_mode_count = msg.main_menu_preview_warmed_mode_count
		bridge.status.main_menu_preview_fallback_fill_count = msg.main_menu_preview_fallback_fill_count
		bridge.status.main_menu_preview_skipped_present_count = msg.main_menu_preview_skipped_present_count
		bridge.status.text_width_calls = msg.text_width_calls
		bridge.status.text_width_cache_hits = msg.text_width_cache_hits
		bridge.status.text_width_ms = msg.text_width_ms
		bridge.status.text_shape_calls = msg.text_shape_calls
		bridge.status.text_shape_glyphs = msg.text_shape_glyphs
		bridge.status.text_shape_ms = msg.text_shape_ms
		bridge.status.text_wrap_calls = msg.text_wrap_calls
		bridge.status.text_wrap_ms = msg.text_wrap_ms
		bridge.status.cpu_wait_fence_ms = msg.cpu_wait_fence_ms
		bridge.status.cpu_acquire_ms = msg.cpu_acquire_ms
		bridge.status.cpu_command_begin_ms = msg.cpu_command_begin_ms
		bridge.status.cpu_end_command_ms = msg.cpu_end_command_ms
		bridge.status.cpu_queue_submit_ms = msg.cpu_queue_submit_ms
		bridge.status.cpu_queue_present_ms = msg.cpu_queue_present_ms
		bridge.status.present_mode = msg.present_mode
		bridge.status.command_render_pass_count = msg.command_render_pass_count
		bridge.status.command_compute_dispatch_count = msg.command_compute_dispatch_count
		bridge.status.command_draw_count = msg.command_draw_count
		bridge.status.command_pipeline_bind_count = msg.command_pipeline_bind_count
		bridge.status.command_descriptor_bind_count = msg.command_descriptor_bind_count
		bridge.status.command_pipeline_barrier_count = msg.command_pipeline_barrier_count
		bridge.status.command_transfer_copy_count = msg.command_transfer_copy_count
		bridge.status.command_ui_batch_count = msg.command_ui_batch_count
		bridge.status.command_backdrop_blur_pass_count = msg.command_backdrop_blur_pass_count
		mcp_bridge_profile_record_locked(bridge, msg)
	} else {
		bridge.status.last_message = msg.text
	}
	sync.mutex_unlock(&bridge.status_mutex)
}

mcp_bridge_status_json :: proc(bridge: ^Mcp_Bridge) -> string {
	sync.mutex_lock(&bridge.status_mutex)
	status := bridge.status
	sync.mutex_unlock(&bridge.status_mutex)
	queue_status := mcp_bridge_command_queue_status(bridge)

	builder: strings.Builder
	strings.builder_init(&builder, context.temp_allocator)
	strings.write_string(&builder, fmt.tprintf(
		"{{\"ok\":true,\"running\":%v,\"frame_index\":%d,\"window_width\":%d,\"window_height\":%d,\"logical_window_width\":%d,\"logical_window_height\":%d,\"mouse_x\":%.2f,\"mouse_y\":%.2f,\"mouse_down\":%v,\"fps\":%.2f,\"frame_ms\":%.2f,\"app_mode\":\"%v\"",
		status.running,
		status.frame_index,
		status.window_width,
		status.window_height,
		status.logical_window_width,
		status.logical_window_height,
		status.mouse_pos.x,
		status.mouse_pos.y,
		status.mouse_down,
		status.last_fps,
		status.last_frame_ms,
		status.app_mode,
	))
	strings.write_string(&builder, fmt.tprintf(
		",\"gray_scott_camera_x\":%.4f,\"gray_scott_camera_y\":%.4f,\"gray_scott_camera_zoom\":%.4f,\"gray_scott_controls_visible\":%v,\"gray_scott_paused\":%v",
		status.gray_scott_camera_x,
		status.gray_scott_camera_y,
		status.gray_scott_camera_zoom,
		status.gray_scott_controls_visible,
		status.gray_scott_paused,
	))
	strings.write_string(&builder, fmt.tprintf(
		",\"particle_life_camera_x\":%.4f,\"particle_life_camera_y\":%.4f,\"particle_life_camera_zoom\":%.4f,\"particle_life_ready\":%v,\"particle_life_paused\":%v,\"particle_life_controls_visible\":%v,\"particle_life_frame_index\":%d,\"particle_life_particle_count\":%d,\"particle_life_species_count\":%d,\"particle_life_requested_particle_count\":%d,\"particle_life_requested_species_count\":%d,\"particle_life_trails_enabled\":%v,\"particle_life_infinite_tiles_enabled\":%v",
		status.particle_life_camera_x,
		status.particle_life_camera_y,
		status.particle_life_camera_zoom,
		status.particle_life_ready,
		status.particle_life_paused,
		status.particle_life_controls_visible,
		status.particle_life_frame_index,
		status.particle_life_particle_count,
		status.particle_life_species_count,
		status.particle_life_requested_particle_count,
		status.particle_life_requested_species_count,
		status.particle_life_trails_enabled,
		status.particle_life_infinite_tiles_enabled,
	))
	strings.write_string(&builder, fmt.tprintf(
		",\"gpu_profiling_supported\":%v,\"gpu_profiling_enabled\":%v,\"gpu_simulation_step_ms\":%.4f,\"gpu_simulation_present_ms\":%.4f,\"gpu_ui_overlay_ms\":%.4f,\"gpu_frame_total_ms\":%.4f,\"gpu_pellets_grid_clear_ms\":%.4f,\"gpu_pellets_grid_build_ms\":%.4f,\"gpu_pellets_grid_scatter_ms\":%.4f,\"gpu_pellets_physics_ms\":%.4f,\"gpu_pellets_density_ms\":%.4f,\"gpu_pellets_particle_draw_ms\":%.4f,\"sim_ms\":%.4f,\"ui_ms\":%.4f,\"render_ms\":%.4f,\"submit_ms\":%.4f,\"screenshot_ms\":%.4f,\"screenshot_captured\":%v,\"ui_build_ms\":%.4f,\"ui_overlay_ms\":%.4f",
		status.gpu_profiling_supported,
		status.gpu_profiling_enabled,
		status.gpu_simulation_step_ms,
		status.gpu_simulation_present_ms,
		status.gpu_ui_overlay_ms,
		status.gpu_frame_total_ms,
		status.gpu_pellets_grid_clear_ms,
		status.gpu_pellets_grid_build_ms,
		status.gpu_pellets_grid_scatter_ms,
		status.gpu_pellets_physics_ms,
		status.gpu_pellets_density_ms,
		status.gpu_pellets_particle_draw_ms,
		status.sim_ms,
		status.ui_ms,
		status.render_ms,
		status.submit_ms,
		status.screenshot_ms,
		status.screenshot_captured,
		status.ui_build_ms,
		status.ui_overlay_ms,
	))
	strings.write_string(&builder, fmt.tprintf(
		",\"gui_command_count\":%d,\"ui_vertex_count\":%d,\"ui_batch_count\":%d,\"ui_clear_rect_count\":%d,\"main_menu_preview_visible_slot_count\":%d,\"main_menu_preview_warmed_mode_count\":%d,\"main_menu_preview_fallback_fill_count\":%d,\"main_menu_preview_skipped_present_count\":%d",
		status.gui_command_count,
		status.ui_vertex_count,
		status.ui_batch_count,
		status.ui_clear_rect_count,
		status.main_menu_preview_visible_slot_count,
		status.main_menu_preview_warmed_mode_count,
		status.main_menu_preview_fallback_fill_count,
		status.main_menu_preview_skipped_present_count,
	))
	strings.write_string(&builder, fmt.tprintf(
		",\"text_width_calls\":%d,\"text_width_cache_hits\":%d,\"text_width_ms\":%.4f,\"text_shape_calls\":%d,\"text_shape_glyphs\":%d,\"text_shape_ms\":%.4f,\"text_wrap_calls\":%d,\"text_wrap_ms\":%.4f,\"cpu_wait_fence_ms\":%.4f,\"cpu_acquire_ms\":%.4f,\"cpu_command_begin_ms\":%.4f,\"cpu_end_command_ms\":%.4f,\"cpu_queue_submit_ms\":%.4f,\"cpu_queue_present_ms\":%.4f,\"present_mode\":\"%s\"",
		status.text_width_calls,
		status.text_width_cache_hits,
		status.text_width_ms,
		status.text_shape_calls,
		status.text_shape_glyphs,
		status.text_shape_ms,
		status.text_wrap_calls,
		status.text_wrap_ms,
		status.cpu_wait_fence_ms,
		status.cpu_acquire_ms,
		status.cpu_command_begin_ms,
		status.cpu_end_command_ms,
		status.cpu_queue_submit_ms,
		status.cpu_queue_present_ms,
		mcp_bridge_json_escape(fixed_string(status.present_mode[:])),
	))
	strings.write_string(&builder, fmt.tprintf(
		",\"command_render_pass_count\":%d,\"command_compute_dispatch_count\":%d,\"command_draw_count\":%d,\"command_pipeline_bind_count\":%d,\"command_descriptor_bind_count\":%d,\"command_pipeline_barrier_count\":%d,\"command_transfer_copy_count\":%d,\"command_ui_batch_count\":%d,\"command_backdrop_blur_pass_count\":%d,\"command_queue_count\":%d,\"command_queue_closed\":%v,\"last_message\":\"%s\"}}",
		status.command_render_pass_count,
		status.command_compute_dispatch_count,
		status.command_draw_count,
		status.command_pipeline_bind_count,
		status.command_descriptor_bind_count,
		status.command_pipeline_barrier_count,
		status.command_transfer_copy_count,
		status.command_ui_batch_count,
		status.command_backdrop_blur_pass_count,
		queue_status.count,
		queue_status.closed,
		mcp_bridge_json_escape(fixed_string(status.last_message[:])),
	))
	return strings.to_string(builder)
}

mcp_bridge_gpu_status_json :: proc(bridge: ^Mcp_Bridge) -> string {
	sync.mutex_lock(&bridge.status_mutex)
	status := bridge.status
	sync.mutex_unlock(&bridge.status_mutex)
	return fmt.tprintf(
		"{{\"ok\":true,\"fps\":%.2f,\"frame_ms\":%.4f,\"gpu_supported\":%v,\"gpu_enabled\":%v,\"gpu_step_ms\":%.4f,\"gpu_present_ms\":%.4f,\"gpu_ui_ms\":%.4f,\"gpu_frame_ms\":%.4f,\"render_ms\":%.4f,\"submit_ms\":%.4f,\"screenshot_ms\":%.4f,\"draws\":%d,\"dispatches\":%d,\"render_passes\":%d}}",
		status.last_fps,
		status.last_frame_ms,
		status.gpu_profiling_supported,
		status.gpu_profiling_enabled,
		status.gpu_simulation_step_ms,
		status.gpu_simulation_present_ms,
		status.gpu_ui_overlay_ms,
		status.gpu_frame_total_ms,
		status.render_ms,
		status.submit_ms,
		status.screenshot_ms,
		status.command_draw_count,
		status.command_compute_dispatch_count,
		status.command_render_pass_count,
	)
}
