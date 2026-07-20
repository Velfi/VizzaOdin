package game

import uifw "zelda_engine:ui"
import "core:fmt"

feature_defaults_st_flip :: proc(out: rawptr) -> bool {
	if out == nil do return false
	(cast(^ST_Flip_Settings)out)^ = st_flip_default_settings()
	return true
}

feature_settings_validate_st_flip :: proc(value: rawptr) -> bool {
	if value == nil do return false
	st_flip_validate_settings(cast(^ST_Flip_Settings)value)
	return true
}

feature_runtime_initialize_st_flip :: proc(runtime: rawptr) -> bool {
	if runtime == nil do return false
	(cast(^ST_Flip_Runtime_State)runtime)^ = st_flip_runtime_defaults()
	return true
}

feature_color_access_st_flip :: proc(settings: rawptr) -> (^Color_Scheme_Name, ^bool, bool) {
	if settings == nil do return nil, nil, false
	value := cast(^ST_Flip_Settings)settings
	return &value.color_scheme, &value.color_scheme_reversed, true
}

feature_apply_builtin_st_flip :: proc(settings, runtime: rawptr, index: int) -> bool {
	if settings == nil || runtime == nil do return false
	value := cast(^ST_Flip_Settings)settings
	preserved_name := value.color_scheme
	preserved_reversed := value.color_scheme_reversed
	value^ = st_flip_default_settings()
	value.color_scheme = preserved_name
	value.color_scheme_reversed = preserved_reversed
	switch index {
	case 1:
		value.ink_dissipation = 0.04
	case 2:
		value.flip_ratio = 0.995
	case 3:
		value.ink_dissipation = 0.01
	case:
	}
	state := cast(^ST_Flip_Runtime_State)runtime
	state.reset_requested = true
	state.builtin_preset_index = max(min(index, len(ST_FLIP_BUILTIN_PRESET_NAMES) - 1), 0)
	return true
}

feature_apply_settings_st_flip :: proc(settings, runtime, incoming: rawptr) -> bool {
	if settings == nil || runtime == nil || incoming == nil do return false
	value := (cast(^ST_Flip_Settings)incoming)^
	st_flip_validate_settings(&value)
	(cast(^ST_Flip_Settings)settings)^ = value
	(cast(^ST_Flip_Runtime_State)runtime).reset_requested = true
	return true
}

feature_reset_st_flip :: proc(settings, runtime: rawptr, command: ^Feature_Reset_Command) -> bool {
	if settings == nil || runtime == nil do return false
	state := cast(^ST_Flip_Runtime_State)runtime
	state.time = 0
	state.previous_dt = 0
	state.reset_requested = true
	if command != nil && command.randomize {
		(cast(^ST_Flip_Settings)settings).random_seed += 1
	}
	return true
}

feature_preset_load_st_flip :: proc(settings, runtime: rawptr, path: string) -> bool {
	if settings == nil || runtime == nil do return false
	current := (cast(^ST_Flip_Settings)settings)^
	value, ok := settings_load_st_flip_preset(path, current)
	return ok && feature_apply_settings_st_flip(settings, runtime, &value)
}

feature_preset_save_st_flip :: proc(settings, runtime: rawptr, path: string) -> bool {
	_ = runtime
	return settings != nil && settings_save_st_flip(path, (cast(^ST_Flip_Settings)settings)^)
}

feature_update_st_flip :: proc(settings, runtime: rawptr, dt: f32) -> bool {
	if settings == nil || runtime == nil do return false
	value := cast(^ST_Flip_Settings)settings
	state := cast(^ST_Flip_Runtime_State)runtime
	if !value.paused {
		state.previous_dt = max(dt * value.simulation_speed, 0)
		state.time += state.previous_dt
	}
	return true
}

feature_builtin_presets_st_flip :: proc() -> []string {return ST_FLIP_BUILTIN_PRESET_NAMES[:]}

feature_apply_input_st_flip :: proc(settings, runtime: rawptr, input: Ui_Frame_Input) -> bool {
	if settings == nil || runtime == nil do return false
	state := cast(^ST_Flip_Runtime_State)runtime
	if input.window_width <= 0 || input.window_height <= 0 {
		state.cursor_active = false
		return true
	}
	previous := state.cursor_world
	w := max(f32(input.window_width), 1)
	h := max(f32(input.window_height), 1)
	state.cursor_world = {input.mouse_pos.x / w, 1 - input.mouse_pos.y / h}
	dt := max(input.delta_time, f32(1.0 / 240.0))
	was_active := state.cursor_active
	state.cursor_velocity = was_active ? [2]f32{(state.cursor_world[0] - previous[0]) / dt, (state.cursor_world[1] - previous[1]) / dt} : [2]f32{0, 0}
	state.cursor_world_previous = previous
	state.cursor_active = input.mouse_down || input.actions.primary.down || input.actions.secondary.down
	state.cursor_mode = (input.mouse_button == 3 || input.actions.secondary.down) ? .Erase : state.interaction_mode
	return true
}

feature_draw_ui_st_flip :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, viewport: uifw.Vec2, worker: ^Product_Context) {
	sim := &ui.st_flip
	if gui.input.pause do sim.settings.paused = !sim.settings.paused
	if ui.simulation_shell.controls_visible {
		app_ui_draw_simulation_bar(ui, gui, .ST_FLIP, nil, nil, nil, sim.settings.paused, false, "ST-FLIP · Ink bath", viewport, viewport.x, worker)
	}
	simulation_controller_ui_draw(ui, gui, st_flip = sim, width = viewport.x, height = viewport.y, worker = worker)
}

feature_set_paused_st_flip :: proc(settings, runtime: rawptr, paused: bool) -> bool {
	_ = runtime
	if settings == nil do return false
	(cast(^ST_Flip_Settings)settings).paused = paused
	return true
}

feature_lifecycle_leave_st_flip :: proc(settings, runtime: rawptr) {
	_ = feature_set_paused_st_flip(settings, runtime, true)
}

st_flip_control_tooltip :: proc(gui: ^uifw.Gui_Context, key, text: string) {
	uifw.gui_tooltip_for_id(gui, uifw.gui_make_id(gui, key), text)
}

feature_draw_controls_st_flip :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect: uifw.Rect, worker: ^Product_Context, section: int, scroll: ^f32) {
	settings := ui.st_flip.settings
	content_height := max(rect.h, (gui.style.row_height + gui.style.spacing) * 13 + gui.style.heading_line_height * 3)
	uifw.gui_scroll_begin(gui, rect, content_height, scroll)
	defer uifw.gui_scroll_end(gui)
	switch section {
	case CONTROLLER_SECTION_PRESETS:
		uifw.gui_heading(gui, "Presets")
		preset_fieldset_draw(gui, &ui.st_flip.runtime.preset_ui, worker, "st_flip", ST_FLIP_BUILTIN_PRESET_NAMES[:], ui.st_flip.runtime.builtin_preset_index, Preset_Fieldset_Builtin_Context{kind=.ST_Flip, st_flip=&ui.st_flip})
		uifw.gui_spacer(gui, 8)
		uifw.gui_heading(gui, "Start Over")
		if uifw.gui_button(gui, "Reset", "st_flip_reset") {ui.st_flip.runtime.reset_requested = true}
		st_flip_control_tooltip(gui, "st_flip_reset", "Clear the ink and velocity fields, then restart the selected initial condition.")
		if uifw.gui_button(gui, "Randomize Seed", "st_flip_randomize") {settings.random_seed += 1; ui.st_flip.runtime.reset_requested = true}
		st_flip_control_tooltip(gui, "st_flip_randomize", "Choose a new deterministic seed and restart the simulation.")
		if uifw.gui_button(gui, "Seed Ink Noise", "st_flip_seed_noise") {ui.st_flip.runtime.noise_seed_requested = true}
		st_flip_control_tooltip(gui, "st_flip_seed_noise", "Fill the ink field with smooth multiscale noise generated from the current seed.")
	case CONTROLLER_SECTION_LOOK:
		uifw.gui_heading(gui, "Look")
		_ = color_scheme_editor_draw_selector(gui, &ui.color_scheme_editor, "st_flip_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Surface Smoothing: %.2f", settings.render_smoothing), "st_flip_smoothing", &settings.render_smoothing, 0.02, 0, 1)
		st_flip_control_tooltip(gui, "st_flip_smoothing", "Smooth the displayed ink field. This affects presentation, not the simulation.")
		_ = shared_post_processing_menu(gui, &settings.post_processing.blur_enabled, &settings.post_processing.blur_radius, &settings.post_processing.blur_sigma, shared_default_post_processing_menu_options())
	case ST_FLIP_SECTION_FLUID:
		uifw.gui_heading(gui, "Fluid")
		if uifw.gui_selector(gui, fmt.tprintf("Initial: %s", ST_FLIP_INITIAL_CONDITION_NAMES[settings.initial_condition_index]), "st_flip_initial", &settings.initial_condition_index, ST_FLIP_INITIAL_CONDITION_NAMES[:]) {settings.initial_condition = ST_Flip_Initial_Condition(settings.initial_condition_index); ui.st_flip.runtime.reset_requested = true}
		st_flip_control_tooltip(gui, "st_flip_initial", "Choose the particle layout used after Reset. Ink Bath fills the top-down basin.")
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Gravity: %.2f", settings.gravity), "st_flip_gravity", &settings.gravity, 0.1, -20, 20)
		st_flip_control_tooltip(gui, "st_flip_gravity", "Apply vertical acceleration in the simulation plane. Leave at zero for a top-down ink bath.")
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("FLIP Ratio: %.2f", settings.flip_ratio), "st_flip_ratio", &settings.flip_ratio, 0.01, 0, 1)
		st_flip_control_tooltip(gui, "st_flip_ratio", "Blend PIC stability with FLIP detail. Higher values preserve motion but can retain more noise.")
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Ink Dissipation: %.2f", settings.ink_dissipation), "st_flip_ink_dissipation", &settings.ink_dissipation, 0.02, 0, 5)
		st_flip_control_tooltip(gui, "st_flip_ink_dissipation", "Control how quickly injected ink fades. Zero preserves ink indefinitely.")
	case ST_FLIP_SECTION_TIME:
		uifw.gui_heading(gui, "Space-Time")
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Simulation Speed: %.2fx", settings.simulation_speed), "st_flip_speed", &settings.simulation_speed, 0.05, 0.05, 4)
		st_flip_control_tooltip(gui, "st_flip_speed", "Scale simulated time relative to real time.")
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Target CFL: %.2f", settings.target_cfl), "st_flip_cfl", &settings.target_cfl, 0.25, 0.25, 30)
		st_flip_control_tooltip(gui, "st_flip_cfl", "Target particle travel per global step, measured in grid cells. Larger values favor speed over accuracy.")
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Time Jitter: %.2f", settings.jitter_strength), "st_flip_jitter", &settings.jitter_strength, 0.01, 0, 1)
		st_flip_control_tooltip(gui, "st_flip_jitter", "Distribute particle sample times across each step to reduce temporal aliasing at large CFL values.")
	case ST_FLIP_SECTION_BRUSH:
		uifw.gui_heading(gui, "Brush")
		runtime := ui.st_flip.runtime
		if uifw.gui_combobox(gui, fmt.tprintf("Tool: %s", ST_FLIP_INTERACTION_MODE_NAMES[runtime.interaction_mode_index]), "st_flip_interaction", &runtime.interaction_mode_index, ST_FLIP_INTERACTION_MODE_NAMES[:], runtime.brush_mode_query[:]) {
			runtime.interaction_mode = ST_FLIP_INTERACTION_MODES[runtime.interaction_mode_index]
		}
		st_flip_control_tooltip(gui, "st_flip_interaction", "Stir follows pointer motion; Inject adds ink while stirring; Vortex spins fluid around the pointer. Use the secondary action to erase ink with any tool.")
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Brush Size: %.3f", runtime.brush_size), "st_flip_brush_size", &runtime.brush_size, 0.005, 0.005, 0.3)
		st_flip_control_tooltip(gui, "st_flip_brush_size", "Set the aspect-correct radius of the active brush.")
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Brush Strength: %.2f", runtime.brush_strength), "st_flip_brush_strength", &runtime.brush_strength, 0.1, 0, 10)
		st_flip_control_tooltip(gui, "st_flip_brush_strength", "Set ink deposition, erasing, stirring, or vortex force for the selected tool.")
	case:
		uifw.gui_heading(gui, "Advanced")
		resolution_index := st_flip_resolution_index(settings.grid_height)
		if uifw.gui_selector(gui, fmt.tprintf("Resolution: %s", ST_FLIP_RESOLUTION_NAMES[resolution_index]), "st_flip_resolution", &resolution_index, ST_FLIP_RESOLUTION_NAMES[:]) {
			st_flip_apply_resolution(settings, resolution_index)
			ui.st_flip.runtime.reset_requested = true
		}
		st_flip_control_tooltip(gui, "st_flip_resolution", "Scale grid and particle counts together. Higher resolutions improve detail but sharply increase GPU memory and cost.")
		_ = uifw.gui_numeric_u32(gui, "Pressure Iterations", "st_flip_pressure", &settings.pressure_iterations, 8, 256, 8)
		st_flip_control_tooltip(gui, "st_flip_pressure", "Set fixed Jacobi iterations for incompressibility. More iterations reduce divergence at additional GPU cost.")
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Phase Steepness: %.2f", settings.phase_steepness), "st_flip_phase", &settings.phase_steepness, 0.05, 0.1, 1.5)
		st_flip_control_tooltip(gui, "st_flip_phase", "Control how deposited particle mass becomes the liquid phase field. Lower values produce a fuller, sharper liquid region.")
	}
}
