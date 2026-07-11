package game

import "core:strings"

toml_seek_key :: proc(table: Toml_Datum, key: string) -> Toml_Datum {
	ckey, cerr := strings.clone_to_cstring(key, context.temp_allocator)
	if cerr != nil {
		return {}
	}
	return toml_seek(table, ckey)
}

toml_i64 :: proc(table: Toml_Datum, key: string) -> (i64, bool) {
	datum := toml_seek_key(table, key)
	if datum.type == .INT64 {
		return datum.u.int64, true
	}
	return 0, false
}

toml_f64 :: proc(table: Toml_Datum, key: string) -> (f64, bool) {
	datum := toml_seek_key(table, key)
	#partial switch datum.type {
	case .FP64:
		return datum.u.fp64, true
	case .INT64:
		return f64(datum.u.int64), true
	}
	return 0, false
}

toml_bool :: proc(table: Toml_Datum, key: string) -> (bool, bool) {
	datum := toml_seek_key(table, key)
	if datum.type == .BOOLEAN {
		return datum.u.boolean, true
	}
	return false, false
}

toml_string :: proc(table: Toml_Datum, key: string) -> (string, bool) {
	datum := toml_seek_key(table, key)
	if datum.type != .STRING || datum.u.str.ptr == nil {
		return "", false
	}
	return strings.string_from_ptr(cast(^byte)datum.u.str.ptr, int(datum.u.str.len)), true
}
