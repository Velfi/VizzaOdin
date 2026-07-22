package render_vk

import engine "zelda_engine:engine"
import uifw "zelda_engine:ui"
import vk "vendor:vulkan"

ST_FLIP_COMPUTE_SOURCE :: "assets/shaders/simulations/st_flip/compute.slang"
ST_FLIP_PRESENT_SOURCE :: "assets/shaders/simulations/st_flip/present.slang"
ST_FLIP_COMPUTE_ENTRIES := [?]string{
	"initialize_particles", "clear_grid", "particle_to_grid", "normalize_and_divergence",
	"pressure_jacobi", "pressure_commit", "project_velocity", "extrapolate_velocities", "advect_fluid_phase", "commit_fluid_phase", "render_fluid_phase", "grid_to_particles_advect", "render_particles",
	"reset_grid_history",
	"seed_ink_noise",
}
ST_FLIP_COMPUTE_FALLBACKS := [?]string{
	"build/shaders/simulations/st_flip/compute_compute_initialize_particles",
	"build/shaders/simulations/st_flip/compute_compute_clear_grid",
	"build/shaders/simulations/st_flip/compute_compute_particle_to_grid",
	"build/shaders/simulations/st_flip/compute_compute_normalize_and_divergence",
	"build/shaders/simulations/st_flip/compute_compute_pressure_jacobi",
	"build/shaders/simulations/st_flip/compute_compute_pressure_commit",
	"build/shaders/simulations/st_flip/compute_compute_project_velocity",
	"build/shaders/simulations/st_flip/compute_compute_extrapolate_velocities",
	"build/shaders/simulations/st_flip/compute_compute_advect_fluid_phase",
	"build/shaders/simulations/st_flip/compute_compute_commit_fluid_phase",
	"build/shaders/simulations/st_flip/compute_compute_render_fluid_phase",
	"build/shaders/simulations/st_flip/compute_compute_grid_to_particles_advect",
	"build/shaders/simulations/st_flip/compute_compute_render_particles",
	"build/shaders/simulations/st_flip/compute_compute_reset_grid_history",
	"build/shaders/simulations/st_flip/compute_compute_seed_ink_noise",
}
ST_FLIP_PRESENT_VERTEX_FALLBACK :: "build/shaders/simulations/st_flip/present_vertex"
ST_FLIP_PRESENT_FRAGMENT_FALLBACK :: "build/shaders/simulations/st_flip/present_fragment"

ST_Flip_Buffer_Access :: enum {
	GPU_Only,
	CPU_Written,
}

st_flip_buffer_memory_properties :: proc(access: ST_Flip_Buffer_Access) -> vk.MemoryPropertyFlags {
	switch access {
	case .GPU_Only:    return {.DEVICE_LOCAL}
	case .CPU_Written: return {.HOST_VISIBLE, .HOST_COHERENT}
	}
	return {}
}

// ST-FLIP's simulation buffers are initialized and updated entirely by GPU
// passes. Keeping them unmapped and device-local avoids routing the solver's
// storage traffic through host memory on discrete GPUs.
st_flip_create_device_buffer :: proc(vk_ctx: ^engine.Vk_Context, size: vk.DeviceSize, usage: vk.BufferUsageFlags, resource: string, out: ^engine.Vk_Buffer) -> bool {
	if vk_ctx == nil || out == nil do return false
	out^ = {}
	engine.vk_clear_resource_error(vk_ctx)
	if size == 0 {
		engine.vk_record_resource_error(vk_ctx, .Invalid_Size, resource, 0, 0)
		return false
	}
	info := vk.BufferCreateInfo{sType=.BUFFER_CREATE_INFO, size=size, usage=usage, sharingMode=.EXCLUSIVE}
	if result := vk.CreateBuffer(vk_ctx.device, &info, nil, &out.handle); result != .SUCCESS {
		engine.vk_record_allocation_result(vk_ctx, result, resource, u64(size))
		return false
	}
	req: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(vk_ctx.device, out.handle, &req)
	memory_type, ok := engine.vk_find_memory_type(vk_ctx, req.memoryTypeBits, st_flip_buffer_memory_properties(.GPU_Only))
	if !ok {
		engine.vk_record_resource_error(vk_ctx, .Unsupported, resource, u64(req.size), 0)
		engine.vk_destroy_buffer(vk_ctx, out)
		return false
	}
	alloc := vk.MemoryAllocateInfo{sType=.MEMORY_ALLOCATE_INFO, allocationSize=req.size, memoryTypeIndex=memory_type}
	if !engine.vk_allocate_memory_checked(vk_ctx, &alloc, resource, &out.memory) {
		engine.vk_destroy_buffer(vk_ctx, out)
		return false
	}
	if result := vk.BindBufferMemory(vk_ctx.device, out.handle, out.memory, 0); result != .SUCCESS {
		engine.vk_record_allocation_result(vk_ctx, result, resource, u64(req.size))
		engine.vk_destroy_buffer(vk_ctx, out)
		return false
	}
	out.size = size
	return true
}

st_flip_gpu_ensure :: proc(gpu: ^ST_Flip_Gpu_State, vk_ctx: ^engine.Vk_Context, settings: ^ST_Flip_Settings, width, height: u32) -> bool {
	if gpu == nil || vk_ctx == nil || settings == nil do return false
	grid_height := settings.grid_height
	grid_width := max(u32(f32(grid_height) * f32(max(width, 1)) / f32(max(height, 1)) + 0.5), 1)
	if gpu.ready && gpu.particle_count == settings.particle_count && gpu.grid_width == grid_width && gpu.grid_height == grid_height do return true
	st_flip_gpu_destroy(gpu, vk_ctx)
	gpu.particle_count = settings.particle_count
	gpu.grid_width = grid_width
	gpu.grid_height = grid_height
	for entry, i in ST_FLIP_COMPUTE_ENTRIES {
		if !engine.vk_load_shader_module_with_fallback(vk_ctx, ST_FLIP_COMPUTE_SOURCE, ST_FLIP_COMPUTE_FALLBACKS[i], .Compute, entry, &gpu.compute_shaders[i]) {
			st_flip_gpu_destroy(gpu, vk_ctx); return false
		}
	}
	if !engine.vk_load_shader_module_with_fallback(vk_ctx, ST_FLIP_PRESENT_SOURCE, ST_FLIP_PRESENT_VERTEX_FALLBACK, .Vertex, "vs_main", &gpu.present_vertex_shader) ||
	   !engine.vk_load_shader_module_with_fallback(vk_ctx, ST_FLIP_PRESENT_SOURCE, ST_FLIP_PRESENT_FRAGMENT_FALLBACK, .Fragment, "fs_main", &gpu.present_fragment_shader) {
		st_flip_gpu_destroy(gpu, vk_ctx); return false
	}
	if !st_flip_create_buffers(gpu, vk_ctx) || !st_flip_create_descriptors(gpu, vk_ctx) || !st_flip_create_pipelines(gpu, vk_ctx) {
		st_flip_gpu_destroy(gpu, vk_ctx); return false
	}
	st_flip_upload_lut(gpu, settings)
	gpu.ready = true
	gpu.initialized = false
	return true
}

st_flip_create_buffers :: proc(gpu: ^ST_Flip_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	u_count := (gpu.grid_width + 1) * gpu.grid_height
	v_count := gpu.grid_width * (gpu.grid_height + 1)
	cell_count := gpu.grid_width * gpu.grid_height
	storage := vk.BufferUsageFlags{.STORAGE_BUFFER}
	if !st_flip_create_device_buffer(vk_ctx, vk.DeviceSize(gpu.particle_count) * vk.DeviceSize(size_of(ST_Flip_Particle)), storage, "ST-FLIP particles", &gpu.particle_buffer) ||
	   !st_flip_create_device_buffer(vk_ctx, vk.DeviceSize(u_count) * 8, storage, "ST-FLIP U accumulators", &gpu.u_accum_buffer) ||
	   !st_flip_create_device_buffer(vk_ctx, vk.DeviceSize(v_count) * 8, storage, "ST-FLIP V accumulators", &gpu.v_accum_buffer) ||
	   !st_flip_create_device_buffer(vk_ctx, vk.DeviceSize(u_count) * 8, storage, "ST-FLIP U velocities", &gpu.u_velocity_buffer) ||
	   !st_flip_create_device_buffer(vk_ctx, vk.DeviceSize(v_count) * 8, storage, "ST-FLIP V velocities", &gpu.v_velocity_buffer) ||
	   !st_flip_create_device_buffer(vk_ctx, vk.DeviceSize(cell_count) * 16, storage, "ST-FLIP cells", &gpu.cell_buffer) ||
	   !st_flip_create_device_buffer(vk_ctx, vk.DeviceSize(cell_count) * 4, storage, "ST-FLIP render density", &gpu.render_density_buffer) ||
	   !st_flip_create_device_buffer(vk_ctx, vk.DeviceSize(cell_count) * 8, storage, "ST-FLIP fluid phase", &gpu.fluid_phase_buffer) ||
	   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(COLOR_SCHEME_U32_COUNT) * 4, storage, &gpu.lut_buffer) {
		return false
	}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(ST_Flip_Sim_Params)), {.UNIFORM_BUFFER}, &gpu.params_buffers[i]) ||
		   !engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(size_of(ST_Flip_Present_Ubo)), {.UNIFORM_BUFFER}, &gpu.present_params_buffers[i]) {
			return false
		}
	}
	return true
}

st_flip_create_descriptors :: proc(gpu: ^ST_Flip_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	compute_bindings := [9]vk.DescriptorSetLayoutBinding{
		{binding=0, descriptorType=.STORAGE_BUFFER, descriptorCount=1, stageFlags={.COMPUTE}},
		{binding=1, descriptorType=.UNIFORM_BUFFER, descriptorCount=1, stageFlags={.COMPUTE}},
		{binding=2, descriptorType=.STORAGE_BUFFER, descriptorCount=1, stageFlags={.COMPUTE}},
		{binding=3, descriptorType=.STORAGE_BUFFER, descriptorCount=1, stageFlags={.COMPUTE}},
		{binding=4, descriptorType=.STORAGE_BUFFER, descriptorCount=1, stageFlags={.COMPUTE}},
		{binding=5, descriptorType=.STORAGE_BUFFER, descriptorCount=1, stageFlags={.COMPUTE}},
		{binding=6, descriptorType=.STORAGE_BUFFER, descriptorCount=1, stageFlags={.COMPUTE}},
		{binding=7, descriptorType=.STORAGE_BUFFER, descriptorCount=1, stageFlags={.COMPUTE}},
		{binding=8, descriptorType=.STORAGE_BUFFER, descriptorCount=1, stageFlags={.COMPUTE}},
	}
	info := vk.DescriptorSetLayoutCreateInfo{sType=.DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount=u32(len(compute_bindings)), pBindings=raw_data(compute_bindings[:])}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &info, nil, &gpu.compute_set_layout) != .SUCCESS do return false
	present_bindings := [3]vk.DescriptorSetLayoutBinding{
		{binding=0, descriptorType=.STORAGE_BUFFER, descriptorCount=1, stageFlags={.FRAGMENT}},
		{binding=1, descriptorType=.STORAGE_BUFFER, descriptorCount=1, stageFlags={.FRAGMENT}},
		{binding=2, descriptorType=.UNIFORM_BUFFER, descriptorCount=1, stageFlags={.FRAGMENT}},
	}
	info = {sType=.DESCRIPTOR_SET_LAYOUT_CREATE_INFO, bindingCount=u32(len(present_bindings)), pBindings=raw_data(present_bindings[:])}
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &info, nil, &gpu.present_set_layout) != .SUCCESS do return false
	pool_sizes := [2]vk.DescriptorPoolSize{
		{type=.STORAGE_BUFFER, descriptorCount=u32(engine.MAX_FRAMES_IN_FLIGHT * 10)},
		{type=.UNIFORM_BUFFER, descriptorCount=u32(engine.MAX_FRAMES_IN_FLIGHT * 2)},
	}
	pool_info := vk.DescriptorPoolCreateInfo{sType=.DESCRIPTOR_POOL_CREATE_INFO, maxSets=u32(engine.MAX_FRAMES_IN_FLIGHT * 2), poolSizeCount=2, pPoolSizes=raw_data(pool_sizes[:])}
	if vk.CreateDescriptorPool(vk_ctx.device, &pool_info, nil, &gpu.descriptor_pool) != .SUCCESS do return false
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		layouts := [2]vk.DescriptorSetLayout{gpu.compute_set_layout, gpu.present_set_layout}
		sets: [2]vk.DescriptorSet
		alloc := vk.DescriptorSetAllocateInfo{sType=.DESCRIPTOR_SET_ALLOCATE_INFO, descriptorPool=gpu.descriptor_pool, descriptorSetCount=2, pSetLayouts=raw_data(layouts[:])}
		if vk.AllocateDescriptorSets(vk_ctx.device, &alloc, raw_data(sets[:])) != .SUCCESS do return false
		gpu.compute_sets[i], gpu.present_sets[i] = sets[0], sets[1]
		st_flip_update_descriptors(gpu, vk_ctx, i)
	}
	return true
}

st_flip_update_descriptors :: proc(gpu: ^ST_Flip_Gpu_State, vk_ctx: ^engine.Vk_Context, slot: int) {
	infos := [9]vk.DescriptorBufferInfo{
		{buffer=gpu.particle_buffer.handle, range=gpu.particle_buffer.size},
		{buffer=gpu.params_buffers[slot].handle, range=vk.DeviceSize(size_of(ST_Flip_Sim_Params))},
		{buffer=gpu.u_accum_buffer.handle, range=gpu.u_accum_buffer.size}, {buffer=gpu.v_accum_buffer.handle, range=gpu.v_accum_buffer.size},
		{buffer=gpu.u_velocity_buffer.handle, range=gpu.u_velocity_buffer.size}, {buffer=gpu.v_velocity_buffer.handle, range=gpu.v_velocity_buffer.size},
		{buffer=gpu.cell_buffer.handle, range=gpu.cell_buffer.size}, {buffer=gpu.render_density_buffer.handle, range=gpu.render_density_buffer.size},
		{buffer=gpu.fluid_phase_buffer.handle, range=gpu.fluid_phase_buffer.size},
	}
	writes: [12]vk.WriteDescriptorSet
	for i in 0 ..< 9 {
		writes[i] = {sType=.WRITE_DESCRIPTOR_SET, dstSet=gpu.compute_sets[slot], dstBinding=u32(i), descriptorType=(i == 1 ? vk.DescriptorType.UNIFORM_BUFFER : vk.DescriptorType.STORAGE_BUFFER), descriptorCount=1, pBufferInfo=&infos[i]}
	}
	present_infos := [3]vk.DescriptorBufferInfo{
		{buffer=gpu.render_density_buffer.handle, range=gpu.render_density_buffer.size},
		{buffer=gpu.lut_buffer.handle, range=gpu.lut_buffer.size},
		{buffer=gpu.present_params_buffers[slot].handle, range=vk.DeviceSize(size_of(ST_Flip_Present_Ubo))},
	}
	writes[9] = {sType=.WRITE_DESCRIPTOR_SET, dstSet=gpu.present_sets[slot], dstBinding=0, descriptorType=.STORAGE_BUFFER, descriptorCount=1, pBufferInfo=&present_infos[0]}
	writes[10] = {sType=.WRITE_DESCRIPTOR_SET, dstSet=gpu.present_sets[slot], dstBinding=1, descriptorType=.STORAGE_BUFFER, descriptorCount=1, pBufferInfo=&present_infos[1]}
	writes[11] = {sType=.WRITE_DESCRIPTOR_SET, dstSet=gpu.present_sets[slot], dstBinding=2, descriptorType=.UNIFORM_BUFFER, descriptorCount=1, pBufferInfo=&present_infos[2]}
	vk.UpdateDescriptorSets(vk_ctx.device, 12, raw_data(writes[:]), 0, nil)
}

st_flip_create_pipelines :: proc(gpu: ^ST_Flip_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	for entry, i in ST_FLIP_COMPUTE_ENTRIES {
		layout_info := vk.PipelineLayoutCreateInfo{sType=.PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount=1, pSetLayouts=&gpu.compute_set_layout}
		if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gpu.compute_pipelines[i].layout) != .SUCCESS do return false
		stage := vk.PipelineShaderStageCreateInfo{sType=.PIPELINE_SHADER_STAGE_CREATE_INFO, stage={.COMPUTE}, module=gpu.compute_shaders[i].handle, pName="main"}
		_ = entry
		pipeline_info := vk.ComputePipelineCreateInfo{sType=.COMPUTE_PIPELINE_CREATE_INFO, stage=stage, layout=gpu.compute_pipelines[i].layout}
		if vk.CreateComputePipelines(vk_ctx.device, vk.PipelineCache(0), 1, &pipeline_info, nil, &gpu.compute_pipelines[i].pipeline) != .SUCCESS do return false
	}
	layout_info := vk.PipelineLayoutCreateInfo{sType=.PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount=1, pSetLayouts=&gpu.present_set_layout}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gpu.present_pipeline.layout) != .SUCCESS do return false
	stages := [2]vk.PipelineShaderStageCreateInfo{
		{sType=.PIPELINE_SHADER_STAGE_CREATE_INFO, stage={.VERTEX}, module=gpu.present_vertex_shader.handle, pName="main"},
		{sType=.PIPELINE_SHADER_STAGE_CREATE_INFO, stage={.FRAGMENT}, module=gpu.present_fragment_shader.handle, pName="main"},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType=.PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	assembly := vk.PipelineInputAssemblyStateCreateInfo{sType=.PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology=.TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType=.PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount=1, scissorCount=1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType=.PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode=.FILL, cullMode={}, frontFace=.COUNTER_CLOCKWISE, lineWidth=1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType=.PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples={._1}}
	attachment := vk.PipelineColorBlendAttachmentState{colorWriteMask={.R,.G,.B,.A}}
	blend := vk.PipelineColorBlendStateCreateInfo{sType=.PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount=1, pAttachments=&attachment}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT,.SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo{sType=.PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount=2, pDynamicStates=raw_data(dynamic_states[:])}
	rendering := engine.vk_pipeline_rendering_info(&vk_ctx.swapchain_format)
	info := vk.GraphicsPipelineCreateInfo{sType=.GRAPHICS_PIPELINE_CREATE_INFO, pNext = &rendering, stageCount=2, pStages=raw_data(stages[:]), pVertexInputState=&vertex_input, pInputAssemblyState=&assembly, pViewportState=&viewport_state, pRasterizationState=&raster, pMultisampleState=&multisample, pColorBlendState=&blend, pDynamicState=&dynamic_state, layout=gpu.present_pipeline.layout}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &gpu.present_pipeline.pipeline) == .SUCCESS
}

st_flip_upload_lut :: proc(gpu: ^ST_Flip_Gpu_State, settings: ^ST_Flip_Settings) {
	if gpu.lut_buffer.mapped == nil do return
	scheme := color_scheme_effective(&settings.color_scheme, false)
	data := (cast([^]u32)gpu.lut_buffer.mapped)[:COLOR_SCHEME_U32_COUNT]
	_ = color_scheme_write_u32_buffer(scheme, data)
	gpu.lut_name = settings.color_scheme
}

st_flip_write_params :: proc(gpu: ^ST_Flip_Gpu_State, slot: int, sim: ^ST_Flip_Simulation, dt: f32) {
	occupied_area: f32 = 0.38 * 0.88
	switch sim.settings.initial_condition {
	case .Pool:       occupied_area = 0.92 * 0.92
	case .Twin_Drops: occupied_area = 2 * 3.14159265 * 0.13 * 0.13
	case .Empty:      occupied_area = 1
	case .Dam_Break:
	}
	particles_per_occupied_cell := f32(gpu.particle_count) / max(f32(gpu.grid_width * gpu.grid_height) * occupied_area, 1)
	// Average discrete poly6 face coverage is approximately 0.8. This is m0
	// from Equation 13; phase_steepness is applied separately by the shader.
	// Folding eta_phi into m0 would cancel the user setting entirely.
	reference_mass := particles_per_occupied_cell * 0.8
	params := cast(^ST_Flip_Sim_Params)gpu.params_buffers[slot].mapped
	params^ = {
		grid_width=gpu.grid_width, grid_height=gpu.grid_height, particle_count=gpu.particle_count,
		dt=dt, previous_dt=max(sim.runtime.previous_dt, dt), cell_size=1.0/f32(gpu.grid_height), target_cfl=sim.settings.target_cfl,
		gravity=sim.settings.gravity, flip_ratio=sim.settings.flip_ratio, jitter_strength=sim.settings.jitter_strength,
		phase_steepness=sim.settings.phase_steepness, reference_mass=reference_mass, ink_dissipation=sim.settings.ink_dissipation, brush_size=sim.runtime.brush_size,
		brush_strength=sim.runtime.brush_strength, time=sim.runtime.time, cursor=sim.runtime.cursor_world,
		cursor_velocity=sim.runtime.cursor_velocity, cursor_active=sim.runtime.cursor_active ? 1 : 0,
		cursor_mode=u32(sim.runtime.cursor_mode), random_seed=sim.settings.random_seed, step_index=gpu.step_index,
	}
	present := cast(^ST_Flip_Present_Ubo)gpu.present_params_buffers[slot].mapped
	present^ = {grid_width=gpu.grid_width, grid_height=gpu.grid_height, color_scheme_reversed=sim.settings.color_scheme_reversed ? 1 : 0, smoothing=sim.settings.render_smoothing}
}

st_flip_compute_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	barrier := vk.MemoryBarrier2{sType=.MEMORY_BARRIER_2, srcAccessMask={.SHADER_WRITE}, dstAccessMask={.SHADER_READ,.SHADER_WRITE}}
	engine.vk_cmd_pipeline_barrier2(cmd, {.COMPUTE_SHADER}, {.COMPUTE_SHADER,.FRAGMENT_SHADER}, {}, 1, &barrier, 0, nil, 0, nil)
}

st_flip_dispatch_1d :: proc(gpu: ^ST_Flip_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, slot, pipeline_index: int, count, group_size: u32) {
	pipeline := &gpu.compute_pipelines[pipeline_index]
	vk.CmdBindPipeline(cmd, .COMPUTE, pipeline.pipeline)
	set := gpu.compute_sets[slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, pipeline.layout, 0, 1, &set, 0, nil)
	vk.CmdDispatch(cmd, (count + group_size - 1) / group_size, 1, 1)
	st_flip_compute_barrier(vk_ctx, cmd)
}

st_flip_dispatch_2d :: proc(gpu: ^ST_Flip_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, slot, pipeline_index: int) {
	pipeline := &gpu.compute_pipelines[pipeline_index]
	vk.CmdBindPipeline(cmd, .COMPUTE, pipeline.pipeline)
	set := gpu.compute_sets[slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, pipeline.layout, 0, 1, &set, 0, nil)
	vk.CmdDispatch(cmd, (gpu.grid_width + 15) / 16, (gpu.grid_height + 15) / 16, 1)
	st_flip_compute_barrier(vk_ctx, cmd)
}

// Keep a single frame below the practical Metal command-buffer watchdog
// budget. At 8x, blindly applying 80 full-grid Jacobi+commit pairs exceeds
// 170 million cell visits before the other FLIP passes even begin.
ST_FLIP_PRESSURE_CELL_VISIT_BUDGET :: u64(48_000_000)

st_flip_effective_pressure_iterations :: proc(requested, grid_width, grid_height: u32) -> u32 {
	cell_count := max(u64(grid_width) * u64(grid_height), u64(1))
	budgeted := u32(max(ST_FLIP_PRESSURE_CELL_VISIT_BUDGET / cell_count, u64(16)))
	return min(requested, budgeted)
}

st_flip_gpu_step :: proc(gpu: ^ST_Flip_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim: ^ST_Flip_Simulation, dt: f32, width, height: u32) {
	if !st_flip_gpu_ensure(gpu, vk_ctx, sim.settings, width, height) do return
	slot := int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	st_flip_write_params(gpu, slot, sim, dt)
	if gpu.lut_name != sim.settings.color_scheme do st_flip_upload_lut(gpu, sim.settings)
	did_initialize := false
	if !gpu.initialized || sim.runtime.reset_requested {
		params := cast(^ST_Flip_Sim_Params)gpu.params_buffers[slot].mapped
		params.pass_index = u32(sim.settings.initial_condition)
		st_flip_dispatch_1d(gpu, vk_ctx, cmd, slot, 0, gpu.particle_count, 64)
		gpu.initialized = true
		sim.runtime.reset_requested = false
		did_initialize = true
	}
	let_max := max(max((gpu.grid_width+1)*gpu.grid_height, gpu.grid_width*(gpu.grid_height+1)), gpu.grid_width*gpu.grid_height)
	if did_initialize do st_flip_dispatch_1d(gpu, vk_ctx, cmd, slot, 13, let_max, 256)
	did_seed_noise := false
	if sim.runtime.noise_seed_requested {
		st_flip_dispatch_2d(gpu, vk_ctx, cmd, slot, 14)
		sim.runtime.noise_seed_requested = false
		did_seed_noise = true
	}
	if sim.settings.paused {
		if did_initialize || did_seed_noise {
			st_flip_dispatch_1d(gpu, vk_ctx, cmd, slot, 1, let_max, 256)
			st_flip_dispatch_1d(gpu, vk_ctx, cmd, slot, 10, gpu.grid_width*gpu.grid_height, 256)
		}
		return
	}
	st_flip_dispatch_1d(gpu, vk_ctx, cmd, slot, 1, let_max, 256)
	st_flip_dispatch_1d(gpu, vk_ctx, cmd, slot, 2, gpu.particle_count, 64)
	st_flip_dispatch_2d(gpu, vk_ctx, cmd, slot, 3)
	pressure_iterations := st_flip_effective_pressure_iterations(sim.settings.pressure_iterations, gpu.grid_width, gpu.grid_height)
	for _ in 0 ..< pressure_iterations {
		st_flip_dispatch_2d(gpu, vk_ctx, cmd, slot, 4)
		st_flip_dispatch_1d(gpu, vk_ctx, cmd, slot, 5, gpu.grid_width*gpu.grid_height, 256)
	}
	st_flip_dispatch_2d(gpu, vk_ctx, cmd, slot, 6)
	for _ in 0 ..< 3 do st_flip_dispatch_2d(gpu, vk_ctx, cmd, slot, 7)
	st_flip_dispatch_2d(gpu, vk_ctx, cmd, slot, 8)
	st_flip_dispatch_1d(gpu, vk_ctx, cmd, slot, 9, gpu.grid_width*gpu.grid_height, 256)
	st_flip_dispatch_1d(gpu, vk_ctx, cmd, slot, 10, gpu.grid_width*gpu.grid_height, 256)
	st_flip_dispatch_1d(gpu, vk_ctx, cmd, slot, 11, gpu.particle_count, 64)
	gpu.step_index += 1
	sim.runtime.previous_dt = dt
}

st_flip_gpu_present_viewport :: proc(gpu: ^ST_Flip_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if gpu == nil || !gpu.ready do return
	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(frame.command_buffer, 0, 1, &local_viewport)
	vk.CmdSetScissor(frame.command_buffer, 0, 1, &local_scissor)
	vk.CmdBindPipeline(frame.command_buffer, .GRAPHICS, gpu.present_pipeline.pipeline)
	set := gpu.present_sets[int(frame.frame_index)]
	vk.CmdBindDescriptorSets(frame.command_buffer, .GRAPHICS, gpu.present_pipeline.layout, 0, 1, &set, 0, nil)
	vk.CmdDraw(frame.command_buffer, 6, 1, 0, 0)
}
