package game

import uifw "zelda_engine:ui"
import engine "zelda_engine:engine"

MAX_PRESET_NAME :: 64
MAX_ERROR_TEXT :: 512
MAX_FILE_PATH :: 512

Ui_Frame_Input :: struct {
	actions: Input_Action_Frame,
	frame_index: u64,
	window_width: i32,
	window_height: i32,
	mouse_pos: uifw.Vec2,
	mouse_down: bool,
	mouse_pressed: bool,
	mouse_released: bool,
	mouse_moved: bool,
	mouse_delta: uifw.Vec2,
	mouse_button: u32,
	camera_pan_down: bool,
	wheel_delta_x: f32,
	wheel_delta: f32,
	delta_time: f32,
	camera_sensitivity: f32,
	controller_camera_sensitivity: f32,
	controller_camera_invert_y: bool,
	active_device: uifw.Input_Device_Kind,
	controller_prompt_style: uifw.Controller_Prompt_Style,
	pointer_enabled: bool,
	virtual_cursor_pos: uifw.Vec2,
	controller_connected: bool,
	controller_disconnected: bool,
	canvas_tool_slot: u32,
	controller_left: uifw.Vec2,
	controller_zoom: f32,
	text_input: [32]u8,
	text_input_len: int,
	clipboard_paste: [256]u8,
	clipboard_paste_len: int,
	key_tab: bool,
	key_shift: bool,
	key_ctrl: bool,
	key_super: bool,
	key_enter: bool,
	key_escape: bool,
	key_escape_down: bool,
	controller_start_down: bool,
	key_backspace: bool,
	key_delete: bool,
	key_home: bool,
	key_end: bool,
	key_left: bool,
	key_right: bool,
	key_up: bool,
	key_down: bool,
	key_w: bool,
	key_a: bool,
	key_s: bool,
	key_d: bool,
	key_q: bool,
	key_e: bool,
	key_x: bool,
	key_v: bool,
	key_space: bool,
	key_space_down: bool,
	camera_pan_modifier_down: bool,
	key_space_pressed: bool,
	key_space_released: bool,
}

Ui_To_Render_Command_Kind :: enum {
	Frame_Input,
	Feature,
	Resize,
	Close,
	Set_App_Mode,
	Set_Ui_Component_Fixture,
	Hide_Ui,
	Debug_Reload_Ui_Document,
	Start_Video_Recording,
	Stop_Video_Recording,
	Cancel_Video_Recording,
	Video_Recording_Restoring_Fullscreen,
	Video_Recording_Error,
}

Ui_To_Render_Command :: struct {
	kind: Ui_To_Render_Command_Kind,
	feature: Feature_Command,
	frame_input: Ui_Frame_Input,
	width: i32,
	height: i32,
	file_path: [MAX_FILE_PATH]u8,
	document_id: [uifw.UI_DOCUMENT_ID_CAPACITY]u8,
	app_mode: App_Mode,
	component_fixture: Ui_Component_Fixture,
	component_fixture_state: Ui_Component_Fixture_State,
	component_fixture_value: f32,
}

Render_To_Ui_Message_Kind :: enum {
	Ready,
	Feature_Result,
	Frame_Stats,
	App_Settings_Changed,
	Device_Info,
	Preset_Result,
	Error,
	Request_Close,
	Request_Video_Save_Dialog,
	Clipboard_Set,
	Shutdown_Complete,
}

Render_To_Ui_Message :: struct {
	kind: Render_To_Ui_Message_Kind,
	feature_result: Feature_Result,
	frame_index: u64,
	fps: f32,
	frame_ms: f32,
	app_mode: App_Mode,
	gray_scott_camera_x: f32,
	gray_scott_camera_y: f32,
	gray_scott_camera_zoom: f32,
	gray_scott_controls_visible: bool,
	system_cursor_hidden: bool,
	gray_scott_paused: bool,
	particle_life_camera_x: f32,
	particle_life_camera_y: f32,
	particle_life_camera_zoom: f32,
	particle_life_ready: bool,
	particle_life_paused: bool,
	particle_life_controls_visible: bool,
	particle_life_frame_index: u64,
	particle_life_particle_count: u32,
	particle_life_species_count: u32,
	particle_life_requested_particle_count: u32,
	particle_life_requested_species_count: u32,
	particle_life_trails_enabled: bool,
	particle_life_infinite_tiles_enabled: bool,
	gpu_profiling_supported: bool,
	gpu_profiling_enabled: bool,
	gpu_simulation_step_ms: f32,
	gpu_simulation_present_ms: f32,
	gpu_ui_overlay_ms: f32,
	gpu_frame_total_ms: f32,
	gpu_pellets_grid_clear_ms: f32,
	gpu_pellets_grid_build_ms: f32,
	gpu_pellets_grid_scatter_ms: f32,
	gpu_pellets_physics_ms: f32,
	gpu_pellets_density_ms: f32,
	gpu_pellets_particle_draw_ms: f32,
	sim_ms: f32,
	ui_ms: f32,
	render_ms: f32,
	submit_ms: f32,
	screenshot_ms: f32,
	screenshot_captured: bool,
	ui_build_ms: f32,
	ui_overlay_ms: f32,
	gui_command_count: u32,
	ui_vertex_count: u32,
	ui_batch_count: u32,
	ui_clear_rect_count: u32,
	main_menu_preview_visible_slot_count: u32,
	main_menu_preview_warmed_mode_count: u32,
	main_menu_preview_fallback_fill_count: u32,
	main_menu_preview_skipped_present_count: u32,
	text_width_calls: u64,
	text_width_cache_hits: u64,
	text_width_ms: f32,
	text_shape_calls: u64,
	text_shape_glyphs: u64,
	text_shape_ms: f32,
	text_wrap_calls: u64,
	text_wrap_ms: f32,
	cpu_wait_fence_ms: f32,
	cpu_acquire_ms: f32,
	cpu_command_begin_ms: f32,
	cpu_end_command_ms: f32,
	cpu_queue_submit_ms: f32,
	cpu_queue_present_ms: f32,
	present_mode: [32]u8,
	command_render_pass_count: u32,
	command_compute_dispatch_count: u32,
	command_draw_count: u32,
	command_pipeline_bind_count: u32,
	command_descriptor_bind_count: u32,
	command_pipeline_barrier_count: u32,
	command_transfer_copy_count: u32,
	command_ui_batch_count: u32,
	command_backdrop_blur_pass_count: u32,
	device_info: engine.Vk_Device_Caps,
	app_settings: App_Settings,
	preset_ok: bool,
	text: [MAX_ERROR_TEXT]u8,
}

Ui_To_Render_Queue :: engine.Bounded_Queue(Ui_To_Render_Command, 256)
Render_To_Ui_Queue :: engine.Bounded_Queue(Render_To_Ui_Message, 256)

write_fixed_string :: proc(dst: []u8, src: string) {
	n := min(len(dst) - 1, len(src))
	for i in 0 ..< n {
		dst[i] = src[i]
	}
	if len(dst) > 0 {
		dst[n] = 0
	}
}

fixed_string :: proc(buf: []u8) -> string {
	n := 0
	for n < len(buf) && buf[n] != 0 {
		n += 1
	}
	return string(buf[:n])
}
