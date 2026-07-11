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
