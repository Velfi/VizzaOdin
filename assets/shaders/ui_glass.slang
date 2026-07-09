[[vk::binding(0, 0)]]
Texture2D<float4> backdrop_sharp;
[[vk::binding(1, 0)]]
Texture2D<float4> backdrop_half;
[[vk::binding(2, 0)]]
Texture2D<float4> backdrop_quarter;
[[vk::binding(3, 0)]]
Texture2D<float4> backdrop_eighth;
[[vk::binding(4, 0)]]
SamplerState backdrop_sampler;

struct Fragment_Output {
	float4 color: SV_Target0;
};

float ui_rounded_rect_sdf_px(float2 local_uv, float2 rect_px, float radius_px) {
	float2 p = (local_uv - 0.5) * rect_px;
	float2 half_size = rect_px * 0.5;
	float r = min(max(radius_px, 0.0), min(half_size.x, half_size.y));
	float2 q = abs(p) - (half_size - r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float4 ui_sample_backdrop_pyramid(float2 uv, float roughness) {
	float r = saturate(roughness) * 3.0;
	float4 sharp = backdrop_sharp.Sample(backdrop_sampler, uv);
	float4 half_blur = backdrop_half.Sample(backdrop_sampler, uv);
	float4 quarter_blur = backdrop_quarter.Sample(backdrop_sampler, uv);
	float4 eighth_blur = backdrop_eighth.Sample(backdrop_sampler, uv);
	if (r < 1.0) {
		return lerp(sharp, half_blur, r);
	}
	if (r < 2.0) {
		return lerp(half_blur, quarter_blur, r - 1.0);
	}
	return lerp(quarter_blur, eighth_blur, r - 2.0);
}

[shader("fragment")]
Fragment_Output fragment_main(
	float4 position: SV_Position,
	[[vk::location(0)]] float4 tint: COLOR0,
	[[vk::location(1)]] float2 local_uv: TEXCOORD0,
	[[vk::location(2)]] float glyph: TEXCOORD1,
	[[vk::location(3)]] float4 effect: TEXCOORD2,
	[[vk::location(4)]] float4 material: TEXCOORD3) {
	Fragment_Output output;

	uint source_w_u;
	uint source_h_u;
	backdrop_sharp.GetDimensions(source_w_u, source_h_u);
	float2 source_size = max(float2(float(source_w_u), float(source_h_u)), float2(1.0));
	float2 rect_px = 1.0 / max(fwidth(local_uv), float2(0.00001));

	float thickness_px = max(effect.x, 0.0);
	float roughness = saturate(effect.y);
	float bevel_px = max(effect.z, 0.001);
	float radius_px = max(effect.w, 0.0);
	float ior = max(material.x, 1.0);
	float dispersion_px = max(material.y, 0.0);
	float border_strength = saturate(material.z);
	float highlight_strength = saturate(material.w);

	float sdf = ui_rounded_rect_sdf_px(local_uv, rect_px, radius_px);
	float aa = max(fwidth(sdf), 0.75);
	float coverage = 1.0 - smoothstep(-aa, aa, sdf);
	float bevel = saturate((bevel_px - abs(sdf)) / bevel_px);

	float2 sdf_grad = float2(ddx(sdf), ddy(sdf));
	float grad_len = max(length(sdf_grad), 0.0001);
	float2 edge_normal = sdf_grad / grad_len;
	float2 lens = (local_uv - 0.5) * 0.18;
	float normal_weight = bevel * bevel;
	float2 refraction_normal = normalize(edge_normal * normal_weight + lens * (1.0 - normal_weight) + float2(0.0001, 0.0));

	float ior_bend = saturate((ior - 1.0) / 0.75);
	float center_frost = roughness * 0.35;
	float bend_px = thickness_px * (0.12 + ior_bend * 0.18) * (normal_weight + center_frost);
	float2 screen_uv = position.xy / source_size;
	float2 offset_uv = refraction_normal * bend_px / source_size;
	float2 refracted_uv = clamp(screen_uv - offset_uv, float2(0.001), float2(0.999));
	float2 dispersion_uv = refraction_normal * dispersion_px * (0.35 + normal_weight) / source_size;

	float3 refracted;
	refracted.r = ui_sample_backdrop_pyramid(clamp(refracted_uv + dispersion_uv, float2(0.001), float2(0.999)), roughness).r;
	refracted.g = ui_sample_backdrop_pyramid(refracted_uv, roughness).g;
	refracted.b = ui_sample_backdrop_pyramid(clamp(refracted_uv - dispersion_uv, float2(0.001), float2(0.999)), roughness).b;

	float absorption_strength = saturate(tint.a);
	float3 neutral_absorption = lerp(float3(1.0), max(tint.rgb, float3(0.001)), absorption_strength * 0.92);
	float density_shadow = 1.0 - absorption_strength * (0.30 + roughness * 0.12);
	float3 glass = refracted * neutral_absorption * density_shadow;

	float normal_z = sqrt(saturate(1.0 - normal_weight * 0.72));
	float f0 = pow((ior - 1.0) / max(ior + 1.0, 0.0001), 2.0);
	float fresnel = f0 + (1.0 - f0) * pow(1.0 - saturate(normal_z), 5.0);
	float rim = saturate(bevel * border_strength + fresnel * highlight_strength);
	glass = lerp(glass, float3(1.0), rim * 0.12);

	output.color = float4(glass, coverage);
	return output;
}
