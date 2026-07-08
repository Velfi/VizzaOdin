// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/pellets/shaders/trail_fade_fragment.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Fullscreen fade fragment shader for trail persistence

struct VertexOutput {

    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

struct FadeUniforms {

    float fade_amount;
    float _pad1;
    float _pad2;
    float _pad3;
};

[[vk::binding(0, 0)]]
ConstantBuffer<FadeUniforms> fade_uniforms;
[[vk::binding(1, 0)]]
Texture2D<float4> prev_trail_tex;
[[vk::binding(2, 0)]]
SamplerState prev_trail_sampler;

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0 {
    let tex_color = prev_trail_tex.Sample(prev_trail_sampler, input.uv);
    let faded_alpha = max(tex_color.a - fade_uniforms.fade_amount, 0.0);
    return float4(tex_color.rgb, faded_alpha);
}

