package game

import uifw "../ui"
import engine "../engine"

import vk "vendor:vulkan"
import "core:c"
import "core:fmt"
import "core:math"
import "core:os"
import sdl "vendor:sdl3"

GRAY_SCOTT_STEP_SHADER_SOURCE :: "assets/shaders/gray_scott_step.slang"
GRAY_SCOTT_PRESENT_SHADER_SOURCE :: "assets/shaders/gray_scott_present.slang"
GRAY_SCOTT_VERTEX_SHADER_SOURCE :: GRAY_SCOTT_PRESENT_SHADER_SOURCE
GRAY_SCOTT_STEP_FALLBACK_SPV :: "build/shaders/gray_scott_step"
GRAY_SCOTT_VERTEX_FALLBACK_SPV :: "build/shaders/gray_scott_present_vertex"
GRAY_SCOTT_PRESENT_FALLBACK_SPV :: "build/shaders/gray_scott_present_fragment"
GRAY_SCOTT_STEP_ENTRY :: "main"
GRAY_SCOTT_VERTEX_ENTRY :: "vertex_main"
GRAY_SCOTT_PRESENT_ENTRY :: "fragment_main"
GRAY_SCOTT_STEP_SPIRV_ENTRY :: "main"
GRAY_SCOTT_VERTEX_SPIRV_ENTRY :: "main"
GRAY_SCOTT_PRESENT_SPIRV_ENTRY :: "main"
GRAY_SCOTT_IMAGE_FORMAT :: vk.Format(.R32G32B32A32_SFLOAT)
GRAY_SCOTT_WORKGROUP_SIZE :: 8
GRAY_SCOTT_DEFAULT_ITERATIONS :: u32(1)
GRAY_SCOTT_MAX_STABLE_SUBSTEPS :: 128
GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS :: 132
GRAY_SCOTT_MODE_CLEAR :: u32(0)
GRAY_SCOTT_MODE_STEP :: u32(1)
GRAY_SCOTT_MODE_INITIAL_SEED :: u32(2)
GRAY_SCOTT_MODE_NOISE_SEED :: u32(3)
GRAY_SCOTT_MODE_PAINT :: u32(4)
GRAY_SCOTT_LUT_SIZE :: COLOR_SCHEME_U32_COUNT
GRAY_SCOTT_NUTRIENT_IMAGE_PATH_MAX :: 256

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

Gray_Scott_Runtime_State :: struct {
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
	nutrient_image_loaded: bool,
	webcam: ^sdl.Camera,
	webcam_active: bool,
	webcam_permission_denied: bool,
	webcam_frames: u64,
	nutrient_image_dialog_requested: bool,
}

Gray_Scott_Params :: struct #align(16) {
	feed: f32,
	kill: f32,
	diffusion_a: f32,
	diffusion_b: f32,
	timestep: f32,
	width: u32,
	height: u32,
	mode: u32,
	seed: u32,
	frame_index: u32,
	mask_pattern: u32,
	mask_target: u32,
	mask_strength: f32,
	mask_mirror_horizontal: u32,
	mask_mirror_vertical: u32,
	mask_invert_tone: u32,
	max_timestep: f32,
	stability_factor: f32,
	enable_adaptive_timestep: u32,
	cursor_x: f32,
	cursor_y: f32,
	cursor_size: f32,
	cursor_strength: f32,
	mouse_button: u32,
	_pad0: u32,
	_pad1: u32,
	_pad2: u32,
}

Gray_Scott_Present_Params :: struct #align(16) {
	lut_reversed: u32,
	blur_enabled: u32,
	blur_radius: f32,
	blur_sigma: f32,
	width: u32,
	height: u32,
	viewport_width: u32,
	viewport_height: u32,
	camera_x: f32,
	camera_y: f32,
	camera_zoom: f32,
	_pad0: f32,
}

Gray_Scott_Camera :: struct #align(16) {
	transform_matrix: [16]f32,
	position: [2]f32,
	zoom: f32,
	aspect_ratio: f32,
}

Gray_Scott_Gpu_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	layout: vk.ImageLayout,
}

Gray_Scott_Gpu_State :: struct {
	ready: bool,
	step_shader_module: engine.Vk_Shader_Module,
	present_shader_module: engine.Vk_Shader_Module,
	vertex_shader_module: engine.Vk_Shader_Module,
	step_shader_spirv_path: string,
	vertex_shader_spirv_path: string,
	present_shader_spirv_path: string,
	compute_pipeline: engine.Vk_Compute_Pipeline,
	present_pipeline: engine.Vk_Graphics_Pipeline,
	compute_set_layout: vk.DescriptorSetLayout,
	present_set_layout: vk.DescriptorSetLayout,
	compute_pool: vk.DescriptorPool,
	present_pool: vk.DescriptorPool,
	compute_sets: [GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS]vk.DescriptorSet,
	present_set: vk.DescriptorSet,
	storage: [2]Gray_Scott_Gpu_Image,
	sampler: vk.Sampler,
	params_buffers: [GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS]engine.Vk_Buffer,
	nutrient_buffer: engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	present_params_buffer: engine.Vk_Buffer,
	camera_buffer: engine.Vk_Buffer,
	fullscreen_vertices: engine.Vk_Buffer,
	lut_uploaded_scheme: Color_Scheme_Name,
	lut_uploaded_reversed: bool,
	state_index: u32,
	compute_dispatch_slot: u32,
	width: i32,
	height: i32,
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
	sim.runtime.pending_seed_mode = GRAY_SCOTT_MODE_INITIAL_SEED
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
	sim.gpu = {state_index = 0, width = width, height = height}
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

gray_scott_render :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) {
	_ = sim
	_ = vk_ctx
}

gray_scott_get_step_shader_spv_path :: proc() -> string {
	return engine.shader_spirv_path(
		GRAY_SCOTT_STEP_SHADER_SOURCE,
		.Compute,
		GRAY_SCOTT_STEP_ENTRY,
		GRAY_SCOTT_STEP_FALLBACK_SPV + ".spv",
	)
}

gray_scott_get_present_shader_spv_path :: proc() -> string {
	return engine.shader_spirv_path(
		GRAY_SCOTT_PRESENT_SHADER_SOURCE,
		.Fragment,
		GRAY_SCOTT_PRESENT_ENTRY,
		GRAY_SCOTT_PRESENT_FALLBACK_SPV + ".spv",
	)
}

gray_scott_get_vertex_shader_spv_path :: proc() -> string {
	return engine.shader_spirv_path(
		GRAY_SCOTT_VERTEX_SHADER_SOURCE,
		.Vertex,
		GRAY_SCOTT_VERTEX_ENTRY,
		GRAY_SCOTT_VERTEX_FALLBACK_SPV + ".spv",
	)
}

gray_scott_ensure_gpu_paths :: proc(sim: ^Gray_Scott_Simulation) -> bool {
	step_path := gray_scott_get_step_shader_spv_path()
	vertex_path := gray_scott_get_vertex_shader_spv_path()
	present_path := gray_scott_get_present_shader_spv_path()
	if len(step_path) == 0 || len(vertex_path) == 0 || len(present_path) == 0 {
		return false
	}
	if !os.exists(step_path) || !os.exists(vertex_path) || !os.exists(present_path) {
		return false
	}
	sim.gpu.step_shader_spirv_path = step_path
	sim.gpu.vertex_shader_spirv_path = vertex_path
	sim.gpu.present_shader_spirv_path = present_path
	return true
}

gray_scott_ensure_gpu_runtime :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if sim.gpu.ready {
		return true
	}

	if sim.gpu.step_shader_module.handle != 0 || sim.gpu.present_shader_module.handle != 0 {
		gray_scott_destroy(sim, vk_ctx)
	}
	if !gray_scott_ensure_gpu_paths(sim) {
		return false
	}

	step_module := engine.Vk_Shader_Module{}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.step_shader_spirv_path, &step_module) {
		return false
	}
	present_module := engine.Vk_Shader_Module{}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.present_shader_spirv_path, &present_module) {
		engine.vk_destroy_shader_module(vk_ctx, &step_module)
		return false
	}
	vertex_module := engine.Vk_Shader_Module{}
	if !engine.vk_load_shader_module(vk_ctx, sim.gpu.vertex_shader_spirv_path, &vertex_module) {
		engine.vk_destroy_shader_module(vk_ctx, &step_module)
		engine.vk_destroy_shader_module(vk_ctx, &present_module)
		return false
	}

	sim.gpu.step_shader_module = step_module
	sim.gpu.present_shader_module = present_module
	sim.gpu.vertex_shader_module = vertex_module

	if !gray_scott_create_render_state(sim, vk_ctx) {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	sim.gpu.ready = true
	return true
}

gray_scott_create_render_state :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	if !gray_scott_create_compute_resources(sim, vk_ctx) {
		return false
	}
	if !gray_scott_create_present_resources(sim, vk_ctx) {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}
	return true
}

gray_scott_create_image_resource :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, index: int) -> bool {
	width := cast(int)max(sim.gpu.width, 1)
	height := cast(int)max(sim.gpu.height, 1)
	if width <= 0 || height <= 0 {
		return false
	}

	image_info := vk.ImageCreateInfo {
		sType = .IMAGE_CREATE_INFO,
		imageType = .D2,
		format = GRAY_SCOTT_IMAGE_FORMAT,
		extent = {width = u32(width), height = u32(height), depth = 1},
		mipLevels = 1,
		arrayLayers = 1,
		samples = {._1},
		tiling = .OPTIMAL,
		usage = {.STORAGE, .SAMPLED},
		sharingMode = .EXCLUSIVE,
		initialLayout = .UNDEFINED,
	}
	if vk.CreateImage(vk_ctx.device, &image_info, nil, &sim.gpu.storage[index].handle) != .SUCCESS {
		return false
	}

	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device, sim.gpu.storage[index].handle, &req)
	memory_type, ok := engine.vk_find_memory_type(vk_ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {
		vk.DestroyImage(vk_ctx.device, sim.gpu.storage[index].handle, nil)
		sim.gpu.storage[index].handle = vk.Image(0)
		return false
	}

	alloc_info := vk.MemoryAllocateInfo {
		sType = .MEMORY_ALLOCATE_INFO,
		allocationSize = req.size,
		memoryTypeIndex = memory_type,
	}
	if vk.AllocateMemory(vk_ctx.device, &alloc_info, nil, &sim.gpu.storage[index].memory) != .SUCCESS {
		vk.DestroyImage(vk_ctx.device, sim.gpu.storage[index].handle, nil)
		sim.gpu.storage[index].handle = vk.Image(0)
		return false
	}
	if vk.BindImageMemory(vk_ctx.device, sim.gpu.storage[index].handle, sim.gpu.storage[index].memory, 0) != .SUCCESS {
		vk.FreeMemory(vk_ctx.device, sim.gpu.storage[index].memory, nil)
		vk.DestroyImage(vk_ctx.device, sim.gpu.storage[index].handle, nil)
		sim.gpu.storage[index] = {}
		return false
	}

	view_info := vk.ImageViewCreateInfo {
		sType = .IMAGE_VIEW_CREATE_INFO,
		image = sim.gpu.storage[index].handle,
		viewType = .D2,
		format = GRAY_SCOTT_IMAGE_FORMAT,
		components = {r = .IDENTITY, g = .IDENTITY, b = .IDENTITY, a = .IDENTITY},
		subresourceRange = {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
		},
	}
	if vk.CreateImageView(vk_ctx.device, &view_info, nil, &sim.gpu.storage[index].view) != .SUCCESS {
		vk.FreeMemory(vk_ctx.device, sim.gpu.storage[index].memory, nil)
		vk.DestroyImage(vk_ctx.device, sim.gpu.storage[index].handle, nil)
		sim.gpu.storage[index] = {}
		return false
	}

	sim.gpu.storage[index].layout = .UNDEFINED
	return true
}

gray_scott_upload_lut :: proc(sim: ^Gray_Scott_Simulation) {
	if sim.gpu.lut_buffer.mapped == nil {
		return
	}
	name := color_scheme_name_get(&sim.settings.color_scheme)
	scheme, ok := color_scheme_load(name)
	if !ok {
		scheme = color_scheme_default()
	}
	if sim.settings.color_scheme_reversed {
		color_scheme_reverse(&scheme)
	}
	out := cast([^]u32)sim.gpu.lut_buffer.mapped
	_ = color_scheme_write_u32_buffer(scheme, out[:GRAY_SCOTT_LUT_SIZE])
	sim.gpu.lut_uploaded_scheme = sim.settings.color_scheme
	sim.gpu.lut_uploaded_reversed = sim.settings.color_scheme_reversed
}

gray_scott_upload_present_params :: proc(sim: ^Gray_Scott_Simulation) {
	if sim.gpu.present_params_buffer.mapped == nil {
		return
	}
	params := cast(^Gray_Scott_Present_Params)sim.gpu.present_params_buffer.mapped
	params^ = {
		lut_reversed = sim.settings.color_scheme_reversed ? 1 : 0,
		blur_enabled = sim.settings.blur_enabled ? 1 : 0,
		blur_radius = sim.settings.blur_radius,
		blur_sigma = sim.settings.blur_sigma,
		width = u32(max(sim.gpu.width, 1)),
		height = u32(max(sim.gpu.height, 1)),
		viewport_width = u32(max(sim.gpu.width, 1)),
		viewport_height = u32(max(sim.gpu.height, 1)),
		camera_x = sim.runtime.camera_x,
		camera_y = sim.runtime.camera_y,
		camera_zoom = max(sim.runtime.camera_zoom, 0.05),
	}
}

gray_scott_upload_camera :: proc(sim: ^Gray_Scott_Simulation) {
	if sim.gpu.camera_buffer.mapped == nil {
		return
	}
	zoom := max(sim.runtime.camera_zoom, CAMERA_MIN_ZOOM)
	aspect := f32(max(sim.gpu.width, 1)) / f32(max(sim.gpu.height, 1))
	camera := cast(^Gray_Scott_Camera)sim.gpu.camera_buffer.mapped
	camera^ = {
		transform_matrix = {
			zoom, 0, 0, 0,
			0, zoom, 0, 0,
			0, 0, 1, 0,
			-sim.runtime.camera_x * zoom, -sim.runtime.camera_y * zoom, 0, 1,
		},
		position = {sim.runtime.camera_x, sim.runtime.camera_y},
		zoom = zoom,
		aspect_ratio = aspect,
	}
}

gray_scott_sync_present_resources :: proc(sim: ^Gray_Scott_Simulation) {
	if sim.gpu.lut_uploaded_scheme != sim.settings.color_scheme || sim.gpu.lut_uploaded_reversed != sim.settings.color_scheme_reversed {
		gray_scott_upload_lut(sim)
	}
	gray_scott_upload_present_params(sim)
	gray_scott_upload_camera(sim)
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

gray_scott_load_nutrient_image :: proc(sim: ^Gray_Scott_Simulation) -> bool {
	if sim.gpu.nutrient_buffer.mapped == nil {
		sim.runtime.nutrient_image_loaded = false
		return false
	}
	path := fixed_string(sim.settings.nutrient_image_path[:])
	if len(path) == 0 || !os.exists(path) {
		sim.runtime.nutrient_image_loaded = false
		return false
	}
	img, ok := shared_image_load_rgba8(path)
	if !ok {
		sim.runtime.nutrient_image_loaded = false
		return false
	}
	defer shared_image_destroy(img)

	target_width := int(max(sim.gpu.width, 1))
	target_height := int(max(sim.gpu.height, 1))
	values := cast([^]f32)sim.gpu.nutrient_buffer.mapped
	source := raw_data(img.pixels.buf[:])
	for y := 0; y < target_height; y += 1 {
		for x := 0; x < target_width; x += 1 {
			values[y * target_width + x] = gray_scott_nutrient_image_value(source, int(img.width), int(img.height), int(img.width) * 4, target_width, target_height, x, y, sim.settings.nutrient_image_fit_mode)
		}
	}
	sim.runtime.nutrient_image_loaded = true
	return true
}

gray_scott_webcam_device_count :: proc() -> int {
	count: c.int
	ids := sdl.GetCameras(&count)
	if ids != nil {
		sdl.free(ids)
	}
	return int(max(count, 0))
}

gray_scott_stop_webcam :: proc(sim: ^Gray_Scott_Simulation) {
	if sim.runtime.webcam != nil {
		sdl.CloseCamera(sim.runtime.webcam)
	}
	sim.runtime.webcam = nil
	sim.runtime.webcam_active = false
}

gray_scott_start_webcam :: proc(sim: ^Gray_Scott_Simulation) -> bool {
	if sim.runtime.webcam_active && sim.runtime.webcam != nil {
		return true
	}
	count: c.int
	ids := sdl.GetCameras(&count)
	if ids == nil || count <= 0 {
		sim.runtime.webcam_permission_denied = false
		return false
	}
	defer sdl.free(ids)

	camera := sdl.OpenCamera(ids[0], nil)
	if camera == nil {
		sim.runtime.webcam_permission_denied = false
		return false
	}
	sim.runtime.webcam = camera
	sim.runtime.webcam_active = true
	sim.runtime.webcam_permission_denied = false
	sim.runtime.webcam_frames = 0
	return true
}

gray_scott_update_webcam_nutrient_map :: proc(sim: ^Gray_Scott_Simulation) -> bool {
	if !sim.runtime.webcam_active || sim.runtime.webcam == nil || sim.gpu.nutrient_buffer.mapped == nil {
		return false
	}
	permission := sdl.GetCameraPermissionState(sim.runtime.webcam)
	if permission == .DENIED {
		sim.runtime.webcam_permission_denied = true
		gray_scott_stop_webcam(sim)
		return false
	}
	if permission == .PENDING {
		return false
	}

	timestamp: sdl.Uint64
	frame := sdl.AcquireCameraFrame(sim.runtime.webcam, &timestamp)
	if frame == nil {
		return false
	}
	defer sdl.ReleaseCameraFrame(sim.runtime.webcam, frame)

	converted := sdl.ConvertSurface(frame, .RGBA32)
	if converted == nil || converted.pixels == nil || converted.w <= 0 || converted.h <= 0 {
		return false
	}
	defer sdl.DestroySurface(converted)

	locked := false
	if sdl.MUSTLOCK(converted) {
		if !sdl.LockSurface(converted) {
			return false
		}
		locked = true
	}
	defer if locked {
		sdl.UnlockSurface(converted)
	}

	target_width := int(max(sim.gpu.width, 1))
	target_height := int(max(sim.gpu.height, 1))
	values := cast([^]f32)sim.gpu.nutrient_buffer.mapped
	source := cast([^]u8)converted.pixels
	for y := 0; y < target_height; y += 1 {
		for x := 0; x < target_width; x += 1 {
			values[y * target_width + x] = gray_scott_nutrient_image_value(source, int(converted.w), int(converted.h), int(converted.pitch), target_width, target_height, x, y, sim.settings.nutrient_image_fit_mode)
		}
	}
	sim.runtime.nutrient_image_loaded = true
	sim.runtime.webcam_frames += 1
	return true
}

gray_scott_upload_nutrient_map :: proc(sim: ^Gray_Scott_Simulation) {
	if sim.gpu.nutrient_buffer.mapped == nil {
		return
	}
	if gray_scott_load_nutrient_image(sim) {
		return
	}
	width := int(max(sim.gpu.width, 1))
	height := int(max(sim.gpu.height, 1))
	values := cast([^]f32)sim.gpu.nutrient_buffer.mapped
	seed := sim.runtime.seed
	for y := 0; y < height; y += 1 {
		ny := f32(y) / f32(max(height - 1, 1))
		for x := 0; x < width; x += 1 {
			nx := f32(x) / f32(max(width - 1, 1))
			dx := nx - 0.5
			dy := ny - 0.5
			radial := max(1.0 - (dx * dx + dy * dy) * 2.4, 0.0)
			diagonal := (nx + ny) * 0.5
			coarse := gray_scott_hash01(u32(x / 16), u32(y / 16), seed)
			fine := gray_scott_hash01(u32(x / 5), u32(y / 5), seed + 17)
			value := radial * 0.45 + diagonal * 0.35 + coarse * 0.15 + fine * 0.05
			values[y * width + x] = max(min(value, 1.0), 0.0)
		}
	}
}

gray_scott_create_compute_resources :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	for i := 0; i < 2; i += 1 {
		if !gray_scott_create_image_resource(sim, vk_ctx, i) {
			for j := 0; j < i; j += 1 {
				if sim.gpu.storage[j].view != vk.ImageView(0) {
					vk.DestroyImageView(vk_ctx.device, sim.gpu.storage[j].view, nil)
				}
				if sim.gpu.storage[j].handle != vk.Image(0) {
					vk.DestroyImage(vk_ctx.device, sim.gpu.storage[j].handle, nil)
				}
				if sim.gpu.storage[j].memory != vk.DeviceMemory(0) {
					vk.FreeMemory(vk_ctx.device, sim.gpu.storage[j].memory, nil)
				}
				sim.gpu.storage[j] = {}
			}
			return false
		}
	}

	buffer_size := vk.DeviceSize(size_of(Gray_Scott_Params))
	for i := 0; i < len(sim.gpu.params_buffers); i += 1 {
		if !engine.vk_create_host_buffer(vk_ctx, buffer_size, {.UNIFORM_BUFFER}, &sim.gpu.params_buffers[i]) {
			gray_scott_destroy(sim, vk_ctx)
			return false
		}
	}

	nutrient_size := vk.DeviceSize(size_of(f32) * max(sim.gpu.width, 1) * max(sim.gpu.height, 1))
	if !engine.vk_create_host_buffer(vk_ctx, nutrient_size, {.STORAGE_BUFFER}, &sim.gpu.nutrient_buffer) {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}
	gray_scott_upload_nutrient_map(sim)

	compute_set_bindings := [4]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 1, descriptorType = .STORAGE_IMAGE, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
		{binding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.COMPUTE}},
	}
	compute_set_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(compute_set_bindings)),
		pBindings = raw_data(compute_set_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &compute_set_layout_info, nil, &sim.gpu.compute_set_layout) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	pool_sizes := [3]vk.DescriptorPoolSize {
		{type = .STORAGE_IMAGE, descriptorCount = u32(GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS * 2)},
		{type = .UNIFORM_BUFFER, descriptorCount = u32(GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS)},
		{type = .STORAGE_BUFFER, descriptorCount = u32(GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS)},
	}
	compute_pool_info := vk.DescriptorPoolCreateInfo {
		sType = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = u32(len(pool_sizes)),
		pPoolSizes = raw_data(pool_sizes[:]),
		maxSets = u32(GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS),
	}
	if vk.CreateDescriptorPool(vk_ctx.device, &compute_pool_info, nil, &sim.gpu.compute_pool) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	compute_set_layouts: [GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS]vk.DescriptorSetLayout
	for i := 0; i < len(compute_set_layouts); i += 1 {
		compute_set_layouts[i] = sim.gpu.compute_set_layout
	}
	set_alloc := vk.DescriptorSetAllocateInfo {
		sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool = sim.gpu.compute_pool,
		descriptorSetCount = u32(len(sim.gpu.compute_sets)),
		pSetLayouts = raw_data(compute_set_layouts[:]),
	}
	if vk.AllocateDescriptorSets(vk_ctx.device, &set_alloc, raw_data(sim.gpu.compute_sets[:])) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	compute_layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = &sim.gpu.compute_set_layout,
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &compute_layout_info, nil, &sim.gpu.compute_pipeline.layout) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	compute_stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.COMPUTE},
		module = sim.gpu.step_shader_module.handle,
		pName = GRAY_SCOTT_STEP_SPIRV_ENTRY,
	}
	compute_pipeline_info := vk.ComputePipelineCreateInfo {
		sType = .COMPUTE_PIPELINE_CREATE_INFO,
		stage = compute_stage,
		layout = sim.gpu.compute_pipeline.layout,
	}
	if vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &compute_pipeline_info, nil, &sim.gpu.compute_pipeline.pipeline) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	return true
}

gray_scott_create_fullscreen_vertex_buffer :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	buffer_size := vk.DeviceSize(size_of(engine.Ui_Vertex) * 6)
	if !engine.vk_create_host_buffer(vk_ctx, buffer_size, {.VERTEX_BUFFER}, &sim.gpu.fullscreen_vertices) {
		return false
	}

	white := uifw.Color{1, 1, 1, 1}
	zero := uifw.Color{0, 0, 0, 0}
	verts := cast([^]engine.Ui_Vertex)sim.gpu.fullscreen_vertices.mapped
	verts[0] = {pos = {-1, -1}, color = white, uv = {0, 1}, glyph = 0, effect = zero}
	verts[1] = {pos = { 1, -1}, color = white, uv = {1, 1}, glyph = 0, effect = zero}
	verts[2] = {pos = {-1,  1}, color = white, uv = {0, 0}, glyph = 0, effect = zero}
	verts[3] = {pos = {-1,  1}, color = white, uv = {0, 0}, glyph = 0, effect = zero}
	verts[4] = {pos = { 1, -1}, color = white, uv = {1, 1}, glyph = 0, effect = zero}
	verts[5] = {pos = { 1,  1}, color = white, uv = {1, 0}, glyph = 0, effect = zero}
	return true
}

gray_scott_create_present_resources :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	lut_size := vk.DeviceSize(size_of(u32) * GRAY_SCOTT_LUT_SIZE)
	if !engine.vk_create_host_buffer(vk_ctx, lut_size, {.STORAGE_BUFFER}, &sim.gpu.lut_buffer) {
		return false
	}
	present_params_size := vk.DeviceSize(size_of(Gray_Scott_Present_Params))
	if !engine.vk_create_host_buffer(vk_ctx, present_params_size, {.UNIFORM_BUFFER}, &sim.gpu.present_params_buffer) {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}
	camera_size := vk.DeviceSize(size_of(Gray_Scott_Camera))
	if !engine.vk_create_host_buffer(vk_ctx, camera_size, {.UNIFORM_BUFFER}, &sim.gpu.camera_buffer) {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}
	gray_scott_upload_lut(sim)
	gray_scott_upload_present_params(sim)
	gray_scott_upload_camera(sim)

	sampler_info := vk.SamplerCreateInfo {sType = .SAMPLER_CREATE_INFO}
	sampler_info.magFilter = .LINEAR
	sampler_info.minFilter = .LINEAR
	sampler_info.mipmapMode = .LINEAR
	sampler_info.addressModeU = .REPEAT
	sampler_info.addressModeV = .REPEAT
	sampler_info.addressModeW = .REPEAT
	sampler_info.minLod = 0
	sampler_info.maxLod = 1
	sampler_info.unnormalizedCoordinates = false
	sampler_info.anisotropyEnable = false
	sampler_info.maxAnisotropy = 1
	sampler_info.compareEnable = false
	sampler_info.compareOp = .ALWAYS
	if vk.CreateSampler(vk_ctx.device, &sampler_info, nil, &sim.gpu.sampler) != .SUCCESS {
		return false
	}

	present_set_bindings := [5]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 4, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, stageFlags = {.VERTEX}},
	}
	present_set_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(present_set_bindings)),
		pBindings = raw_data(present_set_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &present_set_layout_info, nil, &sim.gpu.present_set_layout) != .SUCCESS {
		vk.DestroySampler(vk_ctx.device, sim.gpu.sampler, nil)
		sim.gpu.sampler = vk.Sampler(0)
		return false
	}

	present_pool_sizes := [4]vk.DescriptorPoolSize {
		{
			type = .SAMPLER,
			descriptorCount = 1,
		},
		{
			type = .SAMPLED_IMAGE,
			descriptorCount = 1,
		},
		{
			type = .STORAGE_BUFFER,
			descriptorCount = 1,
		},
		{
			type = .UNIFORM_BUFFER,
			descriptorCount = 2,
		},
	}
	present_pool_info := vk.DescriptorPoolCreateInfo {
		sType = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = u32(len(present_pool_sizes)),
		pPoolSizes = raw_data(present_pool_sizes[:]),
		maxSets = 1,
	}
	if vk.CreateDescriptorPool(vk_ctx.device, &present_pool_info, nil, &sim.gpu.present_pool) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	present_set_alloc := vk.DescriptorSetAllocateInfo {
		sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool = sim.gpu.present_pool,
		descriptorSetCount = 1,
		pSetLayouts = &sim.gpu.present_set_layout,
	}
	if vk.AllocateDescriptorSets(vk_ctx.device, &present_set_alloc, &sim.gpu.present_set) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}
	if !gray_scott_update_present_descriptor(sim, vk_ctx, 0) {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = &sim.gpu.present_set_layout,
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &sim.gpu.present_pipeline.layout) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	vertex_stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.VERTEX},
		module = sim.gpu.vertex_shader_module.handle,
		pName = GRAY_SCOTT_VERTEX_SPIRV_ENTRY,
	}
	fragment_stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.FRAGMENT},
		module = sim.gpu.present_shader_module.handle,
		pName = GRAY_SCOTT_PRESENT_SPIRV_ENTRY,
	}
	stages := [?]vk.PipelineShaderStageCreateInfo {vertex_stage, fragment_stage}

	vertex_input := vk.PipelineVertexInputStateCreateInfo {
		sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount = 0,
		pVertexBindingDescriptions = nil,
		vertexAttributeDescriptionCount = 0,
		pVertexAttributeDescriptions = nil,
	}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo {
		sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		topology = .TRIANGLE_LIST,
	}
	viewport_state := vk.PipelineViewportStateCreateInfo {
		sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		viewportCount = 1,
		scissorCount = 1,
	}
	raster := vk.PipelineRasterizationStateCreateInfo {
		sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		polygonMode = .FILL,
		cullMode = {},
		frontFace = .COUNTER_CLOCKWISE,
		lineWidth = 1,
	}
	multisample := vk.PipelineMultisampleStateCreateInfo {
		sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		rasterizationSamples = {._1},
	}
	blend_attachment := vk.PipelineColorBlendAttachmentState {
		blendEnable = false,
		srcColorBlendFactor = .ONE,
		dstColorBlendFactor = .ZERO,
		colorBlendOp = .ADD,
		srcAlphaBlendFactor = .ONE,
		dstAlphaBlendFactor = .ZERO,
		alphaBlendOp = .ADD,
		colorWriteMask = {.R, .G, .B, .A},
	}
	blend := vk.PipelineColorBlendStateCreateInfo {
		sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		attachmentCount = 1,
		pAttachments = &blend_attachment,
	}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state_info := vk.PipelineDynamicStateCreateInfo {
		sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = u32(len(dynamic_states)),
		pDynamicStates = raw_data(dynamic_states[:]),
	}
	present_info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = u32(len(stages)),
		pStages = raw_data(stages[:]),
		pVertexInputState = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState = &multisample,
		pColorBlendState = &blend,
		pDynamicState = &dynamic_state_info,
		layout = sim.gpu.present_pipeline.layout,
		renderPass = vk_ctx.render_pass,
		subpass = 0,
	}
	present_result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &present_info, nil, &sim.gpu.present_pipeline.pipeline)
	if present_result != .SUCCESS {
		engine.log_error("gray_scott_create_present_resources: CreateGraphicsPipelines failed result=", present_result)
		gray_scott_destroy(sim, vk_ctx)
		return false
	}
	return true
}

gray_scott_update_compute_descriptors :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, read_index: int, write_index: int, dispatch_slot: int) -> bool {
	if read_index < 0 || read_index >= 2 || write_index < 0 || write_index >= 2 || dispatch_slot < 0 || dispatch_slot >= len(sim.gpu.compute_sets) {
		return false
	}
	if sim.gpu.compute_sets[dispatch_slot] == vk.DescriptorSet(0) {
		return false
	}

	storage_info := vk.DescriptorImageInfo {
		imageLayout = .GENERAL,
		imageView = sim.gpu.storage[write_index].view,
	}
	sample_info := vk.DescriptorImageInfo {
		imageLayout = .GENERAL,
		imageView = sim.gpu.storage[read_index].view,
	}
	buffer_info := vk.DescriptorBufferInfo {
		buffer = sim.gpu.params_buffers[dispatch_slot].handle,
		offset = 0,
		range = vk.DeviceSize(size_of(Gray_Scott_Params)),
	}
	nutrient_info := vk.DescriptorBufferInfo {
		buffer = sim.gpu.nutrient_buffer.handle,
		offset = 0,
		range = vk.DeviceSize(size_of(f32) * max(sim.gpu.width, 1) * max(sim.gpu.height, 1)),
	}
	writes := [4]vk.WriteDescriptorSet {
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = sim.gpu.compute_sets[dispatch_slot],
			dstBinding = 0,
			descriptorType = .STORAGE_IMAGE,
			descriptorCount = 1,
			pImageInfo = &storage_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = sim.gpu.compute_sets[dispatch_slot],
			dstBinding = 1,
			descriptorType = .STORAGE_IMAGE,
			descriptorCount = 1,
			pImageInfo = &sample_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = sim.gpu.compute_sets[dispatch_slot],
			dstBinding = 2,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &buffer_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = sim.gpu.compute_sets[dispatch_slot],
			dstBinding = 3,
			descriptorType = .STORAGE_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &nutrient_info,
		},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
	return true
}

gray_scott_update_present_descriptor :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, read_index: int) -> bool {
	if sim.gpu.present_set == vk.DescriptorSet(0) {
		return false
	}
	if read_index < 0 || read_index >= 2 {
		return false
	}
	image_info := vk.DescriptorImageInfo {
		imageLayout = .SHADER_READ_ONLY_OPTIMAL,
		imageView = sim.gpu.storage[read_index].view,
	}
	sampler_info := vk.DescriptorImageInfo {
		sampler = sim.gpu.sampler,
	}
	lut_info := vk.DescriptorBufferInfo {
		buffer = sim.gpu.lut_buffer.handle,
		offset = 0,
		range = vk.DeviceSize(size_of(u32) * GRAY_SCOTT_LUT_SIZE),
	}
	present_params_info := vk.DescriptorBufferInfo {
		buffer = sim.gpu.present_params_buffer.handle,
		offset = 0,
		range = vk.DeviceSize(size_of(Gray_Scott_Present_Params)),
	}
	camera_info := vk.DescriptorBufferInfo {
		buffer = sim.gpu.camera_buffer.handle,
		offset = 0,
		range = vk.DeviceSize(size_of(Gray_Scott_Camera)),
	}
	writes := [5]vk.WriteDescriptorSet {
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = sim.gpu.present_set,
			dstBinding = 0,
			descriptorType = .SAMPLED_IMAGE,
			descriptorCount = 1,
			pImageInfo = &image_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = sim.gpu.present_set,
			dstBinding = 1,
			descriptorType = .SAMPLER,
			descriptorCount = 1,
			pImageInfo = &sampler_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = sim.gpu.present_set,
			dstBinding = 2,
			descriptorType = .STORAGE_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &lut_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = sim.gpu.present_set,
			dstBinding = 3,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &present_params_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = sim.gpu.present_set,
			dstBinding = 4,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &camera_info,
		},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
	return true
}

gray_scott_transition_image :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, index: int, old_layout: vk.ImageLayout, new_layout: vk.ImageLayout, cmd: vk.CommandBuffer) {
	if old_layout == new_layout {
		return
	}
	image := sim.gpu.storage[index].handle
	if image == vk.Image(0) {
		return
	}

	src_access: vk.AccessFlags
	dst_access: vk.AccessFlags
	src_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	dst_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	#partial switch old_layout {
	case .UNDEFINED:
		#partial switch new_layout {
		case .GENERAL:
			dst_access = {.SHADER_READ, .SHADER_WRITE}
			dst_stage = {.COMPUTE_SHADER}
			case .SHADER_READ_ONLY_OPTIMAL:
				dst_access = {.SHADER_READ}
				dst_stage = {.COMPUTE_SHADER, .FRAGMENT_SHADER}
			}
	case .GENERAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.SHADER_WRITE}
			dst_access = {.SHADER_READ}
			src_stage = {.COMPUTE_SHADER}
			dst_stage = {.COMPUTE_SHADER, .FRAGMENT_SHADER}
		}
	case .SHADER_READ_ONLY_OPTIMAL:
		#partial switch new_layout {
		case .GENERAL:
			src_access = {.SHADER_READ}
			dst_access = {.SHADER_READ, .SHADER_WRITE}
			src_stage = {.COMPUTE_SHADER, .FRAGMENT_SHADER}
			dst_stage = {.COMPUTE_SHADER}
		}
	}

	barrier := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = src_access,
		dstAccessMask = dst_access,
		oldLayout = old_layout,
		newLayout = new_layout,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = image,
		subresourceRange = {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
		},
	}
	vk.CmdPipelineBarrier(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	sim.gpu.storage[index].layout = new_layout
}

gray_scott_next_compute_slot :: proc(sim: ^Gray_Scott_Simulation) -> (int, bool) {
	slot := int(sim.gpu.compute_dispatch_slot)
	if slot < 0 || slot >= GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS {
		return 0, false
	}
	sim.gpu.compute_dispatch_slot += 1
	return slot, true
}

gray_scott_write_params :: proc(sim: ^Gray_Scott_Simulation, dispatch_slot: int, mode: u32, dt: f32) {
	if dispatch_slot < 0 || dispatch_slot >= len(sim.gpu.params_buffers) || sim.gpu.params_buffers[dispatch_slot].mapped == nil {
		return
	}
	params := cast(^Gray_Scott_Params)sim.gpu.params_buffers[dispatch_slot].mapped
	params^ = {
		feed = sim.settings.feed,
		kill = sim.settings.kill,
		diffusion_a = sim.settings.diffusion_a,
		diffusion_b = sim.settings.diffusion_b,
		timestep = dt,
		width = u32(max(sim.gpu.width, 1)),
		height = u32(max(sim.gpu.height, 1)),
		mode = mode,
		seed = sim.runtime.seed,
		frame_index = u32(sim.runtime.frame_index & 0xffffffff),
		mask_pattern = u32(sim.settings.mask_pattern),
		mask_target = u32(sim.settings.mask_target),
		mask_strength = sim.settings.mask_strength,
		mask_mirror_horizontal = sim.settings.mask_mirror_horizontal ? 1 : 0,
		mask_mirror_vertical = sim.settings.mask_mirror_vertical ? 1 : 0,
		mask_invert_tone = sim.settings.mask_invert_tone ? 1 : 0,
		max_timestep = sim.settings.max_timestep,
		stability_factor = sim.settings.stability_factor,
		enable_adaptive_timestep = sim.settings.enable_adaptive_timestep ? 1 : 0,
		cursor_x = sim.runtime.paint_x,
		cursor_y = sim.runtime.paint_y,
		cursor_size = sim.settings.cursor_size,
		cursor_strength = sim.settings.cursor_strength,
		mouse_button = sim.runtime.paint_button,
	}
}

gray_scott_compute_memory_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	barrier := vk.MemoryBarrier {
		sType = .MEMORY_BARRIER,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = {.SHADER_READ, .SHADER_WRITE},
	}
	vk.CmdPipelineBarrier(
		cmd,
		{.COMPUTE_SHADER},
		{.COMPUTE_SHADER},
		{},
		1,
		&barrier,
		0,
		nil,
		0,
		nil,
	)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

gray_scott_dispatch_compute :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dispatch_slot: int) -> bool {
	group_x := u32((max(sim.gpu.width, 1) + GRAY_SCOTT_WORKGROUP_SIZE - 1) / GRAY_SCOTT_WORKGROUP_SIZE)
	group_y := u32((max(sim.gpu.height, 1) + GRAY_SCOTT_WORKGROUP_SIZE - 1) / GRAY_SCOTT_WORKGROUP_SIZE)
	if group_x == 0 || group_y == 0 {
		return false
	}
	if dispatch_slot < 0 || dispatch_slot >= len(sim.gpu.compute_sets) || sim.gpu.compute_sets[dispatch_slot] == vk.DescriptorSet(0) {
		return false
	}
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.compute_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.compute_pipeline.layout, 0, 1, &sim.gpu.compute_sets[dispatch_slot], 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, group_x, group_y, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	gray_scott_compute_memory_barrier(vk_ctx, cmd)
	return true
}

gray_scott_estimate_stable_timestep :: proc(sim: ^Gray_Scott_Simulation) -> f32 {
	diffusion_sum := max(sim.settings.diffusion_a + sim.settings.diffusion_b, 0.0001)
	diffusion_limit := 0.25 / diffusion_sum
	reaction_limit := 1.0 / max(1.0 + sim.settings.feed + sim.settings.kill, 0.0001)
	stable := min(diffusion_limit, reaction_limit) * max(sim.settings.stability_factor, 0.01)
	return min(max(stable, 0.0001), max(sim.settings.max_timestep, 0.0001))
}

gray_scott_apply_compute_mode_to_image :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, write_index: int, mode: u32, dt: f32) -> bool {
	read_index := 1 - write_index
	if sim.gpu.storage[read_index].layout != .GENERAL {
		gray_scott_transition_image(sim, vk_ctx, read_index, sim.gpu.storage[read_index].layout, .GENERAL, cmd)
	}
	if sim.gpu.storage[write_index].layout != .GENERAL {
		gray_scott_transition_image(sim, vk_ctx, write_index, sim.gpu.storage[write_index].layout, .GENERAL, cmd)
	}
	dispatch_slot, ok := gray_scott_next_compute_slot(sim)
	if !ok {
		engine.log_error("gray_scott_apply_compute_mode_to_image: compute dispatch slots exhausted")
		return false
	}
	gray_scott_write_params(sim, dispatch_slot, mode, dt)
	if !gray_scott_update_compute_descriptors(sim, vk_ctx, read_index, write_index, dispatch_slot) {
		return false
	}
	if !gray_scott_dispatch_compute(sim, vk_ctx, cmd, dispatch_slot) {
		return false
	}
	return true
}

gray_scott_apply_compute_mode_to_state :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, mode: u32, dt: f32) -> bool {
	if !gray_scott_apply_compute_mode_to_image(sim, vk_ctx, cmd, 0, mode, dt) {
		return false
	}
	if !gray_scott_apply_compute_mode_to_image(sim, vk_ctx, cmd, 1, mode, dt) {
		return false
	}
	sim.gpu.state_index = 0
	sim.runtime.pending_seed_mode = 0
	return true
}

gray_scott_step_compute_resources :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dt: f32) -> bool {
	sim.gpu.compute_dispatch_slot = 0
	if sim.gpu.compute_pipeline.pipeline == vk.Pipeline(0) || sim.gpu.compute_sets[0] == vk.DescriptorSet(0) || sim.gpu.compute_sets[1] == vk.DescriptorSet(0) {
		return false
	}
	for i := 0; i < 2; i += 1 {
		if sim.gpu.storage[i].handle == vk.Image(0) {
			return false
		}
	}
	if sim.runtime.webcam_active {
		_ = gray_scott_update_webcam_nutrient_map(sim)
	}

	if sim.runtime.pending_seed_mode != 0 {
		if !gray_scott_apply_compute_mode_to_state(sim, vk_ctx, cmd, sim.runtime.pending_seed_mode, 1.0) {
			return false
		}
	}
	if sim.runtime.paint_active {
		read_index := int(sim.gpu.state_index)
		write_index := 1 - read_index
		if !gray_scott_apply_compute_mode_to_image(sim, vk_ctx, cmd, write_index, GRAY_SCOTT_MODE_PAINT, 1.0) {
			return false
		}
		sim.gpu.state_index = u32(write_index)
	}
	if sim.settings.paused {
		return true
	}

	base_timestep := sim.settings.timestep
	speed := max(sim.settings.simulation_speed, 0.0)
	total_step_dt := base_timestep * speed
	if total_step_dt <= 0 || dt <= 0 {
		return true
	}
	substeps := int(GRAY_SCOTT_DEFAULT_ITERATIONS)
	per_iteration_dt := total_step_dt / f32(max(substeps, 1))
	if speed > 1.0 {
		stable_dt := gray_scott_estimate_stable_timestep(sim)
		substeps = int(math.ceil(total_step_dt / stable_dt))
		substeps = max(min(substeps, GRAY_SCOTT_MAX_STABLE_SUBSTEPS), 1)
		per_iteration_dt = total_step_dt / f32(substeps)
	}
	if sim.settings.enable_adaptive_timestep {
		per_iteration_dt = min(per_iteration_dt, gray_scott_estimate_stable_timestep(sim))
	}

	read_index := int(sim.gpu.state_index)
	write_index := 1 - read_index

	for _ in 0 ..< substeps {
		if sim.gpu.storage[read_index].layout != .GENERAL {
			gray_scott_transition_image(sim, vk_ctx, read_index, sim.gpu.storage[read_index].layout, .GENERAL, cmd)
		}
		if sim.gpu.storage[write_index].layout != .GENERAL {
			gray_scott_transition_image(sim, vk_ctx, write_index, sim.gpu.storage[write_index].layout, .GENERAL, cmd)
		}
		dispatch_slot, ok := gray_scott_next_compute_slot(sim)
		if !ok {
			engine.log_error("gray_scott_step_compute_resources: compute dispatch slots exhausted")
			return false
		}
		gray_scott_write_params(sim, dispatch_slot, GRAY_SCOTT_MODE_STEP, per_iteration_dt)
		if !gray_scott_update_compute_descriptors(sim, vk_ctx, read_index, write_index, dispatch_slot) {
			return false
		}
		if !gray_scott_dispatch_compute(sim, vk_ctx, cmd, dispatch_slot) {
			return false
		}
		read_index, write_index = write_index, read_index
	}
	sim.gpu.state_index = u32(read_index)
	return true
}

gray_scott_gpu_step :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dt: f32) {
	if !gray_scott_ensure_gpu_runtime(sim, vk_ctx) {
		return
	}
	_ = vk_ctx
	_ = gray_scott_step_compute_resources(sim, vk_ctx, cmd, dt)
}

gray_scott_shader_path_report :: proc(sim: ^Gray_Scott_Simulation, kind: string) -> string {
	if kind == "compute" {
		return sim.gpu.step_shader_spirv_path
	}
	return sim.gpu.present_shader_spirv_path
}

gray_scott_gpu_present :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	extent := vk_ctx.swapchain_extent
	viewport := vk.Viewport{x = 0, y = 0, width = f32(extent.width), height = f32(extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = extent}
	gray_scott_gpu_present_viewport(sim, vk_ctx, cmd, viewport, scissor)
}

gray_scott_gpu_present_viewport :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gray_scott_gpu_prepare_present_viewport(sim, vk_ctx, cmd) {
		return
	}
	gray_scott_gpu_draw_prepared_viewport(sim, vk_ctx, cmd, viewport, scissor)
}

gray_scott_gpu_prepare_present_viewport :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) -> bool {
	if !gray_scott_ensure_gpu_runtime(sim, vk_ctx) {
		return false
	}

	if sim.gpu.present_pipeline.pipeline == vk.Pipeline(0) {
		return false
	}
	if sim.gpu.state_index >= 2 {
		return false
	}
	state_index := int(sim.gpu.state_index)
	extent := vk_ctx.swapchain_extent
	if extent.width == 0 || extent.height == 0 {
		return false
	}
	if state_index < 0 || state_index >= 2 {
		return false
	}
	if sim.gpu.storage[state_index].layout != .SHADER_READ_ONLY_OPTIMAL {
		gray_scott_transition_image(sim, vk_ctx, state_index, sim.gpu.storage[state_index].layout, .SHADER_READ_ONLY_OPTIMAL, cmd)
	}
	gray_scott_sync_present_resources(sim)
	if !gray_scott_update_present_descriptor(sim, vk_ctx, state_index) {
		return false
	}
	return true
}

gray_scott_gpu_draw_prepared_viewport :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if sim == nil || !sim.gpu.ready || sim.gpu.present_pipeline.pipeline == vk.Pipeline(0) {
		return
	}

	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(cmd, 0, 1, &local_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &local_scissor)
	vk.CmdBindPipeline(cmd, .GRAPHICS, sim.gpu.present_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, sim.gpu.present_pipeline.layout, 0, 1, &sim.gpu.present_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	tile_count := infinite_render_tile_count(sim.runtime.camera_zoom)
	vk.CmdDraw(cmd, 6, tile_count * tile_count, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
}

gray_scott_destroy :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) {
	gray_scott_stop_webcam(sim)
	if vk_ctx == nil || vk_ctx.device == nil {
		sim.gpu = {}
		return
	}

	if sim.gpu.compute_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.compute_pipeline.pipeline, nil)
		sim.gpu.compute_pipeline.pipeline = vk.Pipeline(0)
	}
	if sim.gpu.compute_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.compute_pipeline.layout, nil)
		sim.gpu.compute_pipeline.layout = vk.PipelineLayout(0)
	}

	if sim.gpu.present_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.present_pipeline)
	}

	if sim.gpu.compute_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.compute_set_layout, nil)
		sim.gpu.compute_set_layout = vk.DescriptorSetLayout(0)
	}
	if sim.gpu.present_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.present_set_layout, nil)
		sim.gpu.present_set_layout = vk.DescriptorSetLayout(0)
	}
	if sim.gpu.compute_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, sim.gpu.compute_pool, nil)
		sim.gpu.compute_pool = vk.DescriptorPool(0)
	}
	if sim.gpu.present_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, sim.gpu.present_pool, nil)
		sim.gpu.present_pool = vk.DescriptorPool(0)
	}
	if sim.gpu.sampler != vk.Sampler(0) {
		vk.DestroySampler(vk_ctx.device, sim.gpu.sampler, nil)
		sim.gpu.sampler = vk.Sampler(0)
	}
	for i := 0; i < 2; i += 1 {
		if sim.gpu.storage[i].view != vk.ImageView(0) {
			vk.DestroyImageView(vk_ctx.device, sim.gpu.storage[i].view, nil)
		}
		if sim.gpu.storage[i].handle != vk.Image(0) {
			vk.DestroyImage(vk_ctx.device, sim.gpu.storage[i].handle, nil)
		}
		if sim.gpu.storage[i].memory != vk.DeviceMemory(0) {
			vk.FreeMemory(vk_ctx.device, sim.gpu.storage[i].memory, nil)
		}
		sim.gpu.storage[i] = {}
	}
	for i := 0; i < len(sim.gpu.params_buffers); i += 1 {
		if sim.gpu.params_buffers[i].handle != vk.Buffer(0) {
			engine.vk_destroy_buffer(vk_ctx, &sim.gpu.params_buffers[i])
		}
	}
	if sim.gpu.nutrient_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.nutrient_buffer)
	}
	if sim.gpu.lut_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.lut_buffer)
	}
	if sim.gpu.present_params_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.present_params_buffer)
	}
	if sim.gpu.camera_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.camera_buffer)
	}
	if sim.gpu.fullscreen_vertices.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.fullscreen_vertices)
	}
	if sim.gpu.step_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.step_shader_module)
	}
	if sim.gpu.present_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.present_shader_module)
	}
	if sim.gpu.vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.vertex_shader_module)
	}

	sim.gpu.ready = false
	sim.gpu.compute_sets = {}
	sim.gpu.present_set = vk.DescriptorSet(0)
	sim.gpu.state_index = 0
	sim.gpu.step_shader_spirv_path = ""
	sim.gpu.vertex_shader_spirv_path = ""
	sim.gpu.present_shader_spirv_path = ""
}

gray_scott_reset_runtime :: proc(sim: ^Gray_Scott_Simulation) {
	sim.runtime.simulation_time = 0
	sim.runtime.frame_index = 0
	sim.runtime.pending_seed_mode = GRAY_SCOTT_MODE_INITIAL_SEED
	sim.runtime.paint_active = false
	sim.gpu.ready = false
}

gray_scott_seed_noise :: proc(sim: ^Gray_Scott_Simulation) {
	sim.runtime.seed += 0x9e3779b9
	if sim.runtime.seed == 0 {
		sim.runtime.seed = 0x6d2b79f5
	}
	sim.runtime.pending_seed_mode = GRAY_SCOTT_MODE_NOISE_SEED
	sim.gpu.ready = false
}

gray_scott_random01 :: proc(seed: ^u32) -> f32 {
	x := seed^ + 0x9e3779b9
	x = (x ~ (x >> 16)) * 0x7feb352d
	x = (x ~ (x >> 15)) * 0x846ca68b
	x = x ~ (x >> 16)
	seed^ = x
	return f32(x) / f32(0xffffffff)
}

gray_scott_random_range :: proc(seed: ^u32, min_value, max_value: f32) -> f32 {
	return min_value + (max_value - min_value) * gray_scott_random01(seed)
}

gray_scott_randomize_settings :: proc(sim: ^Gray_Scott_Simulation) {
	seed := sim.runtime.seed + u32(sim.runtime.frame_index & 0xffffffff) + 1
	sim.settings.feed = gray_scott_random_range(&seed, 0.02, 0.08)
	sim.settings.kill = gray_scott_random_range(&seed, 0.04, 0.08)
	sim.settings.diffusion_a = gray_scott_random_range(&seed, 0.1, 0.3)
	sim.settings.diffusion_b = gray_scott_random_range(&seed, 0.05, 0.15)
	sim.settings.timestep = gray_scott_random_range(&seed, 0.5, 2.0)
	sim.settings.simulation_speed = 1.0
	sim.runtime.seed = seed
	sim.runtime.current_preset_index = len(GRAY_SCOTT_BUILTIN_PRESET_NAMES) - 1
}

gray_scott_load_settings :: proc(sim: ^Gray_Scott_Simulation, settings: Gray_Scott_Settings) {
	sim.settings = settings
	sim.runtime.current_preset_index = len(GRAY_SCOTT_BUILTIN_PRESET_NAMES) - 1
	gray_scott_upload_nutrient_map(sim)
}

gray_scott_save_settings :: proc(sim: ^Gray_Scott_Simulation) -> Gray_Scott_Settings {
	return sim.settings
}

gray_scott_controls_content_height :: proc(sim: ^Gray_Scott_Simulation, ctx: ^uifw.Gui_Context) -> f32 {
	rows := 0
	sections := 0
	add_section :: proc(rows: ^int, sections: ^int, count: int) {
		sections^ += 1
		rows^ += count
	}

	add_section(&rows, &sections, 5) // About
	add_section(&rows, &sections, preset_fieldset_content_rows(&sim.runtime.preset_fieldset)) // Presets
	add_section(&rows, &sections, 34) // Display
	add_section(&rows, &sections, 5) // Post Processing
	add_section(&rows, &sections, 5) // Controls
	add_section(&rows, &sections, 4) // Settings
	add_section(&rows, &sections, 26) // Reaction-Diffusion
	if sim.settings.mask_pattern != .Disabled {
		rows += 6
		if sim.settings.mask_pattern == .Nutrient_Map {
			rows += 6
		}
	}
	add_section(&rows, &sections, 5) // Camera
	slider_extra := max(uifw.gui_slider_height(ctx) - ctx.style.row_height, 0)
	slider_count := sim.settings.mask_pattern != .Disabled ? 6 : 5
	return f32(rows) * ctx.style.row_height + f32(max(rows - 1, 0) + sections + 8) * ctx.style.spacing + f32(sections) * 12 + slider_extra * f32(slider_count)
}

gray_scott_enqueue_preset_command :: proc(worker: ^Render_Worker_State, kind: Ui_To_Render_Command_Kind, name: string) {
	if worker == nil || worker.ui_to_render == nil {
		return
	}
	cmd: Ui_To_Render_Command
	cmd.kind = kind
	write_fixed_string(cmd.preset_name[:], name)
	_ = engine.queue_try_push(worker.ui_to_render, cmd)
}

gray_scott_plot_value_to_point :: proc(area: uifw.Rect, value, min_value, max_value: uifw.Vec2) -> uifw.Vec2 {
	xn := uifw.gui_clamp01((value.x - min_value.x) / max(max_value.x - min_value.x, 0.000001))
	yn := uifw.gui_clamp01((value.y - min_value.y) / max(max_value.y - min_value.y, 0.000001))
	return {
		area.x + area.w * xn,
		area.y + area.h * (1 - yn),
	}
}

gray_scott_plot_point_to_value :: proc(area: uifw.Rect, point, min_value, max_value: uifw.Vec2) -> uifw.Vec2 {
	xn := uifw.gui_clamp01((point.x - area.x) / max(area.w, 1))
	yn := 1 - uifw.gui_clamp01((point.y - area.y) / max(area.h, 1))
	return {
		min_value.x + (max_value.x - min_value.x) * xn,
		min_value.y + (max_value.y - min_value.y) * yn,
	}
}

gray_scott_draw_plot_grid :: proc(ctx: ^uifw.Gui_Context, area: uifw.Rect) {
	grid_color := uifw.gui_apply_opacity(ctx.style.panel_border, 0.48)
	for i in 1 ..< 10 {
		t := f32(i) / 10
		x := area.x + area.w * t
		y := area.y + area.h * t
		uifw.gui_line(ctx, {x, area.y}, {x, area.y + area.h}, grid_color, 1)
		uifw.gui_line(ctx, {area.x, y}, {area.x + area.w, y}, grid_color, 1)
	}
}

gray_scott_draw_plot_handle :: proc(ctx: ^uifw.Gui_Context, center: uifw.Vec2, fill, stroke: uifw.Color) {
	outer := f32(11)
	inner := f32(8)
	uifw.gui_ellipse(ctx, {center.x - outer, center.y - outer, outer * 2, outer * 2}, uifw.gui_apply_opacity(fill, 0.20))
	uifw.gui_ellipse(ctx, {center.x - inner, center.y - inner, inner * 2, inner * 2}, fill)
	uifw.gui_ellipse_stroke(ctx, {center.x - inner, center.y - inner, inner * 2, inner * 2}, stroke, 2)
}

gray_scott_xy_plot :: proc(ctx: ^uifw.Gui_Context, title, key, x_label, y_label, x_short, y_short: string, x: ^f32, y: ^f32, min_value, max_value: uifw.Vec2, fill, stroke: uifw.Color) -> bool {
	bounds := uifw.gui_next_rect(ctx, height = 206)
	id := uifw.gui_make_id(ctx, key)
	title_rect := uifw.Rect{bounds.x, bounds.y, bounds.w, ctx.style.row_height}
	uifw.gui_text_clipped(ctx, title_rect, {bounds.x + 2, bounds.y + 4}, title, ctx.style.text)

	plot_top := bounds.y + ctx.style.row_height + 4
	plot_height := max(bounds.h - ctx.style.row_height - 28, 64)
	area := uifw.Rect{bounds.x + 8, plot_top, max(bounds.w - 16, 1), plot_height}
	current := uifw.Vec2{x^, y^}
	handle := gray_scott_plot_value_to_point(area, current, min_value, max_value)
	changed := false

	if uifw.gui_drag_handle_region(ctx, id, area, handle, 12) {
		next := gray_scott_plot_point_to_value(area, ctx.input.mouse_pos, min_value, max_value)
		x^ = next.x
		y^ = next.y
		changed = true
	}
	nav_x, nav_y := uifw.gui_focused_nav(ctx, id)
	if nav_x != 0 || nav_y != 0 {
		step := uifw.Vec2{(max_value.x - min_value.x) * 0.025, (max_value.y - min_value.y) * 0.025}
		x^ += nav_x * step.x
		y^ -= nav_y * step.y
		x^ = min(max(x^, min_value.x), max_value.x)
		y^ = min(max(y^, min_value.y), max_value.y)
		changed = true
	}

	panel := uifw.gui_inset(area, -6)
	bg := uifw.gui_lerp_color(ctx.style.panel, ctx.style.control, 0.55)
	uifw.gui_round_rect(ctx, panel, ctx.style.radius_control, bg)
	uifw.gui_round_stroke(ctx, panel, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)
	gray_scott_draw_plot_grid(ctx, area)
	uifw.gui_round_stroke(ctx, area, 2, uifw.gui_apply_opacity(ctx.style.text_muted, 0.58), 2)

	handle = gray_scott_plot_value_to_point(area, {x^, y^}, min_value, max_value)
	cross_color := uifw.gui_apply_opacity(fill, 0.36)
	uifw.gui_line(ctx, {area.x, handle.y}, {area.x + area.w, handle.y}, cross_color, 1)
	uifw.gui_line(ctx, {handle.x, area.y}, {handle.x, area.y + area.h}, cross_color, 1)
	gray_scott_draw_plot_handle(ctx, handle, fill, stroke)
	if ctx.focused == id {
		uifw.gui_focus_ring(ctx, panel)
	}

	uifw.gui_text_clipped(ctx, {area.x, area.y + area.h + 4, area.w, ctx.style.text_height}, {area.x + 2, area.y + area.h + 5}, fmt.tprintf("%s %.3f - %.3f", x_label, min_value.x, max_value.x), ctx.style.text_muted)
	uifw.gui_text_right(ctx, {area.x, area.y + area.h + 4, area.w, ctx.style.text_height}, fmt.tprintf("%s %.3f - %.3f", y_label, min_value.y, max_value.y), ctx.style.text_muted)
	value_label := fmt.tprintf("%s %.3f  %s %.3f", x_short, x^, y_short, y^)
	uifw.gui_text_centered(ctx, {area.x, area.y + 5, area.w, ctx.style.text_height}, value_label, ctx.style.text)
	return changed
}

gray_scott_draw_controls :: proc(sim: ^Gray_Scott_Simulation, ctx: ^uifw.Gui_Context, panel: uifw.Rect, scroll: ^f32, worker: ^Render_Worker_State, color_editor: ^Color_Scheme_Editor_State) -> bool {
	changed := false
	uifw.gui_panel_begin(ctx, panel)
	viewport := uifw.gui_next_rect(ctx, height = max(panel.h - ctx.style.panel_padding * 2, 0))
	content_height := gray_scott_controls_content_height(sim, ctx)
	uifw.gui_scroll_begin(ctx, viewport, content_height, scroll)
	uifw.gui_push_id(ctx, "gray_scott_controls")

	uifw.gui_heading(ctx, "About this simulation")
	uifw.gui_text_block(ctx, "Reaction-diffusion patterns from two virtual chemicals, U and V, with feed and kill rates shaping spots, stripes, spirals, and labyrinths.", ctx.content_width, ctx.style.text_muted)
	uifw.gui_spacer(ctx, 8)

	uifw.gui_heading(ctx, "Presets")
	preset_fieldset_draw(
		ctx,
		&sim.runtime.preset_fieldset,
		worker,
		"gray_scott",
		GRAY_SCOTT_BUILTIN_PRESET_NAMES[:],
		sim.runtime.current_preset_index,
		Preset_Fieldset_Builtin_Context {kind = .Gray_Scott, gray_scott = sim},
	)
	uifw.gui_spacer(ctx, 8)

	uifw.gui_heading(ctx, "Display Settings")
	if color_scheme_editor_draw_selector(ctx, color_editor, "gray_scott_color_scheme", &sim.settings.color_scheme, &sim.settings.color_scheme_reversed) {
		changed = true
	}
	uifw.gui_spacer(ctx, 8)

	post_options := shared_default_post_processing_menu_options()
	if shared_post_processing_menu(ctx, &sim.settings.blur_enabled, &sim.settings.blur_radius, &sim.settings.blur_sigma, post_options) {
		changed = true
	}
	uifw.gui_spacer(ctx, 8)

	cursor_options := shared_default_cursor_config_options()
	cursor_options.size_step = 0.01
	cursor_options.strength_step = 0.05
	controls_options := Controls_Panel_Options {
		mouse_interaction_text = "Left click: seed reaction | Right click: erase",
		cursor_settings_title = "Cursor Settings",
		cursor = cursor_options,
	}
	if shared_controls_panel(ctx, controls_options, &sim.settings.cursor_size, &sim.settings.cursor_strength) {
		changed = true
	}
	uifw.gui_spacer(ctx, 8)

	uifw.gui_heading(ctx, "Settings")
	if uifw.gui_button(ctx, "Reset Simulation", "reset") {
		gray_scott_reset_runtime(sim)
		changed = true
	}
	if uifw.gui_button(ctx, "Randomize Settings", "randomize") {
		gray_scott_randomize_settings(sim)
		changed = true
	}
	if uifw.gui_button(ctx, "Seed Noise", "seed_noise") {
		gray_scott_seed_noise(sim)
		changed = true
	}
	uifw.gui_spacer(ctx, 8)

	uifw.gui_heading(ctx, "Reaction-Diffusion")
	uifw.gui_label(ctx, "Drag the handles to adjust paired parameters.")
	if gray_scott_xy_plot(ctx, "Feed Rate vs Kill Rate", "feed_kill_plot", "Feed", "Kill", "F", "K", &sim.settings.feed, &sim.settings.kill, {0.0, 0.0}, {0.1, 0.1}, {0.94, 0.28, 0.31, 1.0}, {0.74, 0.16, 0.18, 1.0}) {
		changed = true
	}
	if gray_scott_xy_plot(ctx, "Diffusion U vs Diffusion V", "diffusion_plot", "Diffusion U", "Diffusion V", "Du", "Dv", &sim.settings.diffusion_a, &sim.settings.diffusion_b, {0.0, 0.0}, {0.5, 0.25}, {0.20, 0.78, 0.42, 1.0}, {0.10, 0.55, 0.28, 1.0}) {
		changed = true
	}
	if uifw.gui_slider_f32(ctx, fmt.tprintf("Feed Rate: %.3f", sim.settings.feed), "feed", &sim.settings.feed, 0.0, 0.1) {
		changed = true
	}
	if uifw.gui_slider_f32(ctx, fmt.tprintf("Kill Rate: %.3f", sim.settings.kill), "kill", &sim.settings.kill, 0.0, 0.1) {
		changed = true
	}
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Diffusion U: %.3f", sim.settings.diffusion_a), "diffusion_u", &sim.settings.diffusion_a, 0.01, 0.0, 0.5) {
		changed = true
	}
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Diffusion V: %.3f", sim.settings.diffusion_b), "diffusion_v", &sim.settings.diffusion_b, 0.01, 0.0, 0.25) {
		changed = true
	}
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Timestep: %.2f", sim.settings.timestep), "timestep", &sim.settings.timestep, 0.05, 0.0, 4.0) {
		changed = true
	}
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Simulation Speed: %.2fx", sim.settings.simulation_speed), "simulation_speed", &sim.settings.simulation_speed, 0.25, 0.0, 32.0) {
		changed = true
	}
	if uifw.gui_toggle(ctx, fmt.tprintf("Adaptive Timestep: %v", sim.settings.enable_adaptive_timestep), "adaptive_timestep", &sim.settings.enable_adaptive_timestep) {
		changed = true
	}
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Max Timestep: %.2f", sim.settings.max_timestep), "max_timestep", &sim.settings.max_timestep, 0.05, 0.1, 8.0) {
		changed = true
	}
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Stability: %.2f", sim.settings.stability_factor), "stability", &sim.settings.stability_factor, 0.05, 0.1, 1.0) {
		changed = true
	}
	pattern_index := int(u32(sim.settings.mask_pattern))
	if uifw.gui_selector(ctx, fmt.tprintf("Mask Pattern: %s", GRAY_SCOTT_MASK_PATTERN_NAMES[pattern_index]), "mask_pattern", &pattern_index, GRAY_SCOTT_MASK_PATTERN_NAMES[:]) {
		sim.settings.mask_pattern = Gray_Scott_Mask_Pattern(pattern_index)
		changed = true
	}
	if sim.settings.mask_pattern != .Disabled {
		target_index := gray_scott_mask_target_to_index(sim.settings.mask_target)
		if uifw.gui_selector(ctx, fmt.tprintf("Mask Target: %s", GRAY_SCOTT_MASK_TARGET_NAMES[target_index]), "mask_target", &target_index, GRAY_SCOTT_MASK_TARGET_NAMES[:]) {
			sim.settings.mask_target = gray_scott_mask_target_from_index(target_index)
			changed = true
		}
		if uifw.gui_toggle(ctx, fmt.tprintf("Mirror Horizontal: %v", sim.settings.mask_mirror_horizontal), "mirror_h", &sim.settings.mask_mirror_horizontal) {
			changed = true
		}
		if uifw.gui_toggle(ctx, fmt.tprintf("Mirror Vertical: %v", sim.settings.mask_mirror_vertical), "mirror_v", &sim.settings.mask_mirror_vertical) {
			changed = true
		}
		if uifw.gui_toggle(ctx, fmt.tprintf("Invert Tone: %v", sim.settings.mask_invert_tone), "invert_tone", &sim.settings.mask_invert_tone) {
			changed = true
		}
		if uifw.gui_slider_f32(ctx, fmt.tprintf("Mask Strength: %.2f", sim.settings.mask_strength), "mask_strength", &sim.settings.mask_strength, 0.0, 1.0) {
			changed = true
		}
		if sim.settings.mask_pattern == .Nutrient_Map {
			fit_index := int(u32(sim.settings.nutrient_image_fit_mode))
			image_options := shared_default_image_selector_options()
			image_options.fit_label = "Image Fit"
			image_options.fit_key = "nutrient_image_fit"
			image_options.load_label = "Reload Selected"
			image_options.load_key = "load_nutrient_png"
			image_options.browse_label = "Choose Image..."
			image_options.browse_key = "browse_nutrient_png"
			image_options.clear_key = "clear_nutrient_image"
			image_options.selected_label = "Selected Image"
			image_options.empty_label = fmt.tprintf("No image selected (%s)", IMAGE_FILE_FORMAT_LABEL)
			image_options.selected_path = fixed_string(sim.settings.nutrient_image_path[:])
			image_result := shared_image_selector(ctx, &fit_index, GRAY_SCOTT_IMAGE_FIT_MODE_NAMES[:], image_options)
			if image_result.fit_changed {
				sim.settings.nutrient_image_fit_mode = Gray_Scott_Image_Fit_Mode(u32(max(min(fit_index, len(GRAY_SCOTT_IMAGE_FIT_MODE_NAMES) - 1), 0)))
				gray_scott_upload_nutrient_map(sim)
				changed = true
			}
			if image_result.load_requested {
				gray_scott_upload_nutrient_map(sim)
				changed = true
			}
			if image_result.browse_requested {
				sim.runtime.nutrient_image_dialog_requested = true
				changed = true
			}
			if image_result.clear_requested {
				write_fixed_string(sim.settings.nutrient_image_path[:], "")
				sim.runtime.nutrient_image_loaded = false
				gray_scott_upload_nutrient_map(sim)
				changed = true
			}
			webcam_options := shared_default_webcam_controls_options()
			webcam_options.active = sim.runtime.webcam_active
			webcam_options.device_count = gray_scott_webcam_device_count()
			webcam_result := shared_webcam_controls(ctx, webcam_options)
			if webcam_result.action == .Stop {
				gray_scott_stop_webcam(sim)
				gray_scott_upload_nutrient_map(sim)
				changed = true
			} else if webcam_result.action == .Start {
				if gray_scott_start_webcam(sim) {
					changed = true
				}
			}
			status := sim.runtime.nutrient_image_loaded ? "Loaded selected image" : "Using procedural nutrient map"
			if sim.runtime.webcam_active {
				status = fmt.tprintf("Webcam frames: %d", sim.runtime.webcam_frames)
			} else if sim.runtime.webcam_permission_denied {
				status = "Webcam permission denied"
			} else if gray_scott_webcam_device_count() == 0 {
				status = "No webcam devices"
			}
			uifw.gui_label(ctx, status)
		}
	}

	uifw.gui_spacer(ctx, 8)
	uifw.gui_heading(ctx, "Camera")
	if uifw.gui_button(ctx, "Reset Camera", "reset_camera") {
		gray_scott_reset_camera(sim)
		changed = true
	}
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Zoom: %.2f", sim.runtime.camera_zoom), "camera_zoom", &sim.runtime.camera_zoom, 0.05, 0.05, 64.0) {
		sim.runtime.camera_target_zoom = sim.runtime.camera_zoom
		changed = true
	}
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Pan X: %.2f", sim.runtime.camera_x), "camera_x", &sim.runtime.camera_x, 0.05, -128.0, 128.0) {
		sim.runtime.camera_target_x = sim.runtime.camera_x
		changed = true
	}
	if uifw.gui_number_drag_f32(ctx, fmt.tprintf("Pan Y: %.2f", sim.runtime.camera_y), "camera_y", &sim.runtime.camera_y, 0.05, -128.0, 128.0) {
		sim.runtime.camera_target_y = sim.runtime.camera_y
		changed = true
	}
	if uifw.gui_slider_f32(ctx, fmt.tprintf("Camera Smoothing: %.2f", sim.runtime.camera_smoothing_factor), "camera_smoothing", &sim.runtime.camera_smoothing_factor, 0.0, 1.0) {
		changed = true
	}
	uifw.gui_pop_id(ctx)
	uifw.gui_scroll_end(ctx)
	uifw.gui_panel_end(ctx)
	preset_save_dialog_draw(ctx, &sim.runtime.preset_fieldset, worker, "gray_scott")
	return changed
}
