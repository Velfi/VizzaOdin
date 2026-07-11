package render_vk

import uifw "../ui"
import engine "../engine"

import "core:math"
import "core:time"
import vk "vendor:vulkan"

render_main_menu_preview_mode_visible :: proc(ctx: ^Render_Context, mode: App_Mode) -> bool {
	if ctx == nil || ctx.app_ui == nil || ctx.app_ui.main_menu_preview_slot_count <= 0 {
		return false
	}
	count := min(ctx.app_ui.main_menu_preview_slot_count, MAIN_MENU_PREVIEW_SLOT_CAP)
	for i in 0 ..< count {
		slot := ctx.app_ui.main_menu_preview_slots[i]
		if slot.mode == mode && slot.clip_rect.w > 1 && slot.clip_rect.h > 1 {
			return true
		}
	}
	return false
}

render_pass_main_menu_preview_prepare :: proc(ctx: ^Render_Context) {
	if ctx.app_ui == nil || ctx.app_ui.main_menu_preview_slot_count <= 0 {
		return
	}
	count := min(ctx.app_ui.main_menu_preview_slot_count, MAIN_MENU_PREVIEW_SLOT_CAP)
	for i in 0 ..< count {
		render_pass_main_menu_preview_prepare_slot(ctx, ctx.app_ui.main_menu_preview_slots[i])
	}
}

render_pass_main_menu_preview_prepare_slot :: proc(ctx: ^Render_Context, slot: Main_Menu_Preview_Slot) {
	if slot.clip_rect.w <= 1 || slot.clip_rect.h <= 1 {
		return
	}
	viewport: vk.Viewport
	scissor: vk.Rect2D
	if !render_main_menu_preview_viewport_for_rect(ctx, slot.rect, slot.clip_rect, &viewport, &scissor) {
		return
	}
	cmd := ctx.frame.command_buffer
	frame_slot := int(ctx.frame.frame_index)
	#partial switch slot.mode {
	case .Gray_Scott:
		sim := ctx.preview_gray_scott
		if sim != nil {
			_ = gray_scott_gpu_prepare_present_viewport(sim, ctx.vk_ctx, cmd)
		}
	case .Slime_Mold:
		gpu := ctx.preview_slime_gpu
		if gpu != nil && gpu.ready && gpu.display_image.handle != vk.Image(0) && gpu.display_image.layout != .SHADER_READ_ONLY_OPTIMAL {
			slime_transition_image(ctx.vk_ctx, cmd, &gpu.display_image, .SHADER_READ_ONLY_OPTIMAL)
		}
		if gpu != nil && gpu.ready {
			slime_upload_camera(gpu, frame_slot)
		}
	case .Flow_Field:
		gpu := ctx.preview_flow_gpu
		if gpu != nil && gpu.ready {
			flow_upload_camera_size(gpu, frame_slot, viewport.width, viewport.height)
			flow_update_descriptors_for_slot(gpu, ctx.vk_ctx, frame_slot)
			if gpu.trail_pipeline.pipeline != vk.Pipeline(0) && gpu.trail_image.handle != vk.Image(0) {
				flow_transition_image(ctx.vk_ctx, cmd, &gpu.trail_image, .GENERAL)
			}
		}
	case .Pellets:
		gpu := ctx.preview_pellets_gpu
		if gpu != nil && gpu.ready {
			preview_pellets := render_main_menu_pellets_preview_state(&ctx.app_ui.pellets)
			render_main_menu_apply_pellets_palette(&preview_pellets.pellets, render_main_menu_preview_palette_name(ctx))
			pellets_upload_lut(gpu, &preview_pellets.pellets)
			pellets_write_static_params_size(gpu, frame_slot, viewport.width * 2, viewport.height * 2, &preview_pellets.pellets)
			pellets_update_descriptors_for_slot(gpu, ctx.vk_ctx, frame_slot)
		}
	case .Voronoi_CA:
		gpu := ctx.preview_voronoi_gpu
		if gpu != nil && gpu.ready {
			image := gpu.jfa_result_is_scratch ? &gpu.jfa_scratch_image : &gpu.jfa_image
			if image.handle != vk.Image(0) && image.layout != .SHADER_READ_ONLY_OPTIMAL {
				voronoi_transition_image(ctx.vk_ctx, cmd, image, .SHADER_READ_ONLY_OPTIMAL)
			}
		}
	case .Moire:
		gpu := ctx.preview_moire_gpu
		if gpu != nil && gpu.ready && gpu.state_index < 2 {
			index := int(gpu.state_index)
			if gpu.images[index].handle != vk.Image(0) && gpu.images[index].layout != .SHADER_READ_ONLY_OPTIMAL {
				moire_transition_image(gpu, ctx.vk_ctx, index, .SHADER_READ_ONLY_OPTIMAL, cmd)
			}
			moire_update_texture_descriptor(gpu, ctx.vk_ctx, frame_slot, index)
		}
		if gpu != nil && gpu.ready {
			moire_upload_camera(gpu, frame_slot)
		}
	case .Primordial:
		gpu := ctx.preview_primordial_gpu
		if gpu != nil && gpu.ready {
			preview_primordial := render_main_menu_primordial_preview_state(&ctx.app_ui.primordial)
			render_main_menu_apply_primordial_palette(&preview_primordial.primordial, render_main_menu_preview_palette_name(ctx))
			primordial_upload_lut(gpu, &preview_primordial.primordial)
			primordial_upload_camera(gpu, frame_slot, viewport.width, viewport.height)
			primordial_upload_render_params_for_extent(gpu, frame_slot, &preview_primordial.primordial, viewport.width, viewport.height)
			primordial_upload_background_params(gpu, frame_slot, &preview_primordial.primordial)
			primordial_update_descriptors_for_slot(gpu, ctx.vk_ctx, frame_slot)
		}
	}
}

render_main_menu_preview_supported_mode_count :: proc() -> u32 {
	return 9
}

render_main_menu_preview_palette_name :: proc(ctx: ^Render_Context) -> string {
	if ctx == nil || ctx.backend == nil {
		return COLOR_SCHEME_DEFAULT_NAME
	}
	name := main_menu_backdrop_current_palette_name(&ctx.backend.main_menu_backdrop)
	if len(name) == 0 {
		return COLOR_SCHEME_DEFAULT_NAME
	}
	return name
}

render_main_menu_apply_preview_palette :: proc(color_scheme: ^Color_Scheme_Name, reversed: ^bool, palette_name: string) {
	name := palette_name
	if len(name) == 0 {
		name = COLOR_SCHEME_DEFAULT_NAME
	}
	color_scheme_name_set(color_scheme, name)
	reversed^ = true
}

render_main_menu_apply_gray_scott_palette :: proc(settings: ^Gray_Scott_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_particle_life_palette :: proc(settings: ^Particle_Life_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_moire_palette :: proc(settings: ^Moire_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_vectors_palette :: proc(settings: ^Vectors_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_primordial_palette :: proc(settings: ^Primordial_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_voronoi_palette :: proc(settings: ^Voronoi_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_pellets_palette :: proc(settings: ^Pellets_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_flow_palette :: proc(settings: ^Flow_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_slime_palette :: proc(settings: ^Slime_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_palette_to_mode :: proc(app_ui: ^App_Ui_State, gray_scott: ^Gray_Scott_Settings, particle_life: ^Particle_Life_Settings, mode: App_Mode, palette_name: string) -> bool {
	#partial switch mode {
	case .Slime_Mold:
		if app_ui == nil {return false}
		render_main_menu_apply_slime_palette(&app_ui.slime_mold.slime, palette_name)
	case .Gray_Scott:
		if gray_scott == nil {return false}
		render_main_menu_apply_gray_scott_palette(gray_scott, palette_name)
	case .Particle_Life:
		if particle_life == nil {return false}
		render_main_menu_apply_particle_life_palette(particle_life, palette_name)
	case .Flow_Field:
		if app_ui == nil {return false}
		render_main_menu_apply_flow_palette(&app_ui.flow_field.flow, palette_name)
	case .Pellets:
		if app_ui == nil {return false}
		render_main_menu_apply_pellets_palette(&app_ui.pellets.pellets, palette_name)
	case .Voronoi_CA:
		if app_ui == nil {return false}
		render_main_menu_apply_voronoi_palette(&app_ui.voronoi_ca.voronoi, palette_name)
	case .Moire:
		if app_ui == nil {return false}
		render_main_menu_apply_moire_palette(&app_ui.moire.moire, palette_name)
	case .Vectors:
		if app_ui == nil {return false}
		render_main_menu_apply_vectors_palette(&app_ui.vectors.vectors, palette_name)
	case .Primordial:
		if app_ui == nil {return false}
		render_main_menu_apply_primordial_palette(&app_ui.primordial.primordial, palette_name)
	case:
		return false
	}
	return true
}

render_main_menu_particle_life_preview_settings :: proc(source: Particle_Life_Settings) -> Particle_Life_Settings {
	preview := source
	preview.particle_count = min(max(source.particle_count, 1), 2400)
	preview.particle_size = max(source.particle_size, 3)
	preview.camera_zoom = 1
	preview.cursor_strength = 0
	preview.trails_enabled = false
	preview.infinite_tiles_enabled = false
	preview.paused = false
	return preview
}

render_main_menu_flow_preview_state :: proc(source: ^Remaining_Sim_State) -> Remaining_Sim_State {
	preview := source^
	preview.paused = false
	preview.cursor_active = 0
	preview.flow.total_pool_size = min(max(source.flow.total_pool_size, 1), 6000)
	preview.flow.autospawn_rate = min(max(source.flow.autospawn_rate, 1), 180)
	preview.flow.brush_spawn_rate = min(max(source.flow.brush_spawn_rate, 1), 300)
	preview.flow.particle_size = min(max(source.flow.particle_size, 1), 3)
	preview.flow.particle_speed = min(source.flow.particle_speed, 1.0)
	preview.flow.particle_lifetime = min(source.flow.particle_lifetime, 4.0)
	preview.flow.show_particles = true
	return preview
}

render_main_menu_pellets_preview_state :: proc(source: ^Remaining_Sim_State) -> Remaining_Sim_State {
	preview := source^
	preview.paused = false
	preview.cursor_active = 0
	preview.pellets.particle_count = min(max(source.pellets.particle_count, 1), 1400)
	preview.pellets.particle_size = max(source.pellets.particle_size, 0.018)
	preview.pellets.trails_enabled = false
	return preview
}

render_main_menu_slime_preview_state :: proc(source: ^Remaining_Sim_State) -> Remaining_Sim_State {
	preview := source^
	preview.paused = false
	preview.cursor_active = 0
	preview.slime.agent_sensor_distance = min(source.slime.agent_sensor_distance, 8.0)
	preview.slime.agent_speed_min = min(source.slime.agent_speed_min, 10.0)
	preview.slime.agent_speed_max = min(source.slime.agent_speed_max, 20.0)
	preview.slime.pheromone_decay_rate = 6.0
	preview.slime.pheromone_deposition_rate = 45.0
	preview.slime.pheromone_diffusion_rate = 18.0
	return preview
}

render_main_menu_primordial_preview_state :: proc(source: ^Remaining_Sim_State) -> Remaining_Sim_State {
	preview := source^
	preview.paused = false
	preview.cursor_active = 0
	preview.primordial.traces_enabled = false
	preview.primordial.particle_count = min(max(source.primordial.particle_count, 1), 2400)
	preview.primordial.particle_size = max(source.primordial.particle_size, 0.012)
	return preview
}

render_main_menu_preview_size_for_slot :: proc(slot: Main_Menu_Preview_Slot) -> (u32, u32) {
	return render_main_menu_preview_size_for_rect(slot.rect.w, slot.rect.h)
}

render_main_menu_preview_size_for_slot_extent :: proc(slot: Main_Menu_Preview_Slot, extent: vk.Extent2D) -> (u32, u32) {
	rect := slot.rect
	if extent.width > 0 && extent.height > 0 {
		x0 := max(rect.x, 0)
		y0 := max(rect.y, 0)
		x1 := min(rect.x + rect.w, f32(extent.width))
		y1 := min(rect.y + rect.h, f32(extent.height))
		if x1 > x0 && y1 > y0 {
			return render_main_menu_preview_size_for_rect(x1 - x0, y1 - y0)
		}
		return MAIN_MENU_SIM_PREVIEW_WIDTH, MAIN_MENU_SIM_PREVIEW_HEIGHT
	}
	return render_main_menu_preview_size_for_slot(slot)
}

render_main_menu_preview_size_for_rect :: proc(rect_width, rect_height: f32) -> (u32, u32) {
	source_w := max(rect_width, f32(MAIN_MENU_SIM_PREVIEW_WIDTH))
	source_h := max(rect_height, f32(MAIN_MENU_SIM_PREVIEW_HEIGHT))
	scale := f32(1)
	if source_w > f32(MAIN_MENU_SIM_PREVIEW_MAX_WIDTH) {
		scale = min(scale, f32(MAIN_MENU_SIM_PREVIEW_MAX_WIDTH) / source_w)
	}
	if source_h > f32(MAIN_MENU_SIM_PREVIEW_MAX_HEIGHT) {
		scale = min(scale, f32(MAIN_MENU_SIM_PREVIEW_MAX_HEIGHT) / source_h)
	}
	width := min(max(u32(source_w * scale), MAIN_MENU_SIM_PREVIEW_WIDTH), MAIN_MENU_SIM_PREVIEW_MAX_WIDTH)
	height := min(max(u32(source_h * scale), MAIN_MENU_SIM_PREVIEW_HEIGHT), MAIN_MENU_SIM_PREVIEW_MAX_HEIGHT)
	return width, height
}

render_main_menu_preview_size_for_mode :: proc(ctx: ^Render_Context, mode: App_Mode) -> (u32, u32) {
	_ = ctx
	_ = mode
	return MAIN_MENU_SIM_PREVIEW_WIDTH, MAIN_MENU_SIM_PREVIEW_HEIGHT
}

render_main_menu_preview_viewport_for_rect :: proc(ctx: ^Render_Context, rect, clip_rect: uifw.Rect, viewport: ^vk.Viewport, scissor: ^vk.Rect2D) -> bool {
	width := f32(ctx.vk_ctx.swapchain_extent.width)
	height := f32(ctx.vk_ctx.swapchain_extent.height)
	inset := f32(0)
	viewport_width := rect.w - inset * 2
	viewport_height := rect.h - inset * 2
	if viewport_width <= 0 || viewport_height <= 0 {
		return false
	}
	vx0 := rect.x + inset
	vy0 := rect.y + inset
	if vx0 + viewport_width > width {
		vx0 = width - viewport_width
	}
	if vy0 + viewport_height > height {
		vy0 = height - viewport_height
	}
	sx0 := max(clip_rect.x + inset, 0)
	sy0 := max(clip_rect.y + inset, 0)
	sx1 := min(clip_rect.x + clip_rect.w - inset, width)
	sy1 := min(clip_rect.y + clip_rect.h - inset, height)
	if sx1 <= sx0 || sy1 <= sy0 {
		return false
	}
	viewport^ = {
		x = vx0,
		y = vy0,
		width = viewport_width,
		height = viewport_height,
		minDepth = 0,
		maxDepth = 1,
	}
	scissor^ = {
		offset = {i32(sx0), i32(sy0)},
		extent = {u32(max(sx1 - sx0, 1)), u32(max(sy1 - sy0, 1))},
	}
	return true
}

render_pass_main_menu_preview_present :: proc(ctx: ^Render_Context) {
	if ctx.app_ui == nil || ctx.app_ui.main_menu_preview_slot_count <= 0 {
		return
	}
	count := min(ctx.app_ui.main_menu_preview_slot_count, MAIN_MENU_PREVIEW_SLOT_CAP)
	ctx.backend.last_main_menu_preview_visible_slot_count = u32(count)
	for i in 0 ..< count {
		render_pass_main_menu_preview_present_slot(ctx, ctx.app_ui.main_menu_preview_slots[i])
	}
}

render_pass_main_menu_preview_present_slot :: proc(ctx: ^Render_Context, slot: Main_Menu_Preview_Slot) {
	viewport: vk.Viewport
	scissor: vk.Rect2D
	if !render_main_menu_preview_viewport_for_rect(ctx, slot.rect, slot.clip_rect, &viewport, &scissor) {
		ctx.backend.last_main_menu_preview_skipped_present_count += 1
		return
	}
	if render_main_menu_preview_clear_slot_fallback(ctx, slot.fallback_color, scissor) {
		ctx.backend.last_main_menu_preview_fallback_fill_count += 1
	}
	#partial switch slot.mode {
	case .Gray_Scott:
		if ctx.preview_gray_scott != nil {
			gray_scott_gpu_draw_prepared_viewport(ctx.preview_gray_scott, ctx.vk_ctx, ctx.frame.command_buffer, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Slime_Mold:
		if ctx.preview_slime_gpu != nil {
			slime_gpu_draw_prepared_viewport(ctx.preview_slime_gpu, ctx.vk_ctx, ctx.frame, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Particle_Life:
		if ctx.preview_particle_life != nil {
			particle_life_gpu_draw_prepared_viewport(ctx.preview_particle_life, ctx.vk_ctx, ctx.frame, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Flow_Field:
		if ctx.preview_flow_gpu != nil {
			flow_gpu_draw_prepared_viewport(ctx.preview_flow_gpu, ctx.vk_ctx, ctx.frame, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Pellets:
		if ctx.preview_pellets_gpu != nil && ctx.preview_pellets_gpu.ready {
			pellets_gpu_draw_scene_viewport(ctx.preview_pellets_gpu, ctx.vk_ctx, ctx.frame.command_buffer, int(ctx.frame.frame_index), &ctx.preview_pellets_gpu.background_pipeline, &ctx.preview_pellets_gpu.render_pipeline, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Voronoi_CA:
		if ctx.preview_voronoi_gpu != nil {
			voronoi_gpu_draw_prepared_viewport(ctx.preview_voronoi_gpu, ctx.vk_ctx, ctx.frame, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Moire:
		if ctx.preview_moire_gpu != nil {
			moire_gpu_draw_prepared_viewport(ctx.preview_moire_gpu, ctx.vk_ctx, ctx.frame, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Vectors:
		if ctx.preview_vectors_gpu != nil {
			vectors_gpu_draw_prepared_viewport(ctx.preview_vectors_gpu, ctx.vk_ctx, ctx.frame, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Primordial:
		if ctx.preview_primordial_gpu != nil {
			primordial_gpu_draw_prepared_viewport(ctx.preview_primordial_gpu, ctx.vk_ctx, ctx.frame, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	}
}

render_main_menu_preview_clear_slot_fallback :: proc(ctx: ^Render_Context, color: uifw.Color, scissor: vk.Rect2D) -> bool {
	if scissor.extent.width == 0 || scissor.extent.height == 0 {
		return false
	}
	clear := vk.ClearAttachment {
		aspectMask = {.COLOR},
		colorAttachment = 0,
		clearValue = {
			color = {float32 = {color.r, color.g, color.b, color.a}},
		},
	}
	rect := vk.ClearRect {
		rect = scissor,
		baseArrayLayer = 0,
		layerCount = 1,
	}
	vk.CmdClearAttachments(ctx.frame.command_buffer, 1, &clear, 1, &rect)
	return true
}
