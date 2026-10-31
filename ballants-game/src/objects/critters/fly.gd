class_name Fly
extends Node3D
## FLY -- sits on top of a flower rubbing its front legs together. When the
## ball comes near it takes off and zig-zags around in the air for a few
## seconds, buzzing, then lands on a flower again (maybe a different one).
##
## Place it anywhere; on start it hops onto the nearest flower. No collision.

## Ball closer than this (m) makes it take off.
@export var startle_distance := 6.0

enum State { PERCHED, FLYING, LANDING }

var _state := State.FLYING
var _perch: Node3D
var _time := 0.0
var _fly_time := 0.0
var _velocity := Vector3.ZERO
var _center := Vector3.ZERO
var _land_from := Vector3.ZERO
var _land_t := 0.0
var _body: Node3D
var _wings: Array[Node3D] = []
var _hands: Array[Dictionary] = []


func _ready() -> void:
	_build()
	_time = randf() * 10.0
	_center = global_position
	_pick_perch.call_deferred(true)


func _build() -> void:
	var grey := CritterParts.material(Color(0.2, 0.22, 0.24), 0.4)
	var eye := CritterParts.material(Color(0.7, 0.12, 0.08), 0.3)
	var wing_mat := CritterParts.material(Color(0.8, 0.85, 0.95, 0.4), 0.1)
	_body = Node3D.new()
	add_child(_body)
	CritterParts.sphere(_body, Vector3(0, 0.22, 0.12), 0.16, Vector3(0.9, 0.8, 1.4), grey)      # abdomen
	CritterParts.sphere(_body, Vector3(0, 0.25, -0.08), 0.13, Vector3.ONE, grey)                # thorax
	CritterParts.sphere(_body, Vector3(0, 0.27, -0.24), 0.1, Vector3(1.2, 1, 0.9), grey)        # head
	CritterParts.sphere(_body, Vector3(0.08, 0.29, -0.28), 0.07, Vector3.ONE, eye)
	CritterParts.sphere(_body, Vector3(-0.08, 0.29, -0.28), 0.07, Vector3.ONE, eye)
	for side in [1.0, -1.0]:
		_wings.append(CritterParts.wing(_body, Vector3(side * 0.06, 0.36, -0.05), 0.4, 0.2, side, wing_mat))
		for i in 3:
			var hip := Vector3(side * 0.06, 0.18, -0.12 + i * 0.1)
			var leg := CritterParts.rod(_body, hip, hip + Vector3(side * 0.12, -0.18, 0.02), 0.012, grey)
			if i == 0:
				_hands.append({"rod": leg, "hip": hip, "side": side})


func _physics_process(delta: float) -> void:
	_time += delta
	var player := CritterParts.find_player(self)
	match _state:
		State.PERCHED:
			if _perch:
				global_position = _perch.top_position()
			if player and global_position.distance_to(player.global_position) < startle_distance:
				_take_off()
		State.FLYING:
			_fly_time -= delta
			# Erratic: random jinks, pulled back toward the middle of its patch.
			if randf() < delta * 4.0:
				_velocity = Vector3(randf_range(-1, 1), randf_range(-0.5, 0.6), randf_range(-1, 1)).normalized() * randf_range(3.0, 6.0)
			_velocity += (_center - global_position) * delta * 0.8
			global_position += _velocity * delta
			var floor_y := CritterParts.ground_height(self, global_position) + 1.0
			global_position.y = maxf(global_position.y, floor_y)
			if _velocity.length() > 0.1:
				look_at(global_position + Vector3(_velocity.x, 0, _velocity.z), Vector3.UP)
			if _fly_time <= 0.0 and (player == null or global_position.distance_to(player.global_position) > startle_distance):
				_pick_perch(false)
		State.LANDING:
			_land_t = minf(_land_t + delta * 1.2, 1.0)
			var target: Vector3 = _perch.top_position()
			var arc := sin(_land_t * PI) * 1.5
			global_position = _land_from.lerp(target, smoothstep(0.0, 1.0, _land_t)) + Vector3.UP * arc
			if _land_t >= 1.0:
				_state = State.PERCHED
				rotation.y = randf() * TAU


func _process(_delta: float) -> void:
	var flying := _state != State.PERCHED
	for i in _wings.size():
		var side := 1.0 if i == 0 else -1.0
		if flying:
			_wings[i].rotation = Vector3(0, side * 0.3, side * sin(_time * 70.0) * 0.9)
		else:
			# Folded back along the body, with the odd twitch.
			var twitch := maxf(sin(_time * 0.7 + i) - 0.97, 0.0) * 10.0
			_wings[i].rotation = Vector3(0, side * 1.1, side * twitch * 0.3)
	# Perched: rubbing its front legs together.
	for hand in _hands:
		var side: float = hand.side
		var hip: Vector3 = hand.hip
		var rub := sin(_time * 9.0) * 0.04 if not flying else 0.0
		var foot := hip + Vector3(-side * 0.02 + rub * side, 0.02, -0.16) if not flying else hip + Vector3(side * 0.1, -0.15, 0)
		CritterParts.set_rod(hand.rod, hip, foot)


func _take_off() -> void:
	_state = State.FLYING
	_fly_time = randf_range(3.0, 6.0)
	_velocity = Vector3(randf_range(-1, 1), 1.5, randf_range(-1, 1)).normalized() * 5.0
	_center = global_position + Vector3.UP * 2.5


func _pick_perch(instant: bool) -> void:
	_perch = CritterParts.random_flower(self, _perch if randf() < 0.5 else null)
	if instant and _perch == null:
		return
	if _perch == null:
		_fly_time = 2.0
		return
	# Prefer a flower near where it started.
	var best: Node3D = _perch
	for f in get_tree().get_nodes_in_group("flower"):
		if f.global_position.distance_to(_center) < best.global_position.distance_to(_center) and randf() < 0.6:
			best = f
	_perch = best
	if instant:
		global_position = _perch.top_position()
		_state = State.PERCHED
		return
	_state = State.LANDING
	_land_from = global_position
	_land_t = 0.0
