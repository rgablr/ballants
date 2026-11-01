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
## The watermark in the bottom-left corner of every screen.
const WATERMARK := "made by rgablr"
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
	_box.offset_top = -240.0
	_box.offset_bottom = 240.0
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 14)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	_black.add_child(_box)

	_title = _label(TITLE_SIZE, Color(1, 0.95, 0.7))
	_level = _label(LINE_SIZE, Color(1, 1, 1, 0.8))
	_time = _label(TIME_SIZE, Color.WHITE)
	_par = _label(LINE_SIZE, Color(1, 1, 1, 0.8))
	_build_crystal_row()
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	_box.add_child(spacer)
	_prompt = _label(24, Color(1, 0.95, 0.7))
	_prompt.text = "[press any button to continue]"
	_prompt.visible = false
	_build_watermark()


## "made by rgablr", small in the bottom-left corner, on every screen
## (this layer sits above all the others and never goes away).
func _build_watermark() -> void:
	var mark := Label.new()
	mark.name = "Watermark"
	mark.text = WATERMARK
	mark.add_theme_font_size_override("font_size", 15)
	mark.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	mark.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	mark.add_theme_constant_override("shadow_offset_x", 1)
	mark.add_theme_constant_override("shadow_offset_y", 1)
	mark.anchor_top = 1.0
	mark.anchor_bottom = 1.0
	mark.offset_left = 16.0
	mark.offset_right = 400.0
	mark.offset_top = -28.0
	mark.offset_bottom = -6.0
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mark)


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


var _crystal_row: HBoxContainer
var _crystal_icons: Array[CrystalIcon] = []
var _crystal_labels: Array[Label] = []
var _crystal_summary: Label

## The level's four sugar crystals: an icon and a name each, under the
## time. Filled in by show_complete.
func _build_crystal_row() -> void:
	_crystal_row = HBoxContainer.new()
	_crystal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_crystal_row.add_theme_constant_override("separation", 34)
	_crystal_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_crystal_row)
	for slot in Progress.SLOT_COUNT:
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 4)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crystal_row.add_child(column)
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(center)
		var icon := CrystalIcon.new()
		icon.extent = 30.0
		center.add_child(icon)
		_crystal_icons.append(icon)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = Progress.SLOT_NAMES[slot]
		column.add_child(label)
		_crystal_labels.append(label)
	_crystal_summary = _label(20, Color(0.85, 0.97, 1.0))


## The results on the black: message, level name, time, target time, and
## the level's four crystals (bright = earned just now, plain = earned on
## an earlier run, outline = still to get). info is a LevelList entry, or
## empty in the test arena; states is Progress.slot_states() for the level.
func show_complete(info: Dictionary, time: float, states: Array = []) -> void:
	if info.is_empty():
		_title.text = "GOAL!"
		_level.text = "Test arena"
		_par.text = ""
	else:
		_title.text = "Level complete!"
		_level.text = "%s  –  %s" % [info.world, info.name]
		var par: float = info.par_time
		if time <= par:
			_par.text = "Target %s  –  beaten by %s" % [Levels.format_time(par), Levels.format_time(par - time)]
		else:
			_par.text = "Target %s  –  %s over" % [Levels.format_time(par), Levels.format_time(time - par)]
	_time.text = Levels.format_time(time)
	var show_crystals := not states.is_empty()
	_crystal_row.visible = show_crystals
	_crystal_summary.visible = show_crystals
	if show_crystals:
		var new_count := 0
		var have := 0
		for slot in Progress.SLOT_COUNT:
			var state: String = states[slot] if slot < states.size() else "none"
			_crystal_icons[slot].state = state
			var name: String = Progress.SLOT_NAMES[slot]
			if slot == Progress.SLOT_TIME and not info.is_empty():
				name = "Under %s" % Levels.format_time(float(info.par_time))
			match state:
				"new":
					_crystal_labels[slot].text = name + "\nNEW!"
					_crystal_labels[slot].add_theme_color_override("font_color", Color(0.85, 0.97, 1.0))
					new_count += 1
					have += 1
				"old":
					_crystal_labels[slot].text = name + "\n(earned before)"
					_crystal_labels[slot].add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
					have += 1
				_:
					_crystal_labels[slot].text = name + "\n–"
					_crystal_labels[slot].add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		if new_count > 0:
			_crystal_summary.text = "+%d sugar crystal%s   (%d of 4 from this level,  %d in the pouch)" \
					% [new_count, "" if new_count == 1 else "s", have, Progress.crystals]
		else:
			_crystal_summary.text = "%d of 4 from this level,  %d in the pouch" % [have, Progress.crystals]
	_box.visible = true
	Sounds.level_complete()


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
	_crystal_row.visible = false
	_crystal_summary.visible = false
	_box.visible = true
	_prompt.visible = false
	Sounds.world_complete()


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
		Sounds.ui("confirm")
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


# ----------------------------------------------------------- game over ----

const IRIS_SHADER := "
shader_type canvas_item;
uniform vec2 center = vec2(640.0, 360.0);
uniform float radius = 2000.0;
uniform float softness = 18.0;
void fragment() {
	float d = distance(FRAGCOORD.xy, center);
	float a = smoothstep(radius - softness, radius + softness, d);
	COLOR = vec4(0.0, 0.0, 0.0, a);
}"

var _iris: ColorRect
var _game_over: Label

## An iris wipe: a black circle closes in on `center` (screen pixels) until
## the screen is black, "Game Over" shows for a moment, and the screen is
## left black (the next scene change fades in from it). Awaitable.
func game_over(center: Vector2, close_time := 1.4, hold_time := 2.2) -> void:
	if _iris == null:
		_iris = ColorRect.new()
		_iris.set_anchors_preset(Control.PRESET_FULL_RECT)
		_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := Shader.new()
		shader.code = IRIS_SHADER
		var material := ShaderMaterial.new()
		material.shader = shader
		_iris.material = material
		add_child(_iris)
		move_child(_iris, 0)
		_game_over = Label.new()
		_game_over.text = "Game Over"
		_game_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_game_over.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_game_over.add_theme_font_size_override("font_size", 72)
		_game_over.add_theme_color_override("font_color", Color(1, 0.92, 0.75))
		_game_over.set_anchors_preset(Control.PRESET_FULL_RECT)
		_game_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_game_over.visible = false
		add_child(_game_over)
	var material := _iris.material as ShaderMaterial
	var size := get_viewport().get_visible_rect().size
	var start_radius := size.length()
	material.set_shader_parameter("center", center)
	material.set_shader_parameter("radius", start_radius)
	_iris.visible = true
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_method(func(r: float): material.set_shader_parameter("radius", r), start_radius, 0.0, close_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	# Hand over to the plain black so the next scene's fade-in works.
	_black.visible = true
	_black.modulate.a = 1.0
	_iris.visible = false
	_game_over.visible = true
	_game_over.modulate.a = 0.0
	var show := create_tween()
	show.tween_property(_game_over, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(hold_time).timeout
	_game_over.visible = false


func _fade_to(alpha: float, duration: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.tween_property(_black, "modulate:a", alpha, duration)
	await _tween.finished
