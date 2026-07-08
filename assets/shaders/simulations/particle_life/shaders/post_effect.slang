// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/particle_life/shaders/post_effect.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

struct PostEffectParams {

    float brightness;
    float contrast;
    float saturation;
    float gamma;
};

[[vk::binding(0, 0)]]
Texture2D<float4> display_tex;
[[vk::binding(1, 0)]]
SamplerState display_sampler;
[[vk::binding(2, 0)]]
ConstantBuffer<PostEffectParams> params;

struct VertexOutput {

    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

[shader("vertex")]
VertexOutput vs_main(uint vertex_index : SV_VertexID) {
    let positions = float2[6](
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2( 1.0,  1.0)
    );
    
    let uvs = float2[6](
        float2(0.0, 0.0),
        float2(1.0, 0.0),
        float2(0.0, 1.0),
        float2(0.0, 1.0),
        float2(1.0, 0.0),
        float2(1.0, 1.0)
    );
    
    let pos = positions[vertex_index];
    let uv = uvs[vertex_index];
    
    return VertexOutput(
        float4(pos, 0.0, 1.0),
        uv
    );
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0 {
    let uv = input.uv;
    let base_color = display_tex.Sample(display_sampler, uv);
    
    // Apply brightness
    var color = base_color.rgb * params.brightness;
    
    // Apply contrast
    color = (color - 0.5) * params.contrast + 0.5;
    
    // Apply saturation
    let luminance = dot(color, float3(0.299, 0.587, 0.114));
    color = lerp(float3(luminance), color, params.saturation);
    
    // Apply gamma
    color = pow(color, float3(1.0 / params.gamma));
    
    return float4(color, base_color.a);
} 
