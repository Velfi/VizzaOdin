struct PostEffectParams {
    float brightness;
    float contrast;
    float saturation;
    float gamma;
};

struct VertexOutput {
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

[[vk::binding(0, 0)]]
Texture2D<float4> display_tex;
[[vk::binding(1, 0)]]
SamplerState display_sampler;
[[vk::binding(2, 0)]]
ConstantBuffer<PostEffectParams> params;

[shader("fragment")]
float4 main(VertexOutput input) : SV_Target0 {
    let base_color = display_tex.Sample(display_sampler, input.uv);
    var color = base_color.rgb * params.brightness;
    color = (color - 0.5) * params.contrast + 0.5;
    let luminance = dot(color, float3(0.299, 0.587, 0.114));
    color = lerp(float3(luminance), color, params.saturation);
    color = pow(color, float3(1.0 / max(params.gamma, 0.0001)));
    return float4(color, base_color.a);
}
