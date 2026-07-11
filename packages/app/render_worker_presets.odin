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

render_worker_handle_preset_command :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, cmd: Ui_To_Render_Command) -> bool {
	#partial switch cmd.kind {
	case .Load_Preset:
		preset_name := cmd.preset_name
		path := render_worker_preset_path(state, preset_name[:], false)
		if runtime.app_ui.mode == .Particle_Life {
			if settings, ok := settings_load_particle_life_preset(path, runtime.particle_life.settings); ok {
				particle_life_load_settings(&runtime.particle_life, settings)
				render_worker_publish_preset_result(state, true, "Loaded Particle Life TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Particle Life TOML preset")
			}
		} else if runtime.app_ui.mode == .Flow_Field {
			if settings, ok := settings_load_flow_preset(path, runtime.app_ui.flow_field.flow); ok {
				runtime.app_ui.flow_field.flow = settings
				image_path := fixed_string(settings.image_path[:])
				if len(image_path) > 0 {
					_ = flow_gpu_load_vector_field_image_path(&runtime.flow_gpu, &runtime.vk_ctx, image_path, &runtime.app_ui.flow_field.flow)
				}
				render_worker_publish_preset_result(state, true, "Loaded Flow TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Flow TOML preset")
			}
		} else if runtime.app_ui.mode == .Moire {
			if settings, ok := settings_load_moire_preset(path, runtime.app_ui.moire.moire); ok {
				runtime.app_ui.moire.moire = settings
				image_path := fixed_string(settings.image_path[:])
				if len(image_path) > 0 {
					_ = moire_gpu_load_image_path(&runtime.moire_gpu, &runtime.vk_ctx, image_path, &runtime.app_ui.moire.moire)
				}
				render_worker_publish_preset_result(state, true, "Loaded Moire TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Moire TOML preset")
			}
		} else if runtime.app_ui.mode == .Vectors {
			if settings, ok := settings_load_vectors_preset(path, runtime.app_ui.vectors.vectors); ok {
				runtime.app_ui.vectors.vectors = settings
				image_path := fixed_string(settings.image_path[:])
				if len(image_path) > 0 {
					_ = vectors_gpu_load_image_path(&runtime.vectors_gpu, image_path, &runtime.app_ui.vectors.vectors)
				}
				render_worker_publish_preset_result(state, true, "Loaded Vectors TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Vectors TOML preset")
			}
		} else if runtime.app_ui.mode == .Primordial {
			if settings, ok := settings_load_primordial_preset(path, runtime.app_ui.primordial.primordial); ok {
				runtime.app_ui.primordial.primordial = settings
				runtime.primordial_gpu.ready = false
				render_worker_publish_preset_result(state, true, "Loaded Primordial TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Primordial TOML preset")
			}
		} else if runtime.app_ui.mode == .Pellets {
			if settings, ok := settings_load_pellets_preset(path, runtime.app_ui.pellets.pellets); ok {
				runtime.app_ui.pellets.pellets = settings
				runtime.pellets_gpu.ready = false
				render_worker_publish_preset_result(state, true, "Loaded Pellets TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Pellets TOML preset")
			}
		} else if runtime.app_ui.mode == .Voronoi_CA {
			if settings, ok := settings_load_voronoi_preset(path, runtime.app_ui.voronoi_ca.voronoi); ok {
				runtime.app_ui.voronoi_ca.voronoi = settings
				runtime.voronoi_gpu.needs_rebuild = true
				render_worker_publish_preset_result(state, true, "Loaded Voronoi TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Voronoi TOML preset")
			}
		} else if runtime.app_ui.mode == .Slime_Mold {
			if settings, ok := settings_load_slime_preset(path, runtime.app_ui.slime_mold.slime); ok {
				runtime.app_ui.slime_mold.slime = settings
				if slime_gpu_ensure(&runtime.slime_gpu, &runtime.vk_ctx, &runtime.app_ui.slime_mold.slime) {
					mask_path := fixed_string(settings.mask_image_path[:])
					if len(mask_path) > 0 && settings.mask_pattern == .Image {
						_ = slime_gpu_load_mask_image_path(&runtime.slime_gpu, mask_path, &runtime.app_ui.slime_mold.slime)
					}
					position_path := fixed_string(settings.position_image_path[:])
					if len(position_path) > 0 && settings.position_generator == 7 {
						_ = slime_gpu_load_position_image_path(&runtime.slime_gpu, position_path, &runtime.app_ui.slime_mold.slime)
					}
				}
				runtime.slime_gpu.needs_reset = true
				render_worker_publish_preset_result(state, true, "Loaded Slime TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Slime TOML preset")
			}
		} else {
			if settings, ok := settings_load_gray_scott_preset(path, runtime.sim.settings); ok {
				gray_scott_load_settings(&runtime.sim, settings)
				render_worker_publish_preset_result(state, true, "Loaded Gray-Scott TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to load Gray-Scott TOML preset")
			}
		}
	case .Save_Preset:
		preset_name := cmd.preset_name
		path := render_worker_preset_path(state, preset_name[:], true)
		if runtime.app_ui.mode == .Particle_Life {
			if settings_save_particle_life(path, particle_life_save_settings(&runtime.particle_life)) {
				render_worker_publish_preset_result(state, true, "Saved Particle Life TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Particle Life TOML preset")
			}
		} else if runtime.app_ui.mode == .Flow_Field {
			if settings_save_flow(path, runtime.app_ui.flow_field.flow) {
				render_worker_publish_preset_result(state, true, "Saved Flow TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Flow TOML preset")
			}
		} else if runtime.app_ui.mode == .Moire {
			if settings_save_moire(path, runtime.app_ui.moire.moire) {
				render_worker_publish_preset_result(state, true, "Saved Moire TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Moire TOML preset")
			}
		} else if runtime.app_ui.mode == .Vectors {
			if settings_save_vectors(path, runtime.app_ui.vectors.vectors) {
				render_worker_publish_preset_result(state, true, "Saved Vectors TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Vectors TOML preset")
			}
		} else if runtime.app_ui.mode == .Primordial {
			if settings_save_primordial(path, runtime.app_ui.primordial.primordial) {
				render_worker_publish_preset_result(state, true, "Saved Primordial TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Primordial TOML preset")
			}
		} else if runtime.app_ui.mode == .Pellets {
			if settings_save_pellets(path, runtime.app_ui.pellets.pellets) {
				render_worker_publish_preset_result(state, true, "Saved Pellets TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Pellets TOML preset")
			}
		} else if runtime.app_ui.mode == .Voronoi_CA {
			if settings_save_voronoi(path, runtime.app_ui.voronoi_ca.voronoi) {
				render_worker_publish_preset_result(state, true, "Saved Voronoi TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Voronoi TOML preset")
			}
		} else if runtime.app_ui.mode == .Slime_Mold {
			if settings_save_slime(path, runtime.app_ui.slime_mold.slime) {
				render_worker_publish_preset_result(state, true, "Saved Slime TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Slime TOML preset")
			}
		} else {
			if settings_save_gray_scott(path, runtime.sim.settings) {
				render_worker_publish_preset_result(state, true, "Saved Gray-Scott TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to save Gray-Scott TOML preset")
			}
		}
	case .Delete_Preset:
		preset_name := cmd.preset_name
		path := render_worker_preset_path(state, preset_name[:], false)
		if err := os.remove(path); err == nil {
			if runtime.app_ui.mode == .Particle_Life {
				render_worker_publish_preset_result(state, true, "Deleted Particle Life TOML preset")
			} else {
				render_worker_publish_preset_result(state, true, "Deleted Gray-Scott TOML preset")
			}
		} else {
			if runtime.app_ui.mode == .Particle_Life {
				render_worker_publish_preset_result(state, false, "Failed to delete Particle Life TOML preset")
			} else {
				render_worker_publish_preset_result(state, false, "Failed to delete Gray-Scott TOML preset")
			}
		}
	case:
		return false
	}
	return true
}
