package game

import uifw "../ui"

import "core:math"
import sdl "vendor:sdl3"

Gray_Scott_Mask_Pattern :: enum u32 {
	Disabled = 0,
	Checkerboard = 1,
	Diagonal_Gradient = 2,
	Radial_Gradient = 3,
	Vertical_Stripes = 4,
	Horizontal_Stripes = 5,
	Wave_Function = 6,
	Cosine_Grid = 7,
	Nutrient_Map = 8,
}

Gray_Scott_Mask_Target :: enum u32 {
	Feed_Rate = 1,
	Kill_Rate = 2,
	Diffusion_U = 3,
	Diffusion_V = 4,
	UV_Concentration = 5,
}

Gray_Scott_Image_Fit_Mode :: enum u32 {
	Stretch = 0,
	Center = 1,
	Fit_H = 2,
	Fit_V = 3,
}

GRAY_SCOTT_MASK_PATTERN_NAMES := [?]string {
	"Disabled",
	"Checkerboard",
	"Diagonal Gradient",
	"Radial Gradient",
	"Vertical Stripes",
	"Horizontal Stripes",
	"Wave Function",
	"Cosine Grid",
	"Image",
}

GRAY_SCOTT_MASK_TARGET_NAMES := [?]string {
	"Feed Rate",
	"Kill Rate",
	"Diffusion U",
	"Diffusion V",
	"UV Concentration",
}

GRAY_SCOTT_IMAGE_FIT_MODE_NAMES := [?]string {
	"Stretch",
	"Center",
	"Fit H",
	"Fit V",
}

GRAY_SCOTT_BUILTIN_PRESET_NAMES := [?]string {
	"Brain Coral",
	"Fingerprint",
	"Mitosis",
	"Ripples",
	"Soliton Collapse",
	"U-Skate World",
	"Undulating",
	"Worms",
	"Custom",
}

Gray_Scott_Builtin_Preset :: struct {
	feed: f32,
	kill: f32,
	timestep: f32,
	max_timestep: f32,
	stability_factor: f32,
}

GRAY_SCOTT_BUILTIN_PRESETS := [?]Gray_Scott_Builtin_Preset {
	{feed = 0.0545, kill = 0.0620, timestep = 1.0, max_timestep = 2.0, stability_factor = 0.8},
	{feed = 0.0545, kill = 0.0620, timestep = 1.0, max_timestep = 2.0, stability_factor = 0.8},
	{feed = 0.0367, kill = 0.0649, timestep = 1.0, max_timestep = 2.0, stability_factor = 0.8},
	{feed = 0.0180, kill = 0.0510, timestep = 1.0, max_timestep = 2.0, stability_factor = 0.8},
	{feed = 0.0220, kill = 0.0600, timestep = 1.0, max_timestep = 2.0, stability_factor = 0.8},
	{feed = 0.0620, kill = 0.0610, timestep = 1.0, max_timestep = 2.0, stability_factor = 0.8},
	{feed = 0.0260, kill = 0.0510, timestep = 1.0, max_timestep = 2.0, stability_factor = 0.8},
	{feed = 0.0780, kill = 0.0610, timestep = 1.0, max_timestep = 2.0, stability_factor = 0.8},
	{feed = 0.0350, kill = 0.0580, timestep = 1.0, max_timestep = 2.0, stability_factor = 0.8},
}

gray_scott_mask_target_to_index :: proc(target: Gray_Scott_Mask_Target) -> int {
	value := int(u32(target))
	return max(min(value - 1, len(GRAY_SCOTT_MASK_TARGET_NAMES) - 1), 0)
}

gray_scott_mask_target_from_index :: proc(index: int) -> Gray_Scott_Mask_Target {
	return Gray_Scott_Mask_Target(u32(max(min(index, len(GRAY_SCOTT_MASK_TARGET_NAMES) - 1), 0) + 1))
}

gray_scott_mask_pattern_from_name :: proc(name: string, out: ^Gray_Scott_Mask_Pattern) -> bool {
	switch name {
	case "Disabled", "disabled":
		out^ = .Disabled
	case "Checkerboard", "checkerboard":
		out^ = .Checkerboard
	case "Diagonal Gradient", "Diagonal_Gradient", "diagonal gradient", "diagonal_gradient":
		out^ = .Diagonal_Gradient
	case "Radial Gradient", "Radial_Gradient", "radial gradient", "radial_gradient":
		out^ = .Radial_Gradient
	case "Vertical Stripes", "Vertical_Stripes", "vertical stripes", "vertical_stripes":
		out^ = .Vertical_Stripes
	case "Horizontal Stripes", "Horizontal_Stripes", "horizontal stripes", "horizontal_stripes":
		out^ = .Horizontal_Stripes
	case "Wave Function", "Wave_Function", "wave function", "wave_function":
		out^ = .Wave_Function
	case "Cosine Grid", "Cosine_Grid", "cosine grid", "cosine_grid":
		out^ = .Cosine_Grid
	case "Image", "image", "Image Gradient", "image gradient", "image_gradient", "Nutrient Map", "nutrient map", "nutrient_map":
		out^ = .Nutrient_Map
	case:
		return false
	}
	return true
}

gray_scott_image_fit_mode_from_name :: proc(name: string, out: ^Gray_Scott_Image_Fit_Mode) -> bool {
	switch name {
	case "Stretch", "stretch":
		out^ = .Stretch
	case "Center", "center":
		out^ = .Center
	case "Fit H", "FitH", "Fit_H", "fit h", "fith", "fit_h":
		out^ = .Fit_H
	case "Fit V", "FitV", "Fit_V", "fit v", "fitv", "fit_v":
		out^ = .Fit_V
	case:
		return false
	}
	return true
}

Gray_Scott_Settings :: struct {
	feed: f32,
	kill: f32,
	diffusion_a: f32,
	diffusion_b: f32,
	timestep: f32,
	simulation_speed: f32,
	max_timestep: f32,
	stability_factor: f32,
	enable_adaptive_timestep: bool,
	mask_pattern: Gray_Scott_Mask_Pattern,
	mask_target: Gray_Scott_Mask_Target,
	mask_strength: f32,
	mask_mirror_horizontal: bool,
	mask_mirror_vertical: bool,
	mask_invert_tone: bool,
	nutrient_image_fit_mode: Gray_Scott_Image_Fit_Mode,
	nutrient_image_path: [GRAY_SCOTT_NUTRIENT_IMAGE_PATH_MAX]u8,
	cursor_size: f32,
	cursor_strength: f32,
	color_scheme: Color_Scheme_Name,
	color_scheme_reversed: bool,
	blur_enabled: bool,
	blur_radius: f32,
	blur_sigma: f32,
	paused: bool,
}

Gray_Scott_Randomize_Undo :: struct {
	feed: f32,
	kill: f32,
	diffusion_a: f32,
	diffusion_b: f32,
	timestep: f32,
	simulation_speed: f32,
	seed: u32,
	current_preset_index: int,
}

Gray_Scott_Runtime_State :: struct {
	nutrient_upload_pending: bool,
	simulation_time: f32,
	frame_index: u64,
	seed: u32,
	pending_seed_mode: u32,
	paint_active: bool,
	paint_x: f32,
	paint_y: f32,
	paint_button: u32,
	camera_x: f32,
	camera_y: f32,
	camera_zoom: f32,
	camera_target_x: f32,
	camera_target_y: f32,
	camera_target_zoom: f32,
	camera_smoothing_factor: f32,
	current_preset_index: int,
	preset_fieldset: Preset_Fieldset_State,
	randomize_undo: Gray_Scott_Randomize_Undo,
	randomize_undo_available: bool,
	nutrient_image_loaded: bool,
	webcam: ^sdl.Camera,
	webcam_active: bool,
	webcam_permission_denied: bool,
	webcam_frames: u64,
	nutrient_image_dialog_requested: bool,
}

Gray_Scott_Simulation :: struct {
	settings: Gray_Scott_Settings,
	runtime: Gray_Scott_Runtime_State,
	gpu: Gray_Scott_Gpu_State,
}

gray_scott_default_settings :: proc() -> Gray_Scott_Settings {
	settings := Gray_Scott_Settings {
			feed = 0.055,
			kill = 0.062,
			diffusion_a = 0.16,
			diffusion_b = 0.08,
			timestep = 2.5,
			simulation_speed = 1.0,
			max_timestep = 4.0,
			stability_factor = 0.9,
			enable_adaptive_timestep = false,
			mask_pattern = .Disabled,
			mask_target = .UV_Concentration,
			mask_strength = 0.5,
			mask_mirror_horizontal = false,
			mask_mirror_vertical = false,
			mask_invert_tone = false,
			nutrient_image_fit_mode = .Stretch,
			cursor_size = 0.20,
			cursor_strength = 1.0,
			color_scheme_reversed = false,
			blur_enabled = false,
			blur_radius = 5.0,
			blur_sigma = 2.0,
			paused = false,
		}
	color_scheme_name_set(&settings.color_scheme, "MATPLOTLIB_prism")
	write_fixed_string(settings.nutrient_image_path[:], "config/gray_scott_nutrient.png")
	return settings
}

gray_scott_apply_builtin_preset :: proc(sim: ^Gray_Scott_Simulation, index: int) {
	if index < 0 || index >= len(GRAY_SCOTT_BUILTIN_PRESETS) {
		return
	}
	preset := GRAY_SCOTT_BUILTIN_PRESETS[index]
	sim.settings.feed = preset.feed
	sim.settings.kill = preset.kill
	sim.settings.diffusion_a = 0.16
	sim.settings.diffusion_b = 0.08
	sim.settings.timestep = preset.timestep
	sim.settings.simulation_speed = 1.0
	sim.settings.max_timestep = preset.max_timestep
	sim.settings.stability_factor = preset.stability_factor
	sim.settings.enable_adaptive_timestep = false
	sim.runtime.current_preset_index = index
}

gray_scott_init :: proc(sim: ^Gray_Scott_Simulation, width, height: i32) {
	sim.settings = gray_scott_default_settings()
	sim.runtime = {
		seed = 0x6d2b79f5,
		pending_seed_mode = GRAY_SCOTT_MODE_INITIAL_SEED,
		camera_zoom = 1,
		camera_target_zoom = 1,
		camera_smoothing_factor = 0.15,
		current_preset_index = 6,
	}
	gray_scott_apply_builtin_preset(sim, sim.runtime.current_preset_index)
	sim.runtime.pending_seed_mode = GRAY_SCOTT_MODE_NOISE_SEED
	sim.runtime.nutrient_upload_pending = true
	sim.gpu = {state_index = 0, width = width, height = height}
}

gray_scott_request_nutrient_upload :: proc(sim: ^Gray_Scott_Simulation) {
	if sim != nil {
		sim.runtime.nutrient_upload_pending = true
	}
}

gray_scott_hash01 :: proc(x, y, seed: u32) -> f32 {
	v := x * 73856093 ~ y * 19349663 ~ seed * 83492791
	v = (v ~ (v >> 16)) * 0x7feb352d
	v = (v ~ (v >> 15)) * 0x846ca68b
	v = v ~ (v >> 16)
	return f32(v) / f32(0xffffffff)
}

gray_scott_sample_nutrient_source :: proc(source: [^]u8, width, height, pitch, x, y: int) -> f32 {
	if width <= 0 || height <= 0 {
		return 0
	}
	sx := max(min(x, width - 1), 0)
	sy := max(min(y, height - 1), 0)
	i := sy * pitch + sx * 4
	r := f32(source[i + 0]) / 255.0
	g := f32(source[i + 1]) / 255.0
	b := f32(source[i + 2]) / 255.0
	a := f32(source[i + 3]) / 255.0
	return (r * 0.2126 + g * 0.7152 + b * 0.0722) * a
}

gray_scott_nutrient_image_value :: proc(source: [^]u8, source_width, source_height, source_pitch, target_width, target_height, x, y: int, fit_mode: Gray_Scott_Image_Fit_Mode) -> f32 {
	if source_width <= 0 || source_height <= 0 || target_width <= 0 || target_height <= 0 {
		return 0
	}
	switch fit_mode {
	case .Center:
		start_x := source_width > target_width ? 0 : (target_width - source_width) / 2
		start_y := source_height > target_height ? 0 : (target_height - source_height) / 2
		src_x := x
		src_y := y
		if source_width > target_width {
			src_x = int((u64(x) * u64(source_width)) / u64(target_width))
		} else {
			src_x = x - start_x
		}
		if source_height > target_height {
			src_y = int((u64(y) * u64(source_height)) / u64(target_height))
		} else {
			src_y = y - start_y
		}
		if src_x < 0 || src_y < 0 || src_x >= source_width || src_y >= source_height {
			return 0
		}
		return gray_scott_sample_nutrient_source(source, source_width, source_height, source_pitch, src_x, source_height - 1 - src_y)
	case .Fit_H:
		new_height := max(int(f32(target_width) * f32(source_height) / f32(max(source_width, 1))), 1)
		start_y := new_height > target_height ? 0 : (target_height - new_height) / 2
		local_y := y - start_y
		if local_y < 0 || local_y >= new_height {
			return 0
		}
		src_x := int((u64(x) * u64(source_width)) / u64(target_width))
		src_y := int((u64(local_y) * u64(source_height)) / u64(new_height))
		return gray_scott_sample_nutrient_source(source, source_width, source_height, source_pitch, src_x, source_height - 1 - src_y)
	case .Fit_V:
		new_width := max(int(f32(target_height) * f32(source_width) / f32(max(source_height, 1))), 1)
		start_x := new_width > target_width ? 0 : (target_width - new_width) / 2
		local_x := x - start_x
		if local_x < 0 || local_x >= new_width {
			return 0
		}
		src_x := int((u64(local_x) * u64(source_width)) / u64(new_width))
		src_y := int((u64(y) * u64(source_height)) / u64(target_height))
		return gray_scott_sample_nutrient_source(source, source_width, source_height, source_pitch, src_x, source_height - 1 - src_y)
	case .Stretch:
		fallthrough
	}
	src_x := int((u64(x) * u64(source_width)) / u64(target_width))
	src_y := int((u64(y) * u64(source_height)) / u64(target_height))
	return gray_scott_sample_nutrient_source(source, source_width, source_height, source_pitch, src_x, source_height - 1 - src_y)
}



gray_scott_resize :: proc(sim: ^Gray_Scott_Simulation, width, height: i32) {
	sim.gpu.width = width
	sim.gpu.height = height
	sim.gpu.ready = false
}

gray_scott_step :: proc(sim: ^Gray_Scott_Simulation, dt: f32) {
	if sim.settings.paused {
		return
	}
	sim.runtime.simulation_time += dt
	sim.runtime.frame_index += 1
}

gray_scott_positive_fract :: proc(v: f32) -> f32 {
	f := v - math.floor(v)
	if f < 0 {
		f += 1
	}
	return f
}

gray_scott_texture_coord_from_world :: proc(v: f32) -> f32 {
	if v >= 0 && v <= 1 {
		return v
	}
	return gray_scott_positive_fract(v)
}

gray_scott_screen_to_world_at :: proc(camera_x, camera_y, camera_zoom: f32, mouse_pos: uifw.Vec2, width, height: i32) -> (f32, f32) {
	w := f32(max(width, 1))
	h := f32(max(height, 1))
	zoom := max(camera_zoom, 0.05)
	ndc_x := (mouse_pos.x / w) * 2.0 - 1.0
	ndc_y := 1.0 - (mouse_pos.y / h) * 2.0
	return camera_x + ndc_x / zoom, camera_y + ndc_y / zoom
}

gray_scott_camera_control_state :: proc(sim: ^Gray_Scott_Simulation) -> Camera_Control_State {
	return {
		position = {sim.runtime.camera_x, sim.runtime.camera_y},
		target_position = {sim.runtime.camera_target_x, sim.runtime.camera_target_y},
		zoom = sim.runtime.camera_zoom,
		target_zoom = sim.runtime.camera_target_zoom,
		smoothing_factor = sim.runtime.camera_smoothing_factor,
	}
}

gray_scott_store_camera_control_state :: proc(sim: ^Gray_Scott_Simulation, camera: Camera_Control_State) {
	sim.runtime.camera_x = camera.position[0]
	sim.runtime.camera_y = camera.position[1]
	sim.runtime.camera_zoom = camera.zoom
	sim.runtime.camera_target_x = camera.target_position[0]
	sim.runtime.camera_target_y = camera.target_position[1]
	sim.runtime.camera_target_zoom = camera.target_zoom
	sim.runtime.camera_smoothing_factor = camera.smoothing_factor
}

gray_scott_screen_to_texture :: proc(sim: ^Gray_Scott_Simulation, mouse_pos: uifw.Vec2, width, height: i32) -> (f32, f32) {
	world_x, world_y := gray_scott_screen_to_world(sim, mouse_pos, width, height)
	return gray_scott_texture_coord_from_world((world_x + 1.0) * 0.5), gray_scott_texture_coord_from_world((world_y + 1.0) * 0.5)
}

gray_scott_reset_camera :: proc(sim: ^Gray_Scott_Simulation) {
	camera := gray_scott_camera_control_state(sim)
	camera_controls_reset(&camera)
	gray_scott_store_camera_control_state(sim, camera)
}

gray_scott_sync_camera_targets :: proc(sim: ^Gray_Scott_Simulation) {
	camera := gray_scott_camera_control_state(sim)
	camera_controls_sync(&camera)
	gray_scott_store_camera_control_state(sim, camera)
}

gray_scott_update_camera :: proc(sim: ^Gray_Scott_Simulation, input: Ui_Frame_Input) {
	camera := gray_scott_camera_control_state(sim)
	camera_controls_apply_input(&camera, input)
	gray_scott_store_camera_control_state(sim, camera)
}

gray_scott_screen_to_world :: proc(sim: ^Gray_Scott_Simulation, mouse_pos: uifw.Vec2, width, height: i32) -> (f32, f32) {
	camera := gray_scott_camera_control_state(sim)
	world := camera_controls_screen_to_world(&camera, mouse_pos, width, height)
	gray_scott_store_camera_control_state(sim, camera)
	return world[0], world[1]
}

gray_scott_apply_frame_input :: proc(sim: ^Gray_Scott_Simulation, input: Ui_Frame_Input) {
	gray_scott_update_camera(sim, input)
	sim.runtime.paint_active = false
	if !input.mouse_down || input.window_width <= 0 || input.window_height <= 0 {
		return
	}
	if input.mouse_pos.x < 340 {
		return
	}
	button := input.mouse_button
	switch button {
	case 1:
		button = 0
	case 2:
		button = 1
	case 3:
		button = 2
	case:
		button = 0
	}
	sim.runtime.paint_active = true
	sim.runtime.paint_x, sim.runtime.paint_y = gray_scott_screen_to_texture(sim, input.mouse_pos, input.window_width, input.window_height)
	sim.runtime.paint_button = button
}
