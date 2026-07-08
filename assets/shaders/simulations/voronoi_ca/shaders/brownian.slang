// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/voronoi_ca/shaders/brownian.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Brownian motion compute shader
// Bindings:
//  @binding(0) storage buffer (vertices) - read/write
//  @binding(1) uniform (uniforms)
//  @binding(2) uniform (brownian_params)

struct Vertex {

  float2 position;
  float state;
  float pad0;
  float age;
  uint alive_neighbors;
  uint dead_neighbors;
  uint random_state;
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

struct BrownianParams {

  float speed;
  float delta_time;
};

[[vk::binding(0, 0)]]
RWStructuredBuffer<Vertex> vertices;
[[vk::binding(1, 0)]]
ConstantBuffer<Uniforms> uniforms;
[[vk::binding(2, 0)]]
ConstantBuffer<BrownianParams> params;

// Improved pseudo-random number generator (Linear Congruential Generator)
float lcg_random(inout uint state) {
  uint x = state;
  x = x * 1664525 + 1013904223; // LCG constants
  state = x;
  return float(x) / 4294967296.0; // Convert to [0,1)
}

// Generate multiple random values using LCG
float2 random_vec2(inout uint state) {
  return float2(lcg_random(state), lcg_random(state));
}

[shader("compute")]
[numthreads(128, 1, 1)]
void main(uint3 gid : SV_DispatchThreadID) {
  let i = gid.x;
  uint count = 0;
  uint stride = 0;
  vertices.GetDimensions(count, stride);
  if (i < count) {
    float dt = params.delta_time;
    float speed = params.speed * uniforms.drift;
    float min_x = 0.0;
    float min_y = 0.0;
    float size_x = uniforms.resolution.x;
    float size_y = uniforms.resolution.y;

    // Use per-point random state for independent brownian motion
    uint random_state = vertices[i].random_state;
    
    // Mix in time and position for additional variation
    random_state = random_state ^ uint(uniforms.time * 1000.0);
    random_state = random_state ^ uint(vertices[i].position.x * 1000.0);
    random_state = random_state ^ uint(vertices[i].position.y * 1000.0);

    // Generate random displacement for brownian motion
    float2 random_displacement = random_vec2(random_state);
    
    // Update the random state for next frame
    vertices[i].random_state = random_state;
    float dx = (random_displacement.x - 0.5) * 2.0 * speed * dt; // [-1, 1] * speed * dt
    float dy = (random_displacement.y - 0.5) * 2.0 * speed * dt; // [-1, 1] * speed * dt

    float new_x = vertices[i].position.x + dx;
    float new_y = vertices[i].position.y + dy;
    
    // Toroidal wrapping
    new_x = fmod(new_x - min_x, size_x) + min_x;
    new_y = fmod(new_y - min_y, size_y) + min_y;
    
    vertices[i].position = float2(new_x, new_y);
  }
}
