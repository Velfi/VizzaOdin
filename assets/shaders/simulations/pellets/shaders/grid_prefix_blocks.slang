struct GridParams { uint particle_count; uint grid_width; uint grid_height; float cell_size; float world_width; float world_height; uint _pad1; uint _pad2; };
[[vk::binding(1, 0)]] ConstantBuffer<GridParams> params;
[[vk::binding(4, 0)]] RWStructuredBuffer<uint> block_sums;
[shader("compute")]
[numthreads(1, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    if (global_id.x != 0u) return;
    let block_count = (params.grid_width * params.grid_height + 255u) / 256u;
    var running = 0u;
    for (var block = 0u; block < block_count; block++) {
        let total = block_sums[block];
        block_sums[block] = running;
        running += total;
    }
}
