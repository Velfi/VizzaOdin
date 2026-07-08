// Rough Slang port generated from old Vizza WGSL.
// Source: src-tauri/src/simulations/particle_life/shaders/fade_vertex.wgsl
// TODO: compile and tighten bindings, texture formats, atomics, constructors, and entry-point IO.

float4 LoadTexture(RWTexture2D<float4> tex, int2 p) { return tex[p]; }
float4 LoadTexture(Texture2D<float4> tex, int2 p) { return tex.Load(int3(p, 0)); }
void StoreTexture(RWTexture2D<float4> tex, int2 p, float4 v) { tex[p] = v; }

// Fullscreen fade vertex shader for particle traces

struct VertexOutput {

    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};// Fullscreen triangle vertex shader - no vertex buffer needed
[shader("vertex")]
VertexOutput main(uint vertex_index : SV_VertexID) {
    // Generate a fullscreen triangle using vertex index
    // This creates a triangle that covers the entire screen:
    // Vertex 0: (-1, -1) bottom-left
    // Vertex 1: (3, -1) bottom-right (extends beyond screen)  
    // Vertex 2: (-1, 3) top-left (extends beyond screen)
    
    var positions = float2[3](
        float2(-1.0, -1.0),  // Bottom-left
        float2(3.0, -1.0),   // Bottom-right (extends past screen)
        float2(-1.0, 3.0)    // Top-left (extends past screen)
    );
    
    var uvs = float2[3](
        float2(0.0, 0.0),    // Top-left UV
        float2(2.0, 0.0),    // Top-right UV (extends past 1.0)
        float2(0.0, 2.0)     // Bottom-left UV (extends past 1.0)
    );
    
    VertexOutput output;
    output.position = float4(positions[vertex_index], 0.0, 1.0);
    output.uv = uvs[vertex_index];
    
    return output;
} 
