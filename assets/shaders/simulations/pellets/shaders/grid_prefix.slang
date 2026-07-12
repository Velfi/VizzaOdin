struct GridParams { uint particle_count; uint grid_width; uint grid_height; float cell_size; float world_width; float world_height; uint _pad1; uint _pad2; };
[[vk::binding(0, 0)]] StructuredBuffer<uint> grid_counts;
[[vk::binding(1, 0)]] ConstantBuffer<GridParams> params;
[[vk::binding(2, 0)]] RWStructuredBuffer<uint> grid_offsets;
[[vk::binding(3, 0)]] RWStructuredBuffer<uint> grid_cursors;
[[vk::binding(4, 0)]] RWStructuredBuffer<uint> block_sums;
groupshared uint[256] scan_values;
[shader("compute")]
[numthreads(256, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID, uint3 group_id : SV_GroupID, uint3 local_id : SV_GroupThreadID) {
    let cell_count = params.grid_width * params.grid_height;
    let index = global_id.x;
    let value = index < cell_count ? grid_counts[index] : 0u;
    scan_values[local_id.x] = value;
    GroupMemoryBarrierWithGroupSync();
    for (var offset = 1u; offset < 256u; offset <<= 1u) {
        let addend = local_id.x >= offset ? scan_values[local_id.x - offset] : 0u;
        GroupMemoryBarrierWithGroupSync();
        scan_values[local_id.x] += addend;
        GroupMemoryBarrierWithGroupSync();
    }
    if (index < cell_count) {
        grid_offsets[index] = scan_values[local_id.x] - value;
        grid_cursors[index] = 0u;
    }
    if (local_id.x == 255u) block_sums[group_id.x] = scan_values[255];
}
