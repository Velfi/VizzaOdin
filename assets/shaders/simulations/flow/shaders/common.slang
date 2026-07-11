struct Particle {
    float2 position;
    float age;
    uint lut_index;
    uint is_alive;
    uint spawn_type;
    uint pad0;
    uint pad1;
};

struct FlowVector {
    float2 position;
    float2 direction;
};

struct SimParams {
    uint autospawn_pool_size;
    uint autospawn_rate;
    uint brush_pool_size;
    uint brush_spawn_rate;
    float cursor_size;
    float cursor_x;
    float cursor_y;
    uint display_mode;
    uint flow_field_resolution;
    float height;
    uint mouse_button_down;
    float noise_dt_multiplier;
    float noise_scale;
    uint noise_seed;
    float noise_x;
    float noise_y;
    uint particle_autospawn;
    float particle_lifetime;
    uint particle_shape;
    uint particle_size;
    float particle_speed;
    uint screen_height;
    uint screen_width;
    float time;
    uint total_pool_size;
    float trail_decay_rate;
    float trail_deposition_rate;
    float trail_diffusion_rate;
    uint trail_map_height;
    uint trail_map_width;
    float trail_wash_out_rate;
    float vector_magnitude;
    float width;
    float delta_time;
    uint emitter_mode;
    float emitter_radius;
    uint boundary_mode;
    uint trail_style;
    float field_animation_speed;
    uint field_animation_enabled;
    uint _padding_1;
};

struct CameraUniform {
    float4x4 transform_matrix;
    float2 position;
    float zoom;
    float aspect_ratio;
};
