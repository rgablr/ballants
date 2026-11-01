@tool
class_name DirtWall
extends StaticBody3D
## DIRT WALL -- a straight, lumpy wall of packed earth running along this
## node's local Z axis, with a jagged top edge and darker clay bands. One
## box collider (so the ball slides along it cleanly). Use it to fence a
## path, close the end of a corridor, or as a backdrop.

@export var length := 12.0:
	set(v):
		length = v
		_rebuild()
@export var height := 3.0:
	set(v):
		height = v
		_rebuild()
@export var thickness := 1.0:
	set(v):
		thickness = v
		_rebuild()
@export var seed := 3:
	set(v):
		seed = v
		_rebuild()

var _built := false


func _ready() -> void:
	_built = true
	_rebuild()


func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# The core box (collision and the plain faces).
	var core := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(thickness, height, length)
	box.material = AnthillTheme.material("packed")
	core.mesh = box
	core.position = Vector3(0.0, height * 0.5, 0.0)
	add_child(core)
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = box.size
	shape.shape = collider
	shape.position = core.position
	add_child(shape)
	# Lumps along the top and faces: flattened spheres pushed into the wall.
	var lumps := int(ceil(length / 1.5))
	var lump_material := AnthillTheme.material("dirt_dark")
	var clay := AnthillTheme.material("clay")
	for i in lumps:
		var z := -length * 0.5 + (i + 0.5) * (length / lumps) + rng.randf_range(-0.3, 0.3)
		var s := rng.randf_range(0.5, 0.9) * thickness
		var lump := CritterParts.sphere(self, Vector3(rng.randf_range(-0.2, 0.2) * thickness, height + rng.randf_range(-0.25, 0.15) * s, z),
				s, Vector3(1.2, 0.6, 1.0), lump_material, 7)
		lump.rotation.y = rng.randf() * TAU
		if rng.randf() < 0.35:
			# A clay band on one face, low down.
			var band := CritterParts.sphere(self, Vector3(signf(rng.randf() - 0.5) * thickness * 0.5, rng.randf_range(0.3, height * 0.7), z),
					s * 0.6, Vector3(0.3, 0.5, 1.6), clay, 6)
			band.rotation.y = rng.randf_range(-0.2, 0.2)
