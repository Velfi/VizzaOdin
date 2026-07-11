// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/primordial_particles/shaders/particle_update.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Primordial Particles Update Shader
// Implements the PPS motion law with signed turn: Δφ = sgn(R-L) * (α + β * N_t,r)
// Based on "How a life-like system emerges from a simplistic particle motion law"

static const float PI = 3.14159265359;

float wrap_angle_pi(float angle) {
    let tau = 2.0 * PI;
    return angle - floor((angle + PI) / tau) * tau;
}

float wrap_angle_tau(float angle) {
    let tau = 2.0 * PI;
    return angle - floor(angle / tau) * tau;
}

struct Particle {

    float2 position;
    float2 previous_position;
    float heading;
    float velocity; // Magnitude of velocity for coloring
    float density; // Local density for coloring
    uint grabbed;
};

struct SimParams {

    // Mouse interaction parameters (vec2 fields first for alignment)
    float2 mouse_position;
    float2 mouse_velocity;
    
    float alpha; // Fixed rotation parameter (radians)
    float beta; // Proportional rotation parameter
    float velocity; // Constant velocity
    float radius; // Interaction radius
    
    float dt; // Time step
    float width; // World width
    float height; // World height
    uint wrap_edges; // 1 if wrapping edges, 0 otherwise
    
    uint particle_count;
    uint mouse_pressed;
    uint mouse_mode;
    float cursor_size;
    float cursor_strength;
    float aspect_ratio;
    float _pad1;
    float _pad0;
};

[[vk::binding(0, 0)]]
StructuredBuffer<Particle> particles_in;

[[vk::binding(1, 0)]]
RWStructuredBuffer<Particle> particles_out;

[[vk::binding(2, 0)]]
ConstantBuffer<SimParams> sim_params;

// Calculate distance between two points with optional wrapping
float distance_with_wrapping(float2 p1, float2 p2) {
    var dx = p2.x - p1.x;
    var dy = p2.y - p1.y;
    
    if (sim_params.wrap_edges == 1) {
        // Wrap around world boundaries
        if (dx > sim_params.width * 0.5) {
            dx -= sim_params.width;
        } else if (dx < -sim_params.width * 0.5) {
            dx += sim_params.width;
        }
        
        if (dy > sim_params.height * 0.5) {
            dy -= sim_params.height;
        } else if (dy < -sim_params.height * 0.5) {
            dy += sim_params.height;
        }
    }
    
    return sqrt(dx * dx + dy * dy);
}

// Count particles in left and right semicircles
uint2 count_neighbors(uint particle_index) {
    let current_particle = particles_in[particle_index];
    uint left_count = 0;
    uint right_count = 0;
    
    for (var i = 0; i < sim_params.particle_count; i++) {
        if (i == particle_index) {
            continue;
        }
        
        let other_particle = particles_in[i];
        let dist = distance_with_wrapping(current_particle.position, other_particle.position);
        
        if (dist <= sim_params.radius) {
            // Calculate relative position vector
            var dx = other_particle.position.x - current_particle.position.x;
            var dy = other_particle.position.y - current_particle.position.y;
            
            if (sim_params.wrap_edges == 1) {
                // Apply same wrapping logic as distance calculation
                if (dx > sim_params.width * 0.5) {
                    dx -= sim_params.width;
                } else if (dx < -sim_params.width * 0.5) {
                    dx += sim_params.width;
                }
                
                if (dy > sim_params.height * 0.5) {
                    dy -= sim_params.height;
                } else if (dy < -sim_params.height * 0.5) {
                    dy += sim_params.height;
                }
            }
            
            // Determine if particle is on left or right side
            // Use cross product to determine side relative to current heading
            let relative_angle = atan2(dy, dx) - current_particle.heading;
            let normalized_angle = wrap_angle_pi(relative_angle);
            
            if (normalized_angle > 0.0) {
                right_count++;
            } else {
                left_count++;
            }
        }
    }
    
    return uint2(left_count, right_count);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let particle_index = global_id.x;
    
    if (particle_index >= sim_params.particle_count) {
        return;
    }
    
    var particle = particles_in[particle_index];
    
    // Use per-particle speed; initialize to baseline if unset
    var speed = particle.velocity;
    if (speed <= 0.0) {
        speed = sim_params.velocity;
    }
    
    // Prepare a velocity-space cursor force like Particle Life (affects velocity, not direct steering)
    float2 cursor_force = float2(0.0, 0.0);
    bool cursor_active = false;
    if (sim_params.mouse_pressed != 0 && sim_params.cursor_size > 0.0) {
        let to_cursor = sim_params.mouse_position - particle.position;
        let aspect_corrected = float2(to_cursor.x * sim_params.aspect_ratio, to_cursor.y);
        let distance = length(aspect_corrected);
        if (distance <= sim_params.cursor_size && distance > 1e-6) {
            let distance_factor = 1.0 - (distance / sim_params.cursor_size);
            var dir = normalize(float2(to_cursor.x, to_cursor.y));
            if (sim_params.mouse_mode == 2) { // pull is the secondary impulse action
                dir = -dir;
            }
            if (sim_params.mouse_mode == 3 || sim_params.mouse_mode == 4) {
                let radial = dir;
                dir = sim_params.mouse_mode == 3 ? float2(-radial.y, radial.x) : float2(radial.y, -radial.x);
            }
            // magnitude scaled by proximity and cursor strength (boosted)
            let mag = sim_params.cursor_strength * distance_factor * 4.0;
            cursor_force = dir * mag;
            cursor_active = true;
        }
    }
    
    // Count neighbors in left and right semicircles
    let neighbor_counts = count_neighbors(particle_index);
    let left_count = neighbor_counts.x;
    let right_count = neighbor_counts.y;
    let total_neighbors = left_count + right_count;
    
    // Determine turn direction based on side counts
    float turn_dir = 1.0; // tie-breaker to the right to preserve alpha effect
    if (right_count < left_count) {
        turn_dir = -1.0;
    } else if (right_count > left_count) {
        turn_dir = 1.0;
    }

    // Apply PPS motion law with sign: Δφ = sgn(R-L) * (α + β * N_t,r)
    let delta_phi_mag = sim_params.alpha + sim_params.beta * float(total_neighbors);
    particle.heading = wrap_angle_tau(particle.heading + turn_dir * delta_phi_mag * sim_params.dt);

    // Convert heading/speed to velocity vector and apply cursor force as acceleration
    var v = float2(cos(particle.heading) * speed, sin(particle.heading) * speed);
    if (cursor_active) {
        // Increased acceleration scaling for stronger interaction
        let accel_scale = 10.0 * sim_params.dt;
        v += cursor_force * accel_scale;
    }
    // Recompute speed and heading from updated velocity vector
    let new_speed = length(v);
    if (new_speed > 1e-6) {
        speed = new_speed;
        particle.heading = atan2(v.y, v.x);
    }
    
    // Decay speed back toward baseline when not actively influenced
    if (!cursor_active) {
        let t = clamp(0.25 * sim_params.dt, 0.0, 1.0);
        speed = speed + (sim_params.velocity - speed) * t;
    }
    
    // Update position based on heading and per-particle speed
    let dx = cos(particle.heading) * speed * sim_params.dt;
    let dy = sin(particle.heading) * speed * sim_params.dt;
    
    particle.position.x += dx;
    particle.position.y += dy;
    
    // Apply edge wrapping if enabled (using [-1,1] world space)
    if (sim_params.wrap_edges == 1) {
        if (particle.position.x < -1.0) {
            particle.position.x += 2.0; // wrap from -1 to +1
        } else if (particle.position.x > 1.0) {
            particle.position.x -= 2.0; // wrap from +1 to -1
        }
        
        if (particle.position.y < -1.0) {
            particle.position.y += 2.0; // wrap from -1 to +1
        } else if (particle.position.y > 1.0) {
            particle.position.y -= 2.0; // wrap from +1 to -1
        }
    } else {
        // Clamp to boundaries if not wrapping ([-1,1] world space)
        particle.position.x = clamp(particle.position.x, -1.0, 1.0);
        particle.position.y = clamp(particle.position.y, -1.0, 1.0);
    }
    
    // Store current speed for coloring/next step
    particle.velocity = speed;
    
    // Write final particle state to output buffer
    particles_out[particle_index] = particle;
}
