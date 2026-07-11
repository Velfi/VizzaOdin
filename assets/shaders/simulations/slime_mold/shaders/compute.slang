// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/slime_mold/shaders/compute.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Compute shader for Physarum simulation
// Each agent is represented by a float4: x, y, angle, speed

static const float TAU = 6.28318530718; // 2π

struct SimSizeUniform {

    uint width;
    uint height;
    float decay_rate;
    float agent_jitter;
    float agent_speed_min;
    float agent_speed_max;
    float agent_turn_rate;
    float agent_sensor_angle;
    float agent_sensor_distance;
    float diffusion_rate;
    float pheromone_deposition_rate;
    uint mask_pattern;
    uint mask_target;
    float mask_strength;
    float mask_curve;
    uint mask_mirror_horizontal;
    uint mask_mirror_vertical;
    uint mask_invert_tone;
    uint random_seed;
    uint position_generator;
    float delta_time;
    uint agent_count;
    uint webcam_live;
    uint webcam_fit_mode;
    uint webcam_width;
    uint webcam_height;
    uint isotropic_jitter;
};

struct CursorParams {

    uint is_active; // 0=inactive, 1=attract, 2=repel
    float x;
    float y;
    float strength;
    float size;
    uint _pad1;
    uint _pad2;
};

// agents are stored as 4 floats each (x, y, angle, speed)
[[vk::binding(0, 0)]]
RWStructuredBuffer<float4> agents;

[[vk::binding(1, 0)]]
RWStructuredBuffer<float> trail_map;

[[vk::binding(2, 0)]]
ConstantBuffer<SimSizeUniform> sim_size;

[[vk::binding(3, 0)]]
StructuredBuffer<float> mask_map;

[[vk::binding(4, 0)]]
ConstantBuffer<CursorParams> cursor;

[[vk::binding(5, 0)]]
Texture2D<float4> webcam_image;

[[vk::binding(6, 0)]]
SamplerState webcam_sampler;

// Helper function for bilinear interpolation
float sample_trail_map(float2 pos) {
    let width = int(sim_size.width);
    let height = int(sim_size.height);

    let x0 = ((int(floor(pos.x)) % width) + width) % width;
    let y0 = ((int(floor(pos.y)) % height) + height) % height;
    let x1 = (x0 + 1) % width;
    let y1 = (y0 + 1) % height;

    let dx = pos.x - float(int(floor(pos.x)));
    let dy = pos.y - float(int(floor(pos.y)));

    let v00 = trail_map[y0 * width + x0];
    let v10 = trail_map[y0 * width + x1];
    let v01 = trail_map[y1 * width + x0];
    let v11 = trail_map[y1 * width + x1];

    let v0 = lerp(v00, v10, dx);
    let v1 = lerp(v01, v11, dx);
    return lerp(v0, v1, dy);
}

// Fast sampling using nearest neighbor (much faster)
float sample_trail_map_fast(float2 pos) {
    let width = int(sim_size.width);
    let height = int(sim_size.height);
    
    let x = ((int(round(pos.x)) % width) + width) % width;
    let y = ((int(round(pos.y)) % height) + height) % height;
    
    return trail_map[y * width + x];
}

// Helper function to sample mask map
float sample_mask_map(float2 pos) {
    let width = int(sim_size.width);
    let height = int(sim_size.height);

    let x0 = ((int(floor(pos.x)) % width) + width) % width;
    let y0 = ((int(floor(pos.y)) % height) + height) % height;
    let x1 = (x0 + 1) % width;
    let y1 = (y0 + 1) % height;

    let dx = pos.x - float(int(floor(pos.x)));
    let dy = pos.y - float(int(floor(pos.y)));

    let v00 = mask_map[y0 * width + x0];
    let v10 = mask_map[y0 * width + x1];
    let v01 = mask_map[y1 * width + x0];
    let v11 = mask_map[y1 * width + x1];

    let v0 = lerp(v00, v10, dx);
    let v1 = lerp(v01, v11, dx);
    return lerp(v0, v1, dy);
}

// Unified mask sampling with mirror + tone inversion applied consistently
float sample_mask_with_mirror_invert(float2 pos) {
    // Normalize for mirroring
    var sx = pos.x / float(sim_size.width);
    var sy = pos.y / float(sim_size.height);

    if (sim_size.mask_mirror_horizontal != 0) { sx = 1.0 - sx; }
    if (sim_size.mask_mirror_vertical != 0) { sy = 1.0 - sy; }

    if (sim_size.webcam_live != 0) {
        float target_width = float(max(sim_size.width, 1u));
        float target_height = float(max(sim_size.height, 1u));
        float source_width = float(max(sim_size.webcam_width, 1u));
        float source_height = float(max(sim_size.webcam_height, 1u));
        float2 p = float2(sx * target_width, sy * target_height);
        float2 source_p;
        if (sim_size.webcam_fit_mode == 1u) {
            source_p.x = source_width > target_width ? p.x * source_width / target_width : p.x - (target_width - source_width) * 0.5;
            source_p.y = source_height > target_height ? p.y * source_height / target_height : p.y - (target_height - source_height) * 0.5;
        } else if (sim_size.webcam_fit_mode == 2u) {
            float fitted_height = target_width * source_height / source_width;
            source_p = float2(p.x * source_width / target_width, (p.y - (target_height - fitted_height) * 0.5) * source_height / fitted_height);
        } else if (sim_size.webcam_fit_mode == 3u) {
            float fitted_width = target_height * source_width / source_height;
            source_p = float2((p.x - (target_width - fitted_width) * 0.5) * source_width / fitted_width, p.y * source_height / target_height);
        } else {
            source_p = p * float2(source_width / target_width, source_height / target_height);
        }
        bool inside = all(source_p >= 0.0) && source_p.x < source_width && source_p.y < source_height;
        float value = 0.0;
        if (inside) {
            source_p.y = source_height - 1.0 - source_p.y;
            float3 rgb = webcam_image.SampleLevel(webcam_sampler, (source_p + 0.5) / float2(source_width, source_height), 0.0).rgb;
            value = dot(rgb, float3(0.2126, 0.7152, 0.0722));
        }
        return sim_size.mask_invert_tone != 0 ? 1.0 - value : value;
    }

    // Convert back to texture space and use bilinear sampling
    let mirrored_pos = float2(sx * float(sim_size.width), sy * float(sim_size.height));
    var v = sample_mask_map(mirrored_pos);
    if (sim_size.mask_invert_tone != 0) { v = 1.0 - v; }
    return v;
}

// Combined function to sample both trail and mask
float sample_combined_map(float2 pos) {
    let trail_value = sample_trail_map(pos);
    float mask_value = 0.0;
    if (sim_size.mask_pattern != 0) {
        mask_value = sample_mask_with_mirror_invert(pos);
    }
    return trail_value + mask_value;
}

// Fast combined sampling for performance-critical paths
float sample_combined_map_fast(float2 pos) {
    let trail_value = sample_trail_map_fast(pos);
    float mask_value = 0.0;
    if (sim_size.mask_pattern != 0) {
        mask_value = sample_mask_with_mirror_invert(pos);
    }
    return trail_value + mask_value;
}

// Get mask factor for the current position
float get_mask_factor(float x, float y) {
    if (sim_size.mask_pattern == 0) { return 0.0; }
    return sample_mask_with_mirror_invert(float2(x, y));
}

// Parameters for the simulation (now mostly from uniform)
static const float TIME_STEP = 0.016; // Legacy movement amount at 60 Hz.

[shader("compute")]
[numthreads(16,  16,  1)]
void update_agents(
    uint3 id : SV_DispatchThreadID,
    uint3 local_id : SV_GroupThreadID
) {
    // Calculate linear agent index from 2D global invocation
    let agents_per_row = 65535 * 16; // Max workgroups per row * threads per workgroup row
    let agent_index = id.x + id.y * agents_per_row;
    
    // For consistent random seeding, create a sequential index (preserves old preset behavior)
    // This ensures random patterns remain the same regardless of dispatch method
    let workgroup_linear_id = (id.x / 16) + (id.y / 16) * 65535; 
    let thread_in_workgroup = (id.x % 16) + (id.y % 16) * 16;
    let random_seed_index = workgroup_linear_id * 256 + thread_in_workgroup;
    
    // Bounds check - exit if this thread doesn't correspond to a valid agent
    if (agent_index >= sim_size.agent_count) {
        return;
    }

    // Get agent data
    let agent = agents[agent_index];
    var x = agent.x;
    var y = agent.y;
    var angle = agent.z;
    var speed = agent.w;

    // Get mask factor for this position, apply curve and strength
    var mask_factor = 0.0;
    if (sim_size.mask_pattern != 0) {
        mask_factor = get_mask_factor(x, y);
        mask_factor = pow(clamp(mask_factor, 0.0, 1.0), max(0.0001, sim_size.mask_curve));
        mask_factor = clamp(mask_factor * sim_size.mask_strength, 0.0, 1.0);
    }
    
    // Apply mask to parameters based on target
    var effective_sensor_distance = sim_size.agent_sensor_distance;
    var effective_speed = speed;
    var effective_turn_rate = sim_size.agent_turn_rate;
    var effective_deposition_rate = sim_size.pheromone_deposition_rate;
    
    if (sim_size.mask_target == 0) { // PheromoneDeposition (0..100)
        let target_min = 0.0;
        let target_max = 100.0;
        let target_value = lerp(target_min, target_max, mask_factor);
        effective_deposition_rate = lerp(effective_deposition_rate, target_value, mask_factor);
    } else if (sim_size.mask_target == 3) { // AgentSpeed (normalize within min/max)
        let speed_min = sim_size.agent_speed_min;
        let speed_max = sim_size.agent_speed_max;
        let speed_norm = clamp((effective_speed - speed_min) / max(0.0001, speed_max - speed_min), 0.0, 1.0);
        let target_norm = mask_factor; // 0..1 in normalized space
        let mixed_norm = lerp(speed_norm, target_norm, mask_factor);
        effective_speed = speed_min + mixed_norm * (speed_max - speed_min);
    } else if (sim_size.mask_target == 4) { // AgentTurnRate (0..pi)
        let target_min = 0.0;
        let target_max = 3.14159265;
        let target_value = lerp(target_min, target_max, mask_factor);
        effective_turn_rate = lerp(effective_turn_rate, target_value, mask_factor);
    } else if (sim_size.mask_target == 5) { // AgentSensorDistance (0..500 per UI)
        let target_min = 0.0;
        let target_max = 500.0;
        let target_value = lerp(target_min, target_max, mask_factor);
        effective_sensor_distance = lerp(effective_sensor_distance, target_value, mask_factor);
    } else if (sim_size.mask_target == 6) { // TrailMap (direct trail map modification)
        // For TrailMap target, we'll apply the mask factor directly to the deposition rate
        // This allows the mask to control how much pheromone is deposited in different areas
        // Make the effect more pronounced by using a wider range
        let min_deposition = 0.0;
        let max_deposition = effective_deposition_rate * 2.0;
        effective_deposition_rate = lerp(min_deposition, max_deposition, mask_factor);
    }

    // Sample trail map at sensor positions
    let sensor_angle = sim_size.agent_sensor_angle;
    
    // Calculate sensor positions
    let left_angle = angle - sensor_angle;
    let right_angle = angle + sensor_angle;
    
    let left_pos = float2(
        x + cos(left_angle) * effective_sensor_distance,
        y + sin(left_angle) * effective_sensor_distance
    );
    let right_pos = float2(
        x + cos(right_angle) * effective_sensor_distance,
        y + sin(right_angle) * effective_sensor_distance
    );
    
    // Sample combined trail + gradient maps at sensor positions
    // Use fast sampling for better performance (sacrifices some accuracy for speed)
    let left_value = sample_combined_map_fast(left_pos);
    let right_value = sample_combined_map_fast(right_pos);
    
    let frame_scale = max(sim_size.delta_time, 0.0) * 60.0;

    // Update angle based on sensor readings
    if (left_value > right_value) {
        // Calculate shortest path to turn left
        angle -= min(effective_turn_rate * frame_scale, TAU);
    } else if (right_value > left_value) {
        // Calculate shortest path to turn right
        angle += min(effective_turn_rate * frame_scale, TAU);
    } else {
        // If equal, do nothing
    }

    // Update agent position
    let move_dist = effective_speed * TIME_STEP * frame_scale;
    x = x + move_dist * cos(angle);
    y = y + move_dist * sin(angle);

    // --- CURSOR INTERACTION ---
    if (cursor.is_active > 0) {
        let cursor_pos = float2(cursor.x, cursor.y);

        // Pheromone is a persistent trail-map edit. One invocation owns the
        // write so thousands of agent threads do not race on the same texels.
        if ((cursor.is_active == 3 || cursor.is_active == 4) && agent_index == 0) {
            let radius = int(max(cursor.size, 1.0));
            for (var oy = -radius; oy <= radius; oy++) {
                for (var ox = -radius; ox <= radius; ox++) {
                    let d = length(float2(float(ox), float(oy)));
                    if (d > cursor.size) { continue; }
                    let px = ((int(cursor.x) + ox) % int(sim_size.width) + int(sim_size.width)) % int(sim_size.width);
                    let py = ((int(cursor.y) + oy) % int(sim_size.height) + int(sim_size.height)) % int(sim_size.height);
                    let ti = py * int(sim_size.width) + px;
                    let amount = saturate(1.0 - d / max(cursor.size, 1.0)) * cursor.strength * 0.01;
                    trail_map[ti] = cursor.is_active == 3 ? saturate(trail_map[ti] + amount) : saturate(trail_map[ti] - amount);
                }
            }
        }

        let delta = cursor_pos - float2(x, y);
        let dist = length(delta);
        if (dist < cursor.size && dist > 0.01) {
            let dir = normalize(delta);
            let force = cursor.strength * (1.0 - dist / cursor.size) * frame_scale;
            if (cursor.is_active == 1) {
                // Attract with swirling effect
                x += dir.x * force;
                y += dir.y * force;
                
                // Add swirling force (tangential component) for black hole effect
                let tangential_dir = float2(-dir.y, dir.x);
                let swirl_force = force * 0.8; // 80% of radial force
                x += tangential_dir.x * swirl_force;
                y += tangential_dir.y * swirl_force;
                
            } else if (cursor.is_active == 2) {
                // Repel with swirling effect
                x -= dir.x * force;
                y -= dir.y * force;
                
                // Add swirling force (tangential component) for centrifugal effect
                let tangential_dir = float2(dir.y, -dir.x);
                let swirl_force = force * 0.8; // 80% of radial force
                x += tangential_dir.x * swirl_force;
                y += tangential_dir.y * swirl_force;
            } else if (cursor.is_active == 5 && ((agent_index + sim_size.random_seed) % 64u) == 0u) {
                // Fixed-capacity population: recycle a sparse stream of agents into the brush.
                let a = float((agent_index * 1664525u + sim_size.random_seed) & 65535u) / 65535.0 * TAU;
                let r = cursor.size * 0.35;
                x = cursor.x + cos(a) * r;
                y = cursor.y + sin(a) * r;
            } else if (cursor.is_active == 6) {
                // Removing recycles affected agents outside the brush rather than reallocating GPU storage.
                x = fmod(x + float(sim_size.width) * 0.5, float(sim_size.width));
                y = fmod(y + float(sim_size.height) * 0.5, float(sim_size.height));
            }
        }
    }
    // --- END CURSOR INTERACTION ---

    // Apply jitter with proper random distribution
    let jitter_strength = sim_size.agent_jitter * sqrt(frame_scale);
    let jitter_x_seed = hash(random_seed_index * 2654435761u + 1013904223u);
    let jitter_y_seed = hash(random_seed_index * 1664525u + 1073741827u);
    let random_x = random_float(jitter_x_seed);
    let random_y = random_float(jitter_y_seed);
    if (sim_size.isotropic_jitter != 0) {
        // Uniform disk sampling is rotationally symmetric. This scale keeps
        // the same RMS displacement as the legacy square distribution.
        let jitter_angle = random_x * TAU;
        let jitter_radius = sqrt(random_y) * jitter_strength * 1.15470054;
        x += cos(jitter_angle) * jitter_radius;
        y += sin(jitter_angle) * jitter_radius;
    } else {
        x += (random_x * 2.0 - 1.0) * jitter_strength;
        y += (random_y * 2.0 - 1.0) * jitter_strength;
    }

    // Wrap agent position to stay within bounds (toroidal)
    x = x % float(sim_size.width);
    if (x < 0.0) { x = x + float(sim_size.width); }
    y = y % float(sim_size.height);
    if (y < 0.0) { y = y + float(sim_size.height); }

    // Deposit trail
    let deposit_x = int(x);
    let deposit_y = int(y);
    if (deposit_x >= 0 && deposit_x < int(sim_size.width) && deposit_y >= 0 && deposit_y < int(sim_size.height)) {
        let idx = deposit_y * int(sim_size.width) + deposit_x;
        trail_map[idx] = clamp(trail_map[idx] + effective_deposition_rate * 0.01 * frame_scale, 0.0, 1.0);
    }

    // Update agent in the buffer
    agents[agent_index] = float4(x, y, angle, speed);
}

// Add a new compute entry point for trail decay
[shader("compute")]
[numthreads(16,  16,  1)]
void decay_trail(uint3 id : SV_DispatchThreadID) {
    let x = id.x;
    let y = id.y;
    if (x >= sim_size.width || y >= sim_size.height) {
        return;
    }
    let idx = y * sim_size.width + x;
    
    // Get mask factor for this position, apply curve and strength
    var mask_factor = 0.0;
    if (sim_size.mask_pattern != 0) {
        mask_factor = get_mask_factor(float(x), float(y));
        mask_factor = pow(clamp(mask_factor, 0.0, 1.0), max(0.0001, sim_size.mask_curve));
        mask_factor = clamp(mask_factor * sim_size.mask_strength, 0.0, 1.0);
    }
    
    // Apply mask to decay rate if target is PheromoneDecay
    var effective_decay_rate = sim_size.decay_rate;
    if (sim_size.mask_target == 1) { // PheromoneDecay (0..10000)
        let target_min = 0.0;
        let target_max = 10000.0;
        let target_value = lerp(target_min, target_max, mask_factor);
        effective_decay_rate = lerp(effective_decay_rate, target_value, 1.0);
    } else if (sim_size.mask_target == 6) { // TrailMap (direct trail map modification)
        // Blend trail toward mask pattern each pass for a clear effect
        // Use mask_strength as the blend factor, shaped by mask_curve
        let blend = clamp(sim_size.mask_strength, 0.0, 1.0);
        let target_trail = mask_factor; // 0..1 from pattern/image
        trail_map[idx] = lerp(trail_map[idx], target_trail, blend);
    }
    
    // Apply decay rate
    let frame_scale = max(sim_size.delta_time, 0.0) * 60.0;
    let decay_rate = effective_decay_rate * 0.0001 * frame_scale;
    trail_map[idx] = max(0.0, trail_map[idx] - decay_rate);
}

// Add a new compute entry point for diffusion
[shader("compute")]
[numthreads(16,  16,  1)]
void diffuse_trail(uint3 id : SV_DispatchThreadID) {
    let x = id.x;
    let y = id.y;
    if (x >= sim_size.width || y >= sim_size.height) {
        return;
    }
    let idx = y * sim_size.width + x;
    
    // Get mask factor for this position
    let mask_factor = sim_size.mask_pattern != 0 ? get_mask_factor(float(x), float(y)) : 0.0;
    
    // Apply mask to diffusion rate if target is PheromoneDiffusion
    var effective_diffusion_rate = sim_size.diffusion_rate;
    if (sim_size.mask_target == 2) { // PheromoneDiffusion (0..100)
        let target_min = 0.0;
        let target_max = 100.0;
        let target_value = lerp(target_min, target_max, mask_factor);
        effective_diffusion_rate = lerp(effective_diffusion_rate, target_value, 1.0);
    }
    
    // Get neighboring values with toroidal wrapping
    let x_prev = (x + sim_size.width - 1) % sim_size.width;
    let x_next = (x + 1) % sim_size.width;
    let y_prev = (y + sim_size.height - 1) % sim_size.height;
    let y_next = (y + 1) % sim_size.height;
    
    // Read from trail_map
    let center = trail_map[y * sim_size.width + x];
    let left = trail_map[y * sim_size.width + x_prev];
    let right = trail_map[y * sim_size.width + x_next];
    let up = trail_map[y_prev * sim_size.width + x];
    let down = trail_map[y_next * sim_size.width + x];
    
    // Simple diffusion: average of neighbors
    let frame_scale = max(sim_size.delta_time, 0.0) * 60.0;
    let diffusion_rate = clamp(effective_diffusion_rate * 0.01 * frame_scale, 0.0, 1.0);
    let new_value = center * (1.0 - diffusion_rate) + 
                   (left + right + up + down) * (diffusion_rate * 0.25);
    
    // Clamp to prevent numerical instability and negative values
    let clamped_value = max(0.0, min(1.0, new_value));
    
    // Write back to trail_map (ping-pong will be handled at higher level)
    trail_map[y * sim_size.width + x] = clamped_value;
}

[shader("compute")]
[numthreads(16,  16,  1)]
void update_agent_speeds(uint3 id : SV_DispatchThreadID) {
    // Calculate linear agent index from 2D global invocation
    let agents_per_row = 65535 * 16; // Max workgroups per row * threads per workgroup row
    let agent_index = id.x + id.y * agents_per_row;
    
    // Bounds check - exit if this thread doesn't correspond to a valid agent
    if (agent_index >= sim_size.agent_count) {
        return;
    }
    
    // Get current agent data
    let agent = agents[agent_index];
    let x = agent.x;
    let y = agent.y;
    let angle = agent.z;
    
    // Generate new random speed within the current range
    let random_speed = frac(sin(float(agent_index) * 12.9898 + 78.233) * 43758.5453);
    let speed_range = sim_size.agent_speed_max - sim_size.agent_speed_min;
    let new_speed = sim_size.agent_speed_min + random_speed * speed_range;
    
    // Update agent with new speed
    agents[agent_index] = float4(x, y, angle, new_speed);
}

// Better random number generation using multiple hash functions
uint hash(uint seed) {
    var x = seed;
    x = ((x >> 16) ^ x) * 0x45d9f3bu;
    x = ((x >> 16) ^ x) * 0x45d9f3bu;
    x = (x >> 16) ^ x;
    return x;
}

float random_float(uint seed) {
    return float(hash(seed)) / float(0xffffffffu);
}

float random_range(uint seed, float min_val, float max_val) {
    return min_val + random_float(seed) * (max_val - min_val);
}

// Position generation functions for slime mold agents
float2 generate_random_position(uint seed, float width, float height) {
    let x = random_range(seed * 2, 0.0, width);
    let y = random_range(seed * 3, 0.0, height);
    return float2(x, y);
}

float2 generate_center_position(uint seed, float width, float height) {
    let center_x = width * 0.5;
    let center_y = height * 0.5;
    let scale = 0.3; // Scale around center
    let x = center_x + (random_range(seed * 2, -1.0, 1.0) * width * scale);
    let y = center_y + (random_range(seed * 3, -1.0, 1.0) * height * scale);
    return float2(x, y);
}

float2 generate_uniform_circle_position(uint seed, float width, float height) {
    let center_x = width * 0.5;
    let center_y = height * 0.5;
    let max_radius = min(width, height) * 0.4; // Scale for the smaller dimension
    let angle = random_range(seed * 2, 0.0, TAU);
    let radius = sqrt(random_range(seed * 3, 0.0, 1.0)) * max_radius;
    return float2(center_x + cos(angle) * radius, center_y + sin(angle) * radius);
}

float2 generate_centered_circle_position(uint seed, float width, float height) {
    let center_x = width * 0.5;
    let center_y = height * 0.5;
    let max_radius = min(width, height) * 0.4;
    let angle = random_range(seed * 2, 0.0, TAU);
    let radius = random_range(seed * 3, 0.0, max_radius);
    return float2(center_x + cos(angle) * radius, center_y + sin(angle) * radius);
}

float2 generate_ring_position(uint seed, float width, float height) {
    let center_x = width * 0.5;
    let center_y = height * 0.5;
    let ring_radius = min(width, height) * 0.35;
    let ring_width = min(width, height) * 0.01;
    let angle = random_range(seed * 2, 0.0, TAU);
    let radius = ring_radius + (random_range(seed * 3, -1.0, 1.0) * ring_width);
    return float2(center_x + cos(angle) * radius, center_y + sin(angle) * radius);
}

float2 generate_line_position(uint seed, float width, float height) {
    let x = random_range(seed * 2, 0.0, width);
    let y = height * 0.5 + (random_range(seed * 3, -1.0, 1.0) * height * 0.3);
    return float2(x, y);
}

float2 generate_spiral_position(uint seed, float width, float height) {
    let center_x = width * 0.5;
    let center_y = height * 0.5;
    let max_radius = min(width, height) * 0.45;
    let max_rotations = 2.0;
    let f = random_range(seed * 2, 0.0, 1.0);
    let angle = max_rotations * TAU * f;
    let spread = max_radius * 0.25 * min(f, 0.2);
    let radius = max_radius * f + spread * (random_range(seed * 3, -1.0, 1.0));
    return float2(center_x + radius * cos(angle), center_y + radius * sin(angle));
}

float2 generate_image_position(uint seed, float width, float height) {
    // Use rejection sampling to generate positions based on mask image intensity
    // Higher intensity areas are more likely to be selected
    
    let max_attempts = 100; // Prevent infinite loops
    var attempts = 0;
    
    while (attempts < max_attempts) {
        // Generate random position
        let x = random_range(seed * 2 + attempts, 0.0, width);
        let y = random_range(seed * 3 + attempts, 0.0, height);
        
        // Sample mask intensity using unified mirror/invert sampler
        var intensity = sample_mask_with_mirror_invert(float2(x, y));
        
        // Generate random threshold
        let threshold = random_range(seed * 4 + attempts, 0.0, 1.0);
        
        // Accept position if intensity is above threshold
        if (intensity >= threshold) {
            return float2(x, y);
        }
        
        attempts++;
    }
    
    // Fallback to random position if rejection sampling fails
    return generate_random_position(seed, width, height);
}

[shader("compute")]
[numthreads(64,  1,  1)]
void reset_agents(uint3 global_id : SV_DispatchThreadID) {
    // With 2D dispatch and workgroup_size(64, 1, 1):
    // global_id.x = linear thread index across all workgroups
    // global_id.y = second dimension for large dispatches  
    let agent_index = global_id.x + global_id.y * 65535u * 64u;
    if (agent_index >= sim_size.agent_count) {
        return;
    }
    
    // Use multiple different seeds for better randomness, incorporating the random seed
    let base_seed = agent_index * 2654435761u + sim_size.random_seed;
    let x_seed = hash(base_seed);
    let y_seed = hash(base_seed + 1013904223u);
    let angle_seed = hash(base_seed + 1664525u);
    
    // Generate position based on generator type
    float2 position;
    switch (sim_size.position_generator) {
        case 0: { // Random
            position = generate_random_position(base_seed, float(sim_size.width), float(sim_size.height));
            break;
        }
        case 1: { // Center
            position = generate_center_position(base_seed, float(sim_size.width), float(sim_size.height));
            break;
        }
        case 2: { // UniformCircle
            position = generate_uniform_circle_position(base_seed, float(sim_size.width), float(sim_size.height));
            break;
        }
        case 3: { // CenteredCircle
            position = generate_centered_circle_position(base_seed, float(sim_size.width), float(sim_size.height));
            break;
        }
        case 4: { // Ring
            position = generate_ring_position(base_seed, float(sim_size.width), float(sim_size.height));
            break;
        }
        case 5: { // Line
            position = generate_line_position(base_seed, float(sim_size.width), float(sim_size.height));
            break;
        }
        case 6: { // Spiral
            position = generate_spiral_position(base_seed, float(sim_size.width), float(sim_size.height));
            break;
        }
        case 7: { // Image
            position = generate_image_position(base_seed, float(sim_size.width), float(sim_size.height));
            break;
        }
        default: {
            position = generate_random_position(base_seed, float(sim_size.width), float(sim_size.height));
            break;
        }
    }
    
    // Generate random angle
    let angle = random_range(angle_seed, 0.0, TAU);
    
    // Set speed to average of min/max
    let speed = (sim_size.agent_speed_min + sim_size.agent_speed_max) * 0.5;
    
    // Update agent
    agents[agent_index] = float4(position.x, position.y, angle, speed);
} 
