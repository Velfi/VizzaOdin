package game

import uifw "../ui"
import engine "../engine"

import vk "vendor:vulkan"

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
	view_mode: u32,
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
	present_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	storage: [2]Gray_Scott_Gpu_Image,
	sampler: vk.Sampler,
	params_buffers: [GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS]engine.Vk_Buffer,
	nutrient_buffer: engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	present_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	camera_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	fullscreen_vertices: engine.Vk_Buffer,
	lut_uploaded_scheme: Color_Scheme_Name,
	lut_uploaded_reversed: bool,
	state_index: u32,
	compute_dispatch_slot: u32,
	present_frame_slot: u32,
	width: i32,
	height: i32,
}

Gray_Scott_Fullscreen_Vertex :: struct {
	pos: uifw.Vec2,
	color: uifw.Color,
	uv: uifw.Vec2,
	glyph: f32,
	effect: uifw.Color,
	material: uifw.Color,
}

