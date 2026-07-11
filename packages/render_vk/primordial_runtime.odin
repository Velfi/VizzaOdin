package render_vk

import engine "../engine"
import uifw "../ui"

import "core:math"
import vk "vendor:vulkan"

primordial_create_render_pipeline :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	return primordial_create_render_pipeline_for_pass(gpu, vk_ctx, vk_ctx.render_pass, &gpu.render_pipeline)
}

primordial_create_render_pipeline_for_pass :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, render_pass: vk.RenderPass, out: ^engine.Vk_Graphics_Pipeline) -> bool {
	layouts := [1]vk.DescriptorSetLayout{gpu.render_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = raw_data(layouts[:])}
	if result := vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &out.layout); result != .SUCCESS {
		engine.log_error("primordial_create_render_pipeline: CreatePipelineLayout failed result=", result)
		return false
	}
	stages := [2]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = gpu.render_vertex_shader.handle, pName = PRIMORDIAL_VERTEX_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = gpu.render_fragment_shader.handle, pName = PRIMORDIAL_FRAGMENT_ENTRY},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState {
		blendEnable = true,
		srcColorBlendFactor = .SRC_ALPHA,
		dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
		colorBlendOp = .ADD,
		srcAlphaBlendFactor = .ONE,
		dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA,
		alphaBlendOp = .ADD,
		colorWriteMask = {.R, .G, .B, .A},
	}
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = u32(len(dynamic_states)), pDynamicStates = raw_data(dynamic_states[:])}
	info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = 2,
		pStages = raw_data(stages[:]),
		pVertexInputState = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState = &multisample,
		pColorBlendState = &blend,
		pDynamicState = &dynamic_state,
		layout = out.layout,
		renderPass = render_pass,
		subpass = 0,
	}
	result := vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &out.pipeline)
	if result != .SUCCESS {
		engine.log_error("primordial_create_render_pipeline: CreateGraphicsPipelines failed result=", result)
		return false
	}
	return true
}

primordial_create_fade_pipeline :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, render_pass: vk.RenderPass, out: ^engine.Vk_Graphics_Pipeline) -> bool {
	layouts := [1]vk.DescriptorSetLayout{gpu.fade_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{sType = .PIPELINE_LAYOUT_CREATE_INFO, setLayoutCount = 1, pSetLayouts = raw_data(layouts[:])}
	if vk.CreatePipelineLayout(vk_ctx.device, &layout_info, nil, &out.layout) != .SUCCESS {
		return false
	}
	stages := [2]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = gpu.fade_vertex_shader.handle, pName = PRIMORDIAL_ENTRY},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = gpu.fade_fragment_shader.handle, pName = PRIMORDIAL_ENTRY},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo{sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState{blendEnable = true, srcColorBlendFactor = .SRC_ALPHA, dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA, colorBlendOp = .ADD, srcAlphaBlendFactor = .ONE, dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA, alphaBlendOp = .ADD, colorWriteMask = {.R, .G, .B, .A}}
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [2]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = u32(len(dynamic_states)), pDynamicStates = raw_data(dynamic_states[:])}
	info := vk.GraphicsPipelineCreateInfo{sType = .GRAPHICS_PIPELINE_CREATE_INFO, stageCount = 2, pStages = raw_data(stages[:]), pVertexInputState = &vertex_input, pInputAssemblyState = &input_assembly, pViewportState = &viewport_state, pRasterizationState = &raster, pMultisampleState = &multisample, pColorBlendState = &blend, pDynamicState = &dynamic_state, layout = out.layout, renderPass = render_pass, subpass = 0}
	return vk.CreateGraphicsPipelines(vk_ctx.device, vk.PipelineCache(0), 1, &info, nil, &out.pipeline) == .SUCCESS
}

primordial_create_trace_render_pass :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	attachment := vk.AttachmentDescription{format = vk_ctx.swapchain_format, samples = {._1}, loadOp = .CLEAR, storeOp = .STORE, stencilLoadOp = .DONT_CARE, stencilStoreOp = .DONT_CARE, initialLayout = .COLOR_ATTACHMENT_OPTIMAL, finalLayout = .COLOR_ATTACHMENT_OPTIMAL}
	color_ref := vk.AttachmentReference{attachment = 0, layout = .COLOR_ATTACHMENT_OPTIMAL}
	subpass := vk.SubpassDescription{pipelineBindPoint = .GRAPHICS, colorAttachmentCount = 1, pColorAttachments = &color_ref}
	dependency := vk.SubpassDependency{srcSubpass = vk.SUBPASS_EXTERNAL, dstSubpass = 0, srcStageMask = {.COLOR_ATTACHMENT_OUTPUT}, dstStageMask = {.COLOR_ATTACHMENT_OUTPUT}, dstAccessMask = {.COLOR_ATTACHMENT_WRITE}, dependencyFlags = {.BY_REGION}}
	info := vk.RenderPassCreateInfo{sType = .RENDER_PASS_CREATE_INFO, attachmentCount = 1, pAttachments = &attachment, subpassCount = 1, pSubpasses = &subpass, dependencyCount = 1, pDependencies = &dependency}
	return vk.CreateRenderPass(vk_ctx.device, &info, nil, &gpu.trace_render_pass) == .SUCCESS
}

primordial_create_sampler :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	info := vk.SamplerCreateInfo{sType = .SAMPLER_CREATE_INFO, magFilter = .LINEAR, minFilter = .LINEAR, mipmapMode = .LINEAR, addressModeU = .CLAMP_TO_EDGE, addressModeV = .CLAMP_TO_EDGE, addressModeW = .CLAMP_TO_EDGE, minLod = 0, maxLod = 1}
	return vk.CreateSampler(vk_ctx.device, &info, nil, &gpu.trace_sampler) == .SUCCESS
}

primordial_create_trace_image :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, index: int, width, height: u32) -> bool {
	image := &gpu.trace_images[index]
	image_info := vk.ImageCreateInfo{sType = .IMAGE_CREATE_INFO, imageType = .D2, format = vk_ctx.swapchain_format, extent = {width, height, 1}, mipLevels = 1, arrayLayers = 1, samples = {._1}, tiling = .OPTIMAL, usage = {.COLOR_ATTACHMENT, .SAMPLED, .TRANSFER_SRC, .TRANSFER_DST}, sharingMode = .EXCLUSIVE, initialLayout = .UNDEFINED}
	if vk.CreateImage(vk_ctx.device, &image_info, nil, &image.handle) != .SUCCESS {
		return false
	}
	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device, image.handle, &req)
	memory_type, ok := engine.vk_find_memory_type(vk_ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {
		return false
	}
	alloc := vk.MemoryAllocateInfo{sType = .MEMORY_ALLOCATE_INFO, allocationSize = req.size, memoryTypeIndex = memory_type}
	if vk.AllocateMemory(vk_ctx.device, &alloc, nil, &image.memory) != .SUCCESS {
		return false
	}
	if vk.BindImageMemory(vk_ctx.device, image.handle, image.memory, 0) != .SUCCESS {
		return false
	}
	view_info := vk.ImageViewCreateInfo{sType = .IMAGE_VIEW_CREATE_INFO, image = image.handle, viewType = .D2, format = vk_ctx.swapchain_format, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	if vk.CreateImageView(vk_ctx.device, &view_info, nil, &image.view) != .SUCCESS {
		return false
	}
	attachment := image.view
	framebuffer_info := vk.FramebufferCreateInfo{sType = .FRAMEBUFFER_CREATE_INFO, renderPass = gpu.trace_render_pass, attachmentCount = 1, pAttachments = &attachment, width = width, height = height, layers = 1}
	if vk.CreateFramebuffer(vk_ctx.device, &framebuffer_info, nil, &image.framebuffer) != .SUCCESS {
		return false
	}
	image.layout = .UNDEFINED
	return true
}

primordial_destroy_trace_image :: proc(vk_ctx: ^engine.Vk_Context, image: ^Primordial_Trace_Image) {
	if image.framebuffer != vk.Framebuffer(0) {vk.DestroyFramebuffer(vk_ctx.device, image.framebuffer, nil)}
	if image.view != vk.ImageView(0) {vk.DestroyImageView(vk_ctx.device, image.view, nil)}
	if image.handle != vk.Image(0) {vk.DestroyImage(vk_ctx.device, image.handle, nil)}
	if image.memory != vk.DeviceMemory(0) {vk.FreeMemory(vk_ctx.device, image.memory, nil)}
	image^ = {}
}

primordial_destroy_trace_targets :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	for i in 0 ..< len(gpu.trace_images) {
		primordial_destroy_trace_image(vk_ctx, &gpu.trace_images[i])
	}
	gpu.trace_width = 0
	gpu.trace_height = 0
	gpu.trace_initialized = false
	gpu.trace_write_index = 0
}

primordial_frame_slot_mask :: proc() -> u32 {
	return (u32(1) << u32(engine.MAX_FRAMES_IN_FLIGHT)) - 1
}

primordial_collect_retired_trace_targets :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	bit := u32(1) << u32(frame_slot)
	for i in 0 ..< PRIMORDIAL_RETIRED_TRACE_TARGET_CAP {
		retired := &gpu.retired_trace_targets[i]
		if retired.pending_frame_slots == 0 {
			continue
		}
		retired.pending_frame_slots = retired.pending_frame_slots & (~bit)
		if retired.pending_frame_slots == 0 {
			for image_index in 0 ..< len(retired.images) {
				primordial_destroy_trace_image(vk_ctx, &retired.images[image_index])
			}
		}
	}
}

primordial_retire_trace_targets :: proc(gpu: ^Primordial_Gpu_State) -> bool {
	if gpu.trace_images[0].handle == vk.Image(0) && gpu.trace_images[1].handle == vk.Image(0) {
		gpu.trace_images = {}
		gpu.trace_width = 0
		gpu.trace_height = 0
		gpu.trace_initialized = false
		gpu.trace_write_index = 0
		return true
	}
	for i in 0 ..< PRIMORDIAL_RETIRED_TRACE_TARGET_CAP {
		retired := &gpu.retired_trace_targets[i]
		if retired.pending_frame_slots == 0 {
			retired.images = gpu.trace_images
			retired.pending_frame_slots = primordial_frame_slot_mask()
			gpu.trace_images = {}
			gpu.trace_width = 0
			gpu.trace_height = 0
			gpu.trace_initialized = false
			gpu.trace_write_index = 0
			return true
		}
	}
	engine.log_warn("primordial: trace target retire slots exhausted")
	return false
}

primordial_ensure_trace_targets :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context) -> bool {
	width := max(vk_ctx.swapchain_extent.width, u32(1))
	height := max(vk_ctx.swapchain_extent.height, u32(1))
	if gpu.trace_width == width && gpu.trace_height == height && gpu.trace_images[0].handle != vk.Image(0) && gpu.trace_images[1].handle != vk.Image(0) {
		return true
	}
	if !primordial_retire_trace_targets(gpu) {
		return false
	}
	for i in 0 ..< len(gpu.trace_images) {
		if !primordial_create_trace_image(gpu, vk_ctx, i, width, height) {
			primordial_destroy_trace_targets(gpu, vk_ctx)
			return false
		}
	}
	gpu.trace_width = width
	gpu.trace_height = height
	frame_slot := int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	primordial_update_trace_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	primordial_collect_retired_trace_targets(gpu, vk_ctx, frame_slot)
	return true
}

primordial_transition_trace_image :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, index: int, new_layout: vk.ImageLayout) {
	image := &gpu.trace_images[index]
	if image.handle == vk.Image(0) || image.layout == new_layout {
		return
	}
	old_layout := image.layout
	src_access: vk.AccessFlags
	dst_access: vk.AccessFlags
	src_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	dst_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	#partial switch old_layout {
	case .UNDEFINED:
		#partial switch new_layout {
		case .COLOR_ATTACHMENT_OPTIMAL:
			dst_access = {.COLOR_ATTACHMENT_WRITE}
			dst_stage = {.COLOR_ATTACHMENT_OUTPUT}
		}
	case .COLOR_ATTACHMENT_OPTIMAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.COLOR_ATTACHMENT_WRITE}
			dst_access = {.SHADER_READ}
			src_stage = {.COLOR_ATTACHMENT_OUTPUT}
			dst_stage = {.FRAGMENT_SHADER}
		}
	case .SHADER_READ_ONLY_OPTIMAL:
		#partial switch new_layout {
		case .COLOR_ATTACHMENT_OPTIMAL:
			src_access = {.SHADER_READ}
			dst_access = {.COLOR_ATTACHMENT_WRITE}
			src_stage = {.FRAGMENT_SHADER}
			dst_stage = {.COLOR_ATTACHMENT_OUTPUT}
		}
	}
	barrier := vk.ImageMemoryBarrier{sType = .IMAGE_MEMORY_BARRIER, srcAccessMask = src_access, dstAccessMask = dst_access, oldLayout = old_layout, newLayout = new_layout, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, image = image.handle, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	vk.CmdPipelineBarrier(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	image.layout = new_layout
}

primordial_gpu_step :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, sim: ^Remaining_Sim_State, dt: f32) {
	if !primordial_gpu_ensure(gpu, vk_ctx, &sim.primordial) || sim.paused {
		return
	}
	frame_slot := int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	read_index := int(gpu.state_index)
	write_index := 1 - read_index
	primordial_write_step_params(gpu, frame_slot, sim, dt, f32(vk_ctx.swapchain_extent.width), f32(vk_ctx.swapchain_extent.height))
	primordial_update_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	grid_clear_set := gpu.grid_clear_sets[frame_slot]
	grid_clear_barrier := vk.MemoryBarrier{sType = .MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.SHADER_READ, .SHADER_WRITE}}
	groups := (gpu.particle_count + PRIMORDIAL_WORKGROUP_SIZE - 1) / PRIMORDIAL_WORKGROUP_SIZE
	grid_populate_barrier := vk.MemoryBarrier{sType = .MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.SHADER_READ}}
	if !gpu.grid_state_valid || gpu.grid_state_index != u32(read_index) {
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.grid_clear_pipeline.pipeline)
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.grid_clear_pipeline.layout, 0, 1, &grid_clear_set, 0, nil)
		vk.CmdDispatch(cmd, PRIMORDIAL_GRID_CELL_COUNT / PRIMORDIAL_WORKGROUP_SIZE, 1, 1)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.COMPUTE_SHADER}, {}, 1, &grid_clear_barrier, 0, nil, 0, nil)
		engine.vk_cmd_count_pipeline_barrier(vk_ctx)
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.grid_populate_pipeline.pipeline)
		grid_populate_set := gpu.grid_populate_sets[frame_slot][write_index]
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.grid_populate_pipeline.layout, 0, 1, &grid_populate_set, 0, nil)
		vk.CmdDispatch(cmd, max(groups, 1), 1, 1)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.COMPUTE_SHADER}, {}, 1, &grid_populate_barrier, 0, nil, 0, nil)
		engine.vk_cmd_count_pipeline_barrier(vk_ctx)
		gpu.grid_state_index = u32(read_index)
		gpu.grid_state_valid = true
	}
	vk.CmdBindPipeline(cmd, .COMPUTE, gpu.update_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	update_set := gpu.update_sets[frame_slot][write_index]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.update_pipeline.layout, 0, 1, &update_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, max(groups, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	if sim.primordial.foreground_color_mode == .Density {
		barrier_update := vk.MemoryBarrier{sType = .MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.SHADER_READ, .SHADER_WRITE}}
		vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.COMPUTE_SHADER}, {}, 1, &barrier_update, 0, nil, 0, nil)
		engine.vk_cmd_count_pipeline_barrier(vk_ctx)
		// Density consumes the newly written positions, so rebuild the shared
		// grid for the output buffer before traversing its local cells.
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.grid_clear_pipeline.pipeline)
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.grid_clear_pipeline.layout, 0, 1, &grid_clear_set, 0, nil)
		vk.CmdDispatch(cmd, PRIMORDIAL_GRID_CELL_COUNT / PRIMORDIAL_WORKGROUP_SIZE, 1, 1)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.COMPUTE_SHADER}, {}, 1, &grid_clear_barrier, 0, nil, 0, nil)
		engine.vk_cmd_count_pipeline_barrier(vk_ctx)
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.grid_populate_pipeline.pipeline)
		output_grid_set := gpu.grid_populate_sets[frame_slot][read_index]
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.grid_populate_pipeline.layout, 0, 1, &output_grid_set, 0, nil)
		vk.CmdDispatch(cmd, max(groups, 1), 1, 1)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
		vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.COMPUTE_SHADER}, {}, 1, &grid_populate_barrier, 0, nil, 0, nil)
		engine.vk_cmd_count_pipeline_barrier(vk_ctx)
		gpu.grid_state_index = u32(write_index)
		gpu.grid_state_valid = true
		vk.CmdBindPipeline(cmd, .COMPUTE, gpu.density_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		density_set := gpu.density_sets[frame_slot][write_index]
		vk.CmdBindDescriptorSets(cmd, .COMPUTE, gpu.density_pipeline.layout, 0, 1, &density_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDispatch(cmd, max(groups, 1), 1, 1)
		engine.vk_cmd_count_compute_dispatch(vk_ctx)
	} else {
		gpu.grid_state_valid = false
	}
	barrier_density := vk.MemoryBarrier{sType = .MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = {.SHADER_READ}}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.VERTEX_SHADER}, {}, 1, &barrier_density, 0, nil, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	gpu.state_index = u32(write_index)
}

primordial_draw_background :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, frame_slot: int) {
	if gpu.background_pipeline.pipeline != vk.Pipeline(0) {
		vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.background_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		background_set := gpu.background_sets[frame_slot]
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.background_pipeline.layout, 0, 1, &background_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 6, 1, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
}

primordial_draw_particles :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, frame_slot: int, pipeline: ^engine.Vk_Graphics_Pipeline) {
	vk.CmdBindPipeline(cmd, .GRAPHICS, pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	set := gpu.render_sets[frame_slot][gpu.state_index]
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline.layout, 0, 1, &set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	tile_count := max(gpu.present_tile_count, 1)
	vk.CmdDraw(cmd, 6, gpu.particle_count * tile_count * tile_count, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
}

primordial_draw_ui_overlay :: proc(vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, ui: ^Ui_Render_Sink) {
	if ui == nil {
		return
	}
	engine.vk_cmd_label_begin(vk_ctx, frame.command_buffer, "UI overlay")
	ui_render_sink_draw(ui, vk_ctx, frame.command_buffer, vk_ctx.swapchain_extent)
	engine.vk_cmd_label_end(vk_ctx, frame.command_buffer)
}

primordial_set_viewport :: proc(cmd: vk.CommandBuffer, width, height: u32) {
	viewport := vk.Viewport{x = 0, y = 0, width = f32(width), height = f32(height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = {width, height}}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)
}

primordial_gpu_present_direct :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, sim: ^Remaining_Sim_State, ui: ^Ui_Render_Sink = nil) {
	settings := &sim.primordial
	engine.vk_cmd_begin_swapchain_render_pass(vk_ctx, frame, primordial_clear_color(settings))
	cmd := frame.command_buffer
	frame_slot := int(frame.frame_index)
	primordial_set_viewport(cmd, vk_ctx.swapchain_extent.width, vk_ctx.swapchain_extent.height)
	primordial_draw_background(gpu, vk_ctx, cmd, frame_slot)
	primordial_draw_particles(gpu, vk_ctx, cmd, frame_slot, &gpu.render_pipeline)
	primordial_draw_ui_overlay(vk_ctx, frame, ui)
	engine.vk_cmd_end_swapchain_render_pass(frame)
}

primordial_gpu_present_traces :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, sim: ^Remaining_Sim_State, ui: ^Ui_Render_Sink = nil) {
	settings := &sim.primordial
	if !primordial_ensure_trace_targets(gpu, vk_ctx) {
		primordial_gpu_present_direct(gpu, vk_ctx, frame, sim, ui)
		return
	}
	cmd := frame.command_buffer
	frame_slot := int(frame.frame_index)
	primordial_update_trace_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	primordial_collect_retired_trace_targets(gpu, vk_ctx, frame_slot)
	write_index := int(gpu.trace_write_index & 1)
	read_index := 1 - write_index
	primordial_transition_trace_image(gpu, vk_ctx, cmd, write_index, .COLOR_ATTACHMENT_OPTIMAL)
	if gpu.trace_initialized {
		primordial_transition_trace_image(gpu, vk_ctx, cmd, read_index, .SHADER_READ_ONLY_OPTIMAL)
		primordial_upload_fade_params(gpu, frame_slot, settings)
	}
	clear := primordial_clear_color(settings)
	clear_value := vk.ClearValue{color = {float32 = {clear.r, clear.g, clear.b, clear.a}}}
	begin := vk.RenderPassBeginInfo{sType = .RENDER_PASS_BEGIN_INFO, renderPass = gpu.trace_render_pass, framebuffer = gpu.trace_images[write_index].framebuffer, renderArea = {offset = {0, 0}, extent = {gpu.trace_width, gpu.trace_height}}, clearValueCount = 1, pClearValues = &clear_value}
	vk.CmdBeginRenderPass(cmd, &begin, .INLINE)
	vk_ctx.command_shape.render_pass_count += 1
	primordial_set_viewport(cmd, gpu.trace_width, gpu.trace_height)
	if gpu.trace_initialized {
		vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.fade_pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		fade_set := gpu.fade_sets[frame_slot][read_index]
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.fade_pipeline.layout, 0, 1, &fade_set, 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		vk.CmdDraw(cmd, 3, 1, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
	}
	primordial_draw_particles(gpu, vk_ctx, cmd, frame_slot, &gpu.trace_particle_pipeline)
	vk.CmdEndRenderPass(cmd)
	gpu.trace_images[write_index].layout = .COLOR_ATTACHMENT_OPTIMAL
	gpu.trace_initialized = true
	primordial_transition_trace_image(gpu, vk_ctx, cmd, write_index, .SHADER_READ_ONLY_OPTIMAL)

	engine.vk_cmd_begin_swapchain_render_pass(vk_ctx, frame, primordial_clear_color(settings))
	primordial_set_viewport(cmd, vk_ctx.swapchain_extent.width, vk_ctx.swapchain_extent.height)
	vk.CmdBindPipeline(cmd, .GRAPHICS, gpu.blit_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	blit_set := gpu.blit_sets[frame_slot][write_index]
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gpu.blit_pipeline.layout, 0, 1, &blit_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDraw(cmd, 3, 1, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
	primordial_draw_ui_overlay(vk_ctx, frame, ui)
	engine.vk_cmd_end_swapchain_render_pass(frame)
	gpu.trace_write_index = u32(read_index)
}

primordial_gpu_present :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, sim: ^Remaining_Sim_State, ui: ^Ui_Render_Sink = nil) {
	if !gpu.ready {
		engine.log_warn("primordial_gpu_present: gpu not ready")
		return
	}
	if gpu.render_pipeline.pipeline == vk.Pipeline(0) {
		engine.log_warn("primordial_gpu_present: render pipeline missing")
		return
	}
	settings := &sim.primordial
	frame_slot := int(frame.frame_index)
	if gpu.trace_images[0].handle != vk.Image(0) && gpu.trace_images[1].handle != vk.Image(0) {
		primordial_update_trace_descriptors_for_slot(gpu, vk_ctx, frame_slot)
		primordial_collect_retired_trace_targets(gpu, vk_ctx, frame_slot)
	}
	primordial_upload_lut(gpu, settings)
	primordial_upload_camera(gpu, frame_slot, f32(vk_ctx.swapchain_extent.width), f32(vk_ctx.swapchain_extent.height))
	primordial_upload_render_params_for_extent(gpu, frame_slot, settings, f32(vk_ctx.swapchain_extent.width), f32(vk_ctx.swapchain_extent.height), &sim.camera)
	primordial_upload_background_params(gpu, frame_slot, settings)
	primordial_upload_blit_params(gpu, frame_slot)
	primordial_update_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	if settings.traces_enabled {
		primordial_gpu_present_traces(gpu, vk_ctx, frame, sim, ui)
		return
	}
	primordial_gpu_present_direct(gpu, vk_ctx, frame, sim, ui)
}

primordial_gpu_present_viewport :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, sim: ^Remaining_Sim_State, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gpu.ready || gpu.render_pipeline.pipeline == vk.Pipeline(0) {
		return
	}
	settings := &sim.primordial
	frame_slot := int(frame.frame_index)
	primordial_upload_lut(gpu, settings)
	primordial_upload_camera(gpu, frame_slot, viewport.width, viewport.height)
	primordial_upload_render_params_for_extent(gpu, frame_slot, settings, viewport.width, viewport.height, &sim.camera)
	primordial_upload_background_params(gpu, frame_slot, settings)
	primordial_update_descriptors_for_slot(gpu, vk_ctx, frame_slot)
	primordial_gpu_draw_prepared_viewport(gpu, vk_ctx, frame, viewport, scissor)
}

primordial_gpu_draw_prepared_viewport :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gpu.ready || gpu.render_pipeline.pipeline == vk.Pipeline(0) {
		return
	}
	cmd := frame.command_buffer
	local_viewport := viewport
	local_scissor := scissor
	frame_slot := int(frame.frame_index)
	vk.CmdSetViewport(cmd, 0, 1, &local_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &local_scissor)
	primordial_draw_background(gpu, vk_ctx, cmd, frame_slot)
	primordial_draw_particles(gpu, vk_ctx, cmd, frame_slot, &gpu.render_pipeline)
}

primordial_clear_color :: proc(settings: ^Primordial_Settings) -> uifw.Color {
	color := primordial_background_color(settings)
	return {color[0], color[1], color[2], color[3]}
}

primordial_gpu_destroy :: proc(gpu: ^Primordial_Gpu_State, vk_ctx: ^engine.Vk_Context) {
	if vk_ctx == nil || vk_ctx.device == nil {
		gpu^ = {}
		return
	}
	if gpu.update_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, gpu.update_pipeline.pipeline, nil)
	}
	if gpu.update_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, gpu.update_pipeline.layout, nil)
	}
	if gpu.density_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, gpu.density_pipeline.pipeline, nil)
	}
	if gpu.density_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, gpu.density_pipeline.layout, nil)
	}
	if gpu.grid_clear_pipeline.pipeline != vk.Pipeline(0) {vk.DestroyPipeline(vk_ctx.device, gpu.grid_clear_pipeline.pipeline, nil)}
	if gpu.grid_clear_pipeline.layout != vk.PipelineLayout(0) {vk.DestroyPipelineLayout(vk_ctx.device, gpu.grid_clear_pipeline.layout, nil)}
	if gpu.grid_populate_pipeline.pipeline != vk.Pipeline(0) {vk.DestroyPipeline(vk_ctx.device, gpu.grid_populate_pipeline.pipeline, nil)}
	if gpu.grid_populate_pipeline.layout != vk.PipelineLayout(0) {vk.DestroyPipelineLayout(vk_ctx.device, gpu.grid_populate_pipeline.layout, nil)}
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.background_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.render_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.trace_particle_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.fade_pipeline)
	engine.vk_destroy_graphics_pipeline(vk_ctx, &gpu.blit_pipeline)
	primordial_destroy_trace_targets(gpu, vk_ctx)
	for i in 0 ..< PRIMORDIAL_RETIRED_TRACE_TARGET_CAP {
		for image_index in 0 ..< len(gpu.retired_trace_targets[i].images) {
			primordial_destroy_trace_image(vk_ctx, &gpu.retired_trace_targets[i].images[image_index])
		}
	}
	if gpu.trace_sampler != vk.Sampler(0) {
		vk.DestroySampler(vk_ctx.device, gpu.trace_sampler, nil)
	}
	if gpu.trace_render_pass != vk.RenderPass(0) {
		vk.DestroyRenderPass(vk_ctx.device, gpu.trace_render_pass, nil)
	}
	if gpu.descriptor_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, gpu.descriptor_pool, nil)
	}
	if gpu.update_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.update_set_layout, nil)
	}
	if gpu.density_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.density_set_layout, nil)
	}
	if gpu.grid_clear_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.grid_clear_set_layout, nil)}
	if gpu.grid_populate_set_layout != vk.DescriptorSetLayout(0) {vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.grid_populate_set_layout, nil)}
	if gpu.background_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.background_set_layout, nil)
	}
	if gpu.render_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.render_set_layout, nil)
	}
	if gpu.fade_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gpu.fade_set_layout, nil)
	}
	for i in 0 ..< 2 {
		engine.vk_destroy_buffer(vk_ctx, &gpu.particle_buffers[i])
	}
	engine.vk_destroy_buffer(vk_ctx, &gpu.grid_heads_buffer)
	engine.vk_destroy_buffer(vk_ctx, &gpu.grid_next_buffer)
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		engine.vk_destroy_buffer(vk_ctx, &gpu.sim_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.density_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.background_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.render_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.fade_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.blit_params_buffers[frame_slot])
		engine.vk_destroy_buffer(vk_ctx, &gpu.camera_buffers[frame_slot])
	}
	engine.vk_destroy_buffer(vk_ctx, &gpu.lut_buffer)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.update_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.density_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.grid_clear_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.grid_populate_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.background_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.background_fragment_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.render_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.render_fragment_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.fade_vertex_shader)
	engine.vk_destroy_shader_module(vk_ctx, &gpu.fade_fragment_shader)
	gpu^ = {}
}
