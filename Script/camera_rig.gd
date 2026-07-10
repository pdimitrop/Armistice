extends Node3D

@export var target: Node3D
@export var follow_speed: float = 6.0

@export var cam_y: float = 16.0
@export var cam_z: float = 27.7
@export var cam_z_nudge_weight: float = 0.25
@export var cam_z_nudge_max: float = 4.0
@export var x_limit: float = 22.0

func _physics_process(delta: float) -> void:
	if not target:
		return
	var z_nudge: float = clamp(
		target.global_position.z * cam_z_nudge_weight,
		-cam_z_nudge_max,
		cam_z_nudge_max
	)
	var desired := Vector3(
		clamp(target.global_position.x, -x_limit, x_limit),
		cam_y,
		cam_z + z_nudge
	)
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
