package app

import engine "zelda_engine:engine"

import avcodec "../../vendor/ffmpeg/avcodec"
import avfmt "../../vendor/ffmpeg/avformat"
import avutil "../../vendor/ffmpeg/avutil"
import swscale "../../vendor/ffmpeg/swscale"

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:sync"
import "core:time"
import vk "vendor:vulkan"
import sdl "vendor:sdl3"

VIDEO_RECORDER_DEFAULT_FPS :: u32(60)
VIDEO_RECORDER_MAX_PATH :: MAX_FILE_PATH
VIDEO_RECORDER_MAX_ERROR :: MAX_ERROR_TEXT
VIDEO_RECORDER_FRAME_POOL_COUNT :: 16

Video_Recorder_Status :: enum {
	Idle,
	Recording,
	Failed,
}

Video_Recorder_Frame :: struct {
	index: int,
	size: int,
	repeat_count: u32,
}

Video_Recorder_Free_Queue :: engine.Bounded_Queue(int, VIDEO_RECORDER_FRAME_POOL_COUNT)
Video_Recorder_Filled_Queue :: engine.Bounded_Queue(Video_Recorder_Frame, VIDEO_RECORDER_FRAME_POOL_COUNT)

Video_Recorder_Enc :: struct {
	fmt_ctx: ^avfmt.FormatContext,
	codec_ctx: ^avcodec.CodecContext,
	stream: ^avfmt.Stream,
	sws_ctx: ^swscale.Context,
	src_frame: ^avutil.Frame,
	dst_frame: ^avutil.Frame,
	pkt: ^avcodec.Packet,
	src_pix_fmt: avutil.PixelFormat,
	enc_w: c.int,
	enc_h: c.int,
	pts: i64,
}

Video_Recorder_State :: struct {
	status: Video_Recorder_Status,
	enc: Video_Recorder_Enc,
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
	captured_frame_count: u64,
	dropped_frame_count: u64,
	start_tick: time.Tick,
	reserved_repeat_counts: [VIDEO_RECORDER_FRAME_POOL_COUNT]u32,
	output_path: [VIDEO_RECORDER_MAX_PATH]u8,
	last_error: [VIDEO_RECORDER_MAX_ERROR]u8,
}

Video_Recorder_Start_Config :: struct {
	output_path: string,
	fps: u32,
}

@(private)
_av_err_str :: proc(code: c.int) -> string {
	buf: [avutil.AV_ERROR_MAX_STRING_SIZE]c.char
	avutil.strerror(code, &buf[0], size_of(buf))
	return strings.clone_from_cstring(cstring(&buf[0]))
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

		enc_w := c.int((width + 1) & ~u32(1))
		enc_h := c.int((height + 1) & ~u32(1))
		max_dim := c.int(1920)
		if enc_w > max_dim || enc_h > max_dim {
			scale := f32(min(f32(max_dim) / f32(enc_w), f32(max_dim) / f32(enc_h)))
			enc_w = c.int(f32(enc_w) * scale + 0.5)
			enc_h = c.int(f32(enc_h) * scale + 0.5)
			enc_w = (enc_w + 1) & ~c.int(1)
			enc_h = (enc_h + 1) & ~c.int(1)
		}

		src_pix_fmt: avutil.PixelFormat
		#partial switch format {
		case .B8G8R8A8_UNORM, .B8G8R8A8_SRGB:
			src_pix_fmt = .BGRA
		case:
			src_pix_fmt = .RGBA
		}

		codec := avcodec.find_encoder_by_name("h264_videotoolbox")
		if codec == nil {
			codec = avcodec.find_encoder_by_name("libx264")
		}
		if codec == nil {
			codec = avcodec.find_encoder(.H264)
		}
		if codec == nil {
			video_recorder_fail(rec, "H.264 encoder not found")
			return false
		}

		output_c := strings.clone_to_cstring(config.output_path, context.temp_allocator)
		oc: ^avfmt.FormatContext
		ret := avfmt.alloc_output_context2(&oc, nil, nil, output_c)
		if ret < 0 || oc == nil {
			video_recorder_fail(rec, fmt.tprintf("Failed to create output context: %s", _av_err_str(ret)))
			return false
		}

		video_st := avfmt.new_stream(oc, nil)
		if video_st == nil {
			avfmt.free_context(oc)
			video_recorder_fail(rec, "Failed to create video stream")
			return false
		}

		codec_ctx := avcodec.alloc_context3(codec)
		if codec_ctx == nil {
			avfmt.free_context(oc)
			video_recorder_fail(rec, "Failed to allocate encoder context")
			return false
		}

		codec_ctx.bit_rate = 0
		codec_ctx.width = enc_w
		codec_ctx.height = enc_h
		codec_ctx.time_base = avutil.Rational{1, c.int(fps)}
		codec_ctx.framerate = avutil.Rational{c.int(fps), 1}
		codec_ctx.gop_size = c.int(fps)
		codec_ctx.max_b_frames = 0
		codec_ctx.pix_fmt = .NV12

		opts: ^avutil.Dictionary
		avutil.dict_set(&opts, "allow_sw", "1", {})
		avutil.dict_set(&opts, "realtime", "1", {})

		if .Global_Header in oc.oformat.flags {
			codec_ctx.flags += {.Global_Header}
		}

		if ret2 := avcodec.open2(codec_ctx, codec, &opts); ret2 < 0 {
			avutil.dict_free(&opts)
			avcodec.free_context(&codec_ctx)
			avfmt.free_context(oc)
			video_recorder_fail(rec, fmt.tprintf("Failed to open encoder: %s", _av_err_str(ret2)))
			return false
		}
		avutil.dict_free(&opts)

		if ret3 := avcodec.parameters_from_context(video_st.codecpar, codec_ctx); ret3 < 0 {
			avcodec.free_context(&codec_ctx)
			avfmt.free_context(oc)
			video_recorder_fail(rec, fmt.tprintf("Failed to copy codec parameters: %s", _av_err_str(ret3)))
			return false
		}
		video_st.time_base = codec_ctx.time_base

		sws := swscale.getContext(
			c.int(width), c.int(height), src_pix_fmt,
			enc_w, enc_h, .NV12,
			{.Bilinear}, nil, nil, nil,
		)
		if sws == nil {
			avcodec.free_context(&codec_ctx)
			avfmt.free_context(oc)
			video_recorder_fail(rec, "Failed to create scaler context")
			return false
		}

		src_frame := avutil.frame_alloc()
		dst_frame := avutil.frame_alloc()
		pkt := avcodec.packet_alloc()
		if src_frame == nil || dst_frame == nil || pkt == nil {
			if src_frame != nil { avutil.frame_free(&src_frame) }
			if dst_frame != nil { avutil.frame_free(&dst_frame) }
			if pkt != nil { avcodec.packet_free(&pkt) }
			swscale.free_context(&sws)
			avcodec.free_context(&codec_ctx)
			avfmt.free_context(oc)
			video_recorder_fail(rec, "Failed to allocate frames/packet")
			return false
		}

		src_frame.format = c.int(src_pix_fmt)
		src_frame.width = c.int(width)
		src_frame.height = c.int(height)

		dst_frame.format = c.int(avutil.PixelFormat.NV12)
		dst_frame.width = enc_w
		dst_frame.height = enc_h
		if ret5 := avutil.frame_get_buffer(dst_frame, 0); ret5 < 0 {
			avutil.frame_free(&src_frame)
			avutil.frame_free(&dst_frame)
			avcodec.packet_free(&pkt)
			swscale.free_context(&sws)
			avcodec.free_context(&codec_ctx)
			avfmt.free_context(oc)
			video_recorder_fail(rec, fmt.tprintf("Failed to allocate dst frame buffer: %s", _av_err_str(ret5)))
			return false
		}

		if .No_File not_in oc.oformat.flags {
			if ret6 := avfmt.open(&oc.pb, output_c, {.Write}); ret6 < 0 {
				avutil.frame_free(&src_frame)
				avutil.frame_free(&dst_frame)
				avcodec.packet_free(&pkt)
				swscale.free_context(&sws)
				avcodec.free_context(&codec_ctx)
				avfmt.free_context(oc)
				video_recorder_fail(rec, fmt.tprintf("Failed to open output file: %s", _av_err_str(ret6)))
				return false
			}
		}

		if ret7 := avfmt.write_header(oc, nil); ret7 < 0 {
			avutil.frame_free(&src_frame)
			avutil.frame_free(&dst_frame)
			avcodec.packet_free(&pkt)
			swscale.free_context(&sws)
			avcodec.free_context(&codec_ctx)
			avfmt.free_context(oc)
			video_recorder_fail(rec, fmt.tprintf("Failed to write header: %s", _av_err_str(ret7)))
			return false
		}

		frame_size := int(width * height * 4)
		for i in 0 ..< VIDEO_RECORDER_FRAME_POOL_COUNT {
			buffer, alloc_err := make([]u8, frame_size)
			if alloc_err != nil {
				video_recorder_enc_destroy(&rec.enc)
				video_recorder_destroy_frame_pool(rec)
				video_recorder_fail(rec, "Failed to allocate video recording frame buffers")
				return false
			}
			rec.frames[i] = buffer
			_ = engine.queue_try_push(&rec.free_queue, i)
		}

		rec.status = .Recording
		rec.enc = {
			fmt_ctx = oc,
			codec_ctx = codec_ctx,
			stream = video_st,
			sws_ctx = sws,
			src_frame = src_frame,
			dst_frame = dst_frame,
			pkt = pkt,
			src_pix_fmt = src_pix_fmt,
			enc_w = enc_w,
			enc_h = enc_h,
			pts = 0,
		}
		rec.width = width
		rec.height = height
		rec.fps = fps
		rec.frame_size = frame_size
		rec.start_tick = time.tick_now()
		write_fixed_string(rec.output_path[:], config.output_path)
		rec.writer_thread = sdl.CreateThread(video_recorder_writer_entry, "vizza-video", rec)
		if rec.writer_thread == nil {
			video_recorder_fail(rec, fmt.tprintf("Failed to start video writer thread: %s", sdl.GetError()))
			return false
		}
		engine.log_info("video_recorder: started path=", config.output_path, " size=", width, "x", height, " encoder=", enc_w, "x", enc_h, " fps=", fps, " src_fmt=", src_pix_fmt)
		return true
	}
}

video_recorder_stop :: proc(rec: ^Video_Recorder_State) -> bool {
	if rec == nil || rec.status == .Idle {
		return false
	}
	path := fixed_string(rec.output_path[:])
	was_failed := rec.status == .Failed
	t_stop := time.tick_now()
	thread := rec.writer_thread
	engine.queue_close(&rec.filled_queue)
	if thread != nil {
		status: c.int
		sdl.WaitThread(thread, &status)
		rec.writer_thread = nil
	}
	t_thread := time.tick_now()
	was_failed = was_failed || rec.status == .Failed
	rec.writer_thread = nil
	rec.status = .Idle
	video_recorder_enc_destroy(&rec.enc)
	t_destroy := time.tick_now()
	dropped := rec.dropped_frame_count
	video_recorder_destroy_frame_pool(rec)
	thread_ms := time.duration_milliseconds(time.tick_diff(t_stop, t_thread))
	destroy_ms := time.duration_milliseconds(time.tick_diff(t_thread, t_destroy))
	engine.log_info("video_recorder: stopped path=", path, " output_frames=", rec.frame_count, " captured_frames=", rec.captured_frame_count, " dropped=", dropped)
	engine.log_info("video_recorder: stop timings thread_wait=", thread_ms, "ms destroy=", destroy_ms, "ms")
	write_fixed_string(rec.output_path[:], path)
	return !was_failed
}

video_recorder_enc_destroy :: proc(enc: ^Video_Recorder_Enc) {
	if enc == nil {
		return
	}
	if enc.codec_ctx != nil {
		if enc.stream != nil && enc.fmt_ctx != nil {
			avcodec.send_frame(enc.codec_ctx, nil)
			for {
				ret := avcodec.receive_packet(enc.codec_ctx, enc.pkt)
				if ret == avutil.AVERROR_EAGAIN || ret == avutil.AVERROR_EOF {
					break
				}
				if ret >= 0 {
					avcodec.packet_rescale_ts(enc.pkt, enc.codec_ctx.time_base, enc.stream.time_base)
					enc.pkt.stream_index = enc.stream.index
					avfmt.write_frame(enc.fmt_ctx, enc.pkt)
					avcodec.packet_unref(enc.pkt)
				}
			}
		}
	}
	if enc.fmt_ctx != nil {
		avfmt.write_trailer(enc.fmt_ctx)
		if .No_File not_in enc.fmt_ctx.oformat.flags {
			avfmt.closep(&enc.fmt_ctx.pb)
		}
		avfmt.free_context(enc.fmt_ctx)
		enc.fmt_ctx = nil
	}
	if enc.codec_ctx != nil {
		avcodec.free_context(&enc.codec_ctx)
		enc.codec_ctx = nil
	}
	if enc.sws_ctx != nil {
		swscale.free_context(&enc.sws_ctx)
		enc.sws_ctx = nil
	}
	if enc.src_frame != nil {
		avutil.frame_free(&enc.src_frame)
		enc.src_frame = nil
	}
	if enc.dst_frame != nil {
		avutil.frame_free(&enc.dst_frame)
		enc.dst_frame = nil
	}
	if enc.pkt != nil {
		avcodec.packet_free(&enc.pkt)
		enc.pkt = nil
	}
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
	elapsed_seconds := time.duration_seconds(time.tick_diff(rec.start_tick, time.tick_now()))
	desired_frame_count := video_recorder_desired_frame_count(elapsed_seconds, rec.fps)
	if desired_frame_count <= rec.frame_count {
		return false
	}
	if !engine.queue_try_pop(&rec.free_queue, index) {
		rec.dropped_frame_count += 1
		if rec.dropped_frame_count == 1 || (rec.dropped_frame_count % 120) == 0 {
			engine.log_warn("video_recorder: dropping frame encoder behind dropped=", rec.dropped_frame_count)
		}
		return false
	}
	rec.reserved_repeat_counts[index^] = u32(min(desired_frame_count - rec.frame_count, u64(max(u32))))
	return true
}

video_recorder_release_frame :: proc(rec: ^Video_Recorder_State, index: int) {
	if rec == nil || index < 0 || index >= VIDEO_RECORDER_FRAME_POOL_COUNT {
		return
	}
	rec.reserved_repeat_counts[index] = 0
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
	repeat_count := rec.reserved_repeat_counts[index]
	if repeat_count == 0 {
		repeat_count = 1
	}
	frame := Video_Recorder_Frame{index = index, size = needed, repeat_count = repeat_count}
	if !engine.queue_try_push(&rec.filled_queue, frame) {
		video_recorder_release_frame(rec, index)
		video_recorder_fail(rec, "Recording stopped because the writer queue closed")
		return false
	}
	rec.frame_count += u64(repeat_count)
	rec.captured_frame_count += 1
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
		ok := true
		err := ""
		for _ in 0 ..< frame.repeat_count {
			ok, err = video_recorder_encode_frame(rec, rec.frames[frame.index][:frame.size])
			if !ok {
				break
			}
		}
		_ = engine.queue_try_push(&rec.free_queue, frame.index)
		if !ok {
			video_recorder_mark_failure(rec, err)
			break
		}
	}
	return 0
}

video_recorder_encode_frame :: proc(rec: ^Video_Recorder_State, pixels: []u8) -> (bool, string) {
	enc := &rec.enc
	if enc.codec_ctx == nil || enc.dst_frame == nil || enc.sws_ctx == nil || enc.fmt_ctx == nil || enc.src_frame == nil {
		return false, "Encoder not initialized"
	}

	t0 := time.tick_now()

	avutil.image_fill_arrays(
		raw_data(enc.src_frame.data[:]),
		raw_data(enc.src_frame.linesize[:]),
		raw_data(pixels),
		enc.src_pix_fmt,
		c.int(rec.width),
		c.int(rec.height),
		1,
	)
	enc.src_frame.pts = enc.pts

	t1 := time.tick_now()

	if ret := swscale.scale_frame(enc.sws_ctx, enc.dst_frame, enc.src_frame); ret < 0 {
		return false, fmt.tprintf("Failed to scale frame: %s", _av_err_str(ret))
	}

	enc.dst_frame.pts = enc.pts
	enc.pts += 1

	t2 := time.tick_now()

	if ret := avcodec.send_frame(enc.codec_ctx, enc.dst_frame); ret < 0 {
		return false, fmt.tprintf("Failed to send frame to encoder: %s", _av_err_str(ret))
	}

	t3 := time.tick_now()

	packet_count := 0
	for {
		ret := avcodec.receive_packet(enc.codec_ctx, enc.pkt)
		if ret == avutil.AVERROR_EAGAIN || ret == avutil.AVERROR_EOF {
			break
		}
		if ret < 0 {
			return false, fmt.tprintf("Failed to receive packet from encoder: %s", _av_err_str(ret))
		}
		avcodec.packet_rescale_ts(enc.pkt, enc.codec_ctx.time_base, enc.stream.time_base)
		enc.pkt.stream_index = enc.stream.index
		if ret2 := avfmt.write_frame(enc.fmt_ctx, enc.pkt); ret2 < 0 {
			avcodec.packet_unref(enc.pkt)
			return false, fmt.tprintf("Failed to write packet: %s", _av_err_str(ret2))
		}
		avcodec.packet_unref(enc.pkt)
		packet_count += 1
	}

	t4 := time.tick_now()

	fill_us := time.duration_microseconds(time.tick_diff(t0, t1))
	scale_us := time.duration_microseconds(time.tick_diff(t1, t2))
	send_us := time.duration_microseconds(time.tick_diff(t2, t3))
	drain_us := time.duration_microseconds(time.tick_diff(t3, t4))
	total_us := fill_us + scale_us + send_us + drain_us
	if total_us > 8000 || enc.pts < 120 {
		engine.log_info("video_recorder: frame ", enc.pts-1, " total=", total_us, "us fill=", fill_us, "us scale=", scale_us, "us send=", send_us, "us drain=", drain_us, "us pkts=", packet_count)
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
	video_recorder_enc_destroy(&rec.enc)
	video_recorder_destroy_frame_pool(rec)
	rec.status = .Failed
	write_fixed_string(rec.last_error[:], text)
	engine.log_error("video_recorder: ", text)
}

video_recorder_fps_from_settings :: proc(settings: App_Settings) -> u32 {
	fps := VIDEO_RECORDER_DEFAULT_FPS
	if settings.default_fps_limit_enabled && settings.default_fps_limit > 0 {
		fps = u32(min(settings.default_fps_limit, i32(VIDEO_RECORDER_DEFAULT_FPS)))
	}
	return max(fps, 1)
}

video_recorder_desired_frame_count :: proc(elapsed_seconds: f64, fps: u32) -> u64 {
	if fps == 0 {
		return 0
	}
	return u64(max(elapsed_seconds, 0) * f64(fps)) + 1
}

video_recorder_capture_sink :: proc(rec: ^Video_Recorder_State) -> Video_Capture_Sink {
	return {
		userdata = rec,
		is_recording = video_recorder_capture_is_recording,
		reserve_frame = video_recorder_capture_reserve,
		release_frame = video_recorder_capture_release,
		submit_frame = video_recorder_capture_submit,
		fail = video_recorder_capture_fail,
	}
}

video_recorder_capture_is_recording :: proc(data: rawptr) -> bool {
	return video_recorder_is_recording(cast(^Video_Recorder_State)data)
}

video_recorder_capture_reserve :: proc(data: rawptr, index: ^int) -> bool {
	return video_recorder_reserve_frame(cast(^Video_Recorder_State)data, index)
}

video_recorder_capture_release :: proc(data: rawptr, index: int) {
	video_recorder_release_frame(cast(^Video_Recorder_State)data, index)
}

video_recorder_capture_submit :: proc(data: rawptr, index: int, pixels: []u8, width, height: u32, format: Capture_Pixel_Format) -> bool {
	vk_format: vk.Format
	switch format {
	case .RGBA8_UNorm: vk_format = .R8G8B8A8_UNORM
	case .BGRA8_UNorm: vk_format = .B8G8R8A8_UNORM
	case .RGBA8_SRGB: vk_format = .R8G8B8A8_SRGB
	case .BGRA8_SRGB: vk_format = .B8G8R8A8_SRGB
	}
	return video_recorder_submit_reserved_frame(cast(^Video_Recorder_State)data, index, pixels, width, height, vk_format)
}

video_recorder_capture_fail :: proc(data: rawptr, text: string) {
	video_recorder_fail(cast(^Video_Recorder_State)data, text)
}
