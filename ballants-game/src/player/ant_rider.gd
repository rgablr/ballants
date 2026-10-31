extends Node3D
## ANT RIDER -- keeps the ant visual standing on top of the ball.
##
## The ant is NOT part of the physics. It is a picture that follows the ball:
##   - it stands on the ball's surface, sliding away from the top when the
##     ball speeds up or slows down, so it looks like it's balancing
##   - it turns to face the direction of travel
##   - it asks the model to animate its legs faster the faster the ball rolls
##
## This node is marked "top level" so it ignores the ball's spinning and
## positions itself in world space every frame.

## The ball to ride. Set in player.tscn.
@export var ball: RigidBody3D
## Scale applied to the ant model, in case the model is the wrong size.
@export var model_scale := 1.0

var _visual: Node3D
var _facing := Vector3.FORWARD
var _lean := Vector3.ZERO       # smoothed horizontal acceleration
var _previous_velocity := Vector3.ZERO


func _ready() -> void:
	top_level = true
	_visual = Assets.instantiate_model("ant")
	_visual.scale = Vector3.ONE * model_scale
	add_child(_visual)


func _physics_process(delta: float) -> void:
	if ball == null:
		return
	var velocity := ball.linear_velocity
	var acceleration := (velocity - _previous_velocity) / delta
	_previous_velocity = velocity
	var acceleration_h := Vector3(acceleration.x, 0.0, acceleration.z)
	_lean = _lean.lerp(acceleration_h, 1.0 - exp(-delta * Tuning.ant_lean_smoothing))


func _process(delta: float) -> void:
	if ball == null:
		return
	var ball_radius: float = ball.radius if "radius" in ball else 0.5

	# Which way is "up" for the ant: straight up, tilted away from the
	# direction the ball is accelerating (it gets left behind, then catches up).
	var up := Vector3.UP
	var lean_amount: float = clamp(_lean.length() * Tuning.ant_lean_per_accel, 0.0, Tuning.ant_max_lean)
	if lean_amount > 0.001:
		var axis := _lean.normalized().cross(Vector3.UP).normalized()
		up = Vector3.UP.rotated(axis, lean_amount)

	# Face the direction of travel, smoothly.
	var velocity_h := Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z)
	var speed := velocity_h.length()
	if speed > 0.4:
		var blend := 1.0 - exp(-delta * Tuning.ant_turn_speed)
		_facing = _facing.lerp(velocity_h / speed, blend).normalized()

	# Build the ant's orientation from "up" and "facing", keeping them at right
	# angles so the model isn't skewed.
	var forward := _facing - up * _facing.dot(up)
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	global_transform = Transform3D(Basis.looking_at(forward, up), ball.global_position + up * ball_radius)

	if _visual.has_method("set_walk_speed"):
		_visual.set_walk_speed(speed)
