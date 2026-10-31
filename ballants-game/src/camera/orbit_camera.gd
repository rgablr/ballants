extends Node3D
## ORBIT CAMERA -- third-person camera that follows a target, swings around
## behind the direction of travel by itself, and can be looked around with
## the mouse or the right stick.
##
## Structure: this node (the "rig") sits at the target and holds the rotation.
## A SpringArm3D child pushes the actual Camera3D backwards, and pulls it in
## automatically if a wall would otherwise block the view.
##
## Auto-follow: when the target is moving and the player hasn't touched the
## camera for Tuning.camera_look_hold_time seconds, the rig eases its yaw
## toward the direction of travel and its pitch back to the default.
##
## The player reads this rig's yaw to decide which way "forward" is, so
## turning the camera turns the controls too.

## Fired when the PLAYER turns the camera (mouse/stick), not when it swings
## by itself. The player uses this to keep its "frozen" control direction in
## step while reversing.
signal manually_turned(yaw_delta: float)

## What to follow. Set in the level scene.
@export var target: Node3D

var _yaw := 0.0     # left/right rotation, radians
var _pitch := 0.0   # up/down rotation, radians (positive looks down)
var _seconds_since_manual := 999.0
var _shake := 0.0   # current screen-shake strength, meters
var _fov_current := 70.0

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	add_to_group("camera_rig")
	_pitch = deg_to_rad(Tuning.camera_pitch_default)
	_arm.spring_length = Tuning.camera_distance
	_fov_current = Tuning.camera_fov
	_camera.fov = _fov_current
	if target:
		global_position = _focus_point()
		if target is CollisionObject3D:
			# Don't let the arm collide with the thing we're looking at.
			_arm.add_excluded_object((target as CollisionObject3D).get_rid())
	_apply_rotation()


## The rig's current left/right angle, in radians.
func get_yaw() -> float:
	return _yaw


## Points the camera in a direction right away (used by dev tools).
func aim(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch
	_seconds_since_manual = 0.0
	_apply_rotation()
	if target:
		global_position = _focus_point()


## Kicks off a screen shake of the given size (meters). Decays on its own.
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var invert := -1.0 if Tuning.invert_camera_y else 1.0
		_turn_manually(-motion.relative.x * Tuning.mouse_sensitivity,
				motion.relative.y * Tuning.mouse_sensitivity * invert)


func _process(delta: float) -> void:
	_seconds_since_manual += delta
	# Cheap to re-apply every frame, and it makes the F1 panel's changes live.
	_arm.spring_length = Tuning.camera_distance
	_update_fov(delta)
	_update_shake(delta)

	var stick := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if stick != Vector2.ZERO:
		var invert := -1.0 if Tuning.invert_camera_y else 1.0
		_turn_manually(-stick.x * Tuning.stick_sensitivity * delta,
				stick.y * Tuning.stick_sensitivity * delta * invert)

	_auto_follow(delta)

	# Once the ball drops into the ant hill the camera holds still, so the
	# ball visibly disappears down the hole instead of the camera following
	# it into the dirt.
	if target and not Game.level_complete:
		var blend := 1.0 - exp(-delta * Tuning.camera_follow_speed)
		global_position = global_position.lerp(_focus_point(), blend)


func _turn_manually(yaw_delta: float, pitch_delta: float) -> void:
	_yaw += yaw_delta
	_pitch += pitch_delta
	_seconds_since_manual = 0.0
	_apply_rotation()
	manually_turned.emit(yaw_delta)


## Eases the camera behind the direction the target is moving.
func _auto_follow(delta: float) -> void:
	if not Tuning.camera_auto_follow or target is not RigidBody3D:
		return
	if _seconds_since_manual < Tuning.camera_look_hold_time:
		return
	var velocity: Vector3 = (target as RigidBody3D).linear_velocity
	velocity.y = 0.0
	if velocity.length() < Tuning.camera_auto_follow_min_speed:
		return
	# The yaw at which the rig's forward (-Z) points along the velocity.
	var desired_yaw := atan2(-velocity.x, -velocity.z)
	var blend := 1.0 - exp(-delta * Tuning.camera_auto_follow_speed)
	_yaw = lerp_angle(_yaw, desired_yaw, blend)
	_pitch = lerp(_pitch, deg_to_rad(Tuning.camera_pitch_default), blend)
	_apply_rotation()


## Field of view widens with speed so going fast looks fast.
func _update_fov(delta: float) -> void:
	var target_fov: float = Tuning.camera_fov
	if target is RigidBody3D:
		var v: Vector3 = (target as RigidBody3D).linear_velocity
		var speed_fraction: float = clampf(Vector2(v.x, v.z).length() / Tuning.max_speed, 0.0, 1.0)
		target_fov += Tuning.camera_fov_speed_boost * speed_fraction
	_fov_current = lerpf(_fov_current, target_fov, 1.0 - exp(-delta * 6.0))
	_camera.fov = _fov_current


## Random camera offset that dies away, for impacts.
func _update_shake(delta: float) -> void:
	if _shake < 0.001:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		return
	_camera.h_offset = randf_range(-_shake, _shake)
	_camera.v_offset = randf_range(-_shake, _shake)
	_shake *= exp(-delta * Tuning.shake_decay)


func _focus_point() -> Vector3:
	var center: Vector3 = target.get_render_transform().origin if target.has_method("get_render_transform") else target.global_position
	return center + Vector3.UP * Tuning.camera_height_offset


func _apply_rotation() -> void:
	_pitch = clamp(_pitch, deg_to_rad(Tuning.camera_pitch_min), deg_to_rad(Tuning.camera_pitch_max))
	rotation = Vector3(-_pitch, _yaw, 0.0)
