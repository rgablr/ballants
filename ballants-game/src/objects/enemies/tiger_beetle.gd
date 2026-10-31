class_name TigerBeetle
extends Enemy
## TIGER BEETLE -- a shiny metallic-green sprinter on long copper legs with
## huge eyes, about 1.1 m long. Real tiger beetles run so fast they lose
## sight of their prey and have to stop to look again; this one does the
## same: CROUCH (your warning) -> SPRINT a short burst at where you are ->
## STOP and look -> again, for as long as you're in its patch. Keep moving
## and change direction while it's stopped.

@export var sprint_speed := 9.0
@export var sprint_time := 0.55
@export var crouch_time := 0.4
@export var look_time := 0.6
@export var wander_speed := 0.8

enum State { WANDER, CROUCH, SPRINT, LOOK }

var _state := State.WANDER
var _state_time := 0.0
var _heading := 0.0
var _body: Node3D
var _legs: Array[Dictionary] = []


func enemy_name() -> String:
	return "tiger beetle"


func _ready() -> void:
	super._ready()
	sight = maxf(sight, 11.0)
	_heading = randf() * TAU
	_build()


func _build() -> void:
	var green := CritterParts.material(Color(0.1, 0.62, 0.38), 0.12)
	var copper := CritterParts.material(Color(0.72, 0.42, 0.2), 0.3)
	var eye := CritterParts.material(Color(0.05, 0.08, 0.06), 0.1)
	var cream := CritterParts.material(Color(0.95, 0.9, 0.7), 0.5)
	_body = Node3D.new()
	add_child(_body)
	CritterParts.sphere(_body, Vector3(0, 0.62, 0.2), 0.32, Vector3(0.95, 0.55, 1.45), green)
	for z in [0.05, 0.3]:   # cream spots on the wing cases
		for side in [1.0, -1.0]:
			CritterParts.sphere(_body, Vector3(side * 0.18, 0.75, z), 0.05, Vector3(1, 0.4, 1), cream)
	CritterParts.sphere(_body, Vector3(0, 0.62, -0.28), 0.17, Vector3(1.0, 0.7, 1.0), green)
	CritterParts.sphere(_body, Vector3(0, 0.62, -0.5), 0.17, Vector3(1.3, 0.75, 0.85), green)
	for side in [1.0, -1.0]:
		CritterParts.sphere(_body, Vector3(side * 0.17, 0.68, -0.53), 0.09, Vector3.ONE, eye)   # big eyes
		CritterParts.rod(_body, Vector3(side * 0.06, 0.58, -0.65), Vector3(side * 0.02, 0.55, -0.82), 0.03, cream)  # jaws
		CritterParts.rod(_body, Vector3(side * 0.12, 0.72, -0.6), Vector3(side * 0.35, 0.95, -0.95), 0.012, copper)
	for i in 3:
		for side in [1.0, -1.0]:
			var hip := Vector3(side * 0.16, 0.55, -0.3 + i * 0.22)
			var thigh := CritterParts.rod(_body, hip, hip + Vector3.UP * 0.1, 0.025, copper)
			var shin := CritterParts.rod(_body, hip, hip + Vector3.DOWN * 0.1, 0.02, copper)
			_legs.append({"thigh": thigh, "shin": shin, "hip": hip, "side": side,
					"reach": -0.4 + i * 0.4, "group": (i + (0 if side > 0 else 1)) % 2})


func _physics_process(delta: float) -> void:
	_time += delta
	_state_time += delta
	var ball := target_ball()
	var speed := 0.0
	var sees := can_see(ball, global_position)
	match _state:
		State.WANDER:
			speed = wander_speed
			_heading += sin(_time * 0.7) * delta
			if distance_from_home(global_position) > leash * 0.5:
				_heading = lerp_angle(_heading, yaw_toward(global_position, _home), delta * 2.0)
			if sees:
				_set_state(State.CROUCH)
		State.CROUCH:
			if ball:
				_heading = lerp_angle(_heading, yaw_toward(global_position, ball.global_position), delta * 10.0)
			if _state_time >= crouch_time:
				_set_state(State.SPRINT)
		State.SPRINT:
			speed = sprint_speed
			if _state_time >= sprint_time or distance_from_home(global_position) > leash:
				_set_state(State.LOOK)
		State.LOOK:
			if _state_time >= look_time:
				_set_state(State.CROUCH if sees else State.WANDER)
	rotation.y = _heading
	global_position += -Vector3(sin(_heading), 0.0, cos(_heading)) * speed * delta
	global_position.y = ground_at(global_position)
	check_hit(_body.to_global(Vector3(0, 0.6, -0.25)), 0.55)
	_animate(speed)


func _set_state(state: State) -> void:
	_state = state
	_state_time = 0.0


func _animate(speed: float) -> void:
	var crouch := 0.18 if _state == State.CROUCH else 0.0
	_body.position.y = lerpf(_body.position.y, -crouch, 0.3)
	_body.rotation.x = lerpf(_body.rotation.x, -0.12 if _state == State.CROUCH else 0.0, 0.3)
	var rate := 4.0 + speed * 2.0
	for leg in _legs:
		var side: float = leg.side
		var phase := _time * rate + (PI if leg.group == 1 else 0.0)
		var amount := clampf(speed, 0.0, 1.0)
		var step := sin(phase) * 0.2 * amount
		var lift := maxf(cos(phase), 0.0) * 0.12 * amount
		var hip: Vector3 = leg.hip
		var knee := hip + Vector3(side * 0.3, 0.2 + lift - crouch * 0.5, leg.reach * 0.5 + step * 0.5)
		var foot := hip + Vector3(side * 0.55, -0.55 + lift + crouch, leg.reach + step)
		CritterParts.set_rod(leg.thigh, hip, knee)
		CritterParts.set_rod(leg.shin, knee, foot)
