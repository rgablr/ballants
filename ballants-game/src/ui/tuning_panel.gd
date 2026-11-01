extends CanvasLayer
## TUNING PANEL (F1) -- sliders for every value in config/physics_tuning.gd.
##
## Changes apply to the running game immediately. "Save" writes them back
## into the tuning file (comments are kept), "Reset" restores the values
## the file had when the game started. The panel is built from the tuning
## file itself, so a new value there shows up here with no extra work.
##
## Everything in it is mouse-only, so you can keep driving the ball with
## the keyboard or a controller while the panel is open.

const PANEL_WIDTH := 440.0

var _rows := {}            # value_name -> {slider/check, value_label}
var _startup_values := {}  # for Reset
var _status: Label
var _root: PanelContainer


func _ready() -> void:
	visible = false
	layer = 10
	for value_name in Tuning.get_value_names():
		_startup_values[value_name] = Tuning.get(value_name)
	_build()
	Tuning.value_changed.connect(_on_tuning_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tuning_panel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	Game.set_ui_open(visible)
	if visible:
		_refresh_all()


func _build() -> void:
	_root = PanelContainer.new()
	_root.anchor_left = 1.0
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.offset_left = -PANEL_WIDTH
	_root.offset_right = 0.0
	_root.offset_top = 0.0
	_root.offset_bottom = 0.0
	add_child(_root)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_root.add_child(column)

	var title := Label.new()
	title.text = "Tuning (F1 to close)"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	_add_button(buttons, "Save to file", _on_save_pressed)
	_add_button(buttons, "Reset", _on_reset_pressed)
	_add_button(buttons, "Restart level (R)", Game.restart_level)

	_status = Label.new()
	_status.text = "Drag a slider; changes apply instantly."
	_status.add_theme_font_size_override("font_size", 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_NONE
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	var descriptions := Tuning.get_descriptions()
	var current_section := ""
	for value_name in Tuning.get_value_names():
		var info: Dictionary = descriptions.get(value_name, {"section": "", "comment": ""})
		if info.section != current_section:
			current_section = info.section
			var header := Label.new()
			header.text = current_section
			header.add_theme_font_size_override("font_size", 18)
			header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
			list.add_child(header)
		_add_row(list, value_name, info.comment)


func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)


func _add_row(parent: Control, value_name: String, comment: String) -> void:
	var value = Tuning.get(value_name)
	var row := HBoxContainer.new()
	row.tooltip_text = comment
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = value_name.replace("_", " ")
	name_label.custom_minimum_size.x = 180.0
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.tooltip_text = comment
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_label)

	if value is bool:
		var check := CheckBox.new()
		check.button_pressed = value
		check.focus_mode = Control.FOCUS_NONE
		check.toggled.connect(func(pressed: bool): Tuning.set_value(value_name, pressed))
		row.add_child(check)
		_rows[value_name] = {"control": check, "value_label": null}
		return

	var slider := HSlider.new()
	var value_range: Array = Tuning.get_range(value_name)
	slider.min_value = value_range[0]
	slider.max_value = value_range[1]
	slider.step = (value_range[1] - value_range[0]) / 400.0
	slider.value = value
	# Mouse only: never takes keyboard/controller focus (so driving the ball
	# with the stick doesn't also move sliders), and the mouse wheel
	# scrolls the list instead of nudging the slider under the pointer.
	slider.focus_mode = Control.FOCUS_NONE
	slider.scrollable = false
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 140.0
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 64.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.text = _pretty(value)
	row.add_child(value_label)

	slider.value_changed.connect(func(new_value: float):
		Tuning.set_value(value_name, new_value)
		value_label.text = _pretty(new_value))
	_rows[value_name] = {"control": slider, "value_label": value_label}


func _pretty(value: float) -> String:
	if abs(value) >= 100.0:
		return "%.0f" % value
	if abs(value) >= 10.0:
		return "%.1f" % value
	if abs(value) >= 0.1:
		return "%.2f" % value
	return "%.4f" % value


func _refresh_all() -> void:
	for value_name in _rows:
		_sync_row(value_name, Tuning.get(value_name))


func _sync_row(value_name: String, value) -> void:
	if not _rows.has(value_name):
		return
	var row: Dictionary = _rows[value_name]
	var control: Control = row.control
	if control is CheckBox:
		(control as CheckBox).set_pressed_no_signal(value)
	elif control is HSlider:
		(control as HSlider).set_value_no_signal(value)
		row.value_label.text = _pretty(value)


func _on_tuning_changed(value_name: String, value) -> void:
	_sync_row(value_name, value)


func _on_save_pressed() -> void:
	var error := Tuning.save_to_file()
	if error.is_empty():
		_status.text = "Saved to config/physics_tuning.gd."
		for value_name in Tuning.get_value_names():
			_startup_values[value_name] = Tuning.get(value_name)
	else:
		_status.text = "Save failed: " + error


func _on_reset_pressed() -> void:
	for value_name in _startup_values:
		Tuning.set_value(value_name, _startup_values[value_name])
	_refresh_all()
	_status.text = "Reset to the values from the file."
