#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="Metal System Trace"
DURATION="30s"
OUTPUT="$ROOT_DIR/profiles/vizzaodin-gpu.trace"
TARGET=""
MODE="launch"
APP="$ROOT_DIR/build/vizzaodin"

usage() {
  cat <<'USAGE'
Usage:
  scripts/profile_gpu_trace.sh [options]

Options:
  --attach <pid|name>       Attach to a running process instead of launching.
  --launch <path>           Launch this binary. Defaults to build/vizzaodin.
  --duration <time>         xctrace time limit, e.g. 30s, 2m. Defaults to 30s.
  --template <name>         Instruments template. Defaults to Metal System Trace.
  --output <path>           Output .trace path. Defaults to profiles/vizzaodin-gpu.trace.
  -h, --help                Show this help.

Examples:
  scripts/profile_gpu_trace.sh --duration 45s
  scripts/profile_gpu_trace.sh --attach 12345 --duration 2m --output profiles/pl-metal.trace
  scripts/profile_gpu_trace.sh --template "Game Performance" --attach vizzaodin

MCP UI/render workflow:
  1. Start the app with MCP enabled: make mcp
  2. Call the app MCP profile_start tool for the mode and frame window.
  3. Attach this recorder while the profile is active:
     scripts/profile_gpu_trace.sh --attach vizzaodin --duration 30s --output profiles/ui-render.trace
  4. Inspect the .trace with /Users/zelda/Agents/mcps/instruments_mcp.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --attach)
      MODE="attach"
      TARGET="${2:?missing value for --attach}"
      shift 2
      ;;
    --launch)
      MODE="launch"
      APP="${2:?missing value for --launch}"
      shift 2
      ;;
    --duration)
      DURATION="${2:?missing value for --duration}"
      shift 2
      ;;
    --template)
      TEMPLATE="${2:?missing value for --template}"
      shift 2
      ;;
    --output)
      OUTPUT="${2:?missing value for --output}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$(dirname "$OUTPUT")"

run_xctrace_record() {
  set +e
  xcrun xctrace record "$@"
  status=$?
  set -e
  if [[ $status -eq 0 ]]; then
    return 0
  fi
  if [[ $status -eq 54 && -d "$OUTPUT" ]]; then
    return 0
  fi
  return "$status"
}

if [[ "$MODE" == "attach" ]]; then
  if [[ -z "$TARGET" ]]; then
    echo "--attach requires a pid or process name" >&2
    exit 2
  fi
  run_xctrace_record \
    --template "$TEMPLATE" \
    --time-limit "$DURATION" \
    --output "$OUTPUT" \
    --attach "$TARGET"
  exit $?
fi

if [[ ! -x "$APP" ]]; then
  echo "Launch target is not executable: $APP" >&2
  echo "Run make build first, or pass --launch <path>." >&2
  exit 2
fi

MOLTENVK_PREFIX="$(brew --prefix molten-vk 2>/dev/null || true)"
VULKAN_LOADER_PREFIX="$(brew --prefix vulkan-loader 2>/dev/null || true)"
ENV_ARGS=()
if [[ -n "$MOLTENVK_PREFIX" && -n "$VULKAN_LOADER_PREFIX" ]]; then
  ENV_ARGS+=(--env "VK_ICD_FILENAMES=$MOLTENVK_PREFIX/etc/vulkan/icd.d/MoltenVK_icd.json")
  ENV_ARGS+=(--env "DYLD_LIBRARY_PATH=$MOLTENVK_PREFIX/lib:$VULKAN_LOADER_PREFIX/lib")
fi

run_xctrace_record \
  --template "$TEMPLATE" \
  --time-limit "$DURATION" \
  --output "$OUTPUT" \
  "${ENV_ARGS[@]}" \
  --launch -- "$APP"
