# GPU Profiling

VizzaOdin has two GPU profiling paths:

- in-app Vulkan timestamp queries exposed through frame stats and MCP status;
- external Xcode Instruments captures, usually with `Metal System Trace`, for
  MoltenVK/Metal queue and encoder details.

## In-App GPU Timings

When the selected Vulkan device supports timestamp queries, the app records
coarse GPU timings for each submitted frame without waiting for query results on
the hot path. Results are read when a frame slot's fence has already completed,
so reported values can lag the current frame by a small number of frames.

The MCP `app_status` JSON includes:

- `gpu_profiling_supported`
- `gpu_profiling_enabled`
- `gpu_simulation_step_ms`
- `gpu_simulation_present_ms`
- `gpu_ui_overlay_ms`
- `gpu_frame_total_ms`

The MCP also exposes a UI/render profile session:

- `profile_start`
- `profile_status`
- `profile_report`
- `profile_reset`

`profile_start` accepts `mode`, optional `frames` (default `240`), and optional
sanitizer thresholds such as `ui_spike_ms`, `render_spike_ms`,
`gpu_ui_spike_ms`, `screenshot_spike_ms`, `cap_ratio`,
`text_calls_per_frame`, and `min_width_cache_hit_rate`. Collection is
nonblocking: the app switches to the requested mode, waits until frame stats
report that mode, then accumulates stats as frames continue rendering.

`ui_build` is intentionally CPU-only and is not included as a GPU pass.

## Instruments Capture

Use the helper script for repeatable GPU captures:

```sh
make build
scripts/profile_gpu_trace.sh --duration 30s --output profiles/vizzaodin-metal.trace
```

To attach to an existing app process:

```sh
scripts/profile_gpu_trace.sh \
  --attach <pid-or-process-name> \
  --duration 2m \
  --output profiles/vizzaodin-pl-metal-2min.trace
```

The default template is `Metal System Trace`. To try Xcode's game-focused
template:

```sh
scripts/profile_gpu_trace.sh --template "Game Performance" --duration 45s
```

The script supplies the Homebrew MoltenVK loader environment when launching the
app. When attaching, launch the app however you normally do, then attach by PID
or process name.

For UI/render profiling, start the app in MCP mode and attach to that live
process:

```sh
make mcp
```

From an MCP client, start a bounded profile:

```json
{"name":"profile_start","arguments":{"mode":"Particle_Life","frames":240}}
```

Then attach Instruments while the app profile is active:

```sh
make profile-ui-trace DURATION=30s OUTPUT=profiles/vizzaodin-ui-render.trace
```

Poll completion and read the in-app sanitizer report:

```json
{"name":"profile_status","arguments":{}}
{"name":"profile_report","arguments":{}}
```

Use the global Instruments MCP to inspect the captured trace:

```json
{"name":"open_trace","arguments":{"path":"/Users/zelda/Documents/VizzaOdin/profiles/vizzaodin-ui-render.trace"}}
{"name":"summarize_gpu","arguments":{"trace_id":"<returned trace_id>"}}
```

The VizzaOdin app MCP intentionally does not parse `.trace` bundles; keep trace
inspection in `/Users/zelda/Agents/mcps/instruments_mcp`.

## Particle Life Stress Workflow

1. Start the app in MCP mode:

   ```sh
   make build
   VK_ICD_FILENAMES="$(brew --prefix molten-vk)/etc/vulkan/icd.d/MoltenVK_icd.json" \
   DYLD_LIBRARY_PATH="$(brew --prefix molten-vk)/lib:$(brew --prefix vulkan-loader)/lib" \
   build/vizzaodin --mcp
   ```

2. Use the MCP `click` tool to select `Particle Life` from the main menu, or
   select it manually in the app.
3. Confirm `app_status` reports `app_mode:"Particle_Life"`,
   `particle_life_ready:true`, and the expected particle count.
4. Attach a GPU trace:

   ```sh
   scripts/profile_gpu_trace.sh \
     --attach vizzaodin \
     --duration 2m \
     --output profiles/vizzaodin-pl-metal-2min.trace
   ```

5. Compare the Instruments trace against the in-app fields:
   `gpu_simulation_step_ms`, `gpu_simulation_present_ms`,
   `gpu_ui_overlay_ms`, and `gpu_frame_total_ms`.

## Labels

If `VK_EXT_debug_utils` is available and MoltenVK forwards labels to Metal
tooling, captures may include labels such as:

- `Simulation step`
- `Simulation present`
- `Particle Life: grid clear`
- `Particle Life: grid scatter`
- `Particle Life: force compute`
- `Particle Life: collision solve/apply`
- `Particle Life: copy scratch`
- `Particle Life: present`
- `UI overlay`

If labels do not appear, the capture is still useful; inspect command buffer,
encoder, present, and queue occupancy tables.
