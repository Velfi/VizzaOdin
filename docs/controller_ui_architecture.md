# Controller UI Architecture

Physical south/east face buttons are mapped to semantic Accept and Back actions
using the persisted controller face-layout preference. UI code consumes only the
semantic actions. A live layout change releases any held face actions before the
new mapping takes effect, so ownership cannot become stuck across the change.

Keyboard shortcut profiles follow the same boundary rule. Standard and Letter
Shortcuts translate their physical Pause, Toggle UI, and Help keys before UI
routing; controller and keyboard press pulses remain distinct so prompt-device
handoff cannot misattribute action ownership.

Custom keyboard bindings use the same semantic route. The settings layer owns
validation and duplicate resolution, including the reserved Space relationship
with the Control Deck, so event handling never needs to reason about UI labels
or conflicts.

Controller Guide maps to the semantic Help action. It opens the in-simulation
reference independently of visible chrome and toggles the modal closed before
normal routing, while the bar button remains available on controllers whose
platform reserves Guide.

The controller menu-button layout maps Start and View/Back to semantic Pause
and Toggle UI roles, with North retained as a Toggle UI fallback. Each physical
button has independent held state; the semantic action is the union of its
current contributors. Layout swaps release the old owners before remapping.

The shoulder handedness layout similarly maps physical left/right shoulders to
semantic Focus Next and Focus Previous. Deck and generic GUI traversal consume
the same semantic actions, so neither layer contains layout-specific branches.

Vizza's controller UI is built around capabilities. A capability is a reusable instrument such as Look, Brush, Motion, Awareness, Field, Birth, or World. A simulation declares the controls it supports, then groups related capabilities into a small impact-ordered deck. The deck is a user-facing information architecture rather than a one-to-one reflection of implementation fieldsets.

## Control Descriptors

`packages/game/control_descriptors.odin` defines the shared descriptor schema. Each descriptor has a stable ID, label, type, semantic group, feel group, preset scope, runtime apply policy, UI hint, controller hint, and wiring status.

Normal couch UI only shows controls that are fully wired, not Developer or Debug, and not marked `NoEffectDeprecated`. Advanced mode may show advanced/expert controls. Developer mode can show broken or deprecated controls so they can be audited, but the normal deck will not expose them.

## Slime Declaration

`packages/game/slime_capabilities.odin` declares Slime Mold's controls. The couch deck composes them into six user-facing views:

- Presets: built-ins, saved settings, respawn, and randomize
- Look: palette, reverse, background, blur
- Agents: speed range, steering, and an interactive awareness cone
- Trails: Ink plus the paired Fade/Spread response
- Brush: a two-axis radius/strength instrument
- World: initial placement and mask source/target/response/image transforms

Pause and Record remain universal header actions. Clear Trails stays next to the trail controls where its consequence is visible.

Legacy Slime fields that are currently ineffective remain loadable through settings, but descriptors mark them as deprecated or exposed-ineffective. This includes heading range, decay frequency, diffusion frequency, and `mask_reversed`.

## Control Deck

`packages/game/slime_controller_ui.odin` generates the bottom Control Deck from `SLIME_CONTROL_INSTRUMENTS` and descriptor visibility. `Tab` or the controller shoulders enter and browse the deck. Left/right navigation moves focus across instruments, and Enter/Accept opens the focused instrument. Space is the compatibility keyboard binding for the semantic `Control Deck` action, which focuses the deck without opening a separate shortcut menu. Routing consumes that action before the Pause fallback only while this UI is available.

The deck reserves a contextual command strip that follows the last presentation device and current focus phase. It explains browse/open/close at deck level, navigate/edit/back inside a panel, and adjust/commit/cancel while a value is engaged. Controller prompts use semantic Accept and Back names rather than assuming one platform's face-button lettering.

The controller-friendly deck is the settings UI for every simulation. Gradient Editor retains its specialized editor layout.

The other simulations use the same impact-first order: Presets and Look first, defining behavior next, direct manipulation after that, and low-frequency analysis or camera utilities last. Generic `Settings`, `Controls`, and `Actions` tabs are avoided; reset actions live with Presets and pointer parameters are named Brush.

Paired fields use a single spatial control when the relationship is meaningful. Range sliders represent ordered minimum/maximum values, two-axis pads represent coupled response dimensions, and domain-specific diagrams remain the primary editor for Gray-Scott reaction pairs and Particle Life force curves. Exact legacy fields remain serialized unchanged.

Each semantic view owns its focus-memory and scroll-animation namespace. Returning to a view can restore a valid control without leaking focus or an in-flight scroll animation from another tab; if a conditional control has disappeared, focus falls back to the first available control. A stable dark scrim beneath the refractive glass keeps labels, handles, and focus rings readable over bright or high-frequency simulations.

The simulation header and the Control Deck tabs form one chrome layer. They
reveal and auto-hide together; opening a tab adds its panel above that layer.
Visibility does not itself imply focus: pointer activity may reveal the chrome
while focus remains on the canvas. Focus has one owner and moves between the
header, deck, panel, active control, and modal layers. In particular, a header
shortcut relinquishes deck/panel focus before focusing its header action.

## Controller Focus Shortcuts

Controller Start focuses the simulation header bar's Pause/Resume action. Controller Select/North focuses its Back-to-menu action. The shoulder actions enter or browse the Control Deck. While these shortcuts are handled by the controller UI, the context router prevents them from also reaching the simulation or global fallback.

On the simulation canvas, D-pad Up/Down controls camera zoom, the left stick pans, the right stick moves the virtual cursor, and the triggers perform primary/secondary interaction. The triggers do not also zoom: physical controls resolve to one canvas operation at a time. When UI owns focus, the D-pad returns to navigation and its camera channel is suppressed.

The main menu's `CONTROLS` destination is the persistent reference for keyboard, mouse, controller, focus/edit semantics, and device handoff. It is scrollable at compact sizes and can always be dismissed with Back/Escape.

Options > Input persists controller deadzone, virtual-cursor speed, navigation repeat delay, and repeat interval. These settings are published back to the SDL-owning main thread immediately, so adjustment does not require restarting the app or reopening a simulation.

## Adding Another Simulation

Add descriptors for the simulation, mark every control's wiring status honestly, then group them into a small impact-ordered set of semantic views. Start with generic descriptor rendering where possible. Use custom renderers for controls that need a spatial representation, such as a sensor cone, force matrix, palette browser, response pad, range slider, or image source picker.

Known TODOs: split behavior/look preset serialization, add more generic descriptor renderers, and restore safe runtime agent count if GPU resource recreation is made cheap enough.
