// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/gray_scott/shaders/reaction_diffusion.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

struct SimulationParams {

    float feed_rate;
    float kill_rate;
    float delta_u;
    float delta_v;

    float timestep;
    uint width;
    uint height;
    
    // Mask system
    uint mask_pattern;
    uint mask_target;
    float mask_strength;
    uint mask_mirror_horizontal;
    uint mask_mirror_vertical;
    uint mask_invert_tone;
    
    // Adaptive timestep parameters
    float max_timestep;
    float stability_factor;
    uint enable_adaptive_timestep;
};

struct UVPair {

    float u;
    float v;
};

[[vk::binding(0, 0)]]
RWTexture2D<float4> uvs_in;
[[vk::binding(1, 0)]]
RWTexture2D<float4> uvs_out;
[[vk::binding(2, 0)]]
ConstantBuffer<SimulationParams> params;
// Optional image-driven nutrient pattern (bound only when used)
[[vk::binding(3, 0)]]
StructuredBuffer<float> gradient_map;

uint get_index(int x, int y) {
    let width = int(params.width);
    let height = int(params.height);
    let wrapped_x = (x + width) % width;
    let wrapped_y = (y + height) % height;
    return uint(wrapped_y * width + wrapped_x);
}


float2 get_laplacian(int x, int y) {
    let width = int(params.width);
    let height = int(params.height);
    let wrapped_x = (x + width) % width;
    let wrapped_y = (y + height) % height;
    
    let current_sample = LoadTexture(uvs_in, int2(wrapped_x, wrapped_y));
    let current = current_sample.xy; // Extract only the first two components (RG -> UV)
    
    var laplacian = float2(0.0);
    
    // 5-point stencil: center + 4 cardinal neighbors
    // Center weight: -4 (for 5-point stencil)
    laplacian -= current * 4.0;
    
    // Cardinal directions (weight 1.0 each) - batch the lookups for better performance
    let left_x = (x - 1 + width) % width;
    let right_x = (x + 1 + width) % width;
    let up_y = (y - 1 + height) % height;
    let down_y = (y + 1 + height) % height;
    
    let left_sample = LoadTexture(uvs_in, int2(left_x, wrapped_y));
    let right_sample = LoadTexture(uvs_in, int2(right_x, wrapped_y));
    let up_sample = LoadTexture(uvs_in, int2(wrapped_x, up_y));
    let down_sample = LoadTexture(uvs_in, int2(wrapped_x, down_y));
    
    let left = left_sample.xy;
    let right = right_sample.xy;
    let up = up_sample.xy;
    let down = down_sample.xy;
    
    laplacian += left;
    laplacian += right;
    laplacian += up;
    laplacian += down;
    
    return laplacian;
}

float hash(uint n) {
    return frac(sin(float(n)) * 43758.5453);
}

float noise2D(uint x, uint y, uint seed) {
    return hash(x * 73856093 + y * 19349663 + seed);
}

float get_mask_factor(int x, int y) {
    // Calculate normalized coordinates
    let original_nx = float(x) / float(params.width);
    let original_ny = float(y) / float(params.height);
    
    // For image-based masks, we need to handle mirroring differently
    let pattern = params.mask_pattern;
    
    var result = 0.0;
    
    switch (pattern) {
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
            var nx = original_nx;
            var ny = original_ny;
            // Apply mirror transformations
            if (params.mask_mirror_horizontal != 0) {
                nx = 1.0 - nx;
            }
            if (params.mask_mirror_vertical != 0) {
                ny = 1.0 - ny;
            }
            result = (nx + ny) / 2.0;
            break;
        }
        case 3: { // Radial gradient
            var nx = original_nx;
            var ny = original_ny;
            // Apply mirror transformations
            if (params.mask_mirror_horizontal != 0) {
                nx = 1.0 - nx;
            }
            if (params.mask_mirror_vertical != 0) {
                ny = 1.0 - ny;
            }
            let center_x = 0.5;
            let center_y = 0.5;
            let dx = nx - center_x;
            let dy = ny - center_y;
            let distance = sqrt(dx * dx + dy * dy);
            result = 1.0 - distance;
            break;
        }
        case 4: { // Vertical stripes
            var nx = original_nx;
            // Apply mirror transformations
            if (params.mask_mirror_horizontal != 0) {
                nx = 1.0 - nx;
            }
            let stripe_width = 0.1;
            let is_stripe = (nx / stripe_width) % 2.0 < 1.0;
            result = ((is_stripe) ? (1.0) : (0.0));
            break;
        }
        case 5: { // Horizontal stripes
            var ny = original_ny;
            // Apply mirror transformations
            if (params.mask_mirror_vertical != 0) {
                ny = 1.0 - ny;
            }
            let stripe_width = 0.1;
            let is_stripe = (ny / stripe_width) % 2.0 < 1.0;
            result = ((is_stripe) ? (1.0) : (0.0));
            break;
        }
        case 6: { // Wave function f(x,y) = xe^(-(x² + y²))
            var nx = original_nx;
            var ny = original_ny;
            // Apply mirror transformations
            if (params.mask_mirror_horizontal != 0) {
                nx = 1.0 - nx;
            }
            if (params.mask_mirror_vertical != 0) {
                ny = 1.0 - ny;
            }
            let x_norm = (nx * 4.0) - 2.0;
            let y_norm = (ny * 4.0) - 2.0;
            let squared_dist = x_norm * x_norm + y_norm * y_norm;
            let wave = x_norm * exp(-squared_dist);
            result = (wave + 0.43) / 0.86;
            break;
        }
        case 7: { // Enhanced cosine grid with phase and frequency variations
            var nx = original_nx;
            var ny = original_ny;
            // Apply mirror transformations
            if (params.mask_mirror_horizontal != 0) {
                nx = 1.0 - nx;
            }
            if (params.mask_mirror_vertical != 0) {
                ny = 1.0 - ny;
            }
            // Scale coordinates with different frequencies
            let x_scaled = nx * 18.85; // 6π
            let y_scaled = ny * 12.566; // 4π
            
            // Add phase variation and cross-modulation
            let pattern1 = cos(x_scaled + cos(y_scaled * 0.5));
            let pattern2 = cos(y_scaled + sin(x_scaled * 0.3));
            
            // Create interesting interference pattern
            let interference = pattern1 * pattern2;
            
            // Add non-linear transformation
            let raw = -(interference * interference) * cos(x_scaled * 0.5);
            
            // Normalize to [0, 1] with smoother transition
            result = (tanh(raw) + 1.0) * 0.5;
            break;
        }
        case 8: { // Image-driven gradient map
            // For image masks, we need to apply mirroring to the sampling coordinates
            var sample_x = original_nx;
            var sample_y = original_ny;
            
            // Apply mirror transformations to sampling coordinates
            if (params.mask_mirror_horizontal != 0) {
                sample_x = 1.0 - sample_x;
            }
            if (params.mask_mirror_vertical != 0) {
                sample_y = 1.0 - sample_y;
            }
            
            // Use mirrored sampling coordinates for image indexing
            let mirrored_x = int(sample_x * float(params.width));
            let mirrored_y = int(sample_y * float(params.height));
            let idx = get_index(mirrored_x, mirrored_y);
            // Map [0,1] image to [0,1] nutrient factor
            let img = clamp(gradient_map[idx], 0.0, 1.0);
            result = img;
            break;
        }
        default: {
            result = 1.0;
            break;
        }
    }
    
    // If tone inverted, invert the pattern (keep it in the 0 to 1 range)
    if (params.mask_invert_tone != 0) {
        result = 1.0 - result;
    }
    
    return result;
}


float calculate_adaptive_timestep(float delta_u, float delta_v, float feed_rate, float kill_rate, float stability_factor) {
    // Von Neumann stability condition for 2D diffusion
    // For 2D, the condition is dt <= 0.25 / (Du + Dv) where Du, Dv are diffusion coefficients
    let diffusion_limit = 0.25 / (delta_u + delta_v);
    
    // Reaction rate stability - consider the maximum reaction rate
    // The reaction term uv² can be at most 1.0 when u=1, v=1
    // A more conservative estimate: dt <= 1.0 / (max_reaction_rate + feed_rate + kill_rate)
    let max_reaction_rate = 1.0; // uv² <= 1.0
    let reaction_limit = 1.0 / (max_reaction_rate + feed_rate + kill_rate);
    
    // Take the minimum for stability
    let stable_timestep = min(diffusion_limit, reaction_limit) * stability_factor;
    
    return stable_timestep;
}



[shader("compute")]
[numthreads(1,  1,  1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let x = int(global_id.x);
    let y = int(global_id.y);
    
    if (x >= int(params.width) || y >= int(params.height)) {
        return;
    }
    
    let width = int(params.width);
    let height = int(params.height);
    let wrapped_x = (x + width) % width;
    let wrapped_y = (y + height) % height;
    
    let uv_sample = LoadTexture(uvs_in, int2(wrapped_x, wrapped_y));
    let uv = uv_sample.xy; // Extract only the first two components (RG -> UV)
    let reaction_rate = uv.x * uv.y * uv.y;
    
    let laplacian = get_laplacian(x, y);
    let mask_factor = get_mask_factor(x, y);
    
    // Use adaptive timestep only if enabled, otherwise use the user-specified timestep
    float effective_timestep;
    if (params.enable_adaptive_timestep != 0) {
        effective_timestep = calculate_adaptive_timestep(
            params.delta_u,
            params.delta_v,
            params.feed_rate,
            params.kill_rate,
            params.stability_factor
        );
    } else {
        effective_timestep = params.timestep;
    }
    
    // Apply mask to the appropriate parameters based on mask_target
    var effective_feed_rate = params.feed_rate;
    var effective_kill_rate = params.kill_rate;
    var effective_delta_u = params.delta_u;
    var effective_delta_v = params.delta_v;
    
    // Calculate mask influence: 0.0 = no effect, 1.0 = full effect
    let mask_influence = mask_factor * params.mask_strength;
    
    switch (params.mask_target) {
        case 1: { // FeedRate
            // Map mask factor from [0,1] to [0.5,1.0] for feed rate scaling
            effective_feed_rate = params.feed_rate * (0.5 + mask_influence * 0.5);
            break;
        }
        case 2: { // KillRate
            // Map mask factor from [0,1] to [0.5,1.0] for kill rate scaling
            effective_kill_rate = params.kill_rate * (0.5 + mask_influence * 0.5);
            break;
        }
        case 3: { // DiffusionU
            // Map mask factor from [0,1] to [0.5,1.5] for diffusion scaling
            effective_delta_u = params.delta_u * (0.5 + mask_influence * 1.0);
            break;
        }
        case 4: { // DiffusionV
            // Map mask factor from [0,1] to [0.5,1.5] for diffusion scaling
            effective_delta_v = params.delta_v * (0.5 + mask_influence * 1.0);
            break;
        }
        case 5: { // UVConcentration
            // This would affect initial concentrations, but we'll implement it as a feed rate effect for now
            effective_feed_rate = params.feed_rate * (0.5 + mask_influence * 0.5);
            break;
        }
        default: { // None or any other value
            // No masking applied - use original values
            break;
        }
    }
    
    let delta_u = effective_delta_u * laplacian.x - reaction_rate + effective_feed_rate * (1.0 - uv.x);
    let delta_v = effective_delta_v * laplacian.y + reaction_rate - (effective_kill_rate + effective_feed_rate) * uv.y;
    
    let new_u = clamp(uv.x + delta_u * effective_timestep, 0.0, 1.0);
    let new_v = clamp(uv.y + delta_v * effective_timestep, 0.0, 1.0);
    
    StoreTexture(uvs_out, int2(wrapped_x, wrapped_y), float4(new_u, new_v, 0.0, 0.0));
} 
