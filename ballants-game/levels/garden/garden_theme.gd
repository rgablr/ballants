@tool
class_name GardenTheme
extends Node3D
## GARDEN THEME -- the one place that defines how the Backyard Garden
## world looks: sky, sun, fog, and the shared materials every garden piece
## uses. Drop garden_theme.tscn into a level and it matches the others.
##
## Scale: the ball is 1 m across and we are ant-sized, so think of 1 m as
## about one pea. Grass blades are 2-4 m tall, flower stems 8-14 m, a
## sidewalk slab 12 m square, a pebble 1-3 m. Keep those proportions.
##
## Materials are shared via GardenTheme.material("grass") etc., so a color
## change here recolors every piece at once.

const COLORS := {
	"grass": Color(0.42, 0.72, 0.28),
	"grass_dark": Color(0.3, 0.58, 0.22),
	"dirt": Color(0.5, 0.36, 0.22),
	"dirt_light": Color(0.62, 0.47, 0.3),
	"sidewalk": Color(0.8, 0.78, 0.72),
	"sidewalk_crack": Color(0.42, 0.4, 0.36),
	"stem": Color(0.36, 0.62, 0.26),
	"leaf": Color(0.38, 0.68, 0.3),
	"leaf_wet": Color(0.3, 0.6, 0.35),
	"petal_pink": Color(0.95, 0.5, 0.65),
	"petal_yellow": Color(0.98, 0.82, 0.3),
	"petal_white": Color(0.96, 0.95, 0.9),
	"petal_purple": Color(0.6, 0.45, 0.85),
	"flower_center": Color(0.9, 0.7, 0.2),
	"pebble": Color(0.6, 0.6, 0.58),
	"pebble_dark": Color(0.45, 0.45, 0.47),
	"water": Color(0.35, 0.6, 0.9, 0.7),
	"pot": Color(0.78, 0.42, 0.28),
	"pot_rim": Color(0.7, 0.36, 0.24),
	"hose": Color(0.2, 0.55, 0.3),
	"hose_stripe": Color(0.9, 0.8, 0.25),
	"wood": Color(0.55, 0.4, 0.25),
}

static var _materials := {}


## A shared material by name (see COLORS). Cached; the same object is
## returned every time, so pieces share it.
static func material(name: String) -> StandardMaterial3D:
	if _materials.has(name):
		return _materials[name]
	var m := StandardMaterial3D.new()
	var color: Color = COLORS.get(name, Color.MAGENTA)
	m.albedo_color = color
	m.roughness = 0.9
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.2
	_materials[name] = m
	return m


func _ready() -> void:
	_build_sky_and_sun()


func _build_sky_and_sun() -> void:
	for child in get_children():
		child.queue_free()

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.4, 0.66, 0.98)
	sky_material.sky_horizon_color = Color(0.82, 0.9, 1.0)
	sky_material.ground_bottom_color = Color(0.3, 0.45, 0.25)
	sky_material.ground_horizon_color = Color(0.82, 0.9, 1.0)
	sky_material.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.8
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.8, 0.9, 1.0)
	environment.fog_density = 0.004
	environment.fog_sky_affect = 0.2

	var world_environment := WorldEnvironment.new()
	world_environment.name = "GardenEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.light_energy = 1.4
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)
