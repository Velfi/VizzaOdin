package game

import uifw "../ui"
import engine "../engine"

import "core:fmt"
import "core:math"
import sdl "vendor:sdl3"

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

Ui_Component_Fixture :: enum {
	None,
	Button,
	Toggle,
	Slider,
	Number,
	Integer,
	Selector,
	Text_Input,
}

Ui_Component_Fixture_State :: enum {
	Rest,
	Hover,
	Active,
	Focused,
	Editing,
	Disabled,
}

SIMULATION_BAR_HEIGHT :: f32(44)
SIMULATION_BAR_BASE_ROW_HEIGHT :: f32(44)
MAIN_MENU_PREVIEW_SLOT_CAP :: 16
MAIN_MENU_TEXT_BUTTON_SCALE_MULTIPLIER :: f32(1.85)
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
	simulation_exit_hold_seconds: f32,
	simulation_exit_hold_triggered: bool,
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
	main_menu_palette: Color_Scheme_Name,
	main_menu_focus_navigation_active: bool,
	main_menu_quit_hold_highlight: bool,
	options_section_index: int,
	options_scroll: f32,
	camera_device_index: int,
	camera_test: ^sdl.Camera,
	camera_test_frames: u64,
	camera_test_status: [128]u8,
	how_to_play_scroll: f32,
	how_to_play_demo_toggle: bool,
	how_to_play_demo_slider: f32,
	how_to_play_demo_number: f32,
	how_to_play_demo_selector: int,
	how_to_play_demo_button_count: int,
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
	component_fixture: Ui_Component_Fixture,
	component_fixture_state: Ui_Component_Fixture_State,
	component_fixture_value: f32,
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

HOW_TO_PLAY_INTRO :: "You do not need to understand every setting before touching it. Mess with things, push them too far, and see what happens—the fun is in experimenting. If you are not sure what to try next, hit Randomize. It will give you a fresh direction, and simulations that randomize settings let you restore what you had before."
HOW_TO_PLAY_DEMO_INTRO :: "Try these controls here. This playground does not change any simulation or saved setting. On the number control, use -/+ or drag to adjust, tap or type for an exact value, Shift or a light stick for fine control, Ctrl for broad keyboard control, and the controller Secondary action to cycle the visible step."
HOW_TO_PLAY_DEMO_SELECTOR_OPTIONS := [?]string{"Calm", "Curious", "Chaotic"}
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
	ui.how_to_play_demo_slider = 0.5
	ui.how_to_play_demo_number = 1
	ui.how_to_play_demo_selector = 1
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
	if ui.mode != .Options && ui.camera_test != nil {
		sdl.CloseCamera(ui.camera_test)
		ui.camera_test = nil
		ui.camera_test_frames = 0
	}
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
	isolated_component := ui.mode == .Theme_Preview && ui.component_fixture != .None
	if !isolated_component {
		app_ui_draw_device_notice(ui, gui)
		app_ui_draw_virtual_cursor(ui, gui)
	}
	if transitioning {
		gui.input = saved_input
		ui.frame_actions = saved_actions
	}
	if !isolated_component {
		app_ui_draw_mode_transition_overlay(ui, gui)
	}
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
