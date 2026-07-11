package game

import engine "../engine"
import vk "vendor:vulkan"

VORONOI_JFA_INIT_SHADER_SOURCE :: "assets/shaders/simulations/voronoi_ca/shaders/jfa_init.slang"
VORONOI_BROWNIAN_SHADER_SOURCE :: "assets/shaders/simulations/voronoi_ca/shaders/brownian.slang"
VORONOI_JFA_ITERATION_SHADER_SOURCE :: "assets/shaders/simulations/voronoi_ca/shaders/jfa_iteration.slang"
VORONOI_RENDER_SHADER_SOURCE :: "assets/shaders/simulations/voronoi_ca/shaders/voronoi_render_jfa.slang"
VORONOI_JFA_INIT_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/jfa_init"
VORONOI_BROWNIAN_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/brownian"
VORONOI_JFA_ITERATION_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/jfa_iteration"
VORONOI_RENDER_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/voronoi_render_jfa_vertex"
VORONOI_RENDER_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/voronoi_render_jfa_fragment"
VORONOI_SOURCE_ENTRY :: "main"
VORONOI_VERTEX_SOURCE_ENTRY :: "vs_main"
VORONOI_FRAGMENT_SOURCE_ENTRY :: "fs_main"
VORONOI_ENTRY :: cstring("main")
VORONOI_VERTEX_ENTRY :: cstring("main")
VORONOI_FRAGMENT_ENTRY :: cstring("main")
VORONOI_IMAGE_FORMAT :: vk.Format(.R32G32B32A32_SFLOAT)

Voronoi_Vertex :: struct #align(8) {
	position: [2]f32,
	color: f32,
	pad0: f32,
	phase: f32,
	seed: u32,
	pad1: u32,
	random_state: u32,
}

Voronoi_Params :: struct #align(16) {
	count: f32,
	color_mode: f32,
	border_enabled: f32,
	border_width: f32,
	filter_mode: f32,
	resolution_x: f32,
	resolution_y: f32,
	jump_distance: f32,
}

Voronoi_Uniforms :: struct #align(16) {
	resolution: [2]f32,
	time: f32,
	drift: f32,
	_pad0: u32,
	_pad1: u32,
	_pad2: u32,
	_pad3: u32,
}

Voronoi_Brownian_Params :: struct #align(8) {
	speed: f32,
	delta_time: f32,
}

Voronoi_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	layout: vk.ImageLayout,
	width: u32,
	height: u32,
}

Voronoi_Gpu_State :: struct {
	width: u32,
	height: u32,
	jfa_init_shader: engine.Vk_Shader_Module,
	jfa_iteration_shader: engine.Vk_Shader_Module,
	brownian_shader: engine.Vk_Shader_Module,
	render_vertex_shader: engine.Vk_Shader_Module,
	render_fragment_shader: engine.Vk_Shader_Module,
	jfa_init_pipeline: engine.Vk_Compute_Pipeline,
	jfa_iteration_pipeline: engine.Vk_Compute_Pipeline,
	brownian_pipeline: engine.Vk_Compute_Pipeline,
	render_pipeline: engine.Vk_Graphics_Pipeline,
	jfa_set_layout: vk.DescriptorSetLayout,
	jfa_iteration_set_layout: vk.DescriptorSetLayout,
	brownian_set_layout: vk.DescriptorSetLayout,
	render_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	jfa_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	jfa_iteration_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	brownian_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	render_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	vertex_buffer: engine.Vk_Buffer,
	params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	uniforms_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	brownian_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	jfa_image: Voronoi_Image,
	jfa_scratch_image: Voronoi_Image,
	jfa_result_is_scratch: bool,
	point_count: u32,
	time_accum: f32,
	needs_rebuild: bool,
	ready: bool,
}

