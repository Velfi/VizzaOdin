// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/primordial_particles/shaders/particle_render.wgsl

static const float PI = 3.14159265359;

struct Particle {
	float2 position;
	float2 previous_position;
	float heading;
	float velocity;
	float density;
	uint grabbed;
};

struct RenderParams {
	float particle_size;
	float screen_width;
	float screen_height;
	uint foreground_color_mode;
};

struct VertexOutput {
	float4 position : SV_Position;
	nointerpolation float3 color : TEXCOORD0;
	float2 uv : TEXCOORD1;
};

[[vk::binding(0, 0)]]
StructuredBuffer<Particle> particles;

[[vk::binding(1, 0)]]
ConstantBuffer<RenderParams> render_params;

[[vk::binding(2, 0)]]
StructuredBuffer<uint> lut;

float srgb_to_linear(float srgb) {
	if (srgb <= 0.04045) {
		return srgb / 12.92;
	}
	return pow((srgb + 0.055) / 1.055, 2.4);
}

float3 get_lut_color(float intensity) {
	let index = uint(clamp(intensity * 255.0, 0.0, 255.0));
	let r_srgb = float(lut[index]) / 255.0;
	let g_srgb = float(lut[index + 256]) / 255.0;
	let b_srgb = float(lut[index + 512]) / 255.0;
	return float3(srgb_to_linear(r_srgb), srgb_to_linear(g_srgb), srgb_to_linear(b_srgb));
}

float3 get_particle_color(Particle particle, uint particle_index) {
	switch (render_params.foreground_color_mode) {
		case 0: {
			return get_lut_color(float(particle_index) / 10000.0);
		}
		case 1: {
			return get_lut_color(clamp(particle.density / 16.0, 0.0, 1.0));
		}
		case 2: {
			return get_lut_color(frac(particle.heading / (2.0 * PI)));
		}
		case 3: {
			return get_lut_color(clamp(particle.velocity / 1.0, 0.0, 1.0));
		}
		default: {
			return get_lut_color(frac(particle.heading / (2.0 * PI)));
		}
	}
}

[shader("vertex")]
VertexOutput vs_main(uint vertex_index : SV_VertexID, uint instance_index : SV_InstanceID) {
	let particle = particles[instance_index];

	let quad_positions = float2[6](
		float2(-1.0, -1.0),
		float2( 1.0, -1.0),
		float2(-1.0,  1.0),
		float2(-1.0,  1.0),
		float2( 1.0, -1.0),
		float2( 1.0,  1.0)
	);

	let quad_uvs = float2[6](
		float2(0.0, 0.0),
		float2(1.0, 0.0),
		float2(0.0, 1.0),
		float2(0.0, 1.0),
		float2(1.0, 0.0),
		float2(1.0, 1.0)
	);

	let quad_pos = quad_positions[vertex_index];
	let quad_uv = quad_uvs[vertex_index];
	let aspect = max(render_params.screen_width / max(render_params.screen_height, 1.0), 0.0001);
	let size = render_params.particle_size;
	let offset = float2((quad_pos.x * size) / aspect, quad_pos.y * size);
	let final_pos = particle.position + offset;

	VertexOutput output;
	output.position = float4(final_pos, 0.0, 1.0);
	output.color = get_particle_color(particle, instance_index);
	output.uv = quad_uv;
	return output;
}

[shader("fragment")]
float4 fs_main(
	nointerpolation float3 color : TEXCOORD0,
	float2 uv : TEXCOORD1
) : SV_Target0 {
	let centered = uv - float2(0.5, 0.5);
	if (length(centered) > 0.45) {
		discard;
	}
	return float4(color, 1.0);
}
