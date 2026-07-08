package game

import engine "../engine"

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sync"
import vk "vendor:vulkan"
import sdl "vendor:sdl3"

VIDEO_RECORDER_DEFAULT_FPS :: u32(60)
VIDEO_RECORDER_MAX_PATH :: MAX_FILE_PATH
VIDEO_RECORDER_MAX_ERROR :: MAX_ERROR_TEXT
VIDEO_RECORDER_WRITE_RETRY_DELAY_MS :: u32(1)
VIDEO_RECORDER_WRITE_NOT_READY_MAX_RETRIES :: u32(5000)
VIDEO_RECORDER_FRAME_POOL_COUNT :: 3

Video_Recorder_Status :: enum {
	Idle,
	Recording,
	Failed,
}

Video_Recorder_Frame :: struct {
	index: int,
	size: int,
}

Video_Recorder_Free_Queue :: engine.Bounded_Queue(int, VIDEO_RECORDER_FRAME_POOL_COUNT)
Video_Recorder_Filled_Queue :: engine.Bounded_Queue(Video_Recorder_Frame, VIDEO_RECORDER_FRAME_POOL_COUNT)

Video_Recorder_State :: struct {
	status: Video_Recorder_Status,
	process: ^sdl.Process,
	input: ^sdl.IOStream,
	writer_thread: ^sdl.Thread,
	free_queue: Video_Recorder_Free_Queue,
	filled_queue: Video_Recorder_Filled_Queue,
	frames: [VIDEO_RECORDER_FRAME_POOL_COUNT][]u8,
	state_mutex: sync.Mutex,
	width: u32,
	height: u32,
	fps: u32,
	frame_size: int,
	frame_count: u64,
	dropped_frame_count: u64,
	output_path: [VIDEO_RECORDER_MAX_PATH]u8,
	last_error: [VIDEO_RECORDER_MAX_ERROR]u8,
}

Video_Recorder_Start_Config :: struct {
	output_path: string,
	fps: u32,
}

video_recorder_is_recording :: proc(rec: ^Video_Recorder_State) -> bool {
	return rec != nil && rec.status == .Recording
}

video_recorder_start :: proc(rec: ^Video_Recorder_State, width, height: u32, format: vk.Format, config: Video_Recorder_Start_Config) -> bool {
	if rec == nil {
		return false
	}
	if video_recorder_is_recording(rec) {
		video_recorder_stop(rec)
	}
	rec^ = {}

	when ODIN_OS == .Windows {
		engine.log_error("video recording is not implemented on Windows yet")
		assert(false, "video recording is not implemented on Windows yet")
		return false
	} else {
		if len(config.output_path) == 0 {
			video_recorder_fail(rec, "No output path selected")
			return false
		}
		if width == 0 || height == 0 {
			video_recorder_fail(rec, "Cannot record a zero-sized frame")
			return false
		}

		fps := config.fps
		if fps == 0 {
			fps = VIDEO_RECORDER_DEFAULT_FPS
		}
		ffmpeg := video_recorder_find_ffmpeg()
		if len(ffmpeg) == 0 {
			video_recorder_fail(rec, "ffmpeg was not found on PATH")
			return false
		}

		size_arg := fmt.tprintf("%dx%d", width, height)
		fps_arg := fmt.tprintf("%d", fps)
		pix_fmt := video_recorder_pixel_format_name(format)

		ffmpeg_c, e0 := strings.clone_to_cstring(ffmpeg, context.temp_allocator)
		size_c, e1 := strings.clone_to_cstring(size_arg, context.temp_allocator)
		fps_c, e2 := strings.clone_to_cstring(fps_arg, context.temp_allocator)
		pix_fmt_c, e3 := strings.clone_to_cstring(pix_fmt, context.temp_allocator)
		output_c, e4 := strings.clone_to_cstring(config.output_path, context.temp_allocator)
		if e0 != nil || e1 != nil || e2 != nil || e3 != nil || e4 != nil {
			video_recorder_fail(rec, "Failed to allocate ffmpeg arguments")
			return false
		}

		args := [?]cstring {
			ffmpeg_c,
			cstring("-y"),
			cstring("-loglevel"),
			cstring("error"),
			cstring("-nostats"),
			cstring("-f"),
			cstring("rawvideo"),
			cstring("-pix_fmt"),
			pix_fmt_c,
			cstring("-s"),
			size_c,
			cstring("-framerate"),
			fps_c,
			cstring("-i"),
			cstring("-"),
			cstring("-vf"),
			cstring("scale=trunc(iw/2)*2:trunc(ih/2)*2"),
			cstring("-c:v"),
			cstring("libx264"),
			cstring("-preset"),
			cstring("veryfast"),
			cstring("-crf"),
			cstring("18"),
			cstring("-pix_fmt"),
			cstring("yuv420p"),
			output_c,
			nil,
		}

		process := sdl.CreateProcess(raw_data(args[:]), true)
		if process == nil {
			video_recorder_fail(rec, fmt.tprintf("Failed to start ffmpeg: %s", sdl.GetError()))
			return false
		}
		input := sdl.GetProcessInput(process)
		if input == nil {
			sdl.DestroyProcess(process)
			video_recorder_fail(rec, "Failed to open ffmpeg stdin")
			return false
		}

		frame_size := int(width * height * 4)
		for i in 0 ..< VIDEO_RECORDER_FRAME_POOL_COUNT {
			buffer, alloc_err := make([]u8, frame_size)
			if alloc_err != nil {
				_ = sdl.CloseIO(input)
				sdl.DestroyProcess(process)
				video_recorder_destroy_frame_pool(rec)
				video_recorder_fail(rec, "Failed to allocate video recording frame buffers")
				return false
			}
			rec.frames[i] = buffer
			_ = engine.queue_try_push(&rec.free_queue, i)
		}

		rec.status = .Recording
		rec.process = process
		rec.input = input
		rec.width = width
		rec.height = height
		rec.fps = fps
		rec.frame_size = frame_size
		write_fixed_string(rec.output_path[:], config.output_path)
		rec.writer_thread = sdl.CreateThread(video_recorder_writer_entry, "vizza-video", rec)
		if rec.writer_thread == nil {
			video_recorder_fail(rec, fmt.tprintf("Failed to start video writer thread: %s", sdl.GetError()))
			return false
		}
		engine.log_info("video_recorder: started path=", config.output_path, " size=", width, "x", height, " fps=", fps, " pix_fmt=", pix_fmt)
		return true
	}
}

video_recorder_stop :: proc(rec: ^Video_Recorder_State) -> bool {
	if rec == nil || rec.status == .Idle {
		return false
	}
	path := fixed_string(rec.output_path[:])
	was_failed := rec.status == .Failed
	process := rec.process
	input := rec.input
	thread := rec.writer_thread
	engine.queue_close(&rec.filled_queue)
	if thread != nil {
		status: c.int
		sdl.WaitThread(thread, &status)
		rec.writer_thread = nil
	}
	was_failed = was_failed || rec.status == .Failed
	rec.process = nil
	rec.input = nil
	rec.writer_thread = nil
	rec.status = .Idle
	if input != nil {
		_ = sdl.CloseIO(input)
	}
	if process != nil {
		exitcode: c.int
		_ = sdl.WaitProcess(process, true, &exitcode)
		sdl.DestroyProcess(process)
		if exitcode != 0 {
			video_recorder_destroy_frame_pool(rec)
			if !was_failed {
				video_recorder_fail(rec, fmt.tprintf("ffmpeg exited with code %d", exitcode))
			}
			return false
		}
	}
	dropped := rec.dropped_frame_count
	video_recorder_destroy_frame_pool(rec)
	engine.log_info("video_recorder: stopped path=", path, " frames=", rec.frame_count, " dropped=", dropped)
	write_fixed_string(rec.output_path[:], path)
	return !was_failed
}

video_recorder_write_frame :: proc(rec: ^Video_Recorder_State, pixels: []u8, width, height: u32, format: vk.Format) -> bool {
	index: int
	if !video_recorder_reserve_frame(rec, &index) {
		return true
	}
	return video_recorder_submit_reserved_frame(rec, index, pixels, width, height, format)
}

video_recorder_reserve_frame :: proc(rec: ^Video_Recorder_State, index: ^int) -> bool {
	if rec == nil || rec.status != .Recording {
		return false
	}
	if !engine.queue_try_pop(&rec.free_queue, index) {
		rec.dropped_frame_count += 1
		if rec.dropped_frame_count == 1 || (rec.dropped_frame_count % 120) == 0 {
			engine.log_warn("video_recorder: dropping frame because ffmpeg is behind dropped=", rec.dropped_frame_count)
		}
		return false
	}
	return true
}

video_recorder_release_frame :: proc(rec: ^Video_Recorder_State, index: int) {
	if rec == nil || index < 0 || index >= VIDEO_RECORDER_FRAME_POOL_COUNT {
		return
	}
	_ = engine.queue_try_push(&rec.free_queue, index)
}

video_recorder_submit_reserved_frame :: proc(rec: ^Video_Recorder_State, index: int, pixels: []u8, width, height: u32, format: vk.Format) -> bool {
	if rec == nil || rec.status != .Recording {
		video_recorder_release_frame(rec, index)
		return false
	}
	if index < 0 || index >= VIDEO_RECORDER_FRAME_POOL_COUNT {
		video_recorder_fail(rec, "Recording stopped because an invalid frame buffer was reserved")
		return false
	}
	if width != rec.width || height != rec.height {
		video_recorder_release_frame(rec, index)
		video_recorder_fail(rec, "Recording stopped because the frame size changed")
		return false
	}
	_ = format
	needed := int(width * height * 4)
	if len(pixels) < needed {
		video_recorder_release_frame(rec, index)
		video_recorder_fail(rec, "Recording stopped because the frame readback was incomplete")
		return false
	}
	copy(rec.frames[index][:needed], pixels[:needed])
	frame := Video_Recorder_Frame{index = index, size = needed}
	if !engine.queue_try_push(&rec.filled_queue, frame) {
		video_recorder_release_frame(rec, index)
		video_recorder_fail(rec, "Recording stopped because the writer queue closed")
		return false
	}
	rec.frame_count += 1
	return true
}

video_recorder_writer_entry :: proc "c" (data: rawptr) -> c.int {
	context = runtime.default_context()
	if data == nil {
		return 1
	}
	rec := cast(^Video_Recorder_State)data
	frame: Video_Recorder_Frame
	for engine.queue_pop_blocking(&rec.filled_queue, &frame) {
		if frame.index < 0 || frame.index >= VIDEO_RECORDER_FRAME_POOL_COUNT || frame.size <= 0 {
			video_recorder_mark_failure(rec, "Recording stopped because the writer received an invalid frame")
			break
		}
		ok, err := video_recorder_write_frame_to_ffmpeg(rec, rec.frames[frame.index][:frame.size])
		_ = engine.queue_try_push(&rec.free_queue, frame.index)
		if !ok {
			video_recorder_mark_failure(rec, err)
			break
		}
	}
	return 0
}

video_recorder_write_frame_to_ffmpeg :: proc(rec: ^Video_Recorder_State, pixels: []u8) -> (bool, string) {
	if rec == nil || rec.input == nil {
		return false, "Recording stopped because ffmpeg stdin was closed"
	}
	written_total := uint(0)
	needed := uint(len(pixels))
	not_ready_retries := u32(0)
	for written_total < needed {
		ptr := rawptr(uintptr(raw_data(pixels)) + uintptr(written_total))
		written := sdl.WriteIO(rec.input, ptr, needed - written_total)
		if written == 0 {
			status := sdl.GetIOStatus(rec.input)
			if status == .NOT_READY || status == .READY {
				not_ready_retries += 1
				if not_ready_retries < VIDEO_RECORDER_WRITE_NOT_READY_MAX_RETRIES {
					sdl.Delay(VIDEO_RECORDER_WRITE_RETRY_DELAY_MS)
					continue
				}
				return false, "Recording stopped because ffmpeg stdin stayed blocked"
			}
			return false, fmt.tprintf("Recording stopped because ffmpeg stopped accepting frames (io_status=%v)", status)
		}
		not_ready_retries = 0
		written_total += written
	}
	return true, ""
}

video_recorder_mark_failure :: proc(rec: ^Video_Recorder_State, text: string) {
	if rec == nil {
		return
	}
	sync.mutex_lock(&rec.state_mutex)
	if rec.status == .Recording {
		rec.status = .Failed
		write_fixed_string(rec.last_error[:], text)
		engine.queue_close(&rec.filled_queue)
		engine.log_error("video_recorder: ", text)
	}
	sync.mutex_unlock(&rec.state_mutex)
}

video_recorder_destroy_frame_pool :: proc(rec: ^Video_Recorder_State) {
	if rec == nil {
		return
	}
	for i in 0 ..< VIDEO_RECORDER_FRAME_POOL_COUNT {
		if rec.frames[i] != nil {
			delete(rec.frames[i])
			rec.frames[i] = nil
		}
	}
}

video_recorder_fail :: proc(rec: ^Video_Recorder_State, text: string) {
	if rec == nil {
		return
	}
	engine.queue_close(&rec.filled_queue)
	if rec.writer_thread != nil {
		status: c.int
		sdl.WaitThread(rec.writer_thread, &status)
		rec.writer_thread = nil
	}
	if rec.input != nil {
		_ = sdl.CloseIO(rec.input)
		rec.input = nil
	}
	if rec.process != nil {
		exitcode: c.int
		_ = sdl.WaitProcess(rec.process, true, &exitcode)
		sdl.DestroyProcess(rec.process)
		rec.process = nil
	}
	video_recorder_destroy_frame_pool(rec)
	rec.status = .Failed
	write_fixed_string(rec.last_error[:], text)
	engine.log_error("video_recorder: ", text)
}

video_recorder_pixel_format_name :: proc(format: vk.Format) -> string {
	#partial switch format {
	case .B8G8R8A8_UNORM, .B8G8R8A8_SRGB:
		return "bgra"
	case:
		return "rgba"
	}
}

video_recorder_find_ffmpeg :: proc() -> string {
	when ODIN_OS == .Windows {
		return ""
	} else {
		if os.exists("ffmpeg") {
			return "ffmpeg"
		}
		buf: [8192]u8
		path_value := os.get_env_buf(buf[:], "PATH")
		if len(path_value) == 0 {
			return ""
		}
		parts, err := strings.split(path_value, ":", context.temp_allocator)
		if err != nil {
			return ""
		}
		for dir in parts {
			if len(dir) == 0 {
				continue
			}
			candidate := fmt.tprintf("%s/ffmpeg", dir)
			if os.exists(candidate) {
				return candidate
			}
		}
		return ""
	}
}

video_recorder_fps_from_settings :: proc(settings: App_Settings) -> u32 {
	fps := VIDEO_RECORDER_DEFAULT_FPS
	if settings.default_fps_limit_enabled && settings.default_fps_limit > 0 {
		fps = u32(min(settings.default_fps_limit, i32(VIDEO_RECORDER_DEFAULT_FPS)))
	}
	return max(fps, 1)
}
