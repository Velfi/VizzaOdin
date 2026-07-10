package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"
import "core:math"

SLIME_CONTROLLER_UI_DECK_MIN_TAB_WIDTH :: f32(132)
SLIME_CONTROLLER_UI_DECK_MAX_TAB_WIDTH :: f32(260)
SLIME_CONTROLLER_UI_DECK_LABEL_SCALE :: f32(0.76)
SLIME_CONTROLLER_UI_KEY_SCALE :: f32(0.62)
SLIME_CONTROLLER_UI_HINT_SCALE :: f32(0.58)
SLIME_CONTROLLER_UI_ICON_INSET_RATIO :: f32(0.04)

Slime_Controller_Ui_State :: struct {
	deck_visible: bool,
	panel_open: bool,
	focused_index: int,
	active_index: int,
	mode: Control_Ui_Mode,
	panel_scroll: f32,
	focus: uifw.Controller_Focus_State,
	pending_panel_focus: bool,
}

slime_controller_ui_init :: proc(state: ^Slime_Controller_Ui_State) {
	state^ = {
		deck_visible = false,
		panel_open = false,
		focused_index = 0,
		active_index = 0,
		mode = .Couch,
	}
	uifw.gui_controller_focus_init(&state.focus)
}

slime_controller_ui_deck_region_id :: proc(gui: ^uifw.Gui_Context) -> uifw.Gui_Id {
	return uifw.gui_make_id(gui, "slime_deck_region")
}

slime_controller_ui_panel_region_id :: proc(gui: ^uifw.Gui_Context, instrument: Control_Instrument) -> uifw.Gui_Id {
	uifw.gui_push_id(gui, "slime_controller_panel")
	uifw.gui_push_id_int(gui, int(instrument))
	region := uifw.gui_make_id(gui, "slime_panel_region")
	uifw.gui_pop_id(gui)
	uifw.gui_pop_id(gui)
	return region
}

slime_controller_ui_enabled :: proc(ui: ^App_Ui_State) -> bool {
	return ui != nil && ui.mode == .Slime_Mold
}

slime_controller_ui_visible_instrument_count :: proc(mode: Control_Ui_Mode) -> int {
	count := 0
	for instrument in SLIME_CONTROL_INSTRUMENTS {
		if slime_control_instrument_has_visible_controls(instrument.instrument, mode) {
			count += 1
		}
	}
	return count
}

slime_controller_ui_instrument_at :: proc(mode: Control_Ui_Mode, visible_index: int) -> (Control_Instrument_Descriptor, bool) {
	index := 0
	for instrument in SLIME_CONTROL_INSTRUMENTS {
		if !slime_control_instrument_has_visible_controls(instrument.instrument, mode) {
			continue
		}
		if index == visible_index {
			return instrument, true
		}
		index += 1
	}
	return {}, false
}

slime_controller_ui_clamp_index :: proc(state: ^Slime_Controller_Ui_State) {
	count := slime_controller_ui_visible_instrument_count(state.mode)
	if count <= 0 {
		state.focused_index = 0
		state.active_index = 0
		return
	}
	state.focused_index = max(min(state.focused_index, count - 1), 0)
	state.active_index = max(min(state.active_index, count - 1), 0)
}

slime_controller_ui_select_index :: proc(state: ^Slime_Controller_Ui_State, index: int) {
	count := slime_controller_ui_visible_instrument_count(state.mode)
	if count <= 0 {
		return
	}
	state.focused_index = (index + count) % count
	if state.active_index != state.focused_index {
		state.panel_scroll = 0
	}
	state.active_index = state.focused_index
	state.panel_open = true
	state.deck_visible = true
}

slime_controller_ui_active_instrument :: proc(state: ^Slime_Controller_Ui_State) -> (Control_Instrument_Descriptor, bool) {
	slime_controller_ui_clamp_index(state)
	return slime_controller_ui_instrument_at(state.mode, state.active_index)
}

slime_controller_ui_text_width_scaled :: proc(gui: ^uifw.Gui_Context, text: string, scale: f32) -> f32 {
	return uifw.gui_font_text_width(.Body, transmute([]u8)text, max(gui.style.text_scale * scale, 0.5), gui.style.char_width)
}

slime_controller_ui_fit_text_scale :: proc(gui: ^uifw.Gui_Context, text: string, target_scale, max_width: f32) -> f32 {
	width := slime_controller_ui_text_width_scaled(gui, text, target_scale)
	if width <= max_width || width <= 0 {
		return target_scale
	}
	return max(target_scale * max_width / width, 0.42)
}

slime_controller_ui_key_badge_size :: proc(gui: ^uifw.Gui_Context) -> f32 {
	return max(gui.style.row_height * 1.35, gui.style.body_line_height * 1.65)
}

slime_controller_ui_icon_index :: proc(instrument: Control_Instrument) -> (int, bool) {
	#partial switch instrument {
	case .Play:
		return 0, true
	case .Look:
		return 1, true
	case .Brush:
		return 2, true
	case .Motion:
		return 3, true
	case .Awareness:
		return 4, true
	case .Field:
		return 5, true
	case .World:
		return 6, true
	case .Birth:
		return 7, true
	case .Capture:
		return 8, true
	case .Presets:
		return 9, true
	case:
	}
	return 0, false
}

slime_controller_ui_icon_uv :: proc(index: int) -> uifw.Rect {
	count := f32(engine.UI_ICONOIR_ICON_COUNT)
	u0 := f32(index) / count
	return {u0, 0, 1 / count, 1}
}

slime_controller_ui_draw_icon_badge :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, instrument: Control_Instrument, fallback: string, selected: bool) {
	if icon_index, ok := slime_controller_ui_icon_index(instrument); ok {
		slime_controller_ui_draw_icon_badge_index(gui, rect, icon_index, selected)
		return
	}
	fill := selected ? uifw.Color{0.48, 0.50, 0.90, 0.88} : uifw.Color{1, 1, 1, 0.12}
	stroke := selected ? gui.style.accent : uifw.Color{1, 1, 1, 0.16}
	uifw.gui_round_rect(gui, rect, 5, fill)
	uifw.gui_round_stroke(gui, rect, 5, stroke, gui.style.border_width)
	key_scale := slime_controller_ui_fit_text_scale(gui, fallback, SLIME_CONTROLLER_UI_KEY_SCALE, max(rect.w - gui.style.spacing_1, 1))
	uifw.gui_text_aligned_scaled(gui, rect, fallback, gui.style.text, .Center, key_scale)
}

slime_controller_ui_draw_icon_badge_index :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, icon_index: int, selected: bool) {
	fill := selected ? uifw.Color{0.48, 0.50, 0.90, 0.88} : uifw.Color{1, 1, 1, 0.12}
	stroke := selected ? gui.style.accent : uifw.Color{1, 1, 1, 0.16}
	uifw.gui_round_rect(gui, rect, 5, fill)
	uifw.gui_round_stroke(gui, rect, 5, stroke, gui.style.border_width)
	icon_margin := max(rect.w * SLIME_CONTROLLER_UI_ICON_INSET_RATIO, gui.style.border_width)
	icon_rect := uifw.gui_inset(rect, icon_margin)
	tint := selected ? uifw.Color{1, 1, 1, 0.98} : uifw.Color{1, 1, 1, 0.72}
	uifw.gui_image_uv_filtered(gui, icon_rect, uifw.Gui_Image_Id(engine.UI_ICONOIR_ATLAS_TEXTURE_ID), tint, slime_controller_ui_icon_uv(icon_index), {brightness = 1, contrast = 1})
}

slime_controller_ui_deck_focused :: proc(state: ^Slime_Controller_Ui_State, gui: ^uifw.Gui_Context) -> bool {
	count := slime_controller_ui_visible_instrument_count(state.mode)
	for i in 0 ..< count {
		if gui.focused == uifw.gui_make_id(gui, fmt.tprintf("slime_deck_%d", i)) {
			return true
		}
	}
	return false
}

slime_controller_ui_focus_deck :: proc(state: ^Slime_Controller_Ui_State, gui: ^uifw.Gui_Context) {
	slime_controller_ui_clamp_index(state)
	state.deck_visible = true
	state.focused_index = state.active_index
	deck_region := slime_controller_ui_deck_region_id(gui)
	fallback := uifw.gui_make_id(gui, fmt.tprintf("slime_deck_%d", state.focused_index))
	gui.focused = uifw.gui_controller_focus_enter_region(&state.focus, deck_region, uifw.GUI_ID_NONE, fallback)
}

slime_controller_ui_deck_rect :: proc(gui: ^uifw.Gui_Context, width, height: f32, mode: Control_Ui_Mode) -> uifw.Rect {
	count := max(slime_controller_ui_visible_instrument_count(mode), 1)
	margin := max(gui.style.spacing_3, f32(18))
	label_scale := max(gui.style.text_scale * SLIME_CONTROLLER_UI_DECK_LABEL_SCALE, 0.5)
	key_w := slime_controller_ui_key_badge_size(gui)
	tab_min := max(SLIME_CONTROLLER_UI_DECK_MIN_TAB_WIDTH, key_w + gui.style.spacing_2 + gui.style.body_char_width * 5.8)
	for i in 0 ..< count {
		instrument, ok := slime_controller_ui_instrument_at(mode, i)
		if ok {
			label_w := uifw.gui_font_text_width(.Body, transmute([]u8)instrument.label, label_scale, gui.style.char_width)
			tab_min = max(tab_min, key_w + gui.style.spacing_2 + label_w + gui.style.spacing_3)
		}
	}
	tab_min = min(tab_min, SLIME_CONTROLLER_UI_DECK_MAX_TAB_WIDTH)
	hint_h := max(gui.style.small_line_height, gui.style.body_line_height * 0.72)
	deck_h := max(
		gui.style.row_height * 3.65,
		key_w + gui.style.body_line_height + hint_h + gui.style.spacing_3 + gui.style.spacing_2,
	)
	target_w := f32(count) * tab_min + f32(count + 1) * gui.style.spacing
	deck_w := min(max(target_w, width * 0.58), max(width - margin * 2, 1))
	return {max((width - deck_w) * 0.5, margin), max(height - deck_h - margin, margin), deck_w, deck_h}
}

slime_controller_ui_panel_rect :: proc(gui: ^uifw.Gui_Context, width, height: f32, deck: uifw.Rect) -> uifw.Rect {
	margin := max(gui.style.spacing_3, f32(18))
	panel_w := min(max(width * 0.58, f32(720)), max(width - margin * 2, 1))
	available_h := max(deck.y - margin * 2, 1)
	panel_h := min(max(height * 0.36, gui.style.row_height * 6.5), available_h)
	return {max((width - panel_w) * 0.5, margin), max(deck.y - panel_h - margin, margin), panel_w, panel_h}
}

slime_controller_ui_over_ui :: proc(state: ^Slime_Controller_Ui_State, gui: ^uifw.Gui_Context, input: Ui_Frame_Input) -> bool {
	if !state.deck_visible && !state.panel_open {
		return false
	}
	width := f32(input.window_width)
	height := f32(input.window_height)
	deck := slime_controller_ui_deck_rect(gui, width, height, state.mode)
	if state.deck_visible && uifw.gui_contains(deck, input.mouse_pos) {
		return true
	}
	if state.panel_open {
		panel := slime_controller_ui_panel_rect(gui, width, height, deck)
		if uifw.gui_contains(panel, input.mouse_pos) {
			return true
		}
	}
	return false
}

slime_controller_ui_modal_open :: proc(ui: ^App_Ui_State) -> bool {
	return ui != nil && (ui.slime_mold.preset_ui.save_open || ui.color_scheme_editor.modal_open)
}

slime_controller_ui_update_input :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State, width, height: f32) -> bool {
	_ = sim
	_ = width
	_ = height
	if !slime_controller_ui_enabled(ui) {
		return false
	}
	state := &ui.slime_controller
	slime_controller_ui_clamp_index(state)
	state.focus.remember_focus = ui.settings.remember_controller_focus
	// Preserve the old externally visible deck/panel state for mouse callers and
	// tests while adopting the shared controller state lazily.
	if state.focus.phase == .Unfocused &&
	   (gui.focused == uifw.GUI_ID_NONE || slime_controller_ui_deck_focused(state, gui)) &&
	   (state.deck_visible || state.panel_open) {
		if state.panel_open {
			if instrument, ok := slime_controller_ui_active_instrument(state); ok {
				panel_region := slime_controller_ui_panel_region_id(gui, instrument.instrument)
				_ = uifw.gui_controller_focus_enter_region(&state.focus, panel_region, slime_controller_ui_deck_region_id(gui), gui.focused)
			}
		} else {
			slime_controller_ui_focus_deck(state, gui)
		}
	}
	pause_consumed := false

	deck_opened_by_focus := false
	if state.focus.phase == .Unfocused && (gui.input.focus_next || gui.input.focus_prev) {
		slime_controller_ui_focus_deck(state, gui)
		deck_opened_by_focus = true
		gui.input.focus_next = false
		gui.input.focus_prev = false
	}

	control_deck_pressed := app_ui_control_deck_pressed(
		ui.frame_actions.control_deck,
		gui.input.key_space || gui.input.key_space_pressed,
	)
	control_deck_active := app_ui_control_deck_active(
		ui.frame_actions.control_deck,
		gui.input.key_space || gui.input.key_space_down || gui.input.key_space_pressed || gui.input.key_space_released,
	)
	if control_deck_pressed {
		app_ui_set_simulation_chrome_visible(ui, true)
		slime_controller_ui_focus_deck(state, gui)
		pause_consumed = true
	}
	if ui.frame_actions.toggle_ui.pressed || gui.input.toggle_ui {
		app_ui_set_simulation_chrome_visible(ui, true)
		slime_controller_ui_focus_deck(state, gui)
		gui.input.toggle_ui = false
		pause_consumed = true
	}
	if control_deck_active {
		pause_consumed = true
	}

	if state.focus.phase != .Unfocused {
		back_owned_by_widget := slime_controller_ui_modal_open(ui) ||
			gui.focus_edit_id != uifw.GUI_ID_NONE ||
			gui.text_edit_id != uifw.GUI_ID_NONE ||
			gui.open_panel != uifw.GUI_ID_NONE
		if gui.input.back && !back_owned_by_widget {
			if state.focus.phase == .Active_Control {
				uifw.gui_controller_focus_deactivate(&state.focus)
			} else if state.focus.phase == .Child_Region {
				state.panel_open = false
				state.pending_panel_focus = false
				uifw.gui_controller_focus_leave_region(&state.focus)
				gui.focused = uifw.gui_make_id(gui, fmt.tprintf("slime_deck_%d", state.focused_index))
			} else {
				state.panel_open = false
				uifw.gui_controller_focus_leave_region(&state.focus)
				gui.focused = uifw.GUI_ID_NONE
			}
			gui.input.back = false
		}
		deck_accepts_input := state.focus.phase == .Region && state.deck_visible && !deck_opened_by_focus && slime_controller_ui_deck_focused(state, gui)
		if deck_accepts_input {
			count := slime_controller_ui_visible_instrument_count(state.mode)
			if count > 0 {
				if gui.input.nav_pressed_x > 0 || gui.input.focus_next {
					state.focused_index = (state.focused_index + 1) % count
					gui.focused = uifw.gui_make_id(gui, fmt.tprintf("slime_deck_%d", state.focused_index))
					gui.input.nav_pressed_x = 0
					gui.input.focus_next = false
				} else if gui.input.nav_pressed_x < 0 || gui.input.focus_prev {
					state.focused_index = (state.focused_index - 1 + count) % count
					gui.focused = uifw.gui_make_id(gui, fmt.tprintf("slime_deck_%d", state.focused_index))
					gui.input.nav_pressed_x = 0
					gui.input.focus_prev = false
				}
				if gui.input.accept {
					slime_controller_ui_select_index(state, state.focused_index)
					if instrument, ok := slime_controller_ui_active_instrument(state); ok {
						panel_region := slime_controller_ui_panel_region_id(gui, instrument.instrument)
						deck_region := slime_controller_ui_deck_region_id(gui)
						_ = uifw.gui_controller_focus_enter_region(&state.focus, panel_region, deck_region, uifw.GUI_ID_NONE)
						state.pending_panel_focus = true
					}
				}
			}
		} else if state.focus.phase == .Child_Region && gui.input.accept && gui.focused != uifw.GUI_ID_NONE {
			uifw.gui_controller_focus_activate(&state.focus, gui.focused)
		}
	}

	return pause_consumed
}

slime_controller_ui_draw :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State, width, height: f32, worker: ^Render_Worker_State) {
	if !slime_controller_ui_enabled(ui) {
		return
	}
	state := &ui.slime_controller
	slime_controller_ui_clamp_index(state)
	modal_open := slime_controller_ui_modal_open(ui)
	modal_input := gui.input
	if modal_open {
		// The top modal owns this frame's interaction. Keep pointer position for
		// passive hover rendering, but do not let the covered panel consume the
		// same Back/Accept/navigation event before the modal is drawn.
		gui.input.mouse_down = false
		gui.input.mouse_pressed = false
		gui.input.mouse_released = false
		gui.input.nav_x = 0
		gui.input.nav_y = 0
		gui.input.nav_pressed_x = 0
		gui.input.nav_pressed_y = 0
		gui.input.accept = false
		gui.input.back = false
		gui.input.focus_next = false
		gui.input.focus_prev = false
		gui.input.primary_down = false
		gui.input.primary_pressed = false
		gui.input.primary_released = false
		gui.input.secondary_down = false
		gui.input.secondary_pressed = false
		gui.input.secondary_released = false
		gui.input.key_tab = false
		gui.input.key_enter = false
		gui.input.key_escape = false
		gui.input.text_input_len = 0
		gui.input.clipboard_paste_len = 0
	}
	if ui.simulation_shell.controls_visible && state.panel_open {
		deck := slime_controller_ui_deck_rect(gui, width, height, state.mode)
		panel := slime_controller_ui_panel_rect(gui, width, height, deck)
		slime_controller_ui_draw_panel(ui, gui, sim, panel, worker)
	}
	if ui.simulation_shell.controls_visible {
		deck := slime_controller_ui_deck_rect(gui, width, height, state.mode)
		slime_controller_ui_draw_deck(state, gui, deck)
	}
	if modal_open {
		gui.input = modal_input
	}
	if state.panel_open {
		instrument, ok := slime_controller_ui_active_instrument(state)
		if ok && instrument.instrument == .Look {
			_ = color_scheme_editor_draw_modal(gui, &ui.color_scheme_editor, &sim.slime.color_scheme)
		}
	}
	preset_save_dialog_draw(gui, &sim.preset_ui, worker, remaining_sim_directory(.Slime_Mold))
}

slime_controller_ui_context_hint :: proc(state: ^Slime_Controller_Ui_State, device: uifw.Input_Device_Kind) -> string {
	controller := device == .Controller
	switch state.focus.phase {
	case .Region:
		if controller {
			return "D-pad / shoulders: browse  |  Accept: open  |  Back: close"
		}
		return "Arrows / Tab: browse  |  Enter: open  |  Esc: close"
	case .Child_Region:
		if controller {
			return "D-pad: navigate  |  Accept: edit  |  Back: sections"
		}
		return "Arrows / Tab: navigate  |  Enter: edit  |  Esc: sections"
	case .Active_Control:
		if controller {
			return "D-pad: adjust  |  Light stick: fine  |  Accept: commit  |  Back: cancel"
		}
		return "Arrows: adjust  |  Shift: fine  |  Enter: commit  |  Esc: cancel"
	case .Unfocused:
		if controller {
			return "Shoulders: focus controls"
		}
		return "Space: focus controls  |  Click: open section"
	}
	return ""
}

slime_controller_ui_draw_deck :: proc(state: ^Slime_Controller_Ui_State, gui: ^uifw.Gui_Context, deck: uifw.Rect) {
	count := slime_controller_ui_visible_instrument_count(state.mode)
	if count <= 0 {
		return
	}
	uifw.gui_spatial_group_begin(gui, "slime_deck_region")
	defer uifw.gui_spatial_group_end(gui)
	uifw.gui_shadow(gui, deck, 8, {0, 6}, 18, {0, 0, 0, 0.36})
	uifw.gui_round_rect(gui, deck, 8, {0.025, 0.035, 0.05, 0.52})
	glass := uifw.gui_default_glass_style(gui, 8)
	glass.tint = {0.06, 0.08, 0.10, 0.68}
	glass.roughness = 0.58
	glass.thickness = max(gui.style.rhythm * 0.20, f32(8))
	glass.bevel = max(gui.style.border_width * 6, f32(6))
	glass.border = 0.32
	uifw.gui_refractive_glass_rect(gui, deck, glass)
	uifw.gui_round_stroke(gui, deck, 8, {1, 1, 1, 0.16}, gui.style.border_width)
	gap := gui.style.spacing
	hint := slime_controller_ui_context_hint(state, gui.input.active_device)
	hint_h := max(gui.style.small_line_height, gui.style.body_line_height * 0.72)
	hint_rect := uifw.Rect{
		deck.x + gap * 1.5,
		deck.y + deck.h - gap - hint_h,
		max(deck.w - gap * 3, 1),
		hint_h,
	}
	tab_w := max((deck.w - gap * f32(count + 1)) / f32(count), 1)
	tab_h := max(hint_rect.y - deck.y - gap * 2, 1)
	for i in 0 ..< count {
		instrument, ok := slime_controller_ui_instrument_at(state.mode, i)
		if !ok {
			continue
		}
		tab := uifw.Rect{deck.x + gap + f32(i) * (tab_w + gap), deck.y + gap, tab_w, tab_h}
		id := uifw.gui_make_id(gui, fmt.tprintf("slime_deck_%d", i))
		control := uifw.gui_control(gui, id, tab, true)
		if control.focused {
			state.focused_index = i
		}
		if control.activated || (control.hovered && gui.active == id && gui.input.mouse_released) {
			slime_controller_ui_select_index(state, i)
			// Pointer and keyboard selection of a deck tab transfers ownership
			// back to the deck region. The next controller Accept can then enter
			// the newly selected panel instead of treating the tab as a child edit.
			slime_controller_ui_focus_deck(state, gui)
		} else if control.hovered {
			state.focused_index = i
		}
		selected := i == state.active_index && state.panel_open
		deck_focused := state.focus.phase == .Region && (control.focused || i == state.focused_index)
		fill := selected ? uifw.Color{0.28, 0.30, 0.62, 0.78} : uifw.Color{1, 1, 1, 0.08}
		if control.hovered || deck_focused {
			fill = selected ? uifw.Color{0.34, 0.36, 0.72, 0.86} : uifw.Color{1, 1, 1, 0.16}
		}
		uifw.gui_round_rect(gui, tab, 6, fill)
		uifw.gui_round_stroke(gui, tab, 6, selected ? uifw.gui_apply_opacity(gui.style.accent, 0.62) : uifw.Color{1, 1, 1, 0.12}, selected ? max(gui.style.border_width * 1.5, 1.5) : gui.style.border_width)
		if deck_focused {
			uifw.gui_focus_ring(gui, tab)
		}
		content_pad := max(gui.style.spacing_1, gui.style.border_width * 2)
		content := uifw.gui_inset(tab, content_pad)
		label_h := min(gui.style.body_line_height, max(content.h * 0.34, gui.style.small_line_height))
		badge_limit := max(content.h - label_h - gui.style.spacing_1, 1)
		badge_size := min(min(slime_controller_ui_key_badge_size(gui), badge_limit), max(content.w, 1))
		badge_x := content.x + max((content.w - badge_size) * 0.5, 0)
		badge := uifw.Rect{badge_x, content.y, badge_size, badge_size}
		label_y := badge.y + badge.h + gui.style.spacing_1
		label_rect := uifw.Rect{content.x, label_y, content.w, max(content.y + content.h - label_y, 1)}
		label_scale := slime_controller_ui_fit_text_scale(gui, instrument.label, SLIME_CONTROLLER_UI_DECK_LABEL_SCALE, label_rect.w)
		uifw.gui_scissor_begin(gui, tab)
		slime_controller_ui_draw_icon_badge(gui, badge, instrument.instrument, instrument.icon, selected || deck_focused)
		uifw.gui_text_aligned_scaled(gui, label_rect, instrument.label, gui.style.text, .Center, label_scale)
		uifw.gui_scissor_end(gui)
	}
	hint_scale := slime_controller_ui_fit_text_scale(gui, hint, SLIME_CONTROLLER_UI_HINT_SCALE, hint_rect.w)
	uifw.gui_text_aligned_scaled(gui, hint_rect, hint, gui.style.text_muted, .Center, hint_scale)
}

slime_controller_ui_panel_content_height :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State, instrument: Control_Instrument, mode: Control_Ui_Mode) -> f32 {
	row := gui.style.row_height
	slider := uifw.gui_slider_height(gui)
	gap := gui.style.spacing
	row_count := f32(1)
	slider_count := f32(0)
	extra := f32(0)
	settings := &sim.slime

	#partial switch instrument {
	case .Look:
		row_count = 3
		if mode != .Couch && settings.post_processing.blur_enabled {
			slider_count = 2
		}
	case .Brush:
		row_count = 1
		extra = shared_two_axis_pad_height(gui)
	case .Motion:
		slider_count = 1
		row_count = 1
		extra = shared_two_axis_pad_height(gui) + max(row * 3.8, f32(172)) + 8
	case .Field:
		slider_count = 1
		row_count = 1
		extra = shared_two_axis_pad_height(gui)
	case .World:
		row_count = 10
		extra = shared_two_axis_pad_height(gui)
		if settings.position_generator == 7 {
			row_count += 5
		}
		if settings.mask_pattern == .Image {
			row_count += 5
		}
	case .Presets:
		row_count = f32(preset_fieldset_content_rows(&sim.preset_ui) + 3 + (sim.slime_randomize_undo_available ? 1 : 0))
	case:
		row_count = 1
	}

	items := row_count + slider_count
	return row_count * row + slider_count * slider + max(items - 1, 0) * gap + extra
}

slime_controller_ui_draw_panel :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State, panel: uifw.Rect, worker: ^Render_Worker_State) {
	instrument, ok := slime_controller_ui_active_instrument(&ui.slime_controller)
	if !ok {
		return
	}
	state := &ui.slime_controller
	first_item := gui.spatial_item_count
	previous_explicit_activation := gui.controller_explicit_activation
	gui.controller_explicit_activation = state.focus.phase == .Child_Region || state.focus.phase == .Active_Control
	defer gui.controller_explicit_activation = previous_explicit_activation
	uifw.gui_push_id(gui, "slime_controller_panel")
	defer uifw.gui_pop_id(gui)
	uifw.gui_push_id_int(gui, int(instrument.instrument))
	defer uifw.gui_pop_id(gui)
	panel_region := uifw.gui_make_id(gui, "slime_panel_region")
	uifw.gui_spatial_group_begin(gui, "slime_panel_region")
	defer uifw.gui_spatial_group_end(gui)
	uifw.gui_shadow(gui, panel, 8, {0, 7}, 20, {0, 0, 0, 0.42})
	uifw.gui_panel_begin(gui, panel)
	uifw.gui_heading(gui, instrument.label)
	viewport_h := max(panel.h - gui.style.panel_padding * 2 - gui.style.heading_line_height - gui.style.spacing, gui.style.row_height)
	viewport := uifw.gui_next_rect(gui, height = viewport_h)
	content_h := slime_controller_ui_panel_content_height(gui, sim, instrument.instrument, ui.slime_controller.mode)
	uifw.gui_scroll_begin(gui, viewport, content_h, &ui.slime_controller.panel_scroll)
	#partial switch instrument.instrument {
	case .Look:
		slime_controller_ui_draw_look(ui, gui, sim)
	case .Brush:
		slime_controller_ui_draw_brush(gui, sim)
	case .Motion:
		slime_controller_ui_draw_motion(gui, sim)
		uifw.gui_spacer(gui, 8)
		uifw.gui_label(gui, "Awareness")
		slime_controller_ui_draw_awareness(gui, sim)
	case .Field:
		slime_controller_ui_draw_field(gui, sim)
	case .World:
		uifw.gui_label(gui, "Spawn")
		slime_controller_ui_draw_birth(gui, sim, worker)
		uifw.gui_spacer(gui, 8)
		uifw.gui_label(gui, "Mask")
		slime_controller_ui_draw_world(gui, sim, worker)
	case .Presets:
		slime_controller_ui_draw_presets(gui, sim, worker)
		uifw.gui_spacer(gui, 8)
		uifw.gui_label(gui, "Start Over")
		slime_controller_ui_draw_start_over(gui, sim)
	case:
		uifw.gui_label(gui, "No couch controls for this instrument.")
	}
	uifw.gui_scroll_end(gui)
	uifw.gui_panel_end(gui)

	if state.pending_panel_focus {
		fallback := uifw.GUI_ID_NONE
		for i in first_item ..< gui.spatial_item_count {
			item := gui.spatial_items[i]
			if item.focusable && item.group == panel_region {
				if fallback == uifw.GUI_ID_NONE {
					fallback = item.id
				}
				if item.id == uifw.gui_controller_focus_restore(&state.focus, panel_region, fallback) {
					fallback = item.id
					break
				}
			}
		}
		if fallback != uifw.GUI_ID_NONE {
			gui.focused = fallback
			gui.focus_moved = true
		}
		state.pending_panel_focus = false
	}
	if state.focus.phase == .Active_Control &&
		gui.focus_edit_id == uifw.GUI_ID_NONE &&
		gui.text_edit_id == uifw.GUI_ID_NONE &&
		gui.open_panel == uifw.GUI_ID_NONE &&
		gui.controller_armed_id == uifw.GUI_ID_NONE {
		uifw.gui_controller_focus_deactivate(&state.focus)
	}
}

// Spatial/Tab focus resolves in gui_end_frame, after the immediate-mode panel
// has drawn. Commit memory afterward so the newly moved item—not the previous
// frame's item—is restored when the user returns to this instrument.
slime_controller_ui_end_frame :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	if !slime_controller_ui_enabled(ui) || gui == nil {
		return
	}
	state := &ui.slime_controller
	if state.focus.phase != .Child_Region && state.focus.phase != .Active_Control {
		return
	}
	instrument, ok := slime_controller_ui_active_instrument(state)
	if !ok {return}
	panel_region := slime_controller_ui_panel_region_id(gui, instrument.instrument)
	for i in 0 ..< gui.spatial_item_count {
		item := gui.spatial_items[i]
		if item.id == gui.focused && item.focusable && item.group == panel_region {
			uifw.gui_controller_focus_remember(&state.focus, panel_region, item.id)
			return
		}
	}
}

slime_controller_ui_float_slider :: proc(gui: ^uifw.Gui_Context, desc: Control_Descriptor, value: ^f32) -> bool {
	label := fmt.tprintf("%s: %.2f", desc.label, value^)
	changed := uifw.gui_slider_f32(gui, label, desc.stable_id, value, desc.range.min, desc.range.max)
	shared_control_explanation(gui, desc.stable_id, desc.description)
	return changed
}

slime_controller_ui_button :: proc(gui: ^uifw.Gui_Context, desc: Control_Descriptor, label_override: string = "") -> bool {
	label := desc.label
	if len(label_override) > 0 {
		label = label_override
	}
	clicked := uifw.gui_button(gui, label, desc.stable_id)
	shared_control_explanation(gui, desc.stable_id, desc.description)
	return clicked
}

slime_controller_ui_draw_presets :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State, worker: ^Render_Worker_State) {
	builtin_names := remaining_sim_builtin_preset_names(.Slime_Mold)
	directory := remaining_sim_directory(.Slime_Mold)
	preset_fieldset_draw(
		gui,
		&sim.preset_ui,
		worker,
		directory,
		builtin_names,
		sim.builtin_preset_index,
		Preset_Fieldset_Builtin_Context {kind = .Remaining, remaining = sim, remaining_kind = .Slime_Mold},
	)
}

slime_controller_ui_draw_start_over :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	if desc, ok := slime_control_descriptor_by_id(.Playback_Reset); ok {
		if slime_controller_ui_button(gui, desc, "Respawn Agents") {
			slime_request_reset(sim)
			uifw.gui_notice(gui, "Agents respawned. Your behavior settings stayed unchanged.")
		}
	}
	if desc, ok := slime_control_descriptor_by_id(.Playback_Randomize); ok {
		if slime_controller_ui_button(gui, desc, "Randomize Behavior") {
			slime_randomize_settings(sim)
			uifw.gui_notice(gui, "Behavior randomized. Restore Previous Behavior is available here.")
		}
	}
	if sim.slime_randomize_undo_available && uifw.gui_button(gui, "Restore Previous Behavior", "slime_undo_randomize") {
		if slime_undo_randomize_settings(sim) {
			uifw.gui_notice(gui, "Previous Slime behavior restored.")
		}
	}
}

slime_controller_ui_draw_play :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	_ = ui
	if desc, ok := slime_control_descriptor_by_id(.Playback_Paused); ok {
		if uifw.gui_button(gui, sim.paused ? "Resume" : "Pause", desc.stable_id) {
			sim.paused = !sim.paused
		}
	}
	if desc, ok := slime_control_descriptor_by_id(.Playback_Reset); ok {
		if slime_controller_ui_button(gui, desc) {
			slime_request_reset(sim)
			uifw.gui_notice(gui, "Agents respawned. Your behavior settings stayed unchanged.")
		}
	}
	if desc, ok := slime_control_descriptor_by_id(.Playback_Clear_Accumulation); ok {
		if slime_controller_ui_button(gui, desc) {
			slime_request_clear_trails(sim)
		}
	}
	if desc, ok := slime_control_descriptor_by_id(.Playback_Randomize); ok {
		if slime_controller_ui_button(gui, desc) {
			slime_randomize_settings(sim)
			uifw.gui_notice(gui, "Behavior randomized. Restore Previous Behavior is available here.")
		}
	}
	if sim.slime_randomize_undo_available && uifw.gui_button(gui, "Restore Previous Behavior", "slime_play_undo_randomize") {
		if slime_undo_randomize_settings(sim) {
			uifw.gui_notice(gui, "Previous Slime behavior restored.")
		}
	}
}

slime_controller_ui_draw_look :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	settings := &sim.slime
	_ = color_scheme_editor_draw_selector(gui, &ui.color_scheme_editor, "slime_controller_palette", &settings.color_scheme, &settings.color_scheme_reversed)
	if desc, ok := slime_control_descriptor_by_id(.Render_Background_Mode); ok {
		if uifw.gui_selector(gui, fmt.tprintf("%s: %s", desc.label, SLIME_BACKGROUND_MODE_NAMES[settings.background_index]), desc.stable_id, &settings.background_index, SLIME_BACKGROUND_MODE_NAMES[:]) {
			settings.background_mode = Slime_Background_Mode(settings.background_index)
		}
		shared_control_explanation(gui, desc.stable_id, desc.description)
	}
	if desc, ok := slime_control_descriptor_by_id(.Post_Blur_Enabled); ok {
		_ = uifw.gui_toggle(gui, settings.post_processing.blur_enabled ? "Blur: On" : "Blur: Off", desc.stable_id, &settings.post_processing.blur_enabled)
		shared_control_explanation(gui, desc.stable_id, desc.description)
	}
	if ui.slime_controller.mode != .Couch && settings.post_processing.blur_enabled {
		if desc, ok := slime_control_descriptor_by_id(.Post_Blur_Radius); ok {
			_ = slime_controller_ui_float_slider(gui, desc, &settings.post_processing.blur_radius)
		}
		if desc, ok := slime_control_descriptor_by_id(.Post_Blur_Sigma); ok {
			_ = slime_controller_ui_float_slider(gui, desc, &settings.post_processing.blur_sigma)
		}
	}
}

slime_controller_ui_draw_brush :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	_ = shared_two_axis_pad_f32(gui, "Brush Shape", "slime_brush_shape", "Radius", "Strength", &sim.cursor_size, &sim.cursor_strength, 0.01, 1, 0, 50)
	hint := gui.input.active_device == .Controller ? "Primary: attract   Secondary: repel" : "Left click: attract   Right click: repel"
	uifw.gui_label(gui, hint)
}

slime_controller_ui_draw_motion :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	settings := &sim.slime
	_ = shared_range_slider_f32(gui, "Speed Range", "slime_speed_range", &settings.agent_speed_min, &settings.agent_speed_max, 0, 500)
	shared_range_explanation(gui, "slime_speed_range", "Speed Range gives agents different movement speeds, from the slowest to the fastest.")
	turn_degrees := settings.agent_turn_rate * 180 / math.PI
	if shared_two_axis_pad_f32(gui, "Steering", "slime_steering", "Turn °/s", "Jitter", &turn_degrees, &settings.agent_jitter, 0, 360, 0, 5) {
		settings.agent_turn_rate = turn_degrees * math.PI / 180
	}
	shared_control_explanation(gui, "slime_steering", "Turn Rate is how sharply agents steer; Jitter adds randomness so paths feel less uniform.")
}

slime_controller_ui_draw_awareness :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	settings := &sim.slime
	_ = slime_controller_ui_draw_sensor_cone(gui, &settings.agent_sensor_angle, &settings.agent_sensor_distance)
}

slime_controller_ui_draw_sensor_cone :: proc(gui: ^uifw.Gui_Context, angle, distance: ^f32) -> bool {
	bounds := uifw.gui_next_rect(gui, height = max(gui.style.row_height * 3.8, f32(172)))
	id := uifw.gui_make_id(gui, "slime_sensor_cone")
	center := uifw.Vec2{bounds.x + bounds.w * 0.5, bounds.y + bounds.h * 0.66}
	r := min(bounds.h * 0.48, max(bounds.w * 0.18, 1))
	current := uifw.Vec2{angle^, distance^}
	dist_t := min(max(current.y / 500.0, 0), 1)
	cone_r := r * (0.35 + dist_t * 0.65)
	left := -math.PI * 0.5 - current.x
	right := -math.PI * 0.5 + current.x
	p0 := uifw.Vec2{center.x + math.cos(left) * cone_r, center.y + math.sin(left) * cone_r}
	p1 := uifw.Vec2{center.x + math.cos(right) * cone_r, center.y + math.sin(right) * cone_r}
	forward := uifw.Vec2{center.x, center.y - cone_r}
	changed := false
	if uifw.gui_drag_handle_region(gui, id, bounds, p1, 14) {
		fine := uifw.gui_pointer_fine_adjust_scale(gui, id)
		if fine < 1 {
			current.x = min(max(current.x + gui.mouse_delta.x / max(r, 1) * math.PI * fine, 0), math.PI)
			current.y = min(max(current.y - gui.mouse_delta.y / max(r, 1) * 500 * fine, 0), 500)
		} else {
			dx := gui.input.mouse_pos.x - center.x
			dy := gui.input.mouse_pos.y - center.y
			distance_from_center := math.sqrt(dx * dx + dy * dy)
			current.x = min(max(math.abs(math.atan2(dx, -dy)), 0), math.PI)
			current.y = min(max(((distance_from_center / max(r, 1)) - 0.35) / 0.65 * 500, 0), 500)
		}
		changed = true
	}
	_ = uifw.gui_update_focus_edit(gui, id, gui.focused == id)
	uifw.gui_controller_edit_vec2(gui, id, &current)
	nav_x, nav_y := uifw.gui_focused_nav_pressed(gui, id)
	if nav_x != 0 || nav_y != 0 {
		adjust_scale := uifw.gui_fine_adjust_scale(gui)
		current.x = min(max(current.x + nav_x * math.PI * 0.025 * adjust_scale, 0), math.PI)
		current.y = min(max(current.y - nav_y * 12.5 * adjust_scale, 0), 500)
		changed = true
	}
	if current.x != angle^ || current.y != distance^ {
		angle^ = current.x
		distance^ = current.y
		changed = true
	}
	dist_t = min(max(distance^ / 500.0, 0), 1)
	cone_r = r * (0.35 + dist_t * 0.65)
	left = -math.PI * 0.5 - angle^
	right = -math.PI * 0.5 + angle^
	p0 = {center.x + math.cos(left) * cone_r, center.y + math.sin(left) * cone_r}
	p1 = {center.x + math.cos(right) * cone_r, center.y + math.sin(right) * cone_r}
	forward = {center.x, center.y - cone_r}
	uifw.gui_round_rect(gui, bounds, 6, {1, 1, 1, 0.05})
	uifw.gui_quad(gui, center, p0, forward, p1, {0.392, 0.424, 1.0, 0.26})
	uifw.gui_line(gui, center, p0, gui.style.accent, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, center, p1, gui.style.accent, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, center, forward, {1, 1, 1, 0.72}, max(gui.style.border_width, 1))
	center_radius := max(gui.style.row_height * 0.07, f32(5))
	handle_radius := max(gui.style.row_height * 0.14, f32(9))
	uifw.gui_ellipse(gui, {center.x - center_radius, center.y - center_radius, center_radius * 2, center_radius * 2}, gui.style.text)
	uifw.gui_ellipse(gui, {p1.x - handle_radius, p1.y - handle_radius, handle_radius * 2, handle_radius * 2}, gui.style.accent)
	uifw.gui_focus_or_edit_ring(gui, id, bounds)
	uifw.gui_text(gui, {bounds.x + gui.style.spacing_2, bounds.y + gui.style.spacing_1}, "Drag the cone edge to set reach and angle", gui.style.text_muted)
	angle_degrees := angle^ * 180 / math.PI
	uifw.gui_text(gui, {bounds.x + gui.style.spacing_2, bounds.y + bounds.h - gui.style.body_line_height - gui.style.spacing_1}, fmt.tprintf("Angle %.0f°    Distance %.0f", angle_degrees, distance^), gui.style.text)
	shared_control_explanation(gui, "slime_sensor_cone", "Sensor Angle and Distance set how wide and how far ahead each agent can sense trails.")
	return changed
}

slime_controller_ui_draw_field :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	settings := &sim.slime
	if desc, ok := slime_control_descriptor_by_id(.Field_Deposit); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &settings.pheromone_deposition_rate)
	}
	_ = shared_two_axis_pad_f32(gui, "Trail Character", "slime_trail_character", "Fade", "Spread", &settings.pheromone_decay_rate, &settings.pheromone_diffusion_rate, 0, 200, 0, 200)
	shared_control_explanation(gui, "slime_trail_character", "Pheromone Fade controls how quickly trails vanish; Spread controls how far they diffuse.")
	if desc, ok := slime_control_descriptor_by_id(.Playback_Clear_Accumulation); ok {
		if slime_controller_ui_button(gui, desc) {
			slime_request_clear_trails(sim)
		}
	}
}

slime_controller_ui_draw_birth :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State, worker: ^Render_Worker_State) {
	settings := &sim.slime
	if desc, ok := slime_control_descriptor_by_id(.Initialization_Position_Distribution); ok {
		if uifw.gui_selector(gui, fmt.tprintf("%s: %s", desc.label, SLIME_POSITION_GENERATOR_NAMES[settings.position_generator_index]), desc.stable_id, &settings.position_generator_index, SLIME_POSITION_GENERATOR_NAMES[:]) {
			settings.position_generator = u32(settings.position_generator_index)
			slime_request_reset(sim)
		}
		shared_control_explanation(gui, desc.stable_id, desc.description)
	}
	if desc, ok := slime_control_descriptor_by_id(.Initialization_Seed); ok {
		seed := f32(settings.random_seed)
		if uifw.gui_number_drag_f32(gui, fmt.tprintf("%s: %d", desc.label, settings.random_seed), desc.stable_id, &seed, 1, 0, 4294967295) {
			settings.random_seed = u32(seed)
			slime_request_reset(sim)
		}
	}
	if desc, ok := slime_control_descriptor_by_id(.Playback_Randomize); ok {
		if slime_controller_ui_button(gui, desc, "Randomize Seed") {
			slime_randomize_seed(sim)
		}
	}
	if settings.position_generator == 7 {
		position_options := shared_default_image_selector_options()
		position_options.fit_label = "Position Image Fit"
		position_options.fit_key = "slime_controller_position_image_fit"
		position_options.load_label = "Reload Selected"
		position_options.load_key = "slime_controller_position_load_png"
		position_options.browse_label = "Choose Image..."
		position_options.browse_key = "slime_controller_position_browse_png"
		position_options.clear_label = "Clear Position Image"
		position_options.clear_key = "slime_controller_position_clear_image"
		position_options.selected_label = "Selected Position Image"
		position_options.empty_label = fmt.tprintf("No position image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
		position_options.selected_path = fixed_string(settings.position_image_path[:])
		position_result := shared_image_selector(gui, &settings.position_image_fit_index, VECTOR_IMAGE_FIT_MODE_NAMES[:], position_options)
		reload_position_image := false
		if position_result.fit_changed {
			settings.position_image_fit_mode = Vector_Image_Fit_Mode(settings.position_image_fit_index)
			reload_position_image = true
		}
		if position_result.browse_requested {
			sim.slime_position_image_dialog_requested = true
		}
		if position_result.load_requested || reload_position_image {
			remaining_sim_enqueue_image_command(worker, .Load_Slime_Position_Image, fixed_string(settings.position_image_path[:]))
			slime_request_reset(sim)
		}
		if position_result.clear_requested {
			remaining_sim_enqueue_image_command(worker, .Clear_Slime_Position_Image)
			slime_request_reset(sim)
		}
	}
}

slime_controller_ui_draw_world :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State, worker: ^Render_Worker_State) {
	settings := &sim.slime
	if desc, ok := slime_control_descriptor_by_id(.Mask_Source); ok {
		if uifw.gui_selector(gui, fmt.tprintf("%s: %s", desc.label, SLIME_MASK_PATTERN_NAMES[settings.mask_pattern_index]), desc.stable_id, &settings.mask_pattern_index, SLIME_MASK_PATTERN_NAMES[:]) {
			settings.mask_pattern = Slime_Mask_Pattern(settings.mask_pattern_index)
		}
		shared_control_explanation(gui, desc.stable_id, desc.description)
	}
	if desc, ok := slime_control_descriptor_by_id(.Mask_Target); ok {
		if uifw.gui_selector(gui, fmt.tprintf("%s: %s", desc.label, SLIME_MASK_TARGET_NAMES[settings.mask_target_index]), desc.stable_id, &settings.mask_target_index, SLIME_MASK_TARGET_NAMES[:]) {
			settings.mask_target = Slime_Mask_Target(settings.mask_target_index)
		}
		shared_control_explanation(gui, desc.stable_id, desc.description)
	}
	_ = shared_two_axis_pad_f32(gui, "Mask Response", "slime_mask_response", "Strength", "Curve", &settings.mask_strength, &settings.mask_curve, 0, 1, 0.1, 4)
	if settings.mask_pattern == .Image {
		mask_options := shared_default_image_selector_options()
		mask_options.fit_label = "Mask Image Fit"
		mask_options.fit_key = "slime_controller_mask_image_fit"
		mask_options.load_label = "Reload Selected"
		mask_options.load_key = "slime_controller_mask_load_png"
		mask_options.browse_label = "Choose Image..."
		mask_options.browse_key = "slime_controller_mask_browse_png"
		mask_options.clear_label = "Clear Mask Image"
		mask_options.clear_key = "slime_controller_mask_clear_image"
		mask_options.selected_label = "Selected Mask Image"
		mask_options.empty_label = fmt.tprintf("No mask image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
		mask_options.selected_path = fixed_string(settings.mask_image_path[:])
		mask_result := shared_image_selector(gui, &settings.mask_image_fit_index, VECTOR_IMAGE_FIT_MODE_NAMES[:], mask_options)
		reload_mask_image := false
		if mask_result.fit_changed {
			settings.mask_image_fit_mode = Vector_Image_Fit_Mode(settings.mask_image_fit_index)
			reload_mask_image = true
		}
		if mask_result.browse_requested {
			sim.slime_mask_image_dialog_requested = true
		}
		if mask_result.load_requested || reload_mask_image {
			remaining_sim_enqueue_image_command(worker, .Load_Slime_Mask_Image, fixed_string(settings.mask_image_path[:]))
		}
		if mask_result.clear_requested {
			remaining_sim_enqueue_image_command(worker, .Clear_Slime_Mask_Image)
		}
	}
	if desc, ok := slime_control_descriptor_by_id(.Mask_Mirror_X); ok {
		_ = uifw.gui_toggle(gui, settings.mask_mirror_horizontal ? "Mirror X: On" : "Mirror X: Off", desc.stable_id, &settings.mask_mirror_horizontal)
	}
	if desc, ok := slime_control_descriptor_by_id(.Mask_Mirror_Y); ok {
		_ = uifw.gui_toggle(gui, settings.mask_mirror_vertical ? "Mirror Y: On" : "Mirror Y: Off", desc.stable_id, &settings.mask_mirror_vertical)
	}
	if desc, ok := slime_control_descriptor_by_id(.Mask_Invert); ok {
		_ = uifw.gui_toggle(gui, settings.mask_invert_tone ? "Invert: On" : "Invert: Off", desc.stable_id, &settings.mask_invert_tone)
	}
}

slime_controller_ui_draw_capture :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, worker: ^Render_Worker_State) {
	if desc, ok := slime_control_descriptor_by_id(.Capture_Record); ok {
		if slime_controller_ui_button(gui, desc, app_ui_video_recording_button_label(ui)) {
			app_ui_video_recording_toggle(ui, worker)
		}
	}
}
