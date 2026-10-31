class_name Enemy
extends Node3D
## ENEMY -- what every ant predator shares. Touch one and the ant is
## knocked off the ball (PlayerBall.knock_off): the level restarts, or in
## the title area you go back to the spawn.
##
## Fairness rules every enemy follows:
##   - it has a HOME and never chases farther than leash meters from it,
##     so you can always get away by leaving its patch
##   - it only notices you within sight meters
##   - before it attacks it WARNS you (rears up, crouches, hovers and aims)
##     for a moment you can react to
##   - after an attack it rests, so it can't hit you twice in a row
##
## They're built from shapes in code, like the friendly bugs, using
## CritterParts. No collision of their own: the hit is a distance check
## against the ball, so it is exact and can't snag on anything.

## How far from home it will chase before giving up (m).
@export var leash := 9.0
## How close the ball must be before it notices (m).
@export var sight := 8.0

const BALL_RADIUS := 0.5

## What the death message calls this enemy ("A ground beetle attacked you!").
func enemy_name() -> String:
	return "bug"

var _home := Vector3.ZERO
var _time := 0.0


func _ready() -> void:
	_home = global_position
	_time = randf() * 10.0


## The player's ball if it can be attacked right now (not already knocked
## off, not sinking into a hill, not in the middle of a level change).
func target_ball() -> PlayerBall:
	var ball := CritterParts.find_player(self) as PlayerBall
	if ball == null or ball.knocked or ball.freeze or Game.level_complete:
		return null
	return ball


## True if the ball is within sight of `from` and inside this enemy's patch.
func can_see(ball: PlayerBall, from: Vector3) -> bool:
	if ball == null:
		return false
	var flat := Vector2(ball.global_position.x - from.x, ball.global_position.z - from.z)
	var from_home := Vector2(ball.global_position.x - _home.x, ball.global_position.z - _home.z)
	return flat.length() < sight and from_home.length() < leash + sight * 0.5


## Knocks the ant off if the ball is touching a sphere of `radius` at
## `point`. Returns true on a hit.
func check_hit(point: Vector3, radius: float) -> bool:
	var ball := target_ball()
	if ball == null:
		return false
	if ball.global_position.distance_to(point) > radius + BALL_RADIUS:
		return false
	ball.knock_off(ball.global_position - point, enemy_name())
	return true


## Height of the ground under a point, ignoring the ball.
func ground_at(point: Vector3) -> float:
	var ball := CritterParts.find_player(self)
	var exclude: Array[RID] = []
	if ball:
		exclude.append(ball.get_rid())
	return CritterParts.ground_height(self, point, exclude)


## Yaw that faces from `from` toward `to` (Godot forward is -Z).
static func yaw_toward(from: Vector3, to: Vector3) -> float:
	return atan2(-(to.x - from.x), -(to.z - from.z))


func distance_from_home(point: Vector3) -> float:
	return Vector2(point.x - _home.x, point.z - _home.z).length()
