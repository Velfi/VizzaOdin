package render_vk

import uifw "../ui"
import engine "../engine"

import "core:math"
import "core:time"
import vk "vendor:vulkan"

MAX_RENDER_GRAPH_PASSES :: 16
MAX_RENDER_GRAPH_RESOURCES :: 32
MAX_RENDER_GRAPH_DEPENDENCIES :: 8
MAX_RENDER_GRAPH_BARRIERS :: 64
SCREENSHOT_REFRESH_INTERVAL_FRAMES :: u64(15)
MAIN_MENU_SIM_PREVIEW_WIDTH :: u32(192)
MAIN_MENU_SIM_PREVIEW_HEIGHT :: u32(128)
MAIN_MENU_SIM_PREVIEW_MAX_WIDTH :: u32(640)
MAIN_MENU_SIM_PREVIEW_MAX_HEIGHT :: u32(360)
SIMULATION_MAX_SUBSTEP_SECONDS :: f32(1.0 / 120.0)
SIMULATION_MAX_FRAME_SECONDS :: f32(0.1)
SIMULATION_MAX_SUBSTEPS :: 12

Simulation_Substeps :: struct {
	count: int,
	delta_time: f32,
}

// Split elapsed real time into equal, bounded integration steps. Equal steps
// are intentional: GPU commands recorded in one frame share the frame's mapped
// parameter buffer, so every dispatch must use the same delta time.
simulation_substeps :: proc(frame_dt: f32) -> Simulation_Substeps {
	clamped_dt := min(max(frame_dt, 0), SIMULATION_MAX_FRAME_SECONDS)
	if clamped_dt <= 0 {
		return {}
	}
	count := int(math.ceil(clamped_dt / SIMULATION_MAX_SUBSTEP_SECONDS))
	count = min(max(count, 1), SIMULATION_MAX_SUBSTEPS)
	return {count = count, delta_time = clamped_dt / f32(count)}
}

particle_life_simulation_substeps :: proc(frame_dt: f32, particle_count: u32) -> Simulation_Substeps {
	steps := simulation_substeps(frame_dt)
	// Catch-up work must not create a feedback loop where a slow force frame
	// schedules still more complete force frames. Keep the same stable substep
	// size and shed excess elapsed simulation time for large populations.
	max_steps := SIMULATION_MAX_SUBSTEPS
	if particle_count >= 100_000 {
		max_steps = 2
	} else if particle_count >= 50_000 {
		max_steps = 4
	}
	steps.count = min(steps.count, max_steps)
	return steps
}

// Pellets performs several full-grid neighbor passes per integration step.
// Never turn a slow rendered frame into more GPU work on the next frame: shed
// excess elapsed time and keep the single step at the established stable size.
pellets_simulation_substeps :: proc(frame_dt: f32) -> Simulation_Substeps {
	clamped_dt := min(max(frame_dt, 0), SIMULATION_MAX_SUBSTEP_SECONDS)
	if clamped_dt <= 0 do return {}
	return {count = 1, delta_time = clamped_dt}
}

primordial_simulation_substeps :: proc(frame_dt: f32, particle_count: u32) -> Simulation_Substeps {
	steps := simulation_substeps(frame_dt)
	max_steps := SIMULATION_MAX_SUBSTEPS
	if particle_count >= 100_000 {
		max_steps = 1
	} else if particle_count >= 50_000 {
		max_steps = 2
	}
	if steps.count > max_steps {
		total_dt := steps.delta_time * f32(steps.count)
		steps.count = max_steps
		steps.delta_time = total_dt / f32(max_steps)
	}
	return steps
}

simulation_frame_delta :: proc(frame_dt: f32) -> f32 {
	return min(max(frame_dt, 0), SIMULATION_MAX_FRAME_SECONDS)
}

Render_Resource_Kind :: enum {
	Swapchain_Color,
	Storage_Image,
	Sampled_Image,
	Vertex_Buffer,
	Index_Buffer,
}

Render_Pass_Side_Effect :: enum u8 {
	Acquire,
	Present,
	Video_Capture_Point,
	Screenshot_Capture_Point,
	External,
	Refresh_Imported_Resources,
}

Render_Pass_Side_Effects :: bit_set[Render_Pass_Side_Effect; u8]

Render_Resource_Handle :: distinct int

Render_Resource_Access :: enum u8 {
	Read,
	Write,
	Read_Write,
}

Render_Subresource_Range :: struct {
	base_mip_level: u32,
	level_count: u32,
	base_array_layer: u32,
	layer_count: u32,
}

Render_Resource_Use :: struct {
	resource: Render_Resource_Handle,
	access: Render_Resource_Access,
	stage: vk.PipelineStageFlags2,
	access_mask: vk.AccessFlags2,
	layout: vk.ImageLayout,
	subresource: Render_Subresource_Range,
}

Render_Graph_Barrier :: struct {
	resource: Render_Resource_Handle,
	producer_pass: int,
	consumer_pass: int,
	src_stage: vk.PipelineStageFlags2,
	src_access: vk.AccessFlags2,
	dst_stage: vk.PipelineStageFlags2,
	dst_access: vk.AccessFlags2,
	old_layout: vk.ImageLayout,
	new_layout: vk.ImageLayout,
}

Render_Graph_Transient_Barrier :: struct {
	resource: Render_Resource_Handle,
	previous_resource: Render_Resource_Handle,
	consumer_pass: int,
	src_stage: vk.PipelineStageFlags2,
	src_access: vk.AccessFlags2,
	dst_stage: vk.PipelineStageFlags2,
	dst_access: vk.AccessFlags2,
	old_layout: vk.ImageLayout,
	new_layout: vk.ImageLayout,
}

Render_Graph_Compile_Error :: enum u8 {
	None,
	Invalid_Resource,
	Invalid_Dependency,
	Cycle,
	Barrier_Capacity,
}

Render_Resource :: struct {
	name: string,
	feature_mode: App_Mode,
	feature_owned: bool,
	kind: Render_Resource_Kind,
	format: vk.Format,
	width: u32,
	height: u32,
	depth: u32,
	byte_size: u64,
	usage: u64,
	image_layout: vk.ImageLayout,
	stage: vk.PipelineStageFlags2,
	access: vk.AccessFlags2,
	transient: bool,
	external: bool,
}

Render_Imported_Resource_Binding :: struct {
	valid: bool,
	image: vk.Image,
	buffer: vk.Buffer,
	observed_layout: vk.ImageLayout,
	observed_stage: vk.PipelineStageFlags2,
	observed_access: vk.AccessFlags2,
}

Render_Graph_Diagnostics :: struct {
	compiled: bool,
	compile_error: Render_Graph_Compile_Error,
	pass_count: int,
	resource_count: int,
	barrier_count: int,
	transient_barrier_count: int,
	physical_slot_count: int,
	disabled_pass_count: int,
	physical_allocation_count: u64,
	physical_reuse_count: u64,
	disabled_passes: [MAX_RENDER_GRAPH_PASSES]int,
	compiled_order: [MAX_RENDER_GRAPH_PASSES]int,
	resource_first_use: [MAX_RENDER_GRAPH_RESOURCES]int,
	resource_last_use: [MAX_RENDER_GRAPH_RESOURCES]int,
	resource_physical_slot: [MAX_RENDER_GRAPH_RESOURCES]int,
}

Render_Pass_Execute :: proc(ctx: ^Render_Context, pass: ^Render_Pass_Node) -> bool

Render_Pass_Node :: struct {
	name: string,
	enabled: bool,
	side_effects: Render_Pass_Side_Effects,
	reads: [16]Render_Resource_Handle,
	read_count: int,
	writes: [16]Render_Resource_Handle,
	write_count: int,
	uses: [16]Render_Resource_Use,
	use_count: int,
	depends_on: [MAX_RENDER_GRAPH_DEPENDENCIES]int,
	dependency_count: int,
	execute: Render_Pass_Execute,
}

Render_Graph :: struct {
	resources: [MAX_RENDER_GRAPH_RESOURCES]Render_Resource,
	resource_count: int,
	passes: [MAX_RENDER_GRAPH_PASSES]Render_Pass_Node,
	pass_count: int,
	compiled_order: [MAX_RENDER_GRAPH_PASSES]int,
	compiled_count: int,
	edges: [MAX_RENDER_GRAPH_PASSES][MAX_RENDER_GRAPH_PASSES]bool,
	resource_first_use: [MAX_RENDER_GRAPH_RESOURCES]int,
	resource_last_use: [MAX_RENDER_GRAPH_RESOURCES]int,
	resource_physical_slot: [MAX_RENDER_GRAPH_RESOURCES]int,
	physical_slot_count: int,
	barriers: [MAX_RENDER_GRAPH_BARRIERS]Render_Graph_Barrier,
	barrier_count: int,
	transient_barriers: [MAX_RENDER_GRAPH_RESOURCES]Render_Graph_Transient_Barrier,
	transient_barrier_count: int,
	compile_error: Render_Graph_Compile_Error,
	compiled: bool,
}

Render_Graph_Structural_Key :: struct {
	mode: App_Mode,
	preview_count: u32,
	preview_mode_mask: u32,
	capture_active: bool,
	target_format: vk.Format,
}

render_graph_preview_mode_mask :: proc(app_ui: ^App_Ui_State) -> u32 {
	if app_ui == nil do return 0
	mask: u32
	count := min(app_ui.main_menu_preview_slot_count, len(app_ui.main_menu_preview_slots))
	for i in 0 ..< count {
		mode_index := int(app_ui.main_menu_preview_slots[i].mode)
		if mode_index >= 0 && mode_index < 32 do mask |= u32(1) << u32(mode_index)
	}
	return mask
}

Render_Graph_Cache :: struct {
	graph: Render_Graph,
	key: Render_Graph_Structural_Key,
	valid: bool,
	compile_count: u64,
}

Render_Transient_Image :: struct {
	handle: vk.Image,
	view: vk.ImageView,
	memory: vk.DeviceMemory,
}

Render_Backend :: struct {
	ui: Ui_Renderer,
	post_processing: Post_Processing_Gpu_State,
	main_menu_backdrop: Main_Menu_Backdrop_Gpu_State,
	graph_cache: Render_Graph_Cache,
	transient_buffers: [MAX_RENDER_GRAPH_RESOURCES]engine.Vk_Buffer,
	transient_images: [MAX_RENDER_GRAPH_RESOURCES]Render_Transient_Image,
	transient_buffer_resources: [MAX_RENDER_GRAPH_RESOURCES]Render_Resource,
	transient_buffer_valid: [MAX_RENDER_GRAPH_RESOURCES]bool,
	transient_allocation_count: u64,
	transient_reuse_count: u64,
	capture_readback_buffers: [2][engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	capture_readback_allocation_count: u64,
	capture_readback_reuse_count: u64,
	last_ui_build_seconds: f64,
	last_ui_overlay_seconds: f64,
	last_submit_seconds: f64,
	last_screenshot_seconds: f64,
	gpu_profiling_supported: bool,
	gpu_profiling_enabled: bool,
	last_gpu_simulation_step_ms: f64,
	last_gpu_simulation_present_ms: f64,
	last_gpu_ui_overlay_ms: f64,
	last_gpu_frame_total_ms: f64,
	last_gpu_pellets_grid_clear_ms: f64,
	last_gpu_pellets_grid_build_ms: f64,
	last_gpu_pellets_grid_scatter_ms: f64,
	last_gpu_pellets_physics_ms: f64,
	last_gpu_pellets_density_ms: f64,
	last_gpu_pellets_particle_draw_ms: f64,
	last_cpu_wait_fence_ms: f64,
	last_cpu_acquire_ms: f64,
	last_cpu_command_begin_ms: f64,
	last_cpu_end_command_ms: f64,
	last_cpu_queue_submit_ms: f64,
	last_cpu_queue_present_ms: f64,
	present_mode: string,
	last_command_render_pass_count: u32,
	last_command_compute_dispatch_count: u32,
	last_command_draw_count: u32,
	last_command_pipeline_bind_count: u32,
	last_command_descriptor_bind_count: u32,
	last_command_pipeline_barrier_count: u32,
	last_command_transfer_copy_count: u32,
	last_command_ui_batch_count: u32,
	last_command_backdrop_blur_pass_count: u32,
	last_main_menu_preview_visible_slot_count: u32,
	last_main_menu_preview_warmed_mode_count: u32,
	last_main_menu_preview_fallback_fill_count: u32,
	last_main_menu_preview_skipped_present_count: u32,
	last_screenshot_captured: bool,
	last_app_mode: App_Mode,
	last_app_mode_valid: bool,
	initialized: bool,
}

render_backend_ui_sink :: proc(backend: ^Render_Backend) -> Ui_Render_Sink {
	return {userdata = &backend.ui, draw = render_backend_ui_sink_draw}
}

render_backend_ui_sink_draw :: proc(data: rawptr, vk_ctx: ^engine.Vk_Context, command_buffer: vk.CommandBuffer, extent: vk.Extent2D) {
	ui_renderer_draw(cast(^Ui_Renderer)data, vk_ctx, command_buffer, extent)
}

Render_Context :: struct {
	vk_ctx: ^engine.Vk_Context,
	backend: ^Render_Backend,
	frame: engine.Vk_Frame,
	gui: ^uifw.Gui_Context,
	feature_instances: ^Render_Feature_Instance_Set,
	app_ui: ^App_Ui_State,
	dt: f32,
	app_mode: App_Mode,
	frame_index: u64,
	video_capture: ^Video_Capture_Sink,
	video_capture_readback: engine.Vk_Buffer,
	video_capture_readback_ready: bool,
	video_capture_frame_reserved: bool,
	video_capture_frame_index: int,
	screenshot: ^engine.Screenshot_State,
	screenshot_requested: bool,
	screenshot_readback: engine.Vk_Buffer,
	screenshot_readback_ready: bool,
	imported_resources: [MAX_RENDER_GRAPH_RESOURCES]Render_Imported_Resource_Binding,
}

render_backend_init :: proc(backend: ^Render_Backend, ctx: ^engine.Vk_Context) -> bool {
	backend^ = {}
	startup_seed := u64(time.duration_nanoseconds(time.diff(time.Time{}, time.now())))
	main_menu_backdrop_seed_palette(&backend.main_menu_backdrop, startup_seed)
	if !ui_renderer_init(&backend.ui, ctx) {
		return false
	}
	backend.initialized = true
	return true
}

render_backend_destroy :: proc(backend: ^Render_Backend, ctx: ^engine.Vk_Context) {
	if backend.initialized {
		for slot in 0 ..< len(backend.transient_buffers) {
			if backend.transient_buffer_valid[slot] {
				if backend.transient_buffer_resources[slot].kind == .Storage_Image || backend.transient_buffer_resources[slot].kind == .Sampled_Image {
					render_transient_image_destroy(ctx, &backend.transient_images[slot])
				} else {
					engine.vk_destroy_buffer(ctx, &backend.transient_buffers[slot])
				}
			}
		}
		for &kind_buffers in backend.capture_readback_buffers {
			for &buffer in kind_buffers do engine.vk_destroy_buffer(ctx, &buffer)
		}
		main_menu_backdrop_destroy(&backend.main_menu_backdrop, ctx)
		post_processing_gpu_destroy(&backend.post_processing, ctx)
		ui_renderer_destroy(&backend.ui, ctx)
	}
	backend^ = {}
}

render_transient_image_destroy :: proc(vk_ctx: ^engine.Vk_Context, image: ^Render_Transient_Image) {
	if vk_ctx == nil || image == nil do return
	if image.view != vk.ImageView(0) do vk.DestroyImageView(vk_ctx.device, image.view, nil)
	if image.handle != vk.Image(0) do vk.DestroyImage(vk_ctx.device, image.handle, nil)
	if image.memory != vk.DeviceMemory(0) do vk.FreeMemory(vk_ctx.device, image.memory, nil)
	image^ = {}
}

render_transient_image_create :: proc(vk_ctx: ^engine.Vk_Context, resource: ^Render_Resource, out: ^Render_Transient_Image) -> bool {
	if vk_ctx == nil || resource == nil || out == nil || resource.format == .UNDEFINED || resource.width == 0 || resource.height == 0 do return false
	out^ = {}
	usage: vk.ImageUsageFlags = {.STORAGE, .SAMPLED, .TRANSFER_SRC, .TRANSFER_DST}
	info := vk.ImageCreateInfo{sType = .IMAGE_CREATE_INFO, imageType = .D2, format = resource.format, extent = {resource.width, resource.height, max(resource.depth, 1)}, mipLevels = 1, arrayLayers = 1, samples = {._1}, tiling = .OPTIMAL, usage = usage, sharingMode = .EXCLUSIVE, initialLayout = .UNDEFINED}
	if vk.CreateImage(vk_ctx.device, &info, nil, &out.handle) != .SUCCESS do return false
	requirements: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device, out.handle, &requirements)
	memory_type, found := engine.vk_find_memory_type(vk_ctx, requirements.memoryTypeBits, {.DEVICE_LOCAL})
	if !found {render_transient_image_destroy(vk_ctx, out); return false}
	allocation := vk.MemoryAllocateInfo{sType = .MEMORY_ALLOCATE_INFO, allocationSize = requirements.size, memoryTypeIndex = memory_type}
	if vk.AllocateMemory(vk_ctx.device, &allocation, nil, &out.memory) != .SUCCESS {render_transient_image_destroy(vk_ctx, out); return false}
	if vk.BindImageMemory(vk_ctx.device, out.handle, out.memory, 0) != .SUCCESS {render_transient_image_destroy(vk_ctx, out); return false}
	view_info := vk.ImageViewCreateInfo{sType = .IMAGE_VIEW_CREATE_INFO, image = out.handle, viewType = .D2, format = resource.format, subresourceRange = {aspectMask = {.COLOR}, baseMipLevel = 0, levelCount = 1, baseArrayLayer = 0, layerCount = 1}}
	if vk.CreateImageView(vk_ctx.device, &view_info, nil, &out.view) != .SUCCESS {render_transient_image_destroy(vk_ctx, out); return false}
	return true
}

render_backend_bind_transient_resources :: proc(backend: ^Render_Backend, vk_ctx: ^engine.Vk_Context, graph: ^Render_Graph, ctx: ^Render_Context) -> bool {
	if backend == nil || vk_ctx == nil || graph == nil || ctx == nil do return false
	for resource_index in 0 ..< graph.resource_count {
		resource := &graph.resources[resource_index]
		if !resource.transient || graph.resource_first_use[resource_index] < 0 do continue
		slot := graph.resource_physical_slot[resource_index]
		if slot < 0 || slot >= len(backend.transient_buffers) do return false
		is_image := resource.kind == .Storage_Image || resource.kind == .Sampled_Image
		if !is_image && resource.kind != .Vertex_Buffer && resource.kind != .Index_Buffer do return false
		if is_image && (resource.format == .UNDEFINED || resource.width == 0 || resource.height == 0) do return false
		if !is_image && resource.byte_size == 0 do return false
		compatible := backend.transient_buffer_valid[slot] && render_graph_resource_compatible_for_alias(&backend.transient_buffer_resources[slot], resource)
		if !compatible {
			if backend.transient_buffer_valid[slot] {
				old := &backend.transient_buffer_resources[slot]
				if old.kind == .Storage_Image || old.kind == .Sampled_Image do render_transient_image_destroy(vk_ctx, &backend.transient_images[slot])
				if old.kind == .Vertex_Buffer || old.kind == .Index_Buffer do engine.vk_destroy_buffer(vk_ctx, &backend.transient_buffers[slot])
			}
			created := false
			if is_image {
				created = render_transient_image_create(vk_ctx, resource, &backend.transient_images[slot])
			} else {
				usage: vk.BufferUsageFlags = resource.kind == .Vertex_Buffer ? {.VERTEX_BUFFER, .STORAGE_BUFFER} : {.INDEX_BUFFER, .STORAGE_BUFFER}
				created = engine.vk_create_host_buffer(vk_ctx, vk.DeviceSize(resource.byte_size), usage, &backend.transient_buffers[slot])
			}
			if !created {
				backend.transient_buffer_valid[slot] = false
				return false
			}
			backend.transient_buffer_resources[slot] = resource^
			backend.transient_buffer_valid[slot] = true
			backend.transient_allocation_count += 1
		} else {
			backend.transient_reuse_count += 1
		}
		if is_image {
			if !render_graph_bind_imported_image(graph, ctx, Render_Resource_Handle(resource_index), backend.transient_images[slot].handle, .UNDEFINED, {.TOP_OF_PIPE}, {}) do return false
		} else {
			if !render_graph_bind_imported_buffer(graph, ctx, Render_Resource_Handle(resource_index), backend.transient_buffers[slot].handle, {.HOST}, {.HOST_WRITE}) do return false
		}
	}
	return true
}

render_backend_handle_main_menu_palette_requests :: proc(backend: ^Render_Backend, app_ui: ^App_Ui_State, app_mode: App_Mode) {
	entered_main_menu := app_mode == .Main_Menu && (!backend.last_app_mode_valid || backend.last_app_mode != .Main_Menu)
	backend.last_app_mode = app_mode
	backend.last_app_mode_valid = true
	if entered_main_menu {
		main_menu_backdrop_select_next_palette(&backend.main_menu_backdrop)
	}
	if app_ui != nil && app_ui.main_menu_palette_randomize_requested {
		main_menu_backdrop_select_next_palette(&backend.main_menu_backdrop)
		app_ui.main_menu_palette_randomize_requested = false
	}
	if app_ui != nil {
		palette_name := main_menu_backdrop_current_palette_name(&backend.main_menu_backdrop)
		if len(palette_name) == 0 {
			palette_name = COLOR_SCHEME_DEFAULT_NAME
		}
		color_scheme_name_set(&app_ui.main_menu_palette, palette_name)
	}
}

render_backend_draw_frame :: proc(backend: ^Render_Backend, vk_ctx: ^engine.Vk_Context, feature_instances: ^Render_Feature_Instance_Set, app_ui: ^App_Ui_State, gui: ^uifw.Gui_Context, dt: f32, app_mode: App_Mode, frame_index: u64, screenshot: ^engine.Screenshot_State, video_capture: ^Video_Capture_Sink = nil) -> bool {
	mode_changed := !backend.last_app_mode_valid || backend.last_app_mode != app_mode
	if backend.last_app_mode_valid && mode_changed {
		simulation_leave_cleanup(app_ui, backend.last_app_mode)
	}
	if mode_changed && app_ui != nil do _ = feature_instance_set_enter(&app_ui.feature_instances, app_mode)
	webcam_state: ^Remaining_Sim_State
	#partial switch app_mode {
	case .Vectors: webcam_state = &app_ui.vectors
	case .Moire: webcam_state = &app_ui.moire
	case .Flow_Field: webcam_state = &app_ui.flow_field
	case .Slime_Mold: webcam_state = &app_ui.slime_mold
	case:
	}
	if !backend.initialized || !vk_ctx.initialized {
		return false
	}
	render_backend_handle_main_menu_palette_requests(backend, app_ui, app_mode)
	backend.last_ui_build_seconds = 0
	backend.last_ui_overlay_seconds = 0
	backend.last_submit_seconds = 0
	backend.last_screenshot_seconds = 0
	backend.last_screenshot_captured = false
	backend.last_main_menu_preview_visible_slot_count = 0
	backend.last_main_menu_preview_warmed_mode_count = 0
	backend.last_main_menu_preview_fallback_fill_count = 0
	backend.last_main_menu_preview_skipped_present_count = 0

	submit_start := time.tick_now()
	frame, ok := engine.vk_begin_frame(vk_ctx)
	if !ok {
		return false
	}
	// Capture after vk_begin_frame has waited for this frame slot's fence. Flow
	// can now safely refill its persistent per-slot staging buffer.
	webcam_update_remaining(
		webcam_state,
		app_mode,
		vk_ctx,
		render_feature_set_runtime(feature_instances, .Vectors, false, Vectors_Gpu_State),
		render_feature_set_runtime(feature_instances, .Moire, false, Moire_Gpu_State),
		render_feature_set_runtime(feature_instances, .Flow_Field, false, Flow_Gpu_State),
		render_feature_set_runtime(feature_instances, .Slime_Mold, false, Slime_Gpu_State),
	)

	preview_count := app_ui != nil ? u32(app_ui.main_menu_preview_slot_count) : u32(0)
	screenshot_requested := screenshot != nil && engine.screenshot_state_should_capture(screenshot, frame_index, SCREENSHOT_REFRESH_INTERVAL_FRAMES)
	graph_key := Render_Graph_Structural_Key {
		mode = app_mode,
		preview_count = preview_count,
		preview_mode_mask = render_graph_preview_mode_mask(app_ui),
		capture_active = video_capture_is_recording(video_capture) || screenshot_requested,
		target_format = vk_ctx.swapchain_format,
	}
	graph := render_graph_cache_resolve(&backend.graph_cache, graph_key)
	if graph == nil {
		engine.log_error("render_backend_draw_frame: render graph compile failed error=", backend.graph_cache.graph.compile_error)
		return false
	}
	ctx := Render_Context {
		vk_ctx   = vk_ctx,
		backend  = backend,
		frame    = frame,
		gui      = gui,
		feature_instances = feature_instances,
		app_ui = app_ui,
		dt       = dt,
		app_mode = app_mode,
		frame_index = frame_index,
		video_capture = video_capture,
		screenshot = screenshot,
		screenshot_requested = screenshot_requested,
	}
	if !render_backend_bind_transient_resources(backend, vk_ctx, graph, &ctx) {
		engine.log_error("render_backend_draw_frame: failed to bind transient resources")
		return false
	}
	if int(frame.image_index) >= len(vk_ctx.swapchain_images) || !render_graph_bind_imported_image(graph, &ctx, Render_Resource_Handle(0), vk_ctx.swapchain_images[frame.image_index], .PRESENT_SRC_KHR, {.TOP_OF_PIPE}, {}) {
		engine.log_error("render_backend_draw_frame: failed to bind imported swapchain image")
		return false
	}
	ui_frame_slot := int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	ui_buffer_bound := false
	for resource_index in 0 ..< graph.resource_count {
		if graph.resources[resource_index].name != "ui frame vertices" do continue
		ui_buffer_bound = render_graph_bind_imported_buffer(graph, &ctx, Render_Resource_Handle(resource_index), backend.ui.vertex_buffers[ui_frame_slot].handle, {.HOST}, {.HOST_WRITE})
		break
	}
	if !ui_buffer_bound {
		engine.log_error("render_backend_draw_frame: failed to bind imported UI vertex buffer")
		return false
	}
	if !render_graph_execute(graph, &ctx) {
		engine.log_error("render_backend_draw_frame: render graph execute failed")
		if ctx.video_capture_frame_reserved {
			video_capture_release_frame(video_capture, ctx.video_capture_frame_index)
		}
		return false
	}
	if vk_ctx.debug_present_log_count < engine.VK_DEBUG_FRAME_LOG_LIMIT {
		engine.log_debug("render_backend_draw_frame: image_index=", frame.image_index, " app_mode=", app_mode, " ui_vertices=", backend.ui.vertex_count, " clear_rects=", backend.ui.clear_rect_count, " screenshot=", screenshot != nil)
	}

	if !engine.vk_end_frame(vk_ctx, frame) {
		if ctx.video_capture_frame_reserved {
			video_capture_release_frame(video_capture, ctx.video_capture_frame_index)
		}
		return false
	}
	backend.last_submit_seconds = time.duration_seconds(time.tick_diff(submit_start, time.tick_now()))
	gpu_sample := engine.gpu_profiler_last_sample(vk_ctx)
	backend.gpu_profiling_supported = gpu_sample.supported
	backend.gpu_profiling_enabled = gpu_sample.enabled
	backend.last_gpu_simulation_step_ms = gpu_sample.simulation_step_ms
	backend.last_gpu_simulation_present_ms = gpu_sample.simulation_present_ms
	backend.last_gpu_ui_overlay_ms = gpu_sample.ui_overlay_ms
	backend.last_gpu_frame_total_ms = gpu_sample.frame_ms
	backend.last_gpu_pellets_grid_clear_ms = gpu_sample.pellets_grid_clear_ms
	backend.last_gpu_pellets_grid_build_ms = gpu_sample.pellets_grid_build_ms
	backend.last_gpu_pellets_grid_scatter_ms = gpu_sample.pellets_grid_scatter_ms
	backend.last_gpu_pellets_physics_ms = gpu_sample.pellets_physics_ms
	backend.last_gpu_pellets_density_ms = gpu_sample.pellets_density_ms
	backend.last_gpu_pellets_particle_draw_ms = gpu_sample.pellets_particle_draw_ms
	backend.last_cpu_wait_fence_ms = vk_ctx.last_cpu_timings.wait_fence_ms
	backend.last_cpu_acquire_ms = vk_ctx.last_cpu_timings.acquire_ms
	backend.last_cpu_command_begin_ms = vk_ctx.last_cpu_timings.command_begin_ms
	backend.last_cpu_end_command_ms = vk_ctx.last_cpu_timings.end_command_ms
	backend.last_cpu_queue_submit_ms = vk_ctx.last_cpu_timings.queue_submit_ms
	backend.last_cpu_queue_present_ms = vk_ctx.last_cpu_timings.queue_present_ms
	backend.present_mode = engine.vk_present_mode_name(vk_ctx.caps.present_mode)
	backend.last_command_render_pass_count = vk_ctx.last_command_shape.rendering_scope_count
	backend.last_command_compute_dispatch_count = vk_ctx.last_command_shape.compute_dispatch_count
	backend.last_command_draw_count = vk_ctx.last_command_shape.draw_count
	backend.last_command_pipeline_bind_count = vk_ctx.last_command_shape.pipeline_bind_count
	backend.last_command_descriptor_bind_count = vk_ctx.last_command_shape.descriptor_bind_count
	backend.last_command_pipeline_barrier_count = vk_ctx.last_command_shape.pipeline_barrier_count
	backend.last_command_transfer_copy_count = vk_ctx.last_command_shape.transfer_copy_count
	backend.last_command_ui_batch_count = vk_ctx.last_command_shape.ui_batch_count
	backend.last_command_backdrop_blur_pass_count = vk_ctx.last_command_shape.backdrop_blur_pass_count

	if ctx.screenshot_readback_ready {
		screenshot_start := time.tick_now()
		backend.last_screenshot_captured = true
		_ = vk.WaitForFences(vk_ctx.device, 1, &frame.state.in_flight, true, 0xffffffffffffffff)
		size := int(vk_ctx.swapchain_extent.width * vk_ctx.swapchain_extent.height * 4)
		pixels := (cast([^]u8)ctx.screenshot_readback.mapped)[:size]
		published := engine.screenshot_state_publish_from_gpu_rgba(screenshot, pixels, vk_ctx.swapchain_extent.width, vk_ctx.swapchain_extent.height, vk_ctx.swapchain_format, frame_index)
		if vk_ctx.debug_present_log_count < engine.VK_DEBUG_FRAME_LOG_LIMIT {
			engine.log_debug("render_backend_draw_frame: screenshot publish=", published, " bytes=", size)
		}
		backend.last_screenshot_seconds = time.duration_seconds(time.tick_diff(screenshot_start, time.tick_now()))
	}
	if ctx.video_capture_readback_ready {
		_ = vk.WaitForFences(vk_ctx.device, 1, &frame.state.in_flight, true, 0xffffffffffffffff)
		size := int(vk_ctx.swapchain_extent.width * vk_ctx.swapchain_extent.height * 4)
		pixels := (cast([^]u8)ctx.video_capture_readback.mapped)[:size]
		capture_format := Capture_Pixel_Format.BGRA8_UNorm
		#partial switch vk_ctx.swapchain_format {
		case .R8G8B8A8_UNORM: capture_format = .RGBA8_UNorm
		case .R8G8B8A8_SRGB: capture_format = .RGBA8_SRGB
		case .B8G8R8A8_SRGB: capture_format = .BGRA8_SRGB
		}
		_ = video_capture_submit_frame(video_capture, ctx.video_capture_frame_index, pixels, vk_ctx.swapchain_extent.width, vk_ctx.swapchain_extent.height, capture_format)
	}

	return true
}

render_backend_capture_readback_buffer :: proc(ctx: ^Render_Context, kind: int) -> ^engine.Vk_Buffer {
	if ctx == nil || ctx.backend == nil || ctx.vk_ctx == nil || kind < 0 || kind >= len(ctx.backend.capture_readback_buffers) do return nil
	frame_slot := int(ctx.frame.frame_index)
	if frame_slot < 0 || frame_slot >= engine.MAX_FRAMES_IN_FLIGHT do return nil
	buffer := &ctx.backend.capture_readback_buffers[kind][frame_slot]
	required := vk.DeviceSize(ctx.vk_ctx.swapchain_extent.width * ctx.vk_ctx.swapchain_extent.height * 4)
	if buffer.handle != vk.Buffer(0) && buffer.size >= required {
		ctx.backend.capture_readback_reuse_count += 1
		return buffer
	}
	if buffer.handle != vk.Buffer(0) do engine.vk_destroy_buffer(ctx.vk_ctx, buffer)
	if !engine.vk_create_host_buffer(ctx.vk_ctx, required, {.TRANSFER_DST}, buffer) do return nil
	ctx.backend.capture_readback_allocation_count += 1
	return buffer
}

vk_cmd_capture_swapchain_to_buffer_graph_owned :: proc(ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, out: ^engine.Vk_Buffer) -> bool {
	width := ctx.swapchain_extent.width
	height := ctx.swapchain_extent.height
	if width == 0 || height == 0 {
		return false
	}
	if !ctx.swapchain_supports_transfer_src {
		return false
	}
	if out == nil || out.handle == vk.Buffer(0) || out.size < vk.DeviceSize(width * height * 4) do return false

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
	vk.CmdCopyImageToBuffer(frame.command_buffer, ctx.swapchain_images[frame.image_index], .TRANSFER_SRC_OPTIMAL, out.handle, 1, &region)
	engine.vk_cmd_count_transfer_copy(ctx)
	return true
}
