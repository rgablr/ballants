@tool
class_name Root
extends Node3D
## ROOT -- a tree root poking through the dirt: a chain of capsules that
## bends along a few points, tapering toward the tip, with smaller rootlets
## branching off. Solid by default (one capsule collider per segment) so it
## can block a path or hide a ledge; turn `solid` off for pure decoration.
##
## `points` are in this node's local space; the root is thickest at the
## first point. The default is a root arching out of the ground and back
## in. Rotate the node to grow it out of a wall or ceiling.

@export var points := PackedVector3Array([Vector3(0, 0, 0), Vector3(1.5, 1.4, -0.6), Vector3(3.5, 1.6, -1.0), Vector3(5.5, 0.4, -1.4)]):
	set(v):
		points = v
		_rebuild()
## Radius at the first point (m). The tip is a third of this.
@export var radius := 0.45:
	set(v):
		radius = v
		_rebuild()
@export var solid := true:
	set(v):
		solid = v
		_rebuild()
@export var rootlets := 3:
	set(v):
		rootlets = v
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
	if points.size() < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var body: StaticBody3D = null
	if solid:
		body = StaticBody3D.new()
		body.name = "Collision"
		add_child(body)
	var material := AnthillTheme.material("root")
	var dark := AnthillTheme.material("root_dark")
	# Smooth the path a little (Catmull-Rom) so the root bends instead of kinking.
	var smooth := _smooth(points, 3)
	var n := smooth.size()
	for i in n - 1:
		var t0 := float(i) / (n - 1)
		var t1 := float(i + 1) / (n - 1)
		var r0 := lerpf(radius, radius * 0.33, t0)
		var r1 := lerpf(radius, radius * 0.33, t1)
		_segment(smooth[i], smooth[i + 1], (r0 + r1) * 0.5, material, body)
	# Rootlets: thin side roots off random segments.
	for k in rootlets:
		var i := rng.randi_range(0, n - 2)
		var base := smooth[i].lerp(smooth[i + 1], rng.randf())
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.6, 0.3), rng.randf_range(-1.0, 1.0)).normalized()
		var length := rng.randf_range(0.6, 1.6) * radius / 0.45
		var mid := base + dir * length * 0.5 + Vector3(0.0, rng.randf_range(-0.2, 0.2), 0.0)
		var tip := base + dir * length + Vector3(0.0, -0.3 * length, 0.0)
		_segment(base, mid, radius * 0.22, dark, null)
		_segment(mid, tip, radius * 0.12, dark, null)


func _segment(a: Vector3, b: Vector3, r: float, material: Material, body: StaticBody3D) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = r
	mesh.radial_segments = 7
	mesh.rings = 2
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)
	CritterParts.set_rod(instance, a, b)
	if body:
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = r
		capsule.height = a.distance_to(b) + r * 2.0
		shape.shape = capsule
		shape.transform = instance.transform
		body.add_child(shape)


static func _smooth(source: PackedVector3Array, subdivisions: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := source.size()
	for i in n - 1:
		var p0 := source[maxi(i - 1, 0)]
		var p1 := source[i]
		var p2 := source[i + 1]
		var p3 := source[mini(i + 2, n - 1)]
		for s in subdivisions:
			var t := float(s) / subdivisions
			out.append(_catmull(p0, p1, p2, p3, t))
	out.append(source[n - 1])
	return out


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
