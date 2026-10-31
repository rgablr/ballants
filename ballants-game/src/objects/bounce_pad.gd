extends Area3D
## BOUNCE PAD -- launches anything physical that rolls onto it straight up,
## to the height set by Tuning.bounce_pad_height.

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is not RigidBody3D:
		return
	var rigid := body as RigidBody3D
	if rigid.has_method("allow_launch"):
		rigid.allow_launch()
	# Same trick as the jump: set vertical speed to exactly what's needed to
	# reach the target height, whatever speed the body arrived with.
	var launch_speed := sqrt(2.0 * Tuning.gravity * Tuning.bounce_pad_height)
	rigid.apply_central_impulse(Vector3.UP * (launch_speed - rigid.linear_velocity.y) * rigid.mass)
	_squash()


## Quick squash-and-stretch so it reads as a bounce.
func _squash() -> void:
	var tween := create_tween()
	tween.tween_property(_mesh, "scale", Vector3(1.2, 0.5, 1.2), 0.06)
	tween.tween_property(_mesh, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK)
