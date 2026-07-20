package render_vk

import uifw "zelda_engine:ui"
import engine "zelda_engine:engine"

import vk "vendor:vulkan"
import "core:c"
import "core:fmt"
import "core:math"
import "core:os"
import sdl "vendor:sdl3"

gray_scott_estimate_stable_timestep :: proc(sim: ^Gray_Scott_Simulation) -> f32 {
	// Forward Euler with the five-point 2D Laplacian requires dt * D <= 1/4.
	// Mask modulation is a [0, 1] multiplier, so the configured diffusion is
	// the maximum diffusion present anywhere in the field.
	max_diffusion := max(max(sim.settings.diffusion_a, sim.settings.diffusion_b), 0.0001)
	diffusion_limit := 0.25 / max_diffusion
	reaction_limit := 1.0 / max(1.0 + sim.settings.feed + sim.settings.kill, 0.0001)
	stable := min(diffusion_limit, reaction_limit) * max(sim.settings.stability_factor, 0.01)
	return min(max(stable, 0.0001), max(sim.settings.max_timestep, 0.0001))
}

gray_scott_apply_compute_mode_to_image :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, write_index: int, mode: u32, dt: f32) -> bool {
	read_index := 1 - write_index
	if gray_scott_gpu(sim).storage[read_index].layout != .GENERAL {
		gray_scott_transition_image(sim, vk_ctx, read_index, gray_scott_gpu(sim).storage[read_index].layout, .GENERAL, cmd)
	}
	if gray_scott_gpu(sim).storage[write_index].layout != .GENERAL {
		gray_scott_transition_image(sim, vk_ctx, write_index, gray_scott_gpu(sim).storage[write_index].layout, .GENERAL, cmd)
	}
	dispatch_slot, ok := gray_scott_next_compute_slot(sim)
	if !ok {
		engine.log_error("gray_scott_apply_compute_mode_to_image: compute dispatch slots exhausted")
		return false
	}
	gray_scott_write_params(sim, dispatch_slot, mode, dt)
	if !gray_scott_update_compute_descriptors(sim, vk_ctx, read_index, write_index, dispatch_slot) {
		return false
	}
	if !gray_scott_dispatch_compute(sim, vk_ctx, cmd, dispatch_slot) {
		return false
	}
	return true
}

gray_scott_apply_compute_mode_to_state :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, mode: u32, dt: f32) -> bool {
	if !gray_scott_apply_compute_mode_to_image(sim, vk_ctx, cmd, 0, mode, dt) {
		return false
	}
	if !gray_scott_apply_compute_mode_to_image(sim, vk_ctx, cmd, 1, mode, dt) {
		return false
	}
	gray_scott_gpu(sim).state_index = 0
	sim.runtime.pending_seed_mode = 0
	return true
}

gray_scott_step_compute_resources :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dt: f32) -> bool {
	gray_scott_gpu(sim).compute_dispatch_slot = 0
	if gray_scott_gpu(sim).compute_pipeline.pipeline == vk.Pipeline(0) || gray_scott_gpu(sim).compute_sets[0] == vk.DescriptorSet(0) || gray_scott_gpu(sim).compute_sets[1] == vk.DescriptorSet(0) {
		return false
	}
	for i := 0; i < 2; i += 1 {
		if gray_scott_gpu(sim).storage[i].handle == vk.Image(0) {
			return false
		}
	}
	if sim.runtime.webcam_active {
		_ = gray_scott_update_webcam_nutrient_map(sim)
	}

	if sim.runtime.pending_seed_mode != 0 {
		if !gray_scott_apply_compute_mode_to_state(sim, vk_ctx, cmd, sim.runtime.pending_seed_mode, 1.0) {
			return false
		}
	}
	if sim.runtime.paint_active {
		read_index := int(gray_scott_gpu(sim).state_index)
		write_index := 1 - read_index
		if !gray_scott_apply_compute_mode_to_image(sim, vk_ctx, cmd, write_index, GRAY_SCOTT_MODE_PAINT, 1.0) {
			return false
		}
		gray_scott_gpu(sim).state_index = u32(write_index)
	}
	if sim.settings.paused {
		return true
	}

	base_timestep := sim.settings.timestep
	speed := max(sim.settings.simulation_speed, 0.0)
	// Preserve the legacy apparent rate at 60 Hz while making evolution depend
	// on elapsed time rather than the number of rendered frames.
	total_step_dt := base_timestep * speed * dt * 60.0
	if total_step_dt <= 0 || dt <= 0 {
		return true
	}
	stable_dt := gray_scott_estimate_stable_timestep(sim)
	// Bound catch-up work after a long stall rather than taking an unstable step.
	total_step_dt = min(total_step_dt, stable_dt * f32(GRAY_SCOTT_MAX_STABLE_SUBSTEPS))
	substeps := max(int(math.ceil(total_step_dt / stable_dt)), 1)
	per_iteration_dt := total_step_dt / f32(substeps)

	read_index := int(gray_scott_gpu(sim).state_index)
	write_index := 1 - read_index

	for _ in 0 ..< substeps {
		if gray_scott_gpu(sim).storage[read_index].layout != .GENERAL {
			gray_scott_transition_image(sim, vk_ctx, read_index, gray_scott_gpu(sim).storage[read_index].layout, .GENERAL, cmd)
		}
		if gray_scott_gpu(sim).storage[write_index].layout != .GENERAL {
			gray_scott_transition_image(sim, vk_ctx, write_index, gray_scott_gpu(sim).storage[write_index].layout, .GENERAL, cmd)
		}
		dispatch_slot, ok := gray_scott_next_compute_slot(sim)
		if !ok {
			engine.log_error("gray_scott_step_compute_resources: compute dispatch slots exhausted")
			return false
		}
		gray_scott_write_params(sim, dispatch_slot, GRAY_SCOTT_MODE_STEP, per_iteration_dt)
		if !gray_scott_update_compute_descriptors(sim, vk_ctx, read_index, write_index, dispatch_slot) {
			return false
		}
		if !gray_scott_dispatch_compute(sim, vk_ctx, cmd, dispatch_slot) {
			return false
		}
		read_index, write_index = write_index, read_index
	}
	gray_scott_gpu(sim).state_index = u32(read_index)
	return true
}

gray_scott_gpu_step :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dt: f32) {
	if !gray_scott_ensure_gpu_runtime(sim, vk_ctx) {
		return
	}
	if sim.runtime.nutrient_upload_pending {
		gray_scott_upload_nutrient_map(sim)
	}
	_ = vk_ctx
	_ = gray_scott_step_compute_resources(sim, vk_ctx, cmd, dt)
}

gray_scott_shader_path_report :: proc(sim: ^Gray_Scott_Simulation, kind: string) -> string {
	if kind == "compute" {
		return gray_scott_gpu(sim).step_shader_spirv_path
	}
	return gray_scott_gpu(sim).present_shader_spirv_path
}

gray_scott_gpu_present :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	extent := vk_ctx.swapchain_extent
	viewport := vk.Viewport{x = 0, y = 0, width = f32(extent.width), height = f32(extent.height), minDepth = 0, maxDepth = 1}
	scissor := vk.Rect2D{offset = {0, 0}, extent = extent}
	gray_scott_gpu_present_viewport(sim, vk_ctx, cmd, viewport, scissor)
}

gray_scott_gpu_present_viewport :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if !gray_scott_gpu_prepare_present_viewport(sim, vk_ctx, cmd) {
		return
	}
	gray_scott_gpu_draw_prepared_viewport(sim, vk_ctx, cmd, viewport, scissor)
}

gray_scott_gpu_prepare_present_viewport :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) -> bool {
	if !gray_scott_ensure_gpu_runtime(sim, vk_ctx) {
		return false
	}

	if gray_scott_gpu(sim).present_pipeline.pipeline == vk.Pipeline(0) {
		return false
	}
	if gray_scott_gpu(sim).state_index >= 2 {
		return false
	}
	state_index := int(gray_scott_gpu(sim).state_index)
	extent := vk_ctx.swapchain_extent
	if extent.width == 0 || extent.height == 0 {
		return false
	}
	if state_index < 0 || state_index >= 2 {
		return false
	}
	if gray_scott_gpu(sim).storage[state_index].layout != .SHADER_READ_ONLY_OPTIMAL {
		gray_scott_transition_image(sim, vk_ctx, state_index, gray_scott_gpu(sim).storage[state_index].layout, .SHADER_READ_ONLY_OPTIMAL, cmd)
	}
	frame_slot := vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT
	gray_scott_gpu(sim).present_frame_slot = frame_slot
	gray_scott_sync_present_resources_for_slot(sim, frame_slot)
	if !gray_scott_update_present_descriptor(sim, vk_ctx, state_index, frame_slot) {
		return false
	}
	return true
}

gray_scott_gpu_draw_prepared_viewport :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if sim == nil || !gray_scott_gpu(sim).ready || gray_scott_gpu(sim).present_pipeline.pipeline == vk.Pipeline(0) {
		return
	}

	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(cmd, 0, 1, &local_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &local_scissor)
	vk.CmdBindPipeline(cmd, .GRAPHICS, gray_scott_gpu(sim).present_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	frame_slot := min(gray_scott_gpu(sim).present_frame_slot, u32(engine.MAX_FRAMES_IN_FLIGHT - 1))
	present_set := gray_scott_gpu(sim).present_sets[frame_slot]
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, gray_scott_gpu(sim).present_pipeline.layout, 0, 1, &present_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	tile_count := infinite_render_tile_count(sim.runtime.camera_zoom)
	vk.CmdDraw(cmd, 6, tile_count * tile_count, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
}

gray_scott_destroy :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) {
	gray_scott_stop_webcam(sim)
	if vk_ctx == nil || vk_ctx.device == nil {
		gray_scott_gpu(sim)^ = {}
		return
	}

	if gray_scott_gpu(sim).compute_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, gray_scott_gpu(sim).compute_pipeline.pipeline, nil)
		gray_scott_gpu(sim).compute_pipeline.pipeline = vk.Pipeline(0)
	}
	if gray_scott_gpu(sim).compute_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, gray_scott_gpu(sim).compute_pipeline.layout, nil)
		gray_scott_gpu(sim).compute_pipeline.layout = vk.PipelineLayout(0)
	}

	if gray_scott_gpu(sim).present_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &gray_scott_gpu(sim).present_pipeline)
	}

	if gray_scott_gpu(sim).compute_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gray_scott_gpu(sim).compute_set_layout, nil)
		gray_scott_gpu(sim).compute_set_layout = vk.DescriptorSetLayout(0)
	}
	if gray_scott_gpu(sim).present_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, gray_scott_gpu(sim).present_set_layout, nil)
		gray_scott_gpu(sim).present_set_layout = vk.DescriptorSetLayout(0)
	}
	if gray_scott_gpu(sim).compute_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, gray_scott_gpu(sim).compute_pool, nil)
		gray_scott_gpu(sim).compute_pool = vk.DescriptorPool(0)
	}
	if gray_scott_gpu(sim).present_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, gray_scott_gpu(sim).present_pool, nil)
		gray_scott_gpu(sim).present_pool = vk.DescriptorPool(0)
	}
	if gray_scott_gpu(sim).sampler != vk.Sampler(0) {
		vk.DestroySampler(vk_ctx.device, gray_scott_gpu(sim).sampler, nil)
		gray_scott_gpu(sim).sampler = vk.Sampler(0)
	}
	for i := 0; i < 2; i += 1 {
		if gray_scott_gpu(sim).storage[i].view != vk.ImageView(0) {
			vk.DestroyImageView(vk_ctx.device, gray_scott_gpu(sim).storage[i].view, nil)
		}
		if gray_scott_gpu(sim).storage[i].handle != vk.Image(0) {
			vk.DestroyImage(vk_ctx.device, gray_scott_gpu(sim).storage[i].handle, nil)
		}
		if gray_scott_gpu(sim).storage[i].memory != vk.DeviceMemory(0) {
			vk.FreeMemory(vk_ctx.device, gray_scott_gpu(sim).storage[i].memory, nil)
		}
		gray_scott_gpu(sim).storage[i] = {}
	}
	for i := 0; i < len(gray_scott_gpu(sim).params_buffers); i += 1 {
		if gray_scott_gpu(sim).params_buffers[i].handle != vk.Buffer(0) {
			engine.vk_destroy_buffer(vk_ctx, &gray_scott_gpu(sim).params_buffers[i])
		}
	}
	if gray_scott_gpu(sim).nutrient_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &gray_scott_gpu(sim).nutrient_buffer)
	}
	if gray_scott_gpu(sim).lut_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &gray_scott_gpu(sim).lut_buffer)
	}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if gray_scott_gpu(sim).present_params_buffers[i].handle != vk.Buffer(0) {
			engine.vk_destroy_buffer(vk_ctx, &gray_scott_gpu(sim).present_params_buffers[i])
		}
		if gray_scott_gpu(sim).camera_buffers[i].handle != vk.Buffer(0) {
			engine.vk_destroy_buffer(vk_ctx, &gray_scott_gpu(sim).camera_buffers[i])
		}
	}
	if gray_scott_gpu(sim).fullscreen_vertices.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &gray_scott_gpu(sim).fullscreen_vertices)
	}
	if gray_scott_gpu(sim).step_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &gray_scott_gpu(sim).step_shader_module)
	}
	if gray_scott_gpu(sim).present_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &gray_scott_gpu(sim).present_shader_module)
	}
	if gray_scott_gpu(sim).vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &gray_scott_gpu(sim).vertex_shader_module)
	}

	gray_scott_gpu(sim).ready = false
	sim.runtime.render_ready = false
	gray_scott_gpu(sim).compute_sets = {}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		gray_scott_gpu(sim).present_sets[i] = vk.DescriptorSet(0)
	}
	gray_scott_gpu(sim).state_index = 0
	gray_scott_gpu(sim).step_shader_spirv_path = ""
	gray_scott_gpu(sim).vertex_shader_spirv_path = ""
	gray_scott_gpu(sim).present_shader_spirv_path = ""
}
