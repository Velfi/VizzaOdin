package render_vk

import uifw "zelda_engine:ui"
import engine "zelda_engine:engine"

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

render_feature_preview_prepare_gray_scott :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) {
	_ = viewport; _ = scissor
	if sim := render_context_gray_scott(ctx, true); sim != nil do _ = gray_scott_gpu_prepare_present_viewport(sim, ctx.vk_ctx, ctx.frame.command_buffer)
}

render_feature_preview_prepare_slime :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) {
	_ = viewport; _ = scissor
	gpu := render_context_slime_gpu(ctx, true)
	if gpu != nil && gpu.ready && gpu.display_image.handle != vk.Image(0) && gpu.display_image.layout != .SHADER_READ_ONLY_OPTIMAL do slime_transition_image(ctx.vk_ctx, ctx.frame.command_buffer, &gpu.display_image, .SHADER_READ_ONLY_OPTIMAL)
	if gpu != nil && gpu.ready do slime_upload_camera(gpu, int(ctx.frame.frame_index))
}

render_feature_preview_prepare_flow :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) {
	_ = scissor
	gpu := render_context_flow_gpu(ctx, true)
	if gpu == nil || !gpu.ready do return
	frame_slot := int(ctx.frame.frame_index)
	flow_upload_camera_size(gpu, frame_slot, viewport.width, viewport.height)
	flow_update_descriptors_for_slot(gpu, ctx.vk_ctx, frame_slot)
	if gpu.trail_pipeline.pipeline != vk.Pipeline(0) && gpu.trail_image.handle != vk.Image(0) do flow_transition_image(ctx.vk_ctx, ctx.frame.command_buffer, &gpu.trail_image, .GENERAL)
}

render_feature_preview_prepare_pellets :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) {
	_ = scissor
	gpu := render_context_pellets_gpu(ctx, true)
	if gpu == nil || !gpu.ready do return
	settings := ctx.app_ui.preview_pellets.pellets
	render_main_menu_apply_pellets_palette(settings, render_main_menu_preview_palette_name(ctx))
	pellets_upload_lut(gpu, settings)
	pellets_write_static_params_size(gpu, int(ctx.frame.frame_index), viewport.width * 2, viewport.height * 2, settings)
	pellets_update_descriptors_for_slot(gpu, ctx.vk_ctx, int(ctx.frame.frame_index))
}

render_feature_preview_prepare_voronoi :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) {
	_ = viewport; _ = scissor
	gpu := render_context_voronoi_gpu(ctx, true)
	if gpu == nil || !gpu.ready do return
	image := gpu.jfa_result_is_scratch ? &gpu.jfa_scratch_image : &gpu.jfa_image
	if image.handle != vk.Image(0) && image.layout != .SHADER_READ_ONLY_OPTIMAL do voronoi_transition_image(ctx.vk_ctx, ctx.frame.command_buffer, image, .SHADER_READ_ONLY_OPTIMAL)
}

render_feature_preview_prepare_moire :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) {
	_ = viewport; _ = scissor
	gpu := render_context_moire_gpu(ctx, true)
	if gpu == nil || !gpu.ready do return
	frame_slot := int(ctx.frame.frame_index)
	if gpu.state_index < 2 {
		index := int(gpu.state_index)
		if gpu.images[index].handle != vk.Image(0) && gpu.images[index].layout != .SHADER_READ_ONLY_OPTIMAL do moire_transition_image(gpu, ctx.vk_ctx, index, .SHADER_READ_ONLY_OPTIMAL, ctx.frame.command_buffer)
		moire_update_texture_descriptor(gpu, ctx.vk_ctx, frame_slot, index)
	}
	moire_upload_camera(gpu, frame_slot)
}

render_feature_preview_prepare_primordial :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) {
	_ = scissor
	gpu := render_context_primordial_gpu(ctx, true)
	if gpu == nil || !gpu.ready do return
	settings := ctx.app_ui.preview_primordial.primordial
	frame_slot := int(ctx.frame.frame_index)
	render_main_menu_apply_primordial_palette(settings, render_main_menu_preview_palette_name(ctx))
	primordial_upload_lut(gpu, settings)
	primordial_upload_camera(gpu, frame_slot, viewport.width, viewport.height)
	primordial_upload_render_params_for_extent(gpu, frame_slot, settings, viewport.width, viewport.height)
	primordial_upload_background_params(gpu, frame_slot, settings)
	primordial_update_descriptors_for_slot(gpu, ctx.vk_ctx, frame_slot)
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
	descriptor, ok := render_feature_descriptor_by_mode(slot.mode)
	if ok && descriptor.preview_prepare != nil do descriptor.preview_prepare(ctx, viewport, scissor)
}

render_main_menu_preview_supported_mode_count :: proc() -> u32 {
	count: u32
	for descriptor in RENDER_FEATURE_DESCRIPTORS {
		product, ok := feature_descriptor_by_mode(descriptor.mode)
		if ok && feature_has_capability(product, .Live_Preview) && descriptor.preview_step != nil && descriptor.preview_present != nil do count += 1
	}
	return count
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

render_main_menu_apply_palette_to_mode :: proc(app_ui: ^App_Ui_State, mode: App_Mode, palette_name: string) -> bool {
	if app_ui == nil do return false
	descriptor, ok := feature_descriptor_by_mode(mode)
	instance := feature_instance_set_get(&app_ui.feature_instances, mode)
	if !ok || instance == nil || descriptor.color_scheme_access == nil do return false
	name, reversed, accessible := descriptor.color_scheme_access(instance.settings)
	if !accessible do return false
	render_main_menu_apply_preview_palette(name, reversed, palette_name)
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

render_main_menu_flow_preview_state :: proc(source, preview: ^Remaining_Sim_State) {
	preview.flow^ = source.flow^
	preview.paused = false
	preview.cursor_active = 0
	preview.flow.total_pool_size = min(max(source.flow.total_pool_size, 1), 6000)
	preview.flow.autospawn_rate = min(max(source.flow.autospawn_rate, 1), 180)
	preview.flow.brush_spawn_rate = min(max(source.flow.brush_spawn_rate, 1), 300)
	preview.flow.particle_size = min(max(source.flow.particle_size, 1), 3)
	preview.flow.particle_speed = min(source.flow.particle_speed, 1.0)
	preview.flow.particle_lifetime = min(source.flow.particle_lifetime, 4.0)
	preview.flow.show_particles = true
}

render_main_menu_pellets_preview_state :: proc(source, preview: ^Remaining_Sim_State) {
	preview.pellets^ = source.pellets^
	preview.paused = false
	preview.cursor_active = 0
	preview.pellets.particle_count = min(max(source.pellets.particle_count, 1), 1400)
	preview.pellets.particle_size = max(source.pellets.particle_size, 0.018)
	preview.pellets.trails_enabled = false
}

render_main_menu_slime_preview_state :: proc(source, preview: ^Remaining_Sim_State) {
	preview.slime^ = source.slime^
	preview.paused = false
	preview.cursor_active = 0
	preview.slime.agent_sensor_distance = min(source.slime.agent_sensor_distance, 8.0)
	preview.slime.agent_speed_min = min(source.slime.agent_speed_min, 10.0)
	preview.slime.agent_speed_max = min(source.slime.agent_speed_max, 20.0)
	preview.slime.pheromone_decay_rate = 6.0
	preview.slime.pheromone_deposition_rate = 45.0
	preview.slime.pheromone_diffusion_rate = 18.0
}

render_main_menu_primordial_preview_state :: proc(source, preview: ^Remaining_Sim_State) {
	preview.primordial^ = source.primordial^
	preview.paused = false
	preview.cursor_active = 0
	preview.primordial.traces_enabled = false
	preview.primordial.particle_count = min(max(source.primordial.particle_count, 1), 2400)
	preview.primordial.particle_size = max(source.primordial.particle_size, 0.012)
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
	if ctx == nil || ctx.app_ui == nil {
		return MAIN_MENU_SIM_PREVIEW_WIDTH, MAIN_MENU_SIM_PREVIEW_HEIGHT
	}
	count := min(ctx.app_ui.main_menu_preview_slot_count, MAIN_MENU_PREVIEW_SLOT_CAP)
	for i in 0 ..< count {
		slot := ctx.app_ui.main_menu_preview_slots[i]
		if slot.mode == mode {
			return render_main_menu_preview_size_for_slot(slot)
		}
	}
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
	if descriptor, ok := render_feature_descriptor_by_mode(slot.mode); ok && descriptor.preview_present != nil {
		if !descriptor.preview_present(ctx, viewport, scissor) {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
		return
	}
	ctx.backend.last_main_menu_preview_skipped_present_count += 1
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
