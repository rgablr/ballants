@tool
class_name NurseryChamber
extends StaticBody3D
## NURSERY CHAMBER -- one big round room of the nest, built in code: a
## flat dirt floor, a smooth lower wall that rises straight up (so ramps
## and shelves can hug it), a rougher upper wall that leans in, and a dome.
## Built like the hub's cave shell (src/objects/hub/cave_shell.gd) but with
## a perfectly flat floor (eggs and bowls stand on it) and no holes.
##
## Local space: the floor is y = 0, centered on the origin. Collision is a
## triangle mesh of the floor and the walls up to `collide_height` (the
## dome is out of reach and has none), merged with the level's pieces.
##
## Keep the node above y = -2 in world space (the ball counts as fallen out
## below Tuning.fall_respawn_y).

## Radius of the floor, where the wall starts.
@export var radius := 46.0:
	set(v):
		radius = v
		_rebuild()
## Height of the smooth, straight lower wall.
@export var wall_height := 22.0:
	set(v):
		wall_height = v
		_rebuild()
## Height of the top of the dome above the floor.
@export var dome_height := 38.0:
	set(v):
		dome_height = v
		_rebuild()
## Slices around the room.
@export var segments := 96:
	set(v):
		segments = v
		_rebuild()
## Collision stops this high up the wall (nothing can reach above it).
@export var collide_height := 30.0:
	set(v):
		collide_height = v
		_rebuild()
@export var seed := 7:
	set(v):
		seed = v
		_rebuild()
## Leave on: the level's StaticMerger folds this collision into one body.
@export var merge_collision := true

const COLOR_FLOOR := Color(0.42, 0.26, 0.13)
const COLOR_FLOOR_PALE := Color(0.5, 0.32, 0.17)
const COLOR_WALL_LOW := Color(0.5, 0.29, 0.14)
const COLOR_WALL_HIGH := Color(0.36, 0.19, 0.09)
const COLOR_BAND := Color(0.64, 0.38, 0.19)
const COLOR_DOME := Color(0.26, 0.13, 0.07)

## The upper wall and dome as (fraction of radius, height above the
## straight wall as a fraction of the dome's rise).
const DOME_PROFILE := [
	Vector2(1.0, 0.0), Vector2(0.99, 0.18), Vector2(0.95, 0.36), Vector2(0.87, 0.54),
	Vector2(0.74, 0.71), Vector2(0.56, 0.85), Vector2(0.34, 0.95), Vector2(0.12, 1.0), Vector2(0.0, 1.0),
]

var _built := false
var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _faces := PackedVector3Array()
var _rng := RandomNumberGenerator.new()
var _collide := true


func _ready() -> void:
	_built = true
	_rebuild()


func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		child.queue_free()
	_rng.seed = seed
	_vertices = PackedVector3Array()
	_normals = PackedVector3Array()
	_colors = PackedColorArray()
	_faces = PackedVector3Array()
	var phase := [_rng.randf() * TAU, _rng.randf() * TAU]

	# ---- Floor: rings every ~3 m, flat (all one plane: no seams).
	var ring_count := maxi(int(ceil(radius / 3.0)), 2)
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		for r in ring_count:
			var ra := radius * r / ring_count
			var rb := radius * (r + 1) / ring_count
			var patch := 0.5 + 0.5 * sin(a0 * 5.0 + phase[0] + ra * 0.21) * sin(ra * 0.17 + phase[1])
			var color := COLOR_FLOOR.lerp(COLOR_FLOOR_PALE, patch).lightened(_rng.randf_range(-0.04, 0.04))
			if r == 0:
				_tri_facing(Vector3.ZERO, d0 * rb, d1 * rb, color, Vector3.UP)
			else:
				_quad_facing(d0 * ra, d0 * rb, d1 * rb, d1 * ra, color, Vector3.UP)

	# ---- Lower wall: straight up, smooth, in ~3 m rows with clay bands.
	var wall_rows := maxi(int(ceil(wall_height / 3.0)), 1)
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var tint := _rng.randf_range(-0.05, 0.05)
		for r in wall_rows:
			var ya := wall_height * r / wall_rows
			var yb := wall_height * (r + 1) / wall_rows
			var t := float(r) / wall_rows
			var color := COLOR_WALL_LOW.lerp(COLOR_WALL_HIGH, t)
			if r == 1 or r == 4:
				color = COLOR_BAND
			_collide = yb <= collide_height + 0.01
			_quad_facing(d0 * radius + Vector3.UP * ya, d1 * radius + Vector3.UP * ya,
					d1 * radius + Vector3.UP * yb, d0 * radius + Vector3.UP * yb,
					color.lightened(tint), -d0)

	# ---- Upper wall and dome: leaning in, lumpier the higher it goes.
	var rise := dome_height - wall_height
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		for k in DOME_PROFILE.size() - 1:
			var pa: Vector2 = DOME_PROFILE[k]
			var pb: Vector2 = DOME_PROFILE[k + 1]
			var wa := 1.0 + 0.04 * sin(a0 * 7.0 + phase[0] + k) * float(k > 0)
			var wa1 := 1.0 + 0.04 * sin(a1 * 7.0 + phase[0] + k) * float(k > 0)
			var wb := 1.0 + 0.04 * sin(a0 * 7.0 + phase[0] + k + 1)
			var wb1 := 1.0 + 0.04 * sin(a1 * 7.0 + phase[0] + k + 1)
			var p00 := Vector3(cos(a0), 0, sin(a0)) * radius * pa.x * wa + Vector3.UP * (wall_height + rise * pa.y)
			var p10 := Vector3(cos(a1), 0, sin(a1)) * radius * pa.x * wa1 + Vector3.UP * (wall_height + rise * pa.y)
			var p01 := Vector3(cos(a0), 0, sin(a0)) * radius * pb.x * wb + Vector3.UP * (wall_height + rise * pb.y)
			var p11 := Vector3(cos(a1), 0, sin(a1)) * radius * pb.x * wb1 + Vector3.UP * (wall_height + rise * pb.y)
			var color := COLOR_WALL_HIGH.lerp(COLOR_DOME, float(k) / (DOME_PROFILE.size() - 2))
			_collide = wall_height + rise * pb.y <= collide_height + 0.01
			_quad_facing(p00, p10, p11, p01, color.lightened(_rng.randf_range(-0.05, 0.05)),
					-Vector3(cos(a0), 0, sin(a0)) - Vector3.UP * pa.y)
	_collide = true

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


func _quad_facing(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, color: Color, facing: Vector3) -> void:
	_tri_facing(p0, p1, p2, color, facing)
	_tri_facing(p0, p2, p3, color, facing)


func _tri_facing(p0: Vector3, p1: Vector3, p2: Vector3, color: Color, facing: Vector3) -> void:
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
	if _collide:
		_faces.append(p0)
		_faces.append(p2)
		_faces.append(p1)
