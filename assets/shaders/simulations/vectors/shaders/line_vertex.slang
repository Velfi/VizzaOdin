struct CameraUniform {
    float4x4 transform_matrix;
    float2 position;
    float zoom;
    float aspect_ratio;
    uint cols;
    uint rows;
    float line_length;
    float line_width;
    uint display_mode;
    uint3 _padding;
};

struct InstanceInput {
    float value : TEXCOORD0;
    float angle : TEXCOORD1;
};

struct VertexOutput {
    float4 position : SV_Position;
    float value : TEXCOORD0;
};

[[vk::binding(0, 0)]]
ConstantBuffer<CameraUniform> camera;

float2 shaft_vertex(uint vertex_id, float2 p0, float2 p1, float2 normal) {
    static const uint corner_indices[6] = {0, 1, 2, 0, 2, 3};
    uint corner = corner_indices[vertex_id];
    if (corner == 0) return p0 - normal;
    if (corner == 1) return p0 + normal;
    if (corner == 2) return p1 + normal;
    return p1 - normal;
}

[shader("vertex")]
VertexOutput main(InstanceInput input, uint vertex_id : SV_VertexID, uint instance_id : SV_InstanceID) {
    uint x = instance_id % max(camera.cols, 1u);
    uint y = instance_id / max(camera.cols, 1u);
    float2 center = float2(
        -1.2 + (float(x) + 0.5) / float(max(camera.cols, 1u)) * 2.4,
        -0.9 + (float(y) + 0.5) / float(max(camera.rows, 1u)) * 1.8);
    float intensity = clamp(input.value, 0.0, 1.0);
    float length = max(camera.line_length, 0.001) * (0.5 + intensity * 0.5);
    float half_width = max(camera.line_width, 0.001) * 0.5;
    float2 unit_dir = float2(cos(input.angle), sin(input.angle));
    float2 delta = unit_dir * length;
    float2 normal = float2(-unit_dir.y, unit_dir.x) * half_width;
    float2 position;

    if (camera.display_mode == 4u) {
        uint segment_vertex = vertex_id % 6u;
        uint segment = vertex_id / 6u;
        static const uint ring_indices[6] = {0, 1, 2, 0, 2, 3};
        uint corner = ring_indices[segment_vertex];
        uint next = (segment + 1u) % 6u;
        float radius = max(length * 0.5, half_width * 2.0);
        float inner_radius = max(radius - max(half_width * 2.0, radius * 0.18), radius * 0.35);
        float a0 = float(segment) / 6.0 * 6.28318530718;
        float a1 = float(next) / 6.0 * 6.28318530718;
        float2 outer0 = center + float2(cos(a0), sin(a0)) * radius;
        float2 outer1 = center + float2(cos(a1), sin(a1)) * radius;
        float2 inner0 = center + float2(cos(a0), sin(a0)) * inner_radius;
        float2 inner1 = center + float2(cos(a1), sin(a1)) * inner_radius;
        if (corner == 0u) position = outer0;
        else if (corner == 1u) position = outer1;
        else if (corner == 2u) position = inner1;
        else position = inner0;
    } else {
        float2 p0 = center;
        float2 p1 = center + delta;
        if (camera.display_mode == 1u) {
            p0 = center - delta * 0.5;
            p1 = center + delta * 0.5;
        }
        if (vertex_id < 6u) {
            position = shaft_vertex(vertex_id, p0, p1, normal);
        } else if (camera.display_mode == 2u) {
            float head_length = min(length * 0.42, max(half_width * 8.0, length * 0.22));
            float head_width = max(half_width * 3.5, head_length * 0.45);
            float2 head_base = p1 - unit_dir * head_length;
            uint corner = vertex_id - 6u;
            if (corner == 0u) position = p1;
            else if (corner == 1u) position = head_base + float2(-unit_dir.y, unit_dir.x) * head_width;
            else position = head_base - float2(-unit_dir.y, unit_dir.x) * head_width;
        } else {
            float wing_length = length * 0.42;
            float2 wing_start = p1 - unit_dir * wing_length - float2(-unit_dir.y, unit_dir.x) * wing_length * 0.55;
            float2 wing_dir = normalize(p1 - wing_start);
            float2 wing_normal = float2(-wing_dir.y, wing_dir.x) * half_width;
            position = shaft_vertex(vertex_id - 6u, wing_start, p1, wing_normal);
        }
    }

    VertexOutput output;
    output.position = mul(camera.transform_matrix, float4(position, 0.0, 1.0));
    output.value = intensity;
    return output;
}
