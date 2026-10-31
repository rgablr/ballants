extends Node3D
## ORBIT CAMERA -- third-person camera that follows a target and can be
## rotated around it with the mouse or the right stick.
##
## Structure: this node (the "rig") sits at the target and holds the rotation.
## A SpringArm3D child pushes the actual Camera3D backwards, and pulls it in
## automatically if a wall would otherwise block the view.
##
## The player reads this rig's facing to decide which way "forward" is, so
## turning the camera turns the controls too.

## What to follow. Set in the level scene.
@export var target: Node3D

var _yaw := 0.0     # left/right rotation, radians
var _pitch := 0.0   # up/down rotation, radians (positive looks down)

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	_pitch = deg_to_rad(Tuning.camera_pitch_default)
	_arm.spring_length = Tuning.camera_distance
	_camera.fov = Tuning.camera_fov
	if target:
		global_position = _focus_point()
		if target is CollisionObject3D:
			# Don't let the arm collide with the thing we're looking at.
			_arm.add_excluded_object((target as CollisionObject3D).get_rid())
	_apply_rotation()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var invert := -1.0 if Tuning.invert_camera_y else 1.0
		_yaw -= motion.relative.x * Tuning.mouse_sensitivity
		_pitch += motion.relative.y * Tuning.mouse_sensitivity * invert
		_apply_rotation()


func _process(delta: float) -> void:
	var stick := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if stick != Vector2.ZERO:
		var invert := -1.0 if Tuning.invert_camera_y else 1.0
		_yaw -= stick.x * Tuning.stick_sensitivity * delta
		_pitch += stick.y * Tuning.stick_sensitivity * delta * invert
		_apply_rotation()
	if target:
		var blend := 1.0 - exp(-delta * Tuning.camera_follow_speed)
		global_position = global_position.lerp(_focus_point(), blend)


func _focus_point() -> Vector3:
	return target.global_position + Vector3.UP * Tuning.camera_height_offset


func _apply_rotation() -> void:
	_pitch = clamp(_pitch, deg_to_rad(Tuning.camera_pitch_min), deg_to_rad(Tuning.camera_pitch_max))
	rotation = Vector3(-_pitch, _yaw, 0.0)
