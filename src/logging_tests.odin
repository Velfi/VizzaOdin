package main

import host "../packages/app"
import engine "zelda_engine:engine"

import "core:os"
import "core:strings"
import "core:testing"

@(test)
test_crash_log_default_path_uses_local_app_data :: proc(t: ^testing.T) {
	path := host.crash_log_default_path("C:/Users/steamuser/AppData/Local")
	testing.expect_value(t, path, "C:/Users/steamuser/AppData/Local/VizzaOdin/logs/vizza.log")
}

@(test)
test_crash_log_macos_default_path_uses_library_logs :: proc(t: ^testing.T) {
	path := host.crash_log_macos_default_path("/Users/player")
	testing.expect_value(t, path, "/Users/player/Library/Logs/VizzaOdin/vizza.log")
}

@(test)
test_engine_log_secondary_sink_is_immediately_readable :: proc(t: ^testing.T) {
	path := "/tmp/vizzaodin_engine_log_test.log"
	_ = os.remove(path)
	file, err := os.open(path, {.Write, .Create, .Trunc})
	testing.expect(t, err == nil)
	if err != nil {
		return
	}

	engine.log_set_file(file)
	engine.log_info("durable-log-test")
	engine.log_set_file(nil)
	_ = os.close(file)

	data, read_err := os.read_entire_file(path, context.temp_allocator)
	testing.expect(t, read_err == nil)
	if read_err == nil {
		testing.expect(t, strings.contains(string(data), "durable-log-test"))
	}
	_ = os.remove(path)
}
