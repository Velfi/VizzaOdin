struct Particle {
    float2 position;
    float2 velocity;
    uint species;
    uint _pad;
};

struct SimParams {
    uint particle_count;
    uint species_count;
    float max_force;
    float max_distance;
    float friction;
    uint wrap_edges;
    float width;
    float height;
    uint random_seed;
    float dt;
    float beta;
    float cursor_x;
    float cursor_y;
    float cursor_size;
    float cursor_strength;
    uint cursor_active;
    float brownian_motion;
    float particle_size;
    float aspect_ratio;
    uint _pad1;
};

struct AnalysisParams {
    uint enabled;
    uint interval_frames;
    uint grid_size;
    uint min_blob_area_cells;
    float coherence_threshold;
    float _pad1;
    float _pad2;
    float _pad3;
};

struct AnalysisCell {
    uint density;
    int2 velocity_sum;
    uint speed_sum;
    uint species_histogram[8];
};

struct BlobAccumulator {
    uint id;
    uint area;
    uint density;
    uint coherence_sum;
    int2 centroid_sum;
    int2 velocity_sum;
    uint2 bounds_min;
    uint2 bounds_max;
    uint species_histogram[8];
};

[[vk::binding(0, 0)]] RWStructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]] ConstantBuffer<SimParams> params;
[[vk::binding(2, 0)]] ConstantBuffer<AnalysisParams> analysis;
[[vk::binding(3, 0)]] RWStructuredBuffer<AnalysisCell> cells;
[[vk::binding(4, 0)]] RWStructuredBuffer<float> coherence;
[[vk::binding(5, 0)]] RWStructuredBuffer<uint> labels;
[[vk::binding(6, 0)]] RWStructuredBuffer<uint> tile_components;
[[vk::binding(7, 0)]] RWStructuredBuffer<uint> parent;
[[vk::binding(8, 0)]] RWStructuredBuffer<BlobAccumulator> blob_summaries;
[[vk::binding(9, 0)]] RWStructuredBuffer<uint> blob_count;

uint2 particle_to_cell(float2 position) {
    let world_size = float2(params.width, params.height);
    let normalized = clamp((position + world_size * 0.5) / world_size, float2(0.0, 0.0), float2(0.999999, 0.999999));
    return uint2(
        min(uint(normalized.x * float(analysis.grid_size)), analysis.grid_size - 1),
        min(uint(normalized.y * float(analysis.grid_size)), analysis.grid_size - 1)
    );
}

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    if (index >= params.particle_count || analysis.enabled == 0) {
        return;
    }
    let particle = particles[index];
    let coord = particle_to_cell(particle.position);
    let cell_index = coord.y * analysis.grid_size + coord.x;
    InterlockedAdd(cells[cell_index].density, 1);
    InterlockedAdd(cells[cell_index].velocity_sum.x, int(particle.velocity.x * 65536.0));
    InterlockedAdd(cells[cell_index].velocity_sum.y, int(particle.velocity.y * 65536.0));
    InterlockedAdd(cells[cell_index].speed_sum, uint(length(particle.velocity) * 65536.0));
    let species = min(particle.species, 7u);
    if (species < params.species_count) {
        InterlockedAdd(cells[cell_index].species_histogram[species], 1);
    }
}
