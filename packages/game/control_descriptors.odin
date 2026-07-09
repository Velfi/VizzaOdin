package game

Control_Type :: enum {
	Bool,
	Enum,
	Int,
	Float,
	Action,
	Path,
	Color,
	Vec2,
}

Control_Unit :: enum {
	None,
	Normalized,
	Pixels,
	World,
	Radians,
	Degrees,
	Frames,
	FPS,
	Seconds,
	Milliseconds,
	Percent,
}

Semantic_Group :: enum {
	Application,
	Playback,
	Presets,
	Capture,
	Camera,
	Palette,
	Rendering,
	PostProcessing,
	Brush,
	World,
	Initialization,
	Entities,
	Agents,
	Motion,
	Sensing,
	Field,
	Mask,
	ImageSource,
	Noise,
	Reaction,
	Solver,
	Constraints,
	Analysis,
	Pattern,
	InteractionMatrix,
	Developer,
}

Feel_Group :: enum {
	Play,
	Look,
	Touch,
	Motion,
	Awareness,
	Memory,
	Spread,
	Birth,
	World,
	Source,
	Capture,
	Debug,
}

Reuse_Level :: enum {
	Universal,
	Common,
	Occasional,
	Unique,
	Deprecated,
	DeveloperOnly,
}

Importance :: enum {
	Essential,
	Common,
	Advanced,
	Expert,
	Developer,
	Debug,
}

Frequency :: enum {
	Constant,
	PerSession,
	Frequently,
	Continuously,
}

Scope :: enum {
	Global,
	SharedSimulation,
	Rendering,
	PostProcessing,
	SimulationSpecific,
	Developer,
}

Preset_Scope :: enum {
	No,
	Behavior,
	Look,
	Both,
	Maybe,
}

Runtime_Apply_Policy :: enum {
	LiveUniform,
	LiveCpuState,
	ReloadImageSource,
	ClearAccumulation,
	RegenerateEntities,
	RecreateGpuResources,
	ResetSimulation,
	RestartApp,
	ActionOnly,
	NoEffectDeprecated,
}

Wiring_Status :: enum {
	FullyWired,
	PartiallyWired,
	ExposedIneffective,
	CodeOnly,
	LegacyOnly,
	Disabled,
	Deprecated,
}

UI_Hint :: enum {
	Button,
	Toggle,
	Slider,
	Knob,
	BigKnob,
	TwoAxisPad,
	RadialCone,
	CardGrid,
	Carousel,
	TextInput,
	FilePicker,
	Hidden,
}

Controller_Hint :: enum {
	Primary,
	Secondary,
	HoldAdjust,
	DPadAdjust,
	StickAdjust,
	ShoulderCycle,
	AdvancedOnly,
	DeveloperOnly,
}

Control_Ui_Mode :: enum {
	Couch,
	Advanced,
	Developer,
}

Control_Instrument :: enum {
	Play,
	Look,
	Brush,
	Motion,
	Awareness,
	Field,
	Birth,
	World,
	Source,
	Capture,
	Debug,
}

Control_Id :: enum {
	Playback_Paused,
	Playback_Reset,
	Playback_Clear_Accumulation,
	Playback_Randomize,
	Palette_Name,
	Palette_Reversed,
	Render_Background_Mode,
	Post_Blur_Enabled,
	Post_Blur_Radius,
	Post_Blur_Sigma,
	Field_Trail_Filter,
	Brush_Radius,
	Brush_Strength,
	Agents_Speed_Min,
	Agents_Speed_Max,
	Agents_Turn_Rate,
	Agents_Jitter,
	Sensing_Angle,
	Sensing_Distance,
	Field_Deposit,
	Field_Decay,
	Field_Diffusion,
	Initialization_Seed,
	Agents_Count,
	Initialization_Position_Distribution,
	Initialization_Position_Image_Path,
	Initialization_Position_Image_Fit,
	Initialization_Heading_Range,
	Mask_Source,
	Mask_Target,
	Mask_Strength,
	Mask_Curve,
	Mask_Image_Path,
	Mask_Image_Fit,
	Mask_Mirror_X,
	Mask_Mirror_Y,
	Mask_Invert,
	Mask_Reversed,
	Field_Decay_Frequency,
	Field_Diffusion_Frequency,
	Capture_Record,
}

Control_Range :: struct {
	min: f32,
	max: f32,
	step: f32,
}

Control_Default_Value :: struct {
	bool_value: bool,
	int_value: i64,
	float_value: f32,
	text_value: string,
}

Control_Descriptor :: struct {
	id: Control_Id,
	stable_id: string,
	label: string,
	domain_alias: string,
	description: string,
	type: Control_Type,
	unit: Control_Unit,
	range: Control_Range,
	default_value: Control_Default_Value,
	semantic_group: Semantic_Group,
	feel_group: Feel_Group,
	reuse_level: Reuse_Level,
	importance: Importance,
	frequency: Frequency,
	scope: Scope,
	preset_scope: Preset_Scope,
	runtime_apply_policy: Runtime_Apply_Policy,
	dependencies: string,
	simulation_support: string,
	ui_hint: UI_Hint,
	controller_hint: Controller_Hint,
	wiring_status: Wiring_Status,
	legacy_names: string,
	instrument: Control_Instrument,
}

Control_Instrument_Descriptor :: struct {
	instrument: Control_Instrument,
	label: string,
	icon: string,
	description: string,
}

control_is_action :: proc(desc: Control_Descriptor) -> bool {
	return desc.type == .Action
}

control_is_live :: proc(desc: Control_Descriptor) -> bool {
	#partial switch desc.runtime_apply_policy {
	case .LiveUniform, .LiveCpuState, .ReloadImageSource, .ClearAccumulation:
		return true
	case:
		return false
	}
}

control_should_be_saved_in_behavior_preset :: proc(desc: Control_Descriptor) -> bool {
	return desc.preset_scope == .Behavior || desc.preset_scope == .Both
}

control_should_be_saved_in_look_preset :: proc(desc: Control_Descriptor) -> bool {
	return desc.preset_scope == .Look || desc.preset_scope == .Both
}

control_is_broken_or_deprecated :: proc(desc: Control_Descriptor) -> bool {
	return desc.runtime_apply_policy == .NoEffectDeprecated ||
	       desc.wiring_status == .ExposedIneffective ||
	       desc.wiring_status == .Disabled ||
	       desc.wiring_status == .Deprecated ||
	       desc.reuse_level == .Deprecated
}

control_is_visible_in_couch_ui :: proc(desc: Control_Descriptor) -> bool {
	if desc.ui_hint == .Hidden {
		return false
	}
	if desc.wiring_status != .FullyWired {
		return false
	}
	if desc.importance == .Developer || desc.importance == .Debug {
		return false
	}
	if desc.importance == .Advanced || desc.importance == .Expert {
		return false
	}
	if desc.runtime_apply_policy == .NoEffectDeprecated {
		return false
	}
	return true
}

control_is_visible_in_advanced_ui :: proc(desc: Control_Descriptor) -> bool {
	if desc.ui_hint == .Hidden {
		return false
	}
	if desc.importance == .Developer || desc.importance == .Debug {
		return false
	}
	if control_is_broken_or_deprecated(desc) {
		return false
	}
	return desc.wiring_status == .FullyWired
}

control_is_visible_in_developer_ui :: proc(desc: Control_Descriptor) -> bool {
	return desc.ui_hint != .Hidden || control_is_broken_or_deprecated(desc)
}

control_is_visible_for_mode :: proc(desc: Control_Descriptor, mode: Control_Ui_Mode) -> bool {
	switch mode {
	case .Couch:
		return control_is_visible_in_couch_ui(desc)
	case .Advanced:
		return control_is_visible_in_advanced_ui(desc)
	case .Developer:
		return control_is_visible_in_developer_ui(desc)
	}
	return false
}

control_type_is_valid :: proc(value: Control_Type) -> bool {
	switch value {
	case .Bool, .Enum, .Int, .Float, .Action, .Path, .Color, .Vec2:
		return true
	case:
		return false
	}
}

control_unit_is_valid :: proc(value: Control_Unit) -> bool {
	switch value {
	case .None, .Normalized, .Pixels, .World, .Radians, .Degrees, .Frames, .FPS, .Seconds, .Milliseconds, .Percent:
		return true
	case:
		return false
	}
}

semantic_group_is_valid :: proc(value: Semantic_Group) -> bool {
	switch value {
	case .Application, .Playback, .Presets, .Capture, .Camera, .Palette, .Rendering, .PostProcessing, .Brush, .World, .Initialization, .Entities, .Agents, .Motion, .Sensing, .Field, .Mask, .ImageSource, .Noise, .Reaction, .Solver, .Constraints, .Analysis, .Pattern, .InteractionMatrix, .Developer:
		return true
	case:
		return false
	}
}

feel_group_is_valid :: proc(value: Feel_Group) -> bool {
	switch value {
	case .Play, .Look, .Touch, .Motion, .Awareness, .Memory, .Spread, .Birth, .World, .Source, .Capture, .Debug:
		return true
	case:
		return false
	}
}

reuse_level_is_valid :: proc(value: Reuse_Level) -> bool {
	switch value {
	case .Universal, .Common, .Occasional, .Unique, .Deprecated, .DeveloperOnly:
		return true
	case:
		return false
	}
}

importance_is_valid :: proc(value: Importance) -> bool {
	switch value {
	case .Essential, .Common, .Advanced, .Expert, .Developer, .Debug:
		return true
	case:
		return false
	}
}

frequency_is_valid :: proc(value: Frequency) -> bool {
	switch value {
	case .Constant, .PerSession, .Frequently, .Continuously:
		return true
	case:
		return false
	}
}

scope_is_valid :: proc(value: Scope) -> bool {
	switch value {
	case .Global, .SharedSimulation, .Rendering, .PostProcessing, .SimulationSpecific, .Developer:
		return true
	case:
		return false
	}
}

preset_scope_is_valid :: proc(value: Preset_Scope) -> bool {
	switch value {
	case .No, .Behavior, .Look, .Both, .Maybe:
		return true
	case:
		return false
	}
}

runtime_apply_policy_is_valid :: proc(value: Runtime_Apply_Policy) -> bool {
	switch value {
	case .LiveUniform, .LiveCpuState, .ReloadImageSource, .ClearAccumulation, .RegenerateEntities, .RecreateGpuResources, .ResetSimulation, .RestartApp, .ActionOnly, .NoEffectDeprecated:
		return true
	case:
		return false
	}
}

wiring_status_is_valid :: proc(value: Wiring_Status) -> bool {
	switch value {
	case .FullyWired, .PartiallyWired, .ExposedIneffective, .CodeOnly, .LegacyOnly, .Disabled, .Deprecated:
		return true
	case:
		return false
	}
}

ui_hint_is_valid :: proc(value: UI_Hint) -> bool {
	switch value {
	case .Button, .Toggle, .Slider, .Knob, .BigKnob, .TwoAxisPad, .RadialCone, .CardGrid, .Carousel, .TextInput, .FilePicker, .Hidden:
		return true
	case:
		return false
	}
}

controller_hint_is_valid :: proc(value: Controller_Hint) -> bool {
	switch value {
	case .Primary, .Secondary, .HoldAdjust, .DPadAdjust, .StickAdjust, .ShoulderCycle, .AdvancedOnly, .DeveloperOnly:
		return true
	case:
		return false
	}
}

control_instrument_is_valid :: proc(value: Control_Instrument) -> bool {
	switch value {
	case .Play, .Look, .Brush, .Motion, .Awareness, .Field, .Birth, .World, .Source, .Capture, .Debug:
		return true
	case:
		return false
	}
}

control_descriptor_type_requires_range :: proc(desc: Control_Descriptor) -> bool {
	return desc.type == .Int || desc.type == .Float || desc.type == .Vec2
}

control_descriptor_is_valid_for_visible_ui :: proc(desc: Control_Descriptor) -> bool {
	if len(desc.stable_id) == 0 || len(desc.label) == 0 || len(desc.description) == 0 || len(desc.simulation_support) == 0 {
		return false
	}
	if !control_type_is_valid(desc.type) ||
	   !control_unit_is_valid(desc.unit) ||
	   !semantic_group_is_valid(desc.semantic_group) ||
	   !feel_group_is_valid(desc.feel_group) ||
	   !reuse_level_is_valid(desc.reuse_level) ||
	   !importance_is_valid(desc.importance) ||
	   !frequency_is_valid(desc.frequency) ||
	   !scope_is_valid(desc.scope) ||
	   !preset_scope_is_valid(desc.preset_scope) ||
	   !runtime_apply_policy_is_valid(desc.runtime_apply_policy) ||
	   !wiring_status_is_valid(desc.wiring_status) ||
	   !ui_hint_is_valid(desc.ui_hint) ||
	   !controller_hint_is_valid(desc.controller_hint) ||
	   !control_instrument_is_valid(desc.instrument) {
		return false
	}
	if desc.wiring_status != .FullyWired || desc.ui_hint == .Hidden || control_is_broken_or_deprecated(desc) {
		return false
	}
	if control_descriptor_type_requires_range(desc) {
		if desc.range.max <= desc.range.min || desc.range.step <= 0 {
			return false
		}
	}
	return true
}
