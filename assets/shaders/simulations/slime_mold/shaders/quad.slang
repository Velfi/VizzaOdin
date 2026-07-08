// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/slime_mold/shaders/quad.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// quad.wgsl: Fullscreen quad vertex and fragment shaders

struct CameraUniform {

    float4x4 transform_matrix;
    float2 position;
    float zoom;
    float aspect_ratio;
};

struct VertexOutput {

    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

[[vk::binding(0, 0)]]
Texture2D<float4> display_tex;
[[vk::binding(1, 0)]]
SamplerState display_sampler;

[[vk::binding(0, 1)]]
ConstantBuffer<CameraUniform> camera;

[shader("vertex")]
VertexOutput vs_main(uint vertex_index : SV_VertexID) {
    var pos = float2[6](
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2( 1.0,  1.0),
    );
    var uv = float2[6](
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(0.0, 0.0),
        float2(1.0, 1.0),
        float2(1.0, 0.0),
    );
    VertexOutput out;
    out.position = mul(camera.transform_matrix, float4(pos[vertex_index], 0.0, 1.0));
    out.uv = uv[vertex_index];
    return out;
}

float4 fs_main(VertexOutput in) : SV_Target0 {
    return display_tex.Sample(display_sampler, in.uv);
} 
