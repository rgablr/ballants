class_name LevelList
## THE LEVEL LIST -- one entry per level, in play order. This is the only
## place that knows which levels exist, what order they come in, and what
## it costs to unlock each one.
##
## The anthill hub reads this list to build its tunnels: tunnel N leads to
## entry N. So to point a tunnel somewhere else, change the entry here.
##
## Each entry:
##   world              the world's name (shown on the HUD and results)
##   name               the level's name (spelled out in 3D letters over
##                      its tunnel in the hub)
##   par_time           seconds a good run should beat; a first finish under
##                      par earns a sugar crystal (see src/core/progress.gd)
##   crystals_required  how many crystals you need before the tunnel to this
##                      level is dug open. 0 = open from the start.
##   scene              the level's scene file
##
## To add a level: make a scene (see SETUP_NOTES.md "How to make a level"),
## then add a line here. To reorder: reorder the lines.
##
## Keys while playing: 1 / 2 / 3 / 4 / 5 jump to a level, 0 loads the test
## arena, H the anthill hub, T the title meadow, R restarts, U toggles the
## debug "all tunnels open" switch.

const LEVELS := [
	{
		"world": "Backyard Garden",
		"name": "Sidewalk Crack",
		"par_time": 45.0,
		"crystals_required": 0,
		"scene": "res://levels/garden/level_1_sidewalk_crack.tscn",
	},
	{
		"world": "Backyard Garden",
		"name": "Flowerbed Slalom",
		"par_time": 60.0,
		"crystals_required": 0,
		"scene": "res://levels/garden/level_2_flowerbed_slalom.tscn",
	},
	{
		"world": "Backyard Garden",
		"name": "Garden Hose Bridge",
		"par_time": 75.0,
		"crystals_required": 0,
		"scene": "res://levels/garden/level_3_garden_hose_bridge.tscn",
	},
	{
		"world": "Inside the Nest",
		"name": "Placeholder 4",
		"par_time": 60.0,
		"crystals_required": 2,
		"scene": "res://levels/nest/level_4_placeholder.tscn",
	},
	{
		"world": "Inside the Nest",
		"name": "Placeholder 5",
		"par_time": 60.0,
		"crystals_required": 4,
		"scene": "res://levels/nest/level_5_placeholder.tscn",
	},
]

## The title area: title screen + garden playground. The game opens here
## (key T / controller View button comes back). Its giant ant hill is the
## way into the anthill hub.
const TITLE := "res://levels/garden/title_meadow.tscn"

## The anthill hub: the cave inside the giant ant hill, with one tunnel per
## level above. Key H.
const HUB := "res://levels/hub/anthill_hub.tscn"

## The free-roam test environment (key 0). Not part of the level order.
const TEST_ARENA := "res://levels/test_arena.tscn"


## True when the entry after `index` belongs to a different world (or there
## is none): finishing it earns the "world complete" card.
static func is_last_of_world(index: int) -> bool:
	if index < 0 or index >= LEVELS.size():
		return false
	if index == LEVELS.size() - 1:
		return true
	return LEVELS[index + 1].world != LEVELS[index].world
