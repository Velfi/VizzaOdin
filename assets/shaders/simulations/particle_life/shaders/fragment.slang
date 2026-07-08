// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/particle_life/shaders/fragment.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Particle Life fragment shader - Instanced Quads for Sizable Points

struct VertexOutput {

    float4 position : SV_Position;
    uint species : TEXCOORD0;
    float velocity_magnitude : TEXCOORD1;
    float2 world_pos : TEXCOORD2;
    float grid_fade_factor : TEXCOORD3;
    float2 uv : TEXCOORD4;
};

struct SpeciesColors {

    float4[9] colors; // Allocate space for 9 colors (background + 8 species)
};

struct ColorMode {

    uint mode; // 0=Gray18, 1=White, 2=Black, 3=ColorScheme
    uint _pad1;
    uint _pad2;
    uint _pad3;
    float brightness;
    float contrast;
    float saturation;
    float gamma;
};

[[vk::binding(0, 1)]]
ConstantBuffer<SpeciesColors> species_colors;
[[vk::binding(1, 1)]]
ConstantBuffer<ColorMode> color_mode;

[shader("fragment")]
float4 main(VertexOutput input) : SV_Target0 {
    // Create circular particles with sharp edges
    // UV coordinates are in [0,1] range for each quad
    let center = float2(0.5, 0.5);
    let dist_from_center = distance(input.uv, center);
    
    // Define particle radius - use sharp cutoff for crisp edges
    let particle_radius = 0.45;
    
    // Discard pixels outside the particle radius for circular particles
    if (dist_from_center > particle_radius) {
        discard;
    }
    
    // Get the color for this particle's species directly from the uniform buffer
    let species_index = input.species;
    
    // Species colors are stored first in the buffer for all modes.
    // When using a LUT, the background color is appended at the end by the backend.
    let color_index = species_index;
    
    var base_color = species_colors.colors[color_index].rgb;
    if (color_mode.mode == 0) {
        base_color = float3(0.18, 0.18, 0.18);
    } else if (color_mode.mode == 1) {
        base_color = float3(1.0, 1.0, 1.0);
    } else if (color_mode.mode == 2) {
        base_color = float3(0.0, 0.0, 0.0);
    }
    
    // When completely faded (grid_fade_factor = 0), render a color based on the species
    // This gives a better representation of the simulation state than a fixed dark color
    if (input.grid_fade_factor <= 0.0) {
        // Use a dimmed version of the species color to represent the average
        // This creates a more dynamic fade that reflects the simulation content
        let dimmed_color = base_color * 0.15;
        let srgb_color = float3(
            dimmed_color.r,
            dimmed_color.g,
            dimmed_color.b
        );
        return float4(srgb_color, 1.0);
    }
    
    // Apply grid fade factor for infinite rendering
    // Use the grid fade factor to adjust the color intensity
    var final_color = base_color * input.grid_fade_factor;
    
    return float4(final_color, 1.0);
}
