struct FullscreenVertexOutput {
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

float2 fullscreen_quad_position(uint vertex_index) {
    let positions = float2[6](
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2( 1.0,  1.0)
    );
    return positions[vertex_index];
}

float2 fullscreen_quad_uv(uint vertex_index) {
    let uvs = float2[6](
        float2(0.0, 0.0),
        float2(1.0, 0.0),
        float2(0.0, 1.0),
        float2(0.0, 1.0),
        float2(1.0, 0.0),
        float2(1.0, 1.0)
    );
    return uvs[vertex_index];
}

float2 fullscreen_triangle_position(uint vertex_index) {
    let positions = float2[3](
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    );
    return positions[vertex_index];
}

float2 fullscreen_triangle_uv(uint vertex_index) {
    let uvs = float2[3](
        float2(0.0, 0.0),
        float2(2.0, 0.0),
        float2(0.0, 2.0)
    );
    return uvs[vertex_index];
}
