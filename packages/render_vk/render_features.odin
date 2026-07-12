package render_vk

import uifw "../ui"
import engine "../engine"

import "core:time"
import "core:mem"
import vk "vendor:vulkan"

Render_Feature_Step :: proc(ctx: ^Render_Context, dt: f32) -> bool
Render_Feature_Present :: proc(ctx: ^Render_Context, draw_ui: bool, ui_sink: ^Ui_Render_Sink) -> bool
Render_Feature_Destroy_Runtime :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context)
Render_Feature_Initialize_Runtime :: proc(runtime: rawptr) -> bool
Render_Feature_Preview_Step :: proc(ctx: ^Render_Context, palette_name: string, dt: f32) -> bool
Render_Feature_Preview_Present :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) -> bool
Render_Feature_Bind_Graph_Resource :: proc(ctx: ^Render_Context, graph: ^Render_Graph, resource: Render_Resource_Handle, preview: bool) -> bool
Render_Feature_Get_Post_Processing :: proc(ctx: ^Render_Context, out: ^Post_Processing_Settings) -> bool
Render_Feature_Invalidate_Runtime :: proc(runtime: rawptr)
Render_Feature_Reset_Runtime :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context)
Render_Feature_Release_Target_Resources :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context)
Render_Feature_Preview_Prepare :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D)

Render_Feature_Descriptor :: struct {
	id: Feature_Id,
	mode: App_Mode,
	step: Render_Feature_Step,
	present: Render_Feature_Present,
	runtime_size: int,
	runtime_alignment: int,
	initialize_runtime: Render_Feature_Initialize_Runtime,
	destroy_runtime: Render_Feature_Destroy_Runtime,
	preview_step: Render_Feature_Preview_Step,
	preview_present: Render_Feature_Preview_Present,
	bind_graph_resource: Render_Feature_Bind_Graph_Resource,
	get_post_processing: Render_Feature_Get_Post_Processing,
	invalidate_runtime: Render_Feature_Invalidate_Runtime,
	reset_runtime: Render_Feature_Reset_Runtime,
	release_target_resources: Render_Feature_Release_Target_Resources,
	preview_prepare: Render_Feature_Preview_Prepare,
	graph_resource_kind: Render_Resource_Kind,
}

RENDER_FEATURE_DESCRIPTORS := [?]Render_Feature_Descriptor {
	{FEATURE_ID_SLIME_MOLD, .Slime_Mold, render_feature_step_slime, render_feature_present_slime, size_of(Slime_Gpu_State), align_of(Slime_Gpu_State), render_feature_initialize_zeroed, render_feature_destroy_slime, render_feature_preview_step_slime, render_feature_preview_present_slime, render_feature_bind_slime, render_feature_post_processing_slime, render_feature_invalidate_slime, render_feature_reset_slime, render_feature_destroy_slime, render_feature_preview_prepare_slime, .Storage_Image},
	{FEATURE_ID_GRAY_SCOTT, .Gray_Scott, render_feature_step_gray_scott, render_feature_present_gray_scott, size_of(Gray_Scott_Gpu_State), align_of(Gray_Scott_Gpu_State), render_feature_initialize_zeroed, render_feature_destroy_gray_scott, render_feature_preview_step_gray_scott, render_feature_preview_present_gray_scott, render_feature_bind_gray_scott, nil, nil, nil, nil, render_feature_preview_prepare_gray_scott, .Storage_Image},
	{FEATURE_ID_PARTICLE_LIFE, .Particle_Life, render_feature_step_particle_life, render_feature_present_particle_life, size_of(Particle_Life_Gpu_State), align_of(Particle_Life_Gpu_State), render_feature_initialize_zeroed, render_feature_destroy_particle_life, render_feature_preview_step_particle_life, render_feature_preview_present_particle_life, render_feature_bind_particle_life, render_feature_post_processing_particle_life, nil, nil, nil, nil, .Vertex_Buffer},
	{FEATURE_ID_FLOW_FIELD, .Flow_Field, render_feature_step_flow, render_feature_present_flow, size_of(Flow_Gpu_State), align_of(Flow_Gpu_State), render_feature_initialize_zeroed, render_feature_destroy_flow, render_feature_preview_step_flow, render_feature_preview_present_flow, render_feature_bind_flow, render_feature_post_processing_flow, nil, render_feature_reset_flow, render_feature_destroy_flow, render_feature_preview_prepare_flow, .Storage_Image},
	{FEATURE_ID_PELLETS, .Pellets, render_feature_step_pellets, render_feature_present_pellets, size_of(Pellets_Gpu_State), align_of(Pellets_Gpu_State), render_feature_initialize_zeroed, render_feature_destroy_pellets, render_feature_preview_step_pellets, render_feature_preview_present_pellets, render_feature_bind_pellets, render_feature_post_processing_pellets, render_feature_invalidate_pellets, render_feature_reset_pellets, render_feature_destroy_pellets, render_feature_preview_prepare_pellets, .Vertex_Buffer},
	{FEATURE_ID_GRADIENT_EDITOR, .Gradient_Editor, render_feature_step_none, render_feature_present_clear, 0, 0, nil, nil, nil, nil, render_feature_bind_none, nil, nil, nil, nil, nil, .Storage_Image},
	{FEATURE_ID_VORONOI, .Voronoi_CA, render_feature_step_voronoi, render_feature_present_voronoi, size_of(Voronoi_Gpu_State), align_of(Voronoi_Gpu_State), render_feature_initialize_zeroed, render_feature_destroy_voronoi, render_feature_preview_step_voronoi, render_feature_preview_present_voronoi, render_feature_bind_voronoi, render_feature_post_processing_voronoi, render_feature_invalidate_voronoi, render_feature_reset_voronoi, render_feature_destroy_voronoi, render_feature_preview_prepare_voronoi, .Storage_Image},
	{FEATURE_ID_MOIRE, .Moire, render_feature_step_moire, render_feature_present_moire, size_of(Moire_Gpu_State), align_of(Moire_Gpu_State), render_feature_initialize_zeroed, render_feature_destroy_moire, render_feature_preview_step_moire, render_feature_preview_present_moire, render_feature_bind_moire, nil, nil, render_feature_reset_moire, render_feature_destroy_moire, render_feature_preview_prepare_moire, .Storage_Image},
	{FEATURE_ID_VECTORS, .Vectors, render_feature_step_vectors, render_feature_present_vectors, size_of(Vectors_Gpu_State), align_of(Vectors_Gpu_State), render_feature_initialize_zeroed, render_feature_destroy_vectors, render_feature_preview_step_vectors, render_feature_preview_present_vectors, render_feature_bind_vectors, nil, nil, render_feature_reset_vectors, render_feature_destroy_vectors, nil, .Storage_Image},
	{FEATURE_ID_PRIMORDIAL, .Primordial, render_feature_step_primordial, render_feature_present_primordial, size_of(Primordial_Gpu_State), align_of(Primordial_Gpu_State), render_feature_initialize_zeroed, render_feature_destroy_primordial, render_feature_preview_step_primordial, render_feature_preview_present_primordial, render_feature_bind_primordial, render_feature_post_processing_primordial, render_feature_invalidate_primordial, render_feature_reset_primordial, render_feature_destroy_primordial, render_feature_preview_prepare_primordial, .Vertex_Buffer},
}

render_feature_graph_resource_kind :: proc(mode: App_Mode) -> Render_Resource_Kind {
	descriptor, ok := render_feature_descriptor_by_mode(mode)
	return ok ? descriptor.graph_resource_kind : .Storage_Image
}

render_feature_graph_has_resource :: proc(mode: App_Mode) -> bool {
	descriptor, ok := render_feature_descriptor_by_mode(mode)
	return ok && descriptor.runtime_size > 0
}

render_feature_bind_image :: proc(ctx: ^Render_Context, graph: ^Render_Graph, resource: Render_Resource_Handle, image: vk.Image, layout: vk.ImageLayout) -> bool {
	return render_graph_bind_imported_image(graph, ctx, resource, image, layout, {.COMPUTE_SHADER}, {.SHADER_STORAGE_WRITE})
}
render_feature_bind_buffer :: proc(ctx: ^Render_Context, graph: ^Render_Graph, resource: Render_Resource_Handle, buffer: vk.Buffer) -> bool {
	return render_graph_bind_imported_buffer(graph, ctx, resource, buffer, {.COMPUTE_SHADER}, {.SHADER_STORAGE_WRITE})
}
render_feature_bind_gray_scott :: proc(ctx: ^Render_Context, graph: ^Render_Graph, resource: Render_Resource_Handle, preview: bool) -> bool {sim := preview ? render_context_gray_scott(ctx, true) : render_context_gray_scott(ctx); gpu := gray_scott_gpu(sim); return gpu != nil && render_feature_bind_image(ctx, graph, resource, gpu.storage[gpu.state_index].handle, gpu.storage[gpu.state_index].layout)}
render_feature_bind_particle_life :: proc(ctx: ^Render_Context, graph: ^Render_Graph, resource: Render_Resource_Handle, preview: bool) -> bool {sim := preview ? render_context_particle_life(ctx, true) : render_context_particle_life(ctx); return sim != nil && render_feature_bind_buffer(ctx, graph, resource, particle_life_gpu(sim).particle_buffer.handle)}
render_feature_bind_flow :: proc(ctx: ^Render_Context, graph: ^Render_Graph, resource: Render_Resource_Handle, preview: bool) -> bool {gpu := preview ? render_context_flow_gpu(ctx, true) : render_context_flow_gpu(ctx); return gpu != nil && render_feature_bind_image(ctx, graph, resource, gpu.trail_image.handle, gpu.trail_image.layout)}
render_feature_bind_pellets :: proc(ctx: ^Render_Context, graph: ^Render_Graph, resource: Render_Resource_Handle, preview: bool) -> bool {gpu := preview ? render_context_pellets_gpu(ctx, true) : render_context_pellets_gpu(ctx); return gpu != nil && render_feature_bind_buffer(ctx, graph, resource, gpu.particle_buffer.handle)}
render_feature_bind_voronoi :: proc(ctx: ^Render_Context, graph: ^Render_Graph, resource: Render_Resource_Handle, preview: bool) -> bool {gpu := preview ? render_context_voronoi_gpu(ctx, true) : render_context_voronoi_gpu(ctx); if gpu == nil do return false; image := gpu.jfa_result_is_scratch ? gpu.jfa_scratch_image : gpu.jfa_image; return render_feature_bind_image(ctx, graph, resource, image.handle, image.layout)}
render_feature_bind_moire :: proc(ctx: ^Render_Context, graph: ^Render_Graph, resource: Render_Resource_Handle, preview: bool) -> bool {gpu := preview ? render_context_moire_gpu(ctx, true) : render_context_moire_gpu(ctx); return gpu != nil && render_feature_bind_image(ctx, graph, resource, gpu.images[gpu.state_index].handle, gpu.images[gpu.state_index].layout)}
render_feature_bind_vectors :: proc(ctx: ^Render_Context, graph: ^Render_Graph, resource: Render_Resource_Handle, preview: bool) -> bool {gpu := preview ? render_context_vectors_gpu(ctx, true) : render_context_vectors_gpu(ctx); return gpu != nil && render_feature_bind_image(ctx, graph, resource, gpu.field_image.handle, gpu.field_image.layout)}
render_feature_bind_primordial :: proc(ctx: ^Render_Context, graph: ^Render_Graph, resource: Render_Resource_Handle, preview: bool) -> bool {gpu := preview ? render_context_primordial_gpu(ctx, true) : render_context_primordial_gpu(ctx); return gpu != nil && render_feature_bind_buffer(ctx, graph, resource, gpu.particle_buffers[gpu.state_index].handle)}
render_feature_bind_slime :: proc(ctx: ^Render_Context, graph: ^Render_Graph, resource: Render_Resource_Handle, preview: bool) -> bool {gpu := preview ? render_context_slime_gpu(ctx, true) : render_context_slime_gpu(ctx); return gpu != nil && render_feature_bind_image(ctx, graph, resource, gpu.display_image.handle, gpu.display_image.layout)}
render_feature_bind_none :: proc(ctx: ^Render_Context, graph: ^Render_Graph, resource: Render_Resource_Handle, preview: bool) -> bool {_ = ctx; _ = graph; _ = resource; _ = preview; return true}

Render_Feature_Instance :: struct {
	descriptor: ^Render_Feature_Descriptor,
	storage: []byte,
	runtime: rawptr,
}

RENDER_FEATURE_INSTANCE_VARIANT_COUNT :: 2

Render_Feature_Instance_Set :: struct {
	instances: [len(RENDER_FEATURE_DESCRIPTORS)][RENDER_FEATURE_INSTANCE_VARIANT_COUNT]Render_Feature_Instance,
}

render_feature_instance_set_get :: proc(set: ^Render_Feature_Instance_Set, mode: App_Mode, preview := false) -> ^Render_Feature_Instance {
	if set == nil do return nil
	for descriptor, index in RENDER_FEATURE_DESCRIPTORS {
		if descriptor.mode == mode {
			return &set.instances[index][preview ? 1 : 0]
		}
	}
	return nil
}

render_context_feature_runtime :: proc(ctx: ^Render_Context, mode: App_Mode, preview: bool, $T: typeid) -> ^T {
	if ctx == nil || ctx.feature_instances == nil do return nil
	return render_feature_set_runtime(ctx.feature_instances, mode, preview, T)
}

render_feature_set_runtime :: proc(set: ^Render_Feature_Instance_Set, mode: App_Mode, preview: bool, $T: typeid) -> ^T {
	if set == nil do return nil
	instance := render_feature_instance_set_get(set, mode, preview)
	result, ok := render_feature_instance_runtime(instance, T)
	return ok ? result : nil
}

render_context_vectors_gpu :: proc(ctx: ^Render_Context, preview := false) -> ^Vectors_Gpu_State {return render_context_feature_runtime(ctx, .Vectors, preview, Vectors_Gpu_State)}
render_context_moire_gpu :: proc(ctx: ^Render_Context, preview := false) -> ^Moire_Gpu_State {return render_context_feature_runtime(ctx, .Moire, preview, Moire_Gpu_State)}
render_context_primordial_gpu :: proc(ctx: ^Render_Context, preview := false) -> ^Primordial_Gpu_State {return render_context_feature_runtime(ctx, .Primordial, preview, Primordial_Gpu_State)}
render_context_pellets_gpu :: proc(ctx: ^Render_Context, preview := false) -> ^Pellets_Gpu_State {return render_context_feature_runtime(ctx, .Pellets, preview, Pellets_Gpu_State)}
render_context_flow_gpu :: proc(ctx: ^Render_Context, preview := false) -> ^Flow_Gpu_State {return render_context_feature_runtime(ctx, .Flow_Field, preview, Flow_Gpu_State)}
render_context_slime_gpu :: proc(ctx: ^Render_Context, preview := false) -> ^Slime_Gpu_State {return render_context_feature_runtime(ctx, .Slime_Mold, preview, Slime_Gpu_State)}
render_context_voronoi_gpu :: proc(ctx: ^Render_Context, preview := false) -> ^Voronoi_Gpu_State {return render_context_feature_runtime(ctx, .Voronoi_CA, preview, Voronoi_Gpu_State)}
render_context_gray_scott :: proc(ctx: ^Render_Context, preview := false) -> ^Gray_Scott_Simulation {if ctx == nil || ctx.app_ui == nil do return nil; return preview ? &ctx.app_ui.preview_gray_scott : &ctx.app_ui.gray_scott}
render_context_particle_life :: proc(ctx: ^Render_Context, preview := false) -> ^Particle_Life_Simulation {if ctx == nil || ctx.app_ui == nil do return nil; return preview ? &ctx.app_ui.preview_particle_life : &ctx.app_ui.particle_life}

render_feature_instance_set_init :: proc(set: ^Render_Feature_Instance_Set, vk_ctx: ^engine.Vk_Context) -> bool {
	if set == nil do return false
	set^ = {}
	initialized := 0
	for descriptor, descriptor_index in RENDER_FEATURE_DESCRIPTORS {
		if descriptor.runtime_size == 0 do continue
		for variant in 0 ..< RENDER_FEATURE_INSTANCE_VARIANT_COUNT {
			if !render_feature_instance_init(&set.instances[descriptor_index][variant], descriptor.mode) {
				for rollback_descriptor := descriptor_index; rollback_descriptor >= 0; rollback_descriptor -= 1 {
					for rollback_variant := RENDER_FEATURE_INSTANCE_VARIANT_COUNT - 1; rollback_variant >= 0; rollback_variant -= 1 {
						instance := &set.instances[rollback_descriptor][rollback_variant]
						if instance.runtime != nil do render_feature_instance_destroy(instance, vk_ctx)
					}
				}
				set^ = {}
				return false
			}
			initialized += 1
		}
	}
	_ = initialized
	return true
}

render_feature_instance_set_destroy :: proc(set: ^Render_Feature_Instance_Set, vk_ctx: ^engine.Vk_Context) {
	if set == nil do return
	for descriptor_index := len(RENDER_FEATURE_DESCRIPTORS) - 1; descriptor_index >= 0; descriptor_index -= 1 {
		for variant := RENDER_FEATURE_INSTANCE_VARIANT_COUNT - 1; variant >= 0; variant -= 1 {
			render_feature_instance_destroy(&set.instances[descriptor_index][variant], vk_ctx)
		}
	}
	set^ = {}
}

render_feature_instance_set_release_target_resources :: proc(set: ^Render_Feature_Instance_Set, vk_ctx: ^engine.Vk_Context) {
	if set == nil || vk_ctx == nil do return
	for descriptor, descriptor_index in RENDER_FEATURE_DESCRIPTORS {
		if descriptor.release_target_resources == nil do continue
		for variant in 0 ..< RENDER_FEATURE_INSTANCE_VARIANT_COUNT {
			instance := &set.instances[descriptor_index][variant]
			if instance.runtime != nil do descriptor.release_target_resources(instance.runtime, vk_ctx)
		}
	}
}

render_feature_instance_init :: proc(instance: ^Render_Feature_Instance, mode: App_Mode) -> bool {
	descriptor, ok := render_feature_descriptor_by_mode(mode)
	if !ok || descriptor.runtime_size <= 0 || descriptor.runtime_alignment <= 0 {
		return false
	}
	storage, allocation_error := mem.alloc_bytes(descriptor.runtime_size, descriptor.runtime_alignment)
	if allocation_error != nil {
		return false
	}
	for _, i in storage do storage[i] = 0
	instance^ = {descriptor = descriptor, storage = storage, runtime = raw_data(storage)}
	if descriptor.initialize_runtime == nil || !descriptor.initialize_runtime(instance.runtime) {
		delete(instance.storage)
		instance^ = {}
		return false
	}
	return true
}

render_feature_initialize_zeroed :: proc(runtime: rawptr) -> bool {return runtime != nil}
render_feature_invalidate_slime :: proc(runtime: rawptr) {if runtime != nil do (cast(^Slime_Gpu_State)runtime).needs_reset = true}
render_feature_invalidate_pellets :: proc(runtime: rawptr) {if runtime != nil do (cast(^Pellets_Gpu_State)runtime).ready = false}
render_feature_invalidate_voronoi :: proc(runtime: rawptr) {if runtime != nil do (cast(^Voronoi_Gpu_State)runtime).needs_rebuild = true}
render_feature_invalidate_primordial :: proc(runtime: rawptr) {if runtime != nil do (cast(^Primordial_Gpu_State)runtime).ready = false}
render_feature_reset_slime :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {_ = vk_ctx; render_feature_invalidate_slime(runtime)}
render_feature_reset_flow :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {if runtime != nil do flow_gpu_destroy(cast(^Flow_Gpu_State)runtime, vk_ctx)}
render_feature_reset_pellets :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {_ = vk_ctx; render_feature_invalidate_pellets(runtime)}
render_feature_reset_voronoi :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {_ = vk_ctx; render_feature_invalidate_voronoi(runtime)}
render_feature_reset_moire :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {if runtime != nil do moire_gpu_destroy(cast(^Moire_Gpu_State)runtime, vk_ctx)}
render_feature_reset_vectors :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {if runtime != nil do vectors_gpu_destroy(cast(^Vectors_Gpu_State)runtime, vk_ctx)}
render_feature_reset_primordial :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {_ = vk_ctx; render_feature_invalidate_primordial(runtime)}

render_feature_destroy_gray_scott :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {
	settings: Gray_Scott_Settings
	product_runtime: Gray_Scott_Runtime_State
	sim := Gray_Scott_Simulation{settings = &settings, runtime = &product_runtime, render_runtime = runtime}
	gray_scott_destroy(&sim, vk_ctx)
}

render_feature_destroy_particle_life :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {
	settings: Particle_Life_Settings
	product_runtime: Particle_Life_Runtime_State
	sim := Particle_Life_Simulation{settings = &settings, runtime = &product_runtime, render_runtime = runtime}
	particle_life_destroy(&sim, vk_ctx)
}

render_feature_instance_destroy :: proc(instance: ^Render_Feature_Instance, vk_ctx: ^engine.Vk_Context) {
	if instance == nil {
		return
	}
	if instance.runtime != nil && instance.descriptor != nil && instance.descriptor.destroy_runtime != nil {
		instance.descriptor.destroy_runtime(instance.runtime, vk_ctx)
	}
	if instance.storage != nil {
		delete(instance.storage)
	}
	instance^ = {}
}

render_feature_instance_runtime :: proc(instance: ^Render_Feature_Instance, $T: typeid) -> (^T, bool) {
	if instance == nil || instance.runtime == nil || instance.descriptor == nil || instance.descriptor.runtime_size != size_of(T) || instance.descriptor.runtime_alignment != align_of(T) {
		return nil, false
	}
	return cast(^T)instance.runtime, true
}

render_feature_destroy_moire :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {
	moire_gpu_destroy(cast(^Moire_Gpu_State)runtime, vk_ctx)
}

render_feature_destroy_voronoi :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {
	voronoi_gpu_destroy(cast(^Voronoi_Gpu_State)runtime, vk_ctx)
}
render_feature_destroy_pellets :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {pellets_gpu_destroy(cast(^Pellets_Gpu_State)runtime, vk_ctx)}
render_feature_destroy_primordial :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {primordial_gpu_destroy(cast(^Primordial_Gpu_State)runtime, vk_ctx)}
render_feature_destroy_flow :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {flow_gpu_destroy(cast(^Flow_Gpu_State)runtime, vk_ctx)}
render_feature_destroy_slime :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {slime_gpu_destroy(cast(^Slime_Gpu_State)runtime, vk_ctx)}
render_feature_destroy_vectors :: proc(runtime: rawptr, vk_ctx: ^engine.Vk_Context) {vectors_gpu_destroy(cast(^Vectors_Gpu_State)runtime, vk_ctx)}

render_feature_preview_step_gray_scott :: proc(ctx: ^Render_Context, palette_name: string, dt: f32) -> bool {
	if render_context_gray_scott(ctx, true) == nil do return false
	render_main_menu_apply_gray_scott_palette(render_context_gray_scott(ctx, true).settings, palette_name)
	if gray_scott_gpu(render_context_gray_scott(ctx, true)).width != i32(MAIN_MENU_SIM_PREVIEW_WIDTH) || gray_scott_gpu(render_context_gray_scott(ctx, true)).height != i32(MAIN_MENU_SIM_PREVIEW_HEIGHT) {
		gray_scott_resize(render_context_gray_scott(ctx, true), i32(MAIN_MENU_SIM_PREVIEW_WIDTH), i32(MAIN_MENU_SIM_PREVIEW_HEIGHT))
	}
	if gray_scott_ensure_gpu_runtime(render_context_gray_scott(ctx, true), ctx.vk_ctx) {
		gray_scott_gpu_step(render_context_gray_scott(ctx, true), ctx.vk_ctx, ctx.frame.command_buffer, dt)
	}
	return true
}

render_feature_preview_step_slime :: proc(ctx: ^Render_Context, palette_name: string, dt: f32) -> bool {
	if render_context_slime_gpu(ctx, true) == nil || ctx.app_ui == nil do return false
	preview := &ctx.app_ui.preview_slime_mold
	render_main_menu_slime_preview_state(&ctx.app_ui.slime_mold, preview)
	render_main_menu_apply_slime_palette(preview.slime, palette_name)
	remaining_sim_step(preview, dt)
	width, height := render_main_menu_preview_size_for_mode(ctx, .Slime_Mold)
	slime_gpu_step_preview(render_context_slime_gpu(ctx, true), ctx.vk_ctx, ctx.frame.command_buffer, preview, dt, width, height)
	return true
}

render_feature_preview_step_particle_life :: proc(ctx: ^Render_Context, palette_name: string, dt: f32) -> bool {
	if render_context_particle_life(ctx, true) == nil do return false
	settings := render_context_particle_life(ctx, true).settings^
	if render_context_particle_life(ctx) != nil do settings = render_context_particle_life(ctx).settings^
	render_context_particle_life(ctx, true).settings^ = render_main_menu_particle_life_preview_settings(settings)
	render_main_menu_apply_particle_life_palette(render_context_particle_life(ctx, true).settings, palette_name)
	if particle_life_gpu(render_context_particle_life(ctx, true)).width != i32(MAIN_MENU_SIM_PREVIEW_WIDTH) || particle_life_gpu(render_context_particle_life(ctx, true)).height != i32(MAIN_MENU_SIM_PREVIEW_HEIGHT) {
		particle_life_resize(render_context_particle_life(ctx, true), i32(MAIN_MENU_SIM_PREVIEW_WIDTH), i32(MAIN_MENU_SIM_PREVIEW_HEIGHT))
	}
	if particle_life_ensure_gpu_runtime(render_context_particle_life(ctx, true), ctx.vk_ctx) {
		steps := simulation_substeps(dt)
		for _ in 0 ..< steps.count do particle_life_gpu_step(render_context_particle_life(ctx, true), ctx.vk_ctx, ctx.frame.command_buffer, steps.delta_time)
	}
	return true
}

render_feature_preview_step_flow :: proc(ctx: ^Render_Context, palette_name: string, dt: f32) -> bool {
	if render_context_flow_gpu(ctx, true) == nil || ctx.app_ui == nil do return false
	preview := &ctx.app_ui.preview_flow_field
	render_main_menu_flow_preview_state(&ctx.app_ui.flow_field, preview)
	render_main_menu_apply_flow_palette(preview.flow, palette_name)
	remaining_sim_step(preview, dt)
	width, height := render_main_menu_preview_size_for_mode(ctx, .Flow_Field)
	flow_gpu_step_preview(render_context_flow_gpu(ctx, true), ctx.vk_ctx, ctx.frame.command_buffer, preview, dt, width, height)
	return true
}

render_feature_preview_step_pellets :: proc(ctx: ^Render_Context, palette_name: string, dt: f32) -> bool {
	if render_context_pellets_gpu(ctx, true) == nil || ctx.app_ui == nil do return false
	preview := &ctx.app_ui.preview_pellets
	render_main_menu_pellets_preview_state(&ctx.app_ui.pellets, preview)
	render_main_menu_apply_pellets_palette(preview.pellets, palette_name)
	remaining_sim_step(preview, dt)
	pellets_gpu_step(render_context_pellets_gpu(ctx, true), ctx.vk_ctx, ctx.frame.command_buffer, preview, dt)
	return true
}

render_feature_preview_step_voronoi :: proc(ctx: ^Render_Context, palette_name: string, dt: f32) -> bool {
	if render_context_voronoi_gpu(ctx, true) == nil || ctx.app_ui == nil do return false
	preview := &ctx.app_ui.preview_voronoi_ca
	preview.voronoi^ = ctx.app_ui.voronoi_ca.voronoi^
	remaining_sim_step(preview, dt)
	render_main_menu_apply_voronoi_palette(preview.voronoi, palette_name)
	voronoi_gpu_step_size(render_context_voronoi_gpu(ctx, true), ctx.vk_ctx, ctx.frame.command_buffer, preview.voronoi, dt, preview.paused, MAIN_MENU_SIM_PREVIEW_WIDTH, MAIN_MENU_SIM_PREVIEW_HEIGHT)
	return true
}

render_feature_preview_step_moire :: proc(ctx: ^Render_Context, palette_name: string, dt: f32) -> bool {
	if render_context_moire_gpu(ctx, true) == nil || ctx.app_ui == nil do return false
	preview := &ctx.app_ui.preview_moire
	preview.moire^ = ctx.app_ui.moire.moire^
	remaining_sim_step(preview, dt)
	render_main_menu_apply_moire_palette(preview.moire, palette_name)
	moire_gpu_step(render_context_moire_gpu(ctx, true), ctx.vk_ctx, ctx.frame.command_buffer, preview.moire, preview.time, i32(MAIN_MENU_SIM_PREVIEW_WIDTH), i32(MAIN_MENU_SIM_PREVIEW_HEIGHT), preview.paused)
	return true
}

render_feature_preview_step_vectors :: proc(ctx: ^Render_Context, palette_name: string, dt: f32) -> bool {
	_ = dt
	if render_context_vectors_gpu(ctx, true) == nil || ctx.app_ui == nil do return false
	preview := &ctx.app_ui.preview_vectors
	preview.vectors^ = ctx.app_ui.vectors.vectors^
	remaining_sim_step(preview, dt)
	render_main_menu_apply_vectors_palette(preview.vectors, palette_name)
	_ = vectors_gpu_prepare_viewport(render_context_vectors_gpu(ctx, true), ctx.vk_ctx, preview.vectors, preview.time, f32(MAIN_MENU_SIM_PREVIEW_WIDTH), f32(MAIN_MENU_SIM_PREVIEW_HEIGHT))
	vectors_gpu_dispatch_field(render_context_vectors_gpu(ctx, true), ctx.vk_ctx, ctx.frame.command_buffer)
	return true
}

render_feature_preview_step_primordial :: proc(ctx: ^Render_Context, palette_name: string, dt: f32) -> bool {
	if render_context_primordial_gpu(ctx, true) == nil || ctx.app_ui == nil do return false
	preview := &ctx.app_ui.preview_primordial
	render_main_menu_primordial_preview_state(&ctx.app_ui.primordial, preview)
	render_main_menu_apply_primordial_palette(preview.primordial, palette_name)
	remaining_sim_step(preview, dt)
	steps := simulation_substeps(dt)
	for _ in 0 ..< steps.count do primordial_gpu_step(render_context_primordial_gpu(ctx, true), ctx.vk_ctx, ctx.frame.command_buffer, preview, steps.delta_time)
	return true
}

render_feature_preview_present_gray_scott :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) -> bool {if render_context_gray_scott(ctx, true) == nil do return false; gray_scott_gpu_draw_prepared_viewport(render_context_gray_scott(ctx, true), ctx.vk_ctx, ctx.frame.command_buffer, viewport, scissor); return true}
render_feature_preview_present_slime :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) -> bool {if render_context_slime_gpu(ctx, true) == nil do return false; slime_gpu_draw_prepared_viewport(render_context_slime_gpu(ctx, true), ctx.vk_ctx, ctx.frame, viewport, scissor); return true}
render_feature_preview_present_particle_life :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) -> bool {if render_context_particle_life(ctx, true) == nil do return false; particle_life_gpu_draw_prepared_viewport(render_context_particle_life(ctx, true), ctx.vk_ctx, ctx.frame, viewport, scissor); return true}
render_feature_preview_present_flow :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) -> bool {if render_context_flow_gpu(ctx, true) == nil do return false; flow_gpu_draw_prepared_viewport(render_context_flow_gpu(ctx, true), ctx.vk_ctx, ctx.frame, viewport, scissor); return true}
render_feature_preview_present_pellets :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) -> bool {if render_context_pellets_gpu(ctx, true) == nil || !render_context_pellets_gpu(ctx, true).ready do return false; pellets_gpu_draw_scene_viewport(render_context_pellets_gpu(ctx, true), ctx.vk_ctx, ctx.frame.command_buffer, int(ctx.frame.frame_index), &render_context_pellets_gpu(ctx, true).background_pipeline, &render_context_pellets_gpu(ctx, true).render_pipeline, viewport, scissor); return true}
render_feature_preview_present_voronoi :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) -> bool {if render_context_voronoi_gpu(ctx, true) == nil do return false; voronoi_gpu_draw_prepared_viewport(render_context_voronoi_gpu(ctx, true), ctx.vk_ctx, ctx.frame, viewport, scissor); return true}
render_feature_preview_present_moire :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) -> bool {if render_context_moire_gpu(ctx, true) == nil do return false; moire_gpu_draw_prepared_viewport(render_context_moire_gpu(ctx, true), ctx.vk_ctx, ctx.frame, viewport, scissor); return true}
render_feature_preview_present_vectors :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) -> bool {if render_context_vectors_gpu(ctx, true) == nil do return false; vectors_gpu_draw_prepared_viewport(render_context_vectors_gpu(ctx, true), ctx.vk_ctx, ctx.frame, viewport, scissor); return true}
render_feature_preview_present_primordial :: proc(ctx: ^Render_Context, viewport: vk.Viewport, scissor: vk.Rect2D) -> bool {if render_context_primordial_gpu(ctx, true) == nil do return false; primordial_gpu_draw_prepared_viewport(render_context_primordial_gpu(ctx, true), ctx.vk_ctx, ctx.frame, viewport, scissor); return true}

render_feature_descriptor_by_mode :: proc(mode: App_Mode) -> (^Render_Feature_Descriptor, bool) {
	for _, i in RENDER_FEATURE_DESCRIPTORS {
		descriptor := &RENDER_FEATURE_DESCRIPTORS[i]
		if descriptor.mode == mode {
			return descriptor, true
		}
	}
	return nil, false
}

render_feature_registry_validate :: proc() -> bool {
	for descriptor, i in RENDER_FEATURE_DESCRIPTORS {
		product, ok := feature_descriptor_by_mode(descriptor.mode)
		if !ok || product.id != descriptor.id || descriptor.step == nil || descriptor.present == nil {
			return false
		}
		if product.preview.width > 0 && (descriptor.preview_step == nil || descriptor.preview_present == nil) {
			return false
		}
		if feature_has_capability(product, .Scene_Post_Processing) != (descriptor.get_post_processing != nil) {
			return false
		}
		if descriptor.runtime_size > 0 {
			if descriptor.runtime_alignment <= 0 || descriptor.initialize_runtime == nil || descriptor.destroy_runtime == nil {
				return false
			}
		} else if descriptor.runtime_alignment != 0 || descriptor.initialize_runtime != nil || descriptor.destroy_runtime != nil {
			return false
		}
		for other in RENDER_FEATURE_DESCRIPTORS[i + 1:] {
			if other.id == descriptor.id || other.mode == descriptor.mode {
				return false
			}
		}
	}
	return true
}

render_feature_step_none :: proc(ctx: ^Render_Context, dt: f32) -> bool {
	_ = ctx
	_ = dt
	return true
}

render_feature_step_gray_scott :: proc(ctx: ^Render_Context, dt: f32) -> bool {
	if gray_scott_ensure_gpu_runtime(render_context_gray_scott(ctx), ctx.vk_ctx) {
		gray_scott_gpu_step(render_context_gray_scott(ctx), ctx.vk_ctx, ctx.frame.command_buffer, dt)
	}
	return true
}

render_feature_step_particle_life :: proc(ctx: ^Render_Context, dt: f32) -> bool {
	if particle_life_ensure_gpu_runtime(render_context_particle_life(ctx), ctx.vk_ctx) {
		steps := particle_life_simulation_substeps(dt, render_context_particle_life(ctx).settings.particle_count)
		for _ in 0 ..< steps.count {
			particle_life_gpu_step(render_context_particle_life(ctx), ctx.vk_ctx, ctx.frame.command_buffer, steps.delta_time)
		}
	}
	return true
}

render_feature_step_moire :: proc(ctx: ^Render_Context, dt: f32) -> bool {
	_ = dt
	if ctx.app_ui != nil && render_context_moire_gpu(ctx) != nil {
		moire_gpu_step(render_context_moire_gpu(ctx), ctx.vk_ctx, ctx.frame.command_buffer, ctx.app_ui.moire.moire, ctx.app_ui.moire.time, i32(ctx.vk_ctx.swapchain_extent.width), i32(ctx.vk_ctx.swapchain_extent.height), ctx.app_ui.moire.paused)
	}
	return true
}

render_feature_step_primordial :: proc(ctx: ^Render_Context, dt: f32) -> bool {
	if ctx.app_ui != nil && render_context_primordial_gpu(ctx) != nil {
		steps := primordial_simulation_substeps(dt, ctx.app_ui.primordial.primordial.particle_count)
		for _ in 0 ..< steps.count {
			primordial_gpu_step(render_context_primordial_gpu(ctx), ctx.vk_ctx, ctx.frame.command_buffer, &ctx.app_ui.primordial, steps.delta_time)
		}
	}
	return true
}

render_feature_step_pellets :: proc(ctx: ^Render_Context, dt: f32) -> bool {
	if ctx.app_ui != nil && render_context_pellets_gpu(ctx) != nil {
		steps := pellets_simulation_substeps(dt)
		for _ in 0 ..< steps.count {
			pellets_gpu_step(render_context_pellets_gpu(ctx), ctx.vk_ctx, ctx.frame.command_buffer, &ctx.app_ui.pellets, steps.delta_time)
		}
	}
	return true
}

render_feature_step_flow :: proc(ctx: ^Render_Context, dt: f32) -> bool {
	if ctx.app_ui != nil && render_context_flow_gpu(ctx) != nil {
		flow_gpu_step(render_context_flow_gpu(ctx), ctx.vk_ctx, ctx.frame.command_buffer, &ctx.app_ui.flow_field, dt)
	}
	return true
}

render_feature_step_slime :: proc(ctx: ^Render_Context, dt: f32) -> bool {
	if ctx.app_ui != nil && render_context_slime_gpu(ctx) != nil {
		slime_gpu_step(render_context_slime_gpu(ctx), ctx.vk_ctx, ctx.frame.command_buffer, &ctx.app_ui.slime_mold, dt)
	}
	return true
}

render_feature_step_voronoi :: proc(ctx: ^Render_Context, dt: f32) -> bool {
	if ctx.app_ui != nil && render_context_voronoi_gpu(ctx) != nil {
		voronoi_gpu_step(render_context_voronoi_gpu(ctx), ctx.vk_ctx, ctx.frame.command_buffer, &ctx.app_ui.voronoi_ca, dt)
	}
	return true
}

render_feature_step_vectors :: proc(ctx: ^Render_Context, dt: f32) -> bool {
	_ = dt
	if ctx.app_ui == nil || render_context_vectors_gpu(ctx) == nil do return false
	if !vectors_gpu_prepare_viewport(render_context_vectors_gpu(ctx), ctx.vk_ctx, ctx.app_ui.vectors.vectors, ctx.app_ui.vectors.time, f32(ctx.vk_ctx.swapchain_extent.width), f32(ctx.vk_ctx.swapchain_extent.height)) do return false
	vectors_gpu_dispatch_field(render_context_vectors_gpu(ctx), ctx.vk_ctx, ctx.frame.command_buffer)
	return true
}

render_feature_draw_ui :: proc(ctx: ^Render_Context) {
	ui_start := time.tick_now()
	engine.vk_cmd_label_begin(ctx.vk_ctx, ctx.frame.command_buffer, "UI overlay")
	ui_renderer_draw(&ctx.backend.ui, ctx.vk_ctx, ctx.frame.command_buffer, ctx.vk_ctx.swapchain_extent)
	engine.vk_cmd_label_end(ctx.vk_ctx, ctx.frame.command_buffer)
	ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(ui_start, time.tick_now()))
}

render_feature_present_clear :: proc(ctx: ^Render_Context, draw_ui: bool, ui_sink: ^Ui_Render_Sink) -> bool {
	_ = ui_sink
	engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, uifw.Color{0.09, 0.105, 0.125, 1})
	if draw_ui do render_feature_draw_ui(ctx)
	engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
	return true
}

render_feature_present_gray_scott :: proc(ctx: ^Render_Context, draw_ui: bool, ui_sink: ^Ui_Render_Sink) -> bool {
	_ = ui_sink
	engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, uifw.Color{0.09, 0.105, 0.125, 1})
	if gray_scott_ensure_gpu_runtime(render_context_gray_scott(ctx), ctx.vk_ctx) {
		gray_scott_gpu_present(render_context_gray_scott(ctx), ctx.vk_ctx, ctx.frame.command_buffer)
	}
	if draw_ui do render_feature_draw_ui(ctx)
	engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
	return true
}

render_feature_present_particle_life :: proc(ctx: ^Render_Context, draw_ui: bool, ui_sink: ^Ui_Render_Sink) -> bool {
	if particle_life_gpu(render_context_particle_life(ctx)).ready {
		particle_life_gpu_present(render_context_particle_life(ctx), ctx.vk_ctx, ctx.frame, draw_ui ? ui_sink : nil)
	} else {
		engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, particle_life_clear_color(render_context_particle_life(ctx)))
		if draw_ui do render_feature_draw_ui(ctx)
		engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
	}
	render_context_apply_scene_post_processing(ctx)
	return true
}

render_feature_present_vectors :: proc(ctx: ^Render_Context, draw_ui: bool, ui_sink: ^Ui_Render_Sink) -> bool {
	_ = ui_sink
	if ctx.app_ui == nil || render_context_vectors_gpu(ctx) == nil do return render_feature_present_clear(ctx, draw_ui, nil)
	engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, vectors_clear_color(ctx.app_ui.vectors.vectors))
	vectors_gpu_draw_prepared_viewport(render_context_vectors_gpu(ctx), ctx.vk_ctx, ctx.frame, {x = 0, y = 0, width = f32(ctx.vk_ctx.swapchain_extent.width), height = f32(ctx.vk_ctx.swapchain_extent.height), minDepth = 0, maxDepth = 1}, {offset = {0, 0}, extent = ctx.vk_ctx.swapchain_extent})
	if draw_ui do render_feature_draw_ui(ctx)
	engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
	return true
}

render_feature_present_moire :: proc(ctx: ^Render_Context, draw_ui: bool, ui_sink: ^Ui_Render_Sink) -> bool {
	_ = ui_sink
	engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, uifw.Color{0.09, 0.105, 0.125, 1})
	if render_context_moire_gpu(ctx) != nil do moire_gpu_present(render_context_moire_gpu(ctx), ctx.vk_ctx, ctx.frame)
	if draw_ui do render_feature_draw_ui(ctx)
	engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
	return true
}

render_feature_present_primordial :: proc(ctx: ^Render_Context, draw_ui: bool, ui_sink: ^Ui_Render_Sink) -> bool {
	if ctx.app_ui != nil && render_context_primordial_gpu(ctx) != nil {
		start := time.tick_now()
		primordial_gpu_present(render_context_primordial_gpu(ctx), ctx.vk_ctx, ctx.frame, &ctx.app_ui.primordial, draw_ui ? ui_sink : nil)
		if draw_ui do ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(start, time.tick_now()))
	}
	render_context_apply_scene_post_processing(ctx)
	return true
}

render_feature_present_pellets :: proc(ctx: ^Render_Context, draw_ui: bool, ui_sink: ^Ui_Render_Sink) -> bool {
	if ctx.app_ui != nil && render_context_pellets_gpu(ctx) != nil {
		start := time.tick_now()
		pellets_gpu_present(render_context_pellets_gpu(ctx), ctx.vk_ctx, ctx.frame, &ctx.app_ui.pellets, draw_ui ? ui_sink : nil)
		if draw_ui do ctx.backend.last_ui_overlay_seconds = time.duration_seconds(time.tick_diff(start, time.tick_now()))
	}
	render_context_apply_scene_post_processing(ctx)
	return true
}

render_feature_present_flow :: proc(ctx: ^Render_Context, draw_ui: bool, ui_sink: ^Ui_Render_Sink) -> bool {
	_ = ui_sink
	if ctx.app_ui == nil do return render_feature_present_clear(ctx, draw_ui, nil)
	engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, flow_clear_color(ctx.app_ui.flow_field.flow))
	if render_context_flow_gpu(ctx) != nil do flow_gpu_present(render_context_flow_gpu(ctx), ctx.vk_ctx, ctx.frame)
	if draw_ui do render_feature_draw_ui(ctx)
	engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
	render_context_apply_scene_post_processing(ctx)
	return true
}

render_feature_present_slime :: proc(ctx: ^Render_Context, draw_ui: bool, ui_sink: ^Ui_Render_Sink) -> bool {
	_ = ui_sink
	if ctx.app_ui == nil do return render_feature_present_clear(ctx, draw_ui, nil)
		engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, slime_clear_color(ctx.app_ui.slime_mold.slime))
	if render_context_slime_gpu(ctx) != nil do slime_gpu_present(render_context_slime_gpu(ctx), ctx.vk_ctx, ctx.frame, &ctx.app_ui.slime_mold.camera)
	if draw_ui do render_feature_draw_ui(ctx)
	engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
	render_context_apply_scene_post_processing(ctx)
	return true
}

render_feature_present_voronoi :: proc(ctx: ^Render_Context, draw_ui: bool, ui_sink: ^Ui_Render_Sink) -> bool {
	_ = ui_sink
	if ctx.app_ui == nil do return render_feature_present_clear(ctx, draw_ui, nil)
	engine.vk_cmd_begin_swapchain_render_pass(ctx.vk_ctx, ctx.frame, voronoi_clear_color())
	if render_context_voronoi_gpu(ctx) != nil do voronoi_gpu_present(render_context_voronoi_gpu(ctx), ctx.vk_ctx, ctx.frame, &ctx.app_ui.voronoi_ca.camera)
	if draw_ui do render_feature_draw_ui(ctx)
	engine.vk_cmd_end_swapchain_render_pass(ctx.frame)
	render_context_apply_scene_post_processing(ctx)
	return true
}
