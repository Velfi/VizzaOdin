package render_vk

import uifw "zelda_engine:ui"
import engine "zelda_engine:engine"

import vk "vendor:vulkan"
import "core:bytes"
import "core:fmt"
import "core:math"
import png "core:image/png"

ui_renderer_texture_index :: proc(renderer: ^Ui_Renderer, id: uifw.Gui_Image_Id) -> u32 {
	index := int(id)
	if index <= 0 || index >= UI_MAX_TEXTURES || !renderer.textures[index].ready {
		return 0
	}
	return u32(index)
}

ui_renderer_font_atlas_for_scale :: proc(renderer: ^Ui_Renderer, ctx: ^Vk_Context, font_kind: uifw.Gui_Font_Kind, scale: f32) -> ^Ui_Font_Atlas_Cache_Entry {
	if renderer == nil || ctx == nil || UI_FONT_TEXTURE_COUNT <= 0 {
		return nil
	}
	text_scale := scale
	if text_scale <= 0 {
		text_scale = 1
	}
	pixel_height := u32(max(math.ceil(f32(UI_FONT_LOGICAL_HEIGHT) * text_scale), 1))
	renderer.font_atlas_generation += 1
	if renderer.font_atlas_generation == 0 {
		renderer.font_atlas_generation = 1
		for i in 0 ..< len(renderer.font_atlases) {
			renderer.font_atlases[i].generation = 0
		}
	}

	for i in 0 ..< len(renderer.font_atlases) {
		entry := &renderer.font_atlases[i]
		if entry.ready && entry.font_kind == font_kind && entry.pixel_height == pixel_height {
			entry.generation = renderer.font_atlas_generation
			return entry
		}
	}

	slot := 0
	oldest_generation := renderer.font_atlases[0].generation
	for i in 0 ..< len(renderer.font_atlases) {
		entry := &renderer.font_atlases[i]
		if !entry.ready {
			slot = i
			break
		}
		if entry.generation < oldest_generation {
			slot = i
			oldest_generation = entry.generation
		}
	}

	entry := &renderer.font_atlases[slot]
	texture_index := UI_FONT_TEXTURE_FIRST_ID + slot
	cell_height := pixel_height
	cell_width := u32(max(math.ceil(f32(pixel_height) * f32(UI_FONT_ATLAS_LOGICAL_WIDTH) / f32(UI_FONT_LOGICAL_HEIGHT)), 1))
	columns := u32(UI_FONT_ATLAS_COLUMNS)
	rows := u32((UI_FONT_GLYPH_COUNT + UI_FONT_ATLAS_COLUMNS - 1) / UI_FONT_ATLAS_COLUMNS)
	atlas_width := cell_width * columns
	atlas_height := cell_height * rows
	byte_count := int(atlas_width * atlas_height * 4)
	rgba := make([]u8, byte_count, context.temp_allocator)
	defer delete(rgba, context.temp_allocator)
	if !uifw.gui_font_render_ascii_atlas(font_kind, UI_FONT_GLYPH_FIRST, UI_FONT_GLYPH_FIRST + UI_FONT_GLYPH_COUNT - 1, int(pixel_height), int(cell_width), int(cell_height), int(columns), rgba) {
		log_warn("ui_renderer_font_atlas_for_scale: font atlas rasterization failed height=", pixel_height)
		return nil
	}
	if !ui_renderer_create_owned_texture(renderer, ctx, texture_index, atlas_width, atlas_height, rgba) {
		log_warn("ui_renderer_font_atlas_for_scale: font atlas upload failed height=", pixel_height, " atlas=", atlas_width, "x", atlas_height)
		return nil
	}

	entry^ = {
		font_kind = font_kind,
		pixel_height = pixel_height,
		cell_width = cell_width,
		cell_height = cell_height,
		atlas_width = atlas_width,
		atlas_height = atlas_height,
		columns = columns,
		rows = rows,
		texture_index = u32(texture_index),
		generation = renderer.font_atlas_generation,
		ready = true,
	}
	return entry
}

ui_renderer_blend_index :: proc(mode: uifw.Gui_Blend_Mode) -> u32 {
	switch mode {
	case .Alpha:
		return 0
	case .Add:
		return 1
	case .Multiply:
		return 2
	case .Screen:
		return 3
	}
	return 0
}

ui_renderer_active_frame_slot :: proc(ctx: ^Vk_Context) -> u32 {
	if ctx == nil {
		return 0
	}
	return ctx.current_frame % MAX_FRAMES_IN_FLIGHT
}

ui_renderer_add_batch :: proc(renderer: ^Ui_Renderer, first, count, texture_index, blend_mode: u32, glass: bool) {
	if count == 0 {
		return
	}
	if renderer.batch_count > 0 {
		last := &renderer.batches[renderer.batch_count - 1]
		if last.texture_index == texture_index && last.blend_mode == blend_mode && last.glass == glass && last.first_vertex + last.vertex_count == first {
			last.vertex_count += count
			return
		}
	}
	if renderer.batch_count >= UI_MAX_DRAW_BATCHES {
		return
	}
	renderer.batches[renderer.batch_count] = {first_vertex = first, vertex_count = count, texture_index = texture_index, blend_mode = blend_mode, glass = glass}
	renderer.batch_count += 1
}

ui_push_stroke :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, color: uifw.Color, width: f32, scissor: uifw.Rect, extent: vk.Extent2D) {
	w := max(width, UI_STROKE_WIDTH)
	ui_push_rect(out, count, {rect.x, rect.y, rect.w, w}, color, scissor, extent)
	ui_push_rect(out, count, {rect.x, rect.y + rect.h - w, rect.w, w}, color, scissor, extent)
	ui_push_rect(out, count, {rect.x, rect.y, w, rect.h}, color, scissor, extent)
	ui_push_rect(out, count, {rect.x + rect.w - w, rect.y, w, rect.h}, color, scissor, extent)
}

ui_push_clear_stroke :: proc(out: []Ui_Clear_Rect, count: ^int, rect: uifw.Rect, color: uifw.Color, width: f32, scissor: uifw.Rect) {
	w := max(width, UI_STROKE_WIDTH)
	ui_push_clear_rect(out, count, {rect.x, rect.y, rect.w, w}, color, scissor)
	ui_push_clear_rect(out, count, {rect.x, rect.y + rect.h - w, rect.w, w}, color, scissor)
	ui_push_clear_rect(out, count, {rect.x, rect.y, w, rect.h}, color, scissor)
	ui_push_clear_rect(out, count, {rect.x + rect.w - w, rect.y, w, rect.h}, color, scissor)
}

ui_push_rounded_rect :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, radius: f32, color: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	r := min(max(radius, 0), min(clipped.w, clipped.h) * 0.5)
	if r <= 0.5 {
		ui_push_rect(out, count, clipped, color, scissor, extent)
		return
	}

	points: [32]uifw.Vec2
	n := ui_rounded_rect_points(points[:], clipped, r)
	center := uifw.Vec2{clipped.x + clipped.w * 0.5, clipped.y + clipped.h * 0.5}
	for i in 0 ..< n {
		j := (i + 1) % n
		ui_push_triangle_screen(out, count, center, points[i], points[j], color, color, color, extent)
	}
}

ui_push_rounded_stroke :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, radius, width: f32, color: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	w := min(max(width, UI_STROKE_WIDTH), min(clipped.w, clipped.h) * 0.5)
	r := min(max(radius, 0), min(clipped.w, clipped.h) * 0.5)
	if r <= 0.5 {
		ui_push_stroke(out, count, clipped, color, w, scissor, extent)
		return
	}

	inner := uifw.Rect{clipped.x + w, clipped.y + w, max(clipped.w - w * 2, 0), max(clipped.h - w * 2, 0)}
	inner_r := max(r - w, 0)
	outer_points: [32]uifw.Vec2
	inner_points: [32]uifw.Vec2
	n := ui_rounded_rect_points(outer_points[:], clipped, r)
	_ = ui_rounded_rect_points(inner_points[:], inner, inner_r)
	for i in 0 ..< n {
		j := (i + 1) % n
		ui_push_triangle_screen(out, count, outer_points[i], outer_points[j], inner_points[j], color, color, color, extent)
		ui_push_triangle_screen(out, count, outer_points[i], inner_points[j], inner_points[i], color, color, color, extent)
	}
}

ui_push_gradient_rect :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, radius: f32, top, bottom: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	if count^ + 6 > UI_MAX_VERTICES {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	r := min(max(radius, 0), min(clipped.w, clipped.h) * 0.5)
	if r > 0.5 {
		points: [32]uifw.Vec2
		n := ui_rounded_rect_points(points[:], clipped, r)
		center := uifw.Vec2{clipped.x + clipped.w * 0.5, clipped.y + clipped.h * 0.5}
		center_t := (center.y - rect.y) / max(rect.h, 0.00001)
		center_color := ui_color_lerp(top, bottom, center_t)
		for i in 0 ..< n {
			j := (i + 1) % n
			ai := (points[i].y - rect.y) / max(rect.h, 0.00001)
			bi := (points[j].y - rect.y) / max(rect.h, 0.00001)
			ui_push_triangle_screen(out, count, center, points[i], points[j], center_color, ui_color_lerp(top, bottom, ai), ui_color_lerp(top, bottom, bi), extent)
		}
		return
	}
	y0_t := (clipped.y - rect.y) / max(rect.h, 0.00001)
	y1_t := (clipped.y + clipped.h - rect.y) / max(rect.h, 0.00001)
	c0 := ui_color_lerp(top, bottom, y0_t)
	c1 := ui_color_lerp(top, bottom, y1_t)
	p0 := uifw.Vec2{clipped.x, clipped.y}
	p1 := uifw.Vec2{clipped.x + clipped.w, clipped.y}
	p2 := uifw.Vec2{clipped.x + clipped.w, clipped.y + clipped.h}
	p3 := uifw.Vec2{clipped.x, clipped.y + clipped.h}
	ui_push_triangle_screen(out, count, p0, p1, p2, c0, c0, c1, extent)
	ui_push_triangle_screen(out, count, p0, p2, p3, c0, c1, c1, extent)
}

ui_push_horizontal_gradient_rect :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, left, right: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	if count^ + 6 > UI_MAX_VERTICES {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	x0_t := (clipped.x - rect.x) / max(rect.w, 0.00001)
	x1_t := (clipped.x + clipped.w - rect.x) / max(rect.w, 0.00001)
	c0 := ui_color_lerp(left, right, x0_t)
	c1 := ui_color_lerp(left, right, x1_t)
	p0 := uifw.Vec2{clipped.x, clipped.y}
	p1 := uifw.Vec2{clipped.x + clipped.w, clipped.y}
	p2 := uifw.Vec2{clipped.x + clipped.w, clipped.y + clipped.h}
	p3 := uifw.Vec2{clipped.x, clipped.y + clipped.h}
	ui_push_triangle_screen(out, count, p0, p1, p2, c0, c1, c1, extent)
	ui_push_triangle_screen(out, count, p0, p2, p3, c0, c1, c0, extent)
}

ui_push_line :: proc(out: [^]Ui_Vertex, count: ^int, p0, p1: uifw.Vec2, color: uifw.Color, width: f32, scissor: uifw.Rect, extent: vk.Extent2D) {
	dx := p1.x - p0.x
	dy := p1.y - p0.y
	len_sq := dx * dx + dy * dy
	if len_sq <= 0.0001 {
		ui_push_ellipse(out, count, {p0.x - width * 0.5, p0.y - width * 0.5, width, width}, color, scissor, extent)
		return
	}
	len := math.sqrt(len_sq)
	nx := -dy / len * width * 0.5
	ny := dx / len * width * 0.5
	bounds := uifw.Rect{min(p0.x, p1.x) - width, min(p0.y, p1.y) - width, abs(dx) + width * 2, abs(dy) + width * 2}
	if ui_rect_intersection(bounds, scissor).w <= 0 || ui_rect_intersection(bounds, scissor).h <= 0 {
		return
	}
	a := uifw.Vec2{p0.x + nx, p0.y + ny}
	b := uifw.Vec2{p1.x + nx, p1.y + ny}
	c := uifw.Vec2{p1.x - nx, p1.y - ny}
	d := uifw.Vec2{p0.x - nx, p0.y - ny}
	ui_push_quad(out, count, a, b, c, d, color, scissor, extent)
}

ui_push_quad :: proc(out: [^]Ui_Vertex, count: ^int, p0, p1, p2, p3: uifw.Vec2, color: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	min_x := min(min(p0.x, p1.x), min(p2.x, p3.x))
	min_y := min(min(p0.y, p1.y), min(p2.y, p3.y))
	max_x := max(max(p0.x, p1.x), max(p2.x, p3.x))
	max_y := max(max(p0.y, p1.y), max(p2.y, p3.y))
	bounds_clip := ui_rect_intersection({min_x, min_y, max_x - min_x, max_y - min_y}, scissor)
	if bounds_clip.w <= 0 || bounds_clip.h <= 0 {
		return
	}
	points := [?]uifw.Vec2{p0, p1, p2, p3}
	clipped: [16]uifw.Vec2
	n := ui_clip_polygon_to_rect(points[:], clipped[:], scissor)
	if n < 3 {
		return
	}
	ui_push_solid_polygon(out, count, clipped[:n], color, extent)
}

ui_push_solid_polygon :: proc(out: [^]Ui_Vertex, count: ^int, points: []uifw.Vec2, color: uifw.Color, extent: vk.Extent2D) {
	if len(points) < 3 {
		return
	}
	required := (len(points) - 2) * 3
	if count^ + required > UI_MAX_VERTICES {
		return
	}
	origin := points[0]
	for i in 1 ..< len(points) - 1 {
		ui_push_triangle_screen(out, count, origin, points[i], points[i + 1], color, color, color, extent)
	}
}

ui_push_triangle_clipped :: proc(out: [^]Ui_Vertex, count: ^int, p0, p1, p2: uifw.Vec2, color: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	min_x := min(min(p0.x, p1.x), p2.x)
	min_y := min(min(p0.y, p1.y), p2.y)
	max_x := max(max(p0.x, p1.x), p2.x)
	max_y := max(max(p0.y, p1.y), p2.y)
	bounds_clip := ui_rect_intersection({min_x, min_y, max_x - min_x, max_y - min_y}, scissor)
	if bounds_clip.w <= 0 || bounds_clip.h <= 0 {
		return
	}
	points := [?]uifw.Vec2{p0, p1, p2}
	clipped: [16]uifw.Vec2
	n := ui_clip_polygon_to_rect(points[:], clipped[:], scissor)
	if n < 3 {
		return
	}
	ui_push_solid_polygon(out, count, clipped[:n], color, extent)
}

ui_clip_polygon_to_rect :: proc(points: []uifw.Vec2, out: []uifw.Vec2, rect: uifw.Rect) -> int {
	if len(points) == 0 || len(out) == 0 || rect.w <= 0 || rect.h <= 0 {
		return 0
	}
	a: [16]uifw.Vec2
	b: [16]uifw.Vec2
	n := min(len(points), len(a))
	for i in 0 ..< n {
		a[i] = points[i]
	}

	left := rect.x
	top := rect.y
	right := rect.x + rect.w
	bottom := rect.y + rect.h

	n = ui_clip_polygon_edge(a[:n], b[:], left, 0)
	n = ui_clip_polygon_edge(b[:n], a[:], right, 1)
	n = ui_clip_polygon_edge(a[:n], b[:], top, 2)
	n = ui_clip_polygon_edge(b[:n], a[:], bottom, 3)

	result_count := min(n, len(out))
	for i in 0 ..< result_count {
		out[i] = a[i]
	}
	return result_count
}

ui_clip_polygon_edge :: proc(input: []uifw.Vec2, output: []uifw.Vec2, boundary: f32, edge: int) -> int {
	if len(input) == 0 || len(output) == 0 {
		return 0
	}
	count := 0
	prev := input[len(input) - 1]
	prev_inside := ui_clip_point_inside(prev, boundary, edge)
	for curr in input {
		curr_inside := ui_clip_point_inside(curr, boundary, edge)
		if curr_inside {
			if !prev_inside && count < len(output) {
				output[count] = ui_clip_intersection(prev, curr, boundary, edge)
				count += 1
			}
			if count < len(output) {
				output[count] = curr
				count += 1
			}
		} else if prev_inside && count < len(output) {
			output[count] = ui_clip_intersection(prev, curr, boundary, edge)
			count += 1
		}
		prev = curr
		prev_inside = curr_inside
	}
	return count
}

ui_clip_point_inside :: proc(p: uifw.Vec2, boundary: f32, edge: int) -> bool {
	switch edge {
	case 0:
		return p.x >= boundary
	case 1:
		return p.x <= boundary
	case 2:
		return p.y >= boundary
	case:
		return p.y <= boundary
	}
}

ui_clip_intersection :: proc(a, b: uifw.Vec2, boundary: f32, edge: int) -> uifw.Vec2 {
	if edge == 0 || edge == 1 {
		t := (boundary - a.x) / max(b.x - a.x, 0.00001)
		if b.x < a.x {
			t = (boundary - a.x) / min(b.x - a.x, -0.00001)
		}
		return {boundary, a.y + (b.y - a.y) * t}
	}
	t := (boundary - a.y) / max(b.y - a.y, 0.00001)
	if b.y < a.y {
		t = (boundary - a.y) / min(b.y - a.y, -0.00001)
	}
	return {a.x + (b.x - a.x) * t, boundary}
}

ui_push_ellipse :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, color: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	center := uifw.Vec2{rect.x + rect.w * 0.5, rect.y + rect.h * 0.5}
	points: [32]uifw.Vec2
	n := ui_ellipse_points(points[:], rect)
	for i in 0 ..< n {
		j := (i + 1) % n
		ui_push_triangle_clipped(out, count, center, points[i], points[j], color, scissor, extent)
	}
}

ui_push_ellipse_stroke :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, color: uifw.Color, width: f32, scissor: uifw.Rect, extent: vk.Extent2D) {
	if ui_rect_intersection(rect, scissor).w <= 0 || ui_rect_intersection(rect, scissor).h <= 0 {
		return
	}
	w := min(max(width, UI_STROKE_WIDTH), min(rect.w, rect.h) * 0.5)
	inner := uifw.Rect{rect.x + w, rect.y + w, max(rect.w - w * 2, 0), max(rect.h - w * 2, 0)}
	outer_points: [32]uifw.Vec2
	inner_points: [32]uifw.Vec2
	n := ui_ellipse_points(outer_points[:], rect)
	_ = ui_ellipse_points(inner_points[:], inner)
	for i in 0 ..< n {
		j := (i + 1) % n
		ui_push_quad(out, count, outer_points[i], outer_points[j], inner_points[j], inner_points[i], color, scissor, extent)
	}
}

ui_push_image_textured :: proc(out: [^]Ui_Vertex, count: ^int, rect, uv_rect: uifw.Rect, tint: uifw.Color, filter: uifw.Gui_Image_Filter, scissor: uifw.Rect, extent: vk.Extent2D) {
	if count^ + 6 > UI_MAX_VERTICES {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	color := tint
	if color.a <= 0 {
		color = {1, 1, 1, 1}
	}
	uv := uv_rect
	if uv.w == 0 && uv.h == 0 {
		uv = {0, 0, 1, 1}
	}
	effect := uifw.Color{filter.brightness, filter.contrast, filter.grayscale, filter.blur}
	if effect.r == 0 {
		effect.r = 1
	}
	if effect.g == 0 {
		effect.g = 1
	}
	u0 := uv.x + (clipped.x - rect.x) / max(rect.w, 0.00001) * uv.w
	v0 := uv.y + (clipped.y - rect.y) / max(rect.h, 0.00001) * uv.h
	u1 := uv.x + (clipped.x + clipped.w - rect.x) / max(rect.w, 0.00001) * uv.w
	v1 := uv.y + (clipped.y + clipped.h - rect.y) / max(rect.h, 0.00001) * uv.h

	x0 := ui_screen_to_ndc_x(clipped.x, extent.width)
	y0 := ui_screen_to_ndc_y(clipped.y, extent.height)
	x1 := ui_screen_to_ndc_x(clipped.x + clipped.w, extent.width)
	y1 := ui_screen_to_ndc_y(clipped.y + clipped.h, extent.height)

	verts := [?]Ui_Vertex {
		{{x0, y0}, color, {u0, v0}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{x1, y0}, color, {u1, v0}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{x1, y1}, color, {u1, v1}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{x0, y0}, color, {u0, v0}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{x1, y1}, color, {u1, v1}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
		{{x0, y1}, color, {u0, v1}, UI_IMAGE_GLYPH, effect, UI_DEFAULT_MATERIAL},
	}
	for vertex in verts {
		out[count^] = vertex
		count^ += 1
	}
}

ui_push_shader_rect :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, tint: uifw.Color, kind: uifw.Gui_Shader_Kind, params: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	if count^ + 6 > UI_MAX_VERTICES {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	color := tint
	if color.a <= 0 {
		color = {1, 1, 1, 1}
	}
	u0 := (clipped.x - rect.x) / max(rect.w, 0.00001)
	v0 := (clipped.y - rect.y) / max(rect.h, 0.00001)
	u1 := (clipped.x + clipped.w - rect.x) / max(rect.w, 0.00001)
	v1 := (clipped.y + clipped.h - rect.y) / max(rect.h, 0.00001)

	x0 := ui_screen_to_ndc_x(clipped.x, extent.width)
	y0 := ui_screen_to_ndc_y(clipped.y, extent.height)
	x1 := ui_screen_to_ndc_x(clipped.x + clipped.w, extent.width)
	y1 := ui_screen_to_ndc_y(clipped.y + clipped.h, extent.height)
	glyph := UI_SHADER_GLYPH_BASE - f32(kind)
	effect := params

	verts := [?]Ui_Vertex {
		{{x0, y0}, color, {u0, v0}, glyph, effect, UI_DEFAULT_MATERIAL},
		{{x1, y0}, color, {u1, v0}, glyph, effect, UI_DEFAULT_MATERIAL},
		{{x1, y1}, color, {u1, v1}, glyph, effect, UI_DEFAULT_MATERIAL},
		{{x0, y0}, color, {u0, v0}, glyph, effect, UI_DEFAULT_MATERIAL},
		{{x1, y1}, color, {u1, v1}, glyph, effect, UI_DEFAULT_MATERIAL},
		{{x0, y1}, color, {u0, v1}, glyph, effect, UI_DEFAULT_MATERIAL},
	}
	for vertex in verts {
		out[count^] = vertex
		count^ += 1
	}
}

ui_push_refractive_glass_rect :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, style: uifw.Gui_Glass_Style, scissor: uifw.Rect, extent: vk.Extent2D) {
	if count^ + 6 > UI_MAX_VERTICES {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}

	u0 := (clipped.x - rect.x) / max(rect.w, 0.00001)
	v0 := (clipped.y - rect.y) / max(rect.h, 0.00001)
	u1 := (clipped.x + clipped.w - rect.x) / max(rect.w, 0.00001)
	v1 := (clipped.y + clipped.h - rect.y) / max(rect.h, 0.00001)

	x0 := ui_screen_to_ndc_x(clipped.x, extent.width)
	y0 := ui_screen_to_ndc_y(clipped.y, extent.height)
	x1 := ui_screen_to_ndc_x(clipped.x + clipped.w, extent.width)
	y1 := ui_screen_to_ndc_y(clipped.y + clipped.h, extent.height)

	radius := min(max(style.radius, 0), min(rect.w, rect.h) * 0.5)
	thickness := max(style.thickness, f32(0))
	roughness := min(max(style.roughness, 0), 1)
	bevel := max(style.bevel, f32(0))
	ior := max(style.ior, f32(1.0))
	dispersion := max(style.dispersion, f32(0))
	border := min(max(style.border, 0), 1)
	highlight := min(max(style.highlight, 0), 1)
	effect := uifw.Color{thickness, roughness, bevel, radius}
	material := uifw.Color{ior, dispersion, border, highlight}
	color := style.tint

	verts := [?]Ui_Vertex {
		{{x0, y0}, color, {u0, v0}, UI_GLASS_GLYPH, effect, material},
		{{x1, y0}, color, {u1, v0}, UI_GLASS_GLYPH, effect, material},
		{{x1, y1}, color, {u1, v1}, UI_GLASS_GLYPH, effect, material},
		{{x0, y0}, color, {u0, v0}, UI_GLASS_GLYPH, effect, material},
		{{x1, y1}, color, {u1, v1}, UI_GLASS_GLYPH, effect, material},
		{{x0, y1}, color, {u0, v1}, UI_GLASS_GLYPH, effect, material},
	}
	for vertex in verts {
		out[count^] = vertex
		count^ += 1
	}
}

ui_ellipse_points :: proc(points: []uifw.Vec2, rect: uifw.Rect) -> int {
	unit := [?]uifw.Vec2 {
		{1.0000, 0.0000},
		{0.9808, 0.1951},
		{0.9239, 0.3827},
		{0.8315, 0.5556},
		{0.7071, 0.7071},
		{0.5556, 0.8315},
		{0.3827, 0.9239},
		{0.1951, 0.9808},
		{0.0000, 1.0000},
		{-0.1951, 0.9808},
		{-0.3827, 0.9239},
		{-0.5556, 0.8315},
		{-0.7071, 0.7071},
		{-0.8315, 0.5556},
		{-0.9239, 0.3827},
		{-0.9808, 0.1951},
		{-1.0000, 0.0000},
		{-0.9808, -0.1951},
		{-0.9239, -0.3827},
		{-0.8315, -0.5556},
		{-0.7071, -0.7071},
		{-0.5556, -0.8315},
		{-0.3827, -0.9239},
		{-0.1951, -0.9808},
		{0.0000, -1.0000},
		{0.1951, -0.9808},
		{0.3827, -0.9239},
		{0.5556, -0.8315},
		{0.7071, -0.7071},
		{0.8315, -0.5556},
		{0.9239, -0.3827},
		{0.9808, -0.1951},
	}
	center := uifw.Vec2{rect.x + rect.w * 0.5, rect.y + rect.h * 0.5}
	rx := rect.w * 0.5
	ry := rect.h * 0.5
	count := min(len(points), len(unit))
	for i in 0 ..< count {
		points[i] = {center.x + unit[i].x * rx, center.y + unit[i].y * ry}
	}
	return count
}

ui_rounded_rect_points :: proc(points: []uifw.Vec2, rect: uifw.Rect, radius: f32) -> int {
	r := min(max(radius, 0), min(rect.w, rect.h) * 0.5)
	corners := [?]uifw.Vec2 {
		{rect.x + rect.w - r, rect.y + r},
		{rect.x + rect.w - r, rect.y + rect.h - r},
		{rect.x + r, rect.y + rect.h - r},
		{rect.x + r, rect.y + r},
	}
	offsets := [?][5]uifw.Vec2 {
		{
			{0.0000, -1.0000},
			{0.3827, -0.9239},
			{0.7071, -0.7071},
			{0.9239, -0.3827},
			{1.0000, 0.0000},
		},
		{
			{1.0000, 0.0000},
			{0.9239, 0.3827},
			{0.7071, 0.7071},
			{0.3827, 0.9239},
			{0.0000, 1.0000},
		},
		{
			{0.0000, 1.0000},
			{-0.3827, 0.9239},
			{-0.7071, 0.7071},
			{-0.9239, 0.3827},
			{-1.0000, 0.0000},
		},
		{
			{-1.0000, 0.0000},
			{-0.9239, -0.3827},
			{-0.7071, -0.7071},
			{-0.3827, -0.9239},
			{0.0000, -1.0000},
		},
	}
	count := 0
	for corner_index in 0 ..< 4 {
		for step in 0 ..< 5 {
			if count >= len(points) {
				return count
			}
			u := offsets[corner_index][step]
			points[count] = {corners[corner_index].x + u.x * r, corners[corner_index].y + u.y * r}
			count += 1
		}
	}
	return count
}
