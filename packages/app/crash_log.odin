package app

import engine "../engine"

import "core:fmt"
import "core:os"
import "core:time"

// Keep this file open for the lifetime of the process so all diagnostics written
// to stderr, including startup failures, survive GUI launches without a console.
crash_log_file: ^os.File

CRASH_LOG_MAX_BYTES :: i64(4 * 1024 * 1024)

crash_log_default_path :: proc(local_app_data: string) -> string {
	if len(local_app_data) > 0 {
		return fmt.tprintf("%s/VizzaOdin/logs/vizza.log", local_app_data)
	}
	if exe_dir, err := os.get_executable_directory(context.temp_allocator); err == nil {
		return fmt.tprintf("%s/vizza.log", exe_dir)
	}
	return "vizza.log"
}

crash_log_rotate :: proc(path: string) {
	file, err := os.open(path, {.Read})
	if err != nil {
		return
	}
	size, size_err := os.file_size(file)
	_ = os.close(file)
	if size_err == nil && size >= CRASH_LOG_MAX_BYTES {
		previous := fmt.tprintf("%s.previous", path)
		_ = os.remove(previous)
		_ = os.rename(path, previous)
	}
}

crash_log_init :: proc() {
	when ODIN_OS == .Windows {
		buf: [1024]u8
		local_app_data := os.get_env_buf(buf[:], "LOCALAPPDATA")
		path_buf: [2048]u8
		path := os.get_env_buf(path_buf[:], "VIZZA_LOG_PATH")
		if len(path) == 0 {
			path = crash_log_default_path(local_app_data)
		}

		if len(local_app_data) > 0 && len(os.get_env_buf(path_buf[:], "VIZZA_LOG_PATH")) == 0 {
			log_dir := fmt.tprintf("%s/VizzaOdin/logs", local_app_data)
			if os.make_directory_all(log_dir) != nil {
				path = crash_log_default_path("")
			}
		}

		crash_log_rotate(path)
		file, err := os.open(
			path,
			{.Write, .Create, .Append},
		)
		if err != nil {
			return
		}

		crash_log_file = file
		engine.log_set_file(file)
		engine.log_info("\n--- Vizza startup: time=", time.now(), " log=", path, " ---")
		if cwd, cwd_err := os.get_working_directory(context.temp_allocator); cwd_err == nil {
			engine.log_info("startup: cwd=", cwd)
		}
		if exe, exe_err := os.get_executable_path(context.temp_allocator); exe_err == nil {
			engine.log_info("startup: executable=", exe)
		}
		engine.log_info("startup: args=", os.args)
	}
}

crash_log_shutdown :: proc(exit_code: int) {
	when ODIN_OS == .Windows {
		if crash_log_file == nil {
			return
		}
		engine.log_info("--- Vizza shutdown: exit_code=", exit_code, " clean=true ---")
		engine.log_set_file(nil)
		_ = os.sync(crash_log_file)
		_ = os.close(crash_log_file)
		crash_log_file = nil
	}
}
