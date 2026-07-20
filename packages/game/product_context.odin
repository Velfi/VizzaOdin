package game

import uifw "zelda_engine:ui"

// Product_Context is the narrow boundary exposed to Vizza UI and simulation
// controls. It deliberately excludes SDL, Vulkan, threads, screenshots, and
// render-worker lifetime state. The optional document asset pointer is an
// immutable renderer-neutral UI service owned by the app composition layer.
Product_Context :: struct {
	ui_to_render: ^Ui_To_Render_Queue,
	render_to_ui: ^Render_To_Ui_Queue,
	settings: App_Settings,
	documents: ^uifw.Ui_Document_Assets,
}
