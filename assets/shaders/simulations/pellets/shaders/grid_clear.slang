// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/pellets/shaders/grid_clear.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Clear the spatial partitioning grid

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

struct GridCell {

    uint particle_count;
    uint[64] particle_indices;
};

[[vk::binding(0, 0)]]
RWStructuredBuffer<GridCell> grid;
[[vk::binding(1, 0)]]
ConstantBuffer<GridParams> params;
// Atomic per-cell particle counts used for concurrent population
[[vk::binding(2, 0)]]
RWStructuredBuffer<uint> grid_counts;

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    let total_cells = params.grid_width * params.grid_height;
    if (index < total_cells) {
        // Clear the grid cell
        grid[index].particle_count = 0;
        
        // Clear particle indices array
        for (var i = 0; i < 64; i++) {
            grid[index].particle_indices[i] = 0;
        }

        // Reset cell count
        grid_counts[index] = 0;
    }
}
