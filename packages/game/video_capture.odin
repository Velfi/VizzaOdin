package game

import vk "vendor:vulkan"

Video_Capture_Sink :: struct {
	userdata: rawptr,
	is_recording: proc(rawptr) -> bool,
	reserve_frame: proc(rawptr, ^int) -> bool,
	release_frame: proc(rawptr, int),
	submit_frame: proc(rawptr, int, []u8, u32, u32, vk.Format) -> bool,
	fail: proc(rawptr, string),
}

video_capture_is_recording :: proc(sink: ^Video_Capture_Sink) -> bool {
	return sink != nil && sink.is_recording != nil && sink.is_recording(sink.userdata)
}

video_capture_reserve_frame :: proc(sink: ^Video_Capture_Sink, index: ^int) -> bool {
	return sink != nil && sink.reserve_frame != nil && sink.reserve_frame(sink.userdata, index)
}

video_capture_release_frame :: proc(sink: ^Video_Capture_Sink, index: int) {
	if sink != nil && sink.release_frame != nil {
		sink.release_frame(sink.userdata, index)
	}
}

video_capture_submit_frame :: proc(sink: ^Video_Capture_Sink, index: int, pixels: []u8, width, height: u32, format: vk.Format) -> bool {
	return sink != nil && sink.submit_frame != nil && sink.submit_frame(sink.userdata, index, pixels, width, height, format)
}

video_capture_fail :: proc(sink: ^Video_Capture_Sink, text: string) {
	if sink != nil && sink.fail != nil {
		sink.fail(sink.userdata, text)
	}
}
