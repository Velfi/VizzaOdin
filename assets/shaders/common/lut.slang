float srgb_to_linear(float srgb) {
    if (srgb <= 0.04045) {
        return srgb / 12.92;
    }
    return pow((srgb + 0.055) / 1.055, 2.4);
}

float3 linear_from_srgb(float3 srgb) {
    return float3(
        srgb_to_linear(srgb.r),
        srgb_to_linear(srgb.g),
        srgb_to_linear(srgb.b)
    );
}

float3 lut_planar_u8_srgb(StructuredBuffer<uint> lut_data, uint index) {
    let idx = min(index, 255u);
    return float3(
        float(lut_data[idx]) / 255.0,
        float(lut_data[idx + 256u]) / 255.0,
        float(lut_data[idx + 512u]) / 255.0
    );
}

float3 lut_planar_u8_linear(StructuredBuffer<uint> lut_data, uint index) {
    return linear_from_srgb(lut_planar_u8_srgb(lut_data, index));
}
