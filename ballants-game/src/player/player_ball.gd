class_name PlayerBall
extends RigidBody3D
## THE BALL the player controls.
##
## Movement is physics-driven: holding a direction applies a steady push, so
## the ball keeps its momentum and takes time to turn or stop (the Super
## Monkey Ball feel). All numbers come from config/physics_tuning.gd.
##
## Responsibilities:
##   - read movement input and push the ball relative to the camera
##   - detect the ground and handle jumping (with coyote time + jump buffer)
##   - respawn when it falls out of the world
##   - load the ball's visual model from the asset manifest
## The ant on top is purely visual and lives in ant_rider.gd.

signal jumped
signal landed

## The camera rig that decides which way "forward" is. Set in the level scene.
@export var camera_rig: Node3D

var radius := 0.5

var _grounded := false
var _ground_normal := Vector3.UP
var _time_since_grounded := 999.0
var _time_since_jump_pressed := 999.0
var _spawn_transform: Transform3D

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _visual_root: Node3D = $Visual


func _ready() -> void:
	add_to_group("player")
	_spawn_transform = global_transform
	radius = (_collision.shape as SphereShape3D).radius

	mass = Tuning.ball_mass
	# Rolling resistance is applied by hand in _apply_rolling_resistance so it
	# only slows horizontal motion and never shortens a jump.
	linear_damp = 0.0
	angular_damp = Tuning.spin_resistance
	var material := PhysicsMaterial.new()
	material.friction = Tuning.ball_friction
	material.bounce = Tuning.ball_bounce
	physics_material_override = material

	# Needed so _integrate_forces can see what we're touching.
	contact_monitor = true
	max_contacts_reported = 8

	_visual_root.add_child(Assets.instantiate_model("ball"))


func is_grounded() -> bool:
	return _grounded


func _physics_process(delta: float) -> void:
	_time_since_grounded += delta
	_time_since_jump_pressed += delta
	if Input.is_action_just_pressed("jump"):
		_time_since_jump_pressed = 0.0

	_apply_movement()
	_apply_rolling_resistance()
	_try_jump()

	if global_position.y < Tuning.fall_respawn_y:
		respawn()


func _apply_movement() -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input == Vector2.ZERO:
		return
	var direction := _camera_relative(input)
	if direction == Vector3.ZERO:
		return

	var strength := Tuning.roll_acceleration * mass
	if not _grounded:
		strength *= Tuning.air_control

	var velocity_h := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var speed_h := velocity_h.length()
	if speed_h > 0.5:
		var along := direction.dot(velocity_h / speed_h)
		if along < 0.0:
			# Pushing against our motion: braking help.
			strength *= Tuning.brake_multiplier
		elif speed_h >= Tuning.max_speed:
			# At top speed: drop the part of the push that would make us
			# faster, keep the part that steers.
			direction -= (velocity_h / speed_h) * along
			if direction.length_squared() < 0.0001:
				return
	apply_central_force(direction * strength)


## A gentle drag on horizontal speed only, so the ball coasts to a stop
## when you let go. Vertical motion (jumps, falls) is untouched.
func _apply_rolling_resistance() -> void:
	if not _grounded:
		return
	var velocity_h := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	apply_central_force(-velocity_h * Tuning.rolling_resistance * mass)


## Turns stick/keyboard input (x = right, y = back) into a world direction
## based on where the camera is looking, flattened so we never push into the
## floor or the sky.
func _camera_relative(input: Vector2) -> Vector3:
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	if camera_rig:
		forward = -camera_rig.global_basis.z
		right = camera_rig.global_basis.x
	forward.y = 0.0
	right.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3.ZERO
	var direction := right.normalized() * input.x + forward.normalized() * -input.y
	return direction.limit_length(1.0)


func _try_jump() -> void:
	var can_jump := _time_since_grounded <= Tuning.coyote_time
	var wants_jump := _time_since_jump_pressed <= Tuning.jump_buffer_time
	if not (can_jump and wants_jump):
		return
	_time_since_grounded = 999.0
	_time_since_jump_pressed = 999.0
	_grounded = false
	# Upward speed needed to reach jump_height, then set our vertical speed
	# to exactly that so every jump is the same height.
	var launch_speed := sqrt(2.0 * Tuning.gravity * Tuning.jump_height)
	apply_central_impulse(Vector3.UP * (launch_speed - linear_velocity.y) * mass)
	jumped.emit()


## Runs inside the physics engine each step; the only reliable place to read
## what the ball is touching.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var was_grounded := _grounded
	var grounded := false
	for i in state.get_contact_count():
		var normal := state.get_contact_local_normal(i)
		if normal.y >= Tuning.ground_normal_min:
			grounded = true
			_ground_normal = normal
			break
	# A jump that just launched this step shouldn't be cancelled by a
	# lingering floor contact.
	if grounded and state.linear_velocity.y > 2.0 and not was_grounded:
		grounded = false
	_grounded = grounded
	if _grounded:
		_time_since_grounded = 0.0
		if not was_grounded:
			landed.emit()


func respawn() -> void:
	global_transform = _spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
