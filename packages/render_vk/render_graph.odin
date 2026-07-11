package render_vk

import uifw "../ui"
import engine "../engine"

import "core:math"
import "core:time"
import vk "vendor:vulkan"

MAX_RENDER_GRAPH_PASSES :: 16
MAX_RENDER_GRAPH_RESOURCES :: 32
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

Render_Pass_Kind :: enum {
	Acquire_Swapchain,
	Gray_Scott_Compute,
	Simulation_Present,
	Ui_Build,
	Ui_Overlay,
	Present_Swapchain,
}

Render_Resource_Handle :: distinct int

Render_Resource :: struct {
	name: string,
	kind: Render_Resource_Kind,
	image_layout: vk.ImageLayout,
	stage: vk.PipelineStageFlags,
	access: vk.AccessFlags,
	transient: bool,
}

Render_Pass_Execute :: proc(ctx: ^Render_Context, pass: ^Render_Pass_Node) -> bool

Render_Pass_Node :: struct {
	name: string,
	kind: Render_Pass_Kind,
	reads: [8]Render_Resource_Handle,
	read_count: int,
	writes: [8]Render_Resource_Handle,
	write_count: int,
	execute: Render_Pass_Execute,
}

Render_Graph :: struct {
	resources: [MAX_RENDER_GRAPH_RESOURCES]Render_Resource,
	resource_count: int,
	passes: [MAX_RENDER_GRAPH_PASSES]Render_Pass_Node,
	pass_count: int,
}

Render_Backend :: struct {
	ui: Ui_Renderer,
	post_processing: Post_Processing_Gpu_State,
	main_menu_backdrop: Main_Menu_Backdrop_Gpu_State,
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
	sim: ^Gray_Scott_Simulation,
	preview_gray_scott: ^Gray_Scott_Simulation,
	particle_life: ^Particle_Life_Simulation,
	preview_particle_life: ^Particle_Life_Simulation,
	vectors_gpu: ^Vectors_Gpu_State,
	preview_vectors_gpu: ^Vectors_Gpu_State,
	moire_gpu: ^Moire_Gpu_State,
	preview_moire_gpu: ^Moire_Gpu_State,
	primordial_gpu: ^Primordial_Gpu_State,
	preview_primordial_gpu: ^Primordial_Gpu_State,
	pellets_gpu: ^Pellets_Gpu_State,
	preview_pellets_gpu: ^Pellets_Gpu_State,
	flow_gpu: ^Flow_Gpu_State,
	preview_flow_gpu: ^Flow_Gpu_State,
	slime_gpu: ^Slime_Gpu_State,
	voronoi_gpu: ^Voronoi_Gpu_State,
	preview_slime_gpu: ^Slime_Gpu_State,
	preview_voronoi_gpu: ^Voronoi_Gpu_State,
	app_ui: ^App_Ui_State,
	dt: f32,
	app_mode: App_Mode,
	frame_index: u64,
	video_capture: ^Video_Capture_Sink,
	video_capture_readback: engine.Vk_Buffer,
	video_capture_readback_ready: bool,
	video_capture_frame_reserved: bool,
	video_capture_frame_index: int,
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
		main_menu_backdrop_destroy(&backend.main_menu_backdrop, ctx)
		post_processing_gpu_destroy(&backend.post_processing, ctx)
		ui_renderer_destroy(&backend.ui, ctx)
	}
	backend^ = {}
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

render_backend_draw_frame :: proc(backend: ^Render_Backend, vk_ctx: ^engine.Vk_Context, sim: ^Gray_Scott_Simulation, preview_gray_scott: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation, preview_particle_life: ^Particle_Life_Simulation, vectors_gpu: ^Vectors_Gpu_State, preview_vectors_gpu: ^Vectors_Gpu_State, moire_gpu: ^Moire_Gpu_State, preview_moire_gpu: ^Moire_Gpu_State, primordial_gpu: ^Primordial_Gpu_State, preview_primordial_gpu: ^Primordial_Gpu_State, pellets_gpu: ^Pellets_Gpu_State, preview_pellets_gpu: ^Pellets_Gpu_State, flow_gpu: ^Flow_Gpu_State, preview_flow_gpu: ^Flow_Gpu_State, slime_gpu: ^Slime_Gpu_State, voronoi_gpu: ^Voronoi_Gpu_State, preview_slime_gpu: ^Slime_Gpu_State, preview_voronoi_gpu: ^Voronoi_Gpu_State, app_ui: ^App_Ui_State, gui: ^uifw.Gui_Context, dt: f32, app_mode: App_Mode, frame_index: u64, screenshot: ^engine.Screenshot_State, video_capture: ^Video_Capture_Sink = nil) -> bool {
	if backend.last_app_mode_valid && backend.last_app_mode != app_mode {
		simulation_leave_cleanup(app_ui, sim, particle_life, backend.last_app_mode)
	}
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
	webcam_update_remaining(webcam_state, app_mode, vk_ctx, vectors_gpu, moire_gpu, flow_gpu, slime_gpu)

	graph := render_graph_build_v1()
	ctx := Render_Context {
		vk_ctx   = vk_ctx,
		backend  = backend,
		frame    = frame,
		gui      = gui,
		sim      = sim,
		preview_gray_scott = preview_gray_scott,
		particle_life = particle_life,
		preview_particle_life = preview_particle_life,
		vectors_gpu = vectors_gpu,
		preview_vectors_gpu = preview_vectors_gpu,
		moire_gpu = moire_gpu,
		preview_moire_gpu = preview_moire_gpu,
		primordial_gpu = primordial_gpu,
		preview_primordial_gpu = preview_primordial_gpu,
		pellets_gpu = pellets_gpu,
		preview_pellets_gpu = preview_pellets_gpu,
		flow_gpu = flow_gpu,
		preview_flow_gpu = preview_flow_gpu,
		slime_gpu = slime_gpu,
		voronoi_gpu = voronoi_gpu,
		preview_slime_gpu = preview_slime_gpu,
		preview_voronoi_gpu = preview_voronoi_gpu,
		app_ui = app_ui,
		dt       = dt,
		app_mode = app_mode,
		frame_index = frame_index,
		video_capture = video_capture,
	}
	if !render_graph_execute(&graph, &ctx) {
		engine.log_error("render_backend_draw_frame: render graph execute failed")
		if ctx.video_capture_readback_ready {
			engine.vk_destroy_buffer(vk_ctx, &ctx.video_capture_readback)
		}
		if ctx.video_capture_frame_reserved {
			video_capture_release_frame(video_capture, ctx.video_capture_frame_index)
		}
		return false
	}
	if vk_ctx.debug_present_log_count < engine.VK_DEBUG_FRAME_LOG_LIMIT {
		engine.log_debug("render_backend_draw_frame: image_index=", frame.image_index, " app_mode=", app_mode, " ui_vertices=", backend.ui.vertex_count, " clear_rects=", backend.ui.clear_rect_count, " screenshot=", screenshot != nil)
	}

	readback: engine.Vk_Buffer
	readback_ready := false
	if screenshot != nil && engine.screenshot_state_should_capture(screenshot, frame_index, SCREENSHOT_REFRESH_INTERVAL_FRAMES) {
		readback_ready = vk_cmd_capture_swapchain_to_buffer(vk_ctx, frame, &readback)
		if !readback_ready {
			engine.log_warn("render_backend_draw_frame: screenshot readback setup failed")
		}
	}

	if !engine.vk_end_frame(vk_ctx, frame) {
		if readback_ready {
			engine.vk_destroy_buffer(vk_ctx, &readback)
		}
		if ctx.video_capture_readback_ready {
			engine.vk_destroy_buffer(vk_ctx, &ctx.video_capture_readback)
		}
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
	backend.last_cpu_wait_fence_ms = vk_ctx.last_cpu_timings.wait_fence_ms
	backend.last_cpu_acquire_ms = vk_ctx.last_cpu_timings.acquire_ms
	backend.last_cpu_command_begin_ms = vk_ctx.last_cpu_timings.command_begin_ms
	backend.last_cpu_end_command_ms = vk_ctx.last_cpu_timings.end_command_ms
	backend.last_cpu_queue_submit_ms = vk_ctx.last_cpu_timings.queue_submit_ms
	backend.last_cpu_queue_present_ms = vk_ctx.last_cpu_timings.queue_present_ms
	backend.present_mode = engine.vk_present_mode_name(vk_ctx.caps.present_mode)
	backend.last_command_render_pass_count = vk_ctx.last_command_shape.render_pass_count
	backend.last_command_compute_dispatch_count = vk_ctx.last_command_shape.compute_dispatch_count
	backend.last_command_draw_count = vk_ctx.last_command_shape.draw_count
	backend.last_command_pipeline_bind_count = vk_ctx.last_command_shape.pipeline_bind_count
	backend.last_command_descriptor_bind_count = vk_ctx.last_command_shape.descriptor_bind_count
	backend.last_command_pipeline_barrier_count = vk_ctx.last_command_shape.pipeline_barrier_count
	backend.last_command_transfer_copy_count = vk_ctx.last_command_shape.transfer_copy_count
	backend.last_command_ui_batch_count = vk_ctx.last_command_shape.ui_batch_count
	backend.last_command_backdrop_blur_pass_count = vk_ctx.last_command_shape.backdrop_blur_pass_count

	if readback_ready {
		screenshot_start := time.tick_now()
		backend.last_screenshot_captured = true
		_ = vk.WaitForFences(vk_ctx.device, 1, &frame.state.in_flight, true, 0xffffffffffffffff)
		size := int(vk_ctx.swapchain_extent.width * vk_ctx.swapchain_extent.height * 4)
		pixels := (cast([^]u8)readback.mapped)[:size]
		published := engine.screenshot_state_publish_from_gpu_rgba(screenshot, pixels, vk_ctx.swapchain_extent.width, vk_ctx.swapchain_extent.height, vk_ctx.swapchain_format, frame_index)
		if vk_ctx.debug_present_log_count < engine.VK_DEBUG_FRAME_LOG_LIMIT {
			engine.log_debug("render_backend_draw_frame: screenshot publish=", published, " bytes=", size)
		}
		engine.vk_destroy_buffer(vk_ctx, &readback)
		backend.last_screenshot_seconds = time.duration_seconds(time.tick_diff(screenshot_start, time.tick_now()))
	}
	if ctx.video_capture_readback_ready {
		_ = vk.WaitForFences(vk_ctx.device, 1, &frame.state.in_flight, true, 0xffffffffffffffff)
		size := int(vk_ctx.swapchain_extent.width * vk_ctx.swapchain_extent.height * 4)
		pixels := (cast([^]u8)ctx.video_capture_readback.mapped)[:size]
		_ = video_capture_submit_frame(video_capture, ctx.video_capture_frame_index, pixels, vk_ctx.swapchain_extent.width, vk_ctx.swapchain_extent.height, vk_ctx.swapchain_format)
		engine.vk_destroy_buffer(vk_ctx, &ctx.video_capture_readback)
	}

	return true
}

vk_cmd_capture_swapchain_to_buffer :: proc(ctx: ^engine.Vk_Context, frame: engine.Vk_Frame, out: ^engine.Vk_Buffer) -> bool {
	width := ctx.swapchain_extent.width
	height := ctx.swapchain_extent.height
	if width == 0 || height == 0 {
		return false
	}
	if !ctx.swapchain_supports_transfer_src {
		return false
	}
	size := vk.DeviceSize(width * height * 4)
	if !engine.vk_create_host_buffer(ctx, size, {.TRANSFER_DST}, out) {
		return false
	}

	image := ctx.swapchain_images[frame.image_index]
	to_transfer := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = {.COLOR_ATTACHMENT_WRITE},
		dstAccessMask = {.TRANSFER_READ},
		oldLayout = .PRESENT_SRC_KHR,
		newLayout = .TRANSFER_SRC_OPTIMAL,
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
	vk.CmdPipelineBarrier(frame.command_buffer, {.COLOR_ATTACHMENT_OUTPUT}, {.TRANSFER}, {}, 0, nil, 0, nil, 1, &to_transfer)
	engine.vk_cmd_count_pipeline_barrier(ctx)

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
	vk.CmdCopyImageToBuffer(frame.command_buffer, image, .TRANSFER_SRC_OPTIMAL, out.handle, 1, &region)
	engine.vk_cmd_count_transfer_copy(ctx)

	to_present := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = {.TRANSFER_READ},
		dstAccessMask = {},
		oldLayout = .TRANSFER_SRC_OPTIMAL,
		newLayout = .PRESENT_SRC_KHR,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = image,
		subresourceRange = to_transfer.subresourceRange,
	}
	vk.CmdPipelineBarrier(frame.command_buffer, {.TRANSFER}, {.BOTTOM_OF_PIPE}, {}, 0, nil, 0, nil, 1, &to_present)
	engine.vk_cmd_count_pipeline_barrier(ctx)
	return true
}

vk_cmd_transition_swapchain_present_to_color :: proc(ctx: ^engine.Vk_Context, frame: engine.Vk_Frame) {
	image := ctx.swapchain_images[frame.image_index]
	to_color := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = {},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
		oldLayout = .PRESENT_SRC_KHR,
		newLayout = .COLOR_ATTACHMENT_OPTIMAL,
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
	vk.CmdPipelineBarrier(frame.command_buffer, {.BOTTOM_OF_PIPE}, {.COLOR_ATTACHMENT_OUTPUT}, {}, 0, nil, 0, nil, 1, &to_color)
	engine.vk_cmd_count_pipeline_barrier(ctx)
}

render_graph_build_v1 :: proc() -> Render_Graph {
	graph: Render_Graph
	swapchain := render_graph_add_resource(&graph, "swapchain color", .Swapchain_Color, false)
	sim_state := render_graph_add_resource(&graph, "gray scott state", .Storage_Image, false)
	ui_vertices := render_graph_add_resource(&graph, "ui transient vertices", .Vertex_Buffer, true)

	render_graph_add_pass(&graph, "AcquireSwapchain", .Acquire_Swapchain, nil, nil, render_pass_noop)
	render_graph_add_pass(&graph, "GrayScottCompute", .Gray_Scott_Compute, []Render_Resource_Handle{sim_state}, []Render_Resource_Handle{sim_state}, render_pass_gray_scott_compute)
	render_graph_add_pass(&graph, "UiBuild", .Ui_Build, nil, []Render_Resource_Handle{ui_vertices}, render_pass_ui_build)
	render_graph_add_pass(&graph, "SimulationPresent", .Simulation_Present, []Render_Resource_Handle{sim_state, ui_vertices}, []Render_Resource_Handle{swapchain}, render_pass_simulation_present)
	render_graph_add_pass(&graph, "UiOverlay", .Ui_Overlay, []Render_Resource_Handle{ui_vertices}, []Render_Resource_Handle{swapchain}, render_pass_ui_overlay)
	render_graph_add_pass(&graph, "PresentSwapchain", .Present_Swapchain, []Render_Resource_Handle{swapchain}, nil, render_pass_noop)
	return graph
}

render_graph_add_resource :: proc(graph: ^Render_Graph, name: string, kind: Render_Resource_Kind, transient: bool) -> Render_Resource_Handle {
	index := graph.resource_count
	if index >= MAX_RENDER_GRAPH_RESOURCES {
		return Render_Resource_Handle(-1)
	}
	graph.resources[index] = {name = name, kind = kind, transient = transient}
	graph.resource_count += 1
	return Render_Resource_Handle(index)
}

render_graph_add_pass :: proc(graph: ^Render_Graph, name: string, kind: Render_Pass_Kind, reads: []Render_Resource_Handle, writes: []Render_Resource_Handle, execute: Render_Pass_Execute) {
	if graph.pass_count >= MAX_RENDER_GRAPH_PASSES {
		return
	}
	pass := &graph.passes[graph.pass_count]
	pass.name = name
	pass.kind = kind
	pass.execute = execute
	pass.read_count = min(len(reads), len(pass.reads))
	pass.write_count = min(len(writes), len(pass.writes))
	for i in 0 ..< pass.read_count {
		pass.reads[i] = reads[i]
	}
	for i in 0 ..< pass.write_count {
		pass.writes[i] = writes[i]
	}
	graph.pass_count += 1
}

render_graph_execute :: proc(graph: ^Render_Graph, ctx: ^Render_Context) -> bool {
	for i in 0 ..< graph.pass_count {
		pass := &graph.passes[i]
		if pass.execute != nil && !pass.execute(ctx, pass) {
			return false
		}
			if pass.kind == .Simulation_Present && video_capture_is_recording(ctx.video_capture) && app_ui_mode_allows_video_recording(ctx.app_mode) {
				if video_capture_reserve_frame(ctx.video_capture, &ctx.video_capture_frame_index) {
					ctx.video_capture_frame_reserved = true
					ctx.video_capture_readback_ready = vk_cmd_capture_swapchain_to_buffer(ctx.vk_ctx, ctx.frame, &ctx.video_capture_readback)
					if !ctx.video_capture_readback_ready {
						video_capture_release_frame(ctx.video_capture, ctx.video_capture_frame_index)
						ctx.video_capture_frame_reserved = false
						video_capture_fail(ctx.video_capture, "Failed to capture video frame")
					}
				}
			}
	}
	return true
}

render_pass_noop :: proc(ctx: ^Render_Context, pass: ^Render_Pass_Node) -> bool {
	_ = ctx
	_ = pass
	return true
}

render_pass_gray_scott_compute :: proc(ctx: ^Render_Context, pass: ^Render_Pass_Node) -> bool {
	_ = pass
	engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "Simulation step")
	engine.gpu_profiler_begin_pass(ctx.vk_ctx, ctx.frame.command_buffer, ctx.frame, .Simulation_Step)
	defer engine.gpu_profiler_end_pass(ctx.vk_ctx, ctx.frame.command_buffer, ctx.frame, .Simulation_Step)
	defer engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
	sim_dt := simulation_frame_delta(ctx.dt)
	if ctx.app_mode == .Main_Menu {
		render_pass_main_menu_preview_step(ctx)
		render_pass_main_menu_preview_prepare(ctx)
		return true
	}
	if ctx.app_mode != .Gray_Scott {
		if ctx.app_mode == .Particle_Life && particle_life_ensure_gpu_runtime(ctx.particle_life, ctx.vk_ctx) {
			steps := particle_life_simulation_substeps(sim_dt, ctx.particle_life.settings.particle_count)
			for _ in 0 ..< steps.count {
				particle_life_gpu_step(ctx.particle_life, ctx.vk_ctx, ctx.frame.command_buffer, steps.delta_time)
			}
		} else if ctx.app_mode == .Moire && ctx.app_ui != nil && ctx.moire_gpu != nil {
			moire_gpu_step(
				ctx.moire_gpu,
				ctx.vk_ctx,
				ctx.frame.command_buffer,
				&ctx.app_ui.moire.moire,
				ctx.app_ui.moire.time,
				i32(ctx.vk_ctx.swapchain_extent.width),
				i32(ctx.vk_ctx.swapchain_extent.height),
				ctx.app_ui.moire.paused,
			)
		} else if ctx.app_mode == .Primordial && ctx.app_ui != nil && ctx.primordial_gpu != nil {
			steps := simulation_substeps(sim_dt)
			for _ in 0 ..< steps.count {
				primordial_gpu_step(ctx.primordial_gpu, ctx.vk_ctx, ctx.frame.command_buffer, &ctx.app_ui.primordial, steps.delta_time)
			}
		} else if ctx.app_mode == .Pellets && ctx.app_ui != nil && ctx.pellets_gpu != nil {
			steps := simulation_substeps(sim_dt)
			for _ in 0 ..< steps.count {
				pellets_gpu_step(ctx.pellets_gpu, ctx.vk_ctx, ctx.frame.command_buffer, &ctx.app_ui.pellets, steps.delta_time)
			}
		} else if ctx.app_mode == .Flow_Field && ctx.app_ui != nil && ctx.flow_gpu != nil {
			flow_gpu_step(ctx.flow_gpu, ctx.vk_ctx, ctx.frame.command_buffer, &ctx.app_ui.flow_field, sim_dt)
		} else if ctx.app_mode == .Slime_Mold && ctx.app_ui != nil && ctx.slime_gpu != nil {
			slime_gpu_step(ctx.slime_gpu, ctx.vk_ctx, ctx.frame.command_buffer, &ctx.app_ui.slime_mold, sim_dt)
		} else if ctx.app_mode == .Voronoi_CA && ctx.app_ui != nil && ctx.voronoi_gpu != nil {
			voronoi_gpu_step(ctx.voronoi_gpu, ctx.vk_ctx, ctx.frame.command_buffer, &ctx.app_ui.voronoi_ca, sim_dt)
		}
		return true
	}
	if !gray_scott_ensure_gpu_runtime(ctx.sim, ctx.vk_ctx) {
		return true
	}
	gray_scott_gpu_step(ctx.sim, ctx.vk_ctx, ctx.frame.command_buffer, sim_dt)
	return true
}

render_pass_main_menu_preview_step :: proc(ctx: ^Render_Context) {
	if ctx.app_ui == nil {
		return
	}
	palette_name := render_main_menu_preview_palette_name(ctx)
	sim_dt := simulation_frame_delta(ctx.dt)
	preview_width := MAIN_MENU_SIM_PREVIEW_WIDTH
	preview_height := MAIN_MENU_SIM_PREVIEW_HEIGHT
	if ctx.preview_gray_scott != nil && render_main_menu_preview_mode_visible(ctx, .Gray_Scott) {
		render_main_menu_apply_gray_scott_palette(&ctx.preview_gray_scott.settings, palette_name)
		if ctx.preview_gray_scott.gpu.width != i32(preview_width) || ctx.preview_gray_scott.gpu.height != i32(preview_height) {
			gray_scott_resize(ctx.preview_gray_scott, i32(preview_width), i32(preview_height))
		}
		if gray_scott_ensure_gpu_runtime(ctx.preview_gray_scott, ctx.vk_ctx) {
			gray_scott_gpu_step(ctx.preview_gray_scott, ctx.vk_ctx, ctx.frame.command_buffer, sim_dt)
		}
		ctx.backend.last_main_menu_preview_warmed_mode_count += 1
	}
	if ctx.preview_slime_gpu != nil && render_main_menu_preview_mode_visible(ctx, .Slime_Mold) {
		preview_slime := render_main_menu_slime_preview_state(&ctx.app_ui.slime_mold)
		render_main_menu_apply_slime_palette(&preview_slime.slime, palette_name)
		remaining_sim_step(&preview_slime, sim_dt)
		slime_width, slime_height := render_main_menu_preview_size_for_mode(ctx, .Slime_Mold)
		slime_gpu_step_preview(ctx.preview_slime_gpu, ctx.vk_ctx, ctx.frame.command_buffer, &preview_slime, sim_dt, slime_width, slime_height)
		ctx.backend.last_main_menu_preview_warmed_mode_count += 1
	}
	if ctx.preview_particle_life != nil && render_main_menu_preview_mode_visible(ctx, .Particle_Life) {
		particle_life_settings := ctx.preview_particle_life.settings
		if ctx.particle_life != nil {
			particle_life_settings = ctx.particle_life.settings
		}
		ctx.preview_particle_life.settings = render_main_menu_particle_life_preview_settings(particle_life_settings)
		render_main_menu_apply_particle_life_palette(&ctx.preview_particle_life.settings, palette_name)
		if ctx.preview_particle_life.gpu.width != i32(preview_width) || ctx.preview_particle_life.gpu.height != i32(preview_height) {
			particle_life_resize(ctx.preview_particle_life, i32(preview_width), i32(preview_height))
		}
		if particle_life_ensure_gpu_runtime(ctx.preview_particle_life, ctx.vk_ctx) {
			steps := simulation_substeps(sim_dt)
			for _ in 0 ..< steps.count {
				particle_life_gpu_step(ctx.preview_particle_life, ctx.vk_ctx, ctx.frame.command_buffer, steps.delta_time)
			}
		}
		ctx.backend.last_main_menu_preview_warmed_mode_count += 1
	}
	if ctx.preview_flow_gpu != nil && render_main_menu_preview_mode_visible(ctx, .Flow_Field) {
		preview_flow := render_main_menu_flow_preview_state(&ctx.app_ui.flow_field)
		render_main_menu_apply_flow_palette(&preview_flow.flow, palette_name)
		remaining_sim_step(&preview_flow, sim_dt)
		flow_width, flow_height := render_main_menu_preview_size_for_mode(ctx, .Flow_Field)
		flow_gpu_step_preview(ctx.preview_flow_gpu, ctx.vk_ctx, ctx.frame.command_buffer, &preview_flow, sim_dt, flow_width, flow_height)
		ctx.backend.last_main_menu_preview_warmed_mode_count += 1
	}
	if ctx.preview_pellets_gpu != nil && render_main_menu_preview_mode_visible(ctx, .Pellets) {
		preview_pellets := render_main_menu_pellets_preview_state(&ctx.app_ui.pellets)
		render_main_menu_apply_pellets_palette(&preview_pellets.pellets, palette_name)
		remaining_sim_step(&preview_pellets, sim_dt)
		pellets_gpu_step(ctx.preview_pellets_gpu, ctx.vk_ctx, ctx.frame.command_buffer, &preview_pellets, sim_dt)
		ctx.backend.last_main_menu_preview_warmed_mode_count += 1
	}
	if ctx.preview_voronoi_gpu != nil && render_main_menu_preview_mode_visible(ctx, .Voronoi_CA) {
		remaining_sim_step(&ctx.app_ui.voronoi_ca, sim_dt)
		preview_voronoi := ctx.app_ui.voronoi_ca
		render_main_menu_apply_voronoi_palette(&preview_voronoi.voronoi, palette_name)
		voronoi_gpu_step_size(ctx.preview_voronoi_gpu, ctx.vk_ctx, ctx.frame.command_buffer, &preview_voronoi.voronoi, sim_dt, preview_voronoi.paused, preview_width, preview_height)
		ctx.backend.last_main_menu_preview_warmed_mode_count += 1
	}
	if ctx.preview_moire_gpu != nil && render_main_menu_preview_mode_visible(ctx, .Moire) {
		remaining_sim_step(&ctx.app_ui.moire, sim_dt)
		preview_moire := ctx.app_ui.moire
		render_main_menu_apply_moire_palette(&preview_moire.moire, palette_name)
		moire_gpu_step(
			ctx.preview_moire_gpu,
			ctx.vk_ctx,
			ctx.frame.command_buffer,
			&preview_moire.moire,
			preview_moire.time,
			i32(preview_width),
			i32(preview_height),
			preview_moire.paused,
		)
		ctx.backend.last_main_menu_preview_warmed_mode_count += 1
	}
	if ctx.preview_vectors_gpu != nil && render_main_menu_preview_mode_visible(ctx, .Vectors) {
		remaining_sim_step(&ctx.app_ui.vectors, sim_dt)
		preview_vectors := ctx.app_ui.vectors
		render_main_menu_apply_vectors_palette(&preview_vectors.vectors, palette_name)
		_ = vectors_gpu_prepare_viewport(ctx.preview_vectors_gpu, ctx.vk_ctx, &preview_vectors.vectors, preview_vectors.time, f32(preview_width), f32(preview_height))
		ctx.backend.last_main_menu_preview_warmed_mode_count += 1
	}
	if ctx.preview_primordial_gpu != nil && render_main_menu_preview_mode_visible(ctx, .Primordial) {
		preview_primordial := render_main_menu_primordial_preview_state(&ctx.app_ui.primordial)
		render_main_menu_apply_primordial_palette(&preview_primordial.primordial, palette_name)
		remaining_sim_step(&preview_primordial, sim_dt)
		steps := simulation_substeps(sim_dt)
		for _ in 0 ..< steps.count {
			primordial_gpu_step(ctx.preview_primordial_gpu, ctx.vk_ctx, ctx.frame.command_buffer, &preview_primordial, steps.delta_time)
		}
		ctx.backend.last_main_menu_preview_warmed_mode_count += 1
	}
}

render_main_menu_preview_mode_visible :: proc(ctx: ^Render_Context, mode: App_Mode) -> bool {
	if ctx == nil || ctx.app_ui == nil || ctx.app_ui.main_menu_preview_slot_count <= 0 {
		return false
	}
	count := min(ctx.app_ui.main_menu_preview_slot_count, MAIN_MENU_PREVIEW_SLOT_CAP)
	for i in 0 ..< count {
		slot := ctx.app_ui.main_menu_preview_slots[i]
		if slot.mode == mode && slot.clip_rect.w > 1 && slot.clip_rect.h > 1 {
			return true
		}
	}
	return false
}

render_pass_main_menu_preview_prepare :: proc(ctx: ^Render_Context) {
	if ctx.app_ui == nil || ctx.app_ui.main_menu_preview_slot_count <= 0 {
		return
	}
	count := min(ctx.app_ui.main_menu_preview_slot_count, MAIN_MENU_PREVIEW_SLOT_CAP)
	for i in 0 ..< count {
		render_pass_main_menu_preview_prepare_slot(ctx, ctx.app_ui.main_menu_preview_slots[i])
	}
}

render_pass_main_menu_preview_prepare_slot :: proc(ctx: ^Render_Context, slot: Main_Menu_Preview_Slot) {
	if slot.clip_rect.w <= 1 || slot.clip_rect.h <= 1 {
		return
	}
	viewport: vk.Viewport
	scissor: vk.Rect2D
	if !render_main_menu_preview_viewport_for_rect(ctx, slot.rect, slot.clip_rect, &viewport, &scissor) {
		return
	}
	cmd := ctx.frame.command_buffer
	frame_slot := int(ctx.frame.frame_index)
	#partial switch slot.mode {
	case .Gray_Scott:
		sim := ctx.preview_gray_scott
		if sim != nil {
			_ = gray_scott_gpu_prepare_present_viewport(sim, ctx.vk_ctx, cmd)
		}
	case .Slime_Mold:
		gpu := ctx.preview_slime_gpu
		if gpu != nil && gpu.ready && gpu.display_image.handle != vk.Image(0) && gpu.display_image.layout != .SHADER_READ_ONLY_OPTIMAL {
			slime_transition_image(ctx.vk_ctx, cmd, &gpu.display_image, .SHADER_READ_ONLY_OPTIMAL)
		}
		if gpu != nil && gpu.ready {
			slime_upload_camera(gpu, frame_slot)
		}
	case .Flow_Field:
		gpu := ctx.preview_flow_gpu
		if gpu != nil && gpu.ready {
			flow_upload_camera_size(gpu, frame_slot, viewport.width, viewport.height)
			flow_update_descriptors_for_slot(gpu, ctx.vk_ctx, frame_slot)
			if gpu.trail_pipeline.pipeline != vk.Pipeline(0) && gpu.trail_image.handle != vk.Image(0) {
				flow_transition_image(ctx.vk_ctx, cmd, &gpu.trail_image, .GENERAL)
			}
		}
	case .Pellets:
		gpu := ctx.preview_pellets_gpu
		if gpu != nil && gpu.ready {
			preview_pellets := render_main_menu_pellets_preview_state(&ctx.app_ui.pellets)
			render_main_menu_apply_pellets_palette(&preview_pellets.pellets, render_main_menu_preview_palette_name(ctx))
			pellets_upload_lut(gpu, &preview_pellets.pellets)
			pellets_write_static_params_size(gpu, frame_slot, viewport.width * 2, viewport.height * 2, &preview_pellets.pellets)
			pellets_update_descriptors_for_slot(gpu, ctx.vk_ctx, frame_slot)
		}
	case .Voronoi_CA:
		gpu := ctx.preview_voronoi_gpu
		if gpu != nil && gpu.ready {
			image := gpu.jfa_result_is_scratch ? &gpu.jfa_scratch_image : &gpu.jfa_image
			if image.handle != vk.Image(0) && image.layout != .SHADER_READ_ONLY_OPTIMAL {
				voronoi_transition_image(ctx.vk_ctx, cmd, image, .SHADER_READ_ONLY_OPTIMAL)
			}
		}
	case .Moire:
		gpu := ctx.preview_moire_gpu
		if gpu != nil && gpu.ready && gpu.state_index < 2 {
			index := int(gpu.state_index)
			if gpu.images[index].handle != vk.Image(0) && gpu.images[index].layout != .SHADER_READ_ONLY_OPTIMAL {
				moire_transition_image(gpu, ctx.vk_ctx, index, .SHADER_READ_ONLY_OPTIMAL, cmd)
			}
			moire_update_texture_descriptor(gpu, ctx.vk_ctx, frame_slot, index)
		}
		if gpu != nil && gpu.ready {
			moire_upload_camera(gpu, frame_slot)
		}
	case .Primordial:
		gpu := ctx.preview_primordial_gpu
		if gpu != nil && gpu.ready {
			preview_primordial := render_main_menu_primordial_preview_state(&ctx.app_ui.primordial)
			render_main_menu_apply_primordial_palette(&preview_primordial.primordial, render_main_menu_preview_palette_name(ctx))
			primordial_upload_lut(gpu, &preview_primordial.primordial)
			primordial_upload_camera(gpu, frame_slot, viewport.width, viewport.height)
			primordial_upload_render_params_for_extent(gpu, frame_slot, &preview_primordial.primordial, viewport.width, viewport.height)
			primordial_upload_background_params(gpu, frame_slot, &preview_primordial.primordial)
			primordial_update_descriptors_for_slot(gpu, ctx.vk_ctx, frame_slot)
		}
	}
}

render_main_menu_preview_supported_mode_count :: proc() -> u32 {
	return 9
}

render_main_menu_preview_palette_name :: proc(ctx: ^Render_Context) -> string {
	if ctx == nil || ctx.backend == nil {
		return COLOR_SCHEME_DEFAULT_NAME
	}
	name := main_menu_backdrop_current_palette_name(&ctx.backend.main_menu_backdrop)
	if len(name) == 0 {
		return COLOR_SCHEME_DEFAULT_NAME
	}
	return name
}

render_main_menu_apply_preview_palette :: proc(color_scheme: ^Color_Scheme_Name, reversed: ^bool, palette_name: string) {
	name := palette_name
	if len(name) == 0 {
		name = COLOR_SCHEME_DEFAULT_NAME
	}
	color_scheme_name_set(color_scheme, name)
	reversed^ = true
}

render_main_menu_apply_gray_scott_palette :: proc(settings: ^Gray_Scott_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_particle_life_palette :: proc(settings: ^Particle_Life_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_moire_palette :: proc(settings: ^Moire_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_vectors_palette :: proc(settings: ^Vectors_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_primordial_palette :: proc(settings: ^Primordial_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_voronoi_palette :: proc(settings: ^Voronoi_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_pellets_palette :: proc(settings: ^Pellets_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_flow_palette :: proc(settings: ^Flow_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_slime_palette :: proc(settings: ^Slime_Settings, palette_name: string) {
	render_main_menu_apply_preview_palette(&settings.color_scheme, &settings.color_scheme_reversed, palette_name)
}

render_main_menu_apply_palette_to_mode :: proc(app_ui: ^App_Ui_State, gray_scott: ^Gray_Scott_Settings, particle_life: ^Particle_Life_Settings, mode: App_Mode, palette_name: string) -> bool {
	#partial switch mode {
	case .Slime_Mold:
		if app_ui == nil {return false}
		render_main_menu_apply_slime_palette(&app_ui.slime_mold.slime, palette_name)
	case .Gray_Scott:
		if gray_scott == nil {return false}
		render_main_menu_apply_gray_scott_palette(gray_scott, palette_name)
	case .Particle_Life:
		if particle_life == nil {return false}
		render_main_menu_apply_particle_life_palette(particle_life, palette_name)
	case .Flow_Field:
		if app_ui == nil {return false}
		render_main_menu_apply_flow_palette(&app_ui.flow_field.flow, palette_name)
	case .Pellets:
		if app_ui == nil {return false}
		render_main_menu_apply_pellets_palette(&app_ui.pellets.pellets, palette_name)
	case .Voronoi_CA:
		if app_ui == nil {return false}
		render_main_menu_apply_voronoi_palette(&app_ui.voronoi_ca.voronoi, palette_name)
	case .Moire:
		if app_ui == nil {return false}
		render_main_menu_apply_moire_palette(&app_ui.moire.moire, palette_name)
	case .Vectors:
		if app_ui == nil {return false}
		render_main_menu_apply_vectors_palette(&app_ui.vectors.vectors, palette_name)
	case .Primordial:
		if app_ui == nil {return false}
		render_main_menu_apply_primordial_palette(&app_ui.primordial.primordial, palette_name)
	case:
		return false
	}
	return true
}

render_main_menu_particle_life_preview_settings :: proc(source: Particle_Life_Settings) -> Particle_Life_Settings {
	preview := source
	preview.particle_count = min(max(source.particle_count, 1), 2400)
	preview.particle_size = max(source.particle_size, 3)
	preview.camera_zoom = 1
	preview.cursor_strength = 0
	preview.trails_enabled = false
	preview.infinite_tiles_enabled = false
	preview.paused = false
	return preview
}

render_main_menu_flow_preview_state :: proc(source: ^Remaining_Sim_State) -> Remaining_Sim_State {
	preview := source^
	preview.paused = false
	preview.cursor_active = 0
	preview.flow.total_pool_size = min(max(source.flow.total_pool_size, 1), 6000)
	preview.flow.autospawn_rate = min(max(source.flow.autospawn_rate, 1), 180)
	preview.flow.brush_spawn_rate = min(max(source.flow.brush_spawn_rate, 1), 300)
	preview.flow.particle_size = min(max(source.flow.particle_size, 1), 3)
	preview.flow.particle_speed = min(source.flow.particle_speed, 1.0)
	preview.flow.particle_lifetime = min(source.flow.particle_lifetime, 4.0)
	preview.flow.show_particles = true
	return preview
}

render_main_menu_pellets_preview_state :: proc(source: ^Remaining_Sim_State) -> Remaining_Sim_State {
	preview := source^
	preview.paused = false
	preview.cursor_active = 0
	preview.pellets.particle_count = min(max(source.pellets.particle_count, 1), 1400)
	preview.pellets.particle_size = max(source.pellets.particle_size, 0.018)
	preview.pellets.trails_enabled = false
	return preview
}

render_main_menu_slime_preview_state :: proc(source: ^Remaining_Sim_State) -> Remaining_Sim_State {
	preview := source^
	preview.paused = false
	preview.cursor_active = 0
	preview.slime.agent_sensor_distance = min(source.slime.agent_sensor_distance, 8.0)
	preview.slime.agent_speed_min = min(source.slime.agent_speed_min, 10.0)
	preview.slime.agent_speed_max = min(source.slime.agent_speed_max, 20.0)
	preview.slime.pheromone_decay_rate = 6.0
	preview.slime.pheromone_deposition_rate = 45.0
	preview.slime.pheromone_diffusion_rate = 18.0
	return preview
}

render_main_menu_primordial_preview_state :: proc(source: ^Remaining_Sim_State) -> Remaining_Sim_State {
	preview := source^
	preview.paused = false
	preview.cursor_active = 0
	preview.primordial.traces_enabled = false
	preview.primordial.particle_count = min(max(source.primordial.particle_count, 1), 2400)
	preview.primordial.particle_size = max(source.primordial.particle_size, 0.012)
	return preview
}

render_main_menu_preview_size_for_slot :: proc(slot: Main_Menu_Preview_Slot) -> (u32, u32) {
	return render_main_menu_preview_size_for_rect(slot.rect.w, slot.rect.h)
}

render_main_menu_preview_size_for_slot_extent :: proc(slot: Main_Menu_Preview_Slot, extent: vk.Extent2D) -> (u32, u32) {
	rect := slot.rect
	if extent.width > 0 && extent.height > 0 {
		x0 := max(rect.x, 0)
		y0 := max(rect.y, 0)
		x1 := min(rect.x + rect.w, f32(extent.width))
		y1 := min(rect.y + rect.h, f32(extent.height))
		if x1 > x0 && y1 > y0 {
			return render_main_menu_preview_size_for_rect(x1 - x0, y1 - y0)
		}
		return MAIN_MENU_SIM_PREVIEW_WIDTH, MAIN_MENU_SIM_PREVIEW_HEIGHT
	}
	return render_main_menu_preview_size_for_slot(slot)
}

render_main_menu_preview_size_for_rect :: proc(rect_width, rect_height: f32) -> (u32, u32) {
	source_w := max(rect_width, f32(MAIN_MENU_SIM_PREVIEW_WIDTH))
	source_h := max(rect_height, f32(MAIN_MENU_SIM_PREVIEW_HEIGHT))
	scale := f32(1)
	if source_w > f32(MAIN_MENU_SIM_PREVIEW_MAX_WIDTH) {
		scale = min(scale, f32(MAIN_MENU_SIM_PREVIEW_MAX_WIDTH) / source_w)
	}
	if source_h > f32(MAIN_MENU_SIM_PREVIEW_MAX_HEIGHT) {
		scale = min(scale, f32(MAIN_MENU_SIM_PREVIEW_MAX_HEIGHT) / source_h)
	}
	width := min(max(u32(source_w * scale), MAIN_MENU_SIM_PREVIEW_WIDTH), MAIN_MENU_SIM_PREVIEW_MAX_WIDTH)
	height := min(max(u32(source_h * scale), MAIN_MENU_SIM_PREVIEW_HEIGHT), MAIN_MENU_SIM_PREVIEW_MAX_HEIGHT)
	return width, height
}

render_main_menu_preview_size_for_mode :: proc(ctx: ^Render_Context, mode: App_Mode) -> (u32, u32) {
	_ = ctx
	_ = mode
	return MAIN_MENU_SIM_PREVIEW_WIDTH, MAIN_MENU_SIM_PREVIEW_HEIGHT
}

render_main_menu_preview_viewport_for_rect :: proc(ctx: ^Render_Context, rect, clip_rect: uifw.Rect, viewport: ^vk.Viewport, scissor: ^vk.Rect2D) -> bool {
	width := f32(ctx.vk_ctx.swapchain_extent.width)
	height := f32(ctx.vk_ctx.swapchain_extent.height)
	inset := f32(0)
	viewport_width := rect.w - inset * 2
	viewport_height := rect.h - inset * 2
	if viewport_width <= 0 || viewport_height <= 0 {
		return false
	}
	vx0 := rect.x + inset
	vy0 := rect.y + inset
	if vx0 + viewport_width > width {
		vx0 = width - viewport_width
	}
	if vy0 + viewport_height > height {
		vy0 = height - viewport_height
	}
	sx0 := max(clip_rect.x + inset, 0)
	sy0 := max(clip_rect.y + inset, 0)
	sx1 := min(clip_rect.x + clip_rect.w - inset, width)
	sy1 := min(clip_rect.y + clip_rect.h - inset, height)
	if sx1 <= sx0 || sy1 <= sy0 {
		return false
	}
	viewport^ = {
		x = vx0,
		y = vy0,
		width = viewport_width,
		height = viewport_height,
		minDepth = 0,
		maxDepth = 1,
	}
	scissor^ = {
		offset = {i32(sx0), i32(sy0)},
		extent = {u32(max(sx1 - sx0, 1)), u32(max(sy1 - sy0, 1))},
	}
	return true
}

render_pass_main_menu_preview_present :: proc(ctx: ^Render_Context) {
	if ctx.app_ui == nil || ctx.app_ui.main_menu_preview_slot_count <= 0 {
		return
	}
	count := min(ctx.app_ui.main_menu_preview_slot_count, MAIN_MENU_PREVIEW_SLOT_CAP)
	ctx.backend.last_main_menu_preview_visible_slot_count = u32(count)
	for i in 0 ..< count {
		render_pass_main_menu_preview_present_slot(ctx, ctx.app_ui.main_menu_preview_slots[i])
	}
}

render_pass_main_menu_preview_present_slot :: proc(ctx: ^Render_Context, slot: Main_Menu_Preview_Slot) {
	viewport: vk.Viewport
	scissor: vk.Rect2D
	if !render_main_menu_preview_viewport_for_rect(ctx, slot.rect, slot.clip_rect, &viewport, &scissor) {
		ctx.backend.last_main_menu_preview_skipped_present_count += 1
		return
	}
	if render_main_menu_preview_clear_slot_fallback(ctx, slot.fallback_color, scissor) {
		ctx.backend.last_main_menu_preview_fallback_fill_count += 1
	}
	#partial switch slot.mode {
	case .Gray_Scott:
		if ctx.preview_gray_scott != nil {
			gray_scott_gpu_draw_prepared_viewport(ctx.preview_gray_scott, ctx.vk_ctx, ctx.frame.command_buffer, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Slime_Mold:
		if ctx.preview_slime_gpu != nil {
			slime_gpu_draw_prepared_viewport(ctx.preview_slime_gpu, ctx.vk_ctx, ctx.frame, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Particle_Life:
		if ctx.preview_particle_life != nil {
			particle_life_gpu_draw_prepared_viewport(ctx.preview_particle_life, ctx.vk_ctx, ctx.frame, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Flow_Field:
		if ctx.preview_flow_gpu != nil {
			flow_gpu_draw_prepared_viewport(ctx.preview_flow_gpu, ctx.vk_ctx, ctx.frame, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Pellets:
		if ctx.preview_pellets_gpu != nil && ctx.preview_pellets_gpu.ready {
			pellets_gpu_draw_scene_viewport(ctx.preview_pellets_gpu, ctx.vk_ctx, ctx.frame.command_buffer, int(ctx.frame.frame_index), &ctx.preview_pellets_gpu.background_pipeline, &ctx.preview_pellets_gpu.render_pipeline, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Voronoi_CA:
		if ctx.preview_voronoi_gpu != nil {
			voronoi_gpu_draw_prepared_viewport(ctx.preview_voronoi_gpu, ctx.vk_ctx, ctx.frame, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Moire:
		if ctx.preview_moire_gpu != nil {
			moire_gpu_draw_prepared_viewport(ctx.preview_moire_gpu, ctx.vk_ctx, ctx.frame, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Vectors:
		if ctx.preview_vectors_gpu != nil {
			vectors_gpu_draw_prepared_viewport(ctx.preview_vectors_gpu, ctx.vk_ctx, ctx.frame, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	case .Primordial:
		if ctx.preview_primordial_gpu != nil {
			primordial_gpu_draw_prepared_viewport(ctx.preview_primordial_gpu, ctx.vk_ctx, ctx.frame, viewport, scissor)
		} else {
			ctx.backend.last_main_menu_preview_skipped_present_count += 1
		}
	}
}

render_main_menu_preview_clear_slot_fallback :: proc(ctx: ^Render_Context, color: uifw.Color, scissor: vk.Rect2D) -> bool {
	if scissor.extent.width == 0 || scissor.extent.height == 0 {
		return false
	}
	clear := vk.ClearAttachment {
		aspectMask = {.COLOR},
		colorAttachment = 0,
		clearValue = {
			color = {float32 = {color.r, color.g, color.b, color.a}},
		},
	}
	rect := vk.ClearRect {
		rect = scissor,
		baseArrayLayer = 0,
		layerCount = 1,
	}
	vk.CmdClearAttachments(ctx.frame.command_buffer, 1, &clear, 1, &rect)
	return true
}

render_context_scene_post_processing_settings :: proc(ctx: ^Render_Context) -> ^Post_Processing_Settings {
	if ctx == nil {
		return nil
	}
	#partial switch ctx.app_mode {
	case .Particle_Life:
		if ctx.particle_life != nil {
			return &ctx.particle_life.settings.post_processing
		}
	case .Primordial:
		if ctx.app_ui != nil {
			return &ctx.app_ui.primordial.primordial.post_processing
		}
	case .Pellets:
		if ctx.app_ui != nil {
			return &ctx.app_ui.pellets.pellets.post_processing
		}
	case .Flow_Field:
		if ctx.app_ui != nil {
			return &ctx.app_ui.flow_field.flow.post_processing
		}
	case .Slime_Mold:
		if ctx.app_ui != nil {
			return &ctx.app_ui.slime_mold.slime.post_processing
		}
	case .Voronoi_CA:
		if ctx.app_ui != nil {
			return &ctx.app_ui.voronoi_ca.voronoi.post_processing
		}
	case:
	}
	return nil
}

render_context_scene_blur_enabled :: proc(ctx: ^Render_Context) -> bool {
	settings := render_context_scene_post_processing_settings(ctx)
	return settings != nil && settings.blur_enabled && settings.blur_radius > 0
}

render_context_apply_scene_post_processing :: proc(ctx: ^Render_Context) {
	settings := render_context_scene_post_processing_settings(ctx)
	if settings == nil || !settings.blur_enabled || settings.blur_radius <= 0 {
		return
	}
	_ = post_processing_apply_blur(&ctx.backend.post_processing, ctx.vk_ctx, ctx.frame, settings)
}

render_pass_simulation_present :: proc(ctx: ^Render_Context, pass: ^Render_Pass_Node) -> bool {
	_ = pass
	engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "Simulation present")
	engine.gpu_profiler_begin_pass(ctx.vk_ctx, ctx.frame.command_buffer, ctx.frame, .Simulation_Present)
	defer engine.gpu_profiler_end_pass(ctx.vk_ctx, ctx.frame.command_buffer, ctx.frame, .Simulation_Present)
	defer engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
	clear_color := uifw.Color{0.09, 0.105, 0.125, 1}
	force_late_ui_overlay := video_capture_is_recording(ctx.video_capture) || render_context_scene_blur_enabled(ctx)
	draw_ui_in_pass := ui_renderer_has_overlay_work(&ctx.backend.ui) && !ui_renderer_needs_backdrop_capture(&ctx.backend.ui) && !force_late_ui_overlay
	ui_sink := render_backend_ui_sink(ctx.backend)
	if ctx.app_mode == .Main_Menu {
		engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, clear_color)
		main_menu_backdrop_draw(&ctx.backend.main_menu_backdrop, ctx.vk_ctx, ctx.frame, ctx.dt)
		render_pass_main_menu_preview_present(ctx)
		if draw_ui_in_pass {
			ui_start := time.tick_now()
			engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
			ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
			engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		}
		engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
		return true
	}
	if ctx.app_mode == .Particle_Life {
		if ctx.particle_life.gpu.ready {
			if draw_ui_in_pass {
				particle_life_gpu_present(ctx.particle_life, ctx.vk_ctx, ctx.frame, &ui_sink)
			} else {
				particle_life_gpu_present(ctx.particle_life, ctx.vk_ctx, ctx.frame, nil)
			}
		} else {
			engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, particle_life_clear_color(ctx.particle_life))
			if draw_ui_in_pass {
				ui_start := time.tick_now()
				engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
				ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
				engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
				ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
			}
			engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
		}
		render_context_apply_scene_post_processing(ctx)
		return true
	}
	if ctx.app_mode == .Vectors && ctx.app_ui != nil && ctx.vectors_gpu != nil {
		engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, vectors_clear_color(&ctx.app_ui.vectors.vectors))
		vectors_gpu_draw(ctx.vectors_gpu, ctx.vk_ctx, ctx.frame, &ctx.app_ui.vectors.vectors, ctx.app_ui.vectors.time)
		if draw_ui_in_pass {
			ui_start := time.tick_now()
			engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
			ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
			engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		}
		engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
		return true
	}
	if ctx.app_mode == .Moire && ctx.app_ui != nil && ctx.moire_gpu != nil {
		engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, clear_color)
		moire_gpu_present(ctx.moire_gpu, ctx.vk_ctx, ctx.frame)
		if draw_ui_in_pass {
			ui_start := time.tick_now()
			engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
			ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
			engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		}
		engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
		return true
	}
	if ctx.app_mode == .Primordial && ctx.app_ui != nil && ctx.primordial_gpu != nil {
		ui: ^Ui_Render_Sink
		if draw_ui_in_pass {
			ui = &ui_sink
			ui_start := time.tick_now()
			primordial_gpu_present(ctx.primordial_gpu, ctx.vk_ctx, ctx.frame, &ctx.app_ui.primordial, ui)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		} else {
			primordial_gpu_present(ctx.primordial_gpu, ctx.vk_ctx, ctx.frame, &ctx.app_ui.primordial, nil)
		}
		render_context_apply_scene_post_processing(ctx)
		return true
	}
	if ctx.app_mode == .Pellets && ctx.app_ui != nil && ctx.pellets_gpu != nil {
		ui: ^Ui_Render_Sink
		if draw_ui_in_pass {
			ui = &ui_sink
			ui_start := time.tick_now()
			pellets_gpu_present(ctx.pellets_gpu, ctx.vk_ctx, ctx.frame, &ctx.app_ui.pellets, ui)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		} else {
			pellets_gpu_present(ctx.pellets_gpu, ctx.vk_ctx, ctx.frame, &ctx.app_ui.pellets, nil)
		}
		render_context_apply_scene_post_processing(ctx)
		return true
	}
	if ctx.app_mode == .Flow_Field && ctx.app_ui != nil && ctx.flow_gpu != nil {
		engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, flow_clear_color(&ctx.app_ui.flow_field.flow))
		flow_gpu_present(ctx.flow_gpu, ctx.vk_ctx, ctx.frame)
		if draw_ui_in_pass {
			ui_start := time.tick_now()
			engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
			ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
			engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		}
		engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
		render_context_apply_scene_post_processing(ctx)
		return true
	}
	if ctx.app_mode == .Slime_Mold && ctx.app_ui != nil && ctx.slime_gpu != nil {
		engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, slime_clear_color(&ctx.app_ui.slime_mold.slime))
		slime_gpu_present(ctx.slime_gpu, ctx.vk_ctx, ctx.frame, &ctx.app_ui.slime_mold.camera)
		if draw_ui_in_pass {
			ui_start := time.tick_now()
			engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
			ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
			engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		}
		engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
		render_context_apply_scene_post_processing(ctx)
		return true
	}
	if ctx.app_mode == .Voronoi_CA && ctx.app_ui != nil && ctx.voronoi_gpu != nil {
		engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, voronoi_clear_color())
		voronoi_gpu_present(ctx.voronoi_gpu, ctx.vk_ctx, ctx.frame)
		if draw_ui_in_pass {
			ui_start := time.tick_now()
			engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
			ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
			engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
			ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
		}
		engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
		render_context_apply_scene_post_processing(ctx)
		return true
	}
	engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, clear_color)
	if ctx.app_mode == .Gray_Scott && gray_scott_ensure_gpu_runtime(ctx.sim, ctx.vk_ctx) {
		gray_scott_gpu_present(ctx.sim, ctx.vk_ctx, ctx.frame.command_buffer)
	}
	if draw_ui_in_pass {
		ui_start := time.tick_now()
		engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
		ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
		engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
		ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
	}
	engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
	return true
}

render_pass_ui_build :: proc(ctx: ^Render_Context, pass: ^Render_Pass_Node) -> bool {
	_ = pass
	start := time.tick_now()
	ok := ui_renderer_build(&ctx.backend.ui, ctx.vk_ctx, ctx.gui.commands[:])
	ctx.backend.last_ui_build_seconds = time.duration_seconds(time.tick_diff(start, time.tick_now()))
	return ok
}

render_pass_ui_overlay :: proc(ctx: ^Render_Context, pass: ^Render_Pass_Node) -> bool {
	_ = pass
	if !ui_renderer_has_overlay_work(&ctx.backend.ui) {
		return true
	}
	force_late_ui_overlay := video_capture_is_recording(ctx.video_capture) || render_context_scene_blur_enabled(ctx)
	if !force_late_ui_overlay && !ui_renderer_needs_backdrop_capture(&ctx.backend.ui) {
		return true
	}
	start := time.tick_now()
	engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
	engine.gpu_profiler_begin_pass(ctx.vk_ctx, ctx.frame.command_buffer, ctx.frame, .Ui_Overlay)
	defer engine.gpu_profiler_end_pass(ctx.vk_ctx, ctx.frame.command_buffer, ctx.frame, .Ui_Overlay)
	defer engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
	if !ui_renderer_prepare_backdrop_blur(&ctx.backend.ui, ctx.vk_ctx, ctx.frame) {
		vk_cmd_transition_swapchain_present_to_color(ctx.vk_ctx, ctx.frame)
	}
	engine.vk_cmd_begin_swapchain_render_pass_load(ctx.vk_ctx, ctx.frame)
	ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
	engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
	ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(start, time.tick_now()))
	return true
}
