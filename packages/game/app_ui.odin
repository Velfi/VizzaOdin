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

SIMULATION_BAR_HEIGHT :: f32(44)
SIMULATION_BAR_BASE_ROW_HEIGHT :: f32(44)
MAIN_MENU_PREVIEW_SLOT_CAP :: 16
MAIN_MENU_TEXT_BUTTON_SCALE_MULTIPLIER :: f32(2.5)
MAIN_MENU_TEXT_BUTTON_FOCUS_BORDER_WIDTH :: f32(5)
MAIN_MENU_SIM_BUTTON_GRADIENT_MIDPOINT :: f32(0.66)
MAIN_MENU_DISPLAY_FONT_BASELINE_RATIO :: f32(0.78)
MAIN_MENU_TITLE_SLOT :: 0
MAIN_MENU_SIMULATION_SLOT_OFFSET :: 1

Main_Menu_Preview_Slot :: struct {
	mode: App_Mode,
	rect: uifw.Rect,
	clip_rect: uifw.Rect,
	fallback_color: uifw.Color,
}

Simulation_Shell_State :: struct {
	show_ui: bool,
	controls_visible: bool,
	force_hidden: bool,
	idle_seconds: f32,
	mouse_pressed: bool,
	mouse_button: u32,
	camera_pan_active: bool,
}

// The render thread resolves one prioritized interaction context, then routes
// each input channel to its owner. Separate channel owners preserve useful
// concurrency (for example, keyboard WASD camera control while a button has
// focus) without allowing navigation, pointer gestures, or controller camera
// input to leak through the focused UI.
App_Input_Context :: enum u8 {
	Global_Fallback,
	Simulation_Canvas,
	Focused_Ui,
	Value_Edit,
	Modal,
}

App_Input_Context_Route :: struct {
	active_context: App_Input_Context,
	pointer_owner: App_Input_Context,
	navigation_owner: App_Input_Context,
	keyboard_camera_owner: App_Input_Context,
	controller_camera_owner: App_Input_Context,
	global_shortcut_owner: App_Input_Context,
	pointer_over_ui: bool,
	controller_ui_claimed: bool,
}

Video_Recording_Ui_State :: enum {
	Idle,
	Choosing_Path,
	Restoring_Fullscreen,
	Recording,
	Failed,
}

Mode_Transition_Phase :: enum u8 {
	Idle,
	Fade_Out,
	Waiting_For_Target,
	Fade_In,
}

App_Ui_State :: struct {
	mode: App_Mode,
	previous_mode: App_Mode,
	mode_transition_phase: Mode_Transition_Phase,
	mode_transition_target: App_Mode,
	mode_transition_elapsed: f32,
	settings: App_Settings,
	last_stats: Render_To_Ui_Message,
	menu_position_index: int,
	texture_filtering_index: int,
	controller_face_layout_index: int,
	controller_menu_layout_index: int,
	controller_shoulder_layout_index: int,
	keyboard_shortcut_profile_index: int,
	keyboard_binding_notice: [128]u8,
	settings_dirty: bool,
	simulation_shell: Simulation_Shell_State,
	frame_actions: Input_Action_Frame,
	input_route: App_Input_Context_Route,
	device_notice: [128]u8,
	device_notice_seconds: f32,
	device_notice_disconnected: bool,
	slime_controller: Slime_Controller_Ui_State,
	simulation_controllers: [SIMULATION_CONTROLLER_STATE_COUNT]Simulation_Controller_Ui_State,
	video_recording_state: Video_Recording_Ui_State,
	video_recording_status: [MAX_ERROR_TEXT]u8,
	main_menu_selected: int,
	main_menu_focus_slot: int,
	main_menu_scroll: f32,
	main_menu_live_preview_visible: bool,
	main_menu_live_preview_mode: App_Mode,
	main_menu_live_preview_rect: uifw.Rect,
	main_menu_preview_slots: [MAIN_MENU_PREVIEW_SLOT_CAP]Main_Menu_Preview_Slot,
	main_menu_preview_slot_count: int,
	main_menu_palette_randomize_requested: bool,
	main_menu_focus_navigation_active: bool,
	options_section_index: int,
	options_scroll: f32,
	how_to_play_scroll: f32,
	controls_help_open: bool,
	controls_help_open_frame: u64,
	controls_help_invoker_focus: uifw.Gui_Id,
	controls_help_modal_scroll: f32,
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
	"Voronoi",
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
	"Nearest-site regions",
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
	"Drifting Voronoi sites split the canvas into nearest-region fields with color-map controls.",
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
	"geometry",
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
	{"voronoi", "regions", "motion"},
	{"wave", "moire", "image"},
	{"field", "vectors", "analysis"},
	{"particles", "density", "motion"},
}

How_To_Play_Section :: struct {
	title: string,
	body: string,
}

HOW_TO_PLAY_INTRO :: "Inputs are routed to the most specific active context: modal, engaged editor, focused UI, simulation canvas, then global shortcuts. The same keyboard and controller can be used interchangeably."
CONTROLS_HELP_KEYBOARD_QUICK_REFERENCE :: "F1 closes help  •  Tab / Shift+Tab moves focus  •  Enter activates or edits  •  Escape goes back or cancels  •  Slash toggles UI  •  Space pauses"
CONTROLS_HELP_KEYBOARD_LETTER_QUICK_REFERENCE :: "H closes help  •  Tab / Shift+Tab moves focus  •  Enter activates or edits  •  Escape goes back or cancels  •  U toggles UI  •  P pauses"
CONTROLS_HELP_CONTROLLER_QUICK_REFERENCE :: "Guide or Back closes help  •  D-pad or left stick moves focus  •  Accept activates or edits  •  Right shoulder next / Left previous  •  Start pauses"
CONTROLS_HELP_CONTROLLER_VIEW_PAUSE_QUICK_REFERENCE :: "Guide or Back closes help  •  D-pad or left stick moves focus  •  Accept activates or edits  •  Right shoulder next / Left previous  •  View pauses  •  Start toggles UI"
CONTROLS_HELP_CONTROLLER_LEFT_NEXT_QUICK_REFERENCE :: "Guide or Back closes help  •  D-pad or left stick moves focus  •  Accept activates or edits  •  Left shoulder next / Right previous  •  Start pauses"
CONTROLS_HELP_CONTROLLER_LEFT_NEXT_VIEW_PAUSE_QUICK_REFERENCE :: "Guide or Back closes help  •  D-pad or left stick moves focus  •  Accept activates or edits  •  Left shoulder next / Right previous  •  View pauses  •  Start toggles UI"

app_ui_controls_help_quick_reference :: proc(device: uifw.Input_Device_Kind, keyboard_profile := "Standard") -> string {
	if device == .Controller {
		return CONTROLS_HELP_CONTROLLER_QUICK_REFERENCE
	}
	return keyboard_profile == "Letter Shortcuts" ? CONTROLS_HELP_KEYBOARD_LETTER_QUICK_REFERENCE : CONTROLS_HELP_KEYBOARD_QUICK_REFERENCE
}

app_ui_controls_help_quick_reference_for_settings :: proc(device: uifw.Input_Device_Kind, settings: App_Settings) -> string {
	if device == .Controller {
		view_pauses := settings.controller_menu_layout == "View Pauses"
		left_next := settings.controller_shoulder_layout == "Left Next"
		if left_next {return view_pauses ? CONTROLS_HELP_CONTROLLER_LEFT_NEXT_VIEW_PAUSE_QUICK_REFERENCE : CONTROLS_HELP_CONTROLLER_LEFT_NEXT_QUICK_REFERENCE}
		return view_pauses ? CONTROLS_HELP_CONTROLLER_VIEW_PAUSE_QUICK_REFERENCE : CONTROLS_HELP_CONTROLLER_QUICK_REFERENCE
	}
	if settings.keyboard_shortcut_profile != "Custom" {
		return app_ui_controls_help_quick_reference(device, settings.keyboard_shortcut_profile)
	}
	return fmt.tprintf(
		"%s closes help  •  Tab / Shift+Tab moves focus  •  Enter activates or edits  •  Escape goes back or cancels  •  %s toggles UI  •  %s pauses",
		keyboard_shortcut_key_name(settings.keyboard_help_binding),
		keyboard_shortcut_key_name(settings.keyboard_toggle_ui_binding),
		keyboard_shortcut_key_name(settings.keyboard_pause_binding),
	)
}

HOW_TO_PLAY_SECTIONS := [?]How_To_Play_Section {
	{
		title = "Keyboard and mouse",
		body = "Left/right drag performs primary/secondary simulation interaction. Middle-drag or Space + left-drag pans, including on laptops. Wheel or two-finger scroll zooms toward the pointer; horizontal scroll or Shift + vertical scroll pans. W A S D or canvas-owned arrows pan, Q / E zoom, and C resets. UI under the pointer owns scrolling, and engaged editors block camera keys. Tab moves focus, Enter activates or edits, and Escape cancels. Standalone Space keeps its configured shortcut.",
	},
	{
		title = "Controller",
		body = "The D-pad navigates UI and its Up/Down directions zoom the canvas when no UI context owns them. The left stick pans the canvas or navigates focused UI, and the right stick moves the virtual cursor. Accept activates or engages; Back closes one scope or cancels an edit. Guide opens or closes this reference globally; the simulation bar's Help button is the universal fallback. The shoulders move next/previous focus according to the selected handedness layout, North remains a Toggle UI fallback, and clicking the left stick resets the camera. Start/View map to Pause and Toggle UI according to the selected menu-button layout. The triggers provide primary/secondary canvas interaction where supported. Options > Input adjusts bindings, face/menu/shoulder layouts, deadzone, cursor speed, and repeat timing. Options > Camera independently adjusts controller sensitivity and Y inversion.",
	},
	{
		title = "Focus and editing",
		body = "Buttons activate with one press. Sliders, selectors, text fields, and spatial editors first engage, then Accept commits and Back cancels. Focused items inside scroll panels are revealed automatically. The Control Deck command strip always shows the actions available in its current browse, panel, or editing phase.",
	},
	{
		title = "Device handoff",
		body = "Keyboard, mouse, and controller input remain eligible regardless of which prompt style is visible. If the actively used controller disconnects during a simulation, Vizza reveals the controls, pauses safely, and keeps logical focus and the current edit so you can continue on the keyboard.",
	},
}

MENU_POSITION_OPTIONS := [?]string{"left", "middle", "right"}
TEXTURE_FILTERING_OPTIONS := [?]string{"Linear", "Nearest", "Lanczos"}
OPTIONS_SECTION_LABELS := [?]string{"Display", "Window", "Interface", "Input", "Camera"}
OPTIONS_SECTION_KEYS := [?]string{"display", "window", "interface", "input", "camera"}

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
	slime_controller_ui_init(&ui.slime_controller)
	for &state in ui.simulation_controllers {
		simulation_controller_ui_init(&state)
	}
	ui.main_menu_selected = 0 // Slime Mold
	ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(ui.main_menu_selected)
	ui.menu_position_index = option_index(settings.menu_position, MENU_POSITION_OPTIONS[:], 1)
	ui.texture_filtering_index = option_index(settings.texture_filtering, TEXTURE_FILTERING_OPTIONS[:], 0)
	ui.controller_face_layout_index = option_index(settings.controller_face_layout, CONTROLLER_FACE_LAYOUT_OPTIONS[:], 0)
	ui.controller_menu_layout_index = option_index(settings.controller_menu_layout, CONTROLLER_MENU_LAYOUT_OPTIONS[:], 0)
	ui.controller_shoulder_layout_index = option_index(settings.controller_shoulder_layout, CONTROLLER_SHOULDER_LAYOUT_OPTIONS[:], 0)
	ui.keyboard_shortcut_profile_index = option_index(settings.keyboard_shortcut_profile, KEYBOARD_SHORTCUT_PROFILE_OPTIONS[:], 0)
	ui.options_section_index = 0
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

app_ui_draw :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, worker: ^Product_Context) {
	app_ui_mode_transition_update(ui, max(gui.input.delta_time, 0))
	app_ui_handle_controller_disconnect(ui, gui, sim, particle_life)
	app_ui_update_device_notice(ui, gui)

	transitioning := app_ui_mode_transition_active(ui)
	saved_input := gui.input
	saved_actions := ui.frame_actions
	if transitioning {
		app_ui_mode_transition_suppress_input(&gui.input)
		ui.frame_actions = {}
	}
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
	if ui.controls_help_open && app_ui_mode_is_simulation(ui.mode) {
		app_ui_draw_controls_help_modal(ui, gui)
	}
	app_ui_draw_device_notice(ui, gui)
	app_ui_draw_virtual_cursor(ui, gui)
	if transitioning {
		gui.input = saved_input
		ui.frame_actions = saved_actions
	}
	app_ui_draw_mode_transition_overlay(ui, gui)
}

APP_UI_MODE_FADE_OUT_SECONDS :: f32(0.28)
APP_UI_MODE_FADE_IN_SECONDS :: f32(0.32)

app_ui_mode_transition_active :: proc(ui: ^App_Ui_State) -> bool {
	return ui != nil && ui.mode_transition_phase != .Idle
}

app_ui_mode_transition_ease :: proc(t: f32) -> f32 {
	clamped := min(max(t, 0), 1)
	return clamped * clamped * (3 - 2 * clamped)
}

app_ui_mode_transition_opacity :: proc(ui: ^App_Ui_State) -> f32 {
	if ui == nil {
		return 0
	}
	#partial switch ui.mode_transition_phase {
	case .Fade_Out:
		return app_ui_mode_transition_ease(ui.mode_transition_elapsed / APP_UI_MODE_FADE_OUT_SECONDS)
	case .Waiting_For_Target:
		return 1
	case .Fade_In:
		return 1 - app_ui_mode_transition_ease(ui.mode_transition_elapsed / APP_UI_MODE_FADE_IN_SECONDS)
	case:
		return 0
	}
}

app_ui_mode_transition_request :: proc(ui: ^App_Ui_State, target: App_Mode) {
	if ui == nil || ui.mode_transition_phase != .Idle {
		return
	}
	ui.mode_transition_phase = .Fade_Out
	ui.mode_transition_target = target
	ui.mode_transition_elapsed = 0
}

app_ui_mode_transition_cancel :: proc(ui: ^App_Ui_State) {
	if ui == nil {
		return
	}
	ui.mode_transition_phase = .Idle
	ui.mode_transition_target = ui.mode
	ui.mode_transition_elapsed = 0
}

app_ui_mode_transition_update :: proc(ui: ^App_Ui_State, delta_time: f32) {
	if ui == nil {
		return
	}
	dt := max(delta_time, 0)
	#partial switch ui.mode_transition_phase {
	case .Fade_Out:
		ui.mode_transition_elapsed = min(ui.mode_transition_elapsed + dt, APP_UI_MODE_FADE_OUT_SECONDS)
		if ui.mode_transition_elapsed >= APP_UI_MODE_FADE_OUT_SECONDS {
			app_ui_navigate_immediate(ui, ui.mode_transition_target)
			ui.mode_transition_phase = .Waiting_For_Target
			ui.mode_transition_elapsed = 0
		}
	case .Fade_In:
		ui.mode_transition_elapsed = min(ui.mode_transition_elapsed + dt, APP_UI_MODE_FADE_IN_SECONDS)
		if ui.mode_transition_elapsed >= APP_UI_MODE_FADE_IN_SECONDS {
			app_ui_mode_transition_cancel(ui)
		}
	case:
	}
}

app_ui_mode_transition_notify_loaded :: proc(ui: ^App_Ui_State) {
	if ui == nil || ui.mode != ui.mode_transition_target || ui.mode_transition_phase != .Waiting_For_Target {
		return
	}
	ui.mode_transition_phase = .Fade_In
	ui.mode_transition_elapsed = 0
}

app_ui_mode_transition_suppress_input :: proc(input: ^uifw.Input_State) {
	if input == nil {
		return
	}
	input.mouse_down = false
	input.mouse_pressed = false
	input.mouse_released = false
	input.mouse_moved = false
	input.mouse_delta = {}
	input.wheel_delta = 0
	input.nav_x = 0
	input.nav_y = 0
	input.nav_pressed_x = 0
	input.nav_pressed_y = 0
	input.accept = false
	input.accept_pressed = false
	input.back = false
	input.pause = false
	input.toggle_ui = false
	input.focus_next = false
	input.focus_prev = false
	input.primary_down = false
	input.primary_pressed = false
	input.primary_released = false
	input.secondary_down = false
	input.secondary_pressed = false
	input.secondary_released = false
	input.text_input_len = 0
	input.clipboard_paste_len = 0
	input.key_tab = false
	input.key_enter = false
	input.key_escape = false
	input.key_backspace = false
	input.key_delete = false
	input.key_home = false
	input.key_end = false
	input.key_left = false
	input.key_right = false
	input.key_up = false
	input.key_down = false
	input.key_w = false
	input.key_a = false
	input.key_s = false
	input.key_d = false
	input.key_q = false
	input.key_e = false
	input.key_x = false
	input.key_v = false
	input.key_c = false
	input.key_f1 = false
	input.key_slash = false
	input.key_space = false
	input.key_space_down = false
	input.key_space_pressed = false
	input.key_space_released = false
	input.controller_left = {}
	input.controller_right = {}
	input.controller_zoom = 0
}

app_ui_draw_mode_transition_overlay :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	if !app_ui_mode_transition_active(ui) {
		return
	}
	bounds := uifw.Rect{0, 0, f32(max(gui.input.window_width, 0)), f32(max(gui.input.window_height, 0))}
	if bounds.w <= 0 || bounds.h <= 0 {
		return
	}
	uifw.gui_overlay_input_rect(gui, bounds)
	uifw.gui_rect(gui, bounds, {0, 0, 0, app_ui_mode_transition_opacity(ui)})
}

app_ui_handle_controller_disconnect :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation) {
	if !gui.input.controller_disconnected || gui.input.active_device != .Controller || !app_ui_mode_is_simulation(ui.mode) {
		return
	}
	ui.simulation_shell.show_ui = true
	app_ui_set_simulation_chrome_visible(ui, true)
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

APP_UI_DEVICE_NOTICE_SECONDS :: f32(2.75)
APP_UI_DEVICE_NOTICE_FADE_SECONDS :: f32(0.35)

app_ui_update_device_notice :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	if gui.input.controller_connected {
		write_fixed_string(ui.device_notice[:], "Controller connected")
		ui.device_notice_seconds = APP_UI_DEVICE_NOTICE_SECONDS
		ui.device_notice_disconnected = false
	}
	if gui.input.controller_disconnected {
		paused_for_disconnect := gui.input.active_device == .Controller && app_ui_mode_is_simulation(ui.mode)
		message := paused_for_disconnect ? "Controller disconnected - simulation paused" : "Controller disconnected"
		write_fixed_string(ui.device_notice[:], message)
		ui.device_notice_seconds = APP_UI_DEVICE_NOTICE_SECONDS
		ui.device_notice_disconnected = true
	}
	if gui.input.controller_connected || gui.input.controller_disconnected {
		return
	}
	ui.device_notice_seconds = max(ui.device_notice_seconds - max(gui.input.delta_time, 0), 0)
	if ui.device_notice_seconds <= 0 {
		write_fixed_string(ui.device_notice[:], "")
		ui.device_notice_disconnected = false
	}
}

app_ui_draw_device_notice :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	message := fixed_string(ui.device_notice[:])
	if len(message) == 0 || ui.device_notice_seconds <= 0 || gui.input.window_width <= 0 || gui.input.window_height <= 0 {
		return
	}
	alpha := f32(1)
	if ui.device_notice_seconds < APP_UI_DEVICE_NOTICE_FADE_SECONDS {
		alpha = max(ui.device_notice_seconds / APP_UI_DEVICE_NOTICE_FADE_SECONDS, 0)
	}
	width := f32(gui.input.window_width)
	margin := max(gui.style.spacing_3, f32(18))
	padding := max(gui.style.spacing_2, f32(10))
	notice_w := min(max(uifw.gui_text_width(gui, message) + padding * 2.5, f32(220)), max(width - margin * 2, 1))
	notice_h := max(gui.style.row_height, gui.style.body_line_height + padding)
	notice_y := margin
	rect := uifw.Rect{max((width - notice_w) * 0.5, margin), notice_y, notice_w, notice_h}
	accent := gui.style.accent
	if ui.device_notice_disconnected {
		accent = {0.96, 0.56, 0.24, 1}
	}
	fill := uifw.Color{0.055, 0.065, 0.085, 0.94 * alpha}
	border := uifw.Color{accent.r, accent.g, accent.b, 0.82 * alpha}
	text_color := uifw.Color{gui.style.text.r, gui.style.text.g, gui.style.text.b, alpha}
	uifw.gui_shadow(gui, rect, gui.style.radius_control, {0, 5}, 16, {0, 0, 0, 0.42 * alpha})
	uifw.gui_round_rect(gui, rect, gui.style.radius_control, fill)
	uifw.gui_round_stroke(gui, rect, gui.style.radius_control, border, max(gui.style.border_width * 1.5, 1.5))
	uifw.gui_text_aligned(gui, uifw.gui_inset(rect, padding), message, text_color, .Center)
}

app_ui_draw_virtual_cursor :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	controller_gesture := ui != nil &&
		((ui.frame_actions.primary.owner == .Controller && ui.frame_actions.primary.down) ||
		 (ui.frame_actions.secondary.owner == .Controller && ui.frame_actions.secondary.down))
	if gui.input.active_device != .Controller && !controller_gesture {
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

app_ui_draw_remaining_sim :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, kind: Remaining_Sim_Kind, sim: ^Remaining_Sim_State, vk_ctx: ^engine.Vk_Context, worker: ^Product_Context) {
	width := f32(vk_ctx.swapchain_extent.width)
	height := f32(vk_ctx.swapchain_extent.height)
	controller_ui_active := kind == .Slime_Mold || simulation_controller_ui_enabled(ui)
	pause_consumed := false
	controller_pause_pressed := app_ui_take_controller_action(&ui.frame_actions.pause, gui.input.pause, gui.input.active_device)
	if controller_ui_active && controller_pause_pressed {
		app_ui_release_controller_focus(ui)
		app_ui_focus_simulation_bar_pause(gui)
		app_ui_set_simulation_chrome_visible(ui, true)
		pause_consumed = true
	}
	if kind == .Slime_Mold {
		pause_consumed = slime_controller_ui_update_input(ui, gui, sim, width, height) || pause_consumed
	} else {
		pause_consumed = simulation_controller_ui_update_input(ui, gui) || pause_consumed
	}
	if gui.input.pause && !pause_consumed {
		sim.paused = !sim.paused
	}
	if kind != .Vectors && kind != .Moire && kind != .Primordial && kind != .Pellets && kind != .Flow_Field && kind != .Slime_Mold && kind != .Voronoi_CA {
		remaining_sim_draw(sim, gui, kind, width, height)
	}
	if ui.simulation_shell.controls_visible {
		app_ui_draw_simulation_bar(ui, gui, app_mode_from_remaining_sim_kind(kind), nil, nil, sim, sim.paused, false, remaining_sim_name(kind), vk_ctx, width, worker)
	}
	if kind == .Slime_Mold {
		slime_controller_ui_draw(ui, gui, sim, width, height, worker)
	} else {
		simulation_controller_ui_draw(ui, gui, remaining = sim, width = width, height = height, worker = worker)
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

app_ui_draw_options :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, vk_ctx: ^engine.Vk_Context, worker: ^Product_Context) {
	window_w := f32(vk_ctx.swapchain_extent.width)
	window_h := f32(vk_ctx.swapchain_extent.height)
	panel_w := min(max(window_w * 0.72, gui.style.body_char_width * 54), max(window_w - gui.style.margin * 2, 1))
	panel_h := min(max(window_h * 0.86, gui.style.row_height * 12), max(window_h - gui.style.margin * 2, 1))
	panel := centered_panel_styled(panel_w, panel_h, i32(vk_ctx.swapchain_extent.width), i32(vk_ctx.swapchain_extent.height), &gui.style)
	uifw.gui_panel_begin(gui, panel)
	inner_h := max(panel.h - gui.style.panel_padding * 2, 0)
	content_w := max(panel.w - gui.style.panel_padding * 2, 1)
	footer_h := app_ui_options_footer_height(gui, content_w)
	section_rail_h := app_ui_options_section_rail_height(gui, content_w)
	viewport_h := max(inner_h - gui.style.heading_line_height - section_rail_h - footer_h - gui.style.spacing * 3, gui.style.row_height)
	ui.options_section_index = max(min(ui.options_section_index, len(OPTIONS_SECTION_LABELS) - 1), 0)
	uifw.gui_heading(gui, "Options")
	if app_ui_draw_options_section_rail(gui, content_w, &ui.options_section_index) {
		ui.options_scroll = 0
	}
	viewport := uifw.gui_next_rect(gui, height = viewport_h)
	content_height := app_ui_options_content_height(gui, ui.options_section_index)
	uifw.gui_push_id(gui, "settings")
	uifw.gui_scroll_begin(gui, viewport, content_height, &ui.options_scroll)
	app_ui_draw_options_active_section(ui, gui, worker)
	uifw.gui_scroll_end(gui)
	footer := uifw.gui_next_rect(gui, height = footer_h)
	app_ui_draw_options_footer(ui, gui, footer, worker)
	uifw.gui_pop_id(gui)
	uifw.gui_panel_end(gui)
}

app_ui_how_to_play_content_height :: proc(gui: ^uifw.Gui_Context, width: f32) -> f32 {
	wrap_width := max(width - gui.style.spacing_1, gui.style.body_char_width)
	height := f32(uifw.gui_wrap_line_count(gui, HOW_TO_PLAY_INTRO, wrap_width)) * gui.style.body_line_height
	for section in HOW_TO_PLAY_SECTIONS {
		height += gui.style.heading_line_height
		height += f32(uifw.gui_wrap_line_count(gui, section.body, wrap_width)) * gui.style.body_line_height
		height += gui.style.spacing_2
	}
	// Each layout item also advances by the scroll column's normal gap.
	height += gui.style.spacing * f32(1 + len(HOW_TO_PLAY_SECTIONS) * 3)
	return height
}

app_ui_controls_help_modal_content_height :: proc(gui: ^uifw.Gui_Context, width: f32, settings: App_Settings) -> f32 {
	quick_reference := app_ui_controls_help_quick_reference_for_settings(gui.input.active_device, settings)
	wrap_width := max(width - gui.style.spacing_1, gui.style.body_char_width)
	return app_ui_how_to_play_content_height(gui, width) +
		gui.style.heading_line_height +
		f32(uifw.gui_wrap_line_count(gui, quick_reference, wrap_width)) * gui.style.body_line_height +
		gui.style.spacing * 3 + gui.style.spacing_2
}

app_ui_draw_how_to_play :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	window_w := f32(max(gui.input.window_width, 1))
	window_h := f32(max(gui.input.window_height, 1))
	margin := max(gui.style.margin, f32(18))
	panel_w := min(max(window_w * 0.74, gui.style.body_char_width * 44), max(window_w - margin * 2, 1))
	panel_h := min(max(window_h * 0.86, gui.style.row_height * 9), max(window_h - margin * 2, 1))
	panel := uifw.Rect{max((window_w - panel_w) * 0.5, margin), max((window_h - panel_h) * 0.5, margin), panel_w, panel_h}
	back_id := uifw.gui_make_id(gui, "back")
	if gui.input.active_device == .Controller {
		gui.focused = back_id
	}

	if gui.input.back {
		app_ui_navigate(ui, .Main_Menu)
	}

	uifw.gui_panel_begin(gui, panel)
	inner_h := max(panel.h - gui.style.panel_padding * 2, 1)
	footer_h := gui.style.row_height
	viewport_h := max(inner_h - gui.style.heading_line_height - footer_h - gui.style.spacing * 2, gui.style.row_height)
	uifw.gui_heading(gui, "Controls")
	viewport := uifw.gui_next_rect(gui, height = viewport_h)
	content_width := max(viewport.w - gui.style.spacing_2, 1)
	content_height := app_ui_how_to_play_content_height(gui, content_width)
	uifw.gui_scroll_begin(gui, viewport, content_height, &ui.how_to_play_scroll)
	uifw.gui_text_block(gui, HOW_TO_PLAY_INTRO, content_width, gui.style.text)
	uifw.gui_spacer(gui, gui.style.spacing_1)
	for section in HOW_TO_PLAY_SECTIONS {
		uifw.gui_heading(gui, section.title)
		uifw.gui_text_block(gui, section.body, content_width, gui.style.text_muted)
		uifw.gui_spacer(gui, gui.style.spacing_2)
	}
	uifw.gui_scroll_end(gui)
	footer := uifw.gui_next_rect(gui, height = footer_h)
	back_w := uifw.gui_button_content_width(gui, "Back to Menu")
	if uifw.gui_button_at(gui, back_id, {footer.x, footer.y, back_w, footer.h}, "Back to Menu", true) {
		app_ui_navigate(ui, .Main_Menu)
	}
	uifw.gui_panel_end(gui)
}

app_ui_open_controls_help :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	if ui == nil || gui == nil || ui.controls_help_open {
		return
	}
	ui.controls_help_open = true
	ui.controls_help_open_frame = gui.frame_index
	ui.controls_help_invoker_focus = gui.focused
	ui.controls_help_modal_scroll = 0
}

app_ui_close_controls_help :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	if ui == nil {
		return
	}
	ui.controls_help_open = false
	ui.controls_help_modal_scroll = 0
	if gui != nil {
		gui.focused = ui.controls_help_invoker_focus
		uifw.gui_focus_scope_release(gui)
	}
	ui.controls_help_invoker_focus = uifw.GUI_ID_NONE
}

app_ui_draw_controls_help_modal :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	if ui == nil || gui == nil || !ui.controls_help_open {
		return
	}
	window_w := f32(max(gui.input.window_width, 1))
	window_h := f32(max(gui.input.window_height, 1))
	margin := max(gui.style.spacing_2, f32(12))
	panel_w := min(max(window_w * 0.76, gui.style.body_char_width * 40), max(window_w - margin * 2, 1))
	panel_h := min(max(window_h * 0.86, gui.style.row_height * 8), max(window_h - margin * 2, 1))
	panel := uifw.Rect{max((window_w - panel_w) * 0.5, margin), max((window_h - panel_h) * 0.5, margin), panel_w, panel_h}

	uifw.gui_push_id(gui, "controls_help_modal")
	uifw.gui_rect(gui, {0, 0, window_w, window_h}, {0, 0, 0, 0.72})
	uifw.gui_overlay_input_begin(gui, {0, 0, window_w, window_h})
	if gui.frame_index > ui.controls_help_open_frame && (gui.input.back || gui.input.key_f1) {
		app_ui_close_controls_help(ui, gui)
		uifw.gui_overlay_input_cancel(gui)
		uifw.gui_pop_id(gui)
		return
	}
	uifw.gui_spatial_group_begin(gui, "controls_help_focus_scope")
	defer uifw.gui_spatial_group_end(gui)
	uifw.gui_focus_scope_trap_current(gui)
	previous_explicit_activation := gui.controller_explicit_activation
	gui.controller_explicit_activation = previous_explicit_activation || gui.input.active_device == .Controller
	defer gui.controller_explicit_activation = previous_explicit_activation

	uifw.gui_panel_begin(gui, panel)
	header := uifw.gui_next_rect(gui, height = gui.style.row_height)
	close_w := min(uifw.gui_button_content_width(gui, "Close"), header.w * 0.30)
	title_rect := uifw.Rect{header.x, header.y, max(header.w - close_w - gui.style.spacing, 0), header.h}
	close_rect := uifw.Rect{header.x + header.w - close_w, header.y, close_w, header.h}
	uifw.gui_text_clipped(gui, title_rect, {title_rect.x, title_rect.y + max((title_rect.h - gui.style.heading_text_height) * 0.5, 0)}, "Controls", gui.style.text)
	if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "close"), close_rect, "Close", true) {
		app_ui_close_controls_help(ui, gui)
		uifw.gui_panel_end(gui)
		uifw.gui_overlay_input_cancel(gui)
		uifw.gui_pop_id(gui)
		return
	}
	viewport := uifw.gui_next_rect(gui, height = max(panel.h - gui.style.panel_padding * 2 - gui.style.row_height - gui.style.spacing, gui.style.row_height))
	content_width := max(viewport.w - gui.style.spacing_2, 1)
	content_height := app_ui_controls_help_modal_content_height(gui, content_width, ui.settings)
	uifw.gui_scroll_begin(gui, viewport, content_height, &ui.controls_help_modal_scroll)
	quick_reference := app_ui_controls_help_quick_reference_for_settings(gui.input.active_device, ui.settings)
	uifw.gui_heading(gui, "Quick reference")
	uifw.gui_text_block(gui, quick_reference, content_width, gui.style.accent)
	uifw.gui_spacer(gui, gui.style.spacing_2)
	uifw.gui_text_block(gui, HOW_TO_PLAY_INTRO, content_width, gui.style.text)
	uifw.gui_spacer(gui, gui.style.spacing_1)
	for section in HOW_TO_PLAY_SECTIONS {
		uifw.gui_heading(gui, section.title)
		uifw.gui_text_block(gui, section.body, content_width, gui.style.text_muted)
		uifw.gui_spacer(gui, gui.style.spacing_2)
	}
	uifw.gui_scroll_end(gui)
	uifw.gui_panel_end(gui)
	uifw.gui_overlay_input_end(gui)
	uifw.gui_pop_id(gui)
}

app_ui_draw_gray_scott :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, worker: ^Product_Context) {
	width := f32(vk_ctx.swapchain_extent.width)
	height := f32(vk_ctx.swapchain_extent.height)
	pause_consumed := simulation_controller_ui_update_input(ui, gui)

	if gui.input.pause && !pause_consumed {
		sim.settings.paused = !sim.settings.paused
	}

	if ui.simulation_shell.controls_visible {
		app_ui_draw_simulation_bar(ui, gui, .Gray_Scott, sim, nil, nil, sim.settings.paused, !sim.gpu.ready, "Gray-Scott", vk_ctx, width, worker)
	}
	simulation_controller_ui_draw(ui, gui, gray = sim, width = width, height = height, worker = worker)
	if sim.runtime.nutrient_image_dialog_requested {
		sim.runtime.nutrient_image_dialog_requested = false
		msg: Render_To_Ui_Message
		msg.kind = .Request_Nutrient_Image_Dialog
		_ = engine.queue_try_push(worker.render_to_ui, msg)
	}
	app_ui_draw_loading_overlay(gui, width, height, !sim.gpu.ready)
}

app_ui_action_pressed_by_controller :: proc(action: Input_Action_Button_State, legacy_pressed: bool, legacy_device: uifw.Input_Device_Kind) -> bool {
	if action.pressed {
		return action.owner == .Controller
	}
	return legacy_pressed && legacy_device == .Controller
}

app_ui_control_deck_pressed :: proc(action: Input_Action_Button_State, legacy_pressed: bool) -> bool {
	if action.pressed {
		return true
	}
	// Compatibility for callers that still construct only legacy Space fields.
	return legacy_pressed && !action.down && !action.released
}

app_ui_control_deck_active :: proc(action: Input_Action_Button_State, legacy_active: bool) -> bool {
	return action.down || action.pressed || action.repeated || action.released || legacy_active
}

app_ui_take_controller_action :: proc(action: ^Input_Action_Button_State, legacy_pressed: bool, legacy_device: uifw.Input_Device_Kind) -> bool {
	if action == nil || !app_ui_action_pressed_by_controller(action^, legacy_pressed, legacy_device) {
		return false
	}
	action.pressed = false
	action.repeated = false
	return true
}

app_ui_hide_unfocused_simulation_ui :: proc(ui: ^App_Ui_State) {
	ui.simulation_shell.show_ui = false
	app_ui_set_simulation_chrome_visible(ui, false)
	ui.slime_controller.deck_visible = false
	ui.slime_controller.panel_open = false
	ui.slime_controller.pending_panel_focus = false
	ui.slime_controller.focus.phase = .Unfocused
	ui.slime_controller.focus.region = uifw.GUI_ID_NONE
	ui.slime_controller.focus.parent_region = uifw.GUI_ID_NONE
	ui.slime_controller.focus.active_control = uifw.GUI_ID_NONE
	for &state in ui.simulation_controllers {
		state.deck_visible = false
		state.panel_open = false
		state.pending_panel_focus = false
		state.focus.phase = .Unfocused
		state.focus.region = uifw.GUI_ID_NONE
		state.focus.parent_region = uifw.GUI_ID_NONE
		state.focus.active_control = uifw.GUI_ID_NONE
	}
}

// The utility rail and Control Deck tabs are one simulation-chrome layer. The
// deck fields remain on the per-simulation states for panel/focus bookkeeping,
// but callers must not independently decide whether either part exists.
app_ui_set_simulation_chrome_visible :: proc(ui: ^App_Ui_State, visible: bool) {
	if ui == nil {return}
	ui.simulation_shell.controls_visible = visible
	if slime_controller_ui_enabled(ui) {
		ui.slime_controller.deck_visible = visible
	}
	if state := simulation_controller_ui_state(ui); state != nil {
		state.deck_visible = visible
	}
}

app_ui_release_controller_focus :: proc(ui: ^App_Ui_State) {
	if ui == nil {return}
	if slime_controller_ui_enabled(ui) {
		state := &ui.slime_controller
		state.pending_panel_focus = false
		state.focus.phase = .Unfocused
		state.focus.region = uifw.GUI_ID_NONE
		state.focus.parent_region = uifw.GUI_ID_NONE
		state.focus.active_control = uifw.GUI_ID_NONE
	}
	if state := simulation_controller_ui_state(ui); state != nil {
		state.pending_panel_focus = false
		state.focus.phase = .Unfocused
		state.focus.region = uifw.GUI_ID_NONE
		state.focus.parent_region = uifw.GUI_ID_NONE
		state.focus.active_control = uifw.GUI_ID_NONE
	}
}

app_ui_simulation_shell_update :: proc(ui: ^App_Ui_State, input: Ui_Frame_Input, ui_engaged := false) {
	ui.frame_actions = input.actions
	if (input.key_f1 || input.help || input.actions.help.pressed) && !ui.controls_help_open && app_ui_mode_is_simulation(ui.mode) {
		// Keyboard help is a shell-level command so it remains available when
		// the simulation UI has auto-hidden, but never steals an active editor.
		ui.controls_help_open = true
		ui.controls_help_open_frame = input.frame_index
		ui.controls_help_invoker_focus = uifw.GUI_ID_NONE
		ui.controls_help_modal_scroll = 0
	}
	controller_ui_action_shortcut := (slime_controller_ui_enabled(ui) || simulation_controller_ui_enabled(ui)) && (input.actions.toggle_ui.pressed || input.toggle_ui)
	if ui.simulation_shell.force_hidden {
		if input.key_slash || (input.toggle_ui && !controller_ui_action_shortcut) {
			ui.simulation_shell.force_hidden = false
			ui.simulation_shell.show_ui = true
			app_ui_set_simulation_chrome_visible(ui, true)
			ui.simulation_shell.idle_seconds = 0
		} else {
			ui.simulation_shell.show_ui = false
			app_ui_set_simulation_chrome_visible(ui, false)
			ui.simulation_shell.idle_seconds = f32(max(ui.settings.auto_hide_delay, 0)) / 1000.0
			return
		}
	}
	reveal_activity := input.mouse_pressed ||
		input.mouse_released ||
		input.mouse_moved ||
		input.wheel_delta != 0 ||
		input.help ||
		input.toggle_ui ||
		input.key_space ||
		input.key_slash ||
		input.nav_x != 0 ||
		input.nav_y != 0 ||
		input.accept ||
		input.back
	reveal_activity = reveal_activity ||
		input.actions.control_deck.down ||
		input.actions.control_deck.pressed ||
		input.actions.control_deck.released
	if ui_engaged || reveal_activity {
		ui.simulation_shell.idle_seconds = 0
		if reveal_activity && !ui.simulation_shell.show_ui {
			app_ui_set_simulation_chrome_visible(ui, true)
		}
	} else {
		ui.simulation_shell.idle_seconds += input.delta_time
	}
	auto_hide_delay_seconds := f32(max(ui.settings.auto_hide_delay, 0)) / 1000.0
	if !ui_engaged &&
	   ui.simulation_shell.idle_seconds >= auto_hide_delay_seconds {
		app_ui_hide_unfocused_simulation_ui(ui)
	}
	if input.key_slash || (input.toggle_ui && !controller_ui_action_shortcut) {
		ui.simulation_shell.show_ui = !ui.simulation_shell.show_ui
		app_ui_set_simulation_chrome_visible(ui, true)
		ui.simulation_shell.idle_seconds = 0
	}
}

app_ui_system_cursor_hidden :: proc(ui: ^App_Ui_State) -> bool {
	return ui != nil &&
		app_ui_mode_is_simulation(ui.mode) &&
		!ui.simulation_shell.show_ui &&
		!ui.simulation_shell.controls_visible
}

app_ui_resolve_input_context :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, input: Ui_Frame_Input) -> App_Input_Context_Route {
	simulation_active := app_ui_mode_is_simulation(ui.mode)
	controller_ui_active := slime_controller_ui_enabled(ui) || simulation_controller_ui_enabled(ui)
	controller_ui_focused := (slime_controller_ui_enabled(ui) && ui.slime_controller.focus.phase != .Unfocused) || simulation_controller_ui_focused(ui)
	controller_pause_pressed := controller_ui_active && app_ui_action_pressed_by_controller(input.actions.pause, input.pause, input.active_device)
	controller_toggle_pressed := controller_ui_active && (input.actions.toggle_ui.pressed || input.toggle_ui)
	control_deck_claim := controller_ui_active && app_ui_control_deck_active(
		input.actions.control_deck,
		input.key_space || input.key_space_down || input.key_space_pressed || input.key_space_released,
	)
	focus_entry_claim := controller_ui_active && (
		input.focus_next || input.focus_prev || input.key_tab ||
		input.actions.focus_next.down || input.actions.focus_next.pressed || input.actions.focus_next.repeated || input.actions.focus_next.released ||
		input.actions.focus_prev.down || input.actions.focus_prev.pressed || input.actions.focus_prev.repeated || input.actions.focus_prev.released
	)
	controller_ui_claimed := controller_ui_active &&
		(controller_ui_focused || focus_entry_claim || control_deck_claim || controller_pause_pressed || controller_toggle_pressed)
	controller_ui_pointer_claim := controller_ui_active && (control_deck_claim || controller_pause_pressed || controller_toggle_pressed)

	modal_active := ui.controls_help_open || slime_controller_ui_modal_open(ui)
	edit_active := gui.text_edit_id != uifw.GUI_ID_NONE ||
		gui.focus_edit_id != uifw.GUI_ID_NONE ||
		gui.open_panel != uifw.GUI_ID_NONE ||
		gui.overlay_input_rect_count > 0
	focused_ui_active := gui.focused != uifw.GUI_ID_NONE || controller_ui_claimed

	active_context := App_Input_Context.Global_Fallback
	if simulation_active {
		active_context = .Simulation_Canvas
	}
	if focused_ui_active {
		active_context = .Focused_Ui
	}
	if edit_active {
		active_context = .Value_Edit
	}
	if modal_active {
		active_context = .Modal
	}

	width := f32(input.window_width)
	height := f32(input.window_height)
	bar_rect := app_ui_simulation_chrome_rect(ui, gui, ui.mode, width, height)
	menu_rect := app_ui_simulation_menu_panel(ui, gui, width, height)
	over_bar := simulation_active && ui.simulation_shell.controls_visible && uifw.gui_contains(bar_rect, input.mouse_pos)
	over_menu := simulation_active && ui.simulation_shell.show_ui && !controller_ui_active && uifw.gui_contains(menu_rect, input.mouse_pos)
	over_controller_ui := (slime_controller_ui_enabled(ui) && slime_controller_ui_over_ui(&ui.slime_controller, gui, input)) || simulation_controller_ui_over_ui(ui, gui, input)
	top_layer_open := modal_active || gui.overlay_input_rect_count > 0 || gui.open_panel != uifw.GUI_ID_NONE
	// An engaged editor owns the complete gesture until commit/cancel. This
	// prevents an outside release from both ending an edit and painting/panning
	// the simulation underneath it in the same frame.
	pointer_over_ui := over_bar || over_menu || over_controller_ui || top_layer_open || edit_active || controller_ui_pointer_claim

	base_owner := simulation_active ? App_Input_Context.Simulation_Canvas : App_Input_Context.Global_Fallback
	pointer_owner := base_owner
	if pointer_over_ui {
		pointer_owner = .Focused_Ui
		if edit_active {
			pointer_owner = .Value_Edit
		}
		if modal_active {
			pointer_owner = .Modal
		}
	}
	navigation_owner := base_owner
	if active_context >= .Focused_Ui {
		navigation_owner = active_context
	}
	keyboard_camera_owner := base_owner
	if active_context >= .Value_Edit {
		keyboard_camera_owner = active_context
	}
	controller_camera_owner := base_owner
	if active_context >= .Focused_Ui {
		controller_camera_owner = active_context
	}
	global_shortcut_owner := App_Input_Context.Global_Fallback
	if active_context >= .Value_Edit || controller_ui_claimed {
		global_shortcut_owner = active_context
	}

	return {
		active_context = active_context,
		pointer_owner = pointer_owner,
		navigation_owner = navigation_owner,
		keyboard_camera_owner = keyboard_camera_owner,
		controller_camera_owner = controller_camera_owner,
		global_shortcut_owner = global_shortcut_owner,
		pointer_over_ui = pointer_over_ui,
		controller_ui_claimed = controller_ui_claimed,
	}
}

app_ui_clear_global_shortcuts :: proc(input: ^Ui_Frame_Input) {
	input.pause = false
	input.help = false
	input.toggle_ui = false
	input.key_slash = false
	input.key_f1 = false
	input.key_space = false
	input.key_space_down = false
	input.key_space_pressed = false
	input.key_space_released = false
	input.actions.pause = {}
	input.actions.help = {}
	input.actions.toggle_ui = {}
	input.actions.control_deck = {}
}

app_ui_clear_gui_global_shortcuts :: proc(gui: ^uifw.Gui_Context) {
	gui.input.pause = false
	gui.input.toggle_ui = false
	gui.input.key_slash = false
	gui.input.key_space = false
	gui.input.key_space_down = false
	gui.input.key_space_pressed = false
	gui.input.key_space_released = false
}

app_ui_clear_navigation_input :: proc(input: ^Ui_Frame_Input) {
	input.text_input = {}
	input.text_input_len = 0
	input.clipboard_paste = {}
	input.clipboard_paste_len = 0
	input.key_tab = false
	input.key_enter = false
	input.key_escape = false
	input.key_backspace = false
	input.key_delete = false
	input.key_home = false
	input.key_end = false
	input.key_left = false
	input.key_right = false
	input.key_up = false
	input.key_down = false
	input.nav_x = 0
	input.nav_y = 0
	input.nav_pressed_x = 0
	input.nav_pressed_y = 0
	input.accept = false
	input.back = false
	input.focus_next = false
	input.focus_prev = false
	input.actions.navigate = {}
	input.actions.accept = {}
	input.actions.back = {}
	input.actions.focus_next = {}
	input.actions.focus_prev = {}
}

app_ui_clear_keyboard_camera_input :: proc(input: ^Ui_Frame_Input) {
	input.key_w = false
	input.key_a = false
	input.key_s = false
	input.key_d = false
	input.key_q = false
	input.key_e = false
	input.key_x = false
	input.key_v = false
	input.key_c = false
	input.camera_reset = false
	input.actions.camera_pan = {}
	input.actions.camera_zoom = 0
	input.actions.camera_reset = {}
}

app_ui_clear_controller_camera_input :: proc(input: ^Ui_Frame_Input) {
	input.controller_left = {}
	input.controller_zoom = 0
	// Navigation routing may already have removed arrow keys. Rebuild the
	// semantic camera axes from the keyboard controls that remain eligible.
	input.actions.camera_pan = {
		app_input_axis(input.key_right || input.key_d, input.key_left || input.key_a),
		app_input_axis(input.key_down || input.key_s, input.key_up || input.key_w),
	}
	input.actions.camera_zoom = app_input_axis(input.key_e, input.key_q)
	if input.actions.camera_reset.owner == .Controller {
		input.actions.camera_reset = {}
	}
	// The compatibility reset pulse may have come from the controller. The
	// keyboard C field remains authoritative for an eligible keyboard reset.
	input.camera_reset = false
}

app_ui_simulation_filter_input :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, input: Ui_Frame_Input) -> Ui_Frame_Input {
	dismiss_help := ui.controls_help_open && (input.key_f1 || input.help || input.actions.help.pressed)
	if dismiss_help {app_ui_close_controls_help(ui, gui)}
	pan_chord_candidate := input.mouse_pressed &&
		(input.mouse_button == 2 || (input.mouse_button == 1 && input.key_space_down))
	routing_input := input
	if pan_chord_candidate {
		// Resolve the pointer hit before Space's shell/control-deck binding can
		// claim the same chord. Actual UI hit-testing still has priority.
		routing_input.key_space = false
		routing_input.key_space_down = false
		routing_input.key_space_pressed = false
		routing_input.actions.control_deck = {}
	}
	route := app_ui_resolve_input_context(ui, gui, routing_input)
	// A deliberate canvas click transfers ownership from keyboard/controller UI
	// navigation back to the simulation. Pointer motion alone never steals focus.
	if input.active_device == .Mouse_Keyboard &&
	   input.mouse_pressed &&
	   route.pointer_owner == .Simulation_Canvas &&
	   route.active_context < .Value_Edit {
		app_ui_hide_unfocused_simulation_ui(ui)
		gui.focused = uifw.GUI_ID_NONE
		route = app_ui_resolve_input_context(ui, gui, routing_input)
	}
	ui.input_route = route
	shell_input := input
	pan_gesture_started := pan_chord_candidate &&
		route.pointer_owner == .Simulation_Canvas &&
		!route.pointer_over_ui
	if pan_gesture_started {
		ui.simulation_shell.camera_pan_active = true
		// Space remains a standalone shortcut, but a same-frame Space+canvas drag
		// is an explicit camera gesture and must not also pause/open the deck.
		app_ui_clear_global_shortcuts(&shell_input)
		app_ui_clear_gui_global_shortcuts(gui)
	}
	if dismiss_help {
		shell_input.key_f1 = false
		shell_input.help = false
		shell_input.actions.help = {}
	}
	if route.global_shortcut_owner != .Global_Fallback {
		app_ui_clear_global_shortcuts(&shell_input)
		// Modal/edit contexts suppress shortcuts inside the GUI as well. A
		// focused controller deck claim only suppresses the shell fallback;
		// the GUI still needs the opening Space/Select/Pause event.
		if route.active_context >= .Value_Edit {
			app_ui_clear_gui_global_shortcuts(gui)
		}
	}
	ui_engaged := route.active_context >= .Focused_Ui || route.pointer_owner >= .Focused_Ui
	app_ui_simulation_shell_update(ui, shell_input, ui_engaged)
	if (shell_input.key_f1 || shell_input.help || shell_input.actions.help.pressed) && ui.controls_help_open {
		ui.controls_help_invoker_focus = gui.focused
		ui.controls_help_open_frame = gui.frame_index
	}
	// UI consumers still need the unfiltered semantic action frame even when
	// the shell/global fallback did not own a shortcut.
	ui.frame_actions = input.actions

	if !app_ui_mode_is_simulation(ui.mode) {
		filtered := input
		filtered.mouse_down = false
		filtered.mouse_pressed = false
		filtered.mouse_released = false
		filtered.camera_pan_down = false
		filtered.wheel_delta_x = 0
		filtered.wheel_delta = 0
		filtered.actions.primary = {}
		filtered.actions.secondary = {}
		ui.simulation_shell.mouse_pressed = false
		ui.simulation_shell.camera_pan_active = false
		return filtered
	}

	filtered := input
	if route.global_shortcut_owner != .Global_Fallback {
		app_ui_clear_global_shortcuts(&filtered)
	}
	if route.navigation_owner != .Simulation_Canvas {
		app_ui_clear_navigation_input(&filtered)
	}
	if route.keyboard_camera_owner != .Simulation_Canvas {
		app_ui_clear_keyboard_camera_input(&filtered)
	}
	if route.controller_camera_owner != .Simulation_Canvas {
		app_ui_clear_controller_camera_input(&filtered)
	}

	if input.mouse_pressed {
		ui.simulation_shell.mouse_pressed = !route.pointer_over_ui
		ui.simulation_shell.mouse_button = input.mouse_button
		if route.pointer_over_ui {
			filtered.mouse_pressed = false
			filtered.mouse_down = false
		}
	}
	gesture_owned := ui.simulation_shell.mouse_pressed
	camera_gesture_owned := ui.simulation_shell.camera_pan_active
	filtered.camera_pan_down = camera_gesture_owned && input.mouse_down
	if camera_gesture_owned {
		// Camera gestures own the pointer exclusively. The simulation never sees
		// their press/hold phases as primary or secondary interaction.
		filtered.mouse_down = false
		filtered.mouse_pressed = false
		filtered.mouse_released = false
		filtered.primary_down = false
		filtered.primary_pressed = false
		filtered.primary_released = false
		filtered.secondary_down = false
		filtered.secondary_pressed = false
		filtered.secondary_released = false
		filtered.actions.primary = {}
		filtered.actions.secondary = {}
	}
	if !gesture_owned && route.pointer_over_ui {
		filtered.mouse_down = false
		filtered.mouse_pressed = false
		filtered.mouse_released = false
	}
	if route.pointer_over_ui {
		filtered.wheel_delta_x = 0
		filtered.wheel_delta = 0
	}
	if route.pointer_over_ui && !gesture_owned {
		filtered.primary_down = filtered.mouse_down && filtered.mouse_button == 1
		filtered.primary_pressed = filtered.mouse_pressed && filtered.mouse_button == 1
		filtered.primary_released = filtered.mouse_released && filtered.mouse_button == 1
		filtered.secondary_down = filtered.mouse_down && filtered.mouse_button == 3
		filtered.secondary_pressed = filtered.mouse_pressed && filtered.mouse_button == 3
		filtered.secondary_released = filtered.mouse_released && filtered.mouse_button == 3
		filtered.actions.primary.down = filtered.primary_down
		filtered.actions.primary.pressed = filtered.primary_pressed
		filtered.actions.primary.released = filtered.primary_released
		filtered.actions.primary.repeated = false
		filtered.actions.secondary.down = filtered.secondary_down
		filtered.actions.secondary.pressed = filtered.secondary_pressed
		filtered.actions.secondary.released = filtered.secondary_released
		filtered.actions.secondary.repeated = false
	}
	if input.mouse_released {
		ui.simulation_shell.mouse_pressed = false
		ui.simulation_shell.camera_pan_active = false
	}
	return filtered
}

app_ui_draw_simulation_bar :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, mode: App_Mode, gray_scott: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation, remaining: ^Remaining_Sim_State, paused, loading: bool, simulation_name: string, vk_ctx: ^engine.Vk_Context, width: f32, worker: ^Product_Context) {
	height := f32(gui.input.window_height)
	if vk_ctx != nil && vk_ctx.swapchain_extent.height > 0 {
		height = f32(vk_ctx.swapchain_extent.height)
	}
	if height <= 0 {height = f32(720)}
	bar := app_ui_simulation_chrome_rect(ui, gui, mode, width, height)
	radius := max(gui.style.radius_control * 2, f32(8))
	uifw.gui_shadow(gui, bar, radius, {0, 6}, 18, {0, 0, 0, 0.36})
	uifw.gui_round_rect(gui, bar, radius, {0.025, 0.035, 0.05, 0.52})
	glass := uifw.gui_default_glass_style(gui, radius)
	glass.tint = {0.06, 0.08, 0.10, 0.68}
	glass.roughness = 0.58
	glass.thickness = max(gui.style.rhythm * 0.20, f32(8))
	glass.bevel = max(gui.style.border_width * 6, f32(6))
	glass.border = 0.32
	glass.highlight = 0.38
	uifw.gui_refractive_glass_rect(gui, bar, glass)
	uifw.gui_round_stroke(gui, bar, radius, {1, 1, 1, 0.16}, gui.style.border_width)

	header_h := app_ui_simulation_bar_height(gui)
	pad := gui.style.spacing_1
	gap := max(gui.style.spacing_1, gui.style.border_width * 2)
	content := uifw.Rect{bar.x + pad, bar.y + pad, max(bar.w - pad * 2, 1), max(header_h - pad * 2, 1)}
	button_h := content.h
	back_label := "Menu"
	help_label := "Help"
	pause_label := paused ? "Resume" : "Pause"
	record_visible := worker != nil && app_ui_mode_allows_video_recording(mode)
	record_label := app_ui_video_recording_button_label(ui)
	record_display_label := record_label
	if content.w < f32(760) {
		if ui.video_recording_state == .Recording {record_display_label = "Stop"} else {record_display_label = "Rec"}
		if paused {pause_label = "Play"}
	}
	back_w := uifw.gui_button_content_width(gui, back_label)
	help_w := uifw.gui_button_content_width(gui, help_label)
	pause_w := uifw.gui_button_content_width(gui, pause_label)
	record_w := record_visible ? uifw.gui_button_content_width(gui, record_display_label) : f32(0)
	button_count := record_visible ? 4 : 3
	natural_buttons_w := back_w + help_w + pause_w + record_w
	info_reserve := min(max(content.w * 0.26, gui.style.row_height * 1.65), content.w * 0.42)
	buttons_available := max(content.w - info_reserve - gap * f32(button_count), f32(button_count))
	shrink := min(buttons_available / max(natural_buttons_w, 1), f32(1))
	back_w *= shrink
	help_w *= shrink
	pause_w *= shrink
	record_w *= shrink
	x := content.x
	back_rect := uifw.Rect{x, content.y, back_w, button_h}
	x += back_w + gap
	help_rect := uifw.Rect{x, content.y, help_w, button_h}
	x += help_w + gap
	pause_rect := uifw.Rect{x, content.y, pause_w, button_h}
	x += pause_w
	record_rect: uifw.Rect
	if record_visible {
		x += gap
		record_rect = {x, content.y, record_w, button_h}
		x += record_w
	}

	uifw.gui_push_id(gui, "simulation_bar")
	if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "back"), back_rect, back_label, true, false) {
		app_ui_video_recording_stop(ui, worker)
		app_ui_navigate(ui, .Main_Menu)
	}
	if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "help"), help_rect, help_label, true, false) {
		app_ui_open_controls_help(ui, gui)
	}
	if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "pause"), pause_rect, pause_label, true, false) {
		app_ui_simulation_set_paused(mode, gray_scott, particle_life, remaining, !paused)
	}
	if paused {
		uifw.gui_round_stroke(gui, pause_rect, gui.style.radius_control, uifw.gui_apply_opacity(gui.style.accent, 0.62), max(gui.style.border_width * 1.5, 1.5))
	}
	if record_visible {
		if ui.video_recording_state == .Restoring_Fullscreen {
			uifw.gui_text_aligned(gui, app_ui_simulation_bar_text_rect(gui, record_rect), record_display_label, gui.style.text_muted, .Center)
		} else if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "record"), record_rect, record_display_label, true, false) {
			app_ui_video_recording_toggle(ui, worker)
		}
		if ui.video_recording_state == .Recording {
			uifw.gui_round_stroke(gui, record_rect, gui.style.radius_control, uifw.gui_apply_opacity(gui.style.danger, 0.82), max(gui.style.border_width * 1.5, 1.5))
		}
	}
	info_x := x + gap
	info_rect := uifw.Rect{info_x, content.y, max(content.x + content.w - info_x, 1), content.h}
	app_ui_draw_simulation_bar_info(gui, info_rect, simulation_name, paused, loading, ui.last_stats.fps)
	uifw.gui_pop_id(gui)

	if slime_controller_ui_enabled(ui) || simulation_controller_ui_enabled(ui) {
		line_y := bar.y + header_h - gui.style.border_width
		uifw.gui_rect(gui, {bar.x + pad * 2, line_y, max(bar.w - pad * 4, 1), gui.style.border_width}, {1, 1, 1, 0.12})
	}
}

app_ui_draw_simulation_bar_info :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, simulation_name: string, paused, loading: bool, fps: f32) {
	if rect.w <= 1 {return}
	status := loading ? "Loading" : (paused ? "Paused" : "Running")
	status_color := uifw.Color{0.32, 0.88, 0.58, 1}
	if paused {status_color = {0.98, 0.70, 0.28, 1}}
	if loading {status_color = gui.style.accent}
	fps_label := fmt.tprintf("%.0f FPS", fps)
	text_rect := app_ui_simulation_bar_text_rect(gui, rect)
	// Reserve the configured four-digit range so FPS fluctuations do not move
	// the status badge or simulation name as the displayed digit count changes.
	fps_w := min(max(uifw.gui_text_width(gui, "0000 FPS") + gui.style.spacing_1 * 2, gui.style.row_height), rect.w)
	fps_rect := uifw.Rect{rect.x + rect.w - fps_w, text_rect.y, fps_w, text_rect.h}
	uifw.gui_text_right(gui, fps_rect, fps_label, gui.style.text_muted)
	remaining_w := max(rect.w - fps_w - gui.style.spacing_1, 0)
	status_w := uifw.gui_text_width(gui, status) + gui.style.spacing_1 * 4 + max(gui.style.border_width * 6, f32(6))
	if remaining_w >= status_w {
		status_rect := uifw.Rect{rect.x + remaining_w - status_w, rect.y + max((rect.h - gui.style.body_line_height) * 0.5, 0), status_w, min(gui.style.body_line_height, rect.h)}
		uifw.gui_round_rect(gui, status_rect, status_rect.h * 0.5, uifw.gui_apply_opacity(status_color, 0.13))
		dot_size := max(gui.style.border_width * 6, f32(6))
		dot := uifw.Rect{status_rect.x + gui.style.spacing_1, status_rect.y + (status_rect.h - dot_size) * 0.5, dot_size, dot_size}
		uifw.gui_ellipse(gui, dot, status_color)
		status_text := uifw.Rect{dot.x + dot.w + gui.style.spacing_1, status_rect.y, max(status_rect.x + status_rect.w - dot.x - dot.w - gui.style.spacing_1 * 2, 1), status_rect.h}
		uifw.gui_text_aligned(gui, status_text, status, gui.style.text, .Left)
		remaining_w = max(remaining_w - status_w - gui.style.spacing_1, 0)
	}
	if remaining_w >= gui.style.body_char_width * 4 {
		name_rect := uifw.Rect{rect.x, text_rect.y, remaining_w, text_rect.h}
		uifw.gui_scissor_begin(gui, name_rect)
		uifw.gui_text_aligned(gui, name_rect, simulation_name, gui.style.text, .Left)
		uifw.gui_scissor_end(gui)
	}
}

app_ui_simulation_chrome_rect :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, mode: App_Mode, width, height: f32) -> uifw.Rect {
	if mode == .Slime_Mold && ui != nil {
		return slime_controller_ui_deck_rect(gui, width, height, ui.slime_controller.mode)
	}
	if _, ok := simulation_controller_ui_state_index(mode); ok {
		return simulation_controller_ui_deck_rect(gui, width, height, len(simulation_controller_ui_tabs(mode)))
	}
	margin := max(gui.style.spacing_3, f32(18))
	bar_h := app_ui_simulation_bar_height(gui)
	target_w := max(width * 0.62, gui.style.body_char_width * 30)
	bar_w := min(target_w, max(width - margin * 2, 1))
	return {max((width - bar_w) * 0.5, margin), max(height - bar_h - margin, margin), bar_w, bar_h}
}

app_ui_focus_simulation_bar_pause :: proc(gui: ^uifw.Gui_Context) {
	uifw.gui_push_id(gui, "simulation_bar")
	gui.focused = uifw.gui_make_id(gui, "pause")
	uifw.gui_pop_id(gui)
}

app_ui_focus_simulation_bar_back :: proc(gui: ^uifw.Gui_Context) {
	uifw.gui_push_id(gui, "simulation_bar")
	gui.focused = uifw.gui_make_id(gui, "back")
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

app_ui_video_recording_toggle :: proc(ui: ^App_Ui_State, worker: ^Product_Context) {
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

app_ui_video_recording_request_save_dialog :: proc(ui: ^App_Ui_State, worker: ^Product_Context) {
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

app_ui_video_recording_stop :: proc(ui: ^App_Ui_State, worker: ^Product_Context) {
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

remaining_sim_kind_from_app_mode :: proc(mode: App_Mode) -> Remaining_Sim_Kind {
	#partial switch mode {
	case .Slime_Mold: return .Slime_Mold
	case .Flow_Field: return .Flow_Field
	case .Pellets: return .Pellets
	case .Voronoi_CA: return .Voronoi_CA
	case .Moire: return .Moire
	case .Vectors: return .Vectors
	case .Primordial: return .Primordial
	case: return .Slime_Mold
	}
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
	glass := uifw.gui_default_glass_style(gui, 0)
	glass.tint = {0.04, 0.05, 0.07, 0.56}
	glass.radius = 0
	glass.roughness = 0.88
	glass.thickness = max(gui.style.rhythm * 0.42, f32(16))
	glass.bevel = max(gui.style.border_width * 3, f32(3))
	glass.border = 0.12
	glass.highlight = 0.18
	uifw.gui_refractive_glass_rect(gui, overlay, glass)
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
	content_h := gui.style.spacing_1 * 2 + gui.style.row_height
	return max(SIMULATION_BAR_HEIGHT, content_h)
}

app_ui_simulation_menu_panel :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, width, height: f32) -> uifw.Rect {
	top := f32(0)
	bottom_margin := f32(0)
	if ui.simulation_shell.controls_visible && !slime_controller_ui_enabled(ui) && !simulation_controller_ui_enabled(ui) {
		bottom_margin = app_ui_simulation_bar_height(gui) + max(gui.style.spacing_3, f32(18)) * 2
	}
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

app_ui_navigate_immediate :: proc(ui: ^App_Ui_State, mode: App_Mode) {
	if ui.video_recording_state == .Recording && app_ui_mode_is_simulation(ui.mode) && !app_ui_mode_is_simulation(mode) {
		ui.video_recording_state = .Idle
		write_fixed_string(ui.video_recording_status[:], "")
	}
	ui.previous_mode = ui.mode
	ui.mode = mode
	if mode == .Options {
		ui.options_scroll = 0
	}
	if mode == .How_To_Play {
		ui.how_to_play_scroll = 0
	}
	if app_ui_mode_is_simulation(mode) {
		// A simulation starts with no controller surface claiming focus. Mouse
		// motion may reveal the transient bar; Tab/deck actions explicitly enter
		// and focus the controller UI.
		app_ui_hide_unfocused_simulation_ui(ui)
		ui.simulation_shell.idle_seconds = 0
	}
}

app_ui_navigate :: proc(ui: ^App_Ui_State, mode: App_Mode) {
	if ui == nil {
		return
	}
	if app_ui_mode_transition_active(ui) {
		return
	}
	transition_between_menu_and_scene :=
		(ui.mode == .Main_Menu && app_ui_mode_is_simulation(mode)) ||
		(app_ui_mode_is_simulation(ui.mode) && mode == .Main_Menu)
	if transition_between_menu_and_scene {
		app_ui_mode_transition_request(ui, mode)
		return
	}
	app_ui_mode_transition_cancel(ui)
	app_ui_navigate_immediate(ui, mode)
}

app_ui_save_settings :: proc(ui: ^App_Ui_State, worker: ^Product_Context) {
	if settings_save_app(settings_app_config_path(), ui.settings) {
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

app_ui_mark_settings_changed :: proc(ui: ^App_Ui_State, worker: ^Product_Context) {
	ui.settings_dirty = true
	app_ui_publish_settings_changed(ui, worker)
}

app_ui_reset_settings_to_defaults :: proc(ui: ^App_Ui_State, worker: ^Product_Context) {
	ui.settings = settings_default()
	ui.menu_position_index = option_index(ui.settings.menu_position, MENU_POSITION_OPTIONS[:], 1)
	ui.texture_filtering_index = option_index(ui.settings.texture_filtering, TEXTURE_FILTERING_OPTIONS[:], 0)
	ui.controller_face_layout_index = option_index(ui.settings.controller_face_layout, CONTROLLER_FACE_LAYOUT_OPTIONS[:], 0)
	ui.controller_menu_layout_index = option_index(ui.settings.controller_menu_layout, CONTROLLER_MENU_LAYOUT_OPTIONS[:], 0)
	ui.controller_shoulder_layout_index = option_index(ui.settings.controller_shoulder_layout, CONTROLLER_SHOULDER_LAYOUT_OPTIONS[:], 0)
	ui.keyboard_shortcut_profile_index = option_index(ui.settings.keyboard_shortcut_profile, KEYBOARD_SHORTCUT_PROFILE_OPTIONS[:], 0)
	app_ui_mark_settings_changed(ui, worker)
}

app_ui_publish_settings_changed :: proc(ui: ^App_Ui_State, worker: ^Product_Context) {
	msg: Render_To_Ui_Message
	msg.kind = .App_Settings_Changed
	msg.app_settings = ui.settings
	_ = engine.queue_try_push(worker.render_to_ui, msg)
}
