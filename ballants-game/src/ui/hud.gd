extends CanvasLayer
## HUD -- the text drawn over the game: controls reminder, current speed,
## and the big center message when the goal is reached.
## The font comes from the asset manifest (applied game-wide by Assets).

@onready var _controls: Label = $Controls
@onready var _speed: Label = $Speed
@onready var _message: Label = $Message

var _player: RigidBody3D


func _ready() -> void:
	_message.visible = false
	_controls.text = ("WASD / left stick: roll     Space / A: jump     "
			+ "Mouse / right stick: camera     R: restart     Esc: free the mouse")
	Game.level_completed.connect(_on_level_completed)


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as RigidBody3D
		if _player == null:
			return
	var v := _player.linear_velocity
	_speed.text = "%.1f m/s" % Vector2(v.x, v.z).length()


func _on_level_completed() -> void:
	_message.text = "GOAL!\nPress R to play again"
	_message.visible = true
