package render_vk

import engine "zelda_engine:engine"
import vk "vendor:vulkan"

FLOW_IMAGE_FORMAT :: vk.Format(.R8G8B8A8_UNORM)
FLOW_RETIRED_VECTOR_FIELD_IMAGE_CAP :: 4

Flow_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	layout: vk.ImageLayout,
	width, height: u32,
}

Flow_Retired_Vector_Field_Image :: struct {
	image: Flow_Image,
	pending_frame_slots: u32,
}

Flow_Gpu_State :: struct {
	vector_shader, particle_update_shader, trail_decay_shader, shape_drawing_shader: engine.Vk_Shader_Module,
	background_vertex_shader, background_fragment_shader: engine.Vk_Shader_Module,
	trail_vertex_shader, trail_fragment_shader: engine.Vk_Shader_Module,
	particle_vertex_shader, particle_fragment_shader: engine.Vk_Shader_Module,
	vector_pipeline, particle_update_pipeline, trail_decay_pipeline, shape_drawing_pipeline: engine.Vk_Compute_Pipeline,
	background_pipeline, trail_pipeline, particle_pipeline: engine.Vk_Graphics_Pipeline,
	vector_set_layout, update_set_layout, background_set_layout, trail_set_layout: vk.DescriptorSetLayout,
	shape_drawing_set_layout, particle_set_layout, camera_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	vector_sets, update_sets, background_sets, trail_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	shape_drawing_sets, particle_sets, camera_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	particle_buffer, flow_vector_buffer: engine.Vk_Buffer,
	sim_params_buffers, vector_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	background_color_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	spawn_control_buffer: engine.Vk_Buffer,
	shape_params_buffers, camera_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	trail_image, default_image, vector_field_image: Flow_Image,
	webcam_images: [engine.MAX_FRAMES_IN_FLIGHT]Flow_Image,
	webcam_staging_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	webcam_upload_pending, webcam_image_ready: [engine.MAX_FRAMES_IN_FLIGHT]bool,
	webcam_live: bool,
	webcam_width, webcam_height: u32,
	retired_vector_field_images: [FLOW_RETIRED_VECTOR_FIELD_IMAGE_CAP]Flow_Retired_Vector_Field_Image,
	vector_field_image_loaded: bool,
	vector_field_image_path: [MAX_FILE_PATH]u8,
	vector_field_image_fit_uploaded: Vector_Image_Fit_Mode,
	vector_field_image_mirror_horizontal_uploaded, vector_field_image_mirror_vertical_uploaded: bool,
	vector_field_image_invert_tone_uploaded: bool,
	sampler: vk.Sampler,
	total_pool_size, trail_width, trail_height: u32,
	autospawn_accumulator, brush_spawn_accumulator: f32,
	trail_cleared, default_image_initialized, show_particles, ready: bool,
}
