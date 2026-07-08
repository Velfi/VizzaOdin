// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/gray_scott/shaders/paint.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// GPU-based painting shader for Gray-Scott simulation
// Paints directly onto the texture without clearing it

struct PaintParams {

    float mouse_x;
    float mouse_y;
    float cursor_size;
    float cursor_strength;
    uint mouse_button; // 0 = left (seed), 1 = middle (no effect), 2 = right (erase)
    uint width;
    uint height;
    uint _pad1;
};

[[vk::binding(0, 0)]]
ConstantBuffer<PaintParams> params;
[[vk::binding(1, 0)]]
RWTexture2D<float4> uvs_texture;

[shader("compute")]
[numthreads(8,  8, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    let x = int(global_id.x);
    let y = int(global_id.y);
    
    // Check bounds
    if (x >= int(params.width) || y >= int(params.height)) {
        return;
    }
    
    // Convert mouse position to texture coordinates
    let mouse_x = int(params.mouse_x * float(params.width));
    let mouse_y = int(params.mouse_y * float(params.height));
    
    // Circular brush in pixel space using the smaller texture dimension (no stretching)
    let min_dim = float(min(params.width, params.height));
    let radius_px = max(params.cursor_size * (min_dim * 0.5), 1.0);

    let dx = float(x - mouse_x);
    let dy = float(y - mouse_y);
    let r2 = dx * dx + dy * dy;
    let radius2 = radius_px * radius_px;
    if (r2 > radius2) {
        return;
    }

    // Smooth radial falloff
    let factor = 1.0 - sqrt(r2) / radius_px;
    
    // Skip very small factors to reduce unnecessary updates
    if (factor < 0.01) {
        return;
    }
    
    // Read current UV values
    let current_sample = LoadTexture(uvs_texture, int2(x, y));
    let current_uv = current_sample.xy;
    
    // Apply painting based on mouse button
    var new_uv = current_uv;
    
    if (params.mouse_button == 0) {
        // Left mouse button: paint U value based on cursor strength
        let paint_strength = factor * params.cursor_strength;
        new_uv.x = lerp(current_uv.x, params.cursor_strength, paint_strength);
        new_uv.y = lerp(current_uv.y, 0.8 + 0.2 * factor, paint_strength);
    } else if (params.mouse_button == 2) {
        // Right mouse button: create voids/erase
        let paint_strength = factor * params.cursor_strength;
        new_uv.x = lerp(current_uv.x, 1.0, paint_strength);
        new_uv.y = lerp(current_uv.y, 0.0, paint_strength);
    }
    // Middle mouse button (params.mouse_button == 1): no effect
    
    // Write back to texture
    StoreTexture(uvs_texture, int2(x, y), float4(new_uv.x, new_uv.y, 0.0, 0.0));
}
