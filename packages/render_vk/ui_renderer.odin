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
	to_src := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = {.COLOR_ATTACHMENT_WRITE},
		dstAccessMask = {.TRANSFER_READ},
		oldLayout = .PRESENT_SRC_KHR,
		newLayout = .TRANSFER_SRC_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = swapchain_image,
		subresourceRange = range,
	}
	to_dst := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = renderer.backdrop_layouts[UI_BACKDROP_SOURCE_TEXTURE_ID] == .SHADER_READ_ONLY_OPTIMAL ? vk.AccessFlags{.SHADER_READ} : vk.AccessFlags{},
		dstAccessMask = {.TRANSFER_WRITE},
		oldLayout = renderer.backdrop_layouts[UI_BACKDROP_SOURCE_TEXTURE_ID],
		newLayout = .TRANSFER_DST_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = source.image,
		subresourceRange = range,
	}
	barriers := [?]vk.ImageMemoryBarrier{to_src, to_dst}
	vk.CmdPipelineBarrier(frame.command_buffer, {.COLOR_ATTACHMENT_OUTPUT, .FRAGMENT_SHADER}, {.TRANSFER}, {}, 0, nil, 0, nil, u32(len(barriers)), raw_data(barriers[:]))
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

	to_color := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = {.TRANSFER_READ},
		dstAccessMask = {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE},
		oldLayout = .TRANSFER_SRC_OPTIMAL,
		newLayout = .COLOR_ATTACHMENT_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = swapchain_image,
		subresourceRange = range,
	}
	to_shader := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = {.TRANSFER_WRITE},
		dstAccessMask = {.SHADER_READ},
		oldLayout = .TRANSFER_DST_OPTIMAL,
		newLayout = .SHADER_READ_ONLY_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = source.image,
		subresourceRange = range,
	}
	post_barriers := [?]vk.ImageMemoryBarrier{to_color, to_shader}
	vk.CmdPipelineBarrier(frame.command_buffer, {.TRANSFER}, {.COLOR_ATTACHMENT_OUTPUT, .FRAGMENT_SHADER}, {}, 0, nil, 0, nil, u32(len(post_barriers)), raw_data(post_barriers[:]))
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
	if !source.ready || !dest.ready || dest.framebuffer == vk.Framebuffer(0) {
		return false
	}

	range := vk.ImageSubresourceRange {
		aspectMask = {.COLOR},
		baseMipLevel = 0,
		levelCount = 1,
		baseArrayLayer = 0,
		layerCount = 1,
	}
	to_color := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = renderer.backdrop_layouts[dest_index] == .SHADER_READ_ONLY_OPTIMAL ? vk.AccessFlags{.SHADER_READ} : vk.AccessFlags{},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
		oldLayout = renderer.backdrop_layouts[dest_index],
		newLayout = .COLOR_ATTACHMENT_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = dest.image,
		subresourceRange = range,
	}
	vk.CmdPipelineBarrier(cmd, {.FRAGMENT_SHADER, .TOP_OF_PIPE}, {.COLOR_ATTACHMENT_OUTPUT}, {}, 0, nil, 0, nil, 1, &to_color)
	vk_cmd_count_pipeline_barrier(ctx)
	renderer.backdrop_layouts[dest_index] = .COLOR_ATTACHMENT_OPTIMAL

	clear := vk.ClearValue{color = {float32 = {0, 0, 0, 0}}}
	render_area := vk.Rect2D {
		offset = {0, 0},
		extent = {dest.width, dest.height},
	}
	begin := vk.RenderPassBeginInfo {
		sType = .RENDER_PASS_BEGIN_INFO,
		renderPass = renderer.backdrop_render_pass,
		framebuffer = dest.framebuffer,
		renderArea = render_area,
		clearValueCount = 1,
		pClearValues = &clear,
	}
	vk.CmdBeginRenderPass(cmd, &begin, .INLINE)
	ctx.command_shape.render_pass_count += 1
	vk_cmd_count_backdrop_blur_pass(ctx)

	viewport := vk.Viewport{x = 0, y = 0, width = f32(dest.width), height = f32(dest.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = {dest.width, dest.height}}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)

	if !ui_renderer_write_blur_quad(renderer, frame_slot, vertex_offset, texel_step) {
		vk.CmdEndRenderPass(cmd)
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
	vk.CmdEndRenderPass(cmd)

	to_shader := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = {.COLOR_ATTACHMENT_WRITE},
		dstAccessMask = {.SHADER_READ},
		oldLayout = .COLOR_ATTACHMENT_OPTIMAL,
		newLayout = .SHADER_READ_ONLY_OPTIMAL,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = dest.image,
		subresourceRange = range,
	}
	vk.CmdPipelineBarrier(cmd, {.COLOR_ATTACHMENT_OUTPUT}, {.FRAGMENT_SHADER}, {}, 0, nil, 0, nil, 1, &to_shader)
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
	info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
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
		renderPass = ctx.render_pass,
		subpass = 0,
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
	info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
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
		renderPass = renderer.backdrop_render_pass,
		subpass = 0,
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
	info := vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
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
		renderPass = ctx.render_pass,
		subpass = 0,
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

ui_renderer_texture_index :: proc(renderer: ^Ui_Renderer, id: uifw.Gui_Image_Id) -> u32 {
	index := int(id)
	if index <= 0 || index >= UI_MAX_TEXTURES || !renderer.textures[index].ready {
		return 0
	}
	return u32(index)
}

ui_renderer_font_atlas_for_scale :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context, font_kind: uifw.Gui_Font_Kind, scale: f32) -> ^Ui_Font_Atlas_Cache_Entry {
	if renderer == nil || ctx == nil || UI_FONT_TEXTURE_COUNT <= 0 {
		return nil
	}
	text_scale := scale
	if text_scale <= 0 {
		text_scale = 1
	}
	pixel_height := u32(max(math.ceil(f32(UI_FONT_LOGICAL_HEIGHT) * text_scale), 1))
	renderer.font_atlas_generation += 1
	if renderer.font_atlas_generation == 0 {
		renderer.font_atlas_generation = 1
		for i in 0 ..< len(renderer.font_atlases) {
			renderer.font_atlases[i].generation = 0
		}
	}

	for i in 0 ..< len(renderer.font_atlases) {
		entry := &renderer.font_atlases[i]
		if entry.ready && entry.font_kind == font_kind && entry.pixel_height == pixel_height {
			entry.generation = renderer.font_atlas_generation
			return entry
		}
	}

	slot := 0
	oldest_generation := renderer.font_atlases[0].generation
	for i in 0 ..< len(renderer.font_atlases) {
		entry := &renderer.font_atlases[i]
		if !entry.ready {
			slot = i
			break
		}
		if entry.generation < oldest_generation {
			slot = i
			oldest_generation = entry.generation
		}
	}

	entry := &renderer.font_atlases[slot]
	texture_index := UI_FONT_TEXTURE_FIRST_ID + slot
	cell_height := pixel_height
	cell_width := u32(max(math.ceil(f32(pixel_height) * f32(UI_FONT_ATLAS_LOGICAL_WIDTH) / f32(UI_FONT_LOGICAL_HEIGHT)), 1))
	columns := u32(UI_FONT_ATLAS_COLUMNS)
	rows := u32((UI_FONT_GLYPH_COUNT + UI_FONT_ATLAS_COLUMNS - 1) / UI_FONT_ATLAS_COLUMNS)
	atlas_width := cell_width * columns
	atlas_height := cell_height * rows
	byte_count := int(atlas_width * atlas_height * 4)
	rgba := make([]u8, byte_count, context.temp_allocator)
	defer delete(rgba, context.temp_allocator)
	if !uifw.gui_font_render_ascii_atlas(font_kind, UI_FONT_GLYPH_FIRST, UI_FONT_GLYPH_FIRST + UI_FONT_GLYPH_COUNT - 1, int(pixel_height), int(cell_width), int(cell_height), int(columns), rgba) {
		log_warn("ui_renderer_font_atlas_for_scale: font atlas rasterization failed height=", pixel_height)
		return nil
	}
	if !ui_renderer_create_owned_texture(renderer, ctx, texture_index, atlas_width, atlas_height, rgba) {
		log_warn("ui_renderer_font_atlas_for_scale: font atlas upload failed height=", pixel_height, " atlas=", atlas_width, "x", atlas_height)
		return nil
	}

	entry^ = {
		font_kind = font_kind,
		pixel_height = pixel_height,
		cell_width = cell_width,
		cell_height = cell_height,
		atlas_width = atlas_width,
		atlas_height = atlas_height,
		columns = columns,
		rows = rows,
		texture_index = u32(texture_index),
		generation = renderer.font_atlas_generation,
		ready = true,
	}
	return entry
}

ui_renderer_blend_index :: proc(mode: uifw.Gui_Blend_Mode) -> u32 {
	switch mode {
	case .Alpha:
		return 0
	case .Add:
		return 1
	case .Multiply:
		return 2
	case .Screen:
		return 3
	}
	return 0
}

ui_renderer_active_frame_slot :: proc(ctx: ^Vk_Context) -> u32 {
	if ctx == nil {
		return 0
	}
	return ctx.current_frame % MAX_FRAMES_IN_FLIGHT
}

ui_renderer_add_batch :: proc(renderer: ^Ui_Renderer, first, count, texture_index, blend_mode: u32, glass: bool) {
	if count == 0 {
		return
	}
	if renderer.batch_count > 0 {
		last := &renderer.batches[renderer.batch_count - 1]
		if last.texture_index == texture_index && last.blend_mode == blend_mode && last.glass == glass && last.first_vertex + last.vertex_count == first {
			last.vertex_count += count
			return
		}
	}
	if renderer.batch_count >= UI_MAX_DRAW_BATCHES {
		return
	}
	renderer.batches[renderer.batch_count] = {first_vertex = first, vertex_count = count, texture_index = texture_index, blend_mode = blend_mode, glass = glass}
	renderer.batch_count += 1
}

ui_push_stroke :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, color: uifw.Color, width: f32, scissor: uifw.Rect, extent: vk.Extent2D) {
	w := max(width, UI_STROKE_WIDTH)
	ui_push_rect(out, count, {rect.x, rect.y, rect.w, w}, color, scissor, extent)
	ui_push_rect(out, count, {rect.x, rect.y + rect.h - w, rect.w, w}, color, scissor, extent)
	ui_push_rect(out, count, {rect.x, rect.y, w, rect.h}, color, scissor, extent)
	ui_push_rect(out, count, {rect.x + rect.w - w, rect.y, w, rect.h}, color, scissor, extent)
}

ui_push_clear_stroke :: proc(out: []Ui_Clear_Rect, count: ^int, rect: uifw.Rect, color: uifw.Color, width: f32, scissor: uifw.Rect) {
	w := max(width, UI_STROKE_WIDTH)
	ui_push_clear_rect(out, count, {rect.x, rect.y, rect.w, w}, color, scissor)
	ui_push_clear_rect(out, count, {rect.x, rect.y + rect.h - w, rect.w, w}, color, scissor)
	ui_push_clear_rect(out, count, {rect.x, rect.y, w, rect.h}, color, scissor)
	ui_push_clear_rect(out, count, {rect.x + rect.w - w, rect.y, w, rect.h}, color, scissor)
}

ui_push_rounded_rect :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, radius: f32, color: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	r := min(max(radius, 0), min(clipped.w, clipped.h) * 0.5)
	if r <= 0.5 {
		ui_push_rect(out, count, clipped, color, scissor, extent)
		return
	}

	points: [32]uifw.Vec2
	n := ui_rounded_rect_points(points[:], clipped, r)
	center := uifw.Vec2{clipped.x + clipped.w * 0.5, clipped.y + clipped.h * 0.5}
	for i in 0 ..< n {
		j := (i + 1) % n
		ui_push_triangle_screen(out, count, center, points[i], points[j], color, color, color, extent)
	}
}

ui_push_rounded_stroke :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, radius, width: f32, color: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	w := min(max(width, UI_STROKE_WIDTH), min(clipped.w, clipped.h) * 0.5)
	r := min(max(radius, 0), min(clipped.w, clipped.h) * 0.5)
	if r <= 0.5 {
		ui_push_stroke(out, count, clipped, color, w, scissor, extent)
		return
	}

	inner := uifw.Rect{clipped.x + w, clipped.y + w, max(clipped.w - w * 2, 0), max(clipped.h - w * 2, 0)}
	inner_r := max(r - w, 0)
	outer_points: [32]uifw.Vec2
	inner_points: [32]uifw.Vec2
	n := ui_rounded_rect_points(outer_points[:], clipped, r)
	_ = ui_rounded_rect_points(inner_points[:], inner, inner_r)
	for i in 0 ..< n {
		j := (i + 1) % n
		ui_push_triangle_screen(out, count, outer_points[i], outer_points[j], inner_points[j], color, color, color, extent)
		ui_push_triangle_screen(out, count, outer_points[i], inner_points[j], inner_points[i], color, color, color, extent)
	}
}

ui_push_gradient_rect :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, radius: f32, top, bottom: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	if count^ + 6 > UI_MAX_VERTICES {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	r := min(max(radius, 0), min(clipped.w, clipped.h) * 0.5)
	if r > 0.5 {
		points: [32]uifw.Vec2
		n := ui_rounded_rect_points(points[:], clipped, r)
		center := uifw.Vec2{clipped.x + clipped.w * 0.5, clipped.y + clipped.h * 0.5}
		center_t := (center.y - rect.y) / max(rect.h, 0.00001)
		center_color := ui_color_lerp(top, bottom, center_t)
		for i in 0 ..< n {
			j := (i + 1) % n
			ai := (points[i].y - rect.y) / max(rect.h, 0.00001)
			bi := (points[j].y - rect.y) / max(rect.h, 0.00001)
			ui_push_triangle_screen(out, count, center, points[i], points[j], center_color, ui_color_lerp(top, bottom, ai), ui_color_lerp(top, bottom, bi), extent)
		}
		return
	}
	y0_t := (clipped.y - rect.y) / max(rect.h, 0.00001)
	y1_t := (clipped.y + clipped.h - rect.y) / max(rect.h, 0.00001)
	c0 := ui_color_lerp(top, bottom, y0_t)
	c1 := ui_color_lerp(top, bottom, y1_t)
	p0 := uifw.Vec2{clipped.x, clipped.y}
	p1 := uifw.Vec2{clipped.x + clipped.w, clipped.y}
	p2 := uifw.Vec2{clipped.x + clipped.w, clipped.y + clipped.h}
	p3 := uifw.Vec2{clipped.x, clipped.y + clipped.h}
	ui_push_triangle_screen(out, count, p0, p1, p2, c0, c0, c1, extent)
	ui_push_triangle_screen(out, count, p0, p2, p3, c0, c1, c1, extent)
}

ui_push_horizontal_gradient_rect :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, left, right: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	if count^ + 6 > UI_MAX_VERTICES {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	x0_t := (clipped.x - rect.x) / max(rect.w, 0.00001)
	x1_t := (clipped.x + clipped.w - rect.x) / max(rect.w, 0.00001)
	c0 := ui_color_lerp(left, right, x0_t)
	c1 := ui_color_lerp(left, right, x1_t)
	p0 := uifw.Vec2{clipped.x, clipped.y}
	p1 := uifw.Vec2{clipped.x + clipped.w, clipped.y}
	p2 := uifw.Vec2{clipped.x + clipped.w, clipped.y + clipped.h}
	p3 := uifw.Vec2{clipped.x, clipped.y + clipped.h}
	ui_push_triangle_screen(out, count, p0, p1, p2, c0, c1, c1, extent)
	ui_push_triangle_screen(out, count, p0, p2, p3, c0, c1, c0, extent)
}

ui_push_line :: proc(out: [^]Ui_Vertex, count: ^int, p0, p1: uifw.Vec2, color: uifw.Color, width: f32, scissor: uifw.Rect, extent: vk.Extent2D) {
	dx := p1.x - p0.x
	dy := p1.y - p0.y
	len_sq := dx * dx + dy * dy
	if len_sq <= 0.0001 {
		ui_push_ellipse(out, count, {p0.x - width * 0.5, p0.y - width * 0.5, width, width}, color, scissor, extent)
		return
	}
	len := math.sqrt(len_sq)
	nx := -dy / len * width * 0.5
	ny := dx / len * width * 0.5
	bounds := uifw.Rect{min(p0.x, p1.x) - width, min(p0.y, p1.y) - width, abs(dx) + width * 2, abs(dy) + width * 2}
	if ui_rect_intersection(bounds, scissor).w <= 0 || ui_rect_intersection(bounds, scissor).h <= 0 {
		return
	}
	a := uifw.Vec2{p0.x + nx, p0.y + ny}
	b := uifw.Vec2{p1.x + nx, p1.y + ny}
	c := uifw.Vec2{p1.x - nx, p1.y - ny}
	d := uifw.Vec2{p0.x - nx, p0.y - ny}
	ui_push_quad(out, count, a, b, c, d, color, scissor, extent)
}

ui_push_quad :: proc(out: [^]Ui_Vertex, count: ^int, p0, p1, p2, p3: uifw.Vec2, color: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	min_x := min(min(p0.x, p1.x), min(p2.x, p3.x))
	min_y := min(min(p0.y, p1.y), min(p2.y, p3.y))
	max_x := max(max(p0.x, p1.x), max(p2.x, p3.x))
	max_y := max(max(p0.y, p1.y), max(p2.y, p3.y))
	bounds_clip := ui_rect_intersection({min_x, min_y, max_x - min_x, max_y - min_y}, scissor)
	if bounds_clip.w <= 0 || bounds_clip.h <= 0 {
		return
	}
	points := [?]uifw.Vec2{p0, p1, p2, p3}
	clipped: [16]uifw.Vec2
	n := ui_clip_polygon_to_rect(points[:], clipped[:], scissor)
	if n < 3 {
		return
	}
	ui_push_solid_polygon(out, count, clipped[:n], color, extent)
}

ui_push_solid_polygon :: proc(out: [^]Ui_Vertex, count: ^int, points: []uifw.Vec2, color: uifw.Color, extent: vk.Extent2D) {
	if len(points) < 3 {
		return
	}
	required := (len(points) - 2) * 3
	if count^ + required > UI_MAX_VERTICES {
		return
	}
	origin := points[0]
	for i in 1 ..< len(points) - 1 {
		ui_push_triangle_screen(out, count, origin, points[i], points[i + 1], color, color, color, extent)
	}
}

ui_push_triangle_clipped :: proc(out: [^]Ui_Vertex, count: ^int, p0, p1, p2: uifw.Vec2, color: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	min_x := min(min(p0.x, p1.x), p2.x)
	min_y := min(min(p0.y, p1.y), p2.y)
	max_x := max(max(p0.x, p1.x), p2.x)
	max_y := max(max(p0.y, p1.y), p2.y)
	bounds_clip := ui_rect_intersection({min_x, min_y, max_x - min_x, max_y - min_y}, scissor)
	if bounds_clip.w <= 0 || bounds_clip.h <= 0 {
		return
	}
	points := [?]uifw.Vec2{p0, p1, p2}
	clipped: [16]uifw.Vec2
	n := ui_clip_polygon_to_rect(points[:], clipped[:], scissor)
	if n < 3 {
		return
	}
	ui_push_solid_polygon(out, count, clipped[:n], color, extent)
}

ui_clip_polygon_to_rect :: proc(points: []uifw.Vec2, out: []uifw.Vec2, rect: uifw.Rect) -> int {
	if len(points) == 0 || len(out) == 0 || rect.w <= 0 || rect.h <= 0 {
		return 0
	}
	a: [16]uifw.Vec2
	b: [16]uifw.Vec2
	n := min(len(points), len(a))
	for i in 0 ..< n {
		a[i] = points[i]
	}

	left := rect.x
	top := rect.y
	right := rect.x + rect.w
	bottom := rect.y + rect.h

	n = ui_clip_polygon_edge(a[:n], b[:], left, 0)
	n = ui_clip_polygon_edge(b[:n], a[:], right, 1)
	n = ui_clip_polygon_edge(a[:n], b[:], top, 2)
	n = ui_clip_polygon_edge(b[:n], a[:], bottom, 3)

	result_count := min(n, len(out))
	for i in 0 ..< result_count {
		out[i] = a[i]
	}
	return result_count
}

ui_clip_polygon_edge :: proc(input: []uifw.Vec2, output: []uifw.Vec2, boundary: f32, edge: int) -> int {
	if len(input) == 0 || len(output) == 0 {
		return 0
	}
	count := 0
	prev := input[len(input) - 1]
	prev_inside := ui_clip_point_inside(prev, boundary, edge)
	for curr in input {
		curr_inside := ui_clip_point_inside(curr, boundary, edge)
		if curr_inside {
			if !prev_inside && count < len(output) {
				output[count] = ui_clip_intersection(prev, curr, boundary, edge)
				count += 1
			}
			if count < len(output) {
				output[count] = curr
				count += 1
			}
		} else if prev_inside && count < len(output) {
			output[count] = ui_clip_intersection(prev, curr, boundary, edge)
			count += 1
		}
		prev = curr
		prev_inside = curr_inside
	}
	return count
}

ui_clip_point_inside :: proc(p: uifw.Vec2, boundary: f32, edge: int) -> bool {
	switch edge {
	case 0:
		return p.x >= boundary
	case 1:
		return p.x <= boundary
	case 2:
		return p.y >= boundary
	case:
		return p.y <= boundary
	}
}

ui_clip_intersection :: proc(a, b: uifw.Vec2, boundary: f32, edge: int) -> uifw.Vec2 {
	if edge == 0 || edge == 1 {
		t := (boundary - a.x) / max(b.x - a.x, 0.00001)
		if b.x < a.x {
			t = (boundary - a.x) / min(b.x - a.x, -0.00001)
		}
		return {boundary, a.y + (b.y - a.y) * t}
	}
	t := (boundary - a.y) / max(b.y - a.y, 0.00001)
	if b.y < a.y {
		t = (boundary - a.y) / min(b.y - a.y, -0.00001)
	}
	return {a.x + (b.x - a.x) * t, boundary}
}

ui_push_ellipse :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, color: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	center := uifw.Vec2{rect.x + rect.w * 0.5, rect.y + rect.h * 0.5}
	points: [32]uifw.Vec2
	n := ui_ellipse_points(points[:], rect)
	for i in 0 ..< n {
		j := (i + 1) % n
		ui_push_triangle_clipped(out, count, center, points[i], points[j], color, scissor, extent)
	}
}

ui_push_ellipse_stroke :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, color: uifw.Color, width: f32, scissor: uifw.Rect, extent: vk.Extent2D) {
	if ui_rect_intersection(rect, scissor).w <= 0 || ui_rect_intersection(rect, scissor).h <= 0 {
		return
	}
	w := min(max(width, UI_STROKE_WIDTH), min(rect.w, rect.h) * 0.5)
	inner := uifw.Rect{rect.x + w, rect.y + w, max(rect.w - w * 2, 0), max(rect.h - w * 2, 0)}
	outer_points: [32]uifw.Vec2
	inner_points: [32]uifw.Vec2
	n := ui_ellipse_points(outer_points[:], rect)
	_ = ui_ellipse_points(inner_points[:], inner)
	for i in 0 ..< n {
		j := (i + 1) % n
		ui_push_quad(out, count, outer_points[i], outer_points[j], inner_points[j], inner_points[i], color, scissor, extent)
	}
}

ui_push_image_textured :: proc(out: [^]Ui_Vertex, count: ^int, rect, uv_rect: uifw.Rect, tint: uifw.Color, filter: uifw.Gui_Image_Filter, scissor: uifw.Rect, extent: vk.Extent2D) {
	if count^ + 6 > UI_MAX_VERTICES {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	color := tint
	if color.a <= 0 {
		color = {1, 1, 1, 1}
	}
	uv := uv_rect
	if uv.w == 0 && uv.h == 0 {
		uv = {0, 0, 1, 1}
	}
	effect := uifw.Color{filter.brightness, filter.contrast, filter.grayscale, filter.blur}
	if effect.r == 0 {
		effect.r = 1
	}
	if effect.g == 0 {
		effect.g = 1
	}
	u0 := uv.x + (clipped.x - rect.x) / max(rect.w, 0.00001) * uv.w
	v0 := uv.y + (clipped.y - rect.y) / max(rect.h, 0.00001) * uv.h
	u1 := uv.x + (clipped.x + clipped.w - rect.x) / max(rect.w, 0.00001) * uv.w
	v1 := uv.y + (clipped.y + clipped.h - rect.y) / max(rect.h, 0.00001) * uv.h

	x0 := ui_screen_to_ndc_x(clipped.x, extent.width)
	y0 := ui_screen_to_ndc_y(clipped.y, extent.height)
	x1 := ui_screen_to_ndc_x(clipped.x + clipped.w, extent.width)
	y1 := ui_screen_to_ndc_y(clipped.y + clipped.h, extent.height)

	verts := [?]Ui_Vertex {
		{{x0, y0}, color, {u0, v0}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{x1, y0}, color, {u1, v0}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{x1, y1}, color, {u1, v1}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{x0, y0}, color, {u0, v0}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{x1, y1}, color, {u1, v1}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{x0, y1}, color, {u0, v1}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
	}
	for vertex in verts {
		out[count^] = vertex
		count^ += 1
	}
}

ui_push_shader_rect :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, tint: uifw.Color, kind: uifw.Gui_Shader_Kind, params: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	if count^ + 6 > UI_MAX_VERTICES {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	color := tint
	if color.a <= 0 {
		color = {1, 1, 1, 1}
	}
	u0 := (clipped.x - rect.x) / max(rect.w, 0.00001)
	v0 := (clipped.y - rect.y) / max(rect.h, 0.00001)
	u1 := (clipped.x + clipped.w - rect.x) / max(rect.w, 0.00001)
	v1 := (clipped.y + clipped.h - rect.y) / max(rect.h, 0.00001)

	x0 := ui_screen_to_ndc_x(clipped.x, extent.width)
	y0 := ui_screen_to_ndc_y(clipped.y, extent.height)
	x1 := ui_screen_to_ndc_x(clipped.x + clipped.w, extent.width)
	y1 := ui_screen_to_ndc_y(clipped.y + clipped.h, extent.height)
	glyph := UI_SHADER_GLYPH_BASE - f32(kind)
	effect := params

	verts := [?]Ui_Vertex {
		{{x0, y0}, color, {u0, v0}, glyph, effect, UI_DEFAULT_MATERIAL},
		{{x1, y0}, color, {u1, v0}, glyph, effect, UI_DEFAULT_MATERIAL},
		{{x1, y1}, color, {u1, v1}, glyph, effect, UI_DEFAULT_MATERIAL},
		{{x0, y0}, color, {u0, v0}, glyph, effect, UI_DEFAULT_MATERIAL},
		{{x1, y1}, color, {u1, v1}, glyph, effect, UI_DEFAULT_MATERIAL},
		{{x0, y1}, color, {u0, v1}, glyph, effect, UI_DEFAULT_MATERIAL},
	}
	for vertex in verts {
		out[count^] = vertex
		count^ += 1
	}
}

ui_push_refractive_glass_rect :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, style: uifw.Gui_Glass_Style, scissor: uifw.Rect, extent: vk.Extent2D) {
	if count^ + 6 > UI_MAX_VERTICES {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}

	u0 := (clipped.x - rect.x) / max(rect.w, 0.00001)
	v0 := (clipped.y - rect.y) / max(rect.h, 0.00001)
	u1 := (clipped.x + clipped.w - rect.x) / max(rect.w, 0.00001)
	v1 := (clipped.y + clipped.h - rect.y) / max(rect.h, 0.00001)

	x0 := ui_screen_to_ndc_x(clipped.x, extent.width)
	y0 := ui_screen_to_ndc_y(clipped.y, extent.height)
	x1 := ui_screen_to_ndc_x(clipped.x + clipped.w, extent.width)
	y1 := ui_screen_to_ndc_y(clipped.y + clipped.h, extent.height)

	radius := min(max(style.radius, 0), min(rect.w, rect.h) * 0.5)
	thickness := max(style.thickness, f32(0))
	roughness := min(max(style.roughness, 0), 1)
	bevel := max(style.bevel, f32(0))
	ior := max(style.ior, f32(1.0))
	dispersion := max(style.dispersion, f32(0))
	border := min(max(style.border, 0), 1)
	highlight := min(max(style.highlight, 0), 1)
	effect := uifw.Color{thickness, roughness, bevel, radius}
	material := uifw.Color{ior, dispersion, border, highlight}
	color := style.tint

	verts := [?]Ui_Vertex {
		{{x0, y0}, color, {u0, v0}, UI_GLASS_GLYPH, effect, material},
		{{x1, y0}, color, {u1, v0}, UI_GLASS_GLYPH, effect, material},
		{{x1, y1}, color, {u1, v1}, UI_GLASS_GLYPH, effect, material},
		{{x0, y0}, color, {u0, v0}, UI_GLASS_GLYPH, effect, material},
		{{x1, y1}, color, {u1, v1}, UI_GLASS_GLYPH, effect, material},
		{{x0, y1}, color, {u0, v1}, UI_GLASS_GLYPH, effect, material},
	}
	for vertex in verts {
		out[count^] = vertex
		count^ += 1
	}
}

ui_ellipse_points :: proc(points: []uifw.Vec2, rect: uifw.Rect) -> int {
	unit := [?]uifw.Vec2 {
		{1.0000, 0.0000},
		{0.9808, 0.1951},
		{0.9239, 0.3827},
		{0.8315, 0.5556},
		{0.7071, 0.7071},
		{0.5556, 0.8315},
		{0.3827, 0.9239},
		{0.1951, 0.9808},
		{0.0000, 1.0000},
		{-0.1951, 0.9808},
		{-0.3827, 0.9239},
		{-0.5556, 0.8315},
		{-0.7071, 0.7071},
		{-0.8315, 0.5556},
		{-0.9239, 0.3827},
		{-0.9808, 0.1951},
		{-1.0000, 0.0000},
		{-0.9808, -0.1951},
		{-0.9239, -0.3827},
		{-0.8315, -0.5556},
		{-0.7071, -0.7071},
		{-0.5556, -0.8315},
		{-0.3827, -0.9239},
		{-0.1951, -0.9808},
		{0.0000, -1.0000},
		{0.1951, -0.9808},
		{0.3827, -0.9239},
		{0.5556, -0.8315},
		{0.7071, -0.7071},
		{0.8315, -0.5556},
		{0.9239, -0.3827},
		{0.9808, -0.1951},
	}
	center := uifw.Vec2{rect.x + rect.w * 0.5, rect.y + rect.h * 0.5}
	rx := rect.w * 0.5
	ry := rect.h * 0.5
	count := min(len(points), len(unit))
	for i in 0 ..< count {
		points[i] = {center.x + unit[i].x * rx, center.y + unit[i].y * ry}
	}
	return count
}

ui_rounded_rect_points :: proc(points: []uifw.Vec2, rect: uifw.Rect, radius: f32) -> int {
	r := min(max(radius, 0), min(rect.w, rect.h) * 0.5)
	corners := [?]uifw.Vec2 {
		{rect.x + rect.w - r, rect.y + r},
		{rect.x + rect.w - r, rect.y + rect.h - r},
		{rect.x + r, rect.y + rect.h - r},
		{rect.x + r, rect.y + r},
	}
	offsets := [?][5]uifw.Vec2 {
		{
			{0.0000, -1.0000},
			{0.3827, -0.9239},
			{0.7071, -0.7071},
			{0.9239, -0.3827},
			{1.0000, 0.0000},
		},
		{
			{1.0000, 0.0000},
			{0.9239, 0.3827},
			{0.7071, 0.7071},
			{0.3827, 0.9239},
			{0.0000, 1.0000},
		},
		{
			{0.0000, 1.0000},
			{-0.3827, 0.9239},
			{-0.7071, 0.7071},
			{-0.9239, 0.3827},
			{-1.0000, 0.0000},
		},
		{
			{-1.0000, 0.0000},
			{-0.9239, -0.3827},
			{-0.7071, -0.7071},
			{-0.3827, -0.9239},
			{0.0000, -1.0000},
		},
	}
	count := 0
	for corner_index in 0 ..< 4 {
		for step in 0 ..< 5 {
			if count >= len(points) {
				return count
			}
			u := offsets[corner_index][step]
			points[count] = {corners[corner_index].x + u.x * r, corners[corner_index].y + u.y * r}
			count += 1
		}
	}
	return count
}

ui_text_shape_cache_hash :: proc(font_kind: uifw.Gui_Font_Kind, bytes: []u8, scale: f32) -> u64 {
	hash := u64(14695981039346656037)
	hash = (hash ~ u64(font_kind)) * 1099511628211
	for ch in bytes {
		hash = (hash ~ u64(ch)) * 1099511628211
	}
	scale_bits := transmute(u32)scale
	for shift := 0; shift < 32; shift += 8 {
		hash = (hash ~ u64((scale_bits >> u32(shift)) & 0xff)) * 1099511628211
	}
	return hash
}

ui_text_shape_cache_matches :: proc(entry: ^Ui_Text_Shape_Cache_Entry, hash: u64, font_kind: uifw.Gui_Font_Kind, bytes: []u8, scale: f32) -> bool {
	if entry.glyph_count == 0 || entry.hash != hash || entry.scale != scale || entry.font_kind != font_kind || int(entry.text_len) != len(bytes) {
		return false
	}
	for i in 0 ..< len(bytes) {
		if entry.text[i] != bytes[i] {
			return false
		}
	}
	return true
}

ui_text_shape_cache_get :: proc(renderer: ^Ui_Renderer, font_kind: uifw.Gui_Font_Kind, bytes: []u8, scale: f32) -> ^Ui_Text_Shape_Cache_Entry {
	if renderer == nil || len(renderer.text_shape_cache) == 0 || len(bytes) == 0 || len(bytes) > UI_TEXT_SHAPE_CACHE_MAX_BYTES {
		return nil
	}
	hash := ui_text_shape_cache_hash(font_kind, bytes, scale)
	renderer.text_shape_generation += 1
	if renderer.text_shape_generation == 0 {
		renderer.text_shape_generation = 1
		for i in 0 ..< len(renderer.text_shape_cache) {
			renderer.text_shape_cache[i].generation = 0
		}
	}
	for i in 0 ..< len(renderer.text_shape_cache) {
		entry := &renderer.text_shape_cache[i]
		if ui_text_shape_cache_matches(entry, hash, font_kind, bytes, scale) {
			entry.generation = renderer.text_shape_generation
			return entry
		}
	}

	return nil
}

ui_text_shape_cache_store :: proc(renderer: ^Ui_Renderer, font_kind: uifw.Gui_Font_Kind, bytes: []u8, scale: f32, shaped: []uifw.Gui_Shaped_Glyph) {
	if renderer == nil || len(renderer.text_shape_cache) == 0 || len(bytes) == 0 || len(bytes) > UI_TEXT_SHAPE_CACHE_MAX_BYTES || len(shaped) == 0 || len(shaped) > UI_TEXT_SHAPE_CACHE_MAX_GLYPHS {
		return
	}
	hash := ui_text_shape_cache_hash(font_kind, bytes, scale)
	oldest := 0
	oldest_generation := renderer.text_shape_cache[0].generation
	for i in 0 ..< len(renderer.text_shape_cache) {
		entry := &renderer.text_shape_cache[i]
		if ui_text_shape_cache_matches(entry, hash, font_kind, bytes, scale) {
			entry.generation = renderer.text_shape_generation
			return
		}
		if entry.glyph_count == 0 {
			oldest = i
			break
		}
		if entry.generation < oldest_generation {
			oldest = i
			oldest_generation = entry.generation
		}
	}

	entry := &renderer.text_shape_cache[oldest]
	if renderer.text_shape_generation == 0 {
		renderer.text_shape_generation = 1
	}
	entry.hash = hash
	entry.generation = renderer.text_shape_generation
	entry.text_len = u16(len(bytes))
	entry.scale = scale
	entry.font_kind = font_kind
	entry.glyph_count = u16(len(shaped))
	copy(entry.text[:], bytes)
	copy(entry.glyphs[:], shaped)
}

ui_push_text :: proc(renderer: ^Ui_Renderer, out: [^]Ui_Vertex, count: ^int, command: uifw.Draw_Command, scissor: uifw.Rect, extent: vk.Extent2D, atlas: ^Ui_Font_Atlas_Cache_Entry) {
	if len(command.text) == 0 {
		return
	}
	bytes := transmute([]u8)command.text
	scale := command.text_scale
	if scale <= 0 {
		scale = 1
	}
	char_w := ui_text_glyph_quad_width(atlas, scale)
	advance_w := f32(UI_FONT_LOGICAL_WIDTH) * scale
	char_h := f32(UI_FONT_LOGICAL_HEIGHT) * scale
	gap := f32(0)
	x := command.rect.x
	y := command.rect.y
	shaped: []uifw.Gui_Shaped_Glyph
	shaped_count := 0
	direct_shaped: [UI_MAX_SHAPED_GLYPHS]uifw.Gui_Shaped_Glyph
	if renderer != nil {
		cache_entry := ui_text_shape_cache_get(renderer, command.font_kind, bytes, scale)
		if cache_entry != nil {
			shaped_count = int(cache_entry.glyph_count)
			shaped = cache_entry.glyphs[:shaped_count]
		}
	}
	if shaped_count == 0 {
		direct_count := uifw.gui_font_shape_text(command.font_kind, bytes, scale, direct_shaped[:])
		if direct_count > 0 {
			shaped_count = direct_count
			shaped = direct_shaped[:shaped_count]
			ui_text_shape_cache_store(renderer, command.font_kind, bytes, scale, shaped)
		}
	}
	if command.text_align == .Center {
		text_w := uifw.gui_font_text_width(command.font_kind, bytes, scale, advance_w)
		x = command.rect.x + max((command.rect.w - text_w) * 0.5, 0)
	} else if command.text_align == .Right {
		text_w := uifw.gui_font_text_width(command.font_kind, bytes, scale, advance_w)
		x = command.rect.x + max(command.rect.w - text_w, 0)
	}

	if shaped_count > 0 {
		cursor_x := x
		for glyph in shaped[:shaped_count] {
			slot := uifw.gui_font_glyph_slot(glyph.glyph_id)
			if slot >= 0 {
				ui_push_text_glyph(
					out,
					count,
					{cursor_x + glyph.x_offset, y - glyph.y_offset, char_w, char_h},
					command.color,
					f32(slot),
					scissor,
					extent,
					ui_font_atlas_uv(atlas, int(slot)),
				)
			}
			cursor_x += glyph.x_advance
		}
		return
	}

	cursor_x := x
	for ch in bytes {
		if ch < UI_FONT_GLYPH_FIRST || ch > UI_FONT_GLYPH_FIRST + UI_FONT_GLYPH_COUNT - 1 {
			cursor_x += advance_w + gap
			continue
		}
		if ch == ' ' {
			cursor_x += uifw.gui_font_glyph_advance(command.font_kind, ch, scale, advance_w) + gap
			continue
		}
		slot := int(ch - UI_FONT_GLYPH_FIRST)
		ui_push_text_glyph(out, count, {cursor_x, y, char_w, char_h}, command.color, f32(slot), scissor, extent, ui_font_atlas_uv(atlas, slot))
		cursor_x += uifw.gui_font_glyph_advance(command.font_kind, ch, scale, advance_w) + gap
	}
}

ui_push_clear_text_placeholder :: proc(out: []Ui_Clear_Rect, count: ^int, command: uifw.Draw_Command, scissor: uifw.Rect) {
	if len(command.text) == 0 {
		return
	}
	scale := command.text_scale
	if scale <= 0 {
		scale = 1
	}
	char_w := f32(UI_FONT_ATLAS_LOGICAL_WIDTH) * scale
	advance_w := f32(UI_FONT_LOGICAL_WIDTH) * scale
	char_h := f32(UI_FONT_LOGICAL_HEIGHT) * scale
	gap := f32(0)
	x := command.rect.x
	y := command.rect.y
	if command.text_align == .Center {
		text_w := uifw.gui_font_text_width(command.font_kind, transmute([]u8)command.text, scale, advance_w)
		x = command.rect.x + max((command.rect.w - text_w) * 0.5, 0)
	} else if command.text_align == .Right {
		text_w := uifw.gui_font_text_width(command.font_kind, transmute([]u8)command.text, scale, advance_w)
		x = command.rect.x + max(command.rect.w - text_w, 0)
	}

	shaped: [UI_MAX_SHAPED_GLYPHS]uifw.Gui_Shaped_Glyph
	shaped_count := uifw.gui_font_shape_text(command.font_kind, transmute([]u8)command.text, scale, shaped[:])
	if shaped_count > 0 {
		cursor_x := x
		for glyph in shaped[:shaped_count] {
			slot := uifw.gui_font_glyph_slot(glyph.glyph_id)
			if slot >= 0 {
				ui_push_clear_rect(out, count, {cursor_x + glyph.x_offset, y - glyph.y_offset, char_w, char_h}, command.color, scissor)
			}
			cursor_x += glyph.x_advance
		}
		return
	}

	cursor_x := x
	for ch in transmute([]u8)command.text {
		if ch < UI_FONT_GLYPH_FIRST || ch > UI_FONT_GLYPH_FIRST + UI_FONT_GLYPH_COUNT - 1 {
			cursor_x += char_w + gap
			continue
		}
		if ch == ' ' {
			cursor_x += uifw.gui_font_glyph_advance(command.font_kind, ch, scale, char_w) + gap
			continue
		}
		ui_push_clear_rect(out, count, {cursor_x, y, char_w, char_h}, command.color, scissor)
		cursor_x += uifw.gui_font_glyph_advance(command.font_kind, ch, scale, advance_w) + gap
	}
}

ui_text_glyph_quad_width :: proc(atlas: ^Ui_Font_Atlas_Cache_Entry, scale: f32) -> f32 {
	if atlas != nil && atlas.cell_width > 0 && atlas.cell_height > 0 {
		return f32(atlas.cell_width) * f32(UI_FONT_LOGICAL_HEIGHT) * scale / f32(atlas.cell_height)
	}
	return f32(UI_FONT_ATLAS_LOGICAL_WIDTH) * scale
}

ui_push_text_glyph :: proc(
	out: [^]Ui_Vertex,
	count: ^int,
	rect: uifw.Rect,
	color: uifw.Color,
	glyph: f32,
	scissor: uifw.Rect,
	extent: vk.Extent2D,
	uv_rect: uifw.Rect,
) {
	if count^ + 6 > UI_MAX_VERTICES {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	clip_x0 := ui_screen_to_ndc_x(clipped.x, extent.width)
	clip_y0 := ui_screen_to_ndc_y(clipped.y, extent.height)
	clip_x1 := ui_screen_to_ndc_x(clipped.x + clipped.w, extent.width)
	clip_y1 := ui_screen_to_ndc_y(clipped.y + clipped.h, extent.height)

	local_u0 := (clipped.x - rect.x) / max(rect.w, 0.00001)
	local_v0 := (clipped.y - rect.y) / max(rect.h, 0.00001)
	local_u1 := (clipped.x + clipped.w - rect.x) / max(rect.w, 0.00001)
	local_v1 := (clipped.y + clipped.h - rect.y) / max(rect.h, 0.00001)
	u0 := uv_rect.x + local_u0 * uv_rect.w
	v0 := uv_rect.y + local_v0 * uv_rect.h
	u1 := uv_rect.x + local_u1 * uv_rect.w
	v1 := uv_rect.y + local_v1 * uv_rect.h

	verts := [?]Ui_Vertex {
		{{clip_x0, clip_y0}, color, {u0, v0}, glyph, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{clip_x1, clip_y0}, color, {u1, v0}, glyph, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{clip_x1, clip_y1}, color, {u1, v1}, glyph, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{clip_x0, clip_y0}, color, {u0, v0}, glyph, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{clip_x1, clip_y1}, color, {u1, v1}, glyph, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{clip_x0, clip_y1}, color, {u0, v1}, glyph, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
	}
	for vertex in verts {
		out[count^] = vertex
		count^ += 1
	}
}

ui_font_atlas_uv :: proc(atlas: ^Ui_Font_Atlas_Cache_Entry, slot: int) -> uifw.Rect {
	if atlas == nil || !atlas.ready || atlas.atlas_width == 0 || atlas.atlas_height == 0 || atlas.columns == 0 {
		return {0, 0, 1, 1}
	}
	s := max(slot, 0)
	col := u32(s) % atlas.columns
	row := u32(s) / atlas.columns
	inset_u := f32(0.5) / f32(atlas.atlas_width)
	inset_v := f32(0.5) / f32(atlas.atlas_height)
	u0 := f32(col * atlas.cell_width) / f32(atlas.atlas_width) + inset_u
	v0 := f32(row * atlas.cell_height) / f32(atlas.atlas_height) + inset_v
	u1 := f32(col * atlas.cell_width + atlas.cell_width) / f32(atlas.atlas_width) - inset_u
	v1 := f32(row * atlas.cell_height + atlas.cell_height) / f32(atlas.atlas_height) - inset_v
	return {u0, v0, max(u1 - u0, 0), max(v1 - v0, 0)}
}

ui_push_clear_rect :: proc(out: []Ui_Clear_Rect, count: ^int, rect: uifw.Rect, color: uifw.Color, scissor: uifw.Rect) {
	if count^ >= len(out) {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	out[count^] = {rect = clipped, color = color}
	count^ += 1
}

ui_push_rect :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, color: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	if count^ + 6 > UI_MAX_VERTICES {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}

	x0 := ui_screen_to_ndc_x(clipped.x, extent.width)
	y0 := ui_screen_to_ndc_y(clipped.y, extent.height)
	x1 := ui_screen_to_ndc_x(clipped.x + clipped.w, extent.width)
	y1 := ui_screen_to_ndc_y(clipped.y + clipped.h, extent.height)

	verts := [?]Ui_Vertex {
		{{x0, y0}, color, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{x1, y0}, color, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{x1, y1}, color, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{x0, y0}, color, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{x1, y1}, color, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{x0, y1}, color, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
	}
	for vertex in verts {
		out[count^] = vertex
		count^ += 1
	}
}

ui_push_triangle_screen :: proc(
	out: [^]Ui_Vertex,
	count: ^int,
	a, b, c: uifw.Vec2,
	color_a, color_b, color_c: uifw.Color,
	extent: vk.Extent2D,
) {
	if count^ + 3 > UI_MAX_VERTICES {
		return
	}
	out[count^] = {{ui_screen_to_ndc_x(a.x, extent.width), ui_screen_to_ndc_y(a.y, extent.height)}, color_a, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL}
	count^ += 1
	out[count^] = {{ui_screen_to_ndc_x(b.x, extent.width), ui_screen_to_ndc_y(b.y, extent.height)}, color_b, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL}
	count^ += 1
	out[count^] = {{ui_screen_to_ndc_x(c.x, extent.width), ui_screen_to_ndc_y(c.y, extent.height)}, color_c, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL}
	count^ += 1
}

ui_color_lerp :: proc(a, b: uifw.Color, t: f32) -> uifw.Color {
	x := min(max(t, 0), 1)
	return {
		a.r + (b.r - a.r) * x,
		a.g + (b.g - a.g) * x,
		a.b + (b.b - a.b) * x,
		a.a + (b.a - a.a) * x,
	}
}

ui_screen_to_ndc_x :: proc(x: f32, width: u32) -> f32 {
	return x / f32(max(width, 1)) * 2 - 1
}

ui_screen_to_ndc_y :: proc(y: f32, height: u32) -> f32 {
	return y / f32(max(height, 1)) * 2 - 1
}

ui_rect_intersection :: proc(a, b: uifw.Rect) -> uifw.Rect {
	x0 := max(a.x, b.x)
	y0 := max(a.y, b.y)
	x1 := min(a.x + a.w, b.x + b.w)
	y1 := min(a.y + a.h, b.y + b.h)
	return {x0, y0, max(x1 - x0, 0), max(y1 - y0, 0)}
}
