package game

import uifw "../ui"
import "core:mem"
import sdl "vendor:sdl3"

// Feature_Id is stable across App_Mode reordering and is used by queued
// feature commands and authored UI bindings. Values are never derived from an
// enum ordinal.
Feature_Id :: distinct u32

FEATURE_ID_SLIME_MOLD      :: Feature_Id(0x5649_0001)
FEATURE_ID_GRAY_SCOTT      :: Feature_Id(0x5649_0002)
FEATURE_ID_PARTICLE_LIFE   :: Feature_Id(0x5649_0003)
FEATURE_ID_FLOW_FIELD      :: Feature_Id(0x5649_0004)
FEATURE_ID_PELLETS         :: Feature_Id(0x5649_0005)
FEATURE_ID_GRADIENT_EDITOR :: Feature_Id(0x5649_0006)
FEATURE_ID_VORONOI         :: Feature_Id(0x5649_0007)
FEATURE_ID_MOIRE           :: Feature_Id(0x5649_0008)
FEATURE_ID_VECTORS         :: Feature_Id(0x5649_0009)
FEATURE_ID_PRIMORDIAL      :: Feature_Id(0x5649_000a)

Feature_Capability :: enum u8 {
	Simulation,
	Tool,
	Live_Preview,
	Video_Capture,
	Image_Source,
	Scene_Post_Processing,
}

Feature_Capabilities :: bit_set[Feature_Capability; u16]

Feature_Preview_Profile :: struct {
	width: u32,
	height: u32,
	update_stride: u32,
}

Feature_Settings_Defaults :: proc(out: rawptr) -> bool
Feature_Settings_Validate :: proc(value: rawptr) -> bool
Feature_Settings_Copy :: proc(dst, src: rawptr, size: int) -> bool
Feature_Runtime_Initialize :: proc(runtime: rawptr) -> bool
Feature_Runtime_Destroy :: proc(runtime: rawptr)
Feature_Color_Scheme_Access :: proc(settings: rawptr) -> (name: ^Color_Scheme_Name, reversed: ^bool, ok: bool)
Feature_Apply_Builtin_Preset :: proc(settings, runtime: rawptr, index: int) -> bool
Feature_Apply_Settings :: proc(settings, runtime, incoming: rawptr) -> bool
Feature_Reset :: proc(settings, runtime: rawptr, command: ^Feature_Reset_Command) -> bool
Feature_Preset_Load :: proc(settings, runtime: rawptr, path: string) -> bool
Feature_Preset_Save :: proc(settings, runtime: rawptr, path: string) -> bool
Feature_Update :: proc(settings, runtime: rawptr, dt: f32) -> bool
Feature_Builtin_Preset_Names :: proc() -> []string
Feature_Apply_Input :: proc(settings, runtime: rawptr, input: Ui_Frame_Input) -> bool
Feature_Draw_Ui :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2, worker: ^Product_Context)
Feature_Set_Paused :: proc(settings, runtime: rawptr, paused: bool) -> bool
Feature_Lifecycle :: proc(settings, runtime: rawptr)
Feature_Draw_Controls :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, worker: ^Product_Context, section: int, scroll: ^f32)

// Product descriptor. Renderer callbacks live in render_vk's paired registry
// so game remains independent of Vulkan and render-graph types.
Feature_Descriptor :: struct {
	id: Feature_Id,
	mode: App_Mode,
	name: string,
	short_description: string,
	capabilities: Feature_Capabilities,
	preview: Feature_Preview_Profile,
	settings_size: int,
	settings_alignment: int,
	settings_defaults: Feature_Settings_Defaults,
	settings_validate: Feature_Settings_Validate,
	settings_copy: Feature_Settings_Copy,
	runtime_size: int,
	runtime_alignment: int,
	runtime_initialize: Feature_Runtime_Initialize,
	runtime_destroy: Feature_Runtime_Destroy,
	color_scheme_access: Feature_Color_Scheme_Access,
	apply_builtin_preset: Feature_Apply_Builtin_Preset,
	apply_settings: Feature_Apply_Settings,
	reset: Feature_Reset,
	preset_load: Feature_Preset_Load,
	preset_save: Feature_Preset_Save,
	update: Feature_Update,
	image_targets: [2]Feature_Image_Target,
	image_target_count: int,
	builtin_preset_names: Feature_Builtin_Preset_Names,
	apply_input: Feature_Apply_Input,
	draw_ui: Feature_Draw_Ui,
	set_paused: Feature_Set_Paused,
	enter: Feature_Lifecycle,
	leave: Feature_Lifecycle,
	draw_controls: Feature_Draw_Controls,
}

feature_image_target :: proc(feature_id: Feature_Id, slot: u16) -> (Feature_Image_Target, bool) {
	descriptor, ok := feature_descriptor_by_id(feature_id)
	if !ok || int(slot) >= descriptor.image_target_count do return {}, false
	return descriptor.image_targets[slot], true
}

feature_image_target_location :: proc(target: Feature_Image_Target) -> (feature_id: Feature_Id, slot: u16, ok: bool) {
	for descriptor in FEATURE_DESCRIPTORS {
		for target_index in 0 ..< descriptor.image_target_count {
			if descriptor.image_targets[target_index] == target do return descriptor.id, u16(target_index), true
		}
	}
	return {}, 0, false
}

FEATURE_DESCRIPTORS := [?]Feature_Descriptor {
	{FEATURE_ID_SLIME_MOLD, .Slime_Mold, "Slime Mold", "Agent collaboration", {.Simulation, .Live_Preview, .Video_Capture, .Image_Source, .Scene_Post_Processing}, {192, 128, 1}, size_of(Slime_Settings), align_of(Slime_Settings), feature_defaults_slime, feature_settings_validate_non_nil, feature_settings_copy_bytes, size_of(Remaining_Sim_Runtime_State), align_of(Remaining_Sim_Runtime_State), feature_runtime_initialize_zeroed, feature_runtime_destroy_remaining, feature_color_access_slime, feature_apply_builtin_slime, feature_apply_settings_slime, feature_reset_noop, feature_preset_load_slime, feature_preset_save_slime, feature_update_slime, {.Slime_Mask, .Slime_Position}, 2, feature_builtin_presets_slime, feature_apply_input_slime, feature_draw_ui_slime, feature_set_paused_remaining, feature_lifecycle_enter_noop, feature_lifecycle_leave_remaining, nil},
	{FEATURE_ID_GRAY_SCOTT, .Gray_Scott, "Gray-Scott", "Reaction-diffusion", {.Simulation, .Live_Preview, .Video_Capture, .Image_Source}, {256, 144, 1}, size_of(Gray_Scott_Settings), align_of(Gray_Scott_Settings), feature_defaults_gray_scott, feature_settings_validate_non_nil, feature_settings_copy_bytes, size_of(Gray_Scott_Runtime_State), align_of(Gray_Scott_Runtime_State), feature_runtime_initialize_zeroed, nil, feature_color_access_gray_scott, feature_apply_builtin_gray_scott, feature_apply_settings_gray_scott, feature_reset_gray_scott, feature_preset_load_gray_scott, feature_preset_save_gray_scott, feature_update_gray_scott, {.Gray_Scott_Nutrient, .Gray_Scott_Nutrient}, 1, feature_builtin_presets_gray_scott, feature_apply_input_gray_scott, feature_draw_ui_gray_scott, feature_set_paused_gray_scott, feature_lifecycle_enter_noop, feature_lifecycle_leave_gray_scott, feature_draw_controls_gray_scott},
	{FEATURE_ID_PARTICLE_LIFE, .Particle_Life, "Particle Life", "Multi-species particles", {.Simulation, .Live_Preview, .Video_Capture, .Scene_Post_Processing}, {192, 144, 1}, size_of(Particle_Life_Settings), align_of(Particle_Life_Settings), feature_defaults_particle_life, feature_settings_validate_non_nil, feature_settings_copy_bytes, size_of(Particle_Life_Runtime_State), align_of(Particle_Life_Runtime_State), feature_runtime_initialize_zeroed, feature_runtime_destroy_particle_life, feature_color_access_particle_life, feature_apply_builtin_particle_life, feature_apply_settings_particle_life, feature_reset_particle_life, feature_preset_load_particle_life, feature_preset_save_particle_life, feature_update_particle_life, {}, 0, feature_builtin_presets_particle_life, feature_apply_input_particle_life, feature_draw_ui_particle_life, feature_set_paused_particle_life, feature_lifecycle_enter_noop, feature_lifecycle_leave_particle_life, feature_draw_controls_particle_life},
	{FEATURE_ID_FLOW_FIELD, .Flow_Field, "Flow Field", "Vector-field trails", {.Simulation, .Live_Preview, .Video_Capture, .Image_Source, .Scene_Post_Processing}, {192, 128, 1}, size_of(Flow_Settings), align_of(Flow_Settings), feature_defaults_flow, feature_settings_validate_non_nil, feature_settings_copy_bytes, size_of(Remaining_Sim_Runtime_State), align_of(Remaining_Sim_Runtime_State), feature_runtime_initialize_zeroed, feature_runtime_destroy_remaining, feature_color_access_flow, feature_apply_builtin_flow, feature_apply_settings_flow, feature_reset_noop, feature_preset_load_flow, feature_preset_save_flow, feature_update_flow, {.Flow, .Flow}, 1, feature_builtin_presets_remaining, feature_apply_input_flow, feature_draw_ui_flow, feature_set_paused_remaining, feature_lifecycle_enter_noop, feature_lifecycle_leave_remaining, feature_draw_controls_flow},
	{FEATURE_ID_PELLETS, .Pellets, "Pellets", "2D particle physics", {.Simulation, .Live_Preview, .Video_Capture, .Scene_Post_Processing}, {192, 128, 1}, size_of(Pellets_Settings), align_of(Pellets_Settings), feature_defaults_pellets, feature_settings_validate_non_nil, feature_settings_copy_bytes, size_of(Remaining_Sim_Runtime_State), align_of(Remaining_Sim_Runtime_State), feature_runtime_initialize_zeroed, feature_runtime_destroy_remaining, feature_color_access_pellets, feature_apply_builtin_pellets, feature_apply_settings_pellets, feature_reset_noop, feature_preset_load_pellets, feature_preset_save_pellets, feature_update_pellets, {}, 0, feature_builtin_presets_remaining, feature_apply_input_pellets, feature_draw_ui_pellets, feature_set_paused_remaining, feature_lifecycle_enter_noop, feature_lifecycle_leave_remaining, feature_draw_controls_pellets},
	{FEATURE_ID_GRADIENT_EDITOR, .Gradient_Editor, "Gradient Editor", "Color gradient tool", {.Tool}, {}, 0, 0, nil, nil, nil, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, nil, {}, 0, nil, nil, feature_draw_ui_gradient_editor, nil, feature_lifecycle_enter_noop, feature_lifecycle_leave_noop, nil},
	{FEATURE_ID_VORONOI, .Voronoi_CA, "Voronoi", "Nearest-site regions", {.Simulation, .Live_Preview, .Video_Capture, .Scene_Post_Processing}, {192, 128, 1}, size_of(Voronoi_Settings), align_of(Voronoi_Settings), feature_defaults_voronoi, feature_settings_validate_non_nil, feature_settings_copy_bytes, size_of(Remaining_Sim_Runtime_State), align_of(Remaining_Sim_Runtime_State), feature_runtime_initialize_zeroed, feature_runtime_destroy_remaining, feature_color_access_voronoi, feature_apply_builtin_voronoi, feature_apply_settings_voronoi, feature_reset_noop, feature_preset_load_voronoi, feature_preset_save_voronoi, feature_update_voronoi, {}, 0, feature_builtin_presets_remaining, feature_apply_input_voronoi, feature_draw_ui_voronoi, feature_set_paused_remaining, feature_lifecycle_enter_noop, feature_lifecycle_leave_remaining, feature_draw_controls_voronoi},
	{FEATURE_ID_MOIRE, .Moire, "Moire", "Interference patterns", {.Simulation, .Live_Preview, .Video_Capture, .Image_Source}, {192, 128, 1}, size_of(Moire_Settings), align_of(Moire_Settings), feature_defaults_moire, feature_settings_validate_non_nil, feature_settings_copy_bytes, size_of(Remaining_Sim_Runtime_State), align_of(Remaining_Sim_Runtime_State), feature_runtime_initialize_zeroed, feature_runtime_destroy_remaining, feature_color_access_moire, feature_apply_builtin_moire, feature_apply_settings_moire, feature_reset_noop, feature_preset_load_moire, feature_preset_save_moire, feature_update_moire, {.Moire, .Moire}, 1, feature_builtin_presets_moire, feature_apply_input_noop, feature_draw_ui_moire, feature_set_paused_remaining, feature_lifecycle_enter_noop, feature_lifecycle_leave_remaining, feature_draw_controls_moire},
	{FEATURE_ID_VECTORS, .Vectors, "Vectors", "Vector field view", {.Simulation, .Live_Preview, .Video_Capture, .Image_Source}, {192, 128, 1}, size_of(Vectors_Settings), align_of(Vectors_Settings), feature_defaults_vectors, feature_settings_validate_non_nil, feature_settings_copy_bytes, size_of(Remaining_Sim_Runtime_State), align_of(Remaining_Sim_Runtime_State), feature_runtime_initialize_zeroed, feature_runtime_destroy_remaining, feature_color_access_vectors, feature_apply_builtin_vectors, feature_apply_settings_vectors, feature_reset_noop, feature_preset_load_vectors, feature_preset_save_vectors, feature_update_vectors, {.Vectors, .Vectors}, 1, feature_builtin_presets_remaining, feature_apply_input_noop, feature_draw_ui_vectors, feature_set_paused_remaining, feature_lifecycle_enter_noop, feature_lifecycle_leave_remaining, feature_draw_controls_vectors},
	{FEATURE_ID_PRIMORDIAL, .Primordial, "Primordial", "Emergent particle motion", {.Simulation, .Live_Preview, .Video_Capture, .Scene_Post_Processing}, {192, 128, 1}, size_of(Primordial_Settings), align_of(Primordial_Settings), feature_defaults_primordial, feature_settings_validate_non_nil, feature_settings_copy_bytes, size_of(Remaining_Sim_Runtime_State), align_of(Remaining_Sim_Runtime_State), feature_runtime_initialize_zeroed, feature_runtime_destroy_remaining, feature_color_access_primordial, feature_apply_builtin_primordial, feature_apply_settings_primordial, feature_reset_noop, feature_preset_load_primordial, feature_preset_save_primordial, feature_update_primordial, {}, 0, feature_builtin_presets_remaining, feature_apply_input_primordial, feature_draw_ui_primordial, feature_set_paused_remaining, feature_lifecycle_enter_noop, feature_lifecycle_leave_remaining, feature_draw_controls_primordial},
}

feature_runtime_initialize_zeroed :: proc(runtime: rawptr) -> bool {return runtime != nil}
feature_color_access_slime :: proc(settings: rawptr) -> (^Color_Scheme_Name, ^bool, bool) {if settings == nil do return nil, nil, false; value := cast(^Slime_Settings)settings; return &value.color_scheme, &value.color_scheme_reversed, true}
feature_color_access_gray_scott :: proc(settings: rawptr) -> (^Color_Scheme_Name, ^bool, bool) {if settings == nil do return nil, nil, false; value := cast(^Gray_Scott_Settings)settings; return &value.color_scheme, &value.color_scheme_reversed, true}
feature_color_access_particle_life :: proc(settings: rawptr) -> (^Color_Scheme_Name, ^bool, bool) {if settings == nil do return nil, nil, false; value := cast(^Particle_Life_Settings)settings; return &value.color_scheme, &value.color_scheme_reversed, true}
feature_color_access_flow :: proc(settings: rawptr) -> (^Color_Scheme_Name, ^bool, bool) {if settings == nil do return nil, nil, false; value := cast(^Flow_Settings)settings; return &value.color_scheme, &value.color_scheme_reversed, true}
feature_color_access_pellets :: proc(settings: rawptr) -> (^Color_Scheme_Name, ^bool, bool) {if settings == nil do return nil, nil, false; value := cast(^Pellets_Settings)settings; return &value.color_scheme, &value.color_scheme_reversed, true}
feature_color_access_voronoi :: proc(settings: rawptr) -> (^Color_Scheme_Name, ^bool, bool) {if settings == nil do return nil, nil, false; value := cast(^Voronoi_Settings)settings; return &value.color_scheme, &value.color_scheme_reversed, true}
feature_color_access_moire :: proc(settings: rawptr) -> (^Color_Scheme_Name, ^bool, bool) {if settings == nil do return nil, nil, false; value := cast(^Moire_Settings)settings; return &value.color_scheme, &value.color_scheme_reversed, true}
feature_color_access_vectors :: proc(settings: rawptr) -> (^Color_Scheme_Name, ^bool, bool) {if settings == nil do return nil, nil, false; value := cast(^Vectors_Settings)settings; return &value.color_scheme, &value.color_scheme_reversed, true}
feature_color_access_primordial :: proc(settings: rawptr) -> (^Color_Scheme_Name, ^bool, bool) {if settings == nil do return nil, nil, false; value := cast(^Primordial_Settings)settings; return &value.color_scheme, &value.color_scheme_reversed, true}

feature_apply_builtin_gray_scott :: proc(settings, runtime: rawptr, index: int) -> bool {if settings == nil || runtime == nil do return false; sim := Gray_Scott_Simulation{settings = cast(^Gray_Scott_Settings)settings, runtime = cast(^Gray_Scott_Runtime_State)runtime}; gray_scott_apply_builtin_preset(&sim, index); return true}
feature_apply_builtin_particle_life :: proc(settings, runtime: rawptr, index: int) -> bool {if settings == nil || runtime == nil do return false; sim := Particle_Life_Simulation{settings = cast(^Particle_Life_Settings)settings, runtime = cast(^Particle_Life_Runtime_State)runtime}; particle_life_apply_builtin_preset(&sim, index); return true}
feature_apply_builtin_remaining :: proc(settings, runtime: rawptr, index: int, kind: Remaining_Sim_Kind) -> bool {
	if settings == nil || runtime == nil do return false
	sim := Remaining_Sim_State{runtime = cast(^Remaining_Sim_Runtime_State)runtime}
	#partial switch kind {
	case .Slime_Mold: sim.slime = cast(^Slime_Settings)settings
	case .Flow_Field: sim.flow = cast(^Flow_Settings)settings
	case .Pellets: sim.pellets = cast(^Pellets_Settings)settings
	case .Voronoi_CA: sim.voronoi = cast(^Voronoi_Settings)settings
	case .Moire: sim.moire = cast(^Moire_Settings)settings
	case .Vectors: sim.vectors = cast(^Vectors_Settings)settings
	case .Primordial: sim.primordial = cast(^Primordial_Settings)settings
	}
	remaining_sim_apply_builtin_preset(&sim, kind, index)
	return true
}
feature_apply_builtin_slime :: proc(settings, runtime: rawptr, index: int) -> bool {return feature_apply_builtin_remaining(settings, runtime, index, .Slime_Mold)}
feature_apply_builtin_flow :: proc(settings, runtime: rawptr, index: int) -> bool {return feature_apply_builtin_remaining(settings, runtime, index, .Flow_Field)}
feature_apply_builtin_pellets :: proc(settings, runtime: rawptr, index: int) -> bool {return feature_apply_builtin_remaining(settings, runtime, index, .Pellets)}
feature_apply_builtin_voronoi :: proc(settings, runtime: rawptr, index: int) -> bool {return feature_apply_builtin_remaining(settings, runtime, index, .Voronoi_CA)}
feature_apply_builtin_moire :: proc(settings, runtime: rawptr, index: int) -> bool {return feature_apply_builtin_remaining(settings, runtime, index, .Moire)}
feature_apply_builtin_vectors :: proc(settings, runtime: rawptr, index: int) -> bool {return feature_apply_builtin_remaining(settings, runtime, index, .Vectors)}
feature_apply_builtin_primordial :: proc(settings, runtime: rawptr, index: int) -> bool {return feature_apply_builtin_remaining(settings, runtime, index, .Primordial)}

feature_apply_settings_copy :: proc(settings, runtime, incoming: rawptr, size: int) -> bool {if settings == nil || runtime == nil || incoming == nil || size <= 0 do return false; mem.copy_non_overlapping(settings, incoming, size); return true}
feature_apply_settings_slime :: proc(settings, runtime, incoming: rawptr) -> bool {return feature_apply_settings_copy(settings, runtime, incoming, size_of(Slime_Settings))}
feature_apply_settings_flow :: proc(settings, runtime, incoming: rawptr) -> bool {return feature_apply_settings_copy(settings, runtime, incoming, size_of(Flow_Settings))}
feature_apply_settings_pellets :: proc(settings, runtime, incoming: rawptr) -> bool {return feature_apply_settings_copy(settings, runtime, incoming, size_of(Pellets_Settings))}
feature_apply_settings_voronoi :: proc(settings, runtime, incoming: rawptr) -> bool {return feature_apply_settings_copy(settings, runtime, incoming, size_of(Voronoi_Settings))}
feature_apply_settings_moire :: proc(settings, runtime, incoming: rawptr) -> bool {return feature_apply_settings_copy(settings, runtime, incoming, size_of(Moire_Settings))}
feature_apply_settings_vectors :: proc(settings, runtime, incoming: rawptr) -> bool {return feature_apply_settings_copy(settings, runtime, incoming, size_of(Vectors_Settings))}
feature_apply_settings_primordial :: proc(settings, runtime, incoming: rawptr) -> bool {return feature_apply_settings_copy(settings, runtime, incoming, size_of(Primordial_Settings))}
feature_apply_settings_gray_scott :: proc(settings, runtime, incoming: rawptr) -> bool {if settings == nil || runtime == nil || incoming == nil do return false; sim := Gray_Scott_Simulation{settings = cast(^Gray_Scott_Settings)settings, runtime = cast(^Gray_Scott_Runtime_State)runtime}; gray_scott_load_settings(&sim, (cast(^Gray_Scott_Settings)incoming)^); return true}
feature_apply_settings_particle_life :: proc(settings, runtime, incoming: rawptr) -> bool {if settings == nil || runtime == nil || incoming == nil do return false; sim := Particle_Life_Simulation{settings = cast(^Particle_Life_Settings)settings, runtime = cast(^Particle_Life_Runtime_State)runtime}; particle_life_load_settings(&sim, (cast(^Particle_Life_Settings)incoming)^); return true}

feature_reset_noop :: proc(settings, runtime: rawptr, command: ^Feature_Reset_Command) -> bool {
	return settings != nil && runtime != nil && command != nil
}

feature_reset_gray_scott :: proc(settings, runtime: rawptr, command: ^Feature_Reset_Command) -> bool {
	if settings == nil || runtime == nil || command == nil do return false
	sim := Gray_Scott_Simulation{settings = cast(^Gray_Scott_Settings)settings, runtime = cast(^Gray_Scott_Runtime_State)runtime}
	if command.seed_noise do gray_scott_seed_noise(&sim)
	if !command.seed_noise do gray_scott_reset_runtime(&sim)
	return true
}

feature_reset_particle_life :: proc(settings, runtime: rawptr, command: ^Feature_Reset_Command) -> bool {
	if settings == nil || runtime == nil || command == nil do return false
	sim := Particle_Life_Simulation{settings = cast(^Particle_Life_Settings)settings, runtime = cast(^Particle_Life_Runtime_State)runtime}
	if command.randomize do particle_life_randomize_forces(&sim)
	particle_life_reset_runtime(&sim)
	return true
}

feature_preset_load_slime :: proc(settings, runtime: rawptr, path: string) -> bool {if settings == nil || runtime == nil do return false; value, ok := settings_load_slime_preset(path, (cast(^Slime_Settings)settings)^); return ok && feature_apply_settings_slime(settings, runtime, &value)}
feature_preset_load_gray_scott :: proc(settings, runtime: rawptr, path: string) -> bool {if settings == nil || runtime == nil do return false; value, ok := settings_load_gray_scott_preset(path, (cast(^Gray_Scott_Settings)settings)^); return ok && feature_apply_settings_gray_scott(settings, runtime, &value)}
feature_preset_load_particle_life :: proc(settings, runtime: rawptr, path: string) -> bool {if settings == nil || runtime == nil do return false; value, ok := settings_load_particle_life_preset(path, (cast(^Particle_Life_Settings)settings)^); return ok && feature_apply_settings_particle_life(settings, runtime, &value)}
feature_preset_load_flow :: proc(settings, runtime: rawptr, path: string) -> bool {if settings == nil || runtime == nil do return false; value, ok := settings_load_flow_preset(path, (cast(^Flow_Settings)settings)^); return ok && feature_apply_settings_flow(settings, runtime, &value)}
feature_preset_load_pellets :: proc(settings, runtime: rawptr, path: string) -> bool {if settings == nil || runtime == nil do return false; value, ok := settings_load_pellets_preset(path, (cast(^Pellets_Settings)settings)^); return ok && feature_apply_settings_pellets(settings, runtime, &value)}
feature_preset_load_voronoi :: proc(settings, runtime: rawptr, path: string) -> bool {if settings == nil || runtime == nil do return false; value, ok := settings_load_voronoi_preset(path, (cast(^Voronoi_Settings)settings)^); return ok && feature_apply_settings_voronoi(settings, runtime, &value)}
feature_preset_load_moire :: proc(settings, runtime: rawptr, path: string) -> bool {if settings == nil || runtime == nil do return false; value, ok := settings_load_moire_preset(path, (cast(^Moire_Settings)settings)^); return ok && feature_apply_settings_moire(settings, runtime, &value)}
feature_preset_load_vectors :: proc(settings, runtime: rawptr, path: string) -> bool {if settings == nil || runtime == nil do return false; value, ok := settings_load_vectors_preset(path, (cast(^Vectors_Settings)settings)^); return ok && feature_apply_settings_vectors(settings, runtime, &value)}
feature_preset_load_primordial :: proc(settings, runtime: rawptr, path: string) -> bool {if settings == nil || runtime == nil do return false; value, ok := settings_load_primordial_preset(path, (cast(^Primordial_Settings)settings)^); return ok && feature_apply_settings_primordial(settings, runtime, &value)}

feature_preset_save_slime :: proc(settings, runtime: rawptr, path: string) -> bool {_ = runtime; return settings != nil && settings_save_slime(path, (cast(^Slime_Settings)settings)^)}
feature_preset_save_gray_scott :: proc(settings, runtime: rawptr, path: string) -> bool {_ = runtime; return settings != nil && settings_save_gray_scott(path, (cast(^Gray_Scott_Settings)settings)^)}
feature_preset_save_particle_life :: proc(settings, runtime: rawptr, path: string) -> bool {_ = runtime; return settings != nil && settings_save_particle_life(path, (cast(^Particle_Life_Settings)settings)^)}
feature_preset_save_flow :: proc(settings, runtime: rawptr, path: string) -> bool {_ = runtime; return settings != nil && settings_save_flow(path, (cast(^Flow_Settings)settings)^)}
feature_preset_save_pellets :: proc(settings, runtime: rawptr, path: string) -> bool {_ = runtime; return settings != nil && settings_save_pellets(path, (cast(^Pellets_Settings)settings)^)}
feature_preset_save_voronoi :: proc(settings, runtime: rawptr, path: string) -> bool {_ = runtime; return settings != nil && settings_save_voronoi(path, (cast(^Voronoi_Settings)settings)^)}
feature_preset_save_moire :: proc(settings, runtime: rawptr, path: string) -> bool {_ = runtime; return settings != nil && settings_save_moire(path, (cast(^Moire_Settings)settings)^)}
feature_preset_save_vectors :: proc(settings, runtime: rawptr, path: string) -> bool {_ = runtime; return settings != nil && settings_save_vectors(path, (cast(^Vectors_Settings)settings)^)}
feature_preset_save_primordial :: proc(settings, runtime: rawptr, path: string) -> bool {_ = runtime; return settings != nil && settings_save_primordial(path, (cast(^Primordial_Settings)settings)^)}

feature_update_gray_scott :: proc(settings, runtime: rawptr, dt: f32) -> bool {if settings == nil || runtime == nil do return false; sim := Gray_Scott_Simulation{settings = cast(^Gray_Scott_Settings)settings, runtime = cast(^Gray_Scott_Runtime_State)runtime}; gray_scott_step(&sim, dt); return true}
feature_update_particle_life :: proc(settings, runtime: rawptr, dt: f32) -> bool {if settings == nil || runtime == nil do return false; sim := Particle_Life_Simulation{settings = cast(^Particle_Life_Settings)settings, runtime = cast(^Particle_Life_Runtime_State)runtime}; particle_life_step(&sim, dt); return true}
feature_update_remaining :: proc(settings, runtime: rawptr, dt: f32, kind: Remaining_Sim_Kind) -> bool {
	if settings == nil || runtime == nil do return false
	sim := Remaining_Sim_State{runtime = cast(^Remaining_Sim_Runtime_State)runtime}
	#partial switch kind {
	case .Slime_Mold: sim.slime = cast(^Slime_Settings)settings
	case .Flow_Field: sim.flow = cast(^Flow_Settings)settings
	case .Pellets: sim.pellets = cast(^Pellets_Settings)settings
	case .Voronoi_CA: sim.voronoi = cast(^Voronoi_Settings)settings
	case .Moire: sim.moire = cast(^Moire_Settings)settings
	case .Vectors: sim.vectors = cast(^Vectors_Settings)settings
	case .Primordial: sim.primordial = cast(^Primordial_Settings)settings
	}
	remaining_sim_step(&sim, dt)
	return true
}
feature_update_slime :: proc(settings, runtime: rawptr, dt: f32) -> bool {return feature_update_remaining(settings, runtime, dt, .Slime_Mold)}
feature_update_flow :: proc(settings, runtime: rawptr, dt: f32) -> bool {return feature_update_remaining(settings, runtime, dt, .Flow_Field)}
feature_update_pellets :: proc(settings, runtime: rawptr, dt: f32) -> bool {return feature_update_remaining(settings, runtime, dt, .Pellets)}
feature_update_voronoi :: proc(settings, runtime: rawptr, dt: f32) -> bool {return feature_update_remaining(settings, runtime, dt, .Voronoi_CA)}
feature_update_moire :: proc(settings, runtime: rawptr, dt: f32) -> bool {return feature_update_remaining(settings, runtime, dt, .Moire)}
feature_update_vectors :: proc(settings, runtime: rawptr, dt: f32) -> bool {return feature_update_remaining(settings, runtime, dt, .Vectors)}
feature_update_primordial :: proc(settings, runtime: rawptr, dt: f32) -> bool {return feature_update_remaining(settings, runtime, dt, .Primordial)}

feature_builtin_presets_gray_scott :: proc() -> []string {return GRAY_SCOTT_BUILTIN_PRESET_NAMES[:]}
feature_builtin_presets_particle_life :: proc() -> []string {return PARTICLE_LIFE_BUILTIN_PRESET_NAMES[:]}
feature_builtin_presets_slime :: proc() -> []string {return SLIME_BUILTIN_PRESET_NAMES[:]}
feature_builtin_presets_remaining :: proc() -> []string {return REMAINING_DEFAULT_BUILTIN_PRESET_NAMES[:]}
feature_builtin_presets_moire :: proc() -> []string {return MOIRE_BUILTIN_PRESET_NAMES[:]}

feature_apply_input_gray_scott :: proc(settings, runtime: rawptr, input: Ui_Frame_Input) -> bool {if settings == nil || runtime == nil do return false; sim := Gray_Scott_Simulation{settings = cast(^Gray_Scott_Settings)settings, runtime = cast(^Gray_Scott_Runtime_State)runtime}; gray_scott_apply_frame_input(&sim, input); return true}
feature_apply_input_particle_life :: proc(settings, runtime: rawptr, input: Ui_Frame_Input) -> bool {if settings == nil || runtime == nil do return false; sim := Particle_Life_Simulation{settings = cast(^Particle_Life_Settings)settings, runtime = cast(^Particle_Life_Runtime_State)runtime}; particle_life_apply_frame_input(&sim, input); return true}
feature_apply_input_remaining :: proc(settings, runtime: rawptr, input: Ui_Frame_Input, kind: Remaining_Sim_Kind) -> bool {
	if settings == nil || runtime == nil do return false
	sim := Remaining_Sim_State{runtime = cast(^Remaining_Sim_Runtime_State)runtime}
	#partial switch kind {
	case .Slime_Mold: sim.slime = cast(^Slime_Settings)settings
	case .Flow_Field: sim.flow = cast(^Flow_Settings)settings
	case .Pellets: sim.pellets = cast(^Pellets_Settings)settings
	case .Voronoi_CA: sim.voronoi = cast(^Voronoi_Settings)settings
	case .Primordial: sim.primordial = cast(^Primordial_Settings)settings
	case:
		return true
	}
	remaining_sim_apply_frame_input_for_kind(&sim, kind, input)
	return true
}
feature_apply_input_slime :: proc(settings, runtime: rawptr, input: Ui_Frame_Input) -> bool {return feature_apply_input_remaining(settings, runtime, input, .Slime_Mold)}
feature_apply_input_flow :: proc(settings, runtime: rawptr, input: Ui_Frame_Input) -> bool {return feature_apply_input_remaining(settings, runtime, input, .Flow_Field)}
feature_apply_input_pellets :: proc(settings, runtime: rawptr, input: Ui_Frame_Input) -> bool {return feature_apply_input_remaining(settings, runtime, input, .Pellets)}
feature_apply_input_voronoi :: proc(settings, runtime: rawptr, input: Ui_Frame_Input) -> bool {return feature_apply_input_remaining(settings, runtime, input, .Voronoi_CA)}
feature_apply_input_primordial :: proc(settings, runtime: rawptr, input: Ui_Frame_Input) -> bool {return feature_apply_input_remaining(settings, runtime, input, .Primordial)}
feature_apply_input_noop :: proc(settings, runtime: rawptr, input: Ui_Frame_Input) -> bool {_ = input; return settings != nil && runtime != nil}

feature_draw_ui_slime :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2, worker: ^Product_Context) {app_ui_draw_remaining_sim(ui, gui, .Slime_Mold, &ui.slime_mold, viewport, worker)}
feature_draw_ui_gray_scott :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2, worker: ^Product_Context) {app_ui_draw_gray_scott(ui, gui, &ui.gray_scott, viewport, worker)}
feature_draw_ui_particle_life :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2, worker: ^Product_Context) {app_ui_draw_particle_life(ui, gui, &ui.particle_life, viewport, worker)}
feature_draw_ui_flow :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2, worker: ^Product_Context) {app_ui_draw_remaining_sim(ui, gui, .Flow_Field, &ui.flow_field, viewport, worker)}
feature_draw_ui_pellets :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2, worker: ^Product_Context) {app_ui_draw_remaining_sim(ui, gui, .Pellets, &ui.pellets, viewport, worker)}
feature_draw_ui_gradient_editor :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2, worker: ^Product_Context) {_ = worker; app_ui_draw_gradient_editor(ui, gui, viewport)}
feature_draw_ui_voronoi :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2, worker: ^Product_Context) {app_ui_draw_remaining_sim(ui, gui, .Voronoi_CA, &ui.voronoi_ca, viewport, worker)}
feature_draw_ui_moire :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2, worker: ^Product_Context) {app_ui_draw_remaining_sim(ui, gui, .Moire, &ui.moire, viewport, worker)}
feature_draw_ui_vectors :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2, worker: ^Product_Context) {app_ui_draw_remaining_sim(ui, gui, .Vectors, &ui.vectors, viewport, worker)}
feature_draw_ui_primordial :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2, worker: ^Product_Context) {app_ui_draw_remaining_sim(ui, gui, .Primordial, &ui.primordial, viewport, worker)}

feature_set_paused_gray_scott :: proc(settings, runtime: rawptr, paused: bool) -> bool {_ = runtime; if settings == nil do return false; (cast(^Gray_Scott_Settings)settings).paused = paused; return true}
feature_set_paused_particle_life :: proc(settings, runtime: rawptr, paused: bool) -> bool {_ = runtime; if settings == nil do return false; (cast(^Particle_Life_Settings)settings).paused = paused; return true}
feature_set_paused_remaining :: proc(settings, runtime: rawptr, paused: bool) -> bool {_ = settings; if runtime == nil do return false; (cast(^Remaining_Sim_Runtime_State)runtime).paused = paused; return true}
feature_lifecycle_enter_noop :: proc(settings, runtime: rawptr) {_ = settings; _ = runtime}
feature_lifecycle_leave_noop :: proc(settings, runtime: rawptr) {_ = settings; _ = runtime}
feature_lifecycle_leave_gray_scott :: proc(settings, runtime: rawptr) {if settings == nil || runtime == nil do return; _ = feature_set_paused_gray_scott(settings, runtime, true); sim := Gray_Scott_Simulation{settings = cast(^Gray_Scott_Settings)settings, runtime = cast(^Gray_Scott_Runtime_State)runtime}; gray_scott_stop_webcam(&sim)}
feature_lifecycle_leave_particle_life :: proc(settings, runtime: rawptr) {_ = feature_set_paused_particle_life(settings, runtime, true)}
feature_lifecycle_leave_remaining :: proc(settings, runtime: rawptr) {
	_ = feature_set_paused_remaining(settings, runtime, true)
	if runtime == nil do return
	state := cast(^Remaining_Sim_Runtime_State)runtime
	if state.webcam_capture != nil do sdl.CloseCamera(state.webcam_capture)
	state.webcam_capture = nil
	write_fixed_string(state.webcam_capture_status[:], "Webcam stopped")
}

feature_draw_controls_gray_scott :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, worker: ^Product_Context, section: int, scroll: ^f32) {_ = gray_scott_draw_controls(&ui.gray_scott, gui, rect, scroll, worker, &ui.color_scheme_editor, section)}
feature_draw_controls_particle_life :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, worker: ^Product_Context, section: int, scroll: ^f32) {particle_life_draw_controls(&ui.particle_life, gui, rect, scroll, worker, &ui.color_scheme_editor, section)}
feature_draw_controls_remaining :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, worker: ^Product_Context, section: int, scroll: ^f32, kind: Remaining_Sim_Kind) {
	state: ^Remaining_Sim_State
	#partial switch kind {
	case .Flow_Field: state = &ui.flow_field
	case .Pellets: state = &ui.pellets
	case .Voronoi_CA: state = &ui.voronoi_ca
	case .Moire: state = &ui.moire
	case .Vectors: state = &ui.vectors
	case .Primordial: state = &ui.primordial
	case: return
	}
	remaining_sim_draw_controls(state, gui, kind, rect, &ui.color_scheme_editor, worker, section, scroll)
}
feature_draw_controls_flow :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, worker: ^Product_Context, section: int, scroll: ^f32) {feature_draw_controls_remaining(ui, gui, rect, worker, section, scroll, .Flow_Field)}
feature_draw_controls_pellets :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, worker: ^Product_Context, section: int, scroll: ^f32) {feature_draw_controls_remaining(ui, gui, rect, worker, section, scroll, .Pellets)}
feature_draw_controls_voronoi :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, worker: ^Product_Context, section: int, scroll: ^f32) {feature_draw_controls_remaining(ui, gui, rect, worker, section, scroll, .Voronoi_CA)}
feature_draw_controls_moire :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, worker: ^Product_Context, section: int, scroll: ^f32) {feature_draw_controls_remaining(ui, gui, rect, worker, section, scroll, .Moire)}
feature_draw_controls_vectors :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, worker: ^Product_Context, section: int, scroll: ^f32) {feature_draw_controls_remaining(ui, gui, rect, worker, section, scroll, .Vectors)}
feature_draw_controls_primordial :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, worker: ^Product_Context, section: int, scroll: ^f32) {feature_draw_controls_remaining(ui, gui, rect, worker, section, scroll, .Primordial)}
feature_runtime_destroy_remaining :: proc(runtime: rawptr) {
	if runtime == nil do return
	state := cast(^Remaining_Sim_Runtime_State)runtime
	if state.webcam_capture != nil do sdl.CloseCamera(state.webcam_capture)
	state^ = {}
}
feature_runtime_destroy_particle_life :: proc(runtime: rawptr) {
	if runtime == nil do return
	state := cast(^Particle_Life_Runtime_State)runtime
	particle_life_analysis_workspace_destroy(&state.analysis)
	if state.preserved_particles != nil do delete(state.preserved_particles)
	state^ = {}
}

Feature_Instance :: struct {
	descriptor: ^Feature_Descriptor,
	settings_storage: []byte,
	runtime_storage: []byte,
	settings: rawptr,
	runtime: rawptr,
}

FEATURE_INSTANCE_VARIANT_COUNT :: 2

Feature_Instance_Set :: struct {
	instances: [len(FEATURE_DESCRIPTORS)][FEATURE_INSTANCE_VARIANT_COUNT]Feature_Instance,
}

feature_instance_set_get :: proc(set: ^Feature_Instance_Set, mode: App_Mode, preview := false) -> ^Feature_Instance {
	if set == nil do return nil
	for descriptor, index in FEATURE_DESCRIPTORS {
		if descriptor.mode == mode do return &set.instances[index][preview ? 1 : 0]
	}
	return nil
}

feature_instance_set_set_paused :: proc(set: ^Feature_Instance_Set, mode: App_Mode, paused: bool) -> bool {
	instance := feature_instance_set_get(set, mode)
	if instance == nil || instance.descriptor == nil || instance.descriptor.set_paused == nil do return false
	return instance.descriptor.set_paused(instance.settings, instance.runtime, paused)
}

feature_instance_set_enter :: proc(set: ^Feature_Instance_Set, mode: App_Mode) -> bool {
	instance := feature_instance_set_get(set, mode)
	descriptor, ok := feature_descriptor_by_mode(mode)
	if !ok || descriptor.enter == nil do return false
	settings := instance != nil ? instance.settings : nil
	runtime := instance != nil ? instance.runtime : nil
	descriptor.enter(settings, runtime)
	return true
}

feature_instance_set_leave :: proc(set: ^Feature_Instance_Set, mode: App_Mode) -> bool {
	instance := feature_instance_set_get(set, mode)
	descriptor, ok := feature_descriptor_by_mode(mode)
	if !ok || descriptor.leave == nil do return false
	settings := instance != nil ? instance.settings : nil
	runtime := instance != nil ? instance.runtime : nil
	descriptor.leave(settings, runtime)
	return true
}

feature_instance_set_init :: proc(set: ^Feature_Instance_Set) -> bool {
	if set == nil do return false
	set^ = {}
	for descriptor, descriptor_index in FEATURE_DESCRIPTORS {
		if .Tool in descriptor.capabilities do continue
		for variant in 0 ..< FEATURE_INSTANCE_VARIANT_COUNT {
			if !feature_instance_init(&set.instances[descriptor_index][variant], descriptor.mode) {
				feature_instance_set_destroy(set)
				return false
			}
		}
	}
	return true
}

feature_instance_set_destroy :: proc(set: ^Feature_Instance_Set) {
	if set == nil do return
	for descriptor_index := len(FEATURE_DESCRIPTORS) - 1; descriptor_index >= 0; descriptor_index -= 1 {
		for variant := FEATURE_INSTANCE_VARIANT_COUNT - 1; variant >= 0; variant -= 1 {
			feature_instance_destroy(&set.instances[descriptor_index][variant])
		}
	}
	set^ = {}
}

feature_instance_init :: proc(instance: ^Feature_Instance, mode: App_Mode) -> bool {
	if instance == nil do return false
	descriptor, ok := feature_descriptor_by_mode(mode)
	if !ok || descriptor.settings_size <= 0 || descriptor.settings_alignment <= 0 do return false
	settings, settings_error := mem.alloc_bytes(descriptor.settings_size, descriptor.settings_alignment)
	if settings_error != nil do return false
	for _, i in settings do settings[i] = 0
	instance^ = {descriptor = descriptor, settings_storage = settings, settings = raw_data(settings)}
	if descriptor.settings_defaults == nil || !descriptor.settings_defaults(instance.settings) {
		delete(instance.settings_storage)
		instance^ = {}
		return false
	}
	if descriptor.runtime_size > 0 {
		runtime, runtime_error := mem.alloc_bytes(descriptor.runtime_size, descriptor.runtime_alignment)
		if runtime_error != nil {
			delete(instance.settings_storage)
			instance^ = {}
			return false
		}
		for _, i in runtime do runtime[i] = 0
		instance.runtime_storage = runtime
		instance.runtime = raw_data(runtime)
		if descriptor.runtime_initialize == nil || !descriptor.runtime_initialize(instance.runtime) {
			delete(instance.runtime_storage)
			delete(instance.settings_storage)
			instance^ = {}
			return false
		}
	}
	return true
}

feature_instance_destroy :: proc(instance: ^Feature_Instance) {
	if instance == nil do return
	if instance.runtime != nil && instance.descriptor != nil && instance.descriptor.runtime_destroy != nil do instance.descriptor.runtime_destroy(instance.runtime)
	if instance.runtime_storage != nil do delete(instance.runtime_storage)
	if instance.settings_storage != nil do delete(instance.settings_storage)
	instance^ = {}
}

feature_instance_settings :: proc(instance: ^Feature_Instance, $T: typeid) -> (^T, bool) {
	if instance == nil || instance.descriptor == nil || instance.settings == nil || instance.descriptor.settings_size != size_of(T) || instance.descriptor.settings_alignment != align_of(T) do return nil, false
	return cast(^T)instance.settings, true
}

feature_instance_runtime :: proc(instance: ^Feature_Instance, $T: typeid) -> (^T, bool) {
	if instance == nil || instance.descriptor == nil || instance.runtime == nil || instance.descriptor.runtime_size != size_of(T) || instance.descriptor.runtime_alignment != align_of(T) do return nil, false
	return cast(^T)instance.runtime, true
}

feature_settings_validate_non_nil :: proc(value: rawptr) -> bool {return value != nil}
feature_settings_copy_bytes :: proc(dst, src: rawptr, size: int) -> bool {if dst == nil || src == nil || size <= 0 do return false; mem.copy_non_overlapping(dst, src, size); return true}
feature_defaults_slime :: proc(out: rawptr) -> bool {if out == nil do return false; (cast(^Slime_Settings)out)^ = slime_settings_default(); return true}
feature_defaults_gray_scott :: proc(out: rawptr) -> bool {if out == nil do return false; (cast(^Gray_Scott_Settings)out)^ = gray_scott_default_settings(); return true}
feature_defaults_particle_life :: proc(out: rawptr) -> bool {if out == nil do return false; (cast(^Particle_Life_Settings)out)^ = particle_life_default_settings(); return true}
feature_defaults_flow :: proc(out: rawptr) -> bool {if out == nil do return false; (cast(^Flow_Settings)out)^ = flow_settings_default(); return true}
feature_defaults_pellets :: proc(out: rawptr) -> bool {if out == nil do return false; (cast(^Pellets_Settings)out)^ = pellets_settings_default(); return true}
feature_defaults_voronoi :: proc(out: rawptr) -> bool {if out == nil do return false; (cast(^Voronoi_Settings)out)^ = voronoi_settings_default(); return true}
feature_defaults_moire :: proc(out: rawptr) -> bool {if out == nil do return false; (cast(^Moire_Settings)out)^ = moire_settings_default(); return true}
feature_defaults_vectors :: proc(out: rawptr) -> bool {if out == nil do return false; (cast(^Vectors_Settings)out)^ = vectors_settings_default(); return true}
feature_defaults_primordial :: proc(out: rawptr) -> bool {if out == nil do return false; (cast(^Primordial_Settings)out)^ = primordial_settings_default(); return true}

feature_count :: proc() -> int {
	return len(FEATURE_DESCRIPTORS)
}

feature_descriptor_at :: proc(index: int) -> (^Feature_Descriptor, bool) {
	if index < 0 || index >= len(FEATURE_DESCRIPTORS) {
		return nil, false
	}
	return &FEATURE_DESCRIPTORS[index], true
}

feature_descriptor_by_mode :: proc(mode: App_Mode) -> (^Feature_Descriptor, bool) {
	for _, i in FEATURE_DESCRIPTORS {
		descriptor := &FEATURE_DESCRIPTORS[i]
		if descriptor.mode == mode {
			return descriptor, true
		}
	}
	return nil, false
}

feature_descriptor_by_id :: proc(id: Feature_Id) -> (^Feature_Descriptor, bool) {
	for _, i in FEATURE_DESCRIPTORS {
		descriptor := &FEATURE_DESCRIPTORS[i]
		if descriptor.id == id {
			return descriptor, true
		}
	}
	return nil, false
}

feature_has_capability :: proc(descriptor: ^Feature_Descriptor, capability: Feature_Capability) -> bool {
	return descriptor != nil && capability in descriptor.capabilities
}

feature_registry_validate :: proc() -> bool {
	if len(FEATURE_DESCRIPTORS) != len(APP_SIMULATION_NAMES) || len(FEATURE_DESCRIPTORS) != len(APP_SIMULATION_DESCRIPTIONS) {
		return false
	}
	for descriptor, i in FEATURE_DESCRIPTORS {
		if descriptor.id == Feature_Id(0) || len(descriptor.name) == 0 || len(descriptor.short_description) == 0 {
			return false
		}
		if descriptor.draw_ui == nil || descriptor.enter == nil || descriptor.leave == nil do return false
		if .Simulation in descriptor.capabilities == .Tool in descriptor.capabilities {
			return false
		}
		if .Simulation in descriptor.capabilities && (descriptor.settings_size <= 0 || descriptor.settings_alignment <= 0 || descriptor.settings_defaults == nil || descriptor.settings_validate == nil || descriptor.settings_copy == nil) {
			return false
		}
		if .Simulation in descriptor.capabilities && descriptor.runtime_size <= 0 {
			return false
		}
		if .Simulation in descriptor.capabilities && (descriptor.color_scheme_access == nil || descriptor.apply_builtin_preset == nil || descriptor.apply_settings == nil || descriptor.reset == nil || descriptor.preset_load == nil || descriptor.preset_save == nil || descriptor.update == nil || descriptor.builtin_preset_names == nil || descriptor.apply_input == nil || descriptor.set_paused == nil) {
			return false
		}
		if .Tool in descriptor.capabilities && (descriptor.settings_size != 0 || descriptor.settings_alignment != 0 || descriptor.color_scheme_access != nil || descriptor.apply_builtin_preset != nil || descriptor.apply_settings != nil || descriptor.reset != nil || descriptor.preset_load != nil || descriptor.preset_save != nil || descriptor.update != nil || descriptor.builtin_preset_names != nil || descriptor.apply_input != nil || descriptor.set_paused != nil) {
			return false
		}
		if (descriptor.runtime_size == 0) != (descriptor.runtime_alignment == 0) {
			return false
		}
		if descriptor.runtime_size > 0 && descriptor.runtime_initialize == nil {
			return false
		}
		if .Live_Preview in descriptor.capabilities && (descriptor.preview.width == 0 || descriptor.preview.height == 0 || descriptor.preview.update_stride == 0) {
			return false
		}
		if (.Image_Source in descriptor.capabilities) != (descriptor.image_target_count > 0) || descriptor.image_target_count < 0 || descriptor.image_target_count > len(descriptor.image_targets) {
			return false
		}
		for target_index in 0 ..< descriptor.image_target_count {
			for prior_index in 0 ..< target_index {
				if descriptor.image_targets[target_index] == descriptor.image_targets[prior_index] do return false
			}
		}
		if descriptor.name != APP_SIMULATION_NAMES[i] || descriptor.short_description != APP_SIMULATION_DESCRIPTIONS[i] {
			return false
		}
		for other in FEATURE_DESCRIPTORS[i + 1:] {
			if descriptor.id == other.id || descriptor.mode == other.mode {
				return false
			}
			for target_index in 0 ..< descriptor.image_target_count {
				for other_target_index in 0 ..< other.image_target_count {
					if descriptor.image_targets[target_index] == other.image_targets[other_target_index] do return false
				}
			}
		}
	}
	return true
}
