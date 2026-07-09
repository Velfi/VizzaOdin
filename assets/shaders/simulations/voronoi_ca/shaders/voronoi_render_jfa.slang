// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/voronoi_ca/shaders/voronoi_render_jfa.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
float4 LoadTexture(Texture2D<float4> tex, int2 p, uint lod) { return tex.Load(int3(p, int(lod))); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Fullscreen Voronoi renderer using JFA texture: shades regions by sampling LUT.
// This version uses the pre-computed JFA texture instead of brute-force search

struct VSOut {
  float4 pos : SV_Position;
  float2 uv : TEXCOORD0;
};

// 0: VoronoiParams (uniform), 1: LUT (storage), 2: JFA texture

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
StructuredBuffer<uint> lut_data;

// JFA texture: RGBA32Float
// R,G: site position (x,y)
// B: site index (as float)
// A: distance to site (squared)
[[vk::binding(2, 0)]]
Texture2D<float4> jfa_texture;

float srgb_to_linear(float srgb) {
  if (srgb <= 0.04045) { return srgb / 12.92; }
  return pow((srgb + 0.055) / 1.055, 2.4);
}

float3 lut_sample(float intensity) {
  let lut_index = clamp(intensity * 255.0, 0.0, 255.0);
  let idx = uint(lut_index);
  let r_srgb = float(lut_data[idx]) / 255.0;
  let g_srgb = float(lut_data[idx + 256]) / 255.0;
  let b_srgb = float(lut_data[idx + 512]) / 255.0;
  return float3(srgb_to_linear(r_srgb), srgb_to_linear(g_srgb), srgb_to_linear(b_srgb));
}

float hash_u32_to_unit_float(uint n) {
  // Simple integer hash -> [0,1)
  var x = n;
  x ^= x >> 16;
  x *= 0x7feb352du;
  x ^= x >> 15;
  x *= 0x846ca68bu;
  x ^= x >> 16;
  return float(x) / 4294967295.0;
}

[shader("vertex")]
VSOut vs_main(uint vi : SV_VertexID) {
  var p = float2[3](float2(-1.0, -3.0), float2(3.0, 1.0), float2(-1.0, 1.0));
  VSOut out;
  let pos = p[vi];
  out.pos = float4(pos, 0.0, 1.0);
  // Flip Y so UV origin matches textureLoad's top-left origin
  out.uv = float2(pos.x * 0.5 + 0.5, -pos.y * 0.5 + 0.5);
  return out;
}

[shader("fragment")]
float4 fs_main(VSOut in) : SV_Target0 {
  let uv = clamp(in.uv, float2(0.0), float2(0.999999));
  
  // Load JFA texture to get closest site information
  let fdim = float2(params.resolution_x, params.resolution_y);
  let pixel_coord = int2(clamp(int2(float2(uv * fdim)), int2(0), int2(int(fdim.x) - 1, int(fdim.y) - 1)));
  let jfa_data = LoadTexture(jfa_texture, pixel_coord, 0);
  let closest_site_index = uint(jfa_data.b);
  let closest_distance = jfa_data.a;
  
  var is_border = false;
  if (params.border_enabled >= 0.5 && params.border_width > 0.0) {
    var found_different_site = false;
    let border_width = params.border_width;
    
    if (border_width <= 4.0) {
      let check_radius = int(ceil(border_width));
      for (var dy = -check_radius; dy <= check_radius && !found_different_site; dy = dy + 1) {
        for (var dx = -check_radius; dx <= check_radius && !found_different_site; dx = dx + 1) {
          if (dx == 0 && dy == 0) { continue; }
          
          let distance = sqrt(float(dx * dx + dy * dy));
          if (distance > border_width) { continue; }
          
          let check_coord = pixel_coord + int2(dx, dy);
          let wrapped_coord = int2(
            (check_coord.x + int(fdim.x)) % int(fdim.x),
            (check_coord.y + int(fdim.y)) % int(fdim.y)
          );
          let check_jfa_data = LoadTexture(jfa_texture, wrapped_coord, 0);
          let check_site_index = uint(check_jfa_data.b);
          
          if (check_site_index != closest_site_index) {
            found_different_site = true;
          }
        }
      }
    } else {
      let sample_count = min(int(border_width), 16);
      let angle_step = 6.28318 / float(sample_count);
      
      for (var i = 0; i < sample_count && !found_different_site; i = i + 1) {
        let angle = float(i) * angle_step;
        let dx = int(round(cos(angle) * border_width));
        let dy = int(round(sin(angle) * border_width));
        
        let check_coord = pixel_coord + int2(dx, dy);
        let wrapped_coord = int2(
          (check_coord.x + int(fdim.x)) % int(fdim.x),
          (check_coord.y + int(fdim.y)) % int(fdim.y)
        );
        let check_jfa_data = LoadTexture(jfa_texture, wrapped_coord, 0);
        let check_site_index = uint(check_jfa_data.b);
        
        if (check_site_index != closest_site_index) {
          found_different_site = true;
        }
      }
    }
    
    is_border = found_different_site;
  }

  float intensity;
  if (params.color_mode < 0.5) {
    // Random color per cell based on ID
    intensity = hash_u32_to_unit_float(closest_site_index);
  } else if (params.color_mode < 1.5) {
    // Distance from each pixel to its nearest site.
    let max_distance = max(min(params.resolution_x, params.resolution_y) * 0.20, 1.0);
    intensity = clamp(sqrt(max(closest_distance, 0.0)) / max_distance, 0.0, 1.0);
  } else {
    // Repeating distance bands within each region.
    intensity = frac(sqrt(max(closest_distance, 0.0)) * 0.045);
  }

  // If borders enabled, override with mid color at borders
  if (params.border_enabled >= 0.5 && is_border) {
    intensity = 0.5;
  }

  let col = lut_sample(intensity);
  return float4(col, 1.0);
}
