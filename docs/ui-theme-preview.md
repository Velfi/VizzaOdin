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
- toggles, sliders, number drags, selectors, and collapsibles
- color picker, 2D area slider, checkbox, switch, radio group, combobox, and
  circular progress samples
- image tint/crop/filter/blend samples, palette swatches, geometry primitives,
  and grid/anchor/distribution layout samples

The app flag can also be passed directly:

```sh
build/vizzaodin --theme-preview
build/vizzaodin --theme-preview --mcp
```
