@tool
class_name Hose
extends StaticBody3D
## HOSE -- a garden hose the ball can roll along, built from a list of
## points. Each pair of neighboring points becomes one capsule (visible
## mesh + matching collision), so a bendy hose is just more points. The
## radius can change along the hose (wide start, narrow end), and the
## points can rise and fall for humps.
##
## All capsules belong to this one body, so the joins are seamless to the
## ball. Points are in this node's local space.

## The hose's path. Add points to bend it; closer points = smoother bend.
@export var points := PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -10), Vector3(0, 0, -20)]):
	set(v):
		points = v
		_rebuild()
## Radius at the first point.
@export var radius_start := 1.2:
	set(v):
		radius_start = v
		_rebuild()
## Radius at the last point (same as start = constant width).
@export var radius_end := 1.2:
	set(v):
		radius_end = v
		_rebuild()
@export var striped := true:
	set(v):
		striped = v
		_rebuild()

var _built := false


func _ready() -> void:
	_built = true
	_rebuild()


## Length of the whole hose along its points.
func total_length() -> float:
	var length := 0.0
	for i in points.size() - 1:
		length += points[i].distance_to(points[i + 1])
	return length


func _rebuild() -> void:
	if not _built or points.size() < 2:
		return
	for child in get_children():
		child.queue_free()
	var total := total_length()
	var travelled := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var segment_length := a.distance_to(b)
		var t_mid := (travelled + segment_length * 0.5) / maxf(total, 0.001)
		var radius := lerpf(radius_start, radius_end, t_mid)
		travelled += segment_length

		var mesh := CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = segment_length + radius * 2.0
		mesh.radial_segments = 12
		mesh.rings = 3
		mesh.material = GardenTheme.material("hose_stripe" if striped and i % 4 == 3 else "hose")
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.transform = _capsule_transform(a, b)
		add_child(instance)

		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius
		capsule.height = segment_length + radius * 2.0
		shape.shape = capsule
		shape.transform = instance.transform
		add_child(shape)


## A transform whose Y axis runs from a to b, centered between them.
func _capsule_transform(a: Vector3, b: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var helper := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y, z), (a + b) * 0.5)
