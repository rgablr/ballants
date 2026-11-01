@tool
class_name EggBowl
extends StaticBody3D
## EGG BOWL -- a U-shaped skate bowl of packed dirt: a semicircular end
## and two straight legs, with a smooth curved wall (a quarter-pipe) all
## the way round that rises from the floor and steepens to near vertical.
## Roll into it fast and the ball rides up the wall and comes back down,
## which turns it much tighter than the flat floor could. The open end of
## the U (the mouth) is where you come in and go out.
##
## The bowl has NO floor of its own: it stands on the floor below it (the
## chamber floor), and the wall starts exactly at that height with a flat
## tangent, so rolling onto the wall is seamless.
##
## Local space: the semicircle's center is the origin, its floor is y = 0,
## the round end is toward -Z and the legs run toward +Z for `leg_length`
## (the mouth is at z = +leg_length). The wall's foot is `floor_radius`
## from the center line (so the flat floor is 2 x floor_radius wide).
##
## The wall profile, from the foot outward: a circular arc of
## `pipe_radius` from flat to `pipe_angle` degrees, then a straight section
## at that angle up to `height`, then a flat rim `rim_width` wide, then the
## outer face straight down. Collision is a triangle mesh of exactly the
## mesh (solid from both sides), merged with the level's other pieces.
##
## surface_point(around, height_on_wall) gives a point on the inner wall
## (for crystals, fungus, waypoints): around is meters along the foot line
## from the WEST mouth (0) round to the east mouth (length_of_foot()).

@export var floor_radius := 7.0:
	set(v):
		floor_radius = v
		_rebuild()
@export var leg_length := 10.0:
	set(v):
		leg_length = v
		_rebuild()
@export var pipe_radius := 6.0:
	set(v):
		pipe_radius = v
		_rebuild()
## Steepest angle of the curved part (degrees from flat).
@export var pipe_angle := 80.0:
	set(v):
		pipe_angle = v
		_rebuild()
## Height of the rim above the bowl floor.
@export var height := 8.0:
	set(v):
		height = v
		_rebuild()
@export var rim_width := 1.2:
	set(v):
		rim_width = v
		_rebuild()
## Degrees per slice round the semicircle (smaller = rounder).
@export var step_degrees := 3.0:
	set(v):
		step_degrees = v
		_rebuild()
@export var seed := 5:
	set(v):
		seed = v
		_rebuild()
## Leave on: the level's StaticMerger folds this collision into one body.
@export var merge_collision := true

## How far below the floor the wall's foot starts (m).
const FOOT_SINK := 0.03

const COLOR_LOW := Color(0.52, 0.32, 0.16)
const COLOR_MID := Color(0.46, 0.28, 0.14)
const COLOR_HIGH := Color(0.4, 0.23, 0.11)
const COLOR_BAND := Color(0.68, 0.41, 0.21)
const COLOR_RIM := Color(0.6, 0.38, 0.19)
const COLOR_OUTER := Color(0.33, 0.18, 0.09)

var _built := false
var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _faces := PackedVector3Array()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_built = true
	_rebuild()


## The wall profile as (outward offset, height) rows from the foot.
func profile() -> PackedVector2Array:
	var rows := PackedVector2Array()
	# The foot starts a hair BELOW the floor (and a little behind the foot
	# line), so the wall meets the floor face-to-face partway up its first
	# facets instead of at an edge the ball could catch on.
	rows.append(Vector2(-0.6, -FOOT_SINK - 0.01))
	var steps := maxi(int(ceil(pipe_angle / 2.5)), 2)
	for k in steps + 1:
		var a := deg_to_rad(pipe_angle * k / steps)
		var sink := FOOT_SINK * clampf(1.0 - float(k) / 4.0, 0.0, 1.0)
		rows.append(Vector2(pipe_radius * sin(a), pipe_radius * (1.0 - cos(a)) - sink))
	var top := rows[rows.size() - 1]
	if top.y < height:
		var a := deg_to_rad(pipe_angle)
		var extra := (height - top.y) / sin(a)
		rows.append(top + Vector2(cos(a), sin(a)) * extra * 0.5)
		rows.append(top + Vector2(cos(a), sin(a)) * extra)
	return rows


## Length of the wall's foot line from the west mouth to the east mouth.
func length_of_foot() -> float:
	return leg_length * 2.0 + PI * floor_radius


## Foot point and outward normal at a distance along the foot line.
func foot_at(along: float) -> Array:
	along = clampf(along, 0.0, length_of_foot())
	if along <= leg_length:
		return [Vector3(-floor_radius, 0.0, leg_length - along), Vector3.LEFT]
	along -= leg_length
	var arc := PI * floor_radius
	if along <= arc:
		var alpha := along / floor_radius
		var n := Vector3(-cos(alpha), 0.0, -sin(alpha))
		return [n * floor_radius, n]
	along -= arc
	return [Vector3(floor_radius, 0.0, along), Vector3.RIGHT]


## A point on the inner wall surface `height_on_wall` meters above the
## bowl floor, `along` meters round the foot line (local space).
func surface_point(along: float, height_on_wall: float) -> Vector3:
	var foot: Array = foot_at(along)
	var rows := profile()
	var off := 0.0
	for k in range(1, rows.size()):
		if height_on_wall <= rows[k].y or k == rows.size() - 1:
			var a := rows[k - 1]
			var b := rows[k]
			var u := clampf((height_on_wall - a.y) / maxf(b.y - a.y, 0.0001), 0.0, 1.0)
			off = lerpf(a.x, b.x, u)
			break
	return (foot[0] as Vector3) + (foot[1] as Vector3) * off + Vector3.UP * height_on_wall


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

	# Foot samples: each leg in ~1 m steps, the semicircle in step_degrees.
	var alongs := PackedFloat32Array()
	var leg_steps := maxi(int(ceil(leg_length)), 1)
	for i in leg_steps:
		alongs.append(leg_length * i / leg_steps)
	var arc_steps := maxi(int(ceil(180.0 / step_degrees)), 2)
	for i in arc_steps:
		alongs.append(leg_length + PI * floor_radius * i / arc_steps)
	for i in leg_steps + 1:
		alongs.append(leg_length + PI * floor_radius + leg_length * i / leg_steps)

	var rows := profile()
	var top := rows[rows.size() - 1]
	var outer := top.x + rim_width
	var tints := PackedFloat32Array()
	for i in alongs.size():
		tints.append(_rng.randf_range(-0.05, 0.05))
	var band_row := int(rows.size() * 0.55)

	for i in alongs.size() - 1:
		var fa: Array = foot_at(alongs[i])
		var fb: Array = foot_at(alongs[i + 1])
		var pa: Vector3 = fa[0]
		var pb: Vector3 = fb[0]
		var na: Vector3 = fa[1]
		var nb: Vector3 = fb[1]
		var tint := tints[i]
		# Inner surface.
		for k in rows.size() - 1:
			var r0 := rows[k]
			var r1 := rows[k + 1]
			var t := float(k) / (rows.size() - 1)
			var color := COLOR_LOW.lerp(COLOR_MID, minf(t * 2.0, 1.0)).lerp(COLOR_HIGH, maxf(t * 2.0 - 1.0, 0.0))
			if k == band_row:
				color = COLOR_BAND
			_quad_facing(pa + na * r0.x + Vector3.UP * r0.y, pb + nb * r0.x + Vector3.UP * r0.y,
					pb + nb * r1.x + Vector3.UP * r1.y, pa + na * r1.x + Vector3.UP * r1.y,
					color.lightened(tint), Vector3.UP * 0.5 - na)
		# Rim (a slightly lumpy flat top) and the outer face.
		var ta := pa + na * top.x + Vector3.UP * top.y
		var tb := pb + nb * top.x + Vector3.UP * top.y
		var oa := pa + na * outer + Vector3.UP * top.y
		var ob := pb + nb * outer + Vector3.UP * top.y
		_quad_facing(ta, tb, ob, oa, COLOR_RIM.lightened(tint), Vector3.UP)
		_quad_facing(oa, ob, ob - Vector3.UP * (top.y + 0.3), oa - Vector3.UP * (top.y + 0.3),
				COLOR_OUTER.lightened(tint), na)

	# End caps at both mouths: the wall's cross-section, a fan from the
	# outer bottom corner (the region under a convex curve is star-shaped
	# from there).
	for end in [0.0, length_of_foot()]:
		var f: Array = foot_at(end)
		var p: Vector3 = f[0]
		var n: Vector3 = f[1]
		var corner := p + n * outer - Vector3.UP * 0.3
		var ring: Array[Vector3] = [p - Vector3.UP * 0.3]
		for r in rows:
			ring.append(p + n * r.x + Vector3.UP * r.y)
		ring.append(p + n * outer + Vector3.UP * top.y)
		for k in ring.size() - 1:
			_tri_facing(corner, ring[k], ring[k + 1], COLOR_OUTER, Vector3.BACK)

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
	# Godot front faces are clockwise as seen by the viewer: emit p0, p2, p1.
	for p in [p0, p2, p1]:
		_vertices.append(p)
		_normals.append(normal)
		_colors.append(color)
	_faces.append(p0)
	_faces.append(p2)
	_faces.append(p1)
