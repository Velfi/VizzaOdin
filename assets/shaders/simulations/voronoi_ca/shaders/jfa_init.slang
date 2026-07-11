// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/voronoi_ca/shaders/jfa_init.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Voronoi initialization shader.

struct Vertex {

  float2 position;
  float color;
  float pad0;
  float phase;
  uint seed;
  uint pad1;
  uint random_state;
};

struct VoronoiParams {

  float count;
  float color_mode;
  float border_enabled;
  float border_width;
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
[numthreads(128, 1, 1)]
void main(uint3 gid : SV_DispatchThreadID) {
  uint i = gid.x;
  if (i >= uint(params.count)) return;
  Vertex v = vertices[i];
  int2 dims = int2(int(params.resolution_x), int(params.resolution_y));
  int2 coord = int2(v.position) % dims;
  // The image is cleared to an infinite-distance sentinel before this dispatch.
  // Site collisions at identical pixels are harmless: either site is a valid seed.
  StoreTexture(voronoi_texture, coord, float4(v.position, float(i), 0.0));
}
