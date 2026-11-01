extends Node
## LEVEL MANAGER -- moves between levels and times each run.
##
##   - knows which level is playing (an index into LevelList.LEVELS, or -1
##     for the test arena)
##   - the run timer: starts on the first movement input, stops at the goal
##   - on goal (the ball drops into the ant hill): a moment to watch it
##     sink, the screen wipes to black, the results show (message and
##     time) with "press any button to continue"; on a press the next
##     level loads under the black and the black lifts. After the last
##     level it wraps to the first.
##   - the title area's giant hill: dropping in wipes to black and loads
##     level 1 (no results; there was no run to time)
##   - on fall-out (a FallZone, or dropping below the world): restarts
##   - keys 1/2/3 jump to a level, 0 loads the test arena, R restarts
##
## Loaded as a global called "Levels". The HUD listens to its signals.

signal level_loaded(index: int)
signal run_started
signal run_finished(time: float)
signal run_failed
## Outside a level (title area, arena) a knock-off respawns you in place of
## a restart; this fires once you're back at the spawn.
signal knock_recovered
## An enemy hit the player (the HUD flashes a red border).
signal player_hit(attacker: String)
## The ball dropped into an entrance hill (the title area's giant hill).
## level_index is HUB_INDEX when the hill leads into the anthill hub.
signal entered_through_hill(level_index: int)
## The ball rolled into one of the hub's tunnels; the level is loading.
signal entered_tunnel(level_index: int)

## Stands for "the hub" where a level index is expected.
const HUB_INDEX := -2

## Seconds to watch the ball sink into the hill before the wipe starts.
const DROP_DELAY := 0.9
## Seconds the wipe to black takes, and the lift off the next level.
const FADE_TIME := 0.5
## Seconds the results show before "press any button" appears, so a button
## still held from playing can't skip them by accident.
const CONTINUE_DELAY := 0.6
## Seconds to show "Fell out!" before restarting.
const FAIL_DELAY := 0.8
## Seconds to watch the ant tumble off the ball before restarting.
const KNOCK_DELAY := 1.5

## Why the last run failed, for the HUD ("Fell out!", "Knocked off!").
var fail_reason := "Fell out!"
var _knock_busy := false

var current_index := -1
## This session's latest time for each level (index -> seconds), for the
## world-complete screen.
var session_times := {}
var run_time := 0.0
var timer_running := false

var _run_done := false
var _loading := false
var _run_id := 0   # bumps on every load so stale timers can't act


func _ready() -> void:
	Game.level_completed.connect(_on_level_completed)
	# Which level is the main scene? Match it to the list so the index is
	# right from the first frame.
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	for i in LevelList.LEVELS.size():
		if LevelList.LEVELS[i].scene == main_scene:
			current_index = i
	level_loaded.emit.call_deferred(current_index)


func _process(delta: float) -> void:
	if timer_running:
		run_time += delta
	elif is_in_level() and not _run_done and not _loading and _movement_pressed():
		timer_running = true
		run_started.emit()


func _unhandled_input(event: InputEvent) -> void:
	if Game.cutscene_active:
		return   # hold Esc / Start to skip the cutscene instead
	if event.is_action_pressed("level_1"):
		load_level(0)
	elif event.is_action_pressed("level_2"):
		load_level(1)
	elif event.is_action_pressed("level_3"):
		load_level(2)
	elif event.is_action_pressed("level_4"):
		load_level(3)
	elif event.is_action_pressed("level_5"):
		load_level(4)
	elif event.is_action_pressed("level_0"):
		load_test_arena()
	elif event.is_action_pressed("hub"):
		load_hub()
	elif event.is_action_pressed("title_screen"):
		load_title()


## True when the anthill hub is the current scene.
func is_in_hub() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == LevelList.HUB


## Loads the hub. return_from = the level index the player just finished
## (they appear in front of that tunnel), or -1 to fall in through the top.
func load_hub(return_from := -1) -> void:
	current_index = -1
	Progress.hub_return_from = return_from
	_change_scene(LevelList.HUB)


## Called by a hub tunnel when the ball rolls into it: a moment of rolling
## into the dark, a wipe to black, then the level.
func enter_level_from_hub(index: int) -> void:
	if _loading or index < 0 or index >= LevelList.LEVELS.size():
		return
	_run_done = true
	Game.control_locked = true
	entered_tunnel.emit(index)
	var my_run := _run_id
	await get_tree().create_timer(0.35).timeout
	if my_run != _run_id:
		return
	await Transition.fade_out(FADE_TIME)
	if my_run == _run_id:
		load_level(index)


## Called by the title meadow's giant hill: watch the ball sink, wipe to
## black, then the hub (where the hero falls in through the top).
func enter_hub_through_hill() -> void:
	if _run_done or _loading:
		return
	_run_done = true
	timer_running = false
	entered_through_hill.emit(HUB_INDEX)
	var my_run := _run_id
	await get_tree().create_timer(DROP_DELAY).timeout
	if my_run != _run_id:
		return
	await Transition.fade_out(FADE_TIME)
	if my_run == _run_id:
		load_hub(-1)


## True when a listed level is playing (false in the test arena).
func is_in_level() -> bool:
	return current_index >= 0


## The current level's list entry, or an empty dictionary in the arena.
func current_info() -> Dictionary:
	if is_in_level():
		return LevelList.LEVELS[current_index]
	return {}


func load_level(index: int) -> void:
	if index < 0 or index >= LevelList.LEVELS.size():
		push_error("Levels: no level %d in the list" % index)
		return
	current_index = index
	_change_scene(LevelList.LEVELS[index].scene)


func load_next() -> void:
	load_level((current_index + 1) % LevelList.LEVELS.size())


func load_title() -> void:
	current_index = -1
	_change_scene(LevelList.TITLE)


func load_test_arena() -> void:
	current_index = -1
	_change_scene(LevelList.TEST_ARENA)


func restart() -> void:
	if is_in_level():
		load_level(current_index)
	else:
		_change_scene(get_tree().current_scene.scene_file_path)


## Called by FallZone (or the ball falling below the world). Shows the
## fail message briefly, then restarts the level. In the test arena the
## ball just respawns instead (handled by the player).
func fail(reason := "Fell out!", delay := FAIL_DELAY) -> void:
	if _run_done or _loading:
		return
	_run_done = true
	timer_running = false
	fail_reason = reason
	run_failed.emit()
	var my_run := _run_id
	await get_tree().create_timer(delay).timeout
	if my_run == _run_id:
		restart()


## An enemy knocked the ant off the ball. In a level: "Knocked off!" and
## the level restarts from the spawn. Elsewhere (title area, test arena):
## the screen dips to black and the ball is put back at its spawn point.
func knocked_off(attacker := "") -> void:
	player_hit.emit(attacker)
	var reason := "Knocked off!"
	if not attacker.is_empty():
		var article := "An" if attacker[0].to_lower() in "aeiou" else "A"
		reason = "%s %s attacked you!" % [article, attacker]
	if is_in_level():
		fail(reason, KNOCK_DELAY)
		return
	if _knock_busy or _loading:
		return
	_knock_busy = true
	fail_reason = reason
	run_failed.emit()
	var my_run := _run_id
	await get_tree().create_timer(KNOCK_DELAY).timeout
	if my_run == _run_id:
		await Transition.fade_out(0.35)
	if my_run == _run_id:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("respawn"):
			player.respawn()
		knock_recovered.emit()
		Transition.fade_in(0.35)
	_knock_busy = false


func _change_scene(path: String) -> void:
	_loading = true
	_run_id += 1
	run_time = 0.0
	timer_running = false
	_run_done = false
	Game.level_complete = false
	Game.control_locked = false
	Game.cutscene_active = false
	Engine.time_scale = 1.0
	var was_dark := Transition.is_dark()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	_loading = false
	level_loaded.emit(current_index)
	# Coming out of the results screen: lift the black off the new level.
	# A plain restart or level key cuts straight to the level instead.
	if was_dark:
		Transition.fade_in(FADE_TIME)
	else:
		Transition.clear()


## The finish sequence. Each wait checks the run is still the same one so
## pressing R or a level key during it cancels the rest.
func _on_level_completed() -> void:
	timer_running = false
	_run_done = true
	run_finished.emit(run_time)
	if is_in_level():
		session_times[current_index] = run_time
		Progress.record_finish(current_index, run_time, float(current_info().par_time))
	var my_run := _run_id
	await get_tree().create_timer(DROP_DELAY).timeout
	if my_run != _run_id:
		return
	await Transition.fade_out(FADE_TIME)
	if my_run != _run_id:
		return
	Transition.show_complete(current_info(), run_time)
	await get_tree().create_timer(CONTINUE_DELAY).timeout
	if my_run != _run_id:
		return
	await Transition.wait_for_continue()
	if my_run != _run_id:
		return
	if is_in_level() and LevelList.is_last_of_world(current_index):
		# Last level of its world: a "world complete" card first.
		Transition.show_world_complete(current_info().world, _world_times())
		await get_tree().create_timer(CONTINUE_DELAY).timeout
		if my_run != _run_id:
			return
		await Transition.wait_for_continue()
		if my_run != _run_id:
			return
	if is_in_level():
		# Every level leads back to the hub, in front of its own tunnel.
		load_hub(current_index)
	else:
		restart()


## [name, seconds or -1] for every level in the current world, in order.
func _world_times() -> Array:
	var world: String = current_info().world
	var rows := []
	for i in LevelList.LEVELS.size():
		if LevelList.LEVELS[i].world == world:
			rows.append([LevelList.LEVELS[i].name, session_times.get(i, -1.0)])
	return rows


## Called by an entrance hill (the title area's giant hill): watch the
## ball sink, wipe to black, load the level, lift the black.
func enter_level_through_hill(index: int) -> void:
	if _run_done or _loading:
		return
	_run_done = true
	timer_running = false
	entered_through_hill.emit(index)
	var my_run := _run_id
	await get_tree().create_timer(DROP_DELAY).timeout
	if my_run != _run_id:
		return
	await Transition.fade_out(FADE_TIME)
	if my_run == _run_id:
		load_level(index)


func _movement_pressed() -> bool:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO \
			or Input.is_action_pressed("jump")


## Formats seconds as m:ss.hh for the HUD.
static func format_time(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	var rest := seconds - minutes * 60.0
	return "%d:%05.2f" % [minutes, rest]
