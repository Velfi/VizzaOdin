package app

import engine "../engine"

import "core:c"
import "core:time"
import sdl "vendor:sdl3"
//
// Main thread always owns SDL: window creation, event polling, and immutable
// per-frame input snapshots published through ui_to_render.
//
// The frame processor owns everything GPU-facing: Vulkan init/present, simulation
// stepping, immediate-mode UI layout, and render-graph execution. It reads only
// queued commands and never polls SDL events.
//
// macOS/MoltenVK requires Vulkan surface/swapchain work on the main thread, so
// Darwin uses Main_Thread mode. Other platforms use a background SDL thread.

Frame_Processor_Mode :: enum {
	Main_Thread,
	Background_Thread,
}

frame_processor_mode :: proc() -> Frame_Processor_Mode {
	when ODIN_OS == .Darwin {
		return .Main_Thread
	}
	return .Background_Thread
}

frame_processor_bootstrap :: proc(app: ^App_State) -> bool {
	app.frame_processor_mode = frame_processor_mode()
	when ODIN_OS == .Darwin {
		return true
	} else {
		app.render_thread = sdl.CreateThread(render_worker_entry, "vizza-frame", &app.render_worker)
		if app.render_thread == nil {
			engine.log_error("Frame processor thread creation failed: ", sdl.GetError())
			return false
		}
		return true
	}
}

frame_processor_pump :: proc(app: ^App_State) {
	if app.frame_processor_mode != .Main_Thread {
		return
	}
	render_worker_pump(&app.render_worker, &app.render_runtime)
}

frame_processor_shutdown :: proc(app: ^App_State) {
	total_start := time.tick_now()
	engine.log_info("shutdown: frame_processor begin mode=", app.frame_processor_mode)
	close_cmd: Ui_To_Render_Command
	close_cmd.kind = .Close

	when ODIN_OS == .Darwin {
		step_start := time.tick_now()
		_ = engine.queue_try_push(&app.ui_to_render, close_cmd)
		engine.log_info("shutdown: queue close command ms=", shutdown_elapsed_ms(step_start))
		step_start = time.tick_now()
		render_worker_pump(&app.render_worker, &app.render_runtime)
		engine.log_info("shutdown: render worker close pump ms=", shutdown_elapsed_ms(step_start))
		step_start = time.tick_now()
		render_worker_runtime_shutdown(&app.render_worker, &app.render_runtime)
		engine.log_info("shutdown: render worker runtime shutdown ms=", shutdown_elapsed_ms(step_start))
	} else {
		step_start := time.tick_now()
		_ = engine.queue_push_blocking(&app.ui_to_render, close_cmd)
		engine.log_info("shutdown: queue close command ms=", shutdown_elapsed_ms(step_start))
		step_start = time.tick_now()
		engine.queue_close(&app.ui_to_render)
		engine.log_info("shutdown: close ui_to_render queue ms=", shutdown_elapsed_ms(step_start))
		if app.render_thread != nil {
			step_start = time.tick_now()
			status: c.int
			sdl.WaitThread(app.render_thread, &status)
			app.render_thread = nil
			engine.log_info("shutdown: wait render thread ms=", shutdown_elapsed_ms(step_start), " status=", status)
		}
	}
	engine.log_info("shutdown: frame_processor total ms=", shutdown_elapsed_ms(total_start))
}

shutdown_elapsed_ms :: proc(start: time.Tick) -> f64 {
	return time.duration_seconds(time.tick_diff(start, time.tick_now())) * 1000.0
}
