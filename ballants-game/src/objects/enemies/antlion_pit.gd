@tool
class_name AntlionPit
extends StaticBody3D
## ANTLION PIT -- a ring of loose sand with a funnel in the middle and an
## antlion buried at the bottom with only its head and big curved jaws
## showing. Exactly how real antlions hunt ants: once you're in the funnel
## the sand slides you toward the middle (and the antlion flicks sand at
## you). Reach the bottom and the jaws snap: knocked off.
##
## The warning: the jaws open wide as soon as you're over the rim. Escape
## by rolling straight back out (it's a slog) or jumping out. A fast ball
## can roll right across the funnel without stopping.
##
## The sand ring is real collision (a triangle mesh of the same shape you
## see). The pull is extra, applied only inside the funnel.

## Radius of the whole sand pile where it meets the ground.
@export var outer_radius := 5.6:
	set(v):
		outer_radius = v
		_rebuild()
## Radius of the rim's crest.
@export var rim_radius := 4.3:
	set(v):
		rim_radius = v
		_rebuild()
@export var rim_height := 0.9:
	set(v):
		rim_height = v
		_rebuild()
## Sand slide toward the middle inside the funnel (m/s²).
@export var pull := 4.5
## The jaws snap if the ball's center comes this close to the middle (m).
@export var jaw_reach := 1.1

const SAND := Color(0.86, 0.76, 0.55)
const SAND_DARK := Color(0.74, 0.62, 0.42)

var _built := false
var _jaws: Array[Node3D] = []
var _head: Node3D
var _time := 0.0
var _open := 0.0
var _snap := 0.0
var _flick_timer := 0.0
var _enemy := Enemy.new()   # borrow the shared enemy helpers


var _was_inside := false


func _ready() -> void:
	_built = true
	_rebuild()
	if not Engine.is_editor_hint():
		add_child(_enemy)


func _profile() -> PackedVector2Array:
	# Outside slope up to the rim, then a smooth funnel down to a small flat bottom.
	var points := PackedVector2Array()
	points.append(Vector2(outer_radius, -0.1))
	points.append(Vector2(lerpf(outer_radius, rim_radius, 0.5), rim_height * 0.6))
	points.append(Vector2(rim_radius, rim_height))
	for i in range(1, 6):
		var t := float(i) / 5.0
		var r := lerpf(rim_radius, 0.7, t)
		points.append(Vector2(r, lerpf(rim_height, 0.08, sqrt(t))))
	points.append(Vector2(0.0, 0.08))
	return points


func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		if child != _enemy:
			child.queue_free()
	_jaws.clear()
	var profile := _profile()
	var segments := 40
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for row in profile.size() - 1:
		for s in segments:
			var a0 := TAU * s / segments
			var a1 := TAU * (s + 1) / segments
			var p := profile[row]
			var q := profile[row + 1]
			var v := [Vector3(cos(a0) * p.x, p.y, sin(a0) * p.x), Vector3(cos(a1) * p.x, p.y, sin(a1) * p.x),
					Vector3(cos(a0) * q.x, q.y, sin(a0) * q.x), Vector3(cos(a1) * q.x, q.y, sin(a1) * q.x)]
			var color := SAND.lerp(SAND_DARK, clampf(1.0 - q.x / rim_radius, 0.0, 1.0))
			for idx in [0, 1, 2, 1, 3, 2]:
				st.set_color(color)
				st.add_vertex(v[idx])
				faces.append(v[idx])
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)

	# The antlion: a bristly brown head poking out of the sand, big jaws.
	var brown := CritterParts.material(Color(0.42, 0.3, 0.2), 0.8)
	var jaw_mat := CritterParts.material(Color(0.25, 0.15, 0.08), 0.4)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.05, 0)
	_head.scale = Vector3.ONE * 1.7   # big enough to read as a threat from the rim
	add_child(_head)
	CritterParts.sphere(_head, Vector3(0, 0.1, 0.1), 0.3, Vector3(1.1, 0.5, 1.0), brown)
	CritterParts.sphere(_head, Vector3(0.12, 0.24, -0.1), 0.05, Vector3.ONE, jaw_mat)
	CritterParts.sphere(_head, Vector3(-0.12, 0.24, -0.1), 0.05, Vector3.ONE, jaw_mat)
	for side in [1.0, -1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * 0.14, 0.15, -0.15)
		_head.add_child(hinge)
		# A curved jaw: three rods sweeping forward and in, with a spike.
		CritterParts.rod(hinge, Vector3.ZERO, Vector3(side * 0.25, 0.05, -0.3), 0.04, jaw_mat)
		CritterParts.rod(hinge, Vector3(side * 0.25, 0.05, -0.3), Vector3(side * 0.15, 0.08, -0.6), 0.035, jaw_mat)
		CritterParts.rod(hinge, Vector3(side * 0.15, 0.08, -0.6), Vector3(-side * 0.08, 0.08, -0.72), 0.03, jaw_mat)
		CritterParts.rod(hinge, Vector3(side * 0.22, 0.05, -0.4), Vector3(side * 0.08, 0.05, -0.45), 0.02, jaw_mat)
		_jaws.append(hinge)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_snap = maxf(_snap - delta, 0.0)
	var ball := _enemy.target_ball()
	var inside := false
	if ball:
		var local := to_local(ball.global_position)
		var across := Vector2(local.x, local.z).length()
		inside = across < rim_radius - 0.2 and local.y < rim_height + 1.2
		if inside:
			# The sand slides you toward the middle.
			var toward := Vector3(-local.x, 0.0, -local.z).normalized()
			ball.apply_central_force(global_transform.basis * toward * pull * ball.mass)
			_flick_sand(delta, ball)
			if across < jaw_reach:
				_snap = 0.4
				ball.knock_off(ball.global_position - global_position, "antlion")
	if inside and not _was_inside:
		Sounds.enemy_warn(global_position)   # the jaws open: you're in the pit
	_was_inside = inside
	# The jaws: open wide while you're in the funnel, snap shut on a catch,
	# otherwise twitch slowly.
	var want := 0.9 if inside else 0.25 + 0.08 * sin(_time * 1.5)
	if _snap > 0.0:
		want = -0.15
	_open = lerpf(_open, want, 1.0 - exp(-delta * (25.0 if _snap > 0.0 else 6.0)))
	for i in _jaws.size():
		var side := 1.0 if i == 0 else -1.0
		_jaws[i].rotation.y = side * _open
	if ball:
		var to_ball := to_local(ball.global_position)
		_head.rotation.y = lerp_angle(_head.rotation.y, atan2(-to_ball.x, -to_ball.z), delta * 3.0)


## Antlions flick sand at prey on the slope: little puffs from the middle.
func _flick_sand(delta: float, ball: PlayerBall) -> void:
	_flick_timer -= delta
	if _flick_timer > 0.0:
		return
	_flick_timer = 0.35
	var toward := (ball.global_position - global_position).normalized()
	Effects.impact(Tuning.impact_small, toward, global_position + Vector3.UP * 0.3)
