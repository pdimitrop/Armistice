extends CharacterBody3D

const SPEED = 5.0
const GRAVITY = 10.0
const TEAM_ENTENTE := 0
const TEAM_CENTRAL := 1

const POSSESS_RADIUS    := 1.8
const DRIBBLE_GLUE      := 32.0
const MAX_DRIBBLE_SPEED := 14.0
const KICK_COOLDOWN     := 0.45
const PASS_FAIL_CHANCE  := 0.20

const CPU_CHASE_FACTOR := 0.8
const CPU_ZONE_FACTOR  := 0.5

const SUPPORT_FACTOR    := 0.7
const SUPPORT_PUSH_UP   := 3.0
const SUPPORT_BALL_BIAS := 0.35
const SUPPORT_X_LIMIT   := 22.0
const SUPPORT_Z_LIMIT   := 13.0
const SUPPORT_ARRIVE    := 1.0
const SUPPORT_RESUME    := 3.0

const KICK_ANIM_SPEED := 1.6

enum PlayerState { IDLE, RUNNING, DRIBBLING, KICKING, PASSING }
var current_state: PlayerState = PlayerState.IDLE

@export var is_selected_player: bool = false
@export var engagement_radius: float = 6.0
@export var idle_clip: StringName = &"offensive idle"
@export var idle_pose_time: float = 0.0
@export var dribble_ahead: float = 0.6
@export var dribble_side_offset: float = 0.0

var home_position: Vector3 = Vector3.ZERO
var _aim_dir := Vector3.ZERO
var is_cpu_player := true
var _kick_cooldown := 0.0
var _support_moving := false

var _ground_y := 0.0
var _grounded := false

@onready var ball: RigidBody3D
@onready var anim_player = find_child("AnimationPlayer", true, false)

func _ready():
	add_to_group("players")
	call_deferred("_find_ball")
	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)
		# Pose idle directly: change_state(IDLE) would early-out and leave a T-pose.
		_play_idle_still()

func _find_ball():
	ball = get_tree().get_first_node_in_group("Ball")
	home_position = global_position
	_aim_dir = _get_goal_dir()
	_ground_y = global_position.y
	_grounded = true

# Players never jump; pin height so ball contact can't shove them up onto it.
func _pin_to_ground() -> void:
	if _grounded:
		global_position.y = _ground_y
	velocity.y = 0.0

func _get_team() -> int:
	return TEAM_ENTENTE if get_parent().name == "TeamEntente" else TEAM_CENTRAL

func _get_goal_dir() -> Vector3:
	return Vector3(1, 0, 0) if get_parent().name == "TeamEntente" else Vector3(-1, 0, 0)

func change_state(new_state: PlayerState) -> void:
	if current_state == new_state or not anim_player:
		return
	current_state = new_state
	match current_state:
		PlayerState.IDLE:
			_play_idle_still()
		PlayerState.RUNNING:
			anim_player.speed_scale = 1.0
			anim_player.play("jog forward")
		PlayerState.DRIBBLING:
			anim_player.speed_scale = 1.0
			anim_player.play("dribble")
		PlayerState.KICKING:
			anim_player.speed_scale = KICK_ANIM_SPEED
			anim_player.play("kick soccerball 1")
		PlayerState.PASSING:
			anim_player.speed_scale = KICK_ANIM_SPEED
			anim_player.play("kick soccerball 2")

func _play_idle_still() -> void:
	if not anim_player:
		return
	anim_player.play(idle_clip)
	if anim_player.has_method("seek"):
		var t := idle_pose_time
		if anim_player.has_method("get_animation"):
			var a: Animation = anim_player.get_animation(idle_clip)
			if a:
				t = clampf(idle_pose_time, 0.0, maxf(0.0, a.length - 0.01))
		anim_player.seek(t, true)
	anim_player.speed_scale = 0.0

func _physics_process(delta: float) -> void:
	_kick_cooldown = maxf(0.0, _kick_cooldown - delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if current_state == PlayerState.KICKING or current_state == PlayerState.PASSING:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		move_and_slide()
		_pin_to_ground()
		return

	var direction := Vector3.ZERO
	var pursuing := false

	if is_selected_player:
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	elif ball:
		var ball_flat := Vector3(ball.global_position.x, 0.0, ball.global_position.z)
		var home_flat := Vector3(home_position.x, 0.0, home_position.z)
		var self_flat := Vector3(global_position.x, 0.0, global_position.z)
		if is_cpu_player:
			var chaser := _is_nearest_teammate_to_ball()
			if chaser or ball_flat.distance_to(home_flat) < engagement_radius:
				pursuing = chaser
				if self_flat.distance_to(ball_flat) > 1.5:
					direction = (ball_flat - self_flat).normalized()
				else:
					_try_cpu_shoot()
			elif self_flat.distance_to(home_flat) > 0.5:
				direction = (home_flat - self_flat).normalized()
		else:
			direction = _support_direction(ball_flat, home_flat, self_flat)

	if direction:
		var current_speed := SPEED
		if not is_selected_player:
			if is_cpu_player:
				current_speed = SPEED * (CPU_CHASE_FACTOR if pursuing else CPU_ZONE_FACTOR)
			else:
				current_speed = SPEED * SUPPORT_FACTOR
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 18 * delta)
		_aim_dir = direction
		change_state(PlayerState.DRIBBLING if (is_selected_player and _is_possessing()) else PlayerState.RUNNING)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		change_state(PlayerState.IDLE)

	move_and_slide()
	_pin_to_ground()

	if is_selected_player:
		_apply_dribble()
	_handle_ball_collisions()
	_update_run_anim_speed()

func _apply_dribble() -> void:
	if not ball or _kick_cooldown > 0.0:
		return
	var self_flat := Vector3(global_position.x, 0.0, global_position.z)
	var ball_flat := Vector3(ball.global_position.x, 0.0, ball.global_position.z)
	if self_flat.distance_to(ball_flat) > POSSESS_RADIUS:
		return
	# Lead the ball by the player's ACTUAL velocity, scaled by speed: standing still
	# it sits right at the feet (no stale heading to read as "off to the side"), and
	# it extends out in front along the true direction of travel as the player runs.
	var vel_flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed_frac := clampf(vel_flat.length() / SPEED, 0.0, 1.0)
	var target := self_flat
	if speed_frac > 0.01:
		var fwd := vel_flat.normalized()
		var side := Vector3(-fwd.z, 0.0, fwd.x)
		target += (fwd * dribble_ahead + side * dribble_side_offset) * speed_frac
	var desired := (target - ball_flat) * DRIBBLE_GLUE
	if desired.length() > MAX_DRIBBLE_SPEED:
		desired = desired.normalized() * MAX_DRIBBLE_SPEED
	ball.linear_velocity = Vector3(desired.x, ball.linear_velocity.y, desired.z)
	ball.angular_velocity = Vector3.ZERO   # kill roll-spin so it can't drift off-axis

func _is_possessing() -> bool:
	if not ball or _kick_cooldown > 0.0:
		return false
	var s := Vector3(global_position.x, 0.0, global_position.z)
	var b := Vector3(ball.global_position.x, 0.0, ball.global_position.z)
	return s.distance_to(b) <= POSSESS_RADIUS

func _support_direction(ball_flat: Vector3, home_flat: Vector3, self_flat: Vector3) -> Vector3:
	var attack := _get_goal_dir()
	var anchor := home_flat + attack * SUPPORT_PUSH_UP
	var target := anchor.lerp(ball_flat, SUPPORT_BALL_BIAS)
	target.x = clampf(target.x, -SUPPORT_X_LIMIT, SUPPORT_X_LIMIT)
	target.z = clampf(target.z, -SUPPORT_Z_LIMIT, SUPPORT_Z_LIMIT)
	var to_t := target - self_flat
	to_t.y = 0.0
	var d := to_t.length()
	if _support_moving:
		if d <= SUPPORT_ARRIVE:
			_support_moving = false
			return Vector3.ZERO
		return to_t.normalized()
	if d >= SUPPORT_RESUME:
		_support_moving = true
		return to_t.normalized()
	return Vector3.ZERO

func _is_nearest_teammate_to_ball() -> bool:
	if not ball:
		return false
	var my_d := global_position.distance_to(ball.global_position)
	for sib in get_parent().get_children():
		if sib == self or (sib as Node).is_in_group("goalkeepers"):
			continue
		if (sib as Node3D).global_position.distance_to(ball.global_position) < my_d:
			return false
	return true

func _update_run_anim_speed() -> void:
	if (current_state != PlayerState.RUNNING and current_state != PlayerState.DRIBBLING) or not anim_player:
		return
	var spd := Vector2(velocity.x, velocity.z).length()
	anim_player.speed_scale = clampf(spd / SPEED, 0.4, 1.5)

func _try_cpu_shoot() -> void:
	if not is_cpu_player or is_in_group("goalkeepers"):
		return
	if current_state == PlayerState.KICKING or current_state == PlayerState.PASSING:
		return
	if not ball or global_position.distance_to(ball.global_position) > 2.5:
		return
	ball.set_meta("last_touch_team", _get_team())
	_clear_pass_homing()
	change_state(PlayerState.KICKING)
	ball.apply_central_impulse(_get_goal_dir() * 36.0 + Vector3(0, 6, 0))

# Only non-selected human teammates nudge the ball on contact; CPU and the
# selected carrier move it elsewhere (_try_cpu_shoot / _apply_dribble).
func _handle_ball_collisions() -> void:
	if is_cpu_player or is_selected_player:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is RigidBody3D and collider.is_in_group("Ball"):
			collider.set_meta("last_touch_team", _get_team())
			var push_direction := -collision.get_normal()
			push_direction.y = 0
			collider.apply_central_impulse(push_direction * 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_player") and is_selected_player:
		_advance_selection()
		get_viewport().set_input_as_handled()
		return

	if not is_selected_player:
		return

	if ball and global_position.distance_to(ball.global_position) < 2.5:
		if event.is_action_pressed("pass_action"):
			_do_pass()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("shoot_action"):
			change_state(PlayerState.KICKING)
			ball.set_meta("last_touch_team", _get_team())
			_kick_cooldown = KICK_COOLDOWN
			_clear_pass_homing()
			var shot_dir := _get_shot_dir()
			ball.apply_central_impulse(shot_dir * 45.0 + Vector3(0, 8, 0))
			get_viewport().set_input_as_handled()

func _do_pass() -> void:
	change_state(PlayerState.PASSING)
	ball.set_meta("last_touch_team", _get_team())
	_kick_cooldown = KICK_COOLDOWN
	var target := _get_pass_target()
	var accurate := randf() >= PASS_FAIL_CHANCE
	var pass_dir := _aim_dir if _aim_dir != Vector3.ZERO else _get_goal_dir()
	if target:
		var to_mate := target.global_position - global_position
		to_mate.y = 0.0
		pass_dir = to_mate.normalized()
	if not accurate:
		var sway := deg_to_rad(30.0) * (1.0 if randf() < 0.5 else -1.0)
		pass_dir = pass_dir.rotated(Vector3.UP, sway)
		target = null
	ball.apply_central_impulse(pass_dir * 18.0 + Vector3(0, 3, 0))
	_register_pass(target)

func _register_pass(target: Node3D) -> void:
	var mgr := get_tree().get_first_node_in_group("match")
	if mgr and mgr.has_method("register_pass"):
		mgr.register_pass(target)

func _clear_pass_homing() -> void:
	_register_pass(null)

func _get_pass_target() -> Node3D:
	var aim := _aim_dir if _aim_dir != Vector3.ZERO else _get_goal_dir()
	var best_score := -INF
	var best_node: Node3D = null
	for sibling in get_parent().get_children():
		if sibling == self or (sibling as Node).is_in_group("goalkeepers"):
			continue
		var to_mate := (sibling as Node3D).global_position - global_position
		to_mate.y = 0.0
		var dist := to_mate.length()
		if dist < 0.5:
			continue
		var dot := aim.dot(to_mate.normalized())
		var score := dot / maxf(dist, 1.0)
		if score > best_score:
			best_score = score
			best_node = sibling as Node3D
	return best_node

func _get_shot_dir() -> Vector3:
	var aim := _aim_dir if _aim_dir != Vector3.ZERO else _get_goal_dir()
	var roll := randf()
	if roll < 0.6:
		return aim
	var angle := deg_to_rad(35.0) * (1.0 if roll < 0.8 else -1.0)
	return aim.rotated(Vector3.UP, angle)

func toggle_selection() -> void:
	is_selected_player = !is_selected_player

func reset_for_kickoff() -> void:
	velocity = Vector3.ZERO
	_kick_cooldown = 0.0
	current_state = PlayerState.IDLE
	_play_idle_still()

func _advance_selection() -> void:
	var siblings := get_parent().get_children().filter(
		func(n: Node) -> bool: return not n.is_in_group("goalkeepers")
	)
	var idx := siblings.find(self)
	if idx == -1:
		return
	is_selected_player = false
	siblings[(idx + 1) % siblings.size()].set("is_selected_player", true)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "kick soccerball 1" or anim_name == "kick soccerball 2":
		change_state(PlayerState.IDLE)
