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


## The garden fence is placed this far (meters) beyond the farthest part
## of the course, all the way round, so no scenery ever sits next to the
## track. The ring is centered on the course, not on this node.
@export var backdrop_margin := 70.0
## The fence ring is never smaller than this radius (meters).
@export var backdrop_min_radius := 140.0
## Height of the lawn the whole level floats above. Visual only.
@export var backdrop_lawn_y := -6.0
## Turn the surrounding scenery off for small test scenes.
@export var backdrop_enabled := true


const SKY_SHADER := preload("res://levels/garden/garden_sky.gdshader")

var backdrop_radius := 160.0   # worked out from the course in _build_backdrop
var _center := Vector3.ZERO


func _ready() -> void:
	_build_sky_and_sun()
	if backdrop_enabled:
		# Wait until every piece of the course exists, then measure it.
		_build_backdrop.call_deferred()


## Scenery around the level so it isn't floating in a void: a giant lawn
## far below, a picket fence ring, bushes inside the fence and giant trees
## outside it. The houses, clouds and sun are painted on the sky (see
## garden_sky.gdshader). None of the scenery has collision, so all of it
## stays at least backdrop_margin meters from anything you can touch.
func _build_backdrop() -> void:
	_measure_course()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var root := Node3D.new()
	root.name = "Backdrop"
	root.top_level = true
	root.position = Vector3(_center.x, 0.0, _center.z)
	add_child(root)

	# Lawn: a huge disc far below.
	var lawn := MeshInstance3D.new()
	var lawn_mesh := CylinderMesh.new()
	lawn_mesh.top_radius = backdrop_radius * 1.3
	lawn_mesh.bottom_radius = backdrop_radius * 1.3
	lawn_mesh.height = 1.0
	lawn_mesh.radial_segments = 48
	lawn_mesh.material = material("grass")
	lawn.mesh = lawn_mesh
	lawn.position = Vector3(0, backdrop_lawn_y - 0.5, 0)
	root.add_child(lawn)

	# Picket fence ring: posts with two rails.
	var post_count := 96
	var fence_height := 24.0
	var fence_y := backdrop_lawn_y
	for i in post_count:
		var angle := TAU * i / post_count
		var pos := Vector3(cos(angle) * backdrop_radius, fence_y, sin(angle) * backdrop_radius)
		var post := _box(root, pos + Vector3.UP * fence_height * 0.5, Vector3(2.0, fence_height, 2.0), "wood")
		post.rotation.y = -angle
		# Picket top: a small pyramid-ish cap.
		var cap := _box(root, pos + Vector3.UP * (fence_height + 0.8), Vector3(2.4, 1.6, 2.4), "wood")
		cap.rotation = Vector3(0, -angle, 0)
		cap.scale = Vector3(1, 1, 1)
	var rail_segments := post_count
	for i in rail_segments:
		var a0 := TAU * i / rail_segments
		var a1 := TAU * (i + 1) / rail_segments
		var p0 := Vector3(cos(a0) * backdrop_radius, 0, sin(a0) * backdrop_radius)
		var p1 := Vector3(cos(a1) * backdrop_radius, 0, sin(a1) * backdrop_radius)
		for h in [fence_height * 0.35, fence_height * 0.75]:
			var rail := _box(root, (p0 + p1) * 0.5 + Vector3.UP * (fence_y + h), Vector3(1.0, 1.6, p0.distance_to(p1) + 1.0), "wood")
			rail.look_at_from_position(rail.position, rail.position + (p1 - p0), Vector3.UP)

	# Bushes just inside the fence.
	for i in 40:
		var angle := rng.randf() * TAU
		var r := backdrop_radius * rng.randf_range(0.82, 0.96)
		var pos := Vector3(cos(angle) * r, backdrop_lawn_y, sin(angle) * r)
		var size := rng.randf_range(8.0, 16.0)
		_sphere(root, pos + Vector3.UP * size * 0.4, size, Vector3(1.0, 0.75, 1.0), "grass_dark" if rng.randf() < 0.5 else "leaf")

	# Giant trees outside the fence.
	for i in 7:
		var angle := TAU * i / 7.0 + rng.randf_range(-0.2, 0.2)
		var r := backdrop_radius * rng.randf_range(1.05, 1.25)
		var pos := Vector3(cos(angle) * r, backdrop_lawn_y, sin(angle) * r)
		var trunk_height := rng.randf_range(60.0, 90.0)
		_cylinder(root, pos + Vector3.UP * trunk_height * 0.5, 4.0, 6.0, trunk_height, "wood")
		var canopy := rng.randf_range(36.0, 50.0)
		_sphere(root, pos + Vector3.UP * (trunk_height + canopy * 0.3), canopy, Vector3(1.0, 0.8, 1.0), "leaf")
		_sphere(root, pos + Vector3(canopy * 0.4, trunk_height + canopy * 0.1, 0), canopy * 0.7, Vector3.ONE, "grass_dark")


## Finds the middle and size of everything solid in the level (every
## collision shape on a physics body; trigger zones don't count), and sizes
## the fence ring to clear it by backdrop_margin.
func _measure_course() -> void:
	var level := get_parent()
	var box := AABB()
	var first := true
	if level:
		for shape in level.find_children("*", "CollisionShape3D", true, false):
			var cs := shape as CollisionShape3D
			if cs.shape == null or not (cs.get_parent() is PhysicsBody3D) or is_ancestor_of(cs):
				continue
			var mesh := cs.shape.get_debug_mesh()
			if mesh == null:
				continue
			var shape_box := cs.global_transform * mesh.get_aabb()
			box = shape_box if first else box.merge(shape_box)
			first = false
	if first:
		_center = global_position
		backdrop_radius = backdrop_min_radius
		return
	_center = box.get_center()
	var half := Vector2(box.size.x, box.size.z) * 0.5
	backdrop_radius = maxf(half.length() + backdrop_margin, backdrop_min_radius)


func _box(parent: Node3D, pos: Vector3, size: Vector3, material_name: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material(material_name)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)
	return instance


func _sphere(parent: Node3D, pos: Vector3, diameter: float, scale_by: Vector3, material_name: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = diameter * 0.5
	mesh.height = diameter
	mesh.radial_segments = 10
	mesh.rings = 5
	mesh.material = material(material_name)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_by
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, pos: Vector3, top_radius: float, bottom_radius: float, height: float, material_name: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.material = material(material_name)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)
	return instance


func _build_sky_and_sun() -> void:
	for child in get_children():
		child.queue_free()

	# The painted sky: gradient, sun, clouds, and the neighbourhood on the
	# horizon. Colors and amounts are uniforms in garden_sky.gdshader.
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
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
	environment.fog_density = 0.002   # thin: far flowers must stay visible as landmarks
	environment.fog_sky_affect = 0.2

	var world_environment := WorldEnvironment.new()
	world_environment.name = "GardenEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.light_energy = 1.4
	# Lower than overhead so the sun disc shows up in the sky when you look
	# toward it, and shadows read well at ant scale.
	sun.rotation_degrees = Vector3(-36, 32, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)
