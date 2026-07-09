[[vk::binding(0, 0)]]
Texture2D<float4> source_texture;
[[vk::binding(1, 0)]]
SamplerState source_sampler;

struct Fragment_Output {
	float4 color: SV_Target0;
};

[shader("fragment")]
Fragment_Output fragment_main(
	[[vk::location(0)]] float4 color: COLOR0,
	[[vk::location(1)]] float2 texcoord: TEXCOORD0,
	[[vk::location(2)]] float glyph: TEXCOORD1,
	[[vk::location(3)]] float4 effect: TEXCOORD2,
	[[vk::location(4)]] float4 material: TEXCOORD3) {
	Fragment_Output output;
	float2 step = effect.xy;
	float4 blurred =
		source_texture.Sample(source_sampler, texcoord) * 0.2270270270 +
		source_texture.Sample(source_sampler, texcoord + step * 1.3846153846) * 0.3162162162 +
		source_texture.Sample(source_sampler, texcoord - step * 1.3846153846) * 0.3162162162 +
		source_texture.Sample(source_sampler, texcoord + step * 3.2307692308) * 0.0702702703 +
		source_texture.Sample(source_sampler, texcoord - step * 3.2307692308) * 0.0702702703;
	output.color = blurred * color;
	return output;
}
