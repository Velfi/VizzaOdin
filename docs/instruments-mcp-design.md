# Xcode Instruments MCP Inspector Design

This document designs a project-neutral stdio MCP server for inspecting Xcode
Instruments captures. Its purpose is to let an LLM fully read `.instruments` or
`.trace` bundles from any project without loading huge XML exports into one
prompt.

The server should not be part of the running Vizza app MCP. Instruments
captures are offline profiling artifacts, and the existing app MCP is a live
window/input/screenshot bridge. Keeping them separate makes the inspector useful
across projects and avoids putting filesystem and trace-export behavior into the
app process.

## Goals

- Accept an Instruments capture path and expose everything readable from it.
- Use Apple's own `xctrace` exporter as the primary source of truth.
- Preserve raw exported data while adding LLM-friendly indexes, pagination, and
  summaries.
- Work over stdio MCP and be registered once by absolute path.
- Avoid hidden network access, OS automation, or mutation of the input trace.

## Capture Model

Modern Xcode uses `.trace` bundles for Instruments documents. Older workflows
and user language may still refer to `.instruments` files. The inspector should
treat both as trace packages:

- If the input is a directory/package, pass it directly to `xctrace export`.
- If the input is a single file or compressed artifact, first identify it with
  `file`, `plutil`, `sqlite3`, and package metadata probes, then either reject it
  with a precise error or copy/unpack it into the MCP cache if it is a supported
  trace package.
- Never guess table schemas from extension alone. Always ask `xctrace export
  --toc` for the authoritative table of contents.

## Architecture

The server is a small wrapper around three layers:

1. `TraceStore`: validates input paths, assigns stable trace IDs, records file
   metadata, and owns a per-trace cache directory.
2. `XctraceExporter`: shells out to `xcrun xctrace export --input ... --toc` and
   `--xpath ...`, capturing stdout/stderr and command metadata.
3. `TraceIndex`: parses exported XML into table descriptors, column schemas,
   row counts, time ranges, process/thread metadata, and chunk offsets.

Recommended implementation language: Python 3 for the first version. The XML and
SQLite tooling is built in, subprocess handling is straightforward, and it keeps
this profiler-facing tool decoupled from the Odin renderer. If this later needs
to ship as a single binary, port the stable tool contract to Odin after the data
model is proven.

## MCP Surface

### Resources

Expose resources for stable, browsable trace data:

- `instruments://traces`: JSON list of opened traces.
- `instruments://trace/{trace_id}/metadata`: input path, size, mtime, Xcode tool
  version, export status, and cache paths.
- `instruments://trace/{trace_id}/toc`: parsed table of contents from
  `xctrace export --toc`.
- `instruments://trace/{trace_id}/raw/toc.xml`: raw TOC XML.
- `instruments://trace/{trace_id}/table/{table_id}/schema`: table columns,
  types, units, likely keys, and discovered time columns.
- `instruments://trace/{trace_id}/table/{table_id}/rows`: paginated table rows,
  with cursor parameters supplied through resource templates or tools.

MCP resources are good for deterministic reading. Tools should do work:
opening traces, filtering, summarizing, and exporting.

### Tools

#### `open_trace`

Input:

```json
{
  "path": "string",
  "force_reindex": "boolean?"
}
```

Output:

```json
{
  "trace_id": "sha256 path/content prefix",
  "display_name": "string",
  "kind": "trace | instruments | unknown",
  "xctrace_version": "string",
  "toc_resource": "instruments://trace/{trace_id}/toc",
  "warnings": ["string"]
}
```

This validates the file, runs the TOC export, builds the first index, and
returns enough information for an LLM to decide what to inspect next.

#### `list_tables`

Input:

```json
{
  "trace_id": "string",
  "query": "string?",
  "run": "integer?"
}
```

Output includes table IDs, names, schemas, run numbers, row counts when known,
time ranges when known, and the exact XPath used to export each table.

#### `read_table`

Input:

```json
{
  "trace_id": "string",
  "table_id": "string",
  "columns": ["string"]?,
  "filter": {
    "time_start_ns": "integer?",
    "time_end_ns": "integer?",
    "process": "string?",
    "thread": "string?",
    "predicate": "string?"
  },
  "limit": 1000,
  "cursor": "string?"
}
```

Output:

```json
{
  "columns": [{"name": "string", "type": "string", "unit": "string?"}],
  "rows": [{"column": "value"}],
  "next_cursor": "string?",
  "total_rows_estimate": "integer?",
  "source_xpath": "string"
}
```

This is the main LLM reading primitive. It must page results and should default
to compact JSON rows rather than XML.

#### `export_xpath`

Input:

```json
{
  "trace_id": "string",
  "xpath": "string",
  "format": "xml | json",
  "limit_bytes": 1048576,
  "cursor": "string?"
}
```

This is the escape hatch for full fidelity. Any table or node advertised by the
TOC can be exported by XPath. JSON format is best-effort XML normalization; XML
format returns byte chunks of the original export.

#### `search`

Input:

```json
{
  "trace_id": "string",
  "text": "string",
  "tables": ["string"]?,
  "limit": 100
}
```

Search table names, column names, symbols, processes, backtrace frames, call
trees, signposts, and string cells already indexed in the cache.

#### `summarize`

Input:

```json
{
  "trace_id": "string",
  "focus": "cpu | gpu | memory | allocations | leaks | hangs | io | network | signposts | all",
  "time_start_ns": "integer?",
  "time_end_ns": "integer?"
}
```

This returns derived facts, not replacement data: top processes, hot functions,
largest allocations, leak groups, busiest threads, long stalls, signpost
intervals, and links to the backing tables/resources.

#### `call_tree`

Input:

```json
{
  "trace_id": "string",
  "table_id": "string?",
  "root": "string?",
  "invert": "boolean?",
  "limit": 200
}
```

For Time Profiler-style captures, expose a compact tree with symbol, library,
self time, total time, sample count, and child cursor IDs. The raw backing table
must remain readable through `read_table` or `export_xpath`.

#### `timeline`

Input:

```json
{
  "trace_id": "string",
  "tracks": ["cpu", "thread", "memory", "signpost", "gpu"]?,
  "bucket_ns": "integer?",
  "time_start_ns": "integer?",
  "time_end_ns": "integer?"
}
```

Returns bucketed time-series data suitable for LLM reasoning and optional chart
rendering: CPU samples, allocations, resident memory, signposts, thread states,
and frame/GPU events when present.

#### `diagnostics`

Input:

```json
{
  "trace_id": "string"
}
```

Returns exporter commands, stderr, parse warnings, unsupported table shapes, and
cache stats. This is important because `xctrace` output can vary by Xcode
version and instrument template.

## Data Flow

Opening a trace:

1. Normalize and validate the path.
2. Run `xcrun xctrace version`.
3. Run `xcrun xctrace export --input <path> --toc`.
4. Save raw TOC XML in `.cache/instruments-mcp/{trace_id}/toc.xml`.
5. Parse TOC into runs, tables, schemas, table names, and XPath addresses.
6. Lazily export tables only when the LLM requests them.

Reading a table:

1. Resolve `table_id` to the TOC XPath.
2. Run `xcrun xctrace export --input <path> --xpath <table_xpath>` if the table
   is not cached or the source mtime changed.
3. Stream-parse XML into SQLite or newline-delimited JSON in the cache.
4. Apply column projection, filters, and pagination.
5. Return compact JSON plus a cursor.

The cache should be content-addressed by input path, size, mtime, and Xcode
version. Trace files can be large; never pre-export every table during
`open_trace`.

## Handling Full Readability

"Fully read" means every byte that `xctrace` exposes is reachable, not that every
byte is emitted in one response. The design guarantees this through:

- Raw TOC access.
- Raw XPath export access.
- Cursor-based byte chunks for huge XML exports.
- Parsed table access for structured reasoning.
- Diagnostics when data is not exported by Xcode.

If an artifact contains files not surfaced by `xctrace`, add a `package_tree`
tool that lists bundle contents and a `read_package_file` tool that reads safe,
bounded chunks from text, plist, SQLite, or binary files. These tools should be
clearly marked as package inspection, while `xctrace` remains authoritative for
Instruments semantics.

## Safety

- Only read paths explicitly passed to `open_trace`.
- Resolve symlinks and reject paths outside configured allowed roots unless the
  MCP client opts into broader access at launch.
- Do not execute commands from trace contents.
- Do not mutate traces. Symbolication/remodeling should be separate opt-in tools
  because they can create or modify artifacts.
- Limit `xctrace` runtime and output bytes per call. Return continuation cursors
  instead of unbounded text.
- Store cache files under the workspace or an explicit `--cache-dir`.

## Proposed Files

Initial implementation lives outside the app binary:

- `/Users/zelda/Agents/mcps/instruments_mcp/instruments_mcp.py`: generic
  stdio MCP server.
- `/Users/zelda/Agents/mcps/instruments_mcp/README.md`: standalone setup
  notes.
- `docs/instruments-mcp-design.md`: this design.
- Optional `tests/fixtures/`: tiny exported XML fixtures, not full Apple trace
  captures.

Client config:

```json
{
  "mcpServers": {
    "instruments": {
      "command": "python3",
      "args": [
        "/Users/zelda/Agents/mcps/instruments_mcp/instruments_mcp.py",
        "--cache-dir",
        "/Users/zelda/.cache/instruments-mcp"
      ]
    }
  }
}
```

The MCP contract does not depend on VizzaOdin paths or packages.

## Implementation Notes

- Use line-delimited JSON-RPC over stdin/stdout to match the existing MCP style.
- Write diagnostics to stderr only.
- Use `xml.etree.ElementTree.iterparse` or `lxml` if vendored later; do not load
  multi-gigabyte exports into memory.
- Store parsed rows in SQLite when a table exceeds a small threshold. SQLite
  enables filtering and pagination without keeping the whole table in RAM.
- Keep a `raw_exports` directory alongside parsed tables so lossless XML chunks
  are always available.
- Assign stable table IDs from run number plus TOC schema/name/XPath hash.
- Include source XPath in every structured response so the LLM can ask for raw
  backing data.

## Milestones

1. Minimal MCP handshake, `open_trace`, `list_tables`, raw TOC resource.
2. `export_xpath` with byte cursors.
3. `read_table` with lazy XML-to-JSON parsing and pagination.
4. SQLite-backed indexing and `search`.
5. Domain summaries for Time Profiler, Allocations, Leaks, System Trace, GPU,
   signposts, and networking.
6. Optional package fallback tools for files not visible through `xctrace`.

The first three milestones are enough for complete LLM readability. Later
milestones make traces easier to reason about, but they should not replace raw
TOC/XPath access.
