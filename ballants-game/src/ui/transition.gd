extends CanvasLayer
## TRANSITION -- the black screen between levels and the "Level complete"
## results drawn on it. Lives above every other UI layer and survives
## scene changes (it is a global called "Transition"), so the fade can
## start in one level and finish in the next.
##
## The level manager drives it:
##   await Transition.fade_out(0.5)        # screen wipes to black
##   Transition.show_complete(info, time)  # message + time on the black
##   await Transition.wait_for_continue()  # "[press any button to continue]"
##   ...load the next level...
##   Transition.fade_in(0.5)               # black lifts off the new level

const TITLE_SIZE := 64
const TIME_SIZE := 56
const LINE_SIZE := 28

var _black: ColorRect
var _box: VBoxContainer
var _title: Label
var _level: Label
var _time: Label
var _par: Label
var _prompt: Label
var _tween: Tween
var _waiting := false
var _prompt_time := 0.0

## Fired when a button is pressed while the continue prompt is up.
signal continue_pressed


func _ready() -> void:
	layer = 50
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	_black.visible = false
	add_child(_black)

	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER)
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 0.5
	_box.anchor_bottom = 0.5
	_box.offset_left = -500.0
	_box.offset_right = 500.0
	_box.offset_top = -160.0
	_box.offset_bottom = 160.0
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 14)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	_black.add_child(_box)

	_title = _label(TITLE_SIZE, Color(1, 0.95, 0.7))
	_level = _label(LINE_SIZE, Color(1, 1, 1, 0.8))
	_time = _label(TIME_SIZE, Color.WHITE)
	_par = _label(LINE_SIZE, Color(1, 1, 1, 0.8))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	_box.add_child(spacer)
	_prompt = _label(24, Color(1, 0.95, 0.7))
	_prompt.text = "[press any button to continue]"
	_prompt.visible = false


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(label)
	return label


## True while the screen is (at least partly) covered.
func is_dark() -> bool:
	return _black.visible and _black.modulate.a > 0.0


## Wipes the screen to black. Await it to know when it is fully dark.
func fade_out(duration: float) -> void:
	_black.visible = true
	await _fade_to(1.0, duration)


## Lifts the black off the screen (and hides the results).
func fade_in(duration: float) -> void:
	hide_complete()
	await _fade_to(0.0, duration)
	if _black.modulate.a <= 0.0:
		_black.visible = false


## Drops the black and results instantly (restarts, level keys).
func clear() -> void:
	if _tween:
		_tween.kill()
	hide_complete()
	_black.modulate.a = 0.0
	_black.visible = false


## The results on the black: message, level name, time, par verdict.
## info is a LevelList entry, or empty in the test arena.
func show_complete(info: Dictionary, time: float) -> void:
	if info.is_empty():
		_title.text = "GOAL!"
		_level.text = "Test arena"
		_par.text = ""
	else:
		_title.text = "Level complete!"
		_level.text = "%s  –  %s" % [info.world, info.name]
		var par: float = info.par_time
		if time <= par:
			_par.text = "Under par by %s" % Levels.format_time(par - time)
		else:
			_par.text = "Par %s  (%s over)" % [Levels.format_time(par), Levels.format_time(time - par)]
	_time.text = Levels.format_time(time)
	_box.visible = true


## After the last level of a world: the world's name and this session's
## time for each of its levels. rows = [[level name, seconds or -1], ...]
func show_world_complete(world: String, rows: Array) -> void:
	_title.text = "%s complete!" % world
	_level.text = "You rolled through the whole world"
	var lines := PackedStringArray()
	var total := 0.0
	var all_timed := true
	for row in rows:
		var seconds: float = row[1]
		if seconds >= 0.0:
			lines.append("%s   %s" % [row[0], Levels.format_time(seconds)])
			total += seconds
		else:
			lines.append("%s   –" % row[0])
			all_timed = false
	_time.text = "Total %s" % Levels.format_time(total) if all_timed else ""
	_par.text = "\n".join(lines)
	_box.visible = true
	_prompt.visible = false


func hide_complete() -> void:
	_box.visible = false
	_prompt.visible = false
	_waiting = false


## Shows "[press any button to continue]" and returns when any key,
## controller button or mouse button is pressed.
func wait_for_continue() -> void:
	_prompt.visible = true
	_prompt_time = 0.0
	_waiting = true
	await continue_pressed


## Same as a player pressing a button (used by the test bot).
func press_continue() -> void:
	if _waiting:
		_waiting = false
		_prompt.visible = false
		continue_pressed.emit()


func _process(delta: float) -> void:
	if _prompt.visible:
		# Gentle pulse so it reads as waiting for you.
		_prompt_time += delta
		_prompt.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * cos(_prompt_time * 3.0))


## While the results are up, every press belongs to this screen (so R or
## a level key can't also fire underneath).
func _input(event: InputEvent) -> void:
	if not _box.visible:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventJoypadButton and event.pressed) \
			or (event is InputEventMouseButton and event.pressed)
	if pressed or event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
	if pressed:
		press_continue()


func _fade_to(alpha: float, duration: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.tween_property(_black, "modulate:a", alpha, duration)
	await _tween.finished
