// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/voronoi_ca/shaders/jfa_iteration.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
float4 LoadTexture(Texture2D<float4> tex, int2 p, uint lod) { return tex.Load(int3(p, int(lod))); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// JFA iteration shader - performs one step of the jump flood algorithm

struct VoronoiParams {

  float count;
  float color_mode;
  float border_enabled;
  float border_width;
  float filter_mode;
  float resolution_x;
  float resolution_y;
  float jump_distance;
};

[[vk::binding(0, 0)]]
ConstantBuffer<VoronoiParams> params;
[[vk::binding(1, 0)]]
Texture2D<float4> voronoi_texture_read;
[[vk::binding(2, 0)]]
RWTexture2D<float4> voronoi_texture_write;

[shader("compute")]
[numthreads(8,  8, 1)]
void main(uint3 gid : SV_DispatchThreadID) {
  let coord = int2(gid.xy);
  let dims = int2(int(params.resolution_x), int(params.resolution_y));
  
  if (coord.x < dims.x && coord.y < dims.y) {
    let pixel_pos = float2(float(coord.x), float(coord.y));
  
    // Current best
    uint best_site = 0;
    float best_distance = 1e30;
    float2 best_pos = float2(0.0);
  
    // Load from current pixel
    let current = LoadTexture(voronoi_texture_read, coord, 0);
    if (current.a < best_distance) {
      best_distance = current.a;
      best_site = uint(current.b);
      best_pos = current.rg;
    }
  
    // Sample from jump offset positions
    // JFA uses powers of 2 for jump distances
    let jump_distance = params.jump_distance;
    
    for (var dy = -1; dy <= 1; dy = dy + 1) {
      for (var dx = -1; dx <= 1; dx = dx + 1) {
        if (dx == 0 && dy == 0) { continue; }
        
        let offset = int2(dx, dy) * int(jump_distance);
        let sample_coord = coord + offset;
        
        // Toroidal wrapping
        let wrapped_coord = int2(
          (sample_coord.x + dims.x) % dims.x,
          (sample_coord.y + dims.y) % dims.y
        );
        let sample = LoadTexture(voronoi_texture_read, wrapped_coord, 0);
        
        // Calculate distance from this pixel to the sampled site
        let sampled_pos = sample.rg;
        let w = params.resolution_x;
        let h = params.resolution_y;
        var dist_x = sampled_pos.x - pixel_pos.x;
        var dist_y = sampled_pos.y - pixel_pos.y;
        if (dist_x >  0.5 * w) { dist_x = dist_x - w; }
        if (dist_x < -0.5 * w) { dist_x = dist_x + w; }
        if (dist_y >  0.5 * h) { dist_y = dist_y - h; }
        if (dist_y < -0.5 * h) { dist_y = dist_y + h; }
        
        let distance = dist_x*dist_x + dist_y*dist_y;
        
        if (distance < best_distance) {
          best_distance = distance;
          best_site = uint(sample.b);
          best_pos = sampled_pos;
        }
      }
    }
  
    // Write result
    StoreTexture(voronoi_texture_write, coord, float4(best_pos, float(best_site), best_distance));
  }
}
