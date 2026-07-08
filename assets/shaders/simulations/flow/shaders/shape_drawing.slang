// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/flow/shaders/shape_drawing.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

#include "../../../common/texture.slang"

// Antialiased shape drawing compute shader for Flow Field
// Draws smooth geometric shapes directly onto the trail map

struct ShapeParams {

    float center_x;
    float center_y;
    float size;
    uint shape_type; // 0=Circle, 1=Square, 2=Triangle, 3=Star, 4=Diamond, 5=Line
    float4 color;
    float intensity;
    float antialiasing_width; // Width of antialiasing edge in pixels
    float rotation; // Rotation angle in radians
    float aspect_ratio; // For ellipses and rectangles
    uint trail_map_width;
    uint trail_map_height;
    uint _padding;
};

[[vk::binding(0, 0)]]
RWTexture2D<float4> trail_map;
[[vk::binding(1, 0)]]
ConstantBuffer<ShapeParams> shape_params;

// Signed distance functions for various shapes
float sdf_circle(float2 p, float radius) {
    return length(p) - radius;
}

float sdf_box(float2 p, float2 size) {
    let d = abs(p) - size;
    return length(max(d, float2(0.0))) + min(max(d.x, d.y), 0.0);
}

float sdf_triangle(float2 p, float size) {
    let k = sqrt(3.0);
    let px = abs(p.x) - size;
    let py = p.y + size / k;
    
    if (px + k * py > 0.0) {
        let temp = float2(px - k * py, -k * px - py) / 2.0;
        return -length(temp);
    }
    
    let px_clamped = max(px, 0.0);
    return -sqrt(px_clamped * px_clamped + py * py);
}

float sdf_star(float2 p, float r, float n, float m) {
    // Star with n points, inner radius m*r, outer radius r
    let an = 3.141593 / n;
    let en = 3.141593 / m;
    let acs = float2(cos(an), sin(an));
    let ecs = float2(cos(en), sin(en));
    
    let bn = (atan2(p.x, p.y) % (2.0 * an)) - an;
    let p_rot = length(p) * float2(cos(bn), abs(sin(bn)));
    
    let p_final = p_rot - r * acs;
    let p_clamped = float2(clamp(p_final.x, -ecs.y * r, ecs.y * r), p_final.y);
    
    return length(p_final - p_clamped) * sign(p_final.y - ecs.x * r);
}

float sdf_diamond(float2 p, float size) {
    return (abs(p.x) + abs(p.y)) - size;
}

// Rotation matrix
float2x2 rotate2d(float angle) {
    let c = cos(angle);
    let s = sin(angle);
    return float2x2(
        float2(c, -s),
        float2(s, c)
    );
}

// Main compute shader
[shader("compute")]
[numthreads(8,  8, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let pixel_coords = int2(int(global_id.x), int(global_id.y));
    
    // Check bounds
    if (global_id.x >= shape_params.trail_map_width || global_id.y >= shape_params.trail_map_height) {
        return;
    }
    
    // Convert pixel coordinates to world space (-1 to 1)
    let uv = float2(
        (float(global_id.x) / float(shape_params.trail_map_width)) * 2.0 - 1.0,
        (float(global_id.y) / float(shape_params.trail_map_height)) * 2.0 - 1.0
    );
    
    // Transform to shape local space
    let center = float2(shape_params.center_x, shape_params.center_y);
    let p = uv - center;
    
    // Apply rotation
    let rot = rotate2d(shape_params.rotation);
    let p_rotated = float2(
        rot[0][0] * p.x + rot[0][1] * p.y,
        rot[1][0] * p.x + rot[1][1] * p.y
    );
    
    // Apply aspect ratio scaling
    let p_scaled = float2(p_rotated.x, p_rotated.y / shape_params.aspect_ratio);
    
    // Calculate signed distance based on shape type
    float distance;
    
    switch (shape_params.shape_type) {
        case 0: { // Circle
            distance = sdf_circle(p_scaled, shape_params.size);
            break;
        }
        case 1: { // Square/Rectangle
            let size = float2(shape_params.size, shape_params.size);
            distance = sdf_box(p_scaled, size);
            break;
        }
        case 2: { // Triangle
            distance = sdf_triangle(p_scaled, shape_params.size);
            break;
        }
        case 3: { // Star
            distance = sdf_star(p_scaled, shape_params.size, 5.0, 2.5);
            break;
        }
        case 4: { // Diamond
            distance = sdf_diamond(p_scaled, shape_params.size);
            break;
        }
        default: { // Default to circle
            distance = sdf_circle(p_scaled, shape_params.size);
            break;
        }
    }
    
    // Calculate antialiased alpha based on distance
    let edge_width = shape_params.antialiasing_width * 0.01; // Convert to world space
    let alpha = 1.0 - smoothstep(-edge_width, edge_width, distance);
    
    // Only draw if alpha is significant
    if (alpha > 0.001) {
        // Read existing trail color
        let existing_color = LoadTexture(trail_map, pixel_coords);
        
        // Blend new shape with existing trail
        let shape_color = float4(
            shape_params.color.rgb,
            alpha * shape_params.intensity
        );
        
        // Alpha blending: new_color = src * src_alpha + dst * (1 - src_alpha)
        let final_color = float4(
            shape_color.rgb * shape_color.a + existing_color.rgb * (1.0 - shape_color.a),
            min(shape_color.a + existing_color.a, 1.0)
        );
        
        StoreTexture(trail_map, pixel_coords, final_color);
    }
}
