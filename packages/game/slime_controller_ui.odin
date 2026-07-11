package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"
import "core:math"

SLIME_CONTROLLER_UI_DECK_MIN_TAB_WIDTH :: f32(132)
SLIME_CONTROLLER_UI_DECK_MAX_TAB_WIDTH :: f32(260)
SLIME_CONTROLLER_UI_DECK_LABEL_SCALE :: f32(0.86)
SLIME_CONTROLLER_UI_KEY_SCALE :: f32(0.72)
SLIME_CONTROLLER_UI_HINT_SCALE :: f32(0.68)
SLIME_CONTROLLER_UI_ICON_INSET_RATIO :: f32(0.04)
SLIME_CONTROLLER_UI_AWARENESS_HEIGHT :: f32(116)
SLIME_CONTROLLER_UI_BEHAVIOR_HEIGHT :: f32(328)

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

slime_controller_ui_icon :: proc(instrument: Control_Instrument) -> (uifw.Ui_Controller_Icon, bool) {
	#partial switch instrument {
	case .Play:
		return .Player_Play, true
	case .Look:
		return .Palette, true
	case .Brush:
		return .Brush, true
	case .Motion:
		return .Motion, true
	case .Awareness:
		return .Awareness, true
	case .Field:
		return .Trails, true
	case .World:
		return .World, true
	case .Birth:
		return .Birth, true
	case .Capture:
		return .Capture, true
	case .Presets:
		return .Presets, true
	case:
	}
	return .Player_Play, false
}

slime_controller_ui_icon_uv :: proc(icon: uifw.Ui_Controller_Icon) -> uifw.Rect {
	count := f32(uifw.UI_CONTROLLER_ICON_COUNT)
	u0 := f32(int(icon)) / count
	return {u0, 0, 1 / count, 1}
}

slime_controller_ui_draw_icon_badge :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, instrument: Control_Instrument, fallback: string, selected: bool) {
	if icon, ok := slime_controller_ui_icon(instrument); ok {
		slime_controller_ui_draw_atlas_icon_badge(gui, rect, icon, selected)
		return
	}
	fill := selected ? uifw.Color{0.48, 0.50, 0.90, 0.88} : uifw.Color{1, 1, 1, 0.12}
	stroke := selected ? gui.style.accent : uifw.Color{1, 1, 1, 0.16}
	uifw.gui_round_rect(gui, rect, 5, fill)
	uifw.gui_round_stroke(gui, rect, 5, stroke, gui.style.border_width)
	key_scale := slime_controller_ui_fit_text_scale(gui, fallback, SLIME_CONTROLLER_UI_KEY_SCALE, max(rect.w - gui.style.spacing_1, 1))
	uifw.gui_text_aligned_scaled(gui, rect, fallback, gui.style.text, .Center, key_scale)
}

slime_controller_ui_draw_atlas_icon_badge :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, icon: uifw.Ui_Controller_Icon, selected: bool) {
	fill := selected ? uifw.Color{0.48, 0.50, 0.90, 0.88} : uifw.Color{1, 1, 1, 0.12}
	stroke := selected ? gui.style.accent : uifw.Color{1, 1, 1, 0.16}
	uifw.gui_round_rect(gui, rect, 5, fill)
	uifw.gui_round_stroke(gui, rect, 5, stroke, gui.style.border_width)
	icon_margin := max(rect.w * SLIME_CONTROLLER_UI_ICON_INSET_RATIO, gui.style.border_width)
	icon_rect := uifw.gui_inset(rect, icon_margin)
	tint := selected ? uifw.Color{1, 1, 1, 0.98} : uifw.Color{1, 1, 1, 0.72}
	uifw.gui_image_uv_filtered(gui, icon_rect, uifw.Gui_Image_Id(uifw.UI_CONTROLLER_ICON_ATLAS_TEXTURE_ID), tint, slime_controller_ui_icon_uv(icon), {brightness = 1, contrast = 1})
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
	header_h := app_ui_simulation_bar_height(gui)
	tab_h := max(gui.style.row_height * 1.28, key_w * 0.72)
	deck_h := header_h + tab_h + hint_h + gui.style.spacing_1 * 3
	target_w := f32(count) * tab_min + f32(count + 1) * gui.style.spacing
	deck_w := min(max(target_w, width * 0.58), max(width - margin * 2, 1))
	return {max((width - deck_w) * 0.5, margin), max(height - deck_h - margin, margin), deck_w, deck_h}
}

slime_controller_ui_panel_rect :: proc(gui: ^uifw.Gui_Context, width, height: f32, deck: uifw.Rect) -> uifw.Rect {
	margin := max(gui.style.spacing_3, f32(18))
	panel_w := app_ui_simulation_control_panel_width(gui, width, 720)
	available_h := max(deck.y - margin * 2, 1)
	height_fraction := app_ui_simulation_control_panel_height_fraction(width, 0.36, 0.40)
	panel_h := min(max(height * height_fraction, gui.style.row_height * 6.5), available_h)
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
			// Let the Accept press flow through so the widget can enter edit mode
			// and set focus_edit_id, preventing an immediate deactivation revert.
			// Do not clear accept here: gui_accept_pressed already edge-detects the
			// press (accept && !previous.accept), so a held button cannot commit on
			// the next frame. Clearing it only breaks the begin-edit path.
		}
	}

	return pause_consumed
}

slime_controller_ui_draw :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State, width, height: f32, worker: ^Product_Context) {
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
		slime_controller_ui_draw_deck(state, gui, deck, &ui.settings)
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
			return "D-pad: adjust  |  Light stick: fine  |  Secondary: step  |  Accept: commit  |  Back: cancel"
		}
		return "Arrows: adjust  |  Shift: fine  |  Ctrl: broad  |  Enter: commit  |  Esc: cancel"
	case .Unfocused:
		if controller {
			return "Shoulders: focus controls"
		}
		return "Space: focus controls  |  Click: open section"
	}
	return ""
}

slime_controller_ui_draw_deck :: proc(state: ^Slime_Controller_Ui_State, gui: ^uifw.Gui_Context, deck: uifw.Rect, settings: ^App_Settings = nil) {
	count := slime_controller_ui_visible_instrument_count(state.mode)
	if count <= 0 {
		return
	}
	uifw.gui_spatial_group_begin(gui, "slime_deck_region")
	defer uifw.gui_spatial_group_end(gui)
	gap := gui.style.spacing_1
	hint := slime_controller_ui_context_hint(state, gui.input.active_device)
	hint_h := max(gui.style.small_line_height, gui.style.body_line_height * 0.72)
	hint_rect := uifw.Rect{
		deck.x + gap * 1.5,
		deck.y + deck.h - gap - hint_h,
		max(deck.w - gap * 3, 1),
		hint_h,
	}
	tabs_y := deck.y + app_ui_simulation_bar_height(gui) + gap
	tab_w := max((deck.w - gap * f32(count + 1)) / f32(count), 1)
	tab_h := max(hint_rect.y - tabs_y - gap, 1)
	for i in 0 ..< count {
		instrument, ok := slime_controller_ui_instrument_at(state.mode, i)
		if !ok {
			continue
		}
		tab := uifw.Rect{deck.x + gap + f32(i) * (tab_w + gap), tabs_y, tab_w, tab_h}
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
		badge_size := min(min(gui.style.row_height * 0.94, content.h), max(content.w * 0.42, 1))
		badge := uifw.Rect{content.x, content.y + max((content.h - badge_size) * 0.5, 0), badge_size, badge_size}
		label_x := badge.x + badge.w + gui.style.spacing_1
		label_rect := uifw.Rect{label_x, content.y, max(content.x + content.w - label_x, 1), content.h}
		label_scale := slime_controller_ui_fit_text_scale(gui, instrument.label, SLIME_CONTROLLER_UI_DECK_LABEL_SCALE, label_rect.w)
		uifw.gui_scissor_begin(gui, tab)
		slime_controller_ui_draw_icon_badge(gui, badge, instrument.instrument, instrument.icon, selected || deck_focused)
		uifw.gui_text_aligned_scaled(gui, label_rect, instrument.label, gui.style.text, .Left, label_scale)
		uifw.gui_scissor_end(gui)
	}
	if gui.input.active_device == .Controller {
		controller_prompt_draw_context_hint(gui, hint_rect, state.focus.phase, settings)
	} else {
		hint_scale := slime_controller_ui_fit_text_scale(gui, hint, SLIME_CONTROLLER_UI_HINT_SCALE, hint_rect.w)
		uifw.gui_text_aligned_scaled(gui, hint_rect, hint, gui.style.text_muted, .Center, hint_scale)
	}
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
		row_count = 6
		extra = 8
		if mode != .Couch && settings.post_processing.blur_enabled {
			slider_count = 2
		}
	case .Brush:
		row_count = 7
		extra = shared_two_axis_pad_height(gui) + 8
	case .Motion:
		slider_count = 1
		row_count = 5
		extra = SLIME_CONTROLLER_UI_BEHAVIOR_HEIGHT + 8
	case .Awareness:
		row_count = 0
		extra = SLIME_CONTROLLER_UI_AWARENESS_HEIGHT
	case .Field:
		slider_count = 1
		row_count = 3
		extra = shared_two_axis_pad_height(gui) + 8
	case .World:
		row_count = 10
		extra = shared_two_axis_pad_height(gui) + 8
		if settings.position_generator == 7 {
			row_count += 5
		}
		if settings.mask_pattern == .Image {
			row_count += 5
		}
	case .Presets:
		row_count = f32(preset_fieldset_content_rows(&sim.preset_ui) + 4 + (sim.slime_randomize_undo_available ? 1 : 0))
		extra = 8
	case:
		row_count = 1
	}

	items := row_count + slider_count
	return row_count * row + slider_count * slider + max(items - 1, 0) * gap + extra
}

slime_controller_ui_draw_panel :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State, panel: uifw.Rect, worker: ^Product_Context) {
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
		uifw.gui_label(gui, "Appearance")
		slime_controller_ui_draw_look(ui, gui, sim)
	case .Brush:
		slime_controller_ui_draw_brush(gui, sim)
	case .Motion:
		slime_controller_ui_draw_motion(gui, sim)
	case .Awareness:
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
		uifw.gui_label(gui, "Library")
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
