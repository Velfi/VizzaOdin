// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/particle_life/shaders/force_update.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Force matrix update compute shader
// Updates individual force matrix elements without full CPU-to-GPU transfer

struct ForceUpdateParams {

    uint species_a;
    uint species_b;
    float new_force;
    uint species_count;
};

[[vk::binding(0, 0)]]
RWStructuredBuffer<float> force_matrix;
[[vk::binding(1, 0)]]
ConstantBuffer<ForceUpdateParams> update_params;

[shader("compute")]
[numthreads(1,  1,  1)]
void main(uint3 id : SV_DispatchThreadID) {
    // Only one thread needed for a single force matrix update
    if (id.x != 0 || id.y != 0 || id.z != 0) {
        return;
    }
    
    // Calculate the index in the flattened force matrix
    let index = update_params.species_a * update_params.species_count + update_params.species_b;
    
    // Update the force matrix element
    force_matrix[index] = update_params.new_force;
}
