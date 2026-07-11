struct Particle {
    float2 position;
    float2 velocity;
    uint species;
    uint _pad;
};

struct SimParams {
    uint particle_count;
    uint species_count;
    float max_force;
    float max_distance;
    float friction;
    uint wrap_edges;
    float width;
    float height;
    uint random_seed;
    float dt;
    float beta;
    float cursor_x;
    float cursor_y;
    float cursor_size;
    float cursor_strength;
    uint cursor_active;
    float brownian_motion;
    float particle_size;
    float aspect_ratio;
    uint force_refresh_stride;
    uint force_sample_limit;
    uint _pad1;
    uint _pad2;
    uint _pad3;
};

struct GridParams {
    uint particle_count;
    uint grid_width;
    uint grid_height;
    uint neighbor_radius_cells;
    float cell_size;
    float world_min_x;
    float world_min_y;
    float world_width;
    float world_height;
    float _pad0;
    float _pad1;
};
