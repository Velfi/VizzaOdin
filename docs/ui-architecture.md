# VizzaOdin UI Architecture

## Goal

Build a native UI system that is pleasant for both runtime simulation controls
and tooling. The application code should keep the immediate-mode ergonomics:
state lives in the app or simulation, and a widget call returns an action in the
same frame. Internally, the UI system may retain caches, layout variables,
animation state, text shaping data, and editor metadata.

The visual editor is a separate tool surface. It edits documents that describe
layout, style tokens, and reusable view templates. The game/app consumes those
documents as immutable assets and still renders them through the same
immediate-mode runtime.

## Principles

- Immediate-mode is the public API, not a promise that the implementation is
  stateless.
- App and simulation data remain the source of truth.
- Layout is solved in explicit passes before rendering.
- Runtime UI and editor UI share the same renderer, widgets, style system, and
  layout engine, but they do not share mutable state.
- The editor can author structure, style, and constraints; runtime code owns
  behavior.
- The system is app-specific first. Generality is only added where Vizza needs
  it across simulations and tools.

## Package Shape

```text
ui/
  core        IDs, input, frame arena, command buffers, focus/nav state
  layout      constraint and flow layout, measurement, resolved rectangles
  widgets     buttons, sliders, selectors, panels, menus, inspectors
  style       tokens, themes, variants, state transitions
  text        font atlas, HarfBuzz/Freetype shaping shim, glyph runs, text measurement
  render      draw command lowering, atlas binding, scissor, clipping
  doc         authored UI documents, templates, schema, serialization
  editor      visual editor app, inspectors, timeline/state preview
```

The current implementation lives in `packages/ui/gui.odin`, with Vulkan draw
lowering in `packages/engine/ui_renderer.odin`. It is still a single package
surface rather than the split module layout above.

## Frame Pipeline

1. Main thread polls SDL events and publishes immutable `Ui_Frame_Input`.
2. Render worker begins a UI frame with the input snapshot.
3. Runtime code calls immediate-mode functions.
4. Widget calls emit semantic items into a transient frame tree.
5. Layout pass resolves constraints and flow containers.
6. Interaction pass resolves hover, active, focus, navigation, drag/drop, and
   text edit operations against the resolved tree.
7. Widget calls return actions or changed values to app code.
8. Paint pass emits renderer-neutral draw commands.
9. Vulkan backend lowers draw commands to transient vertices and submits after
   simulation rendering.

### Interaction geometry

Pointer interaction uses the stable-ID rectangle snapshot from the previous
completed frame. Widget calls still return current input actions immediately
and emit current-frame geometry for paint and for the next snapshot. The first
bootstrap frame may use explicit current rectangles; once a snapshot exists, a
new widget waits until it has completed layout before accepting pointer input.
Keyboard and controller focus remain stable-ID based and spatial navigation is
resolved at frame end.

This hybrid avoids replaying product UI code or retaining product values while
preventing input from targeting unresolved or discontinuously moving layout.

This keeps the API immediate while allowing the implementation to be
multi-pass, deterministic, and debuggable.

## Immediate API

The public API should feel like this:

```odin
ui_panel(ctx, "Gray-Scott", ui_constraints({
    left = px(16),
    top = px(16),
    width = px(320),
}))
defer ui_end_panel(ctx)

if ui_button(ctx, "Back") {
    mode = .Main_Menu
}

changed := false
changed |= ui_slider(ctx, "Feed", &settings.feed, 0, 0.1)
changed |= ui_slider(ctx, "Kill", &settings.kill, 0, 0.1)
```

For authored views, runtime code binds named slots to typed values and actions:

```odin
view := ui_template(ctx, app_assets.options_view)
ui_bind_bool(view, "fps_limit_enabled", &settings.default_fps_limit_enabled)
ui_bind_i32(view, "fps_limit", &settings.default_fps_limit)
if ui_action(view, "save") {
    settings_save_app("config/app.toml", settings)
}
```

The editor owns structure; runtime owns data and behavior.

## Constraint Layout

Use a two-layer layout model:

1. Fast layout primitives for common cases:
   - Stack row/column
   - Grid
   - Overlay
   - Dock
   - Scroll area
   - Absolute anchors
2. Constraint solver for relationships that need it:
   - `left == parent.left + 16`
   - `width >= 280`
   - `button_a.right + 8 == button_b.left`
   - `panel.width == min(parent.width - 32, 560)`
   - preferred constraints with strengths

Most UI should never hit the solver. Stack/grid/dock containers are faster,
more predictable, and easier to inspect. Constraints are for editor-authored
layouts, overlays, responsive menus, and view templates.

### Constraint Types

```odin
Constraint_Kind :: enum {
    Equal,
    Less_Equal,
    Greater_Equal,
    Aspect,
    Intrinsic_Min,
    Intrinsic_Preferred,
}

Constraint_Strength :: enum {
    Required,
    Strong,
    Medium,
    Weak,
}
```

Each element has variables:

```text
x, y, width, height
left, right, top, bottom
center_x, center_y
baseline
```

Derived variables are cheap aliases where possible. The solver should work on
`x/y/width/height` internally and expose friendly anchors.

### Solver Choice

Start with an incremental Cassowary-style linear solver because UI constraints
need required and preferred strengths, inequality support, and interactive edit
variables. Keep the implementation isolated behind `ui/layout/solver`.

Do not put OR-constraints or full branch-and-bound adaptive layout into V1.
Model responsive alternatives as explicit editor-authored breakpoints first.

### Layout Passes

1. Build frame tree and collect intrinsic measurements.
2. Resolve fast containers.
3. Add constraint variables for nodes that requested constraints.
4. Solve required constraints.
5. Solve soft constraints by priority.
6. Clamp to pixel grid.
7. Emit debug records for every constraint and broken preference.

## Styling

Use named design tokens, not raw colors spread through app code:

```odin
Ui_Tokens :: struct {
    bg: Color,
    panel: Color,
    panel_border: Color,
    text: Color,
    text_muted: Color,
    accent: Color,
    danger: Color,
    spacing_1: f32,
    spacing_2: f32,
    radius_control: f32,
    row_height: f32,
}
```

Widget style is a function of role and state:

```text
Button.primary.normal
Button.primary.hot
Button.primary.active
Button.primary.disabled
Panel.default
Slider.track
Slider.fill
```

The visual editor edits tokens, variants, and document-level overrides. Runtime
code can swap themes but should not mutate editor documents.

## Input And Focus

V1 input:

- Mouse hover/press/release
- Wheel
- Keyboard focus
- Text input
- Escape/back
- Tab focus traversal
- Arrow navigation for sliders/selectors

Current input includes mouse, wheel, text input, Tab/Shift/Enter/Escape/
Backspace, arrow keys, and gamepad buttons mapped onto focus/navigation actions.

State model:

```odin
Ui_State :: struct {
    hot: Ui_Id,
    active: Ui_Id,
    focused: Ui_Id,
    keyboard_capture: Ui_Id,
    text_edit: Text_Edit_State,
    drag_drop: Drag_Drop_State,
    frame_index: u64,
}
```

Focus and text editing are retained by widget ID, but widget values stay in app
state.

## Draw Commands

Keep draw commands renderer-neutral:

```odin
Draw_Command_Kind :: enum {
    Rect,
    Rounded_Rect,
    Stroke,
    Text_Run,
    Image,
    Path,
    Scissor_Begin,
    Scissor_End,
}
```

Text commands currently carry raw strings and are shaped during UI draw lowering
through the `third_party/textshape` shim, falling back to bitmap-font advances
when shaping is unavailable. A later split can cache shaped runs by handle.

## Main-menu previews

Simulation cards emit renderer-neutral preview slots during UI construction.
All registered simulations use live preview callbacks from their paired render
descriptors. The former simulation-by-simulation CPU illustration switch has
been removed; Gradient Editor retains its palette-strip tool preview, with a
generic surface fallback for non-feature screens.

## Authored documents and future tooling

Runtime-authored documents now use versioned `.vui.json` assets. Documents are
parsed into arena-owned immutable structures, fully validated before swap, and
bound to explicitly typed runtime slots. Failed debug reloads preserve the
active document. Production builds load packaged documents during render-worker
initialization and do not watch the filesystem.

No visual editor is implemented by this refactor. A future separate tool could
edit `Ui_Document` assets without becoming part of the runtime architecture:

```odin
Ui_Document :: struct {
    version: u32,
    tokens: []Token_Def,
    templates: []Ui_Template,
    styles: []Style_Rule,
    breakpoints: []Breakpoint,
}

Ui_Template :: struct {
    name: string,
    root: Ui_Node,
    bindings: []Ui_Binding_Def,
    actions: []Ui_Action_Def,
}
```

Potential out-of-scope tooling features:

- Canvas with selectable/resizable nodes
- Hierarchy tree
- Constraint inspector
- Token/style inspector
- Binding/action inspector
- Breakpoint preview
- Runtime data preview using sample values
- Constraint debug overlay
- Export to TOML or a compact binary asset

The editor does not execute game logic. It emits action names like `save`,
`back`, `randomize`, and binding names like `settings.feed`. Runtime code maps
those to typed data and commands.

## Editor/Runtime Boundary

Runtime consumes compiled UI assets:

```text
assets/ui/main_menu.ui.toml
assets/ui/options.ui.toml
assets/ui/gray_scott_controls.ui.toml
build/ui/*.uibin
```

Build step:

1. Validate document schema.
2. Validate all referenced tokens and styles.
3. Compile templates to stable node IDs and constraint bytecode.
4. Emit a compact asset plus debug metadata.

Runtime:

- Loads compiled assets on render worker.
- Binds values/actions each frame.
- Uses immediate API for behavior.
- Emits draw commands through the same renderer as hand-written UI.

## Constraint Debugging

The editor and debug builds should expose:

- Element bounds overlay
- Constraint lines and anchors
- Strength coloring
- Broken soft constraints list
- Solver timings
- Layout invalidation reasons
- Hit-test rectangles
- Focus chain
- Hot/active/focused IDs

Debugging layout without these would be misery with better branding.

## Performance Targets

- Zero heap allocation in normal runtime UI frames after initialization.
- Frame arena for transient nodes, constraints, and draw commands.
- Stable IDs from source locations, explicit strings, or compiled document IDs.
- Skip layout/input/render for clipped virtualized lists.
- Cache text shaping by string/font/size/style.
- Batch draw commands by texture, scissor, and pipeline state.
- Solver budget visible in frame stats.

## Current Hybrid Core

The public API remains immediate and product values remain authoritative. Each
widget also emits a transient semantic node. Layout containers form parent and
sibling links, while controls record stable IDs, resolved bounds, enabled and
focusable state. No transient node pointer survives `gui_end_frame`.

Interaction uses the previous completed frame's stable-ID rectangle snapshot.
New widgets wait for one completed layout, unstable nodes suppress pointer
interaction, and discontinuous position/size changes suppress interaction for
the transition frame unless a control explicitly opts in. Internal semantic
validation is bounded to two passes and exposes node, retry, overflow, and
unstable-node diagnostics.

Widget drawing first accumulates a transient draft command stream. After
semantic validation and bounded layout retries complete, `gui_end_frame`
publishes a separate renderer-neutral paint stream. Vulkan lowering and frame
statistics consume only that completed stream; it remains unchanged while the
next frame is being constructed.

Focus ownership is centralized by semantic layer: canvas, utility rail,
control deck, panel, active control, child region, and modal. Controller decks
claim and release deck/panel/control owners as their region phase changes;
focused editors claim the active-control layer; modal focus scopes push and
restore the prior owner without accumulating duplicate claims across frames.

Remaining core work is richer multi-node constraint solving and moving more
specialized slot content from draft immediate paint emission into semantic-node
paint lowering. All production shared screens now instantiate immutable
documents. This refactor does not include a visual editor.

Defer:

- Rich text
- Full accessibility tree
- Animation timeline editor
- OR-constraint adaptive layouts
- Multi-window docking
- Undo history beyond editor document edits

## Migration From Current Implementation

1. Rename current `Gui_Context` concepts into `Ui_Context`.
2. Split widget calls from drawing commands.
3. Add a transient frame tree.
4. Add layout containers before adding the solver.
5. Route `app_ui.odin` through the new API.
6. Keep the existing Vulkan UI renderer as the draw-command backend.
7. Add document loading for main/options screens.
8. Build the editor as a separate mode using the same widgets.

## References

- Dear ImGui's IMGUI paradigm notes emphasize that immediate-mode is about the
  API boundary and application-owned truth, not about forbidding internal UI
  state.
- Cassowary is the classic incremental linear constraint solver family for UI
  layout with required and preferred constraints.
- Yoga is a useful reference point for fast embeddable layout primitives built
  around web-style flex layout, even though VizzaOdin should own a smaller,
  Odin-native implementation.
