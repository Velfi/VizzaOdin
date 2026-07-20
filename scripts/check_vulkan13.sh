#!/usr/bin/env bash
set -euo pipefail

engine_dir="${ZELDA_ENGINE_ROOT:-../zelda-engine}/packages/engine"
roots=("$engine_dir" packages/render_vk packages/game)
legacy='vk\.CmdPipelineBarrier\(|vk\.QueueSubmit\(|vk\.CmdBeginRenderPass|vk\.CmdEndRenderPass|vk\.CreateRenderPass|vk\.DestroyRenderPass|vk\.CreateFramebuffer|vk\.DestroyFramebuffer|vk\.(ImageMemoryBarrier|BufferMemoryBarrier|MemoryBarrier)\b|vk\.RenderPass\b|vk\.Framebuffer\b'
if rg -n "$legacy" "${roots[@]}"; then
    echo "legacy pre-Vulkan-1.3 rendering or synchronization API remains" >&2
    exit 1
fi

graphics=$(rg -c 'GraphicsPipelineCreateInfo' packages/render_vk | awk -F: '{sum += $2} END {print sum + 0}')
dynamic=$(rg -c 'pNext = &rendering' packages/render_vk | awk -F: '{sum += $2} END {print sum + 0}')
if [ "$graphics" -ne "$dynamic" ]; then
    echo "graphics pipelines=$graphics, dynamic-rendering declarations=$dynamic" >&2
    exit 1
fi

rg -q 'apiVersion = vk_make_version\(1, 3, 0\)' "$engine_dir/vk_context.odin"
rg -q 'Vulkan 1.3 loader is required' "$engine_dir/vk_context.odin"
rg -q 'PhysicalDeviceVulkan13Features' "$engine_dir/vk_context.odin"
rg -q 'vk\.CmdBeginRendering' "$engine_dir/vk_13.odin"
rg -q 'vk\.CmdPipelineBarrier2' "$engine_dir/vk_13.odin"
rg -q 'vk\.QueueSubmit2' "$engine_dir/vk_frame.odin"
rg -q 'vk\.CmdWriteTimestamp2' "$engine_dir/gpu_profiler.odin"
