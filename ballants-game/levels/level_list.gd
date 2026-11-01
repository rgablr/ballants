class_name LevelList
## THE LEVEL LIST -- one entry per level. This is the only place that
## knows which levels exist, which tunnel leads to each, their target
## times, and what it costs to unlock each one.
##
## The anthill hub reads this list to build its tunnels: tunnel N leads to
## entry N (the first TUNNEL_COUNT entries). Entries after that are
## UNASSIGNED: they are not behind any tunnel, but the debug level keys
## still load them (keys 1-5 = the tunnels, 6-8 = the unassigned ones).
##
## Each entry:
##   world              the world's name (shown on the HUD and results)
##   name               the level's name (spelled out in 3D letters over
##                      its tunnel in the hub)
##   par_time           the TARGET TIME in seconds; finishing at or under
##                      it earns the level's time crystal (see
##                      src/core/progress.gd for all four crystals)
##   crystals_required  how many crystals you need before the tunnel to this
##                      level is dug open. 0 = open from the start.
##   scene              the level's scene file
##   unassigned         true = not behind a tunnel (kept for later)
##
## To add a level: make a scene (see SETUP_NOTES.md "How to make a level"),
## then add a line here. To put a level behind a tunnel: move it into the
## first five lines.
##
## Keys while playing: 1-8 jump to a level, 0 loads the test arena, H the
## anthill hub, T the title meadow, R restarts, U toggles the debug "all
## tunnels open" switch.

## How many tunnels the hub has (entries 0..TUNNEL_COUNT-1 sit behind them).
const TUNNEL_COUNT := 5

const LEVELS := [
	{
		"world": "Inside the Nest",
		"name": "Tunnel Drop",
		"par_time": 85.0,
		"crystals_required": 0,
		"scene": "res://levels/nest/level_1_tunnel_drop.tscn",
	},
	{
		"world": "Inside the Nest",
		"name": "Egg Chamber",
		"par_time": 62.0,
		"crystals_required": 0,
		"scene": "res://levels/nest/level_2_egg_chamber.tscn",
	},
	{
		"world": "Inside the Nest",
		"name": "Fungus Farm",
		"par_time": 70.0,
		"crystals_required": 0,
		"scene": "res://levels/nest/level_3_fungus_farm.tscn",
	},
	{
		"world": "Inside the Nest",
		"name": "Worker Rush",
		"par_time": 75.0,
		"crystals_required": 5,
		"scene": "res://levels/nest/level_4_worker_rush.tscn",
	},
	{
		"world": "Inside the Nest",
		"name": "Collapsing Gallery",
		"par_time": 65.0,
		"crystals_required": 8,
		"scene": "res://levels/nest/level_5_collapsing_gallery.tscn",
	},
	# The Backyard Garden levels: unhooked from the tunnels for now, kept
	# for later (key 6 / 7 / 8).
	{
		"world": "Backyard Garden",
		"name": "Sidewalk Crack",
		"par_time": 45.0,
		"crystals_required": 0,
		"scene": "res://levels/garden/level_1_sidewalk_crack.tscn",
		"unassigned": true,
	},
	{
		"world": "Backyard Garden",
		"name": "Flowerbed Slalom",
		"par_time": 60.0,
		"crystals_required": 0,
		"scene": "res://levels/garden/level_2_flowerbed_slalom.tscn",
		"unassigned": true,
	},
	{
		"world": "Backyard Garden",
		"name": "Garden Hose Bridge",
		"par_time": 75.0,
		"crystals_required": 0,
		"scene": "res://levels/garden/level_3_garden_hose_bridge.tscn",
		"unassigned": true,
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


## True when this entry sits behind a hub tunnel.
static func has_tunnel(index: int) -> bool:
	return index >= 0 and index < mini(TUNNEL_COUNT, LEVELS.size()) and not LEVELS[index].get("unassigned", false)
