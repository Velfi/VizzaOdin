// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/primordial_particles/shaders/density_compute.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// GPU-based density calculation for PPS particle coloring

struct Particle {

    float2 position;
    float2 previous_position;
    float heading;
    float velocity;
    float density;
    uint grabbed;
};

struct DensityParams {

    uint particle_count;
    float density_radius;
    uint coloring_mode; // 0 = random, 1 = density, 2 = heading, 3 = velocity
    uint grid_axis;
    float grid_cell_size;
    uint3 _padding;
};

[[vk::binding(0, 0)]]
RWStructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]]
ConstantBuffer<DensityParams> params;
[[vk::binding(2, 0)]] StructuredBuffer<uint> grid_heads;
[[vk::binding(3, 0)]] StructuredBuffer<uint> grid_next;

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    if (index >= params.particle_count) {
        return;
    }

    var particle = particles[index];
    
    // Always compute density here. Rendering decides how to use it.
    // This avoids stale or incorrect values when UI state changes.
    particle.density = compute_density(particle, index);
    
    particles[index] = particle;
}

float compute_density(Particle particle, uint particle_index) {
    var density = 0.0;
    let density_radius_sq = params.density_radius * params.density_radius;
    
    let axis = int(params.grid_axis);
    let center = int2(clamp(int((particle.position.x + 1.0) / params.grid_cell_size), 0, axis - 1),
                      clamp(int((particle.position.y + 1.0) / params.grid_cell_size), 0, axis - 1));
    let cell_radius = min(int(ceil(params.density_radius / params.grid_cell_size)), axis / 2);
    for (var oy = -cell_radius; oy <= cell_radius; oy++) {
      for (var ox = -cell_radius; ox <= cell_radius; ox++) {
        let minimum_cell_dx = float(max(abs(ox) - 1, 0)) * params.grid_cell_size;
        let minimum_cell_dy = float(max(abs(oy) - 1, 0)) * params.grid_cell_size;
        if (minimum_cell_dx * minimum_cell_dx + minimum_cell_dy * minimum_cell_dy > density_radius_sq) {
            continue;
        }
        var cx = (center.x + ox) % axis;
        var cy = (center.y + oy) % axis;
        if (cx < 0) cx += axis;
        if (cy < 0) cy += axis;
        var i = grid_heads[uint(cy * axis + cx)];
        while (i != 0xffffffffu) {
          if (i != particle_index) {
            let other = particles[i];
        var delta = particle.position - other.position;
        
        // Toroidal wrapping for PPS world space [-1,1]
        if (abs(delta.x) > 1.0) {
            delta.x = delta.x - sign(delta.x) * 2.0;
        }
        if (abs(delta.y) > 1.0) {
            delta.y = delta.y - sign(delta.y) * 2.0;
        }
        
        let distance_sq = dot(delta, delta);
        
        if (distance_sq < density_radius_sq) {
            density += 1.0 / (1.0 + distance_sq);
        }
          }
          i = grid_next[i];
        }
      }
    }
    
    return density;
}
