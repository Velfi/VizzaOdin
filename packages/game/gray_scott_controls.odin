package game

import uifw "zelda_engine:ui"
import engine "zelda_engine:engine"

import "core:fmt"
import "core:math"

gray_scott_reset_runtime :: proc(sim: ^Gray_Scott_Simulation) {
	sim.runtime.simulation_time = 0
	sim.runtime.frame_index = 0
	sim.runtime.pending_seed_mode = GRAY_SCOTT_MODE_INITIAL_SEED
	sim.runtime.paint_active = false
	sim.runtime.render_ready = false
}

gray_scott_seed_noise :: proc(sim: ^Gray_Scott_Simulation) {
	sim.runtime.seed += 0x9e3779b9
	if sim.runtime.seed == 0 {
		sim.runtime.seed = 0x6d2b79f5
	}
	sim.runtime.pending_seed_mode = GRAY_SCOTT_MODE_NOISE_SEED
}

gray_scott_randomize_seed_recipe :: proc(sim: ^Gray_Scott_Simulation) {
	seed := sim.runtime.seed + u32(sim.runtime.frame_index & 0xffffffff) + 1
	noise := &sim.settings.seed_noise
	noise.kind = Noise_Kind(int(gray_scott_random_range(&seed, 0, f32(len(NOISE_KIND_NAMES)))) % len(NOISE_KIND_NAMES))
	noise.fractal_mode = Noise_Fractal_Mode(int(gray_scott_random_range(&seed, 0, f32(len(NOISE_FRACTAL_MODE_NAMES)))) % len(NOISE_FRACTAL_MODE_NAMES))
	noise.warp_mode = Noise_Warp_Mode(int(gray_scott_random_range(&seed, 0, f32(len(NOISE_WARP_MODE_NAMES)))) % len(NOISE_WARP_MODE_NAMES))
	noise.frequency = gray_scott_random_range(&seed, 1.5, 14.0)
	noise.octaves = u32(gray_scott_random_range(&seed, 2, 8))
	noise.lacunarity = gray_scott_random_range(&seed, 1.6, 3.0)
	noise.gain = gray_scott_random_range(&seed, 0.3, 0.75)
	noise.warp_octaves = u32(gray_scott_random_range(&seed, 1, 6))
	noise.warp_amplitude = gray_scott_random_range(&seed, 0.15, 1.75)
	noise.warp_frequency = gray_scott_random_range(&seed, 0.4, 3.5)
	noise.rotation = gray_scott_random_range(&seed, -f32(math.PI), f32(math.PI))
	sim.settings.seed_density = gray_scott_random_range(&seed, 0.3, 0.8)
	sim.settings.seed_amplitude = gray_scott_random_range(&seed, 0.25, 1.5)
	noise_sync_indices(noise)
	sim.runtime.seed = seed
	sim.runtime.pending_seed_mode = GRAY_SCOTT_MODE_NOISE_SEED
}

gray_scott_random01 :: proc(seed: ^u32) -> f32 {
	x := seed^ + 0x9e3779b9
	x = (x ~ (x >> 16)) * 0x7feb352d
	x = (x ~ (x >> 15)) * 0x846ca68b
	x = x ~ (x >> 16)
	seed^ = x
	return f32(x) / f32(0xffffffff)
}

gray_scott_random_range :: proc(seed: ^u32, min_value, max_value: f32) -> f32 {
	return min_value + (max_value - min_value) * gray_scott_random01(seed)
}

gray_scott_randomize_settings :: proc(sim: ^Gray_Scott_Simulation) {
	sim.runtime.randomize_undo = {
		feed = sim.settings.feed,
		kill = sim.settings.kill,
		diffusion_a = sim.settings.diffusion_a,
		diffusion_b = sim.settings.diffusion_b,
		timestep = sim.settings.timestep,
		simulation_speed = sim.settings.simulation_speed,
		seed = sim.runtime.seed,
		current_preset_index = sim.runtime.current_preset_index,
	}
	sim.runtime.randomize_undo_available = true
	seed := sim.runtime.seed + u32(sim.runtime.frame_index & 0xffffffff) + 1
	sim.settings.feed = gray_scott_random_range(&seed, 0.02, 0.08)
	sim.settings.kill = gray_scott_random_range(&seed, 0.04, 0.08)
	sim.settings.diffusion_a = gray_scott_random_range(&seed, 0.1, 0.3)
	sim.settings.diffusion_b = gray_scott_random_range(&seed, 0.05, 0.15)
	sim.settings.timestep = gray_scott_random_range(&seed, 0.5, 2.0)
	sim.settings.simulation_speed = 1.0
	sim.runtime.seed = seed
	sim.runtime.current_preset_index = len(GRAY_SCOTT_BUILTIN_PRESET_NAMES) - 1
}

gray_scott_undo_randomize_settings :: proc(sim: ^Gray_Scott_Simulation) -> bool {
	if sim == nil || !sim.runtime.randomize_undo_available {
		return false
	}
	undo := sim.runtime.randomize_undo
	sim.settings.feed = undo.feed
	sim.settings.kill = undo.kill
	sim.settings.diffusion_a = undo.diffusion_a
	sim.settings.diffusion_b = undo.diffusion_b
	sim.settings.timestep = undo.timestep
	sim.settings.simulation_speed = undo.simulation_speed
	sim.runtime.seed = undo.seed
	sim.runtime.randomize_undo_available = false
	sim.runtime.current_preset_index = undo.current_preset_index
	return true
}

gray_scott_load_settings :: proc(sim: ^Gray_Scott_Simulation, settings: Gray_Scott_Settings) {
	sim.settings^ = settings
	sim.runtime.randomize_undo_available = false
	sim.runtime.current_preset_index = len(GRAY_SCOTT_BUILTIN_PRESET_NAMES) - 1
	gray_scott_request_nutrient_upload(sim)
}

gray_scott_save_settings :: proc(sim: ^Gray_Scott_Simulation) -> Gray_Scott_Settings {
	return sim.settings^
}

gray_scott_xy_plot_height :: proc(ctx: ^uifw.Gui_Context) -> f32 {
	return max(ctx.style.row_height * 3.25, f32(206))
}

gray_scott_draw_mask_controls :: proc(sim: ^Gray_Scott_Simulation, ctx: ^uifw.Gui_Context, worker: ^Product_Context, section: int) -> bool {
	changed := false
	if section < 0 || section == 6 || section == GRAY_SCOTT_SECTION_MASK {
	if section == GRAY_SCOTT_SECTION_MASK {
		uifw.gui_heading(ctx, "Mask")
		uifw.gui_text_block(ctx, "Shape the reaction field with a procedural pattern, selected image, or live camera.", ctx.content_width, ctx.style.text_muted)
	}
	pattern_index := int(u32(sim.settings.mask_pattern))
	if uifw.gui_selector(ctx, fmt.tprintf("Mask Pattern: %s", GRAY_SCOTT_MASK_PATTERN_NAMES[pattern_index]), "mask_pattern", &pattern_index, GRAY_SCOTT_MASK_PATTERN_NAMES[:]) {
		sim.settings.mask_pattern = Gray_Scott_Mask_Pattern(pattern_index)
		changed = true
	}
	if sim.settings.mask_pattern != .Disabled {
		target_index := gray_scott_mask_target_to_index(sim.settings.mask_target)
		if uifw.gui_selector(ctx, fmt.tprintf("Mask Target: %s", GRAY_SCOTT_MASK_TARGET_NAMES[target_index]), "mask_target", &target_index, GRAY_SCOTT_MASK_TARGET_NAMES[:]) {
			sim.settings.mask_target = gray_scott_mask_target_from_index(target_index)
			changed = true
		}
		if uifw.gui_toggle(ctx, fmt.tprintf("Mirror Horizontal: %v", sim.settings.mask_mirror_horizontal), "mirror_h", &sim.settings.mask_mirror_horizontal) {
			changed = true
		}
		if uifw.gui_toggle(ctx, fmt.tprintf("Mirror Vertical: %v", sim.settings.mask_mirror_vertical), "mirror_v", &sim.settings.mask_mirror_vertical) {
			changed = true
		}
		if uifw.gui_toggle(ctx, fmt.tprintf("Invert Tone: %v", sim.settings.mask_invert_tone), "invert_tone", &sim.settings.mask_invert_tone) {
			changed = true
		}
		if uifw.gui_slider_f32(ctx, fmt.tprintf("Mask Strength: %.2f", sim.settings.mask_strength), "mask_strength", &sim.settings.mask_strength, 0.0, 1.0) {
			changed = true
		}
		if sim.settings.mask_pattern == .Nutrient_Map {
			fit_index := int(u32(sim.settings.nutrient_image_fit_mode))
			image_options := shared_default_image_selector_options()
			image_options.fit_label = "Image Fit"
			image_options.fit_key = "nutrient_image_fit"
			image_options.load_label = "Reload Selected"
			image_options.load_key = "load_nutrient_png"
			image_options.browse_label = "Choose Image..."
			image_options.browse_key = "browse_nutrient_png"
			image_options.clear_key = "clear_nutrient_image"
			image_options.selected_label = "Selected Image"
			image_options.empty_label = fmt.tprintf("No image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
			image_options.selected_path = fixed_string(sim.settings.nutrient_image_path[:])
			image_result := shared_image_selector(ctx, &fit_index, GRAY_SCOTT_IMAGE_FIT_MODE_NAMES[:], image_options)
			if image_result.fit_changed {
				sim.settings.nutrient_image_fit_mode = Gray_Scott_Image_Fit_Mode(u32(max(min(fit_index, len(GRAY_SCOTT_IMAGE_FIT_MODE_NAMES) - 1), 0)))
				gray_scott_request_nutrient_upload(sim)
				changed = true
			}
			if image_result.load_requested {
				gray_scott_request_nutrient_upload(sim)
				changed = true
			}
			if image_result.browse_requested {
				sim.runtime.nutrient_image_dialog_requested = true
				changed = true
			}
			if image_result.clear_requested {
				write_fixed_string(sim.settings.nutrient_image_path[:], "")
				sim.runtime.nutrient_image_loaded = false
				gray_scott_request_nutrient_upload(sim)
				changed = true
			}
			webcam_options := shared_default_webcam_controls_options()
			webcam_options.active = sim.runtime.webcam_active
			webcam_options.device_count = gray_scott_webcam_device_count()
			webcam_result := shared_webcam_controls(ctx, webcam_options)
			if webcam_result.action == .Stop {
				gray_scott_stop_webcam(sim)
				gray_scott_request_nutrient_upload(sim)
				changed = true
			} else if webcam_result.action == .Start {
				preferred_camera := worker == nil ? "" : worker.settings.preferred_camera
				if gray_scott_start_webcam(sim, preferred_camera) {
					changed = true
				}
			}
			status := sim.runtime.nutrient_image_loaded ? "Loaded selected image" : "Using procedural nutrient map"
			if sim.runtime.webcam_active {
				status = fmt.tprintf("Webcam frames: %d", sim.runtime.webcam_frames)
			} else if sim.runtime.webcam_permission_denied {
				status = "Webcam permission denied"
			} else if gray_scott_webcam_device_count() == 0 {
				status = "No webcam devices"
			}
			uifw.gui_label(ctx, status)
		}
	}
	}

	return changed
}

gray_scott_controls_content_height :: proc(sim: ^Gray_Scott_Simulation, ctx: ^uifw.Gui_Context, section := -1) -> f32 {
	row := ctx.style.row_height + ctx.style.spacing
	undo_row := sim.runtime.randomize_undo_available ? row : f32(0)
	heading := ctx.style.heading_line_height + ctx.style.spacing
	spacer := f32(8) + ctx.style.spacing
	if section >= 0 {
		switch section {
		case 0:
			return heading + row * 4
		case 1:
			return heading * 2 + row * f32(preset_fieldset_content_rows(&sim.runtime.preset_fieldset) + 4) + spacer
		case CONTROLLER_SECTION_PRESETS:
			return heading * 3 + row * f32(preset_fieldset_content_rows(&sim.runtime.preset_fieldset) + 7) + spacer * 2 + undo_row
		case 2:
			return heading + row * 4
		case 3:
			return heading + row * 4
		case CONTROLLER_SECTION_LOOK:
			return heading * 2 + row * 10 + spacer
		case 4:
			return heading * 2 + shared_two_axis_pad_height(ctx) + row * 5 + spacer
		case 5:
			return heading + row * 3 + spacer + undo_row
		case GRAY_SCOTT_SECTION_PATTERN:
			return heading * 2 + row * 7 + spacer * 2 + gray_scott_xy_plot_height(ctx) * 2 + noise_settings_controls_content_height(ctx, &sim.settings.seed_noise) + uifw.gui_slider_height(ctx) * 2
		case GRAY_SCOTT_SECTION_MASK:
			rows := 2
			if sim.settings.mask_pattern != .Disabled {
				rows += 5
				if sim.settings.mask_pattern == .Nutrient_Map {
					rows += 7
				}
			}
			return heading + row * f32(rows) + spacer
		case 7:
			return heading + row * 5 + spacer
		case:
		}
	}
	rows := 0
	sections := 0
	add_section :: proc(rows: ^int, sections: ^int, count: int) {
		sections^ += 1
		rows^ += count
	}

	add_section(&rows, &sections, 5) // About
	add_section(&rows, &sections, preset_fieldset_content_rows(&sim.runtime.preset_fieldset)) // Presets
	add_section(&rows, &sections, 35) // Display
	add_section(&rows, &sections, 5) // Post Processing
	add_section(&rows, &sections, 5) // Controls
	add_section(&rows, &sections, sim.runtime.randomize_undo_available ? 3 : 2) // Settings
	add_section(&rows, &sections, 26) // Reaction-Diffusion
	rows += int(noise_settings_controls_content_height(ctx, &sim.settings.seed_noise) / max(ctx.style.row_height, 1)) + 4
	if sim.settings.mask_pattern != .Disabled {
		rows += 6
		if sim.settings.mask_pattern == .Nutrient_Map {
			rows += 6
		}
	}
	add_section(&rows, &sections, 5) // Camera
	slider_extra := max(uifw.gui_slider_height(ctx) - ctx.style.row_height, 0)
	slider_count := sim.settings.mask_pattern != .Disabled ? 6 : 5
	return f32(rows) * ctx.style.row_height + f32(max(rows - 1, 0) + sections + 8) * ctx.style.spacing + f32(sections) * 12 + slider_extra * f32(slider_count)
}

gray_scott_draw_actions :: proc(sim: ^Gray_Scott_Simulation, ctx: ^uifw.Gui_Context) -> bool {
	changed := false
	actions_bounds := uifw.gui_next_rect(ctx)
	actions := uifw.gui_grid_begin(ctx, actions_bounds, 4, ctx.style.spacing)
	if uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, "reset"), uifw.gui_grid_next(&actions, actions_bounds.h), "Reset Simulation", true) {
		gray_scott_reset_runtime(sim)
		uifw.gui_notice(ctx, "Fresh pattern started. Your settings stayed exactly as they were.")
		changed = true
	}
	if uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, "randomize"), uifw.gui_grid_next(&actions, actions_bounds.h), "Randomize Settings", true) {
		gray_scott_randomize_settings(sim)
		uifw.gui_notice(ctx, "Settings randomized. Restore Before Randomize is available here.")
		changed = true
	}
	if uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, "seed_noise"), uifw.gui_grid_next(&actions, actions_bounds.h), "Seed Noise", true) {
		gray_scott_seed_noise(sim)
		uifw.gui_notice(ctx, "New noise seed added. Settings stayed unchanged.")
		changed = true
	}
	if uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, "randomize_seed_recipe"), uifw.gui_grid_next(&actions, actions_bounds.h), "Random Seed Recipe", true) {
		gray_scott_randomize_seed_recipe(sim)
		uifw.gui_notice(ctx, "Noise type, scale, fractal, warp, density, and amplitude randomized.")
		changed = true
	}
	if sim.runtime.randomize_undo_available && uifw.gui_button(ctx, "Restore Before Randomize", "undo_randomize") {
		if gray_scott_undo_randomize_settings(sim) {
			uifw.gui_notice(ctx, "Previous Gray-Scott settings restored.")
			changed = true
		}
	}
	return changed
}

gray_scott_plot_value_to_point :: proc(area: uifw.Rect, value, min_value, max_value: uifw.Vec2) -> uifw.Vec2 {
	xn := uifw.gui_clamp01((value.x - min_value.x) / max(max_value.x - min_value.x, 0.000001))
	yn := uifw.gui_clamp01((value.y - min_value.y) / max(max_value.y - min_value.y, 0.000001))
	return {
		area.x + area.w * xn,
		area.y + area.h * (1 - yn),
	}
}

gray_scott_plot_point_to_value :: proc(area: uifw.Rect, point, min_value, max_value: uifw.Vec2) -> uifw.Vec2 {
	xn := uifw.gui_clamp01((point.x - area.x) / max(area.w, 1))
	yn := 1 - uifw.gui_clamp01((point.y - area.y) / max(area.h, 1))
	return {
		min_value.x + (max_value.x - min_value.x) * xn,
		min_value.y + (max_value.y - min_value.y) * yn,
	}
}

gray_scott_draw_plot_grid :: proc(ctx: ^uifw.Gui_Context, area: uifw.Rect) {
	grid_color := uifw.gui_apply_opacity(ctx.style.panel_border, 0.48)
	for i in 1 ..< 10 {
		t := f32(i) / 10
		x := area.x + area.w * t
		y := area.y + area.h * t
		uifw.gui_line(ctx, {x, area.y}, {x, area.y + area.h}, grid_color, 1)
		uifw.gui_line(ctx, {area.x, y}, {area.x + area.w, y}, grid_color, 1)
	}
}

gray_scott_draw_plot_handle :: proc(ctx: ^uifw.Gui_Context, center: uifw.Vec2, fill, stroke: uifw.Color) {
	outer := max(ctx.style.row_height * 0.25, f32(11))
	inner := max(ctx.style.row_height * 0.18, f32(8))
	uifw.gui_ellipse(ctx, {center.x - outer, center.y - outer, outer * 2, outer * 2}, uifw.gui_apply_opacity(fill, 0.20))
	uifw.gui_ellipse(ctx, {center.x - inner, center.y - inner, inner * 2, inner * 2}, fill)
	uifw.gui_ellipse_stroke(ctx, {center.x - inner, center.y - inner, inner * 2, inner * 2}, stroke, 2)
}

gray_scott_xy_plot :: proc(ctx: ^uifw.Gui_Context, title, key, x_label, y_label, x_short, y_short: string, x: ^f32, y: ^f32, min_value, max_value: uifw.Vec2, fill, stroke: uifw.Color) -> bool {
	bounds := uifw.gui_next_rect(ctx, height = gray_scott_xy_plot_height(ctx))
	id := uifw.gui_make_id(ctx, key)
	title_rect := uifw.Rect{bounds.x, bounds.y, bounds.w, ctx.style.row_height}
	uifw.gui_text_clipped(ctx, title_rect, {bounds.x + ctx.style.spacing_1, bounds.y + max((ctx.style.row_height - ctx.style.body_text_height) * 0.5, 0)}, title, ctx.style.text)

	plot_top := bounds.y + ctx.style.row_height + ctx.style.spacing_1
	footer_h := max(ctx.style.small_line_height + ctx.style.spacing_1, f32(28))
	plot_height := max(bounds.h - ctx.style.row_height - footer_h - ctx.style.spacing_1, ctx.style.row_height * 1.35)
	area_inset := max(ctx.style.spacing_2, f32(8))
	area := uifw.Rect{bounds.x + area_inset, plot_top, max(bounds.w - area_inset * 2, 1), plot_height}
	current := uifw.Vec2{x^, y^}
	handle := gray_scott_plot_value_to_point(area, current, min_value, max_value)
	changed := false

	if uifw.gui_drag_handle_region(ctx, id, area, handle, max(ctx.style.row_height * 0.12, f32(12))) {
		next: uifw.Vec2
		fine := uifw.gui_pointer_fine_adjust_scale(ctx, id)
		if fine < 1 {
			next = {
				current.x + ctx.mouse_delta.x / max(area.w, 1) * (max_value.x - min_value.x) * fine,
				current.y - ctx.mouse_delta.y / max(area.h, 1) * (max_value.y - min_value.y) * fine,
			}
			next.x = min(max(next.x, min_value.x), max_value.x)
			next.y = min(max(next.y, min_value.y), max_value.y)
		} else {
			next = gray_scott_plot_point_to_value(area, ctx.input.mouse_pos, min_value, max_value)
		}
		x^ = next.x
		y^ = next.y
		current = next
		changed = true
	}
	_ = uifw.gui_update_focus_edit(ctx, id, ctx.focused == id)
	uifw.gui_controller_edit_vec2(ctx, id, &current)
	if current.x != x^ || current.y != y^ {
		x^ = current.x
		y^ = current.y
		changed = true
	}
	nav_x, nav_y := uifw.gui_focused_nav_pressed(ctx, id)
	if nav_x != 0 || nav_y != 0 {
		adjust_scale := uifw.gui_fine_adjust_scale(ctx)
		step := uifw.Vec2{(max_value.x - min_value.x) * 0.025 * adjust_scale, (max_value.y - min_value.y) * 0.025 * adjust_scale}
		x^ += nav_x * step.x
		y^ -= nav_y * step.y
		x^ = min(max(x^, min_value.x), max_value.x)
		y^ = min(max(y^, min_value.y), max_value.y)
		changed = true
	}

	panel := uifw.gui_inset(area, -max(ctx.style.spacing_1, f32(6)))
	bg := uifw.gui_lerp_color(ctx.style.panel, ctx.style.control, 0.55)
	uifw.gui_round_rect(ctx, panel, ctx.style.radius_control, bg)
	uifw.gui_round_stroke(ctx, panel, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)
	gray_scott_draw_plot_grid(ctx, area)
	uifw.gui_round_stroke(ctx, area, 2, uifw.gui_apply_opacity(ctx.style.text_muted, 0.58), 2)

	handle = gray_scott_plot_value_to_point(area, {x^, y^}, min_value, max_value)
	cross_color := uifw.gui_apply_opacity(fill, 0.36)
	uifw.gui_line(ctx, {area.x, handle.y}, {area.x + area.w, handle.y}, cross_color, 1)
	uifw.gui_line(ctx, {handle.x, area.y}, {handle.x, area.y + area.h}, cross_color, 1)
	gray_scott_draw_plot_handle(ctx, handle, fill, stroke)
	uifw.gui_focus_or_edit_ring(ctx, id, panel)

	uifw.gui_text_clipped(ctx, {area.x, area.y + area.h + 4, area.w, ctx.style.text_height}, {area.x + 2, area.y + area.h + 5}, fmt.tprintf("%s %.3f - %.3f", x_label, min_value.x, max_value.x), ctx.style.text_muted)
	uifw.gui_text_right(ctx, {area.x, area.y + area.h + 4, area.w, ctx.style.text_height}, fmt.tprintf("%s %.3f - %.3f", y_label, min_value.y, max_value.y), ctx.style.text_muted)
	value_label := fmt.tprintf("%s %.3f  %s %.3f", x_short, x^, y_short, y^)
	uifw.gui_text_centered(ctx, {area.x, area.y + 5, area.w, ctx.style.text_height}, value_label, ctx.style.text)
	return changed
}

gray_scott_draw_controls :: proc(sim: ^Gray_Scott_Simulation, ctx: ^uifw.Gui_Context, panel: uifw.Rect, scroll: ^f32, worker: ^Product_Context, color_editor: ^Color_Scheme_Editor_State, section := -1) -> bool {
	changed := false
	uifw.gui_panel_begin(ctx, panel)
	viewport := uifw.gui_next_rect(ctx, height = max(panel.h - ctx.style.panel_padding * 2, 0))
	content_height := gray_scott_controls_content_height(sim, ctx, section)
	uifw.gui_scroll_begin(ctx, viewport, content_height, scroll)
	uifw.gui_push_id(ctx, "gray_scott_controls")

	if section < 0 || section == 0 {
	uifw.gui_heading(ctx, "About this simulation")
	uifw.gui_text_block(ctx, "Reaction-diffusion patterns from two virtual chemicals, U and V, with feed and kill rates shaping spots, stripes, spirals, and labyrinths.", ctx.content_width, ctx.style.text_muted)
	uifw.gui_spacer(ctx, 8)
	}

	if section < 0 || section == 1 || section == CONTROLLER_SECTION_PRESETS {
	uifw.gui_heading(ctx, "Presets")
	preset_fieldset_draw(
		ctx,
		&sim.runtime.preset_fieldset,
		worker,
		"gray_scott",
		GRAY_SCOTT_BUILTIN_PRESET_NAMES[:],
		sim.runtime.current_preset_index,
		Preset_Fieldset_Builtin_Context {kind = .Gray_Scott, gray_scott = sim},
	)
	if section == CONTROLLER_SECTION_PRESETS {
		uifw.gui_spacer(ctx, 8)
		uifw.gui_heading(ctx, "Start Over")
		changed = gray_scott_draw_actions(sim, ctx) || changed
	}
	if section == 1 || section == CONTROLLER_SECTION_PRESETS {
		uifw.gui_spacer(ctx, 8)
		uifw.gui_heading(ctx, "About this simulation")
		uifw.gui_text_block(ctx, "Reaction-diffusion patterns from two virtual chemicals, U and V, with feed and kill rates shaping spots, stripes, spirals, and labyrinths.", ctx.content_width, ctx.style.text_muted)
	}
	uifw.gui_spacer(ctx, 8)
	}

	if section < 0 || section == 2 || section == CONTROLLER_SECTION_LOOK {
	uifw.gui_heading(ctx, "Display Settings")
	view_mode_index := int(sim.settings.view_mode)
	if uifw.gui_selector(ctx, fmt.tprintf("Field View: %s", GRAY_SCOTT_VIEW_MODE_NAMES[view_mode_index]), "gray_scott_view_mode", &view_mode_index, GRAY_SCOTT_VIEW_MODE_NAMES[:]) {
		sim.settings.view_mode = Gray_Scott_View_Mode(u32(view_mode_index))
		changed = true
	}
	if color_scheme_editor_draw_selector(ctx, color_editor, "gray_scott_color_scheme", &sim.settings.color_scheme, &sim.settings.color_scheme_reversed) {
		changed = true
	}
	uifw.gui_spacer(ctx, 8)
	}

	if section < 0 || section == 3 || section == CONTROLLER_SECTION_LOOK {
	post_options := shared_default_post_processing_menu_options()
	if shared_post_processing_menu(ctx, &sim.settings.blur_enabled, &sim.settings.blur_radius, &sim.settings.blur_sigma, post_options) {
		changed = true
	}
	uifw.gui_spacer(ctx, 8)
	}

	if section < 0 || section == 4 {
	tool_set := canvas_tool_set_for_mode(.Gray_Scott)
	shared_canvas_tool_selector(ctx, &tool_set, &sim.canvas_tool)
	cursor_options := shared_default_cursor_config_options()
	cursor_options.size_step = 0.01
	cursor_options.strength_step = 0.05
	controls_options := Controls_Panel_Options {
		heading = section >= 0 ? "Brush" : "Controls",
		mouse_interaction_text = "",
		cursor_settings_title = "Cursor Settings",
		cursor = cursor_options,
	}
	if shared_controls_panel(ctx, controls_options, &sim.settings.cursor_size, &sim.settings.cursor_strength) {
		changed = true
	}
	uifw.gui_spacer(ctx, 8)
	}

	if section < 0 || section == 5 {
	uifw.gui_heading(ctx, "Settings")
	changed = gray_scott_draw_actions(sim, ctx) || changed
	uifw.gui_spacer(ctx, 8)
	}

	if section < 0 || section == 6 || section == GRAY_SCOTT_SECTION_PATTERN {
	uifw.gui_heading(ctx, "Seed Generator")
	if draw_noise_settings_controls(ctx, &sim.settings.seed_noise, "gray_scott_seed") {changed = true}
	if uifw.gui_slider_f32(ctx, fmt.tprintf("Seed Density: %.2f", sim.settings.seed_density), "seed_density", &sim.settings.seed_density, 0, 1) {changed = true}
	if uifw.gui_slider_f32(ctx, fmt.tprintf("Seed Amplitude: %.2f", sim.settings.seed_amplitude), "seed_amplitude", &sim.settings.seed_amplitude, 0, 2) {changed = true}
	uifw.gui_spacer(ctx, 8)
	uifw.gui_heading(ctx, "Reaction-Diffusion")
	uifw.gui_label(ctx, "Drag the handles to adjust paired parameters.")
	if gray_scott_xy_plot(ctx, "Feed Rate vs Kill Rate", "feed_kill_plot", "Feed", "Kill", "F", "K", &sim.settings.feed, &sim.settings.kill, {0.0, 0.0}, {0.1, 0.1}, {0.94, 0.28, 0.31, 1.0}, {0.74, 0.16, 0.18, 1.0}) {
		changed = true
	}
	shared_control_explanation(ctx, "feed_kill_plot", "Feed adds fresh chemical U; Kill removes chemical V. Tiny changes can turn spots into stripes or spirals.")
	if gray_scott_xy_plot(ctx, "Diffusion U vs Diffusion V", "diffusion_plot", "Diffusion U", "Diffusion V", "Du", "Dv", &sim.settings.diffusion_a, &sim.settings.diffusion_b, {0.0, 0.0}, {0.5, 0.25}, {0.20, 0.78, 0.42, 1.0}, {0.10, 0.55, 0.28, 1.0}) {
		changed = true
	}
	shared_control_explanation(ctx, "diffusion_plot", "Diffusion is how quickly each chemical spreads. The difference between U and V helps patterns form.")
	// The spatial plots are the primary controller UI. Keep the legacy precise
	// fields in the full menu, where their duplication remains useful.
	if section != GRAY_SCOTT_SECTION_PATTERN {
		if uifw.gui_slider_f32(ctx, fmt.tprintf("Feed Rate: %.3f", sim.settings.feed), "feed", &sim.settings.feed, 0.0, 0.1) {
			changed = true
		}
		shared_control_explanation(ctx, "feed", "Feed adds fresh chemical U. Higher values refill the pattern faster.")
		if uifw.gui_slider_f32(ctx, fmt.tprintf("Kill Rate: %.3f", sim.settings.kill), "kill", &sim.settings.kill, 0.0, 0.1) {
			changed = true
		}
		shared_control_explanation(ctx, "kill", "Kill removes chemical V. Small changes can switch the kind of pattern you see.")
		if uifw.gui_numeric_f32(ctx, fmt.tprintf("Diffusion U: %.3f", sim.settings.diffusion_a), "diffusion_u", &sim.settings.diffusion_a, 0.01, 0.0, 0.5) {
			changed = true
		}
		shared_control_explanation(ctx, "diffusion_u", "Diffusion U is how quickly chemical U spreads into nearby pixels.")
		if uifw.gui_numeric_f32(ctx, fmt.tprintf("Diffusion V: %.3f", sim.settings.diffusion_b), "diffusion_v", &sim.settings.diffusion_b, 0.01, 0.0, 0.25) {
			changed = true
		}
		shared_control_explanation(ctx, "diffusion_v", "Diffusion V is how quickly chemical V spreads into nearby pixels.")
	}
	if uifw.gui_numeric_f32(ctx, fmt.tprintf("Timestep: %.2f", sim.settings.timestep), "timestep", &sim.settings.timestep, 0.05, 0.0, 4.0) {
		changed = true
	}
	shared_control_explanation(ctx, "timestep", "Timestep is the size of each simulation step. Higher moves faster, but can become unstable.")
	if uifw.gui_numeric_f32(ctx, fmt.tprintf("Simulation Speed: %.2fx", sim.settings.simulation_speed), "simulation_speed", &sim.settings.simulation_speed, 0.25, 0.0, 32.0) {
		changed = true
	}
	if uifw.gui_numeric_f32(ctx, fmt.tprintf("Max Timestep: %.2f", sim.settings.max_timestep), "max_timestep", &sim.settings.max_timestep, 0.05, 0.1, 8.0) {
		changed = true
	}
	shared_control_explanation(ctx, "max_timestep", "Max Timestep caps each stable integration step. Larger requested advances are subdivided automatically.")
	if uifw.gui_numeric_f32(ctx, fmt.tprintf("Stability: %.2f", sim.settings.stability_factor), "stability", &sim.settings.stability_factor, 0.05, 0.1, 1.0) {
		changed = true
	}
	shared_control_explanation(ctx, "stability", "Stability controls the safety margin for automatic step subdivision. Lower is safer; higher is faster.")
	}

	if gray_scott_draw_mask_controls(sim, ctx, worker, section) {changed = true}
	if section < 0 || section == 7 {
	uifw.gui_spacer(ctx, 8)
	uifw.gui_heading(ctx, "Camera")
	if uifw.gui_button(ctx, "Reset Camera", "reset_camera") {
		gray_scott_reset_camera(sim)
		changed = true
	}
	if uifw.gui_numeric_f32(ctx, fmt.tprintf("Zoom: %.2f", sim.runtime.camera_zoom), "camera_zoom", &sim.runtime.camera_zoom, 0.05, 0.05, 64.0, mapping = .Logarithmic) {
		sim.runtime.camera_target_zoom = sim.runtime.camera_zoom
		changed = true
	}
	if uifw.gui_numeric_f32(ctx, fmt.tprintf("Pan X: %.2f", sim.runtime.camera_x), "camera_x", &sim.runtime.camera_x, 0.05, -128.0, 128.0, mapping = .Symmetric_Log) {
		sim.runtime.camera_target_x = sim.runtime.camera_x
		changed = true
	}
	if uifw.gui_numeric_f32(ctx, fmt.tprintf("Pan Y: %.2f", sim.runtime.camera_y), "camera_y", &sim.runtime.camera_y, 0.05, -128.0, 128.0, mapping = .Symmetric_Log) {
		sim.runtime.camera_target_y = sim.runtime.camera_y
		changed = true
	}
	if uifw.gui_slider_f32(ctx, fmt.tprintf("Camera Smoothing: %.2f", sim.runtime.camera_smoothing_factor), "camera_smoothing", &sim.runtime.camera_smoothing_factor, 0.0, 1.0) {
		changed = true
	}
	}
	uifw.gui_pop_id(ctx)
	uifw.gui_scroll_end(ctx)
	uifw.gui_panel_end(ctx)
	preset_save_dialog_draw(ctx, &sim.runtime.preset_fieldset, worker, "gray_scott")
	return changed
}
