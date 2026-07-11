package render_vk

import uifw "../ui"
import engine "../engine"

import vk "vendor:vulkan"
import "core:bytes"
import "core:fmt"
import "core:math"
import png "core:image/png"

MAX_FRAMES_IN_FLIGHT :: engine.MAX_FRAMES_IN_FLIGHT
Vk_Buffer :: engine.Vk_Buffer
Vk_Context :: engine.Vk_Context
Vk_Frame :: engine.Vk_Frame
Vk_Graphics_Pipeline :: engine.Vk_Graphics_Pipeline
Vk_Shader_Module :: engine.Vk_Shader_Module
log_error :: engine.log_error
log_warn :: engine.log_warn
vk_begin_upload_commands :: engine.vk_begin_upload_commands
vk_cmd_count_backdrop_blur_pass :: engine.vk_cmd_count_backdrop_blur_pass
vk_cmd_count_descriptor_bind :: engine.vk_cmd_count_descriptor_bind
vk_cmd_count_draw :: engine.vk_cmd_count_draw
vk_cmd_count_pipeline_barrier :: engine.vk_cmd_count_pipeline_barrier
vk_cmd_count_pipeline_bind :: engine.vk_cmd_count_pipeline_bind
vk_cmd_count_transfer_copy :: engine.vk_cmd_count_transfer_copy
vk_cmd_count_ui_batches :: engine.vk_cmd_count_ui_batches
vk_create_host_buffer :: engine.vk_create_host_buffer
vk_destroy_buffer :: engine.vk_destroy_buffer
vk_destroy_graphics_pipeline :: engine.vk_destroy_graphics_pipeline
vk_destroy_shader_module :: engine.vk_destroy_shader_module
vk_find_memory_type :: engine.vk_find_memory_type
vk_load_shader_module_with_fallback :: engine.vk_load_shader_module_with_fallback
vk_submit_upload_commands :: engine.vk_submit_upload_commands

UI_MAX_VERTICES :: 65536
UI_MAX_CLEAR_RECTS :: 4096
UI_MAX_DRAW_BATCHES :: 4096
UI_MAX_TEXTURES :: 32
UI_BLEND_MODE_COUNT :: 4
UI_BACKDROP_BLUR_VERTICES_PER_PASS :: 6
UI_BACKDROP_BLUR_PASS_COUNT :: 6
UI_STROKE_WIDTH :: f32(1)
UI_IMAGE_GLYPH :: f32(-2)
UI_GLASS_GLYPH :: f32(-3)
UI_SHADER_GLYPH_BASE :: f32(-10)
UI_DEFAULT_EFFECT :: uifw.Color{1, 1, 0, 0}
UI_DEFAULT_MATERIAL :: uifw.Color{0, 0, 0, 0}
UI_VERTEX_SHADER_FALLBACK_SPV :: "build/shaders/ui_vertex"
UI_FRAGMENT_SHADER_FALLBACK_SPV :: "build/shaders/ui"
UI_BLUR_FRAGMENT_SHADER_FALLBACK_SPV :: "build/shaders/ui_blur"
UI_GLASS_FRAGMENT_SHADER_FALLBACK_SPV :: "build/shaders/ui_glass"
UI_VERTEX_SHADER_SOURCE :: "assets/shaders/ui_vertex.slang"
UI_FRAGMENT_SHADER_SOURCE :: "assets/shaders/ui.slang"
UI_BLUR_FRAGMENT_SHADER_SOURCE :: "assets/shaders/ui_blur.slang"
UI_GLASS_FRAGMENT_SHADER_SOURCE :: "assets/shaders/ui_glass.slang"
UI_VERTEX_ENTRY_POINT :: "main"
UI_FRAGMENT_ENTRY_POINT :: "fragment_main"
UI_VERTEX_SPIRV_ENTRY_POINT :: "main"
UI_FRAGMENT_SPIRV_ENTRY_POINT :: "main"
UI_EXAMPLE_SCREENSHOT_TEXTURE_ID :: uifw.UI_EXAMPLE_SCREENSHOT_TEXTURE_ID
UI_BACKDROP_SOURCE_TEXTURE_ID :: 2
UI_BACKDROP_HALF_TEMP_TEXTURE_ID :: 3
UI_BACKDROP_HALF_TEXTURE_ID :: 4
UI_BACKDROP_QUARTER_TEMP_TEXTURE_ID :: 5
UI_BACKDROP_QUARTER_TEXTURE_ID :: 6
UI_BACKDROP_EIGHTH_TEMP_TEXTURE_ID :: 7
UI_BACKDROP_EIGHTH_TEXTURE_ID :: 8
UI_BACKDROP_TEXTURE_ID :: UI_BACKDROP_EIGHTH_TEXTURE_ID
UI_CONTROLLER_ICON_ATLAS_TEXTURE_ID :: uifw.UI_CONTROLLER_ICON_ATLAS_TEXTURE_ID
UI_KENNEY_INPUT_ATLAS_TEXTURE_ID :: uifw.UI_KENNEY_INPUT_ATLAS_TEXTURE_ID
UI_FONT_TEXTURE_FIRST_ID :: 11
UI_FONT_TEXTURE_COUNT :: UI_MAX_TEXTURES - UI_FONT_TEXTURE_FIRST_ID
UI_CONTROLLER_ICON_SIZE :: u32(96)
UI_CONTROLLER_ICON_COUNT :: uifw.UI_CONTROLLER_ICON_COUNT
UI_KENNEY_INPUT_ICON_SIZE :: u32(128)
UI_KENNEY_INPUT_ICONS_PER_STYLE :: uifw.UI_KENNEY_INPUT_ICONS_PER_STYLE
UI_KENNEY_INPUT_STYLE_COUNT :: uifw.UI_KENNEY_INPUT_STYLE_COUNT
UI_KENNEY_INPUT_ICON_COUNT :: uifw.UI_KENNEY_INPUT_ICON_COUNT
UI_FONT_ATLAS_COLUMNS :: 16
UI_EXAMPLE_SCREENSHOT_PATH :: "vizzaodin-ui-screenshot.png"
UI_EXAMPLE_SCREENSHOT_MAX_WIDTH :: u32(512)
UI_FONT_GLYPH_COUNT :: 95
UI_FONT_GLYPH_FIRST :: 32
UI_FONT_LOGICAL_WIDTH :: 10
UI_FONT_ATLAS_LOGICAL_WIDTH :: uifw.UI_FONT_ATLAS_LOGICAL_WIDTH
UI_FONT_LOGICAL_HEIGHT :: 16
UI_MAX_SHAPED_GLYPHS :: 1024
UI_TEXT_SHAPE_CACHE_ENTRIES :: 128
UI_TEXT_SHAPE_CACHE_MAX_BYTES :: 256
UI_TEXT_SHAPE_CACHE_MAX_GLYPHS :: 256

Ui_Controller_Icon :: uifw.Ui_Controller_Icon

Ui_Vertex :: struct {
	pos: uifw.Vec2,
	color: uifw.Color,
	uv: uifw.Vec2,
	glyph: f32,
	effect: uifw.Color,
	material: uifw.Color,
}

Ui_Clear_Rect :: struct {
	rect: uifw.Rect,
	color: uifw.Color,
}

Ui_Draw_Batch :: struct {
	first_vertex: u32,
	vertex_count: u32,
	texture_index: u32,
	blend_mode: u32,
	glass: bool,
}

Ui_Font_Atlas_Cache_Entry :: struct {
	font_kind: uifw.Gui_Font_Kind,
	pixel_height: u32,
	cell_width: u32,
	cell_height: u32,
	atlas_width: u32,
	atlas_height: u32,
	columns: u32,
	rows: u32,
	texture_index: u32,
	generation: u32,
	ready: bool,
}

Ui_Text_Shape_Cache_Entry :: struct {
	hash: u64,
	generation: u32,
	text_len: u16,
	scale: f32,
	font_kind: uifw.Gui_Font_Kind,
	glyph_count: u16,
	text: [UI_TEXT_SHAPE_CACHE_MAX_BYTES]u8,
	glyphs: [UI_TEXT_SHAPE_CACHE_MAX_GLYPHS]uifw.Gui_Shaped_Glyph,
}

Ui_Texture :: struct {
	image: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	framebuffer: vk.Framebuffer,
	sampler: vk.Sampler,
	descriptor_set: vk.DescriptorSet,
	width: u32,
	height: u32,
	owned: bool,
	ready: bool,
}

Ui_Renderer :: struct {
	vertex_buffers: [MAX_FRAMES_IN_FLIGHT]Vk_Buffer,
	vertex_count: u32,
	active_frame_slot: u32,
	needs_backdrop_capture: bool,
	clear_rects: [UI_MAX_CLEAR_RECTS]Ui_Clear_Rect,
	clear_rect_count: u32,
	batches: [UI_MAX_DRAW_BATCHES]Ui_Draw_Batch,
	batch_count: u32,
	descriptor_set_layout: vk.DescriptorSetLayout,
	glass_descriptor_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	glass_descriptor_set: vk.DescriptorSet,
	textures: [UI_MAX_TEXTURES]Ui_Texture,
	backdrop_width: u32,
	backdrop_height: u32,
	backdrop_layouts: [UI_MAX_TEXTURES]vk.ImageLayout,
	backdrop_render_pass: vk.RenderPass,
	backdrop_blur_pipeline: Vk_Graphics_Pipeline,
	glass_pipeline: Vk_Graphics_Pipeline,
	backdrop_vertex_buffers: [MAX_FRAMES_IN_FLIGHT]Vk_Buffer,
	pipelines: [UI_BLEND_MODE_COUNT]Vk_Graphics_Pipeline,
	font_atlases: [UI_FONT_TEXTURE_COUNT]Ui_Font_Atlas_Cache_Entry,
	font_atlas_generation: u32,
	text_shape_cache: []Ui_Text_Shape_Cache_Entry,
	text_shape_generation: u32,
	ready: bool,
}

ui_renderer_init :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context) -> bool {
	renderer^ = {}
	buffer_size := vk.DeviceSize(size_of(Ui_Vertex) * UI_MAX_VERTICES)
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		if !vk_create_host_buffer(ctx, buffer_size, {.VERTEX_BUFFER}, &renderer.vertex_buffers[i]) {
			log_error("ui_renderer_init: vertex buffer creation failed frame_slot=", i)
			ui_renderer_destroy(renderer, ctx)
			return false
		}
	}
	if !ui_renderer_create_texture_resources(renderer, ctx) {
		log_error("ui_renderer_init: texture resources creation failed")
		ui_renderer_destroy(renderer, ctx)
		return false
	}
	blur_vertex_size := vk.DeviceSize(size_of(Ui_Vertex) * UI_BACKDROP_BLUR_VERTICES_PER_PASS * UI_BACKDROP_BLUR_PASS_COUNT)
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		if !vk_create_host_buffer(ctx, blur_vertex_size, {.VERTEX_BUFFER}, &renderer.backdrop_vertex_buffers[i]) {
			log_error("ui_renderer_init: backdrop blur vertex buffer creation failed frame_slot=", i)
			ui_renderer_destroy(renderer, ctx)
			return false
		}
	}
	if !ui_renderer_create_backdrop_render_pass(renderer, ctx) {
		log_error("ui_renderer_init: backdrop blur render pass creation failed")
		ui_renderer_destroy(renderer, ctx)
		return false
	}
	if !ui_renderer_create_blur_pipeline(renderer, ctx, &renderer.backdrop_blur_pipeline) {
		log_error("ui_renderer_init: backdrop blur pipeline creation failed")
		ui_renderer_destroy(renderer, ctx)
		return false
	}
	if !ui_renderer_create_glass_pipeline(renderer, ctx, &renderer.glass_pipeline) {
		log_error("ui_renderer_init: glass pipeline creation failed")
		ui_renderer_destroy(renderer, ctx)
		return false
	}
	for i in 0 ..< UI_BLEND_MODE_COUNT {
		if !ui_renderer_create_pipeline(renderer, ctx, uifw.Gui_Blend_Mode(i), &renderer.pipelines[i]) {
			log_error("ui_renderer_init: graphics pipeline creation failed for blend mode index=", i)
			ui_renderer_destroy(renderer, ctx)
			return false
		}
	}
	renderer.text_shape_cache = make([]Ui_Text_Shape_Cache_Entry, UI_TEXT_SHAPE_CACHE_ENTRIES)
	if renderer.text_shape_cache == nil {
		log_warn("ui_renderer_init: text shape cache allocation failed; continuing without cache")
	}
	renderer.ready = true
	return true
}

ui_renderer_destroy :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context) {
	for i in 0 ..< len(renderer.pipelines) {
		vk_destroy_graphics_pipeline(ctx, &renderer.pipelines[i])
	}
	vk_destroy_graphics_pipeline(ctx, &renderer.glass_pipeline)
	vk_destroy_graphics_pipeline(ctx, &renderer.backdrop_blur_pipeline)
	if renderer.backdrop_render_pass != vk.RenderPass(0) {
		vk.DestroyRenderPass(ctx.device, renderer.backdrop_render_pass, nil)
	}
	for i in 0 ..< len(renderer.textures) {
		ui_renderer_destroy_texture(ctx, &renderer.textures[i])
	}
	if renderer.descriptor_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(ctx.device, renderer.descriptor_pool, nil)
	}
	if renderer.descriptor_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(ctx.device, renderer.descriptor_set_layout, nil)
	}
	if renderer.glass_descriptor_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(ctx.device, renderer.glass_descriptor_set_layout, nil)
	}
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk_destroy_buffer(ctx, &renderer.backdrop_vertex_buffers[i])
		vk_destroy_buffer(ctx, &renderer.vertex_buffers[i])
	}
	if renderer.text_shape_cache != nil {
		delete(renderer.text_shape_cache)
		renderer.text_shape_cache = nil
	}
	renderer^ = {}
}

ui_renderer_create_texture_resources :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context) -> bool {
	bindings := [?]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(bindings)),
		pBindings = raw_data(bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(ctx.device, &layout_info, nil, &renderer.descriptor_set_layout) != .SUCCESS {
		log_error("ui_renderer_create_texture_resources: descriptor set layout failed")
		return false
	}
	glass_bindings := [?]vk.DescriptorSetLayoutBinding {
		{binding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 2, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 3, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, stageFlags = {.FRAGMENT}},
		{binding = 4, descriptorType = .SAMPLER, descriptorCount = 1, stageFlags = {.FRAGMENT}},
	}
	glass_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(glass_bindings)),
		pBindings = raw_data(glass_bindings[:]),
	}
	if vk.CreateDescriptorSetLayout(ctx.device, &glass_layout_info, nil, &renderer.glass_descriptor_set_layout) != .SUCCESS {
		log_error("ui_renderer_create_texture_resources: glass descriptor set layout failed")
		return false
	}

	pool_sizes := [?]vk.DescriptorPoolSize {
		{type = .SAMPLED_IMAGE, descriptorCount = UI_MAX_TEXTURES + 4},
		{type = .SAMPLER, descriptorCount = UI_MAX_TEXTURES + 1},
	}
	pool_info := vk.DescriptorPoolCreateInfo {
		sType = .DESCRIPTOR_POOL_CREATE_INFO,
		maxSets = UI_MAX_TEXTURES + 1,
		poolSizeCount = u32(len(pool_sizes)),
		pPoolSizes = raw_data(pool_sizes[:]),
	}
	if vk.CreateDescriptorPool(ctx.device, &pool_info, nil, &renderer.descriptor_pool) != .SUCCESS {
		log_error("ui_renderer_create_texture_resources: descriptor pool failed")
		return false
	}

	pixels := [?]u8 {
		0x4a, 0x41, 0x3b, 0xff, 0x78, 0x6b, 0x5f, 0xff,
		0x78, 0x6b, 0x5f, 0xff, 0x4a, 0x41, 0x3b, 0xff,
	}
	if !ui_renderer_create_owned_texture(renderer, ctx, 0, 2, 2, pixels[:]) {
		return false
	}
	if !ui_renderer_update_glass_descriptor(renderer, ctx) {
		return false
	}
	_ = ui_renderer_create_example_screenshot_texture(renderer, ctx)
	_ = ui_renderer_create_controller_icon_atlas_texture(renderer, ctx)
	_ = ui_renderer_create_kenney_input_atlas_texture(renderer, ctx)
	return true
}

ui_renderer_create_backdrop_render_pass :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context) -> bool {
	attachment := vk.AttachmentDescription {
		format = ctx.swapchain_format,
		samples = {._1},
		loadOp = .CLEAR,
		storeOp = .STORE,
		stencilLoadOp = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout = .COLOR_ATTACHMENT_OPTIMAL,
		finalLayout = .COLOR_ATTACHMENT_OPTIMAL,
	}
	color_ref := vk.AttachmentReference {
		attachment = 0,
		layout = .COLOR_ATTACHMENT_OPTIMAL,
	}
	subpass := vk.SubpassDescription {
		pipelineBindPoint = .GRAPHICS,
		colorAttachmentCount = 1,
		pColorAttachments = &color_ref,
	}
	info := vk.RenderPassCreateInfo {
		sType = .RENDER_PASS_CREATE_INFO,
		attachmentCount = 1,
		pAttachments = &attachment,
		subpassCount = 1,
		pSubpasses = &subpass,
	}
	return vk.CreateRenderPass(ctx.device, &info, nil, &renderer.backdrop_render_pass) == .SUCCESS
}

ui_renderer_create_example_screenshot_texture :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context) -> bool {
	img, err := png.load(UI_EXAMPLE_SCREENSHOT_PATH, {.alpha_add_if_missing})
	if err != nil || img == nil {
		return false
	}
	defer png.destroy(img)
	if img.depth != 8 || img.channels != 4 || img.width <= 0 || img.height <= 0 {
		return false
	}

	source_width := u32(img.width)
	source_height := u32(img.height)
	target_width := min(source_width, UI_EXAMPLE_SCREENSHOT_MAX_WIDTH)
	target_height := u32(max(f32(source_height) * f32(target_width) / f32(source_width), 1))
	pixel_count := int(target_width * target_height)
	rgba := make([]u8, pixel_count * 4, context.temp_allocator)
	defer delete(rgba, context.temp_allocator)

	source := img.pixels.buf[:]
	for y in 0 ..< target_height {
		source_y := min((u64(y) * u64(source_height)) / u64(target_height), u64(source_height - 1))
		for x in 0 ..< target_width {
			source_x := min((u64(x) * u64(source_width)) / u64(target_width), u64(source_width - 1))
			src_i := int((source_y * u64(source_width) + source_x) * 4)
			dst_i := int((u64(y) * u64(target_width) + u64(x)) * 4)
			rgba[dst_i + 0] = source[src_i + 0]
			rgba[dst_i + 1] = source[src_i + 1]
			rgba[dst_i + 2] = source[src_i + 2]
			rgba[dst_i + 3] = source[src_i + 3]
		}
	}

	return ui_renderer_create_owned_texture(renderer, ctx, UI_EXAMPLE_SCREENSHOT_TEXTURE_ID, target_width, target_height, rgba)
}

ui_renderer_create_controller_icon_atlas_texture :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context) -> bool {
	paths := [?]string {
		"assets/icons/tabler/png/96/player-play.png",
		"assets/icons/tabler/png/96/palette.png",
		"assets/icons/tabler/png/96/brush.png",
		"assets/icons/tabler/png/96/arrows-move.png",
		"assets/icons/tabler/png/96/radar.png",
		"assets/icons/tabler/png/96/route.png",
		"assets/icons/tabler/png/96/world.png",
		"assets/icons/tabler/png/96/sparkles.png",
		"assets/icons/tabler/png/96/video.png",
		"assets/icons/tabler/png/96/bookmarks.png",
		"assets/icons/tabler/png/96/grid-pattern.png",
		"assets/icons/tabler/png/96/mask.png",
		"assets/icons/tabler/png/96/camera.png",
		"assets/icons/tabler/png/96/magnet.png",
		"assets/icons/tabler/png/96/atom.png",
		"assets/icons/tabler/png/96/users-group.png",
		"assets/icons/tabler/png/96/settings-cog.png",
		"assets/icons/tabler/png/96/chart-grid-dots.png",
		"assets/icons/tabler/png/96/grain.png",
		"assets/icons/tabler/png/96/map-pins.png",
		"assets/icons/tabler/png/96/wind.png",
	}
	atlas_width := UI_CONTROLLER_ICON_SIZE * u32(len(paths))
	atlas_height := UI_CONTROLLER_ICON_SIZE
	icon_stride := int(UI_CONTROLLER_ICON_SIZE * 4)
	atlas := make([]u8, int(atlas_width * atlas_height * 4), context.temp_allocator)
	defer delete(atlas, context.temp_allocator)
	loaded_count := 0

	for path, icon_index in paths {
		img, err := png.load(path, {.alpha_add_if_missing})
		if err != nil || img == nil {
			log_warn("ui_renderer_create_controller_icon_atlas_texture: failed to load ", path)
			if img != nil {
				png.destroy(img)
			}
			continue
		}
		if img.depth != 8 || img.channels != 4 || img.width != int(UI_CONTROLLER_ICON_SIZE) || img.height != int(UI_CONTROLLER_ICON_SIZE) {
			log_warn("ui_renderer_create_controller_icon_atlas_texture: unexpected icon format ", path, " size=", img.width, "x", img.height, " channels=", img.channels, " depth=", img.depth)
			png.destroy(img)
			continue
		}

		pixels := bytes.buffer_to_bytes(&img.pixels)
		for y in 0 ..< int(UI_CONTROLLER_ICON_SIZE) {
			src_start := y * icon_stride
			dst_start := (y * int(atlas_width) + icon_index * int(UI_CONTROLLER_ICON_SIZE)) * 4
			copy(atlas[dst_start:dst_start + icon_stride], pixels[src_start:src_start + icon_stride])
		}
		loaded_count += 1
		png.destroy(img)
	}

	if loaded_count == 0 {
		return false
	}
	return ui_renderer_create_owned_texture(renderer, ctx, UI_CONTROLLER_ICON_ATLAS_TEXTURE_ID, atlas_width, atlas_height, atlas)
}

ui_renderer_create_kenney_input_atlas_texture :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context) -> bool {
	// Each family keeps the same semantic order: D-pad, left shoulder, right
	// shoulder, south face, east face, and light left-stick movement.
	paths := [?]string {
		"assets/icons/kenney-input-prompts/png/128/xbox_dpad.png",
		"assets/icons/kenney-input-prompts/png/128/xbox_lb.png",
		"assets/icons/kenney-input-prompts/png/128/xbox_rb.png",
		"assets/icons/kenney-input-prompts/png/128/xbox_button_a.png",
		"assets/icons/kenney-input-prompts/png/128/xbox_button_b.png",
		"assets/icons/kenney-input-prompts/png/128/xbox_stick_l_horizontal.png",
		"assets/icons/kenney-input-prompts/png/128/playstation_dpad.png",
		"assets/icons/kenney-input-prompts/png/128/playstation_trigger_l1.png",
		"assets/icons/kenney-input-prompts/png/128/playstation_trigger_r1.png",
		"assets/icons/kenney-input-prompts/png/128/playstation_button_cross.png",
		"assets/icons/kenney-input-prompts/png/128/playstation_button_circle.png",
		"assets/icons/kenney-input-prompts/png/128/playstation_stick_l_horizontal.png",
		"assets/icons/kenney-input-prompts/png/128/steamdeck_dpad.png",
		"assets/icons/kenney-input-prompts/png/128/steamdeck_button_l1.png",
		"assets/icons/kenney-input-prompts/png/128/steamdeck_button_r1.png",
		"assets/icons/kenney-input-prompts/png/128/steamdeck_button_a.png",
		"assets/icons/kenney-input-prompts/png/128/steamdeck_button_b.png",
		"assets/icons/kenney-input-prompts/png/128/steamdeck_stick_l_horizontal.png",
	}
	atlas_width := UI_KENNEY_INPUT_ICON_SIZE * u32(len(paths))
	atlas_height := UI_KENNEY_INPUT_ICON_SIZE
	icon_stride := int(UI_KENNEY_INPUT_ICON_SIZE * 4)
	atlas := make([]u8, int(atlas_width * atlas_height * 4), context.temp_allocator)
	defer delete(atlas, context.temp_allocator)
	loaded_count := 0

	for path, icon_index in paths {
		img, err := png.load(path, {.alpha_add_if_missing})
		if err != nil || img == nil {
			log_warn("ui_renderer_create_kenney_input_atlas_texture: failed to load ", path)
			if img != nil {
				png.destroy(img)
			}
			continue
		}
		if img.depth != 8 || img.channels != 4 || img.width != int(UI_KENNEY_INPUT_ICON_SIZE) || img.height != int(UI_KENNEY_INPUT_ICON_SIZE) {
			log_warn("ui_renderer_create_kenney_input_atlas_texture: unexpected icon format ", path, " size=", img.width, "x", img.height, " channels=", img.channels, " depth=", img.depth)
			png.destroy(img)
			continue
		}

		pixels := bytes.buffer_to_bytes(&img.pixels)
		for y in 0 ..< int(UI_KENNEY_INPUT_ICON_SIZE) {
			src_start := y * icon_stride
			dst_start := (y * int(atlas_width) + icon_index * int(UI_KENNEY_INPUT_ICON_SIZE)) * 4
			copy(atlas[dst_start:dst_start + icon_stride], pixels[src_start:src_start + icon_stride])
		}
		loaded_count += 1
		png.destroy(img)
	}

	if loaded_count == 0 {
		return false
	}
	return ui_renderer_create_owned_texture(renderer, ctx, UI_KENNEY_INPUT_ATLAS_TEXTURE_ID, atlas_width, atlas_height, atlas)
}

ui_renderer_create_owned_texture :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context, index: int, width, height: u32, rgba: []u8) -> bool {
	if index < 0 || index >= UI_MAX_TEXTURES || len(rgba) < int(width * height * 4) {
		log_error("ui_renderer_create_owned_texture: invalid texture data index=", index, " bytes=", len(rgba), " expected=", width * height * 4)
		return false
	}

	texture := &renderer.textures[index]
	ui_renderer_destroy_texture(ctx, texture)

	staging: Vk_Buffer
	size := vk.DeviceSize(width * height * 4)
	if !vk_create_host_buffer(ctx, size, {.TRANSFER_SRC}, &staging) {
		log_error("ui_renderer_create_owned_texture: staging buffer failed")
		return false
	}
	defer vk_destroy_buffer(ctx, &staging)
	dst := cast([^]u8)staging.mapped
	for i in 0 ..< int(size) {
		dst[i] = rgba[i]
	}

	image_info := vk.ImageCreateInfo {
		sType = .IMAGE_CREATE_INFO,
		imageType = .D2,
		format = .R8G8B8A8_UNORM,
		extent = {width, height, 1},
		mipLevels = 1,
		arrayLayers = 1,
		samples = {._1},
		tiling = .OPTIMAL,
		usage = {.TRANSFER_DST, .SAMPLED},
		sharingMode = .EXCLUSIVE,
		initialLayout = .UNDEFINED,
	}
	if vk.CreateImage(ctx.device, &image_info, nil, &texture.image) != .SUCCESS {
		log_error("ui_renderer_create_owned_texture: image creation failed")
		texture^ = {}
		return false
	}

	req: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(ctx.device, texture.image, &req)
	memory_type, ok := vk_find_memory_type(ctx, req.memoryTypeBits, {.DEVICE_LOCAL})
	if !ok {
		log_error("ui_renderer_create_owned_texture: device local memory type not found")
		ui_renderer_destroy_texture(ctx, texture)
		return false
	}
	alloc := vk.MemoryAllocateInfo {
		sType = .MEMORY_ALLOCATE_INFO,
		allocationSize = req.size,
		memoryTypeIndex = memory_type,
	}
	if vk.AllocateMemory(ctx.device, &alloc, nil, &texture.memory) != .SUCCESS {
		log_error("ui_renderer_create_owned_texture: image memory allocation failed")
		ui_renderer_destroy_texture(ctx, texture)
		return false
	}
	if vk.BindImageMemory(ctx.device, texture.image, texture.memory, 0) != .SUCCESS {
		log_error("ui_renderer_create_owned_texture: bind image memory failed")
		ui_renderer_destroy_texture(ctx, texture)
		return false
	}

	view_info := vk.ImageViewCreateInfo {
		sType = .IMAGE_VIEW_CREATE_INFO,
		image = texture.image,
		viewType = .D2,
		format = .R8G8B8A8_UNORM,
		subresourceRange = {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
		},
	}
	if vk.CreateImageView(ctx.device, &view_info, nil, &texture.view) != .SUCCESS {
		log_error("ui_renderer_create_owned_texture: image view creation failed")
		ui_renderer_destroy_texture(ctx, texture)
		return false
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
	sampler_info.unnormalizedCoordinates = false
	if vk.CreateSampler(ctx.device, &sampler_info, nil, &texture.sampler) != .SUCCESS {
		log_error("ui_renderer_create_owned_texture: sampler creation failed")
		ui_renderer_destroy_texture(ctx, texture)
		return false
	}

	if !ui_renderer_upload_texture(ctx, texture.image, width, height, staging.handle) {
		log_error("ui_renderer_create_owned_texture: upload failed")
		ui_renderer_destroy_texture(ctx, texture)
		return false
	}
	texture.owned = true
	texture.width = width
	texture.height = height
	return ui_renderer_allocate_texture_descriptor(renderer, ctx, index, texture.view, texture.sampler)
}
