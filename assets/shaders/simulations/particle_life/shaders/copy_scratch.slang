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

[[vk::binding(0, 0)]]
RWStructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
ConstantBuffer<SimParams> params;
[[vk::binding(6, 0)]]
StructuredBuffer<Particle> particles_in;

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    if (index >= params.particle_count) {
        return;
    }
    particles[index] = particles_in[index];
}
