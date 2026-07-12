package game

import uifw "../ui"

import "core:math"

app_input_axis :: proc(positive, negative: bool) -> f32 {
	value := f32(0)
	if positive {value += 1}
	if negative {value -= 1}
	return value
}

app_controller_south_is_accept :: proc(settings: App_Settings) -> bool {
	return settings.controller_face_layout != "East Accept"
}

app_controller_start_is_pause :: proc(settings: App_Settings) -> bool {
	return settings.controller_menu_layout != "View Pauses"
}

app_controller_right_shoulder_is_next :: proc(settings: App_Settings) -> bool {
	return settings.controller_shoulder_layout != "Left Next"
}

app_controller_right_trigger_is_primary :: proc(settings: App_Settings) -> bool {
	return settings.controller_trigger_layout != "Left Primary"
}

// The event loop resolves physical inputs into these stable semantic actions.
// Simulation focus ownership and controller shortcuts consume this frame as
// their authoritative route; raw key/button fields remain only for widgets and
// canvas gestures that have no semantic action.
Input_Action_Source :: enum u8 {
	None,
	Mouse_Keyboard,
	Controller,
}

Input_Action_Button_State :: struct {
	down: bool,
	pressed: bool,
	repeated: bool,
	released: bool,
	owner: Input_Action_Source,
}

Input_Action_Axis_2D_State :: struct {
	value: uifw.Vec2,
	pressed: uifw.Vec2,
	repeated: uifw.Vec2,
}

Input_Action_Frame :: struct {
	navigate: Input_Action_Axis_2D_State,
	accept: Input_Action_Button_State,
	back: Input_Action_Button_State,
	pause: Input_Action_Button_State,
	help: Input_Action_Button_State,
	toggle_ui: Input_Action_Button_State,
	control_deck: Input_Action_Button_State,
	focus_next: Input_Action_Button_State,
	focus_prev: Input_Action_Button_State,
	primary: Input_Action_Button_State,
	secondary: Input_Action_Button_State,
	camera_reset: Input_Action_Button_State,
	camera_pan: uifw.Vec2,
	camera_zoom: f32,
}

Input_Action_Button_Raw :: struct {
	mouse_keyboard_down: bool,
	controller_down: bool,
	mouse_keyboard_pressed: bool,
	controller_pressed: bool,
	mouse_keyboard_repeated: bool,
	controller_repeated: bool,
	mouse_keyboard_released: bool,
	controller_released: bool,
}

Input_Action_Release_Pulses :: struct {
	accept: bool,
	back: bool,
	pause: bool,
	help: bool,
	toggle_ui: bool,
	control_deck: bool,
	focus_next: bool,
	focus_prev: bool,
	primary: bool,
	secondary: bool,
	camera_reset: bool,
}

Input_Action_Button_Resolver :: struct {
	down: bool,
	owner: Input_Action_Source,
	mouse_keyboard_down: bool,
	controller_down: bool,
}

Input_Action_Axis_Repeat_State :: struct {
	direction: i8,
	held_seconds: f32,
	next_repeat_seconds: f32,
}

Input_Action_Resolver :: struct {
	accept: Input_Action_Button_Resolver,
	back: Input_Action_Button_Resolver,
	pause: Input_Action_Button_Resolver,
	help: Input_Action_Button_Resolver,
	toggle_ui: Input_Action_Button_Resolver,
	control_deck: Input_Action_Button_Resolver,
	focus_next: Input_Action_Button_Resolver,
	focus_prev: Input_Action_Button_Resolver,
	primary: Input_Action_Button_Resolver,
	secondary: Input_Action_Button_Resolver,
	camera_reset: Input_Action_Button_Resolver,
	navigate_x: Input_Action_Axis_Repeat_State,
	navigate_y: Input_Action_Axis_Repeat_State,
}

INPUT_ACTION_NAV_THRESHOLD :: f32(0.50)
INPUT_ACTION_REPEAT_DELAY :: f32(0.35)
INPUT_ACTION_REPEAT_INTERVAL :: f32(0.09)

input_action_source_for_press :: proc(raw: Input_Action_Button_Raw) -> Input_Action_Source {
	if raw.controller_pressed || (raw.controller_down && !raw.mouse_keyboard_down) {
		return .Controller
	}
	if raw.mouse_keyboard_pressed || raw.mouse_keyboard_down {
		return .Mouse_Keyboard
	}
	return .None
}

input_action_source_pressed :: proc(raw: Input_Action_Button_Raw, source: Input_Action_Source) -> bool {
	switch source {
	case .Mouse_Keyboard:
		return raw.mouse_keyboard_pressed
	case .Controller:
		return raw.controller_pressed
	case .None:
		return false
	}
	return false
}

input_action_source_released :: proc(raw: Input_Action_Button_Raw, source: Input_Action_Source) -> bool {
	switch source {
	case .Mouse_Keyboard:
		return raw.mouse_keyboard_released
	case .Controller:
		return raw.controller_released
	case .None:
		return false
	}
	return false
}

input_action_source_repeated :: proc(raw: Input_Action_Button_Raw, source: Input_Action_Source) -> bool {
	switch source {
	case .Mouse_Keyboard:
		return raw.mouse_keyboard_repeated
	case .Controller:
		return raw.controller_repeated
	case .None:
		return false
	}
	return false
}

input_action_other_source_contributed :: proc(
	state: ^Input_Action_Button_Resolver,
	raw: Input_Action_Button_Raw,
	owner: Input_Action_Source,
) -> bool {
	switch owner {
	case .Mouse_Keyboard:
		return state.controller_down || raw.controller_down || raw.controller_pressed || raw.controller_released
	case .Controller:
		return state.mouse_keyboard_down || raw.mouse_keyboard_down || raw.mouse_keyboard_pressed || raw.mouse_keyboard_released
	case .None:
		return false
	}
	return false
}

// A second device cannot create another press while the same semantic action
// is held. Ownership stays latched until every contributing source releases.
input_action_resolve_button :: proc(state: ^Input_Action_Button_Resolver, raw: Input_Action_Button_Raw) -> Input_Action_Button_State {
	down := raw.mouse_keyboard_down || raw.controller_down
	press_observed := raw.mouse_keyboard_pressed || raw.controller_pressed
	// A release+repress may be coalesced into one input frame. Treat it as a
	// second activation only when the latched owner itself cycled and no other
	// source contributed to the still-held semantic action. In particular, a
	// fast controller tap cannot re-own Accept while keyboard Enter is held.
	retriggered := state.down &&
		input_action_source_pressed(raw, state.owner) &&
		input_action_source_released(raw, state.owner) &&
		!input_action_other_source_contributed(state, raw, state.owner)
	pressed := (!state.down && (down || press_observed)) || retriggered
	repeated := state.down && down && input_action_source_repeated(raw, state.owner)
	released := (state.down && !down) || retriggered
	owner := state.owner
	if pressed && !state.down {
		owner = input_action_source_for_press(raw)
	}

	// A full tap can arrive between two rendered frames. Preserve both phases
	// rather than dropping the action because its final physical state is up.
	if pressed && !down {
		released = true
	}

	state.down = down
	state.mouse_keyboard_down = raw.mouse_keyboard_down
	state.controller_down = raw.controller_down
	if down {
		state.owner = owner
	} else {
		state.owner = .None
	}

	return {
		down = down,
		pressed = pressed,
		repeated = repeated,
		released = released,
		owner = owner,
	}
}

input_action_axis_direction :: proc(value, threshold: f32) -> i8 {
	if value >= threshold {
		return 1
	}
	if value <= -threshold {
		return -1
	}
	return 0
}

input_action_resolve_axis_repeat :: proc(
	state: ^Input_Action_Axis_Repeat_State,
	value, delta_time: f32,
	threshold := INPUT_ACTION_NAV_THRESHOLD,
	delay := INPUT_ACTION_REPEAT_DELAY,
	interval := INPUT_ACTION_REPEAT_INTERVAL,
) -> (pressed, repeated: f32) {
	direction := input_action_axis_direction(value, threshold)
	if direction == 0 {
		state^ = {}
		return 0, 0
	}

	if direction != state.direction {
		state.direction = direction
		state.held_seconds = 0
		state.next_repeat_seconds = max(delay, 0)
		return f32(direction), 0
	}

	state.held_seconds += max(delta_time, 0)
	if state.held_seconds < state.next_repeat_seconds {
		return 0, 0
	}

	repeat_interval := max(interval, 0.001)
	for state.next_repeat_seconds <= state.held_seconds {
		state.next_repeat_seconds += repeat_interval
	}
	return 0, f32(direction)
}

input_action_resolve_navigation :: proc(
	resolver: ^Input_Action_Resolver,
	value: uifw.Vec2,
	delta_time: f32,
	delay := INPUT_ACTION_REPEAT_DELAY,
	interval := INPUT_ACTION_REPEAT_INTERVAL,
) -> Input_Action_Axis_2D_State {
	pressed_x, repeated_x := input_action_resolve_axis_repeat(&resolver.navigate_x, value.x, delta_time, delay = delay, interval = interval)
	pressed_y, repeated_y := input_action_resolve_axis_repeat(&resolver.navigate_y, value.y, delta_time, delay = delay, interval = interval)
	return {
		value = value,
		pressed = {pressed_x, pressed_y},
		repeated = {repeated_x, repeated_y},
	}
}


// Sticks use a circular deadzone so diagonal motion has the same activation
// radius as cardinal motion. The remaining magnitude is rescaled to [0, 1].
input_action_apply_radial_deadzone :: proc(value: uifw.Vec2, deadzone: f32) -> uifw.Vec2 {
	deadzone_clamped := min(max(deadzone, 0), 0.9999)
	magnitude_squared := value.x * value.x + value.y * value.y
	if magnitude_squared <= deadzone_clamped * deadzone_clamped {
		return {}
	}
	magnitude := f32(math.sqrt(f64(magnitude_squared)))
	if magnitude <= 0 {
		return {}
	}
	clamped_magnitude := min(magnitude, 1)
	scaled_magnitude := (clamped_magnitude - deadzone_clamped) / max(1 - deadzone_clamped, 0.0001)
	scale := scaled_magnitude / magnitude
	return {value.x * scale, value.y * scale}
}
