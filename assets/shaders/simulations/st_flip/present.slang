struct PresentParams {
    uint grid_width;
    uint grid_height;
    uint color_scheme_reversed;
    float smoothing;
};

struct VertexOutput {
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

[[vk::binding(0, 0)]] StructuredBuffer<uint> render_density;
[[vk::binding(1, 0)]] StructuredBuffer<uint> lut;
[[vk::binding(2, 0)]] ConstantBuffer<PresentParams> params;

float srgb_to_linear(float value) {
    return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4);
}

float3 lut_color(float intensity) {
    let value = params.color_scheme_reversed != 0u ? 1.0 - intensity : intensity;
    let index = uint(clamp(value * 255.0, 0.0, 255.0));
    return float3(srgb_to_linear(float(lut[index]) / 255.0),
                  srgb_to_linear(float(lut[index + 256u]) / 255.0),
                  srgb_to_linear(float(lut[index + 512u]) / 255.0));
}

[shader("vertex")]
VertexOutput vs_main(uint id : SV_VertexID) {
    let positions = float2[6](float2(-1,-1), float2(1,-1), float2(-1,1), float2(-1,1), float2(1,-1), float2(1,1));
    VertexOutput output;
    output.position = float4(positions[id], 0, 1);
    output.uv = positions[id] * float2(0.5, -0.5) + 0.5;
    return output;
}

[shader("fragment")]
float4 fs_main(float2 uv : TEXCOORD0) : SV_Target0 {
    let grid_position = uv * float2(params.grid_width, params.grid_height) - 0.5;
    let base = int2(floor(grid_position));
    let fraction = frac(grid_position);
    var count = 0.0;
    var weight_sum = 0.0;
    for (var oy = -1; oy <= 1; oy++) for (var ox = -1; ox <= 1; ox++) {
        let sample_base = base + int2(ox, oy);
        let p00 = clamp(sample_base, int2(0), int2(int(params.grid_width)-1, int(params.grid_height)-1));
        let p10 = clamp(sample_base + int2(1, 0), int2(0), int2(int(params.grid_width)-1, int(params.grid_height)-1));
        let p01 = clamp(sample_base + int2(0, 1), int2(0), int2(int(params.grid_width)-1, int(params.grid_height)-1));
        let p11 = clamp(sample_base + int2(1, 1), int2(0), int2(int(params.grid_width)-1, int(params.grid_height)-1));
        let d00 = float(render_density[uint(p00.y) * params.grid_width + uint(p00.x)]);
        let d10 = float(render_density[uint(p10.y) * params.grid_width + uint(p10.x)]);
        let d01 = float(render_density[uint(p01.y) * params.grid_width + uint(p01.x)]);
        let d11 = float(render_density[uint(p11.y) * params.grid_width + uint(p11.x)]);
        let interpolated = lerp(lerp(d00, d10, fraction.x), lerp(d01, d11, fraction.x), fraction.y);
        let sigma = lerp(0.35, 4.0, clamp(params.smoothing, 0.0, 1.0));
        let weight = exp(-float(ox*ox + oy*oy) / sigma);
        count += interpolated * weight;
        weight_sum += weight;
    }
    // The compute pass stores ink concentration as four fixed coverage levels.
    let reconstructed_mass = (count / weight_sum) * 0.32;
    let grayscale = smoothstep(0.16, 0.95, reconstructed_mass);
    return float4(lut_color(grayscale), 1.0);
}
