extends Node3D
## PROP SPAWNER -- places many copies of a physics prop in a pattern when
## the level starts, so a field of boxes or a row of dominoes is one node
## in the level instead of fifty.
##
## Patterns:
##   GRID     count_a across (local X) by count_b deep (local Z)
##   ROW      count_a in a line along local X
##   PYRAMID  count_a on the bottom row, one fewer each row up, along X
## Rotate this node to aim the pattern. Props drop in from slightly above
## their rest height so they settle naturally.

enum Pattern { GRID, ROW, PYRAMID }

@export var prop: PackedScene
@export var pattern: Pattern = Pattern.GRID
@export var count_a := 6
@export var count_b := 5
## Distance between prop centers, in meters.
@export var spacing := 1.0
## Height of one prop, used to stack rows and to place them on the ground.
@export var prop_height := 0.5


func _ready() -> void:
	if prop == null:
		push_error("PropSpawner '%s' has no prop scene" % name)
		return
	match pattern:
		Pattern.GRID:
			for ix in count_a:
				for iz in count_b:
					_spawn(Vector3((ix - (count_a - 1) * 0.5) * spacing, 0.0, (iz - (count_b - 1) * 0.5) * spacing))
		Pattern.ROW:
			for ix in count_a:
				_spawn(Vector3((ix - (count_a - 1) * 0.5) * spacing, 0.0, 0.0))
		Pattern.PYRAMID:
			for row in count_a:
				var in_row := count_a - row
				for ix in in_row:
					_spawn(Vector3((ix - (in_row - 1) * 0.5) * spacing, row * prop_height, 0.0))


func _spawn(local_offset: Vector3) -> void:
	var instance := prop.instantiate() as Node3D
	add_child(instance)
	instance.position = local_offset + Vector3.UP * (prop_height * 0.5 + 0.02)
