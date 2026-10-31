extends CanvasLayer
## TITLE SCREEN -- the game's name in the top-left corner over the title
## area, with a pulsing "move to play" prompt while the camera circles the
## ant. On the first input the prompt is replaced by a hint about the giant
## ant hill and the HUD comes in; the title stays, smaller and quieter.
##
## The title area (levels/garden/title_meadow.gd) adds this and calls
## start() when the player first moves.

var _title: Label
var _subtitle: Label
var _prompt: Label
var _time := 0.0
var _started := false


func _ready() -> void:
	layer = 5
	var box := VBoxContainer.new()
	box.position = Vector2(36, 44)
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = _label(box, "BALLANTS", 104, Color(1.0, 0.95, 0.78))
	_title.add_theme_constant_override("outline_size", 14)
	_title.add_theme_color_override("font_outline_color", Color(0.32, 0.18, 0.08))
	_subtitle = _label(box, "a tiny ant on a big ball", 28, Color(1, 1, 1, 0.92))
	_prompt = _label(self, "move to play", 30, Color(1.0, 0.95, 0.7))
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.offset_top = -110
	_prompt.offset_bottom = -70
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _process(delta: float) -> void:
	_time += delta
	if not _started:
		_prompt.modulate.a = 0.5 + 0.5 * (0.5 + 0.5 * cos(_time * 2.6))


## The player has taken control: swap the prompt for a hint and tone the
## title down so it doesn't get in the way.
func start() -> void:
	if _started:
		return
	_started = true
	var tween := create_tween().set_parallel()
	tween.tween_property(_prompt, "modulate:a", 0.0, 0.4)
	tween.tween_property(_title, "theme_override_font_sizes/font_size", 64, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_title, "modulate:a", 0.85, 0.6)
	_subtitle.text = "roll into the giant ant hill to start"
