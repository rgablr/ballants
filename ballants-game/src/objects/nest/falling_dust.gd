@tool
class_name FallingDust
extends Node3D
## FALLING DUST -- a steady trickle of dirt specks drifting down from the
## dark ceiling over a stretch of tunnel, for an old, crumbling look.
## Decorative only (no collision, nothing it does affects play). The
## specks start anywhere inside a box `size` wide/long, `height` above
## this node, and fall to about this node's height (the floor). Rotate the
## node to line the box up with a corridor (its length runs along local Z).

@export var size := Vector2(6.0, 20.0):
	set(v):
		size = v
		_rebuild()
## How high above the node the specks appear (m).
@export var height := 6.0:
	set(v):
		height = v
		_rebuild()
## Specks alive at once.
@export var amount := 60:
	set(v):
		amount = v
		_rebuild()
## Also a few thin "pours" of dirt (falling streams) along the box.
@export var pours := 2:
	set(v):
		pours = v
		_rebuild()
@export var seed := 1:
	set(v):
		seed = v
		_rebuild()

const SPECK_COLOR := Color(0.6, 0.45, 0.3)

var _built := false


func _ready() -> void:
	_built = true
	_rebuild()


func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		child.queue_free()
	var specks := _make_particles(amount, Vector3(size.x * 0.5, 0.3, size.y * 0.5), 0.05, 1.1, 4.0)
	specks.position = Vector3(0, height, 0)
	add_child(specks)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in pours:
		var pour := _make_particles(18, Vector3(0.08, 0.05, 0.08), 0.035, 3.5, 1.6)
		pour.position = Vector3(rng.randf_range(-0.4, 0.4) * size.x, height, rng.randf_range(-0.45, 0.45) * size.y)
		add_child(pour)


func _make_particles(count: int, extents: Vector3, speck: float, fall: float, life: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = maxi(count, 1)
	particles.lifetime = life
	particles.preprocess = life
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-extents.x - 1.0, -height - 1.0, -extents.z - 1.0),
			Vector3(extents.x * 2.0 + 2.0, height + 2.0, extents.z * 2.0 + 2.0))
	var mesh := BoxMesh.new()
	mesh.size = Vector3(speck, speck, speck)
	mesh.material = CritterParts.material(SPECK_COLOR, 1.0)
	particles.draw_pass_1 = mesh
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = Vector3.DOWN
	process.spread = 8.0
	process.initial_velocity_min = fall * 0.6
	process.initial_velocity_max = fall
	process.gravity = Vector3(0, -0.6, 0)
	process.scale_min = 0.5
	process.scale_max = 1.3
	process.angular_velocity_min = -90.0
	process.angular_velocity_max = 90.0
	particles.process_material = process
	return particles
