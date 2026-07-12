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

struct GridParams {
    uint particle_count;
    uint grid_width;
    uint grid_height;
    float cell_size;
    float world_width;
    float world_height;
    uint _pad1;
    uint _pad2;
};

[[vk::binding(0, 0)]]
RWStructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
ConstantBuffer<DensityParams> params;
[[vk::binding(2, 0)]]
StructuredBuffer<uint> particle_indices;
[[vk::binding(3, 0)]]
ConstantBuffer<GridParams> grid_params;
[[vk::binding(4, 0)]]
StructuredBuffer<uint> grid_counts;
[[vk::binding(5, 0)]]
StructuredBuffer<uint> grid_offsets;

uint2 world_to_grid(float2 pos) {
    let normalized_pos = (pos + float2(1.0, 1.0)) * 0.5;
    return uint2(
        min(uint(normalized_pos.x * float(grid_params.grid_width)), grid_params.grid_width - 1),
        min(uint(normalized_pos.y * float(grid_params.grid_height)), grid_params.grid_height - 1)
    );
}

uint grid_coord_to_index(uint2 coord) {
    return coord.y * grid_params.grid_width + coord.x;
}

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

    // Density is normally smaller than a cell, but settings allow a larger
    // radius. Expand the cell window when needed so the optimized path remains
    // equivalent to the former all-pairs calculation.
    let center_cell = world_to_grid(particle.position);
    let cell_radius = max(int(ceil(params.density_radius / grid_params.cell_size)), 1);
    for (var dy = -cell_radius; dy <= cell_radius; dy++) {
        for (var dx = -cell_radius; dx <= cell_radius; dx++) {
            let cx = (int(center_cell.x) + dx + int(grid_params.grid_width)) % int(grid_params.grid_width);
            let cy = (int(center_cell.y) + dy + int(grid_params.grid_height)) % int(grid_params.grid_height);
            let cell_index = grid_coord_to_index(uint2(uint(cx), uint(cy)));
            let count = grid_counts[cell_index];
            let start = grid_offsets[cell_index];
            for (var k = 0; k < count; k++) {
                let i = particle_indices[start + k];
                if (i == particle_index) { continue; }

                let other = particles[i];
                var delta = particle.position - other.position;
                if (abs(delta.x) > 1.0) { delta.x -= sign(delta.x) * 2.0; }
                if (abs(delta.y) > 1.0) { delta.y -= sign(delta.y) * 2.0; }
                let distance_sq = dot(delta, delta);
                if (distance_sq < density_radius_sq) {
                    density += 1.0 / (1.0 + distance_sq);
                }
            }
        }
    }

    return density;
} 
