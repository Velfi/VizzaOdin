// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/pellets/shaders/post_effect_fragment.wgsl
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
ConstantBuffer<PostEffectParams> params;
[[vk::binding(1, 0)]]
Texture2D<float4> input_texture;
[[vk::binding(2, 0)]]
SamplerState input_sampler;

[shader("fragment")]
float4 fs_main(float2 uv : TEXCOORD0) : SV_Target0 {
    // Sample the input texture
    let color = input_texture.Sample(input_sampler, uv);
    
    // Apply brightness
    let bright_color = color.rgb * params.brightness;
    
    // Apply contrast
    let contrast_color = (bright_color - 0.5) * params.contrast + 0.5;
    
    // Apply saturation
    let luminance = dot(contrast_color, float3(0.299, 0.587, 0.114));
    let saturated_color = lerp(float3(luminance), contrast_color, params.saturation);
    
    // Apply gamma correction
    let gamma_corrected = pow(saturated_color, float3(1.0 / params.gamma));
    
    return float4(gamma_corrected, color.a);
} 