package render_vk

import uifw "../ui"
import engine "../engine"

import vk "vendor:vulkan"
import "core:bytes"
import "core:fmt"
import "core:math"
import png "core:image/png"

ui_renderer_prepare_backdrop_blur :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context, frame: Vk_Frame) -> bool {
	if !renderer.ready || !renderer.needs_backdrop_capture {
		return false
	}
	if !ctx.swapchain_supports_transfer_src {
		return false
	}
	if !ui_renderer_ensure_backdrop_texture(renderer, ctx) {
		return false
	}
	source := &renderer.textures[UI_BACKDROP_SOURCE_TEXTURE_ID]
	if source.image == vk.Image(0) {
		return false
	}

	range := vk.ImageSubresourceRange {
		aspectMask = {.COLOR},
		baseMipLevel = 0,
		levelCount = 1,
		baseArrayLayer = 0,
		layerCount = 1,
	}
	swapchain_image := ctx.swapchain_images[frame.image_index]
	to_src := vk.ImageMemoryBarrier2 {
		sType = .IMAGE_MEMORY_BARRIER_2,
		srcAccessMask = {.COLOR_ATTACHMENT_WRITE},
		dstAccessMask = {.TRANSFER_READ},
		oldLayout = .PRESENT_SRC_KHR,
		newLayout = .TRANSFER_SRC_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = swapchain_image,
		subresourceRange = range,
	}
	to_dst := vk.ImageMemoryBarrier2 {
		sType = .IMAGE_MEMORY_BARRIER_2,
		srcAccessMask = renderer.backdrop_layouts[UI_BACKDROP_SOURCE_TEXTURE_ID] == .SHADER_READ_ONLY_OPTIMAL ? vk.AccessFlags2{.SHADER_READ} : vk.AccessFlags2{},
		dstAccessMask = {.TRANSFER_WRITE},
		oldLayout = renderer.backdrop_layouts[UI_BACKDROP_SOURCE_TEXTURE_ID],
		newLayout = .TRANSFER_DST_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = source.image,
		subresourceRange = range,
	}
	barriers := [?]vk.ImageMemoryBarrier2{to_src, to_dst}
	engine.vk_cmd_pipeline_barrier2(frame.command_buffer, {.COLOR_ATTACHMENT_OUTPUT, .FRAGMENT_SHADER}, {.TRANSFER}, {}, 0, nil, 0, nil, u32(len(barriers)), raw_data(barriers[:]))
	vk_cmd_count_pipeline_barrier(ctx, u32(len(barriers)))

	src := vk.Offset3D{i32(0), i32(0), i32(0)}
	src_max := vk.Offset3D{i32(ctx.swapchain_extent.width), i32(ctx.swapchain_extent.height), i32(1)}
	dst := vk.Offset3D{i32(0), i32(0), i32(0)}
	dst_max := vk.Offset3D{i32(source.width), i32(source.height), i32(1)}
	blit := vk.ImageBlit {
		srcSubresource = {
			aspectMask = {.COLOR},
			mipLevel = 0,
			baseArrayLayer = 0,
			layerCount = 1,
		},
		srcOffsets = {src, src_max},
		dstSubresource = {
			aspectMask = {.COLOR},
			mipLevel = 0,
			baseArrayLayer = 0,
			layerCount = 1,
		},
		dstOffsets = {dst, dst_max},
	}
	vk.CmdBlitImage(frame.command_buffer, swapchain_image, .TRANSFER_SRC_OPTIMAL, source.image, .TRANSFER_DST_OPTIMAL, 1, &blit, .LINEAR)
	vk_cmd_count_transfer_copy(ctx)

	to_color := vk.ImageMemoryBarrier2 {
		sType = .IMAGE_MEMORY_BARRIER_2,
		srcAccessMask = {.TRANSFER_READ},
		dstAccessMask = {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE},
		oldLayout = .TRANSFER_SRC_OPTIMAL,
		newLayout = .COLOR_ATTACHMENT_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = swapchain_image,
		subresourceRange = range,
	}
	to_shader := vk.ImageMemoryBarrier2 {
		sType = .IMAGE_MEMORY_BARRIER_2,
		srcAccessMask = {.TRANSFER_WRITE},
		dstAccessMask = {.SHADER_READ},
		oldLayout = .TRANSFER_DST_OPTIMAL,
		newLayout = .SHADER_READ_ONLY_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = source.image,
		subresourceRange = range,
	}
	post_barriers := [?]vk.ImageMemoryBarrier2{to_color, to_shader}
	engine.vk_cmd_pipeline_barrier2(frame.command_buffer, {.TRANSFER}, {.COLOR_ATTACHMENT_OUTPUT, .FRAGMENT_SHADER}, {}, 0, nil, 0, nil, u32(len(post_barriers)), raw_data(post_barriers[:]))
	vk_cmd_count_pipeline_barrier(ctx, u32(len(post_barriers)))
	renderer.backdrop_layouts[UI_BACKDROP_SOURCE_TEXTURE_ID] = .SHADER_READ_ONLY_OPTIMAL

	frame_slot := frame.frame_index % MAX_FRAMES_IN_FLIGHT
	if !ui_renderer_run_backdrop_blur_pass(renderer, ctx, frame.command_buffer, frame_slot, UI_BACKDROP_SOURCE_TEXTURE_ID, UI_BACKDROP_HALF_TEMP_TEXTURE_ID, {1.85 / f32(source.width), 0}, 0) {
		return false
	}
	half_temp := &renderer.textures[UI_BACKDROP_HALF_TEMP_TEXTURE_ID]
	if !ui_renderer_run_backdrop_blur_pass(renderer, ctx, frame.command_buffer, frame_slot, UI_BACKDROP_HALF_TEMP_TEXTURE_ID, UI_BACKDROP_HALF_TEXTURE_ID, {0, 1.85 / f32(half_temp.height)}, UI_BACKDROP_BLUR_VERTICES_PER_PASS) {
		return false
	}
	half := &renderer.textures[UI_BACKDROP_HALF_TEXTURE_ID]
	if !ui_renderer_run_backdrop_blur_pass(renderer, ctx, frame.command_buffer, frame_slot, UI_BACKDROP_HALF_TEXTURE_ID, UI_BACKDROP_QUARTER_TEMP_TEXTURE_ID, {2.15 / f32(half.width), 0}, UI_BACKDROP_BLUR_VERTICES_PER_PASS * 2) {
		return false
	}
	quarter_temp := &renderer.textures[UI_BACKDROP_QUARTER_TEMP_TEXTURE_ID]
	if !ui_renderer_run_backdrop_blur_pass(renderer, ctx, frame.command_buffer, frame_slot, UI_BACKDROP_QUARTER_TEMP_TEXTURE_ID, UI_BACKDROP_QUARTER_TEXTURE_ID, {0, 2.15 / f32(quarter_temp.height)}, UI_BACKDROP_BLUR_VERTICES_PER_PASS * 3) {
		return false
	}
	quarter := &renderer.textures[UI_BACKDROP_QUARTER_TEXTURE_ID]
	if !ui_renderer_run_backdrop_blur_pass(renderer, ctx, frame.command_buffer, frame_slot, UI_BACKDROP_QUARTER_TEXTURE_ID, UI_BACKDROP_EIGHTH_TEMP_TEXTURE_ID, {2.45 / f32(quarter.width), 0}, UI_BACKDROP_BLUR_VERTICES_PER_PASS * 4) {
		return false
	}
	eighth_temp := &renderer.textures[UI_BACKDROP_EIGHTH_TEMP_TEXTURE_ID]
	if !ui_renderer_run_backdrop_blur_pass(renderer, ctx, frame.command_buffer, frame_slot, UI_BACKDROP_EIGHTH_TEMP_TEXTURE_ID, UI_BACKDROP_EIGHTH_TEXTURE_ID, {0, 2.45 / f32(eighth_temp.height)}, UI_BACKDROP_BLUR_VERTICES_PER_PASS * 5) {
		return false
	}
	if !ui_renderer_update_glass_descriptor(renderer, ctx) {
		return false
	}
	return true
}

ui_renderer_run_backdrop_blur_pass :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context, cmd: vk.CommandBuffer, frame_slot: u32, source_index, dest_index: int, texel_step: uifw.Vec2, vertex_offset: u32) -> bool {
	source := &renderer.textures[source_index]
	dest := &renderer.textures[dest_index]
	if !source.ready || !dest.ready || dest.view == vk.ImageView(0) {
		return false
	}

	range := vk.ImageSubresourceRange {
		aspectMask = {.COLOR},
		baseMipLevel = 0,
		levelCount = 1,
		baseArrayLayer = 0,
		layerCount = 1,
	}
	to_color := vk.ImageMemoryBarrier2 {
		sType = .IMAGE_MEMORY_BARRIER_2,
		srcAccessMask = renderer.backdrop_layouts[dest_index] == .SHADER_READ_ONLY_OPTIMAL ? vk.AccessFlags2{.SHADER_READ} : vk.AccessFlags2{},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
		oldLayout = renderer.backdrop_layouts[dest_index],
		newLayout = .COLOR_ATTACHMENT_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = dest.image,
		subresourceRange = range,
	}
	engine.vk_cmd_pipeline_barrier2(cmd, {.FRAGMENT_SHADER, .TOP_OF_PIPE}, {.COLOR_ATTACHMENT_OUTPUT}, {}, 0, nil, 0, nil, 1, &to_color)
	vk_cmd_count_pipeline_barrier(ctx)
	renderer.backdrop_layouts[dest_index] = .COLOR_ATTACHMENT_OPTIMAL

	clear := vk.ClearValue{color = {float32 = {0, 0, 0, 0}}}
	engine.vk_cmd_begin_rendering(ctx, cmd, dest.view, {dest.width, dest.height}, .COLOR_ATTACHMENT_OPTIMAL, .CLEAR, .STORE, clear)
	vk_cmd_count_backdrop_blur_pass(ctx)

	viewport := vk.Viewport{x = 0, y = 0, width = f32(dest.width), height = f32(dest.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = {dest.width, dest.height}}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)

	if !ui_renderer_write_blur_quad(renderer, frame_slot, vertex_offset, texel_step) {
		engine.vk_cmd_end_rendering(cmd)
		return false
	}
	buffer := renderer.backdrop_vertex_buffers[min(frame_slot, u32(MAX_FRAMES_IN_FLIGHT - 1))].handle
	offset := vk.DeviceSize(size_of(Ui_Vertex) * int(vertex_offset))
	vk.CmdBindVertexBuffers(cmd, 0, 1, &buffer, &offset)
	vk.CmdBindPipeline(cmd, .GRAPHICS, renderer.backdrop_blur_pipeline.pipeline)
	vk_cmd_count_pipeline_bind(ctx)
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, renderer.backdrop_blur_pipeline.layout, 0, 1, &source.descriptor_set, 0, nil)
	vk_cmd_count_descriptor_bind(ctx)
	vk.CmdDraw(cmd, 6, 1, 0, 0)
	vk_cmd_count_draw(ctx)
	engine.vk_cmd_end_rendering(cmd)

	to_shader := vk.ImageMemoryBarrier2 {
		sType = .IMAGE_MEMORY_BARRIER_2,
		srcAccessMask = {.COLOR_ATTACHMENT_WRITE},
		dstAccessMask = {.SHADER_READ},
		oldLayout = .COLOR_ATTACHMENT_OPTIMAL,
		newLayout = .SHADER_READ_ONLY_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = dest.image,
		subresourceRange = range,
	}
	engine.vk_cmd_pipeline_barrier2(cmd, {.COLOR_ATTACHMENT_OUTPUT}, {.FRAGMENT_SHADER}, {}, 0, nil, 0, nil, 1, &to_shader)
	vk_cmd_count_pipeline_barrier(ctx)
	renderer.backdrop_layouts[dest_index] = .SHADER_READ_ONLY_OPTIMAL
	return true
}

ui_renderer_write_blur_quad :: proc(renderer: ^Ui_Renderer, frame_slot, vertex_offset: u32, texel_step: uifw.Vec2) -> bool {
	slot := min(frame_slot, u32(MAX_FRAMES_IN_FLIGHT - 1))
	buffer := &renderer.backdrop_vertex_buffers[slot]
	if buffer.mapped == nil || buffer.handle == vk.Buffer(0) {
		return false
	}
	if vertex_offset + UI_BACKDROP_BLUR_VERTICES_PER_PASS > UI_BACKDROP_BLUR_VERTICES_PER_PASS * UI_BACKDROP_BLUR_PASS_COUNT {
		return false
	}
	out := cast([^]Ui_Vertex)buffer.mapped
	effect := uifw.Color{texel_step.x, texel_step.y, 0, 0}
	verts := [?]Ui_Vertex {
		{{-1, -1}, {1, 1, 1, 1}, {0, 1}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{ 1, -1}, {1, 1, 1, 1}, {1, 1}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{ 1,  1}, {1, 1, 1, 1}, {1, 0}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{-1, -1}, {1, 1, 1, 1}, {0, 1}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{ 1,  1}, {1, 1, 1, 1}, {1, 0}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{-1,  1}, {1, 1, 1, 1}, {0, 0}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
	}
	for vertex, i in verts {
		out[int(vertex_offset) + i] = vertex
	}
	return true
}

ui_renderer_draw_clear_fallback :: proc(renderer: ^Ui_Renderer, cmd: vk.CommandBuffer) {
	for i: u32 = 0; i < renderer.clear_rect_count; i += 1 {
		item := renderer.clear_rects[i]
		if item.rect.w <= 0 || item.rect.h <= 0 {
			continue
		}
		clear := vk.ClearAttachment {
			aspectMask = {.COLOR},
			colorAttachment = 0,
			clearValue = {color = {float32 = {item.color.r, item.color.g, item.color.b, item.color.a}}},
		}
		clear_rect := vk.ClearRect {
			rect = {
				offset = {i32(item.rect.x), i32(item.rect.y)},
				extent = {u32(item.rect.w), u32(item.rect.h)},
			},
			baseArrayLayer = 0,
			layerCount = 1,
		}
		vk.CmdClearAttachments(cmd, 1, &clear, 1, &clear_rect)
	}
}

ui_renderer_create_pipeline :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context, blend_mode: uifw.Gui_Blend_Mode, pipeline: ^Vk_Graphics_Pipeline) -> bool {
	vert: Vk_Shader_Module
	frag: Vk_Shader_Module
	if !vk_load_shader_module_with_fallback(ctx, UI_VERTEX_SHADER_SOURCE, UI_VERTEX_SHADER_FALLBACK_SPV, .Vertex, UI_VERTEX_ENTRY_POINT, &vert) {
		return false
	}
	defer vk_destroy_shader_module(ctx, &vert)
	if !vk_load_shader_module_with_fallback(ctx, UI_FRAGMENT_SHADER_SOURCE, UI_FRAGMENT_SHADER_FALLBACK_SPV, .Fragment, UI_FRAGMENT_ENTRY_POINT, &frag) {
		return false
	}
	defer vk_destroy_shader_module(ctx, &frag)

	set_layouts := [?]vk.DescriptorSetLayout{renderer.descriptor_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = u32(len(set_layouts)),
		pSetLayouts = raw_data(set_layouts[:]),
	}
	if vk.CreatePipelineLayout(ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}

	stages := [?]vk.PipelineShaderStageCreateInfo {
		{
			sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = {.VERTEX},
			module = vert.handle,
			pName = UI_VERTEX_SPIRV_ENTRY_POINT,
		},
		{
			sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = {.FRAGMENT},
			module = frag.handle,
			pName = UI_FRAGMENT_SPIRV_ENTRY_POINT,
		},
	}

	binding := vk.VertexInputBindingDescription {
		binding = 0,
		stride = u32(size_of(Ui_Vertex)),
		inputRate = .VERTEX,
	}
	attributes := [?]vk.VertexInputAttributeDescription {
		{
			location = 0,
			binding = 0,
			format = .R32G32_SFLOAT,
			offset = u32(offset_of(Ui_Vertex, pos)),
		},
		{
			location = 1,
			binding = 0,
			format = .R32G32B32A32_SFLOAT,
			offset = u32(offset_of(Ui_Vertex, color)),
		},
		{
			location = 2,
			binding = 0,
			format = .R32G32_SFLOAT,
			offset = u32(offset_of(Ui_Vertex, uv)),
		},
		{
			location = 3,
			binding = 0,
			format = .R32_SFLOAT,
			offset = u32(offset_of(Ui_Vertex, glyph)),
		},
		{
			location = 4,
			binding = 0,
			format = .R32G32B32A32_SFLOAT,
			offset = u32(offset_of(Ui_Vertex, effect)),
		},
		{
			location = 5,
			binding = 0,
			format = .R32G32B32A32_SFLOAT,
			offset = u32(offset_of(Ui_Vertex, material)),
		},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo {
		sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount = 1,
		pVertexBindingDescriptions = &binding,
		vertexAttributeDescriptionCount = u32(len(attributes)),
		pVertexAttributeDescriptions = raw_data(attributes[:]),
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
	blend_attachment := ui_blend_attachment(blend_mode)
	blend := vk.PipelineColorBlendStateCreateInfo {
		sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		attachmentCount = 1,
		pAttachments = &blend_attachment,
	}
	dynamic_states := [?]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state_info := vk.PipelineDynamicStateCreateInfo {
		sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = u32(len(dynamic_states)),
		pDynamicStates = raw_data(dynamic_states[:]),
	}
	rendering := engine.vk_pipeline_rendering_info(&ctx.swapchain_format)
	info := vk.GraphicsPipelineCreateInfo {
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
		layout = pipeline.layout,
	}
	if vk.CreateGraphicsPipelines(ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline) != .SUCCESS {
		return false
	}
	return true
}

ui_renderer_create_blur_pipeline :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context, pipeline: ^Vk_Graphics_Pipeline) -> bool {
	vert: Vk_Shader_Module
	frag: Vk_Shader_Module
	if !vk_load_shader_module_with_fallback(ctx, UI_VERTEX_SHADER_SOURCE, UI_VERTEX_SHADER_FALLBACK_SPV, .Vertex, UI_VERTEX_ENTRY_POINT, &vert) {
		return false
	}
	defer vk_destroy_shader_module(ctx, &vert)
	if !vk_load_shader_module_with_fallback(ctx, UI_BLUR_FRAGMENT_SHADER_SOURCE, UI_BLUR_FRAGMENT_SHADER_FALLBACK_SPV, .Fragment, UI_FRAGMENT_ENTRY_POINT, &frag) {
		return false
	}
	defer vk_destroy_shader_module(ctx, &frag)

	set_layouts := [?]vk.DescriptorSetLayout{renderer.descriptor_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = u32(len(set_layouts)),
		pSetLayouts = raw_data(set_layouts[:]),
	}
	if vk.CreatePipelineLayout(ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}

	stages := [?]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = vert.handle, pName = UI_VERTEX_SPIRV_ENTRY_POINT},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = frag.handle, pName = UI_FRAGMENT_SPIRV_ENTRY_POINT},
	}
	binding := vk.VertexInputBindingDescription{binding = 0, stride = u32(size_of(Ui_Vertex)), inputRate = .VERTEX}
	attributes := [?]vk.VertexInputAttributeDescription {
		{location = 0, binding = 0, format = .R32G32_SFLOAT, offset = u32(offset_of(Ui_Vertex, pos))},
		{location = 1, binding = 0, format = .R32G32B32A32_SFLOAT, offset = u32(offset_of(Ui_Vertex, color))},
		{location = 2, binding = 0, format = .R32G32_SFLOAT, offset = u32(offset_of(Ui_Vertex, uv))},
		{location = 3, binding = 0, format = .R32_SFLOAT, offset = u32(offset_of(Ui_Vertex, glyph))},
		{location = 4, binding = 0, format = .R32G32B32A32_SFLOAT, offset = u32(offset_of(Ui_Vertex, effect))},
		{location = 5, binding = 0, format = .R32G32B32A32_SFLOAT, offset = u32(offset_of(Ui_Vertex, material))},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo {
		sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount = 1,
		pVertexBindingDescriptions = &binding,
		vertexAttributeDescriptionCount = u32(len(attributes)),
		pVertexAttributeDescriptions = raw_data(attributes[:]),
	}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := vk.PipelineColorBlendAttachmentState{blendEnable = false, colorWriteMask = {.R, .G, .B, .A}}
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [?]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state_info := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = u32(len(dynamic_states)), pDynamicStates = raw_data(dynamic_states[:])}
	rendering := engine.vk_pipeline_rendering_info(&ctx.swapchain_format)
	info := vk.GraphicsPipelineCreateInfo {
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
		layout = pipeline.layout,
	}
	return vk.CreateGraphicsPipelines(ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline) == .SUCCESS
}

ui_renderer_create_glass_pipeline :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context, pipeline: ^Vk_Graphics_Pipeline) -> bool {
	vert: Vk_Shader_Module
	frag: Vk_Shader_Module
	if !vk_load_shader_module_with_fallback(ctx, UI_VERTEX_SHADER_SOURCE, UI_VERTEX_SHADER_FALLBACK_SPV, .Vertex, UI_VERTEX_ENTRY_POINT, &vert) {
		return false
	}
	defer vk_destroy_shader_module(ctx, &vert)
	if !vk_load_shader_module_with_fallback(ctx, UI_GLASS_FRAGMENT_SHADER_SOURCE, UI_GLASS_FRAGMENT_SHADER_FALLBACK_SPV, .Fragment, UI_FRAGMENT_ENTRY_POINT, &frag) {
		return false
	}
	defer vk_destroy_shader_module(ctx, &frag)

	set_layouts := [?]vk.DescriptorSetLayout{renderer.glass_descriptor_set_layout}
	layout_info := vk.PipelineLayoutCreateInfo{
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = u32(len(set_layouts)),
		pSetLayouts = raw_data(set_layouts[:]),
	}
	if vk.CreatePipelineLayout(ctx.device, &layout_info, nil, &pipeline.layout) != .SUCCESS {
		return false
	}

	stages := [?]vk.PipelineShaderStageCreateInfo {
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.VERTEX}, module = vert.handle, pName = UI_VERTEX_SPIRV_ENTRY_POINT},
		{sType = .PIPELINE_SHADER_STAGE_CREATE_INFO, stage = {.FRAGMENT}, module = frag.handle, pName = UI_FRAGMENT_SPIRV_ENTRY_POINT},
	}
	binding := vk.VertexInputBindingDescription{binding = 0, stride = u32(size_of(Ui_Vertex)), inputRate = .VERTEX}
	attributes := [?]vk.VertexInputAttributeDescription {
		{location = 0, binding = 0, format = .R32G32_SFLOAT, offset = u32(offset_of(Ui_Vertex, pos))},
		{location = 1, binding = 0, format = .R32G32B32A32_SFLOAT, offset = u32(offset_of(Ui_Vertex, color))},
		{location = 2, binding = 0, format = .R32G32_SFLOAT, offset = u32(offset_of(Ui_Vertex, uv))},
		{location = 3, binding = 0, format = .R32_SFLOAT, offset = u32(offset_of(Ui_Vertex, glyph))},
		{location = 4, binding = 0, format = .R32G32B32A32_SFLOAT, offset = u32(offset_of(Ui_Vertex, effect))},
		{location = 5, binding = 0, format = .R32G32B32A32_SFLOAT, offset = u32(offset_of(Ui_Vertex, material))},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo {
		sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount = 1,
		pVertexBindingDescriptions = &binding,
		vertexAttributeDescriptionCount = u32(len(attributes)),
		pVertexAttributeDescriptions = raw_data(attributes[:]),
	}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, topology = .TRIANGLE_LIST}
	viewport_state := vk.PipelineViewportStateCreateInfo{sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO, viewportCount = 1, scissorCount = 1}
	raster := vk.PipelineRasterizationStateCreateInfo{sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO, polygonMode = .FILL, cullMode = {}, frontFace = .COUNTER_CLOCKWISE, lineWidth = 1}
	multisample := vk.PipelineMultisampleStateCreateInfo{sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, rasterizationSamples = {._1}}
	blend_attachment := ui_blend_attachment(.Alpha)
	blend := vk.PipelineColorBlendStateCreateInfo{sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, attachmentCount = 1, pAttachments = &blend_attachment}
	dynamic_states := [?]vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_state_info := vk.PipelineDynamicStateCreateInfo{sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO, dynamicStateCount = u32(len(dynamic_states)), pDynamicStates = raw_data(dynamic_states[:])}
	rendering := engine.vk_pipeline_rendering_info(&ctx.swapchain_format)
	info := vk.GraphicsPipelineCreateInfo {
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
		layout = pipeline.layout,
	}
	return vk.CreateGraphicsPipelines(ctx.device, vk.PipelineCache(0), 1, &info, nil, &pipeline.pipeline) == .SUCCESS
}

ui_blend_attachment :: proc(mode: uifw.Gui_Blend_Mode) -> vk.PipelineColorBlendAttachmentState {
	state := vk.PipelineColorBlendAttachmentState {
		blendEnable = true,
		srcColorBlendFactor = .SRC_ALPHA,
		dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
		colorBlendOp = .ADD,
		srcAlphaBlendFactor = .ONE,
		dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA,
		alphaBlendOp = .ADD,
		colorWriteMask = {.R, .G, .B, .A},
	}
	switch mode {
	case .Alpha:
	case .Add:
		state.srcColorBlendFactor = .SRC_ALPHA
		state.dstColorBlendFactor = .ONE
	case .Multiply:
		state.srcColorBlendFactor = .DST_COLOR
		state.dstColorBlendFactor = .ZERO
		state.srcAlphaBlendFactor = .ONE
		state.dstAlphaBlendFactor = .ZERO
	case .Screen:
		state.srcColorBlendFactor = .ONE
		state.dstColorBlendFactor = .ONE_MINUS_SRC_COLOR
		state.srcAlphaBlendFactor = .ONE
		state.dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA
	}
	return state
}
