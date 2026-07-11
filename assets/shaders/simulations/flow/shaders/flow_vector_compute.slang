#include "../../../common/noise.slang"
#include "../../../common/texture.slang"

[[vk::binding(0, 0)]]
RWStructuredBuffer<FlowVector> flow_vectors;

[[vk::binding(1, 0)]]
ConstantBuffer<FlowVectorParams> params;

[[vk::binding(2, 0)]]
Texture2D<float4> vector_field_image;

[[vk::binding(3, 0)]]
SamplerState vector_field_sampler;

struct FlowVector {
    float2 position;
    float2 direction;
};

struct FlowVectorParams {
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

float webcam_image_value(float2 target_uv, uint texture_width, uint texture_height) {
    float target_width = float(max(params.target_width, 1u));
    float target_height = float(max(params.target_height, 1u));
    float source_width = float(max(texture_width, 1u));
    float source_height = float(max(texture_height, 1u));
    float2 p = target_uv * float2(target_width, target_height);
    if (params.image_mirror_horizontal != 0u) p.x = target_width - p.x;
    if (params.image_mirror_vertical != 0u) p.y = target_height - p.y;

    float2 source_p;
    bool inside = true;
    if (params.image_fit_mode == 1u) { // Center
        source_p.x = source_width > target_width ? p.x * source_width / target_width : p.x - (target_width - source_width) * 0.5;
        source_p.y = source_height > target_height ? p.y * source_height / target_height : p.y - (target_height - source_height) * 0.5;
    } else if (params.image_fit_mode == 2u) { // Fit H
        float fitted_height = target_width * source_height / source_width;
        source_p = float2(p.x * source_width / target_width, (p.y - (target_height - fitted_height) * 0.5) * source_height / fitted_height);
    } else if (params.image_fit_mode == 3u) { // Fit V
        float fitted_width = target_height * source_width / source_height;
        source_p = float2((p.x - (target_width - fitted_width) * 0.5) * source_width / fitted_width, p.y * source_height / target_height);
    } else { // Stretch
        source_p = p * float2(source_width / target_width, source_height / target_height);
    }
    inside = all(source_p >= 0.0) && source_p.x < source_width && source_p.y < source_height;
    if (!inside) return params.image_invert_tone != 0u ? 1.0 : 0.0;
    source_p.y = source_height - 1.0 - source_p.y;
    float3 rgb = LoadTexture(vector_field_image, int2(source_p), 0).rgb;
    float value = dot(rgb, float3(0.2126, 0.7152, 0.0722));
    return params.image_invert_tone != 0u ? 1.0 - value : value;
}

NoiseParams flow_noise_params() {
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

[shader("compute")]
[numthreads(16, 16, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let x = global_id.x;
    let y = global_id.y;
    if (x >= params.grid_size || y >= params.grid_size) {
        return;
    }

    let index = y * params.grid_size + x;
    let world_x = (float(x) / float(params.grid_size - 1)) * 2.0 - 1.0;
    let world_y = (float(y) / float(params.grid_size - 1)) * 2.0 - 1.0;
    float2 direction;

    uint texture_width = 0;
    uint texture_height = 0;
    vector_field_image.GetDimensions(texture_width, texture_height);
    let _sampler_ref = vector_field_sampler;

    if (params.vector_field_type == 0) {
        let noise_value = noise_sample_2d(flow_noise_params(), float2((world_x + 1.0) * 0.5, (world_y + 1.0) * 0.5), params.time);
        let angle = noise_value * 6.28318530718;
        direction = float2(cos(angle), sin(angle)) * params.vector_magnitude;
    } else {
        let tex_coords = float2((world_x + 1.0) * 0.5, 1.0 - (world_y + 1.0) * 0.5);
        let texel_coords = uint2(
            uint(clamp(tex_coords.x, 0.0, 1.0) * float(max(texture_width, 1u) - 1u)),
            uint(clamp(tex_coords.y, 0.0, 1.0) * float(max(texture_height, 1u) - 1u))
        );
        let image_value = params.webcam_live != 0u
            ? webcam_image_value(tex_coords, texture_width, texture_height)
            : LoadTexture(vector_field_image, int2(texel_coords), 0).r;
        let angle = image_value * 6.28318530718;
        direction = float2(cos(angle), sin(angle)) * params.vector_magnitude;
    }

    flow_vectors[index] = FlowVector(float2(world_x, world_y), direction);
}
