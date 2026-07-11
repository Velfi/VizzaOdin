package render_vk

import uifw "../ui"
import engine "../engine"

import vk "vendor:vulkan"
import "core:bytes"
import "core:fmt"
import "core:math"
import png "core:image/png"

ui_text_shape_cache_hash :: proc(font_kind: uifw.Gui_Font_Kind, bytes: []u8, scale: f32) -> u64 {
	hash := u64(14695981039346656037)
	hash = (hash ~ u64(font_kind)) * 1099511628211
	for ch in bytes {
		hash = (hash ~ u64(ch)) * 1099511628211
	}
	scale_bits := transmute(u32)scale
	for shift := 0; shift < 32; shift += 8 {
		hash = (hash ~ u64((scale_bits >> u32(shift)) & 0xff)) * 1099511628211
	}
	return hash
}

ui_text_shape_cache_matches :: proc(entry: ^Ui_Text_Shape_Cache_Entry, hash: u64, font_kind: uifw.Gui_Font_Kind, bytes: []u8, scale: f32) -> bool {
	if entry.glyph_count == 0 || entry.hash != hash || entry.scale != scale || entry.font_kind != font_kind || int(entry.text_len) != len(bytes) {
		return false
	}
	for i in 0 ..< len(bytes) {
		if entry.text[i] != bytes[i] {
			return false
		}
	}
	return true
}

ui_text_shape_cache_get :: proc(renderer: ^Ui_Renderer, font_kind: uifw.Gui_Font_Kind, bytes: []u8, scale: f32) -> ^Ui_Text_Shape_Cache_Entry {
	if renderer == nil || len(renderer.text_shape_cache) == 0 || len(bytes) == 0 || len(bytes) > UI_TEXT_SHAPE_CACHE_MAX_BYTES {
		return nil
	}
	hash := ui_text_shape_cache_hash(font_kind, bytes, scale)
	renderer.text_shape_generation += 1
	if renderer.text_shape_generation == 0 {
		renderer.text_shape_generation = 1
		for i in 0 ..< len(renderer.text_shape_cache) {
			renderer.text_shape_cache[i].generation = 0
		}
	}
	for i in 0 ..< len(renderer.text_shape_cache) {
		entry := &renderer.text_shape_cache[i]
		if ui_text_shape_cache_matches(entry, hash, font_kind, bytes, scale) {
			entry.generation = renderer.text_shape_generation
			return entry
		}
	}

	return nil
}

ui_text_shape_cache_store :: proc(renderer: ^Ui_Renderer, font_kind: uifw.Gui_Font_Kind, bytes: []u8, scale: f32, shaped: []uifw.Gui_Shaped_Glyph) {
	if renderer == nil || len(renderer.text_shape_cache) == 0 || len(bytes) == 0 || len(bytes) > UI_TEXT_SHAPE_CACHE_MAX_BYTES || len(shaped) == 0 || len(shaped) > UI_TEXT_SHAPE_CACHE_MAX_GLYPHS {
		return
	}
	hash := ui_text_shape_cache_hash(font_kind, bytes, scale)
	oldest := 0
	oldest_generation := renderer.text_shape_cache[0].generation
	for i in 0 ..< len(renderer.text_shape_cache) {
		entry := &renderer.text_shape_cache[i]
		if ui_text_shape_cache_matches(entry, hash, font_kind, bytes, scale) {
			entry.generation = renderer.text_shape_generation
			return
		}
		if entry.glyph_count == 0 {
			oldest = i
			break
		}
		if entry.generation < oldest_generation {
			oldest = i
			oldest_generation = entry.generation
		}
	}

	entry := &renderer.text_shape_cache[oldest]
	if renderer.text_shape_generation == 0 {
		renderer.text_shape_generation = 1
	}
	entry.hash = hash
	entry.generation = renderer.text_shape_generation
	entry.text_len = u16(len(bytes))
	entry.scale = scale
	entry.font_kind = font_kind
	entry.glyph_count = u16(len(shaped))
	copy(entry.text[:], bytes)
	copy(entry.glyphs[:], shaped)
}

ui_push_text :: proc(renderer: ^Ui_Renderer, out: [^]Ui_Vertex, count: ^int, command: uifw.Draw_Command, scissor: uifw.Rect, extent: vk.Extent2D, atlas: ^Ui_Font_Atlas_Cache_Entry) {
	if len(command.text) == 0 {
		return
	}
	bytes := transmute([]u8)command.text
	scale := command.text_scale
	if scale <= 0 {
		scale = 1
	}
	char_w := ui_text_glyph_quad_width(atlas, scale)
	advance_w := f32(UI_FONT_LOGICAL_WIDTH) * scale
	char_h := f32(UI_FONT_LOGICAL_HEIGHT) * scale
	gap := f32(0)
	x := command.rect.x
	y := command.rect.y
	shaped: []uifw.Gui_Shaped_Glyph
	shaped_count := 0
	direct_shaped: [UI_MAX_SHAPED_GLYPHS]uifw.Gui_Shaped_Glyph
	if renderer != nil {
		cache_entry := ui_text_shape_cache_get(renderer, command.font_kind, bytes, scale)
		if cache_entry != nil {
			shaped_count = int(cache_entry.glyph_count)
			shaped = cache_entry.glyphs[:shaped_count]
		}
	}
	if shaped_count == 0 {
		direct_count := uifw.gui_font_shape_text(command.font_kind, bytes, scale, direct_shaped[:])
		if direct_count > 0 {
			shaped_count = direct_count
			shaped = direct_shaped[:shaped_count]
			ui_text_shape_cache_store(renderer, command.font_kind, bytes, scale, shaped)
		}
	}
	if command.text_align == .Center {
		text_w := uifw.gui_font_text_width(command.font_kind, bytes, scale, advance_w)
		x = command.rect.x + max((command.rect.w - text_w) * 0.5, 0)
	} else if command.text_align == .Right {
		text_w := uifw.gui_font_text_width(command.font_kind, bytes, scale, advance_w)
		x = command.rect.x + max(command.rect.w - text_w, 0)
	}

	if shaped_count > 0 {
		cursor_x := x
		for glyph in shaped[:shaped_count] {
			slot := uifw.gui_font_glyph_slot(glyph.glyph_id)
			if slot >= 0 {
				ui_push_text_glyph(
					out,
					count,
					{cursor_x + glyph.x_offset, y - glyph.y_offset, char_w, char_h},
					command.color,
					f32(slot),
					scissor,
					extent,
					ui_font_atlas_uv(atlas, int(slot)),
				)
			}
			cursor_x += glyph.x_advance
		}
		return
	}

	cursor_x := x
	for ch in bytes {
		if ch < UI_FONT_GLYPH_FIRST || ch > UI_FONT_GLYPH_FIRST + UI_FONT_GLYPH_COUNT - 1 {
			cursor_x += advance_w + gap
			continue
		}
		if ch == ' ' {
			cursor_x += uifw.gui_font_glyph_advance(command.font_kind, ch, scale, advance_w) + gap
			continue
		}
		slot := int(ch - UI_FONT_GLYPH_FIRST)
		ui_push_text_glyph(out, count, {cursor_x, y, char_w, char_h}, command.color, f32(slot), scissor, extent, ui_font_atlas_uv(atlas, slot))
		cursor_x += uifw.gui_font_glyph_advance(command.font_kind, ch, scale, advance_w) + gap
	}
}

ui_push_clear_text_placeholder :: proc(out: []Ui_Clear_Rect, count: ^int, command: uifw.Draw_Command, scissor: uifw.Rect) {
	if len(command.text) == 0 {
		return
	}
	scale := command.text_scale
	if scale <= 0 {
		scale = 1
	}
	char_w := f32(UI_FONT_ATLAS_LOGICAL_WIDTH) * scale
	advance_w := f32(UI_FONT_LOGICAL_WIDTH) * scale
	char_h := f32(UI_FONT_LOGICAL_HEIGHT) * scale
	gap := f32(0)
	x := command.rect.x
	y := command.rect.y
	if command.text_align == .Center {
		text_w := uifw.gui_font_text_width(command.font_kind, transmute([]u8)command.text, scale, advance_w)
		x = command.rect.x + max((command.rect.w - text_w) * 0.5, 0)
	} else if command.text_align == .Right {
		text_w := uifw.gui_font_text_width(command.font_kind, transmute([]u8)command.text, scale, advance_w)
		x = command.rect.x + max(command.rect.w - text_w, 0)
	}

	shaped: [UI_MAX_SHAPED_GLYPHS]uifw.Gui_Shaped_Glyph
	shaped_count := uifw.gui_font_shape_text(command.font_kind, transmute([]u8)command.text, scale, shaped[:])
	if shaped_count > 0 {
		cursor_x := x
		for glyph in shaped[:shaped_count] {
			slot := uifw.gui_font_glyph_slot(glyph.glyph_id)
			if slot >= 0 {
				ui_push_clear_rect(out, count, {cursor_x + glyph.x_offset, y - glyph.y_offset, char_w, char_h}, command.color, scissor)
			}
			cursor_x += glyph.x_advance
		}
		return
	}

	cursor_x := x
	for ch in transmute([]u8)command.text {
		if ch < UI_FONT_GLYPH_FIRST || ch > UI_FONT_GLYPH_FIRST + UI_FONT_GLYPH_COUNT - 1 {
			cursor_x += char_w + gap
			continue
		}
		if ch == ' ' {
			cursor_x += uifw.gui_font_glyph_advance(command.font_kind, ch, scale, char_w) + gap
			continue
		}
		ui_push_clear_rect(out, count, {cursor_x, y, char_w, char_h}, command.color, scissor)
		cursor_x += uifw.gui_font_glyph_advance(command.font_kind, ch, scale, advance_w) + gap
	}
}

ui_text_glyph_quad_width :: proc(atlas: ^Ui_Font_Atlas_Cache_Entry, scale: f32) -> f32 {
	if atlas != nil && atlas.cell_width > 0 && atlas.cell_height > 0 {
		return f32(atlas.cell_width) * f32(UI_FONT_LOGICAL_HEIGHT) * scale / f32(atlas.cell_height)
	}
	return f32(UI_FONT_ATLAS_LOGICAL_WIDTH) * scale
}

ui_push_text_glyph :: proc(
	out: [^]Ui_Vertex,
	count: ^int,
	rect: uifw.Rect,
	color: uifw.Color,
	glyph: f32,
	scissor: uifw.Rect,
	extent: vk.Extent2D,
	uv_rect: uifw.Rect,
) {
	if count^ + 6 > UI_MAX_VERTICES {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	clip_x0 := ui_screen_to_ndc_x(clipped.x, extent.width)
	clip_y0 := ui_screen_to_ndc_y(clipped.y, extent.height)
	clip_x1 := ui_screen_to_ndc_x(clipped.x + clipped.w, extent.width)
	clip_y1 := ui_screen_to_ndc_y(clipped.y + clipped.h, extent.height)

	local_u0 := (clipped.x - rect.x) / max(rect.w, 0.00001)
	local_v0 := (clipped.y - rect.y) / max(rect.h, 0.00001)
	local_u1 := (clipped.x + clipped.w - rect.x) / max(rect.w, 0.00001)
	local_v1 := (clipped.y + clipped.h - rect.y) / max(rect.h, 0.00001)
	u0 := uv_rect.x + local_u0 * uv_rect.w
	v0 := uv_rect.y + local_v0 * uv_rect.h
	u1 := uv_rect.x + local_u1 * uv_rect.w
	v1 := uv_rect.y + local_v1 * uv_rect.h

	verts := [?]Ui_Vertex {
		{{clip_x0, clip_y0}, color, {u0, v0}, glyph, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{clip_x1, clip_y0}, color, {u1, v0}, glyph, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{clip_x1, clip_y1}, color, {u1, v1}, glyph, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{clip_x0, clip_y0}, color, {u0, v0}, glyph, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{clip_x1, clip_y1}, color, {u1, v1}, glyph, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{clip_x0, clip_y1}, color, {u0, v1}, glyph, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
	}
	for vertex in verts {
		out[count^] = vertex
		count^ += 1
	}
}

ui_font_atlas_uv :: proc(atlas: ^Ui_Font_Atlas_Cache_Entry, slot: int) -> uifw.Rect {
	if atlas == nil || !atlas.ready || atlas.atlas_width == 0 || atlas.atlas_height == 0 || atlas.columns == 0 {
		return {0, 0, 1, 1}
	}
	s := max(slot, 0)
	col := u32(s) % atlas.columns
	row := u32(s) / atlas.columns
	inset_u := f32(0.5) / f32(atlas.atlas_width)
	inset_v := f32(0.5) / f32(atlas.atlas_height)
	u0 := f32(col * atlas.cell_width) / f32(atlas.atlas_width) + inset_u
	v0 := f32(row * atlas.cell_height) / f32(atlas.atlas_height) + inset_v
	u1 := f32(col * atlas.cell_width + atlas.cell_width) / f32(atlas.atlas_width) - inset_u
	v1 := f32(row * atlas.cell_height + atlas.cell_height) / f32(atlas.atlas_height) - inset_v
	return {u0, v0, max(u1 - u0, 0), max(v1 - v0, 0)}
}

ui_push_clear_rect :: proc(out: []Ui_Clear_Rect, count: ^int, rect: uifw.Rect, color: uifw.Color, scissor: uifw.Rect) {
	if count^ >= len(out) {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}
	out[count^] = {rect = clipped, color = color}
	count^ += 1
}

ui_push_rect :: proc(out: [^]Ui_Vertex, count: ^int, rect: uifw.Rect, color: uifw.Color, scissor: uifw.Rect, extent: vk.Extent2D) {
	if count^ + 6 > UI_MAX_VERTICES {
		return
	}
	clipped := ui_rect_intersection(rect, scissor)
	if clipped.w <= 0 || clipped.h <= 0 {
		return
	}

	x0 := ui_screen_to_ndc_x(clipped.x, extent.width)
	y0 := ui_screen_to_ndc_y(clipped.y, extent.height)
	x1 := ui_screen_to_ndc_x(clipped.x + clipped.w, extent.width)
	y1 := ui_screen_to_ndc_y(clipped.y + clipped.h, extent.height)

	verts := [?]Ui_Vertex {
		{{x0, y0}, color, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{x1, y0}, color, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{x1, y1}, color, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{x0, y0}, color, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{x1, y1}, color, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
		{{x0, y1}, color, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL},
	}
	for vertex in verts {
		out[count^] = vertex
		count^ += 1
	}
}

ui_push_triangle_screen :: proc(
	out: [^]Ui_Vertex,
	count: ^int,
	a, b, c: uifw.Vec2,
	color_a, color_b, color_c: uifw.Color,
	extent: vk.Extent2D,
) {
	if count^ + 3 > UI_MAX_VERTICES {
		return
	}
	out[count^] = {{ui_screen_to_ndc_x(a.x, extent.width), ui_screen_to_ndc_y(a.y, extent.height)}, color_a, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL}
	count^ += 1
	out[count^] = {{ui_screen_to_ndc_x(b.x, extent.width), ui_screen_to_ndc_y(b.y, extent.height)}, color_b, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL}
	count^ += 1
	out[count^] = {{ui_screen_to_ndc_x(c.x, extent.width), ui_screen_to_ndc_y(c.y, extent.height)}, color_c, {0, 0}, -1, UI_DEFAULT_EFFECT, UI_DEFAULT_MATERIAL}
	count^ += 1
}

ui_color_lerp :: proc(a, b: uifw.Color, t: f32) -> uifw.Color {
	x := min(max(t, 0), 1)
	return {
		a.r + (b.r - a.r) * x,
		a.g + (b.g - a.g) * x,
		a.b + (b.b - a.b) * x,
		a.a + (b.a - a.a) * x,
	}
}

ui_screen_to_ndc_x :: proc(x: f32, width: u32) -> f32 {
	return x / f32(max(width, 1)) * 2 - 1
}

ui_screen_to_ndc_y :: proc(y: f32, height: u32) -> f32 {
	return y / f32(max(height, 1)) * 2 - 1
}

ui_rect_intersection :: proc(a, b: uifw.Rect) -> uifw.Rect {
	x0 := max(a.x, b.x)
	y0 := max(a.y, b.y)
	x1 := min(a.x + a.w, b.x + b.w)
	y1 := min(a.y + a.h, b.y + b.h)
	return {x0, y0, max(x1 - x0, 0), max(y1 - y0, 0)}
}
