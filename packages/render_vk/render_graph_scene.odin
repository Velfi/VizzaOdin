package render_vk

import uifw "../ui"
import engine "../engine"

import "core:math"
import "core:time"
import vk "vendor:vulkan"

render_context_scene_post_processing_settings :: proc(ctx: ^Render_Context) -> ^Post_Processing_Settings {
	if ctx == nil {
		return nil
	}
	#partial switch ctx.app_mode {
	case .Particle_Life:
		if ctx.particle_life != nil {
			return &ctx.particle_life.settings.post_processing
		}
	case .Primordial:
		if ctx.app_ui != nil {
			return &ctx.app_ui.primordial.primordial.post_processing
		}
	case .Pellets:
		if ctx.app_ui != nil {
			return &ctx.app_ui.pellets.pellets.post_processing
		}
	case .Flow_Field:
		if ctx.app_ui != nil {
			return &ctx.app_ui.flow_field.flow.post_processing
		}
	case .Slime_Mold:
		if ctx.app_ui != nil {
			return &ctx.app_ui.slime_mold.slime.post_processing
		}
	case .Voronoi_CA:
		if ctx.app_ui != nil {
			return &ctx.app_ui.voronoi_ca.voronoi.post_processing
		}
	case:
	}
	return nil
}

render_context_scene_blur_enabled :: proc(ctx: ^Render_Context) -> bool {
	settings := render_context_scene_post_processing_settings(ctx)
	return settings != nil && settings.blur_enabled && settings.blur_radius > 0
}

render_context_apply_scene_post_processing :: proc(ctx: ^Render_Context) {
	settings := render_context_scene_post_processing_settings(ctx)
	if settings == nil || !settings.blur_enabled || settings.blur_radius <= 0 {
		return
	}
	_ = post_processing_apply_blur(&ctx.backend.post_processing, ctx.vk_ctx, ctx.frame, settings)
}

render_pass_simulation_present :: proc(ctx: ^Render_Context, pass: ^Render_Pass_Node) -> bool {
	_ = pass
	engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "Simulation present")
	engine.gpu_profiler_begin_pass(ctx.vk_ctx, ctx.frame.command_buffer, ctx.frame, .Simulation_Present)
	defer engine.gpu_profiler_end_pass(ctx.vk_ctx, ctx.frame.command_buffer, ctx.frame, .Simulation_Present)
	defer engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
	clear_color := uifw.Color{0.09, 0.105, 0.125, 1}
	force_late_ui_overlay := video_capture_is_recording(ctx.video_capture) || render_context_scene_blur_enabled(ctx)
	draw_ui_in_pass := ui_renderer_has_overlay_work(&ctx.backend.ui) && !ui_renderer_needs_backdrop_capture(&ctx.backend.ui) && !force_late_ui_overlay
	ui_sink := render_backend_ui_sink(ctx.backend)
	if ctx.app_mode == .Main_Menu {
		engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, clear_color)
		main_menu_backdrop_draw(&ctx.backend.main_menu_backdrop, ctx.vk_ctx, ctx.frame, ctx.dt)
		render_pass_main_menu_preview_present(ctx)
		if draw_ui_in_pass {
			ui_start := time.tick_now()
			engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
			ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
			engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		}
		engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
		return true
	}
	if ctx.app_mode == .Particle_Life {
		if ctx.particle_life.gpu.ready {
			if draw_ui_in_pass {
				particle_life_gpu_present(ctx.particle_life, ctx.vk_ctx, ctx.frame, &ui_sink)
			} else {
				particle_life_gpu_present(ctx.particle_life, ctx.vk_ctx, ctx.frame, nil)
			}
		} else {
			engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, particle_life_clear_color(ctx.particle_life))
			if draw_ui_in_pass {
				ui_start := time.tick_now()
				engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
				ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
				engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
				ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
			}
			engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
		}
		render_context_apply_scene_post_processing(ctx)
		return true
	}
	if ctx.app_mode == .Vectors && ctx.app_ui != nil && ctx.vectors_gpu != nil {
		_ = vectors_gpu_prepare_viewport(ctx.vectors_gpu, ctx.vk_ctx, &ctx.app_ui.vectors.vectors, ctx.app_ui.vectors.time, f32(ctx.vk_ctx.swapchain_extent.width), f32(ctx.vk_ctx.swapchain_extent.height))
		vectors_gpu_dispatch_field(ctx.vectors_gpu, ctx.vk_ctx, ctx.frame.command_buffer)
		engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, vectors_clear_color(&ctx.app_ui.vectors.vectors))
		vectors_gpu_draw_prepared_viewport(ctx.vectors_gpu, ctx.vk_ctx, ctx.frame, {x = 0, y = 0, width = f32(ctx.vk_ctx.swapchain_extent.width), height = f32(ctx.vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}, {offset = {0, 0}, extent = ctx.vk_ctx.swapchain_extent})
		if draw_ui_in_pass {
			ui_start := time.tick_now()
			engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
			ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
			engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		}
		engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
		return true
	}
	if ctx.app_mode == .Moire && ctx.app_ui != nil && ctx.moire_gpu != nil {
		engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, clear_color)
		moire_gpu_present(ctx.moire_gpu, ctx.vk_ctx, ctx.frame)
		if draw_ui_in_pass {
			ui_start := time.tick_now()
			engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
			ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
			engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		}
		engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
		return true
	}
	if ctx.app_mode == .Primordial && ctx.app_ui != nil && ctx.primordial_gpu != nil {
		ui: ^Ui_Render_Sink
		if draw_ui_in_pass {
			ui = &ui_sink
			ui_start := time.tick_now()
			primordial_gpu_present(ctx.primordial_gpu, ctx.vk_ctx, ctx.frame, &ctx.app_ui.primordial, ui)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		} else {
			primordial_gpu_present(ctx.primordial_gpu, ctx.vk_ctx, ctx.frame, &ctx.app_ui.primordial, nil)
		}
		render_context_apply_scene_post_processing(ctx)
		return true
	}
	if ctx.app_mode == .Pellets && ctx.app_ui != nil && ctx.pellets_gpu != nil {
		ui: ^Ui_Render_Sink
		if draw_ui_in_pass {
			ui = &ui_sink
			ui_start := time.tick_now()
			pellets_gpu_present(ctx.pellets_gpu, ctx.vk_ctx, ctx.frame, &ctx.app_ui.pellets, ui)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		} else {
			pellets_gpu_present(ctx.pellets_gpu, ctx.vk_ctx, ctx.frame, &ctx.app_ui.pellets, nil)
		}
		render_context_apply_scene_post_processing(ctx)
		return true
	}
	if ctx.app_mode == .Flow_Field && ctx.app_ui != nil && ctx.flow_gpu != nil {
		engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, flow_clear_color(&ctx.app_ui.flow_field.flow))
		flow_gpu_present(ctx.flow_gpu, ctx.vk_ctx, ctx.frame)
		if draw_ui_in_pass {
			ui_start := time.tick_now()
			engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
			ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
			engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		}
		engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
		render_context_apply_scene_post_processing(ctx)
		return true
	}
	if ctx.app_mode == .Slime_Mold && ctx.app_ui != nil && ctx.slime_gpu != nil {
		engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, slime_clear_color(&ctx.app_ui.slime_mold.slime))
		slime_gpu_present(ctx.slime_gpu, ctx.vk_ctx, ctx.frame, &ctx.app_ui.slime_mold.camera)
		if draw_ui_in_pass {
			ui_start := time.tick_now()
			engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
			ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
			engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		}
		engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
		render_context_apply_scene_post_processing(ctx)
		return true
	}
	if ctx.app_mode == .Voronoi_CA && ctx.app_ui != nil && ctx.voronoi_gpu != nil {
		engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, voronoi_clear_color())
		voronoi_gpu_present(ctx.voronoi_gpu, ctx.vk_ctx, ctx.frame, &ctx.app_ui.voronoi_ca.camera)
		if draw_ui_in_pass {
			ui_start := time.tick_now()
			engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
			ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
			engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		}
		engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
		render_context_apply_scene_post_processing(ctx)
		return true
	}
	engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, clear_color)
	if ctx.app_mode == .Gray_Scott && gray_scott_ensure_gpu_runtime(ctx.sim, ctx.vk_ctx) {
		gray_scott_gpu_present(ctx.sim, ctx.vk_ctx, ctx.frame.command_buffer)
	}
	if draw_ui_in_pass {
		ui_start := time.tick_now()
		engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
		ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
		engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
		ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
	}
	engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
	return true
}

render_pass_ui_build :: proc(ctx: ^Render_Context, pass: ^Render_Pass_Node) -> bool {
	_ = pass
	start := time.tick_now()
	ok := ui_renderer_build(&ctx.backend.ui, ctx.vk_ctx, ctx.gui.commands[:])
	ctx.backend.last_ui_build_seconds = time.duration_seconds(time.tick_diff(start, time.tick_now()))
	return ok
}

render_pass_ui_overlay :: proc(ctx: ^Render_Context, pass: ^Render_Pass_Node) -> bool {
	_ = pass
	if !ui_renderer_has_overlay_work(&ctx.backend.ui) {
		return true
	}
	force_late_ui_overlay := video_capture_is_recording(ctx.video_capture) || render_context_scene_blur_enabled(ctx)
	if !force_late_ui_overlay && !ui_renderer_needs_backdrop_capture(&ctx.backend.ui) {
		return true
	}
	start := time.tick_now()
	engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
	engine.gpu_profiler_begin_pass(ctx.vk_ctx, ctx.frame.command_buffer, ctx.frame, .Ui_Overlay)
	defer engine.gpu_profiler_end_pass(ctx.vk_ctx, ctx.frame.command_buffer, ctx.frame, .Ui_Overlay)
	defer engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
	if !ui_renderer_prepare_backdrop_blur(&ctx.backend.ui, ctx.vk_ctx, ctx.frame) {
		vk_cmd_transition_swapchain_present_to_color(ctx.vk_ctx, ctx.frame)
	}
	engine.vk_cmd_begin_swapchain_render_pass_load(ctx.vk_ctx, ctx.frame)
	ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
	engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
	ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(start, time.tick_now()))
	return true
}
