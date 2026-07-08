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

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    let cell_count = analysis.grid_size * analysis.grid_size;
    if (index == 0) {
        blob_count[0] = 0;
    }
    if (index < cell_count) {
        AnalysisCell empty_cell;
        empty_cell.density = 0;
        empty_cell.velocity_sum = int2(0, 0);
        empty_cell.speed_sum = 0;
        [unroll]
        for (uint i = 0; i < 8; i++) {
            empty_cell.species_histogram[i] = 0;
        }
        cells[index] = empty_cell;
        coherence[index] = 0.0;
        labels[index] = 0;
        parent[index] = index;
        tile_components[index] = 0xffffffffu;
    }
    if (index < 128) {
        BlobAccumulator summary;
        summary.id = 0;
        summary.area = 0;
        summary.density = 0;
        summary.coherence_sum = 0;
        summary.centroid_sum = int2(0, 0);
        summary.velocity_sum = int2(0, 0);
        summary.bounds_min = uint2(0xffffffffu, 0xffffffffu);
        summary.bounds_max = uint2(0, 0);
        [unroll]
        for (uint i = 0; i < 8; i++) {
            summary.species_histogram[i] = 0;
        }
        blob_summaries[index] = summary;
    }
}
