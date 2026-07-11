package render_vk

import engine "../engine"
import uifw "../ui"

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import vk "vendor:vulkan"

particle_life_dispatch_collision_solver :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer) {
	particle_life_write_collision_uniforms(sim)
	if !sim.settings.collision_enabled {
		return
	}
	particle_life_dispatch_grid_clear(sim, vk_ctx, cmd, true)
	particle_life_dispatch_grid_scatter_predicted(sim, vk_ctx, cmd)
	iterations := max(min(sim.settings.collision_iterations, 8), 1)
	for iteration: u32 = 0; iteration < iterations; iteration += 1 {
		particle_life_dispatch_collision_solve(sim, vk_ctx, cmd)
		particle_life_dispatch_collision_apply(sim, vk_ctx, cmd)
	}
}

particle_life_analysis_frame_due :: proc(sim: ^Particle_Life_Simulation) -> bool {
	if !sim.settings.analysis_enabled {
		return false
	}
	interval := u64(max(sim.settings.analysis_interval_frames, 1))
	return sim.runtime.frame_index != sim.runtime.last_analysis_frame && (sim.runtime.frame_index % interval) == 0
}

particle_life_analysis_gpu_ready :: proc(sim: ^Particle_Life_Simulation) -> bool {
	return sim.gpu.analysis_sets[sim.gpu.active_frame_slot] != vk.DescriptorSet(0) &&
		sim.gpu.analysis_clear_pipeline.pipeline != vk.Pipeline(0) &&
		sim.gpu.analysis_blob_count_buffer.mapped != nil &&
		sim.gpu.analysis_blob_summaries_buffer.mapped != nil
}

particle_life_analysis_barrier :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer, dst_stage: vk.PipelineStageFlags, dst_access: vk.AccessFlags) {
	barriers := [7]vk.BufferMemoryBarrier {
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_cells_buffer.handle, offset = 0, size = sim.gpu.analysis_cells_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_coherence_buffer.handle, offset = 0, size = sim.gpu.analysis_coherence_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_labels_buffer.handle, offset = 0, size = sim.gpu.analysis_labels_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_tile_components_buffer.handle, offset = 0, size = sim.gpu.analysis_tile_components_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_parent_buffer.handle, offset = 0, size = sim.gpu.analysis_parent_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_blob_summaries_buffer.handle, offset = 0, size = sim.gpu.analysis_blob_summaries_buffer.size},
		{sType = .BUFFER_MEMORY_BARRIER, srcAccessMask = {.SHADER_WRITE}, dstAccessMask = dst_access, srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, buffer = sim.gpu.analysis_blob_count_buffer.handle, offset = 0, size = sim.gpu.analysis_blob_count_buffer.size},
	}
	vk.CmdPipelineBarrier(cmd, {.COMPUTE_SHADER}, dst_stage, {}, 0, nil, u32(len(barriers)), raw_data(barriers[:]), 0, nil)
}

particle_life_dispatch_analysis_pipeline :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Compute_Pipeline, groups_x, groups_y: u32) {
	vk.CmdBindPipeline(cmd, .COMPUTE, pipeline.pipeline)
	analysis_set := sim.gpu.analysis_sets[sim.gpu.active_frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, pipeline.layout, 0, 1, &analysis_set, 0, nil)
	vk.CmdDispatch(cmd, max(groups_x, 1), max(groups_y, 1), 1)
	particle_life_analysis_barrier(sim, cmd, {.COMPUTE_SHADER}, {.SHADER_READ, .SHADER_WRITE})
}

particle_life_dispatch_gpu_blob_analysis :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	if !particle_life_analysis_frame_due(sim) || !particle_life_analysis_gpu_ready(sim) {
		return
	}
	particle_life_write_analysis_uniforms(sim)
	axis := max(sim.gpu.analysis_grid_axis, 1)
	cells := axis * axis
	particle_groups := u32((sim.gpu.uploaded_particle_count + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	cell_groups := u32((cells + PARTICLE_LIFE_WORKGROUP_SIZE - 1) / PARTICLE_LIFE_WORKGROUP_SIZE)
	tile_count := max(sim.gpu.analysis_tile_count, 1)

	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_clear_pipeline, cell_groups, 1)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_scatter_pipeline, particle_groups, 1)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_coherence_pipeline, cell_groups, 1)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_tile_label_pipeline, tile_count, tile_count)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_tile_merge_pipeline, cell_groups, 1)
	particle_life_dispatch_analysis_pipeline(sim, cmd, &sim.gpu.analysis_summarize_pipeline, cell_groups, 1)
	particle_life_analysis_barrier(sim, cmd, {.HOST}, {.HOST_READ})
	sim.runtime.last_analysis_frame = sim.runtime.frame_index
}

particle_life_read_gpu_blob_analysis :: proc(sim: ^Particle_Life_Simulation) {
	if !particle_life_analysis_frame_due(sim) || sim.runtime.last_analysis_frame == 0 || sim.runtime.last_analysis_read_frame == sim.runtime.last_analysis_frame || !particle_life_analysis_gpu_ready(sim) {
		return
	}
	count_ptr := cast(^u32)sim.gpu.analysis_blob_count_buffer.mapped
	accumulators := cast([^]Particle_Life_Blob_Accumulator)sim.gpu.analysis_blob_summaries_buffer.mapped
	raw_count := min(count_ptr^, PARTICLE_LIFE_ANALYSIS_MAX_BLOBS)
	summaries: [PARTICLE_LIFE_ANALYSIS_MAX_BLOBS]Particle_Life_Blob_Summary
	out_count: u32
	axis := max(sim.gpu.analysis_grid_axis, 1)
	world_size := particle_life_world_size(sim)
	cell_w := world_size[0] / f32(axis)
	cell_h := world_size[1] / f32(axis)
	world_min_x := -world_size[0] * 0.5
	world_min_y := -world_size[1] * 0.5
	for i: u32 = 0; i < raw_count; i += 1 {
		acc := accumulators[i]
		if acc.area < max(sim.settings.min_blob_area_cells, 1) || acc.density == 0 {
			continue
		}
		summary: Particle_Life_Blob_Summary
		summary.id = acc.id
		summary.area = acc.area
		summary.density = f32(acc.density)
		inv_density := 1.0 / max(f32(acc.density), 1.0)
		summary.centroid = {
			(f32(acc.centroid_sum[0]) / PARTICLE_LIFE_ANALYSIS_COORD_SCALE) * inv_density,
			(f32(acc.centroid_sum[1]) / PARTICLE_LIFE_ANALYSIS_COORD_SCALE) * inv_density,
		}
		summary.velocity = {
			(f32(acc.velocity_sum[0]) / PARTICLE_LIFE_ANALYSIS_VELOCITY_SCALE) * inv_density,
			(f32(acc.velocity_sum[1]) / PARTICLE_LIFE_ANALYSIS_VELOCITY_SCALE) * inv_density,
		}
		summary.bounds = {
			world_min_x + f32(acc.bounds_min[0]) * cell_w,
			world_min_y + f32(acc.bounds_min[1]) * cell_h,
			world_min_x + f32(acc.bounds_max[0] + 1) * cell_w,
			world_min_y + f32(acc.bounds_max[1] + 1) * cell_h,
		}
		summary.coherence_score = (f32(acc.coherence_sum) / PARTICLE_LIFE_ANALYSIS_COHERENCE_SCALE) / f32(max(acc.area, 1))
		summary.species_histogram = acc.species_histogram
		summaries[out_count] = summary
		out_count += 1
	}
	particle_life_blob_tracker_update(&sim.blob_tracker, summaries[:out_count])
	sim.runtime.last_analysis_read_frame = sim.runtime.last_analysis_frame
}

particle_life_gpu_step :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, dt: f32) {
	if sim.runtime.force_matrix_dirty {
		particle_life_upload_force_matrix(sim)
	}
	if !particle_life_ensure_gpu_runtime(sim, vk_ctx) {
		return
	}
	sim.gpu.active_frame_slot = int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	particle_life_update_descriptors_for_slot(sim, vk_ctx, sim.gpu.active_frame_slot)
	target_analysis_axis := particle_life_target_analysis_grid_axis(sim.settings)
	world_size := particle_life_world_size(sim)
	target_grid_width, target_grid_height := particle_life_target_grid_dimensions(sim.settings, world_size)
	target_collision_width, target_collision_height := particle_life_target_collision_grid_dimensions(sim.settings, world_size)
	grid_capacity_sufficient := target_grid_width * target_grid_height <= sim.gpu.grid_cell_capacity &&
		target_collision_width * target_collision_height <= sim.gpu.grid_cell_capacity
	if grid_capacity_sufficient {
		sim.gpu.grid_width = target_grid_width
		sim.gpu.grid_height = target_grid_height
		sim.gpu.neighbor_radius_cells = particle_life_target_neighbor_radius_cells(sim.settings, target_grid_width, target_grid_height, world_size)
		sim.gpu.collision_grid_width = target_collision_width
		sim.gpu.collision_grid_height = target_collision_height
		particle_life_write_grid_uniforms(sim)
		particle_life_write_collision_grid_uniforms(sim)
	}
	grid_satisfies_target := particle_life_current_grid_satisfies_settings(sim)
	if sim.gpu.uploaded_particle_count != particle_life_target_particle_count(sim.settings) || sim.gpu.uploaded_species_count != particle_life_target_species_count(sim.settings) || !grid_satisfies_target || sim.gpu.analysis_grid_axis != target_analysis_axis {
		if sim.gpu.uploaded_particle_count != particle_life_target_particle_count(sim.settings) || sim.gpu.uploaded_species_count != particle_life_target_species_count(sim.settings) {
			particle_life_clear_preserved_particles(sim)
			sim.gpu.ready = false
		} else {
			particle_life_request_resource_rebuild(sim)
		}
		return
	}
	if sim.runtime.needs_reset {
		particle_life_clear_force_cache(sim, vk_ctx, cmd)
		particle_life_dispatch_init(sim, cmd)
	}
	if sim.runtime.pending_force_randomize {
		particle_life_dispatch_force_randomize(sim, cmd)
	}
	if sim.runtime.pending_force_update {
		particle_life_dispatch_force_update(sim, cmd)
	}
	if sim.settings.paused {
		return
	}
	particle_life_write_frame_uniforms(sim, dt)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: grid clear")
	particle_life_dispatch_grid_clear(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: grid scatter")
	particle_life_dispatch_grid_scatter(sim, vk_ctx, cmd)
	particle_life_dispatch_grid_prefix(sim, vk_ctx, cmd)
	particle_life_dispatch_grid_index_scatter(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: force compute")
	particle_life_dispatch_binned_compute(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: collision solve/apply")
	particle_life_dispatch_collision_solver(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
	engine.vk_cmd_label_begin(vk_ctx, cmd, "Particle Life: copy scratch")
	particle_life_copy_scratch_to_particles(sim, vk_ctx, cmd)
	engine.vk_cmd_label_end(vk_ctx, cmd)
}

particle_life_draw_particles :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Graphics_Pipeline) {
	vk.CmdBindPipeline(cmd, .GRAPHICS, pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	frame_slot := sim.gpu.active_frame_slot
	sets := [3]vk.DescriptorSet{sim.gpu.sim_sets[frame_slot], sim.gpu.color_sets[frame_slot], sim.gpu.view_sets[frame_slot]}
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline.layout, 0, u32(len(sets)), raw_data(sets[:]), 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	particle_life_push_viewport_uniform_mode(vk_ctx, cmd, pipeline)
	vk.CmdDraw(cmd, 6, sim.gpu.uploaded_particle_count, 0, 0)
	engine.vk_cmd_count_draw(vk_ctx)
}


particle_life_draw_infinite_tiles :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, pipeline: ^engine.Vk_Graphics_Pipeline, width, height: f32) {
	if sim.runtime.camera_zoom >= 1.0 {
		vk.CmdBindPipeline(cmd, .GRAPHICS, pipeline.pipeline)
		engine.vk_cmd_count_pipeline_bind(vk_ctx)
		frame_slot := sim.gpu.active_frame_slot
		sets := [3]vk.DescriptorSet{sim.gpu.sim_sets[frame_slot], sim.gpu.color_sets[frame_slot], sim.gpu.view_sets[frame_slot]}
		vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline.layout, 0, u32(len(sets)), raw_data(sets[:]), 0, nil)
		engine.vk_cmd_count_descriptor_bind(vk_ctx)
		particle_life_push_wrapped_viewport_mode(vk_ctx, cmd, pipeline)
		vk.CmdDraw(cmd, 6, sim.gpu.uploaded_particle_count, 0, 0)
		engine.vk_cmd_count_draw(vk_ctx)
		particle_life_push_viewport_uniform_mode(vk_ctx, cmd, pipeline)
		return
	}
	bounds := particle_life_view_bounds(sim, width, height)
	tile_size := particle_life_world_size_for_viewport(width, height)
	tile_count := infinite_render_tile_count(sim.runtime.camera_zoom)
	tile_range := particle_life_tile_range_for_bounds(bounds, sim.runtime.camera_x, sim.runtime.camera_y, tile_count / 2, tile_size)
	vk.CmdBindPipeline(cmd, .GRAPHICS, pipeline.pipeline)
	engine.vk_cmd_count_pipeline_bind(vk_ctx)
	frame_slot := sim.gpu.active_frame_slot
	sets := [3]vk.DescriptorSet{sim.gpu.sim_sets[frame_slot], sim.gpu.color_sets[frame_slot], sim.gpu.view_sets[frame_slot]}
	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline.layout, 0, u32(len(sets)), raw_data(sets[:]), 0, nil)
	engine.vk_cmd_count_descriptor_bind(vk_ctx)
	for tile_y := tile_range.min_y; tile_y <= tile_range.max_y; tile_y += 1 {
		for tile_x := tile_range.min_x; tile_x <= tile_range.max_x; tile_x += 1 {
			tile_bounds := particle_life_tile_bounds_for_offset(bounds, tile_x, tile_y, tile_size)
			particle_life_push_viewport_bounds(vk_ctx, cmd, pipeline, tile_bounds)
			vk.CmdDraw(cmd, 6, sim.gpu.uploaded_particle_count, 0, 0)
			engine.vk_cmd_count_draw(vk_ctx)
		}
	}
	particle_life_push_viewport_uniform_mode(vk_ctx, cmd, pipeline)
}

particle_life_transition_trail_image :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, cmd: vk.CommandBuffer, index: int, new_layout: vk.ImageLayout) {
	image := &sim.gpu.trail_images[index]
	if image.handle == vk.Image(0) || image.layout == new_layout {
		return
	}
	old_layout := image.layout
	src_access: vk.AccessFlags
	dst_access: vk.AccessFlags
	src_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	dst_stage := vk.PipelineStageFlags{.TOP_OF_PIPE}
	#partial switch old_layout {
	case .UNDEFINED:
		#partial switch new_layout {
		case .COLOR_ATTACHMENT_OPTIMAL:
			dst_access = {.COLOR_ATTACHMENT_WRITE}
			dst_stage = {.COLOR_ATTACHMENT_OUTPUT}
		case .TRANSFER_DST_OPTIMAL:
			dst_access = {.TRANSFER_WRITE}
			dst_stage = {.TRANSFER}
		}
	case .COLOR_ATTACHMENT_OPTIMAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.COLOR_ATTACHMENT_WRITE}
			dst_access = {.SHADER_READ}
			src_stage = {.COLOR_ATTACHMENT_OUTPUT}
			dst_stage = {.FRAGMENT_SHADER}
		case .TRANSFER_SRC_OPTIMAL:
			src_access = {.COLOR_ATTACHMENT_WRITE}
			dst_access = {.TRANSFER_READ}
			src_stage = {.COLOR_ATTACHMENT_OUTPUT}
			dst_stage = {.TRANSFER}
		}
	case .SHADER_READ_ONLY_OPTIMAL:
		#partial switch new_layout {
		case .COLOR_ATTACHMENT_OPTIMAL:
			src_access = {.SHADER_READ}
			dst_access = {.COLOR_ATTACHMENT_WRITE}
			src_stage = {.FRAGMENT_SHADER}
			dst_stage = {.COLOR_ATTACHMENT_OUTPUT}
		}
	case .TRANSFER_SRC_OPTIMAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.TRANSFER_READ}
			dst_access = {.SHADER_READ}
			src_stage = {.TRANSFER}
			dst_stage = {.FRAGMENT_SHADER}
		case .COLOR_ATTACHMENT_OPTIMAL:
			src_access = {.TRANSFER_READ}
			dst_access = {.COLOR_ATTACHMENT_WRITE}
			src_stage = {.TRANSFER}
			dst_stage = {.COLOR_ATTACHMENT_OUTPUT}
		}
	case .TRANSFER_DST_OPTIMAL:
		#partial switch new_layout {
		case .SHADER_READ_ONLY_OPTIMAL:
			src_access = {.TRANSFER_WRITE}
			dst_access = {.SHADER_READ}
			src_stage = {.TRANSFER}
			dst_stage = {.FRAGMENT_SHADER}
		}
	}
	barrier := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		srcAccessMask = src_access,
		dstAccessMask = dst_access,
		oldLayout = old_layout,
		newLayout = new_layout,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = image.handle,
		subresourceRange = {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
		},
	}
	vk.CmdPipelineBarrier(cmd, src_stage, dst_stage, {}, 0, nil, 0, nil, 1, &barrier)
	engine.vk_cmd_count_pipeline_barrier(vk_ctx)
	image.layout = new_layout
}

particle_life_update_fade_descriptor :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot, set_index, read_index: int) {
	params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.fade_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Fade_Params))}
	image_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = sim.gpu.trail_images[read_index].view}
	sampler_info := vk.DescriptorImageInfo{sampler = sim.gpu.trail_sampler}
	set := sim.gpu.fade_sets[frame_slot][set_index]
	writes := [3]vk.WriteDescriptorSet {
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 0, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 1, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
		{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 2, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
	}
	vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
}

particle_life_update_background_descriptor :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.background_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Background_Params))}
	write := vk.WriteDescriptorSet {
		sType = .WRITE_DESCRIPTOR_SET,
		dstSet = sim.gpu.background_sets[frame_slot],
		dstBinding = 0,
		descriptorType = .UNIFORM_BUFFER,
		descriptorCount = 1,
		pBufferInfo = &params_info,
	}
	vk.UpdateDescriptorSets(vk_ctx.device, 1, &write, 0, nil)
}

particle_life_update_post_descriptors :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	params_info := vk.DescriptorBufferInfo{buffer = sim.gpu.post_params_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Post_Params))}
	camera_info := vk.DescriptorBufferInfo{buffer = sim.gpu.camera_buffers[frame_slot].handle, offset = 0, range = vk.DeviceSize(size_of(Particle_Life_Camera))}
	sampler_info := vk.DescriptorImageInfo{sampler = sim.gpu.trail_sampler}
	for i in 0 ..< len(sim.gpu.trail_images) {
		image_info := vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, imageView = sim.gpu.trail_images[i].view}
		set := sim.gpu.post_sets[frame_slot][i]
		writes := [4]vk.WriteDescriptorSet {
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 0, descriptorType = .SAMPLED_IMAGE, descriptorCount = 1, pImageInfo = &image_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 1, descriptorType = .SAMPLER, descriptorCount = 1, pImageInfo = &sampler_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 2, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &params_info},
			{sType = .WRITE_DESCRIPTOR_SET, dstSet = set, dstBinding = 3, descriptorType = .UNIFORM_BUFFER, descriptorCount = 1, pBufferInfo = &camera_info},
		}
		vk.UpdateDescriptorSets(vk_ctx.device, u32(len(writes)), raw_data(writes[:]), 0, nil)
	}
}

particle_life_destroy_trail_image :: proc(vk_ctx: ^engine.Vk_Context, image: ^Particle_Life_Trail_Image) {
	if image.framebuffer != vk.Framebuffer(0) {
		vk.DestroyFramebuffer(vk_ctx.device, image.framebuffer, nil)
	}
	if image.view != vk.ImageView(0) {
		vk.DestroyImageView(vk_ctx.device, image.view, nil)
	}
	if image.handle != vk.Image(0) {
		vk.DestroyImage(vk_ctx.device, image.handle, nil)
	}
	if image.memory != vk.DeviceMemory(0) {
		vk.FreeMemory(vk_ctx.device, image.memory, nil)
	}
	image^ = {}
}

particle_life_destroy_trail_targets :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) {
	for i in 0 ..< len(sim.gpu.trail_images) {
		particle_life_destroy_trail_image(vk_ctx, &sim.gpu.trail_images[i])
	}
	sim.gpu.trail_width = 0
	sim.gpu.trail_height = 0
	sim.gpu.trail_initialized = false
	sim.gpu.trail_write_index = 0
}

particle_life_frame_slot_mask :: proc() -> u32 {
	return (u32(1) << u32(engine.MAX_FRAMES_IN_FLIGHT)) - 1
}

particle_life_collect_retired_trail_targets :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, frame_slot: int) {
	bit := u32(1) << u32(frame_slot)
	for i in 0 ..< PARTICLE_LIFE_RETIRED_TRAIL_TARGET_CAP {
		retired := &sim.gpu.retired_trail_targets[i]
		if retired.pending_frame_slots == 0 {
			continue
		}
		retired.pending_frame_slots = retired.pending_frame_slots & (~bit)
		if retired.pending_frame_slots == 0 {
			for image_index in 0 ..< len(retired.images) {
				particle_life_destroy_trail_image(vk_ctx, &retired.images[image_index])
			}
		}
	}
}

particle_life_retire_trail_targets :: proc(sim: ^Particle_Life_Simulation) -> bool {
	if sim.gpu.trail_images[0].handle == vk.Image(0) && sim.gpu.trail_images[1].handle == vk.Image(0) {
		sim.gpu.trail_images = {}
		sim.gpu.trail_width = 0
		sim.gpu.trail_height = 0
		sim.gpu.trail_initialized = false
		sim.gpu.trail_write_index = 0
		return true
	}
	for i in 0 ..< PARTICLE_LIFE_RETIRED_TRAIL_TARGET_CAP {
		retired := &sim.gpu.retired_trail_targets[i]
		if retired.pending_frame_slots == 0 {
			retired.images = sim.gpu.trail_images
			retired.pending_frame_slots = particle_life_frame_slot_mask()
			sim.gpu.trail_images = {}
			sim.gpu.trail_width = 0
			sim.gpu.trail_height = 0
			sim.gpu.trail_initialized = false
			sim.gpu.trail_write_index = 0
			return true
		}
	}
	engine.log_warn("particle life: trail target retire slots exhausted")
	return false
}

particle_life_ensure_trail_targets :: proc(sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context) -> bool {
	width := max(vk_ctx.swapchain_extent.width, u32(1))
	height := max(vk_ctx.swapchain_extent.height, u32(1))
	if sim.gpu.trail_width == width && sim.gpu.trail_height == height && sim.gpu.trail_images[0].handle != vk.Image(0) && sim.gpu.trail_images[1].handle != vk.Image(0) {
		return true
	}
	if !particle_life_retire_trail_targets(sim) {
		return false
	}
	for i in 0 ..< len(sim.gpu.trail_images) {
		if !particle_life_create_trail_image(sim, vk_ctx, i, width, height) {
			particle_life_destroy_trail_targets(sim, vk_ctx)
			return false
		}
	}
	sim.gpu.trail_width = width
	sim.gpu.trail_height = height
	frame_slot := int(vk_ctx.current_frame % engine.MAX_FRAMES_IN_FLIGHT)
	particle_life_update_background_descriptor(sim, vk_ctx, frame_slot)
	particle_life_update_post_descriptors(sim, vk_ctx, frame_slot)
	particle_life_collect_retired_trail_targets(sim, vk_ctx, frame_slot)
	return true
}
