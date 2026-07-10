package ui

import "core:math"
import "core:fmt"
import "core:strconv"
import "core:sync"
import "core:time"

when ODIN_OS == .Windows {
	foreign import textshape "../../third_party/textshape/textshape.lib"
} else {
	foreign import textshape "../../third_party/textshape/libtextshape.a"
}

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

Controller_Prompt_Style :: enum {
	Xbox,
	PlayStation,
	Steam_Deck,
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
	wheel_delta_x: f32,
	wheel_delta: f32,
	delta_time: f32,
	active_device: Input_Device_Kind,
	controller_prompt_style: Controller_Prompt_Style,
	pointer_enabled: bool,
	virtual_cursor_pos: Vec2,
	nav_x: f32,
	nav_y: f32,
	nav_pressed_x: f32,
	nav_pressed_y: f32,
	accept: bool,
	accept_pressed: bool,
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
	key_f1: bool,
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

// Shared controller focus primitives. Screens own their region hierarchy; the
// framework owns phase transitions and optional per-region cursor memory.
Controller_Focus_Phase :: enum {
	Unfocused,
	Region,
	Child_Region,
	Active_Control,
}

Controller_Focus_Memory :: struct {
	region: Gui_Id,
	control: Gui_Id,
}

MAX_CONTROLLER_FOCUS_MEMORY :: 32

Controller_Focus_State :: struct {
	phase: Controller_Focus_Phase,
	region: Gui_Id,
	parent_region: Gui_Id,
	active_control: Gui_Id,
	remember_focus: bool,
	memory: [MAX_CONTROLLER_FOCUS_MEMORY]Controller_Focus_Memory,
	memory_count: int,
}

Controller_Edit_Snapshot_Kind :: enum {
	None,
	Float,
	Integer,
	Boolean,
	Text,
	Vec2,
	Hsv,
}

gui_controller_focus_init :: proc(state: ^Controller_Focus_State, remember_focus := true) {
	state^ = {phase = .Unfocused, remember_focus = remember_focus}
}

gui_controller_focus_remember :: proc(state: ^Controller_Focus_State, region, control: Gui_Id) {
	if state == nil || !state.remember_focus || region == GUI_ID_NONE || control == GUI_ID_NONE {
		return
	}
	for i in 0 ..< state.memory_count {
		if state.memory[i].region == region {
			state.memory[i].control = control
			return
		}
	}
	if state.memory_count < MAX_CONTROLLER_FOCUS_MEMORY {
		state.memory[state.memory_count] = {region = region, control = control}
		state.memory_count += 1
	}
}

gui_controller_focus_restore :: proc(state: ^Controller_Focus_State, region, fallback: Gui_Id) -> Gui_Id {
	if state != nil && state.remember_focus {
		for i in 0 ..< state.memory_count {
			if state.memory[i].region == region && state.memory[i].control != GUI_ID_NONE {
				return state.memory[i].control
			}
		}
	}
	return fallback
}

gui_controller_focus_enter_region :: proc(state: ^Controller_Focus_State, region, parent_region, fallback: Gui_Id) -> Gui_Id {
	if state == nil {
		return fallback
	}
	state.parent_region = parent_region
	state.region = region
	state.active_control = GUI_ID_NONE
	state.phase = parent_region == GUI_ID_NONE ? .Region : .Child_Region
	return gui_controller_focus_restore(state, region, fallback)
}

gui_controller_focus_activate :: proc(state: ^Controller_Focus_State, control: Gui_Id) {
	if state == nil || control == GUI_ID_NONE {
		return
	}
	state.active_control = control
	state.phase = .Active_Control
}

gui_controller_focus_deactivate :: proc(state: ^Controller_Focus_State) {
	if state == nil {
		return
	}
	state.active_control = GUI_ID_NONE
	state.phase = state.parent_region == GUI_ID_NONE ? .Region : .Child_Region
}

gui_controller_focus_leave_region :: proc(state: ^Controller_Focus_State) {
	if state == nil {
		return
	}
	if state.parent_region != GUI_ID_NONE {
		state.region = state.parent_region
		state.parent_region = GUI_ID_NONE
		state.phase = .Region
	} else {
		state.region = GUI_ID_NONE
		state.phase = .Unfocused
	}
	state.active_control = GUI_ID_NONE
}

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
	scrollbar_gutter: f32,
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
	focus_record: int,
}

Gui_Scroll_Focus_Record :: struct {
	viewport: Rect,
	scroll: f32,
	max_scroll: f32,
	target_scroll: ^f32,
	animation_id: Gui_Id,
	parent: int,
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
MAX_GUI_SCROLL_FOCUS_RECORDS :: 32
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
	focusable: bool,
	visible: bool,
	scroll_owner: int,
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
	fine_pointer_drag_id: Gui_Id,
	text_edit_id: Gui_Id,
	text_edit_buffer: [64]u8,
	text_edit_len: int,
	text_edit_caret: int,
	text_edit_anchor: int,
	text_edit_scroll_x: f32,
	text_edit_blink: f32,
	text_edit_selecting: bool,
	wants_text_input: bool,
	number_edit_snapshot_id: Gui_Id,
	number_edit_snapshot_value: f32,
	clipboard_set_pending: bool,
	clipboard_set_text: [256]u8,
	clipboard_set_len: int,
	focus_order_next: int,
	focus_moved: bool,
	focus_edit_id: Gui_Id,
	focus_edit_seen: bool,
	controller_explicit_activation: bool,
	controller_armed_id: Gui_Id,
	controller_snapshot_id: Gui_Id,
	controller_snapshot_kind: Controller_Edit_Snapshot_Kind,
	controller_snapshot_f32: f32,
	controller_snapshot_int: int,
	controller_snapshot_bool: bool,
	controller_snapshot_vec2: Vec2,
	controller_snapshot_hsv: Hsv_Color,
	controller_snapshot_text: [256]u8,
	controller_snapshot_text_len: int,
	controller_cancel_id: Gui_Id,
	spatial_items: [MAX_GUI_SPATIAL_ITEMS]Gui_Spatial_Item,
	spatial_item_count: int,
	spatial_groups: [MAX_GUI_SPATIAL_GROUP_DEPTH]Gui_Spatial_Group,
	spatial_group_depth: int,
	focus_scope: Gui_Id,
	focus_scope_active: bool,
	frame_index: u64,
	open_panel: Gui_Id,
	scroll_drag_id: Gui_Id,
	scroll_drag_start_pos: Vec2,
	scroll_drag_start_scroll: f32,
	scroll_drag_consumed: bool,
	scroll_drag_release_pending: bool,
	combo_highlight: int,
	combo_scroll: f32,
	combo_popup_visible: bool,
	combo_popup_id: Gui_Id,
	combo_popup_rect: Rect,
	combo_popup_options: []string,
	combo_popup_query: [128]u8,
	combo_popup_query_len: int,
	tooltip_visible: bool,
	tooltip_from_hover: bool,
	tooltip_rect: Rect,
	tooltip_text: string,
	notice_text: [192]u8,
	notice_text_len: int,
	notice_seconds: f32,
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
	scroll_focus_records: [MAX_GUI_SCROLL_FOCUS_RECORDS]Gui_Scroll_Focus_Record,
	scroll_focus_record_count: int,
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
		scrollbar_gutter = 8,
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
	style.scrollbar_gutter *= s
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
	style.scrollbar_gutter = min(max(gui_snap(rhythm * 0.20), 6), 16)
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
	raw_mouse_released := frame_input.mouse_released
	ctx.scroll_drag_release_pending = ctx.scroll_drag_id != GUI_ID_NONE && raw_mouse_released
	if ctx.scroll_drag_release_pending && ctx.scroll_drag_consumed {
		// A completed scroll gesture must not also activate the control that
		// received the initial press.
		frame_input.mouse_released = false
	}
	if ctx.scroll_drag_id != GUI_ID_NONE && !frame_input.mouse_down && !raw_mouse_released {
		ctx.scroll_drag_id = GUI_ID_NONE
		ctx.scroll_drag_consumed = false
		ctx.scroll_drag_release_pending = false
	}
	gui_input_apply_keyboard_fallbacks(&frame_input, ctx.input)
	if frame_input.mouse_button == 2 || frame_input.mouse_button == 3 {
		// Regular widgets only capture the primary pointer. Secondary input stays
		// available through its semantic fields, while middle mouse remains an
		// application-level camera gesture and cannot click or drag UI controls.
		frame_input.mouse_down = false
		frame_input.mouse_pressed = false
		frame_input.mouse_released = false
	}
	ctx.previous_input = ctx.input
	// Controller focus is navigational until the user explicitly accepts an
	// editable control. Mouse and keyboard retain their direct-manipulation
	// conventions (click-to-drag, focused text entry, arrow-key editing).
	ctx.controller_explicit_activation = frame_input.active_device == .Controller
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
	ctx.focus_moved = false
	ctx.focus_edit_seen = false
	ctx.wants_text_input = false
	ctx.spatial_item_count = 0
	ctx.spatial_group_depth = 0
	ctx.focus_scope = GUI_ID_NONE
	ctx.focus_scope_active = false
	ctx.combo_popup_visible = false
	ctx.tooltip_visible = false
	ctx.tooltip_from_hover = false
	if ctx.notice_seconds > 0 {
		ctx.notice_seconds = max(ctx.notice_seconds - max(frame_input.delta_time, 0), 0)
		if ctx.notice_seconds <= 0 {
			ctx.notice_text_len = 0
		}
	}
	ctx.layout_depth = 0
	ctx.input_clip_depth = 0
	ctx.next_overlay_input_rect_count = 0
	ctx.overlay_input_depth = 0
	ctx.scroll_depth = 0
	ctx.scroll_focus_record_count = 0
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
	input.primary_down = input.primary_down || (input.mouse_down && input.mouse_button != 2 && input.mouse_button != 3)
	input.primary_pressed = input.primary_pressed || (input.mouse_pressed && input.mouse_button != 2 && input.mouse_button != 3)
	input.primary_released = input.primary_released || (input.mouse_released && input.mouse_button != 2 && input.mouse_button != 3)
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
	gui_draw_notice_overlay(ctx)
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
		ctx.fine_pointer_drag_id = GUI_ID_NONE
	}
	if ctx.focus_edit_id != GUI_ID_NONE && ctx.input.back {
		cancelled_id := ctx.focus_edit_id
		ctx.focus_edit_id = GUI_ID_NONE
		if ctx.controller_armed_id == cancelled_id {
			ctx.controller_armed_id = GUI_ID_NONE
		}
		gui_controller_edit_clear_snapshot(ctx, cancelled_id)
	}
	if ctx.focus_edit_id != GUI_ID_NONE && (!ctx.focus_edit_seen || ctx.focused != ctx.focus_edit_id || !gui_spatial_item_registered(ctx, ctx.focus_edit_id)) {
		abandoned_id := ctx.focus_edit_id
		ctx.focus_edit_id = GUI_ID_NONE
		if ctx.controller_armed_id == abandoned_id {
			ctx.controller_armed_id = GUI_ID_NONE
		}
		gui_controller_edit_clear_snapshot(ctx, abandoned_id)
	}
	gui_enforce_focus_scope(ctx)
	gui_apply_tab_navigation(ctx)
	gui_apply_spatial_navigation(ctx)
	// A wheel gesture is an explicit request to move the viewport.  Do not let
	// focus reveal snap it back toward the currently hovered/focused control.
	if ctx.focus_moved && !ctx.wheel_scroll_consumed {
		gui_reveal_focused_item(ctx)
	}
	if ctx.focused != GUI_ID_NONE && !gui_spatial_item_registered(ctx, ctx.focused) {
		stale_id := ctx.focused
		if ctx.text_edit_id == ctx.focused {
			ctx.text_edit_id = GUI_ID_NONE
			ctx.text_edit_len = 0
			ctx.text_edit_selecting = false
		}
		ctx.focused = GUI_ID_NONE
		ctx.focus_edit_id = GUI_ID_NONE
		ctx.controller_armed_id = GUI_ID_NONE
		gui_controller_edit_clear_snapshot(ctx, stale_id)
	}
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

gui_focus_scope_trap_current :: proc(ctx: ^Gui_Context) {
	if ctx.spatial_group_depth <= 0 {
		return
	}
	group := ctx.spatial_groups[ctx.spatial_group_depth - 1]
	if group.enabled {
		ctx.focus_scope = group.id
		ctx.focus_scope_active = true
	}
}

gui_focus_scope_release :: proc(ctx: ^Gui_Context) {
	ctx.focus_scope = GUI_ID_NONE
	ctx.focus_scope_active = false
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
	// A stable scrim keeps controls legible over bright, high-frequency
	// simulations while the refractive layer preserves the glass character.
	gui_round_rect(ctx, bounds, ctx.style.radius_panel, ctx.style.panel)
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
	gui_scroll_begin_internal(ctx, viewport, content_height, scroll, false)
}

gui_scroll_begin_draggable :: proc(ctx: ^Gui_Context, viewport: Rect, content_height: f32, scroll: ^f32) {
	gui_scroll_begin_internal(ctx, viewport, content_height, scroll, true)
}

gui_scroll_begin_internal :: proc(ctx: ^Gui_Context, viewport: Rect, content_height: f32, scroll: ^f32, draggable: bool) {
	max_scroll := max(content_height - viewport.h, 0)
	previous_scroll, consumed_wheel := gui_apply_wheel_scroll(ctx, viewport, scroll, max_scroll, 32, ctx.scroll_depth)
	scroll^ = min(max(scroll^, 0), max_scroll)
	gui_record_scroll_hit(ctx, viewport, scroll^, max_scroll, 32, ctx.scroll_depth)
	scroll_id := gui_id_child_int(gui_make_id(ctx, "scroll"), ctx.scroll_depth)
	direct_scroll := false
	if draggable && max_scroll > 0 && gui_pointer_enabled(ctx) {
		if ctx.input.mouse_pressed && gui_contains(viewport, ctx.input.mouse_pos) {
			ctx.scroll_drag_id = scroll_id
			ctx.scroll_drag_start_pos = ctx.input.mouse_pos
			ctx.scroll_drag_start_scroll = scroll^
			ctx.scroll_drag_consumed = false
		}
		if ctx.scroll_drag_id == scroll_id && (ctx.input.mouse_down || ctx.scroll_drag_release_pending) {
			delta_y := ctx.input.mouse_pos.y - ctx.scroll_drag_start_pos.y
			threshold := max(ctx.style.spacing_1 * 1.5, f32(6))
			if ctx.scroll_drag_consumed || abs(delta_y) >= threshold {
				ctx.scroll_drag_consumed = true
				scroll^ = min(max(ctx.scroll_drag_start_scroll - delta_y, 0), max_scroll)
				direct_scroll = true
				ctx.active = GUI_ID_NONE
			}
			if ctx.scroll_drag_release_pending {
				ctx.scroll_drag_id = GUI_ID_NONE
				ctx.scroll_drag_consumed = false
				ctx.scroll_drag_release_pending = false
			}
		}
	}
	visible_scroll := scroll^
	if ctx.input.delta_time > 0 {
		slot := gui_animation_slot(ctx, scroll_id)
		if slot != nil {
			if direct_scroll {
				slot.value = scroll^
			} else if slot.last_frame == 0 {
				slot.value = min(max(previous_scroll, 0), max_scroll)
			}
			if !direct_scroll {
				slot.value = gui_animate_towards(slot.value, scroll^, 18, ctx.input.delta_time)
			}
			slot.value = min(max(slot.value, 0), max_scroll)
			slot.last_frame = ctx.frame_index
			visible_scroll = slot.value
		}
	}

	focus_record := -1
	if ctx.scroll_focus_record_count < MAX_GUI_SCROLL_FOCUS_RECORDS {
		focus_record = ctx.scroll_focus_record_count
		parent := -1
		if ctx.scroll_depth > 0 {
			parent = ctx.scroll_stack[ctx.scroll_depth - 1].focus_record
		}
		ctx.scroll_focus_records[focus_record] = {
			viewport = viewport,
			scroll = visible_scroll,
			max_scroll = max_scroll,
			target_scroll = scroll,
			animation_id = scroll_id,
			parent = parent,
		}
		ctx.scroll_focus_record_count += 1
	}

	if ctx.scroll_depth < MAX_GUI_SCROLL_DEPTH {
		ctx.scroll_stack[ctx.scroll_depth] = {
			viewport = viewport,
			content_height = content_height,
			scroll = visible_scroll,
			previous_scroll = previous_scroll,
			target_scroll = scroll,
			wheel_consumed = consumed_wheel,
			focus_record = focus_record,
		}
		ctx.scroll_depth += 1
	}

	gui_scissor_begin(ctx, viewport)
	gui_input_clip_begin(ctx, viewport)
	content_w := gui_scrollbar_content_width(ctx, viewport, content_height)
	content := Rect{viewport.x, viewport.y - visible_scroll, content_w, max(content_height, viewport.h)}
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
	item_focusable := enabled && group.enabled
	item_visible := item_focusable && gui_spatial_bounds_visible(ctx, bounds)
	scroll_owner := -1
	if ctx.scroll_depth > 0 {
		scroll_owner = ctx.scroll_stack[ctx.scroll_depth - 1].focus_record
	}
	ctx.spatial_items[ctx.spatial_item_count] = {
		id = id,
		bounds = bounds,
		group = group.id,
		order = ctx.focus_order_next,
		enabled = item_visible,
		focusable = item_focusable,
		visible = item_visible,
		scroll_owner = scroll_owner,
	}
	ctx.spatial_item_count += 1
	ctx.focus_order_next += 1
}

gui_find_spatial_item :: proc(ctx: ^Gui_Context, id: Gui_Id) -> (Gui_Spatial_Item, bool) {
	for i in 0 ..< ctx.spatial_item_count {
		item := ctx.spatial_items[i]
		if item.id == id && item.focusable {
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
		if !item.focusable || item.id == current.id || item.group != current.group {
			continue
		}
		// Clipping alone must not make a long scroll panel unreachable, but an
		// arbitrary scissor remains a hard navigation boundary.
		if !item.visible && (current.scroll_owner < 0 || item.scroll_owner != current.scroll_owner) {
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

gui_tab_item_candidate :: proc(item: Gui_Spatial_Item, group: Gui_Id, scoped: bool) -> bool {
	if !item.focusable || (!item.visible && item.scroll_owner < 0) {
		return false
	}
	return !scoped || item.group == group
}

gui_apply_tab_navigation :: proc(ctx: ^Gui_Context) {
	if ctx.focus_moved || (!ctx.input.focus_next && !ctx.input.focus_prev) || ctx.focus_edit_id != GUI_ID_NONE || ctx.open_panel != GUI_ID_NONE {
		return
	}

	current, has_current := gui_find_spatial_item(ctx, ctx.focused)
	group := GUI_ID_NONE
	scoped := has_current
	if ctx.focus_scope_active {
		group = ctx.focus_scope
		scoped = true
		if !has_current || current.group != group {
			has_current = false
		}
	} else if has_current {
		group = current.group
	}

	first := Gui_Spatial_Item{}
	last := Gui_Spatial_Item{}
	next := Gui_Spatial_Item{}
	previous := Gui_Spatial_Item{}
	has_first, has_last, has_next, has_previous: bool
	for i in 0 ..< ctx.spatial_item_count {
		item := ctx.spatial_items[i]
		if !gui_tab_item_candidate(item, group, scoped) {
			continue
		}
		if !has_first || item.order < first.order {
			first = item
			has_first = true
		}
		if !has_last || item.order > last.order {
			last = item
			has_last = true
		}
		if has_current && item.order > current.order && (!has_next || item.order < next.order) {
			next = item
			has_next = true
		}
		if has_current && item.order < current.order && (!has_previous || item.order > previous.order) {
			previous = item
			has_previous = true
		}
	}

	target := GUI_ID_NONE
	if ctx.input.focus_prev {
		if has_previous {
			target = previous.id
		} else if has_last {
			target = last.id
		}
	} else if has_next {
		target = next.id
	} else if has_first {
		target = first.id
	}
	if target != GUI_ID_NONE {
		ctx.focused = target
		ctx.focus_moved = true
	}
}

gui_enforce_focus_scope :: proc(ctx: ^Gui_Context) {
	if !ctx.focus_scope_active {
		return
	}
	current, ok := gui_find_spatial_item(ctx, ctx.focused)
	if ok && gui_tab_item_candidate(current, ctx.focus_scope, true) {
		return
	}
	for i in 0 ..< ctx.spatial_item_count {
		item := ctx.spatial_items[i]
		if gui_tab_item_candidate(item, ctx.focus_scope, true) {
			ctx.focused = item.id
			ctx.focus_moved = true
			return
		}
	}
}

gui_reveal_focused_item :: proc(ctx: ^Gui_Context) {
	if ctx.focused == GUI_ID_NONE {
		return
	}
	item, ok := gui_find_spatial_item(ctx, ctx.focused)
	if !ok || item.scroll_owner < 0 {
		return
	}

	reveal_bounds := item.bounds
	owner := item.scroll_owner
	for depth := 0; owner >= 0 && owner < ctx.scroll_focus_record_count && depth < MAX_GUI_SCROLL_DEPTH; depth += 1 {
		record := &ctx.scroll_focus_records[owner]
		padding := min(max(ctx.style.border_width * 3, f32(4)), record.viewport.h * 0.2)
		top := record.viewport.y + padding
		bottom := record.viewport.y + record.viewport.h - padding
		delta := f32(0)
		if reveal_bounds.h > max(bottom - top, 0) {
			delta = reveal_bounds.y - top
		} else if reveal_bounds.y < top {
			delta = reveal_bounds.y - top
		} else if reveal_bounds.y + reveal_bounds.h > bottom {
			delta = reveal_bounds.y + reveal_bounds.h - bottom
		}

		if delta != 0 && record.target_scroll != nil {
			target := min(max(record.scroll + delta, 0), record.max_scroll)
			record.target_scroll^ = target
			record.scroll = target
			if ctx.input.delta_time > 0 {
				slot := gui_animation_slot(ctx, record.animation_id)
				if slot != nil {
					slot.value = target
					slot.last_frame = ctx.frame_index
				}
			}
		}

		reveal_bounds = record.viewport
		owner = record.parent
	}
}

gui_control :: proc(ctx: ^Gui_Context, id: Gui_Id, bounds: Rect, enabled := true, focusable := true, pointer_focus := true) -> Gui_Control {
	if enabled && focusable {
		gui_register_focusable(ctx, id, bounds)
	}

	hovered := enabled && gui_mouse_contains(ctx, bounds)
	if hovered {
		ctx.hot = id
		if ctx.input.mouse_pressed {
			ctx.active = id
			if focusable && pointer_focus {
				ctx.focused = id
			}
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
		activated = focused && gui_accept_pressed(ctx),
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

gui_accept_pressed :: proc(ctx: ^Gui_Context) -> bool {
	return ctx.input.accept_pressed || (ctx.input.accept && !ctx.previous_input.accept)
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

gui_controller_edit_clear_snapshot :: proc(ctx: ^Gui_Context, id: Gui_Id) {
	if ctx.controller_snapshot_id == id {
		ctx.controller_snapshot_id = GUI_ID_NONE
		ctx.controller_snapshot_kind = .None
	}
	if ctx.controller_cancel_id == id {
		ctx.controller_cancel_id = GUI_ID_NONE
	}
}

gui_controller_edit_f32 :: proc(ctx: ^Gui_Context, id: Gui_Id, value: ^f32) {
	if ctx.controller_cancel_id == id && ctx.controller_snapshot_id == id && ctx.controller_snapshot_kind == .Float {
		value^ = ctx.controller_snapshot_f32
		gui_controller_edit_clear_snapshot(ctx, id)
		return
	}
	if ctx.focus_edit_id == id && ctx.controller_snapshot_id != id {
		ctx.controller_snapshot_id = id
		ctx.controller_snapshot_kind = .Float
		ctx.controller_snapshot_f32 = value^
	}
}

gui_controller_edit_int :: proc(ctx: ^Gui_Context, id: Gui_Id, value: ^int) {
	if ctx.controller_cancel_id == id && ctx.controller_snapshot_id == id && ctx.controller_snapshot_kind == .Integer {
		value^ = ctx.controller_snapshot_int
		gui_controller_edit_clear_snapshot(ctx, id)
		return
	}
	if ctx.focus_edit_id == id && ctx.controller_snapshot_id != id {
		ctx.controller_snapshot_id = id
		ctx.controller_snapshot_kind = .Integer
		ctx.controller_snapshot_int = value^
	}
}

gui_controller_edit_bool :: proc(ctx: ^Gui_Context, id: Gui_Id, value: ^bool) {
	if ctx.controller_cancel_id == id && ctx.controller_snapshot_id == id && ctx.controller_snapshot_kind == .Boolean {
		value^ = ctx.controller_snapshot_bool
		gui_controller_edit_clear_snapshot(ctx, id)
		return
	}
	if ctx.focus_edit_id == id && ctx.controller_snapshot_id != id {
		ctx.controller_snapshot_id = id
		ctx.controller_snapshot_kind = .Boolean
		ctx.controller_snapshot_bool = value^
	}
}

gui_controller_edit_text :: proc(ctx: ^Gui_Context, id: Gui_Id, buffer: []u8, length: ^int) {
	if ctx.controller_cancel_id == id && ctx.controller_snapshot_id == id && ctx.controller_snapshot_kind == .Text {
		length^ = min(ctx.controller_snapshot_text_len, len(buffer))
		for i in 0 ..< length^ {
			buffer[i] = ctx.controller_snapshot_text[i]
		}
		if length^ < len(buffer) {
			buffer[length^] = 0
		}
		gui_controller_edit_clear_snapshot(ctx, id)
		return
	}
	if ctx.focus_edit_id == id && ctx.controller_snapshot_id != id {
		ctx.controller_snapshot_id = id
		ctx.controller_snapshot_kind = .Text
		ctx.controller_snapshot_text_len = min(length^, min(len(buffer), len(ctx.controller_snapshot_text)))
		for i in 0 ..< ctx.controller_snapshot_text_len {
			ctx.controller_snapshot_text[i] = buffer[i]
		}
	}
}

gui_controller_edit_vec2 :: proc(ctx: ^Gui_Context, id: Gui_Id, value: ^Vec2) {
	if ctx.controller_cancel_id == id && ctx.controller_snapshot_id == id && ctx.controller_snapshot_kind == .Vec2 {
		value^ = ctx.controller_snapshot_vec2
		gui_controller_edit_clear_snapshot(ctx, id)
		return
	}
	if ctx.focus_edit_id == id && ctx.controller_snapshot_id != id {
		ctx.controller_snapshot_id = id
		ctx.controller_snapshot_kind = .Vec2
		ctx.controller_snapshot_vec2 = value^
	}
}

gui_controller_edit_hsv :: proc(ctx: ^Gui_Context, id: Gui_Id, value: ^Hsv_Color) {
	if ctx.controller_cancel_id == id && ctx.controller_snapshot_id == id && ctx.controller_snapshot_kind == .Hsv {
		value^ = ctx.controller_snapshot_hsv
		gui_controller_edit_clear_snapshot(ctx, id)
		return
	}
	if ctx.focus_edit_id == id && ctx.controller_snapshot_id != id {
		ctx.controller_snapshot_id = id
		ctx.controller_snapshot_kind = .Hsv
		ctx.controller_snapshot_hsv = value^
	}
}

gui_update_focus_edit :: proc(ctx: ^Gui_Context, id: Gui_Id, focused: bool) -> bool {
	if !focused {
		if ctx.controller_armed_id == id {
			ctx.controller_armed_id = GUI_ID_NONE
		}
		gui_controller_edit_clear_snapshot(ctx, id)
		gui_focus_edit_end(ctx, id)
		return false
	}
	if ctx.controller_explicit_activation {
		if ctx.focus_edit_id == id {
			if gui_accept_pressed(ctx) || ctx.input.back {
				if ctx.input.back {
					ctx.controller_cancel_id = id
				} else {
					gui_controller_edit_clear_snapshot(ctx, id)
				}
				gui_focus_edit_end(ctx, id)
				ctx.controller_armed_id = GUI_ID_NONE
				return false
			}
			ctx.focus_edit_seen = true
			return true
		}
		if gui_accept_pressed(ctx) {
			gui_focus_edit_begin(ctx, id)
			ctx.controller_armed_id = id
			ctx.focus_edit_seen = true
			return true
		}
		return false
	}
	if ctx.focus_edit_id == id {
		if gui_accept_pressed(ctx) || ctx.input.back {
			if ctx.input.back {
				ctx.controller_cancel_id = id
			} else {
				gui_controller_edit_clear_snapshot(ctx, id)
			}
			gui_focus_edit_end(ctx, id)
			return false
		}
		ctx.focus_edit_seen = true
		return true
	}
	if gui_accept_pressed(ctx) || ctx.input.key_space {
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
}

gui_button_behavior :: proc(ctx: ^Gui_Context, id: Gui_Id, bounds: Rect, enabled: bool) -> bool {
	control := gui_control(ctx, id, bounds, enabled)
	// Buttons, toggles, checkboxes, and radio choices are immediate actions.
	// Explicit engagement is reserved for controls with an editable value or
	// nested interaction mode (sliders, selectors, text fields, canvases).
	if ctx.controller_explicit_activation && control.focused && gui_accept_pressed(ctx) {
		return true
	}
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
	if ctx.input.back {
		if ctx.number_edit_snapshot_id == id {
			value^ = ctx.number_edit_snapshot_value
		}
		ctx.number_edit_snapshot_id = GUI_ID_NONE
		ctx.text_edit_id = GUI_ID_NONE
		ctx.text_edit_len = 0
		return false
	}
	if ctx.input.accept {
		ctx.number_edit_snapshot_id = GUI_ID_NONE
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
	if ctx.number_edit_snapshot_id != id {
		ctx.number_edit_snapshot_id = id
		ctx.number_edit_snapshot_value = value
	}
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
