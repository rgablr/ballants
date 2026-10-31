@tool
class_name Pebble
extends StaticBody3D
## PEBBLE -- a garden stone that is a boulder to an ant. Unmoving. The
## collision is a convex hull built from the same squashed sphere as the
## visible mesh, so what you see is what you hit.

@export var size := Vector3(2.0, 1.3, 1.6):
	set(v):
		size = v
		_rebuild()
@export var dark := false:
	set(v):
		dark = v
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
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 10
	sphere.rings = 6
	sphere.material = GardenTheme.material("pebble_dark" if dark else "pebble")

	var instance := MeshInstance3D.new()
	instance.mesh = sphere
	instance.scale = size
	instance.position = Vector3(0, size.y * 0.4, 0)   # sits a little into the ground
	add_child(instance)

	# Convex collision from the scaled points of the same sphere.
	var points := PackedVector3Array()
	for p in sphere.get_mesh_arrays()[Mesh.ARRAY_VERTEX]:
		points.append(p * size)
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	var shape := CollisionShape3D.new()
	shape.shape = hull
	shape.position = instance.position
	add_child(shape)
