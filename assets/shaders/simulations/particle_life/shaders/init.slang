// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/particle_life/shaders/init.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Particle initialization compute shader

struct Particle {

    float2 position;
    float2 velocity;
    uint species;
    uint _pad;
};

struct InitParams {

    uint start_index;
    uint spawn_count;
    uint species_count;
    float width;
    float height;
    uint random_seed;
    uint position_generator; // 0=Random, 1=Center, 2=UniformCircle, etc.
    uint type_generator; // 0=Random, 1=Randomize10Percent, etc.
    uint _pad1;
    uint _pad2;
};

[[vk::binding(0, 0)]]
RWStructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
ConstantBuffer<InitParams> init_params;

// Simple pseudo-random number generator
uint hash(uint seed) {
    var x = seed;
    x = ((x >> 16) ^ x) * 0x45d9f3bu;
    x = ((x >> 16) ^ x) * 0x45d9f3bu;
    x = (x >> 16) ^ x;
    return x;
}

float random_f32(uint seed) {
    return float(hash(seed)) / float(0xffffffffu);
}

// Position generation functions - now using [-1,1] coordinate system
float2 generate_random_position(uint seed) {
    let x = random_f32(seed * 2) * 2.0 - 1.0; // [0,1] -> [-1,1]
    let y = random_f32(seed * 3) * 2.0 - 1.0; // [0,1] -> [-1,1]
    return float2(x, y); // [-1,1] x [-1,1]
}

float2 generate_center_position(uint seed) {
    let x = random_f32(seed * 2) * 2.0 - 1.0; // [0,1] -> [-1,1]
    let y = random_f32(seed * 3) * 2.0 - 1.0; // [0,1] -> [-1,1]
    let scale = 0.3; // Scale around center (0,0)
    return float2(x * scale, y * scale);
}

float2 generate_uniform_circle_position(uint seed) {
    let angle = random_f32(seed * 2) * 2.0 * 3.14159;
    let radius = sqrt(random_f32(seed * 3)) * 0.8; // Scale for [-1,1] space (radius up to 0.8)
    return float2(cos(angle) * radius, sin(angle) * radius);
}

float2 generate_centered_circle_position(uint seed) {
    let angle = random_f32(seed * 2) * 2.0 * 3.14159;
    let radius = random_f32(seed * 3) * 0.8; // Scale for [-1,1] space
    return float2(cos(angle) * radius, sin(angle) * radius);
}

float2 generate_ring_position(uint seed) {
    let angle = random_f32(seed * 2) * 2.0 * 3.14159;
    let radius = 0.35 + 0.01 * (random_f32(seed * 3) - 0.5) * 2.0; // Ring in [-1,1] space
    return float2(cos(angle) * radius, sin(angle) * radius);
}

float2 generate_rainbow_ring_position(uint seed, uint type_id, uint n_types) {
    let angle = (0.3 * (random_f32(seed * 2) - 0.5) * 2.0 + float(type_id)) / float(n_types) * 2.0 * 3.14159;
    let radius = 0.35 + 0.01 * (random_f32(seed * 3) - 0.5) * 2.0; // Ring in [-1,1] space
    return float2(cos(angle) * radius, sin(angle) * radius);
}

float2 generate_color_battle_position(uint seed, uint type_id, uint n_types) {
    let center_angle = float(type_id) / float(n_types) * 2.0 * 3.14159;
    let center_radius = 0.25; // Scale for [-1,1] space
    let angle = random_f32(seed * 2) * 2.0 * 3.14159;
    let radius = random_f32(seed * 3) * 0.05; // Scale for [-1,1] space
    return float2(
        center_radius * cos(center_angle) + cos(angle) * radius,
        center_radius * sin(center_angle) + sin(angle) * radius
    );
}

float2 generate_color_wheel_position(uint seed, uint type_id, uint n_types) {
    let center_angle = float(type_id) / float(n_types) * 2.0 * 3.14159;
    let center_radius = 0.15; // Scale for [-1,1] space
    let individual_radius = 0.1; // Scale for [-1,1] space
    return float2(
        center_radius * cos(center_angle) + (random_f32(seed * 2) - 0.5) * 2.0 * individual_radius,
        center_radius * sin(center_angle) + (random_f32(seed * 3) - 0.5) * 2.0 * individual_radius
    );
}

float2 generate_line_position(uint seed) {
    let x = random_f32(seed * 2) * 2.0 - 1.0; // Full width in [-1,1]
    let y = (random_f32(seed * 3) - 0.5) * 0.3; // Center around 0 with small spread
    return float2(x, y);
}

float2 generate_spiral_position(uint seed) {
    let max_rotations = 2.0;
    let f = random_f32(seed * 2);
    let angle = max_rotations * 2.0 * 3.14159 * f;
    let spread = 0.25 * min(f, 0.2); // Spiral spread
    let radius = 0.45 * f + spread * (random_f32(seed * 3) - 0.5) * 2.0; // Scale for [-1,1] space
    return float2(radius * cos(angle), radius * sin(angle));
}

float2 generate_rainbow_spiral_position(uint seed, uint type_id, uint n_types) {
    let max_rotations = 2.0;
    let type_spread = 0.3 / float(n_types);
    var f = (float(type_id + 1) / float(n_types + 2) + type_spread * (random_f32(seed * 2) - 0.5) * 2.0);
    f = clamp(f, 0.0, 1.0);
    let angle = max_rotations * 2.0 * 3.14159 * f;
    let spread = 0.25 * min(f, 0.2); // Spiral spread
    let radius = 0.45 * f + spread * (random_f32(seed * 3) - 0.5) * 2.0; // Scale for [-1,1] space
    return float2(radius * cos(angle), radius * sin(angle));
}

// Type generation functions
uint generate_radial_type(float2 position, uint n_types) {
    let distance = length(position); // Distance from center (0,0)
    let normalized_distance = clamp(distance / 1.414, 0.0, 1.0); // Normalize to [0,1], max distance is ~√2
    return uint(normalized_distance * float(n_types)) % n_types;
}

uint generate_polar_type(float2 position, uint n_types) {
    let angle = atan2(position.y, position.x); // Angle from center, range [-π, π]
    let normalized_angle = (angle + 3.14159) / (2.0 * 3.14159); // Convert to [0,1]
    return uint(normalized_angle * float(n_types)) % n_types;
}

uint generate_stripes_h_type(float2 position, uint n_types) {
    let normalized_y = (position.y + 1.0) * 0.5; // Convert from [-1,1] to [0,1]
    return uint(normalized_y * float(n_types)) % n_types;
}

uint generate_stripes_v_type(float2 position, uint n_types) {
    let normalized_x = (position.x + 1.0) * 0.5; // Convert from [-1,1] to [0,1]
    return uint(normalized_x * float(n_types)) % n_types;
}

uint generate_random_type(uint seed, uint n_types) {
    return uint(random_f32(seed * 4) * float(n_types)) % n_types;
}

uint generate_line_h_type(float2 position, uint n_types) {
    // Horizontal line in the middle, distribute other areas across remaining types
    if (abs(position.y) < 0.1) {
        return 0; // Center line gets type 0
    } else {
        // Distribute upper and lower areas across remaining types
        let normalized_y = (position.y + 1.0) * 0.5; // Convert from [-1,1] to [0,1]
        let region_type = uint(normalized_y * float(n_types - 1)) + 1; // Use types 1 to n_types-1
        return region_type % n_types;
    }
}

uint generate_line_v_type(float2 position, uint n_types) {
    // Vertical line in the middle, distribute other areas across remaining types
    if (abs(position.x) < 0.1) {
        return 0; // Center line gets type 0
    } else {
        // Distribute left and right areas across remaining types
        let normalized_x = (position.x + 1.0) * 0.5; // Convert from [-1,1] to [0,1]
        let region_type = uint(normalized_x * float(n_types - 1)) + 1; // Use types 1 to n_types-1
        return region_type % n_types;
    }
}

uint generate_spiral_type(float2 position, uint n_types) {
    let distance = length(position);
    let angle = atan2(position.y, position.x);
    let spiral_value = distance + angle * 0.159; // 0.159 ≈ 1/(2π) for normalization
    let normalized_spiral = frac(spiral_value * 2.0); // Create repeating spiral pattern
    return uint(normalized_spiral * float(n_types)) % n_types;
}

uint generate_dithered_type(float2 position, uint seed, uint n_types) {
    // Create bold color bands that blend at the edges (classic web JPEG style)
    
    let distance = length(position);
    let angle = atan2(position.y, position.x);
    
    // Create bold radial bands
    let band_value = distance * float(n_types);
    let base_band = uint(floor(band_value));
    
    // Add blending at edges using noise
    let noise_seed = uint((position.x + 1.0) * 1000.0) + uint((position.y + 1.0) * 1000.0) + seed;
    let noise = random_f32(noise_seed);
    
    // Calculate how close we are to the next band boundary
    let band_fraction = frac(band_value);
    
    // Blend between bands at edges (within 20% of band boundaries)
    if (band_fraction > 0.8 && noise > 0.5) {
        return (base_band + 1) % n_types;
    } else if (band_fraction < 0.2 && noise < 0.5) {
        return (base_band + n_types - 1) % n_types;
    }
    
    return base_band % n_types;
}

uint generate_wavy_line_h_type(float2 position, uint seed, uint n_types) {
    // Create wavy horizontal lines using sine waves
    let wave_frequency = 2.5; // Number of waves across the width
    let wave_amplitude = 0.25; // Amplitude of the waves
    let line_thickness = 0.08; // Thickness of the wavy lines
    
    // Create multiple wavy lines
    let normalized_y = (position.y + 1.0) * 0.5; // Convert from [-1,1] to [0,1]
    let line_spacing = 1.0 / float(n_types); // Space between lines
    
    // Check each wavy line to see if this position is within it
    for (var i = 0; i < n_types; i = i + 1) {
        let line_center = (float(i) + 0.5) * line_spacing;
        
        // Calculate the wavy line position using sine wave
        let wave_offset = sin(position.x * wave_frequency * 3.14159) * wave_amplitude;
        let line_y = line_center + wave_offset;
        
        // Check if position is within the wavy line
        let distance_to_line = abs(normalized_y - line_y);
        if (distance_to_line < line_thickness) {
            return i;
        }
    }
    
    // For areas outside the wavy lines, distribute based on y position
    let background_type = uint(normalized_y * float(n_types)) % n_types;
    return background_type;
}

uint generate_wavy_line_v_type(float2 position, uint seed, uint n_types) {
    // Create wavy vertical lines using sine waves
    let wave_frequency = 2.5; // Number of waves across the height
    let wave_amplitude = 0.25; // Amplitude of the waves
    let line_thickness = 0.08; // Thickness of the wavy lines
    
    // Create multiple wavy lines
    let normalized_x = (position.x + 1.0) * 0.5; // Convert from [-1,1] to [0,1]
    let line_spacing = 1.0 / float(n_types); // Space between lines
    
    // Check each wavy line to see if this position is within it
    for (var i = 0; i < n_types; i = i + 1) {
        let line_center = (float(i) + 0.5) * line_spacing;
        
        // Calculate the wavy line position using sine wave (waves along y-axis)
        let wave_offset = sin(position.y * wave_frequency * 3.14159) * wave_amplitude;
        let line_x = line_center + wave_offset;
        
        // Check if position is within the wavy line
        let distance_to_line = abs(normalized_x - line_x);
        if (distance_to_line < line_thickness) {
            return i;
        }
    }
    
    // For areas outside the wavy lines, distribute based on x position
    let background_type = uint(normalized_x * float(n_types)) % n_types;
    return background_type;
}

[shader("compute")]
[numthreads(64,  1,  1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    if (index >= init_params.spawn_count) {
        return;
    }
    
    let particle_index = init_params.start_index + index;
    let seed = init_params.random_seed + index;
    
    // Generate position based on generator type
    float2 position;
    switch (init_params.position_generator) {
        case 0: { // Random
            position = generate_random_position(seed);
            break;
        }
        case 1: { // Center
            position = generate_center_position(seed);
            break;
        }
        case 2: { // UniformCircle
            position = generate_uniform_circle_position(seed);
            break;
        }
        case 3: { // CenteredCircle
            position = generate_centered_circle_position(seed);
            break;
        }
        case 4: { // Ring
            position = generate_ring_position(seed);
            break;
        }
        case 5: { // RainbowRing
            let type_id = index % init_params.species_count;
            position = generate_rainbow_ring_position(seed, type_id, init_params.species_count);
            break;
        }
        case 6: { // ColorBattle
            let type_id = index % init_params.species_count;
            position = generate_color_battle_position(seed, type_id, init_params.species_count);
            break;
        }
        case 7: { // ColorWheel
            let type_id = index % init_params.species_count;
            position = generate_color_wheel_position(seed, type_id, init_params.species_count);
            break;
        }
        case 8: { // Line
            position = generate_line_position(seed);
            break;
        }
        case 9: { // Spiral
            position = generate_spiral_position(seed);
            break;
        }
        case 10: { // RainbowSpiral
            let type_id = index % init_params.species_count;
            position = generate_rainbow_spiral_position(seed, type_id, init_params.species_count);
            break;
        }
        default: {
            position = generate_random_position(seed);
            break;
        }
    }
    
    let normalized_position = position;
    let world_half_size = float2(max(init_params.width, 0.0001), max(init_params.height, 0.0001)) * 0.5;
    position *= world_half_size;

    // Generate initial type based on generator
    uint initial_type;
    switch (init_params.type_generator) {
        case 0: { // Radial
            initial_type = generate_radial_type(normalized_position, init_params.species_count);
            break;
        }
        case 1: { // Polar
            initial_type = generate_polar_type(normalized_position, init_params.species_count);
            break;
        }
        case 2: { // StripesH
            initial_type = generate_stripes_h_type(normalized_position, init_params.species_count);
            break;
        }
        case 3: { // StripesV
            initial_type = generate_stripes_v_type(normalized_position, init_params.species_count);
            break;
        }
        case 4: { // Random
            initial_type = generate_random_type(seed, init_params.species_count);
            break;
        }
        case 5: { // LineH
            initial_type = generate_line_h_type(normalized_position, init_params.species_count);
            break;
        }
        case 6: { // LineV
            initial_type = generate_line_v_type(normalized_position, init_params.species_count);
            break;
        }
        case 7: { // Spiral
            initial_type = generate_spiral_type(normalized_position, init_params.species_count);
            break;
        }
        case 8: { // Dithered
            initial_type = generate_dithered_type(normalized_position, seed, init_params.species_count);
            break;
        }
        case 9: { // WavyLineH
            initial_type = generate_wavy_line_h_type(normalized_position, seed, init_params.species_count);
            break;
        }
        case 10: { // WavyLineV
            initial_type = generate_wavy_line_v_type(normalized_position, seed, init_params.species_count);
            break;
        }
        default: {
            initial_type = generate_random_type(seed, init_params.species_count);
            break;
        }
    }
    
    // Ensure type is within bounds
    initial_type = initial_type % init_params.species_count;
    
    // Initialize particle
    particles[particle_index] = Particle(
        position,
        float2(0.0, 0.0), // Zero initial velocity
        initial_type,
        0 // _pad field
    );
}
