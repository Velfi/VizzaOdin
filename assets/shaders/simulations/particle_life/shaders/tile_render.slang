// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/particle_life/shaders/tile_render.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Tile-based rendering shader for improved particle life pipeline
// This shader renders individual tiles with camera-aware detail levels

struct Particle {

    float2 position;
    float2 velocity;
    uint species;
    uint _pad;
};

struct SimParams {

    uint particle_count;
    uint species_count;
    float max_force;
    float max_distance;
    float friction;
    uint wrap_edges;
    float width;
    float height;
    uint random_seed;
    float dt;
    float beta;
    float cursor_x;
    float cursor_y;
    float cursor_size;
    float cursor_strength;
    uint cursor_active;
    float brownian_motion;
    float particle_size;
    float aspect_ratio;
    uint _pad1;
};

struct TileParams {

    int tile_x;
    int tile_y;
    float camera_zoom;
    float _pad0; // Padding for 16-byte alignment
    float4 world_bounds; // [left, bottom, right, top] for this tile
    float2 texture_size; // [width, height] of tile texture
    float _pad1;
    float _pad2;
};

struct CameraAwareParams {

    float camera_zoom;
    float _pad0; // Padding for 16-byte alignment
    float2 camera_position;
    float2 viewport_size;
    float tile_size;
    uint max_tiles;
    float _pad1;
    float _pad2;
};

struct SpeciesColors {

    float4[9] colors;
};

struct ColorMode {

    uint mode;
    uint _pad1;
    uint _pad2;
    uint _pad3;
    float brightness;
    float contrast;
    float saturation;
    float gamma;
};

struct VertexOutput {

    float4 position : SV_Position;
    nointerpolation uint species : TEXCOORD0;
    float velocity_magnitude : TEXCOORD1;
    float2 world_pos : TEXCOORD2;
    float tile_fade_factor : TEXCOORD3;
    float2 uv : TEXCOORD4;
};

[[vk::binding(0, 0)]]
StructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
ConstantBuffer<SimParams> sim_params;
[[vk::binding(0, 1)]]
ConstantBuffer<TileParams> tile_params;
[[vk::binding(1, 1)]]
ConstantBuffer<CameraAwareParams> camera_aware_params;
[[vk::binding(0, 2)]]
ConstantBuffer<SpeciesColors> species_colors;
[[vk::binding(1, 2)]]
ConstantBuffer<ColorMode> color_mode;

// Calculate LOD factor based on camera zoom
float calculate_lod_factor(float camera_zoom) {
    // Base LOD factor - higher zoom = higher detail
    let base_lod = 1.0;
    
    // Adjust LOD based on zoom level
    // At high zoom (close), we want full detail
    // At low zoom (far), we want reduced detail
    let zoom_factor = clamp(camera_zoom / 2.0, 0.5, 2.0);
    
    return base_lod * zoom_factor;
}

// Calculate tile fade factor based on distance from camera
float calculate_tile_fade_factor(float2 tile_center, float2 camera_pos, float camera_zoom) {
    // Calculate distance from camera to tile center
    let distance = distance(tile_center, camera_pos);
    
    // Base fade distance - tiles beyond this start to fade
    let base_fade_distance = 2.0;
    
    // Adjust fade distance based on zoom level
    let fade_distance = max(base_fade_distance / camera_zoom, camera_aware_params.tile_size * float(max(camera_aware_params.max_tiles, 1u)));
    
    // Calculate fade factor (1.0 = fully visible, 0.0 = fully faded)
    let fade_factor = 1.0 - clamp(distance / fade_distance, 0.0, 1.0);
    
    // Apply smooth falloff
    return smoothstep(0.0, 1.0, fade_factor);
}

// Check if particle is visible within tile bounds
bool is_particle_visible_in_tile(float2 particle_pos, float4 world_bounds) {
    let left = world_bounds.x;
    let bottom = world_bounds.y;
    let right = world_bounds.z;
    let top = world_bounds.w;
    
    // Add some margin to ensure particles at edges are rendered
    let margin = 0.1;
    
    return particle_pos.x >= left - margin &&
           particle_pos.x <= right + margin &&
           particle_pos.y >= bottom - margin &&
           particle_pos.y <= top + margin;
}

[shader("vertex")]
VertexOutput vs_main(
    uint vertex_index : SV_VertexID,
    uint instance_index : SV_InstanceID
) {
    // Full-screen quad positions for instanced rendering
    let quad_positions = float2[6](
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2( 1.0,  1.0),
    );
    
    let quad_uvs = float2[6](
        float2(0.0, 0.0),
        float2(1.0, 0.0),
        float2(0.0, 1.0),
        float2(0.0, 1.0),
        float2(1.0, 0.0),
        float2(1.0, 1.0),
    );
    
    let particle = particles[instance_index];
    let quad_pos = quad_positions[vertex_index];
    let quad_uv = quad_uvs[vertex_index];
    let tile_size = float2(sim_params.width, sim_params.height);
    let tile_offset = float2(float(tile_params.tile_x), float(tile_params.tile_y)) * tile_size;
    let world_particle_pos = particle.position + tile_offset;
    
    // Check if particle is visible in this tile
    if (!is_particle_visible_in_tile(world_particle_pos, tile_params.world_bounds)) {
        // Return a position that will be clipped
        VertexOutput output;
        output.position = float4(0.0, 0.0, -1.0, 1.0);
        output.species = particle.species;
        output.velocity_magnitude = 0.0;
        output.world_pos = world_particle_pos;
        output.tile_fade_factor = 0.0;
        output.uv = quad_uv;
        return output;
    }
    
    // Map world position to tile NDC space [-1, 1]
    let world_left = tile_params.world_bounds.x;
    let world_bottom = tile_params.world_bounds.y;
    let world_right = tile_params.world_bounds.z;
    let world_top = tile_params.world_bounds.w;
    
    let tile_ndc_x = (world_particle_pos.x - world_left) / (world_right - world_left) * 2.0 - 1.0;
    let tile_ndc_y = (world_particle_pos.y - world_bottom) / (world_top - world_bottom) * 2.0 - 1.0;
    let particle_ndc_pos = float2(tile_ndc_x, tile_ndc_y);
    
    // Calculate LOD-aware particle size
    let lod_factor = calculate_lod_factor(tile_params.camera_zoom);
    let base_particle_size = sim_params.particle_size;
    let lod_particle_size = base_particle_size * lod_factor;
    
    // Scale particle size from world units to tile NDC units
    let world_width = world_right - world_left;
    let world_height = world_top - world_bottom;
    let world_scale = min(world_width, world_height) / 2.0;
    let particle_ndc_size = lod_particle_size / world_scale * 0.001;
    
    // Apply aspect ratio correction
    let aspect_ratio = camera_aware_params.viewport_size.x / camera_aware_params.viewport_size.y;
    let aspect_corrected_quad = float2(quad_pos.x / aspect_ratio, quad_pos.y);
    let quad_offset = aspect_corrected_quad * particle_ndc_size;
    let final_pos = particle_ndc_pos + quad_offset;
    
    // Calculate tile fade factor
    let tile_center = float2(
        float(tile_params.tile_x) * tile_size.x,
        float(tile_params.tile_y) * tile_size.y
    );
    let tile_fade_factor = calculate_tile_fade_factor(tile_center, camera_aware_params.camera_position, tile_params.camera_zoom);
    
    VertexOutput output;
    output.position = float4(final_pos, 0.0, 1.0);
    output.species = particle.species;
    output.velocity_magnitude = length(particle.velocity);
    output.world_pos = world_particle_pos;
    output.tile_fade_factor = tile_fade_factor;
    output.uv = quad_uv;
    
    return output;
}

// Convert linear RGB to sRGB for proper display
float linear_to_srgb(float linear) {
    if (linear <= 0.0031308) {
        return linear * 12.92;
    } else {
        return 1.055 * pow(linear, 1.0 / 2.4) - 0.055;
    }
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0 {
    // Create circular particles with sharp edges
    let center = float2(0.5, 0.5);
    let dist_from_center = distance(input.uv, center);
    
    // Define particle radius - use sharp cutoff for crisp edges
    let particle_radius = 0.45;
    
    // Discard pixels outside the particle radius for circular particles
    if (dist_from_center > particle_radius) {
        discard;
    }
    
    // Get the color for this particle's species
    let species_index = input.species;
    var base_color = species_colors.colors[species_index].rgb;
    if (color_mode.mode == 0) {
        base_color = float3(0.18, 0.18, 0.18);
    } else if (color_mode.mode == 1) {
        base_color = float3(1.0, 1.0, 1.0);
    } else if (color_mode.mode == 2) {
        base_color = float3(0.0, 0.0, 0.0);
    }
    
    // Apply tile fade factor
    if (input.tile_fade_factor <= 0.0) {
        discard;
    }
    
    // Apply tile fade factor for smooth transitions
    var final_color = base_color * input.tile_fade_factor;
    
    return float4(final_color, input.tile_fade_factor);
} 
