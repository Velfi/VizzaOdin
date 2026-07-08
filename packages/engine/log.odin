package engine

import "core:fmt"
import "core:os"

Log_Level :: enum int {
	Off,
	Error,
	Warn,
	Info,
	Debug,
	Trace,
}

log_level: Log_Level = .Info
log_level_loaded := false

log_configure_from_env :: proc() {
	if log_level_loaded {
		return
	}
	buf: [32]u8
	value := os.get_env_buf(buf[:], "VIZZA_LOG_LEVEL")
	if len(value) > 0 {
		log_level = log_parse_level(value)
	}
	log_level_loaded = true
}

log_set_level :: proc(level: Log_Level) {
	log_level = level
	log_level_loaded = true
}

log_enabled :: proc(level: Log_Level) -> bool {
	log_configure_from_env()
	return level != .Off && int(level) <= int(log_level)
}

log_error :: proc(args: ..any) {
	if log_enabled(.Error) {
		fmt.eprintln(..args)
	}
}

log_warn :: proc(args: ..any) {
	if log_enabled(.Warn) {
		fmt.eprintln(..args)
	}
}

log_info :: proc(args: ..any) {
	if log_enabled(.Info) {
		fmt.eprintln(..args)
	}
}

log_debug :: proc(args: ..any) {
	if log_enabled(.Debug) {
		fmt.eprintln(..args)
	}
}

log_trace :: proc(args: ..any) {
	if log_enabled(.Trace) {
		fmt.eprintln(..args)
	}
}

log_parse_level :: proc(value: string) -> Log_Level {
	switch value {
	case "off", "OFF", "Off", "quiet", "QUIET", "Quiet", "none", "NONE", "None", "0":
		return .Off
	case "error", "ERROR", "Error", "err", "ERR", "Err", "1":
		return .Error
	case "warn", "WARN", "Warn", "warning", "WARNING", "Warning", "2":
		return .Warn
	case "info", "INFO", "Info", "3":
		return .Info
	case "debug", "DEBUG", "Debug", "4":
		return .Debug
	case "trace", "TRACE", "Trace", "5":
		return .Trace
	}
	return .Info
}
