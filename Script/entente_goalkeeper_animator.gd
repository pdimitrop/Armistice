extends Node
# Model-swap animator named "AnimationPlayer" so goalkeeper.gd's find_child()
# picks it up: one FBX per state as a child, visibility toggled on play().

signal animation_finished(anim_name: StringName)

const BASE := "res://Assets/Characters/Entente/EntenteAnimated/"

const MODEL_MAP: Dictionary = {
	&"offensive idle":    BASE + "Goalkeeper Idle.fbx",
	&"jog forward":       BASE + "Goalkeeper Sidestep.fbx",
	&"kick soccerball 1": BASE + "Goalkeeper Drop Kick.fbx",
	&"kick soccerball 2": BASE + "Goalkeeper Pass.fbx",
}

const LOOPING := [&"offensive idle", &"jog forward"]

var _models: Dictionary = {}
var _current_name: StringName = &""
var _current_src_ap: AnimationPlayer = null

var speed_scale: float = 1.0: set = _set_speed_scale

func _set_speed_scale(v: float) -> void:
	speed_scale = v
	if is_instance_valid(_current_src_ap):
		_current_src_ap.speed_scale = v


func _ready() -> void:
	_setup_models()


func _setup_models() -> void:
	for anim_name: StringName in MODEL_MAP:
		var scene: PackedScene = load(MODEL_MAP[anim_name])
		if not scene:
			push_warning("EntenteGKAnimator: cannot load %s" % MODEL_MAP[anim_name])
			continue
		var inst: Node = scene.instantiate()
		inst.set("visible", false)
		add_child(inst)
		_models[anim_name] = inst
		_strip_root_motion(inst)
	play(&"offensive idle")


func _strip_root_motion(model: Node) -> void:
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not ap:
		return
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		for anim_name: StringName in lib.get_animation_list():
			if anim_name == &"RESET":
				continue
			CentralAnimLoader._make_in_place(lib.get_animation(anim_name))


func play(anim_name: StringName = &"") -> void:
	if anim_name == _current_name:
		return

	if is_instance_valid(_current_src_ap):
		if _current_src_ap.animation_finished.is_connected(_on_src_finished):
			_current_src_ap.animation_finished.disconnect(_on_src_finished)
		_current_src_ap.stop()
	_current_src_ap = null

	if _current_name != &"" and _current_name in _models:
		_models[_current_name].set("visible", false)

	_current_name = anim_name

	if anim_name not in _models:
		return

	var model: Node = _models[anim_name]
	model.set("visible", true)
	_current_src_ap = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _current_src_ap:
		var clip := _pick_clip(_current_src_ap)
		if clip != &"":
			var anim := _current_src_ap.get_animation(clip)
			anim.loop_mode = Animation.LOOP_LINEAR if anim_name in LOOPING else Animation.LOOP_NONE
			_current_src_ap.speed_scale = speed_scale
			_current_src_ap.play(clip)
		_current_src_ap.animation_finished.connect(_on_src_finished)


# Entente FBX import two clips: the real "mixamo_com" motion and a spurious
# static "Take 001" that sorts first. Prefer the real one or the keeper T-poses.
func _pick_clip(ap: AnimationPlayer) -> StringName:
	var names := ap.get_animation_list()
	for n: StringName in names:
		if n == &"mixamo_com":
			return n
	for n: StringName in names:
		if n != &"RESET" and n != &"Take 001":
			return n
	for n: StringName in names:
		if n != &"RESET":
			return n
	return &""


func _exit_tree() -> void:
	if is_instance_valid(_current_src_ap):
		if _current_src_ap.animation_finished.is_connected(_on_src_finished):
			_current_src_ap.animation_finished.disconnect(_on_src_finished)
	_current_src_ap = null


func _on_src_finished(_anim: StringName) -> void:
	if not is_inside_tree():
		return
	animation_finished.emit(_current_name)
