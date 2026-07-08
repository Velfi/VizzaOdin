// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/primordial_particles/shaders/background_render.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Primordial Particles Background Render Shader
// Renders a simple background

struct CameraUniform {

    float4x4 transform_matrix;
    float2 position;
    float zoom;
    float aspect_ratio;
};

struct BackgroundParams {

    float4 background_color; // RGBA color values
};

[[vk::binding(0, 0)]]
ConstantBuffer<CameraUniform> camera;

[[vk::binding(1, 0)]]
ConstantBuffer<BackgroundParams> background_params;

struct VertexOutput {

    float4 position : SV_Position;
    float2 world_pos : TEXCOORD0;
};

[shader("vertex")]
VertexOutput vs_main(uint vertex_index : SV_VertexID) {
    // Create fullscreen quad
    float2 pos;
    switch (vertex_index) {
        case 0: { pos = float2(-1.0, -1.0); break; }
        case 1: { pos = float2(1.0, -1.0); break; }
        case 2: { pos = float2(-1.0, 1.0); break; }
        case 3: { pos = float2(1.0, -1.0); break; }
        case 4: { pos = float2(1.0, 1.0); break; }
        case 5: { pos = float2(-1.0, 1.0); break; }
        default: { pos = float2(0.0, 0.0); break; }
    }
    
    // Convert screen coordinates to world coordinates using proper transformation
    let world_pos = mul(camera.transform_matrix, float4(pos, 0.0, 1.0)).xy;
    
    return VertexOutput(
        float4(pos, 0.0, 1.0),
        world_pos
    );
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0 {
    return background_params.background_color;
}
