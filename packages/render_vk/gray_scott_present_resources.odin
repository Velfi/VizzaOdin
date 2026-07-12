package render_vk

import uifw "../ui"
import engine "../engine"

import vk "vendor:vulkan"
import "core:c"
import "core:fmt"
import "core:math"
import "core:os"
import sdl "vendor:sdl3"

gray_scott_create_present_resources :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	lut_size := vk.DeviceSize(size_of(u32) * GRAY_SCOTT_LUT_SIZE)
	if !engine.vk_create_host_buffer(vk_ctx, lut_size, {.STORAGE_BUFFER}, &gray_scott_gpu(sim).lut_buffer) {
		return false
	}
	present_params_size := vk.DeviceSize(size_of(Gray_Scott_Present_Params))
	camera_size := vk.DeviceSize(size_of(Gray_Scott_Camera))
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !engine.vk_create_host_buffer(vk_ctx, present_params_size, {.UNIFORM_BUFFER}, &gray_scott_gpu(sim).present_params_buffers[i]) {
			gray_scott_destroy(sim, vk_ctx)
			return false
		}
		if !engine.vk_create_host_buffer(vk_ctx, camera_size, {.UNIFORM_BUFFER}, &gray_scott_gpu(sim).camera_buffers[i]) {
			gray_scott_destroy(sim, vk_ctx)
			return false
		}
	}
	gray_scott_upload_lut(sim)
	gray_scott_sync_present_resources(sim)

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
	if vk.CreateSampler(vk_ctx.device, &sampler_info, nil, &gray_scott_gpu(sim).sampler) != .SUCCESS {
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
	if vk.CreateDescriptorSetLayout(vk_ctx.device, &present_set_layout_info, nil, &gray_scott_gpu(sim).present_set_layout) != .SUCCESS {
		vk.DestroySampler(vk_ctx.device, gray_scott_gpu(sim).sampler, nil)
		gray_scott_gpu(sim).sampler = vk.Sampler(0)
		return false
	}

	present_pool_sizes := [4]vk.DescriptorPoolSize {
		{
			type = .SAMPLER,
			descriptorCount = engine.MAX_FRAMES_IN_FLIGHT,
		},
		{
			type = .SAMPLED_IMAGE,
			descriptorCount = engine.MAX_FRAMES_IN_FLIGHT,
		},
		{
			type = .STORAGE_BUFFER,
			descriptorCount = engine.MAX_FRAMES_IN_FLIGHT,
		},
		{
			type = .UNIFORM_BUFFER,
			descriptorCount = engine.MAX_FRAMES_IN_FLIGHT * 2,
		},
	}
	present_pool_info := vk.DescriptorPoolCreateInfo {
		sType = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = u32(len(present_pool_sizes)),
		pPoolSizes = raw_data(present_pool_sizes[:]),
		maxSets = engine.MAX_FRAMES_IN_FLIGHT,
	}
	if vk.CreateDescriptorPool(vk_ctx.device, &present_pool_info, nil, &gray_scott_gpu(sim).present_pool) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	present_layouts: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSetLayout
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		present_layouts[i] = gray_scott_gpu(sim).present_set_layout
	}
	present_set_alloc := vk.DescriptorSetAllocateInfo {
		sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool = gray_scott_gpu(sim).present_pool,
		descriptorSetCount = u32(len(present_layouts)),
		pSetLayouts = raw_data(present_layouts[:]),
	}
	if vk.AllocateDescriptorSets(vk_ctx.device, &present_set_alloc, raw_data(gray_scott_gpu(sim).present_sets[:])) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if !gray_scott_update_present_descriptor(sim, vk_ctx, 0, u32(i)) {
			gray_scott_destroy(sim, vk_ctx)
			return false
		}
	}
	return gray_scott_create_present_pipeline(sim, vk_ctx)
}

gray_scott_create_present_pipeline :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts = &gray_scott_gpu(sim).present_set_layout,
	}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &gray_scott_gpu(sim).present_pipeline.layout) != .SUCCESS {
		gray_scott_destroy(sim, vk_ctx)
		return false
	}

	vertex_stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.VERTEX},
		module = gray_scott_gpu(sim).vertex_shader_module.handle,
		pName = GRAY_SCOTT_VERTEX_SPIRV_ENTRY,
	}
	fragment_stage := vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {.FRAGMENT},
		module = gray_scott_gpu(sim).present_shader_module.handle,
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
	rendering := engine.vk_pipeline_rendering_info(&vk_ctx.swapchain_format)
	present_info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		pNext = &rendering,
		stageCount = u32(len(stages)),
		pStages = raw_data(stages[:]),
		pVertexInputState = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState = &multisample,
		pColorBlendState = &blend,
		pDynamicState = &dynamic_state_info,
		layout = gray_scott_gpu(sim).present_pipeline.layout,
	}
	present_result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &present_info, nil, &gray_scott_gpu(sim).present_pipeline.pipeline)
	if present_result != .SUCCESS {
		engine.log_error("gray_scott_create_present_resources: CreateGraphicsPipelines failed result=", present_result)
		gray_scott_destroy(sim, vk_ctx)
		return false
	}
	return true
}

gray_scott_update_compute_descriptors :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, read_index: int, write_index: int, dispatch_slot: int) -> bool {
	if read_index < 0 || read_index >= 2 || write_index < 0 || write_index >= 2 || dispatch_slot < 0 || dispatch_slot >= len(gray_scott_gpu(sim).compute_sets) {
		return false
	}
	if gray_scott_gpu(sim).compute_sets[dispatch_slot] == vk.DescriptorSet(0) {
		return false
	}

	storage_info := vk.DescriptorImageInfo {
		imageLayout = .GENERAL,
		imageView = gray_scott_gpu(sim).storage[write_index].view,
	}
	sample_info := vk.DescriptorImageInfo {
		imageLayout = .GENERAL,
		imageView = gray_scott_gpu(sim).storage[read_index].view,
	}
	buffer_info := vk.DescriptorBufferInfo {
		buffer = gray_scott_gpu(sim).params_buffers[dispatch_slot].handle,
		offset = 0,
		range = vk.DeviceSize(size_of(Gray_Scott_Params)),
	}
	nutrient_info := vk.DescriptorBufferInfo {
		buffer = gray_scott_gpu(sim).nutrient_buffer.handle,
		offset = 0,
		range = vk.DeviceSize(size_of(f32) * max(gray_scott_gpu(sim).width, 1) * max(gray_scott_gpu(sim).height, 1)),
	}
	writes := [4]vk.WriteDescriptorSet {
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = gray_scott_gpu(sim).compute_sets[dispatch_slot],
			dstBinding = 0,
			descriptorType = .STORAGE_IMAGE,
			descriptorCount = 1,
			pImageInfo = &storage_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = gray_scott_gpu(sim).compute_sets[dispatch_slot],
			dstBinding = 1,
			descriptorType = .STORAGE_IMAGE,
			descriptorCount = 1,
			pImageInfo = &sample_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = gray_scott_gpu(sim).compute_sets[dispatch_slot],
			dstBinding = 2,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &buffer_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = gray_scott_gpu(sim).compute_sets[dispatch_slot],
			dstBinding = 3,
			descriptorType = .STORAGE_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &nutrient_info,
		},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
	return true
}

gray_scott_update_present_descriptor :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, read_index: int, frame_slot: u32) -> bool {
	slot := min(frame_slot, u32(engine.MAX_FRAMES_IN_FLIGHT - 1))
	present_set := gray_scott_gpu(sim).present_sets[slot]
	if present_set == vk.DescriptorSet(0) {
		return false
	}
	if read_index < 0 || read_index >= 2 {
		return false
	}
	image_info := vk.DescriptorImageInfo {
		imageLayout = .SHADER_READ_ONLY_OPTIMAL,
		imageView = gray_scott_gpu(sim).storage[read_index].view,
	}
	sampler_info := vk.DescriptorImageInfo {
		sampler = gray_scott_gpu(sim).sampler,
	}
	lut_info := vk.DescriptorBufferInfo {
		buffer = gray_scott_gpu(sim).lut_buffer.handle,
		offset = 0,
		range = vk.DeviceSize(size_of(u32) * GRAY_SCOTT_LUT_SIZE),
	}
	present_params_info := vk.DescriptorBufferInfo {
		buffer = gray_scott_gpu(sim).present_params_buffers[slot].handle,
		offset = 0,
		range = vk.DeviceSize(size_of(Gray_Scott_Present_Params)),
	}
	camera_info := vk.DescriptorBufferInfo {
		buffer = gray_scott_gpu(sim).camera_buffers[slot].handle,
		offset = 0,
		range = vk.DeviceSize(size_of(Gray_Scott_Camera)),
	}
	writes := [5]vk.WriteDescriptorSet {
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = present_set,
			dstBinding = 0,
			descriptorType = .SAMPLED_IMAGE,
			descriptorCount = 1,
			pImageInfo = &image_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = present_set,
			dstBinding = 1,
			descriptorType = .SAMPLER,
			descriptorCount = 1,
			pImageInfo = &sampler_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = present_set,
			dstBinding = 2,
			descriptorType = .STORAGE_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &lut_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = present_set,
			dstBinding = 3,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			pBufferInfo = &present_params_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = present_set,
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
	image := gray_scott_gpu(sim).storage[index].handle
	if image == vk.Image(0) {
		return
	}

	src_access: vk.AccessFlags2
	dst_access: vk.AccessFlags2
	src_stage := vk.PipelineStageFlags2{.TOP_OF_PIPE}
	dst_stage := vk.PipelineStageFlags2{.TOP_OF_PIPE}
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

	barrier := vk.ImageMemoryBarrier2 {
		sType = .IMAGE_MEMORY_BARRIER_2,
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
	engine.vk_cmd_pipeline_barrier2(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	gray_scott_gpu(sim).storage[index].layout = new_layout
}

gray_scott_next_compute_slot :: proc(sim: ^Gray_Scott_Simulation) -> (int, bool) {
	slot := int(gray_scott_gpu(sim).compute_dispatch_slot)
	if slot < 0 || slot >= GRAY_SCOTT_COMPUTE_DISPATCH_SLOTS {
		return 0, false
	}
	gray_scott_gpu(sim).compute_dispatch_slot += 1
	return slot, true
}

gray_scott_write_params :: proc(sim: ^Gray_Scott_Simulation, dispatch_slot: int, mode: u32, dt: f32) {
	if dispatch_slot < 0 || dispatch_slot >= len(gray_scott_gpu(sim).params_buffers) || gray_scott_gpu(sim).params_buffers[dispatch_slot].mapped == nil {
		return
	}
	params := cast(^Gray_Scott_Params)gray_scott_gpu(sim).params_buffers[dispatch_slot].mapped
	noise := &sim.settings.seed_noise
	noise_sync_indices(noise)
	params^ = {
		feed = sim.settings.feed,
		kill = sim.settings.kill,
		diffusion_a = sim.settings.diffusion_a,
		diffusion_b = sim.settings.diffusion_b,
		timestep = dt,
		width = u32(max(gray_scott_gpu(sim).width, 1)),
		height = u32(max(gray_scott_gpu(sim).height, 1)),
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
		noise_kind = u32(noise.kind_index),
		noise_fractal_mode = u32(noise.fractal_mode_index),
		noise_seed = sim.runtime.seed + noise.seed,
		noise_warp_mode = u32(noise.warp_mode_index),
		noise_offset_x = noise.offset_x,
		noise_offset_y = noise.offset_y,
		noise_rotation = noise.rotation,
		noise_anchor_x = noise.anchor_x,
		noise_anchor_y = noise.anchor_y,
		noise_strength = noise.noise_strength,
		noise_amplitude = noise.amplitude,
		noise_frequency = noise.frequency,
		noise_octaves = noise.octaves,
		noise_lacunarity = noise.lacunarity,
		noise_gain = noise.gain,
		noise_warp_octaves = noise.warp_octaves,
		noise_warp_amplitude = noise.warp_amplitude,
		noise_warp_frequency = noise.warp_frequency,
		noise_gabor_iterations = noise.gabor.iterations,
		noise_gabor_velocity = noise.gabor.velocity,
		noise_gabor_band_width = noise.gabor.band_width,
		noise_gabor_band_softness = noise.gabor.band_softness,
		noise_phasor_iterations = noise.phasor.iterations,
		noise_phasor_velocity = noise.phasor.velocity,
		noise_phasor_band_width = noise.phasor.band_width,
		noise_voronoi_output = u32(noise.voronoi.output_index),
		noise_voronoi_distance_mode = u32(noise.voronoi.distance_mode_index),
		noise_wave_velocity = noise.wave.velocity,
		noise_wave_band_width = noise.wave.band_width,
		noise_wave_band_softness = noise.wave.band_softness,
		seed_density = sim.settings.seed_density,
		seed_amplitude = sim.settings.seed_amplitude,
	}
}

gray_scott_compute_memory_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	barrier := vk.MemoryBarrier2 {
		sType = .MEMORY_BARRIER_2,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = {.SHADER_READ, .SHADER_WRITE},
	}
	engine.vk_cmd_pipeline_barrier2(
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
	group_x := u32((max(gray_scott_gpu(sim).width, 1) + GRAY_SCOTT_WORKGROUP_SIZE - 1) / GRAY_SCOTT_WORKGROUP_SIZE)
	group_y := u32((max(gray_scott_gpu(sim).height, 1) + GRAY_SCOTT_WORKGROUP_SIZE - 1) / GRAY_SCOTT_WORKGROUP_SIZE)
	if group_x == 0 || group_y == 0 {
		return false
	}
	if dispatch_slot < 0 || dispatch_slot >= len(gray_scott_gpu(sim).compute_sets) || gray_scott_gpu(sim).compute_sets[dispatch_slot] == vk.DescriptorSet(0) {
		return false
	}
	vk.CmdBindPipeline(cmd, .COMPUTE, gray_scott_gpu(sim).compute_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gray_scott_gpu(sim).compute_pipeline.layout, 0, 1, &gray_scott_gpu(sim).compute_sets[dispatch_slot], 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, group_x, group_y, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	gray_scott_compute_memory_barrier(vk_ctx, cmd)
	return true
}
