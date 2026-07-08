// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/flow/shaders/particle_render.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

#include "../../../common/texture.slang"
#include "../../../common/lut.slang"
#include "common.slang"

[[vk::binding(0, 0)]]
StructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
ConstantBuffer<SimParams> sim_params;
[[vk::binding(2, 0)]]
StructuredBuffer<uint> lut_data;
[[vk::binding(0, 1)]]
ConstantBuffer<CameraUniform> camera;

// Get color from LUT
float3 get_lut_color(float intensity) {
    let lut_index = clamp(intensity * 255.0, 0.0, 255.0);
    let index = uint(lut_index);
    
    // LUT data format: [r0, r1, ..., r255, g0, g1, ..., g255, b0, b1, ..., b255]
    let r_srgb = float(lut_data[index]) / 255.0;
    let g_srgb = float(lut_data[index + 256]) / 255.0;
    let b_srgb = float(lut_data[index + 512]) / 255.0;
    
    return linear_from_srgb(float3(r_srgb, g_srgb, b_srgb));
}

struct VertexOutput {

    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
    uint particle_index : TEXCOORD1;
};
[shader("vertex")]
VertexOutput vs_main(uint vertex_index : SV_VertexID, uint instance_index : SV_InstanceID) {
    let particle = particles[instance_index];
    
    // Skip inactive particles by moving them off-screen
    if (particle.is_alive == 0) {
        return VertexOutput(
            float4(-10.0, -10.0, 0.0, 1.0), // Move off-screen
            float2(0.0, 0.0),
            instance_index,
        );
    }
    
    // Create a quad centered at particle position
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
    
    // Calculate quad offset for this vertex
    let quad_offset = pos * float(sim_params.particle_size) / float2(float(sim_params.screen_width), float(sim_params.screen_height));
    
    // Add quad offset to particle position
    let world_pos = particle.position + quad_offset;
    
    // Don't apply camera transformation in offscreen pass - let 3x3 shader handle it
    
    return VertexOutput(
        float4(world_pos, 0.0, 1.0),
        uv,
        instance_index,
    );
}

[shader("fragment")]
float4 fs_main(float2 uv : TEXCOORD0, uint particle_index : TEXCOORD1) : SV_Target0 {
    let particle = particles[particle_index];
    
    // Check if particle is dead (age >= lifetime) - if so, discard it completely
    if (particle.age >= sim_params.particle_lifetime) {
        discard;
    }
    
    // Get particle shape from uniform
    let shape = sim_params.particle_shape;
    
    // Check if pixel is inside the particle shape
    var is_inside = false;
    let center = float2(0.5, 0.5);
    let offset = uv - center;
    
    if (shape == 0) { // Circle
        let dist = distance(uv, center);
        is_inside = dist <= 0.5;
    } else if (shape == 1) { // Square
        is_inside = abs(offset.x) <= 0.5 && abs(offset.y) <= 0.5;
    } else if (shape == 2) { // Triangle
        let triangle_uv = float2(offset.x, offset.y * 1.732); // Scale Y for equilateral triangle
        is_inside = abs(triangle_uv.x) + abs(triangle_uv.y) <= 0.5;
    } else if (shape == 3) { // Star
        let angle = atan2(offset.y, offset.x);
        let radius = length(offset);
        let star_radius = 0.5;
        let inner_radius = star_radius * 0.4;
        let points = 5.0;
        let angle_per_point = 6.28318 / points;
        let point_angle = (angle + 6.28318) % angle_per_point;
        let point_radius = lerp(inner_radius, star_radius, smoothstep(0.0, angle_per_point * 0.3, point_angle));
        is_inside = radius <= point_radius;
    } else if (shape == 4) { // Diamond
        is_inside = abs(offset.x) + abs(offset.y) <= 0.5;
    }
    
    if (!is_inside) {
        discard;
    }
    
    // Create smooth fade for particle edges
    let fade = 1.0 - smoothstep(0.0, 0.5, length(offset));
    
    // Calculate color based on display mode
    var color_intensity = 0.0;
    
    if (sim_params.display_mode == 0) { // Age mode
        // Use particle age as the color intensity to create a gradient effect
        let age_ratio = particle.age / sim_params.particle_lifetime;
        color_intensity = 1.0 - age_ratio; // Younger particles = higher intensity
    } else if (sim_params.display_mode == 1) { // Random mode
        // Use the stored LUT index from the particle (set during creation)
        color_intensity = float(particle.lut_index) / 255.0;
    } else if (sim_params.display_mode == 2) { // Direction mode
        // Use the stored LUT index from the particle (set during update based on velocity)
        color_intensity = float(particle.lut_index) / 255.0;
    } else {
        // Fallback to age mode if display mode is invalid
        let age_ratio = particle.age / sim_params.particle_lifetime;
        color_intensity = 1.0 - age_ratio;
    }
    
    let particle_color = get_lut_color(color_intensity);
    
    // Apply particle fade
    let alpha = 1.0 - (particle.age / sim_params.particle_lifetime) * 0.5;
    return float4(particle_color, alpha * fade);
} 
