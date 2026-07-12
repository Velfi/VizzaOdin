package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"

Simulation_Controller_Ui_State :: struct {
	deck_visible: bool,
	panel_open: bool,
	focused_index: int,
	active_index: int,
	panel_scroll: f32,
	focus: uifw.Controller_Focus_State,
	pending_panel_focus: bool,
}

SIMULATION_CONTROLLER_STATE_COUNT :: 8

// The deck is ordered by impact: establish a result quickly, shape the defining
// behavior, then expose direct interaction and lower-frequency utilities.
// Values above the legacy 0-7 section range are semantic controller views that
// may compose several old fieldsets without changing the underlying settings.
CONTROLLER_SECTION_PRESETS :: 100
CONTROLLER_SECTION_LOOK :: 101
GRAY_SCOTT_SECTION_PATTERN :: 102
GRAY_SCOTT_SECTION_MASK :: 103
PARTICLE_LIFE_SECTION_FORCES :: 102
PARTICLE_LIFE_SECTION_POPULATION :: 103
PARTICLE_LIFE_SECTION_ADVANCED :: 104
MOIRE_SECTION_PATTERN :: 102

GRAY_SCOTT_CONTROLLER_TABS := [?]string{"Presets", "Look", "Pattern", "Mask", "Brush", "Camera"}
GRAY_SCOTT_CONTROLLER_SECTIONS := [?]int{CONTROLLER_SECTION_PRESETS, CONTROLLER_SECTION_LOOK, GRAY_SCOTT_SECTION_PATTERN, GRAY_SCOTT_SECTION_MASK, 4, 7}
PARTICLE_LIFE_CONTROLLER_TABS := [?]string{"Presets", "Look", "Forces", "Physics", "Population", "Brush", "Advanced"}
PARTICLE_LIFE_CONTROLLER_SECTIONS := [?]int{CONTROLLER_SECTION_PRESETS, CONTROLLER_SECTION_LOOK, PARTICLE_LIFE_SECTION_FORCES, 5, PARTICLE_LIFE_SECTION_POPULATION, 3, PARTICLE_LIFE_SECTION_ADVANCED}
FLOW_FIELD_CONTROLLER_TABS := [?]string{"Presets", "Look", "Field", "Particles", "Trails", "Brush"}
FLOW_FIELD_CONTROLLER_SECTIONS := [?]int{CONTROLLER_SECTION_PRESETS, CONTROLLER_SECTION_LOOK, 5, 6, 7, 3}
PELLETS_CONTROLLER_TABS := [?]string{"Presets", "Look", "Physics", "Particles", "Brush"}
PELLETS_CONTROLLER_SECTIONS := [?]int{CONTROLLER_SECTION_PRESETS, CONTROLLER_SECTION_LOOK, 6, 5, 3}
VORONOI_CONTROLLER_TABS := [?]string{"Presets", "Look", "Tools"}
VORONOI_CONTROLLER_SECTIONS := [?]int{CONTROLLER_SECTION_PRESETS, CONTROLLER_SECTION_LOOK, 5}
MOIRE_CONTROLLER_TABS := [?]string{"Presets", "Look", "Pattern", "Flow"}
MOIRE_CONTROLLER_SECTIONS := [?]int{CONTROLLER_SECTION_PRESETS, CONTROLLER_SECTION_LOOK, MOIRE_SECTION_PATTERN, 7}
VECTORS_CONTROLLER_TABS := [?]string{"Presets", "Look", "Field", "Probe"}
VECTORS_CONTROLLER_SECTIONS := [?]int{CONTROLLER_SECTION_PRESETS, CONTROLLER_SECTION_LOOK, 3, 8}
PRIMORDIAL_CONTROLLER_TABS := [?]string{"Presets", "Look", "Motion", "Population", "Brush"}
PRIMORDIAL_CONTROLLER_SECTIONS := [?]int{CONTROLLER_SECTION_PRESETS, CONTROLLER_SECTION_LOOK, 6, 5, 3}

simulation_controller_ui_init :: proc(state: ^Simulation_Controller_Ui_State) {
	state^ = {deck_visible = false, panel_open = false}
	uifw.gui_controller_focus_init(&state.focus)
}

simulation_controller_ui_state_index :: proc(mode: App_Mode) -> (int, bool) {
	#partial switch mode {
	case .Gray_Scott: return 0, true
	case .Particle_Life: return 1, true
	case .Flow_Field: return 2, true
	case .Pellets: return 3, true
	case .Voronoi_CA: return 4, true
	case .Moire: return 5, true
	case .Vectors: return 6, true
	case .Primordial: return 7, true
	case: return 0, false
	}
}

simulation_controller_ui_state :: proc(ui: ^App_Ui_State) -> ^Simulation_Controller_Ui_State {
	index, ok := simulation_controller_ui_state_index(ui.mode)
	return ok ? &ui.simulation_controllers[index] : nil
}

simulation_controller_ui_tabs :: proc(mode: App_Mode) -> []string {
	#partial switch mode {
	case .Gray_Scott: return GRAY_SCOTT_CONTROLLER_TABS[:]
	case .Particle_Life: return PARTICLE_LIFE_CONTROLLER_TABS[:]
	case .Flow_Field: return FLOW_FIELD_CONTROLLER_TABS[:]
	case .Pellets: return PELLETS_CONTROLLER_TABS[:]
	case .Voronoi_CA: return VORONOI_CONTROLLER_TABS[:]
	case .Moire: return MOIRE_CONTROLLER_TABS[:]
	case .Vectors: return VECTORS_CONTROLLER_TABS[:]
	case .Primordial: return PRIMORDIAL_CONTROLLER_TABS[:]
	case: return nil
	}
}

simulation_controller_ui_section :: proc(mode: App_Mode, tab_index: int) -> int {
	sections: []int
	#partial switch mode {
	case .Gray_Scott: sections = GRAY_SCOTT_CONTROLLER_SECTIONS[:]
	case .Particle_Life: sections = PARTICLE_LIFE_CONTROLLER_SECTIONS[:]
	case .Flow_Field: sections = FLOW_FIELD_CONTROLLER_SECTIONS[:]
	case .Pellets: sections = PELLETS_CONTROLLER_SECTIONS[:]
	case .Voronoi_CA: sections = VORONOI_CONTROLLER_SECTIONS[:]
	case .Moire: sections = MOIRE_CONTROLLER_SECTIONS[:]
	case .Vectors: sections = VECTORS_CONTROLLER_SECTIONS[:]
	case .Primordial: sections = PRIMORDIAL_CONTROLLER_SECTIONS[:]
	case: return tab_index
	}
	if tab_index < 0 || tab_index >= len(sections) {return tab_index}
	return sections[tab_index]
}

simulation_controller_ui_select_canvas_tool :: proc(mode: App_Mode, tab_index: int, remaining: ^Remaining_Sim_State) {
	_ = mode; _ = tab_index; _ = remaining
}

simulation_controller_ui_tab_icon :: proc(label: string) -> uifw.Ui_Controller_Icon {
	if label == "Presets" {return .Presets}
	if label == "Look" {return .Palette}
	if label == "Pattern" {return .Pattern}
	if label == "Mask" {return .Mask}
	if label == "Brush" {return .Brush}
	if label == "Camera" {return .Camera}
	if label == "Forces" {return .Forces}
	if label == "Physics" {return .Physics}
	if label == "Population" {return .Population}
	if label == "Advanced" {return .Advanced}
	if label == "Field" {return .Field}
	if label == "Particles" {return .Particles}
	if label == "Trails" {return .Trails}
	if label == "Sites" {return .Sites}
	if label == "Magnet" {return .Forces}
	if label == "Sculpt" {return .Brush}
	if label == "Tools" {return .Brush}
	if label == "Probe" {return .Brush}
	if label == "Flow" {return .Flow}
	if label == "Motion" {return .Motion}
	return .World
}

simulation_controller_ui_enabled :: proc(ui: ^App_Ui_State) -> bool {
	if ui == nil {return false}
	_, ok := simulation_controller_ui_state_index(ui.mode)
	return ok
}

simulation_controller_ui_focused :: proc(ui: ^App_Ui_State) -> bool {
	state := simulation_controller_ui_state(ui)
	return state != nil && state.focus.phase != .Unfocused
}

simulation_controller_ui_over_ui :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, input: Ui_Frame_Input) -> bool {
	state := simulation_controller_ui_state(ui)
	if state == nil || (!state.deck_visible && !state.panel_open) {return false}
	deck := simulation_controller_ui_deck_rect(gui, f32(input.window_width), f32(input.window_height), len(simulation_controller_ui_tabs(ui.mode)))
	if state.deck_visible && uifw.gui_contains(deck, input.mouse_pos) {return true}
	return state.panel_open && uifw.gui_contains(simulation_controller_ui_panel_rect(gui, f32(input.window_width), f32(input.window_height), deck), input.mouse_pos)
}

simulation_controller_ui_region_id :: proc(gui: ^uifw.Gui_Context, suffix: string) -> uifw.Gui_Id {
	return uifw.gui_make_id(gui, fmt.tprintf("simulation_controller_%s", suffix))
}

simulation_controller_ui_panel_region_id :: proc(gui: ^uifw.Gui_Context, section: int) -> uifw.Gui_Id {
	uifw.gui_push_id(gui, fmt.tprintf("simulation_controller_section_%d", section))
	region := simulation_controller_ui_region_id(gui, "panel")
	uifw.gui_pop_id(gui)
	return region
}

simulation_controller_ui_clamp :: proc(state: ^Simulation_Controller_Ui_State, count: int) {
	if count <= 0 {state.focused_index = 0; state.active_index = 0; return}
	state.focused_index = max(min(state.focused_index, count - 1), 0)
	state.active_index = max(min(state.active_index, count - 1), 0)
}

simulation_controller_ui_deck_rect :: proc(gui: ^uifw.Gui_Context, width, height: f32, count: int) -> uifw.Rect {
	margin := max(gui.style.spacing_3, f32(18))
	key_w := slime_controller_ui_key_badge_size(gui)
	hint_h := max(gui.style.small_line_height, gui.style.body_line_height * 0.72)
	header_h := app_ui_simulation_bar_height(gui)
	tab_h := max(gui.style.row_height * 1.28, key_w * 0.72)
	deck_h := header_h + tab_h + hint_h + gui.style.spacing_1 * 3
	tab_min := max(SLIME_CONTROLLER_UI_DECK_MIN_TAB_WIDTH, key_w + gui.style.spacing_2 + gui.style.body_char_width * 5.8)
	tab_min = min(tab_min, SLIME_CONTROLLER_UI_DECK_MAX_TAB_WIDTH)
	target_w := f32(max(count, 1)) * tab_min + f32(max(count, 1) + 1) * gui.style.spacing
	deck_w := min(max(target_w, width * 0.58), max(width - margin * 2, 1))
	return {max((width - deck_w) * 0.5, margin), max(height - deck_h - margin, margin), deck_w, deck_h}
}

simulation_controller_ui_panel_rect :: proc(gui: ^uifw.Gui_Context, width, height: f32, deck: uifw.Rect) -> uifw.Rect {
	margin := max(gui.style.spacing_3, f32(18))
	panel_w := app_ui_simulation_control_panel_width(gui, width, 720)
	height_fraction := app_ui_simulation_control_panel_height_fraction(width, 0.42, 0.46)
	panel_h := min(max(height * height_fraction, gui.style.row_height * 7), max(deck.y - margin * 2, 1))
	return {max((width - panel_w) * 0.5, margin), max(deck.y - panel_h - margin, margin), panel_w, panel_h}
}

simulation_controller_ui_focus_deck :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	state := simulation_controller_ui_state(ui)
	if state == nil {return}
	tabs := simulation_controller_ui_tabs(ui.mode)
	simulation_controller_ui_clamp(state, len(tabs))
	app_ui_set_simulation_chrome_visible(ui, true)
	state.focused_index = state.active_index
	region := simulation_controller_ui_region_id(gui, "deck")
	fallback := uifw.gui_make_id(gui, fmt.tprintf("simulation_deck_%d", state.focused_index))
	gui.focused = uifw.gui_controller_focus_enter_region(&state.focus, region, uifw.GUI_ID_NONE, fallback)
	uifw.gui_focus_owner_claim(gui, .Control_Deck, region)
}

simulation_controller_ui_update_input :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) -> bool {
	if !simulation_controller_ui_enabled(ui) {return false}
	state := simulation_controller_ui_state(ui)
	tabs := simulation_controller_ui_tabs(ui.mode)
	simulation_controller_ui_clamp(state, len(tabs))
	state.focus.remember_focus = ui.settings.remember_controller_focus
	consumed := false
	if state.focus.phase == .Unfocused && (gui.input.focus_next || gui.input.focus_prev) {
		simulation_controller_ui_focus_deck(ui, gui)
		gui.input.focus_next = false; gui.input.focus_prev = false
	}
	if app_ui_control_deck_pressed(ui.frame_actions.control_deck) ||
		(ui.frame_actions.toggle_ui.pressed && ui.frame_actions.toggle_ui.owner == .Controller) {
		simulation_controller_ui_focus_deck(ui, gui)
		consumed = true
	}
	if state.focus.phase != .Unfocused {
		if gui.input.back && gui.focus_edit_id == uifw.GUI_ID_NONE && gui.text_edit_id == uifw.GUI_ID_NONE && gui.open_panel == uifw.GUI_ID_NONE {
			if state.focus.phase == .Active_Control {
				uifw.gui_controller_focus_deactivate(&state.focus)
				uifw.gui_focus_owner_release(gui, .Active_Control)
			} else if state.focus.phase == .Child_Region {
				state.panel_open = false
				uifw.gui_controller_focus_leave_region(&state.focus)
				gui.focused = uifw.gui_make_id(gui, fmt.tprintf("simulation_deck_%d", state.focused_index))
				uifw.gui_focus_owner_release(gui, .Panel)
			} else {
				state.panel_open = false
				uifw.gui_controller_focus_leave_region(&state.focus)
				gui.focused = uifw.GUI_ID_NONE
				uifw.gui_focus_owner_release(gui, .Control_Deck)
			}
			gui.input.back = false
		}
		deck_focused := state.focus.phase == .Region && state.deck_visible &&
			gui.focused == uifw.gui_make_id(gui, fmt.tprintf("simulation_deck_%d", state.focused_index))
		if deck_focused {
			if gui.input.nav_pressed_x > 0 || gui.input.focus_next {
				state.focused_index = (state.focused_index + 1) % len(tabs)
				gui.input.nav_pressed_x = 0; gui.input.focus_next = false
			} else if gui.input.nav_pressed_x < 0 || gui.input.focus_prev {
				state.focused_index = (state.focused_index - 1 + len(tabs)) % len(tabs)
				gui.input.nav_pressed_x = 0; gui.input.focus_prev = false
			}
			gui.focused = uifw.gui_make_id(gui, fmt.tprintf("simulation_deck_%d", state.focused_index))
			if gui.input.accept {
				if state.active_index != state.focused_index {state.panel_scroll = 0}
				state.active_index = state.focused_index; state.panel_open = true
				section := simulation_controller_ui_section(ui.mode, state.active_index)
				panel_region := simulation_controller_ui_panel_region_id(gui, section)
				_ = uifw.gui_controller_focus_enter_region(&state.focus, panel_region, simulation_controller_ui_region_id(gui, "deck"), uifw.GUI_ID_NONE)
				uifw.gui_focus_owner_claim(gui, .Panel, panel_region)
				state.pending_panel_focus = true
			}
		} else if state.focus.phase == .Child_Region && gui.input.accept && gui.focused != uifw.GUI_ID_NONE {
			uifw.gui_controller_focus_activate(&state.focus, gui.focused)
			uifw.gui_focus_owner_claim(gui, .Active_Control, gui.focused)
			// Let the Accept press flow through so the widget can enter edit mode
			// and set focus_edit_id, preventing an immediate deactivation revert.
			// Do not clear accept here: gui_accept_pressed already edge-detects the
			// press (accept && !previous.accept), so a held button cannot commit on
			// the next frame. Clearing it only breaks the begin-edit path.
		}
	}
	return consumed
}

simulation_controller_ui_draw_deck :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, remaining: ^Remaining_Sim_State = nil) {
	state := simulation_controller_ui_state(ui)
	tabs := simulation_controller_ui_tabs(ui.mode)
	// Keyboard/controller Accept moves focus into the panel during input update;
	// apply the tool choice here without continuously overriding canvas shortcuts.
	if gui.input.accept && state.focus.phase == .Child_Region {
		simulation_controller_ui_select_canvas_tool(ui.mode, state.active_index, remaining)
	}
	uifw.gui_spatial_group_begin(gui, "simulation_controller_deck")
	defer uifw.gui_spatial_group_end(gui)
	gap := gui.style.spacing_1
	hint_h := max(gui.style.small_line_height, gui.style.body_line_height * 0.72)
	hint_rect := uifw.Rect{rect.x + gap * 1.5, rect.y + rect.h - gap - hint_h, max(rect.w - gap * 3, 1), hint_h}
	tabs_y := rect.y + app_ui_simulation_bar_height(gui) + gap
	tab_w := max((rect.w - gap * f32(len(tabs) + 1)) / f32(len(tabs)), 1)
	tab_h := max(hint_rect.y - tabs_y - gap, 1)
	for label, i in tabs {
		tab := uifw.Rect{rect.x + gap + f32(i) * (tab_w + gap), tabs_y, tab_w, tab_h}
		id := uifw.gui_make_id(gui, fmt.tprintf("simulation_deck_%d", i))
		control := uifw.gui_control(gui, id, tab, true)
		if control.focused {state.focused_index = i}
		if control.activated || (control.hovered && gui.active == id && gui.input.mouse_released) {
			if state.active_index != i {state.panel_scroll = 0}
			state.focused_index = i; state.active_index = i; state.panel_open = true; state.deck_visible = true
			simulation_controller_ui_select_canvas_tool(ui.mode, i, remaining)
			simulation_controller_ui_focus_deck(ui, gui)
		}
		selected := state.panel_open && state.active_index == i
		fill := selected ? uifw.Color{0.28, 0.30, 0.62, 0.78} : uifw.Color{1, 1, 1, 0.08}
		deck_focused := state.focus.phase == .Region && (control.focused || i == state.focused_index)
		if control.hovered || deck_focused {
			fill = selected ? uifw.Color{0.34, 0.36, 0.72, 0.86} : uifw.Color{1, 1, 1, 0.16}
		}
		uifw.gui_round_rect(gui, tab, 6, fill)
		uifw.gui_round_stroke(gui, tab, 6, selected ? uifw.gui_apply_opacity(gui.style.accent, 0.62) : uifw.Color{1, 1, 1, 0.12}, selected ? max(gui.style.border_width * 1.5, 1.5) : gui.style.border_width)
		if deck_focused {uifw.gui_focus_ring(gui, tab)}
		content := uifw.gui_inset(tab, max(gui.style.spacing_1, gui.style.border_width * 2))
		badge_size := min(min(gui.style.row_height * 0.94, content.h), max(content.w * 0.42, 1))
		badge := uifw.Rect{content.x, content.y + max((content.h - badge_size) * 0.5, 0), badge_size, badge_size}
		label_x := badge.x + badge.w + gui.style.spacing_1
		label_rect := uifw.Rect{label_x, content.y, max(content.x + content.w - label_x, 1), content.h}
		scale := slime_controller_ui_fit_text_scale(gui, label, SLIME_CONTROLLER_UI_DECK_LABEL_SCALE, label_rect.w)
		uifw.gui_scissor_begin(gui, tab)
		slime_controller_ui_draw_atlas_icon_badge(gui, badge, simulation_controller_ui_tab_icon(label), selected || deck_focused)
		uifw.gui_text_aligned_scaled(gui, label_rect, label, gui.style.text, .Left, scale)
		uifw.gui_scissor_end(gui)
	}
	hint := simulation_controller_ui_context_hint(state, gui.input.active_device)
	if gui.input.active_device == .Controller {
		controller_prompt_draw_context_hint(gui, hint_rect, state.focus.phase, &ui.settings)
	} else {
		hint_scale := slime_controller_ui_fit_text_scale(gui, hint, SLIME_CONTROLLER_UI_HINT_SCALE, hint_rect.w)
		uifw.gui_text_aligned_scaled(gui, hint_rect, hint, gui.style.text_muted, .Center, hint_scale)
	}
}

simulation_controller_ui_context_hint :: proc(state: ^Simulation_Controller_Ui_State, device: uifw.Input_Device_Kind) -> string {
	controller := device == .Controller
	switch state.focus.phase {
	case .Region:
		return controller ? "D-pad / shoulders: browse  |  Accept: open  |  Back: close" : "Arrows / Tab: browse  |  Enter: open  |  Esc: close"
	case .Child_Region:
		return controller ? "D-pad: navigate  |  Accept: edit  |  Back: sections" : "Arrows / Tab: navigate  |  Enter: edit  |  Esc: sections"
	case .Active_Control:
		return controller ? "D-pad: adjust  |  Light stick: fine  |  Secondary: step  |  Accept: commit  |  Back: cancel" : "Arrows: adjust  |  Shift: fine  |  Ctrl: broad  |  Enter: commit  |  Esc: cancel"
	case .Unfocused:
		return controller ? "Shoulders: focus controls" : "Tab: focus controls  |  Click: open section"
	}
	return ""
}

simulation_controller_ui_draw_panel :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, worker: ^Product_Context) {
	state := simulation_controller_ui_state(ui)
	section := simulation_controller_ui_section(ui.mode, state.active_index)
	uifw.gui_push_id(gui, fmt.tprintf("simulation_controller_section_%d", section))
	defer uifw.gui_pop_id(gui)
	panel_region := simulation_controller_ui_region_id(gui, "panel")
	first := gui.spatial_item_count
	previous := gui.controller_explicit_activation
	gui.controller_explicit_activation = state.focus.phase == .Child_Region || state.focus.phase == .Active_Control
	defer gui.controller_explicit_activation = previous
	uifw.gui_spatial_group_begin(gui, "simulation_controller_panel")
	defer uifw.gui_spatial_group_end(gui)
	descriptor, ok := feature_descriptor_by_mode(ui.mode)
	if ok && descriptor.draw_controls != nil do descriptor.draw_controls(ui, gui, rect, worker, section, &state.panel_scroll)
	if state.pending_panel_focus {
		fallback := uifw.GUI_ID_NONE
		restored := uifw.GUI_ID_NONE
		for i in first ..< gui.spatial_item_count {
			item := gui.spatial_items[i]
			if !item.focusable || item.group != panel_region {continue}
			if fallback == uifw.GUI_ID_NONE {fallback = item.id}
			candidate := uifw.gui_controller_focus_restore(&state.focus, panel_region, fallback)
			if item.id == candidate {restored = item.id; break}
		}
		if restored == uifw.GUI_ID_NONE {restored = fallback}
		if restored != uifw.GUI_ID_NONE {gui.focused = restored; gui.focus_moved = true}
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

simulation_controller_ui_draw :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, gray: ^Gray_Scott_Simulation = nil, particle: ^Particle_Life_Simulation = nil, remaining: ^Remaining_Sim_State = nil, width, height: f32, worker: ^Product_Context) {
	if !simulation_controller_ui_enabled(ui) {return}
	state := simulation_controller_ui_state(ui)
	tabs := simulation_controller_ui_tabs(ui.mode)
	simulation_controller_ui_clamp(state, len(tabs))
	deck := simulation_controller_ui_deck_rect(gui, width, height, len(tabs))
	if ui.simulation_shell.controls_visible && state.panel_open {simulation_controller_ui_draw_panel(ui, gui, simulation_controller_ui_panel_rect(gui, width, height, deck), worker)}
	if ui.simulation_shell.controls_visible {simulation_controller_ui_draw_deck(ui, gui, deck, remaining)}
	if remaining != nil {
		kind := remaining_sim_kind_from_app_mode(ui.mode)
		remaining_sim_draw_color_scheme_modal(gui, &ui.color_scheme_editor, kind, remaining)
		preset_save_dialog_draw(gui, &remaining.preset_ui, worker, remaining_sim_directory(kind))
	}
	if gray != nil {_ = color_scheme_editor_draw_modal(gui, &ui.color_scheme_editor, &gray.settings.color_scheme); preset_save_dialog_draw(gui, &gray.runtime.preset_fieldset, worker, "gray_scott")}
	if particle != nil {_ = color_scheme_editor_draw_modal(gui, &ui.color_scheme_editor, &particle.settings.color_scheme); preset_save_dialog_draw(gui, &particle.runtime.preset_ui, worker, "particle_life")}
}

simulation_controller_ui_end_frame :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	state := simulation_controller_ui_state(ui)
	if state == nil || (state.focus.phase != .Child_Region && state.focus.phase != .Active_Control) {return}
	section := simulation_controller_ui_section(ui.mode, state.active_index)
	region := simulation_controller_ui_panel_region_id(gui, section)
	for item in gui.spatial_items[:gui.spatial_item_count] {
		if item.id == gui.focused && item.focusable && item.group == region {
			uifw.gui_controller_focus_remember(&state.focus, region, item.id)
			return
		}
	}
}
