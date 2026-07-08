# VizzaOdin

An Odin rewrite experiment for Vizza.

The target architecture is native Odin: SDL3 for the window/input layer,
`vendor:vulkan` for GPU simulation/rendering, and a project-owned immediate-mode
GUI instead of a webview.

## Package layout

- `src`: executable entrypoint and integration tests.
- `packages/game`: Vizza app flow, Gray-Scott simulation, settings, render graph,
  render worker, and MCP bridge.
- `packages/engine`: shared infrastructure such as bounded queues, Vulkan
  context/resources, shader asset lookup, screenshots, and the Vulkan UI renderer.
- `packages/ui`: renderer-agnostic immediate-mode UI primitives and widgets.

## Commands

```sh
make run
make run-steam STEAM_APP_ID=<id>
make build
make build-steam STEAM_APP_ID=<id>
make check
make test
make deps
make textshape
make install-slangc
make ui-font-atlas
make shaders
make mcp
make theme-preview
make theme-preview-mcp
make profile-ui-trace
make fmt
make package-macos
```

The compiled binary is written to `build/vizzaodin`.

`make deps` downloads the pinned `third_party/tomlc17` checkout and builds it
along with the `third_party/textshape` HarfBuzz/Freetype shim. `make tomlc17`
re-downloads/builds only `tomlc17`; `make textshape` rebuilds only the text
shaping shim. On systems without a global Slang compiler,
`make install-slangc` installs the pinned `slangc` tool into `.tools/slang`.
`make ui-font-atlas` regenerates `assets/shaders/ui_font_bitmap.slang` from
`assets/fonts/ZeldaSans-Regular-v1.otf`.
`make shaders` uses `.tools/slang/bin/slangc` when present, otherwise `slangc`
on PATH, and compiles all `assets/shaders/**/*.slang` into `build/shaders`,
generating `build/shaders/slang-manifest.txt` with one entry per compiled
shader stage. `make mcp` runs the app as a stdio MCP server; see `docs/mcp.md`.
`make build-steam` and `make run-steam` enable SteamAPI defaults, define the
Steam App ID, and copy the Steamworks redistributable from `STEAM_SDK_LOCATION`
(default: `~/steam_sdk`) next to `build/vizzaodin`. Steam can also be enabled at
runtime with `[steam].enabled`, `VIZZA_STEAM_ENABLED=1`, or `--steam`; use
`--no-steam` to disable it for a run. `--steam-app-id`, `VIZZA_STEAM_APP_ID`, or
`[steam].app_id` provide the app ID, and `--steam-library`/`VIZZA_STEAM_LIBRARY`
can point at a nonstandard SteamAPI library path.
`make theme-preview` opens the UI component design sheet. `make theme-preview-mcp`
opens the same sheet with the MCP screenshot tool enabled; see
`docs/ui-theme-preview.md`. The native UI framework's current styling, layout,
rendering, media, and interaction surface is tracked in
`docs/ui-framework-features.md`.
`make profile-ui-trace` attaches Xcode Instruments to a running `vizzaodin`
process and writes `profiles/vizzaodin-ui-render.trace`; override `DURATION`,
`TEMPLATE`, or `OUTPUT` as needed. Use it with the MCP profiling tools described
in `docs/gpu-profiling.md`.
`make package-macos` builds `dist/VizzaOdin.app`, signs it with the configured
Developer ID identity, notarizes it with `notarytool`, and writes
`dist/VizzaOdin-macos.zip`. Signing/notarization can be configured with
`MACOS_CODESIGN_IDENTITY`, `NOTARYTOOL_PROFILE`, or the standard
`APPLE_ID`/`APPLE_TEAM_ID`/`APPLE_APP_SPECIFIC_PASSWORD` variables. Override
`ODIN_FLAGS` to change the build optimization mode. Pass `--steam` or
`STEAM_ENABLED=1` to include `libsteam_api.dylib` in the app bundle.

See `docs/dependency-map.md` for the dependency translation from the original
Tauri/Svelte/Rust project.
