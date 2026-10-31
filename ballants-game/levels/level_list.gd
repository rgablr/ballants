class_name LevelList
## THE LEVEL LIST -- one entry per level, in play order. This is the only
## place that knows which levels exist and what order they come in.
##
## To add a level: make a scene (see SETUP_NOTES.md "How to make a level"),
## then add a line here. To reorder: reorder the lines. "par_time" is the
## target time in seconds a good run should beat.
##
## Keys while playing: 1 / 2 / 3 jump to a level, 0 loads the test arena,
## R restarts.

const LEVELS := [
	{
		"world": "Backyard Garden",
		"name": "Sidewalk Crack",
		"par_time": 45.0,
		"scene": "res://levels/garden/level_1_sidewalk_crack.tscn",
	},
	{
		"world": "Backyard Garden",
		"name": "Flowerbed Slalom",
		"par_time": 60.0,
		"scene": "res://levels/garden/level_2_flowerbed_slalom.tscn",
	},
	{
		"world": "Backyard Garden",
		"name": "Garden Hose Bridge",
		"par_time": 75.0,
		"scene": "res://levels/garden/level_3_garden_hose_bridge.tscn",
	},
]

## The title area: title screen + garden playground; its giant ant hill
## starts the first level. The game opens here (key T / controller View
## button comes back).
const TITLE := "res://levels/garden/title_meadow.tscn"

## The free-roam test environment (key 0). Not part of the level order.
const TEST_ARENA := "res://levels/test_arena.tscn"
