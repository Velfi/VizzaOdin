package render_vk

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

Voronoi_Image :: struct {handle: vk.Image, memory: vk.DeviceMemory, view: vk.ImageView, layout: vk.ImageLayout, width: u32, height: u32}

Voronoi_Gpu_State :: struct {
	width, height: u32,
	jfa_init_shader, jfa_iteration_shader, brownian_shader, render_vertex_shader, render_fragment_shader: engine.Vk_Shader_Module,
	jfa_init_pipeline, jfa_iteration_pipeline, brownian_pipeline: engine.Vk_Compute_Pipeline,
	render_pipeline: engine.Vk_Graphics_Pipeline,
	jfa_set_layout, jfa_iteration_set_layout, brownian_set_layout, render_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	jfa_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	jfa_iteration_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	brownian_sets, render_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	vertex_buffer: engine.Vk_Buffer,
	params_buffers, uniforms_buffers, brownian_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	jfa_image, jfa_scratch_image: Voronoi_Image,
	jfa_result_is_scratch: bool,
	point_count: u32,
	initialized_seed: u32,
	time_accum: f32,
	needs_rebuild, ready: bool,
	present_tile_count: u32,
}
