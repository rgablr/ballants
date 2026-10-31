extends Area3D
## GOAL -- the level's finish. A spinning ring; roll through it to win.
## Tells the global Game that the level is complete, which the HUD shows.

const SPIN_SPEED := 1.2  # radians per second

@onready var _ring: MeshInstance3D = $Ring

var _done := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_ring.rotate_y(delta * SPIN_SPEED)


func _on_body_entered(body: Node3D) -> void:
	if _done or body is not PlayerBall:
		return
	_done = true
	var material := _ring.mesh.material as StandardMaterial3D
	material.albedo_color = Color(0.35, 0.9, 0.4)
	material.emission = Color(0.2, 0.8, 0.3)
	Game.complete_level()
	Sounds.goal()
