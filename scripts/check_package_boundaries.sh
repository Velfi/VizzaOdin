#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT_DIR"

failed=0

reject_imports() {
	local package_dir="$1"
	shift
	local pattern="$1"
	shift
	local message="$1"
	local matches
	matches="$(rg -n "$pattern" "$package_dir" -g '*.odin' || true)"
	if [[ -n "$matches" ]]; then
		printf '%s\n%s\n' "$message" "$matches" >&2
		failed=1
	fi
}

reject_imports packages/engine 'import[^\n]*"\.\./(game|app)(/|\")' \
	'engine must not depend on game or app'
reject_imports packages/engine 'import[^\n]*"\.\./ui(/|\")' \
	'engine must not depend on the renderer-neutral UI package'
reject_imports packages/ui 'import[^\n]*"\.\./(engine|game|app)(/|\")' \
	'ui must remain renderer-neutral and must not depend on engine, game, or app'
reject_imports packages/game 'import[^\n]*"\.\./app(/|\")' \
	'game must not depend on the app composition layer'
reject_imports packages/game 'import[^\n]*"\.\./render_vk(/|\")' \
	'game must not depend on the Vulkan renderer adapter'
reject_imports packages/render_vk 'import[^\n]*"\.\./app(/|\")' \
	'render_vk must not depend on the app composition layer'

exit "$failed"
