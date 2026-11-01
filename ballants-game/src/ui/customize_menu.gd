extends CanvasLayer
## CUSTOMIZE MENU -- dress up your ant and pick your ball.
##
## Press C (keyboard) or Y (controller) anywhere to open it; the game
## pauses. Your ant appears big in the middle of the screen, standing on
## its ball and slowly turning. Next to each part of the ant is a row with
## arrows: Antennae, Eyes, Head, Thorax, Abdomen, Legs, and under the ball
## the Ball style. The selected part glows gently on the ant. Beside the
## ball row is the Music on/off switch.
##
##   Up / Down (stick, d-pad, W/S, arrows): choose a part
##   Left / Right: change its color / the ball
##   B, Esc or C / Y again: done
## The arrows can be clicked with the mouse too. Changes apply instantly
## (to the ant and ball in the game as well) and are saved.
##
## Loaded as a global called "CustomizeMenu".

const ROW_SLOTS := ["antennae", "eyes", "head", "thorax", "abdomen", "legs", "ball", "music"]
## Where on the ant each row points (the ant's own space; feet at 0).
const ANCHORS := {
	"antennae": Vector3(0.0, 0.56, -0.1),
	"eyes": Vector3(0.0, 0.45, -0.1),
	"head": Vector3(0.0, 0.41, -0.04),
	"thorax": Vector3(0.0, 0.3, 0.0),
	"abdomen": Vector3(0.0, 0.17, 0.07),
	"legs": Vector3(0.0, 0.06, 0.0),
}

var is_open := false

var _root: Control
var _viewport: SubViewport
var _container: SubViewportContainer
var _camera: Camera3D
var _turntable: Node3D
var _ant: Node3D
var _ball: Node3D
var _rows := {}           # slot -> {box, name, value, swatch}
var _selected := 0
var _time := 0.0
var _was_paused := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	Cosmetics.changed.connect(_refresh)
	Music.changed.connect(_refresh)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.07, 0.09, 0.93)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	# The 3D preview: a little stage of its own with the ant and its ball.
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.anchor_left = 0.5
	_container.anchor_right = 0.5
	_container.anchor_top = 0.0
	_container.anchor_bottom = 1.0
	_container.offset_left = -260
	_container.offset_right = 260
	_container.offset_top = 70
	_container.offset_bottom = -130
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_container.add_child(_viewport)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.environment.ambient_light_energy = 0.6
	_viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 150, 0)
	key.light_energy = 1.3
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -30, 0)
	rim.light_energy = 0.5
	_viewport.add_child(rim)

	_turntable = Node3D.new()
	_viewport.add_child(_turntable)
	_ball = Assets.instantiate_model("ball")
	_ball.position = Vector3(0, -0.5, 0)
	_turntable.add_child(_ball)
	_ant = Assets.instantiate_model("ant")
	_turntable.add_child(_ant)

	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.position = Vector3(0.0, 0.2, -1.75)
	_viewport.add_child(_camera)
	_camera.look_at(Vector3(0.0, 0.12, 0.0))

	var title := _label("Customize", 40, Color(1.0, 0.95, 0.75))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -300
	title.offset_right = 300
	title.offset_top = 16
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)

	var help := _label("Up / Down: choose     Left / Right: change     B / Esc / C: done", 18, Color(1, 1, 1, 0.75))
	help.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	help.offset_left = -400
	help.offset_right = 400
	help.offset_top = -34
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(help)

	for slot in ROW_SLOTS:
		_rows[slot] = _make_row(slot)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## One row: [<]  name / current choice  (swatch)  [>]
func _make_row(slot: String) -> Dictionary:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(box)
	var left := Button.new()
	left.text = "<"
	left.custom_minimum_size = Vector2(44, 44)
	left.add_theme_font_size_override("font_size", 24)
	left.pressed.connect(func(): _select(slot); _change(slot, -1))
	box.add_child(left)
	var texts := VBoxContainer.new()
	texts.custom_minimum_size = Vector2(170, 0)
	texts.add_theme_constant_override("separation", -4)
	box.add_child(texts)
	var title := _part_label(slot)
	var name := _label(title, 22, Color.WHITE)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texts.add_child(name)
	var value := _label("", 17, Color(1, 1, 1, 0.8))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texts.add_child(value)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(26, 26)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.visible = _is_part(slot)
	box.add_child(swatch)
	var right := Button.new()
	right.text = ">"
	right.custom_minimum_size = Vector2(44, 44)
	right.add_theme_font_size_override("font_size", 24)
	right.pressed.connect(func(): _select(slot); _change(slot, 1))
	box.add_child(right)
	return {"box": box, "name": name, "value": value, "swatch": swatch}


func _part_label(slot: String) -> String:
	if slot == "ball":
		return "Ball"
	if slot == "music":
		return "Music"
	for p in Cosmetics.PARTS:
		if p[0] == slot:
			return p[1]
	return slot


func _is_part(slot: String) -> bool:
	return slot != "ball" and slot != "music"


## Left / right on a row: the next color or ball, or music on / off.
func _change(slot: String, direction: int) -> void:
	Sounds.ui("change")
	if slot == "music":
		Music.toggle()
	else:
		Cosmetics.step(slot, direction)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("customize"):
		if is_open:
			close()
		elif not Transition.is_dark():
			open()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventJoypadMotion:
		# The stick is read in _process instead: a held stick sends a new
		# motion event every frame, and each one would count as a fresh
		# press (30 color changes and clicks a second). (Left unhandled so
		# Controls still notices a controller is in use; the game is paused.)
		return
	var handled := true
	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("customize"):
		close()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_select_index(_selected - 1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		_select_index(_selected + 1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_change(ROW_SLOTS[_selected], -1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_change(ROW_SLOTS[_selected], 1)
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		handled = false   # let the buttons get clicks
	else:
		handled = event is InputEventKey or event is InputEventJoypadButton
	if handled:
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open:
		return
	is_open = true
	Sounds.ui("open")
	_was_paused = get_tree().paused
	get_tree().paused = true
	Game.set_ui_open(true)
	_root.visible = true
	_refresh()
	_place_rows_soon()
	# The ant pops into the middle of the screen.
	_turntable.scale = Vector3.ONE * 0.6
	_root.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_root, "modulate:a", 1.0, 0.2)
	tween.tween_property(_turntable, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not is_open:
		return
	is_open = false
	Sounds.ui("close")
	_root.visible = false
	get_tree().paused = _was_paused
	Game.set_ui_open(false)


func _select(slot: String) -> void:
	_select_index(ROW_SLOTS.find(slot))


func _select_index(index: int) -> void:
	var before := _selected
	_selected = posmod(index, ROW_SLOTS.size())
	if is_open and _selected != before:
		Sounds.ui("move")
	_refresh()


func _refresh() -> void:
	Cosmetics.apply_to_ant(_ant)
	Cosmetics.apply_to_ball(_ball)
	for i in ROW_SLOTS.size():
		var slot: String = ROW_SLOTS[i]
		var row: Dictionary = _rows[slot]
		if slot == "music":
			(row.value as Label).text = "On" if Music.enabled else "Off"
		else:
			(row.value as Label).text = Cosmetics.option_name(slot)
		if _is_part(slot):
			(row.swatch as ColorRect).color = Cosmetics.color_of(slot)
		var chosen := i == _selected
		(row.name as Label).add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if chosen else Color.WHITE)
		(row.box as Control).modulate.a = 1.0 if chosen else 0.7


func _place_rows_soon() -> void:
	# Wait for the layout to settle (the preview's size) before measuring.
	await get_tree().process_frame
	await get_tree().process_frame
	_place_rows()


## Lines each row up with its part of the ant: rows alternate left and
## right of the preview, at the height of the part they color; the ball
## row sits under the ball, with the music switch to its left.
func _place_rows() -> void:
	var view_size := Vector2(_viewport.size)
	var origin := _container.position
	var scale := _container.size / view_size if view_size.x > 0 else Vector2.ONE
	var column_gap := 30.0
	for i in ROW_SLOTS.size():
		var slot: String = ROW_SLOTS[i]
		var box: Control = _rows[slot].box
		box.reset_size()
		var width := box.get_combined_minimum_size().x
		var height := box.get_combined_minimum_size().y
		if slot == "ball":
			box.position = Vector2(origin.x + _container.size.x * 0.5 - width * 0.5, origin.y + _container.size.y + 6)
			continue
		if slot == "music":
			box.position = Vector2(origin.x - width - column_gap, origin.y + _container.size.y + 6)
			continue
		var on_screen := _camera.unproject_position(ANCHORS[slot]) * scale + origin
		var left_side := i % 2 == 1
		var x := origin.x - width - column_gap if left_side else origin.x + _container.size.x + column_gap
		box.position = Vector2(x, on_screen.y - height * 0.5)


## The stick: one step when pushed, then a steady repeat while held.
const STICK_THRESHOLD := 0.55
const STICK_REPEAT_DELAY := 0.45
const STICK_REPEAT_EVERY := 0.16
var _stick_dir := Vector2i.ZERO
var _stick_timer := 0.0


func _read_stick(delta: float) -> void:
	# The movement controls are WASD + the left stick; the keys are handled
	# as key presses in _input, so only read here while on a controller.
	var raw := Vector2.ZERO
	if Controls.last_device == "controller":
		raw = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector2i.ZERO
	if raw.length() >= STICK_THRESHOLD:
		# Whichever way it's pushed more: up / down or left / right.
		dir = Vector2i(int(signf(raw.x)), 0) if absf(raw.x) > absf(raw.y) else Vector2i(0, int(signf(raw.y)))
	if dir != _stick_dir:
		_stick_dir = dir
		_stick_timer = STICK_REPEAT_DELAY
		_stick_step(dir)
	elif dir != Vector2i.ZERO:
		_stick_timer -= delta
		if _stick_timer <= 0.0:
			_stick_timer = STICK_REPEAT_EVERY
			_stick_step(dir)


func _stick_step(dir: Vector2i) -> void:
	if dir.y != 0:
		_select_index(_selected + dir.y)
	elif dir.x != 0:
		_change(ROW_SLOTS[_selected], dir.x)


func _process(delta: float) -> void:
	if not is_open:
		_stick_dir = Vector2i.ZERO
		return
	_read_stick(delta)
	_time += delta
	# Slowly swing round so you see the ant from the front and both sides.
	_turntable.rotation.y = sin(_time * 0.6) * 0.7
	if _ant.has_method("set_walk_speed"):
		_ant.set_walk_speed(0.0)
	# The selected part glows (pulses brighter).
	var slot: String = ROW_SLOTS[_selected]
	if _is_part(slot) and _ant.has_method("set_part_color"):
		Cosmetics.apply_to_ant(_ant)
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		_ant.set_part_color(slot, Cosmetics.color_of(slot).lightened(0.35 * pulse))
