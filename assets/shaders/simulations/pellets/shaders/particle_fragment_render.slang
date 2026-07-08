// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/pellets/shaders/particle_fragment_render.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

struct FragmentInput {

    nointerpolation float3 color : TEXCOORD0;
    nointerpolation float mass : TEXCOORD1;
    nointerpolation float density : TEXCOORD2;
    float2 uv : TEXCOORD3;
    nointerpolation uint foreground_color_mode : TEXCOORD4;
};

struct RenderParams {

    float particle_size;
    float screen_width;
    float screen_height;
    uint foreground_color_mode; // 0 = density, 1 = velocity, 2 = random
};

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

[shader("fragment")]
float4 fs_main(FragmentInput in) : SV_Target0 {
    // Create circular particles with aspect ratio correction
    let center = float2(0.5, 0.5);
    let aspect_ratio = params.screen_width / params.screen_height;
    
    // Correct UV coordinates for aspect ratio to ensure circular particles
    var corrected_uv = in.uv - center;
    corrected_uv.x *= aspect_ratio;
    let dist = length(corrected_uv);
    
    // Standard particle rendering with hard edges
    let particle_radius = 0.45;
    
    if (dist > particle_radius) {
        discard;
    }
    
    float3 final_color;
    
    if (in.foreground_color_mode == 2) {
        // Random mode
        let color_factor = clamp(in.density / 255.0, 0.0, 1.0);
        let lut_index = uint(color_factor * 255.0);
        let color = get_lut_color(lut_index);
        
        // Add mass-based glow effect for larger particles
        let mass_factor = clamp(in.mass / 20.0, 0.0, 1.0);
        let glow_intensity = mass_factor * 0.3;
        let glow_color = float3(1.0, 0.9, 0.7) * glow_intensity;
        
        final_color = color + glow_color;
    } else if (in.foreground_color_mode == 1) {
        // Velocity mode
        let color_factor = clamp(in.density / 4.0, 0.0, 1.0);
        let lut_index = uint(color_factor * 255.0);
        let color = get_lut_color(lut_index);
        
        // Add mass-based glow effect for larger particles
        let mass_factor = clamp(in.mass / 20.0, 0.0, 1.0);
        let glow_intensity = mass_factor * 0.3;
        let glow_color = float3(1.0, 0.9, 0.7) * glow_intensity;
        
        final_color = color + glow_color;
    } else {
        // Density mode
        let color_factor = clamp(in.density / 16.0, 0.0, 1.0);
        let lut_index = uint(color_factor * 255.0);
        let color = get_lut_color(lut_index);
        
        // Add mass-based glow effect for larger particles
        let mass_factor = clamp(in.mass / 20.0, 0.0, 1.0);
        let glow_intensity = mass_factor * 0.3;
        let glow_color = float3(1.0, 0.9, 0.7) * glow_intensity;
        
        final_color = color + glow_color;
    }
    
    return float4(final_color, 1.0);
} 
