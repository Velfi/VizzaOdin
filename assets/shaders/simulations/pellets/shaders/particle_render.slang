// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/pellets/shaders/particle_render.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

struct Particle {

    float2 position;
    float2 velocity;
    float mass;
    float radius;
    uint clump_id;
    float density;
    uint grabbed;
    uint _pad0;
    float2 previous_position;
};

struct RenderParams {

    float particle_size;
    float screen_width;
    float screen_height;
    uint foreground_color_mode; // 0 = density, 1 = velocity, 2 = random
    float2 camera_position;
    float camera_zoom;
    uint tile_count;
};

struct VertexOutput {

    float4 position : SV_Position;
    nointerpolation float3 color : TEXCOORD0;
    nointerpolation float mass : TEXCOORD1;
    nointerpolation float density : TEXCOORD2;
    float2 uv : TEXCOORD3;
    nointerpolation uint foreground_color_mode : TEXCOORD4;
};

[[vk::binding(0, 0)]]
StructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
ConstantBuffer<RenderParams> params;
[[vk::binding(2, 0)]]
StructuredBuffer<uint> lut;

// Convert from sRGB (gamma-corrected) to linear RGB
float srgb_to_linear(float srgb) {
    if (srgb <= 0.04045) {
        return srgb / 12.92;
    } else {
        return pow((srgb + 0.055) / 1.055, 2.4);
    }
}

float3 get_lut_color(uint index) {
    let r_srgb = float(lut[index]) / 255.0;
    let g_srgb = float(lut[index + 256]) / 255.0;
    let b_srgb = float(lut[index + 512]) / 255.0;
    return float3(
        srgb_to_linear(r_srgb),
        srgb_to_linear(g_srgb),
        srgb_to_linear(b_srgb)
    );
}

float3 get_particle_color(Particle particle) {
    // Color based on mass and clump id
    // Scale mass (expected ~0.1-0.3) into 0-1 range for LUT selection
    let mass_factor = clamp(particle.mass * 3.33, 0.0, 1.0);
    let clump_factor = clamp(float(particle.clump_id) / 5.0, 0.0, 1.0);
    
    // Use LUT based on mass (smaller particles = blue, larger = red)
    let mass_index = uint(mass_factor * 255.0);
    let base_color = get_lut_color(mass_index);
    
    // Add brightness for clumped particles
    let clumped_brightness = float3(1.0, 1.0, 1.0) * clump_factor * 0.3;
    return base_color + clumped_brightness;
}

[shader("vertex")]
VertexOutput vs_main(
    uint vertex_index : SV_VertexID,
    uint instance_index : SV_InstanceID,
) {
    let tiles = max(params.tile_count, 1u);
    let tiles_per_world = tiles * tiles;
    let particle_index = instance_index / tiles_per_world;
    let tile_index = instance_index % tiles_per_world;
    let vertex_id = vertex_index; // 0-5 within the quad
    
    let particle = particles[particle_index];

    // Create a quad for each particle
    let positions = float2[6](
        float2(-1.0, -1.0), float2(1.0, -1.0), float2(-1.0, 1.0),
        float2(-1.0, 1.0), float2(1.0, -1.0), float2(1.0, 1.0)
    );
    
    let uvs = float2[6](
        float2(0.0, 0.0), float2(1.0, 0.0), float2(0.0, 1.0),
        float2(0.0, 1.0), float2(1.0, 0.0), float2(1.0, 1.0)
    );
    
    let pos = positions[vertex_id];
    let uv = uvs[vertex_id];
    
    // Use the pre-calculated particle size that matches collision detection exactly
    let size = params.particle_size; // Already calculated on backend to match collision size
    
    let tile_center = int2(round(params.camera_position / 2.0));
    let tile_start = tile_center - int2(int(tiles / 2u));
    let tile = tile_start + int2(int(tile_index % tiles), int(tile_index / tiles));
    let world_pos = particle.position + float2(tile) * 2.0 + pos * size;
    
    // Convert to clip coordinates using camera transformation
    let clip_pos = float4((world_pos - params.camera_position) * params.camera_zoom, 0.0, 1.0);
    let transformed_pos = clip_pos;
    
    // Color based on mass and merged count
    let color = get_particle_color(particle);
    
    return VertexOutput(
        transformed_pos,
        color,
        particle.mass,
        particle.density,
        uv,
        params.foreground_color_mode
    );
}

[shader("fragment")]
float4 fs_main(
    nointerpolation float3 color : TEXCOORD0,
    nointerpolation float mass : TEXCOORD1,
    nointerpolation float density : TEXCOORD2,
    float2 uv : TEXCOORD3,
    nointerpolation uint foreground_color_mode : TEXCOORD4,
) : SV_Target0 {
    // Create circular particles with aspect ratio correction
    let center = float2(0.5, 0.5);
    let aspect_ratio = params.screen_width / params.screen_height;

    // Correct UV coordinates for aspect ratio to ensure circular particles
    var corrected_uv = uv - center;
    corrected_uv.x *= aspect_ratio;
    let dist = length(corrected_uv);

    // Standard particle rendering with hard edges
    let particle_radius = 0.45;

    if (dist > particle_radius) {
        discard;
    }

    float3 final_color;

    if (foreground_color_mode == 2) {
        // Random mode
        let color_factor = clamp(density / 255.0, 0.0, 1.0);
        let lut_index = uint(color_factor * 255.0);
        let color = get_lut_color(lut_index);
        
        // Add mass-based glow effect for larger particles
        let mass_factor = clamp(mass / 20.0, 0.0, 1.0);
        let glow_intensity = mass_factor * 0.3;
        let glow_color = float3(1.0, 0.9, 0.7) * glow_intensity;

        final_color = color + glow_color;
    } else if (foreground_color_mode == 1) {
        // Velocity mode
        let color_factor = clamp(density / 4.0, 0.0, 1.0);
        let lut_index = uint(color_factor * 255.0);
        let color = get_lut_color(lut_index);

        // Add mass-based glow effect for larger particles
        let mass_factor = clamp(mass / 20.0, 0.0, 1.0);
        let glow_intensity = mass_factor * 0.3;
        let glow_color = float3(1.0, 0.9, 0.7) * glow_intensity;

        final_color = color + glow_color;
    } else {
        // Density mode
        let color_factor = clamp(density / 16.0, 0.0, 1.0);
        let lut_index = uint(color_factor * 255.0);
        let color = get_lut_color(lut_index);

        // Add mass-based glow effect for larger particles
        let mass_factor = clamp(mass / 20.0, 0.0, 1.0);
        let glow_intensity = mass_factor * 0.3;
        let glow_color = float3(1.0, 0.9, 0.7) * glow_intensity;

        final_color = color + glow_color;
    }

    return float4(final_color, 1.0);
}
