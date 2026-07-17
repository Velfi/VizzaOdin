![VizzaOdin Logo](icon.png)

# VizzaOdin

An Odin/Slang port of [Vizza](https://github.com/Velfi/Vizza), a collection of
interactive GPU-accelerated simulations for fun and beauty. The port keeps the
original simulations as the behavior reference while replacing the Tauri,
Svelte, Rust, and WebGPU stack with a native SDL3/Vulkan app and a
project-owned immediate-mode UI.

## How to play

Download the latest package from the
[releases page](https://github.com/Velfi/VizzaOdin/releases).

- For macOS: download `vizza-<version>-macos.zip`, unzip it, and open
  `Vizza.app`.
- The packaged app targets macOS 13 or newer and bundles its shaders, assets,
  SDL3, Vulkan loader, and MoltenVK runtime files.
- For Windows: download `vizza-<version>-windows-x64.zip`, unzip it, and run
  `Vizza.exe`.
- The Windows package bundles its shaders, assets, SDL3, HarfBuzz, Freetype,
  and Vulkan loader runtime files. It still requires a Vulkan-capable GPU
  driver.
- Windows releases also include `vizza-<version>-windows-x64.msix` for
  Microsoft Store submission or signed sideloading.

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

### Voronoi

Nearest-site Voronoi regions with drifting points, color-map modes, and
optional borders.

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
- On Windows: Visual Studio Build Tools, vcpkg packages for `sdl3`,
  `harfbuzz`, `freetype`, and `vulkan-loader`, plus Git Bash for shader builds
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
pwsh ./scripts/package_windows.ps1 -Msix
```

`make build` writes the native executable to `build/vizzaodin`.
`make package-macos` creates `dist/Vizza.app` and
`dist/Vizza-macos.zip`; signing and notarization are configured through the
environment variables documented in [docs/release.md](docs/release.md).
`scripts/package_windows.ps1` creates `dist/Vizza-windows/`,
`dist/Vizza-windows.zip`, and, with `-Msix`, `dist/Vizza-windows.msix`.

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
make steam-upload-preview VERSION=0.1.0
pwsh ./scripts/package_windows.ps1 -Msix
scripts/release.sh 0.1.0
```

Particle Life GPU performance can be measured without the application UI:

```bash
make perf-particle-life
make perf-particle-life ARGS="--particles=10000,50000 --ranges=0.05,0.2,0.4 --iterations=50"
```

The harness uses a hidden Vulkan window and prints CSV rows containing the grid
shape plus mean, median, p95, and maximum synchronized step time. Pass
`--no-collisions` to isolate the force pass.
Pass `--churn` to cycle through the supplied ranges every step and report how
many times the grid resource was recreated.

### Test policy

Tests protect durable behavior: simulation correctness, saved-data compatibility,
input ownership, focus and modal safety, accessibility, and layout bounds. They
should assert user-visible outcomes rather than preserve the Rust port's exact
menu order, labels, colors, spacing, draw-command sequence, default aesthetic,
or physical key assignments.

Legacy preset migration remains supported behavior. Historical appearance and
layout are not compatibility contracts; redesigns may replace them without
adding tests that reproduce the former implementation.

Steam commands default to app ID `4945920`; override with `STEAM_APP_ID=...`
for alternate targets. SteamPipe uploads use main app ID `4945920`, Windows
depot `4945921`, macOS depot `4945922`, Playtest AppID `4946320`, and Playtest
depot `4946321` from `packaging/steam/targets.env`.

To smoke-test a local SteamPipe upload package, first build the app bundle with
Steam support, then run the preview uploader:

```bash
SKIP_SIGN=1 SKIP_NOTARIZE=1 scripts/package_macos.sh --steam
pwsh ./scripts/package_windows.ps1
scripts/steam-upload.sh --preview --local 0.1.0
```

For a real upload from a GitHub release asset:

```bash
STEAM_BUILD_USER=vizza_ci scripts/steam-upload.sh --beta 0.1.0
```

See [docs/steam-uploads.md](docs/steam-uploads.md), [docs/mcp.md](docs/mcp.md),
[docs/gpu-profiling.md](docs/gpu-profiling.md), and
[docs/ui-theme-preview.md](docs/ui-theme-preview.md) for the Steam upload,
MCP, profiling, and UI preview workflows.

### Project layout

- `src`: minimal executable entrypoint and integration tests
- `packages/app`: executable composition and command-line policy
- `packages/game`: Vizza simulations, product policy, and product command/event
  payloads
- `packages/engine`: queues, Vulkan context/resources, shader lookup,
  screenshots, logging, and profiling
- `packages/render_vk`: Vulkan render graph, simulation render adapters, and
  lowering for renderer-neutral UI commands
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
- Packaging: Make plus signed/notarized macOS app bundles, Windows zip
  archives, and Windows MSIX packages

See [docs/dependency-map.md](docs/dependency-map.md) for the dependency
translation from the original Tauri/Svelte/Rust project, and
[docs/package-architecture.md](docs/package-architecture.md) for current package
ownership and dependency rules.
