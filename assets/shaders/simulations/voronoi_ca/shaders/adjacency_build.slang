// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/voronoi_ca/shaders/adjacency_build.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
float4 LoadTexture(Texture2D<float4> tex, int2 p, uint lod) { return tex.Load(int3(p, int(lod))); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Build per-site Voronoi adjacency by casting rays from each site into the JFA texture.
// Each invocation handles one site; deduplicates neighbors locally and writes a capped list.

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

[[vk::binding(0, 0)]]
StructuredBuffer<Vertex> vertices;
[[vk::binding(1, 0)]]
ConstantBuffer<Uniforms> uniforms;
[[vk::binding(2, 0)]]
RWStructuredBuffer<uint> neighbors;
[[vk::binding(3, 0)]]
RWStructuredBuffer<uint> degrees;
[[vk::binding(4, 0)]]
Texture2D<float4> jfa_texture;

static const uint MAX_NEIGHBORS = 16;

void write_neighbor(uint site_index, uint slot, uint neighbor_id) {
  uint base = site_index * MAX_NEIGHBORS;
  neighbors[base + slot] = neighbor_id;
}

uint get_site_index_at_pixel(int2 px) {
  float4 texel = LoadTexture(jfa_texture, px, 0);
  return uint(texel.b);
}

[shader("compute")]
[numthreads(128, 1, 1)]
void main(uint3 gid : SV_DispatchThreadID) {
  let i = gid.x;
  uint count = 0;
  uint stride = 0;
  vertices.GetDimensions(count, stride);
  if (i < count) {
    let res = int2(int(uniforms.resolution.x), int(uniforms.resolution.y));
    let pos = vertices[i].position;

  // Convert to pixel coords and clamp inside texture
  int2 pixel = int2(clamp(int2(float2(pos)), int2(0), res - int2(1)));
  // Ensure starting site matches i; if not, locate nearest pixel for this site by probing a tiny area
  uint center_site = get_site_index_at_pixel(pixel);
  if (center_site != i) {
    // Probe small 3x3 neighborhood to find a pixel owned by this site
    bool found = false;
    for (int dy = -1; dy <= 1 && !found; dy = dy + 1) {
      for (int dx = -1; dx <= 1 && !found; dx = dx + 1) {
        int2 q = pixel + int2(dx, dy);
        int2 wrapped = int2((q.x + res.x) % res.x, (q.y + res.y) % res.y);
        uint s = get_site_index_at_pixel(wrapped);
        if (s == i) {
          pixel = wrapped;
          center_site = s;
          found = true;
        }
      }
    }
  }

  // Local dedup buffer
  uint[32] local_n;
  uint local_len = 0;
  for (uint init_m = 0; init_m < MAX_NEIGHBORS; init_m = init_m + 1) {
    local_n[init_m] = 0;
  }

  int sample_count = 24;
  int max_steps = 1024;
  float step_size = 2.0; // pixels per step
  float two_pi = 6.2831853;

  for (uint k = 0; k < uint(sample_count); k = k + 1) {
    float angle = float(k) * (two_pi / float(sample_count));
    float2 dir = float2(cos(angle), sin(angle));

    float t = step_size;
    uint neighbor_id = center_site;
    bool hit = false;
    int step = 0;
    while (true) {
      if (step >= max_steps) { break; }
      step = step + 1;
      float2 p = float2(pos + dir * t);
      int2 q = int2(
        (int(floor(p.x)) % res.x + res.x) % res.x,
        (int(floor(p.y)) % res.y + res.y) % res.y
      );
      uint s = get_site_index_at_pixel(q);
      if (s != center_site) { neighbor_id = s; hit = true; break; }
      t = t + step_size;
    }

    if (hit) {
      // Dedup locally
      bool exists = false;
      for (uint m = 0; m < local_len; m = m + 1) {
        if (local_n[m] == neighbor_id) { exists = true; break; }
      }
      if (!exists && local_len < MAX_NEIGHBORS) {
        local_n[local_len] = neighbor_id;
        local_len = local_len + 1;
      }
    }
  }

  // Write out degree and neighbor list (pad unspecified entries)
    degrees[i] = local_len;
    for (uint m = 0; m < local_len; m = m + 1) {
      write_neighbor(i, m, local_n[m]);
    }
  }
}
