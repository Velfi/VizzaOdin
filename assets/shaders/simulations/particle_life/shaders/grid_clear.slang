#include "common.slang"

[[vk::binding(0, 0)]]
RWStructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
ConstantBuffer<SimParams> params;
[[vk::binding(2, 0)]]
StructuredBuffer<float> force_matrix;
[[vk::binding(3, 0)]]
RWStructuredBuffer<uint> grid_heads;
[[vk::binding(4, 0)]]
RWStructuredBuffer<uint> particle_next;
[[vk::binding(5, 0)]]
ConstantBuffer<GridParams> grid_params;
[[vk::binding(10, 0)]]
RWStructuredBuffer<uint> grid_cursors;

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    let cell_count = grid_params.grid_width * grid_params.grid_height;
    if (index < cell_count) {
		grid_heads[index] = grid_params._pad0 > 0.5 ? 0xffffffffu : 0u;
		grid_cursors[index] = 0u;
    }
    if (grid_params._pad0 > 0.5 && index < params.particle_count) {
        particle_next[index] = 0xffffffffu;
    }
}
