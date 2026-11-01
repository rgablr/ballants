@tool
class_name EggMound
extends StaticBody3D
## EGG MOUND -- the heart of a nursery: a broad column of packed dirt with
## a flat top, its sides and rim heaped with pale eggs. A goal or a
## lookout to stand things on. Built in code, flat-shaded; collision is a
## triangle mesh of the top and sides (merged with the level's pieces).
## The eggs are looks only (to make them bump the ball, put EggPiles
## around the base).
##
## Local space: the base is y = 0, the flat top is at `height`.

@export var top_radius := 7.5:
	set(v):
		top_radius = v
		_rebuild()
@export var base_radius := 9.5:
	set(v):
		base_radius = v
		_rebuild()
@export var height := 10.0:
	set(v):
		height = v
		_rebuild()
@export var segments := 36:
	set(v):
		segments = v
		_rebuild()
## Where a path comes onto the top (degrees from local +X toward +Z): no
## rim eggs within 25 degrees of it. Below -360 = no gap.
@export var entry_angle := -999.0:
	set(v):
		entry_angle = v
		_rebuild()
@export var seed := 9:
	set(v):
		seed = v
		_rebuild()
## Leave on: the level's StaticMerger folds this collision into one body.
@export var merge_collision := true

const COLOR_TOP := Color(0.55, 0.35, 0.18)
const COLOR_SIDE := Color(0.42, 0.25, 0.12)
const COLOR_BAND := Color(0.64, 0.39, 0.2)

var _built := false
var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _faces := PackedVector3Array()


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
	_vertices = PackedVector3Array()
	_normals = PackedVector3Array()
	_colors = PackedColorArray()
	_faces = PackedVector3Array()
	var rows := 5
	var lumps := PackedFloat32Array()
	for i in segments * (rows + 1):
		lumps.append(rng.randf_range(-0.35, 0.35))
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		# Flat top (a fan, one plane).
		_tri(Vector3.UP * height, d0 * top_radius + Vector3.UP * height, d1 * top_radius + Vector3.UP * height,
				COLOR_TOP.lightened(rng.randf_range(-0.04, 0.04)), Vector3.UP)
		# Sides: from the top rim down to the base, lumpier lower down.
		for r in rows:
			var ta := float(r) / rows
			var tb := float(r + 1) / rows
			var ra0 := lerpf(top_radius, base_radius, ta) + (lumps[s * (rows + 1) + r] if r > 0 else 0.0)
			var ra1 := lerpf(top_radius, base_radius, ta) + (lumps[((s + 1) % segments) * (rows + 1) + r] if r > 0 else 0.0)
			var rb0 := lerpf(top_radius, base_radius, tb) + lumps[s * (rows + 1) + r + 1]
			var rb1 := lerpf(top_radius, base_radius, tb) + lumps[((s + 1) % segments) * (rows + 1) + r + 1]
			var ya := height * (1.0 - ta)
			var yb := height * (1.0 - tb) - (0.3 if r == rows - 1 else 0.0)
			var color := COLOR_BAND if r == 2 else COLOR_SIDE.lightened(rng.randf_range(-0.05, 0.05))
			var p00 := d0 * ra0 + Vector3.UP * ya
			var p10 := d1 * ra1 + Vector3.UP * ya
			var p01 := d0 * rb0 + Vector3.UP * yb
			var p11 := d1 * rb1 + Vector3.UP * yb
			_tri(p00, p10, p11, color, d0 + d1)
			_tri(p00, p11, p01, color, d0 + d1)

	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	add_child(instance)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_faces)
	shape.backface_collision = true
	var collider := CollisionShape3D.new()
	collider.name = "Collision"
	collider.shape = shape
	add_child(collider)

	# Eggs heaped against the sides and in a ring just inside the top rim
	# (inside the rim they stay clear of the middle, where the goal sits).
	var transforms: Array[Transform3D] = []
	for i in int(segments * 2.2):
		var a := TAU * (i + rng.randf()) / (segments * 2.2)
		var t := rng.randf_range(0.0, 1.0)
		var r := lerpf(top_radius, base_radius, t) + 0.15
		var y := height * (1.0 - t)
		transforms.append(_egg(rng, Vector3(cos(a) * r, y, sin(a) * r), 1.0))
	for i in int(segments * 1.2):
		var a := TAU * (i + rng.randf() * 0.6) / (segments * 1.2)
		var r := top_radius - rng.randf_range(0.2, 0.6)
		if entry_angle > -360.0 and absf(angle_difference(a, deg_to_rad(entry_angle))) < deg_to_rad(25.0):
			continue
		transforms.append(_egg(rng, Vector3(cos(a) * r, height + 0.35, sin(a) * r), 0.8))
	var multimesh := EggPile.make_multimesh(transforms, rng)
	var eggs := MultiMeshInstance3D.new()
	eggs.name = "Eggs"
	eggs.multimesh = multimesh
	add_child(eggs)


func _egg(rng: RandomNumberGenerator, pos: Vector3, size: float) -> Transform3D:
	var s := rng.randf_range(0.8, 1.15) * size
	var basis := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
	return Transform3D(basis * Basis.from_scale(Vector3(0.7, 1.1, 0.7) * s), pos)


func _tri(p0: Vector3, p1: Vector3, p2: Vector3, color: Color, facing: Vector3) -> void:
	var normal := (p1 - p0).cross(p2 - p0)
	if normal.length_squared() < 0.0000001:
		return
	if normal.dot(facing) < 0.0:
		var swap := p1
		p1 = p2
		p2 = swap
		normal = -normal
	normal = normal.normalized()
	for p in [p0, p2, p1]:
		_vertices.append(p)
		_normals.append(normal)
		_colors.append(color)
	_faces.append(p0)
	_faces.append(p2)
	_faces.append(p1)
