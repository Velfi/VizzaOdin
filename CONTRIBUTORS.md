# Contributors

VizzaOdin is an experiment in rebuilding Vizza as a native Odin application:
SDL3 owns the window and main-thread event loop, Vulkan owns rendering and
compute, Slang is the shader language, and the UI is custom immediate mode.

## Dependency Install

### macOS

Install Odin and the native graphics/tooling dependencies:

```sh
brew install odin sdl3 vulkan-loader vulkan-headers molten-vk
```

Install `slangc` using the directions in the Slang section below. `make
shaders` requires `slangc` to be discoverable on `PATH`.

If Vulkan startup fails with `Failed to load Vulkan Portability library`, make
sure MoltenVK is installed and discoverable. With Homebrew installs, this may
require exporting `VK_ICD_FILENAMES` to the MoltenVK ICD JSON shipped by the
installed package, or using the LunarG Vulkan SDK environment setup script.
This repository also provides a Homebrew-oriented helper:

```sh
make run-macos-vulkan
```

Then build the vendored TOML dependency and project:

```sh
make deps
make shaders
make check
make test
make build
```

### Linux

Install Odin, SDL3 development headers/libraries, Vulkan loader and headers, a
Vulkan ICD for your GPU, and Slang's `slangc`. Package names vary by
distribution.

```sh
make deps
make shaders
make check
make test
make build
```

### Windows

Install Odin, SDL3, the Vulkan SDK, and Slang. Ensure `odin`, SDL3 runtime
libraries, Vulkan loader/runtime, and `slangc` are on `PATH`.

```bat
make deps
make shaders
make check
make test
make build
```

## Installing Slang

`make shaders` invokes `slangc` directly. The most reliable install route is
the official Slang GitHub release page:

<https://github.com/shader-slang/slang/releases>

On macOS/Linux, the repository script can download the latest matching release
asset and install it under `.tools/slang`:

```sh
make install-slangc
make shaders
```

`make` automatically prepends `.tools/slang/bin` to `PATH`, so the local install
is enough for repository commands.

Manual install:

1. Open the latest release and expand **Assets**.
2. Download the archive that matches your platform and CPU architecture:
   - macOS Apple Silicon: look for a macOS/aarch64 or macOS/arm64 archive.
   - macOS Intel: look for a macOS/x86_64 archive.
   - Linux: choose the Linux archive for your architecture. Prefer a glibc
     archive if your distribution needs the older glibc compatibility build.
   - Windows: choose the Windows archive for your architecture.
3. Extract the archive somewhere stable, such as `~/Tools/slang` on macOS/Linux
   or `C:\Tools\slang` on Windows.
4. Add the extracted `bin` directory to `PATH`.

macOS/Linux shell example:

```sh
export PATH="$HOME/Tools/slang/bin:$PATH"
slangc -version
make shaders
```

Windows PowerShell example:

```powershell
$env:Path = "C:\Tools\slang\bin;$env:Path"
slangc -version
make shaders
```

If a package manager provides a current Slang package, that is fine too; the
only project requirement is that `slangc -version` works before running
`make shaders`.

## Notes

Threading model:

- Main thread owns SDL: window lifecycle, event polling, and immutable
  `Ui_Frame_Input` snapshots pushed through `ui_to_render`.
- The frame processor owns Vulkan, simulation stepping, immediate-mode UI
  layout, and render-graph execution. It consumes queued commands only and
  never polls SDL events.
- macOS/MoltenVK requires Vulkan surface/swapchain work on the main thread, so
  Darwin runs the frame processor inline via `frame_processor_pump`. Linux and
  Windows use a background SDL thread.
- Main thread publishes pixel-space window sizes and scaled mouse coordinates.
  Do not call SDL window/event APIs from the background frame processor.
- Keep `tomlc17` behind `src/settings.odin`; simulation code should not touch C
  bindings directly.
- Keep Vulkan helpers thin and app-specific. This is a Vizza rewrite, not a
  general engine.
