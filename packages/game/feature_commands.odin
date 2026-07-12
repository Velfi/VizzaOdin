package game

import "core:mem"

FEATURE_COMMAND_PAYLOAD_CAPACITY :: 4096
FEATURE_COMMAND_SCHEMA_VERSION :: u16(1)

Feature_Command_Id :: distinct u32

FEATURE_COMMAND_APPLY_SETTINGS :: Feature_Command_Id(1)
FEATURE_COMMAND_RESET          :: Feature_Command_Id(2)
FEATURE_COMMAND_APPLY_PRESET   :: Feature_Command_Id(3)
FEATURE_COMMAND_SET_COLOR      :: Feature_Command_Id(4)
FEATURE_COMMAND_LOAD_IMAGE     :: Feature_Command_Id(5)
FEATURE_COMMAND_CLEAR_IMAGE    :: Feature_Command_Id(6)
FEATURE_COMMAND_PRESET_FILE    :: Feature_Command_Id(7)

Feature_Command_Payload :: struct #align(16) {
	bytes: [FEATURE_COMMAND_PAYLOAD_CAPACITY]u8,
}

Feature_Command :: struct {
	feature_id: Feature_Id,
	command_id: Feature_Command_Id,
	schema_version: u16,
	payload_size: u16,
	payload_alignment: u16,
	payload: Feature_Command_Payload,
}

Feature_Command_Schema :: struct {
	feature_id: Feature_Id,
	command_id: Feature_Command_Id,
	schema_version: u16,
	payload_size: u16,
	payload_alignment: u16,
}

Feature_Result_Error :: enum u8 {
	None,
	Unknown_Feature,
	Unknown_Command,
	Version_Mismatch,
	Size_Mismatch,
	Alignment_Mismatch,
	Wrong_Mode,
	Stale_Result,
	Shutting_Down,
	Dispatch_Failed,
}

Feature_Result :: struct {
	success: bool,
	error: Feature_Result_Error,
	feature_id: Feature_Id,
	command_id: Feature_Command_Id,
	message: [MAX_ERROR_TEXT]u8,
	dialog: Feature_Platform_Dialog_Request,
}

Feature_Platform_Dialog_Kind :: enum u8 {
	None,
	Open_Image,
}

Feature_Platform_Dialog_Request :: struct {
	kind: Feature_Platform_Dialog_Kind,
	request_id: u64,
	feature_id: Feature_Id,
	slot: u16,
}

Feature_Preset_Command :: struct {
	index: i32,
}

Feature_Reset_Command :: struct {
	randomize: bool,
	seed_noise: bool,
	single_step: bool,
	undo_field: bool,
}

Feature_Color_Command :: struct {
	name: Color_Scheme_Name,
	reversed: bool,
	reversed_set: bool,
}

Feature_Image_Command :: struct {
	path: [MAX_FILE_PATH]u8,
	slot: u16,
	dialog_request_id: u64,
}

Feature_Preset_File_Operation :: enum u8 {
	Load,
	Save,
	Delete,
}

Feature_Preset_File_Command :: struct {
	operation: Feature_Preset_File_Operation,
	path: [MAX_PRESET_NAME]u8,
}

Feature_Image_Target :: enum u8 {
	Gray_Scott_Nutrient,
	Vectors,
	Moire,
	Flow,
	Slime_Mask,
	Slime_Position,
}

FEATURE_COMMAND_SCHEMAS := [?]Feature_Command_Schema {
	feature_command_schema(FEATURE_ID_SLIME_MOLD, FEATURE_COMMAND_RESET, Feature_Reset_Command),
	feature_command_schema(FEATURE_ID_GRAY_SCOTT, FEATURE_COMMAND_RESET, Feature_Reset_Command),
	feature_command_schema(FEATURE_ID_PARTICLE_LIFE, FEATURE_COMMAND_RESET, Feature_Reset_Command),
	feature_command_schema(FEATURE_ID_FLOW_FIELD, FEATURE_COMMAND_RESET, Feature_Reset_Command),
	feature_command_schema(FEATURE_ID_PELLETS, FEATURE_COMMAND_RESET, Feature_Reset_Command),
	feature_command_schema(FEATURE_ID_VORONOI, FEATURE_COMMAND_RESET, Feature_Reset_Command),
	feature_command_schema(FEATURE_ID_MOIRE, FEATURE_COMMAND_RESET, Feature_Reset_Command),
	feature_command_schema(FEATURE_ID_VECTORS, FEATURE_COMMAND_RESET, Feature_Reset_Command),
	feature_command_schema(FEATURE_ID_PRIMORDIAL, FEATURE_COMMAND_RESET, Feature_Reset_Command),
	feature_command_schema(FEATURE_ID_SLIME_MOLD, FEATURE_COMMAND_SET_COLOR, Feature_Color_Command),
	feature_command_schema(FEATURE_ID_GRAY_SCOTT, FEATURE_COMMAND_SET_COLOR, Feature_Color_Command),
	feature_command_schema(FEATURE_ID_PARTICLE_LIFE, FEATURE_COMMAND_SET_COLOR, Feature_Color_Command),
	feature_command_schema(FEATURE_ID_FLOW_FIELD, FEATURE_COMMAND_SET_COLOR, Feature_Color_Command),
	feature_command_schema(FEATURE_ID_PELLETS, FEATURE_COMMAND_SET_COLOR, Feature_Color_Command),
	feature_command_schema(FEATURE_ID_VORONOI, FEATURE_COMMAND_SET_COLOR, Feature_Color_Command),
	feature_command_schema(FEATURE_ID_MOIRE, FEATURE_COMMAND_SET_COLOR, Feature_Color_Command),
	feature_command_schema(FEATURE_ID_VECTORS, FEATURE_COMMAND_SET_COLOR, Feature_Color_Command),
	feature_command_schema(FEATURE_ID_PRIMORDIAL, FEATURE_COMMAND_SET_COLOR, Feature_Color_Command),
	feature_command_schema(FEATURE_ID_SLIME_MOLD, FEATURE_COMMAND_APPLY_PRESET, Feature_Preset_Command),
	feature_command_schema(FEATURE_ID_GRAY_SCOTT, FEATURE_COMMAND_APPLY_PRESET, Feature_Preset_Command),
	feature_command_schema(FEATURE_ID_PARTICLE_LIFE, FEATURE_COMMAND_APPLY_PRESET, Feature_Preset_Command),
	feature_command_schema(FEATURE_ID_FLOW_FIELD, FEATURE_COMMAND_APPLY_PRESET, Feature_Preset_Command),
	feature_command_schema(FEATURE_ID_PELLETS, FEATURE_COMMAND_APPLY_PRESET, Feature_Preset_Command),
	feature_command_schema(FEATURE_ID_VORONOI, FEATURE_COMMAND_APPLY_PRESET, Feature_Preset_Command),
	feature_command_schema(FEATURE_ID_MOIRE, FEATURE_COMMAND_APPLY_PRESET, Feature_Preset_Command),
	feature_command_schema(FEATURE_ID_VECTORS, FEATURE_COMMAND_APPLY_PRESET, Feature_Preset_Command),
	feature_command_schema(FEATURE_ID_PRIMORDIAL, FEATURE_COMMAND_APPLY_PRESET, Feature_Preset_Command),
	feature_command_schema(FEATURE_ID_GRAY_SCOTT, FEATURE_COMMAND_LOAD_IMAGE, Feature_Image_Command),
	feature_command_schema(FEATURE_ID_VECTORS, FEATURE_COMMAND_LOAD_IMAGE, Feature_Image_Command),
	feature_command_schema(FEATURE_ID_MOIRE, FEATURE_COMMAND_LOAD_IMAGE, Feature_Image_Command),
	feature_command_schema(FEATURE_ID_FLOW_FIELD, FEATURE_COMMAND_LOAD_IMAGE, Feature_Image_Command),
	feature_command_schema(FEATURE_ID_SLIME_MOLD, FEATURE_COMMAND_LOAD_IMAGE, Feature_Image_Command),
	feature_command_schema(FEATURE_ID_GRAY_SCOTT, FEATURE_COMMAND_CLEAR_IMAGE, Feature_Image_Command),
	feature_command_schema(FEATURE_ID_VECTORS, FEATURE_COMMAND_CLEAR_IMAGE, Feature_Image_Command),
	feature_command_schema(FEATURE_ID_MOIRE, FEATURE_COMMAND_CLEAR_IMAGE, Feature_Image_Command),
	feature_command_schema(FEATURE_ID_FLOW_FIELD, FEATURE_COMMAND_CLEAR_IMAGE, Feature_Image_Command),
	feature_command_schema(FEATURE_ID_SLIME_MOLD, FEATURE_COMMAND_CLEAR_IMAGE, Feature_Image_Command),
	feature_command_schema(FEATURE_ID_SLIME_MOLD, FEATURE_COMMAND_PRESET_FILE, Feature_Preset_File_Command),
	feature_command_schema(FEATURE_ID_GRAY_SCOTT, FEATURE_COMMAND_PRESET_FILE, Feature_Preset_File_Command),
	feature_command_schema(FEATURE_ID_PARTICLE_LIFE, FEATURE_COMMAND_PRESET_FILE, Feature_Preset_File_Command),
	feature_command_schema(FEATURE_ID_FLOW_FIELD, FEATURE_COMMAND_PRESET_FILE, Feature_Preset_File_Command),
	feature_command_schema(FEATURE_ID_PELLETS, FEATURE_COMMAND_PRESET_FILE, Feature_Preset_File_Command),
	feature_command_schema(FEATURE_ID_VORONOI, FEATURE_COMMAND_PRESET_FILE, Feature_Preset_File_Command),
	feature_command_schema(FEATURE_ID_MOIRE, FEATURE_COMMAND_PRESET_FILE, Feature_Preset_File_Command),
	feature_command_schema(FEATURE_ID_VECTORS, FEATURE_COMMAND_PRESET_FILE, Feature_Preset_File_Command),
	feature_command_schema(FEATURE_ID_PRIMORDIAL, FEATURE_COMMAND_PRESET_FILE, Feature_Preset_File_Command),
}

feature_command_schema :: proc "contextless" (feature_id: Feature_Id, command_id: Feature_Command_Id, $T: typeid) -> Feature_Command_Schema {
	#assert(size_of(T) <= FEATURE_COMMAND_PAYLOAD_CAPACITY)
	#assert(align_of(T) <= align_of(Feature_Command_Payload))
	return {feature_id, command_id, FEATURE_COMMAND_SCHEMA_VERSION, u16(size_of(T)), u16(align_of(T))}
}

feature_command_schema_find :: proc(feature_id: Feature_Id, command_id: Feature_Command_Id) -> (Feature_Command_Schema, bool) {
	if command_id == FEATURE_COMMAND_APPLY_SETTINGS {
		if descriptor, ok := feature_descriptor_by_id(feature_id); ok && descriptor.settings_size > 0 && descriptor.settings_size <= FEATURE_COMMAND_PAYLOAD_CAPACITY && descriptor.settings_alignment <= align_of(Feature_Command_Payload) {
			return {feature_id, command_id, FEATURE_COMMAND_SCHEMA_VERSION, u16(descriptor.settings_size), u16(descriptor.settings_alignment)}, true
		}
	}
	for _, i in FEATURE_COMMAND_SCHEMAS {
		schema := &FEATURE_COMMAND_SCHEMAS[i]
		if schema.feature_id == feature_id && schema.command_id == command_id {
			return schema^, true
		}
	}
	return {}, false
}

feature_command_validate :: proc(command: ^Feature_Command) -> Feature_Result_Error {
	if command == nil {
		return .Unknown_Command
	}
	if _, ok := feature_descriptor_by_id(command.feature_id); !ok {
		return .Unknown_Feature
	}
	schema, ok := feature_command_schema_find(command.feature_id, command.command_id)
	if !ok {
		return .Unknown_Command
	}
	if command.schema_version != schema.schema_version {
		return .Version_Mismatch
	}
	if command.payload_size != schema.payload_size {
		return .Size_Mismatch
	}
	if command.payload_alignment != schema.payload_alignment {
		return .Alignment_Mismatch
	}
	return .None
}

feature_command_make :: proc(feature_id: Feature_Id, command_id: Feature_Command_Id, value: ^$T) -> (Feature_Command, bool) {
	command: Feature_Command
	schema, ok := feature_command_schema_find(feature_id, command_id)
	if !ok || value == nil || int(schema.payload_size) != size_of(T) || int(schema.payload_alignment) != align_of(T) {
		return command, false
	}
	command.feature_id = feature_id
	command.command_id = command_id
	command.schema_version = schema.schema_version
	command.payload_size = schema.payload_size
	command.payload_alignment = schema.payload_alignment
	copy(command.payload.bytes[:int(command.payload_size)], mem.byte_slice(rawptr(value), int(command.payload_size)))
	return command, true
}

feature_command_payload :: proc(command: ^Feature_Command, $T: typeid) -> (^T, bool) {
	if feature_command_validate(command) != .None || int(command.payload_size) != size_of(T) || int(command.payload_alignment) != align_of(T) {
		return nil, false
	}
	return cast(^T)&command.payload.bytes[0], true
}
