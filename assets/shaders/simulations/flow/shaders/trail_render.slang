// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/flow/shaders/trail_render.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

#include "../../../common/texture.slang"

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
ConstantBuffer<SimParams> sim_params;
[[vk::binding(1, 0)]]
RWTexture2D<float4> trail_map;
[[vk::binding(0, 1)]]
ConstantBuffer<CameraUniform> camera;

struct VertexOutput {

    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
    float2 world_pos : TEXCOORD1;
};
[shader("vertex")]
VertexOutput vs_main(uint vertex_index : SV_VertexID) {
    // Full screen quad
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
        pos,
    );
}

// Convert world coordinates to trail texture coordinates
float2 world_to_trail_coords(float2 world_pos) {
    // World coordinates are -1 to 1, convert to 0 to 1 for texture sampling
    return float2(
        (world_pos.x + 1.0) * 0.5,
        (world_pos.y + 1.0) * 0.5  // Remove Y flip to match particle_update.wgsl
    );
}

[shader("fragment")]
float4 fs_main(float2 uv : TEXCOORD0, float2 world_pos : TEXCOORD1) : SV_Target0 {
    let trail_uv = world_to_trail_coords(world_pos);
    let texel = int2(
        int(trail_uv.x * float(sim_params.trail_map_width)),
        int(trail_uv.y * float(sim_params.trail_map_height))
    );
    let trail_data = LoadTexture(trail_map, texel);
    let trail_intensity = trail_data.a;
    let trail_color = trail_data.rgb;
    if (trail_intensity <= 0.01) {
        return float4(0.0, 0.0, 0.0, 0.0);
    }
    return float4(trail_color, trail_intensity);
} 
