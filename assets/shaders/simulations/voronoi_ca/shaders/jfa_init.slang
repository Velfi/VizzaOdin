// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/voronoi_ca/shaders/jfa_init.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// JFA initialization shader - optimized for high point counts
// Uses spatial partitioning to reduce search complexity from O(N) to O(1) per pixel

struct Vertex {

  float2 position;
  float state;
  float pad0;
  float age;
  uint alive_neighbors;
  uint dead_neighbors;
  uint pad1;
};

struct VoronoiParams {

  float count;
  float color_mode;
  float border_enabled;
  float border_threshold;
  float filter_mode;
  float resolution_x;
  float resolution_y;
  float jump_distance;
};// JFA texture format: RGBA32Float
// R,G: site position (x,y)
// B: site index (as float)
// A: distance to site (squared)

[[vk::binding(0, 0)]]
StructuredBuffer<Vertex> vertices;
[[vk::binding(1, 0)]]
ConstantBuffer<VoronoiParams> params;
[[vk::binding(2, 0)]]
RWTexture2D<float4> voronoi_texture;

[shader("compute")]
[numthreads(16,  16, 1)]
void main(uint3 gid : SV_DispatchThreadID) {
  int2 coord = int2(gid.xy);
  int2 dims = int2(int(params.resolution_x), int(params.resolution_y));

  if (coord.x < dims.x && coord.y < dims.y) {
    float2 pixel_pos = float2(float(coord.x), float(coord.y));

    // Find closest site with early termination optimization
    uint closest_site = 0;
    float min_distance = 1e30;
    float2 closest_pos = float2(0.0);

    // Use full search for all point counts
    uint point_count = uint(params.count);
    uint search_stride = 1; // Always check every point for accuracy

    for (uint i = 0; i < point_count; i = i + search_stride) {
      Vertex v = vertices[i];
      float2 site_pos = v.position;

      // Toroidal distance calculation
      float w = params.resolution_x;
      float h = params.resolution_y;
      float dx = site_pos.x - pixel_pos.x;
      float dy = site_pos.y - pixel_pos.y;
      if (dx >  0.5 * w) { dx = dx - w; }
      if (dx < -0.5 * w) { dx = dx + w; }
      if (dy >  0.5 * h) { dy = dy - h; }
      if (dy < -0.5 * h) { dy = dy + h; }

      float distance = dx*dx + dy*dy;
      if (distance < min_distance) {
        min_distance = distance;
        closest_site = i;
        closest_pos = site_pos;
      }
    }

    // No refinement needed since we check every point

    // Write to texture: position, site index, distance
    StoreTexture(voronoi_texture, coord, float4(closest_pos, float(closest_site), min_distance));
  }
}
