// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/voronoi_ca/shaders/infinite_render.wgsl
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

struct VertexOutput {

    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

// VCA-specific texture-based binding
[[vk::binding(0, 0)]]
Texture2D<float4> display_tex;
[[vk::binding(1, 0)]]
SamplerState display_sampler;

// Render parameters for texture-based simulations
[[vk::binding(2, 0)]]
ConstantBuffer<RenderParams> texture_render_params;

[[vk::binding(0, 1)]]
ConstantBuffer<CameraUniform> camera;

struct RenderParams {

    uint filtering_mode; // 0 = nearest, 1 = linear, 2 = lanczos
    uint _pad1;
    uint _pad2;
    uint _pad3;
};

// Calculate how many tiles we need based on zoom level
int calculate_tile_count(float zoom) {
    let visible_world_size = 2.0 / zoom;
    // Match the Rust-side calculation exactly
    let tiles_needed = int(ceil(visible_world_size / 2.0)) + 6;
    let min_tiles = ((zoom < 0.1) ? (7) : (5));
    return min(max(tiles_needed, min_tiles), 1024);
}

// Calculate the starting tile offset based on camera position
int2 calculate_tile_start(float2 camera_pos, float zoom) {
    let tile_center = int2(
        int(round(camera_pos.x / 2.0)),
        int(round(camera_pos.y / 2.0))
    );
    
    let tile_count = calculate_tile_count(zoom);
    let half_tiles = tile_count / 2;
    
    return int2(
        tile_center.x - half_tiles,
        tile_center.y - half_tiles
    );
}

// Vertex shader for infinite instanced rendering
[shader("vertex")]
VertexOutput vs_main(
    uint vertex_index : SV_VertexID,
    uint instance_index : SV_InstanceID,
){
    var pos = float2[6](
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2( 1.0,  1.0),
    );
    var uv = float2[6](
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(0.0, 0.0),
        float2(1.0, 1.0),
        float2(1.0, 0.0),
    );
    
    let tile_count = calculate_tile_count(camera.zoom);
    let tile_start = calculate_tile_start(camera.position, camera.zoom);
    
    let grid_x = int(instance_index % uint(tile_count)) + tile_start.x;
    let grid_y = int(instance_index / uint(tile_count)) + tile_start.y;
    
    var world_pos = float2(
        pos[vertex_index].x + float(grid_x) * 2.0,
        pos[vertex_index].y + float(grid_y) * 2.0
    );
    
    VertexOutput out;
    out.position = mul(camera.transform_matrix, float4(world_pos, 0.0, 1.0));
    out.uv = uv[vertex_index];
    return out;
}

// Fragment shader for VCA texture-based rendering
[shader("fragment")]
float4 fs_main_texture(VertexOutput in) : SV_Target0 {
    float4 base_color;
    
    if (texture_render_params.filtering_mode == 0) {
        // Nearest neighbor
        base_color = display_tex.Sample(display_sampler, in.uv);
    } else if (texture_render_params.filtering_mode == 1) {
        // Linear (bilinear interpolation)
        base_color = display_tex.Sample(display_sampler, in.uv);
    } else {
        // Lanczos filtering
    uint tex_width = 0;
    uint tex_height = 0;
    display_tex.GetDimensions(tex_width, tex_height);
        
        let tex_dims = uint2(tex_width, tex_height);
        let tex_x = in.uv.x * float(tex_dims.x);
        let tex_y = in.uv.y * float(tex_dims.y);
        
        let lanczos_a = 2.0; // Lanczos window size
        let radius = int(lanczos_a);
        
        var color_sum = float4(0.0);
        var weight_sum = 0.0;
        
        // Sample in a radius around the target pixel
        for (var dy = -radius; dy <= radius; dy++) {
            for (var dx = -radius; dx <= radius; dx++) {
                let sample_x = int(floor(tex_x)) + dx;
                let sample_y = int(floor(tex_y)) + dy;
                
                // Clamp to texture bounds
                let clamped_x = uint(clamp(float(sample_x), 0.0, float(tex_dims.x - 1)));
                let clamped_y = uint(clamp(float(sample_y), 0.0, float(tex_dims.y - 1)));
                
                // Calculate distance from target pixel
                let dist_x = (float(sample_x) - tex_x);
                let dist_y = (float(sample_y) - tex_y);
                
                // Calculate Lanczos weights
                let weight_x = lanczos_kernel(dist_x, lanczos_a);
                let weight_y = lanczos_kernel(dist_y, lanczos_a);
                let weight = weight_x * weight_y;
                
                // Sample the pixel
                let sample_uv = float2(
                    float(clamped_x) / float(tex_dims.x),
                    float(clamped_y) / float(tex_dims.y)
                );
                let sample_color = display_tex.Sample(display_sampler, sample_uv);
                
                color_sum += sample_color * weight;
                weight_sum += weight;
            }
        }
        
        // Normalize by total weight
        base_color = color_sum / weight_sum;
    }
    
    // Don't discard transparent pixels, just return them as-is
    // This allows the background to show through transparent areas
    return base_color;
}

// Lanczos kernel function
float lanczos_kernel(float x, float a) {
    if (abs(x) >= a) {
        return 0.0;
    }
    if (abs(x) < 0.0001) {
        return 1.0;
    }
    let x_pi = x * 3.14159265359;
    let x_pi_a = x_pi / a;
    return (sin(x_pi) * sin(x_pi_a)) / (x_pi * x_pi_a);
}
