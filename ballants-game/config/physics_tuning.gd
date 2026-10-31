extends Node
## PHYSICS TUNING -- the one place to change how the game feels.
##
## Every number here is read by the game code at runtime. Change a value, save
## this file, and press F5 in Godot to feel the difference. Nothing else needs
## to change.
##
## Units: meters, seconds, kilograms. The ball is 1 meter across (radius 0.5),
## so "2 meters" means "2 ball-heights".
##
## This script is loaded as a global called "Tuning", so code reads values as
## Tuning.gravity, Tuning.max_speed, and so on.
##
## Press F1 in the game for sliders that change these live and can save
## them back into this file. The RANGES table at the bottom sets each
## slider's lowest and highest value.

## Fired whenever a value is changed through set_value() (the F1 panel).
## Objects that copy a value at startup (ball mass, camera distance...)
## listen to this and re-apply.
signal value_changed(value_name: String, value)


# ---------------------------------------------------------------- WORLD ----

## How hard everything falls. Real Earth gravity is 9.8. Games usually use
## more so that jumps feel quick and snappy instead of floaty.
var gravity := 18.0

## If the ball falls below this height (for example, off the edge of the
## world), it is put back at the level's start point.
var fall_respawn_y := -8.0


# ----------------------------------------------------------------- BALL ----

## Weight of the ball (with the ant). Heavier = pushes crates harder, but
## roll_acceleration below is "per kilogram", so weight alone won't change
## how fast you accelerate.
var ball_mass := 1.0

## How quickly you pick up speed when you hold a direction. Higher = snappier
## response. Lower = more "Super Monkey Ball" momentum, where you have to plan
## turns ahead. (This is the force per kilogram; a rolling ball converts about
## 70% of it into actual acceleration because some goes into spinning it.)
var roll_acceleration := 22.0

## Top rolling speed on flat ground. Holding a direction will not push you
## faster than this. Gravity (rolling down a ramp) still can.
var max_speed := 14.0

## When you push AGAINST the direction you're already moving, your push is
## multiplied by this. 1.0 = no help (pure momentum). 1.5 = stopping and
## reversing is 50% easier than accelerating.
var brake_multiplier := 1.3

## How much control you have while in the air, as a fraction of ground
## control. 0 = none (very old-school), 1 = same as on the ground.
var air_control := 0.3

## How quickly the ball slows down on its own when you let go. 0 = rolls
## forever. Higher = stops sooner. Keep this small for a momentum feel.
var rolling_resistance := 0.25

## How quickly the ball stops spinning on its own. Keep small.
var spin_resistance := 0.1

## Grip between the ball and the ground. 0 = ice, 1 = rubber on concrete.
## Low values make the ball slide instead of roll.
var ball_friction := 1.0

## How bouncy the ball is when it hits something. 0 = thud, 1 = superball.
var ball_bounce := 0.15


# ----------------------------------------------------------------- JUMP ----

## How high a jump goes at its peak, in meters, from flat ground.
## 1.0 = one ball-height.
var jump_height := 1.6

## Jump "forgiveness" after rolling off an edge: for this many seconds after
## leaving the ground you can still jump. Makes edges feel fair. Keep tiny.
var coyote_time := 0.12

## Jump "forgiveness" before landing: if you press jump this many seconds
## before touching down, the jump still happens on landing. Keep tiny.
var jump_buffer_time := 0.12

## How steep a surface can be and still count as "ground" you can jump from.
## 1.0 = only perfectly flat. 0.5 = up to about 60 degrees. 0 = even walls.
var ground_normal_min := 0.5


# --------------------------------------------------------------- CAMERA ----

## Distance from the ball to the camera, in meters.
var camera_distance := 6.0

## The camera looks at a point this far above the ball's center (meters), so
## the ball sits a bit below the middle of the screen and you see more ahead.
var camera_height_offset := 0.6

## Starting camera angle in degrees: 0 = level with the ball, 90 = top-down.
var camera_pitch_default := 22.0

## Limits for how far the player can tilt the camera up or down (degrees).
var camera_pitch_min := -10.0
var camera_pitch_max := 70.0

## How tightly the camera follows the ball. Higher = stiffer and more
## immediate. Lower = smoother and lazier, which can feel floaty.
var camera_follow_speed := 14.0

## Camera field of view in degrees. Bigger = see more, feels faster.
var camera_fov := 70.0

## The camera swings around behind the direction you're rolling by itself.
## false = fully manual camera.
var camera_auto_follow := true

## How quickly the camera swings behind you. Higher = snappier.
var camera_auto_follow_speed := 2.5

## After you move the mouse or right stick, the camera stays where you put
## it for this many seconds before it starts swinging back behind you.
var camera_look_hold_time := 1.2

## Below this speed the camera stops trying to swing behind you, so it
## doesn't twitch when you're nearly stopped.
var camera_auto_follow_min_speed := 1.5

## Mouse look speed. Small numbers; try 0.001 to 0.005.
var mouse_sensitivity := 0.0025

## Right-stick look speed, in how far it rotates per second at full tilt.
var stick_sensitivity := 2.8

## Flip vertical camera control (true = push up to look down).
var invert_camera_y := false


# -------------------------------------------------------- ANT (VISUAL) ----
# These only change how the ant LOOKS on the ball. They don't affect physics.

## How far the ant slides across the top of the ball when the ball speeds up
## or slows down, so it looks like it's struggling to keep its balance.
## 0 = ant always stays glued to the very top.
var ant_lean_per_accel := 0.035

## Maximum lean angle in radians (0.6 is about 35 degrees).
var ant_max_lean := 0.6

## How quickly the lean settles. Higher = twitchier, lower = lazier.
var ant_lean_smoothing := 8.0

## How quickly the ant turns to face the direction of travel.
var ant_turn_speed := 10.0

## How much the ant squashes when the ball lands. 0 = none, 0.3 = squashes
## to 70% height. It also stretches slightly on take-off.
var ant_land_squash := 0.3

## How long the landing squash takes to spring back, in seconds.
var ant_land_bounce_time := 0.35


# --------------------------------------------------- INTERACTIVE OBJECTS ----

## Weight of a pushable crate. Lighter than the ball = easy to shove around.
var crate_mass := 0.6

## Weight of a loose boulder. Heavier than the ball = it shoves YOU around.
var boulder_mass := 2.5

## Weight of a seesaw plank.
var seesaw_plank_mass := 1.5

## How high a bounce pad launches you, in meters.
var bounce_pad_height := 5.0


# ------------------------------------------------------- SLIDER RANGES ----
# Lowest and highest value the F1 panel's slider allows for each value.
# Only affects the panel. Values not listed get a guessed range.

const RANGES := {
	"gravity": [1.0, 50.0],
	"fall_respawn_y": [-50.0, 0.0],
	"ball_mass": [0.1, 10.0],
	"roll_acceleration": [1.0, 80.0],
	"max_speed": [1.0, 40.0],
	"brake_multiplier": [0.5, 4.0],
	"air_control": [0.0, 1.0],
	"rolling_resistance": [0.0, 3.0],
	"spin_resistance": [0.0, 3.0],
	"ball_friction": [0.0, 2.0],
	"ball_bounce": [0.0, 1.0],
	"jump_height": [0.0, 6.0],
	"coyote_time": [0.0, 0.5],
	"jump_buffer_time": [0.0, 0.5],
	"ground_normal_min": [0.0, 1.0],
	"camera_distance": [1.0, 20.0],
	"camera_height_offset": [-2.0, 4.0],
	"camera_pitch_default": [-10.0, 80.0],
	"camera_pitch_min": [-45.0, 45.0],
	"camera_pitch_max": [0.0, 89.0],
	"camera_follow_speed": [1.0, 40.0],
	"camera_fov": [40.0, 120.0],
	"camera_auto_follow_speed": [0.1, 10.0],
	"camera_look_hold_time": [0.0, 5.0],
	"camera_auto_follow_min_speed": [0.0, 10.0],
	"mouse_sensitivity": [0.0005, 0.01],
	"stick_sensitivity": [0.5, 8.0],
	"ant_lean_per_accel": [0.0, 0.15],
	"ant_max_lean": [0.0, 1.2],
	"ant_lean_smoothing": [1.0, 30.0],
	"ant_turn_speed": [1.0, 30.0],
	"ant_land_squash": [0.0, 0.6],
	"ant_land_bounce_time": [0.05, 1.0],
	"crate_mass": [0.05, 5.0],
	"boulder_mass": [0.1, 20.0],
	"seesaw_plank_mass": [0.1, 10.0],
	"bounce_pad_height": [0.5, 15.0],
}


# ----------------------------------------------------------- PLUMBING ----
# Code below here supports the F1 panel. No feel numbers live past this line.

const SOURCE_PATH := "res://config/physics_tuning.gd"


## Names of every tunable value above, in file order.
func get_value_names() -> Array[String]:
	var names: Array[String] = []
	for prop in get_script().get_script_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.type in [TYPE_FLOAT, TYPE_BOOL, TYPE_INT]:
			names.append(prop.name)
	return names


## Changes a value at runtime and tells listeners. Use this instead of
## assigning directly when the change should apply to live objects.
func set_value(value_name: String, value) -> void:
	if get(value_name) == value:
		return
	set(value_name, value)
	value_changed.emit(value_name, value)


## Slider range for a value: from RANGES, or a guess based on its current value.
func get_range(value_name: String) -> Array:
	if RANGES.has(value_name):
		return RANGES[value_name]
	var current: float = float(get(value_name))
	var span: float = max(abs(current) * 4.0, 1.0)
	return [min(0.0, current - span), max(0.0, current + span)]


## Reads the section headers and ## comments out of this file, so the panel
## can group sliders and show each value's explanation as a tooltip.
## Returns { value_name: { "section": String, "comment": String } }.
func get_descriptions() -> Dictionary:
	var result := {}
	var source := FileAccess.get_file_as_string(SOURCE_PATH)
	var section := ""
	var comment := ""
	var header := RegEx.create_from_string("^# -+ ([A-Z /()]+) -+$")
	var declaration := RegEx.create_from_string("^var (\\w+)\\s*:=")
	for raw_line in source.split("\n"):
		var line := raw_line.strip_edges()
		var header_match := header.search(line)
		if header_match:
			section = header_match.get_string(1).strip_edges().capitalize()
			comment = ""
			continue
		if line.begins_with("## "):
			comment += ("" if comment.is_empty() else " ") + line.substr(3)
			continue
		var decl_match := declaration.search(line)
		if decl_match:
			result[decl_match.get_string(1)] = {"section": section, "comment": comment}
		if not line.begins_with("#"):
			comment = ""
	return result


## Writes the current values back into this file, keeping every comment.
## Returns an error message, or "" on success.
func save_to_file() -> String:
	var source := FileAccess.get_file_as_string(SOURCE_PATH)
	if source.is_empty():
		return "Could not read " + SOURCE_PATH
	for value_name in get_value_names():
		var pattern := RegEx.create_from_string("(?m)^(var %s\\s*:=\\s*)([^\\s#]+)" % value_name)
		source = pattern.sub(source, "${1}" + _format_value(get(value_name)))
	var file := FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	if file == null:
		return "Could not write " + SOURCE_PATH
	file.store_string(source)
	file.close()
	return ""


func _format_value(value) -> String:
	if value is bool:
		return "true" if value else "false"
	if value is int:
		return str(value)
	var text := "%.4f" % value
	# Trim trailing zeros but always keep a decimal point so it stays a float.
	text = text.rstrip("0")
	if text.ends_with("."):
		text += "0"
	return text
