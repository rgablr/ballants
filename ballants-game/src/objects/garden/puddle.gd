@tool
class_name Puddle
extends Node3D
## PUDDLE -- a sheet of water with a FallZone just under its surface.
## Touch the water and the run restarts. Place it at the water's surface
## height; it is purely a box of the given size.

@export var size := Vector2(30.0, 30.0):
	set(v):
		size = v
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
	var water := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.1, size.y)
	mesh.material = GardenTheme.material("water")
	water.mesh = mesh
	water.position = Vector3(0, -0.05, 0)
	add_child(water)

	var zone := FallZone.new()
	zone.size = Vector3(size.x, 2.0, size.y)
	zone.position = Vector3(0, -1.2, 0)
	add_child(zone)
