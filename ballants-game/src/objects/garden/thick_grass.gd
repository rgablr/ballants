@tool
class_name ThickGrass
extends Node3D
## THICK GRASS -- a patch of tall, thick grass blades, rooted in the ground,
## that you can push through like brush.
##
## Roll into it slowly and the blades bend away from the ball, push back on
## it and slow it down; they spring upright again once you're past. Hit a
## blade hard (faster than break_speed) and it SNAPS: the broken blade
## tumbles away as a loose piece, a puff of dust goes up, and the ball
## loses a little speed. Snapped blades grow back after regrow_time.
##
## The blades are not physics bodies (that would be dozens of joints and
## jitter); each one is a little spring the script updates every physics
## step against the ball's position, which is cheap and never glitches.

@export var blade_count := 14:
	set(v):
		blade_count = maxi(v, 1)
		_rebuild()
@export var radius := 3.0:
	set(v):
		radius = v
		_rebuild()
@export var height_min := 2.6:
	set(v):
		height_min = v
		_rebuild()
@export var height_max := 4.4:
	set(v):
		height_max = v
		_rebuild()
@export var seed := 1:
	set(v):
		seed = v
		_rebuild()
## Ball speed (m/s) at which a blade snaps instead of bending.
@export var break_speed := 6.0
## How strongly pushing through the brush slows the ball (per second).
@export var drag := 2.4
## Seconds before a snapped blade grows back.
@export var regrow_time := 12.0

const BLADE_WIDTH := 0.45
const BLADE_THICKNESS := 0.14
const BALL_RADIUS := 0.5
const CONTACT := BALL_RADIUS + 0.18   # ball center to blade centerline
const STIFFNESS := 55.0               # how hard a bent blade springs back
const DAMPING := 6.5
const PUSH := 110.0                   # how hard the ball shoves a blade over
const SHOVE_BACK := 26.0              # how hard a blade shoves the ball back (m/s² at full overlap)
const MAX_BEND := 1.25                # radians; a blade can't fold flatter than this

var _built := false
var _blades: Array[Dictionary] = []
var _player: RigidBody3D


func _ready() -> void:
	_built = true
	_rebuild()


func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		child.queue_free()
	_blades.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in blade_count:
		var angle := rng.randf() * TAU
		var distance := sqrt(rng.randf()) * radius
		var height := rng.randf_range(height_min, height_max)
		var pivot := Node3D.new()
		pivot.position = Vector3(cos(angle) * distance, -0.1, sin(angle) * distance)
		add_child(pivot)
		var mesh := PrismMesh.new()
		mesh.size = Vector3(BLADE_WIDTH, height, BLADE_THICKNESS)
		mesh.left_to_right = rng.randf_range(0.35, 0.65)
		mesh.material = GardenTheme.material("grass" if rng.randf() < 0.6 else "grass_dark")
		var blade := MeshInstance3D.new()
		blade.mesh = mesh
		blade.position = Vector3.UP * height * 0.5
		blade.rotation.y = rng.randf() * TAU
		var grow := Node3D.new()   # scaled when the blade grows back
		pivot.add_child(grow)
		grow.add_child(blade)
		var rest := Vector2(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08))
		_blades.append({
			"pivot": pivot, "grow": grow, "mesh": blade, "height": height, "rest": rest,
			"bend": rest, "bend_velocity": Vector2.ZERO,
			"touching": false, "broken": false, "regrow": 0.0,
			"sway": rng.randf() * TAU,
		})
		_apply_bend(_blades[-1])


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _blades.is_empty():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as RigidBody3D
	var time := Time.get_ticks_msec() * 0.001
	for blade in _blades:
		if blade.broken:
			_update_regrow(blade, delta)
			continue
		var push := Vector2.ZERO
		if _player and not _player.freeze:
			push = _touch_ball(blade, delta)
		# A gentle breeze sway, plus the spring back toward rest.
		var breeze := Vector2(sin(time * 1.3 + blade.sway), cos(time * 1.1 + blade.sway)) * 0.03
		var accel: Vector2 = (blade.rest + breeze - blade.bend) * STIFFNESS - blade.bend_velocity * DAMPING + push
		blade.bend_velocity += accel * delta
		blade.bend += blade.bend_velocity * delta
		blade.bend = blade.bend.limit_length(MAX_BEND)
		_apply_bend(blade)


## Checks the ball against one blade; returns the push on the blade and
## applies the brush's resistance to the ball.
func _touch_ball(blade: Dictionary, delta: float) -> Vector2:
	var pivot: Node3D = blade.pivot
	var base := pivot.global_position
	var ball := _player.global_position
	var rise := ball.y - base.y
	var height: float = blade.height
	var bend: Vector2 = blade.bend
	var angle := bend.length()
	if rise < -BALL_RADIUS or rise > height * cos(angle) + BALL_RADIUS:
		blade.touching = false
		return Vector2.ZERO
	# Where the (leaning) blade is at the height of the ball's center.
	var lean := bend.normalized() * tan(minf(angle, 1.2)) * maxf(rise, 0.0) if angle > 0.001 else Vector2.ZERO
	var blade_at := Vector2(base.x, base.z) + lean
	var offset := blade_at - Vector2(ball.x, ball.z)
	var distance := offset.length()
	if distance >= CONTACT:
		blade.touching = false
		return Vector2.ZERO
	var away := offset / distance if distance > 0.001 else Vector2(1, 0)
	var overlap := 1.0 - distance / CONTACT
	var v := _player.linear_velocity
	var speed := Vector2(v.x, v.z).length()
	if not blade.touching and speed > break_speed:
		_snap(blade, v)
		return Vector2.ZERO
	blade.touching = true
	# The brush slows the ball and nudges it away from the blade.
	var slow := 1.0 - clampf(drag * overlap * delta, 0.0, 0.5)
	_player.linear_velocity = Vector3(v.x * slow, v.y, v.z * slow)
	_player.apply_central_force(Vector3(-away.x, 0.0, -away.y) * SHOVE_BACK * overlap * _player.mass)
	return away * PUSH * overlap


func _apply_bend(blade: Dictionary) -> void:
	var bend: Vector2 = blade.bend
	var angle := bend.length()
	var pivot: Node3D = blade.pivot
	if angle < 0.0001:
		pivot.basis = Basis()
		return
	var toward := Vector3(bend.x, 0.0, bend.y) / angle
	pivot.basis = Basis(Vector3.UP.cross(toward).normalized(), angle)


## The blade breaks off: hide it, throw a loose copy, puff of dust.
func _snap(blade: Dictionary, ball_velocity: Vector3) -> void:
	blade.broken = true
	blade.touching = false
	blade.regrow = regrow_time
	var pivot: Node3D = blade.pivot
	var source: MeshInstance3D = blade.mesh
	pivot.visible = false

	var piece := RigidBody3D.new()
	piece.mass = 0.3
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BLADE_WIDTH * 0.7, blade.height * 0.9, BLADE_THICKNESS)
	shape.shape = box
	piece.add_child(shape)
	var look := MeshInstance3D.new()
	look.mesh = source.mesh
	piece.add_child(look)
	get_parent().add_child(piece)
	piece.global_transform = source.global_transform
	piece.add_collision_exception_with(_player)   # debris never trips the ball
	var horizontal := Vector3(ball_velocity.x, 0.0, ball_velocity.z)
	piece.linear_velocity = horizontal * 0.6 + Vector3.UP * 2.5
	piece.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-6, 6))
	var fade := piece.create_tween()
	fade.tween_interval(2.5)
	fade.tween_property(piece, "scale", Vector3.ONE * 0.01, 0.6)
	fade.tween_callback(piece.queue_free)

	_player.linear_velocity = Vector3(ball_velocity.x * 0.88, ball_velocity.y, ball_velocity.z * 0.88)
	Effects.impact(Tuning.impact_small, -horizontal.normalized(), pivot.global_position + Vector3.UP * 0.3)


## Grows a snapped blade back once its timer runs out and the ball isn't
## standing in the way.
func _update_regrow(blade: Dictionary, delta: float) -> void:
	blade.regrow -= delta
	if blade.regrow > 0.0:
		return
	var pivot: Node3D = blade.pivot
	if _player and pivot.global_position.distance_to(_player.global_position) < 3.0:
		return
	blade.broken = false
	blade.bend = blade.rest
	blade.bend_velocity = Vector2.ZERO
	pivot.visible = true
	var grow: Node3D = blade.grow
	grow.scale = Vector3(1.0, 0.05, 1.0)
	var tween := grow.create_tween()
	tween.tween_property(grow, "scale", Vector3.ONE, 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
