# 2D ST-FLIP implementation

This document fixes the numerical and product contract for VizzaOdin's 2D
ST-FLIP simulation. The implementation follows Braun et al., "Spatiotemporal
FLIP for Fast Free-Surface and Two-Phase Simulation With Very Large Time
Steps" (2026), specialized from three spatial dimensions to two.

## Scope

- Free-surface liquid in a rectangular 2D domain.
- Particles carry position, velocity, and the ST-FLIP temporal residual.
- A staggered MAC grid carries face velocity, mass/momentum accumulators, and
  pressure-projection coefficients.
- The simulation produces a scalar grayscale render field. Color is applied
  only by the presentation shader through the current color-scheme LUT.
- Settings contain only user-authored, serializable parameters. Particles,
  grids, counters, solver scratch space, and interaction impulses are runtime
  state and must never be written to presets.

This is not a stable-fluids dye solver and temporal jitter alone is not called
ST-FLIP. The temporal kernel, residual carryover, phase-weighted projection,
and FLIP update are required parts of the feature.

## Particle state

Each particle stores:

```text
position         float2
velocity         float2
time_residual    float
random_state     uint
```

`time_residual` is the paper's delta-t residual. It is initialized to zero.
Random state is runtime-only and makes runs reproducible for a saved seed.

## Grid state

For a grid of `width * height` cells:

```text
u velocity and previous u velocity       (width + 1) * height
v velocity and previous v velocity       width * (height + 1)
u mass/momentum accumulator              (width + 1) * height
v mass/momentum accumulator              width * (height + 1)
cell phase and pressure                   width * height
pressure scratch and divergence           width * height
render density                            width * height
```

Face mass accumulators are retained through projection because they define the
space-time phase field and variable projection coefficients.

## One simulation step

1. Choose a globally adaptive step from the previous maximum velocity and the
   target CFL. Quantize it so the remaining display-frame interval is divided
   into equal steps.
2. Clear grid accumulators.
3. Deposit every particle to neighboring U and V faces. Multiply the separable
   2D spatial Poly6 weight by the one-sided temporal Poly6 weight.
4. Normalize deposited momentum to provisional face velocity and derive cell
   phase values from the same mass weights.
5. Apply gravity and queued interaction impulses to grid velocity.
6. Form divergence and solve the phase-weighted pressure Poisson equation.
7. Project face velocity and extrapolate valid liquid velocity into a narrow
   band around the free surface.
8. Update particle velocity using a configurable PIC/FLIP blend. The default
   FLIP fraction is 0.98.
9. Compute adaptive jitter strength from local CFL, update the actual particle
   step and residual, then advect with locally sub-stepped RK3.
10. Enforce solid boundaries and update the maximum-velocity reduction.

### Spatial kernel

For one dimension:

```text
poly6(r) = max(0, (1 - r*r)^3)
```

The 2D spatial weight is the product of the X and Y weights. Normalization
constants cancel when normalizing face momentum, but the reference mass used
by the phase field must be calibrated using this exact discrete kernel.

### Temporal kernel

With `tau = -time_residual / previous_dt`:

```text
W_temporal(tau) = (35 / 16) * poly6(tau - 0.5), tau <= 0.5
                  0,                              otherwise
```

This one-sided, forward-weighted kernel is required. A symmetric temporal
kernel is specifically rejected because it produces the phase lag and surface
oscillation described in the paper.

### Residual carryover

For global step `dt`, uniform random `xi` in `[-0.5, 0.5]`, and adaptive
jitter strength `gamma`:

```text
jitter     = gamma * xi * dt
actual_dt  = clamp(dt + time_residual + jitter, 0, 2 * dt)
residual'  = dt + time_residual - actual_dt
```

The particle is advected for `actual_dt`, not `dt`. Omitting `residual'` is
naive jittering and allows particle sample times to random-walk.

### Phase field

The cell phase is obtained from deposited mass:

```text
phase = min(sqrt(mass / (phase_steepness * reference_mass)), 1)
```

The default `phase_steepness` is 0.5. Cells with phase below 0.5 are air and
use the free-surface Dirichlet condition `pressure = 0`.

### Projection

The pressure solve uses face coefficient:

```text
beta_face = aperture_face / max(liquid_density * phase_face, density_epsilon)
```

Only liquid cells participate in the linear system. The first GPU version may
use a fixed-count weighted Jacobi solve for predictable interactive cost. A
later PCG implementation can improve convergence without changing the feature
contract.

## Rendering

Rendering must not modify simulation particle positions. A render pass
temporarily re-synchronizes each particle to global time by advecting its
position by its residual, splats the result into a grayscale density target,
and smooths that target. The presentation shader clamps the scalar field to
`[0, 1]`, optionally reverses it, and samples the active color-scheme LUT.

This separation means changing color schemes does not reset or perturb the
simulation.

## Interaction

- Primary pointer/trigger injects liquid and momentum.
- Dragging stirs existing liquid using pointer velocity.
- Secondary pointer/trigger removes liquid.
- Reset creates the selected initial condition (dam break, pool, twin drops,
  or empty canvas).

Interaction requests are transient runtime impulses. Brush size and strength
are settings.

## Serializable settings

- color scheme and reversal
- grid quality preset
- particle count/particles per cell target
- target CFL
- simulation speed
- gravity
- PIC/FLIP blend
- jitter strength
- phase steepness
- pressure iteration count
- render smoothing strength
- brush size and strength
- initial-condition preset
- random seed
- paused state, following existing simulation convention

No particle positions, grid values, pressure state, time residual arrays,
dispatch counters, or focus/interaction state are serializable.

## Validation gates

1. With jitter strength zero, normalized P2G matches ordinary FLIP.
2. Mean actual particle step converges to the global step and residuals remain
   bounded under changing step sizes.
3. A closed-box projection reduces maximum divergence by at least two orders
   of magnitude at the default iteration count.
4. Particle and liquid volume remain bounded during a dam-break stress test.
5. At target CFL 8, ST-FLIP retains a smoother free surface than a standard
   FLIP toggle using the same grid, particles, and time steps.
6. Changing or reversing the color scheme changes presentation without
   changing particle or grid state.

