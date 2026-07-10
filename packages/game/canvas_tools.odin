package game

Canvas_Tool_Gesture :: enum u8 {
	Brush,
	Manipulator,
	Stamp,
	Probe,
	Placement,
}

Canvas_Tool_Action :: enum u8 {
	None,
	Attract,
	Repel,
	Pluck,
	Shockwave,
	Paint_Sites,
	Erase_Sites,
}

Canvas_Tool_Descriptor :: struct {
	valid: bool,
	name: string,
	primary_label: string,
	secondary_label: string,
	primary_action: Canvas_Tool_Action,
	secondary_action: Canvas_Tool_Action,
	gesture: Canvas_Tool_Gesture,
}

Canvas_Tool_State :: struct {
	selected_slot: int,
	previous_slot: int,
	changed: bool,
}

Canvas_Tool_Set :: struct {
	tools: [4]Canvas_Tool_Descriptor,
}

canvas_tool_set_for_kind :: proc(kind: Remaining_Sim_Kind) -> Canvas_Tool_Set {
	set: Canvas_Tool_Set
	#partial switch kind {
	case .Slime_Mold:
		set.tools[0] = {true, "Influence", "Attract", "Repel", .Attract, .Repel, .Brush}
	case .Flow_Field:
		set.tools[0] = {true, "Particles", "Spawn", "Remove", .None, .None, .Brush}
	case .Pellets:
		set.tools[0] = {true, "Manipulate", "Grab", "Black Hole", .None, .None, .Manipulator}
	case .Voronoi_CA:
		// Cardinal layout: left Magnet, up Sites, right Sculpt.
		set.tools[0] = {true, "Magnet", "Attract", "Repel", .Attract, .Repel, .Brush}
		set.tools[1] = {true, "Sites", "Paint", "Erase", .Paint_Sites, .Erase_Sites, .Brush}
		set.tools[2] = {true, "Sculpt", "Pluck", "Shockwave", .Pluck, .Shockwave, .Manipulator}
	case .Primordial:
		set.tools[0] = {true, "Impulse", "Fling", "Pull", .None, .None, .Manipulator}
	case:
	}
	return set
}

canvas_tool_set_for_mode :: proc(mode: App_Mode) -> Canvas_Tool_Set {
	set: Canvas_Tool_Set
	#partial switch mode {
	case .Gray_Scott:
		set.tools[0] = {true, "Reaction", "Seed", "Erase", .None, .None, .Brush}
	case .Particle_Life:
		set.tools[0] = {true, "Gravity", "Attract", "Repel", .Attract, .Repel, .Brush}
	case .Slime_Mold: return canvas_tool_set_for_kind(.Slime_Mold)
	case .Flow_Field: return canvas_tool_set_for_kind(.Flow_Field)
	case .Pellets: return canvas_tool_set_for_kind(.Pellets)
	case .Voronoi_CA: return canvas_tool_set_for_kind(.Voronoi_CA)
	case .Primordial: return canvas_tool_set_for_kind(.Primordial)
	case:
	}
	return set
}

canvas_tool_selected :: proc(set: ^Canvas_Tool_Set, state: ^Canvas_Tool_State) -> ^Canvas_Tool_Descriptor {
	state.selected_slot = max(min(state.selected_slot, len(set.tools) - 1), 0)
	if !set.tools[state.selected_slot].valid {
		for tool, index in set.tools {
			if tool.valid {state.selected_slot = index; break}
		}
	}
	return &set.tools[state.selected_slot]
}

canvas_tool_update_selection :: proc(set: ^Canvas_Tool_Set, state: ^Canvas_Tool_State, input: Ui_Frame_Input) {
	state.changed = false
	target := -1
	if input.canvas_tool_slot >= 1 && input.canvas_tool_slot <= 4 {
		target = int(input.canvas_tool_slot - 1)
	}
	if input.nav_pressed_x < -0.5 {target = 0}
	if input.nav_pressed_y < -0.5 {target = 1}
	if input.nav_pressed_x > 0.5 {target = 2}
	if input.nav_pressed_y > 0.5 {target = 3}
	if target >= 0 && set.tools[target].valid && target != state.selected_slot {
		state.previous_slot = state.selected_slot
		state.selected_slot = target
		state.changed = true
	}
}

canvas_tool_action_for_input :: proc(tool: ^Canvas_Tool_Descriptor, secondary: bool) -> Canvas_Tool_Action {
	return secondary ? tool.secondary_action : tool.primary_action
}
