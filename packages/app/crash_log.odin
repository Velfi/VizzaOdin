package app

import "core:fmt"
import "core:os"

// Keep this file open for the lifetime of the process so all diagnostics written
// to stderr, including startup failures, survive GUI launches without a console.
crash_log_file: ^os.File

crash_log_init :: proc() {
	when ODIN_OS == .Windows {
		buf: [1024]u8
		local_app_data := os.get_env_buf(buf[:], "LOCALAPPDATA")
		if len(local_app_data) == 0 {
			return
		}

		log_dir := fmt.tprintf("%s/VizzaOdin/logs", local_app_data)
		if os.make_directory_all(log_dir) != nil {
			return
		}

		file, err := os.open(
			fmt.tprintf("%s/vizza.log", log_dir),
			{.Write, .Create, .Append},
		)
		if err != nil {
			return
		}

		crash_log_file = file
		os.stderr = file
		fmt.eprintln("\n--- Vizza startup ---")
	}
}
