package game

import engine "../engine"
import uifw "../ui"

Controller_Prompt_Icon :: enum {
	Dpad,
	Left_Shoulder,
	Right_Shoulder,
	South,
	East,
	Left_Stick,
}

Controller_Prompt_Hint :: struct {
	icons: [3]Controller_Prompt_Icon,
	icon_count: int,
	label: string,
}

controller_prompt_icon_index :: proc(icon: Controller_Prompt_Icon, style: uifw.Controller_Prompt_Style) -> int {
	return int(style) * uifw.UI_KENNEY_INPUT_ICONS_PER_STYLE + int(icon)
}

controller_prompt_icon_uv :: proc(icon: Controller_Prompt_Icon, style: uifw.Controller_Prompt_Style) -> uifw.Rect {
	count := f32(uifw.UI_KENNEY_INPUT_ICON_COUNT)
	u0 := f32(controller_prompt_icon_index(icon, style)) / count
	return {u0, 0, 1 / count, 1}
}

controller_prompt_face_icons :: proc(settings: ^App_Settings) -> (accept, back: Controller_Prompt_Icon) {
	south_accept := settings == nil || app_controller_south_is_accept(settings^)
	return south_accept ? .South : .East, south_accept ? .East : .South
}

controller_prompt_draw_items :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, items: []Controller_Prompt_Hint) {
	if len(items) == 0 {
		return
	}
	base_icon_size := min(rect.h, max(gui.style.small_line_height * 0.94, f32(14)))
	icon_gap := max(gui.style.spacing_1 * 0.22, gui.style.border_width)
	label_gap := max(gui.style.spacing_1 * 0.52, gui.style.border_width * 2)
	item_gap := max(gui.style.spacing_2 * 0.9, base_icon_size * 0.58)
	text_scale := SLIME_CONTROLLER_UI_HINT_SCALE
	total_w := item_gap * f32(max(len(items) - 1, 0))
	for item in items {
		icon_count := max(min(item.icon_count, len(item.icons)), 0)
		icons_w := f32(icon_count) * base_icon_size + f32(max(icon_count - 1, 0)) * icon_gap
		label_w := slime_controller_ui_text_width_scaled(gui, item.label, text_scale)
		total_w += icons_w + (icon_count > 0 ? label_gap : 0) + label_w
	}
	fit := min(rect.w / max(total_w, 1), f32(1))
	icon_size := base_icon_size * fit
	icon_gap *= fit
	label_gap *= fit
	item_gap *= fit
	text_scale = max(text_scale * fit, f32(0.42))

	// Re-measure at the fitted text size so the row stays visually centered.
	total_w = item_gap * f32(max(len(items) - 1, 0))
	for item in items {
		icon_count := max(min(item.icon_count, len(item.icons)), 0)
		icons_w := f32(icon_count) * icon_size + f32(max(icon_count - 1, 0)) * icon_gap
		label_w := slime_controller_ui_text_width_scaled(gui, item.label, text_scale)
		total_w += icons_w + (icon_count > 0 ? label_gap : 0) + label_w
	}

	x := rect.x + max((rect.w - total_w) * 0.5, 0)
	icon_y := rect.y + (rect.h - icon_size) * 0.5
	for item, item_index in items {
		icon_count := max(min(item.icon_count, len(item.icons)), 0)
		for icon_index in 0 ..< icon_count {
			icon_rect := uifw.Rect{x, icon_y, icon_size, icon_size}
			uifw.gui_image_uv_filtered(
				gui,
				icon_rect,
				uifw.Gui_Image_Id(uifw.UI_KENNEY_INPUT_ATLAS_TEXTURE_ID),
				gui.style.text_muted,
				controller_prompt_icon_uv(item.icons[icon_index], gui.input.controller_prompt_style),
				{brightness = 1, contrast = 1},
			)
			x += icon_size
			if icon_index + 1 < icon_count {
				x += icon_gap
			}
		}
		if icon_count > 0 {
			x += label_gap
		}
		label_w := slime_controller_ui_text_width_scaled(gui, item.label, text_scale)
		label_rect := uifw.Rect{x, rect.y, label_w, rect.h}
		uifw.gui_text_aligned_scaled(gui, label_rect, item.label, gui.style.text_muted, .Left, text_scale)
		x += label_w
		if item_index + 1 < len(items) {
			x += item_gap
		}
	}
}

controller_prompt_draw_context_hint :: proc(gui: ^uifw.Gui_Context, rect: uifw.Rect, phase: uifw.Controller_Focus_Phase, settings: ^App_Settings = nil) {
	accept, back := controller_prompt_face_icons(settings)
	switch phase {
	case .Region:
		items := [?]Controller_Prompt_Hint {
			{icons = {.Dpad, .Left_Shoulder, .Right_Shoulder}, icon_count = 3, label = "Browse"},
			{icons = {accept, .Dpad, .Dpad}, icon_count = 1, label = "Open"},
			{icons = {back, .Dpad, .Dpad}, icon_count = 1, label = "Close"},
		}
		controller_prompt_draw_items(gui, rect, items[:])
	case .Child_Region:
		items := [?]Controller_Prompt_Hint {
			{icons = {.Dpad, .Dpad, .Dpad}, icon_count = 1, label = "Navigate"},
			{icons = {accept, .Dpad, .Dpad}, icon_count = 1, label = "Edit"},
			{icons = {back, .Dpad, .Dpad}, icon_count = 1, label = "Sections"},
		}
		controller_prompt_draw_items(gui, rect, items[:])
	case .Active_Control:
		items := [?]Controller_Prompt_Hint {
			{icons = {.Dpad, .Dpad, .Dpad}, icon_count = 1, label = "Adjust"},
			{icons = {.Left_Stick, .Dpad, .Dpad}, icon_count = 1, label = "Fine"},
			{icons = {back, .Dpad, .Dpad}, icon_count = 1, label = "Step"},
			{icons = {accept, .Dpad, .Dpad}, icon_count = 1, label = "Commit"},
			{icons = {back, .Dpad, .Dpad}, icon_count = 1, label = "Cancel"},
		}
		controller_prompt_draw_items(gui, rect, items[:])
	case .Unfocused:
		items := [?]Controller_Prompt_Hint {
			{icons = {.Left_Shoulder, .Right_Shoulder, .Dpad}, icon_count = 2, label = "Focus controls"},
		}
		controller_prompt_draw_items(gui, rect, items[:])
	}
}
