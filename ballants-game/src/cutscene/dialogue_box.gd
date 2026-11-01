class_name DialogueBox
extends CanvasLayer
## DIALOGUE BOX -- the see-through black text box on the right of the
## screen with the speaker's name above it. Text types out letter by
## letter (the speaker's VoiceSynth babbles along); A / Space finishes the
## line at once, and pressing again moves on. It also shows a two-way
## choice ("Yes (A)" / "No (B)") with the labels matching whatever the
## player last used, keyboard or controller, and a short centred popup
## ("Received: ...").
##
## Looks and speeds come from src/cutscene/cutscene_style.gd. Driven by
## CutscenePlayer:
##   await box.say("Queen Ant", "Oh boy!...", voice, type_speed)
##   var pick: int = await box.choose(options)

## The player pressed to move past a finished line.
signal advanced
## The player picked a choice (its index), or -1 when cancelled.
signal choice_made(index: int)

var _root: Control
var _panel: PanelContainer
var _name: Label
var _text: Label
var _hint: Label
var _choices: HBoxContainer
var _popup: Label

var _voice: VoiceSynth
var _type_speed := CutsceneStyle.TYPE_SPEED
var _typing := false
var _shown := 0
var _type_accum := 0.0
var _pause := 0.0
var _complete_at := -1.0
var _waiting := false
var _choosing := false
var _options: Array = []
var _time := 0.0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_name = Label.new()
	_name.add_theme_font_size_override("font_size", CutsceneStyle.NAME_SIZE)
	_name.add_theme_color_override("font_color", CutsceneStyle.NAME_COLOR)
	_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_name.add_theme_constant_override("shadow_offset_x", 2)
	_name.add_theme_constant_override("shadow_offset_y", 2)
	_root.add_child(_name)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CutsceneStyle.BOX_COLOR
	style.set_corner_radius_all(CutsceneStyle.BOX_CORNER)
	style.set_content_margin_all(CutsceneStyle.BOX_PADDING)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", CutsceneStyle.TEXT_SIZE)
	_text.add_theme_color_override("font_color", CutsceneStyle.TEXT_COLOR)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	column.add_child(_text)
	_choices = HBoxContainer.new()
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 60)
	_choices.visible = false
	column.add_child(_choices)
	_hint = Label.new()
	_hint.text = "▼"
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", CutsceneStyle.HINT_COLOR)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.visible = false
	column.add_child(_hint)

	_popup = Label.new()
	_popup.add_theme_font_size_override("font_size", 34)
	_popup.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_popup.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_popup.add_theme_constant_override("shadow_offset_x", 2)
	_popup.add_theme_constant_override("shadow_offset_y", 2)
	_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_popup.anchor_left = 0.0
	_popup.anchor_right = 1.0
	_popup.offset_top = 90
	_popup.offset_bottom = 140
	_popup.visible = false
	_root.add_child(_popup)

	_skip_label = Label.new()
	_skip_label.text = "skipping..."
	_skip_label.add_theme_font_size_override("font_size", 18)
	_skip_label.add_theme_color_override("font_color", CutsceneStyle.HINT_COLOR)
	_skip_label.position = Vector2(20, 16)
	_skip_label.visible = false
	_root.add_child(_skip_label)
	_skip_bar = ColorRect.new()
	_skip_bar.color = CutsceneStyle.HINT_COLOR
	_skip_bar.position = Vector2(20, 44)
	_skip_bar.size = Vector2(0, 5)
	_skip_bar.visible = false
	_root.add_child(_skip_bar)

	_layout()
	get_viewport().size_changed.connect(_layout)
	_panel.visible = false
	_name.visible = false


var _skip_label: Label
var _skip_bar: ColorRect

## Shows how far the skip hold has got (0 hides it).
func set_skip_progress(fraction: float) -> void:
	var show := fraction > 0.05
	_skip_label.visible = show
	_skip_bar.visible = show
	_skip_bar.size.x = 140.0 * clampf(fraction, 0.0, 1.0)


## Positions the box from the fractions in CutsceneStyle.
func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var left := size.x * CutsceneStyle.BOX_LEFT
	var width := size.x * CutsceneStyle.BOX_WIDTH
	var height := size.y * CutsceneStyle.BOX_HEIGHT
	var top := size.y * CutsceneStyle.BOX_BOTTOM - height
	_panel.position = Vector2(left, top)
	_panel.size = Vector2(width, height)
	_name.position = Vector2(left + CutsceneStyle.BOX_PADDING, top - CutsceneStyle.NAME_SIZE - 14)


func is_showing() -> bool:
	return _panel.visible


## Types a line and returns when the player has pressed to move on.
func say(speaker: String, text: String, voice: VoiceSynth, type_speed: float) -> void:
	_voice = voice
	_type_speed = type_speed if type_speed > 0.0 else CutsceneStyle.TYPE_SPEED
	_name.text = speaker
	_name.visible = true
	_panel.visible = true
	_choices.visible = false
	_hint.visible = false
	_text.text = text
	_text.visible_characters = 0
	_shown = 0
	_type_accum = 0.0
	_pause = 0.0
	_complete_at = -1.0
	_waiting = false
	_typing = true
	if voice:
		voice.reset()
	await advanced


## Shows the options (each {"text", "input", "keyboard", "controller"}) and
## returns the index picked, or -1 if cancelled.
func choose(options: Array, speaker := "") -> int:
	_options = options
	for child in _choices.get_children():
		child.queue_free()
	for option in options:
		var label := Label.new()
		label.text = _option_text(option)
		label.add_theme_font_size_override("font_size", CutsceneStyle.CHOICE_SIZE)
		label.add_theme_color_override("font_color", CutsceneStyle.CHOICE_COLOR)
		_choices.add_child(label)
	if not speaker.is_empty():
		_name.text = speaker
	_name.visible = true
	_panel.visible = true
	_text.text = ""
	_text.visible_characters = -1
	_hint.visible = false
	_choices.visible = true
	_typing = false
	_waiting = false
	_choosing = true
	var picked: int = await choice_made
	_choosing = false
	return picked


## "Yes (A / Space)" style text, from whichever the player used last.
func _option_text(option: Dictionary) -> String:
	var device: String = Controls.last_device if "last_device" in Controls else "keyboard"
	var key: String = str(option.get(device, option.get("keyboard", "")))
	if key.is_empty():
		return str(option.get("text", "?"))
	return "%s (%s)" % [option.get("text", "?"), key]


## A short centred message (item received).
func show_popup(text: String, seconds: float) -> void:
	_popup.text = text
	_popup.visible = true
	_popup.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_popup, "modulate:a", 1.0, 0.25)
	tween.tween_interval(seconds)
	tween.tween_property(_popup, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): _popup.visible = false)


func hide_box() -> void:
	_panel.visible = false
	_name.visible = false
	_typing = false
	_waiting = false


## Drops whatever is going on and releases anyone awaiting us.
func cancel() -> void:
	var was_choosing := _choosing
	var was_line := _typing or _waiting
	hide_box()
	_choosing = false
	if was_choosing:
		choice_made.emit(-1)
	if was_line:
		advanced.emit()


func _process(delta: float) -> void:
	_time += delta
	if _choosing:
		# Refresh labels if the player switched between keyboard and pad.
		for i in mini(_options.size(), _choices.get_child_count()):
			var label := _choices.get_child(i) as Label
			var want := _option_text(_options[i])
			if label.text != want:
				label.text = want
		return
	if _typing:
		_type(delta)
	elif _waiting:
		_hint.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * cos(_time * 5.0))


func _type(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		return
	_type_accum += delta * _type_speed
	var text := _text.text
	while _type_accum >= 1.0 and _shown < text.length():
		_type_accum -= 1.0
		var ch := text[_shown]
		_shown += 1
		_text.visible_characters = _shown
		if _voice:
			_voice.on_letter(ch)
		if ch in ".!?":
			# A run of dots ("...") pauses once, at its end.
			if _shown >= text.length() or text[_shown] != ch:
				_pause = CutsceneStyle.PAUSE_SENTENCE
				break
		elif ch == ",":
			_pause = CutsceneStyle.PAUSE_COMMA
			break
	if _shown >= text.length():
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_complete_at = _time
	_waiting = true
	_hint.visible = true


func _input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if _choosing:
		for i in _options.size():
			var action: String = str(_options[i].get("input", ""))
			if not action.is_empty() and event.is_action_pressed(action):
				get_viewport().set_input_as_handled()
				Sounds.ui("confirm")
				choice_made.emit(i)
				return
		return
	var pressed := event.is_action_pressed("jump") or event.is_action_pressed("ui_accept")
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_finish_typing()
	elif _waiting and _time - _complete_at >= CutsceneStyle.ADVANCE_GUARD:
		_waiting = false
		_hint.visible = false
		Sounds.ui("move")
		advanced.emit()
