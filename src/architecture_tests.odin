package main

import game "../packages/game"
import host "../packages/app"
import engine "zelda_engine:engine"
import rendervk "../packages/render_vk"
import uifw "zelda_engine:ui"

import "core:math"
import "core:os"
import "core:strings"
import "core:testing"
import sdl "vendor:sdl3"
import vk "vendor:vulkan"

Test_Gray_Scott_Product_Storage :: struct {
	settings: game.Gray_Scott_Settings,
	runtime: game.Gray_Scott_Runtime_State,
}

test_gray_scott_init :: proc(sim: ^game.Gray_Scott_Simulation, storage: ^Test_Gray_Scott_Product_Storage, width, height: i32) {
	sim.settings = &storage.settings
	sim.runtime = &storage.runtime
	game.gray_scott_init(sim, width, height)
}

Test_Particle_Life_Product_Storage :: struct {
	settings: game.Particle_Life_Settings,
	runtime: game.Particle_Life_Runtime_State,
}

test_particle_life_init :: proc(sim: ^game.Particle_Life_Simulation, storage: ^Test_Particle_Life_Product_Storage, width, height: i32) {
	sim.settings = &storage.settings
	sim.runtime = &storage.runtime
	game.particle_life_init(sim, width, height)
}

Test_Remaining_Sim_Product_Storage :: struct {
	runtime: game.Remaining_Sim_Runtime_State,
	moire: game.Moire_Settings,
	vectors: game.Vectors_Settings,
	primordial: game.Primordial_Settings,
	voronoi: game.Voronoi_Settings,
	pellets: game.Pellets_Settings,
	flow: game.Flow_Settings,
	slime: game.Slime_Settings,
}

test_remaining_sim_init :: proc(sim: ^game.Remaining_Sim_State, storage: ^Test_Remaining_Sim_Product_Storage) {
	sim.runtime = &storage.runtime
	sim.moire = &storage.moire
	sim.vectors = &storage.vectors
	sim.primordial = &storage.primordial
	sim.voronoi = &storage.voronoi
	sim.pellets = &storage.pellets
	sim.flow = &storage.flow
	sim.slime = &storage.slime
	game.remaining_sim_init(sim)
}

@(test)
test_feature_registry_is_unique_complete_and_stable :: proc(t: ^testing.T) {
	testing.expect(t, game.feature_registry_validate())
	testing.expect(t, rendervk.render_feature_registry_validate())
	testing.expect_value(t, game.feature_count(), len(game.APP_SIMULATION_NAMES))
	for i in 0 ..< game.feature_count() {
		descriptor, ok := game.feature_descriptor_at(i)
		testing.expect(t, ok)
		if !ok {
			continue
		}
		by_id, id_ok := game.feature_descriptor_by_id(descriptor.id)
		by_mode, mode_ok := game.feature_descriptor_by_mode(descriptor.mode)
		testing.expect(t, id_ok && mode_ok)
		if id_ok && mode_ok {
			testing.expect_value(t, by_id.mode, descriptor.mode)
			testing.expect_value(t, by_mode.id, descriptor.id)
		}
	}
}

@(test)
test_feature_registry_owns_settings_schema_defaults_validation_and_copy :: proc(t: ^testing.T) {
	descriptor, found := game.feature_descriptor_by_mode(.Moire)
	testing.expect(t, found)
	if !found do return
	testing.expect_value(t, descriptor.settings_size, size_of(game.Moire_Settings))
	testing.expect_value(t, descriptor.settings_alignment, align_of(game.Moire_Settings))
	defaults: game.Moire_Settings
	testing.expect(t, descriptor.settings_defaults(&defaults))
	testing.expect(t, descriptor.settings_validate(&defaults))
	copy_value: game.Moire_Settings
	testing.expect(t, descriptor.settings_copy(&copy_value, &defaults, descriptor.settings_size))
	testing.expect_value(t, copy_value.generator_index, defaults.generator_index)
	tool, tool_found := game.feature_descriptor_by_mode(.Gradient_Editor)
	testing.expect(t, tool_found)
	if tool_found {
		testing.expect_value(t, tool.settings_size, 0)
		testing.expect(t, tool.settings_defaults == nil)
	}
}

@(test)
test_product_feature_instance_separates_settings_from_transient_runtime :: proc(t: ^testing.T) {
	modes := [?]game.App_Mode{.Slime_Mold, .Gray_Scott, .Particle_Life, .Flow_Field, .Pellets, .Voronoi_CA, .Moire, .Vectors, .Primordial}
	for mode in modes {
		instance: game.Feature_Instance
		testing.expect(t, game.feature_instance_init(&instance, mode))
		testing.expect(t, instance.settings != nil && instance.runtime != nil)
		testing.expect(t, instance.settings != instance.runtime)
		testing.expect(t, uintptr(instance.settings) % uintptr(instance.descriptor.settings_alignment) == 0)
		testing.expect(t, uintptr(instance.runtime) % uintptr(instance.descriptor.runtime_alignment) == 0)
		#partial switch mode {
		case .Gray_Scott:
			settings, settings_ok := game.feature_instance_settings(&instance, game.Gray_Scott_Settings)
			runtime, runtime_ok := game.feature_instance_runtime(&instance, game.Gray_Scott_Runtime_State)
			testing.expect(t, settings_ok && runtime_ok && settings != nil && runtime != nil)
			testing.expect_value(t, settings.feed, game.gray_scott_default_settings().feed)
		case .Particle_Life:
			_, settings_ok := game.feature_instance_settings(&instance, game.Particle_Life_Settings)
			_, runtime_ok := game.feature_instance_runtime(&instance, game.Particle_Life_Runtime_State)
			testing.expect(t, settings_ok && runtime_ok)
		case:
		}
		game.feature_instance_destroy(&instance)
		testing.expect(t, instance.settings == nil && instance.runtime == nil)
	}
}

@(test)
test_product_feature_instance_set_owns_live_and_preview_variants :: proc(t: ^testing.T) {
	set: game.Feature_Instance_Set
	testing.expect(t, game.feature_instance_set_init(&set))
	modes := [?]game.App_Mode{.Slime_Mold, .Gray_Scott, .Particle_Life, .Flow_Field, .Pellets, .Voronoi_CA, .Moire, .Vectors, .Primordial}
	for mode in modes {
		primary := game.feature_instance_set_get(&set, mode)
		preview := game.feature_instance_set_get(&set, mode, true)
		testing.expect(t, primary != nil && primary.settings != nil && primary.runtime != nil)
		testing.expect(t, preview != nil && preview.settings != nil && preview.runtime != nil)
		testing.expect(t, primary.settings != preview.settings && primary.runtime != preview.runtime)
	}
	tool := game.feature_instance_set_get(&set, .Gradient_Editor)
	testing.expect(t, tool != nil && tool.settings == nil && tool.runtime == nil)
	game.feature_instance_set_destroy(&set)
	for mode in modes {
		instance := game.feature_instance_set_get(&set, mode)
		testing.expect(t, instance != nil && instance.settings == nil && instance.runtime == nil)
	}
}

@(test)
test_remaining_simulation_views_bind_distinct_live_and_preview_instances :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	testing.expect(t, game.app_ui_init(&ui, game.settings_default()))
	defer game.app_ui_destroy(&ui)
	views := [?]struct {mode: game.App_Mode, live, preview: ^game.Remaining_Sim_State, settings: rawptr} {
		{.Slime_Mold, &ui.slime_mold, &ui.preview_slime_mold, ui.slime_mold.slime},
		{.Flow_Field, &ui.flow_field, &ui.preview_flow_field, ui.flow_field.flow},
		{.Pellets, &ui.pellets, &ui.preview_pellets, ui.pellets.pellets},
		{.Voronoi_CA, &ui.voronoi_ca, &ui.preview_voronoi_ca, ui.voronoi_ca.voronoi},
		{.Moire, &ui.moire, &ui.preview_moire, ui.moire.moire},
		{.Vectors, &ui.vectors, &ui.preview_vectors, ui.vectors.vectors},
		{.Primordial, &ui.primordial, &ui.preview_primordial, ui.primordial.primordial},
	}
	for view in views {
		live := game.feature_instance_set_get(&ui.feature_instances, view.mode)
		preview := game.feature_instance_set_get(&ui.feature_instances, view.mode, true)
		testing.expect(t, live != nil && preview != nil)
		testing.expect(t, view.live.runtime == live.runtime)
		testing.expect(t, view.preview.runtime == preview.runtime)
		testing.expect(t, view.settings == live.settings)
		testing.expect(t, live.settings != preview.settings && live.runtime != preview.runtime)
	}
}

@(test)
test_gray_scott_simulation_is_a_view_over_descriptor_owned_product_storage :: proc(t: ^testing.T) {
	instance: game.Feature_Instance
	testing.expect(t, game.feature_instance_init(&instance, .Gray_Scott))
	defer game.feature_instance_destroy(&instance)
	sim: game.Gray_Scott_Simulation
	testing.expect(t, game.gray_scott_bind_product_instance(&sim, &instance))
	settings, settings_ok := game.feature_instance_settings(&instance, game.Gray_Scott_Settings)
	runtime, runtime_ok := game.feature_instance_runtime(&instance, game.Gray_Scott_Runtime_State)
	testing.expect(t, settings_ok && runtime_ok)
	testing.expect(t, sim.settings == settings && sim.runtime == runtime)
	game.gray_scott_init(&sim, 640, 480)
	sim.settings.feed = 0.041
	sim.runtime.seed = 1234
	testing.expect_value(t, settings.feed, f32(0.041))
	testing.expect_value(t, runtime.seed, u32(1234))
}

@(test)
test_particle_life_simulation_is_a_view_over_descriptor_owned_product_storage :: proc(t: ^testing.T) {
	instance: game.Feature_Instance
	testing.expect(t, game.feature_instance_init(&instance, .Particle_Life))
	defer game.feature_instance_destroy(&instance)
	sim: game.Particle_Life_Simulation
	testing.expect(t, game.particle_life_bind_product_instance(&sim, &instance))
	settings, settings_ok := game.feature_instance_settings(&instance, game.Particle_Life_Settings)
	runtime, runtime_ok := game.feature_instance_runtime(&instance, game.Particle_Life_Runtime_State)
	testing.expect(t, settings_ok && runtime_ok)
	testing.expect(t, sim.settings == settings && sim.runtime == runtime)
	game.particle_life_init(&sim, 640, 480)
	sim.settings.particle_count = 12_000
	sim.runtime.seed = 9876
	testing.expect_value(t, settings.particle_count, u32(12_000))
	testing.expect_value(t, runtime.seed, u32(9876))
}

@(test)
test_render_graph_compiles_hazards_deterministically :: proc(t: ^testing.T) {
	graph: rendervk.Render_Graph
	resource := rendervk.render_graph_add_resource(&graph, "state", .Storage_Image, false)
	rendervk.render_graph_add_pass(&graph, "write", nil, []rendervk.Render_Resource_Handle{resource}, nil)
	rendervk.render_graph_add_pass(&graph, "read", []rendervk.Render_Resource_Handle{resource}, nil, nil)
	rendervk.render_graph_add_pass(&graph, "rewrite", nil, []rendervk.Render_Resource_Handle{resource}, nil)

	testing.expect(t, rendervk.render_graph_compile(&graph))
	testing.expect_value(t, graph.compiled_count, 3)
	testing.expect_value(t, graph.compiled_order[0], 0)
	testing.expect_value(t, graph.compiled_order[1], 1)
	testing.expect_value(t, graph.compiled_order[2], 2)
	testing.expect_value(t, graph.resource_first_use[int(resource)], 0)
	testing.expect_value(t, graph.resource_last_use[int(resource)], 2)
	testing.expect(t, graph.edges[0][1])
	testing.expect(t, !graph.edges[0][2])
	testing.expect(t, graph.edges[1][2])
}

@(test)
test_render_graph_aliases_only_non_overlapping_compatible_transients :: proc(t: ^testing.T) {
	graph: rendervk.Render_Graph
	a := rendervk.render_graph_add_resource(&graph, "a", .Storage_Image, true)
	b := rendervk.render_graph_add_resource(&graph, "b", .Storage_Image, true)
	c := rendervk.render_graph_add_resource(&graph, "c", .Vertex_Buffer, true)
	rendervk.render_graph_add_pass(&graph, "write a", nil, []rendervk.Render_Resource_Handle{a}, nil)
	rendervk.render_graph_add_pass(&graph, "read a", []rendervk.Render_Resource_Handle{a}, nil, nil)
	rendervk.render_graph_add_pass(&graph, "write b and c", nil, []rendervk.Render_Resource_Handle{b, c}, nil)
	testing.expect(t, rendervk.render_graph_compile(&graph))
	testing.expect_value(t, graph.resource_physical_slot[int(a)], graph.resource_physical_slot[int(b)])
	testing.expect(t, graph.resource_physical_slot[int(c)] != graph.resource_physical_slot[int(a)])
	testing.expect_value(t, graph.transient_barrier_count, 3)
	testing.expect_value(t, graph.transient_barriers[1].previous_resource, a)
}

@(test)
test_render_graph_alias_slot_checks_every_prior_lifetime :: proc(t: ^testing.T) {
	graph: rendervk.Render_Graph
	a := rendervk.render_graph_add_resource(&graph, "a", .Vertex_Buffer, true)
	b := rendervk.render_graph_add_resource(&graph, "b", .Vertex_Buffer, true)
	c := rendervk.render_graph_add_resource(&graph, "c", .Vertex_Buffer, true)
	_ = rendervk.render_graph_set_resource_shape(&graph, a, byte_size = 256, usage = 1)
	_ = rendervk.render_graph_set_resource_shape(&graph, b, byte_size = 256, usage = 1)
	_ = rendervk.render_graph_set_resource_shape(&graph, c, byte_size = 256, usage = 1)
	rendervk.render_graph_add_pass(&graph, "use a", nil, []rendervk.Render_Resource_Handle{a}, nil)
	rendervk.render_graph_add_pass(&graph, "start b", nil, []rendervk.Render_Resource_Handle{b}, nil)
	rendervk.render_graph_add_pass(&graph, "use c", nil, []rendervk.Render_Resource_Handle{c}, nil)
	rendervk.render_graph_add_pass(&graph, "finish b", []rendervk.Render_Resource_Handle{b}, nil, nil)
	testing.expect(t, rendervk.render_graph_compile(&graph))
	testing.expect_value(t, graph.resource_physical_slot[int(a)], graph.resource_physical_slot[int(b)])
	testing.expect(t, graph.resource_physical_slot[int(c)] != graph.resource_physical_slot[int(a)])
}

@(test)
test_render_graph_rejects_aliasing_for_incompatible_shapes_and_exposes_diagnostics :: proc(t: ^testing.T) {
	graph: rendervk.Render_Graph
	a := rendervk.render_graph_add_resource(&graph, "rgba16", .Storage_Image, true)
	b := rendervk.render_graph_add_resource(&graph, "rgba8", .Storage_Image, true)
	testing.expect(t, rendervk.render_graph_set_resource_shape(&graph, a, .R16G16B16A16_SFLOAT, 256, 256, 1, usage = 1))
	testing.expect(t, rendervk.render_graph_set_resource_shape(&graph, b, .R8G8B8A8_UNORM, 256, 256, 1, usage = 1))
	rendervk.render_graph_add_pass(&graph, "write a", nil, []rendervk.Render_Resource_Handle{a}, nil)
	rendervk.render_graph_add_pass(&graph, "read a", []rendervk.Render_Resource_Handle{a}, nil, nil)
	rendervk.render_graph_add_pass(&graph, "write b", nil, []rendervk.Render_Resource_Handle{b}, nil)
	testing.expect(t, rendervk.render_graph_compile(&graph))
	testing.expect(t, graph.resource_physical_slot[int(a)] != graph.resource_physical_slot[int(b)])
	diagnostics := rendervk.render_graph_diagnostics(&graph)
	testing.expect(t, diagnostics.compiled)
	testing.expect_value(t, diagnostics.compile_error, rendervk.Render_Graph_Compile_Error.None)
	testing.expect_value(t, diagnostics.pass_count, 3)
	testing.expect_value(t, diagnostics.resource_count, 2)
	testing.expect_value(t, diagnostics.resource_first_use[int(a)], 0)
	testing.expect_value(t, diagnostics.resource_last_use[int(a)], 1)
}

@(test)
test_render_graph_hazards_respect_image_subresources :: proc(t: ^testing.T) {
	graph: rendervk.Render_Graph
	image := rendervk.render_graph_add_resource(&graph, "mipped image", .Storage_Image, false)
	rendervk.render_graph_add_pass(&graph, "write mip 0", nil, nil, nil)
	rendervk.render_graph_add_pass(&graph, "write mip 1", nil, nil, nil)
	rendervk.render_graph_add_pass(&graph, "read mip 0", nil, nil, nil)
	mip_0 := rendervk.Render_Subresource_Range{base_mip_level = 0, level_count = 1, base_array_layer = 0, layer_count = 1}
	mip_1 := rendervk.Render_Subresource_Range{base_mip_level = 1, level_count = 1, base_array_layer = 0, layer_count = 1}
	testing.expect(t, rendervk.render_graph_add_use(&graph.passes[0], image, .Write, subresource = mip_0))
	testing.expect(t, rendervk.render_graph_add_use(&graph.passes[1], image, .Write, subresource = mip_1))
	testing.expect(t, rendervk.render_graph_add_use(&graph.passes[2], image, .Read, subresource = mip_0))
	testing.expect(t, rendervk.render_graph_compile(&graph))
	testing.expect(t, graph.edges[0][2])
	testing.expect(t, !graph.edges[0][1])
	testing.expect(t, !graph.edges[1][2])
}

@(test)
test_render_graph_rejects_explicit_dependency_cycle :: proc(t: ^testing.T) {
	graph: rendervk.Render_Graph
	rendervk.render_graph_add_pass(&graph, "a", nil, nil, nil)
	rendervk.render_graph_add_pass(&graph, "b", nil, nil, nil)
	testing.expect(t, rendervk.render_graph_add_explicit_dependency(&graph, 0, 1))
	testing.expect(t, rendervk.render_graph_add_explicit_dependency(&graph, 1, 0))
	testing.expect(t, !rendervk.render_graph_compile(&graph))
	testing.expect_value(t, graph.compile_error, rendervk.Render_Graph_Compile_Error.Cycle)
}

@(test)
test_render_graph_excludes_structurally_disabled_passes :: proc(t: ^testing.T) {
	graph: rendervk.Render_Graph
	resource := rendervk.render_graph_add_resource(&graph, "state", .Storage_Image, false)
	rendervk.render_graph_add_pass(&graph, "write", nil, []rendervk.Render_Resource_Handle{resource}, nil)
	rendervk.render_graph_add_pass(&graph, "disabled read", []rendervk.Render_Resource_Handle{resource}, nil, nil)
	rendervk.render_graph_add_pass(&graph, "rewrite", nil, []rendervk.Render_Resource_Handle{resource}, nil)
	testing.expect(t, rendervk.render_graph_set_pass_enabled(&graph, 1, false))
	testing.expect(t, rendervk.render_graph_compile(&graph))
	testing.expect_value(t, graph.compiled_count, 2)
	testing.expect_value(t, graph.compiled_order[0], 0)
	testing.expect_value(t, graph.compiled_order[1], 2)
	testing.expect(t, graph.edges[0][2])
	testing.expect(t, !graph.edges[0][1] && !graph.edges[1][2])
	diagnostics := rendervk.render_graph_diagnostics(&graph)
	testing.expect_value(t, diagnostics.disabled_pass_count, 1)
	testing.expect_value(t, diagnostics.disabled_passes[0], 1)
}

@(test)
test_render_graph_imported_state_validation_uses_per_frame_binding :: proc(t: ^testing.T) {
	graph: rendervk.Render_Graph
	image := rendervk.render_graph_add_resource(&graph, "imported", .Sampled_Image, false, true)
	rendervk.render_graph_add_pass(&graph, "sample", []rendervk.Render_Resource_Handle{image}, nil, nil)
	testing.expect(t, rendervk.render_graph_set_pass_use(&graph, 0, image, .Read, {.FRAGMENT_SHADER}, {.SHADER_SAMPLED_READ}, .SHADER_READ_ONLY_OPTIMAL))
	testing.expect(t, rendervk.render_graph_compile(&graph))
	ctx: rendervk.Render_Context
	testing.expect(t, rendervk.render_graph_bind_imported_image(&graph, &ctx, image, vk.Image(1), .SHADER_READ_ONLY_OPTIMAL, {.FRAGMENT_SHADER}, {.SHADER_SAMPLED_READ}))
	testing.expect(t, rendervk.render_graph_validate_imported_states(&graph, &ctx))
	ctx.imported_resources[int(image)].observed_layout = .GENERAL
	testing.expect(t, !rendervk.render_graph_validate_imported_states(&graph, &ctx))
	missing: rendervk.Render_Context
	testing.expect(t, !rendervk.render_graph_validate_imported_states(&graph, &missing))
}

@(test)
test_render_graph_cache_reuses_only_matching_structure :: proc(t: ^testing.T) {
	cache: rendervk.Render_Graph_Cache
	key := rendervk.Render_Graph_Structural_Key{mode = .Moire, preview_count = 0, capture_active = false, target_format = .B8G8R8A8_SRGB}
	first := rendervk.render_graph_cache_resolve(&cache, key)
	testing.expect(t, first != nil)
	testing.expect_value(t, cache.compile_count, u64(1))
	testing.expect_value(t, first.compiled_count, 6)
	testing.expect_value(t, rendervk.render_graph_diagnostics(first).disabled_pass_count, 1)
	second := rendervk.render_graph_cache_resolve(&cache, key)
	testing.expect(t, second == first)
	testing.expect_value(t, cache.compile_count, u64(1))
	key.capture_active = true
	third := rendervk.render_graph_cache_resolve(&cache, key)
	testing.expect(t, third != nil)
	testing.expect_value(t, cache.compile_count, u64(2))
	testing.expect_value(t, third.compiled_count, 7)
	testing.expect_value(t, rendervk.render_graph_diagnostics(third).disabled_pass_count, 0)
}

@(test)
test_render_graph_cache_distinguishes_equal_sized_preview_sets :: proc(t: ^testing.T) {
	cache: rendervk.Render_Graph_Cache
	key := rendervk.Render_Graph_Structural_Key{mode = .Main_Menu, preview_count = 2, preview_mode_mask = (u32(1) << u32(game.App_Mode.Gray_Scott)) | (u32(1) << u32(game.App_Mode.Moire)), target_format = .B8G8R8A8_SRGB}
	testing.expect(t, rendervk.render_graph_cache_resolve(&cache, key) != nil)
	testing.expect_value(t, cache.compile_count, u64(1))
	key.preview_mode_mask = (u32(1) << u32(game.App_Mode.Gray_Scott)) | (u32(1) << u32(game.App_Mode.Flow_Field))
	testing.expect(t, rendervk.render_graph_cache_resolve(&cache, key) != nil)
	testing.expect_value(t, cache.compile_count, u64(2))
}

@(test)
test_render_graph_preview_mask_is_order_independent :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	ui.main_menu_preview_slot_count = 2
	ui.main_menu_preview_slots[0].mode = .Slime_Mold
	ui.main_menu_preview_slots[1].mode = .Vectors
	first := rendervk.render_graph_preview_mode_mask(&ui)
	ui.main_menu_preview_slots[0].mode = .Vectors
	ui.main_menu_preview_slots[1].mode = .Slime_Mold
	testing.expect_value(t, rendervk.render_graph_preview_mode_mask(&ui), first)
}

@(test)
test_main_menu_graph_declares_each_visible_preview_output :: proc(t: ^testing.T) {
	mask := (u32(1) << u32(game.App_Mode.Gray_Scott)) | (u32(1) << u32(game.App_Mode.Particle_Life))
	graph := rendervk.render_graph_build_v1(.Main_Menu, false, mask)
	testing.expect_value(t, graph.resource_count, 4) // swapchain, two previews, UI vertices
	testing.expect(t, graph.resources[1].feature_owned && graph.resources[1].external)
	testing.expect(t, graph.resources[2].feature_owned && graph.resources[2].external)
	testing.expect_value(t, graph.resources[1].kind, rendervk.Render_Resource_Kind.Storage_Image)
	testing.expect_value(t, graph.resources[2].kind, rendervk.Render_Resource_Kind.Vertex_Buffer)
	testing.expect(t, rendervk.render_graph_compile(&graph))
	preview_barrier_count := 0
	for barrier in graph.barriers[:graph.barrier_count] {
		if barrier.producer_pass == 1 && barrier.consumer_pass == 3 do preview_barrier_count += 1
	}
	testing.expect_value(t, preview_barrier_count, 2)
}

@(test)
test_render_graph_v1_declares_swapchain_transition_chain :: proc(t: ^testing.T) {
	graph := rendervk.render_graph_build_v1()
	testing.expect(t, rendervk.render_graph_compile(&graph))
	found_acquire_to_color := false
	found_color_to_present := false
	for barrier in graph.barriers[:graph.barrier_count] {
		if barrier.producer_pass == 0 && barrier.consumer_pass == 3 {
			found_acquire_to_color = barrier.old_layout == .PRESENT_SRC_KHR && barrier.new_layout == .COLOR_ATTACHMENT_OPTIMAL &&
				barrier.dst_stage == vk.PipelineStageFlags2{.COLOR_ATTACHMENT_OUTPUT} && .COLOR_ATTACHMENT_WRITE in barrier.dst_access
		}
		if barrier.producer_pass == 5 && barrier.consumer_pass == 6 {
			found_color_to_present = barrier.old_layout == .COLOR_ATTACHMENT_OPTIMAL && barrier.new_layout == .PRESENT_SRC_KHR &&
				.COLOR_ATTACHMENT_WRITE in barrier.src_access
		}
	}
	testing.expect(t, found_acquire_to_color)
	testing.expect(t, found_color_to_present)
}

@(test)
test_video_capture_pass_owns_swapchain_transfer_transitions :: proc(t: ^testing.T) {
	graph := rendervk.render_graph_build_v1(.Moire, true)
	testing.expect(t, rendervk.render_graph_compile(&graph))
	to_transfer, back_to_color := false, false
	for barrier in graph.barriers[:graph.barrier_count] {
		if barrier.resource != rendervk.Render_Resource_Handle(0) do continue
		if barrier.producer_pass == 3 && barrier.consumer_pass == 4 {
			to_transfer = barrier.old_layout == .COLOR_ATTACHMENT_OPTIMAL && barrier.new_layout == .TRANSFER_SRC_OPTIMAL && .TRANSFER_READ in barrier.dst_access
		}
		if barrier.producer_pass == 4 && barrier.consumer_pass == 5 {
			back_to_color = barrier.old_layout == .TRANSFER_SRC_OPTIMAL && barrier.new_layout == .COLOR_ATTACHMENT_OPTIMAL && .COLOR_ATTACHMENT_WRITE in barrier.dst_access
		}
	}
	testing.expect(t, to_transfer)
	testing.expect(t, back_to_color)
}

@(test)
test_capture_readback_pool_reuses_safe_frame_slot_buffer :: proc(t: ^testing.T) {
	backend: rendervk.Render_Backend
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 320, height = 180}
	backend.capture_readback_buffers[0][1] = {handle = vk.Buffer(7), size = vk.DeviceSize(320 * 180 * 4), mapped = rawptr(uintptr(1))}
	ctx := rendervk.Render_Context{backend = &backend, vk_ctx = &vk_ctx, frame = {frame_index = 1}}
	buffer := rendervk.render_backend_capture_readback_buffer(&ctx, 0)
	testing.expect(t, buffer != nil)
	if buffer != nil do testing.expect_value(t, buffer.handle, vk.Buffer(7))
	testing.expect_value(t, backend.capture_readback_reuse_count, u64(1))
	testing.expect_value(t, backend.capture_readback_allocation_count, u64(0))
	diagnostics := rendervk.render_backend_graph_diagnostics(&backend)
	testing.expect_value(t, diagnostics.physical_reuse_count, u64(0))
	testing.expect_value(t, diagnostics.physical_allocation_count, u64(0))
}

@(test)
test_render_graph_diagnostics_report_graph_owned_transient_pool :: proc(t: ^testing.T) {
	backend := rendervk.Render_Backend{transient_allocation_count = 4, transient_reuse_count = 9}
	diagnostics := rendervk.render_backend_graph_diagnostics(&backend)
	testing.expect_value(t, diagnostics.physical_allocation_count, u64(4))
	testing.expect_value(t, diagnostics.physical_reuse_count, u64(9))
}

@(test)
test_render_graph_feature_resource_matches_active_mode :: proc(t: ^testing.T) {
	image_graph := rendervk.render_graph_build_v1(.Gray_Scott)
	buffer_graph := rendervk.render_graph_build_v1(.Particle_Life)
	menu_graph := rendervk.render_graph_build_v1(.Main_Menu)
	testing.expect_value(t, image_graph.resources[1].kind, rendervk.Render_Resource_Kind.Storage_Image)
	testing.expect(t, image_graph.resources[1].external)
	testing.expect_value(t, buffer_graph.resources[1].kind, rendervk.Render_Resource_Kind.Vertex_Buffer)
	testing.expect(t, buffer_graph.resources[1].external)
	testing.expect(t, menu_graph.resources[1].external)
	testing.expect(t, !menu_graph.resources[1].transient)
	testing.expect_value(t, menu_graph.resources[1].name, "ui frame vertices")
}

@(test)
test_render_feature_descriptors_bind_real_graph_resources :: proc(t: ^testing.T) {
	modes := [?]game.App_Mode{.Gray_Scott, .Particle_Life, .Flow_Field, .Pellets, .Voronoi_CA, .Moire, .Vectors, .Primordial, .Slime_Mold}
	for mode in modes {
		descriptor, ok := rendervk.render_feature_descriptor_by_mode(mode)
		testing.expect(t, ok)
		if ok do testing.expect(t, descriptor.bind_graph_resource != nil)
	}
}

@(test)
test_render_feature_descriptors_declare_target_resource_release :: proc(t: ^testing.T) {
	rebuild_modes := [?]game.App_Mode{.Slime_Mold, .Flow_Field, .Pellets, .Voronoi_CA, .Moire, .Vectors, .Primordial}
	for mode in rebuild_modes {
		descriptor, ok := rendervk.render_feature_descriptor_by_mode(mode)
		testing.expect(t, ok)
		if ok do testing.expect(t, descriptor.release_target_resources != nil)
	}
	preserved_modes := [?]game.App_Mode{.Gray_Scott, .Particle_Life}
	for mode in preserved_modes {
		descriptor, ok := rendervk.render_feature_descriptor_by_mode(mode)
		testing.expect(t, ok)
		if ok do testing.expect(t, descriptor.release_target_resources == nil)
	}
}

@(test)
test_feature_command_schema_validates_owned_payload :: proc(t: ^testing.T) {
	settings := game.moire_settings_default()
	command, made := game.feature_command_make(game.FEATURE_ID_MOIRE, game.FEATURE_COMMAND_APPLY_SETTINGS, &settings)
	testing.expect(t, made)
	testing.expect_value(t, game.feature_command_validate(&command), game.Feature_Result_Error.None)
	payload, payload_ok := game.feature_command_payload(&command, game.Moire_Settings)
	testing.expect(t, payload_ok)
	if payload_ok {
		testing.expect_value(t, payload.generator_index, settings.generator_index)
	}
	command.payload_size -= 1
	testing.expect_value(t, game.feature_command_validate(&command), game.Feature_Result_Error.Size_Mismatch)
}

@(test)
test_simulation_feature_descriptors_own_mutation_and_preset_contracts :: proc(t: ^testing.T) {
	for index in 0 ..< game.feature_count() {
		descriptor, ok := game.feature_descriptor_at(index)
		testing.expect(t, ok)
		if !ok || descriptor == nil do continue
		testing.expect(t, descriptor.draw_ui != nil)
		testing.expect(t, descriptor.enter != nil)
		testing.expect(t, descriptor.leave != nil)
		if descriptor.mode == .Slime_Mold || .Tool in descriptor.capabilities {
			testing.expect(t, descriptor.draw_controls == nil)
		} else {
			testing.expect(t, descriptor.draw_controls != nil)
		}
		if .Simulation in descriptor.capabilities {
			testing.expect(t, descriptor.apply_settings != nil)
			testing.expect(t, descriptor.reset != nil)
			testing.expect(t, descriptor.preset_load != nil)
			testing.expect(t, descriptor.preset_save != nil)
			testing.expect(t, descriptor.update != nil)
			testing.expect(t, descriptor.builtin_preset_names != nil)
			testing.expect(t, descriptor.apply_input != nil)
			testing.expect(t, descriptor.set_paused != nil)
			if descriptor.builtin_preset_names != nil do testing.expect(t, len(descriptor.builtin_preset_names()) > 0)
			if .Image_Source in descriptor.capabilities {
				testing.expect(t, descriptor.image_target_count > 0)
				for slot in 0 ..< descriptor.image_target_count {
					target, target_ok := game.feature_image_target(descriptor.id, u16(slot))
					testing.expect(t, target_ok)
					if target_ok {
						testing.expect_value(t, target, descriptor.image_targets[slot])
						feature_id, resolved_slot, location_ok := game.feature_image_target_location(target)
						testing.expect(t, location_ok)
						testing.expect_value(t, feature_id, descriptor.id)
						testing.expect_value(t, resolved_slot, u16(slot))
					}
				}
			}
		} else {
			testing.expect(t, descriptor.apply_settings == nil)
			testing.expect(t, descriptor.reset == nil)
			testing.expect(t, descriptor.preset_load == nil)
			testing.expect(t, descriptor.preset_save == nil)
			testing.expect(t, descriptor.update == nil)
			testing.expect(t, descriptor.builtin_preset_names == nil)
			testing.expect(t, descriptor.apply_input == nil)
			testing.expect(t, descriptor.set_paused == nil)
		}
	}
}

@(test)
test_feature_lifecycle_dispatch_owns_pause_state :: proc(t: ^testing.T) {
	testing.expect(t, game.app_ui_mode_is_simulation(.Gray_Scott))
	testing.expect(t, !game.app_ui_mode_is_simulation(.Gradient_Editor))
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)
	ui.gray_scott.settings.paused = false
	ui.flow_field.paused = false
	testing.expect(t, game.feature_instance_set_enter(&ui.feature_instances, .Gray_Scott))
	testing.expect(t, game.feature_instance_set_leave(&ui.feature_instances, .Gray_Scott))
	testing.expect(t, ui.gray_scott.settings.paused)
	testing.expect(t, game.feature_instance_set_leave(&ui.feature_instances, .Flow_Field))
	testing.expect(t, ui.flow_field.paused)
	testing.expect(t, game.feature_instance_set_enter(&ui.feature_instances, .Gradient_Editor))
	testing.expect(t, game.feature_instance_set_leave(&ui.feature_instances, .Gradient_Editor))
}

@(test)
test_feature_image_commands_are_schema_owned_and_feature_scoped :: proc(t: ^testing.T) {
	payload: game.Feature_Image_Command
	game.write_fixed_string(payload.path[:], "/tmp/vector.png")
	payload.slot = 0
	payload.dialog_request_id = 37
	command, made := game.feature_command_make(game.FEATURE_ID_VECTORS, game.FEATURE_COMMAND_LOAD_IMAGE, &payload)
	testing.expect(t, made)
	testing.expect_value(t, game.feature_command_validate(&command), game.Feature_Result_Error.None)
	decoded, decoded_ok := game.feature_command_payload(&command, game.Feature_Image_Command)
	testing.expect(t, decoded_ok)
	if decoded_ok {
		testing.expect_value(t, game.fixed_string(decoded.path[:]), "/tmp/vector.png")
		testing.expect_value(t, decoded.slot, u16(0))
		testing.expect_value(t, decoded.dialog_request_id, u64(37))
	}
	_, unsupported := game.feature_command_make(game.FEATURE_ID_PARTICLE_LIFE, game.FEATURE_COMMAND_LOAD_IMAGE, &payload)
	testing.expect(t, !unsupported)
}

@(test)
test_image_dialog_request_generation_rejects_stale_and_duplicate_results :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	ui.pending_image_dialog_requests[int(game.Feature_Image_Target.Vectors)] = 42
	testing.expect(t, !game.app_ui_consume_image_dialog_request(&ui, .Vectors, 41))
	testing.expect(t, game.app_ui_consume_image_dialog_request(&ui, .Vectors, 42))
	testing.expect(t, !game.app_ui_consume_image_dialog_request(&ui, .Vectors, 42))
}

@(test)
test_feature_image_command_reports_stale_dialog_result :: proc(t: ^testing.T) {
	state: host.Render_Worker_State
	runtime := new(host.Render_Worker_Runtime)
	defer free(runtime)
	queue := new(game.Render_To_Ui_Queue)
	defer free(queue)
	state.render_to_ui = queue
	runtime.app_ui.mode = .Vectors
	runtime.app_ui.pending_image_dialog_requests[int(game.Feature_Image_Target.Vectors)] = 99
	payload := game.Feature_Image_Command{slot = 0, dialog_request_id = 98}
	game.write_fixed_string(payload.path[:], "/tmp/stale.png")
	command, made := game.feature_command_make(game.FEATURE_ID_VECTORS, game.FEATURE_COMMAND_LOAD_IMAGE, &payload)
	testing.expect(t, made)
	host.render_worker_handle_feature_command(&state, runtime, &command)
	message: game.Render_To_Ui_Message
	testing.expect(t, engine.queue_try_pop(queue, &message))
	testing.expect_value(t, message.kind, game.Render_To_Ui_Message_Kind.Feature_Result)
	testing.expect_value(t, message.feature_result.error, game.Feature_Result_Error.Stale_Result)
	testing.expect_value(t, runtime.app_ui.pending_image_dialog_requests[int(game.Feature_Image_Target.Vectors)], u64(99))
}

@(test)
test_feature_image_command_returns_typed_platform_dialog_request :: proc(t: ^testing.T) {
	state: host.Render_Worker_State
	runtime := new(host.Render_Worker_Runtime)
	defer free(runtime)
	queue := new(game.Render_To_Ui_Queue)
	defer free(queue)
	state.render_to_ui = queue
	runtime.app_ui.mode = .Vectors
	runtime.app_ui.pending_image_dialog_requests[int(game.Feature_Image_Target.Vectors)] = 77
	payload := game.Feature_Image_Command{slot = 0, dialog_request_id = 77}
	command, made := game.feature_command_make(game.FEATURE_ID_VECTORS, game.FEATURE_COMMAND_LOAD_IMAGE, &payload)
	testing.expect(t, made)
	host.render_worker_handle_feature_command(&state, runtime, &command)
	message: game.Render_To_Ui_Message
	testing.expect(t, engine.queue_try_pop(queue, &message))
	testing.expect(t, message.feature_result.success)
	testing.expect_value(t, message.feature_result.dialog.kind, game.Feature_Platform_Dialog_Kind.Open_Image)
	testing.expect_value(t, message.feature_result.dialog.request_id, u64(77))
	testing.expect_value(t, message.feature_result.dialog.feature_id, game.FEATURE_ID_VECTORS)
	testing.expect_value(t, message.feature_result.dialog.slot, u16(0))
	// Issuing the platform request does not consume it; only a matching callback does.
	testing.expect_value(t, runtime.app_ui.pending_image_dialog_requests[int(game.Feature_Image_Target.Vectors)], u64(77))
}

@(test)
test_named_preset_commands_are_owned_and_feature_scoped :: proc(t: ^testing.T) {
	payload := game.Feature_Preset_File_Command {operation = .Save}
	game.write_fixed_string(payload.path[:], "moire/example.toml")
	command, made := game.feature_command_make(game.FEATURE_ID_MOIRE, game.FEATURE_COMMAND_PRESET_FILE, &payload)
	testing.expect(t, made)
	testing.expect_value(t, game.feature_command_validate(&command), game.Feature_Result_Error.None)
	decoded, decoded_ok := game.feature_command_payload(&command, game.Feature_Preset_File_Command)
	testing.expect(t, decoded_ok)
	if decoded_ok {
		testing.expect_value(t, decoded.operation, game.Feature_Preset_File_Operation.Save)
		testing.expect_value(t, game.fixed_string(decoded.path[:]), "moire/example.toml")
	}
}

@(test)
test_feature_commands_reject_shutdown_with_structured_result :: proc(t: ^testing.T) {
	state: host.Render_Worker_State
	runtime := new(host.Render_Worker_Runtime)
	defer free(runtime)
	queue := new(game.Render_To_Ui_Queue)
	defer free(queue)
	state.render_to_ui = queue
	state.shutdown_started = true
	runtime.app_ui.mode = .Moire
	payload := game.Feature_Reset_Command{}
	command, made := game.feature_command_make(game.FEATURE_ID_MOIRE, game.FEATURE_COMMAND_RESET, &payload)
	testing.expect(t, made)
	host.render_worker_handle_feature_command(&state, runtime, &command)
	message: game.Render_To_Ui_Message
	testing.expect(t, engine.queue_try_pop(queue, &message))
	testing.expect_value(t, message.kind, game.Render_To_Ui_Message_Kind.Feature_Result)
	testing.expect(t, !message.feature_result.success)
	testing.expect_value(t, message.feature_result.error, game.Feature_Result_Error.Shutting_Down)
	testing.expect_value(t, message.feature_result.feature_id, game.FEATURE_ID_MOIRE)
	testing.expect_value(t, message.feature_result.command_id, game.FEATURE_COMMAND_RESET)
}

@(test)
test_moire_render_feature_runtime_is_aligned_owned_storage :: proc(t: ^testing.T) {
	instance: rendervk.Render_Feature_Instance
	testing.expect(t, rendervk.render_feature_instance_init(&instance, .Moire))
	runtime, ok := rendervk.render_feature_instance_runtime(&instance, rendervk.Moire_Gpu_State)
	testing.expect(t, ok)
	testing.expect(t, runtime != nil)
	if runtime != nil {
		testing.expect_value(t, uintptr(runtime) % uintptr(align_of(rendervk.Moire_Gpu_State)), uintptr(0))
	}
	vk_ctx: engine.Vk_Context
	rendervk.render_feature_instance_destroy(&instance, &vk_ctx)
	testing.expect(t, instance.runtime == nil)
}

@(test)
test_migrated_render_feature_instances_allocate_and_destroy :: proc(t: ^testing.T) {
	modes := [?]game.App_Mode{
		.Moire,
		.Voronoi_CA,
		.Pellets,
		.Primordial,
		.Flow_Field,
		.Slime_Mold,
		.Vectors,
		.Gray_Scott,
		.Particle_Life,
	}
	for mode in modes {
		instance: rendervk.Render_Feature_Instance
		testing.expect(t, rendervk.render_feature_instance_init(&instance, mode))
		testing.expect(t, instance.runtime != nil)
		testing.expect(t, instance.descriptor != nil)
		vk_ctx: engine.Vk_Context
		rendervk.render_feature_instance_destroy(&instance, &vk_ctx)
		testing.expect(t, instance.runtime == nil)
	}
}

@(test)
test_render_feature_instance_set_is_registry_indexed_and_owns_preview_variants :: proc(t: ^testing.T) {
	set: rendervk.Render_Feature_Instance_Set
	vk_ctx: engine.Vk_Context
	testing.expect(t, rendervk.render_feature_instance_set_init(&set, &vk_ctx))
	modes := [?]game.App_Mode{.Slime_Mold, .Gray_Scott, .Particle_Life, .Flow_Field, .Pellets, .Voronoi_CA, .Moire, .Vectors, .Primordial}
	for mode in modes {
		primary := rendervk.render_feature_instance_set_get(&set, mode)
		preview := rendervk.render_feature_instance_set_get(&set, mode, true)
		testing.expect(t, primary != nil && primary.runtime != nil)
		testing.expect(t, preview != nil && preview.runtime != nil)
		testing.expect(t, primary != preview && primary.runtime != preview.runtime)
	}
	testing.expect(t, rendervk.render_feature_instance_set_get(&set, .Gradient_Editor) != nil)
	testing.expect(t, rendervk.render_feature_instance_set_get(&set, .Gradient_Editor).runtime == nil)
	rendervk.render_feature_instance_set_destroy(&set, &vk_ctx)
	for mode in modes {
		instance := rendervk.render_feature_instance_set_get(&set, mode)
		testing.expect(t, instance != nil && instance.runtime == nil && instance.storage == nil)
	}
}

@(test)
test_feature_descriptors_route_color_and_render_invalidation_without_mode_switches :: proc(t: ^testing.T) {
	product: game.Feature_Instance
	testing.expect(t, game.feature_instance_init(&product, .Moire))
	defer game.feature_instance_destroy(&product)
	descriptor, found := game.feature_descriptor_by_mode(.Moire)
	testing.expect(t, found && descriptor.color_scheme_access != nil)
	name, reversed, access_ok := descriptor.color_scheme_access(product.settings)
	testing.expect(t, access_ok && name != nil && reversed != nil)
	game.color_scheme_name_set(name, "ZELDA_Aqua")
	reversed^ = true
	settings, settings_ok := game.feature_instance_settings(&product, game.Moire_Settings)
	testing.expect(t, settings_ok)
	testing.expect_value(t, game.color_scheme_name_get(&settings.color_scheme), "ZELDA_Aqua")
	testing.expect(t, settings.color_scheme_reversed)

	render: rendervk.Render_Feature_Instance
	testing.expect(t, rendervk.render_feature_instance_init(&render, .Primordial))
	vk_ctx: engine.Vk_Context
	defer rendervk.render_feature_instance_destroy(&render, &vk_ctx)
	render_descriptor, render_found := rendervk.render_feature_descriptor_by_mode(.Primordial)
	gpu, gpu_ok := rendervk.render_feature_instance_runtime(&render, rendervk.Primordial_Gpu_State)
	testing.expect(t, render_found && gpu_ok && render_descriptor.invalidate_runtime != nil)
	gpu.ready = true
	render_descriptor.invalidate_runtime(render.runtime)
	testing.expect(t, !gpu.ready)
}

test_approx_f32 :: proc(a, b: f32) -> bool {
	return math.abs(a - b) <= 0.01
}

@(test)
test_simulation_substeps_preserve_real_time_with_bounded_steps :: proc(t: ^testing.T) {
	fast := rendervk.simulation_substeps(1.0 / 240.0)
	testing.expect_value(t, fast.count, 1)
	testing.expect(t, math.abs(fast.delta_time - f32(1.0 / 240.0)) < 0.00001)

	normal := rendervk.simulation_substeps(1.0 / 60.0)
	testing.expect_value(t, normal.count, 2)
	testing.expect(t, normal.delta_time <= rendervk.SIMULATION_MAX_SUBSTEP_SECONDS)
	testing.expect(t, math.abs(normal.delta_time * f32(normal.count) - f32(1.0 / 60.0)) < 0.00001)

	stalled := rendervk.simulation_substeps(1)
	testing.expect_value(t, stalled.count, rendervk.SIMULATION_MAX_SUBSTEPS)
	testing.expect(t, math.abs(stalled.delta_time * f32(stalled.count) - rendervk.SIMULATION_MAX_FRAME_SECONDS) < 0.00001)
}

@(test)
test_particle_life_large_population_caps_catch_up_work :: proc(t: ^testing.T) {
	large := rendervk.particle_life_simulation_substeps(0.1, 200_000)
	testing.expect_value(t, large.count, 2)
	testing.expect(t, large.delta_time <= f32(1.0 / 120.0) + 0.00001)
	medium := rendervk.particle_life_simulation_substeps(0.1, 50_000)
	testing.expect_value(t, medium.count, 4)
	small := rendervk.particle_life_simulation_substeps(0.1, 15_000)
	testing.expect_value(t, small.count, rendervk.SIMULATION_MAX_SUBSTEPS)
}

@(test)
test_particle_life_far_force_refresh_adapts_to_range :: proc(t: ^testing.T) {
	settings := game.particle_life_default_settings()
	settings.particle_count = 200_000
	settings.max_distance = 0.05
	testing.expect_value(t, game.particle_life_force_refresh_stride(settings), u32(1))
	settings.max_distance = 0.1
	testing.expect_value(t, game.particle_life_force_refresh_stride(settings), u32(2))
	settings.max_distance = 0.2
	testing.expect_value(t, game.particle_life_force_refresh_stride(settings), u32(8))
	settings.force_temporal_coherence = false
	testing.expect_value(t, game.particle_life_force_refresh_stride(settings), u32(1))
	testing.expect_value(t, game.particle_life_force_sample_limit(settings), u32(64))
	settings.force_dense_sampling = false
	testing.expect_value(t, game.particle_life_force_sample_limit(settings), u32(0))
}

@(test)
test_primordial_timestep_is_independent_of_render_rate :: proc(t: ^testing.T) {
	configured := f32(0.016)
	at_60 := rendervk.primordial_effective_step_dt(configured, 1.0 / 60.0)
	at_240 := rendervk.primordial_effective_step_dt(configured, 1.0 / 240.0)
	testing.expect(t, math.abs(at_60 - configured) < 0.00001)
	testing.expect(t, math.abs(at_240 * 4 - at_60) < 0.00001)

	steps := rendervk.simulation_substeps(1.0 / 60.0)
	substep_total := rendervk.primordial_effective_step_dt(configured, steps.delta_time) * f32(steps.count)
	testing.expect(t, math.abs(substep_total - at_60) < 0.00001)
}

@(test)
test_pellets_caps_each_rendered_frame_to_one_stable_step :: proc(t: ^testing.T) {
	slow := rendervk.pellets_simulation_substeps(0.1)
	testing.expect_value(t, slow.count, 1)
	testing.expect(t, math.abs(slow.delta_time - rendervk.SIMULATION_MAX_SUBSTEP_SECONDS) < 0.00001)
	fast := rendervk.pellets_simulation_substeps(1.0 / 240.0)
	testing.expect_value(t, fast.count, 1)
	testing.expect(t, math.abs(fast.delta_time - f32(1.0 / 240.0)) < 0.00001)
	stopped := rendervk.pellets_simulation_substeps(0)
	testing.expect_value(t, stopped.count, 0)
}

@(test)
test_pellets_semi_implicit_euler_updates_velocity_before_position :: proc(t: ^testing.T) {
	position, velocity := rendervk.pellets_semi_implicit_euler({1, 2}, {3, 4}, {2, -2}, 0.5, 0.8)
	testing.expect(t, math.abs(velocity.x - 3.2) < 0.00001)
	testing.expect(t, math.abs(velocity.y - 2.4) < 0.00001)
	testing.expect(t, math.abs(position.x - 2.6) < 0.00001)
	testing.expect(t, math.abs(position.y - 3.2) < 0.00001)
}

@(test)
test_pellets_toroidal_delta_uses_shortest_wrapped_distance :: proc(t: ^testing.T) {
	delta := rendervk.pellets_toroidal_delta({0.95, -0.95}, {-0.95, 0.95})
	testing.expect(t, math.abs(delta.x - 0.1) < 0.00001)
	testing.expect(t, math.abs(delta.y + 0.1) < 0.00001)
}

@(test)
test_pellets_density_contribution_respects_radius_and_zero_neighbor_case :: proc(t: ^testing.T) {
	testing.expect_value(t, rendervk.pellets_density_contribution(1, 0.5), f32(0))
	testing.expect(t, math.abs(rendervk.pellets_density_contribution(0.25, 1) - f32(0.8)) < 0.00001)
	zero := rendervk.pellets_bounded_separation({}, 0, 0, 1, 0.01)
	testing.expect_value(t, zero, [2]f32{})
}

@(test)
test_pellets_separation_is_bounded_by_particle_size :: proc(t: ^testing.T) {
	separation := rendervk.pellets_bounded_separation({3, 4}, 10, 2, 10, 0.01)
	length := math.sqrt(separation.x * separation.x + separation.y * separation.y)
	testing.expect(t, math.abs(length - f32(0.008)) < 0.00001)
}

@(test)
test_pellets_cancelling_overlap_directions_do_not_create_singularity :: proc(t: ^testing.T) {
	separation := rendervk.pellets_bounded_separation({0, 0}, 0.02, 2, 1, 0.01)
	testing.expect_value(t, separation, [2]f32{})
	testing.expect(t, !math.is_nan(separation.x))
	testing.expect(t, !math.is_nan(separation.y))
}

@(test)
test_primordial_zero_seed_uses_nonzero_rng_state :: proc(t: ^testing.T) {
	rng := rendervk.primordial_rng_seed(0)
	first := rendervk.primordial_next_random01(&rng)
	second := rendervk.primordial_next_random01(&rng)
	testing.expect(t, first != second)
	testing.expect(t, rng != 0)
}

@(test)
test_primordial_large_population_caps_catch_up_without_losing_elapsed_time :: proc(t: ^testing.T) {
	steps := rendervk.primordial_simulation_substeps(0.1, 100_000)
	testing.expect_value(t, steps.count, 1)
	testing.expect(t, math.abs(steps.delta_time - f32(0.1)) < 0.00001)
	medium := rendervk.primordial_simulation_substeps(0.1, 50_000)
	testing.expect_value(t, medium.count, 2)
	testing.expect(t, math.abs(medium.delta_time * 2 - f32(0.1)) < 0.00001)
}

test_is_scroll_top_fade :: proc(command: uifw.Draw_Command, viewport: uifw.Rect) -> bool {
	if command.kind != uifw.Draw_Command_Kind.Gradient_Rect {
		return false
	}
	return test_approx_f32(command.rect.x, viewport.x) &&
	       test_approx_f32(command.rect.y, viewport.y) &&
	       test_approx_f32(command.rect.w, viewport.w) &&
	       command.rect.h > 0 &&
	       command.rect.h <= 18.01 &&
	       command.color.r == 0 &&
	       command.color.g == 0 &&
	       command.color.b == 0 &&
	       command.color.a > 0 &&
	       command.color_2.r == 0 &&
	       command.color_2.g == 0 &&
	       command.color_2.b == 0 &&
	       command.color_2.a == 0
}

test_is_scroll_bottom_fade :: proc(command: uifw.Draw_Command, viewport: uifw.Rect) -> bool {
	if command.kind != uifw.Draw_Command_Kind.Gradient_Rect {
		return false
	}
	return test_approx_f32(command.rect.x, viewport.x) &&
	       test_approx_f32(command.rect.y + command.rect.h, viewport.y + viewport.h) &&
	       test_approx_f32(command.rect.w, viewport.w) &&
	       command.rect.h > 0 &&
	       command.rect.h <= 18.01 &&
	       command.color.r == 0 &&
	       command.color.g == 0 &&
	       command.color.b == 0 &&
	       command.color.a == 0 &&
	       command.color_2.r == 0 &&
	       command.color_2.g == 0 &&
	       command.color_2.b == 0 &&
	       command.color_2.a > 0
}

test_count_scroll_fades :: proc(commands: []uifw.Draw_Command, viewport: uifw.Rect) -> (top, bottom: int) {
	for command in commands {
		if test_is_scroll_top_fade(command, viewport) {
			top += 1
		}
		if test_is_scroll_bottom_fade(command, viewport) {
			bottom += 1
		}
	}
	return
}

test_first_text_command_index :: proc(commands: []uifw.Draw_Command, text: string) -> int {
	for command, i in commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == text {
			return i
		}
	}
	return -1
}

test_expect_color_scheme :: proc(t: ^testing.T, color_scheme: ^game.Color_Scheme_Name, reversed: bool, expected_name: string, expected_reversed: bool) {
	testing.expect_value(t, game.color_scheme_name_get(color_scheme), expected_name)
	testing.expect_value(t, reversed, expected_reversed)
}

test_color_byte :: proc(value: f32) -> u8 {
	return u8(uifw.gui_clamp01(value) * 255 + 0.5)
}

test_expect_color_near_rgb8 :: proc(t: ^testing.T, color: uifw.Color, r, g, b: u8, tolerance: int) {
	red_delta := int(test_color_byte(color.r)) - int(r)
	green_delta := int(test_color_byte(color.g)) - int(g)
	blue_delta := int(test_color_byte(color.b)) - int(b)
	if red_delta < 0 {
		red_delta = -red_delta
	}
	if green_delta < 0 {
		green_delta = -green_delta
	}
	if blue_delta < 0 {
		blue_delta = -blue_delta
	}
	testing.expect(t, red_delta <= tolerance)
	testing.expect(t, green_delta <= tolerance)
	testing.expect(t, blue_delta <= tolerance)
}

test_colors_match_rgb8 :: proc(a, b: uifw.Color) -> bool {
	return test_color_byte(a.r) == test_color_byte(b.r) &&
	       test_color_byte(a.g) == test_color_byte(b.g) &&
	       test_color_byte(a.b) == test_color_byte(b.b)
}

test_is_black_horizontal_fade :: proc(command: uifw.Draw_Command, left_alpha, right_alpha: f32) -> bool {
	if command.kind != uifw.Draw_Command_Kind.Horizontal_Gradient_Rect {
		return false
	}
	return command.color.r == 0 &&
	       command.color.g == 0 &&
	       command.color.b == 0 &&
	       test_approx_f32(command.color.a, left_alpha) &&
	       command.color_2.r == 0 &&
	       command.color_2.g == 0 &&
	       command.color_2.b == 0 &&
	       test_approx_f32(command.color_2.a, right_alpha)
}
@(test)
test_memory_budget_prefers_reported_budget :: proc(t: ^testing.T) {
	budget := engine.gpu_memory_budget_from_heaps(
		sizes = []u64{1000},
		usages = []u64{100},
		budgets = []u64{800},
		has_budget = true,
		override_fraction = 0,
	)
	testing.expect_value(t, budget.heaps[0].ceiling, u64(560))
}

@(test)
test_memory_budget_falls_back_to_heap_size :: proc(t: ^testing.T) {
	budget := engine.gpu_memory_budget_from_heaps(
		sizes = []u64{1000},
		usages = []u64{0},
		budgets = nil,
		has_budget = false,
		override_fraction = 0,
	)
	testing.expect_value(t, budget.heaps[0].ceiling, u64(600))
}

@(test)
test_queue_is_bounded :: proc(t: ^testing.T) {
	q: engine.Bounded_Queue(int, 2)
	testing.expect(t, engine.queue_try_push(&q, 1))
	testing.expect(t, engine.queue_try_push(&q, 2))
	testing.expect(t, !engine.queue_try_push(&q, 3))

	value: int
	testing.expect(t, engine.queue_try_pop(&q, &value))
	testing.expect_value(t, value, 1)
	testing.expect(t, engine.queue_try_push(&q, 3))
	testing.expect_value(t, engine.queue_len(&q), 2)
}

@(test)
test_screenshot_state_converts_bgra_to_qoi_on_request :: proc(t: ^testing.T) {
	state: engine.Screenshot_State
	defer engine.screenshot_state_destroy(&state)

	pixels := []u8{10, 20, 30, 255}
	testing.expect(t, engine.screenshot_state_publish_from_gpu_rgba(&state, pixels, 1, 1, vk.Format.B8G8R8A8_SRGB, 7))

	qoi_bytes, width, height, sequence, ok := engine.screenshot_state_copy_qoi(&state)
	defer delete(qoi_bytes)

	testing.expect(t, ok)
	testing.expect_value(t, width, u32(1))
	testing.expect_value(t, height, u32(1))
	testing.expect_value(t, sequence, u64(1))
	testing.expect(t, len(qoi_bytes) >= 26)
	testing.expect_value(t, string(qoi_bytes[:4]), "qoif")
	testing.expect_value(t, qoi_bytes[4], u8(0))
	testing.expect_value(t, qoi_bytes[5], u8(0))
	testing.expect_value(t, qoi_bytes[6], u8(0))
	testing.expect_value(t, qoi_bytes[7], u8(1))
	testing.expect_value(t, qoi_bytes[8], u8(0))
	testing.expect_value(t, qoi_bytes[9], u8(0))
	testing.expect_value(t, qoi_bytes[10], u8(0))
	testing.expect_value(t, qoi_bytes[11], u8(1))
	testing.expect_value(t, qoi_bytes[12], u8(3))
	testing.expect_value(t, qoi_bytes[14], u8(0xfe))
	testing.expect_value(t, qoi_bytes[15], u8(30))
	testing.expect_value(t, qoi_bytes[16], u8(20))
	testing.expect_value(t, qoi_bytes[17], u8(10))
}

@(test)
test_video_recorder_uses_swapchain_pixel_format_names :: proc(t: ^testing.T) {
	testing.expect_value(t, host.video_recorder_pixel_format_name(vk.Format.B8G8R8A8_UNORM), "bgra")
	testing.expect_value(t, host.video_recorder_pixel_format_name(vk.Format.B8G8R8A8_SRGB), "bgra")
	testing.expect_value(t, host.video_recorder_pixel_format_name(vk.Format.R8G8B8A8_UNORM), "rgba")
}

@(test)
test_video_recorder_fps_defaults_and_clamps_to_sixty :: proc(t: ^testing.T) {
	settings := game.settings_default()
	settings.default_fps_limit_enabled = false
	settings.default_fps_limit = 240
	testing.expect_value(t, host.video_recorder_fps_from_settings(settings), u32(60))

	settings.default_fps_limit_enabled = true
	settings.default_fps_limit = 30
	testing.expect_value(t, host.video_recorder_fps_from_settings(settings), u32(30))

	settings.default_fps_limit = 240
	testing.expect_value(t, host.video_recorder_fps_from_settings(settings), u32(60))
}

@(test)
test_video_recorder_resamples_wall_clock_to_fixed_rate_timeline :: proc(t: ^testing.T) {
	testing.expect_value(t, host.video_recorder_desired_frame_count(0, 60), u64(1))
	testing.expect_value(t, host.video_recorder_desired_frame_count(0.5, 60), u64(31))
	testing.expect_value(t, host.video_recorder_desired_frame_count(1.0, 60), u64(61))
	testing.expect_value(t, host.video_recorder_desired_frame_count(1.0, 0), u64(0))
}

@(test)
test_app_ui_video_recording_command_state_transitions :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)
	testing.expect_value(t, ui.video_recording_state, game.Video_Recording_Ui_State.Idle)

	game.app_ui_video_recording_apply_command_state(&ui, .Restoring_Fullscreen, "Restoring fullscreen before recording")
	testing.expect_value(t, ui.video_recording_state, game.Video_Recording_Ui_State.Restoring_Fullscreen)
	testing.expect_value(t, game.fixed_string(ui.video_recording_status[:]), "Restoring fullscreen before recording")

	game.app_ui_video_recording_apply_command_state(&ui, .Recording, "/tmp/test.mp4")
	testing.expect_value(t, ui.video_recording_state, game.Video_Recording_Ui_State.Recording)
	testing.expect_value(t, game.app_ui_video_recording_button_label(&ui), "Stop Recording")

	game.app_ui_video_recording_apply_command_state(&ui, .Failed, "ffmpeg was not found on PATH")
	testing.expect_value(t, ui.video_recording_state, game.Video_Recording_Ui_State.Failed)
	testing.expect_value(t, game.app_ui_video_recording_button_label(&ui), "Record")
}

@(test)
test_screenshot_state_can_return_smaller_qoi :: proc(t: ^testing.T) {
	state: engine.Screenshot_State
	defer engine.screenshot_state_destroy(&state)

	pixels := []u8{
		255, 0, 0, 255, 0, 255, 0, 255,
		0, 0, 255, 255, 255, 255, 255, 255,
	}
	testing.expect(t, engine.screenshot_state_publish_from_gpu_rgba(&state, pixels, 2, 2, vk.Format.R8G8B8A8_UNORM, 7))

	qoi_bytes, width, height, sequence, ok := engine.screenshot_state_copy_qoi_sized(&state, 1, 1, 1)
	defer delete(qoi_bytes)

	testing.expect(t, ok)
	testing.expect_value(t, width, u32(1))
	testing.expect_value(t, height, u32(1))
	testing.expect_value(t, sequence, u64(1))
	testing.expect_value(t, string(qoi_bytes[:4]), "qoif")
	testing.expect_value(t, qoi_bytes[7], u8(1))
	testing.expect_value(t, qoi_bytes[11], u8(1))
	testing.expect_value(t, qoi_bytes[12], u8(3))
}

@(test)
test_screenshot_state_can_return_resized_png :: proc(t: ^testing.T) {
	state: engine.Screenshot_State
	defer engine.screenshot_state_destroy(&state)

	pixels := []u8{
		255, 0, 0, 255, 0, 255, 0, 255,
		0, 0, 255, 255, 255, 255, 255, 255,
	}
	testing.expect(t, engine.screenshot_state_publish_from_gpu_rgba(&state, pixels, 2, 2, vk.Format.R8G8B8A8_UNORM, 7))

	png_bytes, width, height, sequence, ok := engine.screenshot_state_copy_png_sized(&state, 1, 1, 1)
	defer delete(png_bytes)

	testing.expect(t, ok)
	testing.expect_value(t, width, u32(1))
	testing.expect_value(t, height, u32(1))
	testing.expect_value(t, sequence, u64(1))
	testing.expect(t, len(png_bytes) >= 24)
	png_signature := [8]u8{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'}
	for value, index in png_signature {
		testing.expect_value(t, png_bytes[index], value)
	}
	testing.expect_value(t, png_bytes[16], u8(0))
	testing.expect_value(t, png_bytes[17], u8(0))
	testing.expect_value(t, png_bytes[18], u8(0))
	testing.expect_value(t, png_bytes[19], u8(1))
	testing.expect_value(t, png_bytes[20], u8(0))
	testing.expect_value(t, png_bytes[21], u8(0))
	testing.expect_value(t, png_bytes[22], u8(0))
	testing.expect_value(t, png_bytes[23], u8(1))
}

@(test)
test_screenshot_state_throttles_background_capture_but_honors_requests :: proc(t: ^testing.T) {
	state: engine.Screenshot_State
	defer engine.screenshot_state_destroy(&state)

	pixels := []u8{1, 2, 3, 255}
	testing.expect(t, engine.screenshot_state_should_capture(&state, 1, 15))
	testing.expect(t, engine.screenshot_state_publish_from_gpu_rgba(&state, pixels, 1, 1, vk.Format.R8G8B8A8_UNORM, 1))
	testing.expect(t, !engine.screenshot_state_should_capture(&state, 2, 15))

	engine.screenshot_state_request_capture(&state)
	testing.expect(t, engine.screenshot_state_should_capture(&state, 3, 15))
	testing.expect(t, engine.screenshot_state_publish_from_gpu_rgba(&state, pixels, 1, 1, vk.Format.R8G8B8A8_UNORM, 3))
	testing.expect(t, !engine.screenshot_state_should_capture(&state, 4, 15))
	testing.expect(t, engine.screenshot_state_should_capture(&state, 18, 15))
}

@(test)
test_gray_scott_settings_round_trip :: proc(t: ^testing.T) {
	sim: game.Gray_Scott_Simulation
	storage: Test_Gray_Scott_Product_Storage
	test_gray_scott_init(&sim, &storage, 640, 480)
	sim.settings.feed = 0.04
	saved := game.gray_scott_save_settings(&sim)

	other: game.Gray_Scott_Simulation
	other_storage: Test_Gray_Scott_Product_Storage
	test_gray_scott_init(&other, &other_storage, 320, 240)
	game.gray_scott_load_settings(&other, saved)
	testing.expect_value(t, other.settings.feed, f32(0.04))
}

@(test)
test_gray_scott_noise_seed_preserves_product_runtime :: proc(t: ^testing.T) {
	sim: game.Gray_Scott_Simulation
	storage: Test_Gray_Scott_Product_Storage
	gpu: rendervk.Gray_Scott_Gpu_State
	sim.render_runtime = &gpu
	test_gray_scott_init(&sim, &storage, 640, 480)
	gpu.ready = true
	seed_before := sim.runtime.seed

	game.gray_scott_seed_noise(&sim)

	testing.expect(t, sim.runtime.seed != seed_before)
	testing.expect_value(t, sim.runtime.pending_seed_mode, game.GRAY_SCOTT_MODE_NOISE_SEED)
	testing.expect(t, gpu.ready)
}

@(test)
test_gray_scott_builtin_preset_preserves_live_field :: proc(t: ^testing.T) {
	sim: game.Gray_Scott_Simulation
	storage: Test_Gray_Scott_Product_Storage
	gpu: rendervk.Gray_Scott_Gpu_State
	sim.render_runtime = &gpu
	test_gray_scott_init(&sim, &storage, 640, 480)
	sim.runtime.pending_seed_mode = 0
	gpu.ready = true
	seed_before := sim.runtime.seed

	game.gray_scott_apply_builtin_preset(&sim, 2)

	testing.expect_value(t, sim.runtime.seed, seed_before)
	testing.expect_value(t, sim.runtime.pending_seed_mode, u32(0))
	testing.expect(t, gpu.ready)
}

@(test)
test_gray_scott_toml_round_trip_through_tomlc17 :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_gray_scott_roundtrip.toml"
	settings := game.gray_scott_default_settings()
	settings.feed = 0.031
	settings.kill = 0.067
	settings.diffusion_b = 0.42
	settings.simulation_speed = 4.0
	settings.paused = true
	settings.mask_pattern = .Nutrient_Map
	settings.nutrient_image_fit_mode = .Fit_V
	settings.seed_noise.kind = .Voronoi
	settings.seed_noise.warp_mode = .Recursive
	settings.seed_noise.warp_amplitude = 1.75
	settings.seed_density = 0.61
	game.write_fixed_string(settings.nutrient_image_path[:], "config/custom_nutrient.png")

	testing.expect(t, game.settings_save_gray_scott(path, settings))
	loaded, ok := game.settings_load_gray_scott(path, game.gray_scott_default_settings())
	testing.expect(t, ok)
	testing.expect_value(t, loaded.feed, settings.feed)
	testing.expect_value(t, loaded.kill, settings.kill)
	testing.expect_value(t, loaded.diffusion_b, settings.diffusion_b)
	testing.expect_value(t, loaded.simulation_speed, settings.simulation_speed)
	testing.expect_value(t, loaded.paused, settings.paused)
	testing.expect_value(t, loaded.mask_pattern, settings.mask_pattern)
	testing.expect_value(t, loaded.nutrient_image_fit_mode, settings.nutrient_image_fit_mode)
	testing.expect_value(t, game.fixed_string(loaded.nutrient_image_path[:]), "config/custom_nutrient.png")
	testing.expect_value(t, loaded.seed_noise.kind, game.Noise_Kind.Voronoi)
	testing.expect_value(t, loaded.seed_noise.warp_mode, game.Noise_Warp_Mode.Recursive)
	testing.expect_value(t, loaded.seed_noise.warp_amplitude, f32(1.75))
	testing.expect_value(t, loaded.seed_density, f32(0.61))
}

@(test)
test_particle_life_toml_round_trip_through_tomlc17 :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_particle_life_roundtrip.toml"
	settings := game.particle_life_default_settings()
	settings.particle_count = 2222
	settings.species_count = 4
	settings.position_generator = 10
	settings.type_generator = 8
	settings.force_generator = 18
	settings.camera_x = 1.25
	settings.camera_y = -0.5
	settings.camera_zoom = 3.5
	settings.color_mode = .White
	settings.background_color_mode = .White
	settings.background_index = int(game.Vector_Background_Mode.White)
	game.color_scheme_name_set(&settings.color_scheme, "MATPLOTLIB_viridis")
	settings.color_scheme_reversed = true
	settings.background_color = {0.12, 0.23, 0.34, 1}
	settings.brightness = 1.4
	settings.contrast = 0.7
	settings.saturation = 1.6
	settings.gamma = 1.8
	settings.trails_enabled = false
	settings.trail_fade_amount = 0.042
	settings.infinite_tiles_enabled = false
	settings.infinite_tile_radius = 7
	settings.analysis_enabled = true
	settings.analysis_interval_frames = 6
	settings.analysis_grid_size = 512
	settings.coherence_threshold = 0.66
	settings.min_blob_area_cells = 20
	settings.blob_overlay_enabled = true
	settings.force_dense_sampling = false
	settings.custom_force_matrix = true
	settings.force_matrix[2 * game.PARTICLE_LIFE_MAX_SPECIES + 3] = -0.625

	testing.expect(t, game.settings_save_particle_life(path, settings))
	loaded, ok := game.settings_load_particle_life(path, game.particle_life_default_settings())
	testing.expect(t, ok)
	testing.expect_value(t, loaded.particle_count, settings.particle_count)
	testing.expect_value(t, loaded.species_count, settings.species_count)
	testing.expect_value(t, loaded.position_generator, settings.position_generator)
	testing.expect_value(t, loaded.type_generator, settings.type_generator)
	testing.expect_value(t, loaded.force_generator, settings.force_generator)
	testing.expect_value(t, loaded.camera_x, settings.camera_x)
	testing.expect_value(t, loaded.camera_y, settings.camera_y)
	testing.expect_value(t, loaded.camera_zoom, settings.camera_zoom)
	testing.expect_value(t, loaded.color_mode, settings.color_mode)
	testing.expect_value(t, loaded.background_color_mode, settings.background_color_mode)
	testing.expect_value(t, loaded.background_index, int(game.Vector_Background_Mode.White))
	testing.expect_value(t, game.color_scheme_name_get(&loaded.color_scheme), "MATPLOTLIB_viridis")
	testing.expect_value(t, loaded.color_scheme_reversed, settings.color_scheme_reversed)
	testing.expect_value(t, loaded.background_color[0], settings.background_color[0])
	testing.expect_value(t, loaded.background_color[1], settings.background_color[1])
	testing.expect_value(t, loaded.background_color[2], settings.background_color[2])
	testing.expect_value(t, loaded.brightness, settings.brightness)
	testing.expect_value(t, loaded.contrast, settings.contrast)
	testing.expect_value(t, loaded.saturation, settings.saturation)
	testing.expect_value(t, loaded.gamma, settings.gamma)
	testing.expect_value(t, loaded.trails_enabled, settings.trails_enabled)
	testing.expect_value(t, loaded.trail_fade_amount, settings.trail_fade_amount)
	testing.expect_value(t, loaded.infinite_tiles_enabled, settings.infinite_tiles_enabled)
	testing.expect_value(t, loaded.infinite_tile_radius, settings.infinite_tile_radius)
	testing.expect_value(t, loaded.analysis_enabled, settings.analysis_enabled)
	testing.expect_value(t, loaded.analysis_interval_frames, settings.analysis_interval_frames)
	testing.expect_value(t, loaded.analysis_grid_size, settings.analysis_grid_size)
	testing.expect_value(t, loaded.coherence_threshold, settings.coherence_threshold)
	testing.expect_value(t, loaded.min_blob_area_cells, settings.min_blob_area_cells)
	testing.expect_value(t, loaded.blob_overlay_enabled, settings.blob_overlay_enabled)
	testing.expect_value(t, loaded.force_dense_sampling, false)
	testing.expect_value(t, loaded.custom_force_matrix, true)
	testing.expect_value(t, loaded.force_matrix[2 * game.PARTICLE_LIFE_MAX_SPECIES + 3], f32(-0.625))
}

@(test)
test_particle_life_saved_preset_keeps_current_color_scheme :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_particle_life_preserve_color_preset.toml"
	preset := game.particle_life_default_settings()
	preset.particle_count = 3333
	game.color_scheme_name_set(&preset.color_scheme, "MATPLOTLIB_viridis")
	preset.color_scheme_reversed = true
	testing.expect(t, game.settings_save_particle_life(path, preset))

	current := game.particle_life_default_settings()
	game.color_scheme_name_set(&current.color_scheme, "ZELDA_Aqua")
	current.color_scheme_reversed = false
	loaded, ok := game.settings_load_particle_life_preset(path, current)

	testing.expect(t, ok)
	testing.expect_value(t, loaded.particle_count, u32(3333))
	test_expect_color_scheme(t, &loaded.color_scheme, loaded.color_scheme_reversed, "ZELDA_Aqua", false)
}

@(test)
test_particle_life_builtin_preset_keeps_current_color_scheme :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	gpu: rendervk.Particle_Life_Gpu_State
	sim.render_runtime = &gpu
	storage: Test_Particle_Life_Product_Storage
	test_particle_life_init(&sim, &storage, 320, 240)
	game.color_scheme_name_set(&sim.settings.color_scheme, "ZELDA_Aqua")
	sim.settings.color_scheme_reversed = true

	game.particle_life_apply_builtin_preset(&sim, 0)

	test_expect_color_scheme(t, &sim.settings.color_scheme, sim.settings.color_scheme_reversed, "ZELDA_Aqua", true)
}

@(test)
test_particle_life_force_randomize_does_not_regenerate_particles :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	storage: Test_Particle_Life_Product_Storage
	test_particle_life_init(&sim, &storage, 320, 240)
	sim.runtime.needs_reset = false

	game.particle_life_randomize_forces(&sim)

	testing.expect(t, !sim.runtime.needs_reset)
	testing.expect(t, sim.runtime.pending_force_randomize)
}

@(test)
test_particle_life_particle_regenerate_preserves_forces :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	storage: Test_Particle_Life_Product_Storage
	test_particle_life_init(&sim, &storage, 320, 240)
	game.particle_life_randomize_forces(&sim)
	force_before := sim.runtime.force_matrix

	game.particle_life_reset_runtime(&sim)

	testing.expect(t, sim.runtime.needs_reset)
	testing.expect_value(t, sim.runtime.force_matrix[0], force_before[0])
	testing.expect_value(t, sim.runtime.force_matrix[1], force_before[1])
	testing.expect_value(t, sim.runtime.force_matrix[2 * game.PARTICLE_LIFE_MAX_SPECIES + 3], force_before[2 * game.PARTICLE_LIFE_MAX_SPECIES + 3])
}

@(test)
test_particle_life_resource_rebuild_does_not_regenerate_particles :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	gpu: rendervk.Particle_Life_Gpu_State
	sim.render_runtime = &gpu
	storage: Test_Particle_Life_Product_Storage
	test_particle_life_init(&sim, &storage, 320, 240)
	sim.runtime.needs_reset = false

	game.particle_life_request_resource_rebuild(&sim)

	testing.expect(t, !sim.runtime.needs_reset)
	testing.expect(t, sim.runtime.render_rebuild_requested)
	testing.expect(t, sim.runtime.preserve_particles_requested)
}

particle_life_test_blob_summary :: proc(x, y, vx, vy: f32, area: u32, species: u32) -> game.Particle_Life_Blob_Summary {
	summary: game.Particle_Life_Blob_Summary
	summary.area = area
	summary.centroid = {x, y}
	summary.velocity = {vx, vy}
	summary.density = 1
	summary.coherence_score = 1
	if species < game.PARTICLE_LIFE_MAX_SPECIES {
		summary.species_histogram[species] = area
	}
	return summary
}

@(test)
test_particle_life_blob_tracker_keeps_id_across_motion :: proc(t: ^testing.T) {
	tracker: game.Particle_Life_Blob_Tracker
	game.particle_life_blob_tracker_reset(&tracker)
	first := [?]game.Particle_Life_Blob_Summary{particle_life_test_blob_summary(0, 0, 0.02, 0, 24, 1)}
	game.particle_life_blob_tracker_update(&tracker, first[:])
	id := tracker.blobs[0].id

	next := [?]game.Particle_Life_Blob_Summary{particle_life_test_blob_summary(0.025, 0, 0.02, 0, 25, 1)}
	game.particle_life_blob_tracker_update(&tracker, next[:])

	testing.expect_value(t, tracker.count, u32(1))
	testing.expect_value(t, tracker.blobs[0].id, id)
	testing.expect(t, tracker.blobs[0].confidence > 0.45)
}

@(test)
test_particle_life_blob_tracker_ages_lost_blobs :: proc(t: ^testing.T) {
	tracker: game.Particle_Life_Blob_Tracker
	game.particle_life_blob_tracker_reset(&tracker)
	first := [?]game.Particle_Life_Blob_Summary{particle_life_test_blob_summary(0, 0, 0, 0, 24, 1)}
	game.particle_life_blob_tracker_update(&tracker, first[:])
	empty: [0]game.Particle_Life_Blob_Summary

	for _ in 0 ..< 10 {
		game.particle_life_blob_tracker_update(&tracker, empty[:])
	}
	testing.expect_value(t, tracker.count, u32(1))
	game.particle_life_blob_tracker_update(&tracker, empty[:])
	testing.expect_value(t, tracker.count, u32(0))
}

@(test)
test_particle_life_blob_tracker_distinguishes_distant_split :: proc(t: ^testing.T) {
	tracker: game.Particle_Life_Blob_Tracker
	game.particle_life_blob_tracker_reset(&tracker)
	first := [?]game.Particle_Life_Blob_Summary{particle_life_test_blob_summary(0, 0, 0, 0, 40, 2)}
	game.particle_life_blob_tracker_update(&tracker, first[:])

	split := [?]game.Particle_Life_Blob_Summary{
		particle_life_test_blob_summary(0.01, 0, 0, 0, 22, 2),
		particle_life_test_blob_summary(0.8, 0, 0, 0, 20, 2),
	}
	game.particle_life_blob_tracker_update(&tracker, split[:])

	testing.expect_value(t, tracker.count, u32(2))
}

@(test)
test_particle_life_blob_tracker_uses_species_histogram_tie_break :: proc(t: ^testing.T) {
	tracker: game.Particle_Life_Blob_Tracker
	game.particle_life_blob_tracker_reset(&tracker)
	first := [?]game.Particle_Life_Blob_Summary{
		particle_life_test_blob_summary(-0.1, 0, 0, 0, 20, 0),
		particle_life_test_blob_summary(0.1, 0, 0, 0, 20, 1),
	}
	game.particle_life_blob_tracker_update(&tracker, first[:])
	id_species_one := tracker.blobs[1].id

	next := [?]game.Particle_Life_Blob_Summary{particle_life_test_blob_summary(0.12, 0, 0, 0, 20, 1)}
	game.particle_life_blob_tracker_update(&tracker, next[:])

	found := false
	for i in 0 ..< int(tracker.count) {
		if tracker.blobs[i].id == id_species_one && tracker.blobs[i].missed_frames == 0 {
			found = true
		}
	}
	testing.expect(t, found)
}

@(test)
test_particle_life_analysis_segments_grid_blobs :: proc(t: ^testing.T) {
	workspace: game.Particle_Life_Analysis_Workspace
	defer game.particle_life_analysis_workspace_destroy(&workspace)

	particles := [?]game.Particle_Life_Particle{
		{position = {-0.08, -0.08}, velocity = {0.03, 0.01}, species = 1},
		{position = {-0.07, -0.08}, velocity = {0.03, 0.01}, species = 1},
		{position = {-0.08, -0.07}, velocity = {0.03, 0.01}, species = 1},
		{position = {-0.07, -0.07}, velocity = {0.03, 0.01}, species = 1},
		{position = {-0.06, -0.07}, velocity = {0.03, 0.01}, species = 1},
		{position = {0.58, 0.58}, velocity = {-0.02, 0.00}, species = 2},
		{position = {0.59, 0.58}, velocity = {-0.02, 0.00}, species = 2},
		{position = {0.58, 0.59}, velocity = {-0.02, 0.00}, species = 2},
		{position = {0.59, 0.59}, velocity = {-0.02, 0.00}, species = 2},
	}

	summaries := game.particle_life_analyze_particles(&workspace, particles[:], 4, 16, 1, 0.35, {2, 2})

	testing.expect_value(t, len(summaries), 2)
	if len(summaries) < 2 {
		return
	}
	testing.expect(t, summaries[0].area >= 1)
	testing.expect(t, summaries[0].density >= 4)
	testing.expect(t, summaries[0].coherence_score > 0.35)
	testing.expect(t, summaries[0].species_histogram[1] >= 4 || summaries[1].species_histogram[1] >= 4)
	testing.expect(t, summaries[0].species_histogram[2] >= 4 || summaries[1].species_histogram[2] >= 4)
}

@(test)
test_particle_life_analysis_gpu_struct_layouts_are_stable :: proc(t: ^testing.T) {
	testing.expect_value(t, size_of(game.Particle_Life_Analysis_Gpu_Cell), 48)
	testing.expect_value(t, align_of(game.Particle_Life_Analysis_Gpu_Cell), 16)
	testing.expect_value(t, size_of(game.Particle_Life_Blob_Accumulator), 80)
	testing.expect_value(t, align_of(game.Particle_Life_Blob_Accumulator), 16)
}

@(test)
test_particle_life_analysis_grid_helpers_clamp_and_tile :: proc(t: ^testing.T) {
	settings := game.particle_life_default_settings()
	settings.analysis_grid_size = 8
	testing.expect_value(t, game.particle_life_target_analysis_grid_axis(settings), u32(64))
	settings.analysis_grid_size = 2048
	testing.expect_value(t, game.particle_life_target_analysis_grid_axis(settings), u32(1024))
	settings.analysis_grid_size = 512
	testing.expect_value(t, game.particle_life_target_analysis_grid_axis(settings), u32(512))
	testing.expect_value(t, game.particle_life_analysis_tile_count_for_axis(512), u32(32))
	testing.expect_value(t, game.particle_life_analysis_tile_count_for_axis(513), u32(33))
}

@(test)
test_particle_life_collision_distance_follows_particle_size :: proc(t: ^testing.T) {
	settings := game.particle_life_default_settings()
	settings.collision_enabled = true
	settings.max_distance = 1.0
	settings.particle_size = 4
	settings.collision_distance = 0.04
	testing.expect_value(t, game.particle_life_collision_distance(settings), f32(0.008))
	testing.expect_value(t, game.particle_life_target_grid_cell_size(settings), f32(0.25))

	settings.particle_size = 12
	testing.expect_value(t, game.particle_life_collision_distance(settings), f32(0.024))
	testing.expect_value(t, game.particle_life_target_grid_cell_size(settings), f32(0.25))
}

@(test)
test_particle_life_grid_uses_larger_interaction_radius :: proc(t: ^testing.T) {
	settings := game.particle_life_default_settings()
	settings.collision_enabled = true
	settings.max_distance = 0.4
	settings.particle_size = 4
	width, height := game.particle_life_target_grid_dimensions(settings, {2, 2})
	radius := game.particle_life_target_neighbor_radius_cells(settings, width, height, {2, 2})
	testing.expect_value(t, width, u32(20))
	testing.expect_value(t, height, u32(20))
	testing.expect_value(t, radius, u32(4))
}

@(test)
test_particle_life_collision_grid_uses_particle_diameter :: proc(t: ^testing.T) {
	settings := game.particle_life_default_settings()
	settings.max_distance = 0.4
	settings.particle_size = 20
	width, height := game.particle_life_target_collision_grid_dimensions(settings, {2, 2})
	testing.expect_value(t, width, u32(50))
	testing.expect_value(t, height, u32(50))
}

@(test)
test_particle_life_contiguous_bins_preserve_exact_membership :: proc(t: ^testing.T) {
	cell_indices := [?]u32{2, 0, 2, 1, 0, 2}
	counts := [?]u32{2, 1, 3}
	offsets: [3]u32
	cursors: [3]u32
	indices: [6]u32
	total := game.particle_life_grid_exclusive_offsets(counts[:], offsets[:])
	testing.expect_value(t, total, u32(6))
	testing.expect_value(t, offsets, [3]u32{0, 2, 3})
	testing.expect(t, game.particle_life_grid_scatter_indices(cell_indices[:], offsets[:], cursors[:], indices[:]))
	for cell in 0 ..< len(counts) {
		seen: [6]bool
		for slot: u32 = offsets[cell]; slot < offsets[cell] + counts[cell]; slot += 1 {
			particle := indices[slot]
			testing.expect_value(t, cell_indices[particle], u32(cell))
			seen[particle] = true
		}
		for source_cell, particle in cell_indices {
			if source_cell == u32(cell) {
				testing.expect(t, seen[particle])
			}
		}
	}
}

@(test)
test_particle_life_collision_toggle_reuses_interaction_grid :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	gpu: rendervk.Particle_Life_Gpu_State
	sim.render_runtime = &gpu
	storage: Test_Particle_Life_Product_Storage
	test_particle_life_init(&sim, &storage, 320, 240)
	world_size := game.particle_life_world_size(&sim)

	sim.settings.collision_enabled = true
	fine_width, fine_height := game.particle_life_target_grid_dimensions(sim.settings^, world_size)
	fine_radius := game.particle_life_target_neighbor_radius_cells(sim.settings^, fine_width, fine_height, world_size)
	sim.runtime.grid_width = fine_width
	sim.runtime.grid_height = fine_height
	sim.runtime.neighbor_radius_cells = fine_radius
	sim.runtime.collision_grid_width, sim.runtime.collision_grid_height = game.particle_life_target_collision_grid_dimensions(sim.settings^, world_size)
	testing.expect(t, game.particle_life_current_grid_satisfies_settings(&sim))

	sim.settings.collision_enabled = false
	testing.expect(t, game.particle_life_current_grid_satisfies_settings(&sim))

	interaction_width, interaction_height := game.particle_life_target_grid_dimensions(sim.settings^, world_size)
	interaction_radius := game.particle_life_target_neighbor_radius_cells(sim.settings^, interaction_width, interaction_height, world_size)
	sim.runtime.grid_width = interaction_width
	sim.runtime.grid_height = interaction_height
	sim.runtime.neighbor_radius_cells = interaction_radius
	sim.runtime.collision_grid_width, sim.runtime.collision_grid_height = game.particle_life_target_collision_grid_dimensions(sim.settings^, world_size)
	sim.settings.collision_enabled = true
	testing.expect(t, game.particle_life_current_grid_satisfies_settings(&sim))
}

@(test)
test_particle_life_range_change_rejects_stale_grid :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	gpu: rendervk.Particle_Life_Gpu_State
	sim.render_runtime = &gpu
	storage: Test_Particle_Life_Product_Storage
	test_particle_life_init(&sim, &storage, 320, 240)
	world_size := game.particle_life_world_size(&sim)

	sim.settings.collision_enabled = false
	sim.settings.max_distance = 0.8
	wide_width, wide_height := game.particle_life_target_grid_dimensions(sim.settings^, world_size)
	wide_radius := game.particle_life_target_neighbor_radius_cells(sim.settings^, wide_width, wide_height, world_size)
	sim.runtime.grid_width = wide_width
	sim.runtime.grid_height = wide_height
	sim.runtime.neighbor_radius_cells = wide_radius
	testing.expect(t, game.particle_life_current_grid_satisfies_settings(&sim))

	sim.settings.max_distance = 0.02
	testing.expect(t, !game.particle_life_current_grid_satisfies_settings(&sim))
}

@(test)
test_particle_life_screen_to_world_keeps_mouse_y_upright :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	storage: Test_Particle_Life_Product_Storage
	test_particle_life_init(&sim, &storage, 200, 100)

	top := game.particle_life_screen_to_world(&sim, {100, 0}, 200, 100)
	bottom := game.particle_life_screen_to_world(&sim, {100, 100}, 200, 100)
	left := game.particle_life_screen_to_world(&sim, {0, 50}, 200, 100)
	right := game.particle_life_screen_to_world(&sim, {200, 50}, 200, 100)

	testing.expect_value(t, top[0], f32(0))
	testing.expect_value(t, top[1], f32(1))
	testing.expect_value(t, bottom[0], f32(0))
	testing.expect_value(t, bottom[1], f32(-1))
	testing.expect_value(t, left[0], f32(-2))
	testing.expect_value(t, left[1], f32(0))
	testing.expect_value(t, right[0], f32(2))
	testing.expect_value(t, right[1], f32(0))
}

@(test)
test_particle_life_random_spawn_scales_to_viewport_world :: proc(t: ^testing.T) {
	wide_world := game.particle_life_world_size_for_viewport(200, 100)
	wide_position, wide_normalized := game.particle_life_generate_position_for_world(0, 4, 0, 42, wide_world)
	testing.expect_value(t, wide_world[0], f32(4))
	testing.expect_value(t, wide_world[1], f32(2))
	testing.expect_value(t, wide_position[0], wide_normalized[0] * 2.0)
	testing.expect_value(t, wide_position[1], wide_normalized[1])

	tall_world := game.particle_life_world_size_for_viewport(100, 200)
	tall_position, tall_normalized := game.particle_life_generate_position_for_world(0, 4, 0, 42, tall_world)
	testing.expect_value(t, tall_world[0], f32(1))
	testing.expect_value(t, tall_world[1], f32(2))
	testing.expect_value(t, tall_position[0], tall_normalized[0] * 0.5)
	testing.expect_value(t, tall_position[1], tall_normalized[1])
}

@(test)
test_gray_scott_screen_to_texture_matches_rendered_y :: proc(t: ^testing.T) {
	sim: game.Gray_Scott_Simulation
	storage: Test_Gray_Scott_Product_Storage
	test_gray_scott_init(&sim, &storage, 200, 100)

	top_x, top_y := game.gray_scott_screen_to_texture(&sim, {100, 0}, 200, 100)
	bottom_x, bottom_y := game.gray_scott_screen_to_texture(&sim, {100, 100}, 200, 100)

	testing.expect_value(t, top_x, f32(0.5))
	testing.expect_value(t, top_y, f32(1))
	testing.expect_value(t, bottom_x, f32(0.5))
	testing.expect_value(t, bottom_y, f32(0))
}

@(test)
test_particle_life_infinite_tile_range_clamps_to_camera_radius :: proc(t: ^testing.T) {
	bounds := [4]f32{-2.5, -1.0, 2.5, 1.0}
	tile_range := game.particle_life_tile_range_for_bounds(bounds, 0, 0, 1, {2, 2})
	testing.expect_value(t, tile_range.min_x, i32(-1))
	testing.expect_value(t, tile_range.max_x, i32(1))
	testing.expect_value(t, tile_range.min_y, i32(-1))
	testing.expect_value(t, tile_range.max_y, i32(1))
}

@(test)
test_particle_life_tile_bounds_shift_view_instead_of_particle_positions :: proc(t: ^testing.T) {
	bounds := [4]f32{-2.5, -1.0, 2.5, 1.0}
	shifted := game.particle_life_tile_bounds_for_offset(bounds, 2, -1, {2, 2})
	testing.expect_value(t, shifted[0], f32(-6.5))
	testing.expect_value(t, shifted[1], f32(1.0))
	testing.expect_value(t, shifted[2], f32(-1.5))
	testing.expect_value(t, shifted[3], f32(3.0))
}

@(test)
test_particle_life_trails_reset_when_camera_changes :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	gpu: rendervk.Particle_Life_Gpu_State
	sim.render_runtime = &gpu
	storage: Test_Particle_Life_Product_Storage
	test_particle_life_init(&sim, &storage, 1280, 720)

	game.particle_life_note_trail_camera(&sim)
	testing.expect(t, !sim.runtime.trail_reset_requested)

	sim.runtime.camera_zoom = 2
	game.particle_life_note_trail_camera(&sim)
	testing.expect(t, sim.runtime.trail_reset_requested)
	testing.expect_value(t, sim.runtime.trail_camera_zoom, f32(2))

	sim.runtime.trail_reset_requested = false
	game.particle_life_note_trail_camera(&sim)
	testing.expect(t, !sim.runtime.trail_reset_requested)
}

@(test)
test_camera_controls_zoom_to_cursor_keeps_world_point_stationary :: proc(t: ^testing.T) {
	camera: game.Camera_Control_State
	game.camera_controls_init(&camera)
	mouse := uifw.Vec2{960, 540}
	before := game.camera_controls_screen_to_world(&camera, mouse, 1920, 1080)

	game.camera_controls_zoom_to_cursor(&camera, game.CAMERA_WHEEL_DELTA_SCALE, 1, mouse, 1920, 1080)
	after := game.camera_controls_screen_to_world(&camera, mouse, 1920, 1080)

	testing.expect(t, math.abs(before[0] - after[0]) < 0.00001)
	testing.expect(t, math.abs(before[1] - after[1]) < 0.00001)
	testing.expect(t, camera.target_zoom > 1)
}

@(test)
test_camera_controls_middle_mouse_drag_pans_screen_space :: proc(t: ^testing.T) {
	camera: game.Camera_Control_State
	game.camera_controls_init(&camera)

	game.camera_controls_apply_input(&camera, {
		window_width = 100,
		window_height = 100,
		camera_pan_down = true,
		mouse_delta = {10, 20},
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 1,
	})

	testing.expect(t, camera.target_position[0] < 0)
	testing.expect(t, camera.target_position[1] > 0)
	testing.expect(t, camera.position[0] < 0)
	testing.expect(t, camera.position[1] > 0)
}

@(test)
test_camera_controls_trackpad_zoom_clamps_bursts_and_uses_visible_camera :: proc(t: ^testing.T) {
	camera: game.Camera_Control_State
	game.camera_controls_init(&camera)
	camera.position = {0.25, -0.1}
	camera.target_position = {2, 1}
	camera.zoom = 1.25
	camera.target_zoom = 3
	mouse := uifw.Vec2{150, 25}
	before := game.camera_controls_screen_to_world(&camera, mouse, 200, 100)

	game.camera_controls_apply_input(&camera, {
		window_width = 200,
		window_height = 100,
		mouse_pos = mouse,
		wheel_delta = 100,
		delta_time = 0,
		camera_sensitivity = 1,
	})
	after := game.camera_controls_screen_to_world(&camera, mouse, 200, 100)

	testing.expect(t, math.abs(before[0] - after[0]) < 0.00001)
	testing.expect(t, math.abs(before[1] - after[1]) < 0.00001)
	testing.expect(t, camera.zoom < f32(1.5))
}

@(test)
test_camera_controls_shift_trackpad_scroll_pans_without_zooming :: proc(t: ^testing.T) {
	camera: game.Camera_Control_State
	game.camera_controls_init(&camera)
	game.camera_controls_apply_input(&camera, {
		wheel_delta = 1.5,
		key_shift = true,
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 1,
	})
	testing.expect(t, camera.target_position[0] > 0)
	testing.expect_value(t, camera.target_zoom, f32(1))
}

@(test)
test_particle_life_camera_uses_shared_wasd_qe_reset_controls :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	storage: Test_Particle_Life_Product_Storage
	test_particle_life_init(&sim, &storage, 1280, 720)

	game.particle_life_apply_frame_input(&sim, {key_w = true, key_d = true, key_e = true, delta_time = 1.0 / 60.0, camera_sensitivity = 2})
	testing.expect(t, sim.runtime.camera_target_x > 0)
	testing.expect(t, sim.runtime.camera_target_y < 0)
	testing.expect(t, sim.runtime.camera_target_zoom > 1)
	testing.expect(t, sim.runtime.camera_x > 0)
	testing.expect(t, sim.runtime.camera_y < 0)

	game.particle_life_apply_frame_input(&sim, {actions = {camera_reset = {pressed = true, owner = .Mouse_Keyboard}}, delta_time = 1.0 / 60.0, camera_sensitivity = 1})
	testing.expect_value(t, sim.runtime.camera_target_x, f32(0))
	testing.expect_value(t, sim.runtime.camera_target_y, f32(0))
	testing.expect_value(t, sim.runtime.camera_target_zoom, f32(1))
}

@(test)
test_slime_mold_camera_uses_shared_unfocused_controls :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	sim_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&sim, &sim_storage)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Slime_Mold, {
		key_w = true,
		key_d = true,
		key_e = true,
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 2,
	})
	testing.expect(t, sim.camera.target_position[0] > 0)
	testing.expect(t, sim.camera.target_position[1] < 0)
	testing.expect(t, sim.camera.target_zoom > 1)
	testing.expect(t, sim.camera.position[0] > 0)
	testing.expect(t, sim.camera.position[1] < 0)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Slime_Mold, {
		actions = {camera_reset = {pressed = true, owner = .Mouse_Keyboard}},
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 1,
	})
	testing.expect_value(t, sim.camera.target_position[0], f32(0))
	testing.expect_value(t, sim.camera.target_position[1], f32(0))
	testing.expect_value(t, sim.camera.target_zoom, f32(1))
}

@(test)
test_toroidal_remaining_sims_use_shared_camera_and_wrapped_pointer :: proc(t: ^testing.T) {
	kinds := [?]game.Remaining_Sim_Kind{.Pellets, .Voronoi_CA, .Primordial}
	for kind in kinds {
		sim: game.Remaining_Sim_State
		sim_storage: Test_Remaining_Sim_Product_Storage
		test_remaining_sim_init(&sim, &sim_storage)
		game.remaining_sim_apply_frame_input_for_kind(&sim, kind, {
			window_width = 100,
			window_height = 100,
			mouse_pos = {100, 50},
			key_d = true,
			key_e = true,
			delta_time = 1.0 / 60.0,
			camera_sensitivity = 1,
		})
		testing.expect(t, sim.camera.target_position[0] > 0)
		testing.expect(t, sim.camera.target_zoom > 1)
		testing.expect(t, sim.cursor_world[0] >= -1 && sim.cursor_world[0] < 1)
		testing.expect(t, sim.cursor_world[1] >= -1 && sim.cursor_world[1] < 1)

		game.remaining_sim_apply_frame_input_for_kind(&sim, kind, {
			actions = {camera_reset = {pressed = true, owner = .Controller}},
			delta_time = 1.0 / 60.0,
			camera_sensitivity = 1,
		})
		testing.expect_value(t, sim.camera.position, [2]f32{})
		testing.expect_value(t, sim.camera.zoom, f32(1))
	}
}

@(test)
test_shared_camera_uniform_and_toroidal_coordinates :: proc(t: ^testing.T) {
	camera: game.Camera_Control_State
	game.camera_controls_init(&camera)
	camera.position = {3, -2}
	camera.target_position = camera.position
	camera.zoom = 0.5
	camera.target_zoom = camera.zoom
	uniform := game.camera_uniform_data(&camera, 400, 200)
	testing.expect_value(t, uniform.position, camera.position)
	testing.expect_value(t, uniform.zoom, f32(0.5))
	testing.expect_value(t, uniform.aspect_ratio, f32(2))
	testing.expect_value(t, game.toroidal_world_position({3.25, -2.25}), [2]f32{-0.75, -0.25})
	testing.expect_value(t, game.infinite_render_tile_count(1), u32(7))
	testing.expect(t, game.infinite_render_tile_count(0.05) > game.infinite_render_tile_count(1))
}

@(test)
test_slime_mold_camera_accepts_controller_pan_and_zoom :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	sim_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&sim, &sim_storage)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Slime_Mold, {
		controller_left = {1, -1},
		controller_zoom = 1,
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 1,
	})

	testing.expect(t, sim.camera.target_position[0] > 0)
	testing.expect(t, sim.camera.target_position[1] < 0)
	testing.expect(t, sim.camera.target_zoom > 1)
}

@(test)
test_controller_camera_y_inversion_preserves_default_direction_and_isolates_sensitivity :: proc(t: ^testing.T) {
	normal, inverted, slow, fast: game.Camera_Control_State
	game.camera_controls_init(&normal)
	game.camera_controls_init(&inverted)
	game.camera_controls_init(&slow)
	game.camera_controls_init(&fast)
	base_input := game.Ui_Frame_Input{
		controller_left = {0.5, -0.75},
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 4,
		controller_camera_sensitivity = 1,
	}
	game.camera_controls_apply_input(&normal, base_input)
	base_input.controller_camera_invert_y = true
	game.camera_controls_apply_input(&inverted, base_input)
	testing.expect(t, normal.target_position[1] < 0)
	testing.expect(t, inverted.target_position[1] > 0)
	testing.expect(t, math.abs(normal.target_position[1] + inverted.target_position[1]) < 0.00001)

	base_input.controller_camera_invert_y = false
	base_input.controller_camera_sensitivity = 0.5
	game.camera_controls_apply_input(&slow, base_input)
	base_input.controller_camera_sensitivity = 2
	game.camera_controls_apply_input(&fast, base_input)
	testing.expect(t, math.abs(fast.target_position[0]) > math.abs(slow.target_position[0]))
	zoom_slow, zoom_fast: game.Camera_Control_State
	game.camera_controls_init(&zoom_slow)
	game.camera_controls_init(&zoom_fast)
	game.camera_controls_apply_input(&zoom_slow, {controller_zoom = 1, camera_sensitivity = 4, controller_camera_sensitivity = 0.5, delta_time = 1.0 / 60.0})
	game.camera_controls_apply_input(&zoom_fast, {controller_zoom = 1, camera_sensitivity = 4, controller_camera_sensitivity = 2, delta_time = 1.0 / 60.0})
	testing.expect(t, zoom_fast.target_zoom > zoom_slow.target_zoom)

	keyboard_a, keyboard_b: game.Camera_Control_State
	game.camera_controls_init(&keyboard_a)
	game.camera_controls_init(&keyboard_b)
	game.camera_controls_apply_input(&keyboard_a, {key_w = true, camera_sensitivity = 1, controller_camera_sensitivity = 0.1, delta_time = 1.0 / 60.0})
	game.camera_controls_apply_input(&keyboard_b, {key_w = true, camera_sensitivity = 1, controller_camera_sensitivity = 5, delta_time = 1.0 / 60.0})
	testing.expect_value(t, keyboard_a.target_position, keyboard_b.target_position)
}

@(test)
test_slime_mold_camera_resets_from_controller_reset_action :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	sim_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&sim, &sim_storage)
	sim.camera.position = {1, -0.5}
	sim.camera.target_position = sim.camera.position
	sim.camera.zoom = 2
	sim.camera.target_zoom = 2

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Slime_Mold, {
		actions = {camera_reset = {pressed = true, owner = .Controller}},
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 1,
	})

	testing.expect_value(t, sim.camera.position[0], f32(0))
	testing.expect_value(t, sim.camera.position[1], f32(0))
	testing.expect_value(t, sim.camera.zoom, f32(1))
	testing.expect_value(t, sim.camera.target_zoom, f32(1))
}

@(test)
test_slime_camera_uniform_uses_runtime_camera_state :: proc(t: ^testing.T) {
	camera: game.Camera_Control_State
	game.camera_controls_init(&camera)
	camera.position = {1, -0.5}
	camera.target_position = camera.position
	camera.zoom = 2
	camera.target_zoom = 2

	uniform := game.slime_camera_uniform_for_state(320, 160, &camera)

	testing.expect_value(t, uniform.position[0], f32(1))
	testing.expect_value(t, uniform.position[1], f32(-0.5))
	testing.expect_value(t, uniform.zoom, f32(2))
	testing.expect_value(t, uniform.aspect_ratio, f32(2))
	testing.expect_value(t, uniform.transform_matrix[0], f32(2))
	testing.expect_value(t, uniform.transform_matrix[5], f32(2))
	testing.expect_value(t, uniform.transform_matrix[12], f32(-2))
	testing.expect_value(t, uniform.transform_matrix[13], f32(1))
}

@(test)
test_controller_left_stick_click_requests_camera_reset :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)

	host.app_apply_gamepad_button(app, .LEFT_STICK, true)
	testing.expect(t, app.controller_camera_reset_pressed)

	host.app_apply_gamepad_button(app, .LEFT_STICK, false)
	testing.expect(t, app.controller_camera_reset_pressed)

	host.app_poll_events(app)
	testing.expect(t, !app.controller_camera_reset_pressed)
}

@(test)
test_controller_confirm_is_a_single_press_pulse :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)

	host.app_apply_gamepad_button(app, .SOUTH, true)
	testing.expect(t, app.controller_accept_down)
	testing.expect(t, app.input.accept)

	// The physical button remains held, but the one-frame action pulse expires.
	host.app_poll_events(app)
	testing.expect(t, app.controller_accept_down)
	testing.expect(t, !app.input.accept)
}

@(test)
test_keyboard_confirm_ignores_auto_repeat :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)

	host.app_apply_key_event(app, sdl.K_RETURN, .RETURN, true)
	testing.expect(t, app.input.key_enter)

	host.app_poll_events(app)
	host.app_apply_key_event(app, sdl.K_RETURN, .RETURN, true, true)
	testing.expect(t, !app.input.key_enter)
}

@(test)
test_particle_life_accepts_left_side_simulation_clicks :: proc(t: ^testing.T) {
	sim: game.Particle_Life_Simulation
	storage: Test_Particle_Life_Product_Storage
	test_particle_life_init(&sim, &storage, 1920, 1080)

	game.particle_life_apply_frame_input(&sim, {
		window_width = 1920,
		window_height = 1080,
		mouse_pos = {100, 100},
		mouse_down = true,
		mouse_button = 1,
		delta_time = 1.0 / 60.0,
		camera_sensitivity = 1,
	})

	testing.expect_value(t, sim.runtime.cursor_active, u32(1))
}

@(test)
test_remaining_sim_screen_to_world_uses_ndc_coordinates :: proc(t: ^testing.T) {
	center := game.remaining_sim_screen_to_world({960, 540}, 1920, 1080)
	testing.expect_value(t, center[0], f32(0))
	testing.expect_value(t, center[1], f32(0))

	top_left := game.remaining_sim_screen_to_world({0, 0}, 1920, 1080)
	testing.expect_value(t, top_left[0], f32(-1))
	testing.expect_value(t, top_left[1], f32(1))
}

@(test)
test_voronoi_cursor_texture_y_follows_mouse_y :: proc(t: ^testing.T) {
	top := rendervk.voronoi_cursor_texture_position({-1, 1}, 200, 100)
	bottom := rendervk.voronoi_cursor_texture_position({1, -1}, 200, 100)

	testing.expect_value(t, top[0], f32(0))
	testing.expect_value(t, top[1], f32(100))
	testing.expect_value(t, bottom[0], f32(200))
	testing.expect_value(t, bottom[1], f32(0))
}

@(test)
test_flow_field_input_tracks_cursor_mode_and_vulkan_y :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	sim_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&sim, &sim_storage)

	game.remaining_sim_apply_frame_input(&sim, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {50, 50},
		delta_time = 1.0 / 60.0,
	})
	game.remaining_sim_apply_frame_input(&sim, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {75, 25},
		mouse_down = true,
		mouse_button = 3,
		delta_time = 1.0 / 60.0,
	})

	testing.expect_value(t, sim.cursor_active, u32(1))
	testing.expect_value(t, sim.cursor_mode, u32(2))
	testing.expect_value(t, sim.cursor_world[0], f32(0.5))
	testing.expect_value(t, sim.cursor_world[1], f32(-0.5))
	testing.expect(t, sim.cursor_world_velocity[0] > 0)
	testing.expect(t, sim.cursor_world_velocity[1] < 0)
}

@(test)
test_primordial_input_tracks_vulkan_y :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	sim_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&sim, &sim_storage)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Primordial, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {75, 25},
		mouse_down = true,
		mouse_button = 1,
		delta_time = 1.0 / 60.0,
	})

	testing.expect_value(t, sim.cursor_world[0], f32(0.5))
	testing.expect_value(t, sim.cursor_world[1], f32(-0.5))
}

@(test)
test_pellets_input_preserves_old_mouse_y_flip :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	sim_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&sim, &sim_storage)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Pellets, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {75, 25},
		mouse_down = true,
		mouse_button = 1,
		delta_time = 1.0 / 60.0,
	})

	testing.expect_value(t, sim.cursor_world[0], f32(0.5))
	testing.expect_value(t, sim.cursor_world[1], f32(-0.5))
}

@(test)
test_pellets_throw_velocity_survives_release_frame :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	sim_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&sim, &sim_storage)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Pellets, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {50, 50},
		mouse_down = true,
		mouse_button = 1,
		delta_time = 1.0 / 60.0,
	})
	game.remaining_sim_apply_frame_input_for_kind(&sim, .Pellets, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {75, 50},
		mouse_down = true,
		mouse_button = 1,
		delta_time = 1.0 / 60.0,
	})

	drag_velocity := sim.cursor_world_velocity
	testing.expect(t, drag_velocity[0] > 20)
	testing.expect(t, drag_velocity[0] < 30)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Pellets, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {75, 50},
		mouse_down = false,
		mouse_button = 1,
		delta_time = 1.0 / 60.0,
	})

	testing.expect_value(t, sim.cursor_active, u32(0))
	testing.expect_value(t, sim.cursor_mode, u32(0))
	testing.expect(t, sim.cursor_world_velocity[0] > 0)
	testing.expect(t, test_approx_f32(sim.cursor_world_velocity[0], drag_velocity[0] * 0.95))
}

@(test)
test_slime_mold_cursor_pixel_y_matches_shader_coordinates :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	sim_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&sim, &sim_storage)

	game.remaining_sim_apply_frame_input_for_kind(&sim, .Slime_Mold, {
		window_width = 100,
		window_height = 100,
		mouse_pos = {25, 20},
		mouse_down = true,
		mouse_button = 1,
		delta_time = 1.0 / 60.0,
	})

	testing.expect_value(t, sim.cursor_pixel[0], f32(25))
	testing.expect_value(t, sim.cursor_pixel[1], f32(80))
	testing.expect_value(t, sim.cursor_world[1], f32(0.6))
}

@(test)
test_shader_manifest_parse_supports_multi_entry_sources :: proc(t: ^testing.T) {
	parsed, ok := engine.shader_manifest_parse_line("assets/shaders/simulations/slime_mold/shaders/compute.slang|compute|update_agent_speeds|build/shaders/simulations/slime_mold/shaders/compute_compute_update_agent_speeds.spv")

	testing.expect(t, ok)
	testing.expect_value(t, parsed.source_path, "assets/shaders/simulations/slime_mold/shaders/compute.slang")
	testing.expect_value(t, parsed.stage, engine.Shader_Stage.Compute)
	testing.expect_value(t, parsed.entry_point, "update_agent_speeds")
	testing.expect_value(t, parsed.spirv_path, "build/shaders/simulations/slime_mold/shaders/compute_compute_update_agent_speeds.spv")
}

@(test)
test_shader_source_fallback_constants_match_manifest_keys :: proc(t: ^testing.T) {
	testing.expect_value(t, game.FLOW_VECTOR_SHADER_SOURCE, "assets/shaders/simulations/flow/shaders/flow_vector_compute.slang")
	testing.expect_value(t, game.FLOW_VECTOR_FALLBACK_SPV, "build/shaders/simulations/flow/shaders/flow_vector_compute")
	testing.expect_value(t, game.SLIME_COMPUTE_SHADER_SOURCE, "assets/shaders/simulations/slime_mold/shaders/compute.slang")
	testing.expect_value(t, game.SLIME_SOURCE_ENTRY_UPDATE_SPEEDS, "update_agent_speeds")
	testing.expect_value(t, game.SLIME_UPDATE_SPEEDS_FALLBACK_SPV, "build/shaders/simulations/slime_mold/shaders/compute_compute_update_agent_speeds")
	testing.expect_value(t, rendervk.MOIRE_PRESENT_FRAGMENT_SOURCE_ENTRY, "fs_main_texture")
	testing.expect_value(t, game.GRAY_SCOTT_PRESENT_FALLBACK_SPV, "build/shaders/gray_scott_present_fragment")
}

@(test)
test_slime_speed_range_change_tracking_matches_settings :: proc(t: ^testing.T) {
	gpu: rendervk.Slime_Gpu_State
	settings := game.slime_settings_default()

	testing.expect(t, rendervk.slime_speed_range_changed(&gpu, &settings))

	gpu.agent_speed_min_uploaded = settings.agent_speed_min
	gpu.agent_speed_max_uploaded = settings.agent_speed_max
	testing.expect(t, !rendervk.slime_speed_range_changed(&gpu, &settings))

	settings.agent_speed_max += 0.25
	testing.expect(t, rendervk.slime_speed_range_changed(&gpu, &settings))
}

@(test)
test_flow_defaults_keep_particles_visible_with_color_scheme_background :: proc(t: ^testing.T) {
	settings := game.flow_settings_default()

	testing.expect_value(t, settings.show_particles, true)
	testing.expect_value(t, settings.background_color_mode, game.Vector_Background_Mode.Color_Scheme)
	testing.expect_value(t, settings.background_index, int(game.Vector_Background_Mode.Color_Scheme))
	testing.expect_value(t, settings.image_fit_mode, game.Vector_Image_Fit_Mode.Stretch)
	testing.expect_value(t, settings.image_fit_index, int(game.Vector_Image_Fit_Mode.Stretch))
	testing.expect_value(t, settings.image_mirror_horizontal, false)
	testing.expect_value(t, settings.image_mirror_vertical, false)
	testing.expect_value(t, settings.image_invert_tone, false)
}

@(test)
test_vectors_color_scheme_background_uses_active_lut :: proc(t: ^testing.T) {
	settings := game.vectors_settings_default()
	settings.background_color_mode = .Color_Scheme
	settings.background_index = int(game.Vector_Background_Mode.Color_Scheme)
	game.color_scheme_name_set(&settings.color_scheme, "MATPLOTLIB_viridis")
	settings.color_scheme_reversed = false

	clear := game.vectors_clear_color(&settings)
	scheme := game.color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
	expected := game.color_scheme_color_at(scheme, 0)
	testing.expect_value(t, clear.r, expected[0])
	testing.expect_value(t, clear.g, expected[1])
	testing.expect_value(t, clear.b, expected[2])
	testing.expect_value(t, clear.a, expected[3])

	settings.color_scheme_reversed = true
	clear = game.vectors_clear_color(&settings)
	scheme = game.color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
	expected = game.color_scheme_color_at(scheme, 0)
	testing.expect_value(t, clear.r, expected[0])
	testing.expect_value(t, clear.g, expected[1])
	testing.expect_value(t, clear.b, expected[2])
	testing.expect_value(t, clear.a, expected[3])
}

@(test)
test_flow_shader_mouse_button_preserves_right_click_delete_mode :: proc(t: ^testing.T) {
	sim: game.Remaining_Sim_State
	sim_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&sim, &sim_storage)

	testing.expect_value(t, game.flow_mouse_button_down_from_cursor(&sim), u32(0))

	sim.cursor_active = 1
	sim.cursor_mode = 1
	testing.expect_value(t, game.flow_mouse_button_down_from_cursor(&sim), u32(1))

	sim.cursor_mode = 2
	testing.expect_value(t, game.flow_mouse_button_down_from_cursor(&sim), u32(2))
}

@(test)
test_vector_image_source_rows_match_vulkan_visual_y :: proc(t: ^testing.T) {
	src_x, src_y: int

	ok := game.vectors_image_source_coord(1, 2, 1, 2, 0, 0, .Stretch, &src_x, &src_y)
	testing.expect(t, ok)
	testing.expect_value(t, src_x, 0)
	testing.expect_value(t, src_y, 1)

	ok = game.vectors_image_source_coord(1, 2, 1, 2, 0, 1, .Stretch, &src_x, &src_y)
	testing.expect(t, ok)
	testing.expect_value(t, src_x, 0)
	testing.expect_value(t, src_y, 0)
}

@(test)
test_gray_scott_nutrient_image_rows_match_vulkan_visual_y :: proc(t: ^testing.T) {
	source := [8]u8{
		255, 0, 0, 255,
		0, 0, 255, 255,
	}

	bottom_target_value := game.gray_scott_nutrient_image_value(raw_data(source[:]), 1, 2, 4, 1, 2, 0, 0, .Stretch)
	top_target_value := game.gray_scott_nutrient_image_value(raw_data(source[:]), 1, 2, 4, 1, 2, 0, 1, .Stretch)

	testing.expect(t, bottom_target_value < top_target_value)
	testing.expect_value(t, top_target_value, f32(0.2126))
}

@(test)
test_noise_defaults_match_world_creator_style_controls :: proc(t: ^testing.T) {
	settings := game.noise_settings_default(.Gabor)

	testing.expect_value(t, settings.kind, game.Noise_Kind.Gabor)
	testing.expect_value(t, settings.kind_index, int(game.Noise_Kind.Gabor))
	testing.expect_value(t, settings.noise_strength, f32(1))
	testing.expect_value(t, settings.amplitude, f32(1))
	testing.expect_value(t, settings.frequency, f32(1))
	testing.expect_value(t, settings.fractal_mode, game.Noise_Fractal_Mode.Single)
	testing.expect_value(t, settings.octaves, u32(6))
	testing.expect_value(t, settings.lacunarity, f32(2))
	testing.expect_value(t, settings.gain, f32(0.5))
	testing.expect_value(t, settings.warp_mode, game.Noise_Warp_Mode.None)
	testing.expect_value(t, settings.gabor.iterations, u32(50))
	testing.expect_value(t, settings.gabor.velocity, f32(1))
	testing.expect_value(t, settings.gabor.band_width, f32(0.01))
	testing.expect_value(t, settings.gabor.band_softness, f32(1))
}

@(test)
test_noise_all_kinds_produce_finite_bounded_samples :: proc(t: ^testing.T) {
	for i in 0 ..< len(game.NOISE_KIND_NAMES) {
		settings := game.noise_settings_default(game.Noise_Kind(i))
		settings.seed = 17
		settings.frequency = 2.25
		settings.fractal_mode = .FBM
		settings.octaves = 3
		value := game.noise_sample_2d(&settings, 0.37, -0.81, 0.125)

		testing.expect(t, value >= -1)
		testing.expect(t, value <= 1)
	}
}

@(test)
test_noise_type_specific_settings_affect_output :: proc(t: ^testing.T) {
	gabor := game.noise_settings_default(.Gabor)
	gabor.seed = 4
	gabor.gabor.band_width = 0.01
	gabor_a := game.noise_sample_2d(&gabor, 0.4, 0.8, 0.2)
	gabor.gabor.band_width = 0.25
	gabor_b := game.noise_sample_2d(&gabor, 0.4, 0.8, 0.2)
	testing.expect(t, math.abs(gabor_a - gabor_b) > 0.0001)

	phasor := game.noise_settings_default(.Phasor)
	phasor.seed = 5
	phasor.phasor.velocity = 0
	phasor_a := game.noise_sample_2d(&phasor, -0.2, 0.55, 0.25)
	phasor.phasor.velocity = 8
	phasor_b := game.noise_sample_2d(&phasor, -0.2, 0.55, 0.25)
	testing.expect(t, math.abs(phasor_a - phasor_b) > 0.0001)

	voronoi := game.noise_settings_default(.Voronoi)
	voronoi.seed = 6
	voronoi.voronoi.output = .Distance_F1
	voronoi_a := game.noise_sample_2d(&voronoi, 0.13, -0.47, 0)
	voronoi.voronoi.output = .Cell_Value
	voronoi_b := game.noise_sample_2d(&voronoi, 0.13, -0.47, 0)
	testing.expect(t, math.abs(voronoi_a - voronoi_b) > 0.0001)
}

@(test)
test_vectors_legacy_noise_preset_migrates_to_canonical_settings :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_vectors_legacy_noise.toml"
	legacy := "[vectors]\nvector_field_type = \"Noise\"\nnoise_type = \"FBM Ridged\"\nnoise_seed = 42\nnoise_scale = 3.500000\nnoise_x = -0.250000\nnoise_y = 0.750000\n"
	testing.expect(t, os.write_entire_file(path, legacy) == nil)

	loaded, ok := game.settings_load_vectors(path, game.vectors_settings_default())

	testing.expect(t, ok)
	testing.expect_value(t, loaded.noise.kind, game.Noise_Kind.Simplex)
	testing.expect_value(t, loaded.noise.fractal_mode, game.Noise_Fractal_Mode.Ridged)
	testing.expect_value(t, loaded.noise.seed, u32(42))
	testing.expect_value(t, loaded.noise.frequency, f32(3.5))
	testing.expect_value(t, loaded.noise.offset_x, f32(-0.25))
	testing.expect_value(t, loaded.noise.offset_y, f32(0.75))
}

@(test)
test_remaining_image_settings_round_trip_through_tomlc17 :: proc(t: ^testing.T) {
	flow_path := "/tmp/vizzaodin_flow_remaining_roundtrip.toml"
	flow := game.flow_settings_default()
	flow.vector_field_type = .Image
	flow.vector_field_index = int(game.Vector_Field_Type.Image)
	flow.image_fit_mode = .Fit_H
	flow.image_fit_index = int(game.Vector_Image_Fit_Mode.Fit_H)
	flow.image_mirror_horizontal = true
	flow.image_invert_tone = true
	flow.noise.kind = .Checkerboard
	flow.noise.seed = 77
	flow.noise.frequency = 2.5
	flow.noise.offset_x = -0.75
	flow.noise.offset_y = 1.25
	flow.noise.fractal_mode = .FBM
	flow.noise.octaves = 4
	flow.vector_magnitude = 0.45
	flow.total_pool_size = 12345
	flow.particle_lifetime = 6.5
	flow.particle_speed = 1.75
	flow.particle_size = 9
	flow.particle_shape = .Diamond
	flow.shape_index = int(game.Flow_Particle_Shape.Diamond)
	flow.particle_autospawn = false
	flow.show_particles = false
	flow.autospawn_rate = 12
	flow.brush_spawn_rate = 34
	flow.emitter_mode = .Ring
	flow.emitter_index = int(game.Flow_Emitter_Mode.Ring)
	flow.emitter_radius = 0.625
	flow.boundary_mode = .Respawn
	flow.boundary_index = int(game.Flow_Boundary_Mode.Respawn)
	flow.trail_style = .Dotted
	flow.trail_style_index = int(game.Flow_Trail_Style.Dotted)
	flow.field_animation_enabled = true
	flow.field_animation_speed = -0.35
	flow.foreground_color_mode = .Direction
	flow.foreground_index = int(game.Flow_Foreground_Mode.Direction)
	flow.background_color_mode = .White
	flow.background_index = int(game.Vector_Background_Mode.White)
	flow.trail_decay_rate = 0.25
	flow.trail_deposition_rate = 0.75
	flow.trail_diffusion_rate = 0.125
	flow.trail_wash_out_rate = 0.0625
	flow.trail_map_filtering = .Linear
	flow.trail_filtering_index = int(game.Flow_Trail_Map_Filtering.Linear)
	game.write_fixed_string(flow.image_path[:], "config/flow.png")
	testing.expect(t, game.settings_save_flow(flow_path, flow))
	loaded_flow, flow_ok := game.settings_load_flow(flow_path, game.flow_settings_default())
	testing.expect(t, flow_ok)
	testing.expect_value(t, loaded_flow.vector_field_type, game.Vector_Field_Type.Image)
	testing.expect_value(t, loaded_flow.image_fit_mode, game.Vector_Image_Fit_Mode.Fit_H)
	testing.expect_value(t, loaded_flow.image_mirror_horizontal, true)
	testing.expect_value(t, loaded_flow.image_invert_tone, true)
	testing.expect_value(t, game.fixed_string(loaded_flow.image_path[:]), "config/flow.png")
	testing.expect_value(t, loaded_flow.noise.kind, game.Noise_Kind.Checkerboard)
	testing.expect_value(t, loaded_flow.noise.seed, u32(77))
	testing.expect_value(t, loaded_flow.noise.frequency, f32(2.5))
	testing.expect_value(t, loaded_flow.noise.offset_x, f32(-0.75))
	testing.expect_value(t, loaded_flow.noise.offset_y, f32(1.25))
	testing.expect_value(t, loaded_flow.noise.fractal_mode, game.Noise_Fractal_Mode.FBM)
	testing.expect_value(t, loaded_flow.noise.octaves, u32(4))
	testing.expect_value(t, loaded_flow.vector_magnitude, f32(0.45))
	testing.expect_value(t, loaded_flow.total_pool_size, u32(12345))
	testing.expect_value(t, loaded_flow.particle_lifetime, f32(6.5))
	testing.expect_value(t, loaded_flow.particle_speed, f32(1.75))
	testing.expect_value(t, loaded_flow.particle_size, u32(9))
	testing.expect_value(t, loaded_flow.particle_shape, game.Flow_Particle_Shape.Diamond)
	testing.expect_value(t, loaded_flow.particle_autospawn, false)
	testing.expect_value(t, loaded_flow.show_particles, false)
	testing.expect_value(t, loaded_flow.autospawn_rate, u32(12))
	testing.expect_value(t, loaded_flow.brush_spawn_rate, u32(34))
	testing.expect_value(t, loaded_flow.emitter_mode, game.Flow_Emitter_Mode.Ring)
	testing.expect_value(t, loaded_flow.emitter_radius, f32(0.625))
	testing.expect_value(t, loaded_flow.boundary_mode, game.Flow_Boundary_Mode.Respawn)
	testing.expect_value(t, loaded_flow.trail_style, game.Flow_Trail_Style.Dotted)
	testing.expect_value(t, loaded_flow.field_animation_enabled, true)
	testing.expect_value(t, loaded_flow.field_animation_speed, f32(-0.35))
	testing.expect_value(t, loaded_flow.foreground_color_mode, game.Flow_Foreground_Mode.Direction)
	testing.expect_value(t, loaded_flow.background_color_mode, game.Vector_Background_Mode.White)
	testing.expect_value(t, loaded_flow.trail_decay_rate, f32(0.25))
	testing.expect_value(t, loaded_flow.trail_deposition_rate, f32(0.75))
	testing.expect_value(t, loaded_flow.trail_diffusion_rate, f32(0.125))
	testing.expect_value(t, loaded_flow.trail_wash_out_rate, f32(0.0625))
	testing.expect_value(t, loaded_flow.trail_map_filtering, game.Flow_Trail_Map_Filtering.Linear)

	moire_path := "/tmp/vizzaodin_moire_remaining_roundtrip.toml"
	moire := game.moire_settings_default()
	moire.speed = 0.33
	moire.generator_type = .Radial
	moire.generator_index = int(game.Moire_Generator_Type.Radial)
	moire.base_freq = 12.5
	moire.moire_amount = 1.25
	moire.moire_rotation = -0.75
	moire.moire_scale = 1.75
	moire.moire_interference = 0.875
	moire.moire_rotation3 = 0.45
	moire.moire_scale3 = 2.25
	moire.moire_weight3 = 0.625
	moire.radial_swirl_strength = 0.375
	moire.radial_starburst_count = 24
	moire.radial_center_brightness = 2.5
	moire.advect_strength = 1.25
	moire.advect_speed = 3.5
	moire.curl = 1.5
	moire.decay = 0.925
	moire.image_mode_enabled = true
	moire.image_fit_mode = .Center
	moire.image_fit_index = int(game.Vector_Image_Fit_Mode.Center)
	moire.image_mirror_horizontal = true
	moire.image_mirror_vertical = true
	moire.image_invert_tone = false
	moire.image_interference_mode = .Overlay
	moire.interference_index = int(game.Moire_Image_Interference_Mode.Overlay)
	game.write_fixed_string(moire.image_path[:], "config/moire.png")
	testing.expect(t, game.settings_save_moire(moire_path, moire))
	loaded_moire, moire_ok := game.settings_load_moire(moire_path, game.moire_settings_default())
	testing.expect(t, moire_ok)
	testing.expect_value(t, loaded_moire.speed, f32(0.33))
	testing.expect_value(t, loaded_moire.generator_type, game.Moire_Generator_Type.Radial)
	testing.expect_value(t, loaded_moire.base_freq, f32(12.5))
	testing.expect_value(t, loaded_moire.moire_amount, f32(1.25))
	testing.expect_value(t, loaded_moire.moire_rotation, f32(-0.75))
	testing.expect_value(t, loaded_moire.moire_scale, f32(1.75))
	testing.expect_value(t, loaded_moire.moire_interference, f32(0.875))
	testing.expect_value(t, loaded_moire.moire_rotation3, f32(0.45))
	testing.expect_value(t, loaded_moire.moire_scale3, f32(2.25))
	testing.expect_value(t, loaded_moire.moire_weight3, f32(0.625))
	testing.expect_value(t, loaded_moire.radial_swirl_strength, f32(0.375))
	testing.expect_value(t, loaded_moire.radial_starburst_count, f32(24))
	testing.expect_value(t, loaded_moire.radial_center_brightness, f32(2.5))
	testing.expect_value(t, loaded_moire.advect_strength, f32(1.25))
	testing.expect_value(t, loaded_moire.advect_speed, f32(3.5))
	testing.expect_value(t, loaded_moire.curl, f32(1.5))
	testing.expect_value(t, loaded_moire.decay, f32(0.925))
	testing.expect_value(t, loaded_moire.image_mode_enabled, true)
	testing.expect_value(t, loaded_moire.image_fit_mode, game.Vector_Image_Fit_Mode.Center)
	testing.expect_value(t, loaded_moire.image_mirror_horizontal, true)
	testing.expect_value(t, loaded_moire.image_mirror_vertical, true)
	testing.expect_value(t, loaded_moire.image_invert_tone, false)
	testing.expect_value(t, loaded_moire.image_interference_mode, game.Moire_Image_Interference_Mode.Overlay)
	testing.expect_value(t, game.fixed_string(loaded_moire.image_path[:]), "config/moire.png")

	vectors_path := "/tmp/vizzaodin_vectors_remaining_roundtrip.toml"
	vectors := game.vectors_settings_default()
	vectors.vector_field_type = .Image
	vectors.vector_field_index = int(game.Vector_Field_Type.Image)
	vectors.image_fit_mode = .Fit_V
	vectors.image_fit_index = int(game.Vector_Image_Fit_Mode.Fit_V)
	vectors.image_mirror_horizontal = true
	vectors.noise.kind = .Cylinders
	vectors.noise.seed = 123
	vectors.noise.frequency = 6.25
	vectors.density = 0.04
	vectors.line_length = 0.08
	vectors.line_width = 0.004
	vectors.display_mode = .Arrows
	vectors.display_index = int(game.Vector_Display_Mode.Arrows)
	vectors.background_color_mode = .Color_Scheme
	vectors.background_index = int(game.Vector_Background_Mode.Color_Scheme)
	testing.expect(t, game.settings_save_vectors(vectors_path, vectors))
	loaded_vectors, vectors_ok := game.settings_load_vectors(vectors_path, game.vectors_settings_default())
	testing.expect(t, vectors_ok)
	testing.expect_value(t, loaded_vectors.vector_field_type, game.Vector_Field_Type.Image)
	testing.expect_value(t, loaded_vectors.image_fit_mode, game.Vector_Image_Fit_Mode.Fit_V)
	testing.expect_value(t, loaded_vectors.image_mirror_horizontal, true)
	testing.expect_value(t, loaded_vectors.noise.kind, game.Noise_Kind.Cylinders)
	testing.expect_value(t, loaded_vectors.noise.seed, u32(123))
	testing.expect_value(t, loaded_vectors.noise.frequency, f32(6.25))
	testing.expect_value(t, loaded_vectors.density, f32(0.04))
	testing.expect_value(t, loaded_vectors.line_length, f32(0.08))
	testing.expect_value(t, loaded_vectors.line_width, f32(0.004))
	testing.expect_value(t, loaded_vectors.display_mode, game.Vector_Display_Mode.Arrows)
	testing.expect_value(t, loaded_vectors.background_color_mode, game.Vector_Background_Mode.Color_Scheme)
}

@(test)
test_remaining_core_settings_round_trip_through_tomlc17 :: proc(t: ^testing.T) {
	primordial_path := "/tmp/vizzaodin_primordial_remaining_roundtrip.toml"
	primordial := game.primordial_settings_default()
	primordial.particle_count = 2345
	primordial.random_seed = 99
	primordial.position_generator = 6
	primordial.position_generator_index = 6
	primordial.alpha = 22.5
	primordial.beta = -1.25
	primordial.velocity = 0.75
	primordial.radius = 0.2
	primordial.dt = 0.033
	primordial.particle_size = 0.03
	primordial.density_radius = 0.09
	primordial.background_color_mode = .White
	primordial.background_index = int(game.Vector_Background_Mode.White)
	primordial.foreground_color_mode = .Velocity
	primordial.foreground_index = int(game.Primordial_Foreground_Mode.Velocity)
	primordial.traces_enabled = true
	primordial.trace_fade = 0.35
	primordial.wrap_edges = false
	testing.expect(t, game.settings_save_primordial(primordial_path, primordial))
	loaded_primordial, primordial_ok := game.settings_load_primordial(primordial_path, game.primordial_settings_default())
	testing.expect(t, primordial_ok)
	testing.expect_value(t, loaded_primordial.particle_count, u32(2345))
	testing.expect_value(t, loaded_primordial.random_seed, u32(99))
	testing.expect_value(t, loaded_primordial.position_generator, u32(6))
	testing.expect_value(t, loaded_primordial.alpha, f32(22.5))
	testing.expect_value(t, loaded_primordial.beta, f32(-1.25))
	testing.expect_value(t, loaded_primordial.velocity, f32(0.75))
	testing.expect_value(t, loaded_primordial.radius, f32(0.2))
	testing.expect_value(t, loaded_primordial.dt, f32(0.033))
	testing.expect_value(t, loaded_primordial.particle_size, f32(0.03))
	testing.expect_value(t, loaded_primordial.density_radius, f32(0.09))
	testing.expect_value(t, loaded_primordial.background_color_mode, game.Vector_Background_Mode.White)
	testing.expect_value(t, loaded_primordial.foreground_color_mode, game.Primordial_Foreground_Mode.Velocity)
	testing.expect_value(t, loaded_primordial.traces_enabled, true)
	testing.expect_value(t, loaded_primordial.trace_fade, f32(0.35))
	testing.expect_value(t, loaded_primordial.wrap_edges, false)

	pellets_path := "/tmp/vizzaodin_pellets_remaining_roundtrip.toml"
	pellets := game.pellets_settings_default()
	pellets.particle_count = 3456
	pellets.particle_size = 0.025
	pellets.collision_damping = 0.6
	pellets.initial_velocity_max = 0.5
	pellets.initial_velocity_min = 0.25
	pellets.random_seed = 123
	pellets.background_color_mode = .Gray18
	pellets.background_index = int(game.Vector_Background_Mode.Gray18)
	pellets.gravitational_constant = 0.000002
	pellets.energy_damping = 0.7
	pellets.gravity_softening = 0.01
	pellets.density_radius = 0.12
	pellets.foreground_color_mode = .Velocity
	pellets.foreground_index = int(game.Pellets_Foreground_Mode.Velocity)
	pellets.trails_enabled = true
	pellets.trail_fade = 0.42
	pellets.density_damping_enabled = true
	pellets.overlap_resolution_strength = 0.14
	testing.expect(t, game.settings_save_pellets(pellets_path, pellets))
	loaded_pellets, pellets_ok := game.settings_load_pellets(pellets_path, game.pellets_settings_default())
	testing.expect(t, pellets_ok)
	testing.expect_value(t, loaded_pellets.particle_count, u32(3456))
	testing.expect_value(t, loaded_pellets.particle_size, f32(0.025))
	testing.expect_value(t, loaded_pellets.collision_damping, f32(0.6))
	testing.expect_value(t, loaded_pellets.initial_velocity_max, f32(0.5))
	testing.expect_value(t, loaded_pellets.initial_velocity_min, f32(0.25))
	testing.expect_value(t, loaded_pellets.random_seed, u32(123))
	testing.expect_value(t, loaded_pellets.background_color_mode, game.Vector_Background_Mode.Gray18)
	testing.expect_value(t, loaded_pellets.gravitational_constant, f32(0.000002))
	testing.expect_value(t, loaded_pellets.energy_damping, f32(0.7))
	testing.expect_value(t, loaded_pellets.gravity_softening, f32(0.01))
	testing.expect_value(t, loaded_pellets.density_radius, f32(0.12))
	testing.expect_value(t, loaded_pellets.foreground_color_mode, game.Pellets_Foreground_Mode.Velocity)
	testing.expect_value(t, loaded_pellets.trails_enabled, true)
	testing.expect_value(t, loaded_pellets.trail_fade, f32(0.42))
	testing.expect_value(t, loaded_pellets.density_damping_enabled, true)
	testing.expect_value(t, loaded_pellets.overlap_resolution_strength, f32(0.14))

	voronoi_path := "/tmp/vizzaodin_voronoi_remaining_roundtrip.toml"
	voronoi := game.voronoi_settings_default()
	voronoi.point_count = 1234
	voronoi.time_scale = 2.5
	voronoi.drift = 0.75
	voronoi.brownian_speed = 42.5
	voronoi.random_seed = 44
	voronoi.borders_enabled = true
	voronoi.border_width = 6.5
	voronoi.color_mode = 2
	voronoi.color_mode_index = 2
	testing.expect(t, game.settings_save_voronoi(voronoi_path, voronoi))
	loaded_voronoi, voronoi_ok := game.settings_load_voronoi(voronoi_path, game.voronoi_settings_default())
	testing.expect(t, voronoi_ok)
	testing.expect_value(t, loaded_voronoi.point_count, u32(1234))
	testing.expect_value(t, loaded_voronoi.time_scale, f32(2.5))
	testing.expect_value(t, loaded_voronoi.drift, f32(0.75))
	testing.expect_value(t, loaded_voronoi.brownian_speed, f32(42.5))
	testing.expect_value(t, loaded_voronoi.random_seed, u32(44))
	testing.expect_value(t, loaded_voronoi.borders_enabled, true)
	testing.expect_value(t, loaded_voronoi.border_width, f32(6.5))
	testing.expect_value(t, loaded_voronoi.color_mode, u32(2))
	testing.expect_value(t, loaded_voronoi.color_mode_index, 2)

	slime_path := "/tmp/vizzaodin_slime_remaining_roundtrip.toml"
	slime := game.slime_settings_default()
	slime.agent_jitter = 0.12
	slime.isotropic_jitter = false
	slime.agent_heading_start = 15
	slime.agent_heading_end = 300
	slime.agent_sensor_angle = 0.9
	slime.agent_sensor_distance = 45
	slime.agent_speed_max = 90
	slime.agent_speed_min = 12
	slime.agent_turn_rate = 0.7
	slime.pheromone_decay_rate = 12
	slime.pheromone_deposition_rate = 34
	slime.pheromone_diffusion_rate = 56
	slime.diffusion_frequency = 3
	slime.decay_frequency = 5
	slime.random_seed = 321
	slime.position_generator = 6
	slime.position_generator_index = 6
	slime.mask_pattern = .Wave_Function
	slime.mask_pattern_index = int(game.Slime_Mask_Pattern.Wave_Function)
	slime.mask_target = .Agent_Speed
	slime.mask_target_index = int(game.Slime_Mask_Target.Agent_Speed)
	slime.mask_strength = 0.65
	slime.mask_curve = 1.75
	slime.mask_image_fit_mode = .Fit_H
	slime.mask_image_fit_index = int(game.Vector_Image_Fit_Mode.Fit_H)
	game.write_fixed_string(slime.mask_image_path[:], "config/slime_mask.png")
	slime.position_image_fit_mode = .Center
	slime.position_image_fit_index = int(game.Vector_Image_Fit_Mode.Center)
	game.write_fixed_string(slime.position_image_path[:], "config/slime_position.png")
	slime.mask_mirror_horizontal = true
	slime.mask_mirror_vertical = true
	slime.mask_invert_tone = true
	slime.mask_reversed = true
	slime.trail_map_filtering = .Linear
	slime.trail_filtering_index = int(game.Flow_Trail_Map_Filtering.Linear)
	slime.background_mode = .White
	slime.background_index = int(game.Slime_Background_Mode.White)
	testing.expect(t, game.settings_save_slime(slime_path, slime))
	loaded_slime, slime_ok := game.settings_load_slime(slime_path, game.slime_settings_default())
	testing.expect(t, slime_ok)
	testing.expect_value(t, loaded_slime.agent_jitter, f32(0.12))
	testing.expect_value(t, loaded_slime.isotropic_jitter, false)
	testing.expect_value(t, loaded_slime.agent_heading_start, f32(15))
	testing.expect_value(t, loaded_slime.agent_heading_end, f32(300))
	testing.expect_value(t, loaded_slime.agent_sensor_angle, f32(0.9))
	testing.expect_value(t, loaded_slime.agent_sensor_distance, f32(45))
	testing.expect_value(t, loaded_slime.agent_speed_max, f32(90))
	testing.expect_value(t, loaded_slime.agent_speed_min, f32(12))
	testing.expect_value(t, loaded_slime.agent_turn_rate, f32(0.7))
	testing.expect_value(t, loaded_slime.pheromone_decay_rate, f32(12))
	testing.expect_value(t, loaded_slime.pheromone_deposition_rate, f32(34))
	testing.expect_value(t, loaded_slime.pheromone_diffusion_rate, f32(56))
	testing.expect_value(t, loaded_slime.diffusion_frequency, u32(3))
	testing.expect_value(t, loaded_slime.decay_frequency, u32(5))
	testing.expect_value(t, loaded_slime.random_seed, u32(321))
	testing.expect_value(t, loaded_slime.position_generator, u32(6))
	testing.expect_value(t, loaded_slime.mask_pattern, game.Slime_Mask_Pattern.Wave_Function)
	testing.expect_value(t, loaded_slime.mask_target, game.Slime_Mask_Target.Agent_Speed)
	testing.expect_value(t, loaded_slime.mask_strength, f32(0.65))
	testing.expect_value(t, loaded_slime.mask_curve, f32(1.75))
	testing.expect_value(t, loaded_slime.mask_image_fit_mode, game.Vector_Image_Fit_Mode.Fit_H)
	testing.expect_value(t, game.fixed_string(loaded_slime.mask_image_path[:]), "config/slime_mask.png")
	testing.expect_value(t, loaded_slime.position_image_fit_mode, game.Vector_Image_Fit_Mode.Center)
	testing.expect_value(t, game.fixed_string(loaded_slime.position_image_path[:]), "config/slime_position.png")
	testing.expect_value(t, loaded_slime.mask_mirror_horizontal, true)
	testing.expect_value(t, loaded_slime.mask_mirror_vertical, true)
	testing.expect_value(t, loaded_slime.mask_invert_tone, true)
	testing.expect_value(t, loaded_slime.mask_reversed, true)
	testing.expect_value(t, loaded_slime.trail_map_filtering, game.Flow_Trail_Map_Filtering.Linear)
	testing.expect_value(t, loaded_slime.background_mode, game.Slime_Background_Mode.White)
}

@(test)
test_flow_saved_preset_keeps_current_color_scheme :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_flow_preserve_color_preset.toml"
	preset := game.flow_settings_default()
	preset.vector_magnitude = 0.37
	game.color_scheme_name_set(&preset.color_scheme, "MATPLOTLIB_viridis")
	preset.color_scheme_reversed = true
	testing.expect(t, game.settings_save_flow(path, preset))

	current := game.flow_settings_default()
	game.color_scheme_name_set(&current.color_scheme, "ZELDA_Aqua")
	current.color_scheme_reversed = false
	loaded, ok := game.settings_load_flow_preset(path, current)

	testing.expect(t, ok)
	testing.expect_value(t, loaded.vector_magnitude, f32(0.37))
	test_expect_color_scheme(t, &loaded.color_scheme, loaded.color_scheme_reversed, "ZELDA_Aqua", false)
}

@(test)
test_remaining_builtin_presets_keep_current_color_scheme :: proc(t: ^testing.T) {
	expected_name := "ZELDA_Aqua"
	expected_reversed := false
	sim: game.Remaining_Sim_State
	sim_storage: Test_Remaining_Sim_Product_Storage
	test_remaining_sim_init(&sim, &sim_storage)

	game.color_scheme_name_set(&sim.moire.color_scheme, expected_name)
	sim.moire.color_scheme_reversed = expected_reversed
	game.remaining_sim_apply_builtin_preset(&sim, game.Remaining_Sim_Kind.Moire, 2)
	test_expect_color_scheme(t, &sim.moire.color_scheme, sim.moire.color_scheme_reversed, expected_name, expected_reversed)

	game.color_scheme_name_set(&sim.vectors.color_scheme, expected_name)
	sim.vectors.color_scheme_reversed = expected_reversed
	game.remaining_sim_apply_builtin_preset(&sim, game.Remaining_Sim_Kind.Vectors, 0)
	test_expect_color_scheme(t, &sim.vectors.color_scheme, sim.vectors.color_scheme_reversed, expected_name, expected_reversed)

	game.color_scheme_name_set(&sim.primordial.color_scheme, expected_name)
	sim.primordial.color_scheme_reversed = expected_reversed
	game.remaining_sim_apply_builtin_preset(&sim, game.Remaining_Sim_Kind.Primordial, 0)
	test_expect_color_scheme(t, &sim.primordial.color_scheme, sim.primordial.color_scheme_reversed, expected_name, expected_reversed)

	game.color_scheme_name_set(&sim.voronoi.color_scheme, expected_name)
	sim.voronoi.color_scheme_reversed = expected_reversed
	game.remaining_sim_apply_builtin_preset(&sim, game.Remaining_Sim_Kind.Voronoi_CA, 0)
	test_expect_color_scheme(t, &sim.voronoi.color_scheme, sim.voronoi.color_scheme_reversed, expected_name, expected_reversed)

	game.color_scheme_name_set(&sim.pellets.color_scheme, expected_name)
	sim.pellets.color_scheme_reversed = expected_reversed
	game.remaining_sim_apply_builtin_preset(&sim, game.Remaining_Sim_Kind.Pellets, 0)
	test_expect_color_scheme(t, &sim.pellets.color_scheme, sim.pellets.color_scheme_reversed, expected_name, expected_reversed)

	game.color_scheme_name_set(&sim.flow.color_scheme, expected_name)
	sim.flow.color_scheme_reversed = expected_reversed
	game.remaining_sim_apply_builtin_preset(&sim, game.Remaining_Sim_Kind.Flow_Field, 0)
	test_expect_color_scheme(t, &sim.flow.color_scheme, sim.flow.color_scheme_reversed, expected_name, expected_reversed)

	game.color_scheme_name_set(&sim.slime.color_scheme, expected_name)
	sim.slime.color_scheme_reversed = expected_reversed
	sim.slime_reset_requested = false
	game.remaining_sim_apply_builtin_preset(&sim, game.Remaining_Sim_Kind.Slime_Mold, 2)
	test_expect_color_scheme(t, &sim.slime.color_scheme, sim.slime.color_scheme_reversed, expected_name, expected_reversed)
	testing.expect(t, sim.slime_reset_requested)
}

@(test)
test_app_ui_navigation_tracks_previous_mode :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)
	testing.expect_value(t, ui.mode, game.App_Mode.Main_Menu)
	game.app_ui_navigate(&ui, .Options)
	testing.expect_value(t, ui.mode, game.App_Mode.Options)
	testing.expect_value(t, ui.previous_mode, game.App_Mode.Main_Menu)
}

@(test)
test_app_ui_scene_to_main_menu_waits_at_black_until_menu_rendered :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)
	game.app_ui_navigate(&ui, .Slime_Mold)
	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_OUT_SECONDS)
	game.app_ui_mode_transition_notify_loaded(&ui)
	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_IN_SECONDS)

	game.app_ui_navigate(&ui, .Main_Menu)
	testing.expect_value(t, ui.mode, game.App_Mode.Slime_Mold)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Fade_Out)
	testing.expect_value(t, ui.mode_transition_target, game.App_Mode.Main_Menu)
	testing.expect(t, test_approx_f32(game.app_ui_mode_transition_opacity(&ui), 0))

	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_OUT_SECONDS * 0.5)
	testing.expect_value(t, ui.mode, game.App_Mode.Slime_Mold)
	testing.expect(t, test_approx_f32(game.app_ui_mode_transition_opacity(&ui), 0.5))

	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_OUT_SECONDS * 0.5)
	testing.expect_value(t, ui.mode, game.App_Mode.Main_Menu)
	testing.expect_value(t, ui.previous_mode, game.App_Mode.Slime_Mold)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Waiting_For_Target)
	testing.expect(t, test_approx_f32(game.app_ui_mode_transition_opacity(&ui), 1))

	game.app_ui_mode_transition_update(&ui, 1)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Waiting_For_Target)
	testing.expect(t, test_approx_f32(game.app_ui_mode_transition_opacity(&ui), 1))

	game.app_ui_mode_transition_notify_loaded(&ui)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Fade_In)
	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_IN_SECONDS * 0.5)
	testing.expect(t, test_approx_f32(game.app_ui_mode_transition_opacity(&ui), 0.5))
	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_IN_SECONDS * 0.5)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Idle)
	testing.expect(t, test_approx_f32(game.app_ui_mode_transition_opacity(&ui), 0))
}

@(test)
test_app_ui_main_menu_to_scene_waits_at_black_until_scene_rendered :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)

	game.app_ui_navigate(&ui, .Particle_Life)
	testing.expect_value(t, ui.mode, game.App_Mode.Main_Menu)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Fade_Out)
	testing.expect_value(t, ui.mode_transition_target, game.App_Mode.Particle_Life)

	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_OUT_SECONDS)
	testing.expect_value(t, ui.mode, game.App_Mode.Particle_Life)
	testing.expect_value(t, ui.previous_mode, game.App_Mode.Main_Menu)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Waiting_For_Target)
	testing.expect(t, test_approx_f32(game.app_ui_mode_transition_opacity(&ui), 1))

	game.app_ui_mode_transition_notify_loaded(&ui)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Fade_In)
	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_IN_SECONDS)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Idle)
}

@(test)
test_app_ui_non_scene_returns_to_main_menu_without_fade :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)
	game.app_ui_navigate(&ui, .Options)
	game.app_ui_navigate(&ui, .Main_Menu)

	testing.expect_value(t, ui.mode, game.App_Mode.Main_Menu)
	testing.expect_value(t, ui.previous_mode, game.App_Mode.Options)
	testing.expect_value(t, ui.mode_transition_phase, game.Mode_Transition_Phase.Idle)
}

@(test)
test_main_menu_backdrop_selects_different_palette_on_reentry :: proc(t: ^testing.T) {
	names := game.color_scheme_available_names_cached()
	if len(names) < 2 {
		testing.expect(t, true)
		return
	}

	backdrop: rendervk.Main_Menu_Backdrop_Gpu_State
	rendervk.main_menu_backdrop_select_next_palette(&backdrop)
	first: game.Color_Scheme_Name
	game.color_scheme_name_set(&first, rendervk.main_menu_backdrop_current_palette_name(&backdrop))
	rendervk.main_menu_backdrop_select_next_palette(&backdrop)
	second := rendervk.main_menu_backdrop_current_palette_name(&backdrop)

	testing.expect(t, game.color_scheme_name_get(&first) != second)
	testing.expect(t, len(game.color_scheme_name_get(&first)) > 0)
	testing.expect(t, len(second) > 0)
}

@(test)
test_main_menu_backdrop_seed_changes_initial_palette_sequence :: proc(t: ^testing.T) {
	names := game.color_scheme_available_names_cached()
	if len(names) < 2 {
		testing.expect(t, true)
		return
	}

	first: rendervk.Main_Menu_Backdrop_Gpu_State
	second: rendervk.Main_Menu_Backdrop_Gpu_State
	rendervk.main_menu_backdrop_seed_palette(&first, 1)
	rendervk.main_menu_backdrop_seed_palette(&second, 2)

	rendervk.main_menu_backdrop_select_next_palette(&first)
	rendervk.main_menu_backdrop_select_next_palette(&second)

	testing.expect(t, rendervk.main_menu_backdrop_current_palette_name(&first) != rendervk.main_menu_backdrop_current_palette_name(&second))
}

@(test)
test_app_ui_main_menu_logo_click_requests_palette_randomize :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: host.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {128, 112}, mouse_pressed = true, mouse_released = true})
	game.app_ui_draw_main_menu(&ui, &ctx, {f32(vk_ctx.swapchain_extent.width), f32(vk_ctx.swapchain_extent.height)}, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ui.main_menu_palette_randomize_requested)
}

@(test)
test_render_backend_consumes_main_menu_palette_randomize_request :: proc(t: ^testing.T) {
	names := game.color_scheme_available_names_cached()
	if len(names) < 2 {
		testing.expect(t, true)
		return
	}

	backend: rendervk.Render_Backend
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)

	rendervk.render_backend_handle_main_menu_palette_requests(&backend, &ui, .Main_Menu)
	first: game.Color_Scheme_Name
	game.color_scheme_name_set(&first, rendervk.main_menu_backdrop_current_palette_name(&backend.main_menu_backdrop))

	ui.main_menu_palette_randomize_requested = true
	rendervk.render_backend_handle_main_menu_palette_requests(&backend, &ui, .Main_Menu)
	second := rendervk.main_menu_backdrop_current_palette_name(&backend.main_menu_backdrop)

	testing.expect(t, !ui.main_menu_palette_randomize_requested)
	testing.expect(t, game.color_scheme_name_get(&first) != second)
}

@(test)
test_main_menu_preview_palette_helper_sets_reversed_scheme :: proc(t: ^testing.T) {
	palette := "MATPLOTLIB_viridis"

	gray_scott := game.gray_scott_default_settings()
	rendervk.render_main_menu_apply_gray_scott_palette(&gray_scott, palette)
	testing.expect_value(t, game.color_scheme_name_get(&gray_scott.color_scheme), palette)
	testing.expect(t, gray_scott.color_scheme_reversed)

	particle_life := game.particle_life_default_settings()
	rendervk.render_main_menu_apply_particle_life_palette(&particle_life, palette)
	testing.expect_value(t, game.color_scheme_name_get(&particle_life.color_scheme), palette)
	testing.expect(t, particle_life.color_scheme_reversed)

	flow := game.flow_settings_default()
	rendervk.render_main_menu_apply_flow_palette(&flow, palette)
	testing.expect_value(t, game.color_scheme_name_get(&flow.color_scheme), palette)
	testing.expect(t, flow.color_scheme_reversed)
}

@(test)
test_main_menu_launch_palette_helper_sets_live_sim_schemes :: proc(t: ^testing.T) {
	palette := "ZELDA_Aqua"
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	defer game.app_ui_destroy(&ui)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, .Slime_Mold, palette))
	test_expect_color_scheme(t, &ui.slime_mold.slime.color_scheme, ui.slime_mold.slime.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, .Gray_Scott, palette))
	test_expect_color_scheme(t, &ui.gray_scott.settings.color_scheme, ui.gray_scott.settings.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, .Particle_Life, palette))
	test_expect_color_scheme(t, &ui.particle_life.settings.color_scheme, ui.particle_life.settings.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, .Flow_Field, palette))
	test_expect_color_scheme(t, &ui.flow_field.flow.color_scheme, ui.flow_field.flow.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, .Pellets, palette))
	test_expect_color_scheme(t, &ui.pellets.pellets.color_scheme, ui.pellets.pellets.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, .Voronoi_CA, palette))
	test_expect_color_scheme(t, &ui.voronoi_ca.voronoi.color_scheme, ui.voronoi_ca.voronoi.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, .Moire, palette))
	test_expect_color_scheme(t, &ui.moire.moire.color_scheme, ui.moire.moire.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, .Vectors, palette))
	test_expect_color_scheme(t, &ui.vectors.vectors.color_scheme, ui.vectors.vectors.color_scheme_reversed, palette, true)
	testing.expect(t, rendervk.render_main_menu_apply_palette_to_mode(&ui, .Primordial, palette))
	test_expect_color_scheme(t, &ui.primordial.primordial.color_scheme, ui.primordial.primordial.color_scheme_reversed, palette, true)
	testing.expect(t, !rendervk.render_main_menu_apply_palette_to_mode(&ui, .Gradient_Editor, palette))
}

@(test)
test_render_worker_main_menu_launch_applies_current_menu_palette_once :: proc(t: ^testing.T) {
	palette := "MATPLOTLIB_viridis"
	runtime := new(host.Render_Worker_Runtime)
	defer free(runtime)
	game.app_ui_init(&runtime.app_ui, game.settings_default())
	defer game.app_ui_destroy(&runtime.app_ui)
	game.color_scheme_name_set(&runtime.render_backend.main_menu_backdrop.palette_name, palette)

	runtime.app_ui.mode = .Flow_Field
	host.render_worker_apply_main_menu_palette_after_navigation(runtime, .Options)
	test_expect_color_scheme(t, &runtime.app_ui.flow_field.flow.color_scheme, runtime.app_ui.flow_field.flow.color_scheme_reversed, "MATPLOTLIB_cubehelix", true)

	host.render_worker_apply_main_menu_palette_after_navigation(runtime, .Main_Menu)
	test_expect_color_scheme(t, &runtime.app_ui.flow_field.flow.color_scheme, runtime.app_ui.flow_field.flow.color_scheme_reversed, palette, true)
}

@(test)
test_render_worker_set_color_scheme_preserves_reversed_when_omitted :: proc(t: ^testing.T) {
	runtime := new(host.Render_Worker_Runtime)
	defer free(runtime)
	game.app_ui_init(&runtime.app_ui, game.settings_default())
	defer game.app_ui_destroy(&runtime.app_ui)

	runtime.app_ui.slime_mold.slime.color_scheme_reversed = false
	testing.expect(t, host.render_worker_set_color_scheme(runtime, .Slime_Mold, "MATPLOTLIB_viridis", false, false))
	test_expect_color_scheme(t, &runtime.app_ui.slime_mold.slime.color_scheme, runtime.app_ui.slime_mold.slime.color_scheme_reversed, "MATPLOTLIB_viridis", false)

	runtime.app_ui.slime_mold.slime.color_scheme_reversed = true
	testing.expect(t, host.render_worker_set_color_scheme(runtime, .Slime_Mold, "ZELDA_Aqua", false, true))
	test_expect_color_scheme(t, &runtime.app_ui.slime_mold.slime.color_scheme, runtime.app_ui.slime_mold.slime.color_scheme_reversed, "ZELDA_Aqua", false)
}

@(test)
test_app_settings_round_trip_options_fields :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_app_settings_roundtrip.toml"
	settings := game.settings_default()
	settings.ui_scale = 1.4
	settings.default_fps_limit = 144
	settings.default_fps_limit_enabled = true
	settings.window_maximized = true
	settings.auto_hide_delay = 4500
	settings.menu_position = "right"
	settings.remember_controller_focus = false
	settings.controller_deadzone = 0.18
	settings.controller_cursor_speed = 1.15
	settings.navigation_repeat_delay_ms = 475
	settings.navigation_repeat_interval_ms = 125
	settings.controller_face_layout = "East Accept"
	settings.controller_menu_layout = "View Pauses"
	settings.controller_shoulder_layout = "Left Next"
	settings.keyboard_shortcut_profile = "Custom"
	settings.keyboard_pause_binding = .P
	settings.keyboard_toggle_ui_binding = .H
	settings.keyboard_help_binding = .U
	settings.default_camera_sensitivity = 2.2
	settings.controller_camera_sensitivity = 1.7
	settings.controller_camera_invert_y = true
	settings.texture_filtering = "Nearest"

	testing.expect(t, game.settings_save_app(path, settings))
	loaded, ok := game.settings_load_app(path)
	testing.expect(t, ok)
	defer delete(loaded.menu_position)
	defer delete(loaded.texture_filtering)
	defer delete(loaded.controller_face_layout)
	defer delete(loaded.controller_menu_layout)
	defer delete(loaded.controller_shoulder_layout)
	defer delete(loaded.controller_trigger_layout)
	defer delete(loaded.keyboard_shortcut_profile)
	defer delete(loaded.preset_directory)
	testing.expect_value(t, loaded.ui_scale, settings.ui_scale)
	testing.expect_value(t, loaded.default_fps_limit, settings.default_fps_limit)
	testing.expect_value(t, loaded.default_fps_limit_enabled, settings.default_fps_limit_enabled)
	testing.expect_value(t, loaded.window_maximized, settings.window_maximized)
	testing.expect_value(t, loaded.auto_hide_delay, settings.auto_hide_delay)
	testing.expect_value(t, loaded.menu_position, settings.menu_position)
	testing.expect_value(t, loaded.remember_controller_focus, settings.remember_controller_focus)
	testing.expect_value(t, loaded.controller_deadzone, settings.controller_deadzone)
	testing.expect_value(t, loaded.controller_cursor_speed, settings.controller_cursor_speed)
	testing.expect_value(t, loaded.navigation_repeat_delay_ms, settings.navigation_repeat_delay_ms)
	testing.expect_value(t, loaded.navigation_repeat_interval_ms, settings.navigation_repeat_interval_ms)
	testing.expect_value(t, loaded.controller_face_layout, settings.controller_face_layout)
	testing.expect_value(t, loaded.controller_menu_layout, settings.controller_menu_layout)
	testing.expect_value(t, loaded.controller_shoulder_layout, settings.controller_shoulder_layout)
	testing.expect_value(t, loaded.keyboard_shortcut_profile, settings.keyboard_shortcut_profile)
	testing.expect_value(t, loaded.keyboard_pause_binding, settings.keyboard_pause_binding)
	testing.expect_value(t, loaded.keyboard_toggle_ui_binding, settings.keyboard_toggle_ui_binding)
	testing.expect_value(t, loaded.keyboard_help_binding, settings.keyboard_help_binding)
	testing.expect_value(t, loaded.default_camera_sensitivity, settings.default_camera_sensitivity)
	testing.expect_value(t, loaded.controller_camera_sensitivity, settings.controller_camera_sensitivity)
	testing.expect_value(t, loaded.controller_camera_invert_y, settings.controller_camera_invert_y)
	testing.expect_value(t, loaded.texture_filtering, settings.texture_filtering)
}

@(test)
test_app_settings_path_uses_user_data_directory :: proc(t: ^testing.T) {
	path := game.settings_app_config_path()
	when ODIN_OS == .Darwin {
		testing.expect(t, strings.contains(path, "/Library/Application Support/Vizza/config/app.toml"))
		testing.expect(t, !strings.contains(path, "VizzaOdin"))
		testing.expect(t, path != "config/app.toml")
	}
	when ODIN_OS == .Windows {
		testing.expect(t, strings.contains(path, "/Vizza/config/app.toml") || path == "config/app.toml")
		testing.expect(t, !strings.contains(path, "VizzaOdin"))
	}
}

@(test)
test_custom_keyboard_binding_config_recovers_from_duplicates_and_reserved_space :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_invalid_keyboard_bindings.toml"
	text := "[input]\nkeyboard_shortcut_profile = \"Custom\"\nkeyboard_pause_binding = \"P\"\nkeyboard_toggle_ui_binding = \"Space\"\nkeyboard_help_binding = \"P\"\n"
	testing.expect(t, os.write_entire_file(path, transmute([]u8)text) == nil)
	loaded, ok := game.settings_load_app(path)
	testing.expect(t, ok)
	defer delete(loaded.keyboard_shortcut_profile)
	testing.expect_value(t, loaded.keyboard_shortcut_profile, "Custom")
	testing.expect(t, game.settings_keyboard_bindings_valid(loaded))
	testing.expect_value(t, loaded.keyboard_pause_binding, game.Keyboard_Shortcut_Key.Space)
	testing.expect_value(t, loaded.keyboard_toggle_ui_binding, game.Keyboard_Shortcut_Key.Slash)
	testing.expect_value(t, loaded.keyboard_help_binding, game.Keyboard_Shortcut_Key.F1)
}

@(test)
test_voronoi_canvas_tools_have_stable_cardinal_slots_and_pairs :: proc(t: ^testing.T) {
	set := game.canvas_tool_set_for_kind(.Voronoi_CA)
	testing.expect_value(t, set.tools[0].name, "Magnet")
	testing.expect_value(t, set.tools[0].primary_action, game.Canvas_Tool_Action.Attract)
	testing.expect_value(t, set.tools[0].secondary_action, game.Canvas_Tool_Action.Repel)
	testing.expect_value(t, set.tools[1].name, "Sites")
	testing.expect_value(t, set.tools[2].name, "Sculpt")
	testing.expect(t, !set.tools[3].valid)
}

@(test)
test_simulation_brush_mode_sets_match_cardinal_design :: proc(t: ^testing.T) {
	slime := game.canvas_tool_set_for_mode(.Slime_Mold)
	testing.expect_value(t, slime.tools[0].name, "Influence")
	testing.expect_value(t, slime.tools[1].name, "Pheromone")
	testing.expect_value(t, slime.tools[2].name, "Agents")
	testing.expect(t, !slime.tools[3].valid)

	gray := game.canvas_tool_set_for_mode(.Gray_Scott)
	testing.expect_value(t, gray.tools[0].name, "Reaction")
	testing.expect_value(t, gray.tools[1].name, "Nutrient")
	testing.expect(t, !gray.tools[2].valid && !gray.tools[3].valid)

	particle := game.canvas_tool_set_for_mode(.Particle_Life)
	testing.expect_value(t, particle.tools[0].name, "Gravity")
	testing.expect_value(t, particle.tools[1].name, "Vortex")
	testing.expect(t, !particle.tools[2].valid)
	testing.expect(t, !particle.tools[3].valid)

	flow := game.canvas_tool_set_for_mode(.Flow_Field)
	testing.expect_value(t, flow.tools[0].name, "Particles")
	testing.expect_value(t, flow.tools[1].name, "Force")
	testing.expect_value(t, flow.tools[2].name, "Flow")

	pellets := game.canvas_tool_set_for_mode(.Pellets)
	testing.expect_value(t, pellets.tools[0].name, "Grab")
	testing.expect_value(t, pellets.tools[1].name, "Gravity")
	testing.expect_value(t, pellets.tools[1].primary_label, "Attract")
	testing.expect_value(t, pellets.tools[1].secondary_label, "Repel")
	testing.expect_value(t, pellets.tools[2].name, "Burst")

	vectors := game.canvas_tool_set_for_mode(.Vectors)
	testing.expect_value(t, vectors.tools[0].name, "Probe")
	testing.expect_value(t, vectors.tools[1].name, "Deflect")
	testing.expect(t, !vectors.tools[2].valid && !vectors.tools[3].valid)

	primordial := game.canvas_tool_set_for_mode(.Primordial)
	testing.expect_value(t, primordial.tools[0].name, "Impulse")
	testing.expect_value(t, primordial.tools[1].name, "Vortex")

	moire := game.canvas_tool_set_for_mode(.Moire)
	for tool in moire.tools {testing.expect(t, !tool.valid)}
}

@(test)
test_brush_mode_actions_map_to_stable_shader_pairs :: proc(t: ^testing.T) {
	set := game.canvas_tool_set_for_mode(.Particle_Life)
	testing.expect_value(t, game.canvas_tool_interaction_mode(&set.tools[0], false), u32(1))
	testing.expect_value(t, game.canvas_tool_interaction_mode(&set.tools[0], true), u32(2))
	testing.expect_value(t, game.canvas_tool_interaction_mode(&set.tools[1], false), u32(3))
	testing.expect_value(t, game.canvas_tool_interaction_mode(&set.tools[1], true), u32(4))

	flow := game.canvas_tool_set_for_mode(.Flow_Field)
	testing.expect_value(t, flow.tools[0].primary_action, game.Canvas_Tool_Action.Spawn_Particles)
	testing.expect_value(t, game.canvas_tool_interaction_mode(&flow.tools[0], false), u32(1))
	testing.expect_value(t, game.canvas_tool_interaction_mode(&flow.tools[0], true), u32(2))

	primordial := game.canvas_tool_set_for_mode(.Primordial)
	testing.expect_value(t, primordial.tools[0].primary_action, game.Canvas_Tool_Action.Impulse_Pull)
	testing.expect_value(t, game.canvas_tool_interaction_mode(&primordial.tools[0], false), u32(1))
	testing.expect_value(t, game.canvas_tool_interaction_mode(&primordial.tools[0], true), u32(2))

	unknown: game.Canvas_Tool_Descriptor
	testing.expect_value(t, game.canvas_tool_interaction_mode(&unknown, false), u32(0))
}

@(test)
test_canvas_tool_dpad_selection_is_direct_and_ignores_empty_slots :: proc(t: ^testing.T) {
	set := game.canvas_tool_set_for_kind(.Voronoi_CA)
	state: game.Canvas_Tool_State
	game.canvas_tool_update_selection(&set, &state, {actions = {navigate = {pressed = {0, -1}}}})
	testing.expect_value(t, state.selected_slot, 1)
	testing.expect(t, state.changed)
	game.canvas_tool_update_selection(&set, &state, {actions = {navigate = {pressed = {1, 0}}}})
	testing.expect_value(t, state.selected_slot, 2)
	game.canvas_tool_update_selection(&set, &state, {actions = {navigate = {pressed = {0, 1}}}})
	testing.expect_value(t, state.selected_slot, 2)
	testing.expect(t, !state.changed)
}

@(test)
test_canvas_tool_number_shortcuts_select_slots_directly :: proc(t: ^testing.T) {
	set := game.canvas_tool_set_for_kind(.Voronoi_CA)
	state: game.Canvas_Tool_State
	game.canvas_tool_update_selection(&set, &state, {canvas_tool_slot = 3})
	testing.expect_value(t, state.selected_slot, 2)
	testing.expect(t, state.changed)
	game.canvas_tool_update_selection(&set, &state, {canvas_tool_slot = 4})
	testing.expect_value(t, state.selected_slot, 2)
	testing.expect(t, !state.changed)
}

@(test)
test_particle_life_force_generator_dispatch_matches_strategy_families :: proc(t: ^testing.T) {
	for generator: u32 = 0; generator <= 21; generator += 1 {
		dispatched: [game.PARTICLE_LIFE_MAX_SPECIES * game.PARTICLE_LIFE_MAX_SPECIES]f32
		direct: [game.PARTICLE_LIFE_MAX_SPECIES * game.PARTICLE_LIFE_MAX_SPECIES]f32
		seed := u32(0x51f15e + generator * 97)
		game.particle_life_generate_force_matrix(&dispatched, 7, generator, -0.75, 0.65, seed)
		direct_seed := seed
		if generator >= 1 && generator <= 6 {
			_ = game.particle_life_generate_force_classic(&direct, 7, generator, &direct_seed, -0.75, 0.65)
		} else if generator >= 7 && generator <= 13 {
			_ = game.particle_life_generate_force_structured(&direct, 7, generator, &direct_seed, -0.75, 0.65)
		} else {
			_ = game.particle_life_generate_force_numeric(&direct, 7, generator, &direct_seed, -0.75, 0.65)
		}
		for value, index in dispatched {
			testing.expect_value(t, value, direct[index])
		}
	}
}

@(test)
test_refactored_dispatch_families_reject_unknown_inputs :: proc(t: ^testing.T) {
	bridge := new(host.Mcp_Bridge)
	defer free(bridge)
	_, handled := host.mcp_bridge_call_application_tool(bridge, "1", "not_a_tool", "{}")
	testing.expect(t, !handled)
	state := new(host.Render_Worker_State)
	defer free(state)
	runtime := new(host.Render_Worker_Runtime)
	defer free(runtime)
	command := host.Ui_To_Render_Command{kind = game.Ui_To_Render_Command_Kind(999)}
	testing.expect(t, !host.render_worker_handle_lifecycle_command(state, runtime, command))
	testing.expect(t, !host.render_worker_handle_settings_command(state, runtime, command))
	testing.expect(t, !host.render_worker_handle_recording_command(state, runtime, command))
	invalid_preset := host.Feature_Preset_File_Command {
		operation = game.Feature_Preset_File_Operation(255),
	}
	testing.expect(t, !host.render_worker_handle_preset_file_command(state, runtime, .Gray_Scott, invalid_preset))
}

@(test)
test_resource_size_arithmetic_rejects_overflow :: proc(t: ^testing.T) {
	value, ok := engine.checked_mul_u64(max(u64), 2)
	testing.expect(t, !ok)
	testing.expect_value(t, value, u64(0))
	value, ok = engine.checked_add_u64(max(u64), 1)
	testing.expect(t, !ok)
	testing.expect_value(t, value, u64(0))
	value, ok = engine.checked_mul_u64(4096, 4096)
	testing.expect(t, ok)
	testing.expect_value(t, value, u64(16_777_216))
}

@(test)
test_webcam_frame_rgba_rejects_non_positive_dimensions :: proc(t: ^testing.T) {
	testing.expect(t, rendervk.webcam_frame_rgba(nil, 0, 64, .Center, false, false, false) == nil)
	testing.expect(t, rendervk.webcam_frame_rgba(nil, 64, -1, .Center, false, false, false) == nil)
}

@(test)
test_gpu_heap_admission_preserves_headroom :: proc(t: ^testing.T) {
	heap := engine.Gpu_Memory_Heap{usage = 500, ceiling = 1000}
	available, ok := engine.gpu_heap_allocation_fits(heap, 400, 100)
	testing.expect(t, ok)
	testing.expect_value(t, available, u64(500))
	_, ok = engine.gpu_heap_allocation_fits(heap, 401, 100)
	testing.expect(t, !ok)
	_, ok = engine.gpu_heap_allocation_fits(engine.Gpu_Memory_Heap{usage = 1000, ceiling = 1000}, 1, 0)
	testing.expect(t, !ok)
}
