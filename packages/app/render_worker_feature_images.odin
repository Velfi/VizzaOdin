package app

import "core:fmt"

render_worker_dispatch_feature_image :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, feature_id: Feature_Id, payload: ^Feature_Image_Command, clear: bool) -> bool {
	if state == nil || runtime == nil || payload == nil do return false
	path := fixed_string(payload.path[:])
	target, target_ok := feature_image_target(feature_id, payload.slot)
	if !target_ok do return false
	if clear {
		switch target {
		case .Gray_Scott_Nutrient:
			write_fixed_string(runtime.app_ui.gray_scott.settings.nutrient_image_path[:], "")
			runtime.app_ui.gray_scott.runtime.nutrient_image_loaded = false
			gray_scott_upload_nutrient_map(&runtime.app_ui.gray_scott)
			render_worker_publish_preset_result(state, true, "Cleared Gray-Scott nutrient image")
		case .Vectors:
			write_fixed_string(runtime.app_ui.vectors.vectors.image_path[:], "")
			gpu := render_worker_vectors_gpu(runtime)
			write_fixed_string(gpu.image_path[:], "")
			gpu.image_loaded = false
			runtime.app_ui.vectors.vectors.vector_field_type = .Noise
			runtime.app_ui.vectors.vectors.vector_field_index = int(Vector_Field_Type.Noise)
			render_worker_publish_preset_result(state, true, "Cleared Vectors image")
		case .Moire:
			write_fixed_string(runtime.app_ui.moire.moire.image_path[:], "")
			gpu := render_worker_moire_gpu(runtime)
			write_fixed_string(gpu.image_path[:], "")
			gpu.image_loaded = false
			runtime.app_ui.moire.moire.image_mode_enabled = false
			render_worker_publish_preset_result(state, true, "Cleared Moire image")
		case .Flow:
			write_fixed_string(runtime.app_ui.flow_field.flow.image_path[:], "")
			gpu := render_worker_flow_gpu(runtime)
			write_fixed_string(gpu.vector_field_image_path[:], "")
			gpu.vector_field_image_loaded = false
			runtime.app_ui.flow_field.flow.vector_field_type = .Noise
			runtime.app_ui.flow_field.flow.vector_field_index = int(Vector_Field_Type.Noise)
			render_worker_publish_preset_result(state, true, "Cleared Flow image")
		case .Slime_Mask:
			gpu := render_worker_slime_gpu(runtime)
			write_fixed_string(runtime.app_ui.slime_mold.slime.mask_image_path[:], "")
			runtime.app_ui.slime_mold.slime.mask_pattern = .Disabled
			runtime.app_ui.slime_mold.slime.mask_pattern_index = int(Slime_Mask_Pattern.Disabled)
			if gpu.mask_buffer.mapped != nil {
				data := (cast([^]f32)gpu.mask_buffer.mapped)[:int(gpu.width * gpu.height)]
				for i in 0 ..< len(data) do data[i] = 0
			}
			render_worker_publish_preset_result(state, true, "Cleared Slime mask image")
		case .Slime_Position:
			gpu := render_worker_slime_gpu(runtime)
			write_fixed_string(runtime.app_ui.slime_mold.slime.position_image_path[:], "")
			runtime.app_ui.slime_mold.slime.position_generator = 0
			runtime.app_ui.slime_mold.slime.position_generator_index = 0
			gpu.needs_reset = true
			render_worker_publish_preset_result(state, true, "Cleared Slime position image")
		case: return false
		}
		return true
	}
	if len(path) == 0 do return false
	switch target {
	case .Gray_Scott_Nutrient:
		write_fixed_string(runtime.app_ui.gray_scott.settings.nutrient_image_path[:], path)
		runtime.app_ui.gray_scott.settings.mask_pattern = .Nutrient_Map
		gray_scott_upload_nutrient_map(&runtime.app_ui.gray_scott)
		ok := runtime.app_ui.gray_scott.runtime.nutrient_image_loaded
		render_worker_publish_preset_result(state, ok, ok ? "Loaded Gray-Scott nutrient image" : "Failed to load Gray-Scott nutrient image")
	case .Vectors:
		runtime.app_ui.vectors.vectors.vector_field_type = .Image
		runtime.app_ui.vectors.vectors.vector_field_index = int(Vector_Field_Type.Image)
		write_fixed_string(runtime.app_ui.vectors.vectors.image_path[:], path)
		ok := vectors_gpu_load_image_path(render_worker_vectors_gpu(runtime), &runtime.vk_ctx, path, runtime.app_ui.vectors.vectors)
		render_worker_publish_preset_result(state, ok, ok ? "Loaded Vectors image" : "Failed to load Vectors image")
	case .Moire:
		runtime.app_ui.moire.moire.image_mode_enabled = true
		write_fixed_string(runtime.app_ui.moire.moire.image_path[:], path)
		ok := moire_gpu_load_image_path(render_worker_moire_gpu(runtime), &runtime.vk_ctx, path, runtime.app_ui.moire.moire)
		render_worker_publish_preset_result(state, ok, ok ? "Loaded Moire image" : "Failed to load Moire image")
	case .Flow:
		runtime.app_ui.flow_field.flow.vector_field_type = .Image
		runtime.app_ui.flow_field.flow.vector_field_index = int(Vector_Field_Type.Image)
		write_fixed_string(runtime.app_ui.flow_field.flow.image_path[:], path)
		ok := flow_gpu_load_vector_field_image_path(render_worker_flow_gpu(runtime), &runtime.vk_ctx, path, runtime.app_ui.flow_field.flow)
		render_worker_publish_preset_result(state, ok, ok ? "Loaded Flow image" : "Failed to load Flow image")
	case .Slime_Mask, .Slime_Position:
		gpu := render_worker_slime_gpu(runtime)
		if !slime_gpu_ensure(gpu, &runtime.vk_ctx, runtime.app_ui.slime_mold.slime) {
			render_worker_publish_preset_result(state, false, fmt.tprintf("Failed to initialize Slime image target %dx%d", gpu.width, gpu.height))
			return true
		}
		if target == .Slime_Mask {
			ok, reason := slime_gpu_load_mask_image_path_diagnostic(gpu, path, runtime.app_ui.slime_mold.slime)
			render_worker_publish_preset_result(state, ok, ok ? "Loaded Slime mask image" : fmt.tprintf("Failed to load Slime mask image: %s", reason))
		} else {
			ok := slime_gpu_load_position_image_path(gpu, path, runtime.app_ui.slime_mold.slime)
			render_worker_publish_preset_result(state, ok, ok ? "Loaded Slime position image" : "Failed to load Slime position image")
		}
	case: return false
	}
	return true
}

// Restore renderer-owned image resources referenced by newly loaded settings.
// Features without image sources require no service work.
render_worker_restore_feature_images :: proc(runtime: ^Render_Worker_Runtime, mode: App_Mode) -> bool {
	if runtime == nil do return false
	#partial switch mode {
	case .Gray_Scott:
		path := fixed_string(runtime.app_ui.gray_scott.settings.nutrient_image_path[:])
		if len(path) > 0 do gray_scott_upload_nutrient_map(&runtime.app_ui.gray_scott)
	case .Flow_Field:
		path := fixed_string(runtime.app_ui.flow_field.flow.image_path[:])
		if len(path) > 0 do return flow_gpu_load_vector_field_image_path(render_worker_flow_gpu(runtime), &runtime.vk_ctx, path, runtime.app_ui.flow_field.flow)
	case .Moire:
		path := fixed_string(runtime.app_ui.moire.moire.image_path[:])
		if len(path) > 0 do return moire_gpu_load_image_path(render_worker_moire_gpu(runtime), &runtime.vk_ctx, path, runtime.app_ui.moire.moire)
	case .Vectors:
		path := fixed_string(runtime.app_ui.vectors.vectors.image_path[:])
		if len(path) > 0 do return vectors_gpu_load_image_path(render_worker_vectors_gpu(runtime), &runtime.vk_ctx, path, runtime.app_ui.vectors.vectors)
	case .Slime_Mold:
		settings := runtime.app_ui.slime_mold.slime
		gpu := render_worker_slime_gpu(runtime)
		if !slime_gpu_ensure(gpu, &runtime.vk_ctx, settings) do return false
		mask_path := fixed_string(settings.mask_image_path[:])
		if len(mask_path) > 0 && settings.mask_pattern == .Image {
			if !slime_gpu_load_mask_image_path(gpu, mask_path, settings) do return false
		}
		position_path := fixed_string(settings.position_image_path[:])
		if len(position_path) > 0 && settings.position_generator == 7 {
			if !slime_gpu_load_position_image_path(gpu, position_path, settings) do return false
		}
	case:
	}
	return true
}
