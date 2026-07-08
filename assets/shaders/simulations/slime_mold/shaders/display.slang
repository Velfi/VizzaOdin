// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/slime_mold/shaders/display.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Display shader for converting trail map to displayable texture
// Uses color scheme (planar LUT) for color mapping

struct SimSizeUniform {

    uint width;
    uint height;
    float decay_rate;
    float agent_jitter;
    float agent_speed_min;
    float agent_speed_max;
    float agent_turn_rate;
    float agent_sensor_angle;
    float agent_sensor_distance;
    float diffusion_rate;
    float pheromone_deposition_rate;
    uint gradient_enabled;
    uint gradient_type;
    float gradient_strength;
    float gradient_center_x;
    float gradient_center_y;
    float gradient_size;
    float gradient_angle;
    uint _pad1;
    uint _pad2;
};

[[vk::binding(0, 0)]]
StructuredBuffer<float> trail_map;

[[vk::binding(1, 0)]]
RWTexture2D<float4> display_tex;

[[vk::binding(2, 0)]]
ConstantBuffer<SimSizeUniform> sim_size;

[[vk::binding(3, 0)]]
StructuredBuffer<uint> lut_data;

[[vk::binding(4, 0)]]
StructuredBuffer<float> gradient_map;

// Bilinear interpolation for trail map sampling
float sample_trail_map_smooth(float2 pos) {
    let width = int(sim_size.width);
    let height = int(sim_size.height);
    // Wrap position to valid range (toroidal)
    let fx = floor(pos.x);
    let fy = floor(pos.y);
    let x0 = ((int(fx) % width) + width) % width;
    let y0 = ((int(fy) % height) + height) % height;
    let x1 = (x0 + 1) % width;
    let y1 = (y0 + 1) % height;
    
    let dx = pos.x - fx;
    let dy = pos.y - fy;
    
    let v00 = trail_map[y0 * width + x0];
    let v10 = trail_map[y0 * width + x1];
    let v01 = trail_map[y1 * width + x0];
    let v11 = trail_map[y1 * width + x1];
    
    let v0 = lerp(v00, v10, dx);
    let v1 = lerp(v01, v11, dx);
    return lerp(v0, v1, dy);
}

// Bilinear interpolation for gradient map sampling
float sample_gradient_map_smooth(float2 pos) {
    let width = int(sim_size.width);
    let height = int(sim_size.height);
    // Wrap position to valid range (toroidal)
    let fx = floor(pos.x);
    let fy = floor(pos.y);
    let x0 = ((int(fx) % width) + width) % width;
    let y0 = ((int(fy) % height) + height) % height;
    let x1 = (x0 + 1) % width;
    let y1 = (y0 + 1) % height;
    
    let dx = pos.x - fx;
    let dy = pos.y - fy;
    
    let v00 = gradient_map[y0 * width + x0];
    let v10 = gradient_map[y0 * width + x1];
    let v01 = gradient_map[y1 * width + x0];
    let v11 = gradient_map[y1 * width + x1];
    
    let v0 = lerp(v00, v10, dx);
    let v1 = lerp(v01, v11, dx);
    return lerp(v0, v1, dy);
}

// Convert from sRGB (gamma-corrected) to linear RGB
float srgb_to_linear(float srgb) {
    if (srgb <= 0.04045) {
        return srgb / 12.92;
    } else {
        return pow((srgb + 0.055) / 1.055, 2.4);
    }
}

// Get color from color scheme (planar LUT)
float3 get_lut_color(float intensity) {
    let idx = clamp(int(intensity * 255.0), 0, 255);
    let r_srgb = float(lut_data[idx]) / 255.0;
    let g_srgb = float(lut_data[256 + idx]) / 255.0;
    let b_srgb = float(lut_data[512 + idx]) / 255.0;
    
    return float3(
        srgb_to_linear(r_srgb),
        srgb_to_linear(g_srgb),
        srgb_to_linear(b_srgb)
    );
}

[shader("compute")]
[numthreads(16,  16,  1)]
void main(uint3 id : SV_DispatchThreadID) {
    uint tex_width = 0;
    uint tex_height = 0;
    display_tex.GetDimensions(tex_width, tex_height);
    if (id.x >= tex_width || id.y >= tex_height) {
        return;
    }

    // Map texture pixel to simulation coordinates (with sub-pixel precision)
    var sim_x = float(id.x) * float(sim_size.width) / float(tex_width);
    var sim_y = float(id.y) * float(sim_size.height) / float(tex_height);

    var color = float3(0.0);
    if (sim_x >= 0.0 && sim_x < float(sim_size.width) && sim_y >= 0.0 && sim_y < float(sim_size.height)) {
        // Use bilinear interpolation for smooth sampling
        let trail = sample_trail_map_smooth(float2(sim_x, sim_y));
        
        let intensity = trail;
        
        color = get_lut_color(intensity);
    }
    StoreTexture(display_tex, int2(int(id.x), int(id.y)), float4(color, 1.0));
} 
