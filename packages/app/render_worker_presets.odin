package app

import "core:fmt"
import "core:os"

render_worker_handle_preset_file_command :: proc(state: ^Render_Worker_State, runtime: ^Render_Worker_Runtime, mode: App_Mode, payload: Feature_Preset_File_Command) -> bool {
	if state == nil || runtime == nil do return false
	descriptor, found := feature_descriptor_by_mode(mode)
	instance := feature_instance_set_get(&runtime.app_ui.feature_instances, mode)
	if !found || instance == nil do return false

	ensure_directory := payload.operation == .Save
	preset_name := payload.path
	path := render_worker_preset_path(state, preset_name[:], ensure_directory)
	ok := false
	verb := ""
	action := ""
	#partial switch payload.operation {
	case .Load:
		verb = "Loaded"
		action = "load"
		ok = descriptor.preset_load != nil && descriptor.preset_load(instance.settings, instance.runtime, path)
		if ok {
			render_worker_mark_mode_dirty(runtime, mode)
			ok = render_worker_restore_feature_images(runtime, mode)
		}
	case .Save:
		verb = "Saved"
		action = "save"
		ok = descriptor.preset_save != nil && descriptor.preset_save(instance.settings, instance.runtime, path)
	case .Delete:
		verb = "Deleted"
		action = "delete"
		ok = os.remove(path) == nil
	case:
		return false
	}

	message := ok ? fmt.tprintf("%s %s TOML preset", verb, descriptor.name) : fmt.tprintf("Failed to %s %s TOML preset", action, descriptor.name)
	render_worker_publish_preset_result(state, ok, message)
	return true
}
