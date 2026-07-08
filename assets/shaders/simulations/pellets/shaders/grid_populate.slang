// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/pellets/shaders/grid_populate.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Spatial partitioning grid population shader
// Creates a uniform grid for efficient neighbor lookups

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

struct GridParams {

    uint particle_count;
    uint grid_width;
    uint grid_height;
    float cell_size;
    float world_width; // 2.0 for [-1,1] space
    float world_height; // 2.0 for [-1,1] space
    uint _pad1;
    uint _pad2;
};// Grid cell structure - each cell stores particle indices
struct GridCell {

    uint particle_count;
    uint[64] particle_indices; // Max 64 particles per cell
};

[[vk::binding(0, 0)]]
StructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
RWStructuredBuffer<GridCell> grid;
[[vk::binding(2, 0)]]
ConstantBuffer<GridParams> params;
// Atomic per-cell particle counts for safe concurrent insertion
[[vk::binding(3, 0)]]
RWStructuredBuffer<uint> grid_counts;

// Convert world position to grid coordinates
uint2 world_to_grid(float2 pos) {
    // Convert from [-1,1] to [0,1] then to grid coordinates
    let normalized_pos = (pos + float2(1.0, 1.0)) * 0.5;
    let grid_x = uint(normalized_pos.x * float(params.grid_width));
    let grid_y = uint(normalized_pos.y * float(params.grid_height));
    
    // Clamp to grid bounds
    return uint2(
        min(grid_x, params.grid_width - 1),
        min(grid_y, params.grid_height - 1)
    );
}

// Get grid cell index from coordinates
uint grid_coord_to_index(uint2 coord) {
    return coord.y * params.grid_width + coord.x;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    if (index < params.particle_count) {
        let particle = particles[index];

        // Skip grabbed particles (they don't need physics)
        if (particle.grabbed != 0) {
            return;
        }

        // Convert particle position to grid coordinates
        let grid_coord = world_to_grid(particle.position);
        let cell_index = grid_coord_to_index(grid_coord);

        // Concurrently add particle to grid cell using atomic counter
        uint slot;
        InterlockedAdd(grid_counts[cell_index], 1, slot);
        if (slot < 64) {
            // Write the index directly to the slot to avoid racy struct writebacks
            grid[cell_index].particle_indices[slot] = index;
        }
    }
}
