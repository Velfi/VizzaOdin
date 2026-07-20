package render_vk

import engine "zelda_engine:engine"
import vk "vendor:vulkan"

// Renderer-local callback used when a feature presentation pass needs the UI
// overlay inserted between its own draw phases. It is deliberately not part of
// the product API because command buffers and image extents are Vulkan details.
Ui_Render_Sink :: struct {
	userdata: rawptr,
	draw: proc(rawptr, ^engine.Vk_Context, vk.CommandBuffer, vk.Extent2D),
}

ui_render_sink_draw :: proc(sink: ^Ui_Render_Sink, ctx: ^engine.Vk_Context, command_buffer: vk.CommandBuffer, extent: vk.Extent2D) {
	if sink != nil && sink.draw != nil {
		sink.draw(sink.userdata, ctx, command_buffer, extent)
	}
}
