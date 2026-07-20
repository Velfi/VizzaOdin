package render_vk

import engine "zelda_engine:engine"

import vk "vendor:vulkan"

GRAY_SCOTT_IMAGE_FORMAT :: vk.Format(.R32G32B32A32_SFLOAT)

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

gray_scott_gpu :: proc(sim: ^Gray_Scott_Simulation) -> ^Gray_Scott_Gpu_State {
	if sim == nil || sim.render_runtime == nil do return nil
	return cast(^Gray_Scott_Gpu_State)sim.render_runtime
}
