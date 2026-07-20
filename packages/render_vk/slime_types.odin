package render_vk

import engine "zelda_engine:engine"
import vk "vendor:vulkan"

SLIME_IMAGE_FORMAT :: vk.Format(.R8G8B8A8_UNORM)

Slime_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	layout: vk.ImageLayout,
	width: u32,
	height: u32,
}

Slime_Gpu_State :: struct {
	width, height, agent_count: u32,
	update_shader, decay_shader, diffuse_shader, update_speeds_shader: engine.Vk_Shader_Module,
	reset_shader, gradient_shader, display_shader: engine.Vk_Shader_Module,
	present_vertex_shader, present_fragment_shader: engine.Vk_Shader_Module,
	update_pipeline, decay_pipeline, diffuse_pipeline, update_speeds_pipeline: engine.Vk_Compute_Pipeline,
	reset_pipeline, gradient_pipeline, display_pipeline: engine.Vk_Compute_Pipeline,
	present_pipeline: engine.Vk_Graphics_Pipeline,
	sim_set_layout, display_set_layout, texture_set_layout, camera_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	sim_sets, display_sets, texture_sets, camera_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	present_camera_zoom: f32,
	agent_buffer, trail_buffer, mask_buffer, gradient_buffer: engine.Vk_Buffer,
	sim_buffers, cursor_buffers, render_params_buffers, camera_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	display_image: Slime_Image,
	webcam_images: [engine.MAX_FRAMES_IN_FLIGHT]Slime_Image,
	webcam_staging_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	webcam_upload_pending, webcam_image_ready: [engine.MAX_FRAMES_IN_FLIGHT]bool,
	webcam_live: bool,
	webcam_fit_mode: Vector_Image_Fit_Mode,
	sampler: vk.Sampler,
	agent_speed_min_uploaded, agent_speed_max_uploaded: f32,
	needs_reset, ready: bool,
}

slime_speed_range_changed :: proc(gpu: ^Slime_Gpu_State, settings: ^Slime_Settings) -> bool {
	return gpu.agent_speed_min_uploaded != settings.agent_speed_min ||
	       gpu.agent_speed_max_uploaded != settings.agent_speed_max
}
