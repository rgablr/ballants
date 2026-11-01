class_name CaveShell
extends StaticBody3D
## CAVE SHELL -- the inside of the giant ant hill, built in code: a flat
## (slightly bumpy) floor, walls that lean outward, a dome ceiling, and a
## round hole at the very top the hero falls in through.
##
## One mesh, one collision shape (a triangle mesh of the same surface, with
## both sides solid), so the ball can never leave the cave. Low-poly on
## purpose: every triangle is flat-shaded and the walls get a little random
## jaggedness the higher they go.
##
## OPENINGS: the hub tells the shell where the big tunnel mouths and the
## jail are (`cuts`) before it builds, and those cells of the lower wall
## are left out. The tunnel pieces fill the gaps with their own dirt
## collars, overlapping the edges so no seam shows.
##
## SMALL HOLES: dozens of ant-sized holes on the walls and ceiling. Each is
## a dirt lip (a torus) with a pure black, unlit disc set just inside it,
## so lighting never shows an inside, plus a collision plug so the ball
## can't get in (the wall behind it is solid too). NPC ants come and go
## through them.
##
## The wall surface is PARAMETRIZED: surface_transform(angle, t) gives a
## point on the wall (t = 0 at the floor rim, 1 at the top hole) with its
## inward normal, so ants, holes and glowing fungus can sit on it.
##
## Angles: 0 degrees = +Z, 90 = +X (direction(angle) below).

## Radius of the flat floor, where the walls start.
@export var floor_radius := 26.0
## Height of the top of the dome.
@export var height := 20.7
## Radius of the hole in the top the hero drops in through.
@export var top_hole_radius := 2.6
## Slices around. Tunnel angles must land on slice boundaries (6 degrees).
@export var segments := 60
@export var seed := 3
## How many small holes to scatter over the walls and ceiling.
@export var hole_count := 46

## Openings in the lower wall: [{"angle": degrees, "cells": n, "rows": n}].
## Set by the hub before _ready (it adds the shell's children in order), or
## call rebuild() after changing it.
var cuts: Array = []
## Angles (degrees) small holes must stay away from in the lower wall, so
## they don't crowd the letters over a tunnel.
var keep_clear_angles: Array = []
## The small holes, each {"angle", "t", "transform"} (transform: origin on
## the wall, Y = inward normal, -Z = "up the wall").
var holes: Array = []

## The wall profile from the floor rim to the top hole, as fractions of
## floor_radius (x) and height (y). Rows 0..3 are the smooth lower wall the
## tunnels are cut from (up to about 4.8 m); rows up to 4 stay smooth so
## the tunnel collars (7 m tall) meet a predictable wall.
const WALL_PROFILE := [
	Vector2(1.0, 0.0), Vector2(1.038, 0.077), Vector2(1.069, 0.155), Vector2(1.092, 0.232),
	Vector2(1.123, 0.338), Vector2(1.146, 0.459), Vector2(1.138, 0.58), Vector2(1.092, 0.7),
	Vector2(1.008, 0.797), Vector2(0.865, 0.879), Vector2(0.654, 0.937), Vector2(0.423, 0.976),
	Vector2(0.231, 0.995), Vector2(0.1, 1.0),
]
## Floor rings, as fractions of floor_radius.
const FLOOR_RINGS := [0.0, 0.115, 0.23, 0.365, 0.5, 0.635, 0.77, 0.885]
## The lowest wall rows have no jaggedness (tunnels and the jail are cut
## from them and their collars must meet a predictable surface).
const SMOOTH_WALL_ROWS := 5

const COLOR_FLOOR := Color(0.38, 0.23, 0.12)
const COLOR_WALL_LOW := Color(0.58, 0.31, 0.14)
const COLOR_WALL_HIGH := Color(0.42, 0.2, 0.1)
const COLOR_DOME := Color(0.3, 0.14, 0.08)
const COLOR_LIP := Color(0.3, 0.17, 0.09)

var _rng := RandomNumberGenerator.new()
var _phase := [0.0, 0.0, 0.0]
var _wall_lengths: PackedFloat32Array   # cumulative arc length along WALL_PROFILE

static var _black: StandardMaterial3D
static var _shell_material: StandardMaterial3D
static var _lip_material: StandardMaterial3D


## Unit direction along the floor for an angle in degrees.
static func direction(angle_degrees: float) -> Vector3:
	var a := deg_to_rad(angle_degrees)
	return Vector3(sin(a), 0.0, cos(a))


## Pure black that no light can brighten: the inside of every hole.
static func black_material() -> StandardMaterial3D:
	if _black == null:
		_black = StandardMaterial3D.new()
		_black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_black.albedo_color = Color.BLACK
		_black.disable_receive_shadows = true
	return _black


static func lip_material() -> StandardMaterial3D:
	if _lip_material == null:
		_lip_material = StandardMaterial3D.new()
		_lip_material.albedo_color = COLOR_LIP
		_lip_material.roughness = 1.0
	return _lip_material


func _ready() -> void:
	add_to_group("cave_shell")
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	holes.clear()
	_rng.seed = seed
	_phase = [_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU]
	_measure_profile()
	_build_shell()
	_build_holes()


# ----------------------------------------------------------- geometry ----

func _measure_profile() -> void:
	_wall_lengths = PackedFloat32Array()
	_wall_lengths.append(0.0)
	for i in range(1, WALL_PROFILE.size()):
		var a := _wall_point(i - 1)
		var b := _wall_point(i)
		_wall_lengths.append(_wall_lengths[i - 1] + a.distance_to(b))


## (radius, height) of a wall profile row, in meters, before jaggedness.
func _wall_point(row: int) -> Vector2:
	var p: Vector2 = WALL_PROFILE[row]
	var r := p.x * floor_radius
	if row == WALL_PROFILE.size() - 1:
		r = top_hole_radius
	return Vector2(r, p.y * height)


## Smooth deterministic wobble in -1..1 around the cave.
func _wobble(angle: float, row: float) -> float:
	return 0.5 * sin(3.0 * angle + _phase[0] + row * 0.7) \
			+ 0.3 * sin(7.0 * angle + _phase[1] - row * 1.3) \
			+ 0.2 * sin(13.0 * angle + _phase[2] + row * 2.1)


## How much the wall radius wobbles at a (fractional) row: none low down,
## up to about 5% higher up.
func _wall_amp(row: float) -> float:
	var smooth := float(SMOOTH_WALL_ROWS - 1)
	var t := clampf((row - smooth) / 3.0, 0.0, 1.0)
	return lerpf(0.0, 0.05, t)


## Floor bumps: flat in the middle (the hero lands there) and at the rim
## (tunnels start there), gently uneven in between.
func _floor_bump(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var fade := smoothstep(0.23, 0.46, r / floor_radius) * (1.0 - smoothstep(0.75, 0.9, r / floor_radius))
	var n := sin(x * 0.37 + _phase[0]) * sin(z * 0.41 + _phase[1]) + 0.5 * sin((x + z) * 0.6 + _phase[2])
	return n * 0.08 * fade


## The wall radius (before wobble) at a height, for pieces that must hug
## the lower wall (tunnel letters).
func wall_radius_at_height(y: float) -> float:
	for i in range(1, WALL_PROFILE.size()):
		var a := _wall_point(i - 1)
		var b := _wall_point(i)
		if y >= a.y and y <= b.y:
			return lerpf(a.x, b.x, (y - a.y) / maxf(b.y - a.y, 0.001))
	return floor_radius


## A point on the wall with its inward normal. angle in degrees; t from 0
## (floor rim) to 1 (top hole). Basis: Y = inward normal (what an ant
## standing there calls "up"), -Z = up the wall, X = around the wall.
func surface_transform(angle_degrees: float, t: float) -> Transform3D:
	t = clampf(t, 0.0, 1.0)
	var total := _wall_lengths[_wall_lengths.size() - 1]
	var want := t * total
	var row := 0
	while row < _wall_lengths.size() - 2 and _wall_lengths[row + 1] < want:
		row += 1
	var seg_len := _wall_lengths[row + 1] - _wall_lengths[row]
	var u := (want - _wall_lengths[row]) / maxf(seg_len, 0.001)
	var a := _wall_point(row)
	var b := _wall_point(row + 1)
	var p := a.lerp(b, u)
	var angle := deg_to_rad(angle_degrees)
	var frac_row := row + u
	p.x *= 1.0 + _wobble(angle, frac_row) * _wall_amp(frac_row)
	var tangent := (b - a).normalized()
	var normal2 := Vector2(-tangent.y, tangent.x)   # points toward the axis
	var dir := Vector3(sin(angle), 0.0, cos(angle))
	var origin := dir * p.x + Vector3.UP * p.y
	var normal := (dir * normal2.x + Vector3.UP * normal2.y).normalized()
	var up_wall := (dir * tangent.x + Vector3.UP * tangent.y).normalized()
	var x_axis := up_wall.cross(normal).normalized()
	return Transform3D(Basis(x_axis, normal, -up_wall), origin)


func _build_shell() -> void:
	var step := TAU / segments
	# Rings from the floor center out, then up the wall to the top hole.
	var rings: Array = []   # each: PackedVector3Array of segments+1 points
	var ring_kind: Array = []   # "floor" or "wall", with the row index
	for f in FLOOR_RINGS.size():
		var r: float = FLOOR_RINGS[f] * floor_radius
		var ring := PackedVector3Array()
		for s in segments + 1:
			var angle := step * s
			var x := sin(angle) * r
			var z := cos(angle) * r
			ring.append(Vector3(x, _floor_bump(x, z), z))
		rings.append(ring)
		ring_kind.append(["floor", f])
	for w in WALL_PROFILE.size():
		var p := _wall_point(w)
		var ring := PackedVector3Array()
		for s in segments + 1:
			var angle := step * s
			var r := p.x * (1.0 + _wobble(angle, w) * _wall_amp(w))
			var jitter := 0.0
			if w >= SMOOTH_WALL_ROWS and s < segments:
				jitter = _rng.randf_range(-0.35, 0.35) * _wall_amp(w) / 0.05
			ring.append(Vector3(sin(angle) * r, p.y + jitter, cos(angle) * r))
		rings.append(ring)
		ring_kind.append(["wall", w])
	for ring in rings:
		ring[segments] = ring[0]   # close the loop exactly

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var inside := Vector3(0.0, height * 0.5, 0.0)
	var first_wall_ring := FLOOR_RINGS.size()
	for i in rings.size() - 1:
		var kind_a: Array = ring_kind[i]
		var wall_row := int(kind_a[1]) if kind_a[0] == "wall" else -1
		for s in segments:
			if wall_row >= 0 and _is_cut(s, wall_row):
				continue
			var a: Vector3 = rings[i][s]
			var b: Vector3 = rings[i][s + 1]
			var c: Vector3 = rings[i + 1][s]
			var d: Vector3 = rings[i + 1][s + 1]
			var color := _face_color(i, first_wall_ring)
			if i == 0:
				# The center ring is a single point: a fan of triangles.
				_add_triangle(vertices, normals, colors, a, d, c, inside, color)
			else:
				_add_triangle(vertices, normals, colors, a, b, c, inside, color)
				_add_triangle(vertices, normals, colors, b, d, c, inside, _jitter_color(color))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material())
	var instance := MeshInstance3D.new()
	instance.name = "Shell"
	instance.mesh = mesh
	add_child(instance)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(vertices)
	shape.backface_collision = true
	var collider := CollisionShape3D.new()
	collider.name = "Collision"
	collider.shape = shape
	add_child(collider)


## True when this cell of the lower wall is inside one of the cuts.
func _is_cut(segment: int, wall_row: int) -> bool:
	var step := 360.0 / segments
	var center := (segment + 0.5) * step
	for cut in cuts:
		if wall_row >= int(cut.get("rows", 3)):
			continue
		var half := int(cut.get("cells", 2)) * step * 0.5
		var d := absf(wrapf(center - float(cut.angle), -180.0, 180.0))
		if d < half - 0.01:
			return true
	return false


func _face_color(ring_index: int, first_wall_ring: int) -> Color:
	if ring_index < first_wall_ring - 1:
		return COLOR_FLOOR
	if ring_index == first_wall_ring - 1:
		return COLOR_FLOOR.lerp(COLOR_WALL_LOW, 0.5)
	var row := ring_index - first_wall_ring
	var t := float(row) / float(WALL_PROFILE.size() - 2)
	if t < 0.5:
		return COLOR_WALL_LOW.lerp(COLOR_WALL_HIGH, t * 2.0)
	return COLOR_WALL_HIGH.lerp(COLOR_DOME, (t - 0.5) * 2.0)


func _jitter_color(color: Color) -> Color:
	var k := _rng.randf_range(-0.04, 0.04)
	return Color(color.r + k, color.g + k * 0.7, color.b + k * 0.5)


## Adds one flat-shaded triangle, wound so its front faces the inside of
## the cave (toward `inside`), whichever order the corners came in.
func _add_triangle(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray,
		a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 0.000001:
		return
	n = n.normalized()
	var centroid := (a + b + c) / 3.0
	if n.dot(inside - centroid) < 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	# Godot's front face is clockwise as seen from the front; the normal
	# from (b-a)x(c-a) points toward the viewer for counter-clockwise order,
	# so swap once more to make the clockwise order face the inside.
	for v in [a, c, b]:
		vertices.append(v)
		normals.append(n)
		colors.append(color)


func _material() -> StandardMaterial3D:
	if _shell_material == null:
		_shell_material = StandardMaterial3D.new()
		_shell_material.vertex_color_use_as_albedo = true
		_shell_material.roughness = 1.0
	return _shell_material


# -------------------------------------------------------------- holes ----

## Scatters the small holes over the walls and ceiling: a dirt lip, a black
## disc just inside it, and a collision plug. Keeps away from the cuts,
## the letters over the tunnels, and other holes.
func _build_holes() -> void:
	var root := Node3D.new()
	root.name = "SmallHoles"
	add_child(root)
	var attempts := 0
	while holes.size() < hole_count and attempts < hole_count * 40:
		attempts += 1
		var angle := _rng.randf() * 360.0
		var t := _rng.randf_range(0.1, 0.93)
		if not _hole_spot_free(angle, t):
			continue
		_add_hole(root, angle, t)


## Also used by the hub to place a specific hole (the Queen's).
func add_hole_at(angle: float, t: float) -> Dictionary:
	var root := get_node_or_null("SmallHoles") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "SmallHoles"
		add_child(root)
	return _add_hole(root, angle, t)


func _hole_spot_free(angle: float, t: float) -> bool:
	var low := t < 0.4
	if low:
		for cut in cuts:
			var d := absf(wrapf(angle - float(cut.angle), -180.0, 180.0))
			if d < 22.0:
				return false
		for clear in keep_clear_angles:
			if absf(wrapf(angle - float(clear), -180.0, 180.0)) < 22.0:
				return false
	var here := surface_transform(angle, t).origin
	for hole in holes:
		if (hole.transform as Transform3D).origin.distance_to(here) < 3.2:
			return false
	return true


func _add_hole(root: Node3D, angle: float, t: float) -> Dictionary:
	var xf := surface_transform(angle, t)
	var hole := Node3D.new()
	hole.name = "Hole%d" % holes.size()
	root.add_child(hole)
	hole.global_transform = xf
	# The lip: a squat torus around the opening, half sunk into the wall.
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.68
	torus.rings = 10
	torus.ring_segments = 6
	torus.material = lip_material()
	var lip := MeshInstance3D.new()
	lip.mesh = torus
	lip.position = Vector3(0.0, 0.1, 0.0)
	lip.scale = Vector3(1.0, 0.7, 1.0)
	hole.add_child(lip)
	# The black inside, a little way in.
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.46
	disc_mesh.bottom_radius = 0.46
	disc_mesh.height = 0.04
	disc_mesh.radial_segments = 12
	disc_mesh.rings = 1
	disc_mesh.material = black_material()
	var disc := MeshInstance3D.new()
	disc.mesh = disc_mesh
	disc.position = Vector3(0.0, 0.03, 0.0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hole.add_child(disc)
	# The plug: the ball can never get in, even if the wall somehow let it.
	var plug := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.68
	cylinder.height = 0.8
	plug.shape = cylinder
	plug.position = Vector3(0.0, 0.0, 0.0)
	hole.add_child(plug)
	var entry := {"angle": angle, "t": t, "transform": xf, "node": hole}
	holes.append(entry)
	return entry
