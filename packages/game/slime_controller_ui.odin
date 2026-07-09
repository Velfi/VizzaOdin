package game

import uifw "../ui"

import "core:fmt"
import "core:math"

SLIME_CONTROLLER_UI_DECK_MIN_TAB_WIDTH :: f32(132)
SLIME_CONTROLLER_UI_DECK_MAX_TAB_WIDTH :: f32(260)
SLIME_CONTROLLER_UI_DECK_LABEL_SCALE :: f32(0.76)
SLIME_CONTROLLER_UI_KEY_SCALE :: f32(0.62)

Slime_Controller_Ui_State :: struct {
	deck_visible: bool,
	panel_open: bool,
	focused_index: int,
	active_index: int,
	mode: Control_Ui_Mode,
	panel_scroll: f32,
}

slime_controller_ui_init :: proc(state: ^Slime_Controller_Ui_State) {
	state^ = {
		deck_visible = true,
		panel_open = false,
		focused_index = 0,
		active_index = 0,
		mode = .Couch,
	}
}

slime_controller_ui_enabled :: proc(ui: ^App_Ui_State) -> bool {
	return ui != nil && ui.settings.experimental_controller_ui && ui.mode == .Slime_Mold
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
	return max(gui.style.row_height * 0.52, gui.style.body_line_height * 0.78)
}

slime_controller_ui_draw_key_badge :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, key: string, selected: bool) {
	fill := selected ? uifw.Color{0.48, 0.50, 0.90, 0.88} : uifw.Color{1, 1, 1, 0.12}
	stroke := selected ? gui.style.accent : uifw.Color{1, 1, 1, 0.16}
	uifw.gui_round_rect(gui, rect, 5, fill)
	uifw.gui_round_stroke(gui, rect, 5, stroke, gui.style.border_width)
	key_scale := slime_controller_ui_fit_text_scale(gui, key, SLIME_CONTROLLER_UI_KEY_SCALE, max(rect.w - gui.style.spacing_1, 1))
	uifw.gui_text_aligned_scaled(gui, rect, key, gui.style.text, .Center, key_scale)
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
	gui.focused = uifw.gui_make_id(gui, fmt.tprintf("slime_deck_%d", state.focused_index))
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
	deck_h := max(gui.style.row_height * 1.45, key_w + gui.style.spacing_3)
	target_w := f32(count) * tab_min + f32(count + 1) * gui.style.spacing
	deck_w := min(max(target_w, width * 0.58), max(width - margin * 2, 1))
	return {max((width - deck_w) * 0.5, margin), max(height - deck_h - margin, margin), deck_w, deck_h}
}

slime_controller_ui_panel_rect :: proc(gui: ^uifw.Gui_Context, width, height: f32, deck: uifw.Rect) -> uifw.Rect {
	margin := max(gui.style.spacing_3, f32(18))
	panel_w := min(max(width * 0.58, f32(720)), max(width - margin * 2, 1))
	panel_h := min(max(height * 0.36, gui.style.row_height * 6.5), max(deck.y - margin * 2, gui.style.row_height * 4))
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

slime_controller_ui_filter_input :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, input: Ui_Frame_Input) -> Ui_Frame_Input {
	filtered := input
	if !slime_controller_ui_enabled(ui) {
		return filtered
	}
	state := &ui.slime_controller
	over_new_ui := slime_controller_ui_over_ui(state, gui, input)
	keyboard_triggering_new_ui := input.key_tab ||
		input.key_space ||
		input.key_space_down ||
		input.key_space_pressed ||
		input.key_space_released ||
		(input.toggle_ui && input.active_device == .Controller) ||
		state.deck_visible ||
		state.panel_open
	pointer_consumed := over_new_ui ||
		input.key_space ||
		input.key_space_down ||
		input.key_space_pressed ||
		input.key_space_released ||
		(input.toggle_ui && input.active_device == .Controller)

	if pointer_consumed {
		filtered.mouse_down = false
		filtered.mouse_pressed = false
		filtered.mouse_released = false
		filtered.primary_down = false
		filtered.primary_pressed = false
		filtered.primary_released = false
		filtered.secondary_down = false
		filtered.secondary_pressed = false
		filtered.secondary_released = false
		filtered.wheel_delta = 0
	}
	if keyboard_triggering_new_ui {
		filtered.pause = false
		filtered.key_space = false
		filtered.key_space_down = false
		filtered.key_space_pressed = false
		filtered.key_space_released = false
		if input.active_device == .Controller {
			filtered.toggle_ui = false
		}
		filtered.focus_next = false
		filtered.focus_prev = false
	}
	return filtered
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
	pause_consumed := false

	deck_opened_by_focus := false
	if !state.deck_visible && (gui.input.focus_next || gui.input.focus_prev) {
		slime_controller_ui_focus_deck(state, gui)
		deck_opened_by_focus = true
		gui.input.focus_next = false
		gui.input.focus_prev = false
	}

	if gui.input.key_space || gui.input.key_space_pressed {
		slime_controller_ui_focus_deck(state, gui)
		pause_consumed = true
	}
	if gui.input.toggle_ui && gui.input.active_device == .Controller {
		slime_controller_ui_focus_deck(state, gui)
		pause_consumed = true
	}
	if gui.input.key_space_down || gui.input.key_space_released {
		pause_consumed = true
	}

	if state.deck_visible || state.panel_open {
		if gui.input.back {
			if state.panel_open {
				state.panel_open = false
			} else {
				state.deck_visible = false
			}
			gui.focused = uifw.GUI_ID_NONE
		}
		deck_accepts_input := state.deck_visible && !deck_opened_by_focus && (!state.panel_open || slime_controller_ui_deck_focused(state, gui))
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
				}
			}
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
	if state.panel_open {
		deck := slime_controller_ui_deck_rect(gui, width, height, state.mode)
		panel := slime_controller_ui_panel_rect(gui, width, height, deck)
		slime_controller_ui_draw_panel(ui, gui, sim, panel, worker)
	}
	if state.deck_visible {
		deck := slime_controller_ui_deck_rect(gui, width, height, state.mode)
		slime_controller_ui_draw_deck(state, gui, deck)
	}
	if state.panel_open {
		instrument, ok := slime_controller_ui_active_instrument(state)
		if ok && instrument.instrument == .Look {
			_ = color_scheme_editor_draw_modal(gui, &ui.color_scheme_editor, &sim.slime.color_scheme)
		}
	}
}

slime_controller_ui_draw_deck :: proc(state: ^Slime_Controller_Ui_State, gui: ^uifw.Gui_Context, deck: uifw.Rect) {
	count := slime_controller_ui_visible_instrument_count(state.mode)
	if count <= 0 {
		return
	}
	uifw.gui_shadow(gui, deck, 8, {0, 6}, 18, {0, 0, 0, 0.36})
	glass := uifw.gui_default_glass_style(gui, 8)
	glass.tint = {0.06, 0.08, 0.10, 0.48}
	glass.roughness = 0.58
	glass.thickness = max(gui.style.rhythm * 0.20, f32(8))
	glass.bevel = max(gui.style.border_width * 6, f32(6))
	glass.border = 0.32
	uifw.gui_refractive_glass_rect(gui, deck, glass)
	uifw.gui_round_stroke(gui, deck, 8, {1, 1, 1, 0.16}, gui.style.border_width)
	gap := gui.style.spacing
	tab_w := max((deck.w - gap * f32(count + 1)) / f32(count), 1)
	tab_h := max(deck.h - gap * 2, 1)
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
		} else if control.hovered {
			state.focused_index = i
		}
		selected := i == state.active_index && state.panel_open
		deck_focused := i == state.focused_index
		fill := selected ? uifw.Color{0.28, 0.30, 0.62, 0.78} : uifw.Color{1, 1, 1, 0.08}
		if control.hovered || control.focused || deck_focused {
			fill = selected ? uifw.Color{0.34, 0.36, 0.72, 0.86} : uifw.Color{1, 1, 1, 0.16}
		}
		uifw.gui_round_rect(gui, tab, 6, fill)
		uifw.gui_round_stroke(gui, tab, 6, selected || control.focused || deck_focused ? gui.style.accent : uifw.Color{1, 1, 1, 0.12}, selected || control.focused || deck_focused ? max(gui.style.border_width * 2, 2) : gui.style.border_width)
		content := uifw.gui_inset(tab, gui.style.spacing_1)
		badge_size := min(slime_controller_ui_key_badge_size(gui), max(content.h - gui.style.spacing_1, 1))
		row_h := min(max(badge_size, gui.style.body_line_height * 0.86), content.h)
		row_y := content.y + max((content.h - row_h) * 0.5, 0)
		badge := uifw.Rect{content.x, row_y + max((row_h - badge_size) * 0.5, 0), badge_size, badge_size}
		label_x := badge.x + badge.w + gui.style.spacing_2
		label_rect := uifw.Rect{label_x, row_y, max(content.x + content.w - label_x, 1), row_h}
		label_scale := slime_controller_ui_fit_text_scale(gui, instrument.label, SLIME_CONTROLLER_UI_DECK_LABEL_SCALE, label_rect.w)
		uifw.gui_scissor_begin(gui, tab)
		slime_controller_ui_draw_key_badge(gui, badge, instrument.icon, selected || control.focused || deck_focused)
		uifw.gui_text_aligned_scaled(gui, label_rect, instrument.label, gui.style.text, .Left, label_scale)
		uifw.gui_scissor_end(gui)
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
	case .Play:
		row_count = 4
	case .Look:
		row_count = 3
		if mode != .Couch && settings.post_processing.blur_enabled {
			slider_count = 2
		}
	case .Brush:
		slider_count = 2
		row_count = 1
	case .Motion:
		slider_count = 4
	case .Awareness:
		slider_count = 2
		extra = max(row * 2.1, f32(112))
	case .Field:
		slider_count = 3
		row_count = 1
	case .Birth:
		row_count = 3
		if settings.position_generator == 7 {
			row_count += 5
		}
	case .World:
		row_count = 5
		slider_count = 2
		if settings.mask_pattern == .Image {
			row_count += 5
		}
	case .Capture:
		row_count = 1
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
	uifw.gui_shadow(gui, panel, 8, {0, 7}, 20, {0, 0, 0, 0.42})
	uifw.gui_panel_begin(gui, panel)
	uifw.gui_push_id(gui, "slime_controller_panel")
	uifw.gui_heading(gui, instrument.label)
	viewport_h := max(panel.h - gui.style.panel_padding * 2 - gui.style.heading_line_height - gui.style.spacing, gui.style.row_height)
	viewport := uifw.gui_next_rect(gui, height = viewport_h)
	content_h := slime_controller_ui_panel_content_height(gui, sim, instrument.instrument, ui.slime_controller.mode)
	uifw.gui_scroll_begin(gui, viewport, content_h, &ui.slime_controller.panel_scroll)
	#partial switch instrument.instrument {
	case .Play:
		slime_controller_ui_draw_play(ui, gui, sim)
	case .Look:
		slime_controller_ui_draw_look(ui, gui, sim)
	case .Brush:
		slime_controller_ui_draw_brush(gui, sim)
	case .Motion:
		slime_controller_ui_draw_motion(gui, sim)
	case .Awareness:
		slime_controller_ui_draw_awareness(gui, sim)
	case .Field:
		slime_controller_ui_draw_field(gui, sim)
	case .Birth:
		slime_controller_ui_draw_birth(gui, sim, worker)
	case .World:
		slime_controller_ui_draw_world(gui, sim, worker)
	case .Capture:
		slime_controller_ui_draw_capture(ui, gui, worker)
	case:
		uifw.gui_label(gui, "No couch controls for this instrument.")
	}
	uifw.gui_scroll_end(gui)
	uifw.gui_pop_id(gui)
	uifw.gui_panel_end(gui)
}

slime_controller_ui_float_slider :: proc(gui: ^uifw.Gui_Context, desc: Control_Descriptor, value: ^f32) -> bool {
	label := fmt.tprintf("%s: %.2f", desc.label, value^)
	return uifw.gui_slider_f32(gui, label, desc.stable_id, value, desc.range.min, desc.range.max)
}

slime_controller_ui_button :: proc(gui: ^uifw.Gui_Context, desc: Control_Descriptor, label_override: string = "") -> bool {
	label := desc.label
	if len(label_override) > 0 {
		label = label_override
	}
	return uifw.gui_button(gui, label, desc.stable_id)
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
	}
	if desc, ok := slime_control_descriptor_by_id(.Post_Blur_Enabled); ok {
		_ = uifw.gui_toggle(gui, settings.post_processing.blur_enabled ? "Blur: On" : "Blur: Off", desc.stable_id, &settings.post_processing.blur_enabled)
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
	if desc, ok := slime_control_descriptor_by_id(.Brush_Radius); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &sim.cursor_size)
	}
	if desc, ok := slime_control_descriptor_by_id(.Brush_Strength); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &sim.cursor_strength)
	}
	uifw.gui_label(gui, "Left: attract   Right: repel")
}

slime_controller_ui_draw_motion :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	settings := &sim.slime
	if desc, ok := slime_control_descriptor_by_id(.Agents_Speed_Min); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &settings.agent_speed_min)
	}
	if desc, ok := slime_control_descriptor_by_id(.Agents_Speed_Max); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &settings.agent_speed_max)
	}
	if settings.agent_speed_min > settings.agent_speed_max {
		settings.agent_speed_min, settings.agent_speed_max = settings.agent_speed_max, settings.agent_speed_min
	}
	if desc, ok := slime_control_descriptor_by_id(.Agents_Turn_Rate); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &settings.agent_turn_rate)
	}
	if desc, ok := slime_control_descriptor_by_id(.Agents_Jitter); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &settings.agent_jitter)
	}
}

slime_controller_ui_draw_awareness :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	settings := &sim.slime
	slime_controller_ui_draw_sensor_cone(gui, settings.agent_sensor_angle, settings.agent_sensor_distance)
	if desc, ok := slime_control_descriptor_by_id(.Sensing_Angle); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &settings.agent_sensor_angle)
	}
	if desc, ok := slime_control_descriptor_by_id(.Sensing_Distance); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &settings.agent_sensor_distance)
	}
}

slime_controller_ui_draw_sensor_cone :: proc(gui: ^uifw.Gui_Context, angle, distance: f32) {
	bounds := uifw.gui_next_rect(gui, height = max(gui.style.row_height * 2.1, f32(112)))
	center := uifw.Vec2{bounds.x + bounds.w * 0.5, bounds.y + bounds.h * 0.66}
	r := min(bounds.h * 0.48, max(bounds.w * 0.18, 1))
	dist_t := min(max(distance / 500.0, 0), 1)
	cone_r := r * (0.35 + dist_t * 0.65)
	left := -math.PI * 0.5 - angle
	right := -math.PI * 0.5 + angle
	p0 := uifw.Vec2{center.x + math.cos(left) * cone_r, center.y + math.sin(left) * cone_r}
	p1 := uifw.Vec2{center.x + math.cos(right) * cone_r, center.y + math.sin(right) * cone_r}
	forward := uifw.Vec2{center.x, center.y - cone_r}
	uifw.gui_round_rect(gui, bounds, 6, {1, 1, 1, 0.05})
	uifw.gui_quad(gui, center, p0, forward, p1, {0.392, 0.424, 1.0, 0.26})
	uifw.gui_line(gui, center, p0, gui.style.accent, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, center, p1, gui.style.accent, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, center, forward, {1, 1, 1, 0.72}, max(gui.style.border_width, 1))
	uifw.gui_ellipse(gui, {center.x - 5, center.y - 5, 10, 10}, gui.style.text)
}

slime_controller_ui_draw_field :: proc(gui: ^uifw.Gui_Context, sim: ^Remaining_Sim_State) {
	settings := &sim.slime
	if desc, ok := slime_control_descriptor_by_id(.Field_Deposit); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &settings.pheromone_deposition_rate)
	}
	if desc, ok := slime_control_descriptor_by_id(.Field_Decay); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &settings.pheromone_decay_rate)
	}
	if desc, ok := slime_control_descriptor_by_id(.Field_Diffusion); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &settings.pheromone_diffusion_rate)
	}
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
	}
	if desc, ok := slime_control_descriptor_by_id(.Mask_Target); ok {
		if uifw.gui_selector(gui, fmt.tprintf("%s: %s", desc.label, SLIME_MASK_TARGET_NAMES[settings.mask_target_index]), desc.stable_id, &settings.mask_target_index, SLIME_MASK_TARGET_NAMES[:]) {
			settings.mask_target = Slime_Mask_Target(settings.mask_target_index)
		}
	}
	if desc, ok := slime_control_descriptor_by_id(.Mask_Strength); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &settings.mask_strength)
	}
	if desc, ok := slime_control_descriptor_by_id(.Mask_Curve); ok {
		_ = slime_controller_ui_float_slider(gui, desc, &settings.mask_curve)
	}
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
