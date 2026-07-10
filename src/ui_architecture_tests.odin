package main

import game "../packages/game"
import host "../packages/app"
import engine "../packages/engine"
import rendervk "../packages/render_vk"
import uifw "../packages/ui"

import "core:math"
import "core:os"
import "core:testing"
import sdl "vendor:sdl3"
import vk "vendor:vulkan"

@(test)
test_controller_focus_regions_restore_memory_and_return_to_parent :: proc(t: ^testing.T) {
	state: uifw.Controller_Focus_State
	uifw.gui_controller_focus_init(&state, true)
	root := uifw.Gui_Id(11)
	child := uifw.Gui_Id(12)
	fallback := uifw.Gui_Id(21)
	remembered := uifw.Gui_Id(22)

	testing.expect_value(t, uifw.gui_controller_focus_enter_region(&state, root, uifw.GUI_ID_NONE, fallback), fallback)
	uifw.gui_controller_focus_remember(&state, root, remembered)
	testing.expect_value(t, uifw.gui_controller_focus_enter_region(&state, root, uifw.GUI_ID_NONE, fallback), remembered)
	_ = uifw.gui_controller_focus_enter_region(&state, child, root, fallback)
	testing.expect_value(t, state.phase, uifw.Controller_Focus_Phase.Child_Region)
	uifw.gui_controller_focus_activate(&state, remembered)
	testing.expect_value(t, state.phase, uifw.Controller_Focus_Phase.Active_Control)
	uifw.gui_controller_focus_deactivate(&state)
	testing.expect_value(t, state.phase, uifw.Controller_Focus_Phase.Child_Region)
	uifw.gui_controller_focus_leave_region(&state)
	testing.expect_value(t, state.region, root)
	testing.expect_value(t, state.phase, uifw.Controller_Focus_Phase.Region)
}

@(test)
test_slime_control_descriptors_validate_couch_ui :: proc(t: ^testing.T) {
	testing.expect(t, game.slime_control_couch_validation_passes())
	testing.expect(t, game.slime_control_visible_descriptor_count(.Couch) > 0)

	required := [?]game.Control_Instrument{.Play, .Look, .Brush, .Motion, .Awareness, .Field, .Birth, .World, .Presets}
	for instrument in required {
		testing.expect(t, game.slime_control_instrument_has_visible_controls(instrument, .Couch))
	}
}

@(test)
test_slime_descriptor_hides_known_ineffective_controls_from_couch :: proc(t: ^testing.T) {
	ids := [?]game.Control_Id{
		.Field_Decay_Frequency,
		.Field_Diffusion_Frequency,
		.Mask_Reversed,
		.Initialization_Heading_Range,
	}
	for id in ids {
		desc, ok := game.slime_control_descriptor_by_id(id)
		testing.expect(t, ok)
		testing.expect(t, game.control_is_broken_or_deprecated(desc))
		testing.expect(t, !game.control_is_visible_in_couch_ui(desc))
	}
}

@(test)
test_slime_visible_descriptor_validation_rejects_missing_metadata :: proc(t: ^testing.T) {
	desc, ok := game.slime_control_descriptor_by_id(.Brush_Radius)
	testing.expect(t, ok)
	testing.expect(t, game.control_descriptor_is_valid_for_visible_ui(desc))

	bad := desc
	bad.label = ""
	testing.expect(t, !game.control_descriptor_is_valid_for_visible_ui(bad))

	bad = desc
	bad.semantic_group = game.Semantic_Group(999)
	testing.expect(t, !game.control_descriptor_is_valid_for_visible_ui(bad))

	bad = desc
	bad.range.max = bad.range.min
	testing.expect(t, !game.control_descriptor_is_valid_for_visible_ui(bad))

	bad = desc
	bad.wiring_status = .ExposedIneffective
	testing.expect(t, !game.control_descriptor_is_valid_for_visible_ui(bad))
}

@(test)
test_slime_controller_deck_draw_does_not_steal_panel_focus :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = true
	ui.slime_controller.focused_index = 2
	ui.slime_controller.active_index = 2
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720})
	panel_focus := uifw.gui_make_id(&ctx, "panel_control")
	ctx.focused = panel_focus
	worker: host.Render_Worker_State
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)

	testing.expect_value(t, ctx.focused, panel_focus)
}

@(test)
test_slime_controller_deck_accept_ignores_non_deck_panel_focus :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = true
	ui.slime_controller.focused_index = 1
	ui.slime_controller.active_index = 2

	uifw.gui_begin_frame(&ctx, {accept = true})
	ctx.focused = uifw.gui_make_id(&ctx, "panel_control")
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)

	testing.expect_value(t, ui.slime_controller.active_index, 2)
}

@(test)
test_slime_controller_long_world_panel_scrolls :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Slime_Mold
	ui.slime_mold.slime.mask_pattern = .Image
	ui.slime_mold.slime.mask_pattern_index = int(game.Slime_Mask_Pattern.Image)
	ui.slime_controller.panel_open = true
	ui.slime_controller.deck_visible = true
	ui.slime_controller.focused_index = 5
	ui.slime_controller.active_index = 5
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 800, 360, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 800, window_height = 360, mouse_pos = {40, 110}, wheel_delta = -5})
	worker: host.Render_Worker_State
	game.slime_controller_ui_draw_panel(&ui, &ctx, &ui.slime_mold, {0, 0, 620, 180}, &worker)

	testing.expect(t, ui.slime_controller.panel_scroll > 0)
}

@(test)
test_slime_controller_ui_replaces_old_slime_panel_when_enabled :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.simulation_shell.show_ui = true
	ui.slime_controller.deck_visible = true
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1200, height = 800}
	worker: host.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1200, 800, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1200, window_height = 800})
	game.app_ui_draw_remaining_sim(&ui, &ctx, .Slime_Mold, &ui.slime_mold, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, test_first_text_command_index(ctx.commands[:], "About this simulation") < 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Agents") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Look") >= 0)
}

@(test)
test_slime_controller_ui_disables_hidden_old_panel_hit_test :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.simulation_shell.show_ui = true
	ui.simulation_shell.controls_visible = true
	ui.slime_controller.deck_visible = false
	ui.slime_controller.panel_open = false
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1600, 900, ui.settings.ui_scale)

	old_panel := game.app_ui_simulation_menu_panel(&ui, &ctx, 1600, 900)
	input := game.Ui_Frame_Input {
		window_width = 1600,
		window_height = 900,
		mouse_pos = {old_panel.x + old_panel.w * 0.5, old_panel.y + old_panel.h * 0.5},
		mouse_pressed = true,
		mouse_down = true,
	}
	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, input)

	testing.expect(t, filtered.mouse_pressed)
	testing.expect(t, filtered.mouse_down)
	testing.expect(t, ui.simulation_shell.mouse_pressed)
}

@(test)
test_slime_controller_preset_save_dialog_consumes_simulation_input :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = true
	ui.slime_mold.preset_ui.save_open = true
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1600, 900, ui.settings.ui_scale)

	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1600,
		window_height = 900,
		mouse_pos = {32, 420},
		mouse_pressed = true,
		mouse_down = true,
	})

	testing.expect(t, !filtered.mouse_pressed)
	testing.expect(t, !filtered.mouse_down)
	testing.expect(t, !ui.simulation_shell.mouse_pressed)
}

@(test)
test_slime_controller_deck_tabs_bound_key_and_label_text :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = false
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 2048, 1152, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 2048, window_height = 1152})
	worker: host.Render_Worker_State
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 2048, 1152, &worker)
	uifw.gui_end_frame(&ctx)

	labels := [?]string{"Presets", "Look", "Agents", "Trails", "Brush", "World"}
	found := 0
	icon_count := 0
	active_clip: uifw.Rect
	clip_active := false
	for command in ctx.commands {
		#partial switch command.kind {
		case .Scissor_Begin:
			active_clip = command.rect
			clip_active = true
		case .Scissor_End:
			clip_active = false
		case .Text:
			for label in labels {
				if command.text == label {
					testing.expect(t, clip_active)
					testing.expect(t, command.rect.x >= active_clip.x)
					testing.expect(t, command.rect.y >= active_clip.y)
					testing.expect(t, command.rect.x + command.rect.w <= active_clip.x + active_clip.w + 0.5)
					testing.expect(t, command.rect.y + command.rect.h <= active_clip.y + active_clip.h + 0.5)
					found += 1
				}
			}
		case .Image:
			if command.image_id == uifw.Gui_Image_Id(rendervk.UI_CONTROLLER_ICON_ATLAS_TEXTURE_ID) {
				testing.expect(t, clip_active)
				testing.expect(t, command.rect.x >= active_clip.x)
				testing.expect(t, command.rect.y >= active_clip.y)
				testing.expect(t, command.rect.x + command.rect.w <= active_clip.x + active_clip.w + 0.5)
				testing.expect(t, command.rect.y + command.rect.h <= active_clip.y + active_clip.h + 0.5)
				testing.expect(t, command.rect.h >= ctx.style.row_height * 0.85)
				icon_count += 1
			}
		case:
		}
	}
	testing.expect_value(t, found, len(labels))
	testing.expect_value(t, icon_count, len(labels))
}

@(test)
test_simulation_controller_tabs_use_semantic_icons :: proc(t: ^testing.T) {
	labels := [?]string {
		"Presets", "Look", "Pattern", "Mask", "Brush", "Camera", "Forces", "Physics",
		"Population", "Advanced", "Field", "Particles", "Trails", "Sites", "Flow", "Motion",
	}
	expected := [?]rendervk.Ui_Controller_Icon {
		.Presets, .Palette, .Pattern, .Mask, .Brush, .Camera, .Forces, .Physics,
		.Population, .Advanced, .Field, .Particles, .Trails, .Sites, .Flow, .Motion,
	}

	for label, i in labels {
		icon := game.simulation_controller_ui_tab_icon(label)
		testing.expect_value(t, icon, expected[i])
		for previous in 0 ..< i {
			testing.expect(t, icon != expected[previous])
		}
	}
}

@(test)
test_slime_controller_presets_panel_exposes_selector_and_save :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = true
	preset_index := 0
	ui.slime_controller.focused_index = preset_index
	ui.slime_controller.active_index = preset_index
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1600, 900, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1600, window_height = 900, mouse_pos = {-1000, -1000}})
	worker: host.Render_Worker_State
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1600, 900, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Presets") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Default") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Save Current Settings") >= 0)
}

@(test)
test_slime_controller_deck_tab_focus_moves_between_tabs :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = false
	ui.slime_controller.focused_index = 0
	ui.slime_controller.active_index = 0
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, key_tab = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	worker: host.Render_Worker_State
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ui.slime_controller.deck_visible)
	testing.expect(t, !ui.slime_controller.panel_open)
	testing.expect_value(t, ui.slime_controller.focused_index, 1)
	testing.expect_value(t, ui.slime_controller.active_index, 0)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_1"))

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, key_tab = true, key_shift = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ui.slime_controller.focused_index, 0)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_0"))
}

@(test)
test_slime_controller_deck_arrow_focus_moves_once :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = false
	ui.slime_controller.focused_index = 0
	ui.slime_controller.active_index = 0
	ctx.focused = uifw.gui_make_id(&ctx, "slime_deck_0")
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, key_right = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	worker: host.Render_Worker_State
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ui.slime_controller.focused_index, 1)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_1"))

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, key_left = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ui.slime_controller.focused_index, 0)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_0"))
}

@(test)
test_slime_controller_deck_tab_opens_hidden_deck_without_skipping_tab :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = false
	ui.slime_controller.panel_open = false
	ui.slime_controller.active_index = 2
	ui.slime_controller.focused_index = 2
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, key_tab = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	worker: host.Render_Worker_State
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ui.slime_controller.deck_visible)
	testing.expect(t, !ui.slime_controller.panel_open)
	testing.expect_value(t, ui.slime_controller.focused_index, 2)
	testing.expect_value(t, ui.slime_controller.active_index, 2)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_2"))
}

@(test)
test_slime_controller_unfocused_filter_preserves_camera_controls :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = false
	ui.slime_controller.focused_index = 0
	ui.slime_controller.active_index = 0
	ctx.focused = uifw.gui_make_id(&ctx, "slime_deck_0")
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, key_escape = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	uifw.gui_end_frame(&ctx)

	// Back leaves the shared utility-rail/tab chrome visible and only releases its
	// focus. Auto-hide owns the later transition to fully hidden chrome.
	testing.expect(t, ui.simulation_shell.controls_visible)
	testing.expect(t, ui.slime_controller.deck_visible)
	testing.expect(t, !ui.slime_controller.panel_open)
	testing.expect_value(t, ctx.focused, uifw.GUI_ID_NONE)

	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, {
		active_device = .Controller,
		window_width = 1280,
		window_height = 720,
		key_w = true,
		key_e = true,
		camera_reset = true,
		controller_left = {1, -1},
		controller_zoom = 1,
	})

	testing.expect(t, filtered.key_w)
	testing.expect(t, filtered.key_e)
	testing.expect(t, filtered.camera_reset)
	testing.expect_value(t, filtered.controller_left.x, f32(1))
	testing.expect_value(t, filtered.controller_left.y, f32(-1))
	testing.expect_value(t, filtered.controller_zoom, f32(1))
}

@(test)
test_slime_controller_deck_click_selects_tab_with_panel_focus :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = true
	ui.slime_controller.active_index = 0
	ui.slime_controller.focused_index = 0
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, ui.settings.ui_scale)

	deck := game.slime_controller_ui_deck_rect(&ctx, 1280, 720, ui.slime_controller.mode)
	count := game.slime_controller_ui_visible_instrument_count(ui.slime_controller.mode)
	gap := ctx.style.spacing
	tab_w := max((deck.w - gap * f32(count + 1)) / f32(count), f32(1))
	tab_h := max(deck.h - gap * 2, f32(1))
	target_index := 1
	tab := uifw.Rect{deck.x + gap + f32(target_index) * (tab_w + gap), deck.y + gap, tab_w, tab_h}
	click := uifw.Vec2{tab.x + tab.w * 0.5, tab.y + tab.h * 0.5}
	panel_focus := uifw.gui_make_id(&ctx, "panel_control")
	worker: host.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, mouse_pos = click, mouse_down = true, mouse_pressed = true})
	ctx.focused = panel_focus
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, mouse_pos = click, mouse_released = true})
	_ = game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1280, 720)
	game.slime_controller_ui_draw(&ui, &ctx, &ui.slime_mold, 1280, 720, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, ui.slime_controller.panel_open)
	testing.expect_value(t, ui.slime_controller.focused_index, target_index)
	testing.expect_value(t, ui.slime_controller.active_index, target_index)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_1"))
}

@(test)
test_slime_controller_space_focuses_bottom_bar :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_controller.deck_visible = false
	ui.slime_controller.panel_open = false
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1024, 768, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1024, window_height = 768, key_space = true})
	consumed := game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1024, 768)

	testing.expect(t, consumed)
	testing.expect(t, ui.slime_controller.deck_visible)
	testing.expect_value(t, ui.slime_controller.focused_index, ui.slime_controller.active_index)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_0"))
}

@(test)
test_slime_controller_select_focuses_bottom_bar_without_toggling_shell :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.simulation_shell.show_ui = true
	ui.slime_controller.deck_visible = false
	ui.slime_controller.panel_open = false
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1024, 768, ui.settings.ui_scale)

	game_input := game.Ui_Frame_Input{window_width = 1024, window_height = 768, active_device = .Controller, toggle_ui = true}
	game.app_ui_simulation_shell_update(&ui, game_input)

	uifw.gui_begin_frame(&ctx, {window_width = 1024, window_height = 768, active_device = .Controller, toggle_ui = true})
	consumed := game.slime_controller_ui_update_input(&ui, &ctx, &ui.slime_mold, 1024, 768)

	testing.expect(t, consumed)
	testing.expect(t, ui.simulation_shell.show_ui)
	testing.expect(t, ui.slime_controller.deck_visible)
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_0"))
}

@(test)
test_slime_controller_pause_focuses_utility_rail :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	ui.slime_mold.paused = false
	ui.slime_controller.deck_visible = true
	ui.slime_controller.panel_open = true
	ui.slime_controller.focus.phase = .Child_Region
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1024, height = 768}
	worker: host.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1024, 768, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1024, window_height = 768, active_device = .Controller, pause = true})
	game.app_ui_draw_remaining_sim(&ui, &ctx, .Slime_Mold, &ui.slime_mold, &vk_ctx, &worker)

	uifw.gui_push_id(&ctx, "simulation_bar")
	pause_id := uifw.gui_make_id(&ctx, "pause")
	uifw.gui_pop_id(&ctx)

	testing.expect_value(t, ctx.focused, pause_id)
	testing.expect(t, !ui.slime_mold.paused)
	testing.expect(t, ui.simulation_shell.controls_visible)
	testing.expect(t, ui.slime_controller.deck_visible)
	testing.expect_value(t, ui.slime_controller.focus.phase, uifw.Controller_Focus_Phase.Unfocused)
}

@(test)
test_simulation_utility_focus_relinquishes_deck_navigation :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Flow_Field
	state := game.simulation_controller_ui_state(&ui)
	state.deck_visible = true
	state.panel_open = true
	state.focus.phase = .Child_Region
	state.focused_index = 0

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1024, height = 768}
	worker: host.Render_Worker_State
	sim: game.Remaining_Sim_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1024, 768, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1024, window_height = 768, active_device = .Controller, pause = true})
	game.app_ui_draw_remaining_sim(&ui, &ctx, .Flow_Field, &sim, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, state.focus.phase, uifw.Controller_Focus_Phase.Unfocused)
	testing.expect(t, ui.simulation_shell.controls_visible)
	testing.expect(t, state.deck_visible)

	uifw.gui_begin_frame(&ctx, {window_width = 1024, window_height = 768, active_device = .Controller, key_right = true})
	game.app_ui_draw_remaining_sim(&ui, &ctx, .Flow_Field, &sim, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, state.focused_index, 0)
}

@(test)
test_slime_controller_ui_action_focuses_deck :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	ui.mode = .Slime_Mold
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1024, height = 768}
	worker: host.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1024, 768, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1024, window_height = 768, active_device = .Controller, toggle_ui = true})
	game.app_ui_draw_remaining_sim(&ui, &ctx, .Slime_Mold, &ui.slime_mold, &vk_ctx, &worker)

	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "slime_deck_0"))
}

@(test)
test_app_options_screen_uses_plain_toggle_labels_and_sticky_footer :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1200, height = 800}
	worker: host.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1200, 800, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1200, window_height = 800, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_options(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Options") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Display") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Window") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Interface") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Camera") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "FPS Limiter") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "FPS Limiter: false") < 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Start Maximized") < 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "Start Maximized: true") < 0)

	scroll_clip: uifw.Rect
	found_scroll_clip := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Scissor_Begin && command.rect.h > ctx.style.row_height * 2 {
			scroll_clip = command.rect
			found_scroll_clip = true
			break
		}
	}
	save_index := test_first_text_command_index(ctx.commands[:], "Save")
	testing.expect(t, found_scroll_clip)
	testing.expect(t, save_index >= 0)
	testing.expect(t, ctx.commands[save_index].rect.y > scroll_clip.y + scroll_clip.h)
}

@(test)
test_app_options_section_rail_switches_active_group :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1200, height = 800}
	worker: host.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1200, 800, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1200, window_height = 800, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_options(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	interface_index := test_first_text_command_index(ctx.commands[:], "Interface")
	testing.expect(t, interface_index >= 0)
	interface_rect := ctx.commands[interface_index].rect
	click := uifw.Vec2{interface_rect.x + interface_rect.w * 0.5, interface_rect.y + interface_rect.h * 0.5}

	uifw.gui_begin_frame(&ctx, {window_width = 1200, window_height = 800, mouse_pos = click, mouse_pressed = true, mouse_down = true})
	game.app_ui_draw_options(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {window_width = 1200, window_height = 800, mouse_pos = click, mouse_released = true})
	game.app_ui_draw_options(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ui.options_section_index, 2)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "UI Hide Delay: 3000 ms") >= 0)
	testing.expect(t, test_first_text_command_index(ctx.commands[:], "FPS Limiter") < 0)
}

@(test)
test_app_options_screen_mutes_disabled_fps_field_but_keeps_focus_hide_delay_available :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	settings := game.settings_default()
	settings.default_fps_limit_enabled = false
	ui: game.App_Ui_State
	game.app_ui_init(&ui, settings)
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1200, height = 800}
	worker: host.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1200, 800, ui.settings.ui_scale)

	uifw.gui_begin_frame(&ctx, {window_width = 1200, window_height = 800, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_options(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	saw_muted_fps_limit := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "FPS Limit: 60" && command.color.a == ctx.style.text_muted.a {
			saw_muted_fps_limit = true
		}
	}
	testing.expect(t, saw_muted_fps_limit)

	ui.options_section_index = 2
	uifw.gui_begin_frame(&ctx, {window_width = 1200, window_height = 800, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_options(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	saw_enabled_hide_delay := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "UI Hide Delay: 3000 ms" && command.color.a != ctx.style.text_muted.a {
			saw_enabled_hide_delay = true
		}
	}
	testing.expect(t, saw_enabled_hide_delay)
}

@(test)
test_app_options_reset_defaults_stays_unsaved_and_publishes_change :: proc(t: ^testing.T) {
	render_to_ui := new(game.Render_To_Ui_Queue)
	defer free(render_to_ui)
	worker: host.Render_Worker_State
	worker.render_to_ui = render_to_ui
	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.ui_scale = 1.8
	settings.default_fps_limit_enabled = true
	settings.menu_position = "right"
	settings.texture_filtering = "Nearest"
	game.app_ui_init(&ui, settings)
	ui.settings_dirty = false

	game.app_ui_reset_settings_to_defaults(&ui, &worker)

	testing.expect(t, ui.settings_dirty)
	testing.expect_value(t, ui.settings.ui_scale, f32(1.0))
	testing.expect_value(t, ui.settings.default_fps_limit_enabled, false)
	testing.expect_value(t, ui.menu_position_index, game.option_index(ui.settings.menu_position, game.MENU_POSITION_OPTIONS[:], 1))
	testing.expect_value(t, ui.texture_filtering_index, game.option_index(ui.settings.texture_filtering, game.TEXTURE_FILTERING_OPTIONS[:], 0))

	msg: game.Render_To_Ui_Message
	testing.expect(t, engine.queue_try_pop(render_to_ui, &msg))
	testing.expect_value(t, msg.kind, game.Render_To_Ui_Message_Kind.App_Settings_Changed)
	testing.expect(t, !engine.queue_try_pop(render_to_ui, &msg))
}

@(test)
test_app_settings_defaults_are_tv_readable :: proc(t: ^testing.T) {
	settings := game.settings_default()

	testing.expect_value(t, settings.ui_scale, f32(1.0))
	testing.expect_value(t, settings.window_width, i32(1920))
	testing.expect_value(t, settings.window_height, i32(1080))
	testing.expect(t, settings.window_maximized)
}

@(test)
test_gui_style_for_viewport_computes_h_fraction_typography :: proc(t: ^testing.T) {
	style := uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1)

	testing.expect_value(t, style.display_text_height, f32(90))
	testing.expect_value(t, style.heading_text_height, f32(45))
	testing.expect_value(t, style.body_text_height, f32(30))
	testing.expect_value(t, style.small_text_height, f32(23))
	testing.expect_value(t, style.display_text_scale, f32(5.625))
}

@(test)
test_ui_font_atlas_cell_covers_wide_glyph_advances :: proc(t: ^testing.T) {
	display_scale := uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1).display_text_scale
	atlas_cell_w := f32(rendervk.UI_FONT_ATLAS_LOGICAL_WIDTH) * display_scale
	widest_advance := f32(0)
	for advance in uifw.GUI_FONT_ADVANCES {
		widest_advance = max(widest_advance, advance * display_scale)
	}

	testing.expect(t, atlas_cell_w >= widest_advance + display_scale)
}

@(test)
test_ui_shaped_glyph_ids_resolve_to_ascii_atlas_slots :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	shaped: [16]uifw.Gui_Shaped_Glyph
	label := "Slime Mold"
	bytes := transmute([]u8)label
	count := uifw.gui_font_shape_text(.Body, bytes, 1, shaped[:])

	testing.expect(t, count > 0)
	testing.expect_value(t, uifw.gui_font_glyph_slot(shaped[0].glyph_id), i32('S' - uifw.GUI_FONT_GLYPH_FIRST))
}

@(test)
test_gui_style_for_viewport_applies_ui_scale_multiplier :: proc(t: ^testing.T) {
	normal := uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1)
	scaled := uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1.5)

	testing.expect_value(t, scaled.display_text_height, f32(135))
	testing.expect_value(t, scaled.body_text_height, f32(45))
	testing.expect(t, scaled.rhythm > normal.rhythm)
	testing.expect(t, scaled.row_height > normal.row_height)
}

@(test)
test_gui_style_for_viewport_derives_rhythm_spacing_and_box_metrics :: proc(t: ^testing.T) {
	style := uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1)

	testing.expect_value(t, style.rhythm, f32(38))
	testing.expect_value(t, style.body_line_height, style.rhythm)
	testing.expect_value(t, style.spacing_1, f32(10))
	testing.expect_value(t, style.spacing_2, f32(19))
	testing.expect_value(t, style.spacing_3, style.rhythm)
	testing.expect_value(t, style.spacing_4, f32(57))
	testing.expect_value(t, style.panel_padding, style.spacing_2)
	testing.expect_value(t, style.margin, style.spacing_2)
	testing.expect_value(t, style.section_gap, style.spacing_3)
	testing.expect_value(t, style.border_width, f32(1))
}

@(test)
test_app_ui_simulation_bar_scales_with_viewport_style :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1)
	height := game.app_ui_simulation_bar_height(&ctx)

	testing.expect(t, height > game.SIMULATION_BAR_HEIGHT)
	testing.expect_value(t, height, ctx.style.row_height + ctx.style.spacing_1 * 2)
}

@(test)
test_simulation_bar_fps_width_is_stable_across_digit_counts :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, 1)
	info_rect := uifw.Rect{0, 0, 480, game.app_ui_simulation_bar_height(&ctx)}

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720})
	game.app_ui_draw_simulation_bar_info(&ctx, info_rect, "Slime Mold", false, false, 9)
	single_digit_index := test_first_text_command_index(ctx.commands[:], "9 FPS")
	status_index := test_first_text_command_index(ctx.commands[:], "Running")
	testing.expect(t, single_digit_index >= 0)
	testing.expect(t, status_index >= 0)
	single_digit_rect := ctx.commands[single_digit_index].rect
	single_digit_status_rect := ctx.commands[status_index].rect
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720})
	game.app_ui_draw_simulation_bar_info(&ctx, info_rect, "Slime Mold", false, false, 1000)
	four_digit_index := test_first_text_command_index(ctx.commands[:], "1000 FPS")
	status_index = test_first_text_command_index(ctx.commands[:], "Running")
	testing.expect(t, four_digit_index >= 0)
	testing.expect(t, status_index >= 0)
	four_digit_rect := ctx.commands[four_digit_index].rect
	four_digit_status_rect := ctx.commands[status_index].rect
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, four_digit_rect.x, single_digit_rect.x)
	testing.expect_value(t, four_digit_rect.w, single_digit_rect.w)
	testing.expect_value(t, four_digit_status_rect.x, single_digit_status_rect.x)
	testing.expect_value(t, four_digit_status_rect.w, single_digit_status_rect.w)
}

@(test)
test_app_ui_auto_hide_hides_unfocused_ui_after_grace_period :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.auto_hide_delay = 1000
	game.app_ui_init(&ui, settings)
	ui.mode = .Gray_Scott

	game.app_ui_simulation_shell_update(&ui, {delta_time = 1.25})
	testing.expect(t, !ui.simulation_shell.show_ui)
	testing.expect(t, !ui.simulation_shell.controls_visible)
}

@(test)
test_holding_escape_or_start_exits_a_simulation :: proc(t: ^testing.T) {
	inputs := [2]bool{false, true}
	for use_start in inputs {
		ui: game.App_Ui_State
		game.app_ui_init(&ui, game.settings_default())
		ui.mode = .Gray_Scott

		for _ in 0 ..< 2 {
			game.app_ui_simulation_shell_update(&ui, {
				delta_time = 0.3,
				key_escape_down = !use_start,
				controller_start_down = use_start,
			})
		}
		testing.expect_value(t, ui.mode, game.App_Mode.Gray_Scott)

		game.app_ui_simulation_shell_update(&ui, {
			delta_time = 0.2,
			key_escape_down = !use_start,
			controller_start_down = use_start,
		})
		testing.expect_value(t, ui.mode_transition_target, game.App_Mode.Main_Menu)
	}
}

@(test)
test_holding_escape_or_start_highlights_main_menu_quit :: proc(t: ^testing.T) {
	inputs := [2]game.Ui_Frame_Input{
		{key_escape_down = true},
		{controller_start_down = true},
	}
	for input in inputs {
		ui: game.App_Ui_State
		game.app_ui_init(&ui, game.settings_default())
		ctx: uifw.Gui_Context
		uifw.gui_init(&ctx)

		_ = game.app_ui_simulation_filter_input(&ui, &ctx, input)
		testing.expect(t, ui.main_menu_quit_hold_highlight)
		uifw.gui_destroy(&ctx)
	}
}

@(test)
test_app_ui_auto_hide_keeps_engaged_ui_visible :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.auto_hide_delay = 1000
	game.app_ui_init(&ui, settings)
	ui.mode = .Gray_Scott

	game.app_ui_simulation_shell_update(&ui, {delta_time = 2}, true)
	testing.expect(t, ui.simulation_shell.show_ui)
	testing.expect(t, ui.simulation_shell.controls_visible)
	testing.expect_value(t, ui.simulation_shell.idle_seconds, f32(0))
}

@(test)
test_app_ui_auto_hide_closes_unfocused_controller_surfaces :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.auto_hide_delay = 1000
	game.app_ui_init(&ui, settings)
	ui.mode = .Particle_Life
	ui.simulation_controllers[1].deck_visible = true
	ui.simulation_controllers[1].panel_open = true

	game.app_ui_simulation_shell_update(&ui, {delta_time = 1.25})
	testing.expect(t, !ui.simulation_controllers[1].deck_visible)
	testing.expect(t, !ui.simulation_controllers[1].panel_open)
}

@(test)
test_app_ui_hide_releases_controller_focus_but_preserves_memory :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	settings := game.settings_default()
	game.app_ui_init(&ui, settings)
	state := &ui.simulation_controllers[1]
	region := uifw.Gui_Id(101)
	control := uifw.Gui_Id(202)
	uifw.gui_controller_focus_remember(&state.focus, region, control)
	_ = uifw.gui_controller_focus_enter_region(&state.focus, region, uifw.Gui_Id(99), control)
	uifw.gui_controller_focus_activate(&state.focus, control)
	state.deck_visible = true
	state.panel_open = true
	state.pending_panel_focus = true

	game.app_ui_hide_unfocused_simulation_ui(&ui)
	testing.expect_value(t, state.focus.phase, uifw.Controller_Focus_Phase.Unfocused)
	testing.expect_value(t, state.focus.region, uifw.GUI_ID_NONE)
	testing.expect_value(t, state.focus.parent_region, uifw.GUI_ID_NONE)
	testing.expect_value(t, state.focus.active_control, uifw.GUI_ID_NONE)
	testing.expect(t, !state.pending_panel_focus)
	testing.expect_value(t, uifw.gui_controller_focus_restore(&state.focus, region, uifw.GUI_ID_NONE), control)
}

@(test)
test_app_ui_navigation_enters_simulation_hidden_and_unfocused :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.slime_controller.deck_visible = true
	ui.slime_controller.focus.phase = .Region

	game.app_ui_navigate(&ui, .Slime_Mold)
	game.app_ui_mode_transition_update(&ui, game.APP_UI_MODE_FADE_OUT_SECONDS)
	testing.expect(t, !ui.slime_controller.deck_visible)
	testing.expect(t, !ui.slime_controller.panel_open)
	testing.expect_value(t, ui.slime_controller.focus.phase, uifw.Controller_Focus_Phase.Unfocused)
	testing.expect(t, !ui.simulation_shell.controls_visible)
}

@(test)
test_app_ui_auto_hide_mouse_motion_reveals_hidden_controls :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.auto_hide_delay = 1000
	game.app_ui_init(&ui, settings)
	ui.mode = .Gray_Scott
	ui.simulation_shell.show_ui = false
	ui.simulation_shell.controls_visible = false
	ui.simulation_shell.idle_seconds = 2

	game.app_ui_simulation_shell_update(&ui, {mouse_moved = true})
	testing.expect(t, ui.simulation_shell.controls_visible)
	testing.expect_value(t, ui.simulation_shell.idle_seconds, f32(0))
}

@(test)
test_app_ui_system_cursor_hides_with_hidden_simulation_controls :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.auto_hide_delay = 1000
	game.app_ui_init(&ui, settings)
	ui.mode = .Gray_Scott

	testing.expect(t, !game.app_ui_system_cursor_hidden(&ui))

	game.app_ui_simulation_shell_update(&ui, {key_slash = true})
	testing.expect(t, !ui.simulation_shell.show_ui)
	testing.expect(t, ui.simulation_shell.controls_visible)
	testing.expect(t, !game.app_ui_system_cursor_hidden(&ui))

	game.app_ui_simulation_shell_update(&ui, {delta_time = 1.25})
	testing.expect(t, !ui.simulation_shell.controls_visible)
	testing.expect(t, game.app_ui_system_cursor_hidden(&ui))

	game.app_ui_simulation_shell_update(&ui, {mouse_moved = true})
	testing.expect(t, ui.simulation_shell.controls_visible)
	testing.expect(t, !game.app_ui_system_cursor_hidden(&ui))

	ui.mode = .Main_Menu
	ui.simulation_shell.show_ui = false
	ui.simulation_shell.controls_visible = false
	testing.expect(t, !game.app_ui_system_cursor_hidden(&ui))
}

@(test)
test_app_ui_virtual_controller_cursor_remains_visible_for_hidden_canvas :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Gray_Scott
	ui.simulation_shell.show_ui = false
	ui.simulation_shell.controls_visible = false

	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	uifw.gui_begin_frame(&ctx, {
		active_device = .Controller,
		mouse_pos = {640, 360},
	})

	game.app_ui_draw_virtual_cursor(&ui, &ctx)
	testing.expect(t, len(ctx.commands) > 0)

	command_count := len(ctx.commands)
	ui.simulation_shell.controls_visible = true
	game.app_ui_draw_virtual_cursor(&ui, &ctx)
	testing.expect(t, len(ctx.commands) > command_count)
}

@(test)
test_app_ui_camera_pan_gestures_never_reach_simulation_interaction :: proc(t: ^testing.T) {
	inputs := [?]game.Ui_Frame_Input{
		game.Ui_Frame_Input{window_width = 1280, window_height = 720, mouse_pos = {640, 360}, mouse_down = true, mouse_pressed = true, mouse_button = 2},
		game.Ui_Frame_Input{window_width = 1280, window_height = 720, mouse_pos = {640, 360}, mouse_down = true, mouse_pressed = true, mouse_button = 1, camera_pan_modifier_down = true},
	}
	for input in inputs {
		ctx: uifw.Gui_Context
		uifw.gui_init(&ctx)
		ui: game.App_Ui_State
		game.app_ui_init(&ui, game.settings_default())
		ui.mode = .Gray_Scott

		filtered := game.app_ui_simulation_filter_input(&ui, &ctx, input)
		testing.expect(t, filtered.camera_pan_down)
		testing.expect(t, !filtered.mouse_down)
		testing.expect(t, !filtered.primary_down)
		testing.expect(t, !filtered.secondary_down)
		uifw.gui_destroy(&ctx)
	}
}

@(test)
test_app_ui_primary_drag_stays_interaction_when_space_is_pressed_mid_gesture :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Gray_Scott

	first := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1280, window_height = 720, mouse_pos = {640, 360},
		mouse_down = true, mouse_pressed = true, mouse_button = 1,
	})
	testing.expect(t, !first.camera_pan_down)
	testing.expect(t, first.mouse_down)

	continued := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1280, window_height = 720, mouse_pos = {650, 360},
		mouse_down = true, mouse_button = 1, camera_pan_modifier_down = true,
	})
	testing.expect(t, !continued.camera_pan_down)
	testing.expect(t, continued.mouse_down)
}

@(test)
test_gui_middle_mouse_cannot_activate_regular_controls :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	uifw.gui_begin_frame(&ctx, {
		mouse_pos = {20, 20}, mouse_down = true, mouse_pressed = true, mouse_button = 2,
	})
	id := uifw.gui_make_id(&ctx, "middle_button")
	pressed := uifw.gui_button_at(&ctx, id, {0, 0, 100, 40}, "Button", true)
	uifw.gui_end_frame(&ctx)
	testing.expect(t, !pressed)
	testing.expect_value(t, ctx.active, uifw.GUI_ID_NONE)
}

@(test)
test_app_mouse_input_restores_hidden_system_cursor_immediately :: proc(t: ^testing.T) {
	testing.expect(t, host.app_input_reveals_hidden_system_cursor({
		mouse_pressed = true,
	}, .Mouse_Keyboard))
	testing.expect(t, host.app_input_reveals_hidden_system_cursor({
		mouse_moved = true,
	}, .Mouse_Keyboard))
	testing.expect(t, host.app_input_reveals_hidden_system_cursor({
		wheel_delta = 1,
	}, .Mouse_Keyboard))
	testing.expect(t, !host.app_input_reveals_hidden_system_cursor({
		mouse_pressed = true,
	}, .Controller))
	testing.expect(t, !host.app_input_reveals_hidden_system_cursor({}, .Mouse_Keyboard))
}

@(test)
test_app_mouse_button_events_update_position_for_same_frame_clicks :: proc(t: ^testing.T) {
	app := new(host.App_State)
	defer free(app)
	app.input.mouse_pos = {12, 18}

	host.app_apply_mouse_button_event(app, 1, 320, 240, true)
	host.app_apply_mouse_button_event(app, 1, 320, 240, false)

	testing.expect_value(t, app.input.mouse_pos.x, f32(320))
	testing.expect_value(t, app.input.mouse_pos.y, f32(240))
	testing.expect_value(t, app.input.mouse_delta.x, f32(0))
	testing.expect_value(t, app.input.mouse_delta.y, f32(0))
	testing.expect(t, app.input.mouse_pressed)
	testing.expect(t, app.input.mouse_released)
	testing.expect(t, !app.input.mouse_down)
	testing.expect_value(t, app.held_mouse_button, u32(0))

	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	uifw.gui_begin_frame(&ctx, {
		mouse_pos = app.input.mouse_pos,
		mouse_pressed = app.input.mouse_pressed,
		mouse_released = app.input.mouse_released,
	})
	clicked := uifw.gui_button_at(&ctx, uifw.gui_make_id(&ctx, "click_target"), {280, 220, 100, 50}, "Click", true)
	testing.expect(t, clicked)
}

@(test)
test_app_ui_simulation_filter_blocks_controller_deck_clicks :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	settings := game.settings_default()
	ui: game.App_Ui_State
	game.app_ui_init(&ui, settings)
	ui.mode = .Particle_Life

	ui.simulation_controllers[1].deck_visible = true
	deck := game.simulation_controller_ui_deck_rect(&ctx, 1920, 1080, len(game.PARTICLE_LIFE_CONTROLLER_TABS))
	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1920,
		window_height = 1080,
		mouse_pos = {deck.x + deck.w * 0.5, deck.y + 40},
		mouse_down = true,
		mouse_pressed = true,
		mouse_button = 1,
	})

	testing.expect(t, !filtered.mouse_down)
	testing.expect(t, !filtered.mouse_pressed)
	testing.expect(t, !ui.simulation_shell.mouse_pressed)
}

@(test)
test_app_ui_simulation_filter_preserves_camera_arrows_without_ui_focus :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.mode = .Gray_Scott

	filtered := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1920,
		window_height = 1080,
		key_right = true,
		camera_reset = true,
		nav_x = 1,
		nav_pressed_x = 1,
	})

	testing.expect(t, filtered.key_right)
	testing.expect(t, filtered.camera_reset)
	testing.expect_value(t, filtered.nav_x, f32(1))
	testing.expect_value(t, filtered.nav_pressed_x, f32(1))

	ctx.focused = uifw.gui_make_id(&ctx, "focused_control")
	filtered = game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1920,
		window_height = 1080,
		key_right = true,
		camera_reset = true,
		nav_x = 1,
		nav_pressed_x = 1,
	})

	testing.expect(t, !filtered.key_right)
	testing.expect(t, !filtered.camera_reset)
	testing.expect_value(t, filtered.nav_x, f32(0))
	testing.expect_value(t, filtered.nav_pressed_x, f32(0))
}

@(test)
test_app_ui_simulation_filter_keeps_canvas_drag_owned_across_utility_rail :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	settings := game.settings_default()
	settings.menu_position = "right"
	ui: game.App_Ui_State
	game.app_ui_init(&ui, settings)
	ui.mode = .Particle_Life

	first := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1920,
		window_height = 1080,
		mouse_pos = {100, 100},
		mouse_down = true,
		mouse_pressed = true,
		mouse_button = 1,
	})
	testing.expect(t, first.mouse_down)
	testing.expect(t, ui.simulation_shell.mouse_pressed)
	chrome := game.app_ui_simulation_chrome_rect(&ui, &ctx, ui.mode, 1920, 1080)

	second := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1920,
		window_height = 1080,
		mouse_pos = {chrome.x + 10, chrome.y + 10},
		mouse_down = true,
		mouse_button = 1,
	})

	testing.expect(t, second.mouse_down)
	testing.expect(t, !second.mouse_released)
	testing.expect(t, ui.simulation_shell.mouse_pressed)

	third := game.app_ui_simulation_filter_input(&ui, &ctx, {
		window_width = 1920,
		window_height = 1080,
		mouse_pos = {chrome.x + 10, chrome.y + 10},
		mouse_released = true,
		mouse_button = 1,
	})
	testing.expect(t, third.mouse_released)
	testing.expect(t, !ui.simulation_shell.mouse_pressed)
}

@(test)
test_gui_style_scaled_expands_readability_metrics :: proc(t: ^testing.T) {
	base := uifw.gui_default_style()
	scaled := uifw.gui_style_scaled(base, 1.5)

	testing.expect_value(t, scaled.row_height, base.row_height * 1.5)
	testing.expect_value(t, scaled.text_height, base.text_height * 1.5)
	testing.expect_value(t, scaled.text_scale, base.text_scale * 1.5)
	testing.expect_value(t, scaled.panel_padding, base.panel_padding * 1.5)
}

@(test)
test_gui_collapsible_toggles_with_keyboard_space :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	open := false
	id := uifw.gui_make_id(&ctx, "section")
	ctx.focused = id

	uifw.gui_begin_frame(&ctx, {key_space = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 240, 80}, .Column, 0, 44)
	testing.expect(t, uifw.gui_collapsible_begin(&ctx, "Section", "section", &open))
	uifw.gui_layout_end(&ctx)
	testing.expect(t, open)
}

@(test)
test_app_ui_main_menu_arrows_move_once_per_press :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_selected = 0

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1200, height = 800}
	worker: host.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}, key_down = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 1)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}, key_down = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 1)

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}, key_down = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 2)
}

@(test)
test_app_ui_main_menu_keyboard_scrolls_all_sims_into_view :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_selected = 0
	ui.main_menu_focus_slot = game.app_ui_main_menu_slot_for_simulation_index(0)

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: host.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), f32(vk_ctx.swapchain_extent.width), f32(vk_ctx.swapchain_extent.height), 1)

	for _ in 0 ..< 9 {
		uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, key_down = true})
		game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
		uifw.gui_end_frame(&ctx)

		uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}})
		game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
		uifw.gui_end_frame(&ctx)
	}

	testing.expect_value(t, ui.main_menu_selected, 9)
	testing.expect(t, ui.main_menu_scroll > 0)

	width := f32(vk_ctx.swapchain_extent.width)
	height := f32(vk_ctx.swapchain_extent.height)
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), width, height, 1)
	theme := game.app_ui_menu_theme(&ctx, width, height)
	margin_x := max(width * 0.055, ctx.style.spacing_4)
	title_y := max(height * 0.070, ctx.style.spacing_4)
	title_scale := max((height * 0.31) / f32(16), ctx.style.display_text_scale * 1.2)
	title_text_h := uifw.GUI_FONT_LOGICAL_HEIGHT * title_scale
	title_h := min(max(max(height * 0.20, ctx.style.display_line_height), title_text_h), height - title_y)
	side_w := min(max(width * 0.23, f32(330)), f32(560))
	right_margin := max(width * 0.050, ctx.style.spacing_4)
	options_size := game.app_ui_main_menu_text_button_size(&ctx, "OPTIONS", theme)
	quit_size := game.app_ui_main_menu_text_button_size(&ctx, "QUIT", theme)
	button_w := max(side_w, max(options_size.x, quit_size.x))
	actions_x := max(width - right_margin - button_w, margin_x)
	list_w := min(max(width * 0.60, f32(680)), max(actions_x - theme.detail_gap - margin_x, 1))
	list_y := max(title_y + title_h + theme.inner_gap, height * 0.39)
	list_bottom := height - max(height * 0.050, ctx.style.spacing_4)
	list_h := max(list_bottom - list_y, theme.row_height * 2.25)
	catalog := game.app_ui_main_menu_catalog_list_bounds(&ctx, {margin_x, list_y, list_w, list_h})
	viewport := game.app_ui_main_menu_list_viewport(&ctx, catalog)
	selected_top := f32(ui.main_menu_selected) * (theme.row_height + ctx.style.spacing)
	selected_bottom := selected_top + theme.row_height

	testing.expect(t, selected_bottom <= ui.main_menu_scroll + viewport.h + theme.item_gap)
	testing.expect(t, selected_top >= ui.main_menu_scroll - theme.item_gap)
}

@(test)
test_app_ui_main_menu_keyboard_reaches_title_options_and_quit :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_selected = 0
	ui.main_menu_focus_slot = game.app_ui_main_menu_slot_for_simulation_index(0)

	render_to_ui := new(game.Render_To_Ui_Queue)
	defer free(render_to_ui)
	worker: host.Render_Worker_State
	worker.render_to_ui = render_to_ui
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, key_up = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_focus_slot, game.MAIN_MENU_TITLE_SLOT)

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, key_enter = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect(t, ui.main_menu_palette_randomize_requested)

	ui.main_menu_palette_randomize_requested = false
	ui.main_menu_selected = 9
	ui.main_menu_focus_slot = game.app_ui_main_menu_slot_for_simulation_index(9)
	ui.main_menu_focus_navigation_active = true
	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, nav_pressed_y = 1, active_device = .Controller})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_focus_slot, game.app_ui_main_menu_options_slot())

	ctx.focused = uifw.gui_make_id(&ctx, "options")
	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, accept = true, active_device = .Controller})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.mode, game.App_Mode.Options)

	game.app_ui_navigate(&ui, .Main_Menu)
	ui.main_menu_focus_slot = game.app_ui_main_menu_options_slot()
	ui.main_menu_focus_navigation_active = true
	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, nav_pressed_y = 1, active_device = .Controller})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_focus_slot, game.app_ui_main_menu_quit_slot())

	ctx.focused = uifw.gui_make_id(&ctx, "quit")
	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, accept = true, active_device = .Controller})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	msg: game.Render_To_Ui_Message
	testing.expect(t, engine.queue_try_pop(render_to_ui, &msg))
	testing.expect_value(t, msg.kind, game.Render_To_Ui_Message_Kind.Request_Close)
}

@(test)
test_app_ui_main_menu_keyboard_selection_ignores_stationary_hover :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_selected = 0

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: host.Render_Worker_State
	mouse := uifw.Vec2{200, 760}

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = mouse})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 1)

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = mouse, key_down = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 2)

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = mouse})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 2)

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = mouse, mouse_moved = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 2)

	ui.main_menu_scroll = 0
	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = mouse, mouse_pressed = true, mouse_down = true})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ui.main_menu_selected, 1)
}

@(test)
test_app_ui_main_menu_hover_selection_draws_same_frame :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_selected = 0

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: host.Render_Worker_State
	mouse := uifw.Vec2{200, 760}

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = mouse})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ui.main_menu_selected, 1)
	found_hover_focus_ring := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Stroked_Rounded_Rect &&
		   command.color.a >= 0.8 &&
		   command.stroke_width == ctx.style.focus_ring_width &&
		   uifw.gui_contains(command.rect, mouse) {
			found_hover_focus_ring = true
		}
	}
	testing.expect(t, found_hover_focus_ring)
}

@(test)
test_app_ui_main_menu_idle_selection_has_no_hover_highlight :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	testing.expect_value(t, ui.main_menu_selected, 0)

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: host.Render_Worker_State
	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Stroked_Rounded_Rect &&
		   command.color.r > 0.9 &&
		   command.color.g > 0.9 &&
		   command.color.b > 0.9 &&
		   command.color.a >= 0.39 &&
		   command.stroke_width >= 2 {
			testing.expect(t, false, "idle simulation selection must not draw a hover/focus highlight")
		}
	}
}

@(test)
test_app_ui_main_menu_hover_selection_respects_scroll_clip :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_selected = 0

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: host.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {200, 1070}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, ui.main_menu_selected, 0)
}

@(test)
test_app_ui_main_menu_preview_slots_skip_gradient_editor :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_scroll = 900

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: host.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	saw_gradient_label := false
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Text && command.text == "Gradient Editor" {
			saw_gradient_label = true
			bytes := transmute([]u8)command.text
			fallback_advance := ctx.style.char_width * command.text_scale / max(ctx.style.text_scale, 0.001)
			text_w := uifw.gui_font_text_width(command.font_kind, bytes, command.text_scale, fallback_advance)
			testing.expect(t, text_w <= command.rect.w + 0.01)
		}
	}
	testing.expect(t, saw_gradient_label)
	for i in 0 ..< ui.main_menu_preview_slot_count {
		testing.expect(t, ui.main_menu_preview_slots[i].mode != game.App_Mode.Gradient_Editor)
	}
}

@(test)
test_app_ui_main_menu_preview_slots_keep_unclipped_rect_when_scrolled :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_scroll = 42

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: host.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	found_partially_clipped := false
	found_clipped_overlay := false
	for i in 0 ..< ui.main_menu_preview_slot_count {
		slot := ui.main_menu_preview_slots[i]
		if slot.clip_rect.h > 1 && slot.rect.h > slot.clip_rect.h + 1 {
			found_partially_clipped = true
			expected_left_w := slot.rect.w * game.MAIN_MENU_SIM_BUTTON_GRADIENT_MIDPOINT
			for command in ctx.commands {
				if test_is_black_horizontal_fade(command, 1, 0.62) &&
				   math.abs(command.rect.x - slot.clip_rect.x) <= 0.01 &&
				   math.abs(command.rect.y - slot.clip_rect.y) <= 0.01 &&
				   math.abs(command.rect.w - expected_left_w) <= 0.01 &&
				   math.abs(command.rect.h - slot.clip_rect.h) <= 0.01 {
					found_clipped_overlay = true
				}
			}
		}
	}
	testing.expect(t, found_partially_clipped)
	testing.expect(t, found_clipped_overlay)
}

@(test)
test_app_ui_main_menu_preview_slots_record_fallback_color :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: host.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	theme := game.app_ui_menu_theme(&ctx, 1920, 1080)
	testing.expect(t, ui.main_menu_preview_slot_count > 0)
	for i in 0 ..< ui.main_menu_preview_slot_count {
		slot := ui.main_menu_preview_slots[i]
		testing.expect(t, test_approx_f32(slot.fallback_color.r, theme.preview_surface.r))
		testing.expect(t, test_approx_f32(slot.fallback_color.g, theme.preview_surface.g))
		testing.expect(t, test_approx_f32(slot.fallback_color.b, theme.preview_surface.b))
		testing.expect(t, test_approx_f32(slot.fallback_color.a, theme.preview_surface.a))
	}
}

@(test)
test_app_ui_main_menu_preview_overlay_starts_fully_dark :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: host.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	found := false
	for command in ctx.commands {
		if !test_is_black_horizontal_fade(command, 1, 0.62) {
			continue
		}
		for next in ctx.commands {
			if test_is_black_horizontal_fade(next, 0.62, 0) &&
			   math.abs(next.rect.x - (command.rect.x + command.rect.w)) <= 0.01 &&
			   math.abs(next.rect.y - command.rect.y) <= 0.01 &&
			   math.abs(next.rect.h - command.rect.h) <= 0.01 {
				full_w := command.rect.w + next.rect.w
				midpoint := command.rect.w / full_w
				if math.abs(midpoint - game.MAIN_MENU_SIM_BUTTON_GRADIENT_MIDPOINT) <= 0.01 {
					found = true
				}
			}
		}
	}
	testing.expect(t, found)
}

@(test)
test_app_ui_main_menu_simulation_list_draws_scroll_edge_fades :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	width := f32(1920)
	height := f32(1080)
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), width, height, 1)
	theme := game.app_ui_menu_theme(&ctx, width, height)
	margin_x := max(width * 0.055, ctx.style.spacing_4)
	title_y := max(height * 0.070, ctx.style.spacing_4)
	title_scale := max((height * 0.31) / f32(16), ctx.style.display_text_scale * 1.2)
	title_text_h := uifw.GUI_FONT_LOGICAL_HEIGHT * title_scale
	title_h := min(max(max(height * 0.20, ctx.style.display_line_height), title_text_h), height - title_y)
	side_w := min(max(width * 0.23, f32(330)), f32(560))
	right_margin := max(width * 0.050, ctx.style.spacing_4)
	options_size := game.app_ui_main_menu_text_button_size(&ctx, "OPTIONS", theme)
	quit_size := game.app_ui_main_menu_text_button_size(&ctx, "QUIT", theme)
	button_w := max(side_w, max(options_size.x, quit_size.x))
	actions_x := max(width - right_margin - button_w, margin_x)
	list_w := min(max(width * 0.60, f32(680)), max(actions_x - theme.detail_gap - margin_x, 1))
	list_y := max(title_y + title_h + theme.inner_gap, height * 0.39)
	list_bottom := height - max(height * 0.050, ctx.style.spacing_4)
	list_h := max(list_bottom - list_y, theme.row_height * 2.25)
	list_bounds := game.app_ui_main_menu_catalog_list_bounds(&ctx, {margin_x, list_y, list_w, list_h})
	viewport := game.app_ui_main_menu_list_viewport(&ctx, list_bounds)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: host.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	top, bottom := test_count_scroll_fades(ctx.commands[:], viewport)
	testing.expect_value(t, top, 0)
	testing.expect_value(t, bottom, 1)

	ui.main_menu_scroll = 42
	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	top, bottom = test_count_scroll_fades(ctx.commands[:], viewport)
	testing.expect_value(t, top, 1)
	testing.expect(t, bottom >= 1)
}

@(test)
test_app_ui_main_menu_discovery_chrome_is_visible :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: host.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1)

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, game.app_ui_main_menu_catalog_eyebrow_label(), "10 SIMULATIONS")
	saw_eyebrow := false
	saw_keyboard_hint := false
	saw_wide_scrollbar := false
	for command in ctx.commands {
		if command.kind == .Text && command.text == "10 SIMULATIONS" {
			saw_eyebrow = true
		}
		if command.kind == .Text && command.text == "Scroll / \u2191\u2193  Browse   \u2022   Enter / Click  Start" {
			saw_keyboard_hint = true
		}
		if command.kind == .Filled_Rounded_Rect && command.rect.w >= 9 && command.rect.w <= 16 && command.rect.h > 100 {
			saw_wide_scrollbar = true
		}
	}
	testing.expect(t, saw_eyebrow)
	testing.expect(t, saw_keyboard_hint)
	testing.expect(t, saw_wide_scrollbar)
}

@(test)
test_app_ui_main_menu_controller_hint_uses_accept_preference :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	settings := game.settings_default()
	settings.controller_face_layout = "East Accept"
	ui: game.App_Ui_State
	game.app_ui_init(&ui, settings)
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: host.Render_Worker_State
	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1)

	uifw.gui_begin_frame(&ctx, {window_width = 1920, window_height = 1080, mouse_pos = {-1000, -1000}, active_device = .Controller, controller_prompt_style = .Xbox})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	expected_accept_uv := game.controller_prompt_icon_uv(.East, .Xbox)
	saw_browse := false
	saw_start := false
	saw_accept := false
	for command in ctx.commands {
		if command.kind == .Text && command.text == "Browse" {
			saw_browse = true
		}
		if command.kind == .Text && command.text == "Start" {
			saw_start = true
		}
		if command.kind == .Image &&
		   command.image_id == uifw.Gui_Image_Id(rendervk.UI_KENNEY_INPUT_ATLAS_TEXTURE_ID) &&
		   test_approx_f32(command.rect_2.x, expected_accept_uv.x) {
			saw_accept = true
		}
	}
	testing.expect(t, saw_browse)
	testing.expect(t, saw_start)
	testing.expect(t, saw_accept)
}

@(test)
test_app_ui_main_menu_instruction_strip_stays_outside_catalog_viewport :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	bounds_cases := [?]uifw.Rect{uifw.Rect{100, 400, 1080, 620}, uifw.Rect{24, 220, 520, 410}}
	window_widths := [?]i32{1920, 800}
	for bounds, index in bounds_cases {
		ctx.input.window_width = window_widths[index]
		viewport := game.app_ui_main_menu_list_viewport(&ctx, bounds)
		hint := game.app_ui_main_menu_list_hint_rect(&ctx, bounds)
		disjoint := viewport.y + viewport.h <= hint.y || hint.y + hint.h <= viewport.y
		testing.expect(t, disjoint)
		testing.expect(t, hint.y + hint.h <= bounds.y + bounds.h + 0.01)
		testing.expect_value(t, viewport.x, bounds.x)
		testing.expect_value(t, viewport.w, bounds.w)
	}
}

@(test)
test_app_ui_main_menu_bottom_scroll_registers_primordial_live_preview :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	game.app_ui_init(&ui, game.settings_default())
	ui.main_menu_scroll = 1900

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	worker: host.Render_Worker_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {-1000, -1000}})
	game.app_ui_draw_main_menu(&ui, &ctx, &vk_ctx, &worker)
	uifw.gui_end_frame(&ctx)

	saw_primordial := false
	for i in 0 ..< ui.main_menu_preview_slot_count {
		if ui.main_menu_preview_slots[i].mode == game.App_Mode.Primordial {
			saw_primordial = true
		}
	}
	testing.expect(t, saw_primordial)
}

@(test)
test_render_main_menu_preview_viewport_matches_sim_button_clip :: proc(t: ^testing.T) {
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	render_ctx: rendervk.Render_Context
	render_ctx.vk_ctx = &vk_ctx

	rect := uifw.Rect{118, 119, 1796, 438}
	clip := uifw.Rect{118, 160, 1796, 397}
	viewport: vk.Viewport
	scissor: vk.Rect2D
	ok := rendervk.render_main_menu_preview_viewport_for_rect(&render_ctx, rect, clip, &viewport, &scissor)

	testing.expect(t, ok)
	testing.expect(t, test_approx_f32(viewport.x, rect.x))
	testing.expect(t, test_approx_f32(viewport.y, rect.y))
	testing.expect(t, test_approx_f32(viewport.width, rect.w))
	testing.expect(t, test_approx_f32(viewport.height, rect.h))
	testing.expect_value(t, scissor.offset.x, i32(clip.x))
	testing.expect_value(t, scissor.offset.y, i32(clip.y))
	testing.expect_value(t, scissor.extent.width, u32(clip.w))
	testing.expect_value(t, scissor.extent.height, u32(clip.h))
}

@(test)
test_render_main_menu_preview_scissor_clamps_to_swapchain :: proc(t: ^testing.T) {
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	render_ctx: rendervk.Render_Context
	render_ctx.vk_ctx = &vk_ctx

	rect := uifw.Rect{-20, -30, 240, 160}
	clip := uifw.Rect{-10, -15, 120, 90}
	viewport: vk.Viewport
	scissor: vk.Rect2D
	ok := rendervk.render_main_menu_preview_viewport_for_rect(&render_ctx, rect, clip, &viewport, &scissor)

	testing.expect(t, ok)
	testing.expect_value(t, i32(viewport.x), i32(rect.x))
	testing.expect_value(t, i32(viewport.y), i32(rect.y))
	testing.expect_value(t, u32(viewport.width), u32(rect.w))
	testing.expect_value(t, u32(viewport.height), u32(rect.h))
	testing.expect_value(t, scissor.offset.x, i32(0))
	testing.expect_value(t, scissor.offset.y, i32(0))
	testing.expect_value(t, scissor.extent.width, u32(110))
	testing.expect_value(t, scissor.extent.height, u32(75))
}

@(test)
test_render_main_menu_preview_viewport_clamps_partially_scrolled_row :: proc(t: ^testing.T) {
	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 1920, height = 1080}
	render_ctx: rendervk.Render_Context
	render_ctx.vk_ctx = &vk_ctx

	rect := uifw.Rect{118, 980, 700, 220}
	clip := uifw.Rect{118, 980, 700, 100}
	viewport: vk.Viewport
	scissor: vk.Rect2D
	ok := rendervk.render_main_menu_preview_viewport_for_rect(&render_ctx, rect, clip, &viewport, &scissor)

	testing.expect(t, ok)
	testing.expect_value(t, i32(viewport.x), i32(118))
	testing.expect_value(t, i32(viewport.y), i32(f32(vk_ctx.swapchain_extent.height) - rect.h))
	testing.expect_value(t, u32(viewport.width), u32(700))
	testing.expect_value(t, u32(viewport.height), u32(220))
	testing.expect(t, viewport.y + viewport.height <= f32(vk_ctx.swapchain_extent.height))
	testing.expect_value(t, scissor.offset.x, i32(118))
	testing.expect_value(t, scissor.offset.y, i32(980))
	testing.expect_value(t, scissor.extent.width, u32(700))
	testing.expect_value(t, scissor.extent.height, u32(100))
}

@(test)
test_render_main_menu_preview_size_uses_stable_slot_dimensions :: proc(t: ^testing.T) {
	slot := game.Main_Menu_Preview_Slot {
		mode = .Flow_Field,
		rect = {10, 20, 430, 260},
		clip_rect = {10, 20, 420, 220},
	}
	width, height := rendervk.render_main_menu_preview_size_for_slot(slot)

	testing.expect_value(t, width, u32(430))
	testing.expect_value(t, height, u32(260))
}

@(test)
test_render_main_menu_preview_size_enforces_minimum :: proc(t: ^testing.T) {
	slot := game.Main_Menu_Preview_Slot {
		mode = .Slime_Mold,
		rect = {0, 0, 80, 60},
		clip_rect = {0, 0, 80, 60},
	}
	width, height := rendervk.render_main_menu_preview_size_for_slot(slot)

	testing.expect_value(t, width, rendervk.MAIN_MENU_SIM_PREVIEW_WIDTH)
	testing.expect_value(t, height, rendervk.MAIN_MENU_SIM_PREVIEW_HEIGHT)
}

@(test)
test_render_main_menu_preview_size_enforces_cap_with_aspect :: proc(t: ^testing.T) {
	slot := game.Main_Menu_Preview_Slot {
		mode = .Flow_Field,
		rect = {0, 0, 1280, 720},
		clip_rect = {0, 0, 1280, 720},
	}
	width, height := rendervk.render_main_menu_preview_size_for_slot(slot)

	testing.expect_value(t, width, rendervk.MAIN_MENU_SIM_PREVIEW_MAX_WIDTH)
	testing.expect_value(t, height, rendervk.MAIN_MENU_SIM_PREVIEW_MAX_HEIGHT)
}

@(test)
test_render_main_menu_preview_size_cap_preserves_non_16_9_aspect :: proc(t: ^testing.T) {
	slot := game.Main_Menu_Preview_Slot {
		mode = .Flow_Field,
		rect = {0, 0, 1280, 500},
		clip_rect = {0, 0, 1280, 500},
	}
	width, height := rendervk.render_main_menu_preview_size_for_slot(slot)

	testing.expect_value(t, width, rendervk.MAIN_MENU_SIM_PREVIEW_MAX_WIDTH)
	testing.expect_value(t, height, u32(250))
}

@(test)
test_render_main_menu_preview_size_for_mode_is_scroll_stable :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	ui.main_menu_preview_slot_count = 2
	ui.main_menu_preview_slots[0] = {mode = .Slime_Mold, rect = {0, 0, 384, 216}, clip_rect = {0, 0, 300, 160}}
	ui.main_menu_preview_slots[1] = {mode = .Flow_Field, rect = {0, 0, 512, 256}, clip_rect = {0, 0, 320, 180}}

	render_ctx: rendervk.Render_Context
	render_ctx.app_ui = &ui

	flow_width, flow_height := rendervk.render_main_menu_preview_size_for_mode(&render_ctx, .Flow_Field)
	missing_width, missing_height := rendervk.render_main_menu_preview_size_for_mode(&render_ctx, .Gray_Scott)

	testing.expect_value(t, flow_width, rendervk.MAIN_MENU_SIM_PREVIEW_WIDTH)
	testing.expect_value(t, flow_height, rendervk.MAIN_MENU_SIM_PREVIEW_HEIGHT)
	testing.expect_value(t, missing_width, rendervk.MAIN_MENU_SIM_PREVIEW_WIDTH)
	testing.expect_value(t, missing_height, rendervk.MAIN_MENU_SIM_PREVIEW_HEIGHT)
}

@(test)
test_render_main_menu_preview_size_for_mode_ignores_swapchain_clip :: proc(t: ^testing.T) {
	ui: game.App_Ui_State
	ui.main_menu_preview_slot_count = 1
	ui.main_menu_preview_slots[0] = {mode = .Slime_Mold, rect = {-20, -10, 300, 200}, clip_rect = {0, 0, 220, 140}}

	vk_ctx: engine.Vk_Context
	vk_ctx.swapchain_extent = {width = 220, height = 140}
	render_ctx: rendervk.Render_Context
	render_ctx.app_ui = &ui
	render_ctx.vk_ctx = &vk_ctx

	width, height := rendervk.render_main_menu_preview_size_for_mode(&render_ctx, .Slime_Mold)

	testing.expect_value(t, width, rendervk.MAIN_MENU_SIM_PREVIEW_WIDTH)
	testing.expect_value(t, height, rendervk.MAIN_MENU_SIM_PREVIEW_HEIGHT)
}

@(test)
test_render_main_menu_preview_warm_policy_covers_all_supported_live_modes :: proc(t: ^testing.T) {
	testing.expect_value(t, rendervk.render_main_menu_preview_supported_mode_count(), u32(9))
	testing.expect(t, game.app_ui_live_preview_supported(.Slime_Mold))
	testing.expect(t, game.app_ui_live_preview_supported(.Gray_Scott))
	testing.expect(t, game.app_ui_live_preview_supported(.Particle_Life))
	testing.expect(t, game.app_ui_live_preview_supported(.Flow_Field))
	testing.expect(t, game.app_ui_live_preview_supported(.Pellets))
	testing.expect(t, game.app_ui_live_preview_supported(.Voronoi_CA))
	testing.expect(t, game.app_ui_live_preview_supported(.Moire))
	testing.expect(t, game.app_ui_live_preview_supported(.Vectors))
	testing.expect(t, game.app_ui_live_preview_supported(.Primordial))
	testing.expect(t, !game.app_ui_live_preview_supported(.Gradient_Editor))
}

@(test)
test_app_ui_simulation_menu_panel_stays_inside_viewport_at_common_sizes :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	settings := game.settings_default()
	settings.menu_position = "right"
	ui: game.App_Ui_State
	game.app_ui_init(&ui, settings)
	ui.mode = .Gray_Scott

	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1280, 720, 1)
	panel_720 := game.app_ui_simulation_menu_panel(&ui, &ctx, 1280, 720)
	testing.expect(t, panel_720.x >= ctx.style.margin)
	testing.expect(t, panel_720.x + panel_720.w <= 1280 - ctx.style.margin + 0.01)
	testing.expect(t, panel_720.y + panel_720.h <= 720 + 0.01)

	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1)
	panel_1080 := game.app_ui_simulation_menu_panel(&ui, &ctx, 1920, 1080)
	testing.expect(t, panel_1080.x >= ctx.style.margin)
	testing.expect(t, panel_1080.x + panel_1080.w <= 1920 - ctx.style.margin + 0.01)
	testing.expect(t, panel_1080.y + panel_1080.h <= 1080 + 0.01)

	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 3840, 2160, 1)
	panel_4k := game.app_ui_simulation_menu_panel(&ui, &ctx, 3840, 2160)
	testing.expect(t, panel_4k.x >= ctx.style.margin)
	testing.expect(t, panel_4k.x + panel_4k.w <= 3840 - ctx.style.margin + 0.01)
	testing.expect(t, panel_4k.y + panel_4k.h <= 2160 + 0.01)
}

@(test)
test_remaining_sim_pellets_sidebar_scroll_extent_tracks_ui_scale :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	sim: game.Remaining_Sim_State
	game.remaining_sim_init(&sim)

	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1)
	base_height := game.remaining_sim_controls_content_height(&sim, &ctx, .Pellets, 640)
	testing.expect(t, base_height > 1040)

	ctx.style = uifw.gui_style_for_viewport(uifw.gui_default_style(), 1920, 1080, 1.5)
	scaled_height := game.remaining_sim_controls_content_height(&sim, &ctx, .Pellets, 640)
	testing.expect(t, scaled_height > base_height * 1.35)
}

@(test)
test_remaining_sim_controller_section_uses_supplied_panel_scroll :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	sim: game.Remaining_Sim_State
	game.remaining_sim_init(&sim)
	sim.scroll = 17
	panel_scroll := f32(0)
	editor: game.Color_Scheme_Editor_State
	game.color_scheme_editor_init(&editor)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {20, 20}, wheel_delta = -1})
	game.remaining_sim_draw_controls(&sim, &ctx, .Pellets, {0, 0, 760, 240}, &editor, nil, 6, &panel_scroll)

	testing.expect(t, panel_scroll > 0)
	testing.expect_value(t, sim.scroll, f32(17))
}

@(test)
test_shared_range_slider_normalizes_reversed_endpoints :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {0, 0, 320, 120}, .Column, 0, 44)
	lower := f32(8)
	upper := f32(2)
	_ = game.shared_range_slider_f32(&ctx, "Range", "test_range", &lower, &upper, 0, 10)
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, lower, f32(2))
	testing.expect_value(t, upper, f32(8))
}

@(test)
test_shared_range_slider_track_click_moves_nearest_handle :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.style = uifw.gui_default_style()
	mouse_y := ctx.style.body_line_height + ctx.style.spacing_2 + 2
	uifw.gui_begin_frame(&ctx, {mouse_pos = {105, mouse_y}, mouse_pressed = true, mouse_down = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 320, 120}, .Column, 0, 44)
	lower := f32(0.1)
	upper := f32(0.9)
	changed := game.shared_range_slider_f32(&ctx, "Range", "test_range", &lower, &upper, 0, 1)
	uifw.gui_layout_end(&ctx)
	testing.expect(t, changed)
	testing.expect(t, lower > 0.2 && lower < upper)
	testing.expect_value(t, upper, f32(0.9))
	testing.expect_value(t, ctx.focused, uifw.gui_make_id(&ctx, "test_range_lower"))
}

@(test)
test_shared_range_slider_controller_cancel_restores_endpoint :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.style = uifw.gui_default_style()
	ctx.controller_explicit_activation = true
	lower := f32(0.2)
	upper := f32(0.8)
	lower_id := uifw.gui_make_id(&ctx, "test_range_lower")
	ctx.focused = lower_id

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, accept = true, accept_pressed = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 320, 120}, .Column, 0, 44)
	_ = game.shared_range_slider_f32(&ctx, "Range", "test_range", &lower, &upper, 0, 1)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, ctx.focus_edit_id, lower_id)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, nav_pressed_x = 1, nav_x = 1})
	uifw.gui_layout_begin(&ctx, {0, 0, 320, 120}, .Column, 0, 44)
	_ = game.shared_range_slider_f32(&ctx, "Range", "test_range", &lower, &upper, 0, 1)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect(t, lower > 0.2)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, back = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 320, 120}, .Column, 0, 44)
	_ = game.shared_range_slider_f32(&ctx, "Range", "test_range", &lower, &upper, 0, 1)
	uifw.gui_layout_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, lower, f32(0.2))
	testing.expect_value(t, ctx.focus_edit_id, uifw.GUI_ID_NONE)
}

@(test)
test_shared_two_axis_pad_updates_both_fields_from_pointer :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.style = uifw.gui_default_style()
	uifw.gui_begin_frame(&ctx, {mouse_pos = {290, 42}, mouse_pressed = true, mouse_down = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 320, 240}, .Column, 0, 44)
	x := f32(0)
	y := f32(0)
	changed := game.shared_two_axis_pad_f32(&ctx, "Pad", "test_pad", "X", "Y", &x, &y, 0, 1, 0, 1)
	uifw.gui_layout_end(&ctx)
	testing.expect(t, changed)
	testing.expect(t, x > 0.8)
	testing.expect(t, y > 0.7)
}

@(test)
test_simulation_controller_panel_uses_scoped_focus_region_and_leaves_edit_mode :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	ui: game.App_Ui_State
	settings := game.settings_default()
	settings.remember_controller_focus = true
	game.app_ui_init(&ui, settings)
	ui.mode = .Gray_Scott
	state := game.simulation_controller_ui_state(&ui)
	state.panel_open = true
	state.deck_visible = true
	state.focus.phase = .Child_Region
	state.focus.remember_focus = true
	gray: game.Gray_Scott_Simulation
	game.gray_scott_init(&gray, 320, 240)
	ctx.style = uifw.gui_default_style()

	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720})
	game.simulation_controller_ui_draw_panel(&ui, &ctx, &gray, nil, nil, {0, 0, 760, 420}, nil)
	section := game.simulation_controller_ui_section(ui.mode, state.active_index)
	panel_region := game.simulation_controller_ui_panel_region_id(&ctx, section)
	target := uifw.GUI_ID_NONE
	for item in ctx.spatial_items[:ctx.spatial_item_count] {
		if item.focusable && item.group == panel_region {target = item.id; break}
	}
	testing.expect(t, target != uifw.GUI_ID_NONE)
	ctx.focused = target
	uifw.gui_end_frame(&ctx)
	game.simulation_controller_ui_end_frame(&ui, &ctx)
	testing.expect_value(t, uifw.gui_controller_focus_restore(&state.focus, panel_region, uifw.GUI_ID_NONE), target)

	state.focus.phase = .Active_Control
	state.focus.parent_region = game.simulation_controller_ui_region_id(&ctx, "deck")
	ctx.focused = uifw.GUI_ID_NONE
	uifw.gui_begin_frame(&ctx, {window_width = 1280, window_height = 720, active_device = .Controller})
	game.simulation_controller_ui_draw_panel(&ui, &ctx, &gray, nil, nil, {0, 0, 760, 420}, nil)
	testing.expect_value(t, state.focus.phase, uifw.Controller_Focus_Phase.Child_Region)
}

@(test)
test_preset_selector_side_arrows_cycle_and_apply_builtin_presets :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	gray: game.Gray_Scott_Simulation
	game.gray_scott_init(&gray, 320, 240)
	state: game.Preset_Fieldset_State

	uifw.gui_begin_frame(&ctx, {mouse_pos = {240, 22}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 120}, .Column, 0, 44)
	game.preset_fieldset_draw(&ctx, &state, nil, "gray_scott", game.GRAY_SCOTT_BUILTIN_PRESET_NAMES[:], 1, {
		kind = .Gray_Scott,
		gray_scott = &gray,
	})
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, state.selected_index, 2)
	testing.expect_value(t, gray.runtime.current_preset_index, 2)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {20, 22}, mouse_pressed = true, mouse_released = true})
	uifw.gui_layout_begin(&ctx, {0, 0, 260, 120}, .Column, 0, 44)
	game.preset_fieldset_draw(&ctx, &state, nil, "gray_scott", game.GRAY_SCOTT_BUILTIN_PRESET_NAMES[:], gray.runtime.current_preset_index, {
		kind = .Gray_Scott,
		gray_scott = &gray,
	})
	uifw.gui_layout_end(&ctx)
	testing.expect_value(t, state.selected_index, 1)
	testing.expect_value(t, gray.runtime.current_preset_index, 1)
}

@(test)
test_gui_column_layout_allocates_rows :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_layout_begin(&ctx, {10, 20, 200, 120}, .Column, 5, 30)
	first := uifw.gui_next_rect(&ctx)
	second := uifw.gui_next_rect(&ctx, height = 40)
	uifw.gui_layout_end(&ctx)

	testing.expect_value(t, first.x, f32(10))
	testing.expect_value(t, first.y, f32(20))
	testing.expect_value(t, first.w, f32(200))
	testing.expect_value(t, first.h, f32(30))
	testing.expect_value(t, second.y, f32(55))
	testing.expect_value(t, second.h, f32(40))
}

@(test)
test_gui_grid_layout_allocates_cards :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	grid := uifw.gui_grid_begin(&ctx, {0, 0, 210, 200}, 2, 10)
	first := uifw.gui_grid_next(&grid, 50)
	second := uifw.gui_grid_next(&grid, 50)
	third := uifw.gui_grid_next(&grid, 50)

	testing.expect_value(t, first, uifw.Rect{0, 0, 100, 50})
	testing.expect_value(t, second, uifw.Rect{110, 0, 100, 50})
	testing.expect_value(t, third, uifw.Rect{0, 60, 100, 50})
}

@(test)
test_gui_scroll_area_clamps_and_offsets_content :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	scroll := f32(0)
	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, wheel_delta = -4})
	uifw.gui_scroll_begin(&ctx, {0, 0, 120, 100}, 190, &scroll)
	first := uifw.gui_next_rect(&ctx, height = 40)
	uifw.gui_scroll_end(&ctx)

	testing.expect_value(t, scroll, f32(90))
	testing.expect_value(t, first.y, f32(-90))
	saw_scissor_begin := false
	saw_scissor_end := false
	scrollbar_rects := 0
	for command in ctx.commands {
		if command.kind == uifw.Draw_Command_Kind.Scissor_Begin {
			saw_scissor_begin = true
		}
		if command.kind == uifw.Draw_Command_Kind.Scissor_End {
			saw_scissor_end = true
		}
		if command.kind == uifw.Draw_Command_Kind.Filled_Rounded_Rect {
			scrollbar_rects += 1
		}
	}
	testing.expect(t, saw_scissor_begin)
	testing.expect(t, saw_scissor_end)
	testing.expect(t, scrollbar_rects >= 2)
}

@(test)
test_gui_draggable_scroll_tracks_pointer_and_consumes_release :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	viewport := uifw.Rect{0, 0, 120, 100}
	scroll := f32(0)
	uifw.gui_begin_frame(&ctx, {mouse_pos = {40, 70}, mouse_pressed = true, mouse_down = true})
	uifw.gui_scroll_begin_draggable(&ctx, viewport, 220, &scroll)
	row := uifw.gui_next_rect(&ctx, height = 80)
	id := uifw.gui_make_id(&ctx, "row")
	_ = uifw.gui_control(&ctx, id, row)
	uifw.gui_scroll_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, scroll, f32(0))
	testing.expect_value(t, ctx.active, id)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {40, 30}, mouse_down = true})
	uifw.gui_scroll_begin_draggable(&ctx, viewport, 220, &scroll)
	row = uifw.gui_next_rect(&ctx, height = 80)
	_ = uifw.gui_control(&ctx, id, row)
	uifw.gui_scroll_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, scroll, f32(40))
	testing.expect_value(t, ctx.active, uifw.GUI_ID_NONE)

	uifw.gui_begin_frame(&ctx, {mouse_pos = {40, 30}, mouse_released = true})
	testing.expect(t, !ctx.input.mouse_released)
	uifw.gui_scroll_begin_draggable(&ctx, viewport, 220, &scroll)
	uifw.gui_scroll_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, scroll, f32(40))
}

@(test)
test_gui_draggable_scroll_accepts_controller_virtual_cursor_stream :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	viewport := uifw.Rect{0, 0, 120, 100}
	scroll := f32(20)
	uifw.gui_begin_frame(&ctx, {active_device = .Controller, pointer_enabled = true, mouse_pos = {60, 70}, mouse_pressed = true, mouse_down = true})
	uifw.gui_scroll_begin_draggable(&ctx, viewport, 220, &scroll)
	uifw.gui_scroll_end(&ctx)
	uifw.gui_end_frame(&ctx)

	uifw.gui_begin_frame(&ctx, {active_device = .Controller, pointer_enabled = true, mouse_pos = {60, 20}, mouse_down = true})
	uifw.gui_scroll_begin_draggable(&ctx, viewport, 220, &scroll)
	uifw.gui_scroll_end(&ctx)
	uifw.gui_end_frame(&ctx)
	testing.expect_value(t, scroll, f32(70))
}

@(test)
test_touch_coordinates_convert_to_logical_window_space :: proc(t: ^testing.T) {
	position := host.app_touch_logical_position(0.25, 0.75, 1600, 900)
	testing.expect_value(t, position.x, f32(399.75))
	testing.expect_value(t, position.y, f32(674.25))

	clamped := host.app_touch_logical_position(-0.5, 1.5, 1600, 900)
	testing.expect_value(t, clamped.x, f32(0))
	testing.expect_value(t, clamped.y, f32(899))
}

@(test)
test_gui_wheel_scroll_is_not_overridden_by_focus_reveal :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	scroll := f32(40)
	uifw.gui_begin_frame(&ctx, {mouse_pos = {10, 10}, wheel_delta = -1})
	uifw.gui_scroll_begin(&ctx, {0, 0, 120, 100}, 190, &scroll)
	bounds := uifw.gui_next_rect(&ctx, height = 40)
	id := uifw.gui_make_id(&ctx, "partially_visible")
	_ = uifw.gui_control(&ctx, id, bounds)
	ctx.focused = id
	ctx.focus_moved = true
	uifw.gui_scroll_end(&ctx)
	uifw.gui_end_frame(&ctx)

	testing.expect_value(t, scroll, f32(72))
}

@(test)
test_gui_scroll_area_reserves_scrollbar_gutter_for_overflowing_content :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.style.scrollbar_width = 6
	ctx.style.scrollbar_gutter = 8
	ctx.style.border_width = 1

	viewport := uifw.Rect{0, 0, 120, 100}
	scroll := f32(0)
	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_scroll_begin(&ctx, viewport, 190, &scroll)
	first := uifw.gui_next_rect(&ctx, height = 40)
	uifw.gui_scroll_end(&ctx)

	expected_w := viewport.w - ctx.style.scrollbar_width - ctx.style.scrollbar_gutter - ctx.style.border_width * 2
	track_x := viewport.x + viewport.w - ctx.style.scrollbar_width - ctx.style.border_width * 2
	testing.expect_value(t, first.w, expected_w)
	testing.expect_value(t, track_x - (first.x + first.w), ctx.style.scrollbar_gutter)
}

@(test)
test_gui_scroll_area_keeps_full_content_width_when_content_fits :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)
	ctx.style.scrollbar_width = 6
	ctx.style.scrollbar_gutter = 8
	ctx.style.border_width = 1

	viewport := uifw.Rect{0, 0, 120, 100}
	scroll := f32(0)
	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_scroll_begin(&ctx, viewport, 100, &scroll)
	first := uifw.gui_next_rect(&ctx, height = 40)
	uifw.gui_scroll_end(&ctx)

	testing.expect_value(t, first.w, viewport.w)
}

@(test)
test_gui_scroll_area_draws_bottom_edge_fade_at_top :: proc(t: ^testing.T) {
	ctx: uifw.Gui_Context
	uifw.gui_init(&ctx)
	defer uifw.gui_destroy(&ctx)

	viewport := uifw.Rect{0, 0, 120, 100}
	scroll := f32(0)
	uifw.gui_begin_frame(&ctx, {})
	uifw.gui_scroll_begin(&ctx, viewport, 190, &scroll)
	uifw.gui_scroll_end(&ctx)

	top, bottom := test_count_scroll_fades(ctx.commands[:], viewport)
	testing.expect_value(t, top, 0)
	testing.expect_value(t, bottom, 1)
}
