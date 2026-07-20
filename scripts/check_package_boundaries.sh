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

ENGINE_DIR="${ZELDA_ENGINE_ROOT:-../zelda-engine}/packages/engine"
UI_DIR="${ZELDA_ENGINE_ROOT:-../zelda-engine}/packages/ui"

reject_imports "$ENGINE_DIR" 'import[^\n]*"\.\./(game|app)(/|\")' \
	'engine must not depend on game or app'
reject_imports "$ENGINE_DIR" 'import[^\n]*"\.\./ui(/|\")' \
	'engine must not depend on the renderer-neutral UI package'
reject_imports "$UI_DIR" 'import[^\n]*"\.\./(engine|game|app)(/|\")' \
	'ui must remain renderer-neutral and must not depend on engine, game, or app'
reject_imports packages/game 'import[^\n]*"\.\./app(/|\")' \
	'game must not depend on the app composition layer'
reject_imports packages/game 'import[^\n]*"\.\./render_vk(/|\")' \
	'game must not depend on the Vulkan renderer adapter'
reject_imports packages/render_vk 'import[^\n]*"\.\./app(/|\")' \
	'render_vk must not depend on the app composition layer'

if rg -n 'Vk_Context|vendor:vulkan' packages/game/app_ui*.odin >/dev/null; then
	printf '%s\n' 'Product UI must receive renderer-neutral viewport and service contracts, not Vulkan context' >&2
	failed=1
fi
if rg -n 'Vk_Context|vendor:vulkan|vk\.Format' packages/game/video_capture.odin >/dev/null; then
	printf '%s\n' 'Video capture service contracts must use renderer-neutral pixel formats' >&2
	failed=1
fi
if [[ -e packages/game/ui_render_sink.odin ]] || rg -n 'Ui_Render_Sink' packages/game -g '*.odin' >/dev/null; then
	printf '%s\n' 'Vulkan UI overlay callbacks belong to render_vk, not the product package' >&2
	failed=1
fi

if rg -n 'vendor:vulkan|Moire_Gpu_State|Moire_Image' packages/game/moire_gpu_types.odin >/dev/null; then
	printf '%s\n' 'Moire product ABI must remain renderer-neutral; Vulkan runtime belongs in render_vk' >&2
	failed=1
fi
if rg -n 'vendor:vulkan|Voronoi_Gpu_State|Voronoi_Image' packages/game/voronoi_gpu_types.odin >/dev/null; then
	printf '%s\n' 'Voronoi product ABI must remain renderer-neutral; Vulkan runtime belongs in render_vk' >&2
	failed=1
fi
if rg -n 'vendor:vulkan|Flow_Gpu_State|Flow_Image|Vk_' packages/game/flow_gpu_types.odin >/dev/null; then
	printf '%s\n' 'Flow product ABI must remain renderer-neutral; Vulkan runtime belongs in render_vk' >&2
	failed=1
fi
if rg -n 'vendor:vulkan|Slime_Gpu_State|Slime_Image|Vk_' packages/game/slime_gpu_types.odin >/dev/null; then
	printf '%s\n' 'Slime product ABI must remain renderer-neutral; Vulkan runtime belongs in render_vk' >&2
	failed=1
fi
if rg -n 'vendor:vulkan|Vectors_Gpu_State|Vk_' packages/game/vectors_gpu_types.odin >/dev/null; then
	printf '%s\n' 'Vectors product ABI must remain renderer-neutral; Vulkan runtime belongs in render_vk' >&2
	failed=1
fi
if rg -n 'vendor:vulkan|Pellets_Gpu_State|Pellets_Trail_Image|Vk_' packages/game/pellets_gpu_types.odin >/dev/null; then
	printf '%s\n' 'Pellets product ABI must remain renderer-neutral; Vulkan runtime belongs in render_vk' >&2
	failed=1
fi
if rg -n 'vendor:vulkan|Primordial_Gpu_State|Primordial_Trace_Image|Vk_' packages/game/primordial_gpu_types.odin >/dev/null; then
	printf '%s\n' 'Primordial product ABI must remain renderer-neutral; Vulkan runtime belongs in render_vk' >&2
	failed=1
fi
if rg -n 'vendor:vulkan|Gray_Scott_Gpu_State|Gray_Scott_Gpu_Image|Vk_' packages/game/gray_scott_gpu_types.odin >/dev/null; then
	printf '%s\n' 'Gray-Scott product ABI must remain renderer-neutral; Vulkan runtime belongs in render_vk' >&2
	failed=1
fi
if rg -n 'vendor:vulkan|Particle_Life_Gpu_State|Particle_Life_Trail_Image|Vk_' packages/game/particle_life_model.odin >/dev/null; then
	printf '%s\n' 'Particle Life product model must remain renderer-neutral; Vulkan runtime belongs in render_vk' >&2
	failed=1
fi
if rg -n '\.gpu\b' packages/game/gray_scott_model.odin packages/game/gray_scott_controls.odin packages/game/app_ui_simulation_input.odin >/dev/null; then
	printf '%s\n' 'Gray-Scott product state and UI must use renderer-neutral runtime status, not embedded GPU state' >&2
	failed=1
fi
if rg -n '\.gpu\b' packages/game/app_ui_main_menu_content.odin >/dev/null; then
	printf '%s\n' 'Particle Life product UI must consume renderer-neutral runtime status' >&2
	failed=1
fi
if rg -n '\.gpu\b|Vk_Buffer|vendor:vulkan' packages/game/particle_life_analysis.odin packages/game/particle_life_controls.odin packages/game/particle_life_forces.odin packages/game/particle_life_simulation.odin >/dev/null; then
	printf '%s\n' 'Particle Life product behavior must use runtime snapshots and renderer requests, not GPU storage' >&2
	failed=1
fi
if rg -n 'kind[[:space:]]*=[[:space:]]*\.(Load_Gray_Scott_Nutrient_Image|Load_Vectors_Image|Load_Moire_Image|Load_Flow_Image|Load_Slime_Mask_Image|Load_Slime_Position_Image|Clear_Gray_Scott_Nutrient_Image|Clear_Vectors_Image|Clear_Moire_Image|Clear_Flow_Image|Clear_Slime_Mask_Image|Clear_Slime_Position_Image)' packages/app packages/game -g '*.odin' -g '!mcp_bridge_tools.odin' -g '!mcp_bridge.odin' >/dev/null; then
	printf '%s\n' 'Feature image operations must cross queues through Feature_Command' >&2
	failed=1
fi
if rg -n '\b(Load_Preset|Save_Preset|Delete_Preset)\b|preset_name:[[:space:]]*\[MAX_PRESET_NAME\]u8' packages/app packages/game -g '*.odin' >/dev/null; then
	printf '%s\n' 'Named preset operations must route through schema-validated Feature_Command payloads' >&2
	failed=1
fi
if rg -n 'ctx\.app_mode[[:space:]]*==[[:space:]]*\.(Slime_Mold|Gray_Scott|Particle_Life|Flow_Field|Pellets|Voronoi_CA|Moire|Vectors|Primordial)' packages/render_vk/render_graph_passes.odin packages/render_vk/render_graph_scene.odin >/dev/null; then
	printf '%s\n' 'Core render-graph passes must dispatch product features through the registry' >&2
	failed=1
fi

exit "$failed"
