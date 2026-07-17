package render_vk

import uifw "../ui"
import engine "../engine"

import "core:time"

render_context_scene_post_processing_settings :: proc(ctx: ^Render_Context, out: ^Post_Processing_Settings) -> bool {
	if ctx == nil || out == nil do return false
	descriptor, ok := render_feature_descriptor_by_mode(ctx.app_mode)
	return ok && descriptor.get_post_processing != nil && descriptor.get_post_processing(ctx, out)
}

render_feature_post_processing_particle_life :: proc(ctx: ^Render_Context, out: ^Post_Processing_Settings) -> bool {if ctx == nil || render_context_particle_life(ctx) == nil || out == nil do return false; out^ = render_context_particle_life(ctx).settings.post_processing; return true}
render_feature_post_processing_slime :: proc(ctx: ^Render_Context, out: ^Post_Processing_Settings) -> bool {if ctx == nil || ctx.app_ui == nil || out == nil do return false; out^ = ctx.app_ui.slime_mold.slime.post_processing; return true}
render_feature_post_processing_flow :: proc(ctx: ^Render_Context, out: ^Post_Processing_Settings) -> bool {if ctx == nil || ctx.app_ui == nil || out == nil do return false; out^ = ctx.app_ui.flow_field.flow.post_processing; return true}
render_feature_post_processing_pellets :: proc(ctx: ^Render_Context, out: ^Post_Processing_Settings) -> bool {if ctx == nil || ctx.app_ui == nil || out == nil do return false; out^ = ctx.app_ui.pellets.pellets.post_processing; return true}
render_feature_post_processing_st_flip :: proc(ctx: ^Render_Context, out: ^Post_Processing_Settings) -> bool {if ctx == nil || ctx.app_ui == nil || out == nil do return false; out^ = ctx.app_ui.st_flip.settings.post_processing; return true}
render_feature_post_processing_voronoi :: proc(ctx: ^Render_Context, out: ^Post_Processing_Settings) -> bool {if ctx == nil || ctx.app_ui == nil || out == nil do return false; out^ = ctx.app_ui.voronoi_ca.voronoi.post_processing; return true}
render_feature_post_processing_primordial :: proc(ctx: ^Render_Context, out: ^Post_Processing_Settings) -> bool {if ctx == nil || ctx.app_ui == nil || out == nil do return false; out^ = ctx.app_ui.primordial.primordial.post_processing; return true}

render_context_scene_blur_enabled :: proc(ctx: ^Render_Context) -> bool {
	settings: Post_Processing_Settings
	return render_context_scene_post_processing_settings(ctx, &settings) && settings.blur_enabled && settings.blur_radius > 0
}

render_context_apply_scene_post_processing :: proc(ctx: ^Render_Context) {
	settings: Post_Processing_Settings
	if !render_context_scene_post_processing_settings(ctx, &settings) || !settings.blur_enabled || settings.blur_radius <= 0 {
		return
	}
	_ = post_processing_apply_blur(&ctx.backend.post_processing, ctx.vk_ctx, ctx.frame, &settings)
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
		// Graph barriers have transitioned every preview output to its declared
		// presentation state before this callback. Preparation now only updates
		// descriptors/cameras and observes those graph-owned layouts.
		render_pass_main_menu_preview_prepare(ctx)
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
	if descriptor, ok := render_feature_descriptor_by_mode(ctx.app_mode); ok {
		return descriptor.present(ctx, draw_ui_in_pass, &ui_sink)
	}
	// Non-feature screens only need the shared clear and UI presentation path.
	engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, clear_color)
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
	ok := ui_renderer_build(&ctx.backend.ui, ctx.vk_ctx, ctx.gui.paint_commands[:])
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
	}
	engine.vk_cmd_begin_swapchain_render_pass_load(ctx.vk_ctx, ctx.frame)
	ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
	engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
	ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(start, time.tick_now()))
	return true
}
