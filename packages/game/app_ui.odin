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
		body = "W A S D or the arrow keys pan the simulation camera when the canvas owns them. Q / E zoom and C resets the camera. Tab and Shift+Tab move focus; Enter activates a button or engages an editor; Escape goes back or restores the value captured when editing began. While engaged, the arrow keys adjust values. The Standard shortcut profile uses Slash for UI, F1 for help, and Space for pause. Letter Shortcuts uses U, H, and P instead. Per-action selectors create a Custom profile and automatically resolve duplicate keys. Space remains reserved for Pause plus the Slime Control Deck.",
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

app_ui_draw :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation, vk_ctx: ^engine.Vk_Context, worker: ^Render_Worker_State) {
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
	if app_ui_mode_is_simulation(ui.mode) && ui.simulation_shell.controls_visible {
		notice_y = app_ui_simulation_bar_height(gui) + gui.style.spacing_2
	}
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
	if gui.input.active_device != .Controller || app_ui_system_cursor_hidden(ui) {
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
	app_ui_main_menu_apply_navigation(ui, gui)

	app_ui_draw_main_menu_backdrop(gui, {0, 0, width, height}, theme)

	app_ui_main_menu_sync_slot_to_selection(ui, gui)
	if gui.input.accept && gui.focused == uifw.GUI_ID_NONE {
		app_ui_main_menu_activate_slot(ui, ui.main_menu_focus_slot, worker)
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
	if ui.main_menu_focus_navigation_active {
		if ui.main_menu_focus_slot == MAIN_MENU_TITLE_SLOT {
			gui.focused = title_id
		} else if gui.focused == title_id {
			gui.focused = uifw.GUI_ID_NONE
		}
	}
	title_control := uifw.gui_control(gui, title_id, title_click, true)
	if title_control.activated || (title_control.hovered && gui.active == title_id && gui.input.mouse_released) {
		ui.main_menu_focus_slot = MAIN_MENU_TITLE_SLOT
		ui.main_menu_palette_randomize_requested = true
	}
	uifw.gui_text_aligned_font(gui, title, title_label, theme.text, .Left, .Display, title_scale)
	if title_control.focused {
		ui.main_menu_focus_slot = MAIN_MENU_TITLE_SLOT
		uifw.gui_round_stroke(gui, uifw.gui_inset(title_click, -theme.border_width * 2), theme.card_radius, uifw.gui_apply_opacity(theme.text, 0.88), MAIN_MENU_TEXT_BUTTON_FOCUS_BORDER_WIDTH)
	}
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
		options_id := uifw.gui_make_id(gui, "options")
		if ui.main_menu_focus_navigation_active {
			if ui.main_menu_focus_slot == app_ui_main_menu_options_slot() {
				gui.focused = options_id
			} else if gui.focused == options_id {
				gui.focused = uifw.GUI_ID_NONE
			}
		}
		if app_ui_draw_main_menu_text_button(gui, {actions.x, actions.y, button_w, button_h}, "options", "OPTIONS", theme) {
			ui.main_menu_focus_slot = app_ui_main_menu_options_slot()
			app_ui_main_menu_activate_slot(ui, ui.main_menu_focus_slot, worker)
		}
		if gui.focused == options_id {
			ui.main_menu_focus_slot = app_ui_main_menu_options_slot()
		}
		quit_id := uifw.gui_make_id(gui, "quit")
		if ui.main_menu_focus_navigation_active {
			if ui.main_menu_focus_slot == app_ui_main_menu_quit_slot() {
				gui.focused = quit_id
			} else if gui.focused == quit_id {
				gui.focused = uifw.GUI_ID_NONE
			}
		}
		if app_ui_draw_main_menu_text_button(gui, {actions.x, actions.y + button_h + action_gap, button_w, button_h}, "quit", "QUIT", theme) {
			ui.main_menu_focus_slot = app_ui_main_menu_quit_slot()
			app_ui_main_menu_activate_slot(ui, ui.main_menu_focus_slot, worker)
		}
		if gui.focused == quit_id {
			ui.main_menu_focus_slot = app_ui_main_menu_quit_slot()
		}
	} else {
		action_gap := max(theme.item_gap * 1.4, theme.footer_height * 0.35)
		actions := uifw.Rect{list.x, max(list.y + list.h - theme.footer_height * 2 - action_gap, list.y), list.w, theme.footer_height * 2 + action_gap}
		button_w := min(actions.w, max(gui.style.body_char_width * 16, 220))
		button_x := actions.x + max((actions.w - button_w) * 0.5, 0)
		options_id := uifw.gui_make_id(gui, "options")
		if ui.main_menu_focus_navigation_active {
			if ui.main_menu_focus_slot == app_ui_main_menu_options_slot() {
				gui.focused = options_id
			} else if gui.focused == options_id {
				gui.focused = uifw.GUI_ID_NONE
			}
		}
		if app_ui_draw_main_menu_text_button(gui, {button_x, actions.y, button_w, theme.footer_height}, "options", "OPTIONS", theme) {
			ui.main_menu_focus_slot = app_ui_main_menu_options_slot()
			app_ui_main_menu_activate_slot(ui, ui.main_menu_focus_slot, worker)
		}
		if gui.focused == options_id {
			ui.main_menu_focus_slot = app_ui_main_menu_options_slot()
		}
		quit_id := uifw.gui_make_id(gui, "quit")
		if ui.main_menu_focus_navigation_active {
			if ui.main_menu_focus_slot == app_ui_main_menu_quit_slot() {
				gui.focused = quit_id
			} else if gui.focused == quit_id {
				gui.focused = uifw.GUI_ID_NONE
			}
		}
		if app_ui_draw_main_menu_text_button(gui, {button_x, actions.y + theme.footer_height + action_gap, button_w, theme.footer_height}, "quit", "QUIT", theme) {
			ui.main_menu_focus_slot = app_ui_main_menu_quit_slot()
			app_ui_main_menu_activate_slot(ui, ui.main_menu_focus_slot, worker)
		}
		if gui.focused == quit_id {
			ui.main_menu_focus_slot = app_ui_main_menu_quit_slot()
		}
	}
}

app_ui_main_menu_pointer_interaction :: proc(gui: ^uifw.Gui_Context) -> bool {
	return uifw.gui_pointer_enabled(gui) &&
	       (gui.input.mouse_pressed ||
	        gui.input.mouse_released ||
	        gui.input.mouse_down ||
	        gui.input.wheel_delta != 0)
}

app_ui_main_menu_options_slot :: proc() -> int {
	return MAIN_MENU_SIMULATION_SLOT_OFFSET + len(APP_SIMULATION_NAMES)
}

app_ui_main_menu_quit_slot :: proc() -> int {
	return app_ui_main_menu_options_slot() + 1
}

app_ui_main_menu_slot_count :: proc() -> int {
	return app_ui_main_menu_quit_slot() + 1
}

app_ui_main_menu_clamp_slot :: proc(slot: int) -> int {
	return max(min(slot, app_ui_main_menu_slot_count() - 1), MAIN_MENU_TITLE_SLOT)
}

app_ui_main_menu_slot_for_simulation_index :: proc(index: int) -> int {
	return MAIN_MENU_SIMULATION_SLOT_OFFSET + max(min(index, len(APP_SIMULATION_NAMES) - 1), 0)
}

app_ui_main_menu_simulation_index_for_slot :: proc(slot: int) -> (index: int, ok: bool) {
	index = slot - MAIN_MENU_SIMULATION_SLOT_OFFSET
	ok = index >= 0 && index < len(APP_SIMULATION_NAMES)
	if !ok {
		index = 0
	}
	return
}

app_ui_main_menu_sync_slot_to_selection :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	ui.main_menu_selected = max(min(ui.main_menu_selected, len(APP_SIMULATION_NAMES) - 1), 0)
	ui.main_menu_focus_slot = app_ui_main_menu_clamp_slot(ui.main_menu_focus_slot)
	if gui.focused == uifw.GUI_ID_NONE && !ui.main_menu_focus_navigation_active {
		ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(ui.main_menu_selected)
	}
}

app_ui_main_menu_apply_navigation :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context) {
	app_ui_main_menu_sync_slot_to_selection(ui, gui)

	direction := 0
	if gui.input.focus_next {
		direction = 1
	} else if gui.input.focus_prev {
		direction = -1
	} else if gui.input.nav_pressed_y > 0 {
		direction = 1
	} else if gui.input.nav_pressed_y < 0 {
		direction = -1
	}

	if direction != 0 {
		if (gui.input.focus_next || gui.input.focus_prev) && gui.focused == uifw.GUI_ID_NONE && !ui.main_menu_focus_navigation_active {
			ui.main_menu_focus_slot = direction > 0 ? MAIN_MENU_TITLE_SLOT : app_ui_main_menu_quit_slot()
		} else {
			if !ui.main_menu_focus_navigation_active {
				ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(ui.main_menu_selected)
			}
			ui.main_menu_focus_slot = app_ui_main_menu_clamp_slot(ui.main_menu_focus_slot + direction)
		}
		ui.main_menu_focus_navigation_active = true
		gui.focus_moved = true
		if index, ok := app_ui_main_menu_simulation_index_for_slot(ui.main_menu_focus_slot); ok {
			ui.main_menu_selected = index
		}
		return
	}

	if gui.input.nav_pressed_x > 0 {
		if _, ok := app_ui_main_menu_simulation_index_for_slot(ui.main_menu_focus_slot); ok {
			ui.main_menu_focus_slot = app_ui_main_menu_options_slot()
			ui.main_menu_focus_navigation_active = true
			gui.focus_moved = true
		}
	} else if gui.input.nav_pressed_x < 0 {
		if ui.main_menu_focus_slot == app_ui_main_menu_options_slot() ||
		   ui.main_menu_focus_slot == app_ui_main_menu_quit_slot() {
			ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(ui.main_menu_selected)
			ui.main_menu_focus_navigation_active = true
			gui.focus_moved = true
		}
	}
}

app_ui_main_menu_request_close :: proc(worker: ^Render_Worker_State) {
	if worker == nil || worker.render_to_ui == nil {
		return
	}
	msg: Render_To_Ui_Message
	msg.kind = .Request_Close
	_ = engine.queue_try_push(worker.render_to_ui, msg)
}

app_ui_main_menu_activate_slot :: proc(ui: ^App_Ui_State, slot: int, worker: ^Render_Worker_State) {
	clamped_slot := app_ui_main_menu_clamp_slot(slot)
	if index, ok := app_ui_main_menu_simulation_index_for_slot(clamped_slot); ok {
		ui.main_menu_selected = index
		app_ui_navigate(ui, app_ui_mode_for_simulation_index(index))
		return
	}
	if clamped_slot == MAIN_MENU_TITLE_SLOT {
		ui.main_menu_palette_randomize_requested = true
	} else if clamped_slot == app_ui_main_menu_options_slot() {
		app_ui_navigate(ui, .Options)
	} else if clamped_slot == app_ui_main_menu_quit_slot() {
		app_ui_main_menu_request_close(worker)
	}
}

app_ui_main_menu_scroll_simulation_into_view :: proc(ui: ^App_Ui_State, viewport: uifw.Rect, content_h, row_gap: f32, theme: Menu_Theme) {
	index, ok := app_ui_main_menu_simulation_index_for_slot(ui.main_menu_focus_slot)
	if !ok {
		return
	}
	max_scroll := max(content_h - viewport.h, 0)
	row_step := theme.row_height + row_gap
	row_top := f32(index) * row_step
	row_bottom := row_top + theme.row_height
	padding := min(max(row_gap * 0.45, 8), max(viewport.h * 0.18, 0))
	if row_top < ui.main_menu_scroll + padding {
		ui.main_menu_scroll = row_top - padding
	} else if row_bottom > ui.main_menu_scroll + viewport.h - padding {
		ui.main_menu_scroll = row_bottom - viewport.h + padding
	}
	ui.main_menu_scroll = min(max(ui.main_menu_scroll, 0), max_scroll)
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
		panel = {0.09, 0.11, 0.13, 0.24},
		panel_top = {0.70, 0.78, 0.86, 0.22},
		surface = {0.08, 0.10, 0.12, 0.34},
		surface_hot = {0.18, 0.21, 0.24, 0.40},
		surface_selected = {0.24, 0.28, 0.32, 0.46},
		preview_surface = {0.018, 0.022, 0.028, 1.0},
		footer_surface = {0.09, 0.11, 0.13, 0.24},
		border = {1.00, 1.00, 1.00, 0.18},
		border_hot = {1.00, 1.00, 1.00, 0.58},
		accent = {1.00, 1.00, 1.00, 1.0},
		accent_soft = {1.00, 1.00, 1.00, 0.20},
		text = {1.00, 1.00, 1.00, 1.0},
		text_muted = {0.90, 0.90, 0.90, 0.88},
		text_dim = {1.00, 1.00, 1.00, 0.68},
		chip = {0.08, 0.10, 0.12, 0.28},
		chip_border = {1.0, 1.0, 1.0, 0.20},
		danger = {0.90, 0.18, 0.16, 1.0},
		shadow = {0, 0, 0, 0.42},
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
		radius = max(gui.style.radius_panel, f32(5)),
		card_radius = max(gui.style.radius_control, f32(5)),
		border_width = 1,
		start_width = 0,
	}
}

app_ui_draw_main_menu_backdrop :: proc(gui: ^uifw.Gui_Context, bounds: uifw.Rect, theme: Menu_Theme) {
	_ = gui
	_ = bounds
	_ = theme
}

app_ui_menu_glass_style :: proc(gui: ^uifw.Gui_Context, theme: Menu_Theme, radius: f32, emphasis: f32 = 0) -> uifw.Gui_Glass_Style {
	glass := uifw.gui_default_glass_style(gui, radius)
	t := uifw.gui_clamp01(emphasis)
	glass.tint = uifw.gui_lerp_color(theme.surface, theme.surface_selected, t)
	glass.tint.a = 0.34 + t * 0.14
	glass.roughness = 0.42 + t * 0.18
	glass.thickness = max(gui.style.rhythm * (0.18 + t * 0.06), f32(7))
	glass.bevel = max(gui.style.border_width * (5.5 + t * 1.5), f32(5))
	glass.dispersion = 0.70 + t * 0.35
	glass.border = 0.28 + t * 0.34
	glass.highlight = 0.34 + t * 0.22
	return glass
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
	glass := app_ui_menu_glass_style(gui, theme, theme.card_radius, hot_t)
	glass.tint = fill
	uifw.gui_shadow(gui, rect, theme.card_radius, {0, theme.small_gap * 0.65}, theme.inner_gap, theme.shadow)
	uifw.gui_refractive_glass_rect(gui, rect, glass)
	uifw.gui_round_stroke(gui, rect, theme.card_radius, border, theme.border_width)
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
	if hot_t > 0.01 || control.focused {
		glass := app_ui_menu_glass_style(gui, theme, theme.card_radius, hot_t)
		glass.tint.a = 0.12 + hot_t * 0.08
		uifw.gui_refractive_glass_rect(gui, button, glass)
	}
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
	pause_consumed := simulation_controller_ui_update_input(ui, gui)
	if gui.input.pause && !pause_consumed {
		sim.settings.paused = !sim.settings.paused
	}
	particle_life_draw_blob_overlay(sim, gui, width, height)
	if ui.simulation_shell.controls_visible {
		app_ui_draw_simulation_bar(ui, gui, .Particle_Life, nil, sim, nil, sim.settings.paused, !sim.gpu.ready, "Particle Life", vk_ctx, width, worker)
	}
	simulation_controller_ui_draw(ui, gui, particle = sim, width = width, height = height, worker = worker)
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
	row_gap := gui.style.spacing
	content_h := f32(len(APP_SIMULATION_NAMES)) * theme.row_height + f32(max(len(APP_SIMULATION_NAMES) - 1, 0)) * row_gap
	viewport := bounds
	if ui.main_menu_focus_navigation_active {
		app_ui_main_menu_scroll_simulation_into_view(ui, viewport, content_h, row_gap, theme)
	}
	uifw.gui_scroll_begin(gui, viewport, content_h, &ui.main_menu_scroll)
	uifw.gui_push_id(gui, "main_menu_simulations")
	if ui.main_menu_focus_navigation_active {
		if index, ok := app_ui_main_menu_simulation_index_for_slot(ui.main_menu_focus_slot); ok {
			gui.focused = uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", index))
		} else {
			for i in 0 ..< len(APP_SIMULATION_NAMES) {
				if gui.focused == uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", i)) {
					gui.focused = uifw.GUI_ID_NONE
					break
				}
			}
		}
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
		ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(hovered_index)
		gui.focused = uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", hovered_index))
	}
	for i in 0 ..< len(APP_SIMULATION_NAMES) {
		row := rows[i]
		selected := i == ui.main_menu_selected
		if app_ui_draw_simulation_row(ui, gui, row, viewport, i, selected, theme) {
			ui.main_menu_selected = i
			ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(i)
			app_ui_navigate(ui, app_ui_mode_for_simulation_index(i))
		}
		id := uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", i))
		if gui.focused == id {
			ui.main_menu_selected = i
			ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(i)
		}
	}
	for i in 0 ..< len(APP_SIMULATION_NAMES) {
		id := uifw.gui_make_id(gui, fmt.tprintf("simulation_%d", i))
		if gui.focused == id {
			ui.main_menu_selected = i
			ui.main_menu_focus_slot = app_ui_main_menu_slot_for_simulation_index(i)
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
	emphasis := max(hover_t, selected_t)
	if !live_preview {
		uifw.gui_refractive_glass_rect(gui, card, app_ui_menu_glass_style(gui, theme, theme.card_radius, emphasis))
	}

	preview := uifw.gui_inset(card, theme.border_width)
	clipped_preview := uifw.gui_rect_intersection(preview, clip_bounds)
	if clipped_preview.w > 1 && clipped_preview.h > 1 {
		app_ui_draw_live_simulation_preview(ui, gui, preview, clipped_preview, mode, theme.preview_surface, f32(index))
	}
	if live_preview {
		uifw.gui_refractive_glass_rect(gui, card, app_ui_menu_glass_style(gui, theme, theme.card_radius, emphasis))
	}
	uifw.gui_round_stroke(gui, card, theme.card_radius, border, theme.border_width)

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

app_ui_draw_options :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, vk_ctx: ^engine.Vk_Context, worker: ^Render_Worker_State) {
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

app_ui_draw_gray_scott :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, sim: ^Gray_Scott_Simulation, vk_ctx: ^engine.Vk_Context, worker: ^Render_Worker_State) {
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

// The header and Control Deck are one simulation-chrome layer.  The deck
// fields remain on the per-simulation states for panel/focus bookkeeping, but
// callers must not independently decide whether the header and its tabs exist.
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
	bar_rect := uifw.Rect{0, 0, width, app_ui_simulation_bar_height(gui)}
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
	route := app_ui_resolve_input_context(ui, gui, input)
	// A deliberate canvas click transfers ownership from keyboard/controller UI
	// navigation back to the simulation. Pointer motion alone never steals focus.
	if input.active_device == .Mouse_Keyboard &&
	   input.mouse_pressed &&
	   route.pointer_owner == .Simulation_Canvas &&
	   route.active_context < .Value_Edit {
		app_ui_hide_unfocused_simulation_ui(ui)
		gui.focused = uifw.GUI_ID_NONE
		route = app_ui_resolve_input_context(ui, gui, input)
	}
	ui.input_route = route
	shell_input := input
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
		filtered.wheel_delta = 0
		filtered.actions.primary = {}
		filtered.actions.secondary = {}
		ui.simulation_shell.mouse_pressed = false
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
	if input.mouse_released {
		ui.simulation_shell.mouse_pressed = false
	}
	if ui.simulation_shell.mouse_pressed && route.pointer_over_ui {
		filtered.mouse_down = false
		filtered.mouse_pressed = false
		filtered.mouse_released = true
		filtered.mouse_button = ui.simulation_shell.mouse_button
		ui.simulation_shell.mouse_pressed = false
	} else if !ui.simulation_shell.mouse_pressed && route.pointer_over_ui {
		filtered.mouse_down = false
		filtered.mouse_pressed = false
		filtered.mouse_released = false
	}
	if route.pointer_over_ui {
		filtered.wheel_delta = 0
		filtered.primary_down = filtered.mouse_down && filtered.mouse_button != 3
		filtered.primary_pressed = filtered.mouse_pressed && filtered.mouse_button != 3
		filtered.primary_released = filtered.mouse_released && filtered.mouse_button != 3
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
	return filtered
}

app_ui_draw_simulation_bar :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, mode: App_Mode, gray_scott: ^Gray_Scott_Simulation, particle_life: ^Particle_Life_Simulation, remaining: ^Remaining_Sim_State, paused, loading: bool, simulation_name: string, vk_ctx: ^engine.Vk_Context, width: f32, worker: ^Render_Worker_State) {
	_ = vk_ctx
	bar_h := app_ui_simulation_bar_height(gui)
	bar := uifw.Rect{0, 0, width, bar_h}
	glass := uifw.gui_default_glass_style(gui, 0)
	glass.tint = {0.06, 0.08, 0.10, 0.68}
	glass.radius = 0
	glass.roughness = 0.62
	glass.thickness = max(gui.style.rhythm * 0.22, f32(8))
	glass.bevel = max(gui.style.border_width * 6, f32(6))
	glass.border = 0.36
	glass.highlight = 0.38
	uifw.gui_refractive_glass_rect(gui, bar, glass)
	uifw.gui_stroke(gui, {0, bar_h - gui.style.border_width, width, gui.style.border_width}, {1, 1, 1, 0.10})

	scale := app_ui_simulation_bar_scale(gui)
	button_h := min(gui.style.row_height, max(bar_h - gui.style.spacing_2 * 2, 1))
	gap := gui.style.spacing_2
	x := gui.style.spacing_2
	y := (bar_h - button_h) * 0.5
	back_w := uifw.gui_button_content_width(gui, "Back to Menu")
	help_w := uifw.gui_button_content_width(gui, "Help")
	pause_label := paused ? "Resume" : "Pause"
	pause_w := uifw.gui_button_content_width(gui, pause_label)
	record_visible := worker != nil && app_ui_mode_allows_video_recording(mode)
	record_label := app_ui_video_recording_button_label(ui)
	record_w := record_visible ? uifw.gui_button_content_width(gui, record_label) : f32(0)
	back_rect := uifw.Rect{x, y, back_w, button_h}
	help_rect := uifw.Rect{back_rect.x + back_w + gap, y, help_w, button_h}
	pause_rect := uifw.Rect{max(width * 0.5 - pause_w * 0.5, help_rect.x + help_rect.w + gap), y, pause_w, button_h}
	record_rect := uifw.Rect{pause_rect.x + pause_rect.w + gap, y, record_w, button_h}

	uifw.gui_push_id(gui, "simulation_bar")
	if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "back"), back_rect, "Back to Menu", true, false) {
		app_ui_video_recording_stop(ui, worker)
		app_ui_navigate(ui, .Main_Menu)
	}
	if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "help"), help_rect, "Help", true, false) {
		app_ui_open_controls_help(ui, gui)
	}
	if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "pause"), pause_rect, pause_label, true, false) {
		app_ui_simulation_set_paused(mode, gray_scott, particle_life, remaining, !paused)
	}
	if record_visible {
		if ui.video_recording_state == .Restoring_Fullscreen {
			uifw.gui_text_aligned(gui, app_ui_simulation_bar_text_rect(gui, record_rect), record_label, gui.style.text_muted, .Center)
		} else if uifw.gui_button_at(gui, uifw.gui_make_id(gui, "record"), record_rect, record_label, true, false) {
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

app_ui_save_settings :: proc(ui: ^App_Ui_State, worker: ^Render_Worker_State) {
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

app_ui_mark_settings_changed :: proc(ui: ^App_Ui_State, worker: ^Render_Worker_State) {
	ui.settings_dirty = true
	app_ui_publish_settings_changed(ui, worker)
}

app_ui_reset_settings_to_defaults :: proc(ui: ^App_Ui_State, worker: ^Render_Worker_State) {
	ui.settings = settings_default()
	ui.menu_position_index = option_index(ui.settings.menu_position, MENU_POSITION_OPTIONS[:], 1)
	ui.texture_filtering_index = option_index(ui.settings.texture_filtering, TEXTURE_FILTERING_OPTIONS[:], 0)
	ui.controller_face_layout_index = option_index(ui.settings.controller_face_layout, CONTROLLER_FACE_LAYOUT_OPTIONS[:], 0)
	ui.controller_menu_layout_index = option_index(ui.settings.controller_menu_layout, CONTROLLER_MENU_LAYOUT_OPTIONS[:], 0)
	ui.controller_shoulder_layout_index = option_index(ui.settings.controller_shoulder_layout, CONTROLLER_SHOULDER_LAYOUT_OPTIONS[:], 0)
	ui.keyboard_shortcut_profile_index = option_index(ui.settings.keyboard_shortcut_profile, KEYBOARD_SHORTCUT_PROFILE_OPTIONS[:], 0)
	app_ui_mark_settings_changed(ui, worker)
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

app_ui_options_section_rail_columns :: proc(gui: ^uifw.Gui_Context, width: f32) -> int {
	min_tab_w := max(gui.style.body_char_width * 11, gui.style.row_height * 2.2)
	return uifw.gui_responsive_columns(width, min_tab_w, len(OPTIONS_SECTION_LABELS), gui.style.spacing)
}

app_ui_options_section_rail_height :: proc(gui: ^uifw.Gui_Context, width: f32) -> f32 {
	columns := app_ui_options_section_rail_columns(gui, width)
	rows := (len(OPTIONS_SECTION_LABELS) + columns - 1) / columns
	return f32(rows) * gui.style.row_height + f32(max(rows - 1, 0)) * gui.style.spacing
}

app_ui_draw_options_section_rail :: proc(gui: ^uifw.Gui_Context, width: f32, current: ^int) -> bool {
	rail_h := app_ui_options_section_rail_height(gui, width)
	rail := uifw.gui_next_rect(gui, height = rail_h)
	columns := app_ui_options_section_rail_columns(gui, width)
	rows := (len(OPTIONS_SECTION_LABELS) + columns - 1) / columns
	changed := false
	uifw.gui_push_id(gui, "options_sections")
	for row in 0 ..< rows {
		row_start := row * columns
		row_count := min(columns, len(OPTIONS_SECTION_LABELS) - row_start)
		item_w := max((rail.w - gui.style.spacing * f32(max(row_count - 1, 0))) / f32(row_count), 1)
		y := rail.y + f32(row) * (gui.style.row_height + gui.style.spacing)
		for col in 0 ..< row_count {
			index := row_start + col
			rect := uifw.Rect{rail.x + f32(col) * (item_w + gui.style.spacing), y, item_w, gui.style.row_height}
			if app_ui_options_section_button(gui, rect, OPTIONS_SECTION_LABELS[index], OPTIONS_SECTION_KEYS[index], current^ == index) {
				current^ = index
				changed = true
			}
		}
	}
	uifw.gui_pop_id(gui)
	return changed
}

app_ui_options_section_button :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, label, key: string, selected: bool) -> bool {
	id := uifw.gui_make_id(gui, key)
	control := uifw.gui_control(gui, id, rect, true)

	fill := selected ? uifw.gui_lerp_color(gui.style.control, gui.style.accent, 0.32) : gui.style.control
	border := selected ? uifw.gui_apply_opacity(gui.style.accent, 0.84) : gui.style.panel_border
	stroke_w := selected ? max(gui.style.border_width * 2, 2) : gui.style.border_width
	if gui.active == id {
		fill = uifw.gui_lerp_color(gui.style.control_hot, gui.style.accent, 0.24)
		border = uifw.gui_apply_opacity(gui.style.accent, 0.82)
		stroke_w = max(gui.style.border_width * 2, 2)
	} else if control.hovered || control.focused {
		fill = selected ? uifw.gui_lerp_color(gui.style.control_hot, gui.style.accent, 0.22) : gui.style.control_hot
		border = control.focused || selected ? uifw.gui_apply_opacity(gui.style.accent, 0.78) : uifw.gui_apply_opacity(gui.style.text, 0.46)
		stroke_w = max(gui.style.border_width * 2, 2)
	}

	uifw.gui_round_rect(gui, rect, gui.style.radius_control, fill)
	uifw.gui_round_stroke(gui, rect, gui.style.radius_control, border, stroke_w)
	if control.focused {
		uifw.gui_focus_ring(gui, rect)
	}
	uifw.gui_text_centered(gui, uifw.gui_inset(rect, gui.style.spacing_1), label, selected ? gui.style.text : gui.style.text_muted)

	return control.activated || (control.hovered && gui.active == id && gui.input.mouse_released)
}

app_ui_draw_options_active_section :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, worker: ^Render_Worker_State) {
	switch ui.options_section_index {
	case 0:
		app_ui_draw_options_display(ui, gui, worker)
	case 1:
		app_ui_draw_options_window(ui, gui, worker)
	case 2:
		app_ui_draw_options_interface(ui, gui, worker)
	case 3:
		app_ui_draw_options_input(ui, gui, worker)
	case 4:
		app_ui_draw_options_camera(ui, gui, worker)
	case:
		app_ui_draw_options_display(ui, gui, worker)
	}
}

app_ui_draw_options_display :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, worker: ^Render_Worker_State) {
	uifw.gui_heading(gui, "Display")
	uifw.gui_push_id(gui, "display")
	if uifw.gui_toggle(gui, "FPS Limiter", "fps_limiter", &ui.settings.default_fps_limit_enabled) {
		app_ui_mark_settings_changed(ui, worker)
	}
	fps_limit := f32(ui.settings.default_fps_limit)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("FPS Limit: %d", ui.settings.default_fps_limit), "fps_limit", &fps_limit, 1, 1, 1200, ui.settings.default_fps_limit_enabled) {
		ui.settings.default_fps_limit = i32(fps_limit)
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("UI Scale: %.1f", ui.settings.ui_scale), "ui_scale", &ui.settings.ui_scale, 0.1, 0.5, 3.0) {
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_selector(gui, fmt.tprintf("Texture Filtering: %s", TEXTURE_FILTERING_OPTIONS[ui.texture_filtering_index]), "texture_filtering", &ui.texture_filtering_index, TEXTURE_FILTERING_OPTIONS[:]) {
		ui.settings.texture_filtering = TEXTURE_FILTERING_OPTIONS[ui.texture_filtering_index]
		app_ui_mark_settings_changed(ui, worker)
	}
	uifw.gui_pop_id(gui)
}

app_ui_draw_options_window :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, worker: ^Render_Worker_State) {
	uifw.gui_heading(gui, "Window Defaults")
	uifw.gui_push_id(gui, "window")
	width := f32(ui.settings.window_width)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Default Width: %d", ui.settings.window_width), "width", &width, 50, 800, 3840) {
		ui.settings.window_width = i32(width)
		app_ui_mark_settings_changed(ui, worker)
	}
	height := f32(ui.settings.window_height)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Default Height: %d", ui.settings.window_height), "height", &height, 50, 600, 2160) {
		ui.settings.window_height = i32(height)
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_toggle(gui, "Start Maximized", "maximized", &ui.settings.window_maximized) {
		app_ui_mark_settings_changed(ui, worker)
	}
	uifw.gui_pop_id(gui)
}

app_ui_draw_options_interface :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, worker: ^Render_Worker_State) {
	uifw.gui_heading(gui, "Interface")
	uifw.gui_push_id(gui, "ui_behavior")
	delay := f32(ui.settings.auto_hide_delay)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("UI Hide Delay: %d ms", ui.settings.auto_hide_delay), "auto_hide_delay", &delay, 500, 1000, 10000) {
		ui.settings.auto_hide_delay = i32(delay)
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_selector(gui, fmt.tprintf("Menu Position: %s", MENU_POSITION_OPTIONS[ui.menu_position_index]), "menu_position", &ui.menu_position_index, MENU_POSITION_OPTIONS[:]) {
		ui.settings.menu_position = MENU_POSITION_OPTIONS[ui.menu_position_index]
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_toggle(gui, "Remember Controller Focus", "remember_controller_focus", &ui.settings.remember_controller_focus) {
		app_ui_mark_settings_changed(ui, worker)
	}
	uifw.gui_pop_id(gui)
}

app_ui_draw_options_camera :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, worker: ^Render_Worker_State) {
	uifw.gui_heading(gui, "Camera")
	uifw.gui_push_id(gui, "camera")
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Keyboard / Wheel Sensitivity: %.1f", ui.settings.default_camera_sensitivity), "sensitivity", &ui.settings.default_camera_sensitivity, 0.1, 0.1, 5.0) {
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Controller Sensitivity: %.1f", ui.settings.controller_camera_sensitivity), "controller_sensitivity", &ui.settings.controller_camera_sensitivity, 0.1, 0.1, 5.0) {
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_toggle(gui, "Invert Controller Y", "controller_invert_y", &ui.settings.controller_camera_invert_y) {
		app_ui_mark_settings_changed(ui, worker)
	}
	uifw.gui_pop_id(gui)
}

app_ui_keyboard_action_label :: proc(action: Keyboard_Shortcut_Action) -> string {
	switch action {
	case .Pause: return "Pause"
	case .Toggle_Ui: return "Toggle UI"
	case .Help: return "Help"
	}
	return "Shortcut"
}

app_ui_assign_keyboard_binding :: proc(ui: ^App_Ui_State, action: Keyboard_Shortcut_Action, key: Keyboard_Shortcut_Key, worker: ^Render_Worker_State) {
	if !settings_keyboard_binding_allowed(action, key) {
		write_fixed_string(ui.keyboard_binding_notice[:], "Space is reserved for Pause + Control Deck")
		return
	}
	displaced, swapped := settings_assign_keyboard_binding(&ui.settings, action, key)
	if swapped {
		write_fixed_string(ui.keyboard_binding_notice[:], fmt.tprintf("Reassigned %s to avoid a duplicate key", app_ui_keyboard_action_label(displaced)))
	} else {
		write_fixed_string(ui.keyboard_binding_notice[:], fmt.tprintf("%s now uses %s", app_ui_keyboard_action_label(action), keyboard_shortcut_key_name(key)))
	}
	ui.keyboard_shortcut_profile_index = option_index(ui.settings.keyboard_shortcut_profile, KEYBOARD_SHORTCUT_PROFILE_OPTIONS[:], 2)
	app_ui_mark_settings_changed(ui, worker)
}

app_ui_draw_options_input :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, worker: ^Render_Worker_State) {
	uifw.gui_heading(gui, "Input Bindings and Navigation")
	uifw.gui_push_id(gui, "input")
	if uifw.gui_selector(gui, fmt.tprintf("Keyboard Shortcuts: %s", KEYBOARD_SHORTCUT_PROFILE_OPTIONS[ui.keyboard_shortcut_profile_index]), "keyboard_shortcut_profile", &ui.keyboard_shortcut_profile_index, KEYBOARD_SHORTCUT_PROFILE_OPTIONS[:]) {
		settings_apply_keyboard_profile(&ui.settings, KEYBOARD_SHORTCUT_PROFILE_OPTIONS[ui.keyboard_shortcut_profile_index])
		write_fixed_string(ui.keyboard_binding_notice[:], "Profile applied")
		app_ui_mark_settings_changed(ui, worker)
	}
	pause_binding_index := int(ui.settings.keyboard_pause_binding)
	if uifw.gui_selector(gui, fmt.tprintf("Pause: %s", keyboard_shortcut_key_name(ui.settings.keyboard_pause_binding)), "keyboard_pause_binding", &pause_binding_index, KEYBOARD_SHORTCUT_KEY_OPTIONS[:]) {
		app_ui_assign_keyboard_binding(ui, .Pause, Keyboard_Shortcut_Key(pause_binding_index), worker)
	}
	toggle_binding_index := int(ui.settings.keyboard_toggle_ui_binding)
	if uifw.gui_selector(gui, fmt.tprintf("Toggle UI: %s", keyboard_shortcut_key_name(ui.settings.keyboard_toggle_ui_binding)), "keyboard_toggle_ui_binding", &toggle_binding_index, KEYBOARD_SHORTCUT_KEY_OPTIONS[:]) {
		app_ui_assign_keyboard_binding(ui, .Toggle_Ui, Keyboard_Shortcut_Key(toggle_binding_index), worker)
	}
	help_binding_index := int(ui.settings.keyboard_help_binding)
	if uifw.gui_selector(gui, fmt.tprintf("Help: %s", keyboard_shortcut_key_name(ui.settings.keyboard_help_binding)), "keyboard_help_binding", &help_binding_index, KEYBOARD_SHORTCUT_KEY_OPTIONS[:]) {
		app_ui_assign_keyboard_binding(ui, .Help, Keyboard_Shortcut_Key(help_binding_index), worker)
	}
	binding_notice := fixed_string(ui.keyboard_binding_notice[:])
	if len(binding_notice) == 0 {binding_notice = "Duplicate keys swap automatically. Space is reserved for Pause + Control Deck."}
	uifw.gui_label(gui, binding_notice)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Stick Deadzone: %.2f", ui.settings.controller_deadzone), "controller_deadzone", &ui.settings.controller_deadzone, 0.01, 0.05, 0.60) {
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Virtual Cursor Speed: %.2f", ui.settings.controller_cursor_speed), "controller_cursor_speed", &ui.settings.controller_cursor_speed, 0.05, 0.20, 2.0) {
		app_ui_mark_settings_changed(ui, worker)
	}
	repeat_delay := f32(ui.settings.navigation_repeat_delay_ms)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Repeat Delay: %d ms", ui.settings.navigation_repeat_delay_ms), "navigation_repeat_delay", &repeat_delay, 25, 150, 1000) {
		ui.settings.navigation_repeat_delay_ms = i32(repeat_delay)
		app_ui_mark_settings_changed(ui, worker)
	}
	repeat_interval := f32(ui.settings.navigation_repeat_interval_ms)
	if uifw.gui_number_drag_f32(gui, fmt.tprintf("Repeat Interval: %d ms", ui.settings.navigation_repeat_interval_ms), "navigation_repeat_interval", &repeat_interval, 10, 30, 300) {
		ui.settings.navigation_repeat_interval_ms = i32(repeat_interval)
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_selector(gui, fmt.tprintf("Accept / Back Layout: %s", CONTROLLER_FACE_LAYOUT_OPTIONS[ui.controller_face_layout_index]), "controller_face_layout", &ui.controller_face_layout_index, CONTROLLER_FACE_LAYOUT_OPTIONS[:]) {
		ui.settings.controller_face_layout = CONTROLLER_FACE_LAYOUT_OPTIONS[ui.controller_face_layout_index]
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_selector(gui, fmt.tprintf("Menu Buttons: %s", CONTROLLER_MENU_LAYOUT_OPTIONS[ui.controller_menu_layout_index]), "controller_menu_layout", &ui.controller_menu_layout_index, CONTROLLER_MENU_LAYOUT_OPTIONS[:]) {
		ui.settings.controller_menu_layout = CONTROLLER_MENU_LAYOUT_OPTIONS[ui.controller_menu_layout_index]
		app_ui_mark_settings_changed(ui, worker)
	}
	if uifw.gui_selector(gui, fmt.tprintf("Shoulders: %s", CONTROLLER_SHOULDER_LAYOUT_OPTIONS[ui.controller_shoulder_layout_index]), "controller_shoulder_layout", &ui.controller_shoulder_layout_index, CONTROLLER_SHOULDER_LAYOUT_OPTIONS[:]) {
		ui.settings.controller_shoulder_layout = CONTROLLER_SHOULDER_LAYOUT_OPTIONS[ui.controller_shoulder_layout_index]
		app_ui_mark_settings_changed(ui, worker)
	}
	uifw.gui_pop_id(gui)
}

app_ui_options_content_height :: proc(gui: ^uifw.Gui_Context, section_index: int) -> f32 {
	height := f32(0)
	item_count := 0
	control_count := 4
	switch section_index {
	case 0:
		control_count = 4
	case 1:
		control_count = 3
	case 2:
		control_count = 5
	case 3:
		control_count = 12
	case 4:
		control_count = 3
	case:
		control_count = 4
	}
	app_ui_options_measure_section(&height, &item_count, gui, control_count)

	return height + f32(max(item_count - 1, 0)) * gui.style.spacing
}

app_ui_options_measure_section :: proc(height: ^f32, item_count: ^int, gui: ^uifw.Gui_Context, control_count: int) {
	app_ui_options_measure_row(height, item_count, gui.style.heading_line_height)
	for _ in 0 ..< control_count {
		app_ui_options_measure_row(height, item_count, gui.style.row_height)
	}
}

app_ui_options_measure_row :: proc(height: ^f32, item_count: ^int, row_height: f32) {
	height^ += row_height
	item_count^ += 1
}

app_ui_options_footer_height :: proc(gui: ^uifw.Gui_Context, width: f32) -> f32 {
	action_rows := app_ui_options_footer_action_rows(gui, width)
	return gui.style.spacing_1 +
	       gui.style.body_line_height +
	       gui.style.spacing +
	       f32(action_rows) * gui.style.row_height +
	       f32(max(action_rows - 1, 0)) * gui.style.spacing
}

app_ui_options_footer_action_rows :: proc(gui: ^uifw.Gui_Context, width: f32) -> int {
	labels := [?]string{"Back to Menu", "Reset to Defaults", "Save"}
	row_count := 1
	row_w := f32(0)
	available := max(width, gui.style.row_height)
	for label in labels {
		w := min(uifw.gui_button_content_width(gui, label), available)
		if row_w > 0 && row_w + gui.style.spacing + w > available {
			row_count += 1
			row_w = w
		} else if row_w > 0 {
			row_w += gui.style.spacing + w
		} else {
			row_w = w
		}
	}
	return row_count
}

app_ui_draw_options_footer :: proc(ui: ^App_Ui_State, gui: ^uifw.Gui_Context, bounds: uifw.Rect, worker: ^Render_Worker_State) {
	uifw.gui_rect(gui, {bounds.x, bounds.y, bounds.w, gui.style.border_width}, {1, 1, 1, 0.16})

	status := ui.settings_dirty ? "Unsaved changes. Save to keep after restart." : "No unsaved changes."
	status_color := ui.settings_dirty ? gui.style.text : gui.style.text_muted
	status_rect := uifw.Rect{bounds.x, bounds.y + gui.style.spacing_1, bounds.w, gui.style.body_line_height}
	uifw.gui_text_clipped(gui, status_rect, {status_rect.x + gui.style.spacing_1, status_rect.y + max((status_rect.h - gui.style.body_text_height) * 0.5, 0)}, status, status_color)

	cursor := uifw.Vec2{bounds.x, status_rect.y + status_rect.h + gui.style.spacing}
	row_right := bounds.x + bounds.w
	if app_ui_options_footer_button(gui, "Back to Menu", "back", &cursor, bounds.x, row_right, gui.style.row_height, gui.style.spacing, true) {
		app_ui_navigate(ui, .Main_Menu)
	}
	if app_ui_options_footer_button(gui, "Reset to Defaults", "reset_defaults", &cursor, bounds.x, row_right, gui.style.row_height, gui.style.spacing, true) {
		app_ui_reset_settings_to_defaults(ui, worker)
	}
	if app_ui_options_footer_button(gui, "Save", "save", &cursor, bounds.x, row_right, gui.style.row_height, gui.style.spacing, ui.settings_dirty) {
		app_ui_save_settings(ui, worker)
	}
}

app_ui_options_footer_button :: proc(gui: ^uifw.Gui_Context, label, key: string, cursor: ^uifw.Vec2, row_left, row_right, row_height, gap: f32, enabled: bool) -> bool {
	available := max(row_right - row_left, 1)
	w := min(uifw.gui_button_content_width(gui, label), available)
	if cursor.x > row_left && cursor.x + w > row_right {
		cursor.x = row_left
		cursor.y += row_height + gap
	}
	rect := uifw.Rect{cursor.x, cursor.y, w, row_height}
	cursor.x += w + gap
	return uifw.gui_button_at(gui, uifw.gui_make_id(gui, key), rect, label, enabled)
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
