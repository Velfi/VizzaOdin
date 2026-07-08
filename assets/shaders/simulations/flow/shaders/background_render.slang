// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/flow/shaders/background_render.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

#include "../../../common/texture.slang"

static const float PI = 3.14159265359;

struct FlowVector {

    float2 position;
    float2 direction;
};

struct SimParams {

    uint autospawn_pool_size;
    uint autospawn_rate;
    uint brush_pool_size;
    uint brush_spawn_rate;
    float cursor_size;
    float cursor_x;
    float cursor_y;
    uint display_mode;
    uint flow_field_resolution;
    float height;
    uint mouse_button_down;
    float noise_dt_multiplier;
    float noise_scale;
    uint noise_seed;
    float noise_x;
    float noise_y;
    uint particle_autospawn;
    float particle_lifetime;
    uint particle_shape;
    uint particle_size;
    float particle_speed;
    uint screen_height;
    uint screen_width;
    float time;
    uint total_pool_size;
    float trail_decay_rate;
    float trail_deposition_rate;
    float trail_diffusion_rate;
    uint trail_map_height;
    uint trail_map_width;
    float trail_wash_out_rate;
    float vector_magnitude;
    float width;
    float delta_time;
    uint _padding_1;
    uint _padding_2;
};

struct CameraUniform {

    float4x4 transform_matrix;
    float2 position;
    float zoom;
    float aspect_ratio;
};

[[vk::binding(0, 0)]]
StructuredBuffer<FlowVector> flow_vectors;
[[vk::binding(1, 0)]]
StructuredBuffer<float> lut;
[[vk::binding(2, 0)]]
ConstantBuffer<SimParams> sim_params;
[[vk::binding(3, 0)]]
ConstantBuffer<float4> background_color;

[[vk::binding(0, 1)]]
ConstantBuffer<CameraUniform> camera;

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
        float2( 1.0,  1.0),
    );
    let uvs = float2[6](
        float2(0.0, 0.0),
        float2(1.0, 0.0),
        float2(0.0, 1.0),
        float2(0.0, 1.0),
        float2(1.0, 0.0),
        float2(1.0, 1.0),
    );
    
    let pos = positions[vertex_index];
    let uv = uvs[vertex_index];
    
    // Don't apply camera transformation in offscreen pass - let 3x3 shader handle it
    
    return VertexOutput(
        float4(pos, 0.0, 1.0),
        uv,
    );
}

[shader("fragment")]
float4 fs_main(float2 uv : TEXCOORD0) : SV_Target0 {
    // Use the pre-calculated background color
    return background_color;
}
