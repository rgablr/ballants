class_name Bee
extends Node3D
## BEE -- a fuzzy striped bumblebee, about 1.2 m long at ant scale, busily
## visiting flowers: it flies a lazy arc to a flower, hovers over it in a
## little figure-eight for a couple of seconds, then moves on to another.
## Its wings are a blur and its body bobs as it hovers.
##
## Jump into it and it gets knocked into a dizzy spin, then buzzes off
## higher for a moment before going back to work. No collision with the
## world (it flies over everything).

## How long it hovers at each flower (seconds).
@export var hover_time := 2.5
@export var flight_speed := 3.5

var _body: Node3D
var _wings: Array[Node3D] = []
var _time := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _flower: Node3D
var _t := 1.0               # progress along the current flight, 0..1
var _flight_length := 1.0
var _hover := 0.0
var _dizzy := 0.0
var _home := Vector3.ZERO


func _ready() -> void:
	_build()
	_time = randf() * 10.0
	_home = global_position
	_from = global_position
	_to = global_position
	_hover = randf() * hover_time


func _build() -> void:
	var yellow := CritterParts.material(Color(0.98, 0.78, 0.15), 0.9)
	var black := CritterParts.material(Color(0.08, 0.07, 0.06), 0.9)
	var eye := CritterParts.material(Color(0.05, 0.05, 0.05), 0.2)
	var wing_mat := CritterParts.material(Color(0.85, 0.9, 1.0, 0.35), 0.1)
	_body = Node3D.new()
	add_child(_body)
	# Striped abdomen: alternating fuzzy bands, then a stinger.
	for i in 5:
		var z := 0.12 + i * 0.13
		var r := 0.3 - absf(i - 1.5) * 0.04
		CritterParts.sphere(_body, Vector3(0, 0, z), r, Vector3(1, 0.95, 0.55), yellow if i % 2 == 0 else black, 10)
	CritterParts.rod(_body, Vector3(0, 0, 0.72), Vector3(0, -0.02, 0.86), 0.025, black)
	CritterParts.sphere(_body, Vector3(0, 0.02, -0.12), 0.25, Vector3.ONE, yellow, 10)   # fuzzy thorax
	CritterParts.sphere(_body, Vector3(0, 0.0, -0.38), 0.17, Vector3(1, 0.95, 0.9), black, 10)
	CritterParts.sphere(_body, Vector3(0.1, 0.04, -0.46), 0.07, Vector3(0.7, 1.2, 0.7), eye)
	CritterParts.sphere(_body, Vector3(-0.1, 0.04, -0.46), 0.07, Vector3(0.7, 1.2, 0.7), eye)
	for side in [1.0, -1.0]:
		CritterParts.rod(_body, Vector3(side * 0.05, 0.1, -0.48), Vector3(side * 0.12, 0.25, -0.62), 0.015, black)
		_wings.append(CritterParts.wing(_body, Vector3(side * 0.1, 0.2, -0.12), 0.6, 0.3, side, wing_mat))
		for i in 3:
			var hip := Vector3(side * 0.1, -0.15, -0.2 + i * 0.12)
			CritterParts.rod(_body, hip, hip + Vector3(side * 0.12, -0.2, 0.08), 0.02, black)


func _physics_process(delta: float) -> void:
	_time += delta
	var player := CritterParts.find_player(self)
	if _dizzy > 0.0:
		_dizzy -= delta
		_body.rotation.y += delta * 14.0 * _dizzy
		global_position += Vector3.UP * delta * 1.5
		if _dizzy <= 0.0:
			_body.rotation = Vector3.ZERO
			_choose_next()
		return
	if player and _body.global_position.distance_to(player.global_position) < 1.0:
		_dizzy = 1.5
		return
	if _t < 1.0:
		# Flying between flowers on a lazy arc.
		_t = minf(_t + delta * flight_speed / _flight_length, 1.0)
		var s := smoothstep(0.0, 1.0, _t)
		var p := _from.lerp(_to, s) + Vector3.UP * sin(_t * PI) * minf(_flight_length * 0.25, 4.0)
		var dir := p - global_position
		global_position = p
		if dir.length() > 0.001:
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 6.0)
	else:
		# Hovering over the flower: a small figure-eight, bobbing.
		_hover -= delta
		var eight := Vector3(sin(_time * 1.6) * 0.5, sin(_time * 3.2) * 0.15, sin(_time * 3.2) * 0.25)
		global_position = _to + eight
		if _hover <= 0.0:
			_choose_next()
	_body.position.y = sin(_time * 5.0) * 0.05


func _process(_delta: float) -> void:
	for i in _wings.size():
		var side := 1.0 if i == 0 else -1.0
		_wings[i].rotation = Vector3(0, side * 0.2, side * sin(_time * 80.0 + i) * 0.7)


func _choose_next() -> void:
	_flower = CritterParts.random_flower(self, _flower)
	_from = global_position
	if _flower:
		_to = _flower.top_position() + Vector3.UP * 1.2
	else:
		_to = _home + Vector3(randf_range(-5, 5), randf_range(1, 3), randf_range(-5, 5))
	_flight_length = maxf(_from.distance_to(_to), 0.5)
	_t = 0.0
	_hover = hover_time * randf_range(0.7, 1.3)
