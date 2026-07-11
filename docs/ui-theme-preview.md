# UI Theme Preview

The UI package has a deterministic design-sheet mode for reviewing widget
states through the same renderer as the app.

Run it directly:

```sh
make theme-preview
```

Run it as an MCP screenshot source:

```sh
make theme-preview-mcp
```

The `theme-preview-mcp` target launches `build/vizzaodin --theme-preview --mcp`.
Use the existing MCP `screenshot` tool to capture the latest rendered frame as a
base64 QOI data URL. The preview sheet includes:

- headings, labels, wrapped text, and clipped text
- buttons in normal, hover, active, and disabled states
- cards in enabled, hover, active, and disabled states
- toggles, sliders, numeric inputs, selectors, and collapsibles
- color picker, 2D area slider, checkbox, switch, radio group, combobox, and
  circular progress samples
- image tint/crop/filter/blend samples, palette swatches, geometry primitives,
  and grid/anchor/distribution layout samples

The app flag can also be passed directly:

```sh
build/vizzaodin --theme-preview
build/vizzaodin --theme-preview --mcp
```

## Isolated component renderer

Render an individual component through the same layout, font shaping, draw
commands, Vulkan overlay, and screenshot readback used by the application:

```sh
make ui-component COMPONENT=number STATE=editing VALUE=12.5
python3 scripts/render_ui_component.py slider --state focused --value 0.72
```

PNGs are written to `build/ui-components/` unless `OUTPUT=/path/image.png` or
`--output /path/image.png` is supplied. Output is cropped to the isolated
fixture card by default; pass `--full-frame` when the surrounding renderer
canvas is useful. Available fixtures are `button`,
`toggle`, `slider`, `number`, `integer`, `selector`, and `text_input`; available states are
`rest`, `hover`, `active`, `focused`, `editing`, and `disabled`.

An MCP client can use `list_ui_components`, call `render_ui_component`, wait
for the next frame, and then call `screenshot`. Keeping fixture selection
separate from screenshot capture makes it possible to inspect a live fixture,
inject pointer input, or capture several sizes without restarting the app.
