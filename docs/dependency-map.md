# Vizza to Odin Dependency Map

The original Vizza app is a Tauri + Svelte frontend wrapped around a Rust
`wgpu` simulation backend. For this rewrite, the target is a native Odin app:
no webview, no JavaScript build chain, Vulkan for graphics/compute, and a
project-owned immediate-mode GUI.

## Recommended Odin Stack

| Vizza dependency | Current role | Odin rewrite equivalent |
| --- | --- | --- |
| Svelte, TypeScript, Vite | Web UI and build tooling | Remove. Build UI in Odin as immediate-mode widgets. |
| Tauri, Tauri plugins | Desktop shell, webview, dialogs, shell/open helpers | Remove. Use `vendor:sdl3` for window/input/dialog-capable platform surface; add OS-specific helpers only when needed. |
| Rust `wgpu` | GPU device, queue, surfaces, compute/render pipelines, WGSL shaders | Replaced with `vendor:vulkan` plus SDL3 Vulkan surface helpers. Shaders are authored as Slang and compiled to SPIR-V. |
| `nokhwa` | Webcam capture | Prefer `vendor:sdl3` camera APIs first. Fall back to platform-specific capture only if SDL3 is insufficient. |
| `image` | Decode/resize/flip images for simulation masks/sources | `core:image/*` for PNG/JPEG/TGA/QOI/BMP, or `vendor:stb/image` for broader decode support. Write resize/filtering in Odin or use raylib/stb path if needed. |
| `serde`, `serde_json` | Settings/state serialization and command payloads | `core:encoding/json`; direct structs instead of command JSON once there is no frontend bridge. |
| `toml` | App settings/presets | Kept as TOML via downloaded `third_party/tomlc17`, wrapped by `packages/game/settings.odin`. |
| `rand` | Randomized presets, particle initialization | `core:math/rand`. |
| `noise` | Vector field noise | `core:math/noise` has OpenSimplex2; add custom helpers for exact old behavior if needed. |
| `bytemuck` | Plain-old-data casts for GPU buffers | Odin structs plus explicit byte slices/pointer casts; add alignment assertions around GPU-facing structs. |
| `include_dir`, `lazy_static` | Embedded LUT assets and one-time initialization | Odin compile-time embedding patterns and explicit initialization tables. |
| `tracing` | Logging | `core:log`, with small project wrappers if we want categories. |
| `thiserror` | Error types | Odin multiple returns, error enums, and logging context. |
| `tokio` | Async runtime around Tauri/backend tasks | Remove at first. Use the main loop plus `core:thread` only for camera/file tasks that prove they need it. |
| `lyon` | Path/tessellation support | Avoid initially. Add an Odin tessellator only if the GUI or simulations need complex vector paths. |
| `culori` | UI color interpolation/previews | Project color helpers in Odin; LUT interpolation is simple enough to own. |

## Native Architecture

1. `app`: SDL3 window, input polling, timing, app lifecycle.
2. `vk`: Vulkan instance/device/surface/swapchain, queues, command pools, descriptors, pipelines, buffers, images.
3. `sim`: simulation interface plus ports of Slime Mold, Gray-Scott, Particle Life, etc.
4. `ui`: custom immediate-mode GUI, command buffer, layout, widgets.
5. `assets`: LUTs, fonts, shader source, images.
6. `settings`: presets and app settings as TOML behind the settings facade.

## Vulkan Direction

Use SDL3 only for platform integration:

- Create the window with the Vulkan flag.
- Ask SDL3 for required Vulkan instance extensions.
- Create a Vulkan instance through `vendor:vulkan`.
- Create the `VkSurfaceKHR` with SDL3.
- Pick a physical device and queue families supporting graphics, compute, and present.
- Create the logical device with swapchain support.
- Build a swapchain, render pass or dynamic-rendering path, command pools, synchronization, and per-frame command buffers.

For simulations, prefer compute pipelines and storage images/buffers. The
original WGSL shaders are useful as algorithm references, but Vulkan wants
SPIR-V. The current path is Slang source in `assets/shaders` compiled with
`slangc` during the build.

## Immediate-Mode GUI Direction

The GUI is small and purpose-built:

- Own input state: mouse position, button transitions, wheel, keyboard text,
  keyboard navigation, and gamepad-to-navigation mappings.
- Track `hot` and `active` widget IDs.
- Emit renderer-neutral draw commands: rects, borders, text, images, scissor regions.
- Keep layout predictable: rows, columns, panels, collapsible sections.
- Current widgets cover buttons, toggles, checkboxes, switches, radio groups,
  sliders, number drags, selectors, comboboxes, HSV color controls, image
  samples, progress indicators, panels, cards, and collapsibles.
- Render through the Vulkan UI renderer after simulation rendering.

This keeps the rewrite honest: simulations remain GPU-native, UI remains Odin-native,
and the browser/Tauri bridge disappears completely.
