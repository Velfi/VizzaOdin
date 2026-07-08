// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/particle_life/shaders/force_randomize.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Force matrix randomization compute shader
// Generates random force values entirely on GPU

struct RandomizeParams {

    uint species_count;
    uint random_seed;
    float min_force;
    float max_force;
};

[[vk::binding(0, 0)]]
RWStructuredBuffer<float> force_matrix;
[[vk::binding(1, 0)]]
ConstantBuffer<RandomizeParams> randomize_params;

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

[shader("compute")]
[numthreads(8,  8,  1)]
void main(uint3 id : SV_DispatchThreadID) {
    let species_a = id.x;
    let species_b = id.y;
    
    // Only process valid matrix elements
    if (species_a >= randomize_params.species_count || species_b >= randomize_params.species_count) {
        return;
    }
    
    // Calculate the index in the flattened force matrix
    let index = species_a * randomize_params.species_count + species_b;
    
    // Generate unique seed for this matrix element
    let seed = randomize_params.random_seed + index;
    
    // Generate random force value in the specified range
    let random_val = random_f32(seed);
    let force_range = randomize_params.max_force - randomize_params.min_force;
    let new_force = randomize_params.min_force + random_val * force_range;
    
    // Update the force matrix element
    force_matrix[index] = new_force;
}
