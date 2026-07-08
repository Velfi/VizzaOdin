static const float NOISE_PI = 3.14159265358979323846;
static const float NOISE_TAU = 6.28318530717958647692;

struct NoiseParams {
    uint kind;
    uint fractal_mode;
    uint seed;
    float offset_x;
    float offset_y;
    float rotation;
    float anchor_x;
    float anchor_y;
    float strength;
    float amplitude;
    float frequency;
    uint octaves;
    float lacunarity;
    float gain;
    uint warp_mode;
    uint warp_octaves;
    float warp_amplitude;
    float warp_frequency;
    uint gabor_iterations;
    float gabor_velocity;
    float gabor_band_width;
    float gabor_band_softness;
    uint phasor_iterations;
    float phasor_velocity;
    float phasor_band_width;
    uint voronoi_output;
    uint voronoi_distance_mode;
    float wave_velocity;
    float wave_band_width;
    float wave_band_softness;
};

uint noise_hash(uint seed) {
    var x = seed;
    x = ((x >> 16) ^ x) * 0x45d9f3bu;
    x = ((x >> 16) ^ x) * 0x45d9f3bu;
    x = (x >> 16) ^ x;
    return x;
}

uint noise_hash_coords(int x, int y, uint seed) {
    return noise_hash(uint(x) * 73856093u + uint(y) * 19349663u + seed);
}

float noise_hash01(uint seed) {
    return float(noise_hash(seed)) / float(0xffffffffu);
}

float noise_hash_signed(uint seed) {
    return noise_hash01(seed) * 2.0 - 1.0;
}

float noise_fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float noise_grad2(uint h, float x, float y) {
    switch (h & 7u) {
        case 0u: return x + y;
        case 1u: return -x + y;
        case 2u: return x - y;
        case 3u: return -x - y;
        case 4u: return x;
        case 5u: return -x;
        case 6u: return y;
        default: return -y;
    }
}

float noise_perlin_2d(float2 p, uint seed) {
    let ip = int2(floor(p));
    let f = p - float2(ip);
    let u = float2(noise_fade(f.x), noise_fade(f.y));
    let n00 = noise_grad2(noise_hash_coords(ip.x, ip.y, seed), f.x, f.y);
    let n10 = noise_grad2(noise_hash_coords(ip.x + 1, ip.y, seed), f.x - 1.0, f.y);
    let n01 = noise_grad2(noise_hash_coords(ip.x, ip.y + 1, seed), f.x, f.y - 1.0);
    let n11 = noise_grad2(noise_hash_coords(ip.x + 1, ip.y + 1, seed), f.x - 1.0, f.y - 1.0);
    return clamp(lerp(lerp(n00, n10, u.x), lerp(n01, n11, u.x), u.y) * 0.70710678, -1.0, 1.0);
}

float noise_value_2d(float2 p, uint seed) {
    let ip = int2(floor(p));
    let f = p - float2(ip);
    let u = float2(noise_fade(f.x), noise_fade(f.y));
    let n00 = noise_hash_signed(noise_hash_coords(ip.x, ip.y, seed));
    let n10 = noise_hash_signed(noise_hash_coords(ip.x + 1, ip.y, seed));
    let n01 = noise_hash_signed(noise_hash_coords(ip.x, ip.y + 1, seed));
    let n11 = noise_hash_signed(noise_hash_coords(ip.x + 1, ip.y + 1, seed));
    return lerp(lerp(n00, n10, u.x), lerp(n01, n11, u.x), u.y);
}

float noise_white_2d(float2 p, uint seed) {
    let ip = int2(floor(p));
    return noise_hash_signed(noise_hash_coords(ip.x, ip.y, seed));
}

float2 noise_gradient_unit(uint h) {
    let angle = noise_hash01(h) * NOISE_TAU;
    return float2(cos(angle), sin(angle));
}

float noise_simplex_2d(float2 p, uint seed) {
    let f2 = 0.3660254037844386;
    let g2 = 0.2113248654051871;
    let s = (p.x + p.y) * f2;
    let i = floor(p + float2(s, s));
    let t = (i.x + i.y) * g2;
    let x0 = p - (i - float2(t, t));
    let i1 = x0.x > x0.y ? float2(1.0, 0.0) : float2(0.0, 1.0);
    let x1 = x0 - i1 + float2(g2, g2);
    let x2 = x0 - float2(1.0, 1.0) + float2(2.0 * g2, 2.0 * g2);
    let ii = int2(i);

    var n0 = 0.0;
    var n1 = 0.0;
    var n2 = 0.0;
    var m0 = 0.5 - dot(x0, x0);
    if (m0 > 0.0) {
        m0 *= m0;
        n0 = m0 * m0 * dot(noise_gradient_unit(noise_hash_coords(ii.x, ii.y, seed)), x0);
    }
    var m1 = 0.5 - dot(x1, x1);
    if (m1 > 0.0) {
        m1 *= m1;
        n1 = m1 * m1 * dot(noise_gradient_unit(noise_hash_coords(ii.x + int(i1.x), ii.y + int(i1.y), seed)), x1);
    }
    var m2 = 0.5 - dot(x2, x2);
    if (m2 > 0.0) {
        m2 *= m2;
        n2 = m2 * m2 * dot(noise_gradient_unit(noise_hash_coords(ii.x + 1, ii.y + 1, seed)), x2);
    }
    return clamp(70.0 * (n0 + n1 + n2), -1.0, 1.0);
}

float noise_voronoi_distance(float2 d, uint mode) {
    if (mode == 1u) {
        return abs(d.x) + abs(d.y);
    }
    if (mode == 2u) {
        return max(abs(d.x), abs(d.y));
    }
    return length(d);
}

float noise_voronoi_2d(NoiseParams params, float2 p, uint seed) {
    let cell = int2(floor(p));
    var f1 = 1.0e9;
    var f2 = 1.0e9;
    var win_hash = 0u;
    for (var oy = -1; oy <= 1; oy = oy + 1) {
        for (var ox = -1; ox <= 1; ox = ox + 1) {
            let c = cell + int2(ox, oy);
            let h = noise_hash_coords(c.x, c.y, seed);
            let fp = float2(float(c.x) + noise_hash01(h), float(c.y) + noise_hash01(h + 1013u));
            let d = noise_voronoi_distance(p - fp, params.voronoi_distance_mode);
            if (d < f1) {
                f2 = f1;
                f1 = d;
                win_hash = h;
            } else if (d < f2) {
                f2 = d;
            }
        }
    }
    if (params.voronoi_output == 1u) return clamp(1.0 - f2, -1.0, 1.0);
    if (params.voronoi_output == 2u) return clamp((f2 - f1) * 2.0 - 1.0, -1.0, 1.0);
    if (params.voronoi_output == 3u) return noise_hash_signed(win_hash);
    if (params.voronoi_output == 4u) return clamp(1.0 - (f2 - f1) * 8.0, -1.0, 1.0);
    return clamp(1.0 - f1 * 2.0, -1.0, 1.0);
}

float noise_wave_2d(NoiseParams params, float2 p, float time, uint seed) {
    var angle = params.rotation;
    if (abs(angle) < 0.000001) {
        angle = noise_hash01(seed + 71u) * NOISE_TAU;
    }
    let dir = float2(cos(angle), sin(angle));
    let width = max(params.wave_band_width, 0.0001);
    var v = sin(dot(p, dir) * NOISE_TAU / width + noise_hash01(seed + 131u) * NOISE_TAU + time * params.wave_velocity);
    if (abs(params.wave_band_softness - 1.0) > 0.0001) {
        v = sign(v) * pow(abs(v), max(params.wave_band_softness, 0.0001));
    }
    return v;
}

float noise_gabor_2d(NoiseParams params, float2 p, float time, uint seed) {
    let iterations = min(max(params.gabor_iterations, 1u), 96u);
    var sum = 0.0;
    let width = max(params.gabor_band_width, 0.0001);
    let softness = max(params.gabor_band_softness, 0.0001);
    for (var i = 0u; i < iterations; i = i + 1u) {
        let h = noise_hash(seed + i * 374761393u);
        let c = float2(noise_hash_signed(h), noise_hash_signed(h + 1013u)) * 6.0;
        let angle = noise_hash01(h + 2027u) * NOISE_TAU;
        let dir = float2(cos(angle), sin(angle));
        let d = p - c;
        let envelope = exp(-dot(d, d) * softness);
        let carrier = cos(dot(d, dir) * NOISE_TAU / width + time * params.gabor_velocity + noise_hash01(h + 3037u) * NOISE_TAU);
        sum += envelope * carrier;
    }
    return clamp(sum / sqrt(float(iterations)), -1.0, 1.0);
}

float noise_phasor_2d(NoiseParams params, float2 p, float time, uint seed) {
    let iterations = min(max(params.phasor_iterations, 1u), 96u);
    var acc = float2(0.0);
    let width = max(params.phasor_band_width, 0.0001);
    for (var i = 0u; i < iterations; i = i + 1u) {
        let h = noise_hash(seed + i * 668265263u);
        let angle = noise_hash01(h) * NOISE_TAU;
        let dir = float2(cos(angle), sin(angle));
        let phase = dot(p, dir) * NOISE_TAU / width + time * params.phasor_velocity + noise_hash01(h + 1013u) * NOISE_TAU;
        let weight = 0.5 + 0.5 * noise_hash01(h + 2027u);
        acc += float2(cos(phase), sin(phase)) * weight;
    }
    return atan2(acc.y, acc.x) / NOISE_PI;
}

float noise_cylinders_2d(NoiseParams params, float2 p, float time) {
    return sin(length(p - float2(params.anchor_x, params.anchor_y)) * NOISE_TAU + time);
}

float noise_checkerboard_2d(float2 p) {
    let ip = int2(floor(p));
    return (((ip.x ^ ip.y) & 1) == 0) ? -1.0 : 1.0;
}

float2 noise_transform_position(NoiseParams params, float2 p) {
    let q = (p - float2(params.anchor_x, params.anchor_y)) * max(params.frequency, 0.000001);
    let c = cos(params.rotation);
    let s = sin(params.rotation);
    return float2(q.x * c - q.y * s, q.x * s + q.y * c) + float2(params.anchor_x + params.offset_x, params.anchor_y + params.offset_y);
}

float2 noise_apply_domain_warp(NoiseParams params, float2 p, float time) {
    if (params.warp_mode == 0u || params.warp_amplitude == 0.0) return p;
    var out_p = p;
    var source = p;
    var frequency = max(params.warp_frequency, 0.000001);
    var amplitude = params.warp_amplitude;
    let octaves = min(max(params.warp_octaves, 1u), 8u);
    for (var i = 0u; i < octaves; i = i + 1u) {
        let wx = noise_perlin_2d(source * frequency + float2(17.0, time), params.seed + i * 17u + 1013u);
        let wy = noise_perlin_2d(source * frequency + float2(-time, -31.0), params.seed + i * 17u + 2027u);
        out_p += float2(wx, wy) * amplitude;
        if (params.warp_mode == 2u) source = out_p;
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return out_p;
}

float noise_sample_kind_2d(NoiseParams params, float2 p, float time, uint seed) {
    switch (params.kind) {
        case 0u: return abs(noise_simplex_2d(p + float2(0.0, time * 0.1), seed)) * 2.0 - 1.0; // Billow
        case 1u: return noise_gabor_2d(params, p, time, seed);
        case 2u: return noise_perlin_2d(p + float2(0.0, time * 0.1), seed);
        case 3u: return noise_phasor_2d(params, p, time, seed);
        case 4u: return 1.0 - abs(noise_simplex_2d(p + float2(0.0, time * 0.1), seed)) * 2.0; // Ridged
        case 5u: return noise_simplex_2d(p + float2(0.0, time * 0.1), seed);
        case 6u: return noise_value_2d(p + float2(0.0, time * 0.1), seed);
        case 7u: return noise_voronoi_2d(params, p, seed);
        case 8u: return noise_wave_2d(params, p, time, seed);
        case 9u: return noise_white_2d(p + float2(0.0, time * 0.1), seed);
        case 10u: return noise_cylinders_2d(params, p, time);
        case 11u: return noise_checkerboard_2d(p);
        default: return noise_simplex_2d(p, seed);
    }
}

float noise_sample_fractal_2d(NoiseParams params, float2 p, float time) {
    var sum = 0.0;
    var amp = 1.0;
    var amp_sum = 0.0;
    var freq = 1.0;
    let octaves = min(max(params.octaves, 1u), 12u);
    for (var i = 0u; i < octaves; i = i + 1u) {
        var n = noise_sample_kind_2d(params, p * freq, time * freq, params.seed + i * 1009u);
        if (params.fractal_mode == 2u) {
            n = (1.0 - abs(n)) * 2.0 - 1.0;
        }
        sum += n * amp;
        amp_sum += amp;
        freq *= max(params.lacunarity, 0.000001);
        amp *= clamp(params.gain, 0.0, 1.0);
    }
    return amp_sum > 0.0 ? clamp(sum / amp_sum, -1.0, 1.0) : 0.0;
}

float noise_sample_2d(NoiseParams params, float2 p, float time) {
    let q = noise_apply_domain_warp(params, noise_transform_position(params, p), time);
    let v = params.fractal_mode == 0u
        ? noise_sample_kind_2d(params, q, time, params.seed)
        : noise_sample_fractal_2d(params, q, time);
    return clamp(v * params.amplitude * params.strength, -1.0, 1.0);
}
