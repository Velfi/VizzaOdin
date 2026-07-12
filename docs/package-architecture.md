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
camera semantics, controls, palettes, simulation behavior, and renderer-neutral
shader ABI. Vulkan handles and resource lifecycle state belong in `render_vk`,
never in product settings or runtime models.

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

## Feature registries

Product features have stable IDs independent of `App_Mode` ordinals. The
product registry in `game` owns names, capabilities, and preview policy. A
paired registry in `render_vk` owns step, present, preview, and render-runtime
lifecycle callbacks. `app` validates that both registries agree before the
render worker starts.

Graph-level scene post-processing is an explicit product capability. Startup
validation requires the paired render descriptor to provide exactly one
settings adapter when that capability is present and no adapter when it is
absent, preventing optional renderer policy from drifting away from discovery
metadata.

Descriptor-backed render storage is aligned, explicitly zero-initialized, and
accepted by an initialize callback before publication. The worker owns one
registry-indexed instance set rather than per-simulation fields. It allocates
all live/preview variants as one transaction; any initialization or allocation
failure destroys initialized instances in reverse registry order and leaves the
set empty.

`Render_Context` carries one pointer to that render instance set. It no longer
enumerates live and preview GPU pointers for Vectors, Moire, Primordial,
Pellets, Flow, Slime, or Voronoi, and the frame entrypoint no longer accepts a
per-feature GPU argument list. Feature callbacks and capture services resolve
typed renderer storage through registry lookup with size/alignment validation.

Dedicated Gray-Scott and Particle Life live/preview views also reside
under `App_Ui_State`, beside the product instance set that owns their storage.
`Render_Worker_Runtime` no longer has per-simulation fields, and
`Render_Context` no longer accepts or stores six dedicated simulation pointers;
renderer callbacks obtain typed product views through the single app-state
contract.

Simulation descriptors also own settings size, alignment, defaults,
validation, and copy operations. Apply-settings command schemas are derived
from that metadata rather than repeated in the command table. Tool descriptors
such as Gradient Editor intentionally declare no serializable settings schema.
Color-scheme name/reversal access is also descriptor-owned, so generic feature
commands mutate the registered settings block without a mode switch. Paired
render descriptors optionally expose runtime invalidation; settings and palette
changes invoke that callback through the render instance registry instead of
enumerating GPU state types in the worker.
Descriptors also declare target-change resource release where live and preview
allocations must be rebuilt after resize or swapchain recreation. The worker
invokes one instance-set operation rather than repeating concrete Vulkan state
types in resize and frame-recovery paths. Features with preservation-specific
resize behavior remain outside that release set.
Built-in preset application follows the same route. Every simulation descriptor
adapts its typed settings/runtime blocks to the feature implementation; the
worker no longer distinguishes dedicated simulations from the former remaining
group or maps `App_Mode` through a second simulation-kind enumeration.
The per-frame product update callback is descriptor-owned as well. The worker
advances the active product instance generically before UI construction, while
the compiled render-graph simulation pass invokes the paired GPU step.
Filtered immutable frame input is dispatched through a product descriptor
callback into the active instance. The worker no longer branches over concrete
simulation views, and modes that intentionally had no product input handling
retain explicit no-op callbacks.
Simulation-specific UI construction is also a descriptor callback. Authored
documents still supply the shared simulation shell, while the shell's feature
slot invokes the registered Odin UI builder. Specialized Control Deck and
spatial editors remain native without a central feature-mode switch.
Shared controller navigation likewise invokes an optional descriptor-owned
controls-panel builder. Slime retains its purpose-built deck and the Gradient
Editor remains a tool, while other simulation panels no longer require a
central mode switch or dedicated simulation-pointer parameters.
Enter/leave and pause ownership are descriptor callbacks. Mode transitions call
the registered lifecycle operations, which pause transient product state and
close feature-owned camera sessions without a renderer-side mode switch. Tool
features provide lifecycle callbacks without allocating simulation storage.
Reset dispatch is similarly split across the paired descriptors: `game` owns
product-runtime mutations and `render_vk` owns resource invalidation or
destruction. The app command router performs both calls without inspecting a
feature ID. File preset load/save and migration adapters are product-descriptor
operations; `app` retains only path resolution, deletion, result reporting, and
the narrow renderer image-source restoration service. This keeps preset schema
knowledge out of the worker while ensuring transient runtime remains excluded.
Built-in preset discovery uses the same descriptor as application. MCP mode and
preset listings iterate the feature registry, so adding a registered feature no
longer requires parallel discovery arrays or a preset-name mode switch.
Simulation descriptors separately declare transient product-runtime size,
alignment, initialization, and destruction. `Feature_Instance` allocates the
settings and runtime blocks independently and typed access validates each
schema before casting. Runtime blocks are never copied by settings operations
or included in presets. The older remaining-simulation aggregate now exposes
its settings fields separately from a `Remaining_Sim_Runtime_State` containing
cameras, timers, input state, dialogs, capture handles, and undo state while
consumers are migrated to descriptor-owned instances.

`App_Ui_State` owns the single product `Feature_Instance_Set` and exposes an
explicit destroy operation. The render worker owns only the paired Vulkan
instance set; it no longer allocates a duplicate product registry. Reinitializing
UI state first destroys the prior set, and tests defer `app_ui_destroy` so
allocation and teardown remain covered by memory tracking.

Slime, Flow, Pellets, Voronoi, Moire, Vectors, and Primordial now use
`Remaining_Sim_State` only as a non-owning typed view. Each live view binds one
settings block and one transient runtime block from its primary descriptor
instance; each main-menu preview binds the corresponding preview instance.
Preview configuration copies setting values into preview storage and preserves
preview runtime, so it cannot alias or mutate live settings. Reset/undo uses
the bound runtime kind and snapshots only that feature's settings schema.

Gray-Scott and Particle Life have completed that product cutover. Their
simulation structures are non-owning views whose settings and promoted runtime
pointers are bound from the worker's live or preview `Feature_Instance`.
Canvas selection and Particle Life blob tracking are transient runtime state;
Particle Life's descriptor also destroys its analysis workspace and preserved
particle slice. Simulation views retain only the opaque link to their paired
renderer instance. Standalone tests and tools must provide explicit product
storage, so accidental embedded ownership cannot return unnoticed.

Feature commands cross the main/render ownership boundary as value-owned,
fixed-capacity payloads. Each command is checked against its registered feature
ID, command ID, schema version, byte size, and alignment before dispatch. No
temporary pointer or allocator-owned slice may be placed in the queue.
Settings, reset, preset, color, and image load/clear operations use this path.
Image commands carry a fixed path buffer and stable feature-local slot; product
controls, SDL dialog callbacks, webcam capture, and MCP never enqueue borrowed
file paths or feature-specific settings command variants.
Native image selection also stays on this route. Product UI queues an empty
path image command with a request generation. The worker returns a successful
`Feature_Result` containing a typed optional platform-dialog request; the SDL
callback echoes the generation in the completed image command. Only the
matching pending generation is consumed. The former feature-specific
product-to-host dialog message kinds have been removed.
Image selection inside product state uses `Feature_Image_Target`, which is not a
queue command. The former per-image `Ui_To_Render_Command_Kind` values and
render-worker cases have been removed; only the validated feature service owns
load/clear dispatch.
Image-capable feature descriptors declare their stable slot-to-target mapping.
Command validation, stale-dialog ownership, the SDL dialog service, and the
renderer image service all resolve through that metadata; feature IDs are no
longer re-enumerated in multiple app switches.
Legacy Gray-Scott randomize/noise and built-in-preset queue variants are also
removed. Reset variants and built-in preset selection cross the queue only as
schema-checked feature commands.

Vulkan runtime migration is performed feature by feature. Moire, Voronoi,
Flow, Slime Mold, Vectors, Pellets, Primordial, and Gray-Scott now enforce the target boundary: shader ABI stays
renderer-neutral in `game`, while Vulkan handles, imported-image retirement,
pipelines, and live/preview allocations are owned by `render_vk` through
descriptor-sized aligned feature instances. Package-boundary checks prevent
those renderer types and Vulkan imports from returning to the corresponding
product schema files.

Gray-Scott product controls consume renderer-neutral readiness and render-size
status from `Gray_Scott_Runtime_State`; they do not inspect the GPU resource
block. The renderer is responsible for synchronizing that status when resources
are initialized, invalidated, resized, or destroyed.

Particle Life exposes the same renderer-neutral readiness, dimensions, and
uploaded-count status through `Particle_Life_Runtime_State`. UI and host
statistics consume that snapshot rather than mapped buffers or Vulkan resource
state. GPU creation and destruction publish the status atomically at their
lifecycle boundaries. Product controls, grid compatibility checks, trail
invalidation, and rebuild preservation now communicate through runtime status
and pending requests. Only `render_vk` reads mapped particle storage to fulfill
an explicit preservation request.

Gray-Scott and Particle Life simulations carry only opaque transient
bridges to once-allocated, aligned descriptor storage; all concrete Vulkan state
is defined in `render_vk`. Existing renderer procedures still take product
simulations during the signature migration, so the worker destroys resources
before releasing descriptor storage; runtime storage is never copied or
serialized.

## Compile-time posture

Odin compiles imported packages as part of the executable build, so file splits
primarily improve ownership rather than acting as independent compilation
units. Package boundaries still matter: they prevent the reusable engine and UI
from pulling product code into their dependency cones. Keep host integrations
in `app`, avoid convenience imports that point upward, and use `make check` for
the fast edit loop. Optimized code generation is reserved for packaging.
