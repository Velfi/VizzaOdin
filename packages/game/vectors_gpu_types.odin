package game

import engine "../engine"
import uifw "../ui"

import "core:math"
import vk "vendor:vulkan"

VECTORS_VERTEX_SHADER_SOURCE :: "assets/shaders/simulations/vectors/shaders/line_vertex.slang"
VECTORS_FRAGMENT_SHADER_SOURCE :: "assets/shaders/simulations/vectors/shaders/line_fragment.slang"
VECTORS_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/vectors/shaders/line_vertex"
VECTORS_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/vectors/shaders/line_fragment"
VECTORS_SOURCE_ENTRY :: "main"
VECTORS_ENTRY :: cstring("main")
// The densest supported 2.4 x 1.8 field is 480 x 360 vectors.
VECTORS_MIN_DENSITY :: f32(0.005)
VECTORS_MAX_SEGMENTS :: 480 * 360
VECTORS_MAX_VERTICES :: VECTORS_MAX_SEGMENTS * 4
VECTORS_MAX_INDICES :: VECTORS_MAX_SEGMENTS * 6
VECTORS_IMAGE_RESOLUTION :: 512

Vectors_Vertex :: struct #align(4) {
	position: [2]f32,
	value: f32,
}

Vectors_Camera_Uniform :: struct #align(16) {
	transform_matrix: [16]f32,
	position: [2]f32,
	zoom: f32,
	aspect_ratio: f32,
}

Vectors_Gpu_State :: struct {
	vertex_shader: engine.Vk_Shader_Module,
	fragment_shader: engine.Vk_Shader_Module,
	pipeline: engine.Vk_Graphics_Pipeline,
	descriptor_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	descriptor_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	vertex_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	index_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	camera_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	index_count: u32,
	active_frame_slot: u32,
	image_data: []u8,
	image_loaded: bool,
	image_path: [MAX_FILE_PATH]u8,
	image_fit_uploaded: Vector_Image_Fit_Mode,
	image_mirror_horizontal_uploaded: bool,
	image_mirror_vertical_uploaded: bool,
	image_invert_tone_uploaded: bool,
	ready: bool,
}

vectors_sample_image_source :: proc(source: [^]u8, width, height, pitch, x, y: int) -> u8 {
	if source == nil || width <= 0 || height <= 0 {
		return 0
	}
	sx := max(min(x, width - 1), 0)
	sy := max(min(y, height - 1), 0)
	i := sy * pitch + sx * 4
	r := f32(source[i + 0]) / 255.0
	g := f32(source[i + 1]) / 255.0
	b := f32(source[i + 2]) / 255.0
	a := f32(source[i + 3]) / 255.0
	lum := math.clamp((r * 0.2126 + g * 0.7152 + b * 0.0722) * a, 0, 1)
	return u8(lum * 255.0 + 0.5)
}

vectors_image_source_coord :: proc(source_width, source_height, target_width, target_height, x, y: int, fit_mode: Vector_Image_Fit_Mode, out_x, out_y: ^int) -> bool {
	if source_width <= 0 || source_height <= 0 || target_width <= 0 || target_height <= 0 {
		return false
	}
	switch fit_mode {
	case .Center:
		start_x := source_width > target_width ? 0 : (target_width - source_width) / 2
		start_y := source_height > target_height ? 0 : (target_height - source_height) / 2
		src_x := x
		src_y := y
		if source_width > target_width {
			src_x = int((u64(x) * u64(source_width)) / u64(target_width))
		} else {
			src_x = x - start_x
		}
		if source_height > target_height {
			src_y = int((u64(y) * u64(source_height)) / u64(target_height))
		} else {
			src_y = y - start_y
		}
		if src_x < 0 || src_y < 0 || src_x >= source_width || src_y >= source_height {
			return false
		}
		out_x^ = src_x
		out_y^ = source_height - 1 - src_y
		return true
	case .Fit_H:
		new_height := max(int(f32(target_width) * f32(source_height) / f32(max(source_width, 1))), 1)
		start_y := new_height > target_height ? 0 : (target_height - new_height) / 2
		local_y := y - start_y
		if local_y < 0 || local_y >= new_height {
			return false
		}
		out_x^ = int((u64(x) * u64(source_width)) / u64(target_width))
		out_y^ = source_height - 1 - int((u64(local_y) * u64(source_height)) / u64(new_height))
		return true
	case .Fit_V:
		new_width := max(int(f32(target_height) * f32(source_width) / f32(max(source_height, 1))), 1)
		start_x := new_width > target_width ? 0 : (target_width - new_width) / 2
		local_x := x - start_x
		if local_x < 0 || local_x >= new_width {
			return false
		}
		out_x^ = int((u64(local_x) * u64(source_width)) / u64(new_width))
		out_y^ = source_height - 1 - int((u64(y) * u64(source_height)) / u64(target_height))
		return true
	case .Stretch:
		fallthrough
	}
	out_x^ = int((u64(x) * u64(source_width)) / u64(target_width))
	out_y^ = source_height - 1 - int((u64(y) * u64(source_height)) / u64(target_height))
	return true
}

vectors_clear_color :: proc(settings: ^Vectors_Settings) -> uifw.Color {
	#partial switch settings.background_color_mode {
	case .White:
		return {0.92, 0.93, 0.90, 1}
	case .Gray18:
		return {0.18, 0.18, 0.18, 1}
	case .Color_Scheme:
		scheme := color_scheme_effective(&settings.color_scheme, settings.color_scheme_reversed)
		color := color_scheme_color_at(scheme, 0)
		return {color[0], color[1], color[2], color[3]}
	case:
		return {0.0, 0.0, 0.0, 1}
	}
}
