// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/voronoi_ca/shaders/compute_update.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Applies CA update using neighbor counts computed previously
// Reads and writes the same storage buffer, but only this pass mutates state/age
// Layout matches compute.wgsl: binding(0) = storage Vertices, binding(1) = Uniforms

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
RWStructuredBuffer<Vertex> vertices;
[[vk::binding(1, 0)]]
ConstantBuffer<Uniforms> uniforms;

 [shader("compute")]
 [numthreads(128, 1, 1)]
void main(uint3 gid : SV_DispatchThreadID) {
  let i = gid.x;
  uint count = 0;
  uint stride = 0;
  vertices.GetDimensions(count, stride);
  if (i < count) {
    Vertex v = vertices[i];

  // Life-like cellular automaton rules
  let alive_n = v.alive_neighbors;
  let is_alive = v.state >= 0.5;
  
  float next_state = 0.0;
  
  // Apply rules based on rule_type
  switch (uniforms.rule_type) {
    case 0: { // B1357/S1357 - Replicator
      if (is_alive) {
        next_state = ((alive_n == 1 || alive_n == 3 || alive_n == 5 || alive_n == 7) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 1 || alive_n == 3 || alive_n == 5 || alive_n == 7) ? (1.0) : (0.0));
      }
      break;
    }
    case 1: { // B2/S - Seeds
      if (!is_alive && alive_n == 2) {
        next_state = 1.0;
      } else if (is_alive) {
        next_state = 0.0; // No survival
      }
      break;
    }
    case 2: { // B25/S4 - Small self-replicating pattern
      if (is_alive) {
        next_state = ((alive_n == 4) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 2 || alive_n == 5) ? (1.0) : (0.0));
      }
      break;
    }
    case 3: { // B3/S012345678 - Life without Death
      if (is_alive) {
        next_state = 1.0; // Never die
      } else {
        next_state = ((alive_n == 3) ? (1.0) : (0.0));
      }
      break;
    }
    case 4: { // B3/S23 - Conway's Game of Life
      if (is_alive) {
        next_state = ((alive_n == 2 || alive_n == 3) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 3) ? (1.0) : (0.0));
      }
      break;
    }
    case 5: { // B3/S1234 - Maze
      if (is_alive) {
        next_state = ((alive_n >= 1 && alive_n <= 4) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 3) ? (1.0) : (0.0));
      }
      break;
    }
    case 6: { // B3/S12345 - Mazectric
      if (is_alive) {
        next_state = ((alive_n >= 1 && alive_n <= 5) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 3) ? (1.0) : (0.0));
      }
      break;
    }
    case 7: { // B34/S34 - 34 Life
      if (is_alive) {
        next_state = ((alive_n == 3 || alive_n == 4) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 3 || alive_n == 4) ? (1.0) : (0.0));
      }
      break;
    }
    case 8: { // B35678/S5678 - Diamoeba
      if (is_alive) {
        next_state = ((alive_n >= 5 && alive_n <= 8) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 3 || alive_n == 5 || alive_n == 6 || alive_n == 7 || alive_n == 8) ? (1.0) : (0.0));
      }
      break;
    }
    case 9: { // B36/S125 - 2x2
      if (is_alive) {
        next_state = ((alive_n == 1 || alive_n == 2 || alive_n == 5) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 3 || alive_n == 6) ? (1.0) : (0.0));
      }
      break;
    }
    case 10: { // B36/S23 - High Life
      if (is_alive) {
        next_state = ((alive_n == 2 || alive_n == 3) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 3 || alive_n == 6) ? (1.0) : (0.0));
      }
      break;
    }
    case 11: { // B368/S245 - Day & Night
      if (is_alive) {
        next_state = ((alive_n == 2 || alive_n == 4 || alive_n == 5) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 3 || alive_n == 6 || alive_n == 8) ? (1.0) : (0.0));
      }
      break;
    }
    case 12: { // B4678/S35678 - Anneal
      if (is_alive) {
        next_state = ((alive_n >= 3 && alive_n <= 8) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n >= 4 && alive_n <= 8) ? (1.0) : (0.0));
      }
      break;
    }
    case 13: { // B5678/S45678 - Vote
      if (is_alive) {
        next_state = ((alive_n >= 4 && alive_n <= 8) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n >= 5 && alive_n <= 8) ? (1.0) : (0.0));
      }
      break;
    }
    case 14: { // B6/S16 - Coral
      if (is_alive) {
        next_state = ((alive_n == 1 || alive_n == 6) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 6) ? (1.0) : (0.0));
      }
      break;
    }
    case 15: { // B6/S1 - Long Life
      if (is_alive) {
        next_state = ((alive_n == 1) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 6) ? (1.0) : (0.0));
      }
      break;
    }
    case 16: { // B6/S12 - Stains
      if (is_alive) {
        next_state = ((alive_n == 1 || alive_n == 2) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 6) ? (1.0) : (0.0));
      }
      break;
    }
    case 17: { // B6/S123 - Assimilation
      if (is_alive) {
        next_state = ((alive_n >= 1 && alive_n <= 3) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 6) ? (1.0) : (0.0));
      }
      break;
    }
    case 18: { // B6/S15 - Pseudo Life
      if (is_alive) {
        next_state = ((alive_n == 1 || alive_n == 5) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 6) ? (1.0) : (0.0));
      }
      break;
    }
    case 19: { // B6/S2 - Long Life
      if (is_alive) {
        next_state = ((alive_n == 2) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 6) ? (1.0) : (0.0));
      }
      break;
    }
    case 20: { // B7/S - Seeds variant
      if (!is_alive && alive_n == 7) {
        next_state = 1.0;
      } else if (is_alive) {
        next_state = 0.0; // No survival
      }
      break;
    }
    case 21: { // B8/S - Seeds variant
      if (!is_alive && alive_n == 8) {
        next_state = 1.0;
      } else if (is_alive) {
        next_state = 0.0; // No survival
      }
      break;
    }
    case 22: { // B9/S - Seeds variant
      if (!is_alive && alive_n == 9) {
        next_state = 1.0;
      } else if (is_alive) {
        next_state = 0.0; // No survival
      }
      break;
    }
    default: { // Default to Conway's Game of Life
      if (is_alive) {
        next_state = ((alive_n == 2 || alive_n == 3) ? (1.0) : (0.0));
      } else {
        next_state = ((alive_n == 3) ? (1.0) : (0.0));
      }
      break;
    }
  }

  // Age update: grow age when alive, decay when dead
  if (next_state >= 0.5) {
    v.age = frac(v.age + 0.016 * 0.6);
  } else {
    v.age = v.age * 0.98;
  }

  v.state = next_state;
    vertices[i] = v;
  }
}
