package game

import uifw "../ui"

import "core:fmt"
import "core:math"

remaining_sim_draw_moire_menu :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, color_editor: ^Color_Scheme_Editor_State, worker: ^Product_Context = nil) {
	remaining_sim_draw_moire_display_settings(sim, gui, color_editor, worker)
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Controls")
	uifw.gui_label(gui, "Mouse wheel: Zoom | Drag: Pan camera")
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Actions")
	remaining_sim_draw_settings_actions(sim, gui, "Reset Moire Settings")
	uifw.gui_spacer(gui, 8)
	remaining_sim_draw_moire_animation(sim, gui)
	uifw.gui_spacer(gui, 8)
	remaining_sim_draw_moire_patterns(sim, gui)
	if sim.moire.generator_type == .Radial {
		uifw.gui_spacer(gui, 8)
		remaining_sim_draw_moire_radial(sim, gui)
	}
	uifw.gui_spacer(gui, 8)
	remaining_sim_draw_moire_advection(sim, gui)
}

remaining_sim_draw_moire_display_settings :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, color_editor: ^Color_Scheme_Editor_State, worker: ^Product_Context = nil) {
	settings := &sim.moire
	uifw.gui_heading(gui, "Display Settings")
	_ = color_scheme_editor_draw_selector(gui, color_editor, "moire_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Image Mode: %v", settings.image_mode_enabled), "image_mode", &settings.image_mode_enabled)
	if !settings.image_mode_enabled {
		return
	}
	if uifw.gui_selector(gui, fmt.tprintf("Interference Mode: %s", MOIRE_INTERFERENCE_MODE_NAMES[settings.interference_index]), "image_interference", &settings.interference_index, MOIRE_INTERFERENCE_MODE_NAMES[:]) {
		settings.image_interference_mode = Moire_Image_Interference_Mode(settings.interference_index)
	}
	image_options := shared_default_image_selector_options()
	image_options.fit_label = "Image Fit"
	image_options.fit_key = "moire_image_fit"
	image_options.load_label = "Reload Selected"
	image_options.load_key = "moire_load_png"
	image_options.browse_label = "Choose Image..."
	image_options.browse_key = "moire_browse_png"
	image_options.clear_key = "moire_clear_image"
	image_options.selected_label = "Selected Image"
	image_options.empty_label = fmt.tprintf("No image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
	image_options.selected_path = fixed_string(settings.image_path[:])
	image_result := shared_image_selector(gui, &settings.image_fit_index, VECTOR_IMAGE_FIT_MODE_NAMES[:], image_options)
	remaining_sim_webcam_capture_control(sim, gui, worker, .Load_Moire_Image, "moire_capture_webcam")
	reload_image := false
	if image_result.fit_changed {
		settings.image_fit_mode = Vector_Image_Fit_Mode(settings.image_fit_index)
		reload_image = true
	}
	if image_result.browse_requested {
		sim.moire_image_dialog_requested = true
	}
	if image_result.load_requested || reload_image {
		remaining_sim_enqueue_image_command(worker, .Load_Moire_Image, fixed_string(settings.image_path[:]))
	}
	if image_result.clear_requested {
		remaining_sim_enqueue_image_command(worker, .Clear_Moire_Image)
	}
	_ = uifw.gui_toggle(gui, fmt.tprintf("Mirror Horizontal: %v", settings.image_mirror_horizontal), "mirror_h", &settings.image_mirror_horizontal)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Mirror Vertical: %v", settings.image_mirror_vertical), "mirror_v", &settings.image_mirror_vertical)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Invert Tone: %v", settings.image_invert_tone), "invert_tone", &settings.image_invert_tone)
}

remaining_sim_draw_moire_animation :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context) {
	settings := &sim.moire
	uifw.gui_heading(gui, "Animation")
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Speed: %.2f", settings.speed), "moire_speed", &settings.speed, 0.01, 0, 5)
}

remaining_sim_draw_moire_patterns :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context) {
	settings := &sim.moire
	uifw.gui_heading(gui, "Moire Patterns")
	if uifw.gui_selector(gui, fmt.tprintf("Generator Type: %s", MOIRE_GENERATOR_TYPE_NAMES[settings.generator_index]), "generator_type", &settings.generator_index, MOIRE_GENERATOR_TYPE_NAMES[:]) {
		settings.generator_type = Moire_Generator_Type(settings.generator_index)
	}
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Base Frequency: %.2f", settings.base_freq), "base_freq", &settings.base_freq, 0.1, 0.1, 80)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Moire Amount: %.2f", settings.moire_amount), "moire_amount", &settings.moire_amount, 0.01, 0, 2)
	rotation_two_degrees := settings.moire_rotation * 180 / math.PI
	if shared_two_axis_pad_f32(gui, "Second Layer Transform", "moire_layer_two", "Rotation °", "Scale", &rotation_two_degrees, &settings.moire_scale, -360, 360, 0.1, 4) {
		settings.moire_rotation = rotation_two_degrees * math.PI / 180
	}
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Interference: %.2f", settings.moire_interference), "moire_interference", &settings.moire_interference, 0.01, 0, 1)
	rotation_three_degrees := settings.moire_rotation3 * 180 / math.PI
	if shared_two_axis_pad_f32(gui, "Third Layer Transform", "moire_layer_three", "Rotation °", "Scale", &rotation_three_degrees, &settings.moire_scale3, -360, 360, 0.1, 4) {
		settings.moire_rotation3 = rotation_three_degrees * math.PI / 180
	}
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Weight 3: %.2f", settings.moire_weight3), "moire_weight3", &settings.moire_weight3, 0.01, 0, 1)
}

remaining_sim_draw_moire_radial :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context) {
	settings := &sim.moire
	uifw.gui_heading(gui, "Radial Pattern Settings")
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Swirl: %.2f", settings.radial_swirl_strength), "radial_swirl", &settings.radial_swirl_strength, 0.01, 0, 1)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Starburst: %.1f", settings.radial_starburst_count), "radial_starburst", &settings.radial_starburst_count, 0.5, 1, 64)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Center Brightness: %.2f", settings.radial_center_brightness), "radial_center", &settings.radial_center_brightness, 0.01, 0, 4)
}

remaining_sim_draw_moire_advection :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context) {
	settings := &sim.moire
	uifw.gui_heading(gui, "Advection Flow")
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Advect Strength: %.2f", settings.advect_strength), "advect_strength", &settings.advect_strength, 0.01, 0, 2)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Advect Speed: %.2f", settings.advect_speed), "advect_speed", &settings.advect_speed, 0.01, 0, 5)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Curl: %.2f", settings.curl), "curl", &settings.curl, 0.01, 0, 2)
	shared_control_explanation(gui, "curl", "Curl controls how strongly the flow bends into swirls and rolling eddies.")
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Decay: %.2f", settings.decay), "decay", &settings.decay, 0.001, 0.8, 1)
}

remaining_sim_draw_vectors_menu :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, color_editor: ^Color_Scheme_Editor_State, worker: ^Product_Context = nil) {
	remaining_sim_draw_vectors_color(sim, gui, color_editor)
	uifw.gui_spacer(gui, 8)
	remaining_sim_draw_vectors_field(sim, gui, worker)
}

remaining_sim_draw_vectors_color :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, color_editor: ^Color_Scheme_Editor_State) {
	settings := &sim.vectors
	uifw.gui_heading(gui, "Color")
	if uifw.gui_selector(gui, fmt.tprintf("Background: %s", VECTOR_BACKGROUND_MODE_NAMES[settings.background_index]), "vectors_background", &settings.background_index, VECTOR_BACKGROUND_MODE_NAMES[:]) {
		settings.background_color_mode = Vector_Background_Mode(settings.background_index)
	}
	_ = color_scheme_editor_draw_selector(gui, color_editor, "vectors_color_scheme", &settings.color_scheme, &settings.color_scheme_reversed)
}

remaining_sim_draw_vectors_field :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, worker: ^Product_Context = nil) {
	settings := &sim.vectors
	uifw.gui_heading(gui, "Vector Field")
	if uifw.gui_selector(gui, fmt.tprintf("Vector Field: %s", VECTOR_FIELD_TYPE_NAMES[settings.vector_field_index]), "vector_field", &settings.vector_field_index, VECTOR_FIELD_TYPE_NAMES[:]) {
		settings.vector_field_type = Vector_Field_Type(settings.vector_field_index)
	}
	if settings.vector_field_type == .Image {
		image_options := shared_default_image_selector_options()
		image_options.fit_label = "Image Fit"
		image_options.fit_key = "vector_image_fit"
		image_options.load_label = "Reload Selected"
		image_options.load_key = "vector_load_png"
		image_options.browse_label = "Choose Image..."
		image_options.browse_key = "vector_browse_png"
		image_options.clear_key = "vector_clear_image"
		image_options.selected_label = "Selected Image"
		image_options.empty_label = fmt.tprintf("No image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
		image_options.selected_path = fixed_string(settings.image_path[:])
		image_result := shared_image_selector(gui, &settings.image_fit_index, VECTOR_IMAGE_FIT_MODE_NAMES[:], image_options)
		remaining_sim_webcam_capture_control(sim, gui, worker, .Load_Vectors_Image, "vectors_capture_webcam")
		if image_result.fit_changed {
			settings.image_fit_mode = Vector_Image_Fit_Mode(settings.image_fit_index)
		}
		if image_result.browse_requested {
			sim.vectors_image_dialog_requested = true
		}
		if image_result.load_requested {
			remaining_sim_enqueue_image_command(worker, .Load_Vectors_Image, fixed_string(settings.image_path[:]))
		}
		if image_result.clear_requested {
			remaining_sim_enqueue_image_command(worker, .Clear_Vectors_Image)
		}
		_ = uifw.gui_toggle(gui, fmt.tprintf("Mirror Horizontal: %v", settings.image_mirror_horizontal), "vector_mirror_h", &settings.image_mirror_horizontal)
		_ = uifw.gui_toggle(gui, fmt.tprintf("Mirror Vertical: %v", settings.image_mirror_vertical), "vector_mirror_v", &settings.image_mirror_vertical)
		_ = uifw.gui_toggle(gui, fmt.tprintf("Invert Tone: %v", settings.image_invert_tone), "vector_invert", &settings.image_invert_tone)
	} else if settings.vector_field_type == .Noise {
		_ = draw_noise_settings_controls(gui, &settings.noise, "vectors_noise")
	}
	if uifw.gui_selector(gui, fmt.tprintf("Display: %s", VECTOR_DISPLAY_MODE_NAMES[settings.display_index]), "vector_display", &settings.display_index, VECTOR_DISPLAY_MODE_NAMES[:]) {
		settings.display_mode = Vector_Display_Mode(settings.display_index)
	}
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Density: %.3f", settings.density), "vector_density", &settings.density, 0.001, VECTORS_MIN_DENSITY, 0.1)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Line Length: %.3f", settings.line_length), "line_length", &settings.line_length, 0.001, 0.005, 1)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Line Width: %.3f", settings.line_width), "line_width", &settings.line_width, 0.001, 0.001, 1)
	if uifw.gui_button(gui, "Reset", "vectors_reset") {
		remaining_sim_reset_with_undo(sim)
		uifw.gui_notice(gui, "Vector field returned to defaults. Restore Settings Before Reset is available here.")
	}
	if sim.reset_undo.available && uifw.gui_button(gui, "Restore Settings Before Reset", "vectors_undo_reset") {
		if remaining_sim_undo_reset(sim) {
			uifw.gui_notice(gui, "Vector settings from before reset restored.")
		}
	}
}

remaining_sim_draw_primordial_settings :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, subsection := -1) {
	settings := &sim.primordial
	if subsection < 0 || subsection == 0 {
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, subsection == 0 ? "Population" : "Particle Configuration")
	if uifw.gui_selector(gui, fmt.tprintf("Position Generator: %s", PRIMORDIAL_POSITION_GENERATOR_NAMES[settings.position_generator_index]), "primordial_position_generator", &settings.position_generator_index, PRIMORDIAL_POSITION_GENERATOR_NAMES[:]) {
		settings.position_generator = u32(settings.position_generator_index)
	}
	_ = uifw.gui_numeric_u32(gui, "Particle Count", "primordial_particle_count", &settings.particle_count, 100, 500000, 100)
	_ = uifw.gui_numeric_u32(gui, "Random Seed", "primordial_seed", &settings.random_seed, 0, ~u32(0))
	}
	if subsection < 0 || subsection == 1 {
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, subsection == 1 ? "Motion" : "Physics Parameters")
	_ = shared_two_axis_pad_f32(gui, "Rotation Response", "primordial_rotation", "Alpha", "Beta", &settings.alpha, &settings.beta, -180, 180, -60, 60)
	shared_control_explanation(gui, "primordial_rotation", "Alpha and Beta are the two rotation-response angles. Together they decide how particles turn around neighbors.")
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Velocity: %.2f", settings.velocity), "velocity", &settings.velocity, 0.01, 0.01, 2)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Radius: %.3f", settings.radius), "radius", &settings.radius, 0.001, 0.001, 0.5)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Time Step: %.3f", settings.dt), "primordial_dt", &settings.dt, 0.001, 0, 0.25)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Collisions: %v", settings.collision_enabled), "primordial_collisions", &settings.collision_enabled)
	if settings.collision_enabled {
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Collision Relaxation: %.2f", settings.collision_relaxation), "primordial_collision_relaxation", &settings.collision_relaxation, 0.05, 0, 1)
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Collision Damping: %.2f", settings.collision_damping), "primordial_collision_damping", &settings.collision_damping, 0.01, 0, 1)
	}
	shared_control_explanation(gui, "primordial_dt", "Time Step is how much simulated time moves forward per update. Higher is faster but less precise.")
	_ = uifw.gui_toggle(gui, fmt.tprintf("Wrap Edges: %v", settings.wrap_edges), "wrap_edges", &settings.wrap_edges)
	}
}

remaining_sim_draw_voronoi_settings :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, heading := "Voronoi Parameters") {
	settings := &sim.voronoi
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, heading)
	interaction_help := "Canvas: drag attracts, right-drag repels, Shift-drag plucks and flings, click releases a shockwave, and Ctrl-drag/right-drag paints or erases sites."
	if gui.input.active_device == .Controller {
		interaction_help = "Canvas: primary attracts, secondary repels, right-stick up + primary plucks, right-stick down + primary/secondary paints or erases, and a trigger tap releases a shockwave."
	}
	shared_control_explanation(gui, "voronoi_playground", interaction_help)
	_ = uifw.gui_numeric_u32(gui, "Points", "voronoi_points", &settings.point_count, 32, 20000, 100)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Drift: %.2f", settings.drift), "voronoi_drift", &settings.drift, 0.01, 0, 4)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Brownian Speed: %.1f", settings.brownian_speed), "voronoi_brownian_speed", &settings.brownian_speed, 1, 0, 500)
	shared_control_explanation(gui, "voronoi_brownian_speed", "Brownian Speed adds random wandering to the sites that shape the Voronoi cells.")
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Time Scale: %.2f", settings.time_scale), "voronoi_time_scale", &settings.time_scale, 0.01, 0, 10)
	_ = uifw.gui_numeric_u32(gui, "Random Seed", "random_seed", &settings.random_seed, 0, ~u32(0))
}

remaining_sim_draw_pellets_settings :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, subsection := -1) {
	settings := &sim.pellets
	if subsection < 0 || subsection == 0 {
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Particle")
	_ = uifw.gui_numeric_u32(gui, "Particle Count", "particle_count", &settings.particle_count, 100, 500000, 100)
	_ = uifw.gui_numeric_u32(gui, "Random Seed", "pellets_seed", &settings.random_seed, 0, ~u32(0))
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Particle Size: %.3f", settings.particle_size), "particle_size", &settings.particle_size, 0.001, 0.001, 0.1)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Collision Damping: %.2f", settings.collision_damping), "collision_damping", &settings.collision_damping, 0.01, 0, 1)
	_ = shared_range_slider_f32(gui, "Initial Velocity", "pellets_initial_velocity", &settings.initial_velocity_min, &settings.initial_velocity_max, 0, 2)
	}
	if subsection < 0 || subsection == 1 {
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Physics")
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Gravity Constant: %.7f", settings.gravitational_constant), "gravity_constant", &settings.gravitational_constant, 0.0000001, 0, 0.1)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Energy Damping: %.2f", settings.energy_damping), "energy_damping", &settings.energy_damping, 0.01, 0, 1)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Gravity Softening: %.3f", settings.gravity_softening), "gravity_softening", &settings.gravity_softening, 0.001, 0.0001, 0.1)
	shared_control_explanation(gui, "gravity_softening", "Gravity Softening prevents gravity from becoming extreme when pellets get very close.")
	_ = uifw.gui_toggle(gui, fmt.tprintf("Density Damping: %v", settings.density_damping_enabled), "density_damping", &settings.density_damping_enabled)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Overlap Resolution: %.2f", settings.overlap_resolution_strength), "overlap_resolution", &settings.overlap_resolution_strength, 0.01, 0, 1)
	}
}

remaining_sim_draw_flow_settings :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, worker: ^Product_Context = nil, subsection := -1) {
	settings := &sim.flow
	if subsection < 0 || subsection == 0 {
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Flow Field")
	if uifw.gui_selector(gui, fmt.tprintf("Vector Field: %s", VECTOR_FIELD_TYPE_NAMES[settings.vector_field_index]), "flow_vector_field", &settings.vector_field_index, VECTOR_FIELD_TYPE_NAMES[:]) {
		settings.vector_field_type = Vector_Field_Type(settings.vector_field_index)
	}
	if settings.vector_field_type == .Noise {
		_ = draw_noise_settings_controls(gui, &settings.noise, "flow_noise")
	}
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Vector Magnitude: %.2f", settings.vector_magnitude), "vector_magnitude", &settings.vector_magnitude, 0.01, 0, 2)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Animate Field: %v", settings.field_animation_enabled), "flow_field_animation", &settings.field_animation_enabled)
	if settings.field_animation_enabled {
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Animation Speed: %.2f", settings.field_animation_speed), "flow_field_animation_speed", &settings.field_animation_speed, 0.01, -2, 2)
	}
	if settings.vector_field_type == .Image {
		image_options := shared_default_image_selector_options()
		image_options.fit_label = "Image Fit"
		image_options.fit_key = "flow_image_fit"
		image_options.load_label = "Reload Selected"
		image_options.load_key = "flow_load_png"
		image_options.browse_label = "Choose Image..."
		image_options.browse_key = "flow_browse_png"
		image_options.clear_key = "flow_clear_image"
		image_options.selected_label = "Selected Image"
		image_options.empty_label = fmt.tprintf("No image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
		image_options.selected_path = fixed_string(settings.image_path[:])
		image_result := shared_image_selector(gui, &settings.image_fit_index, VECTOR_IMAGE_FIT_MODE_NAMES[:], image_options)
		remaining_sim_webcam_capture_control(sim, gui, worker, .Load_Flow_Image, "flow_capture_webcam")
		reload_image := false
		if image_result.fit_changed {
			settings.image_fit_mode = Vector_Image_Fit_Mode(settings.image_fit_index)
			reload_image = true
		}
		if image_result.browse_requested {
			sim.flow_image_dialog_requested = true
		}
		if image_result.load_requested {
			reload_image = true
		}
		if uifw.gui_toggle(gui, fmt.tprintf("Mirror Horizontal: %v", settings.image_mirror_horizontal), "flow_mirror_h", &settings.image_mirror_horizontal) {
			reload_image = true
		}
		if uifw.gui_toggle(gui, fmt.tprintf("Mirror Vertical: %v", settings.image_mirror_vertical), "flow_mirror_v", &settings.image_mirror_vertical) {
			reload_image = true
		}
		if uifw.gui_toggle(gui, fmt.tprintf("Invert Tone: %v", settings.image_invert_tone), "flow_invert", &settings.image_invert_tone) {
			reload_image = true
		}
		if reload_image {
			remaining_sim_enqueue_image_command(worker, .Load_Flow_Image, fixed_string(settings.image_path[:]))
		}
		if image_result.clear_requested {
			remaining_sim_enqueue_image_command(worker, .Clear_Flow_Image)
		}
	}
	}
	if subsection < 0 || subsection == 1 {
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Particles")
	if uifw.gui_selector(gui, fmt.tprintf("Shape: %s", FLOW_PARTICLE_SHAPE_NAMES[settings.shape_index]), "flow_shape", &settings.shape_index, FLOW_PARTICLE_SHAPE_NAMES[:]) {
		settings.particle_shape = Flow_Particle_Shape(settings.shape_index)
	}
	_ = uifw.gui_numeric_u32(gui, "Pool Size", "flow_pool", &settings.total_pool_size, 100, 1000000, 1000)
	lifetime := settings.particle_lifetime
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Lifetime: %.2f", lifetime), "flow_lifetime", &settings.particle_lifetime, 0.1, 0.1, 60)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Particle Speed: %.2f", settings.particle_speed), "flow_speed", &settings.particle_speed, 0.01, 0, 10)
	_ = uifw.gui_numeric_u32(gui, "Particle Size", "flow_size", &settings.particle_size, 1, 64)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Autospawn: %v", settings.particle_autospawn), "flow_autospawn", &settings.particle_autospawn)
	if uifw.gui_selector(gui, fmt.tprintf("Emitter: %s", FLOW_EMITTER_MODE_NAMES[settings.emitter_index]), "flow_emitter", &settings.emitter_index, FLOW_EMITTER_MODE_NAMES[:]) {
		settings.emitter_mode = Flow_Emitter_Mode(settings.emitter_index)
	}
	if settings.emitter_mode == .Ring {
		_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Emitter Radius: %.2f", settings.emitter_radius), "flow_emitter_radius", &settings.emitter_radius, 0.01, 0, 1)
	}
	if uifw.gui_selector(gui, fmt.tprintf("Boundary: %s", FLOW_BOUNDARY_MODE_NAMES[settings.boundary_index]), "flow_boundary", &settings.boundary_index, FLOW_BOUNDARY_MODE_NAMES[:]) {
		settings.boundary_mode = Flow_Boundary_Mode(settings.boundary_index)
	}
	_ = uifw.gui_toggle(gui, fmt.tprintf("Show Particles: %v", settings.show_particles), "flow_show_particles", &settings.show_particles)
	_ = uifw.gui_numeric_u32(gui, "Autospawn Rate", "flow_autospawn_rate", &settings.autospawn_rate, 0, 100000, 10)
	_ = uifw.gui_numeric_u32(gui, "Brush Spawn Rate", "flow_brush_rate", &settings.brush_spawn_rate, 0, 100000, 10)
	}
	if subsection < 0 || subsection == 2 {
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Trails")
	if uifw.gui_selector(gui, fmt.tprintf("Style: %s", FLOW_TRAIL_STYLE_NAMES[settings.trail_style_index]), "flow_trail_style", &settings.trail_style_index, FLOW_TRAIL_STYLE_NAMES[:]) {
		settings.trail_style = Flow_Trail_Style(settings.trail_style_index)
	}
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Decay: %.2f", settings.trail_decay_rate), "trail_decay", &settings.trail_decay_rate, 0.01, 0, 10)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Deposition: %.2f", settings.trail_deposition_rate), "trail_deposition", &settings.trail_deposition_rate, 0.01, 0, 10)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Diffusion: %.2f", settings.trail_diffusion_rate), "trail_diffusion", &settings.trail_diffusion_rate, 0.01, 0, 10)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Wash Out: %.2f", settings.trail_wash_out_rate), "trail_wash_out", &settings.trail_wash_out_rate, 0.01, 0, 10)
	if uifw.gui_selector(gui, fmt.tprintf("Filtering: %s", FLOW_TRAIL_MAP_FILTERING_NAMES[settings.trail_filtering_index]), "flow_trail_filtering", &settings.trail_filtering_index, FLOW_TRAIL_MAP_FILTERING_NAMES[:]) {
		settings.trail_map_filtering = Flow_Trail_Map_Filtering(settings.trail_filtering_index)
	}
	}
}

remaining_sim_draw_slime_settings :: proc(sim: ^Remaining_Sim_State, gui: ^uifw.Gui_Context, worker: ^Product_Context = nil) {
	settings := &sim.slime
	if uifw.gui_numeric_u32(gui, "Agent Count", "slime_agent_count", &settings.agent_count, SLIME_MIN_AGENT_COUNT, SLIME_MAX_AGENT_COUNT) {
		slime_request_reset(sim)
	}
	if uifw.gui_selector(gui, fmt.tprintf("Trail Filtering: %s", FLOW_TRAIL_MAP_FILTERING_NAMES[settings.trail_filtering_index]), "slime_trail_filtering", &settings.trail_filtering_index, FLOW_TRAIL_MAP_FILTERING_NAMES[:]) {
		settings.trail_map_filtering = Flow_Trail_Map_Filtering(settings.trail_filtering_index)
	}
	_ = uifw.gui_numeric_u32(gui, "Random Seed", "slime_seed", &settings.random_seed, 0, ~u32(0))
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Pheromone")
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Decay Rate: %.1f", settings.pheromone_decay_rate), "pheromone_decay", &settings.pheromone_decay_rate, 1, 0, 200)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Deposition Rate: %.1f", settings.pheromone_deposition_rate), "pheromone_deposition", &settings.pheromone_deposition_rate, 1, 0, 200)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Diffusion Rate: %.1f", settings.pheromone_diffusion_rate), "pheromone_diffusion", &settings.pheromone_diffusion_rate, 1, 0, 200)
	_ = uifw.gui_numeric_u32(gui, "Diffusion Frequency", "diffusion_frequency", &settings.diffusion_frequency, 1, 128)
	_ = uifw.gui_numeric_u32(gui, "Decay Frequency", "decay_frequency", &settings.decay_frequency, 1, 128)
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Agent")
	if uifw.gui_selector(gui, fmt.tprintf("Position Generator: %s", SLIME_POSITION_GENERATOR_NAMES[settings.position_generator_index]), "slime_position_generator", &settings.position_generator_index, SLIME_POSITION_GENERATOR_NAMES[:]) {
		settings.position_generator = u32(settings.position_generator_index)
	}
	if settings.position_generator == 7 {
		position_options := shared_default_image_selector_options()
		position_options.fit_label = "Position Image Fit"
		position_options.fit_key = "slime_position_image_fit"
		position_options.load_label = "Reload Selected"
		position_options.load_key = "slime_position_load_png"
		position_options.browse_label = "Choose Image..."
		position_options.browse_key = "slime_position_browse_png"
		position_options.clear_key = "slime_position_clear_image"
		position_options.selected_label = "Selected Position Image"
		position_options.empty_label = fmt.tprintf("No position image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
		position_options.selected_path = fixed_string(settings.position_image_path[:])
		position_result := shared_image_selector(gui, &settings.position_image_fit_index, VECTOR_IMAGE_FIT_MODE_NAMES[:], position_options)
		remaining_sim_webcam_capture_control(sim, gui, worker, .Load_Slime_Position_Image, "slime_position_capture_webcam")
		reload_position_image := false
		if position_result.fit_changed {
			settings.position_image_fit_mode = Vector_Image_Fit_Mode(settings.position_image_fit_index)
			reload_position_image = true
		}
		if position_result.browse_requested {
			sim.slime_position_image_dialog_requested = true
		}
		if position_result.load_requested || reload_position_image {
			remaining_sim_enqueue_image_command(worker, .Load_Slime_Position_Image, fixed_string(settings.position_image_path[:]))
		}
		if position_result.clear_requested {
			remaining_sim_enqueue_image_command(worker, .Clear_Slime_Position_Image)
		}
	}
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Jitter: %.2f", settings.agent_jitter), "agent_jitter", &settings.agent_jitter, 0.01, 0, 1)
	_ = uifw.gui_toggle(gui, settings.isotropic_jitter ? "Isotropic Jitter: On" : "Isotropic Jitter: Off", "isotropic_jitter", &settings.isotropic_jitter)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Heading Start: %.1f", settings.agent_heading_start), "heading_start", &settings.agent_heading_start, 1, 0, 360)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Heading End: %.1f", settings.agent_heading_end), "heading_end", &settings.agent_heading_end, 1, 0, 360)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Sensor Angle: %.2f", settings.agent_sensor_angle), "sensor_angle", &settings.agent_sensor_angle, 0.01, 0, 3.14159)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Sensor Distance: %.1f", settings.agent_sensor_distance), "sensor_distance", &settings.agent_sensor_distance, 1, 0, 500)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Speed Min: %.1f", settings.agent_speed_min), "speed_min", &settings.agent_speed_min, 1, 0, 500)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Speed Max: %.1f", settings.agent_speed_max), "speed_max", &settings.agent_speed_max, 1, 0, 500)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Turn Rate: %.2f", settings.agent_turn_rate), "turn_rate", &settings.agent_turn_rate, 0.01, 0, 6.28318)
	uifw.gui_spacer(gui, 8)
	uifw.gui_heading(gui, "Mask")
	if uifw.gui_selector(gui, fmt.tprintf("Pattern: %s", SLIME_MASK_PATTERN_NAMES[settings.mask_pattern_index]), "slime_mask_pattern", &settings.mask_pattern_index, SLIME_MASK_PATTERN_NAMES[:]) {
		settings.mask_pattern = Slime_Mask_Pattern(settings.mask_pattern_index)
	}
	if uifw.gui_selector(gui, fmt.tprintf("Target: %s", SLIME_MASK_TARGET_NAMES[settings.mask_target_index]), "slime_mask_target", &settings.mask_target_index, SLIME_MASK_TARGET_NAMES[:]) {
		settings.mask_target = Slime_Mask_Target(settings.mask_target_index)
	}
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Strength: %.2f", settings.mask_strength), "slime_mask_strength", &settings.mask_strength, 0.01, 0, 1)
	_ = uifw.gui_numeric_f32(gui, fmt.tprintf("Curve: %.2f", settings.mask_curve), "slime_mask_curve", &settings.mask_curve, 0.01, 0.1, 4)
	if settings.mask_pattern == .Image {
		mask_options := shared_default_image_selector_options()
		mask_options.fit_label = "Mask Image Fit"
		mask_options.fit_key = "slime_mask_image_fit"
		mask_options.load_label = "Reload Selected"
		mask_options.load_key = "slime_mask_load_png"
		mask_options.browse_label = "Choose Image..."
		mask_options.browse_key = "slime_mask_browse_png"
		mask_options.clear_key = "slime_mask_clear_image"
		mask_options.selected_label = "Selected Mask Image"
		mask_options.empty_label = fmt.tprintf("No mask image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
		mask_options.selected_path = fixed_string(settings.mask_image_path[:])
		mask_result := shared_image_selector(gui, &settings.mask_image_fit_index, VECTOR_IMAGE_FIT_MODE_NAMES[:], mask_options)
		remaining_sim_webcam_capture_control(sim, gui, worker, .Load_Slime_Mask_Image, "slime_mask_capture_webcam")
		reload_mask_image := false
		if mask_result.fit_changed {
			settings.mask_image_fit_mode = Vector_Image_Fit_Mode(settings.mask_image_fit_index)
			reload_mask_image = true
		}
		if mask_result.browse_requested {
			sim.slime_mask_image_dialog_requested = true
		}
		if mask_result.load_requested || reload_mask_image {
			remaining_sim_enqueue_image_command(worker, .Load_Slime_Mask_Image, fixed_string(settings.mask_image_path[:]))
		}
		if mask_result.clear_requested {
			remaining_sim_enqueue_image_command(worker, .Clear_Slime_Mask_Image)
		}
	}
	_ = uifw.gui_toggle(gui, fmt.tprintf("Mirror Horizontal: %v", settings.mask_mirror_horizontal), "slime_mask_mirror_h", &settings.mask_mirror_horizontal)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Mirror Vertical: %v", settings.mask_mirror_vertical), "slime_mask_mirror_v", &settings.mask_mirror_vertical)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Invert Tone: %v", settings.mask_invert_tone), "slime_mask_invert", &settings.mask_invert_tone)
	_ = uifw.gui_toggle(gui, fmt.tprintf("Reverse Mask: %v", settings.mask_reversed), "slime_mask_reversed", &settings.mask_reversed)
}
