// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/vectors/shaders/line_fragment.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

[[vk::binding(1, 0)]]
StructuredBuffer<uint> lut_data;

struct FragmentInput {

    float value : TEXCOORD0;
};

float3 get_lut_color(float intensity) {
    let idx = uint(clamp(intensity * 255.0, 0.0, 255.0));
    let r_srgb = float(lut_data[idx]) / 255.0;
    let g_srgb = float(lut_data[idx + 256]) / 255.0;
    let b_srgb = float(lut_data[idx + 512]) / 255.0;
    return float3(r_srgb, g_srgb, b_srgb);
}

[shader("fragment")]
float4 main(FragmentInput input) : SV_Target0 {
    let color = get_lut_color(input.value);
    return float4(color, 1.0);
}
