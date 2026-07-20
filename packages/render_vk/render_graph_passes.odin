package render_vk

import uifw "zelda_engine:ui"
import engine "zelda_engine:engine"

import "core:math"
import "core:time"
import vk "vendor:vulkan"

render_graph_build_v1 :: proc(mode: App_Mode = .Gray_Scott, capture_active := false, preview_mode_mask: u32 = 0) -> Render_Graph {
	graph: Render_Graph
	swapchain := render_graph_add_resource(&graph, "swapchain color", .Swapchain_Color, false, true)
	feature_resources: [16]Render_Resource_Handle
	feature_resource_count := 0
	if render_feature_graph_has_resource(mode) {
		feature_resources[feature_resource_count] = render_graph_add_feature_resource(&graph, mode, false)
		feature_resource_count += 1
	} else if mode == .Main_Menu {
		for descriptor in RENDER_FEATURE_DESCRIPTORS {
			mode_index := int(descriptor.mode)
			if descriptor.preview_step == nil || mode_index < 0 || mode_index >= 32 || preview_mode_mask & (u32(1) << u32(mode_index)) == 0 do continue
			feature_resources[feature_resource_count] = render_graph_add_feature_resource(&graph, descriptor.mode, true)
			feature_resource_count += 1
		}
	}
	ui_vertices := render_graph_add_resource(&graph, "ui frame vertices", .Vertex_Buffer, false, true)

	render_graph_add_pass(&graph, "AcquireSwapchain", nil, []Render_Resource_Handle{swapchain}, render_pass_noop, {.Acquire, .External})
	render_graph_add_pass(&graph, "SimulationStep", feature_resources[:feature_resource_count], feature_resources[:feature_resource_count], render_pass_gray_scott_compute, {.Refresh_Imported_Resources})
	render_graph_add_pass(&graph, "UiBuild", nil, []Render_Resource_Handle{ui_vertices}, render_pass_ui_build)
	present_reads: [16]Render_Resource_Handle
	copy(present_reads[:feature_resource_count], feature_resources[:feature_resource_count])
	present_reads[feature_resource_count] = ui_vertices
	render_graph_add_pass(&graph, "SimulationPresent", present_reads[:feature_resource_count + 1], []Render_Resource_Handle{swapchain}, render_pass_simulation_present)
	render_graph_add_pass(&graph, "CaptureReadback", []Render_Resource_Handle{swapchain}, nil, render_pass_noop, {.Video_Capture_Point, .Screenshot_Capture_Point, .External})
	render_graph_add_pass(&graph, "UiOverlay", []Render_Resource_Handle{ui_vertices}, []Render_Resource_Handle{swapchain}, render_pass_ui_overlay)
	render_graph_add_pass(&graph, "PresentSwapchain", []Render_Resource_Handle{swapchain}, nil, render_pass_noop, {.Present, .External})
	_ = render_graph_set_pass_use(&graph, 0, swapchain, .Write, {.TOP_OF_PIPE}, {}, .PRESENT_SRC_KHR)
	_ = render_graph_set_pass_use(&graph, 2, ui_vertices, .Write, {.HOST}, {.HOST_WRITE})
	for resource in feature_resources[:feature_resource_count] {
		kind := graph.resources[int(resource)].kind
		step_layout := kind == .Storage_Image ? vk.ImageLayout.GENERAL : vk.ImageLayout.UNDEFINED
		present_layout := kind == .Storage_Image ? vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL : vk.ImageLayout.UNDEFINED
		_ = render_graph_set_pass_use(&graph, 1, resource, .Read_Write, {.COMPUTE_SHADER}, {.SHADER_STORAGE_READ, .SHADER_STORAGE_WRITE}, step_layout)
		present_stage: vk.PipelineStageFlags2 = {.FRAGMENT_SHADER}
		present_access: vk.AccessFlags2 = {.SHADER_SAMPLED_READ}
		if kind == .Vertex_Buffer {
			present_stage = {.VERTEX_SHADER, .VERTEX_INPUT}
			present_access = {.SHADER_STORAGE_READ, .VERTEX_ATTRIBUTE_READ}
		}
		_ = render_graph_set_pass_use(&graph, 3, resource, .Read, present_stage, present_access, present_layout)
	}
	_ = render_graph_set_pass_use(&graph, 3, ui_vertices, .Read, {.VERTEX_INPUT}, {.VERTEX_ATTRIBUTE_READ})
	_ = render_graph_set_pass_use(&graph, 3, swapchain, .Write, {.COLOR_ATTACHMENT_OUTPUT}, {.COLOR_ATTACHMENT_WRITE}, .COLOR_ATTACHMENT_OPTIMAL)
	_ = render_graph_set_pass_use(&graph, 4, swapchain, .Read, {.TRANSFER}, {.TRANSFER_READ}, .TRANSFER_SRC_OPTIMAL)
	_ = render_graph_set_pass_use(&graph, 5, ui_vertices, .Read, {.VERTEX_INPUT}, {.VERTEX_ATTRIBUTE_READ})
	_ = render_graph_set_pass_use(&graph, 5, swapchain, .Read_Write, {.COLOR_ATTACHMENT_OUTPUT}, {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE}, .COLOR_ATTACHMENT_OPTIMAL)
	_ = render_graph_set_pass_use(&graph, 6, swapchain, .Read, {.BOTTOM_OF_PIPE}, {}, .PRESENT_SRC_KHR)
	_ = render_graph_set_pass_enabled(&graph, 4, capture_active)
	return graph
	}
render_graph_add_resource :: proc(graph: ^Render_Graph, name: string, kind: Render_Resource_Kind, transient: bool, external := false) -> Render_Resource_Handle {
	index := graph.resource_count
	if index >= MAX_RENDER_GRAPH_RESOURCES {
		return Render_Resource_Handle(-1)
	}
	graph.resources[index] = {name = name, kind = kind, transient = transient, external = external}
	graph.resource_count += 1
	return Render_Resource_Handle(index)
}

render_graph_add_feature_resource :: proc(graph: ^Render_Graph, mode: App_Mode, preview: bool) -> Render_Resource_Handle {
	handle := render_graph_add_resource(graph, preview ? "preview feature output" : "feature output", render_feature_graph_resource_kind(mode), false, true)
	if int(handle) >= 0 {
		graph.resources[int(handle)].feature_owned = true
		graph.resources[int(handle)].feature_mode = mode
	}
	return handle
}

render_graph_set_resource_shape :: proc(graph: ^Render_Graph, handle: Render_Resource_Handle, format: vk.Format = .UNDEFINED, width: u32 = 0, height: u32 = 0, depth: u32 = 0, byte_size: u64 = 0, usage: u64 = 0) -> bool {
	index := int(handle)
	if graph == nil || index < 0 || index >= graph.resource_count {
		return false
	}
	resource := &graph.resources[index]
	resource.format = format
	resource.width = width
	resource.height = height
	resource.depth = depth
	resource.byte_size = byte_size
	resource.usage = usage
	graph.compiled = false
	return true
}

render_graph_set_pass_use :: proc(graph: ^Render_Graph, pass_index: int, resource: Render_Resource_Handle, access: Render_Resource_Access, stage: vk.PipelineStageFlags2, access_mask: vk.AccessFlags2, layout: vk.ImageLayout = .UNDEFINED, subresource: Render_Subresource_Range = {}) -> bool {
	if graph == nil || pass_index < 0 || pass_index >= graph.pass_count {
		return false
	}
	pass := &graph.passes[pass_index]
	for i in 0 ..< pass.use_count {
		if pass.uses[i].resource == resource {
			pass.uses[i] = {resource, access, stage, access_mask, layout, subresource}
			graph.compiled = false
			return true
		}
	}
	return false
}

render_graph_add_pass :: proc(graph: ^Render_Graph, name: string, reads: []Render_Resource_Handle, writes: []Render_Resource_Handle, execute: Render_Pass_Execute, side_effects: Render_Pass_Side_Effects = {}) {
	if graph.pass_count >= MAX_RENDER_GRAPH_PASSES {
		return
	}
	pass := &graph.passes[graph.pass_count]
	pass.name = name
	pass.enabled = true
	pass.side_effects = side_effects
	pass.execute = execute
	pass.read_count = min(len(reads), len(pass.reads))
	pass.write_count = min(len(writes), len(pass.writes))
	for i in 0 ..< pass.read_count {
		pass.reads[i] = reads[i]
		_ = render_graph_add_use(pass, reads[i], .Read)
	}
	for i in 0 ..< pass.write_count {
		pass.writes[i] = writes[i]
		if _, already_read := render_graph_pass_use(pass, writes[i]); already_read {
			for use_index in 0 ..< pass.use_count {
				if pass.uses[use_index].resource == writes[i] {
					pass.uses[use_index].access = .Read_Write
					break
				}
			}
		} else {
			_ = render_graph_add_use(pass, writes[i], .Write)
		}
	}
	graph.pass_count += 1
	graph.compiled = false
}

render_graph_set_pass_enabled :: proc(graph: ^Render_Graph, pass_index: int, enabled: bool) -> bool {
	if graph == nil || pass_index < 0 || pass_index >= graph.pass_count do return false
	if graph.passes[pass_index].enabled == enabled do return true
	graph.passes[pass_index].enabled = enabled
	graph.compiled = false
	return true
}

render_graph_execute :: proc(graph: ^Render_Graph, ctx: ^Render_Context) -> bool {
	if !graph.compiled && !render_graph_compile(graph) {
		engine.log_error("render_graph_execute: compile failed error=", graph.compile_error)
		return false
	}
	for order_index in 0 ..< graph.compiled_count {
		pass_index := graph.compiled_order[order_index]
		if !render_graph_emit_barriers_for_pass(graph, ctx, pass_index) {
			engine.log_error("render_graph_execute: barrier emission failed pass=", graph.passes[pass_index].name)
			return false
		}
		pass := &graph.passes[pass_index]
		if pass.execute != nil && !pass.execute(ctx, pass) {
			engine.log_error("render_graph_execute: pass failed name=", pass.name)
			return false
		}
		if .Refresh_Imported_Resources in pass.side_effects {
			for resource_index in 0 ..< graph.resource_count {
				resource := &graph.resources[resource_index]
				if !resource.feature_owned do continue
				descriptor, ok := render_feature_descriptor_by_mode(resource.feature_mode)
				preview := ctx.app_mode == .Main_Menu
				if !ok || descriptor.bind_graph_resource == nil || !descriptor.bind_graph_resource(ctx, graph, Render_Resource_Handle(resource_index), preview) {
					engine.log_error("render_graph_execute: feature resource refresh failed mode=", resource.feature_mode, " preview=", preview)
					return false
				}
			}
		}
			if .Video_Capture_Point in pass.side_effects && video_capture_is_recording(ctx.video_capture) && app_ui_mode_allows_video_recording(ctx.app_mode) {
				if video_capture_reserve_frame(ctx.video_capture, &ctx.video_capture_frame_index) {
					ctx.video_capture_frame_reserved = true
					if buffer := render_backend_capture_readback_buffer(ctx, 0); buffer != nil {
						ctx.video_capture_readback = buffer^
						ctx.video_capture_readback_ready = vk_cmd_capture_swapchain_to_buffer_graph_owned(ctx.vk_ctx, ctx.frame, &ctx.video_capture_readback)
					}
					if !ctx.video_capture_readback_ready {
						video_capture_release_frame(ctx.video_capture, ctx.video_capture_frame_index)
						ctx.video_capture_frame_reserved = false
						video_capture_fail(ctx.video_capture, "Failed to capture video frame")
					}
				}
			}
			if .Screenshot_Capture_Point in pass.side_effects && ctx.screenshot_requested {
				if buffer := render_backend_capture_readback_buffer(ctx, 1); buffer != nil {
					ctx.screenshot_readback = buffer^
					ctx.screenshot_readback_ready = vk_cmd_capture_swapchain_to_buffer_graph_owned(ctx.vk_ctx, ctx.frame, &ctx.screenshot_readback)
				}
				if !ctx.screenshot_readback_ready do engine.log_warn("render_graph_execute: screenshot readback setup failed")
			}
	}
	if !render_graph_validate_imported_states(graph, ctx) {
		engine.log_error("render_graph_execute: imported state validation failed")
		return false
	}
	return true
}

render_graph_bind_imported_image :: proc(graph: ^Render_Graph, ctx: ^Render_Context, resource: Render_Resource_Handle, image: vk.Image, layout: vk.ImageLayout, stage: vk.PipelineStageFlags2, access: vk.AccessFlags2) -> bool {
	index := int(resource)
	if graph == nil || ctx == nil || index < 0 || index >= graph.resource_count || (!graph.resources[index].external && !graph.resources[index].transient) || image == vk.Image(0) do return false
	ctx.imported_resources[index] = {valid = true, image = image, observed_layout = layout, observed_stage = stage, observed_access = access}
	return true
}

render_graph_bind_imported_buffer :: proc(graph: ^Render_Graph, ctx: ^Render_Context, resource: Render_Resource_Handle, buffer: vk.Buffer, stage: vk.PipelineStageFlags2, access: vk.AccessFlags2) -> bool {
	index := int(resource)
	if graph == nil || ctx == nil || index < 0 || index >= graph.resource_count || (!graph.resources[index].external && !graph.resources[index].transient) || buffer == vk.Buffer(0) do return false
	ctx.imported_resources[index] = {valid = true, buffer = buffer, observed_stage = stage, observed_access = access}
	return true
}

render_graph_validate_imported_states :: proc(graph: ^Render_Graph, ctx: ^Render_Context) -> bool {
	if graph == nil || ctx == nil do return false
	for resource_index in 0 ..< graph.resource_count {
		resource := &graph.resources[resource_index]
		binding := &ctx.imported_resources[resource_index]
		if (resource.external || resource.transient) && !binding.valid do return false
		if !binding.valid || graph.resource_last_use[resource_index] < 0 do continue
		last_order := graph.resource_last_use[resource_index]
		pass := &graph.passes[graph.compiled_order[last_order]]
		use, found := render_graph_pass_use(pass, Render_Resource_Handle(resource_index))
		if !found do return false
		if use.layout != .UNDEFINED && binding.observed_layout != use.layout do return false
	}
	return true
}

render_graph_emit_barriers_for_pass :: proc(graph: ^Render_Graph, ctx: ^Render_Context, pass_index: int) -> bool {
	if graph == nil || ctx == nil || ctx.vk_ctx == nil || pass_index < 0 || pass_index >= graph.pass_count {
		return false
	}
	for barrier in graph.transient_barriers[:graph.transient_barrier_count] {
		if barrier.consumer_pass != pass_index do continue
		resource_index := int(barrier.resource)
		if resource_index < 0 || resource_index >= graph.resource_count do return false
		binding := &ctx.imported_resources[resource_index]
		if !binding.valid do return false
		if binding.image != vk.Image(0) {
			engine.vk_cmd_image_barrier2(ctx.vk_ctx, ctx.frame.command_buffer, binding.image, barrier.src_stage, barrier.dst_stage, barrier.src_access, barrier.dst_access, barrier.old_layout, barrier.new_layout)
			binding.observed_layout = barrier.new_layout
		} else if binding.buffer != vk.Buffer(0) {
			engine.vk_cmd_buffer_barrier2(ctx.vk_ctx, ctx.frame.command_buffer, binding.buffer, 0, vk.DeviceSize(vk.WHOLE_SIZE), barrier.src_stage, barrier.dst_stage, barrier.src_access, barrier.dst_access)
		} else do return false
		binding.observed_stage = barrier.dst_stage
		binding.observed_access = barrier.dst_access
	}
	for barrier in graph.barriers[:graph.barrier_count] {
		if barrier.consumer_pass != pass_index do continue
		resource_index := int(barrier.resource)
		if resource_index < 0 || resource_index >= graph.resource_count do return false
		resource := &graph.resources[resource_index]
		binding := &ctx.imported_resources[resource_index]
		if resource.external || resource.transient {
			if !binding.valid {
				// Feature outputs are created lazily by the producer step and bound
				// immediately afterward by Refresh_Imported_Resources. There is no
				// prior image to transition on that first producer pass.
				if resource.feature_owned && .Refresh_Imported_Resources in graph.passes[pass_index].side_effects do continue
				engine.log_error("render_graph: missing binding resource=", resource.name, " mode=", resource.feature_mode)
				return false
			}
			if binding.image != vk.Image(0) {
				// Feature preparation may have already performed the graph's exact
				// target transition before refreshing the imported binding.
				if binding.observed_layout == barrier.new_layout {
					binding.observed_stage = barrier.dst_stage
					binding.observed_access = barrier.dst_access
					continue
				}
				if barrier.old_layout != .UNDEFINED && binding.observed_layout != barrier.old_layout {
					engine.log_error("render_graph: layout mismatch resource=", resource.name, " mode=", resource.feature_mode, " observed=", binding.observed_layout, " declared=", barrier.old_layout)
					return false
				}
				engine.vk_cmd_image_barrier2(
				ctx.vk_ctx,
				ctx.frame.command_buffer,
				binding.image,
				barrier.src_stage,
				barrier.dst_stage,
				barrier.src_access,
				barrier.dst_access,
				barrier.old_layout,
				barrier.new_layout,
				)
				binding.observed_layout = barrier.new_layout
			} else if binding.buffer != vk.Buffer(0) {
				engine.vk_cmd_buffer_barrier2(ctx.vk_ctx, ctx.frame.command_buffer, binding.buffer, 0, vk.DeviceSize(vk.WHOLE_SIZE), barrier.src_stage, barrier.dst_stage, barrier.src_access, barrier.dst_access)
			} else do return false
			binding.observed_stage = barrier.dst_stage
			binding.observed_access = barrier.dst_access
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
		return true
	}
	descriptor, ok := render_feature_descriptor_by_mode(ctx.app_mode)
	if !ok {
		return true
	}
	return descriptor.step(ctx, sim_dt)
}

render_pass_main_menu_preview_step :: proc(ctx: ^Render_Context) {
	if ctx.app_ui == nil {
		return
	}
	palette_name := render_main_menu_preview_palette_name(ctx)
	sim_dt := simulation_frame_delta(ctx.dt)
	for descriptor in RENDER_FEATURE_DESCRIPTORS {
		if descriptor.preview_step != nil && render_main_menu_preview_mode_visible(ctx, descriptor.mode) && descriptor.preview_step(ctx, palette_name, sim_dt) {
			ctx.backend.last_main_menu_preview_warmed_mode_count += 1
		}
	}
}
