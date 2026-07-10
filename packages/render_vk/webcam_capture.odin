package render_vk

import engine "../engine"
import sdl "vendor:sdl3"

simulation_leave_cleanup :: proc(app_ui: ^App_Ui_State, gray_scott: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation, mode: App_Mode) {
	state: ^Remaining_Sim_State
	if app_ui != nil {
		#partial switch mode {
		case .Vectors: state = &app_ui.vectors
		case .Moire: state = &app_ui.moire
		case .Flow_Field: state = &app_ui.flow_field
		case .Slime_Mold: state = &app_ui.slime_mold
		case .Pellets: state = &app_ui.pellets
		case .Voronoi_CA: state = &app_ui.voronoi_ca
		case .Primordial: state = &app_ui.primordial
		case:
		}
	}
	app_ui_simulation_set_paused(mode, gray_scott, particle_life, state, true)
	if mode == .Gray_Scott {
		if gray_scott != nil {gray_scott_stop_webcam(gray_scott)}
		return
	}
	if state != nil && state.webcam_capture != nil {
		sdl.CloseCamera(state.webcam_capture)
		state.webcam_capture = nil
		write_fixed_string(state.webcam_capture_status[:], "Webcam stopped")
	}
}

// Shared latest-frame capture/transform path for every image consumer. SDL
// retains native camera format negotiation; this converts exactly once and
// drops stale frames naturally because AcquireCameraFrame only yields the
// newest frame available to the render thread.
webcam_capture_rgba_frame :: proc(camera: ^sdl.Camera) -> ^sdl.Surface {
	if camera == nil || sdl.GetCameraPermissionState(camera) != .APPROVED {return nil}
	timestamp: sdl.Uint64
	frame := sdl.AcquireCameraFrame(camera, &timestamp)
	if frame == nil {return nil}
	converted := sdl.ConvertSurface(frame, .RGBA32)
	sdl.ReleaseCameraFrame(camera, frame)
	return converted
}

webcam_frame_gray :: proc(frame: ^sdl.Surface, target_width, target_height, x, y: int, fit: Vector_Image_Fit_Mode, mirror_h, mirror_v, invert: bool) -> u8 {
	dx := mirror_h ? target_width - 1 - x : x
	dy := mirror_v ? target_height - 1 - y : y
	sx, sy: int
	value := u8(0)
	if vectors_image_source_coord(int(frame.w), int(frame.h), target_width, target_height, dx, dy, fit, &sx, &sy) {
		value = vectors_sample_image_source(cast([^]u8)frame.pixels, int(frame.w), int(frame.h), int(frame.pitch), sx, sy)
	}
	return invert ? 255 - value : value
}

webcam_frame_rgba :: proc(frame: ^sdl.Surface, width, height: int, fit: Vector_Image_Fit_Mode, mirror_h, mirror_v, invert: bool) -> []u8 {
	pixels := make([]u8, width * height * 4, context.temp_allocator)
	for y in 0..<height {for x in 0..<width {
		v := webcam_frame_gray(frame, width, height, x, y, fit, mirror_h, mirror_v, invert)
		i := (y * width + x) * 4
		pixels[i + 0], pixels[i + 1], pixels[i + 2], pixels[i + 3] = v, v, v, 255
	}}
	return pixels
}

webcam_update_vectors :: proc(gpu: ^Vectors_Gpu_State, frame: ^sdl.Surface, settings: ^Vectors_Settings) -> bool {
	if len(gpu.image_data) != VECTORS_IMAGE_RESOLUTION * VECTORS_IMAGE_RESOLUTION {
		delete(gpu.image_data); gpu.image_data = make([]u8, VECTORS_IMAGE_RESOLUTION * VECTORS_IMAGE_RESOLUTION)
	}
	for y in 0..<VECTORS_IMAGE_RESOLUTION {for x in 0..<VECTORS_IMAGE_RESOLUTION {
		gpu.image_data[y * VECTORS_IMAGE_RESOLUTION + x] = webcam_frame_gray(frame, VECTORS_IMAGE_RESOLUTION, VECTORS_IMAGE_RESOLUTION, x, y, settings.image_fit_mode, settings.image_mirror_horizontal, settings.image_mirror_vertical, settings.image_invert_tone)
	}}
	gpu.image_loaded = true
	return true
}

webcam_update_slime :: proc(gpu: ^Slime_Gpu_State, frame: ^sdl.Surface, settings: ^Slime_Settings, position: bool) -> bool {
	if gpu.mask_buffer.mapped == nil {return false}
	w, h := int(gpu.width), int(gpu.height)
	fit := position ? settings.position_image_fit_mode : settings.mask_image_fit_mode
	values := (cast([^]f32)gpu.mask_buffer.mapped)[:w * h]
	for y in 0..<h {for x in 0..<w {
		values[y * w + x] = f32(webcam_frame_gray(frame, w, h, x, y, fit, settings.mask_mirror_horizontal, settings.mask_mirror_vertical, settings.mask_invert_tone)) / 255
	}}
	if position {gpu.needs_reset = true}
	return true
}

webcam_update_flow :: proc(gpu: ^Flow_Gpu_State, ctx: ^engine.Vk_Context, frame: ^sdl.Surface, settings: ^Flow_Settings) -> bool {
	if !gpu.ready {return false}
	w, h := int(max(gpu.trail_width, 1)), int(max(gpu.trail_height, 1))
	pixels := webcam_frame_rgba(frame, w, h, settings.image_fit_mode, settings.image_mirror_horizontal, settings.image_mirror_vertical, settings.image_invert_tone)
	new_image: Flow_Image
	if !flow_create_image(gpu, ctx, &new_image, u32(w), u32(h), {.SAMPLED, .TRANSFER_DST}) || !flow_upload_sampled_image(ctx, &new_image, u32(w), u32(h), pixels) {return false}
	if !flow_retire_vector_field_image(gpu) {flow_destroy_image(ctx, &new_image); return false}
	gpu.vector_field_image = new_image; gpu.vector_field_image_loaded = true
	return true
}

webcam_update_moire :: proc(gpu: ^Moire_Gpu_State, ctx: ^engine.Vk_Context, frame: ^sdl.Surface, settings: ^Moire_Settings) -> bool {
	if !gpu.ready {return false}
	w, h := int(max(gpu.width, 1)), int(max(gpu.height, 1))
	pixels := webcam_frame_rgba(frame, w, h, settings.image_fit_mode, settings.image_mirror_horizontal, settings.image_mirror_vertical, settings.image_invert_tone)
	new_image: Moire_Image
	if !moire_create_sampled_image(ctx, &new_image, u32(w), u32(h)) || !moire_upload_sampled_image(ctx, &new_image, u32(w), u32(h), pixels) {return false}
	if !moire_retire_image_texture(gpu) {moire_destroy_image(ctx, &new_image); return false}
	gpu.image_texture = new_image; gpu.image_loaded = true; gpu.image_width = i32(w); gpu.image_height = i32(h)
	return true
}

webcam_update_remaining :: proc(state: ^Remaining_Sim_State, mode: App_Mode, ctx: ^engine.Vk_Context, vectors: ^Vectors_Gpu_State, moire: ^Moire_Gpu_State, flow: ^Flow_Gpu_State, slime: ^Slime_Gpu_State) {
	if state == nil || state.webcam_capture == nil {return}
	frame := webcam_capture_rgba_frame(state.webcam_capture)
	if frame == nil {return}
	defer sdl.DestroySurface(frame)
	ok := false
	#partial switch mode {
	case .Vectors: ok = webcam_update_vectors(vectors, frame, &state.vectors)
	case .Moire: ok = webcam_update_moire(moire, ctx, frame, &state.moire)
	case .Flow_Field: ok = webcam_update_flow(flow, ctx, frame, &state.flow)
	case .Slime_Mold:
		position := state.webcam_capture_command == .Load_Slime_Position_Image
		ok = webcam_update_slime(slime, frame, &state.slime, position)
	case:
	}
	if ok {state.webcam_capture_frames += 1; write_fixed_string(state.webcam_capture_status[:], "Webcam live")}
}
