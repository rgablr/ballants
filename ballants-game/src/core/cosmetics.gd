extends Node
## COSMETICS -- how the player has dressed up their ant and ball: which
## sports ball they ride, and the color of each part of the ant (head,
## thorax, abdomen, antennae, legs, eyes). Chosen in the customize menu,
## saved to the player's computer (user://cosmetics.cfg) so it's kept
## between sessions, and applied to every ball and ant on screen the moment
## it changes.
##
## Loaded as a global called "Cosmetics".

signal changed

const SAVE_PATH := "user://cosmetics.cfg"

## The balls you can pick. "shader" 0 = the soccer ball's own pattern,
## otherwise the style number in sports_ball.gdshader.
const BALLS := [
	{"name": "Soccer ball", "style": 0},
	{"name": "Basketball", "style": 1},
	{"name": "Volleyball", "style": 2},
	{"name": "Beach ball", "style": 3},
	{"name": "Tennis ball", "style": 4},
	{"name": "Baseball", "style": 5},
	{"name": "Bowling ball", "style": 6},
	{"name": "8-ball", "style": 7},
	{"name": "Golf ball", "style": 8},
	{"name": "Playground ball", "style": 9},
]

## The colors on offer for the body parts, and for legs/antennae and eyes.
const BODY_COLORS := [
	["Red ant", Color(0.45, 0.19, 0.10)],
	["Fire red", Color(0.78, 0.16, 0.08)],
	["Black", Color(0.1, 0.09, 0.09)],
	["Golden", Color(0.85, 0.6, 0.18)],
	["Orange", Color(0.95, 0.45, 0.1)],
	["Leaf green", Color(0.3, 0.62, 0.22)],
	["Teal", Color(0.12, 0.55, 0.55)],
	["Sky blue", Color(0.3, 0.55, 0.92)],
	["Royal blue", Color(0.15, 0.22, 0.7)],
	["Purple", Color(0.48, 0.25, 0.72)],
	["Pink", Color(0.95, 0.5, 0.7)],
	["White", Color(0.92, 0.9, 0.86)],
	["Grey", Color(0.5, 0.5, 0.52)],
]
const LIMB_COLORS := [
	["Dark brown", Color(0.22, 0.09, 0.05)],
	["Black", Color(0.05, 0.05, 0.05)],
	["Red", Color(0.7, 0.12, 0.08)],
	["Golden", Color(0.8, 0.58, 0.18)],
	["Green", Color(0.25, 0.55, 0.2)],
	["Blue", Color(0.2, 0.35, 0.8)],
	["Purple", Color(0.45, 0.22, 0.65)],
	["Pink", Color(0.92, 0.48, 0.66)],
	["White", Color(0.9, 0.9, 0.88)],
]
const EYE_COLORS := [
	["Black", Color(0.03, 0.03, 0.03)],
	["Red", Color(0.85, 0.1, 0.08)],
	["Green", Color(0.2, 0.85, 0.3)],
	["Blue", Color(0.2, 0.5, 1.0)],
	["Yellow", Color(1.0, 0.85, 0.1)],
	["Purple", Color(0.6, 0.25, 0.9)],
	["White", Color(0.95, 0.95, 0.95)],
]

## The parts you can recolor, in menu order: id, label, which palette.
const PARTS := [
	["antennae", "Antennae", "limb"],
	["eyes", "Eyes", "eye"],
	["head", "Head", "body"],
	["thorax", "Thorax", "body"],
	["abdomen", "Abdomen", "body"],
	["legs", "Legs", "limb"],
]

## Current choices: palette index per part, and the ball index.
var choices := {
	"ball": 0,
	"head": 0, "thorax": 0, "abdomen": 0,
	"antennae": 0, "legs": 0, "eyes": 0,
}

const SOCCER_SHADER := preload("res://assets/placeholders/soccer_ball.gdshader")
const SPORTS_SHADER := preload("res://assets/placeholders/sports_ball.gdshader")


func _ready() -> void:
	load_choices()


func palette_for(part: String) -> Array:
	for p in PARTS:
		if p[0] == part:
			match p[2]:
				"body": return BODY_COLORS
				"eye": return EYE_COLORS
				_: return LIMB_COLORS
	return BODY_COLORS


## How many options a slot has ("ball" or a part id).
func option_count(slot: String) -> int:
	return BALLS.size() if slot == "ball" else palette_for(slot).size()


## The name of the current option for a slot ("Basketball", "Teal"...).
func option_name(slot: String) -> String:
	if slot == "ball":
		return BALLS[choices.ball].name
	return palette_for(slot)[choices[slot]][0]


func color_of(part: String) -> Color:
	return palette_for(part)[choices[part]][1]


## Steps a slot forward (+1) or back (-1) through its options, wrapping.
func step(slot: String, direction: int) -> void:
	choices[slot] = posmod(int(choices[slot]) + direction, option_count(slot))
	save_choices()
	changed.emit()


## Colors an ant model that supports it (set_part_color(part, color)).
func apply_to_ant(model: Node) -> void:
	if model == null or not model.has_method("set_part_color"):
		return
	for p in PARTS:
		model.set_part_color(p[0], color_of(p[0]))


## Gives a ball model the chosen style: finds its mesh and swaps the
## material. (Collision never changes; every ball is the same sphere.)
func apply_to_ball(model: Node) -> void:
	var mesh := model as MeshInstance3D
	if mesh == null and model:
		var found := model.find_children("*", "MeshInstance3D", true, false)
		mesh = found[0] if not found.is_empty() else null
	if mesh == null:
		return
	var style: int = BALLS[choices.ball].style
	var mat := ShaderMaterial.new()
	if style == 0:
		mat.shader = SOCCER_SHADER
	else:
		mat.shader = SPORTS_SHADER
		mat.set_shader_parameter("style", style)
	mesh.material_override = mat


func save_choices() -> void:
	var file := ConfigFile.new()
	for key in choices:
		file.set_value("cosmetics", key, choices[key])
	file.save(SAVE_PATH)


func load_choices() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	for key in choices:
		var value := int(file.get_value("cosmetics", key, choices[key]))
		choices[key] = clampi(value, 0, option_count(key) - 1)
