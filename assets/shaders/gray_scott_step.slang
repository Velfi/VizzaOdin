struct GrayScottParams {
	float feed;
	float kill;
	float diffusion_a;
	float diffusion_b;
	float timestep;
	uint width;
	uint height;
	uint mode;
	uint seed;
	uint frame_index;
	uint mask_pattern;
	uint mask_target;
	float mask_strength;
	uint mask_mirror_horizontal;
	uint mask_mirror_vertical;
	uint mask_invert_tone;
	float max_timestep;
	float stability_factor;
	uint enable_adaptive_timestep;
	float cursor_x;
	float cursor_y;
	float cursor_size;
	float cursor_strength;
	uint mouse_button;
	uint _pad0;
	uint _pad1;
	uint _pad2;
};

[[vk::binding(0, 0)]]
RWTexture2D<float4> state_next;

[[vk::binding(1, 0)]]
RWTexture2D<float4> state_current;

[[vk::binding(2, 0)]]
ConstantBuffer<GrayScottParams> params;

[[vk::binding(3, 0)]]
StructuredBuffer<float> nutrient_map;

uint hash_u32(uint x) {
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = (x >> 16u) ^ x;
	return x;
}

float random_float(uint seed) {
	return float(hash_u32(seed)) / 4294967295.0;
}

float noise2d(uint x, uint y, uint seed) {
	return random_float(x * 73856093u + y * 19349663u + seed);
}

float fbm_noise(uint2 p, uint seed) {
	float result = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	for (uint i = 0; i < 4; i++) {
		uint2 q = uint2(float2(p) * frequency);
		result += noise2d(q.x, q.y, seed + i) * amplitude;
		frequency *= 2.0;
		amplitude *= 0.5;
	}
	return result;
}

float2 load_wrapped(int2 p) {
	int width = int(params.width);
	int height = int(params.height);
	p.x = (p.x + width) % width;
	p.y = (p.y + height) % height;
	return state_current.Load(p).xy;
}

float2 laplacian_5(int2 p) {
	float2 center = load_wrapped(p);
	float2 value = center * -4.0;
	value += load_wrapped(p + int2(-1,  0));
	value += load_wrapped(p + int2( 1,  0));
	value += load_wrapped(p + int2( 0, -1));
	value += load_wrapped(p + int2( 0,  1));
	return value;
}

float mask_factor(int2 p) {
	float2 original = float2(p) / float2(max(params.width, 1u), max(params.height, 1u));
	float result = 1.0;

	switch (params.mask_pattern) {
	case 0u:
		result = 1.0;
		break;
	case 1u: {
		uint bx = uint(p.x) / 200u;
		uint by = uint(p.y) / 200u;
		result = ((bx + by) % 2u) == 0u ? 1.0 : 0.0;
		break;
	}
	case 2u: {
		float2 q = original;
		if (params.mask_mirror_horizontal != 0u) q.x = 1.0 - q.x;
		if (params.mask_mirror_vertical != 0u) q.y = 1.0 - q.y;
		result = (q.x + q.y) * 0.5;
		break;
	}
	case 3u: {
		float2 q = original;
		if (params.mask_mirror_horizontal != 0u) q.x = 1.0 - q.x;
		if (params.mask_mirror_vertical != 0u) q.y = 1.0 - q.y;
		result = 1.0 - distance(q, float2(0.5, 0.5));
		break;
	}
	case 4u: {
		float x = params.mask_mirror_horizontal != 0u ? 1.0 - original.x : original.x;
		result = (x / 0.1) % 2.0 < 1.0 ? 1.0 : 0.0;
		break;
	}
	case 5u: {
		float y = params.mask_mirror_vertical != 0u ? 1.0 - original.y : original.y;
		result = (y / 0.1) % 2.0 < 1.0 ? 1.0 : 0.0;
		break;
	}
	case 6u: {
		float2 q = original;
		if (params.mask_mirror_horizontal != 0u) q.x = 1.0 - q.x;
		if (params.mask_mirror_vertical != 0u) q.y = 1.0 - q.y;
		float2 n = q * 4.0 - 2.0;
		float wave = n.x * exp(-(n.x * n.x + n.y * n.y));
		result = (wave + 0.43) / 0.86;
		break;
	}
	case 7u: {
		float2 q = original;
		if (params.mask_mirror_horizontal != 0u) q.x = 1.0 - q.x;
		if (params.mask_mirror_vertical != 0u) q.y = 1.0 - q.y;
		float x_scaled = q.x * 18.85;
		float y_scaled = q.y * 12.566;
		float pattern1 = cos(x_scaled + cos(y_scaled * 0.5));
		float pattern2 = cos(y_scaled + sin(x_scaled * 0.3));
		float raw = -(pattern1 * pattern2 * pattern1 * pattern2) * cos(x_scaled * 0.5);
		result = (tanh(raw) + 1.0) * 0.5;
		break;
	}
	case 8u: {
		uint x = uint(p.x);
		uint y = uint(p.y);
		if (params.mask_mirror_horizontal != 0u) x = params.width - 1u - x;
		if (params.mask_mirror_vertical != 0u) y = params.height - 1u - y;
		result = nutrient_map[y * params.width + x];
		break;
	}
	default:
		result = 1.0;
		break;
	}

	result = clamp(result, 0.0, 1.0);
	if (params.mask_invert_tone != 0u) {
		result = 1.0 - result;
	}
	return result;
}

float4 clear_state() {
	return float4(1.0, 0.0, 0.0, 0.0);
}

float4 initial_seed(uint2 tid) {
	float2 size = float2(float(params.width), float(params.height));
	float2 p = float2(tid);
	float radius = max(min(size.x, size.y) * 0.055, 10.0);
	float d = distance(p, size * 0.5) / radius;
	float factor = d < 1.0 ? pow(1.0 - d * d, 2.0) : 0.0;
	return float4(lerp(1.0, 0.5, factor), 0.99 * factor, 0.0, 0.0);
}

float4 noise_seed(uint2 tid) {
	float n = fbm_noise(tid, params.seed);
	// Perturb the homogeneous equilibrium instead of replacing rare pixels with
	// near-saturated V. The centered envelope still gives noise enough contrast
	// to nucleate patterns without starting outside the usual Gray-Scott regime.
	float v = saturate((n - 0.35) * 0.35);
	return float4(1.0 - v * 0.5, v, 0.0, 0.0);
}

float4 paint_state(uint2 tid) {
	float2 current = state_current.Load(int2(tid)).xy;
	float2 mouse = float2(params.cursor_x, params.cursor_y) * float2(float(params.width), float(params.height));
	float radius_px = max(params.cursor_size * min(float(params.width), float(params.height)) * 0.5, 1.0);
	float d = distance(float2(tid), mouse);
	if (d > radius_px) {
		return float4(current, 0.0, 0.0);
	}
	float factor = 1.0 - d / radius_px;
	if (factor < 0.01) {
		return float4(current, 0.0, 0.0);
	}
	float strength = factor * params.cursor_strength;
	float2 next = current;
	if (params.mouse_button == 2u) {
		next.x = lerp(current.x, 1.0, strength);
		next.y = lerp(current.y, 0.0, strength);
	} else if (params.mouse_button == 0u) {
		// A conventional seed consumes U while introducing V.
		next.x = lerp(current.x, 0.5, strength);
		next.y = lerp(current.y, 0.25, strength);
	}
	return float4(next, 0.0, 0.0);
}

[shader("compute")]
[numthreads(8, 8, 1)]
void main(uint3 tid: SV_DispatchThreadID) {
	if (tid.x >= params.width || tid.y >= params.height) {
		return;
	}

	uint2 pixel = tid.xy;
	int2 p = int2(pixel);

	if (params.mode == 0u) {
		state_next[pixel] = clear_state();
		return;
	}
	if (params.mode == 2u) {
		state_next[pixel] = initial_seed(pixel);
		return;
	}
	if (params.mode == 3u) {
		state_next[pixel] = noise_seed(pixel);
		return;
	}
	if (params.mode == 4u) {
		state_next[pixel] = paint_state(pixel);
		return;
	}

	float2 uv = load_wrapped(p);
	float2 lap = laplacian_5(p);
	float reaction = uv.x * uv.y * uv.y;
	float mask = mask_factor(p);
	float modulation = lerp(1.0, mask, saturate(params.mask_strength));

	float feed = params.feed;
	float kill = params.kill;
	float diffusion_a = params.diffusion_a;
	float diffusion_b = params.diffusion_b;
	if (params.mask_pattern != 0u) {
	switch (params.mask_target) {
	case 1u:
		feed = params.feed * modulation;
		break;
	case 2u:
		kill = params.kill * modulation;
		break;
	case 3u:
		diffusion_a = params.diffusion_a * modulation;
		break;
	case 4u:
		diffusion_b = params.diffusion_b * modulation;
		break;
	case 5u:
		reaction *= modulation;
		break;
	default:
		break;
	}
	}

	// Subdivision and stability are handled once, on the CPU.
	float dt = params.timestep;
	float du = diffusion_a * lap.x - reaction + feed * (1.0 - uv.x);
	float dv = diffusion_b * lap.y + reaction - (kill + feed) * uv.y;
	uv += float2(du, dv) * dt;
	uv = clamp(uv, float2(0.0, 0.0), float2(1.0, 1.0));

	state_next[pixel] = float4(uv.x, uv.y, 0.0, 0.0);
}
