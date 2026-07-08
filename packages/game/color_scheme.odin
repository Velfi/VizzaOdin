package game

import "core:fmt"
import "core:math"
import "core:os"
import "core:slice"
import "core:strings"
import "core:sync"

COLOR_SCHEME_SIZE :: 256
COLOR_SCHEME_CHANNEL_COUNT :: 3
COLOR_SCHEME_U32_COUNT :: COLOR_SCHEME_SIZE * COLOR_SCHEME_CHANNEL_COUNT
COLOR_SCHEME_BYTE_COUNT :: COLOR_SCHEME_U32_COUNT
COLOR_SCHEME_NAME_MAX :: 128
COLOR_SCHEME_AVAILABLE_NAME_CACHE_MAX :: 256
COLOR_SCHEME_ASSET_DIR :: "assets/LUTs"
COLOR_SCHEME_CUSTOM_DIR :: "config/LUTs"
COLOR_SCHEME_DEFAULT_NAME :: "MATPLOTLIB_bone"

COLOR_SCHEME_LEGACY_NAMES := [?]string {
	"MATPLOTLIB_prism",
	"MATPLOTLIB_viridis",
	"ZELDA_Terrain",
	"ZELDA_Monochrome",
}

Color_Scheme :: struct {
	name: string,
	red: [COLOR_SCHEME_SIZE]u8,
	green: [COLOR_SCHEME_SIZE]u8,
	blue: [COLOR_SCHEME_SIZE]u8,
}

Color_Scheme_Name :: [COLOR_SCHEME_NAME_MAX]u8

color_scheme_available_names_cache: [COLOR_SCHEME_AVAILABLE_NAME_CACHE_MAX]Color_Scheme_Name
color_scheme_available_names_cache_strings: [COLOR_SCHEME_AVAILABLE_NAME_CACHE_MAX]string
color_scheme_available_names_cache_count: int
color_scheme_available_names_overflow: [dynamic]string
color_scheme_available_names_overflow_active := false
color_scheme_available_names_cache_valid := false
color_scheme_available_names_cache_mutex: sync.Mutex

color_scheme_name_get :: proc(name: ^Color_Scheme_Name) -> string {
	n := 0
	for n < len(name^) && name^[n] != 0 {
		n += 1
	}
	return string(name^[:n])
}

color_scheme_name_set :: proc(name: ^Color_Scheme_Name, value: string) {
	for i in 0 ..< len(name^) {
		name^[i] = 0
	}
	n := min(len(value), len(name^) - 1)
	for i in 0 ..< n {
		name^[i] = value[i]
	}
}

color_scheme_legacy_name :: proc(index: int) -> string {
	i := max(min(index, len(COLOR_SCHEME_LEGACY_NAMES) - 1), 0)
	return COLOR_SCHEME_LEGACY_NAMES[i]
}

color_scheme_load_from_bytes :: proc(name: string, data: []u8) -> (Color_Scheme, bool) {
	if len(data) != COLOR_SCHEME_BYTE_COUNT {
		return {}, false
	}
	scheme: Color_Scheme
	scheme.name = name
	copy(scheme.red[:], data[0:COLOR_SCHEME_SIZE])
	copy(scheme.green[:], data[COLOR_SCHEME_SIZE:COLOR_SCHEME_SIZE * 2])
	copy(scheme.blue[:], data[COLOR_SCHEME_SIZE * 2:COLOR_SCHEME_SIZE * 3])
	return scheme, true
}

color_scheme_reverse :: proc(scheme: ^Color_Scheme) {
	for i in 0 ..< COLOR_SCHEME_SIZE / 2 {
		j := COLOR_SCHEME_SIZE - 1 - i
		scheme.red[i], scheme.red[j] = scheme.red[j], scheme.red[i]
		scheme.green[i], scheme.green[j] = scheme.green[j], scheme.green[i]
		scheme.blue[i], scheme.blue[j] = scheme.blue[j], scheme.blue[i]
	}
}

color_scheme_write_u32_buffer :: proc(scheme: Color_Scheme, out: []u32) -> bool {
	if len(out) < COLOR_SCHEME_U32_COUNT {
		return false
	}
	for i in 0 ..< COLOR_SCHEME_SIZE {
		out[i] = u32(scheme.red[i])
		out[i + COLOR_SCHEME_SIZE] = u32(scheme.green[i])
		out[i + COLOR_SCHEME_SIZE * 2] = u32(scheme.blue[i])
	}
	return true
}

color_scheme_file_path :: proc(dir, name: string) -> string {
	return fmt.tprintf("%s/%s.lut", dir, name)
}

color_scheme_load_from_dir :: proc(dir, name: string) -> (Color_Scheme, bool) {
	path := color_scheme_file_path(dir, name)
	data, err := os.read_entire_file_from_path(path, context.temp_allocator)
	if err != nil {
		return {}, false
	}
	return color_scheme_load_from_bytes(name, data)
}

color_scheme_load :: proc(name: string) -> (Color_Scheme, bool) {
	if scheme, ok := color_scheme_load_from_dir(COLOR_SCHEME_ASSET_DIR, name); ok {
		return scheme, true
	}
	if scheme, ok := color_scheme_load_from_dir(COLOR_SCHEME_CUSTOM_DIR, name); ok {
		return scheme, true
	}
	return {}, false
}

color_scheme_default :: proc() -> Color_Scheme {
	if scheme, ok := color_scheme_load(COLOR_SCHEME_DEFAULT_NAME); ok {
		color_scheme_reverse(&scheme)
		return scheme
	}

	scheme: Color_Scheme
	scheme.name = "ZELDA_Monochrome"
	for i in 0 ..< COLOR_SCHEME_SIZE {
		v := u8(i)
		scheme.red[i] = v
		scheme.green[i] = v
		scheme.blue[i] = v
	}
	return scheme
}

color_scheme_effective :: proc(name: ^Color_Scheme_Name, reversed: bool) -> Color_Scheme {
	scheme_name := color_scheme_name_get(name)
	scheme, ok := color_scheme_load(scheme_name)
	if !ok {
		scheme = color_scheme_default()
	}
	if reversed {
		color_scheme_reverse(&scheme)
	}
	return scheme
}

color_scheme_srgb_to_linear :: proc(srgb: f32) -> f32 {
	if srgb <= 0.04045 {
		return srgb / 12.92
	}
	return math.pow((srgb + 0.055) / 1.055, 2.4)
}

color_scheme_color_at :: proc(scheme: Color_Scheme, index: int) -> [4]f32 {
	i := max(min(index, COLOR_SCHEME_SIZE - 1), 0)
	r := f32(scheme.red[i]) / 255.0
	g := f32(scheme.green[i]) / 255.0
	b := f32(scheme.blue[i]) / 255.0
	return {
		color_scheme_srgb_to_linear(r),
		color_scheme_srgb_to_linear(g),
		color_scheme_srgb_to_linear(b),
		1,
	}
}

color_scheme_append_names_from_dir :: proc(names: ^[dynamic]string, dir: string) {
	entries, err := os.read_all_directory_by_path(dir, context.temp_allocator)
	if err != nil {
		return
	}
	defer os.file_info_slice_delete(entries, context.temp_allocator)
	for entry in entries {
		if entry.type != .Regular {
			continue
		}
		if os.ext(entry.name) != ".lut" {
			continue
		}
		name := os.stem(entry.name)
		if len(name) == 0 {
			continue
		}
		append(names, strings.clone(name, context.allocator) or_continue)
	}
}

color_scheme_available_names :: proc(allocator := context.allocator) -> []string {
	old_allocator := context.allocator
	context.allocator = allocator
	defer context.allocator = old_allocator

	names := make([dynamic]string, 0, 192, allocator)
	color_scheme_append_names_from_dir(&names, COLOR_SCHEME_ASSET_DIR)
	color_scheme_append_names_from_dir(&names, COLOR_SCHEME_CUSTOM_DIR)
	slice.sort(names[:])
	return names[:]
}

color_scheme_available_names_cached :: proc() -> []string {
	if !color_scheme_available_names_cache_valid {
		sync.mutex_lock(&color_scheme_available_names_cache_mutex)
		if !color_scheme_available_names_cache_valid {
			color_scheme_rebuild_available_names_cache()
		}
		sync.mutex_unlock(&color_scheme_available_names_cache_mutex)
	}
	if color_scheme_available_names_overflow_active {
		return color_scheme_available_names_overflow[:]
	}
	return color_scheme_available_names_cache_strings[:color_scheme_available_names_cache_count]
}

color_scheme_rebuild_available_names_cache :: proc() {
	color_scheme_clear_available_names_cache()
	color_scheme_append_cached_names_from_dir(COLOR_SCHEME_ASSET_DIR)
	color_scheme_append_cached_names_from_dir(COLOR_SCHEME_CUSTOM_DIR)
	if color_scheme_available_names_overflow_active {
		slice.sort(color_scheme_available_names_overflow[:])
	} else {
		slice.sort(color_scheme_available_names_cache_strings[:color_scheme_available_names_cache_count])
	}
	color_scheme_available_names_cache_valid = true
}

color_scheme_available_names_invalidate :: proc() {
	sync.mutex_lock(&color_scheme_available_names_cache_mutex)
	color_scheme_clear_available_names_cache()
	sync.mutex_unlock(&color_scheme_available_names_cache_mutex)
}

color_scheme_clear_available_names_cache :: proc() {
	for i in 0 ..< color_scheme_available_names_cache_count {
		color_scheme_available_names_cache[i] = {}
		color_scheme_available_names_cache_strings[i] = ""
	}
	color_scheme_available_names_cache_count = 0
	if color_scheme_available_names_overflow_active {
		for name in color_scheme_available_names_overflow {
			delete(name)
		}
		delete(color_scheme_available_names_overflow)
	}
	color_scheme_available_names_overflow = {}
	color_scheme_available_names_overflow_active = false
	color_scheme_available_names_cache_valid = false
}

color_scheme_append_cached_names_from_dir :: proc(dir: string) {
	entries, err := os.read_all_directory_by_path(dir, context.temp_allocator)
	if err != nil {
		return
	}
	defer os.file_info_slice_delete(entries, context.temp_allocator)
	for entry in entries {
		if entry.type != .Regular {
			continue
		}
		if os.ext(entry.name) != ".lut" {
			continue
		}
		name := os.stem(entry.name)
		if len(name) == 0 {
			continue
		}
		color_scheme_append_cached_name(name)
	}
}

color_scheme_append_cached_name :: proc(name: string) {
	if color_scheme_available_names_overflow_active {
		color_scheme_append_cached_overflow_name(name)
		return
	}
	if color_scheme_available_names_cache_count < COLOR_SCHEME_AVAILABLE_NAME_CACHE_MAX {
		index := color_scheme_available_names_cache_count
		color_scheme_name_set(&color_scheme_available_names_cache[index], name)
		color_scheme_available_names_cache_strings[index] = color_scheme_name_get(&color_scheme_available_names_cache[index])
		color_scheme_available_names_cache_count += 1
		return
	}
	color_scheme_promote_available_names_cache()
	color_scheme_append_cached_overflow_name(name)
}

color_scheme_promote_available_names_cache :: proc() {
	if color_scheme_available_names_overflow_active {
		return
	}
	color_scheme_available_names_overflow = make([dynamic]string, 0, COLOR_SCHEME_AVAILABLE_NAME_CACHE_MAX * 2)
	for name in color_scheme_available_names_cache_strings[:color_scheme_available_names_cache_count] {
		append(&color_scheme_available_names_overflow, strings.clone(name) or_continue)
	}
	color_scheme_available_names_overflow_active = true
}

color_scheme_append_cached_overflow_name :: proc(name: string) {
	cloned, err := strings.clone(name)
	if err != nil {
		return
	}
	append(&color_scheme_available_names_overflow, cloned)
}

color_scheme_index_of :: proc(names: []string, name: string) -> int {
	for item, i in names {
		if item == name {
			return i
		}
	}
	return 0
}

color_scheme_save_custom :: proc(name: string, scheme: Color_Scheme) -> bool {
	if len(name) == 0 {
		return false
	}
	if os.make_directory_all(COLOR_SCHEME_CUSTOM_DIR) != nil {
		return false
	}
	path := color_scheme_file_path(COLOR_SCHEME_CUSTOM_DIR, name)
	data: [COLOR_SCHEME_BYTE_COUNT]u8
	for i in 0 ..< COLOR_SCHEME_SIZE {
		data[i] = scheme.red[i]
		data[i + COLOR_SCHEME_SIZE] = scheme.green[i]
		data[i + COLOR_SCHEME_SIZE * 2] = scheme.blue[i]
	}
	if os.write_entire_file(path, data[:]) != nil {
		return false
	}
	color_scheme_available_names_invalidate()
	return true
}
