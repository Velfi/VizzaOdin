// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/gray_scott/shaders/background_render.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

struct BackgroundParams {

    uint background_type; // 0 = black, 1 = white, 2 = gradient
    uint gradient_enabled;
    uint gradient_type;
    float gradient_strength;

    float gradient_center_x;
    float gradient_center_y;
    float gradient_size;
    float gradient_angle;
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
    } else if (background_params.background_type == 2 && background_params.gradient_enabled != 0) {
        // Gradient background
        let world_pos = float2(
            in.uv.x * 2.0 - 1.0,
            in.uv.y * 2.0 - 1.0
        );
        
        var gradient_value = 0.0;
        
        if (background_params.gradient_type == 1) {
            // Linear gradient
            let direction = float2(
                cos(background_params.gradient_angle),
                sin(background_params.gradient_angle)
            );
            let center = float2(background_params.gradient_center_x, background_params.gradient_center_y);
            let offset = world_pos - center;
            gradient_value = dot(offset, direction) * background_params.gradient_strength;
        } else if (background_params.gradient_type == 2) {
            // Radial gradient
            let center = float2(background_params.gradient_center_x, background_params.gradient_center_y);
            let distance = length(world_pos - center);
            gradient_value = (1.0 - distance / background_params.gradient_size) * background_params.gradient_strength;
        } else if (background_params.gradient_type == 3) {
            // Ellipse gradient
            let center = float2(background_params.gradient_center_x, background_params.gradient_center_y);
            let offset = world_pos - center;
            let angle = background_params.gradient_angle;
            let cos_a = cos(angle);
            let sin_a = sin(angle);
            let rotated_x = offset.x * cos_a + offset.y * sin_a;
            let rotated_y = -offset.x * sin_a + offset.y * cos_a;
            let normalized_distance = sqrt((rotated_x * rotated_x) / (background_params.gradient_size * background_params.gradient_size) + 
                                         (rotated_y * rotated_y) / (background_params.gradient_size * background_params.gradient_size * 0.5));
            gradient_value = (1.0 - normalized_distance) * background_params.gradient_strength;
        } else if (background_params.gradient_type == 4) {
            // Spiral gradient
            let center = float2(background_params.gradient_center_x, background_params.gradient_center_y);
            let offset = world_pos - center;
            let angle = atan2(offset.y, offset.x);
            let distance = length(offset);
            let spiral_value = (angle + 3.14159265359) / (2.0 * 3.14159265359) + distance / background_params.gradient_size;
            gradient_value = (frac(spiral_value) * 2.0 - 1.0) * background_params.gradient_strength;
        } else if (background_params.gradient_type == 5) {
            // Checkerboard gradient
            let center = float2(background_params.gradient_center_x, background_params.gradient_center_y);
            let offset = world_pos - center;
            let angle = background_params.gradient_angle;
            let cos_a = cos(angle);
            let sin_a = sin(angle);
            let rotated_x = offset.x * cos_a + offset.y * sin_a;
            let rotated_y = -offset.x * sin_a + offset.y * cos_a;
            let scale = background_params.gradient_size;
            let checker_x = floor(rotated_x / scale);
            let checker_y = floor(rotated_y / scale);
            gradient_value = float((uint(checker_x) + uint(checker_y)) % 2) * background_params.gradient_strength;
        }
        
        // Clamp and apply gradient
        gradient_value = clamp(gradient_value, 0.0, 1.0);
        return float4(gradient_value, gradient_value, gradient_value, 1.0);
    }
    
    // Default to black
    return float4(0.0, 0.0, 0.0, 1.0);
} 
