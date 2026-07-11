#include "common.slang"

[[vk::binding(0, 0)]]
RWStructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
ConstantBuffer<SimParams> params;
[[vk::binding(2, 0)]]
StructuredBuffer<float> force_matrix;
[[vk::binding(3, 0)]]
RWStructuredBuffer<uint> grid_heads;
[[vk::binding(4, 0)]]
RWStructuredBuffer<uint> particle_next;
[[vk::binding(5, 0)]]
ConstantBuffer<GridParams> grid_params;
[[vk::binding(6, 0)]]
RWStructuredBuffer<Particle> particles_out;
[[vk::binding(9, 0)]]
StructuredBuffer<uint> grid_offsets;
[[vk::binding(12, 0)]]
RWStructuredBuffer<float2> far_force_cache;

static uint rng_state;

void init_rng(uint index) {
    rng_state = params.random_seed + index * 1664525u + 1013904223u;
}

uint rand_u32() {
    rng_state = rng_state * 1664525u + 1013904223u;
    return rng_state;
}

float rand_f32() {
    return float(rand_u32()) / 4294967295.0;
}

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

float2 wrapped_distance(float2 pos_a, float2 pos_b) {
    var delta = pos_b - pos_a;
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

float get_force(uint species_a, uint species_b) {
    let index = species_a * params.species_count + species_b;
    return force_matrix[index];
}

float calculate_force(float distance, float attraction) {
    let rmax = params.max_distance;
    let force_multiplier = params.max_force;
    let beta = params.beta;
    let min_dist = 0.001;
    let effective_distance = max(distance, min_dist);
    let beta_rmax = beta * rmax;
    if (distance < beta_rmax) {
        return (effective_distance / beta_rmax - 1.0) * force_multiplier;
    } else if (distance <= rmax) {
        return attraction * (1.0 - (1.0 + beta - 2.0 * distance / rmax) / (1.0 - beta)) * force_multiplier;
    }
    return 0.0;
}

void accumulate_neighbor_force(float2 particle_position, uint particle_species, uint other_index, float near_distance_sq, float sample_weight, inout float2 near_force, inout float2 far_force) {
	let delta = wrapped_distance(particle_position, particles[other_index].position);
    let distance_sq = dot(delta, delta);
    let max_distance_sq = params.max_distance * params.max_distance;
    if (distance_sq > max_distance_sq || distance_sq < 0.000001) {
        return;
    }
    let distance = sqrt(distance_sq);
	let attraction = get_force(particle_species, particles[other_index].species);
    let force_magnitude = calculate_force(distance, attraction);
    let contribution = (delta / distance) * force_magnitude * sample_weight;
    if (distance_sq <= near_distance_sq) {
        near_force += contribution;
    } else {
        far_force += contribution;
    }
}

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    if (index >= params.particle_count) {
        return;
    }

    init_rng(index);

    var particle = particles[index];
    var near_force = float2(0.0, 0.0);
    var far_force = float2(0.0, 0.0);
    let center_cell = world_to_grid(particle.position);
    let radius = int(grid_params.neighbor_radius_cells);
	let cell_width = grid_params.world_width / float(grid_params.grid_width);
	let cell_height = grid_params.world_height / float(grid_params.grid_height);
	let max_distance_sq = params.max_distance * params.max_distance;
    // Refresh complete workgroups together so inactive lanes do not serialize
    // behind active far-field traversal. Particle indices are spatially mixed,
    // so rotating workgroups still distributes refreshes across the world.
    let refresh_stride = max(params.force_refresh_stride, 1u);
    let refresh_phase = params.random_seed % refresh_stride;
    let refresh_far_force = refresh_stride == 1u || ((index / 64u) % refresh_stride) == refresh_phase;
    let near_distance = min(params.max_distance, 0.05);
    let near_distance_sq = near_distance * near_distance;

    for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
			// A particle can sit anywhere in its cell. Even with that conservative
			// allowance, corner cells outside the circular influence range cannot
			// contribute and need no linked-list traversal.
			let cell_distance_x = float(max(abs(dx) - 1, 0)) * cell_width;
			let cell_distance_y = float(max(abs(dy) - 1, 0)) * cell_height;
			let cell_distance_sq = cell_distance_x * cell_distance_x + cell_distance_y * cell_distance_y;
			if (cell_distance_sq > max_distance_sq || (!refresh_far_force && cell_distance_sq > near_distance_sq)) {
				continue;
			}
            var cx = int(center_cell.x) + dx;
            var cy = int(center_cell.y) + dy;
            if (params.wrap_edges == 1) {
                cx = wrap_cell(cx, int(grid_params.grid_width));
                cy = wrap_cell(cy, int(grid_params.grid_height));
            } else if (cx < 0 || cy < 0 || cx >= int(grid_params.grid_width) || cy >= int(grid_params.grid_height)) {
                continue;
            }

			let cell_index = grid_coord_to_index(uint2(uint(cx), uint(cy)));
			let cell_start = grid_offsets[cell_index];
			let cell_count = grid_heads[cell_index];
			let sample_limit = params.force_sample_limit;
			let sample_count = sample_limit == 0u ? cell_count : min(cell_count, sample_limit);
			let sample_weight = sample_count > 0u ? float(cell_count) / float(sample_count) : 1.0;
			// Sparse cells remain exact. Dense cells use evenly spaced samples with a
			// rotating offset, avoiding both a fixed-neighbor bias and unbounded work.
			let sample_offset = cell_count > 0u ? (index * 1664525u + cell_index * 1013904223u + params.random_seed) % cell_count : 0u;
			for (var sample = 0u; sample < sample_count; sample++) {
				let slot = (sample_offset + (sample * cell_count) / sample_count) % cell_count;
				let neighbor_index = particle_next[cell_start + slot];
				if (neighbor_index != index) {
					accumulate_neighbor_force(particle.position, particle.species, neighbor_index, near_distance_sq, sample_weight, near_force, far_force);
				}
			}
        }
    }

    if (refresh_far_force) {
        far_force_cache[index] = far_force;
    } else {
        far_force = far_force_cache[index];
    }
    var force = near_force + far_force;

    if (params.cursor_active > 0) {
        let cursor_pos = float2(params.cursor_x, params.cursor_y);
        let delta_to_cursor = wrapped_distance(particle.position, cursor_pos);
        let distance_to_cursor_sq = dot(delta_to_cursor, delta_to_cursor);
        let cursor_radius_sq = params.cursor_size * params.cursor_size;
        if (distance_to_cursor_sq <= cursor_radius_sq && distance_to_cursor_sq > 0.000001) {
            let distance_to_cursor = sqrt(distance_to_cursor_sq);
            let direction_to_cursor = delta_to_cursor / distance_to_cursor;
            let distance_factor = 1.0 - (distance_to_cursor / params.cursor_size);
            let cursor_force_strength = params.cursor_strength * distance_factor * 2.0;
            if (params.cursor_active == 1) {
                force += direction_to_cursor * cursor_force_strength;
            } else if (params.cursor_active == 2) {
                force -= direction_to_cursor * cursor_force_strength;
            } else if (params.cursor_active == 3) {
                force += float2(-direction_to_cursor.y, direction_to_cursor.x) * cursor_force_strength;
            } else if (params.cursor_active == 4) {
                force += float2(direction_to_cursor.y, -direction_to_cursor.x) * cursor_force_strength;
            }
        }
    }

    if (params.brownian_motion > 0.0) {
        let angle = rand_f32() * 2.0 * 3.14159;
        let magnitude = rand_f32() * params.brownian_motion * params.max_force;
        force += float2(cos(angle) * magnitude, sin(angle) * magnitude);
    }

    let dt = params.dt;
    particle.velocity += force * dt;
    particle.velocity *= pow(params.friction, dt * 60.0);
    particle.position += particle.velocity * dt;

    if (params.wrap_edges == 1) {
        particle.position = wrap_position(particle.position);
    } else {
        let world_min = float2(-params.width, -params.height) * 0.5;
        let world_max = float2(params.width, params.height) * 0.5;
        if (particle.position.x < world_min.x) {
            particle.position.x = world_min.x;
            particle.velocity.x = -particle.velocity.x * 0.8;
        } else if (particle.position.x >= world_max.x) {
            particle.position.x = world_max.x - 0.001;
            particle.velocity.x = -particle.velocity.x * 0.8;
        }
        if (particle.position.y < world_min.y) {
            particle.position.y = world_min.y;
            particle.velocity.y = -particle.velocity.y * 0.8;
        } else if (particle.position.y >= world_max.y) {
            particle.position.y = world_max.y - 0.001;
            particle.velocity.y = -particle.velocity.y * 0.8;
        }
    }

    particles_out[index] = particle;
}
