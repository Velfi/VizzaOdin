package render_vk

import uifw "../ui"
import engine "../engine"

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
	if sim.gpu.storage[read_index].layout != .GENERAL {
		gray_scott_transition_image(sim, vk_ctx, read_index, sim.gpu.storage[read_index].layout, .GENERAL, cmd)
	}
	if sim.gpu.storage[write_index].layout != .GENERAL {
		gray_scott_transition_image(sim, vk_ctx, write_index, sim.gpu.storage[write_index].layout, .GENERAL, cmd)
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
	sim.gpu.state_index = 0
	sim.runtime.pending_seed_mode = 0
	return true
}

gray_scott_step_compute_resources :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dt: f32) -> bool {
	sim.gpu.compute_dispatch_slot = 0
	if sim.gpu.compute_pipeline.pipeline == vk.Pipeline(0) || sim.gpu.compute_sets[0] == vk.DescriptorSet(0) || sim.gpu.compute_sets[1] == vk.DescriptorSet(0) {
		return false
	}
	for i := 0; i < 2; i += 1 {
		if sim.gpu.storage[i].handle == vk.Image(0) {
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
		read_index := int(sim.gpu.state_index)
		write_index := 1 - read_index
		if !gray_scott_apply_compute_mode_to_image(sim, vk_ctx, cmd, write_index, GRAY_SCOTT_MODE_PAINT, 1.0) {
			return false
		}
		sim.gpu.state_index = u32(write_index)
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

	read_index := int(sim.gpu.state_index)
	write_index := 1 - read_index

	for _ in 0 ..< substeps {
		if sim.gpu.storage[read_index].layout != .GENERAL {
			gray_scott_transition_image(sim, vk_ctx, read_index, sim.gpu.storage[read_index].layout, .GENERAL, cmd)
		}
		if sim.gpu.storage[write_index].layout != .GENERAL {
			gray_scott_transition_image(sim, vk_ctx, write_index, sim.gpu.storage[write_index].layout, .GENERAL, cmd)
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
	sim.gpu.state_index = u32(read_index)
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
		return sim.gpu.step_shader_spirv_path
	}
	return sim.gpu.present_shader_spirv_path
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

	if sim.gpu.present_pipeline.pipeline == vk.Pipeline(0) {
		return false
	}
	if sim.gpu.state_index >= 2 {
		return false
	}
	state_index := int(sim.gpu.state_index)
	extent := vk_ctx.swapchain_extent
	if extent.width == 0 || extent.height == 0 {
		return false
	}
	if state_index < 0 || state_index >= 2 {
		return false
	}
	if sim.gpu.storage[state_index].layout != .SHADER_READ_ONLY_OPTIMAL {
		gray_scott_transition_image(sim, vk_ctx, state_index, sim.gpu.storage[state_index].layout, .SHADER_READ_ONLY_OPTIMAL, cmd)
	}
	frame_slot := vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT
	sim.gpu.present_frame_slot = frame_slot
	gray_scott_sync_present_resources_for_slot(sim, frame_slot)
	if !gray_scott_update_present_descriptor(sim, vk_ctx, state_index, frame_slot) {
		return false
	}
	return true
}

gray_scott_gpu_draw_prepared_viewport :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, viewport: vk.Viewport, scissor: vk.Rect2D) {
	if sim == nil || !sim.gpu.ready || sim.gpu.present_pipeline.pipeline == vk.Pipeline(0) {
		return
	}

	local_viewport := viewport
	local_scissor := scissor
	vk.CmdSetViewport(cmd, 0, 1, &local_viewport)
	vk.CmdSetScissor(cmd, 0, 1, &local_scissor)
	vk.CmdBindPipeline(cmd, .GRAPHICS, sim.gpu.present_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	frame_slot := min(sim.gpu.present_frame_slot, u32(engine.MAX_FRAMES_IN_FLIGHT - 1))
	present_set := sim.gpu.present_sets[frame_slot]
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, sim.gpu.present_pipeline.layout, 0, 1, &present_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	tile_count := infinite_render_tile_count(sim.runtime.camera_zoom)
	vk.CmdDraw(cmd, 6, tile_count * tile_count, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
}

gray_scott_destroy :: proc(sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context) {
	gray_scott_stop_webcam(sim)
	if vk_ctx == nil || vk_ctx.device == nil {
		sim.gpu = {}
		return
	}

	if sim.gpu.compute_pipeline.pipeline != vk.Pipeline(0) {
		vk.DestroyPipeline(vk_ctx.device, sim.gpu.compute_pipeline.pipeline, nil)
		sim.gpu.compute_pipeline.pipeline = vk.Pipeline(0)
	}
	if sim.gpu.compute_pipeline.layout != vk.PipelineLayout(0) {
		vk.DestroyPipelineLayout(vk_ctx.device, sim.gpu.compute_pipeline.layout, nil)
		sim.gpu.compute_pipeline.layout = vk.PipelineLayout(0)
	}

	if sim.gpu.present_pipeline.pipeline != vk.Pipeline(0) {
		engine.vk_destroy_graphics_pipeline(vk_ctx, &sim.gpu.present_pipeline)
	}

	if sim.gpu.compute_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.compute_set_layout, nil)
		sim.gpu.compute_set_layout = vk.DescriptorSetLayout(0)
	}
	if sim.gpu.present_set_layout != vk.DescriptorSetLayout(0) {
		vk.DestroyDescriptorSetLayout(vk_ctx.device, sim.gpu.present_set_layout, nil)
		sim.gpu.present_set_layout = vk.DescriptorSetLayout(0)
	}
	if sim.gpu.compute_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, sim.gpu.compute_pool, nil)
		sim.gpu.compute_pool = vk.DescriptorPool(0)
	}
	if sim.gpu.present_pool != vk.DescriptorPool(0) {
		vk.DestroyDescriptorPool(vk_ctx.device, sim.gpu.present_pool, nil)
		sim.gpu.present_pool = vk.DescriptorPool(0)
	}
	if sim.gpu.sampler != vk.Sampler(0) {
		vk.DestroySampler(vk_ctx.device, sim.gpu.sampler, nil)
		sim.gpu.sampler = vk.Sampler(0)
	}
	for i := 0; i < 2; i += 1 {
		if sim.gpu.storage[i].view != vk.ImageView(0) {
			vk.DestroyImageView(vk_ctx.device, sim.gpu.storage[i].view, nil)
		}
		if sim.gpu.storage[i].handle != vk.Image(0) {
			vk.DestroyImage(vk_ctx.device, sim.gpu.storage[i].handle, nil)
		}
		if sim.gpu.storage[i].memory != vk.DeviceMemory(0) {
			vk.FreeMemory(vk_ctx.device, sim.gpu.storage[i].memory, nil)
		}
		sim.gpu.storage[i] = {}
	}
	for i := 0; i < len(sim.gpu.params_buffers); i += 1 {
		if sim.gpu.params_buffers[i].handle != vk.Buffer(0) {
			engine.vk_destroy_buffer(vk_ctx, &sim.gpu.params_buffers[i])
		}
	}
	if sim.gpu.nutrient_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.nutrient_buffer)
	}
	if sim.gpu.lut_buffer.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.lut_buffer)
	}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		if sim.gpu.present_params_buffers[i].handle != vk.Buffer(0) {
			engine.vk_destroy_buffer(vk_ctx, &sim.gpu.present_params_buffers[i])
		}
		if sim.gpu.camera_buffers[i].handle != vk.Buffer(0) {
			engine.vk_destroy_buffer(vk_ctx, &sim.gpu.camera_buffers[i])
		}
	}
	if sim.gpu.fullscreen_vertices.handle != vk.Buffer(0) {
		engine.vk_destroy_buffer(vk_ctx, &sim.gpu.fullscreen_vertices)
	}
	if sim.gpu.step_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.step_shader_module)
	}
	if sim.gpu.present_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.present_shader_module)
	}
	if sim.gpu.vertex_shader_module.handle != 0 {
		engine.vk_destroy_shader_module(vk_ctx, &sim.gpu.vertex_shader_module)
	}

	sim.gpu.ready = false
	sim.gpu.compute_sets = {}
	for i in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		sim.gpu.present_sets[i] = vk.DescriptorSet(0)
	}
	sim.gpu.state_index = 0
	sim.gpu.step_shader_spirv_path = ""
	sim.gpu.vertex_shader_spirv_path = ""
	sim.gpu.present_shader_spirv_path = ""
}
