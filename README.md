![VizzaOdin Logo](icon.png)

# VizzaOdin

An Odin/Slang port of [Vizza](https://github.com/Velfi/Vizza), a collection of
interactive GPU-accelerated simulations for fun and beauty. The port keeps the
original simulations as the behavior reference while replacing the Tauri,
Svelte, Rust, and WebGPU stack with a native SDL3/Vulkan app and a
project-owned immediate-mode UI.

## How to play

VizzaOdin releases are currently macOS-only.

Download the latest macOS package from the
[releases page](https://github.com/Velfi/VizzaOdin/releases).

- For macOS: download `vizza-<version>-macos.zip`, unzip it, and open
  `Vizza.app`.
- The packaged app targets macOS 13 or newer and bundles its shaders, assets,
  SDL3, Vulkan loader, and MoltenVK runtime files.

For the original cross-platform Tauri app, download Vizza from the
[original releases page](https://github.com/Velfi/Vizza/releases).

## Simulations

Screenshots below come from the original Vizza app where matching README images
already exist.

### Slime Mold

Agent-based simulation where creatures follow trails to create emergent
transport networks.

![Slime Mold Example](https://raw.githubusercontent.com/Velfi/Vizza/main/example-slime-mold.png)

### Gray-Scott

Reaction-diffusion simulation modeling chemicals that create cellular islands,
waves, and turbulent organic patterns.

![Gray-Scott Example](https://raw.githubusercontent.com/Velfi/Vizza/main/example-gray-scott.png)

### Particle Life

Multi-species particle simulation with attraction and repulsion interactions.

![Particle Life Example](https://raw.githubusercontent.com/Velfi/Vizza/main/example-particle-life.png)

### Flow Field

Particles trace a changing vector field, revealing direction through layered
motion trails.

![Flow Field Example](https://raw.githubusercontent.com/Velfi/Vizza/main/example-flow-mode.png)

### Pellets

Lightweight 2D particle physics with density, collisions, gravity, and
image-like emergent texture.

![Pellets Example](https://raw.githubusercontent.com/Velfi/Vizza/main/example-pellets-mode.png)

### Gradient Editor

Create and inspect color ramps used by the simulations and post-processing
passes.

![Gradient Editor Example](https://raw.githubusercontent.com/Velfi/Vizza/main/example-gradient-editor.png)

### Voronoi CA

Cellular automata playground driven by nearest-neighbor Voronoi regions and
local state transitions.

### Moire

Interference patterns from layered wave fields, offsets, distortion, and
procedural image sampling.

![Moire Example](https://raw.githubusercontent.com/Velfi/Vizza/main/example-moire.png)

### Vectors

Vector-field inspection for direction, magnitude, and dense line rendering.

### Primordial

Particle motion organized by local density, soft attraction, and primordial
clustering.

## For Developers

### Prerequisites

- [Odin](https://odin-lang.org/)
- `make`, `cc`, `git`, and `pkg-config`
- SDL3, Vulkan loader, HarfBuzz, and Freetype development packages
- On macOS: MoltenVK and Homebrew packages matching the release workflow:
  `odin`, `sdl3`, `molten-vk`, `vulkan-loader`, `harfbuzz`, `freetype`,
  `pkg-config`, and `imagemagick`
- Slang compiler on `PATH`, or use `make install-slangc` to install the pinned
  compiler into `.tools/slang`

### Development

```bash
make deps
make install-slangc
make run
```

`make deps` downloads the pinned `third_party/tomlc17` checkout and builds the
local text-shaping shim. `make run` compiles shaders, builds the app, and runs
`build/vizzaodin`.

### Build

```bash
make build
make package-macos
```

`make build` writes the native executable to `build/vizzaodin`.
`make package-macos` creates `dist/Vizza.app` and
`dist/Vizza-macos.zip`; signing and notarization are configured through the
environment variables documented in [docs/release.md](docs/release.md).

### Useful commands

```bash
make check
make test
make fmt
make shaders
make mcp
make theme-preview
make theme-preview-mcp
make run-steam
make build-steam
```

Steam commands default to app ID `4945920`; override with `STEAM_APP_ID=...`
for test apps or alternate branches.

See [docs/mcp.md](docs/mcp.md), [docs/gpu-profiling.md](docs/gpu-profiling.md),
and [docs/ui-theme-preview.md](docs/ui-theme-preview.md) for the MCP,
profiling, and UI preview workflows.

### Project layout

- `src`: executable entrypoint and integration tests
- `packages/game`: app flow, simulations, settings, render graph, render worker,
  Steam integration, video recording, and MCP bridge
- `packages/engine`: queues, Vulkan context/resources, shader lookup,
  screenshots, logging, profiling, and UI rendering
- `packages/ui`: renderer-agnostic immediate-mode UI primitives and widgets
- `assets`: Slang shaders, LUTs, fonts, and app media
- `docs`: architecture, release, MCP, profiling, and dependency notes

## Tech Stack

- Language: Odin
- Window/input: SDL3
- Graphics and compute: Vulkan through `vendor:vulkan`
- Shaders: Slang compiled to SPIR-V
- UI: project-owned immediate-mode GUI
- Settings and presets: TOML via pinned `tomlc17`
- Packaging: Make plus signed/notarized macOS app bundles

See [docs/dependency-map.md](docs/dependency-map.md) for the dependency
translation from the original Tauri/Svelte/Rust project.
