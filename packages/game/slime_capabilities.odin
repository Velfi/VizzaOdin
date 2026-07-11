package game

SLIME_CONTROL_INSTRUMENTS := [?]Control_Instrument_Descriptor {
	{instrument = .Presets, label = "Presets", icon = "bookmarks", description = "Load presets, respawn agents, or establish a new behavior."},
	{instrument = .Look, label = "Look", icon = "palette", description = "Palette, background, and post-processing."},
	{instrument = .Motion, label = "Agents", icon = "arrows-move", description = "Agent motion, steering, and sensing."},
	{instrument = .Field, label = "Trails", icon = "route", description = "Trail deposition, memory, and spread."},
	{instrument = .Brush, label = "Brush", icon = "brush", description = "Pointer interaction controls."},
	{instrument = .World, label = "World", icon = "world", description = "Initial placement and world masks."},
}

SLIME_CONTROL_DESCRIPTORS := [?]Control_Descriptor {
	SLIME_CONTROL_DESCRIPTOR_00,
	SLIME_CONTROL_DESCRIPTOR_01,
	SLIME_CONTROL_DESCRIPTOR_02,
	SLIME_CONTROL_DESCRIPTOR_03,
	SLIME_CONTROL_DESCRIPTOR_04,
	SLIME_CONTROL_DESCRIPTOR_05,
	SLIME_CONTROL_DESCRIPTOR_06,
	SLIME_CONTROL_DESCRIPTOR_07,
	SLIME_CONTROL_DESCRIPTOR_08,
	SLIME_CONTROL_DESCRIPTOR_09,
	SLIME_CONTROL_DESCRIPTOR_10,
	SLIME_CONTROL_DESCRIPTOR_11,
	SLIME_CONTROL_DESCRIPTOR_12,
	SLIME_CONTROL_DESCRIPTOR_13,
	SLIME_CONTROL_DESCRIPTOR_14,
	SLIME_CONTROL_DESCRIPTOR_15,
	SLIME_CONTROL_DESCRIPTOR_16,
	SLIME_CONTROL_DESCRIPTOR_17,
	SLIME_CONTROL_DESCRIPTOR_18,
	SLIME_CONTROL_DESCRIPTOR_19,
	SLIME_CONTROL_DESCRIPTOR_20,
	SLIME_CONTROL_DESCRIPTOR_21,
	SLIME_CONTROL_DESCRIPTOR_22,
	SLIME_CONTROL_DESCRIPTOR_23,
	SLIME_CONTROL_DESCRIPTOR_24,
	SLIME_CONTROL_DESCRIPTOR_25,
	SLIME_CONTROL_DESCRIPTOR_26,
	SLIME_CONTROL_DESCRIPTOR_27,
	SLIME_CONTROL_DESCRIPTOR_28,
	SLIME_CONTROL_DESCRIPTOR_29,
	SLIME_CONTROL_DESCRIPTOR_30,
	SLIME_CONTROL_DESCRIPTOR_31,
	SLIME_CONTROL_DESCRIPTOR_32,
	SLIME_CONTROL_DESCRIPTOR_33,
	SLIME_CONTROL_DESCRIPTOR_34,
	SLIME_CONTROL_DESCRIPTOR_35,
	SLIME_CONTROL_DESCRIPTOR_36,
	SLIME_CONTROL_DESCRIPTOR_37,
	SLIME_CONTROL_DESCRIPTOR_38,
	SLIME_CONTROL_DESCRIPTOR_39,
	SLIME_CONTROL_DESCRIPTOR_40,
	SLIME_CONTROL_DESCRIPTOR_41,
}


slime_control_descriptors :: proc() -> []Control_Descriptor {
	return SLIME_CONTROL_DESCRIPTORS[:]
}

slime_control_instruments :: proc() -> []Control_Instrument_Descriptor {
	return SLIME_CONTROL_INSTRUMENTS[:]
}

slime_control_descriptor_by_id :: proc(id: Control_Id) -> (Control_Descriptor, bool) {
	for desc in SLIME_CONTROL_DESCRIPTORS {
		if desc.id == id {
			return desc, true
		}
	}
	return {}, false
}

slime_control_instrument_descriptor :: proc(instrument: Control_Instrument) -> (Control_Instrument_Descriptor, bool) {
	for desc in SLIME_CONTROL_INSTRUMENTS {
		if desc.instrument == instrument {
			return desc, true
		}
	}
	return {}, false
}

slime_control_instrument_has_visible_controls :: proc(instrument: Control_Instrument, mode: Control_Ui_Mode) -> bool {
	for desc in SLIME_CONTROL_DESCRIPTORS {
		if desc.instrument == instrument && control_is_visible_for_mode(desc, mode) {
			return true
		}
	}
	return false
}

slime_control_visible_descriptor_count :: proc(mode: Control_Ui_Mode) -> int {
	count := 0
	for desc in SLIME_CONTROL_DESCRIPTORS {
		if control_is_visible_for_mode(desc, mode) {
			count += 1
		}
	}
	return count
}

slime_control_couch_validation_passes :: proc() -> bool {
	for desc in SLIME_CONTROL_DESCRIPTORS {
		if control_is_visible_in_couch_ui(desc) {
			if !control_descriptor_is_valid_for_visible_ui(desc) {
				return false
			}
			if control_is_broken_or_deprecated(desc) {
				return false
			}
			if desc.importance == .Developer || desc.importance == .Debug {
				return false
			}
		}
	}
	return true
}
