class_name CritterParts
extends RefCounted
## CRITTER PARTS -- shared building blocks for the garden's bugs (ladybug,
## worm, spider, fly, bee): simple shapes, cached materials, legs as rods,
## see-through wings, and "how high is the ground here?".
##
## Every critter is built from these in code (no model files), at ant
## scale: the ant on the ball is about 0.5 m tall, so a ladybug is ~0.7 m
## long, a bee ~1.2 m, and an earthworm several meters.

static var _materials := {}


static func material(color: Color, roughness := 0.75, unshaded := false) -> StandardMaterial3D:
	var key := "%s/%.2f/%s" % [color.to_html(), roughness, unshaded]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = m
	return m


static func sphere(parent: Node3D, pos: Vector3, radius: float, scale_by: Vector3, mat: Material, segments := 12) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(segments / 2, 3)
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_by
	parent.add_child(instance)
	return instance


## A thin rod from a to b (legs, antennae, threads).
static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	parent.add_child(instance)
	set_rod(instance, a, b)
	return instance


## Re-aims an existing rod so it runs from a to b.
static func set_rod(instance: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var mesh := instance.mesh as CapsuleMesh
	var length := a.distance_to(b)
	mesh.height = length + mesh.radius * 2.0
	var y := (b - a) / length if length > 0.0001 else Vector3.UP
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	var z := x.cross(y)
	instance.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)


## A flat, see-through wing hinged at the origin of `hinge`, extending
## sideways (side = 1 right, -1 left). Returns the hinge to flap.
static func wing(parent: Node3D, pos: Vector3, length: float, width: float, side: float, mat: Material) -> Node3D:
	var hinge := Node3D.new()
	hinge.position = pos
	parent.add_child(hinge)
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 4
	mesh.material = mat
	var blade := MeshInstance3D.new()
	blade.mesh = mesh
	blade.scale = Vector3(length, 0.02, width)
	blade.position = Vector3(side * length * 0.5, 0.0, width * 0.15)
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hinge.add_child(blade)
	return hinge


## Height of the first solid surface straight below `from` (world space),
## ignoring `exclude` bodies. Returns from.y - 50 if nothing is there.
static func ground_height(node: Node3D, from: Vector3, exclude: Array[RID] = []) -> float:
	var space := node.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 3.0, from + Vector3.DOWN * 50.0)
	query.exclude = exclude
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	return (hit.position as Vector3).y if not hit.is_empty() else from.y - 50.0


## The player's ball, or null.
static func find_player(node: Node) -> RigidBody3D:
	return node.get_tree().get_first_node_in_group("player") as RigidBody3D


## A random flower (FlowerStem) other than `except`, or null.
static func random_flower(node: Node, except: Node = null) -> Node3D:
	var flowers := node.get_tree().get_nodes_in_group("flower").filter(func(f): return f != except)
	return flowers.pick_random() if not flowers.is_empty() else null
