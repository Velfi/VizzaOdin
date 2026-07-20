package render_vk

import engine "zelda_engine:engine"
import vk "vendor:vulkan"

// GPU-owned state only. The concrete buffers and pipelines are added as the
// compute passes land; keeping this independent from ST_Flip_Settings prevents
// transient simulation state from entering preset serialization.
ST_Flip_Gpu_State :: struct {
	compute_shaders: [15]engine.Vk_Shader_Module,
	present_vertex_shader, present_fragment_shader: engine.Vk_Shader_Module,
	compute_pipelines: [15]engine.Vk_Compute_Pipeline,
	present_pipeline: engine.Vk_Graphics_Pipeline,
	compute_set_layout, present_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	compute_sets, present_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	particle_buffer: engine.Vk_Buffer,
	u_accum_buffer, v_accum_buffer: engine.Vk_Buffer,
	u_velocity_buffer, v_velocity_buffer: engine.Vk_Buffer,
	cell_buffer, render_density_buffer, lut_buffer: engine.Vk_Buffer,
	fluid_phase_buffer: engine.Vk_Buffer,
	params_buffers, present_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	ready: bool,
	particle_count: u32,
	grid_width: u32,
	grid_height: u32,
	step_index: u32,
	initialized: bool,
	lut_name: Color_Scheme_Name,
	lut_reversed: bool,
}

st_flip_gpu_destroy :: proc(gpu: ^ST_Flip_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	if gpu == nil do return
	if vk_ctx != nil {
		for &pipeline in gpu.compute_pipelines {
			if pipeline.pipeline != vk.Pipeline(0) do vk.DestroyPipeline(vk_ctx.device, pipeline.pipeline, nil)
			if pipeline.layout != vk.PipelineLayout(0) do vk.DestroyPipelineLayout(vk_ctx.device, pipeline.layout, nil)
		}
		engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.present_pipeline)
		if gpu.descriptor_pool != vk.DescriptorPool(0) do vk.DestroyDescriptorPool(vk_ctx.device, gpu.descriptor_pool, nil)
		if gpu.compute_set_layout != vk.DescriptorSetLayout(0) do vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.compute_set_layout, nil)
		if gpu.present_set_layout != vk.DescriptorSetLayout(0) do vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.present_set_layout, nil)
		engine.vk_destroy_buffer(vk_ctx, &gpu.particle_buffer)
		engine.vk_destroy_buffer(vk_ctx, &gpu.u_accum_buffer)
		engine.vk_destroy_buffer(vk_ctx, &gpu.v_accum_buffer)
		engine.vk_destroy_buffer(vk_ctx, &gpu.u_velocity_buffer)
		engine.vk_destroy_buffer(vk_ctx, &gpu.v_velocity_buffer)
		engine.vk_destroy_buffer(vk_ctx, &gpu.cell_buffer)
		engine.vk_destroy_buffer(vk_ctx, &gpu.render_density_buffer)
		engine.vk_destroy_buffer(vk_ctx, &gpu.fluid_phase_buffer)
		engine.vk_destroy_buffer(vk_ctx, &gpu.lut_buffer)
		for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
			engine.vk_destroy_buffer(vk_ctx, &gpu.params_buffers[i])
			engine.vk_destroy_buffer(vk_ctx, &gpu.present_params_buffers[i])
		}
		for &shader in gpu.compute_shaders do engine.vk_destroy_shader_module(vk_ctx, &shader)
		engine.vk_destroy_shader_module(vk_ctx, &gpu.present_vertex_shader)
		engine.vk_destroy_shader_module(vk_ctx, &gpu.present_fragment_shader)
	}
	gpu^ = {}
}

st_flip_gpu_bind_buffer :: proc(gpu: ^ST_Flip_Gpu_State) -> vk.Buffer {
	return gpu == nil ? vk.Buffer(0) : gpu.particle_buffer.handle
}

ST_Flip_Present_Ubo :: struct #align(16) {
	grid_width: u32,
	grid_height: u32,
	color_scheme_reversed: u32,
	smoothing: f32,
}
