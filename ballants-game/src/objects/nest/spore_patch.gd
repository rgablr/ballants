@tool
class_name SporePatch
extends SlickPatch
## SPORE PATCH -- a pale, powdery stretch of floor thick with fungus
## spores: slick and low-grip, so the ball keeps sliding and barely
## steers or brakes (a SlickPatch whose grip comes from the physics
## config, Tuning.spore_grip). Set your speed BEFORE you roll onto it.
##
## Put the node's origin ON the floor (it is a zone plus looks; the floor
## underneath does the holding up). `size` is the zone (x by z on the
## floor; y is how tall the zone is, keep it about 1.2 so a rolling ball's
## center is inside and a jump leaves it). The look: a lighter powdery
## floor laid 2 cm above the surface, a scatter of pale puffball nubs, a
## soft pale light and drifting spore particles (SporeCloud), so it reads
## as different from dirt even in the dark.

## Off = use `grip` as set in the scene instead of Tuning.spore_grip.
@export var grip_from_tuning := true
@export var seed := 1

const FLOOR_COLOR := Color(0.83, 0.86, 0.72)
const FLOOR_GLOW := Color(0.7, 0.95, 0.65)
const PUFF_COLOR := Color(0.95, 0.97, 0.88)


func _ready() -> void:
	if grip_from_tuning and not Engine.is_editor_hint():
		grip = Tuning.spore_grip
		Tuning.value_changed.connect(func(n: String, v):
			if n == "spore_grip":
				grip = float(v))
	super._ready()
	_build_look()


func _build_look() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var look := Node3D.new()
	look.name = "Look"
	add_child(look)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = FLOOR_COLOR
	floor_mat.roughness = 1.0
	floor_mat.emission_enabled = true
	floor_mat.emission = FLOOR_GLOW
	floor_mat.emission_energy_multiplier = 0.12
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	plane.material = floor_mat
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = plane
	floor_mi.position.y = 0.02
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	look.add_child(floor_mi)

	# Powdery blotches a shade lighter, so the patch is not one flat color.
	var blotch_mat := StandardMaterial3D.new()
	blotch_mat.albedo_color = PUFF_COLOR
	blotch_mat.roughness = 1.0
	blotch_mat.emission_enabled = true
	blotch_mat.emission = FLOOR_GLOW
	blotch_mat.emission_energy_multiplier = 0.2
	var blotches := int(size.x * size.z / 6.0)
	for i in blotches:
		var r := rng.randf_range(0.3, 0.8)
		var disc := CylinderMesh.new()
		disc.top_radius = r
		disc.bottom_radius = r
		disc.height = 0.01
		disc.radial_segments = 8
		disc.rings = 1
		disc.material = blotch_mat
		var disc_mi := MeshInstance3D.new()
		disc_mi.mesh = disc
		disc_mi.position = Vector3(rng.randf_range(-0.5, 0.5) * (size.x - 2.0 * r),
				0.035, rng.randf_range(-0.5, 0.5) * (size.z - 2.0 * r))
		disc_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		look.add_child(disc_mi)

	# Puffball nubs along the two long edges (looks only, no collision).
	var puff_mat := StandardMaterial3D.new()
	puff_mat.albedo_color = PUFF_COLOR
	puff_mat.roughness = 0.8
	puff_mat.emission_enabled = true
	puff_mat.emission = FLOOR_GLOW
	puff_mat.emission_energy_multiplier = 0.5
	var along_z := size.z >= size.x
	var length := size.z if along_z else size.x
	var half_w := (size.x if along_z else size.z) * 0.5
	var n := int(length / 1.6)
	for i in n:
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.35:
				continue
			var t := (float(i) + rng.randf_range(0.2, 0.8)) / maxf(n, 1) - 0.5
			var s := rng.randf_range(0.08, 0.16)
			var puff := SphereMesh.new()
			puff.radius = s
			puff.height = s * 1.5
			puff.radial_segments = 6
			puff.rings = 3
			puff.material = puff_mat
			var puff_mi := MeshInstance3D.new()
			puff_mi.mesh = puff
			var across: float = side * (half_w - rng.randf_range(0.1, 0.35))
			var at := t * length
			puff_mi.position = Vector3(across, s * 0.6, at) if along_z else Vector3(at, s * 0.6, across)
			look.add_child(puff_mi)

	var light := OmniLight3D.new()
	light.light_color = FLOOR_GLOW
	light.light_energy = 0.8
	light.omni_range = maxf(size.x, size.z) * 0.7 + 2.0
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position.y = 1.5
	look.add_child(light)

	var cloud := SporeCloud.new()
	cloud.size = Vector3(size.x, 0.6, size.z)
	cloud.spore_count = clampi(int(size.x * size.z * 1.2), 20, 200)
	cloud.drift_height = 1.4
	cloud.spore_seed = seed
	look.add_child(cloud)
