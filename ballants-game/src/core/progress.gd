extends Node
## PROGRESS -- what the player has achieved this play session: sugar
## crystals earned per level, the Queen's Crystal Pouch, and whether the
## hub's opening cutscene has played.
##
## SAVING: the save profiles (src/core/save_game.gd, global "Saves") write
## this object out with to_dict() whenever `changed` fires, and read it
## back with from_dict() when a profile is picked. Anything that should be
## kept must be listed in to_dict() and must emit `changed` when it
## changes (set_flag() does both for the simple yes/no ones).
## debug_unlock_all and the run bookkeeping are never saved.
##
## CRYSTALS. Every level has four sugar crystals, one per SLOT:
##   SLOT_COMPLETE  finish the level
##   SLOT_TIME      finish it at or under its target time (par_time in the
##                  level list)
##   SLOT_HIDDEN_A  the first hidden crystal placed in the level
##   SLOT_HIDDEN_B  the second hidden crystal
## Each counts ONCE: replaying keeps the best. A hidden crystal is yours
## the moment you roll through it (a restart does not take it back); the
## other two are checked when the level is finished. The hub's tunnels
## compare the total with each level's crystals_required.
##
## Loaded as a global called "Progress".

signal changed

enum { SLOT_COMPLETE, SLOT_TIME, SLOT_HIDDEN_A, SLOT_HIDDEN_B }
const SLOT_COUNT := 4
const SLOT_NAMES := ["Finished", "Target time", "Hidden 1", "Hidden 2"]

## Sugar crystals earned so far (kept in step with level_crystals).
var crystals := 0
## level index -> [bool, bool, bool, bool], one per slot (see the enum).
var level_crystals := {}
## The Queen's gift: the Crystal Pouch (it is what holds the crystals).
var has_queen_item := false
## The hub's opening cutscene has played this session.
var hub_intro_seen := false
## Debug switch (key U): every tunnel counts as unlocked.
var debug_unlock_all := false
## The birthday easter egg (see src/objects/hub/birthday_party.gd): the
## mysterious key has been found, and the jail cell has been opened with it.
var has_mystery_key := false
var jail_unlocked := false
## The party has been thrown: confetti falls in the hub from then on (the
## "you found the easter egg" reward).
var birthday_party_done := false
## Best finishing time per level index (seconds).
var best_times := {}
## A cutscene to replay from the progress screen ("intro" / "party"); the
## hub reads and clears it on arrival.
var replay := ""

## The yes/no things a profile keeps (set_flag / to_dict use this list).
const FLAGS := ["has_queen_item", "hub_intro_seen", "has_mystery_key", "jail_unlocked", "birthday_party_done"]

## Why the hub was just loaded; the hub reads and clears this.
##   -1  fresh arrival: fall in through the top of the hill
##   N   returning from level N: appear in front of tunnel N
var hub_return_from := -1

## Slots earned since the current run started (level load), so the
## results card can say "new" against "earned before".
var _earned_this_run := {}


## Sets one of FLAGS and tells the save system.
func set_flag(flag: String, on := true) -> void:
	if not flag in FLAGS or bool(get(flag)) == on:
		return
	set(flag, on)
	changed.emit()


## Back to a brand-new game (a new or switched profile).
func reset() -> void:
	level_crystals = {}
	best_times = {}
	for flag in FLAGS:
		set(flag, false)
	_earned_this_run = {}
	hub_return_from = -1
	replay = ""
	_recount()
	changed.emit()


## Everything a save profile keeps.
func to_dict() -> Dictionary:
	var data := {"level_crystals": level_crystals.duplicate(true), "best_times": best_times.duplicate()}
	for flag in FLAGS:
		data[flag] = get(flag)
	return data


## Loads what to_dict() wrote (missing entries start empty, so older saves
## still load after new things are added).
func from_dict(data: Dictionary) -> void:
	level_crystals = {}
	var crystals_in: Dictionary = data.get("level_crystals", {})
	for key in crystals_in:
		var flags: Array = crystals_in[key]
		var row := [false, false, false, false]
		for slot in mini(flags.size(), SLOT_COUNT):
			row[slot] = bool(flags[slot])
		level_crystals[int(key)] = row
	best_times = {}
	var times_in: Dictionary = data.get("best_times", {})
	for key in times_in:
		best_times[int(key)] = float(times_in[key])
	for flag in FLAGS:
		set(flag, bool(data.get(flag, false)))
	_earned_this_run = {}
	_recount()
	changed.emit()


## The level manager calls this on every scene change.
func begin_run() -> void:
	_earned_this_run = {}


## Called by the level manager when a level is finished. Returns the state
## of the level's four slots for the results card: one of "new" (earned
## just now), "old" (earned on an earlier run) or "none", per slot.
func record_finish(level_index: int, time: float, par: float) -> Array:
	_award(level_index, SLOT_COMPLETE)
	if time <= par:
		_award(level_index, SLOT_TIME)
	if level_index >= 0 and (not best_times.has(level_index) or time < float(best_times[level_index])):
		best_times[level_index] = time
		changed.emit()
	return slot_states(level_index)


## Called by a hidden crystal when the ball rolls through it. Returns true
## when it was new (so the piece can celebrate), false if already owned.
func collect_hidden(level_index: int, which: int) -> bool:
	return _award(level_index, SLOT_HIDDEN_A + clampi(which, 0, 1))


## True when that slot's crystal has been earned (any time).
func has_crystal(level_index: int, slot: int) -> bool:
	if not level_crystals.has(level_index):
		return false
	return bool(level_crystals[level_index][slot])


## "new" / "old" / "none" for each of a level's four slots.
func slot_states(level_index: int) -> Array:
	var states := []
	for slot in SLOT_COUNT:
		if not has_crystal(level_index, slot):
			states.append("none")
		elif _earned_this_run.has([level_index, slot]):
			states.append("new")
		else:
			states.append("old")
	return states


## How many of a level's four crystals are earned.
func level_count(level_index: int) -> int:
	var n := 0
	for slot in SLOT_COUNT:
		if has_crystal(level_index, slot):
			n += 1
	return n


## Every crystal there is to find: four per level behind a tunnel (the
## unassigned levels' crystals count in the pouch but not in this total).
func crystals_total() -> int:
	var levels := 0
	for i in LevelList.LEVELS.size():
		if LevelList.has_tunnel(i):
			levels += 1
	return levels * SLOT_COUNT


func _award(level_index: int, slot: int) -> bool:
	if level_index < 0:
		return false
	if not level_crystals.has(level_index):
		level_crystals[level_index] = [false, false, false, false]
	if level_crystals[level_index][slot]:
		return false
	level_crystals[level_index][slot] = true
	_earned_this_run[[level_index, slot]] = true
	_recount()
	changed.emit()
	return true


func _recount() -> void:
	crystals = 0
	for flags in level_crystals.values():
		for flag in flags:
			if flag:
				crystals += 1


## True when the tunnel to this level is dug open.
func is_unlocked(level_index: int) -> bool:
	if debug_unlock_all:
		return true
	if level_index < 0 or level_index >= LevelList.LEVELS.size():
		return false
	return crystals >= int(LevelList.LEVELS[level_index].crystals_required)


func crystals_needed(level_index: int) -> int:
	if level_index < 0 or level_index >= LevelList.LEVELS.size():
		return 0
	return int(LevelList.LEVELS[level_index].crystals_required)


func toggle_debug_unlock() -> void:
	debug_unlock_all = not debug_unlock_all
	print("[progress] debug unlock all tunnels: %s" % ("ON" if debug_unlock_all else "off"))
	changed.emit()


## Debug / tests: set the crystal total directly by filling slots in level
## order (so the tunnels' locks can be checked at any count).
func debug_set_crystals(count: int) -> void:
	level_crystals = {}
	_earned_this_run = {}
	var left := clampi(count, 0, crystals_total())
	for i in LevelList.LEVELS.size():
		if left <= 0:
			break
		var flags := [false, false, false, false]
		for slot in SLOT_COUNT:
			if left > 0:
				flags[slot] = true
				left -= 1
		level_crystals[i] = flags
	_recount()
	changed.emit()


func give_queen_item() -> void:
	set_flag("has_queen_item")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_unlock_all"):
		toggle_debug_unlock()
