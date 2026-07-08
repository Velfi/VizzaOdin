struct Particle {
    float2 position;
    float2 velocity;
    uint species;
    uint _pad;
};

struct SimParams {
    uint particle_count;
    uint species_count;
    float max_force;
    float max_distance;
    float friction;
    uint wrap_edges;
    float width;
    float height;
    uint random_seed;
    float dt;
    float beta;
    float cursor_x;
    float cursor_y;
    float cursor_size;
    float cursor_strength;
    uint cursor_active;
    float brownian_motion;
    float particle_size;
    float aspect_ratio;
    uint _pad1;
};

struct GridParams {
    uint particle_count;
    uint grid_width;
    uint grid_height;
    uint neighbor_radius_cells;
    float cell_size;
    float world_min_x;
    float world_min_y;
    float world_width;
    float world_height;
    float _pad0;
    float _pad1;
};

[[vk::binding(1, 0)]]
ConstantBuffer<SimParams> params;
[[vk::binding(3, 0)]]
RWStructuredBuffer<uint> grid_heads;
[[vk::binding(4, 0)]]
RWStructuredBuffer<uint> particle_next;
[[vk::binding(5, 0)]]
ConstantBuffer<GridParams> grid_params;
[[vk::binding(6, 0)]]
RWStructuredBuffer<Particle> particles_predicted;

uint2 world_to_grid(float2 pos) {
    let normalized = (pos - float2(grid_params.world_min_x, grid_params.world_min_y)) / float2(grid_params.world_width, grid_params.world_height);
    return uint2(
        min(uint(max(normalized.x, 0.0) * float(grid_params.grid_width)), grid_params.grid_width - 1),
        min(uint(max(normalized.y, 0.0) * float(grid_params.grid_height)), grid_params.grid_height - 1)
    );
}

uint grid_coord_to_index(uint2 coord) {
    return coord.y * grid_params.grid_width + coord.x;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    if (index >= params.particle_count) {
        return;
    }

    let particle = particles_predicted[index];
    let coord = world_to_grid(particle.position);
    let cell_index = grid_coord_to_index(coord);

    uint old_head;
    InterlockedExchange(grid_heads[cell_index], index, old_head);
    particle_next[index] = old_head;
}
