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
[[vk::binding(6, 0)]] RWStructuredBuffer<uint> root_to_slot;
[[vk::binding(7, 0)]] RWStructuredBuffer<uint> parent;
[[vk::binding(8, 0)]] RWStructuredBuffer<BlobAccumulator> blob_summaries;
[[vk::binding(9, 0)]] RWStructuredBuffer<uint> blob_count;

uint find_root(uint value) {
    var root = value;
    [loop]
    for (uint guard = 0; guard < 1024; guard++) {
        let next = parent[root];
        if (next == root) {
            return root;
        }
        root = next;
    }
    return root;
}

uint slot_for_root(uint root) {
    var slot = root_to_slot[root];
    if (slot != 0xffffffffu) {
        return slot;
    }
    uint new_slot;
    InterlockedAdd(blob_count[0], 1, new_slot);
    if (new_slot >= 128) {
        return 0xffffffffu;
    }
    uint old_slot;
    InterlockedCompareExchange(root_to_slot[root], 0xffffffffu, new_slot, old_slot);
    if (old_slot != 0xffffffffu) {
        return old_slot;
    }
    blob_summaries[new_slot].id = root + 1;
    return new_slot;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let index = global_id.x;
    let axis = analysis.grid_size;
    let cell_count = axis * axis;
    if (index >= cell_count || analysis.enabled == 0 || labels[index] == 0) {
        return;
    }
    let root = find_root(index);
    let slot = slot_for_root(root);
    if (slot == 0xffffffffu) {
        return;
    }

    let cell = cells[index];
    if (cell.density == 0) {
        return;
    }
    let x = index % axis;
    let y = index / axis;
    let world_size = float2(params.width, params.height);
    let center = -world_size * 0.5 + (float2(float(x), float(y)) + float2(0.5, 0.5)) * (world_size / float(axis));
    let density = cell.density;
    InterlockedAdd(blob_summaries[slot].area, 1);
    InterlockedAdd(blob_summaries[slot].density, density);
    InterlockedAdd(blob_summaries[slot].centroid_sum.x, int(center.x * float(density) * 4096.0));
    InterlockedAdd(blob_summaries[slot].centroid_sum.y, int(center.y * float(density) * 4096.0));
    InterlockedAdd(blob_summaries[slot].velocity_sum.x, cell.velocity_sum.x);
    InterlockedAdd(blob_summaries[slot].velocity_sum.y, cell.velocity_sum.y);
    InterlockedAdd(blob_summaries[slot].coherence_sum, uint(coherence[index] * 65536.0));
    InterlockedMin(blob_summaries[slot].bounds_min.x, x);
    InterlockedMin(blob_summaries[slot].bounds_min.y, y);
    InterlockedMax(blob_summaries[slot].bounds_max.x, x);
    InterlockedMax(blob_summaries[slot].bounds_max.y, y);
    [unroll]
    for (uint i = 0; i < 8; i++) {
        InterlockedAdd(blob_summaries[slot].species_histogram[i], cell.species_histogram[i]);
    }
}
