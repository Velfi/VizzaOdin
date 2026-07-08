package engine

import "core:os"
import vk "vendor:vulkan"

GPU_PROFILE_PASS_COUNT :: 4
GPU_PROFILE_QUERY_COUNT :: GPU_PROFILE_PASS_COUNT * 2

Gpu_Profile_Pass :: enum u32 {
	Frame,
	Simulation_Step,
	Simulation_Present,
	Ui_Overlay,
}

Gpu_Profile_Sample :: struct {
	supported: bool,
	enabled: bool,
	frame_ms: f64,
	simulation_step_ms: f64,
	simulation_present_ms: f64,
	ui_overlay_ms: f64,
}

Gpu_Profile_Frame_State :: struct {
	query_pool: vk.QueryPool,
	has_pending_results: bool,
}

Gpu_Profiler :: struct {
	frames: [MAX_FRAMES_IN_FLIGHT]Gpu_Profile_Frame_State,
	timestamp_period: f32,
	supported: bool,
	enabled: bool,
	last_sample: Gpu_Profile_Sample,
}

gpu_profiler_init :: proc(ctx: ^Vk_Context) -> bool {
	ctx.gpu_profiler = {}
	ctx.gpu_profiler.supported = ctx.caps.supports_timestamp_queries && ctx.caps.timestamp_period > 0 && vk.CreateQueryPool != nil && vk.GetQueryPoolResults != nil && vk.CmdWriteTimestamp != nil && vk.CmdResetQueryPool != nil
	ctx.gpu_profiler.last_sample.supported = ctx.gpu_profiler.supported
	if !ctx.gpu_profiler.supported {
		return true
	}

	if !gpu_profiler_env_enabled() {
		ctx.gpu_profiler.supported = false
		ctx.gpu_profiler.enabled = false
		ctx.gpu_profiler.last_sample.supported = false
		return true
	}

	ctx.gpu_profiler.timestamp_period = ctx.caps.timestamp_period
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		info := vk.QueryPoolCreateInfo {
			sType = .QUERY_POOL_CREATE_INFO,
			queryType = .TIMESTAMP,
			queryCount = GPU_PROFILE_QUERY_COUNT,
		}
		if vk.CreateQueryPool(ctx.device, &info, nil, &ctx.gpu_profiler.frames[i].query_pool) != .SUCCESS {
			log_warn("gpu_profiler_init: timestamp query pool creation failed; disabling GPU profiling")
			gpu_profiler_destroy(ctx)
			ctx.gpu_profiler.supported = false
			ctx.gpu_profiler.enabled = false
			ctx.gpu_profiler.last_sample.supported = false
			return true
		}
	}
	ctx.gpu_profiler.enabled = true
	ctx.gpu_profiler.last_sample.enabled = true
	log_info("gpu_profiler_init: enabled timestamp_period_ns=", ctx.gpu_profiler.timestamp_period)
	return true
}

gpu_profiler_env_enabled :: proc() -> bool {
	buf: [16]u8
	value := os.get_env_buf(buf[:], "VIZZA_GPU_PROFILER")
	switch value {
	case "1", "true", "TRUE", "True", "on", "ON", "On", "yes", "YES", "Yes":
		return true
	}
	return false
}

gpu_profiler_destroy :: proc(ctx: ^Vk_Context) {
	if ctx.device != nil {
		for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
			pool := ctx.gpu_profiler.frames[i].query_pool
			if pool != vk.QueryPool(0) {
				vk.DestroyQueryPool(ctx.device, pool, nil)
			}
		}
	}
	ctx.gpu_profiler = {}
}

gpu_profiler_collect_frame :: proc(ctx: ^Vk_Context, frame_slot: u32) {
	if !ctx.gpu_profiler.enabled || frame_slot >= MAX_FRAMES_IN_FLIGHT {
		return
	}
	frame := &ctx.gpu_profiler.frames[frame_slot]
	if !frame.has_pending_results || frame.query_pool == vk.QueryPool(0) {
		return
	}

	values: [GPU_PROFILE_QUERY_COUNT]u64
	result := vk.GetQueryPoolResults(
		ctx.device,
		frame.query_pool,
		0,
		GPU_PROFILE_QUERY_COUNT,
		size_of(values),
		raw_data(values[:]),
		vk.DeviceSize(size_of(u64)),
		{._64},
	)
	if result != .SUCCESS {
		return
	}

	sample := Gpu_Profile_Sample{supported = true, enabled = true}
	sample.frame_ms = gpu_profiler_delta_ms(ctx, values[0], values[1])
	sample.simulation_step_ms = gpu_profiler_delta_ms(ctx, values[2], values[3])
	sample.simulation_present_ms = gpu_profiler_delta_ms(ctx, values[4], values[5])
	sample.ui_overlay_ms = gpu_profiler_delta_ms(ctx, values[6], values[7])
	ctx.gpu_profiler.last_sample = sample
	frame.has_pending_results = false
}

gpu_profiler_begin_frame :: proc(ctx: ^Vk_Context, frame: Vk_Frame) {
	if !ctx.gpu_profiler.enabled {
		return
	}
	slot := frame.frame_index
	if slot >= MAX_FRAMES_IN_FLIGHT {
		return
	}
	pool := ctx.gpu_profiler.frames[slot].query_pool
	if pool == vk.QueryPool(0) {
		return
	}
	vk.CmdResetQueryPool(frame.command_buffer, pool, 0, GPU_PROFILE_QUERY_COUNT)
	gpu_profiler_write(ctx, frame.command_buffer, slot, .Frame, true)
}

gpu_profiler_end_frame :: proc(ctx: ^Vk_Context, frame: Vk_Frame) {
	if !ctx.gpu_profiler.enabled {
		return
	}
	slot := frame.frame_index
	if slot >= MAX_FRAMES_IN_FLIGHT {
		return
	}
	gpu_profiler_write(ctx, frame.command_buffer, slot, .Frame, false)
	ctx.gpu_profiler.frames[slot].has_pending_results = true
}

gpu_profiler_begin_pass :: proc(ctx: ^Vk_Context, cmd: vk.CommandBuffer, frame: Vk_Frame, pass: Gpu_Profile_Pass) {
	gpu_profiler_write(ctx, cmd, frame.frame_index, pass, true)
}

gpu_profiler_end_pass :: proc(ctx: ^Vk_Context, cmd: vk.CommandBuffer, frame: Vk_Frame, pass: Gpu_Profile_Pass) {
	gpu_profiler_write(ctx, cmd, frame.frame_index, pass, false)
}

gpu_profiler_last_sample :: proc(ctx: ^Vk_Context) -> Gpu_Profile_Sample {
	sample := ctx.gpu_profiler.last_sample
	sample.supported = ctx.gpu_profiler.supported
	sample.enabled = ctx.gpu_profiler.enabled
	return sample
}

gpu_profiler_write :: proc(ctx: ^Vk_Context, cmd: vk.CommandBuffer, frame_slot: u32, pass: Gpu_Profile_Pass, begin: bool) {
	if !ctx.gpu_profiler.enabled || frame_slot >= MAX_FRAMES_IN_FLIGHT {
		return
	}
	pool := ctx.gpu_profiler.frames[frame_slot].query_pool
	if pool == vk.QueryPool(0) {
		return
	}
	query := u32(pass) * 2
	stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	if !begin {
		query += 1
		stage = {.BOTTOM_OF_PIPE}
	}
	vk.CmdWriteTimestamp(cmd, stage, pool, query)
}

gpu_profiler_delta_ms :: proc(ctx: ^Vk_Context, start, finish: u64) -> f64 {
	if finish <= start {
		return 0
	}
	ns := f64(finish - start) * f64(ctx.gpu_profiler.timestamp_period)
	return ns / 1000000.0
}

vk_cmd_label_begin :: proc(ctx: ^Vk_Context, cmd: vk.CommandBuffer, name: cstring) {
	if !ctx.supports_debug_utils || vk.CmdBeginDebugUtilsLabelEXT == nil {
		return
	}
	label := vk.DebugUtilsLabelEXT {
		sType = .DEBUG_UTILS_LABEL_EXT,
		pLabelName = name,
		color = {0.35, 0.62, 1.0, 1.0},
	}
	vk.CmdBeginDebugUtilsLabelEXT(cmd, &label)
}

vk_cmd_label_end :: proc(ctx: ^Vk_Context, cmd: vk.CommandBuffer) {
	if !ctx.supports_debug_utils || vk.CmdEndDebugUtilsLabelEXT == nil {
		return
	}
	vk.CmdEndDebugUtilsLabelEXT(cmd)
}
