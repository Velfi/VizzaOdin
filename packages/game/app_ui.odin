package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"
import "core:math"

App_Mode :: enum {
	Main_Menu,
	Slime_Mold,
	Gray_Scott,
	Particle_Life,
	Flow_Field,
	Pellets,
	Gradient_Editor,
	Voronoi_CA,
	Moire,
	Vectors,
	Primordial,
	Options,
	How_To_Play,
	Theme_Preview,
}

SIMULATION_BAR_HEIGHT :: f32(60)
SIMULATION_BAR_BASE_ROW_HEIGHT :: f32(44)
MAIN_MENU_PREVIEW_SLOT_CAP :: 16
MAIN_MENU_TEXT_BUTTON_SCALE_MULTIPLIER :: f32(2.5)
MAIN_MENU_TEXT_BUTTON_FOCUS_BORDER_WIDTH :: f32(5)
MAIN_MENU_SIM_BUTTON_GRADIENT_MIDPOINT :: f32(0.66)
MAIN_MENU_DISPLAY_FONT_BASELINE_RATIO :: f32(0.78)

Main_Menu_Preview_Slot :: struct {
	mode: App_Mode,
	rect: uifw.Rect,
	clip_rect: uifw.Rect,
	fallback_color: uifw.Color,
}

Simulation_Shell_State :: struct {
	show_ui: bool,
	controls_visible: bool,
	idle_seconds: f32,
	mouse_pressed: bool,
	mouse_button: u32,
}

Video_Recording_Ui_State :: enum {
	Idle,
	Choosing_Path,
	Restoring_Fullscreen,
	Recording,
	Failed,
}

App_Ui_State :: struct {
	mode: App_Mode,
	previous_mode: App_Mode,
	settings: App_Settings,
	last_stats: Render_To_Ui_Message,
	menu_position_index: int,
	texture_filtering_index: int,
	settings_dirty: bool,
	simulation_shell: Simulation_Shell_State,
	video_recording_state: Video_Recording_Ui_State,
	video_recording_status: [MAX_ERROR_TEXT]u8,
	main_menu_selected: int,
	main_menu_scroll: f32,
	main_menu_live_preview_visible: bool,
	main_menu_live_preview_mode: App_Mode,
	main_menu_live_preview_rect: uifw.Rect,
	main_menu_preview_slots: [MAIN_MENU_PREVIEW_SLOT_CAP]Main_Menu_Preview_Slot,
	main_menu_preview_slot_count: int,
	main_menu_palette_randomize_requested: bool,
	main_menu_focus_navigation_active: bool,
	options_scroll: f32,
	gray_scott_scroll: f32,
	particle_life_scroll: f32,
	gradient_editor_scroll: f32,
	slime_mold: Remaining_Sim_State,
	flow_field: Remaining_Sim_State,
	pellets: Remaining_Sim_State,
	voronoi_ca: Remaining_Sim_State,
	moire: Remaining_Sim_State,
	vectors: Remaining_Sim_State,
	primordial: Remaining_Sim_State,
	theme_preview: bool,
	preview_hsv: uifw.Hsv_Color,
	preview_area: uifw.Vec2,
	preview_checkbox: bool,
	preview_switch: bool,
	preview_radio_index: int,
	preview_combo_index: int,
	preview_combo_query: [64]u8,
	preview_progress: f32,
	color_scheme_editor: Color_Scheme_Editor_State,
}

APP_SIMULATION_NAMES := [?]string {
	"Slime Mold",
	"Gray-Scott",
	"Particle Life",
	"Flow Field",
	"Pellets",
	"Gradient Editor",
	"Voronoi CA",
	"Moire",
	"Vectors",
	"Primordial",
}

APP_SIMULATION_DESCRIPTIONS := [?]string {
	"Agent collaboration",
	"Reaction-diffusion",
	"Multi-species particles",
	"Vector-field trails",
	"2D particle physics",
	"Color gradient tool",
	"Cellular automata",
	"Interference patterns",
	"Vector field view",
	"Emergent particle motion",
}

APP_SIMULATION_LONG_DESCRIPTIONS := [?]string {
	"Autonomous walkers sense, turn, and leave evaporating trails that settle into branching transport networks.",
	"Two chemicals diffuse and react into cellular islands, waves, and turbulent spots.",
	"Colored particle species attract and repel each other to form living clusters and orbiting structures.",
	"Particles trace a changing vector field, revealing flow direction through layered motion trails.",
	"Lightweight 2D particle physics with density, collisions, and image-like emergent texture.",
	"Build and inspect color ramps used by the simulations and their post-processing passes.",
	"A cellular automata playground driven by nearest-neighbor regions and local state transitions.",
	"Interference patterns from layered wave fields, offsets, and procedural image sampling.",
	"Vector-field inspection for direction, magnitude, and dense line rendering.",
	"Particle motion organized by local density, soft attraction, and primordial clustering.",
}

APP_SIMULATION_CATEGORIES := [?]string {
	"agents",
	"reaction",
	"particles",
	"field",
	"physics",
	"tool",
	"cellular",
	"wave",
	"field",
	"particles",
}

APP_SIMULATION_TAGS := [?][3]string {
	{"agents", "trails", "growth"},
	{"reaction", "diffusion", "patterns"},
	{"particles", "species", "motion"},
	{"field", "trails", "vectors"},
	{"particles", "physics", "density"},
	{"tool", "color", "gradient"},
	{"cellular", "voronoi", "state"},
	{"wave", "moire", "image"},
	{"field", "vectors", "analysis"},
	{"particles", "density", "motion"},
}

MENU_POSITION_OPTIONS := [?]string{"left", "middle", "right"}
TEXTURE_FILTERING_OPTIONS := [?]string{"Linear", "Nearest", "Lanczos"}

Menu_Theme :: struct {
	panel: uifw.Color,
	panel_top: uifw.Color,
	surface: uifw.Color,
	surface_hot: uifw.Color,
	surface_selected: uifw.Color,
	preview_surface: uifw.Color,
	footer_surface: uifw.Color,
	border: uifw.Color,
	border_hot: uifw.Color,
	accent: uifw.Color,
	accent_soft: uifw.Color,
	text: uifw.Color,
	text_muted: uifw.Color,
	text_dim: uifw.Color,
	chip: uifw.Color,
	chip_border: uifw.Color,
	danger: uifw.Color,
	shadow: uifw.Color,
	panel_padding: f32,
	inner_gap: f32,
	item_gap: f32,
	small_gap: f32,
	footer_height: f32,
	footer_gap: f32,
	row_height: f32,
	thumbnail_width: f32,
	thumbnail_height: f32,
	chip_height: f32,
	chip_gap: f32,
	detail_min_width: f32,
	detail_gap: f32,
	radius: f32,
	card_radius: f32,
	border_width: f32,
	start_width: f32,
}

app_ui_init :: proc(ui: ^App_Ui_State, settings: App_Settings, theme_preview := false) {
	ui^ = {}
	ui.mode = .Main_Menu
	ui.previous_mode = .Main_Menu
	ui.settings = settings
	ui.theme_preview = theme_preview
	ui.simulation_shell = {show_ui = true, controls_visible = true}
	ui.main_menu_selected = 1
	ui.menu_position_index = option_index(settings.menu_position, MENU_POSITION_OPTIONS[:], 1)
	ui.texture_filtering_index = option_index(settings.texture_filtering, TEXTURE_FILTERING_OPTIONS[:], 0)
	ui.preview_hsv = {h = 0.56, s = 0.78, v = 0.92, a = 1}
	ui.preview_area = {0.35, 0.68}
	ui.preview_checkbox = true
	ui.preview_switch = true
	ui.preview_radio_index = 1
	ui.preview_combo_index = 2
	ui.preview_progress = 0.68
	color_scheme_editor_init(&ui.color_scheme_editor)
	remaining_sim_init(&ui.slime_mold)
	remaining_sim_init(&ui.flow_field)
	remaining_sim_init(&ui.pellets)
	remaining_sim_init(&ui.voronoi_ca)
	remaining_sim_init(&ui.moire)
	remaining_sim_init(&ui.vectors)
	remaining_sim_init(&ui.primordial)
	if theme_preview {
		ui.mode = .Theme_Preview
		ui.previous_mode = .Theme_Preview
	}
}

app_ui_draw :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, worker: ^Render_Worker_State) {
	app_ui_handle_controller_disconnect(ui, gui, sim, particle_life)
	#partial switch ui.mode {
	case .Main_Menu:
		app_ui_draw_main_menu(ui, gui, vk_ctx, worker)
	case .Options:
		app_ui_draw_options(ui, gui, vk_ctx, worker)
	case .How_To_Play:
		app_ui_draw_how_to_play(ui, gui)
	case .Slime_Mold:
		app_ui_draw_remaining_sim(ui, gui, .Slime_Mold, &ui.slime_mold, vk_ctx, worker)
	case .Gray_Scott:
	app_ui_draw_gray_scott(ui, gui, sim, vk_ctx, worker)
	case .Particle_Life:
		app_ui_draw_particle_life(ui, gui, particle_life, vk_ctx, worker)
	case .Flow_Field:
		app_ui_draw_remaining_sim(ui, gui, .Flow_Field, &ui.flow_field, vk_ctx, worker)
	case .Pellets:
		app_ui_draw_remaining_sim(ui, gui, .Pellets, &ui.pellets, vk_ctx, worker)
	case .Gradient_Editor:
		app_ui_draw_gradient_editor(ui, gui, vk_ctx)
	case .Voronoi_CA:
		app_ui_draw_remaining_sim(ui, gui, .Voronoi_CA, &ui.voronoi_ca, vk_ctx, worker)
	case .Moire:
		app_ui_draw_remaining_sim(ui, gui, .Moire, &ui.moire, vk_ctx, worker)
	case .Vectors:
		app_ui_draw_remaining_sim(ui, gui, .Vectors, &ui.vectors, vk_ctx, worker)
	case .Primordial:
		app_ui_draw_remaining_sim(ui, gui, .Primordial, &ui.primordial, vk_ctx, worker)
	case .Theme_Preview:
		app_ui_draw_theme_preview(ui, gui, vk_ctx)
	}
	app_ui_draw_virtual_cursor(gui)
}

app_ui_handle_controller_disconnect :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation) {
	if !gui.input.controller_disconnected || gui.input.active_device != .Controller || !app_ui_mode_is_simulation(ui.mode) {
		return
	}
	ui.simulation_shell.show_ui = true
	ui.simulation_shell.controls_visible = true
	ui.simulation_shell.idle_seconds = 0
	#partial switch ui.mode {
	case .Gray_Scott:
		if sim != nil {sim.settings.paused = true}
	case .Particle_Life:
		if particle_life != nil {particle_life.settings.paused = true}
	case .Slime_Mold:
		ui.slime_mold.paused = true
	case .Flow_Field:
		ui.flow_field.paused = true
	case .Pellets:
		ui.pellets.paused = true
	case .Voronoi_CA:
		ui.voronoi_ca.paused = true
	case .Moire:
		ui.moire.paused = true
	case .Vectors:
		ui.vectors.paused = true
	case .Primordial:
		ui.primordial.paused = true
	case:
	}
}

app_ui_draw_virtual_cursor :: proc(gui: ^uifw.Gui_Context) {
	if gui.input.active_device != .Controller {
		return
	}
	p := gui.input.mouse_pos
	size := max(gui.style.row_height * 0.26, 10)
	shadow := uifw.Color{0, 0, 0, 0.60}
	fill := gui.style.text
	accent := gui.style.accent
	uifw.gui_line(gui, {p.x - size + 2, p.y + 2}, {p.x + size + 2, p.y + 2}, shadow, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, {p.x + 2, p.y - size + 2}, {p.x + 2, p.y + size + 2}, shadow, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, {p.x - size, p.y}, {p.x + size, p.y}, fill, max(gui.style.border_width * 2, 2))
	uifw.gui_line(gui, {p.x, p.y - size}, {p.x, p.y + size}, fill, max(gui.style.border_width * 2, 2))
	uifw.gui_ellipse(gui, {p.x - size * 0.26, p.y - size * 0.26, size * 0.52, size * 0.52}, accent)
}

app_ui_draw_main_menu :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, vk_ctx: ^engine.Vk_Context, worker: ^Render_Worker_State) {
	width := f32(vk_ctx.swapchain_extent.width)
	height := f32(vk_ctx.swapchain_extent.height)
	theme := app_ui_menu_theme(gui, width, height)
	ui.main_menu_live_preview_visible = false
	ui.main_menu_preview_slot_count = 0
	if app_ui_main_menu_pointer_interaction(gui) {
		ui.main_menu_focus_navigation_active = false
	}
	if app_ui_main_menu_focus_navigation_input(gui) {
		ui.main_menu_focus_navigation_active = true
	}

	app_ui_draw_main_menu_backdrop(gui, {0, 0, width, height}, theme)

	ui.main_menu_selected = max(min(ui.main_menu_selected, len(APP_SIMULATION_NAMES) - 1), 0)
	if gui.input.accept && gui.focused == uifw.GUI_ID_NONE {
		app_ui_navigate(ui, app_ui_mode_for_simulation_index(ui.main_menu_selected))
	}

	margin_x := max(width * 0.055, gui.style.spacing_4)
	title_y := max(height * 0.070, gui.style.spacing_4)
	title_w := max(width - margin_x * 2, 1)
	title_scale := max((height * 0.31) / f32(16), gui.style.display_text_scale * 1.2)
	title_text_h := uifw.GUI_FONT_LOGICAL_HEIGHT * title_scale
	title_h := min(max(max(height * 0.20, gui.style.display_line_height), title_text_h), height - title_y)
	title := uifw.Rect{margin_x, title_y, title_w, title_h}
	title_label := "VIZZA"
	title_bytes := transmute([]u8)title_label
	title_fallback_advance := gui.style.char_width * title_scale / max(gui.style.text_scale, 0.001)
	title_text_w := uifw.gui_font_text_width(.Display, title_bytes, title_scale, title_fallback_advance)
	title_click := uifw.Rect{title.x, title.y, min(title_text_w, title.w), title.h}
	title_id := uifw.gui_make_id(gui, "main_menu_logo")
	title_control := uifw.gui_control(gui, title_id, title_click, true)
	if title_control.activated || (title_control.hovered && gui.active == title_id && gui.input.mouse_released) {
		ui.main_menu_palette_randomize_requested = true
	}
	uifw.gui_text_aligned_font(gui, title, title_label, theme.text, .Left, .Display, title_scale)
	byline_scale := gui.style.heading_text_scale * 1.45
	byline_text_h := uifw.GUI_FONT_LOGICAL_HEIGHT * byline_scale
	title_baseline_y := title.y + title_text_h * MAIN_MENU_DISPLAY_FONT_BASELINE_RATIO
	byline_baseline_offset := byline_text_h * MAIN_MENU_DISPLAY_FONT_BASELINE_RATIO
	byline := uifw.Rect{margin_x + title_w * 0.68, title_baseline_y - byline_baseline_offset, title_w * 0.30, byline_text_h}
	uifw.gui_text_aligned_font(gui, byline, "By Zelda", theme.text, .Left, .Display, byline_scale)

	side_w := min(max(width * 0.23, f32(330)), f32(560))
	bottom_margin := max(height * 0.050, gui.style.spacing_4)
	right_margin := max(width * 0.050, gui.style.spacing_4)
	actions_x := f32(0)
	action_gap := f32(0)
	button_w := f32(0)
	button_h := f32(0)
	actions_h := f32(0)
	actions_y := f32(0)
	available_list_w := max(width - margin_x * 2, 1)
	if width >= 920 {
		action_gap = max(theme.item_gap * 0.12, theme.footer_height * 0.07)
		options_size := app_ui_main_menu_text_button_size(gui, "OPTIONS", theme)
		quit_size := app_ui_main_menu_text_button_size(gui, "QUIT", theme)
		button_w = max(side_w, max(options_size.x, quit_size.x))
		button_h = max(theme.footer_height, max(options_size.y, quit_size.y))
		actions_h = button_h * 2 + action_gap
		actions_x = max(width - right_margin - button_w, margin_x)
		actions_y = max(height - bottom_margin - actions_h, 0)
		available_list_w = max(actions_x - theme.detail_gap - margin_x, 1)
	}
	list_w := min(max(width * 0.60, f32(680)), available_list_w)
	if width < 920 {
		list_w = max(width - margin_x * 2, 1)
	}
	list_y := max(title.y + title.h + theme.inner_gap, height * 0.39)
	list_bottom := height - bottom_margin
	list_h := max(list_bottom - list_y, theme.row_height * 2.25)
	list := uifw.Rect{margin_x, list_y, list_w, list_h}
	app_ui_draw_main_menu_list(ui, gui, list, theme)

	if width >= 920 {
		actions := uifw.Rect{actions_x, actions_y, button_w, actions_h}
		if app_ui_draw_main_menu_text_button(gui, {actions.x, actions.y, button_w, button_h}, "options", "OPTIONS", theme) {
			app_ui_navigate(ui, .Options)
		}
		if app_ui_draw_main_menu_text_button(gui, {actions.x, actions.y + button_h + action_gap, button_w, button_h}, "quit", "QUIT", theme) {
			msg: Render_To_Ui_Message
			msg.kind = .Request_Close
			_ = engine.queue_try_push(worker.render_to_ui, msg)
		}
	} else {
		action_gap := max(theme.item_gap * 1.4, theme.footer_height * 0.35)
		actions := uifw.Rect{list.x, max(list.y + list.h - theme.footer_height * 2 - action_gap, list.y), list.w, theme.footer_height * 2 + action_gap}
		button_w := min(actions.w, max(gui.style.body_char_width * 16, 220))
		button_x := actions.x + max((actions.w - button_w) * 0.5, 0)
		if app_ui_draw_main_menu_text_button(gui, {button_x, actions.y, button_w, theme.footer_height}, "options", "OPTIONS", theme) {
			app_ui_navigate(ui, .Options)
		}
		if app_ui_draw_main_menu_text_button(gui, {button_x, actions.y + theme.footer_height + action_gap, button_w, theme.footer_height}, "quit", "QUIT", theme) {
			msg: Render_To_Ui_Message
			msg.kind = .Request_Close
			_ = engine.queue_try_push(worker.render_to_ui, msg)
		}
	}
}

app_ui_main_menu_pointer_interaction :: proc(gui: ^uifw.Gui_Context) -> bool {
	return uifw.gui_pointer_enabled(gui) &&
	       (gui.input.mouse_moved ||
	        gui.input.mouse_pressed ||
	        gui.input.mouse_released ||
	        gui.input.mouse_down ||
	        gui.input.wheel_delta != 0)
}

app_ui_main_menu_focus_navigation_input :: proc(gui: ^uifw.Gui_Context) -> bool {
	return gui.input.nav_pressed_x != 0 ||
	       gui.input.nav_pressed_y != 0 ||
	       gui.input.focus_next ||
	       gui.input.focus_prev
}

app_ui_main_menu_text_button_size :: proc(gui: ^uifw.Gui_Context, label: string, theme: Menu_Theme) -> uifw.Vec2 {
	text_scale := gui.style.heading_text_scale * MAIN_MENU_TEXT_BUTTON_SCALE_MULTIPLIER
	bytes := transmute([]u8)label
	fallback_advance := gui.style.char_width * text_scale / max(gui.style.text_scale, 0.001)
	text_w := uifw.gui_font_text_width(.SimStart, bytes, text_scale, fallback_advance)
	text_h := uifw.GUI_FONT_LOGICAL_HEIGHT * text_scale
	padding_x := max(theme.small_gap * 2.0, text_h * 0.20)
	padding_y := max(theme.small_gap * 1.4, text_h * 0.14)
	return {text_w + padding_x * 2, text_h + padding_y * 2}
}

app_ui_fit_sim_start_text_scale :: proc(gui: ^uifw.Gui_Context, label: string, desired_scale, max_width: f32) -> f32 {
	if max_width <= 1 || desired_scale <= 0 || len(label) == 0 {
		return desired_scale
	}
	bytes := transmute([]u8)label
	fallback_advance := gui.style.char_width * desired_scale / max(gui.style.text_scale, 0.001)
	text_w := uifw.gui_font_text_width(.SimStart, bytes, desired_scale, fallback_advance)
	if text_w <= max_width || text_w <= 0 {
		return desired_scale
	}
	return desired_scale * max_width / text_w
}

app_ui_menu_theme :: proc(gui: ^uifw.Gui_Context, width, height: f32) -> Menu_Theme {
	scale := min(max(min(width / 1920, height / 1080), 0.72), 1.35)
	return {
		panel = {0.30, 0.000, 0.000, 1.0},
		panel_top = {1.00, 0.000, 0.000, 1.0},
		surface = {0.020, 0.018, 0.018, 0.82},
		surface_hot = {0.070, 0.028, 0.025, 0.88},
		surface_selected = {0.16, 0.030, 0.026, 0.90},
		preview_surface = {0.005, 0.005, 0.006, 1.0},
		footer_surface = {0.030, 0.012, 0.010, 0.72},
		border = {0.00, 0.00, 0.00, 0.56},
		border_hot = {1.00, 1.00, 1.00, 0.50},
		accent = {1.00, 1.00, 1.00, 1.0},
		accent_soft = {1.00, 1.00, 1.00, 0.18},
		text = {1.00, 1.00, 1.00, 1.0},
		text_muted = {0.90, 0.90, 0.90, 0.88},
		text_dim = {1.00, 1.00, 1.00, 0.68},
		chip = {0.0, 0.0, 0.0, 0.30},
		chip_border = {1.0, 1.0, 1.0, 0.20},
		danger = {0.90, 0.18, 0.16, 1.0},
		shadow = {0, 0, 0, 0.72},
		panel_padding = gui.style.spacing_4 * scale,
		inner_gap = max(gui.style.spacing_4 * 1.1 * scale, 18),
		item_gap = max(height * 0.032, gui.style.spacing_3 * 1.35 * scale),
		small_gap = max(gui.style.spacing_2 * scale, 6),
		footer_height = max(gui.style.row_height * 2.20 * scale, 88),
		footer_gap = gui.style.spacing_2 * scale,
		row_height = min(max(height * 0.205, gui.style.row_height * 3.6 * scale), height * 0.245),
		thumbnail_width = 0,
		thumbnail_height = 0,
		chip_height = 0,
		chip_gap = 0,
		detail_min_width = 0,
		detail_gap = max(gui.style.spacing_4 * 2.6 * scale, 36),
		radius = 0,
		card_radius = 0,
		border_width = 1,
		start_width = 0,
	}
}

app_ui_draw_main_menu_backdrop :: proc(gui: ^uifw.Gui_Context, bounds: uifw.Rect, theme: Menu_Theme) {
	_ = gui
	_ = bounds
	_ = theme
}

app_ui_draw_menu_chip :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, label: string, theme: Menu_Theme, emphasis: f32) {
	fill := uifw.gui_lerp_color(theme.chip, theme.accent_soft, emphasis)
	border := uifw.gui_lerp_color(theme.chip_border, theme.accent, emphasis * 0.45)
	uifw.gui_box(gui, rect, {
		fill = fill,
		border = border,
		radius = rect.h * 0.5,
		border_width = theme.border_width,
	})
	app_ui_draw_menu_centered_text(gui, rect, label, uifw.gui_lerp_color(theme.text_dim, theme.text_muted, emphasis))
}

app_ui_draw_menu_centered_text :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, label: string, color: uifw.Color) {
	text_w := uifw.gui_text_width(gui, label)
	pos := uifw.Vec2{
		rect.x + max((rect.w - text_w) * 0.5, 0),
		rect.y + max((rect.h - gui.style.body_text_height) * 0.5, 0),
	}
	uifw.gui_text_clipped(gui, rect, pos, label, color)
}

app_ui_draw_main_menu_button :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, key, label: string, theme: Menu_Theme, primary, danger: bool) -> bool {
	id := uifw.gui_make_id(gui, key)
	control := uifw.gui_control(gui, id, rect, true)
	hot_t := uifw.gui_animate_value(gui, uifw.gui_id_child(id, "hot"), (control.hovered || control.focused || gui.active == id) ? f32(1) : f32(0), 14)
	base := primary ? theme.accent_soft : theme.surface
	target := primary ? uifw.gui_lerp_color(theme.accent_soft, theme.accent, 0.55) : theme.surface_hot
	if danger {
		target = uifw.gui_lerp_color(theme.surface_hot, theme.danger, 0.22)
	}
	fill := uifw.gui_lerp_color(base, target, hot_t)
	border := uifw.gui_lerp_color(theme.border, theme.border_hot, hot_t)
	uifw.gui_box(gui, rect, {
		fill = fill,
		border = border,
		radius = theme.card_radius,
		border_width = theme.border_width,
		shadow_color = theme.shadow,
		shadow_offset = {0, theme.small_gap * 0.65},
		shadow_blur = theme.inner_gap,
	})
	if control.focused {
		uifw.gui_focus_ring(gui, rect)
	}
	uifw.gui_text_aligned_font(gui, rect, label, theme.text, .Center, .Body, gui.style.heading_text_scale)
	return control.activated || (control.hovered && gui.active == id && gui.input.mouse_released)
}

app_ui_draw_main_menu_text_button :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, key, label: string, theme: Menu_Theme) -> bool {
	text_scale := gui.style.heading_text_scale * MAIN_MENU_TEXT_BUTTON_SCALE_MULTIPLIER
	bytes := transmute([]u8)label
	fallback_advance := gui.style.char_width * text_scale / max(gui.style.text_scale, 0.001)
	text_w := uifw.gui_font_text_width(.SimStart, bytes, text_scale, fallback_advance)
	text_h := uifw.GUI_FONT_LOGICAL_HEIGHT * text_scale
	padding_x := max(theme.small_gap * 2.0, text_h * 0.20)
	padding_y := max(theme.small_gap * 1.4, text_h * 0.14)
	button_w := max(rect.w, text_w + padding_x * 2)
	button_h := max(rect.h, text_h + padding_y * 2)
	button := uifw.Rect{
		rect.x + (rect.w - button_w) * 0.5,
		rect.y + (rect.h - button_h) * 0.5,
		button_w,
		button_h,
	}
	text_rect := uifw.Rect{
		button.x + padding_x,
		button.y + max((button.h - text_h) * 0.5, 0),
		max(button.w - padding_x * 2, 1),
		text_h,
	}

	id := uifw.gui_make_id(gui, key)
	control := uifw.gui_control(gui, id, button, true)
	hot_t := uifw.gui_animate_value(gui, uifw.gui_id_child(id, "text_hot"), (control.hovered || control.focused || gui.active == id) ? f32(1) : f32(0), 16)
	if hot_t > 0.01 {
		stroke := uifw.gui_apply_opacity(theme.text, 0.95 * hot_t)
		uifw.gui_round_stroke(gui, button, theme.card_radius, stroke, MAIN_MENU_TEXT_BUTTON_FOCUS_BORDER_WIDTH)
	}
	uifw.gui_text_aligned_font(gui, text_rect, label, theme.text, .Left, .SimStart, text_scale)
	return control.activated || (control.hovered && gui.active == id && gui.input.mouse_released)
}

app_ui_draw_main_menu_footer_button :: proc(gui: ^uifw.Gui_Context, actions: uifw.Rect, index, count: int, key, label: string, theme: Menu_Theme, danger: bool) -> bool {
	gap_total := theme.item_gap * f32(max(count - 1, 0))
	cell_w := max((actions.w - gap_total - theme.small_gap * 2) / f32(max(count, 1)), 1)
	button_h := max(actions.h - theme.small_gap * 2, 1)
	rect := uifw.Rect{actions.x + theme.small_gap + f32(index) * (cell_w + theme.item_gap), actions.y + theme.small_gap, cell_w, button_h}
	return app_ui_draw_main_menu_button(gui, rect, key, label, theme, false, danger)
}

app_ui_draw_particle_life :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, worker: ^Render_Worker_State) {
	width := f32(vk_ctx.swapchain_extent.width)
	height := f32(vk_ctx.swapchain_extent.height)
	particle_life_draw_blob_overlay(sim, gui, width, height)
	if ui.simulation_shell.controls_visible {
		app_ui_draw_simulation_bar(ui, gui, .Particle_Life, nil, sim, nil, sim.settings.paused, !sim.gpu.ready, "Particle Life", vk_ctx, width, worker)
	}
	if ui.simulation_shell.show_ui {
		panel := app_ui_simulation_menu_panel(ui, gui, width, height)
		particle_life_draw_controls(sim, gui, panel, &ui.particle_life_scroll, worker, &ui.color_scheme_editor)
		_ = color_scheme_editor_draw_modal(gui, &ui.color_scheme_editor, &sim.settings.color_scheme)
	}
	app_ui_draw_loading_overlay(gui, width, height, !sim.gpu.ready)
}

app_ui_mode_for_simulation_index :: proc(index: int) -> App_Mode {
	switch index {
	case 0:
		return .Slime_Mold
	case 1:
		return .Gray_Scott
	case 2:
		return .Particle_Life
	case 3:
		return .Flow_Field
	case 4:
		return .Pellets
	case 5:
		return .Gradient_Editor
	case 6:
		return .Voronoi_CA
	case 7:
		return .Moire
	case 8:
		return .Vectors
	case 9:
		return .Primordial
	case:
		return .Main_Menu
	}
}

app_ui_draw_main_menu_content :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, bounds: uifw.Rect, theme: Menu_Theme) {
	app_ui_draw_main_menu_list(ui, gui, bounds, theme)
}

app_ui_draw_main_menu_list :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, bounds: uifw.Rect, theme: Menu_Theme) {
	content_h := f32(len(APP_SIMULATION_NAMES)) * theme.row_height + f32(max(len(APP_SIMULATION_NAMES) - 1, 0)) * theme.item_gap
	viewport := bounds
	uifw.gui_scroll_begin(gui, viewport, content_h, &ui.main_menu_scroll)
	uifw.gui_push_id(gui, "main_menu_simulations")
	if gui.focused == uifw.GUI_ID_NONE && gui.input.nav_pressed_y != 0 {
		gui.focused = uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", ui.main_menu_selected))
	}
	rows: [len(APP_SIMULATION_NAMES)]uifw.Rect
	hovered_index := -1
	for i in 0 ..< len(APP_SIMULATION_NAMES) {
		rows[i] = uifw.gui_next_rect(gui, height = theme.row_height)
		if uifw.gui_mouse_contains(gui, rows[i]) {
			hovered_index = i
		}
	}
	if hovered_index >= 0 && !ui.main_menu_focus_navigation_active {
		ui.main_menu_selected = hovered_index
		gui.focused = uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", hovered_index))
	}
	for i in 0 ..< len(APP_SIMULATION_NAMES) {
		row := rows[i]
		selected := i == ui.main_menu_selected
		if app_ui_draw_simulation_row(ui, gui, row, viewport, i, selected, theme) {
			ui.main_menu_selected = i
			app_ui_navigate(ui, app_ui_mode_for_simulation_index(i))
		}
		id := uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", i))
		if gui.focused == id {
			ui.main_menu_selected = i
		}
	}
	uifw.gui_apply_spatial_navigation(gui)
	for i in 0 ..< len(APP_SIMULATION_NAMES) {
		id := uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", i))
		if gui.focused == id {
			ui.main_menu_selected = i
		}
	}
	uifw.gui_pop_id(gui)
	uifw.gui_scroll_end(gui)
}

app_ui_draw_simulation_row :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, bounds, clip_bounds: uifw.Rect, index: int, selected: bool, theme: Menu_Theme) -> bool {
	id := uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", index))
	control := uifw.gui_control(gui, id, bounds, true)
	hover_t := uifw.gui_animate_value(gui, uifw.gui_id_child(id, "hover"), (control.hovered || control.focused) ? f32(1) : f32(0), 14)
	selected_t := uifw.gui_animate_value(gui, uifw.gui_id_child(id, "selected"), selected ? f32(1) : f32(0), 16)
	card := uifw.gui_inset(bounds, theme.border_width)
	clipped_card := uifw.gui_rect_intersection(card, clip_bounds)
	if clipped_card.w <= 1 || clipped_card.h <= 1 {
		return false
	}
	mode := app_ui_mode_for_simulation_index(index)
	live_preview := app_ui_live_preview_supported(mode)

	border := uifw.gui_lerp_color(theme.border, theme.border_hot, max(hover_t, selected_t))
	if live_preview {
		uifw.gui_round_stroke(gui, card, theme.card_radius, border, theme.border_width)
	} else {
		uifw.gui_box(gui, card, {
			fill = theme.preview_surface,
			border = border,
			radius = theme.card_radius,
			border_width = theme.border_width,
		})
	}

	preview := uifw.gui_inset(card, theme.border_width)
	clipped_preview := uifw.gui_rect_intersection(preview, clip_bounds)
	if clipped_preview.w > 1 && clipped_preview.h > 1 {
		app_ui_draw_live_simulation_preview(ui, gui, preview, clipped_preview, mode, theme.preview_surface, f32(index))
	}

	uifw.gui_scissor_begin(gui, clipped_card)
	if clipped_preview.w > 1 && clipped_preview.h > 1 {
		mid_x := preview.x + preview.w * MAIN_MENU_SIM_BUTTON_GRADIENT_MIDPOINT
		left_fade := uifw.gui_rect_intersection(
			{preview.x, preview.y, max(mid_x - preview.x, 0), preview.h},
			clipped_preview,
		)
		right_fade := uifw.gui_rect_intersection(
			{mid_x, preview.y, max(preview.x + preview.w - mid_x, 0), preview.h},
			clipped_preview,
		)
		if left_fade.w > 1 && left_fade.h > 1 {
			uifw.gui_horizontal_gradient_rect(gui, left_fade, {0, 0, 0, 1.0}, {0, 0, 0, 0.5})
		}
		if right_fade.w > 1 && right_fade.h > 1 {
			uifw.gui_horizontal_gradient_rect(gui, right_fade, {0, 0, 0, 0.5}, {0, 0, 0, 0.0})
		}
	}
	if hover_t > 0.01 || selected_t > 0.01 {
		uifw.gui_round_rect(gui, card, theme.card_radius, uifw.gui_lerp_color({1, 1, 1, 0.0}, {1, 1, 1, 0.13}, max(hover_t, selected_t)))
	}
	label_inset := max(theme.inner_gap, 22)
	label_max_w := max(card.w - label_inset * 2, 1)
	label_scale := app_ui_fit_sim_start_text_scale(gui, APP_SIMULATION_NAMES[index], gui.style.heading_text_scale * (card.h >= 96 ? f32(1.95) : f32(1.35)), label_max_w)
	label_h := uifw.GUI_FONT_LOGICAL_HEIGHT * label_scale
	label := uifw.Rect{
		card.x + label_inset,
		card.y + max((card.h - label_h) * 0.5, 0),
		label_max_w,
		label_h,
	}
	uifw.gui_text_aligned_font(gui, label, APP_SIMULATION_NAMES[index], theme.text, .Left, .SimStart, label_scale)
	uifw.gui_scissor_end(gui)

	if control.focused {
		uifw.gui_focus_ring(gui, uifw.gui_inset(card, -theme.border_width))
	}
	if selected_t > 0.01 {
		uifw.gui_round_stroke(gui, uifw.gui_inset(card, -theme.border_width), theme.card_radius + theme.border_width, uifw.gui_apply_opacity(theme.accent, 0.40 * selected_t), max(theme.border_width * 2, 2))
	}
	return control.activated || (control.hovered && gui.active == id && gui.input.mouse_released)
}

app_ui_draw_main_menu_detail :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, bounds: uifw.Rect, theme: Menu_Theme) {
	_ = ui
	_ = gui
	_ = bounds
	_ = theme
}

app_ui_live_preview_supported :: proc(mode: App_Mode) -> bool {
	#partial switch mode {
	case .Slime_Mold, .Gray_Scott, .Particle_Life, .Flow_Field, .Pellets, .Voronoi_CA, .Moire, .Vectors, .Primordial:
		return true
	case:
		return false
	}
}

app_ui_draw_live_simulation_preview :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, rect, clip_rect: uifw.Rect, mode: App_Mode, fallback_color: uifw.Color, seed: f32) {
	if app_ui_live_preview_supported(mode) {
		ui.main_menu_live_preview_visible = true
		ui.main_menu_live_preview_mode = mode
		ui.main_menu_live_preview_rect = rect
		if ui.main_menu_preview_slot_count < MAIN_MENU_PREVIEW_SLOT_CAP {
			ui.main_menu_preview_slots[ui.main_menu_preview_slot_count] = {mode = mode, rect = rect, clip_rect = clip_rect, fallback_color = fallback_color}
			ui.main_menu_preview_slot_count += 1
		}
		uifw.gui_round_stroke(gui, clip_rect, gui.style.radius_control, gui.style.panel_border, gui.style.border_width)
		return
	}
	app_ui_draw_simulation_preview(gui, clip_rect, mode, seed)
}

app_ui_draw_simulation_preview :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, mode: App_Mode, seed: f32) {
	if rect.w <= 0 || rect.h <= 0 {
		return
	}
	uifw.gui_round_rect(gui, rect, gui.style.radius_control, {0.015, 0.018, 0.026, 0.96})
	uifw.gui_round_stroke(gui, rect, gui.style.radius_control, gui.style.panel_border, gui.style.border_width)
	clip := uifw.gui_inset(rect, gui.style.border_width)
	uifw.gui_scissor_begin(gui, clip)
	t := f32(gui.frame_index % 240) / 240.0
	cx := rect.x + rect.w * 0.5
	cy := rect.y + rect.h * 0.5
	min_d := min(rect.w, rect.h)

	#partial switch mode {
	case .Slime_Mold:
		uifw.gui_gradient_rect(gui, rect, {0.02, 0.04, 0.025, 1}, {0.08, 0.16, 0.10, 1})
		for i in 0 ..< 8 {
			a := f32(i) * 0.785 + t * 2.0
			r := min_d * (0.12 + f32(i % 4) * 0.055)
			p := uifw.Vec2{cx + math.cos(a) * r, cy + math.sin(a * 1.7) * r}
			uifw.gui_line(gui, p, {p.x + math.cos(a + 1.4) * min_d * 0.22, p.y + math.sin(a + 1.4) * min_d * 0.22}, {0.52, 1.0, 0.58, 0.45}, max(gui.style.border_width, 1))
		}
	case .Gray_Scott:
		uifw.gui_gradient_rect(gui, rect, {0.03, 0.035, 0.08, 1}, {0.20, 0.10, 0.28, 1})
		for i in 0 ..< 6 {
			r := min_d * (0.10 + f32(i) * 0.055)
			uifw.gui_ellipse_stroke(gui, {cx - r, cy - r, r * 2, r * 2}, {0.65, 0.88, 1.0, 0.18 + f32(i) * 0.035}, max(gui.style.border_width, 1))
		}
	case .Particle_Life:
		uifw.gui_rect(gui, rect, {0.015, 0.018, 0.024, 1})
		for i in 0 ..< 18 {
			a := f32(i) * 2.399 + seed
			r := min_d * (0.10 + f32(i % 7) * 0.045)
			x := cx + math.cos(a + t) * r
			y := cy + math.sin(a * 1.3 - t) * r
			color := (i % 3 == 0) ? uifw.Color{0.95, 0.34, 0.42, 0.88} : ((i % 3 == 1) ? uifw.Color{0.28, 0.80, 1.0, 0.88} : uifw.Color{0.95, 0.82, 0.32, 0.88})
			s := max(min_d * 0.035, 2)
			uifw.gui_ellipse(gui, {x - s, y - s, s * 2, s * 2}, color)
		}
	case .Flow_Field:
		uifw.gui_gradient_rect(gui, rect, {0.02, 0.03, 0.06, 1}, {0.05, 0.16, 0.18, 1})
		for i in 0 ..< 7 {
			y := rect.y + rect.h * (f32(i) + 0.5) / 7.0
			uifw.gui_line(gui, {rect.x + rect.w * 0.12, y}, {rect.x + rect.w * 0.88, y + math.sin(f32(i) + t * 6.0) * rect.h * 0.10}, {0.35, 0.95, 0.95, 0.40}, max(gui.style.border_width, 1))
		}
	case .Pellets:
		uifw.gui_rect(gui, rect, {0.04, 0.03, 0.025, 1})
		for i in 0 ..< 10 {
			x := rect.x + rect.w * (0.14 + f32((i * 37) % 73) / 100.0)
			y := rect.y + rect.h * (0.18 + f32((i * 19) % 67) / 100.0)
			s := min_d * (0.035 + f32(i % 3) * 0.014)
			uifw.gui_ellipse(gui, {x - s, y - s, s * 2, s * 2}, {0.95, 0.63, 0.24, 0.85})
		}
	case .Gradient_Editor:
		uifw.gui_gradient_rect(gui, rect, {0.20, 0.20, 0.85, 1}, {1.0, 0.42, 0.16, 1})
	case .Voronoi_CA:
		uifw.gui_rect(gui, rect, {0.025, 0.025, 0.035, 1})
		cell := max(min_d * 0.18, 4)
		for y := rect.y; y < rect.y + rect.h; y += cell {
			for x := rect.x; x < rect.x + rect.w; x += cell {
				k := int((x + y + seed * 17) / cell) % 3
				color := k == 0 ? uifw.Color{0.16, 0.72, 0.68, 0.65} : (k == 1 ? uifw.Color{0.86, 0.34, 0.48, 0.58} : uifw.Color{0.88, 0.78, 0.30, 0.50})
				uifw.gui_rect(gui, {x, y, cell - gui.style.border_width, cell - gui.style.border_width}, color)
			}
		}
	case .Moire:
		uifw.gui_rect(gui, rect, {0.02, 0.02, 0.028, 1})
		for i in 0 ..< 9 {
			a := -0.7 + f32(i) * 0.17
			x := rect.x + rect.w * f32(i) / 8.0
			uifw.gui_rotated_rect(gui, {x, cy, rect.w * 0.9, max(gui.style.border_width, 1)}, a, {0.94, 0.84, 0.36, 0.20})
		}
	case .Vectors:
		uifw.gui_rect(gui, rect, {0.015, 0.025, 0.028, 1})
		for i in 0 ..< 6 {
			x := rect.x + rect.w * (0.15 + f32(i) * 0.14)
			y := rect.y + rect.h * (0.25 + f32(i % 3) * 0.22)
			a := f32(i) * 0.7 + t * 2
			d := min_d * 0.12
			uifw.gui_line(gui, {x - math.cos(a) * d, y - math.sin(a) * d}, {x + math.cos(a) * d, y + math.sin(a) * d}, {0.58, 0.93, 0.88, 0.75}, max(gui.style.border_width, 1))
		}
	case .Primordial:
		uifw.gui_gradient_rect(gui, rect, {0.025, 0.016, 0.04, 1}, {0.10, 0.04, 0.13, 1})
		for i in 0 ..< 12 {
			a := f32(i) * 0.86 + t * 4
			r := min_d * (0.08 + f32(i) * 0.018)
			s := max(min_d * 0.025, 2)
			uifw.gui_ellipse(gui, {cx + math.cos(a) * r - s, cy + math.sin(a * 1.2) * r - s, s * 2, s * 2}, {0.96, 0.42, 0.95, 0.55})
		}
	case:
		uifw.gui_rect(gui, rect, {0.08, 0.08, 0.10, 1})
	}
	uifw.gui_scissor_end(gui)
}

app_ui_draw_gradient_editor :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, vk_ctx: ^engine.Vk_Context) {
	width := f32(vk_ctx.swapchain_extent.width)
	height := f32(vk_ctx.swapchain_extent.height)
	color_scheme_editor_draw_full_preview(gui, &ui.color_scheme_editor, {0, 0, width, height})

	if ui.simulation_shell.controls_visible {
		app_ui_draw_simulation_bar(ui, gui, .Gradient_Editor, nil, nil, nil, true, false, "Gradient Editor", vk_ctx, width, nil)
	}
	if ui.simulation_shell.show_ui {
		panel := app_ui_simulation_menu_panel(ui, gui, width, height)
		color_scheme_editor_draw_standalone(gui, &ui.color_scheme_editor, panel, &ui.gradient_editor_scroll)
	}
}

app_ui_draw_remaining_sim :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind, sim: ^Remaining_Sim_State, vk_ctx: ^engine.Vk_Context, worker: ^Render_Worker_State) {
	width := f32(vk_ctx.swapchain_extent.width)
	height := f32(vk_ctx.swapchain_extent.height)
	if gui.input.pause {
		sim.paused = !sim.paused
	}
	if kind != .Vectors && kind != .Moire && kind != .Primordial && kind != .Pellets && kind != .Flow_Field && kind != .Slime_Mold && kind != .Voronoi_CA {
		remaining_sim_draw(sim, gui, kind, width, height)
	}
	if ui.simulation_shell.controls_visible {
		app_ui_draw_simulation_bar(ui, gui, app_mode_from_remaining_sim_kind(kind), nil, nil, sim, sim.paused, false, remaining_sim_name(kind), vk_ctx, width, worker)
	}
	if ui.simulation_shell.show_ui {
		panel := app_ui_simulation_menu_panel(ui, gui, width, height)
		remaining_sim_draw_controls(sim, gui, kind, panel, &ui.color_scheme_editor, worker)
		remaining_sim_draw_color_scheme_modal(gui, &ui.color_scheme_editor, kind, sim)
	}
	if kind == .Vectors && sim.vectors_image_dialog_requested {
		sim.vectors_image_dialog_requested = false
		msg: Render_To_Ui_Message
		msg.kind = .Request_Vectors_Image_Dialog
		_ = engine.queue_try_push(worker.render_to_ui, msg)
	}
	if kind == .Moire && sim.moire_image_dialog_requested {
		sim.moire_image_dialog_requested = false
		msg: Render_To_Ui_Message
		msg.kind = .Request_Moire_Image_Dialog
		_ = engine.queue_try_push(worker.render_to_ui, msg)
	}
	if kind == .Flow_Field && sim.flow_image_dialog_requested {
		sim.flow_image_dialog_requested = false
		msg: Render_To_Ui_Message
		msg.kind = .Request_Flow_Image_Dialog
		_ = engine.queue_try_push(worker.render_to_ui, msg)
	}
	if kind == .Slime_Mold && sim.slime_mask_image_dialog_requested {
		sim.slime_mask_image_dialog_requested = false
		msg: Render_To_Ui_Message
		msg.kind = .Request_Slime_Mask_Image_Dialog
		_ = engine.queue_try_push(worker.render_to_ui, msg)
	}
	if kind == .Slime_Mold && sim.slime_position_image_dialog_requested {
		sim.slime_position_image_dialog_requested = false
		msg: Render_To_Ui_Message
		msg.kind = .Request_Slime_Position_Image_Dialog
		_ = engine.queue_try_push(worker.render_to_ui, msg)
	}
}

app_ui_draw_options :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, vk_ctx: ^engine.Vk_Context, worker: ^Render_Worker_State) {
	window_w := f32(vk_ctx.swapchain_extent.width)
	window_h := f32(vk_ctx.swapchain_extent.height)
	panel_w := min(max(window_w * 0.72, gui.style.body_char_width * 54), max(window_w - gui.style.margin * 2, 1))
	panel_h := min(max(window_h * 0.86, gui.style.row_height * 12), max(window_h - gui.style.margin * 2, 1))
	panel := centered_panel_styled(panel_w, panel_h, i32(vk_ctx.swapchain_extent.width), i32(vk_ctx.swapchain_extent.height), &gui.style)
	uifw.gui_panel_begin(gui, panel)
	viewport := uifw.gui_next_rect(gui, height = max(panel.h - gui.style.panel_padding * 2, 0))
	content_height := app_ui_options_content_height(gui, ui.settings_dirty)
	uifw.gui_scroll_begin(gui, viewport, content_height, &ui.options_scroll)
	uifw.gui_heading(gui, "App Settings")

	uifw.gui_push_id(gui, "settings")
	if uifw.gui_button(gui, "Back to Menu", "back") {
		app_ui_navigate(ui, .Main_Menu)
	}

	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "Display Settings")
	uifw.gui_push_id(gui, "display")
	if uifw.gui_toggle(gui, fmt.tprintf("FPS Limiter: %v", ui.settings.default_fps_limit_enabled), "fps_limiter", &ui.settings.default_fps_limit_enabled) {
		ui.settings_dirty = true
		app_ui_publish_settings_changed(ui, worker)
	}
	fps_limit := f32(ui.settings.default_fps_limit)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("FPS Limit: %d", ui.settings.default_fps_limit), "fps_limit", &fps_limit, 1, 1, 1200) {
		ui.settings.default_fps_limit = i32(fps_limit)
		ui.settings_dirty = true
		app_ui_publish_settings_changed(ui, worker)
	}
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("UI Scale: %.1f", ui.settings.ui_scale), "ui_scale", &ui.settings.ui_scale, 0.1, 0.5, 3.0) {
		ui.settings_dirty = true
	}
	if uifw.gui_selector(gui, fmt.tprintf("Texture Filtering: %s", TEXTURE_FILTERING_OPTIONS[ui.texture_filtering_index]), "texture_filtering", &ui.texture_filtering_index, TEXTURE_FILTERING_OPTIONS[:]) {
		ui.settings.texture_filtering = TEXTURE_FILTERING_OPTIONS[ui.texture_filtering_index]
		ui.settings_dirty = true
	}
	uifw.gui_pop_id(gui)

	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "Window Settings")
	uifw.gui_push_id(gui, "window")
	width := f32(ui.settings.window_width)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Default Width: %d", ui.settings.window_width), "width", &width, 50, 800, 3840) {
		ui.settings.window_width = i32(width)
		ui.settings_dirty = true
	}
	height := f32(ui.settings.window_height)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Default Height: %d", ui.settings.window_height), "height", &height, 50, 600, 2160) {
		ui.settings.window_height = i32(height)
		ui.settings_dirty = true
	}
	if uifw.gui_toggle(gui, fmt.tprintf("Start Maximized: %v", ui.settings.window_maximized), "maximized", &ui.settings.window_maximized) {
		ui.settings_dirty = true
	}
	uifw.gui_pop_id(gui)

	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "UI Behavior")
	uifw.gui_push_id(gui, "ui_behavior")
	if uifw.gui_toggle(gui, fmt.tprintf("Auto-hide UI: %v", ui.settings.auto_hide_ui), "auto_hide", &ui.settings.auto_hide_ui) {
		ui.settings_dirty = true
	}
	delay := f32(ui.settings.auto_hide_delay)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Auto-hide Delay: %d ms", ui.settings.auto_hide_delay), "auto_hide_delay", &delay, 500, 1000, 10000) {
		ui.settings.auto_hide_delay = i32(delay)
		ui.settings_dirty = true
	}
	if uifw.gui_selector(gui, fmt.tprintf("Menu Position: %s", MENU_POSITION_OPTIONS[ui.menu_position_index]), "menu_position", &ui.menu_position_index, MENU_POSITION_OPTIONS[:]) {
		ui.settings.menu_position = MENU_POSITION_OPTIONS[ui.menu_position_index]
		ui.settings_dirty = true
	}
	uifw.gui_pop_id(gui)

	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "Camera Settings")
	uifw.gui_push_id(gui, "camera")
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Camera Sensitivity: %.1f", ui.settings.default_camera_sensitivity), "sensitivity", &ui.settings.default_camera_sensitivity, 0.1, 0.1, 5.0) {
		ui.settings_dirty = true
	}
	uifw.gui_pop_id(gui)

	uifw.gui_spacer(gui, gui.style.spacing_2)
	if uifw.gui_button(gui, "Save", "save") {
		app_ui_save_settings(ui, worker)
	}
	if uifw.gui_button(gui, "Reset to Defaults", "reset_defaults") {
		ui.settings = settings_default()
		ui.menu_position_index = option_index(ui.settings.menu_position, MENU_POSITION_OPTIONS[:], 1)
		ui.texture_filtering_index = option_index(ui.settings.texture_filtering, TEXTURE_FILTERING_OPTIONS[:], 0)
		app_ui_save_settings(ui, worker)
	}
	if ui.settings_dirty {
		uifw.gui_label(gui, "Unsaved changes")
	}
	uifw.gui_pop_id(gui)
	uifw.gui_scroll_end(gui)
	uifw.gui_panel_end(gui)
}

app_ui_draw_how_to_play :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	uifw.gui_panel_begin(gui, {40, 40, 560, 320})
	uifw.gui_heading(gui, "How To Play")
	uifw.gui_text_block(gui, "Choose a simulation from the main menu. Use the options menu to tune app-level behavior. Gray-Scott controls are live immediate-mode widgets. More Vizza modes will be ported after the Vulkan V1 path lands.", 520, gui.style.text)
	uifw.gui_spacer(gui, 12)
	if uifw.gui_button(gui, "Back to Menu", "back") {
		app_ui_navigate(ui, .Main_Menu)
	}
	uifw.gui_panel_end(gui)
}

app_ui_draw_gray_scott :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, worker: ^Render_Worker_State) {
	width := f32(vk_ctx.swapchain_extent.width)
	height := f32(vk_ctx.swapchain_extent.height)

	if gui.input.pause {
		sim.settings.paused = !sim.settings.paused
	}

	if ui.simulation_shell.controls_visible {
		app_ui_draw_simulation_bar(ui, gui, .Gray_Scott, sim, nil, nil, sim.settings.paused, !sim.gpu.ready, "Gray-Scott", vk_ctx, width, worker)
	}
	if ui.simulation_shell.show_ui {
		panel := app_ui_simulation_menu_panel(ui, gui, width, height)
		_ = gray_scott_draw_controls(sim, gui, panel, &ui.gray_scott_scroll, worker, &ui.color_scheme_editor)
		_ = color_scheme_editor_draw_modal(gui, &ui.color_scheme_editor, &sim.settings.color_scheme)
	}
	if sim.runtime.nutrient_image_dialog_requested {
		sim.runtime.nutrient_image_dialog_requested = false
		msg: Render_To_Ui_Message
		msg.kind = .Request_Nutrient_Image_Dialog
		_ = engine.queue_try_push(worker.render_to_ui, msg)
	}
	app_ui_draw_loading_overlay(gui, width, height, !sim.gpu.ready)
}

app_ui_simulation_shell_update :: proc(ui: ^App_Ui_State, input: Ui_Frame_Input) {
	interaction := input.mouse_pressed ||
		input.mouse_released ||
		input.mouse_down ||
		input.mouse_moved ||
		input.wheel_delta != 0 ||
		input.pause ||
		input.toggle_ui ||
		input.key_space ||
		input.key_slash ||
		input.nav_x != 0 ||
		input.nav_y != 0 ||
		input.accept ||
		input.back ||
		input.key_w ||
		input.key_a ||
		input.key_s ||
		input.key_d ||
		input.key_q ||
		input.key_e ||
		input.key_c
	if interaction {
		ui.simulation_shell.idle_seconds = 0
		if ui.settings.auto_hide_ui && !ui.simulation_shell.show_ui {
			ui.simulation_shell.controls_visible = true
		}
	} else {
		ui.simulation_shell.idle_seconds += input.delta_time
	}
	auto_hide_delay_seconds := f32(max(ui.settings.auto_hide_delay, 0)) / 1000.0
	if ui.settings.auto_hide_ui &&
	   !ui.simulation_shell.show_ui &&
	   ui.simulation_shell.controls_visible &&
	   ui.simulation_shell.idle_seconds >= auto_hide_delay_seconds {
		ui.simulation_shell.controls_visible = false
	}
	if !ui.settings.auto_hide_ui || ui.simulation_shell.show_ui {
		ui.simulation_shell.controls_visible = true
	}
	if input.toggle_ui || input.key_slash {
		ui.simulation_shell.show_ui = !ui.simulation_shell.show_ui
		ui.simulation_shell.controls_visible = true
		ui.simulation_shell.idle_seconds = 0
	}
}

app_ui_system_cursor_hidden :: proc(ui: ^App_Ui_State) -> bool {
	return ui != nil &&
		app_ui_mode_is_simulation(ui.mode) &&
		!ui.simulation_shell.show_ui &&
		!ui.simulation_shell.controls_visible
}

app_ui_simulation_filter_input :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, input: Ui_Frame_Input) -> Ui_Frame_Input {
	app_ui_simulation_shell_update(ui, input)

	if !app_ui_mode_is_simulation(ui.mode) {
		filtered := input
		filtered.mouse_down = false
		filtered.mouse_pressed = false
		filtered.mouse_released = false
		filtered.wheel_delta = 0
		ui.simulation_shell.mouse_pressed = false
		return filtered
	}

	filtered := input
	width := f32(input.window_width)
	height := f32(input.window_height)
	bar_rect := uifw.Rect{0, 0, width, app_ui_simulation_bar_height(gui)}
	menu_rect := app_ui_simulation_menu_panel(ui, gui, width, height)
	over_bar := ui.simulation_shell.controls_visible && uifw.gui_contains(bar_rect, input.mouse_pos)
	over_menu := ui.simulation_shell.show_ui && uifw.gui_contains(menu_rect, input.mouse_pos)
	over_ui := over_bar || over_menu

	if input.mouse_pressed {
		ui.simulation_shell.mouse_pressed = !over_ui
		ui.simulation_shell.mouse_button = input.mouse_button
		if over_ui {
			filtered.mouse_pressed = false
			filtered.mouse_down = false
		}
	}
	if input.mouse_released {
		ui.simulation_shell.mouse_pressed = false
	}
	if ui.simulation_shell.mouse_pressed && over_ui {
		filtered.mouse_down = false
		filtered.mouse_pressed = false
		filtered.mouse_released = true
		filtered.mouse_button = ui.simulation_shell.mouse_button
		ui.simulation_shell.mouse_pressed = false
	} else if !ui.simulation_shell.mouse_pressed && over_ui {
		filtered.mouse_down = false
		filtered.mouse_pressed = false
		filtered.mouse_released = false
	}
	if over_ui {
		filtered.wheel_delta = 0
	}
	if gui.focused != uifw.GUI_ID_NONE {
		filtered.text_input = {}
		filtered.text_input_len = 0
		filtered.clipboard_paste = {}
		filtered.clipboard_paste_len = 0
		filtered.key_tab = false
		filtered.key_enter = false
		filtered.key_escape = false
		filtered.key_backspace = false
		filtered.key_delete = false
		filtered.key_home = false
		filtered.key_end = false
		filtered.key_left = false
		filtered.key_right = false
		filtered.key_up = false
		filtered.key_down = false
		filtered.nav_x = 0
		filtered.nav_y = 0
		filtered.nav_pressed_x = 0
		filtered.nav_pressed_y = 0
		filtered.accept = false
		filtered.back = false
		filtered.focus_next = false
		filtered.focus_prev = false
		filtered.key_w = false
		filtered.key_a = false
		filtered.key_s = false
		filtered.key_d = false
		filtered.key_q = false
		filtered.key_e = false
		filtered.key_x = false
		filtered.key_v = false
		filtered.key_c = false
	}
	return filtered
}

app_ui_draw_simulation_bar :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, mode: App_Mode, gray_scott: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation, remaining: ^Remaining_Sim_State, paused, loading: bool, simulation_name: string, vk_ctx: ^engine.Vk_Context, width: f32, worker: ^Render_Worker_State) {
	_ = vk_ctx
	bar_h := app_ui_simulation_bar_height(gui)
	bar := uifw.Rect{0, 0, width, bar_h}
	uifw.gui_backdrop_blur_rect(gui, bar, {1, 1, 1, 0.62}, 0.006)
	uifw.gui_rect(gui, bar, {0, 0, 0, 0.80})
	uifw.gui_stroke(gui, {0, bar_h - gui.style.border_width, width, gui.style.border_width}, {1, 1, 1, 0.10})

	scale := app_ui_simulation_bar_scale(gui)
	button_h := min(gui.style.row_height, max(bar_h - gui.style.spacing_2 * 2, 1))
	gap := gui.style.spacing_2
	x := gui.style.spacing_2
	y := (bar_h - button_h) * 0.5
	back_w := uifw.gui_button_content_width(gui, "Back to Menu")
	toggle_label := ui.simulation_shell.show_ui ? "Hide UI" : "Show UI"
	toggle_w := uifw.gui_button_content_width(gui, toggle_label)
	pause_label := paused ? "Resume" : "Pause"
	pause_w := uifw.gui_button_content_width(gui, pause_label)
	record_visible := worker != nil && app_ui_mode_allows_video_recording(mode)
	record_label := app_ui_video_recording_button_label(ui)
	record_w := record_visible ? uifw.gui_button_content_width(gui, record_label) : f32(0)
	back_rect := uifw.Rect{x, y, back_w, button_h}
	toggle_rect := uifw.Rect{back_rect.x + back_w + gap, y, toggle_w, button_h}
	pause_rect := uifw.Rect{max(width * 0.5 - pause_w * 0.5, toggle_rect.x + toggle_rect.w + gap), y, pause_w, button_h}
	record_rect := uifw.Rect{pause_rect.x + pause_rect.w + gap, y, record_w, button_h}

	uifw.gui_push_id(gui, "simulation_bar")
	if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "back"), back_rect, "Back to Menu", true) {
		app_ui_video_recording_stop(ui, worker)
		app_ui_navigate(ui, .Main_Menu)
	}
	if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "toggle_ui"), toggle_rect, toggle_label, true) {
		ui.simulation_shell.show_ui = !ui.simulation_shell.show_ui
		ui.simulation_shell.controls_visible = true
		ui.simulation_shell.idle_seconds = 0
	}
	if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "pause"), pause_rect, pause_label, true) {
		app_ui_simulation_set_paused(mode, gray_scott, particle_life, remaining, !paused)
	}
	if record_visible {
		if ui.video_recording_state == .Restoring_Fullscreen {
			uifw.gui_text_aligned(gui, app_ui_simulation_bar_text_rect(gui, record_rect), record_label, gui.style.text_muted, .Center)
		} else if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "record"), record_rect, record_label, true) {
			app_ui_video_recording_toggle(ui, worker)
		}
	}
	status := loading ? "Loading..." : (paused ? "Stopped" : "Running")
	status_x := record_visible ? record_rect.x + record_rect.w + gap : pause_rect.x + pause_rect.w + gap
	status_rect := uifw.Rect{status_x, y, 132 * scale, button_h}
	uifw.gui_text_aligned(gui, app_ui_simulation_bar_text_rect(gui, status_rect), status, loading ? gui.style.accent : gui.style.text_muted, .Center)

	info := fmt.tprintf("%s at %03.0f FPS", simulation_name, ui.last_stats.fps)
	right_w := f32(260) * scale
	info_rect := uifw.Rect{max(width - right_w - gui.style.spacing_2, status_rect.x + status_rect.w + gap), y, right_w, button_h}
	uifw.gui_text_right(gui, app_ui_simulation_bar_text_rect(gui, info_rect), info, gui.style.text_muted)
	uifw.gui_pop_id(gui)
}

app_ui_simulation_bar_text_rect :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect) -> uifw.Rect {
	return {rect.x, rect.y + max((rect.h - gui.style.body_text_height) * 0.5, 0), rect.w, gui.style.body_text_height}
}

app_ui_video_recording_button_label :: proc(ui: ^App_Ui_State) -> string {
	#partial switch ui.video_recording_state {
	case .Choosing_Path:
		return "Choosing..."
	case .Restoring_Fullscreen:
		return "Restoring..."
	case .Recording:
		return "Stop Recording"
	case:
		return "Record"
	}
}

app_ui_mode_allows_video_recording :: proc(mode: App_Mode) -> bool {
	#partial switch mode {
	case .Slime_Mold, .Gray_Scott, .Particle_Life, .Flow_Field, .Pellets, .Voronoi_CA, .Moire, .Vectors, .Primordial:
		return true
	case:
		return false
	}
}

app_ui_video_recording_toggle :: proc(ui: ^App_Ui_State, worker: ^Render_Worker_State) {
	if worker == nil {
		return
	}
	if ui.video_recording_state == .Recording {
		app_ui_video_recording_stop(ui, worker)
		return
	}
	if ui.video_recording_state != .Choosing_Path {
		ui.video_recording_state = .Choosing_Path
		write_fixed_string(ui.video_recording_status[:], "Choosing recording destination")
	}
	app_ui_video_recording_request_save_dialog(ui, worker)
}

app_ui_video_recording_request_save_dialog :: proc(ui: ^App_Ui_State, worker: ^Render_Worker_State) {
	ui.video_recording_state = .Choosing_Path
	write_fixed_string(ui.video_recording_status[:], "Choosing recording destination")
	msg: Render_To_Ui_Message
	msg.kind = .Request_Video_Save_Dialog
	engine.log_info("video_recording: record clicked; requesting save dialog")
	if !engine.queue_try_push(worker.render_to_ui, msg) {
		engine.log_error("video_recording: failed to queue save dialog request")
		app_ui_video_recording_apply_command_state(ui, .Failed, "Could not open save dialog")
	}
}

app_ui_video_recording_stop :: proc(ui: ^App_Ui_State, worker: ^Render_Worker_State) {
	if worker == nil {
		return
	}
	if ui.video_recording_state == .Recording || ui.video_recording_state == .Choosing_Path || ui.video_recording_state == .Restoring_Fullscreen {
		cmd: Ui_To_Render_Command
		cmd.kind = .Stop_Video_Recording
		_ = engine.queue_try_push(worker.ui_to_render, cmd)
		ui.video_recording_state = .Idle
		write_fixed_string(ui.video_recording_status[:], "")
	}
}

app_ui_video_recording_apply_command_state :: proc(ui: ^App_Ui_State, state: Video_Recording_Ui_State, text: string = "") {
	ui.video_recording_state = state
	write_fixed_string(ui.video_recording_status[:], text)
}

app_ui_simulation_set_paused :: proc(mode: App_Mode, gray_scott: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation, remaining: ^Remaining_Sim_State, paused: bool) {
	#partial switch mode {
	case .Gray_Scott:
		if gray_scott != nil {
			gray_scott.settings.paused = paused
		}
	case .Particle_Life:
		if particle_life != nil {
			particle_life.settings.paused = paused
		}
	case .Slime_Mold, .Flow_Field, .Pellets, .Voronoi_CA, .Moire, .Vectors, .Primordial:
		if remaining != nil {
			remaining.paused = paused
		}
	case:
	}
}

app_ui_mode_is_simulation :: proc(mode: App_Mode) -> bool {
	#partial switch mode {
	case .Slime_Mold, .Gray_Scott, .Particle_Life, .Flow_Field, .Pellets, .Gradient_Editor, .Voronoi_CA, .Moire, .Vectors, .Primordial:
		return true
	case:
		return false
	}
}

app_mode_from_remaining_sim_kind :: proc(kind: Remaining_Sim_Kind) -> App_Mode {
	#partial switch kind {
	case .Slime_Mold:
		return .Slime_Mold
	case .Flow_Field:
		return .Flow_Field
	case .Pellets:
		return .Pellets
	case .Voronoi_CA:
		return .Voronoi_CA
	case .Moire:
		return .Moire
	case .Vectors:
		return .Vectors
	case .Primordial:
		return .Primordial
	}
	return .Main_Menu
}

app_ui_simulation_reset :: proc(mode: App_Mode, gray_scott: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation) {
	#partial switch mode {
	case .Gray_Scott:
		if gray_scott != nil {
			gray_scott_reset_runtime(gray_scott)
		}
	case .Particle_Life:
		if particle_life != nil {
			particle_life_reset_runtime(particle_life)
		}
	case:
	}
}

app_ui_simulation_randomize :: proc(mode: App_Mode, gray_scott: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation) {
	#partial switch mode {
	case .Gray_Scott:
		if gray_scott != nil {
			gray_scott_randomize_settings(gray_scott)
		}
	case .Particle_Life:
		if particle_life != nil {
			particle_life_randomize_forces(particle_life)
		}
	case:
	}
}

app_ui_draw_loading_overlay :: proc(gui: ^uifw.Gui_Context, width, height: f32, loading: bool) {
	if !loading {
		return
	}
	overlay := uifw.Rect{0, 0, width, height}
	uifw.gui_rect(gui, overlay, {0, 0, 0, 0.80})
	scale := app_ui_simulation_bar_scale(gui)
	spinner_size := max(gui.style.rhythm, f32(40) * scale)
	center_x := width * 0.5
	center_y := height * 0.5 - gui.style.rhythm
	spinner := uifw.Rect{center_x - spinner_size * 0.5, center_y - spinner_size * 0.5, spinner_size, spinner_size}
	uifw.gui_ellipse_stroke(gui, spinner, {1, 1, 1, 0.30}, max(gui.style.border_width * 2, 4 * scale))
	angle := f32(gui.frame_index % 60) / 60.0 * uifw.GUI_TAU
	dot_r := spinner_size * 0.12
	orbit_r := spinner_size * 0.5
	dot := uifw.Rect{
		center_x + math.cos(angle) * orbit_r - dot_r,
		center_y + math.sin(angle) * orbit_r - dot_r,
		dot_r * 2,
		dot_r * 2,
	}
	uifw.gui_ellipse(gui, dot, {1, 1, 1, 1})
	title_w := min(width - gui.style.margin * 2, max(gui.style.body_char_width * 26, 1))
	title := uifw.Rect{center_x - title_w * 0.5, center_y + spinner_size * 0.5 + gui.style.spacing_2, title_w, gui.style.body_line_height}
	uifw.gui_text_centered(gui, title, "Starting Simulation...", gui.style.text)
	subtitle := uifw.Rect{title.x, title.y + title.h, title.w, gui.style.small_line_height}
	uifw.gui_text_centered(gui, subtitle, "Initializing GPU resources", gui.style.text_muted)
}

app_ui_simulation_bar_scale :: proc(gui: ^uifw.Gui_Context) -> f32 {
	return max(gui.style.row_height / SIMULATION_BAR_BASE_ROW_HEIGHT, 1)
}

app_ui_simulation_bar_height :: proc(gui: ^uifw.Gui_Context) -> f32 {
	content_h := gui.style.spacing_2 * 2 + gui.style.row_height
	return max(SIMULATION_BAR_HEIGHT, content_h)
}

app_ui_simulation_menu_panel :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, width, height: f32) -> uifw.Rect {
	top := app_ui_simulation_bar_height(gui)
	bottom_margin := f32(0)
	breakpoint := uifw.gui_breakpoint(width)
	min_w := breakpoint == .Compact ? max(gui.style.body_char_width * 18, f32(320)) : max(gui.style.body_char_width * 24, f32(440))
	max_w := breakpoint == .Wide ? max(gui.style.body_char_width * 34, f32(760)) : max(gui.style.body_char_width * 30, f32(680))
	if ui.mode == .Particle_Life {
		force_cell := max(gui.style.row_height * 1.35, gui.style.rhythm * 1.45)
		force_grid_w := force_cell * f32(PARTICLE_LIFE_MAX_SPECIES + 1)
		min_w = max(min_w, force_grid_w + gui.style.panel_padding * 2 + gui.style.spacing_3)
		max_w = max(max_w, min_w)
	} else if ui.mode == .Gradient_Editor {
		min_w = breakpoint == .Compact ? max(gui.style.body_char_width * 19, f32(340)) : max(gui.style.body_char_width * 28, f32(520))
		max_w = breakpoint == .Wide ? max(gui.style.body_char_width * 34, f32(720)) : max(gui.style.body_char_width * 31, f32(660))
	}
	available_w := max(width - gui.style.margin * 2, 1)
	panel_w := min(max(width * 0.36, min_w), min(max_w, available_w))
	panel_h := max(height - top - bottom_margin, 120)
	x := max((width - panel_w) * 0.5, gui.style.margin)

	position := MENU_POSITION_OPTIONS[ui.menu_position_index]
	if position == "left" {
		x = gui.style.margin
	} else if position == "right" {
		x = max(width - panel_w - gui.style.margin, gui.style.margin)
	}
	return {x, top, panel_w, panel_h}
}

app_ui_navigate :: proc(ui: ^App_Ui_State, mode: App_Mode) {
	if ui.video_recording_state == .Recording && app_ui_mode_is_simulation(ui.mode) && !app_ui_mode_is_simulation(mode) {
		ui.video_recording_state = .Idle
		write_fixed_string(ui.video_recording_status[:], "")
	}
	ui.previous_mode = ui.mode
	ui.mode = mode
	if mode == .Options {
		ui.options_scroll = 0
	}
}

app_ui_save_settings :: proc(ui: ^App_Ui_State, worker: ^Render_Worker_State) {
	if settings_save_app("config/app.toml", ui.settings) {
		worker.settings = ui.settings
		ui.settings_dirty = false
		app_ui_publish_settings_changed(ui, worker)
		msg: Render_To_Ui_Message
		msg.kind = .Preset_Result
		msg.preset_ok = true
		write_fixed_string(msg.text[:], "Saved app settings")
		_ = engine.queue_try_push(worker.render_to_ui, msg)
	}
}

app_ui_publish_settings_changed :: proc(ui: ^App_Ui_State, worker: ^Render_Worker_State) {
	msg: Render_To_Ui_Message
	msg.kind = .App_Settings_Changed
	msg.app_settings = ui.settings
	_ = engine.queue_try_push(worker.render_to_ui, msg)
}

app_ui_draw_theme_preview :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, vk_ctx: ^engine.Vk_Context) {
	_ = ui
	width := f32(vk_ctx.swapchain_extent.width)
	height := f32(vk_ctx.swapchain_extent.height)
	margin := f32(28)
	panel := uifw.Rect{margin, margin, max(width - margin * 2, 0), max(height - margin * 2, 0)}
	uifw.gui_panel_begin(gui, panel)
	uifw.gui_heading(gui, "UI Theme Preview")
	uifw.gui_label(gui, "Design sheet for the immediate-mode UI package")
	uifw.gui_spacer(gui, 10)

	sheet := uifw.gui_next_rect(gui, height = max(panel.h - 154, 0))
	column_gap := gui.style.spacing
	column_width := max((sheet.w - column_gap * 4) / 5, 0)
	controls := uifw.Rect{sheet.x, sheet.y, column_width, sheet.h}
	inputs := uifw.Rect{sheet.x + (column_width + column_gap), sheet.y, column_width, sheet.h}
	text_palette := uifw.Rect{sheet.x + (column_width + column_gap) * 2, sheet.y, column_width, sheet.h}
	media_layout := uifw.Rect{sheet.x + (column_width + column_gap) * 3, sheet.y, column_width, sheet.h}
	advanced := uifw.Rect{sheet.x + (column_width + column_gap) * 4, sheet.y, column_width, sheet.h}

	app_ui_theme_preview_controls(gui, controls)
	app_ui_theme_preview_inputs(gui, inputs)
	app_ui_theme_preview_text_palette(gui, text_palette)
	app_ui_theme_preview_media_layout(gui, media_layout)
	app_ui_theme_preview_advanced(ui, gui, advanced)
	uifw.gui_panel_end(gui)
}

app_ui_theme_preview_controls :: proc(gui: ^uifw.Gui_Context, bounds: uifw.Rect) {
	uifw.gui_layout_begin(gui, bounds, .Column, gui.style.spacing, gui.style.row_height)
	uifw.gui_heading(gui, "Buttons")
	_ = uifw.gui_button(gui, "Primary Button", "primary")
	app_ui_preview_button_state(gui, "Hover Button", "hover", .Hot)
	app_ui_preview_button_state(gui, "Active Button", "active", .Active)
	app_ui_preview_button_state(gui, "Focused Button", "focused", .Focused)
	uifw.gui_disabled_button(gui, "Disabled Button")

	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "Cards")
	card_height := max(gui.style.text_height * 2 + 28, f32(100))
	card := uifw.gui_next_rect(gui, height = card_height)
	_ = uifw.gui_card_button(gui, card, "Enabled Card", "enabled_card", "Subtitle and detail text", true)
	app_ui_preview_card_state(gui, "Hover Card", "hover_card", "Hot state", .Hot)
	app_ui_preview_card_state(gui, "Active Card", "active_card", "Pressed state", .Active)
	card = uifw.gui_next_rect(gui, height = card_height)
	_ = uifw.gui_card_button(gui, card, "Disabled Card", "disabled_card", "Unavailable", false)
	uifw.gui_layout_end(gui)
}

app_ui_theme_preview_inputs :: proc(gui: ^uifw.Gui_Context, bounds: uifw.Rect) {
	uifw.gui_layout_begin(gui, bounds, .Column, gui.style.spacing, gui.style.row_height)
	uifw.gui_heading(gui, "Inputs")
	toggle_on := true
	toggle_off := false
	_ = uifw.gui_toggle(gui, "Toggle: true", "toggle_on", &toggle_on)
	_ = uifw.gui_toggle(gui, "Toggle: false", "toggle_off", &toggle_off)
	app_ui_preview_button_state(gui, "Toggle: hover", "toggle_hover", .Hot)

	uifw.gui_spacer(gui, gui.style.spacing_2)
	value_low := f32(0.22)
	value_mid := f32(0.58)
	value_high := f32(0.86)
	_ = uifw.gui_slider_f32(gui, "Slider: 22%", "slider", &value_low, 0, 1)
	app_ui_preview_slider_state(gui, "Slider: hover", "slider_hover", &value_mid, .Hot)
	app_ui_preview_slider_state(gui, "Slider: active", "slider_active", &value_high, .Active)

	uifw.gui_spacer(gui, gui.style.spacing_2)
	number_value := f32(42)
	_ = uifw.gui_number_drag_f32(gui, "Number Drag: 42", "number", &number_value, 1, 0, 100)
	app_ui_preview_drag_state(gui, "Number Drag: hover", "number_hover", .Hot)
	app_ui_preview_drag_state(gui, "Number Drag: active", "number_active", .Active)

	uifw.gui_spacer(gui, gui.style.spacing_2)
	selector_options := [?]string{"Linear", "Nearest", "Lanczos"}
	selector_index := 1
	_ = uifw.gui_selector(gui, "Selector: Nearest", "selector", &selector_index, selector_options[:])
	open := true
	closed := false
	_ = uifw.gui_collapsible_begin(gui, "Collapsible: open", "collapsible_open", &open)
	_ = uifw.gui_collapsible_begin(gui, "Collapsible: closed", "collapsible_closed", &closed)
	uifw.gui_layout_end(gui)
}

app_ui_theme_preview_text_palette :: proc(gui: ^uifw.Gui_Context, bounds: uifw.Rect) {
	uifw.gui_layout_begin(gui, bounds, .Column, gui.style.spacing, gui.style.row_height)
	uifw.gui_heading(gui, "Text")
	uifw.gui_label(gui, "Label row")
	right_text := uifw.gui_next_rect(gui)
	uifw.gui_text_aligned(gui, right_text, "Left", gui.style.text_muted, .Left)
	uifw.gui_text_centered(gui, right_text, "Center", gui.style.text)
	uifw.gui_text_right(gui, right_text, "Right", gui.style.accent)
	uifw.gui_text_block(gui, "Wrapped text block shows the baseline rhythm, padding, and legibility when copy runs longer than a single row.", bounds.w - 4, gui.style.text)
	clip_rect := uifw.gui_next_rect(gui)
	uifw.gui_box(gui, clip_rect, {
		fill = gui.style.control,
		border = gui.style.panel_border,
		radius = gui.style.radius_control,
		border_width = gui.style.border_width,
	})
	uifw.gui_text_clipped(gui, uifw.gui_inset(clip_rect, 8), {clip_rect.x + 14, clip_rect.y + 6}, "Clipped text with a very long label that should stay inside its control", gui.style.text)

	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "Palette")
	app_ui_preview_swatch(gui, "Panel", gui.style.panel)
	app_ui_preview_swatch(gui, "Border", gui.style.panel_border)
	app_ui_preview_swatch(gui, "Control", gui.style.control)
	app_ui_preview_swatch(gui, "Hot", gui.style.control_hot)
	app_ui_preview_swatch(gui, "Active", gui.style.control_active)
	app_ui_preview_swatch(gui, "Accent", gui.style.accent)
	app_ui_preview_swatch(gui, "Text", gui.style.text)
	uifw.gui_layout_end(gui)
}

app_ui_theme_preview_media_layout :: proc(gui: ^uifw.Gui_Context, bounds: uifw.Rect) {
	uifw.gui_layout_begin(gui, bounds, .Column, gui.style.spacing, gui.style.row_height)
	uifw.gui_heading(gui, "Effects")
	effects := uifw.gui_next_rect(gui, height = 74)
	gradient := uifw.gui_inset_edges(effects, {left = 0, top = 2, right = effects.w * 0.52, bottom = 2})
	uifw.gui_box(gui, gradient, {
		fill = gui.style.accent,
		fill_to = uifw.gui_darken(gui.style.accent, 0.45),
		border = gui.style.panel_border,
		radius = gui.style.radius_control,
		border_width = gui.style.border_width,
		shadow_color = gui.style.shadow_color,
		shadow_offset = {0, 5},
		shadow_blur = 10,
		gradient = true,
	})
	uifw.gui_text_centered(gui, gradient, "Gradient", gui.style.text)
	ghost := uifw.gui_translate(uifw.gui_scale_from_center(gradient, 0.78), {effects.w * 0.56, 0})
	uifw.gui_box(gui, ghost, {
		fill = gui.style.danger,
		border = gui.style.panel_border,
		radius = gui.style.radius_control,
		border_width = gui.style.border_width,
		opacity = 0.62,
	})
	uifw.gui_text_centered(gui, ghost, "Opacity", gui.style.text)
	blend_row := uifw.gui_next_rect(gui, height = 42)
	blend_cells: [3]uifw.Rect
	uifw.gui_distribute_equal(blend_cells[:], blend_row, .Row, 8, .Start)
	blend_modes := [?]uifw.Gui_Blend_Mode{.Add, .Multiply, .Screen}
	blend_labels := [?]string{"Add", "Multiply", "Screen"}
	for cell, i in blend_cells {
		uifw.gui_box(gui, cell, {
			fill = i == 0 ? gui.style.accent : (i == 1 ? gui.style.danger : gui.style.text_muted),
			border = gui.style.panel_border,
			radius = gui.style.radius_control,
			border_width = gui.style.border_width,
			opacity = 0.72,
			blend = blend_modes[i],
		})
		uifw.gui_text_centered(gui, cell, blend_labels[i], gui.style.text)
	}

	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "Images")
	image_grid_bounds := uifw.gui_next_rect(gui, height = 188)
	image_grid := uifw.gui_grid_begin(gui, image_grid_bounds, 3, 8)
	app_ui_preview_image_sample(gui, uifw.gui_grid_next(&image_grid, 90), "Normal", {1, 1, 1, 1}, {0, 0, 1, 1}, {brightness = 1, contrast = 1}, .Alpha)
	app_ui_preview_image_sample(gui, uifw.gui_grid_next(&image_grid, 90), "Tint", gui.style.accent, {0, 0, 1, 1}, {brightness = 1.15, contrast = 1}, .Alpha)
	app_ui_preview_image_sample(gui, uifw.gui_grid_next(&image_grid, 90), "Crop", {1, 1, 1, 1}, {0, 0, 0.55, 0.55}, {brightness = 1, contrast = 1}, .Alpha)
	app_ui_preview_image_sample(gui, uifw.gui_grid_next(&image_grid, 90), "Bright", {1, 1, 1, 1}, {0, 0, 1, 1}, {brightness = 1.45, contrast = 1.05}, .Alpha)
	app_ui_preview_image_sample(gui, uifw.gui_grid_next(&image_grid, 90), "Gray", {1, 1, 1, 1}, {0, 0, 1, 1}, {brightness = 1, contrast = 1.1, grayscale = 1}, .Alpha)
	app_ui_preview_image_sample(gui, uifw.gui_grid_next(&image_grid, 90), "Blur", {1, 1, 1, 1}, {0, 0, 1, 1}, {brightness = 1, contrast = 1, blur = 0.014}, .Alpha)
	uifw.gui_spacer(gui, gui.style.spacing_2)
	filter_row := uifw.gui_next_rect(gui, height = 62)
	filter_cells: [3]uifw.Rect
	uifw.gui_distribute_equal(filter_cells[:], filter_row, .Row, 8, .Start)
	app_ui_preview_image_sample(gui, filter_cells[0], "Contrast", {1, 1, 1, 1}, {0, 0, 1, 1}, {brightness = 0.95, contrast = 1.8}, .Alpha)
	app_ui_preview_image_sample(gui, filter_cells[1], "Multiply", gui.style.accent, {0, 0, 1, 1}, {brightness = 1.2, contrast = 1.2}, .Multiply)
	app_ui_preview_image_sample(gui, filter_cells[2], "Screen", gui.style.danger, {0, 0, 1, 1}, {brightness = 1.05, contrast = 1}, .Screen)

	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "Geometry")
	geometry := uifw.gui_next_rect(gui, height = 70)
	media := uifw.gui_inset_edges(geometry, {left = 0, top = 2, right = geometry.w * 0.66, bottom = 2})
	uifw.gui_image_filtered(gui, media, uifw.Gui_Image_Id(engine.UI_EXAMPLE_SCREENSHOT_TEXTURE_ID), {1, 1, 1, 1}, {brightness = 1.08, contrast = 1.2, grayscale = 0.25, blur = 0.0025})
	uifw.gui_text_centered(gui, media, "Image", gui.style.text)
	ellipse := uifw.Rect{geometry.x + geometry.w * 0.40, geometry.y + 8, geometry.w * 0.20, 46}
	uifw.gui_ellipse(gui, ellipse, uifw.gui_apply_opacity(gui.style.accent, 0.35))
	uifw.gui_ellipse_stroke(gui, ellipse, gui.style.accent, 2)
	line_start := uifw.Vec2{geometry.x + geometry.w * 0.68, geometry.y + 12}
	line_end := uifw.Vec2{geometry.x + geometry.w - 8, geometry.y + 58}
	uifw.gui_line(gui, line_start, line_end, gui.style.danger, 4)
	uifw.gui_line(gui, {line_start.x, line_end.y}, {line_end.x, line_start.y}, gui.style.text_muted, 2)
	rotated := uifw.Rect{geometry.x + geometry.w * 0.58, geometry.y + 28, 34, 22}
	uifw.gui_rotated_rect(gui, rotated, 0.45, uifw.gui_apply_opacity(gui.style.text, 0.42))

	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_heading(gui, "Layout")
	breakpoint := uifw.gui_breakpoint(bounds.w)
	columns := uifw.gui_responsive_columns(bounds.w, 96, 4, 8)
	uifw.gui_label(gui, fmt.tprintf("Breakpoint: %v / columns: %d", breakpoint, columns))
	grid_bounds := uifw.gui_next_rect(gui, height = 124)
	grid := uifw.gui_grid_begin(gui, grid_bounds, columns, 8)
	for i in 0 ..< 6 {
		cell := uifw.gui_grid_next(&grid, 58)
		uifw.gui_box(gui, cell, {
			fill = gui.style.control,
			border = gui.style.panel_border,
			radius = gui.style.radius_control,
			border_width = gui.style.border_width,
		})
		uifw.gui_text_centered(gui, cell, fmt.tprintf("%d", i + 1), gui.style.text)
	}
	distributed_bounds := uifw.gui_next_rect(gui, height = 38)
	distributed: [3]uifw.Rect
	uifw.gui_distribute_equal(distributed[:], distributed_bounds, .Row, 8, .Space_Between)
	for rect, i in distributed {
		uifw.gui_box(gui, rect, {
			fill = uifw.gui_apply_opacity(gui.style.accent, 0.18 + f32(i) * 0.10),
			border = gui.style.accent,
			radius = gui.style.radius_control,
			border_width = gui.style.border_width,
		})
	}
	anchor_demo := uifw.gui_next_rect(gui, height = 70)
	uifw.gui_round_stroke(gui, anchor_demo, gui.style.radius_control, gui.style.panel_border, gui.style.border_width)
	anchored := uifw.gui_anchor_rect(anchor_demo, {left = 1, top = 0.5, right = 1, bottom = 0.5}, {left = 0, top = 0, right = 10, bottom = 0}, {96, 40})
	anchored.x -= anchored.w
	anchored.y -= anchored.h * 0.5
	uifw.gui_box(gui, anchored, {
		fill = gui.style.control_active,
		border = gui.style.accent,
		radius = gui.style.radius_control,
		border_width = gui.style.border_width,
	})
	uifw.gui_text_centered(gui, anchored, "Anchor", gui.style.text)
	uifw.gui_layout_end(gui)
}

app_ui_preview_image_sample :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, label: string, tint: uifw.Color, uv: uifw.Rect, filter: uifw.Gui_Image_Filter, blend: uifw.Gui_Blend_Mode) {
	uifw.gui_box(gui, rect, {
		fill = gui.style.control,
		border = gui.style.panel_border,
		radius = gui.style.radius_control,
		border_width = gui.style.border_width,
	})
	label_height := f32(28)
	image := uifw.gui_inset_edges(rect, {left = 5, top = 5, right = 5, bottom = label_height + 5})
	uifw.gui_image_uv_filtered_blend(gui, image, uifw.Gui_Image_Id(engine.UI_EXAMPLE_SCREENSHOT_TEXTURE_ID), tint, uv, filter, blend)
	uifw.gui_text_centered(gui, {rect.x, rect.y + rect.h - label_height - 2, rect.w, label_height}, label, gui.style.text)
}

app_ui_theme_preview_advanced :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, bounds: uifw.Rect) {
	uifw.gui_layout_begin(gui, bounds, .Column, gui.style.spacing, gui.style.row_height)
	uifw.gui_heading(gui, "Advanced")

	_ = uifw.gui_color_picker_hsv(gui, "HSV Picker", "hsv_picker", &ui.preview_hsv)
	uifw.gui_spacer(gui, 4)
	_ = uifw.gui_area_slider_f32(gui, "2D Area", "area", &ui.preview_area, {0, 0}, {1, 1})

	uifw.gui_spacer(gui, 4)
	_ = uifw.gui_checkbox(gui, "Checkbox", "checkbox", &ui.preview_checkbox)
	_ = uifw.gui_switch(gui, "Switch", "switch", &ui.preview_switch)

	radio_options := [?]string{"Alpha", "Beta", "Gamma"}
	_ = uifw.gui_radio_group(gui, "Radio", "radio", &ui.preview_radio_index, radio_options[:])

	combo_options := [?]string{"Linear", "Nearest", "Lanczos", "Cubic", "Mitchell", "Catmull-Rom"}
	_ = uifw.gui_combobox(gui, "Searchable Combo", "combo", &ui.preview_combo_index, combo_options[:], ui.preview_combo_query[:])

	ui.preview_progress += gui.input.delta_time * 0.12
	if ui.preview_progress > 1 {
		ui.preview_progress -= 1
	}
	uifw.gui_circular_progress(gui, "Circular progress", ui.preview_progress)
	uifw.gui_layout_end(gui)
}

Preview_State :: enum {
	Normal,
	Hot,
	Active,
	Focused,
}

app_ui_preview_button_state :: proc(gui: ^uifw.Gui_Context, label, key: string, state: Preview_State) {
	id := uifw.gui_make_id(gui, key)
	app_ui_preview_apply_state(gui, id, state)
	rect := uifw.gui_next_rect(gui)
	_ = uifw.gui_button_at(gui, id, rect, label, true)
}

app_ui_preview_card_state :: proc(gui: ^uifw.Gui_Context, title, key, subtitle: string, state: Preview_State) {
	id := uifw.gui_make_id(gui, key)
	app_ui_preview_apply_state(gui, id, state)
	rect := uifw.gui_next_rect(gui, height = 96)
	_ = uifw.gui_card_button(gui, rect, title, key, subtitle, true)
}

app_ui_preview_slider_state :: proc(gui: ^uifw.Gui_Context, label, key: string, value: ^f32, state: Preview_State) {
	id := uifw.gui_make_id(gui, key)
	app_ui_preview_apply_state(gui, id, state)
	_ = uifw.gui_slider_f32(gui, label, key, value, 0, 1)
}

app_ui_preview_drag_state :: proc(gui: ^uifw.Gui_Context, label, key: string, state: Preview_State) {
	id := uifw.gui_make_id(gui, key)
	app_ui_preview_apply_state(gui, id, state)
	value := f32(64)
	_ = uifw.gui_number_drag_f32(gui, label, key, &value, 1, 0, 100)
}

app_ui_preview_apply_state :: proc(gui: ^uifw.Gui_Context, id: uifw.Gui_Id, state: Preview_State) {
	#partial switch state {
	case .Hot:
		gui.hot = id
	case .Active:
		gui.active = id
	case .Focused:
		gui.focused = id
	}
}

app_ui_preview_swatch :: proc(gui: ^uifw.Gui_Context, label: string, color: uifw.Color) {
	row := uifw.gui_next_rect(gui)
	size := min(row.h, 34)
	swatch := uifw.Rect{row.x, row.y + (row.h - size) * 0.5, size, size}
	uifw.gui_rect(gui, swatch, color)
	uifw.gui_stroke(gui, swatch, gui.style.panel_border)
	uifw.gui_text(gui, {row.x + size + 12, row.y + 6}, label, gui.style.text)
}

app_ui_options_content_height :: proc(gui: ^uifw.Gui_Context, settings_dirty: bool) -> f32 {
	item_count := 5 + 14 + 5
	if settings_dirty {
		item_count += 1
	}
	heading_count := 5
	control_count := 14
	label_count := settings_dirty ? 1 : 0
	spacer_height := f32(5) * gui.style.spacing_2
	slider_extra := max(uifw.gui_slider_height(gui) - gui.style.row_height, 0) * 3
	return f32(heading_count) * gui.style.heading_line_height +
	       f32(control_count + label_count) * gui.style.row_height +
	       spacer_height +
	       f32(item_count) * gui.style.spacing +
	       slider_extra
}

centered_panel_styled :: proc(width, height: f32, window_width, window_height: i32, style: ^uifw.Gui_Style) -> uifw.Rect {
	margin := max(style.margin, f32(16))
	w := min(width, max(f32(window_width) - margin * 2, margin))
	h := min(height, max(f32(window_height) - margin * 2, margin))
	x := (f32(window_width) - w) * 0.5
	y := (f32(window_height) - h) * 0.5
	if x < margin do x = margin
	if y < margin do y = margin
	return {x, y, w, h}
}

centered_panel :: proc(width, height: f32, window_width, window_height: i32) -> uifw.Rect {
	margin := f32(16)
	w := min(width, max(f32(window_width) - margin * 2, margin))
	h := min(height, max(f32(window_height) - margin * 2, margin))
	x := (f32(window_width) - w) * 0.5
	y := (f32(window_height) - h) * 0.5
	if x < 16 do x = 16
	if y < 16 do y = 16
	return {x, y, w, h}
}

option_index :: proc(value: string, options: []string, fallback: int) -> int {
	for option, i in options {
		if option == value {
			return i
		}
	}
	return fallback
}
