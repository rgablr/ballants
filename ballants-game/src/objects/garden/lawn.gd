@tool
class_name Lawn
extends Node3D
## LAWN -- a big sheet of turf with scattered grass clumps, placed BELOW a
## raised path so the world has a floor to look at. It is purely visual:
## there is no collision, so a ball that rolls off the path falls straight
## through it into the level's FallZone. Put its top below
## Tuning.fall_respawn_y so the run has already failed by then.
##
## The clumps are decorative (never solid) and seeded, so the lawn looks
## the same every time.

@export var size := Vector2(300.0, 300.0):
	set(v):
		size = v
		_rebuild()
@export var clump_count := 120:
	set(v):
		clump_count = max(v, 0)
		_rebuild()
@export var blade_height_min := 1.5:
	set(v):
		blade_height_min = v
		_rebuild()
@export var blade_height_max := 3.2:
	set(v):
		blade_height_max = v
		_rebuild()
@export var seed := 5:
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
	var sheet := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.5, size.y)
	mesh.material = GardenTheme.material("grass")
	sheet.mesh = mesh
	sheet.position = Vector3(0, -0.25, 0)
	add_child(sheet)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in clump_count:
		var clump := GrassClump.new()
		clump.blade_count = rng.randi_range(5, 10)
		clump.radius = rng.randf_range(0.8, 2.0)
		clump.height_min = blade_height_min
		clump.height_max = blade_height_max
		clump.solid = false
		clump.seed = seed * 100 + i
		clump.position = Vector3(
			rng.randf_range(-size.x * 0.5, size.x * 0.5),
			0.0,
			rng.randf_range(-size.y * 0.5, size.y * 0.5))
		add_child(clump)
