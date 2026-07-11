package render_vk

import uifw "../ui"
import engine "../engine"

import vk "vendor:vulkan"
import "core:bytes"
import "core:fmt"
import "core:math"
import png "core:image/png"

ui_renderer_register_texture :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context, id: uifw.Gui_Image_Id, view: vk.ImageView, sampler: vk.Sampler) -> bool {
	index := int(id)
	if index <= 0 || index >= UI_MAX_TEXTURES || view == vk.ImageView(0) || sampler == vk.Sampler(0) {
		return false
	}
	texture := &renderer.textures[index]
	ui_renderer_destroy_texture(ctx, texture)
	texture.view = view
	texture.sampler = sampler
	texture.owned = false
	return ui_renderer_allocate_texture_descriptor(renderer, ctx, index, view, sampler)
}

ui_renderer_ensure_backdrop_texture :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context) -> bool {
	source_w := max(ctx.swapchain_extent.width, u32(1))
	source_h := max(ctx.swapchain_extent.height, u32(1))
	half_w := max((source_w + 1) / 2, u32(1))
	half_h := max((source_h + 1) / 2, u32(1))
	quarter_w := max((half_w + 1) / 2, u32(1))
	quarter_h := max((half_h + 1) / 2, u32(1))
	eighth_w := max((quarter_w + 1) / 2, u32(1))
	eighth_h := max((quarter_h + 1) / 2, u32(1))
	if renderer.textures[UI_BACKDROP_SOURCE_TEXTURE_ID].ready &&
	   renderer.textures[UI_BACKDROP_HALF_TEMP_TEXTURE_ID].ready &&
	   renderer.textures[UI_BACKDROP_HALF_TEXTURE_ID].ready &&
	   renderer.textures[UI_BACKDROP_QUARTER_TEMP_TEXTURE_ID].ready &&
	   renderer.textures[UI_BACKDROP_QUARTER_TEXTURE_ID].ready &&
	   renderer.textures[UI_BACKDROP_EIGHTH_TEMP_TEXTURE_ID].ready &&
	   renderer.textures[UI_BACKDROP_EIGHTH_TEXTURE_ID].ready &&
	   renderer.backdrop_width == source_w && renderer.backdrop_height == source_h {
		return true
	}

	ui_renderer_destroy_texture(ctx, &renderer.textures[UI_BACKDROP_SOURCE_TEXTURE_ID])
	ui_renderer_destroy_texture(ctx, &renderer.textures[UI_BACKDROP_HALF_TEMP_TEXTURE_ID])
	ui_renderer_destroy_texture(ctx, &renderer.textures[UI_BACKDROP_HALF_TEXTURE_ID])
	ui_renderer_destroy_texture(ctx, &renderer.textures[UI_BACKDROP_QUARTER_TEMP_TEXTURE_ID])
	ui_renderer_destroy_texture(ctx, &renderer.textures[UI_BACKDROP_QUARTER_TEXTURE_ID])
	ui_renderer_destroy_texture(ctx, &renderer.textures[UI_BACKDROP_EIGHTH_TEMP_TEXTURE_ID])
	ui_renderer_destroy_texture(ctx, &renderer.textures[UI_BACKDROP_EIGHTH_TEXTURE_ID])
	renderer.backdrop_width = 0
	renderer.backdrop_height = 0
	renderer.backdrop_layouts[UI_BACKDROP_SOURCE_TEXTURE_ID] = .UNDEFINED
	renderer.backdrop_layouts[UI_BACKDROP_HALF_TEMP_TEXTURE_ID] = .UNDEFINED
	renderer.backdrop_layouts[UI_BACKDROP_HALF_TEXTURE_ID] = .UNDEFINED
	renderer.backdrop_layouts[UI_BACKDROP_QUARTER_TEMP_TEXTURE_ID] = .UNDEFINED
	renderer.backdrop_layouts[UI_BACKDROP_QUARTER_TEXTURE_ID] = .UNDEFINED
	renderer.backdrop_layouts[UI_BACKDROP_EIGHTH_TEMP_TEXTURE_ID] = .UNDEFINED
	renderer.backdrop_layouts[UI_BACKDROP_EIGHTH_TEXTURE_ID] = .UNDEFINED

	if !ui_renderer_create_backdrop_texture(renderer, ctx, UI_BACKDROP_SOURCE_TEXTURE_ID, source_w, source_h, false) {
		return false
	}
	if !ui_renderer_create_backdrop_texture(renderer, ctx, UI_BACKDROP_HALF_TEMP_TEXTURE_ID, half_w, half_h, true) {
		return false
	}
	if !ui_renderer_create_backdrop_texture(renderer, ctx, UI_BACKDROP_HALF_TEXTURE_ID, half_w, half_h, true) {
		return false
	}
	if !ui_renderer_create_backdrop_texture(renderer, ctx, UI_BACKDROP_QUARTER_TEMP_TEXTURE_ID, quarter_w, quarter_h, true) {
		return false
	}
	if !ui_renderer_create_backdrop_texture(renderer, ctx, UI_BACKDROP_QUARTER_TEXTURE_ID, quarter_w, quarter_h, true) {
		return false
	}
	if !ui_renderer_create_backdrop_texture(renderer, ctx, UI_BACKDROP_EIGHTH_TEMP_TEXTURE_ID, eighth_w, eighth_h, true) {
		return false
	}
	if !ui_renderer_create_backdrop_texture(renderer, ctx, UI_BACKDROP_EIGHTH_TEXTURE_ID, eighth_w, eighth_h, true) {
		return false
	}
	renderer.backdrop_width = source_w
	renderer.backdrop_height = source_h
	return true
}

ui_renderer_create_backdrop_texture :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context, index: int, width, height: u32, framebuffer: bool) -> bool {
	texture := &renderer.textures[index]
	image_info := vk.ImageCreateInfo {
		sType = .IMAGE_CREATE_INFO,
		imageType = .D2,
		format = ctx.swapchain_format,
		extent = {width, height, 1},
		mipLevels = 1,
		arrayLayers = 1,
		samples = {._1},
		tiling = .OPTIMAL,
		usage = framebuffer ? vk.ImageUsageFlags{.COLOR_ATTACHMENT, .SAMPLED} : vk.ImageUsageFlags{.TRANSFER_DST, .SAMPLED},
		sharingMode = .EXCLUSIVE,
		initialLayout = .UNDEFINED,
	}
	if vk.CreateImage(ctx.device, &image_info, nil, &texture.image) != .SUCCESS {
		log_error("ui_renderer_create_backdrop_texture: image creation failed index=", index)
		return false
	}

	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(ctx.device, texture.image, &req)
	memory_type, ok := vk_find_memory_type(ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {
		log_error("ui_renderer_create_backdrop_texture: device local memory type not found index=", index)
		ui_renderer_destroy_texture(ctx, texture)
		return false
	}
	alloc := vk.MemoryAllocateInfo {
		sType = .MEMORY_ALLOCATE_INFO,
		allocationSize = req.size,
		memoryTypeIndex = memory_type,
	}
	if vk.AllocateMemory(ctx.device, &alloc, nil, &texture.memory) != .SUCCESS {
		log_error("ui_renderer_create_backdrop_texture: image memory allocation failed index=", index)
		ui_renderer_destroy_texture(ctx, texture)
		return false
	}
	if vk.BindImageMemory(ctx.device, texture.image, texture.memory, 0) != .SUCCESS {
		log_error("ui_renderer_create_backdrop_texture: bind image memory failed index=", index)
		ui_renderer_destroy_texture(ctx, texture)
		return false
	}

	view_info := vk.ImageViewCreateInfo {
		sType = .IMAGE_VIEW_CREATE_INFO,
		image = texture.image,
		viewType = .D2,
		format = ctx.swapchain_format,
		subresourceRange = {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
		},
	}
	if vk.CreateImageView(ctx.device, &view_info, nil, &texture.view) != .SUCCESS {
		log_error("ui_renderer_create_backdrop_texture: image view creation failed index=", index)
		ui_renderer_destroy_texture(ctx, texture)
		return false
	}

	if framebuffer {
		fb_info := vk.FramebufferCreateInfo {
			sType = .FRAMEBUFFER_CREATE_INFO,
			renderPass = renderer.backdrop_render_pass,
			attachmentCount = 1,
			pAttachments = &texture.view,
			width = width,
			height = height,
			layers = 1,
		}
		if vk.CreateFramebuffer(ctx.device, &fb_info, nil, &texture.framebuffer) != .SUCCESS {
			log_error("ui_renderer_create_backdrop_texture: framebuffer creation failed index=", index)
			ui_renderer_destroy_texture(ctx, texture)
			return false
		}
	}

	sampler_info := vk.SamplerCreateInfo {sType = .SAMPLER_CREATE_INFO}
	sampler_info.magFilter = .LINEAR
	sampler_info.minFilter = .LINEAR
	sampler_info.mipmapMode = .LINEAR
	sampler_info.addressModeU = .CLAMP_TO_EDGE
	sampler_info.addressModeV = .CLAMP_TO_EDGE
	sampler_info.addressModeW = .CLAMP_TO_EDGE
	sampler_info.minLod = 0
	sampler_info.maxLod = 1
	if vk.CreateSampler(ctx.device, &sampler_info, nil, &texture.sampler) != .SUCCESS {
		log_error("ui_renderer_create_backdrop_texture: sampler creation failed index=", index)
		ui_renderer_destroy_texture(ctx, texture)
		return false
	}

	texture.owned = true
	texture.width = width
	texture.height = height
	if !ui_renderer_allocate_texture_descriptor(renderer, ctx, index, texture.view, texture.sampler) {
		ui_renderer_destroy_texture(ctx, texture)
		return false
	}
	renderer.backdrop_layouts[index] = .UNDEFINED
	return true
}

ui_renderer_allocate_texture_descriptor :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context, index: int, view: vk.ImageView, sampler: vk.Sampler) -> bool {
	layout := renderer.descriptor_set_layout
	alloc := vk.DescriptorSetAllocateInfo {
		sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool = renderer.descriptor_pool,
		descriptorSetCount = 1,
		pSetLayouts = &layout,
	}
	if vk.AllocateDescriptorSets(ctx.device, &alloc, &renderer.textures[index].descriptor_set) != .SUCCESS {
		log_error("ui_renderer_allocate_texture_descriptor: descriptor allocation failed index=", index)
		return false
	}
	image_info := vk.DescriptorImageInfo {
		imageLayout = .SHADER_READ_ONLY_OPTIMAL,
		imageView = view,
	}
	sampler_info := vk.DescriptorImageInfo {
		sampler = sampler,
	}
	writes := [?]vk.WriteDescriptorSet {
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = renderer.textures[index].descriptor_set,
			dstBinding = 0,
			descriptorType = .SAMPLED_IMAGE,
			descriptorCount = 1,
			pImageInfo = &image_info,
		},
		{
			sType = .WRITE_DESCRIPTOR_SET,
			dstSet = renderer.textures[index].descriptor_set,
			dstBinding = 1,
			descriptorType = .SAMPLER,
			descriptorCount = 1,
			pImageInfo = &sampler_info,
		},
	}
	vk.UpdateDescriptorSets(ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
	renderer.textures[index].ready = true
	return true
}

ui_renderer_update_glass_descriptor :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context) -> bool {
	if renderer.glass_descriptor_set_layout == vk.DescriptorSetLayout(0) {
		return false
	}
	if renderer.glass_descriptor_set == vk.DescriptorSet(0) {
		layout := renderer.glass_descriptor_set_layout
		alloc := vk.DescriptorSetAllocateInfo {
			sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
			descriptorPool = renderer.descriptor_pool,
			descriptorSetCount = 1,
			pSetLayouts = &layout,
		}
		if vk.AllocateDescriptorSets(ctx.device, &alloc, &renderer.glass_descriptor_set) != .SUCCESS {
			log_error("ui_renderer_update_glass_descriptor: descriptor allocation failed")
			return false
		}
	}

	fallback := &renderer.textures[0]
	source := ui_renderer_descriptor_texture(renderer, UI_BACKDROP_SOURCE_TEXTURE_ID)
	half := ui_renderer_descriptor_texture(renderer, UI_BACKDROP_HALF_TEXTURE_ID)
	quarter := ui_renderer_descriptor_texture(renderer, UI_BACKDROP_QUARTER_TEXTURE_ID)
	eighth := ui_renderer_descriptor_texture(renderer, UI_BACKDROP_EIGHTH_TEXTURE_ID)
	if source == nil {source = fallback}
	if half == nil {half = source}
	if quarter == nil {quarter = half}
	if eighth == nil {eighth = quarter}
	if source == nil || source.view == vk.ImageView(0) || source.sampler == vk.Sampler(0) {
		return false
	}

	source_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = source.view}
	half_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = half.view}
	quarter_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = quarter.view}
	eighth_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = eighth.view}
	sampler_info := vk.DescriptorImageInfo{sampler = source.sampler}
	writes := [?]vk.WriteDescriptorSet {
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = renderer.glass_descriptor_set, dstBinding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &source_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = renderer.glass_descriptor_set, dstBinding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &half_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = renderer.glass_descriptor_set, dstBinding = 2, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &quarter_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = renderer.glass_descriptor_set, dstBinding = 3, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &eighth_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = renderer.glass_descriptor_set, dstBinding = 4, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
	}
	vk.UpdateDescriptorSets(ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
	return true
}

ui_renderer_descriptor_texture :: proc(renderer: ^Ui_Renderer, index: int) -> ^Ui_Texture {
	if index < 0 || index >= UI_MAX_TEXTURES {
		return nil
	}
	texture := &renderer.textures[index]
	if !texture.ready || texture.view == vk.ImageView(0) || texture.sampler == vk.Sampler(0) {
		return nil
	}
	return texture
}

ui_renderer_destroy_texture :: proc(ctx: ^Vk_Context, texture: ^Ui_Texture) {
	if texture.owned {
		if texture.framebuffer != vk.Framebuffer(0) {
			vk.DestroyFramebuffer(ctx.device, texture.framebuffer, nil)
		}
		if texture.sampler != vk.Sampler(0) {
			vk.DestroySampler(ctx.device, texture.sampler, nil)
		}
		if texture.view != vk.ImageView(0) {
			vk.DestroyImageView(ctx.device, texture.view, nil)
		}
		if texture.image != vk.Image(0) {
			vk.DestroyImage(ctx.device, texture.image, nil)
		}
		if texture.memory != vk.DeviceMemory(0) {
			vk.FreeMemory(ctx.device, texture.memory, nil)
		}
	}
	texture^ = {}
}

ui_renderer_upload_texture :: proc(ctx: ^Vk_Context, image: vk.Image, width, height: u32, staging: vk.Buffer) -> bool {
	if !ctx.frame_resources_ready {
		return false
	}
	command_buffer, begin_ok := vk_begin_upload_commands(ctx)
	if !begin_ok {
		return false
	}

	range := vk.ImageSubresourceRange {
		aspectMask = {.COLOR},
		baseMipLevel = 0,
		levelCount = 1,
		baseArrayLayer = 0,
		layerCount = 1,
	}
	to_transfer := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = {},
		dstAccessMask = {.TRANSFER_WRITE},
		oldLayout = .UNDEFINED,
		newLayout = .TRANSFER_DST_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = image,
		subresourceRange = range,
	}
	vk.CmdPipelineBarrier(command_buffer, {.TOP_OF_PIPE}, {.TRANSFER}, {}, 0, nil, 0, nil, 1, &to_transfer)

	region := vk.BufferImageCopy {
		bufferOffset = 0,
		bufferRowLength = 0,
		bufferImageHeight = 0,
		imageSubresource = {
			aspectMask = {.COLOR},
			mipLevel = 0,
			baseArrayLayer = 0,
			layerCount = 1,
		},
		imageOffset = {0, 0, 0},
		imageExtent = {width, height, 1},
	}
	vk.CmdCopyBufferToImage(command_buffer, staging, image, .TRANSFER_DST_OPTIMAL, 1, &region)

	to_shader := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = {.TRANSFER_WRITE},
		dstAccessMask = {.SHADER_READ},
		oldLayout = .TRANSFER_DST_OPTIMAL,
		newLayout = .SHADER_READ_ONLY_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = image,
		subresourceRange = range,
	}
	vk.CmdPipelineBarrier(command_buffer, {.TRANSFER}, {.FRAGMENT_SHADER}, {}, 0, nil, 0, nil, 1, &to_shader)

	return vk_submit_upload_commands(ctx)
}

ui_renderer_build :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context, commands: []uifw.Draw_Command) -> bool {
	if !renderer.ready {
		return false
	}
	frame_slot := ui_renderer_active_frame_slot(ctx)
	vertex_buffer := &renderer.vertex_buffers[frame_slot]
	if vertex_buffer.mapped == nil {
		return false
	}
	renderer.active_frame_slot = frame_slot
	out := cast([^]Ui_Vertex)vertex_buffer.mapped
	count: int
	renderer.batch_count = 0
	renderer.clear_rect_count = 0
	renderer.needs_backdrop_capture = false
	scissor_stack: [16]uifw.Rect
	scissor_depth := 0
	active_scissor := uifw.Rect{0, 0, f32(ctx.swapchain_extent.width), f32(ctx.swapchain_extent.height)}

	for command in commands {
		first := count
		texture_index := u32(0)
		blend_mode := ui_renderer_blend_index(command.blend)
		glass_batch := false
		#partial switch command.kind {
		case .Filled_Rect:
			ui_push_rect(out, &count, command.rect, command.color, active_scissor, ctx.swapchain_extent)
		case .Stroked_Rect:
			ui_push_stroke(out, &count, command.rect, command.color, max(command.stroke_width, UI_STROKE_WIDTH), active_scissor, ctx.swapchain_extent)
		case .Filled_Rounded_Rect:
			ui_push_rounded_rect(out, &count, command.rect, command.radius, command.color, active_scissor, ctx.swapchain_extent)
		case .Stroked_Rounded_Rect:
			ui_push_rounded_stroke(out, &count, command.rect, command.radius, max(command.stroke_width, UI_STROKE_WIDTH), command.color, active_scissor, ctx.swapchain_extent)
		case .Gradient_Rect:
			ui_push_gradient_rect(out, &count, command.rect, command.radius, command.color, command.color_2, active_scissor, ctx.swapchain_extent)
		case .Horizontal_Gradient_Rect:
			ui_push_horizontal_gradient_rect(out, &count, command.rect, command.color, command.color_2, active_scissor, ctx.swapchain_extent)
		case .Shader_Rect:
			ui_push_shader_rect(out, &count, command.rect, command.color, command.shader_kind, command.shader_params, active_scissor, ctx.swapchain_extent)
		case .Filled_Quad:
			ui_push_quad(out, &count, command.p0, command.p1, command.p2, command.p3, command.color, active_scissor, ctx.swapchain_extent)
		case .Line:
			ui_push_line(out, &count, command.p0, command.p1, command.color, max(command.stroke_width, UI_STROKE_WIDTH), active_scissor, ctx.swapchain_extent)
		case .Filled_Ellipse:
			ui_push_ellipse(out, &count, command.rect, command.color, active_scissor, ctx.swapchain_extent)
		case .Stroked_Ellipse:
			ui_push_ellipse_stroke(out, &count, command.rect, command.color, max(command.stroke_width, UI_STROKE_WIDTH), active_scissor, ctx.swapchain_extent)
		case .Image:
			texture_index = ui_renderer_texture_index(renderer, command.image_id)
			ui_push_image_textured(out, &count, command.rect, command.rect_2, command.color, command.image_filter, active_scissor, ctx.swapchain_extent)
		case .Backdrop_Blur_Rect:
			if ctx.swapchain_supports_transfer_src {
				texture_index = UI_BACKDROP_TEXTURE_ID
				uv := uifw.Rect {
					command.rect.x / max(f32(ctx.swapchain_extent.width), 1),
					command.rect.y / max(f32(ctx.swapchain_extent.height), 1),
					command.rect.w / max(f32(ctx.swapchain_extent.width), 1),
					command.rect.h / max(f32(ctx.swapchain_extent.height), 1),
				}
				ui_push_image_textured(out, &count, command.rect, uv, command.color, command.image_filter, active_scissor, ctx.swapchain_extent)
				if count > first {
					renderer.needs_backdrop_capture = true
				}
			} else {
				ui_push_rect(out, &count, command.rect, command.color, active_scissor, ctx.swapchain_extent)
			}
		case .Refractive_Glass_Rect:
			if ctx.swapchain_supports_transfer_src {
				glass_batch = true
				ui_push_refractive_glass_rect(out, &count, command.rect, command.glass_style, active_scissor, ctx.swapchain_extent)
				if count > first {
					renderer.needs_backdrop_capture = true
				}
			} else {
				ui_push_rounded_rect(out, &count, command.rect, command.glass_style.radius, command.glass_style.tint, active_scissor, ctx.swapchain_extent)
			}
		case .Text:
			text_scissor := active_scissor
			if command.rect.w > 0 && command.rect.h > 0 {
				text_scissor = ui_rect_intersection(text_scissor, command.rect)
			}
			font_atlas := ui_renderer_font_atlas_for_scale(renderer, ctx, command.font_kind, command.text_scale)
			if font_atlas != nil {
				texture_index = font_atlas.texture_index
				ui_push_text(renderer, out, &count, command, text_scissor, ctx.swapchain_extent, font_atlas)
			}
		case .Scissor_Begin:
			if scissor_depth < len(scissor_stack) {
				scissor_stack[scissor_depth] = active_scissor
				scissor_depth += 1
				active_scissor = ui_rect_intersection(active_scissor, command.rect)
			}
		case .Scissor_End:
			if scissor_depth > 0 {
				scissor_depth -= 1
				active_scissor = scissor_stack[scissor_depth]
			}
		}
		ui_renderer_add_batch(renderer, u32(first), u32(count - first), texture_index, blend_mode, glass_batch)
	}

	renderer.vertex_count = u32(count)
	return true
}

ui_renderer_needs_backdrop_blur :: proc(renderer: ^Ui_Renderer) -> bool {
	return renderer.ready && renderer.needs_backdrop_capture
}

ui_renderer_needs_backdrop_capture :: proc(renderer: ^Ui_Renderer) -> bool {
	return renderer.ready && renderer.needs_backdrop_capture
}

ui_renderer_has_overlay_work :: proc(renderer: ^Ui_Renderer) -> bool {
	return renderer.ready && (renderer.vertex_count > 0 || renderer.needs_backdrop_capture)
}

ui_renderer_draw :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context, cmd: vk.CommandBuffer, extent: vk.Extent2D) {
	if !renderer.ready || renderer.vertex_count == 0 {
		return
	}
	frame_slot := min(renderer.active_frame_slot, u32(MAX_FRAMES_IN_FLIGHT - 1))
	vertex_buffer := &renderer.vertex_buffers[frame_slot]
	if vertex_buffer.handle == vk.Buffer(0) {
		return
	}

	viewport := vk.Viewport {
		x = 0,
		y = 0,
		width = f32(extent.width),
		height = f32(extent.height),
		minDepth = 0,
		maxDepth = 1,
	}
	scissor := vk.Rect2D {
		offset = {0, 0},
		extent = extent,
	}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	buffer := vertex_buffer.handle
	offset := vk.DeviceSize(0)
	vk.CmdBindVertexBuffers(cmd, 0, 1, &buffer, &offset)
	vk_cmd_count_ui_batches(ctx, renderer.batch_count)
	for i: u32 = 0; i < renderer.batch_count; i += 1 {
		batch := renderer.batches[i]
		if batch.glass {
			pipeline := &renderer.glass_pipeline
			if pipeline.pipeline == vk.Pipeline(0) || renderer.glass_descriptor_set == vk.DescriptorSet(0) {
				continue
			}
			vk.CmdBindPipeline(cmd, .GRAPHICS, pipeline.pipeline)
			vk_cmd_count_pipeline_bind(ctx)
			vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline.layout, 0, 1, &renderer.glass_descriptor_set, 0, nil)
			vk_cmd_count_descriptor_bind(ctx)
		} else {
			pipeline := &renderer.pipelines[min(batch.blend_mode, UI_BLEND_MODE_COUNT - 1)]
			vk.CmdBindPipeline(cmd, .GRAPHICS, pipeline.pipeline)
			vk_cmd_count_pipeline_bind(ctx)
			texture := &renderer.textures[min(batch.texture_index, UI_MAX_TEXTURES - 1)]
			if !texture.ready {
				texture = &renderer.textures[0]
			}
			if texture.descriptor_set != vk.DescriptorSet(0) {
				vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline.layout, 0, 1, &texture.descriptor_set, 0, nil)
				vk_cmd_count_descriptor_bind(ctx)
			}
		}
		vk.CmdDraw(cmd, batch.vertex_count, 1, batch.first_vertex, 0)
		vk_cmd_count_draw(ctx)
	}
}
