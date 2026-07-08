// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/gray_scott/shaders/noise_seed.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// GPU-based noise seeding shader for Gray-Scott simulation
// Writes directly to an RGBA32F storage texture used by the simulation.

[[vk::binding(0, 0)]]
RWTexture2D<float4> uvs_texture;

[[vk::binding(1, 0)]]
ConstantBuffer<SimulationParams> params;

struct SimulationParams {

    uint width;
    uint height;
    uint seed;
    float noise_strength;
};// High-quality hash function for pseudo-random generation
uint hash(uint seed) {
    var x = seed;
    x = ((x >> 16) ^ x) * 0x45d9f3bu;
    x = ((x >> 16) ^ x) * 0x45d9f3bu;
    x = (x >> 16) ^ x;
    return x;
}

// Convert hash to float [0.0, 1.0]
float random_float(uint seed) {
    return float(hash(seed)) / float(0xffffffffu);
}

// 2D spatial noise function
float noise2D(uint x, uint y, uint seed) {
    return random_float(x * 73856093 + y * 19349663 + seed);
}

// Fractal Brownian Motion (fBm) for richer noise patterns
float fbm_noise(uint x, uint y, uint seed) {
    var result = 0.0;
    var amplitude = 0.5;
    var frequency = 1.0;
    
    // Multiple octaves for fractal detail
    for (var i = 0; i < 4; i = i + 1) {
        let scaled_x = uint(float(x) * frequency);
        let scaled_y = uint(float(y) * frequency);
        result += noise2D(scaled_x, scaled_y, seed + i) * amplitude;
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return result;
}

[shader("compute")]
[numthreads(8,  8, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let x = global_id.x;
    let y = global_id.y;
    
    // Check bounds
    if (x >= params.width || y >= params.height) {
        return;
    }
    
    // Generate noise using spatial coordinates
    let noise_value = fbm_noise(x, y, params.seed);
    
    // Apply noise with configurable strength
    if (noise_value < (0.1 * params.noise_strength)) {
        // Seed reaction areas with high V concentration
        let u_val = 0.2 + noise_value * 0.3;
        let v_val = 0.8 + noise_value * 0.2;
        StoreTexture(uvs_texture, int2(int(x), int(y)), float4(u_val, v_val, 0.0, 0.0));
    } else {
        // Default empty state
        StoreTexture(uvs_texture, int2(int(x), int(y)), float4(1.0, 0.0, 0.0, 0.0));
    }
}
