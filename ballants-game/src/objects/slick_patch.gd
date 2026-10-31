@tool
class_name SlickPatch
extends Area3D
## SLICK PATCH -- a zone where the ball has less grip (a wet leaf, ice).
## While the ball is inside, its friction and its push are both multiplied
## by "grip", so it slides and steers lazily. Add a mesh child for the
## look; the patch itself is invisible.

## 1 = normal ground, 0.2 = very slippery.
@export var grip := 0.2
## The zone's box size. Keep it a bit taller than the ball's radius so the
## ball's center is inside while it rolls over the patch.
@export var size := Vector3(3.0, 1.2, 3.0):
	set(value):
		size = value
		if _shape:
			(_shape.shape as BoxShape3D).size = size
			_shape.position.y = size.y * 0.5

var _shape: CollisionShape3D


func _ready() -> void:
	_shape = CollisionShape3D.new()
	_shape.shape = BoxShape3D.new()
	(_shape.shape as BoxShape3D).size = size
	_shape.position.y = size.y * 0.5
	add_child(_shape)
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerBall:
		(body as PlayerBall).set_surface_grip(grip)


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerBall:
		(body as PlayerBall).set_surface_grip(1.0)
