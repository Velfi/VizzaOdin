package game

import "core:c"
import sdl "vendor:sdl3"

gray_scott_webcam_device_count :: proc() -> int {
	count: c.int
	ids := sdl.GetCameras(&count)
	if ids != nil {
		sdl.free(ids)
	}
	return int(max(count, 0))
}

gray_scott_stop_webcam :: proc(sim: ^Gray_Scott_Simulation) {
	if sim.runtime.webcam != nil {
		sdl.CloseCamera(sim.runtime.webcam)
	}
	sim.runtime.webcam = nil
	sim.runtime.webcam_active = false
}

gray_scott_start_webcam :: proc(sim: ^Gray_Scott_Simulation) -> bool {
	if sim.runtime.webcam_active && sim.runtime.webcam != nil {
		return true
	}
	count: c.int
	ids := sdl.GetCameras(&count)
	if ids == nil || count <= 0 {
		sim.runtime.webcam_permission_denied = false
		return false
	}
	defer sdl.free(ids)

	camera := sdl.OpenCamera(ids[0], nil)
	if camera == nil {
		sim.runtime.webcam_permission_denied = false
		return false
	}
	sim.runtime.webcam = camera
	sim.runtime.webcam_active = true
	sim.runtime.webcam_permission_denied = false
	sim.runtime.webcam_frames = 0
	return true
}


