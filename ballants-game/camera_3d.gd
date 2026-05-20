extends Camera3D

@export var target: Node3D
@export var mouse_sensitivity: float = 0.005

var _offset: Vector3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if target:
		_offset = global_position - target.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Rotate horizontally (around the global Y axis)
		_offset = _offset.rotated(Vector3.UP, event.relative.x * mouse_sensitivity)
		
		# Rotate vertically (around the camera's local right axis)
		var right = Vector3.UP.cross(_offset).normalized()
		var new_offset = _offset.rotated(right, -event.relative.y * mouse_sensitivity)
		
		# Prevent the camera from going perfectly top-down or bottom-up, which causes flipping
		if abs(new_offset.normalized().y) < 0.95:
			_offset = new_offset


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if target:
		global_position = target.global_position + _offset
		look_at(target.global_position)
