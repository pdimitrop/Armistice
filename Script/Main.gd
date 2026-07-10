extends Node3D

const ENTENTE := 0
const CENTRAL := 1
const MUSIC_FADE_DURATION := 1.5

const PITCH_X_LIMIT := 25.0
const PITCH_Z_LIMIT := 15.0
const BALL_RESPAWN  := Vector3(0.0, 1.0, 0.0)
const GOAL_KICK_OFFSET := 4.0

const SWITCH_MARGIN := 1.2

const PASS_HOMING_TIME  := 1.3
const PASS_HOMING_SPEED := 12.0
const PASS_HOMING_LERP  := 0.18
const PASS_ARRIVE_DIST  := 2.1

const KICKOFF_SETTLE      := 1.0
const KICKOFF_TAKEN_DIST  := 2.5
const KICKOFF_TIMEOUT     := 4.0
const KICKOFF_KICKER_AHEAD := 0.9

var _side: int = CENTRAL
var _ball: RigidBody3D
var _goal_a_wall: StaticBody3D
var _goal_b_wall: StaticBody3D
var _players_frozen := true
var _pause_overlay: CanvasLayer
var _goal_pending := false
var _score_entente := 0
var _score_central  := 0

var _pass_target: Node3D = null
var _pass_timer := 0.0

var _kickoff_active := false
var _kickoff_live := false
var _kickoff_team := CENTRAL
var _kickoff_spot := BALL_RESPAWN
var _kickoff_timer := 0.0
var _kicker: Node3D = null
var _formation: Array = []


func _ready() -> void:
	add_to_group("match")
	var gs := get_tree().get_root().get_node_or_null("GameState")
	_side = gs.get_meta("selected_side", CENTRAL) if gs else CENTRAL
	if gs:
		gs.queue_free()

	_ball = get_tree().get_first_node_in_group("Ball") as RigidBody3D
	_goal_a_wall = $Pitch/GoalA/WoodWall as StaticBody3D
	_goal_b_wall = $Pitch/GoalB/WoodWall as StaticBody3D
	_capture_formation()
	_setup_pause_overlay()
	_configure_cpu_flags()
	_freeze_all_players()
	_fade_music_then_whistle()


func _capture_formation() -> void:
	for team in [$Players/TeamEntente, $Players/TeamCentral]:
		for player in team.get_children():
			_formation.append({"node": player, "xform": player.global_transform})


func _process(delta: float) -> void:
	if _players_frozen or _goal_pending or get_tree().paused or not is_instance_valid(_ball):
		return
	if _kickoff_active:
		_update_kickoff(delta)
		return
	_update_pass_homing(delta)
	_update_active_player()
	var scorer := _scoring_team_on_woodwall()
	if scorer != -1:
		_on_goal(scorer)
		return
	var p := _ball.global_position
	if absf(p.x) > PITCH_X_LIMIT or absf(p.z) > PITCH_Z_LIMIT or p.y < -1.0:
		_on_out_of_bounds()


# A goal counts only on contact with a goal's back wall, so a ball flying over
# the bar never scores. Requires contact_monitor on the Ball.
func _scoring_team_on_woodwall() -> int:
	for body in _ball.get_colliding_bodies():
		if body == _goal_a_wall:
			return ENTENTE
		if body == _goal_b_wall:
			return CENTRAL
	return -1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and not _players_frozen:
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	_pause_overlay.set_score(_score_entente, _score_central)
	get_tree().paused = true
	_pause_overlay.visible = true


func _update_active_player() -> void:
	var human_team: Node3D = $Players/TeamEntente if _side == ENTENTE else $Players/TeamCentral
	var selected: Node3D = null
	var nearest: Node3D = null
	var nearest_d := INF
	for p in human_team.get_children():
		if p.is_in_group("goalkeepers"):
			continue
		if p.get("is_selected_player"):
			selected = p
		var d: float = p.global_position.distance_to(_ball.global_position)
		if d < nearest_d:
			nearest_d = d
			nearest = p
	if nearest == null:
		return
	if selected == null:
		nearest.set("is_selected_player", true)
		return
	if selected == nearest:
		return
	var sel_d: float = selected.global_position.distance_to(_ball.global_position)
	if nearest_d + SWITCH_MARGIN < sel_d:
		selected.set("is_selected_player", false)
		nearest.set("is_selected_player", true)


func register_pass(target: Node3D) -> void:
	_pass_target = target
	_pass_timer = PASS_HOMING_TIME if target else 0.0


func _update_pass_homing(delta: float) -> void:
	if _pass_target == null or not is_instance_valid(_pass_target):
		_pass_target = null
		return
	_pass_timer -= delta
	var to_t := _pass_target.global_position - _ball.global_position
	to_t.y = 0.0
	if _pass_timer <= 0.0 or to_t.length() < PASS_ARRIVE_DIST:
		_pass_target = null
		return
	var desired := to_t.normalized() * PASS_HOMING_SPEED
	_ball.linear_velocity.x = lerpf(_ball.linear_velocity.x, desired.x, PASS_HOMING_LERP)
	_ball.linear_velocity.z = lerpf(_ball.linear_velocity.z, desired.z, PASS_HOMING_LERP)


func _teleport_ball() -> void:
	_pass_target = null
	_ball.global_position = BALL_RESPAWN
	_ball.linear_velocity  = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO


func _on_goal(scoring_team: int) -> void:
	if scoring_team == ENTENTE:
		_score_entente += 1
	else:
		_score_central += 1
	_goal_pending = true
	_freeze_all_players()
	_play_whistle_callback(_after_goal_whistle.bind(scoring_team))


func _after_goal_whistle(scoring_team: int) -> void:
	var conceding := CENTRAL if scoring_team == ENTENTE else ENTENTE
	_begin_kickoff(conceding)


func _on_out_of_bounds() -> void:
	var last_team: int = _ball.get_meta("last_touch_team", -1)
	if last_team == -1:
		_teleport_ball()
		return
	var rival := CENTRAL if last_team == ENTENTE else ENTENTE
	_do_goal_kick(rival)


func _do_goal_kick(receiving_team: int) -> void:
	_pass_target = null
	var gk := _get_goalkeeper(receiving_team)
	if not gk:
		_teleport_ball()
		return

	var gk_x: float = gk.global_position.x
	var toward_centre: float = -signf(gk_x)
	_ball.global_position = Vector3(gk_x + toward_centre * GOAL_KICK_OFFSET, 1.0, 0.0)
	_ball.linear_velocity  = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_ball.apply_central_impulse(Vector3(toward_centre, 0.0, 0.0) * 22.0 + Vector3(0.0, 3.0, 0.0))
	_ball.set_meta("last_touch_team", receiving_team)


func _get_goalkeeper(team: int) -> Node:
	var team_node: Node3D = $Players/TeamEntente if team == ENTENTE else $Players/TeamCentral
	for child in team_node.get_children():
		if child.is_in_group("goalkeepers"):
			return child
	return null


func _setup_pause_overlay() -> void:
	var scene: PackedScene = load("res://Scenes/PauseOverlay.tscn")
	_pause_overlay = scene.instantiate() as CanvasLayer
	add_child(_pause_overlay)


func _configure_cpu_flags() -> void:
	var human_team: Node3D = $Players/TeamEntente if _side == ENTENTE else $Players/TeamCentral
	var cpu_team: Node3D   = $Players/TeamCentral if _side == ENTENTE else $Players/TeamEntente
	for p in human_team.get_children():
		p.set("is_cpu_player", false)
	for p in cpu_team.get_children():
		p.set("is_cpu_player", true)


func _freeze_all_players() -> void:
	_players_frozen = true
	for team in [$Players/TeamEntente, $Players/TeamCentral]:
		for player in team.get_children():
			player.set("is_selected_player", false)
			player.set_physics_process(false)
			if player.has_method("reset_for_kickoff"):
				player.reset_for_kickoff()


func _unfreeze_and_configure() -> void:
	for team in [$Players/TeamEntente, $Players/TeamCentral]:
		for player in team.get_children():
			player.set_physics_process(true)

	var entente_team: Node3D = $Players/TeamEntente
	var central_team: Node3D = $Players/TeamCentral
	var chosen: Node3D = entente_team if _side == ENTENTE else central_team
	var starter := chosen.get_node_or_null("MidfielderRight")
	if starter:
		starter.set("is_selected_player", true)
	elif chosen.get_child_count() > 1:
		chosen.get_child(1).set("is_selected_player", true)

	_players_frozen = false


func _fade_music_then_whistle() -> void:
	var music := get_node_or_null("/root/BgMusic") as AudioStreamPlayer2D
	if music and music.playing:
		var tween := create_tween()
		tween.tween_property(music, "volume_db", -80.0, MUSIC_FADE_DURATION)
		tween.tween_callback(music.stop)
		tween.tween_callback(_play_whistle)
	else:
		_play_whistle()


func _play_whistle() -> void:
	_play_whistle_callback(_on_kickoff_whistle_finished)


func _play_whistle_callback(callback: Callable) -> void:
	var whistle := AudioStreamPlayer.new()
	whistle.stream = load("res://Assets/Sound/Whistle.mp3")
	add_child(whistle)
	whistle.finished.connect(func():
		whistle.queue_free()
		callback.call()
	)
	whistle.play()


func _on_kickoff_whistle_finished() -> void:
	_begin_kickoff(_side)


func _team_goal_dir(team: int) -> Vector3:
	return Vector3(1, 0, 0) if team == ENTENTE else Vector3(-1, 0, 0)


func _is_human_team(team: int) -> bool:
	return team == _side


func _reset_formation() -> void:
	for entry in _formation:
		var p: Node3D = entry["node"]
		if not is_instance_valid(p):
			continue
		p.global_transform = entry["xform"]
		if p.has_method("reset_for_kickoff"):
			p.reset_for_kickoff()


func _position_kicker(team: int) -> Node3D:
	var team_node: Node3D = $Players/TeamEntente if team == ENTENTE else $Players/TeamCentral
	var kicker: Node3D = team_node.get_node_or_null("MidfielderRight")
	if kicker == null:
		for c in team_node.get_children():
			if not c.is_in_group("goalkeepers"):
				kicker = c
				break
	if kicker:
		var gdir := _team_goal_dir(team)
		var spot := BALL_RESPAWN - gdir * KICKOFF_KICKER_AHEAD
		kicker.global_position = Vector3(spot.x, kicker.global_position.y, spot.z)
		kicker.rotation.y = atan2(gdir.x, gdir.z)
		kicker.set("_aim_dir", gdir)
	return kicker


func _begin_kickoff(team: int) -> void:
	_kickoff_team = team
	_reset_formation()
	_teleport_ball()
	_kicker = _position_kicker(team)
	for t in [$Players/TeamEntente, $Players/TeamCentral]:
		for p in t.get_children():
			p.set("is_selected_player", false)
			p.set_physics_process(false)
	_kickoff_spot = _ball.global_position
	_kickoff_timer = 0.0
	_kickoff_live = false
	_kickoff_active = true
	_goal_pending = false
	_players_frozen = false


func _update_kickoff(delta: float) -> void:
	_kickoff_timer += delta
	if not _kickoff_live:
		if _kickoff_timer < KICKOFF_SETTLE:
			return
		_kickoff_live = true
		_kickoff_timer = 0.0
		if is_instance_valid(_kicker):
			_kicker.set_physics_process(true)
			if _is_human_team(_kickoff_team):
				_kicker.set("is_selected_player", true)
		return
	if _ball.global_position.distance_to(_kickoff_spot) > KICKOFF_TAKEN_DIST:
		_end_kickoff()
	elif not _is_human_team(_kickoff_team) and _kickoff_timer >= KICKOFF_TIMEOUT:
		_end_kickoff()


func _end_kickoff() -> void:
	_kickoff_active = false
	_kicker = null
	for t in [$Players/TeamEntente, $Players/TeamCentral]:
		for p in t.get_children():
			p.set_physics_process(true)
