#include "common.slang"

[[vk::binding(5, 0)]]
ConstantBuffer<GridParams> grid_params;
[[vk::binding(11, 0)]]
RWStructuredBuffer<uint> block_sums;

[shader("compute")]
[numthreads(1, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
	if (global_id.x != 0u) return;
	let cell_count = grid_params.grid_width * grid_params.grid_height;
	let block_count = (cell_count + 255u) / 256u;
	var running = 0u;
	for (var block = 0u; block < block_count; block++) {
		let total = block_sums[block];
		block_sums[block] = running;
		running += total;
	}
}
