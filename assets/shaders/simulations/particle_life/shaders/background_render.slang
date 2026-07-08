// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/particle_life/shaders/background_render.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

struct BackgroundParams {

    float4 background_color; // RGBA color values
};

[[vk::binding(0, 0)]]
ConstantBuffer<BackgroundParams> background_params;

struct VertexOutput {

    float4 position : SV_Position;
    float2 world_pos : TEXCOORD0;
};
[shader("vertex")]
VertexOutput vs_main(uint vertex_index : SV_VertexID) {
    // Full-screen quad
    let positions = float2[6](
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2( 1.0,  1.0)
    );
    
    let pos = positions[vertex_index];
    
    return VertexOutput(
        float4(pos, 0.0, 1.0),
        pos
    );
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0 {
    return background_params.background_color;
} 
