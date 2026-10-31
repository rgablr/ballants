class_name Ladybug
extends RigidBody3D
## LADYBUG -- wanders around near where it was placed, legs pattering. It
## is a real physics body, so the ball can bump it, push it and send it
## skidding. Roll at it fast and it pops open its red wing cases and flies
## off in a short hop, landing a few meters away.
##
## It always stays upright (tipping is locked), so it can't end up stuck on
## its back. About 0.7 m long: a bit bigger than the ant.

@export var wander_radius := 6.0
@export var walk_speed := 0.7
## Ball closer than this (m) and faster than flee_speed makes it fly off.
@export var flee_distance := 3.0
@export var flee_speed := 3.0

var _home := Vector3.ZERO
var _heading := 0.0
var _turn := 0.0
var _time := 0.0
var _flying := 0.0          # seconds left in a hop
var _legs: Array[Dictionary] = []
var _shells: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _body: Node3D
var _cooldown := 0.0


func _ready() -> void:
	mass = 0.6
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	linear_damp = 0.5
	angular_damp = 4.0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	shape.shape = sphere
	shape.position = Vector3(0, 0.3, 0)
	add_child(shape)
	_build()
	_home = global_position
	_heading = randf() * TAU
	_time = randf() * 10.0


func _build() -> void:
	var red := CritterParts.material(Color(0.86, 0.12, 0.08), 0.35)
	var black := CritterParts.material(Color(0.06, 0.05, 0.05), 0.5)
	var white := CritterParts.material(Color(0.95, 0.95, 0.9))
	var wing_mat := CritterParts.material(Color(0.85, 0.9, 1.0, 0.45), 0.2)
	_body = Node3D.new()
	add_child(_body)
	# Black underbody, head with white cheek spots.
	CritterParts.sphere(_body, Vector3(0, 0.28, 0), 0.3, Vector3(1.0, 0.7, 1.15), black)
	CritterParts.sphere(_body, Vector3(0, 0.3, -0.36), 0.15, Vector3(1.1, 0.9, 0.9), black)
	CritterParts.sphere(_body, Vector3(0.08, 0.34, -0.47), 0.04, Vector3.ONE, white)
	CritterParts.sphere(_body, Vector3(-0.08, 0.34, -0.47), 0.04, Vector3.ONE, white)
	# Two red wing cases (each a half dome) with black spots; they hinge open.
	for side in [1.0, -1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * 0.02, 0.42, -0.2)
		_body.add_child(hinge)
		var shell := CritterParts.sphere(hinge, Vector3(side * 0.15, -0.04, 0.22), 0.3, Vector3(0.55, 0.62, 1.15), red)
		shell.rotation.z = side * 0.15
		for spot in [Vector3(0.12, 0.13, 0.08), Vector3(0.2, 0.06, 0.32), Vector3(0.1, 0.11, 0.42)]:
			CritterParts.sphere(hinge, Vector3(side * spot.x, spot.y, spot.z), 0.055, Vector3(1, 0.4, 1), black)
		_shells.append(hinge)
		var wing := CritterParts.wing(_body, Vector3(side * 0.05, 0.4, -0.1), 0.55, 0.3, side, wing_mat)
		wing.visible = false
		_wings.append(wing)
	# Six little legs.
	for i in 3:
		for side in [1.0, -1.0]:
			var hip := Vector3(side * 0.18, 0.18, -0.15 + i * 0.15)
			var leg := CritterParts.rod(_body, hip, hip + Vector3(side * 0.18, -0.18, 0), 0.025, black)
			_legs.append({"rod": leg, "hip": hip, "side": side, "phase": i * 2.1 + (0.0 if side > 0 else PI)})
	# Antennae.
	for side in [1.0, -1.0]:
		CritterParts.rod(_body, Vector3(side * 0.05, 0.38, -0.46), Vector3(side * 0.12, 0.48, -0.62), 0.012, black)


func _physics_process(delta: float) -> void:
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	var player := CritterParts.find_player(self)
	if _flying > 0.0:
		_flying -= delta
		if _flying <= 0.0:
			_land()
	elif player and _cooldown <= 0.0:
		var to_me := global_position - player.global_position
		var close := Vector2(to_me.x, to_me.z).length() < flee_distance
		if close and player.linear_velocity.length() > flee_speed:
			_take_off(Vector3(to_me.x, 0, to_me.z).normalized())
	if _flying <= 0.0:
		_wander(delta)


func _wander(delta: float) -> void:
	# Drift the heading randomly; head home when too far out.
	_turn = lerpf(_turn, randf_range(-1.5, 1.5), delta * 0.8)
	_heading += _turn * delta
	var from_home := global_position - _home
	from_home.y = 0.0
	if from_home.length() > wander_radius:
		var home_heading := atan2(from_home.x, from_home.z)
		_heading = lerp_angle(_heading, home_heading, delta * 2.0)
	var forward := Vector3(sin(_heading), 0.0, cos(_heading)) * -1.0
	var v := linear_velocity
	var want := forward * walk_speed
	apply_central_force(Vector3(want.x - v.x, 0.0, want.z - v.z) * mass * 5.0)
	# Face where it's going.
	var yaw := rotation.y
	angular_velocity.y = wrapf(_heading - yaw, -PI, PI) * 4.0
	# Legs patter with walking speed.
	var speed := Vector2(v.x, v.z).length()
	for leg in _legs:
		var swing := sin(_time * 14.0 + leg.phase) * 0.08 * clampf(speed / walk_speed, 0.0, 1.5)
		var hip: Vector3 = leg.hip
		CritterParts.set_rod(leg.rod, hip, hip + Vector3(leg.side * 0.18, -0.18 + maxf(swing, 0.0) * 0.4, swing))
	_body.position.y = absf(sin(_time * 14.0)) * 0.01 * clampf(speed, 0.0, 1.0)


func _take_off(away: Vector3) -> void:
	_flying = 1.1
	linear_velocity = away * 3.5 + Vector3.UP * 4.5
	for i in _shells.size():
		var side := 1.0 if i == 0 else -1.0
		_shells[i].create_tween().tween_property(_shells[i], "rotation", Vector3(-0.5, 0, side * 0.9), 0.12)
	for wing in _wings:
		wing.visible = true


func _land() -> void:
	_cooldown = 1.5
	for shell in _shells:
		shell.create_tween().tween_property(shell, "rotation", Vector3.ZERO, 0.2)
	for wing in _wings:
		wing.visible = false


func _process(_delta: float) -> void:
	if _flying > 0.0:
		for i in _wings.size():
			_wings[i].rotation.z = (1.0 if i == 0 else -1.0) * sin(_time * 60.0) * 0.8
