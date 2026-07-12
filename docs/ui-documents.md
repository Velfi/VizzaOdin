# UI Documents

Packaged UI structure assets use `.vui.json` with schema version 1. Documents
declare stable IDs, parent relationships, node kinds, layout hints, constraints,
style roles, typed bindings, actions, and optional metadata.

Template nodes are immutable subtree definitions and are not drawn as document
roots. A node that references a template instantiates that definition's child
subtree at the reference site. Each instance pushes the referencing node's
stable ID while lowering the shared definition, so retained interaction state
is distinct between instances without copying or mutating parsed nodes.

Supported node kinds are panel, text, image, button, toggle, slider, numeric,
selector, stack, row, grid, overlay, scroll, anchor, template, and slot. Binding
kinds are bool, integer, float, enum index, string, image, visibility, enabled,
action, and slot. A slot is a renderer-neutral same-frame callback used for
specialized, highly dynamic Odin content; it carries no Vulkan state and cannot
cross a queue.

Loading is atomic. A candidate document owns all parsed memory through a
dynamic arena and replaces the active document only after version, ID,
parent/template-cycle, constraint, and binding validation succeeds. Debug
reload uses the same path; an invalid candidate leaves the current document
unchanged.

The render worker exposes an explicit debug reload command carrying a fixed
document ID and path. Reload parses into a separate arena, verifies that the
candidate ID matches the requested packaged document, and swaps only after all
validation succeeds. Production code performs no file watching or automatic
reload.

Constraint references are compiled during validation. Both node IDs and layout
properties (`x`, `y`, `width`, `height`, edges, and centers) must exist;
`viewport` is accepted only on the right-hand side. Required document and node
style tokens must resolve against the built-in token catalog. Unknown optional
metadata remains forward-compatible.

Compiled single-property linear relations are resolved deterministically before
document drawing. Equality and upper/lower inequalities support positions,
sizes, edges, and centers relative to the viewport or root node. Resolution is
bounded to two internal passes and never replays product UI construction.
Root layout width and height provide intrinsic preferred bounds before
constraints are applied. Nodes may select a validated `compact`, `wide`,
`short`, or `tall` breakpoint alternative; selection happens during internal
document traversal and never replays product UI code.

Runtime behavior remains in Odin. Documents are immutable structure and style
assets; focus, edit state, scrolling, animation, and product values remain in
their existing runtime owners and are keyed by stable document/element IDs.

The production Main Menu, Controls Help, Options, and preset-save dialog are
instantiated from packaged documents. Main Menu selects immutable compact or
wide shell alternatives and supplies its live-preview catalog through a typed
slot. Controls Help's asset owns its panel, heading, scroll area, constraints,
and back action; Options owns its panel, heading, responsive bounds, and content
slot; the preset document owns its modal panel, title, enabled Save action,
Cancel action, and compact constraints. Interactive teaching content, live
settings controls, preview geometry, and preset-name editing are supplied
through typed slots. Simulation screens, including Gradient Editor and dynamic
Control Deck content, are instantiated through the shared simulation-shell
document and its typed feature slot. The former semantic-scope-only transition
path has been removed. Existing specialized Odin content is emitted as semantic
children of immutable document roots, preserving controller behavior. Document
scroll areas use
persistent values keyed by document and element ID; grid, overlay, anchor, row,
stack, panel, slot, and scroll roles lower to matching semantic container kinds.
