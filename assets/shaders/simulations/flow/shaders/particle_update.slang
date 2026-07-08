// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/flow/shaders/particle_update.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

#include "../../../common/texture.slang"
#include "../../../common/lut.slang"
#include "common.slang"

[[vk::binding(0, 0)]]
RWStructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
StructuredBuffer<FlowVector> flow_vectors;
[[vk::binding(2, 0)]]
ConstantBuffer<SimParams> sim_params;
[[vk::binding(3, 0)]]
RWTexture2D<float4> trail_map;
[[vk::binding(4, 0)]]
StructuredBuffer<uint> lut_data;
// Per-frame quotas for autospawn and brush, controlled by CPU
struct SpawnControl {

    uint autospawn_allowed;
    uint brush_allowed;
    uint autospawn_count;
    uint brush_count;
};

[[vk::binding(5, 0)]]
RWStructuredBuffer<SpawnControl> spawn_control;

// O(1) bilinear sample of flow direction from a uniform grid
float2 sample_flow_vector(float2 pos) {
    let grid = float(sim_params.flow_field_resolution);
    let tx = clamp((pos.x + 1.0) * 0.5 * (grid - 1.0), 0.0, grid - 1.0);
    let ty = clamp((pos.y + 1.0) * 0.5 * (grid - 1.0), 0.0, grid - 1.0);
    let x0 = uint(floor(tx));
    let y0 = uint(floor(ty));
    let x1 = min(x0 + 1, uint(grid - 1.0));
    let y1 = min(y0 + 1, uint(grid - 1.0));
    let fx = tx - float(x0);
    let fy = ty - float(y0);
    let idx00 = y0 * uint(grid) + x0;
    let idx10 = y0 * uint(grid) + x1;
    let idx01 = y1 * uint(grid) + x0;
    let idx11 = y1 * uint(grid) + x1;
    let v00 = flow_vectors[idx00].direction;
    let v10 = flow_vectors[idx10].direction;
    let v01 = flow_vectors[idx01].direction;
    let v11 = flow_vectors[idx11].direction;
    let v0 = lerp(v00, v10, fx);
    let v1 = lerp(v01, v11, fx);
    return lerp(v0, v1, fy);
}

// Convert world position to trail map coordinates
float2 world_to_trail_coords(float2 world_pos) {
    // Convert from [-1, 1] world space to [0, 1] texture space
    let x = (world_pos.x + 1.0) * 0.5;
    let y = (world_pos.y + 1.0) * 0.5;
    return float2(x, y);
}

// Get color from LUT
float3 get_lut_color(float intensity) {
    let lut_index = clamp(intensity * 255.0, 0.0, 255.0);
    let index = uint(lut_index);
    
    // LUT data format: [r0, r1, ..., r255, g0, g1, ..., g255, b0, b1, ..., b255]
    let r_srgb = float(lut_data[index]) / 255.0;
    let g_srgb = float(lut_data[index + 256]) / 255.0;
    let b_srgb = float(lut_data[index + 512]) / 255.0;
    
    return linear_from_srgb(float3(r_srgb, g_srgb, b_srgb));
}

// Check if a point is inside the particle shape
bool is_inside_particle_shape(float offset_x, float offset_y, float radius, uint shape) {
    let normalized_x = offset_x / radius;
    let normalized_y = offset_y / radius;
    
    switch (shape) {
        case 0: { // Circle
            let dist = sqrt(normalized_x * normalized_x + normalized_y * normalized_y);
            return dist <= 1.0;
        }
        case 1: { // Square
            return abs(normalized_x) <= 1.0 && abs(normalized_y) <= 1.0;
        }
        case 2: { // Triangle
            let triangle_y = normalized_y * 1.732; // Scale Y for equilateral triangle
            return abs(triangle_y) <= 1.0 - abs(normalized_x);
        }
        case 3: { // Star (Flower)
            let angle = atan2(normalized_y, normalized_x);
            let radius_dist = sqrt(normalized_x * normalized_x + normalized_y * normalized_y);
            let star_radius = 1.0;
            let inner_radius = star_radius * 0.4;
            let points = 5.0;
            let angle_per_point = 6.28318 / points;
            let point_angle = (angle + 6.28318) % angle_per_point;
            let point_radius = lerp(inner_radius, star_radius, smoothstep(0.0, angle_per_point * 0.3, point_angle));
            return radius_dist <= point_radius;
        }
        case 4: { // Diamond
            return abs(normalized_x) + abs(normalized_y) <= 1.0;
        }
        default: {
            // Fallback to circle
            let dist = sqrt(normalized_x * normalized_x + normalized_y * normalized_y);
            return dist <= 1.0;
        }
    }
}

// Deposit trail covering the same footprint as the particle size and shape
void deposit_trail(float2 pos, float4 particle_color) {
    let trail_pos = world_to_trail_coords(pos);
    let x_coord = int(trail_pos.x * float(sim_params.trail_map_width));
    let y_coord = int(trail_pos.y * float(sim_params.trail_map_height));

    // Use the on-screen particle size (pixels) as the trail footprint radius
    let particle_radius = int(sim_params.particle_size);

    // Scan the footprint and write with a smooth radial falloff
    for (var dx = -particle_radius; dx <= particle_radius; dx++) {
        for (var dy = -particle_radius; dy <= particle_radius; dy++) {
            let x = clamp(x_coord + dx, 0, int(sim_params.trail_map_width) - 1);
            let y = clamp(y_coord + dy, 0, int(sim_params.trail_map_height) - 1);

            // Respect particle shape when laying trails
            if (!is_inside_particle_shape(float(dx), float(dy), float(particle_radius), sim_params.particle_shape)) {
                continue;
            }

            // Distance-based falloff
            let dist = sqrt(float(dx * dx + dy * dy));
            let max_dist = max(1.0, float(particle_radius));
            let falloff = 1.0 - clamp(dist / max_dist, 0.0, 1.0);

            let current = LoadTexture(trail_map, int2(x, y));
            let deposition_strength = sim_params.trail_deposition_rate * falloff;
            let new_intensity = clamp(current.a + deposition_strength, 0.0, 1.0);

            var final_color = current.rgb;
            if (sim_params.trail_deposition_rate >= 0.99) {
                final_color = particle_color.rgb;
            } else {
                let total_weight = current.a + deposition_strength;
                final_color = (current.rgb * current.a + particle_color.rgb * deposition_strength) / max(total_weight, 1e-6);
            }

            StoreTexture(trail_map, int2(x, y), float4(final_color, new_intensity));
        }
    }
}

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let particle_index = global_id.x;
    
    // Only process particles within the total pool size
    if (particle_index >= sim_params.total_pool_size) {
        return;
    }
    
    var particle = particles[particle_index];
    
    // Update age for all particles using actual delta time
    particle.age += sim_params.delta_time;
    
    // Check if particle should be reset due to age
    var should_reset = particle.age >= sim_params.particle_lifetime;
    float spawn_x;
    float spawn_y;
    
    // Unified spawning logic based on spawn_type
    if (particle.spawn_type == 0) {
        // Autospawn particles
        if (sim_params.particle_autospawn == 1 && particle.is_alive == 0) {
            // Probabilistic autospawn: expected spawns this frame = rate * dt across the pool
            let dt = sim_params.delta_time;
            let expected_spawns = float(sim_params.autospawn_rate) * dt;
            let pool = max(1, sim_params.autospawn_pool_size);
            // Adjust probability by estimating number of dead particles to maintain target rate as pool fills
            let expected_alive = min(float(sim_params.autospawn_rate) * sim_params.particle_lifetime, float(pool));
            let estimated_dead = max(1.0, float(pool) - expected_alive);
            let p = clamp(expected_spawns / estimated_dead, 0.0, 1.0);
            // Deterministic per-frame random using a frame index seed
            let frame_idx = floor(sim_params.time / max(dt, 1e-6));
            let seed = float(particle_index) * 2.71828 + frame_idx;
            let randv = frac(sin(seed) * 43758.5453);

            if (randv < p) {
                // Claim an autospawn ticket to cap spawns this frame
                uint ticket;
                InterlockedAdd(spawn_control[0].autospawn_count, 1, ticket);
                if (ticket >= spawn_control[0].autospawn_allowed) {
                    // Quota exhausted: do not spawn
                    particle.position = float2(0.0, 0.0);
                    particle.age = 0.0;
                    particle.lut_index = 0;
                    particle.is_alive = 0;
                    particles[particle_index] = particle;
                    return;
                }
                // Spawn at random position in world space
                let random_x = float(particle_index) * 0.1234 + sim_params.time * 0.1;
                let random_y = float(particle_index) * 0.5678 + sim_params.time * 0.1;
                spawn_x = frac(sin(random_x) * 43758.5453) * 2.0 - 1.0;
                spawn_y = frac(cos(random_y) * 43758.5453) * 2.0 - 1.0;
                should_reset = true; // Force spawn
            } else {
                // Don't spawn yet - keep particle dead
                particle.position = float2(0.0, 0.0);
                particle.age = 0.0;
                particle.lut_index = 0;
                particle.is_alive = 0;
                particles[particle_index] = particle;
                return;
            }
        } else if (particle.is_alive == 1) {
            // Particle is alive - continue normally
            if (should_reset) {
                // Particle is dying - zero out particle
                particle.position = float2(0.0, 0.0);
                particle.age = 0.0;
                particle.lut_index = 0;
                particle.is_alive = 0;
                particles[particle_index] = particle;
                return;
            } else {
                // Particle continues normally
                spawn_x = particle.position.x;
                spawn_y = particle.position.y;
            }
        } else {
            // Autospawn disabled or particle is dead - keep dead
            particle.position = float2(0.0, 0.0);
            particle.age = 0.0;
            particle.lut_index = 0;
            particle.is_alive = 0;
            particles[particle_index] = particle;
            return;
        }
    } else {
        // Brush particles (spawn_type == 1)
        if (sim_params.mouse_button_down == 1 && particle.is_alive == 0) {
            // Left click is held - probabilistic spawn so total matches brush_spawn_rate
            // Expected spawns this frame = rate * dt
            let dt = sim_params.delta_time;
            let expected_spawns = float(sim_params.brush_spawn_rate) * dt;
            let pool = max(1, sim_params.brush_pool_size);
            // Adjust probability by estimating number of dead particles to maintain target rate as pool fills
            let expected_alive = min(float(sim_params.brush_spawn_rate) * sim_params.particle_lifetime, float(pool));
            let estimated_dead = max(1.0, float(pool) - expected_alive);
            let p = clamp(expected_spawns / estimated_dead, 0.0, 1.0);
            // Deterministic per-frame random for brush spawning
            let frame_idx = floor(sim_params.time / max(dt, 1e-6));
            let seed = float(particle_index) * 3.14159 + frame_idx;
            let randv = frac(sin(seed) * 43758.5453);

            if (randv < p) {
                // Claim a brush ticket to cap spawns this frame
                uint ticket;
                InterlockedAdd(spawn_control[0].brush_count, 1, ticket);
                if (ticket >= spawn_control[0].brush_allowed) {
                    // Quota exhausted: do not spawn
                    particle.position = float2(0.0, 0.0);
                    particle.age = 0.0;
                    particle.lut_index = 0;
                    particle.is_alive = 0;
                    particles[particle_index] = particle;
                    return;
                }
                // Spawn at cursor with random offset (spray can effect)
                let radius = sim_params.cursor_size;
                let seed1 = float(particle_index) * 0.1234 + sim_params.time * 0.1;
                let seed2 = float(particle_index) * 0.5678 + sim_params.time * 0.05;
                let angle = frac(sin(seed1) * 43758.5453) * 2.0 * 3.14159;
                let distance = frac(cos(seed2) * 43758.5453);
                let offset_x = cos(angle) * radius * distance;
                let offset_y = sin(angle) * radius * distance;
                spawn_x = sim_params.cursor_x + offset_x;
                spawn_y = sim_params.cursor_y + offset_y;
                should_reset = true; // Force spawn
            } else {
                // Don't spawn yet - keep particle dead
                particle.position = float2(0.0, 0.0);
                particle.age = 0.0;
                particle.lut_index = 0;
                particle.is_alive = 0;
                particles[particle_index] = particle;
                return;
            }
        } else if (particle.is_alive == 1) {
            // Particle is alive - continue normally
            if (should_reset) {
                // Particle is dying - zero out particle
                particle.position = float2(0.0, 0.0);
                particle.age = 0.0;
                particle.lut_index = 0;
                particle.is_alive = 0;
                particles[particle_index] = particle;
                return;
            } else {
                // Particle continues normally
                spawn_x = particle.position.x;
                spawn_y = particle.position.y;
            }
        } else {
            // Particle is dead and left click is not held - keep dead
            particle.position = float2(0.0, 0.0);
            particle.age = 0.0;
            particle.lut_index = 0;
            particle.is_alive = 0;
            particles[particle_index] = particle;
            return;
        }
    }
    
    // Reset particle if needed
    if (should_reset) {
        particle.position = float2(spawn_x, spawn_y);
        particle.age = 0.0;
        particle.is_alive = 1; // Mark as active when spawning
    }
    
    // Set particle LUT index based on display mode (every frame to handle mode changes)
    if (sim_params.display_mode == 0) {
        // Age mode: no per-particle index needed; compute from age when rendering
        particle.lut_index = 0;
    } else if (sim_params.display_mode == 1) {
        // Random mode: stable random per particle based on index
        let seed = float(particle_index) * 0.1234;
        let random_value = frac(sin(seed) * 43758.5453);
        particle.lut_index = uint(clamp(random_value * 255.0, 0.0, 255.0));
    } else if (sim_params.display_mode == 2) {
        // Direction mode: will set after computing direction below
        // Initialize to 0 to avoid undefined data
        particle.lut_index = 0;
    }
    
    // Get flow direction with O(1) bilinear sample
    var direction = sample_flow_vector(particle.position);
    
    // Update particle LUT index based on display mode
    if (sim_params.display_mode == 2) { // Direction mode
        // Set LUT index based on velocity direction
        let direction_angle = atan2(direction.y, direction.x);
        let normalized_angle = (direction_angle + 3.14159) / (2.0 * 3.14159); // Normalize to [0, 1]
        particle.lut_index = uint(clamp(normalized_angle * 255.0, 0.0, 255.0));
    }
    
    // Apply cursor interaction if active (right click destroys particles)
    if (sim_params.mouse_button_down == 2) {
        // Right click destroy mode - destroy particles near cursor
        let cursor_pos = float2(sim_params.cursor_x, sim_params.cursor_y);
        let to_cursor = cursor_pos - particle.position;
        let cursor_dist = length(to_cursor);
        let cursor_radius = sim_params.cursor_size; // World units
        
        if (cursor_dist < cursor_radius) {
            // Zero out particle when destroyed
            particle.position = float2(0.0, 0.0);
            particle.age = 0.0;
            particle.lut_index = 0;
            particle.is_alive = 0;
            particles[particle_index] = particle;
            return;
        }
    }
    
    // Move particle along flow direction using delta time
    particle.position += direction * sim_params.particle_speed * sim_params.delta_time;
    
    // Wrap around edges
    particle.position.x = frac(particle.position.x * 0.5 + 0.5) * 2.0 - 1.0;
    particle.position.y = frac(particle.position.y * 0.5 + 0.5) * 2.0 - 1.0;
    
    // Deposit trail at particle position with LUT color based on display mode
    var trail_color_intensity = 0.0;
    
    if (sim_params.display_mode == 0) { // Age mode
        let age_ratio = particle.age / sim_params.particle_lifetime;
        trail_color_intensity = 1.0 - age_ratio; // Younger particles = higher intensity
    } else if (sim_params.display_mode == 1) { // Random mode
        trail_color_intensity = float(particle.lut_index) / 255.0;
    } else if (sim_params.display_mode == 2) { // Direction mode
        trail_color_intensity = float(particle.lut_index) / 255.0;
    } else {
        // Fallback to age mode
        let age_ratio = particle.age / sim_params.particle_lifetime;
        trail_color_intensity = 1.0 - age_ratio;
    }
    
    let trail_color = get_lut_color(trail_color_intensity);
    // Alpha is not used by deposit_trail (intensity is computed internally), pass placeholder
    deposit_trail(particle.position, float4(trail_color, 1.0));
    
    // No stored alpha; visual alpha is computed in render from age
    
    particles[particle_index] = particle;
} 
