[[vk::binding(0, 0)]]
Texture2D<float4> ui_image_texture;
[[vk::binding(1, 0)]]
SamplerState ui_image_sampler;

struct Fragment_Output {
	float4 color: SV_Target0;
};

float3 ui_hsv_to_rgb(float3 hsv) {
	float s = saturate(hsv.y);
	float v = saturate(hsv.z);
	float3 p = abs(frac(float3(hsv.x, hsv.x + 2.0 / 3.0, hsv.x + 1.0 / 3.0)) * 6.0 - 3.0);
	return v * lerp(float3(1.0), saturate(p - 1.0), s);
}

float4 ui_shader_output(float2 uv, float4 tint, float4 effect, float glyph) {
	float kind = floor((-glyph - 10.0) + 0.5);
	if (kind > 3.5) {
		float2 p = uv * 2.0 - 1.0;
		float dist = length(p);
		float inner = saturate(effect.y);
		float edge = max(fwidth(dist) * 1.5, 0.002);
		float ring = smoothstep(inner - edge, inner + edge, dist) * (1.0 - smoothstep(1.0 - edge, 1.0 + edge, dist));
		float angle = frac((atan2(p.y, p.x) + 1.57079632679) / 6.28318530718);
		float progress = saturate(effect.x);
		float arc = 1.0 - smoothstep(progress, progress + max(fwidth(angle), 0.004), angle);
		float3 track = tint.rgb * 0.34;
		float3 rgb = lerp(track, tint.rgb, arc);
		return float4(rgb, ring * tint.a);
	}
	if (kind > 2.5) {
		float2 p = uv * 2.0 - 1.0;
		float dist = length(p);
		float inner = saturate(effect.x);
		float edge = max(fwidth(dist) * 1.5, 0.002);
		float ring = smoothstep(inner - edge, inner + edge, dist) * (1.0 - smoothstep(1.0 - edge, 1.0 + edge, dist));
		float hue = frac(atan2(p.y, p.x) / 6.28318530718);
		return float4(ui_hsv_to_rgb(float3(hue, 1.0, 1.0)) * tint.rgb, ring * tint.a);
	}
	if (kind > 1.5) {
		float2 cell = floor(uv * float2(18.0, 3.0));
		float checker = fmod(cell.x + cell.y, 2.0) < 1.0 ? 0.22 : 0.34;
		float4 base = float4(tint.rgb, saturate(uv.x) * tint.a);
		float3 composed = lerp(float3(checker), base.rgb, base.a);
		return float4(composed, 1.0);
	}
	if (kind > 0.5) {
		float3 saturation_color = lerp(float3(1.0), tint.rgb, saturate(uv.x));
		float3 value_color = saturation_color * (1.0 - saturate(uv.y));
		return float4(value_color, tint.a);
	}
	return float4(ui_hsv_to_rgb(float3(uv.x, 1.0, 1.0)), tint.a) * float4(tint.rgb, 1.0);
}

[shader("fragment")]
Fragment_Output fragment_main(
	[[vk::location(0)]] float4 color: COLOR0,
	[[vk::location(1)]] float2 texcoord: TEXCOORD0,
	[[vk::location(2)]] float glyph: TEXCOORD1,
	[[vk::location(3)]] float4 effect: TEXCOORD2) {
	Fragment_Output output;
	if (glyph < -9.5) {
		output.color = ui_shader_output(texcoord, color, effect, glyph);
	} else if (glyph < -1.5) {
		float blur = max(effect.w, 0.0);
		float4 sample_color = ui_image_texture.Sample(ui_image_sampler, texcoord);
		if (blur > 0.0) {
			float2 step = float2(blur, blur);
			sample_color =
				ui_image_texture.Sample(ui_image_sampler, texcoord) * 0.36 +
				ui_image_texture.Sample(ui_image_sampler, texcoord + float2(step.x, 0.0)) * 0.12 +
				ui_image_texture.Sample(ui_image_sampler, texcoord - float2(step.x, 0.0)) * 0.12 +
				ui_image_texture.Sample(ui_image_sampler, texcoord + float2(0.0, step.y)) * 0.12 +
				ui_image_texture.Sample(ui_image_sampler, texcoord - float2(0.0, step.y)) * 0.12 +
				ui_image_texture.Sample(ui_image_sampler, texcoord + step) * 0.04 +
				ui_image_texture.Sample(ui_image_sampler, texcoord - step) * 0.04 +
				ui_image_texture.Sample(ui_image_sampler, texcoord + float2(step.x, -step.y)) * 0.04 +
				ui_image_texture.Sample(ui_image_sampler, texcoord + float2(-step.x, step.y)) * 0.04;
		}
		float brightness = (effect.x == 0.0) ? 1.0 : effect.x;
		float contrast = (effect.y == 0.0) ? 1.0 : effect.y;
		float grayscale = clamp(effect.z, 0.0, 1.0);
		sample_color.rgb *= brightness;
		sample_color.rgb = (sample_color.rgb - 0.5) * contrast + 0.5;
		float luma = dot(sample_color.rgb, float3(0.2126, 0.7152, 0.0722));
		sample_color.rgb = lerp(sample_color.rgb, float3(luma), grayscale);
		output.color = sample_color * color;
	} else {
		float alpha = (glyph >= 0.0) ? ui_image_texture.Sample(ui_image_sampler, texcoord).a : 1.0;
		output.color = float4(color.rgb, color.a * alpha);
	}
	return output;
}
