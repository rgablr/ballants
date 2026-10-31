extends Node
## GAME -- small global that owns the things no single level should:
## applying world gravity, restarting, mouse capture, and the "level done"
## state. Loaded as a global called "Game".

## Fired when the player reaches the goal. The HUD listens to this.
signal level_completed
## Fired just before the current level is reloaded.
signal level_restarting

var level_complete := false
## True while a panel (F1 tuning) wants the mouse free.
var ui_open := false


func _ready() -> void:
	_apply_gravity()
	Tuning.value_changed.connect(func(value_name: String, _value):
		if value_name == "gravity":
			_apply_gravity())
	capture_mouse()


## Gravity lives in the tuning file, not in Project Settings, so it is
## applied to the physics world here.
func _apply_gravity() -> void:
	var space := get_viewport().find_world_3d().space
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, Tuning.gravity)
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, Vector3.DOWN)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_level()
	elif event.is_action_pressed("ui_cancel"):
		release_mouse()
	elif event is InputEventMouseButton and event.pressed and not ui_open \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		capture_mouse()


func set_ui_open(open: bool) -> void:
	ui_open = open
	if open:
		release_mouse()
	else:
		capture_mouse()


func restart_level() -> void:
	level_complete = false
	level_restarting.emit()
	Levels.restart()


## Called by the Goal object. Safe to call more than once.
func complete_level() -> void:
	if level_complete:
		return
	level_complete = true
	level_completed.emit()


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
