extends CanvasLayer
## HUD -- the text drawn over the game: controls reminder, current speed,
## level name, run timer, and the big center messages (level complete,
## fell out, goal in the arena).
## The font comes from the asset manifest (applied game-wide by Assets).

@onready var _controls: Label = $Controls
@onready var _speed: Label = $Speed
@onready var _message: Label = $Message
@onready var _level_name: Label = $LevelName
@onready var _timer: Label = $Timer

var _player: RigidBody3D


func _ready() -> void:
	_message.visible = false
	_controls.text = ("WASD / left stick: roll     Space / A: jump     "
			+ "Mouse / right stick: camera     R: restart     1 2 3: levels     0: arena     "
			+ "F1: tuning     F2: debug")
	Levels.run_finished.connect(_on_run_finished)
	Levels.run_failed.connect(_on_run_failed)
	Levels.level_loaded.connect(func(_index: int): _refresh_level_name())
	_refresh_level_name()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as RigidBody3D
	if _player:
		var v := _player.linear_velocity
		_speed.text = "%.1f m/s" % Vector2(v.x, v.z).length()
	if Levels.is_in_level():
		var info := Levels.current_info()
		_timer.text = "%s   par %s" % [Levels.format_time(Levels.run_time), Levels.format_time(info.par_time)]
	else:
		_timer.text = ""


func _refresh_level_name() -> void:
	if Levels.is_in_level():
		var info := Levels.current_info()
		_level_name.text = "%s  –  %s" % [info.world, info.name]
	else:
		var level := get_tree().current_scene
		_level_name.text = level.level_name if level and "level_name" in level else ""


func _on_run_finished(time: float) -> void:
	if Levels.is_in_level():
		var info := Levels.current_info()
		var verdict := "Under par!" if time <= info.par_time else "Par is %s" % Levels.format_time(info.par_time)
		_message.text = "Level complete!\n%s\n%s" % [Levels.format_time(time), verdict]
	else:
		_message.text = "GOAL!\nPress R to play again"
	_message.visible = true


func _on_run_failed() -> void:
	_message.text = "Fell out!"
	_message.visible = true
