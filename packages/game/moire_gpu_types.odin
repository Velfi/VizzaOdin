package game

// Renderer-neutral shader ABI shared with Slang. Vulkan resources and shader
// pipeline ownership live in render_vk/moire_types.odin.
Moire_Params :: struct #align(16) {
	time: f32,
	width: f32,
	height: f32,
	generator_type: f32,
	base_freq: f32,
	moire_amount: f32,
	moire_rotation: f32,
	moire_scale: f32,
	moire_interference: f32,
	moire_rotation3: f32,
	moire_scale3: f32,
	moire_weight3: f32,
	radial_swirl_strength: f32,
	radial_starburst_count: f32,
	radial_center_brightness: f32,
	color_scheme_reversed: f32,
	advect_strength: f32,
	advect_speed: f32,
	curl: f32,
	decay: f32,
	image_loaded: f32,
	image_mode_enabled: f32,
	image_interference_mode: f32,
	image_mirror_horizontal: f32,
	image_mirror_vertical: f32,
	image_invert_tone: f32,
	_pad0: f32,
	_pad1: f32,
}

Moire_Render_Params :: struct #align(16) {
	filtering_mode: u32,
	_pad0: u32,
	_pad1: u32,
	_pad2: u32,
}

Moire_Camera :: Vectors_Camera_Uniform
