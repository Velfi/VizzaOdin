package game

import uifw "zelda_engine:ui"

import "core:math"
import "core:strings"

color_scheme_editor_interpolate :: proc(a, b: uifw.Color, t: f32, color_space: int) -> uifw.Color {
	tt := uifw.gui_clamp01(t)
	switch color_space {
	case 1:
		return color_scheme_editor_interpolate_lab(a, b, tt)
	case 2:
		return color_scheme_editor_interpolate_oklab(a, b, tt)
	case 3:
		return color_scheme_editor_interpolate_jzazbz(a, b, tt)
	case 4:
		return color_scheme_editor_interpolate_hsluv(a, b, tt)
	}
	return color_scheme_editor_lerp_rgb(a, b, tt)
}

color_scheme_editor_lerp_rgb :: proc(a, b: uifw.Color, t: f32) -> uifw.Color {
	return {a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1}
}

color_scheme_editor_interpolate_oklab :: proc(a, b: uifw.Color, t: f32) -> uifw.Color {
	l1, a1, b1 := color_scheme_editor_srgb_to_oklab(a)
	l2, a2, b2 := color_scheme_editor_srgb_to_oklab(b)
	return color_scheme_editor_oklab_to_srgb(
		l1 + (l2 - l1) * t,
		a1 + (a2 - a1) * t,
		b1 + (b2 - b1) * t,
	)
}

color_scheme_editor_srgb_to_oklab :: proc(c: uifw.Color) -> (l, a, b: f32) {
	r := color_scheme_editor_srgb_to_linear(c.r)
	g := color_scheme_editor_srgb_to_linear(c.g)
	bl := color_scheme_editor_srgb_to_linear(c.b)

	lms_l := 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * bl
	lms_m := 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * bl
	lms_s := 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * bl

	l_ := color_scheme_editor_cbrt(lms_l)
	m_ := color_scheme_editor_cbrt(lms_m)
	s_ := color_scheme_editor_cbrt(lms_s)

	l = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
	a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
	b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
	return
}

color_scheme_editor_oklab_to_srgb :: proc(l, a, b: f32) -> uifw.Color {
	l_ := l + 0.3963377774 * a + 0.2158037573 * b
	m_ := l - 0.1055613458 * a - 0.0638541728 * b
	s_ := l - 0.0894841775 * a - 1.2914855480 * b

	lms_l := l_ * l_ * l_
	lms_m := m_ * m_ * m_
	lms_s := s_ * s_ * s_

	r := +4.0767416621 * lms_l - 3.3077115913 * lms_m + 0.2309699292 * lms_s
	g := -1.2684380046 * lms_l + 2.6097574011 * lms_m - 0.3413193965 * lms_s
	bl := -0.0041960863 * lms_l - 0.7034186147 * lms_m + 1.7076147010 * lms_s
	return {
		r = uifw.gui_clamp01(color_scheme_editor_linear_to_srgb(r)),
		g = uifw.gui_clamp01(color_scheme_editor_linear_to_srgb(g)),
		b = uifw.gui_clamp01(color_scheme_editor_linear_to_srgb(bl)),
		a = 1,
	}
}

COLOR_SCHEME_EDITOR_JZAZBZ_M1 :: f32(0.1593017578125)
COLOR_SCHEME_EDITOR_JZAZBZ_C1 :: f32(0.8359375)
COLOR_SCHEME_EDITOR_JZAZBZ_C2 :: f32(18.8515625)
COLOR_SCHEME_EDITOR_JZAZBZ_C3 :: f32(18.6875)
COLOR_SCHEME_EDITOR_JZAZBZ_P :: f32(134.03437499999998)
COLOR_SCHEME_EDITOR_JZAZBZ_D0 :: f32(1.6295499532821566e-11)

color_scheme_editor_interpolate_jzazbz :: proc(a, b: uifw.Color, t: f32) -> uifw.Color {
	j1, az1, bz1 := color_scheme_editor_srgb_to_jzazbz(a)
	j2, az2, bz2 := color_scheme_editor_srgb_to_jzazbz(b)
	return color_scheme_editor_jzazbz_to_srgb(
		j1 + (j2 - j1) * t,
		az1 + (az2 - az1) * t,
		bz1 + (bz2 - bz1) * t,
	)
}

color_scheme_editor_srgb_to_jzazbz :: proc(c: uifw.Color) -> (j, az, bz: f32) {
	x, y, z := color_scheme_editor_srgb_to_xyz(c)
	x_abs := max(x * 203, 0)
	y_abs := max(y * 203, 0)
	z_abs := max(z * 203, 0)

	xp := 1.15 * x_abs - 0.15 * z_abs
	yp := 0.66 * y_abs + 0.34 * x_abs

	l := color_scheme_editor_jzazbz_pq_encode(0.41478972 * xp + 0.579999 * yp + 0.014648 * z_abs)
	m := color_scheme_editor_jzazbz_pq_encode(-0.20151 * xp + 1.120649 * yp + 0.0531008 * z_abs)
	s := color_scheme_editor_jzazbz_pq_encode(-0.0166008 * xp + 0.2648 * yp + 0.6684799 * z_abs)
	i := (l + m) * 0.5

	j = (0.44 * i) / (1 - 0.56 * i) - COLOR_SCHEME_EDITOR_JZAZBZ_D0
	az = 3.524 * l - 4.066708 * m + 0.542708 * s
	bz = 0.199076 * l + 1.096799 * m - 1.295875 * s
	return
}

color_scheme_editor_jzazbz_to_srgb :: proc(j, az, bz: f32) -> uifw.Color {
	i := (j + COLOR_SCHEME_EDITOR_JZAZBZ_D0) / (0.44 + 0.56 * (j + COLOR_SCHEME_EDITOR_JZAZBZ_D0))
	l := color_scheme_editor_jzazbz_pq_decode(i + 0.13860504 * az + 0.058047316 * bz)
	m := color_scheme_editor_jzazbz_pq_decode(i - 0.13860504 * az - 0.058047316 * bz)
	s := color_scheme_editor_jzazbz_pq_decode(i - 0.096019242 * az - 0.8118919 * bz)

	return color_scheme_editor_xyz_to_srgb(
		(1.661373024652174 * l - 0.914523081304348 * m + 0.23136208173913045 * s) / 203,
		(-0.3250758611844533 * l + 1.571847026732543 * m - 0.21825383453227928 * s) / 203,
		(-0.090982811 * l - 0.31272829 * m + 1.5227666 * s) / 203,
	)
}

color_scheme_editor_jzazbz_pq_encode :: proc(value: f32) -> f32 {
	if value < 0 {
		return 0
	}
	vn := math.pow(value / 10000, COLOR_SCHEME_EDITOR_JZAZBZ_M1)
	return math.pow((COLOR_SCHEME_EDITOR_JZAZBZ_C1 + COLOR_SCHEME_EDITOR_JZAZBZ_C2 * vn) / (1 + COLOR_SCHEME_EDITOR_JZAZBZ_C3 * vn), COLOR_SCHEME_EDITOR_JZAZBZ_P)
}

color_scheme_editor_jzazbz_pq_decode :: proc(value: f32) -> f32 {
	if value < 0 {
		return 0
	}
	vp := math.pow(value, 1.0 / COLOR_SCHEME_EDITOR_JZAZBZ_P)
	denom := COLOR_SCHEME_EDITOR_JZAZBZ_C3 * vp - COLOR_SCHEME_EDITOR_JZAZBZ_C2
	if math.abs(denom) <= 0.000000001 {
		return 0
	}
	ratio := (COLOR_SCHEME_EDITOR_JZAZBZ_C1 - vp) / denom
	return 10000 * math.pow(max(ratio, 0), 1.0 / COLOR_SCHEME_EDITOR_JZAZBZ_M1)
}

color_scheme_editor_interpolate_lab :: proc(a, b: uifw.Color, t: f32) -> uifw.Color {
	l1, a1, b1 := color_scheme_editor_srgb_to_lab(a)
	l2, a2, b2 := color_scheme_editor_srgb_to_lab(b)
	return color_scheme_editor_lab_to_srgb(
		l1 + (l2 - l1) * t,
		a1 + (a2 - a1) * t,
		b1 + (b2 - b1) * t,
	)
}

color_scheme_editor_srgb_to_lab :: proc(c: uifw.Color) -> (l, a, b: f32) {
	x, y, z := color_scheme_editor_srgb_to_xyz(c)
	fx := color_scheme_editor_lab_f(x / 0.95047)
	fy := color_scheme_editor_lab_f(y)
	fz := color_scheme_editor_lab_f(z / 1.08883)
	l = 116 * fy - 16
	a = 500 * (fx - fy)
	b = 200 * (fy - fz)
	return
}

color_scheme_editor_lab_to_srgb :: proc(l, a, b: f32) -> uifw.Color {
	fy := (l + 16) / 116
	fx := a / 500 + fy
	fz := fy - b / 200
	x := 0.95047 * color_scheme_editor_lab_f_inv(fx)
	y := color_scheme_editor_lab_f_inv(fy)
	z := 1.08883 * color_scheme_editor_lab_f_inv(fz)
	return color_scheme_editor_xyz_to_srgb(x, y, z)
}

COLOR_SCHEME_EDITOR_HSLUV_REF_U :: f32(0.19783000664283)
COLOR_SCHEME_EDITOR_HSLUV_REF_V :: f32(0.46831999493879)
COLOR_SCHEME_EDITOR_HSLUV_EPSILON :: f32(216.0 / 24389.0)
COLOR_SCHEME_EDITOR_HSLUV_KAPPA :: f32(24389.0 / 27.0)

color_scheme_editor_interpolate_hsluv :: proc(a, b: uifw.Color, t: f32) -> uifw.Color {
	h1, s1, l1 := color_scheme_editor_srgb_to_hsluv(a)
	h2, s2, l2 := color_scheme_editor_srgb_to_hsluv(b)
	h2 = color_scheme_editor_hue_fixup_shorter(h1, h2)
	return color_scheme_editor_hsluv_to_srgb(
		h1 + (h2 - h1) * t,
		s1 + (s2 - s1) * t,
		l1 + (l2 - l1) * t,
	)
}

color_scheme_editor_srgb_to_hsluv :: proc(c: uifw.Color) -> (h, s, l: f32) {
	x, y, z := color_scheme_editor_srgb_to_xyz(c)
	l = color_scheme_editor_hsluv_y_to_l(y)
	denom := x + 15 * y + 3 * z
	if l <= 0.00000001 || math.abs(denom) <= 0.00000001 {
		return
	}

	up := 4 * x / denom
	vp := 9 * y / denom
	u := 13 * l * (up - COLOR_SCHEME_EDITOR_HSLUV_REF_U)
	v := 13 * l * (vp - COLOR_SCHEME_EDITOR_HSLUV_REF_V)
	chroma := math.sqrt(u * u + v * v)
	if chroma <= 0.00000001 || l >= 99.9999999 {
		return
	}

	h = color_scheme_editor_normalize_degrees(math.atan2(v, u) * 180 / math.PI)
	max_chroma := color_scheme_editor_hsluv_max_chroma_for_lh(l, h)
	if max_chroma > 0 {
		s = chroma / max_chroma * 100
	}
	return
}

color_scheme_editor_hsluv_to_srgb :: proc(h, s, l: f32) -> uifw.Color {
	chroma: f32
	if l > 0.00000001 && l < 99.9999999 && s > 0 {
		chroma = color_scheme_editor_hsluv_max_chroma_for_lh(l, h) * s / 100
	}
	u := chroma * math.cos(h * math.PI / 180)
	v := chroma * math.sin(h * math.PI / 180)
	return color_scheme_editor_luv_to_srgb(l, u, v)
}

color_scheme_editor_luv_to_srgb :: proc(l, u, v: f32) -> uifw.Color {
	if l <= 0.00000001 {
		return {0, 0, 0, 1}
	}
	up := u / (13 * l) + COLOR_SCHEME_EDITOR_HSLUV_REF_U
	vp := v / (13 * l) + COLOR_SCHEME_EDITOR_HSLUV_REF_V
	if math.abs(vp) <= 0.00000001 {
		return {0, 0, 0, 1}
	}
	y := color_scheme_editor_hsluv_l_to_y(l)
	x := (y * 9 * up) / (4 * vp)
	z := (y * (12 - 3 * up - 20 * vp)) / (4 * vp)
	return color_scheme_editor_xyz_to_srgb(x, y, z)
}

color_scheme_editor_hsluv_y_to_l :: proc(y: f32) -> f32 {
	if y <= COLOR_SCHEME_EDITOR_HSLUV_EPSILON {
		return y * COLOR_SCHEME_EDITOR_HSLUV_KAPPA
	}
	return 116 * color_scheme_editor_cbrt(y) - 16
}

color_scheme_editor_hsluv_l_to_y :: proc(l: f32) -> f32 {
	if l <= 8 {
		return l / COLOR_SCHEME_EDITOR_HSLUV_KAPPA
	}
	return math.pow((l + 16) / 116, 3)
}

color_scheme_editor_hsluv_max_chroma_for_lh :: proc(l, h: f32) -> f32 {
	sub1 := math.pow(l + 16, 3) / 1560896
	sub2 := sub1 > COLOR_SCHEME_EDITOR_HSLUV_EPSILON ? sub1 : l / COLOR_SCHEME_EDITOR_HSLUV_KAPPA
	h_rad := h * math.PI / 180
	min_length := f32(1.0e30)

	for channel in 0 ..< 3 {
		m1, m2, m3 := color_scheme_editor_hsluv_rgb_matrix_row(channel)
		for t in 0 ..< 2 {
			t_float := f32(t)
			top1 := (284517 * m1 - 94839 * m3) * sub2
			top2 := (838422 * m3 + 769860 * m2 + 731718 * m1) * l * sub2 - 769860 * t_float * l
			bottom := (632260 * m3 - 126452 * m2) * sub2 + 126452 * t_float
			if math.abs(bottom) <= 0.00000001 {
				continue
			}
			slope := top1 / bottom
			intercept := top2 / bottom
			divider := math.sin(h_rad) - slope * math.cos(h_rad)
			if math.abs(divider) <= 0.00000001 {
				continue
			}
			length := intercept / divider
			if length >= 0 && length < min_length {
				min_length = length
			}
		}
	}

	if min_length == f32(1.0e30) {
		return 0
	}
	return min_length
}

color_scheme_editor_hsluv_rgb_matrix_row :: proc(channel: int) -> (m1, m2, m3: f32) {
	switch channel {
	case 0:
		return 3.240969941904521, -1.537383177570093, -0.498610760293
	case 1:
		return -0.96924363628087, 1.87596750150772, 0.041555057407175
	}
	return 0.055630079696993, -0.20397695888897, 1.056971514242878
}

color_scheme_editor_hue_fixup_shorter :: proc(base, next: f32) -> f32 {
	base_normal := color_scheme_editor_normalize_degrees(base)
	next_normal := color_scheme_editor_normalize_degrees(next)
	delta := next_normal - base_normal
	if math.abs(delta) <= 180 {
		return next_normal
	}
	if delta > 0 {
		return next_normal - 360
	}
	return next_normal + 360
}

color_scheme_editor_normalize_degrees :: proc(value: f32) -> f32 {
	result := value
	for result < 0 {
		result += 360
	}
	for result >= 360 {
		result -= 360
	}
	return result
}

color_scheme_editor_srgb_to_xyz :: proc(c: uifw.Color) -> (x, y, z: f32) {
	r := color_scheme_editor_srgb_to_linear(c.r)
	g := color_scheme_editor_srgb_to_linear(c.g)
	b := color_scheme_editor_srgb_to_linear(c.b)
	x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b
	y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
	z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b
	return
}

color_scheme_editor_xyz_to_srgb :: proc(x, y, z: f32) -> uifw.Color {
	r := 3.2404542 * x - 1.5371385 * y - 0.4985314 * z
	g := -0.9692660 * x + 1.8760108 * y + 0.0415560 * z
	b := 0.0556434 * x - 0.2040259 * y + 1.0572252 * z
	return {
		r = uifw.gui_clamp01(color_scheme_editor_linear_to_srgb(r)),
		g = uifw.gui_clamp01(color_scheme_editor_linear_to_srgb(g)),
		b = uifw.gui_clamp01(color_scheme_editor_linear_to_srgb(b)),
		a = 1,
	}
}

color_scheme_editor_lab_f :: proc(t: f32) -> f32 {
	epsilon := f32(216.0 / 24389.0)
	kappa := f32(24389.0 / 27.0)
	if t > epsilon {
		return color_scheme_editor_cbrt(t)
	}
	return (kappa * t + 16) / 116
}

color_scheme_editor_lab_f_inv :: proc(t: f32) -> f32 {
	epsilon := f32(216.0 / 24389.0)
	kappa := f32(24389.0 / 27.0)
	cube := t * t * t
	if cube > epsilon {
		return cube
	}
	return (116 * t - 16) / kappa
}

color_scheme_editor_srgb_to_linear :: proc(value: f32) -> f32 {
	v := uifw.gui_clamp01(value)
	if v <= 0.04045 {
		return v / 12.92
	}
	return math.pow((v + 0.055) / 1.055, 2.4)
}

color_scheme_editor_linear_to_srgb :: proc(value: f32) -> f32 {
	if value <= 0.0031308 {
		return value * 12.92
	}
	return 1.055 * math.pow(max(value, 0), 1.0 / 2.4) - 0.055
}

color_scheme_editor_cbrt :: proc(value: f32) -> f32 {
	if value < 0 {
		return -math.pow(-value, 1.0 / 3.0)
	}
	return math.pow(value, 1.0 / 3.0)
}

color_scheme_editor_build_scheme :: proc(editor: ^Color_Scheme_Editor_State, name: string) -> Color_Scheme {
	scheme: Color_Scheme
	scheme.name = name
	for i in 0 ..< COLOR_SCHEME_SIZE {
		c := color_scheme_editor_color_at(editor, f32(i) / f32(COLOR_SCHEME_SIZE - 1))
		scheme.red[i] = u8(uifw.gui_clamp01(c.r) * 255 + 0.5)
		scheme.green[i] = u8(uifw.gui_clamp01(c.g) * 255 + 0.5)
		scheme.blue[i] = u8(uifw.gui_clamp01(c.b) * 255 + 0.5)
	}
	return scheme
}

color_scheme_editor_randomize :: proc(editor: ^Color_Scheme_Editor_State) {
	count := max(min(int(editor.random_stop_count + 0.5), COLOR_SCHEME_EDITOR_MAX_STOPS), 2)
	editor.stop_count = count
	for i in 0 ..< count {
		position := count == 1 ? f32(0) : f32(i) / f32(count - 1)
		if editor.random_placement_index == 0 && i > 0 && i < count - 1 {
			position = 0.1 + color_scheme_editor_rand01(editor) * 0.8
		}
		editor.stops[i] = {
			position = position,
			color = color_scheme_editor_random_color(editor, editor.random_scheme_index, i),
		}
	}
	color_scheme_editor_sort_stops(editor)
	editor.selected_stop = 0
	editor.selected_hsv = uifw.gui_rgb_to_hsv(editor.stops[0].color)
}

color_scheme_editor_random_color :: proc(editor: ^Color_Scheme_Editor_State, scheme, index: int) -> uifw.Color {
	switch scheme {
	case 0:
		return color_scheme_editor_palette_color(index, []string{"#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff", "#ff8000", "#8000ff"})
	case 1:
		return color_scheme_editor_palette_color(index, []string{"#ff4500", "#ff6347", "#ffa500", "#ff8c00", "#dc143c", "#b22222", "#cd853f", "#d2691e"})
	case 2:
		return color_scheme_editor_palette_color(index, []string{"#4169e1", "#0000cd", "#1e90ff", "#00bfff", "#87ceeb", "#20b2aa", "#008b8b", "#4682b4"})
	case 3:
		return color_scheme_editor_palette_color(index, []string{"#ffb3ba", "#ffdfba", "#ffffba", "#baffc9", "#bae1ff", "#e6baff", "#ffc9ba", "#c9baff"})
	case 4:
		return color_scheme_editor_palette_color(index, []string{"#ff073a", "#39ff14", "#00ffff", "#ff00ff", "#ffff00", "#ff4500", "#8a2be2", "#00ff7f"})
	case 5:
		return color_scheme_editor_palette_color(index, []string{"#8b4513", "#a0522d", "#cd853f", "#daa520", "#b8860b", "#9acd32", "#6b8e23", "#556b2f"})
	case 6:
		base := color_scheme_editor_rand01(editor)
		return uifw.gui_hsv_to_rgb({h = base, s = 0.5 + color_scheme_editor_rand01(editor) * 0.5, v = 0.2 + color_scheme_editor_rand01(editor) * 0.6, a = 1})
	case 7:
		h := color_scheme_editor_rand01(editor)
		if index % 2 == 1 {
			h = h + 0.5
		}
		return uifw.gui_hsv_to_rgb({h = h, s = 0.65 + color_scheme_editor_rand01(editor) * 0.25, v = 0.35 + color_scheme_editor_rand01(editor) * 0.5, a = 1})
	}
	return {color_scheme_editor_rand01(editor), color_scheme_editor_rand01(editor), color_scheme_editor_rand01(editor), 1}
}

color_scheme_editor_palette_color :: proc(index: int, colors: []string) -> uifw.Color {
	return color_scheme_editor_hex_to_color(colors[index % len(colors)])
}

color_scheme_editor_rand01 :: proc(editor: ^Color_Scheme_Editor_State) -> f32 {
	editor.seed = editor.seed * 1664525 + 1013904223
	return f32(editor.seed & 0x00ffffff) / f32(0x01000000)
}

color_scheme_editor_hex_to_color :: proc(hex: string) -> uifw.Color {
	if len(hex) < 7 {
		return {1, 1, 1, 1}
	}
	r := color_scheme_editor_hex_byte(hex[1], hex[2])
	g := color_scheme_editor_hex_byte(hex[3], hex[4])
	b := color_scheme_editor_hex_byte(hex[5], hex[6])
	return {f32(r) / 255, f32(g) / 255, f32(b) / 255, 1}
}

color_scheme_editor_hex_byte :: proc(a, b: u8) -> u8 {
	return u8(color_scheme_editor_hex_nibble(a) * 16 + color_scheme_editor_hex_nibble(b))
}

color_scheme_editor_hex_nibble :: proc(ch: u8) -> int {
	if ch >= '0' && ch <= '9' {
		return int(ch - '0')
	}
	if ch >= 'a' && ch <= 'f' {
		return int(ch - 'a') + 10
	}
	if ch >= 'A' && ch <= 'F' {
		return int(ch - 'A') + 10
	}
	return 0
}

color_scheme_editor_sanitized_name :: proc(editor: ^Color_Scheme_Editor_State) -> string {
	out: [COLOR_SCHEME_NAME_MAX]u8
	cursor := 0
	for ch in editor.name[:editor.name_len] {
		if cursor >= len(out) - 1 {
			break
		}
		if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '_' || ch == '-' || ch == ' ' || ch == '\'' || ch == '!' {
			out[cursor] = ch
			cursor += 1
		} else if ch == '/' || ch == '\\' || ch == ':' {
			out[cursor] = '_'
			cursor += 1
		}
	}
	for cursor > 0 && out[cursor - 1] == ' ' {
		cursor -= 1
	}
	cloned, err := strings.clone(string(out[:cursor]), context.temp_allocator)
	if err != nil {
		return ""
	}
	return cloned
}
