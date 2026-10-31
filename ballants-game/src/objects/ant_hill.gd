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
##   - an invisible catch zone over the crater (and down the shaft) notices
##     the ball. A fast ball launches off the rim and would sail over the
##     hole, so on entry the ball's speed is cut to a slow roll, it is
##     told to collide with the hill only (not the ground the hill sits
##     on), and it drops down the hole to the shaft floor. Game is told
##     the level is complete and the level manager does the fade-to-black.
##
## Slope: about 30 degrees, so the ball climbs it from a standstill
## (roll_acceleration beats gravity along the slope). The hole is wider
## than the ball (ball radius 0.5 m) so it can never rest on the lip.
##
## Collision layers: the hill is on layers 1 and 2. A caught ball switches
## its mask to layer 2 only, so it keeps bouncing off the shaft walls while
## passing through the dirt bed underneath.

## Radius of the mound where it meets the ground (m).
@export var base_radius := 4.5:
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

var _built := false
var _done := false


func _ready() -> void:
	collision_layer = 1 | 2
	_built = true
	_rebuild()


## The profile spun around the Y axis: (radius, height) from the outside
## in. The base starts a little underground so no sliver of ground shows
## between the hill and the floor it sits on.
func _profile() -> PackedVector2Array:
	var crater_depth := 0.45
	return PackedVector2Array([
		Vector2(base_radius, -0.1),
		Vector2(lerpf(base_radius, rim_radius, 0.36), height * 0.33),
		Vector2(lerpf(base_radius, rim_radius, 0.72), height * 0.73),
		Vector2(rim_radius, height),
		Vector2(hole_radius, height - crater_depth),
		Vector2(hole_radius, -shaft_depth),
		Vector2(0.0, -shaft_depth),
	])


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
	_add_sensor()


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
	for i in 40:
		var r := rng.randf_range(rim_radius + 0.2, base_radius * 0.95)
		var angle := rng.randf() * TAU
		var size := rng.randf_range(0.12, 0.3)
		var grain := MeshInstance3D.new()
		grain.mesh = mesh
		grain.scale = Vector3(size, size * 0.7, size)
		grain.position = Vector3(cos(angle) * r, _height_at(r) + size * 0.15, sin(angle) * r)
		grains.add_child(grain)


## The invisible catch zone: the air above the crater, the crater, and the
## shaft. Entering it ends the level. It stops short of the rim so a ball
## rolling around the outside slope is not caught.
func _add_sensor() -> void:
	var area := Area3D.new()
	area.name = "Hole"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = rim_radius - 0.6
	var top := height + 4.0
	cylinder.height = top + shaft_depth
	var shape := CollisionShape3D.new()
	shape.shape = cylinder
	shape.position = Vector3(0, (top - shaft_depth) * 0.5, 0)
	area.add_child(shape)
	add_child(area)
	if not Engine.is_editor_hint():
		area.body_entered.connect(_on_body_entered)


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


func _on_body_entered(body: Node3D) -> void:
	if _done or body is not PlayerBall:
		return
	_done = true
	var ball := body as RigidBody3D
	# Cut the speed to a slow roll aimed a little toward the hole, drop any
	# upward motion, and let it only collide with the hill from now on.
	var v := ball.linear_velocity
	var horizontal := Vector3(v.x, 0.0, v.z).limit_length(2.5)
	var to_center := global_position - ball.global_position
	to_center.y = 0.0
	ball.linear_velocity = horizontal + to_center.limit_length(1.0) * 1.5 + Vector3.UP * minf(v.y, 0.0)
	ball.angular_velocity *= 0.2
	ball.collision_mask = 2
	Game.complete_level()
	Sounds.goal()
