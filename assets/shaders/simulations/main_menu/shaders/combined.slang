// Slang port of the original Vizza main menu background shader.
// Source: src-tauri/src/simulations/main_menu/shaders/combined.wgsl
//
// Kept as an unregistered shader asset for now. Expected bind groups match the
// original WGPU simulation:
//   set 0 / binding 0: f32 time uniform
//   set 1 / binding 0: planar 256-entry RGB LUT storage buffer

struct VertexOutput {
    float4 clip_position : SV_Position;
    float2 uv : TEXCOORD0;
};

[shader("vertex")]
VertexOutput vs_main(uint vertex_index : SV_VertexID) {
    var pos = float2[6](
        float2(-1.0, -1.0),
        float2(1.0, -1.0),
        float2(-1.0, 1.0),
        float2(-1.0, 1.0),
        float2(1.0, -1.0),
        float2(1.0, 1.0),
    );
    var uv = (pos[vertex_index] + float2(1.0, 1.0)) * 0.5;
    VertexOutput out;
    out.clip_position = float4(pos[vertex_index], 0.0, 1.0);
    out.uv = uv;
    return out;
}

[[vk::binding(0, 0)]]
ConstantBuffer<float> time;

[[vk::binding(0, 1)]]
StructuredBuffer<uint> lut_data;

// 3D Simplex noise implementation
float3 mod289_3(float3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float4 mod289_4(float4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float3 permute_3(float3 x) {
    return mod289_3(((x * 34.0) + 1.0) * x);
}

float4 permute_4(float4 x) {
    return mod289_4(((x * 34.0) + 1.0) * x);
}

float4 taylor_inv_sqrt(float4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

float simplex_noise_3d(float3 v) {
    let C = float2(1.0 / 6.0, 1.0 / 3.0);
    let D = float4(0.0, 0.5, 1.0, 2.0);

    // First corner
    let i = floor(v + dot(v, C.yyy));
    let x0 = v - i + dot(i, C.xxx);

    // Other corners
    let g = step(x0.yzx, x0.xyz);
    let l = 1.0 - g;
    let i1 = min(g.xyz, l.zxy);
    let i2 = max(g.xyz, l.zxy);

    let x1 = x0 - i1 + C.xxx;
    let x2 = x0 - i2 + C.yyy;
    let x3 = x0 - D.yyy;

    // Permutations
    let i_mod = mod289_3(i);
    let p = permute_4(permute_4(permute_4(
        i_mod.z + float4(0.0, i1.z, i2.z, 1.0)
    ) + i_mod.y + float4(0.0, i1.y, i2.y, 1.0)) + i_mod.x + float4(0.0, i1.x, i2.x, 1.0));

    let n_ = 0.142857142857;
    let ns = n_ * D.wyz - D.xzx;

    let j = p - 49.0 * floor(p * ns.z * ns.z);

    let x_ = floor(j * ns.z);
    let y_ = floor(j - 7.0 * x_);

    let x = x_ * ns.x + ns.yyyy;
    let y = y_ * ns.x + ns.yyyy;
    let h = 1.0 - abs(x) - abs(y);

    let b0 = float4(x.xy, y.xy);
    let b1 = float4(x.zw, y.zw);

    let s0 = floor(b0) * 2.0 + 1.0;
    let s1 = floor(b1) * 2.0 + 1.0;
    let sh = -step(h, float4(0.0));

    let a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    let a1 = b1.xzyw + s1.xzyw * sh.zzww;

    let p0 = float3(a0.xy, h.x);
    let p1 = float3(a0.zw, h.y);
    let p2 = float3(a1.xy, h.z);
    let p3 = float3(a1.zw, h.w);

    // Normalise gradients
    let norm = taylor_inv_sqrt(float4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    let p0_norm = p0 * norm.x;
    let p1_norm = p1 * norm.y;
    let p2_norm = p2 * norm.z;
    let p3_norm = p3 * norm.w;

    // Mix final noise value
    let m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), float4(0.0));
    let m_squared = m * m;
    return 42.0 * dot(m_squared, float4(dot(p0_norm, x0), dot(p1_norm, x1), dot(p2_norm, x2), dot(p3_norm, x3)));
}

// Multivariate FBM with more octaves and parameter variation
float multivariate_fbm(float3 p, float t) {
    var value = 0.0;
    var amplitude = 0.5;
    var frequency = 1.0;
    var sum = 0.0;
    for (var i = 0; i < 8; i = i + 1) {
        let offset = float3(
            sin(t * (0.3 + 0.1 * float(i))) * 2.0 * float(i),
            cos(t * (0.2 + 0.13 * float(i))) * 2.0 * float(i),
            t * (0.1 + 0.07 * float(i))
        );
        sum += amplitude * simplex_noise_3d(p * frequency + offset);
        frequency *= 1.85 + 0.15 * sin(t + float(i));
        amplitude *= 0.55 + 0.1 * cos(t * 0.5 + float(i));
    }
    return sum;
}

// Convert from sRGB (gamma-corrected) to linear RGB
float srgb_to_linear(float srgb) {
    if (srgb <= 0.04045) {
        return srgb / 12.92;
    } else {
        return pow((srgb + 0.055) / 1.055, 2.4);
    }
}

// LUT lookup function
float3 lookup_lut(float value) {
    let index = uint(value * 255.0);
    let r_srgb = float(lut_data[index]) / 255.0;
    let g_srgb = float(lut_data[256 + index]) / 255.0;
    let b_srgb = float(lut_data[512 + index]) / 255.0;
    
    return float3(
        srgb_to_linear(r_srgb),
        srgb_to_linear(g_srgb),
        srgb_to_linear(b_srgb)
    );
}

[shader("fragment")]
float4 fs_main(float2 uv : TEXCOORD0) : SV_Target0 {
    // Move the pole to the top of the screen (Y=1.0 is top in screen coordinates)
    let pole = float2(0.5, 0.7);
    let delta = uv - pole;
    let angle = atan2(delta.y, delta.x);
    let radius = length(delta);
    let swirl = sin(angle * 3.0 + time + radius * 4.0) * 0.5 + 0.5;

    // Multivariate FBM noise
    let pos_3d = float3(uv.x * 4.0, uv.y * 4.0, time * 0.5);
    let noise1 = multivariate_fbm(pos_3d, time);
    let noise2 = multivariate_fbm(pos_3d * 1.7 + float3(time * 0.3, time * 0.2, time * 0.4), time * 0.7);
    let noise3 = multivariate_fbm(pos_3d * 0.8 - float3(time * 0.2, time * 0.3, time * 0.1), time * 1.3);
    let combined_noise = (noise1 + noise2 + noise3) / 3.0;
    let animated_pattern = combined_noise * swirl;

    // Normalize the pattern to 0-1 range and apply LUT
    let normalized_value = (animated_pattern + 1.0) * 0.5; // Convert from [-1,1] to [0,1]
    let color = lookup_lut(normalized_value);

    // Pulsing
    let pulse = sin(time * 2.0) * 0.1 + 0.9;
    let final_color = color * pulse;

    // Vignette
    let vignette = 1.0 - length(uv - 0.5) * 0.8;
    let final_result = final_color * vignette;
    let vertical_from_bottom = 1.0 - saturate(uv.y);
    let gradient_midpoint = 0.66;
    let gradient_half_width = 0.25;
    let vertical_mix = smoothstep(gradient_midpoint - gradient_half_width, gradient_midpoint + gradient_half_width, vertical_from_bottom);

    return float4(final_result * vertical_mix, 1.0);
} 
