// Pellets single-traversal semi-implicit Euler physics.

struct Particle {
    float2 position;
    float2 velocity;
    float mass;
    float radius;
    uint clump_id;
    float density;
    uint grabbed;
    uint _pad0;
    float2 previous_position;
};

struct PhysicsParams {
    float2 mouse_position;
    float2 mouse_velocity;
    uint particle_count;
    float gravitational_constant;
    float energy_damping;
    float collision_damping;
    float dt;
    float gravity_softening;
    float interaction_radius;
    uint mouse_pressed;
    uint mouse_mode;
    float cursor_size;
    float cursor_strength;
    float particle_size;
    float aspect_ratio;
    uint density_damping_enabled;
    float overlap_resolution_strength;
    uint frame_index;
    uint coloring_mode;
    float density_radius;
};

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

[[vk::binding(0, 0)]] RWStructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]] ConstantBuffer<PhysicsParams> params;
[[vk::binding(2, 0)]] StructuredBuffer<uint> particle_indices;
[[vk::binding(3, 0)]] ConstantBuffer<GridParams> grid_params;
[[vk::binding(4, 0)]] StructuredBuffer<uint> grid_counts;
[[vk::binding(5, 0)]] StructuredBuffer<uint> grid_offsets;

uint2 world_to_grid(float2 pos) {
    let normalized = (pos + float2(1.0, 1.0)) * 0.5;
    return uint2(
        min(uint(normalized.x * float(grid_params.grid_width)), grid_params.grid_width - 1),
        min(uint(normalized.y * float(grid_params.grid_height)), grid_params.grid_height - 1));
}

uint grid_coord_to_index(uint2 coord) {
    return coord.y * grid_params.grid_width + coord.x;
}

float2 toroidal_delta(float2 from, float2 to) {
    var delta = to - from;
    if (abs(delta.x) > 1.0) delta.x -= sign(delta.x) * 2.0;
    if (abs(delta.y) > 1.0) delta.y -= sign(delta.y) * 2.0;
    return delta;
}

float2 safe_normalize(float2 value) {
    let length_sq = dot(value, value);
    if (length_sq <= 1e-12) return float2(0.0);
    return value * rsqrt(length_sq);
}

float2 mouse_acceleration(Particle particle) {
    if (params.mouse_pressed == 0) return float2(0.0);
    let delta = params.mouse_position - particle.position;
    let corrected = float2(delta.x * params.aspect_ratio, delta.y);
    let distance = length(corrected);
    if (distance > params.cursor_size || distance < 1e-6) return float2(0.0);
    let force = params.cursor_strength * (1.0 - distance / params.cursor_size);
    let direction = safe_normalize(delta);
    if (params.mouse_mode == 1) return direction * force;
    if (params.mouse_mode == 2) {
        let screen_direction = safe_normalize(corrected);
        let tangent = safe_normalize(float2(-screen_direction.y / max(params.aspect_ratio, 1e-6), screen_direction.x));
        return (direction + tangent * 0.8) * force;
    }
    return float2(0.0);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    if (index >= params.particle_count) return;
    var particle = particles[index];

    if (params.mouse_pressed != 0 && params.mouse_mode == 1) {
        let delta = params.mouse_position - particle.position;
        let corrected = float2(delta.x * params.aspect_ratio, delta.y);
        if (dot(corrected, corrected) <= params.cursor_size * params.cursor_size) {
            if (particle.grabbed == 0) particle.previous_position = particle.position - params.mouse_position;
            particle.grabbed = 1;
        }
    } else {
        if (particle.grabbed != 0) particle.velocity = params.mouse_velocity * params.cursor_strength * 2.0;
        particle.grabbed = 0;
    }

    if (params.mouse_pressed != 0 && params.mouse_mode >= 3) {
        let delta = params.mouse_position - particle.position;
        let corrected = float2(delta.x * params.aspect_ratio, delta.y);
        let distance = length(corrected);
        if (distance > 1e-6 && distance <= params.cursor_size) {
            let falloff = 1.0 - distance / params.cursor_size;
            var direction = safe_normalize(delta);
            if (params.mouse_mode == 4 || params.mouse_mode == 6) direction = -direction;
            let burst = params.mouse_mode >= 5 ? 5.0 : 1.0;
            particle.velocity += direction * params.cursor_strength * falloff * burst * params.dt;
        }
    }

    if (particle.grabbed != 0) {
        particle.position = params.mouse_position + particle.previous_position;
        particle.velocity = float2(0.0);
        if (particle.position.x > 1.0) particle.position.x -= 2.0;
        else if (particle.position.x < -1.0) particle.position.x += 2.0;
        if (particle.position.y > 1.0) particle.position.y -= 2.0;
        else if (particle.position.y < -1.0) particle.position.y += 2.0;
        particles[index] = particle;
        return;
    }

    var acceleration = mouse_acceleration(particle);
    var collision_impulse = float2(0.0);
    var separation = float2(0.0);
    var total_overlap = 0.0;
    var overlap_count = 0u;
    var nearby_velocity = float2(0.0);
    var nearby_count = 0u;
    var visual_density = 0.0;

    let density_active = params.coloring_mode == 0;
    let search_radius = max(params.interaction_radius, density_active ? params.density_radius : 0.0);
    let cell_radius = max(int(ceil(search_radius / grid_params.cell_size)), 1);
    let density_radius_sq = params.density_radius * params.density_radius;
    let damping_radius_sq = params.particle_size * params.particle_size * 4.0;
    let combined_radius = params.particle_size * 2.0;
    let collision_radius_sq = combined_radius * combined_radius;
    let center = world_to_grid(particle.position);

    for (var dy = -cell_radius; dy <= cell_radius; dy++) {
        for (var dx = -cell_radius; dx <= cell_radius; dx++) {
            let cx = (int(center.x) + dx + int(grid_params.grid_width)) % int(grid_params.grid_width);
            let cy = (int(center.y) + dy + int(grid_params.grid_height)) % int(grid_params.grid_height);
            let cell = grid_coord_to_index(uint2(uint(cx), uint(cy)));
            let start = grid_offsets[cell];
            let count = grid_counts[cell];
            for (var k = 0u; k < count; k++) {
                let other_index = particle_indices[start + k];
                if (other_index == index) continue;
                let other = particles[other_index];
                let delta = toroidal_delta(particle.position, other.position);
                let distance_sq = dot(delta, delta);

                if (density_active && distance_sq < density_radius_sq) visual_density += 1.0 / (1.0 + distance_sq);
                if (params.density_damping_enabled != 0 && distance_sq < damping_radius_sq) {
                    nearby_velocity += other.velocity;
                    nearby_count += 1u;
                }

                if (distance_sq > params.interaction_radius * params.interaction_radius || distance_sq < 1e-12) continue;
                let corrected = float2(delta.x * params.aspect_ratio, delta.y);
                let corrected_sq = dot(corrected, corrected);
                let distance = sqrt(max(distance_sq, 1e-12));

                if (params.gravitational_constant > 0.0) {
                    let softened_sq = distance_sq + params.gravity_softening * params.gravity_softening;
                    let direction = delta / sqrt(softened_sq);
                    let falloff = max((params.interaction_radius - distance) / max(params.interaction_radius, 1e-6), 0.0);
                    acceleration += direction * (params.gravitational_constant * other.mass / softened_sq) * falloff * 2.0;
                }

                if (corrected_sq < collision_radius_sq && corrected_sq > 1e-12) {
                    let corrected_distance = sqrt(corrected_sq);
                    let normal_screen = corrected / corrected_distance;
                    let normal = safe_normalize(float2(normal_screen.x / max(params.aspect_ratio, 1e-6), normal_screen.y));
                    let relative_velocity = particle.velocity - other.velocity;
                    let along_normal = dot(relative_velocity, normal);
                    if (along_normal < 0.0) {
                        collision_impulse += normal * (-along_normal) * min(params.collision_damping, 0.98);
                    }
                    let overlap = combined_radius - corrected_distance;
                    if (overlap > 0.0) {
                        separation -= normal * overlap;
                        total_overlap += overlap;
                        overlap_count += 1u;
                    }
                }
            }
        }
    }

    acceleration += collision_impulse;
    particle.velocity += acceleration * params.dt;
    particle.velocity *= params.energy_damping;
    if (params.density_damping_enabled != 0 && nearby_count > 0u) {
        let local_velocity = nearby_velocity / float(nearby_count);
        let factor = min(float(nearby_count) / 10.0, 1.0) * 0.1;
        particle.velocity = local_velocity + (particle.velocity - local_velocity) * (1.0 - factor);
    }

    let max_velocity = min(5.0, 0.8 * params.particle_size / max(params.dt, 1e-4));
    let speed = length(particle.velocity);
    if (speed > max_velocity) particle.velocity *= max_velocity / speed;
    particle.position += particle.velocity * params.dt;

    if (overlap_count > 0u && total_overlap > params.particle_size * 0.003) {
        let separation_length_sq = dot(separation, separation);
        if (separation_length_sq > 1e-12) {
            let direction = separation * rsqrt(separation_length_sq);
            let average_overlap = total_overlap / float(overlap_count);
            let correction = min(average_overlap * params.overlap_resolution_strength * 1.5, params.particle_size * 0.8);
            particle.position += direction * correction;
        }
    }

    if (particle.position.x > 1.0) particle.position.x -= 2.0;
    else if (particle.position.x < -1.0) particle.position.x += 2.0;
    if (particle.position.y > 1.0) particle.position.y -= 2.0;
    else if (particle.position.y < -1.0) particle.position.y += 2.0;

    if (params.coloring_mode == 0) particle.density = visual_density;
    else if (params.coloring_mode == 1) particle.density = length(particle.velocity) * 4.0;
    else {
        let seed = float(index) * 0.1234;
        particle.density = frac(sin(seed) * 43758.5453) * 255.0;
    }
    particles[index] = particle;
}
