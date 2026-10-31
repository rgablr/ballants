class_name PlayerBall
extends RigidBody3D
## THE BALL the player controls.
##
## Movement is physics-driven: holding a direction applies a steady push, so
## the ball keeps its momentum and takes time to turn or stop (the Super
## Monkey Ball feel). On top of the real physics sit a few small cheats
## (turn assist, ground stick) that make steering feel immediate. All
## numbers come from config/physics_tuning.gd.
##
## Responsibilities:
##   - read movement input and push the ball relative to the camera
##   - detect the ground and handle jumping (with coyote time + jump buffer)
##   - notice impacts (landings, wall hits) and report them for feedback
##   - squash the ball's visual on impact (visual only; collision is a
##     perfect sphere at all times)
##   - respawn when it falls out of the world
##   - load the ball's visual model from the asset manifest
## The ant on top is purely visual and lives in ant_rider.gd.

signal jumped
signal landed
## A sudden change of velocity: strength in m/s, direction the ball was
## pushed (unit vector), and roughly where it happened.
signal impacted(strength: float, direction: Vector3, position: Vector3)

## The camera rig that decides which way "forward" is. Set in the level
## scene, or by the Level script when it spawns the player.
@export var camera_rig: Node3D:
	set(value):
		if camera_rig and camera_rig.has_signal("manually_turned") \
				and camera_rig.manually_turned.is_connected(_on_camera_manually_turned):
			camera_rig.manually_turned.disconnect(_on_camera_manually_turned)
		camera_rig = value
		if camera_rig and camera_rig.has_signal("manually_turned"):
			camera_rig.manually_turned.connect(_on_camera_manually_turned)

## Grip multiplier from the surface under the ball (1 = normal). Slick
## patches lower it; it scales both friction and the push.
var surface_grip := 1.0

var radius := 0.5

var _grounded := false
var _ground_normal := Vector3.UP
var _time_since_grounded := 999.0
var _time_since_jump_pressed := 999.0
var _spawn_transform: Transform3D
var _input_direction := Vector3.ZERO   # world-space push direction this step
var _applied_force := Vector3.ZERO     # what we pushed with this step
var _jumped_this_step := false
var _previous_velocity := Vector3.ZERO
# Seam smoothing (see Tuning.seam_smoothing): how many physics steps in a
# row the ball has been on the ground, and a short window after a jump or
# bounce pad during which upward launches are left alone.
var _grounded_steps := 0
var _launch_grace := 0.0
## How many seam pops were removed since the level started (debug overlay
## and tests read this).
var seam_pops_removed := 0

# While the player holds "back", the control direction is frozen at the
# camera angle they started with. That way the camera can swing around
# behind the reversing ball without the controls flipping mid-swing.
var _control_yaw_frozen := false
var _frozen_yaw := 0.0

# Visual squash: amount (0 = round) and the axis it flattens along.
var _squash := 0.0
var _squash_axis := Vector3.UP
var _squash_tween: Tween

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _visual_root: Node3D = $Visual


func _ready() -> void:
	add_to_group("player")
	_spawn_transform = global_transform
	radius = (_collision.shape as SphereShape3D).radius

	physics_material_override = PhysicsMaterial.new()
	_apply_tuning()
	Tuning.value_changed.connect(func(_name: String, _value): _apply_tuning())

	# Needed so _integrate_forces can see what we're touching.
	contact_monitor = true
	max_contacts_reported = 8
	# Continuous collision: the engine sweeps the ball along its path each
	# step, so at high speed it can't skip through a thin wall or floor.
	continuous_cd = true

	# The visual follows the body by hand (see _process) so it can be
	# squashed in world space without touching the collision sphere.
	_visual_root.top_level = true
	_visual_root.add_child(Assets.instantiate_model("ball"))

	# The exported camera_rig is assigned before _ready, so hook it up now.
	camera_rig = camera_rig


## Copies the values the physics engine needs from the tuning file. Called
## at startup and again whenever a value changes in the F1 panel.
func _apply_tuning() -> void:
	mass = Tuning.ball_mass
	# Rolling resistance is applied by hand in _apply_rolling_resistance so it
	# only slows horizontal motion and never shortens a jump.
	linear_damp = 0.0
	angular_damp = Tuning.spin_resistance
	physics_material_override.friction = Tuning.ball_friction * surface_grip
	physics_material_override.bounce = Tuning.ball_bounce


## Called by SlickPatch when the ball rolls onto / off a slippery surface.
func set_surface_grip(grip: float) -> void:
	surface_grip = clampf(grip, 0.0, 1.0)
	_apply_tuning()


func is_grounded() -> bool:
	return _grounded


## True during the short window after leaving the ground when a jump is
## still allowed.
func is_coyote_active() -> bool:
	return not _grounded and _time_since_grounded <= Tuning.coyote_time


## The direction the player is currently pushing, in world space (zero
## length when idle). The ant uses this to lean before the ball responds.
func get_input_direction() -> Vector3:
	return _input_direction


func _on_camera_manually_turned(yaw_delta: float) -> void:
	_frozen_yaw += yaw_delta


func _physics_process(delta: float) -> void:
	if freeze:
		return   # taken out of the physics (sinking into an ant hill)
	_time_since_grounded += delta
	_time_since_jump_pressed += delta
	if Input.is_action_just_pressed("jump"):
		_time_since_jump_pressed = 0.0

	_detect_impact(delta)
	_applied_force = Vector3.ZERO
	_jumped_this_step = false

	_apply_movement()
	_apply_rolling_resistance()
	_apply_ground_stick()
	_try_jump()

	_previous_velocity = linear_velocity
	# Falling out of the world: in a listed level that fails the run (the
	# level's FallZone normally catches it first); in the arena, respawn.
	if global_position.y < Tuning.fall_respawn_y and not Game.level_complete:
		if Levels.is_in_level():
			Levels.fail()
		else:
			respawn()


## Where the ball is for drawing purposes this frame: between the last two
## physics steps, so rendering at 120 Hz looks smooth with 60 Hz physics.
func get_render_transform() -> Transform3D:
	return get_global_transform_interpolated()


func _process(_delta: float) -> void:
	# Visual = body rotation, squashed along the impact axis in world space.
	var render := get_render_transform()
	var squash_basis := Basis.IDENTITY
	if _squash > 0.001:
		var a := _squash_axis
		var flatten := -_squash
		var bulge := _squash * 0.5
		# Scale by (1 - squash) along the axis, (1 + bulge) across it.
		squash_basis = Basis(
			Vector3(1.0 + bulge, 0, 0) + a * a.x * (flatten - bulge),
			Vector3(0, 1.0 + bulge, 0) + a * a.y * (flatten - bulge),
			Vector3(0, 0, 1.0 + bulge) + a * a.z * (flatten - bulge))
	_visual_root.global_transform = Transform3D(squash_basis * render.basis, render.origin)


func _apply_movement() -> void:
	var input: Vector2 = Controls.get_move_vector()
	if Game.level_complete:
		input = Vector2.ZERO   # in the ant hill: no climbing back out
	var velocity_h := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var speed_h := velocity_h.length()

	# With tilt steering, "back" on the stick means BRAKE (push against the
	# motion), never reverse; steering comes in as the x component.
	var brake := 0.0
	if Controls.gyro_active():
		brake = maxf(input.y, 0.0)
		input.y = minf(input.y, 0.0)
		_control_yaw_frozen = false
	else:
		var holding_back := input.y > 0.5
		if holding_back and not _control_yaw_frozen:
			_frozen_yaw = _camera_yaw()
		_control_yaw_frozen = holding_back

	var direction := _camera_relative(input)
	if brake > 0.0 and speed_h > 0.3:
		direction = (direction - velocity_h / speed_h * brake).limit_length(1.0)
	_input_direction = direction
	if direction.length_squared() < 0.0001:
		return

	var strength := Tuning.roll_acceleration * mass
	if not _grounded:
		strength *= Tuning.air_control
	else:
		strength *= surface_grip

	if speed_h > 0.5:
		var heading := velocity_h / speed_h
		var along := direction.dot(heading)
		var across := direction - heading * along
		if along < 0.0:
			# Pushing against our motion: braking help.
			strength *= Tuning.brake_multiplier
		elif speed_h >= Tuning.max_speed:
			# At top speed: drop the part of the push that would make us
			# faster, keep the part that steers.
			direction = across
			if direction.length_squared() < 0.0001:
				return
		# Turn assist: the sideways part of the push gets a boost so turns
		# begin at once, while the forward momentum is untouched.
		direction += across * Tuning.turn_assist
	_applied_force = direction * strength
	apply_central_force(_applied_force)


## A gentle drag on horizontal speed only, so the ball coasts to a stop
## when you let go. Vertical motion (jumps, falls) is untouched.
func _apply_rolling_resistance() -> void:
	if not _grounded:
		return
	var velocity_h := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var force := -velocity_h * Tuning.rolling_resistance * mass
	_applied_force += force
	apply_central_force(force)


## Pushes the ball onto the surface it's rolling on, harder the faster it
## goes, so it follows ramp crests instead of launching off them.
func _apply_ground_stick() -> void:
	if not _grounded or Tuning.ground_stick <= 0.0:
		return
	var speed_h := Vector2(linear_velocity.x, linear_velocity.z).length()
	var amount: float = clampf(speed_h / Tuning.max_speed, 0.0, 1.0)
	var force := -_ground_normal * Tuning.gravity * Tuning.ground_stick * amount * mass
	_applied_force += force
	apply_central_force(force)


func _camera_yaw() -> float:
	if camera_rig == null:
		return 0.0
	if camera_rig.has_method("get_yaw"):
		return camera_rig.get_yaw()
	return camera_rig.global_rotation.y


## Turns stick/keyboard input (x = right, y = back) into a flat world
## direction based on the camera's left/right angle (or the frozen angle
## while reversing), so we never push into the floor or the sky.
func _camera_relative(input: Vector2) -> Vector3:
	var yaw := _frozen_yaw if _control_yaw_frozen else _camera_yaw()
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var direction := right * input.x + forward * -input.y
	return direction.limit_length(1.0)


func _try_jump() -> void:
	var can_jump := _time_since_grounded <= Tuning.coyote_time
	var wants_jump := _time_since_jump_pressed <= Tuning.jump_buffer_time
	if not (can_jump and wants_jump):
		return
	_time_since_grounded = 999.0
	_time_since_jump_pressed = 999.0
	_grounded = false
	_jumped_this_step = true
	# Upward speed needed to reach jump_height, then set our vertical speed
	# to exactly that so every jump is the same height. Cancel any ground
	# stick applied this step so it can't shorten the jump.
	var launch_speed := sqrt(2.0 * Tuning.gravity * Tuning.jump_height)
	var stick_cancel := -_applied_force.y / mass * get_physics_process_delta_time()
	apply_central_impulse(Vector3.UP * (launch_speed - linear_velocity.y + stick_cancel) * mass)
	_launch_grace = 0.25
	jumped.emit()
	Sounds.jump()


## Compares this step's velocity with the last one. After removing what
## gravity and our own pushes account for, anything left is a collision.
func _detect_impact(delta: float) -> void:
	if _jumped_this_step:
		return
	var expected := _previous_velocity + Vector3.DOWN * Tuning.gravity * delta + _applied_force / mass * delta
	var surprise := linear_velocity - expected
	var strength := surprise.length()
	if strength < Tuning.impact_small:
		return
	var direction := surprise / strength
	var position := global_position - direction * radius
	impacted.emit(strength, direction, position)
	_play_squash(direction, strength)
	Effects.impact(strength, direction, position)


## Flattens the visual along the impact direction, then springs back.
func _play_squash(direction: Vector3, strength: float) -> void:
	var amount: float = Tuning.ball_squash * clampf(strength / Tuning.impact_big, 0.3, 1.0)
	_squash_axis = direction
	_squash = amount
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(self, "_squash", 0.0, Tuning.ball_squash_time) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Runs inside the physics engine each step; the only reliable place to read
## what the ball is touching.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_launch_grace = maxf(_launch_grace - state.step, 0.0)
	_smooth_seams(state)
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
	_grounded_steps = _grounded_steps + 1 if grounded else 0
	if _grounded:
		_time_since_grounded = 0.0
		if not was_grounded:
			landed.emit()
			Sounds.land(-_previous_velocity.y)


## Something (a bounce pad, a spring...) is about to throw the ball upward
## on purpose: don't treat it as a seam pop.
func allow_launch(seconds := 0.3) -> void:
	_launch_grace = maxf(_launch_grace, seconds)


## Seam pops: the ball has been rolling on one flat plane, the plane under
## it hasn't changed, yet it is suddenly moving away from it. That comes
## from the physics engine catching the hidden edge where two overlapping
## floor pieces meet. Remove the "away" part of the velocity. Rays straight
## down (under the center, and a step ahead) read the real surface; if
## either sees a different slope (a ramp starting, a crest), it's real
## geometry and nothing is changed.
func _smooth_seams(state: PhysicsDirectBodyState3D) -> void:
	if not Tuning.seam_smoothing or _grounded_steps < 3 or _launch_grace > 0.0:
		return
	var plane := _ground_normal
	var away := state.linear_velocity.dot(plane)
	if away < 0.25:
		return
	var space := state.get_space_state()
	var center := state.transform.origin
	var ahead := Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z) * state.step * 2.0
	for start in [center, center + ahead]:
		var query := PhysicsRayQueryParameters3D.create(start, start - plane * (radius + 0.3))
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return   # ground ends here: a real edge, leave it
		if (hit.normal as Vector3).dot(plane) < 0.9994:   # more than ~2 degrees off
			return
	state.linear_velocity -= plane * away
	seam_pops_removed += 1


func respawn() -> void:
	global_transform = _spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_previous_velocity = Vector3.ZERO
	_grounded_steps = 0
	reset_physics_interpolation()   # no smear from the old spot to the new
