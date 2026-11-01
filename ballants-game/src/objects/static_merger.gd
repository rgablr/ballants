class_name StaticMerger
extends RefCounted
## STATIC MERGER -- folds every Block's collision into ONE physics body.
##
## Why: when a floor is built from separate tiles, each tile is its own
## physics body, and a fast ball can catch on the edge where two tiles meet
## ("ghost collisions"), popping into the air. The physics engine can only
## smooth over those edges when the tiles belong to the same body. So at
## level start we move all Block collision shapes under one StaticBody3D.
## The Blocks keep their meshes; only the invisible collision moves.
##
## Call StaticMerger.merge(level_root) once the level's children are ready.


static func merge(root: Node) -> StaticBody3D:
	var merged := StaticBody3D.new()
	merged.name = "MergedStaticCollision"
	root.add_child(merged)
	for block in _find_blocks(root):
		if not block.merge_collision:
			continue
		for child in block.get_children():
			if child is CollisionShape3D:
				var shape := child as CollisionShape3D
				var world_transform := shape.global_transform
				block.remove_child(shape)
				merged.add_child(shape)
				shape.global_transform = world_transform
		# The block's own body now has no shapes; take it out of physics
		# entirely so nothing can accidentally hit an empty body.
		block.collision_layer = 0
		block.collision_mask = 0
	return merged


## Blocks, and any other StaticBody3D that opts in with a `merge_collision`
## property (DirtTrack, DirtWall), so a course built from several pieces
## is still one body with no catchable seams.
static func _find_blocks(node: Node) -> Array[StaticBody3D]:
	var found: Array[StaticBody3D] = []
	if node is Block or (node is StaticBody3D and "merge_collision" in node):
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_blocks(child))
	return found
