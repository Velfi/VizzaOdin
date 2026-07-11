- VizzaOdin: Odin/Slang port based on Rust/Tauri app Vizza (~/Documents/Vizza)
  - VizzaOdin has a special Mouse + KB/Controller-friendly UI; The old app does not.

- Preserve the distinction between settings and runtime state:
  - Settings are user-configurable, serializable values that belong in saved
    presets or application preferences.
  - Runtime state includes transient or computed data such as simulation
    buffers, current particle positions, timing, render status, and UI focus.
  - Do not add runtime state to preset serialization unless explicitly required.
