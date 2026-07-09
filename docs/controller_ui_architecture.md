# Controller UI Architecture

Vizza's controller UI is built around capabilities. A capability is a reusable instrument such as Play, Look, Brush, Motion, Awareness, Field, Birth, World, Source, or Capture. A simulation declares the instruments it supports, then lists the controls that belong to each instrument.

## Control Descriptors

`packages/game/control_descriptors.odin` defines the shared descriptor schema. Each descriptor has a stable ID, label, type, semantic group, feel group, preset scope, runtime apply policy, UI hint, controller hint, and wiring status.

Normal couch UI only shows controls that are fully wired, not Developer or Debug, and not marked `NoEffectDeprecated`. Advanced mode may show advanced/expert controls. Developer mode can show broken or deprecated controls so they can be audited, but the normal deck will not expose them.

## Slime Declaration

`packages/game/slime_capabilities.odin` declares Slime Mold's first vertical slice:

- Play: pause, reset, clear trails, randomize
- Look: palette, reverse, background, blur
- Brush: radius and strength
- Motion: speed min/max, turn rate, jitter
- Awareness: sensor angle and distance
- Field: Ink, Memory, Spread
- Birth: seed, position distribution, position image
- World: mask source/target/strength/curve/image/transform
- Capture: recording action

Legacy Slime fields that are currently ineffective remain loadable through settings, but descriptors mark them as deprecated or exposed-ineffective. This includes heading range, decay frequency, diffusion frequency, and `mask_reversed`.

## Control Deck

`packages/game/slime_controller_ui.odin` generates the bottom Control Deck from `SLIME_CONTROL_INSTRUMENTS` and descriptor visibility. `Tab` toggles the deck. Left/right navigation moves focus across instruments, and Enter/A opens the focused instrument. Space and controller Select focus the deck without opening a separate shortcut menu.

The existing settings panel remains available through the existing UI path. The new overlay is controlled by the app setting `ui.experimental_controller_ui`.

## Controller Focus Shortcuts

Controller Start focuses the simulation header bar, currently the Pause/Resume action. Controller Select focuses the bottom Control Deck. While either shortcut is handled by the controller UI, the simulation brush input and old hidden side-panel hit testing stay inactive only over visible controller UI bounds.

## Adding Another Simulation

Add an instrument list and descriptors for the simulation, mark every control's wiring status honestly, and start with generic descriptor rendering where possible. Use custom renderers only for controls that need a spatial representation, such as a sensor cone, force matrix, palette browser, or image source picker.

Known TODOs: split behavior/look preset serialization, add more generic descriptor renderers, restore safe runtime agent count if GPU resource recreation is made cheap enough, and broaden this architecture beyond Slime after this slice has been tested.
