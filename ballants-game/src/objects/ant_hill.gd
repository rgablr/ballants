@tool
class_name AntHill
extends StaticBody3D
## ANT HILL -- the level's finish. A cone of dirt with a hole in the top:
## roll up the slope, drop into the hole, and the level is complete.
##
## Built in code from a few numbers so every level's hill matches:
##   - the mound is a surface of revolution (a 2-D profile spun around the
##     middle), with a shallow crater on top that funnels the ball into the
##     hole, and a shaft below the hole the ball falls down
##   - the collision is a triangle mesh of exactly that surface, so what
##     you see is what you roll on (the shaft walls included)
##   - the THRESHOLD is an invisible zone just inside the hole's lip, no
##     higher than a ball sitting in the crater. The player has to actually
##     roll the ball into the crater; a ball flying over the hill passes
##     above it and lands beyond, and they come back for another go.
##   - once the ball crosses the threshold it is taken out of the physics
##     and sunk: it slides to the middle of the hole and drops down the
##     shaft out of sight. Game is told the level is complete (or, for a
##     hill with enter_level set, that level loads) and the level manager
##     does the fade-to-black.
##
## Shape: the slope follows an S-curve, gentle at the foot (no bump when
## the ball arrives), steepest in the middle (about 30 degrees, which the
## ball still climbs from a standstill), and flattening at the rim, so a
## ball arriving at a sensible speed slows on top and tips into the crater.
## The hole is wider than the ball (ball radius 0.5 m) so it can never rest
## on the lip.

## Radius of the mound where it meets the ground (m).
@export var base_radius := 5.5:
	set(v):
		base_radius = v
		_rebuild()
## Height of the rim above the ground (m).
@export var height := 1.3:
	set(v):
		height = v
		_rebuild()
## Radius of the hole the ball drops through (m). Must beat the ball's 0.5.
@export var hole_radius := 1.05:
	set(v):
		hole_radius = v
		_rebuild()
## How far the ball falls inside before hitting the floor (m).
@export var shaft_depth := 3.0:
	set(v):
		shaft_depth = v
		_rebuild()
## Radius of the crater's edge: the bowl funnels in from here to the hole.
@export var rim_radius := 2.0:
	set(v):
		rim_radius = v
		_rebuild()
## How many slices around; more = rounder, slightly more triangles.
@export var segments := 36:
	set(v):
		segments = maxi(v, 8)
		_rebuild()
@export var seed := 7:
	set(v):
		seed = v
		_rebuild()
## -1 = this hill finishes the level (results screen). 0, 1, 2... = this
## hill is an entrance: dropping in loads that level from the level list
## (the title area's giant hill uses 0, the first level).
@export var enter_level := -1

## Seconds the ball takes to slide to the middle, then to sink out of sight.
const SINK_CENTER_TIME := 0.25
const SINK_DROP_TIME := 0.6

var _built := false
var _done := false


func _ready() -> void:
	add_to_group("ant_hill")
	_built = true
	_rebuild()


## The profile spun around the Y axis: (radius, height) from the outside
## in. The base starts a little underground so no sliver of ground shows
## between the hill and the floor it sits on.
func _profile() -> PackedVector2Array:
	var crater_depth := 0.45
	var points := PackedVector2Array()
	# The slope: an S-curve (smoothstep) from the foot to the rim.
	var samples := 8
	for i in samples + 1:
		var t := float(i) / samples
		var s := t * t * (3.0 - 2.0 * t)
		points.append(Vector2(lerpf(base_radius, rim_radius, t), lerpf(-0.1, height, s)))
	# The crater: a rounded bowl down to the lip of the hole.
	points.append(Vector2(lerpf(rim_radius, hole_radius, 0.5), height - crater_depth * 0.35))
	# The last three rows must stay in this order (the hole surface uses them).
	points.append(Vector2(hole_radius, height - crater_depth))
	points.append(Vector2(hole_radius, -shaft_depth))
	points.append(Vector2(0.0, -shaft_depth))
	return points


func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		child.queue_free()

	var profile := _profile()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	# Spin the profile: one ring of points per profile row.
	var rows := profile.size()
	for row in rows:
		var p := profile[row]
		# Outward normal of this segment of the profile (in the radius/height
		# plane), averaged with the neighbour so the hill shades smoothly.
		var n2 := _profile_normal(profile, row)
		for s in segments + 1:
			var angle := TAU * float(s) / float(segments)
			var c := cos(angle)
			var sn := sin(angle)
			vertices.append(Vector3(p.x * c, p.y, p.x * sn))
			normals.append(Vector3(n2.x * c, n2.y, n2.x * sn).normalized())
	# Two surfaces: the sunlit mound (slope and crater) and the dark hole
	# (shaft walls and floor), so the hole reads as a hole from a distance.
	var hole_indices := PackedInt32Array()
	var shaft_row := rows - 3   # the row where the shaft wall starts
	for row in rows - 1:
		for s in segments:
			var a := row * (segments + 1) + s
			var b := a + 1
			var c := a + (segments + 1)
			var d := c + 1
			# Godot front faces are clockwise as seen by the viewer. This
			# order makes the slope visible from above and the shaft walls
			# visible from inside the shaft.
			var quad := PackedInt32Array([a, b, c, b, d, c])
			if row >= shaft_row:
				hole_indices.append_array(quad)
			else:
				indices.append_array(quad)

	var mesh := ArrayMesh.new()
	for pair in [[indices, _dirt_material()], [hole_indices, _hole_material()]]:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = pair[0]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, pair[1])
	indices.append_array(hole_indices)   # collision wants all of it
	var instance := MeshInstance3D.new()
	instance.name = "Mound"
	instance.mesh = mesh
	add_child(instance)

	# Collision: the same triangles. Both sides so the shaft walls hold the
	# ball from the inside too.
	var faces := PackedVector3Array()
	for i in range(0, indices.size(), 3):
		faces.append(vertices[indices[i]])
		faces.append(vertices[indices[i + 1]])
		faces.append(vertices[indices[i + 2]])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collider := CollisionShape3D.new()
	collider.name = "Collision"
	collider.shape = shape
	add_child(collider)

	_add_grains()


## A lighter dirt than the beds, so the hill reads as fresh-dug.
func _dirt_material() -> StandardMaterial3D:
	return GardenTheme.material("dirt_light")


## Near-black for the inside of the hole; shared by every hill.
static var _hole_material_cache: StandardMaterial3D
func _hole_material() -> StandardMaterial3D:
	if _hole_material_cache == null:
		_hole_material_cache = StandardMaterial3D.new()
		_hole_material_cache.albedo_color = Color(0.12, 0.08, 0.05)
		_hole_material_cache.roughness = 1.0
	return _hole_material_cache


## Little clods of soil scattered on the slope. Visual only.
func _add_grains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var grains := Node3D.new()
	grains.name = "Grains"
	add_child(grains)
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = GardenTheme.material("dirt")
	var scale_up := base_radius / 5.5   # bigger hills get more and bigger clods
	for i in int(clampf(40.0 * scale_up * scale_up, 20.0, 600.0)):
		var r := rng.randf_range(rim_radius + 0.2, base_radius * 0.95)
		var angle := rng.randf() * TAU
		var size := rng.randf_range(0.12, 0.3) * sqrt(scale_up)
		var grain := MeshInstance3D.new()
		grain.mesh = mesh
		grain.scale = Vector3(size, size * 0.7, size)
		grain.position = Vector3(cos(angle) * r, _height_at(r) + size * 0.15, sin(angle) * r)
		grains.add_child(grain)


## The threshold, checked against the ball's CENTER every physics step: it
## counts once the center is over the hole (inside the lip, with a little
## overhang) and no higher than a ball resting in the crater. A ball flying
## over the hill has its center well above that and is never caught.
const THRESHOLD_OVERHANG := 0.25   # m past the lip the center may be
const THRESHOLD_ABOVE_RIM := 0.15  # m above the rim the center may be


func _physics_process(_delta: float) -> void:
	if _done or Engine.is_editor_hint():
		return
	for node in get_tree().get_nodes_in_group("player"):
		var ball := node as PlayerBall
		if ball == null or ball.freeze:
			continue
		var local := ball.global_position - global_position
		var across := Vector2(local.x, local.z).length()
		if across <= hole_radius + THRESHOLD_OVERHANG and local.y <= height + THRESHOLD_ABOVE_RIM:
			_on_ball_crossed(ball)
			return


## Surface height at a distance from the middle (outside the hole).
func _height_at(r: float) -> float:
	var profile := _profile()
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		if (r <= a.x and r >= b.x) or (r >= a.x and r <= b.x):
			if is_equal_approx(a.x, b.x):
				return maxf(a.y, b.y)
			return lerpf(a.y, b.y, (r - a.x) / (b.x - a.x))
	return 0.0


## Normal of the profile at a row, in the (radius, height) plane, pointing
## out of the dirt.
static func _profile_normal(profile: PackedVector2Array, row: int) -> Vector2:
	var n := Vector2.ZERO
	if row > 0:
		var d := profile[row] - profile[row - 1]
		n += Vector2(d.y, -d.x).normalized()
	if row < profile.size() - 1:
		var d := profile[row + 1] - profile[row]
		n += Vector2(d.y, -d.x).normalized()
	return n.normalized() if n != Vector2.ZERO else Vector2.UP


func _on_ball_crossed(ball: PlayerBall) -> void:
	_done = true
	_sink(ball)
	if enter_level >= 0:
		Levels.enter_level_through_hill(enter_level)
	else:
		Game.complete_level()
	Sounds.goal()


## Takes the ball out of the physics and slides it into the hole: to the
## middle first, then straight down the shaft.
func _sink(ball: RigidBody3D) -> void:
	var spin := ball.angular_velocity
	ball.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	ball.set_deferred("freeze", true)
	ball.linear_velocity = Vector3.ZERO
	var middle := global_position + Vector3.UP * (height - 0.3)
	var bottom := global_position + Vector3.UP * (-shaft_depth + 0.6)
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(ball, "global_position", middle, SINK_CENTER_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ball, "global_position", bottom, SINK_DROP_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Keep it visibly rolling a little as it goes in.
	tween.parallel().tween_method(func(t: float):
		ball.rotate(spin.normalized() if spin.length() > 0.01 else Vector3.RIGHT, t * 0.08),
		1.0, 0.0, SINK_DROP_TIME)
