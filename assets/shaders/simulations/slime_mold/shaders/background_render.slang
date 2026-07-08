// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/slime_mold/shaders/background_render.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

struct BackgroundParams {

    uint background_type; // 0 = black, 1 = white
};

struct CameraUniform {

    float4x4 transform_matrix;
    float2 position;
    float zoom;
    float aspect_ratio;
};

[[vk::binding(0, 0)]]
ConstantBuffer<BackgroundParams> background_params;

[[vk::binding(0, 1)]]
ConstantBuffer<CameraUniform> camera;

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
    if (background_params.background_type == 0) {
        // Black background
        return float4(0.0, 0.0, 0.0, 1.0);
    } else if (background_params.background_type == 1) {
        // White background
        return float4(1.0, 1.0, 1.0, 1.0);
    }
    
    // Default to black
    return float4(0.0, 0.0, 0.0, 1.0);
} 
