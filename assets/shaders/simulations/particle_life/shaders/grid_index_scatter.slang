#include "common.slang"

[[vk::binding(0, 0)]]
StructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
ConstantBuffer<SimParams> params;
[[vk::binding(4, 0)]]
RWStructuredBuffer<uint> particle_indices;
[[vk::binding(5, 0)]]
ConstantBuffer<GridParams> grid_params;
[[vk::binding(9, 0)]]
StructuredBuffer<uint> grid_offsets;
[[vk::binding(10, 0)]]
RWStructuredBuffer<uint> grid_cursors;

uint grid_index(float2 pos) {
	let normalized = (pos - float2(grid_params.world_min_x, grid_params.world_min_y)) / float2(grid_params.world_width, grid_params.world_height);
	let x = min(uint(max(normalized.x, 0.0) * float(grid_params.grid_width)), grid_params.grid_width - 1);
	let y = min(uint(max(normalized.y, 0.0) * float(grid_params.grid_height)), grid_params.grid_height - 1);
	return y * grid_params.grid_width + x;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
	let index = global_id.x;
	if (index >= params.particle_count) {
		return;
	}
	let cell = grid_index(particles[index].position);
	uint local_index;
	InterlockedAdd(grid_cursors[cell], 1u, local_index);
	particle_indices[grid_offsets[cell] + local_index] = index;
}
