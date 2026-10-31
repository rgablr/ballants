extends Node3D
## ANT RIDER -- keeps the ant visual standing on top of the ball.
##
## The ant is NOT part of the physics. It is a picture that follows the ball
## and is the main way the player READS momentum:
##   - it leans toward where you're pushing the instant you push (intent)
##   - it is thrown against sudden speed-ups, braking and turns (momentum),
##     on a springy lean that wobbles before it settles
##   - it turns to face the direction of travel
##   - it asks the model to animate its legs faster the faster the ball rolls
##   - at 75% of top speed it tells the model to drop onto all six legs and
##     crawl; it stands back up below about 68% (the gap stops flickering)
##   - in sharp turns it sways and windmills like it's about to fall off
##   - it squashes on landing and stretches on take-off
##   - when an enemy knocks it off, it tumbles off the ball in an arc and
##     lands on its back, legs kicking, until the respawn puts it back
##
## This node is marked "top level" so it ignores the ball's spinning and
## positions itself in world space every frame.

## The ball to ride. Set in player.tscn.
@export var ball: RigidBody3D
## Scale applied to the ant model, in case the model is the wrong size.
@export var model_scale := 1.0

var _visual: Node3D
var _facing := Vector3.FORWARD
var _lean := Vector3.ZERO            # current lean, as a horizontal vector (length = radians)
var _lean_velocity := Vector3.ZERO   # spring velocity of the lean
var _previous_velocity := Vector3.ZERO
var _bounce_tween: Tween
var _crawling := false
var _teeter := 0.0
var _teeter_time := 0.0
var _lateral := 0.0         # sideways acceleration this step (m/s²), from turning

## Crawl at or above this fraction of top speed; stand up below the second.
const CRAWL_ON := 0.75
const CRAWL_OFF := 0.68
## Sideways acceleration (m/s²) where teetering starts, and where it's full.
const TEETER_START := 7.0
const TEETER_FULL := 16.0
# Knocked off: the tumble from where the ant was to where it lands.
var _fallen := false
var _fall_time := 0.0
var _fall_from := Vector3.ZERO
var _fall_to := Vector3.ZERO
var _fall_axis := Vector3.RIGHT
var _fall_basis := Basis()
const FALL_DURATION := 0.8


func _ready() -> void:
	top_level = true
	_visual = Assets.instantiate_model("ant")
	_visual.scale = Vector3.ONE * model_scale
	add_child(_visual)
	# The player's chosen colors (customize menu), kept up to date.
	Cosmetics.apply_to_ant(_visual)
	Cosmetics.changed.connect(func(): Cosmetics.apply_to_ant(_visual))
	if _visual.has_method("set_ball_radius"):
		_visual.set_ball_radius(_ball_radius() / model_scale)
	if ball:
		if ball.has_signal("landed"):
			ball.landed.connect(_on_landed)
		if ball.has_signal("jumped"):
			ball.jumped.connect(_on_jumped)
		if ball.has_signal("knocked_off"):
			ball.knocked_off.connect(_on_knocked_off)
		if ball.has_signal("respawned"):
			ball.respawned.connect(_on_respawned)


func _ball_radius() -> float:
	return ball.radius if ball and "radius" in ball else 0.5


func _physics_process(delta: float) -> void:
	if ball == null:
		return
	var velocity := ball.linear_velocity
	var acceleration := (velocity - _previous_velocity) / delta
	_previous_velocity = velocity
	var acceleration_h := Vector3(acceleration.x, 0.0, acceleration.z)
	# How hard we're turning: acceleration across the direction of travel.
	var velocity_h := Vector3(velocity.x, 0.0, velocity.z)
	if velocity_h.length() > 2.0:
		var along := velocity_h.normalized()
		_lateral = (acceleration_h - along * acceleration_h.dot(along)).length()
	else:
		_lateral = 0.0

	# Where the lean WANTS to be: against the acceleration (thrown back when
	# speeding up, forward when braking, outward in turns), plus a lean
	# toward the direction being pushed.
	var target := -acceleration_h * Tuning.ant_lean_per_accel
	if ball.has_method("get_input_direction"):
		target += ball.get_input_direction() * Tuning.ant_input_lean
	target = target.limit_length(Tuning.ant_max_lean)

	# Spring toward the target. Under-damped on purpose so it wobbles.
	var stiffness: float = Tuning.ant_lean_stiffness
	var damping: float = Tuning.ant_lean_damping
	_lean_velocity += ((target - _lean) * stiffness - _lean_velocity * damping) * delta
	_lean += _lean_velocity * delta
	_lean = _lean.limit_length(Tuning.ant_max_lean)


func _process(delta: float) -> void:
	if ball == null:
		return
	if _fallen:
		_tumble(delta)
		return

	# Which way is "up" for the ant: straight up, tilted in the lean direction.
	var up := Vector3.UP
	var lean_amount := _lean.length()
	if lean_amount > 0.001:
		var axis := Vector3.UP.cross(_lean / lean_amount).normalized()
		up = Vector3.UP.rotated(axis, lean_amount)

	# Face the direction of travel, smoothly.
	var velocity_h := Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z)
	var speed := velocity_h.length()
	if speed > 0.4:
		var blend := 1.0 - exp(-delta * Tuning.ant_turn_speed)
		_facing = _facing.lerp(velocity_h / speed, blend).normalized()

	# Teetering: the whole ant rocks side to side over the ball.
	_teeter_time += delta
	if _teeter > 0.001:
		var forward_axis := Vector3(_facing.x, 0.0, _facing.z).normalized()
		up = up.rotated(forward_axis, sin(_teeter_time * 7.0) * 0.28 * _teeter)

	# Build the ant's orientation from "up" and "facing", keeping them at right
	# angles so the model isn't skewed.
	var forward := _facing - up * _facing.dot(up)
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var ball_center: Vector3 = ball.get_render_transform().origin if ball.has_method("get_render_transform") else ball.global_position
	global_transform = Transform3D(Basis.looking_at(forward, up), ball_center + up * _ball_radius())

	if _visual.has_method("set_walk_speed"):
		_visual.set_walk_speed(speed)
	# Crawl at high speed (with a gap so it doesn't flicker at the edge).
	var fraction := speed / maxf(Tuning.max_speed, 0.1)
	if fraction >= CRAWL_ON:
		_crawling = true
	elif fraction < CRAWL_OFF:
		_crawling = false
	if _visual.has_method("set_crawl"):
		_visual.set_crawl(1.0 if _crawling else 0.0)
	# Teeter in sharp turns: comes on quickly, fades slowly.
	var want := clampf((_lateral - TEETER_START) / (TEETER_FULL - TEETER_START), 0.0, 1.0)
	if ball.has_method("is_grounded") and not ball.is_grounded():
		want = 0.0
	_teeter = move_toward(_teeter, want, delta * (6.0 if want > _teeter else 1.5))
	if _visual.has_method("set_teeter"):
		_visual.set_teeter(_teeter)
	if _visual.has_method("set_airborne") and ball.has_method("is_grounded"):
		_visual.set_airborne(not ball.is_grounded() and not ball.is_coyote_active())


func _on_knocked_off(direction: Vector3) -> void:
	_fallen = true
	_fall_time = 0.0
	_fall_from = global_position
	_fall_basis = global_transform.basis
	_fall_axis = Vector3.UP.cross(direction).normalized()
	if _fall_axis.length() < 0.5:
		_fall_axis = Vector3.RIGHT
	# Lands about 2.8 m away, on whatever ground is there.
	var landing := _fall_from + direction * 2.8
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(landing + Vector3.UP * 3.0, landing + Vector3.DOWN * 20.0)
	query.exclude = [ball.get_rid()]
	var hit := space.intersect_ray(query)
	landing.y = (hit.position as Vector3).y if not hit.is_empty() else _fall_from.y - 1.0
	_fall_to = landing + Vector3.UP * 0.45   # upside down, its feet point up
	if _bounce_tween:
		_bounce_tween.kill()
	_visual.scale = Vector3.ONE * model_scale


## The arc off the ball, tumbling head over heels, then lying on its back
## with legs kicking.
func _tumble(delta: float) -> void:
	_fall_time += delta
	var t := clampf(_fall_time / FALL_DURATION, 0.0, 1.0)
	var pos := _fall_from.lerp(_fall_to, t) + Vector3.UP * sin(t * PI) * 1.6
	var spin := Basis(_fall_axis, lerpf(0.0, PI * 3.0, t))   # one and a half flips
	global_transform = Transform3D(spin * _fall_basis, pos)
	if _visual.has_method("set_walk_speed"):
		_visual.set_walk_speed(6.0 if t >= 1.0 else 0.0)   # legs kicking in the air
	if _visual.has_method("set_airborne"):
		_visual.set_airborne(t < 1.0)


func _on_respawned() -> void:
	_fallen = false
	_lean = Vector3.ZERO
	_lean_velocity = Vector3.ZERO


## Squash on landing, then spring back.
func _on_landed() -> void:
	var squash := Tuning.ant_land_squash
	_play_bounce(Vector3(1.0 + squash * 0.6, 1.0 - squash, 1.0 + squash * 0.6))


## A smaller stretch on take-off.
func _on_jumped() -> void:
	var stretch := Tuning.ant_land_squash * 0.5
	_play_bounce(Vector3(1.0 - stretch * 0.5, 1.0 + stretch, 1.0 - stretch * 0.5))


func _play_bounce(shape: Vector3) -> void:
	if _bounce_tween:
		_bounce_tween.kill()
	var base := Vector3.ONE * model_scale
	_visual.scale = base * shape
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(_visual, "scale", base, Tuning.ant_land_bounce_time) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
