extends Node3D
## IMPACT BURST -- a one-shot puff of low-poly dust chunks at a contact
## point. Builds its own particle system in code (no asset needed) and
## removes itself when done.

const DUST_COLOR := Color(0.82, 0.76, 0.62)

var _particles: GPUParticles3D


func _ready() -> void:
	_particles = GPUParticles3D.new()
	_particles.one_shot = true
	_particles.explosiveness = 0.95
	_particles.lifetime = 0.55
	_particles.emitting = false
	_particles.local_coords = false

	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.12, 0.12, 0.12)
	var material := StandardMaterial3D.new()
	material.albedo_color = DUST_COLOR
	material.roughness = 1.0
	chunk.material = material
	_particles.draw_pass_1 = chunk

	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 70.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 5.0
	process.gravity = Vector3(0, -Tuning.gravity, 0)
	process.scale_min = 0.4
	process.scale_max = 1.0
	process.damping_min = 1.0
	process.damping_max = 3.0
	process.angular_velocity_min = -360.0
	process.angular_velocity_max = 360.0
	_particles.process_material = process
	add_child(_particles)


## direction: which way the ball was pushed (the dust flies the other way,
## i.e. out from the surface). strength: m/s. big: more and faster chunks.
func play(direction: Vector3, strength: float, big: bool) -> void:
	var process := _particles.process_material as ParticleProcessMaterial
	process.direction = direction
	var scale_by: float = clampf(strength / Tuning.impact_big, 0.4, 2.0)
	process.initial_velocity_max = 5.0 * scale_by
	_particles.amount = 24 if big else 10
	_particles.emitting = true
	await get_tree().create_timer(_particles.lifetime + 0.2).timeout
	queue_free()
