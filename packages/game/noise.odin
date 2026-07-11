package game

import "core:math"
import math_noise "core:math/noise"

NOISE_KIND_NAMES := [?]string{"Billow", "Gabor", "Perlin", "Phasor", "Ridged", "Simplex", "Value", "Voronoi", "Wave", "White", "Cylinders", "Checkerboard"}
NOISE_FRACTAL_MODE_NAMES := [?]string{"Single", "FBM", "Ridged"}
NOISE_WARP_MODE_NAMES := [?]string{"None", "Fixed", "Recursive"}
NOISE_CELLULAR_OUTPUT_NAMES := [?]string{"Distance F1", "Distance F2", "Distance F2 - F1", "Cell Value", "Edge"}
NOISE_CELLULAR_DISTANCE_MODE_NAMES := [?]string{"Euclidean", "Manhattan", "Chebyshev"}

Noise_Kind :: enum int {
	Billow,
	Gabor,
	Perlin,
	Phasor,
	Ridged,
	Simplex,
	Value,
	Voronoi,
	Wave,
	White,
	Cylinders,
	Checkerboard,
}

Noise_Fractal_Mode :: enum int {
	Single,
	FBM,
	Ridged,
}

Noise_Warp_Mode :: enum int {
	None,
	Fixed,
	Recursive,
}

Noise_Cellular_Output :: enum int {
	Distance_F1,
	Distance_F2,
	Distance_F2_Minus_F1,
	Cell_Value,
	Edge,
}

Noise_Cellular_Distance_Mode :: enum int {
	Euclidean,
	Manhattan,
	Chebyshev,
}

Noise_Gabor_Settings :: struct {
	iterations: u32,
	velocity: f32,
	band_width: f32,
	band_softness: f32,
}

Noise_Phasor_Settings :: struct {
	iterations: u32,
	velocity: f32,
	band_width: f32,
}

Noise_Voronoi_Settings :: struct {
	output: Noise_Cellular_Output,
	distance_mode: Noise_Cellular_Distance_Mode,
	output_index: int,
	distance_mode_index: int,
}

Noise_Wave_Settings :: struct {
	velocity: f32,
	band_width: f32,
	band_softness: f32,
}

Noise_Settings :: struct {
	seed: u32,
	offset_x: f32,
	offset_y: f32,
	rotation: f32,
	anchor_x: f32,
	anchor_y: f32,
	kind: Noise_Kind,
	kind_index: int,
	noise_strength: f32,
	amplitude: f32,
	frequency: f32,
	fractal_mode: Noise_Fractal_Mode,
	fractal_mode_index: int,
	octaves: u32,
	lacunarity: f32,
	gain: f32,
	warp_mode: Noise_Warp_Mode,
	warp_mode_index: int,
	warp_octaves: u32,
	warp_amplitude: f32,
	warp_frequency: f32,
	gabor: Noise_Gabor_Settings,
	phasor: Noise_Phasor_Settings,
	voronoi: Noise_Voronoi_Settings,
	wave: Noise_Wave_Settings,
	base_open: bool,
	placement_open: bool,
	noise_open: bool,
	fractal_open: bool,
	warp_open: bool,
}

noise_settings_default :: proc(kind: Noise_Kind = .Simplex) -> Noise_Settings {
	settings := Noise_Settings {
		seed = 0,
		kind = kind,
		kind_index = int(kind),
		noise_strength = 1.0,
		amplitude = 1.0,
		frequency = 1.0,
		fractal_mode = .Single,
		fractal_mode_index = int(Noise_Fractal_Mode.Single),
		octaves = 6,
		lacunarity = 2.0,
		gain = 0.5,
		warp_mode = .None,
		warp_mode_index = int(Noise_Warp_Mode.None),
		warp_octaves = 3,
		warp_amplitude = 0.25,
		warp_frequency = 1.0,
		gabor = {iterations = 50, velocity = 1.0, band_width = 0.01, band_softness = 1.0},
		phasor = {iterations = 50, velocity = 1.0, band_width = 0.01},
		voronoi = {output = .Distance_F1, distance_mode = .Euclidean, output_index = int(Noise_Cellular_Output.Distance_F1), distance_mode_index = int(Noise_Cellular_Distance_Mode.Euclidean)},
		wave = {velocity = 1.0, band_width = 1.0, band_softness = 1.0},
		base_open = true,
		placement_open = false,
		noise_open = true,
		fractal_open = true,
		warp_open = true,
	}
	return settings
}

noise_kind_from_name :: proc(name: string, out: ^Noise_Kind) -> bool {
	for i in 0 ..< len(NOISE_KIND_NAMES) {
		if name == NOISE_KIND_NAMES[i] {
			out^ = Noise_Kind(i)
			return true
		}
	}
	return false
}

noise_kind_from_legacy_name :: proc(name: string, out: ^Noise_Kind, fractal: ^Noise_Fractal_Mode) -> bool {
	if noise_kind_from_name(name, out) {
		return true
	}
	switch name {
	case "OpenSimplex", "Simplex":
		out^ = .Simplex
	case "Worley", "Voronoi_F1", "Voronoi F1":
		out^ = .Voronoi
		if fractal != nil {fractal^ = .Single}
	case "Fbm", "FBM":
		out^ = .Simplex
		if fractal != nil {fractal^ = .FBM}
	case "FBMBillow", "FBM_Billow", "FBM Billow":
		out^ = .Billow
		if fractal != nil {fractal^ = .FBM}
	case "FBMClouds", "FBM_Clouds", "FBM Clouds":
		out^ = .Simplex
		if fractal != nil {fractal^ = .FBM}
	case "FBMRidged", "FBM_Ridged", "FBM Ridged", "Ridged Multi", "Ridged_Multi":
		out^ = .Simplex
		if fractal != nil {fractal^ = .Ridged}
	case:
		return false
	}
	return true
}

noise_fractal_mode_from_name :: proc(name: string, out: ^Noise_Fractal_Mode) -> bool {
	for i in 0 ..< len(NOISE_FRACTAL_MODE_NAMES) {
		if name == NOISE_FRACTAL_MODE_NAMES[i] {
			out^ = Noise_Fractal_Mode(i)
			return true
		}
	}
	return false
}

noise_warp_mode_from_name :: proc(name: string, out: ^Noise_Warp_Mode) -> bool {
	for i in 0 ..< len(NOISE_WARP_MODE_NAMES) {
		if name == NOISE_WARP_MODE_NAMES[i] {
			out^ = Noise_Warp_Mode(i)
			return true
		}
	}
	return false
}

noise_cellular_output_from_name :: proc(name: string, out: ^Noise_Cellular_Output) -> bool {
	for i in 0 ..< len(NOISE_CELLULAR_OUTPUT_NAMES) {
		if name == NOISE_CELLULAR_OUTPUT_NAMES[i] {
			out^ = Noise_Cellular_Output(i)
			return true
		}
	}
	switch name {
	case "Distance_F1", "DistanceF1":
		out^ = .Distance_F1
	case "Distance_F2", "DistanceF2":
		out^ = .Distance_F2
	case "Distance_F2_Minus_F1", "Distance F2 Minus F1", "DistanceF2MinusF1":
		out^ = .Distance_F2_Minus_F1
	case "Cell_Value", "CellValue":
		out^ = .Cell_Value
	case:
		return false
	}
	return true
}

noise_cellular_distance_mode_from_name :: proc(name: string, out: ^Noise_Cellular_Distance_Mode) -> bool {
	for i in 0 ..< len(NOISE_CELLULAR_DISTANCE_MODE_NAMES) {
		if name == NOISE_CELLULAR_DISTANCE_MODE_NAMES[i] {
			out^ = Noise_Cellular_Distance_Mode(i)
			return true
		}
	}
	return false
}

noise_sync_indices :: proc(settings: ^Noise_Settings) {
	settings.kind_index = int(settings.kind)
	settings.fractal_mode_index = int(settings.fractal_mode)
	settings.warp_mode_index = int(settings.warp_mode)
	settings.voronoi.output_index = int(settings.voronoi.output)
	settings.voronoi.distance_mode_index = int(settings.voronoi.distance_mode)
}

noise_sample_2d :: proc(settings: ^Noise_Settings, x, y: f32, t: f32 = 0) -> f32 {
	p := noise_transform_position(settings, x, y)
	return noise_sample_transformed_2d(settings, p, t)
}

// Samples coordinates that already have placement frequency, rotation, anchor,
// and offset applied. Dense renderers can hoist the invariant transform out of
// their inner loop instead of recomputing sin/cos for every sample.
noise_sample_transformed_2d :: proc(settings: ^Noise_Settings, p: [2]f32, t: f32 = 0) -> f32 {
	warped := noise_apply_domain_warp(settings, p, t)
	v: f32
	if settings.fractal_mode == .Single {
		v = noise_sample_kind(settings, warped, t, settings.seed)
	} else {
		v = noise_sample_fractal(settings, warped, t)
	}
	v = math.clamp(v * settings.amplitude * settings.noise_strength, -1, 1)
	return v
}

noise_sample01_transformed_2d :: proc(settings: ^Noise_Settings, p: [2]f32, t: f32 = 0) -> f32 {
	return math.clamp(noise_sample_transformed_2d(settings, p, t) * 0.5 + 0.5, 0, 1)
}

noise_sample01_2d :: proc(settings: ^Noise_Settings, x, y: f32, t: f32 = 0) -> f32 {
	return math.clamp(noise_sample_2d(settings, x, y, t) * 0.5 + 0.5, 0, 1)
}

noise_transform_position :: proc(settings: ^Noise_Settings, x, y: f32) -> [2]f32 {
	px := (x - settings.anchor_x) * max(settings.frequency, 0.000001)
	py := (y - settings.anchor_y) * max(settings.frequency, 0.000001)
	c := math.cos(settings.rotation)
	s := math.sin(settings.rotation)
	return {
		px * c - py * s + settings.anchor_x + settings.offset_x,
		px * s + py * c + settings.anchor_y + settings.offset_y,
	}
}

noise_apply_domain_warp :: proc(settings: ^Noise_Settings, p: [2]f32, t: f32) -> [2]f32 {
	if settings.warp_mode == .None || settings.warp_amplitude == 0 {
		return p
	}
	out := p
	source := p
	octaves := min(max(settings.warp_octaves, 1), 8)
	frequency := max(settings.warp_frequency, 0.000001)
	amplitude := settings.warp_amplitude
	for i: u32 = 0; i < octaves; i += 1 {
		wx := noise_perlin_2d(source[0] * frequency + 17.0, source[1] * frequency + t, settings.seed + i * 17 + 1013)
		wy := noise_perlin_2d(source[0] * frequency - t, source[1] * frequency - 31.0, settings.seed + i * 17 + 2027)
		out[0] += wx * amplitude
		out[1] += wy * amplitude
		if settings.warp_mode == .Recursive {
			source = out
		}
		frequency *= 2
		amplitude *= 0.5
	}
	return out
}

noise_sample_fractal :: proc(settings: ^Noise_Settings, p: [2]f32, t: f32) -> f32 {
	sum: f32
	amp: f32 = 1
	amp_sum: f32
	freq: f32 = 1
	octaves := min(max(settings.octaves, 1), 12)
	for i: u32 = 0; i < octaves; i += 1 {
		op := [2]f32{p[0] * freq, p[1] * freq}
		n := noise_sample_kind(settings, op, t * freq, settings.seed + i * 1009)
		if settings.fractal_mode == .Ridged {
			n = 1 - math.abs(n)
			n = n * 2 - 1
		}
		sum += n * amp
		amp_sum += amp
		freq *= max(settings.lacunarity, 0.000001)
		amp *= math.clamp(settings.gain, 0, 1)
	}
	if amp_sum <= 0 {
		return 0
	}
	return math.clamp(sum / amp_sum, -1, 1)
}

noise_sample_kind :: proc(settings: ^Noise_Settings, p: [2]f32, t: f32, seed: u32) -> f32 {
	#partial switch settings.kind {
	case .Billow:
		return math.abs(noise_simplex_2d(seed, p[0], p[1] + t * 0.1)) * 2 - 1
	case .Gabor:
		return noise_gabor_2d(settings, p, t, seed)
	case .Perlin:
		return noise_perlin_2d(p[0], p[1] + t * 0.1, seed)
	case .Phasor:
		return noise_phasor_2d(settings, p, t, seed)
	case .Ridged:
		return 1 - math.abs(noise_simplex_2d(seed, p[0], p[1] + t * 0.1)) * 2
	case .Simplex:
		return noise_simplex_2d(seed, p[0], p[1] + t * 0.1)
	case .Value:
		return noise_value_2d(p[0], p[1] + t * 0.1, seed)
	case .Voronoi:
		return noise_voronoi_2d(settings, p, seed)
	case .Wave:
		return noise_wave_2d(settings, p, t, seed)
	case .White:
		return noise_white_2d(p[0], p[1] + t * 0.1, seed)
	case .Cylinders:
		return noise_cylinders_2d(settings, p, t)
	case .Checkerboard:
		return noise_checkerboard_2d(p)
	case:
		return noise_simplex_2d(seed, p[0], p[1])
	}
}

noise_simplex_2d :: proc(seed: u32, x, y: f32) -> f32 {
	return math_noise.noise_2d(i64(seed), {f64(x), f64(y)})
}

noise_hash_u32 :: proc(v: u32) -> u32 {
	x := v
	x = ((x >> 16) ~ x) * 0x45d9f3b
	x = ((x >> 16) ~ x) * 0x45d9f3b
	x = (x >> 16) ~ x
	return x
}

noise_hash_coords :: proc(x, y: i32, seed: u32) -> u32 {
	return noise_hash_u32(u32(x) * 73856093 + u32(y) * 19349663 + seed)
}

noise_hash01 :: proc(v: u32) -> f32 {
	return f32(noise_hash_u32(v)) / f32(0xffffffff)
}

noise_hash_signed :: proc(v: u32) -> f32 {
	return noise_hash01(v) * 2 - 1
}

noise_floor_i32 :: proc(v: f32) -> i32 {
	return i32(math.floor(v))
}

noise_fade :: proc(t: f32) -> f32 {
	return t * t * t * (t * (t * 6 - 15) + 10)
}

noise_lerp :: proc(a, b, t: f32) -> f32 {
	return a + (b - a) * t
}

noise_grad2 :: proc(hash: u32, x, y: f32) -> f32 {
	switch hash & 7 {
	case 0: return x + y
	case 1: return -x + y
	case 2: return x - y
	case 3: return -x - y
	case 4: return x
	case 5: return -x
	case 6: return y
	case: return -y
	}
}

noise_perlin_2d :: proc(x, y: f32, seed: u32) -> f32 {
	xi := noise_floor_i32(x)
	yi := noise_floor_i32(y)
	xf := x - f32(xi)
	yf := y - f32(yi)
	u := noise_fade(xf)
	v := noise_fade(yf)
	n00 := noise_grad2(noise_hash_coords(xi, yi, seed), xf, yf)
	n10 := noise_grad2(noise_hash_coords(xi + 1, yi, seed), xf - 1, yf)
	n01 := noise_grad2(noise_hash_coords(xi, yi + 1, seed), xf, yf - 1)
	n11 := noise_grad2(noise_hash_coords(xi + 1, yi + 1, seed), xf - 1, yf - 1)
	x0 := noise_lerp(n00, n10, u)
	x1 := noise_lerp(n01, n11, u)
	return math.clamp(noise_lerp(x0, x1, v) * 0.70710678, -1, 1)
}

noise_value_2d :: proc(x, y: f32, seed: u32) -> f32 {
	xi := noise_floor_i32(x)
	yi := noise_floor_i32(y)
	xf := x - f32(xi)
	yf := y - f32(yi)
	u := noise_fade(xf)
	v := noise_fade(yf)
	n00 := noise_hash_signed(noise_hash_coords(xi, yi, seed))
	n10 := noise_hash_signed(noise_hash_coords(xi + 1, yi, seed))
	n01 := noise_hash_signed(noise_hash_coords(xi, yi + 1, seed))
	n11 := noise_hash_signed(noise_hash_coords(xi + 1, yi + 1, seed))
	return noise_lerp(noise_lerp(n00, n10, u), noise_lerp(n01, n11, u), v)
}

noise_white_2d :: proc(x, y: f32, seed: u32) -> f32 {
	return noise_hash_signed(noise_hash_coords(noise_floor_i32(x), noise_floor_i32(y), seed))
}

noise_voronoi_distance :: proc(dx, dy: f32, mode: Noise_Cellular_Distance_Mode) -> f32 {
	#partial switch mode {
	case .Manhattan:
		return math.abs(dx) + math.abs(dy)
	case .Chebyshev:
		return max(math.abs(dx), math.abs(dy))
	case:
		return math.sqrt(dx * dx + dy * dy)
	}
}

noise_voronoi_2d :: proc(settings: ^Noise_Settings, p: [2]f32, seed: u32) -> f32 {
	cell_x := noise_floor_i32(p[0])
	cell_y := noise_floor_i32(p[1])
	f1 := f32(1.0e9)
	f2 := f32(1.0e9)
	win_hash: u32
	for oy in -1 ..= 1 {
		for ox in -1 ..= 1 {
			cx := cell_x + i32(ox)
			cy := cell_y + i32(oy)
			h := noise_hash_coords(cx, cy, seed)
			fx := f32(cx) + noise_hash01(h)
			fy := f32(cy) + noise_hash01(h + 1013)
			d := noise_voronoi_distance(p[0] - fx, p[1] - fy, settings.voronoi.distance_mode)
			if d < f1 {
				f2 = f1
				f1 = d
				win_hash = h
			} else if d < f2 {
				f2 = d
			}
		}
	}
	#partial switch settings.voronoi.output {
	case .Distance_F2:
		return math.clamp(1 - f2, -1, 1)
	case .Distance_F2_Minus_F1:
		return math.clamp((f2 - f1) * 2 - 1, -1, 1)
	case .Cell_Value:
		return noise_hash_signed(win_hash)
	case .Edge:
		return math.clamp(1 - (f2 - f1) * 8, -1, 1)
	case:
		return math.clamp(1 - f1 * 2, -1, 1)
	}
}

noise_wave_2d :: proc(settings: ^Noise_Settings, p: [2]f32, t: f32, seed: u32) -> f32 {
	angle := settings.rotation
	if angle == 0 {
		angle = noise_hash01(seed + 71) * 2 * math.PI
	}
	dir := [2]f32{math.cos(angle), math.sin(angle)}
	phase := noise_hash01(seed + 131) * 2 * math.PI + t * settings.wave.velocity
	width := max(settings.wave.band_width, 0.0001)
	v := math.sin((p[0] * dir[0] + p[1] * dir[1]) * 2 * math.PI / width + phase)
	if settings.wave.band_softness != 1 {
		v = math.sign(v) * math.pow(math.abs(v), max(settings.wave.band_softness, 0.0001))
	}
	return v
}

noise_gabor_2d :: proc(settings: ^Noise_Settings, p: [2]f32, t: f32, seed: u32) -> f32 {
	iterations := min(max(settings.gabor.iterations, 1), 96)
	sum: f32
	softness := max(settings.gabor.band_softness, 0.0001)
	width := max(settings.gabor.band_width, 0.0001)
	for i: u32 = 0; i < iterations; i += 1 {
		h := noise_hash_u32(seed + i * 374761393)
		cx := noise_hash_signed(h) * 6
		cy := noise_hash_signed(h + 1013) * 6
		angle := noise_hash01(h + 2027) * 2 * math.PI
		dir := [2]f32{math.cos(angle), math.sin(angle)}
		dx := p[0] - cx
		dy := p[1] - cy
		envelope := math.exp(-(dx * dx + dy * dy) * softness)
		carrier := math.cos((dx * dir[0] + dy * dir[1]) * 2 * math.PI / width + t * settings.gabor.velocity + noise_hash01(h + 3037) * 2 * math.PI)
		sum += envelope * carrier
	}
	return math.clamp(sum / math.sqrt(f32(iterations)), -1, 1)
}

noise_phasor_2d :: proc(settings: ^Noise_Settings, p: [2]f32, t: f32, seed: u32) -> f32 {
	iterations := min(max(settings.phasor.iterations, 1), 96)
	acc_x: f32
	acc_y: f32
	width := max(settings.phasor.band_width, 0.0001)
	for i: u32 = 0; i < iterations; i += 1 {
		h := noise_hash_u32(seed + i * 668265263)
		angle := noise_hash01(h) * 2 * math.PI
		dir := [2]f32{math.cos(angle), math.sin(angle)}
		phase := (p[0] * dir[0] + p[1] * dir[1]) * 2 * math.PI / width + t * settings.phasor.velocity + noise_hash01(h + 1013) * 2 * math.PI
		weight := 0.5 + 0.5 * noise_hash01(h + 2027)
		acc_x += math.cos(phase) * weight
		acc_y += math.sin(phase) * weight
	}
	return math.atan2(acc_y, acc_x) / math.PI
}

noise_cylinders_2d :: proc(settings: ^Noise_Settings, p: [2]f32, t: f32) -> f32 {
	dx := p[0] - settings.anchor_x
	dy := p[1] - settings.anchor_y
	return math.sin(math.sqrt(dx * dx + dy * dy) * 2 * math.PI + t)
}

noise_checkerboard_2d :: proc(p: [2]f32) -> f32 {
	return (((noise_floor_i32(p[0]) ~ noise_floor_i32(p[1])) & 1) == 0) ? f32(-1) : f32(1)
}
