class_name CaveDecor
extends RefCounted
## CAVE DECOR -- the glowing things that light the hub: clusters of glowing
## fungus low on the walls and around the floor's edge, amber crystal
## clusters higher up, and the shaft of daylight from the hole in the top.
## Each cluster carries a small light. All built from shapes, no files.
##
##   CaveDecor.build(parent, shell)

const FUNGUS_CLUSTERS := 14
const CRYSTAL_CLUSTERS := 8
const FUNGUS_GLOW := Color(1.0, 0.72, 0.3)
const FUNGUS_CAP := Color(1.0, 0.82, 0.45)
const FUNGUS_STEM := Color(0.9, 0.78, 0.6)
const CRYSTAL_GLOW := Color(1.0, 0.58, 0.18)
const DAYLIGHT := Color(1.0, 0.93, 0.8)


static func build(parent: Node3D, shell: CaveShell) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = shell.seed * 7 + 1
	var root := Node3D.new()
	root.name = "Decor"
	parent.add_child(root)
	var fungus_material := _glow_material(FUNGUS_CAP, FUNGUS_GLOW, 0.9)
	var stem_material := CritterParts.material(FUNGUS_STEM, 0.9)
	var crystal_material := _glow_material(Color(1.0, 0.75, 0.4), CRYSTAL_GLOW, 1.3)

	# Fungus: spread evenly around the wall, low down, staying off the
	# tunnel mouths and their letters.
	var placed := 0
	var tries := 0
	while placed < FUNGUS_CLUSTERS and tries < 200:
		tries += 1
		var angle := (360.0 / FUNGUS_CLUSTERS) * placed + rng.randf_range(-10.0, 10.0)
		if _near_cut(shell, angle, 26.0):
			angle += 24.0
			if _near_cut(shell, angle, 26.0):
				placed += 1
				continue
		var t := rng.randf_range(0.04, 0.42)
		var xf := shell.surface_transform(angle, t)
		_fungus_cluster(root, xf, rng, fungus_material, stem_material)
		placed += 1

	# Crystals: higher up the walls and on the lower dome.
	for i in CRYSTAL_CLUSTERS:
		var angle := (360.0 / CRYSTAL_CLUSTERS) * i + 20.0 + rng.randf_range(-12.0, 12.0)
		var t := rng.randf_range(0.42, 0.72)
		var xf := shell.surface_transform(angle, t)
		_crystal_cluster(root, xf, rng, crystal_material)

	_light_shaft(root, shell)


static func _near_cut(shell: CaveShell, angle: float, margin: float) -> bool:
	for cut in shell.cuts:
		if absf(wrapf(angle - float(cut.angle), -180.0, 180.0)) < margin:
			return true
	return false


static func _glow_material(albedo: Color, glow: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = 0.7
	m.emission_enabled = true
	m.emission = glow
	m.emission_energy_multiplier = energy
	return m


## Three to five mushrooms of different sizes on a spot of wall, plus one
## warm light.
static func _fungus_cluster(root: Node3D, xf: Transform3D, rng: RandomNumberGenerator,
		cap_material: Material, stem_material: Material) -> void:
	var cluster := Node3D.new()
	cluster.name = "Fungus"
	root.add_child(cluster)
	cluster.global_transform = xf
	var count := rng.randi_range(3, 5)
	for i in count:
		var size := rng.randf_range(0.5, 1.1)
		var offset := Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2))
		var stem := CylinderMesh.new()
		stem.top_radius = 0.08 * size
		stem.bottom_radius = 0.13 * size
		stem.height = 0.5 * size
		stem.radial_segments = 7
		stem.rings = 1
		stem.material = stem_material
		var stem_instance := MeshInstance3D.new()
		stem_instance.mesh = stem
		stem_instance.position = offset + Vector3(0.0, stem.height * 0.5 - 0.05, 0.0)
		stem_instance.rotation = Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
		cluster.add_child(stem_instance)
		var cap := SphereMesh.new()
		cap.radius = 0.35 * size
		cap.height = 0.7 * size
		cap.radial_segments = 9
		cap.rings = 4
		cap.material = cap_material
		var cap_instance := MeshInstance3D.new()
		cap_instance.mesh = cap
		cap_instance.scale = Vector3(1.0, 0.55, 1.0)
		cap_instance.position = stem_instance.position + Vector3(0.0, stem.height * 0.5, 0.0)
		cap_instance.rotation = stem_instance.rotation
		cluster.add_child(cap_instance)
	var light := OmniLight3D.new()
	light.light_color = FUNGUS_GLOW
	light.light_energy = 1.5
	light.omni_range = 12.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	light.position = Vector3(0.0, 1.0, 0.0)
	cluster.add_child(light)


## A few amber crystals jutting out of the wall at different angles.
static func _crystal_cluster(root: Node3D, xf: Transform3D, rng: RandomNumberGenerator, material: Material) -> void:
	var cluster := Node3D.new()
	cluster.name = "Crystals"
	root.add_child(cluster)
	cluster.global_transform = xf
	var count := rng.randi_range(3, 6)
	for i in count:
		var length := rng.randf_range(0.9, 1.8)
		var shard := CylinderMesh.new()
		shard.top_radius = 0.05
		shard.bottom_radius = rng.randf_range(0.18, 0.3)
		shard.height = length
		shard.radial_segments = 6
		shard.rings = 1
		shard.material = material
		var instance := MeshInstance3D.new()
		instance.mesh = shard
		instance.rotation = Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6))
		instance.position = Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-0.8, 0.8))
		instance.position += instance.basis.y * (length * 0.4)
		cluster.add_child(instance)
	var light := OmniLight3D.new()
	light.light_color = CRYSTAL_GLOW
	light.light_energy = 1.1
	light.omni_range = 10.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	light.position = Vector3(0.0, 1.0, 0.0)
	cluster.add_child(light)


## Daylight pouring in through the hole in the top: a spot light aimed at
## the floor, a faint see-through cone of "dusty air", and a bright disc
## of sky above the hole so looking up shows daylight, not the void.
static func _light_shaft(root: Node3D, shell: CaveShell) -> void:
	var spot := SpotLight3D.new()
	spot.name = "Daylight"
	spot.light_color = DAYLIGHT
	spot.light_energy = 3.2
	spot.spot_range = shell.height + 4.0
	spot.spot_angle = 17.0
	spot.spot_angle_attenuation = 0.6
	spot.shadow_enabled = false   # a shadow map on the flat floor only makes acne
	spot.position = Vector3(0.0, shell.height + 1.5, 0.0)
	spot.rotation.x = -PI * 0.5
	root.add_child(spot)

	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_material.albedo_color = Color(1.0, 0.85, 0.6, 0.045)
	beam_material.no_depth_test = false
	var beam := CylinderMesh.new()
	beam.top_radius = shell.top_hole_radius
	beam.bottom_radius = shell.top_hole_radius * 2.3
	beam.height = shell.height
	beam.radial_segments = 16
	beam.rings = 1
	beam.cap_top = false
	beam.cap_bottom = false   # a cap on the floor would z-fight with it
	beam.material = beam_material
	var beam_instance := MeshInstance3D.new()
	beam_instance.name = "LightBeam"
	beam_instance.mesh = beam
	beam_instance.position = Vector3(0.0, shell.height * 0.5 + 0.15, 0.0)
	beam_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam_instance)

	var sky_material := StandardMaterial3D.new()
	sky_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_material.albedo_color = Color(0.75, 0.88, 1.0)
	sky_material.emission_enabled = true
	sky_material.emission = Color(0.8, 0.9, 1.0)
	sky_material.emission_energy_multiplier = 1.4
	var disc := CylinderMesh.new()
	disc.top_radius = shell.top_hole_radius * 1.6
	disc.bottom_radius = shell.top_hole_radius * 1.6
	disc.height = 0.1
	disc.radial_segments = 16
	disc.material = sky_material
	var disc_instance := MeshInstance3D.new()
	disc_instance.name = "Sky"
	disc_instance.mesh = disc
	disc_instance.position = Vector3(0.0, shell.height + 0.6, 0.0)
	root.add_child(disc_instance)
