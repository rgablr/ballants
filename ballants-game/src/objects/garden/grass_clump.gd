@tool
class_name GrassClump
extends Node3D
## GRASS CLUMP -- a patch of tall low-poly grass blades (taller than the
## ball). Decorative by default; turn on "solid" to make the blades block
## the ball, for walls and funnels.
##
## Blades are placed with a fixed random seed, so the clump looks the same
## every time the level loads.

@export var blade_count := 12:
	set(v):
		blade_count = max(v, 1)
		_rebuild()
## Blades are scattered within this radius (meters).
@export var radius := 1.5:
	set(v):
		radius = v
		_rebuild()
@export var height_min := 2.0:
	set(v):
		height_min = v
		_rebuild()
@export var height_max := 3.5:
	set(v):
		height_max = v
		_rebuild()
## Blades push the ball back when true.
@export var solid := false:
	set(v):
		solid = v
		_rebuild()
@export var seed := 1:
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
	var body: StaticBody3D = null
	if solid:
		body = StaticBody3D.new()
		add_child(body)
	for i in blade_count:
		var angle := rng.randf() * TAU
		var distance := sqrt(rng.randf()) * radius
		var height := rng.randf_range(height_min, height_max)
		var pos := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		var blade := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.3, height, 0.06)
		mesh.left_to_right = 0.5
		mesh.material = GardenTheme.material("grass" if rng.randf() < 0.7 else "grass_dark")
		blade.mesh = mesh
		blade.position = pos + Vector3.UP * height * 0.5
		blade.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
		add_child(blade)
		if body:
			var shape := CollisionShape3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.12
			capsule.height = height
			shape.shape = capsule
			shape.transform = blade.transform
			body.add_child(shape)
