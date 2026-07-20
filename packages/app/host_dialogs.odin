package app

import engine "zelda_engine:engine"

import "base:runtime"
import "core:c"
import "core:fmt"
import sdl "vendor:sdl3"

app_drain_render_messages :: proc(app: ^App_State) {
	msg: Render_To_Ui_Message
	for engine.queue_try_pop(&app.render_to_ui, &msg) {
		#partial switch msg.kind {
		case .Ready, .Device_Info, .Preset_Result, .Feature_Result, .Error, .Shutdown_Complete:
			if app.mcp_enabled {
				mcp_bridge_publish_render_message(&app.mcp_bridge, msg)
			}
			text := fixed_string(msg.text[:])
			if len(text) > 0 {
				if app.mcp_enabled {
					if msg.kind == .Error {
						engine.log_error(text)
					} else {
						engine.log_info(text)
					}
				} else {
					fmt.println(text)
				}
			}
			if msg.kind == .Feature_Result && msg.feature_result.dialog.kind != .None do app_show_feature_dialog(app, msg.feature_result.dialog)
		case .Request_Video_Save_Dialog:
			engine.log_info("video_recording: received save dialog request on app thread")
			app_show_video_save_dialog(app)
		case .Clipboard_Set:
			text := fixed_string(msg.text[:])
			if len(text) > 0 {
				_ = sdl.SetClipboardText(cstring(raw_data(msg.text[:])))
			}
		case .Request_Close:
			app.running = false
		case .App_Settings_Changed:
			app_apply_settings(app, msg.app_settings)
		case .Frame_Stats:
			app.ui_system_cursor_hidden = msg.system_cursor_hidden &&
				!app_input_reveals_hidden_system_cursor(app.input, app.active_device)
			app_apply_system_cursor_visibility(app)
			if app.mcp_enabled {
				mcp_bridge_publish_render_message(&app.mcp_bridge, msg)
			}
		}
	}
}

app_show_feature_dialog :: proc(app: ^App_State, request: Feature_Platform_Dialog_Request) {
	if app == nil || request.kind != .Open_Image || request.request_id == 0 do return
	target, ok := feature_image_target(request.feature_id, request.slot)
	if !ok do return
	switch target {
	case .Gray_Scott_Nutrient: app_show_nutrient_image_dialog(app, request.request_id)
	case .Vectors: app_show_vectors_image_dialog(app, request.request_id)
	case .Moire: app_show_moire_image_dialog(app, request.request_id)
	case .Flow: app_show_flow_image_dialog(app, request.request_id)
	case .Slime_Mask: app_show_slime_mask_image_dialog(app, request.request_id)
	case .Slime_Position: app_show_slime_position_image_dialog(app, request.request_id)
	}
}

app_write_fixed_string_cstring :: proc(dst: []u8, src: cstring) {
	if src == nil || len(dst) == 0 {
		return
	}
	i := 0
	bytes := cast([^]u8)src
	for i < len(dst) - 1 && bytes[i] != 0 {
		dst[i] = bytes[i]
		i += 1
	}
	dst[i] = 0
}

Feature_Image_Dialog_Context :: struct {
	app: ^App_State,
	request_id: u64,
}

app_enqueue_feature_image_cstring :: proc(app: ^App_State, feature_id: Feature_Id, slot: u16, request_id: u64, path: cstring) {
	if app == nil || path == nil do return
	payload: Feature_Image_Command
	payload.slot = slot
	payload.dialog_request_id = request_id
	app_write_fixed_string_cstring(payload.path[:], path)
	if feature, ok := feature_command_make(feature_id, FEATURE_COMMAND_LOAD_IMAGE, &payload); ok {
		_ = engine.queue_try_push(&app.ui_to_render, Ui_To_Render_Command{kind = .Feature, feature = feature})
	}
}

app_image_dialog_context_make :: proc(app: ^App_State, request_id: u64) -> ^Feature_Image_Dialog_Context {
	ctx := new(Feature_Image_Dialog_Context)
	ctx^ = {app = app, request_id = request_id}
	return ctx
}

app_nutrient_image_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	_ = filter
	if userdata == nil do return
	dialog := cast(^Feature_Image_Dialog_Context)userdata
	defer free(dialog)
	if filelist == nil || filelist[0] == nil do return
	app_enqueue_feature_image_cstring(dialog.app, FEATURE_ID_GRAY_SCOTT, 0, dialog.request_id, filelist[0])
}

app_show_nutrient_image_dialog :: proc(app: ^App_State, request_id: u64) {
	sdl.ShowOpenFileDialog(
		app_nutrient_image_dialog_callback,
		app_image_dialog_context_make(app, request_id),
		app.window,
		raw_data(NUTRIENT_IMAGE_DIALOG_FILTERS[:]),
		c.int(len(NUTRIENT_IMAGE_DIALOG_FILTERS)),
		nil,
		false,
	)
}

app_vectors_image_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	_ = filter
	if userdata == nil do return
	dialog := cast(^Feature_Image_Dialog_Context)userdata
	defer free(dialog)
	if filelist == nil || filelist[0] == nil do return
	app_enqueue_feature_image_cstring(dialog.app, FEATURE_ID_VECTORS, 0, dialog.request_id, filelist[0])
}

app_show_vectors_image_dialog :: proc(app: ^App_State, request_id: u64) {
	sdl.ShowOpenFileDialog(
		app_vectors_image_dialog_callback,
		app_image_dialog_context_make(app, request_id),
		app.window,
		raw_data(NUTRIENT_IMAGE_DIALOG_FILTERS[:]),
		c.int(len(NUTRIENT_IMAGE_DIALOG_FILTERS)),
		nil,
		false,
	)
}

app_moire_image_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	_ = filter
	if userdata == nil do return
	dialog := cast(^Feature_Image_Dialog_Context)userdata
	defer free(dialog)
	if filelist == nil || filelist[0] == nil do return
	app_enqueue_feature_image_cstring(dialog.app, FEATURE_ID_MOIRE, 0, dialog.request_id, filelist[0])
}

app_show_moire_image_dialog :: proc(app: ^App_State, request_id: u64) {
	sdl.ShowOpenFileDialog(
		app_moire_image_dialog_callback,
		app_image_dialog_context_make(app, request_id),
		app.window,
		raw_data(NUTRIENT_IMAGE_DIALOG_FILTERS[:]),
		c.int(len(NUTRIENT_IMAGE_DIALOG_FILTERS)),
		nil,
		false,
	)
}

app_flow_image_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	_ = filter
	if userdata == nil do return
	dialog := cast(^Feature_Image_Dialog_Context)userdata
	defer free(dialog)
	if filelist == nil || filelist[0] == nil do return
	app_enqueue_feature_image_cstring(dialog.app, FEATURE_ID_FLOW_FIELD, 0, dialog.request_id, filelist[0])
}

app_show_flow_image_dialog :: proc(app: ^App_State, request_id: u64) {
	sdl.ShowOpenFileDialog(
		app_flow_image_dialog_callback,
		app_image_dialog_context_make(app, request_id),
		app.window,
		raw_data(NUTRIENT_IMAGE_DIALOG_FILTERS[:]),
		c.int(len(NUTRIENT_IMAGE_DIALOG_FILTERS)),
		nil,
		false,
	)
}

app_slime_mask_image_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	_ = filter
	if userdata == nil do return
	dialog := cast(^Feature_Image_Dialog_Context)userdata
	defer free(dialog)
	if filelist == nil || filelist[0] == nil do return
	app_enqueue_feature_image_cstring(dialog.app, FEATURE_ID_SLIME_MOLD, 0, dialog.request_id, filelist[0])
}

app_show_slime_mask_image_dialog :: proc(app: ^App_State, request_id: u64) {
	sdl.ShowOpenFileDialog(
		app_slime_mask_image_dialog_callback,
		app_image_dialog_context_make(app, request_id),
		app.window,
		raw_data(NUTRIENT_IMAGE_DIALOG_FILTERS[:]),
		c.int(len(NUTRIENT_IMAGE_DIALOG_FILTERS)),
		nil,
		false,
	)
}

app_slime_position_image_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	_ = filter
	if userdata == nil do return
	dialog := cast(^Feature_Image_Dialog_Context)userdata
	defer free(dialog)
	if filelist == nil || filelist[0] == nil do return
	app_enqueue_feature_image_cstring(dialog.app, FEATURE_ID_SLIME_MOLD, 1, dialog.request_id, filelist[0])
}

app_show_slime_position_image_dialog :: proc(app: ^App_State, request_id: u64) {
	sdl.ShowOpenFileDialog(
		app_slime_position_image_dialog_callback,
		app_image_dialog_context_make(app, request_id),
		app.window,
		raw_data(NUTRIENT_IMAGE_DIALOG_FILTERS[:]),
		c.int(len(NUTRIENT_IMAGE_DIALOG_FILTERS)),
		nil,
		false,
	)
}

app_video_recording_is_fullscreen :: proc(app: ^App_State) -> bool {
	if app == nil || app.window == nil {
		return false
	}
	flags := sdl.GetWindowFlags(app.window)
	return .FULLSCREEN in flags
}

app_video_recording_send_start :: proc(app: ^App_State, path: string) {
	if len(path) == 0 {
		return
	}
	cmd: Ui_To_Render_Command
	cmd.kind = .Start_Video_Recording
	write_fixed_string(cmd.file_path[:], path)
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
	app.video_recording_pending_start = false
	app.video_recording_restore_fullscreen = false
	app.video_recording_restore_attempts = 0
	write_fixed_string(app.video_recording_pending_path[:], "")
}

app_video_recording_send_cancel :: proc(app: ^App_State) {
	cmd: Ui_To_Render_Command
	cmd.kind = .Cancel_Video_Recording
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
}

app_video_recording_send_error :: proc(app: ^App_State, text: string) {
	cmd: Ui_To_Render_Command
	cmd.kind = .Video_Recording_Error
	write_fixed_string(cmd.file_path[:], text)
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
}

app_video_recording_send_restoring :: proc(app: ^App_State) {
	cmd: Ui_To_Render_Command
	cmd.kind = .Video_Recording_Restoring_Fullscreen
	_ = engine.queue_try_push(&app.ui_to_render, cmd)
}

app_video_recording_clear_pending_start :: proc(app: ^App_State) {
	app.video_recording_pending_start = false
	app.video_recording_restore_fullscreen = false
	app.video_recording_restore_attempts = 0
	write_fixed_string(app.video_recording_pending_path[:], "")
}

app_video_recording_begin_fullscreen_preservation :: proc(app: ^App_State) {
	if app == nil || app.window == nil || app_video_recording_is_fullscreen(app) {
		app.video_recording_preserve_fullscreen = false
		app.video_recording_preserve_fullscreen_attempts = 0
		return
	}
	app.video_recording_preserve_fullscreen = true
	app.video_recording_preserve_fullscreen_attempts = 0
	_ = sdl.SetWindowFullscreen(app.window, true)
}

app_video_recording_process_fullscreen_preservation :: proc(app: ^App_State) {
	if !app.video_recording_preserve_fullscreen {
		return
	}
	if app_video_recording_is_fullscreen(app) {
		app.video_recording_preserve_fullscreen = false
		app.video_recording_preserve_fullscreen_attempts = 0
		return
	}
	app.video_recording_preserve_fullscreen_attempts += 1
	if app.video_recording_preserve_fullscreen_attempts == 1 || (app.video_recording_preserve_fullscreen_attempts % 30) == 0 {
		_ = sdl.SetWindowFullscreen(app.window, true)
	}
	if app.video_recording_preserve_fullscreen_attempts >= VIDEO_RECORDING_FULLSCREEN_RESTORE_MAX_FRAMES {
		app.video_recording_preserve_fullscreen = false
		app.video_recording_preserve_fullscreen_attempts = 0
		engine.log_error("Could not restore fullscreen after video recording dialog")
	}
}

app_video_recording_process_pending_start :: proc(app: ^App_State) {
	if !app.video_recording_pending_start {
		return
	}
	path := fixed_string(app.video_recording_pending_path[:])
	if len(path) == 0 {
		app_video_recording_clear_pending_start(app)
		app_video_recording_send_cancel(app)
		return
	}
	if app.video_recording_restore_fullscreen {
		if app_video_recording_is_fullscreen(app) {
			app_video_recording_send_start(app, path)
			return
		}
		app.video_recording_restore_attempts += 1
		if app.video_recording_restore_attempts == 1 || (app.video_recording_restore_attempts % 30) == 0 {
			_ = sdl.SetWindowFullscreen(app.window, true)
		}
		if app.video_recording_restore_attempts >= VIDEO_RECORDING_FULLSCREEN_RESTORE_MAX_FRAMES {
			app_video_recording_clear_pending_start(app)
			app_video_recording_send_error(app, "Could not restore fullscreen; recording was not started")
		}
		return
	}
	app_video_recording_send_start(app, path)
}

app_video_recording_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	_ = filter
	if userdata == nil {
		return
	}
	app := cast(^App_State)userdata
	was_fullscreen := app.video_recording_restore_fullscreen
	if filelist == nil || filelist[0] == nil {
		err := sdl.GetError()
		if err != nil && len(string(err)) > 0 {
			engine.log_error("video_recording: save dialog failed or was canceled: ", err)
		} else {
			engine.log_info("video_recording: save dialog canceled")
		}
		app_video_recording_clear_pending_start(app)
		if was_fullscreen {
			app_video_recording_begin_fullscreen_preservation(app)
		}
		app_video_recording_send_cancel(app)
		return
	}
	app_write_fixed_string_cstring(app.video_recording_pending_path[:], filelist[0])
	path := fixed_string(app.video_recording_pending_path[:])
	engine.log_info("video_recording: save path selected: ", path)
	if was_fullscreen {
		if app_video_recording_is_fullscreen(app) {
			app_video_recording_send_start(app, path)
		} else if sdl.SetWindowFullscreen(app.window, true) {
			app.video_recording_pending_start = true
			app.video_recording_restore_fullscreen = true
			app.video_recording_restore_attempts = 0
			app_video_recording_send_restoring(app)
		} else {
			app_video_recording_clear_pending_start(app)
			app_video_recording_begin_fullscreen_preservation(app)
			app_video_recording_send_error(app, "Could not restore fullscreen; recording was not started")
		}
	} else {
		app_video_recording_send_start(app, path)
	}
}

app_show_video_save_dialog :: proc(app: ^App_State) {
	app.video_recording_pending_start = false
	app.video_recording_restore_fullscreen = app_video_recording_is_fullscreen(app)
	app.video_recording_restore_attempts = 0
	app.video_recording_preserve_fullscreen = false
	app.video_recording_preserve_fullscreen_attempts = 0
	write_fixed_string(app.video_recording_pending_path[:], "")
	engine.log_info("video_recording: opening save dialog fullscreen=", app.video_recording_restore_fullscreen)
	sdl.ShowSaveFileDialog(
		app_video_recording_dialog_callback,
		app,
		app.window,
		raw_data(VIDEO_FILE_DIALOG_FILTERS[:]),
		c.int(len(VIDEO_FILE_DIALOG_FILTERS)),
		nil,
	)
}
