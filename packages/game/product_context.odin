package game

// Product_Context is the narrow boundary exposed to Vizza UI and simulation
// controls. It deliberately excludes SDL, Vulkan, threads, screenshots, and
// render-worker lifetime state.
Product_Context :: struct {
	ui_to_render: ^Ui_To_Render_Queue,
	render_to_ui: ^Render_To_Ui_Queue,
	settings: App_Settings,
}
