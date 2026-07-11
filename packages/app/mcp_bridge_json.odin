package app

import "core:fmt"
import "core:strconv"
import "core:strings"

mcp_bridge_extract_id :: proc(line: string) -> string {
	key := "\"id\""
	i := strings.index(line, key)
	if i < 0 {
		return "null"
	}
	rest := line[i + len(key):]
	colon := strings.index(rest, ":")
	if colon < 0 {
		return "null"
	}
	rest = strings.trim_space(rest[colon + 1:])
	end := 0
	in_string := false
	for ch, idx in rest {
		if idx == 0 && ch == '"' {
			in_string = true
		} else if in_string && ch == '"' {
			end = idx + 1
			break
		} else if !in_string && (ch == ',' || ch == '}') {
			end = idx
			break
		}
	}
	if end <= 0 {
		end = len(rest)
	}
	return strings.trim_space(rest[:end])
}

mcp_bridge_extract_string_field :: proc(line, field: string) -> string {
	key := fmt.tprintf("\"%s\"", field)
	i := strings.index(line, key)
	if i < 0 {
		return ""
	}
	rest := line[i + len(key):]
	colon := strings.index(rest, ":")
	if colon < 0 {
		return ""
	}
	rest = strings.trim_space(rest[colon + 1:])
	if len(rest) == 0 || rest[0] != '"' {
		return ""
	}
	start := 1
	for idx := start; idx < len(rest); idx += 1 {
		if rest[idx] == '"' && rest[idx - 1] != '\\' {
			return rest[start:idx]
		}
	}
	return ""
}

mcp_bridge_extract_argument_string_field :: proc(line, field: string) -> string {
	arguments_key := "\"arguments\""
	i := strings.index(line, arguments_key)
	if i < 0 {
		return ""
	}
	rest := line[i + len(arguments_key):]
	colon := strings.index(rest, ":")
	if colon < 0 {
		return ""
	}
	return mcp_bridge_extract_string_field(rest[colon + 1:], field)
}

mcp_bridge_extract_number_field :: proc(line, field: string) -> (f32, bool) {
	key := fmt.tprintf("\"%s\"", field)
	i := strings.index(line, key)
	if i < 0 {
		return 0, false
	}
	rest := line[i + len(key):]
	colon := strings.index(rest, ":")
	if colon < 0 {
		return 0, false
	}
	rest = strings.trim_space(rest[colon + 1:])
	end := 0
	for idx := 0; idx < len(rest); idx += 1 {
		ch := rest[idx]
		switch ch {
		case '0'..='9', '-', '+', '.', 'e', 'E':
			end = idx + 1
		case:
			if end > 0 {
				return strconv.parse_f32(rest[:end])
			}
			return 0, false
		}
	}
	if end <= 0 {
		return 0, false
	}
	return strconv.parse_f32(rest[:end])
}

mcp_bridge_extract_bool_field :: proc(line, field: string) -> (bool, bool) {
	key := fmt.tprintf("\"%s\"", field)
	i := strings.index(line, key)
	if i < 0 {
		return false, false
	}
	rest := line[i + len(key):]
	colon := strings.index(rest, ":")
	if colon < 0 {
		return false, false
	}
	rest = strings.trim_space(rest[colon + 1:])
	if strings.has_prefix(rest, "true") {
		return true, true
	}
	if strings.has_prefix(rest, "false") {
		return false, true
	}
	return false, false
}

mcp_bridge_json_escape :: proc(text: string) -> string {
	builder: strings.Builder
	strings.builder_init(&builder, context.temp_allocator)
	for ch in text {
		switch ch {
		case '"':
			strings.write_string(&builder, "\\\"")
		case '\\':
			strings.write_string(&builder, "\\\\")
		case '\n':
			strings.write_string(&builder, "\\n")
		case '\r':
			strings.write_string(&builder, "\\r")
		case '\t':
			strings.write_string(&builder, "\\t")
		case:
			strings.write_rune(&builder, ch)
		}
	}
	return strings.to_string(builder)
}
