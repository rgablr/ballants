extends CanvasLayer
## TITLE SCREEN -- the game's name, huge, filling the top-left quarter of
## the screen ("BALL" over "ANTS"), with a pulsing "move to play" prompt
## while the camera circles the ant. On the first input the title shrinks
## into the corner, the prompt is replaced by a hint about the giant ant
## hill and the HUD comes in. The size is worked out from the window, so
## it fills the quarter at any resolution.
##
## The title area (levels/garden/title_meadow.gd) adds this and calls
## start() when the player first moves.

var _title: Label
var _subtitle: Label
var _prompt: Label
var _box: VBoxContainer
var _time := 0.0
var _started := false

## Font size after the player starts (in the corner, out of the way).
const SMALL_SIZE := 46
const MARGIN := 28.0


func _ready() -> void:
	layer = 5
	var box := VBoxContainer.new()
	box.position = Vector2(MARGIN, MARGIN * 0.5)
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_box = box
	_title = _label(box, "BALL\nANTS", 104, Color(1.0, 0.95, 0.78))
	_title.add_theme_color_override("font_outline_color", Color(0.32, 0.18, 0.08))
	_subtitle = _label(box, "a tiny ant on a big ball", 30, Color(1, 1, 1, 0.92))
	_fit_title()
	get_viewport().size_changed.connect(func():
		if not _started:
			_fit_title())
	_prompt = _label(self, "move to play\nC / Y: customize your ant", 30, Color(1.0, 0.95, 0.7))
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.offset_top = -130
	_prompt.offset_bottom = -70
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## The biggest font size at which "BALL" / "ANTS" fits the top-left
## quarter of the window.
func _fit_title() -> void:
	var quarter := get_viewport().get_visible_rect().size * 0.5
	var font := _title.get_theme_font("font")
	var size := 40
	for candidate in range(40, 600, 4):
		var width := maxf(font.get_string_size("BALL", HORIZONTAL_ALIGNMENT_LEFT, -1, candidate).x,
				font.get_string_size("ANTS", HORIZONTAL_ALIGNMENT_LEFT, -1, candidate).x)
		var height := font.get_height(candidate) * 2.0 * 0.82
		if width > quarter.x - MARGIN * 2.0 or height > quarter.y - MARGIN * 0.5:
			break
		size = candidate
	_set_title_size(size)


func _set_title_size(size: int) -> void:
	_title.add_theme_font_size_override("font_size", size)
	_title.add_theme_constant_override("line_spacing", -int(size * 0.18))
	_title.add_theme_constant_override("outline_size", maxi(int(size * 0.09), 6))
	_title.add_theme_constant_override("shadow_offset_x", maxi(int(size * 0.025), 2))
	_title.add_theme_constant_override("shadow_offset_y", maxi(int(size * 0.025), 2))


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
	var from: int = _title.get_theme_font_size("font_size")
	var tween := create_tween().set_parallel()
	tween.tween_property(_prompt, "modulate:a", 0.0, 0.4)
	tween.tween_method(func(size: float): _set_title_size(int(size)), float(from), float(SMALL_SIZE), 0.7) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_title, "modulate:a", 0.9, 0.7)
	tween.tween_property(_box, "position", Vector2(16, 40), 0.7).set_trans(Tween.TRANS_CUBIC)
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle.text = "roll into the giant ant hill to start"
