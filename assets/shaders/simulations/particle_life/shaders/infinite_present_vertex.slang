struct CameraUniform {
    float4x4 transform_matrix;
    float2 position;
    float zoom;
    float aspect_ratio;
};

struct VertexOutput {
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

[[vk::binding(3, 0)]]
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
VertexOutput main(uint vertex_index : SV_VertexID, uint instance_index : SV_InstanceID) {
    let positions = float2[6](
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2( 1.0,  1.0)
    );

    let uvs = float2[6](
        float2(0.0, 0.0),
        float2(1.0, 0.0),
        float2(0.0, 1.0),
        float2(0.0, 1.0),
        float2(1.0, 0.0),
        float2(1.0, 1.0)
    );

    uint tile_count = calculate_tile_count(camera.zoom);
    int2 tile_start = calculate_tile_start(camera.position, camera.zoom);
    int grid_x = int(instance_index % tile_count) + tile_start.x;
    int grid_y = int(instance_index / tile_count) + tile_start.y;
    float2 world_pos = positions[vertex_index] + float2(float(grid_x), float(grid_y)) * 2.0;

    VertexOutput output;
    output.position = mul(camera.transform_matrix, float4(world_pos, 0.0, 1.0));
    output.uv = uvs[vertex_index];
    return output;
}
