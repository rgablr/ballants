extends CanvasLayer
## GAME MENU -- the main menu (on the title meadow, while the camera
## circles the hero) and the pause menu (Esc / Start in the game), with
## the pages they open:
##
##   MAIN      Play, Select User, Progress, Customize, Exit
##   PAUSE     Resume, Restart Level, Back to the Anthill, Customize,
##             Progress, Controls, Main Menu, Exit Game
##   USERS     the four save profiles: pick one, start a new one (type a
##             name), rename or delete one
##   PROGRESS  everything there is to find, "???" until you have it, then
##             what it is and where you found it; cutscenes you've seen can
##             be watched again from here
##   CONTROLS  every key and button
##
## Keyboard / controller: Up / Down (arrows, W / S, d-pad, stick) move,
## Enter / Space / A choose, Esc / B / Start go back (or resume). The mouse
## works too. While a menu is up the game is paused (the main menu instead
## locks the ball, so the camera keeps circling behind it).
##
## Saving lives in src/core/save_game.gd ("Saves"); the menu only calls it.
## Loaded as a global called "GameMenu".

## Emitted when Play is chosen on the main menu (the title meadow starts).
signal play_pressed

## Off for the automated tests (the title meadow then starts on the first
## input, as it used to). See DevTools.
var enabled := true
## "" (closed), "main" or "pause".
var mode := ""
var page := ""

const ACCENT := Color(1.0, 0.82, 0.32)
const TEXT := Color(1.0, 0.97, 0.9)
const DIM := Color(1.0, 1.0, 1.0, 0.55)
const FOUND := "◆"
const MISSING := "◇"

## Where each level's two hidden crystals are (shown once found).
const HIDDEN_WHERE := [
	["In the shortcut tunnel behind the false wall at the first hairpin",
	 "In the pocket behind the root, at the crest before the plunge"],
	["High up the round end of the skate bowl",
	 "In the nook behind three egg heaps at the last bend"],
	["On top of the tall amber mushroom, off the blue launcher cap",
	 "Round the corner at the end of the spore spur"],
	["Carried on a crumb by a highway worker (bump it to make it drop)",
	 "Round the bend at the end of the long workers' tunnel"],
	["On the side ledge across the narrow tile bridge",
	 "At the far end of the dead end behind the roots"],
]

var _root: Control
var _shade: ColorRect
var _panel: PanelContainer
var _box: VBoxContainer
var _scroll: ScrollContainer
var _stack: Array[String] = []
var _waiting_customize := false
var _name_edit: LineEdit
var _edit_slot := 0
var _renaming := false
var _delete_slot := 0
var _title_scene: Node


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.03, 0.02, 0.01, 0.6)
	_root.add_child(_shade)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.03, 0.86)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(26)
	style.border_color = Color(ACCENT, 0.35)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_panel.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	_root.visible = false
	get_viewport().size_changed.connect(_layout)


func is_open() -> bool:
	return mode != ""


# ------------------------------------------------------- opening, closing ----

## The title meadow calls this: the main menu over the circling camera.
func open_main(title_scene: Node) -> void:
	if not enabled:
		return
	_title_scene = title_scene
	if Saves.active == 0:
		Saves.select_last()
	mode = "main"
	_stack.clear()
	Game.control_locked = true
	Game.set_ui_open(true)
	_root.visible = true
	_show("main")


func open_pause() -> void:
	if not can_pause():
		return
	mode = "pause"
	_stack.clear()
	get_tree().paused = true
	Game.set_ui_open(true)
	Sounds.ui("open")
	_root.visible = true
	_show("pause")


## Closes every page (resume the game / start playing).
func close() -> void:
	if mode == "":
		return
	var was := mode
	mode = ""
	page = ""
	_root.visible = false
	if was == "pause":
		get_tree().paused = false
		Sounds.ui("close")
	Game.set_ui_open(false)


## Only in a playable scene with nothing else going on.
func can_pause() -> bool:
	if not enabled or mode != "" or CustomizeMenu.is_open or Game.cutscene_active or Game.control_locked:
		return false
	if Transition.is_dark() or get_tree().paused:
		return false
	var scene := get_tree().current_scene
	return scene is Level and get_tree().get_first_node_in_group("player") != null


func _unhandled_input(event: InputEvent) -> void:
	if mode == "" and event.is_action_pressed("pause") and can_pause():
		get_viewport().set_input_as_handled()
		open_pause()


func _input(event: InputEvent) -> void:
	if mode == "" or _waiting_customize or CustomizeMenu.is_open:
		return
	var typing := _name_edit != null and is_instance_valid(_name_edit) and _name_edit.has_focus()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") \
			or (event.is_action_pressed("dialogue_no") and not typing):
		get_viewport().set_input_as_handled()
		back()
		return
	# W / S move too (the arrows, d-pad and stick already do, as ui_up / down).
	if event is InputEventKey and not typing:
		var focused := get_viewport().gui_get_focus_owner()
		if focused and event.is_action_pressed("move_forward"):
			var prev := focused.find_prev_valid_focus()
			if prev:
				prev.grab_focus()
			get_viewport().set_input_as_handled()
		elif focused and event.is_action_pressed("move_back"):
			var next := focused.find_next_valid_focus()
			if next:
				next.grab_focus()
			get_viewport().set_input_as_handled()


## One page back; from the first page of the pause menu, resume.
func back() -> void:
	if not _stack.is_empty():
		Sounds.ui("close")
		_show(_stack.pop_back(), false)
	elif mode == "pause":
		close()


func _process(_delta: float) -> void:
	# Anything that recaptured the mouse under an open menu (the customize
	# menu closing, opened with C / Y): free it again so it can click.
	if mode != "" and not _waiting_customize and not CustomizeMenu.is_open \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Game.set_ui_open(true)
	if _waiting_customize and not CustomizeMenu.is_open:
		# Customize closed: back to the menu it was opened from.
		_waiting_customize = false
		if mode == "pause":
			get_tree().paused = true
		Game.set_ui_open(true)
		_root.visible = true
		_show(page, false)


# --------------------------------------------------------------- pages ----

func _show(name: String, push := true) -> void:
	if push and page != "" and page != name:
		_stack.append(page)
	page = name
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_name_edit = null
	match name:
		"main": _page_main()
		"pause": _page_pause()
		"users": _page_users()
		"name": _page_name()
		"delete": _page_delete()
		"progress": _page_progress()
		"controls": _page_controls()
	_shade.visible = mode == "pause" or name != "main"
	_layout.call_deferred()
	_focus_first.call_deferred()


func _focus_first() -> void:
	if _name_edit and is_instance_valid(_name_edit):
		_name_edit.grab_focus()
		_name_edit.caret_column = _name_edit.text.length()
		return
	for node in _box.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button.visible and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return


## The main menu sits on the right, clear of the big title; every other
## page is centred.
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var width := 460.0 if page in ["main", "pause", "name", "delete"] else minf(820.0, view.x - 60.0)
	var max_height := view.y - 80.0
	_scroll.custom_minimum_size = Vector2(width, 0.0)
	_box.reset_size()
	var content := _box.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = minf(content, max_height - 52.0)
	_panel.reset_size()
	var size := _panel.get_combined_minimum_size()
	if mode == "main" and page == "main":
		_panel.position = Vector2(view.x - size.x - 60.0, (view.y - size.y) * 0.5 + 40.0)
	else:
		_panel.position = (view - size) * 0.5


func _page_main() -> void:
	var playing := Saves.active > 0
	_button("Play" if not playing else "Play  —  %s" % Saves.active_name, _on_play, 32)
	_button("Select User", func(): _show("users"))
	_button("Progress", func(): _show("progress"))
	_button("Customize", _open_customize)
	_button("Exit", _exit)
	_note("Playing as %s" % Saves.active_name if playing else "Pick a user to start", 18, DIM)


func _page_pause() -> void:
	_heading("Paused")
	_button("Resume", close)
	if Levels.is_in_level():
		_button("Restart Level", func():
			close()
			Game.restart_level())
		_button("Back to the Anthill", func():
			close()
			Levels.load_hub(Levels.current_index))
	_button("Customize", _open_customize)
	_button("Progress", func(): _show("progress"))
	_button("Controls", func(): _show("controls"))
	_button("Main Menu", func():
		Saves.save_now()
		close()
		Levels.load_title())
	_button("Exit Game", _exit)


func _page_users() -> void:
	_heading("Select User")
	for slot in range(1, Saves.SLOTS + 1):
		var info := Saves.info(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_box.add_child(row)
		var text := ""
		if info.is_empty():
			text = "%d     New game" % slot
		else:
			text = "%d     %s%s\n       %d / %d crystals   ·   %s played" % [slot, info.name,
					"   (playing)" if slot == Saves.active else "", info.crystals, info.total,
					Saves.format_play_time(info.play_time)]
		var pick := _button(text, func(): _pick_slot(slot), 22, row)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.custom_minimum_size.y = 64
		if not info.is_empty():
			var rename := _button("Rename", func():
				_edit_slot = slot
				_renaming = true
				_show("name"), 18, row)
			rename.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var remove := _button("Delete", func():
				_delete_slot = slot
				_show("delete"), 18, row)
			remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_button("Back", back)


func _pick_slot(slot: int) -> void:
	if Saves.exists(slot):
		Saves.select(slot)
		Sounds.ui("confirm")
		_stack.clear()
		_show("main" if mode == "main" else "pause", false)
	else:
		_edit_slot = slot
		_renaming = false
		_show("name")


func _page_name() -> void:
	_heading("Rename" if _renaming else "New game")
	_note("Type a name, then press Enter.", 18, DIM)
	_name_edit = LineEdit.new()
	_name_edit.max_length = Saves.NAME_MAX
	_name_edit.add_theme_font_size_override("font_size", 28)
	_name_edit.custom_minimum_size = Vector2(0, 52)
	_name_edit.text = Saves.info(_edit_slot).get("name", "") if _renaming else "Player %d" % _edit_slot
	_name_edit.select_all_on_focus = true
	_name_edit.text_submitted.connect(func(_text: String): _confirm_name())
	_box.add_child(_name_edit)
	_button("OK", _confirm_name)
	_button("Back", back)


func _confirm_name() -> void:
	var text := _name_edit.text if _name_edit else ""
	Sounds.ui("confirm")
	if _renaming:
		Saves.rename(_edit_slot, text)
		_stack.clear()
		_stack.append("main" if mode == "main" else "pause")
		_show("users", false)
	else:
		Saves.create(_edit_slot, text)
		_stack.clear()
		_show("main" if mode == "main" else "pause", false)


func _page_delete() -> void:
	var info := Saves.info(_delete_slot)
	_heading("Delete %s?" % info.get("name", "this user"))
	_note("All of this user's progress will be gone for good.", 20, TEXT)
	_button("Keep it", back)
	_button("Delete", func():
		Saves.delete(_delete_slot)
		Sounds.ui("close")
		_stack.clear()
		_stack.append("main" if mode == "main" else "pause")
		_show("users", false))


func _page_controls() -> void:
	_heading("Controls")
	for row in [
			["Roll", "WASD / arrow keys  ·  left stick"],
			["Jump", "Space  ·  A"],
			["Camera", "mouse  ·  right stick"],
			["Pause", "Esc  ·  Start"],
			["Restart level", "R  (or from the pause menu)"],
			["Customize", "C  ·  Y"],
			["Skip a cutscene", "hold Esc  ·  hold Start"],
			["Recenter tilt steering", "G  ·  right stick click"],
	]:
		_pair(row[0], row[1])
	_note("Developer keys", 20, ACCENT)
	for row in [["1–8", "load a level"], ["0", "test arena"], ["H / T", "the anthill / the title"],
			["U", "open every tunnel (not saved)"], ["F1 / F2", "tuning panel / debug view"]]:
		_pair(row[0], row[1])
	_button("Back", back)


# ------------------------------------------------------------ progress ----

func _page_progress() -> void:
	if Saves.active == 0 and mode == "main":
		_heading("Progress")
		_note("Pick a user first: progress belongs to a user.", 20, TEXT)
		_button("Select User", func(): _show("users"))
		_button("Back", back)
		return
	var who := Saves.active_name if Saves.active > 0 else "This game"
	_heading("%s's progress" % who if Saves.active > 0 else "Progress (not saved: no user picked)")
	_note("Sugar crystals  %d / %d      ·      played %s" % [Progress.crystals, Progress.crystals_total(),
			Saves.format_play_time(Saves.play_time)], 20, TEXT)

	_section("Sugar crystals")
	for i in LevelList.TUNNEL_COUNT:
		var info: Dictionary = LevelList.LEVELS[i]
		var best := "best %s" % Levels.format_time(float(Progress.best_times[i])) if Progress.best_times.has(i) else "not finished yet"
		_note("%s      %s" % [info.name, best], 22, ACCENT)
		var where: Array = HIDDEN_WHERE[i] if i < HIDDEN_WHERE.size() else ["", ""]
		_entry(Progress.has_crystal(i, Progress.SLOT_COMPLETE), "Finished the level")
		_entry(Progress.has_crystal(i, Progress.SLOT_TIME), "Beat the target time (%s)" % Levels.format_time(float(info.par_time)))
		_entry(Progress.has_crystal(i, Progress.SLOT_HIDDEN_A), "Hidden crystal: %s" % where[0])
		_entry(Progress.has_crystal(i, Progress.SLOT_HIDDEN_B), "Hidden crystal: %s" % where[1])

	_section("Items")
	_entry(Progress.has_queen_item, "Crystal Pouch  —  given to you by the Queen Ant when you agreed to help")
	_entry(Progress.has_mystery_key, "Mysterious Key  —  hanging high above the bounce pad between Worker Rush and Collapsing Gallery")

	_section("Secrets")
	_entry(Progress.jail_unlocked, "The jail cell  —  opened with the mysterious key")
	_entry(Progress.birthday_party_done, "The birthday party  —  the red button inside the jail cell")

	_section("Cutscenes")
	_cutscene(Progress.hub_intro_seen, "The Queen's Request", "intro")
	_cutscene(Progress.birthday_party_done, "Happy Birthday, Martha!", "party")
	_button("Back", back)


## One thing to find: "???" until found.
func _entry(found: bool, text: String) -> void:
	var button := _button("%s   %s" % [FOUND if found else MISSING, text if found else "???"], func(): pass, 19)
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_color_override("font_color", TEXT if found else DIM)
	button.add_theme_color_override("font_focus_color", ACCENT)
	# A soft highlight (the solid one would hide the text in its own color).
	var soft := StyleBoxFlat.new()
	soft.bg_color = Color(1, 1, 1, 0.1)
	soft.set_corner_radius_all(8)
	soft.set_content_margin_all(6)
	soft.content_margin_left = 14
	var plain := soft.duplicate() as StyleBoxFlat
	plain.bg_color = Color(0, 0, 0, 0)
	button.add_theme_stylebox_override("normal", plain)
	button.add_theme_stylebox_override("hover", soft)
	button.add_theme_stylebox_override("focus", soft)
	button.add_theme_stylebox_override("pressed", soft)


func _cutscene(seen: bool, title: String, which: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	var label := _label("%s   %s" % [FOUND if seen else MISSING, title if seen else "???"], 20, TEXT if seen else DIM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if seen:
		_button("Watch", func(): watch(which), 18, row)


## Plays a cutscene again: off to the anthill, where it runs.
func watch(which: String) -> void:
	Saves.save_now()
	close()
	Game.control_locked = false
	Progress.replay = which
	Levels.load_hub(-1)


# ------------------------------------------------------------- actions ----

func _on_play() -> void:
	if Saves.active == 0:
		_show("users")
		return
	Sounds.ui("confirm")
	close()
	Game.control_locked = false
	play_pressed.emit()


func _open_customize() -> void:
	_waiting_customize = true
	_root.visible = false
	CustomizeMenu.open()


func _exit() -> void:
	Saves.save_now()
	get_tree().quit()


# ------------------------------------------------------------- widgets ----

## The button on the current page with this text (tests).
func _page_button(text: String) -> Button:
	for node in _box.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null


func _button(text: String, action: Callable, font_size := 26, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", ACCENT)
	button.add_theme_color_override("font_focus_color", Color(0.1, 0.06, 0.02))
	button.add_theme_color_override("font_pressed_color", Color(0.1, 0.06, 0.02))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.06)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(10)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = ACCENT
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 1, 1, 0.14)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("pressed", focus)
	button.pressed.connect(func():
		Sounds.ui("move")
		action.call())
	button.focus_entered.connect(func(): Sounds.ui("move"))
	(parent if parent else _box).add_child(button)
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _heading(text: String) -> void:
	var label := _label(text, 38, ACCENT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(label)


func _section(text: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	_box.add_child(gap)
	var label := _label(text, 28, ACCENT)
	_box.add_child(label)


func _note(text: String, font_size: int, color: Color) -> void:
	var label := _label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(label)


func _pair(left: String, right: String) -> void:
	var row := HBoxContainer.new()
	_box.add_child(row)
	var a := _label(left, 21, ACCENT)
	a.custom_minimum_size.x = 260
	row.add_child(a)
	var b := _label(right, 21, TEXT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
