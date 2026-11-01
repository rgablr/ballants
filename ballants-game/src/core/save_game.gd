extends Node
## SAVE GAME -- the four save profiles ("users"). Each has a name the
## player types, and keeps that player's progress (crystals, best times,
## the Crystal Pouch, the key, the open cell, the party...; see
## Progress.to_dict), their ant and ball look (Cosmetics.choices) and how
## long they've played.
##
## Each profile is one small file, user://profiles/slot_N.cfg (N = 1..4),
## in Godot's per-user data folder (on a Mac: ~/Library/Application
## Support/Godot/app_userdata/Ballants/profiles). Picking a profile loads it
## into Progress and Cosmetics; from then on it SAVES BY ITSELF whenever
## anything in Progress or Cosmetics changes (a crystal, the key, a best
## time, a new color...) and when the game quits. A save is written to a
## .tmp file first and then swapped in, so a crash mid-save can't leave a
## broken file. The last profile used is remembered in user://settings.cfg
## and picked again at the next start.
##
## Every file carries VERSION; older files still load (anything missing
## starts empty).
##
## With no profile picked (the automated tests, before the main menu is
## used) nothing is ever written.
##
## Loaded as a global called "Saves".

signal profiles_changed
signal profile_selected(slot: int)

const SLOTS := 4
const VERSION := 1
const NAME_MAX := 16

## Where the profile files live, and where the last profile used is
## remembered (the tests point both somewhere else).
var folder := "user://profiles"
var settings_path := "user://settings.cfg"
## 1..SLOTS, or 0 = no profile picked.
var active := 0
var active_name := ""
## Seconds played on the active profile.
var play_time := 0.0

var _save_queued := false
var _loading := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Progress.changed.connect(_queue_save)
	Cosmetics.changed.connect(_queue_save)


func _process(delta: float) -> void:
	if active > 0 and not get_tree().paused:
		play_time += delta


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if active > 0:
			save_now()


# ------------------------------------------------------------ profiles ----

func path_of(slot: int) -> String:
	return "%s/slot_%d.cfg" % [folder, slot]


func exists(slot: int) -> bool:
	return FileAccess.file_exists(path_of(slot))


## A short summary of a profile for the menus, or {} for an empty slot:
## name, crystals, total, play_time, items, version.
func info(slot: int) -> Dictionary:
	var file := ConfigFile.new()
	if file.load(path_of(slot)) != OK:
		return {}
	var progress: Dictionary = file.get_value("profile", "progress", {})
	var crystals := 0
	for flags in (progress.get("level_crystals", {}) as Dictionary).values():
		for flag in flags:
			if flag:
				crystals += 1
	return {
		"name": str(file.get_value("profile", "name", "Player %d" % slot)),
		"crystals": crystals,
		"total": Progress.crystals_total(),
		"play_time": float(file.get_value("profile", "play_time", 0.0)),
		"version": int(file.get_value("profile", "version", 0)),
	}


## Starts a brand-new profile in `slot` with this name and picks it.
func create(slot: int, profile_name: String) -> void:
	flush()
	_loading = true
	Progress.reset()
	_loading = false
	active = slot
	active_name = clean_name(profile_name, slot)
	play_time = 0.0
	save_now()
	_remember(slot)
	profiles_changed.emit()
	profile_selected.emit(slot)


## Loads a profile into the game and makes it the one that saves.
func select(slot: int) -> bool:
	flush()
	var file := ConfigFile.new()
	if file.load(path_of(slot)) != OK:
		return false
	_loading = true
	Progress.from_dict(file.get_value("profile", "progress", {}))
	var look: Dictionary = file.get_value("profile", "cosmetics", {})
	if not look.is_empty():
		Cosmetics.set_all(look)
	_loading = false
	active = slot
	active_name = str(file.get_value("profile", "name", "Player %d" % slot))
	play_time = float(file.get_value("profile", "play_time", 0.0))
	_remember(slot)
	profile_selected.emit(slot)
	return true


## Picks the profile used last time, if it still exists.
func select_last() -> bool:
	var settings := ConfigFile.new()
	if settings.load(settings_path) != OK:
		return false
	var slot := int(settings.get_value("profiles", "last", 0))
	return slot > 0 and exists(slot) and select(slot)


func rename(slot: int, profile_name: String) -> void:
	var file := ConfigFile.new()
	if file.load(path_of(slot)) != OK:
		return
	var clean := clean_name(profile_name, slot)
	file.set_value("profile", "name", clean)
	_write(slot, file)
	if slot == active:
		active_name = clean
	profiles_changed.emit()


## Deletes a profile for good. Deleting the one in use starts a blank game.
func delete(slot: int) -> void:
	if exists(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path_of(slot)))
	if slot == active:
		active = 0
		active_name = ""
		play_time = 0.0
		_loading = true
		Progress.reset()
		_loading = false
		_remember(0)
	profiles_changed.emit()


static func clean_name(profile_name: String, slot: int) -> String:
	var text := profile_name.strip_edges().substr(0, NAME_MAX)
	return text if not text.is_empty() else "Player %d" % slot


static func format_play_time(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	return "%d:%02d" % [minutes / 60, minutes % 60] if minutes >= 60 else "%d min" % minutes


# ------------------------------------------------------------- saving ----

## Writes a save that is still waiting for the end of the frame, before
## the active profile changes (or it would land in the wrong profile, or
## not at all).
func flush() -> void:
	if _save_queued:
		_save_queued = false
		save_now()


func _queue_save() -> void:
	if active <= 0 or _loading or _save_queued:
		return
	_save_queued = true
	_save_deferred.call_deferred()


func _save_deferred() -> void:
	if not _save_queued:
		return   # already written by flush()
	_save_queued = false
	save_now()


## Writes the active profile now.
func save_now() -> void:
	if active <= 0:
		return
	var file := ConfigFile.new()
	file.set_value("profile", "version", VERSION)
	file.set_value("profile", "name", active_name)
	file.set_value("profile", "play_time", play_time)
	file.set_value("profile", "saved_at", Time.get_datetime_string_from_system())
	file.set_value("profile", "progress", Progress.to_dict())
	file.set_value("profile", "cosmetics", Cosmetics.choices.duplicate())
	_write(active, file)


## Writes to a .tmp file, then swaps it in.
func _write(slot: int, file: ConfigFile) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var final_path := ProjectSettings.globalize_path(path_of(slot))
	var tmp_path := final_path + ".tmp"
	if file.save(tmp_path) != OK:
		push_error("Saves: could not write %s" % tmp_path)
		return
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(final_path)
	DirAccess.rename_absolute(tmp_path, final_path)


func _remember(slot: int) -> void:
	var settings := ConfigFile.new()
	settings.load(settings_path)   # keep the other settings (music...)
	settings.set_value("profiles", "last", slot)
	settings.save(settings_path)
