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
	Seed_Reaction,
	Erase_Reaction,
	Attract,
	Repel,
	Pluck,
	Shockwave,
	Paint_Sites,
	Erase_Sites,
	Deposit_Pheromone,
	Erase_Pheromone,
	Spawn_Agents,
	Remove_Agents,
	Add_Nutrient,
	Drain_Nutrient,
	Vortex_Clockwise,
	Vortex_Counterclockwise,
	Spawn_Particles,
	Remove_Particles,
	Grab,
	Release,
	Pull,
	Push,
	Impulse_Pull,
	Impulse_Push,
	Implode,
	Explode,
	Probe,
	Pin_Probe,
	Deflect_Clockwise,
	Deflect_Counterclockwise,
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
		set.tools[1] = {true, "Pheromone", "Deposit", "Erase", .Deposit_Pheromone, .Erase_Pheromone, .Brush}
		set.tools[2] = {true, "Agents", "Gather", "Disperse", .Spawn_Agents, .Remove_Agents, .Brush}
	case .Flow_Field:
		set.tools[0] = {true, "Particles", "Spawn", "Remove", .Spawn_Particles, .Remove_Particles, .Brush}
		set.tools[1] = {true, "Force", "Attract", "Repel", .Attract, .Repel, .Brush}
		set.tools[2] = {true, "Flow", "Clockwise", "Counterclockwise", .Vortex_Clockwise, .Vortex_Counterclockwise, .Brush}
	case .Pellets:
		set.tools[0] = {true, "Grab", "Grab", "Release", .Grab, .Release, .Manipulator}
		set.tools[1] = {true, "Gravity", "Attract", "Repel", .Pull, .Push, .Brush}
		set.tools[2] = {true, "Burst", "Implode", "Explode", .Implode, .Explode, .Stamp}
	case .Voronoi_CA:
		// Cardinal layout: left Magnet, up Sites, right Sculpt.
		set.tools[0] = {true, "Magnet", "Attract", "Repel", .Attract, .Repel, .Brush}
		set.tools[1] = {true, "Sites", "Paint", "Erase", .Paint_Sites, .Erase_Sites, .Brush}
		set.tools[2] = {true, "Sculpt", "Pluck", "Shockwave", .Pluck, .Shockwave, .Manipulator}
	case .Primordial:
		set.tools[0] = {true, "Impulse", "Pull", "Push", .Impulse_Pull, .Impulse_Push, .Manipulator}
		set.tools[1] = {true, "Vortex", "Clockwise", "Counterclockwise", .Vortex_Clockwise, .Vortex_Counterclockwise, .Brush}
	case .Vectors:
		set.tools[0] = {true, "Probe", "Inspect", "Pin", .Probe, .Pin_Probe, .Probe}
		set.tools[1] = {true, "Deflect", "Clockwise", "Counterclockwise", .Deflect_Clockwise, .Deflect_Counterclockwise, .Brush}
	case:
	}
	return set
}

canvas_tool_set_for_mode :: proc(mode: App_Mode) -> Canvas_Tool_Set {
	set: Canvas_Tool_Set
	#partial switch mode {
	case .Gray_Scott:
		set.tools[0] = {true, "Reaction", "Seed", "Erase", .Seed_Reaction, .Erase_Reaction, .Brush}
		set.tools[1] = {true, "Nutrient", "Add", "Drain", .Add_Nutrient, .Drain_Nutrient, .Brush}
	case .Particle_Life:
		set.tools[0] = {true, "Gravity", "Attract", "Repel", .Attract, .Repel, .Brush}
		set.tools[1] = {true, "Vortex", "Clockwise", "Counterclockwise", .Vortex_Clockwise, .Vortex_Counterclockwise, .Brush}
	case .Slime_Mold: return canvas_tool_set_for_kind(.Slime_Mold)
	case .Flow_Field: return canvas_tool_set_for_kind(.Flow_Field)
	case .Pellets: return canvas_tool_set_for_kind(.Pellets)
	case .Voronoi_CA: return canvas_tool_set_for_kind(.Voronoi_CA)
	case .Primordial: return canvas_tool_set_for_kind(.Primordial)
	case .Vectors: return canvas_tool_set_for_kind(.Vectors)
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
	if input.actions.navigate.pressed.x < -0.5 {target = 0}
	if input.actions.navigate.pressed.y < -0.5 {target = 1}
	if input.actions.navigate.pressed.x > 0.5 {target = 2}
	if input.actions.navigate.pressed.y > 0.5 {target = 3}
	if target >= 0 && set.tools[target].valid && target != state.selected_slot {
		state.previous_slot = state.selected_slot
		state.selected_slot = target
		state.changed = true
	}
}

canvas_tool_action_for_input :: proc(tool: ^Canvas_Tool_Descriptor, secondary: bool) -> Canvas_Tool_Action {
	return secondary ? tool.secondary_action : tool.primary_action
}

canvas_tool_interaction_mode :: proc(tool: ^Canvas_Tool_Descriptor, secondary: bool) -> u32 {
	if tool == nil {return 0}
	action := canvas_tool_action_for_input(tool, secondary)
	#partial switch action {
	case .Attract, .Spawn_Particles, .Grab, .Impulse_Pull: return 1
	case .Repel, .Remove_Particles, .Release, .Impulse_Push: return 2
	case .Add_Nutrient, .Deposit_Pheromone, .Vortex_Clockwise, .Pull, .Probe: return 3
	case .Drain_Nutrient, .Erase_Pheromone, .Vortex_Counterclockwise, .Push, .Pin_Probe: return 4
	case .Spawn_Agents, .Implode, .Deflect_Clockwise: return 5
	case .Remove_Agents, .Explode, .Deflect_Counterclockwise: return 6
	case:
	}
	return 0
}
