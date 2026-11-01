@tool
class_name AnthillTheme
extends Node3D
## ANTHILL THEME -- the one place that defines how the "Inside the Nest"
## world looks: a dark, warm, foggy underground with packed dirt in browns
## and oranges, and glowing fungus / amber crystals for light so a path
## is always readable. Drop anthill_theme.tscn into a level and it
## matches the hub and the other nest levels.
##
## Same low-poly style as the hub (src/objects/hub/): flat colors, strong
## silhouettes, no textures. The sky is pitch dark; fog closes in so the
## level floats in the earth. There is NO sun: every nest piece that
## should be visible carries or sits near a glow (see src/objects/nest/
## glow_fungus.gd and wall_crystal.gd; DirtTrack can place fungus along
## its walls by itself).
##
## Materials are shared via AnthillTheme.material("dirt") etc., so a color
## change here recolors every nest piece at once.

const COLORS := {
	"dirt": Color(0.5, 0.3, 0.15),          # the floor you roll on
	"dirt_light": Color(0.62, 0.4, 0.2),    # ledges, lips, lit edges
	"dirt_dark": Color(0.36, 0.2, 0.1),     # walls, undersides
	"dirt_deep": Color(0.24, 0.13, 0.07),   # far walls, ceilings
	"packed": Color(0.44, 0.27, 0.14),      # packed earth (walls' faces)
	"clay": Color(0.7, 0.42, 0.22),         # orange clay bands
	"root": Color(0.58, 0.45, 0.3),
	"root_dark": Color(0.42, 0.32, 0.2),
	"fungus_cap": Color(1.0, 0.82, 0.45),
	"fungus_stem": Color(0.9, 0.78, 0.6),
	"fungus_blue_cap": Color(0.6, 0.85, 1.0),
	"crystal": Color(1.0, 0.75, 0.4),
	"crumble": Color(0.56, 0.36, 0.19),     # the false wall's loose dirt
	"egg": Color(0.95, 0.92, 0.82),
	"spore": Color(0.75, 0.95, 0.7),
	"crack": Color(0.16, 0.09, 0.05),
}

## Glow colors (emission) used by the lit pieces.
const FUNGUS_GLOW := Color(1.0, 0.72, 0.3)
const FUNGUS_BLUE_GLOW := Color(0.45, 0.75, 1.0)
const CRYSTAL_GLOW := Color(1.0, 0.58, 0.18)

## The fog and ambient, shared with the hub's look.
const BACKGROUND := Color(0.035, 0.022, 0.013)
const AMBIENT := Color(0.55, 0.36, 0.22)
const AMBIENT_ENERGY := 0.5
const FOG_COLOR := Color(0.24, 0.13, 0.065)
const FOG_DENSITY := 0.0085

static var _materials := {}


## A shared material by name (see COLORS). Cached; the same object is
## returned every time, so pieces share it.
static func material(name: String) -> StandardMaterial3D:
	if _materials.has(name):
		return _materials[name]
	var m := StandardMaterial3D.new()
	var color: Color = COLORS.get(name, Color.MAGENTA)
	m.albedo_color = color
	m.roughness = 0.95
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.3
	_materials[name] = m
	return m


## A glowing material: albedo plus emission. Cached by name.
static func glow_material(name: String, albedo: Color, glow: Color, energy: float) -> StandardMaterial3D:
	var key := "glow:" + name
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = 0.7
	m.emission_enabled = true
	m.emission = glow
	m.emission_energy_multiplier = energy
	_materials[key] = m
	return m


## Fog density for this level (thicker = shorter view). The default suits
## 8-12 m wide tunnels; a big chamber can thin it.
@export var fog_density := FOG_DENSITY
## A faint overall light so nothing is ever pure black. 0 = fungus only.
@export var fill_light_energy := 0.12


func _ready() -> void:
	_build_environment()


func _build_environment() -> void:
	for child in get_children():
		child.queue_free()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT
	environment.ambient_light_energy = AMBIENT_ENERGY
	environment.fog_enabled = true
	environment.fog_light_color = FOG_COLOR
	environment.fog_density = fog_density
	environment.fog_sky_affect = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.7
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.name = "NestEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	if fill_light_energy > 0.0:
		# A very weak light from above so slopes and walls shade a little
		# even far from any fungus. No shadows (it is fill, not a sun).
		var fill := DirectionalLight3D.new()
		fill.name = "Fill"
		fill.light_color = Color(1.0, 0.8, 0.6)
		fill.light_energy = fill_light_energy
		fill.rotation_degrees = Vector3(-62, 25, 0)
		fill.shadow_enabled = false
		add_child(fill)
