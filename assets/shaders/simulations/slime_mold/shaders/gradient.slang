// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/slime_mold/shaders/gradient.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Mask compute shader for generating mask patterns
// Provides spatial masks that affect simulation parameters

static const float PI = 3.14159265359;

[[vk::binding(3, 0)]]
RWStructuredBuffer<float> mask_map;

struct SimSizeUniform {

    uint width;
    uint height;
    float decay_rate;
    float agent_jitter;
    float agent_speed_min;
    float agent_speed_max;
    float agent_turn_rate;
    float agent_sensor_angle;
    float agent_sensor_distance;
    float diffusion_rate;
    float pheromone_deposition_rate;
    uint mask_pattern;
    uint mask_target;
    float mask_strength;
    float mask_curve;
    uint mask_mirror_horizontal;
    uint mask_mirror_vertical;
    uint mask_invert_tone;
    uint _pad1;
};

[[vk::binding(2, 0)]]
ConstantBuffer<SimSizeUniform> sim_size;

// Mask pattern types
static const uint MASK_DISABLED = 0;
static const uint MASK_CHECKERBOARD = 1;
static const uint MASK_DIAGONAL_GRADIENT = 2;
static const uint MASK_RADIAL_GRADIENT = 3;
static const uint MASK_VERTICAL_STRIPES = 4;
static const uint MASK_HORIZONTAL_STRIPES = 5;
static const uint MASK_WAVE_FUNCTION = 6;
static const uint MASK_COSINE_GRID = 7;
static const uint MASK_IMAGE = 8;

[shader("compute")]
[numthreads(256, 1, 1)]
void generate_mask(uint3 id : SV_DispatchThreadID) {
    let idx = id.x;
    let total_size = sim_size.width * sim_size.height;
    if (idx < total_size) {
        // Check if mask is disabled or image-driven
        if (sim_size.mask_pattern == MASK_DISABLED || sim_size.mask_pattern == MASK_IMAGE) {
            mask_map[idx] = 0.0;
        } else {
            let x = idx % sim_size.width;
            let y = idx / sim_size.width;
            
            // Normalize coordinates to [0, 1]
            let original_nx = float(x) / float(sim_size.width);
            let original_ny = float(y) / float(sim_size.height);
            
            var result = 0.0;
            
            switch (sim_size.mask_pattern) {
                case 0: { // Disabled
                    result = 1.0;
                    break;
                }
                case 1: { // Checkerboard
                    let block_size = 200;
                    let bx = uint(x) / block_size;
                    let by = uint(y) / block_size;
                    let is_checker = ((bx + by) % 2) == 0;
                    result = ((is_checker) ? (1.0) : (0.0));
                    break;
                }
                case 2: { // Diagonal gradient
                    let nx = original_nx;
                    let ny = original_ny;
                    result = (nx + ny) / 2.0;
                    break;
                }
                case 3: { // Radial gradient
                    let nx = original_nx;
                    let ny = original_ny;
                    let center_x = 0.5;
                    let center_y = 0.5;
                    let dx = nx - center_x;
                    let dy = ny - center_y;
                    let distance = sqrt(dx * dx + dy * dy);
                    result = 1.0 - distance * 2.0; // Scale to [0,1]
                    break;
                }
                case 4: { // Vertical stripes
                    let nx = original_nx;
                    result = sin(nx * 3.14159 * 4.0) * 0.5 + 0.5;
                    break;
                }
                case 5: { // Horizontal stripes
                    let ny = original_ny;
                    result = sin(ny * 3.14159 * 4.0) * 0.5 + 0.5;
                    break;
                }
                case 6: { // Wave function
                    let nx = original_nx;
                    let ny = original_ny;
                    let wave = sin(nx * 3.14159 * 2.0) * cos(ny * 3.14159 * 2.0);
                    result = wave * 0.5 + 0.5;
                    break;
                }
                case 7: { // Cosine grid
                    let nx = original_nx;
                    let ny = original_ny;
                    let grid_x = cos(nx * 3.14159 * 4.0);
                    let grid_y = cos(ny * 3.14159 * 4.0);
                    result = (grid_x + grid_y) * 0.5;
                    break;
                }
                default: {
                    result = 1.0;
                    break;
                }
            }

            // Clamp to valid range
            mask_map[idx] = clamp(result, 0.0, 1.0);
        }
    }
} 
