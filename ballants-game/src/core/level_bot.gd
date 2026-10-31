class_name LevelBot
extends Node
## LEVEL BOT -- drives the ball through a list of waypoints by pressing the
## same input actions a player would, so a level can be checked for
## "completable" without a human. Used by:  godot -- --drive=<file.json>
##
## The JSON file:
## {
##   "level": 1,                 1/2/3 = that level, 0 = test arena
##   "timeout": 90,              seconds before giving up
##   "speed": 9,                 default target speed (m/s)
##   "waypoints": [
##     [0, 0, -10],              a point: [x, y, z]
##     {"pos": [0, 0, -20], "speed": 5},          slow down for this one
##     {"pos": [4, 0, -30], "jump": true},        press jump on reaching it
##     {"pos": [4, 2, -36], "reach": 2.5}         how close counts (m)
##   ]
## }
## The run PASSES if the goal is reached before the timeout and the ball
## never fell out. It prints the time taken, like the autotest.

signal finished(passed: bool, summary: String)

const DEFAULT_REACH := 1.5

var _waypoints: Array = []
var _index := 0
var _default_speed := 9.0
var _timeout := 90.0
var _elapsed := 0.0
var _falls := 0
var _done := false
var _reached_goal := false
var _goal_time := 0.0


func start(config: Dictionary) -> void:
	_waypoints = config.get("waypoints", [])
	_default_speed = float(config.get("speed", 9.0))
	_timeout = float(config.get("timeout", 90.0))
	Levels.run_finished.connect(func(t: float):
		_reached_goal = true
		_goal_time = t)
	Levels.run_failed.connect(func(): _falls += 1)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _reached_goal:
		_finish(_falls == 0, "goal reached in %s with %d falls" % [Levels.format_time(_goal_time), _falls])
		return
	if _elapsed > _timeout:
		_finish(false, "timed out after %.0f s at waypoint %d of %d (%d falls)"
				% [_timeout, _index, _waypoints.size(), _falls])
		return
	var player := get_tree().get_first_node_in_group("player") as PlayerBall
	if player == null or _index >= _waypoints.size():
		_release_all()
		return
	_drive(player)


func _drive(player: PlayerBall) -> void:
	var entry = _waypoints[_index]
	var target := _position_of(entry)
	var reach := float(entry.get("reach", DEFAULT_REACH)) if entry is Dictionary else DEFAULT_REACH
	var speed := float(entry.get("speed", _default_speed)) if entry is Dictionary else _default_speed
	var wants_jump: bool = entry is Dictionary and entry.get("jump", false)

	var to_target := target - player.global_position
	to_target.y = 0.0
	if to_target.length() <= reach:
		if wants_jump:
			Input.action_press("jump")
			await get_tree().physics_frame
			Input.action_release("jump")
		_index += 1
		return

	# "Seek": push toward the velocity we want, which also brakes and
	# corrects drift.
	var velocity := player.linear_velocity
	velocity.y = 0.0
	var desired := to_target.normalized() * speed
	var push := desired - velocity
	if push.length() < 0.3:
		_release_all()
		return
	push = push.normalized()

	# Express the push in the same control frame the player uses.
	var yaw: float = player._frozen_yaw if player._control_yaw_frozen else player._camera_yaw()
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var f := push.dot(forward)
	var r := push.dot(right)
	_press("move_forward", maxf(f, 0.0))
	_press("move_back", maxf(-f, 0.0))
	_press("move_right", maxf(r, 0.0))
	_press("move_left", maxf(-r, 0.0))


func _position_of(entry) -> Vector3:
	var p = entry.get("pos") if entry is Dictionary else entry
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _press(action: String, strength: float) -> void:
	if strength > 0.02:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	else:
		Input.action_release(action)


func _release_all() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump"]:
		Input.action_release(action)


func _finish(passed: bool, summary: String) -> void:
	_done = true
	_release_all()
	finished.emit(passed, summary)
