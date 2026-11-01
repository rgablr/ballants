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
##   - in the air it flails; after a real jump or fall it lands with a quick
##     forward somersault on top of the ball
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
var _crawl_blend := 0.0     # 0 standing .. 1 crawling, eased (for the lean)
var _teeter := 0.0
var _teeter_time := 0.0
var _lateral := 0.0         # sideways acceleration this step (m/s²), from turning

## Crawl at or above this fraction of top speed; stand up below the second.
const CRAWL_ON := 0.75
const CRAWL_OFF := 0.68
## While crawling, the lean is cut to this share so the ant runs along the
## top of the ball instead of sliding far round the front.
const CRAWL_LEAN := 0.2
## Sideways acceleration (m/s²) where teetering starts, and where it's full.
const TEETER_START := 4.0
const TEETER_FULL := 10.0
## How far the whole ant rocks over the ball at full teeter (radians).
const TEETER_ROCK := 0.42
# In the air: judged by how high the ball really is above the ground (with
# a gap between "up" and "down"), so landing bounces and bumpy ground don't
# leave the ant flailing after it has landed.
const AIR_UP := 0.5          # clearance that counts as airborne (m); the ball's
                             # little bounces after landing stay below this
const AIR_DOWN := 0.12       # clearance that counts as landed again (m)
const TUMBLE_MIN_AIR := 0.35 # seconds in the air before landing earns a somersault
const TUMBLE_TIME := 0.45
const TUMBLE_HOP := 0.22     # how high it springs up during the roll (m)
var _in_air := false
var _air_time := 0.0
var _tumble_time := -1.0     # < 0 = not somersaulting
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
	_update_air(delta)
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
	_crawl_blend = move_toward(_crawl_blend, 1.0 if _crawling else 0.0, delta * 3.0)
	var lean_amount := _lean.length() * lerpf(1.0, CRAWL_LEAN, _crawl_blend)
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
		up = up.rotated(forward_axis, sin(_teeter_time * 7.0) * TEETER_ROCK * _teeter)

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
	if _visual.has_method("set_airborne"):
		_visual.set_airborne(_in_air and _tumble_time < 0.0)
	_somersault(delta)


## Height of the gap under the ball (m); large if there's no ground below.
func _clearance() -> float:
	var center := ball.global_position
	var query := PhysicsRayQueryParameters3D.create(center, center + Vector3.DOWN * 4.0)
	query.exclude = [ball.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 4.0
	return center.distance_to(hit.position) - _ball_radius()


func _update_air(delta: float) -> void:
	if _fallen or ball.freeze:
		_in_air = false
		_air_time = 0.0
		return
	var grounded: bool = ball.is_grounded() if ball.has_method("is_grounded") else true
	var gap := _clearance()
	if _in_air:
		_air_time += delta
		if grounded or gap < AIR_DOWN:
			_in_air = false
			if _air_time >= TUMBLE_MIN_AIR:
				_tumble_time = 0.0
			_air_time = 0.0
	elif not grounded and gap > AIR_UP:
		_in_air = true
		_air_time = 0.0
		_stop_somersault()


## The landing somersault: one quick forward roll around the ant's middle
## with a little spring up, ending standing again.
func _somersault(delta: float) -> void:
	if _tumble_time < 0.0:
		return
	_tumble_time += delta
	var t := clampf(_tumble_time / TUMBLE_TIME, 0.0, 1.0)
	var angle := -TAU * smoothstep(0.0, 1.0, t)       # negative = head goes forward
	var middle := Vector3(0.0, 0.2, 0.0) * model_scale
	var lift := Vector3.UP * sin(t * PI) * TUMBLE_HOP
	_visual.rotation.x = angle
	_visual.position = middle - Basis(Vector3.RIGHT, angle) * middle + lift
	if t >= 1.0:
		_stop_somersault()


## Ends the somersault (finished, or cut short by a jump) and puts the ant
## squarely back on the ball. Cutting it short without this left the ant
## floating above the ball, mid-hop.
func _stop_somersault() -> void:
	_tumble_time = -1.0
	_visual.rotation.x = 0.0
	_visual.position = Vector3.ZERO


func _on_knocked_off(direction: Vector3) -> void:
	_stop_somersault()
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
	_in_air = false
	_stop_somersault()
	_lean = Vector3.ZERO
	_lean_velocity = Vector3.ZERO


## Squash on landing, then spring back.
func _on_landed() -> void:
	var squash := Tuning.ant_land_squash
	_play_bounce(Vector3(1.0 + squash * 0.6, 1.0 - squash, 1.0 + squash * 0.6))


## A smaller stretch on take-off.
func _on_jumped() -> void:
	_in_air = true   # a jump is airborne at once, before the gap opens up
	_air_time = 0.0
	_stop_somersault()
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
