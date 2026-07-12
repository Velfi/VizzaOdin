package render_vk

import vk "vendor:vulkan"

render_graph_cache_resolve :: proc(cache: ^Render_Graph_Cache, key: Render_Graph_Structural_Key) -> ^Render_Graph {
	if cache == nil {
		return nil
	}
	if cache.valid && cache.key == key {
		return &cache.graph
	}
	candidate := render_graph_build_v1(key.mode, key.capture_active, key.preview_mode_mask)
	if !render_graph_compile(&candidate) {
		cache.graph = candidate
		cache.valid = false
		return nil
	}
	cache.graph = candidate
	cache.key = key
	cache.valid = true
	cache.compile_count += 1
	return &cache.graph
}

render_graph_resource_compatible_for_alias :: proc(a, b: ^Render_Resource) -> bool {
	if a == nil || b == nil || a.kind != b.kind || a.format != b.format || a.usage != b.usage {
		return false
	}
	if a.kind == .Vertex_Buffer || a.kind == .Index_Buffer {
		return a.byte_size == b.byte_size
	}
	return a.width == b.width && a.height == b.height && a.depth == b.depth
}

render_graph_diagnostics :: proc(graph: ^Render_Graph) -> Render_Graph_Diagnostics {
	if graph == nil do return {}
	diagnostics := Render_Graph_Diagnostics {
		compiled = graph.compiled,
		compile_error = graph.compile_error,
		pass_count = graph.pass_count,
		resource_count = graph.resource_count,
		barrier_count = graph.barrier_count,
		transient_barrier_count = graph.transient_barrier_count,
		physical_slot_count = graph.physical_slot_count,
		compiled_order = graph.compiled_order,
		resource_first_use = graph.resource_first_use,
		resource_last_use = graph.resource_last_use,
		resource_physical_slot = graph.resource_physical_slot,
	}
	for i in 0 ..< graph.pass_count {
		if graph.passes[i].enabled do continue
		diagnostics.disabled_passes[diagnostics.disabled_pass_count] = i
		diagnostics.disabled_pass_count += 1
	}
	return diagnostics
}

render_backend_graph_diagnostics :: proc(backend: ^Render_Backend) -> Render_Graph_Diagnostics {
	if backend == nil do return {}
	diagnostics := render_graph_diagnostics(&backend.graph_cache.graph)
	diagnostics.physical_allocation_count = backend.transient_allocation_count
	diagnostics.physical_reuse_count = backend.transient_reuse_count
	return diagnostics
}

render_resource_use_writes :: proc(access: Render_Resource_Access) -> bool {
	return access == .Write || access == .Read_Write
}

render_subresource_ranges_overlap :: proc(a, b: Render_Subresource_Range) -> bool {
	// Zero counts are the graph's compact spelling for the entire resource.
	if a.level_count == 0 || b.level_count == 0 || a.layer_count == 0 || b.layer_count == 0 {
		return true
	}
	a_mip_end := u64(a.base_mip_level) + u64(a.level_count)
	b_mip_end := u64(b.base_mip_level) + u64(b.level_count)
	a_layer_end := u64(a.base_array_layer) + u64(a.layer_count)
	b_layer_end := u64(b.base_array_layer) + u64(b.layer_count)
	return u64(a.base_mip_level) < b_mip_end && u64(b.base_mip_level) < a_mip_end &&
	       u64(a.base_array_layer) < b_layer_end && u64(b.base_array_layer) < a_layer_end
}

render_graph_pass_use :: proc(pass: ^Render_Pass_Node, resource: Render_Resource_Handle) -> (Render_Resource_Use, bool) {
	for i in 0 ..< pass.use_count {
		if pass.uses[i].resource == resource {
			return pass.uses[i], true
		}
	}
	return {}, false
}

render_graph_add_explicit_dependency :: proc(graph: ^Render_Graph, pass_index, dependency_index: int) -> bool {
	if graph == nil || pass_index < 0 || pass_index >= graph.pass_count || dependency_index < 0 || dependency_index >= graph.pass_count {
		return false
	}
	pass := &graph.passes[pass_index]
	if pass.dependency_count >= len(pass.depends_on) {
		return false
	}
	pass.depends_on[pass.dependency_count] = dependency_index
	pass.dependency_count += 1
	graph.compiled = false
	return true
}

render_graph_compile :: proc(graph: ^Render_Graph) -> bool {
	if graph == nil {
		return false
	}
	graph.compiled = false
	graph.compiled_count = 0
	graph.barrier_count = 0
	graph.transient_barrier_count = 0
	graph.physical_slot_count = 0
	graph.compile_error = .None
	graph.edges = {}
	for i in 0 ..< graph.resource_count {
		graph.resource_first_use[i] = -1
		graph.resource_last_use[i] = -1
		graph.resource_physical_slot[i] = -1
	}

	for pass_index in 0 ..< graph.pass_count {
		pass := &graph.passes[pass_index]
		if !pass.enabled do continue
		for use_index in 0 ..< pass.use_count {
			resource_index := int(pass.uses[use_index].resource)
			if resource_index < 0 || resource_index >= graph.resource_count {
				graph.compile_error = .Invalid_Resource
				return false
			}
			if graph.resource_first_use[resource_index] < 0 {
				graph.resource_first_use[resource_index] = pass_index
			}
			graph.resource_last_use[resource_index] = pass_index
		}
		for dependency_index in pass.depends_on[:pass.dependency_count] {
			if dependency_index < 0 || dependency_index >= graph.pass_count || dependency_index == pass_index {
				graph.compile_error = .Invalid_Dependency
				return false
			}
			if !graph.passes[dependency_index].enabled do continue
			graph.edges[dependency_index][pass_index] = true
		}
	}

	// Scan backward to the nearest overlapping writer and the overlapping
	// readers since it. This preserves minimal RAW/WAR/WAW edges while allowing
	// independent mip and array-layer ranges to execute without false hazards.
	for resource_index in 0 ..< graph.resource_count {
		resource := Render_Resource_Handle(resource_index)
		for pass_index in 0 ..< graph.pass_count {
			if !graph.passes[pass_index].enabled do continue
			use, used := render_graph_pass_use(&graph.passes[pass_index], resource)
			if !used {
				continue
			}
			if use.access == .Read {
				for previous := pass_index - 1; previous >= 0; previous -= 1 {
					if !graph.passes[previous].enabled do continue
					previous_use, previous_used := render_graph_pass_use(&graph.passes[previous], resource)
					if previous_used && render_resource_use_writes(previous_use.access) && render_subresource_ranges_overlap(previous_use.subresource, use.subresource) {
						if !render_graph_add_hazard(graph, resource, previous, pass_index) do return false
						break
					}
				}
				continue
			}
			reader_found := false
			for previous := pass_index - 1; previous >= 0; previous -= 1 {
				if !graph.passes[previous].enabled do continue
				previous_use, previous_used := render_graph_pass_use(&graph.passes[previous], resource)
				if !previous_used || !render_subresource_ranges_overlap(previous_use.subresource, use.subresource) do continue
				if previous_use.access == .Read {
					if !render_graph_add_hazard(graph, resource, previous, pass_index) do return false
					reader_found = true
					continue
				}
				if !reader_found && !render_graph_add_hazard(graph, resource, previous, pass_index) {
					return false
				}
				break
			}
		}
	}

	indegree: [MAX_RENDER_GRAPH_PASSES]int
	for from in 0 ..< graph.pass_count {
		for to in 0 ..< graph.pass_count {
			if graph.edges[from][to] {
				indegree[to] += 1
			}
		}
	}
	used: [MAX_RENDER_GRAPH_PASSES]bool
	enabled_count := 0
	for i in 0 ..< graph.pass_count {
		if graph.passes[i].enabled {
			enabled_count += 1
		} else {
			used[i] = true
		}
	}
	for _ in 0 ..< enabled_count {
		next := -1
		for candidate in 0 ..< graph.pass_count {
			if !used[candidate] && indegree[candidate] == 0 {
				next = candidate
				break
			}
		}
		if next < 0 {
			graph.compile_error = .Cycle
			return false
		}
		used[next] = true
		graph.compiled_order[graph.compiled_count] = next
		graph.compiled_count += 1
		for dependent in 0 ..< graph.pass_count {
			if graph.edges[next][dependent] {
				indegree[dependent] -= 1
			}
		}
	}

	// Lifetimes are positions in compiled execution order, not registration
	// indices, so explicit dependencies cannot invalidate alias analysis.
	for i in 0 ..< graph.resource_count {
		graph.resource_first_use[i] = -1
		graph.resource_last_use[i] = -1
	}
	for order_index in 0 ..< graph.compiled_count {
		pass := &graph.passes[graph.compiled_order[order_index]]
		for use in pass.uses[:pass.use_count] {
			resource_index := int(use.resource)
			if graph.resource_first_use[resource_index] < 0 do graph.resource_first_use[resource_index] = order_index
			graph.resource_last_use[resource_index] = order_index
		}
	}
	for resource_index in 0 ..< graph.resource_count {
		resource := &graph.resources[resource_index]
		if !resource.transient || graph.resource_first_use[resource_index] < 0 {
			continue
		}
		slot := -1
		previous_resource := -1
		for candidate_slot in 0 ..< graph.physical_slot_count {
			compatible := true
			candidate_previous := -1
			latest_use := -1
			for previous in 0 ..< resource_index {
				if graph.resource_physical_slot[previous] != candidate_slot do continue
				if !render_graph_resource_compatible_for_alias(&graph.resources[previous], resource) || graph.resource_last_use[previous] >= graph.resource_first_use[resource_index] {
					compatible = false
					break
				}
				if graph.resource_last_use[previous] > latest_use {
					latest_use = graph.resource_last_use[previous]
					candidate_previous = previous
				}
			}
			if compatible && candidate_previous >= 0 {
				slot = candidate_slot
				previous_resource = candidate_previous
				break
			}
		}
		if slot < 0 {
			slot = graph.physical_slot_count
			graph.physical_slot_count += 1
		}
		graph.resource_physical_slot[resource_index] = slot
		first_pass_index := graph.compiled_order[graph.resource_first_use[resource_index]]
		first_use, first_found := render_graph_pass_use(&graph.passes[first_pass_index], Render_Resource_Handle(resource_index))
		if !first_found do return false
		transient_barrier := Render_Graph_Transient_Barrier {
			resource = Render_Resource_Handle(resource_index),
			previous_resource = Render_Resource_Handle(previous_resource),
			consumer_pass = first_pass_index,
			src_stage = {.TOP_OF_PIPE},
			dst_stage = first_use.stage,
			dst_access = first_use.access_mask,
			old_layout = .UNDEFINED,
			new_layout = first_use.layout,
		}
		if previous_resource >= 0 {
			last_pass_index := graph.compiled_order[graph.resource_last_use[previous_resource]]
			last_use, last_found := render_graph_pass_use(&graph.passes[last_pass_index], Render_Resource_Handle(previous_resource))
			if !last_found do return false
			transient_barrier.src_stage = last_use.stage
			transient_barrier.src_access = last_use.access_mask
			transient_barrier.old_layout = last_use.layout
		}
		graph.transient_barriers[graph.transient_barrier_count] = transient_barrier
		graph.transient_barrier_count += 1
	}
	graph.compiled = true
	return true
}

render_graph_add_hazard :: proc(graph: ^Render_Graph, resource: Render_Resource_Handle, producer, consumer: int) -> bool {
	if producer < 0 || consumer < 0 || producer == consumer {
		return true
	}
	graph.edges[producer][consumer] = true
	for barrier in graph.barriers[:graph.barrier_count] {
		if barrier.resource == resource && barrier.producer_pass == producer && barrier.consumer_pass == consumer {
			return true
		}
	}
	if graph.barrier_count >= len(graph.barriers) {
		graph.compile_error = .Barrier_Capacity
		return false
	}
	source, source_ok := render_graph_pass_use(&graph.passes[producer], resource)
	destination, destination_ok := render_graph_pass_use(&graph.passes[consumer], resource)
	if !source_ok || !destination_ok {
		graph.compile_error = .Invalid_Resource
		return false
	}
	graph.barriers[graph.barrier_count] = {
		resource = resource,
		producer_pass = producer,
		consumer_pass = consumer,
		src_stage = source.stage,
		src_access = source.access_mask,
		dst_stage = destination.stage,
		dst_access = destination.access_mask,
		old_layout = source.layout,
		new_layout = destination.layout,
	}
	graph.barrier_count += 1
	return true
}

render_graph_add_use :: proc(pass: ^Render_Pass_Node, resource: Render_Resource_Handle, access: Render_Resource_Access, stage: vk.PipelineStageFlags2 = {}, access_mask: vk.AccessFlags2 = {}, layout: vk.ImageLayout = .UNDEFINED, subresource: Render_Subresource_Range = {}) -> bool {
	if pass == nil || pass.use_count >= len(pass.uses) {
		return false
	}
	pass.uses[pass.use_count] = {resource, access, stage, access_mask, layout, subresource}
	pass.use_count += 1
	return true
}
