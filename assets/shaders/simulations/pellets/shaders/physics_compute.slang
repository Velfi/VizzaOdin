// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/pellets/shaders/physics_compute.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Fourth Order Runge-Kutta GPU Physics for Pellets with Spatial Partitioning
// 
// Pixel-Perfect Collision System with 3 Phases:
// 1. Broad Phase: Spatial grid filtering to eliminate distant particles
// 2. Narrow Phase: Precise circle-circle collision detection with elastic response
// 3. Overlap Resolution: Separate any overlapping particles after integration
//
// Spatial Partitioning: Uses a uniform grid to reduce O(n²) complexity to O(n)
// for neighbor lookups, dramatically improving performance with large particle counts.

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

struct GridCell {

    uint particle_count;
    uint[64] particle_indices;
};

[[vk::binding(0, 0)]]
RWStructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
ConstantBuffer<PhysicsParams> params;
[[vk::binding(2, 0)]]
StructuredBuffer<GridCell> grid;
[[vk::binding(3, 0)]]
ConstantBuffer<GridParams> grid_params;
// Atomic per-cell particle counts for deterministic neighbor iteration
[[vk::binding(4, 0)]]
StructuredBuffer<uint> grid_counts;

// Convert world position to grid coordinates
uint2 world_to_grid(float2 pos) {
    let normalized_pos = (pos + float2(1.0, 1.0)) * 0.5;
    let grid_x = uint(normalized_pos.x * float(grid_params.grid_width));
    let grid_y = uint(normalized_pos.y * float(grid_params.grid_height));
    
    return uint2(
        min(grid_x, grid_params.grid_width - 1),
        min(grid_y, grid_params.grid_height - 1)
    );
}

// Get grid cell index from coordinates
uint grid_coord_to_index(uint2 coord) {
    return coord.y * grid_params.grid_width + coord.x;
}

// Stream neighbors from 3x3 grid neighborhood and apply a callback-like operation
// (Removed obsolete helper placeholder; loops are inlined where needed.)
// Note: WGSL does not support function pointers. We'll inline neighbor loops where needed below.

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    if (index >= params.particle_count) {
        return;
    }

    var particle = particles[index];
    
    // Grab remains mode 1. Higher pairs are transient force instruments.
    if (params.mouse_pressed != 0 && params.mouse_mode == 1) {
        let delta = params.mouse_position - particle.position;
        let aspect_corrected_delta = float2(delta.x * params.aspect_ratio, delta.y);
        let distance_sq = dot(aspect_corrected_delta, aspect_corrected_delta);
        let cursor_radius_sq = params.cursor_size * params.cursor_size;
        
        if (distance_sq <= cursor_radius_sq) {
            if (particle.grabbed == 0) {
                particle.previous_position = particle.position - params.mouse_position;
            }
            particle.grabbed = 1;
        }
    } else {
        if (particle.grabbed != 0) {
            particle.velocity = params.mouse_velocity * params.cursor_strength * 2.0;
        }
        particle.grabbed = 0;
    }

    if (params.mouse_pressed != 0 && params.mouse_mode >= 3) {
        let delta = params.mouse_position - particle.position;
        let corrected = float2(delta.x * params.aspect_ratio, delta.y);
        let distance = length(corrected);
        if (distance > 1e-6 && distance <= params.cursor_size) {
            let falloff = 1.0 - distance / params.cursor_size;
            var direction = normalize(delta);
            if (params.mouse_mode == 4 || params.mouse_mode == 6) { direction = -direction; }
            let burst = params.mouse_mode >= 5 ? 5.0 : 1.0;
            particle.velocity += direction * params.cursor_strength * falloff * burst * params.dt;
        }
    }
    
    // Handle grabbed particles
    if (particle.grabbed != 0) {
        particle.position = params.mouse_position + particle.previous_position;
        particle.velocity = float2(0.0, 0.0);
        
        resolve_collisions(particle, index);
        
        // Apply boundary conditions (toroidal wrapping)
        if (particle.position.x > 1.0) {
            particle.position.x -= 2.0;
        } else if (particle.position.x < -1.0) {
            particle.position.x += 2.0;
        }
        
        if (particle.position.y > 1.0) {
            particle.position.y -= 2.0;
        } else if (particle.position.y < -1.0) {
            particle.position.y += 2.0;
        }
        
        particles[index] = particle;
        return;
    }
    
    // Normal physics integration for non-grabbed particles
    // Fourth Order Runge-Kutta Integration
    let k1_pos = particle.velocity;
    let k1_vel = compute_acceleration(particle, index);
    
    var temp_particle = particle;
    temp_particle.position = particle.position + k1_pos * (params.dt * 0.5);
    temp_particle.velocity = particle.velocity + k1_vel * (params.dt * 0.5);
    let k2_pos = temp_particle.velocity;
    let k2_vel = compute_acceleration(temp_particle, index);
    
    temp_particle.position = particle.position + k2_pos * (params.dt * 0.5);
    temp_particle.velocity = particle.velocity + k2_vel * (params.dt * 0.5);
    let k3_pos = temp_particle.velocity;
    let k3_vel = compute_acceleration(temp_particle, index);
    
    temp_particle.position = particle.position + k3_pos * params.dt;
    temp_particle.velocity = particle.velocity + k3_vel * params.dt;
    let k4_pos = temp_particle.velocity;
    let k4_vel = compute_acceleration(temp_particle, index);
    
    particle.position += (params.dt / 6.0) * (k1_pos + 2.0 * k2_pos + 2.0 * k3_pos + k4_pos);
    particle.velocity += (params.dt / 6.0) * (k1_vel + 2.0 * k2_vel + 2.0 * k3_vel + k4_vel);
    
    // Apply energy damping from settings (retention factor)
    particle.velocity *= params.energy_damping;
    
    // Density-based velocity damping only if enabled, using grid neighbors
    if (params.density_damping_enabled != 0) {
        var nearby_count = 0;
        let center_cell = world_to_grid(particle.position);
        let particle_radius = params.particle_size;
        let nearby_radius_sq = particle_radius * particle_radius * 4.0;
        for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
                let cx = (int(center_cell.x) + dx + int(grid_params.grid_width)) % int(grid_params.grid_width);
                let cy = (int(center_cell.y) + dy + int(grid_params.grid_height)) % int(grid_params.grid_height);
                let cell_index = grid_coord_to_index(uint2(uint(cx), uint(cy)));
                let count = grid_counts[cell_index];
                for (var k = 0; k < min(count, 64); k++) {
                    let j = grid[cell_index].particle_indices[k];
                    if (j == index) { continue; }
                    let other = particles[j];
                    var delta = other.position - particle.position;
                    if (abs(delta.x) > 1.0) { delta.x = delta.x - sign(delta.x) * 2.0; }
                    if (abs(delta.y) > 1.0) { delta.y = delta.y - sign(delta.y) * 2.0; }
                    let distance_sq = dot(delta, delta);
                    if (distance_sq < nearby_radius_sq) { nearby_count += 1; }
                }
            }
        }
        let density_factor = min(float(nearby_count) / 10.0, 1.0);
        let velocity_damping = 1.0 - density_factor * 0.1;
        particle.velocity *= velocity_damping;
    }
    
    // Overlap resolution
    resolve_collisions(particle, index);
    
    // Boundary conditions (toroidal wrapping)
    if (particle.position.x > 1.0) {
        particle.position.x -= 2.0;
    } else if (particle.position.x < -1.0) {
        particle.position.x += 2.0;
    }
    
    if (particle.position.y > 1.0) {
        particle.position.y -= 2.0;
    } else if (particle.position.y < -1.0) {
        particle.position.y += 2.0;
    }
    
    // Clamp velocities: particle-size- and dt-aware to prevent excessive oscillation/tunneling
    let inv_dt = 1.0 / max(params.dt, 1e-4);
    let dynamic_cap = 0.8 * params.particle_size * inv_dt;
    let max_velocity = min(5.0, dynamic_cap);
    let velocity_magnitude = length(particle.velocity);
    if (velocity_magnitude > max_velocity) {
        particle.velocity = normalize(particle.velocity) * max_velocity;
    }
    
    particles[index] = particle;
}

float2 compute_acceleration(Particle particle, uint particle_index) {
    var acceleration = float2(0.0, 0.0);
    
    // Gravitational forces using spatial grid
    if (params.gravitational_constant > 0.0) {
        acceleration += compute_gravity_grid(particle, particle_index);
    }
    
    // Mouse interaction
    if (params.mouse_pressed != 0) {
        acceleration += compute_mouse_force(particle);
    }
    
    // Collision forces using spatial grid
    acceleration += compute_collision_forces_grid(particle, particle_index);
    
    return acceleration;
}

float2 compute_gravity_grid(Particle particle, uint particle_index) {
    var total_force = float2(0.0, 0.0);
    let interaction_radius_sq = params.interaction_radius * params.interaction_radius;
    let long_range_radius_sq = 4.0;
    
    let center_cell = world_to_grid(particle.position);
    for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
            let cx = (int(center_cell.x) + dx + int(grid_params.grid_width)) % int(grid_params.grid_width);
            let cy = (int(center_cell.y) + dy + int(grid_params.grid_height)) % int(grid_params.grid_height);
            let cell_index = grid_coord_to_index(uint2(uint(cx), uint(cy)));
            let count = grid_counts[cell_index];
            for (var k = 0; k < min(count, 64); k++) {
                let neighbor_index = grid[cell_index].particle_indices[k];
                if (neighbor_index == particle_index) { continue; }
                let other = particles[neighbor_index];
                var delta = other.position - particle.position;
                if (abs(delta.x) > 1.0) { delta.x = delta.x - sign(delta.x) * 2.0; }
                if (abs(delta.y) > 1.0) { delta.y = delta.y - sign(delta.y) * 2.0; }
                let distance_sq = dot(delta, delta);
                if (distance_sq < 1e-6) { continue; }
                if (distance_sq > long_range_radius_sq) { continue; }
                let distance = sqrt(distance_sq);
                let softened_distance_sq = distance_sq + params.gravity_softening * params.gravity_softening;
                let softened_distance = sqrt(softened_distance_sq);
                let force_magnitude = params.gravitational_constant * particle.mass * other.mass / softened_distance_sq;
                var attenuated_force = force_magnitude;
                if (distance_sq <= interaction_radius_sq) {
                    let distance_factor = (params.interaction_radius - distance) / params.interaction_radius;
                    attenuated_force = force_magnitude * max(distance_factor, 0.0) * 2.0;
                } else {
                    attenuated_force = 0.0;
                }
                let force_direction = delta / softened_distance;
                total_force += force_direction * attenuated_force;
            }
        }
    }
    
    return total_force / particle.mass;
}

float2 compute_mouse_force(Particle particle) {
    let delta = params.mouse_position - particle.position;
    let aspect_corrected_delta = float2(delta.x * params.aspect_ratio, delta.y);
    let distance = length(aspect_corrected_delta);
    
    if (distance > params.cursor_size || distance < 1e-6) {
        return float2(0.0, 0.0);
    }
    
    let force_strength = params.cursor_strength * (1.0 - distance / params.cursor_size);
    let force_direction = normalize(delta);
    
    if (params.mouse_mode == 1) {
        return force_direction * force_strength;
    }

    if (params.mouse_mode == 2) {
        // Black-hole interaction: pull inward while adding the same 80%
        // tangential swirl used by the other particle simulations. Build the
        // tangent in aspect-corrected space so it appears circular on screen.
        let screen_direction = normalize(aspect_corrected_delta);
        let tangential_direction = normalize(float2(
            -screen_direction.y / max(params.aspect_ratio, 1e-6),
            screen_direction.x
        ));
        return (force_direction + tangential_direction * 0.8) * force_strength;
    }
    
    return float2(0.0, 0.0);
}

float2 compute_collision_forces_grid(Particle particle, uint particle_index) {
    var collision_impulse = float2(0.0, 0.0);
    
    // Use the pre-calculated particle size that matches the rendering size exactly
    let particle_radius = params.particle_size;
    
    var total_impulse = float2(0.0, 0.0);
    let center_cell = world_to_grid(particle.position);
    for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
            let cx = (int(center_cell.x) + dx + int(grid_params.grid_width)) % int(grid_params.grid_width);
            let cy = (int(center_cell.y) + dy + int(grid_params.grid_height)) % int(grid_params.grid_height);
            let cell_index = grid_coord_to_index(uint2(uint(cx), uint(cy)));
            let count = grid_counts[cell_index];
            for (var k = 0; k < min(count, 64); k++) {
                let j = grid[cell_index].particle_indices[k];
                if (j == particle_index) { continue; }
                let other = particles[j];
                var delta = other.position - particle.position;
                if (abs(delta.x) > 1.0) { delta.x = delta.x - sign(delta.x) * 2.0; }
                if (abs(delta.y) > 1.0) { delta.y = delta.y - sign(delta.y) * 2.0; }
                let aspect_corrected_delta = float2(delta.x * params.aspect_ratio, delta.y);
                let distance_sq = dot(aspect_corrected_delta, aspect_corrected_delta);
                let combined_radius = particle_radius + particle_radius;
                let collision_distance_sq = combined_radius * combined_radius;
                if (distance_sq > collision_distance_sq * 1.1) { continue; }
                let distance = sqrt(distance_sq);
                if (distance < combined_radius && distance > 1e-6) {
                    let collision_normal = normalize(aspect_corrected_delta);
                    let relative_velocity = particle.velocity - other.velocity;
                    let velocity_along_normal = dot(relative_velocity, collision_normal);
                    if (velocity_along_normal > 0.0) { continue; }
                    var impulse_magnitude = -2.0 * velocity_along_normal;
                    impulse_magnitude = impulse_magnitude / (1.0 / particle.mass + 1.0 / other.mass);
                    // Slight inelastic bias to help damp oscillations
                    impulse_magnitude *= min(params.collision_damping, 0.98);
                    let impulse = collision_normal * impulse_magnitude;
                    total_impulse += impulse / particle.mass;
                }
            }
        }
    }
    
    // Remove density-based damping for collision impulses to maintain bounce
    collision_impulse = total_impulse;
    
    return collision_impulse;
}

// Hash function for deterministic pseudo-random generation
uint hash(uint seed) {
    var x = seed;
    x = ((x >> 16) ^ x) * 0x45d9f3bu;
    x = ((x >> 16) ^ x) * 0x45d9f3bu;
    x = (x >> 16) ^ x;
    return x;
}

void resolve_collisions(inout Particle particle, uint particle_index) {
    // Pre-computed constants for equal-sized particles
    let particle_radius = params.particle_size;
    let combined_radius = 2.0 * particle_radius; // Always 2x for equal particles
    let collision_distance_sq = combined_radius * combined_radius; // Pre-computed squared distance
    let collision_distance = combined_radius; // Pre-computed distance
    
    // Run 3 iterations of overlap resolution for better separation
    for (var iteration = 0; iteration < 3; iteration++) {
        // Stochastic iteration participation: only process a subset of particles per iteration
        let participation_seed = hash(particle_index ^ (params.frame_index * 1664525) ^ (iteration * 1013904223));
        
        // Higher participation rate for better overlap resolution accuracy
        let base_participation = 0.6; // 60% of particles participate per iteration
        let strength_factor = 1.0 + (params.overlap_resolution_strength * 0.3); // Increase with strength
        
        // Boost participation for fast-moving particles to prevent tunneling
        let velocity_magnitude = length(particle.velocity);
        let velocity_boost = min(velocity_magnitude * 0.3, 0.2); // Up to 20% boost for fast particles
        let participation_rate = min(base_participation * strength_factor + velocity_boost, 0.9); // Cap at 90%
        let participation_threshold = uint(float(0xffffffffu) * participation_rate);
        
        // Skip this iteration if particle doesn't participate (stochastic gating)
        if (participation_seed > participation_threshold) {
            continue;
        }
        
        var overlap_count = 0;
        var total_overlap = 0.0;
        var weighted_separation = float2(0.0, 0.0);
        var velocity_aware_direction = float2(0.0, 0.0);
        
        // Use only neighbors from the 3x3 cells
        let center_cell = world_to_grid(particle.position);
        for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
                let cx = (int(center_cell.x) + dx + int(grid_params.grid_width)) % int(grid_params.grid_width);
                let cy = (int(center_cell.y) + dy + int(grid_params.grid_height)) % int(grid_params.grid_height);
                let cell_index = grid_coord_to_index(uint2(uint(cx), uint(cy)));
                let count = grid_counts[cell_index];
                for (var k = 0; k < min(count, 64); k++) {
                    let i = grid[cell_index].particle_indices[k];
                    if (i == particle_index) { continue; }
                    let other = particles[i];
                    var delta = particle.position - other.position;
                    if (abs(delta.x) > 1.0) { delta.x = delta.x - sign(delta.x) * 2.0; }
                    if (abs(delta.y) > 1.0) { delta.y = delta.y - sign(delta.y) * 2.0; }
                    let aspect_corrected_delta = float2(delta.x * params.aspect_ratio, delta.y);
                    let distance_sq = dot(aspect_corrected_delta, aspect_corrected_delta);
                    
                    // Use pre-computed collision distance (no sqrt needed for detection)
                    if (distance_sq < collision_distance_sq && distance_sq > 1e-12) {
                        let distance = sqrt(distance_sq);
                        let overlap = collision_distance - distance;
                        if (overlap > 0.0) {
                            overlap_count += 1;
                            total_overlap += overlap;
                            
                            // Symmetric separation direction (equal mass/radius)
                            let separation_direction = normalize(aspect_corrected_delta);
                            let world_separation_direction = float2(
                                separation_direction.x / params.aspect_ratio,
                                separation_direction.y
                            );
                            
                            // Weight by overlap amount for better distribution
                            weighted_separation += world_separation_direction * overlap;
                            
                            // Velocity-aware direction to prevent future collisions
                            let relative_velocity = particle.velocity - other.velocity;
                            let velocity_component = dot(relative_velocity, world_separation_direction);
                            if (velocity_component > 0.0) {
                                velocity_aware_direction += world_separation_direction * velocity_component * 0.1;
                            }
                        }
                    }
                }
            }
        }
        
        // Apply overlap resolution with strength from settings and safety bounds
        if (total_overlap > 0.0) {
            let resolution_strength = params.overlap_resolution_strength;
            
            // Increase resolution strength for fast-moving particles to prevent tunneling
            let velocity_factor = min(1.0 + velocity_magnitude * 1.5, 2.5); // Up to 2.5x strength for fast particles
            let enhanced_strength = resolution_strength * velocity_factor;
            
            // Batch processing: particles with more overlaps get stronger resolution
            let overlap_factor = min(1.0 + float(overlap_count) * 0.15, 2.5); // Up to 2.5x for many overlaps
            let final_strength = enhanced_strength * overlap_factor;
            
            // Higher base strength for better accuracy, with higher cap
            let base_strength_multiplier = 1.5; // 50% stronger base resolution
            let clamped_strength = min(final_strength * base_strength_multiplier, 1.2);
            
            // Symmetric separation: each particle moves half the overlap distance
            let half_overlap = total_overlap * 0.5;
            let base_separation_distance = particle_radius * 0.8; // Increased from 0.5 to 0.8
            let velocity_separation_boost = velocity_magnitude * particle_radius * 0.4; // Increased from 0.3 to 0.4
            let max_separation_distance = base_separation_distance + velocity_separation_boost;
            let separation_magnitude = min(half_overlap * clamped_strength, max_separation_distance);
            
            // Combine weighted separation with velocity-aware direction
            var separation_dir = normalize(weighted_separation + velocity_aware_direction);
            
            // Add significant random angle variation to break up wave patterns
            let angle_seed = hash(particle_index ^ (iteration * 1664525) ^ 1013904223);
            let angle_random = float(angle_seed) / float(0xffffffffu);
            let angle_variation = (angle_random - 0.5) * 1.6; // ±0.8 radians (±46 degrees)
            
            // Rotate the separation direction by the random angle
            let cos_angle = cos(angle_variation);
            let sin_angle = sin(angle_variation);
            let rotated_dir = float2(
                separation_dir.x * cos_angle - separation_dir.y * sin_angle,
                separation_dir.x * sin_angle + separation_dir.y * cos_angle
            );
            separation_dir = rotated_dir;
            
            // Additional per-particle, per-iteration jitter to break symmetry
            let jitter_seed = hash(particle_index ^ (iteration * 1664525) ^ 0x12345678u);
            let jitter_value = float(jitter_seed) / float(0xffffffffu);
            let jitter_sign = ((jitter_value > 0.5) ? (1.0) : (-1.0));
            let tangent = float2(-separation_dir.y, separation_dir.x);
            
            // Add a small deadband to avoid micro-oscillation when nearly touching
            if (total_overlap < particle_radius * 0.003) {
                return;
            }
            let jitter_amp = min(0.15 * total_overlap, particle_radius * 0.008);
            let jitter = tangent * jitter_amp * jitter_sign;

            let separation = separation_dir * separation_magnitude + jitter;
            particle.position += separation;
        }
    }
} 
