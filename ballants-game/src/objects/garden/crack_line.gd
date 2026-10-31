@tool
class_name CrackLine
extends Node3D
## CRACK LINE -- a thin dark line painted on top of a sidewalk: a crack to
## follow, a seam between slabs, or a curb line along an open edge.
##
## Purely visual (no collision), so it never bumps the ball. Give it a
## list of local points and it draws a strip through them; "jag" adds a
## seeded sideways wobble so a crack looks cracked instead of ruled.
## Place the node at the height of the surface it sits on.

@export var points := PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -12)]):
	set(v):
		points = v
		_rebuild()
@export var width := 0.25:
	set(v):
		width = v
		_rebuild()
## Sideways wobble in meters. 0 = ruler-straight (seams, curb lines).
@export var jag := 0.3:
	set(v):
		jag = v
		_rebuild()
## When jagged, the line is broken into pieces about this long.
@export var step := 2.0:
	set(v):
		step = max(v, 0.2)
		_rebuild()
@export var color := Color(0.42, 0.4, 0.36):
	set(v):
		color = v
		_rebuild()
@export var seed := 1:
	set(v):
		seed = v
		_rebuild()
## How far above the node the strip floats, so it does not fight the slab.
@export var lift := 0.03:
	set(v):
		lift = v
		_rebuild()

const THICKNESS := 0.04

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
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	var vertices := _jagged_vertices()
	for i in vertices.size() - 1:
		var a: Vector3 = vertices[i]
		var b: Vector3 = vertices[i + 1]
		var length := a.distance_to(b)
		if length < 0.001:
			continue
		var piece := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		# A little longer than the gap so bends do not show a chink.
		mesh.size = Vector3(width, THICKNESS, length + width)
		mesh.material = material
		piece.mesh = mesh
		var center := (a + b) * 0.5 + Vector3.UP * (lift + THICKNESS * 0.5)
		var direction := (b - a).normalized()
		var up := Vector3.UP
		if absf(direction.dot(up)) > 0.99:
			up = Vector3.FORWARD
		piece.transform = Transform3D(Basis.looking_at(direction, up), center)
		add_child(piece)


## Subdivides the polyline and pushes the inner vertices sideways.
func _jagged_vertices() -> PackedVector3Array:
	var out := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	out.append(points[0])
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var segment := b - a
		var length := segment.length()
		if length < 0.001:
			continue
		var pieces := 1 if jag <= 0.0 else maxi(int(round(length / step)), 1)
		var side := segment.cross(Vector3.UP).normalized()
		if side.length_squared() < 0.5:
			side = Vector3.RIGHT
		for k in range(1, pieces):
			var t := float(k) / pieces
			out.append(a + segment * t + side * rng.randf_range(-jag, jag))
		out.append(b)
	return out
