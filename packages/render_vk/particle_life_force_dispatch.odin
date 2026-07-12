package render_vk

import vk "vendor:vulkan"

// Force-matrix commands are kept separate from the main particle-life GPU
// orchestration so that force editing can evolve without growing that module.
particle_life_dispatch_force_randomize :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	_ = cmd
	particle_life_force_matrix_upload_existing(sim, particle_life_gpu(sim).uploaded_species_count)
	sim.runtime.pending_force_randomize = false
}

particle_life_dispatch_force_update :: proc(sim: ^Particle_Life_Simulation, cmd: vk.CommandBuffer) {
	frame_slot := particle_life_gpu(sim).active_frame_slot
	if particle_life_gpu(sim).force_update_params_buffers[frame_slot].mapped == nil {
		return
	}
	params := cast(^Particle_Life_Force_Update_Params)particle_life_gpu(sim).force_update_params_buffers[frame_slot].mapped
	params^ = {
		species_a = sim.runtime.pending_force_a,
		species_b = sim.runtime.pending_force_b,
		new_force = sim.runtime.pending_force_value,
		species_count = particle_life_gpu(sim).uploaded_species_count,
	}
	vk.CmdBindPipeline(cmd, .COMPUTE, particle_life_gpu(sim).force_update_pipeline.pipeline)
	force_update_set := particle_life_gpu(sim).force_update_sets[frame_slot]
	vk.CmdBindDescriptorSets(cmd, .COMPUTE, particle_life_gpu(sim).force_update_pipeline.layout, 0, 1, &force_update_set, 0, nil)
	vk.CmdDispatch(cmd, 1, 1, 1)
	particle_life_force_barrier(sim, cmd)
	sim.runtime.pending_force_update = false
}
