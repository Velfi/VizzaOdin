package game

import uifw "../ui"

import "core:math"

CAMERA_DEFAULT_SMOOTHING :: f32(0.15)
CAMERA_WHEEL_DELTA_SCALE :: f32(0.1)
CAMERA_KEY_PAN_AMOUNT :: f32(0.1)
CAMERA_KEY_ZOOM_DELTA :: f32(0.05)
CAMERA_MIN_ZOOM :: f32(0.005)
CAMERA_MAX_ZOOM :: f32(50.0)
INFINITE_RENDER_MAX_TILES_PER_AXIS :: u32(1024)

Camera_Control_State :: struct {
	position: [2]f32,
	target_position: [2]f32,
	zoom: f32,
	target_zoom: f32,
	smoothing_factor: f32,
}

camera_controls_init :: proc(camera: ^Camera_Control_State) {
	camera^ = {
		zoom = 1,
		target_zoom = 1,
		smoothing_factor = CAMERA_DEFAULT_SMOOTHING,
	}
}

infinite_render_tile_count :: proc(zoom: f32) -> u32 {
	safe_zoom := max(zoom, CAMERA_MIN_ZOOM)
	visible_world_size := 2.0 / safe_zoom
	tiles_needed := u32(math.ceil(visible_world_size / 2.0)) + 6
	min_tiles := u32(5)
	if safe_zoom < 0.1 {
		min_tiles = 7
	}
	return min(max(tiles_needed, min_tiles), INFINITE_RENDER_MAX_TILES_PER_AXIS)
}

camera_controls_sync :: proc(camera: ^Camera_Control_State) {
	if camera.zoom <= 0 {
		camera.zoom = 1
	}
	if camera.target_zoom <= 0 {
		camera.target_position = camera.position
		camera.target_zoom = camera.zoom
	}
	if camera.smoothing_factor <= 0 {
		camera.smoothing_factor = CAMERA_DEFAULT_SMOOTHING
	}
}

camera_controls_reset :: proc(camera: ^Camera_Control_State) {
	camera.position = {}
	camera.target_position = {}
	camera.zoom = 1
	camera.target_zoom = 1
	if camera.smoothing_factor <= 0 {
		camera.smoothing_factor = CAMERA_DEFAULT_SMOOTHING
	}
}

camera_controls_screen_to_world :: proc(camera: ^Camera_Control_State, mouse_pos: uifw.Vec2, width, height: i32) -> [2]f32 {
	camera_controls_sync(camera)
	w := f32(max(width, 1))
	h := f32(max(height, 1))
	zoom := max(camera.target_zoom, CAMERA_MIN_ZOOM)
	ndc_x := (mouse_pos.x / w) * 2.0 - 1.0
	ndc_y := -((mouse_pos.y / h) * 2.0 - 1.0)
	return {
		camera.target_position[0] + ndc_x / zoom,
		camera.target_position[1] + ndc_y / zoom,
	}
}

camera_controls_zoom_center :: proc(camera: ^Camera_Control_State, delta, sensitivity: f32) {
	camera_controls_sync(camera)
	adjusted_delta := delta * max(min(sensitivity, 5.0), 0.1)
	zoom_factor := 1.0 + adjusted_delta * 0.3
	if zoom_factor <= 0 {
		return
	}
	new_zoom := camera.target_zoom * zoom_factor
	clamped_zoom := max(min(new_zoom, CAMERA_MAX_ZOOM), CAMERA_MIN_ZOOM)
	threshold := max(camera.target_zoom * 0.001, 0.000001)
	if math.abs(clamped_zoom - camera.target_zoom) > threshold {
		camera.target_zoom = clamped_zoom
	}
}

camera_controls_zoom_to_cursor :: proc(camera: ^Camera_Control_State, delta, sensitivity: f32, mouse_pos: uifw.Vec2, width, height: i32) {
	camera_controls_sync(camera)
	old_zoom := camera.target_zoom
	camera_controls_zoom_center(camera, delta, sensitivity)
	if width <= 0 || height <= 0 || camera.target_zoom <= 0 {
		return
	}

	w := f32(max(width, 1))
	h := f32(max(height, 1))
	mouse_x_norm := (mouse_pos.x / w) * 2.0 - 1.0
	mouse_y_norm := -((mouse_pos.y / h) * 2.0 - 1.0)
	world_x := mouse_x_norm / old_zoom + camera.target_position[0]
	world_y := mouse_y_norm / old_zoom + camera.target_position[1]
	new_ndc_x := (world_x - camera.target_position[0]) * camera.target_zoom
	new_ndc_y := (world_y - camera.target_position[1]) * camera.target_zoom
	camera.target_position[0] += (mouse_x_norm - new_ndc_x) / camera.target_zoom
	camera.target_position[1] += (mouse_y_norm - new_ndc_y) / camera.target_zoom
}

camera_controls_pan :: proc(camera: ^Camera_Control_State, delta_x, delta_y, sensitivity: f32) {
	camera_controls_sync(camera)
	pan_speed := 0.1 / max(camera.zoom, CAMERA_MIN_ZOOM)
	camera.target_position[0] += delta_x * max(min(sensitivity, 5.0), 0.1) * pan_speed
	camera.target_position[1] += delta_y * max(min(sensitivity, 5.0), 0.1) * pan_speed
}

camera_controls_pan_screen_delta :: proc(camera: ^Camera_Control_State, mouse_delta: uifw.Vec2, width, height: i32) {
	camera_controls_sync(camera)
	if width <= 0 || height <= 0 || (mouse_delta.x == 0 && mouse_delta.y == 0) {
		return
	}
	w := max(f32(width), 1)
	h := max(f32(height), 1)
	zoom := max(camera.target_zoom, CAMERA_MIN_ZOOM)
	camera.target_position[0] -= (mouse_delta.x / w) * 2.0 / zoom
	camera.target_position[1] += (mouse_delta.y / h) * 2.0 / zoom
}

camera_controls_apply_input :: proc(camera: ^Camera_Control_State, input: Ui_Frame_Input) {
	camera_controls_sync(camera)
	if input.key_c {
		camera_controls_reset(camera)
		return
	}

	sensitivity := input.camera_sensitivity
	if sensitivity <= 0 {
		sensitivity = 1
	}
	if input.wheel_delta != 0 {
		camera_controls_zoom_to_cursor(camera, input.wheel_delta * CAMERA_WHEEL_DELTA_SCALE, sensitivity, input.mouse_pos, input.window_width, input.window_height)
	}
	if input.controller_zoom != 0 {
		camera_controls_zoom_center(camera, input.controller_zoom * CAMERA_KEY_ZOOM_DELTA, sensitivity)
	}
	if input.mouse_down && input.mouse_button == 2 {
		camera_controls_pan_screen_delta(camera, input.mouse_delta, input.window_width, input.window_height)
	}

	pan_units := CAMERA_KEY_PAN_AMOUNT
	if input.key_left || input.key_a {
		camera_controls_pan(camera, -pan_units, 0, sensitivity)
	}
	if input.key_right || input.key_d {
		camera_controls_pan(camera, pan_units, 0, sensitivity)
	}
	if input.key_up || input.key_w {
		camera_controls_pan(camera, 0, pan_units, sensitivity)
	}
	if input.key_down || input.key_s {
		camera_controls_pan(camera, 0, -pan_units, sensitivity)
	}
	if input.controller_left.x != 0 || input.controller_left.y != 0 {
		camera_controls_pan(camera, input.controller_left.x * pan_units, -input.controller_left.y * pan_units, sensitivity)
	}
	if input.key_q {
		camera_controls_zoom_center(camera, -CAMERA_KEY_ZOOM_DELTA, sensitivity)
	}
	if input.key_e {
		camera_controls_zoom_center(camera, CAMERA_KEY_ZOOM_DELTA, sensitivity)
	}

	smoothing := min(camera.smoothing_factor * max(input.delta_time, 0) * 60.0, 1.0)
	camera.position[0] += (camera.target_position[0] - camera.position[0]) * smoothing
	camera.position[1] += (camera.target_position[1] - camera.position[1]) * smoothing
	camera.zoom += (camera.target_zoom - camera.zoom) * smoothing
}
