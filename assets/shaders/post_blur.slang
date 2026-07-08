struct Vertex_Output {
	float4 position: SV_Position;
	float2 uv: TEXCOORD0;
};

struct Post_Blur_Params {
	float radius;
	float sigma;
	float width;
	float height;
};

[[vk::binding(0, 0)]]
Texture2D<float4> source_texture;
[[vk::binding(1, 0)]]
SamplerState source_sampler;
[[vk::binding(2, 0)]]
ConstantBuffer<Post_Blur_Params> params;

[shader("vertex")]
Vertex_Output vertex_main(uint vertex_index: SV_VertexID) {
	float2 positions[6] = {
		float2(-1.0, -1.0),
		float2( 1.0, -1.0),
		float2(-1.0,  1.0),
		float2(-1.0,  1.0),
		float2( 1.0, -1.0),
		float2( 1.0,  1.0),
	};
	float2 uvs[6] = {
		float2(0.0, 1.0),
		float2(1.0, 1.0),
		float2(0.0, 0.0),
		float2(0.0, 0.0),
		float2(1.0, 1.0),
		float2(1.0, 0.0),
	};

	Vertex_Output output;
	output.position = float4(positions[vertex_index], 0.0, 1.0);
	output.uv = uvs[vertex_index];
	return output;
}

float gaussian_weight(float distance, float sigma) {
	float sigma_squared = max(sigma * sigma, 0.0001);
	return exp(-(distance * distance) / (2.0 * sigma_squared)) / sqrt(2.0 * 3.14159265 * sigma_squared);
}

[shader("fragment")]
float4 fragment_main(float2 uv: TEXCOORD0): SV_Target0 {
	int radius = int(clamp(params.radius, 0.0, 50.0));
	float sigma = clamp(params.sigma, 0.1, 10.0);
	float2 texel = 1.0 / max(float2(params.width, params.height), float2(1.0, 1.0));

	if (radius <= 0) {
		return source_texture.Sample(source_sampler, uv);
	}

	float4 color = float4(0.0, 0.0, 0.0, 0.0);
	float total_weight = 0.0;

	for (int i = -50; i <= 50; i++) {
		if (abs(i) > radius) {
			continue;
		}

		float weight = gaussian_weight(float(i), sigma);
		if (i == 0) {
			color += source_texture.Sample(source_sampler, uv) * weight;
			total_weight += weight;
		} else {
			float2 x_uv = clamp(uv + float2(float(i) * texel.x, 0.0), float2(0.0, 0.0), float2(1.0, 1.0));
			float2 y_uv = clamp(uv + float2(0.0, float(i) * texel.y), float2(0.0, 0.0), float2(1.0, 1.0));
			color += source_texture.Sample(source_sampler, x_uv) * weight;
			color += source_texture.Sample(source_sampler, y_uv) * weight;
			total_weight += weight * 2.0;
		}
	}

	return color / max(total_weight, 0.0001);
}
