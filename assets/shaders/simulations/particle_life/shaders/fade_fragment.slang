// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/particle_life/shaders/fade_fragment.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Fullscreen fade fragment shader for particle traces

struct VertexOutput {

    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

struct FadeUniforms {

    float fade_amount; // Amount to subtract from alpha each frame (0.0 = no fade, higher = faster fade)
    float _pad1; // Padding for 16-byte alignment
    float _pad2; // Padding for 16-byte alignment
    float _pad3; // Padding for 16-byte alignment
};

[[vk::binding(0, 0)]]
ConstantBuffer<FadeUniforms> fade_uniforms;
[[vk::binding(1, 0)]]
Texture2D<float4> display_tex;
[[vk::binding(2, 0)]]
SamplerState display_sampler;

[shader("fragment")]
float4 main(VertexOutput input) : SV_Target0 {
    // Sample from the display texture
    let tex_color = display_tex.Sample(display_sampler, input.uv);
    
    // Apply alpha fade by subtracting a fixed amount each frame
    // fade_amount controls how much alpha to subtract per frame
    // 0.0 = no fade, higher values = faster fade
    let faded_alpha = max(tex_color.a - fade_uniforms.fade_amount, 0.0);
    
    // Keep the original color but reduce the alpha
    return float4(tex_color.rgb, faded_alpha);
} 
