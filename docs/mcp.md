# VizzaOdin MCP Control

`build/vizzaodin --mcp` runs the native app as a stdio MCP server. The MCP
client launches the app process, sends JSON-RPC on stdin, and receives JSON-RPC
on stdout. App diagnostics are written to stderr in MCP mode so stdout remains
valid MCP traffic.

## Tools

- `app_status`: read status from the running app.
- `profile_start`: switch to a mode and begin a nonblocking UI/render profile
  over a fixed frame window. Defaults to 240 frames.
- `profile_status`: read profile collection progress.
- `profile_report`: return aggregate UI/render timings, command counts, text
  shaping metrics, GPU UI overlay timing, and sanitizer findings.
- `profile_reset`: clear the current profile session.
- `screenshot`: return the latest engine-rendered frame as a base64 QOI data
  URL from Vulkan swapchain readback. Optional arguments `scale`, `max_width`,
  and `max_height` reduce the returned image dimensions and payload size.
- `click`: inject a window-relative click through the app input path.
- `move`: update the app's logical mouse position.
- `wheel`: inject mouse wheel delta.
- `close_app`: ask the app to close.

The profile tools are passive once started: the app continues rendering normally
and frame stats are accumulated as `Frame_Stats` messages reach the UI thread.
The sanitizer reports warnings only; it does not fail or alter the simulation.

No filesystem transport, OS screenshot API, Accessibility automation, or
loopback socket is used by this MCP mode.

## Client Config

Build the app first:

```sh
make build
```

Then register the MCP server with a client that supports stdio MCP:

```json
{
  "mcpServers": {
    "vizzaodin": {
      "command": "/Users/zelda/Documents/VizzaOdin/build/vizzaodin",
      "args": ["--mcp"]
    }
  }
}
```

You can also run it directly for debugging:

```sh
make mcp
```

On Homebrew macOS Vulkan setups, use the same MoltenVK environment as the app
run target:

```sh
make mcp-macos-vulkan
```

MCP clients that support an `env` block can use the same `VK_ICD_FILENAMES` and
`DYLD_LIBRARY_PATH` values from `make run-macos-vulkan`.

## Related MCP Designs

- `docs/instruments-mcp-design.md`: generic offline MCP inspector design for
  Xcode Instruments `.trace`/`.instruments` captures.
- `/Users/zelda/Agents/mcps/instruments_mcp/README.md`: project-neutral MCP
  server that can be registered once and used across workspaces.
