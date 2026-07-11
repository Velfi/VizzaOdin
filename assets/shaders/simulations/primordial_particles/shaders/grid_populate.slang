struct Particle { float2 position; float2 previous_position; float heading; float velocity; float density; uint grabbed; };
struct SimParams {
    float2 mouse_position; float2 mouse_velocity;
    float alpha; float beta; float velocity; float radius;
    float dt; float width; float height; uint wrap_edges;
    uint particle_count; uint mouse_pressed; uint mouse_mode; float cursor_size;
    float cursor_strength; float aspect_ratio; uint grid_axis; float grid_cell_size;
};
[[vk::binding(0, 0)]] StructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]] RWStructuredBuffer<uint> grid_heads;
[[vk::binding(2, 0)]] RWStructuredBuffer<uint> grid_next;
[[vk::binding(3, 0)]] ConstantBuffer<SimParams> params;

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 id : SV_DispatchThreadID) {
    if (id.x >= params.particle_count) return;
    let p = particles[id.x].position;
    let axis = params.grid_axis;
    let x = min(uint(clamp((p.x + 1.0) / params.grid_cell_size, 0.0, float(axis - 1))), axis - 1);
    let y = min(uint(clamp((p.y + 1.0) / params.grid_cell_size, 0.0, float(axis - 1))), axis - 1);
    uint previous;
    InterlockedExchange(grid_heads[y * axis + x], id.x, previous);
    grid_next[id.x] = previous;
}
