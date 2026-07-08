// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/vectors/shaders/line_vertex.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

struct CameraUniform {

    float4x4 transform_matrix;
    float2 position;
    float zoom;
    float aspect_ratio;
};

struct VertexInput {

    float2 position : TEXCOORD0;
    float value : TEXCOORD1;
};

struct VertexOutput {

    float4 position : SV_Position;
    float value : TEXCOORD0;
};

[[vk::binding(0, 0)]]
ConstantBuffer<CameraUniform> camera;

[shader("vertex")]
VertexOutput main(VertexInput input) {
    VertexOutput output;
    let pos = float4(input.position, 0.0, 1.0);
    output.position = mul(camera.transform_matrix, pos);
    output.value = input.value;
    return output;
}
