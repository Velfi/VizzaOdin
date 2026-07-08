// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/pellets/shaders/trail_blit.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Blit shader to sample the trail texture onto the display texture

struct VertexOutput {

    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

[[vk::binding(0, 0)]]
Texture2D<float4> trail_texture;
[[vk::binding(1, 0)]]
SamplerState trail_sampler;

[shader("vertex")]
VertexOutput vs_main(uint vertex_index : SV_VertexID) {
    // Full-screen triangle
    var positions = float2[3](
        float2(-1.0, -1.0),
        float2(3.0, -1.0),
        float2(-1.0, 3.0)
    );
    var uvs = float2[3](
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0)
    );
    VertexOutput out;
    out.position = float4(positions[vertex_index], 0.0, 1.0);
    out.uv = uvs[vertex_index];
    return out;
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0 {
    return trail_texture.Sample(trail_sampler, input.uv);
}

