// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/primordial_particles/shaders/init.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Primordial Particles Initialization Shader
// Randomly distributes particles across the world with random headings

static const float PI = 3.14159265359;

struct Particle {

    float2 position;
    float2 previous_position;
    float heading;
    uint grabbed;
    uint _pad0;
    uint _pad1;
};

struct InitParams {

    uint start_index;
    uint spawn_count;
    float width;
    float height;
    
    uint random_seed;
    uint position_generator; // 0=Random, 1=Center, 2=UniformCircle, etc.
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

float random(uint seed) {
    return float(hash(seed)) / float(0xffffffffu);
}

// Generate random position within world bounds [-1,1] coordinate space
float2 random_position(uint index) {
    let seed1 = init_params.random_seed + index * 2654435761u;
    let seed2 = init_params.random_seed + index * 1013904223u;
    
    let x = random(seed1) * 2.0 - 1.0; // [0,1] -> [-1,1]
    let y = random(seed2) * 2.0 - 1.0; // [0,1] -> [-1,1]
    
    return float2(x, y);
}

// Generate random heading
float random_heading(uint index) {
    let seed = init_params.random_seed + index * 1664525u;
    return random(seed) * 2.0 * PI;
}

// Position generation functions - using [-1,1] coordinate system
float2 generate_random_position(uint seed) {
    let x = random(seed * 2) * 2.0 - 1.0; // [0,1] -> [-1,1]
    let y = random(seed * 3) * 2.0 - 1.0; // [0,1] -> [-1,1]
    return float2(x, y); // [-1,1] x [-1,1]
}

float2 generate_center_position(uint seed) {
    let x = random(seed * 2) * 2.0 - 1.0; // [0,1] -> [-1,1]
    let y = random(seed * 3) * 2.0 - 1.0; // [0,1] -> [-1,1]
    let scale = 0.3; // Scale around center (0,0)
    return float2(x * scale, y * scale);
}

float2 generate_uniform_circle_position(uint seed) {
    let angle = random(seed * 2) * 2.0 * PI;
    let radius = sqrt(random(seed * 3)) * 0.8; // Scale for [-1,1] space (radius up to 0.8)
    return float2(cos(angle) * radius, sin(angle) * radius);
}

float2 generate_centered_circle_position(uint seed) {
    let angle = random(seed * 2) * 2.0 * PI;
    let radius = random(seed * 3) * 0.8; // Scale for [-1,1] space
    return float2(cos(angle) * radius, sin(angle) * radius);
}

float2 generate_ring_position(uint seed) {
    let angle = random(seed * 2) * 2.0 * PI;
    let radius = 0.35 + 0.01 * (random(seed * 3) - 0.5) * 2.0; // Ring in [-1,1] space
    return float2(cos(angle) * radius, sin(angle) * radius);
}

float2 generate_line_position(uint seed) {
    let x = random(seed * 2) * 2.0 - 1.0; // Full width in [-1,1]
    let y = (random(seed * 3) - 0.5) * 0.3; // Center around 0 with small spread
    return float2(x, y);
}

float2 generate_spiral_position(uint seed) {
    let max_rotations = 2.0;
    let f = random(seed * 2);
    let angle = max_rotations * 2.0 * PI * f;
    let spread = 0.25 * min(f, 0.2); // Spiral spread
    let radius = 0.45 * f + spread * (random(seed * 3) - 0.5) * 2.0; // Scale for [-1,1] space
    return float2(radius * cos(angle), radius * sin(angle));
}

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let local_index = global_id.x;
    let global_index = init_params.start_index + local_index;
    
    if (local_index >= init_params.spawn_count) {
        return;
    }
    
    let seed = init_params.random_seed + local_index;
    
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
        case 5: { // Line
            position = generate_line_position(seed);
            break;
        }
        case 6: { // Spiral
            position = generate_spiral_position(seed);
            break;
        }
        default: {
            position = generate_random_position(seed);
            break;
        }
    }
    
    // Initialize particle with generated position and random heading
    particles[global_index].position = position;
    particles[global_index].previous_position = float2(0.0, 0.0);
    particles[global_index].heading = random_heading(global_index);
    particles[global_index].grabbed = 0;
    particles[global_index]._pad0 = 0;
    particles[global_index]._pad1 = 0;
}
