@tool
class_name DirtTrack
extends StaticBody3D
## DIRT TRACK -- a ribbon of packed dirt that follows a smooth curve
## through a list of points, up and down hill, with optional walls on
## either side, a ceiling (for a tunnel), banking, and glowing fungus
## placed along it by itself so the path is readable in the dark. The
## nest levels are built mostly from these.
##
## Set `points` (the centerline, in this node's local space; y is the
## floor height there) and the track is built: a Catmull-Rom curve is
## drawn through the points, sampled every meter or so, and the floor is a
## strip of flat-shaded quads of `width`, `floor_thickness` deep (so the
## edge shows as a dark lip). Collision is a triangle mesh of exactly
## that surface (floor, sides, walls, ceiling), all one shape, and the
## level's StaticMerger folds it in with the other pieces so there are no
## seams to catch on. Walls are solid from both sides.
##
## Per-point settings (arrays the same length as `points`; leave an array
## EMPTY to use the single value for every point):
##   widths    floor width at each point (m)           default: width
##   walls     0 none, 1 left, 2 right, 3 both          default: wall_sides
##             ("left" is on your left when rolling from the first point
##             toward the last). A wall covers the stretch from its point
##             to the next point, so set the value on the point where a
##             wall should START or STOP.
##   banks     bank angle at each point (degrees, + raises the LEFT edge, so
##             a right-hand turn banks with a negative value)  default 0
##
## Useful calls for placing things on the track: length(), frame_at(d)
## (a Transform3D on the centerline d meters from the start: origin on the
## floor, -Z forward, +Y up off the floor), point_at(d).
##
## Keep every floor ABOVE y = -2 in world space: the ball counts as fallen
## out of the world below Tuning.fall_respawn_y (-2.5).

@export var points := PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -12), Vector3(4, -1, -24), Vector3(10, -2, -32)]):
	set(v):
		points = v
		_rebuild()
@export var width := 8.0:
	set(v):
		width = v
		_rebuild()
@export var widths := PackedFloat32Array():
	set(v):
		widths = v
		_rebuild()
## 0 none, 1 left, 2 right, 3 both (for every point unless `walls` is set).
@export_range(0, 3) var wall_sides := 3:
	set(v):
		wall_sides = v
		_rebuild()
@export var walls := PackedInt32Array():
	set(v):
		walls = v
		_rebuild()
@export var banks := PackedFloat32Array():
	set(v):
		banks = v
		_rebuild()
@export var wall_height := 3.0:
	set(v):
		wall_height = v
		_rebuild()
## How far the top of a wall leans outward (fraction of its height).
@export var wall_lean := 0.18:
	set(v):
		wall_lean = v
		_rebuild()
## Height of the ceiling above the floor; 0 = open above. With a ceiling
## the walls run up to it (a tunnel).
@export var ceiling_height := 0.0:
	set(v):
		ceiling_height = v
		_rebuild()
@export var floor_thickness := 1.0:
	set(v):
		floor_thickness = v
		_rebuild()
## Meters between glowing fungus clusters along the edges (alternating
## sides); 0 = none. They sit on the floor against the wall (or the edge).
@export var lights_every := 14.0:
	set(v):
		lights_every = v
		_rebuild()
## Samples per meter of curve; higher = rounder bends and smoother slopes.
@export var samples_per_meter := 0.8:
	set(v):
		samples_per_meter = v
		_rebuild()
## Random lumpiness of the wall tops and the color variation (0 = none).
@export var roughness := 1.0:
	set(v):
		roughness = v
		_rebuild()
@export var seed := 1:
	set(v):
		seed = v
		_rebuild()
## Leave on: the level's StaticMerger folds this collision into one body.
@export var merge_collision := true

const COLOR_FLOOR := Color(0.5, 0.3, 0.15)
const COLOR_FLOOR_EDGE := Color(0.6, 0.38, 0.19)
const COLOR_SIDE := Color(0.33, 0.18, 0.09)
const COLOR_WALL := Color(0.44, 0.27, 0.14)
const COLOR_WALL_TOP := Color(0.58, 0.36, 0.18)
const COLOR_CLAY := Color(0.66, 0.4, 0.2)
const COLOR_CEILING := Color(0.26, 0.14, 0.07)

var _built := false
var _samples: Array = []        # [{"pos", "forward", "right", "up", "width", "walls", "dist"}]
var _total_length := 0.0

# Mesh building scratch.
var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _faces := PackedVector3Array()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_built = true
	_rebuild()


# --------------------------------------------------------------- curve ----

## Total length of the centerline (m).
func length() -> float:
	if _samples.is_empty():
		_sample()
	return _total_length


## A frame on the centerline `distance` meters from the start: origin on
## the floor, -Z along the track, +Y up off the floor (with banking), +X
## to the right. In this node's local space; use to_global() for world.
func frame_at(distance: float) -> Transform3D:
	if _samples.is_empty():
		_sample()
	if _samples.is_empty():
		return Transform3D.IDENTITY
	distance = clampf(distance, 0.0, _total_length)
	var i := 0
	while i < _samples.size() - 2 and _samples[i + 1].dist < distance:
		i += 1
	var a: Dictionary = _samples[i]
	var b: Dictionary = _samples[mini(i + 1, _samples.size() - 1)]
	var span: float = maxf(b.dist - a.dist, 0.0001)
	var u: float = clampf((distance - a.dist) / span, 0.0, 1.0)
	var pos: Vector3 = (a.pos as Vector3).lerp(b.pos, u)
	var forward: Vector3 = (a.forward as Vector3).slerp(b.forward, u).normalized()
	var up: Vector3 = (a.up as Vector3).slerp(b.up, u).normalized()
	var right := forward.cross(up).normalized()
	up = right.cross(forward).normalized()
	return Transform3D(Basis(right, up, -forward), pos)


func point_at(distance: float) -> Vector3:
	return frame_at(distance).origin


## Floor width at a distance along the track.
func width_at(distance: float) -> float:
	if _samples.is_empty():
		_sample()
	var i := 0
	while i < _samples.size() - 2 and _samples[i + 1].dist < distance:
		i += 1
	return float(_samples[i].width)


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _per_point(array, index: int, fallback: float) -> float:
	if array.size() == points.size():
		return float(array[index])
	return fallback


## Walks the curve and records a frame at every sample.
func _sample() -> void:
	_samples = []
	_total_length = 0.0
	var n := points.size()
	if n < 2:
		return
	var last := Vector3.INF
	for i in n - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, n - 1)]
		var segment_length := p1.distance_to(p2)
		var count := maxi(int(ceil(segment_length * samples_per_meter)), 2)
		var w1 := _per_point(widths, i, width)
		var w2 := _per_point(widths, i + 1, width)
		var b1 := _per_point(banks, i, 0.0)
		var b2 := _per_point(banks, i + 1, 0.0)
		var wall_code := int(walls[i]) if walls.size() == n else wall_sides
		var last_sample := (i == n - 2)
		for s in (count + 1 if last_sample else count):
			var t := float(s) / count
			var pos := _catmull(p0, p1, p2, p3, t)
			var ahead := _catmull(p0, p1, p2, p3, minf(t + 0.02, 1.0))
			var behind := _catmull(p0, p1, p2, p3, maxf(t - 0.02, 0.0))
			var forward := (ahead - behind)
			if forward.length_squared() < 0.000001:
				forward = p2 - p1
			forward = forward.normalized()
			var right := forward.cross(Vector3.UP)
			if right.length_squared() < 0.0001:
				right = Vector3.RIGHT
			right = right.normalized()
			var up := right.cross(forward).normalized()
			var bank := deg_to_rad(lerpf(b1, b2, t))
			if absf(bank) > 0.0001:
				var rot := Basis(forward, bank)
				right = rot * right
				up = rot * up
			if last != Vector3.INF:
				_total_length += last.distance_to(pos)
			last = pos
			_samples.append({"pos": pos, "forward": forward, "right": right, "up": up,
					"width": lerpf(w1, w2, t), "walls": wall_code, "dist": _total_length,
					"point": i, "t": t})


# ---------------------------------------------------------------- mesh ----

func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		child.queue_free()
	_sample()
	if _samples.size() < 2:
		return
	_rng.seed = seed
	_vertices = PackedVector3Array()
	_normals = PackedVector3Array()
	_colors = PackedColorArray()
	_faces = PackedVector3Array()

	var count := _samples.size()
	# Precompute the wall-top lumpiness per sample so neighbours share it.
	var lumps := PackedFloat32Array()
	for i in count:
		lumps.append(_rng.randf_range(-0.22, 0.22) * roughness)
	var tint := PackedFloat32Array()
	for i in count:
		tint.append(_rng.randf_range(-0.06, 0.06) * roughness)

	for i in count - 1:
		var a: Dictionary = _samples[i]
		var b: Dictionary = _samples[i + 1]
		var ha: float = a.width * 0.5
		var hb: float = b.width * 0.5
		var ar: Vector3 = a.right
		var br: Vector3 = b.right
		var au: Vector3 = a.up
		var bu: Vector3 = b.up
		var ap: Vector3 = a.pos
		var bp: Vector3 = b.pos
		# Floor corners: left (L) / right (R), near (a) / far (b), top / bottom.
		var aL := ap - ar * ha
		var aR := ap + ar * ha
		var bL := bp - br * hb
		var bR := bp + br * hb
		var aLd := aL - au * floor_thickness
		var aRd := aR - au * floor_thickness
		var bLd := bL - bu * floor_thickness
		var bRd := bR - bu * floor_thickness
		var floor_color := COLOR_FLOOR.lightened(tint[i])
		# Top: split into three strips across so the edges can be a touch
		# lighter (a worn lip) and the middle flat-shaded.
		var edge := 0.9
		var aLi := aL + ar * minf(edge, ha)
		var aRi := aR - ar * minf(edge, ha)
		var bLi := bL + br * minf(edge, hb)
		var bRi := bR - br * minf(edge, hb)
		_quad(aL, aLi, bLi, bL, COLOR_FLOOR_EDGE.lightened(tint[i]))
		_quad(aLi, aRi, bRi, bLi, floor_color)   # middle
		_quad(aRi, aR, bR, bRi, COLOR_FLOOR_EDGE.lightened(tint[i]))
		# Sides and bottom.
		var side_color := COLOR_SIDE.lightened(tint[i])
		_quad(aLd, aL, bL, bLd, side_color)
		_quad(aR, aRd, bRd, bR, side_color)
		_quad(aRd, aLd, bLd, bRd, COLOR_SIDE)
		# Walls.
		var code: int = a.walls
		var top_height := ceiling_height if ceiling_height > 0.0 else wall_height
		if code & 1:
			_wall(aL, bL, au, bu, -ar, -br, top_height, lumps[i], lumps[i + 1], tint[i])
		if code & 2:
			_wall(aR, bR, au, bu, ar, br, top_height, lumps[i], lumps[i + 1], tint[i])
		# Ceiling: a shallow arch (three quads across) at ceiling_height.
		if ceiling_height > 0.0:
			var lean_a := ar * ceiling_height * wall_lean
			var lean_b := br * ceiling_height * wall_lean
			var cL_a := aL - lean_a + au * ceiling_height
			var cR_a := aR + lean_a + au * ceiling_height
			var cL_b := bL - lean_b + bu * ceiling_height
			var cR_b := bR + lean_b + bu * ceiling_height
			var peak_a := ap + au * (ceiling_height + ha * 0.35)
			var peak_b := bp + bu * (ceiling_height + hb * 0.35)
			var cc := COLOR_CEILING.lightened(tint[i])
			# The faces point DOWN into the tunnel.
			_quad_facing(cL_a, cL_b, peak_b, peak_a, cc, -au)
			_quad_facing(peak_a, peak_b, cR_b, cR_a, cc, -au)

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

	_place_lights()


## A wall from edge a to edge b: inner face, a lumpy top, outer face.
## `out_a` / `out_b` point away from the track.
func _wall(a: Vector3, b: Vector3, up_a: Vector3, up_b: Vector3, out_a: Vector3, out_b: Vector3,
		h: float, lump_a: float, lump_b: float, tint: float) -> void:
	var thick := 0.6
	var ta := a + up_a * (h + lump_a) + out_a * h * wall_lean
	var tb := b + up_b * (h + lump_b) + out_b * h * wall_lean
	var oa := a + out_a * thick
	var ob := b + out_b * thick
	var ota := ta + out_a * thick
	var otb := tb + out_b * thick
	var band := _rng.randf() < 0.18 * roughness
	var wall_color := (COLOR_CLAY if band else COLOR_WALL).lightened(tint)
	# Inner face (faces the track), top, outer face.
	_quad_facing(a, ta, tb, b, wall_color, -out_a)
	_quad_facing(ta, ota, otb, tb, COLOR_WALL_TOP.lightened(tint), up_a)
	_quad_facing(oa, ob, otb, ota, COLOR_WALL.darkened(0.15), out_a)


## Two triangles with one flat normal and one color; wound so the normal
## faces the viewer when the corners go anticlockwise as seen from outside.
func _quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, color: Color) -> void:
	_tri(p0, p1, p2, color)
	_tri(p0, p2, p3, color)


## A quad whose visible side faces roughly along `facing` (the corner
## order is flipped if needed).
func _quad_facing(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, color: Color, facing: Vector3) -> void:
	var normal := (p1 - p0).cross(p2 - p0)
	if normal.dot(facing) >= 0.0:
		_quad(p0, p1, p2, p3, color)
	else:
		_quad(p3, p2, p1, p0, color)


func _tri(p0: Vector3, p1: Vector3, p2: Vector3, color: Color) -> void:
	var normal := (p1 - p0).cross(p2 - p0)
	if normal.length_squared() < 0.0000001:
		return
	normal = normal.normalized()
	# Godot front faces are clockwise as seen by the viewer: emit p0, p2, p1.
	for p in [p0, p2, p1]:
		_vertices.append(p)
		_normals.append(normal)
		_colors.append(color)
	_faces.append(p0)
	_faces.append(p2)
	_faces.append(p1)


# -------------------------------------------------------------- lights ----

## Glowing fungus every `lights_every` meters, alternating sides, sitting
## on the floor against the wall (or near the edge when there is none).
func _place_lights() -> void:
	if lights_every <= 0.0 or _total_length < 1.0:
		return
	var root := Node3D.new()
	root.name = "Lights"
	add_child(root)
	var d := lights_every * 0.5
	var side := 1.0
	var k := 0
	while d < _total_length:
		var frame := frame_at(d)
		var half := width_at(d) * 0.5
		var fungus := GlowFungus.new()
		fungus.seed = seed * 31 + k
		fungus.size = 0.8
		fungus.amber = true
		fungus.position = frame.origin + frame.basis.x * side * (half - 0.7)
		fungus.basis = frame.basis
		root.add_child(fungus)
		side = -side
		d += lights_every
		k += 1
