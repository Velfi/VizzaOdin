package ui

import "core:math"
import "core:fmt"
import "core:strconv"
import "core:sync"
import "core:time"

foreign import textshape "../../third_party/textshape/libtextshape.a"

@(default_calling_convention = "c")
foreign textshape {
	vo_textshape_init :: proc(font_kind: i32, font_path: cstring, logical_height: f32) -> i32 ---
	vo_textshape_width :: proc(font_kind: i32, text: [^]u8, len: i32, text_scale, fallback_advance: f32) -> f32 ---
	vo_textshape_shape :: proc(font_kind: i32, text: [^]u8, len: i32, text_scale: f32, out: [^]Gui_Shaped_Glyph, out_cap: i32) -> i32 ---
	vo_textshape_render_ascii_atlas :: proc(font_kind: i32, glyph_first, glyph_last, pixel_height, cell_width, cell_height, columns: i32, out_rgba: [^]u8, out_len: i32) -> i32 ---
}

Vec2 :: struct {
	x, y: f32,
}

Rect :: struct {
	x, y, w, h: f32,
}

Color :: struct {
	r, g, b, a: f32,
}

Hsv_Color :: struct {
	h, s, v, a: f32,
}

Gui_Vec2_Range :: struct {
	min, max: Vec2,
}

Text_Align :: enum {
	Left,
	Center,
	Right,
}

Gui_Font_Kind :: enum i32 {
	Body,
	Display,
	SimStart,
}

Gui_Align :: enum {
	Start,
	Center,
	End,
	Stretch,
}

Gui_Distribution :: enum {
	Start,
	Center,
	End,
	Space_Between,
}

Gui_Breakpoint :: enum {
	Compact,
	Medium,
	Expanded,
	Wide,
}

Gui_Blend_Mode :: enum {
	Alpha,
	Add,
	Multiply,
	Screen,
}

Gui_Shader_Kind :: enum {
	Hue_Strip,
	SV_Grid,
	Alpha_Ramp,
	Hue_Wheel,
	Circular_Progress,
}

Gui_Edge_Insets :: struct {
	left, top, right, bottom: f32,
}

Gui_Anchor :: struct {
	left, top, right, bottom: f32,
}

Gui_Box_Style :: struct {
	fill: Color,
	fill_to: Color,
	border: Color,
	radius: f32,
	border_width: f32,
	opacity: f32,
	shadow_color: Color,
	shadow_offset: Vec2,
	shadow_blur: f32,
	gradient: bool,
	blend: Gui_Blend_Mode,
}

Gui_Image_Filter :: struct {
	brightness: f32,
	contrast: f32,
	grayscale: f32,
	blur: f32,
}

Gui_Glass_Style :: struct {
	tint: Color,
	radius: f32,
	thickness: f32,
	roughness: f32,
	bevel: f32,
	ior: f32,
	dispersion: f32,
	border: f32,
	highlight: f32,
}

Input_Device_Kind :: enum {
	Mouse_Keyboard,
	Controller,
}

Input_State :: struct {
	window_width: i32,
	window_height: i32,
	mouse_pos: Vec2,
	mouse_down: bool,
	mouse_pressed: bool,
	mouse_released: bool,
	mouse_moved: bool,
	mouse_delta: Vec2,
	mouse_button: u32,
	wheel_delta: f32,
	delta_time: f32,
	active_device: Input_Device_Kind,
	pointer_enabled: bool,
	virtual_cursor_pos: Vec2,
	nav_x: f32,
	nav_y: f32,
	nav_pressed_x: f32,
	nav_pressed_y: f32,
	accept: bool,
	back: bool,
	pause: bool,
	toggle_ui: bool,
	focus_next: bool,
	focus_prev: bool,
	primary_down: bool,
	primary_pressed: bool,
	primary_released: bool,
	secondary_down: bool,
	secondary_pressed: bool,
	secondary_released: bool,
	controller_connected: bool,
	controller_disconnected: bool,
	text_input: [32]u8,
	text_input_len: int,
	clipboard_paste: [256]u8,
	clipboard_paste_len: int,
	key_tab: bool,
	key_shift: bool,
	key_ctrl: bool,
	key_super: bool,
	key_enter: bool,
	key_escape: bool,
	key_backspace: bool,
	key_delete: bool,
	key_home: bool,
	key_end: bool,
	key_left: bool,
	key_right: bool,
	key_up: bool,
	key_down: bool,
	key_w: bool,
	key_a: bool,
	key_s: bool,
	key_d: bool,
	key_q: bool,
	key_e: bool,
	key_x: bool,
	key_v: bool,
	key_c: bool,
	key_slash: bool,
	key_space: bool,
	key_space_down: bool,
	key_space_pressed: bool,
	key_space_released: bool,
	controller_left: Vec2,
	controller_right: Vec2,
	controller_zoom: f32,
}

Draw_Command_Kind :: enum {
	Filled_Rect,
	Stroked_Rect,
	Filled_Rounded_Rect,
	Stroked_Rounded_Rect,
	Gradient_Rect,
	Horizontal_Gradient_Rect,
	Filled_Quad,
	Line,
	Filled_Ellipse,
	Stroked_Ellipse,
	Shader_Rect,
	Image,
	Backdrop_Blur_Rect,
	Refractive_Glass_Rect,
	Text,
	Scissor_Begin,
	Scissor_End,
}

Gui_Image_Id :: distinct u64
Gui_Id :: u64
GUI_ID_NONE :: Gui_Id(0)

Draw_Command :: struct {
	kind: Draw_Command_Kind,
	rect: Rect,
	rect_2: Rect,
	p0: Vec2,
	p1: Vec2,
	p2: Vec2,
	p3: Vec2,
	color: Color,
	color_2: Color,
	text: string,
	text_scale: f32,
	text_align: Text_Align,
	font_kind: Gui_Font_Kind,
	radius: f32,
	stroke_width: f32,
	image_id: Gui_Image_Id,
	image_filter: Gui_Image_Filter,
	glass_style: Gui_Glass_Style,
	shader_kind: Gui_Shader_Kind,
	shader_params: Color,
	blend: Gui_Blend_Mode,
}

Gui_Style :: struct {
	bg: Color,
	panel: Color,
	panel_border: Color,
	control: Color,
	control_hot: Color,
	control_active: Color,
	control_disabled: Color,
	text: Color,
	text_muted: Color,
	accent: Color,
	danger: Color,
	spacing: f32,
	spacing_1: f32,
	spacing_2: f32,
	spacing_3: f32,
	spacing_4: f32,
	rhythm: f32,
	display_text_height: f32,
	display_line_height: f32,
	display_char_width: f32,
	display_text_scale: f32,
	heading_text_height: f32,
	heading_line_height: f32,
	heading_char_width: f32,
	heading_text_scale: f32,
	body_text_height: f32,
	body_line_height: f32,
	body_char_width: f32,
	body_text_scale: f32,
	small_text_height: f32,
	small_line_height: f32,
	small_char_width: f32,
	small_text_scale: f32,
	control_padding: f32,
	margin: f32,
	section_gap: f32,
	scrollbar_width: f32,
	focus_ring_width: f32,
	row_height: f32,
	text_height: f32,
	char_width: f32,
	text_scale: f32,
	panel_padding: f32,
	radius_panel: f32,
	radius_control: f32,
	border_width: f32,
	shadow_blur: f32,
	shadow_offset: Vec2,
	shadow_color: Color,
}

Gui_Axis :: enum {
	Column,
	Row,
}

Gui_Layout_Frame :: struct {
	bounds: Rect,
	cursor: Vec2,
	axis: Gui_Axis,
	content_width: f32,
	content_height: f32,
	gap: f32,
	item_height: f32,
	padding: Gui_Edge_Insets,
	align_cross: Gui_Align,
}

Gui_Scroll_Frame :: struct {
	viewport: Rect,
	content_height: f32,
	scroll: f32,
	previous_scroll: f32,
	target_scroll: ^f32,
	wheel_consumed: bool,
}

Gui_Scroll_Hit :: struct {
	viewport: Rect,
	scroll: f32,
	max_scroll: f32,
	step: f32,
	depth: int,
}

MAX_GUI_LAYOUT_DEPTH :: 16
MAX_GUI_CLIP_DEPTH :: 16
MAX_GUI_SCROLL_DEPTH :: 8
MAX_GUI_SCROLL_HITS :: 32
MAX_GUI_ID_DEPTH :: 32
MAX_GUI_DEBUG_IDS :: 512
MAX_GUI_ANIMATION_SLOTS :: 128
MAX_GUI_SPATIAL_ITEMS :: 512
MAX_GUI_SPATIAL_GROUP_DEPTH :: 16
MAX_GUI_OVERLAY_INPUT_RECTS :: 16
GUI_TEXT_WIDTH_CACHE_SLOTS :: 512
GUI_TEXT_WIDTH_CACHE_MAX_BYTES :: 128
GUI_FONT_KIND_CAP :: 4
GUI_COMBO_SHORT_POPUP_ROWS :: 5
GUI_BODY_FONT_PATH :: "assets/fonts/ZeldaSans-Regular-v1.otf"
GUI_DISPLAY_FONT_PATH :: "assets/fonts/ZeldaSerif-Regular-v0_1.otf"
GUI_SIM_START_FONT_PATH :: "assets/fonts/MomoTrustDisplay-Regular.ttf"
GUI_PI :: f32(3.14159265358979323846)
GUI_TAU :: f32(6.28318530717958647692)

gui_text_shaper_ready: bool
gui_text_shaper_font_ready: [GUI_FONT_KIND_CAP]bool
gui_text_shaper_once: sync.Once

Gui_Profile_Snapshot :: struct {
	width_calls: u64,
	width_cache_hits: u64,
	width_seconds: f64,
	shape_calls: u64,
	shape_glyphs: u64,
	shape_seconds: f64,
	wrap_calls: u64,
	wrap_seconds: f64,
}

gui_profile: Gui_Profile_Snapshot

Gui_Animation_Slot :: struct {
	id: Gui_Id,
	value: f32,
	last_frame: u64,
}

Gui_Text_Line :: struct {
	start: int,
	end: int,
}

Gui_Wrap_Candidate :: struct {
	pos: int,
	forced: bool,
}

Gui_Text_Width_Cache_Entry :: struct {
	hash: u64,
	len: int,
	scale: f32,
	fallback_advance: f32,
	font_kind: Gui_Font_Kind,
	width: f32,
	shaper_ready: bool,
	valid: bool,
	bytes: [GUI_TEXT_WIDTH_CACHE_MAX_BYTES]u8,
}

gui_text_width_cache: [GUI_TEXT_WIDTH_CACHE_SLOTS]Gui_Text_Width_Cache_Entry

Gui_Control :: struct {
	id: Gui_Id,
	bounds: Rect,
	enabled: bool,
	hovered: bool,
	focused: bool,
	activated: bool,
	nav_x: f32,
	nav_y: f32,
}

Gui_Spatial_Group_Options :: struct {
	enabled: bool,
}

Gui_Spatial_Group :: struct {
	id: Gui_Id,
	enabled: bool,
}

Gui_Spatial_Item :: struct {
	id: Gui_Id,
	bounds: Rect,
	group: Gui_Id,
	order: int,
	enabled: bool,
}

Gui_Shaped_Glyph :: struct {
	glyph_id: u32,
	x_offset: f32,
	y_offset: f32,
	x_advance: f32,
	y_advance: f32,
}

Gui_Context :: struct {
	input: Input_State,
	previous_input: Input_State,
	commands: [dynamic]Draw_Command,
	hot: Gui_Id,
	active: Gui_Id,
	focused: Gui_Id,
	mouse_prev_pos: Vec2,
	mouse_delta: Vec2,
	mouse_initialized: bool,
	text_edit_id: Gui_Id,
	text_edit_buffer: [64]u8,
	text_edit_len: int,
	text_edit_caret: int,
	text_edit_anchor: int,
	text_edit_scroll_x: f32,
	text_edit_blink: f32,
	text_edit_selecting: bool,
	clipboard_set_pending: bool,
	clipboard_set_text: [256]u8,
	clipboard_set_len: int,
	focus_order_next: int,
	focus_first: Gui_Id,
	focus_prev: Gui_Id,
	focus_last: Gui_Id,
	focus_last_previous: Gui_Id,
	focus_next_from: Gui_Id,
	focus_moved: bool,
	focus_edit_id: Gui_Id,
	focus_edit_seen: bool,
	spatial_items: [MAX_GUI_SPATIAL_ITEMS]Gui_Spatial_Item,
	spatial_item_count: int,
	spatial_groups: [MAX_GUI_SPATIAL_GROUP_DEPTH]Gui_Spatial_Group,
	spatial_group_depth: int,
	frame_index: u64,
	open_panel: Gui_Id,
	combo_highlight: int,
	combo_scroll: f32,
	combo_popup_visible: bool,
	combo_popup_id: Gui_Id,
	combo_popup_rect: Rect,
	combo_popup_options: []string,
	combo_popup_query: [128]u8,
	combo_popup_query_len: int,
	tooltip_visible: bool,
	tooltip_rect: Rect,
	tooltip_text: string,
	next_cursor: Vec2,
	content_width: f32,
	style: Gui_Style,
	layout_stack: [MAX_GUI_LAYOUT_DEPTH]Gui_Layout_Frame,
	layout_depth: int,
	input_clip_stack: [MAX_GUI_CLIP_DEPTH]Rect,
	input_clip_depth: int,
	overlay_input_rects: [MAX_GUI_OVERLAY_INPUT_RECTS]Rect,
	overlay_input_rect_count: int,
	next_overlay_input_rects: [MAX_GUI_OVERLAY_INPUT_RECTS]Rect,
	next_overlay_input_rect_count: int,
	overlay_input_depth: int,
	scroll_stack: [MAX_GUI_SCROLL_DEPTH]Gui_Scroll_Frame,
	scroll_depth: int,
	wheel_scroll_consumed: bool,
	wheel_scroll_depth: int,
	wheel_scroll_target_depth: int,
	scroll_hits: [MAX_GUI_SCROLL_HITS]Gui_Scroll_Hit,
	scroll_hit_count: int,
	next_scroll_hits: [MAX_GUI_SCROLL_HITS]Gui_Scroll_Hit,
	next_scroll_hit_count: int,
	id_stack: [MAX_GUI_ID_DEPTH]Gui_Id,
	id_depth: int,
	debug_registered_ids: [MAX_GUI_DEBUG_IDS]Gui_Id,
	debug_registered_id_count: int,
	debug_duplicate_id_count: int,
	animation_slots: [MAX_GUI_ANIMATION_SLOTS]Gui_Animation_Slot,
}

gui_default_style :: proc() -> Gui_Style {
	return {
		bg = {0.0, 0.0, 0.0, 0.0},
		panel = {0.08, 0.10, 0.12, 0.56},
		panel_border = {1.0, 1.0, 1.0, 0.22},
		control = {1.0, 1.0, 1.0, 0.12},
		control_hot = {1.0, 1.0, 1.0, 0.24},
		control_active = {0.86, 0.92, 1.0, 0.28},
		control_disabled = {1.0, 1.0, 1.0, 0.07},
		text = {1.0, 1.0, 1.0, 0.90},
		text_muted = {1.0, 1.0, 1.0, 0.70},
		accent = {0.86, 0.92, 1.0, 1.0},
		danger = {0.937, 0.267, 0.267, 1.0},
		spacing = 12,
		spacing_1 = 4,
		spacing_2 = 8,
		spacing_3 = 12,
		spacing_4 = 18,
		rhythm = 40,
		display_text_height = 90,
		display_line_height = 112,
		display_char_width = 56,
		display_text_scale = 5.625,
		heading_text_height = 45,
		heading_line_height = 56,
		heading_char_width = 28,
		heading_text_scale = 2.8125,
		body_text_height = 30,
		body_line_height = 38,
		body_char_width = 18.75,
		body_text_scale = 1.875,
		small_text_height = 22.5,
		small_line_height = 30,
		small_char_width = 14.0625,
		small_text_scale = 1.40625,
		control_padding = 8,
		margin = 16,
		section_gap = 40,
		scrollbar_width = 6,
		focus_ring_width = 2,
		row_height = 44,
		text_height = 32,
		char_width = 20,
		text_scale = 2.0,
		panel_padding = 8,
		radius_panel = 4,
		radius_control = 4,
		border_width = 1,
		shadow_blur = 8,
		shadow_offset = {0, 2},
		shadow_color = {0, 0, 0, 0.30},
	}
}

gui_style_scaled :: proc(base: Gui_Style, scale: f32) -> Gui_Style {
	s := min(max(scale, 0.5), 3.0)
	style := base
	style.spacing *= s
	style.spacing_1 *= s
	style.spacing_2 *= s
	style.spacing_3 *= s
	style.spacing_4 *= s
	style.rhythm *= s
	style.display_text_height *= s
	style.display_line_height *= s
	style.display_char_width *= s
	style.display_text_scale *= s
	style.heading_text_height *= s
	style.heading_line_height *= s
	style.heading_char_width *= s
	style.heading_text_scale *= s
	style.body_text_height *= s
	style.body_line_height *= s
	style.body_char_width *= s
	style.body_text_scale *= s
	style.small_text_height *= s
	style.small_line_height *= s
	style.small_char_width *= s
	style.small_text_scale *= s
	style.control_padding *= s
	style.margin *= s
	style.section_gap *= s
	style.scrollbar_width *= s
	style.focus_ring_width *= s
	style.row_height *= s
	style.text_height *= s
	style.char_width *= s
	style.text_scale *= s
	style.panel_padding *= s
	style.radius_panel *= s
	style.radius_control *= s
	style.border_width *= s
	style.shadow_blur *= s
	style.shadow_offset.x *= s
	style.shadow_offset.y *= s
	return style
}

gui_snap :: proc(v: f32) -> f32 {
	return math.floor(v + 0.5)
}

gui_h_fraction :: proc(viewport_height, denominator: f32) -> f32 {
	return viewport_height / max(denominator, 1)
}

gui_style_text_scale_for_height :: proc(height: f32) -> f32 {
	return height / GUI_FONT_LOGICAL_HEIGHT
}

gui_style_for_viewport :: proc(base: Gui_Style, width, height, ui_scale: f32) -> Gui_Style {
	_ = width
	viewport_h := max(height, 480)
	scale := min(max(ui_scale, 0.5), 3.0)
	style := base

	display_h := gui_snap(gui_h_fraction(viewport_h, 12) * scale)
	heading_h := gui_snap(gui_h_fraction(viewport_h, 24) * scale)
	body_h := gui_snap(gui_h_fraction(viewport_h, 36) * scale)
	small_h := gui_snap(gui_h_fraction(viewport_h, 48) * scale)

	body_line := gui_snap(body_h * 1.25)
	heading_line := gui_snap(max(heading_h * 1.25, body_line))
	display_line := gui_snap(max(display_h * 1.15, heading_line))
	small_line := gui_snap(max(small_h * 1.25, body_line * 0.75))
	rhythm := body_line

	style.display_text_height = display_h
	style.display_line_height = display_line
	style.display_text_scale = gui_style_text_scale_for_height(display_h)
	style.display_char_width = base.char_width * style.display_text_scale / base.text_scale

	style.heading_text_height = heading_h
	style.heading_line_height = heading_line
	style.heading_text_scale = gui_style_text_scale_for_height(heading_h)
	style.heading_char_width = base.char_width * style.heading_text_scale / base.text_scale

	style.body_text_height = body_h
	style.body_line_height = body_line
	style.body_text_scale = gui_style_text_scale_for_height(body_h)
	style.body_char_width = base.char_width * style.body_text_scale / base.text_scale

	style.small_text_height = small_h
	style.small_line_height = small_line
	style.small_text_scale = gui_style_text_scale_for_height(small_h)
	style.small_char_width = base.char_width * style.small_text_scale / base.text_scale

	style.rhythm = rhythm
	style.spacing_1 = gui_snap(rhythm * 0.25)
	style.spacing_2 = gui_snap(rhythm * 0.5)
	style.spacing_3 = rhythm
	style.spacing_4 = gui_snap(rhythm * 1.5)
	style.spacing = style.spacing_2
	style.section_gap = style.spacing_3
	style.control_padding = style.spacing_1
	style.margin = style.spacing_2
	style.panel_padding = style.spacing_2
	style.row_height = gui_snap(body_line + style.control_padding * 2)
	style.text_height = style.body_text_height
	style.char_width = style.body_char_width
	style.text_scale = style.body_text_scale
	style.radius_panel = max(gui_snap(rhythm * 0.10), 3)
	style.radius_control = max(gui_snap(rhythm * 0.10), 3)
	style.border_width = min(max(gui_snap(rhythm * 0.03), 1), 3)
	style.scrollbar_width = min(max(gui_snap(rhythm * 0.15), 4), 12)
	style.focus_ring_width = min(max(gui_snap(rhythm * 0.05), 2), 5)
	style.shadow_blur = gui_snap(rhythm * 0.25)
	style.shadow_offset = {0, gui_snap(rhythm * 0.08)}
	return style
}

gui_init :: proc(ctx: ^Gui_Context) {
	ctx.commands = make([dynamic]Draw_Command, 0, 256)
	ctx.style = gui_default_style()
	sync.once_do(&gui_text_shaper_once, gui_init_text_shaper)
}

gui_destroy :: proc(ctx: ^Gui_Context) {
	delete(ctx.commands)
}

gui_init_text_shaper :: proc() {
	body_ready := vo_textshape_init(i32(Gui_Font_Kind.Body), GUI_BODY_FONT_PATH, GUI_FONT_LOGICAL_HEIGHT) != 0
	display_ready := vo_textshape_init(i32(Gui_Font_Kind.Display), GUI_DISPLAY_FONT_PATH, GUI_FONT_LOGICAL_HEIGHT) != 0
	sim_start_ready := vo_textshape_init(i32(Gui_Font_Kind.SimStart), GUI_SIM_START_FONT_PATH, GUI_FONT_LOGICAL_HEIGHT) != 0
	gui_text_shaper_font_ready[int(Gui_Font_Kind.Body)] = body_ready
	gui_text_shaper_font_ready[int(Gui_Font_Kind.Display)] = display_ready
	gui_text_shaper_font_ready[int(Gui_Font_Kind.SimStart)] = sim_start_ready
	gui_text_shaper_ready = body_ready || display_ready || sim_start_ready
}

gui_font_kind_ready :: proc(font_kind: Gui_Font_Kind) -> bool {
	index := int(font_kind)
	return index >= 0 && index < len(gui_text_shaper_font_ready) && gui_text_shaper_font_ready[index]
}

gui_effective_font_kind :: proc(font_kind: Gui_Font_Kind) -> Gui_Font_Kind {
	if gui_font_kind_ready(font_kind) {
		return font_kind
	}
	if font_kind != .Body && gui_font_kind_ready(.Body) {
		return .Body
	}
	return font_kind
}

gui_begin_frame :: proc(ctx: ^Gui_Context, input: Input_State) {
	gui_profile_reset()
	clear(&ctx.commands)
	frame_input := input
	gui_input_apply_keyboard_fallbacks(&frame_input, ctx.input)
	ctx.previous_input = ctx.input
	if ctx.mouse_initialized {
		ctx.mouse_delta = {frame_input.mouse_pos.x - ctx.mouse_prev_pos.x, frame_input.mouse_pos.y - ctx.mouse_prev_pos.y}
	} else {
		ctx.mouse_delta = {}
		ctx.mouse_initialized = true
	}
	if frame_input.mouse_pressed {
		ctx.mouse_delta = {}
	}
	ctx.mouse_prev_pos = frame_input.mouse_pos
	ctx.input = frame_input
	ctx.hot = GUI_ID_NONE
	ctx.focus_order_next = 0
	ctx.focus_first = GUI_ID_NONE
	ctx.focus_prev = GUI_ID_NONE
	ctx.focus_last = GUI_ID_NONE
	ctx.focus_next_from = frame_input.focus_next ? ctx.focused : GUI_ID_NONE
	ctx.focus_moved = false
	ctx.focus_edit_seen = false
	ctx.spatial_item_count = 0
	ctx.spatial_group_depth = 0
	ctx.combo_popup_visible = false
	ctx.tooltip_visible = false
	ctx.layout_depth = 0
	ctx.input_clip_depth = 0
	ctx.next_overlay_input_rect_count = 0
	ctx.overlay_input_depth = 0
	ctx.scroll_depth = 0
	ctx.wheel_scroll_consumed = false
	ctx.wheel_scroll_depth = -1
	ctx.wheel_scroll_target_depth = -1
	if frame_input.wheel_delta != 0 {
		for i in 0 ..< ctx.scroll_hit_count {
			hit := ctx.scroll_hits[i]
			if gui_contains(hit.viewport, frame_input.mouse_pos) {
				scroll := min(max(hit.scroll, 0), hit.max_scroll)
				next_scroll := min(max(scroll - frame_input.wheel_delta * hit.step, 0), hit.max_scroll)
				if next_scroll != scroll && hit.depth >= ctx.wheel_scroll_target_depth {
					ctx.wheel_scroll_target_depth = hit.depth
				}
			}
		}
	}
	ctx.next_scroll_hit_count = 0
	ctx.id_depth = 0
	ctx.debug_registered_id_count = 0
	ctx.debug_duplicate_id_count = 0
	ctx.frame_index += 1
}

gui_input_apply_keyboard_fallbacks :: proc(input: ^Input_State, previous: Input_State) {
	if input.nav_x == 0 {
		if input.key_right {
			input.nav_x += 1
		}
		if input.key_left {
			input.nav_x -= 1
		}
	}
	if input.nav_y == 0 {
		if input.key_down {
			input.nav_y += 1
		}
		if input.key_up {
			input.nav_y -= 1
		}
	}
	if input.nav_pressed_x == 0 {
		if input.key_right && !previous.key_right {
			input.nav_pressed_x += 1
		}
		if input.key_left && !previous.key_left {
			input.nav_pressed_x -= 1
		}
	}
	if input.nav_pressed_y == 0 {
		if input.key_down && !previous.key_down {
			input.nav_pressed_y += 1
		}
		if input.key_up && !previous.key_up {
			input.nav_pressed_y -= 1
		}
	}
	input.accept = input.accept || input.key_enter
	input.back = input.back || input.key_escape
	input.focus_next = input.focus_next || (input.key_tab && !input.key_shift)
	input.focus_prev = input.focus_prev || (input.key_tab && input.key_shift)
	input.primary_down = input.primary_down || (input.mouse_down && input.mouse_button != 3)
	input.primary_pressed = input.primary_pressed || (input.mouse_pressed && input.mouse_button != 3)
	input.primary_released = input.primary_released || (input.mouse_released && input.mouse_button != 3)
	input.secondary_down = input.secondary_down || (input.mouse_down && input.mouse_button == 3)
	input.secondary_pressed = input.secondary_pressed || (input.mouse_pressed && input.mouse_button == 3)
	input.secondary_released = input.secondary_released || (input.mouse_released && input.mouse_button == 3)
}

gui_profile_reset :: proc() {
	gui_profile = {}
}

gui_profile_snapshot :: proc() -> Gui_Profile_Snapshot {
	return gui_profile
}

gui_end_frame :: proc(ctx: ^Gui_Context) {
	gui_draw_combo_popup_overlay(ctx)
	gui_draw_tooltip_overlay(ctx)
	ctx.overlay_input_rect_count = ctx.next_overlay_input_rect_count
	for i in 0 ..< ctx.overlay_input_rect_count {
		ctx.overlay_input_rects[i] = ctx.next_overlay_input_rects[i]
	}
	ctx.scroll_hit_count = ctx.next_scroll_hit_count
	for i in 0 ..< ctx.scroll_hit_count {
		ctx.scroll_hits[i] = ctx.next_scroll_hits[i]
	}
	if ctx.input.mouse_down == false {
		ctx.active = GUI_ID_NONE
	}
	if ctx.focus_edit_id != GUI_ID_NONE && ctx.input.back {
		ctx.focus_edit_id = GUI_ID_NONE
	}
	if ctx.focus_edit_id != GUI_ID_NONE && (!ctx.focus_edit_seen || ctx.focused != ctx.focus_edit_id || !gui_spatial_item_registered(ctx, ctx.focus_edit_id)) {
		ctx.focus_edit_id = GUI_ID_NONE
	}
	if ctx.input.focus_next && ctx.focus_first != GUI_ID_NONE {
		if ctx.focused == GUI_ID_NONE {
			ctx.focused = ctx.focus_first
		} else if ctx.focus_next_from != GUI_ID_NONE && !ctx.focus_moved {
			ctx.focused = ctx.focus_first
		}
	}
	gui_apply_spatial_navigation(ctx)
	ctx.focus_last_previous = ctx.focus_last
}

gui_spatial_group_begin :: proc(ctx: ^Gui_Context, key: string, options := Gui_Spatial_Group_Options{enabled = true}) {
	if ctx.spatial_group_depth >= MAX_GUI_SPATIAL_GROUP_DEPTH {
		return
	}
	parent_enabled := true
	if ctx.spatial_group_depth > 0 {
		parent_enabled = ctx.spatial_groups[ctx.spatial_group_depth - 1].enabled
	}
	ctx.spatial_groups[ctx.spatial_group_depth] = {
		id = gui_make_id(ctx, key),
		enabled = parent_enabled && options.enabled,
	}
	ctx.spatial_group_depth += 1
}

gui_spatial_group_end :: proc(ctx: ^Gui_Context) {
	if ctx.spatial_group_depth > 0 {
		ctx.spatial_group_depth -= 1
	}
}

gui_focus_editing :: proc(ctx: ^Gui_Context, id: Gui_Id) -> bool {
	if ctx.focus_edit_id == id {
		ctx.focus_edit_seen = true
	}
	return ctx.focus_edit_id == id
}

gui_focus_edit_begin :: proc(ctx: ^Gui_Context, id: Gui_Id) {
	ctx.focus_edit_id = id
	ctx.focus_edit_seen = true
}

gui_focus_edit_end :: proc(ctx: ^Gui_Context, id: Gui_Id) {
	if ctx.focus_edit_id == id {
		ctx.focus_edit_id = GUI_ID_NONE
	}
}

gui_begin_panel :: proc(ctx: ^Gui_Context, bounds: Rect) {
	ctx.next_cursor = {bounds.x + ctx.style.spacing, bounds.y + ctx.style.spacing}
	ctx.content_width = bounds.w - ctx.style.spacing * 2
	gui_rect(ctx, bounds, ctx.style.panel)
	gui_stroke(ctx, bounds, ctx.style.panel_border)
}

gui_panel_begin :: proc(ctx: ^Gui_Context, bounds: Rect) {
	gui_shadow(ctx, bounds, ctx.style.radius_panel, ctx.style.shadow_offset, ctx.style.shadow_blur, ctx.style.shadow_color)
	gui_refractive_glass_rect(ctx, bounds, gui_default_glass_style(ctx, ctx.style.radius_panel))
	gui_round_stroke(ctx, bounds, ctx.style.radius_panel, ctx.style.panel_border, ctx.style.border_width)
	gui_layout_begin(ctx, gui_inset(bounds, ctx.style.panel_padding), .Column, ctx.style.spacing, ctx.style.row_height)
}

gui_panel_end :: proc(ctx: ^Gui_Context) {
	gui_layout_end(ctx)
}

gui_layout_begin :: proc(ctx: ^Gui_Context, bounds: Rect, axis: Gui_Axis, gap, item_height: f32) {
	gui_layout_begin_ex(ctx, bounds, axis, gap, item_height, {}, .Stretch)
}

gui_layout_begin_ex :: proc(ctx: ^Gui_Context, bounds: Rect, axis: Gui_Axis, gap, item_height: f32, padding: Gui_Edge_Insets, align_cross: Gui_Align) {
	if ctx.layout_depth >= MAX_GUI_LAYOUT_DEPTH {
		return
	}
	content := gui_inset_edges(bounds, padding)
	ctx.layout_stack[ctx.layout_depth] = {
		bounds = content,
		cursor = {content.x, content.y},
		axis = axis,
		content_width = content.w,
		content_height = content.h,
		gap = gap,
		item_height = item_height,
		padding = padding,
		align_cross = align_cross,
	}
	ctx.layout_depth += 1
	ctx.next_cursor = {content.x, content.y}
	ctx.content_width = content.w
}

gui_layout_end :: proc(ctx: ^Gui_Context) {
	if ctx.layout_depth <= 0 {
		return
	}
	ctx.layout_depth -= 1
	if ctx.layout_depth > 0 {
		parent := &ctx.layout_stack[ctx.layout_depth - 1]
		ctx.next_cursor = parent.cursor
		ctx.content_width = parent.content_width
	}
}

gui_next_rect :: proc(ctx: ^Gui_Context, width := f32(-1), height := f32(-1), stretch_cross_axis := true) -> Rect {
	if ctx.layout_depth == 0 {
		return gui_next_row(ctx, width, height)
	}

	frame := &ctx.layout_stack[ctx.layout_depth - 1]
	w := width
	h := height
	if w <= 0 {
		w = frame.content_width
	}
	if h <= 0 {
		h = frame.item_height
	}

	rect := Rect{frame.cursor.x, frame.cursor.y, w, h}
	if frame.axis == .Column {
		switch frame.align_cross {
		case .Start:
		case .Center:
			rect.x = frame.bounds.x + max((frame.content_width - w) * 0.5, 0)
		case .End:
			rect.x = frame.bounds.x + max(frame.content_width - w, 0)
		case .Stretch:
			if stretch_cross_axis {
				rect.w = frame.content_width
			}
		}
	} else {
		switch frame.align_cross {
		case .Start:
		case .Center:
			rect.y = frame.bounds.y + max((frame.content_height - h) * 0.5, 0)
		case .End:
			rect.y = frame.bounds.y + max(frame.content_height - h, 0)
		case .Stretch:
			if stretch_cross_axis {
				rect.h = frame.content_height
			}
		}
	}
	switch frame.axis {
	case .Column:
		frame.cursor.y += h + frame.gap
	case .Row:
		frame.cursor.x += w + frame.gap
	}
	ctx.next_cursor = frame.cursor
	ctx.content_width = frame.content_width
	return rect
}

gui_row_begin :: proc(ctx: ^Gui_Context, height: f32) {
	row := gui_next_rect(ctx, height = height)
	gui_layout_begin(ctx, row, .Row, ctx.style.spacing, height)
}

gui_row_end :: proc(ctx: ^Gui_Context) {
	gui_layout_end(ctx)
}

gui_grid_begin :: proc(ctx: ^Gui_Context, bounds: Rect, columns: int, gap: f32) -> Gui_Grid {
	return {bounds = bounds, columns = max(columns, 1), gap = gap, index = 0}
}

Gui_Grid :: struct {
	bounds: Rect,
	columns: int,
	gap: f32,
	index: int,
}

gui_grid_next :: proc(grid: ^Gui_Grid, height: f32) -> Rect {
	col := grid.index % grid.columns
	row := grid.index / grid.columns
	width := (grid.bounds.w - grid.gap * f32(grid.columns - 1)) / f32(grid.columns)
	x := grid.bounds.x + f32(col) * (width + grid.gap)
	y := grid.bounds.y + f32(row) * (height + grid.gap)
	grid.index += 1
	return {x, y, width, height}
}

gui_breakpoint :: proc(width: f32) -> Gui_Breakpoint {
	if width < 640 {
		return .Compact
	}
	if width < 1024 {
		return .Medium
	}
	if width < 1440 {
		return .Expanded
	}
	return .Wide
}

gui_responsive_columns :: proc(width: f32, min_column_width: f32, max_columns: int, gap: f32) -> int {
	if min_column_width <= 0 {
		return max(max_columns, 1)
	}
	columns := int((width + gap) / (min_column_width + gap))
	return max(min(columns, max(max_columns, 1)), 1)
}

gui_distribute_equal :: proc(out: []Rect, bounds: Rect, axis: Gui_Axis, gap: f32, distribution: Gui_Distribution) {
	count := len(out)
	if count == 0 {
		return
	}
	total_gap := gap * f32(max(count - 1, 0))
	if distribution == .Space_Between && count > 1 {
		total_gap = 0
	}
	if axis == .Row {
		item_w := max((bounds.w - total_gap) / f32(count), 0)
		actual_gap := gap
		if distribution == .Space_Between && count > 1 {
			actual_gap = max((bounds.w - item_w * f32(count)) / f32(count - 1), 0)
		}
		x := bounds.x
		if distribution == .Center {
			x += max((bounds.w - item_w * f32(count) - actual_gap * f32(count - 1)) * 0.5, 0)
		} else if distribution == .End {
			x += max(bounds.w - item_w * f32(count) - actual_gap * f32(count - 1), 0)
		}
		for i in 0 ..< count {
			out[i] = {x + f32(i) * (item_w + actual_gap), bounds.y, item_w, bounds.h}
		}
	} else {
		item_h := max((bounds.h - total_gap) / f32(count), 0)
		actual_gap := gap
		if distribution == .Space_Between && count > 1 {
			actual_gap = max((bounds.h - item_h * f32(count)) / f32(count - 1), 0)
		}
		y := bounds.y
		if distribution == .Center {
			y += max((bounds.h - item_h * f32(count) - actual_gap * f32(count - 1)) * 0.5, 0)
		} else if distribution == .End {
			y += max(bounds.h - item_h * f32(count) - actual_gap * f32(count - 1), 0)
		}
		for i in 0 ..< count {
			out[i] = {bounds.x, y + f32(i) * (item_h + actual_gap), bounds.w, item_h}
		}
	}
}

gui_anchor_rect :: proc(parent: Rect, anchor: Gui_Anchor, offset: Gui_Edge_Insets, fallback_size: Vec2) -> Rect {
	x0 := parent.x + parent.w * anchor.left + offset.left
	y0 := parent.y + parent.h * anchor.top + offset.top
	x1 := parent.x + parent.w * anchor.right - offset.right
	y1 := parent.y + parent.h * anchor.bottom - offset.bottom
	w := x1 - x0
	h := y1 - y0
	if anchor.left == anchor.right {
		w = fallback_size.x
	}
	if anchor.top == anchor.bottom {
		h = fallback_size.y
	}
	return {x0, y0, max(w, 0), max(h, 0)}
}

gui_restore_ancestor_wheel_scrolls :: proc(ctx: ^Gui_Context, depth: int) {
	if !ctx.wheel_scroll_consumed || depth <= ctx.wheel_scroll_depth {
		return
	}
	for i in 0 ..< ctx.scroll_depth {
		frame := &ctx.scroll_stack[i]
		if frame.wheel_consumed && frame.target_scroll != nil {
			frame.target_scroll^ = frame.previous_scroll
			frame.scroll = frame.previous_scroll
			frame.wheel_consumed = false
		}
	}
}

gui_record_scroll_hit :: proc(ctx: ^Gui_Context, viewport: Rect, scroll, max_scroll, step: f32, depth: int) {
	if ctx.next_scroll_hit_count >= MAX_GUI_SCROLL_HITS {
		return
	}
	ctx.next_scroll_hits[ctx.next_scroll_hit_count] = {
		viewport = viewport,
		scroll = scroll,
		max_scroll = max_scroll,
		step = step,
		depth = depth,
	}
	ctx.next_scroll_hit_count += 1
}

gui_apply_wheel_scroll :: proc(ctx: ^Gui_Context, viewport: Rect, scroll: ^f32, max_scroll, step: f32, depth: int) -> (previous_scroll: f32, consumed: bool) {
	previous_scroll = min(max(scroll^, 0), max_scroll)
	scroll^ = previous_scroll
	if !gui_contains(viewport, ctx.input.mouse_pos) || ctx.input.wheel_delta == 0 {
		return
	}
	if ctx.wheel_scroll_target_depth >= 0 && depth != ctx.wheel_scroll_target_depth {
		return
	}
	if ctx.wheel_scroll_consumed && depth <= ctx.wheel_scroll_depth {
		return
	}

	next_scroll := min(max(scroll^ - ctx.input.wheel_delta * step, 0), max_scroll)
	if next_scroll == scroll^ {
		return
	}

	gui_restore_ancestor_wheel_scrolls(ctx, depth)
	scroll^ = next_scroll
	ctx.wheel_scroll_consumed = true
	ctx.wheel_scroll_depth = depth
	consumed = true
	return
}

gui_scroll_begin :: proc(ctx: ^Gui_Context, viewport: Rect, content_height: f32, scroll: ^f32) {
	max_scroll := max(content_height - viewport.h, 0)
	previous_scroll, consumed_wheel := gui_apply_wheel_scroll(ctx, viewport, scroll, max_scroll, 32, ctx.scroll_depth)
	scroll^ = min(max(scroll^, 0), max_scroll)
	gui_record_scroll_hit(ctx, viewport, scroll^, max_scroll, 32, ctx.scroll_depth)
	visible_scroll := scroll^
	if ctx.input.delta_time > 0 {
		scroll_id := gui_id_child_int(gui_make_id(ctx, "scroll"), ctx.scroll_depth)
		slot := gui_animation_slot(ctx, scroll_id)
		if slot != nil {
			if slot.last_frame == 0 {
				slot.value = min(max(previous_scroll, 0), max_scroll)
			}
			slot.value = gui_animate_towards(slot.value, scroll^, 18, ctx.input.delta_time)
			slot.value = min(max(slot.value, 0), max_scroll)
			slot.last_frame = ctx.frame_index
			visible_scroll = slot.value
		}
	}

	if ctx.scroll_depth < MAX_GUI_SCROLL_DEPTH {
		ctx.scroll_stack[ctx.scroll_depth] = {
			viewport = viewport,
			content_height = content_height,
			scroll = visible_scroll,
			previous_scroll = previous_scroll,
			target_scroll = scroll,
			wheel_consumed = consumed_wheel,
		}
		ctx.scroll_depth += 1
	}

	gui_scissor_begin(ctx, viewport)
	gui_input_clip_begin(ctx, viewport)
	content := Rect{viewport.x, viewport.y - visible_scroll, viewport.w, max(content_height, viewport.h)}
	gui_layout_begin(ctx, content, .Column, ctx.style.spacing, ctx.style.row_height)
}

gui_scroll_end :: proc(ctx: ^Gui_Context) {
	gui_layout_end(ctx)
	gui_input_clip_end(ctx)
	gui_scissor_end(ctx)

	if ctx.scroll_depth <= 0 {
		return
	}
	ctx.scroll_depth -= 1
	frame := ctx.scroll_stack[ctx.scroll_depth]
	gui_scroll_edge_fades(ctx, frame.viewport, frame.content_height, frame.scroll)
	gui_scrollbar(ctx, frame.viewport, frame.content_height, frame.scroll)
}

gui_scroll_edge_fades :: proc(ctx: ^Gui_Context, viewport: Rect, content_height, scroll: f32) {
	max_scroll := max(content_height - viewport.h, 0)
	if max_scroll <= 0 || viewport.h <= 0 || viewport.w <= 0 {
		return
	}
	fade_h := min(min(max(ctx.style.rhythm * 0.55, 8), 18), viewport.h * 0.5)
	if fade_h <= 0 {
		return
	}

	edge := Color{0, 0, 0, 0.34}
	clear := Color{0, 0, 0, 0}
	if scroll > 0.5 {
		gui_gradient_rect(ctx, {viewport.x, viewport.y, viewport.w, fade_h}, edge, clear)
	}
	if scroll < max_scroll - 0.5 {
		gui_gradient_rect(ctx, {viewport.x, viewport.y + viewport.h - fade_h, viewport.w, fade_h}, clear, edge)
	}
}

gui_label :: proc(ctx: ^Gui_Context, text: string) {
	bounds := gui_next_rect(ctx, height = ctx.style.body_line_height)
	gui_text_clipped(ctx, bounds, {bounds.x + ctx.style.spacing_1, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, text, ctx.style.text_muted)
}

gui_heading :: proc(ctx: ^Gui_Context, text: string) {
	bounds := gui_next_rect(ctx, height = ctx.style.heading_line_height)
	gui_scissor_begin(ctx, bounds)
	append(&ctx.commands, Draw_Command{
		kind = .Text,
		rect = {bounds.x + ctx.style.spacing_1, bounds.y + max((bounds.h - ctx.style.heading_text_height) * 0.5, 0), 0, 0},
		color = ctx.style.text,
		text = text,
		text_scale = ctx.style.heading_text_scale,
		text_align = .Left,
		font_kind = .Display,
	})
	gui_scissor_end(ctx)
	line_y := bounds.y + bounds.h - ctx.style.border_width
	gui_rect(ctx, {bounds.x, line_y, bounds.w, ctx.style.border_width}, {1, 1, 1, 0.20})
}

gui_text_block :: proc(ctx: ^Gui_Context, text: string, max_width: f32, color: Color) {
	wrap_width := max(max_width - ctx.style.spacing_1, ctx.style.body_char_width)
	lines := gui_wrap_line_count(ctx, text, wrap_width)
	bounds := gui_next_rect(ctx, height = f32(lines) * ctx.style.body_line_height)
	gui_scissor_begin(ctx, bounds)
	gui_text_wrapped_at(ctx, {bounds.x + ctx.style.spacing_1, bounds.y + max((ctx.style.body_line_height - ctx.style.body_text_height) * 0.5, 0)}, text, wrap_width, color)
	gui_scissor_end(ctx)
}

gui_spacer :: proc(ctx: ^Gui_Context, height: f32) {
	_ = gui_next_rect(ctx, height = height)
}

gui_disabled_button :: proc(ctx: ^Gui_Context, label: string) {
	bounds := gui_next_rect(ctx, width = gui_button_content_width(ctx, label), stretch_cross_axis = false)
	color := ctx.style.control_disabled
	text_color := Color{ctx.style.text.r * 0.55, ctx.style.text.g * 0.55, ctx.style.text.b * 0.55, 0.95}
	gui_round_rect(ctx, bounds, ctx.style.radius_control, color)
	gui_round_stroke(ctx, bounds, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)
	gui_text(ctx, {bounds.x + ctx.style.control_padding * 1.5, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, label, text_color)
}

gui_button :: gui_button_keyed

gui_button_keyed :: proc(ctx: ^Gui_Context, label, key: string) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx, width = gui_button_content_width(ctx, label), stretch_cross_axis = false)
	return gui_button_at(ctx, id, bounds, label, true)
}

gui_button_content_width :: proc(ctx: ^Gui_Context, label: string) -> f32 {
	text_w := gui_text_width(ctx, label)
	return max(text_w + ctx.style.control_padding * 3, ctx.style.row_height)
}

gui_button_at :: proc(ctx: ^Gui_Context, id: Gui_Id, bounds: Rect, label: string, enabled: bool) -> bool {
	control := gui_control(ctx, id, bounds, enabled)

	color := ctx.style.control
	border := ctx.style.panel_border
	stroke_width := ctx.style.border_width
	text_color := enabled ? ctx.style.text : ctx.style.text_muted
	if !enabled {
		color = ctx.style.control_disabled
	} else if ctx.active == id {
		color = gui_lerp_color(ctx.style.control_hot, ctx.style.accent, 0.18)
		border = gui_apply_opacity(ctx.style.accent, 0.62)
		stroke_width = max(ctx.style.border_width * 2, 2)
	} else if ctx.hot == id || control.focused {
		color = ctx.style.control_hot
		border = control.focused ? gui_apply_opacity(ctx.style.accent, 0.78) : gui_apply_opacity(ctx.style.text, 0.46)
		if control.focused {
			stroke_width = max(ctx.style.border_width * 2, 2)
		}
	}
	if enabled && ctx.input.delta_time > 0 {
		hot_t := gui_animate_value(ctx, id, (ctx.hot == id || ctx.active == id) ? f32(1) : f32(0), 10)
		target := ctx.active == id ? gui_lerp_color(ctx.style.control_hot, ctx.style.accent, 0.18) : ctx.style.control_hot
		color = gui_lerp_color(ctx.style.control, target, hot_t)
	}

	gui_shadow(ctx, bounds, ctx.style.radius_control, ctx.style.shadow_offset, ctx.style.shadow_blur * 0.42, {0, 0, 0, enabled ? f32(0.18) : f32(0.08)})
	gui_round_rect(ctx, bounds, ctx.style.radius_control, color)
	gui_round_stroke(ctx, bounds, ctx.style.radius_control, border, stroke_width)
	if ctx.focused == id {
		gui_focus_ring(ctx, bounds)
	}
	inset := ctx.style.control_padding
	if len(label) > 0 {
		text_rect := gui_inset(bounds, inset)
		gui_scissor_begin(ctx, text_rect)
		gui_text_centered(ctx, text_rect, label, text_color)
		gui_scissor_end(ctx)
	}

	return control.activated || (enabled && control.hovered && ctx.active == id && ctx.input.mouse_released)
}

gui_card_button :: gui_card_button_keyed

gui_card_button_keyed :: proc(ctx: ^Gui_Context, bounds: Rect, title, key, subtitle: string, enabled := true) -> bool {
	id := gui_make_id(ctx, key)
	clicked := gui_button_at(ctx, id, bounds, "", enabled)
	title_color := enabled ? ctx.style.text : Color{ctx.style.text.r * 0.55, ctx.style.text.g * 0.55, ctx.style.text.b * 0.55, 1}
	subtitle_color := enabled ? ctx.style.text_muted : Color{0.45, 0.48, 0.52, 1}
	text_rect := gui_inset(bounds, ctx.style.spacing_2)
	title_y := bounds.y + ctx.style.spacing_2
	gui_text_clipped(ctx, text_rect, {bounds.x + 16, title_y}, title, title_color)
	gui_text_clipped(ctx, text_rect, {bounds.x + 16, title_y + ctx.style.body_line_height}, subtitle, subtitle_color)
	return clicked
}

gui_toggle :: gui_toggle_keyed

gui_toggle_keyed :: proc(ctx: ^Gui_Context, label, key: string, value: ^bool) -> bool {
	return gui_switch_keyed(ctx, label, key, value)
}

gui_number_drag_f32 :: gui_number_drag_f32_keyed

gui_number_drag_f32_keyed :: proc(ctx: ^Gui_Context, label, key: string, value: ^f32, speed, min, max_value: f32, enabled := true) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	if !enabled {
		if ctx.focused == id {
			ctx.focused = GUI_ID_NONE
		}
		if ctx.active == id {
			ctx.active = GUI_ID_NONE
		}
		if ctx.text_edit_id == id {
			ctx.text_edit_id = GUI_ID_NONE
			ctx.text_edit_len = 0
		}
		gui_round_rect(ctx, bounds, ctx.style.radius_control, ctx.style.control_disabled)
		gui_round_stroke(ctx, bounds, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)
		gui_text_clipped(ctx, gui_inset(bounds, ctx.style.control_padding), {bounds.x + ctx.style.control_padding * 1.5, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, label, ctx.style.text_muted)
		return false
	}
	control := gui_control(ctx, id, bounds, true)
	changed := false
	editing := ctx.text_edit_id == id
	start_edit := control.focused && !editing && gui_number_edit_wants_text(ctx)
	if control.focused && !editing && ctx.input.key_space {
		gui_focus_edit_begin(ctx, id)
	} else if !control.focused {
		gui_focus_edit_end(ctx, id)
	}

	if ctx.active == id && ctx.input.mouse_down && !editing {
		delta := ctx.input.wheel_delta * speed + ctx.mouse_delta.x * speed * 0.1
		value^ += delta
		if value^ < min do value^ = min
		if value^ > max_value do value^ = max_value
		changed = delta != 0
		if changed && ctx.text_edit_id == id {
			gui_number_edit_set_value(ctx, value^)
			ctx.text_edit_caret = ctx.text_edit_len
			ctx.text_edit_anchor = 0
		}
	}
	if !editing && !start_edit && gui_focus_editing(ctx, id) && (ctx.input.nav_x != 0 || ctx.input.nav_y != 0) {
		value^ += (ctx.input.nav_x - ctx.input.nav_y) * speed
		if value^ < min do value^ = min
		if value^ > max_value do value^ = max_value
		changed = true
		if ctx.text_edit_id == id {
			gui_number_edit_set_value(ctx, value^)
			ctx.text_edit_caret = ctx.text_edit_len
			ctx.text_edit_anchor = 0
		}
	}
	if control.focused && (editing || start_edit) {
		if start_edit && ctx.input.accept {
			gui_focus_edit_end(ctx, id)
			gui_number_edit_begin(ctx, id, value^)
		} else {
			if editing {
				text_pos := Vec2{bounds.x + ctx.style.control_padding * 1.5, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}
				gui_text_edit_handle_mouse(ctx, id, ctx.text_edit_buffer[:], ctx.text_edit_len, bounds, text_pos)
			}
			edit_changed := gui_number_edit_f32(ctx, id, value, min, max_value)
			changed = changed || edit_changed
		}
	} else if ctx.text_edit_id == id {
		ctx.text_edit_id = GUI_ID_NONE
		ctx.text_edit_len = 0
	}

	gui_text_field_chrome(ctx, bounds, ctx.active == id, ctx.hot == id, control.focused)
	display_label := label
	if ctx.text_edit_id == id {
		display_label = string(ctx.text_edit_buffer[:ctx.text_edit_len])
	}
	if control.focused && ctx.text_edit_id == id {
		gui_text_edit_keep_caret_visible(ctx, ctx.text_edit_buffer[:], ctx.text_edit_len, gui_inset(bounds, ctx.style.control_padding * 2))
		gui_text_edit_draw(ctx, bounds, {bounds.x + ctx.style.control_padding * 1.5, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, ctx.text_edit_buffer[:], ctx.text_edit_len, label, true)
	} else {
		gui_text_clipped(ctx, gui_inset(bounds, ctx.style.control_padding), {bounds.x + ctx.style.control_padding * 1.5, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, display_label, ctx.style.text)
	}
	return changed
}

gui_slider_f32 :: gui_slider_f32_keyed

gui_slider_height :: proc(ctx: ^Gui_Context) -> f32 {
	return max(ctx.style.row_height, ctx.style.body_line_height + ctx.style.spacing_2 + ctx.style.control_padding * 2)
}

gui_slider_f32_keyed :: proc(ctx: ^Gui_Context, label, key: string, value: ^f32, min, max_value: f32) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx, height = gui_slider_height(ctx))
	changed := false
	t := gui_clamp01((value^ - min) / max(max_value - min, 0.000001))
	label_h := ctx.style.body_line_height
	handle_radius := max(ctx.style.control_padding, f32(8))
	track_inset := max(handle_radius, ctx.style.spacing_2)
	track_h := max(ctx.style.border_width * 3, f32(6))
	track := Rect{bounds.x + track_inset, bounds.y + label_h + ctx.style.spacing_2, max(bounds.w - track_inset * 2, 1), track_h}
	handle := Vec2{track.x + track.w * t, track.y + track.h * 0.5}

	if gui_drag_handle_region(ctx, id, bounds, handle, 12) {
		t = (ctx.input.mouse_pos.x - track.x) / max(track.w, 1)
		t = gui_clamp01(t)
		value^ = min + (max_value - min) * t
		changed = true
	}
	_ = gui_update_focus_edit(ctx, id, ctx.focused == id)
	nav_x, nav_y := gui_focused_nav(ctx, id)
	if nav_x != 0 || nav_y != 0 {
		step := (max_value - min) * 0.05
		value^ += (nav_x - nav_y) * step
		if value^ < min do value^ = min
		if value^ > max_value do value^ = max_value
		changed = true
	}

	t = gui_clamp01((value^ - min) / max(max_value - min, 0.000001))
	fill := track
	fill.w *= t
	handle = Vec2{track.x + track.w * t, track.y + track.h * 0.5}

	gui_text_clipped(ctx, {bounds.x, bounds.y, bounds.w, label_h}, {bounds.x + ctx.style.spacing_1, bounds.y + max((label_h - ctx.style.body_text_height) * 0.5, 0)}, label, ctx.style.text_muted)
	gui_round_rect(ctx, track, track.h * 0.5, ctx.style.control)
	gui_round_rect(ctx, fill, track.h * 0.5, ctx.style.accent)
	gui_round_stroke(ctx, track, track.h * 0.5, ctx.style.panel_border, ctx.style.border_width)
	gui_draw_handle(ctx, handle, handle_radius)
	if ctx.focused == id {
		gui_focus_ring(ctx, bounds)
	}

	return changed
}

gui_text_input :: gui_text_input_keyed

gui_text_edit_begin :: proc(ctx: ^Gui_Context, id: Gui_Id, length: int) {
	if ctx.text_edit_id != id {
		ctx.text_edit_id = id
		ctx.text_edit_caret = length
		ctx.text_edit_anchor = length
		ctx.text_edit_scroll_x = 0
		ctx.text_edit_blink = 0
		ctx.text_edit_selecting = false
	}
}

gui_text_edit_clamp :: proc(ctx: ^Gui_Context, length: int) {
	ctx.text_edit_caret = gui_utf8_clamp_index(ctx.text_edit_caret, length)
	ctx.text_edit_anchor = gui_utf8_clamp_index(ctx.text_edit_anchor, length)
}

gui_text_edit_has_selection :: proc(ctx: ^Gui_Context) -> bool {
	return ctx.text_edit_caret != ctx.text_edit_anchor
}

gui_text_edit_selection :: proc(ctx: ^Gui_Context) -> (start, end: int) {
	if ctx.text_edit_caret < ctx.text_edit_anchor {
		return ctx.text_edit_caret, ctx.text_edit_anchor
	}
	return ctx.text_edit_anchor, ctx.text_edit_caret
}

gui_text_edit_clear_selection :: proc(ctx: ^Gui_Context) {
	ctx.text_edit_anchor = ctx.text_edit_caret
}

gui_text_edit_delete_range :: proc(buffer: []u8, length: ^int, start, end: int) -> bool {
	range_start := max(min(start, length^), 0)
	range_end := max(min(end, length^), range_start)
	if range_start >= range_end {
		return false
	}
	count := length^ - range_end
	for i in 0 ..< count {
		buffer[range_start + i] = buffer[range_end + i]
	}
	length^ -= range_end - range_start
	if length^ < len(buffer) {
		buffer[length^] = 0
	}
	return true
}

gui_text_edit_delete_selection :: proc(ctx: ^Gui_Context, buffer: []u8, length: ^int) -> bool {
	if !gui_text_edit_has_selection(ctx) {
		return false
	}
	start, end := gui_text_edit_selection(ctx)
	if gui_text_edit_delete_range(buffer, length, start, end) {
		ctx.text_edit_caret = start
		ctx.text_edit_anchor = start
		return true
	}
	return false
}

gui_text_edit_insert_bytes :: proc(ctx: ^Gui_Context, buffer: []u8, length: ^int, bytes: []u8, numeric := false) -> bool {
	if len(buffer) == 0 || len(bytes) == 0 {
		return false
	}
	changed := gui_text_edit_delete_selection(ctx, buffer, length)
	for ch in bytes {
		if ch < 32 {
			continue
		}
		if numeric && !gui_number_edit_accepts_char(ch) {
			continue
		}
		if length^ >= len(buffer) {
			break
		}
		for i := length^; i > ctx.text_edit_caret; i -= 1 {
			buffer[i] = buffer[i - 1]
		}
		buffer[ctx.text_edit_caret] = ch
		length^ += 1
		ctx.text_edit_caret += 1
		ctx.text_edit_anchor = ctx.text_edit_caret
		changed = true
	}
	if length^ < len(buffer) {
		buffer[length^] = 0
	}
	return changed
}

gui_text_edit_set_clipboard :: proc(ctx: ^Gui_Context, bytes: []u8) {
	ctx.clipboard_set_len = min(len(bytes), len(ctx.clipboard_set_text) - 1)
	for i in 0 ..< ctx.clipboard_set_len {
		ctx.clipboard_set_text[i] = bytes[i]
	}
	if len(ctx.clipboard_set_text) > 0 {
		ctx.clipboard_set_text[ctx.clipboard_set_len] = 0
	}
	ctx.clipboard_set_pending = ctx.clipboard_set_len > 0
}

gui_text_edit_copy_selection :: proc(ctx: ^Gui_Context, buffer: []u8) {
	if !gui_text_edit_has_selection(ctx) {
		return
	}
	start, end := gui_text_edit_selection(ctx)
	gui_text_edit_set_clipboard(ctx, buffer[start:end])
}

gui_text_edit_move_caret :: proc(ctx: ^Gui_Context, length: int, caret: int, extend: bool) {
	ctx.text_edit_caret = gui_utf8_clamp_index(caret, length)
	if !extend {
		ctx.text_edit_anchor = ctx.text_edit_caret
	}
	ctx.text_edit_blink = 0
}

gui_text_edit_is_word_char :: proc(ch: u8) -> bool {
	switch ch {
	case 'a'..='z', 'A'..='Z', '0'..='9', '_':
		return true
	}
	return false
}

gui_text_edit_prev_word_index :: proc(bytes: []u8, index: int) -> int {
	i := gui_utf8_clamp_index(index, len(bytes))
	for i > 0 {
		prev := gui_utf8_prev_index(bytes, i)
		if gui_text_edit_is_word_char(bytes[prev]) {
			break
		}
		i = prev
	}
	for i > 0 {
		prev := gui_utf8_prev_index(bytes, i)
		if !gui_text_edit_is_word_char(bytes[prev]) {
			break
		}
		i = prev
	}
	return i
}

gui_text_edit_next_word_index :: proc(bytes: []u8, index: int) -> int {
	i := gui_utf8_clamp_index(index, len(bytes))
	for i < len(bytes) {
		if gui_text_edit_is_word_char(bytes[i]) {
			break
		}
		i = gui_utf8_next_index(bytes, i)
	}
	for i < len(bytes) {
		if !gui_text_edit_is_word_char(bytes[i]) {
			break
		}
		i = gui_utf8_next_index(bytes, i)
	}
	return i
}

gui_text_edit_process :: proc(ctx: ^Gui_Context, id: Gui_Id, buffer: []u8, length: ^int, numeric := false) -> bool {
	gui_text_edit_begin(ctx, id, length^)
	gui_text_edit_clamp(ctx, length^)
	changed := false
	modifier := ctx.input.key_ctrl || ctx.input.key_super

	if ctx.input.back || ctx.input.accept {
		ctx.focused = GUI_ID_NONE
		ctx.text_edit_selecting = false
		return false
	}

	if modifier && ctx.input.key_a {
		ctx.text_edit_caret = length^
		ctx.text_edit_anchor = 0
		ctx.text_edit_blink = 0
	}
	if modifier && ctx.input.key_c {
		gui_text_edit_copy_selection(ctx, buffer[:length^])
	}
	if modifier && ctx.input.key_x {
		gui_text_edit_copy_selection(ctx, buffer[:length^])
		if gui_text_edit_delete_selection(ctx, buffer, length) {
			changed = true
		}
	}
	if modifier && ctx.input.key_v && ctx.input.clipboard_paste_len > 0 {
		changed = gui_text_edit_insert_bytes(ctx, buffer, length, ctx.input.clipboard_paste[:ctx.input.clipboard_paste_len], numeric) || changed
	}

	if ctx.input.key_home {
		gui_text_edit_move_caret(ctx, length^, 0, ctx.input.key_shift)
	}
	if ctx.input.key_end {
		gui_text_edit_move_caret(ctx, length^, length^, ctx.input.key_shift)
	}
	if ctx.input.key_left {
		if ctx.input.key_super {
			gui_text_edit_move_caret(ctx, length^, 0, ctx.input.key_shift)
		} else if ctx.input.key_ctrl {
			gui_text_edit_move_caret(ctx, length^, gui_text_edit_prev_word_index(buffer[:length^], ctx.text_edit_caret), ctx.input.key_shift)
		} else if gui_text_edit_has_selection(ctx) && !ctx.input.key_shift {
			start, _ := gui_text_edit_selection(ctx)
			gui_text_edit_move_caret(ctx, length^, start, false)
		} else {
			gui_text_edit_move_caret(ctx, length^, gui_utf8_prev_index(buffer[:length^], ctx.text_edit_caret), ctx.input.key_shift)
		}
	}
	if ctx.input.key_right {
		if ctx.input.key_super {
			gui_text_edit_move_caret(ctx, length^, length^, ctx.input.key_shift)
		} else if ctx.input.key_ctrl {
			gui_text_edit_move_caret(ctx, length^, gui_text_edit_next_word_index(buffer[:length^], ctx.text_edit_caret), ctx.input.key_shift)
		} else if gui_text_edit_has_selection(ctx) && !ctx.input.key_shift {
			_, end := gui_text_edit_selection(ctx)
			gui_text_edit_move_caret(ctx, length^, end, false)
		} else {
			gui_text_edit_move_caret(ctx, length^, gui_utf8_next_index(buffer[:length^], ctx.text_edit_caret), ctx.input.key_shift)
		}
	}

	if ctx.input.key_backspace {
		if gui_text_edit_delete_selection(ctx, buffer, length) {
			changed = true
		} else if ctx.input.key_super && ctx.text_edit_caret > 0 {
			if gui_text_edit_delete_range(buffer, length, 0, ctx.text_edit_caret) {
				ctx.text_edit_caret = 0
				ctx.text_edit_anchor = 0
				changed = true
			}
		} else if ctx.input.key_ctrl && ctx.text_edit_caret > 0 {
			prev := gui_text_edit_prev_word_index(buffer[:length^], ctx.text_edit_caret)
			if gui_text_edit_delete_range(buffer, length, prev, ctx.text_edit_caret) {
				ctx.text_edit_caret = prev
				ctx.text_edit_anchor = prev
				changed = true
			}
		} else if ctx.text_edit_caret > 0 {
			prev := gui_utf8_prev_index(buffer[:length^], ctx.text_edit_caret)
			if gui_text_edit_delete_range(buffer, length, prev, ctx.text_edit_caret) {
				ctx.text_edit_caret = prev
				ctx.text_edit_anchor = prev
				changed = true
			}
		}
	}
	if ctx.input.key_delete {
		if gui_text_edit_delete_selection(ctx, buffer, length) {
			changed = true
		} else if ctx.input.key_super && ctx.text_edit_caret < length^ {
			if gui_text_edit_delete_range(buffer, length, ctx.text_edit_caret, length^) {
				ctx.text_edit_anchor = ctx.text_edit_caret
				changed = true
			}
		} else if ctx.input.key_ctrl && ctx.text_edit_caret < length^ {
			next := gui_text_edit_next_word_index(buffer[:length^], ctx.text_edit_caret)
			if gui_text_edit_delete_range(buffer, length, ctx.text_edit_caret, next) {
				ctx.text_edit_anchor = ctx.text_edit_caret
				changed = true
			}
		} else if ctx.text_edit_caret < length^ {
			next := gui_utf8_next_index(buffer[:length^], ctx.text_edit_caret)
			if gui_text_edit_delete_range(buffer, length, ctx.text_edit_caret, next) {
				ctx.text_edit_anchor = ctx.text_edit_caret
				changed = true
			}
		}
	}
	if ctx.input.text_input_len > 0 {
		changed = gui_text_edit_insert_bytes(ctx, buffer, length, ctx.input.text_input[:ctx.input.text_input_len], numeric) || changed
	}

	gui_text_edit_clamp(ctx, length^)
	return changed
}

gui_text_edit_hit_test :: proc(ctx: ^Gui_Context, buffer: []u8, x: f32) -> int {
	best := 0
	best_distance := abs(x)
	for i in 0 ..= len(buffer) {
		if i > 0 && gui_utf8_is_continuation(buffer[i - 1]) {
			continue
		}
		width := gui_text_width(ctx, string(buffer[:i]))
		distance := abs(width - x)
		if distance < best_distance {
			best = i
			best_distance = distance
		}
	}
	return best
}

gui_text_edit_handle_mouse :: proc(ctx: ^Gui_Context, id: Gui_Id, buffer: []u8, length: int, bounds: Rect, text_pos: Vec2) {
	if ctx.input.mouse_pressed && gui_mouse_contains(ctx, bounds) {
		local_x := ctx.input.mouse_pos.x - text_pos.x + ctx.text_edit_scroll_x
		ctx.text_edit_caret = gui_text_edit_hit_test(ctx, buffer[:length], local_x)
		if !ctx.input.key_shift {
			ctx.text_edit_anchor = ctx.text_edit_caret
		}
		ctx.text_edit_selecting = true
		ctx.text_edit_blink = 0
	} else if ctx.input.mouse_down && ctx.active == id && ctx.text_edit_selecting {
		local_x := ctx.input.mouse_pos.x - text_pos.x + ctx.text_edit_scroll_x
		ctx.text_edit_caret = gui_text_edit_hit_test(ctx, buffer[:length], local_x)
		ctx.text_edit_blink = 0
	}
	if ctx.input.mouse_released {
		ctx.text_edit_selecting = false
	}
}

gui_text_edit_keep_caret_visible :: proc(ctx: ^Gui_Context, buffer: []u8, length: int, rect: Rect) {
	caret_x := gui_text_width(ctx, string(buffer[:ctx.text_edit_caret]))
	padding := f32(8)
	if caret_x - ctx.text_edit_scroll_x > rect.w - padding {
		ctx.text_edit_scroll_x = caret_x - rect.w + padding
	}
	if caret_x - ctx.text_edit_scroll_x < 0 {
		ctx.text_edit_scroll_x = caret_x
	}
	ctx.text_edit_scroll_x = max(ctx.text_edit_scroll_x, 0)
}

gui_text_edit_draw :: proc(ctx: ^Gui_Context, rect: Rect, text_pos: Vec2, buffer: []u8, length: int, placeholder: string, focused: bool, trailing_inset := f32(0)) {
	display := string(buffer[:length])
	text_color := ctx.style.text
	if length == 0 {
		display = placeholder
		text_color = ctx.style.text_muted
	}
	clip := gui_inset_edges(rect, {left = ctx.style.control_padding, top = ctx.style.control_padding, right = ctx.style.control_padding + trailing_inset, bottom = ctx.style.control_padding})
	draw_pos := Vec2{text_pos.x - ctx.text_edit_scroll_x, text_pos.y}
	if focused && length > 0 && gui_text_edit_has_selection(ctx) {
		start, end := gui_text_edit_selection(ctx)
		x0 := draw_pos.x + gui_text_width(ctx, string(buffer[:start]))
		x1 := draw_pos.x + gui_text_width(ctx, string(buffer[:end]))
		gui_rect(ctx, {x0, rect.y + ctx.style.control_padding, max(x1 - x0, 1), max(rect.h - ctx.style.control_padding * 2, 1)}, {ctx.style.accent.r, ctx.style.accent.g, ctx.style.accent.b, 0.32})
	}
	gui_text_clipped(ctx, clip, draw_pos, display, text_color)
	if focused {
		ctx.text_edit_blink += ctx.input.delta_time
		if ctx.text_edit_blink > 1.0 {
			ctx.text_edit_blink -= 1.0
		}
		if ctx.text_edit_blink < 0.55 {
			caret_x := draw_pos.x + gui_text_width(ctx, string(buffer[:ctx.text_edit_caret]))
			caret_w := max(ctx.style.border_width * 2, 2)
			caret_h := max(ctx.style.body_text_height, rect.h - ctx.style.control_padding * 2)
			caret_y := rect.y + max((rect.h - caret_h) * 0.5, 0)
			gui_rect(ctx, {caret_x, caret_y, caret_w, caret_h}, ctx.style.accent)
		}
	}
}

gui_text_field_chrome :: proc(ctx: ^Gui_Context, bounds: Rect, active, hot, focused: bool) {
	color := ctx.style.control
	border := ctx.style.panel_border
	stroke_width := ctx.style.border_width
	if focused {
		color = gui_lerp_color(ctx.style.control, ctx.style.control_hot, active ? f32(0.45) : f32(0.22))
		border = gui_apply_opacity(ctx.style.accent, 0.78)
		stroke_width = max(ctx.style.border_width * 2, 2)
	} else if active {
		color = ctx.style.control_hot
	} else if hot {
		color = ctx.style.control_hot
	}
	gui_round_rect(ctx, bounds, ctx.style.radius_control, color)
	gui_round_stroke(ctx, bounds, ctx.style.radius_control, border, stroke_width)
	if focused {
		gui_focus_ring(ctx, bounds)
	}
}

gui_text_input_clear_rect :: proc(ctx: ^Gui_Context, bounds: Rect) -> Rect {
	size := min(max(bounds.h * 0.45, f32(18)), max(bounds.h - ctx.style.control_padding * 2, f32(12)))
	x := bounds.x + bounds.w - ctx.style.control_padding * 1.5 - size
	y := bounds.y + (bounds.h - size) * 0.5
	return {x, y, size, size}
}

gui_text_input_clear_hit_rect :: proc(ctx: ^Gui_Context, bounds: Rect) -> Rect {
	size := min(max(bounds.h * 0.72, f32(28)), bounds.h)
	x := bounds.x + bounds.w - ctx.style.control_padding - size
	y := bounds.y + (bounds.h - size) * 0.5
	return {x, y, size, size}
}

gui_text_input_body_rect :: proc(bounds, clear_hit: Rect, clear_visible: bool) -> Rect {
	if !clear_visible {
		return bounds
	}
	return {bounds.x, bounds.y, max(clear_hit.x - bounds.x, 0), bounds.h}
}

gui_text_input_draw_clear_button :: proc(ctx: ^Gui_Context, rect: Rect, hot, active: bool) {
	fill := Color{1, 1, 1, 0.24}
	if active {
		fill = Color{1, 1, 1, 0.36}
	} else if hot {
		fill = Color{1, 1, 1, 0.31}
	}
	gui_ellipse(ctx, rect, fill)
	center := Vec2{rect.x + rect.w * 0.5, rect.y + rect.h * 0.5}
	size := rect.w * 0.22
	line_color := Color{0.02, 0.025, 0.035, 0.82}
	gui_line(ctx, {center.x - size, center.y - size}, {center.x + size, center.y + size}, line_color, max(ctx.style.border_width * 1.6, 2))
	gui_line(ctx, {center.x + size, center.y - size}, {center.x - size, center.y + size}, line_color, max(ctx.style.border_width * 1.6, 2))
}

gui_text_input_keyed :: proc(ctx: ^Gui_Context, label, key: string, buffer: []u8, length: ^int) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	control := gui_control(ctx, id, bounds, true)
	changed := false

	if length^ < 0 {
		length^ = 0
	}
	if length^ > len(buffer) {
		length^ = len(buffer)
	}

	clear_visual := gui_text_input_clear_rect(ctx, bounds)
	clear_hit := gui_text_input_clear_hit_rect(ctx, bounds)
	clear_visible := length^ > 0 && (control.focused || control.hovered)
	clear_hot := clear_visible && gui_mouse_contains(ctx, clear_hit)
	clear_active := clear_hot && ctx.active == id && ctx.input.mouse_down
	clear_clicked := clear_hot && ctx.active == id && ctx.input.mouse_released
	body := gui_text_input_body_rect(bounds, clear_hit, clear_visible)
	text_pos := Vec2{bounds.x + ctx.style.control_padding * 1.5, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}

	if control.focused {
		gui_text_edit_begin(ctx, id, length^)
		if clear_clicked {
			length^ = 0
			if len(buffer) > 0 {
				buffer[0] = 0
			}
			ctx.text_edit_caret = 0
			ctx.text_edit_anchor = 0
			ctx.text_edit_scroll_x = 0
			ctx.text_edit_blink = 0
			changed = true
			clear_visible = false
		} else {
			gui_text_edit_handle_mouse(ctx, id, buffer, length^, body, text_pos)
			changed = gui_text_edit_process(ctx, id, buffer, length) || changed
		}
		trailing_inset := clear_visible ? max(bounds.x + bounds.w - clear_hit.x, 0) : f32(0)
		edit_view := gui_inset_edges(bounds, {left = ctx.style.control_padding * 2, top = ctx.style.control_padding * 2, right = ctx.style.control_padding * 2 + trailing_inset, bottom = ctx.style.control_padding * 2})
		gui_text_edit_keep_caret_visible(ctx, buffer, length^, edit_view)
	} else if ctx.text_edit_id == id {
		ctx.text_edit_id = GUI_ID_NONE
		ctx.text_edit_selecting = false
	}

	gui_text_field_chrome(ctx, bounds, ctx.active == id, ctx.hot == id, control.focused)
	trailing_inset := clear_visible ? max(bounds.x + bounds.w - clear_hit.x, 0) : f32(0)
	gui_text_edit_draw(ctx, bounds, text_pos, buffer, length^, label, control.focused, trailing_inset)
	if clear_visible {
		gui_text_input_draw_clear_button(ctx, clear_visual, clear_hot, clear_active)
	}
	return changed
}

gui_selector :: gui_selector_keyed

gui_selector_keyed :: proc(ctx: ^Gui_Context, label, key: string, current: ^int, options: []string) -> bool {
	if len(options) == 0 {
		return false
	}
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	current^ = max(min(current^, len(options) - 1), 0)
	arrow_w := min(max(bounds.h, f32(35)), bounds.w * 0.22)
	left := Rect{bounds.x, bounds.y, arrow_w, bounds.h}
	right := Rect{bounds.x + bounds.w - arrow_w, bounds.y, arrow_w, bounds.h}
	center := Rect{bounds.x + arrow_w, bounds.y, max(bounds.w - arrow_w * 2, 0), bounds.h}
	changed := false

	if gui_stepper_button_at(ctx, gui_id_child(id, "left"), left, -1, true) {
		current^ = (current^ - 1 + len(options)) % len(options)
		changed = true
	}
	gui_tooltip(ctx, left, "Previous option")
	center_control := gui_control(ctx, id, center, true)
	if center_control.activated {
		gui_focus_edit_begin(ctx, id)
	}
	if center_control.hovered && ctx.active == id && ctx.input.mouse_released {
		current^ = (current^ + 1) % len(options)
		changed = true
	}
	if gui_stepper_button_at(ctx, gui_id_child(id, "right"), right, 1, true) {
		current^ = (current^ + 1) % len(options)
		changed = true
	}
	gui_tooltip(ctx, right, "Next option")
	_ = gui_update_focus_edit(ctx, id, ctx.focused == id)
	nav_x, nav_y := gui_focused_nav_pressed(ctx, id)
	if nav_x != 0 || nav_y != 0 {
		delta := int(nav_x + nav_y)
		current^ = (current^ + delta + len(options)) % len(options)
		changed = true
	}
	center_fill := ctx.style.control
	if ctx.hot == id || ctx.focused == id {
		center_fill = {1, 1, 1, 0.15}
	}
	gui_rect(ctx, center, center_fill)
	gui_stroke(ctx, {center.x, center.y, center.w, center.h}, ctx.style.panel_border)
	text_y := center.y + max((center.h - ctx.style.body_text_height) * 0.5, 0)
	gui_text_clipped(ctx, gui_inset(center, 8), {center.x + 12, text_y}, label, ctx.style.text)
	if ctx.focused == id {
		gui_focus_ring(ctx, center)
	}
	return changed
}

gui_checkbox :: gui_checkbox_keyed

gui_checkbox_keyed :: proc(ctx: ^Gui_Context, label, key: string, value: ^bool) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	box_size := min(bounds.h - 10, f32(26))
	box := Rect{bounds.x + 8, bounds.y + (bounds.h - box_size) * 0.5, box_size, box_size}
	clicked := gui_button_behavior(ctx, id, bounds, true)
	if clicked {
		value^ = !value^
	}

	fill := ctx.style.control
	border := ctx.style.panel_border
	if ctx.hot == id {
		fill = ctx.style.control_hot
	}
	if ctx.active == id {
		fill = ctx.style.control_active
	}
	if value^ {
		fill = ctx.style.accent
		border = gui_apply_opacity(ctx.style.accent, 0.88)
		if ctx.hot == id || ctx.focused == id {
			fill = gui_lighten(ctx.style.accent, 0.08)
		}
		if ctx.active == id {
			fill = gui_lighten(ctx.style.accent, 0.14)
		}
	}
	gui_round_rect(ctx, box, 4, fill)
	gui_round_stroke(ctx, box, 4, border, ctx.style.border_width)
	if value^ {
		check_color := Color{1, 1, 1, 0.95}
		gui_line(ctx, {box.x + box.w * 0.23, box.y + box.h * 0.52}, {box.x + box.w * 0.43, box.y + box.h * 0.72}, check_color, max(ctx.style.border_width * 2, 2))
		gui_line(ctx, {box.x + box.w * 0.43, box.y + box.h * 0.72}, {box.x + box.w * 0.78, box.y + box.h * 0.28}, check_color, max(ctx.style.border_width * 2, 2))
	}
	if ctx.focused == id {
		gui_focus_ring(ctx, bounds)
	}
	gui_text_clipped(ctx, gui_inset_edges(bounds, {left = box_size + 20, top = 0, right = 8, bottom = 0}), {bounds.x + box_size + 24, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, label, ctx.style.text)
	return clicked
}

gui_switch :: gui_switch_keyed

gui_switch_keyed :: proc(ctx: ^Gui_Context, label, key: string, value: ^bool) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	track_h := min(max(bounds.h * 0.64, f32(28)), max(bounds.h - ctx.style.control_padding, f32(24)))
	track_w := max(track_h * 1.85, f32(54))
	track := Rect{bounds.x + 8, bounds.y + (bounds.h - track_h) * 0.5, track_w, track_h}
	clicked := gui_button_behavior(ctx, id, bounds, true)
	if clicked {
		value^ = !value^
	}

	t := value^ ? f32(1) : f32(0)
	if ctx.input.delta_time > 0 {
		t = gui_animate_value(ctx, gui_id_child(id, "switch-track"), t, 14)
	}
	track_color := gui_lerp_color(ctx.style.control, ctx.style.accent, t)
	track_border := ctx.style.panel_border
	if value^ {
		track_border = gui_apply_opacity(ctx.style.accent, 0.78)
	}
	if ctx.hot == id {
		track_color = value^ ? gui_lighten(ctx.style.accent, 0.08) : ctx.style.control_hot
	}
	if ctx.active == id {
		track_color = value^ ? gui_lighten(ctx.style.accent, 0.14) : ctx.style.control_active
	}
	gui_round_rect(ctx, track, track.h * 0.5, track_color)
	gui_round_stroke(ctx, track, track.h * 0.5, track_border, ctx.style.border_width)
	knob_padding := max(track.h * 0.14, f32(4))
	knob_size := max(track.h - knob_padding * 2, f32(12))
	knob_x := track.x + knob_padding + (track.w - knob_size - knob_padding * 2) * t
	knob := Rect{knob_x, track.y + knob_padding, knob_size, knob_size}
	gui_shadow(ctx, knob, knob_size * 0.5, {0, max(ctx.style.border_width, f32(1))}, ctx.style.shadow_blur * 0.35, {0, 0, 0, 0.26})
	gui_ellipse(ctx, knob, Color{1, 1, 1, 0.96})
	gui_ellipse_stroke(ctx, knob, gui_apply_opacity(ctx.style.panel_border, 0.68), ctx.style.border_width)
	if ctx.focused == id {
		gui_focus_ring(ctx, bounds)
	}
	label_left := track.x + track.w + ctx.style.spacing_2
	gui_text_clipped(ctx, gui_inset_edges(bounds, {left = label_left - bounds.x, top = 0, right = 8, bottom = 0}), {label_left, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, label, ctx.style.text)
	return clicked
}

gui_radio :: gui_radio_keyed

gui_radio_keyed :: proc(ctx: ^Gui_Context, label, key: string, selected: bool) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	size := min(bounds.h - 10, f32(26))
	circle := Rect{bounds.x + 8, bounds.y + (bounds.h - size) * 0.5, size, size}
	clicked := gui_button_behavior(ctx, id, bounds, true)
	fill := ctx.style.control
	border := ctx.style.panel_border
	if ctx.hot == id {
		fill = ctx.style.control_hot
	}
	if ctx.active == id {
		fill = ctx.style.control_active
	}
	if selected {
		border = gui_apply_opacity(ctx.style.accent, 0.88)
		if ctx.hot == id || ctx.focused == id {
			fill = gui_lerp_color(ctx.style.control, ctx.style.control_hot, 0.55)
		}
	}
	gui_ellipse(ctx, circle, fill)
	gui_ellipse_stroke(ctx, circle, border, selected ? max(ctx.style.border_width * 2, 2) : ctx.style.border_width)
	if selected {
		gui_ellipse(ctx, gui_inset(circle, max(size * 0.30, f32(6))), ctx.style.accent)
	}
	if ctx.focused == id {
		gui_focus_ring(ctx, bounds)
	}
	gui_text_clipped(ctx, gui_inset_edges(bounds, {left = size + 20, top = 0, right = 8, bottom = 0}), {bounds.x + size + 24, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, label, ctx.style.text)
	return clicked
}

gui_radio_group :: gui_radio_group_keyed

gui_radio_group_keyed :: proc(ctx: ^Gui_Context, label, key: string, current: ^int, options: []string) -> bool {
	if len(options) == 0 {
		return false
	}
	changed := false
	gui_label(ctx, label)
	group_id := gui_make_id(ctx, key)
	start_index := ctx.layout_depth > 0 ? ctx.layout_stack[ctx.layout_depth - 1].cursor : ctx.next_cursor
	group_bounds := Rect{start_index.x, start_index.y, 0, 0}
	row_bounds: [64]Rect
	option_count := min(len(options), len(row_bounds))
	for option, i in options {
		id := gui_id_child_int(group_id, i)
		bounds := gui_next_rect(ctx)
		if i < option_count {
			row_bounds[i] = bounds
		}
		if i == 0 {
			group_bounds = bounds
		} else {
			right := max(group_bounds.x + group_bounds.w, bounds.x + bounds.w)
			bottom := max(group_bounds.y + group_bounds.h, bounds.y + bounds.h)
			group_bounds.x = min(group_bounds.x, bounds.x)
			group_bounds.y = min(group_bounds.y, bounds.y)
			group_bounds.w = right - group_bounds.x
			group_bounds.h = bottom - group_bounds.y
		}
		size := min(bounds.h - 10, f32(24))
		circle := Rect{bounds.x + 8, bounds.y + (bounds.h - size) * 0.5, size, size}
		hovered := gui_mouse_contains(ctx, bounds)
		if hovered {
			ctx.hot = id
			if ctx.input.mouse_pressed {
				ctx.active = group_id
				ctx.focused = group_id
			}
		}
		clicked := hovered && ctx.active == group_id && ctx.input.mouse_released
		if clicked && current^ != i {
			current^ = i
			ctx.focused = group_id
			changed = true
		}
		fill := ctx.style.control
		border := ctx.style.panel_border
		if ctx.hot == id {
			fill = ctx.style.control_hot
		}
		if ctx.active == group_id {
			fill = ctx.style.control_active
		}
		if current^ == i {
			border = gui_apply_opacity(ctx.style.accent, 0.88)
			if ctx.hot == id || ctx.focused == group_id {
				fill = gui_lerp_color(ctx.style.control, ctx.style.control_hot, 0.55)
			}
		}
		gui_ellipse(ctx, circle, fill)
		gui_ellipse_stroke(ctx, circle, border, current^ == i ? max(ctx.style.border_width * 2, 2) : ctx.style.border_width)
		if current^ == i {
			gui_ellipse(ctx, gui_inset(circle, max(size * 0.30, f32(6))), ctx.style.accent)
		}
		gui_text_clipped(ctx, gui_inset_edges(bounds, {left = size + 20, top = 0, right = 8, bottom = 0}), {bounds.x + size + 24, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, option, ctx.style.text)
	}
	group_control := gui_control(ctx, group_id, group_bounds, true)
	if group_control.activated {
		current^ = (current^ + 1) % len(options)
		changed = true
	}
	if group_control.focused {
		nav_delta := int(ctx.input.nav_pressed_x + ctx.input.nav_pressed_y)
		if nav_delta != 0 {
			next := (current^ + nav_delta + len(options)) % len(options)
			if next != current^ {
				current^ = next
				changed = true
			}
		}
		focus_bounds := group_bounds
		if current^ >= 0 && current^ < option_count {
			focus_bounds = row_bounds[current^]
		}
		gui_focus_ring(ctx, focus_bounds)
	}
	return changed
}

gui_area_slider_f32 :: gui_area_slider_f32_keyed

gui_area_slider_f32_keyed :: proc(ctx: ^Gui_Context, label, key: string, value: ^Vec2, min_value, max_value: Vec2) -> bool {
	bounds := gui_next_rect(ctx, height = 160)
	gui_text_clipped(ctx, {bounds.x, bounds.y, bounds.w, ctx.style.row_height}, {bounds.x + 2, bounds.y + 4}, label, ctx.style.text)
	area := Rect{bounds.x, bounds.y + ctx.style.row_height, bounds.w, max(bounds.h - ctx.style.row_height, 1)}
	return gui_area_slider_f32_at(ctx, gui_make_id(ctx, key), area, value, min_value, max_value)
}

gui_area_slider_f32_at :: proc(ctx: ^Gui_Context, id: Gui_Id, area: Rect, value: ^Vec2, min_value, max_value: Vec2) -> bool {
	changed := false
	normalized := gui_vec2_to_normalized(value^, min_value, max_value)
	handle := gui_normalized_to_rect_point(area, normalized)
	if gui_drag_handle_region(ctx, id, area, handle, 10) {
		normalized := gui_rect_point_to_normalized(area, ctx.input.mouse_pos)
		value^ = gui_vec2_from_normalized(normalized, min_value, max_value)
		changed = true
	}
	_ = gui_update_focus_edit(ctx, id, ctx.focused == id)
	nav_x, nav_y := gui_focused_nav(ctx, id)
	if nav_x != 0 || nav_y != 0 {
		step := Vec2{(max_value.x - min_value.x) * 0.05, (max_value.y - min_value.y) * 0.05}
		value^.x += nav_x * step.x
		value^.y += nav_y * step.y
		if value^.x < min_value.x do value^.x = min_value.x
		if value^.x > max_value.x do value^.x = max_value.x
		if value^.y < min_value.y do value^.y = min_value.y
		if value^.y > max_value.y do value^.y = max_value.y
		changed = true
	}
	gui_draw_checker_grid(ctx, area)
	gui_round_stroke(ctx, area, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)
	normalized = gui_vec2_to_normalized(value^, min_value, max_value)
	handle = gui_normalized_to_rect_point(area, normalized)
	gui_draw_handle(ctx, handle, 7)
	if ctx.focused == id {
		gui_focus_ring(ctx, area)
	}
	return changed
}

gui_hue_wheel :: proc(ctx: ^Gui_Context, label, key: string, hsv: ^Hsv_Color) -> bool {
	bounds := gui_next_rect(ctx, height = 176)
	gui_text_clipped(ctx, {bounds.x, bounds.y, bounds.w, ctx.style.row_height}, {bounds.x + 2, bounds.y + 4}, label, ctx.style.text)
	wheel := Rect{bounds.x, bounds.y + ctx.style.row_height, bounds.w, bounds.h - ctx.style.row_height}
	return gui_hue_wheel_at(ctx, gui_make_id(ctx, key), wheel, hsv)
}

gui_hue_wheel_at :: proc(ctx: ^Gui_Context, id: Gui_Id, bounds: Rect, hsv: ^Hsv_Color) -> bool {
	gui_register_focusable(ctx, id, bounds)
	center := Vec2{bounds.x + bounds.w * 0.5, bounds.y + bounds.h * 0.5}
	outer := max(min(bounds.w, bounds.h) * 0.5 - 6, 1)
	inner := max(outer - 18, 1)
	segments := 48
	_ = segments
	gui_shader_rect(ctx, {center.x - outer, center.y - outer, outer * 2, outer * 2}, .Hue_Wheel, {inner / outer, 1, 0, hsv.a}, {1, 1, 1, 1})
	gui_ellipse_stroke(ctx, {center.x - outer, center.y - outer, outer * 2, outer * 2}, ctx.style.panel_border, 1)
	gui_ellipse_stroke(ctx, {center.x - inner, center.y - inner, inner * 2, inner * 2}, ctx.style.panel_border, 1)

	changed := false
	h := gui_wrap01(hsv.h)
	angle := h * GUI_TAU
	handle := Vec2{center.x + math.cos(angle) * ((inner + outer) * 0.5), center.y + math.sin(angle) * ((inner + outer) * 0.5)}
	delta := Vec2{ctx.input.mouse_pos.x - center.x, ctx.input.mouse_pos.y - center.y}
	dist := math.sqrt(delta.x * delta.x + delta.y * delta.y)
	hovered := gui_mouse_in_input_clip(ctx) && ((dist >= inner && dist <= outer) || gui_contains_circle(handle, ctx.input.mouse_pos, 10))
	if hovered {
		ctx.hot = id
		if ctx.input.mouse_pressed {
			ctx.active = id
			ctx.focused = id
		}
	}
	if ctx.active == id && ctx.input.mouse_down {
		hsv.h = gui_hue_from_delta(delta)
		changed = true
	}
	_ = gui_update_focus_edit(ctx, id, ctx.focused == id)
	nav_x, nav_y := gui_focused_nav(ctx, id)
	if nav_x != 0 || nav_y != 0 {
		hsv.h = gui_wrap01(hsv.h + (nav_x - nav_y) * 0.01)
		changed = true
	}
	h = gui_wrap01(hsv.h)
	angle = h * GUI_TAU
	handle = Vec2{center.x + math.cos(angle) * ((inner + outer) * 0.5), center.y + math.sin(angle) * ((inner + outer) * 0.5)}
	gui_draw_handle(ctx, handle, 7)
	if ctx.focused == id {
		gui_focus_ring(ctx, bounds)
	}
	return changed
}

gui_sv_grid :: proc(ctx: ^Gui_Context, label, key: string, hsv: ^Hsv_Color) -> bool {
	bounds := gui_next_rect(ctx, height = 158)
	gui_text_clipped(ctx, {bounds.x, bounds.y, bounds.w, ctx.style.row_height}, {bounds.x + 2, bounds.y + 4}, label, ctx.style.text)
	grid := Rect{bounds.x, bounds.y + ctx.style.row_height, bounds.w, bounds.h - ctx.style.row_height}
	return gui_sv_grid_at(ctx, gui_make_id(ctx, key), grid, hsv)
}

gui_sv_grid_at :: proc(ctx: ^Gui_Context, id: Gui_Id, grid: Rect, hsv: ^Hsv_Color) -> bool {
	hue_color := gui_hsv_to_rgb({h = hsv.h, s = 1, v = 1, a = 1})
	hue_color.a = gui_clamp01(hsv.a)
	gui_shader_rect(ctx, grid, .SV_Grid, {}, hue_color)
	changed := false
	handle := gui_normalized_to_rect_point(grid, {gui_clamp01(hsv.s), 1 - gui_clamp01(hsv.v)})
	if gui_drag_handle_region(ctx, id, grid, handle, 10) {
		n := gui_rect_point_to_normalized(grid, ctx.input.mouse_pos)
		hsv.s = n.x
		hsv.v = 1 - n.y
		changed = true
	}
	_ = gui_update_focus_edit(ctx, id, ctx.focused == id)
	nav_x, nav_y := gui_focused_nav(ctx, id)
	if nav_x != 0 || nav_y != 0 {
		hsv.s = gui_clamp01(hsv.s + nav_x * 0.05)
		hsv.v = gui_clamp01(hsv.v - nav_y * 0.05)
		changed = true
	}
	gui_round_stroke(ctx, grid, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)
	handle = gui_normalized_to_rect_point(grid, {gui_clamp01(hsv.s), 1 - gui_clamp01(hsv.v)})
	gui_draw_handle(ctx, handle, 7)
	if ctx.focused == id {
		gui_focus_ring(ctx, grid)
	}
	return changed
}

gui_alpha_slider :: proc(ctx: ^Gui_Context, label, key: string, hsv: ^Hsv_Color) -> bool {
	bounds := gui_next_rect(ctx, height = ctx.style.row_height)
	id := gui_make_id(ctx, key)
	changed := false
	track := gui_inset_edges(bounds, {left = 0, top = 8, right = 0, bottom = 8})
	base := gui_hsv_to_rgb({h = hsv.h, s = hsv.s, v = hsv.v, a = 1})
	gui_shader_rect(ctx, track, .Alpha_Ramp, {0, 0, 0, 1}, base)
	x := track.x + track.w * gui_clamp01(hsv.a)
	handle := Vec2{x, track.y + track.h * 0.5}
	if gui_drag_handle_region(ctx, id, bounds, handle, 10) {
		hsv.a = gui_rect_point_to_normalized(bounds, ctx.input.mouse_pos).x
		changed = true
	}
	_ = gui_update_focus_edit(ctx, id, ctx.focused == id)
	nav_x, nav_y := gui_focused_nav(ctx, id)
	if nav_x != 0 || nav_y != 0 {
		hsv.a = gui_clamp01(hsv.a + (nav_x - nav_y) * 0.05)
		changed = true
	}
	gui_round_stroke(ctx, track, track.h * 0.5, ctx.style.panel_border, ctx.style.border_width)
	x = track.x + track.w * gui_clamp01(hsv.a)
	gui_draw_handle(ctx, {x, track.y + track.h * 0.5}, 6)
	gui_text_clipped(ctx, gui_inset(bounds, 6), {bounds.x + 10, bounds.y + 6}, label, ctx.style.text)
	return changed
}

gui_color_picker_hsv :: gui_color_picker_hsv_keyed

gui_color_picker_hsv_keyed :: proc(ctx: ^Gui_Context, label, key: string, hsv: ^Hsv_Color) -> bool {
	changed := false
	gui_heading(ctx, label)
	gui_push_id(ctx, key)
	changed = gui_hue_wheel(ctx, "Hue", "hue", hsv) || changed
	changed = gui_sv_grid(ctx, "Saturation / Value", "sv", hsv) || changed
	changed = gui_alpha_slider(ctx, "Alpha", "alpha", hsv) || changed
	gui_pop_id(ctx)
	swatch := gui_next_rect(ctx, height = 42)
	gui_box(ctx, swatch, {
		fill = gui_hsv_to_rgb(hsv^),
		border = ctx.style.panel_border,
		radius = ctx.style.radius_control,
		border_width = ctx.style.border_width,
	})
	return changed
}

gui_circular_progress :: proc(ctx: ^Gui_Context, label: string, value: f32) {
	bounds := gui_next_rect(ctx, height = 92)
	size := min(bounds.h - 8, bounds.w * 0.38)
	rect := Rect{bounds.x + 6, bounds.y + (bounds.h - size) * 0.5, size, size}
	gui_shader_rect(ctx, rect, .Circular_Progress, {gui_clamp01(value), 0.72, 0, 1}, ctx.style.accent)
	gui_text_clipped(ctx, {bounds.x + size + 18, bounds.y, max(bounds.w - size - 18, 0), bounds.h}, {bounds.x + size + 24, bounds.y + 28}, label, ctx.style.text)
}

gui_combobox :: gui_combobox_keyed

gui_stepper_button_at :: proc(ctx: ^Gui_Context, id: Gui_Id, bounds: Rect, direction: int, enabled: bool) -> bool {
	control := gui_control(ctx, id, bounds, enabled)
	fill := ctx.style.control
	border := ctx.style.panel_border
	if !enabled {
		fill = ctx.style.control_disabled
	} else if ctx.active == id {
		fill = ctx.style.control_active
		border = gui_apply_opacity(ctx.style.accent, 0.64)
	} else if ctx.hot == id || control.focused {
		fill = ctx.style.control_hot
		border = gui_apply_opacity(ctx.style.text, 0.46)
	}
	gui_round_rect(ctx, bounds, ctx.style.radius_control, fill)
	gui_round_stroke(ctx, bounds, ctx.style.radius_control, border, ctx.style.border_width)
	center := Vec2{bounds.x + bounds.w * 0.5, bounds.y + bounds.h * 0.5}
	size := max(min(bounds.w, bounds.h) * 0.16, 5)
	x := size * 0.42
	if direction < 0 {
		gui_line(ctx, {center.x + x, center.y - size}, {center.x - x, center.y}, ctx.style.text_muted, ctx.style.border_width * 2)
		gui_line(ctx, {center.x - x, center.y}, {center.x + x, center.y + size}, ctx.style.text_muted, ctx.style.border_width * 2)
	} else {
		gui_line(ctx, {center.x - x, center.y - size}, {center.x + x, center.y}, ctx.style.text_muted, ctx.style.border_width * 2)
		gui_line(ctx, {center.x + x, center.y}, {center.x - x, center.y + size}, ctx.style.text_muted, ctx.style.border_width * 2)
	}
	if control.focused {
		gui_focus_ring(ctx, bounds)
	}
	return control.activated || (enabled && control.hovered && ctx.active == id && ctx.input.mouse_released)
}

gui_select_chrome :: proc(ctx: ^Gui_Context, bounds: Rect, display: string, id: Gui_Id, open, focused: bool) {
	fill := ctx.style.control
	border := ctx.style.panel_border
	stroke_width := ctx.style.border_width
	if open || ctx.active == id {
		fill = ctx.style.control_active
		border = gui_apply_opacity(ctx.style.accent, 0.64)
		stroke_width = max(ctx.style.border_width * 2, 2)
	} else if ctx.hot == id || focused {
		fill = ctx.style.control_hot
		border = gui_apply_opacity(ctx.style.text, 0.46)
	}

	gui_shadow(ctx, bounds, ctx.style.radius_control, ctx.style.shadow_offset, ctx.style.shadow_blur * 0.72, {0, 0, 0, 0.18})
	gui_round_rect(ctx, bounds, ctx.style.radius_control, fill)
	gui_round_stroke(ctx, bounds, ctx.style.radius_control, border, stroke_width)
	text_rect := gui_inset_edges(bounds, {left = ctx.style.control_padding * 1.5, top = 0, right = bounds.h, bottom = 0})
	gui_text_clipped(ctx, text_rect, {text_rect.x, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, display, ctx.style.text)
	icon_center := Vec2{bounds.x + bounds.w - bounds.h * 0.5, bounds.y + bounds.h * 0.5}
	gui_chevron(ctx, icon_center, max(bounds.h * 0.16, 5), open, ctx.style.text_muted)
	if focused {
		gui_focus_ring(ctx, bounds)
	}
}

gui_chevron :: proc(ctx: ^Gui_Context, center: Vec2, size: f32, up: bool, color: Color) {
	half := size
	y := size * 0.36
	if up {
		gui_line(ctx, {center.x - half, center.y + y}, {center.x, center.y - y}, color, ctx.style.border_width * 2)
		gui_line(ctx, {center.x, center.y - y}, {center.x + half, center.y + y}, color, ctx.style.border_width * 2)
	} else {
		gui_line(ctx, {center.x - half, center.y - y}, {center.x, center.y + y}, color, ctx.style.border_width * 2)
		gui_line(ctx, {center.x, center.y + y}, {center.x + half, center.y - y}, color, ctx.style.border_width * 2)
	}
}

gui_combo_popup_rect :: proc(ctx: ^Gui_Context, bounds: Rect, options: []string, query: string, match_count, selected_index: int) -> Rect {
	query_height := len(query) > 0 ? ctx.style.row_height : f32(0)
	visible_rows := min(max(match_count, 1), GUI_COMBO_SHORT_POPUP_ROWS)
	list_height := f32(visible_rows) * ctx.style.row_height
	width := max(bounds.w, gui_combo_popup_content_width(ctx, options))
	max_width := f32(ctx.input.window_width) > 0 ? max(f32(ctx.input.window_width) - ctx.style.spacing_1 * 2, bounds.w) : width
	width = min(width, max_width)
	popup_height := query_height + list_height

	below := Rect{bounds.x, bounds.y + bounds.h + ctx.style.spacing_1, width, popup_height}
	if ctx.input.window_height <= 0 {
		return below
	}
	margin := ctx.style.spacing_1
	viewport_h := max(f32(ctx.input.window_height) - margin * 2, 0)
	if match_count > GUI_COMBO_SHORT_POPUP_ROWS && viewport_h > 0 {
		content_height := f32(max(match_count, 1)) * ctx.style.row_height
		popup_height = min(query_height + content_height, viewport_h)
		popup_height = max(popup_height, min(query_height + ctx.style.row_height, viewport_h))
		selected_rank := gui_combo_match_rank(options, query, selected_index)
		selected_center_y := bounds.y + bounds.h * 0.5
		y := selected_center_y - query_height - (f32(selected_rank) + 0.5) * ctx.style.row_height
		return gui_overlay_nudge_into_view(ctx, {bounds.x, y, width, popup_height})
	}

	space_below := f32(ctx.input.window_height) - margin - (bounds.y + bounds.h + ctx.style.spacing_1)
	space_above := bounds.y - ctx.style.spacing_1 - margin
	if space_below < popup_height && space_above > space_below {
		above_h := min(popup_height, max(space_above, ctx.style.row_height))
		return gui_overlay_nudge_into_view(ctx, {bounds.x, bounds.y - ctx.style.spacing_1 - above_h, width, above_h})
	}
	return gui_overlay_nudge_into_view(ctx, below)
}

gui_combo_popup_content_width :: proc(ctx: ^Gui_Context, options: []string) -> f32 {
	width := f32(0)
	for option in options {
		width = max(width, gui_text_width(ctx, option))
	}
	return width + ctx.style.control_padding * 4 + ctx.style.scrollbar_width
}

gui_combo_match_count :: proc(options: []string, query: string) -> int {
	count := 0
	for option in options {
		if gui_string_contains_fold(option, query) {
			count += 1
		}
	}
	return count
}

gui_combo_match_rank :: proc(options: []string, query: string, selected_index: int) -> int {
	rank := 0
	for option, i in options {
		if !gui_string_contains_fold(option, query) {
			continue
		}
		if i == selected_index {
			return rank
		}
		rank += 1
	}
	return 0
}

gui_combo_scroll_highlight_into_view :: proc(ctx: ^Gui_Context, matches: []int, viewport_height: f32) {
	if ctx.combo_highlight < 0 || viewport_height <= 0 {
		return
	}
	highlight_index := -1
	for match, i in matches {
		if match == ctx.combo_highlight {
			highlight_index = i
			break
		}
	}
	if highlight_index < 0 {
		return
	}
	row_top := f32(highlight_index) * ctx.style.row_height
	row_bottom := row_top + ctx.style.row_height
	if row_top < ctx.combo_scroll {
		ctx.combo_scroll = row_top
	} else if row_bottom > ctx.combo_scroll + viewport_height {
		ctx.combo_scroll = row_bottom - viewport_height
	}
}

gui_combo_scroll_highlight_to_anchor :: proc(ctx: ^Gui_Context, matches: []int, list_viewport: Rect, bounds: Rect) {
	if ctx.combo_highlight < 0 || list_viewport.h <= 0 {
		return
	}
	highlight_index := -1
	for match, i in matches {
		if match == ctx.combo_highlight {
			highlight_index = i
			break
		}
	}
	if highlight_index < 0 {
		return
	}
	content_height := f32(len(matches)) * ctx.style.row_height
	max_scroll := max(content_height - list_viewport.h, 0)
	anchor_center_y := bounds.y + bounds.h * 0.5
	row_center := f32(highlight_index) * ctx.style.row_height + ctx.style.row_height * 0.5
	ctx.combo_scroll = min(max(row_center - (anchor_center_y - list_viewport.y), 0), max_scroll)
}

gui_combobox_keyed :: proc(ctx: ^Gui_Context, label, key: string, current: ^int, options: []string, query_buffer: []u8) -> bool {
	if len(options) == 0 {
		return false
	}
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	current^ = max(min(current^, len(options) - 1), 0)
	changed := false
	open := ctx.open_panel == id
	opened_this_frame := false
	control := gui_control(ctx, id, bounds, true)
	clicked := control.activated || (control.hovered && ctx.active == id && ctx.input.mouse_released)
	if open && ctx.input.accept {
		clicked = false
	}
	if open && clicked {
		query := gui_query_string(query_buffer)
		matches_count := gui_combo_match_count(options, query)
		popup := gui_combo_popup_rect(ctx, bounds, options, query, matches_count, ctx.combo_highlight)
		if gui_contains(popup, ctx.input.mouse_pos) {
			clicked = false
		}
	}
	if !open && control.focused && ctx.input.key_space {
		clicked = true
	}
	if clicked {
		if open {
			ctx.open_panel = GUI_ID_NONE
		} else {
			ctx.open_panel = id
			ctx.focused = id
			ctx.combo_highlight = max(min(current^, len(options) - 1), 0)
			ctx.combo_scroll = 0
			gui_clear_query(query_buffer)
			opened_this_frame = true
		}
		open = ctx.open_panel == id
	}
	if open && ctx.input.mouse_pressed && !gui_contains(bounds, ctx.input.mouse_pos) {
		query := gui_query_string(query_buffer)
		matches_count := gui_combo_match_count(options, query)
		popup := gui_combo_popup_rect(ctx, bounds, options, query, matches_count, ctx.combo_highlight)
		if !gui_contains(popup, ctx.input.mouse_pos) {
			ctx.open_panel = GUI_ID_NONE
			open = false
		}
	}

	display := label
	if current^ >= 0 && current^ < len(options) {
		display = options[current^]
	}
	gui_select_chrome(ctx, bounds, display, id, open, control.focused)

	if !open {
		return changed
	}

	query_changed := false
	if ctx.input.text_input_len > 0 {
		gui_append_query(query_buffer, ctx.input.text_input[:ctx.input.text_input_len])
		query_changed = true
	}
	if ctx.input.key_backspace {
		gui_pop_query(query_buffer)
		query_changed = true
	}
	if ctx.input.back {
		ctx.open_panel = GUI_ID_NONE
		return false
	}

	query := gui_query_string(query_buffer)
	if query_changed {
		ctx.combo_scroll = 0
	}
	matches := make([dynamic]int, 0, len(options))
	defer delete(matches)
	for option, i in options {
		if gui_string_contains_fold(option, query) {
			append(&matches, i)
		}
	}
	if len(matches) == 0 {
		ctx.combo_highlight = -1
	} else {
		if ctx.combo_highlight < 0 || !gui_match_contains(matches[:], ctx.combo_highlight) {
			ctx.combo_highlight = matches[0]
		}
		if !opened_this_frame && ctx.input.nav_pressed_y > 0 {
			ctx.combo_highlight = gui_next_match(matches[:], ctx.combo_highlight, 1)
		}
		if !opened_this_frame && ctx.input.nav_pressed_y < 0 {
			ctx.combo_highlight = gui_next_match(matches[:], ctx.combo_highlight, -1)
		}
		if ctx.input.accept {
			current^ = ctx.combo_highlight
			ctx.open_panel = GUI_ID_NONE
			return true
		}
	}

	popup := gui_combo_popup_rect(ctx, bounds, options, query, len(matches), ctx.combo_highlight)
	query_height := len(query) > 0 ? ctx.style.row_height : f32(0)
	list_viewport := Rect{popup.x, popup.y + query_height, popup.w, max(popup.h - query_height, 0)}
	content_height := f32(len(matches)) * ctx.style.row_height
	max_scroll := max(content_height - list_viewport.h, 0)
	if opened_this_frame && len(matches) > GUI_COMBO_SHORT_POPUP_ROWS {
		gui_combo_scroll_highlight_to_anchor(ctx, matches[:], list_viewport, bounds)
	} else {
		gui_combo_scroll_highlight_into_view(ctx, matches[:], list_viewport.h)
	}
	combo_scroll := ctx.combo_scroll
	_, _ = gui_apply_wheel_scroll(ctx, popup, &combo_scroll, max_scroll, ctx.style.row_height, ctx.scroll_depth)
	ctx.combo_scroll = combo_scroll
	ctx.combo_scroll = min(max(ctx.combo_scroll, 0), max_scroll)
	gui_record_scroll_hit(ctx, popup, ctx.combo_scroll, max_scroll, ctx.style.row_height, ctx.scroll_depth)
	gui_overlay_input_rect(ctx, popup)
	gui_set_combo_popup(ctx, id, popup, options, query)
	y := list_viewport.y - ctx.combo_scroll
	for match in matches {
		row := Rect{popup.x, y, popup.w, ctx.style.row_height}
		visible_row := y + ctx.style.row_height > list_viewport.y && y < list_viewport.y + list_viewport.h
		row_id := gui_id_child_int(id, match)
		if visible_row && !opened_this_frame && gui_pointer_enabled(ctx) && gui_contains(list_viewport, ctx.input.mouse_pos) && gui_contains(row, ctx.input.mouse_pos) {
			ctx.hot = row_id
			ctx.combo_highlight = match
			if ctx.input.mouse_released {
				current^ = match
				ctx.open_panel = GUI_ID_NONE
				changed = true
			}
		}
		y += ctx.style.row_height
		if y >= popup.y + popup.h {
			break
		}
	}
	return changed
}

gui_set_combo_popup :: proc(ctx: ^Gui_Context, id: Gui_Id, popup: Rect, options: []string, query: string) {
	ctx.combo_popup_visible = true
	ctx.combo_popup_id = id
	ctx.combo_popup_rect = popup
	ctx.combo_popup_options = options
	ctx.combo_popup_query_len = min(len(query), len(ctx.combo_popup_query))
	query_bytes := transmute([]u8)query
	for i in 0 ..< ctx.combo_popup_query_len {
		ctx.combo_popup_query[i] = query_bytes[i]
	}
	if ctx.combo_popup_query_len < len(ctx.combo_popup_query) {
		ctx.combo_popup_query[ctx.combo_popup_query_len] = 0
	}
}

gui_draw_combo_popup_overlay :: proc(ctx: ^Gui_Context) {
	if !ctx.combo_popup_visible || ctx.open_panel != ctx.combo_popup_id {
		return
	}
	popup := ctx.combo_popup_rect
	query := string(ctx.combo_popup_query[:ctx.combo_popup_query_len])
	gui_shadow(ctx, popup, ctx.style.radius_control, {0, 5}, 12, ctx.style.shadow_color)
	gui_round_rect(ctx, popup, ctx.style.radius_control, ctx.style.panel)
	gui_round_stroke(ctx, popup, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)
	gui_scissor_begin(ctx, popup)
	query_height := len(query) > 0 ? ctx.style.row_height : f32(0)
	if len(query) > 0 {
		query_row := Rect{popup.x, popup.y, popup.w, ctx.style.row_height}
		gui_round_rect(ctx, gui_inset(query_row, 3), ctx.style.radius_control, ctx.style.control)
		gui_text_clipped(ctx, gui_inset(query_row, 8), {query_row.x + 12, query_row.y + 6}, query, ctx.style.accent)
	}

	list_viewport := Rect{popup.x, popup.y + query_height, popup.w, max(popup.h - query_height, 0)}
	y := list_viewport.y - ctx.combo_scroll
	match_count := gui_combo_match_count(ctx.combo_popup_options, query)
	for option, match in ctx.combo_popup_options {
		if !gui_string_contains_fold(option, query) {
			continue
		}
		row := Rect{popup.x, y, popup.w, ctx.style.row_height}
		if y + ctx.style.row_height > list_viewport.y && y < list_viewport.y + list_viewport.h {
			if ctx.combo_highlight == match {
				gui_round_rect(ctx, gui_inset(row, 3), ctx.style.radius_control, ctx.style.control_hot)
			}
			text_left := row.x + ctx.style.control_padding * 1.5
			if match == ctx.combo_highlight {
				gui_rect(ctx, {row.x + 3, row.y + 7, max(ctx.style.border_width * 2, 2), max(row.h - 14, 1)}, ctx.style.accent)
			}
			gui_text_clipped(ctx, gui_inset_edges(row, {left = ctx.style.control_padding * 1.5, top = 0, right = ctx.style.scrollbar_width + ctx.style.control_padding, bottom = 0}), {text_left, row.y + max((row.h - ctx.style.body_text_height) * 0.5, 0)}, option, ctx.style.text)
		}
		y += ctx.style.row_height
		if y >= popup.y + popup.h {
			break
		}
	}
	if match_count == 0 {
		gui_text_clipped(ctx, gui_inset(popup, 8), {popup.x + 12, popup.y + 6}, "No matches", ctx.style.text_muted)
	}
	gui_scissor_end(ctx)
	gui_scrollbar(ctx, list_viewport, f32(match_count) * ctx.style.row_height, ctx.combo_scroll)
}

gui_collapsible_begin :: gui_collapsible_begin_keyed

gui_collapsible_begin_keyed :: proc(ctx: ^Gui_Context, label, key: string, open: ^bool) -> bool {
	id := gui_make_id(ctx, key)
	bounds := gui_next_rect(ctx)
	control := gui_control(ctx, id, bounds, true)
	if control.activated || (control.focused && ctx.input.key_space) || (control.hovered && ctx.active == id && ctx.input.mouse_released) {
		open^ = !open^
	}
	gui_expander_chrome(ctx, bounds, label, id, open^, control.focused)
	return open^
}

gui_expander_chrome :: proc(ctx: ^Gui_Context, bounds: Rect, label: string, id: Gui_Id, open, focused: bool) {
	fill := Color{0, 0, 0, 0}
	border := ctx.style.panel_border
	label_color := ctx.style.text
	if open {
		fill = gui_apply_opacity(ctx.style.control, 0.72)
		border = gui_apply_opacity(ctx.style.accent, 0.45)
		label_color = ctx.style.text
	}
	if ctx.hot == id || focused {
		fill = ctx.style.control_hot
		border = gui_apply_opacity(ctx.style.text, 0.46)
	}
	if ctx.active == id {
		fill = ctx.style.control_active
		border = gui_apply_opacity(ctx.style.accent, 0.64)
	}
	if fill.a > 0 {
		gui_round_rect(ctx, bounds, ctx.style.radius_control, fill)
	}
	gui_round_stroke(ctx, bounds, ctx.style.radius_control, border, ctx.style.border_width)
	if open {
		gui_rect(ctx, {bounds.x + 3, bounds.y + 7, max(ctx.style.border_width * 2, 2), max(bounds.h - 14, 1)}, ctx.style.accent)
	}
	t := open ? f32(1) : f32(0)
	if ctx.input.delta_time > 0 {
		t = gui_animate_value(ctx, gui_id_child(id, "expander-open"), t, 16)
	}
	icon_center := Vec2{bounds.x + ctx.style.control_padding * 2.1, bounds.y + bounds.h * 0.5}
	icon_color := (ctx.hot == id || focused || open) ? ctx.style.accent : ctx.style.text_muted
	gui_expander_chevron(ctx, icon_center, max(bounds.h * 0.16, 5), t, icon_color)
	text_x := bounds.x + ctx.style.control_padding * 4
	text_rect := gui_inset_edges(bounds, {left = ctx.style.control_padding * 4, top = 0, right = ctx.style.control_padding, bottom = 0})
	gui_text_clipped(ctx, text_rect, {text_x, bounds.y + max((bounds.h - ctx.style.body_text_height) * 0.5, 0)}, label, label_color)
	if focused {
		gui_focus_ring(ctx, bounds)
	}
}

gui_expander_chevron :: proc(ctx: ^Gui_Context, center: Vec2, size, t: f32, color: Color) {
	x := gui_clamp01(t)
	closed_a := Vec2{center.x - size * 0.35, center.y - size}
	closed_b := Vec2{center.x + size * 0.45, center.y}
	closed_c := Vec2{center.x - size * 0.35, center.y + size}
	open_a := Vec2{center.x - size, center.y - size * 0.35}
	open_b := Vec2{center.x, center.y + size * 0.45}
	open_c := Vec2{center.x + size, center.y - size * 0.35}
	a := gui_lerp_vec2(closed_a, open_a, x)
	b := gui_lerp_vec2(closed_b, open_b, x)
	c := gui_lerp_vec2(closed_c, open_c, x)
	gui_line(ctx, a, b, color, ctx.style.border_width * 2)
	gui_line(ctx, b, c, color, ctx.style.border_width * 2)
}

gui_scissor_begin :: proc(ctx: ^Gui_Context, rect: Rect) {
	append(&ctx.commands, Draw_Command{kind = .Scissor_Begin, rect = rect})
}

gui_scissor_end :: proc(ctx: ^Gui_Context) {
	append(&ctx.commands, Draw_Command{kind = .Scissor_End})
}

gui_input_clip_begin :: proc(ctx: ^Gui_Context, rect: Rect) {
	if ctx.input_clip_depth >= MAX_GUI_CLIP_DEPTH {
		return
	}
	clip := rect
	if ctx.input_clip_depth > 0 {
		clip = gui_rect_intersection(ctx.input_clip_stack[ctx.input_clip_depth - 1], rect)
	}
	ctx.input_clip_stack[ctx.input_clip_depth] = clip
	ctx.input_clip_depth += 1
}

gui_input_clip_end :: proc(ctx: ^Gui_Context) {
	if ctx.input_clip_depth > 0 {
		ctx.input_clip_depth -= 1
	}
}

gui_overlay_input_rect :: proc(ctx: ^Gui_Context, rect: Rect) {
	if rect.w <= 0 || rect.h <= 0 || ctx.next_overlay_input_rect_count >= MAX_GUI_OVERLAY_INPUT_RECTS {
		return
	}
	ctx.next_overlay_input_rects[ctx.next_overlay_input_rect_count] = rect
	ctx.next_overlay_input_rect_count += 1
}

gui_overlay_input_begin :: proc(ctx: ^Gui_Context, rect: Rect) {
	gui_overlay_input_rect(ctx, rect)
	ctx.overlay_input_depth += 1
}

gui_overlay_input_end :: proc(ctx: ^Gui_Context) {
	if ctx.overlay_input_depth > 0 {
		ctx.overlay_input_depth -= 1
	}
}

gui_scrollbar :: proc(ctx: ^Gui_Context, viewport: Rect, content_height, scroll: f32) {
	if content_height <= viewport.h || viewport.h <= 0 {
		return
	}
	track_w := ctx.style.scrollbar_width
	track_margin := ctx.style.border_width * 2
	track := Rect{viewport.x + viewport.w - track_w - track_margin, viewport.y + track_margin, track_w, max(viewport.h - track_margin * 2, 0)}
	if track.h <= 0 {
		return
	}
	thumb_h := max(track.h * (viewport.h / max(content_height, 1)), ctx.style.rhythm * 0.5)
	thumb_h = min(thumb_h, track.h)
	max_scroll := max(content_height - viewport.h, 1)
	thumb_range := max(track.h - thumb_h, 0)
	thumb_y := track.y + thumb_range * gui_clamp01(scroll / max_scroll)
	thumb := Rect{track.x, thumb_y, track.w, thumb_h}
	gui_round_rect(ctx, track, track.w * 0.5, gui_apply_opacity(ctx.style.control, 0.55))
	gui_round_rect(ctx, thumb, thumb.w * 0.5, gui_apply_opacity(ctx.style.text_muted, 0.70))
}

gui_next_row :: proc(ctx: ^Gui_Context, width := f32(-1), height := f32(-1)) -> Rect {
	w := width
	h := height
	if w <= 0 {
		w = ctx.content_width
	}
	if h <= 0 {
		h = ctx.style.row_height
	}
	bounds := Rect {
		x = ctx.next_cursor.x,
		y = ctx.next_cursor.y,
		w = w,
		h = h,
	}
	ctx.next_cursor.y += h + ctx.style.spacing
	return bounds
}

gui_rect :: proc(ctx: ^Gui_Context, rect: Rect, color: Color) {
	append(&ctx.commands, Draw_Command{kind = .Filled_Rect, rect = rect, color = color})
}

gui_rect_blend :: proc(ctx: ^Gui_Context, rect: Rect, color: Color, blend: Gui_Blend_Mode) {
	append(&ctx.commands, Draw_Command{kind = .Filled_Rect, rect = rect, color = color, blend = blend})
}

gui_stroke :: proc(ctx: ^Gui_Context, rect: Rect, color: Color) {
	append(&ctx.commands, Draw_Command{kind = .Stroked_Rect, rect = rect, color = color, stroke_width = ctx.style.border_width})
}

gui_round_rect :: proc(ctx: ^Gui_Context, rect: Rect, radius: f32, color: Color) {
	append(&ctx.commands, Draw_Command{kind = .Filled_Rounded_Rect, rect = rect, color = color, radius = radius})
}

gui_round_stroke :: proc(ctx: ^Gui_Context, rect: Rect, radius: f32, color: Color, width: f32) {
	append(&ctx.commands, Draw_Command{kind = .Stroked_Rounded_Rect, rect = rect, color = color, radius = radius, stroke_width = width})
}

gui_gradient_rect :: proc(ctx: ^Gui_Context, rect: Rect, top, bottom: Color) {
	append(&ctx.commands, Draw_Command{kind = .Gradient_Rect, rect = rect, color = top, color_2 = bottom})
}

gui_horizontal_gradient_rect :: proc(ctx: ^Gui_Context, rect: Rect, left, right: Color) {
	append(&ctx.commands, Draw_Command{kind = .Horizontal_Gradient_Rect, rect = rect, color = left, color_2 = right})
}

gui_gradient_round_rect :: proc(ctx: ^Gui_Context, rect: Rect, radius: f32, top, bottom: Color) {
	append(&ctx.commands, Draw_Command{kind = .Gradient_Rect, rect = rect, color = top, color_2 = bottom, radius = radius})
}

gui_shader_rect :: proc(ctx: ^Gui_Context, rect: Rect, kind: Gui_Shader_Kind, params: Color, tint: Color) {
	append(&ctx.commands, Draw_Command{kind = .Shader_Rect, rect = rect, color = tint, shader_kind = kind, shader_params = params})
}

gui_quad :: proc(ctx: ^Gui_Context, p0, p1, p2, p3: Vec2, color: Color) {
	append(&ctx.commands, Draw_Command{kind = .Filled_Quad, p0 = p0, p1 = p1, p2 = p2, p3 = p3, color = color})
}

gui_rotated_rect :: proc(ctx: ^Gui_Context, rect: Rect, angle_radians: f32, color: Color) {
	center := Vec2{rect.x + rect.w * 0.5, rect.y + rect.h * 0.5}
	p0 := gui_rotate_point({rect.x, rect.y}, center, angle_radians)
	p1 := gui_rotate_point({rect.x + rect.w, rect.y}, center, angle_radians)
	p2 := gui_rotate_point({rect.x + rect.w, rect.y + rect.h}, center, angle_radians)
	p3 := gui_rotate_point({rect.x, rect.y + rect.h}, center, angle_radians)
	gui_quad(ctx, p0, p1, p2, p3, color)
}

gui_line :: proc(ctx: ^Gui_Context, p0, p1: Vec2, color: Color, width: f32) {
	append(&ctx.commands, Draw_Command{kind = .Line, p0 = p0, p1 = p1, color = color, stroke_width = max(width, 1)})
}

gui_ellipse :: proc(ctx: ^Gui_Context, rect: Rect, color: Color) {
	append(&ctx.commands, Draw_Command{kind = .Filled_Ellipse, rect = rect, color = color})
}

gui_ellipse_stroke :: proc(ctx: ^Gui_Context, rect: Rect, color: Color, width: f32) {
	append(&ctx.commands, Draw_Command{kind = .Stroked_Ellipse, rect = rect, color = color, stroke_width = max(width, 1)})
}

gui_image :: proc(ctx: ^Gui_Context, rect: Rect, image_id: Gui_Image_Id, tint: Color) {
	gui_image_filtered(ctx, rect, image_id, tint, {brightness = 1, contrast = 1})
}

gui_image_uv :: proc(ctx: ^Gui_Context, rect: Rect, image_id: Gui_Image_Id, tint: Color, uv: Rect) {
	gui_image_uv_filtered(ctx, rect, image_id, tint, uv, {brightness = 1, contrast = 1})
}

gui_image_filtered :: proc(ctx: ^Gui_Context, rect: Rect, image_id: Gui_Image_Id, tint: Color, filter: Gui_Image_Filter) {
	gui_image_uv_filtered(ctx, rect, image_id, tint, {0, 0, 1, 1}, filter)
}

gui_image_uv_filtered :: proc(ctx: ^Gui_Context, rect: Rect, image_id: Gui_Image_Id, tint: Color, uv: Rect, filter: Gui_Image_Filter) {
	gui_image_uv_filtered_blend(ctx, rect, image_id, tint, uv, filter, .Alpha)
}

gui_image_uv_filtered_blend :: proc(ctx: ^Gui_Context, rect: Rect, image_id: Gui_Image_Id, tint: Color, uv: Rect, filter: Gui_Image_Filter, blend: Gui_Blend_Mode) {
	normalized := filter
	if normalized.brightness == 0 {
		normalized.brightness = 1
	}
	if normalized.contrast == 0 {
		normalized.contrast = 1
	}
	append(&ctx.commands, Draw_Command{kind = .Image, rect = rect, rect_2 = uv, color = tint, image_id = image_id, image_filter = normalized, blend = blend})
}

gui_backdrop_blur_rect :: proc(ctx: ^Gui_Context, rect: Rect, tint: Color, blur: f32) {
	filter := Gui_Image_Filter{brightness = 1.04, contrast = 0.96, grayscale = 0, blur = blur}
	append(&ctx.commands, Draw_Command{kind = .Backdrop_Blur_Rect, rect = rect, color = tint, image_filter = filter})
}

gui_default_glass_style :: proc(ctx: ^Gui_Context, radius: f32) -> Gui_Glass_Style {
	r := radius
	if r <= 0 {
		r = ctx.style.radius_panel
	}
	return {
		tint = {0.07, 0.09, 0.11, 0.38},
		radius = r,
		thickness = max(ctx.style.rhythm * 0.18, f32(7)),
		roughness = 0.50,
		bevel = max(ctx.style.border_width * 5, f32(5)),
		ior = 1.46,
		dispersion = 0.90,
		border = 0.32,
		highlight = 0.36,
	}
}

gui_refractive_glass_rect :: proc(ctx: ^Gui_Context, rect: Rect, style: Gui_Glass_Style) {
	if rect.w <= 0 || rect.h <= 0 {
		return
	}
	glass := style
	if glass.radius < 0 {
		glass.radius = 0
	}
	if glass.thickness <= 0 {
		glass.thickness = max(ctx.style.rhythm * 0.18, f32(7))
	}
	if glass.bevel <= 0 {
		glass.bevel = max(ctx.style.border_width * 5, f32(5))
	}
	if glass.ior <= 0 {
		glass.ior = 1.46
	}
	if glass.dispersion < 0 {
		glass.dispersion = 0
	}
	glass.roughness = gui_clamp01(glass.roughness)
	glass.border = gui_clamp01(glass.border)
	glass.highlight = gui_clamp01(glass.highlight)
	append(&ctx.commands, Draw_Command{kind = .Refractive_Glass_Rect, rect = rect, color = glass.tint, glass_style = glass})
}

gui_focus_ring :: proc(ctx: ^Gui_Context, rect: Rect) {
	outer := gui_inset(rect, -ctx.style.focus_ring_width)
	gui_round_stroke(ctx, outer, ctx.style.radius_control + ctx.style.focus_ring_width, gui_apply_opacity(ctx.style.accent, 0.86), ctx.style.focus_ring_width)
}

gui_box :: proc(ctx: ^Gui_Context, rect: Rect, style: Gui_Box_Style) {
	opacity := style.opacity
	if opacity <= 0 {
		opacity = 1
	}
	if style.shadow_blur > 0 && style.shadow_color.a > 0 {
		gui_shadow(ctx, rect, style.radius, style.shadow_offset, style.shadow_blur, gui_apply_opacity(style.shadow_color, opacity))
	}
	if style.gradient {
		append(&ctx.commands, Draw_Command{kind = .Gradient_Rect, rect = rect, color = gui_apply_opacity(style.fill, opacity), color_2 = gui_apply_opacity(style.fill_to, opacity), radius = style.radius, blend = style.blend})
	} else if style.fill.a > 0 {
		append(&ctx.commands, Draw_Command{kind = .Filled_Rounded_Rect, rect = rect, color = gui_apply_opacity(style.fill, opacity), radius = style.radius, blend = style.blend})
	}
	if style.border_width > 0 && style.border.a > 0 {
		gui_round_stroke(ctx, rect, style.radius, gui_apply_opacity(style.border, opacity), style.border_width)
	}
}

gui_shadow :: proc(ctx: ^Gui_Context, rect: Rect, radius: f32, offset: Vec2, blur: f32, color: Color) {
	if blur <= 0 || color.a <= 0 {
		return
	}
	steps := 5
	for i in 0 ..< steps {
		t := f32(i + 1) / f32(steps)
		spread := blur * t
		alpha := color.a * (1 - t) * 0.42
		shadow_rect := Rect{rect.x + offset.x - spread, rect.y + offset.y - spread, rect.w + spread * 2, rect.h + spread * 2}
		gui_round_rect(ctx, shadow_rect, radius + spread, Color{color.r, color.g, color.b, alpha})
	}
}

gui_apply_opacity :: proc(color: Color, opacity: f32) -> Color {
	return {color.r, color.g, color.b, color.a * gui_clamp01(opacity)}
}

gui_lighten :: proc(color: Color, amount: f32) -> Color {
	t := gui_clamp01(amount)
	return {
		color.r + (1 - color.r) * t,
		color.g + (1 - color.g) * t,
		color.b + (1 - color.b) * t,
		color.a,
	}
}

gui_darken :: proc(color: Color, amount: f32) -> Color {
	t := 1 - gui_clamp01(amount)
	return {color.r * t, color.g * t, color.b * t, color.a}
}

gui_lerp_f32 :: proc(a, b, t: f32) -> f32 {
	x := gui_clamp01(t)
	return a + (b - a) * x
}

gui_lerp_color :: proc(a, b: Color, t: f32) -> Color {
	x := gui_clamp01(t)
	return {
		gui_lerp_f32(a.r, b.r, x),
		gui_lerp_f32(a.g, b.g, x),
		gui_lerp_f32(a.b, b.b, x),
		gui_lerp_f32(a.a, b.a, x),
	}
}

gui_lerp_vec2 :: proc(a, b: Vec2, t: f32) -> Vec2 {
	x := gui_clamp01(t)
	return {
		gui_lerp_f32(a.x, b.x, x),
		gui_lerp_f32(a.y, b.y, x),
	}
}

gui_animate_towards :: proc(current, target, speed, delta_time: f32) -> f32 {
	if speed <= 0 {
		return target
	}
	t := 1 - gui_pow_approx(0.5, speed * max(delta_time, 0))
	return gui_lerp_f32(current, target, t)
}

gui_animate_value :: proc(ctx: ^Gui_Context, id: Gui_Id, target, speed: f32) -> f32 {
	slot := gui_animation_slot(ctx, id)
	if slot == nil {
		return target
	}
	if slot.last_frame == 0 {
		slot.value = target
	} else {
		slot.value = gui_animate_towards(slot.value, target, speed, ctx.input.delta_time)
	}
	slot.last_frame = ctx.frame_index
	return slot.value
}

gui_animation_slot :: proc(ctx: ^Gui_Context, id: Gui_Id) -> ^Gui_Animation_Slot {
	free_index := -1
	oldest_index := 0
	oldest_frame := ctx.animation_slots[0].last_frame
	for i in 0 ..< len(ctx.animation_slots) {
		slot := &ctx.animation_slots[i]
		if slot.id == id {
			return slot
		}
		if slot.id == GUI_ID_NONE && free_index < 0 {
			free_index = i
		}
		if slot.last_frame < oldest_frame {
			oldest_frame = slot.last_frame
			oldest_index = i
		}
	}
	index := free_index
	if index < 0 {
		index = oldest_index
	}
	ctx.animation_slots[index] = {id = id, value = 0, last_frame = 0}
	return &ctx.animation_slots[index]
}

gui_pow_approx :: proc(base, exponent: f32) -> f32 {
	if exponent <= 0 {
		return 1
	}
	result := f32(1)
	steps := int(min(max(exponent * 8, 1), 64))
	step_base := 1 + (base - 1) / f32(steps)
	for _ in 0 ..< steps {
		result *= step_base
	}
	return result
}

gui_text :: proc(ctx: ^Gui_Context, pos: Vec2, text: string, color: Color) {
	gui_text_font(ctx, pos, text, color, .Body, ctx.style.text_scale)
}

gui_text_font :: proc(ctx: ^Gui_Context, pos: Vec2, text: string, color: Color, font_kind: Gui_Font_Kind, text_scale: f32) {
	append(&ctx.commands, Draw_Command{
		kind = .Text,
		rect = {pos.x, pos.y, 0, 0},
		color = color,
		text = text,
		text_scale = text_scale,
		text_align = .Left,
		font_kind = font_kind,
	})
}

gui_text_wrapped_at :: proc(ctx: ^Gui_Context, pos: Vec2, text: string, max_width: f32, color: Color) {
	if max_width <= 0 {
		gui_text(ctx, pos, text, color)
		return
	}
	lines := make([dynamic]Gui_Text_Line, 0, 16)
	defer delete(lines)
	gui_text_wrap_lines(ctx, text, max_width, &lines)

	y := pos.y
	for line in lines {
		if line.end > line.start {
			gui_text(ctx, {pos.x, y}, text[line.start:line.end], color)
		}
		y += ctx.style.body_line_height
	}
}

gui_text_aligned :: proc(ctx: ^Gui_Context, rect: Rect, text: string, color: Color, align: Text_Align) {
	gui_text_aligned_font(ctx, rect, text, color, align, .Body, ctx.style.text_scale)
}

gui_text_aligned_font :: proc(ctx: ^Gui_Context, rect: Rect, text: string, color: Color, align: Text_Align, font_kind: Gui_Font_Kind, text_scale: f32) {
	append(&ctx.commands, Draw_Command{
		kind = .Text,
		rect = rect,
		color = color,
		text = text,
		text_scale = text_scale,
		text_align = align,
		font_kind = font_kind,
	})
}

gui_text_aligned_scaled :: proc(ctx: ^Gui_Context, rect: Rect, text: string, color: Color, align: Text_Align, scale: f32) {
	append(&ctx.commands, Draw_Command{
		kind = .Text,
		rect = rect,
		color = color,
		text = text,
		text_scale = max(ctx.style.text_scale * scale, 0.5),
		text_align = align,
		font_kind = scale >= 1.45 ? Gui_Font_Kind.Display : Gui_Font_Kind.Body,
	})
}

gui_text_clipped :: proc(ctx: ^Gui_Context, rect: Rect, pos: Vec2, text: string, color: Color) {
	gui_scissor_begin(ctx, rect)
	gui_text(ctx, pos, text, color)
	gui_scissor_end(ctx)
}

gui_text_centered :: proc(ctx: ^Gui_Context, rect: Rect, text: string, color: Color) {
	gui_text_aligned(ctx, rect, text, color, .Center)
}

gui_text_right :: proc(ctx: ^Gui_Context, rect: Rect, text: string, color: Color) {
	gui_text_aligned(ctx, rect, text, color, .Right)
}

gui_tooltip :: proc(ctx: ^Gui_Context, bounds: Rect, text: string) {
	if len(text) == 0 || !gui_mouse_contains(ctx, bounds) {
		return
	}
	padding := f32(8)
	w := gui_text_width(ctx, text) + padding * 2
	h := ctx.style.text_height + padding * 2
	x := ctx.input.mouse_pos.x + 14
	y := ctx.input.mouse_pos.y + 18
	ctx.tooltip_visible = true
	ctx.tooltip_rect = gui_overlay_nudge_into_view(ctx, {x, y, w, h})
	ctx.tooltip_text = text
}

gui_draw_tooltip_overlay :: proc(ctx: ^Gui_Context) {
	if !ctx.tooltip_visible {
		return
	}
	rect := ctx.tooltip_rect
	gui_shadow(ctx, rect, ctx.style.radius_control, {0, 4}, 12, ctx.style.shadow_color)
	gui_round_rect(ctx, rect, ctx.style.radius_control, {0.02, 0.025, 0.035, 0.96})
	gui_round_stroke(ctx, rect, ctx.style.radius_control, ctx.style.panel_border, ctx.style.border_width)
	gui_text_clipped(ctx, gui_inset(rect, 6), {rect.x + 8, rect.y + 7}, ctx.tooltip_text, ctx.style.text)
}

gui_contains :: proc(rect: Rect, p: Vec2) -> bool {
	return p.x >= rect.x &&
	       p.y >= rect.y &&
	       p.x < rect.x + rect.w &&
	       p.y < rect.y + rect.h
}

gui_contains_circle :: proc(center, p: Vec2, radius: f32) -> bool {
	dx := p.x - center.x
	dy := p.y - center.y
	return dx * dx + dy * dy <= radius * radius
}

gui_rect_intersection :: proc(a, b: Rect) -> Rect {
	x0 := max(a.x, b.x)
	y0 := max(a.y, b.y)
	x1 := min(a.x + a.w, b.x + b.w)
	y1 := min(a.y + a.h, b.y + b.h)
	return {x0, y0, max(x1 - x0, 0), max(y1 - y0, 0)}
}

gui_overlay_nudge_into_view :: proc(ctx: ^Gui_Context, rect: Rect) -> Rect {
	if ctx.input.window_width <= 0 || ctx.input.window_height <= 0 {
		return rect
	}
	margin := ctx.style.spacing_1
	viewport := Rect{margin, margin, max(f32(ctx.input.window_width) - margin * 2, 0), max(f32(ctx.input.window_height) - margin * 2, 0)}
	if viewport.w <= 0 || viewport.h <= 0 {
		return rect
	}

	out := rect
	if out.w > viewport.w {
		out.w = viewport.w
	}
	if out.h > viewport.h {
		out.h = viewport.h
	}
	if out.x + out.w > viewport.x + viewport.w {
		out.x = viewport.x + viewport.w - out.w
	}
	if out.y + out.h > viewport.y + viewport.h {
		out.y = viewport.y + viewport.h - out.h
	}
	if out.x < viewport.x {
		out.x = viewport.x
	}
	if out.y < viewport.y {
		out.y = viewport.y
	}
	return out
}

gui_mouse_in_input_clip :: proc(ctx: ^Gui_Context) -> bool {
	if !gui_pointer_enabled(ctx) {
		return false
	}
	if gui_mouse_occluded_by_overlay(ctx) {
		return false
	}
	if ctx.input_clip_depth == 0 {
		return true
	}
	return gui_contains(ctx.input_clip_stack[ctx.input_clip_depth - 1], ctx.input.mouse_pos)
}

gui_mouse_occluded_by_overlay :: proc(ctx: ^Gui_Context) -> bool {
	if ctx.overlay_input_depth > 0 {
		return false
	}
	for i in 0 ..< ctx.overlay_input_rect_count {
		if gui_contains(ctx.overlay_input_rects[i], ctx.input.mouse_pos) {
			return true
		}
	}
	for i in 0 ..< ctx.next_overlay_input_rect_count {
		if gui_contains(ctx.next_overlay_input_rects[i], ctx.input.mouse_pos) {
			return true
		}
	}
	return false
}

gui_pointer_enabled :: proc(ctx: ^Gui_Context) -> bool {
	return ctx.input.pointer_enabled || ctx.input.active_device == .Mouse_Keyboard
}

gui_mouse_contains :: proc(ctx: ^Gui_Context, rect: Rect) -> bool {
	return gui_mouse_in_input_clip(ctx) && gui_contains(rect, ctx.input.mouse_pos)
}

gui_mouse_contains_circle :: proc(ctx: ^Gui_Context, center: Vec2, radius: f32) -> bool {
	return gui_mouse_in_input_clip(ctx) && gui_contains_circle(center, ctx.input.mouse_pos, radius)
}

gui_clamp01 :: proc(v: f32) -> f32 {
	if v < 0 do return 0
	if v > 1 do return 1
	return v
}

gui_measure_text :: proc(ctx: ^Gui_Context, text: string) -> Vec2 {
	return {gui_text_width(ctx, text), ctx.style.text_height}
}

gui_wrap_line_count :: proc(ctx: ^Gui_Context, text: string, max_width: f32) -> int {
	if max_width <= 0 {
		return 1
	}
	lines := make([dynamic]Gui_Text_Line, 0, 16)
	defer delete(lines)
	gui_text_wrap_lines(ctx, text, max_width, &lines)
	return max(len(lines), 1)
}

gui_text_wrap_lines :: proc(ctx: ^Gui_Context, text: string, max_width: f32, lines: ^[dynamic]Gui_Text_Line) {
	profile_start := time.tick_now()
	defer {
		gui_profile.wrap_calls += 1
		gui_profile.wrap_seconds += time.duration_seconds(time.tick_diff(profile_start, time.tick_now()))
	}
	bytes := transmute([]u8)text
	if len(bytes) == 0 {
		append(lines, Gui_Text_Line{})
		return
	}

	paragraph_start := 0
	for paragraph_start <= len(bytes) {
		paragraph_end := paragraph_start
		for paragraph_end < len(bytes) && bytes[paragraph_end] != '\n' {
			paragraph_end += 1
		}
		gui_text_wrap_paragraph(ctx, bytes, paragraph_start, paragraph_end, max_width, lines)
		if paragraph_end >= len(bytes) {
			break
		}
		paragraph_start = paragraph_end + 1
	}
}

gui_text_wrap_paragraph :: proc(ctx: ^Gui_Context, bytes: []u8, start, end: int, max_width: f32, lines: ^[dynamic]Gui_Text_Line) {
	if end <= start {
		append(lines, Gui_Text_Line{start, end})
		return
	}

	candidates := make([dynamic]Gui_Wrap_Candidate, 0, 16)
	defer delete(candidates)
	gui_text_wrap_candidates(ctx, bytes, start, end, max_width, &candidates)

	n := len(candidates)
	if n <= 1 {
		append(lines, gui_trim_wrap_span(bytes, start, end))
		return
	}

	large := f32(1.0e30)
	cost := make([]f32, n)
	previous := make([]int, n)
	defer delete(cost)
	defer delete(previous)

	for i in 0 ..< n {
		cost[i] = large
		previous[i] = -1
	}
	cost[0] = 0

	for i in 0 ..< n - 1 {
		if cost[i] >= large {
			continue
		}
		for j in i + 1 ..< n {
			trimmed := gui_trim_wrap_span(bytes, candidates[i].pos, candidates[j].pos)
			line_width := gui_text_span_width(ctx, bytes, trimmed.start, trimmed.end)
			if line_width <= 0 {
				continue
			}

			overflow := max(line_width - max_width, 0)
			leftover := max(max_width - line_width, 0)
			is_last := j == n - 1

			break_penalty := f32(0)
			if candidates[i].forced || candidates[j].forced {
				break_penalty = 500000
			}
			if overflow > 0 {
				break_penalty += overflow * overflow * overflow * 1000 + 500000
			}
			ragged_penalty := is_last ? f32(0) : leftover * leftover * leftover
			candidate := cost[i] + ragged_penalty + break_penalty
			if candidate < cost[j] {
				cost[j] = candidate
				previous[j] = i
			}

			if line_width > max_width {
				break
			}
		}
	}

	if previous[n - 1] < 0 {
		gui_text_wrap_greedy_fallback(ctx, bytes, start, end, max_width, lines)
		return
	}

	reversed := make([dynamic]Gui_Text_Line, 0, 8)
	defer delete(reversed)
	cursor := n - 1
	for cursor > 0 {
		prev := previous[cursor]
		if prev < 0 {
			break
		}
		trimmed := gui_trim_wrap_span(bytes, candidates[prev].pos, candidates[cursor].pos)
		append(&reversed, trimmed)
		cursor = prev
	}
	for i := len(reversed) - 1; i >= 0; i -= 1 {
		append(lines, reversed[i])
		if i == 0 {
			break
		}
	}
}

gui_text_wrap_candidates :: proc(ctx: ^Gui_Context, bytes: []u8, start, end: int, max_width: f32, out: ^[dynamic]Gui_Wrap_Candidate) {
	append(out, Gui_Wrap_Candidate{pos = start})
	cursor := start
	for cursor < end {
		next := cursor
		for next < end && !gui_is_wrap_space(bytes[next]) {
			next += 1
		}
		if next > cursor {
			word_width := gui_text_span_width(ctx, bytes, cursor, next)
			if word_width > max_width {
				gui_text_wrap_forced_candidates(ctx, bytes, cursor, next, max_width, out)
			}
		}
		for next < end && gui_is_wrap_space(bytes[next]) {
			next += 1
		}
		if next > start && next < end {
			gui_append_wrap_candidate(out, next, false)
		}
		cursor = next
	}
	gui_append_wrap_candidate(out, end, false)
}

gui_text_wrap_forced_candidates :: proc(ctx: ^Gui_Context, bytes: []u8, start, end: int, max_width: f32, out: ^[dynamic]Gui_Wrap_Candidate) {
	cursor := start
	for cursor < end {
		next := cursor
		width := f32(0)
		for next < end {
			advance := gui_glyph_advance(ctx, bytes[next])
			if next > cursor && width + advance > max_width {
				break
			}
			width += advance
			next += 1
		}
		if next <= cursor {
			next = cursor + 1
		}
		if next < end {
			gui_append_wrap_candidate(out, next, true)
		}
		cursor = next
	}
}

gui_append_wrap_candidate :: proc(out: ^[dynamic]Gui_Wrap_Candidate, pos: int, forced: bool) {
	if len(out^) > 0 {
		last := &out^[len(out^) - 1]
		if last.pos == pos {
			last.forced = last.forced || forced
			return
		}
	}
	append(out, Gui_Wrap_Candidate{pos = pos, forced = forced})
}

gui_text_wrap_greedy_fallback :: proc(ctx: ^Gui_Context, bytes: []u8, start, end: int, max_width: f32, lines: ^[dynamic]Gui_Text_Line) {
	cursor := start
	for cursor < end {
		next := cursor
		width := f32(0)
		for next < end {
			advance := gui_glyph_advance(ctx, bytes[next])
			if next > cursor && width + advance > max_width {
				break
			}
			width += advance
			next += 1
		}
		if next == cursor {
			next += 1
		}
		append(lines, gui_trim_wrap_span(bytes, cursor, next))
		cursor = next
	}
}

gui_text_width :: proc(ctx: ^Gui_Context, text: string) -> f32 {
	bytes := transmute([]u8)text
	return gui_text_span_width(ctx, bytes, 0, len(bytes))
}

gui_text_span_width :: proc(ctx: ^Gui_Context, bytes: []u8, start, end: int) -> f32 {
	if end <= start {
		return 0
	}
	return gui_font_text_width(.Body, bytes[start:end], ctx.style.text_scale, ctx.style.char_width)
}

gui_glyph_advance :: proc(ctx: ^Gui_Context, ch: u8) -> f32 {
	return gui_font_glyph_advance(.Body, ch, ctx.style.text_scale, ctx.style.char_width)
}

gui_font_text_width :: proc(font_kind: Gui_Font_Kind, bytes: []u8, scale, fallback_advance: f32) -> f32 {
	profile_start := time.tick_now()
	defer {
		gui_profile.width_calls += 1
		gui_profile.width_seconds += time.duration_seconds(time.tick_diff(profile_start, time.tick_now()))
	}
	if len(bytes) == 0 {
		return 0
	}
	effective_font_kind := gui_effective_font_kind(font_kind)
	shaper_ready := gui_text_shaper_ready && gui_font_kind_ready(effective_font_kind)
	cacheable := len(bytes) <= GUI_TEXT_WIDTH_CACHE_MAX_BYTES
	hash := u64(0)
	if cacheable {
		hash = gui_text_width_hash(effective_font_kind, bytes, scale, fallback_advance)
		slot := &gui_text_width_cache[int(hash % GUI_TEXT_WIDTH_CACHE_SLOTS)]
		if gui_text_width_cache_matches(slot, effective_font_kind, bytes, hash, scale, fallback_advance, shaper_ready) {
			gui_profile.width_cache_hits += 1
			return slot.width
		}
	}
	width := f32(0)
	if shaper_ready {
		width = vo_textshape_width(i32(effective_font_kind), raw_data(bytes), i32(len(bytes)), scale, fallback_advance)
	} else {
		for ch in bytes {
			width += gui_font_glyph_advance(effective_font_kind, ch, scale, fallback_advance)
		}
	}
	if cacheable {
		slot := &gui_text_width_cache[int(hash % GUI_TEXT_WIDTH_CACHE_SLOTS)]
		slot.hash = hash
		slot.len = len(bytes)
		slot.scale = scale
		slot.fallback_advance = fallback_advance
		slot.font_kind = effective_font_kind
		slot.width = width
		slot.shaper_ready = shaper_ready
		slot.valid = true
		copy(slot.bytes[:len(bytes)], bytes)
	}
	return width
}

gui_text_width_cache_matches :: proc(entry: ^Gui_Text_Width_Cache_Entry, font_kind: Gui_Font_Kind, bytes: []u8, hash: u64, scale, fallback_advance: f32, shaper_ready: bool) -> bool {
	if !entry.valid || entry.hash != hash || entry.len != len(bytes) || entry.scale != scale || entry.fallback_advance != fallback_advance || entry.font_kind != font_kind || entry.shaper_ready != shaper_ready {
		return false
	}
	for i in 0 ..< len(bytes) {
		if entry.bytes[i] != bytes[i] {
			return false
		}
	}
	return true
}

gui_text_width_hash :: proc(font_kind: Gui_Font_Kind, bytes: []u8, scale, fallback_advance: f32) -> u64 {
	hash := u64(14695981039346656037)
	hash = gui_hash_u64(hash, u64(len(bytes)))
	hash = gui_hash_u64(hash, u64(font_kind))
	hash = gui_hash_f32(hash, scale)
	hash = gui_hash_f32(hash, fallback_advance)
	for ch in bytes {
		hash = gui_hash_byte(hash, ch)
	}
	return hash
}

gui_hash_f32 :: proc(hash: u64, value: f32) -> u64 {
	return gui_hash_u64(hash, u64(transmute(u32)value))
}

gui_font_shape_text :: proc(font_kind: Gui_Font_Kind, bytes: []u8, scale: f32, out: []Gui_Shaped_Glyph) -> int {
	profile_start := time.tick_now()
	defer {
		gui_profile.shape_calls += 1
		gui_profile.shape_seconds += time.duration_seconds(time.tick_diff(profile_start, time.tick_now()))
	}
	effective_font_kind := gui_effective_font_kind(font_kind)
	if len(bytes) == 0 || len(out) == 0 || !gui_text_shaper_ready || !gui_font_kind_ready(effective_font_kind) {
		return 0
	}
	count := int(vo_textshape_shape(i32(effective_font_kind), raw_data(bytes), i32(len(bytes)), scale, raw_data(out), i32(len(out))))
	gui_profile.shape_glyphs += u64(max(count, 0))
	return count
}

gui_font_glyph_advance :: proc(font_kind: Gui_Font_Kind, ch: u8, scale, fallback: f32) -> f32 {
	_ = font_kind
	if ch >= GUI_FONT_GLYPH_FIRST && ch <= GUI_FONT_GLYPH_LAST {
		text_scale := scale
		if text_scale <= 0 {
			text_scale = 1
		}
		return GUI_FONT_ADVANCES[int(ch) - GUI_FONT_GLYPH_FIRST] * text_scale
	}
	return fallback
}

gui_font_glyph_slot :: proc(glyph_id: u32) -> i32 {
	if glyph_id >= GUI_FONT_GLYPH_FIRST && glyph_id <= GUI_FONT_GLYPH_LAST {
		return i32(glyph_id - GUI_FONT_GLYPH_FIRST)
	}
	return -1
}

gui_font_render_ascii_atlas :: proc(font_kind: Gui_Font_Kind, glyph_first, glyph_last, pixel_height, cell_width, cell_height, columns: int, rgba: []u8) -> bool {
	effective_font_kind := gui_effective_font_kind(font_kind)
	if len(rgba) == 0 || !gui_text_shaper_ready || !gui_font_kind_ready(effective_font_kind) {
		return false
	}
	return vo_textshape_render_ascii_atlas(
		i32(effective_font_kind),
		i32(glyph_first),
		i32(glyph_last),
		i32(pixel_height),
		i32(cell_width),
		i32(cell_height),
		i32(columns),
		raw_data(rgba),
		i32(len(rgba)),
	) != 0
}

gui_trim_wrap_span :: proc(bytes: []u8, start, end: int) -> Gui_Text_Line {
	s := start
	e := end
	for s < e && gui_is_wrap_space(bytes[s]) {
		s += 1
	}
	for e > s && gui_is_wrap_space(bytes[e - 1]) {
		e -= 1
	}
	return {s, e}
}

gui_is_break_boundary :: proc(bytes: []u8, pos, end: int) -> bool {
	if pos >= end {
		return true
	}
	if gui_is_wrap_space(bytes[pos]) {
		return true
	}
	if pos > 0 && gui_is_wrap_space(bytes[pos - 1]) {
		return true
	}
	return false
}

gui_is_wrap_space :: proc(ch: u8) -> bool {
	return ch == ' ' || ch == '\t' || ch == '\r'
}

gui_inset :: proc(rect: Rect, amount: f32) -> Rect {
	return {rect.x + amount, rect.y + amount, max(rect.w - amount * 2, 0), max(rect.h - amount * 2, 0)}
}

gui_inset_edges :: proc(rect: Rect, edges: Gui_Edge_Insets) -> Rect {
	return {
		rect.x + edges.left,
		rect.y + edges.top,
		max(rect.w - edges.left - edges.right, 0),
		max(rect.h - edges.top - edges.bottom, 0),
	}
}

gui_translate :: proc(rect: Rect, delta: Vec2) -> Rect {
	return {rect.x + delta.x, rect.y + delta.y, rect.w, rect.h}
}

gui_scale_from_center :: proc(rect: Rect, scale: f32) -> Rect {
	w := rect.w * scale
	h := rect.h * scale
	return {rect.x + (rect.w - w) * 0.5, rect.y + (rect.h - h) * 0.5, w, h}
}

gui_rotate_point :: proc(point, origin: Vec2, angle_radians: f32) -> Vec2 {
	c := math.cos(angle_radians)
	s := math.sin(angle_radians)
	x := point.x - origin.x
	y := point.y - origin.y
	return {origin.x + x * c - y * s, origin.y + x * s + y * c}
}

gui_rect_bottom :: proc(rect: Rect) -> f32 {
	return rect.y + rect.h
}

gui_rect_center :: proc(rect: Rect) -> Vec2 {
	return {rect.x + rect.w * 0.5, rect.y + rect.h * 0.5}
}

gui_current_spatial_group :: proc(ctx: ^Gui_Context) -> Gui_Spatial_Group {
	if ctx.spatial_group_depth > 0 {
		return ctx.spatial_groups[ctx.spatial_group_depth - 1]
	}
	return {id = GUI_ID_NONE, enabled = true}
}

gui_spatial_bounds_visible :: proc(ctx: ^Gui_Context, bounds: Rect) -> bool {
	if bounds.w <= 0 || bounds.h <= 0 {
		return false
	}
	if ctx.input_clip_depth <= 0 {
		return true
	}
	clip := gui_rect_intersection(bounds, ctx.input_clip_stack[ctx.input_clip_depth - 1])
	return clip.w > 0 && clip.h > 0
}

gui_register_spatial_item :: proc(ctx: ^Gui_Context, id: Gui_Id, bounds: Rect, enabled: bool) {
	if id == GUI_ID_NONE || ctx.spatial_item_count >= MAX_GUI_SPATIAL_ITEMS {
		return
	}
	group := gui_current_spatial_group(ctx)
	item_enabled := enabled && group.enabled && gui_spatial_bounds_visible(ctx, bounds)
	ctx.spatial_items[ctx.spatial_item_count] = {
		id = id,
		bounds = bounds,
		group = group.id,
		order = ctx.focus_order_next,
		enabled = item_enabled,
	}
	ctx.spatial_item_count += 1
	ctx.focus_order_next += 1
}

gui_find_spatial_item :: proc(ctx: ^Gui_Context, id: Gui_Id) -> (Gui_Spatial_Item, bool) {
	for i in 0 ..< ctx.spatial_item_count {
		item := ctx.spatial_items[i]
		if item.id == id && item.enabled {
			return item, true
		}
	}
	return {}, false
}

gui_spatial_item_registered :: proc(ctx: ^Gui_Context, id: Gui_Id) -> bool {
	for i in 0 ..< ctx.spatial_item_count {
		if ctx.spatial_items[i].id == id {
			return true
		}
	}
	return false
}

gui_spatial_candidate_score :: proc(current, candidate: Rect, dir_x, dir_y: f32) -> (valid: bool, forward, perpendicular: f32, overlap: bool) {
	current_center := gui_rect_center(current)
	candidate_center := gui_rect_center(candidate)
	epsilon := f32(0.001)
	if dir_x > 0 {
		forward = candidate_center.x - current_center.x
		perpendicular = math.abs(candidate_center.y - current_center.y)
		overlap = candidate.y < current.y + current.h && candidate.y + candidate.h > current.y
	} else if dir_x < 0 {
		forward = current_center.x - candidate_center.x
		perpendicular = math.abs(candidate_center.y - current_center.y)
		overlap = candidate.y < current.y + current.h && candidate.y + candidate.h > current.y
	} else if dir_y > 0 {
		forward = candidate_center.y - current_center.y
		perpendicular = math.abs(candidate_center.x - current_center.x)
		overlap = candidate.x < current.x + current.w && candidate.x + candidate.w > current.x
	} else if dir_y < 0 {
		forward = current_center.y - candidate_center.y
		perpendicular = math.abs(candidate_center.x - current_center.x)
		overlap = candidate.x < current.x + current.w && candidate.x + candidate.w > current.x
	} else {
		return false, 0, 0, false
	}
	valid = forward > epsilon
	return
}

gui_apply_spatial_navigation :: proc(ctx: ^Gui_Context) {
	if ctx.focus_moved || ctx.focused == GUI_ID_NONE || ctx.text_edit_id != GUI_ID_NONE || ctx.open_panel != GUI_ID_NONE || ctx.focus_edit_id != GUI_ID_NONE {
		return
	}
	dir_x := ctx.input.nav_pressed_x
	dir_y := ctx.input.nav_pressed_y
	if dir_x == 0 && dir_y == 0 {
		return
	}
	if math.abs(dir_x) >= math.abs(dir_y) {
		dir_y = 0
		dir_x = dir_x > 0 ? f32(1) : f32(-1)
	} else {
		dir_x = 0
		dir_y = dir_y > 0 ? f32(1) : f32(-1)
	}
	current, ok := gui_find_spatial_item(ctx, ctx.focused)
	if !ok {
		return
	}
	best_id := GUI_ID_NONE
	best_forward := f32(0)
	best_perpendicular := f32(0)
	best_overlap := false
	best_order := 0
	for i in 0 ..< ctx.spatial_item_count {
		item := ctx.spatial_items[i]
		if !item.enabled || item.id == current.id || item.group != current.group {
			continue
		}
		valid, forward, perpendicular, overlap := gui_spatial_candidate_score(current.bounds, item.bounds, dir_x, dir_y)
		if !valid {
			continue
		}
		better := best_id == GUI_ID_NONE
		if !better && overlap != best_overlap {
			better = overlap
		}
		if !better && overlap == best_overlap && forward < best_forward {
			better = true
		}
		if !better && overlap == best_overlap && forward == best_forward && perpendicular < best_perpendicular {
			better = true
		}
		if !better && overlap == best_overlap && forward == best_forward && perpendicular == best_perpendicular && item.order < best_order {
			better = true
		}
		if better {
			best_id = item.id
			best_forward = forward
			best_perpendicular = perpendicular
			best_overlap = overlap
			best_order = item.order
		}
	}
	if best_id != GUI_ID_NONE {
		ctx.focused = best_id
		ctx.focus_moved = true
	}
}

gui_control :: proc(ctx: ^Gui_Context, id: Gui_Id, bounds: Rect, enabled := true) -> Gui_Control {
	if enabled {
		gui_register_focusable(ctx, id, bounds)
	}

	hovered := enabled && gui_mouse_contains(ctx, bounds)
	if hovered {
		ctx.hot = id
		if ctx.input.mouse_pressed {
			ctx.active = id
			ctx.focused = id
		}
	}

	focused := enabled && ctx.focused == id
	nav_x, nav_y: f32
	if focused {
		nav_x = ctx.input.nav_x
		nav_y = ctx.input.nav_y
	}

	return {
		id = id,
		bounds = bounds,
		enabled = enabled,
		hovered = hovered,
		focused = focused,
		activated = focused && ctx.input.accept,
		nav_x = nav_x,
		nav_y = nav_y,
	}
}

gui_focused_nav :: proc(ctx: ^Gui_Context, id: Gui_Id) -> (nav_x, nav_y: f32) {
	if ctx.focused != id || ctx.focus_edit_id != id {
		return 0, 0
	}
	nav_x = ctx.input.nav_x
	nav_y = ctx.input.nav_y
	return
}

gui_key_up_pressed :: proc(ctx: ^Gui_Context) -> bool {
	return ctx.input.nav_pressed_y < 0
}

gui_key_down_pressed :: proc(ctx: ^Gui_Context) -> bool {
	return ctx.input.nav_pressed_y > 0
}

gui_focused_nav_pressed :: proc(ctx: ^Gui_Context, id: Gui_Id) -> (nav_x, nav_y: f32) {
	if ctx.focused != id || ctx.focus_edit_id != id {
		return 0, 0
	}
	nav_x = ctx.input.nav_pressed_x
	nav_y = ctx.input.nav_pressed_y
	return
}

gui_key_left_pressed :: proc(ctx: ^Gui_Context) -> bool {
	return ctx.input.nav_pressed_x < 0
}

gui_key_right_pressed :: proc(ctx: ^Gui_Context) -> bool {
	return ctx.input.nav_pressed_x > 0
}

gui_update_focus_edit :: proc(ctx: ^Gui_Context, id: Gui_Id, focused: bool) -> bool {
	if !focused {
		gui_focus_edit_end(ctx, id)
		return false
	}
	if ctx.focus_edit_id != id && (ctx.input.accept || ctx.input.key_space) {
		gui_focus_edit_begin(ctx, id)
	}
	if ctx.focus_edit_id == id {
		ctx.focus_edit_seen = true
	}
	return ctx.focus_edit_id == id
}

gui_register_focusable :: proc(ctx: ^Gui_Context, id: Gui_Id, bounds := Rect{}) {
	gui_debug_register_interactive_id(ctx, id)
	if bounds.w > 0 && bounds.h > 0 {
		gui_register_spatial_item(ctx, id, bounds, true)
	}
	if ctx.focus_first == GUI_ID_NONE {
		ctx.focus_first = id
	}
	if ctx.input.focus_prev && ctx.focused == id && !ctx.focus_moved {
		next_focus := ctx.focus_prev
		if next_focus == GUI_ID_NONE {
			next_focus = ctx.focus_last_previous
		}
		if next_focus != GUI_ID_NONE {
			ctx.focused = next_focus
			ctx.focus_moved = true
		}
	}
	if ctx.focus_next_from != GUI_ID_NONE && ctx.focus_prev == ctx.focus_next_from && !ctx.focus_moved {
		ctx.focused = id
		ctx.focus_moved = true
	}
	ctx.focus_prev = id
	ctx.focus_last = id
}

gui_button_behavior :: proc(ctx: ^Gui_Context, id: Gui_Id, bounds: Rect, enabled: bool) -> bool {
	control := gui_control(ctx, id, bounds, enabled)
	return control.activated || (enabled && control.hovered && ctx.active == id && ctx.input.mouse_released)
}

gui_drag_region :: proc(ctx: ^Gui_Context, id: Gui_Id, bounds: Rect) -> bool {
	control := gui_control(ctx, id, bounds, true)
	_ = control
	return ctx.active == id && ctx.input.mouse_down
}

gui_drag_handle_region :: proc(ctx: ^Gui_Context, id: Gui_Id, bounds: Rect, handle: Vec2, handle_radius: f32) -> bool {
	gui_register_focusable(ctx, id, bounds)
	hovered := gui_mouse_contains(ctx, bounds) || gui_mouse_contains_circle(ctx, handle, handle_radius)
	if hovered {
		ctx.hot = id
		if ctx.input.mouse_pressed {
			ctx.active = id
			ctx.focused = id
		}
	}
	return ctx.active == id && ctx.input.mouse_down
}

gui_debug_register_interactive_id :: proc(ctx: ^Gui_Context, id: Gui_Id) {
	if id == GUI_ID_NONE {
		return
	}
	for i in 0 ..< ctx.debug_registered_id_count {
		if ctx.debug_registered_ids[i] == id {
			ctx.debug_duplicate_id_count += 1
			return
		}
	}
	if ctx.debug_registered_id_count < len(ctx.debug_registered_ids) {
		ctx.debug_registered_ids[ctx.debug_registered_id_count] = id
		ctx.debug_registered_id_count += 1
	}
}

gui_rect_point_to_normalized :: proc(rect: Rect, point: Vec2) -> Vec2 {
	return {
		gui_clamp01((point.x - rect.x) / max(rect.w, 1)),
		gui_clamp01((point.y - rect.y) / max(rect.h, 1)),
	}
}

gui_normalized_to_rect_point :: proc(rect: Rect, value: Vec2) -> Vec2 {
	return {
		rect.x + rect.w * gui_clamp01(value.x),
		rect.y + rect.h * gui_clamp01(value.y),
	}
}

gui_vec2_to_normalized :: proc(value, min_value, max_value: Vec2) -> Vec2 {
	return {
		gui_clamp01((value.x - min_value.x) / max(max_value.x - min_value.x, 0.000001)),
		gui_clamp01((value.y - min_value.y) / max(max_value.y - min_value.y, 0.000001)),
	}
}

gui_vec2_from_normalized :: proc(value, min_value, max_value: Vec2) -> Vec2 {
	n := Vec2{gui_clamp01(value.x), gui_clamp01(value.y)}
	return {
		min_value.x + (max_value.x - min_value.x) * n.x,
		min_value.y + (max_value.y - min_value.y) * n.y,
	}
}

gui_draw_handle :: proc(ctx: ^Gui_Context, center: Vec2, radius: f32) {
	rect := Rect{center.x - radius, center.y - radius, radius * 2, radius * 2}
	gui_ellipse(ctx, rect, ctx.style.text)
	gui_ellipse_stroke(ctx, rect, ctx.style.panel_border, ctx.style.border_width)
	gui_ellipse_stroke(ctx, gui_inset(rect, -ctx.style.focus_ring_width), ctx.style.accent, ctx.style.focus_ring_width)
}

gui_draw_checker_grid :: proc(ctx: ^Gui_Context, rect: Rect) {
	cols := 8
	rows := 6
	for y in 0 ..< rows {
		for x in 0 ..< cols {
			t := ((x + y) % 2 == 0) ? f32(0.16) : f32(0.23)
			color := Color{t, t + 0.015, t + 0.025, 1}
			gui_rect(ctx, {
				rect.x + rect.w * f32(x) / f32(cols),
				rect.y + rect.h * f32(y) / f32(rows),
				rect.w / f32(cols) + 1,
				rect.h / f32(rows) + 1,
			}, color)
		}
	}
}

gui_wrap01 :: proc(v: f32) -> f32 {
	result := v
	for result < 0 {
		result += 1
	}
	for result >= 1 {
		result -= 1
	}
	return result
}

gui_hue_from_delta :: proc(delta: Vec2) -> f32 {
	angle := math.atan2(delta.y, delta.x)
	if angle < 0 {
		angle += GUI_TAU
	}
	return gui_wrap01(angle / GUI_TAU)
}

gui_hsv_to_rgb :: proc(hsv: Hsv_Color) -> Color {
	h := gui_wrap01(hsv.h) * 6
	s := gui_clamp01(hsv.s)
	v := gui_clamp01(hsv.v)
	c := v * s
	x := c * (1 - abs((h - f32(int(h / 2) * 2)) - 1))
	m := v - c
	r, g, b: f32
	if h < 1 {
		r, g, b = c, x, 0
	} else if h < 2 {
		r, g, b = x, c, 0
	} else if h < 3 {
		r, g, b = 0, c, x
	} else if h < 4 {
		r, g, b = 0, x, c
	} else if h < 5 {
		r, g, b = x, 0, c
	} else {
		r, g, b = c, 0, x
	}
	return {r + m, g + m, b + m, gui_clamp01(hsv.a)}
}

gui_rgb_to_hsv :: proc(color: Color) -> Hsv_Color {
	r := gui_clamp01(color.r)
	g := gui_clamp01(color.g)
	b := gui_clamp01(color.b)
	max_c := max(max(r, g), b)
	min_c := min(min(r, g), b)
	delta := max_c - min_c
	h := f32(0)
	if delta > 0.000001 {
		if max_c == r {
			h = ((g - b) / delta)
			if h < 0 {
				h += 6
			}
		} else if max_c == g {
			h = (b - r) / delta + 2
		} else {
			h = (r - g) / delta + 4
		}
		h /= 6
	}
	s := max_c <= 0 ? f32(0) : delta / max_c
	return {gui_wrap01(h), gui_clamp01(s), gui_clamp01(max_c), gui_clamp01(color.a)}
}

gui_clear_query :: proc(buffer: []u8) {
	if len(buffer) > 0 {
		buffer[0] = 0
	}
}

gui_query_len :: proc(buffer: []u8) -> int {
	n := 0
	for n < len(buffer) && buffer[n] != 0 {
		n += 1
	}
	return n
}

gui_query_string :: proc(buffer: []u8) -> string {
	n := gui_query_len(buffer)
	return string(buffer[:n])
}

gui_append_query :: proc(buffer: []u8, text: []u8) {
	n := gui_query_len(buffer)
	for ch in text {
		if ch == 0 || n >= len(buffer) - 1 {
			break
		}
		buffer[n] = ch
		n += 1
	}
	if len(buffer) > 0 {
		buffer[n] = 0
	}
}

gui_pop_query :: proc(buffer: []u8) {
	n := gui_query_len(buffer)
	if n > 0 {
		buffer[n - 1] = 0
	}
}

gui_string_contains_fold :: proc(haystack, needle: string) -> bool {
	h := transmute([]u8)haystack
	n := transmute([]u8)needle
	if len(n) == 0 {
		return true
	}
	if len(n) > len(h) {
		return false
	}
	for start in 0 ..= len(h) - len(n) {
		matched := true
		for i in 0 ..< len(n) {
			if gui_ascii_fold(h[start + i]) != gui_ascii_fold(n[i]) {
				matched = false
				break
			}
		}
		if matched {
			return true
		}
	}
	return false
}

gui_ascii_fold :: proc(ch: u8) -> u8 {
	if ch >= 'A' && ch <= 'Z' {
		return ch + ('a' - 'A')
	}
	return ch
}

gui_next_match :: proc(matches: []int, current, direction: int) -> int {
	if len(matches) == 0 {
		return -1
	}
	index := 0
	for i in 0 ..< len(matches) {
		if matches[i] == current {
			index = i
			break
		}
	}
	index += direction
	if index < 0 {
		index = len(matches) - 1
	}
	if index >= len(matches) {
		index = 0
	}
	return matches[index]
}

gui_match_contains :: proc(matches: []int, value: int) -> bool {
	for match in matches {
		if match == value {
			return true
		}
	}
	return false
}

gui_number_edit_f32 :: proc(ctx: ^Gui_Context, id: Gui_Id, value: ^f32, min_value, max_value: f32) -> bool {
	if ctx.input.back || ctx.input.accept {
		ctx.text_edit_id = GUI_ID_NONE
		ctx.text_edit_len = 0
		return false
	}

	if ctx.text_edit_id != id {
		gui_number_edit_begin(ctx, id, value^)
	}
	edited := gui_text_edit_process(ctx, id, ctx.text_edit_buffer[:], &ctx.text_edit_len, true)

	if ctx.text_edit_len == 0 {
		return edited
	}
	parsed, ok := strconv.parse_f32(string(ctx.text_edit_buffer[:ctx.text_edit_len]))
	if !ok {
		return edited
	}
	clamped := min(max(parsed, min_value), max_value)
	if value^ == clamped {
		return edited
	}
	value^ = clamped
	return true
}

gui_number_edit_begin :: proc(ctx: ^Gui_Context, id: Gui_Id, value: f32) {
	ctx.text_edit_id = id
	gui_number_edit_set_value(ctx, value)
	ctx.text_edit_caret = ctx.text_edit_len
	ctx.text_edit_anchor = 0
	ctx.text_edit_scroll_x = 0
	ctx.text_edit_blink = 0
	ctx.text_edit_selecting = false
}

gui_number_edit_wants_text :: proc(ctx: ^Gui_Context) -> bool {
	modifier := ctx.input.key_ctrl || ctx.input.key_super
	if ctx.input.text_input_len > 0 {
		return true
	}
	if ctx.input.accept || ctx.input.key_backspace || ctx.input.key_delete {
		return true
	}
	if modifier && (ctx.input.key_a || ctx.input.key_v || ctx.input.key_x || ctx.input.key_c) {
		return true
	}
	return false
}

gui_number_edit_set_value :: proc(ctx: ^Gui_Context, value: f32) {
	buf: [64]u8
	text := fmt.bprintf(buf[:], "%.3f", value)
	ctx.text_edit_len = min(len(text), len(ctx.text_edit_buffer))
	copy(ctx.text_edit_buffer[:], transmute([]u8)text[:ctx.text_edit_len])
	for ctx.text_edit_len > 0 && ctx.text_edit_buffer[ctx.text_edit_len - 1] == '0' {
		ctx.text_edit_len -= 1
	}
	if ctx.text_edit_len > 0 && ctx.text_edit_buffer[ctx.text_edit_len - 1] == '.' {
		ctx.text_edit_len -= 1
	}
}

gui_number_edit_accepts_char :: proc(ch: u8) -> bool {
	switch ch {
	case '0'..='9', '-', '+', '.', 'e', 'E':
		return true
	}
	return false
}

gui_utf8_is_continuation :: proc(ch: u8) -> bool {
	return (ch & 0xC0) == 0x80
}

gui_utf8_clamp_index :: proc(index, length: int) -> int {
	return max(min(index, length), 0)
}

gui_utf8_prev_index :: proc(bytes: []u8, index: int) -> int {
	cursor := max(min(index, len(bytes)), 0)
	if cursor <= 0 {
		return 0
	}
	cursor -= 1
	for cursor > 0 && gui_utf8_is_continuation(bytes[cursor]) {
		cursor -= 1
	}
	return cursor
}

gui_utf8_next_index :: proc(bytes: []u8, index: int) -> int {
	cursor := max(min(index, len(bytes)), 0)
	if cursor >= len(bytes) {
		return len(bytes)
	}
	cursor += 1
	for cursor < len(bytes) && gui_utf8_is_continuation(bytes[cursor]) {
		cursor += 1
	}
	return cursor
}

gui_push_id :: proc(ctx: ^Gui_Context, key: string) {
	if ctx.id_depth >= MAX_GUI_ID_DEPTH {
		return
	}
	ctx.id_stack[ctx.id_depth] = gui_make_id(ctx, key)
	ctx.id_depth += 1
}

gui_push_id_int :: proc(ctx: ^Gui_Context, key: int) {
	if ctx.id_depth >= MAX_GUI_ID_DEPTH {
		return
	}
	ctx.id_stack[ctx.id_depth] = gui_make_id_int(ctx, key)
	ctx.id_depth += 1
}

gui_push_id_ptr :: proc(ctx: ^Gui_Context, key: rawptr) {
	if ctx.id_depth >= MAX_GUI_ID_DEPTH {
		return
	}
	ctx.id_stack[ctx.id_depth] = gui_make_id_ptr(ctx, key)
	ctx.id_depth += 1
}

gui_pop_id :: proc(ctx: ^Gui_Context) {
	if ctx.id_depth > 0 {
		ctx.id_depth -= 1
	}
}

gui_current_id :: proc(ctx: ^Gui_Context) -> Gui_Id {
	if ctx.id_depth <= 0 {
		return GUI_ID_NONE
	}
	return ctx.id_stack[ctx.id_depth - 1]
}

gui_make_id :: proc(ctx: ^Gui_Context, key: string) -> Gui_Id {
	hash := gui_id_seed(ctx)
	hash = gui_hash_byte(hash, 's')
	for ch in transmute([]u8)key {
		hash = gui_hash_byte(hash, ch)
	}
	return gui_id_finish(hash)
}

gui_make_id_int :: proc(ctx: ^Gui_Context, key: int) -> Gui_Id {
	hash := gui_id_seed(ctx)
	hash = gui_hash_byte(hash, 'i')
	return gui_id_finish(gui_hash_u64(hash, u64(key)))
}

gui_make_id_ptr :: proc(ctx: ^Gui_Context, key: rawptr) -> Gui_Id {
	hash := gui_id_seed(ctx)
	hash = gui_hash_byte(hash, 'p')
	return gui_id_finish(gui_hash_u64(hash, u64(uintptr(key))))
}

gui_id_index :: proc(ctx: ^Gui_Context, key: string, index: int) -> Gui_Id {
	return gui_id_child_int(gui_make_id(ctx, key), index)
}

gui_id_child :: proc(parent: Gui_Id, key: string) -> Gui_Id {
	hash := gui_hash_byte(u64(parent), 'c')
	for ch in transmute([]u8)key {
		hash = gui_hash_byte(hash, ch)
	}
	return gui_id_finish(hash)
}

gui_id_child_int :: proc(parent: Gui_Id, key: int) -> Gui_Id {
	hash := gui_hash_byte(u64(parent), 'n')
	return gui_id_finish(gui_hash_u64(hash, u64(key)))
}

gui_id_seed :: proc(ctx: ^Gui_Context) -> u64 {
	parent := gui_current_id(ctx)
	if parent == GUI_ID_NONE {
		return 14695981039346656037
	}
	return u64(parent)
}

gui_hash_byte :: proc(hash: u64, ch: u8) -> u64 {
	return (hash ~ u64(ch)) * 1099511628211
}

gui_hash_u64 :: proc(hash: u64, value: u64) -> u64 {
	h := hash
	v := value
	for _ in 0 ..< 8 {
		h = gui_hash_byte(h, u8(v & 0xff))
		v >>= 8
	}
	return h
}

gui_id_finish :: proc(hash: u64) -> Gui_Id {
	h := hash
	if h == 0 {
		h = 1
	}
	return Gui_Id(h)
}
