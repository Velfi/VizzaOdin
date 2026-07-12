package render_vk

import engine "../engine"

import vk "vendor:vulkan"

MOIRE_COMPUTE_SHADER_SOURCE :: "assets/shaders/simulations/moire/compute.slang"
MOIRE_PRESENT_SHADER_SOURCE :: "assets/shaders/simulations/voronoi_ca/shaders/infinite_render.slang"
MOIRE_COMPUTE_FALLBACK_SPV :: "build/shaders/simulations/moire/compute"
MOIRE_PRESENT_VERTEX_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/infinite_render_vertex"
MOIRE_PRESENT_FRAGMENT_FALLBACK_SPV :: "build/shaders/simulations/voronoi_ca/shaders/infinite_render_fragment"
MOIRE_COMPUTE_SOURCE_ENTRY :: "main"
MOIRE_PRESENT_VERTEX_SOURCE_ENTRY :: "vs_main"
MOIRE_PRESENT_FRAGMENT_SOURCE_ENTRY :: "fs_main_texture"
MOIRE_COMPUTE_ENTRY :: cstring("main")
MOIRE_PRESENT_VERTEX_ENTRY :: cstring("main")
MOIRE_PRESENT_FRAGMENT_ENTRY :: cstring("main")
MOIRE_IMAGE_FORMAT :: vk.Format(.R8G8B8A8_UNORM)
MOIRE_WORKGROUP_SIZE :: u32(8)
MOIRE_RETIRED_IMAGE_TEXTURE_CAP :: 4

Moire_Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	layout: vk.ImageLayout,
}

Moire_Retired_Image_Texture :: struct {
	image: Moire_Image,
	pending_frame_slots: u32,
}

Moire_Gpu_State :: struct {
	width: i32,
	height: i32,
	images: [2]Moire_Image,
	state_index: u32,
	compute_shader: engine.Vk_Shader_Module,
	present_vertex_shader: engine.Vk_Shader_Module,
	present_fragment_shader: engine.Vk_Shader_Module,
	compute_pipeline: engine.Vk_Compute_Pipeline,
	present_pipeline: engine.Vk_Graphics_Pipeline,
	compute_set_layout: vk.DescriptorSetLayout,
	texture_set_layout: vk.DescriptorSetLayout,
	camera_set_layout: vk.DescriptorSetLayout,
	descriptor_pool: vk.DescriptorPool,
	compute_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	texture_sets: [engine.MAX_FRAMES_IN_FLIGHT][2]vk.DescriptorSet,
	camera_sets: [engine.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	lut_buffer: engine.Vk_Buffer,
	render_params_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	camera_buffers: [engine.MAX_FRAMES_IN_FLIGHT]engine.Vk_Buffer,
	sampler: vk.Sampler,
	lut_uploaded_scheme: Color_Scheme_Name,
	lut_uploaded_reversed: bool,
	image_texture: Moire_Image,
	retired_image_textures: [MOIRE_RETIRED_IMAGE_TEXTURE_CAP]Moire_Retired_Image_Texture,
	image_loaded: bool,
	image_path: [MAX_FILE_PATH]u8,
	image_fit_uploaded: Vector_Image_Fit_Mode,
	image_mirror_horizontal_uploaded: bool,
	image_mirror_vertical_uploaded: bool,
	image_invert_tone_uploaded: bool,
	image_width: i32,
	image_height: i32,
	ready: bool,
}
