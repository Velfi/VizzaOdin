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

struct CollisionParams {
    uint enabled;
    uint iterations;
    uint _pad0;
    uint _pad1;
    float min_distance;
    float relaxation;
    float max_correction;
    float velocity_damping;
};

[[vk::binding(0, 0)]]
RWStructuredBuffer<Particle> particles_old;
[[vk::binding(1, 0)]]
ConstantBuffer<SimParams> params;
[[vk::binding(6, 0)]]
RWStructuredBuffer<Particle> particles_predicted;
[[vk::binding(7, 0)]]
RWStructuredBuffer<float2> corrections;
[[vk::binding(8, 0)]]
ConstantBuffer<CollisionParams> collision;

float2 wrap_position(float2 pos) {
    if (params.wrap_edges == 0) {
        return pos;
    }
    let world_size = float2(params.width, params.height);
    let half_world = world_size * 0.5;
    var wrapped = pos + half_world;
    wrapped = wrapped - floor(wrapped / world_size) * world_size;
    return wrapped - half_world;
}

float2 wrapped_displacement(float2 from_pos, float2 to_pos) {
    var delta = to_pos - from_pos;
    if (params.wrap_edges == 1) {
        let world_size = float2(params.width, params.height);
        let half_world = world_size * 0.5;
        if (delta.x > half_world.x) {
            delta.x -= world_size.x;
        } else if (delta.x < -half_world.x) {
            delta.x += world_size.x;
        }
        if (delta.y > half_world.y) {
            delta.y -= world_size.y;
        } else if (delta.y < -half_world.y) {
            delta.y += world_size.y;
        }
    }
    return delta;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    if (index >= params.particle_count) {
        return;
    }

    var particle = particles_predicted[index];
    if (collision.enabled != 0) {
        particle.position += corrections[index] * collision.relaxation;
    }

    if (params.wrap_edges == 1) {
        particle.position = wrap_position(particle.position);
    } else {
        let world_min = float2(-params.width, -params.height) * 0.5;
        let world_max = float2(params.width, params.height) * 0.5;
        if (particle.position.x < world_min.x) {
            particle.position.x = world_min.x;
        } else if (particle.position.x >= world_max.x) {
            particle.position.x = world_max.x - 0.001;
        }
        if (particle.position.y < world_min.y) {
            particle.position.y = world_min.y;
        } else if (particle.position.y >= world_max.y) {
            particle.position.y = world_max.y - 0.001;
        }
    }

    let dt = max(params.dt, 0.000001);
    var displacement = wrapped_displacement(particles_old[index].position, particle.position);
    let max_displacement = max(params.max_distance * 2.0, collision.min_distance * 8.0);
    let displacement_sq = dot(displacement, displacement);
    if (displacement_sq > max_displacement * max_displacement) {
        displacement *= max_displacement / sqrt(displacement_sq);
    }
    particle.velocity = displacement / dt;
    particle.velocity *= collision.velocity_damping;
    particles_predicted[index] = particle;
}
