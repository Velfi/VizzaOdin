package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"
import "core:os"
import "core:strings"

Preset_Fieldset_State :: struct {
	selected_index: int,
	query_buffer: [64]u8,
	save_open: bool,
	save_open_frame: u64,
	save_invoker_focus: uifw.Gui_Id,
	save_name: [MAX_PRESET_NAME]u8,
	save_name_len: int,
	initialized: bool,
	select_saved_when_available: bool,
	select_saved_name: [MAX_PRESET_NAME]u8,
	select_saved_name_len: int,
}

Preset_Fieldset_Builtin_Kind :: enum {
	None,
	Gray_Scott,
	Particle_Life,
	Remaining,
	ST_Flip,
}

Preset_Fieldset_Builtin_Context :: struct {
	kind: Preset_Fieldset_Builtin_Kind,
	gray_scott: ^Gray_Scott_Simulation,
	particle_life: ^Particle_Life_Simulation,
	remaining: ^Remaining_Sim_State,
	remaining_kind: Remaining_Sim_Kind,
	st_flip: ^ST_Flip_Simulation,
}

preset_fieldset_draw :: proc(
	ctx: ^uifw.Gui_Context,
	state: ^Preset_Fieldset_State,
	worker: ^Product_Context,
	simulation_directory: string,
	builtin_names: []string,
	builtin_selected_index: int,
	builtin_context: Preset_Fieldset_Builtin_Context,
) {
	saved_presets := preset_names_for_simulation(worker, simulation_directory)
	defer delete(saved_presets)
	presets := preset_combined_names(builtin_names, saved_presets[:])
	defer delete(presets)
	// Saving is handled through the render command queue. Keep the just-saved
	// name visible while the filesystem view catches up with that command.
	if state.select_saved_when_available {
		pending := string(state.select_saved_name[:state.select_saved_name_len])
		if len(pending) > 0 && !preset_name_in_list(presets[:], pending) {
			append(&presets, pending)
		}
	}

	if !state.initialized {
		state.selected_index = max(min(builtin_selected_index, len(presets) - 1), 0)
		state.initialized = true
	}
	preset_fieldset_select_pending_saved(state, presets[:], saved_presets[:])

	if len(presets) > 0 {
		state.selected_index = max(min(state.selected_index, len(presets) - 1), 0)
		if preset_fieldset_draw_selector(ctx, state, presets[:]) {
			preset_fieldset_apply_selection(state.selected_index, worker, simulation_directory, builtin_names, presets[:], builtin_context)
		}
	} else {
		uifw.gui_label(ctx, "No presets yet")
	}

	if uifw.gui_button(ctx, "Save Current Settings", "save_current_settings") {
		state.save_open = true
		state.save_open_frame = ctx.frame_index
		state.save_invoker_focus = ctx.focused
		state.save_name_len = 0
	}
}

preset_fieldset_draw_selector :: proc(ctx: ^uifw.Gui_Context, state: ^Preset_Fieldset_State, presets: []string) -> bool {
	return uifw.gui_stepper_combobox(
		ctx,
		"Select preset...",
		"preset_select",
		&state.selected_index,
		presets,
		state.query_buffer[:],
		"Previous preset",
		"Next preset",
	)
}

preset_fieldset_content_rows :: proc(state: ^Preset_Fieldset_State) -> int {
	return 2
}

preset_names_for_simulation :: proc(worker: ^Product_Context, simulation_directory: string) -> [dynamic]string {
	names := make([dynamic]string, 0, 16, context.temp_allocator)
	if worker == nil {
		return names
	}
	dir := fmt.tprintf("%s/%s", worker.settings.preset_directory, simulation_directory)
	infos, err := os.read_all_directory_by_path(dir, context.temp_allocator)
	if err != nil {
		return names
	}
	defer os.file_info_slice_delete(infos, context.temp_allocator)

	for info in infos {
		if info.type == .Regular && strings.has_suffix(info.name, ".toml") {
			name := strings.trim_suffix(info.name, ".toml")
			append(&names, strings.clone(name, context.temp_allocator) or_continue)
		}
	}
	return names
}

preset_combined_names :: proc(builtin_names, saved_names: []string) -> [dynamic]string {
	names := make([dynamic]string, 0, len(builtin_names) + len(saved_names), context.temp_allocator)
	for name in builtin_names {
		append(&names, name)
	}
	for name in saved_names {
		if !preset_name_in_list(builtin_names, name) {
			append(&names, name)
		}
	}
	return names
}

preset_name_in_list :: proc(names: []string, name: string) -> bool {
	for item in names {
		if item == name {
			return true
		}
	}
	return false
}

preset_fieldset_select_pending_saved :: proc(state: ^Preset_Fieldset_State, names, saved_names: []string) {
	if !state.select_saved_when_available {
		return
	}
	pending := string(state.select_saved_name[:state.select_saved_name_len])
	for name, i in names {
		if name == pending {
			state.selected_index = i
			if preset_name_in_list(saved_names, pending) {
				state.select_saved_when_available = false
				state.select_saved_name_len = 0
			}
			return
		}
	}
}

preset_fieldset_apply_selection :: proc(
	selected_index: int,
	worker: ^Product_Context,
	simulation_directory: string,
	builtin_names: []string,
	preset_names: []string,
	builtin_context: Preset_Fieldset_Builtin_Context,
) {
	if selected_index < 0 || selected_index >= len(preset_names) {
		return
	}
	if selected_index < len(builtin_names) {
		preset_fieldset_apply_builtin(builtin_context, selected_index)
		return
	}
	preset_fieldset_enqueue(worker, .Load, simulation_directory, preset_names[selected_index])
}

preset_fieldset_apply_builtin :: proc(builtin_context: Preset_Fieldset_Builtin_Context, index: int) {
	#partial switch builtin_context.kind {
	case .Gray_Scott:
		if builtin_context.gray_scott != nil {
			gray_scott_apply_builtin_preset(builtin_context.gray_scott, index)
		}
	case .Particle_Life:
		if builtin_context.particle_life != nil {
			particle_life_apply_builtin_preset(builtin_context.particle_life, index)
		}
	case .Remaining:
		if builtin_context.remaining != nil {
			remaining_sim_apply_builtin_preset(builtin_context.remaining, builtin_context.remaining_kind, index)
		}
	case .ST_Flip:
		if builtin_context.st_flip != nil {
			_ = feature_apply_builtin_st_flip(builtin_context.st_flip.settings, builtin_context.st_flip.runtime, index)
		}
	case:
	}
}

Preset_Save_Document_Context :: struct {
	state: ^Preset_Fieldset_State,
}

preset_save_dialog_document_name_slot :: proc(data: rawptr, ctx: ^uifw.Gui_Context, bounds: uifw.Rect) {
	document_context := cast(^Preset_Save_Document_Context)data
	if document_context == nil || document_context.state == nil || ctx == nil do return
	uifw.gui_label(ctx, "Preset Name")
	_ = uifw.gui_text_input(ctx, "Enter preset name...", "preset_save_name", document_context.state.save_name[:], &document_context.state.save_name_len)
}

preset_save_dialog_draw :: proc(ctx: ^uifw.Gui_Context, state: ^Preset_Fieldset_State, worker: ^Product_Context, simulation_directory: string) {
	if !state.save_open {
		return
	}

	window_w := f32(ctx.input.window_width)
	window_h := f32(ctx.input.window_height)
	if window_w <= 0 || window_h <= 0 {
		window_w = max(ctx.content_width + ctx.style.panel_padding * 2, 360)
		window_h = ctx.style.row_height * 9
	}
	overlay := uifw.Rect{0, 0, window_w, window_h}
	viewport_dialog_w := max(window_w - ctx.style.spacing_2 * 2, 1)
	// Keep the modal proportional to the scaled type. A fixed maximum width clips
	// the heading and controls at larger UI scales.
	content_w := max(
		ctx.style.heading_char_width * f32(len("Save Preset")) + ctx.style.spacing_1 * 2,
		ctx.style.body_char_width * f32(len("Enter preset name...")) + ctx.style.control_padding * 3,
	)
	dialog_w := min(max(content_w + ctx.style.panel_padding * 2, 300), viewport_dialog_w)
	// Heading, label, text input, and button row, with one layout gap between
	// each pair. Measuring those rows directly avoids the empty fifth-row tail.
	dialog_h := ctx.style.heading_line_height + ctx.style.body_line_height + ctx.style.row_height * 2 +
		ctx.style.spacing * 3 + ctx.style.panel_padding * 2
	dialog_h = min(dialog_h, max(window_h - ctx.style.spacing_2 * 2, 1))
	dialog := uifw.Rect{
		x = max((window_w - dialog_w) * 0.5, ctx.style.spacing_2),
		y = max((window_h - dialog_h) * 0.5, ctx.style.spacing_2),
		w = dialog_w,
		h = dialog_h,
	}
	document: ^uifw.Ui_Document
	document_found := false
	if worker != nil && worker.documents != nil {
		document, document_found = uifw.ui_document_assets_find(worker.documents, "preset_dialog")
		if document_found {
			dialog = uifw.ui_document_solve_root_bounds(document, overlay)
		}
	}

	uifw.gui_push_id(ctx, "preset_save_dialog")
	uifw.gui_rect(ctx, overlay, {0, 0, 0, 0.70})
	uifw.gui_overlay_input_begin(ctx, overlay)
	if ctx.frame_index > state.save_open_frame && ctx.input.mouse_released && !uifw.gui_contains(dialog, ctx.input.mouse_pos) {
		preset_save_dialog_close(state)
		preset_save_dialog_restore_focus(ctx, state)
		uifw.gui_overlay_input_cancel(ctx)
		uifw.gui_pop_id(ctx)
		return
	}
	if ctx.frame_index > state.save_open_frame && ctx.input.back {
		preset_save_dialog_close(state)
		preset_save_dialog_restore_focus(ctx, state)
		uifw.gui_overlay_input_cancel(ctx)
		uifw.gui_pop_id(ctx)
		return
	}
	if ctx.frame_index == state.save_open_frame {
		// The action that opened the modal belongs to the covered panel. Do not
		// let that same press also activate the first modal control.
		ctx.input.mouse_pressed = false
		ctx.input.mouse_released = false
		ctx.input.nav_pressed_x = 0
		ctx.input.nav_pressed_y = 0
		ctx.input.accept = false
		ctx.input.back = false
		ctx.input.focus_next = false
		ctx.input.focus_prev = false
		ctx.input.primary_pressed = false
		ctx.input.primary_released = false
		ctx.input.secondary_pressed = false
		ctx.input.secondary_released = false
		ctx.input.key_tab = false
		ctx.input.key_enter = false
		ctx.input.key_escape = false
	}
	uifw.gui_spatial_group_begin(ctx, "preset_modal_focus_scope")
	defer uifw.gui_spatial_group_end(ctx)
	uifw.gui_focus_scope_trap_current(ctx)
	previous_explicit_activation := ctx.controller_explicit_activation
	ctx.controller_explicit_activation = previous_explicit_activation || ctx.input.active_device == .Controller
	defer ctx.controller_explicit_activation = previous_explicit_activation

	save_enabled := preset_save_dialog_has_name(state)
	confirmed := false
	cancelled := false
	if document_found {
		document_context := Preset_Save_Document_Context {state}
		bindings := [?]uifw.Ui_Document_Runtime_Binding {
			{id = "name_slot", kind = .Slot, userdata = &document_context, draw_slot = preset_save_dialog_document_name_slot, slot_content_height = ctx.style.body_line_height + ctx.style.row_height + ctx.style.spacing},
			{id = "confirm_enabled", kind = .Enabled, bool_value = &save_enabled},
			{id = "confirm", kind = .Action},
			{id = "cancel", kind = .Action},
		}
		actions: uifw.Ui_Document_Action_State
		result := uifw.ui_document_draw(document, ctx, overlay, bindings[:], &actions)
		if result.error == .None {
			for action in actions.ids[:actions.count] {
				if action == "confirm" do confirmed = true
				if action == "cancel" do cancelled = true
			}
		} else {
			document_found = false
		}
	}
	if !document_found {
		uifw.gui_panel_begin(ctx, dialog)
		uifw.gui_heading(ctx, "Save Preset")
		preset_save_dialog_document_name_slot(&Preset_Save_Document_Context{state}, ctx, dialog)
		button_row := uifw.gui_next_rect(ctx, height = ctx.style.row_height)
		button_gap := ctx.style.spacing
		button_w := max((button_row.w - button_gap) * 0.5, ctx.style.row_height)
		confirmed = uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, "preset_save_confirm"), {button_row.x, button_row.y, button_w, button_row.h}, "Save", save_enabled) && save_enabled
		cancelled = uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, "preset_save_cancel"), {button_row.x + button_w + button_gap, button_row.y, button_w, button_row.h}, "Cancel", true)
		uifw.gui_panel_end(ctx)
	}
	confirmed = confirmed || ctx.input.key_enter && save_enabled
	if confirmed {
		preset_save_dialog_commit(state, worker, simulation_directory)
		preset_save_dialog_restore_focus(ctx, state)
		uifw.gui_focus_scope_release(ctx)
	} else if cancelled {
		preset_save_dialog_close(state)
		preset_save_dialog_restore_focus(ctx, state)
		uifw.gui_focus_scope_release(ctx)
	}
	if state.save_open {
		uifw.gui_overlay_input_end(ctx)
	} else {
		uifw.gui_overlay_input_cancel(ctx)
	}
	uifw.gui_pop_id(ctx)
}

preset_save_dialog_has_name :: proc(state: ^Preset_Fieldset_State) -> bool {
	return len(strings.trim_space(string(state.save_name[:state.save_name_len]))) > 0
}

preset_save_dialog_commit :: proc(state: ^Preset_Fieldset_State, worker: ^Product_Context, simulation_directory: string) {
	name := strings.trim_space(string(state.save_name[:state.save_name_len]))
	preset_fieldset_enqueue(worker, .Save, simulation_directory, name)
	state.select_saved_when_available = true
	display_name := strings.trim_suffix(preset_filename_from_name(name), ".toml")
	state.select_saved_name_len = min(len(display_name), len(state.select_saved_name))
	name_bytes := transmute([]u8)display_name
	for i in 0 ..< state.select_saved_name_len {
		state.select_saved_name[i] = name_bytes[i]
	}
	preset_save_dialog_close(state)
}

preset_save_dialog_close :: proc(state: ^Preset_Fieldset_State) {
	state.save_open = false
	state.save_open_frame = 0
	state.save_name_len = 0
}

preset_save_dialog_restore_focus :: proc(ctx: ^uifw.Gui_Context, state: ^Preset_Fieldset_State) {
	if ctx != nil && state.save_invoker_focus != uifw.GUI_ID_NONE {
		ctx.focused = state.save_invoker_focus
	}
	state.save_invoker_focus = uifw.GUI_ID_NONE
}

preset_name_accepts_char :: proc(ch: rune) -> bool {
	return (ch >= 'a' && ch <= 'z') ||
		(ch >= 'A' && ch <= 'Z') ||
		(ch >= '0' && ch <= '9') ||
		ch == ' ' || ch == '_' || ch == '-' || ch == '.'
}

preset_feature_id_for_directory :: proc(directory: string) -> (Feature_Id, bool) {
	switch directory {
	case "slime_mold": return FEATURE_ID_SLIME_MOLD, true
	case "gray_scott": return FEATURE_ID_GRAY_SCOTT, true
	case "particle_life": return FEATURE_ID_PARTICLE_LIFE, true
	case "flow_field": return FEATURE_ID_FLOW_FIELD, true
	case "pellets": return FEATURE_ID_PELLETS, true
	case "voronoi_ca": return FEATURE_ID_VORONOI, true
	case "moire": return FEATURE_ID_MOIRE, true
	case "vectors": return FEATURE_ID_VECTORS, true
	case "primordial": return FEATURE_ID_PRIMORDIAL, true
	case "st_flip": return FEATURE_ID_ST_FLIP, true
	case: return {}, false
	}
}

preset_fieldset_enqueue :: proc(worker: ^Product_Context, operation: Feature_Preset_File_Operation, simulation_directory, preset_name: string) {
	if worker == nil || worker.ui_to_render == nil {
		return
	}
	feature_id, found := preset_feature_id_for_directory(simulation_directory)
	if !found do return
	filename := preset_filename_from_name(preset_name)
	path := fmt.tprintf("%s/%s", simulation_directory, filename)
	payload := Feature_Preset_File_Command {operation = operation}
	write_fixed_string(payload.path[:], path)
	feature, ok := feature_command_make(feature_id, FEATURE_COMMAND_PRESET_FILE, &payload)
	if ok {
		_ = engine.queue_try_push(worker.ui_to_render, Ui_To_Render_Command {kind = .Feature, feature = feature})
	}
}

preset_filename_from_name :: proc(name: string) -> string {
	stem := preset_filename_stem(name)
	if strings.has_suffix(stem, ".toml") {
		return stem
	}
	return fmt.tprintf("%s.toml", stem)
}

preset_filename_stem :: proc(name: string) -> string {
	trimmed := strings.trim_space(name)
	if len(trimmed) == 0 {
		return "preset"
	}
	out: [MAX_PRESET_NAME]u8
	n := 0
	for ch in trimmed {
		if n >= len(out) - 1 {
			break
		}
		if ch == '/' || ch == '\\' || ch == ':' {
			out[n] = '_'
		} else if ch >= 0 && ch <= 127 && preset_name_accepts_char(ch) {
			out[n] = u8(ch)
		} else {
			out[n] = '_'
		}
		n += 1
	}
	if n == 0 {
		return "preset"
	}
	return string(out[:n])
}
