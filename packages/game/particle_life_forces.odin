package game

import uifw "../ui"

import "core:math"

particle_life_force_clamp :: proc(value: f32) -> f32 {
	return max(min(value, 1.0), -1.0)
}

particle_life_force_random_bool :: proc(seed: ^u32, probability: f32) -> bool {
	return particle_life_random01(seed) < probability
}

particle_life_force_random_int :: proc(seed: ^u32, min_value, max_value: int) -> int {
	if max_value <= min_value {
		return min_value
	}
	span := max_value - min_value + 1
	return min_value + int(particle_life_random01(seed) * f32(span)) % span
}

particle_life_force_species_distance :: proc(i, j: int) -> int {
	if i > j {
		return i - j
	}
	return j - i
}

particle_life_force_species_prime :: proc(n: int) -> bool {
	if n < 2 {
		return false
	}
	limit := int(math.sqrt(f32(n)))
	for i in 2 ..= limit {
		if n % i == 0 {
			return false
		}
	}
	return true
}

particle_life_force_matrix_set :: proc(force_values: ^[PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32, row, col, species_count: int, value: f32) {
	if row < 0 || col < 0 || row >= species_count || col >= species_count {
		return
	}
	force_values[row * PARTICLE_LIFE_MAX_SPECIES + col] = particle_life_force_clamp(value)
}

particle_life_generate_force_matrix :: proc(
	force_values: ^[PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32,
	species_count: u32,
	force_generator: u32,
	random_min, random_max: f32,
	base_seed: u32,
) {
	n := int(max(min(species_count, PARTICLE_LIFE_MAX_SPECIES), 1))
	seed := base_seed
	for i in 0 ..< len(force_values) {force_values[i] = 0}
	if particle_life_generate_force_classic(force_values, n, force_generator, &seed, random_min, random_max) {return}
	if particle_life_generate_force_structured(force_values, n, force_generator, &seed, random_min, random_max) {return}
	_ = particle_life_generate_force_numeric(force_values, n, force_generator, &seed, random_min, random_max)
}

particle_life_force_set :: proc(force_values: ^[PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32, n, i, j: int, value: f32) {
	particle_life_force_matrix_set(force_values, i, j, n, value)
}

particle_life_force_rr :: proc(seed: ^u32, min_value, max_value: f32) -> f32 {
	return particle_life_random_range(seed, min_value, max_value)
}

particle_life_generate_force_classic :: proc(force_values: ^[PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32, n: int, force_generator: u32, seed: ^u32, random_min, random_max: f32) -> bool {
	switch force_generator {

	case 1: // Symmetry
		base_strength := particle_life_force_rr(seed, 0.3, 0.8)
		variation := particle_life_force_rr(seed, 0.1, 0.4)
		for i in 0 ..< n {
			for j in i ..< n {
				value: f32
				if i == j {
					value = particle_life_force_rr(seed, -0.3, -0.05)
				} else {
					sign: f32 = particle_life_force_random_bool(seed, 0.5) ? 1.0 : -1.0
					value = sign * particle_life_force_rr(seed, 0.2, base_strength) + particle_life_force_rr(seed, -variation, variation)
				}
				particle_life_force_set(force_values, n, i, j, value)
				if i != j do particle_life_force_set(force_values, n, j, i, value)
			}
		}
	case 2: // Chains
		chain_strength := particle_life_force_rr(seed, 0.3, 0.7)
		self_repulsion := particle_life_force_rr(seed, -0.3, -0.05)
		background_strength := particle_life_force_rr(seed, -0.2, 0.1)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := background_strength + particle_life_force_rr(seed, -0.05, 0.05)
				if i == j {
					value = self_repulsion
				} else if particle_life_force_species_distance(i, j) == 1 {
					value = chain_strength + particle_life_force_rr(seed, -0.1, 0.1)
				}
				particle_life_force_set(force_values, n, i, j, value)
			}
		}
	case 3: // Chains 2
		near_strength := particle_life_force_rr(seed, 0.2, 0.6)
		far_strength := particle_life_force_rr(seed, -0.3, 0.1)
		self_repulsion := particle_life_force_rr(seed, -0.4, -0.1)
		for i in 0 ..< n {
			for j in 0 ..< n {
				distance := particle_life_force_species_distance(i, j)
				value := particle_life_force_rr(seed, -0.1, 0.05)
				if i == j {
					value = self_repulsion
				} else if distance == 1 {
					value = near_strength + particle_life_force_rr(seed, -0.15, 0.15)
				} else if distance == 2 {
					value = far_strength + particle_life_force_rr(seed, -0.1, 0.1)
				}
				particle_life_force_set(force_values, n, i, j, value)
			}
		}
	case 4: // Chains 3
		decay_rate := particle_life_force_rr(seed, 0.6, 0.9)
		base_strength := particle_life_force_rr(seed, 0.3, 0.6)
		self_repulsion := particle_life_force_rr(seed, -0.3, -0.05)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := self_repulsion
				if i != j {
					distance := f32(particle_life_force_species_distance(i, j))
					value = particle_life_force_clamp(base_strength * math.pow(decay_rate, distance) + particle_life_force_rr(seed, -0.1, 0.1))
				}
				particle_life_force_set(force_values, n, i, j, value)
			}
		}
	case 5: // Snakes
		snake_strength := particle_life_force_rr(seed, 0.2, 0.5)
		end_connection_strength := particle_life_force_rr(seed, 0.1, 0.4)
		self_repulsion := particle_life_force_rr(seed, -0.3, -0.05)
		background_strength := particle_life_force_rr(seed, -0.1, 0.05)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := background_strength + particle_life_force_rr(seed, -0.05, 0.05)
				if i == j {
					value = self_repulsion
				} else if i == 0 && j == n - 1 {
					value = end_connection_strength + particle_life_force_rr(seed, -0.1, 0.1)
				} else if particle_life_force_species_distance(i, j) == 1 {
					value = snake_strength + particle_life_force_rr(seed, -0.1, 0.1)
				}
				particle_life_force_set(force_values, n, i, j, value)
			}
		}
	case 6: // Zero
		for i in 0 ..< n {
			for j in 0 ..< n {
				particle_life_force_set(force_values, n, i, j, particle_life_force_rr(seed, -0.01, 0.01))
			}
		}
	case:
		return false
	}
	return true
}

particle_life_generate_force_structured :: proc(force_values: ^[PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32, n: int, force_generator: u32, seed: ^u32, random_min, random_max: f32) -> bool {
	switch force_generator {
	case 7: // Predator Prey
		for i in 0 ..< n {
			for j in 0 ..< n {
				value: f32 = 0
				if i == j {
					value = -0.1
				} else if j == (i + 1) % n {
					value = 0.4
				} else if i == (j + 1) % n {
					value = -0.3
				}
				particle_life_force_set(force_values, n, i, j, value)
			}
		}
	case 8: // Symbiosis
		symbiosis_strength := particle_life_force_rr(seed, 0.4, 0.8)
		self_repulsion := particle_life_force_rr(seed, -0.3, -0.05)
		background_strength := particle_life_force_rr(seed, -0.1, 0.1)
		for i in 0 ..< n {
			for j in i ..< n {
				value := background_strength + particle_life_force_rr(seed, -0.05, 0.05)
				if i == j {
					value = self_repulsion
				} else if (i % 2 == 0 && j == i + 1) || (j % 2 == 0 && i == j + 1) {
					value = symbiosis_strength + particle_life_force_rr(seed, -0.1, 0.1)
				}
				particle_life_force_set(force_values, n, i, j, value)
				if i != j do particle_life_force_set(force_values, n, j, i, value)
			}
		}
	case 9: // Territorial
		self_repulsion := particle_life_force_rr(seed, -0.9, -0.5)
		other_repulsion_base := particle_life_force_rr(seed, -0.5, -0.1)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := i == j ? self_repulsion : other_repulsion_base + particle_life_force_rr(seed, -0.2, 0.2)
				particle_life_force_set(force_values, n, i, j, value)
			}
		}
	case 10: // Magnetic
		attraction_strength := particle_life_force_rr(seed, 0.2, 0.6)
		repulsion_strength := particle_life_force_rr(seed, -0.6, -0.2)
		self_repulsion := particle_life_force_rr(seed, -0.3, -0.05)
		for i in 0 ..< n {
			for j in i ..< n {
				value := self_repulsion
				if i != j {
					same_charge := (i % 2 == 0) == (j % 2 == 0)
					value = (same_charge ? attraction_strength : repulsion_strength) + particle_life_force_rr(seed, -0.1, 0.1)
				}
				particle_life_force_set(force_values, n, i, j, value)
				if i != j do particle_life_force_set(force_values, n, j, i, value)
			}
		}
	case 11: // Crystal
		lattice_strength := particle_life_force_rr(seed, 0.4, 0.8)
		self_repulsion := particle_life_force_rr(seed, -0.4, -0.1)
		background_strength := particle_life_force_rr(seed, -0.2, 0.05)
		lattice_variation := particle_life_force_rr(seed, 0.05, 0.2)
		for i in 0 ..< n {
			for j in i ..< n {
				neighbors := particle_life_force_species_distance(i, j) == 1 || (i == 0 && j == n - 1) || (j == 0 && i == n - 1)
				value := background_strength + particle_life_force_rr(seed, -0.1, 0.1)
				if i == j {
					value = self_repulsion
				} else if neighbors {
					value = lattice_strength + particle_life_force_rr(seed, -lattice_variation, lattice_variation)
				}
				particle_life_force_set(force_values, n, i, j, value)
				if i != j do particle_life_force_set(force_values, n, j, i, value)
			}
		}
	case 12: // Wave
		amplitude := particle_life_force_rr(seed, 0.3, 0.7)
		frequency := particle_life_force_rr(seed, 0.5, 2.0)
		phase := particle_life_force_rr(seed, 0.0, PARTICLE_LIFE_TAU)
		self_repulsion := particle_life_force_rr(seed, -0.3, -0.05)
		for i in 0 ..< n {
			for j in i ..< n {
				value := self_repulsion
				if i != j {
					distance := f32(particle_life_force_species_distance(i, j))
					value = math.sin(distance * frequency + phase) * amplitude + particle_life_force_rr(seed, -0.1, 0.1)
				}
				particle_life_force_set(force_values, n, i, j, value)
				if i != j do particle_life_force_set(force_values, n, j, i, value)
			}
		}
	case 13: // Hierarchy
		hierarchy_strength := particle_life_force_rr(seed, 0.2, 0.5)
		self_repulsion := particle_life_force_rr(seed, -0.3, -0.05)
		background_strength := particle_life_force_rr(seed, -0.05, 0.05)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := background_strength + particle_life_force_rr(seed, -0.05, 0.05)
				if i == j {
					value = self_repulsion
				} else if i < j {
					value = hierarchy_strength + particle_life_force_rr(seed, -0.1, 0.1)
				}
				particle_life_force_set(force_values, n, i, j, value)
			}
		}
	case:
		return false
	}
	return true
}

particle_life_generate_force_numeric :: proc(force_values: ^[PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32, n: int, force_generator: u32, seed: ^u32, random_min, random_max: f32) -> bool {
	switch force_generator {
	case 14, 15: // Clique / Anti-Clique
		group_size := particle_life_force_random_int(seed, 2, max(n / 2, 2))
		self_repulsion := particle_life_force_rr(seed, -0.3, -0.05)
		inside := force_generator == 14 ? particle_life_force_rr(seed, 0.3, 0.7) : particle_life_force_rr(seed, -0.7, -0.3)
		outside := force_generator == 14 ? particle_life_force_rr(seed, -0.4, -0.1) : particle_life_force_rr(seed, 0.2, 0.5)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := self_repulsion
				if i != j {
					value = ((i / group_size) == (j / group_size) ? inside : outside) + particle_life_force_rr(seed, -0.1, 0.1)
				}
				particle_life_force_set(force_values, n, i, j, value)
			}
		}
	case 16: // Fibonacci
		fib: [PARTICLE_LIFE_MAX_SPECIES]int
		fib[0] = 1
		fib[1] = 1
		for k in 2 ..< n {
			fib[k] = fib[k - 1] + fib[k - 2]
		}
		max_fib := f32(max(fib[max(n - 1, 0)], 1))
		scale_factor := particle_life_force_rr(seed, 0.5, 1.5)
		self_repulsion := particle_life_force_rr(seed, -0.3, -0.05)
		base_offset := particle_life_force_rr(seed, -0.2, 0.2)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := self_repulsion
				if i != j {
					distance := particle_life_force_species_distance(i, j)
					base_force := (f32(max(fib[distance], 1)) / max_fib) * scale_factor + base_offset
					value = base_force + particle_life_force_rr(seed, -0.1, 0.1)
				}
				particle_life_force_set(force_values, n, i, j, value)
			}
		}
	case 17: // Prime
		prime_attraction := particle_life_force_rr(seed, 0.4, 0.8)
		mixed_attraction := particle_life_force_rr(seed, 0.1, 0.4)
		non_prime_repulsion := particle_life_force_rr(seed, -0.2, -0.05)
		self_repulsion := particle_life_force_rr(seed, -0.3, -0.05)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := self_repulsion
				if i != j {
					i_prime := particle_life_force_species_prime(i)
					j_prime := particle_life_force_species_prime(j)
					if i_prime && j_prime {
						value = prime_attraction + particle_life_force_rr(seed, -0.1, 0.1)
					} else if i_prime || j_prime {
						value = mixed_attraction + particle_life_force_rr(seed, -0.1, 0.1)
					} else {
						value = non_prime_repulsion + particle_life_force_rr(seed, -0.05, 0.05)
					}
				}
				particle_life_force_set(force_values, n, i, j, value)
			}
		}
	case 18: // Fractal
		scale_factor := particle_life_force_rr(seed, 0.3, 0.7)
		frequency := particle_life_force_rr(seed, 2.0, 4.0)
		self_repulsion := particle_life_force_rr(seed, -0.3, -0.05)
		base_offset := particle_life_force_rr(seed, -0.1, 0.1)
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := self_repulsion
				if i != j {
					distance := f32(particle_life_force_species_distance(i, j))
					normalized_distance := distance / max(f32(n - 1), 1.0)
					scale := math.log2(normalized_distance * frequency + 1.0)
					value = math.sin(scale * PARTICLE_LIFE_PI) * scale_factor + base_offset + particle_life_force_rr(seed, -0.1, 0.1)
				}
				particle_life_force_set(force_values, n, i, j, value)
			}
		}
	case 19: // Rock Paper Scissors
		for i in 0 ..< n {
			for j in 0 ..< n {
				value: f32 = 0
				if i == j {
					value = -0.1
				} else if j == (i + 1) % n {
					value = 0.4
				} else if i == (j + 1) % n {
					value = -0.2
				}
				particle_life_force_set(force_values, n, i, j, value)
			}
		}
	case 20, 21: // Cooperation / Competition
		mutual_strength := force_generator == 20 ? particle_life_force_rr(seed, 0.1, 0.4) : particle_life_force_rr(seed, -0.4, -0.1)
		self_repulsion := particle_life_force_rr(seed, -0.3, -0.05)
		for i in 0 ..< n {
			for j in i ..< n {
				value := i == j ? self_repulsion : mutual_strength + particle_life_force_rr(seed, -0.1, 0.1)
				particle_life_force_set(force_values, n, i, j, value)
				if i != j do particle_life_force_set(force_values, n, j, i, value)
			}
		}
	case:
		for i in 0 ..< n {
			for j in 0 ..< n {
				value := particle_life_force_rr(seed, random_min, random_max)
				particle_life_force_set(force_values, n, i, j, value)
			}
		}

	}
	return true
}
particle_life_force_hash :: proc(seed: u32) -> u32 {
	x := seed
	x = ((x >> 16) ~ x) * 0x45d9f3b
	x = ((x >> 16) ~ x) * 0x45d9f3b
	x = (x >> 16) ~ x
	return x
}

particle_life_force_random01 :: proc(seed: u32) -> f32 {
	return f32(particle_life_force_hash(seed)) / f32(0xffffffff)
}

particle_life_mirror_force_randomize :: proc(sim: ^Particle_Life_Simulation) {
	species_count := int(max(min(sim.settings.species_count, PARTICLE_LIFE_MAX_SPECIES), 1))
	generated_matrix: [PARTICLE_LIFE_MAX_SPECIES * PARTICLE_LIFE_MAX_SPECIES]f32
	particle_life_generate_force_matrix(&generated_matrix, u32(species_count), sim.settings.force_generator, sim.settings.force_random_min, sim.settings.force_random_max, sim.runtime.seed)
	for a in 0 ..< species_count {
		for b in 0 ..< species_count {
			value := generated_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b]
			sim.runtime.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = value
			sim.settings.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = value
		}
	}
	sim.settings.custom_force_matrix = true
	sim.runtime.force_matrix_dirty = true
}

particle_life_force_value :: proc(sim: ^Particle_Life_Simulation, species_a, species_b: u32) -> f32 {
	a := min(species_a, PARTICLE_LIFE_MAX_SPECIES - 1)
	b := min(species_b, PARTICLE_LIFE_MAX_SPECIES - 1)
	return sim.runtime.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b]
}

particle_life_force_curve_value :: proc(max_force, max_distance, beta, distance: f32) -> f32 {
	min_dist := f32(0.001)
	beta_rmax := beta * max(max_distance, min_dist)
	if distance < beta_rmax {
		effective_distance := max(distance, min_dist)
		return (effective_distance / beta_rmax - 1.0) * max_force
	}
	if distance <= max_distance {
		return max_force * 0.5 * (1.0 - (1.0 + beta - (2.0 * distance) / max(max_distance, min_dist)) / max(1.0 - beta, 0.0001))
	}
	return 0
}

particle_life_force_matrix_color :: proc(value: f32) -> uifw.Color {
	amount := abs(value)
	if amount < 0.1 {
		return {0.54, 0.54, 0.54, 0.86}
	}
	if value < 0 {
		if amount < 0.3 do return {0.23, 0.51, 0.96, 0.88}
		if amount < 0.7 do return {0.15, 0.39, 0.92, 0.92}
		return {0.11, 0.31, 0.85, 0.96}
	}
	if amount < 0.3 do return {0.94, 0.27, 0.27, 0.88}
	if amount < 0.7 do return {0.86, 0.15, 0.15, 0.92}
	return {0.73, 0.11, 0.11, 0.96}
}

particle_life_force_matrix_upload_existing :: proc(sim: ^Particle_Life_Simulation, species_count: u32) {
	sim.settings.custom_force_matrix = true
	sim.runtime.force_matrix_dirty = true
	sim.runtime.pending_force_update = false
}

Particle_Life_Matrix_Transform :: enum {
	Scale_Down,
	Scale_Up,
	Rotate_CCW,
	Rotate_CW,
	Flip_H,
	Flip_V,
	Shift_Left,
	Shift_Right,
	Shift_Up,
	Shift_Down,
	Zero,
	Flip_Sign,
}

particle_life_apply_matrix_transform :: proc(sim: ^Particle_Life_Simulation, transform: Particle_Life_Matrix_Transform) {
	n := int(max(min(sim.settings.species_count, PARTICLE_LIFE_MAX_SPECIES), 1))
	old := sim.runtime.force_matrix
	new_matrix := old
	for i in 0 ..< n {
		for j in 0 ..< n {
			dst := i * PARTICLE_LIFE_MAX_SPECIES + j
			if i == j {
				new_matrix[dst] = old[dst]
				continue
			}
			switch transform {
			case .Scale_Down:
				new_matrix[dst] = max(min(old[dst] * 0.8, 1), -1)
			case .Scale_Up:
				new_matrix[dst] = max(min(old[dst] * 1.2, 1), -1)
			case .Rotate_CCW:
				new_matrix[dst] = old[j * PARTICLE_LIFE_MAX_SPECIES + (n - 1 - i)]
			case .Rotate_CW:
				new_matrix[dst] = old[(n - 1 - j) * PARTICLE_LIFE_MAX_SPECIES + i]
			case .Flip_H:
				new_matrix[dst] = old[i * PARTICLE_LIFE_MAX_SPECIES + (n - 1 - j)]
			case .Flip_V:
				new_matrix[dst] = old[(n - 1 - i) * PARTICLE_LIFE_MAX_SPECIES + j]
			case .Shift_Left:
				new_matrix[dst] = old[i * PARTICLE_LIFE_MAX_SPECIES + ((j - 1 + n) % n)]
			case .Shift_Right:
				new_matrix[dst] = old[i * PARTICLE_LIFE_MAX_SPECIES + ((j + 1) % n)]
			case .Shift_Up:
				new_matrix[dst] = old[((i - 1 + n) % n) * PARTICLE_LIFE_MAX_SPECIES + j]
			case .Shift_Down:
				new_matrix[dst] = old[((i + 1) % n) * PARTICLE_LIFE_MAX_SPECIES + j]
			case .Zero:
				new_matrix[dst] = 0
			case .Flip_Sign:
				new_matrix[dst] = -old[dst]
			}
		}
	}
	sim.runtime.force_matrix = new_matrix
	for i in 0 ..< len(sim.settings.force_matrix) {
		sim.settings.force_matrix[i] = sim.runtime.force_matrix[i]
	}
	particle_life_force_matrix_upload_existing(sim, u32(n))
}

particle_life_set_force_value :: proc(sim: ^Particle_Life_Simulation, species_a, species_b: u32, value: f32) {
	a := min(species_a, PARTICLE_LIFE_MAX_SPECIES - 1)
	b := min(species_b, PARTICLE_LIFE_MAX_SPECIES - 1)
	sim.runtime.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = value
	sim.settings.force_matrix[a * PARTICLE_LIFE_MAX_SPECIES + b] = value
	sim.settings.custom_force_matrix = true
	sim.runtime.pending_force_update = true
	sim.runtime.pending_force_a = a
	sim.runtime.pending_force_b = b
	sim.runtime.pending_force_value = value
}

particle_life_note_trail_camera :: proc(sim: ^Particle_Life_Simulation) {
	zoom := max(sim.runtime.camera_zoom, 0.25)
	if !sim.runtime.trail_camera_valid {
		sim.runtime.trail_camera_x = sim.runtime.camera_x
		sim.runtime.trail_camera_y = sim.runtime.camera_y
		sim.runtime.trail_camera_zoom = zoom
		sim.runtime.trail_camera_valid = true
		return
	}
	epsilon := f32(0.00001)
	camera_changed :=
		math.abs(sim.runtime.camera_x - sim.runtime.trail_camera_x) > epsilon ||
		math.abs(sim.runtime.camera_y - sim.runtime.trail_camera_y) > epsilon ||
		math.abs(zoom - sim.runtime.trail_camera_zoom) > epsilon
	if camera_changed {
		sim.gpu.trail_initialized = false
		sim.runtime.trail_camera_x = sim.runtime.camera_x
		sim.runtime.trail_camera_y = sim.runtime.camera_y
		sim.runtime.trail_camera_zoom = zoom
	}
}

particle_life_tile_index_floor :: proc(value: f32) -> i32 {
	return i32(math.floor(value))
}

particle_life_tile_range_for_bounds :: proc(bounds: [4]f32, camera_x, camera_y: f32, radius_value: u32, tile_size: [2]f32) -> Particle_Life_Tile_Range {
	tile_w := max(tile_size[0], 0.0001)
	tile_h := max(tile_size[1], 0.0001)
	half_w := tile_w * 0.5
	half_h := tile_h * 0.5
	min_x := particle_life_tile_index_floor((bounds[0] - half_w) / tile_w)
	max_x := particle_life_tile_index_floor((bounds[2] + half_w) / tile_w)
	min_y := particle_life_tile_index_floor((bounds[1] - half_h) / tile_h)
	max_y := particle_life_tile_index_floor((bounds[3] + half_h) / tile_h)
	center_x := particle_life_tile_index_floor(camera_x / tile_w + 0.5)
	center_y := particle_life_tile_index_floor(camera_y / tile_h + 0.5)
	radius := i32(max(min(radius_value, 32), 0))
	return {
		min_x = max(min_x, center_x - radius),
		max_x = min(max_x, center_x + radius),
		min_y = max(min_y, center_y - radius),
		max_y = min(max_y, center_y + radius),
	}
}

particle_life_tile_bounds_for_offset :: proc(bounds: [4]f32, tile_x, tile_y: i32, tile_size: [2]f32) -> [4]f32 {
	offset_x := f32(tile_x) * tile_size[0]
	offset_y := f32(tile_y) * tile_size[1]
	return {
		bounds[0] - offset_x,
		bounds[1] - offset_y,
		bounds[2] - offset_x,
		bounds[3] - offset_y,
	}
}

particle_life_reset_runtime :: proc(sim: ^Particle_Life_Simulation) {
	particle_life_clear_preserved_particles(sim)
	sim.runtime.frame_index = 0
	sim.runtime.seed += 0x9e3779b9
	if sim.runtime.seed == 0 {
		sim.runtime.seed = 0x3c6ef372
	}
	sim.runtime.needs_reset = true
}

particle_life_clear_preserved_particles :: proc(sim: ^Particle_Life_Simulation) {
	if sim.runtime.preserved_particles != nil {
		delete(sim.runtime.preserved_particles)
	}
	sim.runtime.preserved_particles = nil
}

particle_life_request_resource_rebuild :: proc(sim: ^Particle_Life_Simulation) {
	if !sim.runtime.needs_reset && sim.gpu.particle_buffer.mapped != nil && sim.gpu.uploaded_particle_count > 0 && sim.gpu.uploaded_particle_count == particle_life_target_particle_count(sim.settings) && sim.gpu.uploaded_species_count == particle_life_target_species_count(sim.settings) {
		particle_life_clear_preserved_particles(sim)
		count := int(sim.gpu.uploaded_particle_count)
		sim.runtime.preserved_particles = make([]Particle_Life_Particle, count)
		particles := (cast([^]Particle_Life_Particle)sim.gpu.particle_buffer.mapped)[:count]
		copy(sim.runtime.preserved_particles, particles)
	}
	sim.gpu.ready = false
}

particle_life_reset_camera :: proc(sim: ^Particle_Life_Simulation) {
	camera := particle_life_camera_control_state(sim)
	camera_controls_reset(&camera)
	particle_life_store_camera_control_state(sim, camera)
}
