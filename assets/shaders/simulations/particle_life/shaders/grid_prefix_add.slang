#include "common.slang"

[[vk::binding(5, 0)]]
ConstantBuffer<GridParams> grid_params;
[[vk::binding(9, 0)]]
RWStructuredBuffer<uint> grid_offsets;
[[vk::binding(11, 0)]]
StructuredBuffer<uint> block_sums;

[shader("compute")]
[numthreads(256, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID, uint3 group_id : SV_GroupID) {
	let cell_count = grid_params.grid_width * grid_params.grid_height;
	if (global_id.x < cell_count) {
		grid_offsets[global_id.x] += block_sums[group_id.x];
	}
}
