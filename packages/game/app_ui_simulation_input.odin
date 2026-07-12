package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"

app_ui_draw_gray_scott :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Gray_Scott_Simulation, viewport: uifw.Vec2, worker: ^Product_Context) {
	width := viewport.x
	height := viewport.y
	pause_consumed := simulation_controller_ui_update_input(ui, gui)

	if gui.input.pause && !pause_consumed {
		sim.settings.paused = !sim.settings.paused
	}
	if sim.canvas_tool.changed {
		set := canvas_tool_set_for_mode(.Gray_Scott)
		tool := canvas_tool_selected(&set, &sim.canvas_tool)
		uifw.gui_notice(gui, fmt.tprintf("%s selected — Primary: %s · Secondary: %s", tool.name, tool.primary_label, tool.secondary_label), 1.6)
	}

	if ui.simulation_shell.controls_visible {
		tool_set := canvas_tool_set_for_mode(.Gray_Scott)
		tool := canvas_tool_selected(&tool_set, &sim.canvas_tool)
		name := fmt.tprintf("Gray-Scott · %s — Primary: %s · Secondary: %s", tool.name, tool.primary_label, tool.secondary_label)
		app_ui_draw_simulation_bar(ui, gui, .Gray_Scott, sim, nil, nil, sim.settings.paused, !sim.runtime.render_ready, name, viewport, width, worker)
	}
	simulation_controller_ui_draw(ui, gui, gray = sim, width = width, height = height, worker = worker)
	if sim.runtime.nutrient_image_dialog_requested {
		sim.runtime.nutrient_image_dialog_requested = false
		app_ui_request_image_dialog(ui, worker, .Gray_Scott_Nutrient)
	}
	app_ui_draw_loading_overlay(gui, width, height, !sim.runtime.render_ready)
}

app_ui_action_pressed_by_controller :: proc(action: Input_Action_Button_State) -> bool {
	return action.pressed && action.owner == .Controller
}

app_ui_control_deck_pressed :: proc(action: Input_Action_Button_State) -> bool {
	return action.pressed
}

app_ui_control_deck_active :: proc(action: Input_Action_Button_State) -> bool {
	return action.down || action.pressed || action.repeated || action.released
}

app_ui_take_controller_action :: proc(action: ^Input_Action_Button_State) -> bool {
	if action == nil || !app_ui_action_pressed_by_controller(action^) {
		return false
	}
	action.pressed = false
	action.repeated = false
	return true
}

app_ui_hide_unfocused_simulation_ui :: proc(ui: ^App_Ui_State) {
	ui.simulation_shell.show_ui = false
	app_ui_set_simulation_chrome_visible(ui, false)
	ui.slime_controller.deck_visible = false
	ui.slime_controller.panel_open = false
	ui.slime_controller.pending_panel_focus = false
	ui.slime_controller.focus.phase = .Unfocused
	ui.slime_controller.focus.region = uifw.GUI_ID_NONE
	ui.slime_controller.focus.parent_region = uifw.GUI_ID_NONE
	ui.slime_controller.focus.active_control = uifw.GUI_ID_NONE
	for &state in ui.simulation_controllers {
		state.deck_visible = false
		state.panel_open = false
		state.pending_panel_focus = false
		state.focus.phase = .Unfocused
		state.focus.region = uifw.GUI_ID_NONE
		state.focus.parent_region = uifw.GUI_ID_NONE
		state.focus.active_control = uifw.GUI_ID_NONE
	}
}

// The utility rail and Control Deck tabs are one simulation-chrome layer. The
// deck fields remain on the per-simulation states for panel/focus bookkeeping,
// but callers must not independently decide whether either part exists.
app_ui_set_simulation_chrome_visible :: proc(ui: ^App_Ui_State, visible: bool) {
	if ui == nil {return}
	ui.simulation_shell.controls_visible = visible
	if slime_controller_ui_enabled(ui) {
		ui.slime_controller.deck_visible = visible
	}
	if state := simulation_controller_ui_state(ui); state != nil {
		state.deck_visible = visible
	}
}

app_ui_release_controller_focus :: proc(ui: ^App_Ui_State) {
	if ui == nil {return}
	if slime_controller_ui_enabled(ui) {
		state := &ui.slime_controller
		state.pending_panel_focus = false
		state.focus.phase = .Unfocused
		state.focus.region = uifw.GUI_ID_NONE
		state.focus.parent_region = uifw.GUI_ID_NONE
		state.focus.active_control = uifw.GUI_ID_NONE
	}
	if state := simulation_controller_ui_state(ui); state != nil {
		state.pending_panel_focus = false
		state.focus.phase = .Unfocused
		state.focus.region = uifw.GUI_ID_NONE
		state.focus.parent_region = uifw.GUI_ID_NONE
		state.focus.active_control = uifw.GUI_ID_NONE
	}
}

app_ui_simulation_shell_update :: proc(ui: ^App_Ui_State, input: Ui_Frame_Input, ui_engaged := false) {
	ui.frame_actions = input.actions
	exit_held := input.key_escape_down || input.controller_start_down
	if app_ui_mode_is_simulation(ui.mode) && exit_held {
		ui.simulation_exit_hold_seconds += max(input.delta_time, 0)
		if ui.simulation_exit_hold_seconds >= 0.75 && !ui.simulation_exit_hold_triggered {
			ui.simulation_exit_hold_triggered = true
			app_ui_navigate(ui, .Main_Menu)
			return
		}
	} else {
		ui.simulation_exit_hold_seconds = 0
		ui.simulation_exit_hold_triggered = false
	}
	if input.actions.help.pressed && !ui.controls_help_open && app_ui_mode_is_simulation(ui.mode) {
		// Keyboard help is a shell-level command so it remains available when
		// the simulation UI has auto-hidden, but never steals an active editor.
		ui.controls_help_open = true
		ui.controls_help_open_frame = input.frame_index
		ui.controls_help_invoker_focus = uifw.GUI_ID_NONE
		ui.controls_help_modal_scroll = 0
	}
	controller_ui_action_shortcut := (slime_controller_ui_enabled(ui) || simulation_controller_ui_enabled(ui)) && input.actions.toggle_ui.pressed && input.actions.toggle_ui.owner == .Controller
	if ui.simulation_shell.force_hidden {
		if input.actions.toggle_ui.pressed && !controller_ui_action_shortcut {
			ui.simulation_shell.force_hidden = false
			ui.simulation_shell.show_ui = true
			app_ui_set_simulation_chrome_visible(ui, true)
			ui.simulation_shell.idle_seconds = 0
		} else {
			ui.simulation_shell.show_ui = false
			app_ui_set_simulation_chrome_visible(ui, false)
			ui.simulation_shell.idle_seconds = f32(max(ui.settings.auto_hide_delay, 0)) / 1000.0
			return
		}
	}
	reveal_activity := input.mouse_pressed ||
		input.mouse_released ||
		input.mouse_moved ||
		input.wheel_delta_x != 0 ||
		input.wheel_delta != 0 ||
		input.actions.help.pressed || input.actions.help.repeated ||
		input.actions.toggle_ui.pressed || input.actions.toggle_ui.repeated ||
		input.key_space ||
		input.actions.navigate.value.x != 0 || input.actions.navigate.value.y != 0 ||
		input.actions.navigate.pressed.x != 0 || input.actions.navigate.pressed.y != 0 ||
		input.actions.accept.pressed || input.actions.accept.repeated ||
		input.actions.back.pressed || input.actions.back.repeated
	reveal_activity = reveal_activity ||
		input.actions.control_deck.down ||
		input.actions.control_deck.pressed ||
		input.actions.control_deck.released
	if ui_engaged || reveal_activity {
		ui.simulation_shell.idle_seconds = 0
		if reveal_activity && !ui.simulation_shell.show_ui {
			app_ui_set_simulation_chrome_visible(ui, true)
		}
	} else {
		ui.simulation_shell.idle_seconds += input.delta_time
	}
	auto_hide_delay_seconds := f32(max(ui.settings.auto_hide_delay, 0)) / 1000.0
	if !ui_engaged &&
	   ui.simulation_shell.idle_seconds >= auto_hide_delay_seconds {
		app_ui_hide_unfocused_simulation_ui(ui)
	}
	if input.actions.toggle_ui.pressed && !controller_ui_action_shortcut {
		ui.simulation_shell.show_ui = !ui.simulation_shell.show_ui
		app_ui_set_simulation_chrome_visible(ui, true)
		ui.simulation_shell.idle_seconds = 0
	}
}

app_ui_system_cursor_hidden :: proc(ui: ^App_Ui_State) -> bool {
	return ui != nil &&
		app_ui_mode_is_simulation(ui.mode) &&
		!ui.simulation_shell.show_ui &&
		!ui.simulation_shell.controls_visible
}

app_ui_resolve_input_context :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, input: Ui_Frame_Input) -> App_Input_Context_Route {
	simulation_active := app_ui_mode_is_simulation(ui.mode)
	controller_ui_active := slime_controller_ui_enabled(ui) || simulation_controller_ui_enabled(ui)
	controller_ui_focused := (slime_controller_ui_enabled(ui) && ui.slime_controller.focus.phase != .Unfocused) || simulation_controller_ui_focused(ui)
	controller_pause_pressed := controller_ui_active && app_ui_action_pressed_by_controller(input.actions.pause)
	controller_toggle_pressed := controller_ui_active && input.actions.toggle_ui.pressed && input.actions.toggle_ui.owner == .Controller
	control_deck_claim := controller_ui_active && app_ui_control_deck_active(input.actions.control_deck)
	focus_entry_claim := controller_ui_active && (
		input.key_tab ||
		input.actions.focus_next.down || input.actions.focus_next.pressed || input.actions.focus_next.repeated || input.actions.focus_next.released ||
		input.actions.focus_prev.down || input.actions.focus_prev.pressed || input.actions.focus_prev.repeated || input.actions.focus_prev.released
	)
	controller_ui_claimed := controller_ui_active &&
		(controller_ui_focused || focus_entry_claim || control_deck_claim || controller_pause_pressed || controller_toggle_pressed)
	controller_ui_pointer_claim := controller_ui_active && (control_deck_claim || controller_pause_pressed || controller_toggle_pressed)

	modal_active := ui.controls_help_open || slime_controller_ui_modal_open(ui)
	edit_active := gui.text_edit_id != uifw.GUI_ID_NONE ||
		gui.focus_edit_id != uifw.GUI_ID_NONE ||
		gui.open_panel != uifw.GUI_ID_NONE ||
		gui.overlay_input_rect_count > 0
	focused_ui_active := gui.focused != uifw.GUI_ID_NONE || controller_ui_claimed

	active_context := App_Input_Context.Global_Fallback
	if simulation_active {
		active_context = .Simulation_Canvas
	}
	if focused_ui_active {
		active_context = .Focused_Ui
	}
	if edit_active {
		active_context = .Value_Edit
	}
	if modal_active {
		active_context = .Modal
	}

	width := f32(input.window_width)
	height := f32(input.window_height)
	bar_rect := app_ui_simulation_chrome_rect(ui, gui, ui.mode, width, height)
	menu_rect := app_ui_simulation_menu_panel(ui, gui, width, height)
	over_bar := simulation_active && ui.simulation_shell.controls_visible && uifw.gui_contains(bar_rect, input.mouse_pos)
	over_menu := simulation_active && ui.simulation_shell.show_ui && !controller_ui_active && uifw.gui_contains(menu_rect, input.mouse_pos)
	over_controller_ui := (slime_controller_ui_enabled(ui) && slime_controller_ui_over_ui(&ui.slime_controller, gui, input)) || simulation_controller_ui_over_ui(ui, gui, input)
	top_layer_open := modal_active || gui.overlay_input_rect_count > 0 || gui.open_panel != uifw.GUI_ID_NONE
	// An engaged editor owns the complete gesture until commit/cancel. This
	// prevents an outside release from both ending an edit and painting/panning
	// the simulation underneath it in the same frame.
	pointer_over_ui := over_bar || over_menu || over_controller_ui || top_layer_open || edit_active || controller_ui_pointer_claim

	base_owner := simulation_active ? App_Input_Context.Simulation_Canvas : App_Input_Context.Global_Fallback
	pointer_owner := base_owner
	if pointer_over_ui {
		pointer_owner = .Focused_Ui
		if edit_active {
			pointer_owner = .Value_Edit
		}
		if modal_active {
			pointer_owner = .Modal
		}
	}
	navigation_owner := base_owner
	if active_context >= .Focused_Ui {
		navigation_owner = active_context
	}
	keyboard_camera_owner := base_owner
	if active_context >= .Value_Edit {
		keyboard_camera_owner = active_context
	}
	controller_camera_owner := base_owner
	if active_context >= .Focused_Ui {
		controller_camera_owner = active_context
	}
	global_shortcut_owner := App_Input_Context.Global_Fallback
	if active_context >= .Value_Edit || controller_ui_claimed {
		global_shortcut_owner = active_context
	}

	return {
		active_context = active_context,
		pointer_owner = pointer_owner,
		navigation_owner = navigation_owner,
		keyboard_camera_owner = keyboard_camera_owner,
		controller_camera_owner = controller_camera_owner,
		global_shortcut_owner = global_shortcut_owner,
		pointer_over_ui = pointer_over_ui,
		controller_ui_claimed = controller_ui_claimed,
	}
}

app_ui_clear_global_shortcuts :: proc(input: ^Ui_Frame_Input) {
	input.key_space = false
	input.key_space_down = false
	input.key_space_pressed = false
	input.key_space_released = false
	input.actions.pause = {}
	input.actions.help = {}
	input.actions.toggle_ui = {}
	input.actions.control_deck = {}
}

app_ui_clear_gui_global_shortcuts :: proc(gui: ^uifw.Gui_Context) {
	gui.input.pause = false
	gui.input.toggle_ui = false
	gui.input.key_slash = false
	gui.input.key_space = false
	gui.input.key_space_down = false
	gui.input.key_space_pressed = false
	gui.input.key_space_released = false
}

app_ui_clear_navigation_input :: proc(input: ^Ui_Frame_Input) {
	input.canvas_tool_slot = 0
	input.text_input = {}
	input.text_input_len = 0
	input.clipboard_paste = {}
	input.clipboard_paste_len = 0
	input.key_tab = false
	input.key_enter = false
	input.key_escape = false
	input.key_backspace = false
	input.key_delete = false
	input.key_home = false
	input.key_end = false
	input.key_left = false
	input.key_right = false
	input.key_up = false
	input.key_down = false
	input.actions.navigate = {}
	input.actions.accept = {}
	input.actions.back = {}
	input.actions.focus_next = {}
	input.actions.focus_prev = {}
}

app_ui_clear_keyboard_camera_input :: proc(input: ^Ui_Frame_Input) {
	input.key_w = false
	input.key_a = false
	input.key_s = false
	input.key_d = false
	input.key_q = false
	input.key_e = false
	input.key_x = false
	input.key_v = false
	input.actions.camera_pan = {}
	input.actions.camera_zoom = 0
	input.actions.camera_reset = {}
}

app_ui_clear_controller_camera_input :: proc(input: ^Ui_Frame_Input) {
	input.controller_left = {}
	input.controller_zoom = 0
	// Navigation routing may already have removed arrow keys. Rebuild the
	// semantic camera axes from the keyboard controls that remain eligible.
	input.actions.camera_pan = {
		app_input_axis(input.key_right || input.key_d, input.key_left || input.key_a),
		app_input_axis(input.key_down || input.key_s, input.key_up || input.key_w),
	}
	input.actions.camera_zoom = app_input_axis(input.key_e, input.key_q)
	if input.actions.camera_reset.owner == .Controller {
		input.actions.camera_reset = {}
	}
	// Keyboard-owned reset remains eligible when only controller camera input is
	// filtered; ownership is carried by the semantic action itself.
}

app_ui_simulation_filter_input :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, input: Ui_Frame_Input) -> Ui_Frame_Input {
	ui.main_menu_quit_hold_highlight = ui.mode == .Main_Menu && (input.key_escape_down || input.controller_start_down)
	dismiss_help := ui.controls_help_open && input.actions.help.pressed
	if dismiss_help {app_ui_close_controls_help(ui, gui)}
	pan_chord_candidate := input.mouse_pressed &&
		(input.mouse_button == 2 || (input.mouse_button == 1 && input.camera_pan_modifier_down))
	routing_input := input
	if pan_chord_candidate {
		// Resolve the pointer hit before Space's shell/control-deck binding can
		// claim the same chord. Actual UI hit-testing still has priority.
		routing_input.key_space = false
		routing_input.key_space_down = false
		routing_input.key_space_pressed = false
		routing_input.actions.control_deck = {}
	}
	route := app_ui_resolve_input_context(ui, gui, routing_input)
	// A deliberate canvas click transfers ownership from keyboard/controller UI
	// navigation back to the simulation. Pointer motion alone never steals focus.
	if input.active_device == .Mouse_Keyboard &&
	   input.mouse_pressed &&
	   route.pointer_owner == .Simulation_Canvas &&
	   route.active_context < .Value_Edit {
		app_ui_hide_unfocused_simulation_ui(ui)
		gui.focused = uifw.GUI_ID_NONE
		route = app_ui_resolve_input_context(ui, gui, routing_input)
	}
	ui.input_route = route
	shell_input := input
	pan_gesture_started := pan_chord_candidate &&
		route.pointer_owner == .Simulation_Canvas &&
		!route.pointer_over_ui
	if pan_gesture_started {
		ui.simulation_shell.camera_pan_active = true
		// Space remains a standalone shortcut, but a same-frame Space+canvas drag
		// is an explicit camera gesture and must not also pause/open the deck.
		app_ui_clear_global_shortcuts(&shell_input)
		app_ui_clear_gui_global_shortcuts(gui)
	}
	if dismiss_help {
		shell_input.actions.help = {}
	}
	if route.global_shortcut_owner != .Global_Fallback {
		app_ui_clear_global_shortcuts(&shell_input)
		// Modal/edit contexts suppress shortcuts inside the GUI as well. A
		// focused controller deck claim only suppresses the shell fallback;
		// the GUI still needs the opening Space/Select/Pause event.
		if route.active_context >= .Value_Edit {
			app_ui_clear_gui_global_shortcuts(gui)
		}
	}
	ui_engaged := route.active_context >= .Focused_Ui || route.pointer_owner >= .Focused_Ui
	app_ui_simulation_shell_update(ui, shell_input, ui_engaged)
	if shell_input.actions.help.pressed && ui.controls_help_open {
		ui.controls_help_invoker_focus = gui.focused
		ui.controls_help_open_frame = gui.frame_index
	}
	// UI consumers still need the unfiltered semantic action frame even when
	// the shell/global fallback did not own a shortcut.
	ui.frame_actions = input.actions

	if !app_ui_mode_is_simulation(ui.mode) {
		filtered := input
		filtered.mouse_down = false
		filtered.mouse_pressed = false
		filtered.mouse_released = false
		filtered.camera_pan_down = false
		filtered.wheel_delta_x = 0
		filtered.wheel_delta = 0
		filtered.actions.primary = {}
		filtered.actions.secondary = {}
		ui.simulation_shell.mouse_pressed = false
		ui.simulation_shell.camera_pan_active = false
		return filtered
	}

	filtered := input
	if route.global_shortcut_owner != .Global_Fallback {
		app_ui_clear_global_shortcuts(&filtered)
	}
	if route.navigation_owner != .Simulation_Canvas {
		app_ui_clear_navigation_input(&filtered)
	}
	if route.keyboard_camera_owner != .Simulation_Canvas {
		app_ui_clear_keyboard_camera_input(&filtered)
	}
	if route.controller_camera_owner != .Simulation_Canvas {
		app_ui_clear_controller_camera_input(&filtered)
	}

	if input.mouse_pressed {
		ui.simulation_shell.mouse_pressed = !route.pointer_over_ui
		ui.simulation_shell.mouse_button = input.mouse_button
		if route.pointer_over_ui {
			filtered.mouse_pressed = false
			filtered.mouse_down = false
		}
	}
	gesture_owned := ui.simulation_shell.mouse_pressed
	camera_gesture_owned := ui.simulation_shell.camera_pan_active
	filtered.camera_pan_down = camera_gesture_owned && input.mouse_down
	if camera_gesture_owned {
		// Camera gestures own the pointer exclusively. The simulation never sees
		// their press/hold phases as primary or secondary interaction.
		filtered.mouse_down = false
		filtered.mouse_pressed = false
		filtered.mouse_released = false
		filtered.actions.primary = {}
		filtered.actions.secondary = {}
	}
	if !gesture_owned && route.pointer_over_ui {
		filtered.mouse_down = false
		filtered.mouse_pressed = false
		filtered.mouse_released = false
	}
	if route.pointer_over_ui {
		filtered.wheel_delta_x = 0
		filtered.wheel_delta = 0
	}
	if route.pointer_over_ui && !gesture_owned {
		filtered.actions.primary.down = filtered.mouse_down && filtered.mouse_button != 2 && filtered.mouse_button != 3
		filtered.actions.primary.pressed = filtered.mouse_pressed && filtered.mouse_button != 2 && filtered.mouse_button != 3
		filtered.actions.primary.released = filtered.mouse_released && filtered.mouse_button != 2 && filtered.mouse_button != 3
		filtered.actions.primary.repeated = false
		filtered.actions.secondary.down = filtered.mouse_down && filtered.mouse_button == 3
		filtered.actions.secondary.pressed = filtered.mouse_pressed && filtered.mouse_button == 3
		filtered.actions.secondary.released = filtered.mouse_released && filtered.mouse_button == 3
		filtered.actions.secondary.repeated = false
	}
	if input.mouse_released {
		ui.simulation_shell.mouse_pressed = false
		ui.simulation_shell.camera_pan_active = false
	}
	return filtered
}
