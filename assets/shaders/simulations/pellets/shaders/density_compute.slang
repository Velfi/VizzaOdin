// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/pellets/shaders/density_compute.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// GPU-based density calculation for particle coloring

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

struct DensityParams {

    uint particle_count;
    float density_radius;
    uint coloring_mode; // 0 = density, 1 = velocity, 2 = random
    uint _padding;
};

[[vk::binding(0, 0)]]
RWStructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
ConstantBuffer<DensityParams> params;
// Optional: if grid is available, we could switch to neighbor-based density later

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    if (index >= params.particle_count) {
        return;
    }

    var particle = particles[index];
    
    if (params.coloring_mode == 0) {
        // Density mode
        particle.density = compute_density(particle, index);
    } else if (params.coloring_mode == 1) {
        // Velocity mode
        particle.density = length(particle.velocity) * 4.0; // Velocity-based coloring
    } else {
        // Random mode - use particle index to generate consistent random value
        let seed = float(index) * 0.1234;
        particle.density = frac(sin(seed) * 43758.5453) * 255.0; // Random value 0-255
    }
    
    particles[index] = particle;
}

float compute_density(Particle particle, uint particle_index) {
    var density = 0.0;
    let density_radius_sq = params.density_radius * params.density_radius;
    
    for (var i = 0; i < params.particle_count; i++) {
        if (i == particle_index) {
            continue;
        }
        
        let other = particles[i];
        var delta = particle.position - other.position;
        
        // Toroidal wrapping
        if (abs(delta.x) > 1.0) {
            delta.x = delta.x - sign(delta.x) * 2.0;
        }
        if (abs(delta.y) > 1.0) {
            delta.y = delta.y - sign(delta.y) * 2.0;
        }
        
        let distance_sq = dot(delta, delta);
        
        if (distance_sq < density_radius_sq) {
            density += 1.0 / (1.0 + distance_sq);
        }
    }
    
    return density;
} 
