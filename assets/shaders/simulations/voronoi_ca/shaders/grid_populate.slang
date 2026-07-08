// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/voronoi_ca/shaders/grid_populate.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Populate spatial grid for Voronoi CA site positions

struct Vertex {

  float2 position;
  float state;
  float pad0;
  float age;
  uint alive_neighbors;
  uint dead_neighbors;
  uint pad1;
};

struct GridParams {

  uint particle_count;
  uint grid_width;
  uint grid_height;
  uint cell_capacity;
  float cell_size;
  float _pad1;
  float _pad2;
  float _pad3;
};

[[vk::binding(0, 0)]]
StructuredBuffer<Vertex> vertices;
// A flattened [grid_width*grid_height * cell_capacity] array of indices
[[vk::binding(1, 0)]]
RWStructuredBuffer<uint> grid_indices;
// Per-cell atomic counters
[[vk::binding(2, 0)]]
RWStructuredBuffer<uint> grid_counts;
[[vk::binding(3, 0)]]
ConstantBuffer<GridParams> params;

uint grid_flat_index(uint cell_x, uint cell_y) {
  return cell_y * params.grid_width + cell_x;
}

[shader("compute")]
[numthreads(128, 1, 1)]
void main(uint3 gid : SV_DispatchThreadID) {
  let i = gid.x;
  if (i < params.particle_count) {
    let p = vertices[i].position;
    // Convert pixel coords to grid cell
    uint gx = clamp(uint(p.x / params.cell_size), 0, max(1, params.grid_width) - 1);
    uint gy = clamp(uint(p.y / params.cell_size), 0, max(1, params.grid_height) - 1);
    uint cell = grid_flat_index(gx, gy);
    // Reserve a slot
    uint slot;
    InterlockedAdd(grid_counts[cell], 1, slot);
    let base = cell * params.cell_capacity;
    if (slot < params.cell_capacity) {
      grid_indices[base + slot] = i;
    }
  }
}
