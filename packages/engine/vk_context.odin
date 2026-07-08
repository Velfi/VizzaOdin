package engine

import uifw "../ui"

import "core:time"
import vk "vendor:vulkan"
import sdl "vendor:sdl3"

MAX_GPU_HEAPS :: 16
MAX_VK_EXTENSIONS :: 32
MAX_SWAPCHAIN_IMAGES :: 8
MAX_FRAMES_IN_FLIGHT :: 2
DEFAULT_REPORTED_BUDGET_CEILING :: 0.70
DEFAULT_HEAP_SIZE_CEILING :: 0.60
VK_DEBUG_FRAME_LOG_LIMIT :: u32(120)
VK_SHUTDOWN_FRAME_FENCE_TIMEOUT_NS :: u64(1_000_000_000)

Gpu_Memory_Heap :: struct {
	size: u64,
	usage: u64,
	budget: u64,
	ceiling: u64,
	has_budget: bool,
}

Gpu_Memory_Budget :: struct {
	heaps: [MAX_GPU_HEAPS]Gpu_Memory_Heap,
	heap_count: int,
	total_ceiling: u64,
	uses_memory_budget_ext: bool,
	override_fraction: f32,
}

Vk_Queue_Family_Indices :: struct {
	graphics: i32,
	compute: i32,
	present: i32,
}

Vk_Device_Caps :: struct {
	adapter_name: [128]u8,
	adapter_type: [32]u8,
	queue_families: Vk_Queue_Family_Indices,
	memory: Gpu_Memory_Budget,
	supports_memory_budget_ext: bool,
	supports_timestamp_queries: bool,
	timestamp_period: f32,
	swapchain_format: vk.Format,
	present_mode: vk.PresentModeKHR,
	swapchain_extent: vk.Extent2D,
}

Vk_Frame_State :: struct {
	command_pool: vk.CommandPool,
	command_buffer: vk.CommandBuffer,
	image_available: vk.Semaphore,
	render_finished: vk.Semaphore,
	in_flight: vk.Fence,
}

Vk_Frame :: struct {
	state: ^Vk_Frame_State,
	command_buffer: vk.CommandBuffer,
	image_index: u32,
	frame_index: u32,
}

Vk_Frame_Cpu_Timings :: struct {
	wait_fence_ms: f64,
	acquire_ms: f64,
	command_begin_ms: f64,
	end_command_ms: f64,
	queue_submit_ms: f64,
	queue_present_ms: f64,
}

Vk_Command_Shape_Counters :: struct {
	render_pass_count: u32,
	compute_dispatch_count: u32,
	draw_count: u32,
	pipeline_bind_count: u32,
	descriptor_bind_count: u32,
	pipeline_barrier_count: u32,
	transfer_copy_count: u32,
	ui_batch_count: u32,
	backdrop_blur_pass_count: u32,
}

Vk_Buffer :: struct {
	handle: vk.Buffer,
	memory: vk.DeviceMemory,
	size: vk.DeviceSize,
	mapped: rawptr,
}

Vk_Shader_Module :: struct {
	handle: vk.ShaderModule,
}

Vk_Graphics_Pipeline :: struct {
	layout: vk.PipelineLayout,
	pipeline: vk.Pipeline,
}

Vk_Compute_Pipeline :: struct {
	layout: vk.PipelineLayout,
	pipeline: vk.Pipeline,
}

Vk_Context :: struct {
	instance: vk.Instance,
	surface: vk.SurfaceKHR,
	physical_device: vk.PhysicalDevice,
	device: vk.Device,
	swapchain: vk.SwapchainKHR,
	swapchain_images: [MAX_SWAPCHAIN_IMAGES]vk.Image,
	swapchain_image_views: [MAX_SWAPCHAIN_IMAGES]vk.ImageView,
	swapchain_framebuffers: [MAX_SWAPCHAIN_IMAGES]vk.Framebuffer,
	swapchain_image_count: u32,
	swapchain_format: vk.Format,
	swapchain_extent: vk.Extent2D,
	render_pass: vk.RenderPass,
	render_pass_load: vk.RenderPass,
	frames: [MAX_FRAMES_IN_FLIGHT]Vk_Frame_State,
	upload_command_pool: vk.CommandPool,
	upload_command_buffer: vk.CommandBuffer,
	current_frame: u32,
	frame_resources_ready: bool,
	needs_swapchain_recreate: bool,
	graphics_queue: vk.Queue,
	compute_queue: vk.Queue,
	present_queue: vk.Queue,
	caps: Vk_Device_Caps,
	gpu_profiler: Gpu_Profiler,
	last_cpu_timings: Vk_Frame_Cpu_Timings,
	command_shape: Vk_Command_Shape_Counters,
	last_command_shape: Vk_Command_Shape_Counters,
	initialized: bool,
	capture_enabled: bool,
	supports_debug_utils: bool,
	debug_acquire_log_count: u32,
	debug_present_log_count: u32,
}

vk_context_init :: proc(ctx: ^Vk_Context, window: ^sdl.Window, width, height: i32, configured_ceiling_fraction: f32, capture_enabled := false) -> bool {
	ctx^ = {}
	ctx.capture_enabled = capture_enabled
	log_info("vk_context_init: requested_size=", width, "x", height, " capture_enabled=", capture_enabled)

	if !sdl.Vulkan_LoadLibrary(nil) {
		log_error("vk_context_init: SDL Vulkan_LoadLibrary failed")
		ctx.caps = vk_make_placeholder_caps(configured_ceiling_fraction)
		write_fixed_string(ctx.caps.adapter_name[:], "SDL could not load Vulkan library")
		return false
	}

	vk.load_proc_addresses(cast(rawptr)sdl.Vulkan_GetVkGetInstanceProcAddr())
	if vk.CreateInstance == nil {
		log_error("vk_context_init: vkCreateInstance unavailable after loading proc addresses")
		ctx.caps = vk_make_placeholder_caps(configured_ceiling_fraction)
		write_fixed_string(ctx.caps.adapter_name[:], "vkCreateInstance unavailable")
		return false
	}

	if !vk_create_instance(ctx) {
		log_error("vk_context_init: vk_create_instance failed")
		return false
	}
	vk.load_proc_addresses(ctx.instance)

	if !sdl.Vulkan_CreateSurface(window, ctx.instance, nil, &ctx.surface) {
		log_error("vk_context_init: SDL Vulkan_CreateSurface failed: ", sdl.GetError())
		return false
	}

	if !vk_pick_physical_device(ctx, configured_ceiling_fraction) {
		log_error("vk_context_init: vk_pick_physical_device failed")
		return false
	}
	log_info("vk_context_init: selected device=", fixed_string(ctx.caps.adapter_name[:]), " type=", fixed_string(ctx.caps.adapter_type[:]))
	log_debug("vk_context_init: queues graphics=", ctx.caps.queue_families.graphics, " compute=", ctx.caps.queue_families.compute, " present=", ctx.caps.queue_families.present)
	if !vk_create_logical_device(ctx) {
		log_error("vk_context_init: vk_create_logical_device failed")
		return false
	}
	vk.load_proc_addresses(ctx.device)

	if !vk_create_swapchain(ctx, width, height) {
		log_error("vk_context_init: vk_create_swapchain failed")
		return false
	}
	if !vk_create_frame_resources(ctx) {
		log_error("vk_context_init: vk_create_frame_resources failed")
		return false
	}
	if !gpu_profiler_init(ctx) {
		log_error("vk_context_init: gpu_profiler_init failed")
		return false
	}

	ctx.initialized = true
	log_info("vk_context_init: complete")
	return true
}

vk_context_destroy :: proc(ctx: ^Vk_Context) {
	total_start := time.tick_now()
	log_info("shutdown: vk context begin")
	if ctx.device != nil {
		step_start := time.tick_now()
		frame_fences_idle := vk_wait_for_frame_fences(ctx)
		when ODIN_OS == .Darwin {
			if frame_fences_idle {
				log_info("shutdown: vk DeviceWaitIdle skipped on Darwin after frame fence wait ms=", vk_elapsed_ms(step_start))
			} else {
				_ = vk.DeviceWaitIdle(ctx.device)
				log_info("shutdown: vk DeviceWaitIdle fallback ms=", vk_elapsed_ms(step_start))
			}
		} else {
			_ = vk.DeviceWaitIdle(ctx.device)
			log_info("shutdown: vk DeviceWaitIdle ms=", vk_elapsed_ms(step_start))
		}
		step_start = time.tick_now()
		gpu_profiler_destroy(ctx)
		log_info("shutdown: gpu profiler destroy ms=", vk_elapsed_ms(step_start))
		step_start = time.tick_now()
		vk_destroy_frame_resources(ctx)
		log_info("shutdown: vk frame resources destroy ms=", vk_elapsed_ms(step_start))
		step_start = time.tick_now()
		vk_destroy_swapchain_resources(ctx)
		log_info("shutdown: vk swapchain resources destroy ms=", vk_elapsed_ms(step_start))
		step_start = time.tick_now()
		vk.DestroyDevice(ctx.device, nil)
		log_info("shutdown: vk DestroyDevice ms=", vk_elapsed_ms(step_start))
	}
	if ctx.surface != vk.SurfaceKHR(0) && ctx.instance != nil {
		step_start := time.tick_now()
		vk.DestroySurfaceKHR(ctx.instance, ctx.surface, nil)
		log_info("shutdown: vk DestroySurfaceKHR ms=", vk_elapsed_ms(step_start))
	}
	if ctx.instance != nil {
		step_start := time.tick_now()
		vk.DestroyInstance(ctx.instance, nil)
		log_info("shutdown: vk DestroyInstance ms=", vk_elapsed_ms(step_start))
	}
	step_start := time.tick_now()
	sdl.Vulkan_UnloadLibrary()
	log_info("shutdown: SDL Vulkan_UnloadLibrary ms=", vk_elapsed_ms(step_start))
	ctx^ = {}
	log_info("shutdown: vk context total ms=", vk_elapsed_ms(total_start))
}

vk_wait_for_frame_fences :: proc(ctx: ^Vk_Context) -> bool {
	if ctx.device == nil || !ctx.frame_resources_ready {
		return true
	}
	all_idle := true
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		frame := &ctx.frames[i]
		if frame.in_flight == vk.Fence(0) {
			continue
		}
		step_start := time.tick_now()
		status := vk.GetFenceStatus(ctx.device, frame.in_flight)
		if status == .NOT_READY {
			status = vk.WaitForFences(ctx.device, 1, &frame.in_flight, true, VK_SHUTDOWN_FRAME_FENCE_TIMEOUT_NS)
		}
		elapsed_ms := vk_elapsed_ms(step_start)
		if status == .SUCCESS {
			log_info("shutdown: vk frame fence idle index=", i, " ms=", elapsed_ms)
		} else {
			all_idle = false
			log_warn("shutdown: vk frame fence wait incomplete index=", i, " result=", status, " ms=", elapsed_ms)
		}
	}
	return all_idle
}

vk_make_placeholder_caps :: proc(configured_ceiling_fraction: f32) -> Vk_Device_Caps {
	caps: Vk_Device_Caps
	write_fixed_string(caps.adapter_name[:], "Vulkan device selection pending")
	write_fixed_string(caps.adapter_type[:], "Unknown")
	caps.queue_families = {-1, -1, -1}
	caps.memory = gpu_memory_budget_from_heaps(
		sizes = []u64{8 * 1024 * 1024 * 1024},
		usages = []u64{0},
		budgets = []u64{6 * 1024 * 1024 * 1024},
		has_budget = true,
		override_fraction = configured_ceiling_fraction,
	)
	caps.supports_memory_budget_ext = true
	return caps
}

vk_create_instance :: proc(ctx: ^Vk_Context) -> bool {
	sdl_ext_count: sdl.Uint32
	sdl_exts := sdl.Vulkan_GetInstanceExtensions(&sdl_ext_count)
	if sdl_exts == nil || sdl_ext_count == 0 {
		ctx.caps = vk_make_placeholder_caps(0)
		write_fixed_string(ctx.caps.adapter_name[:], "SDL returned no Vulkan instance extensions")
		return false
	}

	extensions: [MAX_VK_EXTENSIONS]cstring
	extension_count: u32
	for i in 0 ..< int(sdl_ext_count) {
		if extension_count < MAX_VK_EXTENSIONS {
			extensions[extension_count] = sdl_exts[i]
			extension_count += 1
		}
	}
	if vk_instance_extension_available(vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME) && extension_count < MAX_VK_EXTENSIONS {
		extensions[extension_count] = vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME
		extension_count += 1
	}
	if vk_instance_extension_available(vk.EXT_DEBUG_UTILS_EXTENSION_NAME) && extension_count < MAX_VK_EXTENSIONS {
		extensions[extension_count] = vk.EXT_DEBUG_UTILS_EXTENSION_NAME
		extension_count += 1
	}

	app_info := vk.ApplicationInfo {
		sType = .APPLICATION_INFO,
		pApplicationName = "VizzaOdin",
		applicationVersion = vk_make_version(0, 1, 0),
		pEngineName = "VizzaOdin",
		engineVersion = vk_make_version(0, 1, 0),
		apiVersion = vk_make_version(1, 2, 0),
	}
	create_info := vk.InstanceCreateInfo {
		sType = .INSTANCE_CREATE_INFO,
		flags = {.ENUMERATE_PORTABILITY_KHR},
		pApplicationInfo = &app_info,
		enabledExtensionCount = extension_count,
		ppEnabledExtensionNames = raw_data(extensions[:]),
	}

	return vk.CreateInstance(&create_info, nil, &ctx.instance) == .SUCCESS
}

vk_instance_extension_available :: proc(name: string) -> bool {
	count: u32
	if vk.EnumerateInstanceExtensionProperties(nil, &count, nil) != .SUCCESS || count == 0 {
		return false
	}

	props, alloc_err := make([]vk.ExtensionProperties, int(count), context.temp_allocator)
	if alloc_err != nil {
		return false
	}
	if vk.EnumerateInstanceExtensionProperties(nil, &count, raw_data(props)) != .SUCCESS {
		return false
	}
	for i in 0 ..< len(props) {
		if fixed_string(props[i].extensionName[:]) == name {
			return true
		}
	}
	return false
}

vk_pick_physical_device :: proc(ctx: ^Vk_Context, configured_ceiling_fraction: f32) -> bool {
	count: u32
	if vk.EnumeratePhysicalDevices(ctx.instance, &count, nil) != .SUCCESS || count == 0 {
		ctx.caps = vk_make_placeholder_caps(configured_ceiling_fraction)
		write_fixed_string(ctx.caps.adapter_name[:], "No Vulkan physical devices found")
		return false
	}

	devices, alloc_err := make([]vk.PhysicalDevice, int(count), context.temp_allocator)
	if alloc_err != nil {
		return false
	}
	if vk.EnumeratePhysicalDevices(ctx.instance, &count, raw_data(devices)) != .SUCCESS {
		return false
	}

	for device in devices {
		indices := vk_find_queue_families(device, ctx.surface)
		if indices.graphics >= 0 && indices.compute >= 0 && indices.present >= 0 && vk_device_extension_available(device, vk.KHR_SWAPCHAIN_EXTENSION_NAME) {
			ctx.physical_device = device
			ctx.caps.queue_families = indices
			vk_fill_device_caps(ctx, configured_ceiling_fraction)
			return true
		}
	}

	ctx.caps = vk_make_placeholder_caps(configured_ceiling_fraction)
	write_fixed_string(ctx.caps.adapter_name[:], "No Vulkan device supports graphics, compute, present, and swapchain")
	return false
}

vk_find_queue_families :: proc(device: vk.PhysicalDevice, surface: vk.SurfaceKHR) -> Vk_Queue_Family_Indices {
	indices := Vk_Queue_Family_Indices{-1, -1, -1}
	count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, nil)
	if count == 0 {
		return indices
	}

	props, alloc_err := make([]vk.QueueFamilyProperties, int(count), context.temp_allocator)
	if alloc_err != nil {
		return indices
	}
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, raw_data(props))

	found_graphics_present := false
	for i in 0 ..< int(count) {
		queue := props[i]
		if indices.graphics < 0 && .GRAPHICS in queue.queueFlags {
			indices.graphics = i32(i)
		}
		if indices.compute < 0 && .COMPUTE in queue.queueFlags {
			indices.compute = i32(i)
		}
		supported: b32
		if vk.GetPhysicalDeviceSurfaceSupportKHR(device, u32(i), surface, &supported) == .SUCCESS && supported {
			if indices.present < 0 {
				indices.present = i32(i)
			}
			if !found_graphics_present && .GRAPHICS in queue.queueFlags {
				indices.graphics = i32(i)
				indices.present = i32(i)
				found_graphics_present = true
			}
		}
	}
	return indices
}

vk_device_extension_available :: proc(device: vk.PhysicalDevice, name: string) -> bool {
	count: u32
	if vk.EnumerateDeviceExtensionProperties(device, nil, &count, nil) != .SUCCESS || count == 0 {
		return false
	}
	props, alloc_err := make([]vk.ExtensionProperties, int(count), context.temp_allocator)
	if alloc_err != nil {
		return false
	}
	if vk.EnumerateDeviceExtensionProperties(device, nil, &count, raw_data(props)) != .SUCCESS {
		return false
	}
	for i in 0 ..< len(props) {
		if fixed_string(props[i].extensionName[:]) == name {
			return true
		}
	}
	return false
}

vk_create_logical_device :: proc(ctx: ^Vk_Context) -> bool {
	priority := f32(1)
	unique: [3]u32
	unique_count: u32
	vk_push_unique_queue(&unique, &unique_count, u32(ctx.caps.queue_families.graphics))
	vk_push_unique_queue(&unique, &unique_count, u32(ctx.caps.queue_families.compute))
	vk_push_unique_queue(&unique, &unique_count, u32(ctx.caps.queue_families.present))

	queue_infos: [3]vk.DeviceQueueCreateInfo
	for i in 0 ..< unique_count {
		queue_infos[i] = vk.DeviceQueueCreateInfo {
			sType = .DEVICE_QUEUE_CREATE_INFO,
			queueFamilyIndex = unique[i],
			queueCount = 1,
			pQueuePriorities = &priority,
		}
	}

	extensions: [2]cstring
	extension_count: u32
	extensions[extension_count] = vk.KHR_SWAPCHAIN_EXTENSION_NAME
	extension_count += 1
	if vk_device_extension_available(ctx.physical_device, vk.KHR_PORTABILITY_SUBSET_EXTENSION_NAME) {
		extensions[extension_count] = vk.KHR_PORTABILITY_SUBSET_EXTENSION_NAME
		extension_count += 1
	}
	create_info := vk.DeviceCreateInfo {
		sType = .DEVICE_CREATE_INFO,
		queueCreateInfoCount = unique_count,
		pQueueCreateInfos = raw_data(queue_infos[:]),
		enabledExtensionCount = extension_count,
		ppEnabledExtensionNames = raw_data(extensions[:]),
	}
	if vk.CreateDevice(ctx.physical_device, &create_info, nil, &ctx.device) != .SUCCESS {
		return false
	}

	vk.GetDeviceQueue(ctx.device, u32(ctx.caps.queue_families.graphics), 0, &ctx.graphics_queue)
	vk.GetDeviceQueue(ctx.device, u32(ctx.caps.queue_families.compute), 0, &ctx.compute_queue)
	vk.GetDeviceQueue(ctx.device, u32(ctx.caps.queue_families.present), 0, &ctx.present_queue)
	ctx.supports_debug_utils = vk.CmdBeginDebugUtilsLabelEXT != nil && vk.CmdEndDebugUtilsLabelEXT != nil
	return true
}

vk_begin_frame :: proc(ctx: ^Vk_Context) -> (Vk_Frame, bool) {
	frame: Vk_Frame
	if !ctx.initialized || !ctx.frame_resources_ready || ctx.needs_swapchain_recreate {
		if ctx.debug_acquire_log_count < VK_DEBUG_FRAME_LOG_LIMIT {
			log_debug("vk_begin_frame: skipped initialized=", ctx.initialized, " frame_resources_ready=", ctx.frame_resources_ready, " needs_swapchain_recreate=", ctx.needs_swapchain_recreate)
			ctx.debug_acquire_log_count += 1
		}
		return frame, false
	}

	frame_index := ctx.current_frame % MAX_FRAMES_IN_FLIGHT
	state := &ctx.frames[frame_index]
	ctx.last_cpu_timings = {}
	ctx.command_shape = {}
	wait_start := time.tick_now()
	_ = vk.WaitForFences(ctx.device, 1, &state.in_flight, true, 0xffffffffffffffff)
	ctx.last_cpu_timings.wait_fence_ms = vk_elapsed_ms(wait_start)
	gpu_profiler_collect_frame(ctx, frame_index)

	image_index: u32
	acquire_start := time.tick_now()
	acquire_result := vk.AcquireNextImageKHR(ctx.device, ctx.swapchain, 0xffffffffffffffff, state.image_available, vk.Fence(0), &image_index)
	ctx.last_cpu_timings.acquire_ms = vk_elapsed_ms(acquire_start)
	if ctx.debug_acquire_log_count < VK_DEBUG_FRAME_LOG_LIMIT {
		log_debug("vk_begin_frame: frame_slot=", frame_index, " acquire_result=", acquire_result, " image_index=", image_index, " wait_ms=", ctx.last_cpu_timings.wait_fence_ms, " acquire_ms=", ctx.last_cpu_timings.acquire_ms)
		ctx.debug_acquire_log_count += 1
	}
	if acquire_result == .ERROR_OUT_OF_DATE_KHR {
		log_warn("vk_begin_frame: acquire out of date")
		ctx.needs_swapchain_recreate = true
		return frame, false
	}
	if acquire_result != .SUCCESS && acquire_result != .SUBOPTIMAL_KHR {
		log_error("vk_begin_frame: acquire failed result=", acquire_result)
		return frame, false
	}
	if acquire_result == .SUBOPTIMAL_KHR {
		log_warn("vk_begin_frame: acquire suboptimal")
		ctx.needs_swapchain_recreate = true
	}

	command_begin_start := time.tick_now()
	_ = vk.ResetCommandPool(ctx.device, state.command_pool, {})

	begin_info := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = {.ONE_TIME_SUBMIT},
	}
	if vk.BeginCommandBuffer(state.command_buffer, &begin_info) != .SUCCESS {
		log_error("vk_begin_frame: BeginCommandBuffer failed")
		return frame, false
	}
	ctx.last_cpu_timings.command_begin_ms = vk_elapsed_ms(command_begin_start)

	frame = {
		state = state,
		command_buffer = state.command_buffer,
		image_index = image_index,
		frame_index = frame_index,
	}
	gpu_profiler_begin_frame(ctx, frame)
	return frame, true
}

vk_end_frame :: proc(ctx: ^Vk_Context, frame: Vk_Frame) -> bool {
	gpu_profiler_end_frame(ctx, frame)
	end_command_start := time.tick_now()
	end_result := vk.EndCommandBuffer(frame.command_buffer)
	if end_result != .SUCCESS {
		log_error("vk_end_frame: EndCommandBuffer failed result=", end_result, " image_index=", frame.image_index, " frame_slot=", frame.frame_index)
		return false
	}
	ctx.last_cpu_timings.end_command_ms = vk_elapsed_ms(end_command_start)

	wait_stage := vk.PipelineStageFlags{.COLOR_ATTACHMENT_OUTPUT}
	command_buffer := frame.command_buffer
	submit := vk.SubmitInfo {
		sType = .SUBMIT_INFO,
		waitSemaphoreCount = 1,
		pWaitSemaphores = &frame.state.image_available,
		pWaitDstStageMask = &wait_stage,
		commandBufferCount = 1,
		pCommandBuffers = &command_buffer,
		signalSemaphoreCount = 1,
		pSignalSemaphores = &frame.state.render_finished,
	}
	submit_start := time.tick_now()
	// Reset only once the frame is guaranteed to be submitted; resetting in
	// vk_begin_frame left the fence unsignaled forever when recording failed,
	// deadlocking the next frame's WaitForFences.
	_ = vk.ResetFences(ctx.device, 1, &frame.state.in_flight)
	submit_result := vk.QueueSubmit(ctx.graphics_queue, 1, &submit, frame.state.in_flight)
	ctx.last_cpu_timings.queue_submit_ms = vk_elapsed_ms(submit_start)
	if ctx.debug_present_log_count < VK_DEBUG_FRAME_LOG_LIMIT {
		log_debug("vk_end_frame: frame_slot=", frame.frame_index, " image_index=", frame.image_index, " submit_result=", submit_result, " end_cmd_ms=", ctx.last_cpu_timings.end_command_ms, " submit_ms=", ctx.last_cpu_timings.queue_submit_ms)
	}
	if submit_result != .SUCCESS {
		log_error("vk_end_frame: QueueSubmit failed result=", submit_result)
		return false
	}

	image_index := frame.image_index
	present := vk.PresentInfoKHR {
		sType = .PRESENT_INFO_KHR,
		waitSemaphoreCount = 1,
		pWaitSemaphores = &frame.state.render_finished,
		swapchainCount = 1,
		pSwapchains = &ctx.swapchain,
		pImageIndices = &image_index,
	}
	present_start := time.tick_now()
	present_result := vk.QueuePresentKHR(ctx.present_queue, &present)
	ctx.last_cpu_timings.queue_present_ms = vk_elapsed_ms(present_start)
	ctx.last_command_shape = ctx.command_shape
	queue_idle_result := vk.Result.SUCCESS
	if ctx.debug_present_log_count < VK_DEBUG_FRAME_LOG_LIMIT {
		log_debug("vk_end_frame: frame_slot=", frame.frame_index, " image_index=", frame.image_index, " present_result=", present_result, " queue_idle_result=", queue_idle_result, " present_ms=", ctx.last_cpu_timings.queue_present_ms)
		ctx.debug_present_log_count += 1
	}
	if present_result == .ERROR_OUT_OF_DATE_KHR || present_result == .SUBOPTIMAL_KHR {
		log_warn("vk_end_frame: present requires swapchain recreate result=", present_result)
		ctx.needs_swapchain_recreate = true
	} else if present_result != .SUCCESS {
		log_error("vk_end_frame: QueuePresent failed result=", present_result)
		return false
	}
	ctx.current_frame = (ctx.current_frame + 1) % MAX_FRAMES_IN_FLIGHT
	return true
}

// One-off uploads must use this dedicated command buffer: recycling a frame's
// command pool mid-recording silently invalidates the in-flight frame command
// buffer (MoltenVK reports it as NOT_READY from vkEndCommandBuffer).
vk_begin_upload_commands :: proc(ctx: ^Vk_Context) -> (vk.CommandBuffer, bool) {
	if ctx.upload_command_buffer == nil {
		return nil, false
	}
	_ = vk.ResetCommandPool(ctx.device, ctx.upload_command_pool, {})
	begin := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = {.ONE_TIME_SUBMIT},
	}
	if vk.BeginCommandBuffer(ctx.upload_command_buffer, &begin) != .SUCCESS {
		return nil, false
	}
	return ctx.upload_command_buffer, true
}

vk_submit_upload_commands :: proc(ctx: ^Vk_Context) -> bool {
	if vk.EndCommandBuffer(ctx.upload_command_buffer) != .SUCCESS {
		return false
	}
	command_buffer := ctx.upload_command_buffer
	submit := vk.SubmitInfo {
		sType = .SUBMIT_INFO,
		commandBufferCount = 1,
		pCommandBuffers = &command_buffer,
	}
	if vk.QueueSubmit(ctx.graphics_queue, 1, &submit, vk.Fence(0)) != .SUCCESS {
		return false
	}
	_ = vk.QueueWaitIdle(ctx.graphics_queue)
	return true
}

vk_elapsed_ms :: proc(start: time.Tick) -> f64 {
	return time.duration_seconds(time.tick_diff(start, time.tick_now())) * 1000.0
}

vk_cmd_begin_swapchain_render_pass :: proc(ctx: ^Vk_Context, frame: Vk_Frame, clear_color: uifw.Color) {
	clear := vk.ClearValue{color = {float32 = {clear_color.r, clear_color.g, clear_color.b, clear_color.a}}}
	render_area := vk.Rect2D {
		offset = {0, 0},
		extent = ctx.swapchain_extent,
	}
	rp_begin := vk.RenderPassBeginInfo {
		sType = .RENDER_PASS_BEGIN_INFO,
		renderPass = ctx.render_pass,
		framebuffer = ctx.swapchain_framebuffers[frame.image_index],
		renderArea = render_area,
		clearValueCount = 1,
		pClearValues = &clear,
	}
	vk.CmdBeginRenderPass(frame.command_buffer, &rp_begin, .INLINE)
	ctx.command_shape.render_pass_count += 1
}

vk_cmd_begin_swapchain_render_pass_load :: proc(ctx: ^Vk_Context, frame: Vk_Frame) {
	clear := vk.ClearValue{}
	render_area := vk.Rect2D {
		offset = {0, 0},
		extent = ctx.swapchain_extent,
	}
	rp_begin := vk.RenderPassBeginInfo {
		sType = .RENDER_PASS_BEGIN_INFO,
		renderPass = ctx.render_pass_load,
		framebuffer = ctx.swapchain_framebuffers[frame.image_index],
		renderArea = render_area,
		clearValueCount = 1,
		pClearValues = &clear,
	}
	vk.CmdBeginRenderPass(frame.command_buffer, &rp_begin, .INLINE)
	ctx.command_shape.render_pass_count += 1
}

vk_cmd_end_swapchain_render_pass :: proc(frame: Vk_Frame) {
	vk.CmdEndRenderPass(frame.command_buffer)
}

vk_recreate_swapchain :: proc(ctx: ^Vk_Context, width, height: i32) -> bool {
	if ctx.device == nil {
		return false
	}
	_ = vk.DeviceWaitIdle(ctx.device)
	vk_destroy_swapchain_resources(ctx)
	if !vk_create_swapchain(ctx, width, height) {
		ctx.needs_swapchain_recreate = true
		return false
	}
	ctx.needs_swapchain_recreate = false
	return true
}

vk_push_unique_queue :: proc(values: ^[3]u32, count: ^u32, value: u32) {
	for i in 0 ..< count^ {
		if values[i] == value {
			return
		}
	}
	values[count^] = value
	count^ += 1
}

vk_fill_device_caps :: proc(ctx: ^Vk_Context, configured_ceiling_fraction: f32) {
	props: vk.PhysicalDeviceProperties
	vk.GetPhysicalDeviceProperties(ctx.physical_device, &props)
	write_fixed_string(ctx.caps.adapter_name[:], fixed_string(props.deviceName[:]))
	write_fixed_string(ctx.caps.adapter_type[:], vk_device_type_name(props.deviceType))
	ctx.caps.supports_timestamp_queries = props.limits.timestampComputeAndGraphics == true && props.limits.timestampPeriod > 0
	ctx.caps.timestamp_period = props.limits.timestampPeriod
	ctx.caps.supports_memory_budget_ext = vk_device_extension_available(ctx.physical_device, vk.EXT_MEMORY_BUDGET_EXTENSION_NAME)
	ctx.caps.memory = vk_query_memory_budget(ctx.physical_device, ctx.caps.supports_memory_budget_ext, configured_ceiling_fraction)
}

vk_device_type_name :: proc(t: vk.PhysicalDeviceType) -> string {
	#partial switch t {
	case .DISCRETE_GPU:
		return "Discrete GPU"
	case .INTEGRATED_GPU:
		return "Integrated GPU"
	case .VIRTUAL_GPU:
		return "Virtual GPU"
	case .CPU:
		return "CPU"
	}
	return "Other"
}

vk_query_memory_budget :: proc(device: vk.PhysicalDevice, has_budget: bool, configured_ceiling_fraction: f32) -> Gpu_Memory_Budget {
	mem_props: vk.PhysicalDeviceMemoryProperties
	budget_props: vk.PhysicalDeviceMemoryBudgetPropertiesEXT

	if has_budget && vk.GetPhysicalDeviceMemoryProperties2 != nil {
		budget_props.sType = .PHYSICAL_DEVICE_MEMORY_BUDGET_PROPERTIES_EXT
		props2 := vk.PhysicalDeviceMemoryProperties2 {
			sType = .PHYSICAL_DEVICE_MEMORY_PROPERTIES_2,
			pNext = &budget_props,
		}
		vk.GetPhysicalDeviceMemoryProperties2(device, &props2)
		mem_props = props2.memoryProperties
	} else {
		vk.GetPhysicalDeviceMemoryProperties(device, &mem_props)
	}

	sizes: [MAX_GPU_HEAPS]u64
	usages: [MAX_GPU_HEAPS]u64
	budgets: [MAX_GPU_HEAPS]u64
	heap_count := min(int(mem_props.memoryHeapCount), MAX_GPU_HEAPS)
	for i in 0 ..< heap_count {
		sizes[i] = u64(mem_props.memoryHeaps[i].size)
		if has_budget {
			usages[i] = u64(budget_props.heapUsage[i])
			budgets[i] = u64(budget_props.heapBudget[i])
		}
	}
	return gpu_memory_budget_from_heaps(sizes[:heap_count], usages[:heap_count], budgets[:heap_count], has_budget, configured_ceiling_fraction)
}

vk_create_swapchain :: proc(ctx: ^Vk_Context, width, height: i32) -> bool {
	caps: vk.SurfaceCapabilitiesKHR
	if vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(ctx.physical_device, ctx.surface, &caps) != .SUCCESS {
		return false
	}

	format := vk_choose_surface_format(ctx.physical_device, ctx.surface)
	present_mode := vk_choose_present_mode(ctx.physical_device, ctx.surface, ctx.capture_enabled)
	extent := vk_choose_extent(caps, width, height)
	usage := vk_swapchain_image_usage(ctx, caps)

	image_count := caps.minImageCount + 1
	if caps.maxImageCount > 0 && image_count > caps.maxImageCount {
		image_count = caps.maxImageCount
	}
	if image_count > MAX_SWAPCHAIN_IMAGES {
		image_count = MAX_SWAPCHAIN_IMAGES
	}
	log_debug("vk_create_swapchain: surface current_extent=", caps.currentExtent.width, "x", caps.currentExtent.height, " min_extent=", caps.minImageExtent.width, "x", caps.minImageExtent.height, " max_extent=", caps.maxImageExtent.width, "x", caps.maxImageExtent.height)
	log_debug("vk_create_swapchain: requested=", width, "x", height, " chosen_extent=", extent.width, "x", extent.height, " min_images=", caps.minImageCount, " max_images=", caps.maxImageCount, " requested_images=", image_count)
	log_debug("vk_create_swapchain: format=", format.format, " color_space=", format.colorSpace, " present_mode=", present_mode, " usage=", usage, " supported_usage=", caps.supportedUsageFlags, " capture_enabled=", ctx.capture_enabled)

	queue_indices := [?]u32{u32(ctx.caps.queue_families.graphics), u32(ctx.caps.queue_families.present)}
	sharing_mode := vk.SharingMode.EXCLUSIVE
	queue_index_count: u32
	queue_index_ptr: [^]u32
	if ctx.caps.queue_families.graphics != ctx.caps.queue_families.present {
		sharing_mode = .CONCURRENT
		queue_index_count = 2
		queue_index_ptr = raw_data(queue_indices[:])
	}

	create_info := vk.SwapchainCreateInfoKHR {
		sType = .SWAPCHAIN_CREATE_INFO_KHR,
		surface = ctx.surface,
		minImageCount = image_count,
		imageFormat = format.format,
		imageColorSpace = format.colorSpace,
		imageExtent = extent,
		imageArrayLayers = 1,
		imageUsage = usage,
		imageSharingMode = sharing_mode,
		queueFamilyIndexCount = queue_index_count,
		pQueueFamilyIndices = queue_index_ptr,
		preTransform = caps.currentTransform,
		compositeAlpha = {.OPAQUE},
		presentMode = present_mode,
		clipped = true,
	}
	create_result := vk.CreateSwapchainKHR(ctx.device, &create_info, nil, &ctx.swapchain)
	log_debug("vk_create_swapchain: CreateSwapchainKHR result=", create_result)
	if create_result != .SUCCESS {
		return false
	}

	actual_count: u32
	get_count_result := vk.GetSwapchainImagesKHR(ctx.device, ctx.swapchain, &actual_count, nil)
	log_debug("vk_create_swapchain: GetSwapchainImages count result=", get_count_result, " count=", actual_count)
	if get_count_result != .SUCCESS {
		return false
	}
	if actual_count > MAX_SWAPCHAIN_IMAGES {
		actual_count = MAX_SWAPCHAIN_IMAGES
	}
	get_images_result := vk.GetSwapchainImagesKHR(ctx.device, ctx.swapchain, &actual_count, raw_data(ctx.swapchain_images[:]))
	log_debug("vk_create_swapchain: GetSwapchainImages data result=", get_images_result, " stored_count=", actual_count)
	if get_images_result != .SUCCESS {
		return false
	}

	ctx.swapchain_image_count = actual_count
	ctx.swapchain_format = format.format
	ctx.swapchain_extent = extent
	ctx.caps.swapchain_format = format.format
	ctx.caps.present_mode = present_mode
	ctx.caps.swapchain_extent = extent

	for i in 0 ..< actual_count {
		view_info := vk.ImageViewCreateInfo {
			sType = .IMAGE_VIEW_CREATE_INFO,
			image = ctx.swapchain_images[i],
			viewType = .D2,
			format = ctx.swapchain_format,
			components = {r = .IDENTITY, g = .IDENTITY, b = .IDENTITY, a = .IDENTITY},
			subresourceRange = {
				aspectMask = {.COLOR},
				baseMipLevel = 0,
				levelCount = 1,
				baseArrayLayer = 0,
				layerCount = 1,
			},
		}
			view_result := vk.CreateImageView(ctx.device, &view_info, nil, &ctx.swapchain_image_views[i])
			log_debug("vk_create_swapchain: image_view index=", i, " result=", view_result)
			if view_result != .SUCCESS {
				return false
			}
		}

		if !vk_create_render_pass(ctx) {
			log_error("vk_create_swapchain: render pass creation failed")
			return false
		}
		if !vk_create_framebuffers(ctx) {
			log_error("vk_create_swapchain: framebuffer creation failed")
			return false
		}
		log_debug("vk_create_swapchain: ready image_count=", ctx.swapchain_image_count, " extent=", ctx.swapchain_extent.width, "x", ctx.swapchain_extent.height)

		return true
	}

vk_create_render_pass_variant :: proc(ctx: ^Vk_Context, load_op: vk.AttachmentLoadOp, initial_layout: vk.ImageLayout, out: ^vk.RenderPass) -> bool {
	attachment := vk.AttachmentDescription {
		format = ctx.swapchain_format,
		samples = {._1},
		loadOp = load_op,
		storeOp = .STORE,
		stencilLoadOp = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout = initial_layout,
		finalLayout = .PRESENT_SRC_KHR,
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
	dependency := vk.SubpassDependency {
		srcSubpass = vk.SUBPASS_EXTERNAL,
		dstSubpass = 0,
		srcStageMask = {.COLOR_ATTACHMENT_OUTPUT},
		dstStageMask = {.COLOR_ATTACHMENT_OUTPUT},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
		dependencyFlags = {.BY_REGION},
	}
	info := vk.RenderPassCreateInfo {
		sType = .RENDER_PASS_CREATE_INFO,
		attachmentCount = 1,
		pAttachments = &attachment,
		subpassCount = 1,
		pSubpasses = &subpass,
		dependencyCount = 1,
		pDependencies = &dependency,
	}
	result := vk.CreateRenderPass(ctx.device, &info, nil, out)
	log_debug("vk_create_render_pass_variant: result=", result, " load_op=", load_op, " initial_layout=", initial_layout, " final_layout=", attachment.finalLayout)
	return result == .SUCCESS
}

vk_create_render_pass :: proc(ctx: ^Vk_Context) -> bool {
	if !vk_create_render_pass_variant(ctx, .CLEAR, .UNDEFINED, &ctx.render_pass) {
		return false
	}
	if !vk_create_render_pass_variant(ctx, .LOAD, .COLOR_ATTACHMENT_OPTIMAL, &ctx.render_pass_load) {
		return false
	}
	return true
}

vk_swapchain_image_usage :: proc(ctx: ^Vk_Context, caps: vk.SurfaceCapabilitiesKHR) -> vk.ImageUsageFlags {
	usage := vk.ImageUsageFlags{.COLOR_ATTACHMENT, .TRANSFER_DST}
	transfer_src := vk.ImageUsageFlags{.TRANSFER_SRC}
	if transfer_src <= caps.supportedUsageFlags {
		usage += transfer_src
	}
	return usage
}

vk_create_framebuffers :: proc(ctx: ^Vk_Context) -> bool {
	for i in 0 ..< ctx.swapchain_image_count {
		attachment := ctx.swapchain_image_views[i]
		info := vk.FramebufferCreateInfo {
			sType = .FRAMEBUFFER_CREATE_INFO,
			renderPass = ctx.render_pass,
			attachmentCount = 1,
			pAttachments = &attachment,
			width = ctx.swapchain_extent.width,
			height = ctx.swapchain_extent.height,
			layers = 1,
		}
			result := vk.CreateFramebuffer(ctx.device, &info, nil, &ctx.swapchain_framebuffers[i])
			log_debug("vk_create_framebuffers: index=", i, " result=", result, " size=", info.width, "x", info.height)
			if result != .SUCCESS {
				return false
			}
		}
	return true
}

vk_create_frame_resources :: proc(ctx: ^Vk_Context) -> bool {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		frame := &ctx.frames[i]
		pool_info := vk.CommandPoolCreateInfo {
			sType = .COMMAND_POOL_CREATE_INFO,
			flags = {.RESET_COMMAND_BUFFER},
			queueFamilyIndex = u32(ctx.caps.queue_families.graphics),
		}
		if vk.CreateCommandPool(ctx.device, &pool_info, nil, &frame.command_pool) != .SUCCESS {
			return false
		}
		alloc_info := vk.CommandBufferAllocateInfo {
			sType = .COMMAND_BUFFER_ALLOCATE_INFO,
			commandPool = frame.command_pool,
			level = .PRIMARY,
			commandBufferCount = 1,
		}
		if vk.AllocateCommandBuffers(ctx.device, &alloc_info, &frame.command_buffer) != .SUCCESS {
			return false
		}
		semaphore_info := vk.SemaphoreCreateInfo{sType = .SEMAPHORE_CREATE_INFO}
		if vk.CreateSemaphore(ctx.device, &semaphore_info, nil, &frame.image_available) != .SUCCESS {
			return false
		}
		if vk.CreateSemaphore(ctx.device, &semaphore_info, nil, &frame.render_finished) != .SUCCESS {
			return false
		}
		fence_info := vk.FenceCreateInfo {
			sType = .FENCE_CREATE_INFO,
			flags = {.SIGNALED},
		}
		if vk.CreateFence(ctx.device, &fence_info, nil, &frame.in_flight) != .SUCCESS {
			return false
		}
	}
	upload_pool_info := vk.CommandPoolCreateInfo {
		sType = .COMMAND_POOL_CREATE_INFO,
		flags = {.RESET_COMMAND_BUFFER},
		queueFamilyIndex = u32(ctx.caps.queue_families.graphics),
	}
	if vk.CreateCommandPool(ctx.device, &upload_pool_info, nil, &ctx.upload_command_pool) != .SUCCESS {
		return false
	}
	upload_alloc_info := vk.CommandBufferAllocateInfo {
		sType = .COMMAND_BUFFER_ALLOCATE_INFO,
		commandPool = ctx.upload_command_pool,
		level = .PRIMARY,
		commandBufferCount = 1,
	}
	if vk.AllocateCommandBuffers(ctx.device, &upload_alloc_info, &ctx.upload_command_buffer) != .SUCCESS {
		return false
	}
	ctx.frame_resources_ready = true
	return true
}

vk_destroy_frame_resources :: proc(ctx: ^Vk_Context) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		frame := &ctx.frames[i]
		if frame.in_flight != vk.Fence(0) {
			vk.DestroyFence(ctx.device, frame.in_flight, nil)
		}
		if frame.render_finished != vk.Semaphore(0) {
			vk.DestroySemaphore(ctx.device, frame.render_finished, nil)
		}
		if frame.image_available != vk.Semaphore(0) {
			vk.DestroySemaphore(ctx.device, frame.image_available, nil)
		}
		if frame.command_pool != vk.CommandPool(0) {
			vk.DestroyCommandPool(ctx.device, frame.command_pool, nil)
		}
		frame^ = {}
	}
	if ctx.upload_command_pool != vk.CommandPool(0) {
		vk.DestroyCommandPool(ctx.device, ctx.upload_command_pool, nil)
		ctx.upload_command_pool = vk.CommandPool(0)
		ctx.upload_command_buffer = nil
	}
	ctx.frame_resources_ready = false
}

vk_destroy_swapchain_resources :: proc(ctx: ^Vk_Context) {
	for i in 0 ..< ctx.swapchain_image_count {
		if ctx.swapchain_framebuffers[i] != vk.Framebuffer(0) {
			vk.DestroyFramebuffer(ctx.device, ctx.swapchain_framebuffers[i], nil)
			ctx.swapchain_framebuffers[i] = vk.Framebuffer(0)
		}
	}
	if ctx.render_pass != vk.RenderPass(0) {
		vk.DestroyRenderPass(ctx.device, ctx.render_pass, nil)
		ctx.render_pass = vk.RenderPass(0)
	}
	if ctx.render_pass_load != vk.RenderPass(0) {
		vk.DestroyRenderPass(ctx.device, ctx.render_pass_load, nil)
		ctx.render_pass_load = vk.RenderPass(0)
	}
	for i in 0 ..< ctx.swapchain_image_count {
		if ctx.swapchain_image_views[i] != vk.ImageView(0) {
			vk.DestroyImageView(ctx.device, ctx.swapchain_image_views[i], nil)
			ctx.swapchain_image_views[i] = vk.ImageView(0)
		}
	}
	if ctx.swapchain != vk.SwapchainKHR(0) {
		vk.DestroySwapchainKHR(ctx.device, ctx.swapchain, nil)
		ctx.swapchain = vk.SwapchainKHR(0)
	}
	ctx.swapchain_image_count = 0
}

vk_choose_surface_format :: proc(device: vk.PhysicalDevice, surface: vk.SurfaceKHR) -> vk.SurfaceFormatKHR {
	count: u32
	_ = vk.GetPhysicalDeviceSurfaceFormatsKHR(device, surface, &count, nil)
	if count == 0 {
		return {format = .B8G8R8A8_UNORM, colorSpace = .SRGB_NONLINEAR}
	}
	formats, alloc_err := make([]vk.SurfaceFormatKHR, int(count), context.temp_allocator)
	if alloc_err != nil {
		return {format = .B8G8R8A8_UNORM, colorSpace = .SRGB_NONLINEAR}
	}
	_ = vk.GetPhysicalDeviceSurfaceFormatsKHR(device, surface, &count, raw_data(formats))
	for format in formats {
		if format.format == .B8G8R8A8_SRGB && format.colorSpace == .SRGB_NONLINEAR {
			return format
		}
	}
	return formats[0]
}

vk_choose_present_mode :: proc(device: vk.PhysicalDevice, surface: vk.SurfaceKHR, profiling_capture: bool) -> vk.PresentModeKHR {
	count: u32
	_ = vk.GetPhysicalDeviceSurfacePresentModesKHR(device, surface, &count, nil)
	if count == 0 {
		return .FIFO
	}
	modes, alloc_err := make([]vk.PresentModeKHR, int(count), context.temp_allocator)
	if alloc_err != nil {
		return .FIFO
	}
	if vk.GetPhysicalDeviceSurfacePresentModesKHR(device, surface, &count, raw_data(modes)) != .SUCCESS {
		return .FIFO
	}
	if profiling_capture {
		for mode in modes {
			if mode == .FIFO {
				return .FIFO
			}
		}
	}
	for mode in modes {
		if mode == .MAILBOX {
			return .MAILBOX
		}
	}
	for mode in modes {
		if mode == .IMMEDIATE {
			return .IMMEDIATE
		}
	}
	return modes[0]
}

vk_present_mode_name :: proc(mode: vk.PresentModeKHR) -> string {
	#partial switch mode {
	case .IMMEDIATE:
		return "IMMEDIATE"
	case .MAILBOX:
		return "MAILBOX"
	case .FIFO:
		return "FIFO"
	case .FIFO_RELAXED:
		return "FIFO_RELAXED"
	}
	return "UNKNOWN"
}

vk_cmd_count_compute_dispatch :: proc(ctx: ^Vk_Context) {
	if ctx != nil {
		ctx.command_shape.compute_dispatch_count += 1
	}
}

vk_cmd_count_draw :: proc(ctx: ^Vk_Context) {
	if ctx != nil {
		ctx.command_shape.draw_count += 1
	}
}

vk_cmd_count_pipeline_bind :: proc(ctx: ^Vk_Context) {
	if ctx != nil {
		ctx.command_shape.pipeline_bind_count += 1
	}
}

vk_cmd_count_descriptor_bind :: proc(ctx: ^Vk_Context) {
	if ctx != nil {
		ctx.command_shape.descriptor_bind_count += 1
	}
}

vk_cmd_count_pipeline_barrier :: proc(ctx: ^Vk_Context, count: u32 = 1) {
	if ctx != nil {
		ctx.command_shape.pipeline_barrier_count += count
	}
}

vk_cmd_count_transfer_copy :: proc(ctx: ^Vk_Context) {
	if ctx != nil {
		ctx.command_shape.transfer_copy_count += 1
	}
}

vk_cmd_count_ui_batches :: proc(ctx: ^Vk_Context, count: u32) {
	if ctx != nil {
		ctx.command_shape.ui_batch_count += count
	}
}

vk_cmd_count_backdrop_blur_pass :: proc(ctx: ^Vk_Context) {
	if ctx != nil {
		ctx.command_shape.backdrop_blur_pass_count += 1
	}
}

vk_choose_extent :: proc(caps: vk.SurfaceCapabilitiesKHR, width, height: i32) -> vk.Extent2D {
	if caps.currentExtent.width != 0xffffffff {
		return caps.currentExtent
	}
	w := u32(max(width, 1))
	h := u32(max(height, 1))
	w = min(max(w, caps.minImageExtent.width), caps.maxImageExtent.width)
	h = min(max(h, caps.minImageExtent.height), caps.maxImageExtent.height)
	return {width = w, height = h}
}

vk_make_version :: proc(major, minor, patch: u32) -> u32 {
	return (major << 22) | (minor << 12) | patch
}

gpu_memory_budget_from_heaps :: proc(
	sizes: []u64,
	usages: []u64,
	budgets: []u64,
	has_budget: bool,
	override_fraction: f32,
) -> Gpu_Memory_Budget {
	result: Gpu_Memory_Budget
	result.heap_count = min(len(sizes), MAX_GPU_HEAPS)
	result.uses_memory_budget_ext = has_budget
	result.override_fraction = override_fraction

	for i in 0 ..< result.heap_count {
		heap := &result.heaps[i]
		heap.size = sizes[i]
		if i < len(usages) {
			heap.usage = usages[i]
		}
		if has_budget && i < len(budgets) {
			heap.budget = budgets[i]
		} else {
			heap.budget = heap.size
		}
		heap.has_budget = has_budget

		fraction := override_fraction
		if fraction <= 0 {
			fraction = has_budget ? DEFAULT_REPORTED_BUDGET_CEILING : DEFAULT_HEAP_SIZE_CEILING
		}
		if fraction > 1 {
			fraction = 1
		}

		base := heap.budget
		if !has_budget {
			base = heap.size
		}
		heap.ceiling = u64(f64(base) * f64(fraction) + 0.5)
		result.total_ceiling += heap.ceiling
	}

	return result
}
