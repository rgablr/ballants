@tool
class_name FallZone
extends Area3D
## FALL ZONE -- an invisible box below the level. If the ball enters it,
## the run fails and the level restarts. Every level needs at least one
## (the Level script adds a huge one at y = -10 if you forget). Smaller
## ones can mark puddles, pits, and so on.

@export var size := Vector3(400.0, 6.0, 400.0):
	set(value):
		size = value
		if _shape:
			(_shape.shape as BoxShape3D).size = size

var _shape: CollisionShape3D


func _ready() -> void:
	_shape = CollisionShape3D.new()
	_shape.shape = BoxShape3D.new()
	(_shape.shape as BoxShape3D).size = size
	add_child(_shape)
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerBall:
		if Levels.is_in_level():
			Levels.fail()
		else:
			(body as PlayerBall).respawn()
