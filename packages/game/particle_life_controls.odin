package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"
import "core:math"

particle_life_controls_content_height :: proc(sim: ^Particle_Life_Simulation, ctx: ^uifw.Gui_Context, section := -1) -> f32 {
	row := ctx.style.row_height + ctx.style.spacing
	undo_row := sim.runtime.force_randomize_undo_available ? row : f32(0)
	heading := ctx.style.heading_line_height + ctx.style.spacing
	spacer := f32(8) + ctx.style.spacing
	if section >= 0 {
		switch section {
		case 0:
			return heading + row * 5
		case 1:
			return heading * 2 + row * f32(preset_fieldset_content_rows(&sim.runtime.preset_ui) + 5) + spacer
		case CONTROLLER_SECTION_PRESETS:
			return heading * 3 + row * f32(preset_fieldset_content_rows(&sim.runtime.preset_ui) + 6) + spacer * 2
		case 2, CONTROLLER_SECTION_LOOK:
			rows := 17
			if sim.settings.trails_enabled {rows += 2}
			return heading * 3 + row * f32(rows) + spacer * 2
		case 3:
			return heading * 2 + shared_two_axis_pad_height(ctx) + row * 6 + spacer
		case PARTICLE_LIFE_SECTION_POPULATION:
			return heading + row * 9 + spacer
		case PARTICLE_LIFE_SECTION_FORCES:
			n := int(max(min(sim.settings.species_count, PARTICLE_LIFE_MAX_SPECIES), 1))
			matrix_h := f32(n + 1) * max(ctx.style.row_height * 1.35, f32(58))
			return heading + row * 13 + uifw.gui_slider_height(ctx) + matrix_h + spacer + undo_row
		case 5:
			rows := 11
			if sim.settings.collision_enabled {rows += 4}
			curve_extra := particle_life_force_curve_plot_height(ctx) + ctx.style.row_height
			return heading * 2 + row * f32(rows) + curve_extra + spacer
		case 6:
			return heading + row * 8 + spacer
		case 7:
			return heading + row * 5 + spacer
		case PARTICLE_LIFE_SECTION_ADVANCED:
			return heading * 2 + row * 13 + spacer
		case:
		}
	}
	rows := sim.runtime.force_randomize_undo_available ? 109 : 108
	sections := 12
	rows += preset_fieldset_content_rows(&sim.runtime.preset_ui) - 3
	matrix_rows := PARTICLE_LIFE_MAX_SPECIES + 2
	extra := particle_life_force_curve_plot_height(ctx) + ctx.style.row_height + f32(matrix_rows) * 42 + 7 * ctx.style.row_height
	slider_extra := max(uifw.gui_slider_height(ctx) - ctx.style.row_height, 0)
	slider_count := 22
	return f32(rows) * ctx.style.row_height + f32(max(rows - 1, 0) + sections + 18) * ctx.style.spacing + f32(sections) * 12 + extra + slider_extra * f32(slider_count)
}

particle_life_enqueue_preset_command :: proc(worker: ^Product_Context, kind: Ui_To_Render_Command_Kind, name: string) {
	if worker == nil || worker.ui_to_render == nil {
		return
	}
	cmd: Ui_To_Render_Command
	cmd.kind = kind
	write_fixed_string(cmd.preset_name[:], name)
	_ = engine.queue_try_push(worker.ui_to_render, cmd)
}

particle_life_small_button :: proc(ctx: ^uifw.Gui_Context, rect: uifw.Rect, label, key: string) -> bool {
	return uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, key), rect, label, true)
}

particle_life_force_curve_plot_height :: proc(ctx: ^uifw.Gui_Context) -> f32 {
	return max(ctx.style.row_height * 3.25, f32(236))
}

particle_life_force_cell_label :: proc(value: f32) -> string {
	if value >= 0.995 {
		return "+1"
	}
	if value <= -0.995 {
		return "-1"
	}
	if math.abs(value) < 0.05 {
		return "0"
	}
	if value > 0 {
		return fmt.tprintf("+%.1f", value)
	}
	return fmt.tprintf("%.1f", value)
}

particle_life_draw_force_curve_editor :: proc(sim: ^Particle_Life_Simulation, ctx: ^uifw.Gui_Context) {
	hint := ctx.input.active_device == .Controller ? "Select a colored handle, press Accept, then adjust with the D-pad." : "Drag the colored handles to shape the force curve."
	uifw.gui_label(ctx, hint)
	row := uifw.gui_next_rect(ctx, height = ctx.style.row_height)
	button_gap := ctx.style.spacing
	button_w := max((row.w - button_gap) * 0.5, 1)
	if particle_life_small_button(ctx, {row.x, row.y, button_w, row.h}, sim.runtime.force_curve_narrow_range ? "Show Full Range" : "Show Near Range", "pl_curve_range") {
		sim.runtime.force_curve_narrow_range = !sim.runtime.force_curve_narrow_range
	}
	if particle_life_small_button(ctx, {row.x + row.w - button_w, row.y, button_w, row.h}, "Reset Physics", "pl_curve_reset") {
		sim.settings.max_force = 0.5
		sim.settings.max_distance = 0.01
		sim.settings.beta = 0.3
		sim.settings.friction = 0.5
		sim.settings.brownian_motion = 0.5
		uifw.gui_notice(ctx, "Physics controls returned to their defaults.")
	}

	bounds := uifw.gui_next_rect(ctx, height = particle_life_force_curve_plot_height(ctx))
	uifw.gui_round_rect(ctx, bounds, 4, {0.10, 0.10, 0.10, 1})
	uifw.gui_round_stroke(ctx, bounds, 4, ctx.style.panel_border, ctx.style.border_width)
	margin := max(ctx.style.row_height * 0.68, f32(34))
	top_margin := max(ctx.style.body_line_height * 1.25, f32(22))
	bottom_margin := max(ctx.style.body_line_height * 1.7, f32(32))
	plot := uifw.Rect{bounds.x + margin, bounds.y + top_margin, max(bounds.w - margin * 2, 1), max(bounds.h - top_margin - bottom_margin, 1)}
	y_offset := plot.y + plot.h * 0.5
	max_scale_force := sim.runtime.force_curve_narrow_range ? f32(1.0) : f32(10.0)
	max_plot_distance := sim.runtime.force_curve_narrow_range ? f32(0.1) : f32(1.0)
	y_scale := plot.h / (2 * max_scale_force)
	to_y := proc(y: f32, y_offset, y_scale: f32) -> f32 {
		return y_offset - y * y_scale
	}
	to_x := proc(distance, max_plot_distance: f32, plot: uifw.Rect) -> f32 {
		return plot.x + (distance / max(max_plot_distance, 0.0001)) * plot.w
	}
	max_distance_x := to_x(sim.settings.max_distance, max_plot_distance, plot)
	beta_distance := sim.settings.beta * sim.settings.max_distance
	beta_x := to_x(min(beta_distance, sim.settings.max_distance), max_plot_distance, plot)
	max_force_y := to_y(sim.settings.max_force, y_offset, y_scale)

	inactive := uifw.Rect{max_distance_x, plot.y, max(plot.x + plot.w - max_distance_x, 0), plot.h}
	uifw.gui_rect(ctx, inactive, {0.06, 0.06, 0.06, 1})
	uifw.gui_rect(ctx, {plot.x, plot.y, max(beta_x - plot.x, 0), plot.h}, {0.94, 0.27, 0.27, 0.18})
	uifw.gui_rect(ctx, {beta_x, plot.y, max(max_distance_x - beta_x, 0), plot.h}, {0.23, 0.51, 0.96, 0.18})
	for i in 0 ..= 10 {
		x := plot.x + plot.w * f32(i) / 10
		uifw.gui_line(ctx, {x, plot.y}, {x, plot.y + plot.h}, {0.26, 0.26, 0.26, 0.65}, 1)
	}
	uifw.gui_line(ctx, {plot.x, y_offset}, {plot.x + plot.w, y_offset}, {0.42, 0.42, 0.42, 0.9}, 1)
	uifw.gui_line(ctx, {beta_x, plot.y}, {beta_x, plot.y + plot.h}, {0.90, 0.55, 0.10, 0.9}, 1)
	uifw.gui_line(ctx, {max_distance_x, plot.y}, {max_distance_x, plot.y + plot.h}, {0.23, 0.51, 0.96, 0.95}, 2)
	uifw.gui_line(ctx, {plot.x, plot.y}, {plot.x, plot.y + plot.h}, {0.32, 0.81, 0.40, 0.95}, 2)

	prev: uifw.Vec2
	for step in 0 ..= 160 {
		distance := sim.settings.max_distance * f32(step) / 160
		force := particle_life_force_curve_value(sim.settings.max_force, sim.settings.max_distance, sim.settings.beta, distance)
		p := uifw.Vec2{to_x(distance, max_plot_distance, plot), to_y(force, y_offset, y_scale)}
		if step > 0 {
			uifw.gui_line(ctx, prev, p, {0.94, 0.27, 0.27, 1}, 3)
		}
		prev = p
	}

	max_force_handle := uifw.Vec2{plot.x, max_force_y}
	max_distance_handle := uifw.Vec2{max_distance_x, y_offset}
	beta_handle := uifw.Vec2{beta_x, y_offset}
	force_id := uifw.gui_make_id(ctx, "pl_curve_force_handle")
	distance_id := uifw.gui_make_id(ctx, "pl_curve_distance_handle")
	beta_id := uifw.gui_make_id(ctx, "pl_curve_beta_handle")
	handle_hit_radius := max(ctx.style.row_height * 0.24, f32(14))
	force_hit := uifw.Rect{max_force_handle.x - handle_hit_radius, max_force_handle.y - handle_hit_radius, handle_hit_radius * 2, handle_hit_radius * 2}
	distance_hit := uifw.Rect{max_distance_handle.x - handle_hit_radius, max_distance_handle.y - handle_hit_radius, handle_hit_radius * 2, handle_hit_radius * 2}
	beta_hit := uifw.Rect{beta_handle.x - handle_hit_radius, beta_handle.y - handle_hit_radius, handle_hit_radius * 2, handle_hit_radius * 2}
	if ctx.input.mouse_pressed && uifw.gui_mouse_contains(ctx, beta_hit) {
		sim.runtime.force_curve_beta_drag_start_x = ctx.input.mouse_pos.x
		sim.runtime.force_curve_beta_drag_start_value = sim.settings.beta
	}
	if uifw.gui_drag_handle_region(ctx, force_id, force_hit, max_force_handle, 12) {
		fine := uifw.gui_pointer_fine_adjust_scale(ctx, force_id)
		if fine < 1 {
			sim.settings.max_force -= ctx.mouse_delta.y / max(y_scale, 0.0001) * fine
		} else {
			sim.settings.max_force = max((y_offset - ctx.input.mouse_pos.y) / y_scale, 0.1)
		}
		sim.settings.max_force = min(sim.settings.max_force, max_scale_force)
		sim.settings.max_force = max(sim.settings.max_force, 0.1)
	}
	_ = uifw.gui_update_focus_edit(ctx, force_id, ctx.focused == force_id)
	uifw.gui_controller_edit_f32(ctx, force_id, &sim.settings.max_force)
	force_nav_x, force_nav_y := uifw.gui_focused_nav_pressed(ctx, force_id)
	if force_nav_x != 0 || force_nav_y != 0 {
		sim.settings.max_force = min(max(sim.settings.max_force + (force_nav_x - force_nav_y) * max_scale_force * 0.02 * uifw.gui_fine_adjust_scale(ctx), 0.1), max_scale_force)
	}
	if uifw.gui_drag_handle_region(ctx, distance_id, distance_hit, max_distance_handle, 12) {
		fine := uifw.gui_pointer_fine_adjust_scale(ctx, distance_id)
		if fine < 1 {
			sim.settings.max_distance += ctx.mouse_delta.x / max(plot.w, 1) * max_plot_distance * fine
		} else {
			t := max(min((ctx.input.mouse_pos.x - plot.x) / max(plot.w, 1), 1), 0)
			sim.settings.max_distance = t * max_plot_distance
		}
		sim.settings.max_distance = min(max(sim.settings.max_distance, 0.001), max_plot_distance)
	}
	_ = uifw.gui_update_focus_edit(ctx, distance_id, ctx.focused == distance_id)
	uifw.gui_controller_edit_f32(ctx, distance_id, &sim.settings.max_distance)
	distance_nav_x, distance_nav_y := uifw.gui_focused_nav_pressed(ctx, distance_id)
	if distance_nav_x != 0 || distance_nav_y != 0 {
		sim.settings.max_distance = min(max(sim.settings.max_distance + (distance_nav_x - distance_nav_y) * max_plot_distance * 0.02 * uifw.gui_fine_adjust_scale(ctx), 0.001), max_plot_distance)
	}
	if uifw.gui_drag_handle_region(ctx, beta_id, beta_hit, beta_handle, 12) {
		delta_x := ctx.input.mouse_pos.x - sim.runtime.force_curve_beta_drag_start_x
		fine := uifw.gui_pointer_fine_adjust_scale(ctx, beta_id)
		if fine < 1 {
			sim.settings.beta += ctx.mouse_delta.x * 0.002 * fine
		} else {
			sim.settings.beta = sim.runtime.force_curve_beta_drag_start_value + delta_x * 0.002
		}
		sim.settings.beta = max(min(sim.settings.beta, 0.9), 0.1)
	}
	_ = uifw.gui_update_focus_edit(ctx, beta_id, ctx.focused == beta_id)
	uifw.gui_controller_edit_f32(ctx, beta_id, &sim.settings.beta)
	beta_nav_x, beta_nav_y := uifw.gui_focused_nav_pressed(ctx, beta_id)
	if beta_nav_x != 0 || beta_nav_y != 0 {
		sim.settings.beta = min(max(sim.settings.beta + (beta_nav_x - beta_nav_y) * 0.02 * uifw.gui_fine_adjust_scale(ctx), 0.1), 0.9)
	}
	uifw.gui_tooltip_for_id(ctx, force_id, "Max Force is the strongest attraction or repulsion particles can feel.")
	uifw.gui_tooltip_for_id(ctx, distance_id, "Range is how far a particle can influence another particle.")
	uifw.gui_tooltip_for_id(ctx, beta_id, "Beta sets where close-range repulsion gives way to the longer-range force.")
	handle_radius := max(ctx.style.row_height * 0.12, f32(7))
	uifw.gui_ellipse(ctx, {max_force_handle.x - handle_radius, max_force_handle.y - handle_radius, handle_radius * 2, handle_radius * 2}, {0.32, 0.81, 0.40, 1})
	uifw.gui_ellipse(ctx, {max_distance_handle.x - handle_radius, max_distance_handle.y - handle_radius, handle_radius * 2, handle_radius * 2}, {0.23, 0.51, 0.96, 1})
	uifw.gui_ellipse(ctx, {beta_handle.x - handle_radius, beta_handle.y - handle_radius, handle_radius * 2, handle_radius * 2}, {0.98, 0.75, 0.14, 1})
	uifw.gui_focus_or_edit_ring(ctx, force_id, force_hit)
	uifw.gui_focus_or_edit_ring(ctx, distance_id, distance_hit)
	uifw.gui_focus_or_edit_ring(ctx, beta_id, beta_hit)
	uifw.gui_text(ctx, {plot.x + ctx.style.spacing_1, plot.y + ctx.style.spacing_1}, "Close Range", ctx.style.text)
	uifw.gui_text(ctx, {beta_x + ctx.style.spacing_1, plot.y + ctx.style.spacing_1}, "Far Range", ctx.style.text)
	uifw.gui_text(ctx, {plot.x, bounds.y + bounds.h - ctx.style.body_line_height}, "Distance", ctx.style.text_muted)

	uifw.gui_label(ctx, fmt.tprintf("Force %.2f   Range %.3f   Beta %.2f", sim.settings.max_force, sim.settings.max_distance, sim.settings.beta))
}

particle_life_draw_matrix_transform_row :: proc(sim: ^Particle_Life_Simulation, ctx: ^uifw.Gui_Context, labels: []string, keys: []string, transforms: []Particle_Life_Matrix_Transform) {
	row := uifw.gui_next_rect(ctx, height = ctx.style.row_height)
	gap := ctx.style.spacing
	w := (row.w - gap * f32(len(labels) - 1)) / f32(max(len(labels), 1))
	for i in 0 ..< len(labels) {
		rect := uifw.Rect{row.x + f32(i) * (w + gap), row.y, w, row.h}
		if particle_life_small_button(ctx, rect, labels[i], keys[i]) {
			particle_life_apply_matrix_transform(sim, transforms[i])
		}
	}
}

particle_life_draw_force_matrix_editor :: proc(sim: ^Particle_Life_Simulation, ctx: ^uifw.Gui_Context) {
	n := int(max(min(sim.settings.species_count, PARTICLE_LIFE_MAX_SPECIES), 1))
	scheme := color_scheme_effective(&sim.settings.color_scheme, sim.settings.color_scheme_reversed)
	available := max(ctx.content_width, 220)
	cell := min(max(ctx.style.row_height * 1.35, f32(58)), available / f32(n + 1))
	grid_w := cell * f32(n + 1)
	grid_bounds := uifw.gui_next_rect(ctx, height = cell * f32(n + 1))
	left := grid_bounds.x + max((available - grid_w) * 0.5, 0)
	header_y := grid_bounds.y
	text_scale := cell < 58 ? f32(0.56) : f32(0.66)
	for j in 0 ..< n {
		r := uifw.Rect{left + cell * f32(j + 1), header_y, cell, cell}
		uifw.gui_text_aligned_scaled(ctx, r, fmt.tprintf("S%d", j + 1), particle_life_species_label_color(sim, scheme, j, n), .Center, 0.72)
	}
	for i in 0 ..< n {
		row_y := grid_bounds.y + cell * f32(i + 1)
		uifw.gui_text_aligned_scaled(ctx, {left, row_y, cell, cell}, fmt.tprintf("S%d", i + 1), particle_life_species_label_color(sim, scheme, i, n), .Center, 0.72)
		for j in 0 ..< n {
			index := i * PARTICLE_LIFE_MAX_SPECIES + j
			value := sim.runtime.force_matrix[index]
			previous_value := value
			rect := uifw.Rect{left + cell * f32(j + 1), row_y, cell, cell}
			id := uifw.gui_make_id(ctx, fmt.tprintf("pl_matrix_%d_%d", i, j))
			control := uifw.gui_control(ctx, id, rect, true)
			_ = uifw.gui_update_focus_edit(ctx, id, control.focused)
			uifw.gui_controller_edit_f32(ctx, id, &value)
			if ctx.active == id && ctx.input.mouse_down {
				delta := (ctx.input.wheel_delta * 0.1 + ctx.mouse_delta.x * 0.01) * uifw.gui_fine_adjust_scale(ctx)
				if delta != 0 {
					value = max(min(value + delta, 1), -1)
				}
			}
			nav_x, nav_y := uifw.gui_focused_nav_pressed(ctx, id)
			if nav_x != 0 || nav_y != 0 {
				value = max(min(value + (nav_x - nav_y) * 0.1 * uifw.gui_fine_adjust_scale(ctx), 1), -1)
			}
			if value != previous_value {
				particle_life_set_force_value(sim, u32(i), u32(j), value)
			}
			color := particle_life_force_matrix_color(value)
			if ctx.hot == id || ctx.active == id || control.focused {
				color.a = 1
			}
			uifw.gui_rect(ctx, rect, color)
			uifw.gui_stroke(ctx, rect, ctx.style.panel_border)
			force_text_scale := max(ctx.style.text_scale * text_scale, 0.5)
			force_text_h := uifw.GUI_FONT_LOGICAL_HEIGHT * force_text_scale
			text_rect := uifw.Rect{rect.x, rect.y + max((rect.h - force_text_h) * 0.5, 0), rect.w, force_text_h}
			uifw.gui_text_aligned_scaled(ctx, text_rect, particle_life_force_cell_label(value), ctx.style.text, .Center, text_scale)
			uifw.gui_focus_or_edit_ring(ctx, id, rect)
		}
	}
	uifw.gui_text_block(ctx, "-1 repels   0 neutral   +1 attracts", ctx.content_width, ctx.style.text_muted)
	uifw.gui_text_block(ctx, "Transforms keep diagonal self-repulsion values.", ctx.content_width, ctx.style.text_muted)

	particle_life_draw_matrix_transform_row(sim, ctx, []string{"-20%", "+20%"}, []string{"pl_matrix_scale_down", "pl_matrix_scale_up"}, []Particle_Life_Matrix_Transform{.Scale_Down, .Scale_Up})
	particle_life_draw_matrix_transform_row(sim, ctx, []string{"Rot CCW", "Rot CW"}, []string{"pl_matrix_rot_ccw", "pl_matrix_rot_cw"}, []Particle_Life_Matrix_Transform{.Rotate_CCW, .Rotate_CW})
	particle_life_draw_matrix_transform_row(sim, ctx, []string{"Flip H", "Flip V"}, []string{"pl_matrix_flip_h", "pl_matrix_flip_v"}, []Particle_Life_Matrix_Transform{.Flip_H, .Flip_V})
	particle_life_draw_matrix_transform_row(sim, ctx, []string{"Shift L", "Shift R"}, []string{"pl_matrix_shift_l", "pl_matrix_shift_r"}, []Particle_Life_Matrix_Transform{.Shift_Left, .Shift_Right})
	particle_life_draw_matrix_transform_row(sim, ctx, []string{"Shift U", "Shift D"}, []string{"pl_matrix_shift_u", "pl_matrix_shift_d"}, []Particle_Life_Matrix_Transform{.Shift_Up, .Shift_Down})
	particle_life_draw_matrix_transform_row(sim, ctx, []string{"Zero", "Flip Sign"}, []string{"pl_matrix_zero", "pl_matrix_sign"}, []Particle_Life_Matrix_Transform{.Zero, .Flip_Sign})
}

particle_life_species_label_color :: proc(sim: ^Particle_Life_Simulation, scheme: Color_Scheme, species_index, species_count: int) -> uifw.Color {
	t := 0
	if sim.settings.background_color_mode == .Color_Scheme && species_count > 0 {
		t = int(((species_index + 1) * (COLOR_SCHEME_SIZE - 1)) / species_count)
	} else if PARTICLE_LIFE_MAX_SPECIES > 1 {
		t = int((species_index * (COLOR_SCHEME_SIZE - 1)) / (PARTICLE_LIFE_MAX_SPECIES - 1))
	}
	t = max(min(t, COLOR_SCHEME_SIZE - 1), 0)
	return {
		f32(scheme.red[t]) / 255.0,
		f32(scheme.green[t]) / 255.0,
		f32(scheme.blue[t]) / 255.0,
		1,
	}
}

particle_life_draw_controls :: proc(sim: ^Particle_Life_Simulation, ctx: ^uifw.Gui_Context, panel: uifw.Rect, scroll: ^f32, worker: ^Product_Context, color_editor: ^Color_Scheme_Editor_State, section := -1) {
	uifw.gui_panel_begin(ctx, panel)
	viewport := uifw.gui_next_rect(ctx, height = max(panel.h - ctx.style.panel_padding * 2, 0))
	uifw.gui_scroll_begin(ctx, viewport, particle_life_controls_content_height(sim, ctx, section), scroll)

	if section < 0 || section == 0 {
	uifw.gui_heading(ctx, "About this simulation")
	uifw.gui_text_block(ctx, "Particle Life is a simulation where particles of different species interact with each other based on a force force_values.", panel.w - ctx.style.panel_padding * 2, ctx.style.text)
	uifw.gui_text_block(ctx, "Positive values attract, negative values repel, and values near zero stay neutral.", panel.w - ctx.style.panel_padding * 2, ctx.style.text_muted)
	uifw.gui_spacer(ctx, 8)
	}

	if section < 0 || section == 1 || section == CONTROLLER_SECTION_PRESETS {
	uifw.gui_heading(ctx, "Presets")
	preset_fieldset_draw(
		ctx,
		&sim.runtime.preset_ui,
		worker,
		"particle_life",
		PARTICLE_LIFE_BUILTIN_PRESET_NAMES[:],
		sim.runtime.current_preset_index,
		Preset_Fieldset_Builtin_Context {kind = .Particle_Life, particle_life = sim},
	)
	if section == CONTROLLER_SECTION_PRESETS {
		uifw.gui_spacer(ctx, 8)
		uifw.gui_heading(ctx, "Start Over")
		if uifw.gui_button(ctx, "Regenerate Particles", "pl_reset") {
			particle_life_reset_runtime(sim)
			uifw.gui_notice(ctx, "Particles regenerated. Your force and physics settings stayed unchanged.")
		}
	}
	if section == 1 || section == CONTROLLER_SECTION_PRESETS {
		uifw.gui_spacer(ctx, 8)
		uifw.gui_heading(ctx, "About this simulation")
		uifw.gui_text_block(ctx, "Particle Life is a simulation where particles of different species attract or repel each other according to a force matrix.", panel.w - ctx.style.panel_padding * 2, ctx.style.text)
		uifw.gui_text_block(ctx, "Positive values attract, negative values repel, and values near zero stay neutral.", panel.w - ctx.style.panel_padding * 2, ctx.style.text_muted)
	}
	uifw.gui_spacer(ctx, 8)
	}

	if section < 0 || section == 2 || section == CONTROLLER_SECTION_LOOK {
	uifw.gui_heading(ctx, "Display Settings")
	color_mode_index := int(u32(sim.settings.color_mode))
	if uifw.gui_selector(ctx, fmt.tprintf("Particle Color Mode: %s", PARTICLE_LIFE_COLOR_MODE_NAMES[color_mode_index]), "pl_color_mode", &color_mode_index, PARTICLE_LIFE_COLOR_MODE_NAMES[:]) {
		sim.settings.color_mode = Particle_Life_Color_Mode(u32(max(min(color_mode_index, len(PARTICLE_LIFE_COLOR_MODE_NAMES) - 1), 0)))
	}
	_ = color_scheme_editor_draw_selector(ctx, color_editor, "particle_life_color_scheme", &sim.settings.color_scheme, &sim.settings.color_scheme_reversed)
	if uifw.gui_selector(ctx, fmt.tprintf("Background Color Mode: %s", VECTOR_BACKGROUND_MODE_NAMES[sim.settings.background_index]), "pl_background", &sim.settings.background_index, VECTOR_BACKGROUND_MODE_NAMES[:]) {
		sim.settings.background_color_mode = Vector_Background_Mode(sim.settings.background_index)
	}
	if uifw.gui_toggle(ctx, fmt.tprintf("Enable Particle Traces: %v", sim.settings.trails_enabled), "pl_trails", &sim.settings.trails_enabled) {
		sim.gpu.trail_initialized = false
	}
	if sim.settings.trails_enabled {
		_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Trace Fade: %.2f", sim.settings.trail_fade_amount), "pl_trail_fade", &sim.settings.trail_fade_amount, 0.0, 1.0)
		if uifw.gui_button(ctx, "Clear Trails", "pl_clear_trails") {
			sim.gpu.trail_initialized = false
			sim.runtime.trail_camera_valid = false
		}
	}
	uifw.gui_spacer(ctx, 8)

	post_options := shared_default_post_processing_menu_options()
	_ = shared_post_processing_menu(ctx, &sim.settings.post_processing.blur_enabled, &sim.settings.post_processing.blur_radius, &sim.settings.post_processing.blur_sigma, post_options)
	uifw.gui_spacer(ctx, 8)

	uifw.gui_heading(ctx, "Display Adjustments")
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Brightness: %.2f", sim.settings.brightness), "pl_brightness", &sim.settings.brightness, 0, 2.5)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Contrast: %.2f", sim.settings.contrast), "pl_contrast", &sim.settings.contrast, 0, 2.5)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Saturation: %.2f", sim.settings.saturation), "pl_saturation", &sim.settings.saturation, 0, 2.5)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Gamma: %.2f", sim.settings.gamma), "pl_gamma", &sim.settings.gamma, 0.1, 4.0)
	uifw.gui_spacer(ctx, 8)
	}

	if section < 0 || section == 3 {
	tool_set := canvas_tool_set_for_mode(.Particle_Life)
	shared_canvas_tool_selector(ctx, &tool_set, &sim.canvas_tool)
	cursor_options := shared_default_cursor_config_options()
	cursor_options.size_min = 0.05
	cursor_options.size_max = 1.0
	cursor_options.strength_min = 0.0
	cursor_options.strength_max = 20.0
	controls_options := Controls_Panel_Options {
		heading = section >= 0 ? "Brush" : "Controls",
		mouse_interaction_text = "",
		cursor_settings_title = "",
		cursor = cursor_options,
	}
	_ = shared_controls_panel(ctx, controls_options, &sim.settings.cursor_size, &sim.settings.cursor_strength)
	uifw.gui_spacer(ctx, 8)
	}

	if section < 0 || section == 4 || section == PARTICLE_LIFE_SECTION_POPULATION {
	uifw.gui_heading(ctx, section == PARTICLE_LIFE_SECTION_POPULATION ? "Population" : "Settings")
	if section != PARTICLE_LIFE_SECTION_POPULATION && uifw.gui_button(ctx, "Regenerate Particles", "pl_reset") {
		particle_life_reset_runtime(sim)
		uifw.gui_notice(ctx, "Particles regenerated. Your force and physics settings stayed unchanged.")
	}
	position_index := int(max(min(sim.settings.position_generator, u32(len(PARTICLE_LIFE_POSITION_GENERATOR_NAMES) - 1)), 0))
	if uifw.gui_selector(ctx, fmt.tprintf("Regenerate Positions: %s", PARTICLE_LIFE_POSITION_GENERATOR_NAMES[position_index]), "pl_position_generator", &position_index, PARTICLE_LIFE_POSITION_GENERATOR_NAMES[:]) {
		sim.settings.position_generator = u32(position_index)
		particle_life_reset_runtime(sim)
	}
	type_index := int(max(min(sim.settings.type_generator, u32(len(PARTICLE_LIFE_TYPE_GENERATOR_NAMES) - 1)), 0))
	if uifw.gui_selector(ctx, fmt.tprintf("Regenerate Types: %s", PARTICLE_LIFE_TYPE_GENERATOR_NAMES[type_index]), "pl_type_generator", &type_index, PARTICLE_LIFE_TYPE_GENERATOR_NAMES[:]) {
		sim.settings.type_generator = u32(type_index)
		particle_life_reset_runtime(sim)
	}
	if uifw.gui_numeric_u32(ctx, "Particle Count", "pl_count", &sim.settings.particle_count, 1000, PARTICLE_LIFE_MAX_PARTICLE_COUNT, 1000) {
		particle_life_clear_preserved_particles(sim)
		sim.runtime.needs_reset = true
		sim.gpu.ready = false
	}
	if uifw.gui_numeric_u32(ctx, "Species Count", "pl_species", &sim.settings.species_count, 2, PARTICLE_LIFE_MAX_SPECIES) {
		particle_life_clear_preserved_particles(sim)
		sim.runtime.needs_reset = true
		sim.gpu.ready = false
	}
	_ = uifw.gui_toggle(ctx, fmt.tprintf("Wrap Edges: %v", sim.settings.wrap_edges), "pl_wrap", &sim.settings.wrap_edges)
	if section != PARTICLE_LIFE_SECTION_POPULATION {
		_ = uifw.gui_toggle(ctx, fmt.tprintf("Paused: %v", sim.settings.paused), "pl_paused", &sim.settings.paused)
	}
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Particle Size: %.1f", sim.settings.particle_size), "pl_size", &sim.settings.particle_size, 2, 34)
	}

	if section < 0 || section == 4 || section == PARTICLE_LIFE_SECTION_FORCES {
	if section == PARTICLE_LIFE_SECTION_FORCES {
		uifw.gui_heading(ctx, "Forces")
	}
	if uifw.gui_button(ctx, "Regenerate Matrix", "pl_randomize") {
		particle_life_randomize_forces(sim)
		uifw.gui_notice(ctx, "Force matrix randomized. Restore Previous Matrix is available here.")
	}
	if sim.runtime.force_randomize_undo_available && uifw.gui_button(ctx, "Restore Previous Matrix", "pl_undo_randomize") {
		if particle_life_undo_randomize_forces(sim) {
			uifw.gui_notice(ctx, "Previous force matrix restored.")
		}
	}
	matrix_hint := ctx.input.active_device == .Controller ? "Select a cell, press Accept, then adjust it with the D-pad." : "Drag horizontally across a cell to change its force."
	uifw.gui_text_block(ctx, matrix_hint, panel.w - ctx.style.panel_padding * 2, ctx.style.text_muted)
	force_index := int(max(min(sim.settings.force_generator, u32(len(PARTICLE_LIFE_FORCE_GENERATOR_NAMES) - 1)), 0))
	if uifw.gui_selector(ctx, fmt.tprintf("Force Generator: %s", PARTICLE_LIFE_FORCE_GENERATOR_NAMES[force_index]), "pl_force_generator", &force_index, PARTICLE_LIFE_FORCE_GENERATOR_NAMES[:]) {
		sim.settings.force_generator = u32(force_index)
	}
	_ = shared_range_slider_f32(ctx, "Random Force Range", "pl_force_range", &sim.settings.force_random_min, &sim.settings.force_random_max, -1.5, 1.5)
	shared_range_explanation(ctx, "pl_force_range", "Random Force Range sets the weakest and strongest values used when the matrix is regenerated.")
	particle_life_draw_force_matrix_editor(sim, ctx)
	}

	if section < 0 || section == 5 {
	uifw.gui_spacer(ctx, 8)
	uifw.gui_heading(ctx, "Physics")
	if section < 0 {
		_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Max Force: %.2f", sim.settings.max_force), "pl_force", &sim.settings.max_force, 0.1, 10.0)
		shared_control_explanation(ctx, "pl_force", "Max Force is the strongest attraction or repulsion particles can feel.")
		_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Range: %.2f", sim.settings.max_distance), "pl_range", &sim.settings.max_distance, 0.01, 1.0)
		shared_control_explanation(ctx, "pl_range", "Range is how far a particle can influence another particle.")
		_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Beta: %.2f", sim.settings.beta), "pl_beta", &sim.settings.beta, 0.1, 0.9)
		shared_control_explanation(ctx, "pl_beta", "Beta sets where close-range repulsion gives way to the longer-range force.")
	}
	particle_life_draw_force_curve_editor(sim, ctx)
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Friction: %.2f", sim.settings.friction), "pl_friction", &sim.settings.friction, 0.01, 1.0)
	shared_control_explanation(ctx, "pl_friction", "Friction controls how quickly motion settles. Higher values calm particles sooner.")
	_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Brownian: %.3f", sim.settings.brownian_motion), "pl_brownian", &sim.settings.brownian_motion, 0.0, 1.0)
	shared_control_explanation(ctx, "pl_brownian", "Brownian motion adds small random nudges, keeping particles from moving too perfectly.")
	_ = uifw.gui_toggle(ctx, fmt.tprintf("Dense Cell Sampling: %v", sim.settings.force_dense_sampling), "pl_dense_cell_sampling", &sim.settings.force_dense_sampling)
	shared_control_explanation(ctx, "pl_dense_cell_sampling", "Caps work in overcrowded grid cells using rotating weighted samples. Disable for fully exact force evaluation.")

	uifw.gui_spacer(ctx, 8)
	uifw.gui_heading(ctx, "Local Constraints")
	if uifw.gui_toggle(ctx, fmt.tprintf("Collisions: %v", sim.settings.collision_enabled), "pl_collision_enabled", &sim.settings.collision_enabled) {
		if !particle_life_current_grid_satisfies_settings(sim) {
			particle_life_request_resource_rebuild(sim)
		}
	}
	if sim.settings.collision_enabled {
		uifw.gui_text_block(ctx, fmt.tprintf("Distance follows particle size: %.4f", particle_life_collision_distance(sim.settings)), panel.w - ctx.style.panel_padding * 2, ctx.style.text_muted)
		_ = uifw.gui_numeric_u32(ctx, "Iterations", "pl_collision_iterations", &sim.settings.collision_iterations, 1, 8)
		_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Relaxation: %.2f", sim.settings.collision_relaxation), "pl_collision_relaxation", &sim.settings.collision_relaxation, 0.0, 1.0)
		_ = uifw.gui_slider_f32(ctx, fmt.tprintf("Damping: %.2f", sim.settings.collision_damping), "pl_collision_damping", &sim.settings.collision_damping, 0.0, 1.0)
	}
	}

	if section < 0 || section == 7 || section == PARTICLE_LIFE_SECTION_ADVANCED {
	uifw.gui_spacer(ctx, 8)
	uifw.gui_heading(ctx, "Camera")
	if uifw.gui_button(ctx, "Reset View", "pl_reset_view") {
		particle_life_reset_camera(sim)
	}
	if uifw.gui_slider_f32(ctx, fmt.tprintf("Zoom: %.2f", sim.runtime.camera_zoom), "pl_camera_zoom", &sim.runtime.camera_zoom, 0.25, 24.0) {
		sim.runtime.camera_target_zoom = sim.runtime.camera_zoom
	}
	if uifw.gui_numeric_f32(ctx, fmt.tprintf("Pan X: %.2f", sim.runtime.camera_x), "pl_camera_x", &sim.runtime.camera_x, 0.05, -8.0, 8.0, mapping = .Symmetric_Log) {
		sim.runtime.camera_target_x = sim.runtime.camera_x
	}
	if uifw.gui_numeric_f32(ctx, fmt.tprintf("Pan Y: %.2f", sim.runtime.camera_y), "pl_camera_y", &sim.runtime.camera_y, 0.05, -8.0, 8.0, mapping = .Symmetric_Log) {
		sim.runtime.camera_target_y = sim.runtime.camera_y
	}
	}
	uifw.gui_scroll_end(ctx)
	uifw.gui_panel_end(ctx)
	preset_save_dialog_draw(ctx, &sim.runtime.preset_ui, worker, "particle_life")
}
