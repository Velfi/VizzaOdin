# Package Architecture

## Dependency direction

VizzaOdin uses five package roles:

```text
src/main -> app -> game
                 -> ui
                 -> engine

game -> ui
game -> engine
render_vk -> game
render_vk -> engine
render_vk -> ui
```

Dependencies may point down this list, never back toward `app`. The
`scripts/check_package_boundaries.sh` check enforces these package boundaries.

## Ownership

### `packages/app`

The executable composition layer owns command-line interpretation, lifecycle,
platform integrations, worker creation, and wiring between product and runtime
services. It contains the CLI composition root, SDL lifecycle, MCP and Steam
integrations, video recording, and render-worker orchestration. Product command
and event payloads remain in `game` because they describe Vizza operations.

New platform integration policy belongs here. Do not add new application-host
policy to `game`.

### `packages/game`

The product domain owns Vizza simulation meaning: settings, presets, modes,
camera semantics, controls, palettes, simulation behavior, and shader/pass
selection. A type does not belong in `engine` merely because it contains a GPU
handle; domain-specific GPU state stays with its simulation until a `render_vk`
adapter exists.

### `packages/engine`

The engine owns reusable mechanism: Vulkan resource operations, queues, asset
access, logging, profiling, screenshots, and other facilities that could be
reused unchanged by a different visualization app. It must never import `game`
or `app`, and it must not contain simulation names, modes, presets, or product
navigation policy.

### `packages/ui`

UI owns renderer-neutral input, focus, layout, widgets, text, style, and draw
commands. It must not import `engine`, `game`, or `app`. Vulkan lowering is not
UI behavior.

### `packages/render_vk`

This adapter owns Vulkan implementations that combine renderer-neutral UI
commands with engine mechanisms. The UI Vulkan renderer and every
simulation-specific Vulkan implementation live here, so engine remains
independent of UI and product rendering policy:

```text
game/simulation model + controls
             |
             v
render_vk/simulation resources + command recording -> engine
```

## Change rules

- Prefer a new file in an existing package when the concern shares that
  package's lifetime and dependencies. File splitting improves ownership even
  though it does not create a dependency boundary in Odin.
- Create a package only when its imports form an acyclic boundary.
- Keep durable model and settings code free of SDL and Vulkan. A simulation may
  retain a GPU-state schema needed by the adapter, but buffer mutation, resource
  creation, command recording, presentation, and destruction belong in
  `render_vk`.
- Keep focused behavior tests close to their subject. The current executable
  test suite is split into domain-sized source files under `src` because many
  cases exercise composition across two or more packages.
- Development builds use `-o:none`. Packaging defaults to `-o:speed`.

## Current state

- `src/main.odin` is only an entrypoint; `packages/app` is the composition root.
- Simulation models and controls are in `game`; all simulation Vulkan procedure
  implementations are in `render_vk`.
- The renderer-neutral UI core, widgets, and drawing command builders are split
  by responsibility; Vulkan lowering is in `render_vk/ui_renderer.odin`.
- Integration tests are grouped into architecture, product UI, and GUI files.
- `make check` runs the dependency guard before Odin type checking.

## Compile-time posture

Odin compiles imported packages as part of the executable build, so file splits
primarily improve ownership rather than acting as independent compilation
units. Package boundaries still matter: they prevent the reusable engine and UI
from pulling product code into their dependency cones. Keep host integrations
in `app`, avoid convenience imports that point upward, and use `make check` for
the fast edit loop. Optimized code generation is reserved for packaging.
