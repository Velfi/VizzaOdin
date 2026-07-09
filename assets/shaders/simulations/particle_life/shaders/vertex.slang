// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/particle_life/shaders/vertex.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Particle Life vertex shader - Instanced Quads for Sizable Points

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
    float particle_size; // Add particle size parameter
    float aspect_ratio; // Screen aspect ratio for cursor distance calculation
    uint _pad1;
};

struct CameraUniform {

    float4x4 transform_matrix;
    float2 position;
    float zoom;
    float aspect_ratio;
};

struct ViewportParams {

    float4 world_bounds; // [left, bottom, right, top] in world coordinates
    float2 texture_size; // [width, height] of offscreen texture
    float _pad1;
    float _pad2;
};

struct ViewportPush {

    float4 world_bounds;
    uint enabled;
    uint _pad0;
    uint _pad1;
    uint _pad2;
};

struct VertexOutput {

    float4 position : SV_Position;
    uint species : TEXCOORD0;
    float velocity_magnitude : TEXCOORD1;
    float2 world_pos : TEXCOORD2;
    float grid_fade_factor : TEXCOORD3;
    float2 uv : TEXCOORD4;
};

[[vk::binding(0, 0)]]
StructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
ConstantBuffer<SimParams> sim_params;
[[vk::binding(0, 2)]]
ConstantBuffer<CameraUniform> camera;
[[vk::binding(1, 2)]]
ConstantBuffer<ViewportParams> viewport_params;
[[vk::push_constant]]
ConstantBuffer<ViewportPush> viewport_push;

// Instanced quad vertex shader for sizable particles
[shader("vertex")]
VertexOutput main(
    uint vertex_index : SV_VertexID,
    uint instance_index : SV_InstanceID,
) {
    // Create a quad for each particle (6 vertices = 2 triangles)
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
    
    // Map particles from world space to the texture's world bounds
    let world_particle_pos = particle.position;
    
    // Get the world bounds that this texture represents
    let world_bounds = viewport_push.enabled != 0 ? viewport_push.world_bounds : viewport_params.world_bounds;
    let world_left = world_bounds.x;
    let world_bottom = world_bounds.y;
    let world_right = world_bounds.z;
    let world_top = world_bounds.w;
    
    // Map world position to texture NDC space [-1, 1]
    let texture_ndc_x = (world_particle_pos.x - world_left) / (world_right - world_left) * 2.0 - 1.0;
    let texture_ndc_y = (world_particle_pos.y - world_bottom) / (world_top - world_bottom) * 2.0 - 1.0;
    let particle_ndc_pos = float2(texture_ndc_x, texture_ndc_y);
    
    // Scale particle size from world units to NDC units
    let world_width = world_right - world_left;
    let world_height = world_top - world_bottom;
    let world_scale = min(world_width, world_height) / 2.0; // Scale factor from world to NDC
    let particle_ndc_size = sim_params.particle_size / world_scale * 0.001; // Make particles 0.001 of current size
    
    // Apply aspect ratio correction
    let aspect_corrected_quad = float2(quad_pos.x / camera.aspect_ratio, quad_pos.y);
    let quad_offset = aspect_corrected_quad * particle_ndc_size;
    let final_pos = particle_ndc_pos + quad_offset;
    
    VertexOutput output;
    output.position = float4(final_pos.x, -final_pos.y, 0.0, 1.0);  // Vulkan's positive viewport maps NDC +Y downward.
    output.species = particle.species;
    output.velocity_magnitude = length(particle.velocity);
    output.world_pos = world_particle_pos;  // Pass world position for post-processing
    output.grid_fade_factor = 1.0;
    output.uv = quad_uv;
    
    return output;
}
