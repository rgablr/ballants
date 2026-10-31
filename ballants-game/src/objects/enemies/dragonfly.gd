class_name Dragonfly
extends Enemy
## DRAGONFLY -- a long, bright blue hunter with four see-through wings,
## about 2 m long at ant scale. It patrols a loop in the air above its
## patch. When it spots you it STOPS AND HOVERS, turning to face you and
## dipping its nose (your warning, a full second), then DIVES in a straight
## line at where you were when it committed. Swerve or jump during the
## warning and it misses, pulls up, and climbs back to its patrol.

@export var patrol_height := 6.0
@export var patrol_radius := 7.0
@export var patrol_speed := 4.0
@export var dive_speed := 15.0
@export var warn_time := 1.0

enum State { PATROL, AIM, DIVE, CLIMB }

var _state := State.PATROL
var _state_time := 0.0
var _angle := 0.0
var _dive_dir := Vector3.DOWN
var _cooldown := 0.0
var _body: Node3D
var _wings: Array[Node3D] = []


func enemy_name() -> String:
	return "dragonfly"


func _ready() -> void:
	super._ready()
	sight = maxf(sight, 12.0)
	_angle = randf() * TAU
	_build()
	global_position = _patrol_point(_angle)


func _build() -> void:
	var blue := CritterParts.material(Color(0.12, 0.5, 0.9), 0.25)
	var dark := CritterParts.material(Color(0.05, 0.15, 0.3), 0.3)
	var eye := CritterParts.material(Color(0.1, 0.55, 0.45), 0.1)
	var wing_mat := CritterParts.material(Color(0.8, 0.9, 1.0, 0.3), 0.05)
	_body = Node3D.new()
	add_child(_body)
	# Long segmented tail, thorax, big eyes.
	for i in 9:
		var z := 0.25 + i * 0.17
		CritterParts.sphere(_body, Vector3(0, 0, z), 0.09 - i * 0.004, Vector3(1, 1, 1.4), blue if i % 2 == 0 else dark, 8)
	CritterParts.sphere(_body, Vector3(0, 0.02, 0.0), 0.2, Vector3(1, 1, 1.3), blue)
	CritterParts.sphere(_body, Vector3(0.11, 0.06, -0.24), 0.13, Vector3.ONE, eye)
	CritterParts.sphere(_body, Vector3(-0.11, 0.06, -0.24), 0.13, Vector3.ONE, eye)
	for side in [1.0, -1.0]:
		_wings.append(CritterParts.wing(_body, Vector3(side * 0.1, 0.12, -0.08), 1.25, 0.28, side, wing_mat))
		_wings.append(CritterParts.wing(_body, Vector3(side * 0.1, 0.12, 0.12), 1.15, 0.3, side, wing_mat))
		for i in 3:
			var hip := Vector3(side * 0.08, -0.12, -0.08 + i * 0.07)
			CritterParts.rod(_body, hip, hip + Vector3(side * 0.12, -0.15, -0.08), 0.015, dark)


func _patrol_point(angle: float) -> Vector3:
	var ground := ground_at(_home)
	return _home + Vector3(cos(angle) * patrol_radius, 0.0, sin(angle) * patrol_radius * 0.6) \
			+ Vector3.UP * (ground - _home.y + patrol_height + sin(angle * 3.0) * 0.6)


func _physics_process(delta: float) -> void:
	_time += delta
	_state_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	var ball := target_ball()
	match _state:
		State.PATROL:
			_angle += patrol_speed / patrol_radius * delta
			var target := _patrol_point(_angle)
			var dir := target - global_position
			global_position = global_position.move_toward(target, patrol_speed * 1.5 * delta)
			if dir.length() > 0.01:
				rotation.y = lerp_angle(rotation.y, yaw_toward(Vector3.ZERO, dir), delta * 4.0)
			_body.rotation.x = lerpf(_body.rotation.x, 0.0, delta * 4.0)
			if _cooldown <= 0.0 and can_see(ball, global_position):
				_set_state(State.AIM)
		State.AIM:
			if ball:
				rotation.y = lerp_angle(rotation.y, yaw_toward(global_position, ball.global_position), delta * 6.0)
				var down := (ball.global_position - global_position).normalized()
				_body.rotation.x = lerpf(_body.rotation.x, asin(clampf(down.y, -1.0, 1.0)), delta * 4.0)   # nose down at you
				global_position.y += sin(_time * 8.0) * 0.01
			if _state_time >= warn_time:
				if ball:
					_dive_dir = (ball.global_position - global_position).normalized()
					_set_state(State.DIVE)
				else:
					_set_state(State.CLIMB)
		State.DIVE:
			global_position += _dive_dir * dive_speed * delta
			check_hit(global_position, 0.7)
			check_hit(_body.to_global(Vector3(0, 0, 0.8)), 0.4)
			var floor_y := ground_at(global_position)
			if global_position.y < floor_y + 0.6 or _state_time > 2.0:
				_set_state(State.CLIMB)
		State.CLIMB:
			var target := _patrol_point(_angle)
			global_position = global_position.move_toward(target, patrol_speed * 1.3 * delta)
			var dir := target - global_position
			if dir.length() > 0.01:
				rotation.y = lerp_angle(rotation.y, yaw_toward(Vector3.ZERO, dir), delta * 3.0)
			_body.rotation.x = lerpf(_body.rotation.x, 0.3, delta * 3.0)
			if dir.length() < 0.5:
				_cooldown = 2.5
				_set_state(State.PATROL)


func _set_state(state: State) -> void:
	_state = state
	_state_time = 0.0


func _process(_delta: float) -> void:
	for i in _wings.size():
		var side := 1.0 if i % 4 < 2 else -1.0
		var offset := 0.0 if i % 2 == 0 else PI * 0.5   # front and back pairs beat out of step
		_wings[i].rotation = Vector3(0, 0, side * sin(_time * 45.0 + offset) * 0.45)
