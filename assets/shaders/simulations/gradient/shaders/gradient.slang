// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/gradient/shaders/gradient.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

struct VertexInput {

    float2 position : TEXCOORD0;
    float2 uv : TEXCOORD1;
};

struct VertexOutput {

    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};
[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    return VertexOutput(
        float4(input.position, 0.0, 1.0),
        input.uv,
    );
}

// LUT buffer - contains 256 RGB values in planar format [r0..r255, g0..g255, b0..b255]
[[vk::binding(0, 0)]]
StructuredBuffer<uint> lut;

// Parameters uniform buffer
struct GradientParams {

    uint display_mode; // 0 = smooth, 1 = dithered
    uint _pad1;
    uint _pad2;
    uint _pad3;
};

[[vk::binding(1, 0)]]
ConstantBuffer<GradientParams> params;

// Color space interpolation functions
float rgb_to_linear(float rgb) {
    let normalized = rgb / 255.0;
    return normalized <= 0.04045
        ? (normalized / 12.92)
        : pow((normalized + 0.055) / 1.055, 2.4);
}

float linear_to_rgb(float linear) {
    let result = linear <= 0.0031308
        ? (linear * 12.92)
        : 1.055 * pow(linear, 1.0 / 2.4) - 0.055;
    return clamp(result * 255.0, 0.0, 255.0);
}

float3 linear_rgb_to_xyz(float r, float g, float b) {
    let x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375;
    let y = r * 0.2126729 + g * 0.7151522 + b * 0.072175;
    let z = r * 0.0193339 + g * 0.119192 + b * 0.9503041;
    return float3(x, y, z);
}

float3 xyz_to_linear_rgb(float x, float y, float z) {
    let r = x * 3.2404542 + y * -1.5371385 + z * -0.4985314;
    let g = x * -0.969266 + y * 1.8760108 + z * 0.041556;
    let b = x * 0.0556434 + y * -0.2040259 + z * 1.0572252;
    return float3(r, g, b);
}

float3 xyz_to_lab(float x, float y, float z) {
    // D65 white point
    let xn = 0.95047;
    let yn = 1.0;
    let zn = 1.08883;

    let xr = x / xn;
    let yr = y / yn;
    let zr = z / zn;

    let fx = xr > 0.008856 ? pow(xr, 1.0 / 3.0) : (7.787 * xr + 16.0 / 116.0);
    let fy = yr > 0.008856 ? pow(yr, 1.0 / 3.0) : (7.787 * yr + 16.0 / 116.0);
    let fz = zr > 0.008856 ? pow(zr, 1.0 / 3.0) : (7.787 * zr + 16.0 / 116.0);

    let L = (116.0 * fy) - 16.0;
    let a = 500.0 * (fx - fy);
    let b = 200.0 * (fy - fz);

    return float3(L, a, b);
}

float3 lab_to_xyz(float L, float a, float b) {
    // D65 white point
    let xn = 0.95047;
    let yn = 1.0;
    let zn = 1.08883;

    let fy = (L + 16.0) / 116.0;
    let fx = a / 500.0 + fy;
    let fz = fy - b / 200.0;

    let xr = fx > 0.206897 ? pow(fx, 3.0) : (fx - 16.0 / 116.0) / 7.787;
    let yr = fy > 0.206897 ? pow(fy, 3.0) : (fy - 16.0 / 116.0) / 7.787;
    let zr = fz > 0.206897 ? pow(fz, 3.0) : (fz - 16.0 / 116.0) / 7.787;

    let x = xr * xn;
    let y = yr * yn;
    let z = zr * zn;

    return float3(x, y, z);
}

float3 xyz_to_oklab(float x, float y, float z) {
    let l = 0.8189330101 * x + 0.3618667424 * y - 0.1288597137 * z;
    let m = 0.0329845436 * x + 0.9293118715 * y + 0.0361456387 * z;
    let s = 0.0482003018 * x + 0.2643662691 * y + 0.6338517070 * z;

    let l_ = pow(l, 1.0/3.0);
    let m_ = pow(m, 1.0/3.0);
    let s_ = pow(s, 1.0/3.0);

    let L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_;
    let a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_;
    let b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_;

    return float3(L, a, b);
}

float3 oklab_to_xyz(float L, float a, float b) {
    let l_ = L + 0.3963377774 * a + 0.2158037573 * b;
    let m_ = L - 0.1055613458 * a - 0.0638541728 * b;
    let s_ = L - 0.0894841775 * a - 1.291485548 * b;

    let l = l_ * l_ * l_;
    let m = m_ * m_ * m_;
    let s = s_ * s_ * s_;

    let x = 1.2268798733 * l - 0.5578149965 * m + 0.2813910456 * s;
    let y = -0.0405801784 * l + 1.1122568696 * m - 0.0716766787 * s;
    let z = -0.0763812845 * l - 0.4214819784 * m + 1.5861632204 * s;

    return float3(x, y, z);
}

float3 sample_lut(float index) {
    // Bilinear interpolation for smooth gradient
    let scaled_index = clamp(index * 255.0, 0.0, 255.0);
    let idx0 = uint(floor(scaled_index));
    let idx1 = min(idx0 + 1, 255);
    let t = scaled_index - float(idx0);
    
    // Sample colors at both indices (keep in sRGB for display)
    let color0 = float3(
        float(lut[idx0]),
        float(lut[idx0 + 256]),
        float(lut[idx0 + 512])
    );
    let color1 = float3(
        float(lut[idx1]),
        float(lut[idx1 + 256]),
        float(lut[idx1 + 512])
    );
    
    // Linear interpolation between the two colors
    return lerp(color0, color1, t);
}

// 16x16 Bayer matrix for very fine ordered dithering
float bayer_dither(float2 uv) {
    let x = uint(frac(uv.x * 16.0) * 16.0);
    let y = uint(frac(uv.y * 16.0) * 16.0);
    
    // 16x16 Bayer matrix for very fine dithering
    let bayer_matrix = uint[256](
        0, 128, 32, 160, 8, 136, 40, 168, 2, 130, 34, 162, 10, 138, 42, 170,
        192, 64, 224, 96, 200, 72, 232, 104, 194, 66, 226, 98, 202, 74, 234, 106,
        48, 176, 16, 144, 56, 184, 24, 152, 50, 178, 18, 146, 58, 186, 26, 154,
        240, 112, 208, 80, 248, 120, 216, 88, 242, 114, 210, 82, 250, 122, 218, 90,
        12, 140, 44, 172, 4, 132, 36, 164, 14, 142, 46, 174, 6, 134, 38, 166,
        204, 76, 236, 108, 196, 68, 228, 100, 206, 78, 238, 110, 198, 70, 230, 102,
        60, 188, 28, 156, 52, 180, 20, 148, 62, 190, 30, 158, 54, 182, 22, 150,
        252, 124, 220, 92, 244, 116, 212, 84, 254, 126, 222, 94, 246, 118, 214, 86,
        3, 131, 35, 163, 11, 139, 43, 171, 1, 129, 33, 161, 9, 137, 41, 169,
        195, 67, 227, 99, 203, 75, 235, 107, 193, 65, 225, 97, 201, 73, 233, 105,
        51, 179, 19, 147, 59, 187, 27, 155, 49, 177, 17, 145, 57, 185, 25, 153,
        243, 115, 211, 83, 251, 123, 219, 91, 241, 113, 209, 81, 249, 121, 217, 89,
        15, 143, 47, 175, 7, 135, 39, 167, 13, 141, 45, 173, 5, 133, 37, 165,
        207, 79, 239, 111, 199, 71, 231, 103, 205, 77, 237, 109, 197, 69, 229, 101,
        63, 191, 31, 159, 55, 183, 23, 151, 61, 189, 29, 157, 53, 181, 21, 149,
        255, 127, 223, 95, 247, 119, 215, 87, 253, 125, 221, 93, 245, 117, 213, 85
    );
    
    let index = y * 16 + x;
    return float(bayer_matrix[index]) / 256.0;
}

// Quantize color to limited palette (Amiga-style)
float3 quantize_color(float3 color) {
    // Quantize to 16 levels (4 bits per channel) for more pixelated look
    let levels = 16.0;
    let step = 255.0 / (levels - 1.0);
    
    return float3(
        round(color.x / step) * step,
        round(color.y / step) * step,
        round(color.z / step) * step
    );
}

// Apply display mode effects to color
float3 apply_display_mode(float3 color, float2 uv) {
    if (params.display_mode == 0) {
        // Smooth mode - no modification
        return color;
    } else if (params.display_mode == 1) {
        // Dithered mode - Amiga-style ordered dithering
        
        // Get dither threshold from Bayer matrix
        let dither_threshold = bayer_dither(uv);
        
        // Quantize the color first
        let quantized = quantize_color(color);
        
        // Apply dithering by comparing each channel to the threshold
        let step_size = 255.0 / 15.0; // Step size for 16 levels
        let dithered = float3(
            ((color.x > quantized.x + (dither_threshold * step_size) ? (quantized.x + step_size) : (quantized.x))),
            ((color.y > quantized.y + (dither_threshold * step_size) ? (quantized.y + step_size) : (quantized.y))),
            ((color.z > quantized.z + (dither_threshold * step_size) ? (quantized.z + step_size) : (quantized.z)))
        );
        
        // Clamp to valid range
        return clamp(dithered, float3(0.0), float3(255.0));
    } else {
        // Default to smooth mode for unknown values
        return color;
    }
}

float3 interpolate_rgb(float3 color1, float3 color2, float t) {
    return lerp(color1, color2, t);
}

float3 interpolate_lab(float3 color1, float3 color2, float t) {
    // Convert to linear RGB first
    let linear1 = float3(
        rgb_to_linear(color1.x),
        rgb_to_linear(color1.y),
        rgb_to_linear(color1.z)
    );
    let linear2 = float3(
        rgb_to_linear(color2.x),
        rgb_to_linear(color2.y),
        rgb_to_linear(color2.z)
    );

    // Convert to XYZ
    let xyz1 = linear_rgb_to_xyz(linear1.x, linear1.y, linear1.z);
    let xyz2 = linear_rgb_to_xyz(linear2.x, linear2.y, linear2.z);

    // Convert to Lab
    let lab1 = xyz_to_lab(xyz1.x, xyz1.y, xyz1.z);
    let lab2 = xyz_to_lab(xyz2.x, xyz2.y, xyz2.z);

    // Interpolate in Lab space
    let lab_interp = lerp(lab1, lab2, t);

    // Convert back to XYZ
    let xyz_interp = lab_to_xyz(lab_interp.x, lab_interp.y, lab_interp.z);

    // Convert back to linear RGB
    let linear_interp = xyz_to_linear_rgb(xyz_interp.x, xyz_interp.y, xyz_interp.z);

    // Convert back to sRGB
    return float3(
        linear_to_rgb(linear_interp.x),
        linear_to_rgb(linear_interp.y),
        linear_to_rgb(linear_interp.z)
    );
}

float3 interpolate_oklab(float3 color1, float3 color2, float t) {
    // Convert to linear RGB first
    let linear1 = float3(
        rgb_to_linear(color1.x),
        rgb_to_linear(color1.y),
        rgb_to_linear(color1.z)
    );
    let linear2 = float3(
        rgb_to_linear(color2.x),
        rgb_to_linear(color2.y),
        rgb_to_linear(color2.z)
    );

    // Convert to XYZ
    let xyz1 = linear_rgb_to_xyz(linear1.x, linear1.y, linear1.z);
    let xyz2 = linear_rgb_to_xyz(linear2.x, linear2.y, linear2.z);

    // Convert to OkLab
    let oklab1 = xyz_to_oklab(xyz1.x, xyz1.y, xyz1.z);
    let oklab2 = xyz_to_oklab(xyz2.x, xyz2.y, xyz2.z);

    // Interpolate in OkLab space
    let oklab_interp = lerp(oklab1, oklab2, t);

    // Convert back to XYZ
    let xyz_interp = oklab_to_xyz(oklab_interp.x, oklab_interp.y, oklab_interp.z);

    // Convert back to linear RGB
    let linear_interp = xyz_to_linear_rgb(xyz_interp.x, xyz_interp.y, xyz_interp.z);

    // Convert back to sRGB
    return float3(
        linear_to_rgb(linear_interp.x),
        linear_to_rgb(linear_interp.y),
        linear_to_rgb(linear_interp.z)
    );
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0 {
    // Use X coordinate for gradient position (0.0 to 1.0)
    let gradient_pos = input.uv.x;
    
    // Sample LUT at the gradient position
    let color = sample_lut(gradient_pos);
    
    // Apply display mode effects
    let final_color = apply_display_mode(color, input.uv);
    
    // Convert from 0-255 range to 0-1 range for output
    return float4(final_color / 255.0, 1.0);
} 
