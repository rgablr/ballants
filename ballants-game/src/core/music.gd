extends Node
## MUSIC -- the background songs. Every song in the asset manifest's MUSIC
## table plays in a shuffled loop (never the same song twice in a row),
## kept quiet so the sound effects stay easy to hear. The jingles on the
## results cards briefly dip it (duck).
##
## Music can be turned off in the customize menu; that choice is saved to
## the player's computer (user://settings.cfg).
##
## Loaded as a global called "Music".

## How loud the songs play. 0 would be full volume; -18 is faint, sitting
## under the sound effects.
const VOLUME_DB := -18.0
## How far a jingle pushes the music down.
const DUCK_DB := -14.0
const FADE_IN := 2.0
const SETTINGS_PATH := "user://settings.cfg"

signal changed

var enabled := true

var _player: AudioStreamPlayer
var _order: Array = []
var _last := ""
var _fade := 0.0
var _duck_time := 0.0
var _duck := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps playing in menus
	_player = AudioStreamPlayer.new()
	_player.bus = Sounds.MUSIC_BUS
	_player.finished.connect(_play_next)
	add_child(_player)
	_load_settings()
	_apply_mute()
	# Silent while the automated tests run, so they don't blast songs.
	if DisplayServer.get_name() != "headless":
		_play_next()


func _play_next() -> void:
	if Assets.MUSIC.is_empty():
		return
	if _order.is_empty():
		_order = Assets.MUSIC.keys()
		_order.shuffle()
		if _order.size() > 1 and _order[0] == _last:
			_order.push_back(_order.pop_front())
	_last = _order.pop_front()
	_player.stream = Assets.music(_last)
	_fade = 0.0
	_player.play()


## Lowers the music for `seconds`, then lets it come back up.
func duck(seconds: float) -> void:
	_duck_time = maxf(_duck_time, seconds)


## Pauses the songs altogether (a scene with its own music, such as the
## birthday party) and resumes them, fading back in.
func set_hold(on: bool) -> void:
	if _player == null or _player.stream_paused == on:
		return
	_player.stream_paused = on
	if not on:
		_fade = 0.0


func set_enabled(on: bool) -> void:
	enabled = on
	_apply_mute()
	_save_settings()
	changed.emit()


func toggle() -> void:
	set_enabled(not enabled)


func _apply_mute() -> void:
	var bus := AudioServer.get_bus_index(Sounds.MUSIC_BUS)
	if bus != -1:
		AudioServer.set_bus_mute(bus, not enabled)


func _process(delta: float) -> void:
	_fade = minf(_fade + delta / FADE_IN, 1.0)
	_duck_time = maxf(_duck_time - delta, 0.0)
	var duck_goal := 1.0 if _duck_time > 0.0 else 0.0
	_duck = lerpf(_duck, duck_goal, 1.0 - exp(-delta * (10.0 if duck_goal > _duck else 2.0)))
	# Fade in from silence at the start of each song.
	var fade_db := linear_to_db(maxf(_fade, 0.001))
	_player.volume_db = VOLUME_DB + fade_db + DUCK_DB * _duck


func _load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) == OK:
		enabled = bool(file.get_value("audio", "music", true))


func _save_settings() -> void:
	var file := ConfigFile.new()
	file.load(SETTINGS_PATH)   # keep any other settings already there
	file.set_value("audio", "music", enabled)
	file.save(SETTINGS_PATH)
