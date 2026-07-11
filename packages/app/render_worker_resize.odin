package app

import uifw "../ui"
import engine "../engine"

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sync"
import "core:time"
import sdl "vendor:sdl3"

render_worker_handle_resize :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, cmd: Ui_To_Render_Command) {
		if video_recorder_is_recording(&runtime.video_recorder) {
			video_recorder_stop(&runtime.video_recorder)
			app_ui_video_recording_apply_command_state(&runtime.app_ui, .Idle)
			render_worker_publish_preset_result(state, true, "Stopped video recording because the window was resized")
		}
		gray_scott_resize(&runtime.sim, cmd.width, cmd.height)
		particle_life_resize(&runtime.particle_life, cmd.width, cmd.height)
		vectors_gpu_destroy(&runtime.vectors_gpu, &runtime.vk_ctx)
		vectors_gpu_destroy(&runtime.preview_vectors_gpu, &runtime.vk_ctx)
		moire_gpu_destroy(&runtime.moire_gpu, &runtime.vk_ctx)
		moire_gpu_destroy(&runtime.preview_moire_gpu, &runtime.vk_ctx)
		primordial_gpu_destroy(&runtime.primordial_gpu, &runtime.vk_ctx)
		primordial_gpu_destroy(&runtime.preview_primordial_gpu, &runtime.vk_ctx)
		pellets_gpu_destroy(&runtime.pellets_gpu, &runtime.vk_ctx)
		pellets_gpu_destroy(&runtime.preview_pellets_gpu, &runtime.vk_ctx)
		flow_gpu_destroy(&runtime.flow_gpu, &runtime.vk_ctx)
		flow_gpu_destroy(&runtime.preview_flow_gpu, &runtime.vk_ctx)
		slime_gpu_destroy(&runtime.slime_gpu, &runtime.vk_ctx)
		voronoi_gpu_destroy(&runtime.voronoi_gpu, &runtime.vk_ctx)
		slime_gpu_destroy(&runtime.preview_slime_gpu, &runtime.vk_ctx)
		voronoi_gpu_destroy(&runtime.preview_voronoi_gpu, &runtime.vk_ctx)
		gray_scott_resize(&runtime.preview_gray_scott, runtime.preview_gray_scott.gpu.width, runtime.preview_gray_scott.gpu.height)
		runtime.preview_particle_life.gpu.ready = false
		if runtime.vk_ok {
			if !engine.vk_recreate_swapchain(&runtime.vk_ctx, cmd.width, cmd.height) {
				render_worker_publish_error(state, "Failed to recreate Vulkan swapchain after resize")
			} else {
				render_backend_destroy(&runtime.render_backend, &runtime.vk_ctx)
				vectors_gpu_destroy(&runtime.vectors_gpu, &runtime.vk_ctx)
				vectors_gpu_destroy(&runtime.preview_vectors_gpu, &runtime.vk_ctx)
				moire_gpu_destroy(&runtime.moire_gpu, &runtime.vk_ctx)
				moire_gpu_destroy(&runtime.preview_moire_gpu, &runtime.vk_ctx)
				primordial_gpu_destroy(&runtime.primordial_gpu, &runtime.vk_ctx)
				primordial_gpu_destroy(&runtime.preview_primordial_gpu, &runtime.vk_ctx)
				pellets_gpu_destroy(&runtime.pellets_gpu, &runtime.vk_ctx)
				pellets_gpu_destroy(&runtime.preview_pellets_gpu, &runtime.vk_ctx)
				flow_gpu_destroy(&runtime.flow_gpu, &runtime.vk_ctx)
				flow_gpu_destroy(&runtime.preview_flow_gpu, &runtime.vk_ctx)
				slime_gpu_destroy(&runtime.slime_gpu, &runtime.vk_ctx)
				voronoi_gpu_destroy(&runtime.voronoi_gpu, &runtime.vk_ctx)
				slime_gpu_destroy(&runtime.preview_slime_gpu, &runtime.vk_ctx)
				voronoi_gpu_destroy(&runtime.preview_voronoi_gpu, &runtime.vk_ctx)
				gray_scott_resize(&runtime.preview_gray_scott, runtime.preview_gray_scott.gpu.width, runtime.preview_gray_scott.gpu.height)
				runtime.preview_particle_life.gpu.ready = false
				if !render_backend_init(&runtime.render_backend, &runtime.vk_ctx) {
					runtime.vk_ok = false
					render_worker_publish_error(state, "Failed to recreate render backend after resize")
				}
			}
		}
}
