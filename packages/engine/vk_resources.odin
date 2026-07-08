package engine

import "core:os"
import "core:fmt"
import vk "vendor:vulkan"

vk_create_host_buffer :: proc(ctx: ^Vk_Context, size: vk.DeviceSize, usage: vk.BufferUsageFlags, out: ^Vk_Buffer) -> bool {
	out^ = {}
	info := vk.BufferCreateInfo {
		sType = .BUFFER_CREATE_INFO,
		size = size,
		usage = usage,
		sharingMode = .EXCLUSIVE,
	}
	if vk.CreateBuffer(ctx.device, &info, nil, &out.handle) != .SUCCESS {
		return false
	}

	req: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(ctx.device, out.handle, &req)
	memory_type, ok := vk_find_memory_type(ctx, req.memoryTypeBits, {.HOST_VISIBLE, .HOST_COHERENT})
	if !ok {
		vk.DestroyBuffer(ctx.device, out.handle, nil)
		out^ = {}
		return false
	}

	alloc := vk.MemoryAllocateInfo {
		sType = .MEMORY_ALLOCATE_INFO,
		allocationSize = req.size,
		memoryTypeIndex = memory_type,
	}
	if vk.AllocateMemory(ctx.device, &alloc, nil, &out.memory) != .SUCCESS {
		vk.DestroyBuffer(ctx.device, out.handle, nil)
		out^ = {}
		return false
	}
	if vk.BindBufferMemory(ctx.device, out.handle, out.memory, 0) != .SUCCESS {
		vk_destroy_buffer(ctx, out)
		return false
	}
	if vk.MapMemory(ctx.device, out.memory, 0, size, {}, &out.mapped) != .SUCCESS {
		vk_destroy_buffer(ctx, out)
		return false
	}

	out.size = size
	return true
}

vk_destroy_buffer :: proc(ctx: ^Vk_Context, buffer: ^Vk_Buffer) {
	if buffer.mapped != nil {
		vk.UnmapMemory(ctx.device, buffer.memory)
	}
	if buffer.handle != vk.Buffer(0) {
		vk.DestroyBuffer(ctx.device, buffer.handle, nil)
	}
	if buffer.memory != vk.DeviceMemory(0) {
		vk.FreeMemory(ctx.device, buffer.memory, nil)
	}
	buffer^ = {}
}

vk_find_memory_type :: proc(ctx: ^Vk_Context, type_bits: u32, required: vk.MemoryPropertyFlags) -> (u32, bool) {
	props: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(ctx.physical_device, &props)
	for i: u32 = 0; i < props.memoryTypeCount; i += 1 {
		if (type_bits & (1 << i)) != 0 && required <= props.memoryTypes[i].propertyFlags {
			return i, true
		}
	}
	return 0, false
}

vk_load_shader_module :: proc(ctx: ^Vk_Context, path: string, out: ^Vk_Shader_Module) -> bool {
	out^ = {}
	data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil || len(data) == 0 {
		return false
	}
	defer delete(data, context.allocator)
	if len(data) % 4 != 0 {
		return false
	}
	info := vk.ShaderModuleCreateInfo {
		sType = .SHADER_MODULE_CREATE_INFO,
		codeSize = len(data),
		pCode = cast(^u32)raw_data(data),
	}
	return vk.CreateShaderModule(ctx.device, &info, nil, &out.handle) == .SUCCESS
}

vk_load_shader_module_with_fallback :: proc(
	ctx: ^Vk_Context,
	source_path: string,
	base_path: string,
	stage: Shader_Stage,
	entry_point: string,
	out: ^Vk_Shader_Module,
) -> bool {
	if manifest_path := shader_spirv_path(source_path, stage, entry_point, ""); manifest_path != "" {
		if vk_load_shader_module(ctx, manifest_path, out) {
			return true
		}
	}
	base_spv := fmt.tprintf("%s.spv", base_path)
	if vk_load_shader_module(ctx, base_spv, out) {
		return true
	}
	stage_spv := fmt.tprintf("%s_%s.spv", base_path, shader_stage_suffix(stage))
	if vk_load_shader_module(ctx, stage_spv, out) {
		return true
	}
	return false
}

shader_stage_suffix :: proc(stage: Shader_Stage) -> string {
	#partial switch stage {
	case .Vertex:
		return "vertex"
	case .Fragment:
		return "fragment"
	case .Compute:
		return "compute"
	}
	return "unknown"
}

vk_destroy_shader_module :: proc(ctx: ^Vk_Context, shader: ^Vk_Shader_Module) {
	if shader.handle != vk.ShaderModule(0) {
		vk.DestroyShaderModule(ctx.device, shader.handle, nil)
	}
	shader^ = {}
}

vk_destroy_graphics_pipeline :: proc(ctx: ^Vk_Context, pipeline: ^Vk_Graphics_Pipeline) {
	if pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(ctx.device, pipeline.pipeline, nil)
	}
	if pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(ctx.device, pipeline.layout, nil)
	}
	pipeline^ = {}
}
