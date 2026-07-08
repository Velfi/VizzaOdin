// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/pellets/shaders/background_render.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

struct BackgroundParams {

    uint background_color_mode; // 0 = black, 1 = white, 2 = gray18, 3 = color scheme
};

[[vk::binding(0, 0)]]
ConstantBuffer<BackgroundParams> background_params;

[[vk::binding(1, 0)]]
ConstantBuffer<float4> background_color;


struct VertexOutput {

    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

[shader("vertex")]
VertexOutput vs_main(uint vertex_index : SV_VertexID) {
    // Full-screen quad
    let x = float((vertex_index << 1) & 2);
    let y = float(vertex_index & 2);
    
    VertexOutput out;
    out.position = float4(x * 2.0 - 1.0, y * 2.0 - 1.0, 0.0, 1.0);
    out.uv = float2(x, y);
    
    return out;
}

[shader("fragment")]
float4 fs_main(VertexOutput in) : SV_Target0 {
    if (background_params.background_color_mode == 0) {
        // Black background
        return float4(0.0, 0.0, 0.0, 1.0);
    } else if (background_params.background_color_mode == 1) {
        // White background
        return float4(1.0, 1.0, 1.0, 1.0);
    } else if (background_params.background_color_mode == 2) {
        // Gray18 background
        return float4(0.18, 0.18, 0.18, 1.0);
    } else if (background_params.background_color_mode == 3) {
        // Color scheme background - use the LUT background color
        return background_color;
    }
    
    // Default to black
    return float4(0.0, 0.0, 0.0, 1.0);
} 
