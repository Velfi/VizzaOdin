struct GridParams { uint particle_count; uint grid_width; uint grid_height; float cell_size; float world_width; float world_height; uint _pad1; uint _pad2; };
[[vk::binding(1, 0)]] ConstantBuffer<GridParams> params;
[[vk::binding(2, 0)]] RWStructuredBuffer<uint> grid_offsets;
[[vk::binding(4, 0)]] StructuredBuffer<uint> block_sums;
[shader("compute")]
[numthreads(256, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID, uint3 group_id : SV_GroupID) {
    if (global_id.x < params.grid_width * params.grid_height) grid_offsets[global_id.x] += block_sums[group_id.x];
}
