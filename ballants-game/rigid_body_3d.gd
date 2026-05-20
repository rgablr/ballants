extends RigidBody3D

@export var roll_force: float = 10.0
@export var jump_impulse: float = 5.0
@export var camera: Camera3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_SPACE:
		if event.pressed and not event.echo:
			apply_central_impulse(Vector3.UP * jump_impulse)


func _physics_process(delta: float) -> void:
	var force_direction := Vector3.ZERO

	if Input.is_physical_key_pressed(KEY_W):
		force_direction += Vector3.FORWARD
	if Input.is_physical_key_pressed(KEY_S):
		force_direction += Vector3.BACK
	if Input.is_physical_key_pressed(KEY_A):
		force_direction += Vector3.LEFT
	if Input.is_physical_key_pressed(KEY_D):
		force_direction += Vector3.RIGHT

	if force_direction != Vector3.ZERO:
		force_direction = force_direction.normalized()
		
		# Automatically find the active camera if one isn't assigned in the Inspector
		var current_camera = camera
		if not current_camera:
			current_camera = get_viewport().get_camera_3d()
			
		if current_camera:
			# Get the camera's forward and right directions
			var cam_forward = -current_camera.global_transform.basis.z
			var cam_right = current_camera.global_transform.basis.x
			
			# Flatten the directions so the ball doesn't try to roll into the ground or air
			cam_forward.y = 0
			cam_right.y = 0
			
			# Calculate the new direction relative to the camera
			force_direction = (cam_forward.normalized() * -force_direction.z) + (cam_right.normalized() * force_direction.x)
			
		apply_central_force(force_direction.normalized() * roll_force)
