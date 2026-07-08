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
}

Preset_Fieldset_Builtin_Context :: struct {
	kind: Preset_Fieldset_Builtin_Kind,
	gray_scott: ^Gray_Scott_Simulation,
	particle_life: ^Particle_Life_Simulation,
	remaining: ^Remaining_Sim_State,
	remaining_kind: Remaining_Sim_Kind,
}

preset_fieldset_draw :: proc(
	ctx: ^uifw.Gui_Context,
	state: ^Preset_Fieldset_State,
	worker: ^Render_Worker_State,
	simulation_directory: string,
	builtin_names: []string,
	builtin_selected_index: int,
	builtin_context: Preset_Fieldset_Builtin_Context,
) {
	saved_presets := preset_names_for_simulation(worker, simulation_directory)
	defer delete(saved_presets)
	presets := preset_combined_names(builtin_names, saved_presets[:])
	defer delete(presets)

	if !state.initialized {
		state.selected_index = max(min(builtin_selected_index, len(presets) - 1), 0)
		state.initialized = true
	}
	preset_fieldset_select_pending_saved(state, presets[:])

	if len(presets) > 0 {
		state.selected_index = max(min(state.selected_index, len(presets) - 1), 0)
		if uifw.gui_combobox(ctx, "Select preset...", "preset_select", &state.selected_index, presets[:], state.query_buffer[:]) {
			preset_fieldset_apply_selection(state.selected_index, worker, simulation_directory, builtin_names, presets[:], builtin_context)
		}
	} else {
		uifw.gui_label(ctx, "No presets yet")
	}

	if uifw.gui_button(ctx, "Save Current Settings", "save_current_settings") {
		state.save_open = true
		state.save_open_frame = ctx.frame_index
		state.save_name_len = 0
	}
}

preset_fieldset_content_rows :: proc(state: ^Preset_Fieldset_State) -> int {
	return 2
}

preset_names_for_simulation :: proc(worker: ^Render_Worker_State, simulation_directory: string) -> [dynamic]string {
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

preset_fieldset_select_pending_saved :: proc(state: ^Preset_Fieldset_State, names: []string) {
	if !state.select_saved_when_available {
		return
	}
	pending := string(state.select_saved_name[:state.select_saved_name_len])
	for name, i in names {
		if name == pending {
			state.selected_index = i
			state.select_saved_when_available = false
			state.select_saved_name_len = 0
			return
		}
	}
}

preset_fieldset_apply_selection :: proc(
	selected_index: int,
	worker: ^Render_Worker_State,
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
	preset_fieldset_enqueue(worker, .Load_Preset, simulation_directory, preset_names[selected_index])
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
	case:
	}
}

preset_save_dialog_draw :: proc(ctx: ^uifw.Gui_Context, state: ^Preset_Fieldset_State, worker: ^Render_Worker_State, simulation_directory: string) {
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
	dialog_w := min(max(window_w - ctx.style.spacing_2 * 2, 300), 440)
	dialog_h := ctx.style.row_height * 5 + ctx.style.spacing * 6 + ctx.style.panel_padding * 2
	dialog := uifw.Rect{
		x = max((window_w - dialog_w) * 0.5, ctx.style.spacing_2),
		y = max((window_h - dialog_h) * 0.5, ctx.style.spacing_2),
		w = dialog_w,
		h = dialog_h,
	}

	uifw.gui_push_id(ctx, "preset_save_dialog")
	uifw.gui_rect(ctx, overlay, {0, 0, 0, 0.70})
	uifw.gui_overlay_input_begin(ctx, overlay)
	if ctx.frame_index > state.save_open_frame && ctx.input.mouse_released && !uifw.gui_contains(dialog, ctx.input.mouse_pos) {
		preset_save_dialog_close(state)
		uifw.gui_overlay_input_end(ctx)
		uifw.gui_pop_id(ctx)
		return
	}
	if ctx.frame_index > state.save_open_frame && ctx.input.key_escape {
		preset_save_dialog_close(state)
		uifw.gui_overlay_input_end(ctx)
		uifw.gui_pop_id(ctx)
		return
	}

	uifw.gui_panel_begin(ctx, dialog)
	uifw.gui_heading(ctx, "Save Preset")
	uifw.gui_label(ctx, "Preset Name")
	_ = uifw.gui_text_input(ctx, "Enter preset name...", "preset_save_name", state.save_name[:], &state.save_name_len)
	if ctx.input.key_enter && preset_save_dialog_has_name(state) {
		preset_save_dialog_commit(state, worker, simulation_directory)
		uifw.gui_panel_end(ctx)
		uifw.gui_overlay_input_end(ctx)
		uifw.gui_pop_id(ctx)
		return
	}

	button_row := uifw.gui_next_rect(ctx, height = ctx.style.row_height)
	button_gap := ctx.style.spacing
	button_w := max((button_row.w - button_gap) * 0.5, ctx.style.row_height)
	save_rect := uifw.Rect{button_row.x, button_row.y, button_w, button_row.h}
	cancel_rect := uifw.Rect{button_row.x + button_w + button_gap, button_row.y, button_w, button_row.h}
	save_enabled := preset_save_dialog_has_name(state)
	if uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, "preset_save_confirm"), save_rect, "Save", save_enabled) && save_enabled {
		preset_save_dialog_commit(state, worker, simulation_directory)
	}
	if uifw.gui_button_at(ctx, uifw.gui_make_id(ctx, "preset_save_cancel"), cancel_rect, "Cancel", true) {
		preset_save_dialog_close(state)
	}
	uifw.gui_panel_end(ctx)
	uifw.gui_overlay_input_end(ctx)
	uifw.gui_pop_id(ctx)
}

preset_save_dialog_has_name :: proc(state: ^Preset_Fieldset_State) -> bool {
	return len(strings.trim_space(string(state.save_name[:state.save_name_len]))) > 0
}

preset_save_dialog_commit :: proc(state: ^Preset_Fieldset_State, worker: ^Render_Worker_State, simulation_directory: string) {
	name := strings.trim_space(string(state.save_name[:state.save_name_len]))
	preset_fieldset_enqueue(worker, .Save_Preset, simulation_directory, name)
	state.select_saved_when_available = true
	state.select_saved_name_len = min(len(name), len(state.select_saved_name))
	name_bytes := transmute([]u8)name
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

preset_name_accepts_char :: proc(ch: rune) -> bool {
	return (ch >= 'a' && ch <= 'z') ||
		(ch >= 'A' && ch <= 'Z') ||
		(ch >= '0' && ch <= '9') ||
		ch == ' ' || ch == '_' || ch == '-' || ch == '.'
}

preset_fieldset_enqueue :: proc(worker: ^Render_Worker_State, kind: Ui_To_Render_Command_Kind, simulation_directory, preset_name: string) {
	if worker == nil || worker.ui_to_render == nil {
		return
	}
	filename := preset_filename_from_name(preset_name)
	path := fmt.tprintf("%s/%s", simulation_directory, filename)
	cmd: Ui_To_Render_Command
	cmd.kind = kind
	write_fixed_string(cmd.preset_name[:], path)
	_ = engine.queue_try_push(worker.ui_to_render, cmd)
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
