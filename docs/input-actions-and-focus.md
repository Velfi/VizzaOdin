# Input actions and focus

VizzaOdin keeps SDL3 and the existing immediate-mode UI. Physical input is
normalized before it reaches the render/UI thread:

```text
SDL keyboard, mouse, and gamepad state
  -> semantic action resolver
  -> Ui_Frame_Input action snapshot
  -> compatibility projection for existing UI/simulation consumers
  -> focused UI or simulation
```

## Semantic actions

`packages/game/input_actions.odin` defines the transport-safe action snapshot.
Discrete actions expose `down`, `pressed`, `repeated`, and `released` together,
so a tap that begins and ends between rendered frames is still representable.
The first contributing device owns a press until all contributing sources
release; changing prompt presentation cannot create a second activation.
Frame input uses ordered queue backpressure rather than merging saturated
snapshots. Opposite navigation taps, repeated accepts, text edits, pointer
coordinates, and press/release phases therefore keep their original order.
Background renderers wait for the next queue slot only after the 256-command
buffer fills; the macOS main-thread renderer drains queued work before retrying
the exact frame, avoiding a same-thread blocking deadlock.

The initial action set is:

- Navigate
- Accept, Back, and Help
- Pause and Toggle UI
- Control Deck
- Focus Next and Focus Previous
- Primary and Secondary
- Camera Pan, Camera Zoom, and Camera Reset

Navigation repeat is centralized at the action layer. It fires immediately,
then uses the persisted delay and interval from Options > Input (defaults:
350 ms and 90 ms). Stick input uses a configurable circular deadzone, preserving
the same activation radius in cardinal and diagonal directions. Virtual cursor
speed is independently configurable and updates the main input thread live.

Controller face buttons are translated into semantic Accept and Back actions at
the event boundary. The persisted `South Accept` / `East Accept` preference can
therefore change the physical convention without changing downstream widgets or
prompts. Changing it while a face button is held first releases both semantic
actions, preventing a stale press from surviving the remap.

Controller menu buttons also use a persisted layout. `Start Pauses` preserves
the original Start→Pause and View/Back→Toggle UI mapping; `View Pauses` swaps
those two roles. North remains a Toggle UI fallback in both layouts. Physical
North, Start, and View states are tracked independently before semantic
resolution, so releasing one contributor cannot cancel an action still held by
another. Live layout changes release Pause and Toggle UI and require a fresh
press under the new mapping.

Controller shoulders have a separate handedness layout. `Right Next` preserves
Right→Focus Next and Left→Focus Previous; `Left Next` swaps those semantic
directions. The setting changes only shoulder focus traversal, not D-pad/stick
navigation. A live swap releases both focus actions and clears physical shoulder
state before accepting a fresh press.

Controller canvas bindings avoid simultaneous side effects: triggers own
primary/secondary interaction, while D-pad Up/Down owns camera zoom only when
the simulation canvas has routing priority. Under focused UI the same D-pad
input is navigation and the camera channel is suppressed.

Controls remain discoverable without abandoning a running simulation. F1 or
the focusable Help button in the Control Deck utility rail opens the shared
controls text
as a modal overlay. The overlay captures pointer and navigation input, preserves
the simulation beneath it, and restores the invoking focus when Back or Close
dismisses it. An engaged value editor keeps ownership, so F1 cannot interrupt a
transactional edit.

Help is itself a semantic action. The effective keyboard Help binding and the
controller Guide button share source-owned press/release phases, so Guide can
open the reference even while simulation chrome is hidden. Pressing Guide again
closes the modal without reopening it; Back and the focusable Help/Close buttons
remain universal fallbacks. Active editors suppress the global Help action.

Keyboard shell shortcuts use persisted effective bindings without changing
downstream semantic actions. `Standard` keeps the original Space/Slash/F1
bindings for Pause, Toggle UI, and Help; `Letter Shortcuts` uses P/U/H. Changing
an individual selector creates a `Custom` profile. Duplicate selections swap
the displaced action to the prior key when legal, or to the first free legal key
when Space is involved. Physical Space is reserved for Pause plus the Slime
Control Deck. Switching bindings live releases held Pause and Toggle UI actions
before the new layout takes effect, preventing stuck ownership. Invalid or
duplicate persisted custom bindings recover to a conflict-free safe layout.

Camera tuning is device-specific. Keyboard and wheel input retain the original
camera sensitivity, while controller pan and D-pad zoom use a separate persisted
sensitivity. Controller Y inversion is applied only at the camera-consumption
boundary; its default is off, preserving the user-tested stick direction. These
preferences update live and do not change controller navigation inside UI.

Canvas pointer gestures are exclusive. Left and right drag provide primary and
secondary simulation interaction; middle drag and Space+left drag pan the camera
without also modifying the simulation. The Space chord provides a laptop-safe
pan gesture while middle drag remains an optional mouse shortcut. Vertical wheel
or two-finger scroll zooms toward the visible pointer, while horizontal scroll or
Shift+vertical scroll pans. Fractional trackpad deltas are preserved and large
coalesced bursts are clamped per frame. Scroll input over UI belongs to that UI.
The controller virtual cursor follows the system cursor's simulation-chrome
hide rules, including during trigger-owned canvas gestures.

`active_device` is presentation state for cursor and prompt selection. It does
not decide whether keyboard or controller actions are eligible. Existing raw
fields remain in `Ui_Frame_Input` as a migration bridge and are projected from
the semantic action frame where practical.

SDL controller type selects Xbox or PlayStation prompt art at connection time.
Steam Deck is detected from its controller name because SDL has no distinct
Steam Deck gamepad type. That prompt style travels with each frame, so the
contextual Control Deck strip can switch icon families without changing action
routing; unknown controllers use the Xbox-position fallback.

Controller connection changes produce a short, non-modal notice. Disconnecting
the actively used controller while a simulation is running reveals the UI and
pauses the simulation, and the notice explains that pause instead of leaving a
silent state change. Logical focus and any engaged edit remain intact so the
user can continue with the keyboard without losing work.

## Focus and engagement

Structured UI navigation uses spatial groups as focus scopes. Tab/shoulder
navigation wraps inside the current group, and directional navigation can
reach a clipped item only when both items belong to the same scroll container.
When focus moves to a partially or fully off-screen item, the owning scroll
container reveals it before the next frame.

Interaction rules:

- Buttons, toggles, checkboxes, and radio choices activate with one Accept.
- Sliders, selectors, numeric fields, text fields, and nested panels use
  explicit engagement.
- Accept commits an engaged edit; Back restores its snapshot.
- A Back press that is not owned by a widget pops exactly one focus scope.
- The top modal traps focus and input, then restores its invoking control when
  dismissed.
- Open overlays capture simulation pointer input even outside the side-panel
  rectangle, matching normal DOM child-event ownership.
- Selection, focus, and engagement are separate states. The Slime deck keeps a
  persistent selected treatment but shows a focus ring only while its region
  owns focus.

## Context routing

The render thread resolves an explicit interaction context with this priority:

1. Modal
2. Text or value edit
3. Focused UI region
4. Simulation canvas
5. Global fallback

Routing is channel-aware. Modal and value-edit contexts own pointer,
navigation, camera, and global shortcuts. A focused UI region owns navigation
and controller camera, while keyboard W/A/S/D/Q/E/C camera controls remain
available for ordinary focused buttons, preserving the original Vizza
behavior. Pointer hit routing remains independent, so hovering a panel does
not disable unrelated keyboard camera control. Engaged editors capture the
complete pointer gesture until commit/cancel, preventing an outside release
from also painting or panning the simulation.

Action ownership remains latched from press/axis activation through release,
so a context or prompt-device change in the middle of a gesture cannot leak a
release or repeat to another consumer.

Control-deck focus has its own semantic action and is routed independently from
`Pause` and `Toggle UI`. Space remains its compatibility keyboard binding, so
the context router gives `Control Deck` priority only in the experimental Slime
UI while Space continues to mean Pause elsewhere. Controller shoulders retain
their shared Focus Previous/Next semantics and are claimed by the deck only
when that controller UI is available.

Steam Input can be added later as another physical binding provider behind the
same semantic actions; it should not become a second application-level routing
system.

## Regression expectations

The action/focus suite covers phase transitions, fast taps, held Back,
simultaneous input families, action ownership versus prompt device, navigation
repeat, circular deadzones, focus-scoped Tab traversal, off-screen reveal,
modal trapping/restoration, one-press controls, keyboard and controller edit
commit/cancel, mixed-device ownership latching, ordered queue backpressure, and
post-navigation focus memory.
