package game

import uifw "../ui"

import "core:math"

particle_life_blob_tracker_reset :: proc(tracker: ^Particle_Life_Blob_Tracker) {
	tracker^ = {next_id = 1}
}

particle_life_analysis_workspace_destroy :: proc(workspace: ^Particle_Life_Analysis_Workspace) {
	if workspace.cells != nil {
		delete(workspace.cells)
	}
	if workspace.coherence != nil {
		delete(workspace.coherence)
	}
	if workspace.labels != nil {
		delete(workspace.labels)
	}
	if workspace.queue != nil {
		delete(workspace.queue)
	}
	workspace^ = {}
}

particle_life_analysis_workspace_ensure :: proc(workspace: ^Particle_Life_Analysis_Workspace, axis: u32) -> bool {
	cell_count := int(axis * axis)
	if axis == 0 || cell_count <= 0 {
		return false
	}
	if workspace.axis == axis && len(workspace.cells) == cell_count {
		return true
	}
	particle_life_analysis_workspace_destroy(workspace)
	workspace.axis = axis
	workspace.cells = make([]Particle_Life_Analysis_Cell, cell_count)
	workspace.coherence = make([]f32, cell_count)
	workspace.labels = make([]u32, cell_count)
	workspace.queue = make([]u32, cell_count)
	return workspace.cells != nil && workspace.coherence != nil && workspace.labels != nil && workspace.queue != nil
}

particle_life_smoothstep :: proc(edge0, edge1, x: f32) -> f32 {
	if edge0 == edge1 {
		return x >= edge1 ? 1 : 0
	}
	t := max(min((x - edge0) / (edge1 - edge0), 1.0), 0.0)
	return t * t * (3.0 - 2.0 * t)
}

particle_life_analysis_cell_index :: proc(x, y, axis: u32) -> u32 {
	return y * axis + x
}

particle_life_analysis_particle_coord :: proc(value, world_min, world_size: f32, axis: u32) -> u32 {
	normalized := max(min((value - world_min) / max(world_size, 0.0001), 0.999999), 0.0)
	return min(u32(normalized * f32(axis)), axis - 1)
}

particle_life_analysis_cell_center :: proc(x, y, axis: u32, world_size: [2]f32) -> [2]f32 {
	cell_w := world_size[0] / f32(axis)
	cell_h := world_size[1] / f32(axis)
	return {
		-world_size[0] * 0.5 + (f32(x) + 0.5) * cell_w,
		-world_size[1] * 0.5 + (f32(y) + 0.5) * cell_h,
	}
}

particle_life_analysis_compute_coherence :: proc(workspace: ^Particle_Life_Analysis_Workspace, axis: u32) {
	for y: u32 = 0; y < axis; y += 1 {
		for x: u32 = 0; x < axis; x += 1 {
			index := particle_life_analysis_cell_index(x, y, axis)
			cell := workspace.cells[index]
			if cell.density <= 0 {
				workspace.coherence[index] = 0
				continue
			}

			neighbor_density: f32
			neighbor_velocity := [2]f32{}
			neighbor_count: f32
			for oy := -1; oy <= 1; oy += 1 {
				for ox := -1; ox <= 1; ox += 1 {
					nx := i32(x) + i32(ox)
					ny := i32(y) + i32(oy)
					if nx < 0 || ny < 0 || nx >= i32(axis) || ny >= i32(axis) {
						continue
					}
					neighbor := workspace.cells[particle_life_analysis_cell_index(u32(nx), u32(ny), axis)]
					if neighbor.density <= 0 {
						continue
					}
					neighbor_density += neighbor.density
					neighbor_velocity[0] += neighbor.velocity_sum[0]
					neighbor_velocity[1] += neighbor.velocity_sum[1]
					neighbor_count += 1
				}
			}

			avg_velocity := [2]f32{cell.velocity_sum[0] / cell.density, cell.velocity_sum[1] / cell.density}
			avg_neighbor_velocity := [2]f32{}
			if neighbor_density > 0 {
				avg_neighbor_velocity = {neighbor_velocity[0] / neighbor_density, neighbor_velocity[1] / neighbor_density}
			}
			speed := math.sqrt(avg_velocity[0] * avg_velocity[0] + avg_velocity[1] * avg_velocity[1])
			neighbor_speed := math.sqrt(avg_neighbor_velocity[0] * avg_neighbor_velocity[0] + avg_neighbor_velocity[1] * avg_neighbor_velocity[1])
			alignment := f32(0.65)
			if speed > 0.00001 && neighbor_speed > 0.00001 {
				alignment = (avg_velocity[0] * avg_neighbor_velocity[0] + avg_velocity[1] * avg_neighbor_velocity[1]) / (speed * neighbor_speed)
				alignment = max(min(alignment * 0.5 + 0.5, 1.0), 0.0)
			}

			neighbor_average_density := neighbor_density / max(neighbor_count, 1.0)
			boundary_strength := math.abs(cell.density - neighbor_average_density) / max(cell.density, 1.0)
			boundary_score := max(min(boundary_strength * 1.5 + 0.50, 1.0), 0.50)
			density_score := particle_life_smoothstep(0.75, 4.0, cell.density)
			workspace.coherence[index] = density_score * alignment * boundary_score
		}
	}
}

particle_life_analysis_flush_component :: proc(
	workspace: ^Particle_Life_Analysis_Workspace,
	axis: u32,
	label: u32,
	start_index: u32,
	min_blob_area_cells: u32,
	world_size: [2]f32,
	out_summaries: ^[128]Particle_Life_Blob_Summary,
	out_count: ^u32,
) {
	read_index: u32
	write_index: u32 = 1
	workspace.queue[0] = start_index
	workspace.labels[start_index] = label

	summary: Particle_Life_Blob_Summary
	summary.id = label
	summary.bounds = {1, 1, -1, -1}
	weighted_position := [2]f32{}
	velocity_sum := [2]f32{}
	coherence_sum: f32

	for read_index < write_index {
		index := workspace.queue[read_index]
		read_index += 1
		cell := workspace.cells[index]
		x := index % axis
		y := index / axis
		center := particle_life_analysis_cell_center(x, y, axis, world_size)

		summary.area += 1
		summary.density += cell.density
		weighted_position[0] += center[0] * cell.density
		weighted_position[1] += center[1] * cell.density
		velocity_sum[0] += cell.velocity_sum[0]
		velocity_sum[1] += cell.velocity_sum[1]
		coherence_sum += workspace.coherence[index]
		summary.bounds[0] = min(summary.bounds[0], center[0])
		summary.bounds[1] = min(summary.bounds[1], center[1])
		summary.bounds[2] = max(summary.bounds[2], center[0])
		summary.bounds[3] = max(summary.bounds[3], center[1])
		for species in 0 ..< PARTICLE_LIFE_MAX_SPECIES {
			summary.species_histogram[species] += cell.species_histogram[species]
		}

		neighbors := [4]i32{-1, 1, -i32(axis), i32(axis)}
		for n in 0 ..< len(neighbors) {
			if neighbors[n] == -1 && x == 0 {
				continue
			}
			if neighbors[n] == 1 && x + 1 >= axis {
				continue
			}
			if neighbors[n] == -i32(axis) && y == 0 {
				continue
			}
			if neighbors[n] == i32(axis) && y + 1 >= axis {
				continue
			}
			next := u32(i32(index) + neighbors[n])
			if workspace.labels[next] != 0 || workspace.coherence[next] <= 0 {
				continue
			}
			workspace.labels[next] = label
			workspace.queue[write_index] = next
			write_index += 1
		}
	}

	if summary.area < min_blob_area_cells || out_count^ >= u32(len(out_summaries^)) {
		return
	}
	weight := max(summary.density, 0.00001)
	summary.centroid = {weighted_position[0] / weight, weighted_position[1] / weight}
	summary.velocity = {velocity_sum[0] / weight, velocity_sum[1] / weight}
	summary.coherence_score = coherence_sum / f32(max(summary.area, 1))
	out_summaries^[out_count^] = summary
	out_count^ += 1
}

particle_life_analyze_particles :: proc(
	workspace: ^Particle_Life_Analysis_Workspace,
	particles: []Particle_Life_Particle,
	species_count: u32,
	grid_axis: u32,
	min_blob_area_cells: u32,
	coherence_threshold: f32,
	world_size: [2]f32,
) -> []Particle_Life_Blob_Summary {
	axis := max(min(grid_axis, 1024), 4)
	if !particle_life_analysis_workspace_ensure(workspace, axis) {
		return nil
	}
	cell_count := int(axis * axis)
	for i in 0 ..< cell_count {
		workspace.cells[i] = {}
		workspace.coherence[i] = 0
		workspace.labels[i] = 0
	}
	workspace.summaries = {}
	world_min_x := -world_size[0] * 0.5
	world_min_y := -world_size[1] * 0.5

	for particle in particles {
		x := particle_life_analysis_particle_coord(particle.position[0], world_min_x, world_size[0], axis)
		y := particle_life_analysis_particle_coord(particle.position[1], world_min_y, world_size[1], axis)
		index := particle_life_analysis_cell_index(x, y, axis)
		cell := &workspace.cells[index]
		cell.density += 1
		cell.velocity_sum[0] += particle.velocity[0]
		cell.velocity_sum[1] += particle.velocity[1]
		speed := math.sqrt(particle.velocity[0] * particle.velocity[0] + particle.velocity[1] * particle.velocity[1])
		cell.speed_sum += speed
		species := min(particle.species, PARTICLE_LIFE_MAX_SPECIES - 1)
		if species < species_count {
			cell.species_histogram[species] += 1
		}
	}

	particle_life_analysis_compute_coherence(workspace, axis)
	threshold := max(min(coherence_threshold, 1.0), 0.0)
	for i in 0 ..< cell_count {
		if workspace.coherence[i] < threshold {
			workspace.coherence[i] = 0
		}
	}

	label: u32 = 1
	out_count: u32
	for i in 0 ..< cell_count {
		if workspace.labels[i] != 0 || workspace.coherence[i] <= 0 {
			continue
		}
		particle_life_analysis_flush_component(workspace, axis, label, u32(i), max(min_blob_area_cells, 1), world_size, &workspace.summaries, &out_count)
		label += 1
		if label == 0 {
			label = 1
		}
	}
	return workspace.summaries[:out_count]
}

particle_life_blob_distance_sq :: proc(a, b: [2]f32) -> f32 {
	dx := a[0] - b[0]
	dy := a[1] - b[1]
	return dx * dx + dy * dy
}

particle_life_blob_histogram_similarity :: proc(a, b: [PARTICLE_LIFE_MAX_SPECIES]u32) -> f32 {
	intersection: u32
	total: u32
	for i in 0 ..< PARTICLE_LIFE_MAX_SPECIES {
		intersection += min(a[i], b[i])
		total += max(a[i], b[i])
	}
	if total == 0 {
		return 1
	}
	return f32(intersection) / f32(total)
}

particle_life_blob_match_score :: proc(blob: Particle_Life_Tracked_Blob, summary: Particle_Life_Blob_Summary) -> f32 {
	position_distance := math.sqrt(particle_life_blob_distance_sq(blob.predicted_position, summary.centroid))
	position_score := max(1.0 - position_distance / 0.35, 0.0)
	velocity_distance := math.sqrt(particle_life_blob_distance_sq(blob.velocity, summary.velocity))
	velocity_score := max(1.0 - velocity_distance / 0.6, 0.0)
	area_a := f32(max(blob.area, 1))
	area_b := f32(max(summary.area, 1))
	area_score := min(area_a, area_b) / max(area_a, area_b)
	histogram_score := particle_life_blob_histogram_similarity(blob.species_histogram, summary.species_histogram)
	return position_score * 0.45 + velocity_score * 0.20 + area_score * 0.20 + histogram_score * 0.15
}

particle_life_blob_tracker_update_one :: proc(tracker: ^Particle_Life_Blob_Tracker, blob_index: int, summary: Particle_Life_Blob_Summary) {
	blob := &tracker.blobs[blob_index]
	blob.age += 1
	blob.missed_frames = 0
	blob.velocity = summary.velocity
	blob.bounds = summary.bounds
	blob.last_position = summary.centroid
	blob.predicted_position = {
		summary.centroid[0] + summary.velocity[0],
		summary.centroid[1] + summary.velocity[1],
	}
	blob.area = summary.area
	blob.confidence = min(blob.confidence + 0.15, 1.0)
	blob.species_histogram = summary.species_histogram
}

particle_life_blob_tracker_add :: proc(tracker: ^Particle_Life_Blob_Tracker, summary: Particle_Life_Blob_Summary) {
	if tracker.count >= u32(len(tracker.blobs)) {
		return
	}
	index := int(tracker.count)
	tracker.count += 1
	blob := &tracker.blobs[index]
	blob^ = {
		id = tracker.next_id,
		age = 1,
		last_position = summary.centroid,
		predicted_position = {
			summary.centroid[0] + summary.velocity[0],
			summary.centroid[1] + summary.velocity[1],
		},
		velocity = summary.velocity,
		bounds = summary.bounds,
		area = summary.area,
		confidence = 0.45,
		species_histogram = summary.species_histogram,
	}
	tracker.next_id += 1
	if tracker.next_id == 0 {
		tracker.next_id = 1
	}
}

particle_life_blob_tracker_update :: proc(tracker: ^Particle_Life_Blob_Tracker, summaries: []Particle_Life_Blob_Summary) {
	matched_blobs: [128]bool
	matched_summaries: [128]bool
	old_count := int(tracker.count)
	summary_count := min(len(summaries), len(matched_summaries))
	for s in 0 ..< summary_count {
		best_index := -1
		best_score: f32
		for b in 0 ..< old_count {
			if matched_blobs[b] {
				continue
			}
			score := particle_life_blob_match_score(tracker.blobs[b], summaries[s])
			if score > best_score {
				best_score = score
				best_index = b
			}
		}
		if best_index >= 0 && best_score >= 0.35 {
			particle_life_blob_tracker_update_one(tracker, best_index, summaries[s])
			matched_blobs[best_index] = true
			matched_summaries[s] = true
		}
	}
	write_index := 0
	for read_index in 0 ..< old_count {
		if !matched_blobs[read_index] && tracker.blobs[read_index].age > 0 {
			tracker.blobs[read_index].missed_frames += 1
			tracker.blobs[read_index].confidence = max(tracker.blobs[read_index].confidence - 0.2, 0.0)
		}
		if tracker.blobs[read_index].missed_frames <= 10 {
			if write_index != read_index {
				tracker.blobs[write_index] = tracker.blobs[read_index]
			}
			write_index += 1
		}
	}
	tracker.count = u32(write_index)
	for s in 0 ..< summary_count {
		if !matched_summaries[s] {
			particle_life_blob_tracker_add(tracker, summaries[s])
		}
	}
}

particle_life_randomize_forces :: proc(sim: ^Particle_Life_Simulation) {
	sim.runtime.force_randomize_undo_matrix = sim.runtime.force_matrix
	sim.runtime.force_randomize_undo_seed = sim.runtime.seed
	sim.runtime.force_randomize_undo_available = true
	sim.runtime.seed += 0x85ebca6b
	sim.settings.custom_force_matrix = false
	particle_life_mirror_force_randomize(sim)
	sim.runtime.pending_force_randomize = true
}

particle_life_undo_randomize_forces :: proc(sim: ^Particle_Life_Simulation) -> bool {
	if sim == nil || !sim.runtime.force_randomize_undo_available {
		return false
	}
	sim.runtime.seed = sim.runtime.force_randomize_undo_seed
	sim.runtime.force_matrix = sim.runtime.force_randomize_undo_matrix
	for i in 0 ..< len(sim.settings.force_matrix) {
		sim.settings.force_matrix[i] = sim.runtime.force_matrix[i]
	}
	sim.settings.custom_force_matrix = true
	sim.runtime.pending_force_randomize = false
	particle_life_force_matrix_upload_existing(sim, u32(max(min(sim.settings.species_count, PARTICLE_LIFE_MAX_SPECIES), 1)))
	sim.runtime.force_randomize_undo_available = false
	return true
}

particle_life_load_settings :: proc(sim: ^Particle_Life_Simulation, settings: Particle_Life_Settings) {
	particle_count_changed := sim.runtime.rendered_particle_count != 0 && sim.runtime.rendered_particle_count != particle_life_target_particle_count(settings)
	species_count_changed := sim.runtime.rendered_species_count != 0 && sim.runtime.rendered_species_count != particle_life_target_species_count(settings)
	sim.settings^ = settings
	sim.runtime.force_randomize_undo_available = false
	sim.settings.infinite_tiles_enabled = true
	sim.runtime.camera_x = settings.camera_x
	sim.runtime.camera_y = settings.camera_y
	sim.runtime.camera_zoom = max(settings.camera_zoom, 0.25)
	sim.runtime.camera_target_x = sim.runtime.camera_x
	sim.runtime.camera_target_y = sim.runtime.camera_y
	sim.runtime.camera_target_zoom = sim.runtime.camera_zoom
	if sim.runtime.camera_smoothing_factor <= 0 {
		sim.runtime.camera_smoothing_factor = CAMERA_DEFAULT_SMOOTHING
	}
	for i in 0 ..< len(sim.runtime.force_matrix) {
		sim.runtime.force_matrix[i] = settings.force_matrix[i]
	}
	sim.runtime.needs_reset = true
	if particle_count_changed || species_count_changed {
		sim.runtime.render_rebuild_requested = true
		sim.runtime.render_ready = false
	} else {
		sim.runtime.force_matrix_dirty = true
	}
}

particle_life_save_settings :: proc(sim: ^Particle_Life_Simulation) -> Particle_Life_Settings {
	settings := sim.settings^
	settings.camera_x = sim.runtime.camera_x
	settings.camera_y = sim.runtime.camera_y
	settings.camera_zoom = max(sim.runtime.camera_zoom, 0.25)
	settings.custom_force_matrix = true
	settings.infinite_tiles_enabled = true
	for i in 0 ..< len(settings.force_matrix) {
		settings.force_matrix[i] = sim.runtime.force_matrix[i]
	}
	return settings
}

particle_life_clear_color :: proc(sim: ^Particle_Life_Simulation) -> uifw.Color {
	color := particle_life_background_color(sim.settings)
	return {color[0], color[1], color[2], color[3]}
}

particle_life_background_color :: proc(settings: ^Particle_Life_Settings) -> [4]f32 {
	#partial switch settings.background_color_mode {
	case .Black:
		return {0, 0, 0, 1}
	case .White:
		return {1, 1, 1, 1}
	case .Gray18:
		return {0.18, 0.18, 0.18, 1}
	case .Color_Scheme:
		scheme := color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
		return color_scheme_color_at(scheme, 0)
	case:
		return settings.background_color
	}
}
