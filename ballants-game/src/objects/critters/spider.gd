class_name Spider
extends Node3D
## SPIDER -- a garden spider, about twice the ant's size, with eight jointed
## legs that step in the alternating pattern real spiders use.
##
## On the ground (hanging = false) it creeps around near home and, when the
## ball comes close, scuttles away fast, legs a blur, before settling again.
## Hanging (hanging = true) it dangles from a silk thread from this node's
## position, bobbing gently; when the ball comes near it climbs up the
## thread, then lowers itself back down once it's gone. No collision.

@export var hanging := false
## Hanging: how far below this node it dangles (m).
@export var hang_length := 5.0
@export var wander_radius := 5.0
@export var creep_speed := 0.5
@export var flee_speed := 4.5
## Ball closer than this (m) startles it.
@export var startle_distance := 4.0

var _body: Node3D
var _legs: Array[Dictionary] = []
var _thread: MeshInstance3D
var _home := Vector3.ZERO
var _heading := 0.0
var _time := 0.0
var _flee := 0.0            # seconds of fleeing left
var _flee_dir := Vector3.ZERO
var _climb := 0.0           # hanging: 0 = all the way down, 1 = up at the top
var _pause := 0.0


func _ready() -> void:
	_build()
	_home = global_position
	_heading = randf() * TAU
	_time = randf() * 10.0
	if hanging:
		_body.position = Vector3.DOWN * hang_length


func _build() -> void:
	var brown := CritterParts.material(Color(0.32, 0.22, 0.14), 0.6)
	var dark := CritterParts.material(Color(0.14, 0.1, 0.07), 0.6)
	var pattern := CritterParts.material(Color(0.82, 0.7, 0.45), 0.6)
	var eye := CritterParts.material(Color(0.02, 0.02, 0.02), 0.2)
	_body = Node3D.new()
	add_child(_body)
	# Big round abdomen behind, smaller head-body in front.
	CritterParts.sphere(_body, Vector3(0, 0.55, 0.45), 0.42, Vector3(1, 0.85, 1.15), brown)
	for i in 3:
		CritterParts.sphere(_body, Vector3(0, 0.88 - i * 0.04, 0.3 + i * 0.18), 0.07, Vector3(1.6, 0.4, 1), pattern)
	CritterParts.sphere(_body, Vector3(0, 0.45, -0.12), 0.24, Vector3(1, 0.8, 1.1), dark)
	for e in [Vector3(0.07, 0.55, -0.33), Vector3(-0.07, 0.55, -0.33), Vector3(0.13, 0.52, -0.3), Vector3(-0.13, 0.52, -0.3)]:
		CritterParts.sphere(_body, e, 0.035, Vector3.ONE, eye, 6)
	# Eight legs: each a thigh going up-and-out to a knee, then down to a foot.
	for i in 4:
		for side in [1.0, -1.0]:
			var hip := Vector3(side * 0.16, 0.45, -0.25 + i * 0.12)
			var thigh := CritterParts.rod(_body, hip, hip + Vector3.UP * 0.1, 0.03, dark)
			var shin := CritterParts.rod(_body, hip, hip + Vector3.DOWN * 0.1, 0.025, dark)
			var spread := (-0.6 + i * 0.4)
			_legs.append({"thigh": thigh, "shin": shin, "hip": hip, "side": side, "spread": spread,
					"group": (i + (0 if side > 0 else 1)) % 2})
	if hanging:
		_thread = CritterParts.rod(self, Vector3.ZERO, Vector3.DOWN, 0.012, CritterParts.material(Color(0.95, 0.95, 0.95, 0.7), 0.3))


func _physics_process(delta: float) -> void:
	_time += delta
	var player := CritterParts.find_player(self)
	var near := false
	if player:
		near = _body.global_position.distance_to(player.global_position) < startle_distance
	Sounds.critter_touch(self, _body.global_position, 0.35)
	if hanging:
		_update_hanging(delta, near)
	else:
		_update_ground(delta, near, player)


func _update_ground(delta: float, near: bool, player: RigidBody3D) -> void:
	var speed := 0.0
	if _flee > 0.0:
		_flee -= delta
		speed = flee_speed
		_heading = lerp_angle(_heading, atan2(-_flee_dir.x, -_flee_dir.z), delta * 8.0)
	elif near and player:
		_flee = 1.6
		_flee_dir = global_position - player.global_position
		_flee_dir.y = 0.0
		_flee_dir = _flee_dir.normalized()
	else:
		_pause -= delta
		if _pause <= -3.0:
			_pause = randf_range(1.0, 3.0)   # creep for a while, then stop
		if _pause < 0.0:
			speed = creep_speed
			_heading += randf_range(-1.0, 1.0) * delta
	var from_home := global_position - _home
	from_home.y = 0.0
	if from_home.length() > wander_radius * (2.0 if _flee > 0.0 else 1.0):
		_heading = lerp_angle(_heading, atan2(from_home.x, from_home.z), delta * 3.0)
	var forward := -Vector3(sin(_heading), 0.0, cos(_heading))
	global_position += forward * speed * delta
	global_position.y = CritterParts.ground_height(self, global_position)
	rotation.y = _heading
	_animate_legs(speed)


func _update_hanging(delta: float, near: bool) -> void:
	_climb = move_toward(_climb, 1.0 if near else 0.0, delta * (1.2 if near else 0.25))
	var length := hang_length * (1.0 - _climb * 0.85) + sin(_time * 1.3) * 0.15
	_body.position = Vector3.DOWN * length + Vector3.DOWN * 0.0
	_body.rotation.y = sin(_time * 0.4) * 0.6
	CritterParts.set_rod(_thread, Vector3.ZERO, _body.position + Vector3.UP * 0.9)
	_animate_legs(2.0 if _climb > 0.01 and _climb < 0.99 else 0.0)


## Two groups of four legs step alternately; faster when running.
func _animate_legs(speed: float) -> void:
	var rate := 4.0 + speed * 3.5
	for leg in _legs:
		var side: float = leg.side
		var phase := _time * rate + (PI if leg.group == 1 else 0.0)
		var step := sin(phase) * 0.12 * clampf(speed, 0.0, 1.0)
		var lift := maxf(cos(phase), 0.0) * 0.1 * clampf(speed, 0.0, 1.0)
		var hip: Vector3 = leg.hip
		var outward := Vector3(side, 0.0, leg.spread).normalized()
		var knee := hip + outward * 0.35 + Vector3.UP * (0.3 + lift) + Vector3(0, 0, step * 0.5)
		var foot := hip + outward * 0.75 + Vector3(0, -0.45 + lift, step)
		if hanging:
			foot = hip + outward * 0.55 + Vector3(0, -0.15 + lift, step)
		CritterParts.set_rod(leg.thigh, hip, knee)
		CritterParts.set_rod(leg.shin, knee, foot)
