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
var _gyro_label: Label
var _gyro_track: ColorRect
var _gyro_knob: ColorRect


func _ready() -> void:
	_message.visible = false
	_refresh_controls_text()
	Levels.run_finished.connect(_on_run_finished)
	Levels.run_failed.connect(_on_run_failed)
	Levels.level_loaded.connect(func(_index: int): _refresh_level_name())
	Controls.gyro_device_changed.connect(func(_device: int): _refresh_controls_text())
	_refresh_level_name()
	_build_gyro_indicator()


func _refresh_controls_text() -> void:
	if Controls.gyro_active():
		_controls.text = ("Left stick: forward = go, back = brake     TILT the controller: steer     "
				+ "Right stick click / G: recenter     A: jump     R: restart     F1: tuning     F2: debug")
	else:
		_controls.text = ("WASD / left stick: roll     Space / A: jump     "
				+ "Mouse / right stick: camera     R: restart     1 2 3: levels     0: arena     "
				+ "F1: tuning     F2: debug")


## A small bar at the bottom showing how far the controller is tilted,
## so the player can see what the game thinks they're doing.
func _build_gyro_indicator() -> void:
	_gyro_track = ColorRect.new()
	_gyro_track.color = Color(0, 0, 0, 0.35)
	_gyro_track.anchor_left = 0.5
	_gyro_track.anchor_right = 0.5
	_gyro_track.anchor_top = 1.0
	_gyro_track.anchor_bottom = 1.0
	_gyro_track.offset_left = -120.0
	_gyro_track.offset_right = 120.0
	_gyro_track.offset_top = -34.0
	_gyro_track.offset_bottom = -22.0
	add_child(_gyro_track)
	_gyro_knob = ColorRect.new()
	_gyro_knob.color = Color(1.0, 0.85, 0.3)
	_gyro_knob.size = Vector2(10, 20)
	_gyro_track.add_child(_gyro_knob)
	_gyro_label = Label.new()
	_gyro_label.add_theme_font_size_override("font_size", 14)
	_gyro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gyro_label.anchor_left = 0.5
	_gyro_label.anchor_right = 0.5
	_gyro_label.anchor_top = 1.0
	_gyro_label.anchor_bottom = 1.0
	_gyro_label.offset_left = -200.0
	_gyro_label.offset_right = 200.0
	_gyro_label.offset_top = -58.0
	_gyro_label.offset_bottom = -36.0
	add_child(_gyro_label)


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
	var gyro := Controls.gyro_active()
	_gyro_track.visible = gyro
	_gyro_label.visible = gyro
	if gyro:
		_gyro_knob.position = Vector2(115.0 + Controls.steer * 115.0, -4.0)
		_gyro_label.text = "Tilt steering: %s  (%.0f°)" % [Controls.gyro_device_name(), Controls.tilt_degrees]


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
