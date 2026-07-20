# Vulkan Rewrite Plan

This is the native rendering path for VizzaOdin.

## Status

The original bring-up milestones below are mostly complete in the current
implementation: SDL3 creates the Vulkan window, Vulkan context/swapchain setup
lives in `../zelda-engine/packages/engine/vk_context.odin`, the UI renderer lowers
`../zelda-engine/packages/ui` draw commands through Vulkan, and Gray-Scott has a GPU compute and
present path. The active roadmap is now about broadening simulation coverage,
hardening editor-facing UI systems, and improving packaging/tooling.

## First Milestone: Complete

Bring up a window and clear the swapchain.

1. SDL3 initialization and event loop.
2. SDL3 window created with `WINDOW_VULKAN`.
3. Vulkan loader initialized.
4. Required instance extensions queried from SDL3.
5. Vulkan instance created.
6. SDL3-created `SurfaceKHR`.
7. Physical device and queue-family selection.
8. Logical device with graphics, compute, and present queues.
9. Swapchain creation and resize handling.
10. Per-frame acquire, command recording, submit, present.

## Second Milestone: Complete

Draw the custom immediate-mode GUI.

1. Convert `Gui_Context.commands` into transient vertices.
2. Add an orthographic UI pipeline.
3. Add a font atlas and text quads.
4. Add scissor rect support.
5. Add input wiring from SDL3 events.

The longer-term UI design lives in `docs/ui-architecture.md`: immediate-mode
runtime API, constraint layout, UI documents, and a separate visual editor.

## Third Milestone: Complete For Gray-Scott

Port one simulation.

Gray-Scott is the best first port: it is self-contained, compute-oriented, and
validates storage images, ping-pong textures, and post-processing without
needing particle buffers or camera input.

## Shader Tooling

Vulkan consumes SPIR-V. Use source shaders in `assets/shaders` and compile into
`build/shaders` with `slangc`.

The make target now discovers all `.slang` files recursively and writes
`build/shaders/slang-manifest.txt`, with one line per compiled entry in the
form `<source-path>|<stage>|<entry>|<compiled-spv-path>`.

Initial recommendation:

```sh
slangc assets/shaders/foo.slang -target spirv -profile spirv_1_5 -stage compute -entry main -o build/shaders/foo.spv
```

WGSL from the original project should be ported simulation by simulation rather
than translated mechanically all at once.
