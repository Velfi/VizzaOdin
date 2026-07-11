package render_vk

import engine "../engine"
import uifw "../ui"

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import vk "vendor:vulkan"

particle_life_update_descriptors :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	for frame_slot in 0 ..< engine.MAX_FRAMES_IN_FLIGHT {
		particle_life_update_descriptors_for_slot(sim, vk_ctx, frame_slot)
	}
}

particle_life_update_descriptors_for_slot :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	particle_info := vk.DescriptorBufferInfo{buffer = sim.gpu.particle_buffer.handle, offset = 0, range = sim.gpu.particle_buffer.size}
	particle_scratch_info := vk.DescriptorBufferInfo{buffer = sim.gpu.particle_scratch_buffer.handle, offset = 0, range = sim.gpu.particle_scratch_buffer.size}
	force_cache_info := vk.DescriptorBufferInfo{buffer = sim.gpu.force_cache_buffer.handle, offset = 0, range = sim.gpu.force_cache_buffer.size}
	params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Params))}
	grid_heads_info := vk.DescriptorBufferInfo{buffer = sim.gpu.grid_heads_buffer.handle, offset = 0, range = sim.gpu.grid_heads_buffer.size}
	particle_next_info := vk.DescriptorBufferInfo{buffer = sim.gpu.particle_next_buffer.handle, offset = 0, range = sim.gpu.particle_next_buffer.size}
	grid_offsets_info := vk.DescriptorBufferInfo{buffer = sim.gpu.grid_offsets_buffer.handle, offset = 0, range = sim.gpu.grid_offsets_buffer.size}
	grid_cursors_info := vk.DescriptorBufferInfo{buffer = sim.gpu.grid_cursors_buffer.handle, offset = 0, range = sim.gpu.grid_cursors_buffer.size}
	grid_block_sums_info := vk.DescriptorBufferInfo{buffer = sim.gpu.grid_block_sums_buffer.handle, offset = 0, range = sim.gpu.grid_block_sums_buffer.size}
	grid_params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.grid_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Grid_Params))}
	collision_grid_params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.collision_grid_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Grid_Params))}
	collision_correction_info := vk.DescriptorBufferInfo{buffer = sim.gpu.collision_correction_buffer.handle, offset = 0, range = sim.gpu.collision_correction_buffer.size}
	collision_params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.collision_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Collision_Params))}
	init_params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.init_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Init_Params))}
	force_info := vk.DescriptorBufferInfo{buffer = sim.gpu.force_matrix_buffer.handle, offset = 0, range = sim.gpu.force_matrix_buffer.size}
	color_info := vk.DescriptorBufferInfo{buffer = sim.gpu.color_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Species_Colors))}
	mode_info := vk.DescriptorBufferInfo{buffer = sim.gpu.color_mode_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Color_Mode_Params))}
	camera_info := vk.DescriptorBufferInfo{buffer = sim.gpu.camera_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Camera))}
	viewport_info := vk.DescriptorBufferInfo{buffer = sim.gpu.viewport_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Viewport))}
	force_randomize_info := vk.DescriptorBufferInfo{buffer = sim.gpu.force_randomize_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Force_Randomize_Params))}
	force_update_info := vk.DescriptorBufferInfo{buffer = sim.gpu.force_update_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Force_Update_Params))}
	analysis_params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Analysis_Params))}
	analysis_cells_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_cells_buffer.handle, offset = 0, range = sim.gpu.analysis_cells_buffer.size}
	analysis_coherence_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_coherence_buffer.handle, offset = 0, range = sim.gpu.analysis_coherence_buffer.size}
	analysis_labels_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_labels_buffer.handle, offset = 0, range = sim.gpu.analysis_labels_buffer.size}
	analysis_tile_components_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_tile_components_buffer.handle, offset = 0, range = sim.gpu.analysis_tile_components_buffer.size}
	analysis_parent_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_parent_buffer.handle, offset = 0, range = sim.gpu.analysis_parent_buffer.size}
	analysis_blob_summaries_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_blob_summaries_buffer.handle, offset = 0, range = sim.gpu.analysis_blob_summaries_buffer.size}
	analysis_blob_count_info := vk.DescriptorBufferInfo{buffer = sim.gpu.analysis_blob_count_buffer.handle, offset = 0, range = sim.gpu.analysis_blob_count_buffer.size}
	sim_set := sim.gpu.sim_sets[frame_slot]
	collision_set := sim.gpu.collision_sets[frame_slot]
	init_set := sim.gpu.init_sets[frame_slot]
	color_set := sim.gpu.color_sets[frame_slot]
	view_set := sim.gpu.view_sets[frame_slot]
	force_randomize_set := sim.gpu.force_randomize_sets[frame_slot]
	force_update_set := sim.gpu.force_update_sets[frame_slot]
	analysis_set := sim.gpu.analysis_sets[frame_slot]
	writes := [46]vk.WriteDescriptorSet {
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &force_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_heads_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_next_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 5, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &grid_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 6, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_scratch_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 7, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &collision_correction_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 8, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &collision_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 9, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_offsets_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 10, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_cursors_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 11, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_block_sums_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = sim_set, dstBinding = 12, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &force_cache_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = collision_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = collision_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = collision_set, dstBinding = 2, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &force_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = collision_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_heads_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = collision_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_next_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = collision_set, dstBinding = 5, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &collision_grid_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = collision_set, dstBinding = 6, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_scratch_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = collision_set, dstBinding = 7, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &collision_correction_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = collision_set, dstBinding = 8, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &collision_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = collision_set, dstBinding = 9, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_offsets_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = collision_set, dstBinding = 10, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_cursors_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = collision_set, dstBinding = 11, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &grid_block_sums_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = collision_set, dstBinding = 12, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &force_cache_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = init_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = init_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &init_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = color_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &color_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = color_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &mode_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = view_set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &camera_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = view_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &viewport_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = force_randomize_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &force_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = force_randomize_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &force_randomize_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = force_update_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &force_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = force_update_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &force_update_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 0, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &particle_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 1, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 3, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_cells_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 4, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_coherence_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 5, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_labels_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 6, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_tile_components_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 7, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_parent_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 8, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_blob_summaries_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = analysis_set, dstBinding = 9, descriptorType = .STORAGE_BUFFER, descriptorCount = 1, pBufferInfo = &analysis_blob_count_info},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
}

particle_life_upload_force_matrix :: proc(sim: ^Particle_Life_Simulation) {
	if sim.gpu.force_matrix_buffer.mapped == nil {
		return
	}
	species_count := int(max(sim.gpu.uploaded_species_count, 1))
	forces := cast([^]f32)sim.gpu.force_matrix_buffer.mapped
	generated_matrix: [PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32
	if !sim.settings.custom_force_matrix {
		particle_life_generate_force_matrix(&generated_matrix, u32(species_count), sim.settings.force_generator, sim.settings.force_random_min, sim.settings.force_random_max, sim.runtime.seed)
	}
	for a in 0 ..< species_count {
		for b in 0 ..< species_count {
			v: f32
			if sim.settings.custom_force_matrix {
				v = sim.settings.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b]
			} else {
				v = generated_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b]
			}
			forces[a * species_count + b] = v
			sim.runtime.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = v
			sim.settings.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = v
		}
	}
	sim.settings.custom_force_matrix = true
	sim.runtime.force_matrix_dirty = false
}


particle_life_upload_static_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.color_buffers[frame_slot].mapped != nil {
		colors := cast(^Particle_Life_Species_Colors)sim.gpu.color_buffers[frame_slot].mapped
		colors^ = {}
		scheme_name := color_scheme_name_get(&sim.settings.color_scheme)
		scheme, ok := color_scheme_load(scheme_name)
		if !ok {
			scheme = color_scheme_default()
		}
		if sim.settings.color_scheme_reversed {
			color_scheme_reverse(&scheme)
		}
		species_count := int(particle_life_target_species_count(sim.settings))
		for i in 0 ..< PARTICLE_LIFE_MAX_SPECIES {
			t := 0
			if sim.settings.background_color_mode == .Color_Scheme && species_count > 0 {
				t = int(((i + 1) * (COLOR_SCHEME_SIZE - 1)) / species_count)
			} else if PARTICLE_LIFE_MAX_SPECIES > 1 {
				t = int((i * (COLOR_SCHEME_SIZE - 1)) / (PARTICLE_LIFE_MAX_SPECIES - 1))
			}
			t = max(min(t, COLOR_SCHEME_SIZE - 1), 0)
			colors.colors[i] = {
				f32(scheme.red[t]) / 255.0,
				f32(scheme.green[t]) / 255.0,
				f32(scheme.blue[t]) / 255.0,
				1,
			}
		}
		colors.colors[PARTICLE_LIFE_MAX_SPECIES] = particle_life_background_color(&sim.settings)
	}
	if sim.gpu.color_mode_buffers[frame_slot].mapped != nil {
		mode := cast(^Particle_Life_Color_Mode_Params)sim.gpu.color_mode_buffers[frame_slot].mapped
		mode^ = {
			mode = u32(sim.settings.color_mode),
			brightness = sim.settings.brightness,
			contrast = sim.settings.contrast,
			saturation = sim.settings.saturation,
			gamma = max(sim.settings.gamma, 0.01),
		}
	}
}

particle_life_write_init_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.init_params_buffers[frame_slot].mapped == nil {
		return
	}
	world_size := particle_life_world_size(sim)
	params := cast(^Particle_Life_Init_Params)sim.gpu.init_params_buffers[frame_slot].mapped
	params^ = {
		start_index = 0,
		spawn_count = sim.gpu.uploaded_particle_count,
		species_count = sim.gpu.uploaded_species_count,
		width = world_size[0],
		height = world_size[1],
		random_seed = sim.runtime.seed,
		position_generator = sim.settings.position_generator,
		type_generator = sim.settings.type_generator,
	}
}

particle_life_write_frame_uniforms :: proc(sim: ^Particle_Life_Simulation, dt: f32) {
	frame_slot := sim.gpu.active_frame_slot
	particle_life_upload_static_uniforms(sim)
	width := f32(max(sim.gpu.width, 1))
	height := f32(max(sim.gpu.height, 1))
	aspect := width / max(height, 1)
	world_size := particle_life_world_size_for_viewport(width, height)
	bounds := particle_life_view_bounds(sim, width, height)
	if sim.gpu.params_buffers[frame_slot].mapped != nil {
		params := cast(^Particle_Life_Params)sim.gpu.params_buffers[frame_slot].mapped
		params^ = {
			particle_count = sim.gpu.uploaded_particle_count,
			species_count = sim.gpu.uploaded_species_count,
			max_force = sim.settings.max_force,
			max_distance = sim.settings.max_distance,
			friction = sim.settings.friction,
			wrap_edges = sim.settings.wrap_edges ? 1 : 0,
			width = world_size[0],
			height = world_size[1],
			random_seed = sim.runtime.seed + u32(sim.runtime.frame_index & 0xffffffff),
			dt = min(max(dt, 0.0), 0.033),
			beta = sim.settings.beta,
			cursor_x = sim.runtime.cursor_x,
			cursor_y = sim.runtime.cursor_y,
			cursor_size = sim.settings.cursor_size,
			cursor_strength = sim.settings.cursor_strength,
			cursor_active = sim.runtime.cursor_active,
			brownian_motion = sim.settings.brownian_motion,
			particle_size = sim.settings.particle_size,
			aspect_ratio = aspect,
			force_refresh_stride = particle_life_force_refresh_stride(sim.settings),
			force_sample_limit = particle_life_force_sample_limit(sim.settings),
		}
	}
	if sim.gpu.camera_buffers[frame_slot].mapped != nil {
		zoom := max(sim.runtime.camera_zoom, CAMERA_MIN_ZOOM)
		camera := cast(^Particle_Life_Camera)sim.gpu.camera_buffers[frame_slot].mapped
		camera^ = {
			transform_matrix = {
				zoom, 0, 0, 0,
				0, zoom, 0, 0,
				0, 0, 1, 0,
				-sim.runtime.camera_x * zoom, -sim.runtime.camera_y * zoom, 0, 1,
			},
			position = {sim.runtime.camera_x, sim.runtime.camera_y},
			zoom = zoom,
			aspect_ratio = aspect,
		}
	}
	if sim.gpu.viewport_buffers[frame_slot].mapped != nil {
		particle_life_write_viewport_uniforms(sim, width, height, bounds)
	}
}

particle_life_write_viewport_uniforms :: proc(sim: ^Particle_Life_Simulation, width, height: f32, bounds: [4]f32) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.viewport_buffers[frame_slot].mapped == nil {
		return
	}
	viewport := cast(^Particle_Life_Viewport)sim.gpu.viewport_buffers[frame_slot].mapped
	viewport^ = {
		world_bounds = bounds,
		texture_size = {width, height},
	}
}

particle_life_push_viewport_uniform_mode :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Graphics_Pipeline) {
	_ = vk_ctx
	push := Particle_Life_Viewport_Push{}
	vk.CmdPushConstants(cmd, pipeline.layout, {.VERTEX}, 0, u32(size_of(Particle_Life_Viewport_Push)), &push)
}

particle_life_push_viewport_bounds :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Graphics_Pipeline, bounds: [4]f32) {
	_ = vk_ctx
	push := Particle_Life_Viewport_Push{world_bounds = bounds, enabled = 1}
	vk.CmdPushConstants(cmd, pipeline.layout, {.VERTEX}, 0, u32(size_of(Particle_Life_Viewport_Push)), &push)
}

particle_life_push_wrapped_viewport_mode :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Graphics_Pipeline) {
	_ = vk_ctx
	push := Particle_Life_Viewport_Push{enabled = 2}
	vk.CmdPushConstants(cmd, pipeline.layout, {.VERTEX}, 0, u32(size_of(Particle_Life_Viewport_Push)), &push)
}

particle_life_write_grid_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.grid_params_buffers[frame_slot].mapped == nil {
		return
	}
	world_size := particle_life_world_size(sim)
	cell_w := world_size[0] / f32(max(sim.gpu.grid_width, 1))
	cell_h := world_size[1] / f32(max(sim.gpu.grid_height, 1))
	params := cast(^Particle_Life_Grid_Params)sim.gpu.grid_params_buffers[frame_slot].mapped
	params^ = {
		particle_count = sim.gpu.uploaded_particle_count,
		grid_width = sim.gpu.grid_width,
		grid_height = sim.gpu.grid_height,
		neighbor_radius_cells = sim.gpu.neighbor_radius_cells,
		cell_size = max(cell_w, cell_h),
		world_min_x = -world_size[0] * 0.5,
		world_min_y = -world_size[1] * 0.5,
		world_width = world_size[0],
		world_height = world_size[1],
	}
}

particle_life_write_collision_grid_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.collision_grid_params_buffers[frame_slot].mapped == nil {
		return
	}
	world_size := particle_life_world_size(sim)
	cell_w := world_size[0] / f32(max(sim.gpu.collision_grid_width, 1))
	cell_h := world_size[1] / f32(max(sim.gpu.collision_grid_height, 1))
	params := cast(^Particle_Life_Grid_Params)sim.gpu.collision_grid_params_buffers[frame_slot].mapped
	params^ = {
		particle_count = sim.gpu.uploaded_particle_count,
		grid_width = sim.gpu.collision_grid_width,
		grid_height = sim.gpu.collision_grid_height,
		neighbor_radius_cells = 1,
		cell_size = max(cell_w, cell_h),
		world_min_x = -world_size[0] * 0.5,
		world_min_y = -world_size[1] * 0.5,
		world_width = world_size[0],
		world_height = world_size[1],
		_pad0 = 1,
	}
}

particle_life_write_collision_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.collision_params_buffers[frame_slot].mapped == nil {
		return
	}
	min_distance := particle_life_collision_distance(sim.settings)
	params := cast(^Particle_Life_Collision_Params)sim.gpu.collision_params_buffers[frame_slot].mapped
	params^ = {
		enabled = sim.settings.collision_enabled ? 1 : 0,
		iterations = max(min(sim.settings.collision_iterations, 8), 1),
		min_distance = min_distance,
		relaxation = max(min(sim.settings.collision_relaxation, 1.0), 0.0),
		max_correction = min_distance * 0.25,
		velocity_damping = max(min(sim.settings.collision_damping, 1.0), 0.0),
	}
}

particle_life_write_analysis_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.analysis_params_buffers[frame_slot].mapped != nil {
		params := cast(^Particle_Life_Analysis_Params)sim.gpu.analysis_params_buffers[frame_slot].mapped
		params^ = {
			enabled = sim.settings.analysis_enabled ? 1 : 0,
			interval_frames = max(sim.settings.analysis_interval_frames, 1),
			grid_size = max(sim.gpu.analysis_grid_axis, 1),
			min_blob_area_cells = max(sim.settings.min_blob_area_cells, 1),
			coherence_threshold = sim.settings.coherence_threshold,
		}
	}
	if sim.gpu.selected_blob_params_buffers[frame_slot].mapped != nil {
		params := cast(^Particle_Life_Selected_Blob_Params)sim.gpu.selected_blob_params_buffers[frame_slot].mapped
		params^ = {
			selected_blob_id = sim.runtime.selected_blob_id,
			overlay_enabled = sim.settings.blob_overlay_enabled ? 1 : 0,
		}
	}
}

particle_life_write_fade_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.fade_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Particle_Life_Fade_Params)sim.gpu.fade_params_buffers[frame_slot].mapped
	params^ = {
		fade_amount = max(min(sim.settings.trail_fade_amount, 1.0), 0.0),
	}
}

particle_life_write_background_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.background_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Particle_Life_Background_Params)sim.gpu.background_params_buffers[frame_slot].mapped
	params^ = {background_color = particle_life_background_color(&sim.settings)}
}

particle_life_write_post_uniforms :: proc(sim: ^Particle_Life_Simulation) {
	frame_slot := sim.gpu.active_frame_slot
	if sim.gpu.post_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Particle_Life_Post_Params)sim.gpu.post_params_buffers[frame_slot].mapped
	params^ = {
		brightness = sim.settings.brightness,
		contrast = sim.settings.contrast,
		saturation = sim.settings.saturation,
		gamma = max(sim.settings.gamma, 0.01),
	}
}

particle_life_dispatch_init :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	particle_life_write_init_uniforms(sim)
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.init_pipeline.pipeline)
	init_set := sim.gpu.init_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.init_pipeline.layout, 0, 1, &init_set, 0, nil)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	barrier := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = {.SHADER_READ, .SHADER_WRITE},
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = sim.gpu.particle_buffer.handle,
		offset = 0,
		size = sim.gpu.particle_buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.COMPUTE_SHADER, .VERTEX_SHADER}, {}, 0, nil, 1, &barrier, 0, nil)
	sim.runtime.needs_reset = false
}

particle_life_force_barrier :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	barrier := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = {.SHADER_READ, .SHADER_WRITE},
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = sim.gpu.force_matrix_buffer.handle,
		offset = 0,
		size = sim.gpu.force_matrix_buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.COMPUTE_SHADER}, {}, 0, nil, 1, &barrier, 0, nil)
}

particle_life_buffer_barrier :: proc(vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, buffer: engine.Vk_Buffer, dst_stage: vk.PipelineStageFlags, dst_access: vk.AccessFlags) {
	barrier := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = dst_access,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = buffer.handle,
		offset = 0,
		size = buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, dst_stage, {}, 0, nil, 1, &barrier, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

particle_life_grid_barrier :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dst_stage: vk.PipelineStageFlags, dst_access: vk.AccessFlags) {
	barriers := [5]vk.BufferMemoryBarrier {
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.grid_heads_buffer.handle, offset = 0, size = sim.gpu.grid_heads_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.particle_next_buffer.handle, offset = 0, size = sim.gpu.particle_next_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.grid_offsets_buffer.handle, offset = 0, size = sim.gpu.grid_offsets_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.grid_cursors_buffer.handle, offset = 0, size = sim.gpu.grid_cursors_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.grid_block_sums_buffer.handle, offset = 0, size = sim.gpu.grid_block_sums_buffer.size},
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, dst_stage, {}, 0, nil, u32(len(barriers)), raw_data(barriers[:]), 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx, u32(len(barriers)))
}

particle_life_copy_scratch_to_particles_transfer :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	to_transfer := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = {.TRANSFER_READ},
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = sim.gpu.particle_scratch_buffer.handle,
		offset = 0,
		size = sim.gpu.particle_scratch_buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, {.TRANSFER}, {}, 0, nil, 1, &to_transfer, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	region := vk.BufferCopy {
		srcOffset = 0,
		dstOffset = 0,
		size = min(sim.gpu.particle_scratch_buffer.size, sim.gpu.particle_buffer.size),
	}
	vk.CmdCopyBuffer(cmd, sim.gpu.particle_scratch_buffer.handle, sim.gpu.particle_buffer.handle, 1, &region)
	engine.vk_cmd_count_transfer_copy(vk_ctx)
	to_vertex := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.TRANSFER_WRITE},
		dstAccessMask = {.SHADER_READ},
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = sim.gpu.particle_buffer.handle,
		offset = 0,
		size = sim.gpu.particle_buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.TRANSFER}, {.VERTEX_SHADER, .COMPUTE_SHADER}, {}, 0, nil, 1, &to_vertex, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

particle_life_copy_scratch_to_particles :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	if sim.gpu.copy_scratch_pipeline.pipeline == vk.Pipeline(0) {
		particle_life_copy_scratch_to_particles_transfer(sim, vk_ctx, cmd)
		return
	}
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.copy_scratch_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.copy_scratch_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_buffer_barrier(vk_ctx, cmd, sim.gpu.particle_buffer, {.VERTEX_SHADER, .COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_grid_clear :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, collision := false) {
	if collision { particle_life_write_collision_grid_uniforms(sim) } else { particle_life_write_grid_uniforms(sim) }
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.grid_clear_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := collision ? sim.gpu.collision_sets[sim.gpu.active_frame_slot] : sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.grid_clear_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	cells := collision ? sim.gpu.collision_grid_width * sim.gpu.collision_grid_height : sim.gpu.grid_width * sim.gpu.grid_height
	group_x := u32((cells + PARTICLE_LIFE_GRID_CLEAR_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_GRID_CLEAR_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_grid_barrier(sim, vk_ctx, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_grid_scatter :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.grid_scatter_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.grid_scatter_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_grid_barrier(sim, vk_ctx, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_grid_prefix :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.grid_prefix_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.grid_prefix_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	cell_count := sim.gpu.grid_width * sim.gpu.grid_height
	block_count := max((cell_count + 255) / 256, 1)
	vk.CmdDispatch(cmd, block_count, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_grid_barrier(sim, vk_ctx, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.grid_prefix_blocks_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.grid_prefix_blocks_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, 1, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_grid_barrier(sim, vk_ctx, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.grid_prefix_add_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.grid_prefix_add_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	vk.CmdDispatch(cmd, block_count, 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_grid_barrier(sim, vk_ctx, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_grid_index_scatter :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.grid_index_scatter_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.grid_index_scatter_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_grid_barrier(sim, vk_ctx, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_grid_scatter_predicted :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.grid_scatter_predicted_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.collision_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.grid_scatter_predicted_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_grid_barrier(sim, vk_ctx, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_binned_compute :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.compute_binned_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.sim_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.compute_binned_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_buffer_barrier(vk_ctx, cmd, sim.gpu.particle_scratch_buffer, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
	particle_life_buffer_barrier(vk_ctx, cmd, sim.gpu.force_cache_buffer, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_clear_force_cache :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdFillBuffer(cmd, sim.gpu.force_cache_buffer.handle, 0, sim.gpu.force_cache_buffer.size, 0)
	barrier := vk.BufferMemoryBarrier {
		sType = .BUFFER_MEMORY_BARRIER,
		srcAccessMask = {.TRANSFER_WRITE},
		dstAccessMask = {.SHADER_READ, .SHADER_WRITE},
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer = sim.gpu.force_cache_buffer.handle,
		offset = 0,
		size = sim.gpu.force_cache_buffer.size,
	}
	vk.CmdPipelineBarrier(cmd, {.TRANSFER}, {.COMPUTE_SHADER}, {}, 0, nil, 1, &barrier, 0, nil)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
}

particle_life_dispatch_collision_solve :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.collision_solve_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.collision_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.collision_solve_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_buffer_barrier(vk_ctx, cmd, sim.gpu.collision_correction_buffer, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_collision_apply :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	vk.CmdBindPipeline(cmd, .COMPUTE, sim.gpu.collision_apply_pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	sim_set := sim.gpu.collision_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, sim.gpu.collision_apply_pipeline.layout, 0, 1, &sim_set, 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	group_x := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	vk.CmdDispatch(cmd, max(group_x, 1), 1, 1)
	engine.vk_cmd_count_compute_dispatch(vk_ctx)
	particle_life_buffer_barrier(vk_ctx, cmd, sim.gpu.particle_scratch_buffer, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}
