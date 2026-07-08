// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/flow/shaders/trail_decay_diffusion.wgsl
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

struct FlowVector {

    float2 position;
    float2 direction;
};

[[vk::binding(0, 0)]]
ConstantBuffer<SimParams> sim_params;
[[vk::binding(1, 0)]]
RWTexture2D<float4> trail_map;
[[vk::binding(2, 0)]]
StructuredBuffer<FlowVector> flow_vectors;

[shader("compute")]
[numthreads(16,  16, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let x = global_id.x;
    let y = global_id.y;
    if (x >= sim_params.trail_map_width || y >= sim_params.trail_map_height) {
        return;
    }
    let map_size = float2(float(sim_params.trail_map_width), float(sim_params.trail_map_height));
    let world_x = (float(x) / map_size.x) * 2.0 - 1.0;
    let world_y = (float(y) / map_size.y) * 2.0 - 1.0;
    let world_pos = float2(world_x, world_y);
    var current_trail = LoadTexture(trail_map, int2(int(x), int(y)));
    var current_intensity = current_trail.a;
    var current_color = current_trail.rgb;
    
    // --- Proper advection with inline bilinear sampling ---
    let dt = sim_params.delta_time;
    
    // Inline bilinear sampling for flow field
    let grid_w = 128.0;
    let grid_h = 128.0;
    let tx = (world_pos.x + 1.0) * 0.5 * (grid_w - 1.0);
    let ty = (world_pos.y + 1.0) * 0.5 * (grid_h - 1.0);
    let x0 = uint(floor(tx));
    let x1 = uint(min(ceil(tx), grid_w - 1.0));
    let y0 = uint(floor(ty));
    let y1 = uint(min(ceil(ty), grid_h - 1.0));
    let fx = tx - float(x0);
    let fy = ty - float(y0);
    let idx00 = y0 * uint(grid_w) + x0;
    let idx10 = y0 * uint(grid_w) + x1;
    let idx01 = y1 * uint(grid_w) + x0;
    let idx11 = y1 * uint(grid_w) + x1;
    let v00 = flow_vectors[idx00].direction;
    let v10 = flow_vectors[idx10].direction;
    let v01 = flow_vectors[idx01].direction;
    let v11 = flow_vectors[idx11].direction;
    let v0 = lerp(v00, v10, fx);
    let v1 = lerp(v01, v11, fx);
    let flow = lerp(v0, v1, fy);
    
    let back_pos_world = world_pos - flow * sim_params.particle_speed * dt;
    let back_x = (back_pos_world.x + 1.0) * 0.5 * map_size.x;
    let back_y = (back_pos_world.y + 1.0) * 0.5 * map_size.y;
    
    // Inline bilinear sampling for trail map
    let px = clamp(back_x, 0.0, map_size.x - 1.0);
    let py = clamp(back_y, 0.0, map_size.y - 1.0);
    let tx0 = int(floor(px));
    let tx1 = int(min(ceil(px), map_size.x - 1.0));
    let ty0 = int(floor(py));
    let ty1 = int(min(ceil(py), map_size.y - 1.0));
    let tfx = px - float(tx0);
    let tfy = py - float(ty0);
    let c00 = LoadTexture(trail_map, int2(tx0, ty0));
    let c10 = LoadTexture(trail_map, int2(tx1, ty0));
    let c01 = LoadTexture(trail_map, int2(tx0, ty1));
    let c11 = LoadTexture(trail_map, int2(tx1, ty1));
    let c0 = lerp(c00, c10, tfx);
    let c1 = lerp(c01, c11, tfx);
    let advected_trail = lerp(c0, c1, tfy);
    
    let advection_blend = sim_params.trail_wash_out_rate;
    current_intensity = lerp(current_intensity, advected_trail.a, advection_blend);
    current_color = lerp(current_color, advected_trail.rgb, advection_blend);
    
    // --- Decay and diffusion as before ---
    var new_intensity = current_intensity * (1.0 - sim_params.trail_decay_rate);
    var new_color = current_color;
    let diffusion_rate = sim_params.trail_diffusion_rate;
    if (diffusion_rate > 0.0) {
        let x_prev = (x + sim_params.trail_map_width - 1) % sim_params.trail_map_width;
        let x_next = (x + 1) % sim_params.trail_map_width;
        let y_prev = (y + sim_params.trail_map_height - 1) % sim_params.trail_map_height;
        let y_next = (y + 1) % sim_params.trail_map_height;
        let left = LoadTexture(trail_map, int2(int(x_prev), int(y)));
        let right = LoadTexture(trail_map, int2(int(x_next), int(y)));
        let up = LoadTexture(trail_map, int2(int(x), int(y_prev)));
        let down = LoadTexture(trail_map, int2(int(x), int(y_next)));
        let neighbor_intensity_avg = (left.a + right.a + up.a + down.a) * 0.25;
        let neighbor_color_avg = (left.rgb + right.rgb + up.rgb + down.rgb) * 0.25;
        new_intensity = new_intensity * (1.0 - diffusion_rate) + neighbor_intensity_avg * diffusion_rate;
        new_color = new_color * (1.0 - diffusion_rate) + neighbor_color_avg * diffusion_rate;
    }
    StoreTexture(trail_map, int2(int(x), int(y)), float4(new_color, new_intensity));
} 
