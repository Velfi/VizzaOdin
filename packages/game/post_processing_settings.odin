package game

Post_Processing_Settings :: struct {
	blur_enabled: bool,
	blur_radius: f32,
	blur_sigma: f32,
}

post_processing_default_settings :: proc() -> Post_Processing_Settings {
	return {
		blur_enabled = false,
		blur_radius = 5.0,
		blur_sigma = 2.0,
	}
}
