extends Node
## PROGRESS -- what the player has achieved this play session: sugar
## crystals earned, which levels have paid out, whether the Queen's item
## has been received, and whether the hub's opening cutscene has played.
##
## NOTHING IS SAVED TO DISK YET. Everything here resets when the game is
## closed. When saving is built, this is the one object to serialize.
##
## Crystals: a level's first finish at or under its par time earns one
## crystal. (Hidden bonus crystals inside levels are not built yet.) The
## hub's tunnels compare `crystals` with each level's crystals_required
## from the level list.
##
## Loaded as a global called "Progress".

signal changed

## Sugar crystals earned so far.
var crystals := 0
## Level indices that have already paid out their par crystal.
var par_crystal_awarded := {}
## The Queen's gift (a placeholder item for now).
var has_queen_item := false
## The hub's opening cutscene has played this session.
var hub_intro_seen := false
## Debug switch (key U): every tunnel counts as unlocked.
var debug_unlock_all := false

## Why the hub was just loaded; the hub reads and clears this.
##   -1  fresh arrival: fall in through the top of the hill
##   N   returning from level N: appear in front of tunnel N
var hub_return_from := -1


## Called by the level manager when a level is finished.
func record_finish(level_index: int, time: float, par: float) -> void:
	if time <= par and not par_crystal_awarded.has(level_index):
		par_crystal_awarded[level_index] = true
		crystals += 1
		changed.emit()


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


func give_queen_item() -> void:
	has_queen_item = true
	changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_unlock_all"):
		toggle_debug_unlock()
