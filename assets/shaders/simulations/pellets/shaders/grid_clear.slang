struct GridParams {
    uint particle_count;
    uint grid_width;
    uint grid_height;
    float cell_size;
    float world_width;
    float world_height;
    uint _pad1;
    uint _pad2;
};

[[vk::binding(0, 0)]] RWStructuredBuffer<uint> grid_counts;
[[vk::binding(1, 0)]] ConstantBuffer<GridParams> params;

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    if (index < params.grid_width * params.grid_height) {
        grid_counts[index] = 0;
    }
}
