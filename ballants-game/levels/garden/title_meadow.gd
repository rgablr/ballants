extends Level
## TITLE MEADOW -- the first thing you see: the title screen and a garden
## playground in one. The camera circles the ant while the MAIN MENU is up
## (src/ui/game_menu.gd); choosing Play starts the game here. (With the
## menu switched off, for the automated tests, the first input starts it.) The ground funnels gently downhill toward a giant ant hill;
## dropping into it starts Level 1.
##
## Everything else here is for fooling around: thick grass to bash through,
## pebbles and acorns to shove, a twig ramp, a bounce pad, a seesaw, and
## the bugs (ladybugs, worms, spiders, flies, bees).
##
## Placing things: every piece placed directly in this scene is stood on
## the meadow's sculpted ground when the level starts, so its Y in the
## editor is a height ABOVE the ground (0 = sitting on it).

const TITLE_SCREEN := preload("res://src/ui/title_screen.gd")

var _title: CanvasLayer
var _started := false
var _rig: Node3D


func _ready() -> void:
	_stand_on_ground()
	super._ready()
	_title = TITLE_SCREEN.new()
	_title.name = "TitleScreen"
	add_child(_title)
	_rig = find_child("CameraRig", true, false) as Node3D
	if _rig and "attract" in _rig:
		_rig.attract = true
	_set_hud_visible(false)
	if GameMenu.enabled:
		GameMenu.play_pressed.connect(_start)
		GameMenu.open_main.call_deferred(self)


## Moves every piece onto the ground: its editor Y becomes "height above
## the ground here".
func _stand_on_ground() -> void:
	var ground := find_child("MeadowGround", false, false) as MeadowGround
	if ground == null:
		return
	for child in get_children():
		if child == ground or child is not Node3D or child is GardenTheme:
			continue
		var node := child as Node3D
		var local := ground.to_local(node.global_position)
		node.global_position.y += ground.height_at(local.x, local.z)


func _exit_tree() -> void:
	if GameMenu.play_pressed.is_connected(_start):
		GameMenu.play_pressed.disconnect(_start)


func _unhandled_input(event: InputEvent) -> void:
	if _started or GameMenu.enabled or event.is_action("customize"):
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo \
			and event.keycode != KEY_F1 and event.keycode != KEY_F2) \
			or (event is InputEventJoypadButton and event.pressed) \
			or (event is InputEventMouseButton and event.pressed)
	if pressed:
		_start()


## Sticks start it through the move/camera actions (which have deadzones),
## not raw axis events: some controllers report a resting trigger as a
## fully-pushed axis. This also covers the test bot, which presses actions
## without sending input events.
func _process(_delta: float) -> void:
	if not _started and not GameMenu.enabled and (Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO \
			or Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down") != Vector2.ZERO \
			or Input.is_action_pressed("jump")):
		_start()


func _start() -> void:
	if _started:
		return
	_started = true
	if _rig and "attract" in _rig:
		_rig.attract = false
	_title.start()
	_set_hud_visible(true)


func _set_hud_visible(visible_now: bool) -> void:
	var hud := find_child("HUD", true, false) as CanvasLayer
	if hud:
		hud.visible = visible_now
