extends "res://Script/player.gd"

@export var goal_x: float = -23.0
@export var lateral_range: float = 4.5
@export var keeper_speed_factor: float = 1.4
@export var rush_radius: float = 7.0
@export var rush_max: float = 4.0
@export var clear_radius: float = 1.7

func _ready() -> void:
	super._ready()
	add_to_group("goalkeepers")

func _unhandled_input(_event: InputEvent) -> void:
	pass

# Keepers block physically (collision layers) and clear via _try_keeper_clear();
# suppress the outfield contact-push so a nudge can't deflect into our own goal.
func _handle_ball_collisions() -> void:
	pass

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if current_state == PlayerState.KICKING or current_state == PlayerState.PASSING:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		move_and_slide()
		_pin_to_ground()
		return

	var direction := Vector3.ZERO
	var speed_factor := keeper_speed_factor

	if is_selected_player:
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
		speed_factor = 0.7
	elif ball:
		direction = _guard_direction()

	if direction:
		velocity.x = direction.x * SPEED * speed_factor
		velocity.z = direction.z * SPEED * speed_factor
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 12.0 * delta)
		change_state(PlayerState.RUNNING)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		change_state(PlayerState.IDLE)

	move_and_slide()
	_pin_to_ground()
	_handle_ball_collisions()
	_update_run_anim_speed()

	if not is_selected_player:
		_try_keeper_clear()

func _guard_direction() -> Vector3:
	var bpos := ball.global_position
	var bvel := ball.linear_velocity

	var target_z := bpos.z
	var dx := goal_x - bpos.x
	if absf(bvel.x) > 0.5 and signf(dx) == signf(bvel.x):
		var t := dx / bvel.x
		if t > 0.0 and t < 1.5:
			target_z = bpos.z + bvel.z * t
	target_z = clampf(target_z, -lateral_range, lateral_range)

	var target_x := goal_x
	var dist := bpos.distance_to(global_position)
	if dist < rush_radius and absf(bpos.z) < lateral_range + 1.0:
		var off := clampf(absf(bpos.x - goal_x) * 0.5, 0.0, rush_max)
		target_x = goal_x + signf(-goal_x) * off

	var target := Vector3(target_x, 0.0, target_z)
	var diff := target - Vector3(global_position.x, 0.0, global_position.z)
	if diff.length() < 0.15:
		return Vector3.ZERO
	return diff.normalized()

func _try_keeper_clear() -> void:
	if not ball:
		return
	if current_state == PlayerState.KICKING or current_state == PlayerState.PASSING:
		return
	if global_position.distance_to(ball.global_position) > clear_radius:
		return
	ball.set_meta("last_touch_team", _get_team())
	_clear_pass_homing()
	change_state(PlayerState.KICKING)
	var toward_centre := signf(-goal_x)
	var clear_dir := Vector3(toward_centre, 0.0, randf_range(-0.4, 0.4)).normalized()
	ball.apply_central_impulse(clear_dir * 30.0 + Vector3(0, 7, 0))
