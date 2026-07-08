// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/voronoi_ca/shaders/adjacency_count.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Count alive neighbors using the prebuilt Voronoi adjacency (graph neighbors per site)

struct Vertex {

  float2 position;
  float state;
  float pad0;
  float age;
  uint alive_neighbors;
  uint dead_neighbors;
  uint pad1;
};

struct Uniforms {

  float2 resolution;
  float time;
  float drift;
  uint rule_type;
  uint _pad0;
  uint _pad1;
  uint _pad2;
};

static const uint MAX_NEIGHBORS = 16;

[[vk::binding(0, 0)]]
RWStructuredBuffer<Vertex> vertices;
[[vk::binding(1, 0)]]
ConstantBuffer<Uniforms> uniforms;
[[vk::binding(2, 0)]]
StructuredBuffer<uint> neighbors;
[[vk::binding(3, 0)]]
StructuredBuffer<uint> degrees;

[shader("compute")]
[numthreads(128, 1, 1)]
void main(uint3 gid : SV_DispatchThreadID) {
  uint i = gid.x;
  uint count = 0;
  uint stride = 0;
  vertices.GetDimensions(count, stride);
  if (i < count) {

    Vertex v = vertices[i];

    uint deg = degrees[i];
    uint base = i * MAX_NEIGHBORS;

    uint alive_n = 0;
    uint dead_n = 0;
    for (uint k = 0; k < deg && k < MAX_NEIGHBORS; k = k + 1) {
      uint j = neighbors[base + k];
      Vertex u = vertices[j];
      if (u.state >= 0.5) { alive_n = alive_n + 1; }
      else { dead_n = dead_n + 1; }
    }

    v.alive_neighbors = alive_n;
    v.dead_neighbors = dead_n;
    vertices[i] = v;
  }
}
