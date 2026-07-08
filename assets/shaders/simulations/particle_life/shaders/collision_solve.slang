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
[[vk::binding(7, 0)]]
RWStructuredBuffer<float2> corrections;
[[vk::binding(8, 0)]]
ConstantBuffer<CollisionParams> collision;

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

int wrap_cell(int value, int axis) {
    var wrapped = value % axis;
    if (wrapped < 0) {
        wrapped += axis;
    }
    return wrapped;
}

float2 wrapped_delta_away(float2 pos_i, float2 pos_j) {
    var delta = pos_i - pos_j;
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

float2 fallback_direction(uint index, uint other_index) {
    let low = min(index, other_index);
    let high = max(index, other_index);
    var seed = low * 1664525u + high * 1013904223u + params.random_seed;
    seed = seed * 1664525u + 1013904223u;
    let angle = (float(seed) / 4294967295.0) * 6.28318530718;
    let direction = float2(cos(angle), sin(angle));
    return index == low ? direction : -direction;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    if (index >= params.particle_count || collision.enabled == 0) {
        if (index < params.particle_count) {
            corrections[index] = float2(0.0, 0.0);
        }
        return;
    }

    let particle = particles_predicted[index];
    let center_cell = world_to_grid(particle.position);
    let min_distance = max(collision.min_distance, 0.0001);
    let min_distance_sq = min_distance * min_distance;
    var correction = float2(0.0, 0.0);

    for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
            var cx = int(center_cell.x) + dx;
            var cy = int(center_cell.y) + dy;
            if (params.wrap_edges == 1) {
                cx = wrap_cell(cx, int(grid_params.grid_width));
                cy = wrap_cell(cy, int(grid_params.grid_height));
            } else if (cx < 0 || cy < 0 || cx >= int(grid_params.grid_width) || cy >= int(grid_params.grid_height)) {
                continue;
            }

            var neighbor_index = grid_heads[grid_coord_to_index(uint2(uint(cx), uint(cy)))];
            var guard = 0u;
            while (neighbor_index != 0xffffffffu && guard < params.particle_count) {
                if (neighbor_index != index) {
                    let other = particles_predicted[neighbor_index];
                    var delta = wrapped_delta_away(particle.position, other.position);
                    let distance_sq = dot(delta, delta);
                    if (distance_sq < min_distance_sq) {
                        var normal = fallback_direction(index, neighbor_index);
                        var distance = 0.0;
                        if (distance_sq > 0.00000001) {
                            distance = sqrt(distance_sq);
                            normal = delta / distance;
                        }
                        correction += normal * (min_distance - distance) * 0.5;
                    }
                }
                neighbor_index = particle_next[neighbor_index];
                guard += 1u;
            }
        }
    }

    let length_sq = dot(correction, correction);
    let max_correction = max(collision.max_correction, 0.0);
    if (max_correction > 0.0 && length_sq > max_correction * max_correction) {
        correction = correction * (max_correction / sqrt(length_sq));
    }
    corrections[index] = correction;
}
