// 2D ST-FLIP compute pipeline. Spatial coordinates are normalized to [0, 1].
// Grid accumulators use signed 16.16 fixed point so the solver only relies on
// Vulkan 1.3 core integer atomics.

static const float FIXED_SCALE = 65536.0;
static const float INV_FIXED_SCALE = 1.0 / FIXED_SCALE;
// The paper uses epsilon_rho to keep the diffuse-interface PPE conditioned.
// A fixed-count Jacobi solve needs a practical lower bound; 0.05 limits the
// coefficient contrast to 20:1 while leaving the liquid/air cutoff at 0.5.
static const float PHASE_DENSITY_EPSILON = 0.05;

struct Particle {
    float2 position;
    float2 velocity;
    float time_residual;
    uint random_state;
    // x is runtime-only marker activity. Inactive markers form a reservoir
    // used by the Inject tool and never contribute to the simulation.
    uint2 _padding;
};

struct SimParams {
    uint grid_width;
    uint grid_height;
    uint particle_count;
    uint pass_index;
    float dt;
    float previous_dt;
    float cell_size;
    float target_cfl;
    float gravity;
    float flip_ratio;
    float jitter_strength;
    float phase_steepness;
    float reference_mass;
    float ink_dissipation;
    float brush_size;
    float brush_strength;
    float time;
    float _padding_time;
    float2 cursor;
    float2 cursor_velocity;
    uint cursor_active;
    uint cursor_mode;
    uint random_seed;
    uint step_index;
};

[[vk::binding(0, 0)]] RWStructuredBuffer<Particle> particles;
[[vk::binding(1, 0)]] ConstantBuffer<SimParams> params;
[[vk::binding(2, 0)]] RWStructuredBuffer<int2> u_accum;
[[vk::binding(3, 0)]] RWStructuredBuffer<int2> v_accum;
// x=projected current velocity, y=this step's pre-force/pre-projection
// velocity. FLIP uses their difference; y is not the previous frame.
[[vk::binding(4, 0)]] RWStructuredBuffer<float2> u_velocity;
[[vk::binding(5, 0)]] RWStructuredBuffer<float2> v_velocity;
// x=unsaturated marker density, y=pressure, z=pressure scratch, w=divergence
[[vk::binding(6, 0)]] RWStructuredBuffer<float4> cells;
[[vk::binding(7, 0)]] RWStructuredBuffer<uint> render_density;
// x=current advected fluid coverage, y=advection scratch
[[vk::binding(8, 0)]] RWStructuredBuffer<float2> fluid_phase;

uint hash_u32(uint value) {
    value ^= value >> 16;
    value *= 0x7feb352du;
    value ^= value >> 15;
    value *= 0x846ca68bu;
    return value ^ (value >> 16);
}

float random01(inout uint state) {
    state = hash_u32(state + 0x9e3779b9u);
    return float(state) / 4294967295.0;
}

float ink_value_noise(float2 p, uint seed) {
    let cell = int2(floor(p));
    let f = frac(p);
    let s = f * f * (3.0 - 2.0 * f);
    let h00 = float(hash_u32(uint(cell.x) ^ (uint(cell.y) * 0x9e3779b9u) ^ seed)) / 4294967295.0;
    let h10 = float(hash_u32(uint(cell.x + 1) ^ (uint(cell.y) * 0x9e3779b9u) ^ seed)) / 4294967295.0;
    let h01 = float(hash_u32(uint(cell.x) ^ (uint(cell.y + 1) * 0x9e3779b9u) ^ seed)) / 4294967295.0;
    let h11 = float(hash_u32(uint(cell.x + 1) ^ (uint(cell.y + 1) * 0x9e3779b9u) ^ seed)) / 4294967295.0;
    return lerp(lerp(h00, h10, s.x), lerp(h01, h11, s.x), s.y);
}

float ink_fbm(float2 p, uint seed) {
    var value = 0.0;
    var amplitude = 0.5714286;
    for (var octave = 0; octave < 3; octave++) {
        value += ink_value_noise(p, seed + uint(octave) * 0x85ebca6bu) * amplitude;
        p = p * 2.03 + 7.17;
        amplitude *= 0.5;
    }
    return value;
}

float poly6(float r) {
    let x = max(0.0, 1.0 - r * r);
    return x * x * x;
}

float temporal_weight(float tau) {
    if (tau < -0.5 || tau > 0.5) return 0.0;
    return (35.0 / 16.0) * poly6(tau - 0.5);
}

float phase_from_mass(float mass) {
    let normalized = max(mass, 0.0) / max(params.phase_steepness * params.reference_mass, 1e-6);
    return min(sqrt(normalized), 1.0);
}

float u_phase(uint x, uint y) {
    return phase_from_mass(float(max(u_accum[u_index(x, y)].x, 0)) * INV_FIXED_SCALE);
}

float v_phase(uint x, uint y) {
    return phase_from_mass(float(max(v_accum[v_index(x, y)].x, 0)) * INV_FIXED_SCALE);
}

float smooth_cfl(float value) {
    let x = clamp(value, 0.0, 1.0);
    return x * x * (3.0 - 2.0 * x);
}

float brush_distance(float2 position) {
    var delta = position - params.cursor;
    delta.x *= float(params.grid_width) / max(float(params.grid_height), 1.0);
    return length(delta);
}

uint cell_index(uint x, uint y) { return y * params.grid_width + x; }
uint u_index(uint x, uint y) { return y * (params.grid_width + 1u) + x; }
uint v_index(uint x, uint y) { return y * params.grid_width + x; }

float sample_u(float2 position, bool previous) {
    let grid = float2(position.x * float(params.grid_width), position.y * float(params.grid_height) - 0.5);
    let base = int2(floor(grid));
    let f = frac(grid);
    var result = 0.0;
    var valid_weight = 0.0;
    for (var oy = 0; oy < 2; oy++) for (var ox = 0; ox < 2; ox++) {
        let p = clamp(base + int2(ox, oy), int2(0), int2(int(params.grid_width), int(params.grid_height) - 1));
        let weight = (ox == 0 ? 1.0 - f.x : f.x) * (oy == 0 ? 1.0 - f.y : f.y);
        let index = u_index(uint(p.x), uint(p.y));
        if (u_accum[index].x <= 0) continue;
        let value = u_velocity[index];
        result += (previous ? value.y : value.x) * weight;
        valid_weight += weight;
    }
    return valid_weight > 1e-5 ? result / valid_weight : 0.0;
}

float sample_v(float2 position, bool previous) {
    let grid = float2(position.x * float(params.grid_width) - 0.5, position.y * float(params.grid_height));
    let base = int2(floor(grid));
    let f = frac(grid);
    var result = 0.0;
    var valid_weight = 0.0;
    for (var oy = 0; oy < 2; oy++) for (var ox = 0; ox < 2; ox++) {
        let p = clamp(base + int2(ox, oy), int2(0), int2(int(params.grid_width) - 1, int(params.grid_height)));
        let weight = (ox == 0 ? 1.0 - f.x : f.x) * (oy == 0 ? 1.0 - f.y : f.y);
        let index = v_index(uint(p.x), uint(p.y));
        if (v_accum[index].x <= 0) continue;
        let value = v_velocity[index];
        result += (previous ? value.y : value.x) * weight;
        valid_weight += weight;
    }
    return valid_weight > 1e-5 ? result / valid_weight : 0.0;
}

float2 sample_velocity(float2 position, bool previous) {
    return float2(sample_u(position, previous), sample_v(position, previous));
}

float sample_density(float2 position) {
    let grid = position * float2(params.grid_width, params.grid_height) - 0.5;
    let base = int2(floor(grid));
    let f = frac(grid);
    var result = 0.0;
    for (var oy = 0; oy < 2; oy++) for (var ox = 0; ox < 2; ox++) {
        let p = clamp(base + int2(ox, oy), int2(0), int2(int(params.grid_width) - 1, int(params.grid_height) - 1));
        let weight = (ox == 0 ? 1.0 - f.x : f.x) * (oy == 0 ? 1.0 - f.y : f.y);
        result += cells[cell_index(uint(p.x), uint(p.y))].x * weight;
    }
    return result;
}

float sample_ink(float2 position) {
    let grid = position * float2(params.grid_width, params.grid_height) - 0.5;
    let base = int2(floor(grid));
    let f = frac(grid);
    var result = 0.0;
    for (var oy = 0; oy < 2; oy++) for (var ox = 0; ox < 2; ox++) {
        let p = clamp(base + int2(ox, oy), int2(0), int2(int(params.grid_width) - 1, int(params.grid_height) - 1));
        let weight = (ox == 0 ? 1.0 - f.x : f.x) * (oy == 0 ? 1.0 - f.y : f.y);
        result += fluid_phase[cell_index(uint(p.x), uint(p.y))].x * weight;
    }
    return result;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void initialize_particles(uint3 id : SV_DispatchThreadID) {
    if (id.x >= params.particle_count) return;
    var seed = hash_u32(params.random_seed ^ id.x);
    let r0 = random01(seed);
    let r1 = random01(seed);
    float2 position;
    switch (params.pass_index) {
    case 1: {
        let aspect = float(params.grid_width) / max(float(params.grid_height), 1.0);
        let nx = uint(ceil(sqrt(float(params.particle_count) * aspect)));
        let ny = (params.particle_count + nx - 1u) / nx;
        let ix = id.x % nx;
        let iy = id.x / nx;
        let jitter = (float2(r0, r1) - 0.5) * 0.35;
        position = float2(0.04) + (float2(ix, iy) + 0.5 + jitter) / float2(nx, ny) * 0.92;
        break;
    }
    case 2: {
        let side = (id.x & 1u) == 0u ? -1.0 : 1.0;
        let angle = 6.2831853 * r0;
        let radius = 0.13 * sqrt(r1);
        position = float2(0.5 + side * 0.2 + cos(angle) * radius, 0.66 + sin(angle) * radius);
        break;
    }
    case 3: position = float2(0.5, 0.5); break; // inactive/empty seed point
    default: {
        // Stratified markers avoid starting the pressure solve with Poisson
        // clumps and empty cells. A tiny deterministic jitter prevents a
        // visible lattice without changing particles-per-cell materially.
        let nx = uint(ceil(sqrt(float(params.particle_count) * (0.38 / 0.88))));
        let ny = (params.particle_count + nx - 1u) / nx;
        let ix = id.x % nx;
        let iy = id.x / nx;
        let jitter = (float2(r0, r1) - 0.5) * 0.35;
        position = float2(0.04, 0.04) + (float2(ix, iy) + 0.5 + jitter) / float2(nx, ny) * float2(0.38, 0.88);
        break;
    }
    }
    Particle particle;
    particle.position = position;
    particle.velocity = float2(0.0);
    particle.time_residual = 0.0;
    particle.random_state = seed;
    particle._padding = uint2(params.pass_index == 3u ? 0u : 1u, 0u);
    particles[id.x] = particle;
}

[shader("compute")]
[numthreads(256, 1, 1)]
void clear_grid(uint3 id : SV_DispatchThreadID) {
    let cell_count = params.grid_width * params.grid_height;
    let u_count = (params.grid_width + 1u) * params.grid_height;
    let v_count = params.grid_width * (params.grid_height + 1u);
    if (id.x < u_count) u_accum[id.x] = int2(0);
    if (id.x < v_count) v_accum[id.x] = int2(0);
    if (id.x < cell_count) {
        cells[id.x] = float4(0.0);
        render_density[id.x] = 0u;
        if (params.pass_index == 99u) fluid_phase[id.x] = float2(0.0);
    }
}

// Reset persistent grid history before the first FLIP transfer. clear_grid
// normally copies current velocity into the previous channel; doing that on
// freshly allocated buffers would feed undefined data into the FLIP delta.
[shader("compute")]
[numthreads(256, 1, 1)]
void reset_grid_history(uint3 id : SV_DispatchThreadID) {
    let cell_count = params.grid_width * params.grid_height;
    let u_count = (params.grid_width + 1u) * params.grid_height;
    let v_count = params.grid_width * (params.grid_height + 1u);
    if (id.x < u_count) u_velocity[id.x] = float2(0.0);
    if (id.x < v_count) v_velocity[id.x] = float2(0.0);
    if (id.x < cell_count) fluid_phase[id.x] = float2(0.0);
}

[shader("compute")]
[numthreads(16, 16, 1)]
void seed_ink_noise(uint3 id : SV_DispatchThreadID) {
    if (id.x >= params.grid_width || id.y >= params.grid_height) return;
    let uv = (float2(id.xy) + 0.5) / float2(params.grid_width, params.grid_height);
    let aspect = float(params.grid_width) / max(float(params.grid_height), 1.0);
    let noise = ink_fbm(uv * float2(aspect, 1.0) * 7.0, params.random_seed);
    // Bias toward clear water while retaining connected ink structures.
    let ink = smoothstep(0.48, 0.78, noise);
    fluid_phase[cell_index(id.x, id.y)] = float2(ink, ink);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void particle_to_grid(uint3 id : SV_DispatchThreadID) {
    if (id.x >= params.particle_count) return;
    let particle = particles[id.x];
    if (particle._padding.x == 0u) return;
    let tau = -particle.time_residual / max(params.previous_dt, 1e-6);
    let wt = params.previous_dt > 0.0 ? temporal_weight(tau) : temporal_weight(0.0);
    let px = particle.position.x * float(params.grid_width);
    let py = particle.position.y * float(params.grid_height);
    let u_center = int2(round(px), floor(py));
    let v_center = int2(floor(px), round(py));
    for (var oy = -1; oy <= 1; oy++) for (var ox = -1; ox <= 1; ox++) {
        let up = u_center + int2(ox, oy);
        if (up.x >= 0 && up.x <= int(params.grid_width) && up.y >= 0 && up.y < int(params.grid_height)) {
            let center = float2(float(up.x), float(up.y) + 0.5);
            let weight = poly6(px - center.x) * poly6(py - center.y) * wt;
            let mass = int(round(weight * FIXED_SCALE));
            let momentum = int(round(weight * particle.velocity.x * FIXED_SCALE));
            let index = u_index(uint(up.x), uint(up.y));
            InterlockedAdd(u_accum[index].x, mass);
            InterlockedAdd(u_accum[index].y, momentum);
        }
        let vp = v_center + int2(ox, oy);
        if (vp.x >= 0 && vp.x < int(params.grid_width) && vp.y >= 0 && vp.y <= int(params.grid_height)) {
            let center = float2(float(vp.x) + 0.5, float(vp.y));
            let weight = poly6(px - center.x) * poly6(py - center.y) * wt;
            let mass = int(round(weight * FIXED_SCALE));
            let momentum = int(round(weight * particle.velocity.y * FIXED_SCALE));
            let index = v_index(uint(vp.x), uint(vp.y));
            InterlockedAdd(v_accum[index].x, mass);
            InterlockedAdd(v_accum[index].y, momentum);
        }
    }
}

[shader("compute")]
[numthreads(16, 16, 1)]
void normalize_and_divergence(uint3 id : SV_DispatchThreadID) {
    if (id.x > params.grid_width || id.y > params.grid_height) return;
    if (id.x <= params.grid_width && id.y < params.grid_height) {
        let index = u_index(id.x, id.y);
        let accum = u_accum[index];
        var deposited = accum.x > 0 ? float(accum.y) / float(accum.x) : 0.0;
        if (id.x == 0 || id.x == params.grid_width) deposited = 0.0;
        // Capture u* from this P2G transfer before projection. The FLIP
        // increment is u^(n+1)-u*, not a difference between frame grids.
        u_velocity[index] = float2(deposited, deposited);
    }
    if (id.x < params.grid_width && id.y <= params.grid_height) {
        let index = v_index(id.x, id.y);
        let accum = v_accum[index];
        var deposited = accum.x > 0 ? float(accum.y) / float(accum.x) : 0.0;
        if (id.y == 0 || id.y == params.grid_height) deposited = 0.0;
        v_velocity[index].y = deposited;
        v_velocity[index].x = deposited - params.gravity * params.dt;
        if (id.y == 0 || id.y == params.grid_height) v_velocity[index].x = 0.0;
    }
    if (id.x >= params.grid_width || id.y >= params.grid_height) return;
    let ci = cell_index(id.x, id.y);
    let mass = float(u_accum[u_index(id.x, id.y)].x + u_accum[u_index(id.x + 1u, id.y)].x +
                     v_accum[v_index(id.x, id.y)].x + v_accum[v_index(id.x, id.y + 1u)].x) * 0.25 * INV_FIXED_SCALE;
    // Equation 13: the cell-centered phase is used only to classify liquid
    // cells. Face phases below are retained for the variable-coefficient PPE.
    let density = phase_from_mass(mass);
    var divergence = (u_velocity[u_index(id.x + 1u, id.y)].x - u_velocity[u_index(id.x, id.y)].x +
                      v_velocity[v_index(id.x, id.y + 1u)].x - v_velocity[v_index(id.x, id.y)].x) / params.cell_size;
    cells[ci] = float4(density, 0.0, 0.0, divergence);
}

[shader("compute")]
[numthreads(16, 16, 1)]
void pressure_jacobi(uint3 id : SV_DispatchThreadID) {
    if (id.x >= params.grid_width || id.y >= params.grid_height) return;
    let index = cell_index(id.x, id.y);
    let cell = cells[index];
    if (cell.x < 0.5) { cells[index].z = 0.0; return; }
    var sum = 0.0;
    var diagonal = 0.0;
    // Equations 14-15 with unit liquid density and aperture: beta=1/phi_f.
    // Air is a zero-pressure Dirichlet neighbor; domain walls are Neumann.
    if (id.x > 0) { let beta = 1.0 / max(u_phase(id.x, id.y), PHASE_DENSITY_EPSILON); let n = cells[cell_index(id.x - 1u, id.y)]; sum += beta * (n.x >= 0.5 ? n.y : 0.0); diagonal += beta; }
    if (id.x + 1u < params.grid_width) { let beta = 1.0 / max(u_phase(id.x + 1u, id.y), PHASE_DENSITY_EPSILON); let n = cells[cell_index(id.x + 1u, id.y)]; sum += beta * (n.x >= 0.5 ? n.y : 0.0); diagonal += beta; }
    if (id.y > 0) { let beta = 1.0 / max(v_phase(id.x, id.y), PHASE_DENSITY_EPSILON); let n = cells[cell_index(id.x, id.y - 1u)]; sum += beta * (n.x >= 0.5 ? n.y : 0.0); diagonal += beta; }
    if (id.y + 1u < params.grid_height) { let beta = 1.0 / max(v_phase(id.x, id.y + 1u), PHASE_DENSITY_EPSILON); let n = cells[cell_index(id.x, id.y + 1u)]; sum += beta * (n.x >= 0.5 ? n.y : 0.0); diagonal += beta; }
    cells[index].z = (sum - cell.w * params.cell_size * params.cell_size / max(params.dt, 1e-6)) / max(diagonal, 1.0);
}

[shader("compute")]
[numthreads(256, 1, 1)]
void pressure_commit(uint3 id : SV_DispatchThreadID) {
    if (id.x >= params.grid_width * params.grid_height) return;
    cells[id.x].y = cells[id.x].z;
}

[shader("compute")]
[numthreads(16, 16, 1)]
void project_velocity(uint3 id : SV_DispatchThreadID) {
    if (id.x <= params.grid_width && id.y < params.grid_height) {
        let index = u_index(id.x, id.y);
        if (id.x == 0 || id.x == params.grid_width) u_velocity[index].x = 0.0;
        else {
            let left = cells[cell_index(id.x - 1u, id.y)];
            let right = cells[cell_index(id.x, id.y)];
            let density = max(left.x, right.x);
            if (density >= 0.5) {
                let beta = 1.0 / max(u_phase(id.x, id.y), PHASE_DENSITY_EPSILON);
                u_velocity[index].x -= params.dt * beta * (right.y - left.y) / params.cell_size;
            }
        }
    }
    if (id.x < params.grid_width && id.y <= params.grid_height) {
        let index = v_index(id.x, id.y);
        if (id.y == 0 || id.y == params.grid_height) v_velocity[index].x = 0.0;
        else {
            let bottom = cells[cell_index(id.x, id.y - 1u)];
            let top = cells[cell_index(id.x, id.y)];
            let density = max(bottom.x, top.x);
            if (density >= 0.5) {
                let beta = 1.0 / max(v_phase(id.x, id.y), PHASE_DENSITY_EPSILON);
                v_velocity[index].x -= params.dt * beta * (top.y - bottom.y) / params.cell_size;
            }
        }
    }
}

// Extend both the current and previous grid velocity a few cells beyond the
// particle-supported faces. FLIP needs this safety band: particles near the
// free surface otherwise interpolate zeros and the surface progressively
// tears apart. u/v accumulator mass doubles as the face-validity mask.
[shader("compute")]
[numthreads(16, 16, 1)]
void extrapolate_velocities(uint3 id : SV_DispatchThreadID) {
    if (id.x <= params.grid_width && id.y < params.grid_height) {
        let index = u_index(id.x, id.y);
        if (u_accum[index].x <= 0 && id.x > 0 && id.x < params.grid_width) {
            var sum = float2(0.0);
            var count = 0.0;
            if (id.x > 0) { let ni = u_index(id.x - 1u, id.y); if (u_accum[ni].x > 0) { sum += u_velocity[ni]; count += 1.0; } }
            if (id.x < params.grid_width) { let ni = u_index(id.x + 1u, id.y); if (u_accum[ni].x > 0) { sum += u_velocity[ni]; count += 1.0; } }
            if (id.y > 0) { let ni = u_index(id.x, id.y - 1u); if (u_accum[ni].x > 0) { sum += u_velocity[ni]; count += 1.0; } }
            if (id.y + 1u < params.grid_height) { let ni = u_index(id.x, id.y + 1u); if (u_accum[ni].x > 0) { sum += u_velocity[ni]; count += 1.0; } }
            if (count > 0.0) { u_velocity[index] = sum / count; u_accum[index].x = 1; }
        }
    }
    if (id.x < params.grid_width && id.y <= params.grid_height) {
        let index = v_index(id.x, id.y);
        if (v_accum[index].x <= 0 && id.y > 0 && id.y < params.grid_height) {
            var sum = float2(0.0);
            var count = 0.0;
            if (id.x > 0) { let ni = v_index(id.x - 1u, id.y); if (v_accum[ni].x > 0) { sum += v_velocity[ni]; count += 1.0; } }
            if (id.x + 1u < params.grid_width) { let ni = v_index(id.x + 1u, id.y); if (v_accum[ni].x > 0) { sum += v_velocity[ni]; count += 1.0; } }
            if (id.y > 0) { let ni = v_index(id.x, id.y - 1u); if (v_accum[ni].x > 0) { sum += v_velocity[ni]; count += 1.0; } }
            if (id.y < params.grid_height) { let ni = v_index(id.x, id.y + 1u); if (v_accum[ni].x > 0) { sum += v_velocity[ni]; count += 1.0; } }
            if (count > 0.0) { v_velocity[index] = sum / count; v_accum[index].x = 1; }
        }
    }
}

[shader("compute")]
[numthreads(16, 16, 1)]
void advect_fluid_phase(uint3 id : SV_DispatchThreadID) {
    if (id.x >= params.grid_width || id.y >= params.grid_height) return;
    let index = cell_index(id.x, id.y);
    let position = (float2(id.xy) + 0.5) / float2(params.grid_width, params.grid_height);
    let midpoint = clamp(position - 0.5 * params.dt * sample_velocity(position, false), params.cell_size, 1.0 - params.cell_size);
    let backtraced = clamp(position - params.dt * sample_velocity(midpoint, false), params.cell_size, 1.0 - params.cell_size);
    var ink = sample_ink(backtraced) * exp(-params.ink_dissipation * params.dt);
    if (params.cursor_active != 0u) {
        let distance = brush_distance(position);
        if (distance < params.brush_size) {
            let falloff = 1.0 - distance / max(params.brush_size, 1e-5);
            if (params.cursor_mode == 1u) ink += params.brush_strength * falloff * params.dt;
            if (params.cursor_mode == 2u) ink -= params.brush_strength * falloff * params.dt;
        }
    }
    fluid_phase[index].y = clamp(ink, 0.0, 1.0);
}

[shader("compute")]
[numthreads(256, 1, 1)]
void commit_fluid_phase(uint3 id : SV_DispatchThreadID) {
    if (id.x >= params.grid_width * params.grid_height) return;
    fluid_phase[id.x].x = fluid_phase[id.x].y;
}

[shader("compute")]
[numthreads(256, 1, 1)]
void render_fluid_phase(uint3 id : SV_DispatchThreadID) {
    if (id.x >= params.grid_width * params.grid_height) return;
    render_density[id.x] = uint(round(clamp(fluid_phase[id.x].x, 0.0, 1.0) * 4.0));
}

[shader("compute")]
[numthreads(64, 1, 1)]
void grid_to_particles_advect(uint3 id : SV_DispatchThreadID) {
    if (id.x >= params.particle_count) return;
    var particle = particles[id.x];
    if (particle._padding.x == 0u) return;
    let pic = sample_velocity(particle.position, false);
    let old_grid = sample_velocity(particle.position, true);
    let flip = particle.velocity + (pic - old_grid);
    particle.velocity = lerp(pic, flip, params.flip_ratio);
    if (params.cursor_active != 0u) {
        let distance = brush_distance(particle.position);
        if (distance < params.brush_size) {
            let falloff = 1.0 - distance / max(params.brush_size, 1e-5);
            if (params.cursor_mode == 0u || params.cursor_mode == 1u) {
                particle.velocity += params.cursor_velocity * params.brush_strength * falloff * params.dt;
            } else if (params.cursor_mode == 3u) {
                let aspect = float(params.grid_width) / max(float(params.grid_height), 1.0);
                var radial = particle.position - params.cursor;
                radial.x *= aspect;
                let radial_length = max(length(radial), 1e-5);
                let tangent_physical = float2(-radial.y, radial.x) / radial_length;
                let tangent_world = float2(tangent_physical.x / aspect, tangent_physical.y);
                particle.velocity += tangent_world * params.brush_strength * falloff * params.dt;
            }
        }
    }
    // Fast pointer motion can otherwise inject arbitrarily large velocities.
    // Enforce the user-facing CFL ceiling before advection so positions remain
    // finite and subsequent particle-to-grid indices stay inside GPU buffers.
    let speed = length(particle.velocity);
    let max_speed = params.target_cfl * params.cell_size / max(params.dt, 1e-6);
    if (speed > max_speed && speed > 1e-6) {
        particle.velocity *= max_speed / speed;
    }
    let local_cfl = length(particle.velocity) * params.dt / max(params.cell_size, 1e-6);
    let gamma = params.jitter_strength * smooth_cfl(local_cfl);
    let xi = random01(particle.random_state) - 0.5;
    let actual_dt = clamp(params.dt + particle.time_residual + gamma * xi * params.dt, 0.0, 2.0 * params.dt);
    particle.time_residual = params.dt + particle.time_residual - actual_dt;
    let midpoint = clamp(particle.position + 0.5 * actual_dt * sample_velocity(particle.position, false), params.cell_size, 1.0 - params.cell_size);
    particle.position += actual_dt * sample_velocity(midpoint, false);
    let lower = params.cell_size;
    let upper = 1.0 - params.cell_size;
    // Solid collision: clamp position and remove only inward normal momentum.
    // Retaining that momentum makes floor particles redeposit a downward
    // velocity forever, collapsing the represented liquid volume.
    if (particle.position.x < lower) { particle.position.x = lower; particle.velocity.x = max(particle.velocity.x, 0.0); }
    if (particle.position.x > upper) { particle.position.x = upper; particle.velocity.x = min(particle.velocity.x, 0.0); }
    if (particle.position.y < lower) { particle.position.y = lower; particle.velocity.y = max(particle.velocity.y, 0.0); }
    if (particle.position.y > upper) { particle.position.y = upper; particle.velocity.y = min(particle.velocity.y, 0.0); }
    particles[id.x] = particle;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void render_particles(uint3 id : SV_DispatchThreadID) {
    if (id.x >= params.particle_count) return;
    let particle = particles[id.x];
    if (particle._padding.x == 0u) return;
    let synchronized = clamp(particle.position + particle.time_residual * sample_velocity(particle.position, false), 0.0, 0.999999);
    let x = min(uint(synchronized.x * float(params.grid_width)), params.grid_width - 1u);
    let y = min(uint(synchronized.y * float(params.grid_height)), params.grid_height - 1u);
    // Compact render reconstruction. Simulation positions remain untouched;
    // only the temporarily re-synchronized position is splatted.
    for (var oy = -1; oy <= 1; oy++) for (var ox = -1; ox <= 1; ox++) {
        let sx = clamp(int(x) + ox, 0, int(params.grid_width) - 1);
        let sy = clamp(int(y) + oy, 0, int(params.grid_height) - 1);
        let contribution = (ox == 0 && oy == 0) ? 4u : ((ox == 0 || oy == 0) ? 2u : 1u);
        InterlockedAdd(render_density[cell_index(uint(sx), uint(sy))], contribution);
    }
}
