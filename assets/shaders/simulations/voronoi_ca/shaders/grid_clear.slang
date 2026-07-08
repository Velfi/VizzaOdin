// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/voronoi_ca/shaders/grid_clear.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Clear spatial grid counts for Voronoi CA

struct GridParams {

  uint particle_count;
  uint grid_width;
  uint grid_height;
  uint cell_capacity;
  float cell_size;
  float _pad1;
  float _pad2;
  float _pad3;
};// Atomic per-cell counts used for concurrent population
[[vk::binding(0, 0)]]
RWStructuredBuffer<uint> grid_counts;
[[vk::binding(1, 0)]]
ConstantBuffer<GridParams> params;

[shader("compute")]
[numthreads(128, 1, 1)]
void main(uint3 gid : SV_DispatchThreadID) {
  let index = gid.x;
  let total_cells = params.grid_width * params.grid_height;
  if (index < total_cells) {
    grid_counts[index] = 0;
  }
}

