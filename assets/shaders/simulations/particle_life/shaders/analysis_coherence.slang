struct Particle { float2 position; float2 velocity; uint species; uint _pad; };
struct SimParams {
    uint particle_count; uint species_count; float max_force; float max_distance;
    float friction; uint wrap_edges; float width; float height; uint random_seed;
    float dt; float beta; float cursor_x; float cursor_y; float cursor_size;
    float cursor_strength; uint cursor_active; float brownian_motion;
    float particle_size; float aspect_ratio; uint _pad1;
};
struct AnalysisParams {
    uint enabled; uint interval_frames; uint grid_size; uint min_blob_area_cells;
    float coherence_threshold; float _pad1; float _pad2; float _pad3;
};
struct AnalysisCell { uint density; int2 velocity_sum; uint speed_sum; uint species_histogram[8]; };
struct BlobAccumulator {
    uint id; uint area; uint density; uint coherence_sum; int2 centroid_sum;
    int2 velocity_sum; uint2 bounds_min; uint2 bounds_max; uint species_histogram[8];
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

float smoothstep_local(float edge0, float edge1, float x) {
    let t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    let axis = analysis.grid_size;
    let cell_count = axis * axis;
    if (index >= cell_count || analysis.enabled == 0) {
        return;
    }
    let cell = cells[index];
    if (cell.density == 0) {
        coherence[index] = 0.0;
        labels[index] = 0;
        return;
    }

    let x = index % axis;
    let y = index / axis;
    var neighbor_density = 0.0;
    var neighbor_velocity = float2(0.0, 0.0);
    var neighbor_count = 0.0;
    for (int oy = -1; oy <= 1; oy++) {
        for (int ox = -1; ox <= 1; ox++) {
            let nx = int(x) + ox;
            let ny = int(y) + oy;
            if (nx < 0 || ny < 0 || nx >= int(axis) || ny >= int(axis)) {
                continue;
            }
            let ni = uint(ny) * axis + uint(nx);
            let n = cells[ni];
            if (n.density == 0) {
                continue;
            }
            neighbor_density += float(n.density);
            neighbor_velocity += float2(float(n.velocity_sum.x), float(n.velocity_sum.y));
            neighbor_count += 1.0;
        }
    }

    let avg_velocity = float2(float(cell.velocity_sum.x), float(cell.velocity_sum.y)) / max(float(cell.density), 1.0);
    let avg_neighbor_velocity = neighbor_velocity / max(neighbor_density, 1.0);
    let speed = length(avg_velocity);
    let neighbor_speed = length(avg_neighbor_velocity);
    var alignment = 0.65;
    if (speed > 0.00001 && neighbor_speed > 0.00001) {
        alignment = clamp(dot(avg_velocity, avg_neighbor_velocity) / (speed * neighbor_speed) * 0.5 + 0.5, 0.0, 1.0);
    }

    let neighbor_average_density = neighbor_density / max(neighbor_count, 1.0);
    let boundary_strength = abs(float(cell.density) - neighbor_average_density) / max(float(cell.density), 1.0);
    let boundary_score = clamp(boundary_strength * 1.5 + 0.50, 0.50, 1.0);
    let density_score = smoothstep_local(0.75, 4.0, float(cell.density));
    let score = density_score * alignment * boundary_score;
    coherence[index] = score;
    labels[index] = score >= analysis.coherence_threshold ? index + 1 : 0;
}
