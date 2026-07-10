struct Fragment_Output {
	float4 color: SV_Target0;
};

struct Vertex_Output {
	float4 position: SV_Position;
	[[vk::location(0)]]
	float2 uv: TEXCOORD0;
};

struct PresentParams {
	uint lut_reversed;
	uint blur_enabled;
	float blur_radius;
	float blur_sigma;
	uint width;
	uint height;
	uint viewport_width;
	uint viewport_height;
	float camera_x;
	float camera_y;
	float camera_zoom;
	uint view_mode;
};

struct CameraUniform {
	float4x4 transform_matrix;
	float2 position;
	float zoom;
	float aspect_ratio;
};

[[vk::binding(0, 0)]]
Texture2D<float4> state_texture;

[[vk::binding(1, 0)]]
SamplerState state_sampler;

[[vk::binding(2, 0)]]
StructuredBuffer<uint> lut_data;

[[vk::binding(3, 0)]]
ConstantBuffer<PresentParams> present;

[[vk::binding(4, 0)]]
ConstantBuffer<CameraUniform> camera;

uint calculate_tile_count(float zoom) {
	float safe_zoom = max(zoom, 0.005);
	float visible_world_size = 2.0 / safe_zoom;
	uint tiles_needed = uint(ceil(visible_world_size / 2.0)) + 6u;
	uint min_tiles = safe_zoom < 0.1 ? 7u : 5u;
	return min(max(tiles_needed, min_tiles), 1024u);
}

int2 calculate_tile_start(float2 camera_pos, float zoom) {
	uint tile_count = calculate_tile_count(zoom);
	int2 tile_center = int2(
		int(round(camera_pos.x / 2.0)),
		int(round(camera_pos.y / 2.0))
	);
	int half_tiles = int(tile_count / 2u);
	return int2(tile_center.x - half_tiles, tile_center.y - half_tiles);
}

[shader("vertex")]
Vertex_Output vertex_main(uint vertex_index: SV_VertexID, uint instance_index: SV_InstanceID) {
	let pos = float2[6](
		float2(-1.0, -1.0),
		float2( 1.0, -1.0),
		float2(-1.0,  1.0),
		float2(-1.0,  1.0),
		float2( 1.0, -1.0),
		float2( 1.0,  1.0),
	);
	let uv = float2[6](
		float2(0.0, 1.0),
		float2(1.0, 1.0),
		float2(0.0, 0.0),
		float2(0.0, 0.0),
		float2(1.0, 1.0),
		float2(1.0, 0.0),
	);

	uint tile_count = calculate_tile_count(camera.zoom);
	int2 tile_start = calculate_tile_start(camera.position, camera.zoom);
	int grid_x = int(instance_index % tile_count) + tile_start.x;
	int grid_y = int(instance_index / tile_count) + tile_start.y;
	float2 world_pos = pos[vertex_index] + float2(float(grid_x), float(grid_y)) * 2.0;

	Vertex_Output output;
	output.position = mul(camera.transform_matrix, float4(world_pos, 0.0, 1.0));
	output.uv = uv[vertex_index];
	return output;
}

float4 sample_state(float2 uv) {
	return state_texture.SampleLevel(state_sampler, uv, 0.0);
}

float2 sample_fields_blurred(float2 uv) {
	if (present.blur_enabled == 0u || present.blur_radius <= 0.01) {
		return saturate(sample_state(uv).xy);
	}

	float2 texel = 1.0 / float2(max(present.width, 1u), max(present.height, 1u));
	int radius = int(clamp(present.blur_radius, 1.0, 50.0));
	float sigma = clamp(present.blur_sigma, 0.1, 10.0);
	float2 sum = float2(0.0, 0.0);
	float weight_sum = 0.0;
	for (int i = -50; i <= 50; i++) {
		if (abs(i) > radius) {
			continue;
		}

		float d2 = float(i * i);
		float w = exp(-d2 / (2.0 * sigma * sigma));
		if (i == 0) {
			sum += sample_state(uv).xy * w;
			weight_sum += w;
		} else {
			sum += sample_state(uv + float2(float(i), 0.0) * texel).xy * w;
			sum += sample_state(uv + float2(0.0, float(i)) * texel).xy * w;
			weight_sum += w * 2.0;
		}
	}
	return saturate(sum / max(weight_sum, 0.0001));
}

float srgb_to_linear(float srgb) {
	if (srgb <= 0.04045) {
		return srgb / 12.92;
	}
	return pow((srgb + 0.055) / 1.055, 2.4);
}

float3 lut_color(float t) {
	uint idx = uint(clamp(t * 255.0, 0.0, 255.0));
	float r = float(lut_data[idx]) / 255.0;
	float g = float(lut_data[idx + 256u]) / 255.0;
	float b = float(lut_data[idx + 512u]) / 255.0;
	return float3(srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b));
}

[shader("fragment")]
Fragment_Output fragment_main(Vertex_Output input) {
	Fragment_Output output;
	float2 fields = sample_fields_blurred(input.uv);
	float value = fields.x;
	if (present.view_mode == 1u) {
		value = fields.y;
	} else if (present.view_mode == 2u) {
		value = 0.5 + 0.5 * (fields.x - fields.y);
	} else if (present.view_mode == 3u) {
		// Square-root exposure reveals low reaction activity without an arbitrary
		// multiplier that clips high activity.
		value = sqrt(saturate(fields.x * fields.y * fields.y));
	}
	output.color = float4(lut_color(saturate(value)), 1.0);
	return output;
}
