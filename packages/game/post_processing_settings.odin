package game

import engine "../engine"
import vk "vendor:vulkan"

Post_Processing_Settings :: struct {
	blur_enabled: bool,
	blur_radius: f32,
	blur_sigma: f32,
}

Post_Blur_Params :: struct #align(16) {
	radius: f32,
	sigma: f32,
	width: f32,
	height: f32,
}

Post_Processing_Image :: struct {
	image: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
}

Post_Processing_Gpu_State :: struct {
	ready: bool,
	width: u32,
	height: u32,
	format: vk.Format,
	render_pass: vk.RenderPass,
	source: Post_Processing_Image,
	source_layout: vk.ImageLayout,
	sampler: vk.Sampler,
	params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	descriptor_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	pipeline: engine.Vk_Graphics_Pipeline,
}

post_processing_default_settings :: proc() -> Post_Processing_Settings {
	return {
		blur_enabled = false,
		blur_radius = 5.0,
		blur_sigma = 2.0,
	}
}

