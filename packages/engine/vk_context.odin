package engine

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
	swapchain_supports_transfer_src: bool,
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
		pApplicationName = "Vizza",
		applicationVersion = vk_make_version(APP_VERSION_MAJOR, APP_VERSION_MINOR, APP_VERSION_PATCH),
		pEngineName = "VizzaOdin",
		engineVersion = vk_make_version(APP_VERSION_MAJOR, APP_VERSION_MINOR, APP_VERSION_PATCH),
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
