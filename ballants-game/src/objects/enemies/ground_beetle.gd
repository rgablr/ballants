class_name GroundBeetle
extends Enemy
## GROUND BEETLE -- a big, glossy black hunting beetle, about 1.5 m long,
## on long legs, with curved jaws. It patrols its patch slowly. When it
## spots you it stops, REARS UP and opens its jaws (that's your warning),
## then charges in a straight line. It can turn only a little while
## charging, so a sidestep beats it. After a charge it rests, then walks
## home.

@export var patrol_speed := 1.2
@export var charge_speed := 6.0
## Seconds of warning (rearing up) before the charge.
@export var warn_time := 0.7

enum State { PATROL, WARN, CHARGE, REST }

var _state := State.PATROL
var _state_time := 0.0
var _heading := 0.0
var _charge_dir := Vector3.FORWARD
var _body: Node3D
var _jaws: Array[Node3D] = []
var _legs: Array[Dictionary] = []


func enemy_name() -> String:
	return "ground beetle"


func _ready() -> void:
	super._ready()
	_heading = randf() * TAU
	_build()


func _build() -> void:
	var shell := CritterParts.material(Color(0.08, 0.08, 0.12), 0.15)
	var shell_edge := CritterParts.material(Color(0.2, 0.2, 0.35), 0.2)
	var leg := CritterParts.material(Color(0.05, 0.05, 0.06), 0.4)
	_body = Node3D.new()
	add_child(_body)
	# Wing cases (long glossy oval), thorax, head.
	CritterParts.sphere(_body, Vector3(0, 0.55, 0.3), 0.42, Vector3(1.0, 0.6, 1.6), shell)
	CritterParts.sphere(_body, Vector3(0, 0.6, 0.3), 0.36, Vector3(0.15, 0.6, 1.7), shell_edge)   # the seam ridge
	CritterParts.sphere(_body, Vector3(0, 0.55, -0.35), 0.28, Vector3(1.1, 0.6, 0.9), shell)
	CritterParts.sphere(_body, Vector3(0, 0.52, -0.68), 0.2, Vector3(1.0, 0.75, 0.9), shell)
	# Jaws on hinges so they can open and snap.
	for side in [1.0, -1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * 0.09, 0.48, -0.85)
		_body.add_child(hinge)
		CritterParts.rod(hinge, Vector3.ZERO, Vector3(side * 0.08, 0.0, -0.22), 0.035, leg)
		CritterParts.rod(hinge, Vector3(side * 0.08, 0.0, -0.22), Vector3(-side * 0.04, 0.0, -0.36), 0.03, leg)
		_jaws.append(hinge)
		CritterParts.rod(_body, Vector3(side * 0.1, 0.6, -0.8), Vector3(side * 0.45, 0.75, -1.25), 0.015, leg)   # antenna
	# Six long legs.
	for i in 3:
		for side in [1.0, -1.0]:
			var hip := Vector3(side * 0.25, 0.45, -0.4 + i * 0.3)
			var thigh := CritterParts.rod(_body, hip, hip + Vector3.UP * 0.1, 0.035, leg)
			var shin := CritterParts.rod(_body, hip, hip + Vector3.DOWN * 0.1, 0.03, leg)
			_legs.append({"thigh": thigh, "shin": shin, "hip": hip, "side": side,
					"reach": -0.35 + i * 0.35, "group": (i + (0 if side > 0 else 1)) % 2})


func _physics_process(delta: float) -> void:
	_time += delta
	_state_time += delta
	var ball := target_ball()
	var speed := 0.0
	match _state:
		State.PATROL:
			speed = patrol_speed
			_heading += sin(_time * 0.4) * delta * 0.8
			if distance_from_home(global_position) > leash * 0.6:
				_heading = lerp_angle(_heading, yaw_toward(global_position, _home), delta * 2.0)
			if can_see(ball, global_position):
				_set_state(State.WARN)
		State.WARN:
			if ball:
				_heading = lerp_angle(_heading, yaw_toward(global_position, ball.global_position), delta * 8.0)
			if _state_time >= warn_time:
				_charge_dir = -Vector3(sin(_heading), 0.0, cos(_heading))
				_set_state(State.CHARGE)
		State.CHARGE:
			speed = charge_speed
			if ball:   # can steer only a little
				var want := yaw_toward(global_position, ball.global_position)
				_heading = rotate_toward(_heading, want, delta * 0.6)
			if _state_time > 2.2 or distance_from_home(global_position) > leash:
				_set_state(State.REST)
		State.REST:
			if _state_time > 1.6:
				_set_state(State.PATROL)
	rotation.y = _heading
	global_position += -Vector3(sin(_heading), 0.0, cos(_heading)) * speed * delta
	global_position.y = ground_at(global_position)
	check_hit(_body.to_global(Vector3(0, 0.55, -0.4)), 0.65)
	check_hit(_body.to_global(Vector3(0, 0.55, 0.35)), 0.5)
	_animate(speed)


func _set_state(state: State) -> void:
	_state = state
	_state_time = 0.0


func _animate(speed: float) -> void:
	# Rearing up and opening the jaws is the warning.
	var rear := 0.0
	var jaw_open := 0.15
	if _state == State.WARN:
		rear = 0.35
		jaw_open = 0.7
	elif _state == State.CHARGE:
		jaw_open = 0.5 + 0.3 * sin(_time * 20.0)
	_body.rotation.x = lerpf(_body.rotation.x, rear, 0.2)
	for i in _jaws.size():
		var side := 1.0 if i == 0 else -1.0
		_jaws[i].rotation.y = side * jaw_open
	var rate := 3.0 + speed * 2.2
	for leg in _legs:
		var side: float = leg.side
		var phase := _time * rate + (PI if leg.group == 1 else 0.0)
		var amount := clampf(speed, 0.0, 1.0)
		var step := sin(phase) * 0.18 * amount
		var lift := maxf(cos(phase), 0.0) * 0.12 * amount
		var hip: Vector3 = leg.hip
		var knee := hip + Vector3(side * 0.35, 0.25 + lift, leg.reach * 0.5 + step * 0.5)
		var foot := hip + Vector3(side * 0.6, -0.45 + lift, leg.reach + step)
		CritterParts.set_rod(leg.thigh, hip, knee)
		CritterParts.set_rod(leg.shin, knee, foot)
