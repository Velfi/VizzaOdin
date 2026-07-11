#include "../../../common/noise.slang"

struct VectorsInstance {
    float value;
    float angle;
};

// Matches Flow_Vector_Params. Vectors reuses the mature shared noise parameter
// layout; target_width/target_height carry the glyph column/row counts.
struct FieldParams {
    uint grid_size;
    uint vector_field_type;
    uint noise_kind;
    uint fractal_mode;
    uint noise_seed;
    float offset_x;
    float offset_y;
    float rotation;
    float anchor_x;
    float anchor_y;
    float noise_strength;
    float amplitude;
    float frequency;
    uint octaves;
    float lacunarity;
    float gain;
    uint warp_mode;
    uint warp_octaves;
    float warp_amplitude;
    float warp_frequency;
    uint gabor_iterations;
    float gabor_velocity;
    float gabor_band_width;
    float gabor_band_softness;
    uint phasor_iterations;
    float phasor_velocity;
    float phasor_band_width;
    uint voronoi_output;
    uint voronoi_distance_mode;
    float wave_velocity;
    float wave_band_width;
    float wave_band_softness;
    float time;
    float vector_magnitude;
    uint _pad0;
    uint image_fit_mode;
    uint image_mirror_horizontal;
    uint image_mirror_vertical;
    uint image_invert_tone;
    uint webcam_live;
    uint target_width;
    uint target_height;
    uint _pad1;
};

[[vk::binding(0, 0)]] RWStructuredBuffer<VectorsInstance> instances;
[[vk::binding(1, 0)]] ConstantBuffer<FieldParams> params;
[[vk::binding(2, 0)]] Texture2D<float4> field_image;
[[vk::binding(3, 0)]] SamplerState field_sampler;

struct FieldStamp {
    float2 position;
    float radius;
    float angle;
};
[[vk::binding(4, 0)]] StructuredBuffer<FieldStamp> stamps;

NoiseParams field_noise_params() {
    NoiseParams n;
    n.kind = params.noise_kind;
    n.fractal_mode = params.fractal_mode;
    n.seed = params.noise_seed;
    n.offset_x = params.offset_x;
    n.offset_y = params.offset_y;
    n.rotation = params.rotation;
    n.anchor_x = params.anchor_x;
    n.anchor_y = params.anchor_y;
    n.strength = params.noise_strength;
    n.amplitude = params.amplitude;
    n.frequency = params.frequency;
    n.octaves = params.octaves;
    n.lacunarity = params.lacunarity;
    n.gain = params.gain;
    n.warp_mode = params.warp_mode;
    n.warp_octaves = params.warp_octaves;
    n.warp_amplitude = params.warp_amplitude;
    n.warp_frequency = params.warp_frequency;
    n.gabor_iterations = params.gabor_iterations;
    n.gabor_velocity = params.gabor_velocity;
    n.gabor_band_width = params.gabor_band_width;
    n.gabor_band_softness = params.gabor_band_softness;
    n.phasor_iterations = params.phasor_iterations;
    n.phasor_velocity = params.phasor_velocity;
    n.phasor_band_width = params.phasor_band_width;
    n.voronoi_output = params.voronoi_output;
    n.voronoi_distance_mode = params.voronoi_distance_mode;
    n.wave_velocity = params.wave_velocity;
    n.wave_band_width = params.wave_band_width;
    n.wave_band_softness = params.wave_band_softness;
    return n;
}

float webcam_value(float2 target_uv) {
    uint tw, th;
    field_image.GetDimensions(tw, th);
    float2 source_size = float2(max(tw, 1u), max(th, 1u));
    float2 target_size = float2(512.0, 512.0);
    float2 p = target_uv * target_size;
    if (params.image_mirror_horizontal != 0u) p.x = target_size.x - p.x;
    if (params.image_mirror_vertical != 0u) p.y = target_size.y - p.y;
    float2 source_p;
    if (params.image_fit_mode == 1u) {
        source_p.x = source_size.x > target_size.x ? p.x * source_size.x / target_size.x : p.x - (target_size.x - source_size.x) * 0.5;
        source_p.y = source_size.y > target_size.y ? p.y * source_size.y / target_size.y : p.y - (target_size.y - source_size.y) * 0.5;
    } else if (params.image_fit_mode == 2u) {
        float fitted_h = target_size.x * source_size.y / source_size.x;
        source_p = float2(p.x * source_size.x / target_size.x, (p.y - (target_size.y - fitted_h) * 0.5) * source_size.y / fitted_h);
    } else if (params.image_fit_mode == 3u) {
        float fitted_w = target_size.y * source_size.x / source_size.y;
        source_p = float2((p.x - (target_size.x - fitted_w) * 0.5) * source_size.x / fitted_w, p.y * source_size.y / target_size.y);
    } else {
        source_p = p * source_size / target_size;
    }
    bool inside = all(source_p >= 0.0) && all(source_p < source_size);
    float value = 0.0;
    if (inside) {
        float2 uv = (source_p + 0.5) / source_size;
        float3 rgb = field_image.SampleLevel(field_sampler, uv, 0.0).rgb;
        value = dot(rgb, float3(0.2126, 0.7152, 0.0722));
    }
    return params.image_invert_tone != 0u ? 1.0 - value : value;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 id : SV_DispatchThreadID) {
    uint cols = max(params.target_width, 1u);
    uint rows = max(params.target_height, 1u);
    uint count = cols * rows;
    if (id.x >= count) return;
    uint x = id.x % cols;
    uint y = id.x / cols;
    float wx = -1.2 + (float(x) + 0.5) / float(cols) * 2.4;
    float wy = -0.9 + (float(y) + 0.5) / float(rows) * 1.8;
    float value;
    if (params.vector_field_type == 0u) {
        float raw = noise_sample_2d(field_noise_params(), float2(wx, wy), params.time);
        value = clamp(raw * 0.5 + 0.5, 0.0, 1.0);
    } else {
        float2 uv = clamp(float2((wx + 1.0) * 0.5, 1.0 - (wy + 1.0) * 0.5), 0.0, 1.0);
        value = params.webcam_live != 0u ? webcam_value(uv) : field_image.SampleLevel(field_sampler, uv, 0.0).r;
    }
    float angle = value * 6.28318530718;
    uint stamp_count = min(params._pad0, 32u);
    for (uint i = 0u; i < stamp_count; ++i) {
        FieldStamp stamp = stamps[i];
        float2 delta = float2(wx, wy) - stamp.position;
        float distance_sq = dot(delta, delta);
        if (distance_sq < stamp.radius * stamp.radius) {
            float distance = sqrt(distance_sq);
            angle += stamp.angle * (1.0 - distance / max(stamp.radius, 0.0001));
        }
    }
    instances[id.x] = VectorsInstance(value, angle);
}
