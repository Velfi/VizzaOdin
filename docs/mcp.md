# VizzaOdin MCP Control

`build/vizzaodin --mcp` runs the native app as a stdio MCP server. The MCP
client launches the app process, sends JSON-RPC on stdin, and receives JSON-RPC
on stdout. App diagnostics are written to stderr in MCP mode so stdout remains
valid MCP traffic.

## Tools

- `app_status`: read status from the running app.
- `profile_start`: switch to a mode and begin a nonblocking UI/render profile
  over a fixed frame window. Defaults to 240 frames.
- `profile_status`: read profile collection progress.
- `profile_report`: return aggregate UI/render timings, command counts, text
  shaping metrics, GPU UI overlay timing, and sanitizer findings.
- `profile_reset`: clear the current profile session.
- `screenshot`: return the latest engine-rendered frame as a base64 QOI data
  URL from Vulkan swapchain readback. Optional arguments `scale`, `max_width`,
  and `max_height` reduce the returned image dimensions and payload size.
- `list_ui_components`: list fixtures and deterministic visual states exposed
  by the isolated component renderer.
- `render_ui_component`: select a single component, state, and optional value;
  the next frames render it in `Theme_Preview` through the production UI path.
- `configure_particle_life`: apply a Particle Life capture/configuration blob.
  This starts from Particle Life defaults, then applies any supplied fields:
  `particle_count`, `species_count`, `position_generator`, `type_generator`,
  `force_generator`, `force_random_min`, `force_random_max`,
  `randomize_forces`, `reset`, `hide_ui`, and `set_mode`. Generator values can
  be names or indexes.
- `configure_simulation`: apply a flat capture/configuration blob to any
  simulation except Gradient Editor. It starts from that simulation's defaults,
  applies supplied fields, and supports `reset`, `hide_ui`, and `set_mode`.
- Per-simulation config aliases: `configure_gray_scott`,
  `configure_flow_field`, `configure_slime_mold`, `configure_pellets`,
  `configure_voronoi`, `configure_moire`, `configure_vectors`, and
  `configure_primordial`.
- `click`: inject a window-relative click through the app input path.
- `move`: update the app's logical mouse position.
- `wheel`: inject mouse wheel delta.
- `close_app`: ask the app to close.

The profile tools are passive once started: the app continues rendering normally
and frame stats are accumulated as `Frame_Stats` messages reach the UI thread.
The sanitizer reports warnings only; it does not fail or alter the simulation.

No filesystem transport, OS screenshot API, Accessibility automation, or
loopback socket is used by this MCP mode.

## Particle Life Capture Blob

Use one `configure_particle_life` call per shot, then wait for warmup frames and
call `screenshot` with an `output_path`:

```json
{
  "species_count": 6,
  "particle_count": 15000,
  "position_generator": "Center",
  "type_generator": "Random",
  "force_generator": "Random",
  "force_random_min": -1.0,
  "force_random_max": 1.0,
  "randomize_forces": true,
  "reset": true,
  "hide_ui": true,
  "set_mode": true
}
```

For the Steam capture pass, vary `species_count` between 4 and 8 and keep
`position_generator` at `"Center"`. The randomized force matrix is generated
inside the app, so callers do not need to pass an 8x8 matrix unless a future
capture requires exact reproducibility.

## Generic Capture Blob

Use `configure_simulation` with a `mode` field, or call a per-simulation alias
without `mode`. Config blobs are flat JSON objects; enum-like values can be
numeric indexes or display names.

```json
{
  "mode": "Flow_Field",
  "noise_kind": "Simplex",
  "fractal_mode": "FBM",
  "warp_mode": "Recursive",
  "seed": 12345,
  "frequency": 7.5,
  "noise_strength": 1.0,
  "vector_magnitude": 0.14,
  "particle_count": 100000,
  "particle_speed": 1.2,
  "trail_decay_rate": 0.02,
  "trail_deposition_rate": 1.0,
  "color_scheme": "MATPLOTLIB_cubehelix",
  "reversed": true,
  "reset": true,
  "hide_ui": true,
  "set_mode": true
}
```

## Client Config

Build the app first:

```sh
make build
```

Then register the MCP server with a client that supports stdio MCP:

```json
{
  "mcpServers": {
    "vizzaodin": {
      "command": "/Users/zelda/Documents/VizzaOdin/build/vizzaodin",
      "args": ["--mcp"]
    }
  }
}
```

You can also run it directly for debugging:

```sh
make mcp
```

On Homebrew macOS Vulkan setups, use the same MoltenVK environment as the app
run target:

```sh
make mcp-macos-vulkan
```

MCP clients that support an `env` block can use the same `VK_ICD_FILENAMES` and
`DYLD_LIBRARY_PATH` values from `make run-macos-vulkan`.

## Related MCP Designs

- `docs/instruments-mcp-design.md`: generic offline MCP inspector design for
  Xcode Instruments `.trace`/`.instruments` captures.
- `/Users/zelda/Agents/mcps/instruments_mcp/README.md`: project-neutral MCP
  server that can be registered once and used across workspaces.
