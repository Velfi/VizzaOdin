package game

import engine "../engine"
import vk "vendor:vulkan"

// Ui_Render_Sink lets simulation presentation request a UI overlay without
// depending on a concrete renderer adapter.
Ui_Render_Sink :: struct {
	userdata: rawptr,
	draw: proc(rawptr, ^engine.Vk_Context, vk.CommandBuffer, vk.Extent2D),
}

ui_render_sink_draw :: proc(sink: ^Ui_Render_Sink, ctx: ^engine.Vk_Context, command_buffer: vk.CommandBuffer, extent: vk.Extent2D) {
	if sink != nil && sink.draw != nil {
		sink.draw(sink.userdata, ctx, command_buffer, extent)
	}
}
