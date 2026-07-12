struct Particle { float2 position; float2 velocity; float mass; float radius; uint clump_id; float density; uint grabbed; uint _pad0; float2 previous_position; };
struct GridParams { uint particle_count; uint grid_width; uint grid_height; float cell_size; float world_width; float world_height; uint _pad1; uint _pad2; };
[[vk::binding(0, 0)]] StructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]] ConstantBuffer<GridParams> params;
[[vk::binding(2, 0)]] StructuredBuffer<uint> grid_offsets;
[[vk::binding(3, 0)]] RWStructuredBuffer<uint> grid_cursors;
[[vk::binding(4, 0)]] RWStructuredBuffer<uint> particle_indices;
uint grid_index(float2 pos) {
    let normalized = (pos + float2(1.0, 1.0)) * 0.5;
    let x = min(uint(normalized.x * float(params.grid_width)), params.grid_width - 1);
    let y = min(uint(normalized.y * float(params.grid_height)), params.grid_height - 1);
    return y * params.grid_width + x;
}
[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    if (index >= params.particle_count || particles[index].grabbed != 0) return;
    let cell = grid_index(particles[index].position);
    uint local_index;
    InterlockedAdd(grid_cursors[cell], 1u, local_index);
    particle_indices[grid_offsets[cell] + local_index] = index;
}
