@tool
class_name StartPoint
extends Marker3D
## START POINT -- where the ball appears when the level begins. Place one
## per level; the level script spawns the player here. Face it (-Z) the way
## the player should initially look. Shows a small ghost ball in the
## editor only.


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	var ghost := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.9, 0.4, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	ghost.mesh = mesh
	ghost.position = Vector3(0, 0.5, 0)
	add_child(ghost)
