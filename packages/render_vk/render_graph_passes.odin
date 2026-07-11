package render_vk

import uifw "../ui"
import engine "../engine"

import "core:math"
import "core:time"
import vk "vendor:vulkan"

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
			steps := primordial_simulation_substeps(sim_dt, ctx.app_ui.primordial.primordial.particle_count)
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
		vectors_gpu_dispatch_field(ctx.preview_vectors_gpu, ctx.vk_ctx, ctx.frame.command_buffer)
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
