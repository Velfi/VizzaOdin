# Native UI Framework Feature Matrix

VizzaOdin's UI framework is a native immediate-mode app UI layer. It is not a
web framework, but it now covers the major styling, layout, rendering, state,
and media primitives expected from a general app UI toolkit.

## Styling

- Color tokens: background, panels, controls, hot/active/disabled states, text,
  muted text, accent, danger.
- Surface styling: solid fills, vertical gradients, rounded corners, borders,
  border widths, opacity, and shadow layers.
- Blend modes: alpha, additive, multiply, and screen pipeline variants.
- Text styling: scale, color, left/center/right alignment, clipping,
  HarfBuzz/Freetype-backed measurement, and wrapped text emission.
- State styling: normal, hot, active, disabled, and focused controls.
- Transition styling: retained per-widget animation slots keyed by UI ID.

## Layout

- Explicit rectangles for low-level positioning.
- Stack layouts in row or column direction.
- Cross-axis alignment: start, center, end, stretch.
- Equal distribution helpers, including space-between behavior.
- Grid layout with configurable column count and gap.
- Responsive breakpoint and responsive-column helpers.
- Edge insets and spacers.
- Anchor rectangles for overlay and edge-pinned UI.
- Scroll areas with wheel input, clipping, and content offset.

## Rendering

- Filled and stroked rectangles.
- Filled and stroked rounded rectangles.
- Gradient rectangles, including rounded gradients.
- Lines with thickness.
- Filled and stroked ellipses.
- Transformed quads and rotated rectangles.
- Scissor clipping.
- Bitmap-font text.
- Texture-backed image commands with UV support, tinting, descriptor-backed
  sampling, brightness, contrast, grayscale, small-radius blur filtering, a
  generated default checker texture, and backend registration for external
  Vulkan image views.

## Interaction

- Mouse hover, press, release, active state, and wheel input.
- Keyboard input fields for tab, shift, enter, escape, backspace, text input,
  and arrow keys.
- Gamepad buttons mapped onto activation, back, focus traversal, and directional
  input.
- Focus state and focus-ring rendering.
- Keyboard activation for focused buttons.
- Immediate-mode widgets: panels, headings, labels, buttons, disabled buttons,
  card buttons, toggles, checkboxes, switches, radio groups, numeric inputs,
  sliders, 2D area sliders, selectors, comboboxes, HSV color pickers,
  circular progress indicators, and collapsibles.

## Renderer Backend

- Renderer-neutral draw commands are lowered by the Vulkan backend.
- UI vertices are batched by texture descriptor.
- UI vertices are batched by blend mode.
- The image path uses a sampled-image and sampler descriptor set.
- The default UI texture is uploaded through a staging buffer and one-time
  command submission during renderer initialization.

## Current Intentional Limits

- Text is rendered from the bitmap atlas, with width and glyph placement supplied
  by the text shaping shim when available. Complex text remains limited by the
  atlas coverage.
- Arbitrary vector paths are not included yet; current geometry primitives cover
  the app UI needs without a tessellation dependency.
- Backdrop blur is not implemented as a compositor pass. The framework supports
  shadows, opacity, gradients, image sampling, image filters, and texture
  tinting; true framebuffer-sampling effects should be added as a separate
  render-graph pass.
